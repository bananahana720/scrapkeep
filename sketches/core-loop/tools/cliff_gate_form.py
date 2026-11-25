"""Proposed cliff solids and the CLIFF-R3 section 2 form measures (read-only analysis).

Builds crowns and shoulder hulls from a proposal table (proposal.json) with the same topology as
spillway_scenery.gd (12 crown stations x 5 rings, 10 hull stations x 4 levels), returns world-space
triangles, and measures plan sections, broad faces, nesting and retreat on any triangle soup.
"""
import math
import numpy as np
from shapely.geometry import Polygon, LineString
from shapely.ops import unary_union, polygonize

RIM_ADD = [18.0, 6.0, 12.0]
RIM_WIDTH = [48.0, 36.0, 24.0]
RIM_CREST = [
    [(0, 8), (0.20, 16), (0.38, 18), (0.64, 17), (0.85, 12), (1, 8)],
    [(0, 3), (0.20, 5), (0.40, 6), (0.60, 5.5), (0.85, 4), (1, 3)],
    [(0, 5), (0.20, 10), (0.38, 12), (0.64, 12), (0.85, 10), (1, 6)],
]
RIM_RING_Y = [0.0, 0.0, 0.35, 0.70, 1.0]


def crest_rise(v, u):
    u = min(max(u, 0.0), 1.0)
    keys = RIM_CREST[v]
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if u <= b[0]:
            return a[1] + (b[1] - a[1]) * (u - a[0]) / (b[0] - a[0])
    return keys[-1][1]


def signed_area(pts):
    a = 0.0
    n = len(pts)
    for i in range(n):
        x0, z0 = pts[i][0], pts[i][1]
        x1, z1 = pts[(i + 1) % n][0], pts[(i + 1) % n][1]
        a += x0 * z1 - x1 * z0
    return a * 0.5


def _tri(tris, a, b, c, hint):
    a, b, c = np.array(a), np.array(b), np.array(c)
    if np.dot(np.cross(b - a, c - a), hint) < 0:
        tris.append([a, c, b])
    else:
        tris.append([a, b, c])


def _wall(tris, ring_a, ring_b):
    """Bands between two same-length rings, outward by the ring's winding (plan x,z)."""
    n = len(ring_a)
    sign = 1.0 if signed_area([(p[0], p[2]) for p in ring_a]) > 0 else -1.0
    for i in range(n):
        j = (i + 1) % n
        a, b, c, d = ring_a[i], ring_a[j], ring_b[j], ring_b[i]
        e = np.array(ring_a[j]) - np.array(ring_a[i])
        hint = np.array([e[2], 0.0, -e[0]]) * sign
        if np.linalg.norm(hint) < 1e-9:
            e = np.array(ring_b[j]) - np.array(ring_b[i])
            hint = np.array([e[2], 0.0, -e[0]]) * sign
        _tri(tris, a, b, d, hint)
        _tri(tris, b, c, d, hint)


def corner_slopes(pts, batter):
    """Planar faces: face i (pts[i] -> pts[i+1]) leans inward by batter[i] metres per metre of height.
    Returns per-vertex plan slope m_j (metres of plan movement per metre of height), the corner line
    where faces j-1 and j meet, so every ring vertex lies on both its faces and each face stays planar."""
    n = len(pts)
    sign = 1.0 if signed_area(pts) > 0 else -1.0
    normals = []
    for i in range(n):
        e = np.array(pts[(i + 1) % n], float) - np.array(pts[i], float)
        nrm = np.array([e[1], -e[0]]) * sign
        normals.append(nrm / np.linalg.norm(nrm))
    slopes = []
    for j in range(n):
        n0, n1 = normals[(j - 1) % n], normals[j]
        A = np.array([n0, n1])
        slopes.append(np.linalg.solve(A, -np.array([batter[(j - 1) % n], batter[j]])))
    return slopes


def crown_rings(crown, prop_v, root=None):
    v = crown["variant"]
    xs = 1.0 if crown["side"] < 0 else -1.0
    W = crown["width"]
    root = crown["root"] if root is None else root
    plan = [tuple(p) for p in prop_v["plan"]]
    m = corner_slopes(plan, prop_v["batter"])
    rings = []
    for k in range(5):
        ring = []
        for j, (x, zu) in enumerate(plan):
            if k == 0:
                ring.append((x, -root, zu))
                continue
            y = 0.0
            for _ in range(8):
                z2 = zu + m[j][1] * y
                y = crest_rise(v, z2 / W + 0.5) * RIM_RING_Y[k]
            ring.append((x + m[j][0] * y, y, zu + m[j][1] * y))
        rings.append(ring)
    return rings


