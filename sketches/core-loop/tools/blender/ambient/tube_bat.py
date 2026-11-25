"""The Dig tube bat (ambient life record, ambient_kinds.gd "tube_bat"; issue #149, wave 17).

A plum fuzzy ball with big round ears, a tiny cream face and soft scalloped wings (overlapping round lobes, never a
triangle or a flat shard), unlit. It HANGS upside down: the origin is the feet's grip point at the top of the model
(where the runtime puts a ceiling perch's origin) and the body hangs below it in -Y, about 0.2 m from grip to ear tips.
Faces Godot -Z. In the rest pose the wings are wrapped round the body.

Bones: root (grip point), torso (body centre; bobs and sways, carries the wings), body (ball, face, ears, feet; pitches
into the flight pose), ear_l, ear_r, wing_l, wing_r (shoulders). Wing roll about Z: 0 hangs wrapped, 90 spreads level,
130 is up-stroke, 50 is down-stroke (left wing mirrors the sign).
Clips: idle (2.8 s: slow breathing, a sleepy sway, a small ear twitch), move (1.2 s: three wingbeats, body upright-ish
head-forward, belly down), react (2.0 s: startled shiver, wings unfold, drop and tip into flight; a hovering flap holds
from 0.8 s and closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/tube_bat.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("tube_bat")
CY = -0.1

life.ellipsoid("body", "body", (0, CY, 0), (0.064, 0.066, 0.062), subsurf=1, u=10, v=6)
for cx, cy, cz in ((0.04, -0.07, 0.04), (-0.042, -0.085, 0.036), (0.0, -0.14, 0.05), (-0.036, -0.135, 0.038), (0.038, -0.13, 0.034)):
    life.ellipsoid("body", "wing", (cx, cy, cz), (0.02, 0.018, 0.018), subsurf=1, u=6, v=3)

life.ellipsoid("body", "cream", (0, -0.126, -0.05), (0.03, 0.027, 0.016), rot=(-20, 0, 0), subsurf=1, u=8, v=3)
life.ellipsoid("body", "eye", (0, -0.134, -0.064), (0.0065, 0.005, 0.005), subsurf=1, u=6, v=3)
for s in (-1, 1):
    life.ellipsoid("body", "eye", (0.019 * s, -0.117, -0.059), (0.007, 0.0075, 0.005), subsurf=1, u=6, v=4)

for s in (-1, 1):
    life.ellipsoid("body", "body", (0.014 * s, -0.027, 0.0), (0.0125, 0.026, 0.012), subsurf=1, u=6, v=3)

for s, bone in ((-1, "ear_l"), (1, "ear_r")):
    life.ellipsoid(bone, "body", (0.04 * s, -0.162, -0.018), (0.021, 0.027, 0.013), rot=(0, 0, 22 * s), subsurf=1, u=8, v=5)
    life.ellipsoid(bone, "cream", (0.04 * s, -0.163, -0.029), (0.012, 0.017, 0.005), rot=(0, 0, 22 * s), subsurf=1, u=6, v=3)

for s, bone in ((-1, "wing_l"), (1, "wing_r")):
    sx, sy = 0.058 * s, -0.075
    life.tube(bone, "body", [(sx, sy, 0.0), (sx + 0.002 * s, -0.172, -0.004)], [0.0095, 0.0075], sides=6, subsurf=1)
    for phi, length, width in ((6, 0.098, 0.03), (32, 0.088, 0.034), (58, 0.07, 0.03)):
        p = math.radians(phi)
        cy = sy - length / 2 * math.cos(p)
        cz = length / 2 * math.sin(p)
        cx = (0.066 - 0.016 * math.sin(p)) * s
        life.ellipsoid(bone, "wing", (cx, cy, cz), (0.008, length / 2 + 0.006, width), rot=(-phi, 0, 0), subsurf=1, u=6, v=3)

life.rig([
    ("root", (0, 0, 0), None),
    ("torso", (0, CY, 0), "root"),
    ("body", (0, CY, 0), "torso"),
    ("ear_l", (-0.04, -0.15, -0.018), "body"),
    ("ear_r", (0.04, -0.15, -0.018), "body"),
    ("wing_l", (-0.058, -0.075, 0), "torso"),
    ("wing_r", (0.058, -0.075, 0), "torso"),
])

REST = {}
FLY = (90, 0, 180)


def wings(angle, yaw=0.0, tuck=1.0):
    """wing_l / wing_r keys' poses for a roll of `angle` (right wing +, left mirrored)."""
    return ({"rot": (0, -yaw, -angle), "scale": (1, tuck, 1)}, {"rot": (0, yaw, angle), "scale": (1, tuck, 1)})


