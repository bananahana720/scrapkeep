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

    if stem == "ambush_altar":
        bpy.data.objects["AltarCap"].rotation_euler.z=0.6
        scene.render.filepath=os.path.join(outdir,stem+"_running.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects["AltarRing"].hide_render=True
        scene.render.filepath=os.path.join(outdir,stem+"_spent.png")
        bpy.ops.render.render(write_still=True)

root=common.empty("AmbushAltar")
p=Part("AltarPost")
p.cyl("device_metal",0.64,0.55,0.25,segs=8,loc=g(0,0.125,0),color="charcoal")
p.cyl("device_metal",0.42,0.29,2.9,segs=8,loc=g(0,1.7,0),color="copper")
for y in (0.4,1.4,2.5,3.1):
    p.cyl("device_metal",0.45,0.45,0.13,segs=8,loc=g(0,y,0),color=common.mix("copper","charcoal",0.35))
for k in range(4):
    a=math.tau*k/4+math.pi/4
    p.rod("device_metal",g(0.48*math.cos(a),0.27,0.48*math.sin(a)),g(0.3*math.cos(a),0.78,0.3*math.sin(a)),0.065,segs=5,color="copper")
box(p,(0.2,1.1,0.06),(0,1.95,0.37),"charcoal")
for y in (1.6,1.9,2.2):
    box(p,(0.15,0.06,0.07),(0,y,0.405),"bone")
finish(p)
p=Part("AltarCap")
p.cyl("device_marks",0.74,0.82,0.6,segs=8,loc=g(0,3.5,0),rot=(0,0,math.pi/8),color="charcoal")
p.cyl("device_marks",0.82,0.64,0.12,segs=8,loc=g(0,3.85,0),rot=(0,0,math.pi/8),color="copper")
for side in range(4):
    rot=side*math.pi/2
    mat=common.mtx((0,0,3.5),(0,0,rot)) @ common.mtx((0,-0.728,0),(math.pi/2+math.atan(0.08*math.cos(math.pi/8)/0.6),0,0))
    for x in (-0.66,-0.24,0.18):
        poly=[(x,-0.23),(x+0.17,-0.23),(x+0.63,0.23),(x+0.46,0.23)]
        for edge,sign in [(-0.28,1),(0.28,-1)]:
            clipped=[]
            for i,a in enumerate(poly):
                b=poly[(i+1)%len(poly)]
                inside_a=sign*(a[0]-edge)>=0
                inside_b=sign*(b[0]-edge)>=0
                if inside_a:
                    clipped.append(a)
                if inside_a != inside_b:
                    t=(edge-a[0])/(b[0]-a[0])
                    clipped.append((edge,a[1]+t*(b[1]-a[1])))
            poly=clipped
        if len(poly)>=3:
            p.prism("device_marks",poly,0.035,matrix=mat,color="hazard")
finish(p,(0,3.5,0))
p=Part("AltarBand")
p.cyl("device_metal",0.79,0.79,0.12,segs=8,loc=g(0,3.22,0),rot=(0,0,math.pi/8),color="bone")
finish(p)
p=Part("AltarRing")
for k in range(20):
    a=math.tau*k/20
    p.ring("device_marks",9.76,10.24,0.055,segs=1,loc=g(0,0.055,0),color="charcoal",arc=(a-0.042,a+0.042))
    p.ring("device_marks",9.84,10.16,0.012,segs=1,loc=g(0,0.09,0),color="hazard",arc=(a-0.032,a+0.032))
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("DEVICE_BUDGET",tris,"T",draws,"D")
if tris>1100 or draws>4:
    raise SystemExit("device budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","ambush_altar.glb"))
if opts["render"]:
    preview(opts["render"],"ambush_altar",27,(0, 1, 0),(3, 1, 0))
