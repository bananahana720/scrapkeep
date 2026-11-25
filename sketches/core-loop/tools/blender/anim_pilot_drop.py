"""Shared image-led pilot animation. Cached images are immutable pose-table inputs.

blender --background --threads 2 --python anim_pilot_drop.py -- sable --author
Normal rebuilds omit --author. --draft renders keys 3,5,8,12; --no-render exports only.
"""
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import rig_pilot as rig
import anim_rivet_drop as shared
import common
FRAMES=shared.FRAMES

SABLE_NOTES=[
    '01: back tail leans left; hands at controls; neutral head.',
    '02: nearly neutral brace; back tail slightly right despite requested left swish.',
    '03: front/side wrists lower beside belly; back arm height disagrees. Follow front/side; tail right.',
    '04: hands back at chin level, compact body, tail centred; side head slightly forward.',
    '05: broad low face and torso, elbows flared, wrists above shoulders. Keep seated legs fixed; no invented fingers.',
    '06: rebounds close to neutral, head and tail upright.',
    '07: high forward tool point in front/side; BACK MIRRORS ARM. Preserve anatomical right.',
    '08: right arm extended forward at shoulder height, left at control; tool tipped forward.',
    '09: twirl image retracts right wrist beside cheek, with circular motion marks. Encode a wrist/tool turn, no motion-line geometry.',
    '10: both hands near rest; a second tool outline implies twirl completion.',
    '11: head tilts left; right ear flicks outward; slight right wrist dip.',
    '12: right ear folded low outward/backward; BACK MIRRORS EAR. Front/side chosen; whole-ear hinge approximates fold.',
    '13: right ear upright overshoot, level head and controls; ignore motion marks.',
    '14: soft dip, centered ears and near-neutral tail.', '15: reference proportions nearly restored; controls level.', '16: neutral identity pose; exact rig rest chosen over small generated drift.',
]


def rotate(arm,name,xyz):
    arm.pose.bones[name].rotation_euler=tuple(math.radians(v) for v in xyz)


def body(arm,pitch,head,body_z,head_z,neck_z=0):
    rotate(arm,'spine_01',(pitch*.55,0,0))
    rotate(arm,'spine_02',(pitch*.45,0,0))
    rotate(arm,'head',(head,0,0))
    arm.pose.bones['spine_01'].scale=(1+(1-body_z)*.20,1,body_z)
    arm.pose.bones['spine_02'].scale.z=body_z
    arm.pose.bones['neck'].location.z=neck_z
    arm.pose.bones['head'].scale=((1+(1-head_z)*.4)/(1+(1-body_z)*.2),1,head_z/(body_z*body_z))
    bpy.context.view_layer.update()


def sable_pose(arm,k):
    pitches=[0,-3,-6,-8,-3,0,2,2,1,0,0,0,0,-3,-1,0]
    heads=[0,-3,-7,-7,-3,0,2,1,0,0,0,2,0,-3,-1,0]
    heights=[1,.98,.95,.93,.77,1.02,1.06,1.07,1.04,1.02,1,1,1.01,.98,1,1]
    hz=[1,1,.98,.97,.78,1,1,1,1,1,1,1,1,1,1,1]
    body(arm,pitches[k-1],heads[k-1],heights[k-1],hz[k-1],-.025 if k==5 else 0)
    tail=[-22,18,34,0,-6,5,0,0,0,0,-4,4,-3,2,0,0][k-1]
    rotate(arm,'tail.01',(0,0,tail))
    rotate(arm,'tail.02',(0,0,-tail*.35))
    right=(.32,.4,.05);left=(-.32,.4,.05)
    if k==3: right=(.32,.40,-.11);left=(-.32,.40,-.11)
    if k==5: right=(.49,.28,.05);left=(-.49,.28,.05)
    if k==7: right=(.32,.50,.24)
    if k==8: right=(.32,.59,.13)
    if k==9: right=(.32,.44,.14)
    if k==10: right=(.32,.42,.07)
    if k==11: right=(.32,.40,.01)
    if k!=16:
        shared.solve_arm(arm,'R',right,1.25 if k in (7,8) else 1)
        shared.solve_arm(arm,'L',left)
        shared.world_hand(arm,'R',(0,0,0))
        shared.world_hand(arm,'L',(0,0,0))
    if k in (2,3,4):
        for side in ('L','R'): rotate(arm,'ear.'+side,(8,0,0))
    if k in (11,12,13):
        arm.pose.bones['head'].rotation_euler.y=math.radians({11:-7,12:-4,13:0}[k])
        rotate(arm,'ear.R',({11:12,12:32,13:-8}[k],{11:27,12:60,13:-12}[k],0))
    tool_pitch={7:-25,8:-50,9:155,10:360}.get(k,360 if k>10 else 0)
    rotate(arm,'tool.R',(tool_pitch,0,0))


