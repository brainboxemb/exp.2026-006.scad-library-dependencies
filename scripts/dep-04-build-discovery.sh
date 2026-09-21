#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

target_output="bld/stl/dep04-nested-discovery.stl"
combined_output="bld/stl/dep05-independent-pins.stl"
baseline_output="bld/png/01-baseline-mechint.png"
manifest=".cache/scad-project/state/build-manifest.json"
execution_log=".cache/scad-project/state/executed-targets.txt"
util_root="dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util"
util_source="$util_root/openscad/inspection.scad"
expected_nested="dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util/openscad/inspection.scad"

restore_util() {
  git -C "$util_root" checkout -- openscad/inspection.scad >/dev/null 2>&1 || true
}
trap restore_util EXIT

echo "DEP-04: first normal SCons build"
bash tools/tool.scad-project/scad-project.sh build

test -s "$target_output"
test -f "$manifest"

python3 - "$manifest" "$target_output" "$expected_nested" <<'PY'
import json
import sys
from pathlib import Path
manifest_path, output, expected = sys.argv[1:]
payload = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
matches = [t for t in payload["targets"] if t["output"] == output]
if len(matches) != 1:
    raise SystemExit(f"Expected exactly one DEP-04 target for {output}, found {len(matches)}")
sources = matches[0].get("sources", [])
if expected not in sources:
    raise SystemExit("Nested util source missing from DEP-04 build graph.\nExpected: " + expected + "\nSources:\n" + "\n".join(sources))
print("Nested build dependency recorded: " + expected)
PY

echo "// DEP-04 invalidation probe" >> "$util_source"

echo "DEP-04: rebuild after nested util source change"
bash tools/tool.scad-project/scad-project.sh build

test -s "$execution_log"
mapfile -t executed < "$execution_log"
count="$(printf '%s\n' "${executed[@]}" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$count" != "2" ]]; then
  echo "Expected exactly two nested-util-dependent targets to rebuild." >&2
  printf '  %s\n' "${executed[@]}" >&2
  exit 1
fi
for expected in "$target_output" "$combined_output"; do
  if ! printf '%s\n' "${executed[@]}" | grep -Fqx "$expected"; then
    echo "Expected dependent target to rebuild: $expected" >&2
    printf '  %s\n' "${executed[@]}" >&2
    exit 1
  fi
done

if printf '%s\n' "${executed[@]}" | grep -Fqx "$baseline_output"; then
  echo "Unrelated baseline target unexpectedly rebuilt." >&2
  exit 1
fi

restore_util
trap - EXIT

test -z "$(git -C "$util_root" status --porcelain)" || {
  echo "Nested util checkout was not restored cleanly." >&2
  git -C "$util_root" status --short >&2
  exit 1
}

mkdir -p out
source_sha="$(git rev-parse HEAD)"
cat > out/dep-04-build-discovery.json <<EOF
{
  "testcase": "DEP-04",
  "source_sha": "$source_sha",
  "build_engine": "scons",
  "target": "$target_output",
  "nested_dependency": "$expected_nested",
  "nested_change_rebuilt_targets": [
    "$target_output",
    "$combined_output"
  ],
  "unrelated_baseline_rebuilt": false,
  "result": "pass"
}
EOF
cat out/dep-04-build-discovery.json
