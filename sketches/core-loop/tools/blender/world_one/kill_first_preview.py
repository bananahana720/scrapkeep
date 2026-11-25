"""Preview stills for the kill-first bodies (Splitter, its piece, Linker).

CPU Cycles, 16 samples. Orthographic turnaround (front, three-quarter, side, back) beside a
2 m reference ball, then a game-camera still: perspective, 50 degree vertical field,
14 m back and 6 m up, the distance the chase camera reads a pack from. `lit=True` adds a
second game-camera still with the requisition_tag surfaces flared white, the split or
brace tell. Previews only; nothing here reaches the exported files.
"""
import math
import os

import bpy
from mathutils import Vector

import common
import cycles_device


def _scene(floor):
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
    bg.inputs["Color"].default_value = (0.25, 0.30, 0.36, 1)
    bg.inputs["Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, floor))
    bpy.context.object.data.materials.append(common._flat("Floor", "c6a274"))
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


def _ball(floor, x):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=(x, 0, floor + 1))
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("ReferenceBone", "bone"))
    for poly in ball.data.polygons:
        poly.use_smooth = True
    return ball


def flare(on):
    """Previews the tell: requisition_tag glows white (runtime does this, not the file)."""
    mat = bpy.data.materials.get("requisition_tag")
    if mat is None:
        return
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.97, 0.9, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 6.0 if on else 0.0


def render(name, root, outdir, floor, focus=(0, 0, 0), scale=5.6, ball_x=None, extras=None,
           lit=True, game_target=None, face_yaw=180):
    scene, cam = _scene(floor)
    ball = _ball(floor, ball_x if ball_x is not None else -scale * 0.42)
    if extras:
        extras()
    os.makedirs(outdir, exist_ok=True)
    focus = Vector(focus)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    for label, turn in [("front", 0), ("three_quarter", -45), ("side", -90), ("back", 180)]:
        root.rotation_euler = (0, 0, math.radians(face_yaw + turn))
        cam.location = focus + Vector((0, -12, 3.0))
        common._look(cam, focus)
        scene.render.filepath = os.path.join(outdir, "%s_%s.png" % (name, label))
        bpy.ops.render.render(write_still=True)
    root.rotation_euler = (0, 0, math.radians(face_yaw - 30))
    ball.location.x = -6
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(50)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    target = Vector(game_target) if game_target else focus
    cam.location = target + Vector((0, -14, 6))
    common._look(cam, target)
    shots = [("game", False)] + ([("game_tell", True)] if lit else [])
    for label, on in shots:
        flare(on)
        scene.render.filepath = os.path.join(outdir, "%s_%s.png" % (name, label))
        bpy.ops.render.render(write_still=True)
    flare(False)
    print("PREVIEWS", name, outdir)
