"""Detail layer 1 for the kicker (wave 12-D RECIPE-WAVE): an additive steel shell at kicker_wedge.glb's origin that closes
gap list A from kicker_wedge_101.png: domed cheek rivets in two staggered rows, skirt bolts, a seam framing the riding
plate, four plate corner bolts, cap bar bolts, rivets and a weld bead round the Redjaw patch plate, and paint wear
(slate chips) at the stripes' low ends so the bands melt toward bare plate. One draw, class `detail`; colours from
kicker_wedge.py's TONES; dropped by distance in the side rig (LAYER_RANGE). Every part over the riding plane stays
within RIDE_PROUD of it, checked at export.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/kicker_wedge_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import polish
from kicker_wedge import (kit, common, TONES, tone, face, slab, stud, stripes, ride_check, plane_y, NORMAL, LENGTH, TOP,
                          HALF, CHEEK, SKIRT, SLOPE, FACE_SINK, RIDE_PROUD, CAP_V, CAP_GAP, MODELS)

DETAIL = [1500, 3000, 1]
INNER = HALF - CHEEK
ROW_LOW = [(1.9 + .75 * i, .52) for i in range(7)]
ROW_HIGH = [(3.6 + .75 * i, .52 + .55) for i in range(5)]
SKIRT_BOLTS = [1.8 + .9 * i for i in range(6)]
PATCH = (.62, 4.3, .42, .9)
SIZE = {"kicker_wedge_detail1": [6.22, 1.547, 6.701]}


def dome(s, centre, axis, r, h, color):
    """A domed rivet head: a six-sided two-step frustum."""
    stud(s, centre, axis, r, r * .75, h, color, sides=6, spin=0)


def build(s):
    rivet = tone("rivet")
    for side in (-1, 1):
        for z, y in ROW_LOW + ROW_HIGH:
            if y < plane_y(z) - .12:
                dome(s, (side * HALF, y, z), (side, 0, 0), .075, .045, rivet)
        for z in SKIRT_BOLTS:
            dome(s, (side * (HALF + SKIRT[0]), SKIRT[1] * .5, z), (side, 0, 0), .07, .04, rivet)
    top = RIDE_PROUD * .4
    v1 = CAP_V - CAP_GAP
    for u0, u1 in ((-INNER, -INNER + .06), (INNER - .06, INNER)):
        slab(s, [(u0, .08), (u1, .08), (u1, v1), (u0, v1)], -FACE_SINK - .005, top, tone("body"))
    slab(s, [(-INNER + .06, .08), (INNER - .06, .08), (INNER - .06, .14), (-INNER + .06, .14)], -FACE_SINK - .005, top, tone("body"))
    for u in (-INNER + .22, INNER - .22):
        for v in (.45, v1 - .12):
            stud(s, face(u, v, -FACE_SINK), NORMAL, .07, .05, FACE_SINK + top, rivet, sides=6, spin=0)
    for u in (-INNER + .5, INNER - .5):
        stud(s, face(u, CAP_V + .25, 0), NORMAL, .07, .05, top, rivet, sides=6, spin=0)
    y, z, h, l = PATCH
    x = HALF + .03
    for dy in (-h / 2 + .07, h / 2 - .07):
        for dz in (-l / 2 + .07, l / 2 - .07):
            dome(s, (x, y + dy, z + dz), (1, 0, 0), .045, .03, tone("body"))
    for dy, dz, sy, sz in ((-h / 2, 0, .035, l + .07), (h / 2, 0, .035, l + .07), (0, -l / 2, h, .035), (0, l / 2, h, .035)):
        s.box((.05, sy, sz), (HALF + .02, y + dy, z + dz), tone("patch"))
    for k, poly in stripes(v1, INNER):
        if tone("stripe", k) != tone("stripe", 0):
            continue
        low = min(poly, key=lambda p: (p[1], p[0]))
        cu = sum(p[0] for p in poly) / len(poly)
        cv = sum(p[1] for p in poly) / len(poly)
        for t, w in ((.12, .2), (.3, .16), (.5, .1)):
            u, v = low[0] + (cu - low[0]) * t, low[1] + (cv - low[1]) * t
            slab(s, [(u - w, v - .05), (u + w * .4, v - .07), (u + w, v + .04), (u - w * .3, v + .07)], -.002, top * .5, tone("face"))


def export(out_dir):
    name = "kicker_wedge_detail1"
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface("Detail1", "steel", smooth=False)
    build(s)
    proud = ride_check(s.verts)
    s.finish(root)
    kit.empty("RivetRows", [HALF, .8, 4.0], root)
    kit.empty("PlateSeam", list(face(0, SLOPE / 2)), root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], DETAIL)), (name, metrics, DETAIL)
    assert metrics["materials"] == ["steel"], (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "ride_proud": round(proud, 4)}
    print("KICKER_WEDGE_EXPORT", name, json.dumps(row, sort_keys=True))


def main():
    polish.enable(bevel=.02, bevel_min=.25, **kit.BAKE)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    export(parser.parse_args(argv).out_dir)


if __name__ == "__main__":
    main()
