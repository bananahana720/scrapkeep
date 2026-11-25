import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part
common.reset()
common.SLOTS["device_metal"] = {"vc": True, "rough": 0.68, "metal": 0.28}
common.SLOTS["device_marks"] = {"vc": True, "rough": 0.85, "metal": 0.0}

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color,slot="device_metal"):
    return p.box(slot,(size[0],size[2],size[1]),loc=g(*at),color=color)

def panel(p,outline,depth,at,color,slot="device_metal"):
    return p.prism(slot,outline,depth,matrix=common.mtx(g(*at),(math.pi/2,0,0)),color=color)

def finish(p):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(parent=root)

def chamfer(w,h,c):
    return [(-w/2+c,-h/2),(w/2-c,-h/2),(w/2,-h/2+c),(w/2,h/2-c),(w/2-c,h/2),(-w/2+c,h/2),(-w/2,h/2-c),(-w/2,-h/2+c)]

root=common.empty("FindKit")

p=Part("FindBoardFrame")
W,H,T=7.3,1.8,0.15
for y in (-H/2+T/2,H/2-T/2):
    box(p,(W,T,0.08),(0,y,0.04),"brass")
for x in (-W/2+T/2,W/2-T/2):
    box(p,(T,H-2*T,0.08),(x,0,0.04),"brass")
for x in (-W/2+T/2,W/2-T/2):
    for y in (-H/2+T/2,H/2-T/2):
        p.cyl("device_metal",0.05,0.05,0.04,segs=6,loc=g(x,y,0.1),rot=(math.pi/2,0,0),color="charcoal")
for x in (-2.4,2.4):
    box(p,(0.1,0.5,0.03),(x,H/2+0.22,0.02),common.mix("brass","charcoal",0.4))
finish(p)

p=Part("FindBoard")
panel(p,chamfer(7.0,1.5,0.08),0.08,(0,0,0.08),"charcoal")
finish(p)

p=Part("FindAerial")
box(p,(0.36,0.24,0.3),(0,0.12,0),"charcoal")
box(p,(0.2,0.08,0.34),(0,0.26,0),common.mix("brass","charcoal",0.3))
p.rod("device_metal",g(0,0.25,0),g(0,1.4,0),0.06,segs=6,r2=0.045,color="brass")
p.rod("device_metal",g(0,1.4,0),g(0,2.4,0),0.045,segs=6,r2=0.03,color="brass")
p.rod("device_metal",g(0,2.4,0),g(0,3.12,0),0.03,segs=6,r2=0.018,color="brass")
for y in (1.4,2.4):
    p.cyl("device_metal",0.07,0.07,0.08,segs=6,loc=g(0,y,0),color="charcoal")
p.uv("device_metal",0.08,u=6,v=4,loc=g(0,3.13,0),color="brass")
finish(p)

p=Part("FindSeep")
wet=common.mix("charcoal","petrol",0.35)
outline=[(-0.5,0.5),(-0.18,0.46),(0.12,0.5),(0.5,0.44),(0.36,0.2),(0.22,-0.05),(0.18,-0.3),(0.07,-0.5),(-0.04,-0.42),(-0.12,-0.18),(-0.3,0.08),(-0.44,0.28)]
panel(p,outline,0.03,(0,0,0.015),wet,"device_marks")
panel(p,[(-0.16,0.46),(0.14,0.46),(0.08,0.0),(0.03,-0.38),(-0.04,-0.1)],0.01,(0,0,0.035),common.mix("charcoal","petrol",0.15),"device_marks")
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("FIND_KIT_BUDGET",tris,"T",draws,"D")
if tris>600 or draws>4:
    raise SystemExit("find kit budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","find_kit.glb"))
