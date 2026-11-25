import math
import os
import runpy
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cycles_device

VC = ("paint", "pilot", "ancient_enamel", "hydraulic", "enamel", "elastomer", "steel")

BUILD = """
import os, runpy, shutil, sys
sys.path.insert(0, {here!r})
import bpy, common, polish
opts = {opts!r}
if opts is None:
    polish.enable = lambda **kwargs: None
elif not polish.options():
    polish.enable(**opts)
real = common.export
done = []
def export(root, path):
    if {glb!r}:
        # Multi-GLB recipes write under --out-dir and may read their files back.
        real(root, path)
        if os.path.splitext(os.path.basename(path))[0] == {glb!r}:
            done.append(path)
            shutil.copyfile(path, {out!r})
        return
    done.append(path)
    real(root, {out!r})
common.export = export
if {glb!r}:
    sys.argv = [{recipe!r}, "--", "--out-dir", {out!r} + ".d"]
else:
    sys.argv = [{recipe!r}, "--", "--out", {out!r}]
try:
    runpy.run_path({recipe!r}, run_name="__main__")
except (SystemExit, AssertionError) as e:
    print("RECIPE_STOPPED", e)
    if not done:
        roots = [o for o in bpy.context.scene.objects if o.parent is None and o.type == "EMPTY"]
        real(roots[0], {out!r})
"""


def value(text):
    if text in ("True", "False"):
        return text == "True"
    try:
        return int(text)
    except ValueError:
        return float(text)


def build(recipe, out, opts, tmp, tag, glb=None):
    script = os.path.join(tmp, tag + ".py")
    with open(script, "w") as f:
        f.write(BUILD.format(here=HERE, opts=opts, out=out, recipe=recipe, glb=glb))
    subprocess.run([os.environ.get("BLENDER", "blender"), "-b", "--factory-startup", "-P", script],
                   check=True, stdout=subprocess.DEVNULL)


def render(glb, base, size):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [o for o in scene.objects if o.type == "MESH"]
    for o in meshes:
        if "Bake" not in o.data.uv_layers:
            continue
        for m in o.data.materials:
            if m is None or m.name in VC or m.get("_bake") or not m.use_nodes:
                continue
            m["_bake"] = True
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = "Bake"
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(uv.outputs[0], sep.inputs[0])
            ramp = nt.nodes.new("ShaderNodeMapRange")
            ramp.inputs["To Min"].default_value = 0.45
            nt.links.new(sep.outputs[0], ramp.inputs["Value"])
            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs["Factor"].default_value = 1.0
            base_color = bsdf.inputs["Base Color"]
            if base_color.is_linked:
                nt.links.new(base_color.links[0].from_socket, mul.inputs["A"])
            else:
                mul.inputs["A"].default_value = base_color.default_value
            nt.links.new(ramp.outputs[0], mul.inputs["B"])
            nt.links.new(mul.outputs["Result"], base_color)
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        e = o.evaluated_get(dg)
        me = e.to_mesh()
        pts += [e.matrix_world @ v.co for v in me.vertices]
        e.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    centre, radius = (lo + hi) / 2, max((hi - lo).length / 2, 0.01)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 50
    cam.data.clip_start, cam.data.clip_end = radius * 0.01, radius * 20
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    scene.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"
    paths = []
    for tag, d in (("a", Vector((0.9, 1.3, 0.7))), ("b", Vector((-0.9, -1.3, 0.7)))):
        cam.location = centre + d.normalized() * radius * 3.0
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = base + "_" + tag + ".png"
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    recipe, out = os.path.abspath(os.path.join(HERE, argv[0])), os.path.abspath(argv[1])
    pairs = dict(a.split("=", 1) for a in argv[2:])
    glb = pairs.pop("glb", None)
    opts = {k: value(v) for k, v in pairs.items()}
    size = int(opts.pop("size", 480))
    with tempfile.TemporaryDirectory() as tmp:
        before, after = os.path.join(tmp, "before.glb"), os.path.join(tmp, "after.glb")
        build(recipe, before, None, tmp, "before", glb)
        build(recipe, after, opts, tmp, "after", glb)
        shots = render(before, os.path.join(tmp, "before"), size) + render(after, os.path.join(tmp, "after"), size)
        subprocess.run(["montage", *shots, "-tile", "2x2", "-geometry", "+0+0", "-quality", "82", out], check=True)
    print("POLISH_COMPARE", out)


main()
