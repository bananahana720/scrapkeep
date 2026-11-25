"""The Slag Bowl's Fleet yard: the stands, furnaces, ladles, ledger board and crew props behind the rim.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/arena_bowl_yard.py
Use -- --out /tmp/arena_bowl_yard.glb for a byte-identity rebuild.

Godot metres, no collision or animation. Everything stands outside the rim wall (r 60 to 62, top y 16) on a yard
deck at y 15, so nothing reaches the riding lane or a telegraph. Static parts are built at their bowl position;
CrewFan and CrewPennant are single plush crew built at the origin, facing +X, for src/presentation/arena_bowl_dress.gd
to seat by MultiMesh. LadleMelt and FurnaceGlow carry the slag_glow slot, which the dress gives an emissive material
that steps with Brindle's phase. STANDS mirrors arena_bowl_dress.gd STANDS: the dress seats the crew on these tiers.

Four stands, one to a quarter, each its own build (wave 46 E3-02, concept sheet 03-arena-stands-camp): the north
foundry bleachers under a corrugated oxide awning with brass megaphones, the east crane-watch box on its gantry with a
split-flap scoreboard frame, the south scrap-yard scaffolding with its container stack and crew pennants, and the west
ladle-rail gallery arched over the 165 degree ladle car. Bearings are Godot's: 0 is +X (east), 90 is +Z (south), 270 is
-Z (north). All four are one FleetStands part (three slots), so the yard's draw count does not grow.
"""
import math
from pathlib import Path
import sys

import bmesh
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "rogues"))
import common

SKETCH = HERE.parents[2]
MODEL = SKETCH / "assets/models/bosses/arena_bowl_yard.glb"
METAL, COPPER, SLAG, PAINT, GLOW = "foundry_steel", "foundry_copper", "cooled_slag", "paint", "slag_glow"
DECK_Y = 15.0
NORTH_BLEACHERS, EAST_CRANE_WATCH, SOUTH_SCAFFOLD, WEST_GALLERY = 300.0, 4.0, 95.0, 163.0
STANDS = [(NORTH_BLEACHERS, 18.0, 0, 5), (EAST_CRANE_WATCH, 5.0, 3, 2), (SOUTH_SCAFFOLD, 18.0, 0, 5), (WEST_GALLERY, 7.0, 4, 1)]
WEST_PIERS = (154.0, 172.0)
TIERS = 5
TIER_R0, TIER_DR = 69.0, 2.4
TIER_Y0, TIER_DY = 18.0, 2.0
STEP_DEGREES = 6.0
SPOUTS = [15.0, 165.0, 255.0]
FURNACES = [50.0, 140.0, 345.0]
FURNACE_R = 84.0
LEDGER_ANGLE, LEDGER_R = 180.0, 76.0


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def polar(angle, radius, y):
    return (math.cos(angle) * radius, y, math.sin(angle) * radius)


def box(part, size, at, colour, slot=METAL, yaw=0):
    """size is (radial, height, tangential) when yaw is -angle."""
    part.box(slot, (size[0], size[2], size[1]), loc=xyz(at), rot=(0, 0, yaw), color=colour)


def beam(part, a, b, width, colour, height=None, slot=METAL):
    part.beam(slot, xyz(a), xyz(b), width, height, color=colour)


def rod(part, a, b, r, colour, slot=METAL, segs=8, r2=None):
    part.rod(slot, xyz(a), xyz(b), r, segs, color=colour, r2=r2)


def tri(part, a, b, c, colour, slot=PAINT):
    verts = [part.bm.verts.new(xyz(p)) for p in (a, b, c)]
    face = part.bm.faces.new(verts)
    back = part.bm.faces.new(list(reversed([part.bm.verts.new(xyz(p)) for p in (a, b, c)])))
    part.paint([face, back], slot, colour)


def tier(k):
    return TIER_R0 + TIER_DR * k, TIER_Y0 + TIER_DY * k


def tangent(a):
    return Vector((-math.sin(a), 0, math.cos(a)))


def local(a, r, y, t=0.0):
    """The point at bearing a (radians), radius r and height y, moved t metres along the bearing's tangent."""
    return tuple(Vector(polar(a, r, y)) + tangent(a) * t)


def lbox(part, a, r0, r1, y0, y1, t0, t1, colour, slot=METAL):
    """A box in bearing a's own frame: radius r0 to r1, height y0 to y1, t0 to t1 metres along the tangent."""
    t0, t1 = min(t0, t1), max(t0, t1)
    box(part, (r1 - r0, y1 - y0, t1 - t0), local(a, (r0 + r1) / 2, (y0 + y1) / 2, (t0 + t1) / 2), colour, slot, yaw=-a)


def chord(a0, a1, r, spare=.06):
    return 2 * r * math.sin((a1 - a0) / 2) + spare


def steps(lo, hi, size):
    n = max(1, round(math.degrees(hi - lo) / size))
    return [(lo + (hi - lo) * s / n, lo + (hi - lo) * (s + 1) / n) for s in range(n)]


