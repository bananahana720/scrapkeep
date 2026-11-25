"""Detail layer 2 for the cottonwood (wave 12-D RECIPE-WAVE): the next additive shell, one draw in the enamel slot, closing gap
list C of the re-imagined picture artifacts/local/alpha/push/w12/units/rc-cottonwood/ref/cottonwood_pass2.png (FLUX.1 schnell
image-to-image of the pass-1 hero render) against the pass-1 render: forked root tips and root knots, bark plates between the
bole strands, a wrap over the fork, chipped blocks on the slab rim, twig stubs and edge tufts on the lower side clusters. It
imports cottonwood.py and cottonwood_detail1.py tables and helpers and changes neither; it moves and duplicates no geometry.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cottonwood_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cottonwood as cw
import polish
import cottonwood_detail1 as d1
from cottonwood import kit

NAME = "cottonwood_detail2"
SIZE = {"cottonwood_detail2": [12.045, 9.224, 7.124]}
tone = d1.tone


def rootlets(s):
    for k, row in enumerate(d1.ROOTS):
        path = d1.root_path(*row)
        p2, p3 = path[2], path[3]
        d = (p3 - p2).normalized()
        side = Vector((-d.z, 0, d.x))
        for sign in (-1, 1):
            a = p2.lerp(p3, .35)
            b = a + d * .55 + side * sign * .4 + Vector((0, .08, 0))
            c = b + d * .45 + side * sign * .35 + Vector((0, -.32, 0))
            d1.tube(s, [a, b, c], [.1, .07, 0], 4, tone("bark_dark" if sign > 0 else "bark"), tip=True)
        d1.ico(s, path[1].lerp(path[2], .3) + Vector((0, .1, 0)), .26, squash=(1, .8, 1), color=tone("bark"))


def plates(s):
    for k in range(4):
        path, radii = [], []
        for j in range(6):
            y = .7 + j * .85
            x, z, r, tw = d1.bole_at(y)
            a = math.radians(tw * 1.6) + k * math.tau / 4 + math.tau / 8
            path.append((x + (r - .01) * math.cos(a), y, z + (r - .01) * math.sin(a)))
            radii.append(.1)
        d1.tube(s, path, radii, 3, tone("bark_dark"))


def fork_wrap(s):
    x, z, r, _ = d1.bole_at(5.0)
    for k, (y0, lift) in enumerate([(4.8, .6), (5.1, .5)]):
        pts = []
        for j in range(9):
            a = j * math.tau / 8 * 1.05 + k * 1.4
            rr = r + .14 + .1 * math.sin(j)
            pts.append((x + rr * math.cos(a), y0 + lift * j / 8, z + rr * math.sin(a)))
        d1.tube(s, pts, [.13] * len(pts), 4, tone("bark"))


def chips(s):
    for k, (angle, radius) in enumerate(cw.SLAB):
        if k % 2:
            continue
        a = math.radians(angle + 9)
        at = Vector((math.cos(a) * (radius + .02), cw.SLAB_TOP - .2, math.sin(a) * (radius + .02)))
        out = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        w, h, dpt = .5, .34, .3
        corners = [at - side * w / 2 - out * dpt / 2, at + side * w / 2 - out * dpt / 2,
                   at + side * w * .4 + out * dpt / 2, at - side * w * .45 + out * dpt / 2]
        verts = [tuple(c + Vector((0, dy, 0))) for dy in (-h / 2, h / 2) for c in corners]
        verts[6] = tuple(Vector(verts[6]) - Vector((0, .12, 0)))
        faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        s.add(verts, faces, tone("slab_shadow") if k % 4 else tone("slab_side"))


def stubs(s):
    for k, (a, b, w) in enumerate(cw.TWIGS):
        a, b = Vector(a), Vector(b)
        for f in (.35, .7):
            p = a.lerp(b, f)
            d = (b - a).normalized()
            u, v = cw.frame(d)
            out = (u if k % 2 else -u) * .6 + Vector((0, -.5, 0)) + d * .3
            d1.tube(s, [p, p + out * .8, p + out * 1.5], [.08, .055, 0], 4, tone("limb"), tip=True)


def edge_tufts(s):
    dirs = [Vector(v).normalized() for v in cw.ICO_V]
    for x, y, z, r, yaw in cw.CLUSTERS:
        if y > 7.5:
            continue
        c = Vector((x, y, z))
        out = Vector((c.x - d1.CROWN_CENTRE.x, 0, c.z - d1.CROWN_CENTRE.z)).normalized()
        taken = sorted(range(12), key=lambda i: -(dirs[i].dot((c - d1.CROWN_CENTRE).normalized()) + .6 * dirs[i].y))[:3]
        ranked = sorted((i for i in range(12) if i not in taken), key=lambda i: -(.6 * dirs[i].dot(out) - dirs[i].y))
        for i in ranked[:3]:
            d = dirs[i]
            at = c + Vector((d.x * r, d.y * r * cw.SQUASH, d.z * r)) * .8
            d1.ico(s, at, r * .33, squash=(1, .85, 1), shade=lambda v: tone("leaf", 0 if v.y < -.3 else 1 if v.y < .3 else 2))


def build(s):
    parts = [("Rootlets", rootlets, [0, cw.SLAB_TOP, 0]), ("BarkPlates", plates, [0, 2.8, 0]), ("ForkWrap", fork_wrap, [0, 5.0, 0]),
             ("SlabChips", chips, [0, cw.SLAB_TOP, 0]), ("TwigStubs", stubs, [0, 6.5, 0]), ("EdgeTufts", edge_tufts, [0, 5.5, 0])]
    for pname, fn, ref in parts:
        start = len(s.verts)
        fn(s)
        kit.PARTS[pname] = {"vertex_range": [start, len(s.verts)], "reference_position": ref, "merged_mesh": "Detail2"}


def main():
    polish.enable(bevel=0, **cw.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(cw.MODELS))
    args = parser.parse_args(argv)
    d1.export(NAME, build, SIZE.get(NAME, [1, 1, 1]), args.out_dir)


if __name__ == "__main__":
    main()
