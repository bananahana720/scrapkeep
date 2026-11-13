# A Signal radio cache (src/world/radio_cache.gd): a crew antenna mast with its dish, a blinking
# lamp and the pulse ring that widens from it. Procedural bmesh; no external assets or physics.
# Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y). The mast stands on its origin; the lamp and the ring
# are built about their own origins so the runtime can blink and scale them.
import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part
common.reset()
common.SLOTS["device_metal"] = {"vc": True, "rough": 0.55, "metal": 0.6}
common.SLOTS["device_marks"] = {"vc": True, "rough": 0.85, "metal": 0.0}

def g(x,y,z):
    return (x,-z,y)

def box(p,size,at,color,slot="device_metal"):
    return p.box(slot,(size[0],size[2],size[1]),loc=g(*at),color=color)

root=common.empty("RadioCache")

def finish(p):
    bmesh.ops.recalc_face_normals(p.bm,faces=p.bm.faces[:])
    return p.to_object(parent=root)

# The mast: a bolted foot plate, a crew junction box with a brass tag, a copper pole in two tapering
# sections, and the dish tipped back toward the sky on a short arm with its feed horn.
p=Part("RadioMast")
p.cyl("device_metal",0.42,0.38,0.08,segs=8,loc=g(0,0.04,0),color="charcoal")
for k in range(4):
    a=math.tau*k/4+math.pi/4
    p.cyl("device_metal",0.05,0.05,0.06,segs=6,loc=g(0.3*math.cos(a),0.1,0.3*math.sin(a)),color=common.mix("brass","charcoal",0.3))
box(p,(0.34,0.42,0.22),(0,0.3,0.16),common.mix("petrol","bone",0.2))
box(p,(0.2,0.08,0.02),(0,0.38,0.28),"brass")
p.rod("device_metal",g(0,0.08,0),g(0,1.3,0),0.1,segs=8,r2=0.08,color="copper")
p.cyl("device_metal",0.11,0.11,0.08,segs=8,loc=g(0,1.3,0),color="charcoal")
p.rod("device_metal",g(0,1.3,0),g(0,2.2,0),0.075,segs=8,r2=0.06,color="copper")
p.rod("device_metal",g(0,2.05,0),g(0,2.12,0.32),0.035,segs=6,color="charcoal")
# Dish: a shallow cone, open face up and tipped back 30 degrees, with a rim band and a feed horn.
tilt=(math.radians(-60),0,0)
p.cyl("device_metal",0.18,0.55,0.22,segs=12,loc=g(0,2.2,0.32),rot=tilt,color="brass",caps=True)
p.ring("device_metal",0.5,0.58,0.05,segs=12,loc=g(0,2.31,0.25),rot=tilt,color=common.mix("brass","charcoal",0.25))
p.rod("device_metal",g(0,2.3,0.26),g(0,2.62,0.06),0.02,segs=5,color="charcoal")
finish(p)

# The lamp, a bulb in a small brass cage; the runtime lights it.
p=Part("RadioLamp")
p.uv("device_marks",0.12,u=8,v=6,loc=g(0,0,0),color="bone")
finish(p)

# The pulse ring, flat and thin, radius 0.9 to 1.0; the runtime widens and fades it.
p=Part("RadioPulse")
p.ring("device_marks",0.9,1.0,0.04,segs=24,loc=g(0,0,0),color="bone")
finish(p)

bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("RADIO_CACHE_BUDGET",tris,"T",draws,"D")
if tris>900 or draws>3:
    raise SystemExit("radio cache budget exceeded")
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","radio_cache.glb"))
