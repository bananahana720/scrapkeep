"""Detail layer 2 for Moss's bay jukebox: the next additive steel shell, authored from gap list C (the FLUX.1 schnell
image-to-image re-imagining of the pass-1 render, artifacts/local/alpha/push/w12/units/rc-moss_jukebox/gaps_C.md):
keystone-frame rivets, a vent on the dome, the patch's corner rivets and a button, display-plate bolts, more bezel
rivets, a clip on the service hatch and the feet's front lips. Class "detail" (1500 tris, 3000 verts, 1 draw).
Colours are TONES rows of moss_jukebox.py; no state key is painted.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_jukebox_detail2.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import moss_jukebox as j
from moss_jukebox import bead, bar, tone
from moss_jukebox_detail1 import DETAIL

SIZE = [1.85, 2.079, .16]


def build(s):
    copper, dark = tone("copper"), tone("speaker")
    for k in (-1, 1):
        a, b = (k * .21, 2.575), (k * .1, 2.2)
        for t in (.25, .75):
            bead(s, (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, -.565), .018, .012, copper)
    for i in range(4):
        x = -.18 - .035 * i
        bar(s, (x, 1.86 - .02 * i), (x - .07, 1.93 - .02 * i), .014, -.545, -.525, dark, ends=False)
    x0, x1, y0, y1 = j.PATCH
    for x in (x0 + .02, x1 - .02):
        for y in (y0 + .02, y1 - .02):
            bead(s, (x, y, -.475), .014, .01, copper)
    bead(s, ((x0 + x1) / 2, y1 + .1, -.46), .03, .02, copper, k=8)
    hw, y0, _ = j.PLATE
    for k in (-1, 1):
        bead(s, (k * (hw - .025), y0 + .025, -.52), .016, .012, copper)
    ocy, ohw, ohh, bez = j.OVAL
    for deg in (90, 180, 270):
        a = math.radians(deg)
        bead(s, ((ohw + .015) * math.sin(a), ocy - (ohh + .015) * math.cos(a), -.555), .018, .014, copper)
    j.prism(s, j.rect(-.05, .05, ocy + ohh + .005, ocy + ohh + .04), -.565, -.54, copper, back=False)
    cx, fhw, fhd, top = j.FOOT
    for k in (-1, 1):
        s.box((2 * fhw + .05, .045, .06), (k * cx, top - .02, -.57), dark)


def main():
    j.polish_on()
    j.export(j.NAME + "_detail2", "Detail2", "steel", build, SIZE, {}, j.out_dir(), budget=DETAIL, tag="JUKEBOX_D2")


if __name__ == "__main__":
    main()
