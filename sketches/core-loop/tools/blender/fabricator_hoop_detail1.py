"""Detail layer 1 for the fabricator hoop (wave 12-D RECIPE-WAVE): an additive shell at fabricator_hoop.glb's origin,
one draw in the steel slot, closing gap list A of the approved picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props/fabricator_hoop_101.png against the base render: ring face
slots and dimples, the nut's bore, boss and bevels, plate screws, the pedestal slot and button, the ring's cradles on
the footings and chunkier toes. It moves and duplicates no base geometry, paints no state-key mint (the ring's colour
stays the instance's state_tint) and takes dimensions and tones from fabricator_hoop.py. The game drops it by
distance (visibility range), so it doubles as the first level-of-detail step.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/fabricator_hoop_detail1.py [-- --out-dir DIR]
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
import fabricator_hoop as fh
import polish
from fabricator_hoop import kit, common, frustum
import lantern_beacon_detail1 as lbd1
import lantern_beacon_detail2 as lbd2

NAME = "fabricator_hoop_detail1"
SLOT = "steel"
BUDGET = [1500, 3000, 1]
SIZE = [11.38, 9.25, 2.88]
stud, band = lbd1.stud, lbd2.band
RC = (fh.RING_IN + fh.RING_OUT) / 2
FACE = fh.RING_DEPTH / 2
SLOTS = [(68, .36, .12), (112, .36, .12), (32, .3, .11), (148, .3, .11)]
DIMPLES = [0, 180]


def tone(name):
    assert name != "state", "a detail shell never paints the state key"
    return fh.tone(name)


def on_ring(a, dr, z):
    return (math.cos(a) * (RC + dr), fh.RING_Y + math.sin(a) * (RC + dr), z)


def face_badge(s, deg, half_l, half_w, side, color, n=8, proud=.025):
    a0 = math.radians(deg)
    ring0, ring1 = [], []
    for k in range(n):
        t = math.tau * k / n
        da = math.cos(t) * half_l / RC
        dr = math.sin(t) * half_w
        ring0.append(on_ring(a0 + da, dr, side * (FACE - .02)))
        ring1.append(on_ring(a0 + da, dr, side * (FACE + proud)))
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
    s.add(ring0 + ring1, faces, color)


def ring_face(s):
    for side in (-1, 1):
        for deg, hl, hw in SLOTS:
            face_badge(s, deg, hl, hw, side, tone("footing"))
        for deg in DIMPLES:
            face_badge(s, deg, .1, .1, side, tone("footing"), n=6)


def nut(s):
    r, y0, y1 = fh.NUT
    frustum(s, r, r * .82, y1, y1 + .12, 6, tone("brass"), caps=(False, True))
    frustum(s, r * .82, r, y0 - .12, y0, 6, tone("brass"), caps=(True, False))
    frustum(s, .42, .42, y1 + .12, y1 + .14, 10, tone("footing"), caps=(False, True))
    frustum(s, .5, .5, y1 + .1, y1 + .2, 10, tone("brass"), caps=(False, False))
    ym = (y0 + y1) / 2
    apothem = r * math.cos(math.pi / 6)
    for side in (-1, 1):
        stud(s, (0, ym, side * (apothem - .02)), (0, 0, side), .36, .14, 12, tone("brass"))


def footings(s):
    x0, x1, hz, _, h = fh.FOOTING
    w, ph, py, t = fh.PLATE
    for side in (-1, 1):
        cx = side * (x0 + x1) / 2
        for face in (-1, 1):
            zf = face * (hz + t)
            for dx in (-1, 1):
                for dy in (-1, 1):
                    stud(s, (cx + dx * (w / 2 - .1), py + dy * (ph / 2 - .1), zf - face * .01), (0, 0, face), .05, .04, 6, tone("footing"))
            zw = face * (hz - .01)
            s.box((.62, .1, .06), (cx - .12, .86, zw + face * .02), tone("footing"))
            s.box((.12, .12, .07), (cx + .38, .86, zw + face * .025), tone("brass"))
        a = math.asin((h - fh.RING_Y) / RC)
        a = a if side > 0 else math.pi - a
        p = Vector((math.cos(a) * RC, h, 0))
        tangent = Vector((-math.sin(a), math.cos(a), 0)) * (side * -1 if side > 0 else 1)
        tangent = tangent if tangent.y > 0 else -tangent
        band(s, tuple(p - tangent * .05), tuple(p + tangent * .45), .5, 8, tone("brass"))
        s.box((1.25, .08, 1.0), (p.x, h + .04, 0), tone("brass"))


def toes(s):
    x0, x1, hz, _, _ = fh.FOOTING
    hw, reach, hwall, htip = fh.FOOT
    for side in (-1, 1):
        cx = side * (x0 + x1) / 2
        for face in (-1, 1):
            s.box((hw * 2 + .1, htip + .06, .18), (cx, (htip + .06) / 2, face * (hz + reach - .05)), tone("brass"))
        s.box((.18, htip + .06, hw * 2 + .1), (side * (x1 + .35 - .05), (htip + .06) / 2, 0), tone("brass"))


def build(s):
    start = len(s.verts)
    ring_face(s)
    nut(s)
    kit.PARTS["RingNut"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, fh.RING_Y, 0], "merged_mesh": "Detail1"}
    start = len(s.verts)
    footings(s)
    toes(s)
    kit.PARTS["FootingTrim"] = {"vertex_range": [start, len(s.verts)], "reference_position": [0, 0, 0], "merged_mesh": "Detail1"}


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
    print("FABRICATOR_HOOP_DETAIL_SIZE", name, [round(v, 3) for v in m["bounds"]["size"]], m["triangles"], m["vertices"], m["draws"])
    assert all(m[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, m, budget)
    assert m["materials"] == [slot], m["materials"]
    assert size is not None and all(abs(a - b) <= .03 * b for a, b in zip(m["bounds"]["size"], size)), (name, m["bounds"]["size"], size)
    row = {**m, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "merged_parts": dict(kit.PARTS)}
    print("FABRICATOR_HOOP_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    polish.enable(bevel=.02, bevel_min=.25, **fh.kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(fh.MODELS))
    args = parser.parse_args(argv)
    export(NAME, SLOT, build, SIZE, BUDGET, args.out_dir)


if __name__ == "__main__":
    main()
