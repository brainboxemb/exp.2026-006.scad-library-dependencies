# DEP-07 — exact build dependency provenance

## Question

Can normal SCAD build/publication evidence retain the exact revisions of the
external sources that a target actually used, including two owner-local copies
of the same repository at different revisions?

## Source of truth

DEP-07 reuses the normal SCons build manifest qualified by DEP-04. It does not
treat every initialized submodule as a build dependency.

For each target:

1. read the normal manifest's scanned `sources`;
2. traverse initialized owner-declared `role: external` dependencies;
3. attribute each external source to the deepest containing dependency worktree;
4. retain owner/path/name/repository/declared ref/exact HEAD plus the actual
   source files from that worktree used by the target.

The candidate evidence is written to
`bld/evidence/domain/dependency-provenance.json`, inside the normal Build
publication tree.

## Combined-pin acceptance

The normal SCons build includes the existing DEP-05 combined fixture as a build
target. Its provenance must independently identify direct mechint, project-owned
`lib.scad.util v0.2.0`, and mechint-owned nested
`lib.scad.util v0.1.0`.

The project-owned util must own the used `transform.scad`; the nested util must
own the used `inspection.scad`. Existing SCAD execution evidence separately
retains the exact project source revision and exact `tool.scad-project`
revision.

## Normal production integration

For the PoP, the experiment overrides only the `scad.build` command with a thin
project-owned wrapper. It executes the released `tool.scad-project` build
capability unchanged and then derives provenance from its generated manifest.
The provenance file is declared as a normal Moon build output.

This proves the production shape without modifying `tool.scad-project` during
the experiment. Moving the generator into that production owner is a later
rollout decision.

## Status

Pending first qualifying run.
