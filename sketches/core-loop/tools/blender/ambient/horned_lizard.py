"""The Dig horned lizard (ambient life record, ambient_kinds.gd "horned_lizard"; issue #149, wave 17).

A round flattened mauve cushion of a body (a pancake, never a wedge), a wide round head wearing a crown of soft round
nubs, little round nubs along the body edge, short splayed legs with round toes, a stubby tail, cream belly and chin, big
friendly eyes. About 0.14 m tall to the crown, facing Godot -Z, origin on the ground.

Bones: root, body (side nubs, belly, tail ride it), head (crown nubs, eyes), throat (child of head, cream chin), tail
(child of body), leg_fl, leg_fr, leg_bl, leg_br.
Clips: idle (2.4 s: basking, two slow head turns, a throat pulse), move (1.2 s: waddling scurry, diagonal legs),
react (2.0 s: puffs up round, then flattens low as if wedging into a crack; a hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/horned_lizard.py -- [--out FILE] [--stills DIR]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("horned_lizard")

life.ellipsoid("body", "body", (0, 0.056, 0.0), (0.088, 0.044, 0.095), subsurf=1, u=9, v=5)
life.ellipsoid("body", "cream", (0, 0.034, -0.004), (0.068, 0.03, 0.078), subsurf=0, u=10, v=5)
for i, z in enumerate((-0.03, 0.03)):
    for s in (-1, 1):
        r = 0.015 - 0.0015 * i
        life.ellipsoid("body", "nubs", (0.083 * s, 0.062, z), (r, r * 0.9, r), subsurf=1, u=6, v=4)

life.tube("tail", "body", [(0, 0.04, 0.085), (0, 0.037, 0.125), (0, 0.034, 0.152)], [0.026, 0.018, 0.01], sides=6, subsurf=1)

life.ellipsoid("head", "body", (0, 0.082, -0.092), (0.058, 0.044, 0.05), subsurf=1, u=9, v=5)
life.ellipsoid("throat", "cream", (0, 0.062, -0.116), (0.038, 0.022, 0.03), subsurf=1, u=5, v=3)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.036 * s, 0.098, -0.122), (0.016, 0.017, 0.013), subsurf=1, u=5, v=3)
    life.ellipsoid("head", "cream", (0.036 * s, 0.098, -0.117), (0.021, 0.021, 0.013), subsurf=1, u=5, v=3)
for x, y, z, r in ((0, 0.122, -0.082, 0.015), (0.03, 0.115, -0.08, 0.0135), (-0.03, 0.115, -0.08, 0.0135),
                   (0.052, 0.103, -0.076, 0.012), (-0.052, 0.103, -0.076, 0.012)):
    life.ellipsoid("head", "nubs", (x, y, z), (r, r, r), subsurf=1, u=6, v=4)

LEGS = {"leg_fl": (-1, -0.052), "leg_fr": (1, -0.052), "leg_bl": (-1, 0.05), "leg_br": (1, 0.05)}
for bone, (s, z) in LEGS.items():
    life.capsule(bone, "body", (0.07 * s, 0.036, z), (0.112 * s, 0.014, z - 0.01 * (1 if z < 0 else -1)), 0.02, 0.016,
                 subsurf=1, u=5, v=3)
    for dz in (0.0,):
        life.ellipsoid(bone, "nubs", (0.12 * s, 0.009, z - 0.012 + dz * 0.8), (0.011, 0.009, 0.011), subsurf=1, u=6, v=4)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.056, 0.0), "root"),
    ("head", (0, 0.07, -0.07), "body"),
    ("throat", (0, 0.065, -0.1), "head"),
    ("tail", (0, 0.04, 0.085), "body"),
    ("leg_fl", (-0.07, 0.045, -0.052), "root"),
    ("leg_fr", (0.07, 0.045, -0.052), "root"),
    ("leg_bl", (-0.07, 0.045, 0.05), "root"),
    ("leg_br", (0.07, 0.045, 0.05), "root"),
])

REST = {}

life.cycle("idle", 2.4, {
    "body": [(0, REST), (0.6, {"scale": (1.0, 1.04, 1.0)}), (1.2, REST), (1.8, {"scale": (1.0, 1.04, 1.0)})],
    "head": [(0, REST), (0.4, {"rot": (0, 18, 3)}), (0.8, {"rot": (2, 22, 3)}), (1.2, REST),
             (1.6, {"rot": (0, -18, -3)}), (2.0, {"rot": (2, -20, -3)})],
    "throat": [(0, REST), (0.3, {"scale": (1.18, 1.3, 1.18)}), (0.6, REST), (0.9, {"scale": (1.18, 1.3, 1.18)}),
               (1.2, REST), (1.5, {"scale": (1.18, 1.3, 1.18)}), (1.8, REST)],
    "tail": [(0, REST), (0.8, {"rot": (0, 8, 0)}), (1.6, {"rot": (0, -8, 0)})],
})

legs = {k: [] for k in LEGS}
body, head, tail = [], [], []
step = 0.2
for i in range(6):
    t = round(i * step, 4)
    a = 1 if i % 2 == 0 else -1
    legs["leg_fl"].append((t, {"rot": (38 * a, 0, 0), "loc": (0, 0.006 if a > 0 else 0.0, 0)}))
    legs["leg_br"].append((t, {"rot": (38 * a, 0, 0), "loc": (0, 0.006 if a > 0 else 0.0, 0)}))
    legs["leg_fr"].append((t, {"rot": (-38 * a, 0, 0), "loc": (0, 0.0 if a > 0 else 0.006, 0)}))
    legs["leg_bl"].append((t, {"rot": (-38 * a, 0, 0), "loc": (0, 0.0 if a > 0 else 0.006, 0)}))
    body.append((t, {"rot": (0, 7 * a, 5 * a), "loc": (0, 0.004 if i % 2 == 0 else 0.0, 0)}))
    head.append((t, {"rot": (0, -9 * a, -3 * a)}))
    tail.append((t, {"rot": (0, -14 * a, 0)}))
life.cycle("move", 1.2, {"body": body, "head": head, "tail": tail, **legs})

PUFF = {
    "body": {"scale": (1.25, 1.25, 1.25), "loc": (0, 0.012, 0)},
    "head": {"rot": (-8, 0, 0)},
    "throat": {"scale": (1.3, 1.5, 1.3)},
    "tail": {"rot": (-10, 0, 0)},
}
FLAT = {
    "body": {"scale": (1.18, 0.42, 1.12), "loc": (0, -0.03, 0)},
    "head": {"loc": (0, -0.03, 0.004), "rot": (-10, 0, 0)},
    "throat": {"scale": (0.9, 0.7, 0.9)},
    "tail": {"loc": (0, -0.018, 0), "rot": (12, 0, 0), "scale": (1, 0.6, 1)},
}
LEGFLAT = {"scale": (1.0, 0.3, 1.0), "loc": (0, -0.03, 0)}
LEGPUFF = {"loc": (0, 0.006, 0), "scale": (1.0, 1.1, 1.0)}
BREATH = {"body": {"scale": (1.2, 0.44, 1.14), "loc": (0, -0.03, 0)}}
react = {}
for bone in ("body", "head", "throat", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br"):
    flat = FLAT.get(bone, LEGFLAT)
    puff = PUFF.get(bone, LEGPUFF)
    react[bone] = [(0, REST), (0.3, puff), (0.45, puff), (0.8, flat), (1.4, BREATH.get(bone, flat)), (2.0, flat)]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
