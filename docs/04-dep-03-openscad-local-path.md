# DEP-03 — direct OpenSCAD library-local dependency resolution

## Question

After the controlled dependency closure has initialized a reusable library's
own dependency, can that library be opened directly in OpenSCAD without a
global library installation, permanent `OPENSCADPATH`, or wrapper-based path
setup?

## Real entrypoint

The testcase uses the released `lib.scad.mechint v0.1.6` interactive file:

```text
dsg/openscad/ext/lib.scad.mechint/main.scad
```

That file contains:

```openscad
use <ext/lib.scad.util/openscad/inspection.scad>
```

and its default `lock-section` view actually calls `util_section_inspect()`.
The testcase therefore requires the nested utility library at runtime; it is
not merely checking that an unused include happens to parse.

## Automated engine proof

`DEP-03 OpenSCAD local path` first replays DEP-02, then runs the released
`scad-toolchain-openscad:v0.6.1` engine directly against the nested
`lib.scad.mechint/main.scad`.

The invocation deliberately removes two possible accidental resolution paths:

- Docker working directory is `/tmp`, not the experiment root or mechint root;
- `OPENSCADPATH` is explicitly empty.

A pass requires:

- OpenSCAD exit code 0;
- a non-empty STL;
- no missing include/use warning;
- exact mechint and util revisions retained in machine-readable evidence.

This proves the OpenSCAD engine can resolve mechint's dependency through the
library-local checkout layout.

## Windows local helper

From a normal Windows checkout of this branch/repository:

```powershell
.\scripts\dep-03-windows-desktop.ps1
```

The helper prepares the same controlled closure. If a local `openscad.exe` is
discoverable, it also performs a CLI render with `OPENSCADPATH` empty.

The helper then prints the exact nested file path for the desktop gate.

## Manual Windows desktop gate

The automated engine proof and optional Windows CLI proof do **not** close
DEP-03. The desktop requirement remains:

1. start normal OpenSCAD from the Windows Start menu/desktop, not a wrapper;
2. use **File > Open** on the exact nested `lib.scad.mechint/main.scad` printed
   by the helper;
3. press **F6**;
4. confirm the default lock-section renders;
5. confirm there is no missing `lib.scad.util` / `inspection.scad` warning.

Only that direct desktop result closes the desktop portion of DEP-03.

## Status

- Automated engine/path proof: **pending first CI evidence**.
- Windows desktop proof: **manual gate pending**.
