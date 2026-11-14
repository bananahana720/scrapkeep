# A pocket interior's kit (activities.gd _build_interior): the crew-cast cover block the ball banks
# off inside an activity pocket, and the bollard that marks each side of its entrance.
# Procedural bmesh; no external assets or physics. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y).
# Each part is built about its own centre at a nominal size (block 4 by 3 by 4 m, bollard 0.3 by
# 2 by 0.3 m); activities.gd scales each to its authored block.
import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part
common.reset()
common.SLOTS["device_concrete"] = {"vc": True, "rough": 0.9, "metal": 0.0}
common.SLOTS["device_metal"] = {"vc": True, "rough": 0.68, "metal": 0.28}

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color,slot="device_metal"):
    return p.box(slot,(size[0],size[2],size[1]),loc=g(*at),color=color)

def slab(p,outline,height,y,color,slot="device_concrete"):
    # An outline in Godot (x, z), extruded up y from y - height/2 to y + height/2.
    return p.prism(slot,[(x,-z) for x,z in outline],height,matrix=common.mtx((0,0,y)),color=color)

def chamfer(w,d,c):
    return [(-w/2+c,-d/2),(w/2-c,-d/2),(w/2,-d/2+c),(w/2,d/2-c),(w/2-c,d/2),(-w/2+c,d/2),(-w/2,d/2-c),(-w/2,-d/2+c)]

def finish(p):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(parent=root)

root=common.empty("PocketKit")
cast=common.mix("petrol","sandstone",0.35)
dark=common.mix("petrol","charcoal",0.5)
steel=common.mix("copper","charcoal",0.55)

# The cover block: a chamfered cast body on a darker plinth, a capping slab, a scuffed bone stencil
# band on all four faces, steel corner angles where the ball bites, and two lifting eyes on top.
p=Part("PocketBlock")
slab(p,chamfer(4.0,4.0,0.45),0.3,-1.35,dark)
slab(p,chamfer(3.84,3.84,0.42),2.3,-0.05,cast)
slab(p,chamfer(3.96,3.96,0.46),0.3,1.25,common.mix("sandstone","petrol",0.5))
slab(p,chamfer(3.6,3.6,0.36),0.1,1.45,cast)
for k in range(4):
    a=k*math.pi/2
    c,s=math.cos(a),math.sin(a)
    # Stencil band on this face (normal (s, 0, c) after the turn).
    w,d=2.2,0.03
    at=(s*1.93,0.35,c*1.93)
    box(p,(w*abs(c)+d*abs(s),0.22,w*abs(s)+d*abs(c)),at,"bone","device_concrete")
for x in (-1.0,1.0):
    for z in (-1.0,1.0):
        # A steel wear plate down this corner's chamfer face, turned to lie on it.
        yaw=math.atan2(z,x)
        p.box("device_metal",(0.08,0.62,2.3),loc=g(x*1.71,-0.05,z*1.71),rot=(0,0,-yaw),color=steel)
for x in (-1.1,1.1):
    p.ring("device_metal",0.1,0.18,0.06,segs=8,loc=g(x,1.62,0),rot=(0,math.pi/2,0),color=steel)
finish(p)

# The entrance bollard: a steel post with a domed cap and a reflective collar; the runtime paints it
# the activity's colour so the entrance reads as that pocket's.
p=Part("PocketPost")
p.cyl("device_metal",0.17,0.15,0.12,segs=8,loc=g(0,-0.94,0),color="charcoal")
p.cyl("device_metal",0.13,0.12,1.7,segs=8,loc=g(0,0,0),color="bone")
p.cyl("device_metal",0.15,0.15,0.16,segs=8,loc=g(0,0.55,0),color="bone")
p.uv("device_metal",0.13,u=8,v=4,loc=g(0,0.86,0),scale=(1,1,0.6),color="bone")
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("POCKET_KIT_BUDGET",tris,"T",draws,"D")
if tris>700 or draws>3:
    raise SystemExit("pocket kit budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","pocket_kit.glb"))
