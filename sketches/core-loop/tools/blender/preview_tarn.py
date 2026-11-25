"""CPU-only Cycles previews of Tarn. --glb inspects the actual delivered exports."""
import math
import hashlib
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import common
import cycles_device
import rig_pilot
from pilot_tarn import OUT, SKETCH


def studio(scale=2.25):
    camera = rig_pilot.studio()
    scene = bpy.context.scene
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.render.threads = 4
    scene.render.resolution_x = scene.render.resolution_y = 640
    camera.data.ortho_scale = scale
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.01))
    ground = bpy.context.active_object
    ground.name = "PreviewFloor"
    ground.data.materials.append(common._flat("StudioFloor", "bone"))
    return camera


def render(camera, name, location, target=(0, 0, -.03)):
    camera.location = location
    common._look(camera, target)
    bpy.context.scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    print("TARN_PREVIEW:", name)


def render_model(mesh):
    camera = studio(1.30)
    version = hashlib.sha256((OUT / "pilot_tarn_neutral.glb").read_bytes()).hexdigest()[:8]
    render(camera, "model-front-" + version, (0, 5, .12))
    render(camera, "model-side-" + version, (5, 0, .12))
    render(camera, "model-back-" + version, (0, -5, .12))
    render(camera, "model-three-quarter-" + version, (3, 5, 1.5))


def context():
    path = SKETCH / "assets/models/world_one/shell_tarn.glb"
    bpy.ops.import_scene.gltf(filepath=str(path))
    return bpy.data.objects["ShellTarn"]


def delivery_frames(arm, actions):
    camera = studio()
    arm.animation_data.action = actions["drop_land"]
    bpy.context.scene.frame_set(1)
    for name, point in [("front", (0, 5, .55)), ("side", (5, 0, .55)),
                        ("back", (0, -5, .55)), ("three-quarter", (3.2, 5, 1.7))]:
        render(camera, "turnaround-" + name, point)
    key_frames = {"drop_land": 12, "big_cheer": 25, "wince": 5,
                  "slump": 23, "phew": 10, "brace": 6, "heave": 7}
    for clip, frame in key_frames.items():
        arm.animation_data.action = actions[clip]
        bpy.context.scene.frame_set(frame)
        render(camera, "clip-" + clip, (2.6, 5, 1.20))
    arm.animation_data.action = actions["drop_land"]
    bpy.context.scene.frame_set(1)
    camera.data.type = "PERSP"
    camera.data.sensor_fit = "VERTICAL"
    camera.data.angle_y = math.radians(65)
    target = Vector((0, 0, .8))
    camera.location = target + Vector((0, -7.5 * math.cos(.30), 7.5 * math.sin(.30)))
    common._look(camera, target)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.filepath = str(OUT / "chase-rest.png")
    bpy.ops.render.render(write_still=True)


def render_delivery(arm, mesh):
    context()
    delivery_frames(arm, {a.name: a for a in bpy.data.actions})


def main():
    global OUT
    pilot = SKETCH / "assets/models/pilot_tarn_anim.glb"
    shell = SKETCH / "assets/models/world_one/shell_tarn.glb"
    version = hashlib.sha256(pilot.read_bytes() + shell.read_bytes()).hexdigest()[:8]
    OUT = OUT / ("delivery-" + version)
    OUT.mkdir(parents=True, exist_ok=True)
    common.reset()
    bpy.ops.import_scene.gltf(filepath=str(pilot))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    actions = {a.name.split("|")[-1]: a for a in bpy.data.actions}
    context()
    delivery_frames(arm, actions)


if __name__ == "__main__":
    main()
