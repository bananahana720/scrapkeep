"""Build a pilot's new clips from its pose table (design-v3/PILOT-CLIPS.md sections 4.2 to 4.4).

  blender --background --python-exit-code 1 --python pilot_clips.py -- <pilot> --base <blend> --evidence <dir> [--out <glb>]
  blender --background --python-exit-code 1 --python pilot_clips.py -- --selftest

Opens the pilot's base scene (rig, meshes and the seven kept actions), adds one action per
clip in src/presentation/clips/<pilot>.json, baked every frame with linear keys (a loop writes
frame E equal to frame 1), runs the verifier's checks on the export (verify_pilot_clips.py)
and writes poses.json (a full 25-bone snapshot per key) to the evidence folder. Without a pose
table for the pilot it exits 2: there is no table to build.

Vocabulary implemented here: torso.height/pitch/yaw/roll, head.pitch/yaw/roll, neck.drop,
shoulder.lift, ears, tail, jaw, crest, curl.R/L, tool.R, root. Hand targets (hand.R/L "at" or
"control", wrist, planted) need the pilot's own arm solver (anim_rivet_drop.solve_arm,
pilot_tally.solve_tally_arm) and are refused with a message naming the key: a PE pilot unit
wires its solver here before its table may key hands. Export uses the generic ACTIONS
arguments; a pilot unit replaces them with its route's exact arguments (section 4.2 table).

--selftest imports the shipped Sable GLB as the base, builds a synthetic table (every new
clip, a torso and head beat, rest anchors), bakes, exports to a temp dir and requires the
verifier to PASS it with 18 clips and the seven kept unchanged against the same scene exported
before the build (a reimported GLB resamples the kept clips, so the shipped GLB cannot be the
baseline there).
"""
import argparse
import json
import math
from pathlib import Path
import sys
import tempfile

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import verify_pilot_clips as verifier

FPS = 30
SPLIT = (('spine_01', .55), ('spine_02', .45))
SOLVER_KEYS = ('hand.R', 'hand.L', 'wrist.R', 'wrist.L')


class TableError(Exception):
    pass


def ease(kind, f):
    return f if kind == 'linear' else f * f * (3 - 2 * f)


def pose_of(key, anchors):
    """A key's fields with its anchor pose underneath ("pose": "rest" or "ride")."""
    base = {}
    anchor = key.get('pose')
    if anchor and anchor != 'rest':
        base = dict(anchors.get(anchor, {}))
    for field, value in key.items():
        if field not in ('frame', 'pose', 'note'):
            base[field] = value
    for field in base:
        if field in SOLVER_KEYS:
            raise TableError('key field %s needs the pilot arm solver (not wired in PE-0)' % field)
    return base


def number(pose, path, default=0.0):
    node = pose
    for part in path.split('.', 1)[:1]:
        node = node.get(part, {}) if isinstance(node, dict) else {}
    if len(path.split('.', 1)) == 2:
        return float(node.get(path.split('.', 1)[1], default)) if isinstance(node, dict) else default
    return float(node) if not isinstance(node, dict) else default


def lerp_pose(a, b, f):
    keys = set(a) | set(b)
    out = {}
    for k in keys:
        va, vb = a.get(k), b.get(k)
        if isinstance(va, dict) or isinstance(vb, dict):
            out[k] = lerp_pose(va or {}, vb or {}, f)
        elif isinstance(va, list) or isinstance(vb, list):
            la, lb = va or [0, 0, 0], vb or [0, 0, 0]
            out[k] = [x + (y - x) * f for x, y in zip(la, lb)]
        else:
            x = 0.0 if va is None else float(va)
            y = 0.0 if vb is None else float(vb)
            if k == 'height' and (va is None or vb is None):
                x = 1.0 if va is None else x
                y = 1.0 if vb is None else y
            out[k] = x + (y - x) * f
    return out