def crown_world(crown, prop_v, root=None):
    """Triangles (M,3,3) of one crown in world metres."""
    xs = 1.0 if crown["side"] < 0 else -1.0
    rings = [[(crown["x"] + xs * x, crown["crest"] + y, crown["z"] + z) for (x, y, z) in r] for r in crown_rings(crown, prop_v, root)]
    return _solid(rings, prop_v, crown)


def _solid(rings, prop_v, crown):
    tris = []
    for k in range(len(rings) - 1):
        _wall(tris, rings[k], rings[k + 1])
    faces = 6
    top = rings[-1]
    bot = rings[0]
    for ring, up in ((top, np.array([0, 1.0, 0])), (bot, np.array([0, -1.0, 0]))):
        _zip(tris, ring, faces, up)
    return np.array(tris)


def _zip(tris, ring, faces, up):
    fi, bi = 0, len(ring) - 1
    zf = [p[2] for p in ring]
    while fi < faces - 1 or bi > faces:
        nf = zf[fi + 1] if fi < faces - 1 else math.inf
        nb = zf[bi - 1] if bi > faces else math.inf
        if nf <= nb:
            _tri(tris, ring[fi], ring[fi + 1], ring[bi], up)
            fi += 1
        else:
            _tri(tris, ring[fi], ring[bi - 1], ring[bi], up)
            bi -= 1


def hull_rings(hull, prop_h, levels_y):
    """prop_h: 'plan' 10 (d,e) at the bottom, 'batter' 10 per-face lean. levels_y(k) -> 4 heights."""
    plan = [tuple(p) for p in prop_h["plan"]]
    m = corner_slopes(plan, prop_h["batter"])
    rings = []
    for lv in range(4):
        ring = []
        for j, (d, e) in enumerate(plan):
            ys = levels_y(j)
            t = ys[lv] - ys[0]
            ring.append((hull["x"] + hull["side"] * (d + m[j][0] * t), ys[lv], hull["z"] + e + m[j][1] * t))
        rings.append(ring)
    return rings


def hull_world(hull, prop_h, levels_y):
    rings = hull_rings(hull, prop_h, levels_y)
    tris = []
    for lv in range(3):
        _wall(tris, rings[lv], rings[lv + 1])
    for ring, up in ((rings[3], np.array([0, 1.0, 0])), (rings[0], np.array([0, -1.0, 0]))):
        c = np.mean(np.array(ring), axis=0)
        for i in range(len(ring)):
            _tri(tris, c, ring[i], ring[(i + 1) % len(ring)], up)
    return np.array(tris)


def slice_polygon(tris, y):
    segs = []
    for t in tris:
        ys = t[:, 1]
        if ys.max() < y or ys.min() > y or ys.max() == ys.min():
            continue
        pts = []
        for i in range(3):
            a, b = t[i], t[(i + 1) % 3]
            if (a[1] - y) * (b[1] - y) < 0:
                s = (y - a[1]) / (b[1] - a[1])
                pts.append((round(a[0] + (b[0] - a[0]) * s, 5), round(a[2] + (b[2] - a[2]) * s, 5)))
            elif a[1] == y and b[1] != y:
                pts.append((round(a[0], 5), round(a[2], 5)))
        uniq = []
        for p in pts:
            if not any(abs(p[0] - q[0]) < 1e-7 and abs(p[1] - q[1]) < 1e-7 for q in uniq):
                uniq.append(p)
        if len(uniq) == 2:
            segs.append(LineString(uniq))
    if not segs:
        return None
    polys = list(polygonize(unary_union(segs)))
    if not polys:
        return None
    return max(polys, key=lambda p: p.area)


def _runs(poly):
    pts = list(poly.exterior.coords)[:-1]
    n = len(pts)
    edges = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        edges.append((math.hypot(b[0] - a[0], b[1] - a[1]), math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))))
    edges = [e for e in edges if e[0] > 1e-6]

    def diff(p, q):
        d = abs(p - q) % 360
        return min(d, 360 - d)

    runs = []
    for length, ang in edges:
        if runs and diff(runs[-1][1], ang) < 5.0:
            tot = runs[-1][0] + length
            runs[-1] = (tot, runs[-1][1], )
            runs[-1] = (tot, runs[-1][1])
        else:
            runs.append((length, ang))
    if len(runs) > 1 and diff(runs[0][1], runs[-1][1]) < 5.0:
        runs[0] = (runs[0][0] + runs[-1][0], runs[0][1])
        runs.pop()
    return runs


