# C14 Hooker: a Fleet animal crew beside a tall slim anchor post that carries a long forward
# harpoon. It replaces the capsule crew and the post, gun box and hazard cylinder hooker.gd
# dressed it with. The read is deliberately the opposite of the Lobber's (C11): the Lobber is a
# wide braced tower under a fat overhead tube; the Hooker is a slim pole with an anchor crown
# (stock, flukes and shackle ring) and a thin harpoon lying level, pointing at the ball.
# Blender +Z is up and -Y is forward (the exporter turns -Y into Godot +Z, the way the crew
# and lane face). Origin is the hooker's collider centre, ground at z = -1.1 (the 2.2 m
# capsule the collider keeps). The post stands at x = 0.9 as the base post did and its head
# is at z = 3.1, exactly where Hooker.anchor() reads the tether endpoint; no geometry here
# moves that.
#
# Two meshes, three surfaces (three colour-pass draws), no alpha:
#   HookerBody      static: fleet_paint (crew body and head, flashes with the enemy) and
#                   paint (vertex colour: post, spool, anchor crown, cradle, the brass tag).
#   HookerHarpoon   the harpoon on a pivot at the cradle: one paint surface (vertex colour:
#                   charcoal shaft, hazard head). hooker.gd slides it along its own axis in the
#                   existing warn phase; the anchor and tether endpoint do not move.
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_hooker.py -- [--out file.glb]

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Hooker")

GROUND = -1.1
POST_X = 0.9
HEAD_Z = 3.1  # the tether anchor height (POST_HEIGHT - CREW_HALF in hooker.gd)
PIVOT = (POST_X, 0.0, HEAD_Z)  # harpoon cradle: the sliding pose origin
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.18)
IRON = common.mix("charcoal", "oxide", 0.28)
HAZ = "hazard"
BRASS = "brass"
HALF_PI = math.pi / 2

# --- Body: crew, post, spool, anchor crown ------------------------------------------
b = Part("HookerBody")
# Crew: a barrel torso (rust, flashes at runtime), a cast head from its old job (crew.py), its number and HIRED.
b.cyl("fleet_paint", 0.66, 0.80, 1.1, segs=10, loc=(0, 0, -0.55))
b.cyl("fleet_paint", 0.80, 0.70, 1.1, segs=10, loc=(0, 0, 0.55))
crew.bollard_head(b, (0, 0, 1.3), 0.38)
b.cyl("paint", 0.81, 0.81, 0.12, segs=10, loc=(0, 0, 0.1), color=CHAR)  # strap
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.79, 0.3), color=BRASS)  # the one brass tag
# Yoke arm: a level bar tying the crew's back to the post, so the post reads as worn, not planted.
b.box("paint", (0.36, 0.20, 0.20), loc=(0.62, 0.35, 0.9), color=IRON)

# Post: a slim tapering mast, a foot plate with two stays.
b.cyl("paint", 0.19, 0.12, 4.2, segs=8, loc=(POST_X, 0, HEAD_Z - 2.1), color=CHAR)
b.box("paint", (0.95, 0.95, 0.10), loc=(POST_X, 0, GROUND + 0.05), color=WORN)
for sy in (-1, 1):
    b.rod("paint", (POST_X, sy * 0.44, GROUND + 0.1), (POST_X, 0, GROUND + 1.5), 0.05, segs=5, color=IRON)
# Spool: the tether drum, low on the post.
b.cyl("paint", 0.34, 0.34, 0.34, segs=10, loc=(POST_X, 0, 0.45), rot=(HALF_PI, 0, 0), color=WORN)
b.cyl("paint", 0.42, 0.42, 0.06, segs=10, loc=(POST_X, 0.2, 0.45), rot=(HALF_PI, 0, 0), color=IRON)
b.cyl("paint", 0.42, 0.42, 0.06, segs=10, loc=(POST_X, -0.2, 0.45), rot=(HALF_PI, 0, 0), color=IRON)
# Cradle: two rails and a collar holding the harpoon at the post head.
for sx in (-1, 1):
    b.box("paint", (0.06, 1.0, 0.16), loc=(POST_X + sx * 0.14, -0.25, HEAD_Z - 0.16), color=IRON)
b.box("paint", (0.42, 0.28, 0.28), loc=(POST_X, 0.05, HEAD_Z - 0.02), color=WORN)
# Anchor crown: a stock across the top, two curved flukes and a shackle ring.
b.box("paint", (1.30, 0.14, 0.14), loc=(POST_X, 0, HEAD_Z + 0.42), color=CHAR)
for sx in (-1, 1):
    b.rod("paint", (POST_X + sx * 0.02, 0, HEAD_Z + 0.02), (POST_X + sx * 0.60, 0, HEAD_Z + 0.42), 0.075, segs=5, color=CHAR)
    b.rod("paint", (POST_X + sx * 0.60, 0, HEAD_Z + 0.42), (POST_X + sx * 0.66, 0, HEAD_Z + 0.78), 0.075, segs=5,
          color=CHAR, r2=0.02)
b.ring("paint", 0.13, 0.22, 0.10, segs=10, loc=(POST_X, 0, HEAD_Z + 0.62), rot=(HALF_PI, 0, 0), color=IRON)
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED.
crew.cast_number(b, "paint", "12", (0, -0.715, 0.74), (0, -1, 0), 0.26)
crew.hired(b, "paint", (0, 0.745, -0.3), (0, 1, 0), 0.11)
body = b.to_object(parent=root)

# --- Harpoon: long level shaft, hazard barbed head, tail ring ------------------------
pivot = common.empty("HookerHarpoon", PIVOT, root)
h = Part("HookerHarpoonMesh")
h.subsurf = 0
px, py, pz = PIVOT
h.rod("paint", (px, py + 0.55, pz), (px, py - 1.75, pz), 0.075, segs=6, color=CHAR)
h.rod("paint", (px, py - 1.75, pz), (px, py - 2.35, pz), 0.19, segs=6, color=HAZ, r2=0.0)
for roll in (0.0, HALF_PI):
    h.box("paint", (0.42, 0.24, 0.05), loc=(px, py - 1.86, pz), rot=(0, roll, 0), color=HAZ)
h.ring("paint", 0.06, 0.13, 0.08, segs=8, loc=(px, py + 0.6, pz), rot=(HALF_PI, 0, 0), color=IRON)
harpoon = h.to_object(origin=PIVOT, parent=pivot)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
hys = [v.co.y + PIVOT[1] for v in harpoon.data.vertices]
hzs = [v.co.z + PIVOT[2] for v in harpoon.data.vertices]
surfaces = len(body.data.materials) + len(harpoon.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3),
      "HARPOON_Y", round(min(hys), 3), round(max(hys), 3), "HARPOON_Z", round(min(hzs), 3), round(max(hzs), 3))
if tris > 6800 or surfaces > 3 or max(abs(x) for x in xs) > 1.6 or min(ys) < -1.0 or max(ys) > 1.0 \
        or min(zs) < GROUND - 0.001 or max(zs) > 4.0 or min(hys) < -2.5 or max(hys) > 0.8:
    raise SystemExit("C14 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_hooker.glb"))
