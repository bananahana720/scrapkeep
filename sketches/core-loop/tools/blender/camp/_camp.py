"""Shared helpers for the camp hub kit (wave 19 camp, storyboard 7 "hub ring", design-v3/park/storyboards/DECISIONS.md on
PR #14): one enamel draw with COLOR_0 vertex colour per GLB, an optional "<id>-col-col" trimesh node (the Godot importer
strips one "-col", so the imported node is "<id>-col", the name park_recipes.gd looks for), named socket empties, the class
budgets from assets/asset_budgets.json, and one CAMP_EXPORT row per GLB with its sha256 for the determinism log.

Convention for every camp recipe (kept in each header): metres at game scale, Godot +Y up, origin on the ground at the
piece's footprint centre unless the header says otherwise. Local +Z faces the plaza, the side the player rolls in from; the
layout's yaw turns it. The player is a 1 m ball that grows with heft, so walk-up parts are ball-sized, not person-sized.

Palette: the game palette (common.HEX) and the park dam-era tones (_park.TONES). Copper #b77843 for machinery, never brass
(brass is the requisition tag). Mint means "your verb works here" (LEGIBILITY.md), so mint marks only things the player uses:
the launch pad, the shortcut, station thresholds, the skee-ball lane and the trial start. Amber pays (scores, medals). Hazard
red stays off the camp: nothing here hurts. Pilot class colours (class_def.gd) mark each locker.

The camp is between runs only; nothing here is a combat surface. Lights are runtime work: a recipe places light_* empties
where a lamp's bulb is, and the bulb itself is a bright vertex colour.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "park" / "contraptions"))
import _park as pk
from _park import kit, common

SKETCH = kit.SKETCH
MODELS = SKETCH / "assets/models/camp"
CLASSES = json.loads((SKETCH / "assets/asset_budgets.json").read_text())["classes"]
SLOT = "enamel"
COL_NODE = "%s-col-col"

T = dict(pk.TONES)
T.update({
    "mint": common.HEX["mint"],
    "mint_dk": "5fb39c",
    "amber": common.HEX["amber"],
    "petrol": common.HEX["petrol"],
    "petrol_dk": "2a4442",
    "sandstone": common.HEX["sandstone"],
    "plaza": "dcd0b4",
    "plaza_dk": "b8a580",
    "canvas": "c9b48a",
    "canvas_dk": "a28c63",
    "timber": "6d4a33",
    "timber_lt": "8c6644",
    "felt": "4f6b52",
    "glass_lt": "e8f6ef",
    "ancient": common.HEX["ancient"],
    "ledger": "e6d9b8",
    "brass": common.HEX["brass"],
})

PILOTS = [("sable", "mint", "ring"), ("rivet", "copper", "chevron"), ("kest", "amber", "burst"),
          ("tarn", "oxide", "cross"), ("tally", "ledger", "square"), ("remembered_cannon", "ancient", "lane")]


def around(n, start=0.0):
    return pk.around(n, start)


def obox(s, size, center, color, yaw=0.0, pitch=0.0, roll=0.0):
    """A box of size (x, y, z) turned by yaw about +Y, then pitch about local X, then roll about local Z (radians)."""
    hx, hy, hz = (v / 2 for v in size)
    m = Matrix.Rotation(yaw, 3, "Y") @ Matrix.Rotation(pitch, 3, "X") @ Matrix.Rotation(roll, 3, "Z")
    c = Vector(center)
    pts = [tuple(c + m @ Vector((a * hx, b * hy, d * hz)))
           for a, b, d in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]]
    s.add(pts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color)


def wedge(s, w, l, h0, h1, center, color, yaw=0.0):
    """A ramp block: w across X, l along Z, top rising from h0 at -Z/2 to h1 at +Z/2, bottom at center.y."""
    cx, cy, cz = center
    ca, sa = math.cos(yaw), math.sin(yaw)

    def p(x, y, z):
        return (cx + x * ca + z * sa, cy + y, cz - x * sa + z * ca)

    pts = [p(-w / 2, 0, -l / 2), p(w / 2, 0, -l / 2), p(w / 2, 0, l / 2), p(-w / 2, 0, l / 2),
           p(-w / 2, h0, -l / 2), p(w / 2, h0, -l / 2), p(w / 2, h1, l / 2), p(-w / 2, h1, l / 2)]
    s.add(pts, [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], color)


def disc_y(s, r0, r1, y0, y1, n, color, at=(0.0, 0.0), arc=None):
    """A flat drum (r0 = 0) or annulus about +Y, from y0 to y1, centred at (x, z) = at."""
    if r0 <= 0.0 and arc is None:
        pk.frustum(s, r1, r1, y0, y1, n, color, at=at)
    else:
        pk.ring_y(s, max(r0, 0.0), r1, y0, y1, n, color, at=at, arc=arc)


def lamp(s, x, y, z, r, color="glass_lt"):
    """A small lit bulb: an 8-sided double cone, so it reads round from any side at low cost."""
    pk.tube(s, (x, y - r, z), (x, y, z), 0.0001, r, 8, T[color] if color in T else color, caps=(False, True))
    pk.tube(s, (x, y, z), (x, y + r, z), r, 0.0001, 8, T[color] if color in T else color, caps=(True, False))


def tone(name):
    return T.get(name, name)


def jitter_tone(name, k, amount=0.06):
    """A fixed brightness wobble per index, so long runs of planks or plates do not read as one flat colour."""
    base = common.srgb(tone(name))
    g = 1.0 + amount * (((k * 7919) % 13) / 6.0 - 1.0)
    return "%02x%02x%02x" % tuple(max(0, min(255, int(round(c * g * 255)))) for c in base)


def options():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--count-only", action="store_true", help="build and print triangle counts; write nothing")
    return parser.parse_args(argv)


def surface(name, fn):
    s = kit.Surface(name, SLOT, smooth=False)
    fn(s)
    assert len(s.verts) == len(s.colors) and all(all(0 <= i < len(s.verts) for i in f) for f in s.faces), name
    s.colors = [tone(c) if isinstance(c, str) else c for c in s.colors]
    return s


def tri_count(s):
    return sum(len(f) - 2 for f in s.faces)


def bounds(s):
    return pk.bounds(s)


def inside(shell, base, grow=0.3):
    pk.inside(shell, [base], grow)


def _col_object(c, name, root):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([kit.xyz(v) for v in c.verts], [], c.faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj


def metrics(path):
    data = path.read_bytes()
    length = int.from_bytes(data[12:16], "little")
    doc = json.loads(data[20:20 + length])
    tris = verts = draws = col_tris = 0
    names = {i: m.get("name", "") for i, m in enumerate(doc["meshes"])}
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            n = doc["accessors"][prim["indices"]]["count"] // 3
            if node["name"].endswith("-col-col"):
                col_tris += n
                continue
            tris += n
            verts += doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    return {"triangles": tris, "vertices": verts, "draws": draws, "col_triangles": col_tris,
            "materials": [m["name"] for m in doc.get("materials", [])], "nodes": [n["name"] for n in doc["nodes"]],
            "meshes": sorted(names.values())}


def flipped(obj, n=48):
    """Casts a grid of rays at the drawn mesh from above and from the four sides and counts first hits on a face that points
    away from the ray (a back face). Godot culls back faces, so each such hit is a hole or an inside-out patch in game.
    Open sheets lose to recalc_face_normals; build every part as a closed solid. Returns (back-facing hits, hits)."""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    lo = Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    hi = Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    bm.free()
    bad = hits = 0
    for axis, sign in ((2, -1), (0, 1), (0, -1), (1, 1), (1, -1)):
        a, b = [k for k in range(3) if k != axis]
        d = Vector((0, 0, 0))
        d[axis] = sign
        for i in range(n):
            for j in range(n):
                p = Vector((0, 0, 0))
                p[a] = lo[a] + (hi[a] - lo[a]) * (i + 0.5) / n
                p[b] = lo[b] + (hi[b] - lo[b]) * (j + 0.5) / n
                p[axis] = hi[axis] + 1.0 if sign < 0 else lo[axis] - 1.0
                loc, nrm, _, _ = tree.ray_cast(p, d)
                if loc is None:
                    continue
                hits += 1
                bad += nrm.dot(d) > 0.2
    return bad, hits


def _file_totals(path):
    """Triangles and vertices over every primitive in the GLB, the way asset-inspect.mjs counts them."""
    data = path.read_bytes()
    length = int.from_bytes(data[12:16], "little")
    doc = json.loads(data[20:20 + length])
    prims = [p for m in doc["meshes"] for p in m["primitives"]]
    return (sum(doc["accessors"][p["indices"]]["count"] // 3 for p in prims),
            sum(doc["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims))


def export(name, fn, cls, args, col=None, sockets=None, check=None):
    """Builds one GLB: the drawn mesh "Body" (one enamel draw), the optional collision mesh and the socket empties.
    Fails loud when the drawn mesh is over its class or check(surface) refuses it. Returns its metrics row."""
    s = surface(name, fn)
    if check is not None:
        check(s)
    cap = CLASSES[cls]
    tris = tri_count(s)
    assert tris <= cap["tris"], (name, "triangles", tris, cap["tris"], cls)
    c = surface(name + "-col", col) if col is not None else None
    total = tris + (tri_count(c) if c else 0)
    assert total <= cap["tris"], (name, "triangles incl. collision", total, cap["tris"], cls)
    lo, hi = bounds(s)
    row = {"file": name + ".glb", "class": cls, "tris": tris, "col_tris": tri_count(c) if c else 0,
           "bounds_min": [round(v, 3) for v in lo], "bounds_max": [round(v, 3) for v in hi],
           "sockets": sorted((sockets or {}).keys())}
    if args.count_only:
        print("CAMP_COUNT", json.dumps(row, sort_keys=True))
        return row
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s.name = "Body"
    body = s.finish(root)
    bad, hits = flipped(body)
    assert bad <= max(2, 0.003 * hits), (name, "back faces visible from outside", bad, hits)
    if c is not None:
        _col_object(c, COL_NODE % name, root)
    for sname, loc in sorted((sockets or {}).items()):
        kit.empty(sname, loc, root)
    path = Path(args.out_dir) / (name + ".glb")
    path.parent.mkdir(parents=True, exist_ok=True)
    common.export(root, str(path))
    m = metrics(path)
    assert m["triangles"] <= cap["tris"] and m["vertices"] <= cap["verts"] and m["draws"] <= cap["draws"], (name, m, cap)
    all_tris, all_verts = _file_totals(path)
    assert all_tris <= cap["tris"] and all_verts <= cap["verts"], (name, "file totals incl. collision", all_tris, all_verts, cap)
    assert m["materials"] == [SLOT], (name, m["materials"])
    if c is not None:
        assert COL_NODE % name in m["nodes"], (name, "missing collision node")
    for sname in sockets or {}:
        assert sname in m["nodes"], (name, "missing socket", sname)
    row.update({"tris": m["triangles"], "verts": m["vertices"], "draws": m["draws"], "col_tris": m["col_triangles"],
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    print("CAMP_EXPORT", json.dumps(row, sort_keys=True))
    return row
