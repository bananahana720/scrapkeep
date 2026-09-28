"""Original static mesh kit. Blender coordinates: metres, Z up, face toward -Y."""
import hashlib
import json
import math
import random
from dataclasses import asdict, dataclass

import bpy
from mathutils import Vector

LODS = {"detailed": (24, 12, 8), "reduced": (12, 7, 5)}
FIXTURES = {
    "broad": {"width": 1.64, "depth": 1.26, "height": 1.75, "neck": 0.66},
    "slender": {"width": 1.02, "depth": 1.08, "height": 2.22, "neck": 0.48},
}
COLORS = {
    "cream": (0.77, 0.66, 0.46, 1),
    "fur": (0.92, 0.78, 0.53, 1),
    "ochre": (0.63, 0.28, 0.065, 1),
    "metal": (0.055, 0.083, 0.09, 1),
    "teal": (0.035, 0.31, 0.33, 1),
    "glint": (0.57, 0.86, 0.79, 1),
}


@dataclass(frozen=True)
class Fit:
    width: float
    depth: float
    height: float
    neck: float
    eye_fraction: float = 0.13
    tuft_count: int = 9
    seed: int = 1702

    def validate(self):
        for field in ("width", "depth", "height", "neck"):
            value = getattr(self, field)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0.1 <= value <= 4:
                raise ValueError(f"{field} must be finite and within 0.1..4 metres")
        if not 0.35 <= self.width / self.height <= 1.15 or not 0.4 <= self.depth / self.height <= 0.95:
            raise ValueError("head proportions exceed the demonstrated fitting envelope")
        if self.neck < 0.12:
            raise ValueError("neck must be at least 0.12 metres for fixed collar wall thickness")
        if self.neck >= self.width * 0.75:
            raise ValueError("neck must be less than 75 percent of head width")
        if isinstance(self.eye_fraction, bool) or not isinstance(self.eye_fraction, (int, float)) or not math.isfinite(self.eye_fraction) or not 0 <= self.eye_fraction <= 0.25:
            raise ValueError("eye_fraction must be finite in 0..0.25")
        if type(self.tuft_count) is not int or not 5 <= self.tuft_count <= 13:
            raise ValueError("tuft_count must be an integer in 5..13")
        if type(self.seed) is not int or not 0 <= self.seed <= 2**32 - 1:
            raise ValueError("seed must be an unsigned 32-bit integer")
        return self


def material(role):
    name = "Kit_" + role
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = COLORS[role]
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = COLORS[role]
        shader.inputs["Roughness"].default_value = 0.32 if role in ("metal", "teal") else 0.66
        shader.inputs["Metallic"].default_value = 0.55 if role in ("ochre", "metal") else 0.0
    return mat


