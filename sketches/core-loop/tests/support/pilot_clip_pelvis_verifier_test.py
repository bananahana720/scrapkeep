"""Blender verifier: accept a posed pelvis and reject an excessive loop rotation."""
import copy
from pathlib import Path
import sys
import tempfile

import bpy

HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE / 'tools/blender'))
import pilot_clips
import verify_pilot_clips as verifier

source = HERE / 'assets/models/pilot_sable_anim.glb'
failures = 0
for degrees in (4.0, 8.0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(source))
    arm = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    old = verifier._action(bpy, 'idle_loop')
    for track in list(arm.animation_data.nla_tracks):
        if any(strip.action == old for strip in track.strips):
            arm.animation_data.nla_tracks.remove(track)
        else:
            track.mute = True
    arm.animation_data.action = None
    bpy.data.actions.remove(old)
    table = copy.deepcopy(verifier.pose_table('sable'))
    clip = table['clips']['idle_loop']
    # Counter-rotate the spine in two shares; solve both planted hands after posing.
    clip['keys'] = [{'frame': 1, 'pose': 'rest'},
                    {'frame': 40, 'pelvis': {'yaw': degrees}, 'torso': {'yaw': -degrees}},
                    {'frame': 90, 'pelvis': {'yaw': degrees}, 'torso': {'yaw': -degrees}},
                    {'frame': clip['end'], 'pose': 'rest'}]
    clip['planted'] = ['R', 'L']
    action, _ = pilot_clips.bake(arm, 'idle_loop', clip, table)
    track = arm.animation_data.nla_tracks.new()
    track.name = 'idle_loop'
    track.strips.new('idle_loop', 1, action)
    arm.animation_data.action = None
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder) / 'pelvis.glb'
        pilot_clips.export(arm, out, 'sable')
        passed, line, info = verifier.verify('sable', out, None, has_table=True, table=table)
        want = degrees <= 6
        ok = passed if want else not passed and 'check 10:' in info.get('failure', '')
        print('PELVIS_VERIFIER %.1f degrees: %s; %s' % (degrees, 'PASS' if ok else 'FAIL', line))
        if not ok: failures += 1
print('PILOT_CLIP_PELVIS_VERIFIER: %s (2 cases)' % ('FAIL' if failures else 'PASS'))
raise SystemExit(1 if failures else 0)
