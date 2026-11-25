"""The Highdraft canyon wren (ambient life record, ambient_kinds.gd "canyon_wren"; issue #149, wave 17).

A tiny round mauve ball with a cream throat and bib, folded wing lobes on the flanks, a fan of three rounded plum tail
lobes cocked up and back at a jaunty angle (the silhouette hook), a slender gently down-curved beak with a rounded tip,
big bright eyes and thin legs with round feet. 0.18 m tall, facing Godot -Z, origin at the feet.

Bones: root, body (legs, feet), head (beak, eyes), tail (child of body), wing_l, wing_r (children of body, at the shoulder).
Clips: idle (2.0 s: quick knee-bob dips, tail flicks, head tilts), move (1.2 s: wings out in a quick flutter, flits and the
scatter flight), react (2.0 s: alarm crouch, tail snapped up, wings flick open to take off; hold-flutter from 0.8 s that
closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/canyon_wren.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("canyon_wren")

life.ellipsoid("body", "body", (0, 0.074, 0.006), (0.052, 0.05, 0.058), subsurf=1, u=12, v=6)
life.ellipsoid("body", "cream", (0, 0.066, -0.03), (0.04, 0.04, 0.034), rot=(-10, 0, 0), subsurf=1, u=8, v=6)

life.tube("tail", "tail", [(0, 0.085, 0.045), (0, 0.116, 0.068)], [0.02, 0.017], sides=5, subsurf=1)
for s in (-1, 0, 1):
    life.ellipsoid("tail", "tail", (0.016 * s, 0.14 + 0.004 * (s == 0), 0.072 + 0.006 * abs(s)),
                   (0.015, 0.042, 0.01), rot=(16, 0, -24 * s), subsurf=1, u=8, v=4)

life.ellipsoid("head", "body", (0, 0.122, -0.035), (0.036, 0.034, 0.036), subsurf=1, u=8, v=5)
life.ellipsoid("head", "cream", (0, 0.108, -0.056), (0.026, 0.02, 0.016), subsurf=1, u=8, v=5)
life.tube("head", "tail", [(0, 0.125, -0.06), (0, 0.124, -0.082), (0, 0.117, -0.103), (0, 0.105, -0.118)],
          [0.0085, 0.0072, 0.0058, 0.0042], sides=5, subsurf=1, cap=1.0)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.024 * s, 0.13, -0.054), (0.0105, 0.0115, 0.009), subsurf=1, u=8, v=4)

for s in (-1, 1):
    life.capsule("body", "wing", (0.017 * s, 0.034, 0.0), (0.017 * s, 0.008, -0.008), 0.0055, subsurf=1, u=5, v=3)
    life.ellipsoid("body", "wing", (0.017 * s, 0.006, -0.012), (0.011, 0.006, 0.02), subsurf=1, u=6, v=4)

for s, bone in ((-1, "wing_l"), (1, "wing_r")):
    life.ellipsoid(bone, "wing", (0.045 * s, 0.083, 0.014), (0.018, 0.034, 0.05), rot=(-10, 12 * s, 0), subsurf=1, u=8, v=5)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.074, 0.0), "root"),
    ("head", (0, 0.11, -0.03), "body"),
    ("tail", (0, 0.09, 0.05), "body"),
    ("wing_l", (-0.04, 0.1, -0.025), "body"),
    ("wing_r", (0.04, 0.1, -0.025), "body"),
])

REST = {}


def wings(yaw, roll, tip=0):
    return {"wing_l": {"rot": (tip, -yaw, -roll)}, "wing_r": {"rot": (tip, yaw, roll)}}


DIP = {"loc": (0, -0.008, 0), "rot": (6, 0, 0), "scale": (1.03, 0.95, 1.03)}
life.cycle("idle", 2.0, {
    "body": [(0, REST), (0.2, DIP), (0.4, REST), (0.6, DIP), (0.8, REST), (1.5, REST), (1.7, DIP), (1.9, REST)],
    "head": [(0, REST), (0.3, {"rot": (0, 0, 14)}), (0.9, {"rot": (2, 20, 14)}), (1.2, {"rot": (0, 20, -10)}),
             (1.6, {"rot": (0, -16, -10)}), (1.85, {"rot": (0, 0, 0)})],
    "tail": [(0, REST), (0.4, {"rot": (-8, 0, 0)}), (0.5, {"rot": (6, 0, 0)}), (0.7, REST), (1.0, {"rot": (0, 8, 0)}),
             (1.3, {"rot": (0, -8, 0)}), (1.6, {"rot": (-8, 0, 0)}), (1.7, {"rot": (7, 0, 0)}), (1.9, REST)],
})

w_up, w_down = wings(70, 40), wings(70, -28)
flap = {"wing_l": [], "wing_r": [], "body": [], "head": [], "tail": []}
for i in range(6):
    t = round(i * 0.2, 4)
    w = w_up if i % 2 == 0 else w_down
    flap["wing_l"].append((t, w["wing_l"]))
    flap["wing_r"].append((t, w["wing_r"]))
    flap["body"].append((t, {"loc": (0, 0.008 if i % 2 else 0.0, 0), "rot": (-10, 0, 0)}))
    flap["head"].append((t, {"rot": (8, 0, 0)}))
    flap["tail"].append((t, {"rot": (6 if i % 2 else -4, 0, 0)}))
life.cycle("move", 1.2, flap)

CROUCH = {
    "body": {"loc": (0, -0.014, 0.004), "rot": (-12, 0, 0), "scale": (1.06, 0.88, 1.05)},
    "head": {"loc": (0, -0.004, 0), "rot": (8, 0, 0)},
    "tail": {"rot": (-14, 0, 0)},
    **wings(52, 34),
}
FLUTTER = {
    "body": {"loc": (0, -0.012, 0.004), "rot": (-12, 0, 0), "scale": (1.07, 0.9, 1.06)},
    "head": CROUCH["head"],
    "tail": {"rot": (-10, 0, 0)},
    **wings(66, -12),
}
SQUASH = {"body": {"loc": (0, -0.02, 0), "rot": (4, 0, 0), "scale": (1.08, 0.82, 1.08)}, "head": {"rot": (14, 0, 0)},
          "tail": {"rot": (4, 0, 0)}, **wings(0, 0)}
SNAP = {"body": {"scale": (0.96, 1.06, 0.96), "rot": (6, 0, 0)}, "head": {"rot": (-10, 0, 0)}, "tail": {"rot": (-22, 0, 0)},
        **wings(80, 44)}
react = {}
for bone in ("body", "head", "tail", "wing_l", "wing_r"):
    react[bone] = [(0, REST), (0.1, SQUASH[bone]), (0.25, SNAP[bone]), (0.5, CROUCH[bone]), (0.8, CROUCH[bone]),
                   (1.0, FLUTTER[bone]), (1.2, CROUCH[bone]), (1.4, FLUTTER[bone]), (1.7, FLUTTER[bone]), (2.0, CROUCH[bone])]
life.oneshot("react", 2.0, react, loop_from=0.8)

import os
import _life

if os.environ.get("CANYON_WREN_POSE") and _life.args()["stills"]:
    clip, at = os.environ["CANYON_WREN_POSE"].split(":")
    dest = _life.args()["stills"]
    sys.argv = [a for a in sys.argv if a not in ("--stills", dest)]
    life.finish()
    life.stills(dest, pose=(clip, float(at)))
else:
    life.finish()
