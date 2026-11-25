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

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
for slot, rough, metal in (("fleet_paint", 0.82, 0.0), ("working_tool", 0.5, 0.45),
                           ("part_state", 0.72, 0.25)):
    common.SLOTS[slot] = {"vc": True, "rough": rough, "metal": metal}
root = common.empty("DrillCrew")


def g(x, y, z):
    return (x, -z, y)


def box(part, slot, size, at, color):
    return part.box(slot, (size[0], size[2], size[1]), loc=g(*at), color=color)


def measured(part, faces, lo, hi):
    points = [v.co for v in part.verts_of(faces)]
    low = tuple(min(p[i] for p in points) for i in range(3))
    high = tuple(max(p[i] for p in points) for i in range(3))
    expect_lo, expect_hi = g(lo[0], lo[1], hi[2]), g(hi[0], hi[1], lo[2])
    assert all(abs(low[i] - expect_lo[i]) < 1e-5 and abs(high[i] - expect_hi[i]) < 1e-5
               for i in range(3)), (low, high, expect_lo, expect_hi)


b = Part("DrillCrewBody")
with b.region(bevel=0, subsurf=2, detail=1):
    core = b.uv("fleet_paint", 0.8, u=8, v=6, scale=(1, 1, 1.375), color="petrol")
core_vertices = b.verts_of(core)
assert all(math.hypot(v.co.x, v.co.y) <= 0.800001 and -1.100001 <= v.co.z <= 1.100001
           for v in core_vertices)
measured(b, core, (-0.8, -1.1, -0.8), (0.8, 1.1, 0.8))
with b.region(bevel=0, subsurf=2, detail=1):
    head = b.uv("fleet_paint", 0.38, u=8, v=6, loc=g(0, 1.3, 0), color="oxide")
for face in core + head:
    face.smooth = True
for side in (-1, 1):
    with b.region(bevel=0, subsurf=1, detail=1):
        b.cyl("fleet_paint", 0.13, 0.0, 0.34, segs=6, loc=g(side * 0.2, 1.65, 0), color="charcoal")
    with b.region(bevel=0, detail=1):
        b.uv("fleet_paint", 0.035, u=6, v=4, loc=g(side * 0.14, 1.36, 0.338), color="charcoal")
    with b.region(bevel=0, subsurf=1, detail=1):
        b.rod("fleet_paint", g(side * 0.34, 0.95, 0.18), g(side * 0.38, 0.91, 0.68),
              0.10, segs=6, color="oxide")
        b.uv("fleet_paint", 0.12, u=6, v=4, loc=g(side * 0.38, 0.91, 0.68), color="charcoal")
with b.region(bevel=0, subsurf=2, detail=1):
    b.uv("fleet_paint", 0.16, u=8, v=4, loc=g(0, 1.21, 0.34), scale=(1, 1, 0.65), color="bone")
with b.region(bevel=0.015, detail=1):
    box(b, "fleet_paint", (0.10, 0.07, 0.06), (0, 1.26, 0.48), "charcoal")
outline = [(-0.65, -0.8), (-0.8, -0.65), (-0.8, 0.65), (-0.65, 0.8),
           (0.65, 0.8), (0.8, 0.65), (0.8, -0.65), (0.65, -0.8),
           (0.58, -0.8), (0.58, 0.45), (-0.58, 0.45), (-0.58, -0.8)]
carriage = b.prism("fleet_paint", outline, 0.9, matrix=common.mtx(g(0, 0.5, 1.3)), color="petrol")
measured(b, carriage, (-0.8, 0.05, 0.5), (0.8, 0.95, 2.1))
for side in (-1, 1):
    box(b, "fleet_paint", (0.31, 0.70, 0.025), (side * 0.59, 0.50, 2.095), "bone")
    box(b, "fleet_paint", (0.025, 0.49, 1.16), (side * 0.796, 0.53, 1.27), "bone" if side < 0 else "petrol")
    rail = box(b, "fleet_paint", (0.1, 0.1, 1.6), (side * 0.5, 0.3, 1.3), "a8aaa3")
    measured(b, rail, (side * 0.5 - 0.05, 0.25, 0.5), (side * 0.5 + 0.05, 0.35, 2.1))
    for z in (-0.37, 0.37):
        foot = box(b, "fleet_paint", (0.25, 0.15, 0.35), (side * 0.40, -1.025, z), "charcoal")
        assert all(math.hypot(v.co.x, v.co.y) <= 0.8 for v in b.verts_of(foot))
b.ring("fleet_paint", 0.27, 0.45, 0.10, segs=8, loc=g(0, 0.5, 1.1),
       rot=(math.pi / 2, 0, 0), color="charcoal")
box(b, "fleet_paint", (0.33, 0.04, 0.14), (0, 0.955, 1.40), "brass")
box(b, "fleet_paint", (0.47, 0.06, 0.04), (-0.29, 0.94, 1.81), "a8aaa3")
box(b, "fleet_paint", (0.24, 0.08, 0.025), (0.60, 0.80, 2.113), "242a28")
for side in (-1, 1):
    b.rod("fleet_paint", g(side * 0.38, 0.92, 0.64), g(side * 0.38, 1.03, 0.79),
          0.045, segs=5, color="charcoal")
bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
body = b.to_object(parent=root)

d = Part("DrillBit")
d.bevel = 0.012
d.rod("working_tool", g(0, 0.5, 1.2), g(0, 0.5, 3.6), 0.22, r2=0.0, segs=12, color="a8aaa3")
rows = []
steps = 30
for k in range(steps + 1):
    t = k / steps
    angle = math.tau * 3 * t
    axial = 1.24 + 2.26 * t
    outer = 0.45 * (1.0 - 0.82 * max(0.0, (t - 0.4) / 0.6))
    inner = 0.22 * (1.0 - (axial - 1.2) / 2.4)
    rows.append([d.bm.verts.new(Vector(g(r * math.cos(angle), 0.5 + r * math.sin(angle), axial + dz)))
                 for r, dz in ((inner, -0.035), (outer, -0.035), (outer, 0.035), (inner, 0.035))])
