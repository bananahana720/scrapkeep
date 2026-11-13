# C21: an oxide Fleet animal crew on a squat two-wheel cart, hauling one square floor plate.
# The plate is 5.76 m square and 0.18 m thick, centred on the runtime's existing tilt pivot.
# A charcoal underframe and centre hinge divide two broad oxide deck panels; a petrol repair
# panel, irregular grey edge chips and short hostile-orange lip marks break up the paint.
# The centre axle ends and three hinge knuckles sit in the dark longitudinal deck recess.
# RampBody has fleet_paint (crew) and paint (cart, arms, one brass tag).
# RampPlate has paint only. Three opaque surfaces total, no lights or collision geometry.
# Blender +Z is up; g() converts Godot coordinates. The carried plate transform and deployed
# pose come from ramp_flipper.gd, rather than baked transforms in the exported mesh.
# Provenance: repository procedural primitives and bmesh; no external assets or textures.

import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part


def g(x, y, z):
    return (x, -z, y)


common.reset()
# Soft-toy polish (POLISH.md): filleted edges, one Catmull-Clark level, baked AO.
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("RampFlipper")
b = Part("RampBody")
b.cyl("fleet_paint", .55, .63, .95, segs=10, loc=g(0, -.34, 0))
b.cyl("fleet_paint", .63, .49, .74, segs=10, loc=g(0, .505, 0))
crew.handwheel_head(b, g(0, 1.16, .03), .30)
for side in (-1, 1):
    b.rod("paint", g(side * .44, .62, -.14), g(side * .48, 1.12, -.35), .075,
          segs=6, color=common.mix("oxide", "charcoal", .35))
    b.cyl("paint", .18, .18, .15, segs=10, loc=g(side * .60, -.92, .04),
          rot=(0, math.pi / 2, 0), color="charcoal")
    b.cyl("paint", .08, .08, .155, segs=6, loc=g(side * .60, -.92, .04),
          rot=(0, math.pi / 2, 0), color=common.mix("oxide", "bone", .12))
b.box("paint", (1.05, .65, .15), loc=g(0, -.88, 0), color="charcoal")
b.cyl("paint", .635, .635, .10, segs=10, loc=g(0, .02, 0), color="charcoal")
b.box("paint", (.28, .05, .18), loc=g(0, .43, .60), color="brass")
# The old works' two marks, cast in under the Fleet's paint: the crew number and HIRED.
crew.cast_number(b, "paint", "27", (0, -0.507, 0.70), (0, -1, 0), 0.16)
crew.hired(b, "paint", (0, 0.584, 0.3), (0, 1, 0), 0.08)
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
b.to_object(parent=root)

p = Part("RampPlate")
p.subsurf = 0
# Underframe, panels and rim all remain inside the base box's +/-2.88 m and +/-0.09 m.
p.box("paint", (5.76, 5.76, .10), loc=g(0, -.04, 0), color="charcoal")
for side in (-1, 1):
    p.box("paint", (2.46, 5.30, .075), loc=g(side * 1.40, .0475, 0),
          color="oxide" if side < 0 else common.mix("oxide", "charcoal", .18))
    p.box("paint", (.16, 5.76, .075), loc=g(side * 2.80, .0475, 0),
          color=common.mix("oxide", "charcoal", .38))
for z in (-2.80, 2.80):
    p.box("paint", (5.44, .16, .075), loc=g(0, .0475, z), color="charcoal")
p.rod("paint", g(0, 0, -2.88), g(0, 0, 2.88), .08, segs=8,
      color=common.mix("charcoal", "bone", .25))
for z in (-1.85, 0, 1.85):
    p.rod("paint", g(0, 0, z - .22), g(0, 0, z + .22), .09, segs=8,
          color=common.mix("oxide", "charcoal", .35))
# Thin painted polygons on the deck: one repair patch and broken edge scuffs, not a pale wash.
def mark(outline, color):
    p.prism("paint", [(x, -z) for x, z in outline], .004,
            matrix=common.mtx(g(0, .088, 0)), color=color)

mark([(.25, .75), (2.63, .75), (2.63, 2.60), (.25, 2.60)], "petrol")
wear = common.mix("charcoal", "bone", .52)
for side in (-1, 1):
    mark([(side * 2.40, -2.62), (side * 2.62, -2.62), (side * 2.62, -.90),
          (side * 2.54, -1.12), (side * 2.50, -1.72)], wear)
    mark([(side * .35, -2.60), (side * 1.70, -2.60), (side * 1.47, -2.46),
          (side * .64, -2.49)], wear)
    mark([(side * 2.25, 2.69), (side * 2.66, 2.69), (side * 2.66, 2.80),
          (side * 2.15, 2.80)], "hazard")
bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
p.to_object(parent=root)
bpy.context.view_layer.update()
tris = common.tri_total(root)
surfaces = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
print("C21 TRIS", tris, "SURFACES", surfaces)
if tris > 4400 or surfaces > 3:
    raise SystemExit("C21 assembly budget exceeded")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_ramp_flipper.glb"))