def author_table(arm,pilot,out):
    rows=[]
    for key,frame in enumerate(FRAMES,1):
        rig.clear_pose(arm)
        if pilot=='sable':
            sable_pose(arm,key)
            note=SABLE_NOTES[key-1]
        else:
            from pilot_kest_poses import pose, NOTES
            pose(arm,key)
            note=NOTES[key-1]
        assert 'pending' not in note, 'Inspect every ImageGen sheet before authoring'
        bpy.context.view_layer.update()
        image=f'keys/key-{key:02}.png'
        rows.append({'key':key,'frame':frame,'image':image,
                     'image_sha256':hashlib.sha256((out/image).read_bytes()).hexdigest(),
                     'observation':note,'bones':{b.name:{
                         'rotation_degrees_xyz':[round(math.degrees(v),6) for v in b.rotation_euler],
                         'location':[round(v,6) for v in b.location],
                         'scale':[round(v,6) for v in b.scale]} for b in arm.pose.bones}})
    (HERE/f'{pilot}-drop-poses.json').write_text(json.dumps({'schema':'pilot-v1','action':'drop_land','fps':30,
        'space':'bone-local XYZ; Blender +Y forward, +Z up, +X anatomical right','rows':rows},indent=2)+'\n')
    return rows


def check(arm,meshes,rows,out,pilot=None):
    scene=bpy.context.scene
    anchor=arm.data.bones['pelvis'].head_local
    radius=0; drift=0; worst=None
    end = scene.frame_end
    for half in range(2,end*2+1):
        frame=half/2
        scene.frame_set(int(frame),subframe=frame%1)
        bpy.context.view_layer.update()
        drift=max(drift,(arm.pose.bones['pelvis'].head-anchor).length)
        dg=bpy.context.evaluated_depsgraph_get()
        for obj in meshes:
            evaluated=obj.evaluated_get(dg); mesh=evaluated.to_mesh()
            r=max((evaluated.matrix_world@v.co).length for v in mesh.vertices)
            if r>radius: radius=r;worst={'frame':frame,'mesh':obj.name}
            evaluated.to_mesh_clear()
    assert drift<1e-6,drift
    assert radius<.98,(radius,worst)
    for obj in meshes:
        assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in obj.data.vertices)
    scene.frame_set(end)
    grips={s:(arm.pose.bones['hand.'+s].head-Vector((sign*.32,.4,.05))).length for s,sign in [('R',1),('L',-1)]}
    assert max(grips.values())<1e-6,grips
    report={'action':'drop_land','fps':30,'duration_seconds':(end-1)/30,'key_frames':[r['frame'] for r in rows],'samples':end*2-1,
            'pelvis_max_drift':drift,'max_vertex_radius':radius,'worst_radius_sample':worst,'hull_radius':.98,
            'settle_grip_error':grips,'bones':len(arm.data.bones),'triangles':sum(common.tris(o) for o in meshes),
            'mesh_nodes':[o.name for o in meshes],'rig_node':arm.name,'all_vertices_rigid_weighted':True}
    if (pilot or out.name)=='kest':
        from pilot_kest_poses import contact, FEATHER_TIP
        scene.frame_set(rows[11]['frame'])
        bpy.context.view_layer.update()
        b=arm.pose.bones['hand.R']
        tip=b.matrix@b.bone.matrix_local.inverted()@FEATHER_TIP
        report['preen_contact_error']=(tip-contact(arm)).length
        assert report['preen_contact_error']<.005,report['preen_contact_error']
    (out/'animation-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


def export(arm,meshes,pilot):
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm,*meshes]:obj.select_set(True)
    bpy.context.view_layer.objects.active=arm
    dest=HERE.parents[1]/f'assets/models/pilot_{pilot}_anim.glb'
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,
        export_frame_range=True,export_force_sampling=True,export_def_bones=False,
        export_skins=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    rig.common.canonical_indices(str(dest),vertices=rig.common.POLISH is not None)
    return dest


