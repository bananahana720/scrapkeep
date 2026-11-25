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
WET = common.mix("charcoal", "petrol", 0.45)
LEAF = common.mix("petrol", "bone", 0.45)
ROPE = "9aa0a0"

HALF_W = 4.0
WALL = 1.0
WALL_H = 3.4
LEN = 18.0
PIER_H = 10.0
LEAF_H = 3.6
DECK_Y = PIER_H
WHEEL_AT = (HALF_W + 1.6, DECK_Y + 2.2, 1.6)


def g(x, y, z):
    return (x, -z, y)


def box(p, size, at, color, rot=(0, 0, 0)):
    return p.box(SLOT, (size[0], size[2], size[1]), loc=g(*at), rot=rot, color=color)


def beam(p, a, b, w, color, h=None):
    return p.beam(SLOT, g(*a), g(*b), w, h or w, color=color)


def finish(p, origin=(0, 0, 0), parent=None):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin), parent=parent)


root = common.empty("WorksSluiceModel")

p = Part("Base")
box(p, (2 * HALF_W + 2 * WALL, 0.6, LEN), (0, -0.3, 0), CONCRETE_DARK)
for side in (-1, 1):
    x = side * (HALF_W + WALL / 2)
    box(p, (WALL, WALL_H, LEN), (x, WALL_H / 2, 0), CONCRETE)
    box(p, (WALL + 0.2, 0.25, LEN), (x, WALL_H + 0.12, 0), CONCRETE_DARK)
    box(p, (WALL + 1.2, PIER_H, 3.0), (side * (HALF_W + 0.6), PIER_H / 2, 0), CONCRETE)
    box(p, (WALL + 1.4, 0.4, 3.4), (side * (HALF_W + 0.6), PIER_H + 0.2, 0), CONCRETE_DARK)
    box(p, (0.3, PIER_H - 0.6, 0.6), (side * (HALF_W + 0.05), PIER_H / 2 + 0.3, 0), IRON)
    p.prism(SLOT, [(0, -1.5), (1.6, 0), (0, 1.5)], PIER_H - 2.0,
            matrix=common.mtx(g(side * (HALF_W + 0.6), (PIER_H - 2.0) / 2, 1.5), (0, 0, -math.pi / 2)), color=CONCRETE)
box(p, (2 * HALF_W - 0.4, 0.04, LEN / 2 - 1.0), (0, 0.02, -LEN / 4 - 0.5), WET)
box(p, (2 * HALF_W, 0.6, 0.2), (0, 0.3, -0.7), RUST)
for z in (-1.0, 1.0):
    beam(p, (-HALF_W - 1.4, DECK_Y + 0.5, z), (HALF_W + 1.4, DECK_Y + 0.5, z), 0.5, PETROL_DARK, 0.8)
box(p, (2 * HALF_W + 2.8, 0.15, 2.6), (0, DECK_Y + 0.95, 0), IRON)
box(p, (3.0, 2.4, 2.2), (0, DECK_Y + 2.2, 0.2), PETROL)
roof = [(-1.8, 0.0), (1.8, 0.0), (0.0, 0.7)]
p.prism(SLOT, roof, 2.6, matrix=common.mtx(g(0, DECK_Y + 3.4, 0.2), (math.pi / 2, 0, 0)), color=RUST)
box(p, (1.0, 1.6, 0.1), (0.6, DECK_Y + 1.9, -0.92), PETROL_DARK)
p.cyl(SLOT, 0.9, 0.9, 0.3, segs=14, loc=g(1.65, DECK_Y + 2.2, 1.6), rot=(0, math.pi / 2, 0), color=IRON)
p.rod(SLOT, g(1.5, DECK_Y + 2.2, 1.6), g(WHEEL_AT[0] - 0.2, WHEEL_AT[1], WHEEL_AT[2]), 0.14, segs=6, color=IRON)
box(p, (0.5, 2.2, 0.5), (WHEEL_AT[0] - 0.6, DECK_Y + 1.1, WHEEL_AT[2]), PETROL_DARK)
for side in (-1, 1):
    for x in (-HALF_W - 1.2, -2.0, 2.0, HALF_W + 1.2):
        p.rod(SLOT, g(x, DECK_Y + 1.0, side * 1.25), g(x, DECK_Y + 2.1, side * 1.25), 0.05, segs=4, color=IRON)
    p.rod(SLOT, g(-HALF_W - 1.2, DECK_Y + 2.05, side * 1.25), g(HALF_W + 1.2, DECK_Y + 2.05, side * 1.25), 0.05, segs=4, color=IRON)
p.cyl(SLOT, 0.3, 0.3, 2.0, segs=8, loc=g(0, DECK_Y + 4.2, 0), color=IRON)
box(p, (0.3, 3.0, 0.08), (HALF_W - 0.05, 1.8, 6.0), CONCRETE_DARK, rot=(0, 0, 0))
for k in range(6):
    box(p, (0.32, 0.06, 0.1), (HALF_W - 0.05, 0.6 + k * 0.5, 6.0), IRON)
finish(p, parent=root)

gate = common.empty("Gate", parent=root)
p = Part("Leaf")
box(p, (2 * HALF_W + 0.4, LEAF_H, 0.25), (0, LEAF_H / 2, 0), LEAF)
for y in (0.4, 1.3, 2.2, 3.1):
    box(p, (2 * HALF_W + 0.2, 0.32, 0.5), (0, y, 0.3), PETROL_DARK)
for x in (-2.6, 0.0, 2.6):
    box(p, (0.25, LEAF_H - 0.2, 0.45), (x, LEAF_H / 2, 0.28), PETROL_DARK)
box(p, (2 * HALF_W + 0.4, 0.5, 0.3), (0, 0.25, -0.02), RUST)
box(p, (2 * HALF_W + 0.5, 0.2, 0.5), (0, LEAF_H, 0.15), IRON)
p.rod(SLOT, g(0, LEAF_H, 0), g(0, DECK_Y + 5.4, 0), 0.16, segs=8, color=ROPE)
for k in range(6):
    p.cyl(SLOT, 0.2, 0.2, 0.08, segs=8, loc=g(0, LEAF_H + 1.0 + k * 1.6, 0), color=IRON)
finish(p, parent=gate)

wheel = common.empty("Wheel", loc=g(*WHEEL_AT), parent=root)
p = Part("Handwheel")
wx, wy, wz = WHEEL_AT
p.ring(SLOT, 1.2, 1.42, 0.2, segs=18, loc=g(wx, wy, wz), rot=(0, math.pi / 2, 0), color=RUST)
for k in range(5):
    a = k * 2 * math.pi / 5
    beam(p, (wx, wy, wz), (wx, wy + 1.25 * math.sin(a), wz + 1.25 * math.cos(a)), 0.12, IRON)
p.cyl(SLOT, 0.25, 0.25, 0.4, segs=8, loc=g(wx, wy, wz), rot=(0, math.pi / 2, 0), color=IRON)
p.rod(SLOT, g(wx + 0.1, wy + 1.31 * math.sin(0.6), wz + 1.31 * math.cos(0.6)), g(wx + 0.6, wy + 1.31 * math.sin(0.6), wz + 1.31 * math.cos(0.6)), 0.07, segs=6, color=IRON)
finish(p, origin=WHEEL_AT, parent=wheel)

bpy.context.view_layer.update()
tris = common.tri_total(root)
draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
print("WORKS_SLUICE_BUDGET", tris, "T", draws, "D")
if tris > 6000 or draws > 4:
    raise SystemExit("works sluice budget exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "works_sluice.glb"))
