"""Detail layer 2 for the gauge dial (wave 12-D RECIPE-WAVE, DETAIL-CART loop): one additive steel shell in the
`detail` class, foot frame, static parts only. Authored from the FLUX image-to-image re-imagining of the pass-1 render
(artifacts/local/alpha/push/w12/units/rc-gauge_dial/ref/gauge_pass2.png); closes gap list C lines C1 to C6: union-nut
screws, ground-flange bolts, finer spigot threads, collar screws, the arm-boss flange step and fine scale ticks.
Colours come from gauge_dial.TONES.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/gauge_dial_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gauge_dial as gd
import polish
from gauge_dial import cyl, tick, around, TONES
from gauge_dial_detail1 import export


def radial_screw(s, y, r, a, length, color):
    dx, dz = math.sin(a), math.cos(a)
    cyl(s, (dx * (r - .01), y, dz * (r - .01)), (dx * (r + length), y, dz * (r + length)), .022, 6, color,
        caps=(False, True), start=0.0)


def build(s):
    r, y0, y1 = gd.NUT
    for a in around(6, math.pi / 6):
        radial_screw(s, (y0 + y1) / 2, r * math.cos(math.pi / 6), a, .025, TONES["bolt"])
    r, y0, y1 = gd.FLANGE
    for a in around(6, math.pi / 6):
        x, z = .24 * math.sin(a), .24 * math.cos(a)
        cyl(s, (x, y1 - .01, z), (x, y1 + .03, z), .03, 6, TONES["bolt"], caps=(False, True), start=0.0)
    r, y0, y1 = gd.SPIGOT
    for k in range(7):
        y = y0 + .012 + k * .034
        cyl(s, (0, y, 0), (0, y + .01, 0), r + .01, 8, TONES["collar"])
    r, y0, y1 = gd.COLLAR
    for a in around(4, math.pi / 4):
        radial_screw(s, (y0 + y1) / 2, r * math.cos(math.pi / 8), a, .02, TONES["felt"])
    br, x0, x1, y = gd.BOSS
    cyl(s, (x0 - .03, y, 0), (x0 + .02, y, 0), br + .05, 12, TONES["stem"])
    count, m0, m1, mw = gd.MAJOR
    sub = gd.MINOR[0]
    step = 2 * gd.SWEEP / (count - 1) / (sub + 1)
    for k in range((count - 1) * (sub + 1)):
        tick(s, -gd.SWEEP + (k + .5) * step, .765, .80, .012, gd.FACE_Z + .008, TONES["tick"])


def main():
    polish.enable(bevel=.02, bevel_min=.25, **gd.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(gd.MODELS))
    args = parser.parse_args(argv)
    export("gauge_dial_detail2", "DialDetail2", build, args.out_dir)


if __name__ == "__main__":
    main()
