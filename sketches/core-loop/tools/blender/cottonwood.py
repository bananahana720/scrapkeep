"""Headless recipe for cottonwood_trunk.glb and cottonwood_crown.glb, the Spillway shoulder cottonwood in the approved
FLUX.1 schnell concept artifacts/local/alpha/push/w12/concepts/boards/alpha-props/cottonwood_101.png: a gnarled trunk
twisting up from exposed roots on a sandstone slab, splitting into three limbs under a wide crown of chunky leaf clusters.

Same route as ore_cart.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS. Two GLBs,
each one prop-class draw in the enamel slot, sharing one origin (the root point spillway_scenery.gd cottonwood_transforms
uses as `foot`), the way today's tree is two batches (CottonwoodTrunks, CottonwoodCrowns). Built at the size-1.0 tree
those transforms describe: 13 m to the crown top, crown 13 m along X and 9 m along Z.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cottonwood.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from ore_cart import kit, common, strut
import polish

MODELS = kit.SKETCH / "assets/models"
PROP = [1200, 1000, 1]
SLOT = "enamel"

LEAF_LIT = common.mix("brass", "mint", .3)


def _toward(c, name, t):
    o = common.srgb(name)
    return tuple(c[i] + (o[i] - c[i]) * t for i in range(3))


TONES = {
    "bark": common.mix("charcoal", "sandstone", .42),
    "bark_dark": common.mix("charcoal", "oxide", .35),
    "limb": common.mix("oxide", "charcoal", .45),
    "leaf": [_toward(LEAF_LIT, "petrol", .6), _toward(LEAF_LIT, "petrol", .3), LEAF_LIT],
    "slab": common.srgb("sandstone"),
    "slab_side": common.mix("sandstone", "oxide", .3),
    "slab_shadow": common.mix("sandstone", "oxide", .45),
}

TRUNK = [(0, -.25, 0, .95, 0), (.08, .7, 0, .66, 15), (.24, 1.8, .05, .58, 35), (.12, 3.0, 0, .55, 60),
         (-.15, 4.3, -.05, .56, 80), (-.05, 5.5, 0, .66, 95)]
TRUNK_SIDES = 12
LIMBS = [((-.25, 5.3, 0), (-1.7, 7.6, -.3), (-3.5, 9.8, -.6)),
         ((.05, 5.4, .1), (.4, 8.0, .6), (.2, 10.6, 1.0)),
         ((.25, 5.3, -.05), (1.9, 7.2, -.4), (3.5, 9.0, -.8))]
LIMB_R = (.34, .22, .12)
TWIGS = [((-1.7, 7.6, -.3), (-4.2, 4.6, 1.5), .16), ((1.9, 7.2, -.4), (4.0, 4.6, 1.9), .16),
         ((.4, 8.0, .6), (-1.3, 9.2, 3.2), .12), ((2.7, 8.1, -.6), (3.0, 9.4, -3.3), .12)]
ROOTS = [(15, 2.0, .9), (80, 1.7, .8), (150, 2.2, 1.0), (215, 1.6, .7), (290, 1.9, .9)]
SLAB = [(0, 2.5), (38, 2.2), (82, 2.6), (122, 2.3), (165, 2.55), (205, 2.15), (245, 2.45), (290, 2.3), (330, 2.6)]
SLAB_TOP, SLAB_BOTTOM = .5, -.6
CLUSTERS = [(-.5, 10.8, .5, 2.9, 0), (-3.6, 9.8, -.3, 2.7, 30), (2.6, 9.9, .9, 2.7, 60), (-4.9, 7.1, .5, 2.1, 15),
            (4.2, 7.0, .8, 2.1, 45), (-1.8, 8.4, 2.3, 2.3, 75), (1.4, 8.3, -1.9, 2.3, 20), (.6, 8.6, 2.7, 2.1, 50),
            (-2.2, 9.0, -2.1, 2.2, 10), (4.0, 4.5, 1.8, 2.1, 35), (-4.2, 4.5, 1.5, 2.1, 65), (2.0, 11.0, -1.2, 2.1, 5),
            (-2.7, 11.2, 1.3, 1.9, 40)]
SQUASH = .85
SIZE = {"cottonwood_trunk": [8.386, 11.218, 6.583], "cottonwood_crown": [13.062, 9.96, 8.721]}


def tone(name, k=0):
    row = TONES[name]
    return row[k % len(row)] if isinstance(row, list) else row


def tube(s, rings, color, colors=None, cap=False):
    n = len(rings[0])
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    if cap:
        faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    s.add([tuple(v) for r in rings for v in r], faces, color, colors=colors)


def frame(d):
    d = Vector(d).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    return u, u.cross(d).normalized()


def trunk(s):
    rings = []
    for x, y, z, r, twist in TRUNK:
        rings.append([Vector((x + r * math.cos(math.radians(twist) + a), y, z + r * math.sin(math.radians(twist) + a)))
                      for a in kit.angles(TRUNK_SIDES, closed=True)])
    colors = [tone("bark") if i % 2 else tone("bark_dark") for _ in rings for i in range(TRUNK_SIDES)]
    tube(s, rings, None, colors=colors, cap=True)


def limb(s, path):
    pts = [Vector(p) for p in path]
    rings = []
    for k, (p, r) in enumerate(zip(pts, LIMB_R)):
        d = (pts[min(k + 1, 2)] - pts[max(k - 1, 0)])
        u, v = frame(d)
        rings.append([p + (u * math.cos(a) + v * math.sin(a)) * r for a in kit.angles(10, closed=True)])
    tube(s, rings, tone("limb"))


def root(s, angle, reach, y0):
    a = math.radians(angle)
    out = Vector((math.cos(a), 0, math.sin(a)))
    side = Vector((-math.sin(a), 0, math.cos(a)))
    start = Vector((0, y0, 0)) + out * .35
    mid = out * (.35 + reach * .55) + Vector((0, SLAB_TOP + .28, 0))
    tip = out * (.35 + reach) + Vector((0, SLAB_TOP - .02, 0))
    sections = [(start, .34, .26), (mid, .2, .22)]
    rings = [[c - side * w + Vector((0, -.1, 0)), c + Vector((0, h, 0)), c + side * w + Vector((0, -.1, 0))] for c, w, h in sections]
    verts = [tuple(v) for r in rings for v in r] + [tuple(tip)]
    faces = [(0, 1, 4, 3), (1, 2, 5, 4), (3, 4, 6), (4, 5, 6), (5, 3, 6)]
    s.add(verts, faces, tone("bark_dark"), colors=[tone("bark_dark"), tone("bark"), tone("bark_dark")] * 2 + [tone("bark_dark")])


def slab(s):
    def ring(y, grow):
        return [(math.cos(math.radians(a)) * (r + grow), y, math.sin(math.radians(a)) * (r + grow)) for a, r in SLAB]
    n = len(SLAB)
    rings = [ring(SLAB_TOP, -.2), ring(SLAB_BOTTOM, .25)]
    verts = [v for r in rings for v in r]
    faces = [tuple(reversed(range(n)))]
    faces += [((i + 1) % n, i, n + i, n + (i + 1) % n) for i in range(n)]
    s.add(verts, faces, colors=[tone("slab")] * n + [tone("slab_side")] * n)


def wood(s):
    start = len(s.verts)
    slab(s)
    kit.PARTS["Slab"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, SLAB_TOP, 0], "merged_mesh": "Trunk"}
    start = len(s.verts)
    trunk(s)
    for row in ROOTS:
        root(s, *row)
    kit.PARTS["Bole"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, TRUNK[-1][1], 0], "merged_mesh": "Trunk"}
    start = len(s.verts)
    for path in LIMBS:
        limb(s, path)
    for a, b, w in TWIGS:
        strut(s, a, b, w, w, tone("limb"))
    kit.PARTS["Limbs"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, 8.0, 0], "merged_mesh": "Trunk"}


ICO_T = (1 + 5 ** .5) / 2
ICO_V = [(-1, ICO_T, 0), (1, ICO_T, 0), (-1, -ICO_T, 0), (1, -ICO_T, 0), (0, -1, ICO_T), (0, 1, ICO_T), (0, -1, -ICO_T),
         (0, 1, -ICO_T), (ICO_T, 0, -1), (ICO_T, 0, 1), (-ICO_T, 0, -1), (-ICO_T, 0, 1)]
ICO_F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]


def ico_once():
    verts = [Vector(v).normalized() for v in ICO_V]
    cache, faces = {}, []

    def mid(a, b):
        key = (min(a, b), max(a, b))
        if key not in cache:
            cache[key] = len(verts)
            verts.append(((verts[a] + verts[b]) / 2).normalized())
        return cache[key]

    for a, b, c in ICO_F:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    return verts, faces


def cluster(s, x, y, z, r, yaw):
    rot = Euler((0, math.radians(yaw), 0), "XYZ").to_matrix()
    local, faces = ico_once()
    r *= .895
    verts = [tuple(rot @ Vector((v.x * r, v.y * r * SQUASH * .972, v.z * r)) + Vector((x, y, z))) for v in local]
    colors = [tone("leaf", 0 if v.y < -.3 else (1 if v.y < .45 else 2)) for v in local]
    s.add(verts, faces, colors=colors)


def crown(s):
    for row in CLUSTERS:
        cluster(s, *row)
    kit.PARTS["Crown"] = {"vertex_range": [0, len(s.verts)], "reference_position": [-.5, 8.0, .5], "merged_mesh": "Crown"}


def export(name, part, smooth, build, out_dir):
    common.reset()
    kit.PARTS.clear()
    root_node = common.empty(name)
    s = kit.Surface(part, SLOT, smooth=smooth)
    build(s)
    s.finish(root_node)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root_node)
    path = Path(out_dir) / (name + ".glb")
    common.export(root_node, str(path))
    metrics = kit.gltf_metrics(path)
    size = metrics["bounds"]["size"]
    print("COTTONWOOD_SIZE", name, [round(v, 3) for v in size], metrics["bounds"], metrics["triangles"], metrics["vertices"], metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], PROP)), (name, metrics, PROP)
    assert metrics["materials"] == [SLOT], (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("COTTONWOOD_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    polish.enable(bevel=.03, bevel_min=.2, **kit.BAKE)
    kit.FINISH.update({"Crown": {"bevel": 0, "subsurf": 0}})
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    export("cottonwood_trunk", "Trunk", False, wood, args.out_dir)
    export("cottonwood_crown", "Crown", True, crown, args.out_dir)


if __name__ == "__main__":
    main()
