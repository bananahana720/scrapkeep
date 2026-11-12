# Reward gate arch (VISUAL-LANGUAGE.md section 9): two stout posts of mismatched
# salvaged box sections with angle-iron corners, an I-beam lintel with rarity trim, a
# diamond keystone with a mint field core, a gantry that hangs the trigger and element
# glyph plates, and one rarity topper per rarity whose shape matches the section 5
# frames and src/build/tier_mark.gd (common a bar, rare a bold-rimmed diamond, relic a
# double-outlined four-point star with bolt heads and a mint heart, evolved a double-outlined
# crown of five points). 2026-11-12 (W1-26 follow-up): relic was a five-point star and
# evolved a taller copy of it; both now match the pedestal gems and the ball's part feet.
# Provenance: authored procedurally here from Blender primitives and bmesh operators;
# no external assets. Measured tris, arch plus three plates plus one topper: common
# 1848, rare 1828, relic 2288, evolved 2048 (target 1500 to 2500).
# 2026-10-04: new rarity names; evolved raises the star prism and both outlines to
# 2.0x height, without relic's bolts/heart, keeping the file at 2,696 tris (cap 2,700).
#
# Frame: matches reward_gates.gd, ground centre at the origin, posts at x = +-WIDTH/2
# (8 m apart), lintel at HEIGHT (7 m), topper centre at HEIGHT + 1.2, glyph row at
# HEIGHT + 2.9. Blender +Y is the travel direction (Godot -Z, the gate's facing).

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import polish  # noqa: E402
from common import Part, Vector  # noqa: E402

# Polish (POLISH.md): 3 cm bevels on every edge longer than 30 cm (posts, lintel, gantry, plates), hard bolts,
# smooth shading and the AO/wear bake. rarity and field slots are not vertex-coloured, so the bake leaves the
# rarity trim bright. File total 4,564 tris of the 6,000 gate cap.
polish.enable(detail=1, bevel=0.03, bevel_min=0.3)

HEIGHT = 7.0
POST_X = 4.25
TOPPER_Z = HEIGHT + 1.2
GLYPH_Z = HEIGHT + 2.9
GANTRY_Z = GLYPH_Z + 0.95
PLATE_X = (-1.5, 0.0, 1.5)
BAND = (1500, 3700)  # polish: was (1500, 2500); hero_assets_test GATE_TRIS matches
RAMP = {"common": "bone", "rare": "amber", "relic": "mint", "evolved": "ancient"}


def post(p, rng, x):
    z = 0.0
    colors = [c for c in common.PAINT_SET]
    rng.shuffle(colors)
    p.box("rubber", (1.2, 1.2, 0.2), loc=(x, 0, 0.1))
    for k, h in enumerate((2.6, 2.4, 2.0)):
        size = 0.84 - 0.04 * k
        p.box("paint", (size, size, h), loc=(x + rng.uniform(-0.04, 0.04), 0, 0.2 + z + h / 2),
              rot=(0, 0, rng.uniform(-0.05, 0.05)), color=colors[k])
        for sy in (-1, 1):
            for dz in (0.35, h - 0.35):
                p.bolt((x - 0.22, sy * size / 2, 0.2 + z + dz), (0, sy, 0), r=0.045, h=0.04)
        z += h
        if k < 2:
            p.box("rubber", (0.94, 0.94, 0.12), loc=(x, 0, 0.2 + z))
            for sy in (-1, 1):
                for t in (-0.25, 0.25):
                    p.bolt((x + t, sy * 0.48, 0.2 + z), (0, sy, 0), r=0.05, h=0.05)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.beam("bare_metal", (x + sx * 0.43, sy * 0.43, 0.2), (x + sx * 0.43, sy * 0.43, HEIGHT - 0.3), 0.12)


