"""Flume park dressing kit (park_flume, world 1, morning).

The flume crews lived on the mesa face beside the trestles: bunk ledges, cooked fish drying
on racks, bents numbered downhill, a crane boom locked for the night and found swung by
morning. The big timber (reaches, bents, crib piers, bunk ledges, annex) is already
authored; this kit is the human-scale story around it.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/flume.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, tint

_ico = kit.Prop.ico


def _ico_rooted(self, radius, loc, color, scale=(1, 1, 1), **kw):
    """Tall blobs (grass, reeds, cattails) are authored by their root height: lift the centre so
    the blob stands on `loc` z instead of sinking through the floor (which would raise the
    whole prop when the kit drops the lowest point to z = 0)."""
    if scale[2] >= 1.4:
        loc = (loc[0], loc[1], loc[2] + radius * scale[2] * 0.85 - radius * 0.2)
    if loc[2] - radius * scale[2] < 0.04:  # never sink a blob through the floor
        loc = (loc[0], loc[1], radius * scale[2] + 0.04)
    return _ico(self, radius, loc, color, scale=scale, **kw)


kit.Prop.ico = _ico_rooted

K = kit.Kit("flume", polish_opts={"detail": 1})
WHITE = "e6e3d6"  # chalk white: dial face (not emissive, not a palette hazard colour)
PETROL = "365754"  # petrol enamel: waterworks machine bodies (Spillway props board; kit.py owns the palette, so raw hex here)
OXIDE = "9b513a"  # iron oxide: a painted wheel (Spillway props board, Sluice Wheelhouse)
BONE = "d2c5a5"  # bone: label plates
COPPER = "b77843"  # copper fittings, small accents only (WARN colour: never dominant)
FACE = (math.pi / 2, 0, 0)  # rotates a Z-axis cylinder to face -Y
SIDE = (0, math.pi / 2, 0)  # rotates a Z-axis cylinder to lie along X


def plank_wall_x(p, rng, x0, x1, y, z0, z1, n, col, th=0.12, skip=(), gap=0.0):
    """Vertical planks across x0..x1 at depth y."""
    w = (x1 - x0) / n
    for i in range(n):
        if i in skip:
            continue
        p.box((w - 0.01, th, z1 - z0 - gap * (i % 3)), (x0 + (i + 0.5) * w, y, (z0 + z1) / 2 - gap * (i % 3) / 2),
              tint(col, rng), jit=0.004)


def plank_wall_y(p, rng, y0, y1, x, z0, z1, n, col, th=0.12, skip=()):
    w = (y1 - y0) / n
    for i in range(n):
        if i in skip:
            continue
        p.box((th, w - 0.01, z1 - z0), (x, y0 + (i + 0.5) * w, (z0 + z1) / 2), tint(col, rng), jit=0.004)


def sleeper_stack(p, rng, x, y, layers, long=1.7, col=None):
    """Timber cribbing: crossed sleepers (low, wide, never a crate)."""
    for k in range(layers):
        rot = (0, 0, math.pi / 2 if k % 2 else 0)
        p.box((long, 0.42, 0.34), (x, y, 0.17 + 0.34 * k), tint(col or C["timber_grey"], rng), rot=rot, jit=0.006)


def rope_coil(p, loc, r, col, turns=3, tube=0.045):
    for k in range(turns):
        p.torus(r - k * tube * 1.6, tube, (loc[0], loc[1], loc[2] + k * tube * 1.2), col, major=14, minor=5)


# --------------------------------------------------------------------------------------
@K.kind("boom_crane_wreck", hero=True, tags=["machine"], variants="abc",
        polish_opts={"bevel_min": 0.14}, story="Boom 3, locked for the night and found swung toward the tower; the lock and chain are still on.")
def boom_crane_wreck(p, v, rng):
    # Winch cab on a sleeper plinth, at the foot (x < 0).
    p.box((3.6, 3.0, 0.4), (-4.2, 0, 0.2), C["concrete"], style="hard_smooth")
    plank_wall_x(p, rng, -5.9, -2.5, -1.4, 0.4, 2.5, 14, PETROL)
    plank_wall_x(p, rng, -5.9, -2.5, 1.4, 0.4, 2.5, 14, PETROL, skip=(5, 6) if v != "a" else ())
    plank_wall_y(p, rng, -1.4, 1.4, -5.9, 0.4, 2.5, 12, PETROL)
    plank_wall_y(p, rng, -1.4, 1.4, -2.5, 0.4, 2.5, 12, PETROL, skip=(4, 5, 6, 7))  # open front for the drum
    for s in (-1, 1):
        for r in range(6):
            if v == "c" and s == 1 and r > 2:
                continue  # roof fallen in on one side
            p.box((4.2, 0.62, 0.08), (-4.2, s * (1.55 - r * 0.25), 2.55 + r * 0.17),
                  tint(C["timber_grey"] if (r % 2) else C["timber_dark"], rng, 0.08), rot=(-s * 0.12, 0, 0), jit=0.004)
    p.beam((-6.0, 0, 3.2), (-2.4, 0, 3.2), 0.2, C["timber_dark"])
    # Winch drum with a wound chain, crank wheel.
    p.cyl(0.55, 2.0, (-3.4, 0, 1.0), PETROL, segs=12, rot=FACE, style="hard_smooth")
    for k in range(7):
        p.torus(0.58, 0.07, (-3.4, -0.85 + k * 0.28, 1.0), C["cable"], rot=FACE, major=14, minor=5)
    p.torus(0.6, 0.07, (-3.4, 1.15, 1.0), COPPER, rot=FACE, major=14, minor=5)
    for k in range(4):
        a = math.tau * k / 4
        p.rod((-3.4, 1.15, 1.0), (-3.4 + 0.6 * math.cos(a), 1.15, 1.0 + 0.6 * math.sin(a)), 0.05, C["iron"])
    # Cribbing the broken boom rests on (positions follow the segments below).
    xs = (-1.0,)
    stacks = {"a": ((-1.0, 0, 4), (2.9, 0.9, 3), (5.5, 2.5, 2)), "b": ((-1.0, 0, 4), (2.9, 0.9, 3), (5.4, -2.2, 2)),
              "c": ((-1.0, 0, 4), (3.2, -1.4, 1), (5.6, 1.4, 2))}[v]
    for x, y, n in stacks:
        sleeper_stack(p, rng, x, y, n, col=C["timber_grey"] if v != "a" else C["timber"])
    # A-frame stub behind the foot (stout, apex capped; not a gate).
    for s in (-1, 1):
        p.beam((-1.9, s * 1.4, 0.2), (-2.5, s * 0.25, 4.1), 0.34, C["timber_dark"])
    p.box((0.5, 1.2, 0.34), (-2.5, 0, 4.15), BONE, style="hard_smooth")  # bone cap plate
    p.cyl(0.4, 0.3, (-2.5, 0, 3.75), C["iron"], segs=12, rot=FACE, style="hard_smooth")
    p.beam((-2.0, -1.3, 1.2), (-2.5, 0, 3.0), 0.12, C["timber_dark"])
    # The boom, jack-knifed into chunky lattice segments (steep or short, never a long shallow run).
    def lattice(a, b, w, n=4):
        d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        ln = math.sqrt(sum(c * c for c in d))
        d = tuple(c / ln for c in d)
        side = (d[1] * 1.0, -d[0] * 1.0, 0.0)
        sl = math.hypot(side[0], side[1]) or 1.0
        side = (side[0] / sl, side[1] / sl, 0.0)
        up = (d[1] * side[2] - d[2] * side[1], d[2] * side[0] - d[0] * side[2], d[0] * side[1] - d[1] * side[0])
        def at(t, sg, ug, ww):
            return tuple(a[k] + (b[k] - a[k]) * t + side[k] * sg * ww + up[k] * ug * ww for k in range(3))
        for sg in (-1, 1):
            for ug in (-1, 1):
                p.beam(at(0, sg, ug, w), at(1, sg, ug, w * 0.75), 0.3, tint(C["timber"] if ug > 0 else C["timber_dark"], rng, 0.05))
        for k in range(n):
            t0, t1 = k / n, (k + 1) / n
            sgn = 1 if k % 2 else -1
            for sg in (-1, 1):
                p.beam(at(t0, sg, -sgn, w * (1 - 0.25 * t0)), at(t1, sg, sgn, w * (1 - 0.25 * t1)), 0.12, C["timber_grey"])
            p.beam(at(t0, -1, 0, w), at(t0, 1, 0, w), 0.14, C["timber_dark"], h=0.14)
        p.box((0.5, 0.5, 0.5), at(0, 0, 0, 0), C["iron"], style="hard_smooth")  # joint plate
    P1 = (-2.0, 0, 2.0)
    P2 = (0.8, 0, 4.3)
    if v in ("a", "b"):
        P3 = (2.9, 0.9, 1.0)
        P4 = (5.6, 2.6, 0.9) if v == "a" else (5.4, -2.2, 0.9)
        lattice(P1, P2, 0.6)
        lattice(P2, P3, 0.6)
        lattice((P3[0], P3[1], P3[2] - 0.1), P4, 0.5, n=3)
        hx, hy = (6.2, 3.1) if v == "a" else (6.0, -2.7)
    else:
        lattice(P1, P2, 0.6)
        p.beam(P2, (1.7, 0.2, 3.3), 0.3, C["timber_pale"])  # splintered stub where the second section snapped
        lattice((2.4, -1.5, 0.7), (5.6, -0.3, 1.0), 0.55, n=3)
        lattice((4.2, -2.0, 0.8), (5.5, 1.3, 2.3), 0.5, n=2)
        for i in range(4):
            p.ico(0.3, (3.6 + i * 0.8, -1.2 + 0.5 * (i % 2), 0.45), C["leaf"] if i % 2 else C["leaf_dark"], scale=(0.6, 0.6, 1.9), style="round", subdiv=0)
        hx, hy = 6.6, 0.9
    # Lock block and chain on the first cribbing stack.
    lx = xs[0]
    p.box((0.4, 0.28, 0.5), (lx, -0.62, 1.55 + (0.2 if v == "a" else -0.2)), C["iron"], style="hard_smooth")
    p.torus(0.17, 0.06, (lx, -0.62, 1.85 + (0.2 if v == "a" else -0.2)), C["iron_light"], rot=FACE, major=10, minor=5)
    sag = 0.2 if v == "a" else 0.7
    p.chain((lx, -0.62, 1.6), (lx - 0.3, -0.5, 1.0), C["cable"], link=0.2, radius=0.04, sag=sag)
    p.chain((lx, -0.62, 1.6), (lx + 0.5, 0.6, 1.7), C["cable"], link=0.2, radius=0.04, sag=sag)
    # Hook block on the ground by the boom's end, chain slack in a heap.
    p.box((0.6, 0.5, 0.8), (hx, hy, 0.4), PETROL, style="hard_smooth")
    p.cyl(0.32, 0.2, (hx, hy - 0.3, 0.45), C["iron_light"], segs=12, rot=FACE, style="hard_smooth")
    p.torus(0.22, 0.07, (hx, hy, 0.95), C["iron"], rot=FACE, major=10, minor=5)
    p.chain((hx, hy, 0.9), (hx + 1.2, hy + (-1.3 if hy > 0 else 1.3), 0.1), C["cable"], link=0.2, radius=0.04, sag=0.3)
    # Crew warmth: a night lantern (unlit, plain glass-white) and a jacket slung on the cab.
    p.cyl(0.15, 0.3, (-6.3, 0.6, 1.0), C["iron"], segs=8, style="hard_smooth")
    p.cyl(0.11, 0.2, (-6.3, 0.6, 1.25), WHITE, segs=8, style="hard_smooth")
    p.ico(0.45, (-6.15, -0.6, 1.4), C["canvas_dark"], scale=(0.4, 1.1, 1.3), style="round", subdiv=0)
    if v == "b":
        p.ico(0.8, (5.2, -2.2, 1.4), C["canvas_dark"], scale=(1.8, 1.0, 0.3), rot=(0.1, 0, 0.1), style="round", subdiv=0)  # tarp over the boom
    if v == "c":
        for i in range(4):
            p.ico(0.35, (-5.0 + i * 1.1, -1.8 + rng.uniform(-0.2, 0.2), 0.4), C["leaf_dark"], scale=(0.6, 0.6, 1.8), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
def hull(p, rng, v, sink=0.0, length=7.6, beam_w=2.4):
    """Clinker rowboat hull from strakes of planks, bow at +x. Returns nothing."""
    segs = 12
    rows = 5
    for side in (-1, 1):
        for r in range(rows):
            t = r / (rows - 1)
            for i in range(segs):
                u0, u1 = i / segs, (i + 1) / segs
                if v == "b" and side == 1 and r in (1, 2) and i in (5, 6, 7):
                    continue  # the hole
                def pt(u):
                    x = (u - 0.5) * length
                    prof = math.sqrt(max(0.0, 1 - (2 * u - 1) ** 2)) ** 0.7  # pointed ends
                    half = beam_w / 2 * prof * (0.35 + 0.65 * t ** 0.8)
                    z = 0.45 + 0.9 * t + 0.35 * (abs(2 * u - 1) ** 2) * (0.5 + 0.5 * t)
                    return (x, side * half, z)
                a, b = pt(u0), pt(u1)
                p.beam(a, b, 0.22, tint(C["timber_pale"] if r % 2 else C["timber"], rng, 0.07), h=0.1)
    # Keel, thwarts, stem and stern posts.
    p.beam((-length / 2 * 0.95, 0, 0.35), (length / 2 * 0.95, 0, 0.35), 0.24, C["timber_dark"])
    for k in range(3):
        x = -1.6 + k * 1.6
        half = beam_w / 2 * 0.95 * (1 - (x / (length / 2)) ** 2) ** 0.35
        p.box((0.45, half * 2, 0.1), (x, 0, 1.2), tint(C["timber_pale"], rng), jit=0.004)
    for s in (-1, 1):
        p.beam((s * length / 2 * 0.97, 0, 0.7), (s * length / 2 * 1.02, 0, 1.75), 0.2, C["timber_dark"])


@K.kind("skiff_on_blocks", hero=True, tags=["soft"], variants="abc",
        story="A rowboat left on trestle blocks when the canal dropped, nets drying beside it.")
def skiff_on_blocks(p, v, rng):
    # Hull lifted on blocks: an offset wrapper raises the hull's beams and boxes over the sleepers.
    for x in (-2.2, 2.2):
        sleeper_stack(p, rng, x, 0, 3, long=3.3, col=C["timber_grey"])
    # draw the hull above the blocks: wrap in a temporary offset by building at z then lifting
    # Build the hull by monkey-shifting beam/box with an offset wrapper.
    class Off:
        def __init__(self, base, dz):
            self.base, self.dz = base, dz
        def beam(self, a, b, *r, **k):
            return self.base.beam((a[0], a[1], a[2] + self.dz), (b[0], b[1], b[2] + self.dz), *r, **k)
        def box(self, size, loc, *r, **k):
            return self.base.box(size, (loc[0], loc[1], loc[2] + self.dz), *r, **k)
    q = Off(p, 0.95)
    hull(q, rng, v)
    # Tarp over the stern (a), or a gaping hole and grass (b, c).
    if v == "a":
        p.ico(1.3, (1.2, 0, 2.2), C["canvas_dark"], scale=(1.5, 0.8, 0.35), style="round", subdiv=0)
        p.ico(0.7, (-0.4, -0.9, 2.3), C["canvas_dark"], scale=(1.4, 0.5, 0.5), rot=(0, 0, 0.2), style="round", subdiv=0)
    elif v == "b":
        p.ico(0.55, (0.8, 1.3, 1.9), C["canvas_dark"], scale=(1.2, 0.5, 0.9), style="round", subdiv=0)  # rag stuffed in the hole
    else:
        for i in range(10):
            a = rng.uniform(0, math.tau)
            p.ico(0.4, (rng.uniform(-2.5, 2.5), rng.uniform(-0.45, 0.45), 1.8 + rng.uniform(0, 0.35)),
                  C["leaf"] if i % 2 else C["dry_grass"], scale=(0.5, 0.5, 2.0), style="round", subdiv=0)
        p.ico(0.9, (0.0, 0.0, 1.6), C["soil"], scale=(2.4, 0.8, 0.25), style="round", subdiv=0)
    # Oars lying flat across the thwarts, not leaning.
    p.rod((-3.0, -1.5, 0.12), (1.0, -1.7, 0.12), 0.07, C["timber_pale"])
    p.box((1.2, 0.34, 0.07), (1.5, -1.75, 0.1), C["timber_pale"], rot=(0, 0, 0.1))
    # Net and floats heaped beside the hull.
    p.ico(0.9, (-0.6, -2.2, 0.38), C["canvas_stain"], scale=(1.9, 0.9, 0.45), style="round", subdiv=0)
    for i in range(5):
        p.uv(0.14, (-1.6 + i * 0.5, -2.65 + 0.1 * (i % 2), 0.2), C["timber_pale"], style="round")
    # A bailer pail and a hemp rope coil.
    p.cyl(0.24, 0.4, (3.7, -1.3, 0.2), C["iron_light"], segs=10, r2=0.28, style="hard_smooth")
    p.torus(0.2, 0.025, (3.7, -1.3, 0.42), C["cable"], major=10, minor=4)
    rope_coil(p, (3.3, 1.5, 0.05), 0.55, C["timber_pale"], turns=3)
    # Fish rack: a fat low frame with split grey fish, hung beside (a: full, b: half, c: bare).
    # Leaning A-frame with a short cross-arm (not two posts and a lintel): fish hang from the arm.
    p.beam((-1.0, 3.2, 0.0), (0.0, 2.9, 3.0), 0.3, C["timber_dark"])
    p.beam((1.0, 3.2, 0.0), (0.0, 2.9, 3.0), 0.3, C["timber_dark"])
    p.beam((0.0, 3.9, 0.0), (0.0, 2.9, 3.0), 0.26, C["timber_dark"])  # back leg
    p.beam((-1.6, 2.9, 2.5), (1.5, 2.9, 2.7), 0.2, C["timber_pale"])  # cross-arm, off-level
    n = {"a": 7, "b": 3, "c": 0}[v]
    for i in range(n):
        x = -1.4 + i * 0.45
        p.ico(0.3, (x, 2.9, 1.9), C["timber_grey"] if i % 2 else C["bone"], scale=(0.4, 0.25, 1.4), style="round", subdiv=0)
    if v != "a":
        p.ico(0.5, (0.0, 3.0, 0.3), C["leaf_dark"], scale=(1.8, 0.8, 0.5), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
@K.kind("sluice_shed", hero=True, tags=["machine"], variants="abc",
        story="A gabled shed over the sluice wheel, a warm flask still hung on the post.")
def sluice_shed(p, v, rng):
    # Stone footing and floor.
    p.box((5.6, 4.4, 0.5), (0, 0, 0.25), C["concrete_dark"], style="hard_smooth")
    for x, y in ((-2.7, -2.1), (2.7, 2.1), (2.6, -2.15), (-2.6, 2.2)):
        p.box((0.6, 0.6, 0.3), (x, y, 0.55), mix(C["concrete"], C["concrete_stain"], 0.4), rot=(0, 0, rng.uniform(0, 1.5)))
    # Corner posts and plank walls.
    for x in (-2.4, 2.4):
        for y in (-1.9, 1.9):
            if v == "c" and x > 0 and y < 0:
                p.beam((x, y, 0.5), (x + 0.6, y - 0.4, 1.8), 0.26, C["timber_dark"])  # post kicked out
                continue
            p.beam((x, y, 0.5), (x, y, 3.3), 0.26, C["timber_dark"])
    plank_wall_x(p, rng, -2.3, 2.3, 1.9, 0.5, 3.1, 20, PETROL, skip=(3, 4, 5) if v != "a" else ())
    plank_wall_y(p, rng, -1.8, 1.8, -2.4, 0.5, 3.1, 16, PETROL)
    plank_wall_x(p, rng, -2.3, 2.3, -1.9, 0.5, 3.1, 20, PETROL, skip=(11, 12, 13, 14, 15) if v != "c" else tuple(range(8, 20)))
    if v != "c":
        plank_wall_y(p, rng, -1.8, 1.8, 2.4, 0.5, 3.1, 16, PETROL, skip=(6, 7, 8) if v == "b" else ())
    # Door frame on the front, open.
    p.box((1.3, 0.2, 0.12), (0.0, -2.0, 2.15), BONE)  # bone name plate over the door
    # Gabled roof: planks up both slopes. c: one side gone.
    rise, half = 1.5, 2.3
    th = math.atan2(rise, half)
    rows = 8
    for s in (-1, 1):
        for r in range(rows):
            if v == "c" and s == 1 and r >= 2:
                continue
            if v == "b" and s == -1 and r in (3, 4):
                continue
            t = (r + 0.5) / rows
            p.box((5.6, half / rows * 1.5, 0.1), (0, s * half * (1 - t), 3.3 + rise * t),
                  tint(PETROL if (r % 2) else mix(PETROL, C["charcoal"], 0.35), rng, 0.08), rot=(-s * th, 0, 0), jit=0.004)
    p.beam((-2.9, 0, 3.3 + rise), (2.9, 0, 3.3 + rise), 0.26, C["timber_dark"])
    for x in (-2.4, 0, 2.4):
        for s in (-1, 1):
            p.beam((x, s * half, 3.3), (x, 0, 3.3 + rise - 0.05), 0.14, C["timber_dark"])
    # The sluice wheel: a fat paddle wheel mounted on the east gable end, axle through the wall.
    wx, wr = 3.2, 2.5
    wz = 2.6
    side = (0, math.pi / 2, 0)
    p.cyl(0.22, 2.0, (2.9, 0, wz), PETROL, segs=10, rot=side)
    for sy in (-1.05, 1.05):
        p.torus(wr, 0.12, (wx + 0.3, sy, wz), C["timber_dark"] if v != "a" else C["iron_light"], rot=side, major=20, minor=5)
    p.cyl(0.45, 2.3, (wx + 0.3, 0, wz), PETROL, segs=12, rot=side, style="hard_smooth")
    spokes = 10
    for k in range(spokes):
        a = math.tau * k / spokes + 0.15
        broken = v != "a" and k in (2, 3, 7)
        r_end = wr * (0.55 if broken else 1.0)
        for sy in (-1.05, 1.05):
            p.beam((wx + 0.3 + 0.0, sy, wz), (wx + 0.3 + r_end * math.sin(a), sy, wz + r_end * math.cos(a)), 0.2, OXIDE, h=0.16)
        if not broken:
            p.box((0.14, 2.3, 0.7), (wx + 0.3 + wr * math.sin(a), 0, wz + wr * math.cos(a)), tint(C["timber"], rng),
                  rot=(0, a, 0), jit=0.004)
    # Wheel pit and trough: low timber basin under the wheel (box), water not modelled.
    p.box((3.0, 2.6, 0.5), (wx + 0.3, 0, 0.25), C["concrete_dark"], style="hard_smooth")
    if v == "c":
        for i in range(9):
            p.ico(0.4, (wx + rng.uniform(-1, 1.2), rng.uniform(-1, 1), 0.7 + rng.uniform(0, 0.4)), C["leaf"] if i % 2 else C["leaf_dark"],
                  scale=(0.6, 0.6, 1.9), style="round", subdiv=0)
    # Flask on its own post at the front-left corner (warm, hung by a strap).
    p.beam((-3.4, -2.6, 0.0), (-3.4, -2.6, 1.7), 0.2, C["timber_dark"])
    p.beam((-3.4, -2.6, 1.55), (-3.0, -2.6, 1.55), 0.12, C["timber_dark"])
    p.uv(0.22, (-3.0, -2.62, 1.2), C["verdigris"], scale=(0.7, 0.45, 1.0), style="round")
    p.cyl(0.07, 0.14, (-3.0, -2.62, 1.48), C["iron"], segs=6)
    p.rod((-3.0, -2.62, 1.55), (-3.0, -2.62, 1.42), 0.025, C["cable"], segs=4)
    # Floor barrel-free kit: pail and a coil of rope by the door.
    p.cyl(0.3, 0.5, (-1.0, -3.0, 0.25), C["iron_light"], segs=10, r2=0.34, style="hard_smooth")
    rope_coil(p, (1.1, -3.1, 0.05), 0.5, C["timber_pale"], turns=2)


# --------------------------------------------------------------------------------------
@K.kind("bunk_cots", tags=["soft"], variants="abc",
        story="A canvas cot under a lean-to, boots tucked beneath.")
def bunk_cots(p, v, rng):
    # A pitched, sagging canvas over a ridge pole (no flat top): dusty canvas draped both sides.
    dusty = mix(C["canvas_dark"], C["timber_grey"], 0.25)
    if v != "c":
        for x in (-1.4, 1.4):
            p.beam((x, 0, 0.0), (x, 0, 1.55), 0.16, C["timber_dark"])
        p.beam((-1.6, 0, 1.55), (1.6, 0, 1.55), 0.12, C["timber_dark"])
        for sd in (-1, 1):
            y, z = 0.0, 1.55
            angs = (0.75, 1.0, 1.3) if not (v == "b" and sd == 1) else (0.9, 1.3, 1.5)
            if v == "b" and sd == 1:
                angs = (0.9, 1.3, 1.5, 1.5)  # this side has slumped nearly to the ground
            for k, a in enumerate(angs):
                ln = 0.5
                ny, nz = y + sd * ln * math.cos(a), z - ln * math.sin(a)
                if v == "b" and sd == -1 and k == 2:
                    break  # torn off the low edge
                p.box((2.9 - 0.12 * k, ln + 0.04, 0.05), (0, (y + ny) / 2, (z + nz) / 2), tint(dusty, rng, 0.06),
                      rot=(sd * a, 0, 0), style="fine")
                y, z = ny, nz
        # Stain patch and a sagging belly fold of loose canvas at the front.
        p.ico(0.4, (0.9, -0.55, 0.7), mix(dusty, C["canvas_stain"], 0.5), scale=(1.2, 0.5, 0.5), style="round", subdiv=0)
    else:
        for x in (-1.4, 1.4):
            p.beam((x, 0, 0.0), (x + 0.5, 0.2, 1.0), 0.16, C["timber_dark"])
        p.ico(0.9, (0.2, 0.0, 0.5), mix(dusty, C["canvas_stain"], 0.4), scale=(1.7, 1.1, 0.3), rot=(0.1, 0.2, 0.1), style="round", subdiv=0)
    # Cot: frame, legs, sagging canvas, bedroll.
    sag = 0.12 if v == "a" else 0.25
    for s in (-1, 1):
        p.beam((-0.95, s * 0.35, 0.3), (0.95, s * 0.35, 0.3), 0.07, C["timber_dark"])
        for x in (-0.9, 0.9):
            p.beam((x, s * 0.35, 0.0), (x, s * 0.35, 0.3), 0.07, C["timber_dark"])
    p.box((1.8, 0.7, 0.05), (0, 0, 0.3 - sag * 0.4), C["canvas"] if v == "a" else C["canvas_dark"], style="soft", rot=(0, 0.0, 0.0))
    p.ico(0.35, (-0.5, 0, 0.5), C["canvas_stain"], scale=(0.9, 0.9, 0.5), style="round", subdiv=0)  # pillow roll
    if v == "a":
        p.ico(0.4, (0.35, 0.0, 0.42), mix(C["canvas"], C["timber_grey"], 0.3), scale=(1.4, 0.8, 0.4), style="round", subdiv=0)  # blanket
    # Boots and a mug.
    p.ico(0.16, (-0.4, -0.7, 0.14), C["timber_dark"], scale=(1.3, 0.7, 0.9), style="round", subdiv=0)
    p.ico(0.16, (-0.1, -0.78, 0.14), C["timber_dark"], scale=(1.3, 0.7, 0.9), rot=(0, 0, 0.3), style="round", subdiv=0)
    p.cyl(0.1, 0.16, (0.9, -0.7, 0.08), C["iron_light"], segs=8, style="hard_smooth")
    if v == "c":
        for i in range(5):
            p.ico(0.25, (-0.8 + i * 0.4, 0.1 * (i % 2), 0.3), C["leaf"] if i % 2 else C["dry_grass"], scale=(0.5, 0.5, 1.6), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
@K.kind("milepost", tags=["sign"], variants="abc",
        story="A low post with painted depths; one number crossed out and painted deeper.")
def milepost(p, v, rng):
    lean = {"a": 0.0, "b": 0.12, "c": 0.5}[v]
    p.cyl(0.45, 0.25, (0, 0, 0.12), C["concrete_dark"], segs=10, r2=0.4, style="hard_smooth")
    ph = 1.5 if v != "c" else 1.15
    top = (math.sin(lean) * ph, 0, ph * math.cos(lean))
    p.beam((0, 0, 0.2), top, 0.46, C["timber_grey"] if v != "a" else C["timber"], h=0.34)
    p.cyl(0.26, 0.18, (top[0], top[1], top[2] + 0.07), C["timber_dark"], segs=8, style="hard_smooth")
    # Painted depth marks: two or three short, uneven daubs (offset left and right, tilted) with tick strokes;
    # the middle one is struck through. Nothing spans the post, so it never reads as rungs.
    face = -0.19
    marks = ((0.5, -0.1, 0.28, 0.08), (0.95, 0.09, 0.22, -0.1), (1.28, -0.05, 0.18, 0.05))
    for i, (z, dx, wd, tilt) in enumerate(marks):
        if (v == "c" and i == 2) or (v == "b" and i == 0):
            continue
        zz, xx = z * math.cos(lean), math.sin(lean) * z + dx
        p.box((wd, 0.04, 0.1), (xx, face, zz), WHITE, rot=(0, lean + tilt, 0), style="fine")
        for k in range(1 + (i % 2) + (v == "a")):
            p.box((0.05, 0.04, 0.12 + 0.03 * k), (xx - wd / 2 + 0.05 + 0.08 * k, face, zz - 0.14), WHITE, rot=(0, lean + tilt, 0), style="fine")
        if i == 1:
            p.box((0.5, 0.05, 0.05), (xx, face - 0.02, zz - 0.05), C["charcoal"], rot=(0, lean + 0.7, 0), style="fine")
    # Painter's pail and brush.
    p.cyl(0.2, 0.3, (0.7, -0.5, 0.15), C["iron_light"], segs=8, r2=0.24, style="hard_smooth")
    p.cyl(0.17, 0.04, (0.7, -0.5, 0.31), WHITE, segs=8, style="fine")
    p.rod((0.35, -0.8, 0.04), (0.8, -0.95, 0.06), 0.03, C["timber_pale"])
    if v != "a":
        for i in range(4):
            p.ico(0.2, (rng.uniform(-0.6, 0.6), rng.uniform(0.2, 0.6), 0.2), C["dry_grass"] if v == "b" else C["leaf"], scale=(0.5, 0.5, 1.7), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
@K.kind("tea_hearth", tags=["soft"], variants="abc",
        polish_opts={"bevel_min": 0.2}, story="Hearth stones, a kettle and three cups, all cold: the crew went up the ledge for the shift.")
def tea_hearth(p, v, rng):
    # Ring of chunky stones, ash bed.
    n = 9
    for k in range(n):
        a = math.tau * k / n
        if v == "c" and k in (1, 2):
            continue
        p.ico(0.28, (0.7 * math.cos(a), 0.7 * math.sin(a), 0.2), tint(C["concrete_dark"] if k % 2 else C["concrete"], rng, 0.1),
              scale=(1.0, 1.0, 0.7), rot=(0, 0, a), style="round", subdiv=0)
    p.cyl(1.0, 0.1, (0, 0, 0.05), C["charcoal"] if v != "c" else C["soil"], segs=10, style="hard")
    if v != "c":
        # Cold charred sticks laid flat.
        for a in (0.3, 2.2):
            p.rod((0.35 * math.cos(a), 0.35 * math.sin(a), 0.12), (-0.35 * math.cos(a), -0.35 * math.sin(a), 0.14), 0.05, C["charcoal"])
    # Kettle: a fat pot with a lid, spout and a handle bar lying down.
    kx, ky = (1.2, -0.3) if v != "b" else (1.35, -0.7)
    tip = 0.0
    p.uv(0.38, (kx, ky, 0.36), C["iron"], scale=(1, 1, 0.85), rot=(tip, 0, 0), style="round")
    p.cyl(0.16, 0.1, (kx, ky, 0.7), C["iron_light"], segs=10, style="hard_smooth")
    p.rod((kx + 0.3, ky, 0.4), (kx + 0.62, ky + 0.0, 0.6), 0.07, C["iron"])
    p.rod((kx - 0.3, ky, 0.55), (kx, ky, 0.78), 0.035, C["iron_light"])
    p.rod((kx + 0.3, ky, 0.55), (kx, ky, 0.78), 0.035, C["iron_light"])
    # Cups and a log seat.
    for i, (cx, cy) in enumerate(((-0.4, -1.05), (0.1, -1.2), (-1.1, -0.7))):
        if v == "c" and i == 2:
            continue
        p.cyl(0.1, 0.14, (cx, cy, 0.07), C["canvas_dark"] if i else C["verdigris"], segs=8, r2=0.12, style="hard_smooth")
    p.cyl(0.32, 1.1, (-0.2, 1.35, 0.32), C["timber_grey"], segs=10, rot=SIDE, style="round")
    if v != "a":
        for i in range(3):
            p.ico(0.22, (rng.uniform(-1.2, 1.2), rng.uniform(0.9, 1.5) * (1 if i % 2 else -1), 0.2), C["dry_grass"] if v == "b" else C["leaf"],
                  scale=(0.5, 0.5, 1.8), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
@K.kind("washline", tags=["soft"], variants="abc",
        polish_opts={"bevel_min": 0.2}, line_clear_m=30, story="A tub, a washboard and a short line of shirts: laundry day, interrupted.")
def washline(p, v, rng):
    # Two squat posts, a slack line (draped, never taut), shirts hung on it.
    for x in (-2.0, 2.0):
        p.beam((x, 0, 0.1), (x, 0, 1.35), 0.2, C["timber_dark"])
        p.cyl(0.19, 0.12, (x, 0, 1.4), C["timber_dark"], segs=8, style="hard_smooth")
    if v != "c":
        pts = [(-2.0 + i * 0.5, 0, 1.3 - 0.35 * math.sin(math.pi * i / 8)) for i in range(9)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.03, C["timber_pale"], segs=4)
        for i, x in enumerate((-1.4, -0.4, 0.7, 1.4)):
            if v == "b" and i == 2:
                continue
            drop = 0.75 if i % 2 else 0.6
            col = (C["canvas"], C["canvas_dark"], C["verdigris"], C["canvas_stain"])[i]
            p.ico(0.4, (x, 0, 1.0 - drop * 0.4), col, scale=(1.0, 0.14, drop * 1.0), style="round", subdiv=0)
            p.ico(0.2, (x - 0.35, 0, 0.95), col, scale=(0.6, 0.14, 0.9), rot=(0, 0.2, 0), style="round", subdiv=0)
            p.ico(0.2, (x + 0.35, 0, 0.95), col, scale=(0.6, 0.14, 0.9), rot=(0, -0.2, 0), style="round", subdiv=0)
    else:
        # Line down: posts leaning, a heap of cloth on the ground.
        p.ico(0.9, (0.2, 0.5, 0.2), C["canvas_stain"], scale=(1.8, 1.0, 0.3), style="round", subdiv=0)
        p.ico(0.5, (-0.7, 0.3, 0.3), C["verdigris"], scale=(1, 1, 0.4), style="round", subdiv=0)
        p.beam((-2.0, 0.0, 1.35), (-0.3, 0.3, 0.25), 0.12, C["timber_pale"])
    # Tub: tapered round wooden tub with iron hoops, and a washboard.
    tx, ty = 0.6, -1.4
    p.cyl(0.65, 0.65, (tx, ty, 0.33), C["timber"], segs=12, r2=0.72, style="hard")
    for z in (0.12, 0.5):
        p.torus(0.68 + 0.03 * z, 0.03, (tx, ty, z), C["iron"], major=10, minor=4, style="flat")
    p.cyl(0.55, 0.08, (tx, ty, 0.62), C["canvas_dark"] if v != "a" else WHITE, segs=12, style="hard")
    p.box((0.55, 0.12, 0.8), (-0.7, -1.2, 0.4), C["timber_pale"], rot=(-0.3, 0, 0.1), style="fine")  # washboard (flat, laid back)
    for k in range(5):
        p.rod((-0.95, -1.3, 0.2 + 0.1 * k), (-0.45, -1.3, 0.2 + 0.1 * k), 0.015, C["iron_light"], segs=4)
    p.cyl(0.12, 0.2, (-1.4, -0.9, 0.1), C["iron_light"], segs=8, style="hard_smooth")  # soap pot


# --------------------------------------------------------------------------------------
@K.kind("timber_ties", tags=[], variants="abc",
        story="A low stack of spare ties, bundled with rope where the crew left it.")
def timber_ties(p, v, rng):
    rows = {"a": 4, "b": 3, "c": 2}[v]
    for r in range(rows):
        n = 4 - (r // 2) if v != "c" else 3
        for i in range(n):
            if v == "b" and r == 2 and i > 1:
                continue
            x = (i - (n - 1) / 2) * 0.58 + (0.2 if r % 2 else 0)
            yaw = rng.uniform(-0.04, 0.04) + (0.25 * (i % 2) if v != "a" else 0)
            p.box((0.5, 3.0, 0.36), (x, 0, 0.18 + r * 0.36), tint(C["timber_dark"] if (r + i) % 3 == 0 else C["timber_grey"], rng, 0.1),
                  rot=(0, 0, yaw), jit=0.006)
    if v == "a":
        for y in (-0.8, 0.8):
            p.box((2.5, 0.07, 0.07), (0, y, 1.0), C["timber_pale"], style="fine")
    if v == "b":
        p.box((0.5, 3.0, 0.36), (1.8, 0.8, 0.18), C["timber_dark"], rot=(0, 0, 0.5), jit=0.006)
        p.box((0.5, 3.0, 0.36), (2.2, -0.5, 0.18), C["timber_grey"], rot=(0, 0, -0.3), jit=0.006)
    if v == "c":
        p.box((0.5, 3.0, 0.36), (1.6, 0.6, 0.18), C["timber_grey"], rot=(0, 0, 1.2), jit=0.006)
        for i in range(8):
            p.ico(0.35, (rng.uniform(-1.2, 1.2), rng.uniform(-1.4, 1.4), 0.7), C["leaf"] if i % 2 else C["leaf_dark"], scale=(0.6, 0.6, 1.6), style="round", subdiv=0)
    p.ico(0.3, (-1.4, -1.8, 0.14), C["canvas"], scale=(1.1, 0.8, 0.5), style="round", subdiv=0)  # a wrapped lunch


# --------------------------------------------------------------------------------------
@K.kind("tool_peg", tags=[], variants="abc",
        story="A peg board on two posts holding the crew's saw, adze and shovel.")
def tool_peg(p, v, rng):
    hh = 1.45 if v != "c" else 1.2
    for x in (-1.1, 1.1):
        p.beam((x, 0.3, 0.0), (x, 0.3, hh), 0.2, C["timber_dark"])
    p.box((2.7, 0.12, 1.0), (0, 0.15, 0.95), tint(C["timber_grey"], rng), style="hard_smooth")
    p.box((2.9, 0.18, 0.14), (0, 0.15, hh + 0.05), C["timber_dark"])
    p.box((2.9, 0.18, 0.14), (0, 0.15, 0.4), C["timber_dark"])
    ty = -0.02
    pegs = (-0.9, 0.0, 0.9)
    for x in pegs:
        p.cyl(0.04, 0.2, (x, 0.0, 1.35 if v != "c" else 1.15), C["timber_pale"], segs=6, rot=FACE)
    # Saw (flat blade with handle), adze, shovel (hung blade-up, shorter than board).
    if v != "c":
        p.prism([(0, 0), (0.85, 0), (0.85, 0.07), (0, 0.17)], 0.03, (-1.15, ty - 0.04, 0.75), C["iron_light"], rot=(math.pi / 2, 0, 0), style="fine")
        p.box((0.2, 0.06, 0.18), (-0.1 - 1.2, ty - 0.04, 0.85), C["timber_dark"], style="fine")
        p.rod((-0.1, ty, 1.0), (0.1, ty, 0.4), 0.04, C["timber_pale"])
        p.box((0.4, 0.07, 0.12), (-0.05, ty, 0.95), C["iron"], rot=(0, 0.3, 0.0), style="hard_smooth")
        p.rod((0.9, ty - 0.02, 1.3), (0.9, ty - 0.02, 0.3), 0.05, C["timber_pale"])
        p.box((0.4, 0.04, 0.5), (0.9, ty - 0.02, 0.3), C["iron"], style="hard_smooth")
    else:
        p.rod((0.9, -0.4, 0.06), (1.9, -0.9, 0.1), 0.05, C["timber_pale"])
        p.box((0.4, 0.5, 0.05), (2.1, -1.0, 0.07), C["rust"], rot=(0, 0, 0.5), style="hard_smooth")
    if v == "b":
        p.box((0.6, 0.9, 0.06), (-0.5, -0.7, 0.04), C["timber_grey"], rot=(0, 0, 0.5))
    if v == "c":
        for i in range(6):
            p.ico(0.3, (rng.uniform(-1.4, 1.4), rng.uniform(0.3, 0.8), 0.4), C["leaf"] if i % 2 else C["dry_grass"], scale=(0.5, 0.5, 2.0), style="round", subdiv=0)
    p.cyl(0.22, 0.14, (1.5, -0.9, 0.07), C["iron_light"], segs=8, style="hard_smooth")  # whetstone pan


# --------------------------------------------------------------------------------------
@K.kind("gauge_dial_shed", tags=["machine", "sign", "tall"], variants="abc",
        polish_opts={"bevel_min": 0.2}, story="A hut with one big chalk-white dial: flume flow logged as steady, whatever it does.")
def gauge_dial_shed(p, v, rng):
    p.box((2.4, 2.0, 0.3), (0, 0, 0.15), C["concrete"], style="hard_smooth")
    plank_wall_x(p, rng, -1.05, 1.05, 0.9, 0.3, 2.2, 5, PETROL)
    plank_wall_x(p, rng, -1.05, 1.05, -0.9, 0.3, 2.2, 5, PETROL, skip=(2,) if v == "b" else ())
    plank_wall_y(p, rng, -0.85, 0.85, -1.05, 0.3, 2.2, 4, PETROL)
    plank_wall_y(p, rng, -0.85, 0.85, 1.05, 0.3, 2.2, 4, PETROL)
    for r in range(5):
        for s in (-1, 1):
            if v == "b" and s == 1 and r == 4:
                continue
            p.box((2.7, 0.55, 0.07), (0, s * (1.0 - r * 0.2), 2.25 + r * 0.14), tint(C["timber_dark"] if r % 2 else C["timber_grey"], rng, 0.08), rot=(-s * 0.14, 0, 0), jit=0.004)
    # The dial: back plate, white face, ring, tick marks, needle.
    dz = 1.5
    p.cyl(0.85, 0.16, (0, -1.1, dz), PETROL, segs=20, rot=FACE, style="hard_smooth")
    p.cyl(0.72, 0.06, (0, -1.2, dz), BONE if v != "c" else mix(BONE, C["canvas_stain"], 0.5), segs=20, rot=FACE, style="fine")  # bone dial face
    p.torus(0.8, 0.05, (0, -1.19, dz), C["iron_light"], rot=FACE, major=14, minor=4, style="flat")
    for k in range(8):
        a = math.tau * k / 8
        r1, r2 = (0.52, 0.68)
        p.box((0.04, 0.03, r2 - r1), (0.6 * math.sin(a), -1.24, dz + 0.6 * math.cos(a)), C["charcoal"], rot=(0, -a, 0), style="fine")
    na = 0.5 if v == "a" else (2.3 if v == "b" else -1.0)
    p.box((0.07, 0.04, 0.6), (0.3 * math.sin(na), -1.26, dz + 0.3 * math.cos(na)), C["charcoal"], rot=(0, -na, 0), style="fine")
    p.cyl(0.08, 0.06, (0, -1.27, dz), C["iron"], segs=8, rot=FACE)
    if v == "c":
        p.box((0.9, 0.04, 0.9), (0.2, -1.31, dz + 0.1), C["canvas_dark"], rot=(0, 0.2, 0), style="hard_smooth")
        for i in range(4):
            p.ico(0.3, (-1.1 + i * 0.7, -1.3, 0.35), C["leaf"] if i % 2 else C["leaf_dark"], scale=(0.5, 0.5, 1.9), style="round", subdiv=0)
    # Step stone and a stool.
    p.box((1.0, 0.7, 0.2), (0.5, -1.65, 0.1), C["concrete_light"], style="hard_smooth")
    p.cyl(0.25, 0.45, (-0.9, -1.7, 0.22), C["timber_grey"], segs=8, style="hard_smooth")


# --------------------------------------------------------------------------------------
@K.kind("fish_rack", tags=["soft"], variants="abc",
        story="A drying rack with grey hemp nets and split fish: cooked down off the trestles.")
def fish_rack(p, v, rng):
    # A leaning A-frame (legs meet at an apex, a back brace behind) with one off-level cross-arm:
    # no open span under a straight lintel. c is the same frame fallen over.
    if v != "c":
        ax, az = 0.2, 1.65 if v == "a" else 1.45
        lean = 0.0 if v == "a" else 0.25
        p.beam((-1.0, 0, 0.0), (ax, 0, az), 0.16, C["timber_dark"])
        p.beam((1.1, 0, 0.0), (ax + lean, 0, az), 0.16, C["timber_dark"])
        p.beam((0.5, 1.0, 0.0), (ax, 0, az - 0.1), 0.14, C["timber_dark"])
        z1, z2 = (1.15, 1.3) if v == "a" else (0.75, 1.2)
        p.beam((-1.7, 0, z1), (1.6, 0, z2), 0.14, C["timber_pale"])  # off-level cross-arm
        zt = z1 + 0.1
        nets = 2 if v == "a" else 1
        for k in range(nets):
            x = -0.9 + k * 1.5
            p.ico(0.6, (x, -0.02, zt - 0.4), C["canvas_stain"] if k else C["timber_grey"], scale=(1.0, 0.12, 0.8), style="round", subdiv=0)
        nfish = 5 if v == "a" else 2
        for i in range(nfish):
            x = -1.4 + i * 0.55 if v == "a" else -1.2 + i * 1.0
            p.ico(0.2, (x, -0.1, 0.7), C["bone"] if i % 2 else C["timber_grey"], scale=(0.55, 0.3, 1.6), style="round", subdiv=0)
        if v == "b":
            p.ico(0.5, (-2.3, -0.6, 0.18), C["canvas_stain"], scale=(1.4, 0.9, 0.35), style="round", subdiv=0)  # dropped net
    else:
        # Fallen: legs and arm lying at different angles, net heaped, grass coming through.
        p.beam((-1.2, -0.3, 0.12), (0.8, 0.5, 0.45), 0.16, C["timber_dark"])
        p.beam((0.2, 0.9, 0.12), (1.5, -0.4, 0.3), 0.16, C["timber_grey"])
        p.beam((-1.6, 0.9, 0.1), (0.3, 1.2, 0.1), 0.14, C["timber_pale"])
        p.ico(0.8, (0.2, 0.2, 0.2), C["canvas_stain"], scale=(1.9, 0.8, 0.3), style="round", subdiv=0)
        for i in range(8):
            p.ico(0.3, (rng.uniform(-1.6, 1.6), rng.uniform(-0.6, 1.0), 0.5), C["dry_grass"] if i % 2 else C["leaf"], scale=(0.5, 0.5, 1.9), style="round", subdiv=0)
    p.cyl(0.28, 0.4, (2.2, -0.8, 0.2), C["iron_light"], segs=10, r2=0.32, style="hard_smooth")  # salt pail


# --------------------------------------------------------------------------------------
@K.kind("bent_numbers", tags=["plant", "sign"], variants="abc",
        story="A fallen bent plank with its number still painted, and grass pushing up through the gap.")
def bent_numbers(p, v, rng):
    # Thick plank slab lying flat, broken, with painted chalk numerals as raised blocks.
    L = {"a": 2.6, "b": 2.2, "c": 1.8}[v]
    p.box((L, 0.9, 0.18), (0, 0, 0.09), C["timber_grey"], style="hard_smooth", jit=0.004)
    p.box((L * 0.7, 0.92, 0.14), (0.3, 0.05, 0.25), C["timber_dark"], style="hard_smooth", rot=(0, 0, 0.12))
    p.box((1.3, 0.8, 0.14), (-0.5, -0.1, 0.34) if v != "c" else (-0.5, 0.1, 0.12), tint(C["timber"], rng), rot=(0.0, 0.1, 0.15 if v != "a" else 0.0), style="hard_smooth")
    # Numerals: bold chalk-white strokes on the top plank ("17" style).
    p.box((0.12, 0.55, 0.05), (-0.85, -0.1, 0.43 if v != "c" else 0.21), WHITE, rot=(0, 0.1, 0.15), style="fine")
    p.box((0.4, 0.12, 0.05), (-0.45, -0.28, 0.43 if v != "c" else 0.21), WHITE, rot=(0, 0.1, 0.15), style="fine")
    p.box((0.4, 0.12, 0.05), (-0.45, 0.08, 0.43 if v != "c" else 0.21), WHITE, rot=(0, 0.1, 0.15), style="fine")
    p.box((0.12, 0.4, 0.05), (-0.22, -0.2, 0.43 if v != "c" else 0.21), WHITE, rot=(0, 0.1, 0.15), style="fine")
    # Iron strap and spikes.
    p.box((0.16, 1.0, 0.07), (0.85, 0, 0.32), C["iron"], style="hard_smooth")
    p.cyl(0.07, 0.14, (0.85, 0.3, 0.4), C["iron_light"], segs=6, style="hard_smooth")
    # Grass through the gap.
    n = {"a": 5, "b": 9, "c": 15}[v]
    for i in range(n):
        x = 0.9 - 0.12 * i + rng.uniform(-0.1, 0.3)
        y = rng.uniform(-0.3, 0.3)
        p.ico(0.2, (x, y, 0.35), C["leaf"] if i % 2 else (C["dry_grass"] if v != "c" else C["leaf_dark"]), scale=(0.4, 0.4, 1.7 + 0.4 * (v == "c")), style="round", subdiv=0)
    if v == "c":
        p.ico(0.5, (0.3, 0.1, 0.25), C["soil"], scale=(1.7, 0.8, 0.3), style="round", subdiv=0)


# --------------------------------------------------------------------------------------
def tuft(p, loc, h, col, lean=(0, 0), w=0.14):
    p.ico(w, (loc[0] + lean[0] * h * 0.5, loc[1] + lean[1] * h * 0.5, loc[2] + h * 0.5), col, scale=(1, 1, h / w * 0.5),
          rot=(lean[1] * 0.4, -lean[0] * 0.4, 0), subdiv=0, style="round")


@K.kind("reed_clump", tags=["plant", "soft"], variants="abc",
        story="Cattails and reeds crowding a damp patch where the canal seeps through the flume footing.")
def reed_clump(p, v, rng):
    p.ico(0.9, (0, 0, 0.1), C["soil"], scale=(1.6, 1.3, 0.2), style="round", subdiv=0)
    n, hmax = {"a": (12, 1.9), "b": (9, 1.3), "c": (14, 1.0)}[v]
    for i in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.95)
        h = rng.uniform(0.5, 1.0) * hmax
        lean = (math.cos(a) * 0.35, math.sin(a) * 0.35)
        col = C["leaf"] if i % 3 else C["leaf_dark"]
        if v == "b" and i % 4 == 0:
            col = C["dry_grass"]
        tuft(p, (r * math.cos(a), r * math.sin(a), 0.1), h, col, lean, w=0.12)
        if v != "c" and i % 3 == 0:  # cattail heads
            p.uv(0.09, (r * math.cos(a) + lean[0] * h * 0.9, r * math.sin(a) + lean[1] * h * 0.9, 0.1 + h * 0.85), C["timber_dark"], scale=(1, 1, 2.6), u=6, v=4, style="round")
    if v == "c":  # reeds fallen over, silty, with an old tin pail half-buried
        p.cyl(0.25, 0.35, (0.8, -0.6, 0.2), C["rust"], segs=8, rot=(0.9, 0.2, 0), style="hard_smooth")
        p.ico(0.5, (-0.4, 0.4, 0.2), C["dry_grass"], scale=(1.8, 0.7, 0.3), style="round", subdiv=0)


@K.kind("saltbush", tags=["plant", "soft"], variants="abc",
        story="A grey-green saltbush shrub growing out of a cracked patch of canal floor.")
def saltbush(p, v, rng):
    p.ico(0.7, (0, 0, 0.05), C["soil"], scale=(1.5, 1.4, 0.15), style="round", subdiv=0)
    for i in range(5):
        a = math.tau * i / 5 + 0.3
        p.rod((0, 0, 0.05), (0.35 * math.cos(a), 0.35 * math.sin(a), 0.5), 0.05, C["timber_dark"])
    n, hh = {"a": (12, 1.0), "b": (8, 0.7), "c": (14, 0.5)}[v]
    for i in range(n):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.15, 0.75 if v != "c" else 1.0)
        z = 0.35 + rng.uniform(0, hh) * (1 - r / 1.2)
        col = mix(C["leaf"], C["timber_grey"], 0.45 if i % 2 else 0.2)
        if v == "b" and i % 3 == 0:
            col = C["dry_grass"]
        p.ico(rng.uniform(0.22, 0.36), (r * math.cos(a), r * math.sin(a), z), col, scale=(1.0, 1.0, 0.75), style="round", subdiv=0)
    if v == "c":
        p.ico(0.45, (0.9, 0.5, 0.2), C["concrete"], scale=(1.2, 1.0, 0.7), style="hard_smooth", subdiv=0)  # stone it pushes beside
        p.cyl(0.14, 0.9, (-1.0, -0.5, 0.14), C["rust"], segs=8, rot=SIDE, style="hard_smooth")


# --------------------------------------------------------------------------------------
@K.kind("pipe_section", tags=["plant", "machine"], variants="abc",
        polish_opts={"bevel_min": 0.2}, story="A spare length of flume pipe on sleepers with a bush growing out of its open end.")
def pipe_section(p, v, rng):
    L = {"a": 3.2, "b": 2.6, "c": 2.4}[v]
    r = 0.62 if v != "c" else 0.48
    p.cyl(r, L, (0, 0, r + 0.2), PETROL if v == "a" else C["rust"], segs=10, rot=SIDE, style="hard_smooth")
    p.cyl(r - 0.1, 0.06, (L / 2 + 0.02, 0, r + 0.2), C["charcoal"], segs=12, rot=SIDE, style="flat")
    for x in (-L / 2 + 0.2, L / 2 - 0.2):
        p.cyl(r + 0.08, 0.2, (x, 0, r + 0.2), COPPER, segs=10, rot=SIDE, style="hard_smooth")
        for k in range(4):
            a = math.tau * k / 4
            p.cyl(0.05, 0.08, (x + 0.12 * (1 if x > 0 else -1), (r + 0.1) * math.cos(a), r + 0.2 + (r + 0.1) * math.sin(a)), C["iron_light"], segs=6, rot=SIDE)
    for x in (-1.0, 1.0):
        p.box((0.5, 1.6, 0.2), (x, 0, 0.1), C["timber_grey"], style="hard_smooth")
        for s in (-1, 1):
            p.box((0.5, 0.2, 0.3), (x, s * 0.5, 0.35), C["timber_dark"], rot=(0, 0, 0))
    ex = L / 2 + 0.1
    n = {"a": 3, "b": 5, "c": 5}[v]
    for i in range(n):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, r * 0.7)
        h = rng.uniform(0.5, 1.2) * (1 if v != "a" else 0.7)
        base = (ex - 0.1, rr * math.cos(a), r + 0.2 + rr * math.sin(a))
        p.ico(0.22, (base[0] + h * 0.5, base[1], base[2] + h * 0.3 + 0.1), C["leaf"] if i % 2 else C["leaf_dark"], scale=(1.6, 0.9, 0.9), rot=(0, 0.3, 0), style="round", subdiv=0)
    if v == "c":
        p.ico(0.9, (ex + 0.7, 0, 0.35), C["leaf_dark"], scale=(1.0, 1.1, 0.5), style="round", subdiv=0)
        p.ico(0.5, (-1.8, 0.8, 0.2), C["canvas_stain"], scale=(1.3, 1.0, 0.3), style="round", subdiv=0)
    if v == "b":
        p.cyl(0.14, 0.3, (-1.9, -0.9, 0.15), C["iron_light"], segs=8, style="hard_smooth")


# --------------------------------------------------------------------------------------
# Sight gags (W46-07): the shared builders in kit.py, so the dam and the flume carry the same two kinds.
K.kind("foreman_billboard", hero=True, tags=["sign", "tall"], variants="ab",
       story="A cast Foreman notice, square and spotless, and the keepers' answer on it: a ball-shaped hole and chalk.")(kit.foreman_billboard)
K.kind("shift_table", tags=["machine"], variants="ab",
       story="A cast shift table still set for a crew that left: giant gloves laid out square, the clock stopped on the bell.")(kit.shift_table)


# --------------------------------------------------------------------------------------
# Wayfinding (W46 E3-01, design-v3/WAYFINDING.md section 2.3): the keepers' chalk and bunting at the mouths of side
# routes, the same hand on both parks. dam.py owns the two builders; importing it registers the Dam's kinds on the Dam's
# own kit, not this one. Sand, bone, chalk, oxide and copper rope; nothing mint; dressing with no collider.
import dam

K.closed_lods |= {"chalk_turn", "keeper_bunting"}
K.kind("chalk_turn", hero=False, tags=["sign"], variants="abc",
       story="A keeper's chalk turn mark at the mouth of a side route: a fat crooked arrow and a stone to hold the place.")(dam.chalk_turn)
K.kind("keeper_bunting", hero=False, tags=["soft", "sign"], variants="ab",
       story="Keeper bunting at a side route's mouth: crooked poles, sand and bone cloth, tied on with copper rope.")(dam.keeper_bunting)


if __name__ == "__main__":
    K.main()
