"""Static cabin dressing, in the existing Moss bay footprint. No collision or lights.
Blender +Z is up. Coordinates below are converted from the bay's Godot coordinates.
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import common
import polish
from common import Part
polish.enable(detail=1, bevel=0.03, bevel_min=9)
common.reset()
rng=random.Random(280928)
root=common.empty('MossWorkshop')
p=Part('CabinDress')
def point(g): return (g[0],-g[2],g[1])
def box(size,at,color='petrol',slot='paint'):
    return p.box(slot,(size[0],size[2],size[1]),point(at),color=color if slot=='paint' else None)
def rod(a,b,r,color='copper'):
    return p.rod('paint',point(a),point(b),r,segs=8,color=color)
def disc(at,r,depth,slot='bare_metal'):
    return p.cyl(slot,r,r,depth,segs=12,loc=point(at),rot=(0,math.pi/2,0))
box((4.36,6.05,6.8),(-16.68,3,0))
box((0.12,4.7,7.1),(-14.40,3.45,0),'charcoal')
for z in [-3.6,3.6]:
    box((0.3,5.9,0.3),(-14.25,3.1,z),'copper')
    for y in [0.6,2.1,4.4,5.8]:disc((-14.06,y,z),0.10,0.07)
for i in range(10):
    y=2.2+i*0.34
    color=common.mix('petrol','bone',rng.uniform(0.04,0.20))
    box((0.20,0.27,6.65),(-14.2,y,0),color)
    for j in range(4):
        z=rng.uniform(-3.1,3.1)
        box((0.018,0.045,rng.uniform(0.08,0.32)),(-14.08,y-0.09,z),'oxide')
box((0.24,1.4,2.5),(-14.11,1.2,0),'charcoal')
box((1.0,0.16,5.0),(-13.9,0.7,0),'copper')
for z in [-2.2,2.2]:box((0.55,0.6,0.3),(-14.0,0.3,z),'charcoal')
rod((-14.2,6.05,-4),(-14.2,6.05,4),0.25)
for z in [-3.3,-1.5,1.5,3.3]:rod((-14.2,6.05,z-0.08),(-14.2,6.05,z+0.08),0.34,'charcoal')
for z in [-3.9,3.9]:
    rod((-14.2,0.4,z),(-14.2,6.05,z),0.13)
    box((0.55,0.95,0.48),(-13.92,4.7,z),'charcoal')
    box((0.58,0.60,0.32),(-13.87,4.7,z),slot='class_accent')
    for y in [4.35,5.05]:box((0.72,0.1,0.68),(-13.9,y,z),'copper')
for z in [-2.0,1.4]:
    box((0.12,0.9,1.2),(-14.08,3.3,z),'oxide')
    for dz in [-0.48,0.48]:
        for dy in [-0.33,0.33]:disc((-13.98,3.3+dy,z+dz),0.055,0.07)
for y in [0.9,2.2,3.5]:
    box((0.6,0.14,1.4),(-13.8,y,-2.65),'copper')
    for z in [-2.95,-2.4]:
        p.cyl('paint',0.18,0.18,0.52,segs=10,loc=point((-13.65,y+0.32,z)),color='bone' if z < -2.5 else 'oxide')

box((8.6,0.24,12.6),(-15.6,7.1,0),'petrol')
for z in [-6,6]:
    box((0.30,7,0.30),(-11.8,3.5,z),'copper')
    rod((-19,6.6,z),(-11.7,6.6,z),0.14)
    for x in [-18,-15,-12]:
        box((0.64,0.9,0.64),(x,6.5,z), 'charcoal')
        box((0.42,0.55,0.42),(x,6.45,z),slot='class_accent')
for y in [0.6,1.8,3.0,4.2]:
    box((2.1,0.16,2.6),(-12.8,y,-4.5),'copper')
    for j in range(3):
        at=(-12.6,y+0.4,-5.3+j*0.76)
        p.cyl('paint',0.25,0.23,0.58,8,loc=point(at),color='petrol' if j%2 else 'bone')
        rod((at[0],at[1]+0.30,at[2]),(at[0],at[1]+0.39,at[2]),0.13,'charcoal')
box((1.65,0.35,3.4),(-12.6,0.45,4.5),'copper')
box((1.5,0.55,3.0),(-12.45,0.85,4.5),'petrol')
box((0.35,1.9,3.1),(-13.2,1.3,4.5),'petrol')
for z in [2.9,6.1]:box((1.7,0.45,0.3),(-12.5,1.25,z),'copper')
for z in [3.8,5.2]:box((0.04,0.38,0.55),(-11.67,0.85,z),'bone')
for r,color in [(3.2,'oxide'),(2.9,'bone'),(2.65,'petrol'),(2.35,'copper'),(2.05,'oxide')]:
    p.cyl('paint',r,r,0.018,32,loc=point((-10.7,0.055+(3.2-r)*0.025,0.2)),color=color)
box((1.94,2.8,1.34),(-6,1.4,8.6),'copper')
box((1.98,1.6,1.38),(-6,1.1,8.6),'petrol')
p.uv('paint',1.0,12,6,loc=point((-6,2.68,8.6)),scale=(0.96,0.64,0.54),color='copper')
for z in [8.05,9.15]:rod((-4.98,0.4,z),(-4.98,2.8,z),0.12,'bone')
for y in [0.6,0.85,1.1,1.35]:box((0.05,0.06,0.82),(-4.98,y,8.6),'charcoal')
box((0.06,0.62,0.75),(-4.96,2.1,8.6),slot='class_accent')
for z in [8.38,8.63,8.86]:disc((-4.87,1.65,z),0.07,0.04)
box((2.5,0.02,2.5),(-6,0.12,7),'petrol')
box((0.20,1.05,3.3),(-11.5,5.8,0),'charcoal')
for z in [-1.3,1.3]:rod((-11.5,6.3,z),(-11.5,7,z),0.045)
rod((-11.36,5.45,-1.10),(-11.36,6.07,-0.72),0.085,'bone')
rod((-11.36,6.07,-0.72),(-11.36,6.1,-0.96),0.065,'bone')
rod((-11.36,6.07,-0.72),(-11.36,5.88,-0.62),0.065,'bone')
box((0.08,0.4,0.4),(-11.35,5.75,0),'bone')
rod((-11.35,5.87,0.22),(-11.35,5.72,0.36),0.05,'bone')
rod((-11.35,5.72,0.36),(-11.35,5.60,0.22),0.05,'bone')
rod((-11.35,5.50,1.0),(-11.35,6.08,1.0),0.055,'bone')
rod((-11.35,6.08,1.0),(-11.35,5.99,1.29),0.065,'bone')
p.ico('paint',0.14,1,loc=point((-11.35,5.49,0.89)),color='bone')
p.bm.normal_update()
for f in p.bm.faces:
    if p.slots[f.material_index] != 'paint': continue
    c=f.calc_center_median()
    edge=any(len(e.link_faces)==2 and e.calc_face_angle(0)>0.7 for e in f.edges)
    if f.normal.z < -0.4:
        for loop in f.loops:
            color=loop[p.col];loop[p.col]=(color[0]*0.7,color[1]*0.7,color[2]*0.7,1)
    elif edge and math.sin(c.x*41+c.y*29+c.z*13)>0.65:
        for loop in f.loops:
            color=loop[p.col];loop[p.col]=tuple(color[i]*0.75+common.rgba('bone')[i]*0.25 for i in range(3))+(1,)
p.to_object(parent=root)
tris=common.tri_total(root)
assert tris<6500,tris
common.export(root,common.args()['out'] or os.path.join(common.MODELS,'moss_workshop.glb'))
print('moss_workshop triangles',tris)
