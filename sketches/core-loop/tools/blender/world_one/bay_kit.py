# Moss's bay (src/world/bay.gd): the props on the hover barge's deck and the dock cradle. Procedural
# bmesh; no external assets or physics. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y). Each part is built
# about the point bay.gd places it at:
#   BayCabin      the cabin's centre (5 by 6 by 8 m), its front (+X) dressed with Moss's shutter, hatch,
#                 counter, shelf, locked hook under its pressure dial, chipped mug and plant in a tin
#   BayBellFrame  the floor under the bell: two posts and a beam, 3.6 m wide
#   BayBell       the bell's own centre, so it swings about it
#   BayMarbleToy  the floor at the toy: a crate with its zigzag of copper steps
#   BayYardWall   the yard wall's centre (8 by 5 by 1.4 m)
#   BayPost       the grapple post's centre (9 m tall)
#   BayPin        a bowling pin's centre (1.5 m tall)
#   CradleCup     the dock cradle's cup centre
#   CradleMast    the cradle mast's centre (12 m), with Moss's mug sign on top
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

def cyl(p,r1,r2,h,at,color,segs=8,rot=(0,0,0)):
    return p.cyl("device_metal",r1,r2,h,segs=segs,loc=g(*at),rot=rot,color=color)

def finish(p):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(parent=root)

root=common.empty("BayKitModel")
teal=common.mix("petrol","sandstone",0.3)
plank=common.mix("sandstone","oxide",0.25)
rust=common.mix("oxide","sandstone",0.2)
steel=common.mix("copper","charcoal",0.55)
sand=common.mix("sandstone","bone",0.5)

# The cabin: a teal plank shack on a dark skid, corner posts, a roof slab with an overhang over the
# front, and Moss's counter front. Front face at x +2.5.
p=Part("BayCabin")
box(p,(4.9,5.6,7.9),(0,-0.1,0),teal)
for x in (-2.45,2.45):
    for z in (-3.95,3.95):
        box(p,(0.3,6.0,0.3),(x,0,z),steel)
box(p,(5.4,0.3,8.6),(0.25,3.0,0),plank)
box(p,(5.2,0.3,8.2),(0,-2.85,0),"charcoal")
for y in (-1.5,0.0,1.5):
    box(p,(5.0,0.06,8.0),(0,y,0),common.mix("petrol","charcoal",0.4))
F=2.55
# The shutter, rolled down, ribbed; the hatch at ball height; the counter; the shelf rail.
box(p,(0.1,4.6,7.0),(F,0.4,0),rust)
for k in range(9):
    box(p,(0.05,0.08,7.0),(F+0.07,-1.7+k*0.5,0),common.mix("oxide","charcoal",0.4))
box(p,(0.14,1.3,1.8),(F+0.02,-1.8,0),"charcoal")
box(p,(1.0,1.0,6.0),(F+0.8,-2.5,0),plank)
box(p,(1.1,0.1,6.2),(F+0.8,-1.98,0),common.mix("sandstone","bone",0.3))
box(p,(0.6,0.12,5.0),(F+0.35,2.2,0),"copper")
for z in (-2.2,2.2):
    box(p,(0.1,0.4,0.1),(F+0.1,2.0,z),steel)
# The locked hook on its bracket, and the pressure dial with its needle and red mark.
p.ring("device_metal",0.25,0.42,0.17,segs=10,loc=g(F+0.3,1.0,3.0),rot=(0,math.pi/2,0),color="copper")
box(p,(0.3,0.45,0.35),(F+0.3,0.55,3.0),"charcoal")
cyl(p,0.55,0.55,0.08,(F+0.12,1.9,3.0),sand,segs=12,rot=(0,math.pi/2,0))
cyl(p,0.6,0.6,0.05,(F+0.09,1.9,3.0),"brass",segs=12,rot=(0,math.pi/2,0))
box(p,(0.05,0.45,0.06),(F+0.18,1.95,3.0),"charcoal")
box(p,(0.05,0.2,0.08),(F+0.18,2.3,3.25),"oxide")
# The chipped mug and the plant in a tin on the counter.
cyl(p,0.2,0.22,0.4,(F+0.8,-1.8,-1.8),"bone",segs=8)
box(p,(0.08,0.2,0.1),(F+1.04,-1.75,-1.8),"bone")
cyl(p,0.3,0.3,0.45,(F+0.8,-1.78,2.0),"copper",segs=8)
for k in range(3):
    p.ico("device_metal",0.24,subdiv=0,loc=g(F+0.8+(k-1)*0.15,-1.4+k*0.08,2.0+(k-1)*0.12),color=common.mix("petrol","mint",0.3))
finish(p)

