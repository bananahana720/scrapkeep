"""Headless recipe for kicker_wedge.glb and kicker_wedge_stripes.glb, the Slag Bowl kicker in the approved FLUX.1
schnell concept picture artifacts/local/alpha/push/w12/concepts/boards/alpha-props/kicker_wedge_101.png: a dark
riveted wedge, a striped riding face that fades to bare plate at the low end, and a striped cap bar on the top lip.

Same route as ore_cart.py and lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, a material named for its
dig_scenery.gd SLOTS key. Two prop-class GLBs at one origin (one draw each): kicker_wedge (steel: cheeks, skirts,
face plate, back wall, rivets, bolts, a patch plate) and kicker_wedge_stripes (enamel: the face stripes and the cap
bar). A kicker is ridden, not hostile, so the stripes are AMBER and CHARCOAL enamel, never the hazard_stripe slot.

Footprint (src/boss/arena.gd:315-333, KICKER_LENGTH 7.0, KICKER_TOP 1.6, KICKER_HALF_WIDTH 3.0 at :33-35): origin
at the foot's centre on the floor, +Z is `forward` (the ring tangent), the riding plane rises from y 0 at z 0 to
y 1.6 at z 7 across x -3..3, which is the collider hull's sloped face. The picture's quarter-pipe curve fights that
planar collider, so the footprint wins: the riding face is planar and only the lip behind the top edge is rounded.
The recipe asserts that nothing over the collider's footprint rises more than RIDE_PROUD above the plane.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/kicker_wedge.py [-- --out-dir DIR]
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
PROP = [520, 520, 1]

TONES = {
    "body": "charcoal",
    "face": "6f7f8f",
    "rivet": "6f7f8f",
    "patch": "oxide",
    "stripe": ["amber", "charcoal"],
    "cap": "amber",
}

LENGTH, TOP, HALF = 7.0, 1.6, 3.0
SLOPE = math.hypot(LENGTH, TOP)
UP_SLOPE = Vector((0, TOP, LENGTH)) / SLOPE
NORMAL = Vector((0, LENGTH, -TOP)) / SLOPE
CHEEK = .15
SKIRT = (.07, .32)
FACE_SINK = .010
RIDE_PROUD = .016
CAP_V = SLOPE - .55
BACK = .12
STRIPE_W = .75
STRIPE_C0 = -9.0
FADE_V, FADE_K = 3.5, .30
FADE_STEP = [0, .45, .15, .6, .25, .5, .1, .4, .3, .55, .2, .35, .05, .5]
MIN_BAND = .2
CAP_SEGMENTS = 7
CAP_GAP = .25
CAP_SHEAR = .9
RIVETS = [(2.6, .38), (3.9, .38), (5.2, .38), (6.5, .38), (4.6, .82), (6.1, 1.12)]
SIZE = {"kicker_wedge": [6.14, 1.6, 7.0], "kicker_wedge_stripes": [5.7, 1.011, 4.538]}


def tone(name, k=0):
    row = TONES[name]
    return row[k % len(row)] if isinstance(row, list) else row


def plane_y(z):
    return TOP * z / LENGTH


def face(u, v, h=0.0):
    """Face space to Godot space: u across (x), v up the slope from the foot, h along the face normal."""
    return tuple(Vector((u, 0, 0)) + UP_SLOPE * v + NORMAL * h)


def solid(s, bottom, top, color):
    """Closed prism between two matching rings (convex polygons), so the normal pass sees a closed island."""
    n = len(bottom)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    s.add(list(bottom) + list(top), faces, color)


def extrude_x(s, profile, x0, x1, color, shear=(0.0, 0.0)):
    """A (z, y) profile extruded across x; shear leans each end by k * (y - TOP) so band edges run diagonal."""
    solid(s, [(x0 + shear[0] * (y - TOP), y, z) for z, y in profile],
          [(x1 + shear[1] * (y - TOP), y, z) for z, y in profile], color)


def slab(s, poly, h0, h1, color):
    """A face-space polygon [(u, v)] lifted into a slab between heights h0 and h1 off the riding plane."""
    solid(s, [face(u, v, h0) for u, v in poly], [face(u, v, h1) for u, v in poly], color)


def stud(s, centre, axis, r0, r1, h, color, sides=4, spin=math.pi / 4):
    """A bolt head or rivet: a short frustum standing on `centre` along `axis`, base open (it sits on a surface)."""
    a = Vector(axis).normalized()
    e1 = a.cross(Vector((0, 1, 0)) if abs(a.y) < .9 else Vector((1, 0, 0))).normalized()
    e2 = a.cross(e1)
    c = Vector(centre)
    rings = []
    for r, lift in ((r0, -.01), (r1, h)):
        rings.append([tuple(c + a * lift + (e1 * math.cos(t) + e2 * math.sin(t)) * r)
                      for t in (spin + math.tau * i / sides for i in range(sides))])
    faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
    faces.append(tuple(range(sides, 2 * sides)))
    s.add(rings[0] + rings[1], faces, color)


def clip(poly, keep):
    """Sutherland-Hodgman: keep the part of a convex polygon where keep(p) >= 0 (keep is affine in u, v)."""
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        fp, fq = keep(p), keep(q)
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def area(poly):
    return .5 * abs(sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(poly, poly[1:] + poly[:1])))


def stripes(v_top, inner):
    """The striped bands of the riding face, each clipped to the face and to its own fade edge."""
    bands = []
    k = 0
    c = STRIPE_C0
    while c < inner + v_top:
        step = FADE_STEP[k % len(FADE_STEP)]
        poly = [(-inner, 0), (inner, 0), (inner, v_top), (-inner, v_top)]
        for keep in (lambda p, c=c: p[0] + p[1] - c, lambda p, c=c: c + STRIPE_W - p[0] - p[1],
                     lambda p, step=step: p[1] - (FADE_V + step + FADE_K * p[0])):
            poly = clip(poly, keep) if len(poly) >= 3 else []
        if len(poly) >= 3 and area(poly) >= MIN_BAND:
            bands.append((k, [(round(u, 6), round(v, 6)) for u, v in poly]))
        k += 1
        c += STRIPE_W
    return bands


def body(s):
    inner = HALF - CHEEK
    for side in (-1, 1):
        x_in, x_out = side * inner, side * HALF
        extrude_x(s, [(0, 0), (LENGTH, 0), (LENGTH, TOP)], x_in, x_out, tone("body"))
        rise = SKIRT[1] * LENGTH / TOP
        extrude_x(s, [(0, 0), (LENGTH, 0), (LENGTH, SKIRT[1]), (rise, SKIRT[1])], x_out, side * (HALF + SKIRT[0]), tone("body"))
        for z, y in RIVETS:
            stud(s, (side * (HALF + (SKIRT[0] if y < SKIRT[1] else 0)), y, z), (side, 0, 0), .09, .06, .05, tone("rivet"), sides=8)
    top0, top1, bot1 = face(0, .06, -FACE_SINK), face(0, CAP_V, -FACE_SINK), face(0, CAP_V, -.08)
    extrude_x(s, [(top0[2], top0[1]), (top1[2], top1[1]), (bot1[2], bot1[1]), (top0[2] + .35, 0)], -inner, inner, tone("face"))
    s.box((2 * HALF, 1.2, BACK), (0, .6, LENGTH - BACK / 2), tone("body"))
    for u in (-inner + .22, inner - .22):
        stud(s, face(u, .9, -FACE_SINK), NORMAL, .08, .06, FACE_SINK + RIDE_PROUD * .5, tone("rivet"))
    s.box((.03, .42, .9), (HALF + .015, .62, 4.3), tone("patch"))
    kit.PARTS["RideFace"] = {"reference_position": list(face(0, SLOPE / 2))}


def enamel(s):
    inner = HALF - CHEEK
    for k, poly in stripes(CAP_V - CAP_GAP, inner):
        slab(s, poly, -FACE_SINK - .01, 0.0, tone("stripe", k))
    z0 = CAP_V * UP_SLOPE.z
    profile = [(z0, plane_y(z0)), (LENGTH, TOP), (LENGTH + .18, TOP - .1), (LENGTH + .2, 1.2), (z0 + .1, 1.2)]
    xs = [-inner + i * (2 * inner) / CAP_SEGMENTS for i in range(CAP_SEGMENTS + 1)]
    for i in range(CAP_SEGMENTS):
        lean = (0.0 if i == 0 else CAP_SHEAR, 0.0 if i == CAP_SEGMENTS - 1 else CAP_SHEAR)
        extrude_x(s, [(z, y - (0 if i % 2 else .002)) for z, y in profile], xs[i], xs[i + 1],
                  tone("cap") if i % 2 == 0 else tone("stripe", 1), lean)
    kit.PARTS["CapBar"] = {"reference_position": [0, TOP, LENGTH]}


def ride_check(path_verts):
    """Nothing over the collider footprint may stand more than RIDE_PROUD above the riding plane."""
    worst = max((y - plane_y(z) for x, y, z in path_verts if abs(x) <= HALF + 1e-6 and 0 <= z <= LENGTH), default=-1)
    assert worst <= RIDE_PROUD + 1e-6, ("riding plane", worst)
    return worst


def export(name, part, slot, build, sockets, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(part, slot, smooth=False)
    build(s)
    proud = ride_check(s.verts)
    s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], PROP)), (name, metrics, PROP)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    size = metrics["bounds"]["size"]
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "ride_proud": round(proud, 4)}
    print("KICKER_WEDGE_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    polish.enable(bevel=.02, bevel_min=.3, **kit.BAKE)
    kit.FINISH.update({"Stripes": {"bevel": 0}})
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    export("kicker_wedge", "Body", "steel", body, {"socket_lip": [0, TOP, LENGTH]}, args.out_dir)
    export("kicker_wedge_stripes", "Stripes", "enamel", enamel, {}, args.out_dir)


if __name__ == "__main__":
    main()
