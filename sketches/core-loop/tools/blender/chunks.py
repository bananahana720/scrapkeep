import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common
import polish
from common import Part, Vector

polish.enable(detail=1, bevel=0.012, bevel_min=0.2, bake_slots=())

BASE = -0.07
BANDS = {"small": (60, 120), "medium": (150, 300), "large": (400, 800)}


def pick(rng, avoid=()):
    return rng.choice([c for c in common.PAINT_SET if c not in avoid])


def small(p, rng, v):
    a = pick(rng)
    b = pick(rng, (a,))
    if v == 0:
        p.box("paint", (0.34, 0.26, 0.07), loc=(0, 0, BASE + 0.035), rot=(0, 0, 0.1), color=a)
        p.box("paint", (0.2, 0.15, 0.05), loc=(0.04, -0.02, BASE + 0.095), rot=(0.08, 0.05, 0.4), color=b)
        for x, y in ((-0.13, -0.09), (0.13, 0.1), (-0.12, 0.1), (0.13, -0.08)):
            p.bolt((x, y, BASE + 0.07), (0, 0, 1), r=0.022, h=0.025, segs=4)
    elif v == 1:
        p.box("paint", (0.32, 0.14, 0.06), loc=(0, 0, BASE + 0.03), color=a)
        p.box("paint", (0.06, 0.14, 0.22), loc=(0.13, 0, BASE + 0.14), rot=(0, -0.12, 0), color=b)
        p.prism("bare_metal", [(0, 0), (0.12, 0), (0, 0.12)], 0.03,
                matrix=common.mtx((0.1, 0, BASE + 0.06), (math.pi / 2, 0, math.pi)))
        p.bolt((-0.08, 0.03, BASE + 0.06), (0, 0, 1), r=0.022, h=0.025)
        p.bolt((-0.02, -0.03, BASE + 0.06), (0, 0, 1), r=0.022, h=0.025)
    else:
        p.box("paint", (0.18, 0.2, 0.05), loc=(-0.08, 0, BASE + 0.03), rot=(0, 0.1, 0), color=a)
        p.box("paint", (0.18, 0.2, 0.05), loc=(0.1, 0, BASE + 0.07), rot=(0, -0.45, 0), color=b)
        p.rod("bare_metal", (0.01, -0.11, BASE + 0.07), (0.01, 0.11, BASE + 0.07), 0.03, 6)
        p.bolt((-0.1, 0.05, BASE + 0.055), (0, 0.1, 1), r=0.022, h=0.025)
        p.bolt((0.12, -0.05, BASE + 0.1), (0.4, 0, 1), r=0.022, h=0.025)
    p.jitter(p.bm.faces, rng, 0.006)


def medium(p, rng, v):
    a = pick(rng)
    if v == 0:
        res = common.bmesh.ops.create_uvsphere(p.bm, u_segments=10, v_segments=6, radius=0.26,
                                               matrix=common.mtx((0, 0, BASE + 0.05), (0, 0, 0), (1, 0.9, 0.55)))
        low = [x for x in res["verts"] if x.co.z < BASE + 0.049]
        common.bmesh.ops.delete(p.bm, geom=low, context="VERTS")
        dome = p._faces([x for x in res["verts"] if x.is_valid])
        p.paint(dome, "paint", a)
        dent = max((x for x in p.verts_of(dome)), key=lambda x: x.co.x + x.co.z)
        dent.co.z -= 0.05
        p.ring("paint", 0.22, 0.3, 0.05, 10, loc=(0, 0, BASE + 0.03), color=pick(rng, (a,)))
        for k in range(5):
            t = k * math.tau / 5 + 0.3
            p.bolt((0.26 * math.cos(t), 0.26 * math.sin(t) * 0.9, BASE + 0.055), (0, 0, 1), r=0.02, h=0.025)
    elif v == 1:
        pts = [Vector((0.2 - 0.2 * math.cos(t), 0, BASE + 0.08 + 0.2 * math.sin(t)))
               for t in [k * (math.pi / 2) / 5 for k in range(6)]]
        for q0, q1 in zip(pts, pts[1:]):
            p.rod("paint", q0, q1, 0.08, 8, color=a)
        p.ring("bare_metal", 0.06, 0.12, 0.04, 8, loc=pts[0] + Vector((0, 0, -0.02)))
        p.ring("bare_metal", 0.06, 0.12, 0.04, 8, loc=pts[-1] + Vector((0.02, 0, 0)), rot=(0, math.pi / 2, 0))
        p.box("rubber", (0.3, 0.14, 0.04), loc=(0.1, 0, BASE + 0.02))
    else:
        p.cyl("paint", 0.13, 0.12, 0.2, 8, loc=(0, 0, BASE + 0.12), rot=(0.12, 0, 0), color=a)
        p.cyl("paint", 0.2, 0.2, 0.05, 8, loc=(0, 0, BASE + 0.025), color=pick(rng, (a,)))
        p.cyl("rubber", 0.15, 0.1, 0.05, 8, loc=(0, 0.03, BASE + 0.24), rot=(0.12, 0, 0))
        for k in range(4):
            t = k * math.tau / 4 + 0.4
            p.bolt((0.17 * math.cos(t), 0.17 * math.sin(t), BASE + 0.05), (0, 0, 1), r=0.02, h=0.025)
    p.jitter(p.bm.faces, rng, 0.008)


