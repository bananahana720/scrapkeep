"""The Dig prospector (ambient life record, ambient_kinds.gd "prospector"; issue #149, wave 17).

An old round badger in a violet flannel shirt, kneeling at the runoff, a civilian at rest: floppy battered hat, lengthwise
cream and plum badger stripes over the head, a wide shallow pan held low in both paws, a short blunt pick lying on the
ground beside him (never held). Soft toy look; palette, height and triangle band come from the record. Faces Godot -Z.

Bones: root, legs (lap, shins, feet), body (torso, straps; hip pivot), head (face, stripes, ears), hat (child of head),
arm_l, arm_r and pan (children of body). The pick rides root.
Clips: idle (2.5 s: swirls the pan, head bob, a hummed sway), move (1.8 s: lifts the pan to peer at it, a happy nod;
locals do not walk, the runtime uses it as the greeting), react (2.0 s: startled, then flat on the belly with the hat pulled
over the face; a hold from 0.8 s that closes on itself).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/prospector.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector
from _life import Critter, _B, _m

life = Critter("prospector")

life.ellipsoid("legs", "stripe", (0, 0.16, 0.06), (0.21, 0.15, 0.2), subsurf=1, u=8, v=5)
for s in (-1, 1):
    life.capsule("legs", "stripe", (0.13 * s, 0.075, -0.1), (0.13 * s, 0.07, 0.25), 0.075, 0.062, subsurf=1, u=6, v=4)
    life.ellipsoid("legs", "cream", (0.13 * s, 0.045, 0.31), (0.06, 0.04, 0.075), subsurf=0, u=8, v=4)

life.ellipsoid("body", "shirt", (0, 0.5, 0.01), (0.27, 0.3, 0.25), subsurf=1, u=10, v=6)
life.ellipsoid("body", "cream", (0, 0.72, -0.07), (0.15, 0.06, 0.1), subsurf=1, u=6, v=4)
life.ellipsoid("body", "stripe", (0, 0.5, -0.2), (0.15, 0.17, 0.06), subsurf=1, u=8, v=4)

HC, HR = Vector((0, 0.82, -0.08)), (0.175, 0.15, 0.19)
hp = life.part("head")
with hp.region(bevel=0, subsurf=1, detail=1):
    r = bmesh.ops.create_uvsphere(hp.bm, u_segments=12, v_segments=8, radius=1.0, matrix=_B @ _m(tuple(HC), (0, 0, 0), HR))
    hp.bm.verts.index_update()
    hp.bm.faces.index_update()
    faces = sorted({f for v in r["verts"] for f in v.link_faces}, key=lambda f: f.index)
    band = []
    for f in faces:
        c = f.calc_center_median()
        gx, gy = (c.x - HC.x) / HR[0], (c.z - HC.y) / HR[1]
        if 0.3 <= abs(gx) <= 0.72 and gy > -0.3:
            band.append(f)
    hp.paint(faces, "critter", life.col("cream"))
    hp.paint(band, "critter", life.col("stripe"))
life.ellipsoid("head", "cream", (0, 0.77, -0.25), (0.075, 0.06, 0.09), subsurf=1, u=6, v=4)
life.ellipsoid("head", "eye", (0, 0.785, -0.335), (0.03, 0.025, 0.025), subsurf=0, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.09 * s, 0.825, -0.215), (0.026, 0.029, 0.02), subsurf=0, u=6, v=4)
    life.ellipsoid("head", "stripe", (0.145 * s, 0.94, 0.0), (0.045, 0.05, 0.035), subsurf=1, u=6, v=4)

life.ellipsoid("hat", "hat", (0, 1.02, 0.05), (0.14, 0.08, 0.14), rot=(6, 0, 4), subsurf=1, u=8, v=5)
life.ellipsoid("hat", "hat", (0, 0.965, 0.05), (0.235, 0.025, 0.23), rot=(-6, 0, 0), subsurf=1, u=16, v=4)
life.ellipsoid("hat", "stripe", (0, 0.985, 0.05), (0.15, 0.025, 0.15), subsurf=0, u=10, v=4)

for s, bone in ((-1, "arm_l"), (1, "arm_r")):
    life.capsule(bone, "shirt", (0.25 * s, 0.65, -0.02), (0.19 * s, 0.42, -0.28), 0.085, 0.07, subsurf=1, u=6, v=4)
    life.ellipsoid(bone, "cream", (0.19 * s, 0.4, -0.3), (0.055, 0.05, 0.055), subsurf=1, u=8, v=4)

life.ellipsoid("pan", "pan", (0, 0.37, -0.3), (0.22, 0.035, 0.22), subsurf=1, u=16, v=6)
life.ellipsoid("pan", "stripe", (0, 0.395, -0.3), (0.15, 0.02, 0.15), subsurf=0, u=16, v=4)

life.tube("root", "stripe", [(0.52, 0.035, 0.2), (0.5, 0.05, -0.28)], [0.026, 0.024], sides=6, subsurf=1)
life.ellipsoid("root", "pan", (0.5, 0.07, -0.32), (0.13, 0.05, 0.045), subsurf=1, u=10, v=5)

life.rig([
    ("root", (0, 0, 0), None),
    ("legs", (0, 0, 0), "root"),
    ("body", (0, 0.22, 0), "root"),
    ("head", (0, 0.72, -0.04), "body"),
    ("hat", (0, 0.97, 0.0), "head"),
    ("arm_l", (-0.25, 0.65, -0.02), "body"),
    ("arm_r", (0.25, 0.65, -0.02), "body"),
    ("pan", (0, 0.38, -0.3), "body"),
])

REST = {}

import math
pan_keys, arm_l, arm_r = [], [], []
for i in range(10):
    t = round(i * 0.25, 4)
    a = math.tau * 2 * i / 10
    pan_keys.append((t, {"loc": (0.03 * math.sin(a), 0.004 * math.cos(2 * a), 0.03 * math.cos(a)), "rot": (3 * math.cos(a), 0, 4 * math.sin(a))}))
    arm_l.append((t, {"rot": (2 * math.cos(a), 0, 0)}))
    arm_r.append((t, {"rot": (-2 * math.cos(a), 0, 0)}))
life.cycle("idle", 2.5, {
    "body": [(0, REST), (0.625, {"rot": (0, 0, 2.5), "scale": (1, 1.02, 1)}), (1.25, {"rot": (-2, 0, 0)}),
             (1.875, {"rot": (0, 0, -2.5), "scale": (1, 1.02, 1)})],
    "head": [(0, REST), (0.5, {"rot": (6, 0, -3)}), (1.0, {"rot": (-7, 0, 0), "loc": (0, -0.006, -0.004)}),
             (1.5, {"rot": (5, 0, 3)}), (2.0, {"rot": (-6, 0, 0), "loc": (0, -0.005, -0.004)})],
    "hat": [(0, REST), (1.0, {"rot": (-4, 0, 3)}), (1.75, {"rot": (3, 0, -2)})],
    "pan": pan_keys, "arm_l": arm_l, "arm_r": arm_r,
})

LIFT = 51
life.cycle("move", 1.8, {
    "arm_l": [(0, REST), (0.4, {"rot": (LIFT, 0, 0)}), (0.9, {"rot": (LIFT, 0, 0)}), (1.2, REST)],
    "arm_r": [(0, REST), (0.4, {"rot": (LIFT, 0, 0)}), (0.9, {"rot": (LIFT, 0, 0)}), (1.2, REST)],
    "pan": [(0, REST), (0.4, {"loc": (0, 0.25, -0.09), "rot": (-12, 0, 0)}), (0.65, {"loc": (0.01, 0.25, -0.09), "rot": (-16, 0, 6)}),
            (0.9, {"loc": (0, 0.25, -0.09), "rot": (-12, 0, 0)}), (1.2, REST)],
    "head": [(0, REST), (0.4, {"rot": (-10, 0, 0), "loc": (0, -0.01, -0.01)}), (0.9, {"rot": (-8, 0, 5)}), (1.2, REST),
             (1.4, {"rot": (-16, 0, 0), "loc": (0, -0.012, -0.012)}), (1.6, {"rot": (4, 0, 0)})],
    "body": [(0, REST), (0.4, {"rot": (-4, 0, 0)}), (1.2, REST), (1.4, {"rot": (-3, 0, 0)}), (1.6, {"rot": (1, 0, 0)})],
    "hat": [(0, REST), (1.4, {"rot": (-6, 0, 0)}), (1.6, {"rot": (3, 0, 0)})],
})

DUCK = {
    "legs": {"scale": (1, 0.45, 1)},
    "body": {"loc": (0, -0.03, 0), "rot": (-80, 0, 0)},
    "head": {"rot": (45, 0, 0), "loc": (0, 0, 0)},
    "hat": {"rot": (-55, 0, 0), "loc": (0, -0.1, -0.12)},
    "arm_l": {"rot": (150, 0, 8)},
    "arm_r": {"rot": (150, 0, -8)},
    "pan": {"loc": (0, 0.0, -0.35), "rot": (0, 0, 0)},
}
STARTLE = {
    "legs": REST,
    "body": {"loc": (0, 0.06, 0.0), "rot": (6, 0, 0), "scale": (1, 1.05, 1)},
    "head": {"rot": (16, 0, 0)},
    "hat": {"rot": (12, 0, 0), "loc": (0, 0.05, 0)},
    "arm_l": {"rot": (70, 0, -12)},
    "arm_r": {"rot": (70, 0, 12)},
    "pan": {"loc": (0, 0.3, 0.0), "rot": (-25, 0, 0)},
}
BREATH = {"body": {"loc": (0, -0.02, 0), "rot": (-80, 0, 0)}}
react = {}
for bone, ducked in DUCK.items():
    react[bone] = [(0, REST), (0.15, STARTLE[bone]), (0.8, ducked), (1.4, BREATH.get(bone, ducked)), (2.0, ducked)]
life.oneshot("react", 2.0, react, loop_from=0.8)

life.finish()
