# Repository agent guidance

Persistent guidance for work in
`brainboxemb/exp.2026-006.scad-library-dependencies`.

## Repository role

This repository is the implementation/evidence workspace for Experiment 006:
transitive SCAD library dependencies.

It exists to qualify one dependency architecture before changing shared
production owners.

The current baseline is:

```text
experiment consumer
    -> lib.scad.mechint v0.1.6
         -> lib.scad.util v0.1.0
```

The experiment consumer must not add `lib.scad.util` as a direct dependency
merely to make bootstrap or OpenSCAD resolution succeed. Doing so would bypass
the question being tested.

## Ownership boundary

Keep production ownership separate:

- generic bootstrap/dependency semantics belong in `tool.git-project`;
- SCAD build/discovery semantics belong in `tool.scad-project`;
- reusable utility API belongs in `lib.scad.util`;
- mechanical-interface API belongs in `lib.scad.mechint`;
- HUB75 remains a product consumer.

Prototype logic may live here long enough to qualify behaviour. Do not silently
turn an experiment workaround into a production contract.

The `dep-0x-*` and `prototype/*` scripts are test harnesses only. They must not
become the normal consumer UX. The qualified end state is thin root
`bootstrap.*` / `update-repo.*` launchers delegating all substantial transitive
dependency handling to `tool.git-project`.

## Baseline before correction

DEP-01 must retain the released direct-only behaviour before a transitive
prototype is introduced.

The current generic contract intentionally initializes direct dependencies only.
The experiment should make the resulting nested state explicit rather than
pre-fixing it.

## Dependency rule under qualification

The intended direction is a controlled closure, not unrestricted recursive
submodules.

Candidate model:

```text
runtime/external library dependency
    -> eligible to follow transitively

tooling/development dependency
    -> do not initialize merely because a consumed library declares it
```

Whether existing `role: external` metadata is sufficient is itself part of the
PoP. Do not freeze that assumption prematurely.

## Desktop constraint

A qualified model must allow the relevant nested library SCAD source to be
opened directly in Windows desktop OpenSCAD after normal bootstrap.

Do not solve that testcase by requiring:

- a global library installation;
- a permanent `OPENSCADPATH`;
- manual machine-specific path configuration;
- a wrapper process solely to make ordinary library imports resolve.

## Evidence discipline

Prefer exact, reproducible evidence for each architecture step:

- exact root source commit;
- exact direct and nested gitlink revisions;
- bootstrap command/result;
- resulting dependency tree;
- OpenSCAD command or desktop testcase;
- CI/build result where applicable.

A failed testcase is valid evidence. Do not weaken a testcase merely to produce
a green run.

## Current exact baseline

```text
tool.git-project
7c43f37e7b07cfb57638a1d1dad2501de09ba7eb

tool.scad-project
78e26949c6f2397ed90bb7888c1386d3dd423312

lib.scad.mechint v0.1.6
bdd39925f2ad391b32fad7ba56770053d4d5e2bc

nested lib.scad.util v0.1.0
5c88cd9b6b118d376825927ed67e26aff6eaee2d
```

## Commit and CI discipline

Treat a branch update as a CI boundary.

For one coherent work unit:

1. inspect current sources;
2. prepare related edits together;
3. re-read the complete changed set;
4. create one commit when the available Git tooling permits;
5. advance the branch once;
6. inspect the resulting CI/evidence before the next correction.

Use the normal issue -> `feature/pr-N-...` -> draft PR flow.