for k in range(steps):
    for j in range(4):
        q = (j + 1) % 4
        face = d.bm.faces.new((rows[k][j], rows[k + 1][j], rows[k + 1][q], rows[k][q]))
        d.paint([face], "working_tool", "hazard" if j in (0, 1) and k % 6 < 4 else "charcoal")
for row in (list(reversed(rows[0])), rows[-1]):
    d.paint([d.bm.faces.new(row)], "working_tool", "charcoal")
bmesh.ops.recalc_face_normals(d.bm, faces=d.bm.faces[:])
bit = d.to_object(origin=g(0, 0.5, 2.4), parent=root)

p = Part("DrillPlate")
plate_faces = box(p, "part_state", (2.2, 1.8, 0.25), (0, 0.6, -1.0), "bone")
measured(p, plate_faces, (-1.1, -0.3, -1.125), (1.1, 1.5, -0.875))
with p.region(bevel=0.006):
    for side in (-1, 1):
        box(p, "part_state", (0.14, 1.58, 0.025), (side * 0.83, 0.6, -1.108), "petrol")
        for y in (0.02, 1.19):
            p.cyl("part_state", 0.065, 0.065, 0.025, segs=4, loc=g(side * 0.83, y, -1.110),
                  rot=(math.pi / 2, 0, 0), color="a8aaa3")
    box(p, "part_state", (0.58, 0.06, 0.025), (-0.34, 0.90, -1.110), "charcoal")
bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
plate = p.to_object(origin=g(0, 0.6, -1.0), parent=root)

for name, at in (("DrillHead", (0, 1.3, 0)), ("DrillCarriage", (0, 0.5, 1.3)),
                 ("DrillRails", (0, 0.3, 1.3)), ("DrillFeet", (0, -1.025, 0)),
                 ("bit_axis", (0, 0.5, 2.4)), ("bit_tip", (0, 0.5, 3.6)),
                 ("rail_slide", (0, 0.5, 1.3)), ("plate_attach", (0, 0.6, -1.0))):
    common.empty(name, g(*at), parent=root)
bpy.context.view_layer.update()
print("MESH_COUNTS", [(o.name, common.tris(o)) for o in (body, bit, plate)])
assert common.tri_total(root) <= 7500
assert sum(len(o.data.materials) for o in (body, bit, plate)) == 3
print("EDC RECIPE: %d T / 3 surfaces; core radius 0.8, height 2.2; screw 0.9 x 2.4; plate rear" % common.tri_total(root))
opts = common.args()
output = opts["out"] or os.path.join(common.MODELS, "world_two", "enemy_drill_crew.glb")
common.export(root, output)
with open(output, "rb") as handle:
    exported = handle.read()
gltf = json.loads(exported[20:20 + struct.unpack_from("<I", exported, 12)[0]])
vertices = sum(gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
               for mesh in gltf["meshes"] for primitive in mesh["primitives"])
assert vertices <= 9000, vertices
print("EDC EXPORT: %d T / %d V / 3 D" % (common.tri_total(root), vertices))


def preview(outdir):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x, scene.render.resolution_y = 960, 720
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.49, 0.53, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.105))
    bpy.context.object.data.materials.append(common._flat("PreviewFloor", "b9b4a7"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0, location=g(-2.4, -0.1, 0.6))
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("ReferenceBone", "bone"))
    for polygon in ball.data.polygons:
        polygon.use_smooth = True
    lamp = bpy.data.lights.new("PreviewKey", "AREA")
    lamp.energy, lamp.shape, lamp.size = 1500, "DISK", 7
    light = bpy.data.objects.new("PreviewKey", lamp)
    scene.collection.objects.link(light)
    light.location = (-3, -4, 8)
    common._look(light, (0, -1, 0.4))
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    scene.camera = cam
    os.makedirs(outdir, exist_ok=True)
    corners = [Vector((x, y, z)) for x in (-3.4, 1.1) for y in (-3.6, 1.125) for z in (-1.1, 1.82)]
    for name, direction, withdrawal in (("front", (0, -1, 0), 0), ("side", (1, 0, 0), 0),
                                        ("three-quarter", (1, -1.5, 0.85), 0),
                                        ("wind-up", (1, -1.5, 0.85), 0.25)):
        bit.location = Vector(g(0, 0.5, 2.4 - withdrawal))
        target = Vector((-1.15, -1.2375, 0.36))
        cam.location = target + Vector(direction).normalized() * 14
        common._look(cam, target)
        rotation = cam.rotation_euler.to_matrix().transposed()
        points = [rotation @ (point - target) for point in corners]
        width = max(v.x for v in points) - min(v.x for v in points)
        height = max(v.y for v in points) - min(v.y for v in points)
        cam.data.ortho_scale = max(width, height * 4 / 3) * 1.14
        scene.render.filepath = os.path.join(outdir, name + ".png")
        bpy.ops.render.render(write_still=True)
    bit.location = Vector(g(0, 0.5, 2.4))
    with open(os.path.join(outdir, "preview.json"), "w") as handle:
        json.dump({"engine": "Cycles", "device": bpy.context.scene.cycles.device, "samples": 12, "reference_ball_diameter_m": 2,
                   "views": ["front", "side", "three-quarter", "wind-up"], "windup_withdrawal_m": 0.25}, handle, indent=2)


if opts["render"]:
    preview(opts["render"])
