"""Linker: a kill-first emplacement that holds a dish over a partner on a long boom.

ENEMY-PRIORITY.md 4a: emplacement chassis, fixed; the threat feature is a dish on a long
boom arm held over another enemy, with a slack cable from base to dish. Silhouette: a short
post whose arm breaks the outline sideways; nothing else in the roster has a sideways arm.
Cut the cable (shot, or a harpoon bite and yank) and the dish drops; flank it through the air.

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). The boom reaches along +X and the partner
stands under it at partner_spot (3.6 m out), so the whole Linker is yawed once, when it is
placed, to put partner_spot on its partner; it does not track the ball with counter.gd
_facing. The dish rests facing Godot +Z, and it is the dish that turns toward the ball: it
yaws and tilts about LinkerHinge. cable_dish rides on the dish, so a redrawn cable follows.
Collider core: radius 0.8 round the post (the tripod feet splay to 1.1), floor Y = -1.1.
Three meshes, three surfaces, opaque vertex colour:
  LinkerBody   fleet_paint: tripod, post, winch drum, operator cab with its crew, boom and
               counterweight. Flashes with the enemy.
  LinkerDish   working_tool: the dish, its hazard rim and hanger, skinned whole to the
               DishBrace bone (clips) under DishAim (runtime aim), both at the hinge.
  LinkerCable  requisition_tag: the slack cable from the drum to the dish, with a coupling
               sleeve at mid-span (the cut mark). Brass at rest; the runtime lights it while
               the dish is braced and may redraw it between cable_base and cable_dish.
Sockets (empties, no draws): LinkerHinge, boom_tip, cable_base, cable_dish, cable_cut,
partner_spot, LinkerCab. Procedural bmesh in this repository; no external meshes or textures.
Rig and clips (idle, brace, braced, slack, cut): kill_first_motion.linker.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir] [--sheet dir]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import common
import polish
from common import Part

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.48, "metal": 0.55}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Linker")

FLOOR = -1.1
OXIDE = "9b513a"
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
PIVOT = (0.0, 1.25, 0.0)
TIP = (3.6, 2.85, 0.75)
HINGE = (3.6, 2.7, 0.95)
DISH_R = 1.35
TILT = math.radians(28)
DISH_C = (3.6, 1.75, 1.65)
DRUM = (0.42, -0.35, 0.0)
PARTNER = (3.6, FLOOR, 0.0)


def g(x, y, z):
    return (x, -z, y)


def G(p):
    return Vector(g(*p))


body = Part("LinkerBody")

body.cyl("fleet_paint", 0.78, 0.7, 0.12, segs=8, loc=g(0, FLOOR + 0.06, 0), color=CHAR)
for k in range(3):
    a = math.radians(90 + 120 * k)
    foot = (0.84 * math.cos(a), FLOOR + 0.1, 0.84 * math.sin(a))
    body.rod("fleet_paint", G((0.2 * math.cos(a), -0.3, 0.2 * math.sin(a))), G(foot), 0.09, segs=5, color=CHAR)
    body.box("fleet_paint", (0.3, 0.3, 0.08), loc=g(foot[0], FLOOR + 0.04, foot[2]), color=WORN)

body.cyl("fleet_paint", 0.36, 0.3, 1.9, segs=8, loc=g(0, -0.1, 0), color=OXIDE)
body.cyl("fleet_paint", 0.39, 0.39, 0.16, segs=8, loc=g(0, 0.45, 0), color=WORN)
body.cyl("fleet_paint", 0.22, 0.22, 0.42, segs=8, loc=g(*DRUM), rot=(math.pi / 2, 0, 0), color=STEEL)
for dz in (-0.23, 0.23):
    body.cyl("fleet_paint", 0.3, 0.3, 0.05, segs=8, loc=g(DRUM[0], DRUM[1], dz),
             rot=(math.pi / 2, 0, 0), color=CHAR)

body.box("fleet_paint", (0.95, 0.62, 0.8), loc=g(-0.1, 1.08, 0), color=OXIDE)
body.box("fleet_paint", (1.02, 0.08, 0.86), loc=g(-0.1, 1.42, 0), color=CHAR)
body.box("fleet_paint", (0.62, 0.2, 0.04), loc=g(-0.12, 1.12, 0.41), color=CHAR)
body.uv("fleet_paint", 0.24, u=8, v=5, loc=g(-0.12, 1.2, 0.3), color="oxide")
body.box("fleet_paint", (0.12, 0.09, 0.1), loc=g(-0.12, 1.16, 0.53), color="bone")
for side in (-1, 1):
    body.cyl("fleet_paint", 0.09, 0.0, 0.26, segs=4, loc=g(-0.12 + side * 0.14, 1.52, 0.3), color=CHAR)

lo_root, hi_root = (0.3, 1.05, 0.0), (0.3, 1.45, 0.0)
lo_tip, hi_tip = (TIP[0], TIP[1] - 0.18, TIP[2]), (TIP[0], TIP[1] + 0.12, TIP[2])
body.beam("fleet_paint", G(lo_root), G(lo_tip), 0.16, 0.16, color=OXIDE)
body.beam("fleet_paint", G(hi_root), G(hi_tip), 0.12, 0.12, color=OXIDE)
for k in range(4):
    t0, t1 = k / 4, (k + 1) / 4
    a = Vector(lo_root).lerp(Vector(lo_tip), t0) if k % 2 == 0 else Vector(hi_root).lerp(Vector(hi_tip), t0)
    b = Vector(hi_root).lerp(Vector(hi_tip), t1) if k % 2 == 0 else Vector(lo_root).lerp(Vector(lo_tip), t1)
    body.beam("fleet_paint", G(a), G(b), 0.07, 0.07, color=CHAR)
stripe = Vector(lo_root).lerp(Vector(lo_tip), 0.82)
body.beam("fleet_paint", G(stripe - Vector((0.15, 0.12, 0))), G(stripe + Vector((0.15, 0.12, 0))),
          0.2, 0.2, color="bone")
body.box("fleet_paint", (0.34, 0.34, 0.5), loc=g(TIP[0], TIP[1] - 0.03, TIP[2]), color=CHAR)
body.cyl("fleet_paint", 0.22, 0.22, 0.3, segs=8, loc=g(*PIVOT), rot=(math.pi / 2, 0, 0), color=STEEL)
body.beam("fleet_paint", G((-0.3, 1.25, 0)), G((-1.05, 1.15, 0)), 0.14, 0.14, color=CHAR)
body.box("fleet_paint", (0.62, 0.6, 0.62), loc=g(-1.2, 1.05, 0), color=STEEL)
body.box("fleet_paint", (0.66, 0.1, 0.66), loc=g(-1.2, 1.1, 0), color="hazard")

bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
body_obj = body.to_object(parent=root)

dish = Part("LinkerDish")
dish.subsurf = 0
N = Vector((0.0, -math.sin(TILT), math.cos(TILT)))
U = Vector((1.0, 0.0, 0.0))
V = N.cross(U)
C = Vector(DISH_C)


def on_dish(u, v, w):
    return G(C + U * u + V * v + N * w)


SECT = 10
RINGS = [0.0, 0.5, 0.95, DISH_R]
DEPTH = 0.32
SKIN = 0.12


def bowl(r):
    return -DEPTH * (1.0 - (r / DISH_R) ** 2)


front, back = [], []
for r in RINGS:
    fr, bk = [], []
    for k in range(SECT if r > 0 else 1):
        a = math.tau * k / SECT
        u, v = r * math.cos(a), r * math.sin(a)
        fr.append(dish.bm.verts.new(on_dish(u, v, bowl(r))))
        bk.append(dish.bm.verts.new(on_dish(u, v, bowl(r) - SKIN - 0.06 * (1 - r / DISH_R))))
    front.append(fr)
    back.append(bk)
for rows, flip, color in ((front, False, WORN), (back, True, CHAR)):
    for j in range(len(rows) - 1):
        for k in range(SECT):
            n = (k + 1) % SECT
            if j == 0:
                quad = (rows[0][0], rows[1][k], rows[1][n])
            else:
                quad = (rows[j][k], rows[j + 1][k], rows[j + 1][n], rows[j][n])
            f = dish.bm.faces.new(tuple(reversed(quad)) if flip else quad)
            c = "bone" if (rows is front and j == 1) else color
            dish.paint([f], "working_tool", c)
for k in range(SECT):
    n = (k + 1) % SECT
    f = dish.bm.faces.new((front[-1][k], back[-1][k], back[-1][n], front[-1][n]))
    dish.paint([f], "working_tool", "hazard" if k % 2 == 0 else CHAR)
hub = C - N * (SKIN + 0.12)
dish.cyl("working_tool", 0.22, 0.16, 0.18, segs=6, loc=G(hub), color=STEEL,
         rot=Vector((0, 0, 1)).rotation_difference(Vector(g(*N))).to_euler())
dish.beam("working_tool", G(hub), G(HINGE), 0.12, 0.12, color=CHAR)
dish.beam("working_tool", G(C + V * 1.0 - N * SKIN), G(HINGE), 0.08, 0.08, color=CHAR)
dish.cyl("working_tool", 0.12, 0.12, 0.36, segs=6, loc=g(*HINGE), rot=(0, math.pi / 2, 0), color=STEEL)
bmesh.ops.recalc_face_normals(dish.bm, faces=dish.bm.faces[:])
dish_obj = dish.to_object(origin=g(*HINGE), parent=root)

cable = Part("LinkerCable")
cable.subsurf = 0
start = Vector((DRUM[0] + 0.05, DRUM[1] + 0.22, DRUM[2] + 0.1))
end = C - V * 0.95 - N * (SKIN + 0.05)
SAG = 0.75
pts = []
for i in range(9):
    t = i / 8
    p = start.lerp(end, t)
    p.y -= SAG * 4 * t * (1 - t)
    pts.append(p)
for a, b in zip(pts, pts[1:]):
    cable.rod("requisition_tag", G(a), G(b), 0.07, segs=5, color="brass")
mid = pts[4]
cable.rod("requisition_tag", G(mid - (pts[5] - pts[3]).normalized() * 0.2),
          G(mid + (pts[5] - pts[3]).normalized() * 0.2), 0.14, segs=6, color="hazard")
bmesh.ops.recalc_face_normals(cable.bm, faces=cable.bm.faces[:])
cable_obj = cable.to_object(parent=root)

for name, pos in [("LinkerHinge", HINGE), ("boom_tip", TIP), ("cable_base", tuple(start)),
                  ("cable_cut", tuple(mid)), ("partner_spot", PARTNER), ("LinkerCab", (-0.12, 1.2, 0.3))]:
    common.empty(name, g(*pos), parent=root)
common.empty("cable_dish", g(*end), parent=dish_obj)

bpy.context.view_layer.update()
post = [body_obj.matrix_world @ v.co for v in body_obj.data.vertices]
core = max(math.hypot(p.x, p.y) for p in post if p.z < 0.6)
low = min((o.matrix_world @ v.co).z for o in (body_obj, dish_obj, cable_obj) for v in o.data.vertices)
print("LINKER core %.3f floor %.3f tris %d" % (core, low, common.tri_total(root)))
assert low >= FLOOR - 1e-4 and core <= 1.1
assert common.tri_total(root) <= 7400

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_linker.glb")
import kill_first_motion
import kill_first_rig
rig = kill_first_motion.linker(root, body_obj, dish_obj, cable_obj, start, end, SAG, HINGE, DISH_C, FLOOR, PIVOT)
stats = rig.export(path, draws=3)
print(f"LINKER EXPORTED: {stats['verts']} V / {stats['tris']} T / {stats['draws']} D, "
      f"{stats['joints']} joints, clips {stats['clips']}")
if kill_first_rig.sheet_dir():
    kill_first_rig.contact_sheet("linker", rig, FLOOR, kill_first_rig.sheet_dir(), focus=(1.6, 0, 0.9), scale=8.5,
                                 shots=kill_first_motion.LINKER_SHOTS, yaw=145, lit_clips=("brace", "braced"))

if opts["render"]:
    import kill_first_preview

    def partner():
        bpy.ops.import_scene.gltf(filepath=os.path.join(common.MODELS, "world_one", "enemy_chaser.glb"))
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.parent = root
                o.location = Vector(g(PARTNER[0], FLOOR + 1.5, PARTNER[2]))
                o.rotation_euler.z = math.pi

    kill_first_preview.render("linker", root, opts["render"], FLOOR, focus=(0, 0, 1.0), scale=10.5,
                              ball_x=-3.0, extras=partner, game_target=(1.6, 0, 0.6), face_yaw=0)
