"""Anchor kits: the post collider fit table that World's loader applies (src/world/park/anchors/anchor_fit.json).

Ruling (a) on #241 (6327976830, coordinator, 21 Oct 2026): "A ball that stops in visible air breaks 'momentum is sacred'".
Modeling emits a per-variant, per-size BoxShape table for the rows whose contact gap is over 1.0 m. World applies it in
park_recipes.gd place_anchor_field. Acceptance: no row over 1.0 m of air at ball contact. anchor_gap.py measured the gap
(#250); this script fits the boxes and measures the gap again with them.

  prlimit -v12884901888 blender -b --factory-startup --threads 2 --python-exit-code 1 \
      -P tools/blender/park/anchor_fit.py -- [--out src/world/park/anchors/anchor_fit.json]       (from sketches/core-loop)

Frame and mapping as anchor_gap.py (its docstring): authored post frame x, z in [-4, 4], authored y -1..9, and world
height h above the post's ground sample maps to authored y = (h + 1) * 10 / tall - 1, tall = size[1] + 1.

Gap ("air at ball contact"). A ball of radius 1.0 (Tuning.RADIUS, src/movement/tuning.gd:95) rolls on flat ground (centre
at h = 1.0) head-on at one face of the post. The gap is how far the ball still travels after it touches a collider box
before it would touch the drawn mesh. Toward the +x face on the line z = c:
  mesh contact   the largest x + sqrt(1 - (h - 1)^2 - (z - c)^2) over the mesh's surface samples between h 0 and 2 (spacing
                 at most SAMPLE_M, world metres), so a cap that overhangs the stem counts where the ball's upper half meets it
  box contact    the largest face + sqrt(1 - dv^2) over the boxes whose z span holds c, dv the distance from h 1 to the
                 box's height range (dv 0 when the box spans h 1; a box with dv >= 1 cannot touch the ball)
  gap            box contact - mesh contact; a line on which the ball touches no mesh reports the box's full width
The other three faces likewise. The acceptance gap is the worst of the four faces on each face's centre line, c the middle
of the low boxes' combined span. The script also reports the worst over lines across the whole face width (0.25 m steps),
where a box's corners hold air around any round silhouette; that number is information, not the acceptance.

Fit. For each (variant, shipped size) whose gap with today's 8 m box is over LIMIT_M:
  low    the region h 0 .. min(size, SPLIT_M), the whole height of a rolling ball, as 1 box, else 2, else 4 stacked boxes of
         equal height, the first count whose gap is at or under LIMIT_M (else the count with the smallest gap). Each box's
         x and z are the bounds of the mesh in its heights, and the lowest box reaches down to h -1, the sunk bottom.
  upper  when size > SPLIT_M, one box over h SPLIT_M .. size, the bounds of the mesh there.
So no drawn surface is outside its box (checked), and no box is wider than today's 8 m box. Rows at or under LIMIT_M are
not listed and keep the 8 m box. A fitted row still over LIMIT_M prints `ANCHOR_FIT OVER` and carries "over_limit": true;
an axis-aligned box cannot close air that comes from a lopsided silhouette (an arm or a leaning column off the centre line).

Table (anchor_fit.json, in a subfolder because tests/park_routes_test.gd and park_warden_wiring_test.gd read every .json
directly in src/world/park as a park): "fits" maps a GLB name (`<recipe>_<a|b|c>`) to a list of {"size", "boxes", "gap_before_m",
"gap_after_m", "over_limit"}; "size" is the row's size[1]; each box is {"h": [lo, hi], "x": [min, max], "z": [min, max]}.
h is world metres above the post's ground sample (h -1 is the bottom the loader uses today); x and z are in the GLB's
authored frame, before the post's quarter turn. The loader turns a box with the same Basis it gives the drawn post
(anchor_draws), so a box centre c becomes turn * c and its x and z sizes swap on an odd quarter turn. "glbs" holds each
GLB's sha256, so a rebuilt GLB shows a stale table.

Self-checks (exit 1, `ANCHOR_FIT ERROR`): anchor_gap.py's planted height mapping; each -col box spans 8 x 10 x 8; the -col
box measured against the 8 m box gives gap 0 on every face; planted samples against the 8 m box and an off-centre box
(x -1..2, z -3..3) give the gaps worked by hand, one per face; no mesh sample outside its box.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anchor_gap as gap  # noqa: E402

import bpy  # noqa: E402

LIMIT_M = 1.0          # ruling 6327976830: rows over 1.0 m of air at ball contact
SPLIT_M = 2.0 * gap.BALL_RADIUS
SAMPLE_M = 0.1
LINE_STEP_M = 0.25
LOW_SPLITS = (1, 2, 4)
OUT_KEYS = ("+x", "-x", "+z", "-z")


def fail(msg):
    print("ANCHOR_FIT ERROR " + msg)
    sys.stdout.flush()
    sys.exit(1)


def to_world_h(y, size):
    return (y + gap.SINK_M) * (size + gap.SINK_M) / gap.AUTHORED_M - gap.SINK_M


def slab_polys(tris, lo, hi):
    out = []
    for tri in tris:
        ys = [p[1] for p in tri]
        if max(ys) < lo - 1e-9 or min(ys) > hi + 1e-9:
            continue
        poly = gap.clip_plane(gap.clip_plane(tri, 1, lo, True), 1, hi, False)
        if len(poly) >= 3:
            out.append(poly)
    return out


def samples(tris, size, h0, h1):
    # World (x, h, z) points covering the mesh between world heights h0 and h1, spaced at most SAMPLE_M.
    pts = []
    for poly in slab_polys(tris, gap.to_authored_y(h0, size), gap.to_authored_y(h1, size)):
        w = [(p[0], to_world_h(p[1], size), p[2]) for p in poly]
        for k in range(1, len(w) - 1):
            a, b, c = w[0], w[k], w[k + 1]
            edge = max(math.dist(a, b), math.dist(b, c), math.dist(c, a))
            n = max(1, int(math.ceil(edge / SAMPLE_M)))
            for i in range(n + 1):
                for j in range(n + 1 - i):
                    u, v = i / n, j / n
                    pts.append(tuple(a[q] + (b[q] - a[q]) * u + (c[q] - a[q]) * v for q in range(3)))
    return pts


def bounds(pts):
    return [min(p[0] for p in pts), max(p[0] for p in pts)], [min(p[2] for p in pts), max(p[2] for p in pts)]


def line_gap(pts, boxes, face, c):
    # Air between touching the boxes and touching the mesh, ball centre at h 1 on the line (other axis = c) toward `face`.
    # A box touches the ball where the line crosses its span on the other axis; a box whose height range misses h 1 by
    # dv < 1 touches at sqrt(1 - dv^2) out from its face.
    axis, other, sign = {"+x": (0, 2, 1.0), "-x": (0, 2, -1.0), "+z": (2, 0, 1.0), "-z": (2, 0, -1.0)}[face]
    r = gap.BALL_RADIUS
    hit, width = None, 0.0
    for b in boxes:
        lo, span = (b["x"], b["z"]) if axis == 0 else (b["z"], b["x"])
        width = max(width, lo[1] - lo[0])
        dv = max(b["h"][0] - r, r - b["h"][1], 0.0)
        if dv >= r or not span[0] - 1e-9 <= c <= span[1] + 1e-9:
            continue
        t = (lo[1] if sign > 0 else -lo[0]) + math.sqrt(r * r - dv * dv)
        hit = t if hit is None else max(hit, t)
    reach = None
    for p in pts:
        d2 = (p[1] - r) ** 2 + (p[other] - c) ** 2
        if d2 <= r * r:
            t = sign * p[axis] + math.sqrt(r * r - d2)
            if reach is None or t > reach:
                reach = t
    if hit is None:
        return 0.0
    if reach is None:
        return width
    return hit - reach


def face_gaps(pts, boxes):
    # (centre-line gap, worst gap across the face) per face; lines run across the boxes' combined span.
    bx = [min(b["x"][0] for b in boxes), max(b["x"][1] for b in boxes)]
    bz = [min(b["z"][0] for b in boxes), max(b["z"][1] for b in boxes)]
    out = {}
    for face in OUT_KEYS:
        span = bz if face in ("+x", "-x") else bx
        mid = 0.5 * (span[0] + span[1])
        n = max(1, int(math.floor((span[1] - span[0]) / LINE_STEP_M)))
        lines = [span[0] + (span[1] - span[0]) * k / n for k in range(n + 1)]
        out[face] = (line_gap(pts, boxes, face, mid), max(line_gap(pts, boxes, face, c) for c in lines))
    return out


def worst(g, k):
    return max(v[k] for v in g.values())


def load(name):
    path = os.path.join(gap.MODELS, name + ".glb")
    if not os.path.isfile(path):
        fail("missing " + path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    cols = [o for o in meshes if o.name.endswith("-col")]
    renders = [o for o in meshes if not o.name.endswith("-col")]
    if len(cols) != 1 or len(renders) != 1:
        fail("%s has %d render and %d -col meshes, want 1 and 1" % (name, len(renders), len(cols)))
    col = gap.world_tris(cols[0])
    for (lo, hi), want in zip(gap.extent(col), (gap.POST_M, gap.AUTHORED_M, gap.POST_M)):
        if abs((hi - lo) - want) > gap.TOL:
            fail("%s -col box spans %.4f m, want %.1f" % (name, hi - lo, want))
    return gap.world_tris(renders[0]), col, gap.sha256(path)


def r3(v):
    return round(v + 0.0, 3)


def box_of(tris, size, h0, h1, lo_h):
    pts = samples(tris, size, h0, h1)
    if not pts:
        return None
    bx, bz = bounds(pts)
    return {"h": [lo_h, h1], "x": bx, "z": bz, "pts": pts}


def fit(tris, size):
    # The low region (h 0 .. min(size, SPLIT_M)) as one box, then 2, then 4 stacked boxes until the gap is at or under
    # LIMIT_M; the lowest box reaches down to the sunk bottom. Then one upper box over the rest of the post.
    top = min(size, SPLIT_M)
    low = samples(tris, size, 0.0, top)
    if not low:
        fail("no mesh between h 0 and %g at size %g" % (top, size))
    best = None
    for n in LOW_SPLITS:
        cuts = [top * k / n for k in range(n + 1)]
        stack = [box_of(tris, size, cuts[k], cuts[k + 1], -gap.SINK_M if k == 0 else cuts[k]) for k in range(n)]
        stack = [b for b in stack if b]
        g = worst(face_gaps(low, stack), 0)
        if best is None or g < best[0] - 1e-6:
            best = (g, stack)
        if g <= LIMIT_M:
            break
    stack = best[1]
    boxes = list(stack)
    if size > SPLIT_M:
        up = box_of(tris, size, SPLIT_M, size, SPLIT_M)
        if up:
            boxes.append(up)
    for b in boxes:
        for p in b["pts"]:
            if not (b["x"][0] - 1e-6 <= p[0] <= b["x"][1] + 1e-6 and b["z"][0] - 1e-6 <= p[2] <= b["z"][1] + 1e-6):
                fail("size %g: mesh sample %s outside its box" % (size, p))
    return boxes, low


def self_checks(col_tris):
    full = [{"h": [-gap.SINK_M, SPLIT_M], "x": [-gap.HALF, gap.HALF], "z": [-gap.HALF, gap.HALF]}]
    for size in (2.0, 20.0):
        g = face_gaps(samples(col_tris, size, 0.0, SPLIT_M), full)
        if worst(g, 0) > 1e-3:
            fail("-col box against the 8 m box at size %g gives gap %.4f, want 0" % (size, worst(g, 0)))
    odd = [{"h": [-gap.SINK_M, SPLIT_M], "x": [-1.0, 2.0], "z": [-3.0, 3.0]}]
    for boxes, p, face, c, want in ((full, (2.0, 1.0, 0.0), "+x", 0.0, 2.0), (full, (2.0, 1.6, 0.0), "+x", 0.0, 2.2),
                                    (odd, (1.0, 1.0, 0.0), "+x", 0.0, 1.0), (odd, (-0.5, 1.0, 0.0), "-x", 0.0, 0.5),
                                    (odd, (0.0, 1.0, 1.0), "+z", 0.0, 2.0), (odd, (0.0, 1.0, -2.5), "-z", 0.0, 0.5)):
        got = line_gap([p], boxes, face, c)
        print("ANCHOR_FIT planted sample %s %s gap %.4f want %.4f %s" % (p, face, got, want, "ok" if abs(got - want) < 1e-6 else "WRONG"))
        if abs(got - want) > 1e-6:
            fail("planted sample gap")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = None
    if argv[:1] == ["--out"] and len(argv) == 2:
        out = argv[1]
    elif argv:
        fail("usage: -- [--out FILE.json]")
    if not gap.planted_mapping():
        fail("height mapping planted check failed")
    sizes, park_files = gap.shipped_sizes()
    print("ANCHOR_FIT park files %s; limit %.1f m; split at h %.1f m; sample %.2f m" % (", ".join(park_files), LIMIT_M, SPLIT_M, SAMPLE_M))
    table, checked, over = {}, False, []
    print("%-18s %7s %7s %9s %9s %10s %10s %6s  %s" % ("glb", "size", "famrows", "before", "after", "face.bef", "face.aft",
                                                    "boxes", "boxes (h world, x z authored)"))
    for fam in gap.FAMILIES:
        for v in gap.VARIANTS:
            name = "anchor_%s_%s" % (fam, v)
            tris, col, digest = load(name)
            if not checked:
                self_checks(col)
                checked = True
            fits = []
            for size in sorted(sizes[fam]):
                s = float(size)
                low = samples(tris, s, 0.0, min(s, SPLIT_M))
                before = face_gaps(low, [{"h": [-gap.SINK_M, s], "x": [-gap.HALF, gap.HALF], "z": [-gap.HALF, gap.HALF]}])
                if worst(before, 0) <= LIMIT_M:
                    continue
                boxes, low = fit(tris, s)
                after = face_gaps(low, boxes)
                print("%-18s %7g %7d %9.3f %9.3f %10.3f %10.3f %6d  %s" % (
                    name, s, sizes[fam][size], worst(before, 0), worst(after, 0), worst(before, 1), worst(after, 1),
                    len(boxes), "  ".join("h[%g,%g] x[%.2f,%.2f] z[%.2f,%.2f]" % (
                        r3(b["h"][0]), r3(b["h"][1]), b["x"][0], b["x"][1], b["z"][0], b["z"][1]) for b in boxes)))
                if worst(after, 0) > LIMIT_M:
                    over.append("%s size %g: %.3f m with %d boxes" % (name, s, worst(after, 0), len(boxes)))
                fits.append({"size": s, "gap_before_m": r3(worst(before, 0)), "gap_after_m": r3(worst(after, 0)),
                             "over_limit": worst(after, 0) > LIMIT_M,
                             "boxes": [{"h": [r3(b["h"][0]), r3(b["h"][1])], "x": [r3(b["x"][0]), r3(b["x"][1])],
                                        "z": [r3(b["z"][0]), r3(b["z"][1])]} for b in boxes]})
            table[name] = {"sha256": digest, "fits": fits}
    rows = {fam: sum(n for size, n in sizes[fam].items()) for fam in gap.FAMILIES}
    print("ANCHOR_FIT shipped kit rows by family %s" % ", ".join("%s %d" % kv for kv in rows.items()))
    if out:
        doc = {"generated_by": "tools/blender/park/anchor_fit.py", "ruling": "#241 comment 6327976830, option (a)",
               "limit_m": LIMIT_M, "ball_radius_m": gap.BALL_RADIUS, "split_h_m": SPLIT_M,
               "frame": "h: world metres above the post's ground sample; x, z: the GLB's authored frame before the post's "
                        "quarter turn. Variants or sizes not listed keep the 8 m box.",
               "glbs": {k: v["sha256"] for k, v in table.items()},
               "fits": {k: v["fits"] for k, v in table.items() if v["fits"]}}
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w") as f:
            json.dump(doc, f, indent=1, sort_keys=True)
            f.write("\n")
        print("ANCHOR_FIT wrote " + out)
    print("ANCHOR_FIT %d of %d fitted (variant, size) pairs at or under %.1f m" % (
        sum(len(v["fits"]) for v in table.values()) - len(over), sum(len(v["fits"]) for v in table.values()), LIMIT_M))
    for m in over:
        print("ANCHOR_FIT OVER " + m)


if __name__ == "__main__":
    main()