def render(arm,meshes,root,rows,out,pilot,draft=False):
    cam=rig.studio();scene=bpy.context.scene
    scene.render.resolution_x=scene.render.resolution_y=400
    scene.cycles.samples=12
    tag=next((v.split('=',1)[1] for v in sys.argv if v.startswith('--render-tag=')), 'draft' if draft else 'results')
    target=out/tag
    target.mkdir(exist_ok=True)
    for row in rows:
        if draft and row['key'] not in (3,5,8,12): continue
        scene.frame_set(row['frame'])
        for view in ('front','back','side'):
            rig.render_view(cam,target/f'key-{row["key"]:02}-{view}.png',view,1.9)
    if draft:return
    subprocess.run(['python',str(HERE/'compose_pilot_evidence.py'),'--pilot',pilot,'--folder','results'],check=True)
    subprocess.run(['python',str(HERE/'compose_pilot_evidence.py'),'--pilot',pilot,'--keys-sheet'],check=True)
    for obj in common.tree(root):obj.hide_render=False
    root.hide_render=False
    movie=out/'movie-frames';movie.mkdir(exist_ok=True)
    scene.render.resolution_x=720;scene.render.resolution_y=540;scene.cycles.samples=8
    for frame in range(1,35):
        scene.frame_set(frame)
        rig.render_view(cam,movie/f'{frame:04}.png','chase',2.5)
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2','-framerate','30',
        '-start_number','1','-i',str(movie/'%04d.png'),'-frames:v','34','-c:v','libx264','-threads','2',
        '-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'drop_land.mp4')],check=True)


def main():
    args=sys.argv[sys.argv.index('--')+1:]
    pilot=args[0];assert pilot in ('rivet','sable','kest')
    if '--retime' in args:
        import pilot_drop_timing as timing
        out=rig.ROOT/'artifacts/anim-pilot/retime'/pilot
        arm,meshes,root=rig.build(pilot,out=out)
        reference=rig.ROOT/'artifacts/anim-pilot'/(pilot if pilot!='rivet' else '')
        rows=json.loads((HERE/f'{pilot}-drop-poses.json').read_text())['rows']
        timing.action(arm,rows,pilot,reference,shared.apply_row)
        timed=[dict(row,frame=frame) for row,frame in zip(rows,timing.FRAMES[pilot])]
        max_error=0
        for row in timed:
            bpy.context.scene.frame_set(row['frame'])
            for name,pose in row['bones'].items():
                bone=arm.pose.bones[name]
                for actual,expected in ((bone.rotation_euler,[math.radians(v) for v in pose['rotation_degrees_xyz']]),
                                        (bone.location,pose['location']),(bone.scale,pose['scale'])):
                    max_error=max(max_error,max(abs(a-b) for a,b in zip(actual,expected)))
        assert max_error<1e-5,max_error
        report=timing.receipt(pilot)
        report['max_authored_bone_value_error']=max_error
        (out/'timing.json').write_text(json.dumps(report,indent=2)+'\n')
        check(arm,meshes,timed,out,pilot)
        export(arm,meshes,pilot)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{pilot}-drop.blend'))
        return
    assert pilot in ('sable','kest')
    arm,meshes,root=rig.build(pilot)
    out=rig.OUT;shared.OUT=out
    rows=author_table(arm,pilot,out) if '--author' in args else json.loads((HERE/f'{pilot}-drop-poses.json').read_text())['rows']
    shared.action(arm,rows)
    check(arm,meshes,rows,out)
    export(arm,meshes,pilot)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{pilot}-drop.blend'))
    if '--no-render' not in args:render(arm,meshes,root,rows,out,pilot,'--draft' in args)

if __name__=='__main__':main()