def diamond(p, slot, size, loc, color=None):
    sx, sy, sz = size
    c = Vector(loc)
    pts = [c + Vector(v) for v in ((sx, 0, 0), (0, sy, 0), (-sx, 0, 0), (0, -sy, 0), (0, 0, sz), (0, 0, -sz))]
    vs = [p.bm.verts.new(q) for q in pts]
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append(p.bm.faces.new((vs[i], vs[j], vs[4])))
        faces.append(p.bm.faces.new((vs[j], vs[i], vs[5])))
    return p.paint(faces, slot, color)


def arch(rng):
    p = Part("Arch")
    post(p, rng, -POST_X)
    post(p, rng, POST_X)
    span = 2 * POST_X + 0.9
    p.box("paint", (span, 0.14, 0.72), loc=(0, 0, HEIGHT), color="oxide")
    for dz in (-0.41, 0.41):
        p.box("paint", (span, 0.66, 0.1), loc=(0, 0, HEIGHT + dz), color="petrol")
    for dy in (-0.09, 0.09):
        p.box("rarity", (span - 1.0, 0.04, 0.3), loc=(0, dy, HEIGHT))
    for x in [-3.6 + 0.8 * k for k in range(10)]:
        if abs(x) > 0.9:
            for dy in (-0.33, 0.33):
                p.bolt((x, dy, HEIGHT + 0.46), (0, 0, 1), r=0.05, h=0.05)
    diamond(p, "rarity", (0.75, 0.3, 1.0), (0, 0, HEIGHT))
    diamond(p, "field", (0.32, 0.42, 0.46), (0, 0, HEIGHT))
    for sx in (-1, 1):
        p.beam("bare_metal", (sx * (POST_X - 0.42), 0, HEIGHT - 1.4), (sx * (POST_X - 1.5), 0, HEIGHT - 0.42), 0.16)
    for sx in (-1, 1):
        p.beam("bare_metal", (sx * 3.2, 0.1, HEIGHT + 0.46), (sx * 3.2, 0.1, GANTRY_Z), 0.14)
        p.beam("bare_metal", (sx * 3.2, 0.1, HEIGHT + 0.5), (sx * 2.5, 0.1, HEIGHT + 0.46), 0.1)
    p.beam("paint", (-3.35, 0.1, GANTRY_Z), (3.35, 0.1, GANTRY_Z), 0.16, color="oxide")
    return p


def glyph_plate(i):
    g = Part("GlyphPlate%d" % i)
    c = Vector((PLATE_X[i], 0.14, GLYPH_Z))
    g.box("rubber", (1.3, 0.06, 1.3), loc=c)
    for a, b in (((-0.68, 0.68), (0.68, 0.68)), ((-0.68, -0.68), (0.68, -0.68)),
                 ((-0.68, -0.68), (-0.68, 0.68)), ((0.68, -0.68), (0.68, 0.68))):
        g.beam("bare_metal", c + Vector((a[0], 0, a[1])), c + Vector((b[0], 0, b[1])), 0.09)
    for sx in (-0.45, 0.45):
        g.rod("bare_metal", c + Vector((sx, -0.04, 0.68)), c + Vector((sx, -0.04, GANTRY_Z - GLYPH_Z)), 0.03, 4)
    return g, c


def outline_loop(p, pts, width, z_scale=1.0, slot="bare_metal", y=0.0):
    c = Vector((0, 0, TOPPER_Z))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        p.beam(slot, c + Vector((a[0], y, a[1] * z_scale)), c + Vector((b[0], y, b[1] * z_scale)), width)


def star(n, outer, inner):
    return [((outer if k % 2 == 0 else inner) * math.sin(k * math.pi / n),
             (outer if k % 2 == 0 else inner) * math.cos(k * math.pi / n)) for k in range(2 * n)]


# The evolved crown's outline (x, z about the topper centre): a band and five points.
CROWN = [(-1.1, -0.6), (1.1, -0.6), (1.1, 0.7), (0.825, 0.05), (0.55, 0.95), (0.275, 0.05), (0.0, 1.2),
         (-0.275, 0.05), (-0.55, 0.95), (-0.825, 0.05), (-1.1, 0.7)]


