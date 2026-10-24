"""Top-down and 3/4 stills of each greybox, with a 2 m ball at the proof entry for scale.

Usage: blender -b --factory-startup -P stills.py -- <greybox dir> <name> [<name> ...]
Renders on CPU (Cycles) so it never takes the GPU.
"""
import json
import math
import pathlib
import sys

import bpy
from mathutils import Vector

root = pathlib.Path(sys.argv[sys.argv.index("--") + 1])
names = sys.argv[sys.argv.index("--") + 2:]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1200, 900
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.9, 0.84, 1)
    sc.world = w
    return sc


def look(cam, target):
    d = target - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


for name in names:
    sc = reset()
    bpy.ops.import_scene.gltf(filepath=str(root / name / "model.glb"))
    meshes = [o for o in sc.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    for o in [o for o in sc.objects if o.type == "CAMERA"]:
        bpy.data.objects.remove(o)
    proof = sorted((root / "proofs").glob(f"{name}-*.json"))[0]
    start = json.loads(proof.read_text())["start"]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=start, segments=32, ring_count=16)
    ball = bpy.context.object
    m = bpy.data.materials.new("ball")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.06, 0.56, 0.45, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.06, 0.56, 0.45, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.0
    ball.data.materials.append(m)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(30))
    sc.collection.objects.link(sun)
    c = (lo + hi) / 2
    size = hi - lo
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(size.x, size.y * 4 / 3) * 1.08
    cam.location = (c.x, c.y, hi.z + 50)
    cam.rotation_euler = (0, 0, 0)
    sc.render.filepath = str(root / name / "top.png")
    bpy.ops.render.render(write_still=True)
    cam.data.type = "PERSP"
    cam.data.lens = 35
    span = max(size.x, size.y)
    cam.location = c + Vector((-0.75 * span, -0.95 * span, 0.7 * span))
    look(cam, c + Vector((0, 0, -0.1 * size.z)))
    sc.render.filepath = str(root / name / "three_quarter.png")
    bpy.ops.render.render(write_still=True)
    print("STILLS", name, [round(v, 2) for v in lo], [round(v, 2) for v in hi])
