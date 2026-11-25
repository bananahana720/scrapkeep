"""Cycles CPU stills of any built GLB, for evidence on a cloud box with no GPU or EGL.

common.render_turntable renders with Eevee, which needs a GPU context. This imports a GLB as
built (vertex colours and baked slots as exported), frames it from front, side and
three-quarter, and renders each with Cycles on the CPU at a low sample count:

  blender -b -t 2 -P sketches/core-loop/tools/blender/glb_stills.py -- \
      --glb path/to/model.glb --out DIR [--size 960] [--samples 24] [--views front,side,three-quarter]
      [--adaptive on|off] [--mount mantle.glb[,mantle.glb]] [--name label]

--mount seats each mantle's Mount<Name> groups on the model's <Name> nodes with an identity
transform, as hero_assets.gd mounts a Warden mantle on its kit (MANTLE_MOUNTS).
--adaptive sets Cycles' adaptive sampling (left at Blender's default, on, when absent).
Writes DIR/<name or glb base name>-<view>.png and prints RENDER_S <seconds> and STILL <path> per
frame.
"""
import math
import os
import sys
import time

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cycles_device

VIEWS = {"front": 0.0, "side": 90.0, "three-quarter": 35.0, "rear": 180.0}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"glb": "", "out": "", "size": 960, "samples": 24, "views": "front,side,three-quarter",
         "mount": "", "name": "", "adaptive": ""}
    if len(argv) % 2:
        raise SystemExit("glb_stills: every flag takes one value")
    for flag, value in zip(argv[::2], argv[1::2]):
        key = flag.lstrip("-")
        if key not in a:
            raise SystemExit("glb_stills: unknown flag " + flag)
        a[key] = type(a[key])(value)
    unknown = set(a["views"].split(",")) - set(VIEWS)
    if unknown:
        raise SystemExit("glb_stills: unknown views " + ", ".join(sorted(unknown)))
    if a["adaptive"] not in ("", "on", "off"):
        raise SystemExit("glb_stills: --adaptive takes on or off")
    if not a["glb"] or not a["out"]:
        raise SystemExit("glb_stills: --glb and --out are required")
    return a


def bounds(objects):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for o in objects:
        if o.type != "MESH" or o.name.endswith("-col"):
            continue
        for corner in o.bound_box:
            p = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def colour_material():
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nodes = mat.node_tree.nodes
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or bsdf.inputs["Base Color"].is_linked:
            continue
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])


def mount(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    added = [o for o in bpy.data.objects if o not in before]
    groups = [o for o in added if o.name.startswith("Mount")]
    if not groups:
        raise SystemExit("glb_stills: %s has no Mount<Name> groups" % path)
    for group in groups:
        socket = bpy.data.objects.get(group.name[len("Mount"):].split(".")[0])
        if socket is None or socket in added:
            raise SystemExit("glb_stills: no %s node for %s" % (group.name[len("Mount"):], group.name))
        group.parent = socket
        group.matrix_parent_inverse.identity()
        group.matrix_basis.identity()
    keep = set(groups).union(*(g.children_recursive for g in groups))
    for o in added:
        if o not in keep:
            bpy.data.objects.remove(o)


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a["glb"])
    for path in filter(None, a["mount"].split(",")):
        mount(path)
    colour_material()
    objects = list(bpy.context.scene.objects)
    for o in objects:
        if o.name.endswith("-col"):
            o.hide_render = True
    lo, hi = bounds(objects)
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.1)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = a["samples"]
    scene.cycles.use_denoising = False
    if a["adaptive"]:
        scene.cycles.use_adaptive_sampling = a["adaptive"] == "on"
    scene.render.resolution_x = a["size"]
    scene.render.resolution_y = int(a["size"] * 0.75)
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("Stills")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.36, 0.40, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)
    ground = bpy.data.meshes.new("Ground")
    s = radius * 6
    ground.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ground_obj = bpy.data.objects.new("Ground", ground)
    ground_obj.location.z = lo.z
    scene.collection.objects.link(ground_obj)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(a["out"], exist_ok=True)
    base = a["name"] or os.path.splitext(os.path.basename(a["glb"]))[0]
    dist = radius * 3.2
    for view in a["views"].split(","):
        yaw = math.radians(VIEWS[view])
        eye = centre + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, radius * 0.9))
        cam.location = eye
        cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(a["out"], "%s-%s.png" % (base, view))
        scene.render.filepath = path
        start = time.monotonic()
        bpy.ops.render.render(write_still=True)
        print("RENDER_S %.3f" % (time.monotonic() - start))
        print("STILL", path)


main()
