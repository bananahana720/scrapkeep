"""The dam-era weir-keeper (ambient life record, ambient_kinds.gd "weir_keeper"; issue #149, wave 17).

A pear-shaped beaver in lilac overalls and a wide floppy hat, sitting on an upturned bucket and fishing with a short rod
whose line hangs down toward a pool. A plain civilian: seated, relaxed, rod pointed down and forward, nothing held as a
weapon. About 1.05 m tall seated, facing Godot -Z, origin at the bucket's ground contact. Soft toy look.

Bones: root (bucket, legs), body, head (face, teeth, eyes), hat (child of head), tail (child of body), arm_r (rod arm),
rod (child of arm_r: rod, line and bead), arm_l (the waving paw).
Clips: idle (2.5 s: breathing, rod bob, a slow head tilt toward a doze), move (1.8 s: a friendly wave, the runtime's
greeting), react (2.0 s: startled straighten, hat pulled down, hunch low behind the bucket; a hold from 0.8 s that closes
on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/weir_keeper.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("weir_keeper")

life.tube("root", "hat", [(0, 0.03, 0), (0, 0.14, 0), (0, 0.27, 0)], [0.26, 0.215, 0.215], sides=8, subsurf=1, cap=0.4)
life.tube("root", "bucket", [(0, 0.255, 0), (0, 0.295, 0)], [0.23, 0.23], sides=8, subsurf=1, cap=0.5)

for s in (-1, 1):
    life.capsule("root", "overalls", (0.11 * s, 0.34, -0.06), (0.115 * s, 0.1, -0.22), 0.085, 0.07, subsurf=1, u=6, v=4)
    life.ellipsoid("root", "tail", (0.115 * s, 0.06, -0.26), (0.08, 0.06, 0.11), subsurf=1, u=6, v=4)

life.ellipsoid("body", "overalls", (0, 0.42, 0.0), (0.23, 0.14, 0.215), subsurf=1, u=9, v=5)
life.ellipsoid("body", "overalls", (0, 0.5, -0.01), (0.165, 0.11, 0.15), subsurf=1, u=8, v=4)
life.ellipsoid("body", "bucket", (0, 0.45, -0.17), (0.08, 0.06, 0.03), subsurf=1, u=6, v=4)
for s in (-1, 1):
    life.tube("body", "hat", [(0.07 * s, 0.57, -0.08), (0.085 * s, 0.5, -0.15), (0.085 * s, 0.46, -0.16)],
              [0.016, 0.016, 0.016], sides=4, subsurf=1)

life.ellipsoid("tail", "tail", (0, 0.22, 0.38), (0.13, 0.032, 0.2), rot=(18, 0, 0), subsurf=1, u=8, v=4)

life.ellipsoid("head", "cream", (0, 0.72, -0.015), (0.2, 0.17, 0.18), subsurf=1, u=10, v=5)
life.ellipsoid("head", "cream", (0, 0.675, -0.17), (0.085, 0.06, 0.06), subsurf=1, u=6, v=4)
life.ellipsoid("head", "eye", (0, 0.7, -0.225), (0.038, 0.028, 0.026), subsurf=1, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "cream", (0.125 * s, 0.655, -0.1), (0.085, 0.075, 0.08), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "cream", (0.02 * s, 0.615, -0.205), (0.02, 0.032, 0.014), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "eye", (0.085 * s, 0.745, -0.15), (0.024, 0.028, 0.016), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "tail", (0.195 * s, 0.8, 0.0), (0.055, 0.055, 0.03), rot=(0, 20 * s, 0), subsurf=1, u=6, v=4)

life.ellipsoid("hat", "hat", (0, 0.89, -0.01), (0.3, 0.03, 0.3), subsurf=1, u=9, v=4)
life.ellipsoid("hat", "hat", (0, 0.96, 0.0), (0.17, 0.1, 0.17), subsurf=1, u=8, v=4)
life.ellipsoid("hat", "tail", (0, 0.925, 0.0), (0.178, 0.022, 0.178), subsurf=1, u=8, v=4)

life.capsule("arm_r", "bucket", (0.2, 0.55, -0.02), (0.17, 0.43, -0.17), 0.06, 0.055, subsurf=1, u=6, v=4)
life.ellipsoid("arm_r", "cream", (0.17, 0.425, -0.19), (0.06, 0.055, 0.06), subsurf=1, u=6, v=4)
life.tube("rod", "hat", [(0.16, 0.44, -0.14), (0.19, 0.33, -0.36), (0.22, 0.2, -0.58)], [0.013, 0.01, 0.008], sides=4, subsurf=1)
life.tube("rod", "eye", [(0.22, 0.195, -0.58), (0.22, 0.03, -0.58)], [0.004, 0.004], sides=3, subsurf=0, cap=0.5)
life.capsule("arm_l", "bucket", (-0.2, 0.55, -0.02), (-0.22, 0.44, -0.17), 0.06, 0.055, subsurf=1, u=6, v=4)
life.ellipsoid("arm_l", "cream", (-0.22, 0.435, -0.19), (0.062, 0.06, 0.065), subsurf=1, u=6, v=4)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.35, 0.0), "root"),
    ("head", (0, 0.58, -0.02), "body"),
    ("hat", (0, 0.86, 0.0), "head"),
    ("tail", (0, 0.32, 0.2), "body"),
    ("arm_r", (0.2, 0.55, -0.02), "body"),
    ("rod", (0.17, 0.43, -0.18), "arm_r"),
    ("arm_l", (-0.2, 0.55, -0.02), "body"),
])

REST = {}

life.cycle("idle", 2.5, {
    "body": [(0, REST), (0.6, {"scale": (1, 1.025, 1)}), (1.25, REST), (1.85, {"scale": (1, 1.025, 1)})],
    "head": [(0, REST), (0.7, {"rot": (4, 0, 0)}), (1.2, {"rot": (9, 0, 9), "loc": (0, -0.006, 0)}),
             (1.8, {"rot": (10, 0, 9), "loc": (0, -0.006, 0)}), (2.2, {"rot": (3, 0, 2)})],
    "hat": [(0, REST), (1.2, {"rot": (3, 0, 0)}), (1.8, {"rot": (3, 0, 0)})],
    "rod": [(0, REST), (0.45, {"rot": (5, 0, 0)}), (0.9, {"rot": (-2, 0, 1)}), (1.5, {"rot": (6, 0, -1)}), (2.0, {"rot": (-1, 0, 0)})],
    "arm_r": [(0, REST), (0.6, {"rot": (2, 0, 0)}), (1.25, REST), (1.85, {"rot": (2, 0, 0)})],
    "tail": [(0, REST), (1.0, {"rot": (-4, 0, 0)}), (1.8, {"rot": (2, 0, 0)})],
})

UP = 75
life.cycle("move", 1.8, {
    "arm_l": [(0, REST), (0.35, {"rot": (UP, 0, 0)}), (0.6, {"rot": (UP, 0, 20)}), (0.85, {"rot": (UP, 0, -20)}),
              (1.1, {"rot": (UP, 0, 20)}), (1.35, {"rot": (UP, 0, -20)}), (1.5, {"rot": (UP, 0, 0)})],
    "body": [(0, REST), (0.6, {"rot": (0, 0, -3), "scale": (1, 1.02, 1)}), (1.2, {"rot": (0, 0, 3)})],
    "head": [(0, REST), (0.35, {"rot": (-5, 0, 6)}), (1.0, {"rot": (-3, 0, -5)}), (1.5, {"rot": (-4, 0, 4)})],
    "hat": [(0, REST), (0.6, {"rot": (0, 0, 4)}), (1.2, {"rot": (0, 0, -4)})],
    "rod": [(0, REST), (0.9, {"rot": (4, 0, 0)})],
    "tail": [(0, REST), (0.7, {"rot": (0, 0, 8)}), (1.1, {"rot": (0, 0, -8)})],
})

HUNCH = {
    "body": {"loc": (0, -0.1, 0.09), "rot": (-14, 0, 0), "scale": (1.05, 0.88, 1.05)},
    "head": {"loc": (0, -0.04, 0.0), "rot": (-24, 0, 0)},
    "hat": {"loc": (0, -0.1, -0.03), "rot": (-22, 0, 0)},
    "tail": {"loc": (0, 0, 0.02), "rot": (12, 0, 0)},
    "arm_r": {"rot": (-8, 0, 0), "loc": (0, 0, 0.03)},
    "rod": {"rot": (14, 0, 0)},
    "arm_l": {"rot": (-12, 0, 0), "loc": (0, 0, 0.03)},
}
BREATH = {"body": {"loc": (0, -0.1, 0.09), "rot": (-14, 0, 0), "scale": (1.06, 0.895, 1.06)}}
START = {
    "body": {"scale": (1, 1.05, 1), "loc": (0, 0.02, 0)},
    "head": {"rot": (10, 0, 0), "loc": (0, 0.02, 0)},
    "hat": {"loc": (0, 0.04, 0.01), "rot": (8, 0, 0)},
    "tail": {"rot": (-14, 0, 0)},
    "arm_r": {"rot": (6, 0, 0)},
    "rod": {"rot": (-10, 0, 0)},
    "arm_l": {"rot": (10, 0, 6)},
}
react = {}
for bone, ducked in HUNCH.items():
    react[bone] = [(0, REST), (0.12, START[bone]), (0.55, ducked), (0.8, ducked), (1.4, BREATH.get(bone, ducked)), (2.0, ducked)]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
