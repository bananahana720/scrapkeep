"""Dam park dressing kit (Dressing lane proof: the dam writer extends this recipe).

The dam crew was a survey-and-sluice outfit: timber and concrete works, canvas and chain,
tools left where the last shift dropped them.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/dam.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, tint

K = kit.Kit("dam")


@K.kind("gate_wheelhouse", hero=True, tags=["machine"], variants="ab",
        story="Sluice crew's wheelhouse: a big hand wheel chained shut, timber walls on a concrete plinth.")
def gate_wheelhouse(p, v, rng):
    sag = 0.38 if v == "b" else 0.0
    # Concrete plinth with chipped corners and a stain band.
    p.box((4.0, 3.2, 0.4), (0, 0, 0.2), C["concrete"], style="hard_smooth")
    p.box((4.1, 0.5, 0.18), (0, -1.55, 0.09), C["concrete_light"], style="hard_smooth")
    for x, y in ((-1.9, -1.5), (1.9, 1.5), (1.95, -1.4)):
        p.box((0.28, 0.28, 0.14), (x, y, 0.45), mix(C["concrete"], C["concrete_stain"], 0.5), rot=(0, 0, rng.uniform(0, 1.5)))
    # Corner posts.
    for x in (-1.75, 1.75):
        for y in (-1.3, 1.3):
            p.beam((x, y, 0.4), (x, y, 2.35), 0.2, tint(C["timber_dark"], rng, 0.05))
    # Wall planks: back, sides, front (a door of wide planks, set a hair proud).
    for i in range(16):
        x = -1.58 + i * 0.21
        p.box((0.2, 0.12, 1.9), (x, 1.3, 1.35), tint(C["timber"], rng), jit=0.004)
    for s in (-1, 1):
        for i in range(11):
            y = -1.05 + i * 0.21
            if v == "b" and s == 1 and i in (3, 4):
                continue  # a gap where two planks came away
            p.box((0.12, 0.2, 1.9), (s * 1.75, y, 1.35), tint(C["timber_grey"] if s == 1 else C["timber"], rng), jit=0.004)
    for i in range(16):
        x = -1.58 + i * 0.21
        door = -0.62 <= x <= 0.1
        p.box((0.2, 0.12, 1.9 if not door else 1.75), (x, -1.3, 1.35 if not door else 1.275),
              tint(C["timber_pale"] if door else C["timber"], rng), jit=0.004)
    for z in (0.7, 1.9):
        p.beam((-1.78, -1.38, z), (1.78, -1.38, z), 0.1, C["timber_dark"], h=0.08)
    # Roof: planks in rows up each slope; the ridge dips in the sagging variant.
    rise, half, rows, segs = 0.75, 1.85, 8, 6
    theta = math.atan2(rise, half)
    seg_len = 3.9 / segs
    for s in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            for j in range(segs):
                if v == "b" and s == -1 and j in (2, 3) and r >= 5:
                    continue  # open hole in the sagging roof
                x = -1.95 + (j + 0.5) * seg_len
                dip = sag * (1 - (x / 1.95) ** 2) * (0.35 + 0.65 * t)
                slope = math.atan2(sag * 2 * x / 1.95 ** 2, 1.0) if sag else 0.0
                p.box((seg_len + 0.02, 0.5, 0.07),
                      (x, s * half * (1 - t), 2.35 + rise * t - dip),
                      tint(C["timber_grey"] if (r + j) % 3 else C["timber_dark"], rng, 0.07),
                      rot=(-s * theta, slope, 0), jit=0.005)
    for j in range(5):
        x = -1.9 + j * 0.95
        dip = sag * (1 - (x / 1.95) ** 2) * 0.4
        for s in (-1, 1):
            p.beam((x, s * half, 2.3), (x, 0, 2.3 + rise - dip - 0.05), 0.11, C["timber_dark"], h=0.09)
    p.beam((-1.95, 0, 2.3 + rise - 0.02), (1.95, 0, 2.3 + rise - 0.02 - (sag * 0.4)), 0.14, C["timber_dark"])
    if v == "b":
        # Canvas patch slumped over the hole, planks that fell to the plinth.
        p.ico(0.8, (-0.15, -0.5, 2.55), C["canvas_dark"], scale=(1.5, 1.0, 0.22), rot=(0.4, 0, 0.1), style="soft")
        p.box((1.6, 0.26, 0.07), (-0.6, -1.95, 0.1), C["timber_grey"], rot=(0, 0, 0.35))
        p.box((1.2, 0.24, 0.07), (0.3, -2.1, 0.22), C["timber_dark"], rot=(0.05, 0, -0.5))
        p.box((1.0, 0.22, 0.07), (-1.8, -1.85, 0.07), C["timber_pale"], rot=(0, 0, 1.2))
    else:
        p.ico(0.45, (-1.3, -1.7, 0.3), C["canvas"], scale=(1.0, 0.8, 0.7), style="soft")  # folded tarp
    # The big hand wheel on the front wall: rim, hub, spokes, grips, chained shut.
    wx, wy, wz, wr = 0.95, -1.72, 1.35, 0.78
    face = (math.pi / 2, 0, 0)
    p.box((0.34, 0.3, 1.5), (wx, -1.5, 1.1), C["timber_dark"])  # wheel bracket
    p.cyl(0.09, 0.5, (wx, -1.65, wz), C["iron"], segs=8, rot=face)  # axle
    p.torus(wr, 0.075, (wx, wy, wz), C["iron_light"] if v == "a" else C["rust"], rot=face, major=16, minor=6)
    p.cyl(0.2, 0.2, (wx, wy, wz), C["iron"], segs=10, rot=face, style="round")
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        p.rod((wx + 0.1 * math.cos(a), wy, wz + 0.1 * math.sin(a)),
              (wx + wr * math.cos(a), wy, wz + wr * math.sin(a)), 0.045, C["iron"], segs=6)
    for k in range(4):
        a = math.tau * k / 4 + 0.2
        p.cyl(0.06, 0.28, (wx + (wr + 0.02) * math.cos(a), wy - 0.05, wz + (wr + 0.02) * math.sin(a)),
              C["timber_dark"], segs=6, rot=face)
    # Chain from the rim to a ring on the plinth, and a padlock block where it crosses a spoke.
    ring_x = wx - 0.05
    p.ring(0.05, 0.12, 0.08, (ring_x, -1.85, 0.5), C["iron"], segs=8, rot=(math.pi / 2, 0, 0))
    if v == "a":
        p.chain((wx, wy - 0.12, wz + wr), (ring_x, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.0)
        p.chain((wx + wr, wy - 0.12, wz), (ring_x + 0.1, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.35)
    else:
        p.chain((wx, wy - 0.12, wz + wr), (ring_x + 0.4, -2.3, 0.1), C["cable"], link=0.12, radius=0.022, sag=0.3)
        p.chain((wx + wr, wy - 0.12, wz), (ring_x, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.3)
    p.box((0.22, 0.14, 0.26), (wx + 0.02, wy - 0.18, wz + 0.3), C["iron"], style="hard_smooth")
    # Work boots-width step stone and a bucket-less tool leaning flat: a short-handled mallet.
    p.cyl(0.07, 0.9, (-1.0, -2.35, 0.07), C["timber_dark"], segs=6, rot=(0, math.pi / 2, 0.3))
    p.cyl(0.13, 0.32, (-0.5, -2.2, 0.13), C["iron"], segs=8, rot=(0, math.pi / 2, 0.3), style="hard_smooth")


@K.kind("survey_tripod", hero=False, tags=["machine"], variants="ab", polish_opts={"detail": 1},
        story="A survey tripod knocked flat when the line broke, its plumb bob still on its cord.")
def survey_tripod(p, v, rng):
    leg_r = 0.045
    if v == "a":
        # Toppled on its side: one leg propped up, two on the ground.
        head = (0.0, 0.0, 0.24)
        feet = [(1.35, 0.15, 0.06), (0.4, 1.0, 0.07), (0.35, -0.55, 0.85)]
    else:
        # Folded and dropped: three legs near parallel, head at one end.
        head = (-0.7, 0.0, 0.2)
        feet = [(0.8, 0.14, 0.06), (0.75, -0.14, 0.06), (0.7, 0.0, 0.2)]
    for k, f in enumerate(feet):
        p.rod(head, f, leg_r, tint(C["timber"], rng), segs=6, r2=leg_r * 0.8)
        p.cyl(0.065, 0.14, f, C["iron"], segs=6, r2=0.03, style="hard_smooth",
              rot=(0, math.pi / 2 + (0.4 if k == 2 else 0.1), 0))
        mid = tuple(head[i] + (f[i] - head[i]) * 0.3 for i in range(3))
        p.box((0.1, 0.1, 0.1), mid, C["iron_light"], rot=(0.2 * k, 0.4, 0.3 * k))
    p.cyl(0.15, 0.1, head, C["iron"], segs=10, style="hard_smooth", rot=(0.3, 0.1, 0.4))
    p.cyl(0.04, 0.2, (head[0], head[1], head[2] + 0.12), C["iron_light"], segs=6, rot=(0.3, 0.1, 0.4))
    # The instrument: a short telescope barrel on the ground beside the head.
    tx, ty = (-0.45, -0.35) if v == "a" else (0.0, -0.45)
    p.cyl(0.075, 0.55, (tx, ty, 0.1), C["canvas_dark"], segs=10, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    p.cyl(0.1, 0.1, (tx - 0.3, ty - 0.09, 0.1), C["iron"], segs=10, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    p.cyl(0.07, 0.08, (tx + 0.3, ty + 0.09, 0.1), C["verdigris"], segs=8, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    # The chunky plumb bob, rolled aside, and its slack cord.
    bx, by = (0.55, 0.45) if v == "a" else (-0.2, 0.55)
    p.cyl(0.11, 0.24, (bx, by, 0.11), C["charcoal"], segs=10, r2=0.02, rot=(0, math.pi / 2, 0.8), style="hard_smooth")
    p.uv(0.11, (bx - 0.07, by - 0.07, 0.11), C["iron"], scale=(1, 1, 0.95), u=10, v=6, style="round")
    pts = [(bx + 0.1, by + 0.1, 0.03), (bx + 0.3, by + 0.22, 0.03), (bx + 0.35, by + 0.5, 0.03),
           (bx + 0.12, by + 0.62, 0.03), (head[0] + 0.1, head[1] + 0.3, head[2] - 0.12)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.016, C["cable"], segs=6)
    if v == "a":
        p.ico(0.22, (-0.9, 0.55, 0.12), C["canvas"], scale=(1.0, 0.8, 0.6), style="soft")  # kit bag, slumped
    else:
        p.ico(0.2, (0.2, -0.85, 0.11), C["canvas_dark"], scale=(1.1, 0.8, 0.55), style="soft")


if __name__ == "__main__":
    K.main()
