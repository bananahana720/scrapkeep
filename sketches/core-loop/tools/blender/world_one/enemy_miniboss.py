"""PMB: heavy scrap impact press, three opaque surfaces with rigid pose bones.

Origin is the unchanged 2.3 m / 6.9 m collider centre; forward is Godot -Z.
blender -b --python enemy_miniboss.py -- [--out file.glb] [--render dir]
The optional previews use Cycles on CPU and do not enter the exported GLB.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import cycles_device
import polish
from common import Part

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.75}
common.SLOTS["part_state"] = {"vc": True, "rough": 0.4, "metal": 0.6}
common.SLOTS["core_state"] = {"color": "petrol", "rough": 0.4}
polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty("Miniboss")
GROUND = -3.45
SLATE = "6f7f8f"
WORN = common.mix("charcoal", "bone", 0.55)


def g(x, y, z):
    return (x, -z, y)


bone_rows = [
    ("MinibossBody", (0, 0, 0)),
    ("MinibossFootLeft", (-1.15, -1.9, 0)),
    ("MinibossFootRight", (1.15, -1.9, 0)),
    ("MinibossFistLeft", (-1.9, 1.5, 0)),
    ("MinibossFistRight", (1.9, 1.5, 0)),
    ("MinibossPlateLeft", (-2.05, 0.5, -1.95)),
    ("MinibossPlateRight", (2.05, 0.5, -1.95)),
    ("MinibossHalo", (0, 4.65, 0)),
]


def weights(part):
    layer = part.bm.verts.layers.deform.new()

    def bind(index):
        for vertex in part.bm.verts:
            if not vertex[layer]:
                vertex[layer][index] = 1.0
    return bind


def front_prism(part, slot, outline, depth, at, color):
    return part.prism(slot, outline, depth,
                      matrix=common.mtx(g(*at), (math.pi / 2, 0, 0)), color=color)


def finish(part):
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    obj = part.to_object(parent=root)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.deform.active
    if layer is not None:
        for vertex in bm.verts:
            w = vertex[layer]
            if len(w) > 1:
                keep = max(sorted(w.keys()), key=lambda k: w[k])
                w.clear()
                w[keep] = 1.0
        bm.to_mesh(obj.data)
    bm.free()
    return obj


b = Part("MinibossHull")
bind = weights(b)
SLOT = "fleet_paint"


def piston(a, end, radius, segments, color):
    faces = b.rod(SLOT, g(*a), g(*end), radius, segs=segments, color=color)
    top = Vector(g(*a))
    axis = (Vector(g(*end)) - top).normalized()
    layer = b.bm.verts.layers.deform.active
    for vertex in b.verts_of(faces):
        if abs((vertex.co - top).dot(axis)) < .00001:
            vertex[layer][0] = 1.0


b.cyl(SLOT, 1.55, 1.25, 1.4, segs=8, loc=g(0, -0.65, 0.1), color="petrol")
b.cyl(SLOT, 1.55, 2.05, 2.0, segs=8, loc=g(0, 1.05, 0.1), color="petrol")
b.cyl(SLOT, 1.58, 1.58, 0.18, segs=8, loc=g(0, -0.1, 0.1), color="charcoal")
front_prism(b, SLOT, [(-.65, -.35), (.65, -.35), (.85, .1), (.6, .55), (-.65, .5), (-.85, .05)],
            .8, (0, 2.4, -.8), "petrol")
b.box(SLOT, (1.05, .08, .15), loc=g(0, 2.45, -1.24), color="charcoal")
b.box(SLOT, (1.45, .5, .24), loc=g(0, 2.8, -.9), color=WORN)
for side in (-1, 1):
    front_prism(b, SLOT, [(-.7, -.5), (.6, -.5), (.8, .05), (.5, .5), (-.55, .45)],
                1.5, (side * 1.6, 1.65, .1), "oxide" if side < 0 else "petrol")
    b.cyl(SLOT, .38, .28, 1.3, segs=6, loc=g(side * .8, 1.7, 1.55), color="charcoal")
    b.rod(SLOT, g(side * 1.4, -.9, .55), g(side * 1.5, 1.75, .9), .12, segs=5, color=WORN)
    b.rod(SLOT, g(side * 2.05, -.9, -1.95), g(side * 2.05, 1.7, -1.95), .13, segs=6, color="charcoal")
for x, height in [(-1.4, .6), (-.72, 1.0), (0, 1.25), (.72, .9), (1.4, .55)]:
    front_prism(b, SLOT, [(-.22, 0), (.22, 0), (.12, height), (-.08, height + .1)],
                .5, (x, 2.65, .15), "oxide" if x < 0 else WORN)
bind(0)
for side, index in [(-1, 1), (1, 2)]:
    b.rod(SLOT, g(side * 1.0, -1.4, .05), g(side * 1.15, -2.75, .3), .32, segs=6, color="charcoal")
    b.rod(SLOT, g(side * 1.2, -1.55, -.4), g(side * 1.15, -2.75, -.2), .14, segs=5, color=WORN)
    front_prism(b, SLOT, [(-.65, -.3), (.65, -.3), (.68, .05), (.45, .5), (-.4, .5), (-.65, .15)],
                1.55, (side * 1.15, -3.15, -.2), "oxide" if side < 0 else "petrol")
    bind(index)
for side, index in [(-1, 3), (1, 4)]:
    piston((side * 1.95, 1.5, 0), (side * 2.3, -.95, -.45), .33, 6, "charcoal")
    piston((side * 2.05, 1.25, -.35), (side * 2.2, -.7, -.8), .12, 5, WORN)
    front_prism(b, SLOT, [(-.55, -.65), (.55, -.65), (.7, -.3), (.55, .55), (-.5, .65), (-.7, .15)],
                1.35, (side * 2.3, -1.0, -.65), "oxide")
    b.box(SLOT, (1.0, .1, .12), loc=g(side * 2.3, -.55, -1.35), color=WORN)
    bind(index)
b.ring(SLOT, 1.45, 1.65, .14, segs=12, loc=g(0, 4.65, 0), color="mint")
for angle in (0, 2.1, 4.2):
    b.cyl(SLOT, .12, .0, .4, segs=4,
          loc=g(math.cos(angle) * 1.55, 4.9, math.sin(angle) * 1.55), color="mint")
bind(7)
hull = finish(b)

p = Part("MinibossArmour")
p.subsurf = 0
bind_plate = weights(p)
for side, index in [(-1, 5), (1, 6)]:
    outline = [(-.96, -1.7), (.96, -1.7), (1.03, -.95), (.95, 1.55), (.55, 1.9), (-.7, 1.75), (-1.03, .7)]
    front_prism(p, "part_state", outline, .45, (side * 1.02, .55, -2.0), SLATE)
    p.box("part_state", (.1, .10, 2.65), loc=g(side * 1.8, .45, -2.28), color="000000")
    p.box("part_state", (1.55, .10, .1), loc=g(side * 1.02, 1.95, -2.28), color="000000")
    for y in (-.65, 1.4):
        p.rod("part_state", g(side * 1.78, y, -2.24), g(side * 1.78, y, -2.34), .13, segs=5, color="000000")
    bind_plate(index)
armour = finish(p)

c = Part("MinibossCore")
c.subsurf = 0
c.uv("core_state", 1.0, u=10, v=6, loc=g(0, .6, -1.725), scale=(1, .6, 1))
core = c.to_object(origin=g(0, .6, -1.725), parent=root)

rig_data = bpy.data.armatures.new("MinibossPose")
rig = bpy.data.objects.new("MinibossPose", rig_data)
bpy.context.scene.collection.objects.link(rig)
rig.parent = root
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, at in bone_rows:
    bone = rig_data.edit_bones.new(name)
    bone.head = g(*at)
    bone.tail = Vector(bone.head) + Vector((0, 0, .3))
bpy.ops.object.mode_set(mode="OBJECT")
for mesh in (hull, armour):
    for name, _ in bone_rows:
        mesh.vertex_groups.new(name=name)
    modifier = mesh.modifiers.new("RigidPose", "ARMATURE")
    modifier.object = rig
    mesh.parent = rig

bpy.context.view_layer.update()
triangles = common.tri_total(root)
draws = sum(len(o.data.materials) for o in (hull, armour, core))
if triangles > 8800 or draws != 3:
    raise SystemExit("PMB budget exceeded: %d T / %d D" % (triangles, draws))
opts = common.args()
out = opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_miniboss.glb")
common.export(root, out)
import json
import struct
with open(out, "rb") as stream:
    data = stream.read()
gltf = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
vertices = sum(gltf["accessors"][s["attributes"]["POSITION"]]["count"]
               for mesh in gltf["meshes"] for s in mesh["primitives"])
if vertices > 4900:
    raise SystemExit("PMB vertex ceiling exceeded: %d" % vertices)
print("PMB_ASSET %d T / %d V / %d D" % (triangles, vertices, draws))


def preview_pose(state):
    crouch = state == "crouch"
    vented = state == "vented"
    drop = -.9 if crouch else (-.3 if vented else 0)
    for name, _ in bone_rows:
        bone = rig.pose.bones[name]
        bone.matrix = rig_data.bones[name].matrix_local.copy()
        if name in ("MinibossBody", "MinibossFistLeft", "MinibossFistRight", "MinibossPlateLeft", "MinibossPlateRight"):
            bone.matrix = Matrix.Translation((0, 0, drop)) @ bone.matrix
        if "Fist" in name and crouch:
            bone.matrix = Matrix.Translation((0, -.5, .35)) @ bone.matrix
        if "Plate" in name and vented:
            side = -1 if name.endswith("Left") else 1
            pivot = Vector(g(side * 2.05, .5 + drop, -1.95))
            bone.matrix = (Matrix.Translation(pivot) @ Matrix.Rotation(side * 1.15, 4, "Z")
                           @ Matrix.Translation(-pivot) @ bone.matrix)
        if name == "MinibossHalo" and not vented:
            bone.scale = (0, 0, 0)
    core.location = Vector(g(0, .6 + drop, -1.725))
    core.scale = (1.5, 1.5, 1.5) if vented else (.8, .8, .8)
    bsdf = core.data.materials[0].node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = common.rgba("mint" if vented else "petrol")
    bsdf.inputs["Emission Color"].default_value = common.rgba("mint")
    bsdf.inputs["Emission Strength"].default_value = 1.2 if vented else 0
    bpy.context.view_layer.update()


def render_previews(directory):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 8
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PMB preview world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.35, .42, .5, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .5
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, GROUND))
    bpy.context.object.data.materials.append(common._flat("Preview ground", "sandstone"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=(5, 0, GROUND + 1))
    bpy.context.object.data.materials.append(common._flat("2 m reference ball", "bone"))
    for name, at, energy, size in [("Key", (-6, 8, 11), 1800, 7), ("Fill", (7, 4, 7), 1100, 6), ("Rim", (1, -6, 8), 1800, 5)]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.shape = "DISK"
        light.size = size
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = at
        common._look(obj, (0, 0, 0))
    cam = bpy.data.objects.new("Preview camera", bpy.data.cameras.new("Preview camera"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 13
    cam.location = (1.4, 22, 5.5)
    common._look(cam, (1.4, 0, .3))
    scene.camera = cam
    os.makedirs(directory, exist_ok=True)
    for label, yaw, state in [("front", 0, "closed"), ("side", math.pi / 2, "closed"),
                              ("three-quarter", -.65, "closed"), ("crouch", -.65, "crouch"),
                              ("vented", -.65, "vented")]:
        preview_pose(state)
        root.rotation_euler.z = yaw
        scene.render.filepath = os.path.join(directory, label + ".png")
        bpy.ops.render.render(write_still=True)
    print("PMB_PREVIEWS Cycles", bpy.context.scene.cycles.device, "/ 24 samples / five views / reference ball diameter 2 m")


if opts["render"]:
    render_previews(opts["render"])
