"""EBU: compact Fleet shovel rig; metres, Godot +Z forward, floor Y=-1.1.

Procedural bmesh only. Two body surfaces and one marker surface. The marker's
flat working inset shares part_state vertex paint and has a MarkerWorkingLip
shape key, so its WARN motion adds no fourth draw or independent attack clock.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir]
"""

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


def g(x, y, z):
    return (x, -z, y)


common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.55, "metal": 0.35}
common.SLOTS["part_state"] = {"vc": True, "rough": 0.85}
root = common.empty("Burrower")
body_root = common.empty("BurrowBody", parent=root)
b = Part("BurrowHull")
with b.region(bevel=0, subsurf=1):
    rows = []
    for y, radius in [(-1.1, 0.38), (-0.95, 0.67), (-0.35, 0.75), (0.25, 0.66), (0.60, 0.43), (0.70, 0.28)]:
        row = []
        for k in range(12):
            a = math.tau * k / 12
            x, z = radius * math.cos(a), radius * math.sin(a)
            if z > 0 and y >= -0.35:
                z *= 0.75
            yy = y - (max(0, z) * 0.55 if y > -0.35 else 0)
            row.append(b.bm.verts.new(Vector(g(x, yy, z))))
        rows.append(row)
    b.paint([b.bm.faces.new(list(reversed(rows[0])))], "fleet_paint", "charcoal")
    for j in range(len(rows) - 1):
        for k in range(12):
            col = "petrol" if k in (0, 1, 5, 6, 7, 11) else "bone"
            if j == 0:
                col = "charcoal"
            face = b.bm.faces.new((rows[j][k], rows[j][(k + 1) % 12], rows[j + 1][(k + 1) % 12], rows[j + 1][k]))
            b.paint([face], "fleet_paint", col)
    b.paint([b.bm.faces.new(rows[-1])], "fleet_paint", "bone")

for name, at in [("SidePaddles", (0, -0.95, -0.1)), ("CrewVisor", (0, 0.5, 0.35)),
                 ("Exhaust", (0, 0.925, -0.4)), ("ShovelNose", (0, -0.65, 0.52))]:
    common.empty(name, g(*at), body_root)
for s in (-1, 1):
    b.box("fleet_paint", (0.20, 0.50, 0.18), loc=g(s * 0.57, -0.95, -0.1), color="petrol")
    for z in (-0.27, 0.07):
        b.box("fleet_paint", (0.20, 0.07, 0.04), loc=g(s * 0.57, -0.84, z), color="bone")
    b.rod("fleet_paint", g(s * 0.60, -0.47, -0.18), g(s * 0.60, -0.90, -0.18), 0.07, segs=6, color="charcoal")
    b.box("fleet_paint", (0.035, 0.18, 0.045), loc=g(s * 0.64, -0.35, -0.12), color="bone")
b.box("fleet_paint", (0.55, 0.25, 0.35), loc=g(0, 0.5, 0.35), color="charcoal")
b.box("fleet_paint", (0.57, 0.28, 0.04), loc=g(0, 0.68, 0.35), color="bone")
with b.region(bevel=0, subsurf=2, detail=1):
    b.uv("fleet_paint", 0.13, u=8, v=4, loc=g(0, 0.50, 0.45), scale=(1, 0.70, 1), color="oxide")
    b.uv("fleet_paint", 1.0, u=6, v=4, loc=g(0, 0.46, 0.55), scale=(0.065, 0.025, 0.03), color="bone")
with b.region(bevel=0, subsurf=1, detail=1):
    for s in (-1, 1):
        b.cyl("fleet_paint", 0.045, 0.0, 0.10, segs=5, loc=g(s * 0.08, 0.62, 0.44), color="oxide")
        b.uv("fleet_paint", 0.06, u=6, v=4, loc=g(s * 0.18, 0.34, 0.46), color="oxide")
with b.region(bevel=0.004, detail=1):
    for s in (-1, 1):
        b.box("fleet_paint", (0.025, 0.015, 0.025), loc=g(s * 0.045, 0.53, 0.572), color="charcoal")
b.cyl("fleet_paint", 0.12, 0.10, 0.30, segs=8, loc=g(0, 0.68, -0.4), color="charcoal")
b.cyl("fleet_paint", 0.09, 0.09, 0.35, segs=8, loc=g(0, 0.925, -0.4), color="petrol")
b.cyl("fleet_paint", 0.07, 0.07, 0.015, segs=8, loc=g(0, 1.09, -0.4), color="charcoal")

blade = [b.bm.verts.new(Vector(g(*p))) for p in [
    (-0.40, -0.90, 0.345), (0.40, -0.90, 0.345), (0.34, -0.90, 0.695), (-0.34, -0.90, 0.695),
    (-0.40, -0.40, 0.345), (0.40, -0.40, 0.345), (0.34, -0.50, 0.695), (-0.34, -0.50, 0.695),
]]
for indices in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
    b.paint([b.bm.faces.new([blade[i] for i in indices])], "working_tool", "charcoal")
