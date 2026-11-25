"""Ballast heavy: the Highdraft's slab crew, a stack of barge ballast on castors (WORLD-ROSTERS.md).

Its health is too much to wear down in a stage; a knock that carries it past an island edge
finishes it (a ring-out). Before it slams it braces: four claw legs drop and bite the deck, an
interruptible cast. Silhouette: three stacked iron ingots, widest at the bottom, on four little
castor wheels, with a tiny crew riding on top under a tall pennant. It reads "very heavy, but on
wheels": the answer (push it off) is in the shape. The plated brute raises a slab overhead; this
one never lifts anything, it plants.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). Origin at the roster's standard collider centre,
floor Y = -1.1; faces Godot +Z. Suggested collider: box 2.7 x 1.7 x 2.1 (X, Y, Z) on its castors.
Two meshes, three surfaces, opaque vertex colour, no baked glow:
  BallastBody    fleet_paint: crew, seat, pennant, paint bands and stencils (flashes with the
                 enemy) and working_tool: the iron ingots, castors and the rear winch drum.
                 (Two surfaces on one mesh.)
  BallastBrakes  working_tool: the four claw legs with their hazard toothed feet. At rest the
                 feet hang BRACE_DROP above the deck; the brace cast moves this object straight
                 down by BRACE_DROP (0.3 m) so they bite. A ram during the cast knocks it back up.
Sockets (empties, no draws): cable_anchor (the rear winch, where the grown remix plants its
cable), brace_lever (the crew's lever), crew_head, push_face (the front ingot's centre).
Procedural bmesh in this repository; no external meshes or textures.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "..", "world_two"))
import common
import polish
from common import Part
import fleet_crew

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.85}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.55, "metal": 0.5}
root = common.empty("BallastHeavy")

FLOOR = -1.1
BRACE_DROP = 0.3
IRON = "3b4446"
IRON_HI = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
OXIDE = "9b513a"


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


def ingot(part, slot, y0, y1, bottom, top, color, side_color=None):
    """A rectangular frustum: bottom (sx, sz) at y0 narrowing to top (sx, sz) at y1."""
    lo = [part.bm.verts.new(g(sx * bottom[0] / 2, y0, sz * bottom[1] / 2)) for sx, sz in
          ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [part.bm.verts.new(g(sx * top[0] / 2, y1, sz * top[1] / 2)) for sx, sz in
          ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    faces = [part.bm.faces.new(lo), part.bm.faces.new(list(reversed(hi)))]
    part.paint(faces, slot, color)
    for i in range(4):
        j = (i + 1) % 4
        f = part.bm.faces.new((lo[j], lo[i], hi[i], hi[j]))
        part.paint([f], slot, side_color or color)


body = Part("BallastBody")
STACK = [(-0.78, -0.18, (2.7, 2.1), (2.45, 1.9)), (-0.18, 0.32, (2.3, 1.8), (2.1, 1.62)),
         (0.32, 0.72, (1.9, 1.5), (1.66, 1.3))]
for (y0, y1, bottom, top) in STACK:
    ingot(body, "working_tool", y0, y1, bottom, top, IRON, IRON_HI)
    with body.region(bevel=0.01):
        ingot(body, "fleet_paint", y0 - 0.005, y0 + 0.1, (bottom[0] + 0.04, bottom[1] + 0.04),
              (bottom[0] + 0.02, bottom[1] + 0.02), OXIDE)
for k, (y0, y1, bottom, top) in enumerate(STACK):
    zf = (bottom[1] + top[1]) / 4 + 0.03
    ym = (y0 + y1) / 2 + 0.04
    with body.region(bevel=0.01):
        for i in range(k + 1):
            body.box("fleet_paint", (0.1, 0.04, 0.26), loc=g((i - k / 2) * 0.22, ym, zf), color="bone")
for sx in (-1, 1):
    for sz in (-1, 1):
        body.box("fleet_paint", (0.3, 0.3, 0.16), loc=g(sx * 1.24, -0.62, sz * 0.94), color="hazard")
for sx in (-1, 1):
    for sz in (-1, 1):
        x, z = sx * 1.0, sz * 0.72
        body.box("working_tool", (0.2, 0.26, 0.16), loc=g(x, -0.84, z), color=CHAR)
        body.cyl("working_tool", 0.21, 0.21, 0.14, segs=8, loc=g(x, FLOOR + 0.21, z), rot=(0, math.pi / 2, 0),
                 color=WORN)
WINCH = Vector((0.0, 0.05, -1.0))
body.cyl("working_tool", 0.24, 0.24, 0.9, segs=8, loc=g(*WINCH), rot=(0, math.pi / 2, 0), color=CHAR)
body.cyl("working_tool", 0.26, 0.26, 0.5, segs=8, loc=g(*WINCH), rot=(0, math.pi / 2, 0), color="brass")
SEAT = Vector((0.0, 0.72, -0.15))
body.box("fleet_paint", (0.62, 0.5, 0.12), loc=g(SEAT.x, SEAT.y + 0.2, SEAT.z), color=CHAR)
body.cyl("fleet_paint", 0.08, 0.08, 0.2, segs=6, loc=g(SEAT.x, SEAT.y + 0.1, SEAT.z), color=CHAR)
CREW = Vector((0.0, 1.62, -0.12))
with body.region(bevel=0, subsurf=2, detail=1):
    body.cyl("fleet_paint", 0.3, 0.26, 0.62, segs=8, loc=g(CREW.x, SEAT.y + 0.55, CREW.z), color=OXIDE)
body.box("fleet_paint", (0.52, 0.36, 0.12), loc=g(CREW.x, SEAT.y + 0.68, CREW.z), color="petrol")
fleet_crew.head(body, CREW, r=0.27, facing=(0.0, 1.0), hat="goggles")
LEVER = Vector((0.42, 1.3, 0.3))
with body.region(bevel=0.01):
    body.rod("fleet_paint", G(0.3, 0.74, 0.2), G(*LEVER), 0.035, segs=5, color=CHAR)
body.ico("fleet_paint", 0.08, loc=g(*LEVER), color="hazard")
with body.region(bevel=0, subsurf=1, detail=1):
    body.rod("fleet_paint", G(CREW.x + 0.26, CREW.y - 0.42, CREW.z + 0.08),
             G(LEVER.x - 0.04, LEVER.y, LEVER.z - 0.04), 0.06, segs=5, color=OXIDE)
    body.rod("fleet_paint", G(CREW.x - 0.26, CREW.y - 0.42, CREW.z + 0.08), G(-0.42, 1.05, 0.25), 0.06, segs=5,
             color=OXIDE)
POLE = (-0.62, 0.72, -0.5)
with body.region(bevel=0.01):
    body.rod("fleet_paint", G(*POLE), G(POLE[0], 3.1, POLE[2]), 0.04, segs=5, color=CHAR)
with body.region(bevel=0, subsurf=0):
    for k, (y, color) in enumerate(((2.95, OXIDE), (2.72, "bone"))):
        tip = 1.05 - 0.2 * k
        body.prism("fleet_paint", [(0.0, 0.11), (tip, 0.02), (tip - 0.18, -0.07), (0.0, -0.11)], 0.03,
                   matrix=common.mtx(g(POLE[0] + 0.03, y, POLE[2]), (math.pi / 2, 0, 0)), color=color)
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
body_obj = body.to_object(parent=root)

brakes = Part("BallastBrakes")
FOOT_Y = FLOOR + BRACE_DROP
for sx in (-1, 1):
    for sz in (-1, 1):
        x, z = sx * 1.38, sz * 1.06
        brakes.box("working_tool", (0.26, 0.26, 0.5), loc=g(sx * 1.3, -0.45, sz * 0.98), color=IRON_HI)
        brakes.rod("working_tool", G(sx * 1.32, -0.5, sz * 1.0), G(x, FOOT_Y + 0.12, z), 0.08, segs=6, color=WORN)
        brakes.box("working_tool", (0.46, 0.46, 0.1), loc=g(x, FOOT_Y + 0.09, z), color="hazard")
        with brakes.region(bevel=0, detail=1):
            for t in range(3):
                brakes.cyl("working_tool", 0.07, 0.0, 0.14, segs=4, loc=g(x + (t - 1) * 0.14 * sx, FOOT_Y - 0.0, z),
                           rot=(math.pi, 0, 0), color=CHAR)
bmesh.ops.recalc_face_normals(brakes.bm, faces=brakes.bm.faces[:])
brakes_obj = brakes.to_object(origin=g(0, FOOT_Y, 0), parent=root)

for name, pos in [("cable_anchor", tuple(WINCH)), ("brace_lever", tuple(LEVER)), ("crew_head", tuple(CREW)),
                  ("push_face", (0, -0.45, 1.05))]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (body_obj, brakes_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
brake_low = min((brakes_obj.matrix_world @ v.co).z for v in brakes_obj.data.vertices)
print("BALLAST floor %.3f top %.3f brake feet %.3f tris %d" % (low, high, brake_low, common.tri_total(root)),
      [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and abs(brake_low - (FLOOR + BRACE_DROP - 0.07)) < 0.08 and high <= 3.2
assert common.tri_total(root) <= 6000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_ballast_heavy.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3, tris=6000, verts=9000)

if opts["render"]:
    rest_z = brakes_obj.location.z

    def brace():
        brakes_obj.location.z = rest_z - BRACE_DROP

    def rest():
        brakes_obj.location.z = rest_z

    world_preview.render(
        "ballast_heavy", root, opts["render"], FLOOR, "highdraft", focus=(0, 0, 0.7), scale=7.0, ball_x=-3.6,
        game_target=(0, 0, 0.4), face_yaw=0, game_yaw=-30, poses=[("game_brace", brace)], rest=rest)
