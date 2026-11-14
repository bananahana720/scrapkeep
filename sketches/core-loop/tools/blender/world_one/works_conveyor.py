# A looping worker (BACKLOG W1-93, DECISIONS machine lore 22 Oct): the batch plant's bucket conveyor,
# still carrying aggregate up its truss and tipping it onto a pile nobody will pour. It runs, stops
# while the hopper "fills", and runs again.
# src/presentation/work_machines.gd places it and drives the buckets; nothing here is animated.
# Procedural bmesh; no external assets or physics. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y).
#
# Nodes (the runtime finds them by name):
#   WorksConveyorModel   root, origin on the ground under the truss's middle, the head (discharge) towards -Z
#     Base               static: hopper, truss gallery, trestle legs, head tower, chute, tail housing, the pile
#     CupFull            one loaded bucket at the origin, open side up, its run along -Z; the runtime
#                         copies it along the carrying run (a MultiMesh) and hides this one
#     CupEmpty           one empty bucket hanging upside down, for the return run under the belt
# The carrying run goes from TAIL_TOP to HEAD_TOP; the return run 1.1 m under it the other way.
# Paint as works_derrick.py; aggregate in sandstone tones.
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
GRAVEL = common.mix("sandstone", "charcoal", 0.15)
GRAVEL_LIGHT = common.mix("sandstone", "bone", 0.25)

TAIL_TOP = (0.0, 3.0, 13.0)
HEAD_TOP = (0.0, 16.0, -11.0)
HALF_W = 1.1
DEPTH = 1.6


def g(x, y, z):
    return (x, -z, y)


def box(p, size, at, color, rot=(0, 0, 0)):
    return p.box(SLOT, (size[0], size[2], size[1]), loc=g(*at), rot=rot, color=color)


def beam(p, a, b, w, color, h=None):
    return p.beam(SLOT, g(*a), g(*b), w, h or w, color=color)


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def finish(p, origin=(0, 0, 0), parent=None):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin), parent=parent)


root = common.empty("WorksConveyorModel")

p = Part("Base")
# The truss gallery: two side trusses under the run, chords, verticals and diagonals.
n = 8
for side in (-1, 1):
    x = side * HALF_W
    top = [lerp3((x, TAIL_TOP[1] - 0.2, TAIL_TOP[2]), (x, HEAD_TOP[1] - 0.2, HEAD_TOP[2]), k / n) for k in range(n + 1)]
    bot = [(t[0], t[1] - DEPTH, t[2]) for t in top]
    for k in range(n):
        beam(p, top[k], top[k + 1], 0.22, PETROL)
        beam(p, bot[k], bot[k + 1], 0.22, PETROL)
        beam(p, top[k] if k % 2 else bot[k], bot[k + 1] if k % 2 else top[k + 1], 0.14, PETROL_DARK)
    for k in range(n + 1):
        beam(p, top[k], bot[k], 0.14, PETROL_DARK)
# Cross ties under the gallery and the walkway plate beside it.
for k in range(n + 1):
    a = lerp3((-HALF_W, TAIL_TOP[1] - 0.2 - DEPTH, TAIL_TOP[2]), (-HALF_W, HEAD_TOP[1] - 0.2 - DEPTH, HEAD_TOP[2]), k / n)
    beam(p, a, (HALF_W, a[1], a[2]), 0.14, IRON)
# Trestle legs: A-frames at a third and two thirds, set on concrete pads.
for t in (0.3, 0.65):
    c = lerp3(TAIL_TOP, HEAD_TOP, t)
    yb = c[1] - 0.2 - DEPTH
    for side in (-1, 1):
        beam(p, (side * HALF_W, yb, c[2]), (side * (HALF_W + 2.2), 0.4, c[2]), 0.3, IRON)
        box(p, (1.2, 0.5, 1.2), (side * (HALF_W + 2.2), 0.25, c[2]), CONCRETE)
    beam(p, (-(HALF_W + 1.4), yb * 0.45, c[2]), (HALF_W + 1.4, yb * 0.45, c[2]), 0.16, IRON)
