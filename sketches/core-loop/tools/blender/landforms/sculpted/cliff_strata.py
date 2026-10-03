"""Seeded LKR2 sandstone sculpt, CPU selected-to-active bakes, and previews.

Run Blender -b -t 8 -P this.py -- --render DIR [--seed 613] [--out FILE].
The sibling recipes share this pipeline; no external assets are used.
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import common
import bpy
import numpy as np
from mathutils import Vector

NAME = "cliff_strata"
BUDGETS = {"cliff_strata": 8000, "alcove": 4000, "fin_spire": 2500}
SEEDS = {"cliff_strata": 613, "alcove": 927, "fin_spire": 811}


def noise(p, scale, seed):
    """Smooth seeded lattice field evaluated in bulk, without random mesh ordering."""
    q = p * scale + np.array([seed * .071, seed * .113, seed * .037])
    i = np.floor(q)
    f = q - i
    f = f * f * (3 - 2 * f)
    result = np.zeros(len(p))
    for x in (0, 1):
        for y in (0, 1):
            for z in (0, 1):
                v = i + (x, y, z)
                h = np.sin(v @ np.array([127.1, 311.7, 74.7]) + seed) * 43758.5453
                h = (h - np.floor(h)) * 2 - 1
                w = np.prod(np.where(np.array([x, y, z]), f, 1 - f), axis=1)
                result += h * w
    return result


def beds(p, seed):
    x, y, z = p.T
    return z + .22 * np.sin(x * .21 + seed) + .11 * np.sin(y * .37) + .045 * x


def relief(p, seed):
    """Unequal rounded bed lips, soft-bed joint erosion, ridges and fine pitting."""
    h = beds(p, seed)
    edges = np.array([0, 1.3, 3.6, 6.1, 7.0, 10.5, 13.8, 15.0, 18.4, 21.3, 24, 27])
    k = np.clip(np.searchsorted(edges, h) - 1, 0, len(edges) - 2)
    f = (h - edges[k]) / (edges[k + 1] - edges[k])
    # Rounded inward recess at each bedding boundary, never a boxed terrace.
    seam = np.exp(-((f - .07) / .105) ** 2)
    soft = .42 + .58 * ((k * 7) % 5) / 4
    coarse = noise(p, .42, seed)
    ridge = 1 - np.abs(noise(p, 1.25, seed + 11))
    fine = noise(p, 5.8, seed + 31)
    # Voronoi distance difference creates non-grid, oblique cell-fracture joints.
    q = p * np.array([.24, .28, .105])
    cell = np.floor(q)
    d1 = np.full(len(p), 100.)
    d2 = d1.copy()
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = cell + (dx, dy, dz)
                jitter = np.stack([np.sin(c @ v + seed) * 43758.5453 for v in
                                   ([127.1, 311.7, 74.7], [269.5, 183.3, 246.1], [113.5, 271.9, 124.6])], axis=1)
                jitter -= np.floor(jitter)
                d = np.sum((q - c - .2 - .6 * jitter) ** 2, axis=1)
                d2 = np.minimum(d2, np.maximum(d1, d))
                d1 = np.minimum(d1, d)
    joint = np.exp(-((np.sqrt(d2) - np.sqrt(d1)) / .036) ** 2)
    return -.20 * seam + .21 * coarse + .085 * ridge + .024 * fine - .19 * joint * soft


def make_surface(name):
    """Continuous quad silhouettes matching the first kit's overall proportions."""
    verts, faces = [], []
    if name != "alcove":
        n, rows = 32, 65
        for k in range(rows):
            t = k / (rows - 1)
            z = t * (26 if name == "cliff_strata" else 22)
            for j in range(n):
                a = j * 2 * math.pi / n
                if name == "cliff_strata":
                    # Broad continuous flank: a rounded superellipse, no brick stack.
                    c, s = math.cos(a), math.sin(a)
                    x = math.copysign(abs(c) ** .55, c) * 12
                    y = math.copysign(abs(s) ** .55, s) * 4.7
                    taper = 1 - .24 * t + .045 * math.sin(t * 11)
                    shoulder = .26 * math.sin(x * .29 + 1) + .17 * math.sin(x * .71)
                    x = x * (1 - .11 * t) + .65 * math.sin(t * 6.4)
                    flank = .74 * math.sin(x * .38 + .4) + .38 * math.sin(x * .73 + t * 2)
                    y = y * taper + (shoulder + flank) * abs(s)
                    zz = z + t ** 5 * (1.35 * math.sin(x * .35) + .39 * math.cos(a * 3))
                else:
                    # Unequal cap over a neck with a continuous, weathered shoulder.
                    profile = [(0, 3.8), (2, 3.3), (6, 2.8), (11, 2.1),
                               (16, 1.5), (18.5, 1.75), (19.5, 3.65), (20.5, 4), (22, 3.25)]
                    r = float(np.interp(z, [h for h, _ in profile], [r for _, r in profile]))
                    r *= 1 + .055 * math.sin(a * 3 + z * .16) + .035 * math.sin(a * 7 + 2)
                    x = r * math.cos(a) + .24 * math.sin(z * .25)
                    y = r * .63 * math.sin(a)
                    zz = z + t ** 12 * (.35 * math.sin(a * 3 + .7) + .26 * math.cos(a))
                verts.append((x, y, zz))
        for k in range(rows - 1):
            for j in range(n):
                a, b = k * n + j, k * n + (j + 1) % n
                faces.append((a, b, b + n, a + n))
        faces += [tuple(reversed(range(n))), tuple(range((rows - 1) * n, rows * n))]
    else:
        # An arch swept around a thick, round shell section. The inner arch shrinks
        # into the rear recess; the mouth has bowed sides rather than straight jambs.
        n, m = 65, 64
        for i in range(n):
            a = math.pi * i / (n - 1)
            for j in range(m):
                b = 2 * math.pi * j / m
                profiles = [(7.8, 7.4, -3.3, .32), (6.8, 6.4, -.6, .6),
                            (.045, .045, 2.8, 3.8), (8.5, 10.1, 3.65, .32),
                            (10.1, 11.8, 1.4, .32), (10.2, 11.9, -2.7, .32),
                            (9.4, 10.5, -3.8, .32), (8.5, 8.9, -3.7, .32)]
                q = j / m * len(profiles)
                idx = int(q)
                f = q - idx
                f = f * f * (3 - 2 * f)
                rx, rz, depth, baseline = [(1 - f) * u + f * v for u, v in
                    zip(profiles[idx], profiles[(idx + 1) % len(profiles)])]
                x = rx * math.copysign(abs(math.cos(a)) ** .84, math.cos(a))
                z = baseline + rz * math.sin(a) ** .72
                x += .32 * math.sin(a * 3 + .4) * math.sin(a)
                z += .28 * math.sin(a * 5 + .7) * math.sin(a) ** 2
                y = depth + .18 * math.sin(a * 4 + b)
                verts.append((x, y, z))
        for i in range(n - 1):
            for j in range(m):
                a, b = i * m + j, i * m + (j + 1) % m
                faces.append((a, a + m, b + m, b))
        faces += [tuple(reversed(range(m))), tuple(range((n - 1) * m, n * m))]
    mesh = bpy.data.meshes.new(name + "_continuous_silhouette")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name + "_high", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    sub = obj.modifiers.new("Sculpt subdivision", "SUBSURF")
    sub.levels = 4
    bpy.ops.object.modifier_apply(modifier=sub.name)
    return obj


