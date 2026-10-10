"""VFX validator (runs outside the sandbox, stdlib only).

validate(vdir, params, result, pack) -> list of checks {id, state, value, detail}.
It never trusts the entry's measurements: it re-reads out/effect.json, re-checks the spec,
re-simulates, converts the spec to out/effect.tscn and loads that scene in headless Godot.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1]))
import forgecore as fc  # noqa: E402
import vfxsim  # noqa: E402
import vfxspec  # noqa: E402
import vfxtscn  # noqa: E402

CHECK_GD = HERE / "vfx_check.gd"
FINE_SIZE = 0.05       # metres: an emitter whose biggest visible particle is smaller reads as sparkle dust, not a chunk
LONG_LIFE = 1.2        # seconds: an effect that lingers hides the next hit


def godot_exe():
    return os.environ.get("FORGE_GODOT") or shutil.which("godot")


def godot_check(tscn, expect_json, sketch):
    """Runs the headless load check. -> (ok, output text). Never opens a window."""
    exe = godot_exe()
    if not exe:
        return None, "godot is not on PATH"
    try:
        r = subprocess.run([exe, "--headless", "--path", str(sketch), "--script", str(CHECK_GD), "--",
                            str(tscn), str(expect_json)], capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        return False, "godot timed out after 180 s"
    out = (r.stdout + r.stderr).strip()
    return (r.returncode == 0 and "VFX_OK" in r.stdout), out


def validate(vdir, params, result, pack):
    vdir = Path(vdir)
    checks = []
    add = lambda *a: checks.append(fc.check(*a))  # noqa: E731
    if result.get("status") != "ok":
        add("build", "fail", result.get("status"), (result.get("error") or "the recipe did not build")[-1500:])
        return checks
    add("build", "pass", "ok", "recipe ran and wrote a spec")
    for w in result.get("warnings", []):
        add("harness_warning", "warn", None, w)
    path = vdir / "out" / "effect.json"
    if not path.is_file():
        add("spec_schema", "fail", None, "out/effect.json is missing")
        return checks
    try:
        spec = vfxspec.normalize(json.loads(path.read_text()))
    except ValueError as exc:
        add("spec_schema", "fail", None, "out/effect.json is not JSON: %s" % exc)
        return checks
    palette = params["palette"]
    budget = params["band"][1]
    errs = vfxspec.validate(spec, set(palette), budget=budget, max_emitters=params["max_draw_calls"])
    total = sum(e["amount"] for e in spec["emitters"] if isinstance(e, dict) and isinstance(e.get("amount"), int))
    n_em = len(spec["emitters"]) if isinstance(spec.get("emitters"), list) else 0
    groups = [("spec_schema", ("schema", "range"), "fields, types and ranges are valid"),
              ("palette_roles", ("palette",), "every colour is a palette role"),
              ("budget", ("budget",), "%d particles in %d emitters; budget %d, emitter cap %d" % (total, n_em, budget, params["max_draw_calls"])),
              ("lifetime", ("lifetime",), "lifetimes are 0.05 to 2.0 s")]
    for cid, codes, ok in groups:
        mine = [m for c, m in errs if c in codes]
        if mine:
            add(cid, "fail", len(mine), "; ".join(mine)[:900])
        elif ok:
            add(cid, "pass", 0, ok)
    if errs:
        return checks     # simulating or converting a spec that already failed adds nothing

    life = max(e["lifetime"] for e in spec["emitters"])
    add("lifetime_sanity", "warn" if life > LONG_LIFE else "pass", life,
        "longest lifetime %.2f s%s" % (life, "; short effects read better" if life > LONG_LIFE else ""))
    radius = vfxsim.cloud_radius(spec, palette)
    lo, hi = params["size_range"]
    if radius > hi:
        add("bounds", "fail", round(radius, 2), "the simulated cloud reaches %.2f m from the origin; the cap is %.1f m" % (radius, hi))
    elif radius > vfxspec.WARN_RADIUS or radius < lo:
        add("bounds", "warn", round(radius, 2), "the cloud reaches %.2f m; expected %.2f to %.1f m (warn above %.1f)" % (radius, lo, hi, vfxspec.WARN_RADIUS))
    else:
        add("bounds", "pass", round(radius, 2), "the cloud stays within %.2f m of the origin (cap %.1f m)" % (radius, hi))
    smallest = vfxsim.peak_size(spec, palette)
    if smallest is not None and smallest < FINE_SIZE:
        add("chunkiness", "warn", round(smallest, 3), "an emitter peaks at %.3f m; prefer chunky shapes over fine sparkle" % smallest)
    else:
        add("chunkiness", "pass", None if smallest is None else round(smallest, 3), "every emitter peaks at %.2f m or more" % FINE_SIZE)

    sheet = vdir / "preview" / "sheet.png"
    add("preview", "pass" if sheet.is_file() else "warn", None, "preview strip present" if sheet.is_file() else "preview/sheet.png is missing")

    out = vdir / "out"
    out.mkdir(exist_ok=True)
    tscn, expect = out / "effect.tscn", out / "expect.json"
    tscn.write_text(vfxtscn.to_tscn(spec, palette, params["asset"]))
    expect.write_text(json.dumps(vfxtscn.expectations(spec, palette), indent=1, sort_keys=True) + "\n")
    ok, text = godot_check(tscn, expect, Path(pack["sketch_path"]))
    last = [ln for ln in text.splitlines() if "VFX_" in ln]
    if ok is None:
        add("godot_load", "warn", None, "not verified: " + text)
    elif ok:
        add("godot_load", "pass", None, last[-1][:300] if last else "loaded")
    else:
        add("godot_load", "fail", None, ("; ".join(last) or text)[-900:])
    return checks
