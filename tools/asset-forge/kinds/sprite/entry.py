"""Runs INSIDE Blender (blender -b --factory-startup --python-exit-code 1 -P entry.py -- <version dir>).

The recipe only builds a model (the model kind's contract: build(params) -> root, or
load_reference() for reference/source.glb) and may set a SPRITE config dict. This harness owns the
camera and the lights: an orthographic camera framed from the model's bounds, a key/fill/rim sun
rig parented to the camera so every direction is lit the same, a transparent film. It renders each
direction at SUPERSAMPLE x the target size, box-downsamples, cuts alpha at 50%, quantizes every
opaque pixel to the shade ramp (spritekit.py), adds the optional 1 px outline and writes
out/<asset>_sheet.png, out/<asset>.json, preview/sheet.png.

Exit 1 = recipe fault, 2 = harness fault. result.json is always written.
"""
import json
import math
import os
import sys
import time
import traceback

vdir = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
KIND_DIR = os.path.dirname(os.path.abspath(__file__))
FORGE_DIR = os.path.dirname(os.path.dirname(KIND_DIR))
RESULT = {"schema_version": 1, "status": "started", "warnings": [], "timings": {}}

DEFAULTS = {"size": 64, "directions": 4, "elevation": 30.0, "outline": True, "fit": "sphere",
            "margin": 2, "supersample": 4}


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


def recipe_fault(text):
    RESULT["status"] = "recipe_error"
    RESULT["error"] = text
    write_result()
    print("RECIPE FAULT:", text[-600:])
    sys.exit(1)


try:
    params = json.load(open(os.path.join(vdir, "params.json")))
    sys.path.insert(0, params["helper_dir"])
    sys.path.insert(0, KIND_DIR)
    sys.path.insert(0, FORGE_DIR)
    import bpy  # noqa: E402
    import common  # noqa: E402
    import pngio  # noqa: E402
    import spritekit as sk  # noqa: E402
    from mathutils import Vector  # noqa: E402
    RESULT["blender"] = bpy.app.version_string
    write_result()
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

ASSET = params["asset"]
OUT = os.path.join(vdir, "out")
PREVIEW = os.path.join(vdir, "preview")
RAW = os.path.join(PREVIEW, "raw")
SOURCE_GLB = os.path.join(vdir, "reference", "source.glb")


def stage(name, fn):
    t = time.time()
    try:
        return fn()
    finally:
        RESULT["timings"][name] = round(time.time() - t, 2)


# --- the model -------------------------------------------------------------------------
def load_reference():
    """Imports reference/source.glb under one new empty and returns that empty."""
    if not os.path.isfile(SOURCE_GLB):
        raise RuntimeError("load_reference(): this version has no reference/source.glb (pass --reference model.glb)")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
    new = [o for o in bpy.data.objects if o not in before]
    root = common.empty("source")
    for o in new:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    return root


root = None
cfg = dict(DEFAULTS)
try:
    common.reset()
    src = open(os.path.join(vdir, "recipe.py")).read()
    ns = {"__name__": "recipe", "__file__": os.path.join(vdir, "recipe.py"), "PARAMS": params,
          "load_reference": load_reference}

    def run_recipe():
        exec(compile(src, "recipe.py", "exec"), ns)
        if "build" in ns:
            return ns["build"](params)
        if os.path.isfile(SOURCE_GLB):
            return load_reference()
        raise RuntimeError("recipe.py defines no build(params) and there is no reference/source.glb")

    root = stage("recipe", run_recipe)
    if not hasattr(root, "children") or not hasattr(root, "type"):
        raise RuntimeError("build(params) must return the root Blender object, got %r" % (root,))
    user = ns.get("SPRITE", {})
    if not isinstance(user, dict):
        raise RuntimeError("SPRITE must be a dict, got %r" % (user,))
    unknown = sorted(set(user) - set(DEFAULTS))
    if unknown:
        raise RuntimeError("unknown SPRITE keys %s; allowed: %s" % (unknown, sorted(DEFAULTS)))
    cfg.update(user)
    if cfg["directions"] not in (1, 4, 8):
        raise RuntimeError("SPRITE['directions'] must be 1, 4 or 8, got %r" % (cfg["directions"],))
    if not isinstance(cfg["size"], int) or not 8 <= cfg["size"] <= 256:
        raise RuntimeError("SPRITE['size'] must be an int from 8 to 256, got %r" % (cfg["size"],))
    if cfg["fit"] not in ("sphere", "tight"):
        raise RuntimeError("SPRITE['fit'] must be 'sphere' or 'tight', got %r" % (cfg["fit"],))
    if not isinstance(cfg["supersample"], int) or not 2 <= cfg["supersample"] <= 8:
        raise RuntimeError("SPRITE['supersample'] must be an int from 2 to 8")
    if not 0 <= cfg["elevation"] <= 80 or not 0 <= cfg["margin"] <= cfg["size"] // 4:
        raise RuntimeError("SPRITE['elevation'] must be 0 to 80 degrees and margin 0 to size/4")
except BaseException as exc:  # noqa: BLE001
    recipe_fault("".join(traceback.format_exception(exc)))

RESULT["status"] = "built"
RESULT["config"] = cfg
write_result()


