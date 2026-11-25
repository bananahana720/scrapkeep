"""Highdraft island modules, metres, cosmetic only. Blender 5.2.2.

blender -b --factory-startup --threads 2 --python-exit-code 1 --python \
  sketches/core-loop/tools/blender/highdraft/islands.py -- --out-dir DIR
Add --preview-dir DIR to reimport and render the exported GLBs on Cycles CPU.
Stone/steel reuse the Dig family contract and existing source maps. No atlas,
fan, collision, runtime placement or root-motion animation is authored here.
"""

import argparse
import hashlib
import json
import math
import os
import random
import struct
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import common
import cycles_device
import polish

SKETCH = Path(common.SKETCH)
FILES = ("island_small", "island_medium", "island_large", "island_rim",
         "island_rib", "bridge_skin", "return_ramp_skin", "barge_skin")
LANDFORM = dict(bevel=0, bake_slots=("stone",))
POLISH = {"island_rim": dict(bevel=.03, bevel_min=.1), "island_rib": dict(bevel=.04, bevel_min=.1),
          "bridge_skin": dict(bevel=0), "return_ramp_skin": dict(bevel=0),
          "barge_skin": dict(bevel=.04, bevel_min=.15)}
HARDWARE_CAP = (400, 450, 1)
CHALK = "c8bda5"
PETROL = "53686d"
BONE = "d2c5a5"
DARK = "242a28"
OXIDE = "9b513a"


def xyz(p):
    """Godot X,Y,Z to Blender X,-Z,Y; exporter applies the inverse once."""
    return (p[0], -p[2], p[1])


def marker(root, name, at=(0, 0, 0)):
    return common.empty(name, xyz(at), root)


def face(part, points, color):
    f = part.bm.faces.new(points)
    part.paint([f], "paint", color)


def material(family):
    mat = common.material("paint")
    mat.name = family
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95 if family == "stone" else 0.8
    source = "sandstone-strata.webp" if family == "stone" else "rusted-salvaged-plate.webp"
    image = bpy.data.images.load(str(SKETCH / "assets" / "textures" / source))
    import numpy as np
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape((-1, 4))
    luminance = pixels[:, :3] @ np.array((0.2126, 0.7152, 0.0722))
    gain = 0.85 / max(float(luminance.mean()), 0.05)
    pixels[:, :3] = np.clip((luminance[:, None] * 0.65 + pixels[:, :3] * 0.35) * gain, 0, 1)
    if family == "stone":
        pixels[:, :3] = 0.85 + (pixels[:, :3] - 0.85) * 0.30
    image.pixels.foreach_set(pixels.ravel())
    image.update()
    image.file_format = "PNG"
    image.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    attr = next(n for n in mat.node_tree.nodes if n.type == "VERTEX_COLOR")
    mat.node_tree.links.new(attr.outputs["Color"], mix.inputs[1])
    mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[2])
    mat.node_tree.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    return mat


def finish(part, root, family):
    bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    obj = part.to_object((0, 0, 0), root)
    obj.data.materials.clear()
    obj.data.materials.append(material(family))
    uv = obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda k: abs(normal[k]))
        axes = (0, 1) if axis == 2 else ((0, 2) if axis == 1 else (1, 2))
        metres = 5.0 if family == "stone" else 1.5
        if family == "stone" and normal.z > 0.99 and all(abs(obj.data.vertices[obj.data.loops[i].vertex_index].co.z) < 0.0001 for i in poly.loop_indices):
            metres = 160.0
        for i in poly.loop_indices:
            v = obj.data.vertices[obj.data.loops[i].vertex_index].co
            uv.data[i].uv = (v[axes[0]] / metres, v[axes[1]] / metres)
    return obj


def box(part, size, at, color):
    return part.box("paint", (size[0], size[2], size[1]), loc=xyz(at), color=color)


