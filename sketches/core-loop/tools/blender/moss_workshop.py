"""Static cabin dressing, in the existing Moss bay footprint. No collision or lights.
Blender +Z is up. Coordinates below are converted from the bay's Godot coordinates.
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import common
from common import Part
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
# Fits the grey cabin's 5 x 6 x 8 m volume, with shallow trim over its front.
box((5.08,6.05,8.08),(-17,3,0))
box((0.12,4.7,7.1),(-14.40,3.45,0),'charcoal')
for z in [-3.6,3.6]:
    box((0.3,5.9,0.3),(-14.25,3.1,z),'copper')
    for y in [0.6,2.1,4.4,5.8]:disc((-14.06,y,z),0.10,0.07)
# Uneven enamel shutter ribs and a dark service hatch below them.
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
# The header pipe and its worn collars explain the pressure shutter.
rod((-14.2,6.05,-4),(-14.2,6.05,4),0.25)
for z in [-3.3,-1.5,1.5,3.3]:rod((-14.2,6.05,z-0.08),(-14.2,6.05,z+0.08),0.34,'charcoal')
for z in [-3.9,3.9]:
    rod((-14.2,0.4,z),(-14.2,6.05,z),0.13)
    # One small emissive lamp lens, no dynamic light node.
    box((0.55,0.95,0.48),(-13.92,4.7,z),'charcoal')
    box((0.58,0.60,0.32),(-13.87,4.7,z),slot='class_accent')
    for y in [4.35,5.05]:box((0.72,0.1,0.68),(-13.9,y,z),'copper')
# Riveted roof overhang and two patched plates.
box((5.8,0.25,8.8),(-16.8,6.18,0),'oxide')
for z in [-2.0,1.4]:
    box((0.12,0.9,1.2),(-14.08,3.3,z),'oxide')
    for dz in [-0.48,0.48]:
        for dy in [-0.33,0.33]:disc((-13.98,3.3+dy,z+dz),0.055,0.07)
# A side shelf with cans and repair spools stays inside the cabin silhouette.
for y in [0.9,2.2,3.5]:
    box((0.6,0.14,1.4),(-13.8,y,-2.65),'copper')
    for z in [-2.95,-2.4]:
        p.cyl('paint',0.18,0.18,0.52,segs=10,loc=point((-13.65,y+0.32,z)),color='bone' if z < -2.5 else 'oxide')
p.to_object(parent=root)
tris=common.tri_total(root)
assert tris<6500,tris
common.export(root,common.args()['out'] or os.path.join(common.MODELS,'moss_workshop.glb'))
print('moss_workshop triangles',tris)