def plan_measures(poly):
    per = poly.length
    runs = _runs(poly)
    longest = max(r[0] for r in runs) / per
    axis = 0.0
    for length, ang in runs:
        a = abs(ang) % 180
        near_x = min(a, 180 - a) <= 10.0
        near_z = abs(a - 90) <= 10.0
        if near_x or near_z:
            axis += length
    occ = poly.area / poly.minimum_rotated_rectangle.area
    return {"perimeter": per, "longest_frac": longest, "axis_frac": axis / per, "occupancy": occ, "area": poly.area, "runs": len(runs)}


def patches(tris, y_floor, arena, span_min, wall_ny=0.7, merge_deg=5.0):
    """Connected planar wall patches above y_floor. Returns list of dicts."""
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    area = np.linalg.norm(n, axis=1) * 0.5
    nn = n / np.maximum(np.linalg.norm(n, axis=1)[:, None], 1e-12)
    cen = tris.mean(axis=1)
    keep = [i for i in range(len(tris)) if abs(nn[i][1]) < wall_ny and tris[i][:, 1].min() >= y_floor - 1e-6 and area[i] > 1e-9]
    if not keep:
        return [], 0.0
    key = lambda p: (round(p[0], 3), round(p[1], 3), round(p[2], 3))
    vt = {}
    for i in keep:
        for p in tris[i]:
            vt.setdefault(key(p), []).append(i)
    parent = {i: i for i in keep}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    edge_map = {}
    for i in keep:
        for e in range(3):
            k = tuple(sorted([key(tris[i][e]), key(tris[i][(e + 1) % 3])]))
            edge_map.setdefault(k, []).append(i)
    for k, lst in edge_map.items():
        for a in lst:
            for b in lst:
                if a < b and math.degrees(math.acos(max(-1, min(1, float(np.dot(nn[a], nn[b])))))) < merge_deg:
                    parent[find(a)] = find(b)
    groups = {}
    for i in keep:
        groups.setdefault(find(i), []).append(i)
    total = float(sum(area[i] for i in keep))
    out = []
    for g in groups.values():
        a = np.array([area[i] for i in g])
        nv = (nn[g] * a[:, None]).sum(axis=0)
        nv /= np.linalg.norm(nv)
        h = np.array([nv[0], nv[2]])
        hn = np.linalg.norm(h)
        if hn < 1e-6:
            continue
        h = h / hn
        tang = np.array([-h[1], h[0]])
        pts = np.array([[p[0], p[2]] for i in g for p in tris[i]])
        span = float(pts @ tang.T.max() if False else (pts @ tang).max() - (pts @ tang).min())
        c = np.array([cen[i] for i in g]).mean(axis=0)
        to_arena = np.array([arena[0] - c[0], arena[1] - c[2]])
        out.append({"normal": nv, "azimuth": math.degrees(math.atan2(nv[2], nv[0])), "area": float(a.sum()), "span": span,
                    "faces_arena": float(np.dot(h, to_arena)) > 0, "tris": g, "share": float(a.sum()) / total})
    return out, total


def angle_between(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def qualifying(pat, span_min, min_share=0.08):
    return [p for p in pat if p["faces_arena"] and p["span"] >= span_min and p["share"] >= min_share]


def adjacent_angles(tris, qual):
    key = lambda p: (round(p[0], 3), round(p[1], 3), round(p[2], 3))
    owner = {}
    for pi, p in enumerate(qual):
        for i in p["tris"]:
            for q in tris[i]:
                owner.setdefault(key(q), set()).add(pi)
    pairs = set()
    for s in owner.values():
        for a in s:
            for b in s:
                if a < b:
                    pairs.add((a, b))
    return sorted(round(angle_between(qual[a]["azimuth"], qual[b]["azimuth"]), 1) for a, b in pairs)


def distinct_dirs(azimuths, sep=12.0):
    picked = []
    for a in azimuths:
        if all(angle_between(a, b) >= sep for b in picked):
            picked.append(a)
    return picked
