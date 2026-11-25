"""Rig kit for the four kill-first specials: one skeleton per body and baked clips timed to
their sounds (design-v3/sound/specials.py on PR #12), so the wind-up you see and the wind-up
you hear start on the same frame.

Each body recipe builds its meshes as before, then hands them to a Rig: bones are placed in
Godot metres, every mesh island (one welded primitive) is weighted whole to one bone, so the
silhouette never tears or bends where it was not built to, and the clips are keyed per bone
in Godot axes. Skinning adds joints and weights, never vertices, triangles or draws.

Bone axes. Every bone points up (Blender +Z) with no roll, so its local X, Y, Z are Godot
X, Y, Z: a pose's `rot` is (pitch about X, yaw about Y, roll about Z) in degrees, `loc` is a
Godot offset in metres and `scale` is a factor, all about the bone head.

Runtime contract (for the wave 17 to 19 behaviour units, src/ is theirs):
  - Sample a clip by the counter's clock, never a free-running timer: seek(age, true) on the
    imported AnimationPlayer, with age 0 on the frame the matching `<name>_tell` or
    `<name>_break` sound fires. Loop clips (idle, crawl, scurry, braced) loop on the beat
    grid; seek them by the presence loop's position so the ticks land on its clicks.
  - The importer drops tracks that never change, so call Skeleton3D.reset_bone_poses()
    before seeking a different clip; a bone a clip does not move then rests.
  - Sockets stay where the body recipe put them (rest pose). Clips return every socket's
    bone to rest by the frame its socket is used (the Dispatcher's drop, the Splitter's
    split), so a spawn read off a socket lands where the eye expects.
Procedural in this repository; no external rigs, clips or motion data.
"""
import json
import math
import os
import struct
import tempfile

import bmesh
import bpy
from mathutils import Euler, Vector

import common

FPS = 30
BEAT = 60 / 129
BAR2 = 8 * BEAT


def g(x, y, z):
    return Vector((x, -z, y))


def godot(v):
    return Vector((v.x, v.z, -v.y))


def frame(seconds):
    return 1 + round(seconds * FPS)


