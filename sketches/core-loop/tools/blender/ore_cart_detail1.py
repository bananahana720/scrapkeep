"""Detail layer 1 for the ore cart (wave 12 DETAIL-CART): an additive shell drawn at the body's origin and scale,
one draw in the enamel slot, closing gap list A of the FLUX picture probes/gen2/ref/cart_101.png against the base
render (tub ribs, a chunk-filled heap with pale slabs, hitch block and pin, chassis bolts, hub boss and ring, front
cross-member, strut feet). It moves and duplicates no base geometry; dimensions and tones come from ore_cart.py.
The game drops it by distance (visibility range), so it doubles as the first level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/ore_cart_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
BASE = HERE / "ore_cart.py"
oc = {"__file__": str(BASE), "__name__": "ore_cart_tables"}
exec(compile(BASE.read_text().rsplit("\nmain()", 1)[0], str(BASE), "exec"), oc)
kit, common = oc["kit"], oc["common"]

NAME = "ore_cart_detail1"
BUDGET = [900, 2000, 1]
SIZE = [2.17, 1.707, 3.347]
PHI = (math.sqrt(5) - 1) / 2


def tone(name, k=0):
    t = oc["tone"](name, k)
    return common.srgb(t) if isinstance(t, str) else t


def frac(x):
    return x - math.floor(x)


def rock(s, x, z, size, yaw, flat, color):
    y = oc["heap_y"](x, z) - size * .25
    rot = Euler((0, math.radians(yaw), 0), "YXZ").to_matrix()
    h = size / 2
    top = .8 if flat else .68
    height = size * (.38 if flat else .55)
    skew = Vector((size * .08, 0, -size * .06))
    low = [Vector((-h, 0, -h * .8)), Vector((h, 0, -h)), Vector((h * .9, 0, h)), Vector((-h, 0, h * .85))]
    high = [v * top + Vector((0, height, 0)) + skew for v in low]
    verts = [tuple(rot @ v + Vector((x, y, z))) for v in low + high]
    s.add(verts, [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], color)


def heap(s):
    n = 40
    ex, ez = oc["HEAP_EDGE"][0] - .14, oc["HEAP_EDGE"][1] - .14
    for i in range(n):
        x = (frac(i * PHI + .31) * 2 - 1) * ex
        z = ((i + .5) / n * 2 - 1) * ez
        pale = i % 4 == 1
        size = (.34 if pale else .25) + .08 * frac(i * .4142)
        color = tone("ore_pale") if pale else tone("ore", i)
        rock(s, x, z, size, (i * 47) % 90, pale, color)


def tube(s, a, b, w, h, color):
    oc["strut"](s, a, b, w, h, color)


def ribs(s):
    bw, bl, _, by = oc["TUB_BOTTOM"]
    tw, tl, _, ty = oc["TUB_TOP"]
    out = .04
    for sx in (-1, 1):
        for z in (-.55, .55):
            tube(s, (sx * (bw + out), by + .02, z * bl / tl), (sx * (tw + out), ty - .02, z), .09, .07, tone("tub"))
    for sz in (-1, 1):
        tube(s, (0, by + .02, sz * (bl + out)), (0, ty - .02, sz * (tl + out)), .09, .07, tone("tub"))


def disc(s, center, axis, r, depth, n, color, cap=True):
    c = Vector(center)
    d = Vector(axis) * depth
    u = Vector((0, 1, 0))
    v = Vector(axis).cross(u)
    ring0 = [c + (u * math.cos(a) + v * math.sin(a)) * r for a in kit.angles(n, closed=True)]
    ring1 = [p + d for p in ring0]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if cap:
        faces.append(tuple(range(n, 2 * n)))
    s.add([tuple(p) for p in ring0 + ring1], faces, color)


def hubs(s):
    for name, (x, y, z) in oc["SOCKETS"].items():
        if not name.startswith("socket_wheel_"):
            continue
        sx = 1 if x > 0 else -1
        face = x + sx * (oc["WHEEL_W"] / 2 - .015)
        ring = [(face + sx * .055, y + r * math.cos(a), z + r * math.sin(a)) for r in (.20, .15) for a in kit.angles(8, closed=True)]
        s.add(ring, [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)], tone("brass"))
        disc(s, (face, y, z), (sx, 0, 0), .20, .055, 8, tone("brass"), cap=False)
        disc(s, (face + sx * .03, y, z), (sx, 0, 0), .10, .07, 8, tone("brass"))


def bolt(s, center, axis):
    disc(s, center, axis, .03, .025, 6, tone("tub"))


def chassis(s):
    rx, ry, tip = oc["RAIL_X"], oc["RAIL_Y"], oc["TOW_TIP"]
    s.box((2 * rx + .14, .13, .13), (0, ry, -1.08), tone("chassis"))
    hz = -1.78
    arm = rx * (tip - hz) / (tip + 1.12)
    s.box((2 * abs(arm) + .16, .15, .18), (0, ry, hz), tone("chassis"))
    pin = Vector((0, ry + .075, hz))
    s.add([tuple(pin + Vector((.035 * math.cos(a), dy, .035 * math.sin(a)))) for dy in (0, .12) for a in kit.angles(6, closed=True)],
          [(i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i) for i in range(6)] + [tuple(range(6, 12))], tone("brass"))
    for sx in (-1, 1):
        for z in (-.25, .25):
            face = sx * (rx + .07)
            s.box((.03, .2, .26), (face + sx * .015, ry + .02, z), tone("chassis"))
            bolt(s, (face + sx * .03, ry + .02, z), (sx, 0, 0))
        bolt(s, (sx * (abs(arm) + .08), ry, hz), (sx, 0, 0))


def build(s):
    start = len(s.verts)
    ribs(s)
    kit.PARTS["Ribs"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, 1.0, 0], "merged_mesh": "Detail1"}
    start = len(s.verts)
    heap(s)
    kit.PARTS["OreChunks"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, oc["HEAP_PEAK"], 0], "merged_mesh": "Detail1"}
    start = len(s.verts)
    chassis(s)
    hubs(s)
    kit.PARTS["Hardware"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, oc["RAIL_Y"], 0], "merged_mesh": "Detail1"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(oc["MODELS"]))
    args = parser.parse_args(argv)
    oc["polish_on"]()
    common.reset()
    kit.PARTS.clear()
    root = common.empty(NAME)
    s = kit.Surface("Detail1", "enamel", smooth=False)
    build(s)
    s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    path = Path(args.out_dir) / (NAME + ".glb")
    common.export(root, str(path))
    m = kit.gltf_metrics(path)
    assert all(m[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], BUDGET)), (NAME, m, BUDGET)
    assert m["materials"] == ["enamel"], m["materials"]
    size = m["bounds"]["size"]
    print("ORE_CART_DETAIL_SIZE", NAME, [round(v, 3) for v in size])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE)), (NAME, size, SIZE)
    row = {**m, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("ORE_CART_EXPORT", NAME, json.dumps(row, sort_keys=True))


if __name__ == "__main__":
    main()
