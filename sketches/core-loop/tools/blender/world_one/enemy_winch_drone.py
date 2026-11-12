# C18 Winch drone: a Fleet animal crew slung under one broad flat rotor, with a cable drum
# hanging beneath it. The mass is stacked top and bottom around a slim waist: a 3.2 m bladed rotor
# high above (the widest shape by far), the small crew in the middle on a thin mast, and the winch
# drum slung low on its own hanger. The Hooker is one slim post with a crossbar crown, the Bola
# thrower an overhead hoop on a wide crew, the Netcaster a wide gate of masts, the Deflector one
# broad plate, the Plated brute a heavy body; the Winch drone is the only one wide at the top and
# heavy at the bottom with air between them. It replaces the capsule crew, its head, ears and tag,
# and the base's three cylinders (rotor, mast, brass drum). The gameplay lane (winch_drone.gd
# _commit_lane) is untouched; this only dresses.
#
# Blender +Z is up and -Y is forward (the exporter turns -Y into Godot +Z), so the cable drum's
# front is the local +Z the drone turns toward the ball (counter.gd _facing). Origin is the drone's
# collider centre. Coordinates below are written in Godot terms (x, y up, z forward) and turned
# into Blender by g().
#
# Cable exit: a cable pays out of the drum's front-bottom quarter, along (0, -0.707, 0.707) in
# Godot, toward the ball's lane. Nothing is modelled on that line: the drum hangs on ONE central
# hanger above it (no side straps, so the drum's ends stay open too), and the drum wears a pale
# cable wrap band across its middle, at x = 0, where the line leaves it. The cable itself is drawn
# by the runtime hold, not here.
#
# Three meshes, four surfaces (four colour-pass draws), no alpha:
#   WinchBody   fleet_paint (crew barrel, chest and head; flashes with the enemy) and paint
#               (vertex colour: charcoal mast, hanger, ears, snout, strap and pack, oxide plates and
#               one brass tag on the chest).
#   WinchDrum   paint only: the existing drum and cable wrap, pivoting on its X axle.
#   WinchRotor  paint only: three oxide blades with unequal angular spacing and one pale bare-metal
#               tip. Its origin is the rotor centre (Godot y 2.0). The body pose uses the
#               warning clock to spin it up, and the existing rest clock to coast it down.
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_winch_drone.py -- [--out file.glb]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import crew
import polish
from common import Part

common.reset()
# Soft-toy polish (POLISH.md): filleted edges and one Catmull-Clark level. The AO goes
# to UV2 only, so the one bare-metal blade tip keeps its exact painted colour (DR-1).
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0, bake_slots=())
root = common.empty("Winch")

HALF_PI = math.pi / 2
ROTOR_Y = 2.0  # the base rotor's height above the origin
ROTOR_R = 1.6
ROTOR_T = 0.08
BLADE_ANGLES = (0, 115, 245)
DRUM_Y = -1.40
DRUM_R = 0.45
DRUM_LEN = 0.90
CHAR = "charcoal"
WORN = common.mix("charcoal", "bone", 0.55)  # renders grey-slate, paler than the plates
PLATE = common.mix("oxide", "charcoal", 0.18)
PLATE_HI = common.mix("oxide", "bone", 0.10)
IRON = common.mix("charcoal", "oxide", 0.28)
DRUM_PAINT = common.mix("oxide", "charcoal", 0.35)  # a darker oxide than the crew, so the drum reads apart
BRASS = "brass"


def g(x, y, z):
    """Godot (x, y up, z forward) to Blender (x, y = -z, z = y)."""
    return (x, -z, y)


b = Part("WinchBody")

# --- The crew: an oxide barrel, chest and head, small under the rotor ------------------
b.cyl("fleet_paint", 0.50, 0.62, 0.70, segs=10, loc=g(0, -0.40, 0))  # lower barrel, tapering toward the hanger
b.cyl("fleet_paint", 0.62, 0.56, 0.60, segs=10, loc=g(0, 0.25, 0))  # chest
crew.animal_head(b, g(0, 0.85, 0.20), 0.32, snout=((0.18, 0.16, 0.22), g(0, 0.80, 0.50)),
                 ears=(0.10, 0.28, [g(s * 0.17, 1.24, 0.16) for s in (-1, 1)]))
b.cyl("paint", 0.64, 0.64, 0.10, segs=10, loc=g(0, -0.02, 0), color=CHAR)  # strap round the waist
b.box("paint", (0.50, 0.55, 0.30), loc=g(0, 0.15, -0.62), color=CHAR)  # battery pack behind the crew
b.box("paint", (0.28, 0.18, 0.05), loc=g(0, 0.20, 0.60), color=BRASS)  # the one brass requisition tag
for s in (-1, 1):
    b.box("paint", (0.06, 0.55, 0.42), loc=g(s * 0.62, 0.20, 0.05), color=PLATE)  # welded flank plates

