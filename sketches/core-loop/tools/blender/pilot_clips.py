"""Build a pilot's new clips from its pose table (design-v3/PILOT-CLIPS.md sections 4.2 to 4.4).

  blender --background --python-exit-code 1 --python pilot_clips.py -- <pilot> --base <blend> --evidence <dir> [--out <glb>]
  blender --background --python-exit-code 1 --python pilot_clips.py -- --selftest

Opens the pilot's base scene (rig, meshes and the seven kept actions), adds one action per
clip in src/presentation/clips/<pilot>.json, baked every frame with linear keys (a loop writes
frame E equal to frame 1), runs the verifier's checks on the export (verify_pilot_clips.py)
and writes poses.json (a full 25-bone snapshot per key) to the evidence folder. Without a pose
table for the pilot it exits 2: there is no table to build.

Hand targets, world wrists and planted hands use pilot_arm's imported pilot solvers.
Controls resolve from the shipped shell GLB in Pod space; control_points are ignored.
Exports use the pilot's section 4.2 route, keeping the seven original actions intact.
--table reads an alternate pose table, for scratch proofs without installing a table.
A clip with "ease": "spline" interpolates with a cardinal spline over its keys (no dead-stop at a
key); every other ease keeps the per-segment lerp, so existing tables bake unchanged.

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
import pilot_arm

FPS = 30
SPLIT = (('spine_01', .55), ('spine_02', .45))
EXPORT_COMMON = dict(export_format='GLB', use_selection=True, export_animations=True,
                     export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                     export_frame_range=False, export_force_sampling=True, export_def_bones=False,
                     export_skins=True, export_yup=True, export_materials='EXPORT',
                     export_cameras=False, export_lights=False)
EXPORT_ROUTES = {
    'rivet': ({}, False), 'sable': ({}, False), 'kest': ({}, False),
    'tarn': ({'export_vertex_color': 'ACTIVE'}, True),
    'tally': ({'export_vertex_color': 'ACTIVE', 'export_extras': False}, True),
    'cannon': ({}, True),
}


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


def flatten(pose, path=()):
    """A pose's numbers as {path: float}; lists contribute one entry per item."""
    out = {}
    for k, v in pose.items():
        if isinstance(v, dict):
            out.update(flatten(v, path + (k,)))
        elif isinstance(v, list):
            for i, x in enumerate(v):
                out[path + (k, i)] = float(x)
        else:
            out[path + (k,)] = float(v)
    return out


def unflatten(flat):
    out = {}
    for path, value in flat.items():
        node = out
        for part, following in zip(path, path[1:]):
            node = node.setdefault(part, [0.0] * 3 if isinstance(following, int) else {})
        node[path[-1]] = value
    return out


def spline_pose(poses, i, frame, loop):
    """Cardinal spline through the keys: tangents come from the neighbouring keys, so a segment
    flows into the next with no dead-stop at the key. A loop wraps (frame E equals frame 1);
    an open clip holds zero tangent at its two ends."""
    n = len(poses)
    times = [f for f, _ in poses]
    flats = [flatten(p) for _, p in poses]
    span = times[-1] - times[0]

    def neighbour(j):
        if 0 <= j < n:
            return times[j], flats[j]
        if not loop:
            return None
        return (times[j + n - 1] - span, flats[j + n - 1]) if j < 0 else (times[j - n + 1] + span, flats[j - n + 1])

    def tangent(j, path):
        before, after = neighbour(j - 1), neighbour(j + 1)
        if before is None or after is None:
            return 0.0
        return (after[1].get(path, default_of(path)) - before[1].get(path, default_of(path))) / (after[0] - before[0])

    t0, t1 = times[i], times[min(i + 1, n - 1)]
    u = 0.0 if t1 == t0 else (frame - t0) / (t1 - t0)
    h = t1 - t0
    h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    j1 = min(i + 1, n - 1)
    out = {}
    for path in set().union(*flats):
        p0, p1 = flats[i].get(path, default_of(path)), flats[j1].get(path, default_of(path))
        out[path] = h00 * p0 + h10 * h * tangent(i, path) + h01 * p1 + h11 * h * tangent(j1, path)
    return unflatten(out)


def default_of(path):
    return 1.0 if path[-1] == 'height' else 0.0