def apply(arm, pose, torso_scale):
    for bone in arm.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    torso = pose.get('torso', {})
    for name, share in SPLIT:
        e = Euler((math.radians(torso.get('pitch', 0) * share), math.radians(torso.get('roll', 0) * share),
                   math.radians(torso.get('yaw', 0) * share)))
        arm.pose.bones[name].rotation_quaternion = e.to_quaternion()
    if 'height' in torso and abs(float(torso['height']) - 1.0) > 1e-9:
        if not torso_scale:
            raise TableError('torso.height on a table with torso_scale false')
        arm.pose.bones['spine_01'].scale = (1, float(torso['height']), 1)
    head = pose.get('head', {})
    arm.pose.bones['head'].rotation_quaternion = Euler((math.radians(head.get('pitch', 0)), math.radians(head.get('roll', 0)),
                                                       math.radians(head.get('yaw', 0)))).to_quaternion()
    if 'neck' in pose:
        arm.pose.bones['neck'].location = (0, 0, float(pose['neck'].get('drop', 0)))
    if 'shoulder' in pose:
        for side in ('shoulder.R', 'shoulder.L'):
            arm.pose.bones[side].location = (0, 0, float(pose['shoulder'].get('lift', 0)))
    if 'ears' in pose:
        for side, sign in (('ear.R', 1), ('ear.L', -1)):
            arm.pose.bones[side].rotation_quaternion = Euler((0, 0, math.radians(float(pose['ears']) * sign))).to_quaternion()
    if 'tail' in pose:
        angle = math.radians(float(pose['tail']))
        arm.pose.bones['tail.01'].rotation_quaternion = Euler((angle, 0, 0)).to_quaternion()
        arm.pose.bones['tail.02'].rotation_quaternion = Euler((-.55 * angle, 0, 0)).to_quaternion()
    for field, bone in (('jaw', 'jaw'), ('crest', 'crest'), ('curl.R', 'curl.R'), ('curl.L', 'curl.L'), ('tool.R', 'tool.R')):
        if field in pose:
            arm.pose.bones[bone].rotation_quaternion = Euler((math.radians(float(pose[field])), 0, 0)).to_quaternion()
    if 'root' in pose:
        arm.pose.bones['root'].location = Vector(pose['root'])


def bake(arm, name, clip, table):
    end = int(clip['end'])
    keys = sorted(clip['keys'], key=lambda k: k['frame'])
    if keys[0]['frame'] != 1 or keys[-1]['frame'] != end:
        raise TableError('%s: keys must start at frame 1 and end at frame %d' % (name, end))
    anchors = table.get('anchors', {})
    poses = [(k['frame'], pose_of(k, anchors)) for k in keys]
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    snapshots = []
    for frame in range(1, end + 1):
        if clip.get('loop') and frame == end:
            pose = poses[0][1]
        else:
            i = max(j for j, (f, _) in enumerate(poses) if f <= frame)
            f0, p0 = poses[i]
            f1, p1 = poses[min(i + 1, len(poses) - 1)]
            t = 0.0 if f1 == f0 else ease(clip.get('ease', 'smooth'), (frame - f0) / (f1 - f0))
            pose = lerp_pose(p0, p1, t)
        apply(arm, pose, table.get('torso_scale', True))
        for bone in arm.pose.bones:
            for path in ('location', 'rotation_quaternion', 'scale'):
                bone.keyframe_insert(path, frame=frame)
        if frame in [k['frame'] for k in keys]:
            snapshots.append({'clip': name, 'frame': frame, 'bones': {b.name: [list(b.location), list(b.rotation_quaternion), list(b.scale)]
                                                                        for b in arm.pose.bones}})
    for fcurve in _fcurves(action):
        for point in fcurve.keyframe_points:
            point.interpolation = 'LINEAR'
    action.use_fake_user = True
    return action, snapshots


def _fcurves(action):
    if hasattr(action, 'fcurves') and len(getattr(action, 'fcurves', [])):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def build(pilot, table, out_glb, evidence, baseline):
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    if arm.animation_data is None:
        arm.animation_data_create()
    data = verifier.roster()
    names = list(table['clips'])
    stray = [n for n in names if n not in data['new']]
    if stray:
        raise TableError('clips %s are not roster roles (rule 2.5: a coordinator change)' % stray)
    receipts = []
    for name in names:
        action, snaps = bake(arm, name, table['clips'][name], table)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        receipts.extend(snaps)
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    arm.animation_data.action = None
    export(arm, out_glb)
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'poses.json').write_text(json.dumps(receipts) + '\n')
    passed, line, info = verifier.verify(pilot, out_glb, baseline, has_table=True)
    (evidence / 'verify.json').write_text(json.dumps(info, indent=2, default=str) + '\n')
    print(line)
    return passed


