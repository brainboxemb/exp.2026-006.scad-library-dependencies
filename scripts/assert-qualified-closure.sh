#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_root_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
expected_scad_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_mechint="bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
expected_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"
expected_project_util="da1892a201c3bfc78a65e10df84d4a8d142ae8f6"
mechint="dsg/openscad/ext/lib.scad.mechint"
util="$mechint/ext/lib.scad.util"
project_util="dsg/openscad/ext/lib.scad.util"

assert_head() {
  local path="$1" expected="$2" actual
  actual="$(git -C "$path" rev-parse HEAD)"
  [[ "$actual" == "$expected" ]] || { echo "Unexpected HEAD for $path: $actual (expected $expected)" >&2; exit 1; }
}

assert_uninitialized() {
  local owner="$1" path="$2" expected="$3" status
  status="$(git -C "$owner" submodule status -- "$path")"
  [[ "$status" == "-$expected "* || "$status" == "-$expected" ]] || {
    echo "Expected $owner/$path to remain uninitialized; got: $status" >&2
    exit 1
  }
}

assert_head "tools/tool.git-project" "$expected_root_tool"
assert_head "tools/tool.scad-project" "$expected_scad_tool"
assert_head "$mechint" "$expected_mechint"
assert_head "$util" "$expected_util"
assert_head "$project_util" "$expected_project_util"
assert_uninitialized "$mechint" "tools/tool.git-project" "$expected_root_tool"
assert_uninitialized "$mechint" "tools/tool.scad-project" "$expected_scad_tool"
assert_uninitialized "$util" "tools/tool.git-project" "$expected_root_tool"
assert_uninitialized "$util" "tools/tool.scad-project" "$expected_scad_tool"
