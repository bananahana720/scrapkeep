# Hero sphere blockouts (design-v2/HERO-SPHERE.md): a true glass sphere the pilot sits
# inside, upright on a gyro cradle, with orbit rings outside that carry the class shape
# and make momentum visible. Concept ground truth for readability at the game camera;
# not a runtime asset (no export). Provenance: authored procedurally from Blender
# primitives through tools/blender/common.py; no external assets.
#
# Node contract proposed for hero_assets.gd (HERO-SPHERE.md section 9):
#   Shell<Class> (root)
#     Hull    rolls with the ball: glass sphere plus great-circle seams
#     Cradle  upright, yaws to the heading: gimbals, seat, the heart, Pilot, kit sockets
#     Rig     the orbit rings, steered by velocity and state: Ring0..n, each with plates
#
# Run headless:
#   blender -b --factory-startup -P hero_sphere.py -- --render DIR \
#       [--set sable:1:rest,rivet:3:rolling,patch:3:formA,...|all] [--lineup 1:rest,5:boost]
# Blender +Z is up, +Y is forward (chase cam at yaw 0 looks from behind).
#
# Patch, the fourth pilot (an unlock), borrows one class row per slot, so its rings and
# sockets transmog: ring 0 wears the weapon slot's class shape, ring 1 the movement
# slot's, ring 2 the special slot's. FORMS names the (weapon, movement, special) classes.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from common import Part  # noqa: E402

HULL_R = 0.99
RING_R = (1.10, 1.21, 1.32)
MAX_TILT = 0.70  # rad; 1.44 m * sin(0.70) = 0.93 m < 1.0 m, so no orbit ring touches the ground

CLASSES = {
    "sable": {"color": "mint", "rim": "pips", "fur": "oxide"},
    "rivet": {"color": "copper", "rim": "chevron", "fur": "8a7a6a"},
    "kest": {"color": "amber", "rim": "spikes", "fur": "d2c5a5"},
    "patch": {"color": "bone", "rim": "groove", "fur": None},
}

# Patch's forms: which class row fills (weapon, movement, special).
FORMS = {
    "formA": ("rivet", "sable", "kest"),
    "formB": ("kest", "rivet", "sable"),
    "glitch": ("patch", "patch", "patch"),
}

# heft class -> (orbit rings, plates per ring, gimbal width, core radius, armour bands)
HEFT = {
    1: (1, 0, 0.05, 0.16, 0),
    2: (1, 3, 0.06, 0.18, 0),
    3: (2, 3, 0.07, 0.21, 0),
    4: (2, 5, 0.08, 0.24, 1),
    5: (3, 5, 0.09, 0.28, 2),
}

# state -> (pitch per ring, roll per ring, radius spread, knocked ring or None)
STATES = {
    "rest": ((0.10, 0.34, -0.28), (0.0, 0.30, 0.50), 0.0, None),
    "rolling": ((-0.42, -0.48, -0.36), (0.10, -0.22, 0.30), 0.0, None),
    "boost": ((-0.62, -0.66, -0.58), (0.06, -0.14, 0.20), 0.12, None),
    "airborne": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 0.05, None),
    "hit": ((0.10, 0.34, -0.28), (0.0, 0.30, 0.50), 0.0, 0),
    # Patch: forms roll; the glitch is the gyro failing (rings adrift, one dark).
    "formA": ((-0.42, -0.48, -0.36), (0.10, -0.22, 0.30), 0.0, None),
    "formB": ((-0.42, -0.48, -0.36), (0.10, -0.22, 0.30), 0.0, None),
    "glitch": ((0.30, -0.55, 0.20), (0.45, 0.10, -0.35), 0.0, 1),
}


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"render": None, "set": "all", "lineup": ""}
    i = 0
    while i < len(argv):
        key = argv[i][2:]
        if key in out and i + 1 < len(argv):
            out[key] = argv[i + 1]
            i += 2
        else:
            i += 1
    return out


def slot_classes(cls, state):
    """(weapon, movement, special) class per slot: a pilot's own class, or Patch's form."""
    if cls == "patch":
        return FORMS.get(state, FORMS["glitch"])
    return (cls, cls, cls)


# --- hull ------------------------------------------------------------------------------

