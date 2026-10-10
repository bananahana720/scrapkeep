"""Runs INSIDE Blender's Python (blender -b --factory-startup --python-exit-code 1 -P entry.py -- <version dir>),
though it needs no Blender API: the forge has one sandboxed runner and this kind reuses it.

Runs recipe.py's build(params) -> spec (plain data), normalizes and checks it, writes out/effect.json,
measures the simulated cloud and writes the preview strip to preview/sheet.png. result.json is always
written. Exit 1 = recipe fault (the agent fixes it), 2 = harness fault.
"""
import json
import os
import sys
import time
import traceback

vdir = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
HERE = os.path.dirname(os.path.abspath(__file__))
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


def recipe_fault(msg):
    RESULT["status"] = "recipe_error"
    RESULT["error"] = msg
    write_result()
    print("RECIPE FAULT:", msg)
    sys.exit(1)


try:
    params = json.load(open(os.path.join(vdir, "params.json")))
    sys.path.insert(0, HERE)
    sys.path.insert(0, os.path.dirname(os.path.dirname(HERE)))   # tools/asset-forge, for pngio
    import vfxsim  # noqa: E402
    import vfxspec  # noqa: E402
    try:
        import bpy  # noqa: E402
        RESULT["blender"] = bpy.app.version_string
    except ImportError:
        RESULT["blender"] = "python-only"
    write_result()
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

OUT = os.path.join(vdir, "out")
PREVIEW = os.path.join(vdir, "preview")
palette = params["palette"]

# --- recipe ------------------------------------------------------------------------------
t0 = time.time()
try:
    src = open(os.path.join(vdir, "recipe.py")).read()
    ns = {"__name__": "recipe", "__file__": os.path.join(vdir, "recipe.py"), "PARAMS": params}
    exec(compile(src, "recipe.py", "exec"), ns)  # noqa: S102 - the sandbox is the boundary
    if "build" not in ns:
        recipe_fault("recipe.py defines no build(params)")
    raw = ns["build"](params)
    spec = json.loads(json.dumps(raw))     # plain data only: a non-serialisable value is a recipe fault
except SystemExit:
    raise
except BaseException:  # noqa: BLE001
    recipe_fault("recipe raised:\n" + traceback.format_exc()[-1800:])
RESULT["timings"]["recipe"] = round(time.time() - t0, 2)

spec = vfxspec.normalize(spec)
errors = vfxspec.validate(spec, set(palette), budget=params["band"][1], max_emitters=params["max_draw_calls"])
if errors:
    recipe_fault("the spec is invalid:\n" + "\n".join("  [%s] %s" % e for e in errors))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "effect.json"), "w") as f:
    json.dump(spec, f, indent=2, sort_keys=True)
    f.write("\n")

# --- measure and preview (post-steps: a failure is a warning) ----------------------------
try:
    RESULT["measure"] = {
        "particles": vfxspec.total_amount(spec),
        "emitters": len(spec["emitters"]),
        "cloud_radius": round(vfxsim.cloud_radius(spec, palette), 4),
        "duration": round(vfxsim.duration(spec), 4),
    }
except Exception as exc:  # noqa: BLE001
    warn("measurement failed: %r" % exc)

if params.get("preview", True):
    try:
        os.makedirs(PREVIEW, exist_ok=True)
        vfxsim.write_strip(os.path.join(PREVIEW, "sheet.png"), spec, palette)
    except Exception as exc:  # noqa: BLE001
        warn("preview render failed: %r" % exc)

RESULT["status"] = "ok"
write_result()
print("FORGE_ENTRY_OK")