def corrugated(part, a, front, back, w_front, w_back, crests, amp, colour, slot=METAL, th=.09):
    """A corrugated iron sheet across bearing a: from front (r, y) to back (r, y), w_front and w_back wide, its crests
    running down the slope. One closed solid; the zig-zag edge reads as corrugation from below and across the bowl."""
    up = Vector((0, 1, 0))
    rows = []
    for (r, y), w in ((front, w_front), (back, w_back)):
        centre = Vector(polar(a, r, y))
        row = []
        for lift in (0.0, th):
            row.append([part.bm.verts.new(xyz(tuple(centre + tangent(a) * (-w / 2 + w * i / (2 * crests))
                                                    + up * (lift + (amp if i % 2 else 0.0)))))
                        for i in range(2 * crests + 1)])
        rows.append(row)
    (f_lo, f_hi), (b_lo, b_hi) = rows
    n = 2 * crests + 1
    faces = []
    for i in range(n - 1):
        faces.append(part.bm.faces.new((f_lo[i], b_lo[i], b_lo[i + 1], f_lo[i + 1])))
        faces.append(part.bm.faces.new((f_hi[i], f_hi[i + 1], b_hi[i + 1], b_hi[i])))
    for i in (0, n - 1):
        faces.append(part.bm.faces.new((f_lo[i], f_hi[i], b_hi[i], b_lo[i])))
    faces.append(part.bm.faces.new(f_lo + list(reversed(f_hi))))
    faces.append(part.bm.faces.new(b_hi + list(reversed(b_lo))))
    bmesh.ops.recalc_face_normals(part.bm, faces=faces)
    part.paint(faces, slot, colour)


def horn(part, mouth, aim, length, flare):
    """A Fleet megaphone: a brass throat flaring to a wide bell, its dark mouth turned to the bowl."""
    d = (Vector(aim)).normalized()
    m = Vector(mouth)
    root = m - d * length
    neck = m - d * length * .42
    rod(part, tuple(root - d * .3), tuple(neck + d * .35), .3, "8a6a3a", slot=COPPER, segs=10, r2=.44)
    rod(part, tuple(neck), tuple(m), .42, "c29c55", slot=COPPER, segs=12, r2=flare)
    rod(part, tuple(m - d * .25), tuple(m + d * .05), flare + .16, "a38149", slot=COPPER, segs=12)
    rod(part, tuple(m), tuple(m + d * .09), flare * .82, "2b2520", slot=PAINT, segs=12)


def foundry_bleachers(part, lo, hi):
    """North: heavy stepped iron bleachers under a raked corrugated oxide awning, a cluster of giant brass Fleet
    megaphones on the front posts blaring into the bowl."""
    with part.region(bevel=0):
        for s, (a0, a1) in enumerate(steps(lo, hi, STEP_DEGREES)):
            mid = (a0 + a1) / 2
            for k in range(TIERS):
                r, y = tier(k)
                width = chord(a0, a1, r)
                box(part, (2.5, y - .3 - DECK_Y, width), polar(mid, r, (y - .3 + DECK_Y) / 2), "47443d" if (s + k) % 2 else "514d44", yaw=-mid)
                box(part, (2.4, .3, width + .04), polar(mid, r, y - .15), "6d6656" if (s + k) % 2 else "5f5a4d", yaw=-mid)
                box(part, (.08, .42, width - .3), polar(mid, r - 1.27, y - .62), "8d6240", slot=COPPER, yaw=-mid)
            r, y = tier(TIERS - 1)
            box(part, (.16, .16, chord(a0, a1, r + 1.0)), polar(mid, r + 1.0, y + 1.1), "8a7556", slot=COPPER, yaw=-mid)
            corrugated(part, mid, (65.4, 37.6), (82.6, 34.2), chord(a0, a1, 65.4, -.08), chord(a0, a1, 82.6, -.08), 7, .34,
                       "ae6e48" if s % 2 else "a66444")
            box(part, (.5, .7, chord(a0, a1, 65.3, .02)), polar(mid, 65.3, 37.65), "6e4432", yaw=-mid)
            for k in (1, 3):
                rk = 65.4 + (82.6 - 65.4) * k / 4
                yk = 37.6 + (34.2 - 37.6) * k / 4
                box(part, (.36, .36, chord(a0, a1, rk, .1)), polar(mid, rk, yk - .3), "3f3a33", yaw=-mid)
    with part.region(bevel=.12):
        frames = [lo + (hi - lo) * f / 3 for f in range(4)]
        for f, a in enumerate(frames):
            beam(part, polar(a, 66.4, DECK_Y), polar(a, 66.4, 37.4), .7, "3e413b")
            beam(part, polar(a, 81.2, DECK_Y), polar(a, 81.2, 34.4), .7, "3e413b")
            beam(part, polar(a, 64.8, 37.7), polar(a, 83.2, 34.0), .62, "3a3d37")
            beam(part, polar(a, 66.4, 33.2), polar(a, 69.6, 37.2), .32, "3a3d37")
        for end, side in ((lo, 1), (hi, -1)):
            for k in range(TIERS):
                r, y = tier(k)
                lbox(part, end, r - 1.3, r + 1.3, DECK_Y, y + .25, side * .05, side * .6, "39403b")
    with part.region(bevel=0):
        for f, a in enumerate(frames):
            out = -1 if f == 0 else 1
            cluster = [(-1.1, 33.6, -.9 + 2.6 * out, 2.1), (1.0, 31.9, .7 + 2.2 * out, 1.75), (-.4, 30.2, .2 + 1.6 * out, 1.4)] \
                if f in (0, 3) else [(0.0, 33.0, 0.0, 1.8)]
            for t, y, swing, flare in cluster:
                mouth = Vector(local(a, 63.7, y, t))
                aim = Vector(polar(a, -1.0, 0)) + tangent(a) * swing * .25 + Vector((0, -.22, 0))
                horn(part, tuple(mouth), tuple(aim), 4.2, flare)
                beam(part, local(a, 66.4, y + .4, t * .2), local(a, 66.0, y + .4, t), .26, "3a3d37")


