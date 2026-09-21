#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
tool_path="tools/tool.git-project"
expected_tool="7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
entry="$(git -C "$root" ls-files --stage -- "$tool_path" 2>/dev/null || true)"
if [[ ! "$entry" =~ ^160000[[:space:]]$expected_tool[[:space:]] ]]; then
  echo "Released DEP-01 bootstrap expects $tool_path gitlink $expected_tool; got: $entry" >&2
  exit 1
fi
git -C "$root" submodule sync -- "$tool_path" >/dev/null
git -C "$root" submodule update --init -- "$tool_path" >/dev/null
"$root/$tool_path/git-project.sh" bootstrap --repo "$root"
