"""Shared helpers for the six contraption skin recipes (KC9, design-v3/PARK.md section 4): kit.Surface parts in one enamel
draw with COLOR_0 vertex colour, the tubes, rings and rounded plans the six recipes share, and the export that checks the
class budget from assets/asset_budgets.json and prints one PARK_EXPORT row per GLB (sha256 for the determinism log).

Convention for the whole family (kept the same in every recipe header): metres at game scale, Godot +Y up, +Z the contraption's
aim (the launcher's aim, the gauge's face, the barge's lane is free), origin at the contraption's code anchor: the mouth point for
a launcher (the ground is y -1.0 there), the plate's centre for a lift and a barge, the ground under the post for a gauge.

Arizona palette (BIBLE and PARK.md section 4): dam-era concrete grey with form-board joints, dark iron, copper #b77843 (never
brass for machinery), iron oxide, desert varnish, sandstone and bone. Gorge-era Southwest salvage.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from ore_cart import kit, common
from mathutils import Vector

SKETCH = kit.SKETCH
MODELS = SKETCH / "assets/models/park/contraptions"
CLASSES = json.loads((SKETCH / "assets/asset_budgets.json").read_text())["classes"]
SLOT = "enamel"

TONES = {
    "iron": "2b2724",
    "iron_hi": "3d3732",
    "copper": "b77843",
    "copper_dk": "8d5a32",
    "concrete": "7f7d76",
    "concrete_dk": "5c5a54",
    "concrete_lt": "96938a",
    "deck": "56534e",
    "oxide": "9b513a",
    "rust": "7a4430",
    "varnish": "3e3029",
    "sand": "c6a274",
    "bone": "d2c5a5",
    "charcoal": "242a28",
    "ledger": "e6d9b8",
}


def around(n, start=0.0):
    return [start + math.tau * i / n for i in range(n)]


def frustum(s, r0, r1, y0, y1, n, color, caps=(True, True), at=(0.0, 0.0)):
    """A vertical n-gon frustum between y0 (radius r0) and y1 (radius r1)."""
    aa = around(n, math.pi / n)
    verts = [(at[0] + r * math.sin(a), y, at[1] + r * math.cos(a)) for r, y in [(r0, y0), (r1, y1)] for a in aa]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range(n, 2 * n)))
    s.add(verts, faces, color)


def tube(s, a, b, r0, r1, n, color, caps=(True, True)):
    """A cone or cylinder frustum along the segment a to b (radius r0 at a, r1 at b)."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = d.cross(u).normalized()
    rings = []
    for p, r in ((a, r0), (b, r1)):
        rings.append([tuple(p + (u * math.cos(t) + v * math.sin(t)) * r) for t in around(n)])
    verts = rings[0] + rings[1]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    if caps[0]:
        faces.append(tuple(reversed(range(n))))
    if caps[1]:
        faces.append(tuple(range(n, 2 * n)))
    s.add(verts, faces, color)


