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
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0, bake_slots=())
root = common.empty("Winch")

HALF_PI = math.pi / 2
ROTOR_Y = 2.0
ROTOR_R = 1.6
ROTOR_T = 0.08
BLADE_ANGLES = (0, 115, 245)
DRUM_Y = -1.40
DRUM_R = 0.45
DRUM_LEN = 0.90
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.55)
PLATE = common.mix("oxide", "charcoal", 0.18)
PLATE_HI = common.mix("oxide", "bone", 0.10)
IRON = common.mix("charcoal", "oxide", 0.28)
DRUM_PAINT = common.mix("oxide", "charcoal", 0.35)
BRASS = "brass"


def g(x, y, z):
    """Godot (x, y up, z forward) to Blender (x, y = -z, z = y)."""
    return (x, -z, y)


b = Part("WinchBody")

b.cyl("fleet_paint", 0.50, 0.62, 0.70, segs=10, loc=g(0, -0.40, 0))
b.cyl("fleet_paint", 0.62, 0.56, 0.60, segs=10, loc=g(0, 0.25, 0))
crew.buoy_head(b, g(0, 0.85, 0.20), 0.32)
b.cyl("paint", 0.64, 0.64, 0.10, segs=10, loc=g(0, -0.02, 0), color=CHAR)
b.box("paint", (0.50, 0.55, 0.30), loc=g(0, 0.15, -0.62), color=CHAR)
b.box("paint", (0.28, 0.18, 0.05), loc=g(0, 0.20, 0.60), color=BRASS)
for s in (-1, 1):
    b.box("paint", (0.06, 0.55, 0.42), loc=g(s * 0.62, 0.20, 0.05), color=PLATE)

b.rod("paint", g(0, 0.6, -0.32), g(0, ROTOR_Y - 0.06, -0.32), 0.09, segs=6, color=CHAR)
for s in (-1, 1):
    b.rod("paint", g(s * 0.45, 0.62, -0.05), g(0, 1.55, -0.32), 0.05, segs=5, color=IRON)
b.cyl("paint", 0.30, 0.26, 0.12, segs=8, loc=g(0, ROTOR_Y - 0.10, -0.32), rot=(0, 0, 0), color=CHAR)

b.cyl("paint", 0.14, 0.18, 0.30, segs=6, loc=g(0, -0.88, 0), color=CHAR)
b.box("paint", (0.92, 0.10, 0.60), loc=g(0, DRUM_Y + DRUM_R + 0.04, 0), color=IRON)
d = Part("WinchDrum")
drum = d.cyl("paint", DRUM_R, DRUM_R, DRUM_LEN, segs=16, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=DRUM_PAINT)
d.bm.normal_update()
d.paint([f for f in drum if abs(f.normal.x) > 0.9], "paint", CHAR)
d.cyl("paint", DRUM_R + 0.05, DRUM_R + 0.05, 0.26, segs=8, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=WORN)

crew.cast_number(b, "paint", "33", (0, -0.556, 0.45), (0, -1, 0), 0.16)
crew.hired(b, "paint", (0, 0.9, 0.15), (0, 1, 0), 0.08)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)
bmesh.ops.recalc_face_normals(d.bm, faces=d.bm.faces[:])
drum_node = d.to_object(origin=g(0, DRUM_Y, 0), parent=root)

pivot = g(0, ROTOR_Y, 0)
r = Part("WinchRotor")
r.bevel = 0
r.subsurf = 0
rb = r.bm
r.cyl("paint", 0.28, 0.28, ROTOR_T, segs=8, loc=pivot, color=CHAR)


def blade_section(angle, inner, outer, color):
    outline = []
    for radius, side in ((inner, -1), (outer, -1), (outer, 1), (inner, 1)):
        theta = angle + side * math.radians(8)
        outline.append((radius * math.cos(theta), radius * math.sin(theta)))
    top = [rb.verts.new(Vector(g(x, ROTOR_Y + ROTOR_T / 2, z))) for x, z in outline]
    bot = [rb.verts.new(Vector(g(x, ROTOR_Y - ROTOR_T / 2, z))) for x, z in outline]
    r.paint([rb.faces.new(top), rb.faces.new(list(reversed(bot)))], "paint", color)
    for k in range(4):
        n = (k + 1) % 4
        r.paint([rb.faces.new((top[k], bot[k], bot[n], top[n]))], "paint", color)


for index, degrees in enumerate(BLADE_ANGLES):
    angle = math.radians(degrees)
    if index == 0:
        blade_section(angle, 0.23, 1.15, PLATE)
        blade_section(angle, 1.15, ROTOR_R, "bone")
    else:
        blade_section(angle, 0.23, ROTOR_R, PLATE)
bmesh.ops.recalc_face_normals(rb, faces=rb.faces[:])
rotor = r.to_object(origin=pivot, parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
points = [obj.matrix_world @ v.co for obj in (body, drum_node) for v in obj.data.vertices]
xs = [v.x for v in points]
ys = [v.y for v in points]
zs = [v.z for v in points]
surfaces = len(body.data.materials) + len(rotor.data.materials) + len(drum_node.data.materials)
rotor_drum = common.tris(rotor) + 64
print("TRIS", tris, "SURFACES", surfaces, "ROTOR", common.tris(rotor), "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3))
if tris > 4600 or surfaces > 4 or rotor_drum >= 150 or max(abs(x) for x in xs) > 1.0 or min(ys) < -1.1 or max(ys) > 1.0 \
        or min(zs) < DRUM_Y - DRUM_R - 0.06 or max(zs) > ROTOR_Y:
    raise SystemExit("C18 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_winch_drone.glb"))
