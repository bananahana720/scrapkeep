# C10 Chaser: a Fleet hunter cast as a forward wedge on braced haunches, replacing the
# capsule, torus visor and box fin that chaser.gd dressed it with. Blender +Z is up and
# +Y is forward (the exporter turns +Y into Godot -Z, so the wedge leads along -Z).
# The whole asset sits inside the 2 x 3 m core the collider gives it: |xy| <= 1 m from the
# origin, |z| <= 1.5 m. One mesh, three surfaces (three colour-pass draws), no alpha.
# Slots: fleet_paint (welded oxide plate, flashes with the enemy), rubber (charcoal
# haunches, fin, welds), requisition_tag (the single brass visor slit, lit at runtime).
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_chaser.py -- [--out file.glb]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part

common.reset()
root = common.empty("Chaser")
p = Part("ChaserBody")
bm = p.bm

R_MAX, Z_MAX = 1.0, 1.5


def hull(slot, pts, color=None):
    """Convex hull of points: broad flat planes, few triangles."""
    verts = [bm.verts.new(v) for v in pts]
    res = bmesh.ops.convex_hull(bm, input=verts)
    faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return p.paint(faces, slot, color)


# Main hull: tall rear hump, shoulders widest at mid, front face dropping to a low nose.
hull("fleet_paint", [
    (-0.55, -0.55, -1.05), (0.55, -0.55, -1.05), (-0.62, -0.60, 1.25), (0.62, -0.60, 1.25),
    (-0.84, 0.05, -1.25), (0.84, 0.05, -1.25), (-0.80, 0.08, 1.02), (0.80, 0.08, 1.02),
    (-0.36, 0.30, 0.35), (0.36, 0.30, 0.35), (-0.36, 0.30, -0.10), (0.36, 0.30, -0.10),
])
# Plough wedge: a forward blade, low, lifting to a lip; the read at 30 m from any side.
hull("fleet_paint", [
    (-0.74, 0.02, -1.42), (0.74, 0.02, -1.42), (0.0, 0.98, -1.42),
    (-0.62, 0.05, -0.15), (0.62, 0.05, -0.15), (0.0, 0.90, -0.95),
])
# Shoulder shield: a raked plate over the front of the hump so the head reads as one wedge.
hull("fleet_paint", [
    (-0.70, 0.02, 0.15), (0.70, 0.02, 0.15), (-0.62, 0.08, 1.02), (0.62, 0.08, 1.02),
    (0.0, 0.62, 0.20), (0.0, 0.50, 0.62),
])
# Welded patch plates, slightly proud, one bigger and one tilted per flank.
p.box("fleet_paint", (0.06, 0.55, 0.62), loc=(0.86, -0.05, 0.55), rot=(0.0, 0.0, 0.0))
p.box("fleet_paint", (0.06, 0.42, 0.50), loc=(-0.86, -0.18, -0.35), rot=(0.0, 0.0, 0.0))
p.box("fleet_paint", (0.5, 0.10, 0.40), loc=(0.0, -0.66, 0.30), rot=(0.0, 0.0, 0.0))
# Visor: the one brass tag, a slit under the shoulder shield, lit at runtime.
p.box("requisition_tag", (0.78, 0.09, 0.15), loc=(0.0, 0.11, 0.42))
# Weld seams: charcoal straps round the hump and across the wedge.
p.box("rubber", (1.72, 0.07, 0.10), loc=(0.0, -0.05, -0.80))
p.box("rubber", (1.30, 0.07, 0.10), loc=(0.0, -0.58, 0.85))
p.box("rubber", (1.10, 0.07, 0.09), loc=(0.0, 0.10, -1.13))
# Dorsal fin: a raked blade off the hump, charcoal, leaning back.
p.prism("rubber", [(-0.15, 0.95), (-0.62, 0.92), (-0.72, 1.48), (-0.40, 1.48)], 0.16,
        matrix=Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
# Braced haunches: two rear struts planted behind, each on a flat foot, so the stance
# already reads braced before the wind-up leans onto it.
for s in (-1, 1):
    p.rod("rubber", (s * 0.52, -0.20, 0.10), (s * 0.48, -0.58, -1.40), 0.13, segs=6)
    p.box("rubber", (0.28, 0.32, 0.10), loc=(s * 0.48, -0.60, -1.45))
    p.rod("rubber", (s * 0.80, 0.02, -1.20), (s * 0.66, 0.50, -1.40), 0.09, segs=5)

body = p.to_object(parent=root)
bpy.context.view_layer.update()

tri_count = common.tri_total(root)
radius = max(math.hypot(v.co.x, v.co.y) for v in body.data.vertices)
zmax = max(abs(v.co.z) for v in body.data.vertices)
print("TRIS", tri_count, "RADIUS", round(radius, 4), "ZMAX", round(zmax, 4),
      "SURFACES", len(body.data.materials))
if tri_count > 1200 or radius > R_MAX or zmax > Z_MAX or len(body.data.materials) > 3:
    raise SystemExit("C10 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_chaser.glb"))
