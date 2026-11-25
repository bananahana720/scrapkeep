"""Highdraft sky, BUILD-SPEC Sky fence. Metres; authored coordinates are Godot Y-up.

blender -b --factory-startup --threads 4 --python-exit-code 1 --python \
  sketches/core-loop/tools/blender/highdraft/sky.py -- --out-dir /tmp/mhs
Add --render-dir artifacts/local/dress-preview/MHS for GLB reimport CPU previews.
Static parts are merged into one surface; named empties preserve the assembly contract.
Materials reuse common's vertex-paint, ancient_enamel and translucent glass treatments.
No new atlas, collision, placement, runtime loader, light or animation is exported.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys

import bmesh
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import common
import cycles_device
import polish

ASSETS = ("sky_cloud", "sky_mesa", "sky_cradle", "sky_loom", "sky_blades")
POLISH = {"sky_cradle": dict(bevel=.12, bevel_min=.5), "sky_loom": dict(bevel=.1, bevel_min=.5),
          "sky_blades": dict(bevel=.15, bevel_min=.5), "sky_mesa": dict(bevel=0, bake_slots=("M1_stone",))}
HARDWARE_CAP = (500, 320, 1)
LANDFORM_CAP = (1000, 1000, 2)
PETROL = "53686d"
CHALK = "c8bda5"
CLOUD = "ece7da"


def xyz(p):
    return (p[0], -p[2], p[1])


def socket(root, name, position):
    return common.empty(name, xyz(position), root)


def face(part, vertices, color, slot="paint"):
    return part.paint([part.bm.faces.new(vertices)], slot, color)[0]


def hull(part, points, faces, color, slot="paint", smooth=False):
    vs = [part.bm.verts.new(xyz(p)) for p in points]
    for ids in faces:
        f = face(part, [vs[i] for i in ids], color, slot)
        f.smooth = smooth
    return vs


def box(part, size, position, color):
    return part.box("paint", (size[0], size[2], size[1]), xyz(position), color=color)


def spline(points, steps, closed=False):
    """Catmull-Rom through points (tuples), steps samples per span."""
    out = []
    count = len(points)
    spans = count if closed else count - 1
    for k in range(spans):
        p0, p1 = points[(k - 1) % count if closed else max(k - 1, 0)], points[k]
        p2 = points[(k + 1) % count]
        p3 = points[(k + 2) % count if closed else min(k + 2, count - 1)]
        for j in range(steps):
            t = j / steps
            out.append(tuple(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                                    + (3 * b - a - 3 * c + d) * t ** 3)
                             for a, b, c, d in zip(p0, p1, p2, p3)))
    if not closed:
        out.append(points[-1])
    return out


def fit(part, spans):
    for axis, (low, high) in enumerate(spans):
        lo = min(v.co[axis] for v in part.bm.verts)
        hi = max(v.co[axis] for v in part.bm.verts)
        for v in part.bm.verts:
            v.co[axis] = low + (v.co[axis] - lo) / (hi - lo) * (high - low)


def cloud(root):
    part = common.Part("CloudHull")
    rings = []
    n = 16
    lobes = [(-35, 8, 3, -1), (-29, 16, 5, 1), (-22, 17, 5, 1), (-16, 15, 3.5, -1),
             (-8, 20, 6, 0), (0, 19, 5.5, .5), (9, 16, 3.5, -1), (19, 19, 5, 1),
             (28, 16, 5, 1), (35, 8, 3, -1)]
    for x, width, height, lift in spline(lobes, 3):
        ring = []
        for i in range(n):
            angle = math.tau * i / n
            puff = 1 + 0.07 * math.sin(3 * angle + x * 0.35) + 0.04 * math.cos(5 * angle - x * 0.2)
            ring.append(part.bm.verts.new((x, width * puff * math.sin(angle),
                                          lift + height * puff * math.cos(angle))))
        rings.append(ring)
    low = part.bm.verts.new((-40, 0, -1))
    high = part.bm.verts.new((40, 0, -1))
    for i in range(n):
        j = (i + 1) % n
        face(part, [low, rings[0][j], rings[0][i]], CLOUD, "glass").smooth = True
        for a in range(len(rings) - 1):
            face(part, [rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]],
                 CLOUD, "glass").smooth = True
        face(part, [high, rings[-1][i], rings[-1][j]], CLOUD, "glass").smooth = True
    fit(part, ((-40, 40), (-20, 20), (-6, 6)))
    mat = common.material("glass")
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = common.rgba(CLOUD)
    bsdf.inputs["Alpha"].default_value = 0.62
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Specular IOR Level"].default_value = 0.15
    bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    obj = part.to_object(parent=root)
    socket(root, "join_l", (-40, 0, 0))
    socket(root, "join_r", (40, 0, 0))
    return obj


def mesa(root):
    part = common.Part("MesaHull")
    outline = spline([(-30, -8), (-22, -19), (-6, -20), (18, -18), (30, -6),
                      (27, 12), (12, 20), (-8, 18), (-25, 15), (-29, 6)], 3, closed=True)
    n = len(outline)
    rings = []
    for y, scale, shift in [(0, 1, 0), (5, .97, .3), (11, .94, .1), (11.8, .955, .05),
                            (19, .91, -.3), (19.8, .925, -.35), (27, .87, -.7),
                            (28.4, .905, -.9), (29, .89, -1.0), (29, .86, -.6),
                            (29, .39, 8.0), (30.2, .37, 7.9), (48.9, .35, 7.45),
                            (50, .32, 7.4)]:
        rings.append([part.bm.verts.new(xyz((x * scale + shift, y, z * scale)))
                      for x, z in outline])
    face(part, list(reversed(rings[0])), CHALK)
    for row in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            face(part, [rings[row][i], rings[row][j], rings[row + 1][j], rings[row + 1][i]], CHALK)
    face(part, rings[-1], CHALK)
    fit(part, ((-30, 30), (-20, 20), (0, 50)))
    linear = common.to_linear(common.srgb(CHALK))
    for f in part.bm.faces:
        for loop in f.loops:
            y = loop.vert.co.z
            gain = 0.86 + 0.10 * y / 50 + 0.025 * math.sin(loop.vert.co.x * .2)
            loop[part.col] = (*[c * gain for c in linear], 1)
    bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    obj = part.to_object(parent=root)
    obj.data.materials[0] = common.material("paint").copy()
    obj.data.materials[0].name = "M1_stone"
    obj.data.materials[0].node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = .95
    socket(root, "crown", (0, 50, 0))
    return obj


def cradle(root):
    part = common.Part("CradleHull")
    outline = [(-13, -11), (13, -11), (15, -9), (15, 9),
               (13, 11), (-13, 11), (-15, 9), (-15, -9)]
    deck_faces = part.prism("paint", outline, 2, matrix=common.mtx((0, 0, -1)),
                            color=common.srgb(PETROL), side_color=common.srgb("charcoal"), side_slot="paint")
    for i in (0, 4):
        part.paint([deck_faces[2 + i]], "paint", common.srgb("bone"))
    points = [(-6, -2, -5), (6, -2, -5), (6, -2, 5), (-6, -2, 5),
              (-3, -8, -3), (3, -8, -3), (3, -8, 3), (-3, -8, 3)]
    hull(part, points, [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5),
                        (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)], "charcoal")
    for x, name in [(-9, "Rib_l"), (9, "Rib_r")]:
        common.empty(name, xyz((x, -2, 0)), root)
        for a, b in [((x, -2, -8), (x, -5, -4)), ((x, -5, -4), (x, -5, 4)),
                     ((x, -5, 4), (x, -2, 8))]:
            part.beam("paint", xyz(a), xyz(b), .75, color=common.srgb("bone"))
    socket(root, "Deck", (0, 0, 0))
    socket(root, "Keel", (0, -2, 0))
    socket(root, "hang_l", (-10, -2, 0))
    socket(root, "hang_r", (10, -2, 0))
    return part.to_object(parent=root)


def loom(root):
    part = common.Part("LoomHull")
    apex = (0, 58.5, 0)
    for foot, name in [((-23.5, 0, -8.5), "Beam_l"), ((23.5, 0, -8.5), "Beam_r"),
                       ((0, 0, 8.5), "Beam_back")]:
        a = (foot[0], 1.5, foot[2])
        part.beam("paint", xyz(a), xyz(apex), 2.0, color=common.srgb(PETROL))
        box(part, (3, 3, 3), (foot[0], 1.5, foot[2]), "charcoal")
        socket(root, name, foot)
    box(part, (5, 3, 4), (0, 58.5, 0), "bone")
    for x in (-2, 2):
        part.beam("paint", xyz((x, 58.5, 0)), xyz((x, 45, 0)), .30, color=common.srgb("charcoal"))
    box(part, (7.94, 10, 5.94), (0, 40, 0), PETROL)
    box(part, (8, .6, 6), (0, 42, 0), "bone")
    box(part, (8, .6, 6), (0, 37, 0), "charcoal")
    socket(root, "Weight", (0, 40, 0))
    socket(root, "weight_hang", (0, 45, 0))
    obj = part.to_object(parent=root)
    for axis, span in [(0, 50), (1, 20)]:
        lo = min(v.co[axis] for v in obj.data.vertices)
        hi = max(v.co[axis] for v in obj.data.vertices)
        if hi - lo > span + 1e-6:
            raise ValueError("loom cross-section exceeds envelope")
    return obj


def blades(root):
    part = common.Part("BladeHull")
    profile = [(-4, 0), (3.2, 0), (4, 18), (3.4, 58), (1.2, 80),
               (-1.8, 80), (-3.5, 63), (-4, 20)]
    for x, node in [(-8, "Blade_l"), (8, "Blade_r")]:
        points = [(x + px, y, z) for z in (-1.5, 1.5) for px, y in profile]
        faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
        faces += [(i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8) for i in range(8)]
        hull(part, points, faces, "bone", "ancient_enamel")
        socket(root, node, (x, 0, 0))
    socket(root, "blade_l", (-8, 0, 0))
    socket(root, "blade_r", (8, 0, 0))
    return part.to_object(parent=root)


def metrics(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    triangles = vertices = draws = 0
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            draws += 1
            vertices += doc["accessors"][primitive["attributes"]["POSITION"]]["count"]
            triangles += doc["accessors"][primitive["indices"]]["count"] // 3
    cap = LANDFORM_CAP if path.stem in ASSETS[:2] else HARDWARE_CAP
    assert 0 < triangles <= cap[0] and 0 < vertices <= cap[1] and 0 < draws <= cap[2], (path, triangles, vertices, draws)
    return {"triangles": triangles, "vertices": vertices, "draws": draws,
            "materials": len(doc.get("materials", [])), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def preview(path, directory):
    common.reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bounds = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector(tuple(min(p[a] for p in bounds) for a in range(3)))
    hi = Vector(tuple(max(p[a] for p in bounds) for a in range(3)))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.cycles.seed = 20261006
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 960
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("MorningSky")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = common.rgba("a9b6c0")
    bg.inputs["Strength"].default_value = .65
    bpy.ops.mesh.primitive_plane_add(size=6000, location=(0, 0, lo.z - .1))
    bpy.context.object.name = "PreviewGround"
    bpy.context.object.data.materials.append(common._flat("PreviewGround", "798c9e"))
    sun = bpy.data.lights.new("MorningSun", "SUN")
    sun.energy = 2.2
    sun.angle = math.radians(12)
    sun.color = (1, .91, .78)
    light = bpy.data.objects.new("MorningSun", sun)
    scene.collection.objects.link(light)
    light.rotation_euler = Vector((-.65, .3, -1)).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("ReferenceBall", "53686d"))
    bpy.ops.object.text_add()
    text = bpy.context.object
    text.data.body = "2 m diameter"
    text.data.size = 1.3
    text.data.align_x = "CENTER"
    text.data.materials.append(common._flat("ReferenceLabel", "242a28"))
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    center = (lo + hi) * .5
    extent = max(hi - lo)
    directory.mkdir(parents=True, exist_ok=True)
    for label, direction in [("front", (0, 1, .18)), ("side", (1, 0, .18)),
                              ("three_quarter", (1, 1, .42))]:
        direction = Vector(direction).normalized()
        right = Vector((-direction.y, direction.x, 0)).normalized()
        width = max(p.dot(right) for p in bounds) - min(p.dot(right) for p in bounds)
        ball.location = center + right * (width / 2 + 4)
        ball.location.z = lo.z + 1
        target = center + right * 3
        camera.location = target + direction * extent * 3
        common._look(camera, target)
        camera.data.ortho_scale = max(extent, width + 12) * 1.18
        text.location = ball.location + Vector((0, 0, 2.2))
        text.rotation_euler = camera.rotation_euler
        scene.render.filepath = str(directory / (path.stem + "_" + label + ".png"))
        bpy.ops.render.render(write_still=True)
        print("MHS_PREVIEW", path.stem, label, "Cycles", bpy.context.scene.cycles.device, "12 samples", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path(common.MODELS) / "highdraft")
    parser.add_argument("--render-dir", type=Path)
    parser.add_argument("--render-only", action="store_true")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    options.out_dir.mkdir(parents=True, exist_ok=True)
    report = {}
    for name, builder in zip(ASSETS, (cloud, mesa, cradle, loom, blades)):
        path = options.out_dir / (name + ".glb")
        if not options.render_only:
            common.reset()
            if name in POLISH:
                polish.enable(**POLISH[name])
            else:
                polish._opts = common.POLISH = None
                common.DETAIL = 1
            root = common.empty(name)
            builder(root)
            common.export(root, str(path))
        report[name] = metrics(path)
        print("MHS_METRIC", name, json.dumps(report[name], sort_keys=True), flush=True)
    if options.render_dir:
        options.render_dir.mkdir(parents=True, exist_ok=True)
        (options.render_dir / "metrics.json").write_text(json.dumps(report, indent=2) + "\n")
        for name in ASSETS:
            preview(options.out_dir / (name + ".glb"), options.render_dir)


if __name__ == "__main__":
    main()
