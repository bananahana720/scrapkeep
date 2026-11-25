"""Cycles CPU evidence. Presentation fixtures are never exported as game assets.

Three arena-scale views beside a 2 m ball, one pose per exported clip,
and the maximum-density wake crossing a committed threat fixture.
Paints use a dimensioned SPIL-9 proxy because the companion unit owns its GLB.
Decals are composed in the material of a 2 m shell fixture, with zero sticker mesh.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_cua as cua
import cycles_device

ROOT = cua.SKETCH.parents[1]
ASSETS = cua.SKETCH/"assets/cosmetics"
OUT = ROOT/"artifacts/local/dress-preview/CUA"


def material(name,tint):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = cua.common.rgba(tint)
    p.inputs["Roughness"].default_value = .8
    return mat


def sphere(name,loc,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=1,location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def ball(decal=None):
    obj = sphere("ReferenceBall_2m",(0,0,1),(1,1,1),material("reference_enamel","365754"))
    if decal is not None:
        ident,tint,(w,h) = cua.DECALS[decal]
        tile,_ = cua.decal_shape(decal)
        entry = json.loads((ASSETS/"cua_manifest.json").read_text())["decals"][decal]
        w,h = entry["tile_size_m"]
        bx,by,bw,bh = entry["mask_bounds_px"]
        u0,v0 = (bx+bw/2)/256,1-(by+bh/2)/256
        path = OUT/"fixtures"/(ident+"_composed.png")
        cua.png(path,tile)
        mat = material("ShellPaint_Composed_DecalMask","365754")
        nodes,links = mat.node_tree.nodes,mat.node_tree.links
        p = nodes.get("Principled BSDF")
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(path))
        image.extension = "CLIP"
        uv = obj.data.uv_layers.new(name="DecalMask")
        for face in obj.data.polygons:
            for loop in face.loop_indices:
                v = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                uv.data[loop].uv = (u0+v.x/w,v0+(v.z+.30)/h) if face.center.y < -.45 else (2,2)
        coords = nodes.new("ShaderNodeUVMap")
        coords.uv_map = "DecalMask"
        links.new(coords.outputs["UV"],image.inputs["Vector"])
        mix = nodes.new("ShaderNodeMixRGB")
        mix.inputs[1].default_value = cua.common.rgba("365754")
        links.new(image.outputs["Alpha"],mix.inputs[0])
        links.new(image.outputs["Color"],mix.inputs[2])
        links.new(mix.outputs["Color"],p.inputs["Base Color"])
        obj.data.materials[0] = mat
    sphere("Cockpit_Neutral_Reference",(0,0,1.57),(.57,.57,.38),material("reference_glass_proxy","929995"))
    return obj


def box(name,loc,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("broad_edge","BEVEL")
    bevel.width = .04
    bevel.segments = 1
    return obj


def paint_fixture(index):
    tint = cua.PAINTS[index][1]
    enamel = material("paint",tint)
    rubber = material("rubber","242a28")
    steel = material("bare_metal","929995")
    bone = material("fixed_bone","d2c5a5")
    sphere("Hull_PROXY",(1.70,0,.51),(.55,.36,.21),enamel)
    sphere("Deck_PROXY",(1.70,0,.69),(.49,.30,.04),enamel)
    sphere("LiftPlenum_FIXED",(1.70,0,.34),(.41,.25,.05),rubber)
    for x in (-.29,.29):
        bpy.ops.mesh.primitive_torus_add(major_radius=.12,minor_radius=.02,major_segments=16,minor_segments=4,location=(1.70+x,0,.735))
        bpy.context.object.data.materials.append(bone)
        for angle in (0,120,240):
            a = math.radians(angle)
            box("SocketLug_FIXED",(1.70+x+.13*math.cos(a),.13*math.sin(a),.755),(.035,.035,.045),steel)
    box("ServiceBrow_FIXED",(1.70,-.36,.54),(.26,.04,.12),rubber)
    box("EscapeWitness_FIXED",(1.70,-.39,.54),(.14,.025,.07),bone)
    for angle in (0,90,180,270):
        a = math.radians(angle)
        box("Bumper_FIXED",(1.70+.47*math.cos(a),.29*math.sin(a),.44),(.16,.11,.08),rubber)


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 8
    scene.cycles.use_denoising = True
    scene.cycles.seed = 71
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 720
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("CPU_studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.55,.60,.65,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .65
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001))
    bpy.context.object.data.materials.append(material("floor","929995"))
    light = bpy.data.lights.new("large_sky","AREA")
    light.energy,light.size = 500,8
    obj = bpy.data.objects.new("large_sky",light)
    bpy.context.collection.objects.link(obj)
    obj.location = (1,-3,7)
    cam = bpy.data.objects.new("CPU_camera",bpy.data.cameras.new("CPU_camera"))
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "PERSP"
    cam.data.lens = 48
    return cam


def render(cam,path,view,target=(.30,-.30,.55)):
    views = {"front":(4,-7,4.5),"side":(7,-2.5,3.2),"high":(3.0,-3.5,7.5)}
    cam.location = views[view]
    cam.rotation_euler = (Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler()
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def import_trail(index,pose=False,count=24):
    ident,node,_,_,duration,_ = cua.TRAILS[index]
    bpy.ops.import_scene.gltf(filepath=str(ASSETS/"trails"/(ident+".glb")))
    root = bpy.data.objects["BallTrail"]
    obj = bpy.data.objects[node]
    bpy.context.scene.render.fps = 120
    bpy.context.scene.frame_set(1+round(duration*120*.4) if pose else 1)
    root.location = (0,-1.04,.04)
    for i in range(1,count):
        cp = obj.copy()
        cp.data = obj.data
        cp.animation_data_clear()
        bpy.context.collection.objects.link(cp)
        cp.location.y -= i*(1.8-.17)/(count-1)
        cp.location.x += .10*math.sin(i*.91)
        age = i/count
        cp.scale *= max(.001,1-age*.7)
    return root,obj


def main():
    arg = argparse.ArgumentParser()
    arg.add_argument("--kind",choices=["all","trails","decals","paints"],default="all")
    cli = arg.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True)
    records = []
    for kind,rows in [("trails",cua.TRAILS),("decals",cua.DECALS),("paints",cua.PAINTS)]:
        if cli.kind not in ("all",kind):
            continue
        records = []
        for index,row in enumerate(rows):
            ident = row[0]
            cua.common.reset()
            ball(index if kind=="decals" else None)
            if kind=="paints":
                paint_fixture(index)
            if kind=="trails":
                import_trail(index)
            cam = studio()
            paths = []
            for view in ("front","side","high"):
                path = OUT/(ident+"_"+view+".png")
                render(cam,path,view)
                paths.append(path.name)
            if kind=="trails":
                clip = row[5]
                bpy.context.scene.frame_set(1+round(row[4]*120*.4))
                path = OUT/(ident+"_"+clip+"_key.png")
                render(cam,path,"front")
                paths.append(path.name)
                hazard = material("THREAT_FIXTURE_not_cosmetic","ff5a3c")
                box("Committed_Threat_Footprint",(0,-1.9,.01),(.80,1.20,.012),hazard)
                box("Threat_Tool",(.45,-1.8,.38),(.12,.12,.75),hazard)
                path = OUT/(ident+"_threat_24cards.png")
                render(cam,path,"front")
                paths.append(path.name)
            records.append({"id":ident,"images":paths,"reference_ball_diameter_m":2,
                "engine":"Cycles","device":bpy.context.scene.cycles.device,"samples":8,
                "fixture":"imported trail GLB" if kind=="trails" else "material-only shell fixture" if kind=="decals" else "dimensioned companion proxy; not companion GLB"})
            (OUT/("preview_"+kind+".json")).write_text(json.dumps(records,indent=2)+"\n")
            print("CUA_PREVIEW",ident,"PASS",flush=True)
    print("CUA_PREVIEWS: PASS",flush=True)


if __name__=="__main__":
    main()
