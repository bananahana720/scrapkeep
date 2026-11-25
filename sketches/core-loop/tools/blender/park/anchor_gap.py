"""Anchor kits: the silhouette-to-box gap, at the ball's world height, per shipped row size.

PLAN-w16-plus.md:111-122 swapped the anchor-field rows from grey 8 m boxes to drawn kit meshes but kept the 8 m x 8 m
BoxShape3D post colliders. Line 122: "Report each family's silhouette-to-box gap. If a gap reads as an invisible wall, card a
collider-narrowing follow-up." This script is that report. A large gap means the ball stops against air beside a thin
hoodoo or saguaro.

  prlimit -v12884901888 blender -b --factory-startup --threads 2 --python-exit-code 1 \
      -P tools/blender/park/anchor_gap.py -- [--out FILE.json]       (from sketches/core-loop)

Frame (anchors.py docstring, "Authoring contract"; park_recipes.gd ANCHOR_POST_M, ANCHOR_SINK_M, anchor_draws): +Y up in
the GLB, origin at the post's base centre, footprint x and z in [-4, 4], authored y -1 to 9 (y -1 to 0 sunk underground),
render mesh `<id>` and collision mesh `<id>-col` (8 x 8 x 10 box) in each GLB. Blender's glTF import turns authored
(x, y, z) into (x, -z, y), so authored height is Blender Z, authored x is Blender X and authored z is -Blender Y. The
script checks that the -col box spans 10 m on Blender Z and 8 m on X and Y, and exits nonzero if not.

Height mapping (park_recipes.gd anchor_draws :1263, :1271). The loader stretches Y only, by tall / 10 with
tall = size[1] + ANCHOR_SINK_M, and puts the instance at bottom + tall / 10 with bottom = ground - ANCHOR_SINK_M. So world
height h above ground is authored y = (h + 1) * 10 / tall - 1; ground is authored 10 / tall - 1 (below 0 when tall > 10, so
the sunk skirt y -1..0 shows). Authored height equals world height only at tall = 10. The horizontal gap of an authored band
does not change with the stretch, and quarter turns only permute faces, so the script measures per (variant, shipped row
size) by mapping world probe heights to authored slabs. Shipped sizes and row counts are read from src/world/park/park_*.json
(park_test.json skipped; a row is any object, at any depth, whose recipe is one of the five kit families).

Method. The render mesh in world space is clipped triangle by triangle to a slab of authored height (closed slab [lo, hi]:
a flat cap exactly on an edge counts in both neighbours). The clipped polygons' corners include the points where mesh edges
cross the slab planes, so a long slanting edge is not undersampled. From a slab's points:
  extent toward a face   the largest x (+x face), -x (-x face), z (+z face) or -z (-z face) among them
  face gap               4.0 - extent toward that face: the distance from the drawn surface to the collider face. It is
                         the NEAREST approach anywhere along the face, so it is a lower bound on the air the ball meets:
                         one arm or a lean reaching the face hides that most of the face is air. Above 4.0 it means the
                         geometry lies wholly on the far side of the post axis (cairn_b's top stone: -x gap 4.38), so that
                         face is all air.
  centre gap             the head-on case: the extent toward +-x counting only geometry with |z| <= 1.0 (the ball radius), and
                         toward +-z only geometry with |x| <= 1.0. No geometry in the strip gives 4.0 (the ball meets bare
                         collider at the face centre, 4 m from the post axis); a slab with no geometry at all gives 4.0 on
                         every face, not 8.0.
  hull coverage          area of the convex hull of the slab's (x, z) points / 64 m2 (authored table only)
World summaries per (variant, size), each the worst face (largest gap):
  contact_gap_m          world h in [0.5, 1.5]: a rolling ball (Tuning.RADIUS = 1.0, src/movement/tuning.gd:95) touches a
                         vertical face at its centre height h = 1.0
  contact_gap_centre_m   the same slab, centre gap
  low_band_gap_m         world h in [0, 2], the ball's whole height
  max_gap_m, min_gap_m   airborne: the post's visible height h in [0, size] in min(ceil(size), 20) equal world bands; the
                         largest face gap over all bands (an empty band counts 4.0) and the smallest face gap over
                         non-empty bands
Per (family, size) the worst over a, b, c. Per family: the row-weighted share of rows whose worst-variant
contact_gap_centre_m exceeds 1.0 m (one ball radius) and 2.0 m (a ball diameter), and the worst values. The 1.0 and 2.0
are reporting bins tied to the ball radius, not pass or fail; large gaps exit 0.
Secondary, authored (stretch-invariant, for the modeler): per GLB, 1 m bands of authored y -1..9 with the four face gaps,
min and max, and hull coverage.
Self-checks: the -col box measured the same way gives gap 0 and centre gap 0 on every face in every authored band and in the
contact slab, and the height mapping is planted (tall 10: world [0.5, 1.5] is authored [0.5, 1.5]; size 2, tall 3: authored
[4.0, 7.33]). Contract violations (exit 1, each printed as `ANCHOR_GAP ERROR`): a missing GLB, a -col box that is not
8 x 10 x 8, a render mesh outside [-4, 4] on x or z, a failed self-check.
"""
import hashlib
import json
import math
import os
import subprocess
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
SKETCH = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODELS = os.path.join(SKETCH, "assets", "models", "park")
PARK_DIR = os.path.join(SKETCH, "src", "world", "park")
FAMILIES = ["hoodoo", "basalt", "timber", "saguaro", "cairn"]
VARIANTS = ["a", "b", "c"]
HALF = 4.0
POST_M = 8.0
AUTHORED_M = 10.0
SINK_M = 1.0
BALL_RADIUS = 1.0
MAX_WORLD_BANDS = 20
TOL = 1e-4
FACES = ("+x", "-x", "+z", "-z")
AUTH_BANDS = list(range(-1, 9))


