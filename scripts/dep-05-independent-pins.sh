#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

project_util="dsg/openscad/ext/lib.scad.util"
nested_util="dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util"
source="dsg/openscad/dep05-independent-pins.scad"
expected_project="da1892a201c3bfc78a65e10df84d4a8d142ae8f6"
expected_nested="5c88cd9b6b118d376825927ed67e26aff6eaee2d"

restore_files() {
  if [[ -f "$project_util/openscad/transform.scad.dep05-hidden" ]]; then mv "$project_util/openscad/transform.scad.dep05-hidden" "$project_util/openscad/transform.scad"; fi
  if [[ -f "$nested_util/openscad/inspection.scad.dep05-hidden" ]]; then mv "$nested_util/openscad/inspection.scad.dep05-hidden" "$nested_util/openscad/inspection.scad"; fi
}
trap restore_files EXIT

test "$(git -C "$project_util" rev-parse HEAD)" = "$expected_project"
test "$(git -C "$nested_util" rev-parse HEAD)" = "$expected_nested"

PYTHONPATH=tools/tool.scad-project/src python3 - "$source" <<'PY'
import sys
from pathlib import Path
from scad_project.openscad_deps import scan_openscad_dependencies
source = Path(sys.argv[1])
deps = [p.as_posix() for p in scan_openscad_dependencies(source)]
expected = [
    Path('dsg/openscad/ext/lib.scad.util/openscad/transform.scad').resolve().as_posix(),
    Path('dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util/openscad/inspection.scad').resolve().as_posix(),
]
for value in expected:
    if value not in deps:
        raise SystemExit('Missing independent-pin dependency: ' + value)
print('Both util owner paths are present in the dependency graph.')
PY

mkdir -p out
run_csg() {
  local output="$1" log="$2"
  OPENSCADPATH= xvfb-run -a openscad --enable=object-function -o "$output" "$source" >"$log" 2>&1
}

echo 'DEP-05: combined evaluation with both pins present'
if ! run_csg out/dep-05-both.csg out/dep-05-both.log; then
  echo 'Combined evaluation failed:' >&2
  cat out/dep-05-both.log >&2
  exit 1
fi
test -s out/dep-05-both.csg
if grep -Eiq "can't open|cannot open|could not open|unknown module" out/dep-05-both.log; then
  cat out/dep-05-both.log >&2
  exit 1
fi

echo 'DEP-05: project util must not fall back to nested util'
mv "$project_util/openscad/transform.scad" "$project_util/openscad/transform.scad.dep05-hidden"
run_csg out/dep-05-project-missing.csg out/dep-05-project-missing.log || true
if ! grep -Eiq "transform\.scad|xf_move" out/dep-05-project-missing.log; then
  echo 'Expected project-owned util failure was not observed.' >&2
  cat out/dep-05-project-missing.log >&2
  exit 1
fi
mv "$project_util/openscad/transform.scad.dep05-hidden" "$project_util/openscad/transform.scad"

echo 'DEP-05: nested mechint util must not fall back to project util'
mv "$nested_util/openscad/inspection.scad" "$nested_util/openscad/inspection.scad.dep05-hidden"
run_csg out/dep-05-nested-missing.csg out/dep-05-nested-missing.log || true
if ! grep -Eiq "inspection\.scad|util_section_inspect" out/dep-05-nested-missing.log; then
  echo 'Expected nested mechint util failure was not observed.' >&2
  cat out/dep-05-nested-missing.log >&2
  exit 1
fi
mv "$nested_util/openscad/inspection.scad.dep05-hidden" "$nested_util/openscad/inspection.scad"

restore_files
trap - EXIT
test -z "$(git -C "$project_util" status --porcelain)"
test -z "$(git -C "$nested_util" status --porcelain)"

source_sha="$(git rev-parse HEAD)"
cat > out/dep-05-independent-pins.json <<EOF
{
  "testcase": "DEP-05",
  "source_sha": "$source_sha",
  "project_util": {"ref": "v0.2.0", "sha": "$expected_project"},
  "mechint_nested_util": {"ref": "v0.1.0", "sha": "$expected_nested"},
  "combined_evaluation": true,
  "project_fallback_to_nested": false,
  "nested_fallback_to_project": false,
  "result": "pass"
}
EOF
cat out/dep-05-independent-pins.json
