"""Preview stills for the world 2 and 3 bodies (pit jaw, gap net, ballast heavy, prop crew,
floodlight rig).

CPU Cycles, 16 samples. Orthographic turnaround (front, three-quarter, side) beside a 2 m
reference ball, then game-camera stills: perspective, 50 degree vertical field, 14 m back and
6 m up, the distance the chase camera reads a pack from. Each `poses` entry renders one more
game-camera still after calling its function (the tell pose, a closed jaw), then `rest` puts
the body back. `game_extras` stages the game-camera stills only (a far post, a gap). `ground` tints the floor for the world: Dig sandstone, Highdraft sky.
Previews only; nothing here reaches the exported files.
"""
import math
import os

import bpy
from mathutils import Vector

import common
import cycles_device

GROUNDS = {"dig": ("a7865c", (0.22, 0.2, 0.19)), "highdraft": ("9aa7a0", (0.48, 0.62, 0.78))}


def _scene(floor, ground):
    tint, sky = GROUNDS[ground]
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*sky, 1)
    bg.inputs["Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, floor))
    bpy.context.object.name = "PreviewFloor"
    bpy.context.object.data.materials.append(common._flat("Floor", tint))
    for label, at, power, area in [("Key", (4, -6, 8), 1400, 5), ("Fill", (-5, -1, 4), 600, 4),
                                   ("Rim", (0, 7, 5), 700, 4)]:
        light = bpy.data.lights.new(label, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = area
        obj = bpy.data.objects.new(label, light)
        scene.collection.objects.link(obj)
        obj.location = at
        common._look(obj, (0, 0, 0.5))
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def ball(floor, x, y=0.0, z=None, name="ReferenceBall_2m"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1,
                                         location=(x, y, floor + 1 if z is None else z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(common._flat("ReferenceBone", "bone"))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def render(name, root, outdir, floor, ground, focus=(0, 0, 0), scale=5.6, ball_x=None, extras=None,
           game_extras=None, poses=(), rest=None, game_target=None, game_back=14.0, game_up=6.0, face_yaw=0, game_yaw=-30):
    scene, cam = _scene(floor, ground)
    ref = ball(floor, ball_x if ball_x is not None else -scale * 0.42)
    if extras:
        extras()
    os.makedirs(outdir, exist_ok=True)
    focus = Vector(focus)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    for label, turn in [("front", 0), ("three_quarter", -45), ("side", -90)]:
        root.rotation_euler = (0, 0, math.radians(face_yaw + turn))
        cam.location = focus + Vector((0, -12, 3.0))
        common._look(cam, focus)
        scene.render.filepath = os.path.join(outdir, "%s_%s.png" % (name, label))
        bpy.ops.render.render(write_still=True)
    root.rotation_euler = (0, 0, math.radians(face_yaw + game_yaw))
    ref.location.x = -6
    if game_extras:
        game_extras()
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(50)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    target = Vector(game_target) if game_target else focus
    cam.location = target + Vector((0, -game_back, game_up))
    common._look(cam, target)
    for label, pose in [("game", None)] + list(poses):
        if pose:
            pose()
        scene.render.filepath = os.path.join(outdir, "%s_%s.png" % (name, label))
        bpy.ops.render.render(write_still=True)
        if rest:
            rest()
    print("PREVIEWS", name, outdir)


def budget(path, draws, tris=1100, verts=2100):
    """Reads the exported glb back and asserts the enemy budget (assets/asset_budgets.json)."""
    import json
    import struct
    data = open(path, "rb").read()
    size = struct.unpack_from("<I", data, 12)[0]
    glb = json.loads(data[20:20 + size])
    prims = [p for m in glb["meshes"] for p in m["primitives"]]
    v = sum(glb["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
    t = sum(glb["accessors"][p["indices"]]["count"] // 3 for p in prims)
    print("EXPORTED %s: %d V / %d T / %d D" % (os.path.basename(path), v, t, len(prims)))
    assert v <= verts and t <= tris and len(prims) == draws, (v, t, len(prims))
