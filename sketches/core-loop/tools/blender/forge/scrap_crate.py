import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

NAME = 'scrap_crate'
PARAMS = json.loads('{"asset": "scrap_crate", "band": [150, 1500], "category": "prop", "kind": "model", "max_draw_calls": 12, "pack": "core-loop", "parent_version": "v001", "size_range": [0.15, 8.0]}')

import random

import bpy
import common


def build(params):
    rng = random.Random("scrap_crate")
    root = common.empty("scrap_crate")
    H = 0.80

    p = common.Part("feet")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box("rubber", (0.16, 0.16, 0.08), (sx * 0.38, sy * 0.38, 0.04))
    p.to_object((0, 0, 0), root)

    p = common.Part("core")
    p.box("paint", (0.92, 0.92, 0.68), (0, 0, 0.42), color="petrol")
    p.box("paint", (1.0, 1.0, 0.05), (0, 0, 0.065 + 0.0), color="charcoal")
    p.to_object((0, 0, 0), root)

    p = common.Part("slats")
    tones = ["oxide", common.mix("oxide", "sandstone", 0.25), common.mix("oxide", "charcoal", 0.25)]
    for i in range(4):
        z = 0.20 + i * 0.17
        for sy in (-1, 1):
            p.box("paint", (0.86, 0.05, 0.14), (0, sy * 0.47, z), color=tones[rng.randrange(3)])
        for sx in (-1, 1):
            p.box("paint", (0.05, 0.86, 0.14), (sx * 0.47, 0, z), color=tones[rng.randrange(3)])
    p.box("paint", (1.06, 1.06, 0.06), (0, 0, H - 0.02), color="oxide")
    p.box("paint", (0.50, 1.0, 0.03), (-0.27, 0, H + 0.025), color="oxide")
    p.box("paint", (0.50, 0.12, 0.03), (0.27, -0.44, H + 0.025), color="oxide")
    p.box("paint", (0.50, 0.12, 0.03), (0.27, 0.44, H + 0.025), color="oxide")
    p.box("paint", (0.12, 0.76, 0.03), (0.44, 0, H + 0.025), color="oxide")
    p.box("paint", (0.12, 0.76, 0.03), (0.06, 0, H + 0.025), color="oxide")
    p.box("paint", (0.32, 0.76, 0.02), (0.25, 0, H + 0.02), color=common.mix("oxide", "charcoal", 0.35))
    p.box("paint", (0.20, 0.40, 0.02), (0.27, -0.05, H + 0.0), color=common.mix("oxide", "charcoal", 0.6))
    p.to_object((0, 0, 0), root)

    p = common.Part("metal")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box("bare_metal", (0.10, 0.10, H - 0.08), (sx * 0.46, sy * 0.46, 0.08 + (H - 0.08) / 2))
            p.box("bare_metal", (0.14, 0.14, 0.04), (sx * 0.45, sy * 0.45, H + 0.055))
            for k in (0.0, 1.0):
                pass
            p.bolt((sx * 0.46, sy * 0.51, 0.18), (0, sy, 0), 0.025, 0.025)
            p.bolt((sx * 0.46, sy * 0.51, 0.62), (0, sy, 0), 0.025, 0.025)
    p.box("bare_metal", (0.12, 1.06, 0.02), (0.0, 0, H + 0.050))
    p.box("bare_metal", (0.12, 0.03, H - 0.08), (0.0, -0.515, 0.08 + (H - 0.08) / 2))
    p.box("bare_metal", (0.12, 0.03, 0.10), (0.0, -0.545, H - 0.02))
    for z in (0.22, 0.45, 0.68):
        p.bolt((0, -0.53, z), (0, -1, 0), 0.03, 0.02)
    p.box("bare_metal", (0.2, 0.03, 0.12), (0, -0.53, 0.45))
    p.bolt((0, -0.545, 0.45), (0, -1, 0), 0.03, 0.02)
    p.to_object((0, 0, 0), root)
    return root


def _render(root, outdir):
    import math
    from mathutils import Vector
    pts = [o.matrix_world @ Vector(c) for o in common.tree(root) if o.type == "MESH" for c in o.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    half = 0.5 * math.dist(lo, hi)
    dist = max(1.0, half * 1.4 / math.sin(math.radians(15)))
    views = [("eye", dist, 0.30, 30, (384, 384)), ("high", dist, 0.95, 30, (384, 384))]
    common.render_turntable(root, NAME, outdir, views, ground_z=0.0, target=(0, 0, (lo[2] + hi[2]) / 2))


def main():
    common.reset()
    a = common.args()
    root = build(PARAMS)
    common.export(root, a["out"] or common.default_out(NAME))
    if a["render"]:
        _render(root, a["render"])


main()
