# C17 Deflector: a Fleet animal crew standing behind one broad concave dish, braced toward the
# ball. The dish is the tool and the biggest shape: a 3.9 m plate whose rim (outer radius 1.95 m,
# the base torus's) is a raised worn-bone bead (WORN, a charcoal-bone mix that renders grey-slate
# against the oxide plates, lower contrast than the base's brass ring). The read against the neighbours: the Hooker is one slim post with a crossbar
# crown (a T), the Bola thrower a crew under an overhead hoop, the Netcaster a gate of two tall
# masts; the Deflector is one wide round-shouldered plate that fills the frame edge to edge with
# the crew hidden behind it. It replaces the capsule crew, its head, ears and tag, and the base
# disc and torus. The gameplay lane (deflector.gd _commit_lane) is untouched; this only dresses.
#
# Blender +Z is up and -Y is forward (the exporter turns -Y into Godot +Z), so the dish face looks
# down -Y, the local +Z the enemy turns toward the ball (counter.gd _facing). Origin is the
# deflector's collider centre, ground at z = -1.1. The dish centre stays where the base put it
# (Godot y 0.2, z 1.4 -> Blender z 0.2, y -1.4). Below the crew's feet the dish would sink into
# the floor, so its lower half is squashed to 0.64 of the upper (bottom at z = -1.05): a flat-footed
# shield rather than a buried circle.
#
# Two meshes, three surfaces (three colour-pass draws), no alpha:
#   DeflectorBody   fleet_paint (crew barrel, chest and head; flashes with the enemy) and paint
#                   (vertex colour: pack, one brass tag).
#   DishWall        paint (dish, rim, frame and grips); origin at the face centre for e10_dish_wall.
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_deflector.py -- [--out file.glb]

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
root = common.empty("Deflector")

GROUND = -1.1
CEN_Z = 0.2  # Godot y 0.2
CEN_Y = -1.30  # Godot z 1.30: the face centre, recessed
RIM_Y = -1.65  # Godot z 1.65: the face at the rim
RIM_OUT = 1.95  # the base torus's outer radius
RIM_TUBE = 0.09
SECTORS = 16
RINGS = (0.45, 0.95, 1.40, 1.86)  # four rings
SKIN = 0.14  # dish thickness toward the crew (+Y)
DOWN = 0.64  # the lower half's squash, so the foot clears the floor
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.55)
PLATE = common.mix("oxide", "charcoal", 0.18)
PLATE_HI = common.mix("oxide", "bone", 0.10)
IRON = common.mix("charcoal", "oxide", 0.28)
BRASS = "brass"
HALF_PI = math.pi / 2


def shade(c):
    c = common.srgb(c) if isinstance(c, str) else c
    ch = common.srgb("charcoal")
    return tuple(c[i] + (ch[i] - c[i]) * 0.12 for i in range(3))


def dish_xz(r, a):
    s = math.sin(a)
    return r * math.cos(a), CEN_Z + r * s * (DOWN if s < 0 else 1.0)


def face_y(r):
    return CEN_Y + (RIM_Y - CEN_Y) * (r / RIM_OUT) ** 2


b = Part("DeflectorBody")
bm = b.bm

# --- The crew, behind the dish ---------------------------------------------------------
b.cyl("fleet_paint", 0.62, 0.72, 1.05, segs=10, loc=(0, 0, -0.575))
b.cyl("fleet_paint", 0.72, 0.58, 0.90, segs=10, loc=(0, 0, 0.42))
crew.jet_deflector_head(b, (0, -0.05, 1.12), 0.34)
b.cyl("paint", 0.73, 0.73, 0.10, segs=10, loc=(0, 0, -0.05), color=CHAR)  # strap
b.box("paint", (0.56, 0.22, 0.56), loc=(0, 0.72, 0.30), color=CHAR)  # pack on the back
b.box("paint", (0.28, 0.05, 0.18), loc=(0, 0.855, 0.30), color=BRASS)  # the one brass tag

# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED.
crew.cast_number(b, "paint", "09", (0.613, -0.199, 0.35), (0.951, -0.309, 0), 0.2)
crew.hired(b, "paint", (-0.613, -0.199, 0.35), (-0.951, -0.309, 0), 0.1)
body = b.to_object(parent=root)
b = Part("DishWall")
b.subsurf = 0
bm = b.bm

