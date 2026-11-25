"""Render the exported GLBs, synchronised, on three rotating display roots."""
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import common
import rig_pilot as rig
OUT=rig.ROOT/'artifacts/anim-pilot'

def main():
    common.reset()
    scene=bpy.context.scene
    scene.render.fps=30
    roots=[];sources={}
    for pilot,x in [('rivet',2.0),('sable',0),('kest',-2.0)]:
        path=HERE.parents[1]/f'assets/models/pilot_{pilot}_anim.glb'
        sources[pilot]=hashlib.sha256(path.read_bytes()).hexdigest()
        before=set(scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        new=set(scene.objects)-before
        root=common.empty(pilot.title()+'Display')
        for obj in new:
            if obj.parent not in new:obj.parent=root
        root.location.x=x
        roots.append(root)
    cam=rig.studio()
    cam.location=(0,8,1.0)
    common._look(cam,(0,0,0))
    cam.data.ortho_scale=6.1
    scene.render.resolution_x=1280
    scene.render.resolution_y=540
    scene.cycles.samples=8
    scene.render.threads=8
    frames=OUT/'trio-frames'
    frames.mkdir(exist_ok=True)
    count=204
    chosen=[0,8,14,21,51,102,153,203]
    cached={}
    if '--resume' in sys.argv:
        receipt=json.loads((OUT/'shared/trio-resume-inputs.json').read_text())
        assert receipt['sources']==sources, 'GLB changed; cached frames are stale'
        assert receipt['profile']=={'frames':count,'fps':30,'resolution':[1280,540],'samples':8}
        cached=receipt['cached_frames']
    for f in (chosen if '--draft' in sys.argv else range(count)):
        dest=frames/f'{f:04}.png'
        if dest.name in cached:
            assert hashlib.sha256(dest.read_bytes()).hexdigest()==cached[dest.name],dest
            continue
        scene.frame_set(f%34)
        for root in roots:root.rotation_euler.z=math.tau*f/(count-1)
        scene.render.filepath=str(frames/f'{f:04}.png')
        bpy.ops.render.render(write_still=True)
    if '--draft' in sys.argv:return
    labels="drawtext=text='RIVET':fontcolor=white:fontsize=22:x=w/6-tw/2:y=h-36,drawtext=text='SABLE':fontcolor=white:fontsize=22:x=w/2-tw/2:y=h-36,drawtext=text='KEST':fontcolor=white:fontsize=22:x=5*w/6-tw/2:y=h-36"
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2',
        '-framerate','30','-start_number','0','-i',str(frames/'%04d.png'),'-frames:v',str(count),
        '-vf',labels,'-c:v','libx264','-threads','2','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
        str(OUT/'trio_drop_land.mp4')],check=True)
    (OUT/'shared/trio-render.json').write_text(json.dumps({'source_glb_sha256':sources,
        'method':'Blender reimport of final GLBs; six synchronised 34-frame action repeats and one full display rotation',
        'frames':count,'fps':30,'seconds':count/30,'resolution':[1280,540],
        'frame_mapping':'scene frame = video frame modulo 34; action at 0..33 after glTF reimport',
        'root_rotation_is_evidence_only':True,'render_threads':8,'reused_frames':len(cached)},indent=2)+'\n')

if __name__=='__main__':main()
