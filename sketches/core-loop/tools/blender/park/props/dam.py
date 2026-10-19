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
        p.chain((wx, wy - 0.12, wz + wr), (ring_x, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.3)
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



@K.kind("crew_cookshack", hero=True, tags=["camp"], variants="ab",
        story="The cook's canvas shack: a stove pipe through the roof, a long table, and the menu board that never changes.")
def crew_cookshack(p, v, rng):
    torn = v == "b"
    # Timber deck on stone feet.
    for x in (-1.9, 0.0, 1.9):
        for y in (-1.3, 1.3):
            p.ico(0.26, (x, y, 0.12), tint(C["sandstone_dark"], rng), scale=(1.2, 1.0, 0.6), subdiv=1, style="hard_smooth", jit=0.02)
    for i in range(14):
        x = -1.95 + i * 0.3
        p.box((0.28, 3.0, 0.08), (x, 0, 0.3), tint(C["timber_grey"], rng), jit=0.004)
    for y in (-1.3, 1.3):
        p.beam((-2.1, y, 0.2), (2.1, y, 0.2), 0.16, C["timber_dark"])
    # Frame: four corner poles and a ridge (the b pole leans where a guy came loose).
    lean = 0.35 if torn else 0.0
    poles = [(-2.0, -1.4), (2.0, -1.4), (-2.0, 1.4), (2.0, 1.4)]
    for k, (x, y) in enumerate(poles):
        top = (x + (lean if k == 1 else 0), y - (lean * 0.5 if k == 1 else 0), 2.1 - (0.3 if torn and k == 1 else 0))
        p.rod((x, y, 0.34), top, 0.06, tint(C["timber"], rng), segs=6)
    for x in (-2.0, 2.0):
        p.rod((x, -1.4, 2.1), (x, 0, 2.9), 0.055, C["timber_dark"], segs=6)
        p.rod((x, 1.4, 2.1), (x, 0, 2.9), 0.055, C["timber_dark"], segs=6)
    p.rod((-2.1, 0, 2.9), (2.1, 0, 2.9 - (0.15 if torn else 0)), 0.065, C["timber_dark"], segs=6)
    # Canvas roof in panels with a little slump between rafters; b has a slumped, torn east corner.
    theta = math.atan2(0.8, 1.4)
    for s in (-1, 1):
        for j in range(4):
            x = -1.6 + j * 1.07
            if torn and s == -1 and j == 3:
                continue
            p.box((1.1, 1.75, 0.05), (x, s * 0.72, 2.47), tint(C["canvas"] if j % 2 else C["canvas_dark"], rng, 0.04),
                  rot=(-s * theta, 0, 0), style="hard_smooth", jit=0.03)
    if torn:
        p.ico(0.7, (1.95, -1.1, 1.75), C["canvas_stain"], scale=(1.1, 0.9, 0.35), rot=(0.6, 0.2, 0), subdiv=1, style="round", jit=0.05)
    # Rolled side flap along the back.
    p.cyl(0.13, 3.9, (0, 1.48, 1.9), C["canvas_dark"], segs=8, rot=(0, math.pi / 2, 0), style="round")
    # Stove with a pipe through the roof and a dented cap.
    p.box((0.7, 0.6, 0.65), (-1.4, 0.8, 0.67), C["iron"], style="hard_smooth")
    p.box((0.6, 0.06, 0.3), (-1.4, 0.48, 0.72), C["charcoal"])
    p.cyl(0.09, 2.6, (-1.4, 0.75, 2.3), C["iron_light"], segs=8)
    p.cyl(0.18, 0.08, (-1.4, 0.75, 3.62), C["iron"], segs=8, rot=(0.2, 0.1, 0))
    p.cyl(0.2, 0.12, (-1.2, 0.85, 1.06), C["charcoal"], segs=10)  # pot on the stove
    # Long table on two trestle legs, plates and a big pan.
    p.box((2.4, 0.8, 0.08), (0.5, 0.15, 1.08), C["timber_pale"], jit=0.004)
    for x in (-0.5, 1.5):
        p.rod((x, -0.2, 0.34), (x, 0.15, 1.04), 0.045, C["timber_dark"], segs=6)
        p.rod((x, 0.5, 0.34), (x, 0.15, 1.04), 0.045, C["timber_dark"], segs=6)
    for k in range(4):
        p.cyl(0.13, 0.03, (-0.3 + k * 0.5, -0.05 + 0.2 * (k % 2), 1.14), C["bone"], segs=10)
    p.cyl(0.25, 0.09, (1.4, 0.35, 1.17), C["iron"], segs=12)
    p.rod((1.6, 0.35, 1.18), (2.05, 0.4, 1.2), 0.025, C["iron"], segs=6)
    # Benches either side, one tipped over in b.
    for y in (-0.5, 0.8):
        if torn and y > 0:
            p.box((2.0, 0.08, 0.32), (0.6, 0.85, 0.5), C["timber"], rot=(0.25, 0, 0))
        else:
            p.box((2.0, 0.32, 0.07), (0.5, y, 0.68), C["timber"], jit=0.004)
            for x in (-0.3, 1.3):
                p.box((0.08, 0.28, 0.32), (x, y, 0.5), C["timber_dark"])
    # The menu board: chalk bars that read the same as yesterday.
    mx, my = 2.35, -1.9
    p.box((0.9, 0.06, 0.65), (mx, my, 0.75), C["charcoal"], rot=(0.25, 0, -0.2))
    for k in range(3):
        p.box((0.55 - k * 0.12, 0.02, 0.05), (mx - 0.05, my - 0.06, 0.92 - k * 0.15), C["bone"], rot=(0.25, 0, -0.2), style="flat")
    p.box((0.95, 0.08, 0.06), (mx, my + 0.12, 0.42), C["timber_dark"], rot=(0.25, 0, -0.2))
    # Sacks and a wash tub by the steps.
    p.ico(0.32, (-2.4, -0.9, 0.3), C["canvas_stain"], scale=(0.8, 0.7, 1.0), subdiv=1, style="round", jit=0.02)
    p.ico(0.28, (-2.45, -0.35, 0.25), C["canvas"], scale=(0.8, 0.75, 0.9), subdiv=1, style="round", jit=0.02)
    p.ring(0.32, 0.4, 0.28, (-0.4, -2.0, 0.14), C["iron_light"], segs=12)
    p.cyl(0.33, 0.04, (-0.4, -2.0, 0.03), C["iron"], segs=12)
    p.box((0.9, 0.5, 0.12), (0.6, -1.75, 0.08), C["timber_grey"])  # step


@K.kind("haul_wagon", hero=True, tags=["machine"], variants="ab",
        story="A sandbag wagon on four big spoked wheels; b threw a wheel and the crew propped the corner on stones and went to lunch.")
def haul_wagon(p, v, rng):
    lost = v == "b"
    zb = 1.05
    # Bed: planks over two runners, low side boards.
    for i in range(9):
        y = -0.8 + i * 0.2
        p.box((3.6, 0.19, 0.08), (0, y, zb), tint(C["timber"], rng), jit=0.004)
    for y in (-0.6, 0.6):
        p.beam((-1.8, y, zb - 0.12), (1.8, y, zb - 0.12), 0.16, C["timber_dark"])
    for y in (-0.92, 0.92):
        p.box((3.6, 0.07, 0.32), (0, y, zb + 0.2), tint(C["timber_grey"], rng), jit=0.004)
    for x in (-1.82, 1.82):
        p.box((0.07, 1.8, 0.32), (x, 0, zb + 0.2), C["timber_grey"])
    for x in (-1.2, 0.0, 1.2):
        for y in (-0.92, 0.92):
            p.box((0.1, 0.1, 0.4), (x, y * 1.03, zb + 0.18), C["iron"], style="hard_smooth")
    # Axles and wheels: iron-tyred timber wheels, ten spokes.
    def wheel(cx, cy, cz, rot, rim_col):
        r = 0.62
        p.torus(r, 0.06, (cx, cy, cz), rim_col, rot=rot, major=14, minor=4)
        p.torus(r - 0.07, 0.05, (cx, cy, cz), C["timber_dark"], rot=rot, major=14, minor=4)
        p.cyl(0.14, 0.22, (cx, cy, cz), C["iron"], segs=10, rot=rot, style="round")
        m = rot
        for k in range(8):
            a = math.tau * k / 8
            if m[0]:  # upright wheel in the XZ plane
                a0 = (cx + 0.12 * math.cos(a), cy, cz + 0.12 * math.sin(a))
                a1 = (cx + (r - 0.08) * math.cos(a), cy, cz + (r - 0.08) * math.sin(a))
            else:  # lying flat
                a0 = (cx + 0.12 * math.cos(a), cy + 0.12 * math.sin(a), cz)
                a1 = (cx + (r - 0.08) * math.cos(a), cy + (r - 0.08) * math.sin(a), cz)
            p.rod(a0, a1, 0.035, C["timber"], segs=5)
    for x in (-1.25, 1.25):
        p.cyl(0.06, 2.2, (x, 0, 0.64), C["iron"], segs=8, rot=(math.pi / 2, 0, 0), style="round")
        for y in (-1.08, 1.08):
            if lost and x < 0 and y < 0:
                continue
            wheel(x, y, 0.64, (math.pi / 2, 0, 0), C["iron_light"])
    if lost:
        # The thrown wheel lies flat; three stones hold the corner up.
        wheel(-2.1, -1.9, 0.07, (0, 0, 0), C["rust"])
        for k, (dz, sc) in enumerate(((0.16, 0.34), (0.42, 0.28), (0.63, 0.22))):
            p.ico(sc, (-1.25 + 0.05 * k, -0.95, dz), tint(C["sandstone"], rng), scale=(1.2, 1.0, 0.6), subdiv=0, style="round", jit=0.02)
    # Drawbar resting on the ground in front.
    p.beam((1.8, 0, 0.75), (3.4, 0.1, 0.1), 0.12, C["timber_dark"])
    p.torus(0.12, 0.03, (3.5, 0.1, 0.06), C["iron"], major=10, minor=4)
    # The load: sandbags in two courses, some slid off in b, and a coil of rope on top.
    bags = [(x, y) for x in (-1.3, -0.65, 0.0, 0.65, 1.3) for y in (-0.42, 0.42)]
    for k, (x, y) in enumerate(bags):
        if lost and k in (0, 1, 2):
            continue
        p.ico(0.3, (x, y, zb + 0.2), tint(C["canvas_stain"], rng, 0.06), scale=(1.05, 1.35, 0.5), rot=(0, 0, rng.uniform(-0.2, 0.2)), subdiv=1, style="round", jit=0.015)
    for x, y in ((-0.3, 0.0), (0.35, 0.05)):
        p.ico(0.3, (x, y, zb + 0.5), tint(C["canvas"], rng, 0.06), scale=(1.05, 1.35, 0.5), rot=(0, 0, 0.3), subdiv=1, style="round", jit=0.015)
    if lost:
        for x, y, r in ((-2.2, -0.2, 0.4), (-2.45, 0.55, 1.1)):
            p.ico(0.3, (x, y, 0.13), C["canvas_stain"], scale=(1.05, 1.35, 0.5), rot=(0, 0, r), subdiv=1, style="round", jit=0.02)
    p.torus(0.28, 0.06, (1.15, 0.1, zb + 0.5), C["canvas_dark"], major=14, minor=5)
    p.torus(0.2, 0.06, (1.15, 0.1, zb + 0.6), C["canvas_dark"], major=12, minor=5)


@K.kind("crew_campfire", variants="ab", polish_opts={"detail": 1},
        story="The night shift's fire ring: a kettle on the stones, and in b a forgotten toasting stick still upright in the sand.")
def crew_campfire(p, v, rng):
    cold = v == "b"
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.1, 0.1)
        r = 0.78 + rng.uniform(-0.05, 0.05)
        p.ico(0.17 + rng.uniform(-0.03, 0.04), (r * math.cos(a), r * math.sin(a), 0.1),
              tint(C["sandstone_dark"], rng, 0.1), scale=(1.2, 1.0, 0.75), rot=(0, 0, a), subdiv=0, style="round", jit=0.02)
    p.cyl(0.62, 0.04, (0, 0, 0.02), mix(C["charcoal"], C["soil"], 0.4), segs=12)
    logs = [((-0.45, -0.1, 0.12), (0.4, 0.15, 0.2)), ((0.1, -0.45, 0.12), (-0.05, 0.42, 0.22)),
            ((-0.3, 0.35, 0.1), (0.35, -0.3, 0.26))]
    if cold:
        logs = [((-0.45, -0.1, 0.08), (0.35, 0.0, 0.08)), ((1.1, 0.5, 0.08), (1.6, 0.1, 0.08))]
    for a, b in logs:
        p.rod(a, b, 0.07, C["charcoal"] if not cold else C["timber_dark"], segs=6)
    # Kettle on a flat stone: squat body, spout and a bail handle.
    kx, ky = (0.95, -0.45) if not cold else (-0.95, 0.5)
    p.cyl(0.2, 0.08, (kx, ky, 0.04), C["sandstone"], segs=8)
    p.uv(0.17, (kx, ky, 0.22), C["iron_light"] if not cold else C["verdigris"], scale=(1, 1, 0.75), u=8, v=6)
    p.rod((kx + 0.14, ky, 0.22), (kx + 0.3, ky, 0.32), 0.025, C["iron_light"], segs=5)
    p.ring(0.13, 0.15, 0.02, (kx, ky, 0.4), C["iron"], segs=10, rot=(math.pi / 2, 0, 0), arc=(0.0, math.pi))
    if cold:
        # The toasting stick and its blob; a tin mug knocked over.
        p.rod((0.6, 0.9, 0.0), (0.2, 1.2, 0.9), 0.018, C["timber_pale"], segs=5)
        p.uv(0.05, (0.18, 1.22, 0.92), C["bone"], scale=(1, 1, 1.3), u=6, v=4)
        p.cyl(0.06, 0.12, (-0.2, -1.15, 0.06), C["iron_light"], segs=8, rot=(math.pi / 2, 0, 0.4))
    else:
        p.box((0.7, 0.25, 0.25), (-1.35, 0.2, 0.13), C["timber"], rot=(0, 0, 0.3), style="hard_smooth")  # sitting log end
        p.cyl(0.13, 0.7, (-1.35, 0.2, 0.13), C["timber"], segs=8, rot=(0, math.pi / 2, 0.3), style="round")


