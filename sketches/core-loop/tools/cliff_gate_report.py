"""Combined cliff round-3 preconstruction report (CLIFF-R3 sections 2, 3 and 5). Read-only analysis.

  python3 tools/cliff_gate_report.py --export <dir> --proposal <proposal.json> --out <dir>

Runs the form measures for all 18 crowns and 16 shoulder hulls of the proposal (plan sections, broad
faces, retreat, nesting, roots, envelope, neighbour difference, triangle budget), then the visibility
and dam-overlap gate from cliff_gate.py, and writes <out>/report.json. Exit code 0 only if everything passes.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from shapely.geometry import Point, Polygon

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_gate as G
import cliff_gate_form as F

APRON_X = (-113.0, 160.0)
APRON_Z = (-186.0, 186.0)
BROAD = {"crown_span": 4.0, "hull_span": 6.0}


def crown_checks(meta, prop):
    rows = []
    fam = {}
    tri_total = 0
    for ci, c in enumerate(meta["rim"]):
        v = c["variant"]
        pv = prop["crowns"][v]
        t = F.crown_world(c, pv)
        tri_total += len(t)
        crest, add = c["crest"], F.RIM_ADD[v]
        r = {"i": ci, "side": c["side"], "family": c["family"], "unit": "CSH"[v], "fail": []}
        for name, y in (("h0", crest + 0.01), ("half", crest + add / 2)):
            m = F.plan_measures(F.slice_polygon(t, y))
            r[name] = {k: round(m[k], 3) for k in ("longest_frac", "axis_frac", "occupancy", "perimeter")}
            if m["longest_frac"] > 0.25:
                r["fail"].append(f"{name} run")
            if m["axis_frac"] > 0.35:
                r["fail"].append(f"{name} axis")
            if m["occupancy"] > 0.90:
                r["fail"].append(f"{name} occ")
        pat, _ = F.patches(t, crest + 0.01, (0, 0), 4.0)
        q = F.qualifying(pat, 4.0, 0.08)
        r["faces"] = len(q)
        r["spans"] = [round(p["span"], 1) for p in q]
        r["az"] = [round(p["azimuth"]) for p in q]
        if len(q) < 3:
            r["fail"].append("faces<3")
        if q:
            ratio = max(p["span"] for p in q) / min(p["span"] for p in q)
            r["span_ratio"] = round(ratio, 2)
            if ratio < 1.5:
                r["fail"].append("span ratio")
            adj = F.adjacent_angles(t, q)
            r["adj"] = adj
            if any(a < 12 or a > 65 for a in adj):
                r["fail"].append("adjacent angle")
        rings = F.crown_rings(c, pv)
        m = F.corner_slopes([tuple(p) for p in pv["plan"]], pv["batter"])
        rets = [float(np.hypot(*m[j]) * min(add / 2, rings[4][j][1])) for j in range(6)]
        r["retreat_spread_m"] = round(max(rets) - min(rets), 2)
        if max(rets) - min(rets) < 1.0:
            r["fail"].append("retreat")
        polys = [Polygon([(p[0], p[2]) for p in ring]) for ring in rings[1:]]
        nested = all(a.is_valid and a.buffer(1e-6).contains(b) for a, b in zip(polys, polys[1:]))
        r["nested"] = bool(nested)
        if not nested:
            r["fail"].append("nesting")
        over = max(rings[4][j][1] - F.crest_rise(v, rings[4][j][2] / c["width"] + 0.5) for j in range(12))
        r["top_over_ceiling_m"] = round(float(over), 4)
        if over > 1e-6:
            r["fail"].append("ceiling")
        half_d = c["depth"] / 2
        ex = max(abs(p[0]) for ring in rings for p in ring)
        r["max_abs_local_x"] = round(ex, 2)
        if ex > half_d + 1e-6:
            r["fail"].append("envelope")
        wx = t[:, :, 0]
        if wx.min() < APRON_X[1] and wx.max() > APRON_X[0] and t[:, :, 2].min() < APRON_Z[1] and t[:, :, 2].max() > APRON_Z[0]:
            r["fail"].append("apron")
        fam.setdefault((c["side"], c["family"]), []).extend(p["azimuth"] for p in q)
        rows.append(r)
    fam_rows = {f"{k[0]}:{k[1]}": len(F.distinct_dirs(a)) for k, a in fam.items()}
    fam_fail = [k for k, n in fam_rows.items() if n < 6]
    return rows, fam_rows, fam_fail, tri_total


def hull_checks(meta, prop):
    rows = []
    tri_total = 0
    doms = {}
    for hi, h in enumerate(meta["hulls"]):
        v = G.hull_variant(h)
        ph = prop["hulls"][v]
        ly = G.levels_y(h)
        t = F.hull_world(h, ph, ly)
        tri_total += len(t)
        ymin, ymax = t[:, :, 1].min(), t[:, :, 1].max()
        Ht = ymax - ymin
        r = {"i": hi, "side": h["side"], "variant": v, "fail": []}
        for fr in (0.35, 0.70):
            m = F.plan_measures(F.slice_polygon(t, ymin + fr * Ht))
            r[f"s{int(fr * 100)}"] = {k: round(m[k], 3) for k in ("longest_frac", "axis_frac", "occupancy", "perimeter")}
            if m["longest_frac"] > 0.25:
                r["fail"].append(f"s{int(fr * 100)} run")
            if m["axis_frac"] > 0.35:
                r["fail"].append(f"s{int(fr * 100)} axis")
            if m["occupancy"] > 0.90:
                r["fail"].append(f"s{int(fr * 100)} occ")
        pat, _ = F.patches(t, ymin + 1e-3, (0, 0), 6.0)
        q = F.qualifying(pat, 6.0, 0.08)
        r["faces"] = len(q)
        r["spans"] = [round(p["span"], 1) for p in q]
        if len(q) < 3:
            r["fail"].append("faces<3")
        if q:
            ratio = max(p["span"] for p in q) / min(p["span"] for p in q)
            r["span_ratio"] = round(ratio, 2)
            if ratio < 1.5:
                r["fail"].append("span ratio")
            adj = F.adjacent_angles(t, q)
            r["adj"] = adj
            if any(a < 12 or a > 65 for a in adj):
                r["fail"].append("adjacent angle")
            dom = max(q, key=lambda p: p["area"])
            big = max(pat, key=lambda p: p["area"])
            az = dom["azimuth"] if h["side"] < 0 else 180 - dom["azimuth"]
            r["dominant"] = {"az_plan_frame": round(az, 1), "share": round(dom["share"], 3), "is_largest_face": big is dom}
            doms[hi] = (az, dom["share"])
        m = F.corner_slopes([tuple(p) for p in ph["plan"]], ph["batter"])
        dy = 0.35 * Ht
        rets = [math.hypot(*m[j]) * dy for j in range(10) if ph["plan"][j][0] < 0]
        r["retreat_spread_m"] = round(max(rets) - min(rets), 2) if len(rets) >= 2 else 0.0
        if r["retreat_spread_m"] < 2.0:
            r["fail"].append("retreat")
        sl = F.slice_polygon(t, h["roots"][0][1] + 0.15)
        worst = 1e9
        for rt in h["roots"]:
            worst = min(worst, sl.exterior.distance(Point(rt[0], rt[2])) if sl.contains(Point(rt[0], rt[2])) else -1.0)
        r["root_support_min_m"] = round(worst, 2)
        if worst < 2.0:
            r["fail"].append("root support")
        rings = F.hull_rings(h, ph, ly)
        polys = [Polygon([(p[0], p[2]) for p in ring]) for ring in rings]
        nested = all(a.is_valid and b.is_valid and a.buffer(1e-6).contains(b) for a, b in zip(polys, polys[1:]))
        r["nested"] = bool(nested)
        if not nested:
            r["fail"].append("nesting")
        d0, d1, z0, z1 = _env(meta, hi)
        ok = True
        for ring in rings:
            for p in ring:
                d = h["side"] * (p[0] - h["x"])
                e = p[2] - h["z"]
                if d < d0 - 1e-6 or d > d1 + 1e-6 or e < z0 - 1e-6 or e > z1 + 1e-6:
                    ok = False
        r["in_r2_envelope"] = ok
        if not ok:
            r["fail"].append("envelope")
        if t[:, :, 0].min() < APRON_X[1] and t[:, :, 0].max() > APRON_X[0] and t[:, :, 2].min() < APRON_Z[1] and t[:, :, 2].max() > APRON_Z[0]:
            r["fail"].append("apron")
        rows.append(r)
    nb = []
    for hi in range(len(meta["hulls"]) - 1):
        a, b = meta["hulls"][hi], meta["hulls"][hi + 1]
        if a["side"] != b["side"] or hi not in doms or hi + 1 not in doms:
            continue
        da = F.angle_between(doms[hi][0], doms[hi + 1][0])
        ds = abs(doms[hi][1] - doms[hi + 1][1])
        ok = da >= 12.0 and ds >= 0.05
        nb.append({"pair": [hi, hi + 1], "d_az": round(da, 1), "d_share_pts": round(ds * 100, 1), "pass": bool(ok)})
    return rows, nb, tri_total


def _env(meta, hi):
    h = meta["hulls"][hi]
    e = meta["envelopes"][hi]
    ds = sorted([h["side"] * (x - h["x"]) for x in (e[0], e[0] + e[3])])
    return ds[0], ds[1], e[2] - h["z"], e[2] + e[5] - h["z"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True)
    ap.add_argument("--proposal", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    meta = json.load(open(os.path.join(a.export, "meta.json")))
    prop = json.load(open(a.proposal))
    crowns, fam_rows, fam_fail, ct = crown_checks(meta, prop)
    hulls, nb, ht = hull_checks(meta, prop)
    vis = G.run(a.export, a.proposal, a.out, False)
    form_fail = [f"crown {r['i']}: {r['fail']}" for r in crowns if r["fail"]] + [f"hull {r['i']}: {r['fail']}" for r in hulls if r["fail"]]
    form_fail += [f"family {k} distinct dirs {fam_rows[k]}" for k in fam_fail]
    form_fail += [f"neighbour {n['pair']}" for n in nb if not n["pass"]]
    budget = {"crown_tris": ct, "crown_verts_unwelded": ct * 3, "hull_tris": ht, "hull_verts_unwelded": ht * 3, "crown_cap_T": 2376, "hull_cap_T": 1536}
    budget_ok = ct <= 2376 and ht <= 1536
    ok = not form_fail and vis["visibility_pass"] and budget_ok
    rep = {"pass": bool(ok), "form_fail": form_fail, "budget": budget, "budget_ok": budget_ok, "family_distinct_dirs": fam_rows,
           "neighbour": nb, "crowns": crowns, "hulls": hulls, "visibility_pass": vis["visibility_pass"], "hashes": vis["hashes"],
           "camera_constants": vis["camera_constants"],
           "dam": {c: {"overlap_px": r["dam_overlap_new_cliff_on_base_dam_px"], "lost_px": r["dam_lost_px"]} for c, r in vis["cameras"].items()}}
    json.dump(rep, open(os.path.join(a.out, "report.json"), "w"), indent=1)
    print("form_fail", form_fail)
    print("budget", budget, budget_ok)
    print("dam", rep["dam"], "visibility_pass", vis["visibility_pass"])
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