def fail(msg):
    print("ANCHOR_GAP ERROR " + msg)
    sys.stdout.flush()
    sys.exit(1)


def to_authored_y(h, size):
    return (h + SINK_M) * AUTHORED_M / (size + SINK_M) - SINK_M


def authored(p):
    return (p[0], p[2], -p[1])


def world_tris(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    mw = obj.matrix_world
    pts = [authored(mw @ v.co) for v in mesh.vertices]
    return [[pts[i] for i in t.vertices] for t in mesh.loop_triangles]


def clip_plane(poly, axis, limit, keep_above):
    sign = 1.0 if keep_above else -1.0
    out = []
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        da = sign * (a[axis] - limit)
        db = sign * (b[axis] - limit)
        if da >= -1e-9:
            out.append(a)
        if (da > 1e-9 and db < -1e-9) or (da < -1e-9 and db > 1e-9):
            t = da / (da - db)
            out.append(tuple(a[k] + (b[k] - a[k]) * t for k in range(3)))
    return out


def slab_points(tris, lo, hi, strip_axis=None, strip=BALL_RADIUS):
    pts = []
    for tri in tris:
        ys = [p[1] for p in tri]
        if max(ys) < lo - 1e-9 or min(ys) > hi + 1e-9:
            continue
        poly = clip_plane(clip_plane(tri, 1, lo, True), 1, hi, False)
        if strip_axis is not None and poly:
            poly = clip_plane(clip_plane(poly, strip_axis, -strip, True), strip_axis, strip, False)
        pts.extend(poly)
    return pts


def face_gaps(pts):
    if not pts:
        return [HALF] * 4
    xs = [p[0] for p in pts]
    zs = [p[2] for p in pts]
    return [HALF - max(xs), HALF + min(xs), HALF - max(zs), HALF + min(zs)]


def centre_gaps(tris, lo, hi):
    gx = face_gaps(slab_points(tris, lo, hi, 2))[:2]
    gz = face_gaps(slab_points(tris, lo, hi, 0))[2:]
    return gx + gz


def hull_area(pts2):
    pts = sorted(set((round(x, 7), round(z, 7)) for x, z in pts2))
    if len(pts) < 3:
        return 0.0

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    h = lower[:-1] + upper[:-1]
    return abs(sum(h[i][0] * h[(i + 1) % len(h)][1] - h[(i + 1) % len(h)][0] * h[i][1] for i in range(len(h)))) * 0.5


def authored_bands(tris):
    bands = []
    for b in AUTH_BANDS:
        pts = slab_points(tris, float(b), float(b + 1))
        if not pts:
            bands.append({"band": b, "empty": True, "min_gap_m": HALF, "max_gap_m": HALF})
            continue
        gaps = face_gaps(pts)
        cgaps = centre_gaps(tris, float(b), float(b + 1))
        bands.append({
            "band": b, "empty": False, "gap": dict(zip(FACES, (round(g, 4) for g in gaps))),
            "min_gap_m": round(min(gaps), 4), "max_gap_m": round(max(gaps), 4),
            "centre_gap_m": round(max(cgaps), 4),
            "hull_coverage": round(hull_area([(p[0], p[2]) for p in pts]) / (POST_M * POST_M), 4),
        })
    return bands


def world_measure(tris, size):
    def slab(h0, h1):
        return to_authored_y(h0, size), to_authored_y(h1, size)

    lo, hi = slab(BALL_RADIUS - 0.5, BALL_RADIUS + 0.5)
    contact = max(face_gaps(slab_points(tris, lo, hi)))
    centre = max(centre_gaps(tris, lo, hi))
    lo, hi = slab(0.0, 2.0 * BALL_RADIUS)
    low = max(face_gaps(slab_points(tris, lo, hi)))
    n = min(int(math.ceil(size)), MAX_WORLD_BANDS)
    maxes, mins, empty = [], [], 0
    for i in range(n):
        lo, hi = slab(size * i / n, size * (i + 1) / n)
        pts = slab_points(tris, lo, hi)
        g = face_gaps(pts)
        maxes.append(max(g))
        if pts:
            mins.append(min(g))
        else:
            empty += 1
    return {"contact_gap_m": round(contact, 4), "contact_gap_centre_m": round(centre, 4), "low_band_gap_m": round(low, 4),
            "max_gap_m": round(max(maxes), 4), "min_gap_m": round(min(mins), 4) if mins else None,
            "world_bands": n, "world_bands_empty": empty}


def extent(tris):
    pts = [p for t in tris for p in t]
    return [(min(p[k] for p in pts), max(p[k] for p in pts)) for k in range(3)]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def shipped_sizes(only=None):
    found = {f: {} for f in FAMILIES}

    def walk(o):
        if isinstance(o, dict):
            r = o.get("recipe")
            if isinstance(r, str) and r.startswith("anchor_") and r[7:] in FAMILIES and isinstance(o.get("size"), list):
                d = found[r[7:]]
                d[o["size"][1]] = d.get(o["size"][1], 0) + 1
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    names = sorted(n for n in os.listdir(PARK_DIR) if n.startswith("park_") and n.endswith(".json") and n != "park_test.json"
                   and (only is None or n in only))
    for n in names:
        with open(os.path.join(PARK_DIR, n)) as f:
            walk(json.load(f))
    return found, names


def audit(name, sizes):
    path = os.path.join(MODELS, name + ".glb")
    if not os.path.isfile(path):
        fail("missing " + path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    cols = [o for o in meshes if o.name.endswith("-col")]
    renders = [o for o in meshes if not o.name.endswith("-col")]
    if len(cols) != 1 or len(renders) != 1:
        fail("%s has %d render and %d -col meshes, want 1 and 1" % (name, len(renders), len(cols)))
    ctris, rtris = world_tris(cols[0]), world_tris(renders[0])
    cx, cy, cz = extent(ctris)
    violations = []
    for label, (lo, hi), want in (("x", cx, POST_M), ("height", cy, AUTHORED_M), ("z", cz, POST_M)):
        if abs((hi - lo) - want) > TOL:
            violations.append("-col %s spans %.4f m, want %.1f" % (label, hi - lo, want))
    rx, ry, rz = extent(rtris)
    for label, (lo, hi) in (("x", rx), ("z", rz)):
        if lo < -HALF - TOL or hi > HALF + TOL:
            violations.append("render %s [%.4f, %.4f] outside [-4, 4]" % (label, lo, hi))
    self_check = None
    if not violations:
        zero = all(abs(g) < TOL for b in AUTH_BANDS
                   for g in face_gaps(slab_points(ctris, float(b), float(b + 1))) + centre_gaps(ctris, float(b), float(b + 1)))
        lo, hi = to_authored_y(0.5, 2), to_authored_y(1.5, 2)
        zero = zero and all(abs(g) < TOL for g in face_gaps(slab_points(ctris, lo, hi)) + centre_gaps(ctris, lo, hi))
        self_check = zero
        if not zero:
            violations.append("-col box measured the same way does not give gap 0 and centre gap 0 on every face")
    bands = authored_bands(rtris)
    per_size = {str(s): world_measure(rtris, s) for s in sorted(sizes)}
    return {
        "glb": name + ".glb", "sha256": sha256(path), "tris": len(rtris),
        "render_extent_authored": {"x": [round(v, 4) for v in rx], "y": [round(v, 4) for v in ry], "z": [round(v, 4) for v in rz]},
        "col_extent_authored": {"x": [round(v, 4) for v in cx], "y": [round(v, 4) for v in cy], "z": [round(v, 4) for v in cz]},
        "col_gap_zero": self_check, "violations": violations, "authored_bands": bands, "per_size": per_size,
    }


def planted_mapping():
    cases = [("tall 10 (size 9) h 0.5", to_authored_y(0.5, 9), 0.5), ("tall 10 (size 9) h 1.5", to_authored_y(1.5, 9), 1.5),
             ("size 2 (tall 3) h 0.5", to_authored_y(0.5, 2), 4.0), ("size 2 (tall 3) h 1.5", to_authored_y(1.5, 2), 7.3333)]
    ok = True
    for label, got, want in cases:
        good = abs(got - want) < 1e-3
        ok = ok and good
        print("ANCHOR_GAP planted mapping %-24s authored y %.4f want %.4f %s" % (label, got, want, "ok" if good else "WRONG"))
    return ok


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = None
    if argv[:1] == ["--out"] and len(argv) == 2:
        out = argv[1]
    elif argv:
        fail("usage: -- [--out FILE.json]")
    try:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=HERE, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        head = "unavailable"
    if not planted_mapping():
        fail("height mapping planted check failed")
    sizes, park_files = shipped_sizes()
    print("ANCHOR_GAP git HEAD %s; ball radius %.1f m (tuning.gd:95); park files %s" % (head, BALL_RADIUS, ", ".join(park_files)))
    print("ANCHOR_GAP shipped kit rows by family: size[1]:count")
    for fam in FAMILIES:
        d = sizes[fam]
        print("  %-8s %4d rows  %s" % (fam, sum(d.values()), ", ".join("%g:%d" % (k, d[k]) for k in sorted(d))))
        if not d:
            fail("no shipped rows found for " + fam)
    glbs, bad = [], []
    for fam in FAMILIES:
        for v in VARIANTS:
            r = audit("anchor_%s_%s" % (fam, v), sizes[fam].keys())
            glbs.append(r)
            bad += ["%s: %s" % (r["glb"], m) for m in r["violations"]]
    for g in glbs:
        print("ANCHOR_GAP sha256 %s  %s" % (g["sha256"], g["glb"]))
    metrics = ("contact_gap_m", "contact_gap_centre_m", "low_band_gap_m", "max_gap_m")
    fam_summary = {}
    print("ANCHOR_GAP world gaps per (family, size), worst of a/b/c, metres; rows = shipped row count")
    print("%-8s %7s %5s %9s %9s %9s %9s %8s" % ("family", "size", "rows", "contact", "centre", "low_band", "max_gap", "min_gap"))
    for fam in FAMILIES:
        mine = [g for g in glbs if g["glb"].startswith("anchor_%s_" % fam)]
        rows = []
        for s in sorted(sizes[fam]):
            w = {m: max(g["per_size"][str(s)][m] for g in mine) for m in metrics}
            mins = [g["per_size"][str(s)]["min_gap_m"] for g in mine if g["per_size"][str(s)]["min_gap_m"] is not None]
            w["min_gap_m"] = min(mins) if mins else None
            w["size"], w["rows"] = s, sizes[fam][s]
            rows.append(w)
            print("%-8s %7g %5d %9.3f %9.3f %9.3f %9.3f %8s" % (fam, s, w["rows"], w["contact_gap_m"], w["contact_gap_centre_m"],
                  w["low_band_gap_m"], w["max_gap_m"], "n/a" if w["min_gap_m"] is None else "%.3f" % w["min_gap_m"]))
        total = sum(r["rows"] for r in rows)
        fam_summary[fam] = {
            "rows": total, "sizes": rows,
            "share_centre_gt_1m": round(sum(r["rows"] for r in rows if r["contact_gap_centre_m"] > 1.0) / total, 4),
            "share_centre_gt_2m": round(sum(r["rows"] for r in rows if r["contact_gap_centre_m"] > 2.0) / total, 4),
            **{"worst_" + m: max(r[m] for r in rows) for m in metrics},
        }
    print("ANCHOR_GAP per family: row-weighted share of rows whose worst-variant centre gap exceeds 1.0 m / 2.0 m, and worst values")
    print("%-8s %6s %8s %8s %9s %9s %9s %9s" % ("family", "rows", ">1.0m", ">2.0m", "w.contact", "w.centre", "w.low", "w.max"))
    for fam in FAMILIES:
        f = fam_summary[fam]
        print("%-8s %6d %7.1f%% %7.1f%% %9.3f %9.3f %9.3f %9.3f" % (fam, f["rows"], 100 * f["share_centre_gt_1m"],
              100 * f["share_centre_gt_2m"], f["worst_contact_gap_m"], f["worst_contact_gap_centre_m"],
              f["worst_low_band_gap_m"], f["worst_max_gap_m"]))
    print("ANCHOR_GAP secondary, AUTHORED bands y -1..9 (stretch-invariant): max face gap ('-' empty = 4.0) | hull coverage")
    for g in glbs:
        print("%-18s %s" % (g["glb"][:-4], " ".join("%5s" % ("-" if b["empty"] else "%.2f" % b["max_gap_m"]) for b in g["authored_bands"])),
              "|", " ".join("%4s" % ("-" if b["empty"] else "%.2f" % b["hull_coverage"]) for b in g["authored_bands"]),
              "| col_gap0=%s" % g["col_gap_zero"])
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w") as f:
            json.dump({"git_head": head, "ball_radius_m": BALL_RADIUS, "park_files": park_files, "shipped_sizes":
                       {k: {str(s): n for s, n in v.items()} for k, v in sizes.items()}, "glbs": glbs, "families": fam_summary},
                      f, indent=1)
    for m in bad:
        print("ANCHOR_GAP ERROR contract violation " + m)
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
