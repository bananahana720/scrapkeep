"""The Highdraft bighorn lamb (ambient life record, ambient_kinds.gd "bighorn_lamb"; issue #149, wave 17).

A woolly lavender cloud of blended lobes on four short plum legs with round hooves, a plum face with a soft muzzle, floppy
ears, a cream tail tuft and two big curled nub horns: the silhouette hook, thick and round-ended, never pointed. About
0.7 m tall to the horn tops, facing Godot -Z, origin on the ground. Soft toy look; palette, height and triangle band come
from the record.

Bones: root, body (wool, chest bib ride it), head (face, muzzle, eyes, horns, forelock), jaw (child of head), ear_l, ear_r
(children of head), tail (child of body), leg_fl, leg_fr, leg_bl, leg_br (leg and hoof).
Clips: idle (2.8 s: chewing, an ear flick, a little weight shift; slowed it reads as sleeping curled),
move (1.2 s: two bouncy hops, all four feet springing),
react (2.0 s: startled head-up, a stiff-legged pronk, then crouched low ready to bound; hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/bighorn_lamb.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("bighorn_lamb")

HY = 0.49
HZ = -0.2

life.ellipsoid("body", "wool", (0, 0.29, 0.02), (0.17, 0.15, 0.2), subsurf=0, u=16, v=10)
for s in (-1, 1):
    life.ellipsoid("body", "wool", (0.1 * s, 0.325, -0.09), (0.11, 0.105, 0.11), subsurf=0, u=12, v=8)
    life.ellipsoid("body", "wool", (0.1 * s, 0.30, 0.15), (0.11, 0.11, 0.115), subsurf=0, u=12, v=8)
life.ellipsoid("body", "wool", (0, 0.40, 0.01), (0.115, 0.075, 0.14), subsurf=0, u=12, v=8)
life.ellipsoid("body", "wool", (0, 0.375, -0.15), (0.1, 0.1, 0.085), subsurf=0, u=12, v=8)
life.ellipsoid("body", "cream", (0, 0.25, -0.163), (0.06, 0.055, 0.04), subsurf=0, u=12, v=8)

life.ellipsoid("head", "face", (0, HY, HZ), (0.095, 0.088, 0.1), subsurf=0, u=12, v=8)
life.ellipsoid("head", "face", (0, HY - 0.032, HZ - 0.076), (0.055, 0.047, 0.06), subsurf=0, u=12, v=8)
life.ellipsoid("head", "eye", (0, HY - 0.016, HZ - 0.14), (0.02, 0.015, 0.015), subsurf=0, u=10, v=7)
life.ellipsoid("jaw", "face", (0, HY - 0.064, HZ - 0.07), (0.04, 0.025, 0.05), subsurf=0, u=12, v=8)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.07 * s, HY + 0.018, HZ - 0.066), (0.026, 0.031, 0.02), rot=(0, 0, 0), subsurf=0, u=12, v=8)
    life.ellipsoid("head", "cream", (0.077 * s, HY + 0.028, HZ - 0.082), (0.009, 0.01, 0.006), subsurf=0, u=8, v=5)
    cx, cy = 0.125 * s, HY + 0.09
    pts, rad = [], []
    angles = [200, 165, 130, 95, 60, 25, -10, -45, -80, -115, -145]
    for i, a in enumerate(angles):
        r = 0.06 - 0.0032 * i
        pts.append((cx + r * math.cos(math.radians(a)) * s * 1.0, cy + r * math.sin(math.radians(a)) * 1.0, HZ + 0.015 - 0.0045 * i))
        rad.append(0.037 - 0.0012 * i)
    life.tube("head", "horn", pts, rad, sides=8, subsurf=0, cap=0.9)

for s, bone in ((-1, "ear_l"), (1, "ear_r")):
    life.ellipsoid(bone, "face", (0.115 * s, HY - 0.015, HZ + 0.035), (0.022, 0.06, 0.036), rot=(0, 0, -14 * s), subsurf=0, u=12, v=8)
life.ellipsoid("head", "wool", (0, HY + 0.085, HZ - 0.015), (0.06, 0.042, 0.065), subsurf=0, u=12, v=8)

life.ellipsoid("tail", "cream", (0, 0.31, 0.225), (0.038, 0.042, 0.034), subsurf=0, u=12, v=8)

LEGS = {"leg_fl": (-0.085, -0.1), "leg_fr": (0.085, -0.1), "leg_bl": (-0.095, 0.13), "leg_br": (0.095, 0.13)}
for bone, (x, z) in LEGS.items():
    life.capsule(bone, "face", (x, 0.24, z), (x, 0.05, z), 0.048, 0.04, subsurf=0, u=10, v=7)
    life.ellipsoid(bone, "horn", (x, 0.03, z - 0.008), (0.044, 0.032, 0.054), subsurf=0, u=12, v=8)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.29, 0.02), "root"),
    ("head", (0, 0.46, -0.17), "body"),
    ("jaw", (0, HY - 0.05, HZ - 0.04), "head"),
    ("ear_l", (-0.09, HY + 0.03, HZ + 0.035), "head"),
    ("ear_r", (0.09, HY + 0.03, HZ + 0.035), "head"),
    ("tail", (0, 0.32, 0.2), "body"),
    ("leg_fl", (-0.085, 0.24, -0.1), "root"),
    ("leg_fr", (0.085, 0.24, -0.1), "root"),
    ("leg_bl", (-0.095, 0.24, 0.13), "root"),
    ("leg_br", (0.095, 0.24, 0.13), "root"),
])

REST = {}
LEGS_ = list(LEGS)
EARS = ("ear_l", "ear_r")

chew = []
for i in range(8):
    chew.append((i * 0.35, {"rot": (-13 if i % 2 else 0, 0, 0)}))
life.cycle("idle", 2.8, {
    "body": [(0, REST), (0.7, {"scale": (1.012, 1.02, 1.012), "loc": (0.004, 0, 0), "rot": (0, 0, 1.2)}),
             (1.4, {"loc": (0.007, -0.004, 0), "rot": (0, 0, 2.2)}),
             (2.1, {"scale": (1.012, 1.02, 1.012), "loc": (0.002, 0, 0), "rot": (0, 0, 0.8)})],
    "head": [(0, REST), (0.7, {"rot": (-3, 0, 1.5), "loc": (0, -0.003, 0)}), (1.4, {"rot": (1, 0, 3)}),
             (2.1, {"rot": (-3, 0, -1.5), "loc": (0, -0.003, 0)})],
    "jaw": chew,
    "ear_l": [(0, REST), (0.9, REST), (1.05, {"rot": (0, 0, -32)}), (1.2, {"rot": (0, 0, -4)}), (1.35, {"rot": (0, 0, -26)}),
              (1.6, REST), (2.1, {"rot": (0, 0, -3)})],
    "ear_r": [(0, REST), (0.7, {"rot": (0, 0, 3)}), (1.4, {"rot": (0, 0, 1)}), (2.1, {"rot": (0, 0, 4)})],
    "tail": [(0, REST), (0.7, {"rot": (0, 0, 6)}), (1.4, REST), (2.1, {"rot": (0, 0, -6)})],
    "leg_bl": [(0, REST), (1.4, {"scale": (1, 0.985, 1)})],
    "leg_br": [(0, REST), (0.7, {"scale": (1, 0.985, 1)}), (1.4, REST)],
})

UP = 0.075
def hop(t0):
    k = {"body": [], "head": [], "tail": [], "ear_l": [], "ear_r": []}
    for bone in LEGS_:
        k[bone] = []
    frames = [
        (0.0, -0.014, 0.0, 0.92, 4, {"f": (-10, 0.93), "b": (12, 0.93)}, 2),
        (0.14, UP * 0.7, UP * 0.7 + 0.025, 1.0, -7, {"f": (-24, 1.05), "b": (-34, 1.08)}, 6),
        (0.3, UP, UP + 0.03, 1.0, -1, {"f": (28, 0.78), "b": (-12, 0.78)}, 8),
        (0.45, UP * 0.55, UP * 0.55 + 0.012, 1.0, 6, {"f": (30, 0.95), "b": (22, 0.92)}, 4),
    ]
    for (t, by, ly, sy, pitch, legpose, ear) in frames:
        t = t0 + t
        k["body"].append((t, {"loc": (0, by, 0), "rot": (pitch, 0, 0), "scale": (1 + (1 - sy) * 0.4, sy if sy < 1 else 1.0, 1 + (1 - sy) * 0.4)}))
        k["head"].append((t, {"rot": (-pitch * 1.4, 0, 0)}))
        k["tail"].append((t, {"rot": (pitch * -2 + 8, 0, 0)}))
        k["ear_l"].append((t, {"rot": (0, 0, -ear * 2.5)}))
        k["ear_r"].append((t, {"rot": (0, 0, ear * 2.5)}))
        for bone in LEGS_:
            rot, sc = legpose["f" if bone.startswith("leg_f") else "b"]
            k[bone].append((t, {"loc": (0, ly, 0), "rot": (rot, 0, 0), "scale": (1, sc, 1)}))
    return k
a, b = hop(0.0), hop(0.6)
move = {bone: a[bone] + b[bone] for bone in a}
life.cycle("move", 1.2, move)

START = {
    "body": {"loc": (0, 0.014, 0), "rot": (-3, 0, 0), "scale": (0.98, 1.05, 0.98)},
    "head": {"rot": (24, 0, 0), "loc": (0, 0.012, 0.004)},
    "jaw": {"rot": (-4, 0, 0)},
    "ear_l": {"rot": (0, 0, 20)},
    "ear_r": {"rot": (0, 0, -20)},
    "tail": {"rot": (-18, 0, 0)},
    **{b: {"loc": (0, 0.014, 0), "scale": (1.0, 1.05, 1.0)} for b in LEGS_},
}
PRONK = {
    "body": {"loc": (0, 0.1, 0), "rot": (5, 0, 0), "scale": (0.98, 1.04, 0.98)},
    "head": {"rot": (14, 0, 0), "loc": (0, 0.01, 0)},
    "jaw": {"rot": (-6, 0, 0)},
    "ear_l": {"rot": (0, 0, 28)},
    "ear_r": {"rot": (0, 0, -28)},
    "tail": {"rot": (-26, 0, 0)},
    "leg_fl": {"loc": (0, 0.11, 0), "rot": (22, 0, 0), "scale": (1.0, 1.05, 1.0)},
    "leg_fr": {"loc": (0, 0.11, 0), "rot": (22, 0, 0), "scale": (1.0, 1.05, 1.0)},
    "leg_bl": {"loc": (0, 0.11, 0), "rot": (-18, 0, 0), "scale": (1.0, 1.05, 1.0)},
    "leg_br": {"loc": (0, 0.11, 0), "rot": (-18, 0, 0), "scale": (1.0, 1.05, 1.0)},
}
LAND = {
    "body": {"loc": (0, -0.045, 0), "rot": (-6, 0, 0), "scale": (1.08, 0.88, 1.06)},
    "head": {"rot": (8, 0, 0)},
    "jaw": REST,
    "ear_l": {"rot": (0, 0, 8)},
    "ear_r": {"rot": (0, 0, -8)},
    "tail": {"rot": (-8, 0, 0)},
    **{b: {"loc": (0, -0.045, 0), "scale": (1.04, 0.82, 1.04)} for b in LEGS_},
}
CROUCH = {
    "body": {"loc": (0, -0.08, 0), "rot": (-4, 0, 0), "scale": (1.12, 0.84, 1.08)},
    "head": {"rot": (14, 0, 0), "loc": (0, -0.012, -0.004)},
    "jaw": REST,
    "ear_l": {"rot": (0, 0, 14)},
    "ear_r": {"rot": (0, 0, -14)},
    "tail": {"rot": (-4, 0, 0)},
    **{b: {"loc": (0, -0.08, 0), "scale": (1.06, 0.67, 1.06)} for b in LEGS_},
}
BREATH = {
    "body": {"loc": (0, -0.08, 0), "rot": (-4, 0, 0), "scale": (1.125, 0.86, 1.085)},
    "head": {"rot": (16, 0, 0), "loc": (0, -0.012, -0.004)},
    "ear_l": {"rot": (0, 0, 17)},
    "ear_r": {"rot": (0, 0, -17)},
}
react = {}
for bone in CROUCH:
    react[bone] = [(0, REST), (0.18, START[bone]), (0.36, PRONK[bone]), (0.6, LAND[bone]), (0.8, CROUCH[bone]),
                   (1.4, BREATH.get(bone, CROUCH[bone])), (2.0, CROUCH[bone])]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
