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
5. Every target that actually references that nested source executes again.
   With the later DEP-05 combined fixture present, that is exactly
   `dep04-nested-discovery.stl` and `dep05-independent-pins.stl`.
6. The unrelated baseline PNG remains cached.
7. The util source is restored cleanly.

This proves precise transitive build invalidation rather than broad rebuilding:
the expected dependent set can grow when a new real consumer is added, while
unrelated outputs remain current.

## Status

**Qualified.** Exact source `a6578ec7b07535b4e4fbd7f6501db111b29f4e7b`; DEP-04 run `35640296002` and normal SCAD production run `35640296729` are green. The nested util source is recorded as an SCons input. The original qualifying
fixture rebuilt only DEP-04; after DEP-05 became a normal build target, the
regression correctly expects both nested-util consumers and still requires the
unrelated baseline output to remain cached.
