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

**Qualified.** Exact source `de05e8872eaa0f6246b0d8acfb990bd148815507`.

Evidence:
- DEP-05 run `35641686171` — green;
- project util: `v0.2.0` / `da1892a201c3bfc78a65e10df84d4a8d142ae8f6`;
- mechint-owned nested util: `v0.1.0` / `5c88cd9b6b118d376825927ed67e26aff6eaee2d`;
- combined evaluation: PASS;
- project fallback to nested util: false;
- nested fallback to project util: false;
- DEP-01, DEP-02, DEP-03, DEP-04, normal entrypoints and SCAD production all green on the same source.