def topper(rarity):
    t = Part("Topper_" + rarity)
    c = Vector((0, 0, TOPPER_Z))
    upright = common.mtx(c, (math.pi / 2, 0, 0))
    if rarity == "common":
        t.box("rarity", (1.6, 0.4, 0.4), loc=c)
        for sx in (-1, 1):
            t.box("bare_metal", (0.12, 0.46, 0.46), loc=c + Vector((sx * 0.8, 0, 0)))
            t.bolt(c + Vector((sx * 0.5, -0.2, 0)), (0, -1, 0), r=0.05, h=0.04)
    elif rarity == "rare":
        diamond(t, "rarity", (0.8, 0.25, 1.0), c)
        rim = [(0.95, 0.0), (0.0, 1.18), (-0.95, 0.0), (0.0, -1.18)]
        outline_loop(t, rim, 0.18)
    elif rarity == "relic":
        # A four-point star with the gauge bezel's bolts and a mint heart (src/build/tier_mark.gd).
        tall = 1.3
        pts = [(x, y * tall) for x, y in star(4, 1.0, 0.36)]
        t.prism("rarity", pts, 0.34, matrix=upright)
        outline_loop(t, star(4, 1.16, 0.44), 0.07, tall)
        outline_loop(t, star(4, 1.32, 0.52), 0.07, tall)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            for sy in (-1, 1):
                t.bolt(c + Vector((0.3 * math.cos(a), sy * 0.19, 0.3 * math.sin(a) * tall)), (0, sy, 0),
                       r=0.08, h=0.06)
        t.ico("field", 0.36, 2, loc=c, scale=(1, 0.75, 1))
    else:
        # Evolved: a crown, a band with five points (src/build/tier_mark.gd).
        t.prism("rarity", CROWN, 0.34, matrix=upright)
        outline_loop(t, [(x * 1.12, z * 1.12 + 0.03) for x, z in CROWN], 0.07)
        outline_loop(t, [(x * 1.24, z * 1.24 + 0.06) for x, z in CROWN], 0.07)
    return t, c


def main():
    common.reset()
    a = common.args()
    rng = random.Random("scrapkeep-reward-gate")
    root = common.empty("RewardGate")
    arch_obj = arch(rng).to_object((0, 0, 0), root)
    plates = []
    for i in range(3):
        g, c = glyph_plate(i)
        plates.append(g.to_object(c, root))
    toppers = {}
    for rarity in RAMP:
        t, c = topper(rarity)
        toppers[rarity] = t.to_object(c, root)
    base = common.tris(arch_obj) + sum(common.tris(o) for o in plates)
    rows = [("arch+plates+" + r, base + common.tris(o), BAND) for r, o in toppers.items()]
    ok = common.report("reward_gate", rows)
    common.export(root, a["out"] or common.default_out("reward_gate"))
    if a["render"]:
        sheets = []
        for rarity, color in RAMP.items():
            for r, o in toppers.items():
                o.hide_render = r != rarity
            rim = bpy.data.materials["rarity"].node_tree.nodes["Principled BSDF"]
            rim.inputs["Base Color"].default_value = common.rgba(color)
            rim.inputs["Emission Color"].default_value = common.rgba(color)
            sheets.append(common.render_turntable(root, "reward_gate_" + rarity, a["render"], [
                ("game", 24.0, 0.2, 65, (1920, 1080), 0.5),
                ("close", 15.0, 0.12, 50, (800, 800)),
            ], ground_z=0.0, target=(0, 0, 5.0), yaws=(0, 60)))
        out = os.path.join(a["render"], "reward_gate_sheet.png")
        common.subprocess.run(["montage", *sheets, "-tile", "1x", "-geometry", "+0+4", "-background", "#242a28",
                               out], check=True)
        print("SHEET", out)
    if not ok:
        raise SystemExit("gate budget out of range")


main()
