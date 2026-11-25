"""Detail layer 2 for the valve wheel (wave 12-D RECIPE-WAVE, DETAIL-CART loop pass 2): one additive shell in the wheel
frame (axle +Y, like valve_wheel_wheel.glb), one steel draw in the `detail` class, authored from the FLUX image-to-image
re-imagining artifacts/local/alpha/push/w12/units/rc-valve_wheel/ref/valve_pass2.png (gap list C): hub face bolts, the
brass hub flange, the crack plate with its slit and fresh-fracture edges, and a groove line on each rim face. Every
line of gap list C sits on the wheel, so this layer has no mount-frame shell.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/valve_wheel_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import valve_wheel as vw
import valve_wheel_detail1 as d1
from valve_wheel import frustum, section_ring, around, TONES

PLATE_SPAN = .24
PLATE_PROUD = .05


def point(r, a, y):
    return (r * math.cos(a), y, -r * math.sin(a))


def wheel(s):
    out, inn, half, n = vw.RIM
    frustum(s, .62, .62, vw.HUB[1] - .03, vw.HUB[1] + .04, 12, TONES["brass"], caps=(False, True))
    for a in around(4, math.pi / 4):
        frustum(s, .05, .045, vw.CAP[3] - .01, vw.CAP[3] + .06, 6, TONES["brass"], caps=(False, True),
                at=(.235 * math.sin(a), .235 * math.cos(a)))
    groove = inn + .27
    for sign in (1, -1):
        section_ring(s, [(groove - .025, sign * (half + .004)), (groove + .025, sign * (half + .004))], n, TONES["crack"])
    ca, p = vw.CRACK_ANGLE, PLATE_PROUD
    a0, a1 = ca - PLATE_SPAN / 2, ca + PLATE_SPAN / 2
    prof = [(inn - .02, half + p), (out + p, half + p), (out + p, -half - p), (inn - .02, -half - p), (inn - .02, half + p)]
    section_ring(s, prof, 2, TONES["iron"], start=a0, span=PLATE_SPAN, closed=False)
    for a, flip in ((a0, True), (a1, False)):
        quad = [point(r, a, y) for r, y in prof[:4]]
        s.add(quad, [(3, 2, 1, 0) if flip else (0, 1, 2, 3)], TONES["iron"])
    e = .004
    for da, w, tone in ((0, .05, "crack"), (-.068, .018, "slab"), (.068, .018, "slab")):
        b0, b1 = ca + da - w, ca + da + w
        for r0, r1, y0, y1 in ((inn - .02, out + p, half + p + e, half + p + e), (inn - .02, out + p, -half - p - e, -half - p - e)):
            s.add([point(r0, b0, y0), point(r1, b0, y1), point(r1, b1, y1), point(r0, b1, y0)], [(0, 1, 2, 3)], TONES[tone])
        R = out + p + e
        s.add([point(R, b0, half + p), point(R, b0, -half - p), point(R, b1, -half - p), point(R, b1, half + p)],
              [(0, 1, 2, 3)], TONES[tone])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(vw.MODELS))
    args = parser.parse_args(argv)
    vw.polish_on()
    d1.export("valve_wheel_detail2", "WheelDetail2", wheel, "wheel", args.out_dir)


if __name__ == "__main__":
    main()
