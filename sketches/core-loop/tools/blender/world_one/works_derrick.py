# A looping worker (BACKLOG W1-93, DECISIONS machine lore 22 Oct): the stiff-leg derrick that poured the
# dam and is still pouring it, slewing a concrete bucket out and back with nobody at the levers.
# src/presentation/work_machines.gd places it and drives the named nodes; nothing here is animated.
# Procedural bmesh; no external assets or physics. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y).
#
# Nodes (the runtime finds them by name):
#   WorksDerrickModel        root, origin on the ground under the mast, the boom reaching to -Z
#     Base                   static: footing pads, sills, two stiff legs, the top collar, the winch house
#     Slew  (empty)          turns about +Y at the mast's foot
#       SlewFrame            mast, bull wheel, boom and the topping-lift cables
#       Hook (empty)         at the boom's tip; the runtime tips it a little for sway
#         Fall               two hoist ropes from 0 to -1 m; the runtime stretches it in Y to the bucket
#         Load (empty)       the runtime sets its Y to minus the hoist length
#           Bucket           hook block, bail and the concrete bucket, its top 1.2 m under the block's eye
# Paint (VISUAL-LANGUAGE section 2): weathered petrol machinery, oil-charcoal iron, iron-oxide rust,
# concrete footings, worn-steel rope. No hazard stripes, no mint, no brass, no emission: it is
# neither friend nor foe and must never read as an enemy part or a telegraph.
import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part
common.reset()
common.SLOTS["works_paint"] = {"vc": True, "rough": 0.78, "metal": 0.15}

SLOT = "works_paint"
PETROL = common.mix("petrol", "bone", 0.12)
PETROL_DARK = common.mix("petrol", "charcoal", 0.35)
IRON = common.mix("charcoal", "petrol", 0.2)
RUST = common.mix("oxide", "charcoal", 0.25)
CONCRETE = common.mix("sandstone", "bone", 0.45)
CONCRETE_DARK = common.mix("sandstone", "charcoal", 0.3)
ROPE = "9aa0a0"

MAST_H = 24.0          # mast top above the ground
MAST_W = 1.4           # chord square
FOOT_Y = 1.0           # top of the footing pad: the slew turns here
BOOM_PIN = (0.0, 2.2, -1.0)
BOOM_LEN = 28.0
BOOM_DEG = 34.0
LEG_REACH = 15.0       # sill length behind the mast, at +-45 degrees
LACE_STEP = 3.0


def g(x, y, z):
    return (x, -z, y)


def beam(p, a, b, w, color):
    return p.beam(SLOT, g(*a), g(*b), w, w, color=color)


def box(p, size, at, color, rot=(0, 0, 0)):
    return p.box(SLOT, (size[0], size[2], size[1]), loc=g(*at), rot=rot, color=color)


def lattice(p, a, b, half_w, color, lace_color, step=LACE_STEP, chord=0.32, lace=0.16, taper=None):
    """Four chords from a to b around a square section of half width half_w (or taper(t) -> half width),
    with zigzag lacing on each face. a and b are Godot points."""
    ax, ay, az = a
    bx, by, bz = b
    d = (bx - ax, by - ay, bz - az)
    length = math.sqrt(sum(c * c for c in d))
    f = tuple(c / length for c in d)
    up = (0.0, 1.0, 0.0) if abs(f[1]) < 0.9 else (0.0, 0.0, 1.0)
    s = (f[1] * up[2] - f[2] * up[1], f[2] * up[0] - f[0] * up[2], f[0] * up[1] - f[1] * up[0])
    sl = math.sqrt(sum(c * c for c in s))
    s = tuple(c / sl for c in s)
    u = (s[1] * f[2] - s[2] * f[1], s[2] * f[0] - s[0] * f[2], s[0] * f[1] - s[1] * f[0])
    hw = taper if taper is not None else (lambda t: half_w)
    corners = ((1, 1), (-1, 1), (-1, -1), (1, -1))

    def at(t, k):
        cx, cy = corners[k % 4]
        w = hw(t)
        return tuple(a[i] + d[i] * t + s[i] * cx * w + u[i] * cy * w for i in range(3))

    n = max(1, round(length / step))
    for k in range(4):
        for i in range(n):
            beam(p, at(i / n, k), at((i + 1) / n, k), chord, color)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        for k in range(4):
            if (i + k) % 2:
                beam(p, at(t0, k), at(t1, k + 1), lace, lace_color)
            else:
                beam(p, at(t1, k), at(t0, k + 1), lace, lace_color)
    return at


