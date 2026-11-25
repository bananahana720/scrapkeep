"""Highdraft traversal hardware, metres, Blender Z up / exported Godot Y up.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/highdraft/lift.py -- --out-dir /tmp/mhl
Add --preview-dir artifacts/local/dress-preview/MHL for CPU Cycles GLB reimports.

Static parts merge into one paint surface. Named empty part markers retain their
dimensions and purpose. The eye and collar have baked slate/mint vertex poses.
The later loader must choose them from the actual harpoon verdict. Air occupied
opacity remains integration data and never switches the offered lift off.
The accepted base contains no Dig atlas; the existing common.paint and glass
sources are reused without adding any textures or material families.
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
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
import polish

COLORS = dict(bone="d2c5a5", petrol="53686d", charcoal="242a28",
              oxide="9b513a", mint="8bf0d3", amber="e5a044", slate="596a7c")
POLISH = {
    "thermal_vent": dict(bevel=.05, bevel_min=.15, bevel_angle=35),
    "net_tile": dict(bevel=0),
    "net_edge": dict(bevel=.03, bevel_min=.1),
    "net_shoe": dict(bevel=.03, bevel_min=.1),
    "anchor_mast": dict(bevel=.04, bevel_min=.15),
    "anchor_eye": dict(bevel=.03, bevel_min=.1, ao=False, edge=0),
    "anchor_collar": dict(bevel=.03, ao=False, edge=0),
    "travel_vane": dict(bevel=.03, bevel_min=.1),
}
PROP_CAP = (1500, 3400, 1)
FILES = ("thermal_vent", "thermal_air", "net_tile", "net_edge", "net_shoe",
         "anchor_mast", "anchor_eye", "anchor_collar", "travel_vane")


def xyz(v):
    return (v[0], -v[2], v[1])


def mark(root, name, loc=(0, 0, 0), size=None, **extras):
    obj = common.empty(name, xyz(loc), root)
    if size:
        obj["size_godot"] = list(size)
    for key, value in extras.items():
        obj[key] = value
    return obj


def part_marker(root, name, size, loc=(0, 0, 0)):
    return mark(root, name, loc, size, merged_geometry="Hardware")


def tint(part, faces, color, wear=False):
    part.paint(faces, "paint", COLORS.get(color, color))
    if wear:
        for i, face in enumerate(faces):
            if i % 7 == 2:
                part.paint([face], "paint", common.mix(COLORS[color], COLORS["bone"], .25))


def box(part, size, loc, color, wear=False):
    faces = part.box("paint", (size[0], size[2], size[1]), xyz(loc))
    tint(part, faces, color, wear)
    return faces


def ring(part, inner, outer, depth, loc, color, vertical=False, segs=12, wear=False):
    faces = part.ring("paint", inner, outer, depth, segs, xyz(loc),
                      rot=(math.pi / 2, 0, 0) if vertical else (0, 0, 0))
    tint(part, faces, color, wear)
    return faces


def beam(part, a, b, width, color):
    faces = part.beam("paint", xyz(a), xyz(b), width)
    tint(part, faces, color, True)


def finish(part, root, recalc=True):
    if recalc:
        bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    obj = part.to_object(parent=root)
    uv = obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.loops:
        pos = obj.data.vertices[loop.vertex_index].co
        vertical_uv = obj.name == "AirColumn" or root.name == "anchor_eye"
        uv.data[loop.index].uv = (pos.x * .25, (pos.z if vertical_uv else pos.y) * .25)
    return obj


def thermal_vent(root):
    p = common.Part("Hardware")
    inner = 2.5 / math.cos(math.pi / 12)
    profiles = [([(inner, 1.2), (3, 1.2), (3, 1.72), (2.92, 1.8),
                  (inner + .08, 1.8), (inner, 1.72)], range(6), "amber"),
                ([(inner, 0), (3, 0), (3, 1.2), (inner, 1.2)], (1, 3), "petrol")]
    for profile, sides, color in profiles:
        rows = [[p.bm.verts.new((radius * math.cos(i * math.tau / 12),
                                 radius * math.sin(i * math.tau / 12), height))
                 for radius, height in profile] for i in range(12)]
        faces = []
        for i in range(12):
            for k in sides:
                j, nxt = (i + 1) % 12, (k + 1) % len(profile)
                faces.append(p.bm.faces.new((rows[i][k], rows[j][k], rows[j][nxt], rows[i][nxt])))
        tint(p, faces, color, color == "petrol")
    for axis in range(2):
        for offset in (-1.25, 0, 1.25):
            half = math.sqrt(2.5 ** 2 - (abs(offset) + .07) ** 2)
            size = (2 * half, .15, .14) if axis == 0 else (.14, .15, 2 * half)
            loc = (0, 1.1, offset) if axis == 0 else (offset, 1.1, 0)
            box(p, size, loc, "charcoal")
    obj = finish(p, root, recalc=False)
    part_marker(root, "MouthRim", (6, .6, 6), (0, 1.5, 0))
    part_marker(root, "DuctFoot", (6, 1.2, 6), (0, .6, 0))
    part_marker(root, "Grate", (5, .15, 5), (0, 1.1, 0))
    mark(root, "air_base")
    mark(root, "entry", (0, 0, -3))
    mark(root, "return_join", (0, 0, -4))
    return obj


def thermal_air(root):
    p = common.Part("AirColumn")
    rings = []
    sides = 24
    profile = ((0, 2.5, .22), (14, 3.7, .7), (26, 4.8, .2), (37, 5.8, .55), (39, 6.5, .32), (40, 6.5, 0))
    for (h0, r0, a0), (h1, r1, a1) in zip(profile, profile[1:]):
        steps = math.ceil((h1 - h0) / 3.5)
        for k in range(steps + (h1 == 40)):
            t = k / steps
            height, radius, alpha = h0 + (h1 - h0) * t, r0 + (r1 - r0) * t, a0 + (a1 - a0) * t
            rings.append(([p.bm.verts.new((radius * math.cos(i * math.tau / sides),
                                          radius * math.sin(i * math.tau / sides), height))
                           for i in range(sides)], alpha))
    for k in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            a, aa = rings[k]
            b, ba = rings[k + 1]
            face = p.bm.faces.new((a[i], a[j], b[j], b[i]))
            p.paint([face], "glass")
            for loop in face.loops:
                loop[p.col] = (*common.to_linear(common.srgb("ece7da")),
                               aa if loop.vert in (a[i], a[j]) else ba)
            face.smooth = True
    obj = finish(p, root)
    mat = common.material("glass")
    mat.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value = .18
    mat.use_backface_culling = False
    mark(root, "Crown", (0, 38.5, 0), (13, 3, 13), integrated_geometry="AirColumn")
    mark(root, "exit", (0, 40, 0))
    root["crown_y_scale"] = 46 / 40
    root["idle_opacity"] = .08
    root["occupied_opacity"] = .18
    return obj


def net_tile(root):
    p = common.Part("Weave")
    for axis in range(2):
        for offset in (-2, -1, 0, 1, 2):
            lo, hi = max(-2, offset - .05), min(2, offset + .05)
            rows = []
            for t in (-2, 0, 2):
                sag = -.03 * (1 - abs(offset) / 2) if t == 0 else 0
                coords = []
                for c, dz in ((lo, -.015), (hi, -.015), (hi, .015), (lo, .015)):
                    coords.append((t, c, sag + dz) if axis == 0 else (c, t, sag + dz))
                rows.append([p.bm.verts.new(v) for v in coords])
            faces = []
            for k in range(2):
                for i in range(4):
                    j = (i + 1) % 4
                    faces.append(p.bm.faces.new((rows[k][i], rows[k + 1][i],
                                                rows[k + 1][j], rows[k][j])))
            faces += [p.bm.faces.new(list(reversed(rows[0]))), p.bm.faces.new(rows[-1])]
            tint(p, faces, "bone")
    obj = finish(p, root)
    for name, loc in (("join_n", (0, 0, -2)), ("join_e", (2, 0, 0)),
                      ("join_s", (0, 0, 2)), ("join_w", (-2, 0, 0))):
        mark(root, name, loc)
    root["max_catch_deflection"] = .12
    return obj


def net_edge(root):
    p = common.Part("Hardware")
    outline = [(-.2, 0), (.2, 0), (.25, .05), (.25, .30),
               (.2, .35), (-.2, .35), (-.25, .30), (-.25, .05)]
    m = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, -.35), (0, 0, 0, 1)))
    tint(p, p.prism("paint", outline, 4, matrix=m), "amber")
    box(p, (4, .15, .25), (0, -.425, 0), "charcoal")
    obj = finish(p, root)
    part_marker(root, "Pad", (4, .35, .5), (0, -.175, 0))
    part_marker(root, "Support", (4, .15, .25), (0, -.425, 0))
    mark(root, "join_l", (-2, 0, 0))
    mark(root, "join_r", (2, 0, 0))
    mark(root, "shoe", (0, -.2, 0))
    return obj


def net_shoe(root):
    p = common.Part("Hardware")
    box(p, (1, .4, 1), (0, 0, 0), "petrol", True)
    box(p, (.5, 2, .5), (0, 1.2, 0), "charcoal")
    ring(p, .25, .3, .2, (0, 2, 0), "bone", segs=8)
    obj = finish(p, root)
    part_marker(root, "Foot", (1, .4, 1))
    part_marker(root, "Post", (.5, 2, .5), (0, 1.2, 0))
    part_marker(root, "CableCollar", (.6, .2, .6), (0, 2, 0))
    mark(root, "cable", (0, 2, 0))
    mark(root, "edge_join", (0, 1, 0))
    return obj


def anchor_mast(root):
    p = common.Part("Hardware")
    box(p, (3, .4, 3), (0, .2, 0), "petrol", True)
    box(p, (.9, 14.7, .9), (0, 7.75, 0), "charcoal", True)
    for sign, label in ((-1, "l"), (1, "r")):
        box(p, (.6, 3.6, .8), (sign * 1.8, 16.6, 0), "charcoal", True)
        beam(p, (0, 13.5, 0), (sign * 1.8, 15, 0), .45, "petrol")
        beam(p, (sign * 1.3, .4, 0), (sign * .45, 3, 0), .18, "petrol")
        part_marker(root, "ForkProng_" + label, (.6, 3.6, .8), (sign * 1.8, 16.6, 0))
        mark(root, "stay_" + label, (sign * 1.5, .4, 0))
    obj = finish(p, root)
    part_marker(root, "Foot", (3, .4, 3), (0, .2, 0))
    part_marker(root, "Shaft", (.9, 14.7, .9), (0, 7.75, 0))
    mark(root, "ForkProng", (0, 16.6, 0), instances=2)
    mark(root, "eye_centre", (0, 16.6, 0))
    return obj


def anchor_eye(root):
    p = common.Part("Hardware")
    outer = ring(p, 1, 1.5, .45, (0, 0, 0), "bone", vertical=True, wear=True)
    for face in outer[3::4]:
        p.bm.faces.remove(face)
    ring(p, .9 / math.cos(math.pi / 12), 1, .45, (0, 0, 0), "slate", vertical=True)
    ring(p, .9 / math.cos(math.pi / 12), 1, .45, (0, 0, 0), "mint", vertical=True)
    obj = finish(p, root, recalc=False)
    part_marker(root, "OuterRim", (3, 3, .45))
    part_marker(root, "Sleeve", (2, 2, .45))
    mark(root, "rope_bite", (0, 0, -.225))
    for x, a in ((-1.2, "l"), (1.2, "r")):
        for y, b in ((-1.2, "b"), (1.2, "t")):
            mark(root, "collar_" + a + b, (x, y, 0), inward_godot=[-x / abs(x) / math.sqrt(2),
                                                                  -y / abs(y) / math.sqrt(2), 0])
    root["idle_sleeve_tint"] = COLORS["slate"]
    root["ready_sleeve_tint"] = COLORS["mint"]
    root["attached_sleeve_tint"] = COLORS["mint"]
    return obj


def anchor_collar(root):
    p = common.Part("Block")
    box(p, (.45, .45, .35), (0, 0, 0), "slate")
    box(p, (.45, .45, .35), (0, 0, 0), "mint")
    obj = finish(p, root)
    mark(root, "slide_axis", inward_godot=[-1 / math.sqrt(2), -1 / math.sqrt(2), 0])
    root["open_offset_godot"] = [.25 / math.sqrt(2), .25 / math.sqrt(2), 0]
    root["close_tint"] = COLORS["mint"]
    root["open_tint"] = COLORS["slate"]
    return obj


def travel_vane(root):
    p = common.Part("Hardware")
    box(p, (.2, 1.2, .2), (0, .6, 0), "charcoal")
    blade = common.Part("Hardware.blade")
    blade.bevel = 0
    outline = [(-.7, 0), (.95, .10), (1.3, .34), (1.12, .65),
               (.55, .70), (-.7, .42)]
    m = common.mtx((0, 0, 1.2), (math.pi / 2, 0, 0))
    tint(blade, blade.prism("paint", outline, .15, matrix=m), "bone", True)
    stem = finish(p, root)
    stem_group = stem.vertex_groups.new(name="VaneRoot")
    stem_group.add(list(range(len(stem.data.vertices))), 1, "REPLACE")
    fin = finish(blade, root)
    fin.vertex_groups.new(name="VaneHinge").add(list(range(len(fin.data.vertices))), 1, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    stem.select_set(True)
    fin.select_set(True)
    bpy.context.view_layer.objects.active = stem
    bpy.ops.object.join()
    obj = stem
    part_marker(root, "Blade", (2, .7, .15), (.3, 1.55, 0))
    part_marker(root, "Stem", (.2, 1.2, .2), (0, .6, 0))
    mark(root, "mast_foot")
    mark(root, "hinge", (0, 1.2, 0))
    arm = bpy.data.armatures.new("VaneRig")
    rig = bpy.data.objects.new("VaneRig", arm)
    bpy.context.scene.collection.objects.link(rig)
    rig.parent = root
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    fixed = arm.edit_bones.new("VaneRoot")
    fixed.head, fixed.tail = (0, 0, 0), (0, 0, .2)
    hinge = arm.edit_bones.new("VaneHinge")
    hinge.head, hinge.tail = (0, 0, 1.2), (0, 0, 1.4)
    hinge.parent = fixed
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = obj.modifiers.new("VaneRig", "ARMATURE")
    mod.object = rig
    return obj


def read_glb(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length]), bytearray(data[28 + length:])


def write_glb(path, doc, binary):
    binary.extend(b"\0" * (-len(binary) % 4))
    doc["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(doc, separators=(",", ":"), ensure_ascii=True).encode()
    encoded += b" " * (-len(encoded) % 4)
    size = 12 + 8 + len(encoded) + 8 + len(binary)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, size) +
                     struct.pack("<I4s", len(encoded), b"JSON") + encoded +
                     struct.pack("<I4s", len(binary), b"BIN\0") + binary)


def floats(doc, binary, values, kind):
    binary.extend(b"\0" * (-len(binary) % 4))
    start = len(binary)
    rows = [(v,) if isinstance(v, (float, int)) else v for v in values]
    flat = [float(v) for row in rows for v in row]
    binary.extend(struct.pack("<%df" % len(flat), *flat))
    view = len(doc.setdefault("bufferViews", []))
    doc["bufferViews"].append(dict(buffer=0, byteOffset=start, byteLength=len(flat) * 4))
    acc = dict(bufferView=view, componentType=5126, count=len(rows), type=kind)
    if kind in ("SCALAR", "VEC3"):
        acc["min"] = [min(row[i] for row in rows) for i in range(len(rows[0]))]
        acc["max"] = [max(row[i] for row in rows) for i in range(len(rows[0]))]
    aid = len(doc.setdefault("accessors", []))
    doc["accessors"].append(acc)
    return aid


def positions(doc, binary, aid):
    acc = doc["accessors"][aid]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    return [struct.unpack_from("<3f", binary, start + i * stride) for i in range(acc["count"])]


def colors(doc, binary, aid):
    acc = doc["accessors"][aid]
    view = doc["bufferViews"][acc["bufferView"]]
    code, size = {5121: ("B", 1), 5123: ("H", 2), 5126: ("f", 4)}[acc["componentType"]]
    width = 4 if acc["type"] == "VEC4" else 3
    scale = 255 if code == "B" else 65535 if code == "H" else 1
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", width * size)
    return [tuple(v / scale for v in struct.unpack_from("<" + code * width, binary, start + i * stride))
            for i in range(acc["count"])]


def color_pose(doc, binary, mesh_node, name):
    """One surface, two counted colour variants; STEP pose changes avoid z-fighting.

    Inset the inactive variant inside the active solid. The morph swaps the
    slate/mint positions, leaving the bone rim and every socket unchanged.
    Both variants retain valid triangles for Blender and Godot reimports.
    """
    mesh = doc["meshes"][doc["nodes"][mesh_node]["mesh"]]
    slate, mint = common.rgba(COLORS["slate"]), common.rgba(COLORS["mint"])
    for prim in mesh["primitives"]:
        aid = prim["attributes"]["POSITION"]
        pos = positions(doc, binary, aid)
        col = colors(doc, binary, prim["attributes"]["COLOR_0"])
        acc = doc["accessors"][aid]
        view = doc["bufferViews"][acc["bufferView"]]
        start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        delta = []
        live_count = idle_count = 0
        for i, (p, c) in enumerate(zip(pos, col)):
            is_mint = max(abs(c[j] - mint[j]) for j in range(3)) < .001
            is_slate = max(abs(c[j] - slate[j]) for j in range(3)) < .001
            live_count += int(is_mint)
            idle_count += int(is_slate)
            if name == "anchor_eye" and (is_slate or is_mint):
                radius = math.hypot(p[0], p[1])
                mid = (.9 / math.cos(math.pi / 12) + 1) / 2
                inset_radius = mid + (radius - mid) * .3
                inset = (p[0] * inset_radius / radius, p[1] * inset_radius / radius, p[2] * .4)
            else:
                inset = tuple(v * .7 for v in p)
            if is_mint:
                struct.pack_into("<3f", binary, start + i * stride, *inset)
                delta.append(tuple(p[j] - inset[j] for j in range(3)))
            else:
                delta.append(tuple(inset[j] - p[j] for j in range(3)) if is_slate else (0, 0, 0))
        assert live_count > 0 and idle_count > 0, "missing baked slate/mint pose vertices"
        prim["targets"] = [dict(POSITION=floats(doc, binary, delta, "VEC3"))]
    mesh["weights"] = [0]
    mesh["extras"] = dict(targetNames=["live_mint"])


def add_clip(doc, binary, name, node, path, times, values, kind, **extras):
    ti = floats(doc, binary, times, "SCALAR")
    vi = floats(doc, binary, values, kind)
    doc.setdefault("animations", []).append(dict(name=name, extras=extras,
        samplers=[dict(input=ti, output=vi, interpolation="LINEAR")],
        channels=[dict(sampler=0, target=dict(node=node, path=path))]))


def motions(path, name):
    doc, binary = read_glb(path)
    nodes = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
    root = nodes[name]
    phase = len(doc["nodes"])
    doc["nodes"].append(dict(name="PresentationState", extras=dict(presentation_only=True)))
    doc["nodes"][root].setdefault("children", []).append(phase)
    mesh_node = next(i for i, n in enumerate(doc["nodes"]) if "mesh" in n)
    if name in ("anchor_eye", "anchor_collar"):
        color_pose(doc, binary, mesh_node, name)
    for state in ({"thermal_vent": ("idle", "occupied"), "anchor_eye": ("idle", "ready", "attached")}
                  .get(name, ("rest",) if name not in ("thermal_air", "anchor_collar", "travel_vane") else ())):
        extras = dict(static_geometry=True)
        if name == "thermal_vent":
            extras["air_opacity"] = .08 if state == "idle" else .18
        if name == "anchor_eye":
            extras["sleeve_tint"] = COLORS["slate" if state == "idle" else "mint"]
            extras["requires_actual_harpoon_verdict"] = True
        if name == "anchor_eye":
            live = 0 if state == "idle" else 1
            add_clip(doc, binary, state, mesh_node, "weights", [0, .1], [live, live], "SCALAR", **extras)
            doc["animations"][-1]["samplers"][0]["interpolation"] = "STEP"
        else:
            add_clip(doc, binary, state, phase, "translation", [0, .1], [(0, 0, 0)] * 2, "VEC3", **extras)
    if name in ("thermal_air", "net_tile"):
        mesh_node = next(i for i, n in enumerate(doc["nodes"]) if "mesh" in n)
        mesh = doc["meshes"][doc["nodes"][mesh_node]["mesh"]]
        for prim in mesh["primitives"]:
            pos = positions(doc, binary, prim["attributes"]["POSITION"])
            if name == "net_tile":
                delta = [(0, -.09 * max(0, 1 - abs(x) / 2) * max(0, 1 - abs(z) / 2), 0)
                         for x, y, z in pos]
                prim["targets"] = [dict(POSITION=floats(doc, binary, delta, "VEC3"))]
            else:
                prim["targets"] = []
                for fn, sign in ((math.sin, 1), (math.sin, -1), (math.cos, 1), (math.cos, -1)):
                    delta = []
                    for x, y, z in pos:
                        envelope = 0 if y <= 0 or y >= 40 else math.sin(math.pi * y / 40)
                        wave = sign * fn(math.tau * y / 14) * envelope
                        delta.append((x * .045 * wave, .6 * wave, z * .045 * wave))
                    prim["targets"].append(dict(POSITION=floats(doc, binary, delta, "VEC3")))
        mesh["weights"] = [0] if name == "net_tile" else [1, 0, 0, 0]
        mesh["extras"] = dict(targetNames=["catch_settle"] if name == "net_tile" else
                              ["rise_sin", "rise_minus_sin", "rise_cos", "rise_minus_cos"])
        if name == "net_tile":
            add_clip(doc, binary, "catch", mesh_node, "weights", [0, .12, .4], [0, 1, 0], "SCALAR",
                     deflection_limit=.15, collision_unchanged=True)
        else:
            values = [v for row in ((1, 0, 0, 0), (0, 0, 0, 1), (0, 1, 0, 0),
                                    (0, 0, 1, 0), (1, 0, 0, 0)) for v in row]
            add_clip(doc, binary, "rise_loop", mesh_node, "weights", [0, .5, 1, 1.5, 2], values, "SCALAR",
                     loop=True, occupied_does_not_disable_lift=True, upward_phase_metres_per_second=7)
    if name == "anchor_collar":
        block = nodes["Block"]
        outer = .25 / math.sqrt(2)
        add_clip(doc, binary, "close", block, "translation", [0, .1],
                 [(outer, outer, 0), (0, 0, 0)], "VEC3", tint=COLORS["mint"], travel=.25)
        add_clip(doc, binary, "open", block, "translation", [0, .1],
                 [(0, 0, 0), (outer, outer, 0)], "VEC3", tint=COLORS["slate"], travel=.25)
        for clip, weight in ((doc["animations"][-2], 1), (doc["animations"][-1], 0)):
            sampler = len(clip["samplers"])
            clip["samplers"].append(dict(input=floats(doc, binary, [0, .1], "SCALAR"),
                output=floats(doc, binary, [weight, weight], "SCALAR"), interpolation="STEP"))
            clip["channels"].append(dict(sampler=sampler, target=dict(node=block, path="weights")))
        doc["nodes"][block]["translation"] = [outer, outer, 0]
    if name == "travel_vane":
        hinge = nodes["VaneHinge"]
        base = doc["nodes"][hinge].get("rotation", [0, 0, 0, 1])
        from mathutils import Quaternion
        a = Quaternion((base[3], base[0], base[1], base[2]))
        b = Quaternion((0, 1, 0), math.pi / 2) @ a
        add_clip(doc, binary, "turn", hinge, "rotation", [0, .3, .6],
                 [base, (b.x, b.y, b.z, b.w), (b.x, b.y, b.z, b.w)], "VEC4",
                 example_yaw_degrees=90, retarget_to_committed_endpoint=True, hold_through_travel=True)
    if name == "thermal_air":
        doc["materials"][0]["doubleSided"] = True
        doc["materials"][0]["alphaMode"] = "BLEND"
    write_glb(path, doc, binary)


def export(root, path, name):
    bpy.context.view_layer.update()
    if common.POLISH is not None:
        polish.bake(root, common.POLISH)
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in common.tree(root):
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=False, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_extras=True, export_animations=False, export_skins=True, export_cameras=False, export_lights=False)
    common.canonical_indices(str(path), vertices=common.POLISH is not None)
    motions(path, name)
    doc, _ = read_glb(path)
    triangles = vertices = draws = 0
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            triangles += doc["accessors"][prim["indices"]]["count"] // 3
            vertices += doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    cap = (800, 500, 2) if name == "thermal_air" else PROP_CAP
    assert 0 < triangles <= cap[0] and 0 < vertices <= cap[1] and draws <= cap[2], (name, triangles, vertices, draws)
    assert len(doc["materials"]) == 1
    print("MHL_ASSET %s T=%d V=%d draws=%d materials=1 bytes=%d sha256=%s" %
          (name, triangles, vertices, draws, path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest()))


def preview_glb(path, outdir, pose=None):
    common.reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    objs = [o for o in common.tree(bpy.data.objects[path.stem]) if o.type == "MESH"]
    if pose and path.stem not in ("anchor_eye", "anchor_collar"):
        raise ValueError("state previews are for anchor_eye / anchor_collar")
    if path.stem in ("anchor_eye", "anchor_collar"):
        for obj in objs:
            obj.animation_data_clear()
            keys = obj.data.shape_keys
            if keys and "live_mint" in keys.key_blocks:
                keys.animation_data_clear()
                keys.key_blocks["live_mint"].value = 1 if pose in ("ready", "attached", "close") else 0
            if path.stem == "anchor_collar" and pose == "close":
                obj.location = (0, 0, 0)
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    coords = [o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
    low = Vector(tuple(min(v[i] for v in coords) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in coords) for i in range(3)))
    ball_loc = Vector((high.x + 1.5, 0, low.z + 1))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=ball_loc)
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    ball.data.materials.append(common._flat("ReferenceBone", "d2c5a5"))
    p = common.Part("ReferenceBand")
    p.ring("paint", .995, 1.008, .12, 24, ball_loc, color="242a28")
    p.to_object()
    bpy.ops.mesh.primitive_plane_add(size=max(200, (high - low).length * 6), location=(0, 0, low.z - .02))
    bpy.context.object.data.materials.append(common._flat("PreviewGround", "53686d"))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("HighdraftPreview")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("a9b6c0")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55
    sun = bpy.data.lights.new("MorningSun", "SUN")
    sun.energy = 3
    lamp = bpy.data.objects.new("MorningSun", sun)
    scene.collection.objects.link(lamp)
    lamp.rotation_euler = (math.radians(28), math.radians(-35), math.radians(-35))
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    distance = max(20, (high - low).length * 2)
    for label, direction in (("front", (0, -1, .20)), ("side", (1, 0, .20)),
                             ("three_quarter", (.75, -1, .65))):
        if label == "side":
            old = ball.location.copy()
            ball.location = (0, high.y + 1.5, ball_loc.z)
            bpy.data.objects["ReferenceBand"].location += ball.location - old
        elif label == "three_quarter":
            old = ball.location.copy()
            ball.location = ball_loc
            bpy.data.objects["ReferenceBand"].location += ball.location - old
        ball_corners = [ball.location + Vector((x, y, z))
                        for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        points = coords + ball_corners
        centre = Vector(tuple((min(v[i] for v in points) + max(v[i] for v in points)) / 2
                              for i in range(3)))
        cam.location = centre + Vector(direction).normalized() * distance
        common._look(cam, centre)
        right = cam.rotation_euler.to_matrix() @ Vector((1, 0, 0))
        up = cam.rotation_euler.to_matrix() @ Vector((0, 1, 0))
        horizontal = [(v - centre).dot(right) for v in points]
        vertical = [(v - centre).dot(up) for v in points]
        cam.location += right * (min(horizontal) + max(horizontal)) / 2
        cam.location += up * (min(vertical) + max(vertical)) / 2
        cam.data.ortho_scale = max(max(horizontal) - min(horizontal), max(vertical) - min(vertical)) * 1.2
        tag = path.stem + ("_" + pose if pose else "")
        scene.render.filepath = str(outdir / (tag + "_" + label + ".png"))
        bpy.ops.render.render(write_still=True)
    print("MHL_PREVIEW", path.stem, "CPU Cycles samples=12 views=3 reference_ball_diameter=2m")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=Path(common.MODELS) / "highdraft")
    parser.add_argument("--preview-dir", type=Path)
    parser.add_argument("--preview-only", action="store_true")
    parser.add_argument("--preview-assets", nargs="+", choices=FILES)
    parser.add_argument("--preview-pose", choices=("idle", "ready", "attached", "close", "open"))
    opts = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    opts.out_dir.mkdir(parents=True, exist_ok=True)
    if not opts.preview_only:
        for name in FILES:
            common.reset()
            if name in POLISH:
                polish.enable(**POLISH[name])
            else:
                polish._opts = common.POLISH = None
                common.DETAIL = 1
            root = common.empty(name)
            root["family"] = "M5" if name == "thermal_air" else "M2"
            root["collision"] = False
            globals()[name](root)
            export(root, opts.out_dir / (name + ".glb"), name)
    if opts.preview_dir:
        opts.preview_dir.mkdir(parents=True, exist_ok=True)
        for name in opts.preview_assets or FILES:
            preview_glb(opts.out_dir / (name + ".glb"), opts.preview_dir, opts.preview_pose)


if __name__ == "__main__":
    main()
