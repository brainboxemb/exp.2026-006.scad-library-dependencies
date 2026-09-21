#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
project_util="dsg/openscad/ext/lib.scad.util"
mechint="dsg/openscad/ext/lib.scad.mechint"
nested_util="$mechint/ext/lib.scad.util"
project_v020="da1892a201c3bfc78a65e10df84d4a8d142ae8f6"
util_v010="5c88cd9b6b118d376825927ed67e26aff6eaee2d"

./bootstrap.sh
mkdir -p out

./update-repo.sh status | tee out/dep-06-status-clean.txt
grep -F "owner=dsg/openscad/ext/lib.scad.mechint" out/dep-06-status-clean.txt >/dev/null
grep -F "ref=v0.1.0" out/dep-06-status-clean.txt >/dev/null

printf "\nDEP-06 temporary dirty marker\n" >> "$nested_util/README.md"
./update-repo.sh status | tee out/dep-06-status-dirty.txt
grep -F "DIRTY" out/dep-06-status-dirty.txt >/dev/null
if ./update-repo.sh >out/dep-06-dirty-update.log 2>&1; then
  echo "Update unexpectedly succeeded with a dirty nested dependency." >&2
  exit 1
fi
git -C "$nested_util" checkout -- README.md
[[ "$(git -C "$project_util" rev-parse HEAD)" == "$project_v020" ]]
[[ "$(git -C "$nested_util" rev-parse HEAD)" == "$util_v010" ]]

cp project.yml out/dep-06-project.yml.bak
sed -i "0,/ref: v0.2.0/s//ref: v0.1.0/" project.yml
./update-repo.sh >out/dep-06-project-pin-update.log 2>&1
[[ "$(git -C "$project_util" rev-parse HEAD)" == "$util_v010" ]]
[[ "$(git -C "$nested_util" rev-parse HEAD)" == "$util_v010" ]]
mv out/dep-06-project.yml.bak project.yml
./update-repo.sh >out/dep-06-project-pin-restore.log 2>&1
[[ "$(git -C "$project_util" rev-parse HEAD)" == "$project_v020" ]]
[[ "$(git -C "$nested_util" rev-parse HEAD)" == "$util_v010" ]]

git -C "$mechint" submodule deinit -f -- ext/lib.scad.util >/dev/null
./update-repo.sh status | tee out/dep-06-status-uninitialized.txt
grep -F "UNINITIALIZED" out/dep-06-status-uninitialized.txt >/dev/null
./update-repo.sh >out/dep-06-reinitialize.log 2>&1
[[ "$(git -C "$nested_util" rev-parse HEAD)" == "$util_v010" ]]

mkdir -p dsg/openscad/ext/local-sentinel
printf "keep\n" > dsg/openscad/ext/local-sentinel/keep.txt
./update-repo.sh >out/dep-06-sentinel-update.log 2>&1
test -f dsg/openscad/ext/local-sentinel/keep.txt
rm -rf dsg/openscad/ext/local-sentinel

./update-repo.sh status | tee out/dep-06-status-final.txt
test -z "$(git status --porcelain)" || { git status --short >&2; exit 1; }

cat > out/dep-06-status-update.json <<EOF
{
  "testcase": "DEP-06",
  "project_util": {"ref": "v0.2.0", "sha": "$project_v020"},
  "nested_util": {"ref": "v0.1.0", "sha": "$util_v010"},
  "dirty_nested_reported": true,
  "dirty_nested_update_blocked": true,
  "owner_specific_update": true,
  "uninitialized_nested_reported": true,
  "normal_update_reinitialized_nested": true,
  "undeclared_local_path_preserved": true,
  "final_worktree_clean": true,
  "result": "pass"
}
EOF
cat out/dep-06-status-update.json