def export(arm, out_glb):
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm] + meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.context.scene.render.fps = FPS
    bpy.ops.export_scene.gltf(filepath=str(out_glb), export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_anim_slide_to_zero=True, export_force_sampling=True,
                              export_frame_step=1, export_reset_pose_bones=True)


def synthetic_table(pilot):
    data = verifier.roster()
    ends = data['end_frames'][pilot]
    ride = {'torso': {'pitch': -6}, 'head': {'pitch': -4}}
    clips = {}
    for name in data['new']:
        end = ends[name]
        frm, to = data['anchors'].get(name, ['rest', 'rest'])
        mid = {'frame': max(2, end // 2), 'torso': {'pitch': 3}, 'head': {'yaw': 4}, 'note': 'selftest beat'}
        if name in data['loops']:
            mid = {'frame': max(2, end // 2), 'torso': {'pitch': 2}, 'note': 'selftest sway inside the cap'}
            if name == 'ult_ride_loop':
                mid = dict(mid, pose='ride', torso={'pitch': -5}, head={'pitch': -4})
        keys = [{'frame': 1, 'pose': frm}, mid, {'frame': end, 'pose': to}]
        if name in ('ult_windup', 'ult_strike', 'ult_recover'):
            keys[1] = {'frame': max(2, end // 2), 'pose': 'ride', 'note': 'selftest ride beat'}
        clips[name] = {'end': end, 'loop': name in data['loops'], 'from': frm, 'to': to, 'ease': 'smooth', 'keys': keys}
    return {'schema': 'pilot-clips-v1', 'pilot': pilot, 'fps': FPS, 'rig': 'pilot-v1', 'torso_scale': True,
            'anchors': {'rest': 'bind', 'ride': ride}, 'clips': clips}


def selftest():
    pilot = 'sable'
    base_glb = verifier.SKETCH / verifier.roster()['pilots'][pilot]['glb']
    folder = Path(tempfile.mkdtemp(prefix='pilot-clips-build-'))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(base_glb))
    # A reimported scene resamples the kept clips on export, so the self-test's baseline is the
    # same scene exported once before the build, through the same exporter arguments.
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    baseline = folder / 'baseline.glb'
    export(arm, baseline)
    table = synthetic_table(pilot)
    original = verifier.pose_table
    verifier.pose_table = lambda name: table if name == pilot else original(name)
    try:
        ok = build(pilot, table, folder / 'pilot_sable_anim.glb', folder, baseline)
    finally:
        verifier.pose_table = original
    print('PILOT_CLIPS_BUILD_SELFTEST: %s (%s)' % ('PASS' if ok else 'FAIL', folder))
    return ok


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('pilot', nargs='?')
    parser.add_argument('--base')
    parser.add_argument('--evidence')
    parser.add_argument('--baseline')
    parser.add_argument('--out')
    parser.add_argument('--selftest', action='store_true')
    a = parser.parse_args(argv)
    if a.selftest:
        sys.exit(0 if selftest() else 1)
    if not a.pilot:
        parser.error('a pilot or --selftest')
    table = verifier.pose_table(a.pilot)
    if table is None:
        print('PILOT_CLIPS_BUILD: no pose table for %s (src/presentation/clips/%s.json); nothing to build' % (a.pilot, a.pilot))
        sys.exit(2)
    if not a.base or not a.evidence:
        parser.error('--base and --evidence are required with a pose table')
    bpy.ops.wm.open_mainfile(filepath=a.base)
    out = Path(a.out) if a.out else verifier.SKETCH / verifier.roster()['pilots'][a.pilot]['glb']
    baseline = Path(a.baseline) if a.baseline else None
    try:
        ok = build(a.pilot, table, out, Path(a.evidence), baseline)
    except TableError as error:
        print('PILOT_CLIPS_BUILD: FAIL %s: %s' % (a.pilot, error))
        sys.exit(1)
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