def mesh_object(collection, name, verts, faces, role, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(material(role))
    for face in mesh.polygons:
        face.use_smooth = smooth
    obj["kit_role"] = name.split(".")[0]
    return obj


def ellipsoid(collection, name, center, radii, segments, rings, role, profile=False):
    verts = [(center[0], center[1], center[2] - radii[2])]
    for row in range(1, rings):
        latitude = -math.pi / 2 + math.pi * row / rings
        z = math.sin(latitude)
        for col in range(segments):
            angle = 2 * math.pi * col / segments
            x, y = math.cos(latitude) * math.cos(angle), math.cos(latitude) * math.sin(angle)
            if profile:
                x *= 0.85 + 0.15 * (z + 1) / 2
                if y < 0:
                    y *= 0.86 + 0.1 * math.cos(latitude)
            verts.append(tuple(center[i] + (x, y, z)[i] * radii[i] for i in range(3)))
    top = len(verts)
    verts.append((center[0], center[1], center[2] + radii[2]))
    faces = []
    for col in range(segments):
        nxt = (col + 1) % segments
        faces.append((0, 1 + nxt, 1 + col))
        for row in range(rings - 2):
            a = 1 + row * segments + col
            b = 1 + row * segments + nxt
            faces.append((a, b, b + segments, a + segments))
        faces.append((top, 1 + (rings - 2) * segments + col, 1 + (rings - 2) * segments + nxt))
    return mesh_object(collection, name, verts, faces, role, smooth=True)


def band(collection, name, center, rx, ry, height, thickness, segments, role):
    dimensions = (rx, ry, height, thickness)
    if not all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) and v > 0 for v in dimensions) or thickness >= min(rx, ry):
        raise ValueError("band dimensions must be finite and positive with positive inner radii")
    if type(segments) is not int or not 3 <= segments <= 64:
        raise ValueError("band segments must be an integer in 3..64")
    verts = []
    for inset, z in ((0, -height / 2), (0, height / 2), (thickness, -height / 2), (thickness, height / 2)):
        for i in range(segments):
            a = i * 2 * math.pi / segments
            verts.append((center[0] + (rx - inset) * math.cos(a), center[1] + (ry - inset) * math.sin(a), center[2] + z))
    faces = []
    for i in range(segments):
        j = (i + 1) % segments
        faces.extend(((i, j, j + segments, i + segments), (i + 2 * segments, i + 3 * segments, j + 3 * segments, j + 2 * segments), (i, i + 2 * segments, j + 2 * segments, j), (i + segments, j + segments, j + 3 * segments, i + 3 * segments)))
    return mesh_object(collection, name, verts, faces, role)


def tuft(collection, name, anchor, tip, width, depth, sides, role):
    direction = Vector(tip) - Vector(anchor)
    axis = direction.normalized()
    side = axis.cross(Vector((0, 1, 0))).normalized()
    other = axis.cross(side).normalized()
    verts = []
    for fraction, radius in ((0, 0.7), (0.38, 1), (0.72, 0.65)):
        center = Vector(anchor) + direction * fraction + Vector((0, 0.07 * direction.length * fraction, 0))
        for i in range(sides):
            angle = i * 2 * math.pi / sides
            verts.append(tuple(center + side * math.cos(angle) * width * radius + other * math.sin(angle) * depth * radius))
    verts.append(tuple(tip))
    faces = [tuple(reversed(range(sides)))]
    for row in range(2):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((row * sides + i, row * sides + j, (row + 1) * sides + j, (row + 1) * sides + i))
    for i in range(sides):
        faces.append((2 * sides + i, 2 * sides + (i + 1) % sides, 3 * sides))
    return mesh_object(collection, name, verts, faces, role)


def fur(collection, fit, center_z, sides):
    rng = random.Random(fit.seed)
    for i in range(fit.tuft_count):
        x = (i / (fit.tuft_count - 1) * 2 - 1) * fit.width * 0.42
        z = center_z + fit.height * 0.45 * math.sqrt(max(0, 1 - (x / (fit.width * 0.55)) ** 2))
        length = fit.height * rng.uniform(0.23, 0.34)
        anchor = (x, 0.05, z - 0.08)
        tip = (x + fit.width * 0.13, 0.09 + rng.uniform(0.03, 0.12), z + length)
        tuft(collection, f"Fur.Crown.{i:02}", anchor, tip, fit.width * 0.13, fit.depth * 0.17, sides, "fur" if i % 3 else "ochre")
    for sign in (-1, 1):
        for i in range(3):
            z = center_z + fit.height * (0.12 - i * 0.18)
            anchor = (sign * fit.width * (0.41 - i * 0.025), -fit.depth * 0.15, z)
            tip = (sign * fit.width * (0.67 - i * 0.035), -fit.depth * 0.08, z - fit.height * 0.22)
            tuft(collection, f"Fur.Cheek.{sign:+}.{i}", anchor, tip, fit.width * 0.12, fit.depth * 0.12, sides, "fur")