def large(p, rng, v):
    a = pick(rng)
    b = pick(rng, (a,))
    cut = [0.0, 0.08, 0.14][v]
    w, d = [(0.72, 0.52), (0.66, 0.6), (0.78, 0.46)][v]
    left = [(-w / 2, -d / 2), (0.0, -d / 2 - 0.03), (0.02, d / 2 + 0.02), (-w / 2 + cut, d / 2)]
    right = [(0.0, -d / 2 - 0.03), (w / 2 - cut, -d / 2), (w / 2, d / 2 - cut), (0.02, d / 2 + 0.02)]
    for outline, color, lift in ((left, a, 0.0), (right, b, 0.015)):
        faces = p.prism("paint", outline, 0.06, matrix=common.mtx((0, 0, BASE + 0.03 + lift)), color=color,
                        side_slot="bare_metal")
        for x in p.verts_of(faces):
            x.co.z -= 0.35 * (x.co.x ** 2 + x.co.y ** 2)
    for k in range(12):
        t = k / 11
        y = -d / 2 + t * d
        x = 0.01 + 0.012 * math.sin(k * 1.7)
        z = BASE + 0.07 - 0.35 * (x * x + y * y)
        p.ico("bare_metal", 0.026, 2 if k % 3 == 0 else 1, loc=(x, y, z), scale=(1.3, 1, 0.8))
    for x in (-0.2, 0.22):
        p.beam("paint", (x, -d / 2 + 0.06, BASE + 0.07 - 0.35 * x * x), (x, d / 2 - 0.06, BASE + 0.07 - 0.35 * x * x),
               0.05, 0.05, color="petrol" if a != "petrol" else "oxide")
    for x, y in ((-0.3, -0.18), (-0.3, 0.16), (0.3, -0.16), (0.1, 0.18), (-0.1, -0.18)):
        p.bolt((x, y, BASE + 0.065 - 0.35 * (x * x + y * y)), (0, 0, 1), r=0.024, h=0.025)
    p.box("rubber", (0.1, 0.05, 0.04), loc=(-w / 2 + 0.08, 0, BASE + 0.03 - 0.35 * (w * w / 4)))
    p.jitter(p.bm.faces, rng, 0.006)


def main():
    common.reset()
    a = common.args()
    root = common.empty("Chunks")
    rows = []
    objs = []
    for size, build, x0 in (("small", small, -2.0), ("medium", medium, 0.0), ("large", large, 2.2)):
        for v in range(3):
            name = "chunk_%s_%d" % (size, v)
            rng = random.Random("scrapkeep-" + name)
            p = Part(name)
            if size == "small":
                p.bevel = 0
            build(p, rng, v)
            loc = (x0 + (v - 1) * (0.5 if size == "small" else 0.75 if size == "medium" else 0.95), 0, 0)
            for vert in p.bm.verts:
                vert.co += Vector(loc)
            obj = p.to_object(loc, root)
            objs.append(obj)
            rows.append((name, common.tris(obj), BANDS[size]))
    ok = common.report("chunks", rows)
    common.export(root, a["out"] or common.default_out("chunks"))
    if a["render"]:
        common.render_turntable(root, "chunks", a["render"], [
            ("game", 8.0, 0.30, 65, (1920, 1080), 0.5),
            ("close", 3.4, 0.5, 45, (1400, 600)),
        ], ground_z=BASE, target=(0, 0, 0), yaws=(0, 180))
    if not ok:
        raise SystemExit("chunk budget out of range")


main()
