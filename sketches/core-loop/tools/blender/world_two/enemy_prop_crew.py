"""Prop crew: the Dig's shoring crew (WORLD-ROSTERS.md, the Dig roster).

A Fleet miner holds a screw-jack prop under a timber head-tree loaded with rock, sheltering its
pack. Ram the prop and the roof comes down on everything under it (the player too, if on the
floor). Silhouette: a wide, lumpy, top-heavy roof of rock on stilts, the only enemy whose threat
is overhead. The prop is the one steel upright with a hazard band, set at the front where the
crew stands; the two timber legs behind it are plain wood, so the ram target is never in doubt.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). Origin at the roster's standard collider centre
(the crew's), floor Y = -1.1; faces Godot +Z. The canopy spans 5.2 m (X) by 4.0 m (Z), its
underside at Y = 2.2 (3.3 m clear), centred at canopy_centre behind the crew.
Three meshes, three surfaces, opaque vertex colour, no baked glow:
  PropCrewBody  fleet_paint: the crew, its helmet and lamp, the two rear timber legs and their
                sole plates. Flashes with the enemy.
  PropShore     working_tool: the steel screw-jack prop with its hazard band and foot plate.
                Origin at the prop's foot, so knocked out it pivots there (rotate about X).
  PropCanopy    part_state: the timber head-tree, planks, rock load and cargo net. Origin at
                its rear edge on the legs' line, so it can drop flat or tip forward.
Sockets (empties, no draws): prop_hit (the hazard band, the ram target), canopy_centre (the
centre of the area the roof falls on, at floor height), crew_head. Procedural bmesh.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir]
"""
import math
import os
import random
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
import fleet_crew

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.82}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.5, "metal": 0.45}
common.SLOTS["part_state"] = {"vc": True, "rough": 0.9}
root = common.empty("PropCrew")

FLOOR = -1.1
TIMBER = "8c6a46"
TIMBER_DK = "6b4f35"
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
OXIDE = "9b513a"
UNDER = 2.2
CX, CZ = 0.0, -1.3
HALF_X, HALF_Z = 2.6, 2.0
PROP = (0.75, FLOOR, CZ + HALF_Z - 0.35)
LEGS = [(-HALF_X + 0.35, CZ - HALF_Z + 0.35), (HALF_X - 0.35, CZ - HALF_Z + 0.35)]


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


body = Part("PropCrewBody")
for x, z in LEGS:
    body.beam("fleet_paint", G(x, FLOOR + 0.05, z), G(x, UNDER, z), 0.3, 0.3, color=TIMBER)
    body.box("fleet_paint", (0.62, 0.62, 0.1), loc=g(x, FLOOR + 0.05, z), color=CHAR)
body.beam("fleet_paint", G(LEGS[0][0], 1.4, LEGS[0][1]), G(LEGS[1][0], 1.4, LEGS[1][1]), 0.2, 0.2, color=TIMBER_DK)
CREW = Vector((0.0, 0.55, CZ + HALF_Z - 0.1))
with body.region(bevel=0, subsurf=2, detail=1):
    body.cyl("fleet_paint", 0.42, 0.34, 1.2, segs=8, loc=g(CREW.x, FLOOR + 0.62, CREW.z), color=OXIDE)
body.box("fleet_paint", (0.8, 0.5, 0.16), loc=g(CREW.x, FLOOR + 0.95, CREW.z), color="petrol")
body.box("fleet_paint", (0.86, 0.54, 0.08), loc=g(CREW.x, FLOOR + 0.5, CREW.z), color="hazard")
for side in (-1, 1):
    body.box("fleet_paint", (0.26, 0.36, 0.18), loc=g(CREW.x + side * 0.2, FLOOR + 0.09, CREW.z + 0.06), color=CHAR)
fleet_crew.head(body, CREW, r=0.34, facing=(0.0, 1.0), hat="helmet")
with body.region(bevel=0, subsurf=1, detail=1):
    body.rod("fleet_paint", G(CREW.x + 0.38, 0.0, CREW.z), G(PROP[0] - 0.12, 0.55, PROP[2]), 0.08, segs=5,
             color=OXIDE)
    body.rod("fleet_paint", G(CREW.x - 0.38, 0.0, CREW.z), G(CREW.x - 0.62, -0.45, CREW.z + 0.3), 0.08, segs=5,
             color=OXIDE)
with body.region(bevel=0.01):
    body.box("fleet_paint", (0.5, 0.06, 0.6), loc=g(LEGS[0][0] + 0.26, 0.5, LEGS[0][1] + 0.2), color="bone")
    for i in range(3):
        body.box("fleet_paint", (0.05, 0.03, 0.36), loc=g(LEGS[0][0] + 0.14 + i * 0.12, 0.5, LEGS[0][1] + 0.24),
                 color=CHAR)
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
body_obj = body.to_object(parent=root)

