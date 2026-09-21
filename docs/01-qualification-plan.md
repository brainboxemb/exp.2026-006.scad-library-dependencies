# Qualification plan

This plan grows one architecture through increasingly realistic cases.

## DEP-01 — released direct-only baseline

Fixture:

```text
experiment
  -> lib.scad.mechint v0.1.6
       -> lib.scad.util v0.1.0
```

Actions:

- bootstrap a clean experiment checkout with released `tool.git-project`;
- record initialized direct dependencies;
- inspect
  `dsg/openscad/ext/lib.scad.mechint/ext/lib.scad.util`;
- open/build the experiment's simple public-mechint consumer;
- separately identify the nested mechint interactive entrypoint that requires
  util.

Expected baseline:

- direct experiment dependencies initialize normally;
- the nested util worktree is not initialized by the root's current direct-only
  bootstrap;
- this is retained as the before-state, not treated as an accidental test
  failure.

## DEP-02 — controlled transitive closure

Prototype the minimum traversal needed to initialize eligible nested library
dependencies.

Required properties:

- deterministic;
- owner-local refs remain authoritative;
- cycle-safe;
- no unrestricted recursive tooling initialization;
- works from a clean clone;
- Linux and Windows behaviour match where generic bootstrap is affected.

## DEP-03 — desktop OpenSCAD

After normal bootstrap, directly open the relevant nested library SCAD entrypoint
in Windows desktop OpenSCAD.

Pass criteria:

- required nested source resolves;
- no global library install;
- no permanent `OPENSCADPATH`;
- no machine-specific manual path setup;
- no special launcher solely for dependency resolution.

## DEP-04 — SCAD build discovery

Use the normal SCAD project execution path and prove nested dependencies are
discovered when source actually references them.

Separate bootstrap correctness from build dependency scanning; a green bootstrap
alone is not enough.

## DEP-05 — independent duplicate pins

Add a consumer-owned `lib.scad.util` pin in addition to the mechint-owned
nested pin.

Prove:

- both exact revisions can coexist;
- mechint resolves its own copy;
- the consumer resolves its own copy;
- no global path ordering silently aliases one to the other.

Use deliberately distinguishable revisions only when the testcase requires it.

## Normal developer entrypoint acceptance

The experiment-only `dep-0x-*` and `prototype/*` scripts are test harnesses, not
the intended developer interface. Before production adoption, the qualified
model must be reachable through the normal repository entrypoints:

```text
bootstrap.ps1 / bootstrap.sh
update-repo.ps1 / update-repo.sh
```

A consumer must not need to know that a transitive dependency closure exists or
run a separate dependency-specific script. The substantial traversal logic
belongs in `tool.git-project`; the root launchers remain thin delegates.

This requirement is exercised explicitly by DEP-06 and is a completion gate for
the PoP-to-production handoff.

## DEP-06 — status, update and normal entrypoints

Qualify understandable operations for the complete dependency closure.

Questions:

- how is nested desired-vs-current state reported?
- how are dirty nested worktrees protected?
- does updating one owner change only its owned pin?
- how are removed dependencies cleaned or reported?
- what happens when the same repository appears at two different nested paths?
- does a clean clone reach the complete qualified dependency state through only
  the normal root `bootstrap` launcher?
- does `update-repo` update/report the complete qualified dependency closure
  without a separate PoP/prototype command?

## DEP-07 — provenance

Retain machine-readable evidence identifying the actual nested source revisions
used by a build/publication.

The result should distinguish at least:

- root source revision;
- direct dependency revisions;
- nested dependency owner/path;
- nested exact revision.

## Completion condition

Experiment 006 is complete when these cases support one coherent dependency
contract or when a case demonstrates that the proposed architecture should be
rejected/revised.

Completion does not automatically authorize production rollout.
