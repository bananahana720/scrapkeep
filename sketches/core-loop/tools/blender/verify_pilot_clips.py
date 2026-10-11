"""Verify a shipped pilot GLB's clip set (design-v3/PILOT-CLIPS.md section 6).

  blender --background --python-exit-code 1 --python verify_pilot_clips.py -- <pilot> --baseline <glb> [--glb <glb>]
  blender --background --python-exit-code 1 --python verify_pilot_clips.py -- --selftest

It reads the GLB Godot loads, not a Blender scene. Structure comes from the JSON chunk; pose
checks reimport the GLB into an empty scene (as verify_pilot_drop.py does) and sample every new
clip at half-frame steps. Prints `PILOT_CLIPS: PASS <pilot> <n> clips` and exits 0, or
`PILOT_CLIPS: FAIL <pilot>: <first failure>` and exits 1. The receipt goes to
artifacts/local/alpha/push/w13/clips/<pilot>/verify.json (or --evidence).

Transitional rule (until PE-INT): a GLB with only the seven kept clips passes as
`PASS <pilot> 7 clips` while roster.json says has_table false for the pilot; with has_table
true it fails "seven clips, no pose table".

--selftest builds a clean 18-clip GLB from the shipped Sable GLB in a temp dir (the eleven new
clips keyed at rest, at Sable's end frames), seeds four defects one at a time (a clip missing,
a loop whose last frame differs from its first, a kept clip changed against the baseline, a
track on a mesh node), requires a FAIL for each and a PASS for the clean copy, and exits 0.

Checks not yet implemented, printed as NOTE on an 18-clip GLB: planted hands (13), contact
distance to the shell's CONTROLS (14) and the pilot extras (17). They need the pose tables and
the shell CONTROLS tables the PE pilot units bring.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
ROOT = HERE.parents[3]
ROSTER = SKETCH / 'src/presentation/clips/roster.json'
TABLES = SKETCH / 'src/presentation/clips'
EVIDENCE = ROOT / 'artifacts/local/alpha/push/w13/clips'
FPS = 30
GLB_CAP = 640 * 1024
ANIM_CAP = 300 * 1024
REST_TOL = 1e-5
RIDE_TOL = 1e-4
SEAM_TOL = 1e-5
KEPT_TOL = 1e-5
CLEARANCE = 0.98
PELVIS = (0.0, 0.0, -0.30)
# Section 3 rules 5 and 6: idle and ride amplitude caps.
CAP_SPINE_DEG = 6.0
CAP_SOFT_DEG = 15.0
CAP_HAND_M = 0.02
SPINE = ('spine_01', 'spine_02', 'neck', 'head')
SOFT = ('ear.R', 'ear.L', 'tail.01', 'tail.02', 'crest', 'jaw', 'curl.R', 'curl.L')
HANDS = ('hand.R', 'hand.L')
FLOAT = 5126
COMPONENTS = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}


class Failure(Exception):
    pass


# --- GLB bytes ---------------------------------------------------------------------------

def read_glb(path):
    blob = Path(path).read_bytes()
    if blob[:4] != b'glTF':
        raise Failure('%s is not a GLB' % path)
    length = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20 + length])
    rest = 20 + length
    binary = b''
    if rest + 8 <= len(blob):
        size = struct.unpack_from('<I', blob, rest)[0]
        binary = blob[rest + 8:rest + 8 + size]
    return doc, bytearray(binary), blob


def write_glb(path, doc, binary):
    text = json.dumps(doc, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    data = bytes(binary) + b'\0' * (-len(binary) % 4)
    doc_len = 12 + 8 + len(text) + 8 + len(data)
    out = struct.pack('<III', 0x46546C67, 2, doc_len)
    out += struct.pack('<II', len(text), 0x4E4F534A) + text
    out += struct.pack('<II', len(data), 0x004E4942) + data
    Path(path).write_bytes(out)


def _span(doc, index):
    acc = doc['accessors'][index]
    view = doc['bufferViews'][acc['bufferView']]
    if acc.get('componentType') != FLOAT or view.get('byteStride') not in (None, 4 * COMPONENTS[acc['type']]):
        raise Failure('accessor %d is not tightly packed float' % index)
    start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    return start, acc['count'], COMPONENTS[acc['type']]


def values(doc, binary, index):
    start, count, width = _span(doc, index)
    flat = struct.unpack_from('<%df' % (count * width), binary, start)
    return [flat[i * width:(i + 1) * width] for i in range(count)]


def poke(doc, binary, index, row, column, value):
    start, _, width = _span(doc, index)
    struct.pack_into('<f', binary, start + 4 * (row * width + column), value)


def append_accessor(doc, binary, rows, kind):
    width = COMPONENTS[kind]
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    for row in rows:
        binary.extend(struct.pack('<%df' % width, *row))
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary) - offset})
    acc = {'bufferView': len(doc['bufferViews']) - 1, 'componentType': FLOAT, 'count': len(rows), 'type': kind}
    if kind == 'SCALAR':
        acc['min'] = [min(r[0] for r in rows)]
        acc['max'] = [max(r[0] for r in rows)]
    doc['accessors'].append(acc)
    doc['buffers'][0]['byteLength'] = len(binary)
    return len(doc['accessors']) - 1


def clip_span(doc, anim):
    times = [doc['accessors'][s['input']] for s in anim['samplers']]
    return min(a['min'][0] for a in times), max(a['max'][0] for a in times)


def animation_bytes(doc):
    seen = set()
    for anim in doc.get('animations', []):
        for sampler in anim['samplers']:
            seen.add(sampler['input'])
            seen.add(sampler['output'])
    total = 0
    for index in seen:
        acc = doc['accessors'][index]
        total += acc['count'] * COMPONENTS[acc['type']] * 4
    return total


def channel_map(doc, binary, anim):
    """{(target node name, path): (times, outputs)} for one animation."""
    out = {}
    for channel in anim['channels']:
        sampler = anim['samplers'][channel['sampler']]
        node = doc['nodes'][channel['target']['node']].get('name', str(channel['target']['node']))
        out[(node, channel['target']['path'])] = (values(doc, binary, sampler['input']), values(doc, binary, sampler['output']))
    return out


# --- roster and tables --------------------------------------------------------------------

def roster():
    return json.loads(ROSTER.read_text())


def pose_table(pilot):
    path = TABLES / ('%s.json' % pilot)
    return json.loads(path.read_text()) if path.exists() else None


def expected_clips(data, pilot, table):
    """{clip: {end, loop, from, to}} for the new clips: the pose table's, else the roster's."""
    ends = data['end_frames'][pilot]
    anchors = data.get('anchors', {})
    clips = {}
    for clip in data['new']:
        row = (table or {}).get('clips', {}).get(clip, {})
        frm, to = anchors.get(clip, ['rest', 'rest'])
        clips[clip] = {'end': int(row.get('end', ends[clip])), 'loop': bool(row.get('loop', clip in data['loops'])),
                       'from': row.get('from', frm), 'to': row.get('to', to)}
    return clips


# --- structure (JSON) ----------------------------------------------------------------------

def check_structure(doc, binary, blob, base_doc, base_bin, data, pilot, has_table, table, info):
    names = [a.get('name', '') for a in doc.get('animations', [])]
    info['clips'] = names
    kept = list(data['kept'])
    new = list(data['new'])
    if not names:
        raise Failure('check 1: the GLB has no clips')
    if 'RESET' in names:
        raise Failure('check 1: a RESET action is exported')
    if sorted(names) == sorted(kept):
        if has_table:
            raise Failure('seven clips, no pose table: roster.json says has_table true but the GLB carries the seven kept clips only')
        info['transitional'] = True
    else:
        missing = [c for c in kept + new if c not in names]
        extra = [c for c in names if c not in kept + new]
        if missing or extra:
            raise Failure('check 1: clip set differs from roster.json: missing %s, extra %s' % (missing, extra))
        if not has_table:
            raise Failure('check 1: 18 clips but roster.json says has_table false for %s' % pilot)
        info['transitional'] = False
    for name in names:
        lowered = name.lower()
        is_loop = name in data['loops']
        if name.endswith('_loop') != is_loop:
            raise Failure('check 3: %s: loop names are exactly the roster loops' % name)
        if not is_loop and (lowered.startswith(('loop', 'cycle')) or lowered.endswith(('loop', 'cycle'))):
            raise Failure('check 3: one-shot %s would import as a loop' % name)
    skins = doc.get('skins', [])
    if len(skins) != 1 or len(skins[0]['joints']) != 25:
        raise Failure('check 4: one skin of 25 joints expected, found %s' % [len(s['joints']) for s in skins])
    joints = set(skins[0]['joints'])
    hierarchy = _hierarchy(doc, skins[0]['joints'])
    if base_doc is not None and hierarchy != _hierarchy(base_doc, base_doc['skins'][0]['joints']):
        raise Failure('check 4: the joint hierarchy differs from the baseline')
    for anim in doc['animations']:
        for channel in anim['channels']:
            target = channel['target']
            if target.get('node') not in joints or target.get('path') not in ('translation', 'rotation', 'scale'):
                node = doc['nodes'][target['node']].get('name', target['node']) if 'node' in target else None
                raise Failure('check 5: %s animates %s.%s, not a joint transform' % (anim.get('name'), node, target.get('path')))
    expect = expected_clips(data, pilot, table)
    for anim in doc['animations']:
        start, end = clip_span(doc, anim)
        name = anim.get('name')
        if abs(start) > 1e-6:
            raise Failure('check 2: %s starts at %.6f s, not 0' % (name, start))
        if name in expect and abs(end - (expect[name]['end'] - 1) / FPS) > 1.0 / 60.0:
            raise Failure('check 2: %s lasts %.4f s, the table says %.4f s' % (name, end, (expect[name]['end'] - 1) / FPS))
        info.setdefault('lengths', {})[name] = end
    for anim in doc['animations']:
        if anim.get('name') not in data['loops']:
            continue
        for sampler in anim['samplers']:
            out = values(doc, binary, sampler['output'])
            seam = max(abs(a - b) for a, b in zip(out[0], out[-1]))
            if seam > SEAM_TOL:
                raise Failure('check 9: loop %s is not seamless (frame E differs from frame 1 by %.6f)' % (anim['name'], seam))
    if base_doc is not None:
        base_meshes = [[(sorted(p['attributes']), base_doc['accessors'][p['indices']]['count']) for p in m['primitives']] for m in base_doc['meshes']]
        meshes = [[(sorted(p['attributes']), doc['accessors'][p['indices']]['count']) for p in m['primitives']] for m in doc['meshes']]
        if meshes != base_meshes:
            raise Failure('check 6: mesh primitives, attributes or triangle counts differ from the baseline')
        base_anims = {a.get('name'): a for a in base_doc['animations']}
        for anim in doc['animations']:
            name = anim.get('name')
            if name not in kept or name not in base_anims:
                continue
            ours = channel_map(doc, binary, anim)
            theirs = channel_map(base_doc, base_bin, base_anims[name])
            if set(ours) != set(theirs):
                raise Failure('check 16: kept clip %s changed its channels' % name)
            for key in ours:
                for a_rows, b_rows in zip(ours[key], theirs[key]):
                    if len(a_rows) != len(b_rows) or any(abs(x - y) > KEPT_TOL for ra, rb in zip(a_rows, b_rows) for x, y in zip(ra, rb)):
                        raise Failure('check 16: kept clip %s changed on %s.%s' % (name, key[0], key[1]))
    info['glb_bytes'] = len(blob)
    info['animation_bytes'] = animation_bytes(doc)
    if len(blob) > GLB_CAP or info['animation_bytes'] > ANIM_CAP:
        raise Failure('check 7: size %d bytes (cap %d), animation data %d bytes (cap %d)' % (len(blob), GLB_CAP, info['animation_bytes'], ANIM_CAP))


def _hierarchy(doc, joints):
    parent = {}
    for index, node in enumerate(doc['nodes']):
        for child in node.get('children', []):
            parent[child] = index
    return {doc['nodes'][j].get('name'): doc['nodes'][parent[j]].get('name') if parent.get(j) in joints else None for j in joints}


# --- pose (Blender reimport) --------------------------------------------------------------

def check_pose(glb, data, pilot, table, info):
    import bpy
    from mathutils import Quaternion, Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=str(glb))
    arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
    if arm is None:
        raise Failure('reimport: no armature')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    expect = expected_clips(data, pilot, table)
    rigid = table is not None and table.get('torso_scale') is False or pilot == 'cannon'
    report = {}
    ride_start = None
    chain = {}
    for clip in data['new']:
        action = _action(bpy, clip)
        if action is None:
            raise Failure('reimport: clip %s has no action' % clip)
        arm.animation_data.action = action
        if len(action.slots) >= 1:
            arm.animation_data.action_slot = action.slots[0]
        end = (expect[clip]['end'] - 1) / FPS
        halves = int(round(end * FPS * 2)) + 1
        first = _basis(arm, bpy, 0.0)
        last = _basis(arm, bpy, end)
        chain[clip] = (first, last)
        row = {'seconds': end, 'half_frame_samples': halves}
        if expect[clip]['from'] == 'rest' and _from_rest(first) > REST_TOL:
            raise Failure('check 8: %s does not start at rest (%.6f)' % (clip, _from_rest(first)))
        if expect[clip]['to'] == 'rest' and _from_rest(last) > REST_TOL:
            raise Failure('check 8: %s does not end at rest (%.6f)' % (clip, _from_rest(last)))
        drift = 0.0
        amplitude = 0.0
        scale_error = 0.0
        hands0 = {h: arm.matrix_world @ arm.pose.bones[h].head for h in HANDS if h in arm.pose.bones}
        for half in range(halves):
            t = half / (2.0 * FPS)
            basis = _basis(arm, bpy, t)
            if clip != 'unlock':
                pelvis = arm.matrix_world @ arm.pose.bones['pelvis'].head
                drift = max(drift, (pelvis - Vector(PELVIS)).length)
            for name, (_, _, scale) in basis.items():
                for value in scale:
                    scale_error = max(scale_error, abs(value - 1.0)) if rigid else scale_error
                    if not rigid and not 0.7 <= value <= 1.4:
                        raise Failure('check 15: %s scales %s to %.3f' % (clip, name, value))
            if expect[clip]['loop']:
                ref = first
                for name in SPINE + SOFT:
                    if name in basis:
                        angle = math.degrees((ref[name][1].rotation_difference(basis[name][1])).angle)
                        angle = min(angle, 360.0 - angle)
                        cap = CAP_SPINE_DEG if name in SPINE else CAP_SOFT_DEG
                        amplitude = max(amplitude, angle / cap)
                for hand, at in hands0.items():
                    amplitude = max(amplitude, (arm.matrix_world @ arm.pose.bones[hand].head - at).length / CAP_HAND_M)
        if drift > 1e-6:
            raise Failure('check 11: %s moves the pelvis by %.7f m' % (clip, drift))
        if rigid and scale_error > 1e-5:
            raise Failure('check 15: %s scales a bone of a rigid cast by %.6f' % (clip, scale_error))
        if amplitude > 1.0:
            raise Failure('check 10: %s exceeds its amplitude cap (%.2f of the cap)' % (clip, amplitude))
        radius = 0.0
        for frame in range(int(round(end * FPS)) + 1):
            bpy.context.scene.frame_set(frame)
            radius = max(radius, _radius(bpy, meshes))
        if clip != 'unlock' and radius >= CLEARANCE:
            raise Failure('check 12: %s reaches %.4f m (clearance %.2f)' % (clip, radius, CLEARANCE))
        row.update({'pelvis_drift': drift, 'amplitude_of_cap': amplitude, 'envelope': radius, 'rigid_scale_error': scale_error})
        report[clip] = row
    ride = chain['ult_ride_loop'][0]
    for clip, end_kind in (('ult_windup', 1), ('ult_strike', 0), ('ult_strike', 1), ('ult_recover', 0)):
        error = _distance(chain[clip][end_kind], ride)
        if error > RIDE_TOL:
            raise Failure('check 8: %s %s is %.6f off the ride pose' % (clip, 'end' if end_kind else 'start', error))
    info['pose'] = report


def _action(bpy, clip):
    exact = [a for a in bpy.data.actions if a.name == clip]
    if exact:
        return exact[0]
    # The importer may suffix the armature name (render_pilot_reactions.py matches the same way).
    loose = [a for a in bpy.data.actions if a.name.startswith(clip + '_')]
    return loose[0] if len(loose) == 1 else None


def _basis(arm, bpy, t):
    frame = t * FPS
    bpy.context.scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
    bpy.context.view_layer.update()
    out = {}
    for bone in arm.pose.bones:
        quat = bone.rotation_quaternion.copy() if bone.rotation_mode == 'QUATERNION' else bone.rotation_euler.to_quaternion()
        out[bone.name] = (bone.location.copy(), quat, bone.scale.copy())
    return out


def _from_rest(basis):
    worst = 0.0
    for loc, quat, scale in basis.values():
        worst = max(worst, max(abs(v) for v in loc), max(abs(v - 1.0) for v in scale),
                    min(max(abs(a - b) for a, b in zip(quat, (1, 0, 0, 0))), max(abs(a + b) for a, b in zip(quat, (1, 0, 0, 0)))))
    return worst


def _distance(a, b):
    worst = 0.0
    for name in a:
        la, qa, sa = a[name]
        lb, qb, sb = b[name]
        q = min(max(abs(x - y) for x, y in zip(qa, qb)), max(abs(x + y) for x, y in zip(qa, qb)))
        worst = max(worst, (la - lb).length, (sa - sb).length, q)
    return worst


def _radius(bpy, meshes):
    deps = bpy.context.evaluated_depsgraph_get()
    worst = 0.0
    for obj in meshes:
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        for v in mesh.vertices:
            worst = max(worst, (evaluated.matrix_world @ v.co).length)
        evaluated.to_mesh_clear()
    return worst


# --- the run -------------------------------------------------------------------------------

def verify(pilot, glb, baseline, has_table=None, pose=True, quiet=False):
    """Returns (passed, line, info)."""
    data = roster()
    if pilot not in data['pilots']:
        raise SystemExit('unknown pilot %s; roster has %s' % (pilot, sorted(data['pilots'])))
    if has_table is None:
        has_table = bool(data['pilots'][pilot].get('has_table', False))
    table = pose_table(pilot)
    info = {'pilot': pilot, 'glb': str(glb), 'baseline': str(baseline) if baseline else None, 'has_table': has_table}
    try:
        doc, binary, blob = read_glb(glb)
        info['glb_sha256'] = hashlib.sha256(blob).hexdigest()
        base_doc = base_bin = None
        if baseline:
            base_doc, base_bin, _ = read_glb(baseline)
        check_structure(doc, binary, blob, base_doc, base_bin, data, pilot, has_table, table, info)
        if not info['transitional'] and pose:
            check_pose(glb, data, pilot, table, info)
            info['not_checked'] = ['13 planted hands', '14 contact to CONTROLS', '17 pilot extras']
        line = 'PILOT_CLIPS: PASS %s %d clips' % (pilot, len(info['clips']))
        info['verdict'] = 'PASS'
        return True, line, info
    except Failure as error:
        info['verdict'] = 'FAIL'
        info['failure'] = str(error)
        return False, 'PILOT_CLIPS: FAIL %s: %s' % (pilot, error), info


def synthetic(base_glb, pilot, out):
    """The clean self-test GLB: the base GLB plus every new roster clip keyed at the joints' rest
    transforms, two linear keys each, at the pilot's end frames."""
    data = roster()
    doc, binary, _ = read_glb(base_glb)
    joints = doc['skins'][0]['joints']
    ends = data['end_frames'][pilot]
    for clip in data['new']:
        seconds = (ends[clip] - 1) / FPS
        times = append_accessor(doc, binary, [(0.0,), (seconds,)], 'SCALAR')
        samplers = []
        channels = []
        for joint in joints:
            node = doc['nodes'][joint]
            for path, kind, rest in (('translation', 'VEC3', node.get('translation', [0, 0, 0])),
                                     ('rotation', 'VEC4', node.get('rotation', [0, 0, 0, 1])),
                                     ('scale', 'VEC3', node.get('scale', [1, 1, 1]))):
                output = append_accessor(doc, binary, [tuple(rest), tuple(rest)], kind)
                samplers.append({'input': times, 'output': output, 'interpolation': 'LINEAR'})
                channels.append({'sampler': len(samplers) - 1, 'target': {'node': joint, 'path': path}})
        doc['animations'].append({'name': clip, 'samplers': samplers, 'channels': channels})
    write_glb(out, doc, binary)
    return out


