"""Splitter piece: one wedge pod running loose as a small chaser.

ENEMY-PRIORITY.md 4a: a ground-level ram pops the Splitter into three of these, 0.6 the
chaser's scale, keeping the chaser's lunge lane. It is the same pod enemy_splitter.py
welds three of (splitter_pod.py), built at 0.68 of its size: a half-dome back, the
snout leading, and both seam walls edged in the lit slot so it reads torn off.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). It leads along Godot -Z like the chaser.
Collider core: radius 0.6, half height 0.9 (0.6 x the chaser's 1.0 / 1.5); floor at
Y = -0.92. The lance overhangs the collider to 0.96 m on purpose, the way a lance leads;
damage comes from the committed lunge lane, not the mesh. The pod's spine is pushed back 0.42 m so its mass sits on the origin.
Two meshes, two surfaces, opaque vertex colour:
  SplitterPieceBody  fleet_paint: shell, legs, strap, snout.
  SplitterPieceGlow  requisition_tag: eye slit and the torn seam edges; lit at runtime.
Sockets: snout (lunge lead). Procedural bmesh in this repository.
Rig and clips (scurry, pop_in): kill_first_motion.piece.
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
root = common.empty("SplitterPiece")

R = 0.75
FLOOR = -1.225 * R
BACK = 0.42

body = Part("SplitterPieceBody")
glow = Part("SplitterPieceGlow")
glow.bevel = 0
glow.subsurf = 0
tip, out = splitter_pod.build(body, glow, 0.0, R, centre=(0.0, 0.0, BACK), back_glow=True)
lance = Vector(g(tip.x, tip.y, tip.z + BACK))
lead = Vector(g(0.0, -0.04, -1.0))
body.rod("fleet_paint", lance - lead * 0.05, lance + lead * 0.18, 0.05, segs=4, color="charcoal")
body.rod("fleet_paint", lance + lead * 0.18, lance + lead * 0.3, 0.05, segs=4, color="bone", r2=0.0)
body.rod("fleet_paint", Vector(g(0, -0.5 * R, BACK + 0.05)), Vector(g(0, FLOOR + 0.06, BACK + 0.28)),
         0.06, segs=4, color="charcoal", r2=0.1)
body.cyl("fleet_paint", 0.07, 0.05, 0.12, segs=5, loc=g(0, R * 0.93 + 0.03, BACK), color="charcoal")
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
bmesh.ops.recalc_face_normals(glow.bm, faces=glow.bm.faces[:])
body_obj = body.to_object(parent=root)
glow_obj = glow.to_object(parent=root)
common.empty("snout", lance + lead * 0.3, parent=root)

bpy.context.view_layer.update()
points = [o.matrix_world @ v.co for o in (body_obj, glow_obj) for v in o.data.vertices]
radius = max(math.hypot(p.x, p.y) for p in points)
low = min(p.z for p in points)
high = max(p.z for p in points)
print("PIECE radius %.3f floor %.3f top %.3f tris %d" % (radius, low, high, common.tri_total(root)))
assert low >= FLOOR - 1e-4 and high <= 0.9 and radius <= 1.0
assert common.tri_total(root) <= 3100

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_splitter_piece.glb")
import kill_first_motion
import kill_first_rig
rig = kill_first_motion.piece(root, body_obj, glow_obj, FLOOR)
stats = rig.export(path, draws=2)
assert stats["verts"] <= 1900 and stats["tris"] <= 3100
print(f"PIECE EXPORTED: {stats['verts']} V / {stats['tris']} T / {stats['draws']} D, "
      f"{stats['joints']} joints, clips {stats['clips']}")
if kill_first_rig.sheet_dir():
    kill_first_rig.contact_sheet("splitter_piece", rig, FLOOR, kill_first_rig.sheet_dir(), focus=(0, 0, -0.1), scale=2.6, shots=kill_first_motion.PIECE_SHOTS)

if opts["render"]:
    import kill_first_preview
    kill_first_preview.render("splitter_piece", root, opts["render"], FLOOR, focus=(0, 0, -0.1), scale=3.6, ball_x=-2.4)