@K.kind("timber_stack", tags=["build"], variants="ab", polish_opts={"detail": 1},
        story="Form timber stacked on bearers to season; b slid when someone pulled from the bottom.")
def timber_stack(p, v, rng):
    slid = v == "b"
    for x in (-1.1, 0.0, 1.1):
        p.box((0.16, 1.3, 0.14), (x, 0, 0.07), C["timber_dark"], rot=(0, 0, rng.uniform(-0.05, 0.05)))
    layers = 3 if not slid else 2
    for L in range(layers):
        z = 0.2 + L * 0.17
        for i in range(5):
            y = -0.48 + i * 0.24
            dx = rng.uniform(-0.12, 0.12)
            p.box((3.0, 0.2, 0.08), (dx, y, z), tint(C["timber_pale"] if (i + L) % 3 else C["timber"], rng), rot=(0, 0, rng.uniform(-0.02, 0.02)), jit=0.004)
        if L < layers - 1:
            for x in (-1.0, 0.0, 1.0):
                p.box((0.05, 1.2, 0.05), (x, 0, z + 0.08), C["timber_grey"], style="fine")  # stickers
    if slid:
        for k in range(4):
            p.box((2.8, 0.2, 0.08), (0.6 + k * 0.1, -1.0 - k * 0.25, 0.1 + 0.07 * (k % 2)),
                  tint(C["timber_pale"], rng), rot=(0.12 * (k % 2), 0.08, 0.25 + 0.1 * k), jit=0.004)
        p.ico(0.35, (-1.2, 0.3, 0.55), C["canvas_dark"], scale=(1.5, 1.6, 0.25), subdiv=1, style="round", jit=0.03)
    else:
        p.ico(0.45, (0.9, 0.0, 0.78), C["canvas"], scale=(1.4, 1.5, 0.22), subdiv=1, style="round", jit=0.03)
        p.ico(0.16, (1.2, 0.15, 0.85), C["sandstone_dark"], scale=(1.1, 1.0, 0.7), subdiv=1, style="hard_smooth")  # stone on the tarp


