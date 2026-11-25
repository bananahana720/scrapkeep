"""The Highdraft islands' ride-surface piece (park_islands placeholder burn-down): one GLB drawn over a row whose stamped
ground is the whole collider, so park_recipes.gd places it as an OVER_GREYBOX recipe (the row's greybox node, seat and
ride sensor, no box collider because the stamp replaces it) and only the view is new. It has no -col mesh; the baked
ground (assets/park/park_islands/ground.bin) stays the only thing the ball rolls on.

  isle_ride_wash_west   cloud_wash_west (half_pipe, plateau 300 x 0.01 x 30): the whole wash footprint, x -226..-194, z
                        110..410, less a hole round cloud_cannon_west's mouth. The sheet lies inside isle_shed's impact
                        overlay (west_wing, x -270..-150, z 100..420: the game builds it over the whole site footprint,
                        natural.gd:146-150, event_ground.gd:477-491), which only raises ground (event_ground.gd:236), so
                        where the crater rim rises the sheet is buried under the raised ground and never floats.
  isle_ride_fin_chute   fin_chute (half_pipe, plateau 240 x 0.01 x 56): the whole chute footprint, x -28..28, z -340..-100,
                        wholly inside twin_fins, where fin_rim_collapse drops the ground 8 m. The row declares
                        "hide_on": "fin_rim_collapse", so the collapse parks Park_fin_chute down with Park_twin_fins
                        (event_ground.gd hidden_rows, apply_swap) and the sheet never hangs over the dropped ground
                        (ghost solid, #183); it comes home on revert. That event is the one keep-out the piece skips.

Not dressed, and why:
  slickrock_run, fan_band, net_carve, isle_apron   full-rect stamped bands, 1,600 m across the whole play rect. At the
               bake's 2 m cells a full sheet is 136k to 283k triangles against the landform class's 8,000, so no
               OVER_GREYBOX piece can honestly dress them (a 2 to 4 % window would only clear the placeholder gate). They
               stay greybox pending a coordinator ruling (extending the "Edges are ground" ruling to full-rect bands).

Each piece is a sheet of the baked ground: one vertex per 2 m ground node, triangulated on the b-c diagonal the game's
Terrain._grid_height uses, so every vertex sits OFF above the surface the ball rolls on and the sheet is exact between
vertices. y offset per vertex 0.04 to 0.08 m (a soft hand-laid relief: at least MIN_LIFT 0.03 so it never z-fights, at most FLUSH 0.12);
colours by cell: pale slickrock or ochre on the flats, a darker varnished band on the cliff cells, a few bone guide strokes.
No texture, no light, no mesh from any other source. One "enamel" slot, one draw, landform class.

Convention: Godot metres, +Y up; the origin is the row node (the footprint centre on the ground the row stands on:
ground(at) less the stamp's own raise: size[1] / 2 for a ramp, size[1] for a plateau, none for a terrace), yaw 0, no scale.

  (ulimit -v 6000000; nice -n 10 scripts/cloud/blender -b -t 2 -P tools/blender/park/isle_ride_pieces.py -- \\
      [--out-dir DIR] [--recipe ID] [--count-only] [--check] [--registry])
  --check   rebuild nothing: read the GLBs in --out-dir and measure each against ground.bin and the events' footprints.
"""
import argparse
import hashlib
import json
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import common

SKETCH = common.SKETCH
MODELS = os.path.join(SKETCH, "assets", "models", "park")
CLASSES = json.load(open(os.path.join(SKETCH, "assets", "asset_budgets.json")))["classes"]
PARK = json.load(open(os.path.join(SKETCH, "src", "world", "park", "park_islands.json")))
GROUND_BIN = os.path.join(SKETCH, "assets", "park", "park_islands", "ground.bin")
SLOT = "enamel"
N, STEP, HALF = 801, 2.0, 800.0
FLUSH = 0.12
MIN_LIFT = 0.03
OFF_LO, OFF_HI = 0.04, 0.08

