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
  function reset_current() { name = role = type = url = path = ref = "" }
  function emit_current() {
    if (name != "" && role == "external") print name "|" type "|" url "|" path "|" ref
    reset_current()
  }
  BEGIN { in_dependencies = 0; reset_current() }
  /^[^ ]/ {
    if ($0 ~ /^dependencies:[[:space:]]*$/) { if (in_dependencies) emit_current(); in_dependencies = 1; next }
    if (in_dependencies) { emit_current(); in_dependencies = 0 }
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

repo_initialized() {
  local full="$1" top full_real top_real
  [[ -d "$full" ]] || return 1
  top="$(git -C "$full" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$top" ]] || return 1
  full_real="$(cd "$full" && pwd -P)"
  top_real="$(cd "$top" && pwd -P)"
  [[ "$full_real" == "$top_real" ]]
}

resolve_local() {
  local full="$1" ref="$2" candidate resolved
  if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    resolved="$(git -C "$full" rev-parse --verify "$ref^{commit}" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && { printf '%s' "$resolved"; return 0; }
  fi
  for candidate in "refs/tags/$ref^{commit}" "origin/$ref^{commit}" "$ref^{commit}"; do
    resolved="$(git -C "$full" rev-parse --verify "$candidate" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && { printf '%s' "$resolved"; return 0; }
  done
  return 1
}

owner_label() {
  local owner="$1"
  if [[ "$owner" == "$repo_root" ]]; then printf '.'
  else printf '%s' "${owner#"$repo_root"/}"
  fi
}

walk_status() {
  local owner="$1" lineage="$2" depth="$3"
  local name type url path ref normalized full entry gitlink current expected dirty state

  while IFS='|' read -r name type url path ref; do
    [[ -n "$name" ]] || continue
    [[ "$type" == "git-submodule" ]] || continue
    normalized="$(normalize_url "$url")"
    if printf '%s\n' "$lineage" | grep -Fqx "$normalized"; then
      [[ "$depth" -gt 0 ]] && printf 'nested %-20s CYCLE owner=%s path=%s ref=%s\n' "$name" "$(owner_label "$owner")" "$path" "$ref"
      continue
    fi

    entry="$(git -C "$owner" ls-files --stage -- "$path" 2>/dev/null || true)"
    if [[ ! "$entry" =~ ^160000[[:space:]]([0-9a-fA-F]{40})[[:space:]] ]]; then
      [[ "$depth" -gt 0 ]] && printf 'nested %-20s MISSING_GITLINK owner=%s path=%s ref=%s\n' "$name" "$(owner_label "$owner")" "$path" "$ref"
      continue
    fi
    gitlink="${BASH_REMATCH[1]}"
    full="$owner/$path"

    if ! repo_initialized "$full"; then
      [[ "$depth" -gt 0 ]] && printf 'nested %-20s UNINITIALIZED owner=%s path=%s gitlink=%s ref=%s\n' "$name" "$(owner_label "$owner")" "$path" "${gitlink:0:12}" "$ref"
      continue
    fi

    current="$(git -C "$full" rev-parse HEAD)"
    expected="$(resolve_local "$full" "$ref" || true)"
    dirty="$(git -C "$full" status --porcelain)"
    if [[ -n "$dirty" ]]; then state="DIRTY"
    elif [[ -n "$expected" && "$current" == "$expected" ]]; then state="OK"
    elif [[ -n "$expected" ]]; then state="DIFF"
    else state="UNKNOWN"
    fi

    [[ "$depth" -gt 0 ]] && printf 'nested %-20s %-13s owner=%s path=%s current=%s ref=%s\n' "$name" "$state" "$(owner_label "$owner")" "$path" "${current:0:12}" "$ref"
    walk_status "$full" "$lineage"$'\n'"$normalized" "$((depth + 1))"
  done < <(read_external_dependencies "$owner")
}

root_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || printf 'local-root')"
walk_status "$repo_root" "$(normalize_url "$root_url")" 0
