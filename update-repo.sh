#!/usr/bin/env bash
set -euo pipefail
tool_path="tools/tool.git-project"
root="$(git rev-parse --show-toplevel)"
tool="$root/$tool_path/git-project.sh"
[[ -x "$tool" ]] || { echo "tool.git-project is not initialized. Run ./bootstrap.sh first." >&2; exit 1; }
"$tool" update --repo "$root"
bash "$root/prototype/transitive-external-bootstrap.sh" "$root"
echo
echo "Repository update complete, including transitive external library dependencies."
echo "Review dependency gitlink changes with: git status"