def sculpt(obj, seed):
    p = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", p)
    p = p.reshape(-1, 3)
    normals = np.empty(p.size, dtype=np.float32)
    obj.data.vertices.foreach_get("normal", normals)
    normals = normals.reshape(-1, 3)
    d = relief(p, seed)
    if obj.name.startswith("cliff"):
        d *= 2.4
    p += normals * d[:, None]
    lo, hi = p.min(axis=0), p.max(axis=0)
    p[:, :2] -= (lo[:2] + hi[:2]) / 2
    p[:, 2] -= lo[2]
    obj.data.vertices.foreach_set("co", p.ravel())
    for f in obj.data.polygons:
        f.use_smooth = True
    obj.data.update()


def paint_beds(obj, seed):
    p = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", p)
    p = p.reshape(-1, 3)
    h = beds(p, seed)
    boundaries = np.array([0, 1.3, 3.6, 6.1, 7, 10.5, 13.8, 15, 18.4, 21.3, 24, 28])
    idx = np.clip(np.searchsorted(boundaries, h) - 1, 0, len(boundaries) - 2)
    tones = np.array([common.mix("sandstone", "bone", .18), common.srgb("sandstone"),
                      common.mix("sandstone", "oxide", .17), common.mix("sandstone", "bone", .28),
                      common.mix("sandstone", "oxide", .10)])
    tone = tones[(idx * 3 + 1) % len(tones)]
    cross = h * 8.8 + .38 * p[:, 0] + .25 * np.sin(p[:, 0] * .8 + p[:, 1] * .3)
    lamina = .09 * (np.sin(cross) * .5 + .5) ** 4
    tone += (np.array(common.srgb("bone")) - tone) * lamina[:, None]
    n = np.empty(p.size, dtype=np.float32)
    obj.data.vertices.foreach_get("normal", n)
    vertical = 1 - np.abs(n.reshape(-1, 3)[:, 2])
    streakp = p * np.array([1, 1, .035])
    stain = np.clip((noise(streakp, 1.7, seed + 47) - .1) * .33, 0, .24) * vertical
    varnish = np.array(common.mix("sandstone", "charcoal", .7))
    tone += (varnish - tone) * stain[:, None]
    grain = noise(p, 5.8, seed + 87) * .018
    tone = np.clip(tone + grain[:, None], 0, 1)
    lin = np.where(tone <= .04045, tone / 12.92, ((tone + .055) / 1.055) ** 2.4)
    rgba = np.ones((len(p), 4), dtype=np.float32)
    rgba[:, :3] = lin
    attr = obj.data.color_attributes.new(name="SandstonePaint", type="FLOAT_COLOR", domain="POINT")
    attr.data.foreach_set("color", rgba.ravel())


