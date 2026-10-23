"""Pit park dressing kit (Dressing lane, design-v3/park/DRESSING-KITS.md).

The open pit was a copper outfit run in shifts: haul crews, drillers, powder men and the core shed.
The last shift walked off at the noon whistle and left everything where it stood: a tipped ore car,
the change shack with hats still on the pegs, a drill rig with its mast laid down, and one old
prospector's camp on the rim that was there before any of them. No lamps (the Dig lamp veto).

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/pit.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from mathutils import Matrix
from kit import C, mix, tint

K = kit.Kit("pit")

# The pit's rock bands (3-park_pit.md section 1): ochre and rust oxides, grey-green host rock, and
# copper-carbonate streaks kept a dull sea-green, well clear of MINT.
P = {
    "ochre": "b98a4a", "ochre_dark": "8f6a3c", "oxide": "9a6448", "host": "7f8670",
    "host_dark": "5f6656", "streak": "4f8a7c", "tin": "a3a59c", "tin_dark": "7c7f78",
    "hat": "6f8f9a", "denim": "4d5f72", "char": "2e2a26", "ash": "8a857a",
}


def rock(p, rng, at, r, color, squash=0.6, style="flat"):
    p.ico(r, at, tint(color, rng, 0.06), subdiv=2, scale=(1.0 + rng.uniform(-0.15, 0.2), 1.0 + rng.uniform(-0.15, 0.2), squash),
          rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.tau)), style=style, jit=r * 0.06)


def wheel(p, at, r, color, axis_rot=(math.pi / 2, 0, 0)):
    p.cyl(r, 0.14, at, color, segs=14, rot=axis_rot, style="hard_smooth")
    p.cyl(r * 0.35, 0.2, at, C["iron_light"], segs=8, rot=axis_rot, style="round")


@K.kind("ore_car", hero=True, tags=["machine"], variants="ab",
        story="A side-dump ore car that jumped its stub of track on the last haul and spilled across the bench.")
def ore_car(p, v, rng):
    tipped = v == "a"
    # A short stub of track: five sleepers' worth, broken off, never a long rail.
    for i in range(5):
        x = -2.2 + i * 1.05
        p.box((0.3, 2.0, 0.16), (x, 0, 0.08), tint(C["timber_dark"], rng, 0.06), rot=(0, 0, rng.uniform(-0.08, 0.08)), jit=0.01)
    for y in (-0.6, 0.6):
        p.box((4.2, 0.12, 0.14), (-0.2, y, 0.23), C["rust"], style="hard_smooth")
    # The car, built upright on the rails; the tipped variant then rolls it off onto its side.
    car = []
    bed = [(-0.95, 0.75), (0.95, 0.75), (0.45, -0.55), (-0.45, -0.55)]
    car += p.prism(bed, 2.6, (0, 0, 1.55), mix(C["iron"], C["rust"], 0.35), rot=(math.pi / 2, 0, math.pi / 2), style="hard_smooth")
    car += p.prism([(x * 0.84, y * 0.84 + 0.08) for x, y in bed], 2.64, (0, 0, 1.6), C["charcoal"], rot=(math.pi / 2, 0, math.pi / 2), style="hard")
    for x in (-1.32, 1.32):
        car += p.box((0.16, 2.0, 0.22), (x, 0, 2.27), C["iron_light"], style="hard_smooth")
    car += p.box((2.8, 1.1, 0.24), (0, 0, 0.8), C["iron"], style="hard_smooth")
    car += p.box((0.4, 0.22, 0.22), (-1.55, 0, 0.8), C["iron"])
    car += p.box((0.5, 0.04, 0.32), (0, -0.88, 1.7), C["bone"], style="fine")  # the car number plate, plain
    for x in (-0.9, 0.9):
        for y in (-0.62, 0.62):
            if not tipped and x > 0 and y > 0:
                continue  # the wheel that came off
            car += p.cyl(0.36, 0.13, (x, y, 0.58), mix(C["iron"], C["charcoal"], 0.4), segs=16, rot=(math.pi / 2, 0, 0), style="hard_smooth")
            car += p.cyl(0.13, 0.2, (x, y, 0.58), C["iron_light"], segs=8, rot=(math.pi / 2, 0, 0), style="round")
    if tipped:
        # Roll the car 80 degrees off the -Y rail about its lower bed edge, and slew it a little.
        m = Matrix.Translation((0.25, -1.3, 0.0)) @ Matrix.Rotation(0.2, 4, "Z") @ Matrix.Rotation(-math.radians(80), 4, "X") \
            @ Matrix.Translation((0, 0.75, -0.2))
        # The kit primitives return live BMesh faces, so the built car can be rolled in place before polish.
        verts = {vv for f in car for vv in f.verts}
        for vert in verts:
            vert.co = m @ vert.co
        lift = -min(vert.co.z for vert in verts) - 0.02  # sit the rolled car on the ground, not under it
        for vert in verts:
            vert.co.z += lift
        p.box((0.5, 0.7, 0.5), (-1.3, 0.1, 0.25), C["timber_dark"], rot=(0.0, 0.1, 0.4))  # a chock knocked aside
    else:
        p.cyl(0.36, 0.13, (1.6, 1.4, 0.07), mix(C["iron"], C["charcoal"], 0.4), segs=16, rot=(0.04, 0, 0.6), style="hard_smooth")
        p.cyl(0.13, 0.2, (1.6, 1.4, 0.1), C["iron_light"], segs=8, rot=(0.04, 0, 0.6), style="round")
        p.box((0.5, 0.8, 0.5), (0.95, 0.62, 0.45), C["timber_dark"], rot=(0.0, 0.1, 0.2))  # a block chocked under the axle
        p.ico(0.95, (0.0, 0.0, 2.35), C["canvas_dark"], scale=(1.4, 0.8, 0.22), rot=(0.05, 0.1, 0.02), style="round")  # tarp over the load
        for k in range(6):
            rock(p, rng, (rng.uniform(-1.0, 1.0), rng.uniform(-0.5, 0.5), 2.25), rng.uniform(0.18, 0.3),
                 rng.choice([P["ochre"], P["oxide"], P["host"]]))
        p.chain((-1.75, 0, 0.8), (-2.9, 0.4, 0.06), C["cable"], link=0.14, radius=0.024, sag=0.25, style="flat")
    # The spill: a fan of ore lumps down the bench, a few with sea-green streaks.
    n = 26 if tipped else 12
    cx, cy = (0.6, -2.4) if tipped else (1.4, -1.6)
    for k in range(n):
        a = rng.uniform(-1.1, 1.1) - math.pi / 2
        d = rng.uniform(0.2, 1.0) ** 0.7 * (3.0 if tipped else 1.4)
        x, y = cx + d * math.cos(a) * 1.3, cy + d * math.sin(a)
        r = rng.uniform(0.18, 0.42) * (1.0 - 0.35 * d / 3.0)
        col = rng.choice([P["ochre"], P["ochre"], P["oxide"], P["host"], P["host_dark"]])
        rock(p, rng, (x, y, r * 0.45), r, col)
        if k % 6 == 0:
            p.ico(r * 0.45, (x + r * 0.3, y, r * 0.75), P["streak"], scale=(1.3, 0.5, 0.35), subdiv=2, style="flat")
    # A shovel the haul crew left stuck in the spill.
    p.rod((cx + 1.2, cy - 1.4, 0.2), (cx + 1.45, cy - 1.0, 1.35), 0.04, C["timber"], segs=6)
    p.box((0.3, 0.06, 0.38), (cx + 1.15, cy - 1.46, 0.12), C["iron"], rot=(0.4, 0.2, 0.9), style="hard_smooth")


@K.kind("change_house", hero=True, tags=["tall"], variants="ab",
        story="The shift change shack: tin walls, a bench out front, hard hats still on the pegs for a shift that never came.")
def change_house(p, v, rng):
    blown = v == "b"
    w, d, h = 4.2, 3.0, 2.5
    # Skids and floor.
    for y in (-1.2, 0, 1.2):
        p.box((w + 0.6, 0.24, 0.26), (0, y, 0.13), C["timber_dark"])
    p.box((w, d, 0.12), (0, 0, 0.32), tint(C["timber_grey"], rng, 0.04))
    # Corrugated tin walls as vertical ribs (each rib a thin box, alternating shade).
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
    # Door, hanging open on one hinge.
    p.box((0.9, 0.06, 2.1), (0.95, -d / 2 - 0.4, 1.45), C["timber_pale"], rot=(0, 0, 1.0 if not blown else 1.35))
    # Frame posts and roof purlins.
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
        # The sheets the wind took: two lie folded beside the shack, one on the roof edge.
        p.box((1.9, 1.0, 0.06), (w / 2 + 1.5, 1.1, 0.25), P["tin_dark"], rot=(0.15, 0.25, 0.5), style="fine")
        p.box((1.7, 1.0, 0.06), (w / 2 + 1.0, -1.6, 0.12), P["tin"], rot=(0, 0.05, -0.3), style="fine")
        p.box((1.5, 0.9, 0.06), (w / 2 + 0.2, 0.3, roof_z + 0.45), P["tin"], rot=(0.5, -0.7, 0.2), style="fine")
        for k in range(6):
            p.beam((0.2 + k * 0.38, -d / 2, roof_z), (0.2 + k * 0.38, d / 2, roof_z), 0.1, C["timber_dark"])
    # The pegboard: hats on pegs beside the door, one jacket.
    for k in range(5):
        x = -1.7 + k * 0.42
        p.cyl(0.03, 0.18, (x, -d / 2 - 0.1, 2.05), C["timber_dark"], segs=6, rot=(math.pi / 2, 0, 0))
        if k != 2:
            col = P["hat"] if k % 2 else C["bone"]
            p.uv(0.17, (x, -d / 2 - 0.2, 2.08), col, scale=(1.0, 1.0, 0.7), u=10, v=6, style="round")
            p.cyl(0.21, 0.03, (x, -d / 2 - 0.2, 1.98), col, segs=12, style="round")
    p.ico(0.32, (-0.85, -d / 2 - 0.16, 1.55), P["denim"], scale=(0.9, 0.35, 1.5), style="round")
    # The bench, a lunch pail and a thermos on it.
    p.box((2.6, 0.45, 0.08), (-0.6, -d / 2 - 0.85, 0.55), tint(C["timber"], rng))
    for x in (-1.7, 0.5):
        p.box((0.1, 0.4, 0.5), (x, -d / 2 - 0.85, 0.27), C["timber_dark"])
    p.cyl(0.16, 0.22, (-1.2, -d / 2 - 0.85, 0.7), P["tin_dark"], segs=12, style="round")
    p.torus(0.12, 0.015, (-1.2, -d / 2 - 0.85, 0.86), C["iron"], rot=(math.pi / 2, 0, 0), major=10, minor=4)
    p.cyl(0.07, 0.34, (-0.3, -d / 2 - 0.85, 0.76), C["verdigris"], segs=10, style="round")
    # A canvas water bag hung on the corner, and a pair of boots on the step.
    p.ico(0.25, (w / 2 + 0.18, -d / 2 + 0.3, 1.7), C["canvas"], scale=(0.8, 0.7, 1.2), style="round")
    for k in range(2):
        p.ico(0.13, (0.55 + k * 0.22, -d / 2 - 0.45, 0.42), C["soil"], scale=(1.0, 2.0, 1.1), style="round")


@K.kind("drill_rig", hero=True, tags=["machine"], variants="ab",
        story="The blast-hole drill, mast laid down for the move that never happened; crawler tracks caked in bench dust.")
def drill_rig(p, v, rng):
    snapped = v == "b"
    # Crawler tracks: two long rounded slabs with road wheels and track plates.
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
    # Deck, engine house and cab.
    p.box((4.0, 3.2, 0.3), (0, 0, 1.0), mix(C["iron"], C["rust"], 0.25), style="hard_smooth")
    p.box((1.8, 2.4, 1.3), (-1.0, 0, 1.8), tint(P["tin_dark"], rng, 0.04), style="hard_smooth")
    for i in range(6):
        p.box((0.06, 1.6, 0.9), (-1.92, -0.8 + i * 0.32, 1.8), C["charcoal"], style="fine")  # radiator louvres
    p.cyl(0.12, 1.1, (-0.4, 0.8, 2.9), C["charcoal"], segs=10, style="round")  # exhaust stack, cold
    p.box((1.3, 1.4, 1.6), (1.05, -0.75, 1.95), P["tin"], style="hard_smooth")
    p.box((1.32, 1.0, 0.7), (1.05, -0.85, 2.25), P["host_dark"], style="hard")  # window band, dark glass
    p.box((1.5, 1.6, 0.12), (1.05, -0.75, 2.8), P["tin_dark"], style="hard_smooth")
    # The mast: a lattice laid along the deck, resting on a cradle; snapped variant has its top on the ground.
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
    p.box((0.5, 1.0, 0.7), (2.0, 0, 1.5), C["timber_dark"])  # cradle block
    if snapped:
        lattice((-1.8, 0.2, 1.8), (2.2, 0.2, 1.95), 0.55)
        lattice((2.6, 0.5, 1.6), (5.6, 1.4, 0.32), 0.55)
        p.ico(0.5, (2.4, 0.35, 1.75), P["oxide"], scale=(1.0, 1.0, 0.6), style="round")  # bent knuckle, rust bloom
    else:
        lattice((-1.8, 0.2, 1.8), (-1.8 + length, 0.2, 2.1), 0.55)
        p.box((0.9, 1.1, 2.1), (-1.8 + length - 0.3, 0.2, 1.05), C["timber_dark"])  # cribbing under the mast head
    # Drill steel and bit laid beside the tracks, and a coiled hose on the deck.
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
        # A few cores rolled off onto the ground and a chalk-marked board leaning on the horse.
        for k in range(4):
            p.cyl(0.05, rng.uniform(0.3, 0.5), (rng.uniform(-0.9, 0.9), 0.7 + rng.uniform(0, 0.3), 0.05), rng.choice([P["host"], P["ochre"]]),
                  segs=8, rot=(0, math.pi / 2, rng.uniform(-0.6, 0.6)), style="round")
        p.box((0.7, 0.04, 0.5), (1.3, 0.1, 0.3), C["charcoal"], rot=(0.2, 0, 0.3), style="fine")


@K.kind("ore_heap", tags=["soft"], variants="abc", polish_opts={"detail": 1},
        story="Grab samples heaped by the shovel crew: ochre and rust oxide, grey-green host rock, a streak of copper green.")
def ore_heap(p, v, rng):
    big = {"a": 1.0, "b": 0.7, "c": 1.25}[v]
    R, H = 1.15 * big, 0.5 * big
    p.ico(R, (0, 0, 0.0), tint(P["ochre_dark"], rng, 0.05), scale=(1.3, 1.0, H / R), subdiv=2, style="flat", jit=0.06)  # faceted spoil, not a blob

    def surface(x, y):
        return H * math.sqrt(max(0.0, 1.0 - (x / (1.3 * R)) ** 2 - (y / R) ** 2))
    n = {"a": 16, "b": 10, "c": 20}[v]
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.1, 1.05) * R
        x, y = math.cos(a) * d * 1.3, math.sin(a) * d
        r = rng.uniform(0.2, 0.36) * big
        col = rng.choice([P["ochre"], P["oxide"], P["host"], P["host_dark"], P["oxide"]])
        rock(p, rng, (x, y, surface(x, y) + r * 0.25), r, col)
    for k in range(2 if v != "b" else 1):
        a = rng.uniform(0, math.tau)
        x, y = math.cos(a) * 0.5 * big, math.sin(a) * 0.4 * big
        p.ico(0.24 * big, (x, y, surface(x, y) + 0.06), P["streak"], scale=(1.4, 0.6, 0.4), subdiv=2, style="flat")
    if v == "c":
        # A sample tag on a stake.
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
    # The tail of the hose snaking off to the hammer.
    pts = [(0.5, 0.1, 0.06), (0.95, 0.35, 0.06), (1.25, 0.15, 0.06), (1.55, 0.3, 0.06)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.06, C["cable"], segs=6, style="flat")
    hx, hy = 1.95, 0.3
    ang = 0.1 if v == "a" else 0.6
    p.cyl(0.16, 0.7, (hx, hy, 0.17), C["iron"], segs=10, rot=(0, math.pi / 2, ang), style="hard_smooth")
    p.box((0.12, 0.55, 0.12), (hx - 0.42, hy, 0.17), C["charcoal"], rot=(0, 0, ang))  # T handle
    p.cyl(0.05, 0.5, (hx + 0.6 * math.cos(ang), hy + 0.6 * math.sin(ang), 0.12), C["iron_light"], segs=6, rot=(0, math.pi / 2, ang))
    if v == "b":
        p.uv(0.17, (-0.1, -0.85, 0.12), P["hat"], scale=(1.0, 1.0, 0.65), u=10, v=6, style="round")  # a hard hat, brim up
        p.cyl(0.21, 0.03, (-0.1, -0.85, 0.02), P["hat"], segs=12, style="round")


@K.kind("blast_mat", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="A woven blasting mat dragged off the last shot and left slumped over the rubble it was meant to hold down.")
def blast_mat(p, v, rng):
    for k in range(5):
        rock(p, rng, (rng.uniform(-1.0, 1.0), rng.uniform(-0.6, 0.6), 0.15), rng.uniform(0.25, 0.4), P["host_dark"])
    # The mat: a grid of woven strands draped over the lumps.
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
    # Pick.
    a = {"a": 0.2, "b": 1.2, "c": -0.4}[v]
    ca, sa = math.cos(a), math.sin(a)
    p.rod((-0.6 * ca, -0.6 * sa, 0.05), (0.4 * ca, 0.4 * sa, 0.05), 0.035, C["timber"], segs=6)
    p.rod((0.45 * ca - 0.35 * sa, 0.45 * sa + 0.35 * ca, 0.06), (0.45 * ca + 0.35 * sa, 0.45 * sa - 0.35 * ca, 0.06), 0.045, C["iron"], segs=6, r2=0.012)
    # Shovel.
    b = a + 1.9
    cb, sb = math.cos(b), math.sin(b)
    ox, oy = 0.2, 0.55
    p.rod((ox - 0.55 * cb, oy - 0.55 * sb, 0.05), (ox + 0.5 * cb, oy + 0.5 * sb, 0.05), 0.03, C["timber_pale"], segs=6)
    p.box((0.32, 0.26, 0.05), (ox + 0.68 * cb, oy + 0.68 * sb, 0.04), C["iron_light"], rot=(0, 0, b), style="hard_smooth")
    p.box((0.08, 0.2, 0.05), (ox - 0.6 * cb, oy - 0.6 * sb, 0.05), C["timber_dark"], rot=(0, 0, b))
    if v != "b":
        # Sledge.
        p.rod((-0.5, -0.5, 0.05), (0.15, -0.75, 0.05), 0.035, C["timber_dark"], segs=6)
        p.box((0.32, 0.14, 0.14), (0.27, -0.8, 0.08), C["iron"], rot=(0, 0, -0.36), style="hard_smooth")
    # Lunch pail with its lid off and a thermos lying down.
    p.cyl(0.16, 0.22, (-0.45, 0.45, 0.11), P["tin_dark"], segs=12, style="round")
    p.torus(0.12, 0.015, (-0.45, 0.45, 0.24), C["iron"], rot=(math.pi / 2, 0, 0.4), major=10, minor=4)
    p.cyl(0.17, 0.03, (-0.15, 0.25, 0.02), P["tin"], segs=12, style="round")
    if v == "c":
        p.cyl(0.07, 0.34, (-0.8, 0.0, 0.07), C["verdigris"], segs=10, rot=(0, math.pi / 2, 0.8), style="round")
        p.ico(0.25, (0.6, 0.2, 0.12), P["denim"], scale=(1.4, 0.9, 0.35), style="round")  # a folded jacket
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
        rock(p, rng, (math.cos(k * 2.1) * 0.3, math.sin(k * 2.1) * 0.3, 0.1), 0.2, P["host"], squash=0.7)
    board_z = 1.75
    bx = math.sin(lean) * board_z
    p.box((1.1, 0.06, 0.62), (bx, -0.1, board_z), tint(C["timber_pale"], rng, 0.04), rot=(0, lean, 0.03 if v == "a" else -0.12), style="hard_smooth")
    for k in range(3 if v == "a" else 2):
        p.box((0.32, 0.015, 0.4), (bx - 0.32 + k * 0.34, -0.14, board_z - 0.02), rng.choice([C["bone"], C["canvas"], C["canvas_stain"]]),
              rot=(0, lean, rng.uniform(-0.12, 0.12)), style="flat")
    if v == "b":
        p.box((0.33, 0.015, 0.42), (0.6, -0.4, 0.02), C["canvas_stain"], rot=(math.pi / 2, 0, 0.6), style="flat")  # a notice blown down


@K.kind("saguaro_bones", tags=["plant"], variants="abc", polish_opts={"detail": 1},
        story="A saguaro that died before the pit opened: the flesh long gone, its woody ribs bleached and fallen. "
              "Never upright and never tall, so it cannot read as the park's living saguaro anchors.")
def saguaro_bones(p, v, rng):
    rib = mix(C["timber_pale"], C["bone"], 0.4)
    rib_dark = mix(C["timber_grey"], C["bone"], 0.2)
    # The fallen trunk: a loose bundle of ribs lying along +X, sagging apart toward the top end.
    length = {"a": 4.2, "b": 2.6, "c": 3.4}[v]
    for k in range(8):
        a = math.tau * k / 8 + rng.uniform(-0.1, 0.1)
        spread = 0.24 + rng.uniform(0, 0.08)
        y0, z0 = math.cos(a) * 0.2, 0.22 + math.sin(a) * 0.18
        y1, z1 = math.cos(a) * spread * 1.6, max(0.05, 0.2 + math.sin(a) * spread)
        if rng.random() < 0.25:
            continue  # a rib that has already gone to the wind
        p.rod((0.0, y0, z0), (length * rng.uniform(0.8, 1.0), y1, z1), 0.05, rib if k % 2 else rib_dark, segs=5, style="flat", jit=0.015)
    # The boot: the woody socket where the trunk snapped, and the root flare it left standing.
    stump_h = {"a": 0.6, "b": 0.95, "c": 0.8}[v]
    for k in range(9):
        a = math.tau * k / 9
        lean = rng.uniform(0.0, 0.12)
        p.rod((-0.25 + 0.26 * math.cos(a), 0.26 * math.sin(a), 0.0),
              (-0.25 + (0.24 + lean) * math.cos(a), (0.24 + lean) * math.sin(a), stump_h * rng.uniform(0.7, 1.0)),
              0.04, rib, segs=5, style="flat")
    p.ico(0.45, (-0.25, 0, 0.0), C["soil"], scale=(1.3, 1.2, 0.25), subdiv=2, style="flat", jit=0.04)
    if v != "b":
        # A collapsed arm lying beside the trunk, and the woody cross-hatch where the skin dried.
        p.rod((1.2, 0.5, 0.12), (2.0, 1.3, 0.1), 0.03, rib_dark, segs=5, style="flat")
        p.rod((1.25, 0.6, 0.14), (1.9, 1.45, 0.12), 0.03, rib, segs=5, style="flat")
    if v == "c":
        # A cactus wren's old nest boot, the hollow woody cup that outlasts the plant.
        p.uv(0.16, (length * 0.6, -0.3, 0.14), C["timber_dark"], scale=(1.0, 0.8, 0.7), u=8, v=5, style="round")
    # Young prickly pear coming up in the shade of the old trunk.
    for k in range(2 if v == "a" else 1):
        x = 0.8 + k * 1.4
        p.ico(0.2, (x, -0.55, 0.22), tint(C["leaf"], rng, 0.05), scale=(1.0, 0.22, 1.2), rot=(0, 0, 0.4 + k), subdiv=2, style="flat")


@K.kind("prickly_pear", tags=["plant"], variants="ab", polish_opts={"detail": 1},
        story="Prickly pear grown up through the spoil; nobody cleared it, so the berm goes around it too.")
def prickly_pear(p, v, rng):
    pads = 7 if v == "a" else 5
    stack = [((0, 0, 0.32), 0.0)]
    for k in range(pads):
        base, tilt = rng.choice(stack[: 2 + k // 2])  # branch from the low pads, so it spreads not towers
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
            p.ico(0.06, (0.35 * math.cos(a), 0.35 * math.sin(a), 0.9 + rng.uniform(0, 0.2)), "8a6a7a", style="round")  # dusky fruit


@K.kind("fire_ring", tags=["soft"], variants="ab", polish_opts={"detail": 1},
        story="The old prospector's cold fire ring on the rim: stones, charred ends, a pan and a coffee pot. He was here first.")
def fire_ring(p, v, rng):
    for k in range(10):
        a = math.tau * k / 10 + rng.uniform(-0.1, 0.1)
        rock(p, rng, (0.75 * math.cos(a), 0.75 * math.sin(a), 0.12), rng.uniform(0.17, 0.24), rng.choice([P["host"], P["ochre_dark"], C["sandstone_dark"]]), squash=0.7)
    p.ico(0.6, (0, 0, 0.0), P["ash"], scale=(1.0, 1.0, 0.12), style="round")
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        p.rod((0.1 * math.cos(a), 0.1 * math.sin(a), 0.22), (0.55 * math.cos(a), 0.55 * math.sin(a), 0.07), 0.06, P["char"], segs=6)
    # Coffee pot beside the ring and a gold pan propped on a stone.
    p.cyl(0.12, 0.24, (1.15, 0.3, 0.12), C["iron_light"], segs=10, r2=0.09, style="round")
    p.rod((1.23, 0.3, 0.2), (1.32, 0.3, 0.28), 0.02, C["iron_light"], segs=4)
    p.cyl(0.32, 0.06, (-1.1, -0.4, 0.2), C["iron"], segs=16, r2=0.24, rot=(0.6, 0, 0.4), style="round")
    if v == "b":
        # Bedroll and a battered hat: the prospector's, the only one with a brim this wide.
        p.cyl(0.24, 1.3, (0.4, 1.35, 0.24), C["canvas_dark"], segs=12, rot=(0, math.pi / 2, 0.15), style="round")
        p.torus(0.25, 0.03, (0.0, 1.35, 0.24), C["timber_dark"], rot=(0, math.pi / 2, 0.15), major=10, minor=4)
        p.uv(0.2, (-0.9, 0.9, 0.12), C["timber_dark"], scale=(1.0, 1.0, 0.6), u=10, v=6, style="round")
        p.cyl(0.36, 0.03, (-0.9, 0.9, 0.03), C["timber_dark"], segs=14, style="round")
    else:
        p.ico(0.3, (0.1, 1.2, 0.15), C["canvas"], scale=(1.1, 0.8, 0.5), style="round")  # a sack of beans


@K.kind("haul_tyre", tags=["machine"], variants="ab", polish_opts={"detail": 1},
        story="A haul truck tyre twice a person's height, rolled off the shop pad and left where it fell.")
def haul_tyre(p, v, rng):
    R, r = 1.55, 0.6
    if v == "a":
        # Lying flat, half sunk in dust, a prickly little garden grown in the hub.
        p.torus(R - r * 0.2, r, (0, 0, 0.35), P["char"], scale=(1.0, 1.0, 0.75), major=24, minor=10, style="flat")
        for k in range(20):
            a = math.tau * k / 20
            p.box((0.5, 0.18, 0.2), ((R + r * 0.6) * math.cos(a), (R + r * 0.6) * math.sin(a), 0.4), C["charcoal"], rot=(0, 0, a), style="fine")
        p.ico(1.0, (0, 0, 0.1), C["soil"], scale=(1.0, 1.0, 0.3), style="round")
        for k in range(3):
            a = math.tau * k / 3
            p.ico(0.22, (0.4 * math.cos(a), 0.4 * math.sin(a), 0.42), tint(C["leaf"], rng, 0.05), scale=(1.0, 0.35, 1.2), rot=(0, 0, a), style="round")
    else:
        # Two stacked, the top one slid off-centre.
        for k, (ox, oy) in enumerate(((0, 0), (0.35, 0.2))):
            z = 0.42 + k * 0.82
            p.torus(R - r * 0.2, r * 0.9, (ox, oy, z), P["char"], scale=(1.0, 1.0, 0.7), rot=(0.05 * k, 0, 0), major=24, minor=10, style="flat")
            for j in range(16):
                a = math.tau * j / 16
                p.box((0.45, 0.16, 0.18), (ox + (R + r * 0.5) * math.cos(a), oy + (R + r * 0.5) * math.sin(a), z), C["charcoal"], rot=(0, 0, a), style="fine")
        p.ico(0.6, (0.3, 0.15, 1.0), C["soil"], scale=(1.0, 1.0, 0.3), style="round")


if __name__ == "__main__":
    K.main()