# --- fit: bounds, target, scale ---------------------------------------------------------
def world_vertices():
    dg = bpy.context.evaluated_depsgraph_get()
    pts, tris = [], 0
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        pts += [mw @ v.co for v in me.vertices]
        tris += sum(len(p.vertices) - 2 for p in me.polygons)
        ev.to_mesh_clear()
    return pts, tris


def camera_quat(az_deg, el_deg):
    a, e = math.radians(az_deg), math.radians(el_deg)
    eye = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    return eye, (-eye).to_track_quat("-Z", "Y")


try:
    pts, tris = stage("bounds", world_vertices)
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)
if not pts:
    recipe_fault("the model has no mesh vertices; build something visible")

lo = [min(p[i] for p in pts) for i in range(3)]
hi = [max(p[i] for p in pts) for i in range(3)]
centre = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
n = cfg["directions"]
step = 360.0 / n
if cfg["fit"] == "sphere":
    half = max((p - centre).length for p in pts)
else:
    half = 0.0
    for k in range(n):
        _, q = camera_quat(k * step, cfg["elevation"])
        rx, ry = q @ Vector((1, 0, 0)), q @ Vector((0, 1, 0))
        for p in pts:
            d = p - centre
            half = max(half, abs(d.dot(rx)), abs(d.dot(ry)))
size, ss, margin = cfg["size"], cfg["supersample"], cfg["margin"]
ortho = max(2 * half, 1e-3) * size / (size - 2 * margin)
_, q0 = camera_quat(0, cfg["elevation"])
up0 = q0 @ Vector((0, 1, 0))
feet_up = (lo[2] - centre.z) * up0.z                      # world units above the view centre
pivot = [size / 2.0, size / 2.0 - feet_up * size / ortho]
RESULT["measure"] = {
    "triangles": tris, "bounds_min": lo, "bounds_max": hi, "size": [hi[i] - lo[i] for i in range(3)],
    "fit_half_extent": half, "ortho_scale": ortho, "pivot": pivot,
}
write_result()

# name, camera-relative x tilt, z swing (degrees), sun energy, casts shadow. Documented in README.md.
RIG = (("key", -45.0, 35.0, 3.2, True), ("fill", -20.0, -65.0, 1.0, False), ("rim", -150.0, -25.0, 2.0, False))
AMBIENT = 0.45


# --- the rig: camera, lights, film -------------------------------------------------------
def make_rig():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 24
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.display_settings.display_device = "sRGB"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_x = scene.render.resolution_y = size * ss
    scene.render.resolution_percentage = 100
    world = bpy.data.worlds.new("sprite") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba(common.mix("sandstone", "bone", 0.5))
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = AMBIENT
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam_data.clip_start, cam_data.clip_end = 0.01, 1000.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # Parenting the suns to the camera makes the rig identical in every direction.
    for name, rx, rz, energy, shadow in RIG:
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.use_shadow = shadow
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.parent = cam
        obj.rotation_euler = (math.radians(rx), 0, math.radians(rz))
    return cam


def render_all(cam):
    scene = bpy.context.scene
    os.makedirs(RAW, exist_ok=True)
    frames = []
    ramp = sk.build_ramp(params["palette"])
    _, outline_rgb = sk.darkest(ramp)
    dist = max(10.0, half * 6)
    for k in range(n):
        eye, q = camera_quat(k * step, cfg["elevation"])
        cam.location = centre + eye * dist
        cam.rotation_euler = q.to_euler()
        path = os.path.join(RAW, "dir_%02d.png" % k)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        w, h, rows = pngio.read(path)
        if w != size * ss or h != size * ss:
            raise RuntimeError("render came out %dx%d, expected %d" % (w, h, size * ss))
        small = sk.quantize_rows(sk.downsample(rows, ss), ramp)
        if cfg["outline"]:
            small = sk.add_outline(small, outline_rgb)
        frames.append(small)
    return frames


def write_outputs(frames):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    sheet = sk.stack_rows(frames)
    pngio.write(os.path.join(OUT, ASSET + "_sheet.png"), size, len(sheet), sheet)
    meta = {
        "schema_version": 1, "asset": ASSET, "frame_width": size, "frame_height": size,
        "directions": n, "columns": 1, "rows": n, "layout": "rows are directions, top to bottom",
        "direction_degrees": [k * step for k in range(n)], "direction_zero": "the model's front (-Y in Blender)",
        "turn": "row k shows the camera moved k steps anticlockwise seen from above",
        "elevation_degrees": cfg["elevation"], "pivot": [round(pivot[0], 2), round(pivot[1], 2)],
        "pivot_meaning": "pixel (x, y from the top-left of a frame) where the ground under the model's centre lands",
        "outline": bool(cfg["outline"]), "ramp_steps": list(sk.STEPS),
    }
    with open(os.path.join(OUT, ASSET + ".json"), "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")
    scale = 4 if n <= 4 else 3
    pw, ph, prows = sk.preview_rows(frames, scale)
    pngio.write(os.path.join(PREVIEW, "sheet.png"), pw, ph, prows)
    RESULT["measure"]["opaque_pixels"] = [sk.opaque_count(f) for f in frames]
    RESULT["measure"]["colours"] = len({p[:3] for f in frames for row in f for p in row if p[3]})


try:
    cam = stage("rig", make_rig)
    frames = stage("render", lambda: render_all(cam))
    stage("write", lambda: write_outputs(frames))
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

RESULT["status"] = "ok"
write_result()
print("FORGE_ENTRY_OK")