def island(size, name, keels):
    root = common.empty(name)
    p = common.Part("IslandStone")
    rng = random.Random(name)
    radius = size / 2
    n = 128
    rings = []
    for r, height in [(radius * 0.12, 0), (radius * 0.38, 0),
                      (radius * 0.66, 0), (radius, 0),
                      (radius, -0.35), (radius, -0.85), (radius, -1.2)]:
        rings.append([p.bm.verts.new((r * math.cos(i * math.tau / n),
                                     r * math.sin(i * math.tau / n), height))
                      for i in range(n)])
    centre = p.bm.verts.new((0, 0, 0))
    for i in range(n):
        j = (i + 1) % n
        face(p, (centre, rings[0][i], rings[0][j]), CHALK)
        for row in range(len(rings) - 1):
            tone = common.mix(CHALK, BONE, rng.uniform(0.02, 0.22))
            if row >= 3:
                tone = tuple(c * (0.88, 0.77, 0.90)[row - 3] for c in tone)
            face(p, (rings[row][i], rings[row + 1][i], rings[row + 1][j], rings[row][j]), tone)
    bottom = p.bm.verts.new((0, 0, -1.2))
    for i in range(n):
        face(p, (bottom, rings[-1][(i + 1) % n], rings[-1][i]), common.mix(CHALK, DARK, 0.23))
    marker(root, "StoneTop")
    if name == "island_medium":
        marker(root, "TwinKeel")
    elif name == "island_large":
        marker(root, "LobeKeel")
    for part_name, at, width in keels:
        with p.region(subsurf=1, detail=1, fit=True):
            keel(p, at, width, rng)
        marker(root, part_name, at)
    for label, at in [("rim_n", (0, 0, -radius)), ("rim_e", (radius, 0, 0)),
                      ("rim_s", (0, 0, radius)), ("rim_w", (-radius, 0, 0))]:
        marker(root, label, at)
    if name == "island_large":
        for i in range(3):
            a = i * math.tau / 3
            marker(root, "fan_%d" % (i + 1), (10 * math.cos(a), -3, 10 * math.sin(a)))
    else:
        x = 6 if size == 28 else 8
        marker(root, "fan_l", (-x, -3, 0))
        marker(root, "fan_r", (x, -3, 0))
    marker(root, "frame_root", (0, -1.2, 0))
    finish(p, root, "stone")
    return root


def keel(p, centre, width, rng):
    n = 20
    rows = []
    for row, (y, scale, twist) in enumerate([(-2, 0.86, 0), (-2.8, 1, 0.03),
                                           (-4.0, 0.96, 0.05), (-5.3, 0.81, 0.08),
                                           (-6.1, 0.77, 0.08), (-7.35, 0.52, 0.12),
                                           (-8, 0.34, 0.14)]):
        points = []
        for i in range(n):
            a = i * math.tau / n
            bend = 0 if row in (0, 1, 6) else math.sin(a * 2 + twist) * 0.16
            x = centre[0] + width * 0.5 * scale * math.cos(a)
            z = centre[2] + 3.5 * scale * math.sin(a)
            points.append(p.bm.verts.new(xyz((x, y + bend, z))))
        rows.append(points)
    face(p, tuple(reversed(rows[0])), common.mix(CHALK, DARK, 0.15))
    for row in range(len(rows) - 1):
        for i in range(n):
            j = (i + 1) % n
            tone = common.mix(CHALK, BONE, rng.uniform(0.0, 0.25))
            gain = (0.83, 0.95, 0.85, 0.90, 0.80, 0.93)[row]
            tone = tuple(c * gain for c in tone)
            face(p, (rows[row][i], rows[row][j], rows[row + 1][j], rows[row + 1][i]), tone)
    face(p, tuple(rows[-1]), common.mix(CHALK, DARK, 0.20))