def finish(p, origin=(0, 0, 0), parent=None):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin), parent=parent)


root = common.empty("WorksDerrickModel")

# --- Base: footing, sills, stiff legs, the top collar the mast turns in, the winch house -------------------------------
p = Part("Base")
oct_ = [(math.cos(math.pi / 8 + k * math.pi / 4) * 3.0, math.sin(math.pi / 8 + k * math.pi / 4) * 3.0) for k in range(8)]
p.prism(SLOT, oct_, FOOT_Y, matrix=common.mtx(g(0, FOOT_Y / 2, 0)), color=CONCRETE)
legs = []
for side in (-1, 1):
    end = (side * LEG_REACH * math.sqrt(0.5), 0.0, LEG_REACH * math.sqrt(0.5))
    legs.append(end)
    box(p, (3.2, 1.6, 3.2), (end[0], 0.8, end[2]), CONCRETE)
    box(p, (2.2, 0.25, 2.2), (end[0], 1.72, end[2]), CONCRETE_DARK)
    beam(p, (0, FOOT_Y + 0.35, 0), (end[0], 1.95, end[2]), 0.7, IRON)
    lattice(p, (end[0], 2.0, end[2]), (side * 0.9, MAST_H - 0.6, 0.9), 0.0, PETROL_DARK, PETROL_DARK,
            step=3.5, chord=0.34, lace=0.18, taper=lambda t: 0.55 - 0.25 * t)
# The ties between the leg feet keep the sills square; a rust run where the rain sits.
beam(p, (legs[0][0], 1.9, legs[0][2]), (legs[1][0], 1.9, legs[1][2]), 0.5, RUST)
p.cyl(SLOT, 1.35, 1.35, 0.7, segs=12, loc=g(0, MAST_H - 0.35, 0), color=IRON)
box(p, (2.6, 0.5, 2.6), (0, MAST_H - 0.5, 0.6), PETROL_DARK)
# Winch house between the legs: petrol cab, rust-streaked roof, the hoist drum showing through its open side.
WX, WZ = 0.0, 7.5
box(p, (5.0, 3.6, 4.0), (WX, 1.8, WZ), PETROL)
box(p, (5.0, 0.35, 4.0), (WX, 0.2, WZ), CONCRETE_DARK)
roof = [(-2.8, 0.0), (2.8, 0.0), (0.0, 1.1)]
p.prism(SLOT, roof, 4.4, matrix=common.mtx(g(WX, 3.6, WZ), (math.pi / 2, 0, 0)), color=RUST)
box(p, (4.4, 2.0, 0.2), (WX, 2.0, WZ - 2.05), PETROL_DARK)
p.cyl(SLOT, 0.9, 0.9, 3.6, segs=10, loc=g(WX, 2.0, WZ - 1.2), rot=(0, math.pi / 2, 0), color=IRON)
for x in (-1.9, 1.9):
    p.cyl(SLOT, 1.15, 1.15, 0.18, segs=10, loc=g(WX + x, 2.0, WZ - 1.2), rot=(0, math.pi / 2, 0), color=RUST)
p.cyl(SLOT, 0.22, 0.26, 2.4, segs=6, loc=g(WX + 1.8, 5.3, WZ + 1.2), color=IRON)
for z in (-0.9, 0.9):
    box(p, (0.9, 0.7, 0.08), (WX - 2.54, 2.4, WZ + z), CONCRETE_DARK, rot=(0, 0, math.pi / 2))
# The hoist ropes run from the drum up to the mast top's sheave.
p.rod(SLOT, g(WX, 2.6, WZ - 1.2), g(0, MAST_H - 1.2, 0.7), 0.06, segs=4, color=ROPE)
p.rod(SLOT, g(WX + 0.5, 2.6, WZ - 1.2), g(0.5, MAST_H - 1.2, 0.7), 0.06, segs=4, color=ROPE)
finish(p, parent=root)

# --- Slew: mast, bull wheel, boom, topping lift -----------------------------------------------------------------------
slew = common.empty("Slew", loc=g(0, FOOT_Y, 0), parent=root)
p = Part("SlewFrame")
p.ring(SLOT, 1.7, 2.5, 0.45, segs=20, loc=g(0, FOOT_Y + 0.3, 0), rot=(0, 0, 0), color=IRON)
for k in range(6):
    a = k * math.pi / 3
    beam(p, (0.6 * math.cos(a), FOOT_Y + 0.3, 0.6 * math.sin(a)), (1.8 * math.cos(a), FOOT_Y + 0.3, 1.8 * math.sin(a)), 0.22, IRON)