life.cycle("idle", 2.8, {
    "torso": [(0, REST), (0.7, {"rot": (0, 0, 2.5), "loc": (0, 0.002, 0)}), (1.4, REST),
              (2.1, {"rot": (0, 0, -2.5), "loc": (0, 0.002, 0)})],
    "body": [(0, REST), (0.7, {"scale": (1.035, 1.045, 1.035), "rot": (3, 0, 0)}), (1.4, REST),
             (2.1, {"scale": (1.035, 1.045, 1.035), "rot": (-3, 0, 0)})],
    "wing_l": [(0, REST), (0.7, {"rot": (0, 0, -2.5), "scale": (1.03, 1.0, 1.03)}), (1.4, REST),
               (2.1, {"rot": (0, 0, -1.0), "scale": (1.03, 1.0, 1.03)})],
    "wing_r": [(0, REST), (0.7, {"rot": (0, 0, 2.5), "scale": (1.03, 1.0, 1.03)}), (1.4, REST),
               (2.1, {"rot": (0, 0, 1.0), "scale": (1.03, 1.0, 1.03)})],
    "ear_l": [(0, REST), (1.7, REST), (1.85, {"rot": (0, 0, 14)}), (2.0, {"rot": (0, 0, -6)}), (2.2, REST)],
    "ear_r": [(0, REST), (0.4, {"rot": (0, 0, 4)}), (0.9, REST)],
})

up_l, up_r = wings(125, 8)
dn_l, dn_r = wings(55, -8)
flap = {"wing_l": [], "wing_r": [], "torso": [], "ear_l": [], "ear_r": []}
for i in range(6):
    t = round(i * 0.2, 4)
    a_l, a_r = (up_l, up_r) if i % 2 == 0 else (dn_l, dn_r)
    flap["wing_l"].append((t, a_l))
    flap["wing_r"].append((t, a_r))
    flap["torso"].append((t, {"loc": (0, -0.012 if i % 2 == 0 else 0.012, 0.0), "rot": (-6 if i % 2 == 0 else 6, 0, 0)}))
    flap["ear_l"].append((t, {"rot": (0, 0, 10 if i % 2 else -6)}))
    flap["ear_r"].append((t, {"rot": (0, 0, -10 if i % 2 else 6)}))
flap["body"] = [(0, {"rot": FLY}), (0.6, {"rot": (86, 0, 180)})]
life.cycle("move", 1.2, flap)

hu_l, hu_r = wings(115, 6)
hd_l, hd_r = wings(65, -6)
FLY_POSE = {"rot": FLY}
HOVER_UP = {"rot": FLY, "scale": (1, 1, 1)}
react = {
    "torso": [(0, REST), (0.06, {"rot": (0, 0, 4)}), (0.12, {"rot": (0, 0, -4)}), (0.18, {"rot": (0, 0, 3)}),
              (0.24, {"rot": (0, 0, -3)}), (0.3, REST), (0.5, {"loc": (0, -0.03, 0)}),
              (0.8, {"loc": (0, -0.012, 0), "rot": (-4, 0, 0)}), (1.1, {"loc": (0, 0.01, 0), "rot": (4, 0, 0)}),
              (1.4, {"loc": (0, -0.012, 0), "rot": (-4, 0, 0)}), (1.7, {"loc": (0, 0.01, 0), "rot": (4, 0, 0)}),
              (2.0, {"loc": (0, -0.012, 0), "rot": (-4, 0, 0)})],
    "body": [(0, REST), (0.12, {"scale": (1.07, 1.07, 1.07)}), (0.3, REST), (0.5, {"rot": (45, 0, 90)}),
             (0.8, {"rot": FLY}), (2.0, {"rot": FLY})],
    "wing_l": [(0, REST), (0.3, {"rot": (0, 0, -6)}), (0.5, wings(95, 0)[0]), (0.8, hu_l), (1.1, hd_l), (1.4, hu_l),
               (1.7, hd_l), (2.0, hu_l)],
    "wing_r": [(0, REST), (0.3, {"rot": (0, 0, 6)}), (0.5, wings(95, 0)[1]), (0.8, hu_r), (1.1, hd_r), (1.4, hu_r),
               (1.7, hd_r), (2.0, hu_r)],
    "ear_l": [(0, REST), (0.12, {"rot": (0, 0, 16)}), (0.5, {"rot": (0, 0, -10)}), (0.8, {"rot": (0, 0, 8)}),
              (1.4, {"rot": (0, 0, -6)}), (2.0, {"rot": (0, 0, 8)})],
    "ear_r": [(0, REST), (0.12, {"rot": (0, 0, -16)}), (0.5, {"rot": (0, 0, 10)}), (0.8, {"rot": (0, 0, -8)}),
              (1.4, {"rot": (0, 0, 6)}), (2.0, {"rot": (0, 0, -8)})],
}
life.oneshot("react", 2.0, react, loop_from=0.8)

from _life import args
want_stills = args()["stills"]
if want_stills:
    i = sys.argv.index("--stills")
    del sys.argv[i:i + 2]
life.finish()
if want_stills:
    life.root.location.z += life.row["height_m"]
    life.stills(want_stills)
