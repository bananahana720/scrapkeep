"""Headless recipe for lantern_beacon_frame.glb and lantern_beacon_lens.glb, the lantern beacon in the FLUX.1
schnell concept sheet artifacts/local/alpha/push/w12/probes/gen2/ref/beacon_101.png (beacon_202.png is a
second take): a tripod, an ivory platform, a caged lantern, an upright halo ring and a cone cap.

Same route as ore_cart.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
The frame is two draws (steel: legs, feet, collar, cage bars, brackets, halo ring, cap; enamel: platform and
lantern housing); the lens is one glass draw placed at the frame's socket_lens. Class "landmark" in
assets/asset_budgets.json. No lights: the ring and cap are painted the steel shader's state key, so each
instance shows its beacon state colour through `state_tint` (EventKinds STATE_ROWS: open amber, sealed slate).

The Warden clamps the beacon at socket_clamp, its seat on the axis (wave 12 BEACON-CLAMP). Every family's weak
point is a FAMILY_POINT_RADIUS sphere at the seat plus the kit's point offset, and the mind's choir lens moves among
three seats CHOIR_RADIUS off the axis; all of them are read from the game's own tables (warden_rows), and the export
asserts each sphere clears every triangle of the frame and lens. So the platform rides above the mind's sphere, the
legs bow out under the collar, and the legs sit between the choir seats.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lantern_beacon.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from ore_cart import kit, common, strut
import polish

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [1900, 2000, 2]
FINISH = {"Frame": {"bevel": .03}, "Housing": {"bevel": .04}, "Lens": {"bevel": .05}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


TONES = {
    "leg": "petrol",
    "foot": "charcoal",
    "copper": "copper",
    "platform": "bone",
    "state": "mint",
    "lens": common.mix("bone", "ffffff", .55),
}

LEG_ANGLES = [150, 30, -90]
LEG_PATH = [(.6, 10.85), (1.8, 9.8), (2.55, 1.4), (3.1, .35)]
LEG_R, LEG_SIDES = .22, 6
LIFT = 1.8
COLLAR = (.75, 1.0, 8.8 + LIFT, 9.25 + LIFT)
PLATFORM = (2.1, 9.25 + LIFT, 9.55 + LIFT)
BASE_BAND = (1.3, 9.55 + LIFT, 10.15 + LIFT)
GLASS = (1.08, 10.15 + LIFT, 15.35 + LIFT)
TOP_BAND = (1.3, 15.35 + LIFT, 15.85 + LIFT)
TOP_FIT = (.95, 15.85 + LIFT, 16.35 + LIFT)
CAP = (1.35, 16.35 + LIFT, 19.4 + LIFT)
RING = (15.0 + LIFT, 3.27, .22, 28, 4)
BARS, BAR_R = 8, 1.12
BRACKET = (1.62, 15.7 + LIFT, 12.2 + LIFT)
SIZE = {"lantern_beacon_frame": [6.89, 21.2, 5.99], "lantern_beacon_lens": [2.09, 5.2, 2.09]}
SRC = kit.SKETCH / "src/combat"


def warden_rows():
    """The clamp seat, the weak-point radius and every family's weak point in the frame's space, from warden.gd and
    warden_kit.gd (the Warden sits HALF_HEIGHT over the beacon's origin; family_point_at adds the kit's offset)."""
    warden, wkit = (SRC / "warden.gd").read_text(), (SRC / "warden_kit.gd").read_text()

    def const(text, name):
        found = re.search(r"^const %s := ([0-9.]+)$" % name, text, re.M)
        assert found, name
        return float(found.group(1))

    half, radius, choir = (const(warden, k) for k in ("HALF_HEIGHT", "FAMILY_POINT_RADIUS", "CHOIR_RADIUS"))
    deck = const(wkit, "DECK")
    body = wkit.split("func point_offset()")[1].split("\nfunc ")[0]
    offsets = dict(re.findall(r"Roster\.(\w+):\s*return Vector3\.UP \* \(DECK \+ ([0-9.]+)\)", body))
    mind = re.search(r"Roster\.MIND:.*?\n\t\t\treturn Vector3\.UP \* \(DECK \+ ([0-9.]+)\)", body, re.S)
    assert mind, "mind point offset"
    offsets["MIND"] = mind.group(1)
    assert sorted(offsets) == ["MIND", "REACTOR", "SWARM"], offsets
    points = {f.lower(): (0.0, half + deck + float(o), 0.0) for f, o in offsets.items()}
    y = points["mind"][1]
    for k in range(3):
        t = math.tau * k / 3
        points["choir_lens%d" % k] = (choir * math.cos(t), y, -choir * math.sin(t))
    return (0.0, half, 0.0), radius, points


def _closest(p, a, b, c):
    sub = lambda u, v: (u[0] - v[0], u[1] - v[1], u[2] - v[2])
    dot = lambda u, v: u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
    at = lambda o, u, s: (o[0] + u[0] * s, o[1] + u[1] * s, o[2] + u[2] * s)
    ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
    d1, d2 = dot(ab, ap), dot(ac, ap)
    if d1 <= 0 and d2 <= 0:
        return a
    bp = sub(p, b)
    d3, d4 = dot(ab, bp), dot(ac, bp)
    if d3 >= 0 and d4 <= d3:
        return b
    vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0:
        return at(a, ab, d1 / (d1 - d3))
    cp = sub(p, c)
    d5, d6 = dot(ab, cp), dot(ac, cp)
    if d6 >= 0 and d5 <= d6:
        return c
    vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0:
        return at(a, ac, d2 / (d2 - d6))
    va = d3 * d6 - d5 * d4
    if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0:
        return at(b, sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6)))
    den = 1 / (va + vb + vc)
    return at(at(a, ab, vb * den), ac, vc * den)


def assert_clear(name, surfaces, offset=(0, 0, 0)):
    """Exact distance from every weak-point centre to every triangle (fan of each authored face) of these surfaces,
    placed at offset in the frame; each must be at least the weak-point radius. Returns {point: clearance}."""
    _, radius, points = warden_rows()
    tris = []
    for s in surfaces:
        v = [(x + offset[0], y + offset[1], z + offset[2]) for x, y, z in s.verts]
        for f in s.faces:
            tris.extend((v[f[0]], v[f[i]], v[f[i + 1]]) for i in range(1, len(f) - 1))
    out = {}
    for point, p in sorted(points.items()):
        out[point] = min(math.dist(p, _closest(p, *t)) for t in tris)
        print("LANTERN_CLAMP_CLEARANCE", name, point, round(out[point], 3), "sphere", radius)
    assert all(d >= radius for d in out.values()), (name, out, radius)
    return out


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


def leg(s, angle):
    a = math.radians(angle)
    rings = [[(r * math.sin(a) + LEG_R * math.sin(b), y, r * math.cos(a) + LEG_R * math.cos(b))
              for b in around(LEG_SIDES)] for r, y in LEG_PATH]
    n = LEG_SIDES
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    s.add([v for ring in rings for v in ring], faces, TONES["leg"])
    r, y = LEG_PATH[-1]
    frustum(s, .36, .30, 0, y + .12, 6, TONES["foot"], caps=(True, False), at=(r * math.sin(a), r * math.cos(a)))


def halo(s):
    cy, big, tube, n, m = RING
    verts = []
    for a in around(n):
        cx, cyy = big * math.sin(a), cy + big * math.cos(a)
        for b in around(m, math.pi / m):
            radial = tube * math.cos(b)
            verts.append((cx + radial * math.sin(a), cyy + radial * math.cos(a), tube * math.sin(b)))
    faces = [(i * m + j, i * m + (j + 1) % m, ((i + 1) % n) * m + (j + 1) % m, ((i + 1) % n) * m + j)
             for i in range(n) for j in range(m)]
    s.add(verts, faces, TONES["state"])


def cone(s):
    r, y0, y1 = CAP
    aa = around(12, math.pi / 12)
    verts = [(r * math.sin(a), y0, r * math.cos(a)) for a in aa] + [(0, y1, 0)]
    s.add(verts, [(i, (i + 1) % 12, 12) for i in range(12)] + [tuple(reversed(range(12)))], TONES["state"])


def steel(s):
    for angle in LEG_ANGLES:
        leg(s, angle)
    frustum(s, COLLAR[0], COLLAR[1], COLLAR[2], COLLAR[3], 12, TONES["copper"], caps=(True, False))
    for a in around(BARS, math.pi / BARS):
        x, z = BAR_R * math.sin(a), BAR_R * math.cos(a)
        strut(s, (x, GLASS[1], z), (x, GLASS[2], z), .10, .10, TONES["copper"])
    out, top, bottom = BRACKET
    for side in (-1, 1):
        strut(s, (side * 1.2, top, 0), (side * out, top, 0), .10, .10, TONES["copper"])
        strut(s, (side * out, top + .05, 0), (side * out, bottom - .05, 0), .10, .10, TONES["copper"])
        strut(s, (side * out, bottom, 0), (side * BAR_R, bottom, 0), .10, .10, TONES["copper"])
    halo(s)
    cone(s)
    kit.PARTS["Halo"] = {"reference_position": [0, RING[0], 0]}


def enamel(s):
    frustum(s, PLATFORM[0], PLATFORM[0], PLATFORM[1], PLATFORM[2], 16, TONES["platform"])
    for r, y0, y1 in (BASE_BAND, TOP_BAND, TOP_FIT):
        frustum(s, r, r, y0, y1, 12, TONES["copper"])


def lens(s):
    r, y0, y1 = GLASS
    frustum(s, r, r, 0, y1 - y0, 12, TONES["lens"])


def export(name, surfaces, sockets, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    built = []
    for part, slot, smooth, build in surfaces:
        s = kit.Surface(part, slot, smooth=smooth)
        build(s)
        s.finish(root)
        built.append(s)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], LANDMARK)), (name, metrics, LANDMARK)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("LANTERN_BEACON_EXPORT", name, json.dumps(row, sort_keys=True))
    return built


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish_on()
    seat, _, _ = warden_rows()
    frame = export("lantern_beacon_frame", [("Frame", "steel", False, steel), ("Housing", "enamel", False, enamel)],
                   {"socket_lens": [0, GLASS[1], 0], "socket_ring": [0, RING[0], 0], "socket_clamp": list(seat)},
                   args.out_dir)
    lens_part = export("lantern_beacon_lens", [("Lens", "glass", True, lens)], {}, args.out_dir)
    assert_clear("lantern_beacon_frame", frame)
    assert_clear("lantern_beacon_lens", lens_part, (0, GLASS[1], 0))


if __name__ == "__main__":
    main()
