import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
import polish
from common import Part

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.5, "metal": 0.35}
root = common.empty("AnchorCrew")
PAINT = "53686d"
WORN = "a8aaa3"


def g(x, y, z):
    return (x, -z, y)


BONES = [("CrewBrace", (0, -0.55, 0)), ("AnchorFeet", (0, -1.1, 0)),
         ("AnchorHead", (0, 1.3, 0)), ("WinchPost", (0, 1.2, -1.3)),
         ("WinchClutch", (0.45, 0.9, -1.3)),
         ("ClutchTab0", (0.46, 1.01, -1.3)),
         ("ClutchTab1", (0.46, 0.845, -1.204737)),
         ("ClutchTab2", (0.46, 0.845, -1.395263)),
         ("HostileHook", (0, 1.2, 0.6)),
         ("reel_axis", (0, 0.9, -1.3)), ("post_base", (0, 0, -1.3)),
         ("post_top", (0, 2.4, -1.3)), ("catch_endpoint", (0, 1.2, 0)),
         ("WinchFrame", (0, 0, 0))]


def binder(part):
    layer = part.bm.verts.layers.deform.new()

    def bind(name):
        idx = next(i for i, row in enumerate(BONES) if row[0] == name)
        for v in part.bm.verts:
            if not v[layer]:
                v[layer][idx] = 1.0
    return bind


b = Part("AnchorCrewBody")
bind = binder(b)
with b.region(bevel=0, subsurf=1):
    rows = []
    for y, radius in [(-1.1, 0.38), (-0.9, 0.62), (-0.45, 0.8),
                      (0.5, 0.8), (0.9, 0.60), (1.1, 0.36)]:
        rows.append([b.bm.verts.new(Vector(g(radius * math.cos(k * math.tau / 12), y,
                                               radius * math.sin(k * math.tau / 12)))) for k in range(12)])
    for i in range(len(rows) - 1):
        for k in range(12):
            face = b.bm.faces.new((rows[i][k], rows[i][(k + 1) % 12],
                                   rows[i + 1][(k + 1) % 12], rows[i + 1][k]))
            b.paint([face], "fleet_paint", "bone" if k in (2, 3) and i in (2, 3) else PAINT)
    b.paint([b.bm.faces.new(list(reversed(rows[0]))), b.bm.faces.new(rows[-1])], "fleet_paint", PAINT)
core = list(b.bm.verts)
bind("CrewBrace")
for side in (-1, 1):
    b.box("fleet_paint", (0.32, 0.44, 0.15), loc=g(side * 0.38, -1.025, 0.22), color="charcoal")
    b.cyl("fleet_paint", 0.17, 0.21, 0.3, segs=6, loc=g(side * 0.38, -0.85, 0.15), color="bone")
bind("AnchorFeet")
with b.region(bevel=0, subsurf=2, detail=1):
    b.uv("fleet_paint", 0.38, u=8, v=5, loc=g(0, 1.3, 0), color="oxide")
    b.uv("fleet_paint", 0.18, u=6, v=4, loc=g(0, 1.25, 0.31), scale=(1.1, 0.7, 0.65), color="bone")
for side in (-1, 1):
    with b.region(bevel=0, subsurf=1, detail=1):
        b.cyl("fleet_paint", 0.13, 0.0, 0.34, segs=6, loc=g(side * 0.2, 1.65, 0), color="oxide")
    with b.region(bevel=0, detail=1):
        b.uv("fleet_paint", 0.075, u=6, v=4, loc=g(side * 0.17, 1.42, 0.315), color="charcoal")
bind("AnchorHead")
with b.region(bevel=0, subsurf=1, detail=1):
    for side in (-1, 1):
        b.rod("fleet_paint", g(side * 0.45, 0.72, 0.32), g(side * 0.32, 0.9, 0.58), 0.095, segs=6, color="oxide")
        b.uv("fleet_paint", 0.12, u=6, v=4, loc=g(side * 0.32, 0.9, 0.58), color="charcoal")
bind("CrewBrace")
b.box("fleet_paint", (0.7, 0.16, 0.12), loc=g(0, 0.9, 0.58), color=WORN)
bind("CrewBrace")
b.box("fleet_paint", (0.26, 0.26, 2.4), loc=g(0, 1.2, -1.3), color=PAINT)
for y in (0.12, 1.9, 2.3):
    b.box("fleet_paint", (0.30, 0.30, 0.20), loc=g(0, y, -1.3), color="bone")
bind("WinchPost")
for side in (-1, 1):
    b.beam("fleet_paint", g(side * 0.45, -0.2, -0.5), g(0, 0.45, -1.3), 0.10, color="charcoal")
bind("WinchFrame")
b.box("fleet_paint", (0.32, 0.28, 0.25), loc=g(0, 1.2, 0.48), color=PAINT)
bind("AnchorHead")
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
assert max(math.hypot(v.co.x, v.co.y) for v in core) <= 0.800001
assert abs(min(v.co.z for v in core) + 1.1) < 0.000001 and abs(max(v.co.z for v in core) - 1.1) < 0.000001
body = b.to_object(parent=root)

r = Part("DeckReel")
axis = (0, math.pi / 2, 0)
for x in (-0.39, 0.39):
    r.cyl("fleet_paint", 0.55, 0.55, 0.108, segs=12, loc=g(x, 0.9, -1.3), rot=axis, color=PAINT)
    with r.region(bevel=0):
        r.ring("fleet_paint", 0.39, 0.52, 0.012, segs=8,
               loc=g(x + (-0.054 if x < 0 else 0.054), 0.9, -1.3), rot=axis, color="bone")