def goggles(collection, fit, center_z, segments):
    eye_z = center_z + fit.height * fit.eye_fraction
    face_y = -fit.depth * 0.51
    band(collection, "Goggles.Strap", (0, 0, eye_z), fit.width * 0.49, fit.depth * 0.51, fit.height * 0.075, 0.035, segments, "metal")
    for sign in (-1, 1):
        center = (sign * fit.width * 0.225, face_y, eye_z)
        frame = band(collection, f"Goggles.Frame.{sign:+}", (0, 0, 0), fit.width * 0.217, fit.height * 0.153, 0.11, fit.width * 0.045, segments, "ochre")
        frame.rotation_euler[0] = math.pi / 2
        frame.location = center
        lens = ellipsoid(collection, f"Goggles.Lens.{sign:+}", center, (fit.width * 0.166, 0.052, fit.height * 0.115), segments, 4, "teal")
        lens.location.y = -0.065
        ellipsoid(collection, f"Goggles.Glint.{sign:+}", (center[0] - fit.width * 0.045, face_y - 0.115, eye_z + fit.height * 0.035), (fit.width * 0.022, 0.006, fit.height * 0.055), 6, 4, "glint")
    ellipsoid(collection, "Goggles.Bridge", (0, face_y, eye_z + fit.height * 0.025), (fit.width * 0.095, 0.07, fit.height * 0.035), 8, 4, "metal")


def collar(collection, fit, segments):
    band(collection, "Collar.Body", (0, 0, 0.58), fit.neck * 0.79, fit.neck * 0.72, 0.24, 0.08, segments, "ochre")
    band(collection, "Collar.Rim", (0, 0, 0.7), fit.neck * 0.82, fit.neck * 0.75, 0.07, 0.065, segments, "metal")
    ellipsoid(collection, "Collar.Clasp", (0, -fit.neck * 0.77, 0.58), (0.105, 0.045, 0.13), 8, 4, "teal")


def build(fixture="broad", lod="detailed", fit=None):
    if fixture not in FIXTURES or lod not in LODS:
        raise ValueError("fixture must be broad/slender and LOD detailed/reduced")
    fit = (fit or Fit(**FIXTURES[fixture])).validate()
    segments, rings, sides = LODS[lod]
    collection = bpy.data.collections.new(f"Kit.{fixture}.{lod}")
    bpy.context.scene.collection.children.link(collection)
    center_z = 0.85 + fit.height / 2
    ellipsoid(collection, "Fixture.Head", (0, 0, center_z), (fit.width / 2, fit.depth / 2, fit.height / 2), segments, rings, "cream", profile=True)
    ellipsoid(collection, "Fixture.Bust", (0, 0.07, 0.27), (fit.width * 0.6, fit.depth * 0.39, 0.3), segments, max(5, rings - 3), "metal")
    ellipsoid(collection, "Fixture.Neck", (0, 0.02, 0.75), (fit.neck / 2, fit.neck * 0.43, 0.54), segments, max(5, rings - 3), "cream")
    ellipsoid(collection, "Fixture.Nose", (0, -fit.depth * 0.48, center_z - fit.height * 0.02), (fit.width * 0.13, fit.depth * 0.16, fit.height * 0.15), max(8, segments // 2), 6 if lod == "detailed" else 4, "cream")
    fur(collection, fit, center_z, sides)
    goggles(collection, fit, center_z, segments)
    collar(collection, fit, segments)
    return collection, {"fixture": fixture, "lod": lod, "fit": asdict(fit), "anchors": {"head_center_z": center_z, "eye_z": center_z + fit.height * fit.eye_fraction, "goggle_face_y": -fit.depth * 0.51, "collar_z": 0.58}}


def geometry(collection):
    bpy.context.view_layer.update()
    payload = []
    triangles = 0
    for obj in sorted(collection.objects, key=lambda o: o.name):
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        payload.append({"name": obj.name, "vertices": [[round(v, 7) for v in vertex.co] for vertex in obj.data.vertices], "faces": [list(p.vertices) for p in obj.data.polygons], "matrix": [[round(v, 7) for v in row] for row in obj.matrix_local]})
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"triangles": triangles, "objects": len(payload), "geometry_sha256": digest}


def clear():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