def apply(arm, pose, torso_scale, pilot, planted=None):
    for bone in arm.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    if 'pelvis' in pose:
        pelvis = pose['pelvis']
        arm.pose.bones['pelvis'].rotation_quaternion = Euler(tuple(
            math.radians(pelvis.get(axis, 0)) for axis in ('pitch', 'roll', 'yaw'))).to_quaternion()
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
    for field, bone in (('jaw', 'jaw'), ('crest', 'crest'), ('goggles', 'goggles'), ('curl.R', 'curl.R'), ('curl.L', 'curl.L'), ('tool.R', 'tool.R')):
        if field in pose:
            arm.pose.bones[bone].rotation_quaternion = Euler((math.radians(float(pose[field])), 0, 0)).to_quaternion()
    if 'root' in pose:
        arm.pose.bones['root'].location = Vector(pose['root'])
    bpy.context.view_layer.update()
    for side in ('R', 'L'):
        hand = pose.get('hand.' + side)
        at = (planted or {}).get(side)
        if at is None and hand is not None:
            at = pilot_arm.target(pilot, hand, side)
        wrist = pose.get('wrist.' + side)
        if at is not None:
            pilot_arm.solve(pilot, arm, side, at, wrist if wrist is not None else (0, 0, 0))
        elif wrist is not None:
            pilot_arm.solve(pilot, arm, side, arm.pose.bones['hand.' + side].head.copy(), wrist)


def bake(arm, name, clip, table):
    end = int(clip['end'])
    keys = sorted(clip['keys'], key=lambda k: k['frame'])
    if keys[0]['frame'] != 1 or keys[-1]['frame'] != end:
        raise TableError('%s: keys must start at frame 1 and end at frame %d' % (name, end))
    anchors = table.get('anchors', {})
    pilot = table['pilot']
    poses = [(k['frame'], pose_of(k, anchors)) for k in keys]
    used_hands = [side for side in ('R', 'L') if any('hand.' + side in pose for _, pose in poses)]
    for _, pose in poses:
        for side in used_hands:
            field = 'hand.' + side
            at = pilot_arm.target(pilot, pose[field], side) if field in pose else arm.data.bones[field].head_local
            pose[field] = {'at': list(at)}
    planted = pilot_arm.planted_targets(pilot, clip, table)
    arm.animation_data.action = None
    bpy.context.view_layer.update()
    modes = {b.name: b.rotation_mode for b in arm.pose.bones}
    snapshots = []
    baked = []
    for frame in range(1, end + 1):
        if clip.get('loop') and frame == end:
            pose = poses[0][1]
        else:
            i = max(j for j, (f, _) in enumerate(poses) if f <= frame)
            f0, p0 = poses[i]
            f1, p1 = poses[min(i + 1, len(poses) - 1)]
            if clip.get('ease') == 'spline':
                pose = spline_pose(poses, i, frame, bool(clip.get('loop')))
            else:
                t = 0.0 if f1 == f0 else ease(clip.get('ease', 'smooth'), (frame - f0) / (f1 - f0))
                pose = lerp_pose(p0, p1, t)
        apply(arm, pose, table.get('torso_scale', True), pilot, planted)
        baked.append({b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in arm.pose.bones})
        if clip.get('loop') and frame == end:
            baked[-1] = baked[0]
        if frame in [k['frame'] for k in keys]:
            snapshots.append({'clip': name, 'frame': frame, 'bones': {bone: [list(v) for v in values]
                                                                        for bone, values in baked[-1].items()}})
    action = write_action(arm, name, baked, modes)
    return action, snapshots


def write_action(arm, name, baked, modes):
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    arm.animation_data.action_slot = action.slots.new('OBJECT', arm.name)
    for frame, values in enumerate(baked, 1):
        for bone in arm.pose.bones:
            bone.location, bone.rotation_quaternion, bone.scale = values[bone.name]
            mode = modes[bone.name]
            if mode not in ('QUATERNION', 'AXIS_ANGLE'):
                bone.rotation_euler = bone.rotation_quaternion.to_euler(mode, bone.rotation_euler)
            bone.rotation_mode = mode
            rotation = 'rotation_quaternion' if mode == 'QUATERNION' else 'rotation_euler'
            for path in ('location', rotation, 'scale'):
                bone.keyframe_insert(path, frame=frame)
    for fcurve in _fcurves(action):
        for point in fcurve.keyframe_points:
            point.interpolation = 'LINEAR'
    action.use_fake_user = True
    return action


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
    restore_kept(arm, pilot, data, baseline)
    names = list(table['clips'])
    stray = [n for n in names if n not in data['new']]
    if stray:
        raise TableError('clips %s are not roster roles (rule 2.5: a coordinator change)' % stray)
    receipts = []
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    for name in names:
        action, snaps = bake(arm, name, table['clips'][name], table)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        receipts.extend(snaps)
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    arm.animation_data.action = None
    export(arm, out_glb, pilot)
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'poses.json').write_text(json.dumps(receipts) + '\n')
    passed, line, info = verifier.verify(pilot, out_glb, baseline, has_table=True, table=table)
    (evidence / 'verify.json').write_text(json.dumps(info, indent=2, default=str) + '\n')
    print(line)
    return passed


