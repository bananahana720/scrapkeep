"""Static Slag Bowl foundry details, Godot metres, no collision or animation.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/arena_bowl_dress.py
Use -- --out /tmp/arena_bowl_foundry.glb for a byte-identity rebuild.
The bowl's gameplay surfaces remain in src/boss/arena.gd.
"""
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common

SKETCH = HERE.parents[2]
MODEL = SKETCH / "assets/models/bosses/arena_bowl_foundry.glb"
METAL, COPPER, SLAG = "foundry_steel", "foundry_copper", "cooled_slag"


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def polar(angle, radius, y):
    return (math.cos(angle) * radius, y, math.sin(angle) * radius)


def box(part, size, at, colour, slot=METAL, yaw=0):
    part.box(slot, (size[0], size[2], size[1]), loc=xyz(at), rot=(0, 0, yaw), color=colour)


def beam(part, a, b, width, colour, height=None, slot=METAL):
    part.beam(slot, xyz(a), xyz(b), width, height, color=colour)


def ring(part, inner, outer, height, y, colour, slot=METAL):
    part.ring(slot, inner, outer, height, segs=72, loc=(0, 0, y), color=colour)


def pool(part, center, sx, sz, seed):
    """Continuous shallow pour skin with a broken cooling edge and broad fracture planes."""
    rng = random.Random(seed)
    cx, cy, cz = center
    rows = []
    for r, y in [(1.0, cy), (.87, cy + .008)]:
        row = []
        for i in range(18):
            a = i * math.tau / 18
            irregular = 1 + .10 * math.sin(a * 3 + seed) + .055 * math.cos(a * 5)
            row.append(part.bm.verts.new(xyz((cx + math.cos(a) * sx * r * irregular,
                                             y, cz + math.sin(a) * sz * r * irregular))))
        rows.append(row)
    hub = part.bm.verts.new(xyz((cx - .2 * sx, cy + .013, cz + .08 * sz)))
    for i in range(18):
        j = (i + 1) % 18
        edge = part.bm.faces.new((rows[0][i], rows[0][j], rows[1][j], rows[1][i]))
        face = part.bm.faces.new((hub, rows[1][i], rows[1][j]))
        part.paint([edge], SLAG, "414742")
        part.paint([face], SLAG, common.mix("2d3431", "57594f", rng.uniform(.06, .24)))


