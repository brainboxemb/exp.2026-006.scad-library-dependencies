# Target architecture

## Goal

Qualify a lightweight library-dependency model in which each reusable SCAD
library owns its own direct runtime dependencies.

The consumer should not need to flatten or duplicate another library's internal
dependency list.

## Desired ownership

```text
consumer
  project.yml
    owns consumer -> dependent-library

dependent-library
  project.yml
    owns dependent-library -> foundation-library

foundation-library
  owns its API only
```

For the first real baseline:

```text
experiment
  dsg/openscad/ext/lib.scad.mechint
    ext/lib.scad.util
```

The nested path is intentionally owned by `lib.scad.mechint`, not by the
experiment root.

## Bootstrap concept

The target is not equivalent to `git submodule update --init --recursive`.

A qualified bootstrap needs a controlled dependency closure:

1. restore the root's exact bootstrap-engine gitlink;
2. read and initialize the root's declared managed dependencies;
3. inspect an eligible consumed library's own generic dependency declaration;
4. follow only dependency classes that are intended to be runtime/external
   library requirements;
5. repeat until the closure is complete;
6. retain each owning repository's configured ref and exact gitlink.

Unrelated tooling/development dependencies inside a consumed library must not be
pulled merely because that library is embedded in a consumer.

## OpenSCAD path contract

The preferred path contract is repository-local:

```text
dependent library
  source
  ext/
    foundation library
```

A library source should be able to address its own dependency through a stable
path inside its checkout.

This keeps two independently pinned copies valid:

```text
consumer/
  dsg/openscad/ext/lib.scad.util        # consumer-owned pin, if needed
  dsg/openscad/ext/lib.scad.mechint/
    ext/lib.scad.util                   # mechint-owned pin
```

The PoP must not rely on search-path ordering to decide which copy wins.

## Metadata question

The current generic format already has `role: external`, but the Git layer
currently treats roles as generic purpose labels rather than runtime semantics.

Experiment 006 must determine whether:

- `role: external` is already precise enough for controlled transitive
  traversal; or
- a more explicit dependency property/category is required.

Do not extend the production schema until that distinction is proven necessary.

## Production handoff

If the architecture qualifies:

- generic traversal/bootstrap/status/update belongs in `tool.git-project`;
- SCAD build discovery changes, if any, belong in `tool.scad-project`;
- production libraries adopt the model through a later explicit migration.

The PoP repository remains evidence/regression material; it is not a production
dependency.
