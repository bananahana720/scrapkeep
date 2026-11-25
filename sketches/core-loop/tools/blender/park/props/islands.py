"""Islands park dressing kit (world 3, Highdraft: the sky islands, golden hour).

Pine-topped mesas over desert. The animals' net crews work in ochre rope and patched canvas,
a dam-era fire crew left a lookout and a tram, and the Fleet moors on one mesa. Slickrock
pink, sandstone tan, relict pine and manzanita. Brass (one tag) appears only on the Fleet-owned
winch_drum; oxide wear and charcoal also sit on the tram and ore_trolley. The balloon tag is plain canvas.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/islands.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, shade, tint

K = kit.Kit("islands", polish_opts={"detail": 1})

ROPE = "7a6e58"
ROPE_D = "574e3f"
SLICK = "8c7e76"
SLICK_D = "6f645d"
PINE = "4d6840"
PINE_D = "394f34"
BARK = "6b4a38"
WICKER = "6e6150"
PATCH_A = "a39b86"
PATCH_B = "8e8571"
PATCH_C = "96937f"
TIMBER = "6c5f4d"
TIMBER_D = "4b4136"
SAND = "b5a384"
SAND_D = "9c8d73"
SAND_P = "c9bb9f"
OXIDE = "9b513a"
BRASS = "d9b44a"
PETROL = "365754"
BONE = "d2c5a5"
COPPER = "b77843"


def rock(p, loc, r, col, rng, sq=0.7, style="round", sub=0):
    p.ico(r, loc, tint(col, rng, 0.08), scale=(rng.uniform(0.95, 1.35), rng.uniform(0.9, 1.2), sq),
          rot=(0, 0, rng.uniform(0, 3)), subdiv=sub, style=style, jit=r * 0.07)


def blob(p, r, loc, col, **kw):
    """Low-poly soft lump for small props (the subsurf rounds it)."""
    return p.uv(r, loc, col, u=6, v=4, **kw)


def coil(p, c, r, col, rng, turns=3, z0=0.0, tube=0.05, major=14):
    """Flat rope coil: stacked tori that shrink inward. Lies on the ground, never stands."""
    for k in range(turns):
        rr = r * (1 - 0.18 * k)
        p.torus(rr, tube, (c[0] + rng.uniform(-0.02, 0.02), c[1], z0 + tube + k * tube * 1.3),
                tint(col, rng, 0.06), major=major, minor=5, style="fine")


def blades(p, c, n, h, spread, rng, cols, w=0.06):
    """A tuft of grass blades: slim tilted cones."""
    for _ in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, spread)
        lean = rng.uniform(0.12, 0.5)
        hh = h * rng.uniform(0.6, 1.1)
        x, y = c[0] + d * math.cos(a), c[1] + d * math.sin(a)
        p.rod((x, y, 0.0), (x + hh * lean * math.cos(a), y + hh * lean * math.sin(a), hh * 0.95),
              w, rng.choice(cols), segs=4, r2=0.004, style="fine")


def tuft_clump(p, c, rng, big=1.0):
    blades(p, c, int(20 * big), 0.9 * big, 0.35 * big, rng, [C["dry_grass"], C["leaf"], mix(C["dry_grass"], C["leaf"], 0.5)])


def planks_h(p, x0, x1, y, z0, z1, n, col, rng, d=0.1, skip=(), jit=0.004):
    """Horizontal planks along X on a wall at y, stacked from z0 to z1."""
    h = (z1 - z0) / n
    for i in range(n):
        if i in skip:
            continue
        p.box(((x1 - x0) - rng.uniform(0, 0.1), d, h * 0.94), ((x0 + x1) / 2 + rng.uniform(-0.03, 0.03), y, z0 + h * (i + 0.5)),
              tint(col, rng, 0.07), jit=jit)


def planks_v(p, y0, y1, x, z0, z1, n, col, rng, d=0.1, skip=(), jit=0.004):
    h = (y1 - y0) / n
    for i in range(n):
        if i in skip:
            continue
        p.box((d, h * 0.94, z1 - z0 - rng.uniform(0, 0.12)), (x, y0 + h * (i + 0.5), (z0 + z1) / 2), tint(col, rng, 0.07), jit=jit)


@K.kind("lookout_hut", hero=True, tags=["building"], polish_opts={"detail": 2}, variants="abc",
        story="A fire crew's timber cab on short stilts with a round window and a log board; the roof is going, then the floor.")
def lookout_hut(p, v, rng):
    W, D = 3.6, 3.2
    sz = 1.1
    ch = 2.3
    if v == "c":
        sz, ch = 0.3, 2.0
    for x in (-1.6, 1.6):
        for y in (-1.4, 1.4):
            if v == "b" and (x, y) == (1.6, 1.4):
                p.beam((x, y, 0), (x + 0.3, y + 0.2, 0.55), 0.3, TIMBER_D)
                continue
            p.beam((x, y, 0), (x, y, sz + 0.1), 0.3, TIMBER_D, style="hard_smooth")
            rock(p, (x, y, 0.1), 0.45, SLICK_D, rng, 0.5)
    if v != "c":
        for z in (0.45, 0.75):
            for y in (-1.4, 1.4):
                p.beam((-1.6, y, z), (1.6, y, z), 0.1, TIMBER, h=0.12)
    p.box((W + 0.4, D + 0.4, 0.18), (0, 0, sz + 0.1), TIMBER_D)
    for i in range(10):
        x = -1.75 + i * 0.39
        p.box((0.36, D + 0.45, 0.06), (x, 0, sz + 0.21), tint(C["timber_pale"] if i % 3 else TIMBER, rng, 0.1), jit=0.004)
    p.box((1.6, 0.9, sz * 0.5), (-0.6, -2.35, sz * 0.25), SAND_D, style="hard_smooth")
    p.box((1.3, 0.8, sz * 0.25), (-0.6, -2.95, sz * 0.12), SAND, style="hard_smooth")
    z0 = sz + 0.25
    gap_b = {3, 4, 9} if v == "b" else ({2, 3, 6, 7, 8, 12} if v == "c" else set())
    planks_h(p, -W / 2, W / 2, D / 2, z0, z0 + ch, 15, C["timber_grey"], rng, d=0.12, skip=gap_b)
    for s in (-1, 1):
        for i in range(15):
            if (s == 1 and i in gap_b) or (v == "c" and s == -1 and i > 9):
                continue
            p.box((0.12, D - 0.1, ch / 15 * 0.94), (s * W / 2, 0, z0 + ch / 15 * (i + 0.5)),
                  tint(TIMBER if s == -1 else C["timber_grey"], rng, 0.07), jit=0.004)
    for i in range(15):
        zc = z0 + ch / 15 * (i + 0.5)
        for (a, b) in ((-W / 2, -0.55), (0.45, W / 2)):
            if (a, b) == (0.45, W / 2) and 5 <= i <= 10:
                continue
            p.box((b - a, 0.12, ch / 15 * 0.94), ((a + b) / 2, -D / 2, zc), tint(TIMBER, rng, 0.07), jit=0.004)
    p.box((0.9, 0.1, ch - 0.1), (-0.05, -D / 2 + 0.03, z0 + ch / 2 - 0.05), tint(C["timber_pale"], rng, 0.05))
    p.cyl(0.07, 0.1, (0.3, -D / 2 - 0.1, z0 + 1.1), C["iron"], segs=6, rot=(math.pi / 2, 0, 0))
    wz = z0 + ch * 0.52
    face = (math.pi / 2, 0, 0)
    p.ring(0.34, 0.52, 0.2, (1.65, -D / 2 - 0.02, wz), TIMBER_D, segs=16, rot=face, style="hard_smooth")
    p.cyl(0.36, 0.05, (1.65, -D / 2 + 0.06, wz), C["iron_light"] if v != "c" else C["iron"], segs=16, rot=face, style="flat")
    p.box((0.9, 0.1, 0.7), (-1.55, -D / 2 - 0.35, z0 + 1.1), TIMBER_D, rot=(0, 0.04, 0.04))
    for k in range(4):
        p.box((0.6 - 0.1 * (k % 2), 0.02, 0.05), (-1.55, -D / 2 - 0.42, z0 + 1.28 - k * 0.14), C["canvas"], style="flat")
    p.beam((-1.95, -D / 2 - 0.35, z0), (-1.95, -D / 2 - 0.35, z0 + 0.8), 0.1, TIMBER_D)
    p.beam((-1.15, -D / 2 - 0.35, z0), (-1.15, -D / 2 - 0.35, z0 + 0.8), 0.1, TIMBER_D)
    top = z0 + ch
    rise, half, rows = 1.2, 2.05, 8
    theta = math.atan2(rise, half)
    for s in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            if v == "b" and s == 1 and r >= 3 and r % 3 != 0:
                continue
            if v == "c" and (s == 1 or r >= 4):
                continue
            segs = 3
            for j in range(segs):
                x = -W / 2 - 0.25 + (j + 0.5) * (W + 0.5) / segs
                p.box(((W + 0.5) / segs + 0.02, 0.62, 0.08), (x, s * half * (1 - t) * 0.98, top + 0.12 + rise * t),
                      tint(C["timber_grey"] if (r + j) % 3 else TIMBER_D, rng, 0.07),
                      rot=(-s * theta, 0, 0), jit=0.005)
    for x in (-1.7, -0.6, 0.6, 1.7):
        for s in (-1, 1):
            if v == "c" and s == 1:
                continue
            p.beam((x, s * half, top + 0.05), (x, 0, top + rise + 0.12), 0.12, TIMBER_D, h=0.1)
    if v != "c":
        p.beam((-W / 2 - 0.3, 0, top + rise + 0.1), (W / 2 + 0.3, 0, top + rise + 0.1), 0.2, TIMBER_D)
    if v == "b":
        p.ico(0.8, (0.6, 0.9, top + 0.5), C["canvas_dark"], scale=(1.6, 1.1, 0.25), rot=(0.4, 0, 0.1))
        rock(p, (3.0, 1.0, 0.3), 0.55, SLICK_D, rng, 0.6)
    if v == "c":
        for k in range(6):
            p.box((1.8, 0.4, 0.08), (-0.6 + k * 0.25, -2.0 - 0.05 * k, 0.3 + 0.12 * k), tint(TIMBER_D, rng, 0.1),
                  rot=(0.2 * (k % 2), 0.15, rng.uniform(-0.6, 0.6)), jit=0.006)
        for a in (0.3, 2.4, 4.4):
            p.rod((1.2, 0.5, 0.2), (1.2 + 0.8 * math.cos(a), 0.5 + 0.8 * math.sin(a), 1.2 + 0.4 * math.sin(a)), 0.07, BARK, segs=5)
        p.ico(0.6, (1.3, 0.5, 1.5), C["leaf"], scale=(1.3, 1.2, 0.7))
    for i in range(4):
        rock(p, (rng.uniform(-3.0, 3.0), rng.uniform(-3.6, -2.4), 0.12), rng.uniform(0.2, 0.35), SLICK, rng, 0.5)
    if v == "a":
        coil(p, (2.5, -2.4, 0), 0.5, ROPE, rng, turns=3)


def basket(p, c, w, h, rng, tip=0.0, sag=0.0):
    """A wicker gondola: ring bands round a flared body, rim bound in rope, floor slab."""
    x, y, z = c
    p.cyl(w * 0.5, h, (x, y, z + h / 2), WICKER, segs=14, r2=w * 0.56, rot=(tip, 0, 0), style="round")
    for k in range(5):
        zz = z + h * (0.12 + 0.19 * k)
        p.torus(w * (0.5 + 0.06 * (zz - z) / h) + 0.01, 0.03, (x, y, zz), shade(WICKER, 0.9 + 0.06 * (k % 2)),
                rot=(tip, 0, 0), major=14, minor=4, style="fine")
    p.torus(w * 0.56, 0.05, (x, y, z + h), ROPE_D, rot=(tip, 0, 0), major=14, minor=5, style="fine")


@K.kind("balloon_basket_wreck", hero=True, tags=["wreck"], polish_opts={"detail": 2}, variants="abc",
        story="A patched envelope sagging over a wicker gondola; the stitching is in two hands, the second one braver.")
def balloon_basket_wreck(p, v, rng):
    pats = [PATCH_A, PATCH_B, PATCH_C, C["canvas"], SLICK]
    env = mix(C["canvas"], ROPE, 0.22) if v != "c" else C["canvas_stain"]
    if v == "a":
        basket(p, (0, 0, 0), 1.9, 1.3, rng)
        lobes = [((0.1, 1.35, 1.0), 1.5, (1.6, 1.1, 0.75)), ((-1.7, 1.9, 0.6), 1.3, (1.4, 1.1, 0.5)),
                 ((1.8, 2.2, 0.5), 1.3, (1.3, 1.1, 0.45)), ((0.0, 3.0, 0.45), 1.3, (1.5, 1.1, 0.4))]
    elif v == "b":
        basket(p, (0.0, 0.0, 0.0), 1.9, 1.3, rng, tip=math.pi / 2 - 0.12)
        lobes = [((0.2, 1.9, 0.4), 1.5, (1.6, 1.3, 0.3)), ((-1.9, 3.2, 0.33), 1.6, (1.5, 1.2, 0.25)),
                 ((1.7, 3.5, 0.3), 1.5, (1.4, 1.2, 0.22)), ((0.1, 5.0, 0.28), 1.5, (1.6, 1.2, 0.2)),
                 ((-0.4, 6.4, 0.2), 1.1, (1.4, 1.1, 0.18))]
    else:
        basket(p, (0, 0, 0), 1.9, 1.3, rng)
        lobes = [((0.0, 1.9, 0.6), 1.5, (1.7, 1.2, 0.4)), ((-1.5, 2.3, 0.55), 1.3, (1.2, 1.0, 0.5)),
                 ((1.5, 2.7, 0.5), 1.3, (1.2, 1.0, 0.45))]
        p.rod((0.1, 0.1, 0.1), (0.15, 0.1, 2.9), 0.1, BARK, segs=6, r2=0.04)
        for k in range(5):
            r = 1.0 - 0.15 * k
            p.cyl(r, 0.5, (0.15, 0.1, 1.2 + 0.4 * k), PINE if k % 2 else PINE_D, segs=7, r2=0.1, style="soft")
    for c, r, sc in lobes:
        p.ico(r, c, tint(env, rng, 0.05), scale=sc, rot=(0, 0, rng.uniform(0, 3)), subdiv=1)
    for k in range(9 if v != "c" else 5):
        c, r, sc = lobes[k % len(lobes)]
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.55) * r * sc[0]
        px, py = c[0] + d * math.cos(a), c[1] + d * math.sin(a) * sc[1] / sc[0]
        pz = c[2] + sc[2] * r * math.sqrt(max(0.0, 1 - (d / (r * sc[0])) ** 2)) * 0.97
        p.box((0.9, 0.7, 0.07), (px, py, pz), tint(rng.choice(pats), rng, 0.05),
              rot=(0, 0, rng.uniform(0, 3)), style="soft", jit=0.01)
        for st in range(5):
            if v == "a" and rng.random() < 0.4:
                continue
            p.box((0.1, 0.03, 0.03), (px - 0.4 + st * 0.2, py + 0.3, pz + 0.05), C["cable"], style="flat",
                  rot=(0, 0, math.pi / 4 if (st + k) % 2 else -math.pi / 4))
    if v == "a":
        for sx in (-0.7, 0.7):
            p.rod((sx, 0.4, 1.3), (sx * 1.3, 1.6, 1.1), 0.04, ROPE, segs=5)
    coil(p, (-1.9 if v != "b" else 1.8, -1.6, 0), 0.6, ROPE, rng, turns=3)
    if v != "b":
        p.box((0.5, 0.05, 0.3), (0.0, -0.98, 0.95), C["canvas"], style="fine")
    for i in range(3):
        rock(p, (rng.uniform(-3, 3), rng.uniform(-3.2, -2.0), 0.1), rng.uniform(0.15, 0.3), SLICK, rng, 0.5)


@K.kind("tram_car_parked", hero=True, tags=["machine", "vehicle"], polish_opts={"detail": 2}, variants="abc",
        story="A mining tram cabin set down on sleeper blocks, wheels off, never to hang again.")
def tram_car_parked(p, v, rng):
    L, Wd, H = 4.6, 2.6, 2.3
    tilt = {"a": 0.0, "b": 0.05, "c": 0.12}[v]
    zf = 0.55
    body = PETROL
    for x in (-1.5, 0, 1.5):
        for y in (-0.85, 0.85):
            p.box((0.7, 0.55, 0.55), (x, y, 0.27), tint(TIMBER_D, rng, 0.1), rot=(0, 0, rng.uniform(-0.1, 0.1)))
    p.box((L + 0.2, Wd + 0.2, 0.2), (0, 0, zf + 0.1), C["charcoal"], rot=(0, tilt * 0.3, 0), style="hard_smooth")
    z0 = zf + 0.2
    for s in (-1, 1):
        for i in range(10):
            zc = z0 + H / 10 * (i + 0.5)
            if 4 <= i <= 6:
                continue
            if v == "c" and s == 1 and i in (1, 2, 8):
                continue
            p.box((L, 0.12, H / 10 * 0.94), (0, s * Wd / 2, zc), tint(body, rng, 0.07), jit=0.004)
        for x in (-L / 2 + 0.1, -0.75, 0.75, L / 2 - 0.1):
            p.box((0.2, 0.18, H * 0.4), (x, s * Wd / 2, z0 + H * 0.5), TIMBER_D)
    for e in (-1, 1):
        for i in range(10):
            if v == "b" and e == 1 and i in (2, 3):
                continue
            p.box((0.12, Wd, H / 10 * 0.94), (e * L / 2, 0, z0 + H / 10 * (i + 0.5)), tint(body, rng, 0.07), jit=0.004)
    p.box((1.1, 0.08, H - 0.4), (0.0, -Wd / 2 - 0.08, z0 + H / 2 - 0.05), C["timber_pale"] if v == "a" else TIMBER_D,
          rot=(0, 0, 0.0 if v != "c" else 0.08))
    for s in (-1, 1):
        for x in (-1.8, -0.6, 0.6, 1.8):
            p.box((0.1, 0.1, 0.8), (x, s * Wd / 2, z0 + H * 0.55), TIMBER_D)
        p.box((L, 0.1, 0.1), (0, s * Wd / 2, z0 + H * 0.4 + 0.04), TIMBER_D)
        p.box((L, 0.1, 0.1), (0, s * Wd / 2, z0 + H * 0.7 + 0.1), TIMBER_D)
    for k in range(9):
        a = -1.1 + k * 0.275
        if v == "c" and 3 <= k <= 5:
            continue
        p.box((L + 0.3, 0.55, 0.09), (0, math.sin(a) * Wd * 0.62, z0 + H + 0.1 + (math.cos(a) - 0.6) * 0.9),
              tint(PETROL if k % 2 else TIMBER_D, rng, 0.08), rot=(a, 0, 0), jit=0.004)
    for x in (-1.6, 0, 1.6):
        p.beam((x, -Wd * 0.58, z0 + H + 0.1), (x, 0, z0 + H + 0.62), 0.1, TIMBER_D)
        p.beam((x, Wd * 0.58, z0 + H + 0.1), (x, 0, z0 + H + 0.62), 0.1, TIMBER_D)
    p.box((0.7, 0.6, 0.3), (0, 0, z0 + H + 0.85), C["charcoal"], style="hard_smooth")
    p.cyl(0.14, 0.3, (0, 0, z0 + H + 1.1), COPPER, segs=8, style="hard_smooth")
    p.box((L - 0.8, 0.5, 0.15), (0, 0.7, z0 + 0.5), TIMBER)
    p.box((0.7, 0.5, 0.2), (0.0, -Wd / 2 - 0.6, 0.1), SAND_D, style="hard_smooth")
    p.cyl(0.14, 0.24, (0.0, -Wd / 2 - 0.62, 0.32), COPPER, segs=8, r2=0.17, style="hard_smooth")
    for s in (-1, 1):
        for x in (-L / 2 + 0.05, L / 2 - 0.05):
            p.box((0.14, 0.16, H), (x, s * Wd / 2, z0 + H / 2), OXIDE, style="hard_smooth")
        for x in (-1.5, 1.5):
            p.box((0.5, 0.05, 0.12), (x, s * Wd / 2 - s * 0.08, z0 + H * 0.28), BONE, style="hard_smooth")
    for i in range(9):
        p.box((0.4, Wd - 0.2, 0.05), (-1.8 + i * 0.45, 0, z0 + 0.03), tint(TIMBER_D, rng, 0.1), jit=0.004)
    p.box((L - 1.2, 0.45, 0.12), (0, -0.7, z0 + 0.45), TIMBER)
    for x in (-1.5, 1.5):
        p.box((0.14, 0.4, 0.45), (x, 0.7, z0 + 0.25), TIMBER_D)
        p.box((0.14, 0.4, 0.45), (x, -0.7, z0 + 0.25), TIMBER_D)
    coil(p, (1.3, 0.2, z0 + 0.05), 0.35, ROPE, rng, turns=2, tube=0.045)
    p.cyl(0.26, 0.4, (-2.0, -Wd / 2 - 0.5, 0.2), C["canvas_dark"], segs=10, r2=0.3, style="soft")
    for s in (-1, 1):
        for x in (-1.6, 1.6):
            p.box((0.4, 0.6, 0.18), (x, s * (Wd / 2 + 0.2), zf - 0.15), C["charcoal"], style="hard_smooth")
    for i in range(7 if v != "a" else 4):
        rock(p, (rng.uniform(-3.2, 3.2), rng.choice((-1, 1)) * rng.uniform(1.8, 2.8), 0.1), rng.uniform(0.2, 0.4),
             mix(SLICK_D, C["concrete"], 0.4), rng, 0.5, sub=1)
    if v == "c":
        p.ico(0.8, (1.6, -2.0, 0.4), C["leaf"], scale=(1.5, 1.2, 0.7))


@K.kind("net_bundle", tags=["rope", "ground"],
        story="Coiled ochre nets with cork floats and a mending needle left in the knots.", variants="abc")
def net_bundle(p, v, rng):
    n = {"a": 3, "b": 3, "c": 2}[v]
    for k in range(n):
        a = k * 2.0 + 0.3
        rr = 0.22 * k
        blob(p, 0.5, (rr * math.cos(a), rr * math.sin(a), 0.2 + 0.05 * k), tint(ROPE, rng, 0.08),
              scale=(1.4, 1.0, 0.55), rot=(0, 0, a))
    for k in range(5 if v != "c" else 2):
        p.torus(0.55, 0.035, (0, 0, 0.18), ROPE_D, rot=(0.25, 0.0, k * 0.7), major=14, minor=4, style="fine")
    p.box((1.5, 1.2, 0.08), (0, 0, 0.04), shade(ROPE, 0.85), rot=(0, 0, 0.3), style="fine")
    for _ in range(14 if v == "a" else 7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.1, 0.6)
        p.box((0.22, 0.03, 0.03), (d * math.cos(a), d * math.sin(a), 0.3 + 0.1 * rng.random()), ROPE_D, rot=(0, 0, rng.uniform(0, 3)), style="flat")
    for k in range(3 if v != "c" else 1):
        p.cyl(0.1, 0.16, (0.8 + 0.2 * k, -0.2 + 0.25 * k, 0.1), C["timber_pale"], segs=8, rot=(0, math.pi / 2, k), style="round")
    p.rod((-0.9, 0.3, 0.07), (-0.55, 0.45, 0.09), 0.035, C["bone"], segs=5, r2=0.015)
    if v == "a":
        coil(p, (1.0, 0.8, 0), 0.32, ROPE, rng, turns=2, tube=0.04)
    if v == "c":
        blades(p, (0.3, -0.5, 0), 22, 0.8, 0.4, rng, [C["dry_grass"], C["leaf"]])


@K.kind("mender_stool", tags=["furniture", "crew"],
        story="A three-legged stool and a knot board, the net-menders' spot, still a mug on the seat.", variants="abc")
def mender_stool(p, v, rng):
    h = 0.75
    ang = 0.0 if v != "c" else 0.0
    if v == "c":
        rt = (0, math.pi / 2 - 0.2, 0)
        p.cyl(0.4, 0.12, (0.2, 0, 0.45), TIMBER, segs=10, rot=rt, style="hard_smooth")
        for a in (0, 2.1, 4.2):
            p.rod((0.2, 0, 0.45), (0.2 + 0.1 * math.cos(a) - 0.5, 0.45 * math.sin(a), 0.1 + 0.2 * math.cos(a) + 0.2), 0.07, TIMBER_D, segs=6)
    else:
        p.cyl(0.4, 0.12, (0, 0, h), tint(TIMBER, rng), segs=10, style="hard_smooth")
        for a in (0.4, 2.5, 4.6):
            p.rod((0.18 * math.cos(a), 0.18 * math.sin(a), h - 0.02), (0.42 * math.cos(a), 0.42 * math.sin(a), 0.0),
                  0.07, TIMBER_D, segs=6, r2=0.06)
        p.torus(0.28, 0.025, (0, 0, 0.3), ROPE_D, major=12, minor=4, style="fine")
    if v == "a":
        p.cyl(0.08, 0.14, (0.1, 0.05, h + 0.13), C["canvas"], segs=8, style="round")
    bx, by = 0.95, 0.1
    p.box((1.0, 0.7, 0.08), (bx, by, 0.04), TIMBER_D, rot=(0, 0, 0.25 if v != "b" else 0.7), style="hard_smooth")
    for k in range(4):
        p.box((0.9, 0.035, 0.03), (bx + 0.0, by - 0.24 + k * 0.16, 0.1), ROPE, rot=(0, 0, 0.25 if v != "b" else 0.7), style="fine",
              jit=0.004)
    for k in range(5):
        a2 = 0.25 if v != "b" else 0.7
        xo = -0.4 + k * 0.2
        p.box((0.035, 0.6, 0.03), (bx + xo * math.cos(a2), by + xo * math.sin(a2), 0.115), ROPE_D, rot=(0, 0, a2), style="fine", jit=0.004)
    for k in range(3):
        p.torus(0.07, 0.02, (bx - 0.25 + k * 0.25, by + 0.1 * k - 0.1, 0.13), ROPE, major=8, minor=4, style="fine")
    coil(p, (-0.8, -0.5, 0), 0.3, ROPE, rng, turns=2, tube=0.035)
    if v == "b":
        blob(p, 0.3, (-0.5, 0.7, 0.18), C["leaf"], scale=(1.3, 1.1, 0.7))


@K.kind("chart_post", tags=["marker"],
        story="A pine-stump signpost with the roost chart painted on its flat top, nested ledges and arrows.", variants="abc")
def chart_post(p, v, rng):
    h = {"a": 1.3, "b": 1.2, "c": 0.7}[v]
    p.cyl(0.42, h, (0, 0, h / 2), BARK, segs=10, r2=0.34, style="hard_smooth", jit=0.02)
    for k in range(7):
        a = k * 0.9
        p.rod((0.34 * math.cos(a), 0.34 * math.sin(a), 0.05), (0.38 * math.cos(a), 0.38 * math.sin(a), h - 0.05), 0.04, shade(BARK, 0.8), segs=4)
    tz = h + 0.005
    tl = 0.0 if v != "b" else 0.25
    p.cyl(0.36, 0.04, (0.0, 0.0, tz), C["canvas"] if v != "c" else C["canvas_dark"], segs=12, style="flat", rot=(tl, 0, 0))
    for k in range(4):
        p.box((0.5 - 0.06 * k, 0.018, 0.012), (0.0, -0.2 + k * 0.1, tz + 0.03), C["timber_grey"], style="flat",
              rot=(tl, 0, 0.0))
    p.box((0.02, 0.4, 0.012), (0.12, 0.0, tz + 0.03), C["timber_grey"], style="flat", rot=(tl, 0, 0.0))
    p.beam((0.2, 0.0, h * 0.7), (0.9, -0.1, h * 0.65), 0.18, TIMBER_D, h=0.14)
    if v == "c":
        blob(p, 0.4, (0.6, 0.5, 0.2), C["leaf"], scale=(1.4, 1.2, 0.8))
    for i in range(3):
        rock(p, (rng.uniform(-0.9, 0.9), rng.uniform(-0.9, -0.5), 0.07), rng.uniform(0.12, 0.22), SLICK, rng, 0.5)


@K.kind("ore_trolley", tags=["machine", "debris"],
        story="One parked ore bin on its stub axles, no rails anywhere, ore still heaped in it.", variants="abc")
def ore_trolley(p, v, rng):
    tilt = {"a": 0.0, "b": 0.12, "c": 0.0}[v]
    zc = 0.65 if v != "c" else 0.3
    p.cyl(0.62, 0.7, (0, 0, zc), PETROL, segs=12, r2=0.78,
          rot=(0, tilt, 0) if v != "c" else (0.0, 1.3, 0.0), style="hard_smooth")
    if v != "c":
        p.torus(0.78, 0.05, (0, 0, zc + 0.35), BONE, rot=(0, tilt, 0), major=14, minor=5, style="fine")
        for k in range(5):
            rock(p, (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), zc + 0.35 + 0.05 * k), rng.uniform(0.15, 0.25),
                 mix(SAND_D, C["concrete_dark"], 0.3), rng, 0.8)
    for s in (-1, 1):
        p.cyl(0.34, 0.14, (0, s * 0.72, 0.34), TIMBER_D if v != "c" else C["charcoal"], segs=10, rot=(math.pi / 2, 0, 0), style="hard_smooth")
        p.cyl(0.1, 0.18, (0, s * 0.72, 0.34), COPPER, segs=8, rot=(math.pi / 2, 0, 0), style="round")
    p.cyl(0.05, 1.2, (0, 0, 0.34), OXIDE, segs=6, rot=(math.pi / 2, 0, 0), style="round")
    p.box((1.3, 0.3, 0.12), (0, 0, 0.1), TIMBER_D)
    p.box((0.4, 0.3, 0.2), (0.95, 0, 0.1), TIMBER_D)
    p.box((0.4, 0.3, 0.2), (-0.95, 0, 0.1), TIMBER_D)
    if v == "b":
        for k in range(3):
            rock(p, (-1.0 + k * 0.25, -1.0, 0.1), 0.18, SAND_D, rng, 0.6)
    if v == "c":
        p.torus(0.76, 0.05, (0.33, 0, zc), BONE, rot=(0, 1.3, 0), major=14, minor=5, style="fine")
        for k in range(4):
            rock(p, (0.9 + 0.25 * k, rng.uniform(-0.1, 0.1) * (k + 1), 0.12), rng.uniform(0.13, 0.26), SAND_D, rng, 0.6)
        blades(p, (-0.2, 0.9, 0), 10, 0.7, 0.3, rng, [C["dry_grass"], C["leaf"]])


@K.kind("stair_stones", tags=["marker", "ground"],
        story="Flat marker stones with the hikers' stair counts scratched in, worn nearly smooth.", variants="abc")
def stair_stones(p, v, rng):
    n = {"a": 4, "b": 3, "c": 3}[v]
    for k in range(n):
        x = k * 0.85 - (n - 1) * 0.42
        y = 0.12 * math.sin(k * 1.7)
        a = rng.uniform(-0.15, 0.15)
        h = 0.14 + 0.03 * rng.random()
        sx = rng.uniform(0.6, 0.8)
        p.box((sx, sx * 0.9, h), (x, y, h / 2), tint(SLICK if v != "c" else SLICK_D, rng, 0.07), rot=(0, 0, a), style="hard_smooth", jit=0.012)
        for s in range(min(k + 1, 4)):
            p.box((0.05, 0.28, 0.02), (x - 0.15 + s * 0.1, y, h + 0.005), SLICK_D if v != "c" else C["concrete_dark"], rot=(0, 0, a), style="flat")
        if v == "b" and k == 1:
            p.box((sx * 0.8, sx * 0.7, h * 0.7), (x + 0.55, y - 0.35, h * 0.3), SLICK_D, rot=(0.2, 0.1, 0.8), style="hard_smooth")
    if v == "c":
        for _ in range(3):
            tuft_clump(p, (rng.uniform(-1.3, 1.3), rng.uniform(-0.6, 0.6), 0), rng, 0.5)
    for _ in range(4):
        rock(p, (rng.uniform(-1.6, 1.6), rng.uniform(-0.8, 0.8), 0.06), rng.uniform(0.08, 0.16), SLICK, rng, 0.5)


@K.kind("winch_drum", tags=["machine", "fleet"],
        story="The Fleet's mooring winch: a petrol drum wound with neat rope in a petrol housing, oxide rims, one brass tag.", variants="ab")
def winch_drum(p, v, rng):
    p.box((1.9, 1.2, 0.2), (0, 0, 0.1), C["charcoal"], style="hard")
    for sx in (-0.75, 0.75):
        p.box((0.22, 1.0, 0.8), (sx, 0, 0.6), PETROL if sx < 0 else BONE, style="hard")
    p.cyl(0.45, 1.3, (0, 0, 0.7), PETROL, segs=14, rot=(0, math.pi / 2, 0), style="hard")
    for sx in (-0.55, 0.55):
        p.cyl(0.62, 0.1, (sx, 0, 0.7), OXIDE, segs=14, rot=(0, math.pi / 2, 0), style="hard")
    if v == "a":
        for k in range(6):
            p.torus(0.5, 0.05, (-0.4 + k * 0.16, 0, 0.7), ROPE, rot=(0, math.pi / 2, 0), major=12, minor=4, style="fine")
        p.rod((0.5, -0.4, 0.4), (1.3, -0.9, 0.06), 0.045, ROPE, segs=5)
        coil(p, (1.2, -0.9, 0), 0.32, ROPE, rng, turns=2, tube=0.04)
    else:
        for k in range(3):
            p.torus(0.48 - 0.01 * k, 0.05, (-0.1 + k * 0.16, 0, 0.7), mix(ROPE, C["rust"], 0.3), rot=(0, math.pi / 2 + 0.2, 0.0), major=12, minor=4, style="fine")
        for k in range(3):
            blob(p, 0.25, (0.4 + 0.2 * k, -0.7 + 0.1 * k, 0.2), mix(ROPE, C["canvas_dark"], 0.3), scale=(1.5, 1.0, 0.5), rot=(0, 0, k))
        p.rod((0.3, 0.3, 0.4), (-1.0, 0.8, 0.06), 0.045, ROPE_D, segs=5)
    p.box((0.18, 0.04, 0.12), (0, -0.52, 0.55), BRASS, style="flat")
    p.cyl(0.07, 0.4, (0.85, 0.3, 0.88), COPPER, segs=8, rot=(0.0, 0.9, 0.0), style="round")
    p.cyl(0.06, 0.16, (1.0, 0.3, 1.0), COPPER, segs=8, style="round")
    p.cyl(0.07, 0.8, (0.0, 0.0, 0.75), C["charcoal"], segs=8, rot=(0, math.pi / 2, 0), style="round")


@K.kind("rope_basket", tags=["crew", "ground"],
        story="A wicker lantern basket set on the ground, unlit, a rope bale beside it.", variants="abc")
def rope_basket(p, v, rng):
    h = 0.55
    tip = {"a": 0.0, "b": 1.2, "c": 0.0}[v]
    zb = 0 if v != "b" else 0.28
    p.cyl(0.32, h, (0, 0, zb + h / 2), WICKER, segs=10, r2=0.26, rot=(0, tip, 0), style="round")
    for k in range(3):
        p.torus(0.29 - 0.02 * k, 0.025, (0, 0, zb + 0.12 + 0.17 * k), shade(WICKER, 0.9), rot=(0, tip, 0), major=10, minor=4, style="fine")
    if v != "b":
        p.uv(0.18, (0, 0, h + 0.1), C["concrete_dark"], scale=(1, 1, 1.2), style="round")
        p.torus(0.14, 0.03, (0, 0, h + 0.3), C["iron"], major=10, minor=4, style="fine")
    else:
        p.uv(0.15, (0.55, 0.2, 0.15), C["concrete_dark"], scale=(1, 1, 1.1), style="round")
    p.cyl(0.26, 0.3, (-0.75, 0.2, 0.15), ROPE, segs=10, style="hard_smooth")
    for k in range(3):
        p.torus(0.27, 0.025, (-0.75, 0.2, 0.05 + 0.1 * k), ROPE_D, major=10, minor=4, style="fine")
    if v == "c":
        tuft_clump(p, (0.4, 0.4, 0), rng, 0.8)
        blades(p, (0, -0.1, 0), 10, 0.8, 0.3, rng, [C["leaf"], C["dry_grass"]])
    if v == "a":
        coil(p, (0.5, -0.6, 0), 0.25, ROPE, rng, turns=2, tube=0.035)


@K.kind("pine_sapling", tags=["plant"],
        story="A relict pine seedling, three tiers of needles, rooted in slickrock cracks.", variants="abc")
def pine_sapling(p, v, rng):
    h = {"a": 1.0, "b": 1.3, "c": 0.7}[v]
    tiers = {"a": 3, "b": 4, "c": 2}[v]
    lean = {"a": 0.0, "b": 0.12, "c": 0.3}[v]
    p.rod((0, 0, 0), (lean * h * 0.4, 0, h), 0.06 * (1.3 if v == "b" else 1.0), BARK, segs=5, r2=0.025)
    for k in range(tiers):
        t = k / max(tiers - 1, 1)
        r = (0.55 - 0.3 * t) * (h / 1.0) ** 0.5
        p.cyl(r, 0.4, (lean * h * 0.4 * (0.15 + 0.85 * t), 0, 0.3 + (h - 0.4) * t), tint(PINE if k % 2 else PINE_D, rng, 0.08),
              segs=7, r2=r * 0.15, rot=(0, 0, rng.uniform(0, 1)), style="soft")
    rock(p, (0.25, 0.1, 0.1), 0.28, SLICK, rng, 0.55)
    rock(p, (-0.35, -0.05, 0.08), 0.22, SLICK_D, rng, 0.5)
    if v == "c":
        p.rod((0.1, 0.0, 0.1), (0.7, 0.15, 0.2), 0.04, BARK, segs=4)


@K.kind("manzanita", tags=["plant"],
        story="Red-barked manzanita, twisted bare limbs and pale green leaf-clouds on a ledge.", variants="abc")
def manzanita(p, v, rng):
    n = {"a": 5, "b": 4, "c": 5}[v]
    for k in range(n):
        a = k * math.tau / n + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.4, 0.8)
        mid = (0.5 * r * math.cos(a), 0.5 * r * math.sin(a), 0.5)
        end = (r * math.cos(a + 0.4), r * math.sin(a + 0.4), 0.9 + 0.25 * rng.random())
        p.rod((0, 0, 0.0), mid, 0.07, BARK, segs=5, r2=0.05)
        p.rod(mid, end, 0.05, shade(BARK, 1.1), segs=5, r2=0.03)
        if v != "b" or k != 0:
            blob(p, 0.33, (end[0], end[1], end[2] + 0.1), tint(C["leaf"] if v != "c" else mix(C["leaf"], C["dry_grass"], 0.4), rng, 0.08),
                  scale=(1.35, 1.35, 0.6))
    p.cyl(0.14, 0.2, (0, 0, 0.1), BARK, segs=7, r2=0.1)
    rock(p, (0.5, -0.5, 0.1), 0.26, SLICK, rng, 0.55)
    if v == "c":
        for _ in range(3):
            p.box((0.1, 0.1, 0.07), (rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), 0.04), BARK, style="hard_smooth")


@K.kind("grass_tufts", tags=["plant", "ground"],
        story="Dry bunchgrass tufts in the slickrock cracks, the bits of green low and tight.", variants="abc")
def grass_tufts(p, v, rng):
    n = {"a": 3, "b": 3, "c": 2}[v]
    for k in range(n):
        c = (rng.uniform(-0.9, 0.9), rng.uniform(-0.6, 0.6), 0)
        blades(p, c, 22 if v != "c" else 30, {"a": 0.8, "b": 0.55, "c": 1.2}[v], 0.3, rng,
               [C["dry_grass"], C["leaf"]] if v == "a" else ([C["dry_grass"], mix(C["dry_grass"], C["canvas_dark"], 0.5)] if v == "b" else [C["leaf"], C["leaf_dark"], C["dry_grass"]]))
    for k in range(2 + (v == "b")):
        rock(p, (rng.uniform(-1, 1), rng.uniform(-0.7, 0.7), 0.06), rng.uniform(0.12, 0.25), SLICK, rng, 0.45)


@K.kind("patch_bolt", tags=["crew", "ground"],
        story="A bolt of patch canvas and a tin sewing kit spilled on a flat rock, needles, thread and buttons.", variants="abc")
def patch_bolt(p, v, rng):
    rock(p, (0, 0, 0.08), 0.75, SLICK, rng, 0.25, sub=1)
    zr = 0.2
    if v != "c":
        p.cyl(0.17, 0.75, (-0.15, 0.05, zr + 0.17), PATCH_A, segs=10, rot=(0, math.pi / 2, 0.2), style="round")
        p.cyl(0.06, 0.78, (-0.15, 0.05, zr + 0.17), TIMBER, segs=6, rot=(0, math.pi / 2, 0.2), style="round")
        p.box((0.7, 0.55, 0.025), (0.45, -0.1, zr + 0.015), PATCH_B if v == "a" else PATCH_C, rot=(0, 0, 0.3), style="soft", jit=0.01)
    if v == "b":
        blob(p, 0.3, (0.1, 0.4, zr + 0.07), PATCH_C, scale=(1.5, 1.2, 0.3), style="soft")
    p.cyl(0.17, 0.12, (0.4, 0.35, zr + 0.06), C["iron_light"], segs=10, style="hard")
    p.cyl(0.19, 0.04, (0.7, 0.45, zr + 0.02), C["iron"], segs=10, rot=(0.1, 0, 0), style="hard")
    p.cyl(0.06, 0.1, (0.25, 0.12, zr + 0.05), ROPE_D, segs=8, style="round")
    p.uv(0.09, (0.45, 0.35, zr + 0.13), C["rust"] if v == "a" else C["canvas_stain"], scale=(1, 1, 0.7), style="soft")
    p.rod((-0.55, 0.3, zr + 0.02), (-0.3, 0.38, zr + 0.02), 0.012, C["bone"], segs=4)
    if v == "c":
        blob(p, 0.3, (-0.2, 0.0, zr + 0.05), PATCH_B, scale=(1.5, 1.0, 0.25), style="soft")
        tuft_clump(p, (-0.5, -0.4, 0), rng, 0.45)


@K.kind("stone_scatter", tags=["rock", "ground"],
        story="Slickrock cobbles and a cairn kicked half over; the mesa is always shedding.", variants="abc")
def stone_scatter(p, v, rng):
    n = {"a": 6, "b": 8, "c": 5}[v]
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 1.3)
        r = rng.uniform(0.15, 0.4) if v != "c" else rng.uniform(0.2, 0.5)
        col = rng.choice([SLICK, SLICK_D, SAND, SAND_D])
        rock(p, (d * math.cos(a), d * math.sin(a), r * 0.25), r, col, rng, 0.55)
    if v == "a":
        for k, (r, z) in enumerate(((0.3, 0.12), (0.22, 0.34), (0.15, 0.52))):
            rock(p, (0.0, 0.0, z), r, SLICK if k != 1 else SAND_P, rng, 0.7)
    if v == "b":
        for k in range(3):
            blob(p, 0.18, (1.1 + 0.2 * k, -0.6 - 0.15 * k, 0.1), SLICK_D, scale=(1.3, 1.0, 0.6), style="round")
    if v == "c":
        tuft_clump(p, (0.6, 0.6, 0), rng, 0.8)


if __name__ == "__main__":
    K.main()
