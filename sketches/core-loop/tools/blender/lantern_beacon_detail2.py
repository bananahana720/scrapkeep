"""Detail layer 2 for the lantern beacon (wave 12 DETAIL-BEACON): the second additive shell, one draw in the steel slot,
closing gap list C, read from a FLUX image-to-image re-imagining of the pass-1 render (bolt rows on the top and base
bands, leg plates at the collar, knee and ankle bands, cage hoops, intermediate cage bars, bracket bolts). Dimensions
and tones come from lantern_beacon.py; helpers from lantern_beacon_detail1.py. No state-key paint. The game drops it
by distance before detail1, so it is the nearest level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lantern_beacon_detail2.py [-- --out-dir DIR]
"""
import argparse
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lantern_beacon as lb
import lantern_beacon_detail1 as d1
from lantern_beacon import kit

NAME = "lantern_beacon_detail2"
SLOT = "steel"
BUDGET = [1500, 2000, 1]
SIZE = [4.98, 17.629, 5.602]
tone, ring, stud = d1.tone, d1.ring, d1.stud


def band(s, a, b, r, n, color):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    u = Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))
    v = d.cross(u).normalized()
    u = v.cross(d).normalized()
    ring0 = [a + (u * math.cos(t) + v * math.sin(t)) * r for t in lb.around(n)]
    ring1 = [p + (b - a) for p in ring0]
    s.add([tuple(p) for p in ring0 + ring1], [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)], color)


def plate(s, a, b, out, w, h):
    d = (b - a).normalized()
    side = d.cross(out).normalized() * w / 2
    lift = side.cross(d).normalized()
    if lift.dot(out) < 0:
        lift = -lift
    a, b = a + lift * (lb.LEG_R - .02), b + lift * (lb.LEG_R - .02)
    lift = lift * h
    corners = [-side, side, side + lift, -side + lift]
    verts = [tuple(p + c) for p in (a, b) for c in corners]
    s.add(verts, [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)] + [(3, 2, 1, 0), (4, 5, 6, 7)], tone("copper"))


def bolt_row(s, radius, y, count, start=0.0):
    for t in lb.around(count, start):
        out = Vector((math.sin(t), 0, math.cos(t)))
        stud(s, (radius * .97 * out.x, y, radius * .97 * out.z), out, .06, .08, 6, tone("copper"))


def lantern(s):
    bolt_row(s, lb.TOP_BAND[0], lb.TOP_BAND[2] - .12, 16)
    bolt_row(s, lb.BASE_BAND[0], (lb.BASE_BAND[1] + lb.BASE_BAND[2]) / 2 + .05, 16)
    r, y0, y1 = lb.GLASS
    for y in (y0 + .35, y1 - .35):
        ring(s, lb.BAR_R + .1, lb.BAR_R + .1, y, y + .1, 16, caps=(False, False))
    for t in lb.around(lb.BARS, 0):
        x, z = lb.BAR_R * math.sin(t), lb.BAR_R * math.cos(t)
        lb.strut(s, (x, y0, z), (x, y1, z), .08, .08, tone("copper"))


def brackets(s):
    out, top, bottom = lb.BRACKET
    head = lb.CAP[1] - .12
    for side in (-1, 1):
        for x, y in ((lb.TOP_FIT[0] + .05, head), (lb.TOP_BAND[0] + .05, top), (lb.BAR_R + .05, bottom)):
            for face in (-1, 1):
                stud(s, (side * x, y, face * .04), (0, 0, face), .08, .07, 6, tone("copper"))


def legs(s):
    for angle in lb.LEG_ANGLES:
        a = math.radians(angle)
        pts = [Vector((r * math.sin(a), y, r * math.cos(a))) for r, y in lb.LEG_PATH]
        top, shoulder, knee, foot = pts
        down = (shoulder - top).normalized()
        out = Vector((math.sin(a), 0, math.cos(a)))
        plate(s, top + down * .15, top + down * 1.0, out, .42, .14)
        shin = (knee - shoulder).normalized()
        band(s, knee - shin * .45, knee - shin * .1, lb.LEG_R + .07, 6, tone("leg"))
        low = (foot - knee).normalized()
        band(s, foot - low * .55, foot - low * .3, lb.LEG_R + .07, 6, tone("leg"))


def build(s):
    start = len(s.verts)
    legs(s)
    kit.PARTS["LegHardware"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, lb.COLLAR[2], 0], "merged_mesh": "Detail2"}
    start = len(s.verts)
    lantern(s)
    brackets(s)
    kit.PARTS["CageBolts"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, lb.GLASS[1], 0], "merged_mesh": "Detail2"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(lb.MODELS))
    args = parser.parse_args(argv)
    lb.polish_on()
    d1.export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
