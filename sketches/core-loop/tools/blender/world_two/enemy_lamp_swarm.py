"""ELS: measured Fleet lamp crew, dressed as the Dig's floodlight rig. Godot metres, +Z attack facing.

WORLD-ROSTERS.md: the lamp swarm becomes the floodlight rig, the Dig crew that throws the light
that plates its pack (the floodlight aura belongs to the fields thread). The dress is a miner in
a helmet and riveted shoulder plates, a generator pack with a light mast and hazard beacon, and
three floodlight heads (tapered housing, bone bezel, barn-door shutters) on booms. Geometry
contract unchanged (tests/enemy_lamp_swarm_asset_test.gd): the same barrel core, bones,
sockets, rest positions, bulb, hood and shutter sizes, and the 1.6 m formation.
The three rigid lamp groups share one skin and two surfaces. Body/arms use one
fleet_paint surface. Actor-owned proxies drive lamp bones; shutter and lens bones
read the existing WARN clock. No authored motion or attack geometry is exported.
Run: blender -b --python <this file> -- [--out file.glb] [--render directory]
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
import cycles_device
import polish
from common import Part
import fleet_crew

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.85}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.5, "metal": 0.25}
root = common.empty("LampSwarm")


def g(x, y, z):
    return Vector((x, -z, y))


REST = [Vector((math.cos(math.tau * i / 3) * 1.3, 1.6,
                math.sin(math.tau * i / 3) * 1.3)) for i in range(3)]
body = Part("LampCrewBody")
with body.region(bevel=0, subsurf=0):
    rows = []
    for y, radius in [(-1.1, 0.32), (-0.9, 0.56), (-0.3, 0.8), (0.55, 0.74), (1.1, 0.46)]:
        rows.append([body.bm.verts.new(g(radius * math.cos(k * math.tau / 10), y,
                                         radius * math.sin(k * math.tau / 10))) for k in range(10)])
    for j in range(len(rows) - 1):
        for k in range(10):
            face = body.bm.faces.new((rows[j][k], rows[j][(k + 1) % 10],
                                      rows[j + 1][(k + 1) % 10], rows[j + 1][k]))
            body.paint([face], "fleet_paint", "petrol" if k in (1, 2, 6) else "bone")
    body.paint([body.bm.faces.new(list(reversed(rows[0]))), body.bm.faces.new(rows[-1])],
               "fleet_paint", "charcoal")
for side in (-1, 1):
    body.box("fleet_paint", (0.3, 0.42, 0.22), loc=g(side * 0.38, -0.72, 0.31), color="charcoal")
    with body.region(bevel=0, subsurf=1, detail=1):
        body.rod("fleet_paint", g(side * 0.43, 0.72, 0.2), g(side * 0.23, 0.63, 0.54),
                 0.09, segs=5, color="oxide")
        body.ico("fleet_paint", 0.12, loc=g(side * 0.23, 0.63, 0.54), color="oxide")
body.box("fleet_paint", (0.30, 0.045, 0.12), loc=g(0, 0.64, 0.57), color="charcoal")
with body.region(bevel=0.01):
    body.ring("fleet_paint", 0.65, 0.735, 0.10, segs=10, loc=g(0, 0.63, 0), color="charcoal")
for side in (-1, 1):
    body.box("fleet_paint", (0.12, 0.035, 0.10), loc=g(side * 0.42, 0.35, 0.60), color="charcoal")
    body.box("fleet_paint", (0.42, 0.62, 0.12), loc=g(side * 0.5, 0.86, 0), rot=(0, side * 0.35, 0), color="53686d")
core_points = [v.co.copy() for v in body.bm.verts]
assert max(math.hypot(v.x, v.y) for v in core_points) <= 0.800001
assert min(v.z for v in core_points) >= -1.100001 and max(v.z for v in core_points) <= 1.100001
print("ELS core: radial %.6f m, Y %.6f..%.6f m" % (max(math.hypot(v.x, v.y) for v in core_points),
      min(v.z for v in core_points), max(v.z for v in core_points)))
fleet_crew.head(body, (0, 1.3, 0), r=0.34, hat="helmet")
body.box("fleet_paint", (0.62, 0.34, 0.6), loc=g(0, 0.45, -0.88), color="53686d")
with body.region(bevel=0.012):
    body.rod("fleet_paint", g(0, 0.75, -0.9), g(0, 2.35, -0.9), 0.05, segs=5, color="charcoal")
with body.region(bevel=0, detail=1):
    body.ico("fleet_paint", 0.11, loc=g(0, 2.42, -0.9), color="hazard")
common.empty("LampHead", loc=g(0, 1.3, 0), parent=root)
for i, rest in enumerate(REST):
    shoulder = Vector((rest.x * 0.25, 0.87, rest.z * 0.25))
    assert 0.9 <= (rest - shoulder).length <= 1.3
    with body.region(bevel=0.01):
        body.rod("fleet_paint", g(*shoulder), g(*rest), 0.04, segs=5, color="petrol")
    common.empty("LampArm%d" % i, loc=g(*shoulder), parent=root)
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
body_obj = body.to_object(parent=root)

rig_data = bpy.data.armatures.new("LampRig")
rig = bpy.data.objects.new("LampRig", rig_data)
bpy.context.scene.collection.objects.link(rig)
rig.parent = root
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, at, parent=None):
    b = rig_data.edit_bones.new(name)
    b.head = g(*at)
    b.tail = b.head + Vector((0, 0, 0.1))
    b.align_roll(Vector((0, -1, 0)))
    if parent:
        b.parent = rig_data.edit_bones[parent]
    return b


bone("lamp_root", (0, 0, 0))
for i, rest in enumerate(REST):
    base = "LampBulb%d" % i
    bone(base, rest, "lamp_root")
    bone("LampHood%d" % i, rest, base)
    bone("LampLens%d" % i, rest, base)
    for suffix, side in [("", -1), ("B", 1)]:
        bone("LampShutter%d%s" % (i, suffix), rest + Vector((side * 0.10, 0, 0.15)), base)
bpy.ops.object.mode_set(mode="OBJECT")
rig.select_set(False)
lamps = Part("LampAssembly")
lamps.bevel = 0.012
deform = lamps.bm.verts.layers.deform.verify()
groups = []


def weighted(name, draw):
    if name not in groups:
        groups.append(name)
    before = set(lamps.bm.verts)
    draw()
    for vert in lamps.bm.verts:
        if vert not in before:
            vert[deform][groups.index(name)] = 1.0


for i, rest in enumerate(REST):
    housing = [(-0.2, 0.14), (0.2, 0.14), (0.3, 0.0), (0.27, -0.04), (-0.27, -0.04), (-0.3, 0.0)]
    with lamps.region(bevel=0):
        weighted("LampBulb%d" % i, lambda: lamps.prism("working_tool", housing, 0.6,
                   matrix=Matrix.Translation(g(*rest)), color="charcoal"))
    with lamps.region(detail=1):
        weighted("LampHood%d" % i, lambda: lamps.ring("fleet_paint", 0.17, 0.25, 0.18, segs=6,
                   loc=g(*(rest + Vector((0, 0, 0.09)))), rot=(math.pi / 2, math.pi / 6, 0), color="bone"))
    weighted("LampLens%d" % i, lambda: lamps.cyl("working_tool", 0.14, 0.14, 0.025,
               segs=8, loc=g(*(rest + Vector((0, 0, 0.06)))), rot=(math.pi / 2, 0, 0), color="f3f0e8"))
    for suffix, side in [("", -1), ("B", 1)]:
        name = "LampShutter%d%s" % (i, suffix)
        weighted(name, lambda side=side: lamps.box("working_tool", (0.10, 0.03, 0.24),
                  loc=g(*(rest + Vector((side * 0.05, 0, 0.15)))), color="charcoal"))
        with lamps.region(bevel=0):
            weighted(name, lambda side=side: lamps.box("working_tool", (0.027, 0.002, 0.24),
                      loc=g(*(rest + Vector((side * 0.065, 0, 0.166)))), color="hazard"))
bmesh.ops.recalc_face_normals(lamps.bm, faces=lamps.bm.faces[:])
lamp_obj = lamps.to_object(parent=root)
lamp_obj.parent = rig
for name in groups:
    lamp_obj.vertex_groups.new(name=name)
modifier = lamp_obj.modifiers.new("RigidLamps", "ARMATURE")
modifier.object = rig

opts = common.args()
out = opts["out"] or os.path.join(common.MODELS, "world_two", "enemy_lamp_swarm.glb")
common.export(root, out)
data = open(out, "rb").read()
length = struct.unpack_from("<I", data, 12)[0]
doc = json.loads(data[20:20 + length])
prims = [p for mesh in doc["meshes"] for p in mesh["primitives"]]
triangles = sum(doc["accessors"][p["indices"]]["count"] // 3 for p in prims)
vertices = sum(doc["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
assert triangles <= 7500 and vertices <= 11000 and len(prims) <= 3
print("ELS geometry: %d T / %d V / %d D" % (triangles, vertices, len(prims)))


def preview(directory):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x, scene.render.resolution_y = 960, 720
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.38, 0.4, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.1))
    bpy.context.object.data.materials.append(common._flat("Floor", "sandstone"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=(3.2, 0, -0.1))
    bpy.context.object.name = "ReferenceBall2m"
    bpy.context.object.data.materials.append(common._flat("ReferenceNeutral", "bone"))
    for name, loc, power, size in [("Key", (1, -4, 6), 1000, 5), ("Fill", (-4, 1, 3), 700, 4)]:
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        scene.collection.objects.link(light)
        light.location = loc
        light.data.energy, light.data.shape, light.data.size = power, "DISK", size
        common._look(light, (0, 0, 0.5))
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.9
    os.makedirs(directory, exist_ok=True)
    for label, direction, opened in [("front", (0, -10, 0), False), ("side", (10, 0, 0), False),
                                     ("three-quarter", (7, -10, 5), False), ("wind-up", (7, -10, 5), True)]:
        for i in range(3):
            rig.pose.bones["LampLens%d" % i].scale = (1, 1, 1) if opened else (0.001, 0.001, 0.001)
            for suffix, side in [("", -1), ("B", 1)]:
                pb = rig.pose.bones["LampShutter%d%s" % (i, suffix)]
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (0, side * math.radians(100) if opened else 0, 0)
        forward = Vector(direction).normalized()
        right = forward.cross(Vector((0, 0, 1))).normalized()
        bpy.data.objects["ReferenceBall2m"].location = right * 3.2 + Vector((0, 0, -0.1))
        target = right * 1.25 + Vector((0, 0, 0.5))
        cam.location = target + Vector(direction)
        common._look(cam, target)
        scene.render.filepath = os.path.join(directory, label + "-final.png")
        bpy.ops.render.render(write_still=True)
    print("ELS previews: CPU Cycles, 16 samples, 4 views, 2 m reference")


if opts["render"]:
    preview(opts["render"])