shore = Part("PropShore")
px, _, pz = PROP
shore.box("working_tool", (0.56, 0.56, 0.1), loc=g(px, FLOOR + 0.05, pz), color=CHAR)
shore.cyl("working_tool", 0.13, 0.13, 1.6, segs=8, loc=g(px, FLOOR + 0.9, pz), color=STEEL)
shore.cyl("working_tool", 0.1, 0.1, 1.6, segs=8, loc=g(px, FLOOR + 2.5, pz), color=WORN)
shore.cyl("working_tool", 0.2, 0.2, 0.22, segs=8, loc=g(px, FLOOR + 1.75, pz), color=CHAR)
with shore.region(bevel=0.015):
    shore.beam("working_tool", G(px - 0.45, FLOOR + 1.75, pz), G(px + 0.45, FLOOR + 1.75, pz), 0.07, 0.07,
               color=CHAR)
for k in range(2):
    shore.cyl("working_tool", 0.17, 0.17, 0.18, segs=8, loc=g(px, 0.05 + k * 0.36, pz), color="hazard")
shore.box("working_tool", (0.6, 0.6, 0.12), loc=g(px, UNDER - 0.06, pz), color=CHAR)
bmesh.ops.recalc_face_normals(shore.bm, faces=shore.bm.faces[:])
shore_obj = shore.to_object(origin=g(px, FLOOR, pz), parent=root)

canopy = Part("PropCanopy")
for z in (CZ - HALF_Z + 0.35, CZ + HALF_Z - 0.35):
    canopy.beam("part_state", G(-HALF_X, UNDER + 0.15, z), G(HALF_X, UNDER + 0.15, z), 0.32, 0.3, color=TIMBER_DK)
PLANKS = 7
for i in range(PLANKS):
    x = -HALF_X + (i + 0.5) * (2 * HALF_X / PLANKS)
    canopy.box("part_state", (2 * HALF_X / PLANKS - 0.06, 2 * HALF_Z, 0.12), loc=g(x, UNDER + 0.36, CZ),
               color=TIMBER if i % 2 == 0 else TIMBER_DK)
rng = random.Random(7)
ROCKS = [(-1.4, -0.6, 0.8), (0.2, -0.3, 1.0), (1.5, -0.9, 0.75), (-0.6, 0.7, 0.85), (1.0, 0.8, 0.7),
         (-1.9, 1.0, 0.55)]
for rx, rz, s in ROCKS:
    y = UNDER + 0.42 + s * 0.55
    color = rng.choice(["7b6a58", "8f7a62", "6b5c4c"])
    with canopy.region(detail=1):
        canopy.ico("part_state", s, loc=g(rx, y, CZ + rz), scale=(1.15, 1.0, 0.8),
                   rot=(rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 3)), color=color)
with canopy.region(bevel=0.01):
    for x in (-1.6, 0.0, 1.6):
        canopy.beam("part_state", G(x, UNDER + 0.42, CZ - HALF_Z + 0.2), G(x * 0.8, UNDER + 1.55, CZ), 0.06, 0.05,
                    color="brass")
        canopy.beam("part_state", G(x * 0.8, UNDER + 1.55, CZ), G(x, UNDER + 0.42, CZ + HALF_Z - 0.2), 0.06, 0.05,
                    color="brass")
with canopy.region(bevel=0.01):
    for i in range(6):
        x = -HALF_X + (i + 0.5) * (2 * HALF_X / 6)
        canopy.box("part_state", (2 * HALF_X / 6 - 0.04, 0.05, 0.22), loc=g(x, UNDER + 0.15, CZ + HALF_Z - 0.17),
                   color="hazard" if i % 2 == 0 else CHAR)
bmesh.ops.recalc_face_normals(canopy.bm, faces=canopy.bm.faces[:])
canopy_obj = canopy.to_object(origin=g(0, UNDER, CZ - HALF_Z + 0.35), parent=root)

for name, pos in [("prop_hit", (px, 0.23, pz)), ("canopy_centre", (CX, FLOOR, CZ)), ("crew_head", tuple(CREW))]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (body_obj, shore_obj, canopy_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
print("PROP CREW floor %.3f top %.3f tris %d" % (low, high, common.tri_total(root)),
      [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and high <= 4.4
assert common.tri_total(root) <= 6000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_two", "enemy_prop_crew.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3, tris=6000, verts=9000)

if opts["render"]:
    rest_canopy = (canopy_obj.location.copy(), canopy_obj.rotation_euler.copy())

    def collapse():
        shore_obj.rotation_euler.x = math.radians(-70)
        canopy_obj.rotation_euler.x = math.radians(-14)
        canopy_obj.location.z -= 2.2

    def rest():
        shore_obj.rotation_euler.x = 0.0
        canopy_obj.location, canopy_obj.rotation_euler = rest_canopy[0].copy(), rest_canopy[1].copy()

    def pack():
        for x in (-1.3, 1.2):
            world_preview.ball(FLOOR, x, -CZ - 0.2, name="PackStandIn")

    world_preview.render(
        "prop_crew", root, opts["render"], FLOOR, "dig", focus=(0, 0, 1.2), scale=8.5, ball_x=-4.6,
        game_extras=pack, game_target=(0, -CZ * 0.5, 1.0), game_back=15.0, face_yaw=0, game_yaw=-25,
        poses=[("game_collapse", collapse)], rest=rest)
