"""Salvaged rescue cage, metres; no physics. Gate/latch are state-owned parts.
Godot (X,Y,Z) maps to Blender (X,-Z,Y). Pilot is fitted from its existing GLB.
"""
import math
import os
import sys
import bmesh
import bpy
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
from common import Part
common.reset()
common.SLOTS["cage_steel"] = {"vc": True, "rough": 0.72, "metal": 0.25}
common.SLOTS["cage_signal"] = {"vc": True, "rough": 0.72, "metal": 0.25}
import polish
polish.enable(detail=1, bevel=0, bake_slots=("cage_steel",))
root = common.empty("RescueCage")

def g(x, y, z):
    return (x, -z, y)

def rod(p, a, b, radius=0.07, color="charcoal"):
    p.rod("cage_steel", g(*a), g(*b), radius, segs=6, color=color)

def panel(p, w, h, depth, at, color, slot="cage_steel"):
    c = min(w, h) * 0.18
    outline = [(-w/2+c,-h/2),(w/2-c,-h/2),(w/2,-h/2+c),
               (w/2,h/2-c),(w/2-c,h/2),(-w/2+c,h/2),(-w/2,h/2-c),(-w/2,-h/2+c)]
    p.prism(slot, outline, depth, matrix=common.mtx(g(*at),(math.pi/2,0,0)), color=color)

def finish(p, origin=(0,0,0)):
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    p.to_object(origin=g(*origin), parent=root)

p = Part("CageFrame")
for x in (-1.4, 1.4):
    for z in (-1.4, 1.4):
        rod(p, (x,0.12,z), (x,3.2,z), 0.14, "petrol")
        panel(p,0.42,0.28,0.4,(x,0.14,z),"oxide")
    for y in (0.15,3.2):
        rod(p,(x,y,-1.4),(x,y,1.4),0.12,"petrol")
for y in (0.15,3.2):
    rod(p,(-1.4,y,-1.4),(1.4,y,-1.4),0.12,"petrol")
    rod(p,(-1.4,y,1.4),(1.4,y,1.4),0.12,"petrol")
for x in (-1.4,1.4):
    panel(p,0.33,0.32,0.08,(x,2.8,1.53),"bone")
finish(p)
p = Part("CageGate")
for x in (-1.4,1.4):
    for z in (-0.7,0,0.7):
        rod(p,(x,0.2,z),(x,3.15,z))
for x in (-0.7,0,0.7):
    rod(p,(x,0.2,-1.4),(x,3.15,-1.4))
rod(p,(-1.4,0.55,-1.43),(1.4,2.7,-1.43),0.06,"copper")
for x in (-1.15,1.15):
    rod(p,(x,0.2,1.43),(x,3.05,1.43),0.095,"copper")
for y in (0.2,3.05):
    rod(p,(-1.15,y,1.43),(1.15,y,1.43),0.095,"petrol")
for x in (-0.6,0,0.6):
    rod(p,(x,0.3,1.43),(x,2.95,1.43))
finish(p)
p = Part("CageLatch")
panel(p,0.72,0.56,0.22,(0,1.45,1.6),"mint","cage_signal")
panel(p,0.25,0.28,0.025,(0,1.45,1.73),"charcoal","cage_signal")
finish(p,(0,1.45,1.6))
p = Part("CageSeat")
panel(p,1.18,0.16,0.85,(0,0.67,-0.25),"petrol")
for x in (-0.44,0.44):
    rod(p,(x,0.08,-0.53),(x,0.62,-0.53),0.075,"oxide")
    rod(p,(x,0.08,0.05),(x,0.62,0.05),0.075,"oxide")
panel(p,1.12,0.65,0.1,(0,0.98,-0.68),"bone")
finish(p)
bpy.context.view_layer.update()
tris=common.tri_total(root)
draws=sum(len(o.data.materials) for o in common.tree(root) if o.type=="MESH")
print("CAGE_BUDGET",tris,"T",draws,"D")
assert tris <= 1100 and draws == 4
opts=common.args()
common.export(root,opts["out"] or os.path.join(common.MODELS,"world_one","rescue_cage.glb"))

if opts["render"]:
    from mathutils import Vector
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=16
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.render.resolution_x=800
    scene.render.resolution_y=640
    scene.view_settings.view_transform="Standard"
    world=bpy.data.worlds.new("PreviewSky")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=common.rgba("bone")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=0.65
    scene.world=world
    bpy.ops.mesh.primitive_plane_add(size=60,location=(0,0,-0.05))
    bpy.context.object.data.materials.append(common._flat("PreviewGround","sandstone"))
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(common.MODELS,"pilot_rivet_anim.glb"))
    imported=set(scene.objects)-before
    seat=common.empty("PreviewPilot",g(0,1.25,-0.25))
    seat.scale=(1.6,1.6,1.6)
    seat.rotation_euler.z=math.pi
    for obj in imported:
        if obj.parent not in imported:
            obj.parent=seat
    ref=Part("ReferenceBall2m")
    ref.uv("paint",1,u=16,v=8,loc=g(3.3,1,0),color="bone")
    ref.ring("paint",0.985,1,0.1,segs=16,loc=g(3.3,1,0),color="charcoal")
    ref.to_object()
    lamp=bpy.data.objects.new("PreviewLight",bpy.data.lights.new("PreviewLight","AREA"))
    lamp.data.energy=1100
    lamp.data.size=6
    scene.collection.objects.link(lamp)
    lamp.location=g(3,7,5)
    common._look(lamp,g(0,1.5,0))
    cam=bpy.data.objects.new("PreviewCamera",bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    cam.data.type="ORTHO"
    cam.data.ortho_scale=7.4
    scene.camera=cam
    os.makedirs(opts["render"],exist_ok=True)
    for label,at in [("front",(1,3.6,11)),("side",(11,3.6,0)),("three_quarter",(8,5,9))]:
        cam.location=g(*at)
        common._look(cam,g(1,1.5,0))
        scene.render.filepath=os.path.join(opts["render"],"rescue_cage_"+label+".png")
        bpy.ops.render.render(write_still=True)
