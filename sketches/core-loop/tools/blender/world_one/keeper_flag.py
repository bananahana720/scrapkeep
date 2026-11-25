import math
import os
import sys
import bmesh
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part

for slot, rough, metal in [("flag_metal", 0.6, 0.3), ("flag_cloth", 0.95, 0.0)]:
    common.SLOTS[slot] = {"vc": True, "rough": rough, "metal": metal}

TAU = math.tau
HEX = {"iron": "2b2724", "iron_hi": "4a4e4c", "copper": "b77843", "copper_dk": "8d5a32", "sand": "d2c5a5",
       "sand_dk": "b9b095"}
COIL_TURNS, COIL_Y0, COIL_Y1, COIL_R, WIRE_R = 6, 0.16, 0.66, 0.085, 0.02
STAFF_R, STAFF_TOP = 0.028, 2.0
CLOTH_W, CLOTH_H, CLOTH_T, CLOTH_COLS = 0.6, 0.4, 0.003, 8
HOIST_Y1 = STAFF_TOP - 0.06
HOIST_Y0 = HOIST_Y1 - CLOTH_H
LIMIT_TRIS = 2000


def c(name):
    return common.srgb(HEX[name])


def g(x, y, z):
    return (x, -z, y)


def finish(p, root, origin=(0.0, 0.0, 0.0)):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin), parent=root)


def sweep(p, slot, points, r, sides, color):
    """A closed tube of `sides` sides along points (Godot frame), capped flat at both ends."""
    bm = p.bm
    rings = []
    pts = [Vector(g(*q)) for q in points]
    for i, q in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-6:
            side = d.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(d).normalized()
        rings.append([bm.verts.new(q + (side * math.cos(TAU * k / sides) + up * math.sin(TAU * k / sides)) * r)
                      for k in range(sides)])
    faces = []
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            faces.append(bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    faces.append(bm.faces.new(rings[-1]))
    return p.paint(faces, slot, color)


def build():
    root = common.empty("KeeperFlag")
    p = Part("FlagPole")
    p.box("flag_metal", (0.34, 0.12, 0.26), loc=g(0, 0.06, 0), color=c("iron"))
    p.cyl("flag_metal", 0.12, 0.11, 0.05, segs=10, loc=g(0, 0.145, 0), rot=(0, 0, 0), color=c("copper_dk"))
    helix = []
    steps = COIL_TURNS * 10
    for k in range(steps + 1):
        t = k / steps
        a = TAU * COIL_TURNS * t
        helix.append((COIL_R * math.cos(a), COIL_Y0 + (COIL_Y1 - COIL_Y0) * t, COIL_R * math.sin(a)))
    sweep(p, "flag_metal", helix, WIRE_R, 5, c("copper"))
    p.rod("flag_metal", g(0, 0.12, 0), g(0, STAFF_TOP, 0), STAFF_R, segs=8, color=c("iron_hi"))
    p.cyl("flag_metal", 0.05, 0.03, 0.08, segs=8, loc=g(0, STAFF_TOP + 0.03, 0), color=c("copper_dk"))
    for y in (HOIST_Y1 + 0.005, HOIST_Y0 - 0.005):
        ring = [(0.045 * math.cos(TAU * k / 12), y + 0.012 * math.sin(TAU * k / 12 * 2), 0.045 * math.sin(TAU * k / 12))
                for k in range(13)]
        sweep(p, "flag_metal", ring, 0.014, 5, c("copper"))
    sweep(p, "flag_metal", [(-0.04, HOIST_Y1, 0.01), (-0.07, HOIST_Y1 - 0.08, 0.03), (-0.06, HOIST_Y1 - 0.2, 0.02)],
          0.012, 5, c("copper"))
    finish(p, root)
    q = Part("FlagCloth")
    bm = q.bm
    x0 = STAFF_R + 0.01
    front, back = [], []
    for k in range(CLOTH_COLS + 1):
        x = x0 + CLOTH_W * k / CLOTH_COLS
        col = []
        for y in (HOIST_Y0, HOIST_Y1):
            col.append(bm.verts.new(g(x, y, CLOTH_T / 2)))
        front.append(col)
        col = []
        for y in (HOIST_Y0, HOIST_Y1):
            col.append(bm.verts.new(g(x, y, -CLOTH_T / 2)))
        back.append(col)
    faces = []
    for k in range(CLOTH_COLS):
        faces.append(bm.faces.new((front[k][0], front[k + 1][0], front[k + 1][1], front[k][1])))
        faces.append(bm.faces.new((back[k][1], back[k + 1][1], back[k + 1][0], back[k][0])))
        faces.append(bm.faces.new((front[k][1], front[k + 1][1], back[k + 1][1], back[k][1])))
        faces.append(bm.faces.new((back[k][0], back[k + 1][0], front[k + 1][0], front[k][0])))
    faces.append(bm.faces.new((front[0][0], front[0][1], back[0][1], back[0][0])))
    n = CLOTH_COLS
    faces.append(bm.faces.new((back[n][0], back[n][1], front[n][1], front[n][0])))
    q.paint(faces, "flag_cloth", c("sand"))
    finish(q, root, (x0, (HOIST_Y0 + HOIST_Y1) / 2, 0.0))
    return root


def check(root):
    bpy.context.view_layer.update()
    tris = common.tri_total(root)
    draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
    verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
    print("DEVICE_BUDGET keeper_flag", tris, "T", verts, "V", draws, "D")
    if tris > LIMIT_TRIS or draws > 2:
        raise SystemExit("keeper_flag budget exceeded: %d T %d D" % (tris, draws))


opts = common.args()
out_dir = opts["out"] or os.path.join(common.MODELS, "world_one")
common.reset()
flag = build()
check(flag)
common.export(flag, os.path.join(out_dir, "keeper_flag.glb"))
