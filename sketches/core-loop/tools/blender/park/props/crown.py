"""Crown park dressing kit (Dressing lane; contract: design-v3/park/DRESSING-KITS.md).

Highdraft at dusk under a storm cell: the net-weavers (ochre rope, hammocks, looms; builders
only, no faces) and the Fleet signal crew (petrol enamel bodies, copper fittings, oxide patches, one brass tag; abandoned
equipment, never a camp). The ancient spires are never touched, so the kit has none.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/crown.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, shade, tint

K = kit.Kit("crown")

C.update({
    "ochre": "b49d6a", "ochre_dark": "857248", "ochre_pale": "cdb98a",
    "sage": "9aa58a", "sage_dark": "6f7d5f", "sage_pale": "b9c2a8",
    "oxide": mix("9b513a", "c9c1ae", 0.64), "oxide_dark": mix("74402f", "a79e83", 0.5),
    "brass": "d9b44a",
    "petrol": "365754", "copper": "b77843",
    "glass": "aaa496", "glass_dark": "8c8678", "chalk": "ece6d2",
    "flower": "c8b865", "slate": "2f3634", "steam": "cfccc2",
})
C.update({"timber": shade(C["timber"], 1.14), "timber_dark": shade(C["timber_dark"], 1.15),
          "timber_pale": shade(C["timber_pale"], 1.04), "sage": "a3ad8f", "sage_dark": "7a8a66"})
PETROL, PETROL_LT, COPPER = C["petrol"], shade(C["petrol"], 1.3), C["copper"]
OXIDE, CHAR, BRASS = C["oxide"], C["charcoal"], C["brass"]
TAU = math.tau

_ico, _torus, _rod = kit.Prop.ico, kit.Prop.torus, kit.Prop.rod


def _ico_lo(self, radius, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=1, style="soft", jit=0):
    return _ico(self, radius, loc, color, scale=scale, rot=rot, subdiv=0 if style == "soft" else min(subdiv, 1),
                style=style, jit=jit)


def _torus_lo(self, big, small, loc, color, rot=(0, 0, 0), scale=(1, 1, 1), major=12, minor=5, style="flat", jit=0):
    return _torus(self, big, small, loc, color, rot=rot, scale=scale, major=major, minor=minor, style=style, jit=jit or 0.0015)


_do = kit.Prop._do


def _do_jit(self, style, method, color, jit, *args, **kwargs):
    return _do(self, style, method, color, jit or 0.0015, *args, **kwargs)


kit.Prop.ico, kit.Prop.torus, kit.Prop._do = _ico_lo, _torus_lo, _do_jit


def rope(p, a, b, r, col, sag=0.0, n=6, segs=4):
    """Hanging rope from a to b as short rods, sagging by `sag` metres. Never taut."""
    pts = []
    for k in range(n + 1):
        t = k / n
        pts.append(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))
        pts[-1] = (pts[-1][0], pts[-1][1], pts[-1][2] - sag * 4 * t * (1 - t))
    for q, w in zip(pts, pts[1:]):
        p.rod(q, w, r, col, segs=segs, style="flat")
    return pts


def net(p, x0, x1, z0, z1, y, nx, nz, r, col, rng, sag=0.0, hole=None, drop=0.0):
    """Net panel in the plane y: nx x nz grid of rods, bellying in y by `sag`; `hole` is
    (cx, cz, rad) where knots are cut; `drop` lowers the middle (slack)."""
    def pt(i, j):
        u, w = i / nx, j / nz
        bulge = sag * math.sin(math.pi * u) * math.sin(math.pi * w)
        return (x0 + (x1 - x0) * u, y - bulge, z0 + (z1 - z0) * w - drop * math.sin(math.pi * u) * w)
    def cut(i, j):
        if not hole:
            return False
        q = pt(i, j)
        return math.hypot(q[0] - hole[0], q[2] - hole[1]) < hole[2]
    for i in range(nx + 1):
        for j in range(nz):
            if not (cut(i, j) or cut(i, j + 1)):
                p.rod(pt(i, j), pt(i, j + 1), r, col, segs=4, style="flat")
    for j in range(nz + 1):
        for i in range(nx):
            if not (cut(i, j) or cut(i + 1, j)):
                p.rod(pt(i, j), pt(i + 1, j), r, col, segs=4, style="flat")


def bobbin(p, loc, col, thread, rot=(0, 0, 0)):
    """Chunky thread bobbin: two flanges and a wound barrel."""
    x, y, z = loc
    p.cyl(0.22, 0.07, (x, y, z - 0.18), C["timber_dark"], segs=10, rot=rot)
    p.cyl(0.22, 0.07, (x, y, z + 0.18), C["timber_dark"], segs=10, rot=rot)
    p.cyl(0.19, 0.3, (x, y, z), thread, segs=10, style="round", rot=rot)


def tarp(p, loc, size, col, rng, rot=(0, 0, 0)):
    """Soft draped cloth: a flattened blob."""
    p.ico(0.5, loc, col, scale=(size[0], size[1], size[2]), rot=rot, subdiv=2, style="soft")


def pennant(p, root, length, col, up=0.0):
    """Long triangle pennant from a stake top, pointing +x, drooping by `up` (negative = hang)."""
    x, y, z = root
    tip = (x + length, y, z + up)
    mid = (x + length * 0.5, y, z + up * 0.45)
    p.prism([(0, 0.0), (length, up * 0.8 * 0), (0, -0.55)], 0.03, (x, y, z - 0.0), col, rot=(math.pi / 2, 0, 0), style="flat")
    return tip, mid


@K.kind("loom_frame", hero=True, variants="abc", tags=["machine", "soft"],
        story="Net-weavers' floor loom: chunky bobbins on the bed and a half-woven ochre net in a leaning frame.")
def loom_frame(p, v, rng):
    T, TD = C["timber"], C["timber_dark"]
    rope_c = C["ochre"]
    lean = 0.16
    for y in (-1.3, 1.3):
        p.box((5.6, 0.38, 0.3), (0, y, 0.15), tint(TD, rng), style="hard_smooth")
    for x in (-2.5, 2.5):
        p.box((0.36, 3.2, 0.26), (x, 0, 0.13), tint(TD, rng), style="hard_smooth")
    if v == "c":
        p.beam((-2.1, 1.0, 0.3), (-2.0, 1.5, 3.4), 0.3, tint(T, rng), h=0.26)
        p.beam((2.3, -0.4, 0.4), (-0.6, 0.9, 0.55), 0.3, tint(T, rng), h=0.26)
        p.beam((-1.0, 0.9, 0.7), (1.9, 1.7, 0.45), 0.24, TD, h=0.2)
        p.box((3.2, 1.2, 0.2), (0.2, -0.6, 0.42), tint(C["timber_pale"], rng), rot=(0, 0, 0.12))
        for k in range(6):
            tarp(p, (rng.uniform(-1.2, 1.4), rng.uniform(0.1, 1.3), 0.35 + 0.13 * k % 0.4), (1.2, 0.9, 0.35), tint(rope_c, rng, 0.1), rng, rot=(0, 0, rng.uniform(0, 3)))
        net(p, -1.8, 1.4, 0.38, 0.9, -0.4, 14, 5, 0.035, rope_c, rng, sag=0.2, hole=(0.2, 0.7, 0.5), drop=0.15)
        for k, (x, y) in enumerate(((-2.3, -2.0), (0.9, -2.2), (2.4, -1.8), (-0.4, -2.5))):
            bobbin(p, (x, y, 0.22), None, tint(rope_c, rng), rot=(0, math.pi / 2, rng.uniform(0, 3)))
        tarp(p, (1.5, 1.9, 0.25), (2.4, 1.3, 0.3), C["canvas_dark"], rng, rot=(0, 0, 0.4))
        return
    for x in (-2.0, 2.0):
        for y in (-0.8, 0.0):
            p.beam((x, y, 0.28), (x, y, 1.15), 0.3, tint(T, rng), h=0.3)
    p.box((4.7, 1.3, 0.22), (0, -0.4, 1.25), tint(C["timber_pale"], rng), style="hard_smooth")
    p.box((4.8, 0.2, 0.34), (0, -1.05, 1.18), tint(TD, rng), style="hard_smooth")
    n_bob = 6 if v == "a" else 4
    for k in range(n_bob):
        bobbin(p, (-1.7 + 0.62 * k, -0.45 + 0.14 * (k % 2), 1.58), None,
               tint(rope_c if v == "a" or k % 2 else C["ochre_dark"], rng, 0.1))
    p.rod((-2.0, -0.95, 1.43), (1.2, -0.9, 1.43), 0.08, TD)
    top = 4.5
    for s in (-1, 1):
        base = (s * 2.15, 0.85, 0.3)
        tp = (s * 2.15, 0.85 + lean * (top - 0.3), top)
        if v == "b" and s == 1:
            tp = (s * 2.15, 0.85 + lean * (top - 0.3) + 0.5, top - 0.35)
        p.beam(base, tp, 0.34, tint(T, rng), h=0.3)
        p.beam((s * 2.15, 1.7, 0.3), (s * 2.15, 0.85 + lean * 2.0, 2.3), 0.2, tint(TD, rng), h=0.18)
        p.beam((s * 2.15, -0.9, 0.28), (s * 2.15, 0.9, 2.2), 0.2, tint(TD, rng), h=0.18)
    yb = 0.85 + lean * (top - 0.3)
    p.beam((-2.35, yb, top - 0.1), (2.35 + (0.0), yb + (0.5 if v == "b" else 0), top - (0.35 if v == "b" else 0.1)),
           0.34, tint(TD, rng), h=0.3)
    p.beam((-2.3, 0.85 + lean * 1.9, 2.3), (2.3, 0.85 + lean * 1.9, 2.3), 0.26, tint(TD, rng), h=0.22)
    p.beam((0, 0.9 + lean * 1.4, 1.3), (0, 1.0 + lean * 3.0, 3.9), 0.22, tint(T, rng), h=0.2)
    ymid = 0.85 + lean * 2.4
    n_warp = 17
    for i in range(n_warp):
        x = -1.85 + 3.7 * i / (n_warp - 1)
        z1 = top - 0.25 - (0.35 if v == "b" and i > 11 else 0)
        p.rod((x, 0.85 + lean * 1.0, 0.9), (x, ymid + lean * (z1 - 2.4), z1), 0.032, C["ochre_dark"], segs=4, style="flat")
    woven_top = 3.3 if v == "a" else 2.0
    rows = 11 if v == "a" else 6
    for j in range(rows):
        z = 1.1 + (woven_top - 1.1) * j / (rows - 1)
        y = 0.85 + lean * (z - 0.3) - 0.04
        for i in range(n_warp - 1):
            if v == "b" and j == rows - 1 and i % 3 == 0:
                continue
            x0 = -1.85 + 3.7 * i / (n_warp - 1)
            x1 = -1.85 + 3.7 * (i + 1) / (n_warp - 1)
            p.rod((x0, y, z), (x1, y, z + (0.02 if i % 2 else 0)), 0.04, rope_c, segs=4, style="flat")
    if v == "b":
        net(p, -1.4, 1.2, 1.1, 2.0, 0.6, 10, 5, 0.035, C["ochre_dark"], rng, sag=0.15, hole=(0.2, 1.6, 0.45), drop=0.3)
        tarp(p, (1.4, -1.7, 0.2), (1.5, 1.0, 0.3), C["canvas_dark"], rng, rot=(0, 0, 0.3))
    else:
        tarp(p, (-0.6, yb + 0.5, top - 0.55), (2.7, 1.0, 0.1), C["canvas"], rng, rot=(0.5, 0, 0))
        rope(p, (-2.2, yb + 0.1, top - 0.2), (-2.5, 2.2, 0.4), 0.05, rope_c, sag=0.2)
        tarp(p, (1.6, -1.8, 0.3), (1.0, 0.8, 0.5), C["canvas"], rng)
    for k in range(3):
        p.torus(0.45 - 0.07 * k, 0.07, (-1.4, -2.1, 0.12 + 0.12 * k), rope_c, major=14, minor=5)
    p.torus(0.5, 0.08, (1.3, -2.2, 0.1), tint(C["ochre_dark"], rng), major=14, minor=5)


@K.kind("billing_booth", hero=True, variants="abc", tags=["machine", "sign"],
        story="Fleet signal crew's tally hut: faded petrol-enamel walls patched with oxide and timber, a chalkboard counting ELEVEN against TWELVE, abandoned mid-shift.")
def billing_booth(p, v, rng):
    W, D, H = 4.4, 3.4, 2.6
    p.box((W + 0.4, D + 0.4, 0.32), (0, 0, 0.16), C["concrete"], style="hard_smooth")
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            p.beam((x, y, 0.3), (x, y, H + 0.3), 0.26, CHAR)
    for i in range(20):
        x = -W / 2 + 0.2 + i * (W - 0.4) / 19
        hh = H - (0.0 if not (v == "c" and i > 14) else 1.3)
        p.box((0.22, 0.12, hh), (x, D / 2, 0.3 + hh / 2), tint(PETROL if i % 5 else PETROL_LT, rng, 0.05), jit=0.004)
    for s in (-1, 1):
        for i in range(15):
            y = -D / 2 + 0.2 + i * (D - 0.4) / 14
            if v == "b" and s == 1 and i in (6, 7):
                continue
            p.box((0.12, 0.22, H), (s * W / 2, y, 0.3 + H / 2), tint(PETROL_LT if (i % 4 == 0) else PETROL, rng, 0.05), jit=0.004)
    for (px, py, pw, ph, pz) in ((-1.2, D / 2 + 0.09, 0.9, 0.7, 1.4), (1.3, D / 2 + 0.09, 0.6, 1.1, 0.9)):
        p.box((pw, 0.07, ph), (px, py, pz), tint(C["timber_pale"], rng, 0.1), rot=(0, 0.04, 0.05), style="hard_smooth")
    p.box((0.07, 1.1, 0.5), (W / 2 + 0.09, -0.4, 1.1), tint(C["timber"], rng, 0.1), rot=(0.05, 0, 0), style="hard_smooth")
    if v in "bc":
        p.box((0.1, 0.9, 1.1), (W / 2 + 0.05, 0.9, 0.75), C["timber_dark"], rot=(0.35, 0.2, 0), style="hard_smooth")
        p.box((0.1, 0.12, 0.9), (W / 2 + 0.25, 1.1, 0.5), C["timber_grey"], rot=(0.3, 0.3, 0.2), style="hard_smooth")
    for i in range(20):
        x = -W / 2 + 0.2 + i * (W - 0.4) / 19
        window = -0.5 < x < 0.9
        if window:
            p.box((0.22, 0.12, 0.9), (x, -D / 2, 0.75), tint(PETROL, rng, 0.05))
            p.box((0.22, 0.12, 0.45), (x, -D / 2, H - 0.05), tint(PETROL, rng, 0.05))
        else:
            p.box((0.22, 0.12, H), (x, -D / 2, 0.3 + H / 2), tint(PETROL if i % 5 else PETROL_LT, rng, 0.05))
    p.box((1.8, 0.5, 0.1), (0.2, -D / 2 - 0.25, 1.25), C["timber_pale"])
    p.box((0.8, 0.05, 0.6), (-1.7, -D / 2 - 0.09, 1.6), tint(OXIDE, rng, 0.06), rot=(0, 0.03, 0.04), style="hard_smooth")
    p.box((0.6, 0.05, 0.9), (1.7, -D / 2 - 0.09, 1.1), tint(C["oxide_dark"], rng, 0.06), rot=(0, 0.03, -0.05), style="hard_smooth")
    rise, half = 0.95, D / 2 + 0.35
    th = math.atan2(rise, half)
    for s in (-1, 1):
        for r in range(7):
            t = (r + 0.5) / 7
            if v == "c" and s == -1 and r > 2:
                continue
            sag_d = 0.3 * (1 - 0.5 * t) if (v == "b" and s == 1) else 0.0
            p.box((W + 0.5, 0.58, 0.09), (0, s * half * (1 - t), H + 0.28 + rise * t - sag_d), tint(C["slate"], rng, 0.1),
                  rot=(-s * th + (0.12 if sag_d else 0.0), 0, 0), jit=0.004)
    p.beam((-W / 2 - 0.25, 0, H + 0.28 + rise), (W / 2 + 0.25, 0, H + 0.28 + rise), 0.18, CHAR)
    p.cyl(0.14, 0.8, (-1.4, 0.9, H + 1.1), COPPER, segs=8, r2=0.12, style="hard_smooth")
    bx, by, bz = 2.9, -D / 2 - 1.25, 1.55
    for s in (-1, 1):
        p.beam((bx + s * 0.75, by, 0.3), (bx + s * 0.75, by, bz + 0.75), 0.14, C["timber_dark"])
    if v == "c":
        bz, by = 0.45, by - 0.3
        p.box((1.9, 1.3, 0.1), (bx, by, 0.32), C["slate"], rot=(0, 0, 0.35), style="hard_smooth")
        tally = False
    else:
        p.box((1.8, 0.1, 1.3), (bx, by - 0.02, bz), C["slate"], style="hard_smooth")
        p.box((1.9, 0.12, 0.08), (bx, by - 0.05, bz + 0.69), C["timber_dark"])
        p.box((1.9, 0.12, 0.08), (bx, by - 0.05, bz - 0.69), C["timber_dark"])
        tally = True
    if tally:
        for col, count in ((-0.45, 11), (0.45, 12)):
            if v == "b" and col > 0:
                count -= 4
            for k in range(count):
                r, c = divmod(k, 5)
                p.box((0.035, 0.03, 0.28), (bx + col - 0.2 + c * 0.1, by - 0.1, bz + 0.35 - r * 0.33), C["chalk"], style="fine")
                if c == 4:
                    p.box((0.5, 0.03, 0.035), (bx + col, by - 0.1, bz + 0.35 - r * 0.33), C["chalk"], rot=(0, 0.4, 0), style="fine")
        p.box((0.8, 0.03, 0.05), (bx, by - 0.1, bz - 0.55), C["chalk"], style="fine")
    for s_ in (-1, 1):
        p.box((0.12, 0.14, 1.0), (0.2 + s_ * 0.75, -D / 2 - 0.1, 0.75 + 0.45), CHAR, style="hard_smooth")
        p.box((0.5, 0.06, 0.95), (0.2 + s_ * 1.05, -D / 2 - 0.13, 1.2), tint(C["oxide_dark"], rng), rot=(0, 0, (0.0 if v == "a" else s_ * 0.5)), style="hard_smooth")
    p.box((1.9, 0.14, 0.12), (0.2, -D / 2 - 0.1, 0.78), CHAR, style="hard_smooth")
    p.box((1.9, 0.14, 0.12), (0.2, -D / 2 - 0.1, 1.75), CHAR, style="hard_smooth")
    for x in (-W / 2 + 0.3, 0.0, W / 2 - 0.3):
        for s_ in (-1, 1):
            p.beam((x, s_ * (D / 2 + 0.1), H + 0.25), (x, s_ * (D / 2 + 0.55), H + 0.05), 0.12, CHAR, h=0.1)
    p.box((1.6, 0.4, 0.1), (-1.3, -D / 2 - 0.9, 0.55), C["timber_pale"], style="hard_smooth")
    for x in (-1.9, -0.7):
        p.box((0.12, 0.34, 0.5), (x, -D / 2 - 0.9, 0.25), C["timber_dark"], style="hard")
    for k in range(3):
        p.torus(0.42 - 0.04 * k, 0.07, (-0.2, -D / 2 - 1.0, 0.08 + 0.1 * k), CHAR, major=14, minor=5, style="round")
    p.box((0.2, 0.05, 0.28), (-W / 2 + 0.06, -D / 2 - 0.1, 1.8), BRASS, style="hard_smooth")
    p.box((0.1, 1.0, 1.9), (-W / 2 - 0.07, 0.2, 1.25), tint(C["oxide_dark"], rng), style="hard_smooth")
    p.cyl(0.35, 0.5, (-W / 2 - 0.95, -0.6, 0.55), C["timber"], segs=10, style="hard_smooth")
    p.cyl(0.09, 0.15, (-W / 2 - 0.95, -0.55, 0.88), C["sage_pale"], segs=10, style="round")
    if v == "b":
        p.ico(0.8, (0.5, 0.4, H + 1.0), C["canvas_dark"], scale=(1.6, 1.0, 0.18), rot=(0.4, 0, 0.1), style="soft")
        p.box((1.5, 0.28, 0.08), (-1.0, -D / 2 - 1.1, 0.12), C["timber_grey"], rot=(0, 0, 0.35))
    elif v == "a":
        p.ico(0.5, (-W / 2 - 0.14, -0.9, 1.9), C["canvas"], scale=(0.2, 0.9, 1.0), style="soft")


@K.kind("storm_station", hero=True, variants="abc", tags=["machine", "sign"],
        story="Fleet weather post on a squat plinth: cup anemometer, and a big barometer dial whose needle sits on STORM: YES.")
def storm_station(p, v, rng):
    for k, (x, y, r, sq) in enumerate(((0.2, 0.2, 1.1, 0.5), (-1.4, 0.0, 0.7, 0.55), (1.6, 0.5, 0.75, 0.5), (0.5, -1.3, 0.7, 0.45),
                                         (-0.8, 1.2, 0.65, 0.5), (1.9, -0.9, 0.5, 0.55), (-1.6, -1.1, 0.55, 0.5), (0.3, 1.6, 0.55, 0.5))):
        p.ico(r, (x, y, r * sq * 0.9), tint(C["concrete"] if k % 2 else C["sandstone_pale"], rng, 0.08), scale=(1.0, 0.85, sq),
              rot=(0, 0, rng.uniform(0, 3)), subdiv=1, style="round")
    p.box((2.4, 1.6, 1.3), (0.3, 0.3, 1.25), tint(PETROL, rng, 0.04), style="hard_smooth", jit=0.004)
    p.box((2.5, 1.7, 0.16), (0.3, 0.3, 1.98), CHAR, style="hard_smooth", jit=0.004)
    p.box((1.0, 0.07, 0.6), (0.9, -0.52, 1.0), tint(C["timber_pale"], rng, 0.1), rot=(0, 0, 0.06), style="hard_smooth")
    p.box((0.9, 0.06, 1.0), (-0.3, -0.58, 1.2), tint(C["oxide_dark"], rng), rot=((0.0 if v == "a" else 0.3), 0, 0), style="hard_smooth", jit=0.004)
    p.box((0.16, 0.08, 0.22), (0.35, -0.64, 1.2), BRASS, style="hard_smooth", jit=0.004) if v != "c" else None
    mast_h = 2.0
    mx, my = -0.5, 0.5
    tip = (mx, my, 2.05 + mast_h)
    if v == "c":
        p.cyl(0.2, 2.8, (-1.4, -0.3, 0.8), CHAR, segs=10, rot=(0, math.pi / 2 - 0.1, 0.5), style="hard_smooth", jit=0.004)
    else:
        p.cyl(0.24, mast_h, (mx, my, 2.05 + mast_h / 2), CHAR, segs=10, r2=0.18, style="hard_smooth", jit=0.004)
        for k in range(3):
            a = TAU * k / 3 + 0.4
            p.beam((mx + 0.6 * math.cos(a), my + 0.6 * math.sin(a), 2.05), (mx, my, 2.9), 0.14, C["iron"], h=0.12)
        p.cyl(0.2, 0.18, (mx, my, tip[2] + 0.1), COPPER, segs=10, style="hard_smooth", jit=0.004)
        ncup = 3 if v == "a" else 2
        for k in range(ncup):
            a = TAU * k / 3 + 0.5
            ex, ey = mx + 0.9 * math.cos(a), my + 0.9 * math.sin(a)
            p.rod((mx, my, tip[2] + 0.1), (ex, ey, tip[2] + 0.1), 0.06, COPPER)
            p.uv(0.3, (ex, ey, tip[2] + 0.2), C["canvas"], scale=(1, 1, 0.8), u=10, v=6, style="round")
            p.ring(0.18, 0.3, 0.06, (ex, ey, tip[2] + 0.34), C["canvas_dark"], segs=10)
        vz = 3.3
        bend = 0.0 if v == "a" else 0.5
        p.rod((mx + 0.8, my - 0.3, vz), (mx - 0.8, my + 0.3, vz - bend * 0.4), 0.06, COPPER)
        p.prism([(0, 0), (0.7, 0.35), (0.7, -0.35)], 0.05, (mx + 0.95, my - 0.36, vz), C["canvas_dark"], rot=(0, 0, 0.45), style="flat")
        p.prism([(0, 0), (0.6, 0.4), (0.6, -0.4), (0.0, 0.0)], 0.05, (mx - 1.0, my + 0.35, vz - bend * 0.4), C["canvas"], rot=(0, 0, 0.45 + math.pi), style="flat")
        if v == "b":
            p.uv(0.3, (mx + 1.2, my - 1.4, 0.35), C["canvas"], scale=(1, 1, 0.8), u=10, v=6, style="round")
    dx, dy, dz = 1.5, -1.6, 1.95
    face = (math.pi / 2, 0, 0)
    p.beam((dx, dy + 0.05, 0.45), (dx, dy + 0.05, dz - 0.7), 0.3, C["timber_dark"], h=0.3)
    p.cyl(0.95, 0.22, (dx, dy, dz), CHAR, segs=20, rot=face, style="hard_smooth", jit=0.004)
    p.cyl(0.8, 0.1, (dx, dy - 0.12, dz), C["canvas"] if v != "b" else C["canvas_dark"], segs=20, rot=face, style="hard_smooth", jit=0.004)
    for k in range(11):
        a = math.radians(210 - 24 * k)
        r0, r1 = 0.6, 0.74 if k % 5 == 0 else 0.68
        p.rod((dx + r0 * math.cos(a), dy - 0.2, dz + r0 * math.sin(a)), (dx + r1 * math.cos(a), dy - 0.2, dz + r1 * math.sin(a)), 0.025, CHAR, segs=4)
    na = math.radians(210 - 24 * 9.5) if v != "b" else math.radians(90)
    p.rod((dx, dy - 0.2, dz), (dx + 0.58 * math.cos(na), dy - 0.2, dz + 0.58 * math.sin(na)), 0.04, C["oxide_dark"], segs=5)
    p.cyl(0.09, 0.1, (dx, dy - 0.22, dz), CHAR, segs=8, rot=face)
    p.box((1.4, 0.12, 0.5), (dx, dy - 0.05, dz - 1.2), C["slate"], style="hard_smooth", jit=0.004)
    for k, w in enumerate((0.22, 0.22, 0.22)):
        p.box((w, 0.06, 0.28), (dx - 0.4 + 0.4 * k, dy - 0.13, dz - 1.2), C["chalk"], style="fine", jit=0.002)
    p.cyl(0.26, 0.5, (-1.4, -1.1, 0.95), C["sage_pale"] if v != "b" else C["glass_dark"], segs=10, style="round")
    p.box((0.7, 0.5, 0.07), (-0.6, -1.3, 0.97), C["canvas_stain"], rot=(0, 0, 0.5))
    if v == "b":
        tarp(p, (0.4, 0.9, 2.65), (1.4, 0.9, 0.18), C["canvas_dark"], rng, rot=(0, 0, 0.3))


@K.kind("lookout_deck", hero=True, variants="abc", tags=["soft"],
        story="A net-weavers' lookout: a battered crib of lashed logs and fieldstone holding a roped plank deck, a net hung over its rail, a lean-to cloth for shade.")
def lookout_deck(p, v, rng):
    DECK = 6.9
    for k in range(10):
        a = TAU * k / 10 + 0.2
        r = rng.uniform(0.8, 1.1)
        p.ico(r, (2.7 * math.cos(a), 2.7 * math.sin(a), r * 0.38), tint(C["concrete"] if k % 2 else C["sandstone_pale"], rng, 0.08),
              scale=(1.0, 0.9, 0.55), rot=(0, 0, rng.uniform(0, 3)), subdiv=1, style="round")
    p.box((2.5, 2.5, DECK - 1.1), (0, 0, 0.5 + (DECK - 1.1) / 2), shade(C["timber_dark"], 0.9), style="hard_smooth", jit=0.004)
    n = 14
    for i in range(n):
        t = i / (n - 1)
        z = 0.45 + i * (DECK - 1.0) / (n - 1)
        hw = 2.05 - 0.45 * t
        ln = 5.0 - 0.9 * t
        along_x = i % 2 == 0
        for s in (-1, 1):
            col = tint(C["timber"] if (i + (s > 0)) % 3 else C["timber_dark"], rng, 0.07)
            sag = rng.uniform(-0.05, 0.05)
            if along_x:
                p.cyl(0.25, ln, (sag, s * hw, z), col, segs=8, rot=(0, math.pi / 2, 0), style="hard", jit=0.004)
            else:
                p.cyl(0.25, ln, (s * hw, sag, z), col, segs=8, rot=(math.pi / 2, 0, 0), style="hard", jit=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (DECK - 2.3, DECK - 1.5):
                p.torus(0.34, 0.06, (sx * 1.6, sy * 1.6, z), C["ochre"], major=10, minor=4)
    for sy in (-1.5, 1.5):
        p.box((4.8, 0.4, 0.3), (0, sy, DECK - 0.3), C["timber_dark"], style="hard_smooth", jit=0.004)
    for k in range(8):
        x = -1.95 + k * 0.56
        p.box((0.52, 4.4, 0.18), (x, 0, DECK - 0.09), tint(C["timber_pale"] if k % 3 else C["timber"], rng, 0.06), style="hard", jit=0.004)
    posts = [(-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)]
    for x, y in posts:
        p.beam((x, y, DECK - 0.2), (x, y, DECK + 1.15), 0.2, C["timber_dark"], h=0.2, style="hard")
    for z, sg in ((DECK + 1.0, 0.18), (DECK + 0.55, 0.22)):
        rope(p, posts[2] + (z,), posts[3] + (z,), 0.045, C["ochre"], sag=sg, n=8)
        rope(p, posts[0] + (z,), posts[2] + (z,), 0.045, C["ochre"], sag=sg, n=8)
        rope(p, posts[1] + (z,), posts[3] + (z,), 0.045, C["ochre"], sag=sg, n=8)
    net(p, -2.0, 2.0, DECK + 0.35, DECK + 1.0, 2.28, 12, 4, 0.03, C["ochre_dark"], rng, sag=0.15, drop=0.1)
    p.cyl(0.28, 0.45, (1.5, 1.2, DECK + 0.22), C["timber"], segs=8, style="hard")
    for k in range(3):
        p.torus(0.4 - 0.07 * k, 0.06, (-1.4, 1.1, DECK + 0.1 + 0.08 * k), C["ochre"], major=12, minor=5)
    p.box((0.18, 0.04, 0.3), (2.2, 0.0, DECK + 0.65), C["canvas"], rot=(0, 0, 0.1), style="fine")
    if v == "a":
        for x in (-2.2, 2.2):
            p.beam((x, 2.2, DECK), (x, 2.2, DECK + 2.0), 0.2, C["timber_dark"], h=0.2)
            p.beam((x, -0.3, DECK), (x, -0.3, DECK + 1.4), 0.18, C["timber_dark"], h=0.18)
        p.box((4.9, 3.3, 0.09), (0, 0.95, DECK + 1.75), C["ochre"], rot=(0.3, 0, 0), style="hard_smooth", jit=0.004)
        p.beam((-2.2, 2.2, DECK + 2.0), (-2.2, -0.3, DECK + 1.4), 0.14, C["timber"], h=0.14)
        p.beam((2.2, 2.2, DECK + 2.0), (2.2, -0.3, DECK + 1.4), 0.14, C["timber"], h=0.14)
    elif v == "b":
        p.beam((-2.2, 2.2, DECK), (-2.2, 2.2, DECK + 2.0), 0.2, C["timber_dark"], h=0.2)
        p.ico(0.5, (-1.3, 1.4, DECK + 0.55), C["ochre_dark"], scale=(2.9, 2.0, 0.1), rot=(0.4, 0.5, 0.3), subdiv=1, style="soft")
    else:
        p.beam((-2.0, 2.2, DECK + 0.1), (-0.3, 2.3, DECK + 1.3), 0.16, C["timber"], h=0.16)
        p.ico(0.35, (0.9, 1.6, DECK + 0.4), C["ochre_pale"], scale=(2.0, 0.8, 0.8), rot=(0, 0, 0.2), subdiv=1, style="soft")
    p.perch((0.0, 0.0, DECK))
    return


@K.kind("hammock_rig", tags=["soft"], variants="abc",
        story="Net-weavers' low hammock on two short posts, a blanket still in it; run down, it sags to the dust.")
def hammock_rig(p, v, rng):
    L = 3.0
    h = 1.25
    for s in (-1, 1):
        lean = 0.0 if v == "a" else (0.25 * s if v == "b" else 0.0)
        p.beam((s * L / 2, 0, 0.0), (s * L / 2 + lean, 0, h), 0.2, tint(C["timber_dark"], rng), h=0.2)
        p.cyl(0.18, 0.1, (s * L / 2 + lean, 0, h + 0.05), C["timber"], segs=8, style="hard")
        for k in range(2):
            p.torus(0.3, 0.05, (s * L / 2 + lean, 0, 0.08 + 0.06 * k), C["ochre"], major=12, minor=5)
    if v == "c":
        p.beam((-L / 2 - 0.2, 0, 0.12), (-L / 2 + 1.0, 0.5, 0.3), 0.2, C["timber_dark"], h=0.2)
        for k in range(2 if False else 2):
            tarp(p, (-0.1 + 0.5 * k, 0.1 * k, 0.15 + 0.08 * k), (1.2, 0.8, 0.3), tint(C["canvas_dark"], rng), rng, rot=(0, 0, 0.5 * k))
        for k in range(4):
            a = TAU * k / 4
            p.rod((0.9, 0.2, 0.1), (0.9 + 0.4 * math.cos(a), 0.2 + 0.4 * math.sin(a), 0.8 + 0.2 * (k % 3)), 0.025, C["sage_dark"], segs=4, style="flat")
            p.ico(0.14, (0.9 + 0.4 * math.cos(a), 0.2 + 0.4 * math.sin(a), 0.85 + 0.2 * (k % 3)), C["sage"], subdiv=0, style="round")
        return
    sag = 0.55 if v == "a" else 0.95
    lean = 0.25 if v == "b" else 0.0
    a_pt, b_pt = (-L / 2, 0, h), (L / 2 + lean, 0, h)
    pts = rope(p, a_pt, b_pt, 0.04, C["ochre"], sag=sag, n=7)
    pts2 = rope(p, (a_pt[0], 0.5, h - 0.15), (b_pt[0], 0.5, h - 0.15), 0.04, C["ochre"], sag=sag, n=7)
    for k in range(1, 7, 2):
        q, w = pts[k], pts2[k]
        p.rod(q, (w[0], w[1], w[2] - 0.0), 0.03, C["ochre"], segs=4)
    mid_z = h - sag - 0.1
    tarp(p, (0, 0.25, mid_z + 0.12), (3.0, 1.1, 0.34), C["canvas"], rng, rot=(0, 0, 0))
    p.ico(0.5, (-0.5, 0.25, mid_z + 0.4), C["sage_pale"], scale=(1.6, 0.8, 0.5), style="soft", subdiv=2)
    if v == "b":
        p.ico(0.35, (0.6, 0.3, mid_z + 0.3), C["ochre_dark"], scale=(1.6, 0.9, 0.5), subdiv=0, style="round")


@K.kind("knot_board", tags=["soft"], variants="abc",
        story="A mending basket of spare net and a knot board with sample splices, set down mid-lesson.")
def knot_board(p, v, rng):
    rope_c = C["ochre"]
    bx, by = 0.85, 0.0
    tip = v == "c"
    for k in range(5):
        p.torus(0.5 + (0.03 * k), 0.09, (bx, by, 0.12 + 0.15 * k), tint(C["ochre_dark"], rng, 0.1), major=12, minor=4)
    p.cyl(0.52, 0.1, (bx, by, 0.05), C["ochre_dark"], segs=12)
    tarp(p, (bx, by, 0.7), (0.9, 0.9, 0.5), rope_c, rng)
    for k in range(3):
        p.torus(0.28, 0.06, (bx + 0.15 * (k - 1), by + 0.05, 0.9 + 0.1 * k), rope_c, major=10, minor=4)
    if tip:
        tarp(p, (bx + 0.9, by - 0.5, 0.2), (1.1, 0.9, 0.3), rope_c, rng, rot=(0, 0, 0.7))
    if v == "b":
        p.box((1.5, 1.2, 0.1), (-0.9, -0.1, 0.16), C["timber_pale"], rot=(0, 0, 0.3), style="hard")
        pts = [(-1.4, 0.25), (-1.0, 0.25), (-0.6, 0.05), (-0.8, -0.35), (-1.2, -0.4)]
        for x, y in pts:
            p.torus(0.1, 0.03, (x, y - 0.0, 0.25), rope_c, major=8, minor=4)
        return
    for s in (-1, 1):
        p.cyl(0.16, 0.8, (-1.0 + s * 0.55, 0.0, 0.4), C["timber_dark"], segs=8, style="hard")
    if v == "c":
        p.box((1.3, 0.1, 0.1), (-1.0, 0.5, 0.08), C["timber_grey"], rot=(0, 0, 0.5))
        return
    p.box((1.6, 0.14, 1.1), (-1.0, 0.0, 1.0), tint(C["timber_pale"], rng), style="hard")
    for r in range(2):
        for c in range(3):
            x, z = -1.45 + c * 0.45, 0.75 + r * 0.5
            p.torus(0.12, 0.035, (x, -0.1, z), rope_c, rot=(math.pi / 2, 0, 0), major=8, minor=4)
            p.torus(0.08, 0.03, (x + 0.12, -0.1, z), C["ochre_dark"], rot=(math.pi / 2, 0.3, 0), major=8, minor=4)
            p.rod((x - 0.12, -0.1, z), (x - 0.22, -0.12, z - 0.18 + 0.05 * c), 0.03, rope_c, segs=4)
    p.box((1.7, 0.18, 0.1), (-1.0, 0.0, 1.62), C["timber_dark"], style="hard")


@K.kind("spool_shed", tags=["machine"], variants="abc",
        story="A Fleet cable spool lying flat under a four-post canopy, its brass tag the only mark of owner.")
def spool_shed(p, v, rng):
    posts = ((-1.5, -1.0), (1.5, -1.0), (-1.5, 1.0), (1.5, 1.0))
    H = 2.1
    for x, y in posts:
        p.cyl(0.3, 0.1, (x, y, 0.05), C["concrete"], segs=6, style="flat")
    for k, (x, y) in enumerate(posts):
        hh = H if not (v == "b" and k == 1) else 1.7
        p.beam((x, y, 0.0), (x + (0.0 if v == "b" and k == 1 else 0), y, hh), 0.2, tint(C["timber_dark"], rng), h=0.2)
    if v == "c":
        for s in (-1, 1):
            p.box((3.6, 1.35, 0.09), (0, s * 0.55, 0.85 + 0.2 * (1 - s)), tint(C["timber_grey"], rng, 0.1),
                  rot=(-s * 0.3, 0.05, 0), style="hard")
        p.ico(0.8, (0.2, 0.2, 1.05), C["canvas_dark"], scale=(2.0, 1.2, 0.2), rot=(0.2, 0, 0.15), style="soft")
    else:
        rise = 0.7
        th = math.atan2(rise, 1.25)
        for s in (-1, 1):
            for r in range(4):
                t = (r + 0.5) / 4
                dz_ = -0.3 * (1 - t) if v == "b" and s == 1 else 0.0
                p.box((3.7, 0.55, 0.09), (0, s * 1.25 * (1 - t), H + 0.1 + rise * t + dz_), tint(C["timber_grey"], rng, 0.1),
                      rot=(-s * th, 0, 0), style="hard", jit=0.005)
        p.beam((-1.85, 0, H + 0.1 + rise), (1.85, 0, H + 0.1 + rise - (0.1 if v == "b" else 0)), 0.16, C["timber_dark"])
        for gx in (-1.8, 1.8):
            p.prism([(0.0, -1.2), (0.0, 1.2), (-rise, 0.0)], 0.08, (gx, 0, H + 0.1), tint(C["timber_grey"], rng, 0.1), rot=(0, math.pi / 2, 0), style="flat")
        if v == "b":
            p.ico(0.7, (0.5, 0.8, H + 0.55), C["canvas_dark"], scale=(2.0, 1.2, 0.12), rot=(-0.4, 0, 0.1), style="soft")
    sx, sy = -0.1, 0.0
    p.cyl(0.95, 0.12, (sx, sy, 0.1), CHAR, segs=14, style="hard")
    p.cyl(0.95, 0.12, (sx, sy, 0.78), CHAR, segs=14, style="hard")
    p.cyl(0.62, 0.7, (sx, sy, 0.44), PETROL if v != "b" else PETROL_LT, segs=14, style="round")
    for k in range(4):
        p.torus(0.62, 0.05, (sx, sy, 0.22 + 0.16 * k), COPPER, major=16, minor=4)
    p.cyl(0.18, 0.2, (sx, sy, 0.95), C["iron"], segs=6, style="hard")
    for k in range(2):
        p.torus(0.4 - 0.12 * k, 0.04, (1.15 + 0.1 * k, -0.8, 0.07 + 0.08 * k), CHAR, major=10, minor=4)
    if v != "c":
        p.box((0.2, 0.05, 0.28), (1.15, -1.35, 0.9), BRASS, style="hard")
        p.rod((1.15, -1.3, 0.0), (1.15, -1.3, 0.75), 0.04, C["timber_dark"])
    if v == "a":
        tarp(p, (-1.5, -1.8, 0.2), (0.8, 0.6, 0.4), C["canvas"], rng)
        p.torus(0.3, 0.05, (1.15, -0.8, 0.5), C["iron"], major=6, minor=4) if False else None
        pass


@K.kind("fulgurite", tags=[], variants="abc",
        story="Where lightning struck sand: pale glass tubes branching half-buried in a scorched sand scar, a bent rod lying by.")
def fulgurite(p, v, rng):
    glass, gd = C["glass"], C["glass_dark"]
    for k, (x, y, r, a) in enumerate(((0.0, 0.0, 1.0, 0.4), (0.9, 0.5, 0.65, 1.7), (-0.8, -0.4, 0.7, 2.6), (0.3, -0.9, 0.55, 0.9))):
        p.ico(r, (x, y, 0.04), C["sandstone_dark"] if k % 2 else C["soil"], scale=(1.3, 0.8, 0.08), rot=(0, 0, a), style="round", subdiv=0)

    def tube(x, y, ang, length, r, up, depth=0.0, turns=5):
        """A meandering glass tube; `depth` sinks it into the sand. Returns points for branching."""
        pts = [(x, y, 0.05 + up * 0.0)]
        for t in range(turns):
            ang += rng.uniform(-0.7, 0.7)
            seg = length / turns * rng.uniform(0.7, 1.3)
            x, y = x + seg * math.cos(ang), y + seg * math.sin(ang)
            pts.append((x, y, max(0.02, 0.08 + up * rng.uniform(0.2, 1.0) - depth)))
        for k, (a, b) in enumerate(zip(pts, pts[1:])):
            rr = r * (1.0 - 0.12 * k)
            p.rod(a, b, rr, tint(glass if k % 2 else gd, rng, 0.06), segs=5, r2=rr * 0.85, style="flat")
        return pts

    rng_up = {"a": 0.5, "b": 0.25, "c": 0.12}[v]
    main = tube(-0.9, -0.2, 0.3, 2.0, 0.1, rng_up, turns=6)
    for k in (2, 4):
        a0 = main[k]
        tube(a0[0], a0[1], rng.uniform(0, math.tau), 0.8, 0.065, rng_up * 0.7, turns=3)
    if v != "c":
        second = tube(0.4, 0.7, 4.0, 1.4, 0.08, rng_up, turns=4)
        tube(second[2][0], second[2][1], 2.0, 0.6, 0.05, rng_up * 0.6, turns=2)
    p.ico(0.2, (main[0][0], main[0][1], 0.12), gd, scale=(1.4, 0.9, 0.6), rot=(0, 0, 0.5), subdiv=0, style="round")
    for k in range(3 if v != "a" else 2):
        p.ico(0.1, (rng.uniform(-0.5, 1.0), rng.uniform(-1.0, 0.1), 0.07), glass, scale=(1.5, 0.8, 0.5),
              rot=(0, 0, rng.uniform(0, 3)), subdiv=0, style="round")
    if v == "a":
        p.rod((-0.4, 1.0, 0.1), (0.6, 1.3, 0.12), 0.07, C["iron"], style="flat")
        p.rod((0.6, 1.3, 0.12), (1.1, 1.0, 0.1), 0.07, C["iron"], style="flat")
    elif v == "b":
        p.rod((-0.2, 1.1, 0.1), (0.5, 1.2, 0.12), 0.07, C["rust"], style="flat")
        p.rod((0.5, 1.2, 0.12), (0.8, 0.8, 0.1), 0.07, C["rust"], style="flat")
    else:
        p.rod((0.3, 1.2, 0.08), (0.8, 1.2, 0.1), 0.06, C["rust"], style="flat")


@K.kind("watch_stool", tags=["soft"], variants="abc",
        story="A lookout's stool with a tarp slung over it and a thermos left on the seat: someone is coming back.")
def watch_stool(p, v, rng):
    if v == "b":
        p.cyl(0.4, 0.34, (0, 0, 0.4), C["timber"], segs=10, rot=(math.pi / 2, 0, 0.3), style="hard")
        p.cyl(0.46, 0.08, (0.2, -0.17, 0.4), C["timber_pale"], segs=10, rot=(math.pi / 2, 0, 0.3), style="hard")
        p.cyl(0.38, 0.1, (1.0, 0.6, 0.3), C["timber_dark"], segs=10, rot=(math.pi / 2, 0, 0.6), style="hard")
        p.cyl(0.11, 0.42, (-0.9, -0.6, 0.12), C["sage"], segs=10, rot=(0, math.pi / 2, 0.8), style="round")
        tarp(p, (0.4, 0.9, 0.18), (1.5, 1.1, 0.25), C["canvas"], rng, rot=(0, 0, 0.4))
        return
    p.cyl(0.55, 0.14, (0, 0, 0.07), C["timber_dark"], segs=10, style="hard")
    p.cyl(0.24, 0.62, (0, 0, 0.45), C["timber"], segs=10, style="hard")
    p.cyl(0.55, 0.16, (0, 0, 0.82), tint(C["timber_pale"], rng), segs=12, style="hard")
    if v == "a":
        tarp(p, (0.35, 0.1, 0.9), (1.5, 1.4, 0.45), C["canvas"], rng, rot=(0, 0.15, 0.3))
        p.cyl(0.13, 0.46, (-0.15, -0.2, 1.1), C["sage"], segs=10, style="round")
        p.cyl(0.14, 0.14, (-0.15, -0.2, 1.4), C["sage_dark"], segs=10, style="round")
    else:
        tarp(p, (1.0, 0.6, 0.12), (1.8, 1.2, 0.2), C["canvas_dark"], rng, rot=(0, 0, 0.6))
        p.cyl(0.13, 0.46, (-0.15, -0.2, 1.1), C["sage"], segs=10, style="round")
        p.torus(0.1, 0.03, (-0.15, -0.2, 1.34), C["sage_dark"])
    p.torus(0.2, 0.05, (-0.9, -0.7, 0.07), C["ochre"], major=12, minor=5)


@K.kind("dish_stones", tags=[], variants="abc",
        story="Three smooth palm dishes where someone sets a morning drink: one still steaming, one cold.")
def dish_stones(p, v, rng):
    spots = [(-0.8, 0.1, 0.55), (0.55, 0.5, 0.48), (0.2, -0.75, 0.5)]
    for k, (x, y, r) in enumerate(spots):
        col = tint(shade(C["sandstone_pale"], 0.84) if k != 1 else shade(C["concrete_light"], 0.84), rng, 0.05)
        p.ico(r, (x, y, 0.2), col, scale=(1.0, 1.0, 0.42), rot=(0, 0, rng.uniform(0, 3)), subdiv=2, style="soft")
        p.cyl(r * 0.6, 0.1, (x, y, 0.37), shade(col, 0.78), segs=10, style="round")
    if v == "a":
        x, y, _ = spots[0]
        for k, (dx, dy, dz, rr) in enumerate(((0, 0, 0.62, 0.26), (0.08, -0.04, 0.98, 0.31), (-0.06, 0.05, 1.36, 0.34))):
            p.ico(rr, (x + dx, y + dy, dz), C["steam"], scale=(1.0, 1.0, 0.8), subdiv=0, style="round")
        p.cyl(0.13, 0.14, (x + 0.1, y, 0.45), C["ochre_pale"], segs=8, style="hard")
    elif v == "b":
        for x, y, r in spots[:2]:
            p.ico(0.18, (x + 0.1, y, 0.38), C["sandstone_dark"], scale=(1, 0.7, 0.4), subdiv=0, style="round")
        p.ico(0.3, (1.5, -0.2, 0.15), C["sandstone"], scale=(1.0, 0.8, 0.6))
    else:
        x, y, r = spots[2]
        p.ico(r * 0.5, (x + 0.55, y - 0.15, 0.14), C["sandstone_pale"], scale=(1.0, 0.8, 0.5), rot=(0.3, 0.4, 0.5), subdiv=0, style="round")
        x, y, _ = spots[0]
        for k in range(9):
            a = TAU * k / 9
            p.rod((x, y, 0.35), (x + 0.25 * math.cos(a), y + 0.25 * math.sin(a), 0.75), 0.03, C["sage_dark"], r2=0.01, segs=4, style="flat")


@K.kind("rope_fence", tags=[], variants="abc",
        story="A short net-weaver rope fence between two stout posts, knotted with cloth tags, marking a mending spot.")
def rope_fence(p, v, rng):
    L = 3.0
    h = 1.05
    posts = [(-L / 2, 0.0), (L / 2, 0.0)]
    for k, (x, y) in enumerate(posts):
        fall = v == "c" and k == 1
        if fall:
            p.beam((x - 0.2, y, 0.1), (x + 1.1, y + 0.4, 0.15), 0.24, tint(C["timber_dark"], rng), h=0.24)
            continue
        lean = 0.35 if (v == "b" and k == 1) else 0.0
        p.beam((x, y, 0.0), (x + lean, y, h), 0.24, tint(C["timber_dark"], rng), h=0.24)
        p.ico(0.18, (x + lean, y, h + 0.05), C["timber"], scale=(1, 1, 0.8), style="round")
        p.torus(0.2, 0.05, (x + lean * 0.5, y, 0.3), C["ochre"], major=12, minor=5)
        p.torus(0.2, 0.05, (x + lean, y, h - 0.15), C["ochre"], major=12, minor=5)
    if v == "a":
        for z, sg in ((h - 0.15, 0.3), (h - 0.55, 0.45)):
            rope(p, (-L / 2, 0, z), (L / 2, 0, z), 0.045, C["ochre"], sag=sg, n=8)
        for t in (0.25, 0.5, 0.75):
            x = -L / 2 + L * t
            sg = 0.3 * 4 * t * (1 - t)
            p.box((0.14, 0.04, 0.3), (x, 0, h - 0.15 - sg - 0.2), C["canvas"] if t != 0.5 else C["sage_pale"], rot=(0, 0, 0.1), style="fine")
    elif v == "b":
        rope(p, (-L / 2, 0, h - 0.15), (L / 2 + 0.35, 0, h - 0.15), 0.045, C["ochre"], sag=0.7, n=8)
        rope(p, (-L / 2, 0, h - 0.55), (0.3, 0.3, 0.12), 0.045, C["ochre"], sag=0.2, n=6)
        p.box((0.14, 0.04, 0.3), (-0.6, 0, 0.5), C["canvas_dark"], style="fine")
    else:
        rope(p, (-L / 2, 0, h - 0.15), (0.2, 0.2, 0.14), 0.045, C["ochre"], sag=0.2, n=6)
        for k in range(3):
            p.torus(0.35 - 0.07 * k, 0.05, (0.7, 0.4, 0.07 + 0.08 * k), C["ochre"], major=12, minor=5)
        p.box((0.14, 0.04, 0.3), (0.0, 0.5, 0.1), C["canvas_dark"], rot=(0.0, 0, 0.5), style="fine")


@K.kind("storm_lantern", tags=[], variants="abc",
        story="An unlit storm lantern hung on a short crook post, waiting for the dark to come.")
def storm_lantern(p, v, rng):
    H = 1.35
    px = 0.0
    fall = v == "c"

    def lantern(x, y, z, rot=(0, 0, 0)):
        p.cyl(0.24, 0.1, (x, y, z), CHAR, segs=10, rot=rot, style="hard")
        p.cyl(0.21, 0.42, (x, y, z + 0.26), C["sage_pale"] if v != "b" else C["glass_dark"], segs=10, rot=rot, style="round")
        p.cyl(0.11, 0.1, (x, y, z + 0.5), CHAR, segs=10, r2=0.18, rot=rot, style="hard")
        p.torus(0.14, 0.03, (x, y, z + 0.62), CHAR, rot=rot, major=10, minor=4)
        for k in range(4):
            a = TAU * k / 4 + 0.7
            p.rod((x + 0.2 * math.cos(a), y + 0.2 * math.sin(a), z + 0.05), (x + 0.2 * math.cos(a), y + 0.2 * math.sin(a), z + 0.47), 0.02, CHAR, segs=4)

    p.cyl(0.4, 0.14, (0, 0, 0.07), C["concrete"], segs=10, style="hard")
    if fall:
        p.beam((0, 0, 0.15), (1.3, 0.5, 0.35), 0.2, C["timber_dark"], h=0.2)
        p.torus(0.25, 0.05, (1.3, 0.5, 0.35), C["timber_dark"], rot=(0.3, 0, 0), major=10, minor=5)
        lantern(-0.3, -0.7, 0.2, rot=(0, math.pi / 2, 0.4))
        return
    p.beam((0, 0, 0.1), (0, 0, H), 0.2, tint(C["timber_dark"], rng), h=0.2)
    p.beam((0, 0, H - 0.05), (0.55, 0, H + 0.12), 0.14, C["timber_dark"], h=0.14)
    p.torus(0.1, 0.035, (0.55, 0, H - 0.02), C["iron"], rot=(math.pi / 2, 0, 0), major=10, minor=4)
    p.torus(0.2, 0.05, (0, 0, 0.35), C["ochre"], major=12, minor=5)
    if v == "a":
        lantern(0.55, 0, H - 0.78)
    else:
        lantern(0.9, -0.5, 0.27, rot=(0, math.pi / 2, 0.5))
        p.torus(0.24, 0.03, (0.55, 0, H - 0.2), C["iron"], rot=(math.pi / 2, 0, 0), major=10, minor=4)


@K.kind("tally_slab", tags=["sign"], variants="abc",
        story="A slate tally slab the signal crew scratched with chalk: forty tallied, forty-one just begun.")
def tally_slab(p, v, rng):
    S = C["slate"]
    w, hgt, d = 1.5, 1.7, 0.28
    if v == "b":
        p.box((w, hgt, 0.2), (0, 0, 0.1), S, style="hard_smooth", jit=0.004)
        p.box((w + 0.3, hgt + 0.3, 0.06), (0, 0, 0.03), C["concrete"], style="hard_smooth", jit=0.004)
        bz, rot = 0.22, True
    elif v == "c":
        p.box((w, d, 1.0), (0, 0, 0.5), S, style="hard_smooth", jit=0.004)
        p.box((w, 0.7, 0.2), (0.2, -0.7, 0.1), S, rot=(0, 0, 0.5), style="hard_smooth", jit=0.004)
        bz, rot = 0.75, False
    else:
        p.box((w, d, hgt), (0, 0, hgt / 2), S, style="hard_smooth", jit=0.004)
        p.box((w + 0.3, d + 0.3, 0.2), (0, 0, 0.1), C["concrete"], style="hard_smooth", jit=0.004)
        for k in range(4):
            p.box((w * 0.96, d * 1.12, 0.06), (0, 0, 0.45 + k * 0.38), shade(S, 1.2), style="hard_smooth", jit=0.004)
        for sx in (-1, 1):
            p.box((0.3, d * 0.9, 0.3), (sx * (w / 2 - 0.1), 0, hgt - 0.05), shade(S, 0.9), rot=(0, 0.3 * sx, 0), style="hard_smooth", jit=0.004)
        bz, rot = hgt - 0.2, False
    if v != "a":
        for k in range(5):
            p.box((0.25 + 0.05 * k, 0.2, 0.1), (-0.6 + 0.3 * k, -0.95 if v == "c" else 1.15, 0.2 if v == "b" else 0.06), shade(S, 1.1 + 0.05 * k), rot=(0, 0.1 * k, 0.4 * k), style="hard_smooth", jit=0.004)
    if v != "b":
        p.box((0.2, 0.05, 0.26), (w / 2 - 0.2, -d / 2 - 0.02, 0.32), BRASS, style="hard_smooth", jit=0.004) if v == "a" else None
    cnt = {"a": (40, 41), "b": (40, 41), "c": (40, 20)}[v]
    for side, count in enumerate(cnt):
        for k in range(count):
            grp, c = divmod(k, 5)
            gr, gc = divmod(grp, 4)
            x = -w / 2 + 0.14 + side * 0.72 + gc * 0.16 + c * 0.028
            z = bz - 0.15 - gr * 0.22 if v != "c" else bz - 0.12 - gr * 0.2
            if v == "b":
                p.box((0.02, 0.15, 0.02), (x, -0.55 + (0.1 * gr), 0.205), C["chalk"], style="flat", jit=0.002)
                continue
            p.box((0.018, 0.02, 0.15), (x, -d / 2 - 0.015, z), C["chalk"], style="flat", jit=0.002)
            if c == 4:
                p.box((0.16, 0.02, 0.02), (x - 0.06, -d / 2 - 0.015, z), C["chalk"], rot=(0, 0.6, 0), style="flat", jit=0.002)


@K.kind("rabbitbrush", tags=["plant"], variants="abc",
        story="Dusk-flowering rabbitbrush, a sage-green clump with dusty yellow plumes; in c it has grown up through a fallen iron wheel.")
def rabbitbrush(p, v, rng):
    n = {"a": 12, "b": 9, "c": 9}[v]
    leaf = C["sage"] if v != "b" else C["dry_grass"]
    if v == "c":
        p.ring(0.5, 0.95, 0.12, (0, 0, 0.08), C["iron"], segs=14, style="hard")
        p.cyl(0.3, 0.2, (0, 0, 0.1), C["rust"], segs=10, style="hard")
        for k in range(6):
            a = TAU * k / 6
            p.beam((0.3 * math.cos(a), 0.3 * math.sin(a), 0.1), (0.9 * math.cos(a), 0.9 * math.sin(a), 0.1), 0.1, C["iron"], h=0.07)
    for k in range(n):
        a = TAU * k / n + rng.uniform(-0.2, 0.2)
        lean = rng.uniform(0.2, 0.7)
        hh = rng.uniform(0.8, 1.4) if v != "b" else rng.uniform(0.4, 0.8)
        base = (0.1 * math.cos(a), 0.1 * math.sin(a), 0.05)
        tipp = (base[0] + lean * math.cos(a), base[1] + lean * math.sin(a), hh)
        p.rod(base, tipp, 0.045, tint(C["sage_dark"] if v != "b" else C["timber"], rng), r2=0.02, segs=4, style="flat")
        p.ico(0.17, (tipp[0], tipp[1], tipp[2]), tint(leaf, rng, 0.1), scale=(1, 1, 1.4), subdiv=0, style="round")
        if v != "b" and k % 3 == 0:
            p.ico(0.2, (tipp[0], tipp[1], tipp[2] + 0.2), tint(C["flower"], rng, 0.08), scale=(1, 1, 1.3), subdiv=0, style="round")
    p.ico(0.5, (0, 0, 0.3), C["leaf_dark"] if v != "b" else C["timber_grey"], scale=(1.1, 1.1, 0.7), subdiv=2)


@K.kind("yucca", tags=["plant"], variants="abc",
        story="A yucca rosette with a tall cream flower stalk; the dry one is winter-bare, the third grows through a flat gear plate.")
def yucca(p, v, rng):
    n = {"a": 26, "b": 16, "c": 11}[v]
    dry = v == "b"
    col = C["sage_dark"] if not dry else C["dry_grass"]
    if v == "c":
        p.ring(0.45, 1.0, 0.1, (0, 0, 0.06), C["iron"], segs=12, style="hard")
        for k in range(4):
            a = TAU * k / 4 + 0.4
            p.box((0.28, 0.2, 0.1), (1.05 * math.cos(a), 1.05 * math.sin(a), 0.06), C["iron"], rot=(0, 0, a), style="hard")
    p.ico(0.3, (0, 0, 0.3), C["timber"], scale=(1, 1, 0.9), subdiv=1)
    for k in range(n):
        a = TAU * k / n + rng.uniform(-0.1, 0.1)
        tilt = rng.uniform(0.35, 1.1)
        ln = rng.uniform(0.8, 1.15)
        sx, sy, sz = 0.12 * math.cos(a), 0.12 * math.sin(a), 0.3 + 0.2 * (k % 3)
        end = (sx + ln * math.sin(tilt) * math.cos(a), sy + ln * math.sin(tilt) * math.sin(a), sz + ln * math.cos(tilt) * (1.0 if tilt < 1.0 else 0.7) - (0.25 if dry and k % 2 else 0))
        p.rod((sx, sy, sz), end, 0.07, tint(col, rng, 0.1), r2=0.0, segs=4, style="flat")
    if v != "b":
        top = 2.4 if v == "a" else 2.0
        p.rod((0, 0, 0.5), (0.05, 0, top), 0.06, C["timber_pale"], r2=0.03, segs=5)
        for k in range(14):
            z = 1.0 + (top - 1.0) * k / 14
            a = k * 2.4
            p.ico(0.14, (0.28 * math.cos(a), 0.28 * math.sin(a), z), C["canvas"], scale=(1, 1, 1.3), subdiv=0, style="round")
    else:
        p.rod((0, 0, 0.5), (0.3, 0.1, 1.5), 0.05, C["timber_grey"], r2=0.02, segs=5)


@K.kind("kite_pennant", tags=[], variants="abc", line_clear_m=30,
        story="A crew pennant on a thick stake in a cairn: out in the wind, slack, or on the ground after the gale.")
def kite_pennant(p, v, rng):
    H = 1.35
    for k, (x, y, r) in enumerate(((0.0, 0.0, 0.42), (0.5, 0.15, 0.3), (-0.35, 0.3, 0.27))):
        p.ico(r, (x, y, r * 0.55), tint(C["concrete_light"], rng, 0.06), scale=(1, 1, 0.75), subdiv=2, style="soft")
    col = C["canvas"]
    if v == "c":
        p.beam((-0.2, 0, 0.5), (1.3, -0.6, 0.2), 0.16, C["timber_dark"], h=0.16)
        p.prism([(0, 0.0), (1.4, 0.0), (0, 0.55)], 0.04, (0.2, -0.9, 0.06), col, rot=(0, 0, 0.4), style="flat")
        return
    p.beam((0, 0, 0.3), (0, 0, H), 0.16, tint(C["timber_dark"], rng), h=0.16)
    p.ico(0.14, (0, 0, H + 0.05), C["timber"], style="round")
    p.torus(0.17, 0.04, (0, 0, H - 0.2), C["ochre"], major=10, minor=4)
    if v == "a":
        p.prism([(0, 0.0), (1.5, 0.12), (1.5, 0.52), (1.2, 0.26), (0, 0.5)], 0.04, (0.1, 0.0, H - 0.1),
                col, rot=(math.pi / 2, 0, 0.0), style="flat")
        p.prism([(0, 0.0), (1.5, 0.12), (1.5, 0.52), (1.2, 0.26), (0, 0.5)], 0.04, (0.1, 0.0, H - 0.1),
                C["sage"], rot=(math.pi / 2, 0, 0.0), style="flat") if False else None
        p.box((0.5, 0.05, 0.12), (0.5, 0.0, H - 0.35), C["sage_dark"], style="fine")
    else:
        p.prism([(0, 0.0), (0.45, 0.0), (0.45, -1.0), (0.22, -0.8), (0, -1.0)], 0.04, (0.12, 0.0, H - 0.05),
                col, rot=(math.pi / 2, 0, 0), style="flat")
        p.box((0.45, 0.05, 0.12), (0.34, 0.0, H - 0.35), C["sage_dark"], style="fine")


HANDS = {
    "slate": "6e7378", "slate_dark": "4d5257", "slate_pale": "93979a",
    "glove": "b59a6a", "glove_worn": "9c8458", "card": "e2dccb", "chalk": "e8e6dc",
    "board": "33393a", "scorch": "302a26",
}


def glove(p, at, yaw, color, rng, curl=0.0, scale=1.0, lift=0.0):
    """A chunky work glove lying palm down: cuff, palm, four fingers and a thumb. `curl` bends the fingers under."""
    x, y, z = at
    s = scale
    ca, sa = math.cos(yaw), math.sin(yaw)

    def w(dx, dy, dz=0.0):
        return (x + (dx * ca - dy * sa) * s, y + (dx * sa + dy * ca) * s, z + lift + dz * s)

    p.box((0.13 * s, 0.11 * s, 0.05 * s), w(-0.11, 0, 0.03), shade(color, 0.85), rot=(0, 0, yaw), style="fine")
    p.box((0.13 * s, 0.13 * s, 0.035 * s), w(0.0, 0, 0.022), color, rot=(0, 0, yaw), style="fine")
    for k in range(4):
        fy = -0.05 + k * 0.033
        length = (0.1, 0.115, 0.11, 0.085)[k]
        bend = curl * (0.6 + 0.1 * k)
        a = w(0.06, fy, 0.022)
        b = w(0.06 + length * math.cos(bend), fy * (1.0 + 0.6 * length), 0.022 - length * math.sin(bend))
        p.rod(a, b, 0.014 * s, tint(color, rng, 0.04), segs=4, style="flat")
    p.rod(w(0.0, 0.06, 0.022), w(0.06, 0.13, 0.02), 0.016 * s, color, segs=4, style="flat")


@K.kind("clock_post", tags=["machine", "sign"], polish_opts={"detail": 1}, variants="ab",
        story="The watch crew's time clock on one post under a shingled hood; the card rack is full, 01 to 04 and FOREMAN, every card fresh.")
def clock_post(p, v, rng):
    struck = v == "b"
    p.cyl(0.85, 0.35, (0, 0, 0.17), HANDS["slate"], segs=10, style="hard", jit=0.02)
    p.cyl(0.6, 0.12, (0, 0, 0.4), HANDS["slate_pale"], segs=10, style="hard")
    p.cyl(0.15, 2.0, (0, 0.34, 1.4), tint(C["timber_dark"], rng, 0.05), segs=8, style="hard")
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        p.rod((0.28 * math.cos(a), 0.34 + 0.28 * math.sin(a), 0.46), (0.06 * math.cos(a), 0.34 + 0.06 * math.sin(a), 0.9),
              0.05, C["timber_dark"], segs=4, style="flat")
    p.box((1.05, 0.16, 1.4), (0, 0.18, 1.45), tint(C["timber_grey"], rng), style="hard")
    for i in range(3):
        p.box((0.34, 0.05, 1.4), (-0.345 + i * 0.345, 0.27, 1.45), tint(C["timber"], rng, 0.07), style="fine", jit=0.003)
    p.cyl(0.26, 0.2, (0, -0.02, 1.85), C["iron"], segs=12, rot=(math.pi / 2, 0, 0), style="hard")
    p.torus(0.25, 0.03, (0, -0.12, 1.85), C["iron_light"], rot=(math.pi / 2, 0, 0), major=12, minor=4)
    p.cyl(0.22, 0.02, (0, -0.125, 1.85), HANDS["card"], segs=12, rot=(math.pi / 2, 0, 0), style="flat")
    for k in range(4):
        a = math.tau * k / 4
        p.box((0.02, 0.01, 0.07), (0.18 * math.sin(a), -0.14, 1.85 + 0.18 * math.cos(a)),
              HANDS["board"], rot=(0, a, 0), style="flat")
    p.beam((0, -0.145, 1.85), (0.0, -0.145, 1.99), 0.025, HANDS["board"], style="fine")
    p.beam((0, -0.145, 1.85), (0.11, -0.145, 1.85), 0.025, HANDS["board"], style="fine")
    p.uv(0.025, (0, -0.15, 1.85), C["iron"], u=8, v=4)
    p.box((0.34, 0.16, 0.16), (0, -0.04, 1.47), C["iron"], style="hard")
    p.box((0.18, 0.03, 0.025), (0, -0.125, 1.5), C["charcoal"], style="flat")
    p.rod((0.2, -0.08, 1.47), (0.36, -0.2, 1.36), 0.022, C["iron_light"], segs=6)
    p.uv(0.045, (0.36, -0.2, 1.36), C["timber_dark"], u=8, v=6)
    widths = (0.11, 0.11, 0.11, 0.11, 0.16)
    xs = (-0.36, -0.235, -0.11, 0.015, 0.175)
    for k, (cx, wd) in enumerate(zip(xs, widths)):
        p.box((wd + 0.02, 0.06, 0.2), (cx, -0.06, 1.0), C["iron"], style="flat")
        p.box((wd, 0.012, 0.24), (cx, -0.095, 1.06), tint(HANDS["card"], rng, 0.03), style="flat")
        for r in range(1 + k % 2):
            p.box((wd * 0.7, 0.004, 0.012), (cx, -0.102, 1.13 - r * 0.03), HANDS["board"], style="flat")
        p.box((wd, 0.01, 0.05), (cx, -0.095, 0.85), HANDS["chalk"] if k < 4 else C["bone"], style="flat")
        for b in range(k + 1 if k < 4 else 1):
            bw = 0.012 if k < 4 else 0.1
            p.box((bw, 0.004, 0.03), (cx - 0.03 + b * 0.02 if k < 4 else cx, -0.101, 0.85), HANDS["board"], style="flat")
    if not struck:
        for r in range(3):
            for j in range(3):
                p.box((0.42, 0.3, 0.035), (-0.42 + j * 0.42, 0.44 - r * 0.22, 2.47 - r * 0.09),
                      tint(C["timber_grey"], rng, 0.08), rot=(0.39, 0, rng.uniform(-0.05, 0.05)), style="fine", jit=0.004)
    else:
        p.cyl(0.16, 0.08, (0, 0.34, 2.42), HANDS["scorch"], segs=8, style="hard")
        for k in range(6):
            a = 2.2 + rng.uniform(-0.8, 0.8)
            r = rng.uniform(0.95, 1.6)
            p.box((0.42, 0.3, 0.035), (r * math.cos(a), r * math.sin(a), 0.02 + 0.01 * (k % 3)),
                  HANDS["scorch"] if k % 3 == 0 else tint(C["timber_grey"], rng, 0.08), rot=(rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), rng.uniform(0, math.tau)), style="fine")
    if struck:
        p.cyl(0.95, 0.02, (0, 0, 0.005), HANDS["scorch"], segs=10, style="flat")
        for k in range(5):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(1.0, 1.3)
            p.box((0.1, 0.16, 0.008), (r * math.cos(a), r * math.sin(a), 0.02 + 0.004 * k),
                  HANDS["card"], rot=(0, 0, a), style="flat")
    else:
        p.cyl(0.11, 0.14, (-0.3, -0.3, 0.53), C["iron_light"], segs=8, style="hard")
        p.cyl(0.115, 0.02, (-0.08, -0.5, 0.47), C["iron"], segs=8, style="hard")
        glove(p, (0.25, -0.42, 0.46), 0.3, HANDS["glove"], rng)
        glove(p, (0.42, -0.36, 0.46), 0.1, HANDS["glove"], rng, curl=0.4)


@K.kind("glove_bench", tags=["soft"], polish_opts={"detail": 1}, variants="abc",
        story="A crew bench with a fresh pair of work gloves set out for every shift; nobody draws them.")
def glove_bench(p, v, rng):
    length = 1.9 if v != "c" else 1.3
    p.box((length, 0.38, 0.07), (0, 0, 0.45), tint(C["timber_grey"], rng), style="hard_smooth", jit=0.003)
    for x in (-length / 2 + 0.15, length / 2 - 0.15):
        p.box((0.08, 0.32, 0.42), (x, 0, 0.21), C["timber_dark"], style="hard")
    p.beam((-length / 2 + 0.15, 0, 0.12), (length / 2 - 0.15, 0, 0.12), 0.05, C["timber_dark"])
    pairs = 5 if v != "c" else 3
    for k in range(pairs):
        x = -length / 2 + 0.2 + k * (length - 0.4) / max(1, pairs - 1)
        col = HANDS["glove"] if (v == "a" or k != 2) else HANDS["glove_worn"]
        glove(p, (x - 0.04, -0.05, 0.485), math.pi / 2 + 0.1, col, rng)
        glove(p, (x + 0.05, 0.03, 0.485), math.pi / 2 - 0.1, col, rng, curl=0.2)
        p.box((0.06, 0.012, 0.04), (x, -0.19, 0.42), HANDS["card"], style="flat")
    if v == "b":
        glove(p, (0.4, -0.45, 0.0), 0.8, HANDS["glove"], rng, curl=0.6)
        glove(p, (0.55, -0.55, 0.0), 1.4, HANDS["glove"], rng)


@K.kind("shift_board", tags=["sign"], polish_opts={"detail": 1}, variants="ab",
        story="Sandwich shift board: FOREMAN column chalked MIND, the HANDS column wiped clean every morning.")
def shift_board(p, v, rng):
    lean = 0.22
    for s in (-1, 1):
        p.box((0.9, 0.05, 1.15), (0, s * 0.22, 0.6), C["timber_dark"], rot=(s * lean, 0, 0), style="hard_smooth")
        p.box((0.78, 0.02, 0.95), (0, s * 0.255, 0.62), HANDS["board"], rot=(s * lean, 0, 0), style="flat")
        th = s * lean

        def face(dx, dz, out=0.014):
            return (dx, s * 0.255 + s * out * math.cos(th) - dz * math.sin(th), 0.62 + s * out * math.sin(th) + dz * math.cos(th))

        for r in range(5):
            w = rng.uniform(0.14, 0.26)
            p.box((w, 0.006, 0.03), face(-0.2, 0.33 - r * 0.15), HANDS["chalk"], rot=(th, 0, 0), style="flat")
        p.box((0.04, 0.006, 0.85), face(0.0, 0.0), HANDS["chalk"], rot=(th, 0, 0), style="flat")
        p.box((0.26, 0.006, 0.32), face(0.22, -0.22 if v == "a" else 0.08), mix(HANDS["board"], HANDS["chalk"], 0.25),
              rot=(th, 0, 0), style="flat")
    p.rod((-0.42, -0.1, 1.17), (-0.42, 0.1, 1.17), 0.025, C["iron"], segs=6)
    p.rod((0.42, -0.1, 1.17), (0.42, 0.1, 1.17), 0.025, C["iron"], segs=6)
    p.cyl(0.07, 0.07, (0.35, -0.55, 0.035), C["iron_light"], segs=10, style="round")
    for k in range(3):
        p.cyl(0.012, 0.07, (0.33 + 0.02 * k, -0.55, 0.08), HANDS["chalk"], segs=6, rot=(0.3, 0.2 * k, 0))
    p.ico(0.09, (-0.3, -0.55, 0.04), C["canvas_stain"], scale=(1.4, 1.0, 0.5), style="round")
    if v == "b":
        p.box((0.9, 0.05, 1.15), (-0.75, 0.55, 0.03), C["timber_dark"], rot=(math.pi / 2, 0, 0.3), style="hard_smooth")


@K.kind("lost_glove", tags=["soft"], polish_opts={"detail": 1}, variants="ab",
        story="A work glove dropped on a flat stone, fingers half curled; in b its pair lies beside it.")
def lost_glove(p, v, rng):
    p.ico(0.3, (0, 0, 0.06), HANDS["slate_pale"] if v == "a" else HANDS["slate"], scale=(1.3, 1.0, 0.25), style="round", jit=0.01)
    glove(p, (0.0, 0.0, 0.1), 0.6, HANDS["glove"] if v == "a" else HANDS["glove_worn"], rng, curl=0.7, scale=1.6)
    p.ico(0.12, (-0.35, 0.2, 0.04), HANDS["slate_dark"], scale=(1.3, 1.0, 0.45), style="round")
    if v == "b":
        glove(p, (0.2, -0.32, 0.0), 2.4, HANDS["glove_worn"], rng, scale=1.6)


if __name__ == "__main__":
    K.main()
