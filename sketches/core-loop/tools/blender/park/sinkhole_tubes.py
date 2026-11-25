"""The sinkhole's wash-fit tube pieces: lava_wash, lava_wash_short, gallery_wash and drift_wash (stage 4, the authored
pass of 17 October 2026). Each id builds <id>.glb (the drawn mesh <id> and the collision mesh <id>-col) plus the two detail
shells <id>_detail1.glb and <id>_detail2.glb that park_recipes.gd fades by range.

Why these and not lava_tube_run: the sinkhole's tubes are `stamp: "wash"` rows 24 to 26 m wide, and the bake's wash is the
ride. The stock 16 m tube placed in a 26 m wash narrows the lane and stalls the ride (Sable seed 1: 185 dead stops, never at
waymark 2, measured 17 October 2026). So these pieces dress the wash and never ride it:

  - The ride surface stays the baked terrain. The drawn wall band follows park_stamps.gd's wash profile analytically, LIFT m
    above it, which hides the 2 m terrain grid (its chords sag up to about 0.13 m on a wall) without floating.
  - The -col mesh is two small blocks BURY m under the floor centre at the two authored ends, so the seat fit
    (park_recipes.gd PARK-SEAT) has authored ends and the ball never meets them.
  - Nothing is drawn or collides inside the lane above the surface. Crest crust and fallen roof slabs stand only beyond the
    crest, |x| >= W/2 + 0.5.

The carve band (Andrew, "one skill per park", 17 October 2026; the Dig floor rule, src/combat/floor_rule.gd): the wall
where the wash is steeper than the floor rule's 25.8 degrees is drawn as polished glassy basalt with flow streaks, and its
lower edge carries a pale lip line, so the safe lane reads from the camera. A drift (the miners' level tunnels) has no band:
its walls are timber-lagged and its floor is where the crews work.

Convention (the park family's): +Y up, ride along +Z, origin on the entry lip at the floor centre (registry origin
"entry_lip"), the piece runs z 0 to LENGTH. The wash's own end openings are not drawn: consecutive rows overlap there and
the terrain carries the shape. size is [length, wash depth, wash width], the row's.

Run (memory-capped with prlimit, 12 GiB of address space):
  prlimit <address-space cap> -- blender --background --threads 2 --python-exit-code 1 --python \
    sketches/core-loop/tools/blender/park/sinkhole_tubes.py -- [--out DIR] [--only ID[,ID]] [--count-only]
"""
import argparse
import json
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import tunnels
from tunnels import C, Soup, hash01, make_object, merge, tint

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"

PARK_LARGE = {"tris": 16000, "draws": 2}
DETAIL = {"tris": 1500, "draws": 1}
LIFT = 0.2
BURY = 6.0
FLOOR_NORMAL_Y = 0.9
STATION_M = 2.0

COL = dict(C)
COL.update({
    "polish": common.mix("charcoal", "bone", .30),
    "polish_streak": common.mix("charcoal", "bone", .42),
    "polish_lip": common.mix("bone", "sandstone", .25),
    "lime": common.mix("bone", "sandstone", .22),
    "lime_dark": common.mix("bone", "charcoal", .38),
    "lime_stain": common.mix("bone", "oxide", .30),
    "lime_polish": common.mix("bone", "petrol", .30),
})

RECIPES = {
    "lava_wash": {"length": 54.0, "depth": 4.0, "width": 26.0, "kind": "lava"},
    "lava_wash_short": {"length": 24.0, "depth": 4.0, "width": 26.0, "kind": "lava"},
    "gallery_wash": {"length": 54.0, "depth": 4.0, "width": 26.0, "kind": "gallery"},
    "drift_wash": {"length": 54.0, "depth": 4.0, "width": 24.0, "kind": "drift"},
}


def wash_depth(x, width, depth):
    """park_stamps.gd wash, across the row: the cut below the plain at lateral x (0 at the crest and beyond)."""
    t = abs(2.0 * x / width)
    if t >= 1.0:
        return 0.0
    if t <= 0.4:
        return depth
    w = (t - 0.4) / 0.6
    return depth * (1.0 - w * w)


def wall_slope(x, width, depth):
    """|d depth / dx| of the wash at lateral x."""
    t = abs(2.0 * x / width)
    if t <= 0.4 or t >= 1.0:
        return 0.0
    w = (t - 0.4) / 0.6
    return depth * 2.0 * w / (0.3 * width)


