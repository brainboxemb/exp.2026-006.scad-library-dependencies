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

**Qualified.**

Final qualifying source:
`16f36faf2ff9e2c19f5df6d23121c46ca9c33af4`.

Evidence:

- DEP-07 run `35645913457` — green;
- normal SCAD production run `35645914291` — green through Moon
  materialization, finishing and Build publication;
- project-owned `lib.scad.util v0.2.0`:
  `da1892a201c3bfc78a65e10df84d4a8d142ae8f6`;
- direct `lib.scad.mechint v0.1.6`:
  `bdd39925f2ad391b32fad7ba56770053d4d5e2bc`;
- mechint-owned nested `lib.scad.util v0.1.0`:
  `5c88cd9b6b118d376825927ed67e26aff6eaee2d`;
- exact `tool.scad-project` revision retained by execution evidence:
  `78e26949c6f2397ed90bb7888c1386d3dd423312`.

The first production attempt exposed only a Moon inheritance detail: a local
`command` appended to the inherited command. The final fixture uses a local
`script`, which replaces inherited command/args for the project task while
keeping the released build capability invocation inside the wrapper.

The qualified result was merged to main as
`035a9233f4ef99ad468c3ed0ab288f4772654922`.
