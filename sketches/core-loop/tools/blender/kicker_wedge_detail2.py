"""Detail layer 2 for the kicker (wave 12-D RECIPE-WAVE): the next additive steel shell at kicker_wedge.glb's origin,
authored from gap list C, the FLUX.1 schnell image-to-image re-imagining of the pass-1 render
(artifacts/local/alpha/push/w12/units/rc-kicker_wedge/ref/kicker_wedge_pass2.png): washers under the cheek rivets, a
bolted end post on each cheek at the high end, a rail along each riding edge, a clasp on the patch, a dark nose strip
at the foot and a denser skirt bolt row. One draw, class `detail`; colours from kicker_wedge.py's TONES; nothing over the
riding plane stands more than RIDE_PROUD above it.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/kicker_wedge_detail2.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import polish
from kicker_wedge import kit, common, tone, face, slab, stud, ride_check, plane_y, LENGTH, HALF, CHEEK, SKIRT, SLOPE, RIDE_PROUD, MODELS
from kicker_wedge_detail1 import ROW_LOW, ROW_HIGH, SKIRT_BOLTS, PATCH, DETAIL, dome
from ore_cart import strut

INNER = HALF - CHEEK
POST = (6.55, 6.85, .34, 1.42)
SIZE = {"kicker_wedge_detail2": [6.21, 1.447, 6.802]}


def build(s):
    rivet = tone("rivet")
    for side in (-1, 1):
        for z, y in ROW_LOW + ROW_HIGH:
            if y < plane_y(z) - .12:
                stud(s, (side * HALF, y, z), (side, 0, 0), .12, .115, .012, tone("body"), sides=8, spin=0)
        for z in SKIRT_BOLTS[:-1]:
            dome(s, (side * (HALF + SKIRT[0]), SKIRT[1] * .5, z + .45), (side, 0, 0), .06, .035, rivet)
        z0, z1, y0, y1 = POST
        s.box((.04, y1 - y0, z1 - z0), (side * (HALF + .02), (y0 + y1) / 2, (z0 + z1) / 2), tone("body"))
        for y in (y0 + .18, (y0 + y1) / 2, y1 - .18):
            dome(s, (side * (HALF + .04), y, (z0 + z1) / 2), (side, 0, 0), .06, .035, rivet)
        strut(s, (side * (HALF + .03), plane_y(.6) - .07, .6), (side * (HALF + .03), plane_y(6.5) - .07, 6.5), .06, .08, tone("body"))
    y, z, h, l = PATCH
    s.box((.07, .12, .16), (HALF + .04, y + h / 2 + .03, z - .2), tone("rivet"))
    dome(s, (HALF + .075, y + h / 2 + .03, z - .2), (1, 0, 0), .035, .025, tone("body"))
    slab(s, [(-INNER, .05), (INNER, .05), (INNER, .16), (-INNER, .16)], -.004, RIDE_PROUD * .3, tone("body"))


def export(out_dir):
    name = "kicker_wedge_detail2"
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface("Detail2", "steel", smooth=False)
    build(s)
    proud = ride_check(s.verts)
    s.finish(root)
    kit.empty("EndPosts", [HALF, 1.0, 6.7], root)
    kit.empty("NoseStrip", list(face(0, .1)), root)
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