SAND = "d8b484"
SAND_LT = "e6c898"
SAND_DK = "c39a6c"
OCHRE = "cc9560"
OCHRE_DK = "b27646"
VARNISH = "7e5642"
VARNISH_LT = "98694c"
STONE = "b7a98f"
STONE_DK = "9d8f78"
SILT = "cdb893"
BONE = "d9cdae"
SAGE = "9aa273"

PIECES = {
    "isle_ride_wash_west": {"row": "cloud_wash_west", "raise": "full", "windows": [(-226, -194, 110, 410)],
                            "flat": (SILT, SAND, STONE), "cliff": (STONE_DK, VARNISH), "stroke": BONE, "seed": 4141},
    "isle_ride_fin_chute": {"row": "fin_chute", "raise": "full", "windows": [(-28, 28, -340, -100)], "hide_on": "fin_rim_collapse",
                            "flat": (OCHRE, SAND_LT, SAND_DK), "cliff": (VARNISH, VARNISH_LT), "stroke": BONE, "seed": 5252},
}
BUDGET_CLASS = "landform"


_G = []


def ground():
    """ground.bin as a 801 x 801 float array (rows z, columns x, 2 m apart over -800..800): Godot's compressed GCPF file."""
    if not _G:
        import numpy
        import zstandard
        raw = open(GROUND_BIN, "rb").read()
        assert raw[:4] == b"GCPF", raw[:4]
        mode, block, total = struct.unpack_from("<3I", raw, 4)
        assert mode == 2, mode
        count = -(-total // block)
        sizes = struct.unpack_from("<%dI" % count, raw, 16)
        pos = 16 + 4 * count
        out = bytearray()
        dec = zstandard.ZstdDecompressor()
        for size in sizes:
            out += dec.decompress(raw[pos:pos + size], max_output_size=block)
            pos += size
        assert len(out) == total == N * N * 4, (len(out), total)
        _G.append(numpy.frombuffer(bytes(out), dtype="<f4").reshape(N, N).astype("float64"))
    return _G[0]


def node(x, z):
    return float(ground()[int(round((z + HALF) / STEP)), int(round((x + HALF) / STEP))])


def ground_db(x, z):
    """Terrain._grid_height: the 2 m cell split on its b-c diagonal (a, d the corners off it)."""
    g = ground()
    fx = min(max((x + HALF) / STEP, 0.0), N - 1 - 0.001)
    fz = min(max((z + HALF) / STEP, 0.0), N - 1 - 0.001)
    i, j = int(fx), int(fz)
    u, v = fx - i, fz - j
    a, b, c, d = float(g[j, i]), float(g[j, i + 1]), float(g[j + 1, i]), float(g[j + 1, i + 1])
    if u + v <= 1.0:
        return a + (b - a) * u + (c - a) * v
    return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


def row_of(rid):
    return next(r for r in PARK["park_rows"] if r["id"] == rid)


def node_y(spec):
    """The row node's y as place_row seats it: the ground at `at`, less the stamp's own raise (half of a ramp's height)."""
    row = row_of(spec["row"])
    y = ground_db(float(row["at"][0]), float(row["at"][1]))
    if spec["raise"] == "half":
        y -= float(row["size"][1]) / 2.0
    elif spec["raise"] == "full":
        y -= float(row["size"][1])
    return y


def hh(i, j, k=0):
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) % 1009 / 1009.0


def tone(hex_color, other, t):
    a, b = common.srgb(hex_color), common.srgb(other)
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def footprint(site):
    """The box the game treats as a site: ParkMap.footprint_half_extents (x: size[2] / 2, z: size[0] / 2) at `at`."""
    x, z = float(site["at"][0]), float(site["at"][1])
    hx, hz = site["size"][2] / 2.0, site["size"][0] / 2.0
    return (x - hx, x + hx, z - hz, z + hz)


