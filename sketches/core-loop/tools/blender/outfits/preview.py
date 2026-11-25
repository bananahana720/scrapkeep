"""Cycles CPU stills of a shipped rig wearing an outfit GLB, mounted by its bone frames.

blender -b --python-exit-code 1 -P preview.py -- <item id|bare rig glb> [--out DIR] [--samples N]
The outfit's top-level nodes are put at their bones' rest frames, as BoneAttachment3D does
in game, and a Replace_<name> node hides the rig's <name>. The pilot's glass dome and pod are left out so the head reads.
"""
import argparse
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
import rig_space
from build_outfits import ITEMS, SKETCH

ROOT = SKETCH.parents[1]


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "ARMATURE":
            if o.animation_data:
                o.animation_data.action = None
            for b in o.pose.bones:
                b.location, b.rotation_quaternion, b.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
                b.rotation_euler = (0, 0, 0)
        elif o.animation_data:
            o.animation_data.action = None
    return new


def wear(rig_glb, outfit_glb, pose=None):
    rig = import_glb(rig_glb)
    frames = rig_space.joint_frames(rig_glb)
    worn = import_glb(outfit_glb) if outfit_glb else []
    for o in worn:
        if o.parent is None and o.name.split(".")[0] in frames:
            o.matrix_world = frames[o.name.split(".")[0]]
    hidden = {o.name.split(".")[0][len("Replace_"):] for o in worn if o.name.startswith("Replace_")}
    for o in rig:
        if o.name.split(".")[0] in hidden:
            o.hide_render = True
    if pose:
        pose(worn)
    return rig, worn


def light_and_render(target, shots, out, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    world = scene.world or bpy.data.worlds.new("preview")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba(common.mix("sandstone", "bone", .5))
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy, sun.data.angle = 3.0, math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    paths = []
    for label, yaw, pitch, dist, res in shots:
        scene.render.resolution_x = scene.render.resolution_y = res
        cam.data.angle = math.radians(30)
        t = Vector(target)
        y, p = math.radians(yaw), math.radians(pitch)
        cam.location = t + dist * Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))
        cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out, "%s.png" % label)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("item")
    ap.add_argument("--out", type=Path, default=ROOT / "artifacts/local/outfits")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--bare", action="store_true", help="render the rig without the outfit")
    ap.add_argument("--down", action="store_true", help="pose the item's clip at its last key")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
    spec = ITEMS[a.item]
    common.reset()
    outfit = None if a.bare else SKETCH / spec["out"]
    pose = spec.get("pose_down" if a.down else "pose")
    wear(SKETCH / spec["rig"], outfit, pose)
    tag = a.item + ("_bare" if a.bare else "_down" if a.down else "")
    out = a.out / tag
    out.mkdir(parents=True, exist_ok=True)
    paths = light_and_render(spec["look_at"], [(tag + "_" + l, *v) for l, v in spec["shots"].items()], str(out), a.samples)
    print("PREVIEW", *paths)


if __name__ == "__main__":
    main()
