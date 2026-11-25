import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part

for slot, rough, metal in [("relay_concrete", 0.95, 0.0), ("relay_metal", 0.6, 0.35), ("relay_glass", 0.2, 0.0)]:
    common.SLOTS[slot] = {"vc": True, "rough": rough, "metal": metal}
import polish
polish.enable(detail=1, bevel=0, bake_slots=("relay_concrete", "relay_metal"))

TAU = math.tau
COIL_Y = 17.0
ORB_R = 1.4
STAKE_Y = (6.0, 8.0, 10.0, 12.0)
STAKE_SWEEP = 0.5
DIAL_Y = 2.2
LIMITS = {"relay_stake_post": (3000, 4800, 9), "relay_mast": (3000, 4800, 3)}
HEX = {"copper": "b77843", "copper_dk": "8d5a32", "iron": "2b2724", "iron_hi": "3d3732", "steel": "4f4c48",
       "concrete": "8f8b82", "concrete_dk": "706c65", "bone": "d2c5a5", "glass": "6fb7a8", "lens": "9dff3c",
       "amber": "e5a044", "hazard": "d9a33a", "cable": "34312e", "verdigris": "8fa38a"}


def c(name):
    return common.srgb(HEX[name])


def g(x, y, z):
    return (x, -z, y)


def finish(p, root, origin=(0.0, 0.0, 0.0)):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin), parent=root)


def footing(p, r, h, sides=8):
    p.cyl("relay_concrete", r, r * 0.9, h, segs=sides, loc=g(0, h / 2, 0), rot=(0, 0, math.pi / sides), color=c("concrete"))
    p.cyl("relay_concrete", r * 0.9, r * 0.84, 0.08, segs=sides, loc=g(0, h + 0.04, 0), rot=(0, 0, math.pi / sides), color=c("concrete_dk"))


def coil(p, y0, y1, r):
    """Copper windings on an iron core, the arc coil's body under its glass orb."""
    p.cyl("relay_metal", r * 0.45, r * 0.45, y1 - y0, segs=8, loc=g(0, (y0 + y1) / 2, 0), color=c("iron"))
    n = 7
    for k in range(n):
        y = y0 + 0.15 + (y1 - y0 - 0.3) * k / (n - 1)
        p.ring("relay_metal", r * 0.45, r * (0.95 - 0.25 * abs(k - (n - 1) / 2) / ((n - 1) / 2)), 0.16, segs=12,
               loc=g(0, y, 0), color=c("copper") if k % 2 == 0 else c("copper_dk"))
    p.cyl("relay_metal", r * 1.05, r * 0.7, 0.3, segs=12, loc=g(0, y1 + 0.15, 0), color=c("iron_hi"))


def build_post():
    root = common.empty("RelayStakePost")
    p = Part("StakePost")
    footing(p, 1.8, 0.5)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        p.cyl("relay_metal", 0.09, 0.09, 0.3, segs=6, loc=g(1.35 * math.sin(a), 0.65, 1.35 * math.cos(a)), color=c("copper"))
    p.cyl("relay_metal", 0.75, 0.45, 13.5, segs=8, loc=g(0, 0.5 + 6.75, 0), rot=(0, 0, math.pi / 8), color=c("copper"))
    p.cyl("relay_metal", 1.0, 0.8, 0.6, segs=8, loc=g(0, 0.8, 0), rot=(0, 0, math.pi / 8), color=c("iron"))
    for y in (3.0, 5.0, 14.0):
        r = 0.75 - 0.3 * (y - 0.5) / 13.5 + 0.06
        p.cyl("relay_metal", r, r, 0.22, segs=8, loc=g(0, y, 0), rot=(0, 0, math.pi / 8), color=c("iron"))
    for y in STAKE_Y:
        r = 0.75 - 0.3 * (y - 0.5) / 13.5
        for dy in (-0.42, 0.42):
            p.ring("relay_metal", r, 1.55, 0.14, segs=8, loc=g(0, y + dy, 0), color=c("iron"))
        for k in range(4):
            a = TAU * (k + 0.5) / 4
            p.rod("relay_metal", g(1.5 * math.sin(a), y - 0.4, 1.5 * math.cos(a)), g(1.5 * math.sin(a), y + 0.4, 1.5 * math.cos(a)),
                  0.07, segs=4, color=c("copper_dk"))
    p.box("relay_metal", (1.3, 0.35, 1.3), loc=g(0, DIAL_Y, 0.82), color=c("iron"))
    p.ring("relay_metal", 0.52, 0.62, 0.1, segs=16, loc=g(0, DIAL_Y, 1.02), rot=(math.pi / 2, 0, 0), color=c("copper"))
    coil(p, 14.0, 15.4, 1.3)
    p.rod("relay_metal", g(0.0, 0.25, -1.75), g(0.0, 0.08, -4.5), 0.08, segs=5, color=c("cable"))
    finish(p, root)
    for i, y in enumerate(STAKE_Y):
        r = 0.75 - 0.3 * (y - 0.5) / 13.5
        s = Part("Stake%d" % (i + 1))
        s.ring("relay_glass", r + 0.02, 1.45, 0.66, segs=16, loc=g(0, y, 0), color=c("glass"))
        finish(s, root, (0, y, 0))
    d = Part("StakeDial")
    d.cyl("relay_glass", 0.52, 0.52, 0.04, segs=16, loc=g(0, DIAL_Y, 1.0), rot=(math.pi / 2, 0, 0), color=c("bone"))
    for k in range(5):
        a = k * STAKE_SWEEP
        x, y = 0.42 * math.sin(a), 0.42 * math.cos(a)
        d.box("relay_glass", (0.05 + 0.02 * k, 0.03, 0.12), loc=g(x, DIAL_Y + y, 1.025), rot=(0, -a, 0), color=c("iron") if k else c("hazard"))
    finish(d, root, (0, DIAL_Y, 1.0))
    n = Part("StakeNeedle")
    n.box("relay_metal", (0.06, 0.03, 0.36), loc=g(0, DIAL_Y + 0.16, 1.05), color=c("copper"))
    n.cyl("relay_metal", 0.06, 0.06, 0.05, segs=8, loc=g(0, DIAL_Y, 1.05), rot=(math.pi / 2, 0, 0), color=c("iron_hi"))
    finish(n, root, (0, DIAL_Y, 1.05))
    o = Part("CoilGlow")
    o.uv("relay_glass", ORB_R, u=12, v=8, loc=g(0, COIL_Y, 0), color=c("glass"))
    finish(o, root, (0, COIL_Y, 0))
    return root


