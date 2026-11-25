"""Explicit Tarn motion beats, baked IK, seven neutral-to-neutral clips at 30 fps.

The motion sheet supplies gestures, not rig dimensions. Static pupils and brows,
three fused claw lobes and seated pelvis-weighted legs take precedence over it.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

import common
import rig_pilot as rig
from anim_rivet_drop import solve_arm, world_hand
from pilot_tarn import OUT, HERE

GRIPS = {"R": (.32, .4, .05), "L": (-.32, .4, .05)}
DIRECTION_SHA256 = {
    "pilot-tarn.png": "711967c9672ad84caa021626bfeb6947261ec28999ac8c60ba715c116769ae49",
    "shell-tarn.png": "65a8edc12039b046b85cb4775c3d47674882c185da513c8f25e9b66a4e50886b",
    "motion-tarn.png": "48e28ccac7426112222cb9e3cc325c81f46b4ed4bc2b66a8901e108b0d93c973",
    "pilots-lineup.png": "ba8c5d3fe7601adfc29741f58422359dc49b1085cf3439d164ed59f7c6de8b87",
}
FRAMES = {"drop_land": [1, 5, 9, 12, 16, 23, 32, 43, 54, 66],
          "big_cheer": [1, 7, 16, 25, 46, 58, 73, 85],
          "wince": [1, 3, 5, 8, 12, 16], "slump": [1, 7, 15, 23, 31, 39, 46],
          "phew": [1, 5, 10, 14, 19, 25], "brace": [1, 3, 6, 10, 14, 19],
          "heave": [1, 3, 7, 10, 15, 25]}

REST = (1, 0, 0, 0, 0, GRIPS["R"], GRIPS["L"], 0, 0, 0)
POSES = {
    "drop_land": [REST,
        (.98, -4, -5, 0, .01, GRIPS["R"], GRIPS["L"], 6, -4, 0),
        (.92, -7, -7, 0, .018, GRIPS["R"], GRIPS["L"], 12, -7, 0),
        (.85, -8, -8, 0, .025, GRIPS["R"], GRIPS["L"], 20, -10, 0),
        (.92, -2, -2, 0, .012, GRIPS["R"], GRIPS["L"], 10, -5, 0),
        (1.035, 3, 3, 0, .01, GRIPS["R"], GRIPS["L"], -4, 6, 0),
        (1.015, 2, 5, -8, .018, (.43, .24, .20), GRIPS["L"], 0, 8, -4),
        (1, 0, 0, 0, 0, (.35, .37, .09), GRIPS["L"], 0, 2, 0),
        (.995, -1, -1, 0, 0, GRIPS["R"], GRIPS["L"], 0, 0, 0), REST],
    "big_cheer": [REST,
        (.95, -5, -6, 0, 0, (.36, .32, .05), (-.36, .32, .05), 8, -6, 0),
        (1.02, 3, 4, 0, .025, (.44, .16, .23), (-.44, .16, .23), -5, 8, -7),
        (1.04, 4, 5, 0, .04, (.47, .10, .33), (-.47, .10, .33), -8, 12, -16),
        (1.04, 4, 5, 15, .04, (.47, .10, .33), (-.47, .10, .33), -8, 12, -16),
        (1.03, 3, 6, 8, .035, (.48, .12, .30), (-.45, .14, .29), -6, -9, -10),
        (1.01, 1, 1, 0, .012, (.39, .29, .13), (-.39, .29, .13), 0, 3, 0), REST],
    "wince": [REST,
        (.91, -5, -7, 24, .045, (.40, .28, .13), (-.40, .28, .13), 24, -10, -5),
        (.92, -4, -5, 28, .04, (.40, .29, .12), (-.40, .29, .12), 27, -12, -5),
        (.96, -2, -2, 14, .02, (.36, .35, .08), (-.36, .35, .08), 12, -5, 0),
        (.99, 0, 0, 4, .006, GRIPS["R"], GRIPS["L"], 3, 0, 0), REST],
    "slump": [REST,
        (.96, -5, -6, 0, -.005, (.36, .37, -.04), (-.36, .37, -.04), 12, 3, 0),
        (.92, -10, -12, 6, -.015, (.40, .33, -.17), (-.40, .33, -.17), 25, 5, 0),
        (.90, -11, -17, 8, -.02, (.41, .28, -.26), (-.41, .28, -.26), 35, 6, 0),
        (.90, -11, -17, 8, -.02, (.41, .28, -.26), (-.41, .28, -.26), 35, 6, 0),
        (.97, -3, -5, 3, -.005, (.35, .36, -.04), (-.35, .36, -.04), 10, 2, 0), REST],
    "phew": [REST,
        (1.025, 1, 2, -15, .015, GRIPS["R"], (-.37, .30, .12), 3, -2, 0),
        (1.015, 0, 2, -32, .01, GRIPS["R"], (-.44, .18, .22), -4, -5, -7),
        (1, -1, 0, -32, 0, GRIPS["R"], (-.44, .18, .22), -4, -5, -7),
        (.975, -2, -3, -10, -.005, GRIPS["R"], (-.36, .32, .05), 3, -2, 0), REST],
    "brace": [REST,
        (.88, -16, -9, 0, .01, GRIPS["R"], GRIPS["L"], 35, -8, 0),
        (.86, -18, -10, 0, .012, GRIPS["R"], GRIPS["L"], 40, -10, 0),
        (.88, -16, -9, 0, .01, GRIPS["R"], GRIPS["L"], 35, -8, 0),
        (.95, -7, -4, 0, .004, GRIPS["R"], GRIPS["L"], 15, -3, 0), REST],
    "heave": [REST,
        (1.015, 10, 7, 0, .014, GRIPS["R"], GRIPS["L"], -4, -12, 0),
        (.94, -10, -6, -8, .025, (.46, .22, .29), GRIPS["L"], 18, 12, -5),
        (.95, -8, -4, -6, .02, (.43, .25, .26), GRIPS["L"], 15, 8, -4),
        (.98, -3, -1, -2, .007, (.36, .35, .13), GRIPS["L"], 5, 3, 0), REST],
}
OBSERVATIONS = {
    "drop_land": "Broad torso compresses to 0.85, rebounds, right paw accent, exact driving rest.",
    "big_cheer": "Both three-lobed paws rise wide; jaw opens a small cavity; head stays compact.",
    "wince": "Fast lifted shoulders, sideways head twist and whole-ear hinge; fixed facial features.",
    "slump": "Low shoulders and heavy hanging paws; thick tail relaxes; brief recovery.",
    "phew": "Turn chin toward anatomical left, release left paw only, exhale at fixed right control.",
    "brace": "Torso bites forward with both wrist anchors planted; ears hinge back; release.",
    "heave": "Seat recoil, single right shoulder/paw punch, left grip counterbrace, settle.",
}


def lerp_pose(clip, frame):
    keys, poses = FRAMES[clip], POSES[clip]
    if frame <= 1 or frame >= keys[-1]:
        return REST
    for i in range(len(keys) - 1):
        if keys[i] <= frame <= keys[i + 1]:
            f = (frame - keys[i]) / (keys[i + 1] - keys[i])
            if clip not in ("wince", "brace"):
                f = f * f * (3 - 2 * f)
            return tuple(tuple(a[j] + (b[j] - a[j]) * f for j in range(3)) if isinstance(a, tuple)
                         else a + (b - a) * f for a, b in zip(poses[i], poses[i + 1]))
    raise AssertionError(frame)


def rotate(arm, name, x=0, y=0, z=0):
    arm.pose.bones[name].rotation_euler = tuple(math.radians(a) for a in (x, y, z))


def pose(arm, values):
    rig.clear_pose(arm)
    if values == REST:
        return
    height, pitch, nod, yaw, lift, right, left, ear, tail, jaw = values
    rotate(arm, "spine_01", pitch * .55)
    rotate(arm, "spine_02", pitch * .45)
    arm.pose.bones["spine_01"].scale = (1 + (1 - height) * .12, 1, math.sqrt(height))
    arm.pose.bones["spine_02"].scale.z = math.sqrt(height)
    arm.pose.bones["head"].scale = (1 / (1 + (1 - height) * .12), 1, 1 / height)
    rotate(arm, "head", nod, 0, yaw)
    rotate(arm, "jaw", jaw)
    rotate(arm, "tail.01", 0, 0, tail)
    rotate(arm, "tail.02", 0, 0, -tail * .55)
    for side in ("R", "L"):
        arm.pose.bones["shoulder." + side].location.z = lift
        rotate(arm, "ear." + side, ear)
    bpy.context.view_layer.update()
    for side, target in (("R", right), ("L", left)):
        solve_arm(arm, side, target)
        for _ in range(16):
            for name in ("lower_arm." + side, "upper_arm." + side):
                rig.point_segment(arm, name, "hand." + side, target)
            if (arm.pose.bones["hand." + side].head - Vector(target)).length < .00002:
                break
        world_hand(arm, side, (0, 0, 0))


def animate_and_export(arm, mesh, destination):
    scene = bpy.context.scene
    scene.render.fps = 30
    actions = []
    for clip, frames in FRAMES.items():
        arm.animation_data_clear()
        for frame in range(1, frames[-1] + 1):
            scene.frame_set(frame)
            pose(arm, lerp_pose(clip, frame))
            for bone in arm.pose.bones:
                for prop in ("rotation_euler", "location", "scale"):
                    bone.keyframe_insert(data_path=prop, frame=frame, group=bone.name)
        action = arm.animation_data.action
        action.name, action.use_fake_user = clip, True
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
        actions.append(action)
    checks = []
    for action in actions:
        arm.animation_data.action = action
        end = FRAMES[action.name][-1]
        radius, drift, grip = 0., 0., 0.
        for half in range(2, end * 2 + 1):
            frame = half / 2
            scene.frame_set(int(frame), subframe=frame % 1)
            bpy.context.view_layer.update()
            drift = max(drift, (arm.pose.bones["pelvis"].head - Vector((0, 0, -.30))).length)
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            data = evaluated.to_mesh()
            radius = max(radius, max(v.co.length for v in data.vertices))
            evaluated.to_mesh_clear()
            sides = ("R", "L") if action.name == "brace" else ("L",) if action.name == "heave" else ("R",) if action.name == "phew" else ()
            for side in sides:
                grip = max(grip, (arm.pose.bones["hand." + side].head - Vector(GRIPS[side])).length)
        assert radius < .98, (action.name, "glass", radius)
        assert drift < 1e-6, (action.name, "pelvis", drift)
        assert grip < .004, (action.name, "fixed grip", grip)
        for frame in (1, end):
            scene.frame_set(frame)
            error = max(abs(value - expected) for bone in arm.pose.bones
                        for vector, neutral in ((bone.location, (0, 0, 0)), (bone.rotation_euler, (0, 0, 0)), (bone.scale, (1, 1, 1)))
                        for value, expected in zip(vector, neutral))
            assert error < 1e-6, (action.name, "neutral", error)
        checks.append({"clip": action.name, "seconds": (end - 1) / 30,
                       "half_frame_samples": end * 2 - 1, "max_radius": radius,
                       "pelvis_drift": drift, "fixed_grip_error": grip, "neutral_error": error})
    scene.frame_start, scene.frame_end = 1, 85
    arm.animation_data.action = actions[0]
    scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (arm, mesh):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=str(destination), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
        export_frame_range=False, export_force_sampling=True, export_def_bones=False,
        export_skins=True, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_cameras=False, export_lights=False)
    common.canonical_indices(str(destination))
    report = {"schema": "pilot-v1", "rigid_weighted": all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < 1e-6 for v in mesh.data.vertices),
              "bone_parents": {b.name: b.parent.name if b.parent else None for b in arm.data.bones},
              "rest_anchors": {b.name: list(b.head_local) for b in arm.data.bones},
              "checks": checks, "observations": OBSERVATIONS, "poses": POSES, "frames": FRAMES,
              "direction_sha256": DIRECTION_SHA256,
              "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE / "pilot_tarn.py", HERE / "anim_tarn.py", HERE / "rig_pilot.py", HERE / "anim_rivet_drop.py", HERE / "common.py")}}
    (OUT / "animation-checks.json").write_text(json.dumps(report, indent=2) + "\n")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "pilot_tarn.blend"))
    print("TARN_ANIMATION: PASS 25 bones, seven clips, rigid weights, neutral endpoints, fixed grips and glass clearance")
