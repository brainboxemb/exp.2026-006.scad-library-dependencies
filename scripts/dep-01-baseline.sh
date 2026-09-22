#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_root_git_tool="9879da589101f41b2b0e634d196ddcc51e1a6102"
expected_root_scad_tool="bfaac9f6916c09bc6525abddf64c87238fe59103"
expected_library_git_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
expected_library_scad_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_mechint="bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
expected_nested_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"
expected_project_util="da1892a201c3bfc78a65e10df84d4a8d142ae8f6"

mechint="dsg/openscad/ext/lib.scad.mechint"
nested_util="$mechint/ext/lib.scad.util"
project_util="dsg/openscad/ext/lib.scad.util"

assert_head() {
    local path="$1" expected="$2" actual
    actual="$(git -C "$path" rev-parse HEAD)"
    [[ "$actual" == "$expected" ]] || {
        echo "Unexpected HEAD for $path: $actual (expected $expected)" >&2
        exit 1
    }
}

assert_uninitialized() {
    local owner="$1" path="$2" expected="$3" status
    status="$(git -C "$owner" submodule status -- "$path")"
    [[ "$status" == "-$expected "* || "$status" == "-$expected" ]] || {
        echo "Expected $owner/$path to remain uninitialized; got: $status" >&2
        exit 1
    }
}

echo "DEP-01: bootstrap released controlled external closure"
./bootstrap.sh

assert_head "tools/tool.git-project" "$expected_root_git_tool"
assert_head "tools/tool.scad-project" "$expected_root_scad_tool"
assert_head "$mechint" "$expected_mechint"
assert_head "$nested_util" "$expected_nested_util"
assert_head "$project_util" "$expected_project_util"

for owner in "$mechint" "$nested_util" "$project_util"; do
    assert_uninitialized "$owner" "tools/tool.git-project" "$expected_library_git_tool"
    assert_uninitialized "$owner" "tools/tool.scad-project" "$expected_library_scad_tool"
done

mkdir -p out
./update-repo.sh status | tee out/dep-01-status.txt

source_sha="$(git rev-parse HEAD)"
cat > out/dep-01-baseline.json <<EOF
{
  "testcase": "DEP-01",
  "source_sha": "$source_sha",
  "bootstrap_model": "released-controlled-external-closure",
  "root_tool_git_project": "$expected_root_git_tool",
  "root_tool_scad_project": "$expected_root_scad_tool",
  "lib_scad_mechint": "$expected_mechint",
  "project_util": {"sha": "$expected_project_util", "initialized": true},
  "mechint_nested_util": {"sha": "$expected_nested_util", "initialized": true},
  "nested_tooling_initialized": false
}
EOF
cat out/dep-01-baseline.json
