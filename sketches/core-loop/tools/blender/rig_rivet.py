"""Rebuild the current recipe and rigid-weight its primitives; never edits gameplay.

blender --background --threads 4 --python sketches/core-loop/tools/blender/rig_rivet.py
Evidence and the editable rig are written to artifacts/anim-pilot at repository root.
"""
import ast
import hashlib
import json
import math
from pathlib import Path
import sys
import subprocess

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = ROOT / "artifacts/anim-pilot"
sys.path.insert(0, str(HERE))
import common
import shell_base as sb


def recipe():
    path = HERE / "shell_rivet.py"
    tree = ast.parse(path.read_text())
    # This recipe has an unconditional main(). Load definitions without exporting.
    assert isinstance(tree.body[-1], ast.Expr)
    assert isinstance(tree.body[-1].value, ast.Call)
    assert tree.body[-1].value.func.id == "main"
    tree.body.pop()
    env = {"__file__": str(path), "__name__": "rivet_recipe"}
    exec(compile(tree, str(path), "exec"), env)
    return env


def build():
    common.reset()
    common.preview_class("copper")
    env = recipe()
    records = []
    originals = {}
    depth = [0]
    phase = ["head"]

    def capture(name, fn):
        def wrapped(part, *args, **kwargs):
            if part.name != "Pilot" or depth[0]:
                return fn(part, *args, **kwargs)
            layer = part.bm.verts.layers.int.get("rig_part") or part.bm.verts.layers.int.new("rig_part")
            before = set(part.bm.verts)
            depth[0] += 1
            try:
                result = fn(part, *args, **kwargs)
            finally:
                depth[0] -= 1
            new = set(part.bm.verts) - before
            for v in new:
                v[layer] = len(records) + 1
            records.append((phase[0], name, len(new), args, kwargs))
            return result
        return wrapped

    for name in ("uv", "ring", "rod", "beam", "box", "cyl", "prism"):
        originals[name] = getattr(common.Part, name)
        setattr(common.Part, name, capture(name, originals[name]))
    # A BMesh integer attribute survives deterministic triangulation and conversion.
    original_to_object = common.Part.to_object

    def to_object(part, *args, **kwargs):
        return original_to_object(part, *args, **kwargs)

    common.Part.to_object = to_object
    try:
        animal = env["pilot"]()
        phase[0] = "body"
        root, hull, pilot = sb.spherical("Rivet", env["pod"](), animal)
    finally:
        common.Part.to_object = original_to_object
        for name, fn in originals.items():
            setattr(common.Part, name, fn)

    arm = bpy.data.objects.new("RivetRig", bpy.data.armatures.new("RivetSkeleton"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    spec = [
        ("root", (0, 0, -.6), None),
        ("pelvis", (0, 0, -.3), "root"),
        ("spine_01", (0, 0, -.24), "pelvis"),
        ("spine_02", (0, 0, -.1), "spine_01"),
        ("neck", (0, .015, .005), "spine_02"),
        ("head", (0, .015, .17), "neck"),
        ("snout", (0, .21, .1), "head"),
        ("goggles", (0, .015, .24), "head"),
    ]
    for side, s in (("R", 1), ("L", -1)):
        spec += [
            ("ear." + side, (s * .265, .015, .21), "head"),
            ("shoulder." + side, (s * .13, .005, -.06), "spine_02"),
            ("upper_arm." + side, (s * .24, .015, -.09), "shoulder." + side),
            ("lower_arm." + side, (s * .36, .24, -.12), "upper_arm." + side),
            ("hand." + side, (s * .32, .4, .05), "lower_arm." + side),
            ("curl." + side, (s * .32, .43, .06), "hand." + side),
        ]
    for name, position, parent in spec:
        bone = arm.data.edit_bones.new(name)
        bone.head = position
        # Common rest axes make the human-authored XYZ pose table unambiguous.
        bone.tail = Vector(position) + Vector((0, .08, 0))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        bone.inherit_scale = "FULL"
    arm.show_in_front = True
    arm.data.display_type = "STICK"
    for b in arm.pose.bones:
        b.rotation_mode = "XYZ"

    head_tags = ["head", "snout", "snout", "goggles",
                 "ear.L", "goggles", "goggles", "goggles", "snout",
                 "ear.R", "goggles", "goggles", "goggles", "snout", "goggles"]
    body_tags = ["spine_01", "spine_02"]
    for side in ("L", "R"):
        body_tags += ["pelvis", "pelvis", "pelvis", "shoulder." + side,
                      "upper_arm." + side, "lower_arm." + side, "hand." + side, "spine_02"]
    tags = head_tags + body_tags
    assert len(records) == len(tags), (len(records), len(tags), [(r[0], r[1]) for r in records])
    attr = pilot.data.attributes["rig_part"]
    for index, name in enumerate(tags):
        vg = pilot.vertex_groups.get(name) or pilot.vertex_groups.new(name=name)
        indices = [v.index for v in pilot.data.vertices if attr.data[v.index].value == index + 1]
        assert indices, (index, name)
        vg.add(indices, 1, "REPLACE")
    pilot.parent = arm
    modifier = pilot.modifiers.new("Rigid primitive weights", "ARMATURE")
    modifier.object = arm
    pilot["source"] = "shell_rivet.pilot + shell_base.spherical; unchanged original vertices"
    meshes = [pilot]
    for side, s in (("R", 1), ("L", -1)):
        claws = common.Part("Claws." + side)
        for dx in (-.041, 0, .041):
            claws.rod("pilot", (s * .32 + dx, .44, .055),
                      (s * .32 + dx, .535, .035), .015, 6, color="bone", r2=.004)
        obj = claws.to_object()
        vg = obj.vertex_groups.new(name="curl." + side)
        vg.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        obj.parent = arm
        obj.modifiers.new("Rigid claws", "ARMATURE").object = arm
        meshes.append(obj)
    for obj in common.tree(root):
        obj.hide_render = True
    root.hide_render = True
    # The empty shell hierarchy is retained only for the contextual movie.
    pilot.hide_render = False
    arm["pelvis_anchor"] = [0, 0, -.3]
    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "bones": len(spec), "original_pilot_triangles": common.tris(pilot),
        "export_pilot_triangles": sum(common.tris(o) for o in meshes),
        "parts": [{"index": i+1, "phase": r[0], "primitive": r[1], "bone": tags[i]}
                  for i, r in enumerate(records)],
        "sources": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (HERE / "shell_rivet.py", HERE / "shell_base.py", HERE / "common.py")},
        "scope": "pilot animation only; no game integration; +Y forward, +Z up, character R is +X",
        "containment": "systemd user scope bus unavailable; Blender run plainly with four threads",
    }
    (OUT / "rig-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    return arm, meshes, root


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("Neutral studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.39, .40, .39, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .65
    for name, location, energy, size in [
        ("Key", (2, 3, 4), 180, 3), ("Fill", (-3, 1, 1), 100, 3),
        ("Rim", (1, -3, 3), 180, 2)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size = energy, "DISK", size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        common._look(obj, (0, 0, 0))
    cam = bpy.data.objects.new("PilotCamera", bpy.data.cameras.new("PilotCamera"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.65
    scene.camera = cam
    return cam


def render_view(cam, path, view="front", scale=1.65):
    positions = {"front": (0, 5, -.035), "back": (0, -5, -.035),
                 "side": (5, 0, -.035), "chase": (2.5, -4, 1.6)}
    cam.location = positions[view]
    common._look(cam, (0, .05, -.035))
    cam.data.ortho_scale = scale
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def clear_pose(arm):
    for bone in arm.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_euler = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def point_segment(arm, name, child, target):
    """Rotate one rest segment toward a world target, retaining its length."""
    bone = arm.pose.bones[name]
    child_bone = arm.pose.bones[child]
    bpy.context.view_layer.update()
    direction = Vector(target) - bone.head
    current = child_bone.head - bone.head
    rotation = current.rotation_difference(direction)
    matrix = bone.matrix.copy()
    matrix = rotation.to_matrix().to_4x4() @ matrix
    matrix.translation = bone.head
    bone.matrix = matrix
    bpy.context.view_layer.update()


def main():
    arm, meshes, root = build()
    cam = studio()
    refs = OUT / "references"
    refs.mkdir(exist_ok=True)
    for view in ("front", "back", "side"):
        render_view(cam, refs / (view + ".png"), view)
    for side, s in (("R", 1), ("L", -1)):
        point_segment(arm, "upper_arm." + side, "lower_arm." + side, (s, .015, -.09))
        point_segment(arm, "lower_arm." + side, "hand." + side, (s * 1.5, .015, -.09))
    render_view(cam, refs / "t-pose.png", "front")
    clear_pose(arm)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "rivet-rig.blend"))
    subprocess.run(["python",str(HERE/"compose_rivet_evidence.py"),"--rig"],check=True)


if __name__ == "__main__":
    main()