def hull(cls):
    # Preview only: the runtime glass alpha is hero_assets.gd's; the blockout hull
    # needs a firmer edge so the sphere reads at 8 m.
    common.SLOTS["glass"]["alpha"] = 0.18
    h = Part("Hull")
    h.uv("glass", HULL_R, 28, 18)
    # Three great-circle seams and a few salvaged hex tiles: the only hull marks, so
    # the roll itself is readable (a basketball's lines).
    h.ring("bare_metal", HULL_R - 0.02, HULL_R + 0.015, 0.045, 40, rot=(math.pi / 2, 0, 0))
    h.ring("bare_metal", HULL_R - 0.02, HULL_R + 0.015, 0.045, 40, rot=(0, math.pi / 2, 0))
    h.ring("rubber", HULL_R - 0.015, HULL_R + 0.01, 0.03, 40, rot=(0, 0, 0))
    for k in range(6):
        a = k * math.tau / 6 + 0.5
        n = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.6 if k % 2 else -0.6)).normalized()
        loc = n * (HULL_R - 0.01)
        rot = n.to_track_quat("Z", "Y").to_euler()
        h.cyl("paint", 0.11, 0.11, 0.03, 6, loc=loc, rot=rot, color=("petrol", "oxide", "bone")[k % 3])
        h.bolt(loc + n * 0.015, n, r=0.02)
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        h.bolt((HULL_R * math.cos(a), 0.0, HULL_R * math.sin(a)), (math.cos(a), 0.0, math.sin(a)), r=0.03)
    if cls == "patch":
        # A dead ancient seam, unlit: a charcoal groove where a light used to be.
        h.ring("rubber", HULL_R - 0.01, HULL_R + 0.015, 0.02, 40, rot=(0.6, 0.0, 0.0))
    return h


# --- cradle ----------------------------------------------------------------------------

def gimbals(c, width, accent=True):
    c.ring("bare_metal", 0.86 - width, 0.86, width, 32, rot=(0, math.pi / 2, 0))
    c.ring("bare_metal", 0.76 - width, 0.76, width, 32, rot=(math.pi / 2, 0, 0))
    if accent:
        c.ring("class_accent", 0.76 - width - 0.015, 0.76 - width, width * 0.6, 32, rot=(math.pi / 2, 0, 0))
    for p, n in (((0, 0, 0.86), (0, 0, 1)), ((0, 0, -0.86), (0, 0, -1)),
                 ((0.76, 0, 0), (1, 0, 0)), ((-0.76, 0, 0), (-1, 0, 0))):
        c.cyl("rubber", 0.07, 0.07, 0.06, 8, loc=p, rot=(0, math.pi / 2, 0) if p[0] else (0, 0, 0))
        c.bolt(p, n, r=0.03, h=0.03)


def core(c, radius, cls):
    # The gyro flywheel under the seat: the mint intake ring is the shared collection
    # field, the heart is the class light. Heft brightens by growing the heart.
    c.ring("field", 0.30, 0.44, 0.08, 20, loc=(0, 0, -0.52))
    c.ring("rubber", 0.44, 0.47, 0.05, 20, loc=(0, 0, -0.52))
    c.cyl("bare_metal", 0.10, 0.10, 0.20, 8, loc=(0, 0, -0.52))
    if cls == "patch":
        c.ico("ancient_enamel", radius, 2, loc=(0, 0, -0.52), color="2e4644")
        c.ring("rubber", radius - 0.01, radius + 0.015, 0.02, 20, loc=(0, 0, -0.52), rot=(0.3, 0, 0))
    c.ico("class_accent", radius, 2, loc=(0, 0, -0.52))


def seat(c, cls):
    if cls == "kest":
        c.rod("bare_metal", (-0.34, 0.02, -0.22), (0.34, 0.02, -0.22), 0.035, 8)
        for x in (-0.3, 0.3):
            c.rod("bare_metal", (x, 0.02, -0.22), (x * 0.6, 0.0, -0.44), 0.025, 6)
        return
    c.box("paint", (0.52, 0.5, 0.1), loc=(0, -0.02, -0.30), color="petrol")
    c.box("paint", (0.52, 0.08, 0.42), loc=(0, -0.27, -0.08), color="petrol")
    if cls == "sable":
        c.box("paint", (0.46, 0.42, 0.04), loc=(0, 0.0, -0.24), color="bone")  # felt