def crane_watch_box(part, centre):
    """East: a riveted petrol-green foreman's booth cantilevered off a braced gantry, a chunky split-flap scoreboard
    frame on its roof. The crew sit at its window on two benches (tiers 3 and 4)."""
    a = centre
    green, green_dk, seam = "3f7466", "335f54", "8a6a42"
    with part.region(bevel=.16):
        for r in (77.2, 80.6):
            for t in (-4.6, 4.6):
                beam(part, local(a, r, DECK_Y, t), local(a, r, 22.3, t), .7, "3c403a")
        lbox(part, a, 73.8, 81.2, 22.6, 23.5, -6.8, 6.8, "3a3e39")
        lbox(part, a, 73.6, 81.6, 29.4, 30.2, -7.2, 7.2, green_dk)
        lbox(part, a, 74.1, 74.6, 23.5, 24.9, -6.4, 6.4, green)
        lbox(part, a, 74.1, 74.6, 28.2, 29.4, -6.4, 6.4, green)
        for side in (-1, 1):
            lbox(part, a, 74.1, 80.9, 23.5, 29.4, side * 6.1, side * 6.5, green)
        lbox(part, a, 80.5, 80.9, 23.5, 29.4, -6.3, 6.3, green_dk)
        for t in (-4.2, 4.2):
            lbox(part, a, 77.0, 78.0, 30.2, 31.0, t - .5, t + .5, "3a3e39")
        lbox(part, a, 76.6, 77.8, 30.9, 37.3, -6.2, 6.2, "2e322f")
        lbox(part, a, 76.4, 78.0, 37.3, 37.8, -6.5, 6.5, seam, slot=COPPER)
    with part.region(bevel=0):
        lbox(part, a, 75.0, 77.4, 23.5, 24.0, -6.0, 6.0, "6d6656", slot=PAINT)
        lbox(part, a, 77.4, 79.8, 23.5, 26.0, -6.0, 6.0, "5f5a4d", slot=PAINT)
        for t in (-3.1, 0.0, 3.1):
            lbox(part, a, 74.2, 74.5, 24.9, 28.2, t - .14, t + .14, green_dk)
        for y in (24.9, 28.2):
            lbox(part, a, 73.98, 74.14, y - .14, y + .14, -6.5, 6.5, seam, slot=COPPER)
        for side in (-1, 1):
            for r in (76.4, 78.7):
                lbox(part, a, r - .14, r + .14, 23.5, 29.4, side * 6.48, side * 6.6, seam, slot=COPPER)
            lbox(part, a, 75.2, 77.9, 25.0, 27.9, side * 6.46, side * 6.56, "26302d", slot=PAINT)
        for i in range(12):
            t = -5.0 + (i % 6) * 2.0
            y = 32.5 if i < 6 else 35.6
            lbox(part, a, 76.36, 76.62, y - 1.25, y + 1.25, t - .82, t + .82, "1f2321", slot=PAINT)
            lbox(part, a, 76.28, 76.38, y - .06, y + .06, t - .86, t + .86, "c2b597", slot=PAINT)
        beam(part, local(a, 77.2, 37.8, 5.4), local(a, 77.2, 41.6, 5.4), .12, "4a4e47")
        for r in (77.2, 80.6):
            for t0, t1 in ((-4.6, 4.6), (4.6, -4.6)):
                beam(part, local(a, r, DECK_Y + .4, t0), local(a, r, 22.0, t1), .24, "4a4e47")
        for t in (-4.6, 4.6):
            for r0, r1 in ((77.2, 80.6), (80.6, 77.2)):
                beam(part, local(a, r0, DECK_Y + .4, t), local(a, r1, 22.0, t), .24, "4a4e47")
            beam(part, local(a, 77.2, 19.0, t), local(a, 74.2, 22.6, t), .4, "3c403a")
        for t in (-.45, .45):
            beam(part, local(a, 81.1, DECK_Y, t), local(a, 81.1, 23.5, t), .1, "8a7556", slot=COPPER)
        for k in range(7):
            beam(part, local(a, 81.1, 16.0 + k * 1.1, -.45), local(a, 81.1, 16.0 + k * 1.1, .45), .08, "8a7556", slot=COPPER)
        lbox(part, a, 74.8, 79.4, 23.1, 23.45, -9.0, -6.5, "4a4e47")
        for r in (74.9, 79.3):
            for t in (-8.9, -7.6):
                beam(part, local(a, r, 23.45, t), local(a, r, 24.7, t), .1, "8a7556", slot=COPPER)
        lbox(part, a, 74.82, 79.38, 24.62, 24.76, -8.98, -8.84, "8a7556", slot=COPPER)
        lbox(part, a, 74.82, 74.96, 24.62, 24.76, -8.98, -6.5, "8a7556", slot=COPPER)


