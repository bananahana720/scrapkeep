import array
import contextlib
import json
import math
import os
import struct
import subprocess
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SKETCH = os.path.normpath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(SKETCH, "assets", "models")

HEX = {
    "bone": "d2c5a5",
    "sandstone": "c6a274",
    "oxide": "9b513a",
    "copper": "b77843",
    "charcoal": "242a28",
    "petrol": "365754",
    "amber": "e5a044",
    "mint": "8bf0d3",
    "hazard": "ff5a3c",
    "brass": "d9b44a",
    "ice": "c8f0ff",
    "ancient": "9dff3c",
}

SLOTS = {
    "paint": {"vc": True, "rough": 0.8},
    "bare_metal": {"color": "bone", "lighten": 0.25, "metal": 0.6, "rough": 0.45},
    "rubber": {"color": "charcoal", "rough": 0.95},
    "class_accent": {"color": "mint", "emit": 0.4, "rough": 0.5},
    "field": {"color": "mint", "emit": 2.0, "rough": 0.4},
    "glass": {"color": "ffffff", "alpha": 0.12, "rough": 0.05},
    "pilot": {"vc": True, "rough": 0.9},
    "fleet_paint": {"color": "oxide", "rough": 0.8},
    "requisition_tag": {"color": "brass", "metal": 0.5, "rough": 0.4},
    "ancient_enamel": {"vc": True, "rough": 0.55},
    "hydraulic": {"vc": True, "metal": 0.4, "rough": 0.35},
    "ancient_light": {"color": "ancient", "emit": 3.0, "rough": 0.3},
    "rarity": {"color": "bone", "emit": 1.2, "rough": 0.5},
}

PAINT_SET = ("petrol", "oxide", "bone")

DETAIL = 1
POLISH = None


def _segs(n):
    return n * DETAIL


def preview_class(color):
    """Previews only: the class colour class_accent shows in renders (runtime reads the
    class row)."""
    SLOTS["class_accent"]["color"] = color


def srgb(name_or_hex):
    h = HEX.get(name_or_hex, name_or_hex)
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def to_linear(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mix(a, b, t):
    ca, cb = srgb(a), srgb(b)
    return tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3))


def rgba(color):
    """sRGB triple or palette name -> linear RGBA for a float colour attribute."""
    c = srgb(color) if isinstance(color, str) else color
    return (*to_linear(c), 1.0)


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": None, "render": None}
    i = 0
    while i < len(argv):
        if argv[i] in ("--out", "--render") and i + 1 < len(argv):
            out[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            i += 1
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(slot):
    mat = bpy.data.materials.get(slot)
    if mat is not None:
        return mat
    spec = SLOTS[slot]
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.8)
    bsdf.inputs["Metallic"].default_value = spec.get("metal", 0.0)
    if spec.get("vc"):
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        c = srgb(spec["color"])
        if spec.get("lighten"):
            c = tuple(x + (1.0 - x) * spec["lighten"] for x in c)
        lin = rgba(c)
        bsdf.inputs["Base Color"].default_value = lin
        if spec.get("emit"):
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = spec["emit"]
    if spec.get("alpha") is not None:
        bsdf.inputs["Alpha"].default_value = spec["alpha"]
        bsdf.inputs["Specular IOR Level"].default_value = 1.0
        mat.surface_render_method = "BLENDED"
    return mat


def mtx(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector(scale))


