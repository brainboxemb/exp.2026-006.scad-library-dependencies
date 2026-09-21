#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"
repo_root="$(git -C "$repo_root" rev-parse --show-toplevel)"

normalize_url() {
    local value="$1"
    value="${value%/}"
    value="${value%.git}"
    if [[ "$value" =~ ^git@github\.com:(.+)$ ]]; then
        value="https://github.com/${BASH_REMATCH[1]}"
    fi
    printf '%s' "$value"
}

read_external_dependencies() {
    local owner="$1"
    local project_file="$owner/project.yml"
    [[ -f "$project_file" ]] || return 0

    awk '
    function clean(value, first, last) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        first = substr(value, 1, 1)
        last = substr(value, length(value), 1)
        if (length(value) >= 2 && ((first == "\"" && last == "\"") || (first == "\047" && last == "\047"))) {
            value = substr(value, 2, length(value) - 2)
        }
        return value
    }
    function reset_current() {
        name = role = type = url = path = ref = ""
    }
    function emit_current() {
        if (name != "" && role == "external") {
            print name "|" type "|" url "|" path "|" ref
        }
        reset_current()
    }
    BEGIN { in_dependencies = 0; reset_current() }
    /^[^ ]/ {
        if ($0 ~ /^dependencies:[[:space:]]*$/) {
            if (in_dependencies) emit_current()
            in_dependencies = 1
            next
        }
        if (in_dependencies) {
            emit_current()
            in_dependencies = 0
        }
    }
    in_dependencies && /^  - name:/ { emit_current(); name = clean(substr($0, index($0, ":") + 1)); next }
    in_dependencies && /^    role:/ { role = clean(substr($0, index($0, ":") + 1)); next }
    in_dependencies && /^    type:/ { type = clean(substr($0, index($0, ":") + 1)); next }
    in_dependencies && /^    url:/  { url  = clean(substr($0, index($0, ":") + 1)); next }
    in_dependencies && /^    path:/ { path = clean(substr($0, index($0, ":") + 1)); next }
    in_dependencies && /^    ref:/  { ref  = clean(substr($0, index($0, ":") + 1)); next }
    END { if (in_dependencies) emit_current() }
    ' "$project_file"
}

submodule_name_for_path() {
    local owner="$1"
    local path="$2"
    local line key value
    [[ -f "$owner/.gitmodules" ]] || return 1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        key="${line%%[[:space:]]*}"
        value="${line#${key}}"
        value="${value#${value%%[![:space:]]*}}"
        if [[ "$value" == "$path" ]]; then
            key="${key#submodule.}"
            key="${key%.path}"
            printf '%s' "$key"
            return 0
        fi
    done < <(git -C "$owner" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
    return 1
}

dependency_repo_initialized() {
    local full="$1"
    local top full_real top_real
    [[ -d "$full" ]] || return 1
    top="$(git -C "$full" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$top" ]] || return 1
    full_real="$(cd "$full" && pwd -P)"
    top_real="$(cd "$top" && pwd -P)"
    [[ "$full_real" == "$top_real" ]]
}

assert_clean() {
    local full="$1"
    local name="$2"
    [[ -z "$(git -C "$full" status --porcelain)" ]] || {
        echo "Dependency '$name' has local changes; refusing transitive checkout." >&2
        exit 1
    }
}

resolve_commit() {
    local full="$1"
    local ref="$2"
    local candidate resolved
    git -C "$full" fetch origin --prune --tags >/dev/null
    if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
        if resolved="$(git -C "$full" rev-parse --verify "$ref^{commit}" 2>/dev/null)"; then
            printf '%s' "$resolved"
            return 0
        fi
    fi
    for candidate in "refs/tags/$ref^{commit}" "origin/$ref^{commit}" "$ref^{commit}"; do
        if resolved="$(git -C "$full" rev-parse --verify "$candidate" 2>/dev/null)"; then
            printf '%s' "$resolved"
            return 0
        fi
    done
    return 1
}

walk_owner() {
    local owner="$1"
    local lineage="$2"
    local name type url path ref normalized full entry gitlink sub_name configured_url expected current

    while IFS='|' read -r name type url path ref; do
        [[ -n "$name" ]] || continue
        [[ "$type" == "git-submodule" ]] || {
            echo "Unsupported external dependency type '$type' for $name." >&2
            exit 1
        }
        [[ -n "$url" && -n "$path" && -n "$ref" ]] || {
            echo "External dependency '$name' has incomplete metadata." >&2
            exit 1
        }

        normalized="$(normalize_url "$url")"
        if printf '%s\n' "$lineage" | grep -Fqx "$normalized"; then
            echo "Dependency cycle detected through $url while walking $owner." >&2
            exit 1
        fi

        entry="$(git -C "$owner" ls-files --stage -- "$path" 2>/dev/null || true)"
        [[ "$entry" =~ ^160000[[:space:]]([0-9a-fA-F]{40})[[:space:]] ]] || {
            echo "External dependency '$name' is not a committed gitlink at $owner/$path." >&2
            exit 1
        }
        gitlink="${BASH_REMATCH[1]}"

        sub_name="$(submodule_name_for_path "$owner" "$path" || true)"
        [[ -n "$sub_name" ]] || {
            echo "No .gitmodules entry found for $owner/$path." >&2
            exit 1
        }
        configured_url="$(git -C "$owner" config -f .gitmodules --get "submodule.$sub_name.url" 2>/dev/null || true)"
        [[ "$(normalize_url "$configured_url")" == "$normalized" ]] || {
            echo "URL mismatch for $owner/$path: project.yml=$url .gitmodules=$configured_url" >&2
            exit 1
        }

        git -C "$owner" submodule sync -- "$path" >/dev/null
        if ! dependency_repo_initialized "$owner/$path"; then
            git -C "$owner" submodule update --init -- "$path" >/dev/null
        fi

        full="$owner/$path"
        assert_clean "$full" "$name"
        expected="$(resolve_commit "$full" "$ref" || true)"
        [[ -n "$expected" ]] || {
            echo "Unable to resolve ref '$ref' for $name." >&2
            exit 1
        }
        current="$(git -C "$full" rev-parse HEAD)"
        if [[ "$current" != "$expected" ]]; then
            echo "Aligning external $name: $current -> $expected ($ref)"
            git -C "$full" checkout --detach "$expected" >/dev/null
            current="$expected"
        fi

        echo "external $name owner=$owner path=$path gitlink=$gitlink current=$current ref=$ref"
        walk_owner "$full" "$lineage"$'\n'"$normalized"
    done < <(read_external_dependencies "$owner")
}

root_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || printf 'local-root')"
walk_owner "$repo_root" "$(normalize_url "$root_url")"
