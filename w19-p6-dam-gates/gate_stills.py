"""Cycles CPU stills of landmark_dam.glb with its gate leaves at given angles, from cameras recorded by
tools/asset_capture.gd (frames.json eye/centre/fov, Godot world), shifted by the GLB's placed origin.

  blender -b -t 2 -P gate_stills.py -- GLB FRAMES_JSON ORIGIN_X,Y,Z OUT_DIR ANGLES_DEG(comma) [SAMPLES]
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, frames_path, origin, out, angles = argv[:5]
samples = int(argv[5]) if len(argv) > 5 else 24
origin = Vector([float(v) for v in origin.split(",")])
angles = [float(v) for v in angles.split(",")]


def to_blender(p):
    # Godot (x, y, z) -> Blender (x, -z, y)
    return Vector((p[0], -p[2], p[1]))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
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
for o in bpy.context.scene.objects:
    if o.name.endswith("-col"):
        o.hide_render = True
leaves = [bpy.data.objects[n] for n in ("gate_l", "gate_r")]
rest = [o.matrix_basis.copy() for o in leaves]
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = samples
scene.cycles.use_denoising = False
scene.render.resolution_x = 960
scene.render.resolution_y = 540
world = bpy.data.worlds.new("Stills")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.70, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(55), 0, math.radians(200))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
doc = json.load(open(frames_path))
os.makedirs(out, exist_ok=True)
for frame in doc["frames"]:
    eye = to_blender(Vector(frame["eye"]) - origin)
    centre = to_blender(Vector(frame["target"]) - origin)
    cam.location = eye
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(frame["fov"])
    for deg in angles:
        # Godot local +X turn == Blender local +X turn (the axis map is a turn about X).
        for o, m in zip(leaves, rest):
            o.matrix_basis = m @ Matrix.Rotation(math.radians(deg), 4, "X")
        path = os.path.join(out, "%s-%04.1fdeg.png" % (frame["id"], deg))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("STILL", path)
