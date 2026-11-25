"""Headless recipe for the contraption gauge dial in the FLUX.1 schnell concept sheet
artifacts/local/alpha/push/w12/concepts/boards/alpha-props/gauge_dial_101.png: a round dark bezel holding a pale dial
face with ticks, a thin metal bezel line, a hub and a pointer, on a teal stem with a hex nut and collar over an
L-shaped base block.

Same route as ore_cart.py: kit.Surface parts, COLOR_0 vertex colour, one prop-class draw per GLB, material named for
its dig_scenery.gd SLOTS key. Four GLBs, as today's dial is four meshes (src/world/contraptions.gd `_dial`, :748-783):
- gauge_dial_stand (steel): base block, collar, stem, union nut; origin on the ground under the post.
- gauge_dial_bezel (steel): the deep case and front lip; same origin.
- gauge_dial_face (enamel): the dial face, bezel line, ticks and redline; same origin, facing +Z.
- gauge_dial_needle (enamel): pointer and hub, origin at the pivot, pointer along +Y, so the code's `_needle`
  (:787-788) turns it with rotation.z exactly as it turns today's box. The stand carries socket_needle where
  `_dial` puts the needle (face centre + 0.12 m along +Z, :781).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/gauge_dial.py [-- --out-dir DIR]
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
from ore_cart import kit, common
import polish

MODELS = kit.SKETCH / "assets/models"
PROP = [800, 700, 1]

TONES = {
    "bezel": "charcoal",
    "face": "e6d9b8",
    "tick": "charcoal",
    "line": "copper",
    "redline": "oxide",
    "pointer": "oxide",
    "hub": "copper",
    "stem": "petrol",
    "collar": "copper",
    "bolt": "copper",
    "felt": "charcoal",
}

FACE_Y = 3.4
NEEDLE_Z = .12
FACE_Z = .06
BEZEL = [(1.00, -.24), (1.15, -.16), (1.15, .13), (1.07, .21), (.94, .19), (.905, FACE_Z - .005)]
BEZEL_N = 40
FACE_R = .91
LINE = (.855, .905)
HAIR = (.815, .835)
MAJOR = (9, .64, .80, .055)
MINOR = (4, .73, .80, .022)
SWEEP = math.radians(120)
REDLINE = (math.radians(78), SWEEP, .80, .845)
BLADE = [(-.06, 0), (-.022, .60), (0, .75), (.022, .60), (.06, 0), (.045, -.20), (-.045, -.20)]
BLADE_D = .035
HUB = (.10, -.045, .04)
FLANGE = (.32, 0, .06)
SPIGOT = (.15, .06, .30)
BLOCK = ((.56, .45, .50), (0, .525, 0))
ARM = ((.62, .30, .40), (.55, .53, 0))
BOSS = (.25, .80, 1.00, .53)
BOSS_BOLT = (.09, 1.00, 1.08)
PLUG = (.07, -.28, -.37, .56)
COLLAR = (.27, .75, .85)
STEM = (.20, .85, 2.42)
RING = (.25, 1.95, 2.03)
NUT = (.31, 2.03, 2.20)
SIZE = {"gauge_dial_stand": [1.45, 2.42, .62], "gauge_dial_bezel": [2.27, 2.27, .45],
        "gauge_dial_face": [1.82, 1.82, .036], "gauge_dial_needle": [.193, .95, .105]}
SOCKETS = {"socket_needle": [0, FACE_Y, NEEDLE_Z], "socket_face": [0, FACE_Y, 0]}


def around(n, start=0.0):
    return [start + math.tau * i / n for i in range(n)]


def tube(s, a, b, profile, n, colors, caps=(True, True), start=None):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    u = d.cross(Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))).normalized()
    w = d.cross(u)
    verts, cols = [], []
    for (r, t), c in zip(profile, colors):
        centre = a + (b - a) * t
        for ang in around(n, math.pi / n if start is None else start):
            verts.append(tuple(centre + (u * math.cos(ang) + w * math.sin(ang)) * r))
            cols.append(c)
    m = len(profile)
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(m - 1) for i in range(n)]
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range((m - 1) * n, m * n)))
    s.add(verts, faces, colors=cols)


def cyl(s, a, b, r, n, color, caps=(True, True), start=None):
    tube(s, a, b, [(r, 0), (r, 1)], n, [color, color], caps, start)


def dial_xy(theta, r):
    return r * math.sin(theta), FACE_Y + r * math.cos(theta)


def annulus(s, r0, r1, z, n, color, a0=0.0, a1=math.tau):
    closed = abs(a1 - a0 - math.tau) < 1e-9
    count = n if closed else n + 1
    aa = [a0 + (a1 - a0) * i / n for i in range(count)]
    verts = [(*dial_xy(a, r), z) for r in (r0, r1) for a in aa]
    s.add(verts, [(i, count + i, count + (i + 1) % count, (i + 1) % count) for i in range(n)], color)


def tick(s, theta, r0, r1, w, z, color):
    x0, y0 = dial_xy(theta, r0)
    x1, y1 = dial_xy(theta, r1)
    sx, sy = math.cos(theta) * w / 2, -math.sin(theta) * w / 2
    s.add([(x0 - sx, y0 - sy, z), (x0 + sx, y0 + sy, z), (x1 + sx, y1 + sy, z), (x1 - sx, y1 - sy, z)],
          [(0, 1, 2, 3)], color)


def stand(s):
    r, y0, y1 = FLANGE
    cyl(s, (0, y0, 0), (0, y1, 0), r, 16, TONES["felt"])
    r, y0, y1 = SPIGOT
    cyl(s, (0, y0, 0), (0, y1, 0), r, 16, TONES["collar"], caps=(False, False))
    (size, at) = BLOCK
    s.box(size, at, TONES["stem"])
    (size, at) = ARM
    s.box(size, at, TONES["stem"])
    r, x0, x1, y = BOSS
    cyl(s, (x0, y, 0), (x1, y, 0), r, 16, TONES["stem"])
    r, x0, x1 = BOSS_BOLT
    cyl(s, (x0 - .01, BOSS[3], 0), (x1, BOSS[3], 0), r, 6, TONES["bolt"], caps=(False, True), start=0.0)
    r, x0, x1, y = PLUG
    cyl(s, (x0 + .01, y, 0), (x1, y, 0), r, 6, TONES["bolt"], caps=(False, True), start=0.0)
    r, y0, y1 = COLLAR
    cyl(s, (0, y0, 0), (0, y1, 0), r, 16, TONES["collar"], caps=(False, True))
    r, y0, y1 = STEM
    cyl(s, (0, y0, 0), (0, y1, 0), r, 16, TONES["stem"], caps=(False, False))
    r, y0, y1 = RING
    cyl(s, (0, y0, 0), (0, y1, 0), r, 16, TONES["stem"])
    r, y0, y1 = NUT
    cyl(s, (0, y0, 0), (0, y1, 0), r, 6, TONES["stem"], start=0.0)


def bezel(s):
    z0, z1 = BEZEL[0][1], max(z for _, z in BEZEL)
    prof = [(r, (z - z0) / (z1 - z0)) for r, z in BEZEL]
    tube(s, (0, FACE_Y, z0), (0, FACE_Y, z1), prof, BEZEL_N, [TONES["bezel"]] * len(prof), caps=(True, False))


def face(s):
    cyl(s, (0, FACE_Y, FACE_Z - .03), (0, FACE_Y, FACE_Z), FACE_R, BEZEL_N, TONES["face"], start=0.0)
    n = 48
    z = FACE_Z + .004
    annulus(s, LINE[0], LINE[1], z, n, TONES["line"])
    annulus(s, HAIR[0], HAIR[1], z, n, TONES["tick"])
    a0, a1, r0, r1 = REDLINE
    annulus(s, r0, r1, z, 6, TONES["redline"], a0, a1)
    count, m0, m1, mw = MAJOR
    step = 2 * SWEEP / (count - 1)
    for k in range(count):
        tick(s, -SWEEP + k * step, m0, m1, mw, z + .002, TONES["tick"])
    sub, n0, n1, nw = MINOR
    for k in range(count - 1):
        for j in range(1, sub + 1):
            tick(s, -SWEEP + k * step + j * step / (sub + 1), n0, n1, nw, z + .002, TONES["tick"])


def needle(s):
    s.prism(BLADE, BLADE_D, TONES["pointer"], axis="z")
    r, z0, z1 = HUB
    cyl(s, (0, 0, z0), (0, 0, z1), r, 12, TONES["hub"])
    cyl(s, (0, 0, z1), (0, 0, z1 + .02), r * .55, 16, TONES["hub"], caps=(False, True))


def export(name, part, slot, build, sockets, out_dir, smooth=False):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(part, slot, smooth=smooth)
    build(s)
    s.finish(root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], PROP)), (name, metrics, PROP)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b + .002 for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("GAUGE_DIAL_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish.enable(bevel=.02, bevel_min=.1, **kit.BAKE)
    kit.FINISH.update({"Face": {"bevel": 0}, "Needle": {"bevel": 0}})
    export("gauge_dial_stand", "Stand", "steel", stand, SOCKETS, args.out_dir)
    export("gauge_dial_bezel", "Bezel", "steel", bezel, {}, args.out_dir, smooth=True)
    export("gauge_dial_face", "Face", "enamel", face, {}, args.out_dir)
    export("gauge_dial_needle", "Needle", "enamel", needle, {}, args.out_dir)


if __name__ == "__main__":
    main()
