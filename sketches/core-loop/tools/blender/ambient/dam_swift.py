"""The Spillway dam swift (ambient life record, ambient_kinds.gd "dam_swift"; issue #149, wave 17).

A round plum ball with a cream belly, a small head merged into the body, a short forked tail and two crescent wings
(soft sickle shapes: the silhouette hook) folded along the sides at rest. 0.22 m tall, facing Godot -Z, origin at the feet.
Soft toy look (chunky, smooth); palette, height and triangle band come from the record.

Bones: root, body (tail rides it), head (beak, eyes), wing_l, wing_r (children of body, pivot at the shoulder).
Clips: idle (2.0 s: perched, breathing, head turns, a small wing shuffle; the runtime's slowed idle is its sleep),
move (1.2 s: wings out, flapping in a soft arc; hops and the scatter flight), react (2.0 s: wings snap out and up, then a
crouch ready to launch; a hold from 0.8 s that closes on itself, so a runtime that loops it seeks back to 0.8 s).

  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/dam_swift.py -- [--out FILE] [--stills DIR]
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _life import Critter  # noqa: E402

life = Critter("dam_swift")

# --- body: a round ball, cream belly, short forked tail pointing back (+Z)
life.ellipsoid("body", "body", (0, 0.1, 0.004), (0.088, 0.08, 0.09), subsurf=1, u=10, v=6)
life.ellipsoid("body", "cream", (0, 0.085, -0.046), (0.062, 0.054, 0.042), rot=(-12, 0, 0), subsurf=0, u=10, v=6)
for s in (-1, 1):
    life.capsule("body", "wing", (0.008 * s, 0.108, 0.078), (0.026 * s, 0.116, 0.135), 0.021, 0.013, subsurf=1, u=6, v=4)

# --- head: small, merged into the front of the body; beak nub and eyes
life.ellipsoid("head", "body", (0, 0.173, -0.056), (0.047, 0.043, 0.045), subsurf=1, u=8, v=5)
life.ellipsoid("head", "cream", (0, 0.164, -0.094), (0.03, 0.022, 0.014), subsurf=1, u=6, v=4)
life.ellipsoid("head", "wing", (0, 0.17, -0.106), (0.012, 0.009, 0.013), subsurf=1, u=6, v=4)
for s in (-1, 1):
    life.ellipsoid("head", "eye", (0.03 * s, 0.183, -0.082), (0.011, 0.012, 0.009), subsurf=0, u=8, v=5)

# --- short feet
for s in (-1, 1):
    life.ellipsoid("body", "wing", (0.03 * s, 0.014, -0.012), (0.017, 0.014, 0.027), subsurf=0, u=8, v=5)

# --- crescent wings: one smooth tapered sweep per side, shoulder at the front of the flank, tip curving back and up
ARC = [(-0.025, 0.12), (0.02, 0.114), (0.065, 0.118), (0.105, 0.133), (0.135, 0.153)]
for s, bone in ((-1, "wing_l"), (1, "wing_r")):
    life.tube(bone, "wing", [(0.085 * s, y, z) for z, y in ARC], [0.024, 0.026, 0.022, 0.015, 0.007], sides=6, subsurf=1)

life.rig([
    ("root", (0, 0, 0), None),
    ("body", (0, 0.1, 0.0), "root"),
    ("head", (0, 0.155, -0.05), "body"),
    ("wing_l", (-0.08, 0.12, -0.03), "body"),
    ("wing_r", (0.08, 0.12, -0.03), "body"),
])

REST = {}
# Wing yaw swings the folded wing out sideways (right wing +, left wing -); roll then lifts the tip (right +, left -).
def wings(yaw, roll, tip=0):
    return {"wing_l": {"rot": (tip, -yaw, -roll)}, "wing_r": {"rot": (tip, yaw, roll)}}

# --- idle, 2.0 s: breathe, look round, a small wing shuffle
def idle_wings(t, yaw, roll):
    w = wings(yaw, roll)
    return {k: (t, v) for k, v in w.items()}

life.cycle("idle", 2.0, {
    "body": [(0, REST), (0.5, {"scale": (1.02, 1.03, 1.02)}), (1.0, {"scale": (1, 1, 1), "rot": (-2, 0, 0)}),
             (1.5, {"scale": (1.02, 1.03, 1.02)})],
    "head": [(0, REST), (0.4, {"rot": (2, 22, 3)}), (0.8, {"rot": (0, 22, 3)}), (1.1, {"rot": (3, -18, -3)}),
             (1.5, {"rot": (0, -18, -3)}), (1.8, {"rot": (2, 4, 0)})],
    "wing_l": [(0, REST), (1.2, REST), (1.35, wings(14, 10)["wing_l"]), (1.55, wings(4, 3)["wing_l"]), (1.75, REST)],
    "wing_r": [(0, REST), (1.2, REST), (1.35, wings(14, 10)["wing_r"]), (1.55, wings(4, 3)["wing_r"]), (1.75, REST)],
})

# --- move, 1.2 s: wings out, flapping in a soft arc (4 flaps), body bobbing, tucked forward
w_up, w_down = wings(78, 38), wings(78, -26)
flap = {"wing_l": [], "wing_r": [], "body": [], "head": []}
for i in range(8):
    t = round(i * 0.15, 4)
    w = w_up if i % 2 == 0 else w_down
    flap["wing_l"].append((t, w["wing_l"]))
    flap["wing_r"].append((t, w["wing_r"]))
    flap["body"].append((t, {"loc": (0, 0.012 if i % 2 else 0.0, 0), "rot": (-12, 0, 0)}))
    flap["head"].append((t, {"rot": (8, 0, 0)}))
life.cycle("move", 1.2, flap)

# --- react, 2.0 s: wings snap out and up, then a launch-ready crouch; hold from 0.8 s closes on itself
SNAP = wings(82, 46)
CROUCH = {
    "body": {"loc": (0, -0.014, 0.004), "rot": (-14, 0, 0), "scale": (1.06, 0.88, 1.05)},
    "head": {"loc": (0, -0.004, 0), "rot": (10, 0, 0)},
    **wings(58, 38),
}
BREATH = {"body": {"loc": (0, -0.014, 0.004), "rot": (-14, 0, 0), "scale": (1.07, 0.9, 1.06)}}
react = {}
for bone in ("body", "head", "wing_l", "wing_r"):
    crouch = CROUCH[bone]
    if bone == "body":
        snap = {"scale": (0.96, 1.06, 0.96), "rot": (6, 0, 0)}
    elif bone == "head":
        snap = {"rot": (-12, 0, 0)}
    else:
        snap = SNAP[bone]
    react[bone] = [(0, REST), (0.18, snap), (0.55, crouch), (0.8, crouch), (1.4, BREATH.get(bone, crouch)), (2.0, crouch)]
life.oneshot("react", 2.0, react, loop_from=0.8)

import os  # noqa: E402
import _life  # noqa: E402

if os.environ.get("DAM_SWIFT_POSE") and _life.args()["stills"]:  # review aid: a mid-clip still, e.g. DAM_SWIFT_POSE=move:0.15
    clip, at = os.environ["DAM_SWIFT_POSE"].split(":")
    dest = _life.args()["stills"]
    sys.argv = [a for a in sys.argv if a not in ("--stills", dest)]
    life.finish()
    life.stills(dest, pose=(clip, float(at)))
else:
    life.finish()
