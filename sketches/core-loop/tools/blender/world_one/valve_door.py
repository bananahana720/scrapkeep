import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part
common.reset()
common.SLOTS["device_metal"] = {"vc": True, "rough": 0.62, "metal": 0.45}

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color):
    return p.box("device_metal",(size[0],size[2],size[1]),loc=g(*at),color=color)

root=common.empty("ValveDoorModel")
W,H,D=12.0,6.0,1.0
plate=common.mix("copper","charcoal",0.35)
rib=common.mix("copper","charcoal",0.55)
p=Part("ValveDoor")
box(p,(W-0.6,H-0.6,D*0.6),(0,0,0),plate)
for y in (-H/2+0.2,H/2-0.2):
    box(p,(W,0.4,D),(0,y,0),rib)
for x in (-W/2+0.25,W/2-0.25):
    box(p,(0.5,H-0.8,D),(x,0,0),rib)
for z in (-D*0.3-0.06,D*0.3+0.06):
    for x in (-3.6,-1.2,1.2,3.6):
        box(p,(0.22,H-0.8,0.12),(x,0,z),rib)
    box(p,(W-1.0,0.24,0.16),(0,0.4,z*1.06),rib)
    for x in [(-W/2+0.9)+i*1.1 for i in range(10)]:
        for y in (-H/2+0.2,H/2-0.2):
            p.cyl("device_metal",0.06,0.06,0.06,segs=6,loc=g(x,y,z*1.75),rot=(math.pi/2,0,0),color="charcoal")
    box(p,(1.2,0.6,0.04),(-W/2+1.6,H/2-0.9,z*1.3),"brass")
    box(p,(W-1.2,0.18,0.03),(0,-H/2+0.75,z*1.3),"bone")
for x in (-3.0,3.0):
    box(p,(0.5,0.5,0.3),(x,H/2+0.25,0),"charcoal")
bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
p.to_object(parent=root)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("VALVE_DOOR_BUDGET",tris,"T",draws,"D")
if tris>2000 or draws>1:
    raise SystemExit("valve door budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","valve_door.glb"))
