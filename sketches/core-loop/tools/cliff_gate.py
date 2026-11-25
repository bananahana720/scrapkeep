"""Cliff round-3 preconstruction gate runner (CLIFF-R3 section 3). Read-only analysis.

  python3 tools/cliff_gate.py --export <dir from cliff_gate_export.gd> --proposal <proposal.json> --out <dir> [--baseline]

Builds the proposed crown and hull solids from the proposal table, replaces the source's crown and
hull triangles with them in the frozen scene triangles, depth-tests the whole scene at the launch and
overview cameras, and writes per-unit masks (PNG, 1 = visible), the section 3 metrics, the dam
overlap test and the source, camera and input hashes to <out>/gate.json. --baseline runs the
unchanged R2 solids through the same path, which is the validation against the native masks.
"""
import argparse
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_gate_form as F
import cliff_gate_vis as V

DAM_SKIP = ("SandstoneShoulders", "Cottonwood", "SpillSheets", "Tailrace", "WaterMist")
NAMES = {6: "wC", 7: "wS", 8: "wH", 15: "eC", 16: "eS", 17: "eH"}
TARGETS = {
    "launch": {"wS": ("R12", 12, 48), "eS": ("R12", 12, 48), "wH": ("R24", 24, 48), "eH": ("R24", 24, 48)},
    "overview": {"wC": ("R12", 12, 24), "eC": ("R12", 12, 24), "wH": ("R12", 12, 24), "eH": ("R12", 12, 24), "wS": ("R8", 8, 24), "eS": ("R6", 6, 12)},
}
AREA_UNITS = {"launch": ["wS", "wH", "eS", "eH"], "overview": ["wC", "wS", "wH", "eC", "eS", "eH"]}


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def levels_y(hull):
    h = hull["h"]
    i = hull["i"]
    side = hull["side"]
    bottom = 12.0 - h * 0.2 + 0.2
    root_y = hull["roots"][0][1]

    def f(k):
        top = root_y + 0.15 + 0.4 + 0.4 * math.sin(k * 2.7 + i)
        span = top - bottom
        return [bottom, bottom + span * 0.34 + 1.2 * math.sin(k * 2.1 + i), bottom + span * 0.68 + 1.2 * math.sin(k * 1.7 + side), top]
    return f


def hull_variant(hull):
    return (hull["i"] + (0 if hull["side"] < 0 else 2)) % 4


def proposed_units(meta, prop, base_u=None):
    tris = []
    for c in meta["rim"]:
        tris.append(F.crown_world(c, prop["crowns"][c["variant"]]))
    for hi, h in enumerate(meta["hulls"]):
        if "hulls" not in prop:
            tris.append(base_u[18 + hi])
            continue
        tris.append(F.hull_world(h, prop["hulls"][hull_variant(h)], levels_y(h)))
    return tris


def baseline_units(meta, units):
    out = []
    o = 0
    for u in meta["units"]:
        out.append(units[o:o + u["tris"]])
        o += u["tris"]
    return out