@K.kind("sandbag_berm", tags=["build"], variants="ab", polish_opts={"detail": 1},
        story="A curved sandbag berm from the flood that never came; b has a gap where a shovel is still stuck in the pile.")
def sandbag_berm(p, v, rng):
    gap = v == "b"
    for course, (z, n, r) in enumerate(((0.12, 9, 3.0), (0.32, 8, 3.0))):
        for k in range(n):
            t = (k + 0.5 * course) / 8.5
            a = -0.55 + 1.1 * t
            if gap and course == 1 and k in (3, 4):
                continue
            if gap and course == 0 and k == 4:
                continue
            x, y = r * math.sin(a), r * (1 - math.cos(a)) - 0.3
            p.ico(0.3, (x, y, z), tint(C["canvas_stain"] if (k + course) % 2 else C["canvas_dark"], rng, 0.06),
                  scale=(1.3, 0.75, 0.42), rot=(0, 0, -a + rng.uniform(-0.08, 0.08)), subdiv=1, style="round", jit=0.012)
    if gap:
        for x, y, z, r in ((0.2, -0.75, 0.1, 0.6), (-0.35, -0.95, 0.09, 1.4), (0.5, -1.2, 0.08, 0.2)):
            p.ico(0.3, (x, y, z), C["canvas_stain"], scale=(1.3, 0.75, 0.42), rot=(0.1, 0, r), subdiv=1, style="round", jit=0.015)
        p.rod((0.1, -0.2, 0.25), (0.25, -0.05, 1.15), 0.025, C["timber_pale"], segs=5)
        p.box((0.22, 0.04, 0.28), (0.06, -0.24, 0.18), C["iron_light"], rot=(0.15, 0.2, 0.3), style="hard_smooth")
        p.ring(0.04, 0.07, 0.03, (0.26, -0.04, 1.2), C["timber_dark"], segs=8, rot=(math.pi / 2, 0, 0.3))
    else:
        p.ico(0.3, (1.6, -0.6, 0.1), C["canvas_dark"], scale=(1.3, 0.75, 0.42), rot=(0, 0, 0.9), subdiv=1, style="round", jit=0.012)


