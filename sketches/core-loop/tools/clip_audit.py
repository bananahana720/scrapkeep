#!/usr/bin/env python3
"""Clipping audit over a tools/clip_dump.gd dump (numpy only).

    python3 tools/clip_audit.py <dump dir> [--out=<json>] [--cell=0.25]

Owners: every drawn piece is grouped into an owner, the thing a player reads as one object: a multimesh instance by
its container and instance origin (the parts of one GLB placed by one transform share it), a mesh by its GLB scene
node, else by its parent and origin. Water, glow and other transparent or shader-only surfaces are kept out of the
solid checks. Each owner's surface is sampled at `cell` spacing.

Checks, each a list of findings in the JSON:
  clip      two owners whose surfaces pass into each other: sample points of one inside the other's closed surface
            (ray parity), with the share of points inside and the deepest point's depth (distance to the other surface
            is approximated by the point's distance to the other owner's nearest surface sample).
  coplanar  two owners with parallel faces in the same plane over at least COPLANAR_MIN_CELLS cells: z-fighting.
  ground    park stages only, against the stage's floor_height grid: `floating` (lowest point above the ground), `hanging`
            (a footed owner whose foot ring is more than HANG_M over the ground for more than HANG_SHARE of it),
            `buried` (all of it under the ground), `ground_coplanar` (flat faces lying in the ground plane).
  naked     colliders (layer the ball's mask hits) with surface the ball can touch and nothing drawn within NAKED_M of it,
            kept when the ball feels it: resting on such a point, the ball (radius BALL_R) stops more than FELT_M short of
            anything drawn. Invisible walls. Reports the felt area, the gap and the share of the collider's exposed surface.
  stacked   two instances of the same mesh at nearly the same transform (a doubled row).
"""
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

CELL = 0.3
NAKED_M = 0.5
BALL_R = 0.92
FELT_M = 0.3
COARSE = 4.0
ROLL_M = 1.6
COPLANAR_MIN_CELLS = 6
SEAM_MARGIN = 0.05
HANG_M = 0.35
HANG_SHARE = 0.25
CLIP_MIN_SHARE = 0.04
CLIP_MIN_DEPTH = 0.15
CLIP_REACH = 1.2
STACK_M = 0.08
GLOBAL_SIGN = 1.0
MAX_PAIR_TRIS = 20000
SOFT_SHADERS = ("spill_water", "water", "glow", "beam", "mist", "fog", "sky", "streak", "flash", "telegraph", "ring")


def load(dump):
    dump = Path(dump)
    meta = json.loads((dump / "items.json").read_text())
    tris = np.fromfile(dump / "tris.f32", dtype=np.float32).reshape(-1, 3, 3)
    ground = None
    if "ground" in meta and meta["area"] != "brindle":
        g = meta["ground"]
        ground = (g, np.fromfile(dump / "ground.f32", dtype=np.float32).reshape(g["nz"], g["nx"]))
    return meta, tris, ground


def ground_at(ground, x, z):
    g, h = ground
    fx = (x - g["x0"]) / g["step"]
    fz = (z - g["z0"]) / g["step"]
    i0 = np.clip(np.floor(fx).astype(np.int64), 0, g["nx"] - 2)
    k0 = np.clip(np.floor(fz).astype(np.int64), 0, g["nz"] - 2)
    tx = np.clip(fx - i0, 0.0, 1.0)
    tz = np.clip(fz - k0, 0.0, 1.0)
    a = h[k0, i0] * (1 - tx) + h[k0, i0 + 1] * tx
    b = h[k0 + 1, i0] * (1 - tx) + h[k0 + 1, i0 + 1] * tx
    return a * (1 - tz) + b * tz


def soft(row):
    mat = row.get("mat", "")
    if mat == "alpha" or row.get("shadow_only"):
        return True
    return mat.startswith("shader:") and any(s in mat for s in SOFT_SHADERS)