def pilot_fox(p):
    p.cyl("pilot", 0.24, 0.17, 0.34, 10, loc=(0, -0.02, -0.06), color="petrol")
    p.ico("pilot", 0.2, 2, loc=(0, 0.02, 0.24), scale=(1.05, 0.95, 0.9), color="oxide")
    p.rod("pilot", (0, 0.1, 0.2), (0, 0.32, 0.17), 0.08, 6, color="bone", r2=0.03)
    p.ico("pilot", 0.03, 1, loc=(0, 0.33, 0.18), color="charcoal")
    for s in (-1, 1):
        p.uv("pilot", 0.035, 6, 4, loc=(s * 0.075, 0.17, 0.28), color="charcoal")
        m = common.mtx((s * 0.11, 0.0, 0.34), (math.pi / 2, s * -0.3, 0))
        p.prism("pilot", [(-0.07, 0), (0.07, 0), (0, 0.2)], 0.04, matrix=m, color="oxide")
        p.prism("pilot", [(-0.02, 0.14), (0.02, 0.14), (0, 0.2)], 0.05, matrix=m, color="charcoal")
    p.cyl("pilot", 0.1, 0.09, 0.06, 10, loc=(0, -0.04, 0.42), color="petrol")
    p.box("pilot", (0.15, 0.1, 0.02), loc=(0, 0.07, 0.41), rot=(-0.15, 0, 0), color="petrol")
    # The tail wraps the seat edge, so the fox reads as curled in, not perched.
    p.rod("pilot", (0.2, -0.2, -0.2), (0.42, 0.1, -0.16), 0.06, 6, color="oxide", r2=0.05)
    p.rod("pilot", (0.42, 0.1, -0.16), (0.36, 0.34, -0.1), 0.05, 6, color="bone", r2=0.02)


def pilot_mole(p, fur):
    p.cyl("pilot", 0.26, 0.2, 0.30, 10, loc=(0, -0.02, -0.08), color="petrol")
    p.ico("pilot", 0.21, 2, loc=(0, 0.02, 0.2), scale=(1.1, 1.0, 0.85), color=fur)
    p.box("pilot", (0.3, 0.06, 0.08), loc=(0, 0.19, 0.24), color="charcoal")  # visor
    p.box("class_accent", (0.26, 0.02, 0.03), loc=(0, 0.225, 0.24))
    p.rod("pilot", (0, 0.12, 0.16), (0, 0.3, 0.12), 0.07, 6, color=fur, r2=0.04)
    p.ico("pilot", 0.04, 1, loc=(0, 0.31, 0.12), color="oxide")
    p.rod("pilot", (0.14, 0.15, 0.24), (0.3, -0.05, 0.0), 0.014, 6, color="charcoal")  # cable
    for s in (-1, 1):
        p.ico("pilot", 0.06, 1, loc=(s * 0.24, 0.05, 0.0), scale=(1.4, 1.0, 0.6), color="bone")  # claws


def pilot_bird(p):
    p.cyl("pilot", 0.15, 0.11, 0.34, 8, loc=(0, 0.0, 0.04), color="petrol")
    p.ico("pilot", 0.17, 2, loc=(0, 0.02, 0.33), scale=(0.95, 1.0, 0.95), color="d2c5a5")
    p.rod("pilot", (0, 0.13, 0.31), (0, 0.32, 0.26), 0.05, 6, color="amber", r2=0.01)
    for s in (-1, 1):
        p.uv("pilot", 0.03, 6, 4, loc=(s * 0.07, 0.15, 0.36), color="charcoal")
        p.ring("pilot", 0.035, 0.055, 0.03, 8, loc=(s * 0.08, 0.1, 0.46), rot=(0.9, 0, 0), color="charcoal")
        p.rod("pilot", (s * 0.15, 0.0, 0.12), (s * 0.3, -0.05, -0.18), 0.03, 6, color="d2c5a5", r2=0.015)
    for k in range(3):  # crest
        m = common.mtx((0, -0.08 - k * 0.05, 0.44 + k * 0.03), (math.pi / 2, 0, 0))
        p.prism("pilot", [(-0.03, 0), (0.03, 0), (0, 0.16)], 0.02, matrix=m, color="oxide")
    p.rod("pilot", (-0.08, 0.02, -0.14), (-0.08, 0.02, -0.22), 0.02, 6, color="amber")  # feet on the perch
    p.rod("pilot", (0.08, 0.02, -0.14), (0.08, 0.02, -0.22), 0.02, 6, color="amber")