@K.kind("wheelbarrow", tags=["tool"], variants="ab", polish_opts={"detail": 1},
        story="A crew barrow: a parked one with a set lump of concrete in the tray, or one tipped on its nose after a race.")
def wheelbarrow(p, v, rng):
    tipped = v == "b"
    def barrow(m):
        def at(x, y, z):
            return tuple(m[i][0] * x + m[i][1] * y + m[i][2] * z + m[i][3] for i in range(3))
        # Tray: four sloped boards and a floor.
        p.prism([(-0.45, -0.32), (0.55, -0.32), (0.55, 0.32), (-0.45, 0.32)], 0.06, at(0.05, 0, 0.45), C["iron_light"], rot=rot_of(m))
        for s in (-1, 1):
            p.box((1.1, 0.05, 0.32), at(0.05, s * 0.37, 0.6), C["iron"], rot=rot_of(m, (s * 0.35, 0, 0)), style="hard_smooth")
        p.box((0.05, 0.75, 0.32), at(0.63, 0, 0.6), C["iron"], rot=rot_of(m, (0, -0.5, 0)), style="hard_smooth")
        p.box((0.05, 0.75, 0.3), at(-0.48, 0, 0.6), C["iron"], rot=rot_of(m, (0, 0.3, 0)), style="hard_smooth")
        for s in (-1, 1):
            p.rod(at(0.75, s * 0.12, 0.3), at(-1.05, s * 0.3, 0.55), 0.03, C["timber"], segs=6)
            p.rod(at(-0.3, s * 0.25, 0.42), at(-0.35, s * 0.28, 0.02), 0.025, C["iron"], segs=5)
        p.cyl(0.25, 0.1, at(0.78, 0, 0.25), C["charcoal"], segs=14, rot=rot_of(m, (math.pi / 2, 0, 0)), style="round")
        p.cyl(0.08, 0.14, at(0.78, 0, 0.25), C["iron_light"], segs=8, rot=rot_of(m, (math.pi / 2, 0, 0)), style="round")
    if not tipped:
        barrow(((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0)))
        p.ico(0.3, (0.05, 0, 0.62), C["concrete"], scale=(1.4, 0.9, 0.5), subdiv=1, style="hard_smooth", jit=0.03)
        p.rod((0.2, 0.05, 0.75), (0.5, 0.25, 1.15), 0.02, C["timber_pale"], segs=5)  # trowel stuck in the lump
        p.box((0.06, 0.12, 0.18), (0.18, 0.04, 0.72), C["iron_light"], rot=(0.3, 0.6, 0), style="fine")
    else:
        a = 0.9
        c, s = math.cos(a), math.sin(a)
        barrow(((c, 0, s, -0.2), (0, 1, 0, 0), (-s, 0, c, 0.25)))
        p.ico(0.2, (0.9, 0.3, 0.1), C["concrete_light"], scale=(1.3, 1.0, 0.4), subdiv=1, style="hard_smooth", jit=0.02)
        p.ico(0.16, (1.15, -0.25, 0.08), C["concrete_light"], scale=(1.3, 1.0, 0.4), subdiv=1, style="hard_smooth", jit=0.02)


