import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish
from common import Part

common.reset()
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Lobber")
p = Part("LobberBody")
bm = p.bm

HALF = 1.2
Z_BOTTOM, Z_TOP_BODY = -2.0, 5.0
BULB_Z, BULB_R = 2.6, 0.9
TUBE_LEN = 2.6
TILT = 0.35


def hull(part, slot, pts, color=None):
    """Convex hull of points: broad flat planes, few triangles."""
    b = part.bm
    verts = [b.verts.new(v) for v in pts]
    res = bmesh.ops.convex_hull(b, input=verts)
    faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.recalc_face_normals(b, faces=faces)
    return part.paint(faces, slot, color)


def frustum(z0, z1, w0, w1, d0, d1):
    return [(sx * w0, sy * d0, z0) for sx in (-1, 1) for sy in (-1, 1)] + \
           [(sx * w1, sy * d1, z1) for sx in (-1, 1) for sy in (-1, 1)]


hull(p, "fleet_paint", frustum(-1.30, -0.62, 0.98, 0.98, 1.10, 1.10))
hull(p, "fleet_paint", frustum(-0.62, 1.15, 0.86, 0.60, 0.86, 0.60))
hull(p, "fleet_paint", frustum(1.15, 1.42, 1.20, 1.20, 1.20, 1.20))
hull(p, "fleet_paint", frustum(1.42, 1.58, 0.95, 0.80, 0.95, 0.80))
p.box("fleet_paint", (0.70, 0.10, 0.75), loc=(0.0, -0.78, 0.15))
p.box("rubber", (0.52, 0.06, 0.55), loc=(0.0, -0.85, 0.15))
p.box("fleet_paint", (0.95, 0.30, 0.90), loc=(0.0, 0.85, 0.10))
p.box("fleet_paint", (0.06, 0.62, 0.70), loc=(0.80, 0.05, -0.20))
p.box("fleet_paint", (0.06, 0.45, 0.50), loc=(-0.70, -0.20, 0.55), rot=(0.0, 0.0, 0.0))
p.box("rubber", (1.80, 1.80, 0.13), loc=(0.0, 0.0, -0.10))
p.box("rubber", (2.05, 2.05, 0.12), loc=(0.0, 0.0, -0.98))
p.box("rubber", (1.40, 1.40, 0.11), loc=(0.0, 0.0, 0.72))

for sx in (-1, 1):
    for sy in (-1, 1):
        p.cyl("rubber", 0.5, 0.5, 0.28, segs=12, loc=(sx * 1.05, sy * 0.68, -1.5), rot=(0.0, math.pi / 2, 0.0))
        p.cyl("fleet_paint", 0.20, 0.20, 0.06, segs=6, loc=(sx * 1.17, sy * 0.68, -1.5), rot=(0.0, math.pi / 2, 0.0))
    p.rod("rubber", (sx * 1.0, -0.68, -1.5), (sx * 1.0, 0.68, -1.5), 0.10, segs=6)
for sx in (-1, 1):
    for sy in (-1, 1):
        p.rod("rubber", (sx * 0.98, sy * 1.02, -0.85), (sx * 0.98, sy * 0.98, 1.15), 0.075, segs=5)

for sx in (-1, 1):
    for sy in (-1, 1):
        n = Vector((sx, sy, 0.0)).normalized()
        grip = Vector((0.0, 0.0, BULB_Z)) + Vector((n.x * 0.83, n.y * 0.83, -0.35))
        p.rod("rubber", (sx * 0.72, sy * 0.72, 1.55), tuple(grip), 0.09, segs=6, r2=0.06)

d = Vector((0.0, -math.sin(TILT), math.cos(TILT)))
c = Vector((0.0, 0.0, 3.6))
base, top = c - d * (TUBE_LEN / 2), c + d * (TUBE_LEN / 2)
tube = Part("LobberBarrel")
tube.subsurf = 0
tube.rod("rubber", tuple(base), tuple(top), 0.6, segs=12, r2=0.45)


def band(t, r, depth):
    """A ring around the tube t (0 to 1 along its length) with radius r."""
    m, _ = common.aim(base + d * (TUBE_LEN * t - depth / 2), base + d * (TUBE_LEN * t + depth / 2))
    res = bmesh.ops.create_cone(tube.bm, cap_ends=True, cap_tris=False, segments=12, radius1=r, radius2=r,
                                depth=depth, matrix=m)
    return tube.paint(tube._faces(res["verts"]), "fleet_paint")


band(0.18, 0.68, 0.24)
band(0.55, 0.60, 0.16)
band(0.97, 0.53, 0.14)

body = p.to_object(parent=root)
barrel = tube.to_object(origin=tuple(base), parent=root)

b = Part("LobberBulb")
b.subsurf = 0
b.ico("requisition_tag", BULB_R, subdiv=2, loc=(0.0, 0.0, BULB_Z))
bulb = b.to_object(origin=(0.0, 0.0, BULB_Z), parent=root)
bpy.context.view_layer.update()

tri_count = common.tri_total(root)
surfaces = len(body.data.materials) + len(barrel.data.materials) + len(bulb.data.materials)
assembly = [obj.matrix_world @ v.co for obj in (body, barrel) for v in obj.data.vertices]
half_x = max(abs(v.x) for v in assembly)
half_y = max(abs(v.y) for v in assembly)
zmin = min(v.z for v in assembly)
zmax = max(v.z for v in assembly)
bulb_r = max((v.co).length for v in bulb.data.vertices)
print("TRIS", tri_count, "SURFACES", surfaces, "HALF_XY", round(half_x, 4), round(half_y, 4),
      "Z", round(zmin, 4), round(zmax, 4), "BULB_R", round(bulb_r, 4))
if tri_count > 7100 or surfaces > 5 or half_x > HALF + 1e-4 or half_y > HALF + 1e-4 \
        or zmin < Z_BOTTOM - 1e-4 or zmax > Z_TOP_BODY + 1e-4 or bulb_r > BULB_R + 1e-4:
    raise SystemExit("C11 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_lobber.glb"))
