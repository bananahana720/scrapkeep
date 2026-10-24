"""Board-camera and top-down stills of the dam hero.

Usage: blender -b --factory-startup -P hero_stills.py -- <model.glb> <out prefix>
Cycles on CPU. Blender's glTF importer maps mojulo's frame back to metres, z up.
"""
import math
import sys

import bpy
from mathutils import Vector

glb, prefix = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
sc.view_settings.view_transform = "AgX"
sc.render.image_settings.file_format = "JPEG"
sc.render.image_settings.quality = 88

bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in sc.objects if o.type == "MESH"]

# mojulo 3.0.0's lit glb stores sRGB tints in COLOR_0, which glTF defines as linear; decode them.
fixed = 0
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    nt_m = mat.node_tree
    for link in list(nt_m.links):
        if link.from_node.type in {"VERTEX_COLOR", "ATTRIBUTE"} and link.to_socket.name == "Base Color":
            g = nt_m.nodes.new("ShaderNodeGamma")
            g.inputs[1].default_value = 2.2
            nt_m.links.new(link.from_socket, g.inputs[0])
            nt_m.links.new(g.outputs[0], link.to_socket)
            fixed += 1
print("GAMMA_FIXED", fixed)
lo = Vector((min(v[i] for o in meshes for v in (o.matrix_world @ Vector(c) for c in o.bound_box)) for i in range(3)))
hi = Vector((max(v[i] for o in meshes for v in (o.matrix_world @ Vector(c) for c in o.bound_box)) for i in range(3)))
print("BOUNDS", tuple(round(x, 1) for x in lo), tuple(round(x, 1) for x in hi))

world = bpy.data.worlds.new("sky")
world.use_nodes = True
nt = world.node_tree
sky = nt.nodes.new("ShaderNodeTexSky")
sky.sun_elevation = math.radians(18)
sky.sun_rotation = math.radians(120)
nt.links.new(sky.outputs[0], nt.nodes["Background"].inputs[0])
nt.nodes["Background"].inputs[1].default_value = 0.3
sc.world = world

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.data.color = (1.0, 0.86, 0.7)
sun.data.angle = math.radians(1.5)
sun.rotation_euler = (math.radians(62), 0, math.radians(30))
sc.collection.objects.link(sun)


def shoot(name, loc, target, lens=24, ortho=None):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    sc.collection.objects.link(cam)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = 5000
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.lens = lens
    sc.camera = cam
    sc.render.filepath = f"{prefix}-{name}.jpg"
    bpy.ops.render.render(write_still=True)


# The board: low at the toe, downstream (+x), looking up at the concave face.
shoot("board", (215, -14, 5), (0, 0, 66), lens=17)
cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
shoot("top", (cx, cy + 0.01, hi.z + 400), (cx, cy, 0), ortho=max(hi.x - lo.x, hi.y - lo.y) * 1.02)
