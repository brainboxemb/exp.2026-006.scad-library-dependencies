# Transitive SCAD library dependencies PoP

Proof of Principle for transitive OpenSCAD library dependencies, bootstrap
behaviour, version pinning, desktop usability and dependency provenance.

Status: **active**

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

1. **DEP-01 — baseline direct bootstrap**
   - bootstrap this consumer using the released tooling;
   - retain evidence of which direct and nested dependencies exist afterward;
   - prove the current direct-only boundary.
2. **DEP-02 — transitive runtime/external closure**
   - prototype the smallest rule that follows intended library dependencies;
   - do not recursively initialize unrelated tooling/development dependencies.
3. **DEP-03 — desktop OpenSCAD**
   - after bootstrap, directly open a nested library SCAD entrypoint on Windows;
   - no permanent `OPENSCADPATH`, global library install or wrapper launch.
4. **DEP-04 — CI/build discovery**
   - prove the nested source participates correctly in SCAD dependency
     discovery and execution.
5. **DEP-05 — independent pins**
   - prove a consumer and a nested library can independently pin the same
     foundation library without ambiguous resolution.
6. **DEP-06 — status/update**
   - make nested state, desired refs and updates understandable and safe.
7. **DEP-07 — provenance**
   - retain the exact nested revisions actually used by build/publication
     evidence.

The qualification cases are acceptance boundaries around one dependency model;
they are not seven independent implementations.

## Current released baselines

```text
tool.git-project
  v0.2.8
  7c43f37e7b07cfb57638a1d1dad2501de09ba7eb

tool.scad-project
  v0.15.0
  78e26949c6f2397ed90bb7888c1386d3dd423312

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
