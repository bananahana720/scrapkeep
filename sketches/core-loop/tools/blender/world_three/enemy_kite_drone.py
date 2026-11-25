"""E24: measured hanging crew pod, shallow diamond sail and blunt dive skid.

Procedural geometry only. Godot (X,Y,Z) maps to Blender (X,-Z,Y).
Three opaque draws: pod/operator/hub, rigid-skinned sail halves, working chin.
Run: blender -b --factory-startup -P <this file> -- [--out path] [--render dir]
The optional previews use CPU Cycles and a measured 2 m reference sphere.
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
import polish
from common import Part

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.85}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.65, "metal": 0.25}
root = common.empty("KiteDrone")
CHAR = "charcoal"
WORN = common.mix("bone", "charcoal", 0.22)
PETROL = "53686d"


def g(x, y, z):
    return (x, -z, y)


BONES = [
    ("PodRoot", (0, 0, 0)),
    ("KiteHead", (0, 1.3, 0)),
    ("KiteHub", (0, 1.2, 0)),
    ("KitePawLeft", (-0.40, 0.72, 0.37)),
    ("KitePawRight", (0.40, 0.72, 0.37)),
    ("KiteWingLeft", (0, 1.5, 0)),
    ("KiteWingRight", (0, 1.5, 0)),
]


def weighted(part):
    return part.bm.verts.layers.deform.new()


def bind(part, weights, bone):
    for vertex in part.bm.verts:
        if not vertex[weights]:
            vertex[weights][bone] = 1.0


body = Part("KiteCrewPod")
bw = weighted(body)
with body.region(bevel=0, subsurf=1, fit=False):
    rows = []
    for y, radius, front in [(-1.1, 0.30, 0.30), (-0.93, 0.58, 0.40), (-0.55, 0.8, 0.32),
                             (0.18, 0.70, 0.58), (0.48, 0.8, 0.8), (0.88, 0.62, 0.62), (1.1, 0.34, 0.34)]:
        rows.append([body.bm.verts.new(Vector(g(radius * math.cos(a * math.tau / 12), y,
                                               min(front, radius * math.sin(a * math.tau / 12)))))
                     for a in range(12)])
    for row_index, (low, high) in enumerate(zip(rows, rows[1:])):
        for i in range(12):
            face = body.bm.faces.new((low[i], low[(i + 1) % 12], high[(i + 1) % 12], high[i]))
            col = "bone" if i in (1, 2, 3, 4) else PETROL
            if row_index in (0, 5):
                col = WORN
            if (row_index, i) in ((1, 7), (3, 0), (2, 10)):
                col = "petrol"
            body.paint([face], "fleet_paint", col)
    body.paint([body.bm.faces.new(list(reversed(rows[0]))), body.bm.faces.new(rows[-1])],
               "fleet_paint", CHAR)
core = [v.co.copy() for v in body.bm.verts]
assert max(math.hypot(v.x, v.y) for v in core) <= 0.800001
assert abs(min(v.z for v in core) + 1.1) < 1e-6 and abs(max(v.z for v in core) - 1.1) < 1e-6
body.cyl("fleet_paint", 0.795, 0.795, 0.07, segs=12, loc=g(0, -0.47, 0), color=CHAR)
for side in (-1, 1):
    body.cyl("fleet_paint", 0.26, 0.26, 0.12, segs=8, loc=g(side * 0.68, 0.18, 0),
             rot=(0, math.pi / 2, 0), color=WORN)
    body.cyl("fleet_paint", 0.16, 0.16, 0.13, segs=8, loc=g(side * 0.685, 0.18, 0),
             rot=(0, math.pi / 2, 0), color=CHAR)
    body.rod("fleet_paint", g(side * 0.52, 0.65, -0.10), g(side * 0.26, 1.46, -0.12),
             0.055, segs=5, color=CHAR)
body.box("fleet_paint", (0.38, 0.12, 0.12), loc=g(0, 0.82, 0.45), color=CHAR)
bind(body, bw, 0)
with body.region(bevel=0, subsurf=2, detail=1):
    body.uv("fleet_paint", 0.38, u=8, v=6, loc=g(0, 1.3, 0), color="oxide")
    body.uv("fleet_paint", 0.20, u=8, v=4, loc=g(0, 1.20, 0.25), scale=(1, 0.60, 0.65), color="bone")
with body.region(bevel=0, subsurf=1, detail=1):
    for side in (-1, 1):
        body.cyl("fleet_paint", 0.13, 0, 0.34, segs=6, loc=g(side * 0.20, 1.65, 0), color="oxide")
with body.region(bevel=0, detail=1):
    body.ico("fleet_paint", 0.065, loc=g(0, 1.24, 0.37), scale=(1, 0.6, 0.65), color=CHAR)
    for side in (-1, 1):
        body.ico("fleet_paint", 0.046, loc=g(side * 0.16, 1.40, 0.31), color=CHAR)
bind(body, bw, 1)
body.ring("fleet_paint", 0.41, 0.50, 0.9, segs=10, loc=g(0, 1.2, 0),
          arc=(math.radians(-15), math.radians(195)), color=PETROL)
body.ring("fleet_paint", 0.40, 0.50, 0.07, segs=10, loc=g(0, 0.80, 0),
          arc=(math.radians(-15), math.radians(195)), color=WORN)
bind(body, bw, 2)
for side, bone in [(-1, 3), (1, 4)]:
    with body.region(bevel=0, subsurf=1, detail=1):
        body.rod("fleet_paint", g(side * 0.40, 0.72, 0.37), g(side * 0.32, 0.90, 0.50),
                 0.09, segs=6, color="oxide")
        body.uv("fleet_paint", 0.12, u=6, v=4, loc=g(side * 0.32, 0.90, 0.50), color="oxide")
    bind(body, bw, bone)
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
pod = body.to_object(parent=root)

sail = Part("KiteSail")
sail.bevel = 0
sw = weighted(sail)
for side, bone in [(-1, 5), (1, 6)]:
    outline = [(side * x, -z) for x, z in [(0, 0.35), (1.6, 0), (0, -0.35)]]
    if side < 0:
        outline.reverse()
    sail.prism("fleet_paint", outline, 0.12, matrix=common.mtx(g(0, 1.5, 0)),
               color="bone", side_slot="fleet_paint", side_color=PETROL)
    with sail.region(bevel=0.008):
        for z in (-0.32, 0.32):
            sail.rod("fleet_paint", g(0, 1.535, z), g(side * 1.55, 1.535, 0),
                     0.025, segs=5, color=PETROL)
        sail.rod("fleet_paint", g(0, 1.53, 0), g(side * 1.56, 1.53, 0),
                 0.03, segs=6, color=CHAR)
    sail.prism("fleet_paint", [(side * 0.52, -0.17), (side * 0.95, -0.09), (side * 0.68, 0.06)],
               0.0002, matrix=common.mtx(g(0, 1.5601, 0)), color=WORN)
    bind(sail, sw, bone)
bmesh.ops.recalc_face_normals(sail.bm, faces=sail.bm.faces[:])
wing = sail.to_object(parent=root)

chin = Part("DiveChin")
chin_faces = chin.prism("working_tool", [(-0.175, 0.15), (0.175, 0.15), (0.14, -0.35), (-0.14, -0.35)],
                       0.2, matrix=common.mtx(g(0, -0.3, 0.35)), color=CHAR)
front_face = chin_faces[4]
corners = [loop.vert for loop in front_face.loops]
chin.bm.faces.remove(front_face)
chin.paint([chin.bm.faces.new((corners[0], corners[1], corners[2]))], "working_tool", "hazard")
chin.paint([chin.bm.faces.new((corners[0], corners[2], corners[3]))], "working_tool", CHAR)
with chin.region(bevel=0):
    for i in range(2):
        chin.prism("working_tool", [(-0.13, 0.02 - i * 0.20), (0.13, -0.06 - i * 0.20),
                                    (0.13, -0.13 - i * 0.20), (-0.13, -0.05 - i * 0.20)],
                   0.002, matrix=common.mtx(g(0, -0.199, 0.35)), color="hazard")
bmesh.ops.recalc_face_normals(chin.bm, faces=chin.bm.faces[:])
skid = chin.to_object(origin=g(0, -0.3, 0.3), parent=root)

rig_data = bpy.data.armatures.new("KiteWindup")
rig = bpy.data.objects.new("KiteWindup", rig_data)
bpy.context.scene.collection.objects.link(rig)
rig.parent = root
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, at in BONES:
    bone = rig_data.edit_bones.new(name)
    bone.head = g(*at)
    bone.tail = Vector(bone.head) + Vector((0, 0, 0.2))
bpy.ops.object.mode_set(mode="OBJECT")
for obj in (pod, wing):
    for name, _ in BONES:
        obj.vertex_groups.new(name=name)
    mod = obj.modifiers.new("RigidWindup", "ARMATURE")
    mod.object = rig
    obj.parent = rig
for name, at in [("sail_root", (0, 1.5, 0)), ("hub_axis", (0, 1.2, 0)),
                 ("chin_pivot", (0, -0.3, 0.3)), ("dive_actor", (0, 0, 0)),
                 ("KiteSpars", (0, 1.5, 0))]:
    common.empty(name, g(*at), root)

bpy.context.view_layer.update()
assert common.tri_total(root) <= 6500
assert sum(len(o.data.materials) for o in (pod, wing, skid)) == 3
opts = common.args()
out = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_kite_drone.glb")
common.export(root, out)
data = open(out, "rb").read()
size = struct.unpack_from("<I", data, 12)[0]
glb = json.loads(data[20:20 + size])
prims = [p for m in glb["meshes"] for p in m["primitives"]]
vertices = sum(glb["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
triangles = sum(glb["accessors"][p["indices"]]["count"] // 3 for p in prims)
assert vertices <= 9500 and triangles <= 6500 and len(prims) == 3
print("KITE_BUDGET: %d V, %d T, %d D" % (vertices, triangles, len(prims)))


def preview(directory):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("bone")
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.1))
    bpy.context.object.data.materials.append(common._flat("Floor", common.mix("bone", "charcoal", 0.12)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=(3.1, 0, -0.1))
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("Reference", "petrol"))
    for polygon in ball.data.polygons:
        polygon.use_smooth = True
    bpy.ops.object.light_add(type="AREA", location=(-3, -5, 7))
    light = bpy.context.object
    light.data.energy = 1700
    light.data.shape = "DISK"
    light.data.size = 5
    common._look(light, (0, 0, 0.5))
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 7.4
    os.makedirs(directory, exist_ok=True)
    for label, position in [("front", (1.2, -15, 0.5)), ("side", (15, -1.2, 0.5)),
                            ("three-quarter", (9, -14, 7)), ("windup", (9, -14, 7))]:
        ball.location = (0, -3.1, -0.1) if label == "side" else (3.1, 0, -0.1)
        target = (0, -1.2, 0.5) if label == "side" else (1.2, 0, 0.5)
        cam.location = position
        common._look(cam, target)
        if label == "windup":
            for name, side in [("KiteWingLeft", -1), ("KiteWingRight", 1)]:
                basis = rig.data.bones[name].matrix_local.to_3x3()
                rig.pose.bones[name].rotation_mode = "QUATERNION"
                rig.pose.bones[name].rotation_quaternion = Quaternion(
                    basis.inverted() @ Vector(g(0, 0, 1)), math.radians(side * 5))
            for name, _ in BONES[3:5]:
                basis = rig.data.bones[name].matrix_local.to_3x3()
                rig.pose.bones[name].location = basis.inverted() @ Vector(g(0, 0.08, -0.08))
            skid.rotation_euler.x = math.radians(12)
        scene.render.filepath = os.path.join(directory, label + ".png")
        bpy.ops.render.render(write_still=True)
    print("KITE_PREVIEWS: CPU Cycles, 12 samples, four views, 2 m sphere")


if opts["render"]:
    preview(opts["render"])
