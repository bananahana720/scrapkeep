# C11 Lobber: a Fleet mortar cart. A tall wheeled tower carries the whole read overhead: a
# loading bulb cradled on the platform, a stout mortar tube rising out of it and leaning
# toward the cart's front. It replaces the box, sphere, cylinder and waist band that
# lobber.gd dressed it with. Blender +Z is up and -Y is the cart's front (the exporter turns
# -Y into Godot +Z, the side the mortar leans to, as the base tube did).
# Origin is the enemy origin: the cart sits in the 2.4 x 4 x 2.4 m collider box (wheels on
# z = -2, platform at |xy| <= 1.2), the bulb centre is at z 2.6 (radius 0.9, the base
# muzzle sphere) and the tube is the base 2.6 m barrel tilted 0.35 rad (centre z 3.6).
# Three meshes, five surfaces, no alpha: LobberBody and LobberBarrel (fleet_paint, rubber) and LobberBulb (one
# surface, the runtime muzzle material, so charge scales and lights it as before).
# Slots: fleet_paint (flashes with the enemy), rubber (charcoal wheels, cradle, tube),
# requisition_tag (the bulb; lit hazard at runtime).
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_lobber.py -- [--out file.glb]

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
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
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


# Chassis: a low wide deck between the wheels, then the tower tapering up to the platform.
hull(p, "fleet_paint", frustum(-1.30, -0.62, 0.98, 0.98, 1.10, 1.10))
hull(p, "fleet_paint", frustum(-0.62, 1.15, 0.86, 0.60, 0.86, 0.60))
# Platform: a broad deck at the top of the box, then a raised lip around the cradle.
hull(p, "fleet_paint", frustum(1.15, 1.42, 1.20, 1.20, 1.20, 1.20))
hull(p, "fleet_paint", frustum(1.42, 1.58, 0.95, 0.80, 0.95, 0.80))
# Front loading hatch and a rear ammunition locker, proud of the tower faces.
p.box("fleet_paint", (0.70, 0.10, 0.75), loc=(0.0, -0.78, 0.15))
p.box("rubber", (0.52, 0.06, 0.55), loc=(0.0, -0.85, 0.15))
p.box("fleet_paint", (0.95, 0.30, 0.90), loc=(0.0, 0.85, 0.10))
# Welded patch plates on the flanks, one big and one tilted.
p.box("fleet_paint", (0.06, 0.62, 0.70), loc=(0.80, 0.05, -0.20))
p.box("fleet_paint", (0.06, 0.45, 0.50), loc=(-0.70, -0.20, 0.55), rot=(0.0, 0.0, 0.0))
# Weld straps round the tower and the deck.
p.box("rubber", (1.80, 1.80, 0.13), loc=(0.0, 0.0, -0.10))
p.box("rubber", (2.05, 2.05, 0.12), loc=(0.0, 0.0, -0.98))
p.box("rubber", (1.40, 1.40, 0.11), loc=(0.0, 0.0, 0.72))

# Wheels: four charcoal rollers with axles, bottom on z = -2 (the collider floor).
for sx in (-1, 1):
    for sy in (-1, 1):
        p.cyl("rubber", 0.5, 0.5, 0.28, segs=12, loc=(sx * 1.05, sy * 0.68, -1.5), rot=(0.0, math.pi / 2, 0.0))
        p.cyl("fleet_paint", 0.20, 0.20, 0.06, segs=6, loc=(sx * 1.17, sy * 0.68, -1.5), rot=(0.0, math.pi / 2, 0.0))
    p.rod("rubber", (sx * 1.0, -0.68, -1.5), (sx * 1.0, 0.68, -1.5), 0.10, segs=6)
# Braces from the deck corners up to the platform, so the tower reads as a braced frame.
for sx in (-1, 1):
    for sy in (-1, 1):
        p.rod("rubber", (sx * 0.98, sy * 1.02, -0.85), (sx * 0.98, sy * 0.98, 1.15), 0.075, segs=5)

# Cradle: four claws lifting from the platform to grip the bulb below its equator.
for sx in (-1, 1):
    for sy in (-1, 1):
        n = Vector((sx, sy, 0.0)).normalized()
        grip = Vector((0.0, 0.0, BULB_Z)) + Vector((n.x * 0.83, n.y * 0.83, -0.35))
        p.rod("rubber", (sx * 0.72, sy * 0.72, 1.55), tuple(grip), 0.09, segs=6, r2=0.06)

# Mortar: the base 2.6 m barrel, centre z 3.6, tilted 0.35 rad toward -Y. A breech collar
# where it leaves the bulb, two reinforcing bands and a muzzle ring.
d = Vector((0.0, -math.sin(TILT), math.cos(TILT)))
c = Vector((0.0, 0.0, 3.6))
base, top = c - d * (TUBE_LEN / 2), c + d * (TUBE_LEN / 2)
# WL: the same tube and bands become one hinged part, with its origin at the breech.
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

# Loading bulb: its own mesh, origin at the bulb centre so the runtime charge scale swells it
# in place.
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
