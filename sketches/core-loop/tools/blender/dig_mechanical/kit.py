"""MDM mechanical kit. Metre-space authoring, no runtime placement or collision.

Recipes: blender -b --threads 2 --python-exit-code 1 -P <basename>.py
Batch:   blender -b --threads 2 --python-exit-code 1 -P kit.py -- --all
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import polish

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/dig_mechanical"
MATERIALS = SKETCH / "assets/materials/dig_mechanical"
P = [270, 610, 1]
S = [120, 110, 2]
ASSETS = {}
PARTS = {}


def xyz(v):
    return (v[0], -v[2], v[1])


def material(slot):
    mat = bpy.data.materials.get(slot)
    if mat:
        return mat
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = {"steel": .82, "enamel": .87, "elastomer": .95, "glass": .38}[slot]
    bsdf.inputs["Metallic"].default_value = .22 if slot == "steel" else 0
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


FINISH = {}
BAKE = {"bake_slots": ("elastomer", "enamel", "steel"), "bake_keep": (common.rgba("mint"),)}


DIG_POLISH = {n: dict(bevel=0) for n in (
    "impeller_rim_sector", "impeller_hub", "impeller_vane", "impeller_vane_chipped", "intake_petal",
    "intake_throat", "intake_spine_segment", "cart_wheel", "shell_crescent", "shell_saddle",
    "breach_rim_sector", "breach_tab")}
DIG_POLISH.update({"cart_body": dict(bevel=0),
                   "strut_tall": dict(bevel=.03, bevel_min=.6), "strut_bent": dict(bevel=.03, bevel_min=.6)})


def use_polish(name):
    base = name.rsplit("_", 1)[0] if "x" in name.rsplit("_", 1)[-1] and name.startswith("breach_wedge_") else name
    cfg = DIG_POLISH.get(base, dict(bevel=0) if base.startswith("breach_wedge_") else None)
    if cfg is None:
        polish._opts = common.POLISH = None
        common.DETAIL = 1
    else:
        polish.enable(detail=1, **cfg, **BAKE)


class Surface:
    def __init__(self, name, slot, smooth=False):
        self.name, self.slot, self.smooth = name, slot, smooth
        self.verts, self.faces, self.colors = [], [], []
        finish = FINISH.get(name, {})
        self.bevel, self.subsurf = finish.get("bevel"), finish.get("subsurf")

    def add(self, verts, faces, color="petrol", colors=None):
        off = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(off + k for k in f) for f in faces)
        self.colors.extend(colors if colors else [color] * len(verts))

    def box(self, size, center, color="petrol"):
        x, y, z = (s / 2 for s in size)
        cx, cy, cz = center
        self.add([(cx + a*x, cy + b*y, cz + c*z) for a,b,c in
                  [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],
                 [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)], color)

    def beam(self, a, b, width, depth, color="petrol"):
        d = Vector(b) - Vector(a)
        n = Vector((-d.y, d.x, 0)).normalized() * width / 2
        points = []
        for z in [-depth/2, depth/2]:
            for v in [Vector(a)-n, Vector(b)-n, Vector(b)+n, Vector(a)+n]:
                points.append((v.x, v.y, v.z+z))
        self.add(points, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], color)

    def prism(self, outline, thick, color="bone", axis="z", offset=(0,0,0)):
        points=[]
        for t in [-thick/2, thick/2]:
            for a,b in outline:
                v=(a,b,t) if axis=="z" else (a,t,b)
                points.append(tuple(v[k]+offset[k] for k in range(3)))
        n=len(outline)
        faces=[tuple(reversed(range(n))), tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(points,faces,color)

    def rings(self, rings, angles, color="bone", closed=False, cap_ends=False, palette=None):
        n=len(angles)
        verts=[fn(a) for fn in rings for a in angles]
        colors=[palette(r,i) if palette else color for r in range(len(rings)) for i in range(n)]
        faces=[]
        for r in range(len(rings)-1):
            for i in range(n if closed else n-1):
                j=(i+1)%n
                faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
        if cap_ends:
            faces.append(tuple(reversed(range(n))))
            faces.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
        if not closed:
            count=len(rings)
            if (Vector(rings[0](angles[0]))-Vector(rings[-1](angles[0]))).length < 1e-9:
                count-=1
            if count>=3:
                faces += [tuple(r*n for r in reversed(range(count))),
                          tuple(r*n+n-1 for r in range(count))]
        self.add(verts,faces,colors=colors)

    def tone(self, vi):
        tone=self.colors[vi]
        if tone in ["bone","petrol"]:
            gain=[0,.025,.06,.11,.035,.015][(vi*7+len(self.name))%6]
            tone=common.mix(tone,"charcoal" if tone=="bone" else "bone",gain)
        return common.rgba(tone)

    def finish(self, root):
        if common.POLISH is not None:
            return self._finish_polished(root)
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata([xyz(v) for v in self.verts],[],self.faces)
        mesh.update()
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        attr=mesh.color_attributes.new(name="Color",type="FLOAT_COLOR",domain="CORNER")
        for poly in mesh.polygons:
            poly.use_smooth=self.smooth
            for li in poly.loop_indices:
                attr.data[li].color=self.tone(mesh.loops[li].vertex_index)
        mesh.color_attributes.active_color=attr
        mesh.materials.append(material(self.slot))
        obj=bpy.data.objects.new(self.name,mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent=root
        tri=obj.modifiers.new("FixedTriangles","TRIANGULATE")
        tri.quad_method="FIXED"
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=tri.name)
        return obj


    def _finish_polished(self, root):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata([xyz(v) for v in self.verts],[],self.faces)
        mesh.update()
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        col=bm.loops.layers.float_color.new("Color")
        bm.verts.index_update()
        for f in bm.faces:
            for loop in f.loops:
                loop[col]=self.tone(loop.vert.index)
        part=common.Part(self.name)
        part.bm.free()
        part.bm,part.col=bm,col
        part.slots=[self.slot]
        part.bevel,part.subsurf=self.bevel,self.subsurf
        bpy.data.meshes.remove(mesh)
        bpy.data.materials.get(self.slot) or material(self.slot)
        obj=part.to_object()
        obj.parent=root
        obj.location=(0,0,0)
        return obj


def empty(name, loc, root):
    return common.empty(name,xyz(loc),root)


def angles(n,start=0,end=math.tau,closed=False):
    return [start+(end-start)*i/n for i in range(n if closed else n+1)]


def register(name, parts, sockets, budget=P, notes=""):
    ASSETS[name]={"parts":parts,"sockets":sockets,"budget":budget,"notes":notes}


register("impeller_rim_sector",["RimSector"],{"socket_join_a":[0,12,0],"socket_join_b":[12/math.sqrt(2),12/math.sqrt(2),0]})
register("impeller_hub",["Hub"],{f"socket_vane_{i}":[2.5*math.sin(i*math.tau/5),2.5*math.cos(i*math.tau/5),0] for i in range(5)})
for name,part in [("impeller_vane","Vane"),("impeller_vane_chipped","VaneChipped")]:
    register(name,[part],{"socket_hub":[0,0,0]})
register("intake_petal",["Petal"],{"socket_throat":[0,10,0]})
register("intake_throat",["Throat"],{"socket_spine":[0,1,0],"socket_bell":[0,0,0]})
register("intake_spine_segment",["Spine"],{"socket_next":[0,6,0]})
register("strut_tall",["Strut"],{"socket_wall":[0,2.5,.3],"socket_foot_l":[-.9,0,0],"socket_foot_r":[.9,0,0]})
register("strut_bent",["StrutBent"],{"socket_wall":[.5,1.8,.3],"socket_foot":[0,0,0]})
register("cart_body",["Hopper","Chassis"],{**{f"socket_wheel_{p}":[x,.3,z] for p,x,z in [("fl",-.74,-.95),("fr",.74,-.95),("rl",-.74,.95),("rr",.74,.95)]},"socket_tow":[0,.35,-1.6]},notes="Chassis is a named part reference; its steel geometry is merged into Hopper for one draw.")
register("cart_wheel",["Tyre"],{},notes="Axle is local X, origin axle-centre.")
register("lamp_straight_module",["Rail","Bracket","Hood","Lens"],{"socket_next":[2.667,0,0],"socket_wall":[1.333,0,.15]},S)
register("lamp_curve_module",["Rail","Bracket","Hood","Lens"],{"socket_next":[3,0,-.35],"socket_wall":[1.5,0,.15]},S)
register("shell_crescent",["Crescent"],{"socket_ground":[0,0,0]})
register("shell_saddle",["Saddle"],{"socket_ground":[0,0,0]})
register("breach_rim_sector",["RimSector"],{"socket_join_a":[0,0,-3],"socket_join_b":[3,0,-3]},notes="P-R6: rectangular drum rim half-side; mirrored pairs, four cardinal rotations. Original 45-degree circular geometry superseded by the current rectangle skin.")
for c in "abc":
    register("breach_wedge_"+c,["Wedge"+c.upper()],{"socket_membrane":[0,0,3]},notes="P-R6: rectangular membrane third, nominal 6x6 authoring frame. Placement uses the separately baked 12x12 or 14x10 variants; thickness, dish, cracks and chip stay in metre-space. Only the rim uses assembly X/Z scale.")
register("breach_tab",["StateTab"],{"socket_mount":[0,0,0]},notes="P-R6: mint only; raised pose and rupture hiding are in the assembly manifest.")


def annulus(s, rin,rout,depth,n=20, arc=(0,math.tau), axis="z"):
    closed=abs(arc[1]-arc[0]-math.tau)<1e-6
    aa=angles(n,*arc,closed=closed)
    if axis=="z":
        rings=[lambda a,r=r,z=z:(r*math.sin(a),r*math.cos(a),z)
               for r,z in [(rin,-depth/2),(rout,-depth/2),(rout,depth/2),(rin,depth/2),(rin,-depth/2)]]
    else:
        rings=[lambda a,r=r,y=y:(r*math.sin(a),y,r*math.cos(a))
               for r,y in [(rin,0),(rout,0),(rout,depth),(rin,depth),(rin,0)]]
    s.rings(rings,aa,closed=closed,palette=lambda r,i:"petrol" if r in [3,4] else "bone")
    if axis=="z":
        seam_rings=[lambda a,r=r:(r*math.sin(a),r*math.cos(a),-depth/2-.0005) for r in [rin+.10,rin+.15]]
        s.rings(seam_rings,aa,color="ancient",closed=closed)


def cast_vane(s,chipped):
    yy=[0,1.6,3.6,5.8,8]
    centers=[0,.24,.68,.94,.65]
    widths=[1.25,2.4,3.5,3.6,2.75]
    verts=[]
    for back in [False,True]:
        for i,y in enumerate(yy):
            for j,t in enumerate([-1,0,1]):
                x=centers[i]+t*widths[i]/2
                h=(.15+.45*(1-abs(t)))*math.sin(math.pi*(i+.8)/5.8)
                yp=y-1.5 if chipped and i==4 and j==2 else y
                xp=x-1.0 if chipped and i==4 and j==2 else x
                verts.append((xp,yp,(h if not back else h-1.2)))
    faces=[]
    for layer in range(2):
        o=15*layer
        for i in range(4):
            for j in range(2):
                k=o+i*3+j
                faces.append((k,k+1,k+4,k+3))
    edge=[0,1,2,5,8,11,14,13,12,9,6,3]
    faces += [(edge[i],edge[(i+1)%len(edge)],edge[(i+1)%len(edge)]+15,edge[i]+15) for i in range(len(edge))]
    xs=[v[0] for v in verts]; zs=[v[2] for v in verts]
    lo,hi=min(xs),max(xs); zl,zh=min(zs),max(zs)
    verts=[((x-lo)/(hi-lo)*3.6-1.8,y,(z-zl)/(zh-zl)*1.2-.6) for x,y,z in verts]
    s.add(verts,faces,colors=["petrol" if i<15 else "bone" for i in range(30)])
    seam=[(-.045,y,-.59+.13*math.sin(y*.4)) for y in [0,3.6,8]]+[(.045,y,-.59+.13*math.sin(y*.4)) for y in [0,3.6,8]]
    s.add(seam,[(0,1,4,3),(1,2,5,4)],"ancient")


def rescale(s,size,bottom=True):
    lows=[min(v[k] for v in s.verts) for k in range(3)]
    highs=[max(v[k] for v in s.verts) for k in range(3)]
    s.verts=[tuple((v[k]-lows[k])/(highs[k]-lows[k])*size[k]-(0 if bottom and k==1 else size[k]/2) for k in range(3)) for v in s.verts]


def build(name,out=None):
    common.reset()
    use_polish(name)
    PARTS.clear()
    root=common.empty(name)
    spec=ASSETS[name]
    slot="enamel" if name.startswith(("impeller","intake","shell")) else ("elastomer" if name=="cart_wheel" else "steel")
    part=spec["parts"][0]
    s=Surface(part,slot,smooth=name.startswith(("intake","shell")) or name=="cart_wheel")
    extra=[]
    if name=="impeller_rim_sector":
        annulus(s,10.5,12,3,6,(0,math.pi/4))
    elif name=="impeller_hub":
        annulus(s,1.1,2.5,3,20)
    elif name.startswith("impeller_vane"):
        cast_vane(s,name.endswith("chipped"))
    elif name=="intake_petal":
        aa=angles(8,-math.pi/3,math.pi/3)
        profile=[(5,0),(4.7,1.9),(3.45,5.0),(1.45,10)]
        def petal_at(a,r,y,inside=False):
            lift=2.7*(1-y/10)**2*math.sin(1.5*a)**2
            radius=r-.35 if inside else r
            return (radius*math.sin(a),y+lift,radius*math.cos(a))
        rings=[lambda a,r=r,y=y:petal_at(a,r,y) for r,y in profile]
        rings += [lambda a,r=r,y=y:petal_at(a,r,y,True) for r,y in reversed(profile)]
        rings += [rings[0]]
        s.rings(rings,aa,palette=lambda r,i:"petrol" if 4<=r<=7 else "bone")
        strip=[]
        for r,y in profile:
            for a in [-math.pi/3+.018,-math.pi/3+.030]:
                strip.append(petal_at(a,r-.015,y))
        s.add(strip,[(i,i+1,i+3,i+2) for i in [0,2,4]],"ancient")
    elif name=="intake_throat":
        aa=angles(16,closed=True)
        profile=[(1.5,0),(1.5,.94),(1.46,.98),(1.46,1.06),(1.5,1.10),(1.5,2),(.95,2),(.95,0),(1.5,0)]
        aa=angles(12,closed=True)
        s.rings([lambda a,r=r,y=y:(r*math.sin(a),y,r*math.cos(a)) for r,y in profile],aa,closed=True,
                palette=lambda r,i:"ancient" if r==2 else ("petrol" if r in [3,6,7] else "bone"))
    elif name=="intake_spine_segment":
        profile=[(.8,0),(.8,2.8),(1.1,2.8),(1.1,3.2),(.8,3.2),(.8,6)]
        s.rings([lambda a,r=r,y=y:(r*math.sin(a),y,r*math.cos(a)) for r,y in profile],angles(12,closed=True),closed=True,cap_ends=True,
                palette=lambda r,i:"ancient" if i==0 else ("petrol" if r==2 else "bone"))
    elif name=="strut_tall":
        s.beam((-.85,.15,0),(-.85,2.82,0),.35,.45)
        s.beam((-.85,2.82,0),(.85,.15,0),.35,.45)
        s.beam((-.85,.42,0),(.85,.42,0),.35,.45)
        for x in [-.85,.85]:
            s.box((.7,.15,.6),(x,.075,0),"bone")
        for x,y in [(-.85,.45),(-.85,2.55),(.72,.4)]:
            s.box((.43,.3,.52),(x,y,0),"charcoal")
            s.box((.08,.08,.025),(x,y,-.275),"b2b4b0")
        rescale(s,(2.4,3,.6))
    elif name=="strut_bent":
        s.beam((-.3,.15,0),(-.3,1.08,0),.35,.45)
        s.beam((-.3,1.08,0),(.65,1.82,0),.35,.45)
        s.box((.7,.15,.6),(-.3,.075,0),"bone")
        s.prism([(-.6,.8),(0,.8),(0,1.4)],.1,"bone",offset=(0,0,-.28))
        for x,y in [(-.3,.8),(.65,1.82)]:
            s.box((.5,.25,.55),(x,y,0),"charcoal")
            s.box((.09,.09,.02),(x,y,-.285),"b2b4b0")
        rescale(s,(2,2,.6))
    elif name=="cart_body":
        rings=[[(x*.56,.52,z*1.1) for x,z in [(-1,-1),(1,-1),(1,1),(-1,1)]],
               [(-.85,1.4,-1.5),(.85,1.37,-1.5),(.79,1.4,1.5),(-.85,1.32,1.5)],
               [(-.77,1.4,-1.42),(.77,1.37,-1.42),(.71,1.4,1.42),(-.77,1.32,1.42)],
               [(x*.48,.60,z*1.02) for x,z in [(-1,-1),(1,-1),(1,1),(-1,1)]]]
        verts=[v for ring in rings for v in ring]
        faces=[(0,3,2,1),(12,13,14,15)]
        for r in range(3):
            faces += [(r*4+i,r*4+(i+1)%4,(r+1)*4+(i+1)%4,(r+1)*4+i) for i in range(4)]
        s.add(verts,faces,colors=["petrol"]*4+["bone"]*4+["bone"]*4+["charcoal"]*4)
        start=len(s.verts)
        for x in [-.5,.5]:
            s.box((.16,.16,2.8),(x,.37,0),"charcoal")
        for z in [-.95,.95]:
            s.box((1.48,.18,.16),(0,.3,z),"b2b4b0")
        s.box((.2,.35,2.4),(0,.175,0))
        PARTS["Chassis"]={"vertex_range":[start,len(s.verts)],"reference_position":[0,.3,0],"merged_mesh":"Hopper"}
    elif name=="cart_wheel":
        aa=angles(16,closed=True)
        profile=[(.12,-.11),(.25,-.11),(.30,-.07),(.30,.07),(.25,.11),(.12,.11)]
        s.rings([lambda a,r=r,x=x:(x,r*math.cos(a),r*math.sin(a)) for r,x in profile],aa,closed=True,cap_ends=True,
                palette=lambda r,i:"303633" if r in [0,5] else ("charcoal" if i%2 else "333936"))
    elif name.startswith("lamp_"):
        s.smooth=True
        curved="curve" in name
        length=3 if curved else 2.667
        if curved:
            path=[(0,0,0),(.75,0,.175),(1.5,0,.175),(2.25,0,0),(3,0,-.35)]
            verts=[]
            for x,y,z in path:
                verts.extend([(x,y+dy,z+dz) for dy,dz in [(-.09,-.09),(.09,-.09),(.09,.09),(-.09,.09)]])
            faces=[(3,2,1,0),(16,17,18,19)]
            for i in range(4):
                faces += [(4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j) for j in range(4)]
            s.add(verts,faces)
        else:
            s.box((length,.18,.18),(length/2,0,0))
        for partname,size,center,col in [("Bracket",(.2,.8,.3),(length/2,-.4,0),"petrol"),
                                       ("Hood",(.65,.3,.65),(length/2,-.95,0),"petrol")]:
            start=len(s.verts)
            if partname=="Hood":
                v=[(length/2+x,y,z) for y,w in [(-.8,.22),(-1.1,.325)] for x,z in [(-w,-w),(w,-w),(w,w),(-w,w)]]
                s.add(v,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],col)
            else:
                s.box(size,center,col)
            PARTS[partname]={"vertex_range":[start,len(s.verts)],"reference_position":list(center),"merged_mesh":"Rail"}
        lens=Surface("Lens","glass",smooth=True)
        lens.box((.45,.12,.45),(length/2,-1.04,0),"eeeeeb")
        extra.append(lens)
    elif name=="shell_crescent":
        aa=angles(12,-math.pi,0)
        def shell_at(a,z,inset):
            normal=Vector((math.cos(a)/1.5,math.sin(a)/1.3)).normalized()
            return (1.5*math.cos(a)-normal.x*inset,1.3+1.3*math.sin(a)-normal.y*inset,z)
        profile=[(-.8,0),(-.72,.04),(.72,.04),(.8,0),(.8,.18),(.72,.22),(-.72,.22),(-.8,.18),(-.8,0)]
        rings=[lambda a,z=z,inset=inset:shell_at(a,z,inset) for z,inset in profile]
        s.rings(rings,aa,palette=lambda r,i:"petrol" if 4<=r<=7 else "bone")
        seam=[lambda a,z=z:shell_at(a,z,.0395) for z in [-.69,-.655]]
        s.rings(seam,aa,color="ancient")
    elif name=="shell_saddle":
        verts=[]
        for layer in range(2):
            for i in range(5):
                x=-1.1+i*.55
                for j in range(4):
                    z=-.9+j*.6
                    if i==4 and j==0:
                        z+=.27
                    if i==0 and j==3:
                        x+=.21
                    y=.16+.30*(x/1.1)**2+.09*math.sin(z*1.5)-layer*.12
                    verts.append((x,y,z))
        faces=[]
        for layer in range(2):
            for i in range(4):
                for j in range(3):
                    k=layer*20+i*4+j
                    faces.append((k,k+4,k+5,k+1))
        edge=[0,4,8,12,16,17,18,19,15,11,7,3,2,1]
        faces += [(edge[i],edge[(i+1)%len(edge)],edge[(i+1)%len(edge)]+20,edge[i]+20) for i in range(len(edge))]
        upper=[v[1] for v in verts[:20]]
        low,high=min(upper),max(upper)
        tops=[(x,.12+(y-low)/(high-low)*.48,z) for x,y,z in verts[:20]]
        verts=tops+[(x,y-.12,z) for x,y,z in tops]
        s.add(verts,faces,colors=["bone"]*20+["petrol"]*20)
        strip=[]
        for i in range(5):
            for t in [.45,.51]:
                a=Vector(tops[i*4+1]); b=Vector(tops[i*4+2])
                p=a.lerp(b,t); p.y+=.0005
                strip.append(tuple(p))
        s.add(strip,[(i,i+1,i+3,i+2) for i in [0,2,4,6]],"ancient")
    elif name=="breach_rim_sector":
        s.prism([(0,-3),(3,-3),(3.6,-3),(3.35,-3.6),(0,-3.6)],.35,"charcoal",axis="y",offset=(0,-.175,0))
        s.box((2.8,.035,.12),(1.4,-.0175,-3.44),"b2b4b0")
    elif name.startswith("breach_wedge"):
        c=name[-1]
        outline=wedge_outline(c,6,6)
        pivot=wedge_pivot(c,6,6)
        s.prism(outline,.12,"bone",axis="y")
        s.verts=[(x-pivot[0],y-.06-.18*(1-max(abs(x),abs(z))/3),z-pivot[2]) for x,y,z in s.verts]
        spec["sockets"]={"socket_membrane":[-pivot[0],0,-pivot[2]]}
    elif name=="breach_tab":
        s.box((.9,.12,.55),(.45,.06,0),"mint")
    else:
        raise ValueError(name)
    mesh=s.finish(root)
    for surface in extra:
        surface.finish(root)
    for pname,row in PARTS.items():
        empty(pname,row["reference_position"],root)
    for socket,loc in spec["sockets"].items():
        empty(socket,loc,root)
    bpy.context.view_layer.update()
    path=Path(out) if out else MODELS/(name+".glb")
    common.export(root,str(path))
    metrics=gltf_metrics(path)
    limits=spec["budget"]
    assert all(metrics[k]<=cap for k,cap in zip(["triangles","vertices","draws"],limits)), (name,metrics,limits)
    result={**spec,**metrics,"file":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
            "merged_parts":dict(PARTS),"root":name,"material_resources":{m:"res://assets/materials/dig_mechanical/"+m+".tres" for m in metrics["materials"]}}
    print("MDM_EXPORT",name,json.dumps(metrics,sort_keys=True))
    return result


def gltf_metrics(path):
    data=path.read_bytes()
    length=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+length])
    tris=verts=draws=0
    lo=[float("inf")]*3; hi=[-float("inf")]*3
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            p=doc["accessors"][prim["attributes"]["POSITION"]]
            verts+=p["count"]
            tris+=doc["accessors"][prim["indices"]]["count"]//3
            draws+=1
            for k in range(3):
                lo[k]=min(lo[k],p["min"][k]); hi[k]=max(hi[k],p["max"][k])
    return {"triangles":tris,"vertices":verts,"draws":draws,"materials":[m["name"] for m in doc["materials"]],
            "bounds":{"min":lo,"max":hi,"size":[hi[k]-lo[k] for k in range(3)]},
            "nodes":[n["name"] for n in doc["nodes"]]}


def instance(file,position=(0,0,0),rotation=(0,0,0),scale=(1,1,1),name=None):
    return {"file":file+".glb","name":name or file,"position":list(position),"rotation_degrees":list(rotation),"scale":list(scale)}


def assemblies():
    imp=[instance("impeller_rim_sector",(0,12,0),(0,0,i*45),name="rim_%d"%i) for i in range(8)]
    imp += [instance("impeller_hub",(.8,12,0))]
    for i in range(5):
        a=i*math.tau/5
        imp.append(instance("impeller_vane_chipped" if i==2 else "impeller_vane",(.8+2.5*math.sin(a),12+2.5*math.cos(a),0),(0,0,-i*72),name="vane_%d"%i))
    intake=[instance("intake_petal",(0,10,0),(0,i*120,0),name="petal_%d"%i) for i in range(3)]
    intake += [instance("intake_throat",(0,19,0))]
    intake += [instance("intake_spine_segment",(0,i*6,0),name="spine_%d"%i) for i in range(4)]
    cart=[instance("cart_body")]+[instance("cart_wheel",loc,name=key) for key,loc in ASSETS["cart_body"]["sockets"].items() if key.startswith("socket_wheel")]
    out={"impeller_assembly":{"instances":imp,"sockets":{"socket_wall":[0,12,1.5],"socket_scale_ball":[-15,1,-2]},"placement":"Non-colliding background. Bury at least 30 percent of the lower arc; preserve all five vane silhouettes."},
         "intake_assembly":{"instances":intake,"sockets":{"socket_ceiling":[0,24,0],"socket_waking_axis":[0,0,0],"socket_bell":[0,10,0]},"placement":"Non-colliding background outside the play rectangle plus 8 m. No approved central well."},
         "cart_assembly":{"instances":cart,"sockets":{}},
         "lamp_straight_assembly":{"instances":[instance("lamp_straight_module",(i*2.667,0,0),name="lamp_%d"%i) for i in range(3)],"sockets":{}},
         "lamp_curve_assembly":{"instances":[instance("lamp_curve_module",(i*3,0,-i*.35),name="lamp_%d"%i) for i in range(2)],"sockets":{}}}
    for width,depth in [(12,12),(14,10)]:
        sx,sz=width/6,depth/6
        rim=[]
        for side in range(4):
            for mirror in [-1,1]:
                rim.append({**instance("breach_rim_sector",rotation=(0,side*90,0),scale=(mirror,1,1),name=f"rim_{side}_{mirror}"),"assembly_scale":[sx,1,sz]})
        wedges=[instance(f"breach_wedge_{c}_{width}x{depth}",wedge_pivot(c,width,depth),name="wedge_"+c) for c in "abc"]
        tablocs=[[0,0,-depth/2-.3],[width/2+.3,0,0],[0,0,depth/2+.3],[-width/2-.3,0,0]]
        tabs=[instance("breach_tab",loc,(0,90-i*90,math.degrees(math.asin(.4/.9))),name="tab_"+"nesw"[i]) for i,loc in enumerate(tablocs)]
        out[f"breach_assembly_{width}x{depth}"]={"root":"breach_assembly","cover_rectangle":[width,depth],"instances":rim+wedges+tabs,
            "sockets":{**{"socket_tab_"+n:tablocs[i] for i,n in enumerate("nesw")},"socket_approach":[0,0,-depth/2-5],"socket_void":[0,-.3,0]},
            "poses":{"ready":{"tabs":"raised mint","membrane_visible":True},"rupture":{"duration_s":.45,"state_at_t0":"hide tabs and remove gameplay cover immediately through the existing swap owner", "keys":[{"time":0,"wedge_pitch_x":0,"wedge_drop_y":0},{"time":.18,"wedge_pitch_x":55,"wedge_drop_y":-1.8},{"time":.45,"wedge_pitch_x":105,"wedge_drop_y":-7,"wedges_visible":False}]},"spent":{"membrane_visible":False,"tabs_visible":False},"stage_reset":{"membrane_visible":True,"tabs":"raised mint"}},
            "ruling":"P-R6: existing slam-anywhere eligibility, mint tabs, no slate/unready state. Cosmetic components only; gameplay swap remains authoritative."}
    return out


def wedge_pivot(c,width,depth):
    return {"a":(0,0,-depth/2),"b":(width/2,0,0),"c":(-width/2,0,0)}[c]


def wedge_outline(c,width,depth):
    x,z=width/2,depth/2
    k=z/x
    inset=.05*math.sqrt(1+k*k)
    return {"a":[(0,-inset),(-x+inset/k,-z),(-.45,-z),(-.45,-z+.55),(.45,-z+.55),(.45,-z),(x-inset/k,-z)],
            "b":[(.05,inset-k*.05),(x,-z+inset),(x,z),(.05,z)],
            "c":[(-.05,inset-k*.05),(-.05,z),(-x,z),(-x,-z+inset)]}[c]


def baked_wedge(base,width,depth,out=None):
    x=width/2; z=depth/2; c=base[-1]
    outline=wedge_outline(c,width,depth)
    pivot=wedge_pivot(c,width,depth)
    name=f"{base}_{width}x{depth}"
    common.reset()
    use_polish(name)
    root=common.empty(name)
    s=Surface(ASSETS[base]["parts"][0],"steel")
    s.prism(outline,.12,"bone",axis="y")
    s.verts=[(a-pivot[0],b-.06-.18*(1-max(abs(a)/x,abs(d)/z)),d-pivot[2]) for a,b,d in s.verts]
    s.finish(root)
    empty("socket_membrane",(-pivot[0],0,-pivot[2]),root)
    path=Path(out) if out else MODELS/(name+".glb")
    common.export(root,str(path))
    metrics=gltf_metrics(path)
    assert metrics["triangles"]<=P[0] and metrics["vertices"]<=P[1] and metrics["draws"]==1
    spec={**ASSETS[base],"sockets":{"socket_membrane":[-pivot[0],0,-pivot[2]]},"notes":"P-R6 baked rectangle variant: physical chip .9x.55, dish .18, thickness .12; outer-edge midpoint pivot."}
    ASSETS[name]=spec
    return {**spec,**metrics,"file":path.name,"root":name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"merged_parts":{},"material_resources":{"steel":"res://assets/materials/dig_mechanical/steel.tres"}}


def main(name=None):
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument("--all",action="store_true")
    parser.add_argument("--out")
    args=parser.parse_args(argv)
    if name:
        if "x" in name and name.startswith("breach_wedge_"):
            base,dims=name.rsplit("_",1)
            w,d=map(int,dims.split("x"))
            baked_wedge(base,w,d,args.out)
        else:
            build(name,args.out)
    elif args.all:
        rows={n:build(n) for n in list(ASSETS)}
        for width,depth in [(12,12),(14,10)]:
            for c in "abc":
                row=baked_wedge("breach_wedge_"+c,width,depth)
                rows[row["root"]]=row
        manifest={"schema":"scrapkeep-dig-mechanical/1","units":"metres, Godot +Y up, -Z forward", "ruling":"P-R6 overrides the original circular opening and unready/slate poses; landmarks are non-colliding.",
                  "assets":rows,"assemblies":assemblies(),"assembly_transform_order":"geometry -> local scale -> Godot YXZ Euler rotation -> position -> assembly_scale (if present)",
                  "integration_notes":["No runtime loader, placement, registry or gameplay writes in this unit.","Named reference nodes identify ranges of merged steel geometry; they do not add a mesh draw.","Every material resource is shared by slot, not by file or state.","Blue seams are unlit inlays, not attack cues.","Landmark and plate placement/collision belong to the integration owner."]}
        MODELS.mkdir(parents=True,exist_ok=True)
        (MODELS/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
        print("MDM_BATCH: PASS",len(rows),"GLBs")
    else:
        parser.error("use --all or a basename recipe")


if __name__=="__main__":
    main()
