"""MDS continuous sandstone surfaces. Coordinates below are Godot metres.

No mesh primitives, colliders, placement code or per-piece albedo beds. The low
surfaces are sampled directly from continuous erosion fields, with fixed diagonals.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import polish

LANDFORM = dict(bevel=0, bake_slots=("stone",))

MODELS = Path(common.MODELS) / "dig_stone"
BEDS = (1.7, 0.8, 2.6, 1.1, 0.6, 2.1, 1.4, 0.9)
SPECS = {
    "cut_face_long": ("CutFace", (8, 4, 2), {"socket_chain_l": (-4, 0, 0), "socket_chain_r": (4, 0, 0)}),
    "cut_face_scoop": ("CutScoop", (6, 4, 2.5), {"socket_chain_l": (-3, 0, 0), "socket_chain_r": (3, 0, 0)}),
    "rubble_cluster": ("Rubble", (3, 1, 2.5), {"socket_ground": (0, 0, 0)}),
    "breach_socket": ("SocketCut", (8, 1, 8), {"socket_plate": (0, 0, 0), "socket_landing_preview": (0, -5, -8)}),
    "bed_floor": ("FloorStudy", (8, 1, 8), {}),
    "bed_cut": ("CutStudy", (8, 4, 8), {}),
    "bed_rubble": ("RubbleStudy", (8, 1.8, 8), {}),
    "bed_recess": ("RecessStudy", (8, 4, 8), {}),
}


def to_blender(p):
    return (p[0], -p[2], p[1])


def ripple(x, z, phase=0):
    return 0.55 * math.sin(x * 1.13 + z * 0.71 + phase) + 0.3 * math.sin(x * 2.71 - z * 1.62 + 0.7) + 0.15 * math.sin(x * 5.13 + z * 4.07)


def grain(x, y, z):
    """Coherent sculpt displacement, without a fracture/joint grid."""
    def lattice(i, j, k):
        h = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
        return h - math.floor(h)
    def noise(scale):
        p = [x * scale, y * scale, z * scale]
        cell = [math.floor(v) for v in p]
        f = [v - c for v, c in zip(p, cell)]
        f = [t * t * (3 - 2 * t) for t in f]
        value = 0.0
        for i in range(2):
            for j in range(2):
                for k in range(2):
                    w = (f[0] if i else 1 - f[0]) * (f[1] if j else 1 - f[1]) * (f[2] if k else 1 - f[2])
                    value += w * lattice(cell[0] + i, cell[1] + j, cell[2] + k)
        return value - 0.5
    return noise(1.3) * 0.7 + noise(3.5) * 0.3


def bed_height(x, y, z):
    return y + 0.12 * x + 0.12 * math.sin(x * 0.68 + z * 0.23)


def erosion(x, y, z):
    h = bed_height(x, y, z)
    lo = -11.2
    lips = 0.0
    for _ in range(3):
        for thickness in BEDS[3:] + BEDS[:3]:
            lo += thickness
            lips += math.exp(-((h - lo) / 0.07) ** 2)
    return -0.19 * lips + 0.065 * ripple(x, y + z) + 0.32 * grain(x * 0.55, y, z * 0.7)


def wall(scoop=False):
    width, height, depth = SPECS["cut_face_scoop" if scoop else "cut_face_long"][1]
    n, rows = 64, 47
    verts, faces = [], []
    for k in range(rows):
        t = k / (rows - 1)
        for j in range(n):
            a = 2 * math.pi * j / n
            ca, sa = math.cos(a), math.sin(a)
            x = math.copysign(abs(ca) ** 0.38, ca) * width / 2
            z = math.copysign(abs(sa) ** 0.52, sa) * depth / 2
            crown = 0.86 + 0.10 * math.sin(x * 0.49 + 1) + 0.04 * math.cos(x * 1.4)
            y = t * height * crown
            x *= 1 - 0.07 * t ** 4
            z *= 1 - 0.12 * t ** 3
            e = erosion(x, y, z) * math.sin(math.pi * t) ** 0.5
            x += ca * e
            z += sa * e
            if scoop and sa < 0:
                z += 1.2 * abs(sa) ** 1.8 * math.sin(math.pi * t) ** 1.7
            verts.append((x, y, z))
    for k in range(rows - 1):
        for j in range(n):
            a, b = k * n + j, k * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    faces += [tuple(reversed(range(n))), tuple(range((rows - 1) * n, rows * n))]
    return verts, faces


def slab_pile(x, z, study=False):
    chips = [(-0.70, -0.30, 0.75, 0.62, 0.82, -0.16), (0.57, 0.30, 0.69, 0.77, 1.0, 0.12),
             (0.51, -0.63, 0.55, 0.48, 0.40, -0.28), (-0.80, 0.67, 0.40, 0.46, 0.53, 0.19)]
    if study:
        x, z = x / 2.2, z / 2.2
    pile = 0.0
    for cx, cz, rx, rz, h, tilt in chips:
        qx, qz = x - cx, z - cz
        u, v = qx + tilt * qz, qz - tilt * qx
        q = (abs(u / rx) ** 4 + abs(v / rz) ** 4) ** 0.25
        shoulder = max(0, min(1, (1.0 - q) / 0.23))
        shoulder = shoulder * shoulder * (3 - 2 * shoulder)
        pile = max(pile, shoulder * (h + tilt * u + 0.018 * ripple(x * 2, z * 2)))
    return pile


def floor_surface(name):
    rubble = name in ("rubble_cluster", "bed_rubble")
    cluster = name == "rubble_cluster"
    w, h, d = SPECS[name][1]
    nx, nz = (18, 10) if cluster else (32, 32)
    verts, faces = [], []
    for j in range(nz + 1):
        z = (j / nz - 0.5) * d
        for i in range(nx + 1):
            x = (i / nx - 0.5) * w
            if cluster:
                y = 0.065 + slab_pile(x, z)
            elif rubble:
                y = 1 + 0.8 * slab_pile(x, z, study=True)
            else:
                y = 0.965 + 0.031 * ripple(x * 0.7, z * 0.7)
            edge = min(i, nx - i, j, nz - j)
            if rubble:
                y = (0.065 if cluster else 1) + (y - (0.065 if cluster else 1)) * min(1, edge)
            verts.append((x, y, z))
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    border = list(range(nx + 1)) + [j * (nx + 1) + nx for j in range(1, nz + 1)]
    border += [nz * (nx + 1) + i for i in range(nx - 1, -1, -1)]
    border += [j * (nx + 1) for j in range(nz - 1, 0, -1)]
    bottom = []
    for index in border:
        x, _, z = verts[index]
        bottom.append(len(verts))
        verts.append((x, 0, z))
    for k in range(len(border)):
        j = (k + 1) % len(border)
        faces.append((border[k], border[j], bottom[j], bottom[k]))
    verts.append((0, 0, 0))
    center = len(verts) - 1
    for k in range(len(bottom)):
        faces.append((center, bottom[k], bottom[(k + 1) % len(bottom)]))
    return verts, faces


def rubble_surface():
    n, rings = 32, 8
    verts = [(0, 0.025 + slab_pile(0, 0), 0)]
    faces = []
    for k in range(1, rings + 1):
        t = k / rings
        for j in range(n):
            a = j * 2 * math.pi / n
            edge = 0.91 + 0.06 * math.sin(a * 3 + 0.4) + 0.03 * math.cos(a * 5)
            x, z = math.cos(a) * 1.5 * edge * t, math.sin(a) * 1.25 * edge * t
            toe = min(1, (1 - t) * 8)
            y = 0.025 + slab_pile(x, z) * toe
            verts.append((x, y, z))
    for j in range(n):
        faces.append((0, 1 + j, 1 + (j + 1) % n))
    for k in range(rings - 1):
        for j in range(n):
            a, b = 1 + k * n + j, 1 + k * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    last = 1 + (rings - 1) * n
    bottom = []
    for j in range(n):
        x, _, z = verts[last + j]
        bottom.append(len(verts))
        verts.append((x, 0, z))
    for j in range(n):
        k = (j + 1) % n
        faces.append((last + j, last + k, bottom[k], bottom[j]))
    verts.append((0, 0, 0))
    for j in range(n):
        faces.append((len(verts) - 1, bottom[j], bottom[(j + 1) % n]))
    return verts, faces


def study_wall(recess=False):
    profile = [(-4, 0), (-4, 1), (-2.6, 1), (-1.2, 1.01), (0.2, 1.04),
               (1.45, 1.45), (1.60, 2.10), (1.46, 2.65), (1.75, 3.35), (1.9, 4), (4, 4), (4, 0)]
    if recess:
        profile = [(-4, 0), (-4, 1), (-2.5, 1), (-1.0, 1.02), (0.8, 1.03),
                   (2.4, 1.32), (2.8, 1.95), (2.55, 2.58), (1.55, 3.0),
                   (0.1, 3.03), (-0.8, 3.16), (-0.95, 3.62), (-0.45, 4), (4, 4), (4, 0)]
    verts, faces = [], []
    rows = 49
    samples = []
    for k, a in enumerate(profile):
        b = profile[(k + 1) % len(profile)]
        for j in range(4):
            t = j / 4
            samples.append((a[0] * (1 - t) + b[0] * t, a[1] * (1 - t) + b[1] * t, k))
    n = len(samples)
    for i in range(rows):
        x = (i / (rows - 1) - 0.5) * 8
        for z, y, span in samples:
            zz, yy = z, y
            if recess and 4 <= span <= 10:
                mouth = max(0.08, 1 - (abs(x) / 3.95) ** 3.5)
                zz = -0.8 + (z + 0.8) * mouth
                vault = max(0.09, max(0, 1 - (x / 3.8) ** 2) ** 0.5)
                yy = 1 + (y - 1) * vault
            if 1.08 < y < 3.9:
                yy += 0.12 * math.sin(x * 0.66 + 0.2) + 0.028 * ripple(x, z)
                zz += erosion(x, yy, zz)
            if y >= 3.9:
                yy += -0.21 * (0.5 + 0.5 * math.sin(x * 0.79 + 1)) + 0.30 * grain(x * 0.7, y, z * 0.8)
            if recess and 7 <= span <= 11:
                zz += 0.14 * ripple(x * 0.6, y * 1.4)
                yy += 0.09 * ripple(x * 0.7, z * 0.8) * max(0.1, 1 - (x / 4) ** 2)
            if y > 0.05 and abs(z) > 3.95:
                zz += 0.04 * grain(x, y, z)
            xx = x + 0.045 * ripple(y * 1.5, z) * math.sin(math.pi * i / (rows - 1))
            verts.append((xx, yy, zz))
    for i in range(rows - 1):
        for j in range(n):
            a, b = i * n + j, i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    faces += [tuple(reversed(range(n))), tuple(range((rows - 1) * n, rows * n))]
    return verts, faces


def socket_surface():
    verts, faces = [], []
    n = 96
    for ring in range(6):
        for j in range(n):
            a = j * 2 * math.pi / n
            ca, sa = math.cos(a), math.sin(a)
            outer = 4 / max(abs(ca), abs(sa))
            outer -= (0.20 + 0.52 * (0.5 + 0.5 * math.sin(a * 7 + 0.6))) * abs(math.sin(a * 2))
            fraction = (1.0, 0.67, 0.30, 0.0, 0.0, 1.0)[ring]
            radius = 3 + (outer - 3) * fraction
            if ring == 4:
                radius += 0.045
            x, z = ca * radius, sa * radius
            if ring >= 4:
                y = -1
            else:
                y = -0.07 - 0.13 * fraction - 0.16 * grain(x, 0.5, z)
                y += 0.04 * ripple(x * 0.8, z * 0.8) * (1 - fraction)
            verts.append((x, y, z))
    for ring in range(6):
        following = (ring + 1) % 6
        for j in range(n):
            k = (j + 1) % n
            faces.append((ring * n + j, ring * n + k, following * n + k, following * n + j))
    return verts, faces


def fit_bounds(verts, size, name):
    lo = [min(p[k] for p in verts) for k in range(3)]
    hi = [max(p[k] for p in verts) for k in range(3)]
    if name == "breach_socket":
        return [(x, (y - hi[1]) / (hi[1] - lo[1]), z) for x, y, z in verts]
    return [tuple((p[k] - lo[k]) * size[k] / (hi[k] - lo[k]) - (size[k] / 2 if k != 1 else 0) for k in range(3)) for p in verts]


def make_mesh(name, verts, faces, root):
    mesh = bpy.data.meshes.new(name)
    triangles = []
    for face in faces:
        if len(face) == 4:
            triangles.extend(((face[0], face[1], face[2]), (face[0], face[2], face[3])))
        elif len(face) == 3:
            triangles.append(face)
        else:
            triangles.append(face)
    mesh.from_pydata([to_blender(p) for p in verts], [], triangles)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3], ngon_method="EAR_CLIP")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    polish.shape(bm, bevel=0)
    bm.to_mesh(mesh)
    bm.free()
    attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for i, loop in enumerate(mesh.loops):
        x, z, y = mesh.vertices[loop.vertex_index].co
        shade = 0.96 + 0.025 * ripple(x * 3, z * 3)
        attr.data[i].color = (shade, shade, shade, 1)
    mesh.color_attributes.active_color = attr
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    mat = bpy.data.materials.new("stone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = common.rgba("sandstone")
    bsdf.inputs["Roughness"].default_value = 0.95
    mat.diffuse_color = common.rgba("sandstone")
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    common.place(obj, (0, 0, 0), root)
    return obj


def main(name):
    parser = argparse.ArgumentParser()
    parser.add_argument("--out")
    opt = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    common.reset()
    polish.enable(**LANDFORM)
    part, size, sockets = SPECS[name]
    if name in ("cut_face_long", "cut_face_scoop"):
        verts, faces = wall(name == "cut_face_scoop")
    elif name in ("bed_cut", "bed_recess"):
        verts, faces = study_wall(name == "bed_recess")
    elif name == "breach_socket":
        verts, faces = socket_surface()
    elif name == "rubble_cluster":
        verts, faces = rubble_surface()
    else:
        verts, faces = floor_surface(name)
    verts = fit_bounds(verts, size, name)
    root = common.empty(name)
    obj = make_mesh(part, verts, faces, root)
    for socket, p in sockets.items():
        common.empty(socket, to_blender(p), root)
    budget = 600 if name == "rubble_cluster" else 8000
    assert 0 < common.tris(obj) <= budget, (name, common.tris(obj), budget)
    out = Path(opt.out) if opt.out else MODELS / (name + ".glb")
    common.export(root, str(out))
    data = out.read_bytes()
    print("MDS_EXPORT %s: %d triangles, %d bytes, sha256 %s" % (name, common.tris(obj), len(data), hashlib.sha256(data).hexdigest()))
