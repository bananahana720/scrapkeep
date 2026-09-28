"""Eight-view turntable and a chase-distance still for one GLB, rendered with CPU Cycles.

blender -b --factory-startup --python turntable_blender.py -- --in model.glb --out-dir DIR --name warden
Writes DIR/<name>_tt_0..7.png (900x900) and DIR/<name>_chase.png (1920x1080, camera 12 m away,
60 degree vertical FOV, 1.8 m eye height, on a sandstone ground plane).
With --backface-check it instead writes DIR/<name>_bf_0..7.png, where any camera ray that lands on
a back face is flat magenta, and prints BACKFACE_JSON with the magenta share of object pixels.
Cycles ignores the material's backface-culling flag, so this shows where a single-sided
material would open a hole in the engine.
"""
import argparse
import json
import math
import sys

import bpy
from mathutils import Vector


def parse():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--samples", type=int, default=48)
    p.add_argument("--chase-distance", type=float, default=12.0)
    p.add_argument("--chase-height", type=float, default=1.8)
    p.add_argument("--fov", type=float, default=60.0)
    p.add_argument("--backface-check", action="store_true")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def tint_backfaces(meshes):
    for mat in {slot.material for o in meshes for slot in o.material_slots if slot.material}:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        output = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        surface = output.inputs["Surface"].links[0].from_socket
        geometry = nodes.new("ShaderNodeNewGeometry")
        magenta = nodes.new("ShaderNodeEmission")
        magenta.inputs["Color"].default_value = (1.0, 0.0, 1.0, 1.0)
        mix = nodes.new("ShaderNodeMixShader")
        links.new(geometry.outputs["Backfacing"], mix.inputs["Fac"])
        links.new(surface, mix.inputs[1])
        links.new(magenta.outputs["Emission"], mix.inputs[2])
        links.new(mix.outputs["Shader"], output.inputs["Surface"])


def magenta_share(path):
    image = bpy.data.images.load(path)
    px = image.pixels[:]
    covered = magenta = 0
    for i in range(0, len(px), 4):
        if px[i + 3] > 0.5:
            covered += 1
            if px[i] > 0.9 and px[i + 1] < 0.1 and px[i + 2] > 0.9:
                magenta += 1
    bpy.data.images.remove(image)
    return covered, magenta


def look_at(cam, target):
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    a = parse()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = a.samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.72, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.93, 0.82)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    cam.data.lens = 50
    distance = radius / math.tan(cam.data.angle / 2) * 1.1

    if a.backface_check:
        tint_backfaces(meshes)
        scene.cycles.samples = 1
        scene.cycles.use_denoising = False
        scene.cycles.pixel_filter_type = "BOX"
        scene.cycles.filter_width = 0.01
        scene.render.film_transparent = True
        views = []
        for i in range(8):
            yaw = math.radians(i * 45 - 30)
            cam.location = centre + Vector((math.sin(yaw), -math.cos(yaw), 0.45)).normalized() * distance
            look_at(cam, centre)
            scene.render.filepath = f"{a.out_dir}/{a.name}_bf_{i}.png"
            bpy.ops.render.render(write_still=True)
            covered, magenta = magenta_share(scene.render.filepath)
            views.append({"view": i, "object_px": covered, "backface_px": magenta})
        worst = max(v["backface_px"] / max(v["object_px"], 1) for v in views)
        print("BACKFACE_JSON " + json.dumps({"name": a.name, "worst_view_share": round(worst, 5), "views": views}))
        return

    for i in range(8):
        yaw = math.radians(i * 45 - 30)
        cam.location = centre + Vector((math.sin(yaw), -math.cos(yaw), 0.45)).normalized() * distance
        look_at(cam, centre)
        scene.render.filepath = f"{a.out_dir}/{a.name}_tt_{i}.png"
        bpy.ops.render.render(write_still=True)

    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, lo.z))
    ground = bpy.context.active_object
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.42, 0.24, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    ground.data.materials.append(mat)

    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(a.fov)
    yaw = math.radians(-30)
    cam.location = Vector((centre.x + math.sin(yaw) * a.chase_distance, centre.y - math.cos(yaw) * a.chase_distance, lo.z + a.chase_height))
    look_at(cam, Vector((centre.x, centre.y, lo.z + (hi.z - lo.z) * 0.4)))
    scene.render.filepath = f"{a.out_dir}/{a.name}_chase.png"
    bpy.ops.render.render(write_still=True)
    print(f"TURNTABLE_DONE {a.name}")


main()
