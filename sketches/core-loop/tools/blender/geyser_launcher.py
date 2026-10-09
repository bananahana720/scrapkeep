"""Headless recipe for the geyser launcher in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props/geyser_launcher_101.png (board alpha-props, seed 101): a
round drum of riveted stone blocks under a slotted dark grate disc, four valve posts with capped tops and a central
domed nozzle with a small pale pipe.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
Class "prop" (270 tris, 610 verts, 1 draw per GLB), so each slot is its own GLB, all at one origin:
  geyser_launcher_drum.glb      stone: block course, top course, the pit under the grate
  geyser_launcher_grate.glb     steel: rim, ring and spokes; the rim is the steel shader's state key
  geyser_launcher_fittings.glb  enamel: valve posts, caps, the domed nozzle and its pipe
The rim stands where today's amber cradle ring stands (contraptions.gd:428-435) and carries its colour through
`state_tint` (the instance's role colour), never baked. The steam column stays code-drawn (contraptions.gd:497-507).

Footprint (src/world/contraptions.gd:422-509, map_gorge.gd:356): origin at the mouth point, ground(at, 1.0), so the
ground is at y -1.0; the drum's outer radius is the spec radius 3.5 the mouth test reads (contraptions.gd:259-260);
the grate rim's outer edge is the torus's inner radius 2.9; the drum top stays under 2 m above the ground and the
nozzle well under mouth + 4.0, where the steam column is centred. No facing, no collider.

Lore (research/lore-makers-2026-10-09.md): copper caps and dome (the picture's brass), petrol posts, Switchback
Enclaves construction: serviceable, rubber-bushed (detail1 adds the bushes and the grate's service bolts).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/geyser_launcher.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common, frustum, around

MODELS = kit.SKETCH / "assets/models"
PROP = [270, 610, 1]
NAME = "geyser_launcher"

# One row per painted part, palette names or palette hex only (common.HEX mirrors src/core/palette.gd; LEDGER e6d9b8
# is not in common.HEX, so its hex is written out). "state" is the exact mint steel.gdshader swaps for state_tint.
# The stone slot multiplies its sandstone beds by the vertex colour, so the blocks take pale LEDGER (the beds show as
# sandstone) and the basin under the grate takes LEDGER too (it1: a charcoal pit hid the charcoal bars).
TONES = {
    "block": "e6d9b8",
    "patch": "bone",
    "pit": "e6d9b8",
    "state": "mint",
    "grate": "charcoal",
    "post": "petrol",
    "copper": "copper",
    "pipe": "e6d9b8",
}

# Metres, Godot +Y up, origin at the mouth point.
GROUND = -1.0
R_SPEC = 3.5                           # spec radius, the mouth test (map_gorge.gd:356)
R_TORUS_IN = 2.9                       # today's torus inner radius (contraptions.gd:430)
BLOCKS = (12, R_SPEC, 3.3, GROUND, -.15, .05)   # count, outer, inner core, y0, y1, gap
SLAB = (16, 3.42, -.15, .5)            # segments, outer radius, y0, y1 (the top course)
PIT_Y = -.3                            # the stone basin under the grate: lit stone, so the charcoal bars read over it
GRATE_Y = (.45, .72)                   # rim bottom, grate top
RIM_IN = 2.6
MID = (1.68, 2.02)                     # the ring between the two slot rows, where the posts stand
HUB = 1.15                             # the nozzle flange covers the grate inside this
SPOKES = ((16, MID[1], RIM_IN, .36), (8, HUB, MID[0], .3))   # count, r0, r1, width
POST_R = 1.85
POSTS = [45, 135, 225, 315]
POST = (.27, GRATE_Y[1], 1.55)          # radius, y0, y1
CAP = (.36, 1.55, 1.92)
SPOUT = (.34, .18, 1.1)                # length out of the post, side, centre y
NOZZLE = [(1.15, GRATE_Y[1]), (1.15, .82), (.45, 1.0), (.45, 1.5), (.58, 1.6), (.4, 1.88)]
NOZZLE_TOP = 1.98
PIPE = (.62, .16, 1.15)                # length out of the neck, side, centre y; points at +z
SOCKETS = {"socket_steam": [0, 4.0, 0]}
SIZE = {"drum": [7.0, 1.5, 7.0], "grate": [5.8, .27, 5.8], "fittings": [3.55, 1.26, 3.55]}


def tone(name):
    # The TONES row as an sRGB triple, so kit's wear jitter leaves the palette value exact.
    return common.srgb(TONES[name])


def polar(r, a, y):
    return (r * math.sin(a), y, r * math.cos(a))


def annulus(s, r0, r1, y, n, color, start=0.0):
    aa = around(n, start)
    verts = [polar(r, a, y) for r in (r0, r1) for a in aa]
    s.add(verts, [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)], color)


def wall(s, r, y0, y1, n, color, start=0.0):
    frustum(s, r, r, y0, y1, n, color, caps=(False, False))


def blocks(s):
    n, ro, ri, y0, y1, gap = BLOCKS
    for i in range(n):
        a0 = math.tau * i / n + gap / ro
        a1 = math.tau * (i + 1) / n - gap / ro
        # One block is a later replacement in a paler stone: a repairer's hand.
        c = tone("patch" if i == 7 else "block")
        v = [polar(ro, a0, y0), polar(ro, a1, y0), polar(ro, a1, y1), polar(ro, a0, y1),
             polar(ri, a0, y0), polar(ri, a1, y0), polar(ri, a1, y1), polar(ri, a0, y1)]
        s.add(v, [(0, 1, 2, 3), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)], c)
    wall(s, ri, y0, y1, n, tone("block"))


def drum(s):
    blocks(s)
    n, ro, y0, y1 = SLAB
    wall(s, ro, y0, y1, n, tone("block"))
    annulus(s, R_TORUS_IN, ro, y1, n, tone("block"))
    wall(s, R_TORUS_IN, PIT_Y, y1, n, tone("block"))
    frustum(s, R_TORUS_IN, R_TORUS_IN, PIT_Y - .01, PIT_Y, n, tone("pit"), caps=(False, True))


def spoke(s, a, r0, r1, w, y0, y1, color):
    # A flat bar along the radius: top and both long sides.
    t = (math.cos(a), 0.0, -math.sin(a))
    p = [polar(r, a, 0.0) for r in (r0, r1)]
    v = []
    for y in (y0, y1):
        for k in (-1, 1):
            for q in p:
                v.append((q[0] + t[0] * k * w / 2, y, q[2] + t[2] * k * w / 2))
    # v: y0 (-w: r0, r1), (+w: r0, r1), y1 (-w: r0, r1), (+w: r0, r1)
    s.add(v, [(4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3)], color)


def grate(s):
    n = SLAB[0]
    y0, y1 = GRATE_Y
    annulus(s, RIM_IN, R_TORUS_IN, y1, n, tone("state"))
    wall(s, R_TORUS_IN, y0, y1, n, tone("state"))
    annulus(s, MID[0], MID[1], y1, n, tone("grate"))
    for count, r0, r1, w in SPOKES:
        for i in range(count):
            spoke(s, math.tau * (i + .5) / count, r0, r1, w, y1 - .1, y1, tone("grate"))
    kit.PARTS["GrateTop"] = {"reference_position": [0, y1, 0]}


def lathe(s, profile, top, n, color):
    aa = around(n)
    verts = [polar(r, a, y) for r, y in profile for a in aa] + [(0.0, top, 0.0)]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(profile) - 1) for i in range(n)]
    last = (len(profile) - 1) * n
    faces += [(last + i, last + (i + 1) % n, len(verts) - 1) for i in range(n)]
    s.add(verts, faces, color)


def box_along(s, at, out, length, side, y, color):
    # A square bar from `at` along the unit horizontal `out`, open at its root (it sits in a post or the neck).
    ox, oz = out
    tx, tz = -oz, ox
    h = side / 2
    v = []
    for d in (0.0, length):
        for ky, kt in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
            v.append((at[0] + ox * d + tx * kt * h, y + ky * h, at[1] + oz * d + tz * kt * h))
    s.add(v, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], color)


def fittings(s):
    lathe(s, NOZZLE, NOZZLE_TOP, 8, tone("copper"))
    box_along(s, (0.0, NOZZLE[2][0] - .05), (0.0, 1.0), PIPE[0], PIPE[1], PIPE[2], tone("pipe"))
    for deg in POSTS:
        a = math.radians(deg)
        x, _, z = polar(POST_R, a, 0)
        r, y0, y1 = POST
        frustum(s, r, r, y0, y1, 6, tone("post"), caps=(False, False), at=(x, z))
        cr, c0, c1 = CAP
        frustum(s, cr, cr, c0, c1, 6, tone("copper"), caps=(True, True), at=(x, z))
        # The spout turns along the ring, the way the picture's side valves do.
        t = (math.cos(a), -math.sin(a))
        box_along(s, (x + t[0] * (r - .04), z + t[1] * (r - .04)), t, SPOUT[0], SPOUT[1], SPOUT[2], tone("post"))
    kit.PARTS["Nozzle"] = {"reference_position": [0, NOZZLE_TOP, 0]}


def stone_material():
    # kit.material has no stone row; the stone slot's GLB material only needs the slot name and vertex colour.
    mat = bpy.data.materials.new("stone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .95
    bsdf.inputs["Metallic"].default_value = 0
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])


def export(name, part, slot, build, size, sockets, out_dir, budget=PROP, tag="GEYSER"):
    common.reset()
    kit.PARTS.clear()
    stone_material()
    root = common.empty(name)
    s = kit.Surface(part, slot, smooth=False)
    build(s)
    s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    got = metrics["bounds"]["size"]
    print(tag + "_SIZE", name, [round(v, 3) for v in got], metrics["triangles"], metrics["vertices"], metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, metrics, budget)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(got, size)), (name, got, size)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print(tag + "_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def out_dir():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    return parser.parse_args(argv).out_dir


def main():
    d = out_dir()
    export(NAME + "_drum", "Drum", "stone", drum, SIZE["drum"], SOCKETS, d)
    export(NAME + "_grate", "Grate", "steel", grate, SIZE["grate"], {}, d)
    export(NAME + "_fittings", "Fittings", "enamel", fittings, SIZE["fittings"], {}, d)


if __name__ == "__main__":
    main()
