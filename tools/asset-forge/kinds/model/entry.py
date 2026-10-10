"""Runs INSIDE Blender (blender -b --factory-startup --python-exit-code 1 -P entry.py -- <version dir>).

Builds recipe.py, exports GLB + .blend, renders the turntable sheet and writes result.json.
Exit 1 = recipe fault (the agent fixes it), 2 = harness fault (not the recipe's doing).
result.json is always written. Every post-step is wrapped: a failed measurement becomes a
warning, never a lost model.
"""
import json
import math
import os
import shutil
import sys
import time
import traceback

vdir = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
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
    sys.path.insert(0, params["helper_dir"])
    import bpy  # noqa: E402
    import bmesh  # noqa: E402
    import common  # noqa: E402
    RESULT["blender"] = bpy.app.version_string
    write_result()
except Exception as exc:  # noqa: BLE001
    harness_fault(exc)

ASSET = params["asset"]
OUT = os.path.join(vdir, "out")
GLB = os.path.join(OUT, ASSET + ".glb")
BLEND = os.path.join(OUT, ASSET + ".blend")
PREVIEW = os.path.join(vdir, "preview")


def save_blend(path):
    """Saves the scene as a .blend (kept here so the forge needs no change to common.py)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=False)


def stage(name, fn):
    t = time.time()
    try:
        return fn()
    finally:
        RESULT["timings"][name] = round(time.time() - t, 2)


# --- recipe --------------------------------------------------------------------------
root = None
try:
    common.reset()
    src = open(os.path.join(vdir, "recipe.py")).read()
    ns = {"__name__": "recipe", "__file__": os.path.join(vdir, "recipe.py"), "PARAMS": params}

    def run_recipe():
        exec(compile(src, "recipe.py", "exec"), ns)
        if "build" not in ns:
            raise RuntimeError("recipe.py defines no build(params)")
        return ns["build"](params)

    root = stage("recipe", run_recipe)
    if not hasattr(root, "children") or not hasattr(root, "type"):
        raise RuntimeError("build(params) must return the root Blender object, got %r" % (root,))
    stage("export", lambda: common.export(root, GLB))
except BaseException as exc:  # noqa: BLE001
    RESULT["status"] = "recipe_error"
    RESULT["error"] = "".join(traceback.format_exception(exc))
    write_result()
    print("RECIPE FAULT:", exc)
    sys.exit(1)

RESULT["status"] = "built"
write_result()

try:
    stage("save_blend", lambda: save_blend(BLEND))
except Exception as exc:  # noqa: BLE001
    warn("save_blend failed: %r" % exc)


# --- measurements -----------------------------------------------------------------------
def srgb_hex(lin):
    def enc(c):
        c = max(0.0, min(1.0, c))
        return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return "".join("%02x" % round(enc(c) * 255) for c in lin[:3])


def base_slot(name):
    return name.split(".")[0] if name.split(".")[0] in common.SLOTS else name


def measure():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    names = [o.name for o in common.tree(root)]
    lo = [1e9] * 3
    hi = [-1e9] * 3
    islands = []
    tri_total = 0
    nonmanifold = 0
    edges_total = 0
    area_by_slot = {}
    vc_area = {}
    unslotted_area = 0.0
    unknown_materials = set()
    per_object = {}
    origin = root.matrix_world.translation
    max_radius = 0.0
    for obj in meshes:
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        mw = ev.matrix_world
        wco = [mw @ v.co for v in me.vertices]
        max_radius = max([max_radius] + [(p - origin).length for p in wco])
        for p in wco:
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
        o_tris = sum(len(p.vertices) - 2 for p in me.polygons)
        tri_total += o_tris
        per_object[obj.name] = o_tris
        # islands by vertex connectivity through faces
        parent = list(range(len(wco)))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        for poly in me.polygons:
            vs = poly.vertices
            for k in range(1, len(vs)):
                ra, rb = find(vs[0]), find(vs[k])
                if ra != rb:
                    parent[rb] = ra
        used = {v for poly in me.polygons for v in poly.vertices}
        groups = {}
        for v in used:
            groups.setdefault(find(v), []).append(v)
        for key in sorted(groups):
            pts = [wco[v] for v in groups[key]]
            islands.append({"object": obj.name,
                            "min": [min(p[i] for p in pts) for i in range(3)],
                            "max": [max(p[i] for p in pts) for i in range(3)]})
        # non-manifold edges
        count = {}
        for poly in me.polygons:
            vs = poly.vertices
            for k in range(len(vs)):
                e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)])))
                count[e] = count.get(e, 0) + 1
        edges_total += len(count)
        nonmanifold += sum(1 for c in count.values() if c != 2)
        # materials and colours
        attr = me.color_attributes.get("Color")
        for poly in me.polygons:
            area = poly.area
            if poly.material_index >= len(me.materials) or me.materials[poly.material_index] is None:
                unslotted_area += area
                continue
            slot = base_slot(me.materials[poly.material_index].name)
            if slot not in common.SLOTS:
                unknown_materials.add(slot)
            area_by_slot[slot] = area_by_slot.get(slot, 0.0) + area
            if common.SLOTS.get(slot, {}).get("vc"):
                if attr is None:
                    key = "missing"
                else:
                    cols = [attr.data[li].color for li in poly.loop_indices]
                    avg = [sum(c[i] for c in cols) / len(cols) for i in range(3)]
                    key = srgb_hex(avg)
                vc_area.setdefault(slot, {})
                vc_area[slot][key] = vc_area[slot].get(key, 0.0) + area
        ev.to_mesh_clear()
    # support graph: ground contact, then bounding-box contact within 5 mm
    tol = 0.005
    supported = [i["min"][2] <= tol for i in islands]
    changed = True
    while changed:
        changed = False
        for a, ia in enumerate(islands):
            if supported[a]:
                continue
            for b, ib in enumerate(islands):
                if supported[b] and all(ia["min"][k] - tol <= ib["max"][k] and ib["min"][k] - tol <= ia["max"][k]
                                        for k in range(3)):
                    supported[a] = changed = True
                    break
    floating = [{"object": i["object"], "min": i["min"], "max": i["max"]}
                for i, s in zip(islands, supported) if not s]
    root_loc = list(root.matrix_world.translation)
    lowest = lo[2]
    RESULT["measure"] = {
        "triangles": tri_total,
        "triangles_by_object": per_object,
        "objects": names,
        "bounds_min": lo,
        "bounds_max": hi,
        "size": [hi[i] - lo[i] for i in range(3)],
        "center_xy": [(hi[0] + lo[0]) / 2, (hi[1] + lo[1]) / 2],
        "lowest_z": lowest,
        "root_origin": root_loc,
        "max_radius": max_radius,
        "islands": len(islands),
        "floating": floating,
        "nonmanifold_edges": nonmanifold,
        "edges": edges_total,
        "area_by_slot": area_by_slot,
        "vertex_colour_area": vc_area,
        "unslotted_area": unslotted_area,
        "unknown_materials": sorted(unknown_materials),
    }


try:
    stage("measure", measure)
except Exception as exc:  # noqa: BLE001
    warn("measurement failed: %r" % exc)
    RESULT["measure_error"] = "".join(traceback.format_exception(exc))


# --- preview ---------------------------------------------------------------------------
def render():
    m = RESULT.get("measure")
    if not m:
        raise RuntimeError("no measurements, no framing")
    target = (0.0, 0.0, (m["bounds_min"][2] + m["bounds_max"][2]) / 2)
    half = 0.5 * math.sqrt(sum(s * s for s in m["size"]))
    vfov = 30.0
    dist = max(1.0, half * 1.4 / math.sin(math.radians(vfov / 2)))
    views = [("eye", dist, 0.30, vfov, (384, 384)), ("high", dist, 0.95, vfov, (384, 384))]
    sheet = common.render_turntable(root, ASSET, os.path.join(PREVIEW, "views"), views,
                                    ground_z=0.0, target=target, yaws=(0, 90, 180, 270))
    shutil.copyfile(sheet, os.path.join(PREVIEW, "sheet.png"))


if params.get("preview", True):
    try:
        stage("render", render)
    except Exception as exc:  # noqa: BLE001
        warn("preview render failed: %r" % exc)

RESULT["status"] = "ok"
write_result()
print("FORGE_ENTRY_OK")
