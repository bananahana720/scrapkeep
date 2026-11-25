"""The sinkhole's small authored pieces (stage 4, the authored pass of 17 October 2026): the drop lips, the miners' breach
caps, the great room's floor and the haulage rail bed. Each id builds <id>.glb (the drawn mesh <id> and the collision mesh
<id>-col) plus the detail shells <id>_detail1.glb and <id>_detail2.glb.

Each replaces a greybox stand-in, so its -col is exactly the greybox's solid (park_recipes.gd place_greybox): a drop is
the falling wedge (_wedge, rise -1: full height at the near end, nothing at the far end), a bowl or grind line is a box,
both sitting on y 0 and centred on the footprint (registry origin "centre"). The rows use the seat fit, so a 4 m piece
stretches to a 3 m row along +Z; the width is authored per id because the fit never scales across.

  skylight_lip    W 18 L 4 wedge  skylight_1..3: the roof's broken edge, glassy along the lip where the ball leaves it
  tube_mouth_lip  W 16 L 4 wedge  tube_mouth: the lava tube's mouth, crust bulging at the lip
  breach_lip      W 8 L 3 wedge   crater_breach: the crater wall breached into the channel, scoria rubble at the sides
  miners_cap      W 18 L 4 wedge  upper_tube_cap, great_room_cap: the miners' steel cap plate over a breach, slammed open
  great_room_deck W 44 L 8 box    great_room_floor: the bank's floor, basalt flags with a polish ring
  haulage_bed     W 16 L 4 box    haulage_rails: the miners' rail bed, sleepers and two copper-capped rails

Run (memory-capped with prlimit, 12 GiB of address space):
  prlimit <address-space cap> -- blender --background --threads 2 --python-exit-code 1 --python \
    sketches/core-loop/tools/blender/park/sinkhole_slabs.py -- [--out DIR] [--only ID[,ID]] [--count-only]
"""
import argparse
import json
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import tunnels
from tunnels import C, Soup, hash01, make_object, tint

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"

LANDFORM = {"tris": 6000, "draws": 2}
DETAIL = {"tris": 1500, "draws": 1}

COL = dict(C)
COL.update({
    "polish": common.mix("charcoal", "bone", .30),
    "steel": common.mix("charcoal", "bone", .45),
    "steel_dark": common.mix("charcoal", "bone", .30),
    "stencil": common.mix("bone", "sandstone", .15),
})

RECIPES = {
    "skylight_lip": {"shape": "wedge", "length": 4.0, "height": 0.5, "width": 18.0, "look": "lip"},
    "tube_mouth_lip": {"shape": "wedge", "length": 4.0, "height": 0.5, "width": 16.0, "look": "mouth"},
    "breach_lip": {"shape": "wedge", "length": 3.0, "height": 0.5, "width": 8.0, "look": "breach"},
    "miners_cap": {"shape": "wedge", "length": 4.0, "height": 0.5, "width": 18.0, "look": "cap"},
    "great_room_deck": {"shape": "box", "length": 8.0, "height": 0.5, "width": 44.0, "look": "deck"},
    "haulage_bed": {"shape": "box", "length": 4.0, "height": 0.5, "width": 16.0, "look": "rails"},
}


def wedge_points(spec):
    """park_recipes.gd _wedge for a drop: base at y 0, the top edge at the near end (z -L/2)."""
    hw, hl, h = spec["width"] / 2, spec["length"] / 2, spec["height"]
    return [Vector((-hw, 0, -hl)), Vector((hw, 0, -hl)), Vector((hw, 0, hl)), Vector((-hw, 0, hl)),
            Vector((-hw, h, -hl)), Vector((hw, h, -hl))]


def top_y(spec, z):
    """The solid's top at z: the wedge falls from full height at -L/2 to 0 at +L/2; a box is flat."""
    if spec["shape"] == "box":
        return spec["height"]
    return spec["height"] * (0.5 - z / spec["length"])


def solid(soup, spec, color_fn):
    """The greybox solid itself, faces coloured by color_fn(lane, row) in cells about 1 m across."""
    hw, hl = spec["width"] / 2, spec["length"] / 2
    nx = max(2, int(round(spec["width"])))
    nz = max(2, int(round(spec["length"])))
    xs = [-hw + spec["width"] * k / nx for k in range(nx + 1)]
    zs = [-hl + spec["length"] * k / nz for k in range(nz + 1)]
    rings = [[Vector((x, top_y(spec, z), z)) for x in xs] for z in zs]
    soup.strip(rings, lambda r, i: color_fn(i, r), "out", lambda r: Vector((0, -50, 0)), closed=False)
    inside = Vector((0, spec["height"] * 0.3, -hl * 0.3))
    if spec["shape"] == "wedge":
        p = [soup.add_vert(v) for v in wedge_points(spec)]
        soup.outward((p[0], p[1], p[5], p[4]), inside, COL["basalt_dark"])
        soup.outward((p[0], p[4], p[3]), inside, COL["basalt_dark"])
        soup.outward((p[1], p[2], p[5]), inside, COL["basalt_dark"])
    else:
        h = spec["height"]
        for z in (-hl, hl):
            q = [soup.add_vert(Vector((x, y, z))) for x, y in ((-hw, 0), (hw, 0), (hw, h), (-hw, h))]
            soup.outward(tuple(q), inside, COL["basalt_dark"])
        for x in (-hw, hw):
            q = [soup.add_vert(Vector((x, y, z))) for y, z in ((0, -hl), (0, hl), (h, hl), (h, -hl))]
            soup.outward(tuple(q), inside, COL["basalt_dark"])


