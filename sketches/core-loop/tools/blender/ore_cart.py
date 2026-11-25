"""Headless recipe for ore_cart_body.glb and ore_cart_wheel.glb, the haul cart in the FLUX.1 schnell
concept sheet artifacts/local/alpha/push/w12/probes/gen2/ref/cart_101.png (cart_202.png is the other side).

Same route as today's cart (dig_mechanical/cart_body.py, cart_wheel.py): kit.Surface metre-space parts,
one prop-class draw per GLB, COLOR_0 vertex colour, and a material named for its runtime slot
(dig_scenery.gd SLOTS: enamel for the painted body, elastomer for the tyres). Wheels are a separate GLB
placed with an identity basis at the body's socket_wheel_* nodes, so the tyre is mirror-symmetric.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/ore_cart.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "dig_mechanical"))
sys.path.insert(0, str(HERE))
import kit
import common
import polish

MODELS = kit.SKETCH / "assets/models"

PROP = [750, 610, 1]
FINISH = {"Tub": {"bevel": .04}, "Tyre": {"bevel": 0}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


TONES = {
    "tub": "bone",
    "rim": "copper",
    "chassis": "petrol",
    "ore": [common.mix("oxide", "charcoal", .5), common.mix("oxide", "bone", .35), common.mix("oxide", "charcoal", .2), "oxide"],
    "ore_pale": common.mix("mint", "sandstone", .5),
    "brass": "brass",
    "tyre": ["charcoal", "333936"],
}

TUB_BOTTOM = (.60, 1.05, .12, .58)
TUB_TOP = (.92, 1.42, .18, 1.40)
RIM = [(1.00, 1.50, .22, 1.38), (1.00, 1.50, .22, 1.54), (.86, 1.36, .16, 1.54)]
HEAP_EDGE = (.90, 1.40, .18, 1.50)
HEAP_PEAK = 1.86
HEAP_SHOULDER = [.03, -.04, .05, -.02, .06, -.05, .01, .04]
WHEEL_R, WHEEL_W = .42, .28
WHEEL_X, WHEEL_Z = .86, .80
RAIL_X, RAIL_Y = .62, .50
TOW_TIP, BALL_R = -2.12, .12
LUMPS = [
    ("cube", 0.00, -0.15, .30, 20, 12, "ore"), ("cube", -0.40, 0.55, .26, 50, -10, "ore_pale"),
    ("cube", 0.42, 0.30, .28, 75, 15, "ore"), ("cube", -0.30, -0.70, .26, 35, 8, "ore_pale"),
    ("cube", 0.35, -0.75, .24, 10, -14, "ore"), ("tent", -0.58, -0.10, .30, 0, 0, "ore"),
    ("tent", 0.58, -0.25, .28, 40, 0, "ore_pale"), ("tent", 0.10, 0.85, .30, 15, 0, "ore"),
    ("tent", -0.12, 0.25, .26, 70, 0, "ore_pale"), ("tent", 0.62, 0.95, .24, 25, 0, "ore"),
    ("tent", -0.62, 1.00, .24, 55, 0, "ore"), ("tent", 0.05, -1.05, .26, 5, 0, "ore"),
    ("tent", -0.65, -1.05, .22, 80, 0, "ore_pale"),
]
SOCKETS = {**{f"socket_wheel_{p}": [x * WHEEL_X, WHEEL_R, z * WHEEL_Z] for p, x, z in
              [("fl", -1, -1), ("fr", 1, -1), ("rl", -1, 1), ("rr", 1, 1)]},
           "socket_tow": [0, RAIL_Y, TOW_TIP - BALL_R]}
SIZE = {"ore_cart_body": [2.0, 1.72, 3.84], "ore_cart_wheel": [.34, .84, .80]}


def tone(name, k=0):
    row = TONES[name]
    return row[k % len(row)] if isinstance(row, list) else row


def ring(hw, hl, c, y):
    return [(-hw + c, y, -hl), (hw - c, y, -hl), (hw, y, -hl + c), (hw, y, hl - c),
            (hw - c, y, hl), (-hw + c, y, hl), (-hw, y, hl - c), (-hw, y, -hl + c)]


def bands(s, rings, colors):
    n = len(rings[0])
    verts = [v for r in rings for v in r]
    faces = [(r * n + i, r * n + (i + 1) % n, (r + 1) * n + (i + 1) % n, (r + 1) * n + i)
             for r in range(len(rings) - 1) for i in range(n)]
    s.add(verts, faces, colors=[c for c in colors for _ in range(n)])
    return n


def strut(s, a, b, w, h, color):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))
    side = d.cross(up).normalized() * w / 2
    lift = side.cross(d).normalized() * h / 2
    corners = [-side - lift, side - lift, side + lift, -side + lift]
    verts = [tuple(p + c) for p in (a, b) for c in corners]
    s.add(verts, [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)], color)


def heap_y(x, z):
    return HEAP_PEAK - (HEAP_PEAK - HEAP_EDGE[3]) * max(abs(x) / HEAP_EDGE[0], abs(z) / HEAP_EDGE[1])


def lump(s, kind, x, z, size, yaw, tilt, color):
    y = heap_y(x, z)
    rot = Euler((math.radians(tilt), math.radians(yaw), 0), "YXZ").to_matrix()
    h = size / 2
    if kind == "cube":
        local = [(-h, -h, -h), (h, -h, -h), (h, h, -h), (-h, h, -h), (-h, -h, h), (h, -h, h), (h, h, h), (-h, h, h)]
        faces = [(4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
        lift = h * .55
    else:
        local = [(size * .75 * math.sin(a), -h * .3, size * .75 * math.cos(a)) for a in (0, math.tau / 3, 2 * math.tau / 3)]
        local.append((size * .1, h * .55, 0))
        faces = [(0, 1, 3), (1, 2, 3), (2, 0, 3)]
        lift = h * .2
    s.add([tuple(rot @ Vector(v) + Vector((x, y + lift, z))) for v in local], faces, tone(color))


def body(s):
    tub = [ring(*TUB_BOTTOM), ring(*TUB_TOP)]
    n = bands(s, tub, [tone("tub")] * 2)
    s.faces.append(tuple(reversed(range(len(s.verts) - 2 * n, len(s.verts) - n))))
    bands(s, [ring(*TUB_TOP)] + [ring(*r) for r in RIM], [tone("rim")] * 4)
    start = len(s.verts)
    shoulder = [(x, heap_y(x, z) + dy, z) for (x, _, z), dy in zip(ring(.56, .92, .14, 0), HEAP_SHOULDER)]
    bands(s, [ring(*HEAP_EDGE), shoulder], [tone("ore", 0), tone("ore", 1)])
    s.colors[-16:] = [tone("ore", i) for i in range(8)] + [tone("ore", i + 1) for i in range(8)]
    base = len(s.verts) - 8
    s.add([(.05, HEAP_PEAK, -.1)], [], tone("ore", 2))
    s.faces += [(base + i, base + (i + 1) % 8, base + 8) for i in range(8)]
    for row in LUMPS:
        lump(s, *row)
    kit.PARTS["OreHeap"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, HEAP_PEAK, 0], "merged_mesh": "Tub"}
    start = len(s.verts)
    for x in (-RAIL_X, RAIL_X):
        s.box((.14, .16, 2.3), (x, RAIL_Y, 0), tone("chassis"))
    for z in (-WHEEL_Z, WHEEL_Z):
        strut(s, (-WHEEL_X + WHEEL_W / 2, WHEEL_R, z), (WHEEL_X - WHEEL_W / 2, WHEEL_R, z), .10, .10, tone("chassis"))
    for x in (-1, 1):
        for z in (-.25, .25):
            strut(s, (x * RAIL_X, RAIL_Y + .06, z), (x * .95, 1.46, z), .12, .10, tone("chassis"))
        strut(s, (x * RAIL_X, RAIL_Y, -1.12), (0, RAIL_Y, TOW_TIP), .10, .12, tone("chassis"))
    kit.PARTS["Chassis"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, RAIL_Y, 0], "merged_mesh": "Tub"}
    c = Vector((0, RAIL_Y, TOW_TIP - BALL_R))
    mid = [tuple(c + Vector((BALL_R * math.cos(a), 0, BALL_R * math.sin(a)))) for a in kit.angles(6, closed=True)]
    s.add(mid + [tuple(c + Vector((0, BALL_R, 0))), tuple(c - Vector((0, BALL_R, 0)))],
          [f for i in range(6) for f in [(i, (i + 1) % 6, 6), ((i + 1) % 6, i, 7)]], tone("brass"))


def wheel(s):
    half = WHEEL_W / 2
    profile = [(.09, -half - .03, "brass"), (.21, -half + .01, "brass"), (.235, -half, "tyre"),
               (WHEEL_R - .05, -half, "tyre"), (WHEEL_R, -half + .05, "tread"), (WHEEL_R, half - .05, "tread"),
               (WHEEL_R - .05, half, "tyre"), (.235, half, "tyre"), (.21, half - .01, "brass"), (.09, half + .03, "brass")]
    aa = kit.angles(12, closed=True)

    def radius(r, kind, i):
        return r - (.022 if kind == "tread" and i % 2 else 0)

    def paint(r, i):
        kind = profile[r][2]
        return tone("brass") if kind == "brass" else tone("tyre", i if kind == "tread" else 0)

    s.rings([lambda a, r=r, x=x, k=k: (x, radius(r, k, round(a / (math.tau / 12))) * math.cos(a),
                                         radius(r, k, round(a / (math.tau / 12))) * math.sin(a))
             for r, x, k in profile], aa, closed=True, cap_ends=True, palette=paint)


def export(name, part, slot, smooth, build, sockets, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
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
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], PROP)), (name, metrics, PROP)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("ORE_CART_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish_on()
    export("ore_cart_body", "Tub", "enamel", False, body, SOCKETS, args.out_dir)
    export("ore_cart_wheel", "Tyre", "elastomer", True, wheel, {}, args.out_dir)


if __name__ == "__main__":
    main()
