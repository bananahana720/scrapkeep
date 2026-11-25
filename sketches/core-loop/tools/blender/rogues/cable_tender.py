"""Cable Tender No. 7 (Highdraft rogue): one-piece mojulo shells finished as a rigid-posed GLB.

blender -b --factory-startup --python cable_tender.py -- [--out file.glb]
Shells: cable_tender.mojulo.json -> shells/cable_tender.glb (python3 shells.py cable_tender).
Origin is the 2.3 m / 6 m collider centre, forward Godot -Z (Blender +Y). The hatch is on the
left bearing housing at the spool's axle end, facing -X; TenderPlateLeft is its front (+Y)
door as seen from outside the hatch. Brief: design-v3/rogues/BRIEFS.md section 3; views:
docs/art/reference/rogues/cable_tender/.
"""
import math
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
HALF = 3.0
DOWN = (0, 0, -HALF)
root = common.empty("CableTender")
SLOT = "fleet_paint"
WEAR = common.mix("petrol", "sandstone", 0.35)
CABLE = common.mix("charcoal", "ice", 0.28)
WORN = common.mix("charcoal", "bone", 0.45)
SLATE = "6f7f8f"
AXLE = 3.9


def at(x, y, z):
    return (x, y, z - HALF)


bone_rows = [
    ("TenderBody", at(0, 0, 0)),
    ("TenderSpool", at(0, 0, AXLE)),
    ("TenderBoom", at(0, 1.82, 2.62)),
    ("TenderHarpoon", at(0, 6.0, 2.62)),
    ("TenderPlateLeft", at(-1.93, 0.64, AXLE)),
    ("TenderPlateRight", at(-1.93, -0.64, AXLE)),
    ("TenderGovernor", at(1.6, -0.25, 4.24)),
]


def body_paint(c, n):
    z = c.z + HALF
    if z < 0.1:
        return "charcoal"
    if n.z > 0.7 and z < 1.0:
        return WEAR
    return "petrol"


def spool_paint(c, n):
    r = Vector((c.y, c.z + HALF - AXLE)).length
    if abs(c.x) > 1.33 or r > 1.62:
        return "copper"
    if r < 0.4:
        return "charcoal"
    return CABLE


def boom_paint(c, n):
    return WEAR if n.z > 0.8 else "petrol"


def harpoon_paint(c, n):
    return "copper" if c.y > 6.3 else "charcoal"


pieces, imported = kit.import_shells("cable_tender")
meshes = {
    "Body": kit.shell_mesh(pieces["Body"], 1700, DOWN), "Spool": kit.shell_mesh(pieces["Spool"], 1200, DOWN),
    "Boom": kit.shell_mesh(pieces["Boom"], 450, DOWN), "Harpoon": kit.shell_mesh(pieces["Harpoon"], 200, DOWN),
}
kit.drop(imported)

hull = Part("CableTenderHull")
bind = kit.weights(hull)
kit.add_shell(hull, meshes["Body"], SLOT, body_paint)
hull.ring(SLOT, 0.68, 0.88, 0.1, segs=16, loc=at(-1.93, 0, AXLE), rot=(0, math.pi / 2, 0), color="copper")
hull.cyl(SLOT, 0.65, 0.65, 0.02, segs=14, loc=at(-1.865, 0, AXLE), rot=(0, math.pi / 2, 0), color="charcoal")
for side in (-1, 1):
    kit.stencil(hull, SLOT, "07", at(side * 1.78, 0, 1.55), (side, 0, 0), 0.72, "bone")
kit.stencil(hull, SLOT, "HIRED", at(1.2, 1.81, 0.27), (0, 1, 0), 0.16, "bone", resolution=1)
kit.cut_line(hull, SLOT, [at(-1.75, 0.45, 3.25), at(-2.0, 0.6, 2.7), at(-2.1, 0.75, 2.2)], radius=0.075)
bind(0)
kit.add_shell(hull, meshes["Spool"], SLOT, spool_paint)
for x in (-0.55, 0.45):
    hull.rod(SLOT, at(x, 0.35, AXLE - 1.45), at(x, 0.45, 1.35), 0.05, segs=6, color=CABLE)
    hull.ring(SLOT, 0.07, 0.13, 0.05, segs=10, loc=at(x, 0.45, 1.22), rot=(0, math.pi / 2, 0), color=WORN)
bind(1)
kit.add_shell(hull, meshes["Boom"], SLOT, boom_paint)
hull.cyl(SLOT, 0.2, 0.2, 0.16, segs=10, loc=at(0, 5.96, 2.62), rot=(math.pi / 2, 0, 0), color="copper")
bind(2)
kit.add_shell(hull, meshes["Harpoon"], SLOT, harpoon_paint)
bind(3)
kit.governor(hull, SLOT, at(1.6, -0.25, 4.24), height=0.82, scale=1.6)
bind(6)
hull_obj = kit.finish(hull, root)

armour = Part("CableTenderArmour")
armour.bevel = 0.02
bind_plate = kit.weights(armour)
for side, index in [(1, 4), (-1, 5)]:
    outline = [(side * 0.015, 0.64)]
    for k in range(9):
        a = math.pi / 2 - math.pi * k / 8
        outline.append((side * (0.015 + 0.625 * math.cos(a)), 0.625 * math.sin(a)))
    outline.append((side * 0.015, -0.64))
    if side < 0:
        outline.reverse()
    m = Matrix.Translation(at(-1.93, 0, AXLE)) @ Matrix.Rotation(-math.pi / 2, 4, "Y") @ Matrix.Rotation(
        math.pi / 2, 4, "Z")
    armour.prism("part_state", outline, 0.06, matrix=m, color=SLATE)
    armour.box("part_state", (0.05, 0.05, 0.8), loc=at(-1.97, side * 0.6, AXLE), color="brass")
    armour.box("part_state", (0.04, 0.08, 0.26), loc=at(-1.97, side * 0.11, AXLE), color="charcoal")
    bind_plate(index)
armour_obj = kit.finish(armour, root)

core = Part("CableTenderCore")
core.subsurf = 0
core.uv("core_state", 0.46, u=12, v=8, loc=at(-1.86, 0, AXLE), scale=(0.3, 1, 1))
core_obj = core.to_object(origin=at(-1.86, 0, AXLE), parent=root)

kit.rig(root, "CableTenderPose", bone_rows, (hull_obj, armour_obj))
out = common.args()["out"] or os.path.join(common.MODELS, "rogues", "cable_tender.glb")
kit.export(root, out, (hull_obj, armour_obj, core_obj))