def build():
    common.reset()
    for slot, roughness, metallic in [(METAL, .87, .18), (COPPER, .76, .28), (SLAG, .97, .04)]:
        common.SLOTS[slot] = {"vc": True, "rough": roughness, "metal": metallic}
    root = common.empty("FoundryKit")

    repairs = common.Part("RimRepairs")
    for k in range(24):
        a = k * math.tau / 24
        box(repairs, (.10, 5.65, .62), polar(a, 59.97, 13.05), "674f3e", yaw=-a)
        for y in [10.6, 13.1, 15.5]:
            repairs.rod(METAL, xyz(polar(a, 59.86, y)), xyz(polar(a, 59.73, y)),
                        .12, 6, color="81705a")
        box(repairs, (.08, 1.25, 2.5), polar(a + .045, 59.98, 12.8),
            "755344" if k % 3 else "535951", yaw=-a-.045)
    ring(repairs, 59.86, 62.05, .16, 16.01, "715643")
    repairs.to_object(parent=root)

    rails = common.Part("CraneRails")
    for r in [63.0, 65.0]:
        ring(rails, r-.30, r+.30, .20, 19.8, "726758")
        ring(rails, r-.09, r+.09, .48, 19.49, "3c4540")
    for k in range(12):
        a = k * math.tau / 12
        beam(rails, polar(a, 61.1, 16), polar(a, 64, 19.75), .42, "5d5143", .54)
        beam(rails, polar(a, 62.1, 10), polar(a, 64, 19.75), .34, "484e45")
        beam(rails, polar(a, 62.5, 19.56), polar(a, 65.5, 19.56), .28, "686354", .34)
        box(rails, (1.0, .18, 1.0), polar(a, 61.3, 16.1), "866851", yaw=-a)
    for a in [math.radians(35), math.radians(200)]:
        box(rails, (3.6, .65, 4.0), polar(a, 64, 20.4), "405751", yaw=-a)
        for da in [-.022, .022]:
            beam(rails, polar(a+da, 62.9, 20.1), polar(a+da, 65.1, 20.1), .26, "494d43")
    rails.to_object(parent=root)

    spouts = common.Part("PourSpouts")
    for degrees in [15, 165, 255]:
        a = math.radians(degrees)
        beam(spouts, polar(a, 68, 19.1), polar(a, 60.25, 16.8), 2.5, "775c43", .24, COPPER)
        for side in [-1, 1]:
            da = side * .018
            beam(spouts, polar(a+da, 68, 19.55), polar(a+da, 60.25, 17.25), .22, "6b5a45", .9, COPPER)
        box(spouts, (2.6, 1.0, 4.0), polar(a, 69, 19.3), "4d5c53", yaw=-a)
        box(spouts, (2.9, .16, 4.3), polar(a, 69, 19.9), "766a56", yaw=-a)
        for da in [-.020, .020]:
            beam(spouts, polar(a+da, 69, 16), polar(a+da, 69, 19.2), .28, "4b5149")
        box(spouts, (8.0, .25, 8.0), polar(a, 70.5, 15.43), "4c5148", yaw=-a)
    spouts.to_object(parent=root)

    slag = common.Part("CooledSlagPools")
    for at, sx, sz, seed in [((-7, .009, -5), 5.2, 3.5, 19), ((9, .009, 7), 3.6, 4.4, 27),
                              ((-24, .009, 5), 2.3, 3.2, 36), ((5, .009, -25), 3.2, 2.1, 41)]:
        pool(slag, at, sx, sz, seed)
    for k, degrees in enumerate([15, 165, 255]):
        pool(slag, polar(math.radians(degrees), 70.5, 15.6), 3.5, 3.0, 100+k)
    slag.to_object(parent=root)

    seams = common.Part("CastFloorSeams")
    for k in range(12):
        a = k * math.tau / 12
        for lo, hi in [(2, 15.5), (21.5, 29.5), (36.5, 43.8)]:
            beam(seams, polar(a, lo, .012), polar(a, hi, .012), .052, "484c43", .012)
    seams.to_object(parent=root)

    collars = common.Part("MastCollars")
    for degrees in [45, 135, 225, 315]:
        a = math.radians(degrees)
        at = polar(a, 27, 0)
        for y in [.18, 6, 13, 19.1]:
            collars.ring(COPPER, 1.015, 1.25 if y < 1 else 1.14, .22, 16,
                         loc=xyz((at[0], y, at[2])), color="776448")
    collars.to_object(parent=root)

    courses = common.Part("BankCopperCourses")
    for radius in [54.1, 58.7]:
        rows = []
        for r in [radius-.08, radius+.08]:
            step = math.floor((r-44) / 1.6)
            r0, r1 = 44 + step*1.6, 44 + (step+1)*1.6
            h0, h1 = 10*((r0-44)/16)**2, 10*((r1-44)/16)**2
            y = h0 + (h1-h0)*(r-r0)/1.6 + .015
            rows.append([courses.bm.verts.new(xyz(polar(i*math.tau/72, r, y))) for i in range(72)])
        for i in range(72):
            j = (i+1) % 72
            face = courses.bm.faces.new((rows[0][i], rows[0][j], rows[1][j], rows[1][i]))
            courses.paint([face], COPPER, "79674e")
    courses.to_object(parent=root)
    return root


if __name__ == "__main__":
    options = common.args()
    root = build()
    common.export(root, str(options["out"] or MODEL))
    print("ARB triangles:", common.tri_total(root))