def hardware(name):
    root = common.empty(name)
    p = common.Part("HardwareSkin")
    if name == "island_rim":
        outline = [(-1.9, 0), (1.9, 0), (2, -0.1), (2, -0.6),
                   (1.9, -0.7), (-1.9, -0.7), (-2, -0.6), (-2, -0.1)]
        p.prism("paint", outline, 0.35, matrix=common.mtx((0, 0, -0.175)), color=BONE)
        box(p, (4, 1.8, 0.25), (0, -0.9, 0.55), PETROL)
        box(p, (4, 0.10, 0.04), (0, -0.44, 0.68), DARK)
        for x in (-1.65, 0.8):
            box(p, (0.35, 0.10, 0.015), (x, -1.0, 0.69), OXIDE)
        marker(root, "Nosing", (0, -0.175, 0.35))
        marker(root, "Fascia", (0, -0.9, 0.55))
        marker(root, "join_l", (-2, 0, 0))
        marker(root, "join_r", (2, 0, 0))
        marker(root, "cable_foot", (0, -1, 0))
    elif name == "island_rib":
        box(p, (3.2, 0.35, 0.35), (1.6, 0, 0), PETROL)
        box(p, (0.8, 0.35, 0.35), (3.6, 0, 0), BONE)
        box(p, (0.8, 0.32, 0.8), (0.4, -0.335, 0), DARK)
        box(p, (0.8, 0.08, 0.8), (0.4, -0.535, 0), BONE)
        marker(root, "Beam", (2, 0, 0))
        marker(root, "BearingFoot", (0.4, -0.375, 0))
        marker(root, "join_a")
        marker(root, "join_b", (4, 0, 0))
    elif name in ("bridge_skin", "return_ramp_skin"):
        box(p, (7.3, 0.15, 4), (0, -0.075, 0), PETROL)
        for x in (-3.825, 3.825):
            box(p, (0.35, 0.15, 4), (x, -0.075, 0), BONE)
        marker(root, "TopBay" if name == "bridge_skin" else "RampBay")
        marker(root, "EdgeStrip_l", (-3.825, 0, 0))
        marker(root, "EdgeStrip_r", (3.825, 0, 0))
        marker(root, "bay_n", (0, 0, -2))
        marker(root, "bay_s", (0, 0, 2))
        if name == "bridge_skin":
            marker(root, "rim_l", (-4, 0, 0))
            marker(root, "rim_r", (4, 0, 0))
        else:
            marker(root, "net_join", (0, 0, 2))
    elif name == "barge_skin":
        box(p, (14, 0.15, 14), (0, 0.925, 0), PETROL)
        rows = []
        for y, extent in [(0.85, 7), (-0.95, 7), (0.85, 6.45), (-0.95, 6.45)]:
            rows.append([p.bm.verts.new(xyz((x, y, z))) for x, z in
                         [(-extent, -extent), (extent, -extent), (extent, extent), (-extent, extent)]])
        for i in range(4):
            j = (i + 1) % 4
            for a, b, tone in [(0, 1, DARK), (2, 3, PETROL), (0, 2, BONE), (1, 3, DARK)]:
                face(p, (rows[a][i], rows[a][j], rows[b][j], rows[b][i]), tone)
        for x in (-6.45, 6.45):
            box(p, (0.3, 1.7, 0.4), (x, -0.05, -6.8), BONE)
            box(p, (0.3, 1.7, 0.4), (x, -0.05, 6.8), BONE)
        for z in (-6.8, 6.8):
            box(p, (3.0, 0.15, 0.12), (0, 0.075, z), OXIDE)
        marker(root, "Top", (0, 1, 0))
        marker(root, "Belt", (0, -0.05, 0))
        marker(root, "dock_l", (-7, 1, 0))
        marker(root, "dock_r", (7, 1, 0))
        marker(root, "vane", (0, 1.2, 5))
        marker(root, "fan_l", (-4, -1, 0))
        marker(root, "fan_r", (4, -1, 0))
    finish(p, root, "steel")
    return root


