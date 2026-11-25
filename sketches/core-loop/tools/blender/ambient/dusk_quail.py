"""The Spillway dusk quail (ambient life record, ambient_kinds.gd "dusk_quail"; issue #149, wave 17).

A round teardrop body, stubby legs, a small round head with a cream face mask, and a curled topknot plume that ends in
a bold teardrop bulb: the silhouette hook. 0.32 m tall to the plume tip, facing Godot -Z, origin on the ground.
Soft toy look (chunky, bevelled, smooth); palette, height and triangle band come from the record.

Bones: root, body (tail and wings ride it), head (mask, beak, eyes), plume (child of head), leg_l, leg_r.
Clips: idle (2.0 s: breathing, a head bob and two pecks), move (1.2 s: scurry, legs blur at 7.5 Hz, body bob),
react (2.0 s: alert flick, then crouch and flatten, plume laid back; a breathing hold from 0.8 s that closes on itself,
so a runtime that loops it seeks back to 0.8 s; the quail then hides).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/dusk_quail.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("dusk_quail")

life.ellipsoid("body", "body", (0, 0.118, -0.005), (0.078, 0.072, 0.092), subsurf=1, u=12, v=6)
life.tube("body", "body", [(0, 0.125, 0.05), (0, 0.14, 0.11), (0, 0.158, 0.165)], [0.055, 0.032, 0.012], sides=7, subsurf=1)
life.ellipsoid("body", "cream", (0, 0.095, -0.045), (0.05, 0.04, 0.045), rot=(-15, 0, 0), subsurf=1, u=7, v=4)
for s in (-1, 1):
    life.ellipsoid("body", "wing", (0.066 * s, 0.13, 0.018), (0.018, 0.044, 0.07), rot=(8, 0, 6 * s), subsurf=1, u=6, v=4)

life.ellipsoid("head", "body", (0, 0.222, -0.07), (0.043, 0.042, 0.043), subsurf=1, u=10, v=6)
life.ellipsoid("head", "cream", (0, 0.216, -0.099), (0.032, 0.03, 0.016), subsurf=0, u=8, v=4)
life.tube("head", "plume", [(0, 0.218, -0.108), (0, 0.213, -0.128)], [0.015, 0.007], sides=5, subsurf=1)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.027 * s, 0.232, -0.093), (0.012, 0.013, 0.01), subsurf=1, u=5, v=3)

life.tube("plume", "plume", [(0, 0.248, -0.062), (0, 0.282, -0.054), (0, 0.304, -0.062), (0, 0.315, -0.085), (0, 0.307, -0.108)],
          [0.016, 0.014, 0.0125, 0.0155, 0.012], sides=7, subsurf=1)

for s, bone in ((-1, "leg_l"), (1, "leg_r")):
    life.capsule(bone, "plume", (0.032 * s, 0.07, 0.008), (0.032 * s, 0.016, -0.004), 0.017, 0.013, subsurf=1, u=6, v=4)
    life.ellipsoid(bone, "plume", (0.032 * s, 0.009, -0.02), (0.016, 0.009, 0.026), subsurf=0, u=8, v=4)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.118, 0.0), "root"),
    ("head", (0, 0.2, -0.055), "body"),
    ("plume", (0, 0.252, -0.058), "head"),
    ("leg_l", (-0.032, 0.07, 0.006), "root"),
    ("leg_r", (0.032, 0.07, 0.006), "root"),
])

REST = {}

life.cycle("idle", 2.0, {
    "body": [(0, REST), (0.5, {"scale": (1, 1.025, 1)}), (1.0, {"rot": (-7, 0, 0), "scale": (1, 1.0, 1)}),
             (1.3, {"rot": (-3, 0, 0)}), (1.5, {"rot": (-7, 0, 0)}), (1.75, {"scale": (1, 1.02, 1)})],
    "head": [(0, REST), (0.3, {"rot": (10, 0, 0), "loc": (0, 0.004, 0.002)}), (0.6, {"rot": (6, 0, 4)}),
             (0.9, {"rot": (8, 0, 0)}), (1.0, {"rot": (-42, 0, 0), "loc": (0, -0.012, -0.012)}),
             (1.12, {"rot": (6, 0, 0)}), (1.3, {"rot": (-38, 0, 0), "loc": (0, -0.01, -0.01)}),
             (1.45, {"rot": (4, 0, -3)}), (1.7, {"rot": (2, 0, 0)})],
    "plume": [(0, REST), (0.5, {"rot": (-6, 0, 5)}), (1.0, {"rot": (14, 0, 0)}), (1.12, {"rot": (-10, 0, -4)}),
              (1.5, {"rot": (6, 0, 3)})],
})

half = 2 / 30.0
legs = {"leg_l": [], "leg_r": []}
body, head, plume = [], [], []
for i in range(18):
    t = round(i * half, 4)
    swing = 50 if i % 2 == 0 else -50
    legs["leg_l"].append((t, {"rot": (swing, 0, 0)}))
    legs["leg_r"].append((t, {"rot": (-swing, 0, 0)}))
    body.append((t, {"loc": (0, 0.012 if i % 2 == 0 else 0.0, 0), "rot": (-9, 0, 3 if i % 4 < 2 else -3)}))
    head.append((t, {"rot": (6 if i % 2 == 0 else -2, 0, 0)}))
    plume.append((t, {"rot": (18 + (5 if i % 2 == 0 else -3), 0, 0)}))
life.cycle("move", 1.2, {"body": body, "head": head, "plume": plume, **legs})

DUCK = {
    "body": {"loc": (0, -0.05, 0.004), "rot": (0, 0, 0), "scale": (1.16, 0.55, 1.1)},
    "head": {"loc": (0, -0.03, 0.02), "rot": (-18, 0, 0)},
    "plume": {"rot": (72, 0, 0), "loc": (0, 0, 0.004)},
    "leg_l": {"scale": (1, 0.4, 1), "loc": (0, -0.012, 0)},
    "leg_r": {"scale": (1, 0.4, 1), "loc": (0, -0.012, 0)},
}
BREATH = {"body": {"loc": (0, -0.05, 0.004), "rot": (0, 0, 0), "scale": (1.17, 0.575, 1.11)}}
react = {}
for bone in ("body", "head", "plume", "leg_l", "leg_r"):
    ducked = DUCK[bone]
    react[bone] = [(0, REST), (0.1, {"scale": (1, 1.06, 1)} if bone == "body" else
                                   ({"rot": (14, 0, 0)} if bone in ("head", "plume") else REST)),
                   (0.55, ducked), (0.8, ducked), (1.4, BREATH.get(bone, ducked)), (2.0, ducked)]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
