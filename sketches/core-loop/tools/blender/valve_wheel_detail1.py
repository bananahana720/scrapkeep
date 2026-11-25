"""Detail layer 1 for the valve wheel (wave 12-D RECIPE-WAVE, DETAIL-CART loop): two additive shells, one per moving
frame, each one steel draw in the `detail` class (assets/asset_budgets.json):
- valve_wheel_detail1.glb in the wheel frame (axle +Y, like valve_wheel_wheel.glb): inner rim beads, spoke root
  flares at hub and rim, the hub nut and back boss, a jagged crack branch on both faces.
- valve_wheel_detail1m.glb in the mount frame (foot origin): flange bolts, gasket ribs, the outlet lip, slab bolts.
Closes gap list A lines A1 to A10 (artifacts/local/alpha/push/w12/units/rc-valve_wheel/gaps_A.md). Colours come
from valve_wheel.TONES; nothing moves or duplicates base geometry.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/valve_wheel_detail1.py [-- --out-dir DIR]
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
import valve_wheel as vw
from valve_wheel import kit, common, strut, frustum, tube, section_ring, around, TONES

DETAIL = [1500, 3000, 1]
BASE_BOUNDS = {"wheel": ([-1.9, -.42, -1.9], [1.9, .53, 1.9]), "mount": ([-.65, 0, -2.35], [1.05, 1.82, -.10])}
MARGIN = .12


def crack_line(s, path, y, width):
    pts = [Vector((r * math.cos(a), y, -r * math.sin(a))) for r, a in path]
    for p, q in zip(pts, pts[1:]):
        side = (q - p).normalized().cross(Vector((0, 1, 0))).normalized() * width
        s.add([tuple(p - side), tuple(q - side), tuple(q + side), tuple(p + side)], [(0, 1, 2, 3)], TONES["crack"])


def wheel(s):
    out, inn, half, n = vw.RIM
    for sign in (1, -1):
        y = sign * half
        section_ring(s, [(inn - .005, y - sign * .01), (inn - .045, y + sign * .035), (inn + .08, y + sign * .055),
                         (inn + .16, y - sign * .01)], n, TONES["iron"])
    for a in around(vw.SPOKES, math.pi / vw.SPOKES):
        d = Vector((math.cos(a), 0, -math.sin(a)))
        tube(s, tuple(d * (vw.HUB[0] - .04)), tuple(d * (vw.HUB[0] + .30)), [(.24, 0), (.15, 1)], 6, [TONES["iron"]] * 2,
             caps=(False, False))
        tube(s, tuple(d * (inn + .04)), tuple(d * (inn - .28)), [(.23, 0), (.15, 1)], 6, [TONES["iron"]] * 2,
             caps=(False, False))
    frustum(s, .17, .15, vw.CAP[3] - .01, vw.CAP[3] + .12, 6, TONES["brass"], caps=(False, True))
    frustum(s, vw.CAP[0], vw.CAP[1], -vw.CAP[2], -vw.CAP[3], 8, TONES["brass"], caps=(False, True))
    ca = vw.CRACK_ANGLE
    for sign in (1, -1):
        y = sign * (half + .06)
        crack_line(s, [(inn + .02, ca - .02), (inn + .12, ca + .04), (inn + .22, ca - .02), (inn + .33, ca + .03), (out + .01, ca)],
                   y, .075)
        crack_line(s, [(inn + .12, ca + .04), (inn + .2, ca + .11), (inn + .26, ca + .14)], y, .05)


def mount(s):
    at = (0, vw.MZ)
    r0 = vw.FLANGE[0] - .09
    for a in around(8):
        frustum(s, .055, .05, vw.FLANGE[2] - .01, vw.FLANGE[2] + .075, 6, TONES["brass"], caps=(False, True),
                at=(r0 * math.sin(a), vw.MZ + r0 * math.cos(a)))
    for y in (vw.GASKET[1] + .035, vw.GASKET[2] - .035):
        frustum(s, vw.GASKET[0] + .025, vw.GASKET[0] + .025, y - .012, y + .012, 8, TONES["gasket"], caps=(False, False), at=at)
    R, a0, a1, bore = vw.SOCKET
    y = vw.OUTLET[3]
    tube(s, (a1 - .09, y, vw.MZ), (a1 + .015, y, vw.MZ), [(R + .045, 0), (R + .045, 1), (bore + .03, 1)], 8,
         [TONES["gasket"]] * 3, caps=(False, False))
    sx, sy, sz = vw.SLAB
    for x in (-1, 1):
        for z in (-1, 1):
            frustum(s, .07, .06, sy - .01, sy + .07, 6, TONES["shaft"], caps=(False, True),
                    at=(x * (sx / 2 - .14), vw.MZ + z * (sz / 2 - .14)))


def export(name, part, build, frame, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(part, "steel", smooth=False)
    build(s)
    s.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], DETAIL)), (name, metrics, DETAIL)
    assert metrics["materials"] == ["steel"], (name, metrics["materials"])
    lo, hi = BASE_BOUNDS[frame]
    b = metrics["bounds"]
    assert all(b["min"][k] >= lo[k] - MARGIN and b["max"][k] <= hi[k] + MARGIN for k in range(3)), (name, b, BASE_BOUNDS[frame])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("VALVE_WHEEL_DETAIL", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(vw.MODELS))
    args = parser.parse_args(argv)
    vw.polish_on()
    export("valve_wheel_detail1", "WheelDetail1", wheel, "wheel", args.out_dir)
    export("valve_wheel_detail1m", "MountDetail1", mount, "mount", args.out_dir)


if __name__ == "__main__":
    main()
