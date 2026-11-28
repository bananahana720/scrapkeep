"""Detail layer 2 for moss_hover_barge.glb (wave 12-D RECIPE-WAVE, the DETAIL-CART loop): the second additive steel shell,
authored from gap list C (the FLUX image-to-image re-imagining of the pass-1 render): a dense rivet row along the top of
the hull side, round copper bosses, wheel spokes, long axle spindles and a dark trim line under the coping. Nothing
sits inside the 62 x 42 deck rectangle; colours are the base recipe's TONES. Class "detail" (1500 tris, 3000 verts,
1 draw); it drops out nearer than detail1 (its shell row in ROWS, src/presentation/recipe_props.gd).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_hover_barge_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import moss_hover_barge as base
from moss_hover_barge import tone
from moss_hover_barge_detail1 import bolt, export, SIDE_U, SIDE_V

SIZE = {"moss_hover_barge_detail2": [64.98, 5.63, 51.2]}
RIVET_Y, TRIM_Y = 2.7, 3.0


def rivets(s):
    for k in range(29):
        u = -28.0 + 2.0 * k
        for sv in (-1, 1):
            bolt(s, (u, RIVET_Y, sv * SIDE_V), (0, 0, sv), .2, .08)
    for k in range(17):
        v = -16.0 + 2.0 * k
        for su in (-1, 1):
            bolt(s, (su * SIDE_U, RIVET_Y, v), (su, 0, 0), .2, .08)


def trim(s):
    for sv in (-1, 1):
        s.box((56.0, .14, .06), (0, TRIM_Y, sv * (SIDE_V + .03)), tone("under"))
    for su in (-1, 1):
        s.box((.06, .14, 36.0), (su * (SIDE_U + .03), TRIM_Y, 0), tone("under"))


def boss(s, centre, axis, sign, r=.42, depth=.14, n=8):
    rings = []
    for rr, d in ((r, -.02), (r, depth), (r * .6, depth + .05)):
        ring = []
        for i in range(n):
            a = math.tau * i / n + math.pi / n
            p = list(centre)
            others = [k for k in (0, 2) if k != axis]
            p[others[0]] += rr * math.cos(a)
            p[1] += rr * math.sin(a)
            p[axis] += sign * d
            ring.append(tuple(p))
        rings.append(ring)
    base.loft(s, rings, [tone("copper")] * 3, cap_last=True)


def bosses(s):
    for u in (-21.0, -3.0, 21.0):
        for sv in (-1, 1):
            boss(s, (u, .95, sv * SIDE_V), 2, sv)
    for v in (-9.0, 9.0):
        for su in (-1, 1):
            boss(s, (su * SIDE_U, .95, v), 0, su)


def wheels(s):
    r, y, n = base.WHEEL
    for u, side in base.WHEELS:
        z0 = side * 21.9
        s.box((r * 1.8, .3, .1), (u, y, z0 + side * 1.29), tone("cable"))
        s.box((.3, r * 1.8, .1), (u, y, z0 + side * 1.29), tone("cable"))
        s.box((.36, .36, 1.4), (u, y, z0 + side * 3.0), tone("cable"))


def build(s):
    rivets(s)
    trim(s)
    bosses(s)
    wheels(s)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(base.MODELS))
    args = parser.parse_args(argv)
    base.polish_on()
    export("moss_hover_barge_detail2", "Detail2", "steel", build, SIZE["moss_hover_barge_detail2"], args.out_dir)


if __name__ == "__main__":
    main()
