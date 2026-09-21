#!/usr/bin/env python3
"""Write target-level SCAD dependency provenance from the real SCons source graph."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / ".cache/scad-project/state/build-manifest.json"
OUTPUT = ROOT / "bld/evidence/domain/dependency-provenance.json"


def git(cwd: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed in {cwd}: {completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def normalize_url(value: str) -> str:
    value = value.strip().rstrip("/")
    if value.endswith(".git"):
        value = value[:-4]
    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value[len("git@github.com:"):]
    return value


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def initialized_repo(path: Path) -> bool:
    if not path.is_dir():
        return False
    top = git(path, "rev-parse", "--show-toplevel", check=False)
    if not top:
        return False
    return Path(top).resolve() == path.resolve()


def external_dependencies(owner: Path) -> list[dict[str, str]]:
    project = owner / "project.yml"
    if not project.is_file():
        return []
    payload = yaml.safe_load(project.read_text(encoding="utf-8")) or {}
    result: list[dict[str, str]] = []
    for raw in payload.get("dependencies", []) or []:
        if not isinstance(raw, dict):
            continue
        if raw.get("role") != "external" or raw.get("type") != "git-submodule":
            continue
        required = ("name", "url", "path", "ref")
        missing = [key for key in required if not str(raw.get(key, "")).strip()]
        if missing:
            raise RuntimeError(
                f"{project}: external dependency is missing {', '.join(missing)}"
            )
        result.append({key: str(raw[key]) for key in required})
    return result


def collect_dependencies(
    owner: Path,
    *,
    lineage: tuple[str, ...],
    depth: int,
    nodes: list[dict[str, Any]],
) -> None:
    for dep in external_dependencies(owner):
        normalized = normalize_url(dep["url"])
        if normalized in lineage:
            raise RuntimeError(
                f"Dependency cycle while collecting provenance: {dep['url']}"
            )

        worktree = (owner / dep["path"]).resolve()
        if not initialized_repo(worktree):
            raise RuntimeError(
                f"Dependency required for provenance is not initialized: {worktree}"
            )

        node = {
            "name": dep["name"],
            "repository": normalized,
            "owner_path": "." if owner.resolve() == ROOT else relative(owner),
            "dependency_path": Path(dep["path"]).as_posix(),
            "worktree_path": relative(worktree),
            "declared_ref": dep["ref"],
            "revision": git(worktree, "rev-parse", "HEAD"),
            "depth": depth,
        }
        nodes.append(node)
        collect_dependencies(
            worktree,
            lineage=(*lineage, normalized),
            depth=depth + 1,
            nodes=nodes,
        )


def source_owner(
    source: Path,
    dependency_nodes: list[dict[str, Any]],
) -> dict[str, Any] | None:
    resolved = source.resolve()
    candidates: list[tuple[int, dict[str, Any]]] = []
    for node in dependency_nodes:
        worktree = (ROOT / node["worktree_path"]).resolve()
        try:
            resolved.relative_to(worktree)
        except ValueError:
            continue
        candidates.append((len(worktree.parts), node))
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def main() -> None:
    if not MANIFEST.is_file():
        raise SystemExit(f"Normal SCons build manifest not found: {MANIFEST}")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    dependency_nodes: list[dict[str, Any]] = []
    root_url = git(ROOT, "remote", "get-url", "origin", check=False) or "local-root"
    collect_dependencies(
        ROOT,
        lineage=(normalize_url(root_url),),
        depth=1,
        nodes=dependency_nodes,
    )

    targets: list[dict[str, Any]] = []
    for target in manifest.get("targets", []):
        grouped: dict[tuple[str, str, str], dict[str, Any]] = {}
        for raw_source in target.get("sources", []):
            source = Path(str(raw_source))
            if not source.is_absolute():
                source = ROOT / source
            owner = source_owner(source, dependency_nodes)
            if owner is None:
                continue

            key = (
                owner["owner_path"],
                owner["dependency_path"],
                owner["revision"],
            )
            record = grouped.get(key)
            if record is None:
                record = dict(owner)
                record["used_sources"] = []
                grouped[key] = record
            source_value = relative(source)
            if source_value not in record["used_sources"]:
                record["used_sources"].append(source_value)

        dependencies = sorted(
            grouped.values(),
            key=lambda item: (
                item["owner_path"],
                item["dependency_path"],
                item["name"],
            ),
        )
        for dep in dependencies:
            dep["used_sources"].sort()

        targets.append(
            {
                "output": str(target.get("output", "")),
                "source": str(target.get("source", "")),
                "dependencies": dependencies,
            }
        )

    payload = {
        "schema": "brainboxemb.scad-build-dependency-provenance",
        "schema_version": 1,
        "source_revision": git(ROOT, "rev-parse", "HEAD"),
        "build_manifest": MANIFEST.relative_to(ROOT).as_posix(),
        "targets": targets,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Dependency provenance: {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
