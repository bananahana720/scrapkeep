import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Hooker")

GROUND = -1.1
POST_X = 0.9
HEAD_Z = 3.1
PIVOT = (POST_X, 0.0, HEAD_Z)
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.18)
IRON = common.mix("charcoal", "oxide", 0.28)
HAZ = "hazard"
BRASS = "brass"
HALF_PI = math.pi / 2

b = Part("HookerBody")
b.cyl("fleet_paint", 0.66, 0.80, 1.1, segs=10, loc=(0, 0, -0.55))
b.cyl("fleet_paint", 0.80, 0.70, 1.1, segs=10, loc=(0, 0, 0.55))
crew.bollard_head(b, (0, 0, 1.3), 0.38)
b.cyl("paint", 0.81, 0.81, 0.12, segs=10, loc=(0, 0, 0.1), color=CHAR)
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.79, 0.3), color=BRASS)
b.box("paint", (0.36, 0.20, 0.20), loc=(0.62, 0.35, 0.9), color=IRON)

b.cyl("paint", 0.19, 0.12, 4.2, segs=8, loc=(POST_X, 0, HEAD_Z - 2.1), color=CHAR)
b.box("paint", (0.95, 0.95, 0.10), loc=(POST_X, 0, GROUND + 0.05), color=WORN)
for sy in (-1, 1):
    b.rod("paint", (POST_X, sy * 0.44, GROUND + 0.1), (POST_X, 0, GROUND + 1.5), 0.05, segs=5, color=IRON)
b.cyl("paint", 0.34, 0.34, 0.34, segs=10, loc=(POST_X, 0, 0.45), rot=(HALF_PI, 0, 0), color=WORN)
b.cyl("paint", 0.42, 0.42, 0.06, segs=10, loc=(POST_X, 0.2, 0.45), rot=(HALF_PI, 0, 0), color=IRON)
b.cyl("paint", 0.42, 0.42, 0.06, segs=10, loc=(POST_X, -0.2, 0.45), rot=(HALF_PI, 0, 0), color=IRON)
for sx in (-1, 1):
    b.box("paint", (0.06, 1.0, 0.16), loc=(POST_X + sx * 0.14, -0.25, HEAD_Z - 0.16), color=IRON)
b.box("paint", (0.42, 0.28, 0.28), loc=(POST_X, 0.05, HEAD_Z - 0.02), color=WORN)
b.box("paint", (1.30, 0.14, 0.14), loc=(POST_X, 0, HEAD_Z + 0.42), color=CHAR)
for sx in (-1, 1):
    b.rod("paint", (POST_X + sx * 0.02, 0, HEAD_Z + 0.02), (POST_X + sx * 0.60, 0, HEAD_Z + 0.42), 0.075, segs=5, color=CHAR)
    b.rod("paint", (POST_X + sx * 0.60, 0, HEAD_Z + 0.42), (POST_X + sx * 0.66, 0, HEAD_Z + 0.78), 0.075, segs=5,
          color=CHAR, r2=0.02)
b.ring("paint", 0.13, 0.22, 0.10, segs=10, loc=(POST_X, 0, HEAD_Z + 0.62), rot=(HALF_PI, 0, 0), color=IRON)
crew.cast_number(b, "paint", "12", (0, -0.715, 0.74), (0, -1, 0), 0.26)
crew.hired(b, "paint", (0, 0.745, -0.3), (0, 1, 0), 0.11)
body = b.to_object(parent=root)

pivot = common.empty("HookerHarpoon", PIVOT, root)
h = Part("HookerHarpoonMesh")
h.subsurf = 0
px, py, pz = PIVOT
h.rod("paint", (px, py + 0.55, pz), (px, py - 1.75, pz), 0.075, segs=6, color=CHAR)
h.rod("paint", (px, py - 1.75, pz), (px, py - 2.35, pz), 0.19, segs=6, color=HAZ, r2=0.0)
for roll in (0.0, HALF_PI):
    h.box("paint", (0.42, 0.24, 0.05), loc=(px, py - 1.86, pz), rot=(0, roll, 0), color=HAZ)
h.ring("paint", 0.06, 0.13, 0.08, segs=8, loc=(px, py + 0.6, pz), rot=(HALF_PI, 0, 0), color=IRON)
harpoon = h.to_object(origin=PIVOT, parent=pivot)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
hys = [v.co.y + PIVOT[1] for v in harpoon.data.vertices]
hzs = [v.co.z + PIVOT[2] for v in harpoon.data.vertices]
surfaces = len(body.data.materials) + len(harpoon.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3),
      "HARPOON_Y", round(min(hys), 3), round(max(hys), 3), "HARPOON_Z", round(min(hzs), 3), round(max(hzs), 3))
if tris > 6800 or surfaces > 3 or max(abs(x) for x in xs) > 1.6 or min(ys) < -1.0 or max(ys) > 1.0 \
        or min(zs) < GROUND - 0.001 or max(zs) > 4.0 or min(hys) < -2.5 or max(hys) > 0.8:
    raise SystemExit("C14 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_hooker.glb"))