def keep_out(spec):
    """The ground the islands' events lower, swap or open, as (x0, x1, z0, z1, why), a margin of 8 m round each. No vertex of
    any piece may stand inside them. A collapse or other ground swap uses its whole site footprint (as natural.gd and
    event_ground.gd do) and cloud_cannon_west's mouth uses its radius. An impact is NOT here: its overlay only raises ground
    (event_ground.gd:236, `y += maxf(0.0, offset)`; the crater profile is clamped at zero), so a sheet inside it is buried
    where the rim rises, never left floating. raise_only() names the overlaps the sheet may have. The piece's own hide_on
    event is skipped too: the row leaves with that swap, so the sheet is never seen over the ground it lowers."""
    margin = 8.0
    sites = {r["id"]: r for r in PARK["park_rows"]}
    out = []
    for ev in PARK["event_rows"]:
        if ev["kind"] == "impact" or not (ev["kind"] == "collapse" or ev["effect"].get("swap")):
            continue
        if ev["id"] == spec.get("hide_on"):
            continue
        x0, x1, z0, z1 = footprint(sites[ev["site"]])
        out.append((x0 - margin, x1 + margin, z0 - margin, z1 + margin, ev["id"]))
    for row in PARK.get("contraption_rows", []):
        if row.get("site") == spec["row"] and "at" in row:
            x, z, r = float(row["at"][0]), float(row["at"][1]), float(row.get("radius", 4.0)) + 4.0
            out.append((x - r, x + r, z - r, z + r, row["id"]))
    return out


def raise_only(spec):
    """Assert every event whose real footprint overlaps the sheet is a raise-only impact overlay (isle_shed on west_wing,
    event_ground.gd:236) or the piece's own hide_on event, and that the row really declares that hide_on. Return the ids.
    Any other overlapping event, one that lowers or swaps ground, fails the build."""
    window_boxes = spec["windows"]
    sites = {r["id"]: r for r in PARK["park_rows"]}
    hits = []
    for ev in PARK["event_rows"]:
        if ev["site"] not in sites:
            continue
        x0, x1, z0, z1 = footprint(sites[ev["site"]])
        for (a0, a1, b0, b1) in window_boxes:
            if x0 < a1 and a0 < x1 and z0 < b1 and b0 < z1:
                hits.append(ev)
                break
    ids = [e["id"] for e in hits]
    hide = spec.get("hide_on")
    if hide:
        assert row_of(spec["row"]).get("hide_on") == hide, (spec["row"], "does not declare hide_on", hide)
    bad = [e["id"] for e in hits if e["kind"] != "impact" and e["id"] != hide]
    assert ids and not bad, ("the sheet overlaps events that are neither a raise-only impact nor its hide_on", ids)
    return ids


def inside(x, z, box):
    return box[0] < x < box[1] and box[2] < z < box[3]


