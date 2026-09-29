# C18 Winch drone: a Fleet animal crew slung under one broad flat rotor, with a cable drum
# hanging beneath it. The mass is stacked top and bottom around a slim waist: a 3.2 m rotor disc
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
# Two meshes, three surfaces (three colour-pass draws), no alpha:
#   WinchBody   fleet_paint (crew barrel, chest and head; flashes with the enemy) and paint
#               (vertex colour: charcoal mast, hanger, ears, snout, strap and pack, oxide plates and
#               drum, the cable wrap in worn bone-grey, one brass tag on the chest).
#   WinchRotor  paint only: a 16-sided disc, oxide and charcoal blades in quarter turns so the spin
#               shows. Its origin is the rotor centre (Godot y 2.0), so winch_drone.gd _pose still
#               turns it about its own axis each physics tick, as the base rotor turned.
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
from common import Part

common.reset()
root = common.empty("Winch")

HALF_PI = math.pi / 2
ROTOR_Y = 2.0  # the base rotor's height above the origin
ROTOR_R = 1.6
ROTOR_T = 0.08
SECTORS = 16
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
b.uv("fleet_paint", 0.32, u=10, v=6, loc=g(0, 0.85, 0.20))  # head, forward of the mast
b.box("paint", (0.18, 0.16, 0.22), loc=g(0, 0.80, 0.50), color=CHAR)  # snout
for s in (-1, 1):
    b.cyl("paint", 0.10, 0.0, 0.28, segs=6, loc=g(s * 0.17, 1.24, 0.16), color=CHAR)  # ears
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
drum = b.cyl("paint", DRUM_R, DRUM_R, DRUM_LEN, segs=16, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=DRUM_PAINT)
b.bm.normal_update()
b.paint([f for f in drum if abs(f.normal.x) > 0.9], "paint", CHAR)  # the two dark end flanges
b.cyl("paint", DRUM_R + 0.05, DRUM_R + 0.05, 0.26, segs=8, loc=g(0, DRUM_Y, 0), rot=(0, HALF_PI, 0), color=WORN)  # cable wrap

bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

# --- The rotor: a flat 16-sided disc, blades alternating in quarter turns -----------------
pivot = g(0, ROTOR_Y, 0)
r = Part("WinchRotor")
rb = r.bm
top_c = rb.verts.new(Vector(g(0, ROTOR_Y + ROTOR_T / 2, 0)))
bot_c = rb.verts.new(Vector(g(0, ROTOR_Y - ROTOR_T / 2, 0)))
step = 2 * math.pi / SECTORS
top = [rb.verts.new(Vector(g(ROTOR_R * math.cos(k * step), ROTOR_Y + ROTOR_T / 2, ROTOR_R * math.sin(k * step)))) for k in range(SECTORS)]
bot = [rb.verts.new(Vector(g(ROTOR_R * math.cos(k * step), ROTOR_Y - ROTOR_T / 2, ROTOR_R * math.sin(k * step)))) for k in range(SECTORS)]
for k in range(SECTORS):
    n = (k + 1) % SECTORS
    blade = (k // 2) % 2 == 0  # two sectors of oxide, two of charcoal: four blades in the turn
    col = PLATE if blade else CHAR
    r.paint([rb.faces.new((top_c, top[k], top[n]))], "paint", col)
    r.paint([rb.faces.new((bot_c, bot[n], bot[k]))], "paint", col)
    r.paint([rb.faces.new((top[k], bot[k], bot[n], top[n]))], "paint", CHAR)
bmesh.ops.recalc_face_normals(rb, faces=rb.faces[:])
rotor = r.to_object(origin=pivot, parent=root)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
surfaces = len(body.data.materials) + len(rotor.data.materials)
rotor_drum = common.tris(rotor) + 64  # the 16-sided drum: 32 side + 32 cap triangles
print("TRIS", tris, "SURFACES", surfaces, "ROTOR", common.tris(rotor), "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3))
if tris > 1200 or surfaces > 3 or rotor_drum >= 150 or max(abs(x) for x in xs) > 1.0 or min(ys) < -1.1 or max(ys) > 1.0 \
        or min(zs) < DRUM_Y - DRUM_R - 0.06 or max(zs) > ROTOR_Y:
    raise SystemExit("C18 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_winch_drone.glb"))
