# C19 Gyro jammer: an oxide Fleet animal crew carrying a charcoal aerial with three
# concentric tilted metal hoops. The gyroscope is high above the head on the aerial:
# outer radii 0.55, 0.43 and 0.31 m, all centred at Godot (0, 3.55, -0.2).
# Each hoop is a 16-sector, four-sided tube (128 T). Their three oblique planes and
# charcoal inner faces leave intersecting openings; oxide faces and sparse grey edge
# chips cover the rims. There is no glowing ring or pickup-colour surface.
#
# Two meshes, three colour-pass surfaces, all opaque:
#   GyroBody: fleet_paint (barrel, chest, head) and paint (charcoal joints, aerial,
#             snout, ears, pack, oxide flank plates, worn edges and one brass tag).
#   GyroAerial: paint (three disconnected concentric hoops). Its origin is the base
#               aerial pivot (0, 2.6, -0.2); gyro_jammer.gd spins it on the existing
#               physics tick, 0.3 rad LIVE and 0.05 rad otherwise.
# Blender +Z is up; g() converts Godot metres to Blender. Ground is Godot y -1.1.
# Provenance: procedural bmesh, no external mesh or texture.
#
# systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#   blender -b --factory-startup -P enemy_gyro_jammer.py -- [--out file.glb]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("GyroJammer")
CHAR = "charcoal"
PLATE = common.mix("oxide", "charcoal", 0.18)
IRON = common.mix("charcoal", "oxide", 0.28)
WORN = common.mix("charcoal", "bone", 0.55)
PIVOT = (0, 2.6, -0.2)
CENTER = (0, 3.55, -0.2)


def g(x, y, z):
    return (x, -z, y)


b = Part("GyroBody")
b.cyl("fleet_paint", 0.54, 0.62, 1.0, segs=10, loc=g(0, -0.60, 0))
b.cyl("fleet_paint", 0.62, 0.50, 0.8, segs=10, loc=g(0, 0.3, -0.04))
crew.current_meter_head(b, g(0, 1.02, 0.13), 0.30)
for s in (-1, 1):
    b.box("paint", (0.07, 0.50, 0.40), loc=g(s * 0.59, 0.27, -0.03), color=PLATE)
    b.box("paint", (0.075, 0.38, 0.045), loc=g(s * 0.59, 0.48, -0.03), color=WORN)
    b.rod("paint", g(s * 0.42, 0.6, 0.16), g(s * 0.23, 0.3, 0.38), 0.08, segs=6, color=IRON)
b.cyl("paint", 0.63, 0.63, 0.09, segs=10, loc=g(0, -0.06, 0), color=CHAR)
b.box("paint", (0.46, 0.26, 0.55), loc=g(0, 0.25, -0.61), color=CHAR)
b.box("paint", (0.25, 0.045, 0.16), loc=g(0, 0.27, 0.57), color="brass")
# The aerial and two shoulder braces stand behind the head. A wide oxide socket
# joins the thin 3.4 m shaft to the pack; a charcoal bearing sits inside the hoops.
b.cyl("paint", 0.07, 0.07, 3.4, segs=8, loc=g(*PIVOT), color=CHAR)
b.cyl("paint", 0.16, 0.20, 0.32, segs=8, loc=g(0, 1.0, -0.2), color=PLATE)
for s in (-1, 1):
    b.rod("paint", g(s * 0.42, 0.52, -0.23), g(0, 1.5, -0.2), 0.045, segs=5, color=IRON)
b.cyl("paint", 0.105, 0.105, 0.16, segs=8, loc=g(*CENTER), color=CHAR)
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED.
crew.cast_number(b, "paint", "11", (0, -0.474, 0.52), (0, -1, 0), 0.2)
crew.hired(b, "paint", (0, 0.745, 0.25), (0, 1, 0), 0.08)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

r = Part("GyroAerial")
r.bevel = 0
r.subsurf = 0
# Normals in Godot space: three different oblique planes. The tube cross-section
# is a diamond, with a dark inner edge, broad oxide outer edge and isolated chips.
for ring, (radius, angles) in enumerate([
    (0.55, (70, 0, 20)), (0.43, (40, 0, -45)), (0.31, (100, 35, 0)),
]):
    rot = Euler(tuple(math.radians(a) for a in angles), "XYZ").to_matrix()
    rows = []
    tube = 0.035
    for k in range(16):
        a = math.tau * k / 16
        radial = Vector((math.cos(a), 0, math.sin(a)))
        row = []
        for j in range(4):
            t = math.tau * j / 4
            local = radial * (radius - tube + tube * math.cos(t)) + Vector((0, tube * math.sin(t), 0))
            p = Vector(CENTER) + rot @ local
            row.append(r.bm.verts.new(Vector(g(*p))))
        rows.append(row)
    for k in range(16):
        for j in range(4):
            n, q = (k + 1) % 16, (j + 1) % 4
            face = r.bm.faces.new((rows[k][j], rows[n][j], rows[n][q], rows[k][q]))
            col = CHAR if j in (1, 2) else (PLATE if ring == 1 else "oxide")
            if j == 0 and k in (2 + ring, 9 + ring):
                col = WORN
            r.paint([face], "paint", col)
bmesh.ops.recalc_face_normals(r.bm, faces=r.bm.faces[:])
aerial = r.to_object(origin=g(*PIVOT), parent=root)
bpy.context.view_layer.update()
tris = common.tri_total(root)
surfaces = len(body.data.materials) + len(aerial.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "HOOPS", common.tris(aerial))
if tris > 5000 or surfaces > 3 or common.tris(aerial) != 384:
    raise SystemExit("C19 limits exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_gyro_jammer.glb"))