def build_mast():
    root = common.empty("RelayMastRoot")
    p = Part("RelayMast")
    legs = []
    for k in range(3):
        a = TAU * k / 3
        foot = (2.4 * math.sin(a), 0.0, 2.4 * math.cos(a))
        p.cyl("relay_concrete", 0.6, 0.5, 0.6, segs=6, loc=g(foot[0], 0.3, foot[2]), color=c("concrete"))
        top = (0.45 * math.sin(a), 13.6, 0.45 * math.cos(a))
        legs.append((foot, top))
        p.rod("relay_metal", g(foot[0], 0.6, foot[2]), g(*top), 0.16, segs=6, r2=0.11, color=c("copper"))
    lv = [0.6 + 2.6 * j for j in range(5)] + [13.6]
    at = lambda leg, y: tuple(legs[leg][0][i] + (legs[leg][1][i] - legs[leg][0][i]) * (y - 0.6) / 13.0 if i != 1 else y for i in range(3))
    for j, y in enumerate(lv):
        for k in range(3):
            a, b = at(k, y), at((k + 1) % 3, y)
            p.rod("relay_metal", g(*a), g(*b), 0.07, segs=4, color=c("iron"))
            if j + 1 < len(lv):
                y2 = lv[j + 1]
                p.rod("relay_metal", g(*a), g(*at((k + 1) % 3, y2)), 0.05, segs=4, color=c("iron_hi"))
                p.rod("relay_metal", g(*b), g(*at(k, y2)), 0.05, segs=4, color=c("iron_hi"))
    p.cyl("relay_metal", 0.9, 0.9, 0.25, segs=6, loc=g(0, 13.7, 0), color=c("iron"))
    for k in range(5):
        y = 13.95 + 0.2 * k
        p.cyl("relay_metal", 0.42, 0.42, 0.12, segs=10, loc=g(0, y, 0), color=c("bone"))
        p.cyl("relay_metal", 0.2, 0.2, 0.1, segs=8, loc=g(0, y + 0.11, 0), color=c("iron"))
    coil(p, 14.9, 15.4, 1.4)
    for k in range(3):
        a = TAU * (k + 0.5) / 3
        q = (3.6 * math.sin(a), 0.0, 3.6 * math.cos(a))
        p.rod("relay_metal", g(q[0], -0.2, q[2]), g(q[0], 1.0, q[2]), 0.06, segs=5, color=c("copper"))
        p.uv("relay_metal", 0.12, u=6, v=4, loc=g(q[0], 1.05, q[2]), color=c("copper_dk"))
        f = legs[k][0]
        p.rod("relay_metal", g(q[0], 0.8, q[2]), g(f[0], 0.6, f[2]), 0.035, segs=4, color=c("cable"))
    finish(p, root)
    o = Part("CoilGlow")
    o.uv("relay_glass", ORB_R, u=12, v=8, loc=g(0, COIL_Y, 0), color=c("glass"))
    finish(o, root, (0, COIL_Y, 0))
    return root


def check(name, root):
    bpy.context.view_layer.update()
    tris = common.tri_total(root)
    draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
    verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
    t_cap, v_cap, d_cap = LIMITS[name]
    print("DEVICE_BUDGET", name, tris, "T", verts, "V", draws, "D")
    if tris > t_cap or draws > d_cap:
        raise SystemExit("%s budget exceeded: %d T %d D" % (name, tris, draws))


opts = common.args()
out_dir = opts["out"] or os.path.join(common.MODELS, "world_one")
for name, build in (("relay_stake_post", build_post), ("relay_mast", build_mast)):
    common.reset()
    root = build()
    check(name, root)
    common.export(root, os.path.join(out_dir, name + ".glb"))
