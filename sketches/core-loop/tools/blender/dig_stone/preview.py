"""Cycles CPU views of the actual exported GLBs, with a calibrated 2 m ball.

The Blender bed material is an offline world-position approximation using the
same thickness table and palette. It is never exported into the scenery GLBs.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
from stone_surface import BEDS

SKETCH = HERE.parents[2]
ROOT = SKETCH.parents[1]
MODELS = SKETCH / "assets/models/dig_stone"
NAMES = ("cut_face_long", "cut_face_scoop", "rubble_cluster", "breach_socket", "bed_floor", "bed_cut", "bed_rubble", "bed_recess")


def math_node(nodes, links, operation, a, b=None):
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    for index, value in enumerate((a, b)):
        if value is None:
            continue
        if isinstance(value, (float, int)):
            node.inputs[index].default_value = value
        else:
            links.new(value, node.inputs[index])
    return node.outputs[0]


def bed_material():
    mat = bpy.data.materials.new("stone_CPU_shared_beds")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95
    geo = nodes.new("ShaderNodeNewGeometry")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], xyz.inputs[0])
    warp = math_node(nodes, links, "MULTIPLY", xyz.outputs["X"], 0.68)
    warp = math_node(nodes, links, "ADD", warp, math_node(nodes, links, "MULTIPLY", xyz.outputs["Y"], -0.23))
    warp = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "SINE", warp), 0.12)
    height = math_node(nodes, links, "ADD", xyz.outputs["Z"], math_node(nodes, links, "MULTIPLY", xyz.outputs["X"], 0.12))
    height = math_node(nodes, links, "ADD", height, warp)
    height = math_node(nodes, links, "FLOORED_MODULO", height, sum(BEDS))
    factor = math_node(nodes, links, "DIVIDE", height, sum(BEDS))
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "LINEAR"
    elements = ramp.color_ramp.elements
    tones = [common.srgb("sandstone"), common.srgb("bone"),
             common.mix("sandstone", "bone", 0.18), (0.721, 0.576, 0.411),
             common.mix("sandstone", "bone", 0.55), common.srgb("sandstone"),
             common.mix("sandstone", "bone", 0.4), (0.696, 0.55, 0.385)]
    edge = 0.0
    for i, thickness in enumerate(BEDS[3:] + BEDS[:3]):
        color = common.rgba(tones[i])
        start = elements[0] if i == 0 else elements.new(edge / sum(BEDS))
        start.color = color
        end = elements.new((edge + thickness - 0.045) / sum(BEDS))
        end.color = color
        edge += thickness
    elements[-1].color = common.rgba(tones[-1])
    links.new(factor, ramp.inputs[0])
    normal_xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], normal_xyz.inputs[0])
    up = nodes.new("ShaderNodeMapRange")
    up.interpolation_type = "SMOOTHSTEP"
    up.inputs["From Min"].default_value = 0.50
    up.inputs["From Max"].default_value = 0.66
    links.new(normal_xyz.outputs["Z"], up.inputs["Value"])
    mix = nodes.new("ShaderNodeMixRGB")
    links.new(up.outputs[0], mix.inputs[0])
    links.new(ramp.outputs[0], mix.inputs[1])
    mix.inputs[2].default_value = common.rgba(common.mix("sandstone", "bone", 0.24))
    links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    feet = nodes.new("ShaderNodeValToRGB")
    feet.color_ramp.interpolation = "LINEAR"
    feet.color_ramp.elements[0].color = (0.72, 0.72, 0.72, 1)
    feet.color_ramp.elements[1].color = (1, 1, 1, 1)
    edge = 0.0
    for thickness in BEDS[3:] + BEDS[:3]:
        if edge > 0:
            feet.color_ramp.elements.new(max(0, (edge - 0.025) / sum(BEDS))).color = (1, 1, 1, 1)
            feet.color_ramp.elements.new(edge / sum(BEDS)).color = (0.72, 0.72, 0.72, 1)
        feet.color_ramp.elements.new((edge + 0.045) / sum(BEDS)).color = (1, 1, 1, 1)
        edge += thickness
    links.new(factor, feet.inputs[0])
    foot_mix = nodes.new("ShaderNodeMixRGB")
    foot_mix.blend_type = "MULTIPLY"
    links.new(up.outputs[0], foot_mix.inputs[0])
    invert_up = math_node(nodes, links, "SUBTRACT", 1.0, up.outputs[0])
    links.new(invert_up, foot_mix.inputs[0])
    links.new(mix.outputs[0], foot_mix.inputs[1])
    links.new(feet.outputs[0], foot_mix.inputs[2])
    links.new(foot_mix.outputs[0], bsdf.inputs["Base Color"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7
    noise.inputs["Detail"].default_value = 2
    links.new(geo.outputs["Position"], noise.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    bump.inputs["Distance"].default_value = 0.025
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def flat(name, color, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = common.rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def stage(name, samples, outdir):
    common.reset()
    path = MODELS / (name + ".glb")
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    lo = Vector([min(p[k] for p in pts) for k in range(3)])
    hi = Vector([max(p[k] for p in pts) for k in range(3)])
    mat = bed_material()
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.denoising_use_gpu = False
    scene.cycles.max_bounces = 4
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("CPU_studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.36, 0.4, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    scene.world = world
    ground = lo.z - 0.025
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, ground))
    bpy.context.object.name = "PreviewGround_NOT_EXPORTED"
    bpy.context.object.data.materials.append(flat("preview_ground", "77746d"))
    ball_location = Vector((hi.x + 1.6, hi.y + 1.2, ground + 1))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=ball_location)
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m_NOT_EXPORTED"
    ball.data.materials.append(flat("reference_ball", "petrol", 0.6))
    for f in ball.data.polygons:
        f.use_smooth = True
    assert all(abs(d - 2) < 0.001 for d in ball.dimensions)
    for label, location, energy, size in [
        ("Key", (2, 9, 12), 2100, 9), ("Fill", (-7, 2, 7), 650, 7), ("Rim", (3, -8, 10), 1350, 6)]:
        lamp = bpy.data.lights.new(label, "AREA")
        lamp.energy, lamp.shape, lamp.size = energy, "DISK", size
        obj = bpy.data.objects.new(label, lamp)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        common._look(obj, (0, 0, 1.5))
    camera = bpy.data.objects.new("CPUPreviewCamera_NOT_EXPORTED", bpy.data.cameras.new("CPUPreviewCamera"))
    bpy.context.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera
    outdir.mkdir(parents=True, exist_ok=True)
    files = []
    for label, direction in (("front", (0, 1, 0.18)), ("side", (1, 0, 0.22)), ("three-quarter", (0.75, 1, 0.65))):
        target = (lo + hi) / 2
        camera.location = target + Vector(direction).normalized() * 30
        common._look(camera, target)
        right = camera.rotation_euler.to_quaternion() @ Vector((1, 0, 0))
        right.z = 0
        right.normalize()
        edge = max((p - target).dot(right) for p in pts)
        beside = target + right * (edge + 1.65)
        ball.location = (beside.x, beside.y, ground + 1)
        bpy.context.view_layer.update()
        combined = pts + [ball.matrix_world @ Vector((x, y, z)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        inverse = camera.matrix_world.inverted()
        projected = [inverse @ p for p in combined]
        xmin, xmax = min(p.x for p in projected), max(p.x for p in projected)
        ymin, ymax = min(p.y for p in projected), max(p.y for p in projected)
        right = camera.matrix_world.to_quaternion() @ Vector((1, 0, 0))
        up = camera.matrix_world.to_quaternion() @ Vector((0, 1, 0))
        camera.location += right * ((xmin + xmax) / 2) + up * ((ymin + ymax) / 2)
        camera.data.ortho_scale = max(xmax - xmin, (ymax - ymin) * 960 / 720) * 1.13
        scene.render.filepath = str(outdir / (name + "-" + label + ".png"))
        bpy.ops.render.render(write_still=True)
        png = Path(scene.render.filepath)
        files.append({"view": label, "file": png.name, "sha256": hashlib.sha256(png.read_bytes()).hexdigest()})
        print("MDS_PREVIEW %s %s: Cycles %s, %d samples, 2 m ball" % (name, label, bpy.context.scene.cycles.device, samples), flush=True)
    return {"asset": path.name, "glb_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "renderer": "Cycles " + bpy.context.scene.cycles.device, "threads": 2, "samples": samples, "reference_ball_diameter_m": 2, "views": files}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", choices=NAMES)
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/local/dress-preview/MDS/release")
    opt = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    rows = [stage(name, opt.samples, opt.out) for name in ((opt.asset,) if opt.asset else NAMES)]
    suffix = "-" + opt.asset if opt.asset else ""
    (opt.out / ("preview-receipt" + suffix + ".json")).write_text(json.dumps(rows, indent=2) + "\n")
    print("MDS_PREVIEW: PASS (%d GLBs, %d CPU views)" % (len(rows), len(rows) * 3), flush=True)


if __name__ == "__main__":
    main()
