#!/usr/bin/env bash
set -euo pipefail
mode="${1:-update}"
tool_path="tools/tool.git-project"
root="$(git rev-parse --show-toplevel)"
tool="$root/$tool_path/git-project.sh"
[[ -x "$tool" ]] || { echo "tool.git-project is not initialized. Run ./bootstrap.sh first." >&2; exit 1; }

case "$mode" in
  status)
    echo "Direct dependencies:"
    "$tool" status --repo "$root"
    echo
    echo "Nested external dependencies:"
    bash "$root/prototype/transitive-external-status.sh" "$root"
    ;;
  update)
    "$tool" update --repo "$root"
    bash "$root/prototype/transitive-external-bootstrap.sh" "$root"
    echo
    echo "Repository update complete, including transitive external library dependencies."
    echo "Review dependency gitlink changes with: git status"
    ;;
  *)
    echo "Usage: ./update-repo.sh [update|status]" >&2
    exit 2
    ;;
esac
