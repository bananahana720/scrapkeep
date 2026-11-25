"""Preview still for the anchors family (anchors.py): all fifteen posts in a 5 x 3 lineup (families across, variants a/b/c
going back) on a sand ground plane, seen at a 3/4 angle. Cycles on the CPU, so it runs without a GPU; 1600 x 900.

  prlimit -v12884901888 blender --background --threads 2 --python-exit-code 1 --python \\
      sketches/core-loop/tools/blender/park/anchors_preview.py -- [--models DIR] --out FILE.png [--samples N]
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device

FAMILIES = ("hoodoo", "basalt", "timber", "saguaro", "cairn")
SPACING = 11.0


def vc_material():
    mat = bpy.data.materials.new("preview_vc")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .9
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat, attr


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", default=str(Path(common.SKETCH) / "assets/models/park"))
    parser.add_argument("--out", required=True)
    parser.add_argument("--samples", type=int, default=48)
    args = parser.parse_args(argv)

    common.reset()
    scene = bpy.context.scene
    mat, attr = vc_material()
    for i, fam in enumerate(FAMILIES):
        for k, v in enumerate("abc"):
            rid = "anchor_%s_%s" % (fam, v)
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(Path(args.models) / (rid + ".glb")))
            new = [o for o in bpy.data.objects if o not in before]
            roots = [o for o in new if o.parent is None]
            for o in new:
                if o.type != "MESH":
                    continue
                if o.name.endswith("-col"):
                    o.hide_render = True
                    continue
                if o.data.color_attributes:
                    attr.layer_name = o.data.color_attributes[0].name
                o.data.materials.clear()
                o.data.materials.append(mat)
            for r in roots:
                r.location = (i * SPACING, k * SPACING, 0.0)

    bpy.ops.mesh.primitive_plane_add(size=400, location=(2 * SPACING, SPACING, 0.0))
    ground = bpy.data.materials.new("sand")
    ground.use_nodes = True
    g = ground.node_tree.nodes.get("Principled BSDF")
    g.inputs["Base Color"].default_value = common.rgba("d8c39a")
    g.inputs["Roughness"].default_value = 1.0
    bpy.context.active_object.data.materials.append(ground)

    world = bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("bcd4e0")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(3)
    sun_obj = bpy.data.objects.new("sun", sun)
    sun_obj.rotation_euler = (math.radians(48), math.radians(8), math.radians(-35))
    scene.collection.objects.link(sun_obj)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.lens = 40
    target = Vector((2 * SPACING, SPACING, 3.2))
    az, el, dist = math.radians(-58), math.radians(19), 76.0
    cam.location = target + Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el))) * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 4
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.render.resolution_percentage = 100
    scene.render.filepath = args.out
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", args.out)


if __name__ == "__main__":
    main()
