"""Highdraft props, metres, Blender Z up; one surface per exported file.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/highdraft/props.py -- --out-dir DIR
Add --preview-dir DIR to reimport the GLBs and render three CPU Cycles views.
Static part names are empty markers because their geometry is merged for batching.
Fan and sail use rigid weights in the same surface, without root motion.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
import polish

PETROL = "53686d"
CHALK = "c8bda5"
BONE = "d2c5a5"
DARK = "242a28"
OXIDE = "9b513a"


TRI_CAP, VERT_CAP = 1100, 900
STYLES = {"hard": (0.03, 0), "round": (0, 1), "flat": (0, 0)}


class Prop:
    def __init__(self, name):
        common.reset()
        self.name = name
        self.root = common.empty(name)
        self.parts = {}
        self.markers = set()

    def get(self, style="hard", moving=False):
        key = (style, moving)
        if key not in self.parts:
            part = common.Part("Surface." + style + ("m" if moving else ""))
            part.bevel, part.subsurf = STYLES[style]
            self.parts[key] = part
        return self.parts[key]

    def marker(self, name, loc=(0, 0, 0)):
        if name not in self.markers:
            common.empty(name, loc, self.root)
            self.markers.add(name)

    def add(self, name, method, *args, moving=False, style="hard", **kwargs):
        faces = getattr(self.get(style, moving), method)("paint", *args, **kwargs)
        self.marker(name)
        return faces

    def box(self, name, size, loc, color=PETROL, **kwargs):
        return self.add(name, "box", size, loc=loc, color=color, **kwargs)

    def cyl(self, name, radius, depth, loc, color=BONE, segs=10, rot=(0, 0, 0), **kwargs):
        return self.add(name, "cyl", radius, radius, depth, segs=segs,
                        loc=loc, rot=rot, color=color, **kwargs)

    def ring(self, name, inner, outer, depth, loc, color=BONE, segs=12,
             rot=(math.pi / 2, 0, 0), **kwargs):
        return self.add(name, "ring", inner, outer, depth, segs=segs,
                        loc=loc, rot=rot, color=color, **kwargs)

    def beam(self, name, a, b, width, color=PETROL, **kwargs):
        return self.add(name, "beam", a, b, width, color=color, **kwargs)

    def wear(self, part, stone=False):
        part.bm.normal_update()
        for i, face in enumerate(part.bm.faces):
            if i % 13 == 2 and face.normal.z > 0.35:
                for loop in face.loops:
                    old = loop[part.col]
                    rubbed = common.rgba(CHALK if stone else BONE)
                    loop[part.col] = tuple(old[k] * 0.72 + rubbed[k] * 0.28 for k in range(4))
            elif i % 19 == 4 and abs(face.normal.z) < 0.7:
                for loop in face.loops:
                    old = loop[part.col]
                    rust = common.rgba(DARK if stone else OXIDE)
                    loop[part.col] = tuple(old[k] * 0.70 + rust[k] * 0.30 for k in range(4))

    def finish(self, motion=None, stone=False):
        objs = []
        for key in sorted(self.parts):
            part = self.parts[key]
            self.wear(part, stone)
            obj = part.to_object(parent=self.root)
            if motion is not None:
                group = obj.vertex_groups.new(name="Motion" if key[1] else "Static")
                group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
            objs.append(obj)
        obj = objs[0]
        if len(objs) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.join()
        obj.name = obj.data.name = "Surface"
        if stone:
            common.material("paint").node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
        if motion is not None:
            make_rig(self.root, obj, motion)
        return self.root


def spool():
    p = Prop("prop_spool")
    p.box("Feet", (2.8, 2.2, 0.35), (0, 0, 0.175))
    for s in (-1, 1):
        p.box("Feet", (0.24, 0.55, 1.05), (s * 1.05, 0, 0.875))
        p.cyl("Flange", 1.2, 0.18, (s * 0.99, 0, 1.4), segs=12,
              rot=(0, math.pi / 2, 0))
        p.cyl("Flange", 0.22, 0.10, (s * 1.12, 0, 1.4), PETROL, 6,
              rot=(0, math.pi / 2, 0))
    rows = []
    for x, radius in ((-0.9, 0.76), (-0.45, 0.8), (0, 0.73), (0.45, 0.8), (0.9, 0.76)):
        rows.append([p.get("round").bm.verts.new((x, radius * math.cos(k * math.tau / 10),
                                         1.4 + radius * math.sin(k * math.tau / 10))) for k in range(10)])
    for i in range(4):
        for k in range(10):
            f = p.get("round").bm.faces.new((rows[i][k], rows[i][(k + 1) % 10],
                                     rows[i + 1][(k + 1) % 10], rows[i + 1][k]))
            p.get("round").paint([f], "paint", common.mix(DARK, BONE, 0.12 if (k + i) % 4 == 0 else 0.035))
    for row, reverse in ((rows[0], True), (rows[-1], False)):
        p.get("round").paint([p.get("round").bm.faces.new(list(reversed(row)) if reverse else row)], "paint", DARK)
    p.marker("Barrel")
    p.marker("axle", (0, 0, 1.4))
    p.marker("line_out", (0, 1.1, 1.4))
    return p.finish()


def bearing():
    p = Prop("prop_bearing")
    p.box("Foot", (1.8, 1.4, 0.35), (0, 0, 0.175))
    for a in (0.035, math.pi + 0.035):
        p.ring("SplitHousing", 0.40, 0.65, 0.8, (0, 0, 0.9), segs=6,
               arc=(a, a + math.pi - 0.07))
    p.ring("InnerRing", 0.27, 0.35, 0.84, (0, 0, 0.9), DARK, 10)
    for s in (-1, 1):
        p.box("Foot", (0.24, 0.28, 0.12), (s * 0.72, 0, 0.41), BONE)
    p.marker("load_axis", (0, 0, 0.9))
    return p.finish()


def fan():
    p = Prop("prop_fan")
    p.ring("Bell", 1.32, 1.5, 1.2, (0, 0, -1.8), segs=12)
    p.box("Bracket", (0.5, 1.8, 0.18), (0, 0, -0.09))
    for s in (-1, 1):
        p.beam("Bracket", (0, s * 0.81, -0.18), (0, s * 0.5, -1.2), 0.18)
    for x in (-0.55, 0.55):
        p.beam("Guards", (x, 0.66, -3.05), (x, 0.66, -0.55), 0.12, DARK, style="flat")
    for z in (-2.35, -1.25):
        p.beam("Guards", (-1.25, 0.66, z), (1.25, 0.66, z), 0.12, DARK, style="flat")
    for k in range(3):
        angle = k * math.tau / 3
        m = common.mtx((0, 0, -1.8), (math.pi / 2, 0, 0)) @ Matrix.Rotation(angle, 4, "Z")
        p.add("Blades", "prism", [(0.12, -0.10), (1.1, -0.24), (1.22, 0.14), (0.18, 0.19)],
              0.065, matrix=m, color=PETROL, moving=True, style="flat")
    p.cyl("Blades", 0.23, 0.18, (0, 0, -1.8), BONE, 8,
          rot=(math.pi / 2, 0, 0), moving=True)
    p.marker("hang")
    p.marker("rotor", (0, 0, -1.8))
    return p.finish(("fan", (0, 0, -1.8)))


def crate():
    p = Prop("prop_crate")
    outline = [(-1, -0.61), (-0.86, -0.75), (0.86, -0.75), (1, -0.61),
               (1, 0.61), (0.86, 0.75), (-0.86, 0.75), (-1, 0.61)]
    p.add("Box", "prism", outline, 0.18, matrix=common.mtx((0, 0, 1.11)), color=BONE)
    p.box("Box", (2, 1.5, 0.16), (0, 0, 0.08), BONE)
    for s in (-1, 1):
        p.box("Box", (0.22, 1.5, 0.88), (s * 0.89, 0, 0.6), PETROL)
    p.box("Box", (1.56, 0.12, 0.88), (0, -0.69, 0.6), PETROL)
    for z in (0.24, 0.49, 0.74, 0.99):
        p.box("Box", (1.56, 0.10, 0.14), (0, 0.70, z), BONE)
    for x in (-0.66, 0.66):
        for z in (0.13, 1.16):
            p.box("Straps", (0.12, 1.52, 0.08), (x, 0, z), DARK, style="flat")
        p.box("Straps", (0.12, 0.13, 1.04), (x, 0.72, 0.64), DARK, style="flat")
        p.box("Straps", (0.12, 0.13, 1.04), (x, -0.72, 0.64), DARK, style="flat")
    p.marker("carry_l", (-1, 0, 0.8))
    p.marker("carry_r", (1, 0, 0.8))
    return p.finish()


def pot():
    p = Prop("prop_pot")
    rings = []
    for radius, z, shift in ((0.49, 0.2, 0), (0.7, 0.43, 0), (0.7, 1.40, -0.04),
                              (0.48, 1.72, 0.03), (0.21, 2.0, 0)):
        rings.append([p.get("round").bm.verts.new((radius * math.cos(k * math.tau / 10) + shift,
                                         radius * math.sin(k * math.tau / 10), z)) for k in range(10)])
    for i in range(4):
        for k in range(10):
            f = p.get("round").bm.faces.new((rings[i][k], rings[i][(k + 1) % 10],
                                     rings[i + 1][(k + 1) % 10], rings[i + 1][k]))
            p.get("round").paint([f], "paint", PETROL if i == 1 else BONE)
    for row, reverse in ((rings[0], True), (rings[-1], False)):
        p.get("round").paint([p.get("round").bm.faces.new(list(reversed(row)) if reverse else row)], "paint", DARK)
    p.marker("Tank")
    for s in (-1, 1):
        p.box("Feet", (0.25, 1.5, 0.2), (s * 0.625, 0, 0.1))
    points = [(0.7, 0, 1.6), (0.96, 0, 1.38), (1.12, 0, 0.76), (1.06, 0, 0.18)]
    for a, b in zip(points, points[1:]):
        p.add("Hose", "rod", a, b, 0.08, segs=6, color=DARK, style="flat")
    p.cyl("Tank", 0.25, 0.08, (0, 0, 2.02), PETROL, 6)
    p.marker("hose_out", (0.7, 0, 1.6))
    return p.finish()


def clamp():
    p = Prop("prop_clamp")
    p.box("Stem", (0.45, 0.45, 0.8), (0, 0, 0.4), PETROL)
    for s in (-1, 1):
        rot = (0, s * math.radians(35), 0)
        phase = (math.pi / 8, math.pi / 8 + math.tau)
        p.ring("Sockets", 0.20, 0.325, 0.8, (s * 0.32057, 0, 0.97234), PETROL, 4,
               rot=rot, arc=phase)
        p.ring("Sockets", 0.20, 0.325, 0.13, (s * 0.51272, 0, 1.24675), BONE, 4,
               rot=rot, arc=phase)
    p.marker("line_l", (-0.55, 0, 1.3))
    p.marker("line_r", (0.55, 0, 1.3))
    return p.finish()


def ballast():
    p = Prop("prop_ballast")
    rows = []
    for z, inset in ((0, 0), (0.37, 0.045), (0.42, 0), (0.76, 0.035), (0.81, 0), (1.2, 0)):
        xmax = 1 - z * 1.05
        rows.append([p.get("hard").bm.verts.new(v) for v in
                     [(-1 + inset, -0.7 + inset, z), (xmax - inset, -0.7 + inset, z),
                      (xmax - inset, 0.7 - inset, z), (-1 + inset, 0.7 - inset, z)]])
    for i in range(len(rows) - 1):
        for k in range(4):
            f = p.get("hard").bm.faces.new((rows[i][k], rows[i][(k + 1) % 4],
                                     rows[i + 1][(k + 1) % 4], rows[i + 1][k]))
            p.get("hard").paint([f], "paint", common.mix(CHALK, DARK, 0.18) if i in (1, 3) else CHALK)
    for row, reverse in ((rows[0], True), (rows[-1], False)):
        p.get("hard").paint([p.get("hard").bm.faces.new(list(reversed(row)) if reverse else row)], "paint", CHALK)
    p.marker("BeddedWedge")
    p.marker("strap_a", (-0.6, 0, 0.6))
    p.marker("strap_b", (0.6, 0, 0.6))
    return p.finish(stone=True)


def lamp_body():
    p = Prop("prop_lamp_body")
    p.ring("Cage", 0.35, 0.45, 0.5, (0, 0, 0.75), PETROL, 12)
    for x in (-0.17, 0.17):
        p.beam("Cage", (x, 0.28, 0.35), (x, 0.28, 1.15), 0.04, BONE, style="flat")
    for z in (0.56, 0.94):
        p.beam("Cage", (-0.40, 0.28, z), (0.40, 0.28, z), 0.04, BONE, style="flat")
    p.box("Bracket", (0.3, 0.13, 0.6), (0, -0.285, 0.3))
    p.box("Bracket", (0.3, 0.7, 0.12), (0, 0, 0.06))
    p.marker("wall_mount", (0, -0.3, 0.3))
    return p.finish()


def lamp_glass():
    p = Prop("prop_lamp_glass")
    p.cyl("Lens", 0.35, 0.12, (0, 0.10, 0.75), BONE, 12, rot=(math.pi / 2, 0, 0))
    p.marker("wall_mount", (0, -0.3, 0.3))
    root = p.finish()
    mesh = bpy.data.objects["Surface"]
    mesh.data.materials.clear()
    for attribute in list(mesh.data.color_attributes):
        mesh.data.color_attributes.remove(attribute)
    mat = common.material("glass")
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Alpha"].default_value = 0.82
    mesh.data.materials.append(mat)
    return root


def sail():
    p = Prop("prop_sail")
    p.box("Mast", (0.15, 0.15, 2), (0, 0, 1))
    m = common.mtx((0, 0, 1.5), (math.pi / 2, 0, 0))
    p.add("Triangle", "prism", [(0, -0.65), (1.8, 0), (0, 0.65)], 0.05,
          matrix=m, color=BONE, moving=True, style="flat")
    for z in (0.85, 2.15):
        p.add("BraceRods", "rod", (0, 0, z), (1.8, 0, 1.5), 0.03,
              segs=6, color=PETROL, moving=True, style="flat")
    p.cyl("Mast", 0.13, 0.2, (0, 0, 1.5), DARK, 8)
    p.marker("hinge", (0, 0, 1.5))
    return p.finish(("sail", (0, 0, 1.5)))


def bench():
    p = Prop("prop_bench")
    p.box("Top", (3, 1.2, 0.25), (0, 0, 1.2), BONE)
    for s in (-1, 1):
        p.box("Feet", (0.4, 0.5, 1.2), (s * 1.1, 0, 0.6), PETROL if s == -1 else BONE)
        p.box("Feet", (0.58, 0.65, 0.12), (s * 1.1, 0, 0.06), DARK)
    p.beam("Brace", (-0.7, 0, 0.32), (0.7, 0, 1.095), 0.15, OXIDE)
    p.marker("tool_rest", (0, 0, 1.325))
    return p.finish()


BUILDERS = [spool, bearing, fan, crate, pot, clamp, ballast, lamp_body, lamp_glass, sail, bench]


def make_rig(root, obj, motion):
    kind, pivot = motion
    data = bpy.data.armatures.new("PropRig")
    arm = bpy.data.objects.new("PropRig", data)
    bpy.context.scene.collection.objects.link(arm)
    arm.parent = root
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    base = data.edit_bones.new("Static")
    base.head, base.tail = (0, 0, 0), (0, 0, 0.2)
    bone = data.edit_bones.new("Motion")
    bone.head = pivot
    bone.tail = Vector(pivot) + Vector((0, 0.2, 0))
    bone.parent = base
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.parent = arm
    obj.modifiers.new("Rigid prop motion", "ARMATURE").object = arm
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 1, 121 if kind == "fan" else 91
    pose = arm.pose.bones["Motion"]
    pose.rotation_mode = "XYZ"
    clips = [("spin_loop", 121)] if kind == "fan" else [("fold", 16), ("wind_loop", 91)]
    arm.animation_data_create()
    for name, end in clips:
        action = bpy.data.actions.new(name)
        arm.animation_data.action = action
        pose.rotation_euler = (0, 0, 0)
        pose.scale = (1, 1, 1)
        frames = [1, 31, 61, 91, 121] if kind == "fan" else ([1, 16] if name == "fold" else [1, 23, 46, 69, 91])
        for i, frame in enumerate(frames):
            if kind == "fan":
                pose.rotation_euler.y = math.tau * i / 4
            elif name == "fold":
                pose.scale.x = 1 if i == 0 else 0.055
            else:
                pose.rotation_euler.z = math.radians([0, 5, 0, -5, 0][i])
            pose.keyframe_insert(data_path="rotation_euler", frame=frame, group="Motion")
            pose.keyframe_insert(data_path="scale", frame=frame, group="Motion")
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR" if kind == "fan" else "BEZIER"
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
    arm.animation_data.action = None
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    scene.frame_set(1)


def export(root, path):
    bpy.context.view_layer.update()
    polish.bake(root, common.POLISH)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
    moving = bpy.data.objects.get("PropRig") is not None
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_apply=False, export_yup=True, export_materials="EXPORT",
                             export_vertex_color="ACTIVE", export_extras=False,
                             export_animations=moving, export_animation_mode="NLA_TRACKS",
                             export_anim_slide_to_zero=True, export_force_sampling=True,
                             export_frame_range=False, export_def_bones=False,
                             export_cameras=False, export_lights=False)
    common.canonical_indices(str(path), vertices=True)
    raw = path.read_bytes()
    gltf = json.loads(raw[20:20 + int.from_bytes(raw[12:16], "little")])
    tri, vert, draws = 0, 0, 0
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            tri += gltf["accessors"][primitive["indices"]]["count"] // 3
            vert += gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
            draws += 1
    assert 0 < tri <= TRI_CAP and 0 < vert <= VERT_CAP and draws == 1, (path.name, tri, vert, draws)
    assert len(gltf["materials"]) == 1 and not gltf.get("images"), path.name
    print("MHP_ASSET", path.name, "triangles", tri, "vertices", vert, "surfaces", draws,
          "bytes", len(raw), "sha256", hashlib.sha256(raw).hexdigest(), flush=True)


def preview(paths, folder, asset=None):
    folder.mkdir(parents=True, exist_ok=True)
    lamp_names = {"prop_lamp_body", "prop_lamp_glass"}
    assemblies = [(p.stem, [p]) for p in paths if p.stem not in lamp_names]
    assemblies.insert(7, ("prop_lamp", [p for p in paths if p.stem in lamp_names]))
    assert len(assemblies) == 10 and sum(len(files) for _, files in assemblies) == 11
    for name, files in assemblies:
        if asset is None:
            subprocess.run([bpy.app.binary_path, "-b", "--factory-startup", "--threads", "2",
                            "--python-exit-code", "1", "-P", str(Path(__file__).resolve()), "--",
                            "--out-dir", str(paths[0].parent.resolve()), "--preview-only",
                            "--preview-dir", str(folder.resolve()), "--preview-asset", name], check=True)
            continue
        if name != asset:
            continue
        common.reset()
        for path in files:
            bpy.ops.import_scene.gltf(filepath=str(path))
        scene = bpy.context.scene
        scene.frame_set(1)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        points = []
        roots = [obj for obj in scene.objects if obj.parent is None and obj.name.startswith("prop_")]
        objects = [obj for root in roots for obj in common.tree(root)]
        for obj in objects:
            # glTF's Blender importer also creates a bone-widget Icosphere outside
            if obj.type == "MESH" and not obj.hide_render:
                evaluated = obj.evaluated_get(deps)
                mesh = evaluated.to_mesh()
                points.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
                evaluated.to_mesh_clear()
        low = Vector(tuple(min(p[k] for p in points) for k in range(3)))
        high = Vector(tuple(max(p[k] for p in points) for k in range(3)))
        scene.render.engine = "CYCLES"
        cycles_device.use(scene)
        scene.cycles.samples = 12
        scene.cycles.use_denoising = True
        scene.render.threads_mode = "FIXED"
        scene.render.threads = 2
        scene.render.resolution_x, scene.render.resolution_y = 640, 480
        scene.render.resolution_percentage = 100
        scene.view_settings.view_transform = "Standard"
        scene.world = bpy.data.worlds.new("Morning fill")
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes["Background"]
        bg.inputs["Color"].default_value = common.rgba("a9b6c0")
        bg.inputs["Strength"].default_value = 0.7
        floor_z = low.z
        bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, floor_z - 0.01))
        floor = bpy.context.object
        floor.data.materials.append(common._flat("Preview floor", "798c9e"))
        light = bpy.data.lights.new("Left morning sun", "AREA")
        light.energy, light.shape, light.size = 1100, "DISK", 6
        sun = bpy.data.objects.new("Left morning sun", light)
        scene.collection.objects.link(sun)
        sun.location = (-4, -4, high.z + 6)
        sun.rotation_euler = (Vector((0, 0, (low.z + high.z) / 2)) - sun.location).to_track_quat("-Z", "Y").to_euler()
        cam = bpy.data.objects.new("Preview camera", bpy.data.cameras.new("Preview camera"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        cam.data.type = "ORTHO"
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
        ball = bpy.context.object
        ball.name = "Reference ball diameter 2 m"
        ball.data.materials.append(common._flat("Reference ball", BONE))
        center = (low + high) / 2
        for label, direction in (("front", Vector((0, 1, 0.15))),
                                 ("side", Vector((1, 0, 0.15))),
                                 ("three-quarter", Vector((1, 1.3, 0.65)))):
            direction.normalize()
            right = Vector((-direction.y, direction.x, 0)).normalized()
            extent = max(abs((point - center).dot(right)) for point in points)
            ball.location = Vector((center.x, center.y, floor_z + 1)) + right * (extent + 1.5)
            target = (center + ball.location) / 2
            cam.location = target + direction * 14
            cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            combined = points + [ball.location + Vector((x, y, z)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            inv = cam.rotation_euler.to_matrix().transposed()
            image_points = [inv @ (point - target) for point in combined]
            width = max(p.x for p in image_points) - min(p.x for p in image_points)
            height = max(p.y for p in image_points) - min(p.y for p in image_points)
            cam.data.ortho_scale = max(width, height * 640 / 480) * 1.2
            scene.render.filepath = str(folder / (name + "_" + label + ".png"))
            bpy.ops.render.render(write_still=True)
            print("MHP_PREVIEW", name, label, "Cycles", bpy.context.scene.cycles.device, "12 samples", flush=True)


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--out-dir", type=Path, default=Path(common.MODELS) / "highdraft")
    args.add_argument("--preview-dir", type=Path)
    args.add_argument("--preview-only", action="store_true")
    args.add_argument("--preview-asset", choices=["prop_" + name for name in
                      ("spool", "bearing", "fan", "crate", "pot", "clamp", "ballast", "lamp", "sail", "bench")])
    opts = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    opts.out_dir.mkdir(parents=True, exist_ok=True)
    polish.enable(detail=2, bevel=0.03, bevel_min=0.1)
    paths = [opts.out_dir / ("prop_" + name + ".glb") for name in
             ("spool", "bearing", "fan", "crate", "pot", "clamp", "ballast", "lamp_body", "lamp_glass", "sail", "bench")]
    if not opts.preview_only:
        for builder, path in zip(BUILDERS, paths):
            export(builder(), path)
    if opts.preview_dir:
        preview(paths, opts.preview_dir, opts.preview_asset)


if __name__ == "__main__":
    main()
