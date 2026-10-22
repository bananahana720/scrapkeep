"""Pit park dressing kit (The Dig, world 2, noon, copper porphyry open pit).

The pit crews were a day-shift mining outfit: faded ochre trucks, rust oxide and grey-green
host rock, pale tailings, lunch pails left on shelves. LAMP VETO: nothing here is lit, no
lamp, no light pool, no glass that could read as glowing. Turquoise copper streaks appear
only as thin veins on rock, never as paint.

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

K = kit.Kit("pit", polish_opts={"detail": 1})

# Pit-local colours. Safe hues only: dusty ochre (never a stripe), rust oxide, host rock,
# pale tailings, a muted copper-carbonate vein, dark dull glass (unlit).
OCHRE = "a8905a"
OCHRE_DARK = "86703f"
OXIDE = "8a5a44"
OXIDE_DARK = "6b4535"
HOST = "7d8678"
HOST_DARK = "5e6a60"
TAILS = "d8d2c0"
TAILS_DARK = "bdb7a2"
VEIN = "4f9c92"
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
        kw["style"] = "round"  # small blobs: one subsurf level is smooth enough
    return p.ico(radius, loc, color, **kw)


# Pebble counts tuned so each kind's decimated LOD2 keeps its feet on the floor (kit tolerance 2 cm).
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


def bursage(p, x, y, z, s, rng, dry=False):
    """A grey-green bursage mound; `dry` swaps in straw tones."""
    base = "a39a64" if dry else SAGE
    for k in range(4):
        a = k * 1.9 + rng.uniform(0, 1)
        soft_ico(p, 0.3 * s, (x + math.cos(a) * 0.22 * s, y + math.sin(a) * 0.22 * s, z + 0.18 * s + 0.05 * k * s),
              tint(base if k % 2 else (SAGE_PALE if not dry else "b0a674"), rng, 0.07),
              scale=(1.0, 1.0, 0.75), style="soft")
    for k in range(3):
        a = k * 2.3 + 0.4
        p.rod((x, y, z + 0.1 * s), (x + math.cos(a) * 0.3 * s, y + math.sin(a) * 0.3 * s, z + 0.65 * s),
              0.018 * s, "a39a64", segs=5)


def cholla(p, x, y, z, s, rng, arms=2):
    """A jointed cholla: chunky segments, pale fuzz knobs (no spines to read as a creature)."""
    col = "8c9a72"
    top = z + 0.9 * s
    p.rod((x, y, z), (x, y, top), 0.1 * s, col, segs=7, r2=0.085 * s)
    for h in (0.25, 0.5, 0.75):
        soft_ico(p, 0.12 * s, (x, y, z + 0.9 * s * h), "a9ae88", scale=(1.0, 1.0, 0.8), style="soft")
    for k in range(arms):
        a = k * math.pi + 0.8 + rng.uniform(-0.2, 0.2)
        sx, sz = z + 0.5 * s + 0.12 * k * s, 0
        start = (x, y, sx)
        mid = (x + math.cos(a) * 0.35 * s, y + math.sin(a) * 0.35 * s, sx + 0.25 * s)
        end = (x + math.cos(a) * 0.4 * s, y + math.sin(a) * 0.4 * s, sx + 0.7 * s)
        p.rod(start, mid, 0.08 * s, col, segs=6)
        p.rod(mid, end, 0.075 * s, tint(col, rng, 0.05), segs=6)
        soft_ico(p, 0.11 * s, end, "a9ae88", scale=(1, 1, 0.85), style="soft")
    soft_ico(p, 0.12 * s, (x, y, top + 0.04 * s), "a9ae88", scale=(1, 1, 0.85), style="soft")


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
        # Sagging sidewall bulge puddled on the ground.
        soft_ico(p, r * 0.55, (x, y, 0.18), TYRE, scale=(w * 0.9, 1.15, 0.28), style="soft")


# --- heroes ---------------------------------------------------------------------------------

@K.kind("haul_truck", hero=True, variants="abc", tags=["machine"],
        story="The last haul truck down at shift end: parked dead, a tyre flat, the bed tipped, every lamp dark.")
def haul_truck(p, v, rng):
    body = OCHRE if v != "c" else mix(OCHRE, OXIDE, 0.55)
    trim = OXIDE if v != "c" else OXIDE_DARK
    # Frame rails and axles.
    for x in (-1.5, 1.5):
        p.box((0.5, 10.2, 0.5), (x, 0.4, 1.95), C["charcoal"], style="hard")
    for y in (-3.3, 3.0):
        p.box((6.2, 0.45, 0.45), (0, y, 1.6), C["iron"], style="hard")
    # Wheels: front pair, rear pair; one rear tyre flat in every variant.
    r, w = 1.55, 1.1
    flat_x, off_x = 3.0, (3.0 if v == "b" else None)
    for x in (-3.0, 3.0):
        for y in (-3.3, 3.0):
            if v == "b" and x == off_x and y == 3.0:
                # Tyre off: bare hub and axle stub, the tyre lying on its side nearby.
                p.cyl(0.8, 0.5, (x, y, 1.6), C["iron"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
                p.cyl(0.5, 0.3, (x + 0.35, y, 1.6), OXIDE_DARK, segs=10, rot=(0, math.pi / 2, 0), style="hard")
                continue
            tyre(p, x, y, r, w, flat=(x == -flat_x and y == 3.0))
    if v == "b":
        p.torus(1.2, 0.45, (5.7, 1.3, 0.45), TYRE, rot=(0.12, 0, 0.4), major=16, minor=8, style="round")
        p.cyl(0.85, 0.2, (5.7, 1.3, 0.35), OXIDE_DARK, segs=10, style="hard")
    # Engine hood, grille, bumper (grille bars vertical slats, unlit).
    p.box((2.4, 2.8, 1.4), (-1.3, -4.0, 2.9), body, style="hard")
    p.box((2.5, 0.35, 1.2), (-1.3, -5.5, 2.6), trim, style="hard")
    for k in range(7):
        p.box((0.16, 0.12, 0.9), (-2.2 + k * 0.3, -5.72, 2.65), C["charcoal"], style="fine")
    p.box((3.6, 0.6, 0.35), (-0.1, -5.9, 1.45), C["iron"], style="hard")
    # Cab: deck, walls, dark unlit glass, flat roof, exhaust stub.
    p.box((2.4, 2.4, 0.3), (-1.5, -1.5, 2.45), C["iron_light"], style="hard")
    p.box((2.1, 2.1, 2.0), (-1.5, -1.6, 3.6), body, style="hard")
    p.box((1.9, 0.12, 1.0), (-1.5, -2.7, 3.9), GLASS, style="fine")
    p.box((0.12, 1.6, 0.9), (-2.57, -1.6, 3.9), GLASS, style="fine")
    p.box((0.12, 1.6, 0.9), (-0.43, -1.6, 3.9), GLASS, style="fine")
    p.box((2.6, 3.2, 0.2), (-1.5, -1.9, 4.7), trim, style="hard")
    # A level sunshade deck on four stout posts above the cab roof: a flat 3.6 m top that holds without a mast.
    for dx in (-1.7, 1.7):
        for dy in (-1.7, 1.7):
            p.box((0.3, 0.3, 1.6), (-1.5 + dx, -1.9 + dy, 5.5), C["iron"], style="hard")
    p.box((3.8, 3.8, 0.3), (-1.5, -1.9, 6.25), shade(trim, 1.1), style="hard")
    p.cyl(0.14, 1.0, (-2.6, -0.2, 3.2), C["charcoal"], segs=8, style="round")
    # A single grab handle on the cab's front pillar (no steps).
    p.rod((-3.0, -2.75, 3.1), (-3.0, -2.75, 3.6), 0.05, C["iron_light"], segs=6)
    # Dump bed on a hinge at the rear. Tipped angle by variant.
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
    bed_box((5.0, L, 0.4), 0, cy, hz + 0.1, shade(body, 0.92))                # floor
    for sx in (-1, 1):
        bed_box((0.4, L, 1.6), sx * 2.5, cy, hz + 0.9, body)                  # sides
        bed_box((0.45, L + 0.1, 0.3), sx * 2.5, cy, hz + 1.75, trim)          # rim
    bed_box((5.4, 0.45, 2.2), 0, cy - L / 2 + 0.2, hz + 1.2, body)            # front wall
    bed_box((5.6, 1.2, 0.5), 0, cy - L / 2 - 0.6, hz + 2.4, trim)             # canopy over cab
    p.perch((-1.5, -1.9, 6.4))  # centre of the level sunshade deck, on its top face
    for k in range(5):                                                         # ribs on the sides
        for sx in (-1, 1):
            bed_box((0.15, 0.35, 1.4), sx * 2.72, cy - 3.6 + k * 1.8, hz + 0.9, shade(trim, 0.9))
    for sx in (-1, 1):
        y, z = bp(hy, hz + 0.4)
        p.cyl(0.28, 0.6, (sx * 1.6, y, z), C["iron"], segs=8, rot=(0, math.pi / 2, 0), style="hard")
    # Hydraulic ram from the frame to the bed underside.
    fy, fz = -0.8, 1.9
    uy, uz = bp(-0.8, hz - 0.1)
    for sx in (-1.4, 1.4):
        p.rod((sx, fy, fz), (sx, uy, uz), 0.2, C["iron_light"], segs=8)
        p.rod((sx, fy, fz), (sx, fy + (uy - fy) * 0.45, fz + (uz - fz) * 0.45), 0.28, C["iron"], segs=8)
    # Chocks and shift-end litter.
    p.box((0.9, 0.4, 0.4), (-3.0, 0.2, 0.2), C["timber_dark"], rot=(0, 0, 0.1))
    p.box((0.9, 0.4, 0.4), (3.0, -2.4, 0.2), C["timber_dark"], rot=(0, 0, -0.1))
    if v == "a":
        soft_ico(p, 0.5, (0.0, 6.0, 0.28), TAILS, scale=(2.2, 1.7, 0.5), style="soft")  # last spill
        soft_ico(p, 0.7, (-0.2, 3.6, hz + 0.9), TAILS_DARK, scale=(1.6, 1.6, 0.4), style="soft")
    elif v == "b":
        soft_ico(p, 1.4, (0.2, 6.6, 0.45), TAILS, scale=(1.9, 1.4, 0.55), style="soft")  # ore slid out
        soft_ico(p, 0.7, (-1.8, 6.0, 0.25), HOST_DARK, scale=(1.2, 1.0, 0.6), style="hard")
    else:
        # Rusted: oxide streaks on the flanks and bursage growing in the bed.
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
    # Crawler tracks: pad boxes, drive sprockets, rollers.
    for sx in (-1, 1):
        if v == "b" and sx == 1:
            # Track off on this side: bare roller frame, the pad run lying beside it.
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
    # Deck and engine house with louvres (dark, unlit).
    p.box((5.0, 6.0, 0.5), (0, 0, 1.55), C["charcoal"], style="hard")
    p.box((3.2, 2.8, 2.0), (-0.5, 1.4, 2.8), OCHRE, style="hard")
    p.box((3.3, 2.9, 0.3), (-0.5, 1.4, 3.9), OXIDE, style="hard")
    for k in range(5):
        p.box((0.2, 0.1, 1.2), (-1.7 + k * 0.5, 2.88, 2.8), C["charcoal"], style="fine")
    p.cyl(0.2, 1.1, (0.7, 0.4, 4.4), C["charcoal"], segs=8, style="round")
    # Operator cab: windows are dark and unlit.
    p.box((1.8, 2.0, 2.0), (1.4, -1.6, 2.8), OCHRE_DARK if v == "b" else OCHRE, style="hard")
    p.box((1.6, 0.1, 0.9), (1.4, -2.65, 3.1), GLASS, style="fine")
    p.box((0.1, 1.2, 0.9), (2.3, -1.6, 3.1), GLASS, style="fine")
    p.box((2.0, 2.2, 0.25), (1.4, -1.6, 3.9), OXIDE, style="hard")
    # Hydraulic cylinders and a rotary head riding the lowered mast.
    p.cyl(0.35, 1.8, (-2.2, -1.6, 2.2), C["iron_light"], segs=10, style="round")
    p.cyl(0.25, 1.0, (-2.2, -1.6, 3.3), C["iron"], segs=8, style="round")
    # Mast lowered along the machine on a cradle; chunky box section with ribs.
    mz = 4.65
    my0, my1 = -4.6, 5.0
    cradle = [(-0.0, -2.8), (0.0, 2.8)]
    for _, yy in cradle:
        p.box((1.8, 0.45, 0.6), (0, yy, 4.15), C["timber_dark"], style="hard")
    if v == "a":
        a_pt, b_pt = (0, my0, mz), (0, my1, mz)
        p.box((1.0, my1 - my0, 0.9), (0, (my0 + my1) / 2, mz), OXIDE, style="hard")
        for k in range(10):
            yy = my0 + 0.5 + k * 0.95
            p.box((1.15, 0.28, 1.05), (0, yy, mz), shade(OXIDE, 0.85), style="hard")
        p.cyl(0.55, 0.9, (0, my1 + 0.2, mz), C["iron"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
        p.cyl(0.4, 0.8, (0, my0 - 0.2, mz), C["iron_light"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
    else:
        # Mast slipped off its cradle: nose propped on a rock well clear of the ground, a kink mid-run, tail on the deck.
        rock(p, 0.4, -5.3, 0.0, 1.0, rng, vein=True)
        pts = [(0.4, -5.2, 1.75), (0.15, -1.2, 2.45), (0.0, 3.4, 4.4)]
        for a_pt, b_pt in zip(pts, pts[1:]):
            p.beam(a_pt, b_pt, 1.0, OXIDE, h=0.9, roll=0.0)
            ang = math.atan2(b_pt[2] - a_pt[2], b_pt[1] - a_pt[1])
            for k in range(5):
                t = (k + 0.5) / 5
                q = tuple(a_pt[i] + (b_pt[i] - a_pt[i]) * t for i in range(3))
                p.box((1.2, 0.28, 1.1), q, shade(OXIDE, 0.85), rot=(ang, 0, 0), style="hard")
        p.cyl(0.55, 0.9, (0.0, 3.6, 4.5), C["iron"], segs=10, rot=(math.pi / 2, 0, 0), style="hard")
        bursage(p, 1.8, -4.2, 0.0, 1.8, rng)
        bursage(p, -2.4, -4.8, 0.0, 1.4, rng, dry=True)
        bursage(p, 4.2, 2.0, 0.0, 1.5, rng)
    # Drill steels lying flat along the left pad, and a rod-handling arm stub.
    for k in range(4):
        p.rod((-4.9 + 0.0 * k, -2.5 + k * 0.28, 0.2), (-4.9, 2.4 + k * 0.1, 0.2), 0.11, C["iron_light"], segs=8)
    # Powder-cut debris: loose host rock and drill cuttings.
    for k, (rx, ry) in enumerate(((-4.2, -3.9), (4.6, -3.4), (-3.8, 4.2), (3.9, 4.3))):
        rock(p, rx, ry, 0.0, 0.55 + 0.1 * k, rng, vein=(k == 1))
    soft_ico(p, 1.0, (0.0, -5.4 if v == "a" else 6.0, 0.25), TAILS, scale=(2.2, 1.5, 0.4), style="soft")


@K.kind("rope_drum_wagon", hero=True, variants="ab", tags=["machine"],
        story="Hoist-rope wagon: a giant coiled drum on a timber bed, parked where the last shift unspooled it.")
def rope_drum_wagon(p, v, rng):
    sag = 0.0 if v == "a" else 0.45
    # Wagon bed with side rails and a cross-bolster.
    bed_z = 1.35
    p.box((3.8, 7.0, 0.4), (0, 0, bed_z), C["timber"], style="hard", rot=(0, 0.0, 0))
    for sx in (-1, 1):
        p.beam((sx * 1.7, -3.5, bed_z - 0.3), (sx * 1.7, 3.5, bed_z - 0.3), 0.3, C["timber_dark"], h=0.4)
    for yy in (-2.8, 0.0, 2.8):
        p.beam((-2.0, yy, bed_z - 0.1), (2.0, yy, bed_z - 0.1), 0.28, C["timber_dark"], h=0.3)
    for k in range(7):
        p.box((3.8, 0.9, 0.12), (0, -3.0 + k, bed_z + 0.26), tint(C["timber_pale"], rng, 0.06), style="fine")
    # Four spoked iron-tyred wheels; the rear-left one dropped/broken in variant b.
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
    # Giant rope drum on two stout side cheeks (cheeks are blocks, not an arch).
    dz = bed_z + 0.3 + 1.9 - sag * 0.0
    for sx in (-1, 1):
        p.box((0.45, 1.6, 2.5), (sx * 1.7, 0, bed_z + 1.5), C["timber_dark"], style="hard")
    ang = 0 if v == "a" else 0.0
    p.cyl(0.35, 4.3, (0, 0, dz), C["iron"], segs=10, rot=(0, math.pi / 2, 0), style="round")
    rr = 1.75 if v == "a" else 1.25   # b: half unwound, so a smaller coil
    for sx in (-1, 1):
        p.cyl(2.1, 0.25, (sx * 1.55, 0, dz), C["timber_grey"], segs=20, rot=(0, math.pi / 2, 0), style="hard")
        p.cyl(2.2, 0.12, (sx * 1.66, 0, dz), C["iron"], segs=20, rot=(0, math.pi / 2, 0), style="hard")
    # Rope as stacked wraps: a core cylinder plus ridged turns.
    p.cyl(rr, 2.9, (0, 0, dz), shade(HEMP, 0.9), segs=20, rot=(0, math.pi / 2, 0), style="round")
    for k in range(8):
        xx = -1.25 + k * 0.36
        p.torus(rr, 0.2, (xx, 0, dz), tint(HEMP, rng, 0.07), rot=(0, math.pi / 2, 0), major=20, minor=6)
    # Loose rope tail lying flat on the ground, coiled in a spiral (never taut).
    pts = []
    for k in range(18):
        a = k * 0.42
        rad = 0.4 + 0.075 * k if v == "a" else 0.55 + 0.11 * k
        pts.append((3.9 + math.cos(a) * rad * 0.9, -3.0 + math.sin(a) * rad * 0.9 if v == "a" else -3.4 + math.sin(a) * rad, 0.12))
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.11, HEMP, segs=6)
    # Drawbar lying on the ground, chunky and low, plus a wooden chock.
    p.beam((0, -3.5, 0.35), (0.6, -7.2, 0.18), 0.3, C["timber_dark"], h=0.28)
    p.box((0.8, 0.4, 0.4), (2.5, -4.2, 0.2), C["timber_dark"], rot=(0, 0, 0.2))
    if v == "b":
        bursage(p, -3.6, 3.2, 0.0, 1.6, rng)
        bursage(p, 3.0, 0.5, 0.0, 1.2, rng, dry=True)
        p.box((0.9, 1.6, 0.18), (-4.0, 1.0, 0.1), C["timber_grey"], rot=(0, 0, 0.5))
    pebbles(p, "rope_drum_wagon_" + v, rng, 5.0)


# --- props ----------------------------------------------------------------------------------

@K.kind("shift_bell", tags=["sign"], variants="ab",
        story="Shift bell on a stout post, its over-long rope left coiled flat on the ground.")
def shift_bell(p, v, rng):
    if v == "a":
        p.cyl(0.3, 1.4, (0, 0, 0.7), C["timber_dark"], segs=8, r2=0.26, style="hard")
        p.cyl(0.5, 0.2, (0, 0, 0.5), C["timber_dark"], segs=8, r2=0.3, style="hard")   # splayed foot
        p.box((0.9, 0.5, 0.2), (0, 0, 1.45), C["timber"], style="hard")                # cradle block
        p.cyl(0.68, 0.7, (0, 0, 1.95), C["iron"], segs=14, r2=0.3, style="hard")       # the bell, mouth down
        p.ring(0.58, 0.8, 0.12, (0, 0, 1.62), C["iron_light"], segs=14, style="hard")
        soft_ico(p, 0.2, (0, 0, 1.55), OXIDE_DARK, style="soft")                        # clapper
        p.cyl(0.14, 0.2, (0, 0, 2.38), C["iron_light"], segs=8, style="hard")
        p.cyl(0.4, 0.4, (0, 0, 0.12), HOST, segs=8, r2=0.35, style="hard")
    else:
        # Post snapped, bell fallen on its side beside the stump.
        p.cyl(0.2, 0.9, (0, 0, 0.45), C["timber_dark"], segs=8, r2=0.17, style="hard")
        p.cyl(0.24, 0.4, (0.2, 0.1, 0.3), C["timber_grey"], segs=8, rot=(0.1, 1.2, 0.5), style="hard")
        p.cyl(0.38, 0.5, (1.0, -0.2, 0.38), C["iron"], segs=12, r2=0.2, rot=(0, math.pi / 2 - 0.15, 0.4), style="hard")
        p.ring(0.3, 0.46, 0.1, (0.72, -0.12, 0.38), C["iron_light"], segs=12, rot=(0, math.pi / 2 - 0.15, 0.4), style="hard")
        p.box((0.9, 0.25, 0.22), (-0.9, 0.3, 0.14), C["timber_dark"], rot=(0, 0, 0.5), style="hard")
        bursage(p, -0.4, -0.7, 0.0, 0.9, rng)
    # Rope coil lying flat: three concentric laps plus a tail.
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
    # Back board on two stout posts, one shelf plank, a lower plank.
    for x in (-1.05, 1.05):
        p.box((0.22, 0.28, 1.25), (x, 0.3, 0.62), C["timber_dark"], style="hard")
    p.box((2.5, 0.12, 0.7), (0, 0.4, 0.82), C["timber"], style="hard")
    if v == "a":
        p.box((2.5, 0.65, 0.12), (0, 0.05, 0.65), C["timber_pale"], style="hard")
        for k, (px, ps) in enumerate(((-1.0, 0.9), (-0.48, 1.05), (0.1, 0.8), (0.6, 0.95), (1.0, 0.85))):
            pail(p, px, 0.05 + 0.04 * (k % 2), 0.71, cols[k], rng, lid=(k in (1, 4)), s=ps)
        p.cyl(0.07, 0.1, (1.15, -0.28, 0.76), C["canvas_dark"], segs=8, style="hard")  # a tin mug
        p.torus(0.045, 0.012, (1.22, -0.28, 0.76), C["canvas_dark"], rot=(math.pi / 2, 0, 0), major=8, minor=4)
        soft_ico(p, 0.3, (0.0, -0.1, 0.35), C["canvas"], scale=(1.5, 1.0, 0.45), rot=(0, 0, 0.3), style="soft")  # jacket on the lower plank
        p.box((2.5, 0.5, 0.1), (0, 0.05, 0.22), C["timber_pale"], style="hard")
    else:
        # Shelf end gave way: plank dropped on one side, pails rolled to the ground.
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
    # Platform balance: base, stout pillar, level beam, two pans held on short struts.
    p.cyl(0.38, 0.14, (-0.25, 0.05, 1.02), C["iron"], segs=12, style="hard")
    p.cyl(0.1, 0.62, (-0.25, 0.05, 1.38), C["iron_light"], segs=8, style="round")
    tilt = 0.0 if v == "a" else 0.18
    for sx in (-1, 1):
        ex, ez = -0.25 + sx * 0.62 * math.cos(tilt), 1.72 + sx * 0.62 * math.sin(tilt)
        p.rod((-0.25, 0.05, 1.72), (ex, 0.05, ez), 0.05, C["iron"], segs=6)
        p.rod((ex, 0.05, ez), (ex, 0.05, ez - 0.2 - (0.1 if sx * tilt > 0 else 0)), 0.03, C["iron"], segs=5)
        p.cyl(0.26, 0.05, (ex, 0.05, ez - 0.32 - (0.1 if sx * tilt > 0 else 0)), C["iron_light"], segs=12, style="hard")
    soft_ico(p, 0.1, (-0.25, 0.05, 1.74), C["iron"], style="round")
    # Sample jars (opaque dusty ceramic, no glass) and rock samples with a thin vein.
    for k in range(3):
        p.cyl(0.11, 0.2, (0.6 + k * 0.26, -0.22, 1.06), ["b8b099", "8f9a8a", "a89b7e"][k], segs=8, style="hard")
    rock(p, 0.75, 0.2, 0.96, 0.17, rng, vein=True)
    rock(p, 1.0, 0.18, 0.96, 0.13, rng)
    # Ledger board, kept under 1.5 m, on a single stout stake.
    p.box((0.2, 0.2, 1.1), (-1.0, 0.58, 0.55), C["timber_dark"], style="hard")
    tl = 0.0 if v == "a" else 0.12
    p.box((0.95, 0.1, 0.62), (-1.0, 0.52, 1.1), C["timber_pale"], rot=(0, tl, 0), style="hard")
    p.box((0.8, 0.04, 0.48), (-1.0, 0.45, 1.1), C["canvas"], rot=(0, tl, 0), style="fine")
    for k in range(4):
        p.box((0.6 - 0.1 * (k % 2), 0.03, 0.04), (-1.0, 0.42, 1.25 - k * 0.11), C["charcoal"], rot=(0, tl, 0), style="flat")
    # The mug of the assayer.
    p.cyl(0.08, 0.12, (0.3, -0.25, 1.02), C["canvas_dark"], segs=8, style="hard")


@K.kind("ore_cart_stub", tags=["machine"], variants="abc",
        story="A stubby ore cart on a 2 m stub of track that goes nowhere.")
def ore_cart_stub(p, v, rng):
    # The stub: two chunky rails lying in sleepers, ending in an earth bump. 2 m only.
    for k in range(5):
        p.box((1.3, 0.28, 0.16), (0, -1.0 + k * 0.5, 0.08), C["timber_dark"], style="hard")
    for sx in (-0.45, 0.45):
        p.box((0.14, 2.1, 0.2), (sx, 0, 0.25), C["iron"], style="hard")
    soft_ico(p, 0.5, (0, 1.2, 0.16), C["soil"], scale=(1.6, 1.0, 0.5), style="soft")
    cx = 0.0 if v != "b" else 1.8
    cy = 0.0 if v != "b" else 0.4
    roll = 0.0 if v != "b" else 1.15
    # Cart: tapering bucket on a frame, rounded corners.
    def at(x, y, z):
        if v != "b":
            return (cx + x, cy + y, z)
        # Tipped on its side, rotated about the long axis.
        return (cx + x * math.cos(roll) - z * math.sin(roll) * 0.6, cy + y, 0.1 + z * math.cos(roll) * 0.9 + abs(x) * 0.0)

    rot = (0, roll, 0)
    body = OXIDE if v != "c" else mix(OXIDE, OCHRE, 0.4)
    p.prism([(-0.62, 0.0), (0.62, 0.0), (0.82, 0.8), (-0.82, 0.8)], 1.5, at(0, 0, 0.3), body,
            rot=(math.pi / 2, roll, 0), style="hard")
    if v != "b":
        for sx in (-0.84, 0.84):
            p.box((0.12, 1.62, 0.14), (sx, 0, 1.1), shade(body, 0.8), style="hard")
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
    # Stout timber cribbing (four wide blocks around a cross brace): short, not leggy.
    drop = 0.0 if v == "a" else 0.35
    for k, (x, y) in enumerate(((-0.95, -0.95), (0.95, -0.95), (-0.95, 0.95), (0.95, 0.95))):
        h = 1.0 - (drop if k == 3 else 0.0)
        p.cyl(0.32, h, (x, y, h / 2), C["timber_dark"], segs=8, style="flat")
    p.box((2.4, 0.35, 0.28), (0, 0, 1.0 - drop * 0.4), C["timber"], rot=(0, tilt, 0), style="hard")
    p.box((0.35, 2.4, 0.28), (0, 0, 1.15 - drop * 0.4), C["timber"], rot=(0, tilt, 0), style="hard")
    zt = 1.35
    # Tank: barrel body in oxide steel, rounded cap, banding hoops.
    p.cyl(1.3, 1.0, (0, 0, zt + 0.5), shade(OXIDE, 1.05), segs=12, rot=(0, tilt, 0), style="hard")
    p.uv(1.3, (0, 0, zt + 1.0), shade(OXIDE, 1.05), scale=(1, 1, 0.35), u=12, v=4, rot=(0, tilt, 0), style="hard")
    for z in (0.15, 0.85):
        p.ring(1.28, 1.38, 0.1, (0, 0, zt + z), C["iron"], segs=12, style="hard", rot=(0, tilt, 0))
    p.cyl(0.35, 0.25, (0, 0, zt + 1.42), C["iron"], segs=10, style="hard")
    p.cyl(0.14, 0.5, (1.3, 0, zt + 0.12), C["iron"], segs=8, rot=(0, math.pi / 2, 0), style="round")
    for k in range(3):
        p.box((0.06, 0.05, 0.9), (-1.32, 0.0, zt + 0.5 + k * 0.0), OXIDE_DARK, rot=(0, 0, k * 0.5), style="fine")
    # Hose reel on the ground beside it: drum, cheeks, grey coil laps (CABLE grey, lying low).
    hx, hy = 2.5, -1.0
    p.box((0.9, 0.9, 0.6), (hx, hy, 0.3), C["timber_dark"], style="hard")
    p.cyl(0.55, 0.5, (hx, hy, 0.95), C["iron"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
    for sx in (-1, 1):
        p.cyl(0.7, 0.06, (hx + sx * 0.3, hy, 0.95), C["iron_light"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
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
        # BENCH as five stroke blocks, then the 3.
        for k in range(5):
            p.box((0.1, 0.03, 0.22), (-0.78 + k * 0.17, -0.13, 1.1), C["canvas"], style="fine")
        numeral(0.45, 0.95)
        p.cyl(0.4, 0.3, (0.55, 0.15, 0.15), HOST, segs=8, r2=0.35, style="hard")
        for rx, ry, rr in ((-0.8, 0.5, 0.25), (0.9, 0.4, 0.2)):
            rock(p, rx, ry, 0.0, rr, rng)
    else:
        # Board fallen face-up on the ground, stake snapped.
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
    # Short round props, lying down.
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
        story="Haul-road windsock on a stout mast; the wind has dropped and the sock hangs limp.")
def windsock(p, v, rng):
    if v == "a":
        p.cyl(0.38, 0.5, (0, 0, 0.25), HOST, segs=8, r2=0.34, style="hard")
        p.cyl(0.14, 2.6, (0, 0, 1.55), C["iron"], segs=8, r2=0.1, style="hard")
        p.cyl(0.2, 0.16, (0, 0, 2.7), C["iron_light"], segs=8, style="hard")
        p.box((1.2, 0.14, 0.14), (0.5, 0, 2.7), C["iron"], style="hard")   # arm, braced to the mast
        p.torus(0.34, 0.035, (1.15, 0, 2.7), C["iron"], rot=(0, math.pi / 2, 0), major=10, minor=4)  # mouth hoop
        # Sock held out stiff (as in a steady wind): striped canvas white, charcoal and sand.
        for k, col in enumerate((C["canvas"], C["charcoal"], C["canvas"], C["sandstone"], C["canvas"])):
            r1 = 0.33 - k * 0.045
            p.cyl(r1, 0.3, (1.3 + k * 0.3, 0, 2.7), col, segs=10, r2=r1 - 0.045, rot=(0, math.pi / 2, 0), style="hard")
        for rx, ry, rr in ((-0.6, 0.5, 0.25), (0.5, -0.5, 0.2)):
            rock(p, rx, ry, 0.0, rr, rng)
    else:
        # Mast snapped at the knee, sock tangled beside it on the ground.
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
        # Half-buried bucket shell: a rounded scoop with a rim band and three stubby teeth.
        p.cyl(0.8, 1.7, (0, 0, 0.55), shade(OXIDE, 0.95), segs=14, rot=(0, math.pi / 2, 0), style="hard")
        p.cyl(0.62, 1.74, (0, 0, 0.6), C["soil"], segs=12, rot=(0, math.pi / 2, 0), style="hard")
        p.box((1.9, 0.3, 0.3), (0, -0.78, 0.38), C["iron"], style="hard")
        for k in range(3):
            p.cyl(0.18, 0.5, (-0.6 + k * 0.6, -0.95, 0.35), C["iron_light"], segs=6, r2=0.07, rot=(math.pi / 2 + 0.1, 0, 0), style="hard")
        cholla(p, 0.2, 0.1, 0.8, 1.0, rng, arms=2)
        cholla(p, -0.5, 0.7, 0.0, 0.7, rng, arms=1)
    else:
        # One tooth lying alone, with a scatter of host rock and a young cholla.
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
            p.cyl(0.07, 0.56, (xk, yk, cz), HOST if not vein else mix(HOST, VEIN, 0.0), segs=8,
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
        # Trestle collapsed: trays slid to the ground, cores spilled in a fan.
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
    p.cyl(0.7, 0.22, (0, 0, 0.11), C["soil"], segs=8, r2=0.55, style="hard")  # a mound of trodden dirt
    if v == "a":
        bursage(p, 0, 0, 0.0, 1.5, rng)
        bursage(p, 0.7, 0.5, 0.0, 1.0, rng)
        bursage(p, -0.6, 0.6, 0.0, 0.9, rng)
    elif v == "b":
        bursage(p, 0, 0, 0.0, 1.6, rng, dry=True)
        bursage(p, -0.7, -0.4, 0.0, 1.1, rng)
        for k in range(5):
            p.rod((0.0, 0.0, 0.2), (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.1 + 0.1 * k), 0.015, "b0a674", segs=5)
    else:
        bursage(p, 0, 0, 0.0, 1.0, rng, dry=True)
        bursage(p, 0.8, -0.3, 0.0, 1.2, rng)
        bursage(p, -0.7, 0.5, 0.0, 0.8, rng)
        rock(p, 0.2, 0.9, 0.0, 0.3, rng, vein=True)


@K.kind("cholla", tags=["plant"], variants="abc",
        story="Cholla, jointed and fuzzy, standing in cluster or fallen in a mat of dropped joints.")
def cholla_kind(p, v, rng):
    if v == "a":
        cholla(p, 0, 0, 0.0, 1.5, rng, arms=2)
    elif v == "b":
        cholla(p, -0.4, 0, 0.0, 1.3, rng, arms=1)
        cholla(p, 0.5, 0.3, 0.0, 1.0, rng, arms=2)
        cholla(p, 0.1, -0.6, 0.0, 0.8, rng, arms=0)
    else:
        # Fallen joints in a mat.
        for k in range(6):
            a = rng.uniform(0, 3)
            x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
            p.cyl(0.1, 0.5, (x, y, 0.1), "8c9a72", segs=7, rot=(0, math.pi / 2, a), style="hard")
            soft_ico(p, 0.11, (x + math.cos(a) * 0.27, y - math.sin(a) * 0.27, 0.1), "a9ae88", scale=(1, 1, 0.8), style="soft")
        cholla(p, 0.0, 0.0, 0.0, 0.9, rng, arms=1)
        rock(p, 0.7, 0.5, 0.0, 0.25, rng)


if __name__ == "__main__":
    K.main()