def container(part, a, r, y, t, length, depth, height, colour, yaw=0.0, ribs=8):
    """A cargo container in bearing a's frame, length along the tangent (turned by yaw), its long faces ribbed."""
    span = Vector(tangent(a)) * math.cos(yaw) + Vector(polar(a, 1.0, 0)) * math.sin(yaw)
    out = Vector(polar(a, 1.0, 0)) * math.cos(yaw) - Vector(tangent(a)) * math.sin(yaw)
    centre = Vector(local(a, r, y + height / 2, t))
    heading = math.atan2(span.z, span.x)
    with part.region(bevel=.2):
        box(part, (length, height, depth), tuple(centre), colour, yaw=-heading)
    with part.region(bevel=0):
        for i in range(ribs):
            u = -length / 2 + length * (i + .5) / ribs
            for side in (-1, 1):
                box(part, (.22, height - .3, .1), tuple(centre + span * u + out * side * (depth / 2 + .03)), "6a4232", yaw=-heading)
        for end in (-1, 1):
            box(part, (.12, height + .06, depth + .1), tuple(centre + span * end * (length / 2 + .02)), "3d2f27", yaw=-heading)


def scrap_yard_scaffold(part, lo, hi):
    """South: scaffold boards on a tube frame, an asymmetric stack of cargo containers and rust girders at its high
    end, ladders, and tattered sand-and-oxide crew pennants over the top."""
    lines = [lo] + [b for _, b in steps(lo, hi, STEP_DEGREES)]
    rails = [TIER_R0 - 1.1 + TIER_DR * j for j in range(TIERS + 1)]
    with part.region(bevel=0):
        for s, (a0, a1) in enumerate(steps(lo, hi, STEP_DEGREES)):
            mid = (a0 + a1) / 2
            for k in range(TIERS):
                r, y = tier(k)
                box(part, (2.4, .28, chord(a0, a1, r)), polar(mid, r, y - .14), "7d5a3b" if (s + k) % 2 else "6c4d33", slot=PAINT, yaw=-mid)
                beam(part, polar(a0, rails[k], y - .36), polar(a1, rails[k], y - .36), .16, "6f6a5e")
                if (s + k) % 2 == 0:
                    beam(part, polar(a0, rails[k + 1], DECK_Y + .2), polar(a1, rails[k + 1], y - .4), .14, "7a4430")
            box(part, (.14, .14, chord(a0, a1, rails[-1])), polar(mid, rails[-1], tier(TIERS - 1)[1] + 1.1), "7a4430", yaw=-mid)
        for i, a in enumerate(lines):
            for j, r in enumerate(rails):
                y = tier(min(j, TIERS - 1))[1] + (1.2 if j == TIERS else 0)
                beam(part, polar(a, r, DECK_Y), polar(a, r, y), .18, "6f6a5e" if (i + j) % 3 else "7a4430")
            for k in range(TIERS):
                r, y = tier(k)
                beam(part, polar(a, rails[k], y - .4), polar(a, rails[k + 1], y - .4), .16, "6f6a5e")
        for t in (-.4, .4):
            beam(part, local(lo, 66.8, DECK_Y, t + 1.4), local(lo, 67.6, 19.0, t + 1.4), .1, "7a4430")
        for k in range(5):
            beam(part, local(lo, 66.8 + .16 * (k + .5), DECK_Y + .7 + .75 * k, 1.0), local(lo, 66.8 + .16 * (k + .5), DECK_Y + .7 + .75 * k, 1.8), .08, "7a4430")
    end = hi + math.radians(5.0)
    container(part, end, 77.5, DECK_Y, 0.0, 7.0, 2.6, 2.7, "b09668", ribs=5)
    container(part, end, 77.1, DECK_Y + 2.7, -.5, 7.0, 2.6, 2.7, "9b5a44", yaw=.1, ribs=5)
    container(part, end, 77.8, DECK_Y + 5.4, .7, 6.0, 2.6, 2.7, "7c4834", yaw=-.16, ribs=4)
    lintel = tier(TIERS - 1)[1] + 2.3
    perch = hi - math.radians(5.0)
    container(part, perch, 81.4, lintel + .7, 0.0, 8.0, 2.5, 2.6, "a88c5c", yaw=-.08, ribs=6)
    container(part, perch, 81.2, lintel + 3.3, -1.4, 5.5, 2.5, 2.6, "8a523c", yaw=.22, ribs=4)
    container(part, lo - math.radians(5.0), 75.6, DECK_Y, 0.0, 11.0, 2.5, 2.6, "8a523c", yaw=math.pi / 2, ribs=7)
    with part.region(bevel=.1):
        for da in (-4.0, 4.0):
            beam(part, polar(perch + math.radians(da), 81.6, DECK_Y), polar(perch + math.radians(da), 81.6, lintel + .2), .5, "6e4030")
    with part.region(bevel=0):
        for a0, a1 in steps(perch - math.radians(4.6), perch + math.radians(4.6), 4.6):
            mid = (a0 + a1) / 2
            for y, h, w in ((lintel + .07, .14, .8), (lintel + .63, .14, .8), (lintel + .35, .42, .16)):
                box(part, (w, h, chord(a0, a1, 81.6, .4)), polar(mid, 81.6, y), "6e4030", yaw=-mid)
        for t, lean in ((-3.0, 7.2), (2.6, 6.2)):
            foot = Vector(local(end, 72.4, DECK_Y, t))
            head = Vector(local(end, 75.6, DECK_Y + lean, t + .6))
            for off in (-.2, .2):
                beam(part, tuple(foot + tangent(end) * off), tuple(head + tangent(end) * off), .3, "6e4030")
        for t in (-.4, .4):
            beam(part, local(end, 75.9, DECK_Y, t - 2.0), local(end, 75.9, DECK_Y + 8.1, t - 2.0), .1, "4a4e47")
        for k in range(10):
            beam(part, local(end, 75.9, DECK_Y + .5 + .78 * k, -2.4), local(end, 75.9, DECK_Y + .5 + .78 * k, -1.6), .08, "4a4e47")
        top = tier(TIERS - 1)[1] + 1.2
        poles = [(lines[1], rails[-1], top - .9, top + 6.0), (lines[3], rails[-1], top - .9, top + 7.5), (lines[5], rails[-1], top - .9, top + 5.5),
                 (end, 78.0, DECK_Y + 7.6, DECK_Y + 21.0)]
        for i, (a, r, y0, y1) in enumerate(poles):
            beam(part, polar(a, r, y0), polar(a, r, y1), .18 if i < 3 else .26, "4b5149")
            size = 3.0 if i < 3 else 5.2
            tip = Vector(polar(a, r, y1 - .2))
            fly = tangent(a) * (1 if i % 2 else -1)
            sand, oxide = "c6a274", "9b5a44"
            tri(part, tuple(tip), tuple(tip + Vector((0, -size * .62, 0))), tuple(tip + fly * size + Vector((0, -size * .12, 0))), sand if i != 1 else oxide)
            tri(part, tuple(tip + Vector((0, -size * .62, 0))), tuple(tip + fly * size * .82 + Vector((0, -size * .5, 0))),
                tuple(tip + fly * size * .7 + Vector((0, -size * .3, 0))), sand if i != 1 else oxide)
            if i == 3:
                tri(part, tuple(tip + Vector((0, -2.8, 0))), tuple(tip + Vector((0, -4.6, 0))), tuple(tip - fly * 3.6 + Vector((0, -3.4, 0))), oxide)
        n = round(math.degrees(hi - lo) / 2.0)
        for i in range(n):
            a0 = lo + (hi - lo) * i / n
            a1 = lo + (hi - lo) * (i + 1) / n
            tri(part, polar(a0, rails[-1] + .1, top + 2.6), polar(a1, rails[-1] + .1, top + 2.6),
                polar((a0 + a1) / 2, rails[-1] + .1, top + 1.5), "9b5a44" if i % 2 else "c6a274")