def cell_colour(spec, wx, wz, steep, i, j):
    if steep:
        return tone(spec["cliff"][int(hh(i, j, 1) * len(spec["cliff"]))], spec["cliff"][0], 0.35 * hh(i, j, 2))
    h = hh(i, j, 3)
    if h < 0.06:
        return tone(spec["stroke"], spec["flat"][0], 0.35 + 0.3 * hh(i, j, 4))
    band = (int((wz + 4000.0) / 6.0) + (i // 5)) % 3
    return tone(spec["flat"][band], spec["flat"][(band + 1) % 3], 0.5 * hh(i, j, 5))


def build_mesh(rid, spec):
    """(verts [(x, y, z) Godot local], tris [(a, b, c)], colours per triangle) for the piece's windows."""
    ny = node_y(spec)
    ax, az = row_of(spec["row"])["at"]
    ev = keep_out(spec)
    raise_only(spec)
    verts, tris, cols, index = [], [], [], {}

    def vert(ix, iz):
        key = (ix, iz)
        if key not in index:
            wx, wz = ix * STEP - HALF, iz * STEP - HALF
            off = OFF_LO + (OFF_HI - OFF_LO) * hh(ix, iz, spec["seed"] % 997)
            index[key] = len(verts)
            verts.append((wx - ax, float(ground()[iz, ix]) + off - ny, wz - az))
        return index[key]

    g = ground()
    for (x0, x1, z0, z1) in spec["windows"]:
        for iz in range(int((z0 + HALF) / STEP), int((z1 + HALF) / STEP)):
            for ix in range(int((x0 + HALF) / STEP), int((x1 + HALF) / STEP)):
                wx0, wz0 = ix * STEP - HALF, iz * STEP - HALF
                if any(inside(wx0 + dx, wz0 + dz, b) for b in ev for dx in (0.0, STEP) for dz in (0.0, STEP)):
                    continue
                hs = [g[iz, ix], g[iz, ix + 1], g[iz + 1, ix], g[iz + 1, ix + 1]]
                steep = max(hs) - min(hs) > 1.2
                colour = cell_colour(spec, wx0, wz0, steep, ix, iz)
                a, b, c, d = vert(ix, iz), vert(ix + 1, iz), vert(ix, iz + 1), vert(ix + 1, iz + 1)
                tris.append((a, c, b))
                tris.append((d, b, c))
                cols.append(colour)
                cols.append(colour)
    return verts, tris, cols


def make_object(rid, verts, tris, cols):
    import bpy
    mesh = bpy.data.meshes.new(rid)
    mesh.from_pydata([(x, -z, y) for x, y, z in verts], [], [tuple(t) for t in tris])
    mesh.update()
    attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for poly, colour in zip(mesh.polygons, cols):
        poly.use_smooth = True
        for li in poly.loop_indices:
            attr.data[li].color = (*common.to_linear(colour), 1.0)
    mesh.color_attributes.active_color = attr
    mesh.materials.append(common.material(SLOT))
    obj = bpy.data.objects.new(rid, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build(rid, out_dir, count_only):
    spec = PIECES[rid]
    common.reset()
    common.SLOTS[SLOT] = {"vc": True, "rough": 0.87}
    import polish
    polish.enable(detail=1, bevel=0.0, bake_slots=(SLOT,))
    verts, tris, cols = build_mesh(rid, spec)
    cap = CLASSES[BUDGET_CLASS]
    print("ISLE_RIDE_COUNT", rid, json.dumps({"tris": len(tris), "verts": len(verts), "class": BUDGET_CLASS, "cap": cap["tris"]}))
    assert len(tris) <= cap["tris"] and len(verts) <= cap["verts"], (rid, len(tris), len(verts), cap)
    off = [v[1] + node_y(spec) - ground_db(v[0] + row_of(spec["row"])["at"][0], v[2] + row_of(spec["row"])["at"][1]) for v in verts]
    assert max(off) <= FLUSH and min(off) >= MIN_LIFT, (rid, min(off), max(off))
    if count_only:
        return
    root = common.empty(rid + "_root")
    obj = make_object(rid, verts, tris, cols)
    obj.parent = root
    path = os.path.join(out_dir, rid + ".glb")
    common.export(root, path)
    print("ISLE_RIDE_EXPORT", rid, json.dumps({"file": os.path.basename(path), "tris": len(tris),
                                               "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()}))


def read_glb(path):
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length]), data[20 + length + 8:]


def accessor(doc, binary, idx, fmt, width):
    acc = doc["accessors"][idx]
    view = doc["bufferViews"][acc["bufferView"]]
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", struct.calcsize(fmt))
    return [struct.unpack_from(fmt, binary, base + i * stride) for i in range(acc["count"])]


def check(rid, out_dir):
    """Measure the GLB's surface against ground.bin (the collider) and the events' footprints. Returns (fails, report)."""
    spec = PIECES[rid]
    ax, az = row_of(spec["row"])["at"]
    ny = node_y(spec)
    doc, binary = read_glb(os.path.join(out_dir, rid + ".glb"))
    fails = []
    if any("-col" in n.get("name", "") for n in doc["nodes"]):
        fails.append("%s: has a -col node" % rid)
    meshes = [n for n in doc["nodes"] if "mesh" in n]
    if len(meshes) != 1 or len(doc["meshes"][meshes[0]["mesh"]]["primitives"]) != 1:
        fails.append("%s: not one mesh with one primitive (one draw)" % rid)
    prim = doc["meshes"][meshes[0]["mesh"]]["primitives"][0]
    pos = accessor(doc, binary, prim["attributes"]["POSITION"], "<3f", 3)
    idx_acc = doc["accessors"][prim["indices"]]
    fmt = {5121: "<B", 5123: "<H", 5125: "<I"}[idx_acc["componentType"]]
    ids = [t[0] for t in accessor(doc, binary, prim["indices"], fmt, 1)]
    ev = keep_out(spec)
    raise_only(spec)
    lo, hi = math.inf, -math.inf
    worst_down = 0.0

    def measure(x, y, z):
        nonlocal lo, hi
        off = y + ny - ground_db(x + ax, z + az)
        lo, hi = min(lo, off), max(hi, off)

    for x, y, z in pos:
        measure(x, y, z)
        for b in ev:
            if inside(x + ax, z + az, b):
                fails.append("%s: vertex (%.1f, %.1f) stands in %s's ground" % (rid, x + ax, z + az, b[4]))
                break
    for k in range(0, len(ids), 3):
        p = [pos[ids[k + m]] for m in range(3)]
        up = (p[1][2] - p[0][2]) * (p[2][0] - p[0][0]) - (p[1][0] - p[0][0]) * (p[2][2] - p[0][2])
        worst_down = min(worst_down, up)
        for w in ((1 / 3, 1 / 3, 1 / 3), (0.5, 0.5, 0.0), (0.0, 0.5, 0.5), (0.5, 0.0, 0.5), (0.8, 0.1, 0.1), (0.1, 0.8, 0.1), (0.1, 0.1, 0.8)):
            measure(*[sum(w[m] * p[m][c] for m in range(3)) for c in range(3)])
    if worst_down < -1e-6:
        fails.append("%s: a triangle faces down" % rid)
    ok = hi <= FLUSH + 1e-4 and lo >= MIN_LIFT - 1e-4
    report = {"verts": len(pos), "tris": len(ids) // 3, "max_off": round(hi, 4), "min_off": round(lo, 4)}
    print("ISLE_RIDE_CHECK", rid, json.dumps(report), "PASS" if ok and not fails else "FAIL")
    if not ok:
        fails.append("%s: offset %.4f .. %.4f outside %.2f .. %.2f" % (rid, lo, hi, MIN_LIFT, FLUSH))
    return fails, report


NOTES = {
    "isle_ride_wash_west": "cloud_wash_west's flush ground sheet, conformed to the park_islands bake (park_islands placeholder burn-down); every vertex 0.04 to 0.08 m over ground.bin; none inside a collapse or swap footprint or the cannon mouth; the sheet lies inside isle_shed's impact overlay, which only raises ground; built by this script, no external mesh",
    "isle_ride_fin_chute": "fin_chute's flush ground sheet, conformed to the park_islands bake (park_islands placeholder burn-down); every vertex 0.04 to 0.08 m over ground.bin; the row hides on fin_rim_collapse, so the sheet parks down with twin_fins when the fins collapse and never hangs over the dropped ground; built by this script, no external mesh",
}


def registry():
    out = []
    for rid, spec in PIECES.items():
        out.append({
            "id": rid, "path": "res://assets/models/park/%s.glb" % rid, "class": BUDGET_CLASS, "origin": "centre", "ships": True,
            "loader": "src/world/park/park_recipes.gd (place_over_greybox: drawn over its row's stamped ground, which stays the only collider; no -col mesh)",
            "provenance": {"recipe": "tools/blender/park/isle_ride_pieces.py",
                           "notes": NOTES[rid]},
        })
    return {"assets": out}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=MODELS)
    parser.add_argument("--recipe", action="append", choices=sorted(PIECES))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--registry", action="store_true")
    args = parser.parse_args(argv)
    if args.registry:
        print(json.dumps(registry(), indent=1))
        return
    failed = []
    for rid in args.recipe or sorted(PIECES):
        if args.check:
            failed += check(rid, args.out_dir)[0]
        else:
            build(rid, args.out_dir, args.count_only)
    if failed:
        print("ISLE_RIDE_FAIL", json.dumps(failed))
        raise SystemExit(1)


main()