def rot_of(m, extra=(0, 0, 0)):
    """Euler of a 3x4 rotation-plus-offset (rotation about Y only, as wheelbarrow uses) composed with an extra Euler."""
    from mathutils import Euler, Matrix as M
    base = M(((m[0][0], m[0][1], m[0][2]), (m[1][0], m[1][1], m[1][2]), (m[2][0], m[2][1], m[2][2])))
    return (base @ Euler(extra).to_matrix()).to_euler()


@K.kind("culvert_pipe", tags=["build"], variants="ab", polish_opts={"detail": 1},
        story="Concrete culvert sections left where the truck dropped them; b has one stood on end with a tarp nest inside.")
def culvert_pipe(p, v, rng):
    stood = v == "b"
    lay = (0, math.pi / 2, 0)
    def pipe(loc, rot, n=16):
        p.ring(0.48, 0.62, 1.4, loc, tint(C["concrete"], rng, 0.05), segs=n, rot=rot)
        p.ring(0.6, 0.66, 0.12, loc, C["concrete_stain"], segs=n, rot=rot)
    pipe((0, 0, 0.62), lay)
    if stood:
        pipe((1.3, 1.0, 0.7), (0, 0, 0))
        p.ico(0.42, (1.3, 1.0, 1.25), C["canvas_dark"], scale=(1.0, 1.0, 0.35), subdiv=1, style="round", jit=0.04)
        p.box((0.6, 0.04, 0.3), (0.1, -0.63, 0.75), C["timber_pale"], rot=(0.08, 0, 0), style="fine")  # stencil board tacked on
    else:
        pipe((0.15, 1.3, 0.62), (0, math.pi / 2, 0.15))
        for x in (-0.5, 0.6):
            p.box((0.18, 0.5, 0.18), (x, -0.62, 0.09), C["timber_dark"])  # chocks
            p.box((0.18, 0.5, 0.18), (x + 0.1, 1.9, 0.09), C["timber_dark"])
    for k in range(3):
        p.ico(0.1 + 0.04 * k, (-1.0 + 0.3 * k, 0.6 - 0.2 * k, 0.05), C["concrete_light"], scale=(1.2, 1.0, 0.5), subdiv=1, style="hard_smooth")