def sandstone_material(seed):
    mat = bpy.data.materials.new("Sandstone sculpt source")
    mat.use_nodes = True
    n, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = n.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .93
    tex = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    links.new(tex.outputs["Generated"], sep.inputs[0])
    wave = n.new("ShaderNodeTexWave")
    wave.wave_type, wave.bands_direction = "BANDS", "Z"
    wave.inputs["Scale"].default_value = 6.3
    wave.inputs["Distortion"].default_value = 1.5
    wave.inputs["Detail Scale"].default_value = 1.4
    links.new(tex.outputs["Generated"], wave.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for i, (pos, color) in enumerate([(0, common.mix("sandstone", "oxide", .3)),
                                     (.3, common.srgb("sandstone")),
                                     (.69, common.mix("sandstone", "bone", .38)),
                                     (1, common.srgb("sandstone"))]):
        e = ramp.color_ramp.elements[0] if i == 0 else ramp.color_ramp.elements.new(pos)
        e.position, e.color = pos, common.rgba(color)
    links.new(wave.outputs["Fac"], ramp.inputs[0])
    streak = n.new("ShaderNodeTexNoise")
    mapping = n.new("ShaderNodeVectorMath")
    mapping.operation = "MULTIPLY"
    mapping.inputs[1].default_value = (16, 16, .5)
    links.new(tex.outputs["Generated"], mapping.inputs[0])
    links.new(mapping.outputs[0], streak.inputs[0])
    streak.inputs["Scale"].default_value = 2.6
    stain = n.new("ShaderNodeMapRange")
    stain.inputs["From Min"].default_value = .48
    stain.inputs["From Max"].default_value = .78
    stain.inputs["To Min"].default_value = 0
    stain.inputs["To Max"].default_value = .34
    links.new(streak.outputs["Fac"], stain.inputs["Value"])
    geom = n.new("ShaderNodeNewGeometry")
    vertical = n.new("ShaderNodeSeparateXYZ")
    links.new(geom.outputs["Normal"], vertical.inputs[0])
    absz = n.new("ShaderNodeMath")
    absz.operation = "ABSOLUTE"
    links.new(vertical.outputs["Z"], absz.inputs[0])
    inv = n.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1
    links.new(absz.outputs[0], inv.inputs[1])
    fac = n.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    links.new(stain.outputs[0], fac.inputs[0])
    links.new(inv.outputs[0], fac.inputs[1])
    mix = n.new("ShaderNodeMixRGB")
    links.new(fac.outputs[0], mix.inputs[0])
    links.new(ramp.outputs[0], mix.inputs[1])
    mix.inputs[2].default_value = common.rgba(common.mix("sandstone", "charcoal", .72))
    paint = n.new("ShaderNodeAttribute")
    paint.attribute_name = "SandstonePaint"
    links.new(paint.outputs["Color"], bsdf.inputs["Base Color"])
    return mat, paint.outputs["Color"], geom.outputs["Pointiness"]


def active(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def low_mesh(high, budget):
    low = high.copy()
    low.data = high.data.copy()
    low.name = high.name.replace("_high", "_game")
    bpy.context.collection.objects.link(low)
    active(low)
    dec = low.modifiers.new("Game budget", "DECIMATE")
    dec.ratio = (budget - 12) / common.tris(low)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    tri = low.modifiers.new("Triangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    assert common.tris(low) <= budget
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(68), island_margin=.022)
    bpy.ops.object.mode_set(mode="OBJECT")
    low.data.materials.clear()
    for attr in list(low.data.color_attributes):
        low.data.color_attributes.remove(attr)
    mat = bpy.data.materials.new("Baked Glen Canyon sandstone")
    mat.use_nodes = True
    low.data.materials.append(mat)
    return low, mat


def bake(high, low, mat, source_mat, color, curvature, seed):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.seed = seed
    scene.cycles.use_adaptive_sampling = False
    scene.render.threads_mode, scene.render.threads = "FIXED", 8
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = .34
    scene.render.bake.max_ray_distance = .7
    scene.render.bake.margin = 12
    scene.render.bake.normal_space = "TANGENT"
    target = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = target
    out = source_mat.node_tree.nodes.get("Material Output")
    emit = source_mat.node_tree.nodes.new("ShaderNodeEmission")
    maps, times = {}, {}
    for label, kind, signal in [("normal", "NORMAL", None), ("ao", "AO", None),
                                ("cavity", "EMIT", curvature), ("albedo", "EMIT", color)]:
        img = bpy.data.images.new(low.name + "_" + label, width=1024, height=1024, alpha=False)
        img.colorspace_settings.name = "sRGB" if label == "albedo" else "Non-Color"
        target.image = img
        if signal is not None:
            source_mat.node_tree.links.new(signal, emit.inputs["Color"])
            source_mat.node_tree.links.new(emit.outputs[0], out.inputs["Surface"])
        else:
            source_mat.node_tree.links.new(source_mat.node_tree.nodes.get("Principled BSDF").outputs[0], out.inputs["Surface"])
        active(low)
        high.select_set(True)
        start = time.monotonic()
        print("BAKE_START", low.name, label, flush=True)
        bpy.ops.object.bake(type=kind)
        elapsed = time.monotonic() - start
        assert elapsed < 900, "Bake exceeded 15-minute cap"
        maps[label], times[label] = img, round(elapsed, 2)
        print("BAKE_DONE", label, elapsed, flush=True)
    source_mat.node_tree.links.new(source_mat.node_tree.nodes.get("Principled BSDF").outputs[0], out.inputs["Surface"])
    # ORM carries AO in red and cavity-derived roughness in green. Preserve the
    # unmodified cavity map as an embedded glTF image as well.
    ao = np.array(maps["ao"].pixels[:], dtype=np.float32).reshape(-1, 4)
    cv = np.array(maps["cavity"].pixels[:], dtype=np.float32).reshape(-1, 4)
    orm = np.ones_like(ao)
    orm[:, 0] = ao[:, 0]
    orm[:, 1] = np.clip(.92 - (cv[:, 0] - .5) * .42, .74, 1)
    orm[:, 2] = 0
    maps["orm"] = bpy.data.images.new(low.name + "_orm", width=1024, height=1024, alpha=False)
    maps["orm"].colorspace_settings.name = "Non-Color"
    maps["orm"].pixels.foreach_set(orm.ravel())
    n, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = n.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .92
    for label in ("albedo", "normal", "orm"):
        node = n.new("ShaderNodeTexImage")
        node.image = maps[label]
        if label == "albedo":
            links.new(node.outputs[0], bsdf.inputs["Base Color"])
        elif label == "normal":
            norm = n.new("ShaderNodeNormalMap")
            links.new(node.outputs[0], norm.inputs["Color"])
            links.new(norm.outputs[0], bsdf.inputs["Normal"])
        else:
            sep = n.new("ShaderNodeSeparateColor")
            links.new(node.outputs[0], sep.inputs[0])
            links.new(sep.outputs[1], bsdf.inputs["Roughness"])
            group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
            group.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
            g = n.new("ShaderNodeGroup")
            g.node_tree = group
            links.new(sep.outputs[0], g.inputs["Occlusion"])
    target.image = None
    return maps, times


def append_maps(path, maps):
    """Retain separate AO/cavity PNGs in the GLB buffer, with explicit map metadata."""
    import struct
    data = open(path, "rb").read()
    jl = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + jl])
    binary = bytearray(data[28 + jl:])
    for label in ("ao", "cavity"):
        img = maps[label]
        scratch = os.path.join("/tmp", img.name + ".png")
        img.filepath_raw, img.file_format = scratch, "PNG"
        img.save()
        payload = open(scratch, "rb").read()
        binary += bytes((-len(binary)) % 4)
        view = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)})
        binary += payload
        doc.setdefault("images", []).append({"name": label + "_1024", "bufferView": view, "mimeType": "image/png"})
    doc.setdefault("extras", {})["LKR2"] = {"units": "metres", "origin": "base-centred",
        "maps": "tangent normal, albedo, ORM(AO/cavity roughness), separate AO and cavity"}
    doc["buffers"][0]["byteLength"] = len(binary)
    j = json.dumps(doc, separators=(",", ":"), sort_keys=True).encode()
    j += b" " * ((-len(j)) % 4)
    binary += bytes((-len(binary)) % 4)
    total = 12 + 8 + len(j) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546c67, 2, total))
        f.write(struct.pack("<II", len(j), 0x4e4f534a)); f.write(j)
        f.write(struct.pack("<II", len(binary), 0x004e4942)); f.write(binary)