def exported_metrics(path):
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    tris = verts = draws = 0
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            draws += 1
            verts += doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            tris += doc["accessors"][prim["indices"]]["count"] // 3
    cap = (8000, 24000, 1) if path.stem in FILES[:3] else HARDWARE_CAP
    assert 0 < tris <= cap[0] and 0 < verts <= cap[1] and draws == 1, (path, tris, verts, draws)
    assert len(doc["materials"]) == 1
    return {"file": path.name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "triangles": tris, "vertices": verts, "draws": draws,
            "materials": len(doc["materials"]), "nodes": [n["name"] for n in doc["nodes"]]}


def preview(path, outdir, samples):
    common.reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    points = [o.matrix_world @ Vector(v) for o in objects for v in o.bound_box]
    low = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1,
                                       location=(high.x + 2.0, low.y - 2.0, low.z + 1))
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("reference", "bone"))
    for poly in ball.data.polygons:
        poly.use_smooth = True
    high.x += 3.0
    low.y -= 3.0
    high.z = max(high.z, low.z + 2)
    target = (low + high) / 2
    extent = high - low
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.seed = 20261006
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("morning")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("a9b6c0")
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    light = bpy.data.lights.new("morning_left", "AREA")
    light.energy = 1200 * max(1, extent.x / 5) ** 2
    light.shape = "DISK"
    light.size = max(6, extent.x * 0.65)
    lamp = bpy.data.objects.new(light.name, light)
    scene.collection.objects.link(lamp)
    lamp.location = target + Vector((-extent.x, -extent.x, max(extent.x, 6)))
    common._look(lamp, target)
    cam = bpy.data.objects.new("preview_camera", bpy.data.cameras.new("preview_camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    distance = max(extent) * 3 + 12
    for label, direction in [("front", (0, 1, 0.13)), ("side", (1, 0, 0.13)),
                             ("three_quarter", (1, 1, 0.85))]:
        cam.location = target + Vector(direction).normalized() * distance
        common._look(cam, target)
        bpy.context.view_layer.update()
        inverse = cam.matrix_world.inverted()
        corners = [Vector((x, y, z)) for x in (low.x, high.x)
                   for y in (low.y, high.y) for z in (low.z, high.z)]
        projected = [inverse @ v for v in corners]
        width = max(v.x for v in projected) - min(v.x for v in projected)
        height = max(v.y for v in projected) - min(v.y for v in projected)
        cam.data.ortho_scale = max(width, height * 1.5) * 1.15
        scene.render.filepath = str(outdir / (path.stem + "_" + label + ".png"))
        bpy.ops.render.render(write_still=True)
        print("CPU_PREVIEW", scene.render.filepath, "reference_diameter=2", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path(common.MODELS) / "highdraft")
    parser.add_argument("--preview-dir", type=Path)
    parser.add_argument("--preview-only", action="store_true")
    parser.add_argument("--samples", type=int, default=12)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.out_dir.mkdir(parents=True, exist_ok=True)
    records = []
    for name in FILES:
        path = args.out_dir / (name + ".glb")
        if not args.preview_only:
            common.reset()
            if name in POLISH:
                polish.enable(bake_slots=("steel",), **POLISH[name])
            else:
                polish.enable(**LANDFORM)
            if name == "island_small":
                root = island(28, name, [("OffsetKeel", (3, -5, 0), 8)])
            elif name == "island_medium":
                root = island(36, name, [("TwinKeel_l", (-8, -5, 0), 8),
                                        ("TwinKeel_r", (8, -5, 0), 8)])
            elif name == "island_large":
                keels = [("LobeKeel_%d" % (i + 1),
                          (11 * math.cos(i * math.tau / 3), -5, 11 * math.sin(i * math.tau / 3)), 9)
                         for i in range(3)]
                root = island(44, name, keels)
            else:
                root = hardware(name)
            common.export(root, str(path))
        row = exported_metrics(path)
        records.append(row)
        print("MHI_METRIC", json.dumps(row, sort_keys=True), flush=True)
    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=True)
        (args.preview_dir / "metrics.json").write_text(json.dumps(records, indent=2) + "\n")
        for name in FILES:
            preview(args.out_dir / (name + ".glb"), args.preview_dir, args.samples)


if __name__ == "__main__":
    main()
