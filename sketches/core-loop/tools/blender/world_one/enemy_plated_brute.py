import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("PlatedBrute")

GROUND = -1.1
CHAR = "charcoal"
RIM = "000000"
BRASS = "brass"

b = Part("BruteBody")
weights = b.bm.verts.layers.deform.new()


def bind_new(bone):
    for vertex in b.bm.verts:
        if not vertex[weights]:
            vertex[weights][bone] = 1.0

for s in (-1, 1):
    b.cyl("fleet_paint", 0.30, 0.34, 0.6, segs=8, loc=(s * 0.34, 0.0, -0.8))
    b.box("paint", (0.36, 0.52, 0.16), loc=(s * 0.34, -0.08, -1.02), color=CHAR)
bind_new(0)
b.cyl("fleet_paint", 0.62, 0.78, 1.3, segs=12, loc=(0, 0, 0.05))
b.cyl("paint", 0.79, 0.79, 0.10, segs=12, loc=(0, 0, -0.08), color=CHAR)
b.uv("fleet_paint", 0.42, u=8, v=5, loc=(0, 0.36, 0.5), scale=(1.0, 0.85, 0.85))
bind_new(1)
for s in (-1, 1):
    b.uv("fleet_paint", 0.30, u=8, v=5, loc=(s * 0.46, 0.0, 0.66))
    bind_new(1)
    shoulder = Vector((s * 0.48, -0.02, 0.6))
    fist = Vector((s * 0.5, -0.12, -0.4))
    with b.region(bevel=0.0, subsurf=0):
        faces = b.rod("fleet_paint", shoulder, fist, 0.14, segs=6)
        pad_bone = 2 if s < 0 else 3
        bind_new(pad_bone)
        axis = (fist - shoulder).normalized()
        top = {v for face in faces for v in face.verts
               if abs((v.co - shoulder).dot(axis)) < 0.00001}
        top = sorted(top, key=lambda v: math.atan2(v.co.y - shoulder.y, v.co.x - shoulder.x))
        rings = []
        for offset, pad_weight in ((-0.15, 0.0), (-0.075, 0.5)):
            ring = []
            for vertex in top:
                lower = b.bm.verts.new(vertex.co + Vector((0, 0, offset)))
                lower[weights][1] = 1.0 - pad_weight
                if pad_weight > 0.0:
                    lower[weights][pad_bone] = pad_weight
                ring.append(lower)
            rings.append(ring)
        rings.append(top)
        for lower, upper in zip(rings, rings[1:]):
            sleeve = [b.bm.faces.new((lower[i], lower[(i + 1) % 6],
                                    upper[(i + 1) % 6], upper[i])) for i in range(6)]
            b.paint(sleeve, "fleet_paint")
    b.uv("paint", 0.19, u=6, v=4, loc=(s * 0.5, -0.12, -0.44), color=CHAR)
    bind_new(2 if s < 0 else 3)
crew.lifting_beam_head(b, (0, -0.12, 1.0), 0.38)
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.72, 0.22), color=BRASS)
crew.cast_number(b, "paint", "24", (0, -0.75, 0.5), (0, -1, 0), 0.22)
crew.hired(b, "paint", (0, 0.66, -0.3), (0, 1, 0), 0.1)
bind_new(1)
body = b.to_object(parent=root)
rig_data = bpy.data.armatures.new("BruteWindup")
rig = bpy.data.objects.new("BruteWindup", rig_data)
bpy.context.scene.collection.objects.link(rig)
rig.parent = root
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, head in (("BruteFeet", (0, 0, GROUND)),
                   ("BruteRear", (0, 0, GROUND)),
                   ("SlamPadLeft", (-0.5, -0.12, -0.44)),
                   ("SlamPadRight", (0.5, -0.12, -0.44))):
    bone = rig_data.edit_bones.new(name)
    bone.head = head
    bone.tail = (head[0], head[1], head[2] + 0.3)
bpy.ops.object.mode_set(mode="OBJECT")
for name in ("BruteFeet", "BruteRear", "SlamPadLeft", "SlamPadRight"):
    body.vertex_groups.new(name=name)
modifier = body.modifiers.new("Windup", "ARMATURE")
modifier.object = rig
body.parent = rig

p = Part("BrutePlates")
p.subsurf = 0
p.box("bare_metal", (2.0, 0.5, 1.9), loc=(0, -1.10, 0.10))
p.box("bare_metal", (2.1, 0.62, 0.22), loc=(0, -1.14, 1.02))
p.box("bare_metal", (2.0, 0.05, 0.05), loc=(0, -1.435, 1.135), color=RIM)
for s in (-1, 1):
    p.box("bare_metal", (0.08, 0.06, 1.5), loc=(s * 0.78, -1.37, 0.10), color=RIM)
    p.box("bare_metal", (0.7, 1.7, 0.5), loc=(s * 1.15, -0.05, 0.66))
    p.box("bare_metal", (0.5, 1.4, 0.2), loc=(s * 1.15, -0.05, 0.98))
    p.box("bare_metal", (0.07, 1.4, 0.05), loc=(s * 1.385, -0.05, 1.085), color=RIM)
    p.box("bare_metal", (0.06, 0.07, 1.9), loc=(s * 0.985, -1.365, 0.10), color=RIM)
    for z in (-0.5, 0.5):
        p.paint(p.bolt((s * 0.78, -1.40, 0.10 + z), (0, -1, 0), r=0.07, h=0.06, segs=6), "bare_metal", RIM)
    for y in (-0.5, 0.4):
        p.paint(p.bolt((s * 1.15, y, 1.08), (0, 0, 1), r=0.08, h=0.06, segs=6), "bare_metal", RIM)
    p.box("bare_metal", (0.42, 0.5, 0.5), loc=(s * 0.55, -1.06, -0.85))
p.box("bare_metal", (1.5, 0.4, 1.3), loc=(0, 1.0, 0.10))
p.box("bare_metal", (1.7, 0.3, 0.2), loc=(0, 1.0, 0.85))
p.box("bare_metal", (1.7, 0.07, 0.05), loc=(0, 1.135, 0.955), color=RIM)
for x in (-0.5, 0.5):
    p.paint(p.bolt((x, 1.2, 0.3), (0, 1, 0), r=0.07, h=0.06, segs=6), "bare_metal", RIM)
plates = p.to_object(parent=root)
bpy.context.view_layer.update()


def stats(obj):
    vs = [v.co for v in obj.data.vertices]
    return (max(math.hypot(v.x, v.y) for v in vs), min(v.z for v in vs), max(v.z for v in vs))


body_r, body_lo, body_hi = stats(body)
plate_r, plate_lo, plate_hi = stats(plates)
t_body = common.tris(body)
t_plates = common.tris(plates)
surfaces = len(body.data.materials) + len(plates.data.materials)
print("TRIS", t_body + t_plates, "BODY", t_body, "PLATES", t_plates, "SURFACES", surfaces,
      "BODY_R", round(body_r, 3), "BODY_Z", round(body_lo, 3), round(body_hi, 3),
      "PLATE_R", round(plate_r, 3), "PLATE_Z", round(plate_lo, 3), round(plate_hi, 3))
if (t_body + t_plates > 5500 or surfaces > 3 or body_r > 0.8 or body_lo < GROUND - 0.001
        or body_hi > 2.3 or plate_r > 1.8 or plate_lo < GROUND - 0.001 or plate_hi > 1.3):
    raise SystemExit("C15 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_plated_brute.glb"))
