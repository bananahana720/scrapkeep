# C09 Kest pod, world-one wear pass. Ports tools/blender/shell_kest.py (read-only
# reference; the port reproduces the shipped GLB byte for byte before wear() is added) and
# adds broad wear and exposed mechanisms without growing the silhouette: buckles, patches and
# rubbed edges on the three satchels, a worn saddle with a bare arc, weld beads and a repair
# plate, collars, a pressure gauge, cheek pivot bolts and a cocking lever on the mortar,
# chipped rim edges at its mouth, and a hinge barrel on posts under the vane with a chip and
# a repair plate on each blade. Crest, satchels, mortar mouth, open vane, node names, pilot
# and slots are unchanged; no new slot on any mesh, so no new draw.
# Budget: shell + rig pod stays under the 16,000 T / 15,000 V / 21 draw no-growth ceiling.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P world_one/shell_kest.py -- --out <file.glb>

import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part, Vector  # noqa: E402

# Pod ceiling from ASSETS.md: 16,000 T with the unchanged pilot rig; base pod 14,784 T.
POD_TRIS_MAX = 16000
BASE_POD_TRIS = 14784
BASE_SHELL_TRIS = 6120
SHELL_TRIS = (3000, BASE_SHELL_TRIS + POD_TRIS_MAX - BASE_POD_TRIS)

DOME_C = (0.0, 0.2, 0.8)
DOME_R = 0.56
VANE_HINGE = (0.0, -0.32, 1.02)


def satchel(p, loc, yaw, canvas):
    m = common.mtx(loc, (0, 0, yaw))
    body = p.box("paint", (0.3, 0.2, 0.26), loc=m @ Vector((0, 0, 0)), rot=(0, 0, yaw), color=canvas)
    flap = p.box("paint", (0.31, 0.12, 0.08), loc=m @ Vector((0, 0.05, 0.12)), rot=(0.3, 0, yaw), color="petrol")
    for dz in (-0.07, 0.03):
        p.box("class_accent", (0.32, 0.22, 0.045), loc=m @ Vector((0, 0, dz)), rot=(0, 0, yaw))
    for dx in (-0.07, 0.07):
        top = m @ Vector((dx, -0.03, 0.13))
        tip = m @ Vector((dx * 1.3, -0.05, 0.25))
        p.rod("rubber", top, tip, 0.014, 5)
        p.ico("class_accent", 0.028, 1, loc=tip)
    p.rod("rubber", m @ Vector((0, -0.1, 0.1)), (loc[0] * 0.7, loc[1] * 0.7, loc[2] + 0.12), 0.02, 5)

    return m, body, flap


def pod():
    p = Part("Pod")
    sb.saddle(p, center=(0.0, 0.14, 0.76), r_in=0.42, r_out=0.62, color="bone")
    working = [
        satchel(p, (0.8, -0.08, 0.66), math.pi / 2 + 0.2, "oxide"),
        satchel(p, (0.06, -0.8, 0.64), math.pi, "petrol"),
        satchel(p, (-0.74, 0.3, 0.62), -math.pi / 2 - 0.3, "oxide"),
    ]
    base = Vector((-0.6, -0.42, 0.78))
    mouth = Vector((-0.66, -0.26, 1.2))
    tube_faces = p.rod("paint", base, mouth, 0.09, 10, color="oxide")
    p.rod("bare_metal", base - (mouth - base) * 0.12, base + (mouth - base) * 0.12, 0.11, 10)
    p.ring("class_accent", 0.065, 0.115, 0.05, 10, loc=mouth,
           rot=(Vector((0, 0, 1)).rotation_difference((mouth - base).normalized())).to_euler())
    for side in (-1, 1):
        p.box("paint", (0.03, 0.26, 0.22), loc=base + Vector((side * 0.13, 0.02, 0.02)), color="petrol")
        p.rod("bare_metal", base + Vector((side * 0.13, -0.12, -0.06)), base + Vector((side * 0.13, -0.02, 0.2)),
              0.022, 6)
    p.beam("bare_metal", (-0.35, -0.2, 0.8), base, 0.06)
    # The vane's spine and struts; the blades are separate hinged objects.
    p.beam("bare_metal", (0, -0.2, 0.88), (0, -0.9, 0.9), 0.06, 0.05)
    p.beam("bare_metal", (0, -0.62, 0.9), (0, -0.62, 0.72), 0.05)
    wear(p)
    rub_edges(p, working, base, mouth, tube_faces)
    return p


def rub_edges(p, working, base, mouth, tube_faces):
    """Rub the existing working edges with bone vertex colour (C09 correction).
    Geometry and material slots stay intact; each build owns its face references.
    """
    bone = tuple(common.rgba("bone"))
    for m, body, flap in working:
        inv = m.inverted()
        for f in body:
            for loop in f.loops:
                if (inv @ loop.vert.co).z > 0.06:
                    loop[p.col] = bone
        for f in flap:
            for loop in f.loops:
                c = inv @ loop.vert.co
                if c.y > 0.09 or c.z > 0.19:
                    loop[p.col] = bone
    d = (mouth - base).normalized()
    length = (mouth - base).length
    for f in tube_faces:
        for loop in f.loops:
            if (loop.vert.co - base).dot(d) / length > 0.8:
                loop[p.col] = bone