with b.region(bevel=0, subsurf=0):
    for x0 in (-0.29, -0.04, 0.21):
        face = b.bm.faces.new([b.bm.verts.new(Vector(g(x, y, 0.697)))
                              for x, y in [(x0, -0.87), (min(x0 + 0.12, 0.32), -0.87),
                                           (min(x0 + 0.22, 0.32), -0.54), (min(x0 + 0.10, 0.32), -0.54)]])
        b.paint([face], "working_tool", "hazard")
for s in (-1, 1):
    for y, z in [(-0.22, -0.20), (-0.58, -0.20)]:
        b.rod("fleet_paint", g(s * 0.64, y, z), g(s * 0.67, y, z), 0.028, segs=5,
              color=common.mix("bone", "charcoal", 0.35))
    b.box("fleet_paint", (0.024, 0.10, 0.28), loc=g(s * 0.66, -0.37, -0.20), color="charcoal")
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=body_root)

m = Part("BurrowMarker")
m.bevel = 0
m.subsurf = 0
m.cyl("part_state", 1.6, 1.6, 0.05, segs=24, loc=g(0, -1.1, 0), color="charcoal")
m.ring("part_state", 1.42, 1.58, 0.018, segs=24, loc=g(0, -1.069, 0), color=common.mix("charcoal", "bone", 0.4))
lip_faces = []
for i in range(5):
    x0, x1 = -0.5 + i * 0.2, -0.5 + (i + 1) * 0.2
    lip_faces += m.prism("part_state", [(x0, -0.9), (x1, -0.9), (x1, -1.1), (x0, -1.1)], 0.002,
                         matrix=common.mtx(g(0, -1.14, 0)), color="hazard" if i % 2 == 0 else "charcoal")
lip_vertices = m.verts_of(lip_faces)
m.bm.verts.index_update()
lip_ids = [v.index for v in lip_vertices]
bmesh.ops.recalc_face_normals(m.bm, faces=m.bm.faces[:])
marker = m.to_object(parent=root)
for obj in (body, marker):
    uv = obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.loops:
        p = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x * 0.25 + 0.5, p.y * 0.25 + 0.5)
marker.shape_key_add(name="Basis")
lip_key = marker.shape_key_add(name="MarkerWorkingLip")
for i in lip_ids:
    lip_key.data[i].co.z += 0.07
common.empty("MarkerWorkingLip", g(0, -1.07, 1.0), root)
for name, at in [("burrow_root", (0, 0, 0)), ("nose_forward", (0, -0.65, 0.70)),
                 ("marker_center", (0, -1.1, 0)), ("lane_origin", (0, 0, 0))]:
    common.empty(name, g(*at), root)
bpy.context.view_layer.update()
points = [body.matrix_world @ v.co for v in body.data.vertices]
radial = max(math.hypot(p.x, p.y) for p in points)
bottom, top = min(p.z for p in points), max(p.z for p in points)
tris = common.tri_total(root)
draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
print("EBU measured: %d T, %d D; body radial %.4f, Y %.4f..%.4f" % (tris, draws, radial, bottom, top))
assert tris <= 6000 and draws <= 3
assert radial <= 0.8001 and bottom >= -1.1001 and top <= 1.1001
opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_two", "enemy_burrower.glb")
os.makedirs(os.path.dirname(path), exist_ok=True)
polish.bake(root)
for obj in bpy.context.scene.objects:
    obj.select_set(False)
for obj in common.tree(root):
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                          export_extras=False, export_animations=False, export_cameras=False,
                          export_lights=False, export_try_sparse_sk=False)
common.canonical_indices(path, vertices=True)
print("EXPORTED", path)


def preview(outdir):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x, scene.render.resolution_y = 960, 640
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.50, 0.55, 0.60, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.13))
    bpy.context.object.data.materials.append(common._flat("floor", "bone"))
    ref = Part("ReferenceBall_2m")
    ref.uv("part_state", 1.0, u=32, v=16, loc=g(2.75, -0.1, 0), color="bone")
    ref.to_object()
    light = bpy.data.lights.new("softbox", "AREA")
    light.energy, light.size = 1300, 6
    lamp = bpy.data.objects.new("softbox", light)
    scene.collection.objects.link(lamp)
    lamp.location = (0, -4, 7)
    common._look(lamp, g(0, 0, 0))
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    os.makedirs(outdir, exist_ok=True)
    for label, at, target, ortho in [
        ("front", (1.3, -12, 0.1), (1.3, 0, 0.1), 6.5),
        ("side", (12, -1.3, 0.1), (0, -1.3, 0.1), 6.5),
        ("three-quarter", (7, -10, 5.5), (1.2, 0, -0.1), 6.5),
        ("wind-up", (7, -10, 6.5), (1.2, 0, -0.1), 6.5),
    ]:
        ball = bpy.data.objects["ReferenceBall_2m"]
        ball.location = (0, -2.75, 0) if label == "side" else (0, 0, 0)
        if label == "side":
            ball.location.x = -2.75
        body_root.location.z = -3 if label == "wind-up" else 0
        marker.hide_render = label != "wind-up"
        lip_key.value = 1 if label == "wind-up" else 0
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = ortho
        camera.location = at
        common._look(camera, target)
        scene.render.filepath = os.path.join(outdir, label + ".png")
        bpy.ops.render.render(write_still=True)
    print("EBU previews: CPU Cycles, 12 samples, four views, 2 m reference ball")


if opts["render"]:
    preview(opts["render"])