def in_area(meta, row):
    path = row["path"]
    if "/Player/" in path:
        return False
    if meta["area"] == "camp":
        return "/CampHub/" in path
    return "/CampHub/" not in path


def owner_key(row):
    o = row.get("o", [0, 0, 0])
    oo = "%.2f,%.2f,%.2f" % tuple(o)
    path = row["path"]
    if row["t"] == "mm":
        return path.rsplit("/", 1)[0] + "@" + oo
    if "scene_node" in row:
        return row["scene_node"]
    return path.rsplit("/", 1)[0] + "@" + oo


def short(path):
    parts = path.split("/")
    keep = [p for p in parts if p and not p.startswith("@") and p not in ("root",)]
    return "/".join(keep[-3:])


def on_faces(p, n, t, margin=SEAM_MARGIN):
    """Whether point p (with face normal n) is margin deep in faces of triangles t that face the same way: four points
    margin away from p in its plane each lie on such a face, in its plane within 1 cm (so a point on an edge between two
    of t's faces still counts, and one on an edge t only meets does not)."""
    e1, e2 = t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]
    fn = np.cross(e1, e2)
    ln = np.linalg.norm(fn, axis=1)
    keep = ln > 1e-9
    fn = fn[keep] / ln[keep, None]
    t0, e1, e2 = t[keep, 0], e1[keep], e2[keep]
    keep = (np.abs(np.einsum("ij,ij->i", p - t0, fn)) < 0.01) & (fn @ n > 0.995)
    if not keep.any():
        return False
    t0, e1, e2 = t0[keep], e1[keep], e2[keep]
    d11, d12, d22 = np.einsum("ij,ij->i", e1, e1), np.einsum("ij,ij->i", e1, e2), np.einsum("ij,ij->i", e2, e2)
    den = d11 * d22 - d12 * d12
    den = np.where(np.abs(den) < 1e-12, 1e-12, den)
    a = np.cross(n, [1.0, 0.0, 0.0] if abs(n[0]) < 0.9 else [0.0, 1.0, 0.0])
    a = a / np.linalg.norm(a)
    b = np.cross(n, a)
    for q in (p + margin * a, p - margin * a, p + margin * b, p - margin * b):
        d = q - t0
        dp1, dp2 = np.einsum("ij,ij->i", d, e1), np.einsum("ij,ij->i", d, e2)
        v = (d22 * dp1 - d12 * dp2) / den
        w = (d11 * dp2 - d12 * dp1) / den
        if not np.any((v >= -1e-4) & (w >= -1e-4) & (v + w <= 1.0 + 1e-4)):
            return False
    return True


def sample_tris(t, cell):
    """Points on triangles at about `cell` spacing, with each point's face normal."""
    if len(t) == 0:
        return np.zeros((0, 3), np.float32), np.zeros((0, 3), np.float32)
    e = np.stack([np.linalg.norm(t[:, 1] - t[:, 0], axis=1), np.linalg.norm(t[:, 2] - t[:, 1], axis=1), np.linalg.norm(t[:, 0] - t[:, 2], axis=1)], 1)
    k = np.clip(np.ceil(e.max(1) / cell), 1, 64).astype(np.int64)
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    n = np.where(ln > 1e-12, n / np.maximum(ln, 1e-12), 0.0)
    pts, nrm = [], []
    for kk in np.unique(k):
        sel = np.nonzero(k == kk)[0]
        ij = [(i, j) for i in range(kk + 1) for j in range(kk + 1 - i)]
        if kk == 1:
            ij = [(0, 0), (1, 0), (0, 1)]
            bary = np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1], [1 / 3, 1 / 3, 1 / 3]], np.float32)
        else:
            bary = np.array([[1 - (i + j) / kk, i / kk, j / kk] for i, j in ij], np.float32)
        tt = t[sel]
        p = np.einsum("bk,tkc->tbc", bary, tt).reshape(-1, 3)
        pts.append(p)
        nrm.append(np.repeat(n[sel], len(bary), axis=0))
    return np.concatenate(pts).astype(np.float32), np.concatenate(nrm).astype(np.float32)


