import math
import os
import sys
import bmesh
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
from common import Part
common.reset()
for slot, rough, metal in [("device_concrete", 0.95, 0.0), ("device_metal", 0.68, 0.28), ("device_marks", 0.85, 0.0)]:
    common.SLOTS[slot] = {"vc": True, "rough": rough, "metal": metal}
import polish
polish.enable(detail=1, bevel=0)

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color,slot="device_metal"):
    return p.box(slot,(size[0],size[2],size[1]),loc=g(*at),color=color)

def panel(p,outline,depth,at,color,slot="device_metal",side_color=None):
    return p.prism(slot,outline,depth,matrix=common.mtx(g(*at),(math.pi/2,0,0)),color=color,side_slot=slot if side_color is not None else None,side_color=side_color)

def finish(p,origin=(0,0,0)):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(origin=g(*origin),parent=root)

def chamfer(w,h,c):
    return [(-w/2+c,-h/2),(w/2-c,-h/2),(w/2,-h/2+c),(w/2,h/2-c),(w/2-c,h/2),(-w/2+c,h/2),(-w/2,h/2-c),(-w/2,-h/2+c)]

def preview(outdir,stem,span,target,ball_at):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.render.resolution_x=1000
    scene.render.resolution_y=760
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform="Standard"
    world=bpy.data.worlds.new("PreviewSky")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=common.rgba("bone")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=0.55
    scene.world=world
    bpy.ops.mesh.primitive_plane_add(size=120,location=(0,0,-0.08))
    bpy.context.object.data.materials.append(common._flat("PreviewGround","sandstone"))
    if stem == "cracked_cache":
        template=bpy.data.objects["CachePedestal"]
        template.hide_render=True
        for x,z in [(-4,-3),(0,-3.5),(4,-3)]:
            instance=template.copy()
            instance.data=template.data
            instance.name="PreviewPedestal"+str(x)
            scene.collection.objects.link(instance)
            instance.location=g(x,0,z)
            instance.hide_render=True
    ref=Part("ReferenceBall2m")
    ref.uv("paint",1.0,u=32,v=16,loc=g(*ball_at),color="bone")
    ref.ring("paint",0.985,1.0,0.1,segs=32,loc=g(*ball_at),color="charcoal")
    ref.to_object()
    light=bpy.data.lights.new("SoftSun","AREA")
    light.energy=30*span*span
    light.shape="DISK"
    light.size=span*1.2
    lo=bpy.data.objects.new("SoftSun",light)
    scene.collection.objects.link(lo)
    lo.location=(span*0.5,-span*0.8,span*1.7)
    common._look(lo,g(*target))
    cam=bpy.data.objects.new("PreviewCamera",bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    cam.data.type="ORTHO"
    cam.data.ortho_scale=span
    scene.camera=cam
    os.makedirs(outdir,exist_ok=True)
    for label,direction in [("front",(0,-1,0.25)),("side",(1,0,0.25)),("three_quarter",(0.8,-1,0.65))]:
        cam.location=Vector(g(*target))+Vector(direction)*span
        common._look(cam,g(*target))
        scene.render.filepath=os.path.join(outdir,stem+"_"+label+".png")
        bpy.ops.render.render(write_still=True)

    if stem == "cracked_cache":
        cam.location=g(0,3.2,20)
        common._look(cam,g(0,2.5,0))
        bpy.data.objects["CacheWall"].hide_render=True
        fill=bpy.data.lights.new("PreviewPocketFill","AREA")
        fill.energy=240
        fill.size=4
        fill_obj=bpy.data.objects.new("PreviewPocketFill",fill)
        scene.collection.objects.link(fill_obj)
        fill_obj.location=g(0,4.5,1.5)
        common._look(fill_obj,g(0,0.8,-3.8))
        scene.render.filepath=os.path.join(outdir,stem+"_cracked.png")
        bpy.ops.render.render(write_still=True)
        lid=bpy.data.objects["CacheLid"]
        lid.location+=Vector(g(0,0.6,-0.4))
        lid.rotation_euler.x=-0.9
        for o in scene.objects:
            if o.name.startswith("PreviewPedestal"):
                o.hide_render=False
        for x,z,color in [(-4,-3,"bone"),(0,-3.5,"mint"),(4,-3,"amber")]:
            offer=Part("PreviewOffer"+str(x))
            offer.uv("paint",0.45,u=4,v=2,loc=g(x,1.4,z),color=color)
            offer.to_object()
        scene.render.filepath=os.path.join(outdir,stem+"_opened.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects["ReferenceBall2m"].location=Vector(g(2.9,1,-1.5))-Vector(g(*ball_at))
        cam.data.ortho_scale=7
        cam.location=g(4,3,-0.5)
        common._look(cam,g(0.4,1.0,-3.8))
        scene.render.filepath=os.path.join(outdir,stem+"_chest_detail.png")
        bpy.ops.render.render(write_still=True)

root=common.empty("CrackedCache")
p=Part("CacheShell")
for s in (-1,1):
    box(p,(1,7.5,12),(s*6.5,2.25,0),common.mix("petrol","bone",0.22),"device_concrete")
    for y in (0.5,3.3,5.6):
        box(p,(1.025,0.09,11.9),(s*6.5,y,0),"charcoal","device_concrete")
    for z in (-4,-0.8,2.8):
        panel(p,chamfer(0.65,0.85,0.16),0.05,(s*6.5,4.4,z),common.mix("petrol","bone",0.16),"device_concrete")
box(p,(14,7.5,1),(0,2.25,-5.5),common.mix("petrol","bone",0.22),"device_concrete")
box(p,(14.2,0.35,0.3),(0,3.3,6.05),"charcoal","device_concrete")
for x in (-5.8,-2,2,5.8):
    box(p,(0.3,0.18,1.06),(x,5.75,-5.5),"sandstone","device_concrete")
for s in (-1,1):
    box(p,(0.8,0.12,1.025),(s*5.9,5.85,-5.5),"charcoal","device_concrete")
finish(p)
p=Part("CacheRoof")
panel(p,chamfer(14,1,0.18),12,(0,6.5,0),common.mix("petrol","bone",0.12),"device_concrete")
for x,y,w in [(-5.3,6.35,0.8),(-1.8,6.17,0.65),(4.8,6.32,0.95)]:
    panel(p,[(-w/2,-0.12),(w/2,-0.16),(w/2-0.18,0.14),(-w/2+0.12,0.21)],0.03,(x,y,6.015),common.mix("sandstone","petrol",0.28),"device_concrete")
finish(p)
p=Part("CacheWall")
polys=[ [(-6,-3.75),(-1,-3.75),(-1.5,-0.5),(-4,0.7),(-6,0.2)],
[(-0.87,-3.75),(6,-3.75),(6,-0.1),(2,0.5),(-1.35,-0.57)],
[(-6,0.35),(-4,0.85),(-1.55,-0.36),(-0.7,3.75),(-6,3.75)],
[(-1.38,-0.35),(2,0.65),(6,0.05),(6,3.75),(-0.55,3.75)] ]
box(p,(12,7.5,0.8),(0,2.25,5.5),"charcoal","device_concrete")
for i,poly in enumerate(polys):
    panel(p,poly,0.94,(0,2.25,5.5),common.mix("petrol","sandstone",0.12+i*0.035),"device_concrete")
for x,y in [(-5,1.2),(3.7,4.4),(0.6,0.8),(-2.7,5.5)]:
    panel(p,[(-0.3,-0.08),(0.22,-0.1),(0.32,0.015),(-0.15,0.11)],0.03,(x,y,5.99),"sandstone","device_concrete")
finish(p,(0,2.25,5.5))
p=Part("CacheChest")
panel(p,chamfer(2,1.2,0.16),1.4,(0,0.6,-3.8),common.mix("petrol","bone",0.38),side_color="petrol")
box(p,(1.75,0.12,1.2),(0,1.15,-3.8),"charcoal")
for x in (-0.72,0.72):
    box(p,(0.16,1.0,1.46),(x,0.6,-3.8),"copper")
box(p,(0.32,0.38,0.1),(0,0.85,-3.04),"charcoal")
box(p,(0.12,0.17,0.12),(0,0.88,-2.98),"bone")
finish(p,(0,0,-3.8))
p=Part("CacheLid")
panel(p,chamfer(2.1,0.3,0.08),1.5,(0,1.35,-3.8),common.mix("petrol","bone",0.38))
for x in (-0.72,0.72):
    box(p,(0.16,0.32,1.52),(x,1.35,-3.8),"copper")
box(p,(1.45,0.07,0.85),(0,1.535,-3.8),common.mix("petrol","bone",0.18))
finish(p,(0,1.35,-3.8))
p=Part("CachePedestal")
p.cyl("device_metal",0.8,0.65,0.5,segs=8,loc=g(0,0.25,0),color="charcoal")
p.ring("device_metal",0.44,0.7,0.12,segs=8,loc=g(0,0.54,0),color="copper")
for s in (-1,1):
    box(p,(0.15,0.45,0.3),(s*0.5,0.76,0),"petrol")
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("DEVICE_BUDGET",tris,"T",draws,"D")
if tris>1100 or draws>6:
    raise SystemExit("device budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","cracked_cache.glb"))
if opts["render"]:
    preview(opts["render"],"cracked_cache",23,(0, 2.5, 0),(8.7, 1, 5))
