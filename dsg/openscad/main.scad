// Minimal direct consumer for the released lib.scad.mechint API.

use <ext/lib.scad.mechint/openscad/sliding-dovetail/sliding_dovetail.scad>

joint = sliding_dovetail_create(
    width = 10,
    height = 3,
    angle = 20,
    clearance = 0.20,
    axial_clearance = 0.25,
    extra = 0.01,
    locking = false
);

module baseline_consumer() {
    sliding_dovetail_male_build(joint, slide = 16);
}

baseline_consumer();
