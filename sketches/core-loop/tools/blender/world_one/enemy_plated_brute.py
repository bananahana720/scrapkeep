# C15 Plated brute: a hulking Fleet animal crew wearing ONE plate group, a welded front slab
# with shoulder and rear cladding. The group is the silhouette; when it pops the body under it
# is visibly smaller. The recipe replaces the capsule crew, head, ears and tag counter.gd
# dressed it with and the three boxes plated_brute.gd built. Blender +Z is up and +Y is back (the
# exporter turns +Y into Godot -Z), so the brute faces -Y. Origin is the collider centre, ground
# at z = -1.1 (the 2.2 m capsule the collider keeps, radius 0.8).
#
# The cue rides thin trim only: narrow edge strips (slab sides, brow front, cap outer edges) and
# the bolts carry vertex colour black (the amber cue mask); brows, caps and slabs are plain plate.
# No draw is added.
#
# Two meshes, three surfaces (three colour-pass draws, the E ceiling), no alpha.
# Four glTF joints preserve those surfaces: feet, rearing torso, and
# SlamPadLeft/SlamPadRight. The arms blend from torso to pad at the shoulder;
# the existing rigid arm/fist pads and the plate group keep their geometry.
#   BruteBody    fleet_paint (torso, head, hump, shoulders, arms, legs; flashes with the enemy)
#                and paint (vertex colour: fists, feet, strap, the one brass tag,
#                worn on the chest so the plate hides it until it pops).
#   BrutePlates  one surface, bare_metal (the runtime gives it the enemy's tinted plate material
#                and hides the whole node when the last plate pops). Front slab centred on the
#                base slab (2.0 x 1.9 x 0.5, front face 1.35 m from the origin), shoulder
#                cladding where the base pads sat (x = +-1.15) and a rear slab.
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_plated_brute.py -- [--out file.glb]

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
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("PlatedBrute")

GROUND = -1.1
CHAR = "charcoal"
# Vertex colour black marks the thin trim strips (brow front edge, ribs, slab and cap outer edges) and every bolt: the runtime lights
# only those vertices in amber (enemy.gd emission mask); white plate faces stay unlit.
RIM = "000000"
BRASS = "brass"

# --- Body: a squat barrel torso, hump, arms hanging to fists, a low head --------------
b = Part("BruteBody")
weights = b.bm.verts.layers.deform.new()


def bind_new(bone):
    for vertex in b.bm.verts:
        if not vertex[weights]:
            vertex[weights][bone] = 1.0

for s in (-1, 1):
    b.cyl("fleet_paint", 0.30, 0.34, 0.6, segs=8, loc=(s * 0.34, 0.0, -0.8))  # legs
    b.box("paint", (0.36, 0.52, 0.16), loc=(s * 0.34, -0.08, -1.02), color=CHAR)  # feet
bind_new(0)  # Feet and legs stay planted.
b.cyl("fleet_paint", 0.62, 0.78, 1.3, segs=12, loc=(0, 0, 0.05))  # torso
b.cyl("paint", 0.79, 0.79, 0.10, segs=12, loc=(0, 0, -0.08), color=CHAR)  # strap
b.uv("fleet_paint", 0.42, u=8, v=5, loc=(0, 0.36, 0.5), scale=(1.0, 0.85, 0.85))  # hump
bind_new(1)
for s in (-1, 1):
    b.uv("fleet_paint", 0.30, u=8, v=5, loc=(s * 0.46, 0.0, 0.66))  # shoulder
    bind_new(1)  # The fixed shoulder remains with the torso.
    shoulder = Vector((s * 0.48, -0.02, 0.6))
    fist = Vector((s * 0.5, -0.12, -0.4))
    # The arm and its blend sleeve stay unbevelled and unsubdivided: the windup test and the
    # skin pin the shared pad and shoulder rings to their exact rest positions.
    with b.region(bevel=0.0, subsurf=0):
        faces = b.rod("fleet_paint", shoulder, fist, 0.14, segs=6)  # rigid pad arm
        pad_bone = 2 if s < 0 else 3
        bind_new(pad_bone)
        # Share the pad's actual top ring, rather than approximating its tilted plane.
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
    b.uv("paint", 0.19, u=6, v=4, loc=(s * 0.5, -0.12, -0.44), color=CHAR)  # fist
    bind_new(2 if s < 0 else 3)
crew.lifting_beam_head(b, (0, -0.12, 1.0), 0.38)
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.72, 0.22), color=BRASS)  # the one brass tag
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED. The
# plates cover both until they pop, so the marks are part of what the strip reveals.
crew.cast_number(b, "paint", "24", (0, -0.75, 0.5), (0, -1, 0), 0.22)
crew.hired(b, "paint", (0, 0.66, -0.3), (0, 1, 0), 0.1)
bind_new(1)
body = b.to_object(parent=root)
# The blended arms and rigid pads share the body's two material surfaces.
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

# --- Plate group: front slab, brow, ribs, bolts, shoulder and rear cladding ----------
p = Part("BrutePlates")
p.subsurf = 0
p.box("bare_metal", (2.0, 0.5, 1.9), loc=(0, -1.10, 0.10))  # front slab, face at -1.35
p.box("bare_metal", (2.1, 0.62, 0.22), loc=(0, -1.14, 1.02))  # brow lip (plate; only its front edge is trim)
p.box("bare_metal", (2.0, 0.05, 0.05), loc=(0, -1.435, 1.135), color=RIM)  # brow front edge
for s in (-1, 1):
    p.box("bare_metal", (0.08, 0.06, 1.5), loc=(s * 0.78, -1.37, 0.10), color=RIM)  # ribs
    p.box("bare_metal", (0.7, 1.7, 0.5), loc=(s * 1.15, -0.05, 0.66))  # shoulder cladding
    p.box("bare_metal", (0.5, 1.4, 0.2), loc=(s * 1.15, -0.05, 0.98))  # shoulder cap (plate)
    p.box("bare_metal", (0.07, 1.4, 0.05), loc=(s * 1.385, -0.05, 1.085), color=RIM)  # cap outer edge
    p.box("bare_metal", (0.06, 0.07, 1.9), loc=(s * 0.985, -1.365, 0.10), color=RIM)  # slab outer edge
    for z in (-0.5, 0.5):
        p.paint(p.bolt((s * 0.78, -1.40, 0.10 + z), (0, -1, 0), r=0.07, h=0.06, segs=6), "bare_metal", RIM)
    for y in (-0.5, 0.4):
        p.paint(p.bolt((s * 1.15, y, 1.08), (0, 0, 1), r=0.08, h=0.06, segs=6), "bare_metal", RIM)
    p.box("bare_metal", (0.42, 0.5, 0.5), loc=(s * 0.55, -1.06, -0.85))  # kick block
p.box("bare_metal", (1.5, 0.4, 1.3), loc=(0, 1.0, 0.10))  # rear slab
p.box("bare_metal", (1.7, 0.3, 0.2), loc=(0, 1.0, 0.85))  # rear cap (plate)
p.box("bare_metal", (1.7, 0.07, 0.05), loc=(0, 1.135, 0.955), color=RIM)  # rear cap outer edge
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
