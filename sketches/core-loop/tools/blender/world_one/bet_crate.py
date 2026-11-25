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
polish.enable(detail=1, bevel=0, bake_keep=(common.rgba("mint"), common.rgba("oxide")))

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color,slot="device_metal"):
    return p.box(slot,(size[0],size[2],size[1]),loc=g(*at),color=color)

def panel(p,outline,depth,at,color,slot="device_metal"):
    return p.prism(slot,outline,depth,matrix=common.mtx(g(*at),(math.pi/2,0,0)),color=color)

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

    if stem == "bet_crate":
        for label,angle in [("spinning",0.7),("heads",math.pi/2),("tails",-math.pi/2)]:
            bpy.data.objects["OddsNeedle"].rotation_euler.y=-angle
            scene.render.filepath=os.path.join(outdir,stem+"_"+label+".png")
            bpy.ops.render.render(write_still=True)

root=common.empty("BetCrate")
p=Part("BetHousing")
panel(p,chamfer(2.4,1.8,0.22),2.4,(0,0.9,0),"copper")
box(p,(2.05,0.12,2.05),(0,1.79,0),"charcoal")
box(p,(1.8,0.12,1.8),(0,1.86,0),common.mix("copper","bone",0.18))
for s in (-1,1):
    box(p,(0.18,1.55,2.44),(s*0.86,0.89,0),common.mix("copper","charcoal",0.35))
    box(p,(2.44,1.55,0.18),(0,0.89,s*0.86),common.mix("copper","charcoal",0.35))
for side in range(4):
    rot=side*math.pi/2
    outline=[(-1.22,-0.19),(1.22,-0.19),(1.22,0.19),(-1.22,0.19)]
    mat=common.mtx((0,0,1.2),(0,0,rot)) @ common.mtx((0,-1.235,0),(math.pi/2,0,0))
    p.prism("device_metal",outline,0.035,matrix=mat,color="charcoal")
    for x in (-0.95,-0.45,0.05,0.55):
        poly=[(x,-0.18),(x+0.22,-0.18),(x+0.58,0.18),(x+0.36,0.18)]
        p.prism("device_metal",poly,0.042,matrix=mat,color="hazard")
panel(p,[(-0.45,-0.23),(0.38,-0.25),(0.49,0.11),(0.24,0.24),(-0.4,0.19)],0.035,(0.07,0.6,1.215),common.mix("copper","charcoal",0.24))
for x,y in [(-0.22,0.46),(0.34,0.68),(-0.84,1.65),(0.84,1.65)]:
    p.cyl("device_metal",0.065,0.065,0.045,segs=5,loc=g(x,y,1.25),rot=(math.pi/2,0,0),color="bone")
box(p,(1.76,0.09,0.026),(0,1.7,1.23),common.mix("copper","charcoal",0.65))
p.cyl("device_metal",0.15,0.15,2.6,segs=8,loc=g(0,3.1,0),color="copper")
p.cyl("device_metal",0.24,0.21,0.18,segs=8,loc=g(0,2.0,0),color="charcoal")
for s in (-1,1):
    p.rod("device_metal",g(s*0.82,1.86,0),g(0,3.4,0),0.07,segs=5,color="copper")
finish(p)
p=Part("OddsDial")
p.cyl("device_marks",1.2,1.2,0.16,segs=20,loc=g(0,4.6,0),rot=(math.pi/2,0,0),color="charcoal")
for color,angles in [("mint",(math.pi/2,3*math.pi/2)),("oxide",(-math.pi/2,math.pi/2))]:
    p.ring("device_marks",0.001,1.07,0.025,segs=10,loc=g(0,4.6,0.1),rot=(math.pi/2,0,0),color=color,arc=angles)
for k in range(12):
    a=math.tau*k/12
    x,y=0.91*math.cos(a),4.6+0.91*math.sin(a)
    panel(p,[(-0.028,-0.07),(0.028,-0.07),(0.028,0.07),(-0.028,0.07)],0.028,(x,y,0.13),"charcoal","device_marks")
panel(p,[(0,-0.16),(0.16,0),(0,0.16),(-0.16,0)],0.03,(-0.57,4.6,0.14),"charcoal","device_marks")
for angle in (-math.pi/4,math.pi/4):
    p.box("device_marks",(0.075,0.035,0.4),loc=g(0.57,4.6,0.14),rot=(0,angle,0),color="bone")
finish(p,(0,4.6,0))
p=Part("OddsNeedle")
panel(p,[(-0.1,-0.15),(0.1,-0.15),(0.08,0.62),(0,0.96),(-0.08,0.62)],0.06,(0,4.6,0.18),"charcoal","device_marks")
panel(p,[(-0.055,0.64),(0.055,0.64),(0,0.88)],0.065,(0,4.6,0.18),"bone","device_marks")
p.cyl("device_marks",0.14,0.14,0.07,segs=8,loc=g(0,4.6,0.2),rot=(math.pi/2,0,0),color="copper")
finish(p,(0,4.6,0.18))

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("DEVICE_BUDGET",tris,"T",draws,"D")
if tris>1100 or draws>3:
    raise SystemExit("device budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","bet_crate.glb"))
if opts["render"]:
    preview(opts["render"],"bet_crate",8,(0, 2.8, 0),(2.8, 1, 0))