def wear(p):
    """Wear and exposed mechanisms; every piece stays inside the old pod extents."""
    V = Vector
    # Satchels: a buckle plate on the upper strap, a repair patch between the straps and a
    # rubbed-through chip at the lower corner, all on the face the base leaves flat.
    for k, (loc, yaw, patch) in enumerate((((0.8, -0.08, 0.66), math.pi / 2 + 0.2, "bone"),
                                           ((0.06, -0.8, 0.64), math.pi, "oxide"),
                                           ((-0.74, 0.3, 0.62), -math.pi / 2 - 0.3, "bone"))):
        m = common.mtx(loc, (0, 0, yaw))
        out = m.to_3x3() @ V((0, 1, 0))
        s = 1.0 if (out.x * loc[0] + out.y * loc[1]) > 0 else -1.0
        p.box("bare_metal", (0.05, 0.022, 0.06), loc=m @ V((0.0, s * 0.1, 0.03)), rot=(0, 0, yaw))
        p.box("paint", (0.1, 0.02, 0.05), loc=m @ V((-0.07, s * 0.1, -0.02)), rot=(0, 0, yaw), color=patch)
        p.box("bare_metal", (0.06, 0.02, 0.04), loc=m @ V((0.1, s * 0.098, -0.1)), rot=(0, 0, yaw + 0.4))
    # Saddle: a rubbed-through arc on the rim, two weld beads and a mismatched repair plate.
    c = V((0.0, 0.14, 0.76))
    p.ring("bare_metal", 0.575, 0.605, 0.035, 4, loc=c + V((0, 0, 0.015)), arc=(3.9, 4.7))
    for deg in (47, 167):
        a = math.radians(deg)
        p.rod("bare_metal", c + V((0.45 * math.cos(a), 0.45 * math.sin(a), 0.07)),
              c + V((0.56 * math.cos(a), 0.56 * math.sin(a), 0.07)), 0.014, 4)
    a = math.radians(105)
    p.box("paint", (0.1, 0.07, 0.03), loc=c + V((0.5 * math.cos(a), 0.5 * math.sin(a), 0.055)), rot=(0, 0, a),
          color="petrol")
    # Mortar: collars on the tube, a pressure gauge, cheek pivot bolts, a cocking lever with
    # a knob on the left cheek, chips on the mouth ring and a second brace to the saddle.
    base = V((-0.6, -0.42, 0.78))
    mouth = V((-0.66, -0.26, 1.2))
    d = (mouth - base).normalized()
    length = (mouth - base).length
    tube = d.rotation_difference(V((0, 0, 1))).inverted().to_euler()
    for t in (0.4, 0.72):
        p.cyl("bare_metal", 0.1, 0.1, 0.03, 8, loc=base + d * length * t, rot=tube)
    g = base + d * length * 0.55 + V((-0.095, 0, 0))
    p.cyl("bare_metal", 0.05, 0.05, 0.02, 8, loc=g, rot=(0, math.pi / 2, 0))
    p.cyl("paint", 0.038, 0.038, 0.015, 8, loc=g + V((-0.008, 0, 0)), rot=(0, math.pi / 2, 0), color="bone")
    for side in (-1, 1):
        p.bolt(base + V((side * 0.145, 0.02, -0.02)), (side, 0, 0), r=0.03, h=0.02, segs=5)
    lever_a = base + V((-0.165, 0.02, -0.02))
    lever_b = base + V((-0.165, -0.06, 0.12))
    p.rod("bare_metal", lever_a, lever_b, 0.014, 5)
    p.cyl("rubber", 0.028, 0.028, 0.03, 6, loc=lever_b, rot=(0, math.pi / 2, 0))
    u = d.cross(V((1, 0, 0))).normalized()
    w = d.cross(u)
    for ang in (0.6, 3.4):
        at = mouth + d * 0.02 + (u * math.cos(ang) + w * math.sin(ang)) * 0.09
        p.box("bare_metal", (0.045, 0.03, 0.012), loc=at, rot=tube)
    p.beam("bare_metal", V((-0.4, -0.55, 0.79)), base + d * length * 0.1, 0.05)
    # Vane: a hinge barrel under the blades' folded base, carried on two posts from the spine.
    p.rod("bare_metal", V((0, -0.9, 0.985)), V((0, -0.3, 0.985)), 0.02, 6)
    for y in (-0.4, -0.8):
        p.rod("bare_metal", V((0, y, 0.9)), V((0, y, 0.985)), 0.022, 5)