def aim(a, b):
    """Matrix placing a local +Z unit segment centred at the origin from a to b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return Matrix.LocRotScale((a + b) / 2, rot, Vector((1, 1, 1))), d.length


class Part:
    """One mesh object under construction: faces carry a slot and an optional colour."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Color")
        self.slots = []
        self.bevel = None
        self.subsurf = None
        self.regions = []

    @contextlib.contextmanager
    def region(self, bevel=None, subsurf=None, detail=None, fit=None):
        """Under polish, faces built inside the block take their own bevel, subdivision,
        segment multiplier and fit (None inherits the part's). Subdivided regions usually want
        detail=1. Wrap whole primitives: a region is cut out along its faces, so one that
        shares vertices with the rest of the part would open a seam. Without polish this
        does nothing."""
        global DETAIL
        if POLISH is None:
            yield
            return
        layers = self.bm.faces.layers.int
        layer = layers.get("polish_region") or layers.new("polish_region")
        before = set(self.bm.faces)
        outer = DETAIL
        if detail is not None:
            DETAIL = detail
        try:
            yield
        finally:
            DETAIL = outer
        self.regions.append((bevel, subsurf, fit))
        for f in self.bm.faces:
            if f not in before and not f[layer]:
                f[layer] = len(self.regions)

    def _slot(self, slot):
        if slot not in SLOTS:
            raise ValueError("unknown material slot " + slot)
        if slot not in self.slots:
            self.slots.append(slot)
        return self.slots.index(slot)

    def paint(self, faces, slot, color=None, alpha=1.0):
        """alpha is the paint take mask: 0 keeps the vertex colour under any equipped paint."""
        idx = self._slot(slot)
        c = rgba(color) if color is not None else (1.0, 1.0, 1.0, 1.0)
        c = (*c[:3], alpha)
        for f in faces:
            f.material_index = idx
            for loop in f.loops:
                loop[self.col] = c
        return faces

    def _faces(self, verts):
        self.bm.faces.index_update()
        return sorted({f for v in verts for f in v.link_faces}, key=lambda f: f.index)

    def box(self, slot, size, loc=(0, 0, 0), rot=(0, 0, 0), color=None, alpha=1.0):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx(loc, rot, size))
        return self.paint(self._faces(r["verts"]), slot, color, alpha)

    def cyl(self, slot, r1, r2, depth, segs=8, loc=(0, 0, 0), rot=(0, 0, 0), color=None, caps=True):
        r = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=_segs(segs),
                                  radius1=r1, radius2=r2, depth=depth, matrix=mtx(loc, rot))
        return self.paint(self._faces(r["verts"]), slot, color)

    def rod(self, slot, a, b, r, segs=6, color=None, r2=None, alpha=1.0):
        m, length = aim(a, b)
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=_segs(segs),
                                    radius1=r, radius2=r if r2 is None else r2, depth=length, matrix=m)
        return self.paint(self._faces(res["verts"]), slot, color, alpha)

    def beam(self, slot, a, b, w, h=None, color=None, roll=0.0, alpha=1.0):
        """A square-section beam from a to b."""
        m, length = aim(a, b)
        s = mtx((0, 0, 0), (0, 0, roll), (w, h if h else w, length))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m @ s)
        return self.paint(self._faces(r["verts"]), slot, color, alpha)

    def ico(self, slot, radius, subdiv=1, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), color=None):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv + (DETAIL > 1), radius=radius, matrix=mtx(loc, rot, scale))
        return self.paint(self._faces(r["verts"]), slot, color)

    def uv(self, slot, radius, u=8, v=6, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), color=None):
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=_segs(u), v_segments=_segs(v), radius=radius,
                                      matrix=mtx(loc, rot, scale))
        return self.paint(self._faces(r["verts"]), slot, color)

    def prism(self, slot, outline, depth, matrix=None, color=None, side_slot=None, side_color=None):
        """Extrudes a 2D outline (list of (x, y)) along local Z by depth, centred."""
        m = matrix if matrix is not None else Matrix.Identity(4)
        lo = [self.bm.verts.new(m @ Vector((x, y, -depth / 2))) for x, y in outline]
        hi = [self.bm.verts.new(m @ Vector((x, y, depth / 2))) for x, y in outline]
        faces = [self.bm.faces.new(list(reversed(lo))), self.bm.faces.new(hi)]
        sides = []
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            sides.append(self.bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
        self.paint(faces, slot, color)
        self.paint(sides, side_slot or slot, side_color if side_slot else color)
        return faces + sides

    def ring(self, slot, r_in, r_out, depth, segs=16, loc=(0, 0, 0), rot=(0, 0, 0), color=None,
             arc=(0.0, 2 * math.pi), taper=0.0):
        """A flat annulus (or arc of one) with thickness; taper shrinks the top radii."""
        m = mtx(loc, rot)
        segs = _segs(segs)
        closed = abs(arc[1] - arc[0] - 2 * math.pi) < 1e-6
        steps = segs if closed else segs + 1
        rows = []
        for k in range(steps):
            a = arc[0] + (arc[1] - arc[0]) * k / segs
            ca, sa = math.cos(a), math.sin(a)
            quad = [(r_in, -depth / 2), (r_out, -depth / 2), (r_out - taper, depth / 2), (r_in - taper, depth / 2)]
            rows.append([self.bm.verts.new(m @ Vector((r * ca, r * sa, z))) for r, z in quad])
        faces = []
        count = steps if closed else steps - 1
        for k in range(count):
            a, b = rows[k], rows[(k + 1) % steps]
            for i in range(4):
                j = (i + 1) % 4
                faces.append(self.bm.faces.new((a[i], b[i], b[j], a[j])))
        if not closed:
            faces.append(self.bm.faces.new(list(reversed(rows[0]))))
            faces.append(self.bm.faces.new(rows[-1]))
        return self.paint(faces, slot, color)

    def bolt(self, loc, normal, r=0.025, h=0.02, segs=6, slot="bare_metal"):
        n = Vector(normal).normalized()
        a = Vector(loc)
        return self.rod(slot, a - n * h * 0.3, a + n * h, r, segs)

    def verts_of(self, faces):
        self.bm.verts.index_update()
        return sorted({v for f in faces for v in f.verts}, key=lambda v: v.index)

    def jitter(self, faces, rng, amount):
        for v in self.verts_of(faces):
            v.co += Vector((rng.uniform(-amount, amount) for _ in range(3)))

    def to_object(self, origin=(0, 0, 0), parent=None):
        o = Vector(origin)
        bmesh.ops.translate(self.bm, vec=-o, verts=self.bm.verts)
        if POLISH is not None:
            import polish
            self.bm = polish.finish(self.bm, POLISH, self.bevel, self.subsurf, self.regions)
            self.col = self.bm.loops.layers.float_color["Color"]
        self.bm.normal_update()
        for f in list(self.bm.faces):
            if len(f.verts) > 4 and _convex(f):
                vs = [loop.vert for loop in f.loops]
                color = tuple(f.loops[0][self.col])
                if POLISH is not None:
                    def flat(k):
                        w = vs[k:] + vs[:k]
                        return any((w[i].co - w[0].co).cross(w[i + 1].co - w[0].co).length < 1e-9
                                   for i in range(1, len(w) - 1))
                    k = next((k for k in range(len(vs)) if not flat(k)), 0)
                    vs = vs[k:] + vs[:k]
                slot = f.material_index
                self.bm.faces.remove(f)
                for i in range(1, len(vs) - 1):
                    nf = self.bm.faces.new((vs[0], vs[i], vs[i + 1]))
                    nf.material_index = slot
                    for loop in nf.loops:
                        loop[self.col] = color
        if POLISH is None:
            bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        else:
            fixed, alternate = [], []
            for f in self.bm.faces:
                if len(f.verts) != 4:
                    fixed.append(f)
                    continue
                c = [tuple(v.co) for v in f.verts]
                d02, d13 = math.dist(c[0], c[2]), math.dist(c[1], c[3])
                if abs(d02 - d13) > 1e-9 * max(d02, d13):
                    first = d02 < d13
                else:
                    first = min(c[0], c[2]) < min(c[1], c[3])
                (fixed if first else alternate).append(f)
            bmesh.ops.triangulate(self.bm, faces=fixed, quad_method="FIXED", ngon_method="EAR_CLIP")
            bmesh.ops.triangulate(self.bm, faces=alternate, quad_method="ALTERNATE", ngon_method="EAR_CLIP")
            # Bevel leaves faces in a run-dependent order and Blender sums vertex normals in
            self.bm = polish._canonical(self.bm)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for slot in self.slots:
            mesh.materials.append(material(slot))
        if mesh.color_attributes.get("Color") is not None:
            mesh.color_attributes.active_color = mesh.color_attributes["Color"]
            mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        place(obj, o, parent)
        return obj


def _convex(face):
    vs = [loop.vert.co for loop in face.loops]
    n = len(vs)
    return all((vs[(i + 1) % n] - vs[i]).cross(vs[(i + 2) % n] - vs[(i + 1) % n]).dot(face.normal) > -1e-9
               for i in range(n))


def place(obj, world_origin, parent):
    world_origin = Vector(world_origin)
    obj["world_origin"] = list(world_origin)
    if parent is not None:
        obj.parent = parent
        obj.location = world_origin - Vector(parent["world_origin"])
    else:
        obj.location = world_origin


def empty(name, loc=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(obj)
    place(obj, loc, parent)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons) if obj.type == "MESH" else 0


def tree(obj):
    out = [obj]
    for c in obj.children:
        out += tree(c)
    return out


def tri_total(root, skip=()):
    return sum(tris(o) for o in tree(root) if o.name not in skip)


def max_radius(obj, center=(0, 0, 0)):
    c = Vector(center)
    mw = obj.matrix_world
    return max(((mw @ v.co) - c).length for v in obj.data.vertices)


def export(root, path):
    bpy.context.view_layer.update()
    if POLISH is not None:
        import polish
        polish.bake(root, POLISH)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in tree(root):
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_extras=False, export_animations=False, export_cameras=False,
                              export_lights=False)
    canonical_indices(path, vertices=POLISH is not None)
    print("EXPORTED", path)


