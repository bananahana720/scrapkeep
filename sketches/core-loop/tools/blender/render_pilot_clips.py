"""Strip evidence per pilot clip (design-v3/PILOT-CLIPS.md section 7.1).

  blender --background --python-exit-code 1 --python render_pilot_clips.py -- <pilot> [--clip <name>] [--device auto|CPU|CUDA]

Imports the shipped pilot GLB and the pilot's shell GLB (paths from
src/presentation/clips/roster.json), seats the pilot at identity under the shell's Pod, and
renders from the reimported bytes, as render_pilot_reactions.py does. For each clip it writes
<clip>.png: row 1 the resting chase camera (7.5-unit arm, 65-degree vertical field of view,
pitch -0.30, anchor height 0.8, Core visible), row 2 a three-quarter front close-up (2.6 m,
35 degrees, Core hidden); five cells per row at the pose table's distinct beats for every clip
(or evenly spaced without enough beats), each 480 by 384 px with a label band (clip,
frame, seconds) drawn by the render stamp. sheet.png holds every rendered clip's chase cell at
its middle beat. Output: artifacts/local/alpha/push/w13/clips/<pilot>/ (or --out, which must sit under that clips folder).

Not built here: the per-clip mp4 (section 7.1 "Video"); the pilot units add it with their strips.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE))
import common
import cycles_device

ROSTER = SKETCH / 'src/presentation/clips/roster.json'
TABLES = SKETCH / 'src/presentation/clips'
EVIDENCE = ROOT / 'artifacts/local/alpha/push/w13/clips'
FPS = 30
CELL_W, CELL_H = 480, 384
SHEET_COLUMNS = 6


def args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('pilot')
    parser.add_argument('--clip')
    parser.add_argument('--device', default='auto', choices=['auto', 'CPU', 'CUDA'])
    parser.add_argument('--samples', type=int, default=16)
    parser.add_argument('--out')
    return parser.parse_args(argv)


def out_dir(pilot, out):
    """The strip folder: --out must resolve inside the clips evidence folder, so a render never
    writes over tracked files or another checkout's workspace."""
    folder = (Path(out) if out else EVIDENCE / pilot).resolve()
    root = EVIDENCE.resolve()
    if folder != root and root not in folder.parents:
        raise SystemExit('RENDER_PILOT_CLIPS: refused --out %s: it must sit under %s' % (folder, root))
    return folder


