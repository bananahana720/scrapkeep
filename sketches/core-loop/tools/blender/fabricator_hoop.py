"""Headless recipe for fabricator_hoop.glb, the drive-through fabricator hoop in the approved FLUX.1 schnell concept
picture artifacts/local/alpha/push/w12/concepts/boards/alpha-props/fabricator_hoop_101.png (board alpha-props, seed
101): a thick upright ring with slotted faces, a hex nut on its crown, a dark pedestal with an ivory plate, and brass
splayed feet with pale pads.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
Two draws, class "landmark" in assets/asset_budgets.json: steel (ring, crown nut, feet and pads) and enamel (footings
and their plates). The ring is painted the steel shader's state key, so each instance shows its live state through
`state_tint` (mint when the part is affordable, slate when not, LEGIBILITY.md:24,263); the nut and feet stay brass.

Footprint over picture (src/build/fabricators.gd:17-18,147-160): the ball rolls through the ring, whose centre sits
RING - SINK = 3.5 m up with its lower arc buried, so the picture's single pedestal under the ring would block the lane.
The pedestal becomes two footings that clasp the ring where it meets the ground, each with the picture's plate and
feet. The price text, the part glyph and the ground chevrons stay the code's own nodes; sockets mark where they sit.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/fabricator_hoop.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common, frustum
import polish

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [2500, 2000, 2]
NAME = "fabricator_hoop"

TONES = {
    "state": "mint",
    "brass": "copper",
    "pad": "bone",
    "footing": "charcoal",
    "plate": "bone",
}

RING_Y, RING_IN, RING_OUT, RING_DEPTH = 3.5, 4.65, 5.35, .7
RING_SEGMENTS, RING_CHAMFER = 56, .12
RING_CUT_Y = .3
SILL = (.14, .55, .3)
NUT = (1.0, 7.85, 9.05)
FOOTING = (2.8, 5.3, .8, .22, 1.9)
PLATE = (1.2, .7, 1.3, .06)
FOOT = (.3, .6, .72, .28)
SOCKETS = {"socket_glyph": [0, RING_Y + 1.2, 0], "socket_prompt": [0, 8.5, 0]}
SIZE = [11.3, 9.05, 2.8]


def tone(name):
    return common.srgb(TONES[name])


def ring_arc(s):
    rc, half_r, half_z, c = (RING_IN + RING_OUT) / 2, (RING_OUT - RING_IN) / 2, RING_DEPTH / 2, RING_CHAMFER
    section = [(half_r, -half_z + c), (half_r, half_z - c), (half_r - c, half_z), (-half_r + c, half_z),
               (-half_r, half_z - c), (-half_r, -half_z + c), (-half_r + c, -half_z), (half_r - c, -half_z)]
    start = math.asin((RING_CUT_Y - RING_Y) / rc)
    end = math.pi - start
    m = len(section)
    verts = []
    for i in range(RING_SEGMENTS + 1):
        a = start + (end - start) * i / RING_SEGMENTS
        cx, cy = math.cos(a), math.sin(a)
        for dr, dz in section:
            verts.append(((rc + dr) * cx, RING_Y + (rc + dr) * cy, dz))
    faces = [(i * m + j, i * m + (j + 1) % m, (i + 1) * m + (j + 1) % m, (i + 1) * m + j)
             for i in range(RING_SEGMENTS) for j in range(m)]
    s.add(verts, faces, tone("state"))


def sill(s):
    x = FOOTING[0] + .05
    h, hz, top = SILL
    verts = [(-x, 0.0, -hz), (-x, 0.0, hz), (-x, h, top), (-x, h, -top), (x, 0.0, -hz), (x, 0.0, hz), (x, h, top), (x, h, -top)]
    s.add(verts, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (0, 3, 2, 1), (4, 5, 6, 7)], tone("state"))


def nut(s):
    r, y0, y1 = NUT
    frustum(s, r, r, y0, y1, 6, tone("brass"))


def footing_outline(side, y):
    x0, x1, hz, c, _ = FOOTING
    lo, hi = sorted((side * x0, side * x1))
    return [(lo + c, y, -hz), (hi - c, y, -hz), (hi, y, -hz + c), (hi, y, hz - c),
            (hi - c, y, hz), (lo + c, y, hz), (lo, y, hz - c), (lo, y, -hz + c)]


def footing(s, side):
    h = FOOTING[4]
    rings = [footing_outline(side, 0.0), footing_outline(side, h)]
    n = 8
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
    s.add([v for r in rings for v in r], faces, tone("footing"))
    w, ph, py, t = PLATE
    cx = side * (FOOTING[0] + FOOTING[1]) / 2
    for face in (-1, 1):
        s.box((w, ph, t), (cx, py, face * (FOOTING[2] + t / 2)), tone("plate"))


def foot(s, at, out, along, reach=None):
    hw, full, hwall, htip = FOOT
    reach = reach or full
    ox, oz = out
    ax, az = along
    base = [(at[0] + ax * k * hw + ox * d, 0.0, at[1] + az * k * hw + oz * d) for d in (0, reach) for k in (-1, 1)]
    top = [(at[0] + ax * k * hw + ox * d, hy, at[1] + az * k * hw + oz * d) for d, hy in ((0, hwall), (reach, htip)) for k in (-1, 1)]
    verts = base + top
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    s.add(verts, faces, tone("brass"))
    slope = (reach, htip - hwall)
    ln = math.hypot(*slope)
    nrm = (-slope[1] / ln, slope[0] / ln)
    pad = []
    for d0, k in ((.12, -1), (.12, 1), (reach - .08, 1), (reach - .08, -1)):
        hy = hwall + (htip - hwall) * d0 / reach
        kk = k * (hw - .08)
        pad.append((at[0] + ax * kk + ox * (d0 + nrm[0] * .02), hy + nrm[1] * .02, at[1] + az * kk + oz * (d0 + nrm[0] * .02)))
    s.add(pad, [(0, 1, 2, 3)], tone("pad"))


def feet(s, side):
    x0, x1, hz, _, _ = FOOTING
    cx = side * (x0 + x1) / 2
    for face in (-1, 1):
        foot(s, (cx, face * hz), (0, face), (1, 0))
    foot(s, (side * x1, 0), (side, 0), (0, 1), reach=.35)


def steel(s):
    ring_arc(s)
    sill(s)
    nut(s)
    for side in (-1, 1):
        feet(s, side)
    kit.PARTS["Ring"] = {"reference_position": [0, RING_Y, 0]}


def enamel(s):
    for side in (-1, 1):
        footing(s, side)


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
    size = metrics["bounds"]["size"]
    print("FABRICATOR_HOOP_SIZE", name, [round(v, 3) for v in size], metrics["triangles"], metrics["vertices"], metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], LANDMARK)), (name, metrics, LANDMARK)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE)), (name, size, SIZE)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("FABRICATOR_HOOP_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    export(NAME, [("Hoop", "steel", False, steel), ("Footings", "enamel", False, enamel)], SOCKETS, args.out_dir)


if __name__ == "__main__":
    main()