def canonical_indices(path, vertices=False):
    """The glTF exporter emits the same triangles in a run-dependent order, sometimes
    through a different one of two identical vertices. Pointing each index at the first
    identical vertex and sorting the triangles (winding kept) makes a rerun
    byte-identical. With vertices, the vertex arrays are sorted too: subdivision emits
    the same vertices in a run-dependent order."""
    data = bytearray(open(path, "rb").read())
    json_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len + 8
    codes = {5121: "B", 5123: "H", 5125: "I"}
    sizes = {5121: 1, 5123: 2, 5125: 4, 5126: 4}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

    def element_bytes(acc_id):
        acc = gltf["accessors"][acc_id]
        view = gltf["bufferViews"][acc["bufferView"]]
        size = sizes[acc["componentType"]] * widths[acc["type"]]
        stride = view.get("byteStride", size)
        base = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return [bytes(data[base + k * stride:base + k * stride + size]) for k in range(acc["count"])]

    if vertices:
        data = _unshare_accessors(gltf, data, bin_start)
    def vertex_accessors(prim):
        ids = [a for _, a in sorted(prim["attributes"].items())]
        if not vertices:
            return ids
        return ids + [m[k] for m in prim.get("targets", []) for k in sorted(m)]

    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            columns = [element_bytes(a) for a in vertex_accessors(prim)]
            if vertices:
                rows = list(zip(*columns))
                order = sorted(range(len(rows)), key=lambda k: rows[k])
                where = [0] * len(order)
                for new, old in enumerate(order):
                    where[old] = new
                for acc_id, column in zip(vertex_accessors(prim), columns):
                    acc = gltf["accessors"][acc_id]
                    view = gltf["bufferViews"][acc["bufferView"]]
                    size = len(column[0])
                    stride = view.get("byteStride", size)
                    base = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                    for new, old in enumerate(order):
                        data[base + new * stride:base + new * stride + size] = column[old]
                columns = [[column[old] for old in order] for column in columns]
            first = {}
            same = [first.setdefault(key, k) for k, key in enumerate(zip(*columns))]
            acc = gltf["accessors"][prim["indices"]]
            view = gltf["bufferViews"][acc["bufferView"]]
            start = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            code = codes[acc["componentType"]]
            end = start + acc["count"] * array.array(code).itemsize
            idx = [same[where[i] if vertices else i] for i in array.array(code, data[start:end])]
            tris = [tuple(idx[k:k + 3]) for k in range(0, len(idx), 3)]
            tris = sorted(min(t, t[1:] + t[:1], t[2:] + t[:2]) for t in tris)
            data[start:end] = array.array(code, [i for t in tris for i in t]).tobytes()
    if vertices:
        data = _repack(gltf, data, bin_start)
    open(path, "wb").write(data)