def cell_keys(p, cell):
    q = np.floor(p / cell).astype(np.int64) + (1 << 20)
    return (q[:, 0] << 42) | (q[:, 1] << 21) | q[:, 2]


def inside(points, tris):
    """Ray parity along +x (with a tiny skew) of points against a triangle soup: True where inside."""
    if len(points) == 0 or len(tris) == 0:
        return np.zeros(len(points), bool)
    d = np.array([1.0, 1e-4, 2e-4])
    d /= np.linalg.norm(d)
    v0 = tris[:, 0].astype(np.float64)
    e1 = tris[:, 1].astype(np.float64) - v0
    e2 = tris[:, 2].astype(np.float64) - v0
    h = np.cross(d, e2)
    a = np.einsum("ij,ij->i", e1, h)
    ok = np.abs(a) > 1e-12
    v0, e1, e2, h, a = v0[ok], e1[ok], e2[ok], h[ok], a[ok]
    f = 1.0 / a
    counts = np.zeros(len(points), np.int64)
    for s in range(0, len(points), 256):
        P = points[s:s + 256].astype(np.float64)
        sv = P[:, None, :] - v0[None]
        u = f[None] * np.einsum("ptc,tc->pt", sv, h)
        q = np.cross(sv, e1[None])
        v = f[None] * (q @ d)
        w = f[None] * np.einsum("ptc,tc->pt", q, e2)
        hit = (u >= 0) & (u <= 1) & (v >= 0) & (u + v <= 1) & (w > 1e-6)
        counts[s:s + 256] = hit.sum(1)
    return counts % 2 == 1


def closed_enough(tris):
    """A mesh can answer inside tests when its edges are mostly shared by two faces."""
    if len(tris) < 4:
        return False
    v = np.round(tris.reshape(-1, 3) * 1000).astype(np.int64)
    keys = v[:, 0] * 73856093 ^ v[:, 1] * 19349663 ^ v[:, 2] * 83492791
    keys = keys.reshape(-1, 3)
    edges = np.sort(np.stack([np.stack([keys[:, 0], keys[:, 1]], 1), np.stack([keys[:, 1], keys[:, 2]], 1), np.stack([keys[:, 2], keys[:, 0]], 1)], 1).reshape(-1, 2), axis=1)
    _, counts = np.unique(edges, axis=0, return_counts=True)
    return (counts >= 2).mean() > 0.9


T0 = [0.0]


def _tick(label):
    import time
    if T0[0] == 0.0:
        T0[0] = time.time()
    print("clip_audit: %6.1f s %s" % (time.time() - T0[0], label), file=sys.stderr, flush=True)


