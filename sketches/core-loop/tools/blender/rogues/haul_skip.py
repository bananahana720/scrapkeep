"""Haul Skip No. 31 (Dig rogue): one-piece mojulo shells finished as a rigid-posed GLB.

blender -b --factory-startup --python haul_skip.py -- [--out file.glb]
Shells: haul_skip.mojulo.json -> shells/haul_skip.glb (python3 shells.py haul_skip).
Origin is the 2.6 m / 4.8 m collider centre, forward Godot -Z (Blender +Y). Wheels:
0 front-left, 1 front-right, 2 rear-left, 3 rear-right. Brief: design-v3/rogues/BRIEFS.md
section 2; views: docs/art/reference/rogues/haul_skip/.
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
import kit
import polish
from common import Part

kit.setup()
polish.enable(detail=1, subsurf=0, bevel=0.03, bevel_angle=40.0, sharp_angle=55.0)
HALF = 2.4
DOWN = (0, 0, -HALF)
root = common.empty("HaulSkip")
SLOT = "fleet_paint"
WEAR = common.mix("charcoal", "sandstone", 0.3)
LIP = common.mix("oxide", "sandstone", 0.4)
INSIDE = common.mix("oxide", "charcoal", 0.45)
WORN = common.mix("charcoal", "bone", 0.45)
SLATE = "6f7f8f"
WHEELS = [(-1.78, 1.6), (1.78, 1.6), (-1.78, -1.6), (1.78, -1.6)]


def at(x, y, z):
    return (x, y, z - HALF)


bone_rows = [("SkipBody", at(0, 0, 0)), ("SkipBucket", at(0, 2.36, 1.18))]
bone_rows += [("SkipWheel%d" % i, at(x, y, 0.63)) for i, (x, y) in enumerate(WHEELS)]
bone_rows += [("SkipPlateLeft", at(-0.64, -2.665, 0.95)), ("SkipPlateRight", at(0.64, -2.665, 0.95)),
              ("SkipGovernor", at(-2.5, -2.25, 3.3))]


def body_paint(c, n):
    z = c.z + HALF
    if z > 1.15:
        return "petrol"
    return WEAR if n.z > 0.7 else "charcoal"


def bucket_paint(c, n):
    z = c.z + HALF
    if n.z > 0.6 and z > 2.9:
        return LIP
    inward = n.x * c.x + n.y * (c.y - 0.2) < 0 and z > 1.25
    if inward or (n.z > 0.6 and z < 2.85):
        return INSIDE
    return "oxide"


def wheel_paint(c, n):
    return WORN if abs(n.x) < 0.5 and Vector((c.y, c.z)).length > 0 else "charcoal"


pieces, imported = kit.import_shells("haul_skip")
meshes = {"Body": kit.shell_mesh(pieces["Body"], 1650, DOWN), "Bucket": kit.shell_mesh(pieces["Bucket"], 1350, DOWN)}
for i in range(4):
    meshes["Wheel%d" % i] = kit.shell_mesh(pieces["Wheel%d" % i], 110, DOWN)
kit.drop(imported)

hull = Part("HaulSkipHull")
bind = kit.weights(hull)
kit.add_shell(hull, meshes["Body"], SLOT, body_paint)
for x in (-0.4, 0.4):
    hull.ring(SLOT, 0.3, 0.41, 0.09, segs=14, loc=at(x, -2.25, 4.52), rot=(0, math.pi / 2, 0), color="brass")
for side in (-1, 1):
    hull.box(SLOT, (0.3, 0.08, 0.18), loc=at(side * 1.2, 2.31, 0.8), color="amber")
    hull.box(SLOT, (0.22, 0.08, 0.16), loc=at(side * 1.9, -2.56, 0.78), color="amber")
    kit.stencil(hull, SLOT, "HIRED", at(side * 1.56, 0, 0.76), (side, 0, 0), 0.2, "bone", resolution=1)
hull.box(SLOT, (1.28, 0.02, 0.68), loc=at(0, -2.575, 0.95), color="charcoal")
hull.box(SLOT, (0.14, 0.1, 0.14), loc=at(0, -2.74, 0.56), color=WORN)
hull.ring(SLOT, 0.12, 0.2, 0.07, segs=12, loc=at(0, -2.76, 0.4), rot=(math.pi / 2, 0, 0), color=WORN)
hull.box(SLOT, (0.4, 0.2, 0.1), loc=at(-2.42, -2.25, 3.25), color="charcoal")
receiver = hull.box(SLOT, (0.38, 0.32, 0.44), loc=at(-2.42, -2.25, 2.55), color=WORN)
rng = random.Random(31)
for v in hull.verts_of(receiver):
    if v.co.z > 2.6 - HALF or v.co.x < -2.5:
        v.co += Vector((rng.uniform(-0.07, 0.05), rng.uniform(-0.05, 0.05), rng.uniform(-0.12, 0.0)))
kit.cut_line(hull, SLOT, [at(-2.45, -2.2, 2.33), at(-2.55, -2.1, 1.95), at(-2.62, -1.98, 1.55)], radius=0.075)
bind(0)
kit.add_shell(hull, meshes["Bucket"], SLOT, bucket_paint)
for side in (-1, 1):
    kit.stencil(hull, SLOT, "31", at(side * 1.64, 0.2, 2.05), (side, 0, -0.2), 1.0, "bone")
bind(1)
for i in range(4):
    kit.add_shell(hull, meshes["Wheel%d" % i], SLOT, wheel_paint)
    bind(2 + i)
kit.governor(hull, SLOT, at(-2.5, -2.25, 3.3), height=0.82, scale=1.6)
bind(8)
hull_obj = kit.finish(hull, root)

armour = Part("HaulSkipArmour")
armour.bevel = 0.02
bind_plate = kit.weights(armour)
for side, index in [(-1, 6), (1, 7)]:
    armour.box("part_state", (0.62, 0.06, 0.66), loc=at(side * 0.325, -2.665, 0.95), color=SLATE)
    armour.box("part_state", (0.05, 0.05, 0.5), loc=at(side * 0.6, -2.71, 0.95), color="brass")
    armour.box("part_state", (0.06, 0.04, 0.2), loc=at(side * 0.1, -2.71, 0.95), color="charcoal")
    bind_plate(index)
armour_obj = kit.finish(armour, root)

core = Part("HaulSkipCore")
core.subsurf = 0
core.uv("core_state", 0.34, u=12, v=8, loc=at(0, -2.57, 0.95), scale=(1, 0.3, 1))
core_obj = core.to_object(origin=at(0, -2.57, 0.95), parent=root)

kit.rig(root, "HaulSkipPose", bone_rows, (hull_obj, armour_obj))
out = common.args()["out"] or os.path.join(common.MODELS, "rogues", "haul_skip.glb")
kit.export(root, out, (hull_obj, armour_obj, core_obj))
