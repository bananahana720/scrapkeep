"""Runs inside Blender's Python (blender -b --factory-startup --python-exit-code 1 -P entry.py -- <version dir>)
but needs nothing from Blender: it is pure Python, and also runs under plain python3 for tests.

The recipe defines build(params) -> pixkit Canvas (one frame) or a list of Canvases (an animation),
and may set PIXEL = {"fps": 8}. This harness draws no colour of its own: it maps the canvas's
ramp keys to RGBA, writes out/<asset>.png (frames side by side), out/<asset>.json and
preview/sheet.png (x8 nearest upscale plus the real-size row).

Exit 1 = recipe fault, 2 = harness fault. result.json is always written.
"""
import json
import os
import sys
import time
import traceback

vdir = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
KIND_DIR = os.path.dirname(os.path.abspath(__file__))
FORGE_DIR = os.path.dirname(os.path.dirname(KIND_DIR))
RESULT = {"schema_version": 1, "status": "started", "warnings": [], "timings": {}}
PREVIEW_SCALE = 8


def write_result():
    tmp = os.path.join(vdir, "result.json.tmp")
    with open(tmp, "w") as f:
        json.dump(RESULT, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, os.path.join(vdir, "result.json"))


def harness_fault(exc):
    RESULT["status"] = "harness_error"
    RESULT["error"] = "".join(traceback.format_exception(exc))
    write_result()
    print("HARNESS FAULT (not your script):", exc)
    sys.exit(2)


def recipe_fault(text):
    RESULT["status"] = "recipe_error"
    RESULT["error"] = text
    write_result()
    print("RECIPE FAULT:", text[-600:])
    sys.exit(1)


try:
    params = json.load(open(os.path.join(vdir, "params.json")))
    sys.path.insert(0, KIND_DIR)
    sys.path.insert(0, FORGE_DIR)
    import pixkit  # noqa: E402
    import pngio  # noqa: E402
    import spritekit as sk  # noqa: E402
    pixkit.set_palette(params["palette"])
    RESULT["python"] = sys.version.split()[0]
    write_result()
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

ASSET = params["asset"]
frames = None
cfg = {"fps": 8}
try:
    t = time.time()
    src = open(os.path.join(vdir, "recipe.py")).read()
    ns = {"__name__": "recipe", "__file__": os.path.join(vdir, "recipe.py"), "PARAMS": params}
    exec(compile(src, "recipe.py", "exec"), ns)
    if "build" not in ns:
        raise RuntimeError("recipe.py defines no build(params)")
    frames = pixkit.as_frames(ns["build"](params))
    user = ns.get("PIXEL", {})
    if not isinstance(user, dict) or set(user) - set(cfg):
        raise RuntimeError("PIXEL must be a dict with keys from %s, got %r" % (sorted(cfg), user))
    cfg.update(user)
    if not isinstance(cfg["fps"], int) or not 1 <= cfg["fps"] <= 60:
        raise RuntimeError("PIXEL['fps'] must be an int from 1 to 60")
    RESULT["timings"]["recipe"] = round(time.time() - t, 2)
except BaseException as exc:  # noqa: BLE001
    recipe_fault("".join(traceback.format_exception(exc)))

try:
    fw, fh, n = frames[0].w, frames[0].h, len(frames)
    out_dir, prev_dir = os.path.join(vdir, "out"), os.path.join(vdir, "preview")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(prev_dir, exist_ok=True)
    rows = pixkit.strip_rows(frames)
    pngio.write(os.path.join(out_dir, ASSET + ".png"), fw * n, fh, rows)
    meta = {
        "schema_version": 1, "asset": ASSET, "frame_width": fw, "frame_height": fh, "frames": n,
        "layout": "frames left to right in one row", "fps": cfg["fps"],
        "colours": sorted({k for f in frames for k in f.colours()}), "ramp_steps": list(sk.STEPS),
    }
    with open(os.path.join(out_dir, ASSET + ".json"), "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")
    pw, ph, prows = sk.preview_rows([f.to_rows() for f in frames], PREVIEW_SCALE)
    pngio.write(os.path.join(prev_dir, "sheet.png"), pw, ph, prows)
    RESULT["measure"] = {"frame": [fw, fh], "frames": n, "colours": len(meta["colours"]),
                         "opaque_pixels": [sk.opaque_count(f.to_rows()) for f in frames]}
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

RESULT["status"] = "ok"
write_result()
print("FORGE_ENTRY_OK")