def setup(device, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    if device == 'CUDA':
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'CUDA'
        prefs.get_devices()
        for dev in prefs.devices:
            dev.use = dev.type == 'CUDA'
        scene.cycles.device = 'GPU'
    elif device == 'auto':
        cycles_device.use(scene)
    else:
        scene.cycles.device = 'CPU'
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.fps = FPS
    scene.render.resolution_x, scene.render.resolution_y = CELL_W, CELL_H
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'AgX'
    scene.render.use_stamp = True
    for field in ('date', 'time', 'render_time', 'frame', 'frame_range', 'memory', 'hostname', 'camera', 'lens',
                  'scene', 'marker', 'filename', 'sequencer_strip'):
        if hasattr(scene.render, 'use_stamp_' + field):
            setattr(scene.render, 'use_stamp_' + field, False)
    scene.render.use_stamp_note = True
    scene.render.stamp_font_size = 14
    scene.world = bpy.data.worlds.new('Neutral studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.39, .40, .39, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
    for name, location, energy, size in [('Key', (2, 3, 4), 180, 3), ('Fill', (-3, 1, 1), 100, 3), ('Rim', (1, -3, 3), 180, 2)]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy, data.shape, data.size = energy, 'DISK', size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        common._look(obj, (0, 0, 0))
    cam = bpy.data.objects.new('ClipCamera', bpy.data.cameras.new('ClipCamera'))
    scene.collection.objects.link(cam)
    cam.data.sensor_fit = 'VERTICAL'
    scene.camera = cam
    return cam


def seat(pilot_glb, shell_glb):
    """Imports the shell, then the pilot, and parents the pilot's top objects to Pod at identity.
    Returns (armature, core objects, shell placeholder objects)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(shell_glb))
    shell = set(bpy.data.objects) - before
    pod = next((o for o in shell if o.name.split('.')[0] == 'Pod'), None)
    core = next((o for o in shell if o.name.split('.')[0] == 'Core'), None)
    if pod is None:
        raise SystemExit('render_pilot_clips: %s has no Pod' % shell_glb)
    placeholders = [o for o in shell if o.name.split('.')[0] == 'Pilot']
    for obj in placeholders:
        obj.hide_render = True
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(pilot_glb))
    pilot = set(bpy.data.objects) - before
    arm = next(o for o in pilot if o.type == 'ARMATURE')
    bpy.context.view_layer.update()
    for obj in pilot:
        if obj.parent is None:
            obj.parent = pod
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = Matrix.Identity(4)
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    cores = [core] + list(core.children_recursive) if core is not None else []
    return arm, cores, placeholders


def action_for(clip):
    exact = [a for a in bpy.data.actions if a.name == clip]
    if exact:
        return exact[0]
    loose = [a for a in bpy.data.actions if a.name.startswith(clip + '_')]
    return loose[0] if len(loose) == 1 else None


def clip_frames(clip, action, table, loop):
    """Five 1-based cells: collapse held poses and reserve their first contact beat."""
    start, end = action.frame_range
    last = int(round(end - start)) + 1
    definition = (table or {}).get('clips', {}).get(clip, {})
    contact_frame = definition.get('contact', {}).get('frame')
    beats = []
    previous = None
    for key in sorted(definition.get('keys', []), key=lambda key: key['frame']):
        pose = {field: value for field, value in key.items() if field not in ('frame', 'note')}
        if not beats or pose != previous:
            beats.append({'frame': int(key['frame']), 'contact': False})
        if key['frame'] == contact_frame or key.get('contact') or 'contact' in key.get('note', '').lower():
            beats[-1]['contact'] = True
        previous = pose
    contact = next((beat['frame'] for beat in beats if beat['contact']), None)
    count = 5
    if len(beats) >= count:
        others = [beat['frame'] for beat in beats if beat['frame'] != contact]
        remaining = count - (contact is not None)
        picks = [others[round(i * (len(others) - 1) / (remaining - 1))] for i in range(remaining)]
        if contact is not None:
            picks.append(contact)
    else:
        picks = [1 + round(i * (last - 1) / (count - 1)) for i in range(count)]
        if contact is not None and contact not in picks:
            index = min(range(1, count - 1), key=lambda i: abs(picks[i] - contact))
            picks[index] = contact
    return sorted(picks)


def chase(cam):
    target = Vector((0, 0, .8))
    cam.location = target + Vector((0, -7.5 * math.cos(.30), 7.5 * math.sin(.30)))
    common._look(cam, target)
    cam.data.type = 'PERSP'
    cam.data.angle = math.radians(65)


def close(cam):
    target = Vector((0, 0, -.05))
    yaw = math.radians(35)
    cam.location = target + Vector((2.6 * math.sin(yaw), 2.6 * math.cos(yaw), .55))
    common._look(cam, target)
    cam.data.type = 'PERSP'
    cam.data.angle = math.radians(35)


def render_cell(path, clip, frame):
    scene = bpy.context.scene
    scene.frame_set(frame - 1)
    scene.render.stamp_note_text = '%s  f%d  %.3fs' % (clip, frame, (frame - 1) / FPS)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def load(path):
    path = Path(path)
    image = None
    try:
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError('missing or empty image file')
        image = bpy.data.images.load(str(path))
        size = tuple(image.size)
        if size != (CELL_W, CELL_H):
            raise ValueError('image size %s; expected %s' % (size, (CELL_W, CELL_H)))
        if not image.has_data:
            raise ValueError('image has no decoded pixels')
        pixels = np.empty(CELL_W * CELL_H * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        return pixels.reshape(CELL_H, CELL_W, 4)
    except Exception as error:
        raise RuntimeError('render_pilot_clips: failed cell %s: %s' % (path, error)) from error
    finally:
        if image is not None:
            bpy.data.images.remove(image)


def save(path, grid):
    """grid: rows (top first) of cell arrays; Blender pixels start at the bottom row."""
    height = len(grid) * CELL_H
    width = max(len(row) for row in grid) * CELL_W
    canvas = np.zeros((height, width, 4), dtype=np.float32)
    for r, row in enumerate(grid):
        y = (len(grid) - 1 - r) * CELL_H
        for c, cell in enumerate(row):
            canvas[y:y + CELL_H, c * CELL_W:(c + 1) * CELL_W] = cell
    image = bpy.data.images.new(Path(path).stem, width, height, alpha=True)
    image.pixels.foreach_set(canvas.ravel())
    image.filepath_raw = str(path)
    image.file_format = 'PNG'
    image.save()
    bpy.data.images.remove(image)


def main():
    a = args()
    data = json.loads(ROSTER.read_text())
    row = data['pilots'][a.pilot]
    table_path = TABLES / ('%s.json' % a.pilot)
    table = json.loads(table_path.read_text()) if table_path.exists() else None
    pilot_glb = SKETCH / row['glb']
    shell_glb = SKETCH / row['shell']
    out = out_dir(a.pilot, a.out)
    out.mkdir(parents=True, exist_ok=True)
    cam = setup(a.device, a.samples)
    arm, cores, _ = seat(pilot_glb, shell_glb)
    clips = [a.clip] if a.clip else list(data['kept']) + list(data['new'])
    scratch = Path(tempfile.mkdtemp(prefix='pilot-clips-cells-'))
    sheet = []
    written = []
    for clip in clips:
        action = action_for(clip)
        if action is None:
            print('RENDER_PILOT_CLIPS: %s lacks %s; no strip' % (a.pilot, clip))
            continue
        arm.animation_data.action = action
        if len(action.slots) >= 1:
            arm.animation_data.action_slot = action.slots[0]
        loop = clip in data['loops']
        frames = clip_frames(clip, action, table, loop)
        grid = []
        for camera_row, place, core_on in (('chase', chase, True), ('close', close, False)):
            place(cam)
            for obj in cores:
                obj.hide_render = not core_on
            cells = []
            for frame in frames:
                path = scratch / ('%s-%s-%03d.png' % (clip, camera_row, frame))
                render_cell(path, clip, frame)
                cells.append(load(path))
            grid.append(cells)
        strip = out / ('%s.png' % clip)
        save(strip, grid)
        sheet.append(grid[0][len(frames) // 2])
        written.append({'clip': clip, 'frames': frames, 'png': str(strip), 'sha256': hashlib.sha256(strip.read_bytes()).hexdigest()})
        print('RENDER_PILOT_CLIPS: %s %s frames %s -> %s' % (a.pilot, clip, frames, strip))
    if not written:
        raise SystemExit('render_pilot_clips: no clip rendered')
    rows = [sheet[i:i + SHEET_COLUMNS] for i in range(0, len(sheet), SHEET_COLUMNS)]
    save(out / 'sheet.png', rows)
    receipt = {'pilot': a.pilot, 'device': bpy.context.scene.cycles.device if a.device == 'auto' else a.device, 'samples': a.samples,
               'pilot_glb_sha256': hashlib.sha256(pilot_glb.read_bytes()).hexdigest(),
               'shell_glb_sha256': hashlib.sha256(shell_glb.read_bytes()).hexdigest(),
               'strips': written, 'sheet': str(out / 'sheet.png')}
    (out / 'render.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('RENDER_PILOT_CLIPS: %d strips and sheet.png in %s' % (len(written), out))


if __name__ == '__main__':
    main()