def center_game_base(high, low):
    lo = Vector([min(v.co[i] for v in low.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in low.data.vertices) for i in range(3)])
    offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for obj in (high, low):
        p = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
        obj.data.vertices.foreach_get("co", p)
        p = p.reshape(-1, 3) - np.array(offset, dtype=np.float32)
        obj.data.vertices.foreach_set("co", p.ravel())
        obj.data.update()


def render_views(high, low, name, directory):
    # Reuse the first kit's exact warm 40-degree sun, sky fill, and scale sphere.
    import importlib.util
    oldpath = os.path.join(os.path.dirname(os.path.dirname(__file__)), "cliff_strata.py")
    spec = importlib.util.spec_from_file_location("first_kit_preview", oldpath)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    cam = old.stage()
    lo = Vector([min(v.co[i] for v in low.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in low.data.vertices) for i in range(3)])
    old.sphere(hi.x + 2, lo.y - 1.2)
    center = Vector((1.2, 0, hi.z * .44))
    width = max(hi.x - lo.x + 7, hi.z * 1.777 + 6) * 1.16
    os.makedirs(directory, exist_ok=True)
    for label in ("three-quarter", "near", "highpoly"):
        high.hide_render, low.hide_render = label != "highpoly", label == "highpoly"
        if label == "near":
            cam.data.type = "PERSP"
            cam.data.lens = 15.9  # 65-degree vertical FOV at 16:9, 36 mm sensor.
            target = Vector((0, lo.y, min(hi.z * .42, 7.5)))
            cam.location = target + Vector((2.1, -7.72, 1))
            common._look(cam, target)
        else:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = width
            cam.location = center + Vector((.72, -1, .43)).normalized() * width * 2
            common._look(cam, center)
        bpy.context.scene.render.filepath = os.path.join(directory, name + "-" + label + ".png")
        bpy.ops.render.render(write_still=True)


def run(name=NAME):
    parser = argparse.ArgumentParser()
    parser.add_argument("--out")
    parser.add_argument("--render")
    parser.add_argument("--seed", type=int, default=SEEDS[name])
    opt = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    common.reset()
    high = make_surface(name)
    sculpt(high, opt.seed)
    paint_beds(high, opt.seed)
    source, color, curvature = sandstone_material(opt.seed)
    high.data.materials.append(source)
    print("HIGH_POLY", name, common.tris(high), flush=True)
    low, mat = low_mesh(high, BUDGETS[name])
    maps, times = bake(high, low, mat, source, color, curvature, opt.seed)
    center_game_base(high, low)
    high.hide_render = True
    path = opt.out or os.path.join(common.MODELS, "world_one", "landforms", "sculpted", name + ".glb")
    common.export(low, path)
    append_maps(path, maps)
    print("LKR2_RESULT", json.dumps({"piece": name, "seed": opt.seed, "high_triangles": common.tris(high),
          "triangles": common.tris(low), "bake_seconds": times, "size": os.path.getsize(path),
          "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()}), flush=True)
    if opt.render:
        render_views(high, low, name, opt.render)


if __name__ == "__main__":
    run()
