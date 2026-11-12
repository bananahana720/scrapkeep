# E27 Jolt layer: an oxide Fleet animal crew hauling a charcoal cable spool on its back,
# a coil standing over the spool that swells before each jolt (design-v3/FIELDS-AND-CASTS.md
# section 2.3). The spool axle runs across the shoulders at Godot (0, 2.0, -0.25); the coil
# rises from it to y 3.2. Loose cable drapes from the spool to the ground behind the crew.
#
# Two meshes, three colour-pass surfaces, all opaque:
#   JoltBody: fleet_paint (barrel, chest, head) and paint (charcoal joints, snout, ears,
#             spool drum and flanges, oxide flank plates, cable, worn edges, brass tag).
#   JoltCoil: paint (copper-banded coil and its charcoal cap). Its origin is the coil base
#             (0, 2.4, -0.25); jolt_layer.gd swells it with each pulse's lead.
# Blender +Z is up; g() converts Godot metres to Blender. Ground is Godot y -1.1.
# Provenance: procedural bmesh, no external mesh or texture.
#
# systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#   blender -b --factory-startup -P enemy_jolt_layer.py -- [--out file.glb]

import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("JoltLayer")
CHAR = "charcoal"
PLATE = common.mix("oxide", "charcoal", 0.18)
IRON = common.mix("charcoal", "oxide", 0.28)
WORN = common.mix("charcoal", "bone", 0.55)
COPPER = common.mix("brass", "oxide", 0.35)
AXLE = (0, 2.0, -0.25)
COIL = (0, 2.4, -0.25)


def g(x, y, z):
    return (x, -z, y)


b = Part("JoltBody")
b.cyl("fleet_paint", 0.54, 0.62, 1.0, segs=10, loc=g(0, -0.60, 0))
b.cyl("fleet_paint", 0.62, 0.50, 0.8, segs=10, loc=g(0, 0.3, -0.04))
crew.animal_head(b, g(0, 1.02, 0.13), 0.30, snout=((0.22, 0.20, 0.16), g(0, 0.97, 0.40)),
                 ears=(0.10, 0.28, [g(s * 0.17, 1.38, 0.10) for s in (-1, 1)]))
for s in (-1, 1):
    b.box("paint", (0.07, 0.50, 0.40), loc=g(s * 0.59, 0.27, -0.03), color=PLATE)
    b.box("paint", (0.075, 0.38, 0.045), loc=g(s * 0.59, 0.48, -0.03), color=WORN)
    b.rod("paint", g(s * 0.42, 0.6, 0.16), g(s * 0.23, 0.3, 0.38), 0.08, segs=6, color=IRON)
    # Shoulder forks carry the spool axle.
    b.rod("paint", g(s * 0.40, 0.5, -0.25), g(s * 0.40, AXLE[1], AXLE[2]), 0.05, segs=5, color=IRON)
    b.cyl("paint", 0.56, 0.56, 0.06, segs=12, loc=g(s * 0.30, AXLE[1], AXLE[2]),
          rot=(0, math.pi / 2, 0), color=CHAR)
b.cyl("paint", 0.63, 0.63, 0.09, segs=10, loc=g(0, -0.06, 0), color=CHAR)
b.box("paint", (0.25, 0.045, 0.16), loc=g(0, 0.27, 0.57), color="brass")
# The drum: wound cable between two flanges, a worn band where the cable pays out.
b.cyl("paint", 0.44, 0.44, 0.54, segs=12, loc=g(*AXLE), rot=(0, math.pi / 2, 0), color=IRON)
b.cyl("paint", 0.445, 0.445, 0.08, segs=12, loc=g(0.12, AXLE[1], AXLE[2]), rot=(0, math.pi / 2, 0), color=WORN)
b.cyl("paint", 0.07, 0.07, 0.9, segs=6, loc=g(*AXLE), rot=(0, math.pi / 2, 0), color=CHAR)
# Loose cable drapes from the drum to the ground behind the crew.
cable = [(0.12, 1.6, -0.62), (0.18, 0.8, -0.85), (0.10, -0.2, -1.0), (0.0, -1.05, -1.25), (-0.2, -1.08, -1.7)]
for a, c in zip(cable, cable[1:]):
    b.rod("paint", g(*a), g(*c), 0.05, segs=5, color=CHAR)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

c = Part("JoltCoil")
c.subsurf = 0
c.cyl("paint", 0.06, 0.06, 0.8, segs=8, loc=g(0, COIL[1] + 0.4, COIL[2]), color=CHAR)
for k in range(5):
    y = COIL[1] + 0.12 + k * 0.15
    c.cyl("paint", 0.16, 0.16, 0.08, segs=10, loc=g(0, y, COIL[2]), color=COPPER if k % 2 == 0 else PLATE)
c.cyl("paint", 0.20, 0.08, 0.12, segs=10, loc=g(0, COIL[1] + 0.86, COIL[2]), color=CHAR)
bmesh.ops.recalc_face_normals(c.bm, faces=c.bm.faces[:])
coil = c.to_object(origin=g(*COIL), parent=root)

import bpy
bpy.context.view_layer.update()
tris = common.tri_total(root)
surfaces = len(body.data.materials) + len(coil.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "COIL", common.tris(coil))
if tris > 6800 or surfaces > 3:
    raise SystemExit("E27 limits exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_jolt_layer.glb"))
