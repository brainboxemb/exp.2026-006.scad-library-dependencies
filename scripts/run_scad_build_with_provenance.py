#!/usr/bin/env python3
"""Experiment-owned scad.build wrapper for DEP-07 provenance qualification."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/tool.scad-project/scripts/run_scad_capability.py"),
            "build",
        ],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/write_scad_dependency_provenance.py")],
        cwd=ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