def blade(name, side):
    """One vane blade standing folded; the hinge runs fore-aft along its base, and
    opening turns it 90 degrees outward about that axis (VaneL/VaneR, rotation y)."""
    b = Part(name)
    outline = [(0.1, 0.0), (-0.62, 0.0), (-0.7, 0.07), (-0.58, 0.3), (-0.02, 0.16)]
    m = common.mtx((side * 0.03, 0, 0), (0, -math.pi / 2, 0))
    yz = [(z, y) for y, z in outline]
    hinge = Vector(VANE_HINGE)
    b.prism("paint", yz, 0.028, matrix=common.mtx(hinge) @ m, color="bone")
    for y in (-0.1, -0.35):
        b.beam("bare_metal", hinge + Vector((side * 0.045, y, 0.01)), hinge + Vector((side * 0.045, y, 0.22)), 0.03)
    b.box("rubber", (0.05, 0.72, 0.04), loc=hinge + Vector((0, -0.27, 0.0)))
    # Wear inside the blade outline: a rubbed-through chip near the trailing edge and a
    # mismatched repair plate near the root, both within the bolt rail's thickness.
    b.box("bare_metal", (0.034, 0.06, 0.04), loc=hinge + Vector((side * 0.03, -0.6, 0.19)), rot=(-0.48, 0, 0))
    b.box("paint", (0.036, 0.16, 0.1), loc=hinge + Vector((side * 0.03, -0.3, 0.09)), color="petrol")
    return b


def pilot():
    f = Part("Pilot")
    crest = common.mix("oxide", "amber", 0.2)
    beak = common.mix("amber", "sandstone", 0.35)
    f.uv("pilot", 0.21, 24, 16, loc=(0, 0.2, 1.09), scale=(1.02, 0.88, 1.0), color="bone")
    for side in (-1, 1):
        f.uv("pilot", 0.08, 12, 8, loc=(side * 0.115, 0.302, 1.085), scale=(0.85, 0.40, 1.15), color="charcoal")
        f.ring("pilot", 0.044, 0.063, 0.03, 16, loc=(side * 0.088, 0.35, 1.155), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.088, 0.374, 1.155), 0.040)
    f.rod("pilot", (-0.027, 0.35, 1.158), (0.027, 0.35, 1.158), 0.012, 8, color="charcoal")
    f.uv("pilot", 0.08, 16, 10, loc=(0, 0.357, 1.035), scale=(0.8, 1.2, 0.6), color=beak)
    f.rod("pilot", (0, 0.39, 1.043), (0, 0.475, 0.99), 0.045, 10, color=beak, r2=0.006)
    f.rod("pilot", (0, 0.37, 0.994), (0, 0.44, 0.976), 0.026, 8, color="charcoal", r2=0.005)
    for k in range(3):
        f.uv("pilot", 0.07, 12, 8, loc=(0, 0.16 - k * 0.05, 1.3 + k * 0.015), scale=(0.42, 0.65, 1.75), rot=(0.35 + k * 0.2, 0, 0), color=crest)
    return f


def stable_pilot_normals(path):
    """Two exports differed by 0.00009 in a static pilot smooth normal.
    Round components to 0.001 and normalize; geometry and animated rigs stay intact.
    """
    with open(path, "rb") as f:
        data = bytearray(f.read())
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 28 + json_len
    for mesh in gltf["meshes"]:
        if mesh["name"] != "Pilot":
            continue
        for primitive in mesh["primitives"]:
            accessor = gltf["accessors"][primitive["attributes"]["NORMAL"]]
            view = gltf["bufferViews"][accessor["bufferView"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            start = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            for i in range(accessor["count"]):
                offset = start + i * stride
                normal = struct.unpack_from("<3f", data, offset)
                rounded = tuple(round(x, 3) or 0.0 for x in normal)
                length = math.sqrt(math.fsum(x * x for x in rounded))
                struct.pack_into("<3f", data, offset, *(x / length for x in rounded))
    with open(path, "wb") as f:
        f.write(data)
    common.canonical_indices(path)
    print("STABLE_NORMALS Kest static Pilot, component precision 0.001")


def main():
    common.reset()
    common.preview_class("amber")
    root, core_obj, pilot_obj = sb.spherical("Kest", pod(), pilot(), extras=[(blade("VaneL", -1), VANE_HINGE), (blade("VaneR", 1), VANE_HINGE)])
    shell_tris = common.tri_total(root, skip=(pilot_obj.name,))
    ok = common.report("Kest", [("shell", shell_tris, SHELL_TRIS), ("pilot", common.tris(pilot_obj), sb.PILOT_TRIS)])
    radius = common.max_radius(core_obj)
    print("CORE_RADIUS Kest %.3f %s" % (radius, "ok" if radius <= 1.0 else "OUT"))
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "shell_kest.glb")
    common.export(root, out)
    stable_pilot_normals(out)
    if not ok or radius > 1.0:
        raise SystemExit("budget out of range for Kest")


main()
