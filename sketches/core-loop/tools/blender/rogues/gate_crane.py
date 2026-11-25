"""Gate Crane No. 14 (Spillway rogue): one-piece mojulo shells finished as a rigid-posed GLB.

blender -b --factory-startup --python gate_crane.py -- [--out file.glb]
Shells: gate_crane.mojulo.json -> shells/gate_crane.glb (python3 shells.py gate_crane).
Origin is the 2.4 m / 7.2 m collider centre, forward Godot -Z (Blender +Y). Brief:
design-v3/rogues/BRIEFS.md section 1; views: docs/art/reference/rogues/gate_crane/.
"""
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
import kit
import polish
from common import Part

kit.setup()
polish.enable(detail=1, subsurf=0, bevel=0.03, bevel_angle=40.0, sharp_angle=55.0)
HALF = 3.6
DOWN = (0, 0, -HALF)
root = common.empty("GateCrane")
SLOT = "fleet_paint"
WEAR = common.mix("petrol", "sandstone", 0.35)
WORN = common.mix("charcoal", "bone", 0.45)
SLATE = "6f7f8f"


def at(x, y, z):
    return (x, y, z - HALF)


bone_rows = [
    ("CraneBody", at(0, 0, 0)),
    ("CraneJib", at(0, 0, 6.76)),
    ("CraneHook", at(0, 6.9, 4.2)),
    ("CraneLeaf", at(0, 6.9, 2.54)),
    ("CranePlateLeft", at(-0.72, -2.40, 5.55)),
    ("CranePlateRight", at(0.72, -2.40, 5.55)),
    ("CraneGovernor", at(0, -0.62, 6.4)),
]


def body_paint(c, n):
    z = c.z + HALF
    if z < 0.3:
        return "charcoal"
    if n.z > 0.6 and z < 1.3:
        return WEAR
    return "petrol"


def jib_paint(c, n):
    if c.y > 6.75:
        return "charcoal"
    return WEAR if n.z > 0.8 else "petrol"


def hook_paint(c, n):
    return "charcoal" if c.z + HALF < 3.02 else "amber"


def leaf_paint(c, n):
    return WORN if abs(n.y) < 0.6 else "charcoal"


def mast_width(z):
    return 1.5 * (1 - 0.4 * (z - 0.9) / 5.5)


pieces, imported = kit.import_shells("gate_crane")
shells = {
    "Body": (2100, body_paint), "Jib": (560, jib_paint), "Hook": (260, hook_paint), "Leaf": (320, leaf_paint),
}
meshes = {name: kit.shell_mesh(pieces[name], tris, DOWN) for name, (tris, _) in shells.items()}
kit.drop(imported)

hull = Part("GateCraneHull")
bind = kit.weights(hull)
kit.add_shell(hull, meshes["Body"], SLOT, body_paint)
for x in (-1.5, 1.5):
    hull.box(SLOT, (0.14, 4.3, 0.08), loc=at(x, 0, 0.04), color="brass")
    for y in (-1.5, 1.5):
        for dy in (-0.3, 0.3):
            hull.cyl(SLOT, 0.21, 0.21, 0.16, segs=8, loc=at(x, y + dy, 0.24), rot=(0, 1.5708, 0), color="charcoal")
for side in (-1, 1):
    kit.stencil(hull, SLOT, "14", at(side * 0.61, 0, 3.4), (side, 0, 0.04), 1.05, "bone")
kit.stencil(hull, SLOT, "HIRED", at(-0.92, 1.37, 1.47), (0, 1, 0), 0.15, "bone", resolution=1)
kit.cut_line(hull, SLOT, [at(-1.41, 0.95, 1.85), at(-1.52, 1.05, 1.45), at(-1.58, 1.2, 0.95), at(-1.55, 1.38, 0.62)],
             radius=0.075)
for z in (2.0, 4.55):
    w = mast_width(z) + 0.05
    hull.box(SLOT, (w, w, 0.13), loc=at(0, 0, z), color="brass")
hull.ring(SLOT, 0.86, 1.0, 0.12, segs=16, loc=at(0, -1.165, 5.55), rot=(1.5708, 0, 0), color="brass")
hull.ring(SLOT, 0.76, 1.0, 0.24, segs=16, loc=at(0, -2.29, 5.55), rot=(1.5708, 0, 0), color="brass")
hull.cyl(SLOT, 0.73, 0.73, 0.02, segs=14, loc=at(0, -2.228, 5.55), rot=(1.5708, 0, 0), color="charcoal")
hull.box(SLOT, (0.6, 0.03, 0.4), loc=at(-0.92, 1.325, 1.86), color="ice")
bind(0)
kit.add_shell(hull, meshes["Jib"], SLOT, jib_paint)
hull.beam(SLOT, at(0, 0.35, 7.17), at(0, 6.55, 7.04), 0.2, 0.06, color="brass")
bind(1)
kit.add_shell(hull, meshes["Hook"], SLOT, hook_paint)
hull.rod(SLOT, at(0, 6.9, 6.25), at(0, 6.9, 4.18), 0.04, segs=6, color="charcoal")
bind(2)
kit.add_shell(hull, meshes["Leaf"], SLOT, leaf_paint)
bind(3)
kit.governor(hull, SLOT, at(0, -0.62, 6.4), height=0.82, scale=1.6)
bind(6)
hull_obj = kit.finish(hull, root)

armour = Part("GateCraneArmour")
armour.bevel = 0.02
bind_plate = kit.weights(armour)
import math
for side, index in [(-1, 4), (1, 5)]:
    outline = [(side * 0.015, 0.7)]
    for k in range(9):
        a = math.pi / 2 - math.pi * k / 8
        outline.append((side * (0.015 + 0.705 * math.cos(a)), 0.705 * math.sin(a)))
    outline.append((side * 0.015, -0.7))
    if side < 0:
        outline.reverse()
    m = Matrix.Translation(at(0, -2.40, 5.55)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    armour.prism("part_state", outline, 0.07, matrix=m, color=SLATE)
    armour.box("part_state", (0.05, 0.05, 0.9), loc=at(side * 0.66, -2.45, 5.55), color="brass")
    armour.box("part_state", (0.08, 0.04, 0.28), loc=at(side * 0.12, -2.45, 5.55), color="charcoal")
    bind_plate(index)
armour_obj = kit.finish(armour, root)

core = Part("GateCraneCore")
core.subsurf = 0
core.uv("core_state", 0.5, u=12, v=8, loc=at(0, -2.22, 5.55), scale=(1, 0.28, 1))
core_obj = core.to_object(origin=at(0, -2.22, 5.55), parent=root)

kit.rig(root, "GateCranePose", bone_rows, (hull_obj, armour_obj))
out = common.args()["out"] or os.path.join(common.MODELS, "rogues", "gate_crane.glb")
kit.export(root, out, (hull_obj, armour_obj, core_obj))
