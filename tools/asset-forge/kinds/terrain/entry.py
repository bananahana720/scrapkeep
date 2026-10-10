"""Runs INSIDE Blender's Python (for numpy): blender -b --factory-startup --python-exit-code 1
-P entry.py -- <version dir>. No bpy scene work happens; Blender is only the interpreter that
carries numpy.

Runs recipe.py's build(params), derives the maps the recipe did not supply, writes the five
PNGs, the .tres and the 2x2 lit preview, and ALWAYS writes result.json. Exit 1 = recipe fault,
2 = harness fault. Every post-step is wrapped: a failed measurement is a warning.

recipe.py contract: build(params) -> dict with
  "height"   (n, n) float [0, 1]            required
  "albedo"   (n, n, 3) float sRGB [0, 1]    required (build it with texlib.ramp so it is palette-true)
  "roughness" (n, n) float [0, 1]           optional (default 0.9 everywhere)
  "ao"       (n, n) float [0, 1]            optional (default texlib.ao_from_height)
  "normal_strength" float                   optional (default 1.5)
  "uv_scale" float                          optional, tiles per metre-ish in the .tres (default 1.0)
Normal is always derived from height, so it cannot disagree with it.
"""
import json
import os
import shutil
import sys
import time
import traceback

vdir = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
KIND_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else None
RESULT = {"schema_version": 1, "status": "started", "warnings": [], "timings": {}}


def write_result():
    tmp = os.path.join(vdir, "result.json.tmp")
    with open(tmp, "w") as f:
        json.dump(RESULT, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, os.path.join(vdir, "result.json"))


def warn(msg):
    RESULT["warnings"].append(msg)
    print("WARN", msg)


def harness_fault(exc):
    RESULT["status"] = "harness_error"
    RESULT["error"] = "".join(traceback.format_exception(exc))
    write_result()
    print("HARNESS FAULT (not your script):", exc)
    sys.exit(2)


try:
    params = json.load(open(os.path.join(vdir, "params.json")))
    if KIND_DIR is None:
        raise RuntimeError("entry.py cannot find its own directory (no __file__)")
    sys.path.insert(0, KIND_DIR)
    import numpy as np  # noqa: E402
    import texlib as tl  # noqa: E402
    try:
        import bpy  # noqa: E402
        RESULT["blender"] = bpy.app.version_string
    except Exception:  # noqa: BLE001
        RESULT["blender"] = None
    RESULT["numpy"] = np.__version__
    write_result()
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

ASSET = params["asset"]
OUT = os.path.join(vdir, "out")
PREVIEW = os.path.join(vdir, "preview")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)


def stage(name, fn):
    t = time.time()
    try:
        return fn()
    finally:
        RESULT["timings"][name] = round(time.time() - t, 2)


# The agent cannot read texlib.py before its first run (the forge copies only the pack's
# example recipes), so leave a copy it can Read from the second run on.
try:
    ref = os.path.join(vdir, "reference")
    os.makedirs(ref, exist_ok=True)
    shutil.copyfile(os.path.join(KIND_DIR, "texlib.py"), os.path.join(ref, "texlib.py"))
except Exception as exc:  # noqa: BLE001
    warn("could not copy texlib.py into reference/: %r" % exc)

# --- recipe --------------------------------------------------------------------------
maps = None
try:
    src = open(os.path.join(vdir, "recipe.py")).read()
    ns = {"__name__": "recipe", "__file__": os.path.join(vdir, "recipe.py"), "PARAMS": params}

    def run_recipe():
        exec(compile(src, "recipe.py", "exec"), ns)
        if "build" not in ns:
            raise RuntimeError("recipe.py defines no build(params)")
        return ns["build"](params)

    maps = stage("recipe", run_recipe)
    if not isinstance(maps, dict) or "height" not in maps or "albedo" not in maps:
        raise RuntimeError("build(params) must return a dict with 'height' and 'albedo', got %r" % (type(maps).__name__,))
    height = np.asarray(maps["height"], dtype=np.float32)
    albedo = np.asarray(maps["albedo"], dtype=np.float32)
    if height.ndim != 2 or albedo.ndim != 3 or albedo.shape[2] != 3 or albedo.shape[:2] != height.shape:
        raise RuntimeError("height must be (n, n) and albedo (n, n, 3) with the same n; got %s and %s" % (height.shape, albedo.shape))
    if not (np.isfinite(height).all() and np.isfinite(albedo).all()):
        raise RuntimeError("height or albedo contains NaN or inf")
    n = height.shape[0]
    if n != height.shape[1]:
        raise RuntimeError("maps must be square, got %s" % (height.shape,))
except BaseException as exc:  # noqa: BLE001
    RESULT["status"] = "recipe_error"
    RESULT["error"] = "".join(traceback.format_exception(exc))
    write_result()
    print("RECIPE FAULT:", exc)
    sys.exit(1)

# --- derived maps and files ------------------------------------------------------------
try:
    strength = float(maps.get("normal_strength", 1.5))
    normal = tl.normal_from_height(height, strength)
    rough = maps.get("roughness")
    rough = np.full((n, n), 0.9, dtype=np.float32) if rough is None else np.asarray(rough, dtype=np.float32)
    ao = maps.get("ao")
    ao = tl.ao_from_height(height) if ao is None else np.asarray(ao, dtype=np.float32)
    if rough.shape != (n, n) or ao.shape != (n, n):
        raise RuntimeError("roughness and ao must be (n, n); got %s and %s" % (rough.shape, ao.shape))

    def write_all():
        tl.write_png(os.path.join(OUT, ASSET + "_albedo.png"), albedo)
        tl.write_png(os.path.join(OUT, ASSET + "_normal.png"), normal)
        tl.write_png(os.path.join(OUT, ASSET + "_roughness.png"), rough)
        tl.write_png(os.path.join(OUT, ASSET + "_ao.png"), ao)
        tl.write_png(os.path.join(OUT, ASSET + "_height.png"), height, bits=16)
        with open(os.path.join(OUT, ASSET + ".tres"), "w") as f:
            f.write(tl.tres_text(ASSET, uv_scale=float(maps.get("uv_scale", 1.0))))
    stage("write", write_all)
except BaseException as exc:  # noqa: BLE001
    RESULT["status"] = "recipe_error"
    RESULT["error"] = "".join(traceback.format_exception(exc))
    write_result()
    print("RECIPE FAULT:", exc)
    sys.exit(1)

RESULT["status"] = "built"
write_result()


def measure():
    seams = {k: round(tl.seam_metric(a), 3) for k, a in
             (("albedo", albedo), ("normal", normal), ("roughness", rough), ("ao", ao), ("height", height))}
    RESULT["measure"] = {
        "size": n, "seam": seams, "seam_max": max(seams.values()),
        "height_min": float(height.min()), "height_max": float(height.max()), "height_std": float(height.std()),
        "normal_strength": strength,
    }


try:
    stage("measure", measure)
except Exception as exc:  # noqa: BLE001
    warn("measurement failed: %r" % exc)


def render():
    sheet = tl.preview_sheet(albedo, normal, rough, ao, height)
    tl.write_png(os.path.join(PREVIEW, "sheet.png"), sheet)


if params.get("preview", True):
    try:
        stage("render", render)
    except Exception as exc:  # noqa: BLE001
        warn("preview render failed: %r" % exc)

RESULT["status"] = "ok"
write_result()
print("FORGE_ENTRY_OK")
