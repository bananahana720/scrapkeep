"""Detail layer 1 for moss_hover_barge.glb (wave 12-D RECIPE-WAVE, the DETAIL-CART loop): one additive steel shell at
the skin's origin, authored from gap list A (the approved picture moss_hover_barge_202.png against the base render):
rim bolts, an upper hull bolt row, bolted service hatches (the Switchback Enclaves habit: every panel comes off),
plate seams, wheel clamps and axle stubs, the sign's marks and hinge pivot, a rim edge strip and corner plates.
Nothing sits inside the 62 x 42 deck rectangle; colours are the base recipe's TONES. Class "detail" (1500 tris,
3000 verts, 1 draw). The game drops it by distance (its shell row in ROWS, src/presentation/recipe_props.gd).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_hover_barge_detail1.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import moss_hover_barge as base
from moss_hover_barge import kit, common, tone

DETAIL = [1500, 3000, 1]
SIDE_U, SIDE_V = 32.3, 22.3
COPING = (31.55, 21.55, 4.0)
SIZE = {"moss_hover_barge_detail1": [64.84, 14.91, 49.13]}


def bolt(s, centre, normal, size=.36, height=.14, color="cable"):
    cx, cy, cz = centre
    h = size / 2
    t = h * .6
    axis = [i for i in range(3) if normal[i]][0]
    sign = normal[axis]
    others = [i for i in range(3) if i != axis]

    def pt(a, b, d):
        p = [cx, cy, cz]
        p[others[0]] += a
        p[others[1]] += b
        p[axis] += sign * d
        return tuple(p)
    low = [pt(-h, -h, -.02), pt(h, -h, -.02), pt(h, h, -.02), pt(-h, h, -.02)]
    top = [pt(-t, -t, height), pt(t, -t, height), pt(t, t, height), pt(-t, t, height)]
    faces = [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)] + [(4, 5, 6, 7)]
    s.add(low + top, faces, tone(color))


def rim(s):
    hu, hv, y = COPING
    for u in range(-27, 28, 6):
        for sv in (-1, 1):
            bolt(s, (u, y, sv * hv), (0, 1, 0))
    for v in range(-15, 16, 6):
        for su in (-1, 1):
            bolt(s, (su * hu, y, v), (0, 1, 0))
    for sv in (-1, 1):
        s.box((61.0, .06, .16), (0, 4.0, sv * 21.1), tone("hull"))
    for su in (-1, 1):
        s.box((.16, .06, 41.0), (su * 31.1, 4.0, 0), tone("hull"))
    for su in (-1, 1):
        for sv in (-1, 1):
            s.box((1.4, 1.1, .1), (su * 29.6, 3.0, sv * (SIDE_V + .05)), tone("copper"))


def sides(s):
    for u in range(-27, 28, 6):
        for sv in (-1, 1):
            if abs(u - base.PATCH[0]) < 2 and sv == 1:
                continue
            bolt(s, (u + 3, 1.6, sv * SIDE_V), (0, 0, sv), .3, .12)
    for v in range(-15, 16, 6):
        for su in (-1, 1):
            bolt(s, (su * SIDE_U, 1.6, v + 3), (su, 0, 0), .3, .12)
    for u in (-18.0, -6.0, 6.0, 18.0):
        for sv in (-1, 1):
            s.box((.14, 2.4, .06), (u, 2.0, sv * (SIDE_V + .03)), tone("under"))
    for su in (-1, 1):
        s.box((.06, 2.4, .14), (su * (SIDE_U + .03), 2.0, 0), tone("under"))
    for u in (-10.0, 10.0):
        for sv in (-1, 1):
            if sv == 1 and u == base.PATCH[0]:
                u = 4.0
            z = sv * (SIDE_V + .05)
            s.box((3.2, 1.5, .1), (u, 2.25, z), tone("hull"))
            for du in (-1.35, 1.35):
                for dy in (-.55, .55):
                    bolt(s, (u + du, 2.25 + dy, z + sv * .05), (0, 0, sv), .22, .08, "copper")


def wheels(s):
    r, y, n = base.WHEEL
    for u, side in base.WHEELS:
        z0 = side * 21.9
        for k in range(6):
            a = math.tau * k / 6 + math.pi / 6
            ca, sa = math.cos(a), math.sin(a)
            cx, cy = u + (r + .1) * ca, y + (r + .1) * sa
            tx, ty = -sa * .25, ca * .25
            rx, ry = ca * .18, sa * .18
            zs = [z0 + side * .1, z0 + side * .9]
            verts = [(cx + ex * tx + er * rx, cy + ex * ty + er * ry, z) for z in zs
                     for ex, er in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
            s.add(verts, faces, tone("cable"))
        s.box((.7, .7, .9), (u, y, z0 + side * 1.9), tone("cable"))


def sign(s):
    (cu, cy, cz), up, normal = base.sign_frame()
    r, t = base.SIGN[1], base.SIGN[2]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        du, dr = r * .72 * math.sin(a), r * .72 * math.cos(a)
        c = (cu + du, cy + up[0] * dr + normal[0] * (t / 2 + .04), cz + up[1] * dr + normal[1] * (t / 2 + .04))
        s.box((.5, .5, .5), c, tone("copper"))
    hz, hy = base.SIGN_HINGE
    s.box((2.4, .4, .4), (base.SIGN[0], hy, hz), tone("cable"))


def build(s):
    rim(s)
    sides(s)
    wheels(s)
    sign(s)


def export(name, part, slot, build_fn, size_row, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    sf = kit.Surface(part, slot, smooth=False)
    build_fn(sf)
    sf.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    size = metrics["bounds"]["size"]
    print("MHB_SIZE", name, [round(v, 3) for v in size], metrics["triangles"], metrics["vertices"], metrics["draws"],
          metrics["bounds"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], DETAIL)), (name, metrics, DETAIL)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, size_row)), (name, size, size_row)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("MHB_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(base.MODELS))
    args = parser.parse_args(argv)
    base.polish_on()
    export("moss_hover_barge_detail1", "Detail1", "steel", build, SIZE["moss_hover_barge_detail1"], args.out_dir)


if __name__ == "__main__":
    main()
