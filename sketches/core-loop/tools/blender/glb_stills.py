"""Cycles CPU stills of any built GLB, for evidence on a cloud box with no GPU or EGL.

common.render_turntable renders with Eevee, which needs a GPU context. This imports a GLB as
built (vertex colours and baked slots as exported), frames it from front, side and
three-quarter, and renders each with Cycles on the CPU at a low sample count:

  blender -b -t 2 -P sketches/core-loop/tools/blender/glb_stills.py -- \
      --glb path/to/model.glb --out DIR [--size 960] [--samples 24] [--views front,side,three-quarter]

Writes DIR/<glb base name>-<view>.png and prints STILL <path> per frame.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

VIEWS = {"front": 0.0, "side": 90.0, "three-quarter": 35.0, "rear": 180.0}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"glb": "", "out": "", "size": 960, "samples": 24, "views": "front,side,three-quarter"}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        a[key] = type(a[key])(argv[i + 1]) if key in a else argv[i + 1]
        i += 2
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
    # glTF import keeps COLOR_0 as a colour attribute; route it into the base colour so
    # vertex-coloured slots read as they do in game.
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


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a["glb"])
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
    scene.cycles.device = "CPU"
    scene.cycles.samples = a["samples"]
    scene.cycles.use_denoising = False
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
    base = os.path.splitext(os.path.basename(a["glb"]))[0]
    dist = radius * 3.2
    for view in a["views"].split(","):
        yaw = math.radians(VIEWS[view])
        # glTF +Z forward becomes Blender -Y; front looks at the model's front from -Y.
        eye = centre + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, radius * 0.9))
        cam.location = eye
        cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(a["out"], "%s-%s.png" % (base, view))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("STILL", path)


main()
