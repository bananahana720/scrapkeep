"""Cycles CPU stills of a rogue glb (a raw shell or a finished asset) for review pages.

blender -b --factory-startup -P stills.py -- <in.glb> <out_dir> [--shell] [--views front,side,...]
Origin conventions: a finished asset has its collider centre at the origin, a raw shell
has its ground at z = 0 (--shell). Forward is +Y (Godot -Z). A 1.84 m ball stands beside
it for scale. CPU only, so it never touches the GPUs.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
shell = "--shell" in argv
views = "three-quarter,front,side,back,top"
if "--views" in argv:
    views = argv[argv.index("--views") + 1]
size = 720
if "--size" in argv:
    size = int(argv[argv.index("--size") + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=src)
for o in list(scene.objects):
    if o.type in ("CAMERA", "LIGHT") or o.name == "static":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.update()
meshes = [o for o in scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
ground = lo.z
centre = (lo + hi) / 2
extent = max(hi - lo)

# Vertex colours are the paint: route the colour attribute into every material, with
# mojulo's sRGB-in-linear decode (gamma 2.2) on raw shells.
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None or bsdf.inputs["Base Color"].is_linked is False and not shell:
        continue
    if shell:
        attr = nt.nodes.new("ShaderNodeVertexColor")
        gamma = nt.nodes.new("ShaderNodeGamma")
        gamma.inputs["Gamma"].default_value = 2.2
        nt.links.new(attr.outputs["Color"], gamma.inputs["Color"])
        nt.links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 8
scene.render.resolution_x = size
scene.render.resolution_y = size
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "JPEG"
scene.render.image_settings.quality = 88
world = bpy.data.worlds.new("still world")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.42, .46, .5, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .6

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, ground))
gmat = bpy.data.materials.new("ground")
gmat.use_nodes = True
gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.45, .33, .2, 1)
bpy.context.object.data.materials.append(gmat)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=.92,
                                     location=(hi.x + 1.6, lo.y + 1.0, ground + .92))
bmat = bpy.data.materials.new("ball")
bmat.use_nodes = True
bmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.62, .55, .42, 1)
bpy.context.object.data.materials.append(bmat)
for name, at, energy in [("Key", (-8, 10, 14), 2600), ("Fill", (9, 5, 8), 1300), ("Rim", (2, -10, 10), 2200)]:
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.size = 8
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = Vector(at) + Vector((centre.x, centre.y, ground))
    obj.rotation_euler = (Vector(centre) - obj.location).to_track_quat("-Z", "Y").to_euler()

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = extent * 1.25 + 2.5
dirs = {
    "front": (0, 1, 0.12), "side": (-1, 0, 0.12), "back": (0, -1, 0.12),
    "three-quarter": (-0.75, 0.9, 0.55), "top": (0.001, 0.001, 1), "rear-quarter": (0.75, -0.9, 0.5),
}
os.makedirs(out, exist_ok=True)
base = os.path.splitext(os.path.basename(src))[0]
for view in views.split(","):
    d = Vector(dirs[view]).normalized()
    cam.location = centre + d * (extent * 3)
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, "%s-%s.jpg" % (base, view))
    bpy.ops.render.render(write_still=True)
print("STILLS", base, views, "extent %.2f m" % extent, "size", [round(v, 2) for v in (hi - lo)])