def run(export, prop_path, outdir, baseline):
    meta = json.load(open(os.path.join(export, "meta.json")))
    scene = np.fromfile(os.path.join(export, "scene.f32"), np.float32).reshape(-1, 3, 3).astype(np.float64)
    units = np.fromfile(os.path.join(export, "units.f32"), np.float32).reshape(-1, 3, 3).astype(np.float64)
    base_u = baseline_units(meta, units)
    ids = []
    for gi, g in enumerate(meta["groups"]):
        ids += [gi] * g["tris"]
    scene_ids = np.array(ids, np.int32)
    prop = None if baseline else json.load(open(prop_path))
    cand_u = base_u if baseline else proposed_units(meta, prop, base_u)

    def assemble(unit_list):
        T = [scene] + unit_list
        I = [scene_ids] + [np.full(len(u), 1000 + k, np.int32) for k, u in enumerate(unit_list)]
        return np.concatenate(T), np.concatenate(I)

    os.makedirs(outdir, exist_ok=True)
    dam_ids = [gi for gi, g in enumerate(meta["groups"]) if "/SpillwayScenery/" in g["path"] and not any(s in g["path"] for s in DAM_SKIP)]
    report = {"baseline_run": baseline, "dam_groups": [meta["groups"][g]["path"] for g in dam_ids], "cameras": {}, "hashes": {}}
    for k, v in meta["hashes"].items():
        report["hashes"]["source:" + k] = v
    report["hashes"]["scene.f32"] = sha(os.path.join(export, "scene.f32"))
    report["hashes"]["units.f32"] = sha(os.path.join(export, "units.f32"))
    if prop_path:
        report["hashes"]["proposal"] = sha(prop_path)
    report["hashes"]["camera:cliff_gate_vis.py"] = sha(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cliff_gate_vis.py"))
    report["camera_constants"] = {k: {"eye": v[0], "target": v[1], "fov": v[2]} for k, v in V.CAMERAS.items()}
    Tb, Ib = assemble(base_u)
    Tc, Ic = assemble(cand_u)
    ok_all = True
    for cam in V.CAMERAS:
        bid, _ = V.rasterise(Tb, Ib, V.CAMERAS[cam])
        cid, _ = V.rasterise(Tc, Ic, V.CAMERAS[cam])
        np.save(os.path.join(outdir, f"id-{cam}-cand.npy"), cid)
        rec = {"units": {}}
        dam_b = np.isin(bid, dam_ids)
        dam_c = np.isin(cid, dam_ids)
        cliff_c = cid >= 1000
        rec["dam_overlap_new_cliff_on_base_dam_px"] = int((cliff_c & dam_b).sum())
        rec["dam_lost_px"] = int((dam_b & ~dam_c).sum())
        rec["dam_base_px"] = int(dam_b.sum())
        for ui, name in NAMES.items():
            mb = bid == 1000 + ui
            mc = cid == 1000 + ui
            Image.fromarray((mc * 255).astype(np.uint8)).save(os.path.join(outdir, f"mask-{cam}-{name}.png"))
            eb, ec = V.exposure(mb), V.exposure(mc)
            row = {"base_area": eb["area"], "cand_area": ec["area"], "area_frac": ec["area"] / max(eb["area"], 1), "max_h": ec["max_h"], "components": ec["n_components"]}
            for t in (6, 8, 12, 24):
                row[f"R{t}_cand"], _ = V.run_r(mc, ec, t)
                row[f"R{t}_base"], _ = V.run_r(mb, eb, t)
            hidden = mb & ~mc
            occ = np.unique(cid[hidden])
            row["hidden_by"] = [meta["groups"][o]["path"].split("/")[-1] if 0 <= o < len(meta["groups"]) else f"unit{o - 1000}" for o in occ[:12] if o >= -1]
            rec["units"][name] = row
        for name, (key, t, need) in TARGETS[cam].items():
            row = rec["units"][name]
            row["target"] = f"{key}>={need}"
            row["pass_run"] = row[f"R{t}_cand"] >= need
            row["pass_area"] = (row["area_frac"] >= 0.60) if name in AREA_UNITS[cam] else True
            ok_all = ok_all and row["pass_run"] and row["pass_area"]
        rec["pass_dam"] = rec["dam_overlap_new_cliff_on_base_dam_px"] == 0 and rec["dam_lost_px"] == 0
        ok_all = ok_all and rec["pass_dam"]
        report["cameras"][cam] = rec
    report["visibility_pass"] = bool(ok_all)
    json.dump(report, open(os.path.join(outdir, "gate.json"), "w"), indent=1)
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True)
    ap.add_argument("--proposal")
    ap.add_argument("--out", required=True)
    ap.add_argument("--baseline", action="store_true")
    a = ap.parse_args()
    r = run(a.export, a.proposal, a.out, a.baseline)
    for cam, rec in r["cameras"].items():
        print(cam, "dam overlap", rec["dam_overlap_new_cliff_on_base_dam_px"], "lost", rec["dam_lost_px"])
        for n, row in rec["units"].items():
            print(" ", n, {k: (round(v, 3) if isinstance(v, float) else v) for k, v in row.items() if k not in ("hidden_by",)})
    print("visibility_pass", r["visibility_pass"])
