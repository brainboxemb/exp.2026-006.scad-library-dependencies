# DEP-01 — released direct-only baseline

## Question

What does the released repository bootstrap do when a direct SCAD library
contains its own declared external dependency?

## Fixture

```text
Experiment 006
├── tools/tool.git-project
├── tools/tool.scad-project
└── dsg/openscad/ext/lib.scad.mechint
    ├── tools/tool.git-project
    ├── tools/tool.scad-project
    └── ext/lib.scad.util
```

The root declares only the three direct entries at the first level. The nested
three entries belong to `lib.scad.mechint v0.1.6`.

## Released behaviour under test

`tool.git-project v0.2.8` reads the root `project.yml` and initializes each
declared root dependency individually with non-recursive submodule operations.

DEP-01 therefore expects:

| path | expected state after root bootstrap |
| --- | --- |
| `tools/tool.git-project` | initialized |
| `tools/tool.scad-project` | initialized |
| `dsg/openscad/ext/lib.scad.mechint` | initialized |
| `.../lib.scad.mechint/ext/lib.scad.util` | gitlink present, worktree uninitialized |
| `.../lib.scad.mechint/tools/tool.git-project` | gitlink present, worktree uninitialized |
| `.../lib.scad.mechint/tools/tool.scad-project` | gitlink present, worktree uninitialized |

This is the intentional **before-state** for Experiment 006.

## Why the tooling gitlinks matter

A later transitive implementation must not simply turn on unrestricted recursive
submodules.

The desired DEP-02 change is narrower:

```text
mechint/ext/lib.scad.util
    uninitialized -> initialized

mechint/tools/tool.git-project
mechint/tools/tool.scad-project
    remain uninitialized
```

That distinction is the core reason for qualifying a controlled dependency
closure instead of `git submodule update --recursive`.

## Automated evidence

`.github/workflows/dep-01-baseline.yml` runs the same baseline on:

- Ubuntu 24.04 through the POSIX bootstrap launcher;
- Windows Server 2025 through the PowerShell bootstrap launcher.

Each job asserts exact gitlinks/revisions and writes a machine-readable
`dep-01-baseline.json` into the GitHub Actions run summary.

The normal SCAD production workflow runs separately against the same source and
builds the minimal public `lib.scad.mechint` consumer. That confirms the
before-state is a real CAD consumer rather than only a synthetic Git test.

Run IDs and the exact qualifying source commit are added here after the first
green execution.
