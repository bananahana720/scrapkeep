"""Detail layer 1 for the cottonwood (wave 12-D RECIPE-WAVE): an additive shell drawn at the base GLBs' shared origin, one
draw in the enamel slot, closing gap list A of artifacts/local/alpha/push/w12/concepts/boards/alpha-props/cottonwood_101.png
against the base render: sinuous roots over the slab, twisting bole strands, a swollen fork, fanning secondary branches,
small tufts on the crown clusters, a chipped slab rim and a dark under-crown mass. It moves and duplicates no base geometry
and takes its tables and tones from cottonwood.py. The game drops it by distance (visibility range), so it doubles as the
first level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cottonwood_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cottonwood as cw
import polish
from cottonwood import kit, common

NAME = "cottonwood_detail1"
DETAIL = [1500, 3000, 1]
SIZE = {"cottonwood_detail1": [13.387, 13.6, 9.336]}
CROWN_CENTRE = Vector((-.4, 8.0, .4))


def tone(name, k=0):
    return cw.tone(name, k)


def bole_at(y):
    rows = cw.TRUNK
    for a, b in zip(rows, rows[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / (b[1] - a[1])
            return [a[i] + (b[i] - a[i]) * t for i in (0, 2, 3, 4)]
    r = rows[-1] if y > rows[-1][1] else rows[0]
    return [r[0], r[2], r[3], r[4]]


def tube(s, path, radii, sides, color, colors=None, tip=False):
    pts = [Vector(p) for p in path]
    rings = []
    last = len(pts) - 1 if tip else len(pts)
    for k in range(last):
        d = pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]
        u, v = cw.frame(d)
        rings.append([pts[k] + (u * math.cos(a) + v * math.sin(a)) * radii[k] for a in kit.angles(sides, closed=True)])
    n = sides
    verts = [tuple(v) for r in rings for v in r]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    if tip:
        verts.append(tuple(pts[-1]))
        c = len(verts) - 1
        base = (len(rings) - 1) * n
        faces += [(base + i, base + (i + 1) % n, c) for i in range(n)]
    s.add(verts, faces, color, colors=colors)


def ico(s, centre, r, squash=(1, 1, 1), shade=None, color=None):
    local = [Vector(v).normalized() for v in cw.ICO_V]
    verts = [tuple(Vector((v.x * r * squash[0], v.y * r * squash[1], v.z * r * squash[2])) + Vector(centre)) for v in local]
    colors = [shade(v) for v in local] if shade else None
    s.add(verts, cw.ICO_F, color, colors=colors)


ROOTS = [(0, 2.6, 1.3), (55, 2.1, 1.1), (110, 2.4, 1.2), (170, 2.7, 1.4), (230, 2.2, 1.0), (300, 2.5, 1.2)]


def root_path(angle, reach, y0):
    a = math.radians(angle)
    out = Vector((math.cos(a), 0, math.sin(a)))
    side = Vector((-math.sin(a), 0, math.cos(a)))
    x, z, r, _ = bole_at(y0)
    c = Vector((x, 0, z))
    return [c + out * r * .7 + Vector((0, y0, 0)),
            c + out * (r + .45) + Vector((0, cw.SLAB_TOP + .45, 0)) + side * .15,
            c + out * (r + reach * .6) + Vector((0, cw.SLAB_TOP + .18, 0)) - side * .2,
            c + out * (r + reach) + Vector((0, cw.SLAB_TOP - .25, 0)) + side * .1]


def roots(s):
    for row in ROOTS:
        tube(s, root_path(*row), [.3, .26, .15, 0], 5, tone("bark"), tip=True)


def strands(s):
    for k in range(4):
        path, radii = [], []
        for j in range(7):
            y = .3 + j * (5.0 / 6)
            x, z, r, tw = bole_at(y)
            a = math.radians(tw * 1.6) + k * math.tau / 4
            path.append((x + (r - .02) * math.cos(a), y, z + (r - .02) * math.sin(a)))
            radii.append(.16 if j < 6 else .1)
        tube(s, path, radii, 4, tone("bark_dark") if k % 2 else tone("bark"))


def fork(s):
    x, z, r, _ = bole_at(5.5)
    ico(s, (x, 5.6, z), .85, squash=(1, .75, 1), color=tone("bark"))


BRANCHES = [(0, .55, (-5.9, 8.6, -1.4)), (0, .8, (-4.6, 11.0, 1.6)), (1, .6, (1.4, 11.8, 3.0)), (1, .45, (-1.0, 10.6, -2.6)),
            (2, .5, (5.6, 8.4, 1.2)), (2, .75, (4.6, 10.6, -1.8)), (0, .35, (-3.0, 7.0, 2.6)), (2, .3, (2.8, 6.6, -2.4))]


def limb_point(i, f):
    a, b, c = (Vector(p) for p in cw.LIMBS[i])
    return a.lerp(b, f * 2) if f < .5 else b.lerp(c, (f - .5) * 2)


def branches(s):
    for i, f, end in BRANCHES:
        p0 = limb_point(i, f)
        p2 = CROWN_CENTRE.lerp(Vector(end), .78)
        p1 = p0.lerp(p2, .5) + Vector((0, .7, 0))
        tube(s, [p0, p1, p2], [.11, .08, .04], 4, tone("limb"))


def tufts(s):
    dirs = [Vector(v).normalized() for v in cw.ICO_V]
    for x, y, z, r, yaw in cw.CLUSTERS:
        c = Vector((x, y, z))
        out = (c - CROWN_CENTRE).normalized()
        ranked = sorted(range(12), key=lambda i: -(dirs[i].dot(out) + .6 * dirs[i].y))
        for n, i in enumerate(ranked[:3]):
            d = dirs[i]
            at = c + Vector((d.x * r, d.y * r * cw.SQUASH, d.z * r)) * .82
            size = r * (.42 if n == 0 else .34)
            ico(s, at, size, squash=(1, .85, 1),
                shade=lambda v: tone("leaf", 1 if v.y < .2 else 2))


def slab_rim(s):
    def ring(y, grow, wobble):
        return [(math.cos(math.radians(a)) * (r + grow + (wobble if k % 2 else 0)), y,
                 math.sin(math.radians(a)) * (r + grow + (wobble if k % 2 else 0))) for k, (a, r) in enumerate(cw.SLAB)]
    n = len(cw.SLAB)
    rings = [ring(cw.SLAB_TOP + .02, -.12, .06), ring(cw.SLAB_TOP - .25, .1, -.05), ring(-.2, .2, .04)]
    verts = [v for r in rings for v in r]
    faces = [((i + 1) % n, i, n + i, n + (i + 1) % n) for i in range(n)]
    faces += [(n + (i + 1) % n, n + i, 2 * n + i, 2 * n + (i + 1) % n) for i in range(n)]
    side = tone("slab_shadow")
    s.add(verts, faces, colors=[tone("slab")] * n + [tone("slab_side") if k % 2 else side for k in range(n)] + [side] * n)


def under_crown(s):
    ico(s, (-.3, 7.4, .3), 1, squash=(3.4, .9, 2.3), color=tone("leaf", 0))


def build(s):
    parts = [("Roots", roots, [0, cw.SLAB_TOP, 0]), ("Strands", strands, [0, 2.5, 0]), ("Fork", fork, [0, 5.6, 0]),
             ("Branches", branches, [0, 9.0, 0]), ("Tufts", tufts, [-.4, 11.0, .4]), ("SlabRim", slab_rim, [0, cw.SLAB_TOP, 0]),
             ("UnderCrown", under_crown, [-.3, 7.4, .3])]
    for pname, fn, ref in parts:
        start = len(s.verts)
        fn(s)
        kit.PARTS[pname] = {"vertex_range": [start, len(s.verts)], "reference_position": ref, "merged_mesh": "Detail1"}


def export(name, build_fn, size, out_dir, smooth=True):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(name.split("_")[-1].capitalize(), cw.SLOT, smooth=smooth)
    build_fn(s)
    s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    m = kit.gltf_metrics(path)
    print("COTTONWOOD_DETAIL_SIZE", name, [round(v, 3) for v in m["bounds"]["size"]], m["triangles"], m["vertices"], m["draws"])
    assert all(m[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], DETAIL)), (name, m, DETAIL)
    assert m["materials"] == [cw.SLOT], m["materials"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(m["bounds"]["size"], size)), (name, m["bounds"]["size"], size)
    row = {**m, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("COTTONWOOD_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    polish.enable(bevel=0, **cw.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(cw.MODELS))
    args = parser.parse_args(argv)
    export(NAME, build, SIZE.get(NAME, [1, 1, 1]), args.out_dir)


if __name__ == "__main__":
    main()
