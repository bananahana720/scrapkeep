"""The Highdraft net-weaver (ambient life record, ambient_kinds.gd "net_weaver"; issue #149, wave 17).

A round chubby ringtail in a lilac smock and plum sash, a civilian at rest: sitting cross-legged on the ground and
weaving a small round hand-net in its lap. Big head, big round ears, huge friendly eyes inside a cream eye-ring mask
painted on the head mesh, and a long fluffy tail curling round beside it with soft horizontal plum and lilac rings, two close tones so they read as fur and never as hazard stripes (vertex
colour regions on swept tubes, perpendicular to the tail's length). No posts, no net held up. Soft toy look; palette,
height and triangle band come from the record. About 0.95 m tall seated, facing Godot -Z, origin at the ground.

Bones: root (legs), body (torso, sash), head (face, ears), arm_l, arm_r, net (children of body), tail (child of root),
tail_tip (child of tail).
Clips: idle (2.5 s: weaving paws, head bob, tail sway; slowed it reads as dozing), move (1.8 s: a friendly wave with one
paw and the tail tip; locals do not walk, the runtime uses it as the greeting), react (2.0 s: startled, then curled into
a ball wrapped in its own tail like a hammock; a hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/net_weaver.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector
from _life import Critter, _B, _m

life = Critter("net_weaver")
FUR = "rings"


def banded_tube(bone, points, radii, first_light=False, sides=6, run=2, start=0):
    """A swept tube whose quad rings alternate plum and smock lilac, `run` segments each: bands are perpendicular to the
    length. Two close tones, not plum and cream: a high-contrast band reads as a stripe (AMBIENT-LIFE.md rule 1)."""
    p = life.part(bone)
    before = len(p.bm.faces)
    life.tube(bone, FUR, points, radii, sides=sides, subsurf=1, cap=0.9)
    p.bm.faces.ensure_lookup_table()
    faces = list(p.bm.faces)[before:]
    segs = len(points) - 1
    body, caps = faces[:segs * sides], faces[segs * sides:]
    for i in range(segs):
        light = ((i + start) // run) % 2 == (0 if first_light else 1)
        p.paint(body[i * sides:(i + 1) * sides], "critter", life.col("smock" if light else FUR))
    p.paint(caps[:sides], "critter", life.col(FUR))
    return p


life.ellipsoid("root", "smock", (0, 0.13, 0.0), (0.27, 0.13, 0.24), subsurf=0, u=9, v=5)
life.capsule("root", FUR, (0.2, 0.1, 0.0), (-0.1, 0.09, -0.24), 0.085, 0.075, subsurf=0, u=6, v=4)
life.capsule("root", FUR, (-0.2, 0.1, 0.0), (0.1, 0.095, -0.24), 0.085, 0.075, subsurf=0, u=6, v=4)
life.ellipsoid("root", FUR, (-0.14, 0.085, -0.27), (0.075, 0.065, 0.09), subsurf=0, u=8, v=5)
life.ellipsoid("root", FUR, (0.14, 0.09, -0.27), (0.075, 0.065, 0.09), subsurf=0, u=8, v=5)

life.ellipsoid("body", "smock", (0, 0.36, 0.0), (0.27, 0.25, 0.25), subsurf=1, u=9, v=5)
life.ellipsoid("body", "sash", (0, 0.27, 0.0), (0.285, 0.055, 0.265), subsurf=1, u=10, v=3)
life.ellipsoid("body", "sash", (0, 0.27, -0.27), (0.07, 0.06, 0.05), subsurf=0, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("body", "sash", (0.06 * s, 0.22, -0.28), (0.04, 0.08, 0.035), rot=(0, 0, -14 * s), subsurf=0, u=6, v=4)

HC, HR = Vector((0, 0.72, -0.03)), (0.225, 0.2, 0.205)
hp = life.part("head")
with hp.region(bevel=0, subsurf=1, detail=1):
    r = bmesh.ops.create_uvsphere(hp.bm, u_segments=14, v_segments=10, radius=1.0, matrix=_B @ _m(tuple(HC), (0, 0, 0), HR))
    hp.bm.verts.index_update()
    hp.bm.faces.index_update()
    faces = sorted({f for v in r["verts"] for f in v.link_faces}, key=lambda f: f.index)
    mask = []
    for f in faces:
        c = f.calc_center_median()
        gx, gy, gz = (c.x - HC.x) / HR[0], (c.z - HC.y) / HR[1], (c.y + HC.z) / HR[2]
        if gz < 0.35:
            continue
        ring = ((abs(gx) - 0.43) / 0.36) ** 2 + ((gy - 0.1) / 0.47) ** 2 <= 1.0
        muzzle = abs(gx) < 0.2 and -0.6 < gy < -0.35
        if ring or muzzle:
            mask.append(f)
    hp.paint(faces, "critter", life.col(FUR))
    hp.paint(mask, "critter", life.col("cream"))
life.ellipsoid("head", "eye", (0, 0.665, -0.232), (0.034, 0.025, 0.022), subsurf=0, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.095 * s, 0.74, -0.19), (0.056, 0.07, 0.034), rot=(0, -8 * s, 0), subsurf=1, u=6, v=3)
    life.ellipsoid("head", "cream", (0.078 * s, 0.77, -0.218), (0.022, 0.025, 0.012), subsurf=0, u=6, v=4)
    life.ellipsoid("head", FUR, (0.15 * s, 0.9, -0.02), (0.095, 0.095, 0.045), rot=(0, 18 * s, 0), subsurf=1, u=6, v=3)
    life.ellipsoid("head", "net", (0.153 * s, 0.9, -0.05), (0.06, 0.062, 0.02), rot=(0, 18 * s, 0), subsurf=0, u=6, v=4)

for s, bone in ((-1, "arm_l"), (1, "arm_r")):
    life.capsule(bone, "smock", (0.24 * s, 0.52, -0.02), (0.17 * s, 0.33, -0.2), 0.08, 0.07, subsurf=1, u=8, v=5)
    life.ellipsoid(bone, FUR, (0.15 * s, 0.31, -0.25), (0.06, 0.05, 0.06), subsurf=1, u=6, v=4)

NC = Vector((0, 0.25, -0.31))
life.ellipsoid("net", "net", tuple(NC), (0.17, 0.045, 0.17), rot=(-8, 0, 0), subsurf=1, u=10, v=4)
ring = [(NC.x + 0.165 * math.cos(math.tau * i / 6), NC.y + 0.03,
         NC.z + 0.165 * math.sin(math.tau * i / 6)) for i in range(7)]
life.tube("net", "sash", ring[:-1] + [ring[0]], [0.024] * 7, sides=5, subsurf=1, cap=0.6)
for a in (0, 60, 120):
    t = math.radians(a)
    c, s_ = math.cos(t), math.sin(t)
    life.tube("net", "sash", [(NC.x + c * q, NC.y + 0.04, NC.z + s_ * q) for q in (-0.15, 0, 0.15)],
              [0.017, 0.02, 0.017], sides=5, subsurf=1, cap=0.6)

TAIL = [(0.12, 0.16, 0.22), (0.24, 0.15, 0.27), (0.38, 0.14, 0.24), (0.5, 0.13, 0.14), (0.55, 0.13, 0.0),
        (0.54, 0.13, -0.14), (0.48, 0.14, -0.27), (0.4, 0.15, -0.37)]
TR = [0.07, 0.09, 0.105, 0.115, 0.115, 0.11, 0.1, 0.09]
TIP = [(0.4, 0.15, -0.37), (0.47, 0.19, -0.46), (0.53, 0.28, -0.5), (0.54, 0.4, -0.48), (0.5, 0.5, -0.43), (0.45, 0.56, -0.38)]
TIPR = [0.09, 0.09, 0.085, 0.078, 0.065, 0.045]


def dense(points, radii, n):
    """Resample a polyline with Catmull-Rom into n points so bands are narrow and even."""
    out, rr = [], []
    P = [Vector(q) for q in points]
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
            rr.append(radii[i] + (radii[i + 1] - radii[i]) * t)
    out.append(P[-1])
    rr.append(radii[-1])
    return [tuple(q) for q in out], rr


tp, tr = dense(TAIL, TR, 2)
banded_tube("tail", tp, tr, first_light=False, run=2)
ip, ir = dense(TIP, TIPR, 2)
banded_tube("tail_tip", ip, ir, first_light=False, run=2, start=len(tp) - 1)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.2, 0.0), "root"),
    ("head", (0, 0.56, -0.02), "body"),
    ("arm_l", (-0.24, 0.5, -0.02), "body"),
    ("arm_r", (0.24, 0.5, -0.02), "body"),
    ("net", (0, 0.24, -0.31), "body"),
    ("tail", (0.12, 0.16, 0.22), "root"),
    ("tail_tip", (0.4, 0.15, -0.37), "tail"),
])

REST = {}

life.cycle("idle", 2.5, {
    "body": [(0, REST), (0.6, {"scale": (1, 1.025, 1)}), (1.25, REST), (1.85, {"scale": (1, 1.025, 1)})],
    "head": [(0, REST), (0.5, {"rot": (6, 0, 0)}), (1.0, {"rot": (2, 0, 4), "loc": (0, -0.004, 0)}),
             (1.5, {"rot": (7, 0, -3)}), (2.0, {"rot": (3, 0, 1)})],
    "arm_l": [(0, REST), (0.3, {"rot": (7, 0, 0), "loc": (0, 0.006, -0.01)}), (0.6, {"rot": (-3, 0, 2)}),
              (1.25, {"rot": (6, 0, 0), "loc": (0, 0.006, -0.01)}), (1.55, {"rot": (-3, 0, -2)}), (1.9, REST)],
    "arm_r": [(0, REST), (0.45, {"rot": (-4, 0, 0)}), (0.8, {"rot": (7, 0, -2), "loc": (0, 0.006, -0.01)}),
              (1.5, {"rot": (-4, 0, 2)}), (1.85, {"rot": (7, 0, 0), "loc": (0, 0.006, -0.01)}), (2.2, REST)],
    "net": [(0, REST), (0.6, {"rot": (2, 0, 3)}), (1.25, {"rot": (-1, 0, -3)}), (1.85, {"rot": (2, 0, 2)})],
    "tail": [(0, REST), (0.8, {"rot": (0, 7, 0)}), (1.6, {"rot": (0, -5, 0)})],
    "tail_tip": [(0, REST), (0.6, {"rot": (0, 10, 4)}), (1.3, {"rot": (0, -12, -4)}), (1.9, {"rot": (0, 6, 2)})],
})

UP = -150
life.cycle("move", 1.8, {
    "arm_r": [(0, REST), (0.35, {"rot": (UP, 0, 0), "loc": (0, 0.0, 0)}), (0.6, {"rot": (UP, 0, 22)}), (0.85, {"rot": (UP, 0, -12)}),
              (1.1, {"rot": (UP, 0, 22)}), (1.35, {"rot": (UP, 0, -12)}), (1.55, {"rot": (UP * 0.6, 0, 0)})],
    "arm_l": [(0, REST), (0.7, {"rot": (6, 0, 0)}), (1.2, {"rot": (-3, 0, 0)})],
    "body": [(0, REST), (0.6, {"rot": (0, 0, -3), "scale": (1, 1.02, 1)}), (1.2, {"rot": (0, 0, 3)})],
    "head": [(0, REST), (0.35, {"rot": (-6, 0, 7)}), (1.0, {"rot": (-3, 0, -6)}), (1.5, {"rot": (-5, 0, 5)})],
    "net": [(0, REST), (0.7, {"rot": (3, 0, 2)}), (1.2, {"rot": (-2, 0, -2)})],
    "tail": [(0, REST), (0.7, {"rot": (0, 5, 0)}), (1.2, {"rot": (0, -4, 0)})],
    "tail_tip": [(0, REST), (0.3, {"rot": (-8, 0, 0)}), (0.55, {"rot": (-8, 0, 18)}), (0.8, {"rot": (-8, 0, -18)}),
                 (1.05, {"rot": (-8, 0, 18)}), (1.3, {"rot": (-8, 0, -18)}), (1.55, {"rot": (-4, 0, 0)})],
})

CURL = {
    "body": {"loc": (0, -0.07, 0.0), "rot": (-34, 0, 0), "scale": (1.1, 0.88, 1.1)},
    "head": {"loc": (0, -0.02, -0.03), "rot": (-38, 0, 0)},
    "arm_l": {"loc": (0.03, -0.02, -0.02), "rot": (-10, 0, 14)},
    "arm_r": {"loc": (-0.03, -0.02, -0.02), "rot": (-10, 0, -14)},
    "net": {"loc": (0, -0.06, 0.0), "rot": (-20, 0, 0), "scale": 0.8},
    "tail": {"rot": (0, 40, 0)},
    "tail_tip": {"rot": (0, 80, 0)},
}
BREATH = {"body": {"loc": (0, -0.07, 0.0), "rot": (-34, 0, 0), "scale": (1.12, 0.9, 1.12)}}
START = {
    "body": {"scale": (1, 1.05, 1), "loc": (0, 0.02, 0)},
    "head": {"rot": (10, 0, 0), "loc": (0, 0.02, 0)},
    "arm_l": {"rot": (-30, 0, 6)},
    "arm_r": {"rot": (-30, 0, -6)},
    "net": {"rot": (-6, 0, 0)},
    "tail": {"rot": (0, -8, 0)},
    "tail_tip": {"rot": (-30, 0, 0)},
}
react = {}
for bone, curled in CURL.items():
    react[bone] = [(0, REST), (0.12, START[bone]), (0.55, curled), (0.8, curled), (1.4, BREATH.get(bone, curled)), (2.0, curled)]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
