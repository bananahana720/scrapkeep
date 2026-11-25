"""Reimported GLB chase evidence; CPU Cycles, serial render, native 1080p pixels."""
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rig_pilot as rig
import common
import cycles_device
from anim_pilot_reactions import KEYS

OUT = rig.ROOT / 'artifacts/anim-reactions'


def render(pilot, clip, old=False):
    bpy.ops.wm.open_mainfile(filepath=str(OUT / pilot / f'{pilot}-reactions.blend'))
    manifest = json.loads((OUT / pilot / 'rig-manifest.json').read_text())
    for obj in list(bpy.data.objects):
        if obj.type == 'ARMATURE' or obj.name in manifest['mesh_nodes']:
            bpy.data.objects.remove(obj, do_unlink=True)
        else:
            obj.hide_render = False
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    glb = (OUT / 'baseline' if old else HERE.parents[1] / 'assets/models') / f'pilot_{pilot}_anim.glb'
    bpy.ops.import_scene.gltf(filepath=str(glb))
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    actions = [a for a in bpy.data.actions if a.name == clip or a.name.startswith(clip + '_')]
    assert len(actions) == 1, (clip, [a.name for a in bpy.data.actions])
    arm.animation_data.action = actions[0]
    if len(actions[0].slots) == 1:
        arm.animation_data.action_slot = actions[0].slots[0]
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    scene = bpy.context.scene
    cam = rig.studio()
    target = Vector((0, 0, .8))
    cam.location = target + Vector((0, -7.5*math.cos(.30), 7.5*math.sin(.30)))
    common._look(cam, target)
    cam.data.type = 'PERSP'
    cam.data.sensor_fit = 'VERTICAL'
    cam.data.angle = math.radians(65)
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.fps = 30
    cycles_device.use(scene)
    scene.cycles.samples = 6
    scene.render.threads = 4
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.use_border = scene.render.use_crop_to_border = True
    scene.render.border_min_x, scene.render.border_max_x = .4, .6
    scene.render.border_min_y, scene.render.border_max_y = .25, .55
    folder = OUT / pilot / (clip + ('-old' if old else '') + '-chase')
    folder.mkdir(exist_ok=True)
    start, end = actions[0].frame_range
    count = round(end-start)+1
    expected = (67 if pilot == 'kest' else 66) if clip == 'drop_land' else KEYS[clip][-1]
    assert count == expected, (pilot, clip, count, expected)
    cache = {}
    for frame in range(count):
        scene.frame_set(round(start)+frame)
        bpy.context.view_layer.update()
        signature = tuple(round(v, 7) for bone in arm.pose.bones for row in bone.matrix for v in row)
        dest = folder / f'{frame:04}.png'
        if signature in cache:
            if dest.exists():
                dest.unlink()
            dest.symlink_to(cache[signature].name)
        else:
            scene.render.filepath = str(dest)
            bpy.ops.render.render(write_still=True)
            cache[signature] = dest
    (folder / 'render.json').write_text(json.dumps({
        'pilot': pilot, 'clip': clip, 'glb_sha256': hashlib.sha256(glb.read_bytes()).hexdigest(),
        'frames': count, 'fps': 30, 'seconds': (count-1)/30, 'resolution': [1920,1080],
        'crop_pixels': [768,486,1152,810], 'camera_arm': 7.5, 'pitch': -.30, 'vertical_fov': 65,
        'method': 'exported GLB reimport, original shell and glass, CPU Cycles; no camera enlargement',
        'limits': 'Studio background; not Godot, moving threats, speed FOV or human acceptance',
    }, indent=2)+'\n')


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--')+1:]
    render(args[0], args[1], '--old' in args)
