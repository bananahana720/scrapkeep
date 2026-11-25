"""Park recipe family "workings": the surface plant of the open-pit copper mine (stage 3, park_pit) a park row stands up
as a solid it can ride along, harpoon or roll past.

  ore_bin        a squat riveted steel ore bin, 10 m x 10 m, 14 m tall: four timber-cribbed legs on sandstone pads, steel
                 sills, a hopper (sloped lower plates to a gate, a straight upper box with two stiffener bands and corner
                 angles), a heap of oxide and green copper ore under the rim, a copper gate lever on -z and a chute lip on
                 +x. Rows: [10, 14, 10] and smaller footprints such as [12, 6, 12] (the GLB is not scaled, see below).
  ore_bin_row    four of the same bins, 8 m wide, 11.25 m apart along a 45 m row, rims at 13.2 m, under one shared box
                 girder walkway (top 14 m) with ties across the gaps. Rows: [45, 14, 8].
  timber_portal  an adit portal, 8 m along +Z (the way in, the mouth at z -4) x 6 m tall x 3 m wide: three timber sets
                 (two posts and a cap each) with roof and side lagging, a stencilled "03" number board on the front cap,
                 standing against a rock headwall (z 1.2 to 4) round a dark opening. Rows: [8, 6, 3].

Convention: metres, +Y up, row length along +Z, width along X (park row size [length, height, width]); the origin is the
footprint centre on the ground (registry origin "centre"). park_recipes.gd place_parts places a GLB by position and yaw
only (row_transform; no scale, origin centre: ride_frame origin 0), so each recipe is authored at its row size exactly
and a row of another size draws the GLB at its own size: ore_bin_row covers the long rows. Geometry stays inside the
footprint (|x| <= width / 2, |z| <= length / 2) and spans y 0 to the height; only the bin's footing pads sink 0.3 m.

Collision ("<id>-col", node "<id>-col-col" because Godot's importer strips one -col hint; bowls.py build_recipe):
  ore_bin, ore_bin_row  one closed box hull over the footprint from y 0 to the top: no gap under the hopper a 2 m ball
                        can enter, and vertical sides (normal.y 0, at most 0.7) a harpoon bites.
  timber_portal         the posts and caps only, so the opening and the passage stay open.

Files per recipe id (assets/asset_budgets.json: ore_bin and ore_bin_row class landform, 8,000 triangles, 24,000 vertices,
one draw; timber_portal class detail, 1,500 / 3,000 / one draw; every shell class detail):
  <id>.glb          the drawn mesh <id> (one "enamel" surface, vertex colour as albedo, as anchors.py) and the -col mesh
  <id>_detail1.glb  detail shell 1 (mid range): plate seams, ladder; lagging seams, rail and ties
  <id>_detail2.glb  detail shell 2 (close range): rivet and bolt heads, walkway grating, post straps
Built with anchors.py's Surface (convex pieces wound outward, flat shaded); two builds are byte-identical.

Palette: Southwest stone (sandstone c6a274, desert varnish 3a3027, iron-oxide red 9b513a), mine timber, steel with copper
b77843 for machinery (the gate lever), never brass; ore in oxide red and chrysocolla green 8fa38a. No texture, no light,
no mesh from any other source.

  prlimit -v12884901888 blender --background --threads 2 --python-exit-code 1 --python \\
      sketches/core-loop/tools/blender/park/workings.py -- [--out-dir DIR] [--recipe ID] [--count-only]
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))
import common
import anchors

Surface = anchors.Surface
MODELS = Path(common.SKETCH) / "assets/models/park"
CLASSES = json.loads((Path(common.SKETCH) / "assets/asset_budgets.json").read_text())["classes"]
STEEP_NY = 0.7
FOOT_SINK = 0.3

STEEL = ("5a5853", "4f4c48", "33312e")
STEEL_DK = ("45423e", "3b3936", "2b2724")
RUST = ("8a4e36", "7a4430", "52301f")
COPPER = anchors.COPPER
TIMBER, TIMBER_DARK = anchors.TIMBER, anchors.TIMBER_DARK
TIMBER_LT = ("9a7650", "8c6d4c", "5a4230")
SANDTOP = anchors.SANDTOP
VARNISH = anchors.VARNISH
RED = anchors.RED
ORE = ("a65f43", "9b513a", "6a3626")
CHRYSO = ("9db398", "8fa38a", "5f7158")
BOARD = ("e3d3ad", "d2c5a5", "a39373")
STENCIL = ("2b2724", "2b2724", "2b2724")
DARK = ("1c1816", "1a1614", "141110")
IRON = anchors.IRON


def quad_ring(hx, hz, y, cx=0.0, cz=0.0):
    return [(cx - hx, y, cz - hz), (cx + hx, y, cz - hz), (cx + hx, y, cz + hz), (cx - hx, y, cz + hz)]


def ring_solid(s, lo, hi, tone, mottle=0.08):
    """Two rings of four corners (bottom, top) closed into one convex piece."""
    pts = lo + hi
    faces = [(0, 1, 2, 3), (4, 5, 6, 7)] + [(k, (k + 1) % 4, 4 + (k + 1) % 4, 4 + k) for k in range(4)]
    s.add(pts, faces, tone, mottle)


CRIB = 1.3
CRIB_LAYERS = 10
CRIB_TOP = 6.0
SILL_TOP = 6.6
HOPPER_BREAK = 9.4
GATE_HALF = 1.4


def ore_bin_unit(base, s1, s2, cx, cz, hx, hz, top, ladder=True, rivet_step=1.2):
    """One bin over the rectangle cx +- hx, cz +- hz, rim top at `top`."""
    r = base.rng
    corners = [(cx + sx * (hx - CRIB), cz + sz * (hz - CRIB)) for sx in (-1, 1) for sz in (-1, 1)]
    t = (CRIB_TOP - 0.4) / CRIB_LAYERS
    for k, (px, pz) in enumerate(corners):
        base.box((px - CRIB, -FOOT_SINK, pz - CRIB), (px + CRIB, 0.4, pz + CRIB), SANDTOP, skip=("-y",), mottle=.12)
        for layer in range(CRIB_LAYERS):
            y0 = 0.4 + layer * t
            tone = TIMBER if (layer + k) % 3 else TIMBER_DARK
            for off in (-CRIB + .27, CRIB - .27):
                if layer % 2 == 0:
                    base.box((px - CRIB, y0, pz + off - .25), (px + CRIB, y0 + t, pz + off + .25), tone, mottle=.14)
                else:
                    base.box((px + off - .25, y0, pz - CRIB), (px + off + .25, y0 + t, pz + CRIB), tone, mottle=.14)
    xs = sorted({c[0] for c in corners})
    zs = sorted({c[1] for c in corners})
    for x in xs:
        base.box((x - .3, CRIB_TOP, cz - hz + .1), (x + .3, SILL_TOP, cz + hz - .1), STEEL_DK, mottle=.05)
    for z in zs:
        base.box((cx - hx + .1, CRIB_TOP, z - .3), (cx + hx - .1, SILL_TOP, z + .3), STEEL_DK, mottle=.05)
    ux, uz = hx - .15, hz - .15
    ring_solid(base, quad_ring(GATE_HALF, GATE_HALF, SILL_TOP - .2, cx, cz), quad_ring(ux, uz, HOPPER_BREAK, cx, cz), STEEL)
    base.box((cx - ux, HOPPER_BREAK, cz - uz), (cx + ux, top - .45, cz + uz), STEEL, skip=("-y",), mottle=.07)
    base.box((cx - hx, top - .45, cz - hz), (cx + hx, top, cz + hz), STEEL_DK, mottle=.05)
    for y in (HOPPER_BREAK + .25, (HOPPER_BREAK + top) / 2):
        base.box((cx - ux - .08, y, cz - uz - .08), (cx + ux + .08, y + .3, cz + uz + .08), RUST, mottle=.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = cx + sx * ux, cz + sz * uz
            base.box((x - .14, HOPPER_BREAK, z - .14), (x + .14, top - .45, z + .14), STEEL_DK, mottle=.04)
    ring_solid(base, quad_ring(hx - .35, hz - .35, top - .5, cx, cz), quad_ring(1.6, 1.6, top - .12, cx, cz), ORE, mottle=.16)
    for k in range(3):
        base.rock((cx + r.uniform(-1.4, 1.4), top - .25, cz + r.uniform(-1.4, 1.4)), (.55, .3, .55), CHRYSO)
    base.box((cx - GATE_HALF, CRIB_TOP - .5, cz - GATE_HALF), (cx + GATE_HALF, SILL_TOP - .2, cz + GATE_HALF), STEEL_DK, mottle=.05)
    base.box((cx - .5, CRIB_TOP - .4, cz - GATE_HALF - .12), (cx + .5, CRIB_TOP + .1, cz - GATE_HALF), COPPER, skip=("+z",), mottle=.05)
    base.rod((cx + .3, CRIB_TOP - .15, cz - GATE_HALF - .1), (cx + .3, CRIB_TOP - 1.5, cz - GATE_HALF - .9), .07, COPPER, sides=6)
    lip = cx + hx - .3
    y_in, y_out = CRIB_TOP - .5, CRIB_TOP - 1.7
    base.prism_z([(cx + GATE_HALF - .2, y_in), (lip, y_out), (lip, y_out - .22), (cx + GATE_HALF - .2, y_in - .22)], cz - .9, cz + .9, STEEL)
    for z0, z1 in ((cz - 1.05, cz - .9), (cz + .9, cz + 1.05)):
        base.prism_z([(cx + GATE_HALF - .2, y_in - .22), (lip, y_out - .22), (lip, y_out + .6), (cx + GATE_HALF - .2, y_in + .6)], z0, z1, STEEL_DK)
    base.box((lip, y_out - .3, cz - 1.05), (cx + hx, y_out + .45, cz + 1.05), RUST, mottle=.05)
    for side in (-1, 1):
        n = max(2, int(2 * hz / 2.5))
        for k in range(1, n):
            z = cz - uz + 2 * uz * k / n
            x = cx + side * ux
            s1.box((x - .04 if side > 0 else x - .08, HOPPER_BREAK + .55, z - .06), (x + .08 if side > 0 else x + .04, top - .5, z + .06), STEEL_DK, mottle=.03)
        n = max(2, int(2 * hx / 2.5))
        for k in range(1, n):
            x = cx - ux + 2 * ux * k / n
            z = cz + side * uz
            s1.box((x - .06, HOPPER_BREAK + .55, z - .04 if side > 0 else z - .08), (x + .06, top - .5, z + .08 if side > 0 else z + .04), STEEL_DK, mottle=.03)
    if ladder:
        lx = cx - hx + .12
        for dz in (-.32, .32):
            s1.box((lx - .05, .4, cz + dz - .05), (lx + .05, top, cz + dz + .05), STEEL_DK, mottle=.03)
        y = .8
        while y < top - .3:
            s1.box((lx - .04, y, cz - .32), (lx + .04, y + .07, cz + .32), STEEL_DK, skip=("-z", "+z"), mottle=.03)
            y += .6
    for y in (HOPPER_BREAK + .4, (HOPPER_BREAK + top) / 2 + .15, top - .22):
        for side in (-1, 1):
            out = hx - .07 if y > top - .45 else ux + .08
            z = cz - hz + .6
            while z < cz + hz - .5:
                x = cx + side * out
                s2.box((x - .05 if side > 0 else x - .06, y - .06, z - .06), (x + .06 if side > 0 else x + .05, y + .06, z + .06), STEEL, skip=("-x",) if side > 0 else ("+x",), mottle=.02)
                z += rivet_step
    for px, pz in corners:
        f = pz + CRIB if pz < cz else pz - CRIB
        for y in (1.5, 4.3):
            s2.box((px - .1, y, min(f, f + (.04 if pz < cz else -.04))), (px + .1, y + .2, max(f, f + (.04 if pz < cz else -.04))), IRON,
                   skip=("-z",) if pz < cz else ("+z",), mottle=.02)


def ore_bin(base, s1, s2):
    ore_bin_unit(base, s1, s2, 0.0, 0.0, 5.0, 5.0, 14.0)


ROW_PITCH = 11.25
ROW_TOP = 13.2


def ore_bin_row(base, s1, s2):
    for k in range(4):
        cz = -22.5 + ROW_PITCH * (k + .5)
        ore_bin_unit(base, s1, s2, 0.0, cz, 4.0, 5.0, ROW_TOP, ladder=(k == 0), rivet_step=3.0)
        if k:
            z0, z1 = cz - ROW_PITCH / 2 - .7, cz - ROW_PITCH / 2 + .7
            for x in (-3.4, 3.4):
                base.box((x - .25, ROW_TOP - .45, z0), (x + .25, ROW_TOP - .1, z1), STEEL_DK, skip=("-z", "+z"), mottle=.04)
    base.box((-.8, ROW_TOP - .2, -22.5), (.8, 13.88, 22.5), STEEL_DK, mottle=.05)
    for x0, x1 in ((-.8, -.68), (.68, .8)):
        base.box((x0, 13.88, -22.5), (x1, 14.0, 22.5), RUST, skip=("-y",), mottle=.04)
    z = -21.75
    while z <= 22.0:
        s2.box((-.68, 13.88, z - .04), (.68, 13.94, z + .04), STEEL, skip=("-y",), mottle=.02)
        z += 1.5


SETS = (-3.6, -1.4, 0.8)
POST_X = (1.06, 1.42)
CAP_Y = (5.4, 5.85)
HEADWALL_Z = 1.2


def portal_parts():
    """[(lo, hi)] of the posts and caps: drawn and collided alike."""
    out = []
    for z in SETS:
        for s in (-1, 1):
            x0, x1 = sorted((s * POST_X[0], s * POST_X[1]))
            out.append(((x0, 0.0, z - .18), (x1, CAP_Y[0], z + .18)))
        out.append(((-1.5, CAP_Y[0], z - .21), (1.5, CAP_Y[1], z + .21)))
    return out


def timber_portal(base, s1, s2):
    r = base.rng
    for k, (lo, hi) in enumerate(portal_parts()):
        base.box(lo, hi, TIMBER if k % 3 == 2 else (TIMBER_DARK if k % 2 else TIMBER), mottle=.14)
    zl0, zl1 = SETS[0] - .21, HEADWALL_Z
    for k in range(10):
        x0 = -1.5 + k * .3
        base.box((x0 + .02, CAP_Y[1], zl0 + r.uniform(0, .15)), (x0 + .28, 6.0, zl1), TIMBER_LT if k % 2 else TIMBER, skip=("-y",), mottle=.12)
    for s in (-1, 1):
        x0, x1 = sorted((s * POST_X[1], s * 1.5))
        for k in range(13):
            y0 = k * (CAP_Y[0] / 13)
            base.box((x0, y0 + .02, SETS[0] - .18 + r.uniform(0, .1)), (x1, y0 + CAP_Y[0] / 13, zl1), TIMBER_DARK if k % 2 else TIMBER, skip=(), mottle=.12)
    for s in (-1, 1):
        x0, x1 = sorted((s * POST_X[0], s * 1.5))
        base.box((x0, 0.0, HEADWALL_Z), (x1, CAP_Y[0], 4.0), RED, mottle=.18)
    base.box((-1.5, CAP_Y[0], HEADWALL_Z), (1.5, 6.0, 4.0), VARNISH, mottle=.15)
    for k, y in enumerate((1.4, 3.0, 4.4)):
        for s in (-1, 1):
            base.box((s * 1.5 - (.5 if s > 0 else 0), y, HEADWALL_Z - .25), (s * 1.5 + (0 if s > 0 else .5), y + .55, HEADWALL_Z), SANDTOP, skip=("+z",), mottle=.16)
    base.box((-POST_X[0], 0.0, 2.4), (POST_X[0], CAP_Y[0], 2.45), DARK, mottle=.02)
    for s in (-1, 1):
        base.box((s * POST_X[0] - (.01 if s > 0 else 0), 0.0, HEADWALL_Z), (s * POST_X[0] + (0 if s > 0 else .01), CAP_Y[0], 2.4), DARK, skip=("-z", "+z"), mottle=.02)
    base.box((-POST_X[0], CAP_Y[0] - .01, HEADWALL_Z), (POST_X[0], CAP_Y[0], 2.4), DARK, skip=("-z", "+z"), mottle=.02)
    zf = SETS[0] - .21
    base.box((-.75, CAP_Y[0] + .03, zf - .06), (.75, CAP_Y[1] - .03, zf), BOARD, skip=("+z",), mottle=.04)
    ys = (CAP_Y[0] + .08, (CAP_Y[0] + CAP_Y[1]) / 2, CAP_Y[1] - .08)
    for cxd, segs in ((-.22, "abcdef"), (.22, "abcdg")):
        w, sw = .12, .025
        bars = {"a": ((cxd - w, ys[2] - sw), (cxd + w, ys[2])), "g": ((cxd - w, ys[1] - sw / 2), (cxd + w, ys[1] + sw / 2)),
                "d": ((cxd - w, ys[0]), (cxd + w, ys[0] + sw)), "b": ((cxd + w - sw, ys[1]), (cxd + w, ys[2])),
                "c": ((cxd + w - sw, ys[0]), (cxd + w, ys[1])), "f": ((cxd - w, ys[1]), (cxd - w + sw, ys[2])),
                "e": ((cxd - w, ys[0]), (cxd - w + sw, ys[1]))}
        for seg in segs:
            (x0, y0), (x1, y1) = bars[seg]
            base.box((x0, y0, zf - .075), (x1, y1, zf - .06), STENCIL, skip=("+z",), mottle=0.0)
    for k in range(1, 10):
        x = -1.5 + k * .3
        s1.box((x - .015, 5.99, zl0), (x + .015, 6.0, zl1), DARK, skip=("-y",), mottle=0.0)
    z = -3.8
    while z < 2.4:
        s1.box((-.75, 0.0, z - .1), (.75, .08, z + .1), TIMBER_DARK, skip=("-y",), mottle=.1)
        z += .6
    for x in (-.45, .45):
        s1.box((x - .04, .08, -4.0), (x + .04, .16, 2.4), IRON, skip=("-y",), mottle=.03)
    for z in SETS:
        for s in (-1, 1):
            x0, x1 = sorted((s * POST_X[0], s * POST_X[1]))
            for y in (1.2, 4.6):
                s2.box((x0 - .02, y, z - .2), (x1 + .02, y + .12, z + .2), IRON, mottle=.03)
        for f in (-.21, .21):
            for x in (-1.25, 1.25):
                s2.box((x - .06, (CAP_Y[0] + CAP_Y[1]) / 2 - .06, z + f - (.04 if f < 0 else 0)),
                       (x + .06, (CAP_Y[0] + CAP_Y[1]) / 2 + .06, z + f + (0 if f < 0 else .04)), IRON, skip=("+z",) if f < 0 else ("-z",), mottle=.02)


RECIPES = {
    "ore_bin": (ore_bin, 2101, "landform", (10.0, 14.0, 10.0), "hull"),
    "ore_bin_row": (ore_bin_row, 2111, "landform", (45.0, 14.0, 8.0), "hull"),
    "timber_portal": (timber_portal, 2121, "detail", (8.0, 6.0, 3.0), "portal"),
}


def check_recipe(rid, size, base, col, shells, sink):
    """Fails loud on the authoring contract: inside the footprint, spanning y 0 to the height, a grounded -col with steep
    sides, and every count inside its class."""
    hl, h, hw = size[0] / 2, size[1], size[2] / 2
    for name, s in [(rid, base), (rid + "-col", col)] + [("%s_detail%d" % (rid, k + 1), sh) for k, sh in enumerate(shells)]:
        lo, hi = s.bounds()
        assert lo[0] >= -hw - 1e-6 and hi[0] <= hw + 1e-6 and lo[2] >= -hl - 1e-6 and hi[2] <= hl + 1e-6, (name, "footprint", lo, hi)
        assert lo[1] >= -sink - 1e-6 and hi[1] <= h + 1e-6, (name, "height", lo, hi)
    lo, hi = base.bounds()
    assert abs(hi[1] - h) < 1e-6, (rid, "drawn top at the row height", hi)
    clo, chi = col.bounds()
    assert abs(clo[1]) < 1e-6, (rid, "collider stands on the ground", clo)
    for a, b, c in col.tris:
        n = anchors.cross(anchors.sub(col.verts[b], col.verts[a]), anchors.sub(col.verts[c], col.verts[a]))
        ny = n[1] / anchors.dot(n, n) ** .5
        assert ny > .999 or ny < -.999 or abs(ny) <= STEEP_NY, (rid, "collider side not steep", ny)


def build_recipe(rid, out_dir, count_only):
    fn, seed, cls, size, kind = RECIPES[rid]
    base = Surface(rid, seed)
    col = Surface(rid + "-col-col", seed, colored=False)
    shells = [Surface("%s_detail%d" % (rid, k), seed + k) for k in (1, 2)]
    fn(base, *shells)
    hl, h, hw = size[0] / 2, size[1], size[2] / 2
    if kind == "hull":
        col.box((-hw, 0.0, -hl), (hw, h, hl))
    else:
        for lo, hi in portal_parts():
            col.box(lo, hi)
    check_recipe(rid, size, base, col, shells, FOOT_SINK if kind == "hull" else 0.0)
    caps, detail = CLASSES[cls], CLASSES["detail"]
    counts = {"base": len(base.tris), "col": len(col.tris), "detail1": len(shells[0].tris), "detail2": len(shells[1].tris)}
    assert counts["base"] + counts["col"] <= caps["tris"], (rid, "base triangles", counts, caps["tris"])
    for k in ("detail1", "detail2"):
        assert counts[k] <= detail["tris"], (rid, k, counts[k])
    print("WORKINGS_COUNT", rid, json.dumps(counts, sort_keys=True))
    if count_only:
        return
    out = Path(out_dir)
    for name, surfaces, cap in ((rid, [base, col], caps), ("%s_detail1" % rid, [shells[0]], detail), ("%s_detail2" % rid, [shells[1]], detail)):
        path = out / (name + ".glb")
        m = anchors.export_one(path, name, surfaces)
        assert m["triangles"] <= cap["tris"] and m["vertices"] <= cap["verts"] and m["primitives"] <= cap["draws"] + (1 if name == rid else 0), (name, m, cap)
        row = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "triangles": m["triangles"],
               "vertices": m["vertices"], "primitives": m["primitives"], "materials": m["materials"], "nodes": m["nodes"], "bounds": m["bounds"]}
        print("WORKINGS_EXPORT", name, json.dumps(row, sort_keys=True))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--recipe", action="append", choices=sorted(RECIPES))
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    for rid in args.recipe or sorted(RECIPES):
        build_recipe(rid, args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
