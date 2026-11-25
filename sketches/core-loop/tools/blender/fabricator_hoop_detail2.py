"""Detail layer 2 for the fabricator hoop (wave 12-D RECIPE-WAVE): the second additive shell, one draw in the steel
slot, closing gap list C, read from a FLUX image-to-image re-imagining of the pass-1 render (the boss socket, panel
lines along the ring's faces, rivet heads on the plates, sill lips, weld seams at the nut). Dimensions and tones come
from fabricator_hoop.py, helpers from fabricator_hoop_detail1.py. No state-key paint. The game drops it by distance
before detail1, so it is the nearest level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/fabricator_hoop_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fabricator_hoop as fh
import polish
import fabricator_hoop_detail1 as d1
from fabricator_hoop import kit

NAME = "fabricator_hoop_detail2"
SLOT = "steel"
BUDGET = [1500, 3000, 1]
SIZE = [10.46, 8.753, 2.012]
tone, stud, band, on_ring = d1.tone, d1.stud, d1.band, d1.on_ring
LINE_DR, LINE_W, LINE_H = .21, .045, .015
NUT_GAP = math.radians(11)


def panel_line(s, side, dr, a0, a1, n):
    z0, z1 = side * (d1.FACE - .02), side * (d1.FACE + LINE_H)
    verts = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        for r, z in ((dr - LINE_W / 2, z0), (dr - LINE_W / 2, z1), (dr + LINE_W / 2, z1), (dr + LINE_W / 2, z0)):
            verts.append(on_ring(a, r, z))
    faces = [(i * 4 + k, i * 4 + k + 1, (i + 1) * 4 + k + 1, (i + 1) * 4 + k) for i in range(n) for k in range(3)]
    s.add(verts, faces, tone("footing"))


def ring_lines(s):
    rc = d1.RC
    start = math.asin((fh.FOOTING[4] + .1 - fh.RING_Y) / rc)
    for side in (-1, 1):
        for dr in (-LINE_DR, LINE_DR):
            panel_line(s, side, dr, start, math.pi / 2 - NUT_GAP, 10)
            panel_line(s, side, dr, math.pi / 2 + NUT_GAP, math.pi - start, 10)


def nut(s):
    r, y0, y1 = fh.NUT
    ym = (y0 + y1) / 2
    apothem = r * math.cos(math.pi / 6)
    for side in (-1, 1):
        stud(s, (0, ym, side * (apothem + .1)), (0, 0, side), .22, .04, 10, tone("footing"))
    for sign in (-1, 1):
        a = math.pi / 2 + sign * math.asin((apothem + .02) / d1.RC)
        p0, p1 = on_ring(a, 0, 0), on_ring(a + sign * .02, 0, 0)
        band(s, p0, p1, .47, 8, tone("footing"))


def footings(s):
    x0, x1, hz, _, h = fh.FOOTING
    w, ph, py, t = fh.PLATE
    for side in (-1, 1):
        cx = side * (x0 + x1) / 2
        for face in (-1, 1):
            zf = face * (hz + t)
            for dx in (-1, 1):
                for dy in (-1, 1):
                    stud(s, (cx + dx * (w / 2 - .1), py + dy * (ph / 2 - .1), zf - face * .005), (0, 0, face), .075, .05, 6, tone("brass"))
    sx = x0 + .05
    for face in (-1, 1):
        s.box((sx * 2, .05, .06), (0, fh.SILL[0] + .015, face * (fh.SILL[2] - .03)), tone("footing"))


def build(s):
    start = len(s.verts)
    ring_lines(s)
    nut(s)
    kit.PARTS["RingSeams"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, fh.RING_Y, 0], "merged_mesh": "Detail2"}
    start = len(s.verts)
    footings(s)
    kit.PARTS["FootingRivets"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, 0, 0], "merged_mesh": "Detail2"}


def main():
    polish.enable(bevel=.02, bevel_min=.25, **fh.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(fh.MODELS))
    args = parser.parse_args(argv)
    d1.export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