def ladle_rail_gallery(part, lo, hi):
    """West: an arched steel bridge gallery on two piers, spanning the ladle car's track; the crew line its deck
    (tier 4) under the arch."""
    r_front, r_back = 77.0, 80.5
    with part.region(bevel=.2):
        for a, side in ((lo, 1), (hi, -1)):
            lbox(part, a, 76.2, 81.4, DECK_Y, 25.4, -1.3, 1.3, "57534b")
            lbox(part, a, 75.8, 81.8, 25.4, 26.1, -1.6, 1.6, "7d6449", slot=COPPER)
            beam(part, local(a, 83.2, DECK_Y, 0.0), local(a, 81.2, 23.0, 0.0), .9, "4c4840")
    arch = 12
    pts = [(lo + (hi - lo) * i / arch, 26.0 + 11.0 * math.sin(math.pi * i / arch)) for i in range(arch + 1)]
    with part.region(bevel=.14):
        for r in (r_front, r_back):
            for (a0, y0), (a1, y1) in zip(pts, pts[1:]):
                p0, p1 = Vector(polar(a0, r, y0)), Vector(polar(a1, r, y1))
                d = (p1 - p0).normalized() * .25
                beam(part, tuple(p0 - d), tuple(p1 + d), .8, "454a44")
        under = [(lo + (hi - lo) * i / 8, DECK_Y + 9.0 * math.sin(math.pi * i / 8)) for i in range(9)]
        for (a0, y0), (a1, y1) in zip(under, under[1:]):
            p0, p1 = Vector(polar(a0, 80.8, y0)), Vector(polar(a1, 80.8, y1))
            d = (p1 - p0).normalized() * .2
            beam(part, tuple(p0 - d), tuple(p1 + d), .7, "4c4840")
    with part.region(bevel=0):
        for s, (a0, a1) in enumerate(steps(lo, hi, 2.0)):
            mid = (a0 + a1) / 2
            box(part, (3.0, .32, chord(a0, a1, 78.7)), polar(mid, 78.7, 25.84), "6d6656" if s % 2 else "5f5a4d", slot=PAINT, yaw=-mid)
            for r in (77.3, 80.1):
                box(part, (.3, 1.3, chord(a0, a1, r)), polar(mid, r, 25.03), "3a3e39", yaw=-mid)
            box(part, (.14, .14, chord(a0, a1, 77.05)), polar(mid, 77.05, 27.15), "8a7556", slot=COPPER, yaw=-mid)
            box(part, (.1, .1, chord(a0, a1, 77.05)), polar(mid, 77.05, 26.6), "4a4e47", yaw=-mid)
        for a, _ in pts[1:-1]:
            beam(part, polar(a, 77.05, 26.0), polar(a, 77.05, 27.2), .1, "4a4e47")
        for (a, y) in pts[1:-1]:
            for r in (r_front, r_back):
                beam(part, polar(a, r, 26.0), polar(a, r, y - .3), .16, "4a4e47")
        for a, y in pts[2:-1:2]:
            beam(part, polar(a, r_front, y), polar(a, r_back, y), .22, "4a4e47")
        spout = math.radians(165.0)
        lbox(part, spout, 80.6, 81.0, DECK_Y, DECK_Y + 1.7, -2.6, 2.6, "7d6449", slot=COPPER)
        for t in (-1.6, 1.6):
            lbox(part, spout, 80.2, 80.6, DECK_Y + .9, DECK_Y + 1.4, t - .3, t + .3, "3b3e39")