def strut(s, a, b, w, h, color, caps=True):
    """A square tube from a to b, w wide and h thick, faces turned about the segment so w lies across the world +Y plane."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    side = d.cross(up).normalized() * w / 2
    lift = side.cross(d).normalized() * h / 2
    corners = [-side - lift, side - lift, side + lift, -side + lift]
    verts = [tuple(p + c) for p in (a, b) for c in corners]
    faces = [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)]
    if caps:
        faces += [(3, 2, 1, 0), (4, 5, 6, 7)]
    s.add(verts, faces, color)


def disc_z(s, r0, r1, z0, z1, n, color, at=(0.0, 0.0), caps=True):
    """A drum or annulus about the Z axis through (at.x, at.y): outer radius r1, hole radius r0 (0 for solid), z0 to z1."""
    if r0 <= 0.0:
        aa = around(n)
        ring = lambda z, r: [(at[0] + r * math.cos(t), at[1] + r * math.sin(t), z) for t in aa]
        verts = ring(z0, r1) + ring(z1, r1)
        faces = [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
        if caps:
            faces += [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
        s.add(verts, faces, color)
        return
    aa = around(n)
    quad = [(r0, z0), (r1, z0), (r1, z1), (r0, z1)]
    verts = [(at[0] + r * math.cos(t), at[1] + r * math.sin(t), z) for t in aa for r, z in quad]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(4):
            m = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + m, j * 4 + m, j * 4 + k))
    s.add(verts, faces, color)


def ring_y(s, r0, r1, y0, y1, n, color, at=(0.0, 0.0), arc=None):
    """A vertical annulus (hole radius r0, outer r1) from y0 to y1 about the Y axis through at; arc=(a0, a1) keeps a sector."""
    quad = [(r0, y0), (r1, y0), (r1, y1), (r0, y1)]
    closed = arc is None
    a0, a1 = (0.0, math.tau) if closed else arc
    steps = n if closed else n + 1
    angles = [a0 + (a1 - a0) * i / n for i in range(steps)]
    verts = [(at[0] + r * math.cos(t), y, at[1] + r * math.sin(t)) for t in angles for r, y in quad]
    faces = []
    for i in range(steps if closed else steps - 1):
        j = (i + 1) % steps
        for k in range(4):
            m = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + m, j * 4 + m, j * 4 + k))
    if not closed:
        faces.append((3, 2, 1, 0))
        last = (steps - 1) * 4
        faces.append((last, last + 1, last + 2, last + 3))
    s.add(verts, faces, color)


def bar_xy(s, c, ang, length, width, z0, z1, color):
    """A flat bar in the XY plane about centre c, turned by ang about Z (0 = length along +Y), spanning z0 to z1."""
    ca, sa = math.cos(ang), math.sin(ang)
    pts = []
    for z in (z0, z1):
        for lx, ly in ((-width / 2, -length / 2), (width / 2, -length / 2), (width / 2, length / 2), (-width / 2, length / 2)):
            pts.append((c[0] + lx * ca - ly * sa, c[1] + lx * sa + ly * ca, z))
    s.add(pts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], color)


def hexstud(s, p, normal, r, h, color):
    """A small six-sided bolt head at p standing out along normal."""
    n = Vector(normal).normalized()
    tube(s, Vector(p) - n * h * 0.3, Vector(p) + n * h, r, r * 0.9, 6, color)


def plan(h, r, y, seg=4, grow=0.0):
    """A rounded square of half extent h and corner radius r at height y, as a ring of points in XZ (counter-clockwise)."""
    pts = []
    c = h - r
    for k, (sx, sz) in enumerate([(1, 1), (-1, 1), (-1, -1), (1, -1)]):
        for i in range(seg + 1):
            a = math.pi / 2 * (k + i / seg)
            pts.append((sx * c + (r + grow) * math.cos(a), y, sz * c + (r + grow) * math.sin(a)))
    return pts


def tri_count(s):
    return sum(len(f) - 2 for f in s.faces)


def bounds(s):
    xs, ys, zs = zip(*s.verts)
    return [min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)]


def options(argv=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--count-only", action="store_true", help="build the surfaces and print triangle counts; write nothing")
    return parser.parse_args(argv)


def build(name, builder, cls):
    s = kit.Surface(name, SLOT, smooth=False)
    builder(s)
    cap = CLASSES[cls]
    tris = tri_count(s)
    assert tris <= cap["tris"], (name, "triangles", tris, cap["tris"], cls)
    assert 3 * tris <= cap["verts"] or len(s.verts) <= cap["verts"], (name, "vertices", len(s.verts), cap["verts"])
    assert len(s.verts) == len(s.colors) and all(all(0 <= i < len(s.verts) for i in f) for f in s.faces), name
    return s


def export(name, builder, cls, out_dir, count_only=False, check=None):
    """Builds one single-draw GLB, fails loud when it is over its class or the recipe's own check refuses it, and returns
    its metrics row. check(surface) is the recipe's geometry assertion (bounds, clearance)."""
    s = build(name, builder, cls)
    if check is not None:
        check(s)
    lo, hi = bounds(s)
    row = {"file": name + ".glb", "class": cls, "tris": tri_count(s), "bounds_min": [round(v, 3) for v in lo],
           "bounds_max": [round(v, 3) for v in hi]}
    if count_only:
        print("PARK_COUNT", json.dumps(row, sort_keys=True))
        return row
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    cap = CLASSES[cls]
    assert metrics["triangles"] <= cap["tris"] and metrics["vertices"] <= cap["verts"] and metrics["draws"] <= cap["draws"], (name, metrics, cap)
    assert metrics["materials"] == [SLOT], (name, metrics["materials"])
    row.update({"tris": metrics["triangles"], "verts": metrics["vertices"], "draws": metrics["draws"],
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    print("PARK_EXPORT", json.dumps(row, sort_keys=True))
    return row


def inside(shell_s, base_surfaces, grow=0.3):
    """Fails loud when a detail shell leaves the union of the base bounds grown by `grow`."""
    lo = [min(bounds(b)[0][k] for b in base_surfaces) - grow for k in range(3)]
    hi = [max(bounds(b)[1][k] for b in base_surfaces) + grow for k in range(3)]
    slo, shi = bounds(shell_s)
    assert all(slo[k] >= lo[k] - 1e-6 and shi[k] <= hi[k] + 1e-6 for k in range(3)), ("shell leaves the base bounds", slo, shi, lo, hi)
