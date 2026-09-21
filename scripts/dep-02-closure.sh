#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_root_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
expected_scad_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_mechint="bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
expected_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"
mechint="dsg/openscad/ext/lib.scad.mechint"
util="$mechint/ext/lib.scad.util"

bash scripts/dep-01-baseline.sh
bash prototype/transitive-external-bootstrap.sh .

actual_util="$(git -C "$util" rev-parse HEAD)"
[[ "$actual_util" == "$expected_util" ]] || { echo "Unexpected util HEAD: $actual_util" >&2; exit 1; }

assert_uninitialized() {
    local owner="$1" path="$2" expected="$3" status
    status="$(git -C "$owner" submodule status -- "$path")"
    [[ "$status" == "-$expected "* || "$status" == "-$expected" ]] || {
        echo "Expected $owner/$path to remain uninitialized; got: $status" >&2
        exit 1
    }
}

assert_uninitialized "$mechint" "tools/tool.git-project" "$expected_root_tool"
assert_uninitialized "$mechint" "tools/tool.scad-project" "$expected_scad_tool"
assert_uninitialized "$util" "tools/tool.git-project" "$expected_root_tool"
assert_uninitialized "$util" "tools/tool.scad-project" "$expected_scad_tool"

echo
echo "Mechint nested state after controlled closure:"
git -C "$mechint" submodule status
echo
echo "Util nested state after controlled closure:"
git -C "$util" submodule status

mkdir -p out
source_sha="$(git rev-parse HEAD)"
cat > out/dep-02-closure.json <<EOF
{
  "testcase": "DEP-02",
  "source_sha": "$source_sha",
  "closure": "role:external",
  "lib.scad.mechint": "$expected_mechint",
  "nested": {
    "ext/lib.scad.util": {"sha": "$expected_util", "initialized": true},
    "mechint/tools/tool.git-project": {"sha": "$expected_root_tool", "initialized": false},
    "mechint/tools/tool.scad-project": {"sha": "$expected_scad_tool", "initialized": false},
    "util/tools/tool.git-project": {"sha": "$expected_root_tool", "initialized": false},
    "util/tools/tool.scad-project": {"sha": "$expected_scad_tool", "initialized": false}
  }
}
EOF
cat out/dep-02-closure.json