def stands(root):
    part = common.Part("FleetStands")
    for centre, half, first, count in STANDS:
        lo, hi = math.radians(centre - half), math.radians(centre + half)
        if centre == NORTH_BLEACHERS:
            foundry_bleachers(part, lo, hi)
        elif centre == EAST_CRANE_WATCH:
            crane_watch_box(part, math.radians(centre))
        elif centre == SOUTH_SCAFFOLD:
            scrap_yard_scaffold(part, lo, hi)
        else:
            ladle_rail_gallery(part, math.radians(WEST_PIERS[0]), math.radians(WEST_PIERS[1]))
    part.to_object(parent=root)


def deck(root):
    part = common.Part("YardDeck")
    part.ring(METAL, 62.1, 81.5, .5, segs=72, loc=(0, 0, DECK_Y - .25), color="4f5249")
    for k in range(36):
        a = k * math.tau / 36
        beam(part, polar(a, 62.3, DECK_Y + .02), polar(a, 81.3, DECK_Y + .02), .1, "3e423c", .04)
    part.to_object(parent=root)


def furnaces(root):
    part = common.Part("CupolaFurnaces")
    glow = common.Part("FurnaceGlow")
    for degrees in FURNACES:
        a = math.radians(degrees)
        base = polar(a, FURNACE_R, DECK_Y)
        x, _, z = base
        part.cyl(METAL, 4.6, 4.2, 22, 20, loc=xyz((x, DECK_Y + 11, z)), color="57524a")
        part.cyl(METAL, 4.2, 2.6, 5, 20, loc=xyz((x, DECK_Y + 24.5, z)), color="4b4a44")
        part.cyl(METAL, 2.6, 2.4, 9, 16, loc=xyz((x, DECK_Y + 31.5, z)), color="44473f")
        for y in (DECK_Y + 4, DECK_Y + 12, DECK_Y + 20):
            part.cyl(COPPER, 4.85, 4.85, .5, 20, loc=xyz((x, y, z)), color="7a5f45")
        part.ring(METAL, 4.6, 6.6, .3, segs=20, loc=xyz((x, DECK_Y + 16, z)), color="5c574a")
        for k in range(8):
            leg = a + k * math.tau / 8
            beam(part, (x + math.cos(leg) * 6.3, DECK_Y, z + math.sin(leg) * 6.3),
                 (x + math.cos(leg) * 6.3, DECK_Y + 16, z + math.sin(leg) * 6.3), .3, "4a4e47")
        door = polar(a, FURNACE_R - 4.55, DECK_Y + 18.5)
        box(part, (.6, 3.4, 3.6), door, "3b3e39", yaw=-a)
        box(glow, (.2, 2.4, 2.6), polar(a, FURNACE_R - 4.85, DECK_Y + 18.5), "ffffff", slot=GLOW, yaw=-a)
        tap = polar(a, FURNACE_R - 4.5, DECK_Y + 3.0)
        box(part, (2.2, .5, 1.2), tap, "6b5a45", slot=COPPER, yaw=-a)
        box(glow, (.3, .9, 1.0), polar(a, FURNACE_R - 4.65, DECK_Y + 2.1), "ffffff", slot=GLOW, yaw=-a)
        glow.ring(GLOW, 1.7, 2.35, .3, segs=16, loc=xyz((x, DECK_Y + 36.1, z)), color="ffffff")
    part.to_object(parent=root)
    glow.to_object(parent=root)


def ladles(root):
    part = common.Part("LadleCars")
    melt = common.Part("LadleMelt")
    for degrees in SPOUTS:
        a = math.radians(degrees)
        box(part, (6.0, .7, 4.6), polar(a, 76.5, DECK_Y + 2.6), "4e5249", yaw=-a)
        for side in (-1, 1):
            t = Vector((-math.sin(a), 0, math.cos(a))) * side * 2.0
            for r in (74.6, 78.4):
                p = polar(a, r, DECK_Y + 2.0)
                part.cyl(METAL, .55, .55, .4, 12, loc=xyz((p[0] + t.x, p[1], p[2] + t.z)), rot=(0, math.pi / 2, -a + math.pi / 2), color="383c37")
            run = polar(a, 76.5, DECK_Y + .675)
            box(part, (8.0, 1.35, .4), (run[0] + t.x, run[1], run[2] + t.z), "4a4e47", yaw=-a)
            box(part, (8.2, .1, .6), (run[0] + t.x, DECK_Y + 1.4, run[2] + t.z), "383c37", yaw=-a)
            post = polar(a, 76.2, DECK_Y + 3.0)
            beam(part, (post[0] + t.x * 1.25, post[1], post[2] + t.z * 1.25), (post[0] + t.x * 1.25, post[1] + 4.6, post[2] + t.z * 1.25), .5, "5b5548")
        bottom = polar(a, 77.0, DECK_Y + 4.8)
        top = polar(a, 74.4, DECK_Y + 7.4)
        rod(part, bottom, top, 1.8, "6f5a43", slot=COPPER, segs=16, r2=2.25)
        lip_lo = Vector(top) + (Vector(top) - Vector(bottom)).normalized() * -.05
        rod(part, tuple(lip_lo), tuple(Vector(top) + (Vector(top) - Vector(bottom)).normalized() * .25), 2.4, "7d6449", slot=COPPER, segs=16)
        t = Vector((-math.sin(a), 0, math.cos(a))) * 2.7
        mid = (Vector(bottom) + Vector(top)) / 2
        rod(part, tuple(mid - t), tuple(mid + t), .32, "4b4f47", segs=10)
        surface = Vector(top) + (Vector(bottom) - Vector(top)).normalized() * .35
        rod(melt, tuple(surface), tuple(surface + (Vector(top) - Vector(bottom)).normalized() * .12), 2.12, "ffffff", slot=GLOW, segs=16)
    part.to_object(parent=root)
    melt.to_object(parent=root)


