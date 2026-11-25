"""CPU-only Cycles previews of the actual GLBs and manifest assemblies.

blender -b --threads 2 --python-exit-code 1 -P .../preview.py -- --all
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Matrix, Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import kit
import cycles_device

OUT=kit.SKETCH.parents[1]/"artifacts/local/dress-preview/MDM"


def local_transform(row):
    x,y,z=[math.radians(v) for v in row.get("rotation_degrees",[0,0,0])]
    rot=Matrix.Rotation(y,4,"Y") @ Matrix.Rotation(x,4,"X") @ Matrix.Rotation(z,4,"Z")
    scale=Matrix.Diagonal(Vector((*row.get("scale",[1,1,1]),1)))
    loc=Matrix.Translation(Vector(row.get("position",[0,0,0])))
    world=Matrix.Diagonal(Vector((*row.get("assembly_scale",[1,1,1]),1)))
    return world @ loc @ rot @ scale


def load_component(name,row=None):
    before=set(bpy.data.objects)
    path=kit.MODELS/(name+".glb")
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in bpy.data.objects if o not in before]
    roots=[o for o in objects if o.parent is None]
    if row:
        frame=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
        transform=frame @ local_transform(row) @ frame.inverted()
        for root in roots:
            root.matrix_world=transform @ root.matrix_world
    return [o for o in objects if o.type=="MESH"]


def matte(name,color,roughness=1):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value=kit.common.rgba(color)
    bsdf.inputs["Roughness"].default_value=roughness
    return mat


def render(name,manifest):
    kit.common.reset()
    if name in manifest["assemblies"]:
        meshes=[]
        for row in manifest["assemblies"][name]["instances"]:
            meshes += load_component(row["file"].removesuffix(".glb"),row)
    else:
        meshes=load_component(name)
    bpy.context.view_layer.update()
    corners=[o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    asset_points=list(corners)
    lo=Vector(tuple(min(v[k] for v in corners) for k in range(3)))
    hi=Vector(tuple(max(v[k] for v in corners) for k in range(3)))
    ball_loc=Vector((lo.x-2.6,(lo.y+hi.y)/2,lo.z+1))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=ball_loc)
    ball=bpy.context.object
    ball.name="ReferenceBall_2m"
    ball.data.materials.append(matte("reference_ball","a8aaa4",.3))
    for poly in ball.data.polygons:
        poly.use_smooth=True
    bpy.ops.mesh.primitive_plane_add(size=400,location=(0,0,lo.z-.015))
    bpy.context.object.data.materials.append(matte("preview_floor","8b8980"))
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=12
    scene.cycles.use_denoising=True
    scene.cycles.denoising_use_gpu=False
    scene.render.threads_mode="FIXED"
    scene.render.threads=2
    scene.render.resolution_x=640
    scene.render.resolution_y=640
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="Standard"
    scene.world=bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.48,.52,.56,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.6
    sun=bpy.data.lights.new("PreviewSun","SUN")
    sun.energy=2.5
    sun.angle=math.radians(18)
    light=bpy.data.objects.new("PreviewSun",sun)
    scene.collection.objects.link(light)
    light.rotation_euler=(math.radians(28),math.radians(-25),math.radians(-30))
    cam=bpy.data.objects.new("PreviewCamera",bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera=cam
    cam.data.type="ORTHO"
    cam.data.clip_end=2000
    subject_dir=OUT/name
    subject_dir.mkdir(parents=True,exist_ok=True)
    for label,direction in [("front",(0,1,.18)),("side",(1,0,.18)),("three-quarter",(1,1,.65))]:
        d=Vector(direction).normalized()
        cam.rotation_euler=(-d).to_track_quat("-Z","Y").to_euler()
        basis=cam.rotation_euler.to_matrix()
        right=basis @ Vector((1,0,0))
        up=basis @ Vector((0,1,0))
        base=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z+1))
        leftmost=min(v.dot(right) for v in asset_points)
        ball.location=base+right*(leftmost-base.dot(right)-2.6)
        bpy.context.view_layer.update()
        corners=asset_points+[ball.matrix_world @ v.co for v in ball.data.vertices]
        rr=[v.dot(right) for v in corners]; uu=[v.dot(up) for v in corners]
        center=sum(corners,Vector())/len(corners)
        center += right*((min(rr)+max(rr))/2-center.dot(right))
        center += up*((min(uu)+max(uu))/2-center.dot(up))
        scale=max(max(rr)-min(rr),max(uu)-min(uu))*1.18
        cam.data.ortho_scale=max(scale,3.6)
        cam.location=center+d*max(scale*3,40)
        scene.render.filepath=str(subject_dir/(label+".png"))
        bpy.ops.render.render(write_still=True)
    print("MDM_PREVIEW",name,"CPU",scene.cycles.samples,"samples, three views, 2m ball")


def main():
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument("--all",action="store_true")
    parser.add_argument("--subject",action="append")
    parser.add_argument("--tag",default="verified")
    args=parser.parse_args(argv)
    global OUT
    OUT=OUT/args.tag
    manifest=json.loads((kit.MODELS/"manifest.json").read_text())
    subjects=args.subject or (list(manifest["assets"])+list(manifest["assemblies"]) if args.all else [])
    if not subjects:
        parser.error("use --all or --subject BASENAME")
    for name in subjects:
        render(name,manifest)
    OUT.mkdir(parents=True,exist_ok=True)
    metadata={"blender":bpy.app.version_string,"engine":"Cycles","device":bpy.context.scene.cycles.device,"denoising_use_gpu":False,"samples":12,"threads":2,"views":["front","side","three-quarter"],"reference_ball_diameter_m":2,
              "subjects":subjects,"glb_sha256":{n:r["sha256"] for n,r in manifest["assets"].items()},"manifest_sha256":hashlib.sha256((kit.MODELS/"manifest.json").read_bytes()).hexdigest()}
    (OUT/"preview-receipt.json").write_text(json.dumps(metadata,indent=2,sort_keys=True)+"\n")


if __name__=="__main__":
    main()