p.cyl(SLOT, 0.9, 1.0, 0.9, segs=8, loc=g(0, FOOT_Y + 0.6, 0), color=PETROL_DARK)
lattice(p, (0, FOOT_Y + 0.9, 0), (0, MAST_H, 0), MAST_W / 2, PETROL, PETROL_DARK)
p.cyl(SLOT, 0.55, 0.55, 0.8, segs=8, loc=g(0, MAST_H + 0.4, 0), color=IRON)
p.cyl(SLOT, 0.7, 0.7, 0.3, segs=10, loc=g(0, MAST_H + 0.6, 0.5), rot=(0, math.pi / 2, 0), color=RUST)
# Boom foot pin on the mast, the boom rising to -Z.
bx, by, bz = BOOM_PIN
tip = (0.0, by + BOOM_LEN * math.sin(math.radians(BOOM_DEG)), bz - BOOM_LEN * math.cos(math.radians(BOOM_DEG)))
box(p, (2.0, 1.0, 1.4), (0, by, bz + 0.3), IRON)
lattice(p, BOOM_PIN, tip, 0.0, PETROL, PETROL_DARK, step=3.2, chord=0.3, lace=0.15,
        taper=lambda t: 0.3 + 0.75 * math.sin(math.pi * t))
p.cyl(SLOT, 0.75, 0.75, 0.5, segs=10, loc=g(*tip), rot=(0, math.pi / 2, 0), color=RUST)
box(p, (1.1, 0.5, 1.0), (tip[0], tip[1] + 0.35, tip[2]), IRON)
# Topping lift: four falls of rope from the mast head to the boom's tip.
for x in (-0.3, -0.1, 0.1, 0.3):
    p.rod(SLOT, g(x, MAST_H + 0.2, -0.4), g(x, tip[1] + 0.3, tip[2] + 0.4), 0.05, segs=4, color=ROPE)
# The hoist line along the boom's back from the mast head sheave to the tip sheave.
p.rod(SLOT, g(0, MAST_H - 0.2, -0.5), g(0, tip[1] + 0.6, tip[2] + 0.2), 0.06, segs=4, color=ROPE)
finish(p, origin=(0, FOOT_Y, 0), parent=slew)

hook = common.empty("Hook", loc=g(tip[0], tip[1] - 0.4, tip[2]), parent=slew)
p = Part("Fall")
for x in (-0.25, 0.25):
    p.rod(SLOT, g(tip[0] + x, tip[1] - 0.4, tip[2]), g(tip[0] + x, tip[1] - 1.4, tip[2]), 0.05, segs=4, color=ROPE)
finish(p, origin=(tip[0], tip[1] - 0.4, tip[2]), parent=hook)
load = common.empty("Load", loc=g(tip[0], tip[1] - 1.4, tip[2]), parent=hook)
p = Part("Bucket")
L = (tip[0], tip[1] - 1.4, tip[2])
box(p, (1.1, 0.7, 0.5), (L[0], L[1] - 0.2, L[2]), IRON)
p.cyl(SLOT, 0.32, 0.32, 0.55, segs=8, loc=g(L[0], L[1] - 0.2, L[2]), rot=(0, math.pi / 2, 0), color=RUST)
p.rod(SLOT, g(L[0], L[1] - 0.55, L[2]), g(L[0], L[1] - 1.0, L[2]), 0.1, segs=6, color=IRON)
# The bail and the bucket: a tapered concrete skip, its gate at the bottom.
for x in (-1.25, 1.25):
    beam(p, (L[0], L[1] - 1.0, L[2]), (L[0] + x, L[1] - 2.0, L[2]), 0.14, IRON)
p.cyl(SLOT, 0.9, 1.35, 2.4, segs=10, loc=g(L[0], L[1] - 3.3, L[2]), color=PETROL_DARK)
p.ring(SLOT, 1.2, 1.45, 0.25, segs=10, loc=g(L[0], L[1] - 2.15, L[2]), color=RUST)
p.cyl(SLOT, 1.2, 1.2, 0.1, segs=10, loc=g(L[0], L[1] - 2.2, L[2]), color=CONCRETE_DARK)
box(p, (0.9, 0.3, 0.9), (L[0], L[1] - 4.6, L[2]), IRON)
finish(p, origin=L, parent=load)

bpy.context.view_layer.update()
tris = common.tri_total(root)
draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
print("WORKS_DERRICK_BUDGET", tris, "T", draws, "D", "tip", [round(c, 3) for c in tip])
if tris > 6000 or draws > 4:
    raise SystemExit("works derrick budget exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "works_derrick.glb"))
