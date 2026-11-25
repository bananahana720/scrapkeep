"""CPU Cycles previews of exported Waking GLBs, never the pre-export meshes.

Invoked by waking.py -- --preview. Images and manifest stay untracked.
Run directly with -- --models PATH --out PATH to render existing exports only.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import waking
import cycles_device


def all_nodes(root):
    return [root]+[child for obj in list(root.children) for child in all_nodes(obj)]


def import_asset(path):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported=set(bpy.context.scene.objects)-before
    roots=[obj for obj in imported if obj.parent is None]
    assert len(roots)==1, (path,roots)
    root=roots[0]
    for obj in imported:
        if obj.animation_data:
            obj.animation_data.action=None
            for track in obj.animation_data.nla_tracks:
                track.mute=True
    bpy.context.scene.frame_set(0)
    return root


def sample(roots,clip=None,seconds=0.0):
    starts=[]
    for root in roots:
        for obj in all_nodes(root):
            if obj.animation_data:
                obj.animation_data.action=None
                for track in obj.animation_data.nla_tracks:
                    track.mute=track.name!=clip
                    if not track.mute:
                        starts.extend(strip.frame_start for strip in track.strips)
    frame=(min(starts) if starts else 0)+seconds*waking.FPS
    bpy.context.scene.frame_set(int(frame),subframe=frame%1)
    bpy.context.view_layer.update()


def flat(name,color):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value=(*color,1)
    bsdf.inputs["Roughness"].default_value=.9
    return mat


def render(models,out,results=None,reuse_static=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=8
    scene.cycles.use_denoising=True
    scene.cycles.seed=17
    scene.render.threads_mode="FIXED"
    scene.render.threads=2
    scene.render.resolution_x=720
    scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.fps=waking.FPS
    scene.view_settings.view_transform="AgX"
    world=bpy.data.worlds.new("Neutral inspection sky")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs[0].default_value=(.18,.21,.24,1)
    world.node_tree.nodes["Background"].inputs[1].default_value=.55
    scene.world=world
    roots=[import_asset(models/name) for name in ("boss_waking_base.glb","boss_waking_kit.glb")]
    rest={obj:obj.matrix_basis.copy() for root in roots for obj in all_nodes(root)}
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=36,depth=.12,location=(0,0,-.06))
    ground=bpy.context.object
    ground.name="PreviewOnly_Arena_radius36"
    ground.data.materials.append(flat("Preview stone",(.22,.20,.17)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(6,0,1))
    ball=bpy.context.object
    ball.name="PreviewOnly_ReferenceBall_2m"
    ball.data.materials.append(flat("Reference bone",(.54,.56,.55)))
    bpy.ops.object.light_add(type="AREA",location=(-12,16,35))
    key=bpy.context.object
    key.data.energy=12000
    key.data.shape="DISK"
    key.data.size=16
    key.rotation_euler=(Vector((0,0,13))-key.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.light_add(type="AREA",location=(10,-10,26))
    fill=bpy.context.object
    fill.data.energy=6500
    fill.data.size=13
    fill.rotation_euler=(Vector((0,0,13))-fill.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add()
    camera=bpy.context.object
    camera.data.type="ORTHO"
    camera.data.ortho_scale=29
    scene.camera=camera
    out.mkdir(parents=True,exist_ok=True)
    frames=[]
    cached={}
    if reuse_static:
        previous=json.loads((reuse_static/"manifest.json").read_text())
        assert previous["renderer"]=="Blender Cycles "+bpy.context.scene.cycles.device and previous["samples"]==8 and previous["resolution"]==[720,900]
        for record in previous["models"]:
            assert hashlib.sha256((models/record["file"]).read_bytes()).hexdigest()==record["sha256"]
        cached={f["image"]:f for f in previous["frames"] if f["clip"] is None and "floor_metres" not in f}

    def reset():
        sample(roots)
        for obj,transform in rest.items():
            obj.matrix_basis=transform.copy()
            obj.hide_render=False
        bpy.context.view_layer.update()
        for obj,transform in rest.items():
            assert max(abs(obj.matrix_basis[r][c]-transform[r][c]) for r in range(4) for c in range(4))<1e-5, "Preview reset drift: "+obj.name

    def view(name):
        if name=="front":
            camera.location=(0,50,13)
            ball.location=(6,0,1)
        elif name=="side":
            camera.location=(50,0,13)
            ball.location=(0,6,1)
        else:
            camera.location=(36,36,17)
            ball.location=(4.5,-4.5,1)
        camera.rotation_euler=(Vector((0,0,12.5))-camera.location).to_track_quat("-Z","Y").to_euler()

    def write(name,assets,clip=None,seconds=0.0,extra=None):
        scene.render.filepath=str(out/(name+".png"))
        path=Path(scene.render.filepath)
        if path.name in cached and clip is None and extra is None:
            source=reuse_static/path.name
            assert hashlib.sha256(source.read_bytes()).hexdigest()==cached[path.name]["sha256"]
            shutil.copy2(source,path)
            print("WAK_PREVIEW_REUSED",path.name,flush=True)
        else:
            bpy.ops.render.render(write_still=True)
        controls={obj.name:{"location":list(obj.location),"scale":list(obj.scale),
                            "quaternion":list(obj.matrix_basis.to_quaternion())}
                  for obj in all_nodes(roots[1]) if obj.name.startswith(("Collar","PressureLip","CoreLive","CoreUnready"))}
        frames.append({"image":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
                       "assets":assets,"clip":clip,"key_seconds":seconds,"controls":controls,**(extra or {})})
        print("WAK_PREVIEW",path.name,flush=True)

    filenames=["boss_waking_base.glb","boss_waking_kit.glb"]
    for angle in ("front","side","three_quarter"):
        reset()
        view(angle)
        write("assembled_"+angle,filenames)
    for index,filename in enumerate(filenames):
        for angle in ("front","side","three_quarter"):
            reset()
            for obj in all_nodes(roots[1-index]): obj.hide_render=True
            view(angle)
            write(Path(filename).stem+"_"+angle,[filename])
        for clip,(_,key_seconds) in waking.CLIPS.items():
            reset()
            sample(roots,clip,key_seconds)
            for obj in all_nodes(roots[1-index]): obj.hide_render=True
            view("three_quarter")
            write(Path(filename).stem+"_"+clip,[filename],clip,key_seconds)
    for clip,(_,key_seconds) in waking.CLIPS.items():
        reset()
        sample(roots,clip,key_seconds)
        view("three_quarter")
        write("assembled_"+clip,filenames,clip,key_seconds)
    for lost,floor in enumerate((12,8,4,0)):
        reset()
        found={obj.name.split(".")[0]:obj for root in roots for obj in all_nodes(root)}
        for anchor in ("CombatSeat","CombatSeatAnchor"):
            found[anchor].location.z=1.6+floor
        span=24-(8.4+floor)
        found["SpineInner"].scale.z=span/15.6
        found["SpineOuter"].scale.z=min(5.6,span*.35)/5.6
        for name in ("CollarSpoil","CollarSeam","CollarBedrock")[:lost]:
            found[name].hide_render=True
        view("three_quarter")
        ball.location.z=1+floor
        if floor==0: sample(roots,"core_open",.4)
        write("floor_%dm"%floor,filenames,extra={"floor_metres":floor,"core_height_metres":floor+6.8})
    manifest={"renderer":"Blender Cycles "+bpy.context.scene.cycles.device,"samples":8,"threads":2,"resolution":[720,900],
              "orthographic_metres":29,"arena_radius_metres":36,"reference_ball_diameter_metres":2,
              "floor_pose_note":"Floor-pose frames stage actor and ball at the real socket heights; raised floor bodies are omitted from this asset-only inspection.",
              "models":[{"file":name,"sha256":hashlib.sha256((models/name).read_bytes()).hexdigest()} for name in filenames],
              "frames":frames,"limits":"Asset and key-pose evidence only; no native game wiring or human acceptance."}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("WAK_PREVIEWS_COMPLETE",len(frames),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--models",type=Path,default=waking.MODELS)
    parser.add_argument("--out",type=Path,default=waking.PREVIEW)
    parser.add_argument("--reuse-static",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    render(args.models,args.out,reuse_static=args.reuse_static)
