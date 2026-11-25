"""CPU Cycles evidence from the exported GLB, never source-only geometry.

blender -b --threads 2 --python-exit-code 1 --python \
  sketches/core-loop/tools/blender/bosses/mind_hand_preview.py -- [--out DIR]
Front, side and three-quarter use equal distance, 65-degree vertical FOV,
960x640, 12 samples and a measured 2 m ball at equal camera depth.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mind_hand as hand
import cycles_device


def plain(name, color, roughness=0.7, metal=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*[hand.linear(v) for v in color], 1)
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metal
    return mat


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--glb", type=Path, default=hand.SKETCH / "assets/models/bosses/mind_hand.glb")
    parser.add_argument("--out", type=Path, default=hand.ROOT / "artifacts/local/dress-preview/MHD")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    hand.common.reset()
    bpy.ops.import_scene.gltf(filepath=str(args.glb))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    imported = {a.name: a for a in bpy.data.actions}
    clips = {name: next(a for key, a in imported.items() if key == name or key.startswith(name + "_"))
             for name in hand.CLIPS}
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.cycles.seed = 17
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x, scene.render.resolution_y = 960, 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.fps = 30
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Open sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.48, 0.55, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.8))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(plain("Preview ground", (0.43, 0.44, 0.41)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1)
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(plain("Reference petrol", hand.PALETTE["petrol"], 0.32, 0.3))
    for p in ball.data.polygons:
        p.use_smooth = True
    for name, loc, energy, size in [("Sky key", (-5, 6, 10), 1400, 7),
                                     ("Sky fill", (7, -4, 6), 1000, 8)]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.shape, light.size = energy, "DISK", size
        ob = bpy.data.objects.new(name, light)
        scene.collection.objects.link(ob)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 1.3)) - ob.location).to_track_quat("-Z", "Y").to_euler()
    camera = bpy.data.objects.new("ArenaCamera", bpy.data.cameras.new("ArenaCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "PERSP"
    camera.data.sensor_fit = "VERTICAL"
    camera.data.angle_y = math.radians(65)
    args.out.mkdir(parents=True, exist_ok=True)
    records = []

    def render(name, yaw, clip="still_track", seconds=0):
        angle = math.radians(yaw)
        eye = Vector((13 * math.sin(angle), 13 * math.cos(angle), 3.0))
        target = Vector((0, 0, 1.3))
        camera.location = eye
        camera.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        right = Vector((math.cos(angle), -math.sin(angle), 0))
        ball.location = right * 3.2 + Vector((0, 0, -0.8))
        depth_axis = (target - eye).normalized()
        horizontal = Vector((depth_axis.x, depth_axis.y, 0)).normalized()
        ball.location -= horizontal * (ball.location - target).dot(depth_axis) / horizontal.dot(depth_axis)
        arm.animation_data.action = clips[clip]
        start = clips[clip].frame_range[0]
        scene.frame_set(int(start + seconds * 30))
        bpy.context.view_layer.update()
        path = args.out / (name + ".png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        records.append({"file": path.name, "clip": clip, "seconds": seconds, "yaw": yaw,
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        "bytes": path.stat().st_size, "reference_diameter_m": 2,
                        "equal_depth_error_m": abs((ball.location - target).dot(depth_axis))})
        print("MHD_PREVIEW", path.name, flush=True)

    for name, yaw in (("mind_hand-front", 0), ("mind_hand-side", 90), ("mind_hand-three-quarter", 35)):
        render(name, yaw)
    for clip, seconds in hand.KEY_POSES.items():
        render("mind_hand-clip-" + clip, 25 if clip == "quote_warn" else 10, clip, seconds)
    manifest = {"asset": str(args.glb), "asset_sha256": hashlib.sha256(args.glb.read_bytes()).hexdigest(),
                "engine": "Cycles", "device": bpy.context.scene.cycles.device, "samples": 12, "threads": 2,
                "resolution": [960, 640], "vertical_fov_degrees": 65,
                "camera_horizontal_distance_m": 13, "frames": records}
    (args.out / "preview-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("MHD_PREVIEWS: PASS (%d frames)" % len(records))


if __name__ == "__main__":
    main()
