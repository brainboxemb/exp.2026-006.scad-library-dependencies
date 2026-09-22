# Transitive SCAD library dependencies PoP

Proof of Principle for transitive OpenSCAD library dependencies, bootstrap
behaviour, version pinning, desktop usability and dependency provenance.

Status: **complete**

Cross-project record:
`brainboxemb/brainboxemb.meta/experiments/006-transitive-scad-library-dependencies`.

## Current question

Can a reusable Brainboxemb SCAD library own and pin another SCAD library as a
runtime/external dependency while remaining simple to consume?

The required developer experience is:

```text
clone / checkout
        ↓
bootstrap
        ↓
open the relevant .scad directly in desktop OpenSCAD
        ↓
works without global OPENSCADPATH or manual library installation
```

## Baseline dependency chain

The first fixture deliberately starts from the current released production
relationship rather than an invented library:

```text
exp.2026-006.scad-library-dependencies
    consumer fixture
    |
    +-- lib.scad.mechint v0.1.6
            exact bdd39925f2ad391b32fad7ba56770053d4d5e2bc
            |
            +-- lib.scad.util v0.1.0
                    exact 5c88cd9b6b118d376825927ed67e26aff6eaee2d
```

The experiment consumer declares only `lib.scad.mechint`. It intentionally does
**not** declare `lib.scad.util` directly.

That matters because the current generic repository contract initializes direct
dependencies only. The nested `lib.scad.util` gitlink belongs to
`lib.scad.mechint`, so the first testcase establishes the current behaviour
before any transitive-bootstrap prototype is added.

## Why the real mechint relationship comes first

`lib.scad.mechint v0.1.6` already declares `lib.scad.util` as an external
dependency for verification and interactive inspection. Its public dovetail
source itself remains dependency-free.

That gives the PoP two clean stages:

1. prove nested bootstrap/path behaviour using the real released
   `mechint -> util` ownership relationship;
2. once that mechanism is understood, add the smallest experiment-owned
   runtime-dependent library fixture needed to prove the stronger production
   contract.

Do not modify `lib.scad.mechint` merely to manufacture a PoP dependency.

## Experiment sequence

The work is architecture-first rather than a collection of unrelated checks:

1. **DEP-01 — baseline direct bootstrap — qualified**
   - released direct-only behaviour proved on Linux and Windows;
   - merged baseline `8cc2f7d25b6a66544c7802af7da7664fc625a9c9`.
2. **DEP-02 — transitive runtime/external closure — qualified**
   - controlled `role: external` traversal proved on Linux and Windows;
   - nested tooling remains uninitialized;
   - merged baseline `5385f797ea549c39f075da11e3fa838350e5e44c`.
3. **DEP-03 — desktop OpenSCAD — qualified**
   - library-local resolution proved in CI with an empty `OPENSCADPATH`;
   - direct nested `lib.scad.mechint/main.scad` open + F6 passed in Windows desktop OpenSCAD on 2026-09-21;
   - no global library install or wrapper launch.
4. **DEP-04 — CI/build discovery — qualified**
   - nested util is recorded as a precise SCons input and invalidates only its dependent target;
   - normal reusable SCAD production is green with the SCons build graph;
   - merged baseline `a6bf46d4a024e81b6d5f7f1330f57a8fadd1312c`.
5. **DEP-05 — independent pins — qualified**
   - project-owned `lib.scad.util v0.2.0` and mechint-owned nested `v0.1.0` coexist;
   - both owner-local paths are present in the dependency graph;
   - combined OpenSCAD evaluation succeeds with empty `OPENSCADPATH`;
   - hiding either owner-local source fails at that owner instead of falling back to the other copy.
6. **DEP-06 — status/update — qualified**
   - full owner/path/ref status is available through the normal update entrypoint;
   - dirty nested dependencies block update;
   - owner-specific pin changes remain independent;
   - uninitialized nested dependencies are reported and restored by normal update;
   - unrelated local paths are not silently removed.
7. **DEP-07 — provenance — qualified**
   - normal SCons target provenance retains only dependencies actually present in
     the target source graph;
   - project-owned `lib.scad.util v0.2.0`, direct `lib.scad.mechint v0.1.6`
     and mechint-owned nested `lib.scad.util v0.1.0` remain independently
     identifiable by owner/path/ref/exact revision;
   - normal Moon/SCAD production retains the provenance file inside the Build
     publication tree.

The qualification cases are acceptance boundaries around one dependency model;
they are not seven independent implementations.

## Normal developer flow

The dependency-specific `scripts/dep-0x-*` and `prototype/*` files are experiment
test harnesses. A normal user works through the root entrypoints:

```text
bootstrap.ps1 / bootstrap.sh
update-repo.ps1 / update-repo.sh
```

In the experiment these entrypoints now add the qualified transitive external
closure after the released generic direct dependency operation. This is the
candidate user experience; the substantial traversal logic still needs to move
into `tool.git-project` before production adoption.

## Completion

Experiment 006 is complete. Final qualification source
`16f36faf2ff9e2c19f5df6d23121c46ca9c33af4` passed DEP-01 through DEP-07;
DEP-07 run `35645913457` and normal SCAD production run `35645914291` are
green. The qualified result was merged to main as
`035a9233f4ef99ad468c3ed0ab288f4772654922`.

The repository remains a reusable regression lab. Migration 008 has since
completed production adoption. Migration 009 reuses this repository to qualify
the corrected SCAD production/update stack against the retained DEP-01 through
DEP-07 acceptance boundary.

## Migration 009 regression

Migration 009 requalifies this retained lab on released `tool.scad-project
v0.15.7`. The release contains both production-branch serialization and the
restored read-only `update-repo status` contract that DEP-06 exposed while
qualifying v0.15.6.

## Current released baselines

```text
tool.git-project
  v0.2.9
  9879da589101f41b2b0e634d196ddcc51e1a6102

tool.scad-project
  v0.15.7
  bfaac9f6916c09bc6525abddf64c87238fe59103

lib.scad.mechint
  v0.1.6
  bdd39925f2ad391b32fad7ba56770053d4d5e2bc

lib.scad.util nested in mechint v0.1.6
  v0.1.0
  5c88cd9b6b118d376825927ed67e26aff6eaee2d
```

## Repository boundaries

This repository owns the fixture, PoP prototypes and retained evidence.

Potential production owners remain separate:

- `tool.git-project` — generic dependency/bootstrap/status/update behaviour;
- `tool.scad-project` — SCAD dependency discovery/build integration when needed;
- `lib.scad.util` — candidate lightweight foundation library;
- reusable libraries such as `lib.scad.mechint` — direct dependency intent;
- product consumers such as HUB75 — project-specific integration.

A successful PoP may support a later migration. It does not itself authorize a
production rollout.
