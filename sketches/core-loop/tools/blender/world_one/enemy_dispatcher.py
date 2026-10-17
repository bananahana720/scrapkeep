"""Dispatcher: a kill-first spawner, the cache body clamped to a perch, wearing a headset,
with a pneumatic tube that drops a chaser every 8 s.

ENEMY-PRIORITY.md lever 4: the cache chassis (the vault body) on a perch 6 to 10 m up. It
drops one chaser at a time, spending the attacker budget, until it is broken; reach it by
grapple, vault or a long gun. Silhouette: a squat octagonal box up high with a radar paddle
on top, a headset band over its lid and a fat tube that curls off its front and points down,
the one enemy whose outline says "things come out of here". It never moves.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). It faces Godot -Z. The body is the vault's
octagon (2.88 m across, Y -1.15 to 1.15); four magnet clamps put its floor at Y = -1.5.
The tube reaches 3.4 m out front and its mouth stays above the floor, so any flat perch top
works; set it with the front toward the drop and the tube clears the edge.
Three meshes, three surfaces, all opaque vertex colour:
  DispatcherBody    fleet_paint: the box, lid, clamps, headset and mic boom, ticket printer and
                    its paper tongue, the tube. Flashes with the enemy.
  DispatcherRadar   fleet_paint: the radar paddle. Origin on the mast head; the runtime spins
                    it round Y, a quarter turn per beat with dispatcher_presence's ping.
  DispatcherSignal  requisition_tag: tube bands and mouth lip, the two eye lenses, the mic
                    capsule and the beacon. Brass at rest; the runtime lights it for each drop,
                    with dispatcher_tell (the tube sucks up, then the double ding). No glow is
                    baked into the file.
Sockets (empties, no draws): drop_mouth (each chaser spawns here; its -Z is the way out of
the tube), Beacon, TicketSlot, RadarPivot, perch_foot (centre of the clamp pads).
Procedural bmesh in this repository; no external meshes or textures.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir]
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import common
from common import Part

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
root = common.empty("Dispatcher")

FLOOR = -1.5
PETROL = "petrol"
OXIDE = "9b513a"
CHAR = "charcoal"
BONE = "bone"
BRASS = "brass"
PIVOT = (0.0, 2.3, 0.7)


def g(x, y, z):
    return (x, -z, y)


def G(x, y, z):
    return Vector(g(x, y, z))


def gbox(part, slot, size, loc, color=None, rot=(0, 0, 0)):
    """A box sized in Godot order (width X, height Y, depth Z)."""
    return part.box(slot, (size[0], size[2], size[1]), loc=loc, rot=rot, color=color)


body = Part("DispatcherBody")
signal = Part("DispatcherSignal")

# The vault's octagon: petrol box, a lighter lid band and a charcoal skirt.
FOOT = [(-1.25, -1.44), (1.25, -1.44), (1.44, -1.25), (1.44, 1.25),
        (1.25, 1.44), (-1.25, 1.44), (-1.44, 1.25), (-1.44, -1.25)]
body.prism("fleet_paint", FOOT, 2.3, color=PETROL)
body.prism("fleet_paint", [(x * 1.04, y * 1.04) for x, y in FOOT], 0.16,
           matrix=common.mtx(g(0, 1.14, 0)), color=common.mix(PETROL, BONE, 0.14))
body.prism("fleet_paint", [(x * 1.02, y * 1.02) for x, y in FOOT], 0.14,
           matrix=common.mtx(g(0, -1.2, 0)), color=CHAR)
# A welded oxide patch on the left flank, as the cache wears it.
gbox(body, "fleet_paint", (0.05, 0.6, 0.9), loc=g(-1.46, -0.35, 0.35), color=OXIDE)

# Face: two porthole eyes over a ticket printer whose paper tongue curls out and down.
for sx in (-1, 1):
    body.cyl("fleet_paint", 0.3, 0.3, 0.08, segs=8, loc=g(sx * 0.52, 0.55, -1.47),
             rot=(math.pi / 2, 0, 0), color=CHAR)
    signal.cyl("requisition_tag", 0.19, 0.19, 0.1, segs=8, loc=g(sx * 0.52, 0.55, -1.5),
               rot=(math.pi / 2, 0, 0), color=BRASS)
gbox(body, "fleet_paint", (1.0, 0.22, 0.12), loc=g(-0.1, -0.05, -1.48), color=CHAR)
TONGUE = [(-0.1, -0.05, -1.55), (-0.1, -0.3, -1.76), (0.0, -0.8, -1.66)]
for a, b in zip(TONGUE, TONGUE[1:]):
    body.beam("fleet_paint", G(*a), G(*b), 0.5, 0.025, color=BONE)

# Headset: a band over the lid, a cup on each side and a mic boom round to the mouth.
body.ring("fleet_paint", 1.42, 1.56, 0.2, segs=8, loc=g(0, 0.4, -0.25), rot=(math.pi / 2, 0, 0),
          arc=(0.0, math.pi), color=CHAR)
for sx in (-1, 1):
    body.cyl("fleet_paint", 0.44, 0.44, 0.2, segs=8, loc=g(sx * 1.55, 0.4, -0.25),
             rot=(0, math.pi / 2, 0), color=CHAR)
    body.cyl("fleet_paint", 0.3, 0.3, 0.06, segs=8, loc=g(sx * 1.67, 0.4, -0.25),
             rot=(0, math.pi / 2, 0), color=OXIDE)
BOOM = [(-1.6, 0.4, -0.25), (-1.55, 0.0, -1.2), (-1.0, -0.2, -1.7), (-0.55, -0.22, -1.78)]
for a, b in zip(BOOM, BOOM[1:]):
    body.rod("fleet_paint", G(*a), G(*b), 0.05, segs=4, color=CHAR)
signal.uv("requisition_tag", 0.11, u=6, v=4, loc=g(*BOOM[-1]), color=BRASS)

# Magnet clamps: four splayed legs onto round pads, pad soles on the floor.
for sx in (-1, 1):
    for sz in (-1, 1):
        body.rod("fleet_paint", G(sx * 0.95, -1.2, sz * 0.95), G(sx * 1.2, -1.36, sz * 1.2), 0.1,
                 segs=4, color=CHAR)
        body.cyl("fleet_paint", 0.3, 0.3, 0.08, segs=4, loc=g(sx * 1.2, FLOOR + 0.04, sz * 1.2), color=CHAR)

# Pneumatic tube: out of the lower front, forward and down off the perch edge. Round elbows,
# a brass collar past each and a flared brass lip on the mouth.
TUBE = [(0.62, -0.55, -1.2), (0.62, -0.45, -2.15), (0.62, -0.62, -2.85), (0.62, -0.9, -3.25)]
for a, b in zip(TUBE, TUBE[1:]):
    body.rod("fleet_paint", G(*a), G(*b), 0.38, segs=8, color=OXIDE)
for i, p in enumerate(TUBE[1:-1]):
    p = Vector(p)
    body.uv("fleet_paint", 0.38, u=8, v=4, loc=g(*p), color=OXIDE)
    d = (Vector(TUBE[i + 2]) - p).normalized()
    signal.rod("requisition_tag", G(*(p + d * 0.08)), G(*(p + d * 0.24)), 0.44, segs=8, color=BRASS)
signal.rod("requisition_tag", G(*TUBE[0]) + Vector(g(0, 0, -0.18)), G(*TUBE[0]) + Vector(g(0, 0, -0.42)),
           0.46, segs=8, color=BRASS)
out = (Vector(TUBE[-1]) - Vector(TUBE[-2])).normalized()
mouth = Vector(TUBE[-1])
signal.rod("requisition_tag", G(*(mouth - out * 0.12)), G(*(mouth + out * 0.14)), 0.42, segs=8, r2=0.58,
           color=BRASS)
body.rod("fleet_paint", G(*(mouth - out * 0.3)), G(*(mouth + out * 0.12)), 0.2, segs=6, r2=0.46, color=CHAR)
# A feed line from the lid down to the tube's root: the pneumatic system's supply.
body.rod("fleet_paint", G(1.1, 1.15, -0.9), G(0.9, 0.2, -1.5), 0.09, segs=4, color=OXIDE)
body.rod("fleet_paint", G(0.9, 0.2, -1.5), G(0.66, -0.3, -1.6), 0.09, segs=4, color=OXIDE)

# Radar mast at the rear of the lid, beacon on its tip above the spinning paddle.
body.rod("fleet_paint", G(0, 1.15, 0.7), G(*PIVOT), 0.11, segs=6, color=CHAR)
body.rod("fleet_paint", G(*PIVOT), G(PIVOT[0], PIVOT[1] + 0.55, PIVOT[2]), 0.05, segs=4, color=CHAR)
BEACON = (PIVOT[0], PIVOT[1] + 0.68, PIVOT[2])
signal.uv("requisition_tag", 0.17, u=6, v=4, loc=g(*BEACON), color=BRASS)

bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
bmesh.ops.recalc_face_normals(signal.bm, faces=signal.bm.faces[:])
body_obj = body.to_object(parent=root)
signal_obj = signal.to_object(parent=root)

# Radar paddle round its own origin on the mast head: a slatted bar tipped back, facing -Z.
radar = Part("DispatcherRadar")
tilt = (math.radians(-18), 0, 0)
gbox(radar, "fleet_paint", (1.9, 0.42, 0.08), loc=g(0, 0.2, -0.05), rot=tilt, color=common.mix(PETROL, BONE, 0.3))
for x in (-0.6, 0.6):
    gbox(radar, "fleet_paint", (0.06, 0.46, 0.06), loc=g(x, 0.2, -0.1), rot=tilt, color=CHAR)
radar.cyl("fleet_paint", 0.14, 0.14, 0.16, segs=6, loc=g(0, 0.0, 0), color=CHAR)
bmesh.ops.translate(radar.bm, vec=Vector(g(*PIVOT)), verts=radar.bm.verts)
radar_obj = radar.to_object(origin=g(*PIVOT), parent=root)

# drop_mouth: -Z (a chaser's lead) along the tube's way out.
drop = common.empty("drop_mouth", G(*(mouth + out * 0.14)), parent=root)
# The turn is found in Godot axes, then conjugated into Blender axes for the empty.
drop.rotation_euler = (Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))) @
                       Vector((0, 0, -1)).rotation_difference(out).to_matrix() @
                       Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))).to_euler()
common.empty("Beacon", G(*BEACON), parent=root)
common.empty("TicketSlot", G(-0.1, -0.05, -1.55), parent=root)
common.empty("RadarPivot", G(*PIVOT), parent=root)
common.empty("perch_foot", G(0, FLOOR, 0), parent=root)

bpy.context.view_layer.update()
objs = (body_obj, signal_obj, radar_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
reach = max(p.y for p in points)
tris = common.tri_total(root)
print("DISPATCHER floor %.3f top %.3f front reach %.3f tris %d" % (low, high, reach, tris))
assert low >= FLOOR - 1e-4 and high <= 3.2 and reach <= 3.8
assert tris <= 1100

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_dispatcher.glb")
common.export(root, path)
data = open(path, "rb").read()
size = struct.unpack_from("<I", data, 12)[0]
glb = json.loads(data[20:20 + size])
prims = [p for m in glb["meshes"] for p in m["primitives"]]
verts = sum(glb["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
tri_count = sum(glb["accessors"][p["indices"]]["count"] // 3 for p in prims)
assert verts <= 2100 and tri_count <= 1100 and len(prims) == 3
print(f"DISPATCHER EXPORTED: {verts} V / {tri_count} T / {len(prims)} D")

if opts["render"]:
    import kill_first_preview

    def perch():
        """Previews only: the dispatcher on a 7 m post top, the ball on the ground below."""
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.75, depth=7.0, location=(0, 0, FLOOR - 3.5))
        bpy.context.object.data.materials.append(common._flat("PerchPost", "6f6a5e"))

    kill_first_preview.render("dispatcher", root, opts["render"], FLOOR - 7.0, focus=(0, -1.0, 0.4), scale=8.0,
                              ball_x=-30, extras=perch, game_target=(0, 0, -3.0))
