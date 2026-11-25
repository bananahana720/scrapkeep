"""The Dig pit burro (ambient life record, ambient_kinds.gd "pit_burro"; issue #149, wave 17).

The miners left, their burros stayed. A barrel-round lilac-grey body on short stubby legs with soft round hooves, a big
soft head with a cream muzzle and sleepy eyes, two oversized long rounded ears (the silhouette hook), a short brush
mane and a tufted tail. 1.3 m tall at the ear tips, facing Godot -Z, origin on the ground. Soft toy look.

Bones: root, body (tail rides it), head (muzzle, eyes, mane), ear_l, ear_r, tail, leg_fl, leg_fr, leg_bl, leg_br.
Clips: idle (2.8 s: grazing head dip, ear flicks, tail swish), move (1.2 s: diagonal amble), react (2.0 s: head up, ears
back, a small hop, turn the rump and hunch; a breathing hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/pit_burro.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter

life = Critter("pit_burro")

D = -0.15

life.ellipsoid("body", "body", (0, 0.66 + D, 0.02), (0.28, 0.27, 0.38), subsurf=1, u=10, v=6)
life.ellipsoid("body", "body", (0, 0.8 + D, -0.24), (0.24, 0.27, 0.3), rot=(-20, 0, 0), subsurf=1, u=10, v=6)
life.ellipsoid("body", "cream", (0, 0.5 + D, -0.06), (0.2, 0.1, 0.26), subsurf=1, u=6, v=4)

life.ellipsoid("head", "body", (0, 0.93 + D, -0.43), (0.22, 0.2, 0.25), subsurf=1, u=10, v=6)
life.ellipsoid("head", "cream", (0, 0.86 + D, -0.66), (0.13, 0.1, 0.1), subsurf=1, u=10, v=6)
life.ellipsoid("head", "hoof", (0, 0.88 + D, -0.755), (0.05, 0.035, 0.03), subsurf=0, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.17 * s, 0.97 + D, -0.52), (0.05, 0.042, 0.042), rot=(0, 0, 8 * s), subsurf=1, u=6, v=4)
    life.ellipsoid("head", "body", (0.172 * s, 0.995 + D, -0.52), (0.058, 0.03, 0.05), rot=(0, 0, 8 * s), subsurf=1, u=6, v=4)
life.tube("head", "mane", [(0, 1.09 + D, -0.44), (0, 1.07 + D, -0.34), (0, 1.0 + D, -0.24)],
          [0.055, 0.06, 0.06], sides=6, subsurf=1)
life.tube("body", "mane", [(0, 1.02 + D, -0.27), (0, 0.98 + D, -0.18), (0, 0.93 + D, -0.08)],
          [0.058, 0.055, 0.045], sides=6, subsurf=1)

for s, bone in ((-1, "ear_l"), (1, "ear_r")):
    life.capsule(bone, "body", (0.1 * s, 1.0 + D, -0.4), (0.28 * s, 1.27 - 0.05, -0.38), 0.1, 0.085, subsurf=1, u=7, v=5, squash=(0.55, 1.0))
    life.ellipsoid(bone, "cream", (0.135 * s, 1.1 + D, -0.43), (0.022, 0.12, 0.05), rot=(0, 0, -12 * s), subsurf=0, u=6, v=4)

legs = {"leg_fl": (-1, -0.2), "leg_fr": (1, -0.2), "leg_bl": (-1, 0.24), "leg_br": (1, 0.24)}
for bone, (s, z) in legs.items():
    life.capsule(bone, "body", (0.15 * s, 0.5 + D, z), (0.15 * s, 0.13, z), 0.12, 0.105, subsurf=1, u=7, v=4)
    life.ellipsoid(bone, "hoof", (0.15 * s, 0.05, z - 0.01), (0.12, 0.055, 0.13), subsurf=1, u=7, v=4)

life.tube("tail", "body", [(0, 0.78 + D, 0.38), (0, 0.66 + D, 0.45), (0, 0.52 + D, 0.47)], [0.04, 0.032, 0.026], sides=6, subsurf=1)
life.ellipsoid("tail", "mane", (0, 0.45 + D, 0.47), (0.055, 0.1, 0.055), subsurf=1, u=8, v=5)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.66 + D, 0.02), "root"),
    ("head", (0, 0.88 + D, -0.32), "body"),
    ("ear_l", (-0.1, 1.0 + D, -0.4), "head"),
    ("ear_r", (0.1, 1.0 + D, -0.4), "head"),
    ("tail", (0, 0.78 + D, 0.38), "body"),
    ("leg_fl", (-0.15, 0.5 + D, -0.2), "root"),
    ("leg_fr", (0.15, 0.5 + D, -0.2), "root"),
    ("leg_bl", (-0.15, 0.5 + D, 0.24), "root"),
    ("leg_br", (0.15, 0.5 + D, 0.24), "root"),
])

REST = {}

life.cycle("idle", 2.8, {
    "body": [(0, REST), (0.7, {"scale": (1, 1.02, 1)}), (1.4, REST), (2.1, {"scale": (1, 1.02, 1)})],
    "head": [(0, REST), (0.4, {"rot": (-30, 0, 0), "loc": (0, -0.04, -0.03)}), (0.9, {"rot": (-34, 0, 3), "loc": (0, -0.05, -0.03)}),
             (1.5, {"rot": (4, 0, 0)}), (2.0, {"rot": (6, 0, -3)}), (2.4, {"rot": (2, 0, 0)})],
    "ear_l": [(0, REST), (0.5, {"rot": (-6, 0, -4)}), (1.5, REST), (1.7, {"rot": (14, 0, -12)}), (1.9, {"rot": (-4, 0, 3)}), (2.2, REST)],
    "ear_r": [(0, REST), (0.6, {"rot": (-5, 0, 4)}), (1.2, REST), (2.0, {"rot": (14, 0, 12)}), (2.2, {"rot": (-4, 0, -3)}), (2.5, REST)],
    "tail": [(0, REST), (0.5, {"rot": (0, 0, 16)}), (1.0, {"rot": (0, 0, -14)}), (1.5, {"rot": (0, 0, 14)}), (2.0, {"rot": (0, 0, -10)}), (2.4, {"rot": (0, 0, 6)})],
})

steps = 8
T = 1.2
tracks = {k: [] for k in ("body", "head", "ear_l", "ear_r", "tail", *legs)}
for i in range(steps):
    t = round(i * T / steps, 4)
    ph = math.tau * i / steps
    sw = 24 * math.sin(ph)
    tracks["leg_fl"].append((t, {"rot": (sw, 0, 0), "loc": (0, max(0.0, 0.03 * math.cos(ph)), 0)}))
    tracks["leg_br"].append((t, {"rot": (sw, 0, 0), "loc": (0, max(0.0, 0.03 * math.cos(ph)), 0)}))
    tracks["leg_fr"].append((t, {"rot": (-sw, 0, 0), "loc": (0, max(0.0, -0.03 * math.cos(ph)), 0)}))
    tracks["leg_bl"].append((t, {"rot": (-sw, 0, 0), "loc": (0, max(0.0, -0.03 * math.cos(ph)), 0)}))
    tracks["body"].append((t, {"loc": (0, 0.014 * math.cos(2 * ph), 0), "rot": (0, 0, 3 * math.sin(ph))}))
    tracks["head"].append((t, {"rot": (5 * math.cos(2 * ph + 0.6), 0, -2 * math.sin(ph))}))
    tracks["ear_l"].append((t, {"rot": (7 * math.sin(2 * ph), 0, -3)}))
    tracks["ear_r"].append((t, {"rot": (7 * math.sin(2 * ph + 1.0), 0, 3)}))
    tracks["tail"].append((t, {"rot": (0, 0, 12 * math.sin(ph + 1.0))}))
life.cycle("move", T, tracks)

FINAL = {
    "root": {"rot": (0, 165, 0)},
    "body": {"loc": (0, -0.03, 0), "rot": (6, 0, 0), "scale": (1.06, 0.94, 1.04)},
    "head": {"rot": (-26, 0, 0), "loc": (0, -0.03, 0.02)},
    "ear_l": {"rot": (38, 0, -14)},
    "ear_r": {"rot": (38, 0, 14)},
    "tail": {"rot": (-30, 0, 0)},
    **{b: {"scale": (1, 0.94, 1)} for b in legs},
}
BREATH = {"body": {"loc": (0, -0.03, 0), "rot": (6, 0, 0), "scale": (1.07, 0.95, 1.05)}}
UP = {"head": {"rot": (16, 0, 0), "loc": (0, 0.03, 0.0)}, "ear_l": {"rot": (-14, 0, -6)}, "ear_r": {"rot": (-14, 0, 6)},
      "tail": {"rot": (-40, 0, 0)}}
BACK = {"ear_l": {"rot": (36, 0, -12)}, "ear_r": {"rot": (36, 0, 12)}}
react = {}
for bone in ("root", "body", "head", "ear_l", "ear_r", "tail", *legs):
    fin = FINAL.get(bone, REST)
    hop = {"loc": (0, 0.14, 0), "rot": (0, 40, 0)} if bone == "root" else (
        {"rot": (-14, 0, 0)} if bone.startswith("leg_f") else ({"rot": (14, 0, 0)} if bone.startswith("leg_b") else None))
    land = {"loc": (0, 0, 0), "rot": (0, 85, 0)} if bone == "root" else None
    keys = [(0, REST), (0.12, UP.get(bone, REST))]
    keys.append((0.3, hop or UP.get(bone, BACK.get(bone, REST))))
    keys.append((0.45, land or BACK.get(bone, UP.get(bone, REST))))
    keys += [(0.8, fin), (1.4, BREATH.get(bone, fin)), (2.0, fin)]
    react[bone] = keys
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
