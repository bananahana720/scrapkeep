"""Pit park dressing kit (The Dig, world 2, noon, copper porphyry open pit).

The pit crews were a day-shift mining outfit: petrol enamel machine bodies with oxide bands and
bone plates, grey-green host rock, pale tailings, lunch pails left on shelves. LAMP VETO: nothing
here is lit, no lamp, no light pool, no glass that could read as glowing. The petrol veins appear
only as thin streaks on rock and core.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/pit.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, shade, tint
from mathutils import Matrix

K = kit.Kit("pit", polish_opts={"detail": 1})

OCHRE = "365754"
OCHRE_DARK = shade("365754", 0.8)
OXIDE = "9b513a"
OXIDE_DARK = shade("9b513a", 0.78)
HOST = "7d8678"
HOST_DARK = "5e6a60"
TAILS = "d8d2c0"
TAILS_DARK = "bdb7a2"
VEIN = "365754"
TYRE = "2b2f2e"
GLASS = "2e3836"
HEMP = "8e8060"
TIN = "a9a99a"
SAGE = "7f8f68"
SAGE_DARK = "5f6f4c"
SAGE_PALE = "98a27c"


def soft_ico(p, radius, loc, color, **kw):
    """Low-poly ico; the soft style subdivides it twice, so subdiv 0 is plenty."""
    kw.setdefault("subdiv", 0)
    if kw.get("style", "soft") == "soft" and radius < 0.5:
        kw["style"] = "round"
    return p.ico(radius, loc, color, **kw)


PEBBLES = {"timber_lagging_b": 2, "rope_drum_wagon_b": 4}


def pebbles(p, key, rng, spread):
    """A few host-rock pebbles on the ground (count tuned per kind, see PEBBLES)."""
    for k in range(PEBBLES.get(key, 0)):
        a = k * 2.4 + 0.7
        r = 0.14 + 0.03 * (k % 3)
        soft_ico(p, r, (math.cos(a) * spread * (0.7 + 0.1 * k), math.sin(a) * spread * (0.7 + 0.1 * k), r * 0.5),
                 tint(HOST, rng, 0.08), scale=(1.0, 0.9, 0.7), style="hard")


def rot_x(y, z, theta):
    """Rotate a (y, z) point about the X axis by theta (a bed hinge helper)."""
    return (y * math.cos(theta) - z * math.sin(theta), y * math.sin(theta) + z * math.cos(theta))


def bursage(p, x, y, z, s, rng, dry=False, lean=False):
    """A grey-green bursage mound; `dry` swaps in straw tones. `lean` (the scrub kinds, hundreds per park) drops a
    blob and a stem and draws the rest unsubdivided: an 80-tri ico (subdiv 2) in place of a 20-tri one under a subsurf (120)."""
    base = "a39a64" if dry else SAGE
    blob = dict(style="flat", subdiv=2) if lean else dict(style="soft")
    for k in range(3 if lean else 4):
        a = k * 1.9 + rng.uniform(0, 1)
        soft_ico(p, 0.3 * s, (x + math.cos(a) * 0.22 * s, y + math.sin(a) * 0.22 * s, z + 0.18 * s + 0.05 * k * s),
              tint(base if k % 2 else (SAGE_PALE if not dry else "b0a674"), rng, 0.07),
              scale=(1.0, 1.0, 0.75), **blob)
    for k in range(2 if lean else 3):
        a = k * 2.3 + 0.4
        p.rod((x, y, z + 0.1 * s), (x + math.cos(a) * 0.3 * s, y + math.sin(a) * 0.3 * s, z + 0.65 * s),
              0.018 * s, "a39a64", segs=5, style="flat" if lean else "round")


def cholla(p, x, y, z, s, rng, arms=2, lean=False):
    """A jointed cholla: chunky segments, pale fuzz knobs (no spines to read as a creature). `lean` (the scrub kinds)
    keeps one trunk knob, gives the trunk 6 sides and draws the knobs as 80-tri icos with no subsurf."""
    col = "8c9a72"
    top = z + 0.9 * s
    segs = 6 if lean else 7
    knob = dict(style="flat", subdiv=2) if lean else dict(style="soft")
    p.rod((x, y, z), (x, y, top), 0.1 * s, col, segs=segs, r2=0.085 * s)
    for h in ((0.5,) if lean else (0.25, 0.5, 0.75)):
        soft_ico(p, 0.12 * s, (x, y, z + 0.9 * s * h), "a9ae88", scale=(1.0, 1.0, 0.8), **knob)
    for k in range(arms):
        a = k * math.pi + 0.8 + rng.uniform(-0.2, 0.2)
        sx, sz = z + 0.5 * s + 0.12 * k * s, 0
        start = (x, y, sx)
        mid = (x + math.cos(a) * 0.35 * s, y + math.sin(a) * 0.35 * s, sx + 0.25 * s)
        end = (x + math.cos(a) * 0.4 * s, y + math.sin(a) * 0.4 * s, sx + 0.7 * s)
        p.rod(start, mid, 0.08 * s, col, segs=6)
        p.rod(mid, end, 0.075 * s, tint(col, rng, 0.05), segs=6)
        soft_ico(p, 0.11 * s, end, "a9ae88", scale=(1, 1, 0.85), **knob)
    soft_ico(p, 0.12 * s, (x, y, top + 0.04 * s), "a9ae88", scale=(1, 1, 0.85), **knob)


def rock(p, x, y, z, r, rng, vein=False, col=HOST):
    """Smooth host-rock lump; `vein` lays a thin copper-carbonate streak on the rock face."""
    soft_ico(p, r, (x, y, z + r * 0.55), tint(col, rng, 0.08), scale=(1.0, rng.uniform(0.8, 1.1), 0.7),
          rot=(0, 0, rng.uniform(0, 3)), subdiv=1, style="hard_smooth", jit=r * 0.06)
    if vein:
        p.box((r * 0.9, r * 0.06, r * 0.16), (x, y - r * 0.82, z + r * 0.62), VEIN, rot=(0.05, 0, 0.35),
              style="fine")


def pail(p, x, y, z, col, rng, lid=False, s=1.0):
    """A lunch pail: tapered body, rim band, a swung-over bail handle. Never stacked."""
    p.cyl(0.2 * s, 0.34 * s, (x, y, z + 0.17 * s), col, segs=10, r2=0.23 * s, style="hard")
    p.cyl(0.235 * s, 0.05 * s, (x, y, z + 0.33 * s), shade(col, 0.82), segs=10, style="hard")
    p.torus(0.2 * s, 0.014 * s, (x, y, z + 0.37 * s), C["iron"], rot=(math.pi / 2, 0, rng.uniform(0, 1.5)),
            scale=(1, 0.9, 1), major=8, minor=3)
    if lid:
        p.cyl(0.235 * s, 0.05 * s, (x, y, z + 0.36 * s), shade(col, 0.9), segs=10, style="hard")


def sack(p, x, y, z, s, col, rng):
    soft_ico(p, 0.3 * s, (x, y, z + 0.2 * s), tint(col, rng, 0.05), scale=(1.0, 0.8, 0.7),
          rot=(0, 0, rng.uniform(0, 3)), style="soft")


def tyre(p, x, y, r, w, flat=False):
    """A chunky haul-truck tyre standing on its tread, axis along X. `flat` squats it."""
    if flat:
        r = r * 0.75
    z = r
    p.cyl(r, w, (x, y, z), TYRE, segs=16, rot=(0, math.pi / 2, 0), style="round")
    p.cyl(r * 1.0, w * 0.5, (x, y, z), shade(TYRE, 1.15), segs=16, rot=(0, math.pi / 2, 0), style="round")
    side = 1 if x > 0 else -1
    p.cyl(r * 0.5, 0.12, (x + side * w * 0.5, y, z), OXIDE_DARK, segs=12, rot=(0, math.pi / 2, 0), style="hard")
    p.cyl(r * 0.22, 0.18, (x + side * w * 0.52, y, z), C["iron"], segs=8, rot=(0, math.pi / 2, 0), style="hard")
    for k in range(12):
        a = math.tau * k / 12
        p.box((w * 0.9, 0.2, 0.22), (x, y + math.sin(a) * r * 0.99, z + math.cos(a) * r * 0.99), shade(TYRE, 0.9),
              rot=(-a, 0, 0), style="hard")
    if flat:
        soft_ico(p, r * 0.55, (x, y, 0.18), TYRE, scale=(w * 0.9, 1.15, 0.28), style="soft")


@K.kind("haul_truck", hero=True, variants="abc", tags=["machine"],
        story="The last haul truck down at shift end: parked dead, a tyre flat, the bed tipped, every lamp dark.")
def haul_truck(p, v, rng):
    body = OCHRE if v != "c" else mix(OCHRE, OXIDE, 0.2)
    trim = OXIDE if v != "c" else OXIDE_DARK
    for x in (-1.5, 1.5):
        p.box((0.5, 10.2, 0.5), (x, 0.4, 1.95), C["charcoal"], style="hard")
    for y in (-3.3, 3.0):
        p.box((6.2, 0.45, 0.45), (0, y, 1.6), C["iron"], style="hard")
    r, w = 1.55, 1.1
    flat_x, off_x = 3.0, (3.0 if v == "b" else None)
    for x in (-3.0, 3.0):
        for y in (-3.3, 3.0):
            if v == "b" and x == off_x and y == 3.0:
                p.cyl(0.8, 0.5, (x, y, 1.6), C["iron"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
                p.cyl(0.5, 0.3, (x + 0.35, y, 1.6), OXIDE_DARK, segs=10, rot=(0, math.pi / 2, 0), style="hard")
                continue
            tyre(p, x, y, r, w, flat=(x == -flat_x and y == 3.0))
    if v == "b":
        p.torus(1.2, 0.45, (5.7, 1.3, 0.45), TYRE, rot=(0.12, 0, 0.4), major=16, minor=8, style="round")
        p.cyl(0.85, 0.2, (5.7, 1.3, 0.35), OXIDE_DARK, segs=10, style="hard")
    p.box((2.4, 2.8, 1.4), (-1.3, -4.0, 2.9), body, style="hard")
    p.box((2.5, 0.35, 1.2), (-1.3, -5.5, 2.6), "d2c5a5", style="hard")
    for k in range(7):
        p.box((0.16, 0.12, 0.9), (-2.2 + k * 0.3, -5.72, 2.65), C["charcoal"], style="fine")
    p.box((3.6, 0.6, 0.35), (-0.1, -5.9, 1.45), C["iron"], style="hard")
    p.box((2.4, 2.4, 0.3), (-1.5, -1.5, 2.45), C["iron_light"], style="hard")
    p.box((2.1, 2.1, 2.0), (-1.5, -1.6, 3.6), body, style="hard")
    p.box((1.9, 0.12, 1.0), (-1.5, -2.7, 3.9), GLASS, style="fine")
    p.box((0.12, 1.6, 0.9), (-2.57, -1.6, 3.9), GLASS, style="fine")
    p.box((0.12, 1.6, 0.9), (-0.43, -1.6, 3.9), GLASS, style="fine")
    p.box((2.6, 3.2, 0.2), (-1.5, -1.9, 4.7), trim, style="hard")
    for dx in (-1.7, 1.7):
        for dy in (-1.7, 1.7):
            p.box((0.3, 0.3, 1.6), (-1.5 + dx, -1.9 + dy, 5.5), C["iron"], style="hard")
    p.box((3.8, 3.8, 0.3), (-1.5, -1.9, 6.25), shade(OCHRE, 1.1), style="hard")
    p.cyl(0.14, 1.0, (-2.6, -0.2, 3.2), C["charcoal"], segs=8, style="round")
    p.rod((-3.0, -2.75, 3.1), (-3.0, -2.75, 3.6), 0.05, C["iron_light"], segs=6)
    ang = {"a": 0.22, "b": 0.45, "c": 0.0}[v]
    hy, hz = 4.6, 2.5
    th = -ang

    def bp(y, z):
        ry, rz = rot_x(y - hy, z - hz, th)
        return hy + ry, hz + rz

    def bed_box(size, cx, cy, cz, col):
        y, z = bp(cy, cz)
        p.box(size, (cx, y, z), col, rot=(th, 0, 0), style="hard")

    L = 9.4
    cy = hy - L / 2
    bed_box((5.0, L, 0.4), 0, cy, hz + 0.1, shade(body, 0.92))
    for sx in (-1, 1):
        bed_box((0.4, L, 1.6), sx * 2.5, cy, hz + 0.9, body)
        bed_box((0.45, L + 0.1, 0.3), sx * 2.5, cy, hz + 1.75, trim)
    bed_box((5.4, 0.45, 2.2), 0, cy - L / 2 + 0.2, hz + 1.2, body)
    bed_box((5.6, 1.2, 0.5), 0, cy - L / 2 - 0.6, hz + 2.4, trim)
    p.perch((-1.5, -1.9, 6.4))
    for k in range(5):
        for sx in (-1, 1):
            bed_box((0.15, 0.35, 1.4), sx * 2.72, cy - 3.6 + k * 1.8, hz + 0.9, shade(trim, 0.9))
    for sx in (-1, 1):
        y, z = bp(hy, hz + 0.4)
        p.cyl(0.28, 0.6, (sx * 1.6, y, z), C["iron"], segs=8, rot=(0, math.pi / 2, 0), style="hard")
    fy, fz = -0.8, 1.9
    uy, uz = bp(-0.8, hz - 0.1)
    for sx in (-1.4, 1.4):
        p.rod((sx, fy, fz), (sx, uy, uz), 0.2, "b77843", segs=8)
        p.rod((sx, fy, fz), (sx, fy + (uy - fy) * 0.45, fz + (uz - fz) * 0.45), 0.28, C["iron"], segs=8)
    p.box((0.9, 0.4, 0.4), (-3.0, 0.2, 0.2), C["timber_dark"], rot=(0, 0, 0.1))
    p.box((0.9, 0.4, 0.4), (3.0, -2.4, 0.2), C["timber_dark"], rot=(0, 0, -0.1))
    if v == "a":
        soft_ico(p, 0.5, (0.0, 6.0, 0.28), TAILS, scale=(2.2, 1.7, 0.5), style="soft")
        soft_ico(p, 0.7, (-0.2, 3.6, hz + 0.9), TAILS_DARK, scale=(1.6, 1.6, 0.4), style="soft")
    elif v == "b":
        soft_ico(p, 1.4, (0.2, 6.6, 0.45), TAILS, scale=(1.9, 1.4, 0.55), style="soft")
        soft_ico(p, 0.7, (-1.8, 6.0, 0.25), HOST_DARK, scale=(1.2, 1.0, 0.6), style="hard")
    else:
        for k in range(5):
            p.box((0.05, 0.5, 1.0), (-2.74, -2.8 + k * 1.6, hz + 0.8), OXIDE_DARK, style="fine")
            p.box((0.05, 0.5, 1.0), (2.74, -2.8 + k * 1.6, hz + 0.8), OXIDE_DARK, style="fine")
        for k, (bx, by) in enumerate(((-1.0, 1.0), (0.9, -1.0), (0.0, 2.8), (-0.8, -3.0))):
            bursage(p, bx, by, hz + 0.4, 1.7, rng)
        bursage(p, 3.6, 4.4, 0.0, 1.2, rng)
        soft_ico(p, 1.0, (0, 6.0, 0.25), TAILS_DARK, scale=(2.2, 1.4, 0.35), style="soft")


@K.kind("drill_rig_wreck", hero=True, variants="ab", tags=["machine"],
        story="Powder-cut drill rig left on its crawler pads, the mast lowered flat onto its cradle.")
def drill_rig_wreck(p, v, rng):
    lean = 0.0 if v == "a" else 0.1
    for sx in (-1, 1):
        if v == "b" and sx == 1:
            p.box((1.4, 6.2, 0.6), (sx * 2.2, 0, 0.95), C["iron"], style="hard")
            for k in range(5):
                p.cyl(0.38, 0.7, (sx * 2.2, -2.4 + k * 1.2, 0.5), OXIDE_DARK, segs=10, rot=(0, math.pi / 2, 0), style="hard")
            for k in range(6):
                p.box((1.3, 0.8, 0.3), (4.3 + 0.1 * k, -2.5 + k * 1.1, 0.15), C["iron"], rot=(0, 0, 0.12 * k - 0.3), style="hard")
            continue
        p.box((1.5, 6.8, 1.3), (sx * 2.2, 0, 0.75), C["iron"], style="hard")
        for k in range(14):
            p.box((1.6, 0.42, 0.22), (sx * 2.2, -3.1 + k * 0.48, 0.14), shade(C["iron_light"], 0.85 + 0.03 * (k % 3)), style="hard")
        for yy in (-3.3, 3.3):
            p.cyl(0.65, 1.5, (sx * 2.2, yy, 0.8), OXIDE_DARK, segs=12, rot=(0, math.pi / 2, 0), style="hard")
    p.box((5.0, 6.0, 0.5), (0, 0, 1.55), C["charcoal"], style="hard")
    p.box((3.2, 2.8, 2.0), (-0.5, 1.4, 2.8), OCHRE, style="hard")
    p.box((3.3, 2.9, 0.3), (-0.5, 1.4, 3.9), OCHRE_DARK, style="hard")
    for k in range(5):
        p.box((0.2, 0.1, 1.2), (-1.7 + k * 0.5, 2.88, 2.8), C["charcoal"], style="fine")
    p.cyl(0.2, 1.1, (0.7, 0.4, 4.4), C["charcoal"], segs=8, style="round")
    p.box((1.8, 2.0, 2.0), (1.4, -1.6, 2.8), OCHRE_DARK if v == "b" else OCHRE, style="hard")
    p.box((1.6, 0.1, 0.9), (1.4, -2.65, 3.1), GLASS, style="fine")
    p.box((0.1, 1.2, 0.9), (2.3, -1.6, 3.1), GLASS, style="fine")
    p.box((2.0, 2.2, 0.25), (1.4, -1.6, 3.9), "d2c5a5", style="hard")
    p.cyl(0.35, 1.8, (-2.2, -1.6, 2.2), C["iron_light"], segs=10, style="round")
    p.cyl(0.25, 1.0, (-2.2, -1.6, 3.3), C["iron"], segs=8, style="round")
    mz = 4.65
    my0, my1 = -4.6, 5.0
    cradle = [(-0.0, -2.8), (0.0, 2.8)]
    for _, yy in cradle:
        p.box((1.8, 0.45, 0.6), (0, yy, 4.15), C["timber_dark"], style="hard")
    if v == "a":
        a_pt, b_pt = (0, my0, mz), (0, my1, mz)
        p.box((1.0, my1 - my0, 0.9), (0, (my0 + my1) / 2, mz), OCHRE, style="hard")
        for k in range(10):
            yy = my0 + 0.5 + k * 0.95
            p.box((1.15, 0.28, 1.05), (0, yy, mz), shade(OXIDE, 0.85), style="hard")
        p.cyl(0.55, 0.9, (0, my1 + 0.2, mz), C["iron"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
        p.cyl(0.4, 0.8, (0, my0 - 0.2, mz), C["iron_light"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
    else:
        rock(p, 0.4, -5.3, 0.0, 1.0, rng, vein=True)
        pts = [(0.4, -5.2, 1.75), (0.15, -1.2, 2.45), (0.0, 3.4, 4.4)]
        for a_pt, b_pt in zip(pts, pts[1:]):
            p.beam(a_pt, b_pt, 1.0, OCHRE, h=0.9, roll=0.0)
            ang = math.atan2(b_pt[2] - a_pt[2], b_pt[1] - a_pt[1])
            for k in range(5):
                t = (k + 0.5) / 5
                q = tuple(a_pt[i] + (b_pt[i] - a_pt[i]) * t for i in range(3))
                p.box((1.2, 0.28, 1.1), q, shade(OXIDE, 0.85), rot=(ang, 0, 0), style="hard")
        p.cyl(0.55, 0.9, (0.0, 3.6, 4.5), C["iron"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
        bursage(p, 1.8, -4.2, 0.0, 1.8, rng)
        bursage(p, -2.4, -4.8, 0.0, 1.4, rng, dry=True)
        bursage(p, 4.2, 2.0, 0.0, 1.5, rng)
    for k in range(4):
        p.rod((-4.9 + 0.0 * k, -2.5 + k * 0.28, 0.2), (-4.9, 2.4 + k * 0.1, 0.2), 0.11, C["iron_light"], segs=8)
    for k, (rx, ry) in enumerate(((-4.2, -3.9), (4.6, -3.4), (-3.8, 4.2), (3.9, 4.3))):
        rock(p, rx, ry, 0.0, 0.55 + 0.1 * k, rng, vein=(k == 1))
    soft_ico(p, 1.0, (0.0, -5.4 if v == "a" else 6.0, 0.25), TAILS, scale=(2.2, 1.5, 0.4), style="soft")


@K.kind("rope_drum_wagon", hero=True, variants="ab", tags=["machine"],
        story="Hoist-rope wagon: a giant coiled drum on a timber bed, parked where the last shift unspooled it.")
def rope_drum_wagon(p, v, rng):
    sag = 0.0 if v == "a" else 0.45
    bed_z = 1.35
    p.box((3.8, 7.0, 0.4), (0, 0, bed_z), C["timber"], style="hard", rot=(0, 0.0, 0))
    for sx in (-1, 1):
        p.beam((sx * 1.7, -3.5, bed_z - 0.3), (sx * 1.7, 3.5, bed_z - 0.3), 0.3, C["timber_dark"], h=0.4)
    for yy in (-2.8, 0.0, 2.8):
        p.beam((-2.0, yy, bed_z - 0.1), (2.0, yy, bed_z - 0.1), 0.28, C["timber_dark"], h=0.3)
    for k in range(7):
        p.box((3.8, 0.9, 0.12), (0, -3.0 + k, bed_z + 0.26), tint(C["timber_pale"], rng, 0.06), style="fine")
    for sx in (-1, 1):
        for yy in (-2.7, 2.7):
            broken = v == "b" and sx == -1 and yy == 2.7
            wz = 1.15 if not broken else 0.95
            ox = sx * 2.25 + (-0.35 if broken else 0.0)
            tilt = 0.25 if broken else 0.0
            p.torus(1.05, 0.14, (ox, yy, wz), C["iron"], rot=(0, math.pi / 2 + tilt, 0), major=16, minor=6)
            p.cyl(0.28, 0.5, (ox, yy, wz), C["timber_dark"], segs=10, rot=(0, math.pi / 2 + tilt, 0), style="hard")
            for k in range(8):
                a = math.tau * k / 8 + 0.2
                p.rod((ox, yy + 0.2 * math.cos(a), wz + 0.2 * math.sin(a)),
                      (ox + 0.04 * tilt, yy + 1.0 * math.cos(a), wz + 1.0 * math.sin(a)), 0.07, C["timber"], segs=6)
    dz = bed_z + 0.3 + 1.9 - sag * 0.0
    for sx in (-1, 1):
        p.box((0.45, 1.6, 2.5), (sx * 1.7, 0, bed_z + 1.5), C["timber_dark"], style="hard")
    ang = 0 if v == "a" else 0.0
    p.cyl(0.35, 4.3, (0, 0, dz), C["iron"], segs=10, rot=(0, math.pi / 2, 0), style="round")
    rr = 1.75 if v == "a" else 1.25
    for sx in (-1, 1):
        p.cyl(2.1, 0.25, (sx * 1.55, 0, dz), C["timber_grey"], segs=20, rot=(0, math.pi / 2, 0), style="hard")
        p.cyl(2.2, 0.12, (sx * 1.66, 0, dz), C["iron"], segs=20, rot=(0, math.pi / 2, 0), style="hard")
    p.cyl(rr, 2.9, (0, 0, dz), shade(HEMP, 0.9), segs=20, rot=(0, math.pi / 2, 0), style="round")
    for k in range(8):
        xx = -1.25 + k * 0.36
        p.torus(rr, 0.2, (xx, 0, dz), tint(HEMP, rng, 0.07), rot=(0, math.pi / 2, 0), major=20, minor=6)
    pts = []
    for k in range(18):
        a = k * 0.42
        rad = 0.4 + 0.075 * k if v == "a" else 0.55 + 0.11 * k
        pts.append((3.9 + math.cos(a) * rad * 0.9, -3.0 + math.sin(a) * rad * 0.9 if v == "a" else -3.4 + math.sin(a) * rad, 0.12))
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.11, HEMP, segs=6)
    p.beam((0, -3.5, 0.35), (0.6, -7.2, 0.18), 0.3, C["timber_dark"], h=0.28)
    p.box((0.8, 0.4, 0.4), (2.5, -4.2, 0.2), C["timber_dark"], rot=(0, 0, 0.2))
    if v == "b":
        bursage(p, -3.6, 3.2, 0.0, 1.6, rng)
        bursage(p, 3.0, 0.5, 0.0, 1.2, rng, dry=True)
        p.box((0.9, 1.6, 0.18), (-4.0, 1.0, 0.1), C["timber_grey"], rot=(0, 0, 0.5))
    pebbles(p, "rope_drum_wagon_" + v, rng, 5.0)


@K.kind("shift_bell", tags=["sign"], variants="ab",
        story="Shift bell on a stout post, its over-long rope left coiled flat on the ground.")
def shift_bell(p, v, rng):
    if v == "a":
        p.cyl(0.3, 1.4, (0, 0, 0.7), C["timber_dark"], segs=8, r2=0.26, style="hard")
        p.cyl(0.5, 0.2, (0, 0, 0.5), C["timber_dark"], segs=8, r2=0.3, style="hard")
        p.box((0.9, 0.5, 0.2), (0, 0, 1.45), C["timber"], style="hard")
        p.cyl(0.68, 0.7, (0, 0, 1.95), "b77843", segs=14, r2=0.3, style="hard")
        p.ring(0.58, 0.8, 0.12, (0, 0, 1.62), C["iron_light"], segs=14, style="hard")
        soft_ico(p, 0.2, (0, 0, 1.55), OXIDE_DARK, style="soft")
        p.cyl(0.14, 0.2, (0, 0, 2.38), C["iron_light"], segs=8, style="hard")
        p.cyl(0.4, 0.4, (0, 0, 0.12), HOST, segs=8, r2=0.35, style="hard")
    else:
        p.cyl(0.2, 0.9, (0, 0, 0.45), C["timber_dark"], segs=8, r2=0.17, style="hard")
        p.cyl(0.24, 0.4, (0.2, 0.1, 0.3), C["timber_grey"], segs=8, rot=(0.1, 1.2, 0.5), style="hard")
        p.cyl(0.38, 0.5, (1.0, -0.2, 0.38), C["iron"], segs=12, r2=0.2, rot=(0, math.pi / 2 - 0.15, 0.4), style="hard")
        p.ring(0.3, 0.46, 0.1, (0.72, -0.12, 0.38), C["iron_light"], segs=12, rot=(0, math.pi / 2 - 0.15, 0.4), style="hard")
        p.box((0.9, 0.25, 0.22), (-0.9, 0.3, 0.14), C["timber_dark"], rot=(0, 0, 0.5), style="hard")
        bursage(p, -0.4, -0.7, 0.0, 0.9, rng)
    cx, cy = (-0.2, -1.2) if v == "a" else (1.8, 0.9)
    for k, rad in enumerate((0.55, 0.38, 0.21)):
        p.torus(rad, 0.07, (cx, cy, 0.07 + 0.03 * k), tint(HEMP, rng, 0.06), major=10, minor=4)
    pts = [(cx + 0.55, cy, 0.07), (cx + 1.0, cy + 0.2, 0.06), (cx + 1.5, cy - 0.1, 0.06), (cx + 1.9, cy + 0.15, 0.06)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.07, HEMP, segs=6)


@K.kind("lunch_shelf", tags=["soft"], variants="ab",
        story="A pit-head shelf where the crew left their lunch pails, a mug, a folded jacket.")
def lunch_shelf(p, v, rng):
    cols = (TIN, "b8b099", "8f9a8a", TIN, "a89b7e")
    for x in (-1.05, 1.05):
        p.box((0.22, 0.28, 1.25), (x, 0.3, 0.62), C["timber_dark"], style="hard")
    p.box((2.5, 0.12, 0.7), (0, 0.4, 0.82), C["timber"], style="hard")
    if v == "a":
        p.box((2.5, 0.65, 0.12), (0, 0.05, 0.65), C["timber_pale"], style="hard")
        for k, (px, ps) in enumerate(((-1.0, 0.9), (-0.48, 1.05), (0.1, 0.8), (0.6, 0.95), (1.0, 0.85))):
            pail(p, px, 0.05 + 0.04 * (k % 2), 0.71, cols[k], rng, lid=(k in (1, 4)), s=ps)
        p.cyl(0.07, 0.1, (1.15, -0.28, 0.76), C["canvas_dark"], segs=8, style="hard")
        p.torus(0.045, 0.012, (1.22, -0.28, 0.76), C["canvas_dark"], rot=(math.pi / 2, 0, 0), major=8, minor=4)
        soft_ico(p, 0.3, (0.0, -0.1, 0.35), C["canvas"], scale=(1.5, 1.0, 0.45), rot=(0, 0, 0.3), style="soft")
        p.box((2.5, 0.5, 0.1), (0, 0.05, 0.22), C["timber_pale"], style="hard")
    else:
        p.box((1.6, 0.65, 0.12), (-0.45, 0.05, 0.65), C["timber_pale"], style="hard")
        p.box((1.3, 0.6, 0.12), (0.95, -0.1, 0.25), C["timber_grey"], rot=(0, -0.55, 0.08), style="hard")
        for k in range(3):
            pail(p, -0.9 + k * 0.5, 0.05, 0.71, cols[k], rng, lid=(k == 1), s=0.9)
        p.cyl(0.2, 0.34, (1.5, -0.9, 0.2), cols[3], segs=10, rot=(0, 1.45, 0.4), r2=0.23, style="hard")
        pail(p, 1.5, -0.3, 0.0, cols[4], rng, s=0.9)
        soft_ico(p, 0.3, (1.0, -0.8, 0.12), C["canvas_dark"], scale=(1.5, 1.0, 0.35), rot=(0, 0, 0.9), style="soft")
    sack(p, -1.5, -0.3, 0.0, 0.8, C["canvas_dark"], rng)


@K.kind("assay_bench", tags=["sign", "machine"], variants="ab",
        story="Assay bench: a big beam balance, sample jars and the ledger board left open at the last reading.")
def assay_bench(p, v, rng):
    p.box((2.4, 1.0, 0.16), (0, 0, 0.88), C["timber"], style="hard")
    legs = ((-1.0, -0.35), (1.0, -0.35), (-1.0, 0.35), (1.0, 0.35))
    for k, (x, y) in enumerate(legs):
        if v == "b" and k == 3:
            p.box((0.2, 0.2, 0.7), (x + 0.3, y + 0.9, 0.1), C["timber_dark"], rot=(1.4, 0, 0.4), style="hard")
            continue
        p.box((0.2, 0.2, 0.82), (x, y, 0.41), C["timber_dark"], style="hard")
    p.box((2.1, 0.12, 0.12), (0, -0.35, 0.3), C["timber_dark"], style="fine")
    p.cyl(0.38, 0.14, (-0.25, 0.05, 1.02), C["iron"], segs=12, style="hard")
    p.cyl(0.1, 0.62, (-0.25, 0.05, 1.38), C["iron_light"], segs=8, style="round")
    tilt = 0.0 if v == "a" else 0.18
    for sx in (-1, 1):
        ex, ez = -0.25 + sx * 0.62 * math.cos(tilt), 1.72 + sx * 0.62 * math.sin(tilt)
        p.rod((-0.25, 0.05, 1.72), (ex, 0.05, ez), 0.05, C["iron"], segs=6)
        p.rod((ex, 0.05, ez), (ex, 0.05, ez - 0.2 - (0.1 if sx * tilt > 0 else 0)), 0.03, C["iron"], segs=5)
        p.cyl(0.26, 0.05, (ex, 0.05, ez - 0.32 - (0.1 if sx * tilt > 0 else 0)), C["iron_light"], segs=12, style="hard")
    soft_ico(p, 0.1, (-0.25, 0.05, 1.74), C["iron"], style="round")
    for k in range(3):
        p.cyl(0.11, 0.2, (0.6 + k * 0.26, -0.22, 1.06), ["b8b099", "8f9a8a", "a89b7e"][k], segs=8, style="hard")
    rock(p, 0.75, 0.2, 0.96, 0.17, rng, vein=True)
    rock(p, 1.0, 0.18, 0.96, 0.13, rng)
    p.box((0.2, 0.2, 1.1), (-1.0, 0.58, 0.55), C["timber_dark"], style="hard")
    tl = 0.0 if v == "a" else 0.12
    p.box((0.95, 0.1, 0.62), (-1.0, 0.52, 1.1), C["timber_pale"], rot=(0, tl, 0), style="hard")
    p.box((0.8, 0.04, 0.48), (-1.0, 0.45, 1.1), C["canvas"], rot=(0, tl, 0), style="fine")
    for k in range(4):
        p.box((0.6 - 0.1 * (k % 2), 0.03, 0.04), (-1.0, 0.42, 1.25 - k * 0.11), C["charcoal"], rot=(0, tl, 0), style="flat")
    p.cyl(0.08, 0.12, (0.3, -0.25, 1.02), C["canvas_dark"], segs=8, style="hard")


@K.kind("ore_cart_stub", tags=["machine"], variants="abc",
        story="A stubby ore cart on a 2 m stub of track that goes nowhere.")
def ore_cart_stub(p, v, rng):
    for k in range(5):
        p.box((1.3, 0.28, 0.16), (0, -1.0 + k * 0.5, 0.08), C["timber_dark"], style="hard")
    for sx in (-0.45, 0.45):
        p.box((0.14, 2.1, 0.2), (sx, 0, 0.25), C["iron"], style="hard")
    soft_ico(p, 0.5, (0, 1.2, 0.16), C["soil"], scale=(1.6, 1.0, 0.5), style="soft")
    cx = 0.0 if v != "b" else 1.8
    cy = 0.0 if v != "b" else 0.4
    roll = 0.0 if v != "b" else 1.15
    def at(x, y, z):
        if v != "b":
            return (cx + x, cy + y, z)
        return (cx + x * math.cos(roll) - z * math.sin(roll) * 0.6, cy + y, 0.1 + z * math.cos(roll) * 0.9 + abs(x) * 0.0)

    rot = (0, roll, 0)
    body = OCHRE if v != "c" else mix(OCHRE, OXIDE, 0.35)
    p.prism([(-0.62, 0.0), (0.62, 0.0), (0.82, 0.8), (-0.82, 0.8)], 1.5, at(0, 0, 0.3), body,
            rot=(math.pi / 2, roll, 0), style="hard")
    if v != "b":
        for sx in (-0.84, 0.84):
            p.box((0.12, 1.62, 0.14), (sx, 0, 1.1), "d2c5a5", style="hard")
        for sy in (-0.76, 0.76):
            p.box((1.78, 0.12, 0.14), (0, sy, 1.1), shade(body, 0.8), style="hard")
    for sy in (-0.5, 0.5):
        for sx in (-1, 1):
            if v == "b":
                p.cyl(0.26, 0.14, (cx + sx * 0.9 * math.cos(roll), cy + sy, 0.35 + sx * 0.9 * math.sin(roll) * 0.0 + 0.05), C["iron"], segs=10,
                      rot=(0, math.pi / 2 + roll, 0), style="hard")
            else:
                p.cyl(0.26, 0.14, (cx + sx * 0.45, cy + sy, 0.35), C["iron"], segs=10, rot=(0, math.pi / 2, 0), style="hard")
    if v == "a":
        soft_ico(p, 0.8, (0, 0, 1.1), HOST, scale=(1.0, 0.9, 0.55), subdiv=1, style="hard", jit=0.05)
        rock(p, -0.2, 0.2, 1.1, 0.28, rng, vein=True)
    elif v == "b":
        soft_ico(p, 0.9, (-0.3, -1.6, 0.3), HOST_DARK, scale=(1.5, 1.2, 0.5), style="hard", jit=0.06)
        rock(p, -0.8, -2.2, 0.0, 0.35, rng, vein=True)
    else:
        soft_ico(p, 0.8, (0, 0, 1.08), C["soil"], scale=(1.0, 0.9, 0.45), subdiv=1, style="hard", jit=0.05)
        bursage(p, 0.0, -0.1, 1.05, 1.1, rng)
        bursage(p, 0.5, 0.35, 1.0, 0.8, rng, dry=True)


@K.kind("water_tank", tags=["machine"], variants="ab",
        story="Round haul-road water tank on timber cribs with a hose reel, bled dry at shift end.")
def water_tank(p, v, rng):
    tilt = 0.0 if v == "a" else 0.12
    drop = 0.0 if v == "a" else 0.35
    for k, (x, y) in enumerate(((-0.95, -0.95), (0.95, -0.95), (-0.95, 0.95), (0.95, 0.95))):
        h = 1.0 - (drop if k == 3 else 0.0)
        p.cyl(0.32, h, (x, y, h / 2), C["timber_dark"], segs=8, style="flat")
    p.box((2.4, 0.35, 0.28), (0, 0, 1.0 - drop * 0.4), C["timber"], rot=(0, tilt, 0), style="hard")
    p.box((0.35, 2.4, 0.28), (0, 0, 1.15 - drop * 0.4), C["timber"], rot=(0, tilt, 0), style="hard")
    zt = 1.35
    p.cyl(1.3, 1.0, (0, 0, zt + 0.5), shade(OCHRE, 1.05), segs=12, rot=(0, tilt, 0), style="hard")
    p.uv(1.3, (0, 0, zt + 1.0), shade(OCHRE, 1.05), scale=(1, 1, 0.35), u=12, v=4, rot=(0, tilt, 0), style="hard")
    for z in (0.15, 0.85):
        p.ring(1.28, 1.38, 0.1, (0, 0, zt + z), "b77843", segs=12, style="hard", rot=(0, tilt, 0))
    p.cyl(0.35, 0.25, (0, 0, zt + 1.42), "d2c5a5", segs=10, style="hard")
    p.cyl(0.14, 0.5, (1.3, 0, zt + 0.12), C["iron"], segs=8, rot=(0, math.pi / 2, 0), style="round")
    for k in range(3):
        p.box((0.06, 0.05, 0.9), (-1.32, 0.0, zt + 0.5 + k * 0.0), OXIDE_DARK, rot=(0, 0, k * 0.5), style="fine")
    hx, hy = 2.5, -1.0
    p.box((0.9, 0.9, 0.6), (hx, hy, 0.3), C["timber_dark"], style="hard")
    p.cyl(0.55, 0.5, (hx, hy, 0.95), C["iron"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
    for sx in (-1, 1):
        p.cyl(0.7, 0.06, (hx + sx * 0.3, hy, 0.95), "b77843", segs=12, rot=(0, math.pi / 2, 0), style="hard")
    p.cyl(0.66, 0.5, (hx, hy, 0.95), C["cable"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
    for k in range(3):
        p.torus(0.66, 0.05, (hx - 0.15 + k * 0.15, hy, 0.95), shade(C["cable"], 1.5), rot=(0, math.pi / 2, 0), major=10, minor=3, style="flat")
    pts = [(hx + 0.3, hy + 0.5, 0.1), (hx + 0.2, hy + 1.3, 0.1), (hx - 0.5, hy + 1.9, 0.1), (hx - 1.4, hy + 1.8, 0.1)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.09, C["cable"], segs=6)
    if v == "b":
        bursage(p, -2.1, 1.6, 0.0, 1.2, rng)
    pebbles(p, "water_tank_" + v, rng, 3.0)


@K.kind("bench_sign", tags=["sign"], variants="ab",
        story="Painted BENCH 3 board on a stout post; benches were numbered down the wall.")
def bench_sign(p, v, rng):
    def numeral(cx, cz, rot_back=0.0):
        t, w = 0.08, 0.28
        for dz in (-0.3, 0.0, 0.3):
            p.box((w, 0.05, t), (cx, -0.13, cz + dz), C["canvas"], style="fine")
        for dz in (-0.15, 0.15):
            p.box((t, 0.05, 0.3), (cx + w / 2 - t / 2, -0.13, cz + dz), C["canvas"], style="fine")
    if v == "a":
        p.box((0.28, 0.28, 0.8), (0, 0.15, 0.4), C["timber_dark"], style="hard")
        p.box((1.9, 0.16, 0.95), (0, 0.0, 0.95), C["timber_dark"], style="hard")
        p.box((1.75, 0.04, 0.8), (0, -0.1, 0.95), HOST_DARK, style="hard")
        for k in range(5):
            p.box((0.1, 0.03, 0.22), (-0.78 + k * 0.17, -0.13, 1.1), C["canvas"], style="fine")
        numeral(0.45, 0.95)
        p.cyl(0.4, 0.3, (0.55, 0.15, 0.15), HOST, segs=8, r2=0.35, style="hard")
        for rx, ry, rr in ((-0.8, 0.5, 0.25), (0.9, 0.4, 0.2)):
            rock(p, rx, ry, 0.0, rr, rng)
    else:
        p.box((1.9, 0.9, 0.16), (0, 0, 0.1), C["timber_dark"], rot=(0.0, 0.05, 0.2), style="hard")
        p.box((1.75, 0.8, 0.04), (0, 0, 0.2), HOST_DARK, rot=(0.0, 0.05, 0.2), style="hard")
        for k in range(5):
            p.box((0.1, 0.2, 0.03), (-0.6 + k * 0.17, -0.1 + k * 0.03, 0.23), C["canvas"], style="fine")
        p.box((0.25, 0.25, 0.5), (1.5, 0.7, 0.18), C["timber_dark"], rot=(0.2, 1.1, 0.4), style="hard")
        soft_ico(p, 0.3, (-0.9, 0.6, 0.15), TAILS, scale=(1.4, 1.0, 0.5), style="soft")
        rock(p, 0.9, -0.7, 0.0, 0.3, rng, vein=True)
        bursage(p, -1.3, -0.6, 0.0, 0.7, rng, dry=True)


@K.kind("timber_lagging", tags=["soft"], variants="abc",
        story="Lagging planks and short props left in a low heap beside the bench, ready for a shoring job.")
def timber_lagging(p, v, rng):
    n = {"a": 7, "b": 9, "c": 8}[v]
    for k in range(n):
        if v == "a":
            row, col = k // 4, k % 4
            p.box((2.4, 0.3, 0.16), (0.1 * ((k * 7) % 3 - 1), -0.5 + col * 0.34, 0.08 + row * 0.16), tint(C["timber_grey"], rng, 0.1),
                  rot=(0, 0, rng.uniform(-0.05, 0.05)), style="hard")
        else:
            ang = rng.uniform(-0.7, 0.7)
            p.box((rng.uniform(1.8, 2.5), 0.34, 0.16), (rng.uniform(-0.6, 0.6), rng.uniform(-0.8, 0.8), 0.08 + 0.14 * (k % 3)),
                  tint(C["timber_grey"] if k % 2 else C["timber_pale"], rng, 0.1),
                  rot=(rng.uniform(-0.05, 0.05), rng.uniform(-0.06, 0.06), ang), style="hard")
    for k in range(3):
        a = 0.3 + k * 0.5 + (0.4 if v != "a" else 0.0)
        p.cyl(0.14, 1.6, (1.4 - 0.2 * k, -1.0 + k * 0.4 + (0.2 if v != "a" else 0), 0.16), tint(C["timber_dark"], rng), segs=8,
              rot=(0, math.pi / 2, a), style="hard")
    if v == "c":
        bursage(p, 0.1, 0.1, 0.4, 1.3, rng)
        bursage(p, -0.8, -0.7, 0.0, 0.9, rng, dry=True)
    elif v == "a":
        sack(p, -1.5, 0.9, 0.0, 0.9, C["canvas_dark"], rng)
    else:
        p.cyl(0.15, 1.3, (-1.5, 1.0, 0.15), C["timber_dark"], segs=8, rot=(0, math.pi / 2, -0.5), style="hard")
    pebbles(p, "timber_lagging_" + v, rng, 1.8)


@K.kind("windsock", tags=["tall", "sign"], variants="ab", line_clear_m=30,
        story="Haul-road windsock on a stout mast, the sock held out stiff in a steady wind.")
def windsock(p, v, rng):
    if v == "a":
        p.cyl(0.38, 0.5, (0, 0, 0.25), HOST, segs=8, r2=0.34, style="hard")
        p.cyl(0.14, 2.6, (0, 0, 1.55), C["iron"], segs=8, r2=0.1, style="hard")
        p.cyl(0.2, 0.16, (0, 0, 2.7), C["iron_light"], segs=8, style="hard")
        p.box((1.2, 0.14, 0.14), (0.5, 0, 2.7), C["iron"], style="hard")
        p.torus(0.34, 0.035, (1.15, 0, 2.7), C["iron"], rot=(0, math.pi / 2, 0), major=10, minor=4)
        for k, col in enumerate((C["canvas"], C["charcoal"], C["canvas"], C["sandstone"], C["canvas"])):
            r1 = 0.33 - k * 0.045
            p.cyl(r1, 0.3, (1.3 + k * 0.3, 0, 2.7), col, segs=10, r2=r1 - 0.045, rot=(0, math.pi / 2, 0), style="hard")
        for rx, ry, rr in ((-0.6, 0.5, 0.25), (0.5, -0.5, 0.2)):
            rock(p, rx, ry, 0.0, rr, rng)
    else:
        p.cyl(0.38, 0.5, (0, 0, 0.25), HOST, segs=8, r2=0.34, style="hard")
        p.cyl(0.14, 1.2, (0, 0, 0.9), C["iron"], segs=8, r2=0.12, style="hard")
        p.cyl(0.13, 2.0, (1.3, -0.6, 0.15), C["iron"], segs=8, r2=0.1, rot=(0, math.pi / 2, 0.45), style="hard")
        for k, col in enumerate((C["canvas"], C["charcoal"], C["canvas"], C["sandstone"], C["canvas"])):
            r1 = 0.2 - k * 0.025
            p.cyl(r1, 0.22, (2.3 + k * 0.2, -0.8 + k * 0.05, 0.2), col, segs=10, r2=r1 - 0.025, rot=(0, math.pi / 2, 0.2), style="hard")
        bursage(p, 0.5, 0.8, 0.0, 0.9, rng, dry=True)


@K.kind("rock_bucket", tags=["plant"], variants="ab",
        story="A broken shovel bucket and its tooth left in the dirt, cholla growing up through the lip.")
def rock_bucket(p, v, rng):
    soft_ico(p, 1.0, (0, 0, 0.1), C["soil"], scale=(1.8, 1.4, 0.3), style="soft")
    if v == "a":
        p.cyl(0.8, 1.7, (0, 0, 0.55), shade(OCHRE, 0.95), segs=14, rot=(0, math.pi / 2, 0), style="hard")
        p.cyl(0.62, 1.74, (0, 0, 0.6), C["soil"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
        p.box((1.9, 0.3, 0.3), (0, -0.78, 0.38), C["iron"], style="hard")
        for k in range(3):
            p.cyl(0.18, 0.5, (-0.6 + k * 0.6, -0.95, 0.35), C["iron_light"], segs=6, r2=0.07, rot=(math.pi / 2 + 0.1, 0, 0), style="hard")
        cholla(p, 0.2, 0.1, 0.8, 1.0, rng, arms=2)
        cholla(p, -0.5, 0.7, 0.0, 0.7, rng, arms=1)
    else:
        p.cyl(0.22, 0.9, (0.0, 0, 0.3), C["iron_light"], segs=6, r2=0.08, rot=(0, math.pi / 2 - 0.2, 0.5), style="hard")
        p.box((0.5, 0.3, 0.35), (-0.5, 0.2, 0.2), C["iron"], rot=(0, 0, 0.5), style="hard")
        rock(p, 0.7, -0.5, 0.0, 0.3, rng, vein=True)
        rock(p, -0.9, -0.5, 0.0, 0.22, rng)
        cholla(p, 0.4, 0.6, 0.0, 1.0, rng, arms=1)
        cholla(p, -0.2, -0.8, 0.0, 0.5, rng, arms=0)


@K.kind("core_trays", tags=["soft"], variants="ab",
        story="Drill-core trays on low trestles; the grey-green cores carry thin copper-carbonate veins.")
def core_trays(p, v, rng):
    p.box((2.9, 2.5, 0.2), (0.2, 0.1, 0.1), C["soil"], rot=(0, 0, 0.2), style="flat")
    def core_row(cx, cy, cz, rot_z=0.0, count=7, sc=1.0):
        for k in range(count):
            vein = k % 3 == 1
            xk = cx + (k - count / 2) * 0.26 * sc * math.cos(rot_z)
            yk = cy + (k - count / 2) * 0.26 * sc * math.sin(rot_z)
            p.cyl(0.07, 0.56, (xk, yk, cz), HOST, segs=8,
                  rot=(math.pi / 2, 0, rot_z), style="hard")
            if vein:
                p.box((0.04, 0.2, 0.025), (xk, yk, cz + 0.065), VEIN, rot=(0, 0, rot_z), style="flat")

    if v == "a":
        for tx in (-0.9, 0.9):
            p.box((0.3, 1.7, 0.1), (tx, 0, 0.7), C["timber_dark"], style="hard")
            for sy in (-0.6, 0.6):
                p.box((0.18, 0.18, 0.7), (tx, sy, 0.35), C["timber_dark"], style="hard")
        for k, ty in enumerate((-0.55, 0.0, 0.55)):
            p.box((2.3, 0.45, 0.07), (0, ty, 0.8), C["timber_pale"], style="hard")
            p.box((2.3, 0.04, 0.12), (0, ty - 0.22, 0.85), C["timber_dark"], style="fine")
            p.box((2.3, 0.04, 0.12), (0, ty + 0.22, 0.85), C["timber_dark"], style="fine")
            for j in range(8):
                p.cyl(0.075, 0.38, (-0.95 + j * 0.27, ty, 0.9), tint(HOST, rng, 0.08), segs=8, rot=(math.pi / 2, 0, 0), style="hard")
                if (j + k) % 3 == 1:
                    p.box((0.03, 0.2, 0.025), (-0.95 + j * 0.27, ty, 0.975), VEIN, style="flat")
    else:
        p.box((2.2, 0.5, 0.07), (0, -0.2, 0.1), C["timber_pale"], rot=(0, 0.08, 0.1), style="hard")
        p.box((2.0, 0.5, 0.07), (0.3, 0.7, 0.16), C["timber_grey"], rot=(0, -0.12, -0.2), style="hard")
        p.box((0.3, 1.7, 0.1), (-1.0, 0.2, 0.55), C["timber_dark"], rot=(0.4, 0.1, 0), style="hard")
        for j in range(8):
            p.cyl(0.075, 0.38, (-0.9 + j * 0.27, -0.2, 0.22), tint(HOST, rng, 0.08), segs=8, rot=(math.pi / 2, 0, 0.1), style="hard")
        for j in range(6):
            p.cyl(0.075, 0.38, (-0.2 + j * 0.3 + rng.uniform(-0.1, 0.1), -1.0 + rng.uniform(-0.1, 0.3), 0.09),
                  tint(HOST_DARK, rng, 0.08), segs=8, rot=(math.pi / 2, 0, rng.uniform(0, 3)), style="hard")
            if j % 2:
                p.box((0.03, 0.2, 0.025), (-0.2 + j * 0.3, -1.0, 0.17), VEIN, style="flat")
        bursage(p, 1.5, 0.9, 0.0, 0.9, rng)
    pebbles(p, "core_trays_" + v, rng, 1.6)


@K.kind("bursage", tags=["plant"], variants="abc",
        story="Bursage and brittle desert scrub taking back the bench, greying with the season.")
def bursage_kind(p, v, rng):
    p.cyl(0.7, 0.22, (0, 0, 0.11), C["soil"], segs=8, r2=0.55, style="hard")
    if v == "a":
        bursage(p, 0, 0, 0.0, 1.5, rng, lean=True)
        bursage(p, 0.7, 0.5, 0.0, 1.0, rng, lean=True)
        bursage(p, -0.6, 0.6, 0.0, 0.9, rng, lean=True)
    elif v == "b":
        bursage(p, 0, 0, 0.0, 1.6, rng, dry=True, lean=True)
        bursage(p, -0.7, -0.4, 0.0, 1.1, rng, lean=True)
        for k in range(3):
            p.rod((0.0, 0.0, 0.2), (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.1 + 0.1 * k), 0.015, "b0a674", segs=5)
    else:
        bursage(p, 0, 0, 0.0, 1.0, rng, dry=True, lean=True)
        bursage(p, 0.8, -0.3, 0.0, 1.2, rng, lean=True)
        bursage(p, -0.7, 0.5, 0.0, 0.8, rng, lean=True)
        rock(p, 0.2, 0.9, 0.0, 0.3, rng, vein=True)


@K.kind("cholla", tags=["plant"], variants="abc",
        story="Cholla, jointed and fuzzy, standing in cluster or fallen in a mat of dropped joints.")
def cholla_kind(p, v, rng):
    if v == "a":
        cholla(p, 0, 0, 0.0, 1.5, rng, arms=2, lean=True)
    elif v == "b":
        cholla(p, -0.4, 0, 0.0, 1.3, rng, arms=1, lean=True)
        cholla(p, 0.5, 0.3, 0.0, 1.0, rng, arms=2, lean=True)
        cholla(p, 0.1, -0.6, 0.0, 0.8, rng, arms=0, lean=True)
    else:
        for k in range(4):
            a = rng.uniform(0, 3)
            x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
            p.cyl(0.1, 0.5, (x, y, 0.1), "8c9a72", segs=6, rot=(0, math.pi / 2, a), style="hard")
            soft_ico(p, 0.11, (x + math.cos(a) * 0.27, y - math.sin(a) * 0.27, 0.1), "a9ae88", scale=(1, 1, 0.8), style="flat", subdiv=2)
        cholla(p, 0.0, 0.0, 0.0, 0.9, rng, arms=1, lean=True)
        rock(p, 0.7, 0.5, 0.0, 0.25, rng)

P = {
    "ochre": "b98a4a", "ochre_dark": "8f6a3c", "oxide": "9a6448", "host": "7f8670",
    "host_dark": "5f6656", "streak": "4f8a7c", "tin": "a3a59c", "tin_dark": "7c7f78",
    "hat": "6f8f9a", "denim": "4d5f72", "char": "2e2a26", "ash": "8a857a",
}


def ore_lump(p, rng, at, r, color, squash=0.6, style="flat"):
    p.ico(r, at, tint(color, rng, 0.06), subdiv=2, scale=(1.0 + rng.uniform(-0.15, 0.2), 1.0 + rng.uniform(-0.15, 0.2), squash),
          rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.tau)), style=style, jit=r * 0.06)


@K.kind("ore_car", hero=True, tags=["machine"], variants="ab", polish_opts={"detail": 2},
        story="A side-dump ore car that jumped its stub of track on the last haul and spilled across the bench.")
def ore_car(p, v, rng):
    tipped = v == "a"
    for i in range(5):
        x = -2.2 + i * 1.05
        p.box((0.3, 2.0, 0.16), (x, 0, 0.08), tint(C["timber_dark"], rng, 0.06), rot=(0, 0, rng.uniform(-0.08, 0.08)), jit=0.01)
    for y in (-0.6, 0.6):
        p.box((4.2, 0.12, 0.14), (-0.2, y, 0.23), C["rust"], style="hard_smooth")
    car = []
    bed = [(-0.95, 0.75), (0.95, 0.75), (0.45, -0.55), (-0.45, -0.55)]
    car += p.prism(bed, 2.6, (0, 0, 1.55), mix(C["iron"], C["rust"], 0.35), rot=(math.pi / 2, 0, math.pi / 2), style="hard_smooth")
    car += p.prism([(x * 0.84, y * 0.84 + 0.08) for x, y in bed], 2.64, (0, 0, 1.6), C["charcoal"], rot=(math.pi / 2, 0, math.pi / 2), style="hard")
    for x in (-1.32, 1.32):
        car += p.box((0.16, 2.0, 0.22), (x, 0, 2.27), C["iron_light"], style="hard_smooth")
    car += p.box((2.8, 1.1, 0.24), (0, 0, 0.8), C["iron"], style="hard_smooth")
    car += p.box((0.4, 0.22, 0.22), (-1.55, 0, 0.8), C["iron"])
    car += p.box((0.5, 0.04, 0.32), (0, -0.88, 1.7), C["bone"], style="fine")
    for x in (-0.9, 0.9):
        for y in (-0.62, 0.62):
            if not tipped and x > 0 and y > 0:
                continue
            car += p.cyl(0.36, 0.13, (x, y, 0.58), mix(C["iron"], C["charcoal"], 0.4), segs=16, rot=(math.pi / 2, 0, 0), style="hard_smooth")
            car += p.cyl(0.13, 0.2, (x, y, 0.58), C["iron_light"], segs=8, rot=(math.pi / 2, 0, 0), style="round")
    if tipped:
        m = Matrix.Translation((0.25, -1.3, 0.0)) @ Matrix.Rotation(0.2, 4, "Z") @ Matrix.Rotation(-math.radians(80), 4, "X") \
            @ Matrix.Translation((0, 0.75, -0.2))
        verts = {vv for f in car for vv in f.verts}
        for vert in verts:
            vert.co = m @ vert.co
        lift = -min(vert.co.z for vert in verts) - 0.02
        for vert in verts:
            vert.co.z += lift
        p.box((0.5, 0.7, 0.5), (-1.3, 0.1, 0.25), C["timber_dark"], rot=(0.0, 0.1, 0.4))
    else:
        p.cyl(0.36, 0.13, (1.6, 1.4, 0.07), mix(C["iron"], C["charcoal"], 0.4), segs=16, rot=(0.04, 0, 0.6), style="hard_smooth")
        p.cyl(0.13, 0.2, (1.6, 1.4, 0.1), C["iron_light"], segs=8, rot=(0.04, 0, 0.6), style="round")
        p.box((0.5, 0.8, 0.5), (0.95, 0.62, 0.45), C["timber_dark"], rot=(0.0, 0.1, 0.2))
        p.ico(0.95, (0.0, 0.0, 2.35), C["canvas_dark"], scale=(1.4, 0.8, 0.22), rot=(0.05, 0.1, 0.02), style="round")
        for k in range(6):
            ore_lump(p, rng, (rng.uniform(-1.0, 1.0), rng.uniform(-0.5, 0.5), 2.25), rng.uniform(0.18, 0.3),
                 rng.choice([P["ochre"], P["oxide"], P["host"]]))
        p.chain((-1.75, 0, 0.8), (-2.9, 0.4, 0.06), C["cable"], link=0.14, radius=0.024, sag=0.25, style="flat")
    n = 26 if tipped else 12
    cx, cy = (0.6, -2.4) if tipped else (1.4, -1.6)
    for k in range(n):
        a = rng.uniform(-1.1, 1.1) - math.pi / 2
        d = rng.uniform(0.2, 1.0) ** 0.7 * (3.0 if tipped else 1.4)
        x, y = cx + d * math.cos(a) * 1.3, cy + d * math.sin(a)
        r = rng.uniform(0.18, 0.42) * (1.0 - 0.35 * d / 3.0)
        col = rng.choice([P["ochre"], P["ochre"], P["oxide"], P["host"], P["host_dark"]])
        ore_lump(p, rng, (x, y, r * 0.45), r, col)
        if k % 6 == 0:
            p.ico(r * 0.45, (x + r * 0.3, y, r * 0.75), P["streak"], scale=(1.3, 0.5, 0.35), subdiv=2, style="flat")
    p.rod((cx + 1.2, cy - 1.4, 0.2), (cx + 1.45, cy - 1.0, 1.35), 0.04, C["timber"], segs=6)
    p.box((0.3, 0.06, 0.38), (cx + 1.15, cy - 1.46, 0.12), C["iron"], rot=(0.4, 0.2, 0.9), style="hard_smooth")


@K.kind("change_house", hero=True, tags=["tall"], variants="ab", polish_opts={"detail": 2},
        story="The shift change shack: tin walls, a bench out front, hard hats still on the pegs for a shift that never came.")
def change_house(p, v, rng):
    blown = v == "b"
    w, d, h = 4.2, 3.0, 2.5
    for y in (-1.2, 0, 1.2):
        p.box((w + 0.6, 0.24, 0.26), (0, y, 0.13), C["timber_dark"])
    p.box((w, d, 0.12), (0, 0, 0.32), tint(C["timber_grey"], rng, 0.04))
    def wall(cx, cy, length, along_x, skip=()):
        n = int(length / 0.26)
        for i in range(n):
            if i in skip:
                continue
            o = -length / 2 + (i + 0.5) * length / n
            col = P["tin"] if i % 2 else P["tin_dark"]
            if rng.random() < 0.12:
                col = mix(col, C["rust"], 0.5)
            loc = (cx + o, cy, 0.38 + h / 2) if along_x else (cx, cy + o, 0.38 + h / 2)
            size = (length / n + 0.01, 0.06, h) if along_x else (0.06, length / n + 0.01, h)
            p.box(size, loc, col, style="fine")
    door = range(9, 13)
    wall(0, -d / 2, w, True, skip=door)
    wall(0, d / 2, w, True)
    wall(-w / 2, 0, d, False)
    wall(w / 2, 0, d, False, skip=(range(4, 7) if blown else ()))
    p.box((0.9, 0.06, 2.1), (0.95, -d / 2 - 0.4, 1.45), C["timber_pale"], rot=(0, 0, 1.0 if not blown else 1.35))
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            p.beam((x, y, 0.38), (x, y, 0.38 + h), 0.14, C["timber_dark"])
    roof_z = 0.38 + h
    sheets = 9
    for i in range(sheets):
        if blown and i >= 5:
            continue
        x = -w / 2 - 0.2 + (i + 0.5) * (w + 0.4) / sheets
        p.box(((w + 0.4) / sheets + 0.02, d + 0.6, 0.06), (x, 0, roof_z + 0.18 - x * 0.04),
              tint(P["tin"] if i % 2 else P["tin_dark"], rng, 0.05), rot=(0, 0.04, 0), style="fine")
    if blown:
        p.box((1.9, 1.0, 0.06), (w / 2 + 1.5, 1.1, 0.25), P["tin_dark"], rot=(0.15, 0.25, 0.5), style="fine")
        p.box((1.7, 1.0, 0.06), (w / 2 + 1.0, -1.6, 0.12), P["tin"], rot=(0, 0.05, -0.3), style="fine")
        p.box((1.5, 0.9, 0.06), (w / 2 + 0.2, 0.3, roof_z + 0.45), P["tin"], rot=(0.5, -0.7, 0.2), style="fine")
        for k in range(6):
            p.beam((0.2 + k * 0.38, -d / 2, roof_z), (0.2 + k * 0.38, d / 2, roof_z), 0.1, C["timber_dark"])
    for k in range(5):
        x = -1.7 + k * 0.42
        p.cyl(0.03, 0.18, (x, -d / 2 - 0.1, 2.05), C["timber_dark"], segs=6, rot=(math.pi / 2, 0, 0))
        if k != 2:
            col = P["hat"] if k % 2 else C["bone"]
            p.uv(0.17, (x, -d / 2 - 0.2, 2.08), col, scale=(1.0, 1.0, 0.7), u=10, v=6, style="round")
            p.cyl(0.21, 0.03, (x, -d / 2 - 0.2, 1.98), col, segs=12, style="round")
    p.ico(0.32, (-0.85, -d / 2 - 0.16, 1.55), P["denim"], scale=(0.9, 0.35, 1.5), style="round")
    p.box((2.6, 0.45, 0.08), (-0.6, -d / 2 - 0.85, 0.55), tint(C["timber"], rng))
    for x in (-1.7, 0.5):
        p.box((0.1, 0.4, 0.5), (x, -d / 2 - 0.85, 0.27), C["timber_dark"])
    p.cyl(0.16, 0.22, (-1.2, -d / 2 - 0.85, 0.7), P["tin_dark"], segs=12, style="round")
    p.torus(0.12, 0.015, (-1.2, -d / 2 - 0.85, 0.86), C["iron"], rot=(math.pi / 2, 0, 0), major=10, minor=4)
    p.cyl(0.07, 0.34, (-0.3, -d / 2 - 0.85, 0.76), C["verdigris"], segs=10, style="round")
    p.ico(0.25, (w / 2 + 0.18, -d / 2 + 0.3, 1.7), C["canvas"], scale=(0.8, 0.7, 1.2), style="round")
    for k in range(2):
        p.ico(0.13, (0.55 + k * 0.22, -d / 2 - 0.45, 0.42), C["soil"], scale=(1.0, 2.0, 1.1), style="round")


@K.kind("drill_rig", hero=True, tags=["machine"], variants="ab", polish_opts={"detail": 2},
        story="The blast-hole drill, mast laid down for the move that never happened; crawler tracks caked in bench dust.")
def drill_rig(p, v, rng):
    snapped = v == "b"
    for y in (-1.15, 1.15):
        p.box((4.4, 0.7, 0.75), (0, y, 0.42), C["charcoal"], style="hard_smooth")
        for i in range(14):
            x = -2.15 + i * 0.33
            p.box((0.24, 0.78, 0.08), (x, y, 0.82), P["host_dark"], style="fine")
            p.box((0.24, 0.78, 0.08), (x, y, 0.03), P["host_dark"], style="fine")
        for x in (-1.6, -0.8, 0, 0.8, 1.6):
            p.cyl(0.26, 0.12, (x, y + (0.4 if y > 0 else -0.4), 0.42), C["iron_light"], segs=12, rot=(math.pi / 2, 0, 0), style="round")
        for x in (-2.1, 2.1):
            p.cyl(0.38, 0.72, (x, y, 0.42), C["iron"], segs=14, rot=(math.pi / 2, 0, 0), style="round")
    p.box((4.0, 3.2, 0.3), (0, 0, 1.0), mix(C["iron"], C["rust"], 0.25), style="hard_smooth")
    p.box((1.8, 2.4, 1.3), (-1.0, 0, 1.8), tint(P["tin_dark"], rng, 0.04), style="hard_smooth")
    for i in range(6):
        p.box((0.06, 1.6, 0.9), (-1.92, -0.8 + i * 0.32, 1.8), C["charcoal"], style="fine")
    p.cyl(0.12, 1.1, (-0.4, 0.8, 2.9), C["charcoal"], segs=10, style="round")
    p.box((1.3, 1.4, 1.6), (1.05, -0.75, 1.95), P["tin"], style="hard_smooth")
    p.box((1.32, 1.0, 0.7), (1.05, -0.85, 2.25), P["host_dark"], style="hard")
    p.box((1.5, 1.6, 0.12), (1.05, -0.75, 2.8), P["tin_dark"], style="hard_smooth")
    length = 7.5
    def lattice(a, b, size):
        ax, ay, az = a
        bx, by, bz = b
        for oy in (-size / 2, size / 2):
            for oz in (-size / 2, size / 2):
                p.beam((ax, ay + oy, az + oz), (bx, by + oy, bz + oz), 0.12, mix(C["iron"], C["rust"], 0.2))
        n = max(2, int(math.dist(a, b) / 0.7))
        for k in range(n):
            t0, t1 = k / n, (k + 1) / n
            pa = tuple(a[i] + (b[i] - a[i]) * t0 for i in range(3))
            pb = tuple(a[i] + (b[i] - a[i]) * t1 for i in range(3))
            s = -1 if k % 2 else 1
            p.rod((pa[0], pa[1] - size / 2 * s, pa[2] + size / 2), (pb[0], pb[1] + size / 2 * s, pb[2] + size / 2), 0.04, C["iron_light"], segs=5)
            p.rod((pa[0], pa[1] - size / 2 * s, pa[2] - size / 2), (pb[0], pb[1] + size / 2 * s, pb[2] - size / 2), 0.04, C["iron_light"], segs=5)
    p.box((0.5, 1.0, 0.7), (2.0, 0, 1.5), C["timber_dark"])
    if snapped:
        lattice((-1.8, 0.2, 1.8), (2.2, 0.2, 1.95), 0.55)
        lattice((2.6, 0.5, 1.6), (5.6, 1.4, 0.32), 0.55)
        p.ico(0.5, (2.4, 0.35, 1.75), P["oxide"], scale=(1.0, 1.0, 0.6), style="round")
    else:
        lattice((-1.8, 0.2, 1.8), (-1.8 + length, 0.2, 2.1), 0.55)
        p.box((0.9, 1.1, 2.1), (-1.8 + length - 0.3, 0.2, 1.05), C["timber_dark"])
    p.rod((-2.5, -2.2, 0.08), (2.0, -2.0, 0.08), 0.07, C["iron_light"], segs=8)
    p.cyl(0.18, 0.3, (2.15, -2.0, 0.16), C["iron"], segs=10, rot=(0, math.pi / 2, 0.04), style="hard_smooth")
    for k in range(3):
        p.torus(0.42 - k * 0.05, 0.05, (0.2, 0.9, 1.22 + k * 0.08), C["cable"], major=14, minor=5)


@K.kind("core_rack", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Drill cores laid across two sawhorses for the geologist who never came back up to log them.")
def core_rack(p, v, rng):
    for x in (-0.9, 0.9):
        for s in (-1, 1):
            p.rod((x - 0.18 * s, -0.3, 0.0), (x, 0, 0.72), 0.04, C["timber"], segs=5)
            p.rod((x - 0.18 * s, 0.3, 0.0), (x, 0, 0.72), 0.04, C["timber"], segs=5)
        p.box((0.12, 1.0, 0.08), (x, 0, 0.74), C["timber_dark"])
    p.box((2.4, 1.0, 0.04), (0, 0, 0.8), C["timber_pale"], style="fine")
    rows = 4 if v == "a" else 3
    for r in range(rows):
        y = -0.36 + r * 0.24
        x = -1.1
        while x < 1.0:
            seg = rng.uniform(0.25, 0.55)
            col = rng.choice([P["host"], P["ochre"], P["oxide"], P["host_dark"], P["streak"]])
            p.cyl(0.05, seg - 0.02, (x + seg / 2, y, 0.87), col, segs=8, rot=(0, math.pi / 2, 0), style="round")
            x += seg
    if v == "b":
        for k in range(4):
            p.cyl(0.05, rng.uniform(0.3, 0.5), (rng.uniform(-0.9, 0.9), 0.7 + rng.uniform(0, 0.3), 0.05), rng.choice([P["host"], P["ochre"]]),
                  segs=8, rot=(0, math.pi / 2, rng.uniform(-0.6, 0.6)), style="round")
        p.box((0.7, 0.04, 0.5), (1.3, 0.1, 0.3), C["charcoal"], rot=(0.2, 0, 0.3), style="fine")


@K.kind("ore_heap", tags=["soft"], variants="abc", polish_opts={"detail": 1},
        story="Grab samples heaped by the shovel crew: ochre and rust oxide, grey-green host rock, a streak of copper green.")
def ore_heap(p, v, rng):
    big = {"a": 1.0, "b": 0.7, "c": 1.25}[v]
    R, H = 1.15 * big, 0.5 * big
    p.ico(R, (0, 0, 0.0), tint(P["ochre_dark"], rng, 0.05), scale=(1.3, 1.0, H / R), subdiv=2, style="flat", jit=0.06)

    def surface(x, y):
        return H * math.sqrt(max(0.0, 1.0 - (x / (1.3 * R)) ** 2 - (y / R) ** 2))
    n = {"a": 16, "b": 10, "c": 20}[v]
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.1, 1.05) * R
        x, y = math.cos(a) * d * 1.3, math.sin(a) * d
        r = rng.uniform(0.2, 0.36) * big
        col = rng.choice([P["ochre"], P["oxide"], P["host"], P["host_dark"], P["oxide"]])
        ore_lump(p, rng, (x, y, surface(x, y) + r * 0.25), r, col)
    for k in range(2 if v != "b" else 1):
        a = rng.uniform(0, math.tau)
        x, y = math.cos(a) * 0.5 * big, math.sin(a) * 0.4 * big
        p.ico(0.24 * big, (x, y, surface(x, y) + 0.06), P["streak"], scale=(1.4, 0.6, 0.4), subdiv=2, style="flat")
    if v == "c":
        p.rod((1.9, 0.5, 0.0), (1.9, 0.55, 0.9), 0.025, C["timber_pale"], segs=5)
        p.box((0.22, 0.02, 0.14), (1.9, 0.52, 0.8), C["bone"], style="fine")


@K.kind("lagging_stack", tags=[], variants="ab", polish_opts={"detail": 1},
        story="Mine lagging cribbed in a square stack to dry; the top courses slid when the bench shook.")
def lagging_stack(p, v, rng):
    layers = 6 if v == "a" else 4
    for L in range(layers):
        along_x = L % 2 == 0
        z = 0.1 + L * 0.2
        slip = 0.0 if L < layers - 2 or v == "a" else rng.uniform(0.2, 0.5)
        for k in range(4):
            o = -0.75 + k * 0.5
            if along_x:
                p.box((2.0, 0.2, 0.2), (slip, o, z), tint(C["timber"], rng, 0.08), rot=(0, 0, rng.uniform(-0.04, 0.04)), jit=0.005)
            else:
                p.box((0.2, 2.0, 0.2), (o, slip, z), tint(C["timber_grey"], rng, 0.08), rot=(0, 0, rng.uniform(-0.04, 0.04)), jit=0.005)
    if v == "b":
        for k in range(3):
            p.box((2.0, 0.2, 0.2), (1.3 + k * 0.1, -0.6 + k * 0.5, 0.1), tint(C["timber"], rng), rot=(0, 0.05, 0.4 + k * 0.3))
    p.ico(0.3, (-1.0, 1.0, 0.15), C["canvas_dark"], scale=(1.0, 0.7, 0.5), style="round")


@K.kind("hose_coil", tags=["machine"], variants="ab", polish_opts={"detail": 1},
        story="A driller's air hose coiled down by habit, and the jackhammer dropped beside it at the whistle.")
def hose_coil(p, v, rng):
    for k in range(5 if v == "a" else 3):
        p.torus(0.55 - k * 0.04, 0.06, (0, 0, 0.06 + k * 0.1), C["cable"], rot=(rng.uniform(-0.05, 0.05), 0, 0), major=18, minor=6, style="flat")
    pts = [(0.5, 0.1, 0.06), (0.95, 0.35, 0.06), (1.25, 0.15, 0.06), (1.55, 0.3, 0.06)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.06, C["cable"], segs=6, style="flat")
    hx, hy = 1.95, 0.3
    ang = 0.1 if v == "a" else 0.6
    p.cyl(0.16, 0.7, (hx, hy, 0.17), C["iron"], segs=10, rot=(0, math.pi / 2, ang), style="hard_smooth")
    p.box((0.12, 0.55, 0.12), (hx - 0.42, hy, 0.17), C["charcoal"], rot=(0, 0, ang))
    p.cyl(0.05, 0.5, (hx + 0.6 * math.cos(ang), hy + 0.6 * math.sin(ang), 0.12), C["iron_light"], segs=6, rot=(0, math.pi / 2, ang))
    if v == "b":
        p.uv(0.17, (-0.1, -0.85, 0.12), P["hat"], scale=(1.0, 1.0, 0.65), u=10, v=6, style="round")
        p.cyl(0.21, 0.03, (-0.1, -0.85, 0.02), P["hat"], segs=12, style="round")


@K.kind("blast_mat", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="A woven blasting mat dragged off the last shot and left slumped over the rubble it was meant to hold down.")
def blast_mat(p, v, rng):
    for k in range(5):
        ore_lump(p, rng, (rng.uniform(-1.0, 1.0), rng.uniform(-0.6, 0.6), 0.15), rng.uniform(0.25, 0.4), P["host_dark"])
    def h(x, y):
        return 0.38 + 0.18 * math.cos(x * 1.7 + (0.4 if v == "b" else 0)) * math.cos(y * 2.1) - 0.08 * (x * x + y * y)
    n = 5
    for i in range(n):
        y = -0.75 + i * 1.5 / (n - 1)
        pts = [(-1.3 + j * 0.433, y, max(0.05, h(-1.3 + j * 0.433, y))) for j in range(7)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.055, C["charcoal"], segs=5, style="flat")
    for j in range(7):
        x = -1.3 + j * 0.433
        pts = [(x, -0.75 + i * 1.5 / (n - 1), max(0.05, h(x, -0.75 + i * 1.5 / (n - 1))) + 0.04) for i in range(n)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.045, P["char"], segs=5, style="flat")
    if v == "a":
        p.chain((1.3, 0.0, 0.25), (2.0, 0.6, 0.04), C["cable"], link=0.14, radius=0.022, sag=0.1, style="flat")
    else:
        p.ico(0.32, (-1.5, 0.7, 0.15), C["canvas"], scale=(1.0, 0.7, 0.45), style="round")


@K.kind("tool_drop", tags=[], variants="abc", polish_opts={"detail": 1},
        story="Pick, shovel and sledge where the bench crew set them down at noon, a lunch pail between them.")
def tool_drop(p, v, rng):
    a = {"a": 0.2, "b": 1.2, "c": -0.4}[v]
    ca, sa = math.cos(a), math.sin(a)
    p.rod((-0.6 * ca, -0.6 * sa, 0.05), (0.4 * ca, 0.4 * sa, 0.05), 0.035, C["timber"], segs=6)
    p.rod((0.45 * ca - 0.35 * sa, 0.45 * sa + 0.35 * ca, 0.06), (0.45 * ca + 0.35 * sa, 0.45 * sa - 0.35 * ca, 0.06), 0.045, C["iron"], segs=6, r2=0.012)
    b = a + 1.9
    cb, sb = math.cos(b), math.sin(b)
    ox, oy = 0.2, 0.55
    p.rod((ox - 0.55 * cb, oy - 0.55 * sb, 0.05), (ox + 0.5 * cb, oy + 0.5 * sb, 0.05), 0.03, C["timber_pale"], segs=6)
    p.box((0.32, 0.26, 0.05), (ox + 0.68 * cb, oy + 0.68 * sb, 0.04), C["iron_light"], rot=(0, 0, b), style="hard_smooth")
    p.box((0.08, 0.2, 0.05), (ox - 0.6 * cb, oy - 0.6 * sb, 0.05), C["timber_dark"], rot=(0, 0, b))
    if v != "b":
        p.rod((-0.5, -0.5, 0.05), (0.15, -0.75, 0.05), 0.035, C["timber_dark"], segs=6)
        p.box((0.32, 0.14, 0.14), (0.27, -0.8, 0.08), C["iron"], rot=(0, 0, -0.36), style="hard_smooth")
    p.cyl(0.16, 0.22, (-0.45, 0.45, 0.11), P["tin_dark"], segs=12, style="round")
    p.torus(0.12, 0.015, (-0.45, 0.45, 0.24), C["iron"], rot=(math.pi / 2, 0, 0.4), major=10, minor=4)
    p.cyl(0.17, 0.03, (-0.15, 0.25, 0.02), P["tin"], segs=12, style="round")
    if v == "c":
        p.cyl(0.07, 0.34, (-0.8, 0.0, 0.07), C["verdigris"], segs=10, rot=(0, math.pi / 2, 0.8), style="round")
        p.ico(0.25, (0.6, 0.2, 0.12), P["denim"], scale=(1.4, 0.9, 0.35), style="round")
    else:
        p.uv(0.16, (0.55, -0.2, 0.11), C["bone"] if v == "a" else P["hat"], scale=(1.0, 1.0, 0.65), u=10, v=6, style="round")
        p.cyl(0.2, 0.03, (0.55, -0.2, 0.02), C["bone"] if v == "a" else P["hat"], segs=12, style="round")


@K.kind("notice_post", tags=["sign"], variants="ab", polish_opts={"detail": 1},
        story="A bench notice post: shift times and a blasting schedule, sun-bleached to blank boards.")
def notice_post(p, v, rng):
    lean = 0.05 if v == "a" else 0.22
    top = (math.sin(lean) * 2.2, 0, math.cos(lean) * 2.2)
    p.beam((0, 0, 0), top, 0.14, C["timber_dark"], style="hard_smooth")
    for k in range(3):
        ore_lump(p, rng, (math.cos(k * 2.1) * 0.3, math.sin(k * 2.1) * 0.3, 0.1), 0.2, P["host"], squash=0.7)
    board_z = 1.75
    bx = math.sin(lean) * board_z
    p.box((1.1, 0.06, 0.62), (bx, -0.1, board_z), tint(C["timber_pale"], rng, 0.04), rot=(0, lean, 0.03 if v == "a" else -0.12), style="hard_smooth")
    for k in range(3 if v == "a" else 2):
        p.box((0.32, 0.015, 0.4), (bx - 0.32 + k * 0.34, -0.14, board_z - 0.02), rng.choice([C["bone"], C["canvas"], C["canvas_stain"]]),
              rot=(0, lean, rng.uniform(-0.12, 0.12)), style="flat")
    if v == "b":
        p.box((0.33, 0.015, 0.42), (0.6, -0.4, 0.02), C["canvas_stain"], rot=(math.pi / 2, 0, 0.6), style="flat")


@K.kind("saguaro_bones", tags=["plant"], variants="abc", polish_opts={"detail": 1},
        story="A saguaro that died before the pit opened: the flesh long gone, its woody ribs bleached and fallen. "
              "Never upright and never tall, so it cannot read as the park's living saguaro anchors.")
def saguaro_bones(p, v, rng):
    rib = mix(C["timber_pale"], C["bone"], 0.4)
    rib_dark = mix(C["timber_grey"], C["bone"], 0.2)
    length = {"a": 4.2, "b": 2.6, "c": 3.4}[v]
    for k in range(8):
        a = math.tau * k / 8 + rng.uniform(-0.1, 0.1)
        spread = 0.24 + rng.uniform(0, 0.08)
        y0, z0 = math.cos(a) * 0.2, 0.22 + math.sin(a) * 0.18
        y1, z1 = math.cos(a) * spread * 1.6, max(0.05, 0.2 + math.sin(a) * spread)
        if rng.random() < 0.25:
            continue
        p.rod((0.0, y0, z0), (length * rng.uniform(0.8, 1.0), y1, z1), 0.05, rib if k % 2 else rib_dark, segs=5, style="flat", jit=0.015)
    stump_h = {"a": 0.6, "b": 0.95, "c": 0.8}[v]
    for k in range(9):
        a = math.tau * k / 9
        lean = rng.uniform(0.0, 0.12)
        p.rod((-0.25 + 0.26 * math.cos(a), 0.26 * math.sin(a), 0.0),
              (-0.25 + (0.24 + lean) * math.cos(a), (0.24 + lean) * math.sin(a), stump_h * rng.uniform(0.7, 1.0)),
              0.04, rib, segs=5, style="flat")
    p.ico(0.45, (-0.25, 0, 0.0), C["soil"], scale=(1.3, 1.2, 0.25), subdiv=2, style="flat", jit=0.04)
    if v != "b":
        p.rod((1.2, 0.5, 0.12), (2.0, 1.3, 0.1), 0.03, rib_dark, segs=5, style="flat")
        p.rod((1.25, 0.6, 0.14), (1.9, 1.45, 0.12), 0.03, rib, segs=5, style="flat")
    if v == "c":
        p.uv(0.16, (length * 0.6, -0.3, 0.14), C["timber_dark"], scale=(1.0, 0.8, 0.7), u=8, v=5, style="round")
    for k in range(2 if v == "a" else 1):
        x = 0.8 + k * 1.4
        p.ico(0.2, (x, -0.55, 0.22), tint(C["leaf"], rng, 0.05), scale=(1.0, 0.22, 1.2), rot=(0, 0, 0.4 + k), subdiv=2, style="flat")


@K.kind("prickly_pear", tags=["plant"], variants="ab", polish_opts={"detail": 1},
        story="Prickly pear grown up through the spoil; nobody cleared it, so the berm goes around it too.")
def prickly_pear(p, v, rng):
    pads = 7 if v == "a" else 5
    stack = [((0, 0, 0.32), 0.0)]
    for k in range(pads):
        base, tilt = rng.choice(stack[: 2 + k // 2])
        a = rng.uniform(0, math.tau)
        at = (base[0] + 0.3 * math.cos(a), base[1] + 0.3 * math.sin(a), base[2] + rng.uniform(0.25, 0.4))
        col = tint(mix(C["leaf"], C["dry_grass"], 0.25 if k % 3 else 0.0), rng, 0.05)
        p.ico(0.28, at, col, scale=(1.0, 0.22, 1.25), rot=(rng.uniform(-0.5, 0.5), 0, a + math.pi / 2), subdiv=2, style="flat")
        stack.append((at, a))
    p.ico(0.3, (0, 0, 0.3), C["leaf_dark"], scale=(1.0, 0.35, 1.2), subdiv=2, style="flat")
    p.ico(0.55, (0, 0, 0.0), C["soil"], scale=(1.4, 1.2, 0.3), subdiv=2, style="flat", jit=0.04)
    if v == "b":
        for k in range(4):
            a = rng.uniform(0, math.tau)
            p.ico(0.06, (0.35 * math.cos(a), 0.35 * math.sin(a), 0.9 + rng.uniform(0, 0.2)), "8a6a7a", style="round")


@K.kind("fire_ring", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="The old prospector's cold fire ring on the rim: stones, charred ends, a pan and a coffee pot. He was here first.")
def fire_ring(p, v, rng):
    for k in range(10):
        a = math.tau * k / 10 + rng.uniform(-0.1, 0.1)
        ore_lump(p, rng, (0.75 * math.cos(a), 0.75 * math.sin(a), 0.12), rng.uniform(0.17, 0.24), rng.choice([P["host"], P["ochre_dark"], C["sandstone_dark"]]), squash=0.7)
    p.ico(0.6, (0, 0, 0.0), P["ash"], scale=(1.0, 1.0, 0.12), style="round")
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        p.rod((0.1 * math.cos(a), 0.1 * math.sin(a), 0.22), (0.55 * math.cos(a), 0.55 * math.sin(a), 0.07), 0.06, P["char"], segs=6)
    p.cyl(0.12, 0.24, (1.15, 0.3, 0.12), C["iron_light"], segs=10, r2=0.09, style="round")
    p.rod((1.23, 0.3, 0.2), (1.32, 0.3, 0.28), 0.02, C["iron_light"], segs=4)
    p.cyl(0.32, 0.06, (-1.1, -0.4, 0.2), C["iron"], segs=16, r2=0.24, rot=(0.6, 0, 0.4), style="round")
    if v == "b":
        p.cyl(0.24, 1.3, (0.4, 1.35, 0.24), C["canvas_dark"], segs=12, rot=(0, math.pi / 2, 0.15), style="round")
        p.torus(0.25, 0.03, (0.0, 1.35, 0.24), C["timber_dark"], rot=(0, math.pi / 2, 0.15), major=10, minor=4)
        p.uv(0.2, (-0.9, 0.9, 0.12), C["timber_dark"], scale=(1.0, 1.0, 0.6), u=10, v=6, style="round")
        p.cyl(0.36, 0.03, (-0.9, 0.9, 0.03), C["timber_dark"], segs=14, style="round")
    else:
        p.ico(0.3, (0.1, 1.2, 0.15), C["canvas"], scale=(1.1, 0.8, 0.5), style="round")


@K.kind("haul_tyre", tags=["machine"], variants="ab", polish_opts={"detail": 1},
        story="A haul truck tyre twice a person's height, rolled off the shop pad and left where it fell.")
def haul_tyre(p, v, rng):
    R, r = 1.55, 0.6
    if v == "a":
        p.torus(R - r * 0.2, r, (0, 0, 0.35), P["char"], scale=(1.0, 1.0, 0.75), major=24, minor=10, style="flat")
        for k in range(20):
            a = math.tau * k / 20
            p.box((0.5, 0.18, 0.2), ((R + r * 0.6) * math.cos(a), (R + r * 0.6) * math.sin(a), 0.4), C["charcoal"], rot=(0, 0, a), style="fine")
        p.ico(1.0, (0, 0, 0.1), C["soil"], scale=(1.0, 1.0, 0.3), style="round")
        for k in range(3):
            a = math.tau * k / 3
            p.ico(0.22, (0.4 * math.cos(a), 0.4 * math.sin(a), 0.42), tint(C["leaf"], rng, 0.05), scale=(1.0, 0.35, 1.2), rot=(0, 0, a), style="round")
    else:
        for k, (ox, oy) in enumerate(((0, 0), (0.35, 0.2))):
            z = 0.42 + k * 0.82
            p.torus(R - r * 0.2, r * 0.9, (ox, oy, z), P["char"], scale=(1.0, 1.0, 0.7), rot=(0.05 * k, 0, 0), major=24, minor=10, style="flat")
            for j in range(16):
                a = math.tau * j / 16
                p.box((0.45, 0.16, 0.18), (ox + (R + r * 0.5) * math.cos(a), oy + (R + r * 0.5) * math.sin(a), z), C["charcoal"], rot=(0, 0, a), style="fine")
        p.ico(0.6, (0.3, 0.15, 1.0), C["soil"], scale=(1.0, 1.0, 0.3), style="round")


if __name__ == "__main__":
    K.main()
