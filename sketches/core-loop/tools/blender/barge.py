"""Headless recipe for barge.glb and barge_fenders.glb, the lane barge in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props/barge_101.png (board alpha-props, seed 101): an open-topped
boat with a teal hull and floor, a cream inner wall, an amber rim band with hooks and latches, black side pads and two
black round thruster knobs at one end.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
barge.glb is two draws, class "landmark" in assets/asset_budgets.json: enamel (hull, strake, rim, inner wall, floor)
and steel (latches and rim hooks, copper by the lore rule). barge_fenders.glb is one elastomer draw (side pads and the
thruster knobs) at the same origin, the cart's body-and-tyre split, because three slots exceed the class's two draws.

Footprint over picture (src/world/contraptions.gd:265-323, map_highdraft.gd:43): the collider is one 14 x 2 x 14 box
centred on the origin and the ball rolls on its top at +1.0, so the floor is flat at y 1.0 and the plan is a rounded
square that covers the collider (the picture's long oval would leave the box's ends bare). The hull hangs to -3.6 as
today's cylinder does (:281-289); the knobs face -X. Repairer's hand (Switchback Enclaves: compact, serviceable):
the rim is bolted on in sections, every latch is a bolt-on plate.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/barge.py [-- --out-dir DIR]
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
LANDMARK = [3500, 2100, 2]
NAME = "barge"

TONES = {
    "hull": "petrol",
    "floor": "petrol",
    "wall": "e6d9b8",
    "rim": "amber",
    "strake": "charcoal",
    "copper": "copper",
    "pad": "charcoal",
    "knob_face": "2a3231",
}

SEG = 4
DECK_Y = 1.0
HULL = [(3.4, 2.2, -3.6), (5.4, 2.6, -3.2), (6.6, 2.8, -2.2), (7.2, 2.8, -0.8), (7.42, 2.8, 0.4), (7.5, 2.8, 1.35)]
STRAKE = (7.36, -0.25, 0.0, .07)
RIM = [(7.5, 2.8, 1.35), (7.62, 2.85, 1.45), (7.62, 2.85, 1.95), (7.05, 2.3, 1.95), (7.05, 2.3, 1.8)]
WALL = (7.05, 2.3, 1.8, DECK_Y)
SEAM = .001
LATCH_X = (-2.6, 2.6)
HOOK_X = (-4.6, 4.6)
PADS = [((-4.6, 1), .7), ((4.6, 1), .7), ((-4.6, -1), .7), ((4.6, -1), .7), ((0, 0), .7)]
KNOBS = [(-2.3, -0.55), (2.3, -0.55)]
KNOB = (.72, 7.0, 7.75, 12)
FINISH = {"Hull": {"bevel": 0, "subsurf": 1}, "Fenders": {"bevel": .06}}
SIZE = {"barge": [15.24, 5.55, 15.4], "barge_fenders": [15.41, 2.37, 15.16]}


def tone(name):
    return common.srgb(TONES[name])


def plan(h, r, y, grow=0.0):
    pts = []
    c = h - r
    for k, (sx, sz) in enumerate([(1, 1), (-1, 1), (-1, -1), (1, -1)]):
        for i in range(SEG + 1):
            a = math.pi / 2 * (k + i / SEG)
            pts.append((sx * c + (r + grow) * math.cos(a), y, sz * c + (r + grow) * math.sin(a)))
    return pts


def bands(s, rings, color, cap_bottom=False, cap_top=False):
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    faces = [(r * n + i, r * n + (i + 1) % n, (r + 1) * n + (i + 1) % n, (r + 1) * n + i)
             for r in range(len(rings) - 1) for i in range(n)]
    if cap_bottom:
        faces.append(tuple(reversed(range(n))))
    if cap_top:
        faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    s.add(verts, faces, color)


def shell(s):
    rows = [(r, "hull") for r in HULL[:-1]] + [(HULL[-1], "hull"), (HULL[-1][:2] + (HULL[-1][2] + SEAM,), "rim")]
    rows += [(r, "rim") for r in RIM[1:]]
    h, r, y1, y0 = WALL
    rows += [((h, r, y1 - SEAM), "wall"), ((h, r, y0 + SEAM), "wall"), ((h, r, y0), "floor")]
    rings = [plan(*row) for row, _ in rows]
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    colors = [tone(t) for _, t in rows for _ in range(n)]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    faces += [tuple(reversed(range(n))), tuple(range((len(rings) - 1) * n, len(rings) * n))]
    s.add(verts, faces, colors=colors)


def hull(s):
    shell(s)
    h, y0, y1, out = STRAKE
    r = HULL[3][1]
    bands(s, [plan(h, r, y0), plan(h, r, y0, out), plan(h, r, y1, out), plan(h, r, y1)], tone("strake"))


def latch(s, x, side):
    z = side * 7.62
    s.box((.7, .5, .08), (x, 1.62, z + side * .04), tone("copper"))
    s.box((.16, .62, .1), (x, 1.1, z + side * .03), tone("copper"))


def hook(s, x, side):
    z = side * 7.0
    s.box((.08, .42, .08), (x, 1.72, z - side * .06), tone("copper"))
    s.box((.08, .08, .22), (x, 1.53, z - side * .14), tone("copper"))


def steel(s):
    for side in (-1, 1):
        for x in LATCH_X:
            latch(s, x, side)
        for x in HOOK_X:
            hook(s, x, side)


def enamel(s):
    hull(s)


def fenders(s):
    for (along, side), y in PADS:
        if side == 0:
            s.box((.2, .8, 1.5), (7.5, y, along), tone("pad"))
        else:
            s.box((1.5, .8, .2), (along, y, side * 7.48), tone("pad"))
    r, x0, x1, n = KNOB
    for z, y in KNOBS:
        aa = [math.tau * i / n for i in range(n)]
        rings = [[(-x, y + rr * math.cos(a), z + rr * math.sin(a)) for a in aa] for x, rr in
                 ((x0, r), (x1 - .12, r), (x1, r * .82))]
        bands(s, rings, tone("pad"), cap_top=False)
        hub = [[(-x, y + rr * math.cos(a), z + rr * math.sin(a)) for a in aa] for x, rr in ((x1, r * .82), (x1, r * .4), (x1 + .06, r * .34))]
        bands(s, hub, tone("knob_face"), cap_top=True)


def export(name, surfaces, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        sf = kit.Surface(part, slot, smooth=smooth)
        build(sf)
        sf.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    size = metrics["bounds"]["size"]
    print("BARGE_SIZE", name, [round(v, 3) for v in size], metrics["triangles"], metrics["vertices"], metrics["draws"],
          "min", [round(v, 3) for v in metrics["bounds"]["min"]] if "min" in metrics["bounds"] else metrics["bounds"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], LANDMARK)), (name, metrics, LANDMARK)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("BARGE_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish.enable(bevel=.04, **kit.BAKE)
    kit.FINISH.update(FINISH)
    export(NAME, [("Hull", "enamel", False, enamel), ("Fittings", "steel", False, steel)], args.out_dir)
    export("barge_fenders", [("Fenders", "elastomer", False, fenders)], args.out_dir)


if __name__ == "__main__":
    main()
