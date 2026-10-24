"""CPU-only Cycles previews of the delivered GLBs, never source-only geometry.

blender -b --threads 2 --python-exit-code 1 -P <this file> -- [--asset NAME]
Three arena-scale views and one diagnostic key pose per exported clip, with a
neutral two-metre reference ball. No GPU, shell/pilot substitute, or gameplay proof.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_spil9 as spl
import cycles_device

OUT=spl.SKETCH.parents[1]/"artifacts/local/dress-preview/SPL"


def imported(path):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in bpy.context.scene.objects if o not in before]
    roots=[o for o in objects if o.parent not in objects]
    arm=next((o for o in objects if o.type=="ARMATURE"),None)
    actions={}
    if arm and arm.animation_data:
        for track in arm.animation_data.nla_tracks:
            track.mute=True
            for strip in track.strips:
                actions[track.name]=strip.action
        arm.animation_data.action=None
    return roots,arm,actions


def plain_material(name,color,rough=.8):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    node=mat.node_tree.nodes["Principled BSDF"]
    node.inputs["Base Color"].default_value=(*color,1)
    node.inputs["Roughness"].default_value=rough
    return mat


def studio():
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=8
    scene.cycles.use_denoising=True
    scene.cycles.seed=9
    scene.render.threads_mode="FIXED"
    scene.render.threads=2
    scene.render.resolution_x=800
    scene.render.resolution_y=450
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX"
    world=bpy.data.worlds.new("Neutral arena sky")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.58,.63,.68,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.65
    scene.world=world
    bpy.ops.mesh.primitive_plane_add(size=200)
    bpy.context.object.name="ArenaFloor"
    bpy.context.object.data.materials.append(plain_material("Preview floor",(.20,.22,.225)))
    for name,location,power,size in [("Sky softbox",(-3,4,7),950,5),("Rim softbox",(4,-3,5),700,4)]:
        lamp=bpy.data.lights.new(name,"AREA")
        lamp.energy=power
        lamp.shape="DISK"
        lamp.size=size
        obj=bpy.data.objects.new(name,lamp)
        bpy.context.collection.objects.link(obj)
        obj.location=location
        obj.rotation_euler=(Vector((0,0,.5))-obj.location).to_track_quat("-Z","Y").to_euler()
    cam=bpy.data.objects.new("ArenaCamera",bpy.data.cameras.new("ArenaCamera"))
    bpy.context.collection.objects.link(cam)
    cam.data.type="ORTHO"
    cam.data.ortho_scale=5.8
    scene.camera=cam
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1)
    ball=bpy.context.object
    ball.name="ReferenceBall_2m"
    ball.data.materials.append(plain_material("Reference neutral bone",(.64,.61,.55),.7))
    for face in ball.data.polygons:
        face.use_smooth=True
    return scene,cam,ball


def render_asset(path):
    spl.common.reset()
    source_sha=hashlib.sha256(path.read_bytes()).hexdigest()
    name=path.stem
    module=name in spl.NAMES
    context=[]
    if module:
        context,_,_=imported(spl.OUT/"spil9.glb")
    roots,arm,actions=imported(path)
    scene,cam,ball=studio()
    directory=OUT/name
    directory.mkdir(parents=True,exist_ok=True)
    manifest=[]

    def position(yaw,elevation):
        a=math.radians(yaw)
        horizontal=Vector((math.sin(a),math.cos(a),0))
        right=Vector((math.cos(a),-math.sin(a),0))
        cam.location=horizontal*8+Vector((0,0,elevation))
        target=Vector((0,0,.80))
        cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
        ball.location=right*-1.50+Vector((0,0,1))
        for obj in context:
            obj.location=right*1.05+Vector((0,0,.51))
        for obj in roots:
            obj.location=right*1.05+Vector((0,0,.51+(.225 if module else 0)))
            if module:
                obj.location.x+=.29

    def render(filename,clip=None,fraction=0):
        if arm:
            arm.animation_data_create()
            arm.animation_data.action=None
            for b in arm.pose.bones:
                b.location=(0,0,0)
                b.rotation_euler=(0,0,0)
                b.rotation_quaternion=(1,0,0,0)
                b.scale=(1,1,1)
            if clip:
                act=actions[clip]
                arm.animation_data.action=act
                frame=act.frame_range[0]+fraction*(act.frame_range[1]-act.frame_range[0])
                scene.frame_set(int(frame),subframe=frame%1)
        scene.render.filepath=str(directory/filename)
        bpy.ops.render.render(write_still=True)
        manifest.append({"image":str((directory/filename).relative_to(OUT)),"clip":clip,
                         "key_fraction":fraction,"source_sha256":source_sha})
        print("SPL_PREVIEW",name,filename,flush=True)

    for view,yaw,elev in [("front",0,3.6),("side",90,3.0),("rear",210,5.5)]:
        position(yaw,elev)
        render(view+".png")
    position(0,3.6)
    fractions={"idle":.25,"follow":0,"dock":0,"empty":1,"primer_set":1,
               "primer_consume":.5,"primer_expire":.5,"prow_response":.5,
               "spring_arm":1,"spring_spend":.5,"escape_spent":1,"escape_rearm":1}
    data=path.read_bytes()
    gltf=json.loads(data[20:20+struct.unpack_from("<I",data,12)[0]])
    expected=[a["name"] for a in gltf.get("animations",[])]
    assert set(expected)==set(actions), (name,expected,list(actions))
    for clip in expected:
        render("clip_"+clip+".png",clip,fractions[clip])
    (directory/"preview.json").write_text(json.dumps(manifest,indent=2)+"\n")
    return manifest


def main():
    global OUT
    parser=argparse.ArgumentParser()
    parser.add_argument("--asset")
    parser.add_argument("--out",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    if args.out:
        OUT=args.out
    paths=sorted(spl.OUT.rglob("*.glb"))
    if args.asset:
        paths=[p for p in paths if p.stem==args.asset]
    assert paths
    manifest=[]
    for path in paths:
        manifest.extend(render_asset(path))
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/("preview-index-"+args.asset+".json" if args.asset else "preview-index.json")).write_text(json.dumps(manifest,indent=2)+"\n")
    print("SPL_PREVIEWS",len(paths),"GLBS",len(manifest),"IMAGES CPU CYCLES 8 SAMPLES",flush=True)


if __name__=="__main__":
    main()
