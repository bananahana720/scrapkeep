"""Splitter: a kill-first crawler, three welded wedge pods round one fuse lamp.

ENEMY-PRIORITY.md 4a: crawler chassis, ground move; the threat feature is the three
sub-hulls with glowing seams, so the split is promised before it happens. Rammed at
ground level the seams flare and it pops into three enemy_splitter_piece.glb chasers;
a smash from above or a long shot kills it clean.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). It leads along Godot -Z like the chaser.
Origin at the ball's centre. Suggested collider: capsule radius 1.3, half height 1.35, so its floor
is the feet at Y = -1.35. The shell is within 1.25 above the waist (tested); the waist strap
stands just proud of it, legs and snouts splay to 1.65 and the lamp tops out at 1.7.
Two meshes, two surfaces, both opaque vertex colour:
  SplitterBody   fleet_paint: pods (oxide), legs, strap, snouts (charcoal), tally stencils.
  SplitterSeams  requisition_tag: three seam strips, the junction caps, three eyes and the
                 fuse lamp. Brass at rest; the runtime lights it and flares it white for the
                 0.4 s split tell. No glow is baked into the file.
Sockets (empties, no draws): FuseLamp, pod_a/b/c (each piece's spawn point, facing out),
snout_a/b/c. Procedural bmesh in this repository; no external meshes or textures.
Rig and clips (crawl, tell, break_split, break_clean): kill_first_motion.splitter.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir] [--sheet dir]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import common
import polish
from common import Part
import splitter_pod
from splitter_pod import g

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Splitter")

R = 1.1
FLOOR = -1.35
BRASS = "brass"
AZ = [0.0, math.tau / 3, -math.tau / 3]
NAMES = ["a", "b", "c"]

body = Part("SplitterBody")
glow = Part("SplitterSeams")
glow.bevel = 0
glow.subsurf = 0
snouts = []
for i, az in enumerate(AZ):
    tip, out = splitter_pod.build(body, glow, az, R, tally=i + 1)
    snouts.append((tip, out))

for az in AZ:
    seam_az = az + math.pi / 3
    pts = []
    for lat in (-80, -42, 0, 42, 80):
        rr = R * (0.93 if lat > 40 else 1.0) + 0.02
        c = math.cos(math.radians(lat))
        pts.append(Vector(g(c * math.sin(seam_az) * rr, math.sin(math.radians(lat)) * rr,
                            -c * math.cos(seam_az) * rr)))
    for a, b in zip(pts, pts[1:]):
        glow.beam("requisition_tag", a, b, 0.17, 0.07, color=BRASS)

for y, sign in ((R * 0.93 * 0.99, 1), (-R * 0.99, -1)):
    glow.cyl("requisition_tag", 0.26, 0.2, 0.08, segs=6, loc=g(0, y, 0), color=BRASS)

top = R * 0.93
body.cyl("fleet_paint", 0.11, 0.09, 0.26, segs=6, loc=g(0, top + 0.13, 0), color="charcoal")
body.cyl("fleet_paint", 0.2, 0.2, 0.06, segs=6, loc=g(0, top + 0.27, 0), color="a8aaa3")
glow.uv("requisition_tag", 0.18, u=6, v=4, loc=g(0, top + 0.42, 0), color=BRASS)
for k in range(3):
    a = k * math.tau / 3 + math.pi / 3
    lo = Vector(g(0.19 * math.sin(a), top + 0.29, -0.19 * math.cos(a)))
    hi = Vector(g(0.0, top + 0.62, 0.0))
    body.rod("fleet_paint", lo, hi, 0.025, segs=4, color="charcoal")
body.cyl("fleet_paint", 0.06, 0.03, 0.06, segs=6, loc=g(0, top + 0.63, 0), color="charcoal")

bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
bmesh.ops.recalc_face_normals(glow.bm, faces=glow.bm.faces[:])
body_obj = body.to_object(parent=root)
glow_obj = glow.to_object(parent=root)

common.empty("FuseLamp", g(0, top + 0.42, 0), parent=root)
for name, az, (tip, out) in zip(NAMES, AZ, snouts):
    centre = Vector(g(out.x * R * 0.42, -0.2, out.z * R * 0.42))
    pod = common.empty("pod_" + name, centre, parent=root)
    pod.rotation_euler = (0, 0, -az)
    common.empty("snout_" + name, Vector(g(*tip)), parent=root)

bpy.context.view_layer.update()
points = [o.matrix_world @ v.co for o in (body_obj, glow_obj) for v in o.data.vertices]
radius = max(math.hypot(p.x, p.y) for p in points)
low = min(p.z for p in points)
high = max(p.z for p in points)
print("SPLITTER radius %.3f floor %.3f top %.3f tris %d" % (radius, low, high, common.tri_total(root)))
assert radius <= 1.6 and low >= FLOOR - 1e-4 and high <= 1.7
assert common.tri_total(root) <= 8000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_splitter.glb")
import kill_first_motion
import kill_first_rig
rig = kill_first_motion.splitter(root, body_obj, glow_obj, R, FLOOR, AZ, NAMES)
stats = rig.export(path, draws=2)
print(f"SPLITTER EXPORTED: {stats['verts']} V / {stats['tris']} T / {stats['draws']} D, "
      f"{stats['joints']} joints, clips {stats['clips']}")
if kill_first_rig.sheet_dir():
    kill_first_rig.contact_sheet("splitter", rig, FLOOR, kill_first_rig.sheet_dir(), focus=(0, 0, 0.1), scale=4.6, shots=kill_first_motion.SPLITTER_SHOTS, lit_clips=("tell", "break_split"))

if opts["render"]:
    import kill_first_preview
    kill_first_preview.render("splitter", root, opts["render"], FLOOR, focus=(0, 0, 0.1))
