"""Image-led reactions on pilot-v1. Run under the required memory-capped user scope.

Reads the accepted drop references from --reference-root, never writes there.
The pose tables and source image hashes are retained beside the editable .blend.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rig_pilot as rig
import anim_rivet_drop as shared
import anim_pilot_drop as drop
import pilot_drop_timing as timing

OUT = rig.ROOT / 'artifacts/anim-reactions'
KEYS = {
    'big_cheer': [1, 7, 16, 25, 46, 58, 73, 85],
    'wince': [1, 3, 5, 8, 12, 16],
    'slump': [1, 7, 15, 23, 31, 39, 46],
    'phew': [1, 5, 10, 14, 19, 25],
    'brace': [1, 3, 6, 10, 14, 19],
    'heave': [1, 3, 7, 10, 15, 25],
}
NOTES = {
    'big_cheer': [
        'Neutral: use exact rig rest; generated hands at knees rejected.',
        'Anticipation: shoulders compress, head dips; feet remain fixed.',
        'Rise: both arms out, fists or feathers clear head silhouette.',
        'Triumph: wide raised arms, fox wrench high, bird broad wing fans.',
        'Hold: head rotates to profile while arms remain raised.',
        'Accent: mole hammer fist, fox small precise wrist lift, bird asymmetric flourish.',
        'Descent: soften shoulders and lower hands, no generated costume change.',
        'Neutral: exact rig rest, no generated facial or leg changes.',
    ],
    'wince': [
        'Neutral: exact rig rest.',
        'Impact: head twists sideways, raised elbows, shoulders jump.',
        'Compression: head dips, arms remain outside torso; reject reversed front/back head.',
        'Release: shoulders lower and head returns from profile.',
        'Recovery: easing toward controls.',
        'Neutral: exact rig rest. Sable side row depicts a mole; reject that view throughout.',
    ],
    'slump': [
        'Neutral: exact rig rest.',
        'Deflate: shoulders lower, wrists leave controls.',
        'Droop: head rolls to one side, elbows fall wide.',
        'Dejected: hands hang like weights, ears or crest droop.',
        'Hold: retain broad low silhouette; no grim facial redesign.',
        'Recovery: shoulders and wrists rise gently.',
        'Neutral: exact seated driving pose.',
    ],
    'phew': [
        'Neutral: exact rig rest; reject duplicated fox wrench.',
        'Inhale: shoulders lift and head turns.',
        'Relief: side gesture, free LEFT hand for fox; retain one wrench in right.',
        'Hold: visible profile, mole releases fist, bird fans one wing.',
        'Exhale: shoulders and hands sink, visibly lower head.',
        'Neutral: exact rig rest. Reject mole side row for fox and mirrored arm variants.',
    ],
    'brace': [
        'Neutral: exact rig rest.',
        'Bite: snap the whole torso forward, head down, both hands at the controls.',
        'Brace: hold the compressed torso against the pull; ears or crest laid back.',
        'Hold: both arms locked; Rivet clamps both claws.',
        'Release: torso and head ease back toward seated rest.',
        'Neutral: exact rig rest.',
    ],
    'heave': [
        'Neutral: exact rig rest.',
        'Impact: throw torso and head back into the seat, both elbows recoil.',
        'Heave: one sharp forward torso punch, right arm raised, left arm counterbraces.',
        'Hold: Rivet clamps, Sable tail whips, Kest fans flare.',
        'Release: lower both arms and ease the torso toward the controls.',
        'Neutral: exact rig rest.',
    ],
}


def rotate(arm, name, xyz):
    arm.pose.bones[name].rotation_euler = tuple(math.radians(v) for v in xyz)


def pose(arm, pilot, clip, k):
    rig.clear_pose(arm)
    last = len(KEYS[clip]) - 1
    if k in (0, last):
        return
    right, left = (.32, .4, .05), (-.32, .4, .05)
    pitch = yaw = roll = shoulder = 0
    height = 1.0
    stretch = 1.0
    if clip == 'big_cheer':
        height = [1, .94, 1.06, 1.14, 1.14, 1.16, 1.03, 1][k]
        pitch = [0, -10, 6, 12, 12, 16, 3, 0][k]
        yaw = [0, 0, 10, 22, 45, 40, 12, 0][k]
        widths = [0, .38, .53, .56, .56, .59, .45, 0]
        lifts = [0, .08, .31, .51, .51, .56, .23, 0]
        right = (widths[k], .07, lifts[k])
        left = (-widths[k], .07, lifts[k])
        shoulder = .045
        stretch = 1.35 if k in (3, 4, 5) else 1.1
        if pilot == 'rivet' and k == 5:
            left = (-.45, .16, .25)
        if pilot == 'sable':
            left = (-.46, .12, lifts[k] * .6)
            yaw *= .8
        if pilot == 'kest':
            right = (widths[k] + .03, .0, lifts[k])
            left = (-widths[k] - .03, .0, lifts[k] - (.12 if k == 5 else 0))
    elif clip == 'wince':
        strength = [0, 1, .9, .5, .15, 0][k]
        height = 1 - .20 * strength
        pitch, yaw, roll = -16 * strength, 32 * strength, 13 * strength
        shoulder = .07 * strength
        right = (.32 + .22 * strength, .2, .05 + .2 * strength)
        left = (-.32 - .22 * strength, .2, .05 + .2 * strength)
        if pilot == 'kest':
            right = (.62 * strength + .32 * (1-strength), .06, .13)
            left = (-right[0], .06, .13)
        if pilot == 'sable':
            rotate(arm, 'ear.R', (22 * strength, 25 * strength, 0))
            rotate(arm, 'ear.L', (22 * strength, -25 * strength, 0))
    elif clip == 'slump':
        strength = [0, .3, .8, 1, 1, .4, 0][k]
        height = 1 - .27 * strength
        pitch, yaw, roll = -26 * strength, 22 * strength, -23 * strength
        shoulder = -.045 * strength
        right = (.32 + .23 * strength, .13, .05 - .33 * strength)
        left = (-.32 - .23 * strength, .13, .05 - .33 * strength)
        if pilot == 'sable':
            rotate(arm, 'ear.R', (38 * strength, 40 * strength, 0))
            rotate(arm, 'ear.L', (38 * strength, -40 * strength, 0))
            rotate(arm, 'tool.R', (-45 * strength, 0, 0))
        if pilot == 'kest':
            rotate(arm, 'crest', (-38 * strength, 0, 0))
    elif clip == 'phew':
        strength = [0, .45, 1, 1, .35, 0][k]
        height = [1, 1.08, 1.05, 1.02, .88, 1][k]
        yaw, roll = 42 * strength, -8 * strength
        shoulder = [0, .06, .035, .02, -.045, 0][k]
        right = (.32 + .22 * strength, .10, .05 + .28 * strength)
        if pilot == 'sable':
            left, right = (-right[0], right[1], right[2]), (.32, .4, .05)
            yaw = -yaw
        if pilot == 'kest':
            right = (.53, .03, .30)
        if k == 4:
            right, left = (.47, .2, -.12), (-.47, .2, -.12)
    elif clip == 'brace':
        strength = [0, 1, 1, .85, .35, 0][k]
        height = 1 - .16 * strength
        pitch = -32 * strength
        shoulder = .025 * strength
        if pilot == 'sable':
            rotate(arm, 'ear.R', (38 * strength, 12 * strength, 0))
            rotate(arm, 'ear.L', (38 * strength, -12 * strength, 0))
        if pilot == 'kest':
            rotate(arm, 'crest', (38 * strength, 0, 0))
    elif clip == 'heave':
        strength = [0, .7, 1, .85, .35, 0][k]
        height = [1, 1.12, .84, .87, .96, 1][k]
        pitch = [0, 28, -34, -28, -10, 0][k]
        shoulder = .035 * strength
        if k == 1:
            right, left = (.46, .16, .13), (-.46, .16, .13)
        else:
            right = (.32 + .22 * strength, .4 - .28 * strength, .05 + .38 * strength)
            left = (-.32 - .14 * strength, .4 - .16 * strength, .05 + .12 * strength)
        if pilot == 'sable':
            tail = [0, -28, 48, -32, 12, 0][k]
            rotate(arm, 'tail.01', (0, 0, tail))
            rotate(arm, 'tail.02', (0, 0, -tail * .65))
    drop.body(arm, pitch if clip in ('brace', 'heave') else pitch * .35, pitch, height, 1.0)
    rotate(arm, 'head', (pitch, roll, yaw))
    for side in ('R', 'L'):
        arm.pose.bones['shoulder.' + side].location.z = shoulder
    bpy.context.view_layer.update()
    shared.solve_arm(arm, 'R', right, stretch)
    shared.solve_arm(arm, 'L', left, stretch)
    shared.world_hand(arm, 'R', (0, 0, -25 if pilot == 'kest' else 0))
    shared.world_hand(arm, 'L', (0, 0, 25 if pilot == 'kest' else 0))
    if pilot == 'rivet' and clip == 'big_cheer':
        rotate(arm, 'curl.R', (-65, 0, 0))
        rotate(arm, 'curl.L', (-65, 0, 0))
    if clip in ('brace', 'heave'):
        if pilot == 'rivet':
            rotate(arm, 'curl.R', (-65 * strength, 0, 0))
            rotate(arm, 'curl.L', (-65 * strength, 0, 0))
        if pilot == 'kest' and clip == 'heave':
            shared.world_hand(arm, 'R', (0, -35 * strength, -25 - 35 * strength))
            shared.world_hand(arm, 'L', (0, 35 * strength, 25 + 35 * strength))


def snapshot(arm):
    return {b.name: {'rotation_degrees_xyz': [math.degrees(v) for v in b.rotation_euler],
                     'location': list(b.location), 'scale': list(b.scale)} for b in arm.pose.bones}


def key(arm, frame):
    for bone in arm.pose.bones:
        for path in ('rotation_euler', 'location', 'scale'):
            bone.keyframe_insert(data_path=path, frame=frame, group=bone.name)


def author(pilot, reference):
    for image in json.loads((OUT / 'inspection-ledger.json').read_text()):
        path = rig.ROOT / image['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == image['sha256'], 'Inspected reference changed: ' + str(path)
    out = OUT / pilot
    arm, meshes, shell = rig.build(pilot, out=out)
    source_rows = json.loads((HERE / f'{pilot}-drop-poses.json').read_text())['rows']
    action = timing.action(arm, source_rows, pilot, reference / (pilot if pilot != 'rivet' else ''), shared.apply_row)
    if pilot == 'sable':
        point_rows = []
        point_image = OUT / 'keys/sable-point.png'
        for index in (6, 7, 8):
            row = source_rows[index]
            shared.apply_row(arm, row)
            rotate(arm, 'head', (2, 0, -40))
            arm.pose.bones['shoulder.R'].location.z = .035
            bpy.context.view_layer.update()
            shared.solve_arm(arm, 'R', (.51, .08, .30) if index == 8 else (.61, .04, .34 if index == 6 else .40), 1.22)
            shared.world_hand(arm, 'R', (0, -25, -35))
            rotate(arm, 'tool.R', (155 if index == 8 else -10, 0, -20))
            point_rows.append({'frame': timing.FRAMES[pilot][index], 'bones': snapshot(arm),
                               'image_sha256': hashlib.sha256(point_image.read_bytes()).hexdigest(),
                               'observation': 'Rear view chosen: anatomical right point out and up; front mirrors arm. Keep one wrench and original feet. Retract on key 9.'})
            key(arm, timing.FRAMES[pilot][index])
            if row['key'] in timing.holds(pilot):
                key(arm, timing.FRAMES[pilot][index] + timing.holds(pilot)[row['key']])
        (out / 'sable-point-poses.json').write_text(json.dumps(point_rows, indent=2)+'\n')
        changed_frames = {timing.FRAMES[pilot][i] for i in (6, 7, 8)}
        changed_frames.add(timing.FRAMES[pilot][7] + timing.holds(pilot)[8])
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            if round(point.co.x) in changed_frames:
                                point.handle_left.y = point.handle_right.y = point.co.y
                        curve.update()
    action.use_fake_user = True
    actions = [action]
    tables = {}
    for clip, frames in KEYS.items():
        arm.animation_data.action = None
        rows = []
        if clip in ('brace', 'heave'):
            source = {'source': 'alpha-x1-PR harpoon reaction brief'}
        else:
            image = OUT / 'keys' / f'{clip}.png'
            source = {'image': str(image.relative_to(rig.ROOT)),
                      'image_sha256': hashlib.sha256(image.read_bytes()).hexdigest()}
        for index, frame in enumerate(frames):
            pose(arm, pilot, clip, index)
            rows.append({'frame': frame, 'seconds': (frame-1)/30, **source,
                         'observation': NOTES[clip][index], 'bones': snapshot(arm)})
            key(arm, frame)
        act = arm.animation_data.action
        act.name = clip
        act.use_fake_user = True
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation = 'LINEAR' if clip == 'wince' else 'BEZIER'
                            point.handle_left_type = point.handle_right_type = 'AUTO_CLAMPED'
        actions.append(act)
        tables[clip] = rows
    checks = []
    for act in actions:
        arm.animation_data.action = act
        end = int(act.frame_range[1])
        max_drift = 0.0
        for half in range(2, end*2+1):
            frame = half/2
            bpy.context.scene.frame_set(int(frame), subframe=frame%1)
            bpy.context.view_layer.update()
            max_drift = max(max_drift, (arm.pose.bones['pelvis'].head-arm.data.bones['pelvis'].head_local).length)
        assert max_drift < 1e-6
        bpy.context.scene.frame_set(end)
        neutral_error = max(abs(v - identity) for b in arm.pose.bones for values, neutral in
                            [(b.location, (0,0,0)), (b.rotation_euler, (0,0,0)), (b.scale, (1,1,1))]
                            for v, identity in zip(values, neutral))
        if act.name != 'drop_land':
            assert neutral_error < 1e-5, (act.name, neutral_error)
        checks.append({'clip': act.name, 'seconds': (end-1)/30, 'pelvis_max_drift': max_drift,
                       'neutral_component_error': neutral_error, 'half_frame_samples': end*2-1})
    (out / 'poses.json').write_text(json.dumps(tables, indent=2)+'\n')
    (out / 'checks.json').write_text(json.dumps(checks, indent=2)+'\n')
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 85
    scene.render.fps = 30
    arm.animation_data.action = actions[0]
    scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    dest = HERE.parents[1] / f'assets/models/pilot_{pilot}_anim.glb'
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
        export_frame_range=False, export_force_sampling=True, export_def_bones=False,
        export_skins=True, export_yup=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
    rig.common.canonical_indices(str(dest), vertices=rig.common.POLISH is not None)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / f'{pilot}-reactions.blend'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('pilot', choices=['rivet', 'sable', 'kest'])
    parser.add_argument('--reference-root', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    author(args.pilot, args.reference_root)
