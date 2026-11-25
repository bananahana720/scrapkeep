"""Headless recipe for the cannon launcher in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props-r2/cannon_launcher_202.png (board alpha-props-r2, seed 202): a
stubby petrol steam cannon with a wide copper-lined muzzle, a dark banded breech collar and a rounded boiler; two copper
pipes and a small bone gauge on top; a six-spoke flywheel on its left side over a dark round base plate.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
Class "landmark" (900 tris, 2000 verts, 2 draws per GLB):
  cannon_launcher_body.glb   enamel (barrel, boiler, flywheel, risers, patch) and steel (bore, collar, plate, pipes, bezel)
  cannon_launcher_gauge.glb  glass: the gauge face, at the same origin
No state key: the launcher's amber cradle ring and its gauge dial stay code-drawn (contraptions.gd:424-435, :508).

Footprint (src/world/contraptions.gd:422-459, map_gorge.gd:352): origin at the mouth point ground(at, 1.0), so the ground
is at y -1.0, and +z is the aim. The barrel axis runs through mouth - aim*5 + UP*2 along aim + UP*0.9 (about 42 degrees up),
8 m long from the breech (radius 2.0 today) to the muzzle (radius 2.8 today), the band at its centre (outer radius 2.9).
The ball rolls across the ring's opening (inner radius 3.4, the mouth test at contraptions.gd:259-260), so no vertex within
3.4 m of the mouth horizontally sits below the ball's top (CLEAR); the barrel's waist is narrowed where the axis crosses it.
No collider; the code yaws the whole launcher to the aim (contraptions.gd:436-437).

Lore (research/lore-makers-2026-10-09.md): copper pipes, bore, bezel and hub (the picture's brass), petrol enamel body, oil
charcoal iron, an iron-oxide patch plate. Redjaw Workshops construction: strong foreassemblies, pinned joints, conspicuous
load-bearing repairs (the welded patch on the boiler here; the pinned strap clamp and the axle pin in the detail shells).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cannon_launcher.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common, frustum, around
from ore_cart import strut
import polish

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [3200, 2400, 2]
NAME = "cannon_launcher"

TONES = {
    "body": "petrol",
    "tyre": "2a3231",
    "deck": "2a3231",
    "iron": "charcoal",
    "copper": "copper",
    "patch": "oxide",
    "face": "e6d9b8",
}

GROUND = -1.0
CENTRE = (0.0, 2.0, -5.0)
AXIS = (0.0, .9, 1.0)
CLEAR = (3.4, 1.0)
N = 20
NF = 28
BOILER = [(.02, -4.0), (2.0, -4.0), (2.75, -3.4), (2.9, -2.9), (2.9, -1.6)]
COLLAR = (3.2, -1.6, -.8)
FLANGE = (2.72, -.8, -.45)
BARREL = [(1.8, -.45), (1.8, 1.0), (2.22, 2.7)]
LIP = (2.55, 2.7, 4.0)
BORE = (1.95, 2.95)
PATCH = (1.6, (.9, 1.2))
PIPES = [(-.55, -8.0, (.55, 1.5, 3.7), (.42, 3.7, 4.3), (.3, 4.3, 6.9), (.4, 6.9, 7.15)),
         (.75, -9.1, (.5, 1.2, 2.8), (.4, 2.8, 3.4), (.3, 3.4, 5.6), (.4, 5.6, 5.85))]
GAUGE = ((1.15, 4.25, -9.95), (1.0, 0.0, .45), .8, .66)
GAUGE_ARM = ((.75, 4.0, -9.1), (1.05, 4.2, -9.88))
FLY = ((3.6, 1.3, -7.0), 2.3, 1.85, .32)
FLY_HUB = (.42, .45)
FLY_WEB = (.75, .12)
FLY_SPOKES = (6, .28, .22)
AXLE = (.22, 2.4, 4.2)
PLATE = (-7.2, 3.15, (GROUND, -.62), 2.95, (-.62, -.48))
PLATE_OPEN = 1.6
SIZE = {"cannon_launcher_body": [7.4, 9.368, 10.302], "cannon_launcher_gauge": [.531, 1.183, 1.099]}


def tone(name):
    return common.srgb(TONES[name])


def unit(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Frame:
    """Adds local (x, t, z) parts to a Surface along an axis: x along u, t along d, z along u x d (right-handed)."""

    def __init__(self, s, origin, d, u):
        self.s, self.o, self.d, self.u = s, origin, unit(d), unit(u)
        self.w = cross(self.u, self.d)

    def at(self, v):
        return tuple(self.o[k] + v[0] * self.u[k] + v[1] * self.d[k] + v[2] * self.w[k] for k in range(3))

    def add(self, verts, faces, color="petrol", colors=None):
        self.s.add([self.at(v) for v in verts], faces, color, colors)


def barrel_frame(s):
    return Frame(s, CENTRE, AXIS, (1.0, 0.0, 0.0))


def ring(s, rows, n, color, start=None, tones=None, at=(0.0, 0.0)):
    aa = around(n, math.pi / n if start is None else start)
    verts = [(at[0] + r * math.sin(a), t, at[1] + r * math.cos(a)) for r, t in rows for a in aa]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rows) - 1) for i in range(n)]
    colors = [c for c in tones for _ in range(n)] if tones else None
    s.add(verts, faces, color, colors)


def annulus(s, r0, r1, t, n, color, up=True, at=(0.0, 0.0)):
    aa = around(n, math.pi / n)
    verts = [(at[0] + r * math.sin(a), t, at[1] + r * math.cos(a)) for r in (r0, r1) for a in aa]
    faces = [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    s.add(verts, faces if up else [tuple(reversed(f)) for f in faces], color)


def disc(s, r, t, n, color, up=True):
    aa = around(n, math.pi / n)
    verts = [(r * math.sin(a), t, r * math.cos(a)) for a in aa]
    s.add(verts, [tuple(range(n)) if up else tuple(reversed(range(n)))], color)


def slab(s, centre, half, color):
    cx, ct, cz = centre
    hx, ht, hz = half
    s.add([(cx + a * hx, ct + b * ht, cz + c * hz) for a, b, c in
           [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]],
          [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color)


def flywheel_frame(s):
    return Frame(s, FLY[0], (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))


def gauge_frame(s):
    centre, facing, _, _ = GAUGE
    return Frame(s, centre, facing, (0.0, 1.0, 0.0))


def lathe_rows():
    fr, f0, f1 = FLANGE
    lr, l0, l1 = LIP
    br, b0 = BORE
    body = BOILER + [(fr, f0), (fr, f1)] + BARREL + [(lr, l0), (lr, l1), (br + .03, l1)]
    bore = [(br, l1), (br, b0), (.02, b0)]
    return body + bore, [tone("body")] * len(body) + [tone("copper")] * len(bore)


def enamel(s):
    b = barrel_frame(s)
    rows, tones = lathe_rows()
    ring(b, rows, N, tone("body"), tones=tones)
    t, (along, around_) = PATCH
    r = BARREL[1][0] + (BARREL[2][0] - BARREL[1][0]) * (t - BARREL[1][1]) / (BARREL[2][1] - BARREL[1][1])
    slab(b, (r + .03, t, 0.0), (.07, along / 2, around_ / 2), tone("patch"))
    for x, z, riser, _, _, _ in PIPES:
        rr, y0, y1 = riser
        frustum(s, rr, rr, y0, y1, 10, tone("body"), caps=(False, False), at=(x, z))
    f = flywheel_frame(s)
    _, ro, ri, hw = FLY
    ring(f, [(ri, -hw), (ro, -hw), (ro, hw), (ri, hw), (ri, -hw)], NF, tone("tyre"))
    wr, wh = FLY_WEB
    frustum(f, wr, wr, -wh, wh, 10, tone("body"), caps=(False, True))
    count, width, depth = FLY_SPOKES
    for a in around(count):
        p0 = (wr * .8 * math.sin(a), 0.0, wr * .8 * math.cos(a))
        p1 = ((ri + .05) * math.sin(a), 0.0, (ri + .05) * math.cos(a))
        strut(f, p0, p1, width, depth, tone("body"))
    kit.PARTS["Flywheel"] = {"reference_position": list(FLY[0])}


def steel(s):
    b = barrel_frame(s)
    r, t0, t1 = COLLAR
    ring(b, [(BOILER[-1][0], t0), (r, t0), (r, t1), (FLANGE[0], t1)], N, tone("iron"))
    zc, pr, (y0, y1), dr, (d0, d1) = PLATE
    ring(s, [(pr, y0), (pr, y1), (dr, d0), (dr, d1), (PLATE_OPEN, d1)], 28, tone("iron"), at=(0.0, zc),
         tones=[tone("iron")] * 2 + [tone("deck")] * 3)
    for x, z, _, sleeve, pipe, cap in PIPES:
        for row, name, caps in ((sleeve, "iron", (False, True)), (pipe, "copper", (False, False)), (cap, "copper", (False, True))):
            rr, y0, y1 = row
            frustum(s, rr, rr, y0, y1, 10, tone(name), caps=caps, at=(x, z))
    g = gauge_frame(s)
    _, _, br, fr = GAUGE
    ring(g, [(.02, -.2), (br, -.2), (br, 0.0), (fr, 0.0), (fr, -.04), (.02, -.04)], 16, tone("copper"))
    strut(s, GAUGE_ARM[0], GAUGE_ARM[1], .14, .14, tone("copper"))
    f = flywheel_frame(s)
    hr, hh = FLY_HUB
    frustum(f, hr, hr, -hh, hh, 10, tone("copper"))
    ar, x0, x1 = AXLE
    a = Frame(s, (0.0, FLY[0][1], FLY[0][2]), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))
    frustum(a, ar, ar, x0, x1, 10, tone("iron"), caps=(False, True))
    kit.PARTS["Collar"] = {"reference_position": list(b.at((0.0, (COLLAR[1] + COLLAR[2]) / 2, 0.0)))}


def glass(s):
    g = gauge_frame(s)
    ring(g, [(.02, -.03), (GAUGE[3] - .02, -.03), (GAUGE[3] - .02, .02), (.02, .07)], 8, tone("face"))


def clear(name, verts):
    r, top = CLEAR
    hits = [v for v in verts if math.hypot(v[0], v[2]) < r and v[1] < top]
    assert not hits, (name, "ring opening", len(hits), hits[:3])
    low = min((v[1] for v in verts if math.hypot(v[0], v[2]) < r), default=None)
    print("CANNON_CLEAR", name, "lowest_y_inside_r", None if low is None else round(low, 3))


def export(name, surfaces, sockets, out_dir, budget=LANDMARK, tag="CANNON", size=None):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        s = kit.Surface(part, slot, smooth=smooth)
        build(s)
        clear(name + ":" + part, s.verts)
        s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    got = metrics["bounds"]["size"]
    print(tag + "_SIZE", name, [round(v, 3) for v in got], metrics["bounds"], metrics["triangles"], metrics["vertices"], metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, metrics, budget)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    want = size or SIZE[name]
    assert all(abs(a - b) <= .03 * b for a, b in zip(got, want)), (name, got, want)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print(tag + "_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def out_dir():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    return parser.parse_args(argv).out_dir


def main():
    d = out_dir()
    polish.enable(bevel=.03, **kit.BAKE)
    kit.FINISH.update({"Body": {"bevel": .03}, "Fittings": {"bevel": .03}, "Face": {"bevel": 0}})
    b = Frame(None, CENTRE, AXIS, (1.0, 0.0, 0.0))
    export(NAME + "_body", [("Body", "enamel", False, enamel), ("Fittings", "steel", False, steel)],
           {"socket_muzzle": list(b.at((0.0, LIP[2], 0.0))), "socket_gauge": list(GAUGE[0])}, d)
    export(NAME + "_gauge", [("Face", "glass", True, glass)], {}, d)


if __name__ == "__main__":
    main()
