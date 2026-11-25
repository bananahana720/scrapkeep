"""Pit jaw: the Dig's floor trap, the catch trap re-homed (WORLD-ROSTERS.md, the Dig roster).

A sprung pair of toothed jaws lying flush in a hazard-ringed floor plate, with a mole-ish Fleet
crew peeking out of a manhole behind it, hand on the trip lever. A ball rolling over it on the
floor gets snapped; a ball on a bank, a wall or in the air passes over. A slam from above onto the
open jaw (the bone pressure plate in its middle) kills it. Silhouette: the only enemy in the roster
that is a flat ring of teeth on the floor; at game-camera distance it reads as a hole with teeth.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). Origin at the roster's standard collider centre,
so the floor is Y = -1.1 and the plate sits flush on it; the body faces Godot +Z and the crew
hatch is behind it at -Z. The jaws are an oval 2.6 m wide (X) and 4.1 m long (Z) when open.
Each jaw pivots about the Godot X axis through its own origin at the hinge line (Y = -1.04):
  close:   PitJawA rotates -90 degrees about X, PitJawB +90 degrees. They meet upright in the
           Z = 0 plane as a toothed arch about 2.2 m tall round a ball sitting at catch_centre.
  wind-up: the tell is both jaws lifting 12 degrees off the plate (same signs), teeth up.
Three meshes, three surfaces, opaque vertex colour, no baked glow:
  PitJawFrame  fleet_paint: floor plate with its hazard chevron ring, the bone pressure plate,
               two spring drums at the hinge ends, the manhole, its crew and the trip lever.
               Flashes with the enemy.
  PitJawA      working_tool: the +Z jaw, its teeth and the latch tab.
  PitJawB      working_tool: the -Z jaw, its teeth and the latch tab.
Sockets (empties, no draws): press_plate (the slam spot), catch_centre (the held ball's centre),
crew_head, trip_lever. Procedural bmesh in this repository; no external meshes or textures.
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
sys.path.insert(0, HERE)
import common
import polish
from common import Part

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.82}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.45, "metal": 0.55}
root = common.empty("PitJaw")

FLOOR = -1.1
HINGE_Y = FLOOR + 0.06
AX, AZ = 1.3, 2.05
BAND = 0.16
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
OXIDE = "9b513a"
SEGS = 12
TEETH = 7
LIFT = math.radians(12)


def g(x, y, z):
    return (x, -z, y)


def oval(a, sx=AX, sz=AZ):
    return math.cos(a) * sx, math.sin(a) * sz


frame = Part("PitJawFrame")
with frame.region(bevel=0, subsurf=0):
    RING = 24
    inner, outer = [], []
    for k in range(RING):
        a = math.tau * k / RING
        ix, iz = oval(a, AX + 0.03, AZ + 0.03)
        ox, oz = oval(a, AX + 0.42, AZ + 0.42)
        inner.append((frame.bm.verts.new(g(ix, FLOOR, iz)), frame.bm.verts.new(g(ix, FLOOR + 0.07, iz))))
        outer.append((frame.bm.verts.new(g(ox, FLOOR, oz)), frame.bm.verts.new(g(ox, FLOOR + 0.05, oz))))
    for k in range(RING):
        n = (k + 1) % RING
        color = "hazard" if k % 2 == 0 else CHAR
        top = frame.bm.faces.new((inner[k][1], outer[k][1], outer[n][1], inner[n][1]))
        frame.paint([top], "fleet_paint", color)
        frame.paint([frame.bm.faces.new((outer[k][0], outer[n][0], outer[n][1], outer[k][1]))], "fleet_paint", CHAR)
        frame.paint([frame.bm.faces.new((inner[n][0], inner[k][0], inner[k][1], inner[n][1]))], "fleet_paint", CHAR)
    pit_ring = []
    for k in range(RING):
        x, z = oval(math.tau * k / RING, AX + 0.03, AZ + 0.03)
        pit_ring.append(frame.bm.verts.new(g(x, FLOOR + 0.01, z)))
    frame.paint([frame.bm.faces.new(list(reversed(pit_ring)))], "fleet_paint", "1a1d1c")
with frame.region(bevel=0.012):
    frame.cyl("fleet_paint", 1.0, 1.0, 0.06, segs=8, loc=g(0, FLOOR + 0.04, 0), color=CHAR)
    frame.cyl("fleet_paint", 0.86, 0.86, 0.06, segs=8, loc=g(0, FLOOR + 0.06, 0), color="bone")
    frame.cyl("fleet_paint", 0.3, 0.3, 0.04, segs=8, loc=g(0, FLOOR + 0.09, 0), color="hazard")
for side in (-1, 1):
    x = side * (AX + 0.2)
    with frame.region(subsurf=1, detail=1):
        frame.cyl("fleet_paint", 0.2, 0.2, 0.62, segs=6, loc=g(x, HINGE_Y + 0.15, 0), rot=(0, math.pi / 2, 0),
                  color=STEEL)
        frame.cyl("fleet_paint", 0.24, 0.24, 0.1, segs=6, loc=g(x, HINGE_Y + 0.15, 0), rot=(0, math.pi / 2, 0),
                  color=CHAR)
    frame.box("fleet_paint", (0.5, 0.9, 0.1), loc=g(x, FLOOR + 0.05, 0), color=WORN)

HATCH = (0.0, FLOOR, -(AZ + 0.95))
hx, _, hz = HATCH
frame.cyl("fleet_paint", 0.6, 0.6, 0.16, segs=8, loc=g(hx, FLOOR + 0.08, hz), color=CHAR)
frame.cyl("fleet_paint", 0.46, 0.46, 0.17, segs=8, loc=g(hx, FLOOR + 0.09, hz), color="1a1d1c")
frame.cyl("fleet_paint", 0.55, 0.55, 0.07, segs=8, loc=g(hx, FLOOR + 0.54, hz - 0.66),
          rot=(math.radians(-70), 0, 0), color=OXIDE)
frame.box("fleet_paint", (0.7, 0.12, 0.08), loc=g(hx, FLOOR + 0.57, hz - 0.62), rot=(math.radians(-70), 0, 0),
          color="bone")
CREW = Vector((hx, FLOOR + 0.62, hz + 0.05))
with frame.region(bevel=0, subsurf=2, detail=1):
    frame.cyl("fleet_paint", 0.34, 0.3, 0.42, segs=8, loc=g(CREW.x, FLOOR + 0.3, CREW.z), color=OXIDE)
    frame.uv("fleet_paint", 0.27, u=8, v=5, loc=g(*CREW), color=OXIDE)
    frame.uv("fleet_paint", 1.0, u=6, v=4, loc=g(CREW.x, CREW.y - 0.06, CREW.z + 0.26), scale=(0.075, 0.1, 0.06),
             color="bone")
with frame.region(bevel=0.012, detail=1):
    frame.box("fleet_paint", (0.07, 0.05, 0.06), loc=g(CREW.x, CREW.y - 0.03, CREW.z + 0.37), color=CHAR)
    for side in (-1, 1):
        frame.box("fleet_paint", (0.05, 0.03, 0.04), loc=g(CREW.x + side * 0.1, CREW.y + 0.05, CREW.z + 0.24),
                  color=CHAR)
frame.cyl("fleet_paint", 0.31, 0.2, 0.17, segs=8, loc=g(CREW.x, CREW.y + 0.19, CREW.z), color=CHAR)
frame.cyl("fleet_paint", 0.38, 0.38, 0.03, segs=8, loc=g(CREW.x, CREW.y + 0.11, CREW.z), color=CHAR)
frame.cyl("fleet_paint", 0.08, 0.08, 0.06, segs=6, loc=g(CREW.x, CREW.y + 0.2, CREW.z + 0.28),
          rot=(math.pi / 2, 0, 0), color="bone")
with frame.region(bevel=0, subsurf=1, detail=1):
    for side in (-1, 1):
        frame.cyl("fleet_paint", 0.07, 0.0, 0.18, segs=4, loc=g(CREW.x + side * 0.17, CREW.y + 0.32, CREW.z - 0.04),
                  color=CHAR)
LEVER = Vector((hx + 0.62, FLOOR + 0.95, hz + 0.25))
with frame.region(bevel=0.01):
    frame.rod("fleet_paint", Vector(g(hx + 0.5, FLOOR + 0.12, hz + 0.1)), Vector(g(*LEVER)), 0.04, segs=5, color=CHAR)
frame.ico("fleet_paint", 0.1, loc=g(*LEVER), color="hazard")
with frame.region(bevel=0, subsurf=1, detail=1):
    frame.rod("fleet_paint", Vector(g(CREW.x + 0.22, CREW.y - 0.25, CREW.z + 0.08)),
              Vector(g(LEVER.x - 0.05, LEVER.y - 0.04, LEVER.z)), 0.06, segs=5, color=OXIDE)
with frame.region(bevel=0.008):
    frame.beam("fleet_paint", Vector(g(hx + 0.5, FLOOR + 0.03, hz + 0.1)), Vector(g(AX + 0.2, FLOOR + 0.03, -0.3)),
               0.04, 0.03, color="brass")
bmesh.ops.recalc_face_normals(frame.bm, faces=frame.bm.faces[:])
frame_obj = frame.to_object(parent=root)


def jaw(name, sign):
    """One half oval (sign +1: the +Z half), lying open on the plate, teeth standing up."""
    part = Part(name)
    part.bevel = 0.015
    rows = []
    for k in range(SEGS + 1):
        a = math.pi * k / SEGS
        ox, oz = oval(a)
        ix, iz = oval(a, AX - BAND, AZ - BAND)
        oz, iz = oz * sign, iz * sign
        rows.append([part.bm.verts.new(g(*p)) for p in ((ix, FLOOR + 0.03, iz), (ox, FLOOR + 0.03, oz),
                                                          (ox, FLOOR + 0.13, oz), (ix, FLOOR + 0.13, iz))])
    for k in range(SEGS):
        a, b = rows[k], rows[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            quad = (a[i], b[i], b[j], a[j]) if sign > 0 else (a[j], b[j], b[i], a[i])
            color = WORN if i == 2 else STEEL
            part.paint([part.bm.faces.new(quad)], "working_tool", color)
    for row, flip in ((rows[0], True), (rows[-1], False)):
        part.paint([part.bm.faces.new(list(reversed(row)) if flip == (sign > 0) else row)], "working_tool", CHAR)
    for t in range(TEETH):
        a = math.pi * (t + 0.5) / TEETH
        cx, cz = oval(a, AX - BAND * 0.5, AZ - BAND * 0.5)
        cz *= sign
        tangent = Vector((-math.sin(a) * AX, 0, math.cos(a) * AZ * sign)).normalized()
        base = Vector((cx, FLOOR + 0.13, cz))
        half = 0.13
        h = 0.42 if t % 2 == 0 else 0.32
        pts = [base - tangent * half, base + tangent * half, base + Vector((0, h, 0))]
        normal = tangent.cross(Vector((0, 1, 0))).normalized() * 0.03
        lo = [part.bm.verts.new(g(*(p - normal))) for p in pts]
        hi = [part.bm.verts.new(g(*(p + normal))) for p in pts]
        faces = [part.bm.faces.new(lo), part.bm.faces.new(list(reversed(hi)))]
        for i in range(3):
            j = (i + 1) % 3
            faces.append(part.bm.faces.new((lo[i], hi[i], hi[j], lo[j])))
        part.paint(faces, "working_tool", "bone")
    cx, cz = oval(math.pi / 2, AX + 0.02, AZ + 0.02)
    part.box("working_tool", (0.42, 0.16, 0.14), loc=g(cx, FLOOR + 0.09, cz * sign), color="hazard")
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    return part.to_object(origin=g(0, HINGE_Y, 0), parent=root)


jaw_a = jaw("PitJawA", 1)
jaw_b = jaw("PitJawB", -1)

for name, pos in [("press_plate", (0, FLOOR + 0.09, 0)), ("catch_centre", (0, FLOOR + 1.0, 0)),
                  ("crew_head", tuple(CREW)), ("trip_lever", tuple(LEVER))]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (frame_obj, jaw_a, jaw_b)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
jaw_high = max((o.matrix_world @ v.co).z for o in (jaw_a, jaw_b) for v in o.data.vertices)
print("PIT JAW floor %.3f top %.3f jaw top %.3f tris %d" % (low, high, jaw_high, common.tri_total(root)))
print("PER", [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and jaw_high <= FLOOR + 0.56 and high <= FLOOR + 1.2
assert common.tri_total(root) <= 7000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_two", "enemy_pit_jaw.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3, tris=7000, verts=10000)


def _set(angle):
    jaw_a.rotation_euler.x = -angle
    jaw_b.rotation_euler.x = angle


if opts["render"]:
    def caught():
        ball = world_preview.ball(FLOOR, 0, 0, FLOOR + 1.0, name="CaughtBall")
        ball.parent = root

    world_preview.render(
        "pit_jaw", root, opts["render"], FLOOR, "dig", focus=(0, 0, -0.5), scale=7.5, ball_x=-3.6,
        game_target=(0, 0, -0.6), face_yaw=0, game_yaw=-20,
        poses=[("game_tell", lambda: _set(LIFT)),
               ("game_shut", lambda: (_set(math.radians(90)), caught()))],
        rest=lambda: _set(0.0))
