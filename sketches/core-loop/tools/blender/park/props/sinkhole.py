"""Sinkhole park dressing kit (The Dig, world 2, afternoon, mostly underground).

A mining crew sank a pump caisson in a flooded sinkhole and walked off mid-shift: pumps parked,
lamp racks left facing the wrong way, a timber set come down, a coat still on its hook. A
reference trench of stone granaries sits in the west wall, abandoned, with no hearth. LAMP VETO:
nothing here looks lit; lenses are plain white and non-emissive. The dark basalt reads best
against pale timber, canvas, limestone and lichen, so the props lean light.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/sinkhole.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, shade, tint

K = kit.Kit("sinkhole")

LENS = "e4e2d6"
LIME = "cfc8b2"
LIME_D = "a9a28c"
LICHEN = "9aa284"
FERN = "7b8a58"
FERN_D = "58664a"
STEEL = "365754"
STEEL_D = shade("365754", 0.75)
BASALT = "3d4140"
PALE_PAINT = "e0d9c3"
OXIDE = "9b513a"
COPPER = "b77843"
WET = "4a4234"
TAU = math.tau
FLAT = math.pi / 2


def planks(p, rng, n, x0, step, y, z, size, col, rot=(0, 0, 0), spread=0.0, style="hard"):
    for i in range(n):
        p.box(size, (x0 + i * step, y, z), tint(col, rng, 0.08), rot=rot, jit=spread, style=style)


def fern_tuft(p, rng, c, n, length, col, lift=0.35, droop=0.6):
    """Arching fronds: each is three tapering rods bending over, with a leaflet blob at the tip."""
    for k in range(n):
        a = TAU * k / n + rng.uniform(-0.2, 0.2)
        ln = length * rng.uniform(0.75, 1.0)
        pts = [(c[0], c[1], c[2] + 0.05)]
        for s in (1, 2, 3):
            t = s / 3
            r = ln * t * 0.8
            pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a),
                        c[2] + 0.05 + ln * (lift * math.sin(t * 2.2) - droop * t * t * 0.55 + 0.25 * t)))
        for i, (u, w) in enumerate(zip(pts, pts[1:])):
            f = 0.034 * (1 - i * 0.25)
            p.rod(u, w, f, tint(col, rng, 0.06), segs=4, r2=f * 0.7, style="flat")
            mid = tuple((u[j] + w[j]) / 2 for j in range(3))
            p.ico(ln * 0.1, mid, tint(col, rng, 0.1), scale=(1.5, 0.45, 0.22), rot=(0, 0, a), subdiv=0, style="flat")


def mug(p, loc, col=LENS):
    x, y, z = loc
    p.cyl(0.09, 0.14, (x, y, z + 0.07), col, segs=10, style="round")
    p.torus(0.045, 0.014, (x + 0.1, y, z + 0.07), STEEL_D, rot=(FLAT, 0, 0), major=8, minor=4)


def lamp(p, loc, yaw, col=STEEL_D, s=1.0, lens=LENS, sg=10):
    """A big unlit hand lamp: dull body, plain white lens disc, loop handle. Faces `yaw`."""
    x, y, z = loc
    rot = (0, FLAT, yaw)
    p.cyl(0.26 * s, 0.4 * s, (x, y, z + 0.26 * s), col, segs=sg, rot=rot, style="hard")
    fx, fy = math.cos(yaw), math.sin(yaw)
    p.cyl(0.22 * s, 0.07 * s, (x + fx * 0.22 * s, y + fy * 0.22 * s, z + 0.26 * s), lens, segs=sg, rot=rot, style="round")
    p.torus(0.16 * s, 0.03 * s, (x - fx * 0.05 * s, y - fy * 0.05 * s, z + 0.52 * s), col, rot=(FLAT, 0, yaw), major=8, minor=4)


@K.kind("pump_engine", hero=True, tags=["machine"],
        polish_opts={"detail": 1},
        story="The caisson crew's steam-less pump engine, parked off mid-shift under a half-pulled tarp.")
def pump_engine(p, v, rng):
    run = v == "b"
    p.box((7.0, 3.4, 0.5), (0, 0, 0.25), C["concrete_light"], style="hard_smooth")
    for x in (-3.0, -1.0, 1.0, 3.0):
        p.box((0.5, 3.0, 0.2), (x, 0, 0.6), C["timber_pale"])
    p.box((3.0, 2.0, 1.1), (-0.8, 0, 1.25), STEEL, style="hard_smooth")
    p.box((3.1, 0.25, 0.3), (-0.8, -1.05, 1.5), OXIDE, style="hard_smooth")
    for i, x in enumerate((-1.8, -0.8, 0.2)):
        p.cyl(0.55, 1.5, (x, 0.2, 2.5), STEEL_D if i % 2 else STEEL, segs=14, style="hard_smooth")
        p.cyl(0.62, 0.18, (x, 0.2, 3.3), C["bone"], segs=14, style="hard_smooth")
        p.cyl(0.14, 1.0 if not (run and i == 1) else 0.4, (x, 0.2, 3.9 if not (run and i == 1) else 3.6),
              STEEL, segs=8, style="round")
        p.box((0.9, 0.3, 0.2), (x, 0.2, 4.35 if not run else 3.95), C["bone"], style="hard_smooth")
    for i, x in enumerate((-1.8, -0.8, 0.2)):
        p.rod((x, -0.6, 2.0), (x + 1.7, -1.35, 1.5), 0.1, STEEL_D, segs=8)
    fx = 1.6 if not run else 2.0
    fz = 2.1 if not run else 1.1
    fr = 1.4
    rot = (0, FLAT, 0) if False else (0, FLAT, 0)
    ang = 0.0 if not run else 0.45
    p.torus(fr, 0.17, (fx + 0.5, 0.2, fz), C["iron_light"], rot=(0, FLAT, 0) if False else (0, FLAT, 0),
            major=18, minor=6) if False else None
    p.torus(fr, 0.17, (fx + 0.7, 0.2, fz), STEEL_D, rot=(0, FLAT, 0), major=20, minor=6, style="round")
    p.cyl(0.3, 0.5, (fx + 0.7, 0.2, fz), STEEL, segs=12, rot=(0, FLAT, 0), style="hard_smooth")
    for k in range(6):
        a = TAU * k / 6 + ang
        p.rod((fx + 0.7, 0.2 + 0.2 * math.cos(a), fz + 0.2 * math.sin(a)),
              (fx + 0.7, 0.2 + fr * math.cos(a), fz + fr * math.sin(a)), 0.1, STEEL_D, segs=6)
    p.cyl(0.85, 2.3, (-3.0, 0.1, 1.6), STEEL, segs=16, rot=(0, FLAT, 0), style="hard_smooth")
    for x in (-4.1, -1.9):
        p.cyl(1.0, 0.2, (x, 0.1, 1.6), C["bone"], segs=16, rot=(0, FLAT, 0), style="hard_smooth")
    p.cyl(0.35, 1.4, (-3.4, 1.0, 0.95), STEEL_D, segs=10, rot=(FLAT, 0, 0), style="hard_smooth")
    p.cyl(0.45, 0.25, (-3.4, 1.8, 0.95), C["bone"], segs=10, rot=(FLAT, 0, 0), style="hard_smooth")
    p.cyl(0.4, 0.5, (-2.2, -1.6, 0.55), COPPER, segs=8, style="hard_smooth")
    mug(p, (2.9, -1.3, 0.5))
    p.cyl(0.13, 0.25, (2.4, -1.45, 0.62), STEEL, segs=8, r2=0.07, style="hard_smooth")
    if not run:
        p.ico(1.5, (-0.6, 0.4, 3.0), C["canvas"], scale=(1.3, 0.9, 0.65), rot=(0.1, 0, 0.1), subdiv=0, style="soft")
        p.ico(0.5, (1.2, -1.6, 0.6), C["canvas_dark"], scale=(1.4, 1.0, 0.5), subdiv=0, style="soft")
    else:
        p.ico(1.2, (2.6, -1.9, 0.6), C["canvas_dark"], scale=(1.8, 1.2, 0.35), rot=(0, 0, 0.5), subdiv=0, style="soft")
        p.rod((-0.2, -2.0, 0.65), (1.4, -1.9, 0.62), 0.11, C["rust"], segs=8)
        p.box((1.3, 0.5, 0.05), (-1.2, -1.2, 0.53), mix(C["concrete_light"], C["soil"], 0.5), style="flat")
        fern_tuft(p, rng, (-3.9, -1.3, 0.0), 7, 1.6, FERN, 0.4)


@K.kind("lamp_rack", hero=True, tags=["machine", "sign"],
        polish_opts={"detail": 1},
        story="Crew lamp rack, every unlit lamp facing the same wrong way, toward the dark wall.")
def lamp_rack(p, v, rng):
    run = v == "b"
    p.box((6.4, 2.2, 0.35), (0, 0, 0.17), C["timber_pale"])
    for x in (-2.8, 0, 2.8):
        p.box((0.4, 2.0, 0.18), (x, 0, 0.44), C["timber_dark"])
    planks(p, rng, 17, -3.0, 0.375, 0.8, 2.15, (0.36, 0.14, 3.3), C["timber_pale"])
    for z in (0.7, 1.9, 3.1):
        p.beam((-3.25, 0.68, z), (3.25, 0.68, z), 0.16, C["timber_dark"], h=0.1)
    for i, z in enumerate((1.0, 2.1, 3.2)):
        p.box((6.0, 0.9, 0.14), (0, 0.3, z), C["timber_grey"])
        for x in (-2.9, 2.9):
            p.beam((x, 0.75, z - 0.05), (x, -0.1, z - 0.55), 0.12, C["timber_dark"])
        for j in range(6):
            x = -2.5 + j * 1.0
            if run and (i + j) % 4 == 1:
                continue
            if run and (i + j) % 5 == 2:
                lamp(p, (x + 0.2, -0.6 - i * 0.2, 0.0), 0.8 + j)
                continue
            lamp(p, (x, 0.3, z + 0.07), math.pi / 2 + rng.uniform(-0.04, 0.04) + (0.5 if run and j == 3 else 0),
                 s=1.2)
    p.box((1.5, 0.12, 0.7), (0, -0.3, 3.95), PALE_PAINT, style="hard_smooth")
    for k in range(5):
        p.box((0.06, 0.04, 0.4), (-0.5 + k * 0.25, -0.38, 3.95), C["charcoal"], style="fine")
    p.ico(0.5, (-2.8, -1.4, 0.5), C["canvas"], scale=(1.0, 0.8, 0.6), subdiv=0, style="soft")
    mug(p, (2.4, -0.8, 0.35))
    if run:
        p.box((1.6, 0.9, 0.12), (-2.2, -1.3, 0.1), C["timber_grey"], rot=(0.1, 0, 0.6))
        fern_tuft(p, rng, (3.4, -1.0, 0.0), 6, 1.4, FERN_D, 0.4)


@K.kind("gallery_collapse", hero=True, tags=["machine"],
        polish_opts={"detail": 2},
        story="A timber set that came down, lagging heaped over limestone slabs, a painted water mark still on a post.")
def gallery_collapse(p, v, rng):
    full = v == "b"
    for i in range(26 if not full else 34):
        a = rng.uniform(0, TAU)
        r = rng.uniform(0.6, 3.1)
        s = rng.uniform(0.6, 1.4)
        p.box((s, s * rng.uniform(0.6, 1.1), 0.4 * s + 0.1), (r * math.cos(a), r * math.sin(a), 0.2 + 0.1 * s),
              tint(LIME, rng, 0.1), rot=(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), a), style="hard_smooth")
    px = -2.4
    h = 3.4 if not full else 1.5
    p.beam((px, 0.2, 0), (px, 0.2, h), 0.45, C["timber_pale"])
    p.box((0.5, 0.5, 0.5), (px, 0.2, 0.25), WET)
    p.box((0.52, 0.52, 0.16), (px, 0.2, 0.62), PALE_PAINT, style="hard_smooth")
    for k in range(4):
        p.box((0.3, 0.04, 0.05), (px, -0.07, 0.95 + k * 0.28), C["charcoal"], style="fine")
    if not full:
        p.beam((px, 0.2, h), (px + 0.7, 0.4, h + 0.25), 0.4, C["timber_grey"], roll=0.3)
    p.beam((-1.2, -1.5, 0.45), (3.2, 0.6, 0.7), 0.5, C["timber_dark"], h=0.42, roll=0.2)
    p.beam((1.5, 2.3, 0.35), (-0.5, -0.3, 1.0), 0.42, C["timber"], roll=0.5)
    for i in range(76 if full else 56):
        a = rng.uniform(0, math.pi)
        r = rng.uniform(0.2, 2.8)
        z = 0.5 + rng.uniform(0, 0.9 if full else 0.6)
        p.box((rng.uniform(1.4, 2.4), 0.22, 0.08), (1.2 + r * math.cos(a * 2), 0.4 + r * math.sin(a * 2) * 0.8, z),
              tint(C["timber_pale"] if i % 3 else C["timber_grey"], rng, 0.1),
              rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), a * 3), jit=0.01)
    for k in range(3):
        p.box((0.35, 0.35, 0.35), (-1.0 + k * 0.5, -2.0, 0.18), C["timber_dark"], rot=(0, 0, k))
    p.ico(0.5, (2.8, -1.2, 0.4), C["canvas_dark"], scale=(1.2, 1.0, 0.5), subdiv=0, style="soft")
    p.cyl(0.25, 0.5, (3.4, -1.8, 0.28), C["iron_light"], segs=10, r2=0.2, style="hard_smooth")
    if full:
        fern_tuft(p, rng, (-0.5, 1.7, 0.4), 8, 1.5, FERN, 0.4)
        p.ico(0.8, (1.8, 0.2, 0.9), LICHEN, scale=(1.6, 1.2, 0.3), subdiv=0, style="soft")
    else:
        p.ico(0.6, (0.2, 1.4, 0.7), LICHEN, scale=(1.4, 1.0, 0.25), subdiv=0, style="soft")


@K.kind("echo_horn", hero=False, tags=["machine"], polish_opts={"detail": 1},
        story="A big petrol-enamel signal horn with a bone rim on a squat timber cradle, aimed at the dark to count the crew in.")
def echo_horn(p, v, rng):
    p.box((2.4, 1.6, 0.4), (0, 0, 0.2), C["timber_pale"])
    for x in (-0.75, 0.45):
        p.box((0.28, 1.1, 0.5), (x, 0, 0.65), C["timber_dark"])
    if v == "a":
        pts = [((-0.4, 0, 1.3), 0.2), ((0.3, 0, 1.45), 0.35), ((1.0, 0, 1.65), 0.6), ((1.5, 0, 1.85), 0.95)]
        for (a, ra), (b, rb) in zip(pts, pts[1:]):
            d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            ln = math.sqrt(sum(x * x for x in d))
            tilt = math.atan2(d[2], d[0])
            mid = tuple((a[i] + b[i]) / 2 for i in range(3))
            p.cyl(ra, ln, mid, STEEL, segs=14, r2=rb, rot=(0, FLAT - tilt, 0), style="hard_smooth")
        p.torus(0.97, 0.08, (1.55, 0, 1.87), C["bone"], rot=(0, FLAT - 0.2, 0), major=16, minor=5)
        p.cyl(0.25, 0.4, (-0.55, 0, 1.28), STEEL_D, segs=10, rot=(0, FLAT, 0), style="hard_smooth")
        for x in (-0.1, 0.9):
            p.box((0.2, 0.8, 0.2), (x, 0, 0.98 + x * 0.1), C["iron"])
    else:
        p.cyl(0.55, 1.4, (0.9, 1.5, 0.6), STEEL, segs=14, r2=0.25, rot=(FLAT, 0.0, 0.4), style="hard_smooth", jit=0.03)
        p.torus(0.57, 0.08, (1.1, 2.1, 0.62), C["bone"], rot=(FLAT, 0, 0.4), major=14, minor=5)
        p.cyl(0.22, 0.4, (0.4, 0.8, 0.5), STEEL_D, segs=10, rot=(FLAT, 0, 0.4), style="hard_smooth")
        fern_tuft(p, rng, (-1.0, 1.2, 0.0), 6, 1.0, FERN_D, 0.4)
    p.ico(0.3, (-0.9, -0.9, 0.5), C["canvas"], scale=(1.1, 0.9, 0.55), subdiv=0, style="soft")


@K.kind("tin_cart", hero=False, tags=["machine"], variants="abc", polish_opts={"detail": 1},
        story="An ore cart left with pails of tailings and a bone tally tag; solid wheels, no rails.")
def tin_cart(p, v, rng):
    tip = v == "b"
    over = v == "c"
    if tip:
        rot = (0, 0, 0)
    if not tip:
        p.box((2.2, 1.3, 0.2), (0, 0, 0.5), C["timber_dark"])
        for s in (-1, 1):
            planks(p, rng, 5, -0.9, 0.45, s * 0.66, 0.95, (0.42, 0.1, 0.7), C["timber_pale"], rot=(s * -0.12, 0, 0))
        for s in (-1, 1):
            p.box((0.1, 1.2, 0.7), (s * 1.1, 0, 0.95), tint(C["timber_pale"], rng), rot=(0, s * 0.12, 0))
        for x in (-0.6, 0.6):
            p.box((0.1, 1.5, 0.12), (x, 0, 1.28), OXIDE)
        for sx in (-0.75, 0.75):
            for sy in (-0.78, 0.78):
                p.cyl(0.36, 0.14, (sx, sy, 0.38), C["timber_dark"], segs=6, rot=(FLAT, 0, 0), style="hard")
                p.cyl(0.1, 0.2, (sx, sy, 0.38), C["iron_light"], segs=8, rot=(FLAT, 0, 0), style="hard")
        p.ico(0.8, (0, 0, 1.18), LIME_D if over else BASALT, scale=(1.2, 0.8, 0.28), subdiv=0, style="soft")
        for x in (-0.5, 0.5):
            p.cyl(0.26, 0.4, (x, 0.0, 1.18), C["iron_light"], segs=6, r2=0.3, style="hard")
        p.cyl(0.04, 0.3, (1.2, -0.45, 1.1), C["timber_dark"], segs=6)
        p.box((0.28, 0.06, 0.34), (1.2, -0.45, 1.3), C["bone"], style="hard_smooth")
        for k in range(3):
            p.box((0.04, 0.02, 0.2), (1.12 + k * 0.08, -0.49, 1.3), C["charcoal"], style="fine")
        if over:
            fern_tuft(p, rng, (0, 0, 1.2), 6, 0.7, FERN, 0.4)
            p.ico(0.55, (-1.2, 0.6, 0.35), LICHEN, scale=(1.4, 1.0, 0.4), subdiv=0, style="soft")
        else:
            p.cyl(0.2, 0.34, (1.8, 0.8, 0.17), C["iron_light"], segs=6, r2=0.23, style="hard")
    else:
        p.box((2.2, 1.3, 0.2), (0, -0.7, 0.83), C["timber_dark"])
        for k in range(5):
            p.box((0.42, 0.1, 0.7), (-0.9 + k * 0.45, -0.15 - k * 0.01, 0.43), tint(C["timber_pale"], rng), rot=(0, -0.1 * k, 0))
        p.box((0.1, 1.1, 0.7), (-1.05, -0.55, 0.43), C["timber_pale"])
        p.box((0.1, 1.1, 0.7), (1.05, -0.55, 0.43), C["timber_pale"])
        p.box((2.2, 1.1, 0.1), (0, -0.55, 0.05), C["timber_pale"])
        for sx in (-0.75, 0.75):
            p.cyl(0.36, 0.14, (sx, -0.7, 0.98), C["timber_dark"], segs=6, style="hard")
        p.cyl(0.36, 0.14, (1.9, 1.0, 0.07), C["timber_dark"], segs=6, rot=(0.1, 0, 0), style="hard")
        p.ico(0.9, (0.3, -1.4, 0.2), BASALT, scale=(1.5, 1.0, 0.3), subdiv=0, style="soft")
        for k, (x, y) in enumerate(((-1.3, -1.5), (1.4, -1.9))):
            p.cyl(0.26, 0.4, (x, y, 0.22), C["iron_light"], segs=6, r2=0.3, rot=(0, FLAT, 0.6 * k), style="hard")
        p.box((0.28, 0.06, 0.38), (-0.2, -2.2, 0.06), C["bone"], rot=(0, 0, 0.5), style="hard_smooth")


@K.kind("granary_jars", hero=False, tags=["soft"], variants="abc", polish_opts={"detail": 1},
        story="Stone seed jars of the old trench people, lidded and quiet, nobody home, no hearth.")
def granary_jars(p, v, rng):
    spec = [(0.0, 0.0, 0.55), (0.95, 0.35, 0.42), (-0.85, 0.5, 0.38), (0.3, -0.95, 0.34)]
    for sx, sy, w, d, rz in ((0.0, 0.0, 1.9, 1.5, 0.35), (0.9, 0.3, 1.3, 1.1, -0.5), (-0.9, 0.5, 1.2, 1.0, 0.9),
                             (0.3, -0.85, 1.3, 0.9, 0.1)):
        p.box((w, d, 0.28), (sx, sy, 0.14), tint(shade(LIME_D, 0.9), rng, 0.06), rot=(0, 0, rz), style="hard", jit=0.03)
    for i, (x, y, r) in enumerate(spec):
        col = tint(mix(LIME, C["sandstone_pale"], 0.4), rng, 0.06)
        if v == "b" and i == 1:
            p.ring(r * 0.5, r * 0.85, 0.2, (x, y, 0.1), col, segs=6, style="hard_smooth")
            for k in range(5):
                a = k * 1.3
                p.box((0.24, 0.16, 0.12), (x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), 0.06), col, rot=(0.0, 0.0, a), style="hard")
            continue
        if v == "c" and i == 0:
            p.uv(r, (x, y, r), col, scale=(1.0, 0.9, 0.9), rot=(0, FLAT, 0.4), u=8, v=4)
            p.box((0.5, 0.3, 0.1), (x, y, 0.05), shade(col, 0.85), rot=(0, 0, 0.4), style="hard_smooth")
            p.cyl(r * 0.5, 0.2, (x + 0.55, y + 0.2, r), shade(col, 0.8), segs=6, rot=(0, FLAT, 0.4), style="hard")
            p.cyl(r * 0.5, 0.1, (x + 1.1, y - 0.8, 0.05), shade(col, 1.05), segs=6)
            continue
        p.cyl(r * 0.62, 0.14, (x, y, 0.07), shade(col, 0.85), segs=6, style="hard")
        p.uv(r, (x, y, r * 1.15), col, scale=(1, 1, 1.15), u=8, v=4)
        p.cyl(r * 0.5, 0.12, (x, y, r * 2.2), shade(col, 0.82), segs=6, r2=r * 0.42, style="hard")
        p.cyl(r * 0.6, 0.12, (x, y, r * 2.3), shade(col, 1.06), segs=6, r2=r * 0.5, style="hard")
        p.ico(r * 0.2, (x, y, r * 2.42), shade(col, 0.9), subdiv=0, style="flat")
        for s in (-1, 1):
            p.ico(r * 0.2, (x + s * r * 0.95, y, r * 1.5), shade(col, 0.9), subdiv=0, style="flat")
    if v == "a":
        p.ico(0.3, (-0.2, -0.6, 0.12), LICHEN, scale=(1.3, 1.0, 0.3), subdiv=0, style="soft")
    if v == "c":
        fern_tuft(p, rng, (-1.4, -0.3, 0.0), 6, 0.8, FERN_D, 0.4)
    p.box((0.3, 0.22, 0.16), (1.0, -0.7, 0.08), col, rot=(0, 0, 0.7), style="hard_smooth")


@K.kind("column_stubs", hero=False, tags=[], variants="abc", polish_opts={"detail": 1},
        story="Broken basalt column stubs from the tube floor, pale lichen on their tops.")
def column_stubs(p, v, rng):
    spots = [(0, 0, 1.2), (1.05, 0.2, 0.8), (-0.95, 0.35, 1.0), (0.4, 1.0, 0.6), (-0.3, -1.0, 0.9)]
    for i, (x, y, h) in enumerate(spots):
        if v == "b":
            h = h * 2.0
        if v == "c" and i % 2:
            p.cyl(0.42, h, (x * 1.4, y * 1.4, 0.4), BASALT, segs=6, rot=(FLAT, 0, i), style="hard")
            continue
        top = rng.uniform(-0.04, 0.04)
        p.cyl(0.46, h, (x, y, h / 2), tint(BASALT, rng, 0.12), segs=6, rot=(top, -top, rng.uniform(0, 1)), style="hard")
        p.ico(0.5, (x, y, h + 0.02), LICHEN if (i + (v == "c")) % 2 == 0 else tint(LIME, rng), scale=(1, 1, 0.3), subdiv=0, style="round")
    p.ico(0.35, (0.7, 1.5, 0.2), LICHEN, scale=(1.4, 1.0, 0.4), subdiv=0, style="soft")


@K.kind("rain_gauge", hero=False, tags=["sign"], polish_opts={"detail": 1},
        story="Drip gauge on a short post: the crew counted every drop falling down from the skylights.")
def rain_gauge(p, v, rng):
    lean = (0.25, 0.1, 0) if v == "b" else (0, 0, 0)
    for k, (sx, sy, w, rz) in enumerate(((0.3, 0.2, 0.5, 0.4), (-0.3, 0.15, 0.4, 1.1), (0.0, -0.3, 0.45, 0.2))):
        p.box((w, w * 0.8, 0.22), (sx, sy, 0.11), tint(C["concrete_light"], rng, 0.08), rot=(0, 0, rz), style="hard_smooth", jit=0.02)
    p.beam((0, 0, 0.25), (0.2 * lean[0] * 4, 0, 1.0), 0.2, C["timber_pale"], style="hard")
    ox = lean[0] * 0.8
    p.cyl(0.4, 0.36, (ox, 0, 1.2), C["iron_light"], segs=6, r2=0.55, style="hard_smooth")
    tx, ty, z0, zt, fill = ox, -0.2, 0.35, 1.05, (0.35 if v == "a" else 0.2)
    p.cyl(0.1, 0.04, (tx, ty, z0 - 0.02), C["iron_light"], segs=8, style="hard")
    p.cyl(0.09, fill, (tx, ty, z0 + fill / 2), STEEL, segs=8, style="hard")
    p.cyl(0.09, zt - z0 - fill, (tx, ty, z0 + fill + (zt - z0 - fill) / 2), PALE_PAINT, segs=8, style="hard")
    for k in range(5):
        p.box((0.09 if k % 2 == 0 else 0.06, 0.03, 0.025), (tx - 0.05, ty - 0.075, 0.47 + 0.12 * k), C["charcoal"],
              style="fine", jit=0.004)
    p.ico(0.25, (0.6, -0.6, 0.15), LICHEN, scale=(1.3, 1, 0.4), subdiv=0, style="soft", jit=0.02)
    if v == "b":
        p.cyl(0.18, 0.3, (-0.9, -0.5, 0.18), C["iron_light"], segs=6, rot=(0, FLAT, 0.4), style="hard_smooth")


@K.kind("coat_hooks", hero=False, tags=["soft"], polish_opts={"detail": 1},
        story="Hooks on a short post where a miner hung a canvas coat, hand lamp and mug before the shift ended.")
def coat_hooks(p, v, rng):
    p.box((1.0, 0.7, 0.2), (0, 0, 0.1), C["timber_dark"])
    if v == "a":
        p.beam((0, 0, 0.2), (0, 0, 1.4), 0.2, C["timber_pale"])
        p.box((1.3, 0.16, 0.14), (0, 0, 1.3), C["timber_pale"])
        for x in (-0.5, 0, 0.5):
            p.rod((x, -0.1, 1.3), (x, -0.32, 1.24), 0.04, C["iron_light"], segs=6)
        p.ico(0.34, (-0.5, -0.42, 0.82), C["canvas_dark"], scale=(0.9, 0.5, 1.5), subdiv=0, style="round")
        p.ico(0.15, (-0.78, -0.42, 0.75), C["canvas_dark"], scale=(0.5, 0.5, 1.5), subdiv=0, style="round")
        p.ico(0.15, (-0.22, -0.42, 0.75), C["canvas_dark"], scale=(0.5, 0.5, 1.5), subdiv=0, style="round")
        lamp(p, (0.5, -0.45, 0.88), -FLAT, s=0.8, sg=6)
        mug(p, (0.0, -0.4, 1.12))
        p.ico(0.22, (0.4, 0.5, 0.2), C["canvas"], scale=(1.2, 0.9, 0.55), subdiv=0, style="round")
    else:
        p.beam((0.2, 0.2, 0.3), (1.4, 0.7, 0.28), 0.2, C["timber_grey"])
        p.box((0.14, 1.3, 0.14), (1.2, 0.5, 0.35), C["timber_grey"], rot=(0, 0, 0.8))
        p.ico(0.45, (-0.5, -0.6, 0.18), C["canvas_dark"], scale=(1.7, 1.0, 0.35), rot=(0, 0, 0.5), subdiv=0, style="round")
        lamp(p, (0.3, -0.9, 0.0), 2.4, s=0.8, sg=6)
        fern_tuft(p, rng, (-0.9, 0.4, 0.0), 6, 0.8, FERN, 0.4)


@K.kind("hose_reel", hero=False, tags=["machine"], polish_opts={"detail": 1},
        story="Pump hose wound on a timber reel in CABLE grey; the crew left the loose end coiled flat.")
def hose_reel(p, v, rng):
    p.box((1.8, 0.2, 0.2), (0, -0.55, 0.1), C["timber_dark"])
    p.box((1.8, 0.2, 0.2), (0, 0.55, 0.1), C["timber_dark"])
    p.box((0.2, 1.3, 0.2), (-0.8, 0, 0.1), C["timber_dark"])
    p.box((0.2, 1.3, 0.2), (0.8, 0, 0.1), C["timber_dark"])
    if v == "a":
        zc = 0.72
        for s in (-1, 1):
            p.cyl(0.66, 0.1, (0, s * 0.45, zc), C["timber_pale"], segs=6, rot=(FLAT, 0, 0), style="hard_smooth")
            p.beam((s * 0.7, s * 0.55, 0.2), (s * 0.5, s * 0.5, zc), 0.14, C["timber_dark"])
        p.cyl(0.25, 0.9, (0, 0, zc), C["timber_dark"], segs=6, rot=(FLAT, 0, 0), style="hard_smooth")
        for k in range(5):
            p.torus(0.42 + 0.06 * (k % 2), 0.1, (0, -0.28 + k * 0.14, zc), C["cable"], rot=(FLAT, 0, 0), major=10, minor=4, style="flat")
        p.cyl(0.07, 0.4, (0.9, 0, zc), COPPER, segs=6, rot=(0, FLAT, 0))
        p.torus(0.28, 0.06, (1.3, 0.9, 0.06), C["cable"], major=10, minor=4, style="flat")
        p.torus(0.2, 0.06, (1.3, 0.9, 0.13), C["cable"], major=10, minor=4, style="flat")
    else:
        p.cyl(0.75, 0.1, (0, 0, 0.55), C["timber_pale"], segs=6, rot=(0.0, 0.0, 0), style="hard_smooth")
        p.cyl(0.75, 0.1, (0, 0, 1.05), C["timber_pale"], segs=6, rot=(0.0, 0.0, 0), style="hard_smooth")
        p.cyl(0.25, 0.5, (0, 0, 0.8), C["timber_dark"], segs=6, style="hard_smooth")
        for k in range(3):
            p.torus(0.42, 0.1, (0, 0, 0.66 + k * 0.14), C["cable"], major=10, minor=4, style="flat")
        for k, (x, y, r) in enumerate(((1.9, 0.4, 0.55), (1.6, -0.8, 0.4), (-1.6, 0.9, 0.45))):
            p.torus(r, 0.1, (x, y, 0.1), C["cable"], major=10, minor=4, style="flat")
            p.torus(r * 0.55, 0.1, (x, y, 0.1), C["cable"], major=8, minor=4, style="flat")
        p.ico(0.35, (-1.2, -0.9, 0.3), LICHEN, scale=(1.3, 1, 0.4), subdiv=0, style="soft")
    p.cyl(0.14, 0.3, (1.15, -0.9, 0.2), COPPER, segs=8, r2=0.1, style="hard_smooth")


@K.kind("tally_post", hero=False, tags=["sign"], polish_opts={"detail": 1},
        story="A short post with a pale board of five-bar stroke tallies, counting shifts nobody finished.")
def tally_post(p, v, rng):
    lean = 0.12 if v == "b" else 0.0
    for k, (sx, sy, w, rz) in enumerate(((0.3, 0.2, 0.5, 0.4), (-0.3, 0.1, 0.45, 1.1), (0.1, -0.3, 0.4, 0.2))):
        p.box((w, w * 0.8, 0.2), (sx, sy, 0.1), tint(C["concrete_light"], rng, 0.08), rot=(0, 0, rz), style="hard_smooth", jit=0.02)
    p.beam((0, 0, 0.15), (lean, 0, 1.15), 0.3, C["timber_pale"])
    p.box((0.95, 0.12, 0.8), (lean * 0.8, -0.2, 0.8), C["charcoal"], rot=(0, -lean, 0), style="hard_smooth")
    p.box((1.05, 0.14, 0.08), (lean * 0.8, -0.2, 1.22), C["timber_dark"], rot=(0, -lean, 0))
    groups = 4 if v == "a" else 2
    for g in range(groups):
        for r in range(2):
            gx = -0.32 + g * 0.22 if v == "a" else -0.2 + g * 0.3
            for k in range(4):
                p.box((0.025, 0.03, 0.2), (lean * 0.8 + gx + k * 0.035 - 0.05, -0.28, 0.95 - r * 0.3), PALE_PAINT, style="fine")
            p.box((0.15, 0.03, 0.025), (lean * 0.8 + gx + 0.035, -0.28, 0.95 - r * 0.3), PALE_PAINT, rot=(0, 0.5, 0), style="fine")
    p.ico(0.3, (0.7, -0.6, 0.15), LICHEN, scale=(1.3, 1, 0.35), subdiv=0, style="soft")
    if v == "b":
        p.box((0.7, 0.09, 0.4), (-0.9, -0.5, 0.06), C["charcoal"], rot=(0.05, 0, 0.5), style="hard_smooth")


@K.kind("cave_fern", hero=False, tags=["plant"], variants="abc", polish_opts={"detail": 1},
        story="Ferns and moss mats where skylights let in light; they grow through everything the crew left.")
def cave_fern(p, v, rng):
    if v == "a":
        fern_tuft(p, rng, (0, 0, 0), 9, 1.8, FERN, 0.5)
        fern_tuft(p, rng, (0.6, 0.4, 0), 6, 1.0, FERN_D, 0.4)
        p.ico(0.5, (0, 0, 0.05), LICHEN, scale=(1.6, 1.6, 0.3), subdiv=0, style="soft")
    elif v == "b":
        fern_tuft(p, rng, (0, 0, 0), 11, 2.0, FERN, 0.55, 0.5)
        fern_tuft(p, rng, (-0.7, 0.5, 0), 8, 1.4, FERN_D, 0.45)
        fern_tuft(p, rng, (0.8, -0.5, 0), 7, 1.1, FERN, 0.4)
        p.ico(0.6, (0, 0, 0.1), tint(LICHEN, rng), scale=(1.7, 1.7, 0.3), subdiv=0, style="soft")
    else:
        for i in range(5):
            a = TAU * i / 5 + rng.uniform(-0.3, 0.3)
            r = rng.uniform(0.2, 1.1) if i else 0
            rad = rng.uniform(0.45, 0.8)
            p.ico(rad, (r * math.cos(a), r * math.sin(a), 0.1), tint(FERN_D if i % 3 else FERN, rng, 0.08),
                  scale=(1.3, 1.3, 0.38), style="soft")
        for i in range(3):
            a = TAU * i / 3
            p.ico(0.3, (1.1 * math.cos(a), 1.1 * math.sin(a), 0.22), LICHEN, scale=(1.2, 1.2, 0.35), subdiv=1, style="flat")
        fern_tuft(p, rng, (0.1, 0.0, 0.15), 5, 0.7, FERN, 0.4)


@K.kind("drill_steels", hero=False, tags=[], polish_opts={"detail": 1},
        story="A bundle of drill steels leaned against a low timber crossbar, a canvas wrap loose at the middle.")
def drill_steels(p, v, rng):
    if v == "a":
        for s in (-1, 1):
            p.beam((s * 0.55, -0.55, 0.0), (s * 0.15, 0.05, 0.8), 0.13, C["timber_pale"])
            p.beam((s * 0.55, 0.65, 0.0), (s * 0.15, 0.05, 0.8), 0.13, C["timber_dark"])
        p.beam((-0.4, 0.05, 0.8), (0.4, 0.05, 0.8), 0.14, C["timber_pale"])
        for k in range(8):
            ang = TAU * k / 8
            ox, oy = 0.15 * math.cos(ang), 0.1 * math.sin(ang)
            top = (ox * 0.5, 0.15 + oy * 0.6, 1.15 + 0.05 * (k % 3))
            p.rod((ox * 1.8, -0.7 + oy, 0.02), top, 0.045, STEEL if k % 2 else C["iron_light"], segs=6)
            p.cyl(0.075, 0.1, (ox * 1.8, -0.7 + oy, 0.05), PALE_PAINT, segs=6, style="hard_smooth")
        p.cyl(0.2, 0.3, (0.0, 0.05, 0.9), C["canvas"], segs=10, rot=(FLAT, 0, 0), style="soft")
    else:
        for k in range(8):
            a = 0.2 * k - 0.7
            p.rod((-0.7, -0.5 + 0.13 * k, 0.06 + 0.02 * (k % 2)), (0.7 + 0.06 * k, -0.5 + 0.16 * k + a * 0.3, 0.06),
                  0.045, STEEL if k % 2 else C["iron_light"], segs=6)
        p.beam((0.2, 1.0, 0.1), (1.2, 1.5, 0.12), 0.13, C["timber_dark"])
        p.beam((0.4, 1.4, 0.1), (-0.3, 0.8, 0.3), 0.13, C["timber_pale"])
        p.ico(0.25, (-0.8, 0.5, 0.1), C["canvas_dark"], scale=(1.4, 1, 0.4), subdiv=0, style="soft")
        p.ico(0.3, (1.3, -0.5, 0.1), LICHEN, scale=(1.4, 1, 0.3), subdiv=0, style="soft")


@K.kind("mist_rings", hero=False, tags=["soft"], polish_opts={"detail": 1},
        story="Terraced limestone rimstone rings where the pool edge seeps, smooth and pale, never glowing.")
def mist_rings(p, v, rng):
    n = 3 if v == "a" else 2
    for i in range(n):
        r = 1.9 - i * 0.55
        p.torus(r, 0.2 - 0.02 * i, (0, 0, 0.18 + i * 0.16), tint(LIME, rng, 0.04), major=10, minor=4, style="round")
    p.cyl(1.2 - 0.3 * (n - 2), 0.18 + 0.16 * n, (0, 0, 0.1 + 0.08 * n), shade(LIME_D, 0.95), segs=18, style="hard_smooth")
    p.ico(0.55, (1.2, 1.0, 0.18), LICHEN, scale=(1.6, 1.1, 0.35), subdiv=0, style="soft")
    if v == "a":
        for k in range(4):
            a = 1.1 + k * 1.4
            p.ico(0.22, (2.2 * math.cos(a), 2.2 * math.sin(a), 0.14), tint(LIME, rng, 0.1), scale=(1.2, 1, 0.7), subdiv=0, style="round")
    else:
        fern_tuft(p, rng, (-1.3, 0.9, 0.0), 7, 0.9, FERN, 0.4)
        p.box((0.9, 0.5, 0.22), (1.3, -1.7, 0.12), LIME_D, rot=(0, 0.1, 0.8), style="hard_smooth")


if __name__ == "__main__":
    K.main()
