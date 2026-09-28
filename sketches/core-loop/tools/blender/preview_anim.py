# Preview only (writes no asset): replays the pose trace tests/shell_animator_test.gd
# writes (env SHELL_ANIM_TRACE) on the shell glbs and renders one labelled frame strip
# per class, so the animator's motion can be judged by eye without a window. Each trace
# frame holds every node's Godot local transform plus the device glow, dome glint and
# cloak shimmer the animator set; this script converts the transforms to Blender's
# Z-up frame (x, y, z) = (gx, -gz, gy) and applies them before rendering.
#   blender -b --factory-startup -P preview_anim.py -- --trace trace.json --render <dir>

import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
from common import Vector  # noqa: E402
from mathutils import Matrix  # noqa: E402

CLASSES = (("pylon_engineer", "sable", "mint"), ("runner_gunner", "rivet", "copper"),
           ("demolitions_caster", "kest", "amber"))
GLOWING = ("class_accent", "field")
# Godot to Blender basis change: Blender x = gx, y = -gz, z = gy.
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
FRAME = 360
TARGET = (0.0, 0.0, 0.95)


def import_glb(path):
    """Import a shell glb and swap its slot materials for the preview palette (the same
    swap preview_growth.py makes, kept here because that script runs on import)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type != "MESH":
            continue
        attrs = o.data.color_attributes
        for i, slot in enumerate(o.material_slots):
            name = slot.material.name.split(".")[0] if slot.material else ""
            if name in common.SLOTS:
                mat = common.material(name).copy() if attrs else common.material(name)
                node = mat.node_tree.nodes.get("Color Attribute")
                if node is not None and attrs:
                    node.layer_name = attrs[0].name
                o.material_slots[i].material = mat
    return new


def stage():
    """Background, ground, sun and camera, as common.render_turntable lays them out."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 24
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("preview")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = common.rgba(common.mix("sandstone", "bone", 0.5))
    bg.inputs["Strength"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -1.05))
    bpy.context.active_object.data.materials.append(common._flat("ground", "sandstone"))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun_obj = bpy.data.objects.new("sun", sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = FRAME
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(32)
    # The chase camera sits behind; the strip looks from the front quarter so the
    # pilot's face, ears, visor and crest read.
    cam.location = Vector(TARGET) + Vector((1.4, 3.2, 2.0))
    common._look(cam, TARGET)
    return scene


def godot_matrix(v):
    m = Matrix.Identity(4)
    for col in range(3):
        for row in range(3):
            m[row][col] = v[col * 3 + row]
    m[0][3], m[1][3], m[2][3] = v[9], v[10], v[11]
    return m


def own(obj, slots, name):
    """Give obj private copies of the materials in slots, so one device lights alone."""
    mats = []
    for s in obj.material_slots:
        if s.material is None or s.material.name.split(".")[0] not in slots:
            continue
        s.material = s.material.copy()
        s.material.name = "%s_%s" % (name, s.material.name)
        mats.append(s.material)
    return mats


def bsdf(mat):
    return mat.node_tree.nodes.get("Principled BSDF")


def render_class(trace_id, cls, color, frames, outdir):
    common.reset()
    common.preview_class(color)
    objs = {o.name: o for o in import_glb(os.path.join(common.MODELS, "shell_%s.glb" % cls))}
    devices = {n: own(objs[n], GLOWING, n) for n in frames[0]["glow"] if n in objs}
    glass = own(objs["Dome"], ("glass",), "Dome") if "Dome" in objs else []
    cloak = []
    for n in ("Pod", "Core"):
        if n in objs:
            cloak += own(objs[n], set(common.SLOTS) - {"glass", "pilot"}, n)
    for m in cloak:
        m.surface_render_method = "BLENDED"
    rest = {n: o.matrix_basis.copy() for n, o in objs.items()}
    root = [o for o in objs.values() if o.parent is None][0]
    scene = stage()
    paths = []
    for k, frame in enumerate(frames):
        for n, o in objs.items():
            v = frame["nodes"].get(n)
            if v is None or o is root:
                o.matrix_basis = rest[n]
                continue
            o.matrix_basis = C @ godot_matrix(v) @ C.inverted()
        for n, mats in devices.items():
            for m in mats:
                bsdf(m).inputs["Emission Strength"].default_value = 0.45 * frame["glow"].get(n, 0.5)
        for m in glass:
            b = bsdf(m)
            b.inputs["Emission Color"].default_value = (1, 1, 1, 1)
            b.inputs["Emission Strength"].default_value = 0.6 * frame["glint"]
        for m in cloak:
            bsdf(m).inputs["Alpha"].default_value = 1.0 - frame["shimmer"]
        path = os.path.join(outdir, "%s_%02d.png" % (cls, k))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(("%d %s" % (k, frame["label"]), path))
    strip = os.path.join(outdir, "strip_%s.png" % cls)
    labelled = []
    for label, path in paths:
        labelled += ["-label", label, path]
    subprocess.run(["montage", *labelled, "-tile", "%dx1" % len(paths), "-geometry", "+3+3",
                    "-pointsize", "18", "-background", "#242a28", "-fill", "#e8e2d4",
                    "-title", "%s (%s)" % (cls, trace_id), strip], check=True)
    print("STRIP", strip)
    return strip


def main():
    trace_path = sys.argv[sys.argv.index("--trace") + 1]
    outdir = sys.argv[sys.argv.index("--render") + 1]
    os.makedirs(outdir, exist_ok=True)
    trace = json.load(open(trace_path))
    strips = [render_class(t, cls, color, trace[t], outdir) for t, cls, color in CLASSES if t in trace]
    sheet = os.path.join(outdir, "anim_sheet.png")
    subprocess.run(["convert", *strips, "-append", sheet], check=True)
    print("SHEET", sheet)


main()