def ledger(root):
    part = common.Part("LedgerBoard")
    a = math.radians(LEDGER_ANGLE)
    y = DECK_Y + 10.0
    box(part, (.5, 8.6, 15.6), polar(a, LEDGER_R, y), "3a3f3a", yaw=-a)
    box(part, (.12, 7.8, 14.8), polar(a, LEDGER_R - .3, y), "262b29", slot=PAINT, yaw=-a)
    for dy in (-4.35, 4.35):
        box(part, (.7, .3, 16.2), polar(a, LEDGER_R - .05, y + dy), "a48f55", slot=COPPER, yaw=-a)
    for dy in (2.15, -1.95, -3.45):
        box(part, (.04, .06, 13.6), polar(a, LEDGER_R - .37, y + dy), "6c6a5e", slot=PAINT, yaw=-a)
    for da in (-.085, .085):
        beam(part, polar(a + da, LEDGER_R + .2, DECK_Y), polar(a + da, LEDGER_R + .2, y - 4.3), .5, "4a4e47")
        beam(part, polar(a + da, LEDGER_R + 3.5, DECK_Y), polar(a + da, LEDGER_R + .4, y + 2), .34, "4a4e47")
    part.to_object(parent=root)


def ingots(root):
    part = common.Part("IngotStock")
    for degrees, radius, layers in [(42, 72.5, 5), (58, 74.0, 4), (130, 72.0, 4), (150, 73.5, 6), (334, 72.5, 5), (354, 74.5, 3)]:
        a = math.radians(degrees)
        box(part, (3.0, .3, 3.0), polar(a, radius, DECK_Y + .15), "5a4636", yaw=-a)
        for layer in range(layers):
            y = DECK_Y + .3 + .22 + layer * .44
            cross = layer % 2
            for k in range(4):
                off = (k - 1.5) * .68
                tangent = Vector((-math.sin(a), 0, math.cos(a)))
                radial = Vector((math.cos(a), 0, math.sin(a)))
                at = Vector(polar(a, radius, y)) + (tangent if cross else radial) * off
                size = (2.6, .4, .5) if cross else (.5, .4, 2.6)
                box(part, size, tuple(at), "6a6b62" if (k + layer) % 3 else "7b6650", yaw=-a)
        box(part, (.05, .5, .8), polar(a, radius - 1.52, DECK_Y + .9), "a48f55", slot=COPPER, yaw=-a)
    part.to_object(parent=root)


def crew_yard(root):
    part = common.Part("CrewYard")
    for i in range(5):
        a = math.radians(262 + i * 3.4)
        at = polar(a, 71.5, DECK_Y + .95)
        with part.region(bevel=0):
            part.uv(PAINT, .92, 14, 9, loc=xyz(at), color=["8f6b4c", "7b7a64", "6e5a4c", "86704a", "707866"][i])
        part.ring(COPPER, .9, 1.0, .16, segs=20, loc=xyz(at), rot=(math.pi / 2, 0, -a), color="7d6449")
        box(part, (.6, .35, .28), polar(a, 70.4, DECK_Y + .17), "3b3f3a", yaw=-a)
        box(part, (3.2, .02, .08), polar(a + .029, 71.5, DECK_Y + .01), "a39468", slot=PAINT, yaw=-a)
    a = math.radians(121)
    rack = polar(a, 70.5, DECK_Y)
    box(part, (.3, 2.0, 2.6), (rack[0], DECK_Y + 1.0, rack[2]), "4c5148", yaw=-a)
    for row in range(2):
        for k in range(3):
            t = Vector((-math.sin(a), 0, math.cos(a))) * (k - 1) * .8
            at = Vector(polar(a, 70.2, DECK_Y + 1.0 + row * .7)) + t
            with part.region(bevel=0):
                part.uv(PAINT, .26, 8, 5, loc=xyz(tuple(at)), scale=(1, 1, .62), color="a48f55" if (k + row) % 2 else "8c6a45")
    a = math.radians(125)
    cart = polar(a, 71.0, DECK_Y + .7)
    box(part, (1.2, .5, 1.8), cart, "6b5a45", slot=COPPER, yaw=-a)
    part.cyl(COPPER, .38, .34, .9, 14, loc=xyz((cart[0], cart[1] + .7, cart[2])), color="8a6b4a")
    part.cyl(METAL, .12, .12, .2, 8, loc=xyz((cart[0], cart[1] + 1.25, cart[2])), color="4b4f47")
    for side in (-1, 1):
        t = Vector((-math.sin(a), 0, math.cos(a))) * side * .8
        part.cyl(METAL, .28, .28, .12, 12, loc=xyz((cart[0] + t.x, DECK_Y + .28, cart[2] + t.z)), rot=(0, math.pi / 2, -a + math.pi / 2), color="2f3330")
    a = math.radians(64)
    board = polar(a, 70.0, DECK_Y + 4.6)
    box(part, (.16, 2.2, 3.2), board, "5c4b3a", yaw=-a)
    box(part, (.06, 1.4, 2.8), polar(a, 69.9, DECK_Y + 4.9), "b8ad92", slot=PAINT, yaw=-a)
    for da in (-.02, .02):
        beam(part, polar(a + da, 70.05, DECK_Y), polar(a + da, 70.05, DECK_Y + 5.7), .14, "4a4e47")
    for k in range(4):
        t = Vector((-math.sin(a), 0, math.cos(a))) * (k - 1.5) * .7
        palm = Vector(polar(a, 69.85, DECK_Y + 3.85)) + t
        with part.region(bevel=0):
            box(part, (.12, .34, .3), tuple(palm), "c2b79c" if k != 2 else "8f8a7c", slot=PAINT, yaw=-a)
            for f in range(4):
                tip = palm + Vector((0, .3, 0)) + t.normalized() * (f - 1.5) * .07
                rod(part, tuple(palm + Vector((0, .1, 0)) + t.normalized() * (f - 1.5) * .07), tuple(tip), .03, "c2b79c" if k != 2 else "8f8a7c", slot=PAINT, segs=4)
    a = math.radians(279.5)
    box(part, (.14, 2.0, 3.4), polar(a, 70.2, DECK_Y + 3.6), "2c312e", slot=PAINT, yaw=-a)
    box(part, (.18, .2, 3.6), polar(a, 70.2, DECK_Y + 4.65), "a48f55", slot=COPPER, yaw=-a)
    for da in (-.022, .022):
        beam(part, polar(a + da, 70.3, DECK_Y), polar(a + da, 70.3, DECK_Y + 4.6), .14, "4a4e47")
    part.to_object(parent=root)