@K.kind("survey_stakes", tags=["survey"], variants="ab", polish_opts={"detail": 1},
        story="Grade stakes with canvas flagging and a slack stringline; b is the line the crew swore was straight.")
def survey_stakes(p, v, rng):
    wonky = v == "b"
    pts = []
    for k in range(5):
        x = -1.6 + k * 0.8 + rng.uniform(-0.08, 0.08)
        y = (0.15 * math.sin(k * 1.7) if wonky else rng.uniform(-0.04, 0.04)) * (3 if wonky else 1)
        h = 0.45 + rng.uniform(0, 0.35)
        lean = rng.uniform(-0.12, 0.12) + (0.18 * (k % 2) if wonky else 0)
        top = (x + lean * 0.4, y + lean * 0.2, h)
        p.beam((x, y, 0.0), top, 0.05, tint(C["timber_pale"], rng))
        p.box((0.12, 0.02, 0.07), (top[0], top[1] - 0.03, h - 0.06), C["canvas_stain"] if k % 2 else C["bone"], rot=(0, 0.3, 0), style="fine")
        p.box((0.04, 0.01, 0.18), (top[0] + 0.06, top[1] - 0.03, h - 0.15), C["canvas"], rot=(0, 0.6, 0), style="fine")  # flagging tail
        p.box((0.055, 0.052, 0.04), (x + lean * 0.38, y + lean * 0.19, h - 0.02), C["verdigris"], style="fine")  # painted top
        pts.append((top[0], top[1], h - 0.12))
    for a, b in zip(pts, pts[1:]):
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        mid = (mid[0], mid[1], mid[2] - 0.12)
        p.rod(a, mid, 0.008, C["bone"], segs=4)
        p.rod(mid, b, 0.008, C["bone"], segs=4)
    # The hammer they used, and the offcuts.
    p.cyl(0.02, 0.4, (0.4, -0.45, 0.03), C["timber"], segs=6, rot=(0, math.pi / 2, 0.7))
    p.box((0.16, 0.06, 0.06), (0.26, -0.6, 0.04), C["iron"], rot=(0, 0, 0.7), style="hard_smooth")
    for k in range(3):
        p.box((0.25, 0.05, 0.05), (-0.8 + 0.25 * k, 0.55, 0.03), C["timber_pale"], rot=(0, 0, rng.uniform(0, 3)), style="fine")


@K.kind("crew_sign", tags=["sign"], variants="abc", polish_opts={"detail": 1},
        story="Hand-painted crew boards propped on rocks: an arrow to the dam, an arrow to lunch, and one arrow pointing straight up.")
def crew_sign(p, v, rng):
    lean = (0.22, 0, 0)
    # Board: a plank with a pointed end, painted panel and stencil bars.
    if v == "c":
        outline = [(-0.18, -0.6), (0.18, -0.6), (0.18, 0.35), (0.0, 0.6), (-0.18, 0.35)]  # points up
        board_loc, board_rot = (0, 0.05, 0.75), (math.pi / 2 - 0.22, 0, 0)
    else:
        sgn = 1 if v == "a" else -1
        outline = [(-0.6 * sgn, -0.2), (0.35 * sgn, -0.2), (0.6 * sgn, 0.0), (0.35 * sgn, 0.2), (-0.6 * sgn, 0.2)]
        board_loc, board_rot = (0, 0.05, 0.62), (math.pi / 2 - 0.22, 0, 0)
    p.prism(outline, 0.05, board_loc, C["timber_pale"], rot=board_rot)
    paint = C["verdigris"] if v != "b" else C["bone"]
    if v == "c":
        for k in range(3):
            p.box((0.2, 0.02, 0.05), (0, -0.02, 0.5 + 0.18 * k), paint, rot=lean, style="fine")
    else:
        for k in range(3):
            p.box((0.18 if k else 0.5, 0.02, 0.06), (-0.25 + 0.25 * k, -0.02, 0.64), paint, rot=lean, style="fine")
    # Prop stick behind and two rocks at the foot.
    p.rod((0, 0.35, 0.0), (0, 0.12, 0.7), 0.03, C["timber_dark"], segs=5)
    for x, s in ((-0.35, 0.22), (0.3, 0.18)):
        p.ico(s, (x, -0.12, s * 0.5), tint(C["sandstone"], rng, 0.1), scale=(1.2, 1.0, 0.75), subdiv=1, style="hard_smooth", jit=0.015)
    if v == "b":
        p.cyl(0.07, 0.11, (0.55, -0.3, 0.055), C["iron_light"], segs=8)  # lunch mug left on the rock
        p.ring(0.035, 0.05, 0.02, (0.63, -0.3, 0.06), C["iron_light"], segs=6, rot=(math.pi / 2, 0, 0))


@K.kind("tool_drop", tags=["tool"], variants="ab", polish_opts={"detail": 1},
        story="Tools where the shift dropped them at the whistle: shovel and pick crossed, gloves, a canvas bag.")