def pilot_patch(p, glitch=False):
    # No animal: the housing is the pilot. Seamless enamel, one dead groove, one lens,
    # and salvaged arms the tribes bolted on. The glitch is a lens gone wide and a brow
    # bar askew: an error face, never a creepy one.
    p.ico("ancient_enamel", 0.30, 2, loc=(0, 0.0, 0.18), scale=(1.0, 1.0, 1.15), color="2e4644")
    p.ring("rubber", 0.29, 0.315, 0.02, 24, loc=(0, 0, 0.18), rot=(0.5, 0, 0))
    p.ring("rubber", 0.29, 0.315, 0.02, 24, loc=(0, 0, 0.18), rot=(0, 0.5, 0))
    lens_r = 0.085 if glitch else 0.06
    p.cyl("bare_metal", 0.10, 0.08, 0.06, 10, loc=(0, 0.29, 0.22), rot=(math.pi / 2, 0, 0))
    p.ico("class_accent", lens_r, 1, loc=(0, 0.32, 0.22))
    brow = (0, 0, 0.35) if glitch else (0, 0, 0)
    p.box("bare_metal", (0.22, 0.03, 0.04), loc=(0, 0.31, 0.33), rot=brow)
    for s in (-1, 1):
        arm_tip = (s * 0.4, 0.1, -0.2) if not glitch or s < 0 else (s * 0.45, -0.1, 0.25)  # one arm up: "wait"
        p.rod("bare_metal", (s * 0.28, 0.0, 0.1), arm_tip, 0.03, 6)
        p.bolt((s * 0.28, 0.0, 0.1), (s, 0, 0), r=0.03)


def socket_weapon(c, cls):
    """The weapon slot's device on the cradle: rail, spool-side caster prong, or mortar."""
    if cls == "sable":
        c.rod("bare_metal", (-0.3, 0.2, 0.05), (-0.45, 0.8, 0.15), 0.03, 6)
        c.ico("class_accent", 0.05, 1, loc=(-0.46, 0.83, 0.16), scale=(1, 1, 1.6))
    elif cls == "rivet":
        c.rod("bare_metal", (0.26, -0.15, 0.02), (0.26, 0.93, 0.02), 0.03, 6)
        c.ico("class_accent", 0.055, 1, loc=(0.26, 0.93, 0.02))
    elif cls == "kest":
        c.cyl("bare_metal", 0.07, 0.07, 0.4, 10, loc=(0.36, 0.45, 0.1), rot=(-0.9, 0, 0))
        c.ring("class_accent", 0.06, 0.085, 0.03, 10, loc=(0.36, 0.61, 0.22), rot=(-0.9, 0, 0))
        c.box("bare_metal", (0.14, 0.14, 0.1), loc=(0.36, 0.3, -0.02))


def socket_movement(c, cls):
    """The movement slot's device: rope spool, sprint stacks and fins, or the blink vent."""
    if cls == "sable":
        c.cyl("paint", 0.12, 0.12, 0.16, 10, loc=(0.6, -0.1, -0.15), rot=(0, math.pi / 2, 0), color="bone")
        for dx in (-0.09, 0.09):
            c.cyl("bare_metal", 0.17, 0.17, 0.03, 10, loc=(0.6 + dx, -0.1, -0.15), rot=(0, math.pi / 2, 0))
        c.rod("bare_metal", (0.6, 0.05, -0.15), (0.82, 0.32, -0.02), 0.025, 6)
        c.ring("bare_metal", 0.035, 0.065, 0.04, 8, loc=(0.84, 0.35, 0.0), rot=(0.9, -0.4, 0))
    elif cls == "rivet":
        for x in (-0.36, -0.14, 0.14, 0.36):
            c.box("class_accent", (0.035, 0.3, 0.12), loc=(x, -0.62, 0.06), rot=(-0.7, 0, 0))
        for x in (-0.2, 0.2):
            c.cyl("bare_metal", 0.045, 0.045, 0.36, 8, loc=(x, -0.5, 0.42))
            c.cyl("rubber", 0.055, 0.055, 0.04, 8, loc=(x, -0.5, 0.6))
    elif cls == "kest":
        c.cyl("bare_metal", 0.09, 0.07, 0.14, 8, loc=(-0.55, -0.35, -0.25), rot=(0.6, -0.6, 0))
        c.ring("class_accent", 0.06, 0.09, 0.02, 8, loc=(-0.6, -0.4, -0.3), rot=(0.6, -0.6, 0))