# --- The dish: two skins over 16 sectors and four rings --------------------------------
step = 2 * math.pi / SECTORS
centre_f = bm.verts.new(Vector((0.0, CEN_Y, CEN_Z)))
centre_b = bm.verts.new(Vector((0.0, CEN_Y + SKIN, CEN_Z)))
front = [[bm.verts.new(Vector((dish_xz(r, k * step)[0], face_y(r), dish_xz(r, k * step)[1]))) for k in range(SECTORS)] for r in RINGS]
back = [[bm.verts.new(Vector((dish_xz(r, k * step)[0], face_y(r) + SKIN, dish_xz(r, k * step)[1]))) for k in range(SECTORS)] for r in RINGS]
BAND = [CHAR, PLATE, "oxide", PLATE_HI]  # centre recess, then the plate bands out to the rim
for k in range(SECTORS):
    n = (k + 1) % SECTORS
    b.paint([bm.faces.new((centre_f, front[0][n], front[0][k]))], "paint", BAND[0])
    b.paint([bm.faces.new((centre_b, back[0][k], back[0][n]))], "paint", CHAR)
    for j in range(len(RINGS) - 1):
        # Alternate the plate shade by sector so the bands read as welded panels, not a wash.
        col = BAND[j + 1] if (k + j) % 2 == 0 else shade(BAND[j + 1])
        b.paint([bm.faces.new((front[j][k], front[j][n], front[j + 1][n], front[j + 1][k]))], "paint", col)
        b.paint([bm.faces.new((back[j][n], back[j][k], back[j + 1][k], back[j + 1][n]))], "paint", CHAR)
    # The lip between the two skins at the last ring.
    b.paint([bm.faces.new((front[-1][k], front[-1][n], back[-1][n], back[-1][k]))], "paint", CHAR)

# --- The rebound rim: a hexagonal bead swept around the edge -----------------------------
SECT = 6
rim_rows = []
for k in range(SECTORS):
    a = k * step
    px, pz = dish_xz(RIM_OUT - RIM_TUBE, a)
    u = Vector((px, 0.0, pz - CEN_Z))
    u.normalize()
    cy = (RIM_Y + SKIN * 0.4)
    row = []
    for i in range(SECT):
        t = 2 * math.pi * i / SECT
        row.append(bm.verts.new(Vector((px, cy, pz)) + u * (RIM_TUBE * math.cos(t)) + Vector((0, RIM_TUBE * 1.15 * math.sin(t), 0))))
    rim_rows.append(row)
for k in range(SECTORS):
    n = (k + 1) % SECTORS
    for i in range(SECT):
        j = (i + 1) % SECT
        b.paint([bm.faces.new((rim_rows[k][i], rim_rows[n][i], rim_rows[n][j], rim_rows[k][j]))], "paint", WORN)

# --- The back frame: boss, cross ribs and the grip the crew braces on -------------------
by = CEN_Y + SKIN
b.cyl("paint", 0.30, 0.26, 0.26, segs=8, loc=(0, by + 0.13, CEN_Z), rot=(HALF_PI, 0, 0), color=CHAR)
b.box("paint", (0.16, 0.10, 1.9), loc=(0, by + 0.05, CEN_Z + 0.05), color=IRON)  # vertical rib
b.box("paint", (2.5, 0.10, 0.16), loc=(0, by + 0.05, CEN_Z), color=IRON)  # cross rib
for s in (-1, 1):
    b.rod("paint", (s * 0.5, -0.30, 0.55), (s * 0.24, by + 0.18, CEN_Z + 0.05), 0.09, segs=6, color=IRON)  # arms
    b.rod("paint", (s * 0.24, by + 0.18, CEN_Z + 0.05), (s * 0.24, by + 0.30, CEN_Z + 0.05), 0.11, segs=6, color=CHAR)  # grips
# The dish skins, lip and rim bead are wound by hand; make every closed shell face outward.
import bmesh
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
wall = b.to_object(origin=(0, CEN_Y, CEN_Z), parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
points = [obj.matrix_world @ v.co for obj in (body, wall) for v in obj.data.vertices]
xs = [v.x for v in points]
ys = [v.y for v in points]
zs = [v.z for v in points]
surfaces = len(body.data.materials) + len(wall.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3))
if tris > 3200 or surfaces > 3 or max(abs(x) for x in xs) > 2.0 or min(ys) < -1.75 or max(ys) > 0.9 \
        or min(zs) < GROUND - 0.001 or max(zs) > 2.3:
    raise SystemExit("C17 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_deflector.glb"))