# Tail: the receiving hopper and the tail pulley housing.
tz = TAIL_TOP[2]
box(p, (3.6, 1.4, 3.0), (0, 0.7, tz + 0.6), CONCRETE)
hop = [(-2.0, 0.0), (2.0, 0.0), (1.0, -1.6), (-1.0, -1.6)]
p.prism(SLOT, [(-2.2, 1.8), (2.2, 1.8), (1.1, 0.0), (-1.1, 0.0)], 2.6, matrix=common.mtx(g(0, 1.4, tz + 0.6), (math.pi / 2, 0, 0)), color=RUST)
box(p, (2.8, 0.25, 2.2), (0, 3.25, tz + 0.6), GRAVEL)
p.cyl(SLOT, 0.55, 0.55, 2.6, segs=10, loc=g(0, TAIL_TOP[1] - 0.6, tz), rot=(0, math.pi / 2, 0), color=IRON)
# Head tower: four legs, a deck, the head pulley house with its motor, the discharge chute.
hz = HEAD_TOP[2]
for sx in (-1, 1):
    for sz in (-1, 1):
        beam(p, (sx * 1.8, 0.0, hz + sz * 1.6), (sx * 1.4, HEAD_TOP[1] - 1.2, hz + sz * 1.3), 0.3, PETROL_DARK)
        box(p, (1.0, 0.6, 1.0), (sx * 1.8, 0.3, hz + sz * 1.6), CONCRETE)
for y in (4.5, 9.0):
    for sz in (-1, 1):
        beam(p, (-1.7, y, hz + sz * 1.5), (1.7, y, hz + sz * 1.5), 0.16, IRON)
box(p, (3.6, 0.3, 3.4), (0, HEAD_TOP[1] - 1.1, hz), IRON)
box(p, (3.2, 2.4, 3.0), (0, HEAD_TOP[1] + 0.3, hz - 0.2), PETROL)
p.prism(SLOT, [(-1.9, 0.0), (1.9, 0.0), (0.0, 0.8)], 3.4, matrix=common.mtx(g(0, HEAD_TOP[1] + 1.5, hz - 0.2), (math.pi / 2, 0, 0)), color=RUST)
box(p, (1.0, 1.0, 1.6), (2.1, HEAD_TOP[1] - 0.3, hz), IRON)
p.cyl(SLOT, 0.3, 0.3, 0.6, segs=8, loc=g(2.1, HEAD_TOP[1] + 0.4, hz - 0.5), color=IRON)
chute = [(-0.9, 0.0), (0.9, 0.0), (0.6, -4.5), (-0.6, -4.5)]
p.prism(SLOT, chute, 1.2, matrix=common.mtx(g(0, HEAD_TOP[1] - 1.2, hz - 1.9), (math.pi / 2 - 0.35, 0, 0)), color=RUST)
# The pile under the chute: three heaped mounds.
for (x, z, r, h) in ((0.0, hz - 4.6, 4.2, 3.4), (-2.4, hz - 3.0, 2.6, 1.8), (2.2, hz - 6.2, 2.4, 1.4)):
    p.cyl(SLOT, r, r * 0.25, h, segs=12, loc=g(x, h / 2 - 0.2, z), color=GRAVEL)
    p.cyl(SLOT, r * 0.25, 0.1, h * 0.25, segs=12, loc=g(x, h - 0.2 + h * 0.125, z), color=GRAVEL_LIGHT)
finish(p, parent=root)

# One bucket each way: open up and loaded, and hung empty under the belt.
for name, full in (("CupFull", True), ("CupEmpty", False)):
    p = Part(name)
    flip = 1.0 if full else -1.0
    box(p, (1.6, 0.12, 0.9), (0, -0.25 * flip, 0), RUST)
    for side in (-1, 1):
        box(p, (0.1, 0.55, 0.9), (side * 0.75, 0.0, 0), RUST)
    box(p, (1.6, 0.55, 0.1), (0, 0.0, 0.42), PETROL_DARK)
    box(p, (1.6, 0.4, 0.1), (0, -0.05 * flip, -0.42), PETROL_DARK)
    if full:
        p.cyl(SLOT, 0.62, 0.15, 0.45, segs=8, loc=g(0, 0.2, 0), color=GRAVEL_LIGHT)
    finish(p, parent=root)

bpy.context.view_layer.update()
tris = common.tri_total(root)
draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
print("WORKS_CONVEYOR_BUDGET", tris, "T", draws, "D")
if tris > 6000 or draws > 4:
    raise SystemExit("works conveyor budget exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "works_conveyor.glb"))
