# C22 Catch trap: a small Fleet oxide crew under an open, sixteen-sided spring cup.
# The cup has a dark empty well, oxide tapered walls, a worn grey lip and one red
# hostile latch tab. A side spring stack, pivot pin and long release paddle stand
# outside the well. They travel with the cup; the runtime has no jaw or lever pose.
# The crew has charcoal ears, snout, boots, belt and pack, with one brass chest tag.
#
# Two meshes / three opaque surfaces: CatchBody (fleet_paint + vertex paint) and
# CatchCup (vertex paint). CatchCup's origin is its centre; catch_trap.gd supplies
# both carried and deployed positions. Blender +Z is Godot up; Blender -Y is +Z.
# The literal 0.8 m collider footprint, including the carried cup's -0.3 m offset,
# limits the mouth to 0.48 m radius and the base to 0.30 m (source maxima 1.2/0.7).
# The tool has no geometry in its well above the floor at local y -0.28 m.
# Provenance: procedural bmesh, no external meshes or textures.
#
# systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#   blender -b --factory-startup -P enemy_catch_trap.py -- [--out file.glb]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("CatchTrap")
CHAR = "charcoal"
IRON = common.mix("charcoal", "oxide", 0.25)
WORN = common.mix("charcoal", "bone", 0.55)
PLATE = common.mix("oxide", "charcoal", 0.12)


def g(x, y, z):
    return (x, -z, y)


b = Part("CatchBody")
b.cyl("fleet_paint", 0.34, 0.36, 0.70, segs=10, loc=g(0, -0.48, 0.08))
b.cyl("fleet_paint", 0.36, 0.29, 0.65, segs=10, loc=g(0, 0.20, 0.08))
crew.sheave_head(b, g(0, 0.76, 0.18), 0.24)
for side in (-1, 1):
    b.box("paint", (0.24, 0.38, 0.20), loc=g(side * 0.20, -1.00, 0.14), color=CHAR)
    b.rod("paint", g(side * 0.29, 0.39, 0.05), g(side * 0.32, 1.20, -0.24), 0.065, segs=6, color=IRON)
b.cyl("paint", 0.37, 0.37, 0.09, segs=10, loc=g(0, -0.05, 0.08), color=CHAR)
b.box("paint", (0.40, 0.20, 0.45), loc=g(0, 0.10, -0.31), color=CHAR)
b.box("paint", (0.22, 0.04, 0.14), loc=g(0, 0.20, 0.405), color="brass")
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED, one on
# each cheek of the hoist block (the cup hides the body).
crew.cast_number(b, "paint", "05", (0.185, -0.18, 0.80), (1, 0, 0), 0.15)
crew.hired(b, "paint", (-0.185, -0.18, 0.80), (-1, 0, 0), 0.05)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

# Cup wall: four rings, sealed underside and a recessed floor, no top cap.
c = Part("CatchCup")
c.bevel = 0
c.subsurf = 0
bm = c.bm
N = 16
spec = [(0.30, -0.40), (0.48, 0.40), (0.42, 0.40), (0.24, -0.28)]
rows = [[bm.verts.new(Vector(g(r * math.cos(k * math.tau / N), y, r * math.sin(k * math.tau / N))))
         for k in range(N)] for r, y in spec]
bottom = bm.verts.new(Vector(g(0, -0.40, 0)))
floor = bm.verts.new(Vector(g(0, -0.28, 0)))
for k in range(N):
    n = (k + 1) % N
    col = "oxide" if k % 4 in (0, 1) else PLATE
    c.paint([bm.faces.new((rows[0][k], rows[0][n], rows[1][n], rows[1][k]))], "paint", col)
    c.paint([bm.faces.new((rows[1][k], rows[1][n], rows[2][n], rows[2][k]))], "paint", WORN)
    c.paint([bm.faces.new((rows[2][k], rows[2][n], rows[3][n], rows[3][k]))], "paint", CHAR)
    c.paint([bm.faces.new((rows[3][k], rows[3][n], floor))], "paint", CHAR)
    c.paint([bm.faces.new((rows[0][n], rows[0][k], bottom))], "paint", CHAR)

# Release assembly on +X: charcoal spring core, four iron collars, worn paddle,
# dark pivot pin and a red latch at its upper end. All are outside the well.
c.box("paint", (0.045, 0.10, 0.40), loc=g(0.415, -0.02, 0.02), color=CHAR)
for y in (-0.16, -0.06, 0.04, 0.14):
    c.box("paint", (0.055, 0.14, 0.04), loc=g(0.425, y, 0.02), color=IRON)
c.box("paint", (0.04, 0.09, 0.50), loc=g(0.46, 0.06, -0.04), color=WORN)
c.cyl("paint", 0.055, 0.055, 0.07, segs=8, loc=g(0.445, -0.15, -0.04), rot=(0, math.pi / 2, 0), color=CHAR)
c.box("paint", (0.035, 0.08, 0.08), loc=g(0.46, 0.27, -0.04), color="hazard")
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
cup = c.to_object(parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
surfaces = len(body.data.materials) + len(cup.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "CUP_MOUTH_R", 0.48, "CUP_BASE_R", 0.30,
      "CUP_HEIGHT", 0.80, "BODY_TRIS", common.tris(body), "CUP_TRIS", common.tris(cup))
if tris > 3600 or surfaces > 3:
    raise SystemExit("C22 budget exceeded")
for obj, offset in ((body, Vector(g(0, 0, 0))), (cup, Vector(g(0, 1.6, -0.3)))):
    for v in obj.data.vertices:
        p = v.co + offset
        if math.hypot(p.x, p.y) > 0.8001:
            raise SystemExit("C22 carried collider footprint exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_catch_trap.glb"))
