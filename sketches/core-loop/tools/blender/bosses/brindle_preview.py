"""CPU Cycles previews of reimported GLBs, with a 2 m sphere at equal depth.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/brindle_preview.py
No GPU, display, colliders or game-script dependency. Arena metres are unscaled.
"""
import hashlib
import json
import math
import struct
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent)]
import common
import cycles_device
import brindle_model as model
import brindle_animation as anim


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 960, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.threads_mode, scene.render.threads = "FIXED", 2
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    scene.world = bpy.data.worlds.new("ArenaSky")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.29, .35, .4, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .5
    scene.view_settings.view_transform = "AgX"
    bpy.ops.object.light_add(type="AREA", location=(-10, -8, 18))
    light = bpy.context.object
    light.data.energy, light.data.shape, light.data.size = 3200, "DISK", 12
    light.rotation_euler = (Vector((0, 0, 3)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=(10, 7, 10))
    fill = bpy.context.object
    fill.data.energy, fill.data.size = 1600, 10
    fill.rotation_euler = (Vector((0, 0, 3)) - fill.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=130)
    ground = bpy.context.object
    mat = bpy.data.materials.new("preview_sandstone")
    mat.diffuse_color = common.rgba("sandstone")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = common.rgba("sandstone")
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .95
    ground.data.materials.append(mat)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    scene.camera = cam
    return cam


def preview_files(directory=model.MODELS):
    output = model.PREVIEW
    output.mkdir(parents=True, exist_ok=True)
    recipe_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    rows = []
    for stem, root_name, clips in (("boss_brindle", "BrindleRoot", anim.SHIP_CLIPS),
                                   ("boss_brindle_scooter", "ScooterRoot", anim.SCOOTER_CLIPS)):
        common.reset()
        bpy.context.scene.render.fps = 30
        path = directory / (stem + ".glb")
        glb_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        bpy.ops.import_scene.gltf(filepath=str(path))
        root = bpy.data.objects[root_name]
        for obj in common.tree(root):
            if obj.animation_data:
                obj.animation_data.action = None
                for track in obj.animation_data.nla_tracks:
                    track.mute = True
        bpy.context.scene.frame_set(0)
        # Blender's importer can leave the first action's pose on an object after
        raw = path.read_bytes()
        gltf = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 12)[0]])
        conversion = Matrix.Rotation(math.pi / 2, 4, "X")
        for record in gltf["nodes"]:
            obj = bpy.data.objects.get(record["name"])
            if obj is None:
                continue
            q = record.get("rotation", [0, 0, 0, 1])
            local = Matrix.LocRotScale(Vector(record.get("translation", [0, 0, 0])),
                Quaternion((q[3], q[0], q[1], q[2])), Vector(record.get("scale", [1, 1, 1])))
            obj.matrix_basis = conversion @ local @ conversion.inverted()
        bpy.context.view_layer.update()
        anim.remember(root)
        cam = studio()
        ground_height = 0 if stem == "boss_brindle" else -.5
        bpy.data.objects["Plane"].location.z = ground_height
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
        ball = bpy.context.object
        ball.name = "ReferenceBall_2m"
        ball.data.materials.append(common.material("bare_metal"))
        is_ship = stem == "boss_brindle"
        target = Vector((0, 0, 4.2 if is_ship else .15))
        views = [("front", 0), ("side", 90), ("three_quarter", 35)]
        cam.data.ortho_scale = 24 if is_ship else 7.5
        def render_one(name, yaw, clip=None, seconds=0):
            anim.restore(root)
            if clip:
                anim.preview_pose(root, clip, seconds)
            else:
                bpy.context.scene.frame_set(0)
            a = math.radians(yaw)
            distance = 34 if is_ship else 10
            direction = Vector((math.sin(a), math.cos(a), .34))
            cam.location = target + direction * distance
            cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            perpendicular = Vector((math.cos(a), -math.sin(a), 0))
            ball.location = perpendicular * (10 if is_ship else 2.35) + Vector((0, 0, ground_height + 1))
            dest = output / (stem + "__" + glb_hash[:8] + "_" + recipe_hash[:8] + "__" + name + ".png")
            bpy.context.scene.render.filepath = str(dest)
            bpy.ops.render.render(write_still=True)
            assert dest.is_file()
            rows.append({"file": dest.name, "glb": path.name, "clip": clip,
                         "seconds": seconds, "view": yaw, "reference_diameter_m": 2,
                         "ortho_scale_m": cam.data.ortho_scale,
                         "sha256": hashlib.sha256(dest.read_bytes()).hexdigest()})
        for view, yaw in views:
            render_one(view, yaw)
        for clip, (_duration, key) in clips.items():
            render_one(clip, 35, clip, key)
    manifest = {"engine": "Blender " + bpy.app.version_string, "render": "Cycles " + bpy.context.scene.cycles.device,
                "samples": 12, "dimensions": [960, 720], "fps": 30, "preview_recipe_sha256": recipe_hash,
                "glb_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in directory.glob("boss_brindle*.glb")}, "images": rows}
    (output / "preview-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("BRI previews: PASS %d PNGs, two GLBs, every authored clip" % len(rows))


if __name__ == "__main__":
    preview_files()
