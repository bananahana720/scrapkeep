"""Run in Blender: pelvis XYZ rotations, reset, inherited motion and hand solving."""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE / 'tools/blender'))
import pilot_clips
import pilot_arm

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'assets/models/pilot_sable_anim.glb'))
arm = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
for track in arm.animation_data.nla_tracks:
    track.mute = True
arm.animation_data.action = None
failures = []
checks = 0


def check(label, ok):
    global checks
    checks += 1
    print('PELVIS %s: %s' % (label, 'PASS' if ok else 'FAIL'))
    if not ok: failures.append(label)


for field in ('pitch', 'roll', 'yaw'):
    pose = {'pelvis': {field: 20}}
    pilot_clips.apply(arm, pose, True, 'sable')
    angles = [20 if axis == field else 0 for axis in ('pitch', 'roll', 'yaw')]
    want = Euler(tuple(math.radians(v) for v in angles)).to_quaternion()
    check(field, arm.pose.bones['pelvis'].rotation_quaternion.rotation_difference(want).angle < .0001)
    check(field + ' fixed pelvis head', (arm.pose.bones['pelvis'].head - Vector((0, 0, -.3))).length < 1e-6)
    check(field + ' spine inherits', arm.pose.bones['spine_02'].matrix.to_quaternion().rotation_difference(want).angle < .0001)
pilot_clips.apply(arm, {'pelvis': {'roll': 12}, 'hand.R': {'control': 'Grip.R'},
                        'wrist.R': [0, 0, 0]}, True, 'sable')
check('hand solved after pelvis', (arm.pose.bones['hand.R'].head - pilot_arm.control('sable', 'Grip.R')).length < .003)
pilot_clips.apply(arm, {}, True, 'sable')
check('omitted pelvis resets to rest', tuple(arm.pose.bones['pelvis'].rotation_quaternion) == (1, 0, 0, 0))
check('interpolation', pilot_clips.lerp_pose({}, {'pelvis': {'roll': 20}}, .5)['pelvis']['roll'] == 10)
print('PILOT_CLIP_PELVIS: %s (%d checks)' % ('FAIL' if failures else 'PASS', checks))
raise SystemExit(1 if failures else 0)
