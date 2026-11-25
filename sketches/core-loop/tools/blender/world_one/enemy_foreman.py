"""Foreman: a kill-first buffer, the lobber cart with its mortar swapped for a punch clock
and a twin steam-horn mast.

ENEMY-PRIORITY.md lever 3: an elite on the lobber chassis with a horn mast. Thin tether
lines run from it to each crew member; while it lives the crew's plating shred is wiped
every 5 s, and the horn blasts on the beat before each wipe. It never attacks. Kill it and
the crew clocks out ("SHIFT OVER"). Silhouette: the tallest thing in its pack, a hard-hatted
clock cabinet under a mast with two brass horn bells (the D and the Ab of its tell), so the
player can find the boss of the pack from across the bowl.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). It faces Godot -Z (the clock face, the horn
bells); it can share the lobber's 2.4 x 7 x 2.4 m collider box: wheels on Y = -2, the cart
and cabinet within |x|, |z| <= 1.2 and Y <= 3.6; the mast stops at 4.5 and only the horn bells
rise past the box top (5.0), topping out under 5.95, so the Foreman stands over its crew.
The lobber's own model fronts Godot +Z; this one fronts -Z like the other specials, so the
lobber.gd affix turns it half a turn if it reuses the lobber's facing.
Three meshes, three surfaces, all opaque vertex colour:
  ForemanBody    fleet_paint: cart, cabinet, dial, hard hat, mast, reels, the bristle
                 moustache. Flashes with the enemy.
  ForemanHand    fleet_paint: the clock's one hand, skinned to the Hand bone on the dial
                 centre; the idle clip ticks it on the beat, the presence loop's clock tick.
  ForemanSignal  requisition_tag: both horn bells, the dial rim, the tether reel caps and
                 the steam valve. Brass at rest; the runtime lights it on the beat before
                 each wipe, with foreman_tell. No glow is baked into the file.
Sockets (empties, no draws): HornMouth (steam puff; its -Z blows out of the big bell), ClockFace (where the SHIFT OVER stamp
lands), tether_a..d (where each crew tether leaves its reel), SteamValve.
Procedural bmesh in this repository; no external meshes or textures.
Rig and clips (idle, tell, break): kill_first_motion.foreman.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir] [--sheet dir]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import common
import polish
from common import Part

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Foreman")

FLOOR = -2.0
HALF = 1.2
TOP = 5.95
OXIDE = "9b513a"
OXIDE_HI = "a8603f"
CHAR = "charcoal"
BONE = "bone"
HAT = "f0a81c"
BRASS = "brass"
DIAL = (0.0, 2.25, -0.5)
DIAL_R = 0.42


def g(x, y, z):
    return (x, -z, y)


def G(x, y, z):
    return Vector(g(x, y, z))


def gbox(part, slot, size, loc, color=None):
    """A box sized in Godot order (width X, height Y, depth Z)."""
    return part.box(slot, (size[0], size[2], size[1]), loc=loc, color=color)


def hull(part, slot, pts, color=None):
    """Convex hull of Godot points: broad flat planes, few triangles."""
    verts = [part.bm.verts.new(g(*p)) for p in pts]
    res = bmesh.ops.convex_hull(part.bm, input=verts)
    faces = [f for f in res["geom"] if isinstance(f, bmesh.types.BMFace)]
    return part.paint(faces, slot, color)


def block(y0, y1, w0, w1, d0, d1, z=0.0):
    """Godot frustum: half widths w along X and half depths d along Z, from y0 to y1."""
    return [(sx * w0, y0, z + sz * d0) for sx in (-1, 1) for sz in (-1, 1)] + \
           [(sx * w1, y1, z + sz * d1) for sx in (-1, 1) for sz in (-1, 1)]


body = Part("ForemanBody")
signal = Part("ForemanSignal")
signal.subsurf = 0

hull(body, "fleet_paint", block(-1.30, -0.62, 1.0, 1.0, 1.1, 1.1), OXIDE)
hull(body, "fleet_paint", block(-0.62, 0.95, 0.88, 0.72, 0.9, 0.74), OXIDE)
hull(body, "fleet_paint", block(0.95, 1.2, 1.2, 1.2, 1.2, 1.2), OXIDE_HI)
gbox(body, "fleet_paint", (2.05, 0.12, 2.05), loc=g(0, -0.98, 0), color=CHAR)
gbox(body, "fleet_paint", (1.66, 0.11, 1.4), loc=g(0, 0.3, 0), color=CHAR)
for sx in (-1, 1):
    for sz in (-1, 1):
        body.cyl("fleet_paint", 0.537, 0.537, 0.28, segs=8, loc=g(sx * 1.05, -1.5, sz * 0.68),
                 rot=(0, math.pi / 2, 0), color=CHAR)
    body.rod("fleet_paint", G(sx * 1.0, -1.5, -0.68), G(sx * 1.0, -1.5, 0.68), 0.1, segs=4, color=CHAR)

hull(body, "fleet_paint", block(1.2, 3.05, 0.68, 0.6, 0.48, 0.42), OXIDE)
body.cyl("fleet_paint", DIAL_R, DIAL_R, 0.06, segs=12, loc=g(*DIAL), rot=(math.pi / 2, 0, 0), color=BONE)
for y in (0.32, -0.32):
    gbox(body, "fleet_paint", (0.04, 0.09, 0.03), loc=g(DIAL[0], DIAL[1] + y, DIAL[2] - 0.04), color=CHAR)
signal.ring("requisition_tag", DIAL_R - 0.02, DIAL_R + 0.07, 0.09, segs=12, loc=g(*DIAL),
            rot=(math.pi / 2, 0, 0), color=BRASS)
gbox(body, "fleet_paint", (0.5, 0.03, 0.08), loc=g(0, 1.62, -0.49), color=CHAR)
for i in range(2):
    gbox(body, "fleet_paint", (0.04, 0.42, 0.14), loc=g(0.66, 2.1 + i * 0.05, -0.1 + i * 0.2),
             color=BONE)
gbox(body, "fleet_paint", (0.06, 0.32, 0.62), loc=g(0.63, 1.95, 0.0), color=CHAR)
body.beam("fleet_paint", G(-0.28, 1.76, -0.5), G(0.28, 1.76, -0.5), 0.1, 0.12, color=CHAR)
for sx in (-1, 1):
    body.beam("fleet_paint", G(sx * 0.26, 1.78, -0.5), G(sx * 0.42, 1.6, -0.5), 0.08, 0.1, color=CHAR)

body.uv("fleet_paint", 0.7, u=8, v=5, loc=g(0, 3.05, 0), scale=(1.0, 0.88, 0.62), color=HAT)
body.cyl("fleet_paint", 0.92, 0.92, 0.06, segs=12, loc=g(0, 3.08, -0.06), color=HAT)
body.beam("fleet_paint", G(0, 3.44, -0.4), G(0, 3.44, 0.4), 0.14, 0.1, color=common.mix(HAT, "bone", 0.3))

MAST_BASE = Vector((0.0, 1.2, 0.72))
MAST_TOP = Vector((0.0, 4.45, 0.72))
body.rod("fleet_paint", G(*MAST_BASE), G(*MAST_TOP), 0.11, segs=6, color=CHAR)
for sx in (-1, 1):
    body.rod("fleet_paint", G(sx * 0.95, 1.2, 0.95), G(0, 2.6, 0.72), 0.05, segs=4, color=CHAR)
body.rod("fleet_paint", G(0.17, 1.2, 0.78), G(0.17, 4.2, 0.78), 0.045, segs=4, color=OXIDE)
gbox(body, "fleet_paint", (0.5, 0.12, 0.4), loc=g(0, 4.4, 0.72), color=CHAR)
signal.cyl("requisition_tag", 0.14, 0.14, 0.24, segs=8, loc=g(0.17, 4.12, 0.78), color=BRASS)

HORN_PROFILE = [(0.0, 1.0), (0.66, 1.4), (0.84, 2.2), (0.95, 3.6), (1.0, 4.4)]


def horn(throat, direction, length, r, segs=8):
    """A lofted steam-horn bell: a narrow pipe that flares hard in its last fifth. The bell
    is open; a charcoal cone set inside it reads as the throat from the front."""
    a = Vector(throat)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 1, 0))).normalized()
    up = side.cross(d).normalized()
    rings = []
    for t, k in HORN_PROFILE:
        c = a + d * (length * t)
        rings.append([signal.bm.verts.new(g(*(c + (side * math.cos(i * math.tau / segs) +
                                                     up * math.sin(i * math.tau / segs)) * r * k)))
                      for i in range(segs)])
    faces = [signal.bm.faces.new(list(reversed(rings[0])))]
    for lo, hi in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            faces.append(signal.bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
    signal.paint(faces, "requisition_tag", BRASS)
    mouth = a + d * length
    body.rod("fleet_paint", G(*(mouth - d * (length * 0.2))), G(*(mouth - d * 0.03)), r * 1.2, segs=6,
             r2=r * 4.0, color=CHAR)
    return mouth, d


HORNS = [horn((-0.1, 4.5, 0.62), (-0.32, 0.84, -0.44), 1.3, 0.11),
         horn((0.14, 4.5, 0.62), (0.5, 0.8, -0.2), 0.95, 0.075)]

TETHERS = []
for name, sx, sz in (("a", -1, -1), ("b", 1, -1), ("c", 1, 1), ("d", -1, 1)):
    c = Vector((sx * 0.94, 1.38, sz * 0.94))
    body.cyl("fleet_paint", 0.2, 0.2, 0.22, segs=6, loc=g(*c), rot=(0, math.pi / 2, 0), color=CHAR)
    signal.cyl("requisition_tag", 0.13, 0.13, 0.26, segs=6, loc=g(*c), rot=(0, math.pi / 2, 0), color=BRASS)
    TETHERS.append((name, c + Vector((0, 0.2, 0))))

bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
bmesh.ops.recalc_face_normals(signal.bm, faces=signal.bm.faces[:])
body_obj = body.to_object(parent=root)
signal_obj = signal.to_object(parent=root)

hand = Part("ForemanHand")
hand.beam("fleet_paint", G(0, -0.06, 0), G(0, 0.34, 0), 0.06, 0.04, color=CHAR)
hand.cyl("fleet_paint", 0.06, 0.06, 0.05, segs=6, rot=(math.pi / 2, 0, 0), color=CHAR)
bmesh.ops.translate(hand.bm, vec=Vector(g(*DIAL)) + Vector(g(0, 0, -0.06)), verts=hand.bm.verts)
hand_obj = hand.to_object(origin=g(DIAL[0], DIAL[1], DIAL[2] - 0.06), parent=root)

big_mouth, big_dir = HORNS[0]
horn_socket = common.empty("HornMouth", G(*big_mouth), parent=root)
horn_socket.rotation_euler = (Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))) @
                              Vector((0, 0, -1)).rotation_difference(big_dir).to_matrix() @
                              Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))).to_euler()
common.empty("ClockFace", G(DIAL[0], DIAL[1], DIAL[2] - 0.08), parent=root)
common.empty("SteamValve", G(0.17, 4.26, 0.78), parent=root)
for name, at in TETHERS:
    common.empty("tether_" + name, G(*at), parent=root)

bpy.context.view_layer.update()
objs = (body_obj, signal_obj, hand_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
cart = [o.matrix_world @ v.co for o in (body_obj,) for v in o.data.vertices if (o.matrix_world @ v.co).z < 3.6]
half_x = max(abs(p.x) for p in cart)
half_z = max(abs(p.y) for p in cart)
low = min(p.z for p in points)
high = max(p.z for p in points)
tris = common.tri_total(root)
print("FOREMAN cart half %.3f x %.3f floor %.3f top %.3f tris %d" % (half_x, half_z, low, high, tris))
assert half_x <= HALF + 1e-4 and half_z <= HALF + 1e-4
assert low >= FLOOR - 1e-4 and high <= TOP + 1e-4
assert tris <= 8700

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_foreman.glb")
import kill_first_motion
import kill_first_rig
rig = kill_first_motion.foreman(root, body_obj, signal_obj, hand_obj)
stats = rig.export(path, draws=3)
print(f"FOREMAN EXPORTED: {stats['verts']} V / {stats['tris']} T / {stats['draws']} D, "
      f"{stats['joints']} joints, clips {stats['clips']}")
if kill_first_rig.sheet_dir():
    kill_first_rig.contact_sheet("foreman", rig, FLOOR, kill_first_rig.sheet_dir(), focus=(0, 0, 1.9),
                                 scale=9.5, shots=kill_first_motion.FOREMAN_SHOTS, lit_clips=("tell",))

if opts["render"]:
    import kill_first_preview
    kill_first_preview.render("foreman", root, opts["render"], FLOOR, focus=(0, 0, 1.75), scale=9.0,
                              ball_x=-3.6, game_target=(0, 0, 1.0))
