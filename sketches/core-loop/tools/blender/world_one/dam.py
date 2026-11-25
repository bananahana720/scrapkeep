import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common
from common import Part

BAND = (1500, 3000)
X_HALF = 132.0
Z0, Z1 = 26.0, 115.2
ROWS = 7
FACE = 0.0
FRAMES = [
    (-70.0, 50.0, 14.0, 21.0, "hatch", "petrol"),
    (-14.0, 84.0, 14.0, 17.0, "patch", "oxide"),
    (14.0, 58.0, 14.0, 19.0, "brace", "petrol"),
    (70.0, 90.0, 14.0, 20.0, "hatch", "oxide"),
    (124.0, 62.0, 12.0, 24.0, "patch", "petrol"),
]


def courses(p, rng):
    pitch = (Z1 - Z0) / ROWS
    for row in range(ROWS):
        zc = Z0 + pitch * (row + 0.5)
        h = pitch - 0.7
        x = -X_HALF
        first = True
        while x < X_HALF - 1.0:
            w = rng.uniform(8.0, 34.0) if first else rng.uniform(30.0, 50.0)
            if X_HALF - (x + w) < 22.0:
                w = X_HALF - x
            first = False
            xc = x + w / 2
            t = rng.uniform(0.0, 0.32)
            base = common.mix("sandstone", "bone", t)
            base = tuple(c * (0.9 + 0.1 * row / ROWS) for c in base)
            p.box("paint", (w - 0.6, 0.6, h), loc=(xc, 0.25, zc), color=base)
            lip = common.mix("sandstone", "bone", min(1.0, t + 0.28))
            p.box("paint", (w - 2.2, 0.3, h - 2.0), loc=(xc, 0.7, zc + 0.15), color=lip)
            x += w


def bolt_run(p, a, b, spacing):
    ax, az = a
    bx, bz = b
    n = max(1, int(round(((bx - ax) ** 2 + (bz - az) ** 2) ** 0.5 / spacing)))
    for i in range(n + 1):
        t = i / n
        p.bolt((ax + (bx - ax) * t, 1.08, az + (bz - az) * t), (0, 1, 0), r=0.28, h=0.1, segs=4)


def frame(p, spec, rng):
    cx, cz, w, h, kind, plate = spec
    hw, hh = w / 2, h / 2
    for k, dx in enumerate((-0.32, 0.08, 0.36)):
        drop = rng.uniform(4.0, 8.0)
        p.box("rubber", (0.7, 0.12, drop), loc=(cx + dx * w, 0.62, cz - hh - drop / 2 + 0.4))
    p.box("paint", (w - 1.6, 0.3, h - 1.6), loc=(cx, 0.85, cz), color=plate)
    for zc in (cz - hh + 0.5, cz + hh - 0.5):
        p.box("bare_metal", (w, 0.45, 1.0), loc=(cx, 0.975, zc))
    for xc in (cx - hw + 0.5, cx + hw - 0.5):
        p.box("bare_metal", (1.0, 0.45, h - 2.0), loc=(xc, 0.975, cz))
    if kind == "hatch":
        door = "bone" if plate == "petrol" else "sandstone"
        p.box("paint", (w * 0.5, 0.15, h * 0.5), loc=(cx, 1.075, cz - h * 0.05), color=door)
        p.box("bare_metal", (w * 0.36, 0.1, 0.5), loc=(cx, 1.15, cz - h * 0.05 + 0.2))
        for dz in (-h * 0.2, h * 0.1):
            p.box("bare_metal", (0.9, 0.15, 1.0), loc=(cx - w * 0.25, 1.12, cz + dz))
    elif kind == "patch":
        p.box("paint", (w * 0.62, 0.2, h * 0.34), loc=(cx - 0.6, 1.0, cz + h * 0.12), rot=(0, 0.05, 0), color="oxide" if plate == "petrol" else "petrol")
        p.box("paint", (w * 0.5, 0.2, h * 0.26), loc=(cx + 0.9, 1.0, cz - h * 0.18), rot=(0, -0.04, 0), color="bone")
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.bolt((cx + sx * w * 0.36, 1.05, cz + sz * h * 0.28), (0, 1, 0), r=0.28, h=0.12, segs=4)
    else:
        a = (cx - hw + 1.0, 0.95, cz - hh + 1.0)
        b = (cx + hw - 1.0, 0.95, cz + hh - 1.0)
        p.beam("bare_metal", a, b, 0.5)
    bolt_run(p, (cx - hw + 0.5, cz + hh - 0.5), (cx + hw - 0.5, cz + hh - 0.5), 4.6)
    bolt_run(p, (cx - hw + 0.5, cz - hh + 0.5), (cx + hw - 0.5, cz - hh + 0.5), 4.6)


def main():
    common.reset()
    a = common.args()
    rng = random.Random("scrapkeep-dam-i01")
    p = Part("DamFacade")
    courses(p, rng)
    for spec in FRAMES:
        frame(p, spec, rng)
    root = common.empty("Dam")
    obj = p.to_object((0, 0, 0), root)
    ok = common.report("dam", [("facade detail", common.tris(obj), BAND)])
    common.export(root, a["out"] or os.path.join(common.MODELS, "world_one", "dam.glb"))
    if not ok:
        raise SystemExit("dam budget out of range")


main()
