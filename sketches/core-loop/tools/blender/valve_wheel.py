"""Headless recipe for valve_wheel_wheel.glb, valve_wheel_band.glb and valve_wheel_mount.glb, the smashable valve in
the FLUX.1 schnell concept sheet artifacts/local/alpha/push/w12/concepts/boards/alpha-props/valve_wheel_101.png:
an eight-spoke cast wheel with a brass hub, a cracked rim with a thin hazard band, and a petrol valve body on a slab.

Same route as ore_cart.py: kit.Surface parts, COLOR_0 vertex colour, one prop-class draw per GLB, material named
for its dig_scenery.gd SLOTS key (steel for the wheel and hub, enamel for the band and the mount).

Frames follow today's code (src/world/contraptions.gd `_build_valve`) so a later swap changes one function:
- wheel and band are authored in the TorusMesh frame: origin at the wheel centre, axle along +Y, the hub cap and
  band on the +Y face. The game node keeps `rotation.x = PI/2` (front faces world +Z) and the smash yaw
  `rotation.z = 0.8`; the band rides the same node.
- mount is authored at the valve's foot, Godot +Y up; it stands behind the wheel plane (spokes fill the opening
  today's spokeless torus left for the striped post) and reaches the hub with a shaft at socket_hub.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/valve_wheel.py [-- --out-dir DIR]
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
from ore_cart import kit, common, strut
import polish

MODELS = kit.SKETCH / "assets/models"
PROP = [600, 610, 1]
FINISH = {"Wheel": {"bevel": .03}, "Band": {"bevel": 0}, "Mount": {"bevel": .03}, "WheelDetail1": {"bevel": 0}, "MountDetail1": {"bevel": 0}, "WheelDetail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


TONES = {
    "iron": common.mix("charcoal", "bone", .32),
    "crack": "charcoal",
    "brass": "copper",
    "band": "amber",
    "body": "petrol",
    "gasket": "copper",
    "slab": common.mix("bone", "charcoal", .28),
    "shaft": "charcoal",
}

RIM = (1.90, 1.45, .28, 16)
SPOKES, SPOKE_W, SPOKE_D = 8, .26, .22
HUB = (.50, .22)
CAP = (.38, .30, .22, .40)
CRACK_ANGLE = math.radians(-12)
BAND = (1.80, 1.915, .285, .20)
BAND_GAP = math.radians(8)
MZ = -1.75
HUB_Y = 1.6
SLAB = (1.30, .22, 1.20)
BODY = (.48, .22, 1.00)
GASKET = (.58, .62, .76)
FLANGE = (.56, 1.00, 1.12)
BONNET = (.36, .18, 1.12, 1.42)
GEARBOX = (.50, .44, .50)
OUTLET = (.20, .40, .80, .45)
SOCKET = (.30, .80, 1.05, .14)
SIZE = {"valve_wheel_wheel": [3.8, .68, 3.8], "valve_wheel_band": [3.8, .57, 3.8],
        "valve_wheel_mount": [1.7, 1.82, 2.25]}


def around(n, start=0.0):
    return [start + math.tau * i / n for i in range(n)]


def frustum(s, r0, r1, y0, y1, n, color, caps=(True, True), at=(0, 0)):
    aa = around(n, math.pi / n)
    verts = [(at[0] + r * math.sin(a), y, at[1] + r * math.cos(a)) for r, y in [(r0, y0), (r1, y1)] for a in aa]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range(n, 2 * n)))
    s.add(verts, faces, color)


def tube(s, a, b, profile, n, colors, caps=(True, True)):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    u = d.cross(Vector((0, 1, 0)) if abs(d.y) < .9 else Vector((1, 0, 0))).normalized()
    w = d.cross(u)
    verts, cols = [], []
    for (r, t), c in zip(profile, colors):
        centre = a + (b - a) * t
        for ang in around(n, math.pi / n):
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


def section_ring(s, profile, n, color, start=0.0, span=math.tau, closed=True):
    count = n if closed else n + 1
    aa = [start + span * i / n for i in range(count)]
    verts = [(r * math.cos(a), y, -r * math.sin(a)) for r, y in profile for a in aa]
    m = len(profile)
    faces = [(k * count + i, k * count + (i + 1) % count, (k + 1) * count + (i + 1) % count, (k + 1) * count + i)
             for k in range(m - 1) for i in range(n)]
    s.add(verts, faces, color)


def wheel(s):
    out, inn, half, n = RIM
    section_ring(s, [(out, half), (out, -half), (inn, -half), (inn, half), (out, half)], n, TONES["iron"])
    for a in around(SPOKES, math.pi / SPOKES):
        c, k = math.cos(a), -math.sin(a)
        strut(s, (HUB[0] * .8 * c, 0, HUB[0] * .8 * k), ((inn + .05) * c, 0, (inn + .05) * k), SPOKE_W, SPOKE_D, TONES["iron"])
    frustum(s, HUB[0], HUB[0], -HUB[1], HUB[1], 8, TONES["brass"])
    frustum(s, CAP[0], CAP[1], CAP[2], CAP[3], 8, TONES["brass"], caps=(False, True))
    ca = CRACK_ANGLE
    path = [(inn - .01, 0), (inn + .14, .05), (inn + .27, -.03), (out + .01, .03)]
    pts = []
    for r, da in path:
        a = ca + da
        pts.append(Vector((r * math.cos(a), half + .006, -r * math.sin(a))))
    for p, q in zip(pts, pts[1:]):
        d = (q - p).normalized()
        side = d.cross(Vector((0, 1, 0))).normalized() * .035
        s.add([tuple(p - side), tuple(q - side), tuple(q + side), tuple(p + side)], [(0, 1, 2, 3)], TONES["crack"])
    a = ca + .03
    r = out + .006
    tread = [Vector((r * math.cos(a + e), y, -r * math.sin(a + e))) for y, e in ((half, 0), (0, -.03), (-half, .02))]
    for p, q in zip(tread, tread[1:]):
        side = Vector((-math.sin(a), 0, -math.cos(a))) * .035
        s.add([tuple(p - side), tuple(q - side), tuple(q + side), tuple(p + side)], [(0, 1, 2, 3)], TONES["crack"])


def band(s):
    inn, out, front, wrap = BAND
    start, span = CRACK_ANGLE + BAND_GAP, math.tau - 2 * BAND_GAP
    for sign in (1, -1):
        section_ring(s, [(inn, sign * front), (out, sign * front), (out, sign * wrap)], 16, TONES["band"],
                     start=start, span=span, closed=False)


def mount(s):
    sx, sy, sz = SLAB
    s.box((sx, sy, sz), (0, sy / 2, MZ), TONES["slab"])
    at = (0, MZ)
    frustum(s, BODY[0], BODY[0], BODY[1], BODY[2], 8, TONES["body"], caps=(False, False), at=at)
    frustum(s, GASKET[0], GASKET[0], GASKET[1], GASKET[2], 8, TONES["gasket"], at=at)
    frustum(s, FLANGE[0], FLANGE[0], FLANGE[1], FLANGE[2], 8, TONES["body"], at=at)
    frustum(s, BONNET[0], BONNET[1], BONNET[2], BONNET[3], 8, TONES["body"], caps=(False, False), at=at)
    gx, gy, gz = GEARBOX
    s.box((gx, gy, gz), (0, HUB_Y, MZ), TONES["body"])
    strut(s, (0, HUB_Y, MZ + gz / 2 - .02), (0, HUB_Y, -.10), .16, .16, TONES["shaft"])
    r, x0, x1, y = OUTLET
    tube(s, (BODY[0] - .1, y, MZ), (x1, y, MZ), [(r, 0), (r, 1)], 8, [TONES["gasket"]] * 2, caps=(False, False))
    R, a0, a1, bore = SOCKET
    tube(s, (a0, y, MZ), (a1, y, MZ), [(R, 0), (R, 1), (bore, 1), (bore, .55)], 8,
         [TONES["gasket"], TONES["gasket"], TONES["crack"], TONES["crack"]], caps=(True, True))


def export(name, part, slot, smooth, build, sockets, out_dir):
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
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("VALVE_WHEEL_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish_on()
    export("valve_wheel_wheel", "Wheel", "steel", False, wheel, {}, args.out_dir)
    export("valve_wheel_band", "Band", "enamel", False, band, {}, args.out_dir)
    export("valve_wheel_mount", "Mount", "enamel", False, mount, {"socket_hub": [0, HUB_Y, 0]}, args.out_dir)


if __name__ == "__main__":
    main()
