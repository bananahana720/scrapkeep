"""Detail layer 2 for the geyser launcher: the next additive steel shell, authored from gap list C (the FLUX.1 schnell
image-to-image re-imagining of the pass-1 render, artifacts/local/alpha/push/w12/units/rc-geyser_launcher/gaps_C.md):
rivet rows on the top course, paired rivets on the blocks, cap bands, flange-edge bolts, round spout collars and the
joint line between the two stone courses. Class "detail" (1500 tris, 3000 verts, 1 draw). Colours are TONES rows of
geyser_launcher.py; no state key is painted here.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/geyser_launcher_detail2.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import geyser_launcher as g
import polish
from geyser_launcher import frustum, polar, tone
from geyser_launcher_detail1 import DETAIL, bolt, radial

SIZE = [6.91, 1.108, 6.91]


def on_face(d, a, off, y):
    return polar(d / math.cos(off), a + off, y)


def build(s):
    dark, copper = tone("grate"), tone("copper")
    sn, sro, sy0, sy1 = g.SLAB
    d = sro * math.cos(math.pi / sn)
    for i in range(sn):
        a = math.tau * i / sn
        for off in (-.1, .1):
            bolt(s, on_face(d, a, off, sy1 - .075), radial(a), .04, .03, dark)
    n, ro, ri, y0, y1, gap = g.BLOCKS
    d = ro * math.cos(math.pi / n)
    for i in range(n):
        a = math.tau * (i + .5) / n
        for off in (-.17, .17):
            bolt(s, on_face(d, a, off, (y0 + y1) / 2), radial(a), .04, .03, dark)
    frustum(s, sro + .02, sro + .02, sy0, sy0 + .05, sn, dark, caps=(False, False))
    fr, fy0 = g.NOZZLE[0]
    for i in range(8):
        a = math.tau * (i + .5) / 8
        bolt(s, polar(fr, a, (fy0 + g.NOZZLE[1][1]) / 2), radial(a), .05, .03, dark)
    pr = g.POST[0]
    cr, cy0, cy1 = g.CAP
    for deg in g.POSTS:
        a = math.radians(deg)
        x, _, z = polar(g.POST_R, a, 0)
        frustum(s, cr + .02, cr + .02, cy0 + .06, cy0 + .14, 8, dark, caps=(False, False), at=(x, z))
        t = (math.cos(a), 0.0, -math.sin(a))
        end = pr - .04 + g.SPOUT[0] - .1
        bolt(s, (x + t[0] * end, g.SPOUT[2], z + t[2] * end), t, .12, .06, copper, k=8)


def main():
    polish.enable(bevel=.02, bevel_min=.25, **g.kit.BAKE)
    g.export(g.NAME + "_detail2", "Detail2", "steel", build, SIZE, {}, g.out_dir(), budget=DETAIL, tag="GEYSER_D2")


if __name__ == "__main__":
    main()
