// DEP-05 — two independent util owners in one OpenSCAD evaluation.
//
// Project-owned util v0.2.0 provides xf_move().
// Included mechint v0.1.6 resolves util_section_inspect() from its own
// nested util v0.1.0 through mechint/main.scad.

use <ext/lib.scad.util/openscad/transform.scad>
include <ext/lib.scad.mechint/main.scad>

xf_move([30, 0, 0])
    cube([2, 2, 2]);