def _unshare_accessors(gltf, data, bin_start):
    """The exporter reuses one accessor for identical data, such as the index lists of
    two parts built the same way. Sorting vertices permutes each primitive on its own,
    so every primitive after the first that uses an accessor gets its own copy."""
    used = set()
    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            holders = [(prim["attributes"], k) for k in sorted(prim["attributes"])] + [(prim, "indices")]
            holders += [(m, k) for m in prim.get("targets", []) for k in sorted(m)]
            for holder, key in holders:
                acc_id = holder[key]
                if acc_id not in used:
                    used.add(acc_id)
                    continue
                acc = dict(gltf["accessors"][acc_id])
                view = gltf["bufferViews"][acc["bufferView"]]
                start = bin_start + view.get("byteOffset", 0)
                chunk = bytes(data[start:start + view["byteLength"]])
                data += b"\0" * (-len(data) % 4)
                copy = {k: v for k, v in view.items() if k != "byteOffset"}
                copy["byteOffset"] = len(data) - bin_start
                data += chunk
                gltf["bufferViews"].append(copy)
                acc["bufferView"] = len(gltf["bufferViews"]) - 1
                gltf["accessors"].append(acc)
                holder[key] = len(gltf["accessors"]) - 1
                used.add(holder[key])
    return data


def _repack(gltf, data, bin_start):
    """Lay the buffer out again in a fixed order, one tight buffer view per accessor:
    mesh data by mesh, primitive and attribute name, then animation and skin data. Which
    accessors the exporter shares depends on the run, so its own layout is not stable."""
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    order, targets = [], {}
    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            for key in sorted(prim["attributes"]):
                order.append(prim["attributes"][key])
                targets[prim["attributes"][key]] = 34962
            order.append(prim["indices"])
            targets[prim["indices"]] = 34963
            for morph in prim.get("targets", []):
                for key in sorted(morph):
                    order.append(morph[key])
                    targets[morph[key]] = 34962
    for anim in gltf.get("animations", []):
        for sampler in anim["samplers"]:
            order += [sampler["input"], sampler["output"]]
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            order.append(skin["inverseBindMatrices"])
    new_id, accessors, views, binary = {}, [], [], bytearray()

    def place(chunk, target=None):
        binary.extend(b"\0" * (-len(binary) % 4))
        view = {"buffer": 0, "byteLength": len(chunk), "byteOffset": len(binary)}
        if target:
            view["target"] = target
        binary.extend(chunk)
        views.append(view)
        return len(views) - 1

    for old in order:
        if old in new_id:
            continue
        acc = dict(gltf["accessors"][old])
        view = gltf["bufferViews"][acc["bufferView"]]
        size = sizes[acc["componentType"]] * widths[acc["type"]]
        stride = view.get("byteStride", size)
        base = bin_start + view.get("byteOffset", 0) + acc.pop("byteOffset", 0)
        chunk = b"".join(bytes(data[base + k * stride:base + k * stride + size]) for k in range(acc["count"]))
        acc["bufferView"] = place(chunk, targets.get(old))
        new_id[old] = len(accessors)
        accessors.append(acc)
    for image in gltf.get("images", []):
        if "bufferView" in image:
            view = gltf["bufferViews"][image["bufferView"]]
            start = bin_start + view.get("byteOffset", 0)
            image["bufferView"] = place(bytes(data[start:start + view["byteLength"]]))
    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: new_id[v] for k, v in prim["attributes"].items()}
            prim["indices"] = new_id[prim["indices"]]
            prim["targets"] = [{k: new_id[v] for k, v in morph.items()} for morph in prim.get("targets", [])] or None
            if prim["targets"] is None:
                del prim["targets"]
    for anim in gltf.get("animations", []):
        for sampler in anim["samplers"]:
            sampler["input"], sampler["output"] = new_id[sampler["input"]], new_id[sampler["output"]]
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = new_id[skin["inverseBindMatrices"]]
    gltf["accessors"], gltf["bufferViews"] = accessors, views
    binary.extend(b"\0" * (-len(binary) % 4))
    gltf["buffers"][0]["byteLength"] = len(binary)
    text = json.dumps(gltf, separators=(",", ":"), sort_keys=True).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    return bytearray(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<I", len(text)) + b"JSON"
                     + text + struct.pack("<I", len(binary)) + b"BIN\0" + bytes(binary))


