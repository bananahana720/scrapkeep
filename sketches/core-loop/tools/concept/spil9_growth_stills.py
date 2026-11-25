"""COMPANION-GROWS greybox stills: SPIL-9 per seated module and per mark, plus an assist ring.

Run from sketches/core-loop:
  blender -b -P tools/concept/spil9_growth_stills.py -- OUT.png FILES MARK FX
FILES is a comma list under assets/models/companion/ (a piece may take @x:y:z, its socket in
Blender metres, e.g. ram_prow.glb@0.29:0:0.225); MARK is 1-5 (add-ons from Companion.MARKS);
FX is none, ring (class 1 assist) or big (class 5). Greybox only: the add-ons are primitives
standing in for the rig and effects threads' art.
"""
import bpy, sys, math, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender'))
import cycles_device
args=sys.argv[sys.argv.index('--')+1:]
out, files, rank, fx = args[0], args[1].split(','), int(args[2]), args[3]
M='assets/models/companion/'
bpy.ops.wm.read_factory_settings(use_empty=True)
for f in files:
    f,_,at=f.partition('@')
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=M+f)
    if at:
        for o in set(bpy.data.objects)-before:
            if o.parent is None: o.location=tuple(float(v) for v in at.split(':'))
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
s=[1.0,1.1,1.2,1.3,1.4][rank-1]
root=bpy.data.objects.new('Root',None); bpy.context.scene.collection.objects.link(root)
for o in bpy.data.objects:
    if o.parent is None and o is not root: o.parent=root
def mat(name,col,em=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=col
    if em: b.inputs['Emission Color'].default_value=col; b.inputs['Emission Strength'].default_value=em
    return m
grey=mat('grey',(0.55,0.55,0.6,1)); glow=mat('glow',(1.0,0.62,0.15,1),6); cyan=mat('cyan',(0.2,0.85,1,1),5)
def add(obj,m):
    obj.data.materials.append(m); obj.parent=root
if rank>=2:
    for x in (-1,1):
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x*0.62,0.05,0.18)); o=bpy.context.object
        o.scale=(0.05,0.32,0.14); o.rotation_euler=(0,x*0.5,0); add(o,grey)
if rank>=3:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36,minor_radius=0.03,location=(0,0,0.62)); add(bpy.context.object,cyan)
if rank>=4:
    for x in (-1,1):
        bpy.ops.mesh.primitive_cone_add(radius1=0.09,radius2=0.0,depth=0.6,location=(x*0.25,0.62,0.05),rotation=(math.radians(-90),0,0)); add(bpy.context.object,glow)
if rank>=5:
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16,location=(0,-0.05,0.3)); add(bpy.context.object,glow)
    bpy.ops.mesh.primitive_cone_add(radius1=0.12,radius2=0,depth=0.45,location=(0,0.05,0.62),rotation=(math.radians(20),0,0)); add(bpy.context.object,grey)
root.scale=(s,s,s)
bpy.ops.mesh.primitive_plane_add(size=40,location=(0,0,-0.6)); add_f=bpy.context.object; add_f.data.materials.append(mat('floor',(0.08,0.085,0.1,1)))
if fx!='none':
    r={'ring':2.6,'big':4.4}[fx]
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=0.06*r/2,location=(0,0,-0.25)); bpy.context.object.data.materials.append(cyan)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3,depth=0.6,location=(r*0.7,-r*0.5,0)); bpy.context.object.data.materials.append(mat('red',(0.9,0.15,0.1,1),2))
    bpy.ops.mesh.primitive_circle_add(radius=1.4,fill_type='NGON',location=(r*0.7,-r*0.5,-0.2)); bpy.context.object.data.materials.append(mat('warn',(1,0.1,0.05,1),8))
cam=bpy.data.cameras.new('c'); c=bpy.data.objects.new('c',cam); bpy.context.scene.collection.objects.link(c)
d=3.4 if fx=='none' else 9.5
c.location=(d*0.75,-d*0.95,d*0.6); 
import mathutils
c.rotation_euler=(mathutils.Vector((0,0,0.1))-c.location).to_track_quat('-Z','Y').to_euler()
bpy.context.scene.camera=c
for loc,e in (((3,-3,5),400),((-4,2,3),150)):
    l=bpy.data.lights.new('l','AREA'); l.energy=e; l.size=3; lo=bpy.data.objects.new('l',l); lo.location=loc
    lo.rotation_euler=(mathutils.Vector((0,0,0))-mathutils.Vector(loc)).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.collection.objects.link(lo)
w=bpy.data.worlds.new('w'); w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(0.03,0.035,0.05,1); bpy.context.scene.world=w
sc=bpy.context.scene; sc.render.engine='CYCLES'; cycles_device.use(sc); sc.cycles.samples=24; sc.cycles.use_denoising=True
sc.render.resolution_x=560; sc.render.resolution_y=420; sc.render.filepath=out; sc.view_settings.view_transform='AgX'
bpy.ops.render.render(write_still=True)
