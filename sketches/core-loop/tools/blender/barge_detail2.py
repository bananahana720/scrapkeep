"""Detail layer 2 for the barge (wave 12-D RECIPE-WAVE): the next additive shell at barge.glb's origin, one draw in the
steel slot, closing gap list C, read from the FLUX.1 schnell image-to-image re-imagining of the pass-1 hero render
(artifacts/local/alpha/push/w12/units/rc-barge/ref/barge_pass2.png): fixings at the floor seam crossings, strap plates
behind the hasps, framed pad faces, rim-top clips, knob hub studs, a floor drain, a denser rivet row, and the lore's
patched hull panel. It moves and duplicates no base or pass-1 geometry and paints no state key. The game drops it
first by distance (visibility range), so it doubles as the closest level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/barge_detail2.py [-- --out-dir DIR]
"""
import argparse
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import barge as bg
import barge_detail1 as d1
import lantern_beacon_detail1 as lbd1
import polish

NAME = "barge_detail2"
SLOT = "steel"
BUDGET = [2100, 3000, 1]
SIZE = [15.64, 2.63, 15.4]
tone, stud = d1.tone, d1.stud


def seam_fixings(s):
    y = bg.DECK_Y + .016
    for x in (-3.5, 0.0, 3.5):
        for z in (-3.5, 0.0, 3.5):
            stud(s, (x, y, z), (0, 1, 0), .09, .025, 4, tone("strake"))


def straps(s):
    for side in (-1, 1):
        z = side * bg.RIM[1][0]
        for x in bg.LATCH_X:
            s.box((.5, .5, .06), (x, 1.7, z + side * .02), tone("copper"))
            s.box((.5, .55, .24), (x, 1.15, z - side * .1), tone("copper"))
            for dx in (-.18, .18):
                for y in (1.9, 1.5):
                    stud(s, (x + dx, y, z + side * .05), (0, 0, side), .04, .03, 4, tone("strake"))


def pad_frames(s):
    for (along, side), y in bg.PADS:
        for du, dv, w, h in ((0, .43, 1.6, .08), (0, -.43, 1.6, .08), (-.78, 0, .08, .9), (.78, 0, .08, .9)):
            if side == 0:
                s.box((.06, h, w), (7.62, y + dv, along + du), tone("pad"))
            else:
                s.box((w, h, .06), (along + du, y + dv, side * 7.6), tone("pad"))


def clips(s):
    h_out, h_in = bg.RIM[1][0], bg.RIM[3][0]
    mid, depth = (h_out + h_in) / 2, h_out - h_in + .1
    for u in (-3.6, 0.0, 3.6):
        for sgn in (-1, 1):
            s.box((.22, .08, depth), (u, 1.98, sgn * mid), tone("copper"))
            s.box((depth, .08, .22), (sgn * mid, 1.98, u), tone("copper"))


def hub_studs(s):
    r, x0, x1, n = bg.KNOB
    for z, y in bg.KNOBS:
        stud(s, (-(x1 + .12), y, z), (-1, 0, 0), .06, .1, 6, tone("copper"))


def drain(s):
    bg.frustum(s, .28, .24, bg.DECK_Y, bg.DECK_Y + .02, 8, tone("strake"), at=(5.0, -5.0))


def more_rivets(s):
    for p, n in d1.perimeter(d1.RIM_H, d1.RIM_R, 1.56, 44, 1.0):
        stud(s, (p[0] - n[0] * .01, p[1], p[2] - n[2] * .01), n, .05, .04, 4, tone("copper"))


def patch(s):
    s.box((1.0, .42, .08), (-1.0, .72, 7.47), tone("copper"))
    for dx in (-.4, .4):
        for dy in (-.14, .14):
            stud(s, (-1.0 + dx, .72 + dy, 7.5), (0, 0, 1), .04, .03, 4, tone("strake"))


def build(s):
    seam_fixings(s)
    straps(s)
    pad_frames(s)
    clips(s)
    hub_studs(s)
    drain(s)
    more_rivets(s)
    patch(s)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(bg.MODELS))
    args = parser.parse_args(argv)
    polish.enable(bevel=.02, bevel_min=.25, **bg.kit.BAKE)
    lbd1.export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
