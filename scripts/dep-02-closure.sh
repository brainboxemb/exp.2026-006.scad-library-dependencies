#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_library_git_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
expected_library_scad_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_nested_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"
mechint="dsg/openscad/ext/lib.scad.mechint"
nested_util="$mechint/ext/lib.scad.util"

bash scripts/dep-01-baseline.sh
before="$(git status --porcelain)"
./bootstrap.sh
after="$(git status --porcelain)"
[[ "$before" == "$after" ]] || {
    echo "Released bootstrap is not idempotent." >&2
    git status --short >&2
    exit 1
}

[[ "$(git -C "$nested_util" rev-parse HEAD)" == "$expected_nested_util" ]]

for owner in "$mechint" "$nested_util"; do
    status="$(git -C "$owner" submodule status -- tools/tool.git-project)"
    [[ "$status" == "-$expected_library_git_tool "* || "$status" == "-$expected_library_git_tool" ]] || exit 1
    status="$(git -C "$owner" submodule status -- tools/tool.scad-project)"
    [[ "$status" == "-$expected_library_scad_tool "* || "$status" == "-$expected_library_scad_tool" ]] || exit 1
done

mkdir -p out
./update-repo.sh status | tee out/dep-02-status.txt
grep -F "owner=dsg/openscad/ext/lib.scad.mechint" out/dep-02-status.txt >/dev/null
grep -F "ref=v0.1.0" out/dep-02-status.txt >/dev/null

source_sha="$(git rev-parse HEAD)"
cat > out/dep-02-closure.json <<EOF
{
  "testcase": "DEP-02",
  "source_sha": "$source_sha",
  "implementation": "tool.git-project v0.2.9",
  "closure": "role:external",
  "nested_util": {"sha": "$expected_nested_util", "initialized": true},
  "nested_tooling_initialized": false,
  "bootstrap_idempotent": true
}
EOF
cat out/dep-02-closure.json