def default_out(name):
    return os.path.join(MODELS, name + ".glb")


def _look(cam, target):
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_turntable(root, name, outdir, views, ground_z=0.0, target=(0, 0, 0), yaws=(0, 90, 180, 270)):
    """views: list of (label, distance, pitch_rad, vfov_deg, (w, h)). The asset turns,
    the camera stays; forward is +Y, so yaw 0 shows it from behind like the chase cam."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 24
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("preview") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba(mix("sandstone", "bone", 0.5))
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    if bpy.data.objects.get("cam") is None:
        bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, ground_z))
        bpy.context.active_object.data.materials.append(_flat("ground", "sandstone"))
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 3.2
        sun_obj = bpy.data.objects.new("sun", sun)
        sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
        scene.collection.objects.link(sun_obj)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
    cam = bpy.data.objects["cam"]
    cam_data = cam.data
    scene.camera = cam
    os.makedirs(outdir, exist_ok=True)
    paths = []
    for label, dist, pitch, vfov, res, *crop in views:
        scene.render.resolution_x, scene.render.resolution_y = res
        c = crop[0] if crop else 1.0
        scene.render.use_border = c < 1.0
        scene.render.use_crop_to_border = c < 1.0
        scene.render.border_min_x = scene.render.border_min_y = 0.5 - c / 2
        scene.render.border_max_x = scene.render.border_max_y = 0.5 + c / 2
        cam_data.sensor_fit = "VERTICAL"
        cam_data.angle_y = math.radians(vfov)
        t = Vector(target)
        cam.location = t + Vector((0, -dist * math.cos(pitch), dist * math.sin(pitch)))
        _look(cam, t)
        for yaw in yaws:
            root.rotation_euler = (0, 0, math.radians(yaw))
            path = os.path.join(outdir, "%s_%s_%03d.png" % (name, label, yaw))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
    root.rotation_euler = (0, 0, 0)
    sheet = os.path.join(outdir, "%s_sheet.png" % name)
    subprocess.run(["montage", *paths, "-tile", "%dx" % len(yaws), "-geometry", "+4+4",
                    "-background", "#242a28", sheet], check=True)
    print("SHEET", sheet)
    return sheet


def _flat(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(color)
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def report(name, rows):
    """rows: list of (label, tris, (lo, hi) or None)."""
    ok = True
    for label, n, band in rows:
        inside = band is None or band[0] <= n <= band[1]
        ok = ok and inside
        print("TRIS %s %s %d %s %s" % (name, label, n, band if band else "", "ok" if inside else "OUT"))
    return ok