def run(dump, cell=CELL):
    _tick("load")
    meta, tris, ground = load(dump)
    rows = meta["items"]
    owners = {}
    owner_rows = defaultdict(list)
    for idx, r in enumerate(rows):
        if r["t"] == "col" or r.get("n", 0) == 0 or not in_area(meta, r):
            continue
        key = owner_key(r)
        owner_rows[key].append(idx)
    keys = list(owner_rows)
    oid = {k: i for i, k in enumerate(keys)}
    pts_all, nrm_all, own_all = [], [], []
    otris = {}
    for k, idxs in owner_rows.items():
        hard = [i for i in idxs if not soft(rows[i])]
        if not hard:
            continue
        t = np.concatenate([tris[rows[i]["t0"]:rows[i]["t0"] + rows[i]["n"]] for i in hard])
        p, n = sample_tris(t, cell)
        facing = np.argmax(np.abs(n), axis=1) * 2 + (np.take_along_axis(n, np.argmax(np.abs(n), axis=1)[:, None], 1)[:, 0] > 0)
        _, first_in_cell = np.unique(cell_keys(p, cell) * 8 + facing, return_index=True)
        p, n = p[first_in_cell], n[first_in_cell]
        pts_all.append(p)
        nrm_all.append(n)
        own_all.append(np.full(len(p), oid[k], np.int64))
        otris[oid[k]] = t
    _tick("sampled")
    P = np.concatenate(pts_all)
    N = np.concatenate(nrm_all)
    O = np.concatenate(own_all)
    C = cell_keys(P, cell)
    info = {}
    for k, idxs in owner_rows.items():
        r0 = rows[idxs[0]]
        lo = np.min([rows[i]["aabb"][:3] for i in idxs], 0)
        hi = np.max([rows[i]["aabb"][3:] for i in idxs], 0)
        info[oid[k]] = {"owner": k, "name": short(r0.get("scene_node", r0["path"])), "row": r0.get("row", ""),
                        "kind": r0.get("dress_kind", "") or Path(r0.get("mesh", "")).stem or short(r0["path"]),
                        "mesh": r0.get("mesh", ""), "aabb": [round(float(x), 2) for x in list(lo) + list(hi)], "soft": all(soft(rows[i]) for i in idxs)}

    findings = {"clip": [], "coplanar": [], "ground": [], "naked": [], "stacked": []}

    _tick("pairs")
    no = len(info)
    cnt = np.maximum(np.bincount(O, minlength=no), 1)
    cen = np.stack([np.bincount(O, weights=P[:, k], minlength=no) / cnt for k in range(3)], 1)
    outward = np.bincount(O, weights=np.einsum("ij,ij->i", P - cen[O], N), minlength=no)
    global GLOBAL_SIGN
    GLOBAL_SIGN = -1.0 if np.median(outward / cnt) < 0 else 1.0
    sign = {o: GLOBAL_SIGN for o in range(no)}

    order = np.lexsort((O, C))
    Cs, Os = C[order], O[order]
    first = np.r_[True, (Cs[1:] != Cs[:-1]) | (Os[1:] != Os[:-1])]
    rep = order[first]
    rc, ro = C[rep], O[rep]
    pair_cells = defaultdict(int)
    pair_coplanar = defaultdict(int)
    pair_at = {}
    pair_points = {}
    for d in range(1, 6):
        same = rc[d:] == rc[:-d]
        i = np.flatnonzero(same)
        if len(i) == 0:
            break
        ia, ib = rep[i], rep[i + d]
        a, b = O[ia], O[ib]
        na, nb_ = N[ia], N[ib]
        cop = (np.einsum("ij,ij->i", na, nb_) > 0.995) & (np.abs(np.einsum("ij,ij->i", na, P[ib] - P[ia])) < 0.01)
        key = a * (1 << 32) + b
        uk, cnt = np.unique(key, return_counts=True)
        for k, c in zip(uk.tolist(), cnt.tolist()):
            pair_cells[(k >> 32, k & 0xFFFFFFFF)] += c
        uk, inv, cnt = np.unique(key[cop], return_inverse=True, return_counts=True)
        at = np.stack([np.bincount(inv, weights=P[ia[cop]][:, k], minlength=len(uk)) for k in range(3)], 1)
        for k, c, xyz in zip(uk.tolist(), cnt.tolist(), at):
            pk = (k >> 32, k & 0xFFFFFFFF)
            pair_coplanar[pk] += c
            pair_at[pk] = pair_at.get(pk, np.zeros(3)) + xyz
        for k, pa, pb in zip(key[cop].tolist(), ia[cop].tolist(), ib[cop].tolist()):
            pair_points.setdefault((k >> 32, k & 0xFFFFFFFF), []).append((pa, pb))
    for (a, b), c in pair_coplanar.items():
        if c < COPLANAR_MIN_CELLS:
            continue
        deep = [(pa, pb) for pa, pb in pair_points[(a, b)]
                if on_faces(P[pa], N[pa], otris[b]) or on_faces(P[pb], N[pb], otris[a])]
        if len(deep) >= COPLANAR_MIN_CELLS:
            at = np.mean([P[pa] for pa, _ in deep], axis=0)
            findings["coplanar"].append({"a": info[a], "b": info[b], "cells": len(deep), "edge_cells": c - len(deep),
                                         "area_m2": round(len(deep) * cell * cell, 2),
                                         "at": [round(float(v), 1) for v in at]})

    _tick("clip")
    by_owner = {}
    order_o = np.argsort(O, kind="stable")
    bounds = np.searchsorted(O[order_o], np.arange(len(info) + 1))
    for o in range(len(info)):
        by_owner[o] = order_o[bounds[o]:bounds[o + 1]]
    cand_pairs = [(a, b, c) for (a, b), c in pair_cells.items() if c >= 3 and not info[a]["soft"] and not info[b]["soft"]]
    _tick("clip candidates %d" % len(cand_pairs))
    for a, b, c in cand_pairs:
        res = []
        lo = np.maximum(np.array(info[a]["aabb"][:3]), np.array(info[b]["aabb"][:3])) - CLIP_REACH
        hi = np.minimum(np.array(info[a]["aabb"][3:]), np.array(info[b]["aabb"][3:])) + CLIP_REACH
        for x, y in ((a, b), (b, a)):
            ix = by_owner[x]
            iy = by_owner[y]
            ix = ix[np.all((P[ix] >= lo) & (P[ix] <= hi), axis=1)]
            iy = iy[np.all((P[iy] >= lo) & (P[iy] <= hi), axis=1)]
            if len(ix) == 0 or len(iy) == 0:
                res.append({"share": 0.0, "depth": 0.0, "at": [0, 0, 0]})
                continue
            if len(ix) > 800:
                ix = ix[np.linspace(0, len(ix) - 1, 800).astype(int)]
            if len(iy) > 3000:
                iy = iy[np.linspace(0, len(iy) - 1, 3000).astype(int)]
            px, py = P[ix].astype(np.float64), P[iy].astype(np.float64)
            d2 = np.maximum((px * px).sum(1)[:, None] + (py * py).sum(1)[None, :] - 2.0 * px @ py.T, 0.0)
            nn = d2.argmin(1)
            dist = np.sqrt(d2[np.arange(len(ix)), nn])
            behind = np.einsum("ij,ij->i", P[ix] - P[iy][nn], N[iy][nn]) * sign[y] < -0.02
            ins = behind & (dist < CLIP_REACH)
            depth = float(dist[ins].max()) if ins.any() else 0.0
            share = float(ins.sum()) / max(1, len(by_owner[x]))
            res.append({"share": round(share, 3), "depth": round(depth, 2), "at": [round(float(v), 1) for v in (P[ix][ins].mean(0) if ins.any() else [0, 0, 0])]})
        best = max(res, key=lambda r: r["depth"])
        if best["share"] >= CLIP_MIN_SHARE and best["depth"] >= CLIP_MIN_DEPTH:
            findings["clip"].append({"a": info[a], "b": info[b], "shared_cells": c, "a_in_b": res[0], "b_in_a": res[1]})

    _tick("stacked")
    by_mesh = defaultdict(list)
    for k, idxs in owner_rows.items():
        r0 = rows[idxs[0]]
        if r0.get("mesh"):
            by_mesh[(r0["mesh"], r0["path"].rsplit("/", 1)[0])].append((np.array(r0.get("o", [0, 0, 0])), oid[k]))
    for (mesh, _), lst in by_mesh.items():
        if len(lst) < 2:
            continue
        arr = np.array([x[0] for x in lst])
        q = np.floor(arr / STACK_M).astype(np.int64)
        seen = {}
        for i, cc in enumerate(map(tuple, q)):
            if cc in seen:
                findings["stacked"].append({"a": info[lst[seen[cc]][1]], "b": info[lst[i][1]], "mesh": mesh})
            else:
                seen[cc] = i

    _tick("ground")
    if ground is not None:
        gap_all = P[:, 1] - ground_at(ground, P[:, 0], P[:, 2])
        for o in range(len(info)):
            sel = by_owner[o]
            if len(sel) == 0:
                continue
            g = gap_all[sel]
            p = P[sel]
            height = float(p[:, 1].max() - p[:, 1].min())
            span = float(max(np.ptp(p[:, 0]), np.ptp(p[:, 2])))
            if span > 60 or info[o]["soft"]:
                continue
            if g.min() > 0.12 and g.min() < 6.0:
                findings["ground"].append({"kind": "floating", "o": info[o], "gap_m": round(float(g.min()), 2), "height_m": round(height, 2)})
                continue
            if g.max() < -0.05:
                findings["ground"].append({"kind": "buried", "o": info[o], "top_below_m": round(float(-g.max()), 2), "height_m": round(height, 2)})
                continue
            foot = p[:, 1] < p[:, 1].min() + max(0.12, 0.1 * height)
            if foot.sum() >= 8 and height > 0.4:
                fg = g[foot]
                share = float((fg > HANG_M).mean())
                if share > HANG_SHARE:
                    findings["ground"].append({"kind": "hanging", "o": info[o], "share": round(share, 2), "max_gap_m": round(float(fg.max()), 2), "height_m": round(height, 2)})
            flat = (np.abs(g) < 0.02) & (N[sel][:, 1] * GLOBAL_SIGN > 0.995)
            if flat.sum() >= COPLANAR_MIN_CELLS:
                findings["ground"].append({"kind": "ground_coplanar", "o": info[o], "area_m2": round(float(flat.sum()) * cell * cell, 2)})

    _tick("naked")
    occupied = np.unique(C)
    floor_y = float(meta["ball"][1]) - 1.5

    def has(keys):
        at = np.clip(np.searchsorted(occupied, keys), 0, len(occupied) - 1)
        return occupied[at] == keys

    ck = np.floor(P / COARSE).astype(np.int64) + (1 << 20)
    ckey = (ck[:, 0] << 42) | (ck[:, 1] << 21) | ck[:, 2]
    corder = np.argsort(ckey, kind="stable")
    cs = ckey[corder]

    def near(lo, hi):
        a = np.floor(lo / COARSE).astype(np.int64) + (1 << 20)
        b = np.floor(hi / COARSE).astype(np.int64) + (1 << 20)
        out = []
        for x in range(a[0], b[0] + 1):
            for y in range(a[1], b[1] + 1):
                for z in range(a[2], b[2] + 1):
                    k = (x << 42) | (y << 21) | z
                    i0, i1 = np.searchsorted(cs, k), np.searchsorted(cs, k, side="right")
                    if i1 > i0:
                        out.append(corder[i0:i1])
        return np.concatenate(out) if out else np.zeros(0, np.int64)

    nb = [(dx, dy, dz) for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2) for dz in (-2, -1, 0, 1, 2)]
    reach = int(math.ceil(NAKED_M / cell))
    nb = [d for d in nb if max(map(abs, d)) <= reach]
    for idx, r in enumerate(rows):
        if r["t"] != "col" or r.get("terrain") or r.get("n", 0) == 0 or not in_area(meta, r):
            continue
        if "/Ground/Tile" in r["path"]:
            continue
        t = tris[r["t0"]:r["t0"] + r["n"]]
        p, n = sample_tris(t, cell)
        keep = n[:, 1] > -0.5
        if ground is not None:
            keep &= p[:, 1] > ground_at(ground, p[:, 0], p[:, 2]) + 0.1
        else:
            keep &= p[:, 1] > floor_y + 0.1
        p, n = p[keep], n[keep]
        if len(p) == 0:
            continue
        _, one = np.unique(cell_keys(p, cell), return_index=True)
        p, n = p[one], n[one]
        cen = p.mean(0)
        n = n * (1.0 if np.mean(np.einsum("ij,ij->i", p - cen, n)) >= 0 else -1.0)
        q = np.floor(p / cell).astype(np.int64) + (1 << 20)
        covered = np.zeros(len(p), bool)
        for dx, dy, dz in nb:
            k = ((q[:, 0] + dx) << 42) | ((q[:, 1] + dy) << 21) | (q[:, 2] + dz)
            covered |= has(k)
        if ground is not None:
            covered |= np.abs(p[:, 1] - ground_at(ground, p[:, 0], p[:, 2])) < NAKED_M
        naked = ~covered
        if naked.sum() * cell * cell < 0.5:
            continue
        pn, nn = p[naked], n[naked]
        if len(pn) > 400:
            pick = np.linspace(0, len(pn) - 1, 400).astype(int)
            pn, nn = pn[pick], nn[pick]
        centre = pn + nn * BALL_R
        local = near(centre.min(0) - BALL_R - FELT_M - COARSE, centre.max(0) + BALL_R + FELT_M + COARSE)
        gap = np.full(len(centre), np.inf)
        if len(local):
            lp = P[local].astype(np.float64)
            for s0 in range(0, len(lp), 20000):
                chunk = lp[s0:s0 + 20000]
                d2 = (centre * centre).sum(1)[:, None] + (chunk * chunk).sum(1)[None, :] - 2.0 * centre @ chunk.T
                gap = np.minimum(gap, np.sqrt(np.maximum(d2.min(1), 0.0)))
        if ground is not None:
            gap = np.minimum(gap, np.maximum(centre[:, 1] - ground_at(ground, centre[:, 0], centre[:, 2]), 0.0))
        gap -= BALL_R
        felt = gap > FELT_M
        felt_m2 = float(felt.mean()) * float(naked.sum()) * cell * cell
        if ground is not None:
            rolling = centre[:, 1] - ground_at(ground, centre[:, 0], centre[:, 2]) < ROLL_M
        else:
            rolling = centre[:, 1] < floor_y + 1.5 + ROLL_M
        roll_m2 = float((felt & rolling).mean()) * float(naked.sum()) * cell * cell
        if felt_m2 >= 0.5:
            pf = pn[felt]
            findings["naked"].append({"collider": short(r["path"]), "path": r["path"], "shape": r["shape"], "hidden": r.get("hidden", False), "row": r.get("row", ""),
                                      "felt_m2": round(felt_m2, 1), "rolling_m2": round(roll_m2, 1),
                                      "rolling_gap_max_m": round(float(np.minimum(gap[felt & rolling], 9.9).max()), 2) if (felt & rolling).any() else 0.0, "gap_max_m": round(float(np.minimum(gap[felt], 9.9).max()), 2),
                                      "gap_p50_m": round(float(np.median(np.minimum(gap[felt], 9.9))), 2), "share": round(float(felt.mean() * naked.mean()), 2),
                                      "felt_aabb": [round(float(v), 1) for v in list(pf.min(0)) + list(pf.max(0))], "aabb": r["aabb"],
                                      "felt_pts": [[round(float(v), 1) for v in q] + [round(float(gg), 2)] for q, gg in zip(pf[::max(1, len(pf) // 40)], gap[felt][::max(1, len(pf) // 40)])]})

    findings["clip"].sort(key=lambda f: -max(f["a_in_b"]["share"], f["b_in_a"]["share"]))
    findings["coplanar"].sort(key=lambda f: -f["cells"])
    findings["naked"].sort(key=lambda f: -f["felt_m2"])
    summary = {k: len(v) for k, v in findings.items()}
    return {"area": meta["area"], "seed": meta["seed"], "owners": len(info), "points": int(len(P)), "cell": cell, "summary": summary, "findings": findings}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        print(__doc__)
        sys.exit(2)
    rep = run(args[0], float(opts.get("cell", CELL)))
    out = opts.get("out", str(Path(args[0]) / "audit.json"))
    Path(out).write_text(json.dumps(rep, indent=1))
    print(json.dumps({"area": rep["area"], "seed": rep["seed"], "owners": rep["owners"], "summary": rep["summary"]}))


if __name__ == "__main__":
    main()
