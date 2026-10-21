"""The Highdraft islands' ride-surface pieces (park_islands placeholder burn-down): five GLBs drawn over rows whose
stamped ground is the whole collider, so park_recipes.gd places them as OVER_GREYBOX recipes (the row's greybox node, seat
and ride sensor, no box collider because the stamp replaces it) and only the view is new. Nothing here has a -col mesh;
the baked ground (assets/park/park_islands/ground.bin) stays the only thing the ball rolls on.

  isle_ride_slickrock   slickrock_run  (flow_line, ramp 170 x 36 x 1600): the central lane, |x| <= 20, z -598..-432.
  isle_ride_fan         fan_band       (flow_line, ramp 250 x 48 x 1600): the east shoulder, x 80..140, z -348..-102,
                        clear of twin_fins, whose fin_rim_collapse swaps the ground inside x +-70, z -340..-100.
  isle_ride_net_carve   net_carve      (half_pipe, ramp 282 x 24 x 1600): the lane below the net posts (|x| <= 40, z
                        286..398) and the east shoulder (x 66..100, z 124..284), clear of liner_net_post_run and net_bowl.
  isle_ride_apron       isle_apron     (terrace 354 x 6 x 1600): the east and west verges, |x| 165..193, z 416..654 and
                        746..758, clear of the bowl scatter, the knuckles, the keel net decks and liner_cloud_wash_east.
  isle_ride_wash_west   cloud_wash_west (half_pipe, plateau 300 x 0.01 x 30): the wash floor, x -224..-196, z 112..232
                        and 288..376, with a gap round isle_shed's 20 m crater (the impact swaps the ground there) and
                        cloud_cannon_west's mouth.

fin_chute stays greybox: it lies wholly inside twin_fins' footprint, where fin_rim_collapse drops the ground 8 m and
hides only Park_twin_fins, so a drawn sheet there would hang in the air after the collapse (ghost solid, #183).

Each piece is a sheet of the baked ground: one vertex per 2 m ground node, triangulated on the b-c diagonal the game's
Terrain._grid_height uses, so every vertex sits OFF above the surface the ball rolls on and the sheet is exact between
vertices. y offset per vertex 0.04 to 0.08 m (a soft hand-laid relief, never over FLUSH 0.12, never below the ground);
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
import common  # noqa: E402

SKETCH = common.SKETCH
MODELS = os.path.join(SKETCH, "assets", "models", "park")
CLASSES = json.load(open(os.path.join(SKETCH, "assets", "asset_budgets.json")))["classes"]
PARK = json.load(open(os.path.join(SKETCH, "src", "world", "park", "park_islands.json")))
GROUND_BIN = os.path.join(SKETCH, "assets", "park", "park_islands", "ground.bin")
SLOT = "enamel"
N, STEP, HALF = 801, 2.0, 800.0
FLUSH = 0.12                # the most any part may stand over the ground (landmarks.py; ghost solid, #183)
SINK = 0.03                 # and the most it may sink under it
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

# id: row, world windows (x0, x1, z0, z1) on the 2 m ground nodes, palette (flat tones, cliff tones, stroke), seed
PIECES = {
    "isle_ride_slickrock": {"row": "slickrock_run", "raise": "half", "windows": [(-20, 20, -598, -432)],
                            "flat": (SAND, SAND_LT, SAND_DK), "cliff": (VARNISH, VARNISH_LT), "stroke": BONE, "seed": 4101},
    "isle_ride_fan": {"row": "fan_band", "raise": "half", "windows": [(80, 140, -348, -102)],
                      "flat": (OCHRE, SAND, OCHRE_DK), "cliff": (VARNISH, OCHRE_DK), "stroke": BONE, "seed": 4111},
    "isle_ride_net_carve": {"row": "net_carve", "raise": "half", "windows": [(-40, 40, 286, 398), (66, 100, 124, 284)],
                            "flat": (STONE, SILT, STONE_DK), "cliff": (VARNISH, STONE_DK), "stroke": BONE, "seed": 4121},
    "isle_ride_apron": {"row": "isle_apron", "raise": "none",
                        "windows": [(165, 193, 416, 654), (165, 193, 746, 758), (-193, -165, 416, 654), (-193, -165, 746, 758)],
                        "flat": (STONE, SILT, SAGE), "cliff": (STONE_DK, VARNISH), "stroke": BONE, "seed": 4131},
    "isle_ride_wash_west": {"row": "cloud_wash_west", "raise": "full", "windows": [(-224, -196, 112, 232), (-224, -196, 288, 376)],
                            "flat": (SILT, SAND, STONE), "cliff": (STONE_DK, VARNISH), "stroke": BONE, "seed": 4141},
}
BUDGET_CLASS = "landform"


# ------------------------------------------------------------------------------------------------------ the ground
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
    elif spec["raise"] == "full":      # a plateau stamp raises its whole (here 0.01 m) height
        y -= float(row["size"][1])
    return y


def hh(i, j, k=0):
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) % 1009 / 1009.0


def tone(hex_color, other, t):
    a, b = common.srgb(hex_color), common.srgb(other)
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


# ------------------------------------------------------------------------------------------------------ events
def keep_out():
    """The ground the islands' events change, as (x0, x1, z0, z1, why): a collapse or ground swap's whole site footprint,
    an impact's strike box, and a margin of MARGIN round each. Nothing of any piece may stand inside them."""
    margin = 8.0
    sites = {r["id"]: r for r in PARK["park_rows"]}
    out = []
    for ev in PARK["event_rows"]:
        site = sites[ev["site"]]
        eff = ev["effect"]
        if "strike_m" in eff:
            hx = hz = float(eff["strike_m"])
        elif ev["kind"] == "collapse" or eff.get("swap"):
            hx, hz = site["size"][2] / 2.0, site["size"][0] / 2.0
        else:
            continue
        x, z = float(site["at"][0]), float(site["at"][1])
        out.append((x - hx - margin, x + hx + margin, z - hz - margin, z + hz + margin, ev["id"]))
    # cloud_cannon_west's mouth (a launcher on cloud_wash_west's far end, radius 4)
    for row in PARK.get("contraption_rows", []):
        if row.get("site") == "cloud_wash_west" and "at" in row:
            x, z, r = float(row["at"][0]), float(row["at"][1]), float(row.get("radius", 4.0)) + 4.0
            out.append((x - r, x + r, z - r, z + r, row["id"]))
    return out