CREW_SHELLS = {"CrewFan": "crew_fan", "CrewPennant": "crew_pennant"}
CREW_HANDS = {"CrewFan": [(.20, .54, 1.56), (.20, -.54, 1.56)], "CrewPennant": [(.30, -.44, 1.18), (.44, .26, .34)]}
CREW_TRIS = {"Body": 1100, "Hat": 220, "Teeth": 12}
FUR, BELLY, HAT, BAND, MITT, TAIL, NOSE = "a99a84", "c4b8a2", "a48f55", "6e5734", "8f6b4c", "7d6450", "3b302a"


def crew_paint(name):
    """Vertex colour by position on the shell: cream belly and muzzle, brown mittens, a darker paddle tail and nose,
    a dark hat band. Blends stay on the one skin, so no colour seams."""
    hands = [Vector(h) for h in CREW_HANDS[name]]

    def paint(co, normal):
        if any((co - h).length < .15 for h in hands):
            return MITT
        if co.x < -.24 and co.z < .2:
            return TAIL
        if co.x > .39 and co.z > 1.03:
            return NOSE
        if abs(co.y) < .26 and ((co.x > .2 and .14 < co.z < .9) or (co.x > .26 and .9 < co.z < 1.12)):
            return BELLY
        return FUR
    return paint


def crew(root, name, pennant):
    """One plush crew member from its mojulo smooth shell, seat at the origin, facing +X: pear body, wide work hat,
    paddle tail, mittens up (docs/art/reference/bosses/crowd)."""
    import kit
    kit.SHELLS = str(HERE / "shells")
    pieces, new = kit.import_shells(CREW_SHELLS[name])
    part = common.Part(name)
    part.bevel = 0
    part.subsurf = 0
    paints = {"Body": crew_paint(name), "Hat": lambda co, n: BAND if 1.38 < co.z < 1.43 else HAT,
              "Teeth": lambda co, n: "d2c5a5"}
    for piece in ("Body", "Hat", "Teeth"):
        kit.add_shell(part, kit.shell_mesh(pieces[piece], CREW_TRIS[piece], (0, 0, 0)), PAINT, paints[piece])
    kit.drop(new)
    for side in (-1, 1):
        part.uv(PAINT, .035, 6, 4, loc=(.355, side * .105, 1.19), color="2a2420")
    if pennant:
        rod(part, (.3, .15, .44), (.3, 1.85, .44), .025, "6c6a5e")
        tri(part, (.3, 1.85, .44), (.3, 1.45, .44), (-.35, 1.65, .5), "94503c")
    part.to_object(parent=root)


def build():
    common.reset()
    for slot, roughness, metallic in [(METAL, .87, .18), (COPPER, .76, .28), (SLAG, .97, .04), (PAINT, .9, 0.0), (GLOW, .6, 0.0)]:
        common.SLOTS[slot] = {"vc": True, "rough": roughness, "metal": metallic}
    root = common.empty("FleetYard")
    deck(root)
    stands(root)
    furnaces(root)
    ladles(root)
    ledger(root)
    ingots(root)
    crew_yard(root)
    crew(root, "CrewFan", False)
    crew(root, "CrewPennant", True)
    return root


if __name__ == "__main__":
    import polish
    polish.enable(detail=1, bevel=.03, ao_reach=.012, bake_slots=(METAL, COPPER, PAINT))
    options = common.args()
    root = build()
    common.export(root, str(options["out"] or MODEL))
    print("ARB yard triangles:", common.tri_total(root))
    for o in common.tree(root):
        if o.type == "MESH":
            print("  %-16s %6d tris %d slots" % (o.name, common.tris(o), len(o.data.materials)))