def band_start(width, depth):
    """The lateral distance where the wash wall gets steeper than the floor rule (normal y below FLOOR_NORMAL_Y)."""
    k = math.sqrt(1.0 / (FLOOR_NORMAL_Y * FLOOR_NORMAL_Y) - 1.0)
    w = k * 0.3 * width / (2.0 * depth)
    return min(1.0, 0.4 + 0.6 * w) * width / 2.0


def surface(x, z, spec, lift=LIFT):
    """The drawn point above the wash at lateral x, along z: y is relative to the floor centre (y 0 is the floor)."""
    d = spec["depth"]
    y = d - wash_depth(x, spec["width"], d)
    s = wall_slope(x, spec["width"], d) * (1 if x > 0 else -1)
    n = Vector((-s, 1.0, 0.0)).normalized()
    return Vector((x, y, z)) + n * lift


def stations(length):
    n = max(2, int(round(length / STATION_M)))
    return [length * k / n for k in range(n + 1)]


def band(soup, spec, side, palette):
    """The carve band on one wall: from band_start to 0.3 m under the crest, in lanes across so the streaks run along."""
    half = spec["width"] / 2.0
    x0 = band_start(spec["width"], spec["depth"])
    x1 = half - 0.3
    if x1 - x0 < 0.5:
        return
    lanes = 6
    xs = [x0 + (x1 - x0) * k / lanes for k in range(lanes + 1)]
    zs = stations(spec["length"])
    for li in range(lanes):
        rings = [[surface(side * xs[li], z, spec), surface(side * xs[li + 1], z, spec)] for z in zs]
        soup.strip(rings, lambda r, i, li=li: palette(li, r), "out", lambda r: Vector((0, -50.0, zs[r])), closed=False, smooth=True)
    xa, xb = x0 - 0.18, x0 + 0.18
    rings = [[surface(side * xa, z, spec, LIFT + .02), surface(side * xb, z, spec, LIFT + .02)] for z in zs]
    soup.strip(rings, lambda r, i: COL["polish_lip"] if palette is not drift_band else COL["timber_pale"], "out",
               lambda r: Vector((0, -50.0, zs[r])), closed=False, smooth=True)