def tool_drop(p, v, rng):
    # Shovel: handle, D-grip and a blade.
    a = 0.35 if v == "a" else -0.6
    c, s = math.cos(a), math.sin(a)
    def r(x, y):
        return (x * c - y * s, x * s + y * c)
    h0, h1 = r(-0.7, 0.0), r(0.45, 0.0)
    p.rod((h0[0], h0[1], 0.04), (h1[0], h1[1], 0.05), 0.022, C["timber"], segs=6)
    g = r(-0.78, 0.0)
    p.ring(0.05, 0.075, 0.03, (g[0], g[1], 0.05), C["timber_dark"], segs=8, rot=(0, 0, a))
    b = r(0.62, 0.0)
    p.box((0.32, 0.26, 0.03), (b[0], b[1], 0.03), C["iron_light"], rot=(0, 0.05, a), style="hard_smooth")
    # Pick: haft across the shovel, a curved head.
    a2 = a + 1.2
    c2, s2 = math.cos(a2), math.sin(a2)
    p.rod((-0.5 * c2, -0.5 * s2, 0.08), (0.45 * c2, 0.45 * s2, 0.06), 0.026, C["timber_dark"], segs=6)
    hx, hy = 0.5 * c2, 0.5 * s2
    p.ring(0.32, 0.37, 0.05, (hx + 0.3 * -s2, hy + 0.3 * c2, 0.05), C["iron"], segs=10,
           rot=(0, 0, a2 - math.pi / 2), arc=(-0.6, 0.6))
    # Gloves (soft lumps) and the bag.
    for k in range(2):
        p.ico(0.08, (-0.3 + 0.18 * k, 0.45, 0.04), C["canvas_stain"], scale=(1.6, 0.9, 0.4), rot=(0, 0, 0.4 * k), subdiv=1, style="round")
    if v == "a":
        p.ico(0.22, (0.3, -0.55, 0.16), C["canvas"], scale=(1.1, 0.8, 0.75), subdiv=1, style="round", jit=0.02)
        p.ring(0.1, 0.13, 0.025, (0.3, -0.55, 0.36), C["canvas_dark"], segs=8, rot=(math.pi / 2, 0, 0.2), arc=(0, math.pi))
    else:
        p.cyl(0.11, 0.24, (0.4, -0.5, 0.11), C["verdigris"], segs=10, rot=(math.pi / 2, 0, 0.9), style="round")  # flask on its side
        p.cyl(0.05, 0.06, (0.52, -0.62, 0.11), C["iron"], segs=6, rot=(math.pi / 2, 0, 0.9))


@K.kind("survey_cairn", tags=["survey"], variants="ab", polish_opts={"detail": 1},
        story="A survey cairn of flat stones around a marker; somebody topped b with a spare boot.")
def survey_cairn(p, v, rng):
    z = 0.0
    n = 6 if v == "a" else 5
    for k in range(n):
        r = 0.42 - k * 0.055
        h = 0.14 + rng.uniform(-0.02, 0.03)
        p.ico(r, (rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), z + h * 0.5), tint(C["sandstone_pale"] if k % 2 else C["sandstone"], rng, 0.08),
              scale=(1.15, 1.0, h / r * 0.6), rot=(0, 0, rng.uniform(0, 3)), subdiv=1, style="hard_smooth", jit=0.012)
        z += h * 0.85
    p.beam((0.02, 0.0, z - 0.1), (0.04, 0.02, z + 0.55), 0.06, C["timber_pale"])
    p.box((0.07, 0.07, 0.08), (0.04, 0.02, z + 0.56), C["verdigris"], style="fine")
    if v == "b":
        # The boot: a toe, a shaft, and laces trailing.
        p.ico(0.09, (0.2, -0.05, z + 0.06), C["timber_dark"], scale=(1.6, 0.9, 0.6), subdiv=1, style="round")
        p.cyl(0.08, 0.2, (0.08, -0.05, z + 0.15), C["timber_dark"], segs=8, style="round")
        p.rod((0.12, -0.11, z + 0.2), (0.25, -0.2, z - 0.05), 0.008, C["bone"], segs=4)
    else:
        p.box((0.2, 0.02, 0.06), (0.15, 0.02, z + 0.45), C["canvas"], rot=(0, -0.3, 0), style="fine")  # flagging
    for k in range(3):
        a = rng.uniform(0, math.tau)
        p.ico(0.09, (0.6 * math.cos(a), 0.6 * math.sin(a), 0.03), C["sandstone_dark"], scale=(1.3, 1.0, 0.5), subdiv=1, style="hard_smooth")


@K.kind("staff_gauge", tags=["survey"], variants="ab", polish_opts={"detail": 1},
        story="A painted water gauge on a footing; the crew's flood mark is chalked a hand above the top.")
