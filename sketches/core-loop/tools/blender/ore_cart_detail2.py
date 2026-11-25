"""Detail layer 2 for the ore cart (wave 12 DETAIL-CART, the moving baseline): an additive shell at the body's origin
and scale, one draw in the enamel slot, closing gap list C of the FLUX image-to-image re-imagining of the pass-1 render
(units/detail-cart/ref/cart_pass2.png): hub bolt circles, a bolt row on each rail, a T-handled hitch pin, a round tow
ball, filler chunks over the bare mound, a bevel on the rim's inner edge, and tread blocks on the tyres. Tones and
dimensions come from ore_cart.py; helpers from ore_cart_detail1.py. The game drops it nearer than detail 1.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/ore_cart_detail2.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("ore_cart_detail1", HERE / "ore_cart_detail1.py")
d1 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(d1)
oc, kit, common, tone, frac, rock, disc = d1.oc, d1.kit, d1.common, d1.tone, d1.frac, d1.rock, d1.disc

NAME = "ore_cart_detail2"
BUDGET = [1500, 3000, 1]
SIZE = [2.13, 1.954, 3.753]


def bolt(s, center, axis):
    disc(s, center, axis, .028, .025, 6, tone("tub"))


def hub_bolts(s):
    for name, (x, y, z) in oc["SOCKETS"].items():
        if not name.startswith("socket_wheel_"):
            continue
        sx = 1 if x > 0 else -1
        face = x + sx * (oc["WHEEL_W"] / 2 - .015 + .055)
        for a in kit.angles(5, start=.3, closed=True):
            bolt(s, (face, y + .135 * math.cos(a), z + .135 * math.sin(a)), (sx, 0, 0))


def rail_bolts(s):
    rx, ry = oc["RAIL_X"], oc["RAIL_Y"]
    for sx in (-1, 1):
        for z in (-.85, -.55, .55, .85):
            bolt(s, (sx * (rx + .07), ry - .02, z), (sx, 0, 0))


def hitch_handle(s):
    ry = oc["RAIL_Y"]
    s.box((.16, .035, .035), (0, ry + .075 + .12, -1.78), tone("brass"))


def tow_ball(s):
    c = Vector((0, oc["RAIL_Y"], oc["TOW_TIP"] - oc["BALL_R"]))
    r = oc["BALL_R"] * 1.08
    verts = [tuple(c + Vector((0, -r, 0)))]
    for k in range(1, 5):
        phi = math.pi * k / 5
        for a in kit.angles(8, closed=True):
            verts.append(tuple(c + Vector((r * math.sin(phi) * math.cos(a), -r * math.cos(phi), r * math.sin(phi) * math.sin(a)))))
    verts.append(tuple(c + Vector((0, r, 0))))
    faces = [(0, 1 + (i + 1) % 8, 1 + i) for i in range(8)]
    for k in range(3):
        faces += [(1 + k * 8 + i, 1 + k * 8 + (i + 1) % 8, 1 + (k + 1) * 8 + (i + 1) % 8, 1 + (k + 1) * 8 + i) for i in range(8)]
    top = len(verts) - 1
    faces += [(1 + 24 + i, 1 + 24 + (i + 1) % 8, top) for i in range(8)]
    s.add(verts, faces, tone("brass"))


def filler(s):
    n = 30
    ex, ez = oc["HEAP_EDGE"][0] - .12, oc["HEAP_EDGE"][1] - .12
    for i in range(n):
        x = (frac(i * d1.PHI + .81) * 2 - 1) * ex
        z = ((i + .0) / n * 2 - 1) * ez + .04
        pale = i % 5 == 3
        rock(s, x, z, .24 + .06 * frac(i * .7071), (i * 61) % 90, pale, tone("ore_pale") if pale else tone("ore", i + 2))


def rim_bevel(s):
    hw, hl, c, y = oc["RIM"][2]
    outer = oc["ring"](hw + .03, hl + .03, c, y + .012)
    inner = oc["ring"](hw - .02, hl - .02, c, y - .03)
    oc["bands"](s, [outer, inner], [tone("rim")] * 2)


def tread(s):
    r0, w = oc["WHEEL_R"], oc["WHEEL_W"]
    for name, (x, y, z) in oc["SOCKETS"].items():
        if not name.startswith("socket_wheel_"):
            continue
        for i, a in enumerate(kit.angles(10, closed=True)):
            off = .04 if i % 2 else -.04
            radial = Vector((0, math.cos(a), math.sin(a)))
            tangent = Vector((0, -math.sin(a), math.cos(a)))
            axle = Vector((1, 0, 0))
            centre = Vector((x + off * .5, y, z)) + radial * (r0 - .03)
            hx, hr, ht = w * .28, .02, .04
            low = [centre + axle * sa * hx + tangent * st * ht for sa, st in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            high = [p + radial * hr * 2 for p in low]
            s.add([tuple(p) for p in low + high], [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)],
                  tone("tyre", 1))


def build(s):
    parts = [("Hardware", hub_bolts, [0, oc["WHEEL_R"], 0]), ("RailBolts", rail_bolts, [0, oc["RAIL_Y"], 0]),
             ("Hitch", hitch_handle, [0, oc["RAIL_Y"], -1.78]), ("TowBall", tow_ball, [0, oc["RAIL_Y"], oc["TOW_TIP"]]),
             ("OreFiller", filler, [0, oc["HEAP_PEAK"], 0]), ("RimBevel", rim_bevel, [0, oc["RIM"][2][3], 0]),
             ("Tread", tread, [0, oc["WHEEL_R"], 0])]
    for pname, fn, ref in parts:
        start = len(s.verts)
        fn(s)
        kit.PARTS[pname] = {"vertex_range": [start, len(s.verts)], "reference_position": ref, "merged_mesh": "Detail2"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(oc["MODELS"]))
    args = parser.parse_args(argv)
    oc["polish_on"]()
    common.reset()
    kit.PARTS.clear()
    root = common.empty(NAME)
    s = kit.Surface("Detail2", "enamel", smooth=False)
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
