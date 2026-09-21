#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

provenance="bld/evidence/domain/dependency-provenance.json"
execution="bld/evidence/executions/scad-build/execution.json"
target="bld/stl/dep05-independent-pins.stl"
expected_tool="78e26949c6f2397ed90bb7888c1386d3dd423312"
expected_mechint="bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
expected_project_util="da1892a201c3bfc78a65e10df84d4a8d142ae8f6"
expected_nested_util="5c88cd9b6b118d376825927ed67e26aff6eaee2d"

python3 scripts/run_scad_build_with_provenance.py

test -s "$target"
test -s "$provenance"
test -s "$execution"

python3 - "$provenance" "$execution" "$target" "$expected_tool" "$expected_mechint" "$expected_project_util" "$expected_nested_util" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

prov_path, execution_path, target, expected_tool, expected_mechint, expected_project_util, expected_nested_util = sys.argv[1:]
source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
prov = json.loads(Path(prov_path).read_text(encoding="utf-8"))
execution = json.loads(Path(execution_path).read_text(encoding="utf-8"))

if prov.get("schema") != "brainboxemb.scad-build-dependency-provenance":
    raise SystemExit("Unexpected dependency-provenance schema.")
if prov.get("source_revision") != source_sha:
    raise SystemExit("Dependency provenance source revision does not match HEAD.")
if execution.get("source_revision") != source_sha:
    raise SystemExit("SCAD execution evidence source revision does not match HEAD.")
if execution.get("owner_revision") != expected_tool:
    raise SystemExit("SCAD execution evidence does not retain exact tool.scad-project revision.")

matches = [item for item in prov.get("targets", []) if item.get("output") == target]
if len(matches) != 1:
    raise SystemExit(f"Expected one provenance target for {target}, found {len(matches)}")
deps = matches[0].get("dependencies", [])

expected = {
    (".", "dsg/openscad/ext/lib.scad.mechint"): ("lib.scad.mechint", "v0.1.6", expected_mechint),
    (".", "dsg/openscad/ext/lib.scad.util"): ("lib.scad.util", "v0.2.0", expected_project_util),
    ("dsg/openscad/ext/lib.scad.mechint", "ext/lib.scad.util"): ("lib.scad.util", "v0.1.0", expected_nested_util),
}

seen = {}
for dep in deps:
    key = (dep.get("owner_path"), dep.get("dependency_path"))
    seen[key] = (dep.get("name"), dep.get("declared_ref"), dep.get("revision"), dep.get("used_sources", []))

for key, value in expected.items():
    if key not in seen:
        raise SystemExit(f"Missing used dependency provenance for owner/path {key}")
    actual = seen[key][:3]
    if actual != value:
        raise SystemExit(f"Wrong provenance for {key}: {actual}, expected {value}")
    if not seen[key][3]:
        raise SystemExit(f"No used sources retained for {key}")

project_sources = seen[(".", "dsg/openscad/ext/lib.scad.util")][3]
nested_sources = seen[("dsg/openscad/ext/lib.scad.mechint", "ext/lib.scad.util")][3]
if not any(path.endswith("/openscad/transform.scad") for path in project_sources):
    raise SystemExit("Project-owned util transform.scad was not attributed to v0.2.0.")
if not any(path.endswith("/openscad/inspection.scad") for path in nested_sources):
    raise SystemExit("Nested util inspection.scad was not attributed to v0.1.0.")

print("DEP-07 provenance retains exact owner-local revisions used by the combined target.")
PY

mkdir -p out
source_sha="$(git rev-parse HEAD)"
cat > out/dep-07-provenance.json <<EOF
{
  "testcase": "DEP-07",
  "source_sha": "$source_sha",
  "target": "$target",
  "project_util": "$expected_project_util",
  "mechint": "$expected_mechint",
  "nested_util": "$expected_nested_util",
  "tool_scad_project": "$expected_tool",
  "provenance_path": "$provenance",
  "result": "pass"
}
EOF
cat out/dep-07-provenance.json