def seed(clean, out, defect):
    doc, binary, _ = read_glb(clean)
    anims = {a['name']: a for a in doc['animations']}
    if defect == 'missing':
        doc['animations'] = [a for a in doc['animations'] if a['name'] != 'cast_line']
    elif defect == 'seam':
        anim = anims['idle_loop']
        sampler = next(anim['samplers'][c['sampler']] for c in anim['channels'] if c['target']['path'] == 'rotation')
        rows = values(doc, binary, sampler['output'])
        half = math.radians(3.0) / 2.0
        quat = (math.sin(half), 0.0, 0.0, math.cos(half))
        for column, value in enumerate(quat):
            poke(doc, binary, sampler['output'], len(rows) - 1, column, value)
    elif defect == 'kept':
        # A brace channel whose output no other clip shares (the exporter reuses identical accessors).
        anim = anims['brace']
        shared = [s['output'] for a in doc['animations'] if a is not anim for s in a['samplers']]
        sampler = next(anim['samplers'][c['sampler']] for c in anim['channels']
                       if anim['samplers'][c['sampler']]['output'] not in shared
                       and doc['accessors'][anim['samplers'][c['sampler']]['output']]['count'] > 2)
        rows = values(doc, binary, sampler['output'])
        poke(doc, binary, sampler['output'], len(rows) // 2, 0, rows[len(rows) // 2][0] + 0.01)
    elif defect == 'nonbone':
        anim = anims['drop_land']
        mesh_node = next(i for i, n in enumerate(doc['nodes']) if 'mesh' in n)
        sampler = next(c['sampler'] for c in anim['channels'] if c['target']['path'] == 'translation')
        anim['channels'].append({'sampler': sampler, 'target': {'node': mesh_node, 'path': 'translation'}})
    write_glb(out, doc, binary)
    return out


def selftest():
    pilot = 'sable'
    base = SKETCH / roster()['pilots'][pilot]['glb']
    folder = Path(tempfile.mkdtemp(prefix='pilot-clips-selftest-'))
    clean = synthetic(base, pilot, folder / 'clean.glb')
    ok = True
    for defect in ('missing', 'seam', 'kept', 'nonbone'):
        glb = seed(clean, folder / ('%s.glb' % defect), defect)
        passed, line, _ = verify(pilot, glb, base, has_table=True)
        print(line.replace('PILOT_CLIPS: FAIL %s:' % pilot, 'PILOT_CLIPS: FAIL selftest-%s:' % defect)
              if not passed else 'PILOT_CLIPS: SELFTEST MISSED %s (%s)' % (defect, line))
        ok = ok and not passed
    passed, line, info = verify(pilot, clean, base, has_table=True)
    print(line.replace('PASS %s' % pilot, 'PASS selftest-clean'))
    ok = ok and passed
    (folder / 'clean-verify.json').write_text(json.dumps(info, indent=2, default=str) + '\n')
    print('PILOT_CLIPS_SELFTEST: %s (%s)' % ('PASS' if ok else 'FAIL', folder))
    return ok


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('pilot', nargs='?')
    parser.add_argument('--baseline')
    parser.add_argument('--glb')
    parser.add_argument('--evidence')
    parser.add_argument('--selftest', action='store_true')
    # Reads the GLB as if roster.json said has_table true (the transitional rule's other branch).
    parser.add_argument('--assume-table', action='store_true')
    args = parser.parse_args(argv)
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    if not args.pilot:
        parser.error('a pilot or --selftest')
    data = roster()
    glb = Path(args.glb) if args.glb else SKETCH / data['pilots'][args.pilot]['glb']
    passed, line, info = verify(args.pilot, glb, Path(args.baseline) if args.baseline else None,
                                has_table=True if args.assume_table else None)
    folder = Path(args.evidence) if args.evidence else EVIDENCE / args.pilot
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'verify.json').write_text(json.dumps(info, indent=2, default=str) + '\n')
    print('PILOT_CLIPS: clip set %s' % info.get('clips'))
    if info.get('not_checked'):
        print('PILOT_CLIPS: NOTE not checked yet: %s' % ', '.join(info['not_checked']))
    print(line)
    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