def socket_special(c, cls):
    """The special slot's device: pylon mast, blast capacitor, or line spool of fuses."""
    if cls == "sable":
        c.rod("bare_metal", (0, -0.55, -0.45), (0, -0.62, 0.5), 0.04, 6, r2=0.03)
        c.ico("class_accent", 0.07, 1, loc=(0, -0.62, 0.56), scale=(1, 1, 1.5))
    elif cls == "rivet":
        c.cyl("paint", 0.09, 0.09, 0.26, 8, loc=(-0.5, -0.4, 0.1), rot=(0.4, 0.3, 0), color="oxide")
        c.ring("class_accent", 0.09, 0.11, 0.03, 8, loc=(-0.5, -0.4, 0.1), rot=(0.4, 0.3, 0))
    elif cls == "kest":
        for k in range(3):
            c.box("paint", (0.06, 0.12, 0.05), loc=(-0.5 + k * 0.1, -0.5, 0.3), color="bone")
            c.box("class_accent", (0.065, 0.13, 0.015), loc=(-0.5 + k * 0.1, -0.5, 0.3))


def kit(c, cls, state):
    weapon, movement, special = slot_classes(cls, state)
    if cls == "rivet":
        # The bucket stays below shoulder height so the visor is findable from the chase cam.
        c.ring("paint", 0.56, 0.62, 0.38, 20, loc=(0, 0, -0.16), color="petrol", arc=(math.pi * 1.2, math.pi * 1.8))
    socket_weapon(c, weapon)
    socket_movement(c, movement)
    socket_special(c, special)


def cradle(cls, heft, state):
    rings, _, width, core_r, _ = HEFT[heft]
    c = Part("Cradle")
    gimbals(c, width, accent=cls != "patch")
    core(c, core_r, cls)
    seat(c, cls)
    kit(c, cls, state)
    p = Part("Pilot")
    fur = CLASSES[cls]["fur"]
    if cls == "sable":
        pilot_fox(p)
    elif cls == "rivet":
        pilot_mole(p, fur)
    elif cls == "kest":
        pilot_bird(p)
    else:
        pilot_patch(p, glitch=state == "glitch")
    return c, p


# --- orbit rings -----------------------------------------------------------------------

def rim_marks(r, rim, R, phase):
    if rim == "pips":
        for k in range(12):
            a = k * math.tau / 12 + phase
            r.ico("class_accent", 0.035, 1, loc=((R + 0.01) * math.cos(a), (R + 0.01) * math.sin(a), 0))
    elif rim == "chevron":
        for k in range(14):
            a = k * math.tau / 14 + phase
            m = common.mtx((R * math.cos(a), R * math.sin(a), 0), (0, 0, a + math.pi / 2))
            r.prism("class_accent", [(-0.04, 0.0), (0.06, 0.0), (0.11, -0.12)], 0.04, matrix=m)
    elif rim == "spikes":
        for k in range(8):
            a = k * math.tau / 8 + phase
            d = (math.cos(a), math.sin(a))
            r.rod("bare_metal", (R * d[0], R * d[1], 0), ((R + 0.15) * d[0], (R + 0.15) * d[1], 0), 0.02, 6, r2=0.008)
            r.ico("class_accent", 0.03, 1, loc=((R + 0.16) * d[0], (R + 0.16) * d[1], 0))
    elif rim == "groove":
        r.ring("rubber", R - 0.035, R - 0.02, 0.06, 32)


def orbit_ring(index, cls, heft, state, phase):
    rings, plates, width, _, bands = HEFT[heft]
    pitches, rolls, spread, knocked = STATES[state]
    R = RING_R[index] + spread
    r = Part("Ring%d" % index)
    r.ring("bare_metal", R - 0.06, R, 0.05, 32)
    glow = "class_accent" if knocked != index else ("rubber" if state == "glitch" else "fleet_paint")
    r.ring(glow, R - 0.085, R - 0.06, 0.03, 32)
    slot_cls = slot_classes(cls, state)[index % 3]
    rim_marks(r, CLASSES[slot_cls]["rim"], R, phase)
    if index < bands:
        r.ring("paint", R - 0.13, R - 0.09, 0.07, 32, color="petrol")
    colors = ("petrol", "oxide", "bone", "petrol", "oxide")
    for k in range(plates):
        a = k * math.tau / plates + phase + 0.4 * index
        loc = ((R - 0.035) * math.cos(a), (R - 0.035) * math.sin(a), 0.0)
        r.box("paint", (0.2, 0.13, 0.09), loc=loc, rot=(0, 0, a), color=colors[k % 5])
        r.bolt(loc, (0, 0, 1), r=0.02, h=0.05)
    if slot_cls == "kest" and index == 0:
        for a in (math.pi * 0.85, math.pi * 1.85):
            loc = ((R - 0.05) * math.cos(a), (R - 0.05) * math.sin(a), -0.16)
            r.box("paint", (0.18, 0.14, 0.22), loc=loc, rot=(0, 0, a), color="bone")
            r.box("class_accent", (0.19, 0.15, 0.04), loc=(loc[0], loc[1], -0.16), rot=(0, 0, a))
            r.rod("bare_metal", loc, (loc[0], loc[1], -0.02), 0.012, 6)
    pitch = max(-MAX_TILT, min(MAX_TILT, pitches[index]))
    roll = max(-MAX_TILT, min(MAX_TILT, rolls[index]))
    if knocked == index and state != "glitch":
        pitch, roll = 0.55, 0.45
    return r, (pitch, roll, 0.0)