class Rig:
    def __init__(self, root, name, bones):
        """bones: [(name, godot head, parent name or None)], parents listed first."""
        self.root = root
        data = bpy.data.armatures.new(name)
        self.arm = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(self.arm)
        self.arm.parent = root
        self.arm["world_origin"] = [0.0, 0.0, 0.0]
        bpy.context.view_layer.objects.active = self.arm
        for o in bpy.context.scene.objects:
            o.select_set(False)
        self.arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        self.heads = {}
        for bone_name, head, parent in bones:
            bone = data.edit_bones.new(bone_name)
            bone.head = g(*head)
            bone.tail = g(*head) + Vector((0, 0, 0.25))
            bone.roll = 0.0
            if parent:
                bone.parent = data.edit_bones[parent]
                bone.use_connect = False
            self.heads[bone_name] = Vector(head)
        bpy.ops.object.mode_set(mode="OBJECT")
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "XYZ"
        self.names = [b[0] for b in bones]
        self.meshes = []
        self.clips = {}

    def _attach(self, obj):
        mw = obj.matrix_world.copy()
        obj.parent = self.arm
        obj.matrix_world = mw
        mod = obj.modifiers.new("Rig", "ARMATURE")
        mod.object = self.arm
        for bone_name in self.names:
            if obj.vertex_groups.get(bone_name) is None:
                obj.vertex_groups.new(name=bone_name)
        self.meshes.append(obj)

    def bind(self, obj, classify):
        """Weights each island of obj whole to classify(centre, low, high) -> bone name, all
        three in Godot metres (centre is the island's mean vertex)."""
        self._attach(obj)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        mw = obj.matrix_world
        groups = {}
        for start in bm.verts:
            if start.index in seen:
                continue
            island, stack = [], [start]
            seen.add(start.index)
            while stack:
                v = stack.pop()
                island.append(v.index)
                for e in v.link_edges:
                    o = e.other_vert(v)
                    if o.index not in seen:
                        seen.add(o.index)
                        stack.append(o)
            pts = [godot(mw @ bm.verts[i].co) for i in island]
            centre = sum(pts, Vector()) / len(pts)
            low = Vector([min(p[k] for p in pts) for k in range(3)])
            high = Vector([max(p[k] for p in pts) for k in range(3)])
            bone_name = classify(centre, low, high)
            assert bone_name in self.names, (obj.name, bone_name)
            groups.setdefault(bone_name, []).extend(island)
        bm.free()
        for bone_name, idx in groups.items():
            obj.vertex_groups[bone_name].add(sorted(idx), 1.0, "REPLACE")
        return groups

    def bind_smooth(self, obj, weights):
        """Per-vertex blend: weights(godot point) -> {bone: w}. For the Linker's cable."""
        self._attach(obj)
        mw = obj.matrix_world
        for v in obj.data.vertices:
            for bone_name, w in weights(godot(mw @ v.co)).items():
                if w > 1e-4:
                    obj.vertex_groups[bone_name].add([v.index], w, "REPLACE")

    def socket_to_bone(self, name, bone_name):
        """Re-parents a socket empty onto a bone, keeping where it is, so it follows clips."""
        obj = bpy.data.objects[name]
        bpy.context.view_layer.update()
        mw = obj.matrix_world.copy()
        obj.parent = self.arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        bpy.context.view_layer.update()
        obj.matrix_world = mw

    def rest(self):
        for pb in self.arm.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
            pb.scale = (1, 1, 1)

    def pose(self, bone_name, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
        pb = self.arm.pose.bones[bone_name]
        pb.location = Vector(loc)
        pb.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
        pb.scale = Vector(scale) if isinstance(scale, (tuple, list)) else Vector((scale,) * 3)

    def clip(self, name, seconds, tracks, interp="BEZIER"):
        """tracks: bone -> [(t, pose kwargs)] with t in seconds. Keys snap to 30 fps; a key
        list must start at 0. Bones with no track are not keyed in this clip."""
        arm = self.arm
        arm.animation_data_create()
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for bone_name, keys in tracks.items():
            assert keys[0][0] == 0, (name, bone_name)
            for t, values in keys:
                assert 0 <= t <= seconds + 1e-6, (name, bone_name, t)
                self.rest()
                self.pose(bone_name, **values)
                pb = arm.pose.bones[bone_name]
                for prop in ("location", "rotation_euler", "scale"):
                    pb.keyframe_insert(prop, frame=frame(t), group=bone_name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = interp
                            key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
                        curve.update()
        arm.animation_data.action = None
        self.rest()
        self.clips[name] = seconds

    def evaluate(self, name, seconds):
        """Poses the rig at a clip time, for previews."""
        self.rest()
        self.arm.animation_data.action = bpy.data.actions[name]
        bpy.context.scene.frame_set(frame(seconds))

    def stop(self):
        if self.arm.animation_data:
            self.arm.animation_data.action = None
        self.rest()
        bpy.context.scene.frame_set(1)

    def export(self, path, draws):
        """Writes the GLB with skin and clips, canonicalised so reruns are byte-identical.
        Returns the stats the recipe asserts on."""
        self.stop()
        if common.POLISH is not None:
            import polish
            polish.bake(self.root, common.POLISH)
        scene = bpy.context.scene
        scene.render.fps = FPS
        scene.frame_start, scene.frame_end = 1, frame(max(self.clips.values()))
        bpy.context.view_layer.update()
        for o in scene.objects:
            o.select_set(False)
        for o in common.tree(self.root):
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.arm
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="scrapkeep-kfr-") as scratch:
            packed = os.path.join(scratch, os.path.basename(path))
            bpy.ops.export_scene.gltf(filepath=packed, export_format="GLB", use_selection=True,
                export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
                export_frame_range=False, export_force_sampling=True, export_def_bones=False,
                export_skins=True, export_yup=True, export_materials="EXPORT",
                export_vertex_color="ACTIVE", export_extras=False, export_cameras=False,
                export_lights=False)
            common.canonical_indices(packed, vertices=common.POLISH is not None)
            data = open(packed, "rb").read()
        with open(path, "wb") as fh:
            fh.write(data)
        size = struct.unpack_from("<I", data, 12)[0]
        doc = json.loads(data[20:20 + size])
        prims = [p for m in doc["meshes"] for p in m["primitives"]]
        stats = {
            "verts": sum(doc["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims),
            "tris": sum(doc["accessors"][p["indices"]]["count"] // 3 for p in prims),
            "draws": len(prims),
            "joints": len(doc["skins"][0]["joints"]) if doc.get("skins") else 0,
            "clips": sorted(a["name"] for a in doc.get("animations", [])),
        }
        assert stats["draws"] == draws and stats["verts"] <= 19100 and stats["tris"] <= 10000, stats
        assert stats["clips"] == sorted(self.clips), (stats["clips"], sorted(self.clips))
        assert all("JOINTS_0" in p["attributes"] for p in prims), "every mesh is skinned"
        print("RIG EXPORTED", os.path.basename(path), json.dumps(stats, sort_keys=True))
        return stats


def keys(*rows):
    """keys((0, {}), (0.2, {...}), ...) -> list; a readable alias."""
    return list(rows)


def hold(rows, t_end):
    """Repeats the last pose at t_end, so a clip holds it to the end."""
    return rows + [(t_end, dict(rows[-1][1]))]


def shake(t0, t1, amp, period=2 / FPS, field="rot", axis=2, base=None, decay=1.0):
    """Alternating keys from t0 to t1: a buzz or a vibrating hold. axis picks the component."""
    base = dict(base or {})
    out, k, t = [], 0, t0
    while t <= t1 + 1e-6:
        v = list(base.get(field, (0, 0, 0)))
        a = amp * (decay ** k) * (1 if k % 2 == 0 else -1)
        v[axis] += a
        pose = dict(base)
        pose[field] = tuple(v)
        out.append((round(t, 4), pose))
        t += period
        k += 1
    return out


def merge(*lists):
    """Concatenates key lists, dropping keys that land on an already keyed 30 fps frame."""
    out, used = [], set()
    for rows in lists:
        for t, pose in rows:
            f = frame(t)
            if f not in used:
                used.add(f)
                out.append((t, pose))
    out.sort(key=lambda r: r[0])
    return out


def contact_sheet(name, rig, floor, outdir, focus, scale, shots, yaw=-35.0, size=420, pitch_up=3.0,
                  lit_clips=()):
    """Renders `shots` = [(clip, seconds, label)] from one three-quarter orthographic camera
    and writes <outdir>/<name>_<clip>_<nn>.png per pose. CPU Cycles, 16 samples."""
    import kill_first_preview as kp
    scene, cam = kp._scene(floor)
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.cycles.samples = 12
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    focus = Vector(focus)
    a = math.radians(yaw)
    cam.location = focus + Vector((math.sin(a) * 12, math.cos(a) * 12, pitch_up))
    common._look(cam, focus)
    os.makedirs(outdir, exist_ok=True)
    written = []
    for i, (clip, seconds, label) in enumerate(shots):
        if clip is None:
            rig.stop()
        else:
            rig.evaluate(clip, seconds)
        kp.flare(clip in lit_clips and seconds > 0)
        path = os.path.join(outdir, "%s_%02d_%s.png" % (name, i, label))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        written.append((path, clip or "rest", seconds, label))
    kp.flare(False)
    rig.stop()
    with open(os.path.join(outdir, name + "_shots.json"), "w") as fh:
        json.dump([{"file": os.path.basename(p), "clip": c, "t": round(s, 3), "label": l}
                   for p, c, s, l in written], fh, indent=1)
    print("CONTACT SHEET", name, len(written))


def sheet_dir():
    """`--sheet dir` after `--`: where contact_sheet writes, or None."""
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return argv[argv.index("--sheet") + 1] if "--sheet" in argv and argv.index("--sheet") + 1 < len(argv) else None
