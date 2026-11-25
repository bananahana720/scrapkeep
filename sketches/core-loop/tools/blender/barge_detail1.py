"""Detail layer 1 for the barge (wave 12-D RECIPE-WAVE): an additive shell at barge.glb's origin, one draw in the steel
slot, closing gap list A of the approved picture artifacts/local/alpha/push/w12/concepts/boards/alpha-props/barge_101.png
against the base render: the rim's rivet row, bolt-on rim joint plates, latch hasps with hinge, bail and hull clasp, hook
plates on the inner lip, knob collars and hub bolts, pad corner bolts, floor panel lines and corner clamps. It moves and
duplicates no base geometry, paints no state key, and takes dimensions and tones from barge.py. The game drops it by
distance (visibility range), so it doubles as the first level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/barge_detail1.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import barge as bg
from barge import kit, common, frustum
import lantern_beacon_detail1 as lbd1
import polish

NAME = "barge_detail1"
SLOT = "steel"
BUDGET = [2100, 3000, 1]
SIZE = [15.56, 3.47, 15.54]
stud = lbd1.stud
RIM_H, RIM_R = bg.RIM[1][0], bg.RIM[1][1]


def tone(name):
    return bg.tone(name)


def perimeter(h, r, y, count, start=0.0):
    c = h - r
    straight, arc = 2 * c, math.pi * r / 2
    total = 4 * (straight + arc)
    out = []
    for k in range(count):
        d = (start + k * total / count) % total
        side, d = int(d // (straight + arc)), d % (straight + arc)
        ang = side * math.pi / 2
        n = (math.cos(ang), math.sin(ang))
        t = (-n[1], n[0])
        if d < straight:
            p = (n[0] * h + t[0] * (d - c), n[1] * h + t[1] * (d - c))
            nn = n
        else:
            a = ang + (d - straight) / r
            cc = (n[0] * c + t[0] * c, n[1] * c + t[1] * c)
            nn = (math.cos(a), math.sin(a))
            p = (cc[0] + nn[0] * r, cc[1] + nn[1] * r)
        out.append(((p[0], y, p[1]), (nn[0], 0.0, nn[1])))
    return out


def rivets(s):
    for p, n in perimeter(RIM_H, RIM_R, 1.72, 44, .4):
        stud(s, (p[0] - n[0] * .01, p[1], p[2] - n[2] * .01), n, .06, .05, 4, tone("copper"))


def joints(s):
    c = bg.RIM[1][0] - bg.RIM[1][1]
    for sx in (-1, 1):
        for sz in (-1, 1):
            s.box((.26, .56, .06), (sx * c, 1.7, sz * (RIM_H + .03)), tone("copper"))
            s.box((.06, .56, .26), (sx * (RIM_H + .03), 1.7, sz * c), tone("copper"))


def hasps(s):
    for side in (-1, 1):
        z = side * bg.RIM[1][0]
        for x in bg.LATCH_X:
            s.box((.4, .12, .14), (x, 1.38, z + side * .08), tone("copper"))
            for dx in (-.2, .2):
                s.box((.06, .42, .06), (x + dx, 1.12, z + side * .12), tone("copper"))
            s.box((.5, .2, .27), (x, .8, z - side * .04), tone("copper"))
            stud(s, (x, .8, z + side * .09), (0, 0, side), .05, .04, 4, tone("strake"))


def hook_plates(s):
    h = bg.RIM[3][0]
    for side in (-1, 1):
        for x in bg.HOOK_X:
            s.box((.3, .05, .22), (x, 1.975, side * (h + .08)), tone("copper"))


def knobs(s):
    r, x0, x1, n = bg.KNOB
    for z, y in bg.KNOBS:
        aa = [math.tau * i / 12 for i in range(12)]
        rings = [[(-x, y + rr * math.cos(a), z + rr * math.sin(a)) for a in aa] for x, rr in
                 ((x0 - .25, r + .2), (x0 + .05, r + .2), (x0 + .15, r + .05))]
        bg.bands(s, rings, tone("copper"))
        stud(s, (-(x1 + .05), y, z), (-1, 0, 0), .14, .08, 6, tone("copper"))


def pad_bolts(s):
    for (along, side), y in bg.PADS:
        for du in (-.6, .6):
            for dv in (-.28, .28):
                if side == 0:
                    stud(s, (7.6, y + dv, along + du), (1, 0, 0), .05, .04, 4, tone("copper"))
                else:
                    stud(s, (along + du, y + dv, side * 7.58), (0, 0, side), .05, .04, 4, tone("copper"))


def floor_lines(s):
    y = bg.DECK_Y + .008
    for v in (-3.5, 0.0, 3.5):
        s.box((.07, .016, 12.6), (v, y, 0), tone("floor"))
        s.box((12.6, .016, .07), (0, y, v), tone("floor"))


def clamps(s):
    c = bg.RIM[1][0] - bg.RIM[1][1]
    for sx in (-1, 1):
        for sz in (-1, 1):
            n = (sx * math.sqrt(.5), 0, sz * math.sqrt(.5))
            at = (sx * c + n[0] * (RIM_R - .02), 1.55, sz * c + n[2] * (RIM_R - .02))
            stud(s, at, n, .32, .1, 4, tone("copper"))


def build(s):
    rivets(s)
    joints(s)
    hasps(s)
    hook_plates(s)
    knobs(s)
    pad_bolts(s)
    floor_lines(s)
    clamps(s)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(bg.MODELS))
    args = parser.parse_args(argv)
    polish.enable(bevel=.02, bevel_min=.25, **kit.BAKE)
    lbd1.export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
