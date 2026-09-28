# Kest's class shell (VISUAL-LANGUAGE.md section 9): a smaller scrap core inside an
# open icosahedral truss cage, three satchels girdled by horizontal amber bands (never
# diagonal stripes, which are hostile) with fuse tips, a short mortar tube in a
# recoil cradle, and a folded glide vane on top whose two blades hinge open. The dome
# sits forward and holds a bird pilot with a crest, goggles and a beak.
# Provenance: authored procedurally here from Blender primitives and bmesh operators;
# no external assets. Measured tris: shell 3820, pilot 592 (targets 3000 to 5000 and
# 400 to 800).
#
# Animated parts (shell_animator.gd): Satchel0..2 > Accent_special_smash_0..2 (bands and
# fuse tips), Mortar > Accent_weapon (the mouth), VaneL/VaneR, and Pilot > Head > Eyes,
# Crest.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part, Vector  # noqa: E402

DOME_C = (0.0, 0.2, 0.8)
DOME_R = 0.56
VANE_HINGE = (0.0, -0.32, 1.02)


def satchel(index, loc, yaw, canvas):
    """A satchel hung from its strap anchor, so it can swing; its bands and fuse tips
    are the accent device the special and smash slots light."""
    anchor = Vector((loc[0] * 0.7, loc[1] * 0.7, loc[2] + 0.12))
    bag = Part("Satchel%d" % index)
    m = common.mtx(loc, (0, 0, yaw))
    bag.box("paint", (0.3, 0.2, 0.26), loc=m @ Vector((0, 0, 0)), rot=(0, 0, yaw), color=canvas)
    bag.box("paint", (0.31, 0.12, 0.08), loc=m @ Vector((0, 0.05, 0.12)), rot=(0.3, 0, yaw), color="petrol")
    bag.rod("rubber", m @ Vector((0, -0.1, 0.1)), anchor, 0.02, 5)
    bands = Part("Accent_special_smash_%d" % index)
    for dz in (-0.07, 0.03):
        bands.box("class_accent", (0.32, 0.22, 0.045), loc=m @ Vector((0, 0, dz)), rot=(0, 0, yaw))
    for dx in (-0.07, 0.07):
        top = m @ Vector((dx, -0.03, 0.13))
        tip = m @ Vector((dx * 1.3, -0.05, 0.25))
        bag.rod("rubber", top, tip, 0.014, 5)
        bands.ico("class_accent", 0.028, 1, loc=tip)
    return [(bag, tuple(anchor), "Pod"), (bands, tuple(m @ Vector((0, 0, 0))), bag.name)]


def pod():
    p = Part("Pod")
    sb.saddle(p, center=(0.0, 0.14, 0.76), r_in=0.42, r_out=0.62, color="bone")
    parts = satchel(0, (0.8, -0.08, 0.66), math.pi / 2 + 0.2, "oxide")
    parts += satchel(1, (0.06, -0.8, 0.64), math.pi, "petrol")
    parts += satchel(2, (-0.74, 0.3, 0.62), -math.pi / 2 - 0.3, "oxide")
    base = Vector((-0.6, -0.42, 0.78))
    mouth = Vector((-0.66, -0.26, 1.2))
    mortar = Part("Mortar")
    mortar.rod("paint", base, mouth, 0.09, 10, color="oxide")
    mortar.rod("bare_metal", base - (mouth - base) * 0.12, base + (mouth - base) * 0.12, 0.11, 10)
    muzzle = Part("Accent_weapon")
    muzzle.ring("class_accent", 0.065, 0.115, 0.05, 10, loc=mouth,
                rot=(Vector((0, 0, 1)).rotation_difference((mouth - base).normalized())).to_euler())
    parts += [(mortar, tuple(base), "Pod"), (muzzle, tuple(mouth), "Mortar")]
    for side in (-1, 1):
        p.box("paint", (0.03, 0.26, 0.22), loc=base + Vector((side * 0.13, 0.02, 0.02)), color="petrol")
        p.rod("bare_metal", base + Vector((side * 0.13, -0.12, -0.06)), base + Vector((side * 0.13, -0.02, 0.2)),
              0.022, 6)
    p.beam("bare_metal", (-0.35, -0.2, 0.8), base, 0.06)
    # The vane's spine and struts; the blades are separate hinged objects.
    p.beam("bare_metal", (0, -0.2, 0.88), (0, -0.9, 0.9), 0.06, 0.05)
    p.beam("bare_metal", (0, -0.62, 0.9), (0, -0.62, 0.72), 0.05)
    return p, parts


