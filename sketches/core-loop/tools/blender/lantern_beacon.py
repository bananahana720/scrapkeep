"""Headless recipe for lantern_beacon_frame.glb and lantern_beacon_lens.glb, the lantern beacon in the FLUX.1
schnell concept sheet artifacts/local/alpha/push/w12/probes/gen2/ref/beacon_101.png (beacon_202.png is a
second take): a tripod, an ivory platform, a caged lantern, an upright halo ring and a cone cap.

Same route as ore_cart.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
The frame is two draws (steel: legs, feet, collar, cage bars, brackets, halo ring, cap; enamel: platform and
lantern housing); the lens is one glass draw placed at the frame's socket_lens. Class "landmark" in
tools/asset_budgets.json. No lights: the ring and cap are painted the steel shader's state key, so each
instance shows its beacon state colour through `state_tint` (EventKinds STATE_ROWS: open amber, sealed slate).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lantern_beacon.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from ore_cart import kit, common, strut

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [900, 2000, 2]

# One row per painted part, palette names only. "state" is the exact mint that steel.gdshader swaps for the
# instance's state_tint, so the ring and cap carry the beacon's open/sealed colour from one table; the
# picture's orange (hazard) and mint lantern (live colour) are reserved meanings (LEGIBILITY.md:21,23,263).
TONES = {
    "leg": "petrol",
    "foot": "charcoal",
    "brass": "brass",
    "platform": "bone",
    "state": "mint",
    "lens": common.mix("bone", "ffffff", .55),
}

# Metres at game scale, Godot +Y up. Legs: (radius from the axis, y) at the collar, knee and foot.
LEG_ANGLES = [180, 60, -60]
LEG_PATH = [(.55, 8.7), (2.3, 1.4), (2.85, .35)]
LEG_R, LEG_SIDES = .22, 6
COLLAR = (.75, 1.0, 8.5, 9.25)          # bottom radius, top radius, y0, y1
PLATFORM = (2.1, 9.25, 9.55)
BASE_BAND = (1.3, 9.55, 10.15)
GLASS = (1.08, 10.15, 15.35)
TOP_BAND = (1.3, 15.35, 15.85)
TOP_FIT = (.95, 15.85, 16.35)
CAP = (1.35, 16.35, 19.4)
RING = (15.0, 3.27, .22, 28, 4)         # centre y, major radius, tube radius, segments, tube sides
BARS, BAR_R = 8, 1.12
BRACKET = (1.62, 15.7, 12.2)            # out radius, top y, bottom y
SIZE = {"lantern_beacon_frame": [6.85, 19.4, 5.22], "lantern_beacon_lens": [2.09, 5.2, 2.09]}


def around(n, start=0.0):
    return [start + math.tau * i / n for i in range(n)]


def frustum(s, r0, r1, y0, y1, n, color, caps=(True, True), at=(0, 0)):
    aa = around(n, math.pi / n)
    verts = [(at[0] + r * math.sin(a), y, at[1] + r * math.cos(a)) for r, y in [(r0, y0), (r1, y1)] for a in aa]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range(n, 2 * n)))
    s.add(verts, faces, color)


def leg(s, angle):
    a = math.radians(angle)
    rings = [[(r * math.sin(a) + LEG_R * math.sin(b), y, r * math.cos(a) + LEG_R * math.cos(b))
              for b in around(LEG_SIDES)] for r, y in LEG_PATH]
    n = LEG_SIDES
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    s.add([v for ring in rings for v in ring], faces, TONES["leg"])
    r, y = LEG_PATH[-1]
    frustum(s, .36, .30, 0, y + .12, 6, TONES["foot"], caps=(True, False), at=(r * math.sin(a), r * math.cos(a)))


def halo(s):
    cy, big, tube, n, m = RING
    verts = []
    for a in around(n):
        cx, cyy = big * math.sin(a), cy + big * math.cos(a)
        for b in around(m, math.pi / m):
            radial = tube * math.cos(b)
            verts.append((cx + radial * math.sin(a), cyy + radial * math.cos(a), tube * math.sin(b)))
    faces = [(i * m + j, i * m + (j + 1) % m, ((i + 1) % n) * m + (j + 1) % m, ((i + 1) % n) * m + j)
             for i in range(n) for j in range(m)]
    s.add(verts, faces, TONES["state"])


def cone(s):
    r, y0, y1 = CAP
    aa = around(12, math.pi / 12)
    verts = [(r * math.sin(a), y0, r * math.cos(a)) for a in aa] + [(0, y1, 0)]
    s.add(verts, [(i, (i + 1) % 12, 12) for i in range(12)] + [tuple(reversed(range(12)))], TONES["state"])


def steel(s):
    for angle in LEG_ANGLES:
        leg(s, angle)
    frustum(s, COLLAR[0], COLLAR[1], COLLAR[2], COLLAR[3], 12, TONES["brass"], caps=(True, False))
    for a in around(BARS, math.pi / BARS):
        x, z = BAR_R * math.sin(a), BAR_R * math.cos(a)
        strut(s, (x, GLASS[1], z), (x, GLASS[2], z), .10, .10, TONES["brass"])
    out, top, bottom = BRACKET
    for side in (-1, 1):
        strut(s, (side * 1.2, top, 0), (side * out, top, 0), .10, .10, TONES["brass"])
        strut(s, (side * out, top + .05, 0), (side * out, bottom - .05, 0), .10, .10, TONES["brass"])
        strut(s, (side * out, bottom, 0), (side * BAR_R, bottom, 0), .10, .10, TONES["brass"])
    halo(s)
    cone(s)
    kit.PARTS["Halo"] = {"reference_position": [0, RING[0], 0]}


def enamel(s):
    frustum(s, PLATFORM[0], PLATFORM[0], PLATFORM[1], PLATFORM[2], 16, TONES["platform"])
    for r, y0, y1 in (BASE_BAND, TOP_BAND, TOP_FIT):
        frustum(s, r, r, y0, y1, 12, TONES["brass"])


def lens(s):
    r, y0, y1 = GLASS
    frustum(s, r, r, 0, y1 - y0, 12, TONES["lens"])


def export(name, surfaces, sockets, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        s = kit.Surface(part, slot, smooth=smooth)
        build(s)
        s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], LANDMARK)), (name, metrics, LANDMARK)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("LANTERN_BEACON_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    export("lantern_beacon_frame", [("Frame", "steel", False, steel), ("Housing", "enamel", False, enamel)],
           {"socket_lens": [0, GLASS[1], 0], "socket_ring": [0, RING[0], 0]}, args.out_dir)
    export("lantern_beacon_lens", [("Lens", "glass", True, lens)], {}, args.out_dir)


if __name__ == "__main__":
    main()