r.cyl("fleet_paint", 0.37, 0.37, 0.66, segs=12, loc=g(0, 0.9, -1.3), rot=axis, color="charcoal")
for x in (0,):
    r.ring("fleet_paint", 0.36, 0.385, 0.045, segs=8, loc=g(x, 0.9, -1.3), rot=axis, color="charcoal")
with r.region(bevel=0):
    r.box("fleet_paint", (0.002, 0.075, 0.40), loc=g(-0.449, 1.13, -1.3), color=WORN)
bmesh.ops.recalc_face_normals(r.bm, faces=r.bm.faces[:])
reel = r.to_object(origin=g(0, 0.9, -1.3), parent=root)

w = Part("AnchorWorkingTools")
w.bevel = 0.012
bind_tool = binder(w)
w.cyl("working_tool", 0.15, 0.15, 0.10, segs=9, loc=g(0.45, 0.9, -1.3), rot=axis, color=WORN)
bind_tool("WinchClutch")
for i in range(3):
    _, p = BONES[5 + i]
    w.box("working_tool", (0.11, 0.05, 0.065), loc=g(*p), rot=(math.tau * i / 3, 0, 0), color="hazard")
    bind_tool("ClutchTab" + str(i))
outline = [(-0.10, 0.15), (-0.025, 0.15), (-0.025, -0.065), (0.02, -0.10),
           (0.07, -0.06), (0.07, 0.01), (0.10, 0.01), (0.10, -0.10),
           (0.035, -0.15), (-0.045, -0.15), (-0.10, -0.085)]
hook_faces = w.prism("working_tool", outline, 0.12, matrix=common.mtx(g(0, 1.2, 0.6), (math.pi / 2, 0, 0)), color="charcoal")
w.paint(hook_faces[:1], "working_tool", "hazard")
bind_tool("HostileHook")
bmesh.ops.recalc_face_normals(w.bm, faces=w.bm.faces[:])
tools = w.to_object(parent=root)

rig_data = bpy.data.armatures.new("AnchorWindup")
rig = bpy.data.objects.new("AnchorWindup", rig_data)
bpy.context.scene.collection.objects.link(rig)
rig.parent = root
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, pos in BONES:
    bone = rig_data.edit_bones.new(name)
    bone.head = g(*pos)
    bone.tail = Vector(bone.head) + Vector((0, 0, 0.15))
rig_data.edit_bones["AnchorHead"].parent = rig_data.edit_bones["CrewBrace"]
bpy.ops.object.mode_set(mode="OBJECT")
for obj in (body, tools):
    for name, _ in BONES:
        obj.vertex_groups.new(name=name)
    obj.modifiers.new("Windup", "ARMATURE").object = rig
    obj.parent = rig

bpy.context.view_layer.update()
triangles = common.tri_total(root)
surfaces = sum(len(o.data.materials) for o in (body, reel, tools))
print("EAC geometry:", triangles, "triangles;", surfaces, "surfaces; core radius 0.8; y -1.1..1.1")
assert triangles <= 6000 and surfaces == 3
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_anchor_crew.glb"))


def previews(outdir):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.4, 0.45, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.1))
    bpy.context.object.data.materials.append(common._flat("Ground", "666a68"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=(2.5, -0.1, -0.1))
    bpy.context.object.name = "ReferenceBall_2m"
    bpy.context.object.data.materials.append(common._flat("ReferenceBall", "bone"))
    for poly in bpy.context.object.data.polygons:
        poly.use_smooth = True
    light = bpy.data.lights.new("Key", "AREA")
    light.energy, light.shape, light.size = 1400, "DISK", 6
    lamp = bpy.data.objects.new("Key", light)
    scene.collection.objects.link(lamp)
    lamp.location = (-3, -5, 7)
    common._look(lamp, (0, 0, 0.6))
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy, fill.size = 700, 5
    fill_obj = bpy.data.objects.new("Fill", fill)
    scene.collection.objects.link(fill_obj)
    fill_obj.location = (5, -3, 5)
    common._look(fill_obj, (0, 0.8, 0.9))
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type, cam.data.ortho_scale = "ORTHO", 6.2
    os.makedirs(outdir, exist_ok=True)
    for label, direction in [("front", (0, -10, 1.1)), ("side", (-10, 0, 1.1)),
                             ("three-quarter", (8, -10, 6)), ("windup", (8, -10, 6))]:
        if label == "side":
            bpy.data.objects["ReferenceBall_2m"].location = (2.5, -2.2, -0.1)
        else:
            bpy.data.objects["ReferenceBall_2m"].location = (2.5, -0.1, -0.1)
        if label == "windup":
            torso = rig.pose.bones["CrewBrace"]
            torso.rotation_mode = "XYZ"
            torso.rotation_euler.x = math.radians(8)
            torso.location.y = -0.08
            for i in range(3):
                p = Vector(BONES[5 + i][1]) - Vector((0.46, 0.9, -1.3))
                offset = p.normalized() * 0.09
                rig.pose.bones["ClutchTab" + str(i)].location = (offset.x, offset.y, offset.z)
            rig.pose.bones["HostileHook"].location.z = -0.20
        target = Vector((0, -0.7, 0.6) if label == "side" else (0.9, 0, 0.6))
        cam.location = target + Vector(direction)
        common._look(cam, target)
        scene.render.filepath = os.path.join(outdir, label + ".png")
        bpy.ops.render.render(write_still=True)
    print("EAC previews: CPU Cycles 16 samples, front / side / three-quarter / windup; reference diameter 2 m")


if opts["render"]:
    previews(opts["render"])