def inside(x, z, box):
    return box[0] < x < box[1] and box[2] < z < box[3]


# ------------------------------------------------------------------------------------------------------ build
def cell_colour(spec, wx, wz, steep, i, j):
    if steep:
        return tone(spec["cliff"][int(hh(i, j, 1) * len(spec["cliff"]))], spec["cliff"][0], 0.35 * hh(i, j, 2))
    h = hh(i, j, 3)
    if h < 0.06:
        return tone(spec["stroke"], spec["flat"][0], 0.35 + 0.3 * hh(i, j, 4))
    band = (int((wz + 4000.0) / 6.0) + (i // 5)) % 3        # strata: three tones in 6 m runs along z
    return tone(spec["flat"][band], spec["flat"][(band + 1) % 3], 0.5 * hh(i, j, 5))


def build_mesh(rid, spec):
    """(verts [(x, y, z) Godot local], tris [(a, b, c)], colours per triangle) for the piece's windows."""
    ny = node_y(spec)
    ax, az = row_of(spec["row"])["at"]
    ev = keep_out()
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
                    raise SystemExit("%s: cell (%g, %g) stands in %s's ground" % (rid, wx0, wz0, [b[4] for b in ev if inside(wx0, wz0, b)]))
                hs = [g[iz, ix], g[iz, ix + 1], g[iz + 1, ix], g[iz + 1, ix + 1]]
                steep = max(hs) - min(hs) > 1.2
                colour = cell_colour(spec, wx0, wz0, steep, ix, iz)
                a, b, c, d = vert(ix, iz), vert(ix + 1, iz), vert(ix, iz + 1), vert(ix + 1, iz + 1)
                # the b-c diagonal, each triangle counter-clockwise seen from above in Godot axes (x right, z toward us)
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
    assert max(off) <= FLUSH and min(off) >= -SINK, (rid, min(off), max(off))
    if count_only:
        return
    root = common.empty(rid + "_root")
    obj = make_object(rid, verts, tris, cols)
    obj.parent = root
    path = os.path.join(out_dir, rid + ".glb")
    common.export(root, path)
    print("ISLE_RIDE_EXPORT", rid, json.dumps({"file": os.path.basename(path), "tris": len(tris),
                                               "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()}))


# ------------------------------------------------------------------------------------------------------ check
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
    ev = keep_out()
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
        # winding seen from above in Godot axes; the exporter keeps it, a downward face would be culled
        worst_down = min(worst_down, up)
        for w in ((1 / 3, 1 / 3, 1 / 3), (0.5, 0.5, 0.0), (0.0, 0.5, 0.5), (0.5, 0.0, 0.5), (0.8, 0.1, 0.1), (0.1, 0.8, 0.1), (0.1, 0.1, 0.8)):
            measure(*[sum(w[m] * p[m][c] for m in range(3)) for c in range(3)])
    if worst_down < -1e-6:
        fails.append("%s: a triangle faces down" % rid)
    ok = hi <= FLUSH + 1e-4 and lo >= -SINK - 1e-4
    report = {"verts": len(pos), "tris": len(ids) // 3, "max_off": round(hi, 4), "min_off": round(lo, 4)}
    print("ISLE_RIDE_CHECK", rid, json.dumps(report), "PASS" if ok and not fails else "FAIL")
    if not ok:
        fails.append("%s: offset %.4f .. %.4f outside %.2f .. %.2f" % (rid, lo, hi, -SINK, FLUSH))
    return fails, report


def registry():
    out = []
    for rid, spec in PIECES.items():
        out.append({
            "id": rid, "path": "res://assets/models/park/%s.glb" % rid, "class": BUDGET_CLASS, "origin": "centre", "ships": True,
            "loader": "src/world/park/park_recipes.gd (place_over_greybox: drawn over its row's stamped ground, which stays the only collider; no -col mesh)",
            "provenance": {"recipe": "tools/blender/park/isle_ride_pieces.py",
                           "notes": "%s's flush ground sheet, conformed to the park_islands bake (park_islands placeholder burn-down); every vertex 0.04 to 0.08 m over ground.bin, none inside an event's footprint; built by this script, no external mesh" % spec["row"]},
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