def restore_kept(arm, pilot, data, baseline):
    """Older reaction scenes predate brace/heave; recover only missing kept actions."""
    missing = [name for name in data['kept'] if verifier._action(bpy, name) is None]
    if not missing:
        return
    source = baseline or verifier.SKETCH / data['pilots'][pilot]['glb']
    old_objects, old_actions = set(bpy.data.objects), set(bpy.data.actions)
    modes = {bone.name: bone.rotation_mode for bone in arm.pose.bones}
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported = next(obj for obj in bpy.data.objects if obj not in old_objects and obj.type == 'ARMATURE')
    for track in imported.animation_data.nla_tracks:
        track.mute = True
    rows = {}
    for name in missing:
        action = next((a for a in bpy.data.actions if a not in old_actions and
                       (a.name == name or a.name.startswith(name + '_'))), None)
        if action is None:
            raise TableError('base scene and %s both lack kept clip %s' % (source, name))
        imported.animation_data.action = action
        imported.animation_data.action_slot = action.slots[0]
        end = int(round(action.frame_range[1]))
        rows[name] = [verifier._basis(imported, bpy, frame / FPS) for frame in range(end + 1)]
    for obj in set(bpy.data.objects) - old_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in set(bpy.data.actions) - old_actions:
        bpy.data.actions.remove(action)
    for name, baked in rows.items():
        write_action(arm, name, baked, modes)
    print('PILOT_CLIPS_RESTORE %s %s %s' % (pilot, ' '.join(missing), source))


def export(arm, out_glb, pilot):
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm] + meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_set(1)
    extra, canonical = EXPORT_ROUTES[pilot]
    bpy.ops.export_scene.gltf(filepath=str(out_glb), **dict(EXPORT_COMMON, **extra))
    polished = any("Bake" in o.data.uv_layers for o in meshes)
    if canonical or polished:
        from common import canonical_indices
        canonical_indices(str(out_glb), vertices=polished)


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
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    baseline = folder / 'baseline.glb'
    export(arm, baseline, pilot)
    table = synthetic_table(pilot)
    beat = table['clips']['cast_special']['keys'][1]
    beat.update({'hand.R': {'control': 'Grip.R', 'offset': [0, -.01, .01]},
                 'hand.L': {'at': [-.32, .40, .05]}, 'wrist.R': [10, 0, 5], 'goggles': 12})
    table['clips']['cast_special']['planted'] = ['L']
    table['control_points'] = {'Grip.R': [9, 9, 9]}
    print('PILOT_CLIPS_BUILD_SELFTEST: hand-control-offset, hand-at, wrist, planted, goggles')
    original = verifier.pose_table
    verifier.pose_table = lambda name: table if name == pilot else original(name)
    try:
        ok = build(pilot, table, folder / 'pilot_sable_anim.glb', folder, baseline)
    finally:
        verifier.pose_table = original
    if ok:
        arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
        for track in arm.animation_data.nla_tracks:
            track.mute = True
        arm.animation_data.action = verifier._action(bpy, 'cast_special')
        arm.animation_data.action_slot = arm.animation_data.action.slots[0]
        basis = verifier._basis(arm, bpy, (beat['frame'] - 1) / FPS)
        right = (arm.pose.bones['hand.R'].head - pilot_arm.target(pilot, beat['hand.R'], 'R')).length
        left = (arm.pose.bones['hand.L'].head - Vector(beat['hand.L']['at'])).length
        wrist = arm.pose.bones['hand.R'].matrix.to_quaternion().rotation_difference(
            Euler(tuple(math.radians(v) for v in beat['wrist.R'])).to_quaternion()).angle
        goggles = basis['goggles'][1].rotation_difference(Euler((math.radians(12), 0, 0)).to_quaternion()).angle
        cases = [('hand-control-offset and ignored control_points', right, .003),
                 ('hand-at and planted', left, .003), ('world wrist', wrist, .001),
                 ('goggles', goggles, .001)]
        for name, error, limit in cases:
            passed = error < limit
            print('PILOT_CLIPS_BUILD_SELFTEST_CASE %s: %s (%.8f)' % (name, 'PASS' if passed else 'FAIL', error))
            ok = ok and passed
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
    parser.add_argument('--table', type=Path)
    parser.add_argument('--selftest', action='store_true')
    a = parser.parse_args(argv)
    if a.selftest:
        sys.exit(0 if selftest() else 1)
    if not a.pilot:
        parser.error('a pilot or --selftest')
    table = json.loads(a.table.read_text()) if a.table else verifier.pose_table(a.pilot)
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
