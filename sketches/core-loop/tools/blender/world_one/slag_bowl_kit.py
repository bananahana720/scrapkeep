# The Slag Bowl's crane rig and rim vents (src/boss/arena.gd _mast and _vent): a 20 m crane mast,
# its crossbar boom and a water vent's nozzle. Procedural bmesh; no external assets or physics.
# Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y). Each part is built about its own centre, where arena.gd
# placed the old cylinder or box. The mast and boom are painted light: the bowl dress
# (arena_bowl_dress.gd) wears them in its copper crane material, which the vertex colour tints.
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

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color):
    return p.box("device_metal",(size[0],size[2],size[1]),loc=g(*at),color=color)

def cyl(p,r1,r2,h,y,color,segs=8):
    return p.cyl("device_metal",r1,r2,h,segs=segs,loc=g(0,y,0),color=color)

def finish(p):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(parent=root)

root=common.empty("SlagBowlKit")
light=common.mix("bone","copper",0.15)
shade=common.mix("bone","charcoal",0.45)
dark="charcoal"

# The mast: a tapering pole on a bolted foot flange, four riveted collars, a ladder of rungs
# up its outer face and a cap plate under the boom. 20 m tall about its centre.
H=20.0
p=Part("CraneMast")
cyl(p,1.2,1.0,H,0,light)
cyl(p,1.9,1.9,0.3,-H/2+0.15,shade)
for k in range(8):
    a=math.tau*k/8
    p.cyl("device_metal",0.12,0.12,0.2,segs=6,loc=g(1.6*math.cos(a),-H/2+0.4,1.6*math.sin(a)),color=dark)
for y in (-5.0,0.0,5.0,9.2):
    r=1.2-0.2*(y+H/2)/H
    cyl(p,r+0.14,r+0.14,0.4,y,shade)
for k in range(17):
    y=-H/2+1.5+k*1.0
    r=1.2-0.2*(y+H/2)/H
    box(p,(0.7,0.08,0.08),(0,y,r+0.32),dark)
for x in (-0.38,0.38):
    p.rod("device_metal",g(x,-H/2+1.0,1.32),g(x,H/2-1.2,1.12),0.05,segs=4,color=dark)
cyl(p,1.25,1.25,0.2,H/2-0.1,shade)
finish(p)

# The boom: an I-girder 8 m long about its centre, bolted fishplates over the mast and a pulley
# block hanging from each end.
L=8.0
p=Part("CraneBoom")
box(p,(L,0.14,0.8),(0,0.33,0),light)
box(p,(L,0.14,0.8),(0,-0.33,0),light)
box(p,(L,0.52,0.14),(0,0,0),light)
for x in (-0.9,0.9):
    box(p,(0.9,0.6,0.86),(x,0,0),shade)
for s in (-1.0,1.0):
    x=s*(L/2-0.4)
    box(p,(0.3,0.5,0.5),(x,-0.62,0),dark)
    p.cyl("device_metal",0.22,0.22,0.12,segs=8,loc=g(x,-0.62,0),rot=(math.pi/2,0,0),color=shade)
    p.rod("device_metal",g(x,-0.9,0),g(x,-2.2,0),0.03,segs=4,color=dark)
    box(p,(0.2,0.3,0.12),(x,-2.3,0),dark)
finish(p)

# The vent nozzle: a verdigris riser 3 m tall about its centre on a flange, a valve collar and a
# flared spout ringed with a brass band.
p=Part("VentNozzle")
cyl(p,0.9,0.75,2.2,-0.4,"petrol")
cyl(p,1.15,1.15,0.2,-1.4,common.mix("petrol","charcoal",0.4))
cyl(p,0.95,0.95,0.3,0.2,common.mix("petrol","charcoal",0.4))
box(p,(0.2,0.3,0.6),(0.95,0.2,0),"brass")
cyl(p,0.7,0.95,0.7,1.15,"petrol")
cyl(p,0.98,0.98,0.12,1.44,"brass")
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("SLAG_BOWL_KIT_BUDGET",tris,"T",draws,"D")
if tris>1600 or draws>3:
    raise SystemExit("slag bowl kit budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","slag_bowl_kit.glb"))
