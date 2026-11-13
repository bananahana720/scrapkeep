# C16 Netcaster: a Fleet animal crew standing in front of a wide gate of two separated masts
# joined by a crossbar. The net itself is not modelled here: netcaster.gd keeps its 2.4 x 1.6 m
# hazard plane (the actual hostile geometry) exactly as it was, and this mesh frames it without
# entering it. The read against the neighbours: the Hooker is one slim post with a crossbar
# crown (a T), the Bola thrower is a crew under an overhead hoop; the Netcaster is two tall
# insulated masts 2.4 m apart with a top crossbar, a ground sill and outward stays, a gate the
# net hangs in. It replaces the capsule crew, its head, ears and tag, and the two cylinder masts.
# Blender +Z is up and -Y is forward (the exporter turns -Y into Godot +Z). Origin is the
# netcaster's collider centre, ground at z = -1.1. The masts stand at x = +-1.2 and Blender
# y = +0.3 (Godot z = -0.3) as the base masts did, and the net plane sits between them
# (Godot y 0.8..2.4). The crew stands in front of the net plane (Godot z +0.35) so nothing
# decorative crosses the window: |x| < 1.1, y 0.8..2.4, z -0.4..-0.2.
#
# One mesh, two surfaces (two colour-pass draws; the runtime net box is the third), no alpha:
#   NetcasterBody   fleet_paint (crew body and head, flashes with the enemy) and paint (vertex
#                   colour: masts, crossbar, sill, stays, insulators, ears, the brass tag).
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_netcaster.py -- [--out file.glb]

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
root = common.empty("Netcaster")

GROUND = -1.1
MAST_X = 1.2
MAST_Y = 0.3  # Godot z -0.3, the plane the net hangs in
MAST_H = 3.6
TOP = GROUND + MAST_H  # 2.5
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.18)
IRON = common.mix("charcoal", "oxide", 0.28)
HAZ = "hazard"
BRASS = "brass"
HALF_PI = math.pi / 2
CREW_Y = -0.35  # Godot z +0.35: in front of the net plane

b = Part("NetcasterBody")
# Crew: a barrel torso (rust, flashes at runtime), a round head, a charcoal snout and ears.
b.cyl("fleet_paint", 0.40, 0.46, 1.0, segs=10, loc=(0, CREW_Y, -0.6))
b.cyl("fleet_paint", 0.46, 0.40, 0.9, segs=10, loc=(0, CREW_Y, 0.35))
crew.screen_head(b, (0, CREW_Y, 1.0), 0.32)
b.cyl("paint", 0.47, 0.47, 0.10, segs=10, loc=(0, CREW_Y, -0.05), color=CHAR)  # strap
b.box("paint", (0.30, 0.05, 0.20), loc=(0, CREW_Y - 0.46, 0.05), color=BRASS)  # the one brass tag
# Cable spool on the crew's back, feeding the masts.
b.cyl("paint", 0.22, 0.22, 0.30, segs=8, loc=(0, CREW_Y + 0.5, 0.1), rot=(0, HALF_PI, 0), color=WORN)

for sx in (-1, 1):
    x = sx * MAST_X
    # Mast: a tall tapering pole, foot plate, outward and fore/aft stays.
    b.cyl("paint", 0.10, 0.07, MAST_H, segs=8, loc=(x, MAST_Y, GROUND + MAST_H / 2), color=CHAR)
    b.box("paint", (0.60, 0.60, 0.10), loc=(x, MAST_Y, GROUND + 0.05), color=WORN)
    b.rod("paint", (x, MAST_Y, GROUND + 1.7), (sx * 1.65, MAST_Y, GROUND + 0.1), 0.045, segs=5, color=IRON)
    for sy in (-1, 1):
        b.rod("paint", (x, MAST_Y, GROUND + 1.5), (x, MAST_Y + sy * 0.55, GROUND + 0.1), 0.04, segs=5, color=IRON)
    # Insulator stack at the head: three discs and a finial spike with a hazard tip.
    for i, r in enumerate((0.22, 0.19, 0.16)):
        b.cyl("paint", r, r, 0.05, segs=10, loc=(x, MAST_Y, TOP + 0.10 + i * 0.12), color=IRON)
    b.rod("paint", (x, MAST_Y, TOP + 0.4), (x, MAST_Y, TOP + 0.55), 0.04, segs=5, color=CHAR, r2=0.015)
    b.uv("paint", 0.07, u=6, v=4, loc=(x, MAST_Y, TOP + 0.58), color=HAZ)
# Crossbar joining the masts across their heads, above the net's top edge (Godot y 2.4).
b.box("paint", (2.64, 0.16, 0.16), loc=(0, MAST_Y, TOP), color=CHAR)
# Ground sill between the mast feet, below the net's bottom edge (Godot y 0.8).
b.box("paint", (2.40, 0.14, 0.10), loc=(0, MAST_Y, GROUND + 0.05), color=WORN)
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED.
crew.cast_number(b, "paint", "19", (0, CREW_Y - 0.43, 0.45), (0, -1, 0), 0.18)
crew.hired(b, "paint", (0, CREW_Y + 0.44, -0.5), (0, 1, 0), 0.08)
body = b.to_object(parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
surfaces = len(body.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3))
if tris > 7600 or surfaces > 2 or max(abs(x) for x in xs) > 1.7 or min(ys) < -0.9 or max(ys) > 0.9 \
        or min(zs) < GROUND - 0.001 or max(zs) > 3.2:
    raise SystemExit("C16 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_netcaster.glb"))
