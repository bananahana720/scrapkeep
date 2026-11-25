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
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Swatter")
PIVOT = -0.6
CHAR = "charcoal"
PLATE = common.mix("oxide", "charcoal", 0.18)
HI = common.mix("oxide", "bone", 0.10)
IRON = common.mix("charcoal", "bone", 0.38)


def g(x, y, z):
    return (x, -z, y)


b = Part("SwatterBody")
b.cyl("fleet_paint", 0.57, 0.65, 1.0, segs=10, loc=g(0, -0.60, 0))
b.cyl("fleet_paint", 0.65, 0.51, 0.85, segs=10, loc=g(0, 0.325, 0))
crew.brush_head(b, g(0, 1.10, 0.08), 0.33)
b.cyl("paint", 0.66, 0.66, 0.12, segs=10, loc=g(0, -0.12, 0), color=CHAR)
b.box("paint", (0.46, 0.20, 0.52), loc=g(0, 0.16, -0.62), color=CHAR)
b.box("paint", (0.28, 0.05, 0.18), loc=g(0, 0.28, 0.55), color="brass")
for side in (-1, 1):
    b.rod("paint", g(side * 0.42, 0.36, 0.14), g(side * 0.20, -0.45, 0.42), 0.10, segs=6, color=PLATE)
    b.box("paint", (0.18, 0.26, 0.20), loc=g(side * 0.13, -0.53, 0.50), color=CHAR)
crew.cast_number(b, "paint", "29", (0, -0.527, 0.58), (0, -1, 0), 0.18)
crew.hired(b, "paint", (0, 0.725, 0.16), (0, 1, 0), 0.08)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

p = Part("SwatterPaddle")
p.bevel = 0
p.subsurf = 0
p.box("paint", (0.2, 5.5, 0.2), loc=g(0, PIVOT, 2.9), color=CHAR)
p.box("paint", (0.09, 3.8, 0.018), loc=g(0, PIVOT + 0.090, 2.70), color=PLATE)
for z in (0.55, 3.85):
    p.box("paint", (0.20, 0.13, 0.03), loc=g(0, PIVOT + 0.085, z), color=IRON)

outline = [(-0.30, 4.72), (-0.18, 4.60), (0.58, 4.60), (0.70, 4.72),
           (0.70, 6.08), (0.58, 6.20), (-0.18, 6.20), (-0.30, 6.08)]
rows = [[p.bm.verts.new(Vector(g(x, PIVOT + y, z))) for y, z in outline] for x in (-0.15, 0.15)]
p.paint([p.bm.faces.new(tuple(reversed(rows[0]))), p.bm.faces.new(tuple(rows[1]))], "paint", CHAR)
for i in range(len(outline)):
    j = (i + 1) % len(outline)
    p.paint([p.bm.faces.new((rows[0][i], rows[0][j], rows[1][j], rows[1][i]))], "paint", PLATE)

for side in (-1, 1):
    x = side * 0.151
    for z0, z1, col in ((4.70, 5.36, PLATE), (5.41, 6.10, "oxide")):
        face = [p.bm.verts.new(Vector(g(x, PIVOT + y, z))) for y, z in
                ((-0.20, z0), (0.55, z0), (0.62, z0 + 0.07), (0.62, z1), (-0.20, z1))]
        p.paint([p.bm.faces.new(tuple(face if side > 0 else reversed(face)))], "paint", col)
    for coords, col in ((((-0.19, 5.82), (-0.19, 6.07), (-0.06, 6.07)), IRON),
                        (((0.43, 4.71), (0.56, 4.78), (0.43, 5.08)), HI)):
        vs = [p.bm.verts.new(Vector(g(side * 0.152, PIVOT + y, z))) for y, z in coords]
        p.paint([p.bm.faces.new(tuple(vs if side > 0 else reversed(vs)))], "paint", col)
p.box("paint", (0.32, 1.62, 0.10), loc=g(0, PIVOT + 0.66, 5.4), color="hazard")
bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
paddle = p.to_object(origin=g(0, PIVOT, 0), parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
surfaces = len(body.data.materials) + len(paddle.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY", common.tris(body), "PADDLE", common.tris(paddle),
      "SHAFT_LENGTH", 5.5, "PADDLE_LENGTH", 1.6, "PIVOT_GODOT", (0, PIVOT, 0))
if tris > 3300 or surfaces > 3:
    raise SystemExit("C20 assembly ceiling exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_swatter.glb"))