def palette(look, spec):
    if look == "lip":
        return lambda i, r: tint(COL["polish"] if r == 0 else COL["basalt"], .06, i * 7 + r)
    if look == "mouth":
        return lambda i, r: tint(COL["scoria"] if hash01(i, r, 3) > .5 else COL["basalt"], .08, i + r * 13)
    if look == "breach":
        return lambda i, r: tint(COL["scoria"], .12, i * 3 + r)
    if look == "cap":
        return lambda i, r: COL["stencil"] if (i % 6 in (2, 3) and r == 1) else tint(COL["steel"] if (i // 3) % 2 else COL["steel_dark"], .04, i)
    if look == "deck":
        centre = spec["width"] / 2
        return lambda i, r: tint(COL["polish"] if abs(i - centre) < 4 else COL["basalt"], .07, i * 5 + r)
    return lambda i, r: tint(COL["dust"], .06, i + r)


def base_mesh(spec):
    soup = Soup()
    solid(soup, spec, palette(spec["look"], spec))
    hw, hl = spec["width"] / 2, spec["length"] / 2
    if spec["look"] == "rails":
        for k in range(int(spec["length"] / 0.8)):
            z = -hl + 0.4 + k * 0.8
            soup.box(Vector((0, spec["height"] - .04, z)), (spec["width"] - 1.0, .12, .3), tint(COL["timber"], .08, k))
        for x in (-0.75, 0.75):
            soup.box(Vector((x, spec["height"] + .01, 0)), (.14, .1, spec["length"]), COL["copper"])
    return soup


def col_mesh(spec):
    soup = Soup()
    solid(soup, spec, lambda i, r: COL["sand"])
    return soup


def shell1(spec):
    """Rubble and fittings beside the piece, never on its top: crust blocks off both sides."""
    soup = Soup()
    hw, hl = spec["width"] / 2, spec["length"] / 2
    for k in range(6):
        side = -1 if k % 2 else 1
        z = -hl + spec["length"] * (k + .5) / 6
        sz = .4 + hash01(k, 7, 51) * .7
        stone = COL["steel_dark"] if spec["look"] == "cap" and k % 3 == 0 else COL["scoria"]
        soup.box(Vector((side * (hw + .3 + sz / 2), sz * .4, z)), (sz, sz * .8, sz), tint(stone, .1, k),
                 yaw=hash01(k, 8, 52) * 60)
    return soup


def shell2(spec):
    """Up close: bolts along a cap's near edge, glass flecks on a lip, nothing on the deck or the bed."""
    soup = Soup()
    hw, hl = spec["width"] / 2, spec["length"] / 2
    if spec["look"] in ("cap", "lip", "mouth"):
        n = int(spec["width"] / 1.5)
        for k in range(n):
            x = -hw + 0.75 + k * 1.5
            c = COL["copper"] if spec["look"] == "cap" else COL["polish"]
            soup.box(Vector((x, spec["height"] + .03, -hl + .25)), (.12, .06, .12), c)
    else:
        soup.box(Vector((hw + .4, .1, 0)), (.2, .2, .2), COL["scoria"])
    return soup


def build_glb(rid, out_dir, count_only):
    spec = dict(RECIPES[rid])
    render, col, shells = base_mesh(spec), col_mesh(spec), [shell1(spec), shell2(spec)]
    counts = {"render": len(render.tris()), "col": len(col.tris()), "shell1": len(shells[0].tris()), "shell2": len(shells[1].tris())}
    if count_only:
        print("SINKHOLE_SLABS_COUNT", rid, json.dumps(counts, sort_keys=True))
        return counts
    rows = {}
    common.reset()
    root = common.empty(rid + "_root")
    make_object(rid, render, root, True)
    make_object(rid + "-col", col, root, False)
    path = Path(out_dir) / (rid + ".glb")
    common.export(root, str(path))
    rows[rid] = tunnels.check_glb(path, rid, counts, LANDFORM, 2, [rid, rid + "-col"], None, None)
    for k, shell in enumerate(shells, 1):
        name = "%s_detail%d" % (rid, k)
        common.reset()
        sroot = common.empty(name + "_root")
        make_object(name, shell, sroot, True)
        spath = Path(out_dir) / (name + ".glb")
        common.export(sroot, str(spath))
        rows[name] = tunnels.check_glb(spath, rid, counts, DETAIL, 1, [name], None, None)
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    ids = [i for i in args.only.split(",") if i] or list(RECIPES)
    Path(args.out).mkdir(parents=True, exist_ok=True)
    for rid in ids:
        build_glb(rid, args.out, args.count_only)


if __name__ == "__main__":
    main()
