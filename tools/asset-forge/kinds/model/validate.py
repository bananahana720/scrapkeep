"""Model validator (runs outside Blender, stdlib only).

validate(vdir, params, result, pack) -> list of checks {id, state, value, detail}.
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402

GROUND_TOL = 0.005
OFF_PALETTE_TOL = 0.05   # sRGB euclidean distance to a palette colour or palette mix
OFF_PALETTE_FAIL = 0.01  # share of painted area


def validate(vdir, params, result, pack):
    vdir = Path(vdir)
    checks = []
    add = lambda *a: checks.append(fc.check(*a))  # noqa: E731
    status = result.get("status")
    if status != "ok":
        add("build", "fail", status, (result.get("error") or "the recipe did not build")[-1500:])
        return checks
    add("build", "pass", "ok", "recipe built and exported")
    for w in result.get("warnings", []):
        add("harness_warning", "warn", None, w)
    m = result.get("measure")
    if not m:
        add("measure", "fail", None, "no measurements: " + (result.get("measure_error") or "unknown")[-400:])
        return checks

    glb = vdir / "out" / (params["asset"] + ".glb")
    info = None
    if glb.is_file():
        try:
            info = fc.glb_info(glb)
        except Exception as exc:  # noqa: BLE001
            add("glb_readback", "fail", None, "cannot read the GLB: %r" % exc)
    else:
        add("glb_readback", "fail", None, "out/%s.glb is missing" % params["asset"])

    lo, hi = params["band"]
    tris = info["triangles"] if info else m["triangles"]
    if lo <= tris <= hi:
        add("triangle_band", "pass", tris, "%d tris inside %d to %d" % (tris, lo, hi))
    else:
        add("triangle_band", "fail", tris, "%d tris outside the %s band %d to %d" % (tris, params["category"], lo, hi))

    if info:
        if info["triangles"] == m["triangles"]:
            add("glb_readback", "pass", info["triangles"], "GLB triangles match Blender")
        else:
            add("glb_readback", "warn", info["triangles"], "GLB has %d tris, Blender counted %d" % (info["triangles"], m["triangles"]))
        add("glb_nodes", "info", info["nodes"], "%d nodes, %d mesh nodes, %d bytes" % (info["nodes"], info["mesh_nodes"], info["bytes"]))
        cap = params["max_draw_calls"]
        dc = info["draw_calls"]
        state = "pass" if dc <= cap else "warn" if dc <= 2 * cap else "fail"
        add("draw_calls", state, dc, "%d primitives (draw calls); the %s cap is %d" % (dc, params["category"], cap))
        vcap = params.get("max_vertices")
        if vcap:
            vs = info["vertices"]
            add("vertices", "pass" if vs <= vcap else "fail", vs, "%d vertices; the %s budget class allows %d" % (vs, params["category"], vcap))
        need = params.get("profile", {}).get("required_nodes", [])
        missing = [n for n in need if n not in info["node_names"]]
        if need:
            add("required_nodes", "fail" if missing else "pass", missing or need,
                "missing node(s) %s, which the game looks up by name" % ", ".join(missing) if missing else "nodes %s present" % ", ".join(need))
        unknown = [n for n in info["materials"] if n.split(".")[0] not in params["slots"]]
        if unknown:
            add("glb_materials", "fail", unknown, "GLB materials not in the slot list: %s" % ", ".join(unknown))

    # palette: slots first, then vertex colours
    problems = []
    if m["unknown_materials"]:
        problems.append("materials outside common.py's slots: " + ", ".join(m["unknown_materials"]))
    total_area = sum(m["area_by_slot"].values()) + m["unslotted_area"]
    if m["unslotted_area"] > 0:
        problems.append("%.0f%% of the surface has no material" % (100 * m["unslotted_area"] / max(total_area, 1e-9)))
    if problems:
        add("palette_slots", "fail", None, "; ".join(problems))
    else:
        add("palette_slots", "pass", sorted(m["area_by_slot"]), "every surface uses a common.py slot")

    palette = params["palette"]
    specs = params.get("slot_specs", {})
    bad_fixed = [s for s in m["area_by_slot"]
                 if s in specs and not specs[s].get("vc") and specs[s].get("color") not in palette and specs[s].get("color") != "ffffff"]
    off_area = 0.0
    off = []
    painted = 0.0
    for slot, cols in m["vertex_colour_area"].items():
        for hexcol, area in cols.items():
            painted += area
            if hexcol == "missing":
                off_area += area
                off.append("%s: no colour attribute" % slot)
                continue
            d = fc.palette_distance(hexcol, palette.values())
            if d > OFF_PALETTE_TOL:
                off_area += area
                off.append("#%s on %s is %.2f from the palette" % (hexcol, slot, d))
    share = off_area / painted if painted else 0.0
    if bad_fixed:
        add("palette_colours", "fail", bad_fixed, "slots whose fixed colour is not a palette role: %s" % ", ".join(bad_fixed))
    elif share > OFF_PALETTE_FAIL:
        add("palette_colours", "fail", round(share, 3), "%.0f%% of painted area is off palette: %s" % (100 * share, "; ".join(off[:4])))
    elif off:
        add("palette_colours", "warn", round(share, 4), "small off-palette area: %s" % "; ".join(off[:4]))
    else:
        add("palette_colours", "pass", len(sum(([*c] for c in m["vertex_colour_area"].values()), [])), "every painted colour is a palette role or mix")

    profile = params.get("profile", {})
    centre = profile.get("pivot") == "centre"
    if profile.get("max_radius") is not None:
        r, cap = m.get("max_radius"), profile["max_radius"]
        add("radius", "pass" if r is not None and r <= cap else "fail", None if r is None else round(r, 4),
            "geometry reaches %.3f m from the origin; the cap is %.3f m" % (r if r is not None else -1, cap))
    lowest = m["lowest_z"]
    if centre:
        add("grounding", "info", round(lowest, 4), "centre-pivot asset (%s): no ground contact expected" % params["category"])
    elif abs(lowest) <= GROUND_TOL:
        add("grounding", "pass", round(lowest, 4), "lowest point z = %.4f m" % lowest)
    elif lowest < 0:
        add("grounding", "fail", round(lowest, 4), "sunk %.3f m below z = 0" % -lowest)
    else:
        add("grounding", "fail", round(lowest, 4), "floats %.3f m above z = 0" % lowest)

    cx, cy = m["center_xy"]
    off_c = (cx * cx + cy * cy) ** 0.5
    foot = max(m["size"][0], m["size"][1])
    tol = max(0.05, 0.1 * foot)
    state = "pass" if off_c <= tol else "warn" if off_c <= 3 * tol else "fail"
    add("centred", state, round(off_c, 3), "bounding box centre is %.3f m off x=y=0 (tolerance %.3f)" % (off_c, tol))
    ro = m["root_origin"]
    add("origin", "info", [round(x, 3) for x in ro], "root object origin")

    if centre:
        add("floating_parts", "info", len(m["floating"]), "centre-pivot asset: ground support not checked")
    elif m["floating"]:
        add("floating_parts", "fail", len(m["floating"]),
            "%d part(s) touch neither the ground nor another part, e.g. %s at z %.2f to %.2f" % (
                len(m["floating"]), m["floating"][0]["object"], m["floating"][0]["min"][2], m["floating"][0]["max"][2]))
    else:
        add("floating_parts", "pass", 0, "%d islands, all supported" % m["islands"])

    nm = m["nonmanifold_edges"]
    add("non_manifold", "pass" if nm == 0 else "warn", nm, "%d of %d edges are open or shared by 3+ faces" % (nm, m["edges"]))

    longest = max(m["size"])
    slo, shi = params["size_range"]
    if slo <= longest <= shi:
        add("size", "pass", round(longest, 3), "longest edge %.2f m inside %.2f to %.2f" % (longest, slo, shi))
    elif longest < slo / 10 or longest > shi * 10:
        add("size", "fail", round(longest, 3), "longest edge %.3f m is wildly outside %.2f to %.2f" % (longest, slo, shi))
    else:
        add("size", "warn", round(longest, 3), "longest edge %.2f m outside %.2f to %.2f" % (longest, slo, shi))

    if params.get("preview", True):
        sheet = vdir / "preview" / "sheet.png"
        add("preview", "pass" if sheet.is_file() else "warn", str(sheet.name), "turntable sheet " + ("present" if sheet.is_file() else "missing"))

    inspect = Path(params.get("inspect_script", ""))
    if info and inspect.is_file():
        try:
            r = subprocess.run(["node", str(inspect), str(glb), "--max-tris", str(hi), "--json"],
                               capture_output=True, text=True, timeout=60)
            rep = json.loads(r.stdout)
            state = "pass" if rep.get("status") == "pass" else "warn"
            add("asset_inspect", "info" if state == "pass" else "warn", rep.get("status"),
                "scripts/asset-inspect.mjs status %s, %s tris" % (rep.get("status"), rep.get("assembly", {}).get("triangles")))
        except Exception as exc:  # noqa: BLE001
            add("asset_inspect", "warn", None, "asset-inspect did not run: %r" % exc)
    return checks
