"""Anchor kits: the silhouette-to-box gap, per family and per height band.

PLAN-w16-plus.md:111-122 swapped the anchor-field rows from grey 8 m boxes to drawn kit meshes but kept the 8 m x 8 m
BoxShape3D post colliders. Line 122: "Report each family's silhouette-to-box gap. If a gap reads as an invisible wall, card a
collider-narrowing follow-up." This script is that report. A large gap means the ball stops against air beside a thin
hoodoo or saguaro.

  prlimit --as=12884901888 blender -b --factory-startup --threads 2 --python-exit-code 1 \
      -P tools/blender/park/anchor_gap.py -- [--out FILE.json]       (from sketches/core-loop)

Frame (anchors.py docstring, "Authoring contract"; park_recipes.gd ANCHOR_POST_M, ANCHOR_SINK_M, anchor_draws): +Y up in
the GLB, origin at the post's base centre, footprint x and z in [-4, 4], authored y -1 to 9 (y -1 to 0 sunk underground),
render mesh `<id>` and collision mesh `<id>-col` (8 x 8 x 10 box) in each GLB. Blender's glTF import turns authored
(x, y, z) into (x, -z, y), so authored height is Blender Z, authored x is Blender X and authored z is -Blender Y. The
script checks that the -col box spans 10 m on Blender Z and 8 m on X and Y, and exits nonzero if not. The loader stretches
Y only (tall / 10) and turns each post by a quarter turn, so the horizontal gap of an authored height band is the same at
every stretch and turn: the turn only permutes which face is which. Heights here are authored metres above ground, not
stretched ones.

Method. The render mesh in world space is clipped, triangle by triangle, to each 1.0 m band of authored height 0..9
(closed slab, so a flat cap exactly on a band edge counts in both bands). The clipped polygons' corners include the points
where mesh edges cross the band planes, so a long slanting edge is not undersampled. From a band's points:
  extent toward a face   the largest x (+x face), -x (-x face), z (+z face) or -z (-z face) among them
  face gap               4.0 - extent toward that face: the distance from the drawn surface to the collider face
  band min / max gap     the smallest and largest of the four face gaps
  hull coverage          area of the convex hull of the band's (x, z) points / 64 m2 (the box footprint)
  empty band             no geometry at all (e.g. the top of a short cairn): the whole 8 m face there is air
Summary per GLB:
  max_gap_m              worst face gap over all non-empty bands: the farthest the ball can stop from the drawn surface
  gap_at_ball_height_m   worst face gap in the band holding the ball centre resting on the ground, height
                         Tuning.RADIUS = 1.0 m (src/movement/tuning.gd:95), band [1, 2); the ball spans bands 0 and 1
                         but its centre, where the contact normal is set, is on the band edge, so band 1 is reported
  min_gap_m              smallest face gap over non-empty bands
  bands_empty            indices of empty bands
Per family: the worst of a, b and c for each number (largest gap; smallest min_gap_m; union of empty bands).
Self-check: the -col box measured the same way must give gap 0 on every face in every band; a GLB that fails is a contract
violation. Contract violations: a missing GLB, a -col box that is not 8 x 10 x 8, a render mesh outside [-4, 4] on x or z.
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
FAMILIES = ["hoodoo", "basalt", "timber", "saguaro", "cairn"]
VARIANTS = ["a", "b", "c"]
HALF = 4.0                 # ANCHOR_POST_M / 2
POST_M = 8.0               # ANCHOR_POST_M
AUTHORED_M = 10.0          # ANCHOR_AUTHORED_M
BANDS = 9                  # authored y 0..9, 1.0 m each
BALL_RADIUS = 1.0          # Tuning.RADIUS, src/movement/tuning.gd:95
BALL_BAND = int(BALL_RADIUS)
TOL = 1e-4
FACES = ("+x", "-x", "+z", "-z")


def authored(p):
    # Blender (x, y, z) back to authored (x, y up, z): the importer turned authored (x, y, z) into (x, -z, y).
    return (p[0], p[2], -p[1])


def world_tris(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    mw = obj.matrix_world
    pts = [authored(mw @ v.co) for v in mesh.vertices]
    return [[pts[i] for i in t.vertices] for t in mesh.loop_triangles]


def clip_plane(poly, axis_y, limit, keep_above):
    # Sutherland-Hodgman against y >= limit (keep_above) or y <= limit; points on the plane are kept.
    sign = 1.0 if keep_above else -1.0
    out = []
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        da = sign * (a[1] - limit)
        db = sign * (b[1] - limit)
        if da >= -1e-9:
            out.append(a)
        if (da > 1e-9 and db < -1e-9) or (da < -1e-9 and db > 1e-9):
            t = da / (da - db)
            out.append(tuple(a[k] + (b[k] - a[k]) * t for k in range(3)))
    return out


def band_points(tris, lo, hi):
    pts = []
    for tri in tris:
        ys = [p[1] for p in tri]
        if max(ys) < lo - 1e-9 or min(ys) > hi + 1e-9:
            continue
        poly = clip_plane(clip_plane(tri, 1, lo, True), 1, hi, False)
        pts.extend(poly)
    return pts


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


def measure(tris):
    bands = []
    for b in range(BANDS):
        pts = band_points(tris, float(b), float(b + 1))
        if not pts:
            bands.append({"band": b, "empty": True})
            continue
        xs = [p[0] for p in pts]
        zs = [p[2] for p in pts]
        gaps = [HALF - max(xs), HALF + min(xs), HALF - max(zs), HALF + min(zs)]
        bands.append({
            "band": b, "empty": False,
            "gap": dict(zip(FACES, (round(g, 4) for g in gaps))),
            "min_gap_m": round(min(gaps), 4), "max_gap_m": round(max(gaps), 4),
            "hull_coverage": round(hull_area([(p[0], p[2]) for p in pts]) / (POST_M * POST_M), 4),
        })
    return bands


def summarise(bands):
    live = [b for b in bands if not b["empty"]]
    ball = bands[BALL_BAND]
    return {
        "max_gap_m": max(b["max_gap_m"] for b in live),
        "gap_at_ball_height_m": None if ball["empty"] else ball["max_gap_m"],
        "min_gap_m": min(b["min_gap_m"] for b in live),
        "bands_empty": [b["band"] for b in bands if b["empty"]],
    }


def extent(tris):
    pts = [p for t in tris for p in t]
    return [(min(p[k] for p in pts), max(p[k] for p in pts)) for k in range(3)]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def audit(name):
    path = os.path.join(MODELS, name + ".glb")
    if not os.path.isfile(path):
        raise SystemExit("anchor_gap: missing " + path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    cols = [o for o in meshes if o.name.endswith("-col")]
    renders = [o for o in meshes if not o.name.endswith("-col")]
    if len(cols) != 1 or len(renders) != 1:
        raise SystemExit("anchor_gap: %s has %d render and %d -col meshes, want 1 and 1" % (name, len(renders), len(cols)))
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
    self_check = {}
    if not violations:
        col_bands = measure(ctris)
        self_check = {"all_gaps_zero": all(not b["empty"] and abs(b["max_gap_m"]) < TOL and abs(b["min_gap_m"]) < TOL
                                            for b in col_bands)}
        if not self_check["all_gaps_zero"]:
            violations.append("-col box measured the same way does not give gap 0 on every face")
    bands = measure(rtris)
    return {
        "glb": name + ".glb", "sha256": sha256(path), "tris": len(rtris),
        "render_extent_authored": {"x": [round(v, 4) for v in rx], "y": [round(v, 4) for v in ry], "z": [round(v, 4) for v in rz]},
        "col_extent_authored": {"x": [round(v, 4) for v in cx], "y": [round(v, 4) for v in cy], "z": [round(v, 4) for v in cz]},
        "self_check": self_check, "violations": violations,
        "bands": bands, "summary": summarise(bands),
    }


def worst(items):
    return {
        "max_gap_m": max(i["max_gap_m"] for i in items),
        "gap_at_ball_height_m": max((i["gap_at_ball_height_m"] if i["gap_at_ball_height_m"] is not None else POST_M) for i in items),
        "min_gap_m": min(i["min_gap_m"] for i in items),
        "bands_empty": sorted(set(b for i in items for b in i["bands_empty"])),
    }


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = None
    if argv[:1] == ["--out"] and len(argv) == 2:
        out = argv[1]
    elif argv:
        raise SystemExit("anchor_gap: usage: -- [--out FILE.json]")
    try:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=HERE, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        head = "unavailable"
    glbs, families, bad = [], {}, []
    for fam in FAMILIES:
        for v in VARIANTS:
            r = audit("anchor_%s_%s" % (fam, v))
            glbs.append(r)
            bad += ["%s: %s" % (r["glb"], m) for m in r["violations"]]
        families[fam] = worst([g["summary"] for g in glbs if g["glb"].startswith("anchor_%s_" % fam)])
    print("ANCHOR_GAP git HEAD %s; ball radius %.1f m (tuning.gd:95); bands 1.0 m over authored y 0..9; gaps in metres" % (head, BALL_RADIUS))
    for g in glbs:
        print("ANCHOR_GAP sha256 %s  %s" % (g["sha256"], g["glb"]))
    print("%-20s %8s %10s %8s  %s" % ("glb", "max_gap", "ball_gap", "min_gap", "bands_empty"))
    for g in glbs:
        s = g["summary"]
        ball = "n/a" if s["gap_at_ball_height_m"] is None else "%.3f" % s["gap_at_ball_height_m"]
        print("%-20s %8.3f %10s %8.3f  %s  selfcheck_col_gap0=%s" % (g["glb"][:-4], s["max_gap_m"], ball, s["min_gap_m"],
              s["bands_empty"], g["self_check"].get("all_gaps_zero")))
    for fam, s in families.items():
        print("%-20s %8.3f %10.3f %8.3f  %s" % ("FAMILY " + fam, s["max_gap_m"], s["gap_at_ball_height_m"], s["min_gap_m"], s["bands_empty"]))
    print("ANCHOR_GAP per-band max face gap (m, '-' empty) / hull coverage, bands 0..8")
    for g in glbs:
        print("%-20s %s" % (g["glb"][:-4], " ".join("%5s" % ("-" if b["empty"] else "%.2f" % b["max_gap_m"]) for b in g["bands"])),
              "|", " ".join("%4s" % ("-" if b["empty"] else "%.2f" % b["hull_coverage"]) for b in g["bands"]))
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w") as f:
            json.dump({"git_head": head, "ball_radius_m": BALL_RADIUS, "glbs": glbs, "families": families}, f, indent=1)
    for m in bad:
        print("ANCHOR_GAP CONTRACT VIOLATION " + m)
    if bad:
        sys.exit(1)


main()
