"""The Spillway puddle toad (ambient life record, ambient_kinds.gd "puddle_toad"; issue #149, wave 17).

A squat periwinkle dome with a wide soft mouth line and two big round eye bumps on top: the silhouette hook. Cream throat
and belly, a few soft round spots, folded legs and big soft feet. 0.24 m tall to the eye tops, facing Godot -Z, origin on
the ground. Soft toy look (chunky, bevelled, smooth); palette, height and triangle band come from the record.

Bones: root, body (spots, mouth ride it), throat (cream pulse), eye_l, eye_r (bump plus pupil), leg_l, leg_r (thigh and foot).
Clips: idle (2.4 s: throat pulse, a slow blink, a tiny weight shift), move (1.2 s: one soft hop, legs extend and tuck),
react (2.0 s: startled crouch, then a big squash that sinks into the water; hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/puddle_toad.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("puddle_toad")

BY, RX, RY, RZ = 0.08, 0.10, 0.075, 0.105

life.ellipsoid("body", "body", (0, BY, 0), (RX, RY, RZ), subsurf=1, u=14, v=9)
life.tube("body", "eye", [(-0.056, 0.097, -0.081), (-0.03, 0.087, -0.1), (0, 0.084, -0.106), (0.03, 0.087, -0.1),
                          (0.056, 0.097, -0.081)], [0.005, 0.006, 0.006, 0.006, 0.005], sides=4, subsurf=1)
life.ellipsoid("body", "cream", (0, 0.03, -0.02), (0.075, 0.03, 0.08), subsurf=1, u=6, v=4)
for x, z, r in ((0.05, 0.035, 0.032), (-0.05, 0.05, 0.028), (0.0, 0.07, 0.021)):
    k = max(0.2, 1 - (x / RX) ** 2 - (z / RZ) ** 2)
    y = BY + RY * math.sqrt(k) - 0.006
    life.ellipsoid("body", "spots", (x, y, z), (r, 0.012, r), subsurf=1, u=6, v=3)

life.ellipsoid("throat", "cream", (0, 0.058, -0.078), (0.05, 0.032, 0.034), subsurf=1, u=6, v=4)

for s, bone in ((-1, "eye_l"), (1, "eye_r")):
    life.ellipsoid(bone, "body", (0.052 * s, 0.182, -0.032), (0.044, 0.052, 0.044), subsurf=1, u=8, v=6)
    life.ellipsoid(bone, "body", (0.052 * s, 0.14, -0.03), (0.052, 0.04, 0.05), subsurf=1, u=6, v=4)
    life.ellipsoid(bone, "eye", (0.057 * s, 0.19, -0.072), (0.022, 0.025, 0.014), subsurf=1, u=6, v=4)

for s, bone in ((-1, "leg_l"), (1, "leg_r")):
    life.ellipsoid(bone, "body", (0.092 * s, 0.045, 0.035), (0.03, 0.037, 0.05), subsurf=1, u=6, v=4)
    life.ellipsoid(bone, "spots", (0.074 * s, 0.017, -0.075), (0.04, 0.02, 0.052), subsurf=1, u=7, v=4)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, BY, 0), "root"),
    ("throat", (0, 0.058, -0.078), "root"),
    ("eye_l", (-0.052, 0.182, -0.032), "root"),
    ("eye_r", (0.052, 0.182, -0.032), "root"),
    ("leg_l", (-0.085, 0.04, 0.0), "root"),
    ("leg_r", (0.085, 0.04, 0.0), "root"),
])

REST = {}

life.cycle("idle", 2.4, {
    "body": [(0, REST), (0.6, {"scale": (1.0, 1.015, 1.0), "rot": (0, 0, 1.5)}), (1.2, {"loc": (0.002, 0, 0), "rot": (0, 0, 2.5)}),
             (1.8, {"scale": (1.0, 1.015, 1.0), "rot": (0, 0, 0.5)})],
    "throat": [(0, REST), (0.3, {"scale": (1.12, 1.25, 1.12)}), (0.6, REST), (1.2, {"scale": (1.12, 1.25, 1.12)}),
               (1.5, REST), (1.8, {"scale": (1.08, 1.15, 1.08)})],
    "eye_l": [(0, REST), (0.9, REST), (1.3, {"scale": (1.04, 0.2, 1.04), "loc": (0, -0.016, 0)}), (1.7, REST)],
    "eye_r": [(0, REST), (0.9, REST), (1.3, {"scale": (1.04, 0.2, 1.04), "loc": (0, -0.016, 0)}), (1.7, REST)],
    "leg_l": [(0, REST), (1.2, {"scale": (1.0, 0.97, 1.0)})],
    "leg_r": [(0, REST), (1.2, {"scale": (1.0, 0.97, 1.0)}), (1.8, REST)],
})

HOP = 0.07
life.cycle("move", 1.2, {
    "body": [(0, REST), (0.2, {"loc": (0, -0.012, 0), "scale": (1.08, 0.85, 1.06)}),
             (0.5, {"loc": (0, HOP, 0), "rot": (-6, 0, 0), "scale": (0.95, 1.1, 0.96)}),
             (0.8, {"loc": (0, 0.02, 0), "rot": (4, 0, 0)}),
             (0.95, {"loc": (0, -0.01, 0), "scale": (1.07, 0.88, 1.05)}), (1.1, {"scale": (1.01, 0.99, 1.01)})],
    "throat": [(0, REST), (0.2, {"loc": (0, -0.01, 0), "scale": (1.08, 0.9, 1.05)}),
               (0.5, {"loc": (0, HOP, 0), "scale": (0.95, 1.1, 0.95)}), (0.8, {"loc": (0, 0.02, 0)}),
               (0.95, {"loc": (0, -0.008, 0)})],
    "eye_l": [(0, REST), (0.2, {"loc": (0, -0.02, 0), "scale": (1.0, 0.9, 1.0)}), (0.5, {"loc": (0, HOP + 0.006, 0)}),
              (0.8, {"loc": (0, 0.022, 0)}), (0.95, {"loc": (0, -0.018, 0), "scale": (1.0, 0.9, 1.0)})],
    "eye_r": [(0, REST), (0.2, {"loc": (0, -0.02, 0), "scale": (1.0, 0.9, 1.0)}), (0.5, {"loc": (0, HOP + 0.006, 0)}),
              (0.8, {"loc": (0, 0.022, 0)}), (0.95, {"loc": (0, -0.018, 0), "scale": (1.0, 0.9, 1.0)})],
    "leg_l": [(0, REST), (0.2, {"scale": (1.0, 0.8, 1.0)}), (0.5, {"loc": (0, HOP - 0.03, 0.045), "rot": (-35, 0, 0), "scale": (0.95, 1.3, 1.0)}),
              (0.8, {"loc": (0, 0.0, 0.0), "scale": (1.0, 0.75, 1.0)}), (0.95, {"scale": (1.05, 0.85, 1.0)})],
    "leg_r": [(0, REST), (0.2, {"scale": (1.0, 0.8, 1.0)}), (0.5, {"loc": (0, HOP - 0.03, 0.045), "rot": (-35, 0, 0), "scale": (0.95, 1.3, 1.0)}),
              (0.8, {"loc": (0, 0.0, 0.0), "scale": (1.0, 0.75, 1.0)}), (0.95, {"scale": (1.05, 0.85, 1.0)})],
})

START = {
    "body": {"loc": (0, 0.012, 0), "scale": (0.96, 1.08, 0.96)},
    "throat": {"loc": (0, 0.012, 0), "scale": (1.15, 1.2, 1.15)},
    "eye_l": {"loc": (0, 0.016, 0), "scale": (1.12, 1.15, 1.12)},
    "eye_r": {"loc": (0, 0.016, 0), "scale": (1.12, 1.15, 1.12)},
    "leg_l": {"scale": (1.0, 1.1, 1.0)},
    "leg_r": {"scale": (1.0, 1.1, 1.0)},
}
CROUCH = {
    "body": {"loc": (0, -0.014, 0), "scale": (1.1, 0.8, 1.08)},
    "throat": {"loc": (0, -0.012, 0), "scale": (1.1, 0.85, 1.05)},
    "eye_l": {"loc": (0, -0.03, 0), "scale": (1.0, 0.9, 1.0)},
    "eye_r": {"loc": (0, -0.03, 0), "scale": (1.0, 0.9, 1.0)},
    "leg_l": {"scale": (1.05, 0.75, 1.0)},
    "leg_r": {"scale": (1.05, 0.75, 1.0)},
}
SINK = {
    "body": {"loc": (0, -0.046, 0), "scale": (1.2, 0.45, 1.15)},
    "throat": {"loc": (0, -0.04, 0), "scale": (1.2, 0.3, 1.1)},
    "eye_l": {"loc": (0, -0.1, 0.004), "scale": (1.08, 0.7, 1.08)},
    "eye_r": {"loc": (0, -0.1, 0.004), "scale": (1.08, 0.7, 1.08)},
    "leg_l": {"loc": (0.01, -0.01, 0), "scale": (1.15, 0.3, 1.1)},
    "leg_r": {"loc": (-0.01, -0.01, 0), "scale": (1.15, 0.3, 1.1)},
}
SETTLE = {
    "body": {"loc": (0, -0.047, 0), "scale": (1.21, 0.43, 1.16)},
    "throat": {"loc": (0, -0.041, 0), "scale": (1.22, 0.27, 1.12)},
    "eye_l": {"loc": (0, -0.104, 0.004), "scale": (1.08, 0.64, 1.08)},
    "eye_r": {"loc": (0, -0.104, 0.004), "scale": (1.08, 0.64, 1.08)},
}
react = {}
for bone in SINK:
    react[bone] = [(0, REST), (0.12, START[bone]), (0.3, CROUCH[bone]), (0.6, SINK[bone]), (0.8, SINK[bone]),
                   (1.4, SETTLE.get(bone, SINK[bone])), (2.0, SINK[bone])]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