def staff_gauge(p, v, rng):
    lean = (0.0, 0.08 if v == "a" else -0.2, 0)
    p.cyl(0.3, 0.25, (0, 0, 0.125), C["concrete"], segs=10, style="hard_smooth")
    p.box((0.12, 0.12, 2.0), (0, 0, 1.1), C["timber_grey"], rot=lean)
    # Gauge board: bone face, charcoal ticks every 0.1 m, every fifth longer.
    p.box((0.2, 0.03, 1.6), (0.0, -0.08, 1.15), C["bone"], rot=lean, style="fine")
    ly = lean[1]
    for k in range(16):
        zz = 0.4 + k * 0.1
        dx = math.sin(ly) * (zz - 0.1)
        w = 0.14 if k % 5 == 0 else 0.07
        p.box((w, 0.01, 0.025), (dx - 0.05 + w / 2, -0.1, zz), C["charcoal"], rot=lean, style="flat")
    top = 2.1
    dx = math.sin(ly) * top
    p.box((0.22, 0.02, 0.04), (dx + 0.02, -0.1, top + 0.22), C["canvas"], rot=lean, style="fine")  # chalked flood mark above the board
    if v == "b":
        p.ico(0.2, (0.35, 0.2, 0.08), C["canvas_dark"], scale=(1.4, 1.0, 0.4), subdiv=1, style="round")  # drift rag at the foot
        p.rod((-0.4, 0.3, 0.02), (0.1, 0.6, 0.04), 0.03, C["timber_grey"], segs=5)  # driftwood
    else:
        p.ico(0.14, (-0.3, -0.2, 0.06), C["sandstone"], scale=(1.3, 1.0, 0.5), subdiv=1, style="hard_smooth")


@K.kind("prickly_pear", tags=["plant"], variants="ab", polish_opts={"detail": 1},
        story="Prickly pear grown through the old works, pads stacked like the crew's lunch plates.")
def prickly_pear(p, v, rng):
    def pad(loc, r, rot, col):
        p.ico(r, loc, col, scale=(1.0, 0.32, 1.25), rot=rot, subdiv=1, style="round", jit=0.01)
    stems = 3 if v == "a" else 5
    for s in range(stems):
        a = math.tau * s / stems + rng.uniform(-0.3, 0.3)
        x, y, z = 0.25 * math.cos(a) * (s > 0), 0.25 * math.sin(a) * (s > 0), 0.0
        yaw = a + rng.uniform(-0.4, 0.4)
        r = 0.32 if v == "a" else 0.26
        for k in range(3 if v == "a" else 2):
            tilt = rng.uniform(-0.45, 0.45)
            z += r * 1.1
            pad((x, y, z), r, (0, tilt, yaw), tint(C["leaf"] if (s + k) % 2 else C["leaf_dark"], rng, 0.08))
            if rng.random() < 0.4:
                p.uv(0.045, (x + r * 0.5 * math.cos(yaw), y + r * 0.5 * math.sin(yaw), z + r * 1.15), C["canvas_stain"], u=6, v=4)  # fruit
            x += r * 0.6 * math.sin(tilt) * math.cos(yaw)
            y += r * 0.6 * math.sin(tilt) * math.sin(yaw)
            z += r * 0.1
            r *= 0.85
    p.ico(0.35, (0.0, 0.0, 0.05), C["soil"], scale=(1.5, 1.5, 0.25), subdiv=1, style="round")


@K.kind("brittlebush", tags=["plant"], variants="ab", polish_opts={"detail": 1},
        story="Brittlebush mounds with dry seed heads, the only crew that stayed on.")
def brittlebush(p, v, rng):
    n = 6 if v == "a" else 4
    for k in range(n):
        a = math.tau * k / n + rng.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else rng.uniform(0.3, 0.55)
        r = rng.uniform(0.3, 0.42) if v == "a" else rng.uniform(0.25, 0.34)
        p.ico(r, (d * math.cos(a), d * math.sin(a), r * 0.7), tint(C["leaf"] if k % 2 else mix(C["leaf"], C["dry_grass"], 0.4), rng, 0.08),
              scale=(1.0, 1.0, 0.75), subdiv=1, style="round", jit=0.03)
    for k in range(7 if v == "a" else 5):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.1, 0.5)
        base = (d * math.cos(a), d * math.sin(a), 0.5)
        tip = (base[0] * 1.5, base[1] * 1.5, 0.95 + rng.uniform(0, 0.25))
        p.rod(base, tip, 0.012, C["dry_grass"], segs=4)
        p.uv(0.04, tip, C["bone"], u=5, v=4)
    if v == "b":
        for k in range(3):
            p.rod((0.7 + 0.1 * k, -0.3, 0.02), (1.0 + 0.15 * k, -0.1 - 0.1 * k, 0.03), 0.02, C["timber_grey"], segs=4)  # dead twigs


if __name__ == "__main__":
    K.main()
