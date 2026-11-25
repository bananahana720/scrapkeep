"""Reimported GLB evidence at the resting gameplay chase camera, 1080p/30 fps."""
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import rig_pilot as rig
import common
import pilot_drop_timing as timing
OUT=rig.ROOT/'artifacts/anim-pilot/retime'


def main():
    args=sys.argv[sys.argv.index('--')+1:]
    pilot,version=args[:2]
    bpy.ops.wm.open_mainfile(filepath=str(OUT/pilot/f'{pilot}-drop.blend'))
    manifest=json.loads((OUT/pilot/'rig-manifest.json').read_text())
    for obj in list(bpy.data.objects):
        if obj.type=='ARMATURE' or obj.name in manifest['mesh_nodes']:
            bpy.data.objects.remove(obj,do_unlink=True)
        else:
            obj.hide_render=False
    glb=(OUT/'baseline'/f'pilot_{pilot}_anim.glb' if version=='old'
         else HERE.parents[1]/f'assets/models/pilot_{pilot}_anim.glb')
    bpy.ops.import_scene.gltf(filepath=str(glb))
    scene=bpy.context.scene
    cam=rig.studio()
    target=Vector((0,0,.8))
    cam.location=target+Vector((0,-7.5*math.cos(.30),7.5*math.sin(.30)))
    common._look(cam,target)
    cam.data.type='PERSP'
    cam.data.sensor_fit='VERTICAL'
    cam.data.angle=math.radians(65)
    scene.render.resolution_x=1920
    scene.render.resolution_y=1080
    scene.render.fps=30
    scene.cycles.samples=6
    scene.render.threads=4
    scene.render.film_transparent=True
    scene.render.image_settings.color_mode='RGBA'
    scene.render.use_border=True
    scene.render.use_crop_to_border=True
    scene.render.border_min_x=.4
    scene.render.border_max_x=.6
    scene.render.border_min_y=.25
    scene.render.border_max_y=.55
    folder=OUT/pilot/(version+'-chase')
    folder.mkdir(exist_ok=True)
    count=34 if version=='old' else timing.FRAMES[pilot][-1]
    frames=[0] if '--draft' in args else list(range(count))
    arm=next(o for o in scene.objects if o.type=='ARMATURE')
    cache={}
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        signature=tuple(round(v,7) for b in arm.pose.bones for row in b.matrix for v in row)
        dest=folder/f'{frame:04}.png'
        if signature in cache:
            if dest.exists():dest.unlink()
            dest.symlink_to(cache[signature].name)
        else:
            scene.render.filepath=str(dest)
            bpy.ops.render.render(write_still=True)
            cache[signature]=dest
    if '--draft' not in args and version=='new':
        for beat,frame in timing.receipt(pilot)['beat_samples'].items():
            f=frame-1
            scene.frame_set(int(f),subframe=f%1)
            scene.render.filepath=str(folder/f'hold-{beat}.png')
            bpy.ops.render.render(write_still=True)
    (folder/'render.json').write_text(json.dumps({
        'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),
        'resolution':[1920,1080],'fps':30,'frames':len(frames),
        'render_border_pixels':[768,486,1152,810],
        'border_reconstruction':'Composite RGBA at original pixels; no scaling or camera change',
        'camera_arm':7.5,'camera_pitch':-.30,'vertical_fov_degrees':65,
        'camera_position':list(cam.location),'camera_target':list(target),
        'method':'actual exported GLB reimport with original cockpit shell; idle chase parameters',
        'engine':'Cycles','samples':6,'threads':4,
        'unique_animation_frames_rendered':len(cache),
        'hold_samples_blender_frames':timing.receipt(pilot)['beat_samples'] if version=='new' else {},
        'limitations':'No game background, speed FOV, camera shake or moving threats; rear glass retained.'
    },indent=2)+'\n')


if __name__=='__main__':main()
