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
root = common.empty("BolaThrower")

GROUND = -1.1
LOOP_Z = 2.2
RING_R, RING_TUBE = 0.75, 0.10
WEIGHT_R = 0.26
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.18)
BRASS = "brass"

b = Part("BolaThrowerBody")
b.cyl("fleet_paint", 0.62, 0.72, 1.0, segs=10, loc=(0, 0, -0.6))
b.cyl("fleet_paint", 0.74, 0.54, 0.95, segs=10, loc=(0, 0, 0.37))
crew.lantern_head(b, (0, 0, 1.13), 0.36)
b.cyl("paint", 0.76, 0.76, 0.12, segs=10, loc=(0, 0, 0.0), color=CHAR)
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.72, 0.28), color=BRASS)
b.rod("fleet_paint", (0.60, 0.0, 0.55), (0.14, 0.0, 1.95), 0.11, segs=6)
b.uv("paint", 0.17, u=8, v=5, loc=(0.14, 0.0, 2.0), color=CHAR)
crew.cast_number(b, "paint", "08", (0, -0.572, 0.62), (0, -1, 0), 0.2)
crew.hired(b, "paint", (0, 0.672, -0.4), (0, 1, 0), 0.1)
body = b.to_object(parent=root)

loop = Part("BolaLoop")
loop.ring("class_accent", RING_R - RING_TUBE, RING_R + RING_TUBE, RING_TUBE * 2.0, segs=16,
          rot=(0, 0, 0))
for sx in (-1, 1):
    loop.uv("class_accent", WEIGHT_R, u=8, v=5, loc=(sx * (RING_R + 0.10), 0, 0))
bola = loop.to_object(origin=(0, 0, 0), parent=root)
bola.location = (0.0, 0.0, LOOP_Z)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
reach = max(math.hypot(v.co.x, v.co.y) for v in body.data.vertices)
loop_reach = max(v.co.length for v in bola.data.vertices)
surfaces = len(body.data.materials) + len(bola.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_R", round(reach, 3), "BODY_Z", round(min(zs), 3),
      round(max(zs), 3), "LOOP_REACH", round(loop_reach, 3))
if tris > 4200 or surfaces > 3 or reach > 0.8 or min(zs) < GROUND - 0.001 or max(zs) > 2.3 or loop_reach > 1.12:
    raise SystemExit("C13 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_bola_thrower.glb"))
