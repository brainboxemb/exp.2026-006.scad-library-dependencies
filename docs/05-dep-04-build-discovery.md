# DEP-04 — nested SCAD build discovery

## Question

Does the normal SCons-backed SCAD build graph treat a transitive library source
as a real build input, rather than only as something bootstrap happens to make
available?

## Fixture

The lightweight target:

```text
dsg/openscad/dep04-nested-discovery.scad
  use <ext/lib.scad.mechint/main.scad>
```

emits only a 1 mm cube. The referenced released mechint entrypoint contains:

```text
use <ext/lib.scad.util/openscad/inspection.scad>
```

The existing baseline render remains a negative control: it consumes the public
mechint dovetail source, which does not depend on util.

## Acceptance

1. Root `bootstrap` prepares the qualified transitive external closure.
2. The first normal `scad-project build` records nested util `inspection.scad`
   in the DEP-04 target build-manifest sources.
3. The testcase temporarily changes only that nested util source.
4. The same normal build runs again.
5. Only `bld/stl/dep04-nested-discovery.stl` executes again.
6. The unrelated baseline PNG remains cached.
7. The util source is restored cleanly.

This proves precise transitive build invalidation rather than broad rebuilding.

## Status

Pending first qualifying run.