def lava_band(lane, r):
    streak = hash01(lane, r // 3, 11) > .62
    return tint(COL["polish_streak"] if streak else COL["polish"], .04, lane * 31 + r)


def gallery_band(lane, r):
    streak = hash01(lane, r // 3, 13) > .58
    return tint(COL["lime_polish"] if streak else COL["lime_dark"], .05, lane * 17 + r)


def drift_band(lane, r):
    return tint(COL["timber"] if lane % 2 == 0 else COL["timber_pale"], .07, lane * 7 + r // 2)


def crest(soup, spec, side, kind):
    """Crust lips beyond the crest: broken blocks along the run, never inside |x| < W/2 + 0.5."""
    half = spec["width"] / 2.0
    d = spec["depth"]
    z = 0.8
    k = 0
    stone = {"lava": "scoria", "gallery": "lime", "drift": "sandstone_wall"}[kind]
    while z < spec["length"] - 0.8:
        seg = 2.2 + hash01(k, side, 21) * 3.2
        gap = 0.3 + hash01(k, side, 22) * 1.4
        h = 0.4 + hash01(k, side, 23) * (1.4 if kind == "lava" else 0.8)
        wdt = 1.2 + hash01(k, side, 24) * 1.8
        x = side * (half + 0.5 + wdt / 2)
        soup.box(Vector((x, d + h / 2 - 0.15, z + seg / 2)), (wdt, h, seg), tint(COL[stone], .12, k * 3 + side),
                 yaw=(hash01(k, side, 25) - .5) * 8, roll=side * (hash01(k, side, 26) - .5) * 10)
        z += seg + gap
        k += 1


def roof_slabs(soup, spec, side, kind):
    """The fallen tube roof's edges: slabs leaning out from the crest, every 9 to 15 m (lava and gallery only)."""
    if kind == "drift":
        return
    half = spec["width"] / 2.0
    d = spec["depth"]
    z = 4.0 + hash01(side, 3, 31) * 4
    k = 0
    stone = "basalt_dark" if kind == "lava" else "lime_stain"
    while z < spec["length"] - 4.0:
        length = 3.0 + hash01(k, side, 32) * 4.0
        tall = 2.0 + hash01(k, side, 33) * 3.0
        x = side * (half + 2.2 + hash01(k, side, 34) * 1.2)
        soup.box(Vector((x, d + tall / 2 - 0.3, z)), (1.2, tall, length), tint(COL[stone], .10, k + side * 5),
                 yaw=(hash01(k, side, 35) - .5) * 14, roll=side * (12 + hash01(k, side, 36) * 14))
        z += 9.0 + hash01(k, side, 37) * 6.0
        k += 1


def timber_sets(soup, spec, side):
    """A drift's timber sets every 6 m: a post on each crest and a collar block, all beyond the crest."""
    half = spec["width"] / 2.0
    d = spec["depth"]
    z = 3.0
    k = 0
    while z < spec["length"] - 1.0:
        soup.box(Vector((side * (half + 0.9), d + 1.6, z)), (0.5, 3.2, 0.5), tint(COL["timber"], .08, k + side))
        soup.box(Vector((side * (half + 0.9), d + 3.35, z)), (1.2, 0.3, 0.7), tint(COL["timber_pale"], .08, k))
        if k % 3 == 1:
            soup.box(Vector((side * (half + 0.62), d + 2.6, z + 0.35)), (0.12, 0.4, 0.22), COL["copper"])
        z += 6.0
        k += 1


def base_mesh(spec):
    soup = Soup()
    palette = {"lava": lava_band, "gallery": gallery_band, "drift": drift_band}[spec["kind"]]
    for side in (-1, 1):
        band(soup, spec, side, palette)
        crest(soup, spec, side, spec["kind"])
    return soup


def col_mesh(spec):
    """Two small blocks BURY m down, one at each authored end: they give the seat fit its ends and nothing to hit. A strip
    along the run poked out of the floor wherever the tube floor sags under the chord between its ends (dead stops on
    the floor line, 17 October 2026)."""
    soup = Soup()
    for z in (0.1, spec["length"] - 0.1):
        soup.box(Vector((0, -BURY, z)), (0.2, 0.2, 0.2), COL["sand"])
    return soup


def shell1(spec):
    soup = Soup()
    for side in (-1, 1):
        if spec["kind"] == "drift":
            timber_sets(soup, spec, side)
        else:
            roof_slabs(soup, spec, side, spec["kind"])
    return soup


def shell2(spec):
    """Small things only seen up close: scoria spatter on the crest (lava), drip stains (gallery), lamp brackets (drift)."""
    soup = Soup()
    half = spec["width"] / 2.0
    d = spec["depth"]
    for k in range(int(spec["length"] / 3)):
        side = -1 if k % 2 else 1
        z = 1.5 + k * 3 + hash01(k, 1, 41)
        if spec["kind"] == "lava":
            sz = .3 + hash01(k, 2, 42) * .5
            soup.box(Vector((side * (half + 0.6 + hash01(k, 3, 43) * 2.5), d + sz * .3, z)), (sz, sz * .6, sz),
                     tint(COL["basalt"], .2, k), yaw=hash01(k, 4, 44) * 90)
        elif spec["kind"] == "gallery":
            soup.cone(Vector((side * (half + 1.2 + hash01(k, 5, 45) * 2.0), d + 2.4, z)), .25, 1.2, 6, COL["lime_stain"], down=True)
        elif k % 3 == 0:
            soup.box(Vector((side * (half + 0.62), d + 2.0, z)), (0.08, 0.5, 0.08), COL["copper"])
    return soup


def build_glb(rid, out_dir, count_only):
    spec = dict(RECIPES[rid])
    render = base_mesh(spec)
    col = col_mesh(spec)
    shells = [shell1(spec), shell2(spec)]
    counts = {"render": len(render.tris()), "col": len(col.tris()), "shell1": len(shells[0].tris()), "shell2": len(shells[1].tris())}
    if count_only:
        print("SINKHOLE_TUBES_COUNT", rid, json.dumps(counts, sort_keys=True))
        return counts
    rows = {}
    common.reset()
    root = common.empty(rid + "_root")
    make_object(rid, render, root, True)
    make_object(rid + "-col", col, root, False)
    exit_pos = Vector((0.0, 0.0, spec["length"]))
    sock = common.empty("socket_exit", tunnels.bpy_xyz(exit_pos), root)
    path = Path(out_dir) / (rid + ".glb")
    common.export(root, str(path))
    rows[rid] = tunnels.check_glb(path, rid, counts, PARK_LARGE, 2, [rid, rid + "-col", "socket_exit"], exit_pos, 0.0)
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