def blade(name, side):
    """One vane blade standing folded; the hinge runs fore-aft along its base, and
    opening turns it 90 degrees outward about that axis (VaneL/VaneR, rotation y)."""
    b = Part(name)
    outline = [(0.1, 0.0), (-0.62, 0.0), (-0.7, 0.07), (-0.58, 0.3), (-0.02, 0.16)]
    m = common.mtx((side * 0.03, 0, 0), (0, -math.pi / 2, 0))
    yz = [(z, y) for y, z in outline]
    hinge = Vector(VANE_HINGE)
    b.prism("paint", yz, 0.028, matrix=common.mtx(hinge) @ m, color="bone")
    for y in (-0.1, -0.35):
        b.beam("bare_metal", hinge + Vector((side * 0.045, y, 0.01)), hinge + Vector((side * 0.045, y, 0.22)), 0.03)
    b.box("rubber", (0.05, 0.72, 0.04), loc=hinge + Vector((0, -0.27, 0.0)))
    return b


def pilot():
    f = Part("Pilot")
    crest_color = common.mix("oxide", "amber", 0.2)
    f.cyl("pilot", 0.25, 0.18, 0.16, 12, loc=(0, 0.18, 0.86), color="oxide")
    head = Part("Head")
    head.ico("pilot", 0.21, 2, loc=(0, 0.2, 1.06), scale=(1.0, 1.0, 0.95), color="bone")
    head.ico("pilot", 0.09, 1, loc=(0.1, 0.31, 0.99), color="sandstone")
    head.ico("pilot", 0.09, 1, loc=(-0.1, 0.31, 0.99), color="sandstone")
    beak = common.mix("amber", "sandstone", 0.35)
    head.rod("pilot", (0, 0.36, 1.02), (0, 0.52, 0.98), 0.065, 4, color=beak, r2=0.004)
    head.rod("pilot", (0, 0.35, 0.98), (0, 0.45, 0.96), 0.04, 4, color="charcoal", r2=0.004)
    eyes = Part("Eyes")
    for side in (-1, 1):
        sb.eye(eyes, (side * 0.085, 0.36, 1.1), 0.036)
        head.ring("pilot", 0.045, 0.075, 0.04, 8, loc=(side * 0.085, 0.37, 1.18), rot=(math.pi / 2 - 0.2, 0, 0),
                  color="charcoal")
        head.cyl("pilot", 0.05, 0.05, 0.02, 8, loc=(side * 0.085, 0.37, 1.18), rot=(math.pi / 2 - 0.2, 0, 0),
                 color=common.mix("bone", "ffffff", 0.5))
        f.prism("pilot", [(0, 0), (0.22, 0.04), (0.14, 0.12)], 0.04,
                matrix=common.mtx((side * 0.24, 0.12, 0.88), (math.pi / 2, 0, side * 0.5 + math.pi / 2)),
                color="sandstone")
    head.box("pilot", (0.24, 0.03, 0.03), loc=(0, 0.33, 1.2), color="charcoal")
    crest = Part("Crest")
    for k, (lean, h) in enumerate(((0.35, 0.3), (0.65, 0.26), (0.95, 0.2))):
        m = common.mtx((0, 0.12 - 0.04 * k, 1.2), (math.pi / 2, 0, math.pi / 2)) @ common.mtx((0, 0, 0), (0, 0, lean))
        crest.prism("pilot", [(-0.035, 0), (0.035, 0), (0.02, h * 0.8), (0, h)], 0.035, matrix=m, color=crest_color)
        tip = m @ Vector((0, h * 0.95, 0))
        crest.ico("pilot", 0.025, 1, loc=tip, color="charcoal")
    return f, [(head, (0, 0.2, 0.92), "Pilot"), (eyes, (0, 0.36, 1.1), "Head"), (crest, (0, 0.1, 1.2), "Head")]


def main():
    common.reset()
    common.preview_class("amber")
    rng = sb.rng_for("kest")
    core = Part("Core")
    sb.scrap_core(core, rng, radius=0.7, panels=20, bolts=16)
    sb.truss_cage(core, radius=0.95, width=0.05)
    glass = Part("Dome")
    sb.dome(glass, DOME_C, DOME_R)
    pod_part, pod_parts = pod()
    pilot_part, pilot_parts = pilot()
    root, core_obj, pilot_obj = sb.assemble("Kest", core, pod_part, glass, pilot_part, DOME_C,
                                            pod_parts + pilot_parts
                                            + [(blade("VaneL", -1), VANE_HINGE, "Pod"),
                                               (blade("VaneR", 1), VANE_HINGE, "Pod")])
    sb.finish("Kest", root, core_obj, pilot_obj)


main()