# --- The mast and hub: a thin column up to the rotor ----------------------------------
b.rod("paint", g(0, 0.6, -0.32), g(0, ROTOR_Y - 0.06, -0.32), 0.09, segs=6, color=CHAR)
for s in (-1, 1):
    b.rod("paint", g(s * 0.45, 0.62, -0.05), g(0, 1.55, -0.32), 0.05, segs=5, color=IRON)  # shoulder stays
b.cyl("paint", 0.30, 0.26, 0.12, segs=8, loc=g(0, ROTOR_Y - 0.10, -0.32), rot=(0, 0, 0), color=CHAR)  # hub cup under the rotor

# --- The drum: hung low on one central hanger ------------------------------------------
b.cyl("paint", 0.14, 0.18, 0.30, segs=6, loc=g(0, -0.88, 0), color=CHAR)  # the hanger, x = 0 only
b.box("paint", (0.92, 0.10, 0.60), loc=g(0, DRUM_Y + DRUM_R + 0.04, 0), color=IRON)  # saddle over the drum
d = Part("WinchDrum")
drum = d.cyl("paint", DRUM_R, DRUM_R, DRUM_LEN, segs=16, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=DRUM_PAINT)
d.bm.normal_update()
d.paint([f for f in drum if abs(f.normal.x) > 0.9], "paint", CHAR)  # the two dark end flanges
d.cyl("paint", DRUM_R + 0.05, DRUM_R + 0.05, 0.26, segs=8, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=WORN)  # cable wrap

bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)
bmesh.ops.recalc_face_normals(d.bm, faces=d.bm.faces[:])
drum_node = d.to_object(origin=g(0, DRUM_Y, 0), parent=root)

# --- The rotor: unequal tip spacing and one marked blade make the turn readable ------------
pivot = g(0, ROTOR_Y, 0)
r = Part("WinchRotor")
r.bevel = 0
r.subsurf = 0
rb = r.bm
r.cyl("paint", 0.28, 0.28, ROTOR_T, segs=8, loc=pivot, color=CHAR)


def blade_section(angle, inner, outer, color):
    # Corners lie on the radial envelope, so even the wide tip stays within 1.6 m.
    outline = []
    for radius, side in ((inner, -1), (outer, -1), (outer, 1), (inner, 1)):
        theta = angle + side * math.radians(8)
        outline.append((radius * math.cos(theta), radius * math.sin(theta)))
    top = [rb.verts.new(Vector(g(x, ROTOR_Y + ROTOR_T / 2, z))) for x, z in outline]
    bot = [rb.verts.new(Vector(g(x, ROTOR_Y - ROTOR_T / 2, z))) for x, z in outline]
    r.paint([rb.faces.new(top), rb.faces.new(list(reversed(bot)))], "paint", color)
    for k in range(4):
        n = (k + 1) % 4
        r.paint([rb.faces.new((top[k], bot[k], bot[n], top[n]))], "paint", color)


for index, degrees in enumerate(BLADE_ANGLES):
    angle = math.radians(degrees)
    if index == 0:
        blade_section(angle, 0.23, 1.15, PLATE)
        blade_section(angle, 1.15, ROTOR_R, "bone")
    else:
        blade_section(angle, 0.23, ROTOR_R, PLATE)
bmesh.ops.recalc_face_normals(rb, faces=rb.faces[:])
rotor = r.to_object(origin=pivot, parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
# Keep the original whole-body envelope check after splitting the drum.
points = [obj.matrix_world @ v.co for obj in (body, drum_node) for v in obj.data.vertices]
xs = [v.x for v in points]
ys = [v.y for v in points]
zs = [v.z for v in points]
surfaces = len(body.data.materials) + len(rotor.data.materials) + len(drum_node.data.materials)
rotor_drum = common.tris(rotor) + 64  # the 16-sided drum: 32 side + 32 cap triangles
print("TRIS", tris, "SURFACES", surfaces, "ROTOR", common.tris(rotor), "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3))
if tris > 4600 or surfaces > 4 or rotor_drum >= 150 or max(abs(x) for x in xs) > 1.0 or min(ys) < -1.1 or max(ys) > 1.0 \
        or min(zs) < DRUM_Y - DRUM_R - 0.06 or max(zs) > ROTOR_Y:
    raise SystemExit("C18 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_winch_drone.glb"))
