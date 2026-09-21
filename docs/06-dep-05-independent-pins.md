# DEP-05 — independent project and library util pins

## Layout

```text
experiment
├── dsg/openscad/ext/lib.scad.util        v0.2.0
└── dsg/openscad/ext/lib.scad.mechint     v0.1.6
    └── ext/lib.scad.util                  v0.1.0
```

The root project owns the v0.2.0 pin. Mechint independently owns its nested v0.1.0 pin.

## Runtime fixture

`dep05-independent-pins.scad` uses project-owned `xf_move()` from v0.2.0 and includes the real mechint interactive entrypoint, whose default lock-section uses `util_section_inspect()` from mechint's nested v0.1.0.

The combined file is evaluated to CSG with an empty `OPENSCADPATH`.

## Anti-fallback probes

The testcase deliberately hides each owner-local source in turn:

- hide project `transform.scad`: project-side resolution must fail instead of finding some nested copy;
- restore it and hide mechint's nested `inspection.scad`: mechint must fail instead of falling back to the project-owned util tree.

With both files restored, combined evaluation must pass and both submodule worktrees must be clean.

## Status

Pending first qualifying run.