def build(cls, heft, state, parent=None):
    common.preview_class(CLASSES[cls]["color"])
    root = common.empty("Shell%s" % cls.capitalize(), (0, 0, 0), parent)
    hull(cls).to_object((0, 0, 0), root)
    c, p = cradle(cls, heft, state)
    c_obj = c.to_object((0, 0, 0), root)
    p.to_object((0, 0, 0), c_obj)
    if state == "glitch":
        c_obj.rotation_euler = (0.3, 0.18, 0.0)  # the gyro failing: the seat is off level
    rig = common.empty("Rig", (0, 0, 0), root)
    rings = HEFT[heft][0]
    for i in range(rings):
        r, rot = orbit_ring(i, cls, heft, state, 0.35 * i)
        obj = r.to_object((0, 0, 0), rig)
        obj.rotation_euler = rot
    if slot_classes(cls, state)[1] == "kest" and state in ("airborne", "boost"):
        for s, name in ((-1, "VaneL"), (1, "VaneR")):
            v = Part(name)
            v.box("paint", (0.55, 0.26, 0.02), color="bone")
            v.box("class_accent", (0.56, 0.05, 0.025), loc=(0, 0.1, 0))
            o = v.to_object((s * 1.2, 0, 0.35), rig)
            o.rotation_euler = (0, s * -0.6, 0)
    # Previews only: free the name so the next class in one scene gets its own accent.
    accent = bpy.data.materials.get("class_accent")
    if accent is not None:
        accent.name = "class_accent_" + cls
    return root


def report(root, label):
    total = common.tri_total(root)
    pilot = [o for o in common.tree(root) if o.name.startswith("Pilot")]
    ptris = common.tris(pilot[0]) if pilot else 0
    print("TRIS %s total %d pilot %d" % (label, total, ptris))
    for o in common.tree(root):
        if o.name.startswith("Ring"):
            print("RING %s %s r_max %.2f" % (label, o.name, common.max_radius(o)))


def main():
    a = parse()
    outdir = a["render"] or os.path.join(HERE, "..", "..", "..", "..", "..", "artifacts", "local", "hero-concepts", "blockouts")
    views = [("game", 8.0, 0.30, 65, (1920, 1080), 0.5), ("close", 3.6, 0.28, 38, (640, 640))]
    sets = a["set"]
    if sets == "all":
        sets = ",".join("%s:%d:%s" % (c, h, s) for c in ("sable", "rivet", "kest")
                        for h, s in ((1, "rest"), (3, "rolling"), (5, "boost"), (3, "hit"), (3, "airborne")))
        sets += ",patch:3:formA,patch:3:formB,patch:3:glitch,patch:5:formA"
    elif sets == "patch":
        sets = "patch:3:formA,patch:3:formB,patch:3:glitch,patch:5:formA"
    for item in [x for x in sets.split(",") if x]:
        cls, heft, state = item.split(":")
        common.reset()
        root = build(cls, int(heft), state)
        label = "%s_h%s_%s" % (cls, heft, state)
        report(root, label)
        common.render_turntable(root, label, outdir, views, ground_z=-1.0, target=(0, 0, 0))
    for item in [x for x in a["lineup"].split(",") if x]:
        heft, state = item.split(":")
        common.reset()
        parent = common.empty("Lineup")
        # Parts are built in world space around the origin, so offset the finished root.
        for x, cls, st in ((-4.4, "sable", state), (-1.45, "rivet", state), (1.45, "kest", state),
                           (4.4, "patch", "formA" if state != "rest" else "formB")):
            root = build(cls, int(heft), st, parent=parent)
            root.location = (x, 0, 0)
        label = "lineup_h%s_%s" % (heft, state)
        common.render_turntable(parent, label, outdir, [("game", 13.0, 0.28, 55, (1920, 1080))],
                                ground_z=-1.0, target=(0, 0, 0.1), yaws=(180, 0))


main()
