"""Detail layer 1 for the gauge dial (wave 12-D RECIPE-WAVE, DETAIL-CART loop): one additive steel shell in the
`detail` class (assets/asset_budgets.json), in the foot frame of gauge_dial_stand/_bezel/_face (static parts only; the
needle turns, so nothing here rides it). Closes gap list A lines A1 to A6 and A9 to A12
(artifacts/local/alpha/push/w12/units/rc-gauge_dial/gaps_A.md): face screws, hub seat, spigot threads, a round arm
boss, a block service plate (Switchback Enclaves: the service bolts stay in sight), the bezel's service bolt row, a
weld bead, a hose clamp on the stem and a rust patch with rivets on the case. Colours come from gauge_dial.TONES;
nothing moves or duplicates base geometry.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/gauge_dial_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gauge_dial as gd
import polish
from gauge_dial import kit, common, cyl, dial_xy, around, TONES

DETAIL = [1500, 3000, 1]
BASE_BOUNDS = ([-1.14, 0, -.31], [1.14, 4.54, .25])
MARGIN = .12
Z_FACE = gd.FACE_Z + .004


def lip_ring(s, r0, r1, z0, z1, n, color):
    pts = [(r0, z0), (r1, z0), (r1, z1), (r0, z1)]
    verts = [(*dial_xy(a, r), z) for r, z in pts for a in around(n)]
    faces = [(k * n + i, k * n + (i + 1) % n, ((k + 1) % 4) * n + (i + 1) % n, ((k + 1) % 4) * n + i)
             for k in range(4) for i in range(n)]
    s.add(verts, faces, color)


def radial_plate(s, a0, a1, r0, r1, z0, z1, n, color):
    aa = [a0 + (a1 - a0) * i / n for i in range(n + 1)]
    m = n + 1
    corners = [(r0, z0), (r1, z0), (r1, z1), (r0, z1)]
    verts = [(*dial_xy(a, r), z) for r, z in corners for a in aa]
    faces = [(k * m + i, k * m + i + 1, ((k + 1) % 4) * m + i + 1, ((k + 1) % 4) * m + i) for k in range(4) for i in range(n)]
    faces += [tuple(k * m for k in reversed(range(4))), tuple(k * m + n for k in range(4))]
    s.add(verts, faces, color)


def build(s):
    for a in (math.radians(165), math.radians(195)):
        x, y = dial_xy(a, .46)
        cyl(s, (x, y, Z_FACE - .006), (x, y, Z_FACE + .022), .032, 6, TONES["bolt"], caps=(False, True), start=0.0)
    cyl(s, (0, gd.FACE_Y, Z_FACE - .006), (0, gd.FACE_Y, Z_FACE + .008), .14, 12, TONES["collar"])
    lip_ring(s, .875, .905, Z_FACE - .006, Z_FACE + .03, 24, TONES["felt"])
    r, y0, y1 = gd.SPIGOT
    for k in range(4):
        y = y0 + .035 + k * .055
        cyl(s, (0, y, 0), (0, y + .022, 0), r + .018, 8, TONES["collar"])
    r, x0, x1, y = gd.BOSS
    cyl(s, (x0, y, 0), (x1 - .005, y, 0), r + .01, 12, TONES["stem"])
    (bx, by, bz), (cx, cy, cz) = gd.BLOCK
    s.box((bx - .12, by - .12, .03), (cx, cy, cz + bz / 2 + .012), TONES["stem"])
    for dx in (-1, 1):
        for dy in (-1, 1):
            px, py = cx + dx * (bx / 2 - .12), cy + dy * (by / 2 - .11)
            cyl(s, (px, py, cz + bz / 2 + .02), (px, py, cz + bz / 2 + .05), .028, 6, TONES["bolt"], caps=(False, True), start=0.0)
    for a in around(12, math.pi / 12):
        x, y = dial_xy(a, 1.01)
        cyl(s, (x, y, .18), (x, y, .235), .045, 6, TONES["bolt"], caps=(False, True), start=0.0)
    (ax, ay, az), (acx, acy, acz) = gd.ARM
    top = acy + ay / 2
    for k in range(6):
        z = -az / 2 + .04 + k * (az - .08) / 5
        cyl(s, (bx / 2 + .02, top - .01, z), (bx / 2 + .02, top + .022, z), .036, 6, TONES["bolt"], caps=(False, True))
    r = gd.STEM[0]
    cyl(s, (0, 1.30, 0), (0, 1.37, 0), r + .02, 12, TONES["felt"])
    s.box((.07, .07, .08), (0, 1.335, r + .05), TONES["felt"])
    cyl(s, (-.06, 1.335, r + .05), (.06, 1.335, r + .05), .022, 6, TONES["bolt"], start=0.0)
    a0, a1 = math.radians(240), math.radians(280)
    radial_plate(s, a0, a1, 1.14, 1.18, -.14, .11, 5, TONES["redline"])
    for a in (a0 + .07, a1 - .07):
        for z in (-.09, .05):
            x0, y0 = dial_xy(a, 1.17)
            x1, y1 = dial_xy(a, 1.20)
            cyl(s, (x0, y0, z), (x1, y1, z), .022, 6, TONES["bolt"], caps=(False, True), start=0.0)


def export(name, part, build_fn, out_dir, bounds=BASE_BOUNDS):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(part, "steel", smooth=False)
    build_fn(s)
    s.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], DETAIL)), (name, metrics, DETAIL)
    assert metrics["materials"] == ["steel"], (name, metrics["materials"])
    lo, hi = bounds
    b = metrics["bounds"]
    assert all(b["min"][k] >= lo[k] - MARGIN and b["max"][k] <= hi[k] + MARGIN for k in range(3)), (name, b, bounds)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("GAUGE_DIAL_DETAIL", name, json.dumps(row, sort_keys=True))
    return row


def main():
    polish.enable(bevel=.02, bevel_min=.25, **gd.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(gd.MODELS))
    args = parser.parse_args(argv)
    export("gauge_dial_detail1", "DialDetail1", build, args.out_dir)


if __name__ == "__main__":
    main()
