# C12 Mag trapper: a Fleet animal crew hauling a low cart with three broad pit discs stacked
# on it, replacing the capsule crew and the four-cylinder stack mag_trapper.gd dressed it with.
# Blender +Z is up and +Y is back (the exporter turns +Y into Godot -Z), so the crew faces
# -Y and the cart trails behind at +Y. Origin is the trapper's collider centre, ground at
# z = -1.1 (the 2.2 m capsule the collider keeps).
#
# Three meshes, six surfaces after WG splits the top disc; no alpha or added geometry:
#   MagTrapperBody  static: fleet_paint (crew body and head, flashes with the enemy) and
#                   paint (vertex colour: cart, wheels, ears, strap, the brass chest tag).
#   MagStack/MagDiscs  the remaining stack, pivot at the cart bed: paint (vertex colour:
#                   two charcoal discs and spacers; the runtime gives it its own material
#                   so it flashes on a hit) and class_accent (the hazard cores; the runtime
#                   swaps in the hazard colour at emission 0.6).
#   MagStack/MagTopDisc  the independently hoisted third disc: paint and class_accent.
# Provenance: procedural bmesh in this repository; no external meshes or textures.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P enemy_mag_trapper.py -- [--out file.glb]

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
root = common.empty("MagTrapper")

GROUND = -1.1
PIVOT = (0.0, 1.95, -0.23)  # cart bed top, centre: the stack's rest pivot
CHAR = "charcoal"
CART = common.mix("charcoal", "oxide", 0.3)
WORN = common.mix("charcoal", "bone", 0.18)
HAZ = "hazard"
BRASS = "brass"
HALF_PI = math.pi / 2

# --- Body: crew, cart, wheels -------------------------------------------------------
b = Part("MagTrapperBody")
# Crew: a barrel torso (rust, flashes at runtime), a round head, a charcoal snout and ears.
b.cyl("fleet_paint", 0.66, 0.80, 1.1, segs=10, loc=(0, 0, -0.55))
b.cyl("fleet_paint", 0.80, 0.70, 1.1, segs=10, loc=(0, 0, 0.55))
crew.animal_head(b, (0, 0, 1.3), 0.38, snout=((0.26, 0.30, 0.22), (0, -0.38, 1.22)),
                 ears=(0.13, 0.34, [(s * 0.2, 0, 1.62) for s in (-1, 1)]))
b.cyl("paint", 0.81, 0.81, 0.12, segs=10, loc=(0, 0, 0.1), color=CHAR)  # strap
b.box("paint", (0.36, 0.06, 0.24), loc=(0, -0.79, 0.3), color=BRASS)  # the one brass tag
# Cart: bed, four boards, hitch, axle and two big wheels, all under the discs' footprint.
cy = PIVOT[1]
b.box("paint", (2.2, 2.2, 0.14), loc=(0, cy, PIVOT[2] - 0.07), color=CART)
b.box("paint", (2.2, 0.12, 0.30), loc=(0, cy - 1.04, PIVOT[2] + 0.08), color=CART)
b.box("paint", (2.2, 0.12, 0.30), loc=(0, cy + 1.04, PIVOT[2] + 0.08), color=CART)
for s in (-1, 1):
    b.box("paint", (0.12, 2.0, 0.22), loc=(s * 1.04, cy, PIVOT[2] + 0.04), color=WORN)
    b.cyl("paint", 0.56, 0.56, 0.26, segs=12, loc=(s * 1.24, cy, GROUND + 0.56),
          rot=(0, HALF_PI, 0), color=CHAR)
    b.cyl("paint", 0.22, 0.22, 0.30, segs=8, loc=(s * 1.24, cy, GROUND + 0.56),
          rot=(0, HALF_PI, 0), color=WORN)
b.rod("paint", (-1.24, cy, GROUND + 0.56), (1.24, cy, GROUND + 0.56), 0.08, segs=6, color=WORN)
b.box("paint", (0.20, 0.60, 0.14), loc=(0, 0.98, PIVOT[2] - 0.20), color=CART)  # hitch
body = b.to_object(parent=root)

# --- Stack: two stored discs and one independently hoisted disc ---------------------------------
stack_pivot = common.empty("MagStack", PIVOT, root)
s = Part("MagDiscs")
s.subsurf = 0
top = Part("MagTopDisc")
top.subsurf = 0
px, py, pz = PIVOT
for i, dz in enumerate((0.10, 0.50, 0.90)):
    tone = (CHAR, common.mix("charcoal", "oxide", 0.22), WORN)[i]
    disc = top if i == 2 else s
    disc.cyl("paint", 1.05, 1.05, 0.20, segs=12, loc=(px, py, pz + dz), color=tone)
    disc.cyl("class_accent", 0.50, 0.50, 0.30, segs=8, loc=(px, py, pz + dz), color=HAZ)
for dz in (0.30, 0.70):
    s.cyl("paint", 0.26, 0.26, 0.24, segs=8, loc=(px, py, pz + dz), color=CHAR)
discs = s.to_object(origin=PIVOT, parent=stack_pivot)
top_origin = (px, py, pz + 0.90)
top_disc = top.to_object(origin=top_origin, parent=stack_pivot)
bpy.context.view_layer.update()

tris = common.tri_total(root)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
dzs = [v.co.z + PIVOT[2] for v in discs.data.vertices]
surfaces = len(body.data.materials) + len(discs.data.materials) + len(top_disc.data.materials)
print("TRIS", tris, "SURFACES", surfaces, "BODY_X", round(min(xs), 3), round(max(xs), 3),
      "BODY_Y", round(min(ys), 3), round(max(ys), 3), "BODY_Z", round(min(zs), 3), round(max(zs), 3),
      "STACK_TOP", round(max(v.co.z + top_origin[2] for v in top_disc.data.vertices), 3))
if tris > 5200 or surfaces > 6 or max(abs(x) for x in xs) > 1.4 or min(ys) < -0.9 or max(ys) > 3.2 \
        or min(zs) < GROUND - 0.001 or max(zs) > 1.9:
    raise SystemExit("C12 limits exceeded")

opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_mag_trapper.glb"))
