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
from _life import Critter  # noqa: E402

life = Critter("weir_keeper")

# --- bucket: a soft rounded cylinder, same mesh
life.tube("root", "bucket", [(0, 0.04, 0), (0, 0.27, 0)], [0.185, 0.2], sides=8, subsurf=1, cap=0.45)

# --- legs and feet, resting forward of the bucket
for s in (-1, 1):
    life.capsule("root", "overalls", (0.1 * s, 0.34, -0.06), (0.105 * s, 0.1, -0.22), 0.07, 0.06, subsurf=1, u=6, v=4)
    life.ellipsoid("root", "tail", (0.105 * s, 0.04, -0.27), (0.058, 0.04, 0.1), subsurf=1, u=6, v=4)

# --- body: a pear, wide at the seat
life.ellipsoid("body", "overalls", (0, 0.45, 0.0), (0.2, 0.17, 0.19), subsurf=1, u=9, v=5)
life.ellipsoid("body", "overalls", (0, 0.55, -0.01), (0.15, 0.13, 0.14), subsurf=1, u=9, v=5)
life.ellipsoid("body", "overalls", (0, 0.655, -0.03), (0.095, 0.05, 0.085), subsurf=1, u=6, v=4)
life.ellipsoid("body", "bucket", (0, 0.5, -0.135), (0.075, 0.06, 0.03), subsurf=1, u=6, v=4)  # bib pocket
for s in (-1, 1):
    life.tube("body", "hat", [(0.065 * s, 0.665, -0.07), (0.075 * s, 0.58, -0.145), (0.075 * s, 0.53, -0.15)],
              [0.016, 0.016, 0.016], sides=5, subsurf=1)

# --- tail: a broad flat paddle drooping behind the bucket, round-ended
life.ellipsoid("tail", "tail", (0, 0.22, 0.35), (0.115, 0.032, 0.2), rot=(18, 0, 0), subsurf=1, u=9, v=5)

# --- head: round, with muzzle, nose, two buck teeth, eyes
life.ellipsoid("head", "cream", (0, 0.8, -0.015), (0.135, 0.12, 0.125), subsurf=1, u=9, v=5)
life.ellipsoid("head", "cream", (0, 0.765, -0.115), (0.065, 0.05, 0.05), subsurf=1, u=6, v=4)
life.ellipsoid("head", "eye", (0, 0.785, -0.16), (0.02, 0.014, 0.014), subsurf=1, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "cream", (0.014 * s, 0.725, -0.15), (0.014, 0.024, 0.01), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "eye", (0.058 * s, 0.82, -0.105), (0.017, 0.02, 0.012), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "tail", (0.115 * s, 0.88, 0.0), (0.04, 0.04, 0.025), subsurf=1, u=6, v=4)  # ears

# --- hat: wide floppy brim, rounded crown, band
life.ellipsoid("hat", "hat", (0, 0.9, -0.01), (0.25, 0.03, 0.25), subsurf=1, u=9, v=5)
life.ellipsoid("hat", "hat", (0, 0.96, 0.0), (0.135, 0.095, 0.135), subsurf=1, u=9, v=5)
life.ellipsoid("hat", "tail", (0, 0.925, 0.0), (0.142, 0.022, 0.142), subsurf=1, u=10, v=4)

# --- arms: right holds the rod, left rests on the knee and waves
life.capsule("arm_r", "bucket", (0.17, 0.6, -0.02), (0.15, 0.49, -0.18), 0.05, 0.045, subsurf=1, u=6, v=4)
life.ellipsoid("arm_r", "cream", (0.15, 0.49, -0.2), (0.05, 0.045, 0.05), subsurf=1, u=6, v=4)
life.tube("rod", "hat", [(0.14, 0.505, -0.12), (0.17, 0.36, -0.34), (0.2, 0.22, -0.56)], [0.012, 0.009, 0.007], sides=5, subsurf=1)
life.tube("rod", "eye", [(0.2, 0.215, -0.56), (0.2, 0.12, -0.56), (0.2, 0.03, -0.56)], [0.004, 0.004, 0.004], sides=3, subsurf=0, cap=0.5)
life.ellipsoid("rod", "bucket", (0.2, 0.03, -0.56), (0.016, 0.016, 0.016), subsurf=0, u=6, v=4)
life.capsule("arm_l", "bucket", (-0.17, 0.6, -0.02), (-0.2, 0.5, -0.17), 0.05, 0.045, subsurf=1, u=6, v=4)
life.ellipsoid("arm_l", "cream", (-0.2, 0.495, -0.19), (0.052, 0.05, 0.055), subsurf=1, u=6, v=4)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.35, 0.0), "root"),
    ("head", (0, 0.7, -0.02), "body"),
    ("hat", (0, 0.88, 0.0), "head"),
    ("tail", (0, 0.32, 0.17), "body"),
    ("arm_r", (0.17, 0.6, -0.02), "body"),
    ("rod", (0.15, 0.49, -0.18), "arm_r"),
    ("arm_l", (-0.17, 0.6, -0.02), "body"),
])

REST = {}

# --- idle, 2.5 s: breathe, bob the rod, tilt the head toward a doze
life.cycle("idle", 2.5, {
    "body": [(0, REST), (0.6, {"scale": (1, 1.025, 1)}), (1.25, REST), (1.85, {"scale": (1, 1.025, 1)})],
    "head": [(0, REST), (0.7, {"rot": (4, 0, 0)}), (1.2, {"rot": (9, 0, 9), "loc": (0, -0.006, 0)}),
             (1.8, {"rot": (10, 0, 9), "loc": (0, -0.006, 0)}), (2.2, {"rot": (3, 0, 2)})],
    "hat": [(0, REST), (1.2, {"rot": (3, 0, 0)}), (1.8, {"rot": (3, 0, 0)})],
    "rod": [(0, REST), (0.45, {"rot": (5, 0, 0)}), (0.9, {"rot": (-2, 0, 1)}), (1.5, {"rot": (6, 0, -1)}), (2.0, {"rot": (-1, 0, 0)})],
    "arm_r": [(0, REST), (0.6, {"rot": (2, 0, 0)}), (1.25, REST), (1.85, {"rot": (2, 0, 0)})],
    "tail": [(0, REST), (1.0, {"rot": (-4, 0, 0)}), (1.8, {"rot": (2, 0, 0)})],
})

# --- move, 1.8 s: a friendly wave with the free paw
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

# --- react, 2.0 s: startled straighten, hat down over the face, hunch low behind the bucket
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
