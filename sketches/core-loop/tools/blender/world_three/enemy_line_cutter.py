"""Measured Highdraft line cutter; three opaque vertex-colour surfaces.

Godot metres (X,Y,Z) become Blender (X,-Z,Y). Floor is Y=-1.1.
The crew, rigid throw arm and flying disc are separate meshes. Head/rack
markers name geometry merged into the crew surface; sockets cost no draws.
Run: blender -b --python <this file> -- [--out file.glb] [--render dir]
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
import polish
from common import Part


def g(x, y, z):
    return (x, -z, y)


common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.82}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.48, "metal": 0.55}
root = common.empty("LineCutter")
body = Part("CutterCrewBody")
core_points = []

with body.region(bevel=0, subsurf=1):
    rows = []
    for y, radius in [(-0.55, 0.48), (-0.2, 0.72), (0.55, 0.8), (0.9, 0.62), (1.1, 0.42)]:
        row = []
        for i in range(12):
            a = math.tau * i / 12
            p = (radius * math.cos(a), y, radius * math.sin(a))
            core_points.append(p)
            row.append(body.bm.verts.new(Vector(g(*p))))
        rows.append(row)
    body.paint([body.bm.faces.new(list(reversed(rows[0]))), body.bm.faces.new(rows[-1])],
               "fleet_paint", "charcoal")
    for j in range(len(rows) - 1):
        for i in range(12):
            n = (i + 1) % 12
            face = body.bm.faces.new((rows[j][i], rows[j][n], rows[j + 1][n], rows[j + 1][i]))
            color = "bone" if j == 0 or (j == 2 and i in (2, 3, 8)) else "53686d"
            body.paint([face], "fleet_paint", color)

for side in (-1, 1):
    body.rod("fleet_paint", g(side * 0.32, -0.48, 0), g(side * 0.4, -0.92, 0.08),
             0.13, segs=6, color="charcoal")
    body.cyl("fleet_paint", 0.16, 0.12, 0.18, segs=6,
             loc=g(side * 0.35, -0.6, 0), color="bone")
    body.box("fleet_paint", (0.32, 0.42, 0.18), loc=g(side * 0.4, -1.01, 0.12), color="53686d")
    with body.region(bevel=0.006):
        body.rod("fleet_paint", g(side * 0.52, 0.1, 0.43), g(side * 0.4, 0.72, 0.43),
                 0.024, segs=4, color="a8aaa3")
        body.cyl("fleet_paint", 0.032, 0.032, 0.03, segs=5,
                 loc=g(side * 0.37, 0.57, 0.65), rot=(math.pi / 2, 0, 0), color="charcoal")

with body.region(bevel=0, subsurf=2, detail=1):
    body.uv("fleet_paint", 0.38, u=10, v=6, loc=g(0, 1.3, 0), color="oxide")
    body.uv("fleet_paint", 0.14, u=8, v=4, loc=g(0, 1.23, 0.29),
            scale=(1.25, 0.8, 0.85), color="bone")
for side in (-1, 1):
    with body.region(bevel=0, subsurf=1, detail=1):
        body.cyl("fleet_paint", 0.13, 0.0, 0.34, segs=5,
                 loc=g(side * 0.2, 1.65, 0), color="charcoal")
    with body.region(bevel=0.012, detail=1):
        body.box("fleet_paint", (0.055, 0.03, 0.07), loc=g(side * 0.15, 1.36, 0.335), color="charcoal")
with body.region(bevel=0.012, detail=1):
    body.box("fleet_paint", (0.07, 0.05, 0.055), loc=g(0, 1.26, 0.415), color="charcoal")
with body.region(bevel=0, subsurf=1, detail=1):
    body.rod("fleet_paint", g(0.48, 0.7, 0), g(0.58, 0.32, 0.2), 0.09, segs=6, color="charcoal")
    body.ico("fleet_paint", 0.14, loc=g(0.5, 0.15, 0.32), color="bone")
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
crew = body.to_object(parent=root)

arm = Part("ThrowArm")
arm.bevel = 0.015
arm.rod("fleet_paint", g(-0.48, 0.7, 0), g(-0.50, 1.25, 0), 0.07, segs=8, color="charcoal")
arm.rod("fleet_paint", g(-0.50, 1.25, 0), g(-0.50, 1.8, 0), 0.07, segs=8, color="charcoal")
for y in (0.7, 1.25):
    arm.cyl("fleet_paint", 0.13, 0.13, 0.17, segs=8,
            loc=g(-0.50, y, 0), rot=(0, math.pi / 2, 0), color="bone")
arm.cyl("fleet_paint", 0.1, 0.1, 0.28, segs=6, loc=g(-0.50, 1.56, 0), color="53686d")
arm.rod("fleet_paint", g(-0.50, 1.8, 0), g(0, 1.8, 0), 0.045, segs=6, color="charcoal")
arm.cyl("fleet_paint", 0.08, 0.08, 0.35, segs=8, loc=g(0, 1.9, 0), color="a8aaa3")
bmesh.ops.recalc_face_normals(arm.bm, faces=arm.bm.faces[:])
throw_arm = arm.to_object(origin=g(-0.48, 0.7, 0), parent=root)

disc = Part("CutterDisc")
disc.bevel = 0.01
rings = []
for y, radius in [(2.06, 0.61), (2.06, 0.7), (2.14, 0.7), (2.14, 0.61)]:
    rings.append([disc.bm.verts.new(Vector(g(radius * math.cos(math.tau * i / 24), y,
                                            radius * math.sin(math.tau * i / 24)))) for i in range(24)])
disc.paint([disc.bm.faces.new(list(reversed(rings[0]))), disc.bm.faces.new(rings[3])],
           "working_tool", "a8aaa3")
for row in range(3):
    for i in range(24):
        n = (i + 1) % 24
        face = disc.bm.faces.new((rings[row][i], rings[row][n], rings[row + 1][n], rings[row + 1][i]))
        disc.paint([face], "working_tool", "hazard" if i % 2 == 0 else "charcoal")
bmesh.ops.recalc_face_normals(disc.bm, faces=disc.bm.faces[:])
cutter_disc = disc.to_object(origin=g(0, 2.1, 0), parent=root)

for name, pos in [("CutterHead", (0, 1.3, 0)), ("DiscRack", (0, 1.9, 0)),
                  ("throw_shoulder", (-0.48, 0.7, 0)), ("disc_rest", (0, 2.1, 0)),
                  ("disc_launch", (0, 2.2, 0))]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
assert max(math.hypot(x, z) for x, y, z in core_points) <= 0.800001
assert all(-1.1 <= y <= 1.1 for x, y, z in core_points)
assert max(math.hypot(v.co.x, v.co.y) for v in crew.data.vertices if v.co.z <= 1.100001) <= 0.800001
assert min(v.co.z for v in crew.data.vertices) >= -1.100001
assert common.tri_total(root) <= 6000
opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_line_cutter.glb")
common.export(root, path)
data = open(path, "rb").read()
size = struct.unpack_from("<I", data, 12)[0]
glb = json.loads(data[20:20 + size])
primitives = [p for m in glb["meshes"] for p in m["primitives"]]
vertices = sum(glb["accessors"][p["attributes"]["POSITION"]]["count"] for p in primitives)
triangles = sum(glb["accessors"][p["indices"]]["count"] // 3 for p in primitives)
assert vertices <= 9000 and triangles <= 6000 and len(primitives) == 3
print(f"ELC EXPORTED: {vertices} V / {triangles} T / {len(primitives)} D; core radius 0.8, floor -1.1")


def preview(outdir):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 8
    scene.render.resolution_x = 960
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.30, 0.36, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.1))
    bpy.context.object.data.materials.append(common._flat("Floor", "a8aaa3"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1,
                                       location=(-2.1, 0, -0.1))
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("ReferenceBone", "bone"))
    for poly in ball.data.polygons:
        poly.use_smooth = True
    for label, at, power, area in [("Key", (3, -5, 7), 1000, 5), ("Fill", (-4, -1, 4), 500, 4)]:
        light = bpy.data.lights.new(label, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = area
        obj = bpy.data.objects.new(label, light)
        scene.collection.objects.link(obj)
        obj.location = at
        common._look(obj, (0, 0, 0.5))
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.8
    os.makedirs(outdir, exist_ok=True)
    for label, at in [("front", (-1, -10, 1)), ("side", (-10, -0.01, 1)),
                      ("three_quarter", (-7, -10, 6)), ("windup", (-7, -10, 6))]:
        ball.location = g(0, -0.1, -2.1) if label == "side" else g(-2.1, -0.1, 0)
        if label == "windup":
            crew.rotation_euler.x = 0.08
            throw_arm.rotation_euler.x = -0.52
            throw_arm.location = crew.rotation_euler.to_matrix() @ Vector(g(-0.48, 0.7, 0))
            cutter_disc.location = throw_arm.location + throw_arm.rotation_euler.to_matrix() @ Vector(g(0.48, 1.4, 0))
        camera.location = at
        common._look(camera, (-0.8, 0, 0.5) if label != "side" else (0, 0.8, 0.5))
        scene.render.filepath = os.path.join(outdir, label + ".png")
        bpy.ops.render.render(write_still=True)
    print("ELC PREVIEWS: CPU Cycles, 12 samples, front / side / three_quarter / windup, 2 m sphere")


if opts["render"]:
    preview(opts["render"])
