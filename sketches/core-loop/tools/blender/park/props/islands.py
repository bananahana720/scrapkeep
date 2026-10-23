"""Islands park dressing kit (Highdraft, stage 5; contract: design-v3/park/DRESSING-KITS.md).

Three crews left their things on the isles. The net-weavers re-string everything they find and
keep count with stones and knots. The Fleet's mooring crew pinned its kites down and walked off
the bench mid-shift. The old ore tram ran out of track before it ran out of ore. Fleet signs
only: moored kites, an empty crew bench, sails left drying. Brass goes on Fleet gear alone.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/islands.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, tint
from mathutils import Matrix, Vector

K = kit.Kit("islands")

ROPE = mix(C["canvas_dark"], C["timber_pale"], 0.45)
ROPE_DARK = mix(ROPE, C["timber_dark"], 0.35)
NET = mix(C["canvas_stain"], C["timber_grey"], 0.5)
CORK = mix(C["timber_pale"], C["sandstone_pale"], 0.4)
BRASS = "d9b44a"  # Fleet gear only, never dominant
SAIL = mix(C["canvas"], C["bone"], 0.3)
SAIL_STRIPE = mix(C["canvas_stain"], C["verdigris"], 0.25)
ORE = mix(C["iron"], C["sandstone_dark"], 0.35)


def stones(p, rng, at, n, size, colour, spread=0.5, flat=0.55):
    """A few rounded stones around a point on the floor."""
    for _ in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.2, 1.0) * spread
        s = size * rng.uniform(0.7, 1.2)
        p.uv(s, (at[0] + r * math.cos(a), at[1] + r * math.sin(a), s * flat * 0.6), tint(colour, rng, 0.06),
             scale=(1.0, rng.uniform(0.7, 1.0), flat), rot=(0, 0, rng.uniform(0, 3)), u=8, v=5)


def net_patch(p, rng, x0, y0, w, d, z, cell=0.35, colour=NET, sag=0.0, tilt_y=0.0):
    """A flat square-mesh net lying on the floor: crossing rods, `sag` lifts the middle."""
    nx, ny = max(2, int(w / cell)), max(2, int(d / cell))

    def h(x, y):
        u, v = (x - x0) / w, (y - y0) / d
        return z + sag * 4 * u * (1 - u) * 4 * v * (1 - v) * 0.25 + tilt_y * v

    for i in range(nx + 1):
        x = x0 + w * i / nx
        pts = [(x, y0 + d * j / 3, h(x, y0 + d * j / 3)) for j in range(4)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.018, colour, segs=4, style="flat")
    for j in range(ny + 1):
        y = y0 + d * j / ny
        pts = [(x0 + w * i / 3, y, h(x0 + w * i / 3, y)) for i in range(4)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.018, colour, segs=4, style="flat")


def rope_line(p, pts, colour=ROPE, r=0.035):
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, r, colour, segs=5, style="flat")


# --- heroes ---------------------------------------------------------------------------------

@K.kind("net_hoard", hero=True, tags=["soft"], variants="ab",
        story="The weavers' hoard: every net the isles ever dropped, heaped, floated and half re-strung.")
def net_hoard(p, v, rng):
    # The heap: overlapping soft lobes of bundled net.
    lobes = [((0, 0, 0.75), (2.1, 1.7, 0.95)), ((-1.2, 0.5, 0.55), (1.3, 1.1, 0.7)),
             ((1.1, -0.4, 0.5), (1.2, 1.2, 0.62)), ((0.3, 0.9, 1.25), (1.0, 0.8, 0.6))]
    if v == "b":
        lobes = [((0, 0, 0.6), (2.3, 1.6, 0.75)), ((-1.4, -0.2, 0.42), (1.2, 1.3, 0.55)),
                 ((1.3, 0.5, 0.45), (1.1, 1.0, 0.6))]
    for k, (loc, sc) in enumerate(lobes):
        col = tint(NET if k % 2 == 0 else mix(NET, C["canvas_dark"], 0.5), rng, 0.05)
        p.ico(1.0, loc, col, scale=sc, rot=(0, 0, rng.uniform(0, 3)), subdiv=1, style="soft")
    # Rope bands binding the bundles, and coils of rope on top.
    for k in range(5 if v == "a" else 3):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(1.0, 1.6)
        p.torus(r, 0.05, (0.0, 0.0, 0.55 + 0.12 * k), ROPE_DARK, rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), a),
                scale=(1.15, 0.9, 1.0), major=16, minor=5, style="flat")
    for k in range(3):
        p.torus(0.42 - 0.08 * k, 0.07, (-0.4 + 0.1 * k, -0.7, 1.35 + 0.13 * k if v == "a" else 1.05 + 0.13 * k),
                ROPE, major=14, minor=6, style="flat")
    # Cork floats strung around the heap in a slack loop.
    n = 13 if v == "a" else 12
    for k in range(n):
        a = math.tau * k / n
        rx, ry = 2.35, 1.95
        z = 0.12 + 0.35 * (0.5 + 0.5 * math.sin(a * 2 + 0.5))
        p.cyl(0.14, 0.24, (rx * math.cos(a), ry * math.sin(a), z), tint(CORK, rng, 0.07), segs=6,
              rot=(0, math.pi / 2, a + math.pi / 2), style="round")
    pts = []
    for k in range(n * 2 + 1):
        a = math.tau * k / (n * 2)
        pts.append((2.35 * math.cos(a), 1.95 * math.sin(a), 0.12 + 0.35 * (0.5 + 0.5 * math.sin(a * 2 + 0.5))))
    rope_line(p, pts, ROPE_DARK, 0.03)
    # A big timber net spool beside the heap (rolled away in b), and a weaving needle.
    sx, sy, srot = (2.6, 1.2, 0.0) if v == "a" else (3.4, -1.6, 0.6)
    face = (math.pi / 2, 0, srot)
    p.cyl(0.32, 1.1, (sx, sy, 0.62), C["timber"], segs=12, rot=face, style="round")
    for s in (-0.55, 0.55):
        dx, dy = s * math.sin(srot) * -1, s * math.cos(srot)
        p.cyl(0.62, 0.1, (sx + dx * 1.0, sy + dy, 0.62), tint(C["timber_dark"], rng), segs=14, rot=face, style="hard_smooth")
    for k in range(4):
        p.torus(0.36, 0.05, (sx + (-0.36 + 0.24 * k) * -math.sin(srot), sy + (-0.36 + 0.24 * k) * math.cos(srot), 0.62),
                ROPE, rot=face, major=14, minor=5, style="flat")
    p.box((0.9, 0.12, 0.04), (-2.3, -1.6, 0.05), C["timber_pale"], rot=(0, 0, 0.6), style="hard_smooth")
    p.box((0.18, 0.2, 0.04), (-1.9, -1.32, 0.05), C["timber_pale"], rot=(0, 0, 0.6), style="hard_smooth")
    # Net pulled out across the ground, half re-strung.
    if v == "a":
        net_patch(p, rng, -3.6, 0.6, 2.0, 2.2, 0.05, cell=0.4, sag=0.3)
    else:
        net_patch(p, rng, -1.5, -3.8, 3.2, 1.9, 0.05, cell=0.32, sag=0.2)
        net_patch(p, rng, 1.5, 1.8, 1.6, 1.4, 0.06, cell=0.3, colour=ROPE_DARK)
    stones(p, rng, (-0.5, 2.4), 2, 0.26, C["sandstone"], spread=0.9)


@K.kind("moored_kite", hero=True, tags=["soft"], variants="ab",
        story="A Fleet cargo kite pinned nose-down for the night. The crew never came back for it. Its reel is brass.")
def moored_kite(p, v, rng):
    span, length = 6.4, 4.6
    fold = 0.0 if v == "a" else 1.0
    # Sail: two wings either side of the keel spar, nose propped on a trestle, trailing edge on the floor.
    nose = (0.0, -length / 2, 1.9 - 0.6 * fold)
    tail = (0.0, length / 2, 0.25)
    for s in (-1, 1):
        tip = (s * span / 2 * (1 - 0.35 * fold), length * 0.15, 0.25 + 0.5 * fold)
        # The wing is one flat triangle (nose, tip, tail) cut into bands parallel to the keel, so the panels read.
        X = (Vector(tail) - Vector(nose)).normalized()
        Y = Vector(tip) - Vector(nose)
        Y = (Y - X * Y.dot(X)).normalized()
        frame = Matrix((X, Y, X.cross(Y))).transposed().to_euler()

        def local(pt):
            d = Vector(pt) - Vector(nose)
            return (d.dot(X), d.dot(Y))

        bands = 4
        for k in range(bands):
            t0, t1 = k / bands, (k + 1) / bands
            quad = [local(tuple(nose[i] + (tip[i] - nose[i]) * t for i in range(3))) for t in (t0, t1)]
            quad += [local(tuple(tail[i] + (tip[i] - tail[i]) * t for i in range(3))) for t in (t1, t0)]
            if k == bands - 1:
                quad = quad[:3]
            if s < 0:
                quad = quad[::-1]  # keep the outline counter-clockwise in the wing's frame
            col = SAIL_STRIPE if k % 2 else SAIL
            if fold and s == 1:
                col = mix(col, C["canvas_dark"], 0.3)
            p.prism(quad, 0.05, nose, col, rot=tuple(frame), style="hard_smooth")
        # Leading-edge spar with a brass tip cap.
        p.rod(nose, tip, 0.055, C["timber_dark"], segs=8)
        p.uv(0.09, tip, BRASS, u=8, v=5)
    if fold:
        p.ico(0.8, (1.4, 0.6, 0.55), mix(SAIL, C["canvas_dark"], 0.4), scale=(1.6, 1.1, 0.5), rot=(0.2, 0, 0.7), subdiv=1, style="round")
    p.rod(nose, tail, 0.07, C["timber_dark"], segs=8)
    # Nose trestle: a short X under the nose, lashed.
    for s in (-1, 1):
        p.rod((s * 0.55, nose[1] - 0.2, 0.0), (-s * 0.12, nose[1], nose[2] - 0.05), 0.06, C["timber"], segs=6)
    p.torus(0.1, 0.035, (0, nose[1], nose[2] - 0.08), ROPE, major=10, minor=5, style="flat")
    # Tail ribbon lying in slack loops behind.
    ribbon = [(0.0, length / 2, 0.22), (0.35, length / 2 + 0.6, 0.05), (-0.25, length / 2 + 1.3, 0.04),
              (0.3, length / 2 + 2.0, 0.04), (0.05, length / 2 + 2.6, 0.04)]
    for k, (a, b) in enumerate(zip(ribbon, ribbon[1:])):
        p.beam(a, b, 0.16, SAIL_STRIPE if k % 2 else SAIL, h=0.03, style="fine")
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        p.box((0.24, 0.1, 0.05), mid, C["canvas_stain"], rot=(0, 0, rng.uniform(-0.4, 0.4)), style="fine")
    # Ground pegs and sandbags at each wing tip and the tail.
    for s in (-1, 1):
        bx, by = s * (span / 2 * (1 - 0.35 * fold) + 0.4), length * 0.15
        for k in range(2):
            p.ico(0.32, (bx + 0.2 * k * s, by + 0.3 * k, 0.17 + 0.18 * k), tint(C["canvas_dark"], rng, 0.06),
                  scale=(1.2, 0.8, 0.55), rot=(0, 0, rng.uniform(0, 3)), style="round")
        p.cyl(0.04, 0.5, (bx - 0.25 * s, by - 0.35, 0.18), C["timber_dark"], segs=6, rot=(0.35 * s, 0, 0))
        rope_line(p, [(bx - 0.25 * s, by - 0.35, 0.36), (s * span / 2 * (1 - 0.35 * fold) * 0.92, length * 0.15, 0.3)], ROPE, 0.025)
    # Brass tether reel on a timber sledge, the slack line coiled beside it.
    rx, ry = (1.6, -length / 2 - 1.2) if v == "a" else (-1.8, -length / 2 - 0.9)
    p.box((1.2, 0.7, 0.14), (rx, ry, 0.07), C["timber"], style="hard_smooth")
    for s in (-0.35, 0.35):
        p.box((1.3, 0.12, 0.12), (rx, ry + s, 0.06), C["timber_dark"], style="hard_smooth")
        p.cyl(0.36, 0.06, (rx, ry + s * 0.9, 0.55), BRASS if s < 0 else mix(BRASS, C["iron"], 0.35), segs=14,
              rot=(math.pi / 2, 0, 0), style="hard_smooth")
        p.box((0.12, 0.08, 0.45), (rx, ry + s * 1.05, 0.33), C["iron"], style="hard_smooth")
    p.cyl(0.24, 0.55, (rx, ry, 0.55), ROPE, segs=12, rot=(math.pi / 2, 0, 0), style="round")
    p.cyl(0.03, 0.35, (rx + 0.45, ry + 0.38, 0.6), C["iron_light"], segs=6, rot=(0, math.pi / 2, 0))
    rope_line(p, [(rx, ry, 0.35), (rx * 0.6, ry * 0.85, 0.06), (0.25, -length / 2 - 0.2, 0.05), (0.0, nose[1], nose[2] - 0.1)],
              ROPE, 0.025)
    for k in range(3):
        p.torus(0.38 - 0.05 * k, 0.04, (rx - 1.1, ry + 0.2, 0.04 + 0.07 * k), ROPE, major=14, minor=5, style="flat")


@K.kind("tram_bogie", hero=True, tags=["machine"], variants="ab",
        story="An ore tram car that ran off the end of the track and stayed. The weavers charge it rent.")
def tram_bogie(p, v, rng):
    tipped = v == "a"
    hop = C["rust"] if tipped else mix(C["iron"], C["rust"], 0.45)

    def place(x, y, z):
        # Car frame: on its side (a) rolls 80 degrees about the long axis (Y).
        if not tipped:
            return (x, y, z + 0.35)
        roll = math.radians(82)  # matches the parts' Blender Y rotation
        return (x * math.cos(roll) + z * math.sin(roll), y, -x * math.sin(roll) + z * math.cos(roll) + 1.32)

    rot = (0, math.radians(82), 0) if tipped else (0, 0, 0)
    # Hopper: a tapering steel tub of plates with angle bands.
    hop_outline = [(-0.95, -0.2), (0.95, -0.2), (1.25, 1.25), (-1.25, 1.25)]
    for y in (-1.35, 1.35):
        p.prism(hop_outline, 0.1, place(0, y, 0.5), hop, rot=(math.pi / 2, rot[1], 0), style="hard_smooth")
    p.box((1.9, 2.6, 0.1), place(0, 0, 0.3), tint(hop, rng), rot=rot, style="hard_smooth")
    for s in (-1, 1):
        p.box((0.1, 2.6, 1.5), place(s * 1.1, 0, 0.98), tint(hop, rng), rot=(rot[0], rot[1] + s * 0.2, 0), style="hard_smooth")
    for y in (-1.0, 0.0, 1.0):
        for s in (-1, 1):
            p.box((0.13, 0.14, 1.52), place(s * 1.17, y, 0.98), C["iron"], rot=(rot[0], rot[1] + s * 0.2, 0))
    for s in (-1, 1):
        p.box((2.7, 0.14, 0.14), place(0, s * 1.4, 1.75), C["iron"], rot=rot)
    # Chassis, axles and four spoked wheels.
    p.box((1.3, 3.0, 0.24), place(0, 0, 0.1), C["iron"], rot=rot)
    wheels = [(-1, -1), (1, -1), (-1, 1)] if not tipped else [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    for sx, sy in wheels:
        wx, wy, wz = sx * 0.78, sy * 0.95, -0.15
        cyl_rot = (0, math.pi / 2 + rot[1], 0)
        p.cyl(0.38, 0.12, place(wx, wy, wz), C["iron_light"] if tipped else C["iron"], segs=16, rot=cyl_rot, style="hard_smooth")
        p.cyl(0.12, 0.2, place(wx, wy, wz), C["charcoal"], segs=10, rot=cyl_rot, style="round")
        p.torus(0.42, 0.05, place(wx + sx * 0.05, wy, wz), C["iron"], rot=cyl_rot, major=12, minor=4)
    for sy in (-0.95, 0.95):
        p.cyl(0.06, 1.7, place(0, sy, -0.15), C["iron"], segs=8, rot=(0, math.pi / 2 + rot[1], 0))
    # Couplers and a hand brake lever.
    for sy in (-1.6, 1.6):
        p.cyl(0.1, 0.35, place(0, sy, 0.15), C["iron"], segs=8, rot=(math.pi / 2, rot[1], 0))
        p.torus(0.14, 0.04, place(0, sy * 1.12, 0.15), C["iron_light"], rot=(0, math.pi / 2 + rot[1], 0), major=10, minor=5)
    if not tipped:
        # The fourth wheel lies flat beside the car; the corner it left sits on two sleepers.
        p.cyl(0.38, 0.12, (1.9, 1.8, 0.06), C["iron"], segs=16, style="hard_smooth")
        p.cyl(0.12, 0.2, (1.9, 1.8, 0.1), C["charcoal"], segs=10, style="round")
        for k in range(2):
            p.box((1.3, 0.28, 0.2), (0.8, 0.95, 0.1 + 0.2 * k), tint(C["timber_grey"], rng), rot=(0, 0, 0.1 + 0.4 * k), style="hard_smooth")
        # Ore still in the tub, and a juniper sprig growing through it.
        p.ico(1.0, (0, 0, 1.7), ORE, scale=(1.05, 1.25, 0.32), subdiv=1, style="round")
        for k in range(9):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0.1, 0.8)
            p.ico(0.17, (r * math.cos(a) * 0.9, r * math.sin(a) * 1.1, 1.9), tint(ORE if k % 3 else C["verdigris"], rng, 0.08),
                  scale=(1, 0.8, 0.7), rot=(rng.uniform(0, 2), 0, rng.uniform(0, 3)), style="round")
        p.rod((0.4, 0.5, 1.8), (0.55, 0.65, 2.5), 0.05, C["timber_dark"])
        for k in range(4):
            p.ico(0.3, (0.55 + 0.25 * math.cos(k * 1.7), 0.65 + 0.25 * math.sin(k * 1.7), 2.45 + 0.12 * k),
                  tint(C["leaf_dark"] if k % 2 else C["leaf"], rng, 0.06), scale=(1, 1, 0.7), style="round")
    else:
        # Spilled ore fanning from the mouth.
        p.ico(1.0, (2.6, 0.0, 0.3), ORE, scale=(1.4, 1.8, 0.35), subdiv=1, style="round")
        for k in range(14):
            a = rng.uniform(-1.2, 1.2)
            r = rng.uniform(0.4, 2.4)
            p.ico(0.17, (2.4 + r * math.cos(a), r * math.sin(a), 0.2), tint(ORE if k % 3 else C["verdigris"], rng, 0.08),
                  scale=(1, 0.8, 0.7), rot=(rng.uniform(0, 2), 0, rng.uniform(0, 3)), style="round")
    # A short broken section of track the car left behind: three sleepers and two stub rails, low and short.
    ty = -3.2
    for k in range(3):
        p.box((1.6, 0.26, 0.14), (0.4 + 0.1 * k, ty - 0.55 * k, 0.07), tint(C["timber_grey"], rng),
              rot=(0, 0, rng.uniform(-0.15, 0.15)), style="hard_smooth")
    for s in (-1, 1):
        p.box((0.1, 1.6 if s < 0 else 1.1, 0.12), (0.4 + s * 0.5, ty - 0.55, 0.2), C["iron"], rot=(0, 0, 0.05 * s), style="hard_smooth")
    stones(p, rng, (-1.6, 2.2), 4, 0.28, C["sandstone_dark"], spread=0.8)


# --- props ----------------------------------------------------------------------------------

@K.kind("weaver_cairn", tags=[], variants="abc", polish_opts={"detail": 1},
        story="A weavers' cairn: one stone per crossing. The top stone is the newest, so it is the warm one.")
def weaver_cairn(p, v, rng):
    def stack(x, y, n, base):
        z = 0.0
        for k in range(n):
            s = base * (1 - 0.11 * k) * rng.uniform(0.92, 1.05)
            h = s * 0.5
            col = C["bone"] if k == n - 1 else tint(C["sandstone"] if k % 2 else C["sandstone_dark"], rng, 0.05)
            p.uv(s, (x + rng.uniform(-0.04, 0.04), y + rng.uniform(-0.04, 0.04), z + h * 0.55), col,
                 scale=(1.0, rng.uniform(0.8, 0.95), 0.5), rot=(rng.uniform(-0.08, 0.08), 0, rng.uniform(0, 3)), u=8, v=5)
            z += h * 0.95
        return z

    if v == "a":
        top = stack(0, 0, 6, 0.42)
        p.torus(0.38, 0.03, (0, 0, 0.18), ROPE, major=12, minor=4, style="flat")
        rope_line(p, [(0.35, -0.1, 0.18), (0.5, -0.3, 0.02), (0.75, -0.25, 0.02)], ROPE, 0.025)
    elif v == "b":
        stack(-0.35, 0, 4, 0.36)
        stack(0.45, 0.2, 3, 0.32)
        stones(p, rng, (0.1, -0.5), 3, 0.15, C["sandstone"], spread=0.4)
    else:
        # Toppled: a short base and the rest rolled downwind.
        stack(0, 0, 2, 0.42)
        for k in range(4):
            s = 0.3 - 0.04 * k
            p.uv(s, (0.5 + 0.38 * k, 0.12 * k, s * 0.3), C["bone"] if k == 3 else tint(C["sandstone"], rng, 0.05),
                 scale=(1.0, 0.85, 0.5), rot=(0.3, 0.2, rng.uniform(0, 3)), u=8, v=5)


@K.kind("float_bundle", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Net floats strung on a loop and dropped where the last net came in.")
def float_bundle(p, v, rng):
    n = 9 if v == "a" else 6
    for k in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.1, 0.6)
        z = 0.12 + (0.2 if k > 5 else 0)
        glass = v == "b" and k % 3 == 0
        if glass:
            p.uv(0.16, (r * math.cos(a), r * math.sin(a), 0.15), mix(C["verdigris"], C["canvas"], 0.25), u=8, v=5)
        else:
            p.cyl(0.13, 0.22, (r * math.cos(a), r * math.sin(a), z), tint(CORK, rng, 0.07), segs=10,
                  rot=(rng.uniform(1.2, 1.9), 0, rng.uniform(0, 3)), style="round")
    pts = [(0.75 * math.cos(t), 0.6 * math.sin(t), 0.08 + 0.05 * math.sin(3 * t)) for t in [math.tau * k / 10 for k in range(11)]]
    rope_line(p, pts, ROPE_DARK, 0.028)
    rope_line(p, [pts[3], (0.9, 1.0, 0.03), (1.4, 1.1, 0.03)], ROPE_DARK, 0.028)
    if v == "a":
        net_patch(p, rng, -1.4, -0.9, 0.9, 0.8, 0.04, cell=0.3)


@K.kind("rope_coil", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="Hawser rope coiled the weavers' way: clockwise, tight, a knot on top to say whose.")
def rope_coil(p, v, rng):
    def coil(x, y, r, turns, lean=0.0, col=ROPE):
        for k in range(turns):
            p.torus(r * (1 - 0.06 * (k % 3)), 0.07, (x, y, 0.07 + 0.12 * k), tint(col, rng, 0.04),
                    rot=(lean, 0, rng.uniform(0, 3)), major=14, minor=6, style="flat")
        p.uv(0.11, (x + r * 0.6, y, 0.12 * turns + 0.05), ROPE_DARK, u=8, v=6)

    if v == "a":
        coil(0, 0, 0.55, 5)
        rope_line(p, [(0.55, 0, 0.1), (0.9, -0.3, 0.04), (1.3, -0.25, 0.04), (1.55, 0.1, 0.04)], ROPE, 0.06)
    else:
        coil(-0.4, 0, 0.5, 4, col=ROPE_DARK)
        # The second coil fell over and half unrolled.
        for k in range(3):
            p.torus(0.42, 0.07, (0.65 + 0.12 * k, 0.15, 0.42), ROPE, rot=(0, math.pi / 2 - 0.25, 0.4), major=14, minor=6, style="flat")
        rope_line(p, [(0.75, -0.25, 0.05), (1.2, -0.6, 0.05), (1.7, -0.5, 0.05)], ROPE, 0.06)


@K.kind("crew_bench", tags=[], variants="ab", polish_opts={"detail": 1},
        story="The mooring crew's bench, brass-capped. Empty. A jacket folded on it, a mug gone cold.")
def crew_bench(p, v, rng):
    broken = v == "b"
    top_z = 0.48
    tilt = 0.18 if broken else 0.0
    # Seat planks.
    for k in range(3):
        p.box((2.0, 0.14, 0.06), (0, -0.16 + 0.16 * k, top_z - (0.18 if broken else 0) + 0.0), tint(C["timber"], rng),
              rot=(0, -tilt, 0), style="hard_smooth")
    for sx in (-0.82, 0.82):
        if broken and sx > 0:
            p.box((0.1, 0.4, 0.3), (sx + 0.2, 0.05, 0.15), C["timber_dark"], rot=(0, 1.2, 0.3), style="hard_smooth")
            continue
        h = top_z - (0.18 if broken and sx > 0 else 0)
        for sy in (-0.18, 0.18):
            p.box((0.09, 0.09, h), (sx, sy, h / 2), C["timber_dark"], style="hard_smooth")
        p.box((0.12, 0.5, 0.08), (sx, 0, h - 0.1), C["timber_dark"], style="hard_smooth")
        for sy in (-0.24, 0.24):
            p.box((0.1, 0.06, 0.08), (sx, sy, top_z + 0.03 - (0.0)), BRASS, style="hard_smooth")
    # Folded flight jacket and a mug.
    jz = top_z + 0.07
    if broken:
        p.ico(0.3, (-1.2, 0.5, 0.12), C["timber_dark"], scale=(1.3, 1.0, 0.35), rot=(0, 0, 0.4), style="round")
        p.cyl(0.06, 0.12, (0.1, -0.6, 0.06), C["iron"], segs=10, style="round")
        p.cyl(0.18, 0.08, (-0.3, 0.6, 0.04), C["canvas_dark"], segs=12, r2=0.14, style="round")  # crew cap, dropped
    else:
        p.box((0.55, 0.38, 0.12), (-0.45, 0, jz + 0.03), C["timber_dark"], style="hard_smooth")
        p.box((0.5, 0.12, 0.05), (-0.45, -0.1, jz + 0.12), BRASS, style="fine")
        p.cyl(0.06, 0.12, (0.55, 0.05, jz + 0.03), C["iron"], segs=10, style="round")
        p.torus(0.04, 0.012, (0.62, 0.05, jz + 0.04), C["iron"], rot=(math.pi / 2, 0, 0), major=8, minor=4)
    stones(p, rng, (0.9, -0.6), 2, 0.12, C["sandstone"], spread=0.3)


@K.kind("spar_bundle", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Spare kite spars strapped in a bundle on two chocks, and a furled sail beside them.")
def spar_bundle(p, v, rng):
    spilled = v == "b"
    if not spilled:
        for s in (-0.9, 0.9):
            p.box((0.25, 0.7, 0.22), (s, 0, 0.11), tint(C["timber_dark"], rng), style="hard_smooth")
        for k in range(7):
            ox, oz = (k % 4) * 0.1 - 0.15, 0.3 + (k // 4) * 0.09
            p.cyl(0.045, 2.6, (0, -0.18 + ox, oz), tint(C["timber_pale"], rng, 0.06), segs=8, rot=(0, math.pi / 2, 0), style="round")
        for s in (-0.55, 0.55):
            p.torus(0.22, 0.03, (s, -0.08, 0.36), C["timber_dark"], rot=(0, math.pi / 2, 0), scale=(1.0, 1.3, 0.8), major=12, minor=4)
            p.box((0.06, 0.05, 0.05), (s, -0.08, 0.6), BRASS, style="fine")
        p.cyl(0.2, 2.1, (0.1, 0.55, 0.2), SAIL, segs=12, rot=(0, math.pi / 2, 0.05), style="round")
        for s in (-0.6, 0.0, 0.6):
            p.torus(0.21, 0.025, (0.1 + s, 0.55, 0.2), ROPE, rot=(0, math.pi / 2, 0), major=12, minor=4, style="flat")
    else:
        for k in range(6):
            a = rng.uniform(-0.5, 0.5)
            p.cyl(0.045, 2.5, (rng.uniform(-0.3, 0.3), -0.6 + 0.22 * k, 0.045), tint(C["timber_pale"], rng, 0.06), segs=8,
                  rot=(0, math.pi / 2, a), style="round")
        p.box((0.25, 0.7, 0.22), (-1.1, 0.5, 0.11), C["timber_dark"], rot=(0, 0, 0.6), style="hard_smooth")
        p.ico(0.5, (0.6, 0.9, 0.22), SAIL, scale=(1.6, 0.8, 0.45), rot=(0, 0, 0.3), style="round")
        p.torus(0.22, 0.03, (-0.4, 0.0, 0.03), C["timber_dark"], major=12, minor=4)


@K.kind("sandbag_mooring", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="A Fleet ground mooring: sandbags round a stake, a brass ring, and a tether cut short.")
def sandbag_mooring(p, v, rng):
    n = 6 if v == "a" else 4
    for k in range(n):
        a = math.tau * k / n + rng.uniform(-0.15, 0.15)
        r = 0.55
        p.ico(0.3, (r * math.cos(a), r * math.sin(a), 0.16), tint(C["canvas_dark"], rng, 0.06),
              scale=(1.25, 0.8, 0.55), rot=(0, 0, a + math.pi / 2), style="round")
    if v == "a":
        p.ico(0.3, (0.1, 0.2, 0.42), tint(C["canvas_stain"], rng, 0.05), scale=(1.25, 0.8, 0.5), rot=(0, 0, 1.0), style="round")
    p.cyl(0.07, 0.75, (0, 0, 0.37), C["timber_dark"], segs=8, style="round")
    p.torus(0.14, 0.03, (0.0, -0.09, 0.6), BRASS, rot=(math.pi / 2, 0, 0), major=12, minor=5)
    end = (0.9, -0.9, 0.04) if v == "a" else (-0.4, -1.1, 0.04)
    rope_line(p, [(0.0, -0.2, 0.55), (0.3, -0.5, 0.2), end], ROPE, 0.035)
    p.uv(0.07, end, ROPE_DARK, scale=(1.4, 1, 0.7), u=8, v=5)


@K.kind("ore_spill", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Ore the tram crew riddled and never hauled: a heap, a pick left in it, the sieve tipped over.")
def ore_spill(p, v, rng):
    p.ico(1.0, (0, 0, 0.36), mix(C["soil"], ORE, 0.4), scale=(1.0, 0.8, 0.42), subdiv=1, style="round")
    for k in range(7):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.1, 0.8)
        p.ico(0.16, (r * math.cos(a), r * math.sin(a) * 0.8, 0.32 * (1 - r) + 0.42),
              tint(ORE if k % 3 else C["verdigris"], rng, 0.08), scale=(1, 0.8, 0.7), rot=(rng.uniform(0, 2), 0, rng.uniform(0, 3)),
              style="round")
    if v == "a":
        # Pick stuck in the heap.
        p.rod((0.1, 0.1, 0.6), (0.35, 0.25, 1.35), 0.035, C["timber"])
        p.beam((0.12, -0.1, 1.34), (0.6, 0.6, 1.38), 0.06, C["iron"], h=0.07)
        # Sieve tipped on its edge.
        p.ring(0.32, 0.37, 0.12, (-1.2, 0.5, 0.27), C["timber"], segs=14, rot=(1.3, 0, 0.4))
    else:
        # A canvas ore sack slumped against the heap and a shovel flat on the ground.
        p.ico(0.42, (-0.95, 0.2, 0.25), C["canvas_dark"], scale=(1.0, 0.9, 0.7), rot=(0, 0.3, 0), style="round")
        p.torus(0.12, 0.03, (-0.95, 0.2, 0.52), ROPE, major=10, minor=4, style="flat")
        p.rod((0.6, -0.7, 0.04), (1.6, -0.9, 0.04), 0.03, C["timber"])
        p.box((0.32, 0.28, 0.04), (0.45, -0.67, 0.03), C["iron"], rot=(0, 0, -0.2), style="hard_smooth")


@K.kind("sleeper_stack", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Tram sleepers stacked for track that never got laid, and one rail stub, bent.")
def sleeper_stack(p, v, rng):
    if v == "a":
        for layer in range(4):
            cross = layer % 2
            for k in range(3):
                off = -0.5 + 0.5 * k
                loc = (off, 0, 0.1 + 0.2 * layer) if cross else (0, off, 0.1 + 0.2 * layer)
                p.box((0.26, 1.6, 0.18) if cross else (1.6, 0.26, 0.18), loc, tint(C["timber_grey"], rng, 0.07),
                      rot=(0, 0, rng.uniform(-0.04, 0.04)), style="hard_smooth", jit=0.006)
        p.box((1.5, 0.09, 0.12), (0.2, 1.05, 0.06), C["iron"], rot=(0, 0, 0.12), style="hard_smooth")
        p.box((0.7, 0.09, 0.12), (1.05, 1.25, 0.12), C["iron"], rot=(0, -0.2, 0.5), style="hard_smooth")
    else:
        for k in range(6):
            p.box((1.6, 0.26, 0.18), (rng.uniform(-0.8, 0.8), rng.uniform(-0.9, 0.9), 0.09 + (0.18 if k == 5 else 0)),
                  tint(C["timber_grey"], rng, 0.07), rot=(0, 0, rng.uniform(-1.2, 1.2)), style="hard_smooth", jit=0.006)
        p.ico(0.25, (0.6, 0.6, 0.1), C["dry_grass"], scale=(1.2, 1, 0.6), style="round")


@K.kind("drying_tripod", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Three poles lashed at the top with a net drying on them. The weavers say the net is surveying the wind.")
def drying_tripod(p, v, rng):
    top = (0.0, 0.0, 2.5)
    feet = [(0.9 * math.cos(a), 0.9 * math.sin(a), 0.0) for a in (0.3, 0.3 + math.tau / 3, 0.3 + 2 * math.tau / 3)]
    for f in feet:
        p.rod(f, (top[0] - f[0] * 0.1, top[1] - f[1] * 0.1, top[2] + 0.2), 0.05, tint(C["timber_grey"], rng), segs=6)
    p.torus(0.1, 0.04, (0, 0, top[2] - 0.05), ROPE, major=10, minor=5, style="flat")
    # Net draped over two faces of the tripod: rings at falling heights and drop lines.
    arc = (0.3, 0.3 + math.tau * (0.65 if v == "a" else 0.9))
    for k in range(5):
        z = 2.2 - 0.42 * k
        r = 0.9 * (1 - z / 2.6) + 0.06
        segs = 12
        pts = [(r * math.cos(arc[0] + (arc[1] - arc[0]) * i / segs), r * math.sin(arc[0] + (arc[1] - arc[0]) * i / segs),
                z - 0.08 * math.sin(math.pi * i / segs)) for i in range(segs + 1)]
        rope_line(p, pts, NET, 0.02)
    for i in range(9):
        a = arc[0] + (arc[1] - arc[0]) * i / 8
        rope_line(p, [(0.08 * math.cos(a), 0.08 * math.sin(a), 2.35), (0.95 * math.cos(a), 0.95 * math.sin(a), 0.05)], NET, 0.02)
    # The net's tail piled at the foot.
    p.ico(0.45, (0.8, -0.6, 0.12), NET, scale=(1.3, 1.0, 0.35), rot=(0, 0, 0.5), style="round")
    if v == "b":
        p.ico(0.3, (-0.9, 0.2, 0.1), mix(NET, C["canvas_dark"], 0.5), scale=(1.2, 0.9, 0.35), style="round")
        for k in range(4):
            p.cyl(0.11, 0.2, (1.1 + 0.2 * k, -0.2 + 0.15 * k, 0.11), CORK, segs=10, rot=(math.pi / 2, 0, k), style="round")


@K.kind("juniper_snag", tags=["plant"], variants="ab", polish_opts={"detail": 1},
        story="A wind-bent juniper growing through what was left lying: a tram wheel in one, a snapped kite spar in the other.")
def juniper_snag(p, v, rng):
    lean = 0.5 if v == "b" else 0.25
    pts = [(0, 0, 0)]
    for k in range(1, 5):
        z = 0.45 * k
        pts.append((z * math.sin(lean) * 0.8 + rng.uniform(-0.05, 0.05), rng.uniform(-0.08, 0.08), z * math.cos(lean * 0.6)))
    for k, (a, b) in enumerate(zip(pts, pts[1:])):
        p.rod(a, b, 0.11 - 0.02 * k, tint(C["timber_grey"] if k % 2 else C["timber_dark"], rng), segs=7, r2=0.1 - 0.02 * k)
    # A side branch, then the foliage pads all downwind.
    p.rod(pts[2], (pts[2][0] - 0.45, pts[2][1] + 0.3, pts[2][2] + 0.3), 0.06, C["timber_dark"], segs=6)
    pads = [pts[4], pts[3], (pts[2][0] - 0.45, pts[2][1] + 0.3, pts[2][2] + 0.3), (pts[4][0] + 0.3, 0.1, pts[4][2] - 0.2)]
    for k, c in enumerate(pads):
        p.ico(0.42 - 0.04 * k, (c[0] + 0.25, c[1], c[2] + 0.05), tint(C["leaf_dark"] if k % 2 else C["leaf"], rng, 0.06),
              scale=(1.35, 1.0, 0.62), rot=(0, 0.2, rng.uniform(0, 3)), style="round")
    if v == "a":
        p.cyl(0.38, 0.12, (0, 0, 0.06), C["iron"], segs=14, style="hard_smooth")
        p.cyl(0.13, 0.2, (0, 0, 0.1), C["charcoal"], segs=10, style="round")
        p.torus(0.42, 0.05, (0, 0, 0.1), C["rust"], major=14, minor=5)
    else:
        p.cyl(0.05, 1.3, (-0.6, 0.2, 0.05), C["timber_pale"], segs=8, rot=(0, math.pi / 2, 0.4), style="round")
        p.cyl(0.05, 0.8, (0.5, -0.5, 0.05), C["timber_pale"], segs=8, rot=(0, math.pi / 2, -0.9), style="round")
        stones(p, rng, (0.1, 0.1), 3, 0.2, C["sandstone"], spread=0.45)


@K.kind("grass_tuft", tags=["plant"], variants="abc", polish_opts={"detail": 1},
        story="Dry bunchgrass, combed flat one way by the wind, round a couple of stones.")
def grass_tuft(p, v, rng):
    n = {"a": 14, "b": 10, "c": 18}[v]
    cx = [(0, 0)] if v != "c" else [(-0.35, 0), (0.4, 0.15)]
    for (ox, oy) in cx:
        for k in range(n // len(cx)):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0, 0.18)
            base = (ox + r * math.cos(a), oy + r * math.sin(a), 0.0)
            h = rng.uniform(0.35, 0.6)
            tip = (base[0] + h * 0.45 + rng.uniform(-0.05, 0.08), base[1] + rng.uniform(-0.15, 0.15), h)
            col = tint(C["dry_grass"] if k % 3 else mix(C["dry_grass"], C["leaf"], 0.35), rng, 0.06)
            p.rod(base, tip, 0.035, col, segs=4, r2=0.006)
    stones(p, rng, (0.2, -0.25), 2 if v != "b" else 1, 0.14, C["sandstone"], spread=0.2)


@K.kind("knot_board", tags=["sign"], variants="ab", polish_opts={"detail": 1},
        story="A weavers' tally board: a knot for every crossing tied along a cord. Older knots under it.")
def knot_board(p, v, rng):
    standing = v == "a"
    if standing:
        p.cyl(0.06, 1.05, (0, 0, 0.52), C["timber_dark"], segs=8, rot=(0.06, 0.04, 0), style="round")
        p.box((0.75, 0.06, 0.38), (0, -0.07, 0.82), C["timber_grey"], rot=(0, 0.05, 0), style="hard_smooth")
        p.box((0.8, 0.07, 0.06), (0, -0.07, 1.0), C["timber_dark"], style="hard_smooth")
        rope_line(p, [(-0.36, -0.12, 0.88), (0.0, -0.12, 0.84), (0.36, -0.12, 0.88)], ROPE, 0.015)
        rope_line(p, [(-0.36, -0.12, 0.72), (0.0, -0.12, 0.69), (0.36, -0.12, 0.72)], ROPE_DARK, 0.015)
        for k in range(6):
            p.uv(0.03, (-0.3 + 0.1 * k, -0.13, 0.86 - (0.01 if k in (2, 3, 4) else 0)), ROPE, u=6, v=4)
        for k in range(4):
            p.uv(0.03, (-0.28 + 0.14 * k, -0.13, 0.7), ROPE_DARK, u=6, v=4)
        stones(p, rng, (0.0, 0.0), 2, 0.13, C["sandstone"], spread=0.22)
    else:
        p.cyl(0.06, 0.35, (0, 0, 0.17), C["timber_dark"], segs=8, style="round")
        p.box((0.75, 0.38, 0.06), (0.55, -0.25, 0.04), C["timber_grey"], rot=(0, 0, 0.4), style="hard_smooth")
        rope_line(p, [(0.25, -0.5, 0.09), (0.6, -0.36, 0.09), (0.9, -0.15, 0.09), (1.25, 0.1, 0.03)], ROPE, 0.015)
        for k in range(5):
            p.uv(0.035, (0.32 + 0.13 * k, -0.47 + 0.06 * k, 0.1), ROPE, u=6, v=4)
        p.cyl(0.05, 0.75, (-0.4, 0.3, 0.05), C["timber_dark"], segs=8, rot=(0, math.pi / 2, 1.2), style="round")


if __name__ == "__main__":
    K.main()