# The bell frame: two rusted posts and a beam with a bracket at its centre.
p=Part("BayBellFrame")
for s in (-1.0,1.0):
    box(p,(0.3,5.0,0.3),(s*1.6,2.5,0),rust)
    box(p,(0.7,0.12,0.7),(s*1.6,0.06,0),"charcoal")
box(p,(3.6,0.3,0.3),(0,5.0,0),rust)
box(p,(0.3,0.4,0.36),(0,4.7,0),"charcoal")
finish(p)

# The bell: a flared brass bell 1.4 m tall with a lip ring and a clapper, about its centre.
p=Part("BayBell")
cyl(p,0.5,0.9,1.2,(0,0.1,0),common.mix("brass","copper",0.5),segs=12)
p.ring("device_metal",0.85,1.02,0.14,segs=12,loc=g(0,-0.55,0),color="brass")
cyl(p,0.18,0.18,0.2,(0,0.8,0),"charcoal")
p.uv("device_metal",0.16,u=6,v=4,loc=g(0,-0.62,0),color="charcoal")
finish(p)

# The marble toy: a crate 2.4 by 1.6 by 1.6 m behind its run, five copper steps tilted in a zigzag.
p=Part("BayMarbleToy")
box(p,(2.4,1.6,1.6),(0,0.8,-1.4),plank)
box(p,(2.5,0.12,1.7),(0,1.62,-1.4),common.mix("sandstone","bone",0.3))
for k in range(5):
    p.box("device_metal",(0.5,1.3,0.08),loc=g(-0.9+k*0.4,2.05-k*0.18,-0.8),rot=((0.3 if k%2==0 else -0.3),0,0),color="copper")
for x in (-1.1,1.1):
    box(p,(0.08,2.1,0.08),(x,1.05,-0.8),steel)
finish(p)

# The yard wall: a teal cast panel between steel posts, a dark plinth and a bone target band.
p=Part("BayYardWall")
box(p,(7.6,4.6,1.2),(0,-0.1,0),teal)
for x in (-3.85,3.85):
    box(p,(0.3,5.0,1.4),(x,0,0),steel)
box(p,(8.0,0.3,1.4),(0,-2.35,0),"charcoal")
box(p,(8.0,0.2,1.4),(0,2.4,0),steel)
for z in (-0.62,0.62):
    box(p,(5.0,0.3,0.04),(0,0.5,z),"bone")
finish(p)

# The grapple post: a copper pole 9 m tall on a flange with steel collars.
p=Part("BayPost")
cyl(p,0.6,0.55,9.0,(0,0,0),"copper",segs=10)
cyl(p,0.95,0.95,0.2,(0,-4.4,0),steel,segs=10)
for y in (-2.0,1.0,4.2):
    cyl(p,0.68,0.68,0.25,(0,y,0),steel,segs=10)
finish(p)

# A bowling pin: a turned bone pin with a red neck stripe, 1.5 m tall about its centre.
p=Part("BayPin")
prof=[(-0.75,0.22),(-0.55,0.3),(-0.2,0.3),(0.15,0.2),(0.35,0.12),(0.5,0.14),(0.65,0.12),(0.75,0.0)]
for (y0,r0),(y1,r1) in zip(prof,prof[1:]):
    color="oxide" if 0.3<=y0<0.45 else "bone"
    cyl(p,r0,max(r1,0.04),y1-y0,(0,(y0+y1)/2,0),color,segs=8)
finish(p)

# The cradle cup: a copper dish, wide at the top, on a steel foot ring.
p=Part("CradleCup")
cyl(p,1.2,2.7,0.6,(0,0,0),"copper",segs=16)
cyl(p,1.35,1.35,0.2,(0,-0.25,0),steel,segs=16)
p.ring("device_metal",2.55,2.75,0.12,segs=16,loc=g(0,0.3,0),color=steel)
finish(p)

# The cradle mast: a rusted 12 m mast with collars, and Moss's chipped mug on top for a sign.
p=Part("CradleMast")
cyl(p,0.35,0.3,12.0,(0,0,0),rust,segs=8)
cyl(p,0.6,0.6,0.2,(0,-5.9,0),"charcoal",segs=8)
for y in (-2.0,2.0):
    cyl(p,0.42,0.42,0.2,(0,y,0),steel,segs=8)
cyl(p,0.8,0.9,1.4,(0,6.6,0),"bone",segs=12)
p.ring("device_metal",0.35,0.55,0.18,segs=10,loc=g(0.95,6.6,0),rot=(math.pi/2,0,0),color="bone")
cyl(p,0.86,0.86,0.12,(0,6.4,0),"oxide",segs=12)
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("BAY_KIT_BUDGET",tris,"T",draws,"D")
if tris>4000 or draws>9:
    raise SystemExit("bay kit budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","bay_kit.glb"))
