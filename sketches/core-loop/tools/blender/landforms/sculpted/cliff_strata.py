"""Seeded LKR3 sandstone: preserved LKR2 geometry, CPU UV colour bakes, previews.

Run Blender -b -t 8 -P this.py -- --render DIR [--seed 613] [--out FILE].
Sources: local LKT a/c maps; immutable dbd612b game meshes for the three existing pieces.
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time
import struct
import subprocess
import tempfile
import signal

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import common
import bpy
import numpy as np
from mathutils import Vector

NAME = "cliff_strata"
BUDGETS = {"cliff_strata": 8000, "alcove": 4000, "fin_spire": 2500, "arch": 5000}
SEEDS = {"cliff_strata": 613, "alcove": 927, "fin_spire": 811, "arch": 1203}


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
    if name == "arch":
        # One continuous eroded shell with bowed feet and an uneven broad crown.
        n, m = 81, 48
        for i in range(n):
            a = math.pi * i / (n - 1)
            ca, sa = math.cos(a), math.sin(a)
            for j in range(m):
                b = 2 * math.pi * j / m
                thickness = 1.26 + .38 * sa ** 6 + .16 * math.sin(a * 3 + .7)
                radial = thickness * math.cos(b)
                rx = 5.48 + radial + .34 * math.sin(a * 3 + .5) * sa
                rz = 7.35 + 1.18 * math.cos(b)
                x = rx * math.copysign(abs(ca) ** .79, ca)
                x += .26 * math.sin(a * 4 + .2) * sa
                exponent = .43 + .17 * (1 - math.cos(b))
                z = .20 + rz * sa ** exponent
                z += (.30 * math.sin(a * 5 + .4) + .24 * ca) * sa ** 2
                y = 2.05 * math.sin(b) * (1 + .16 * math.cos(a * 3))
                y += .23 * math.sin(a * 4 + .5) + .10 * math.sin(b * 3 + a)
                verts.append((x, y, z))
        for i in range(n - 1):
            for j in range(m):
                a, b = i * m + j, i * m + (j + 1) % m
                faces.append((a, a + m, b + m, b))
        faces += [tuple(reversed(range(m))), tuple(range((n - 1) * m, n * m))]
    elif name != "alcove":
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
    if name == "arch":
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
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
    elif obj.name.startswith("arch"):
        d *= .65
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


BASE_REV = "dbd612b5722f38e85fe057ff90398ad5288e4daa"
SOURCE_ROOT = "/home/andrew/Projects/scrapkeep/.claude/worktrees/game-completion-plan-75f776/artifacts/local/alpha/x9"
CROPS = {"cliff_strata": "striped_wall", "alcove": "alcove", "fin_spire": "spire", "arch": "arch"}
BED_EDGES = np.array([0., .24, .28, .60, .69, .96, 1.])


def read_rgb(path):
    shape = subprocess.check_output(["magick", "identify", "-format", "%w %h", path]).decode().split()
    w, h = map(int, shape)
    raw = subprocess.check_output(["magick", path, "-alpha", "off", "-depth", "8", "RGB:-"])
    return np.frombuffer(raw, np.uint8).reshape(h, w, 3).astype(np.float64) / 255


def decode_glb(payload):
    length = struct.unpack_from("<I", payload, 12)[0]
    return json.loads(payload[20:20 + length]), bytearray(payload[28 + length:])


def accessor(doc, binary, index):
    a = doc["accessors"][index]
    v = doc["bufferViews"][a["bufferView"]]
    dtype = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}[a["componentType"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    dt = np.dtype(dtype)
    return np.ndarray((a["count"], count), dtype=dt, buffer=binary,
                      offset=v.get("byteOffset", 0) + a.get("byteOffset", 0),
                      strides=(v.get("byteStride", count * dt.itemsize), dt.itemsize)).copy()


def image_bytes(doc, binary, index):
    view = doc["bufferViews"][doc["images"][index]["bufferView"]]
    offset = view.get("byteOffset", 0)
    return bytes(binary[offset:offset + view["byteLength"]])


def raster_positions(p, normals, uv, triangles):
    # Bake world position and surface direction into the accepted UV layout.
    size = 1024
    points = np.zeros((size, size, 3))
    directions = np.zeros_like(points)
    mask = np.zeros((size, size), dtype=bool)
    for tri in triangles:
        q = uv[tri] * size - .5
        lo = np.maximum(np.ceil(q.min(axis=0)).astype(int), 0)
        hi = np.minimum(np.floor(q.max(axis=0)).astype(int), size - 1)
        if np.any(hi < lo):
            continue
        x, y = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        e0, e1 = q[1] - q[0], q[2] - q[0]
        det = e0[0] * e1[1] - e0[1] * e1[0]
        if abs(det) < 1e-8:
            continue
        dx, dy = x - q[0, 0], y - q[0, 1]
        b = (dx * e1[1] - dy * e1[0]) / det
        c = (e0[0] * dy - e0[1] * dx) / det
        a = 1 - b - c
        inside = (a >= -1e-6) & (b >= -1e-6) & (c >= -1e-6)
        w = np.stack([a[inside], b[inside], c[inside]], axis=1)
        points[y[inside], x[inside]] = w @ p[tri]
        directions[y[inside], x[inside]] = w @ normals[tri]
        mask[y[inside], x[inside]] = True
    return points, directions, mask


def band_colours(p, n, seed, height, source_a, source_c):
    # Six nonrepeating beds; both cream beds occupy only 4% of the height.
    h = beds(p, seed) / height
    h += .006 * np.sin(p[:, 0] * .12 + p[:, 1] * .16 + seed)
    colours = np.array([[.64, .414, .278], [.742, .572, .401], [.657, .437, .298],
                        [.585, .370, .257], [.687, .471, .329], [.752, .584, .419]])
    idx = np.clip(np.searchsorted(BED_EDGES, h, side="right") - 1, 0, 5)
    tone = colours[idx].copy()
    for k in range(1, 6):
        t = np.clip((h - BED_EDGES[k] + .012) / .024, 0, 1)
        t = t * t * (3 - 2 * t)
        near = np.abs(h - BED_EDGES[k]) <= .012
        tone[near] = colours[k - 1] * (1 - t[near, None]) + colours[k] * t[near, None]
    fraction = np.clip((h - BED_EDGES[idx]) / (BED_EDGES[idx + 1] - BED_EDGES[idx]), 0, 1)
    def sample(img, u, v):
        return img[(np.mod(v, 1) * img.shape[0]).astype(int),
                   (np.mod(u, 1) * img.shape[1]).astype(int)]
    # Remove each source row's large colour step before sampling its grain.
    a_grain = source_a - source_a.mean(axis=1, keepdims=True)
    c_grain = source_c - source_c.mean(axis=1, keepdims=True)
    u = p[:, 0] * .085 + p[:, 1] * .051 + seed * .017
    tone += .24 * sample(a_grain, u, .12 + fraction * .16 + idx * .11)
    tone += .12 * sample(c_grain, u * 1.47, p[:, 2] * .027 + fraction * .12)
    nz = np.abs(n[:, 2] / np.maximum(np.linalg.norm(n, axis=1), 1e-8))
    steep = np.clip((.46 - nz) / .28, 0, 1)
    axis = p[:, 0] + .37 * p[:, 1]
    lo, hi = axis.min(), axis.max()
    streaks = np.zeros(len(p))
    for f in (.18, .57, .83):
        centre = lo + f * (hi - lo) + .07 * np.sin(p[:, 2] * .12 + seed)
        streaks += np.exp(-((axis - centre) / .13) ** 2)
    lifetime = np.clip((np.sin(p[:, 2] * .21 + seed) + .25) * 1.3, 0, 1)
    tone *= (1 - .15 * np.clip(streaks, 0, 1) * steep * lifetime)[:, None]
    return np.clip(tone, .01, .95)


def rebake_colour(payload, name, seed, source_root):
    doc, binary = decode_glb(payload)
    prim = doc["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]
    positions = accessor(doc, binary, attrs["POSITION"]).astype(float)
    normals = accessor(doc, binary, attrs["NORMAL"]).astype(float)
    # glTF Y-up -> the sculpt's Z-up bedding coordinate.
    p = positions[:, [0, 2, 1]] * [1, -1, 1]
    n = normals[:, [0, 2, 1]] * [1, -1, 1]
    uv = accessor(doc, binary, attrs["TEXCOORD_0"])
    triangles = accessor(doc, binary, prim["indices"]).reshape(-1, 3)
    points, directions, mask = raster_positions(p, n, uv, triangles)
    root = os.path.join(source_root, "LKT", "final")
    source_a, source_c = read_rgb(os.path.join(root, "a.png")), read_rgb(os.path.join(root, "c.png"))
    target = read_rgb(os.path.join(source_root, "crops", CROPS[name] + ".png")).mean(axis=(0, 1))
    colours = band_colours(points[mask], directions[mask], seed, p[:, 2].max(), source_a, source_c)
    with tempfile.TemporaryDirectory(prefix="lkr3-") as temp:
        factors = []
        for label in ("ao", "cavity"):
            ii = next(i for i, im in enumerate(doc["images"]) if im["name"] == label + "_1024")
            path = os.path.join(temp, label + ".png")
            open(path, "wb").write(image_bytes(doc, binary, ii))
            raw = read_rgb(path)[:, :, 0]
            factor = raw if label == "ao" else np.clip(.90 + (raw - .5) * .24, .78, 1)
            factors.append(factor[mask])
        colours *= (factors[0] * factors[1])[:, None]
        # Full supplied crop means include lighting/props: report that method explicitly.
        colours *= target / colours.mean(axis=0)
        colours = np.clip(colours, 0, 1)
        atlas = np.zeros((1024, 1024, 3))
        atlas[mask] = colours
        occupied = mask.copy()
        # UV gutters are extended 12 pixels so far-camera mipmaps cannot expose black seams.
        for _ in range(12):
            old = occupied.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                valid = np.roll(old, (dy, dx), axis=(0, 1)) & ~occupied
                if dy == 1: valid[0] = False
                if dy == -1: valid[-1] = False
                if dx == 1: valid[:, 0] = False
                if dx == -1: valid[:, -1] = False
                atlas[valid] = np.roll(atlas, (dy, dx), axis=(0, 1))[valid]
                occupied[valid] = True
        mean = np.rint(atlas[mask] * 255).mean(axis=0)
        assert np.max(np.abs(mean / (target * 255) - 1)) < .10, "Albedo mean exceeds crop tolerance"
        raw_path, png_path = os.path.join(temp, "rgb.raw"), os.path.join(temp, "albedo.png")
        np.rint(atlas * 255).astype(np.uint8).tofile(raw_path)
        subprocess.run(["magick", "-size", "1024x1024", "-depth", "8", "RGB:" + raw_path,
                        "-strip", "-define", "png:color-type=2", png_path], check=True)
        image = doc["textures"][doc["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
        replace_view = doc["images"][image]["bufferView"]
        colour_png = open(png_path, "rb").read()
    packed = bytearray()
    for i, v in enumerate(doc["bufferViews"]):
        offset = v.get("byteOffset", 0)
        chunk = colour_png if i == replace_view else binary[offset:offset + v["byteLength"]]
        packed += bytes((-len(packed)) % 4)
        v["byteOffset"], v["byteLength"] = len(packed), len(chunk)
        packed += chunk
    doc["buffers"][0]["byteLength"] = len(packed)
    doc.setdefault("extras", {})["LKR3"] = {"seed": seed, "bands": 6, "bed_edges": BED_EDGES.tolist(),
        "albedo_mean_rgb8": mean.tolist(), "crop_mean_rgb8": (target * 255).tolist(),
        "colour_bake": "CPU UV raster using sculpt beds; AO and cavity multiplied; local LKT a/c grain",
        "source_revision": BASE_REV if name != "arch" else "new continuous high-to-low sculpt"}
    j = json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()
    j += b" " * ((-len(j)) % 4)
    packed += bytes((-len(packed)) % 4)
    out = struct.pack("<III", 0x46546c67, 2, 28 + len(j) + len(packed))
    out += struct.pack("<II", len(j), 0x4e4f534a) + j
    out += struct.pack("<II", len(packed), 0x004e4942) + packed
    return out, doc["extras"]["LKR3"]


def render_game(path, name, directory, labels=("three-quarter", "near", "far")):
    common.reset()
    bpy.ops.import_scene.gltf(filepath=path)
    low = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    # Imported nodes use a parent rotation; evaluate world bounds for the camera.
    bpy.context.view_layer.update()
    pts = [low.matrix_world @ v.co for v in low.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    import importlib.util
    oldpath = os.path.join(os.path.dirname(os.path.dirname(__file__)), "cliff_strata.py")
    spec = importlib.util.spec_from_file_location("first_kit_preview", oldpath)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    cam = old.stage()
    sphere = old.sphere(hi.x + 2, lo.y - 1.2)
    center = Vector((1.2, 0, hi.z * .44))
    width = max(hi.x - lo.x + 7, hi.z * 1.777 + 6) * 1.16
    os.makedirs(directory, exist_ok=True)
    for label in labels:
        sphere.location = (hi.x + 2, lo.y - 1.2, 1)
        if label == "three-quarter":
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = width
            cam.location = center + Vector((.72, -1, .43)).normalized() * width * 2
            common._look(cam, center)
        elif label == "near":
            cam.data.type = "PERSP"
            cam.data.lens = 15.9
            target = Vector((0, lo.y, min(hi.z * .42, 4)))
            sphere.location = (-3, lo.y - 2.2, 1)
            cam.location = target + Vector((2.1, -7.72, 1))
            common._look(cam, target)
        else:
            cam.data.type = "PERSP"
            cam.data.lens = 15.9
            direction = Vector((.22, -1, .08)).normalized()
            # Eye is 60 m beyond the frontmost face, with a chase-height position.
            cam.location = Vector((direction.x * 60, lo.y + direction.y * 60, 3.3))
            common._look(cam, Vector((0, 0, hi.z * .43)))
        bpy.context.scene.render.filepath = os.path.join(directory, name + "-" + label + ".png")
        signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("15 minute render cap")))
        signal.alarm(895)
        start = time.monotonic()
        bpy.ops.render.render(write_still=True)
        signal.alarm(0)
        print("RENDER_DONE", name, label, round(time.monotonic() - start, 2), flush=True)


def run(name=NAME):
    parser = argparse.ArgumentParser()
    parser.add_argument("--out")
    parser.add_argument("--render")
    parser.add_argument("--source-root", default=SOURCE_ROOT)
    parser.add_argument("--seed", type=int, default=SEEDS[name])
    opt = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    path = opt.out or os.path.join(common.MODELS, "world_one", "landforms", "sculpted", name + ".glb")
    if name == "arch":
        common.reset()
        high = make_surface(name)
        sculpt(high, opt.seed)
        # Match the requested envelope after erosion, without squared-off jambs.
        p = np.array([v.co[:] for v in high.data.vertices])
        p[:, 0] *= 14 / np.ptp(p[:, 0])
        p[:, 2] *= 9 / p[:, 2].max()
        high.data.vertices.foreach_set("co", p.astype(np.float32).ravel())
        high.data.update()
        paint_beds(high, opt.seed)
        source, color, curvature = sandstone_material(opt.seed)
        high.data.materials.append(source)
        low, mat = low_mesh(high, BUDGETS[name])
        maps, times = bake(high, low, mat, source, color, curvature, opt.seed)
        center_game_base(high, low)
        with tempfile.TemporaryDirectory(prefix="lkr3-arch-") as temp:
            intermediate = os.path.join(temp, "arch.glb")
            common.export(low, intermediate)
            append_maps(intermediate, maps)
            payload = open(intermediate, "rb").read()
        print("ARCH_BAKES", json.dumps(times), flush=True)
    else:
        relative = "sketches/core-loop/assets/models/world_one/landforms/sculpted/" + name + ".glb"
        repo = subprocess.check_output(["git", "-C", os.path.dirname(__file__), "rev-parse", "--show-toplevel"]).decode().strip()
        payload = subprocess.check_output(["git", "-C", repo, "show", BASE_REV + ":" + relative])
    payload, report = rebake_colour(payload, name, opt.seed, opt.source_root)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    open(path, "wb").write(payload)
    print("LKR3_RESULT", json.dumps({"piece": name, "size": len(payload),
          "sha256": hashlib.sha256(payload).hexdigest(), **report}), flush=True)
    if opt.render:
        render_game(path, name, opt.render)


if __name__ == "__main__":
    run()
