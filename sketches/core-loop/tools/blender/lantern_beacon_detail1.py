"""Detail layer 1 for the lantern beacon (wave 12 DETAIL-BEACON): an additive shell drawn at the frame's origin, one
draw in the steel slot, closing gap list A of the FLUX picture probes/gen2/ref/beacon_101.png against the base render
(collar rivets and lips, domed feet, two-tier lantern base, wide top flange, threaded top fitting, cap finial seam,
rounded bracket corners). It moves and duplicates no base geometry, paints no state-key mint (the ring and cap colour
stay the instance's state_tint), and takes its dimensions and tones from lantern_beacon.py. The game drops it by
distance (visibility range), so it doubles as the first level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lantern_beacon_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lantern_beacon as lb
from lantern_beacon import kit, common

NAME = "lantern_beacon_detail1"
SLOT = "steel"
BUDGET = [900, 2000, 1]
SIZE = [5.5, 20.436, 6.219]


def tone(name):
    t = lb.TONES[name]
    assert name != "state", "a detail shell never paints the state key"
    return common.srgb(t) if isinstance(t, str) else t


def ring(s, r0, r1, y0, y1, n=12, color=None, caps=(True, True), at=(0, 0)):
    lb.frustum(s, r0, r1, y0, y1, n, color or tone("copper"), caps=caps, at=at)


def stud(s, center, axis, r, depth, n, color):
    c, d = Vector(center), Vector(axis).normalized()
    u = Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))
    v = d.cross(u).normalized()
    u = v.cross(d).normalized()
    ring0 = [c + (u * math.cos(a) + v * math.sin(a)) * r for a in lb.around(n)]
    ring1 = [p + d * depth - (p - c) * .3 for p in ring0]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
    s.add([tuple(p) for p in ring0 + ring1], faces, color)


def collar(s):
    r0, r1, y0, y1 = lb.COLLAR
    ring(s, r1 + .1, r1 + .1, y1 - .14, y1, 12)
    ring(s, r0 + .08, r0 + .08, y0, y0 + .12, 12)
    ym = (y0 + y1) / 2
    rm = (r0 + r1) / 2 * math.cos(math.pi / 12)
    for a in lb.around(12):
        out = Vector((math.sin(a), 0, math.cos(a)))
        stud(s, (rm * out.x, ym, rm * out.z), out, .1, .1, 6, tone("copper"))


def feet(s):
    for angle in lb.LEG_ANGLES:
        a = math.radians(angle)
        r, y = lb.LEG_PATH[-1]
        at = (r * math.sin(a), r * math.cos(a))
        ring(s, .44, .46, 0, .22, 8, tone("foot"), caps=(True, False), at=at)
        ring(s, .46, .36, .22, .44, 8, tone("foot"), caps=(False, False), at=at)
        ring(s, .36, .2, .44, .56, 8, tone("foot"), caps=(False, True), at=at)


def lantern(s):
    r, y0, y1 = lb.BASE_BAND
    ring(s, r + .14, r + .14, y0, y0 + .16, 12)
    ring(s, r + .07, r + .07, y1 - .14, y1 - .04, 12)
    r, y0, y1 = lb.TOP_BAND
    ring(s, r + .28, r + .28, y0 + .08, y0 + .22, 16)
    r, y0, y1 = lb.TOP_FIT
    for k in range(3):
        y = y0 + .06 + k * .15
        ring(s, r + .08, r + .08, y, y + .07, 12, caps=(False, True))
    r, y0, y1 = lb.CAP
    for_y = y0 + (y1 - y0) * .72
    at = r * (y1 - for_y) / (y1 - y0)
    ring(s, at + .07, at - .02, for_y - .09, for_y + .09, 12)


def brackets(s):
    out, top, bottom = lb.BRACKET
    head = lb.CAP[1] - .12
    fit = lb.TOP_FIT[0]
    for side in (-1, 1):
        lb.strut(s, (side * out, top, 0), (side * out, head - .25, 0), .1, .1, tone("copper"))
        lb.strut(s, (side * out, head - .3, 0), (side * (out - .3), head, 0), .1, .1, tone("copper"))
        lb.strut(s, (side * (out - .25), head, 0), (side * fit, head, 0), .1, .1, tone("copper"))
        lb.strut(s, (side * (out - .3), bottom, 0), (side * out, bottom + .3, 0), .1, .1, tone("copper"))


def build(s):
    start = len(s.verts)
    collar(s)
    feet(s)
    kit.PARTS["CollarFeet"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, lb.COLLAR[2], 0], "merged_mesh": "Detail1"}
    start = len(s.verts)
    lantern(s)
    brackets(s)
    kit.PARTS["LanternTrim"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, lb.TOP_BAND[1], 0], "merged_mesh": "Detail1"}


def export(name, slot, build_fn, size, budget, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(name.split("_")[-1].capitalize(), slot, smooth=False)
    build_fn(s)
    s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    m = kit.gltf_metrics(path)
    lb.assert_clear(name, [s])
    print("LANTERN_BEACON_DETAIL_SIZE", name, [round(v, 3) for v in m["bounds"]["size"]], m["triangles"], m["vertices"], m["draws"])
    assert all(m[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, m, budget)
    assert m["materials"] == [slot], m["materials"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(m["bounds"]["size"], size)), (name, m["bounds"]["size"], size)
    row = {**m, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("LANTERN_BEACON_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(lb.MODELS))
    args = parser.parse_args(argv)
    lb.polish_on()
    export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
