#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_root_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
expected_scad_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_mechint="bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
expected_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"

mechint_path="dsg/openscad/ext/lib.scad.mechint"

assert_head() {
    local path="$1"
    local expected="$2"
    local actual
    actual="$(git -C "$path" rev-parse HEAD)"
    if [[ "$actual" != "$expected" ]]; then
        echo "Unexpected HEAD for $path: $actual (expected $expected)" >&2
        exit 1
    fi
}

assert_nested_gitlink_uninitialized() {
    local owner="$1"
    local path="$2"
    local expected="$3"
    local entry status

    entry="$(git -C "$owner" ls-files --stage -- "$path")"
    if [[ ! "$entry" =~ ^160000[[:space:]]$expected[[:space:]] ]]; then
        echo "Unexpected gitlink for $owner/$path: $entry" >&2
        exit 1
    fi

    status="$(git -C "$owner" submodule status -- "$path")"
    if [[ "$status" != "-$expected "* && "$status" != "-$expected" ]]; then
        echo "Expected $owner/$path to remain uninitialized; got: $status" >&2
        exit 1
    fi
}

echo "DEP-01: bootstrap released direct-only dependency model"
bash scripts/released-direct-bootstrap.sh

assert_head "tools/tool.git-project" "$expected_root_tool"
assert_head "tools/tool.scad-project" "$expected_scad_tool"
assert_head "$mechint_path" "$expected_mechint"

assert_nested_gitlink_uninitialized "$mechint_path" "ext/lib.scad.util" "$expected_util"
assert_nested_gitlink_uninitialized "$mechint_path" "tools/tool.git-project" "$expected_root_tool"
assert_nested_gitlink_uninitialized "$mechint_path" "tools/tool.scad-project" "$expected_scad_tool"

echo
echo "Root dependency status:"
tools/tool.git-project/git-project.sh status --repo .

echo
echo "Nested mechint submodule status:"
git -C "$mechint_path" submodule status

mkdir -p out
source_sha="$(git rev-parse HEAD)"
cat > out/dep-01-baseline.json <<EOF
{
  "testcase": "DEP-01",
  "source_sha": "$source_sha",
  "bootstrap_model": "released-direct-only",
  "direct_dependencies": {
    "tool.git-project": "$expected_root_tool",
    "tool.scad-project": "$expected_scad_tool",
    "lib.scad.mechint": "$expected_mechint"
  },
  "nested_mechint_gitlinks": {
    "ext/lib.scad.util": {"sha": "$expected_util", "initialized": false},
    "tools/tool.git-project": {"sha": "$expected_root_tool", "initialized": false},
    "tools/tool.scad-project": {"sha": "$expected_scad_tool", "initialized": false}
  }
}
EOF

cat out/dep-01-baseline.json
