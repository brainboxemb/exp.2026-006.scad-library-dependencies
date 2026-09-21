#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

runtime_image="${SCAD_RUNTIME_IMAGE:-ghcr.io/brainboxemb/scad-toolchain-openscad:v0.6.1}"
target_rel="dsg/openscad/ext/lib.scad.mechint/main.scad"
target_host="$root/$target_rel"

# Reproduce the qualified dependency state first.
bash scripts/dep-02-closure.sh

[[ -f "$target_host" ]] || { echo "Target not found: $target_host" >&2; exit 1; }
[[ -f "$root/dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util/openscad/inspection.scad" ]] || {
    echo "Nested util inspection source is not initialized." >&2
    exit 1
}

mkdir -p out
rm -f out/dep-03-mechint.csg out/dep-03-openscad.log out/dep-03-engine.json

echo "DEP-03: direct OpenSCAD engine resolution"
echo "runtime=$runtime_image"
echo "target=$target_rel"
echo "working_directory=/tmp"
echo "OPENSCADPATH=<empty>"

set +e
docker run --rm \
  -v "$root:/work" \
  -w /tmp \
  -e OPENSCADPATH= \
  "$runtime_image" \
  bash -lc 'xvfb-run -a openscad --enable=object-function -o /work/out/dep-03-mechint.csg /work/dsg/openscad/ext/lib.scad.mechint/main.scad' \
  > >(tee out/dep-03-openscad.log) 2>&1
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
    echo "OpenSCAD exited with code $rc." >&2
    exit "$rc"
fi

if [[ ! -s out/dep-03-mechint.csg ]]; then
    echo "OpenSCAD did not produce a non-empty evaluated CSG tree." >&2
    exit 1
fi

if grep -Eiq "(can't open|cannot open|could not open|unable to open).*(include|use|inspection\.scad|lib\.scad\.util)|(include|use).*(not found|can't open|cannot open)" out/dep-03-openscad.log; then
    echo "OpenSCAD reported an unresolved include/use dependency:" >&2
    cat out/dep-03-openscad.log >&2
    exit 1
fi

output_bytes="$(stat -c '%s' out/dep-03-mechint.csg)"
source_sha="$(git rev-parse HEAD)"
mechint_sha="$(git -C dsg/openscad/ext/lib.scad.mechint rev-parse HEAD)"
util_sha="$(git -C dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util rev-parse HEAD)"

cat > out/dep-03-engine.json <<EOF
{
  "testcase": "DEP-03-engine",
  "source_sha": "$source_sha",
  "target": "$target_rel",
  "runtime_image": "$runtime_image",
  "working_directory": "/tmp",
  "openscadpath": "",
  "mechint_sha": "$mechint_sha",
  "util_sha": "$util_sha",
  "evaluation": "csg",
  "output": "out/dep-03-mechint.csg",
  "output_bytes": $output_bytes,
  "result": "pass"
}
EOF

cat out/dep-03-engine.json
