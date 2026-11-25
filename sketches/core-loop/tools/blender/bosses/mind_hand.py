"""Detached Mind hand, metres, Blender +Z up/+Y forward, one skin/three draws.

blender -b --threads 2 --python-exit-code 1 --python \
  sketches/core-loop/tools/blender/bosses/mind_hand.py -- [--out FILE]

No root motion, collider, UI, habit selection or authored aim. Runtime owns the
LensRoot bearing and starts/seeks these clips from counter.gd's real phase age.
The upper link telescopes slightly in warning to bridge the bent middle link to
the fixed y=3.4 lens socket. This is visual linkage compensation only.

Glove (2026-10-18): the field hand is one gloved finger-arm, the crew's glove the
Mind still wears. Rounder 16-sided links, a stitched seam ridge with ticks down
each link's back, and a rolled pale cuff band at the lens end.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
ROOT = SKETCH.parents[1]
sys.path.insert(0, str(HERE.parent))
import common

PALETTE = {k: tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)) for k, h in {
    "bone": "d2c5a5", "petrol": "365754", "charcoal": "242a28",
    "blue": "3d8bff", "hazard": "ff5a3c", "mint": "8bf0d3",
    "slate": "617481", "glass": "25333a"}.items()}
CLIPS = {"still_track": 2.0, "quote_warn": 1.4, "exact_strike": 0.2,
         "brace": 5.0, "recover": 3.0, "lens_break": 0.6}
KEY_POSES = {"still_track": 0.0, "quote_warn": 1.4, "exact_strike": 0.1,
             "brace": 2.5, "recover": 3.0, "lens_break": 0.6}
BONES = [
    ("HandRoot", (0, 0, 0), None), ("Foot", (0, 0, -1.55), "HandRoot"),
    ("Segment0", (0, 0, -1.3), "HandRoot"),
    ("Segment1", (0, 0, 0.3), "HandRoot"),
    ("Segment2", (0, 0, 1.9), "HandRoot"),
    ("LensRoot", (0, 0, 3.4), "HandRoot"),
    ("MainLens", (0, 0, 3.4), "LensRoot"),
    ("SideLensL", (-0.75, -0.2, 3.2), "LensRoot"),
    ("SideLensR", (0.75, -0.2, 3.2), "LensRoot"),
    ("LensShutter", (0, 0.46, 3.4), "LensRoot"),
    ("HazardFace", (0, 0.48, 3.4), "LensShutter"),
    ("SlateTarget", (0, 0.56, 3.4), "MainLens"),
    ("MintTarget", (0, 0.565, 3.4), "MainLens"),
    *[("Iris%d" % i, (0, 0.5, 3.4), "LensShutter") for i in range(6)],
    ("WeakPoint", (0, 0, 3.4), "LensRoot"),
]


def linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def atlas(signal=False):
    size = 128
    im = bpy.data.images.new("M4_signal_atlas" if signal else "M1_M2_cast_atlas",
                            width=size, height=size, alpha=False)
    pixels = []
    swatches = ["blue", "hazard", "mint", "slate"] if signal else ["bone", "petrol", "charcoal", "charcoal"]
    for y in range(size):
        for x in range(size):
            quadrant = (0 if x < 64 else 1) + (0 if y < 64 else 2)
            noise = ((x * 73 + y * 139 + x * y * 17) % 131) / 131
            wear = 1 if signal else 0.9 + 0.1 * noise
            if not signal and quadrant < 2 and (x * 19 + y * 37) % 257 < 3:
                wear = 0.7
            tint = "charcoal" if signal and quadrant == 1 and (x + y) % 24 < 10 else swatches[quadrant]
            pixels.extend([linear(c) * wear for c in PALETTE[tint]] + [1])
    im.pixels.foreach_set(pixels)
    im.pack()
    return im


def materials():
    result = []
    for name, rough, metal in [("M1_ancient_enamel__M2_dark_joint", 0.68, 0.14),
                              ("M4_signal_surface", 0.45, 0.15), ("M3_glass", 0.12, 0.1)]:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes.get("Principled BSDF")
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
        if len(result) < 2:
            tex = m.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = atlas(signal=len(result) == 1)
            tex.interpolation = "Linear"
            m.node_tree.links.new(tex.outputs["Color"], p.inputs["Base Color"])
            if len(result) == 1:
                m.node_tree.links.new(tex.outputs["Color"], p.inputs["Emission Color"])
                p.inputs["Emission Strength"].default_value = 0.35
        else:
            col = m.node_tree.nodes.new("ShaderNodeVertexColor")
            col.layer_name = "StateColor"
            m.node_tree.links.new(col.outputs["Color"], p.inputs["Base Color"])
            p.inputs["Alpha"].default_value = 0.3
            m.surface_render_method = "BLENDED"
        result.append(m)
    return result


class Mesh:
    def __init__(self):
        self.verts, self.faces, self.tags, self.uvs, self.face_tags = [], [], [], [], []

    def add(self, vertices, faces, bone, slot=0, tint="bone", smooth=False, matrix=None):
        base = len(self.verts)
        matrix = matrix if matrix is not None else Matrix.Identity(4)
        region = {"bone": (0, 0), "petrol": (1, 0), "charcoal": (0, 1)}.get(tint, (0, 0))
        if slot == 1:
            region = {"blue": (0, 0), "hazard": (1, 0), "mint": (0, 1), "slate": (1, 1)}[tint]
        for v in vertices:
            self.verts.append(tuple(matrix @ Vector(v)))
            self.tags.append((bone, tint))
            self.uvs.append(((region[0] + 0.08 + 0.84 * ((v[0] * 0.31 + 0.5) % 1)) / 2,
                             (region[1] + 0.08 + 0.84 * ((v[2] * 0.27 + v[1] * 0.19 + 0.5) % 1)) / 2))
        for face in faces:
            for i in range(1, len(face) - 1):
                self.faces.append(tuple(base + j for j in (face[0], face[i], face[i + 1])))
                self.face_tags.append((slot, tint, smooth))

    def loft(self, rings, n, bone, tint="bone", slot=0, matrix=None, phase=0, smooth=False):
        vertices = [(r * math.cos(phase + i * math.tau / n),
                     r * math.sin(phase + i * math.tau / n), z)
                    for z, r in rings for i in range(n)]
        faces = [tuple(reversed(range(n))), tuple((len(rings) - 1) * n + i for i in range(n))]
        for j in range(len(rings) - 1):
            for i in range(n):
                faces.append((j * n + i, j * n + (i + 1) % n,
                              (j + 1) * n + (i + 1) % n, (j + 1) * n + i))
        self.add(vertices, faces, bone, slot, tint, smooth, matrix)

    def ring(self, center, inner, outer, depth, n, bone, tint="charcoal", slot=0, stripes=False):
        vertices = [(center[0] + r * math.cos(i * math.tau / n), center[1] + y,
                     center[2] + r * math.sin(i * math.tau / n))
                    for y, r in [(-depth / 2, inner), (-depth / 2, outer),
                                 (depth / 2, outer), (depth / 2, inner)] for i in range(n)]
        for j in range(4):
            for i in range(n):
                k = (i + 1) % n
                color = "charcoal" if stripes and i % 2 == 0 else tint
                self.add([vertices[j * n + i], vertices[j * n + k],
                          vertices[((j + 1) % 4) * n + k], vertices[((j + 1) % 4) * n + i]],
                         [(3, 2, 1, 0)], bone, slot, color)

    def sphere(self, center, radius, n, lat, bone):
        vertices = [(center[0], center[1], center[2] + radius)]
        vertices += [(center[0] + radius * math.sin(j * math.pi / lat) * math.cos(i * math.tau / n),
                      center[1] + radius * math.sin(j * math.pi / lat) * math.sin(i * math.tau / n),
                      center[2] + radius * math.cos(j * math.pi / lat))
                     for j in range(1, lat) for i in range(n)]
        bottom = len(vertices)
        vertices.append((center[0], center[1], center[2] - radius))
        faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
        for j in range(lat - 2):
            for i in range(n):
                faces.append((1 + j * n + i, 1 + (j + 1) * n + i,
                              1 + (j + 1) * n + (i + 1) % n, 1 + j * n + (i + 1) % n))
        faces += [(bottom, 1 + (lat - 2) * n + (i + 1) % n, 1 + (lat - 2) * n + i) for i in range(n)]
        self.add(vertices, faces, bone, 2, "glass", True)

    def plate(self, outline, depth, bone, tint="bone", slot=0):
        n = len(outline)
        area = sum(outline[i][0] * outline[(i + 1) % n][2]
                   - outline[i][2] * outline[(i + 1) % n][0] for i in range(n))
        if area < 0:
            outline = list(reversed(outline))
        vertices = [(x, y + d, z) for d in (-depth / 2, depth / 2) for x, y, z in outline]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
        faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        self.add(vertices, faces, bone, slot, tint)

    def object(self, arm, mats):
        mesh = bpy.data.meshes.new("MindHandSkin")
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new("MindHandSkin", mesh)
        bpy.context.collection.objects.link(obj)
        for m in mats:
            mesh.materials.append(m)
        uv = mesh.uv_layers.new(name="CastAtlas")
        colors = mesh.color_attributes.new(name="StateColor", type="FLOAT_COLOR", domain="CORNER")
        for p, (slot, tint, smooth) in zip(mesh.polygons, self.face_tags):
            p.material_index = slot
            p.use_smooth = smooth
            for loop in p.loop_indices:
                uv.data[loop].uv = self.uvs[mesh.loops[loop].vertex_index]
                colors.data[loop].color = (1, 1, 1, 1) if slot < 2 else (*[linear(c) for c in PALETTE[tint]], 1)
        for name, _, _ in BONES:
            indices = [i for i, (bone, _) in enumerate(self.tags) if bone == name]
            group = obj.vertex_groups.new(name=name)
            if indices:
                group.add(indices, 1, "REPLACE")
        obj.parent = arm
        obj.modifiers.new("Rigid cast skin", "ARMATURE").object = arm
        return obj


def rig():
    arm = bpy.data.objects.new("MindHandRig", bpy.data.armatures.new("mind-hand-v1"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at, parent in BONES:
        b = arm.data.edit_bones.new(name)
        b.head = at
        b.tail = Vector(at) + Vector((0, 0.1, 0))
        if parent:
            b.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in arm.pose.bones:
        b.rotation_mode = "XYZ"
    return arm


def geometry():
    m = Mesh()
    m.loft([(-1.8, 1.1), (-1.71, 1.1), (-1.3, 0.5)], 12, "Foot")
    for i, base in enumerate((-1.3, 0.3, 1.9)):
        name = "Segment%d" % i
        m.loft([(base, 0.18), (base + 0.8, 0.165), (base + 1.6, 0.14)], 16, name,
               "petrol" if i == 1 else "bone", phase=math.pi / 16)
        m.plate([(-0.02, -0.19, base + 0.2), (0.02, -0.19, base + 0.2),
                 (0.02, -0.16, base + 1.4), (-0.02, -0.16, base + 1.4)], 0.03, name, "charcoal")
        for k in range(4):
            z = base + 0.32 + k * 0.3
            y = -0.188 + 0.025 * (z - base) / 1.6
            m.plate([(-0.06, y, z - 0.012), (0.06, y, z - 0.012), (0.06, y, z + 0.012),
                     (-0.06, y, z + 0.012)], 0.02, name, "charcoal")
        m.plate([(-0.014, 0.172, base + 0.18), (0.014, 0.172, base + 0.18),
                 (0.014, 0.143, base + 1.42), (-0.014, 0.143, base + 1.42)],
                0.004, name, "blue", 1)
    for i, z in enumerate((0.3, 1.9)):
        transform = Matrix.Translation((0, 0, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        m.loft([(-0.26, 0.22), (0.26, 0.22)], 8, "Segment%d" % (i + 1),
               "charcoal", matrix=transform)
    for side in (-1, 1):
        m.plate([(side * 0.08, 0.36, 4.1), (side * 0.48, 0.36, 3.98),
                 (side * 0.99, 0.52, 3.46), (side * 0.6, 0.52, 3.50)], 0.24, "LensRoot")
        m.plate([(side * 0.48, 0.495, 3.95), (side * 0.503, 0.495, 3.94),
                 (side * 0.955, 0.66, 3.53), (side * 0.93, 0.66, 3.53)],
                0.004, "LensRoot", "blue", 1)
    m.loft([(2.86, 0.165), (2.92, 0.215), (3.06, 0.225), (3.14, 0.19)], 16, "Segment2", "bone",
           phase=math.pi / 16)
    m.ring((0, 0.25, 3.4), 0.57, 0.7, 0.15, 12, "LensRoot")
    m.ring((0, 0.44, 3.4), 0.46, 0.7, 0.07, 12, "LensShutter")
    m.ring((0, 0.49, 3.4), 0.49, 0.69, 0.015, 12, "HazardFace", "hazard", 1)
    for i in range(6):
        a = i * math.tau / 6
        points = [(r * math.cos(a + offset), 0.52, 3.4 + r * math.sin(a + offset))
                  for r, offset in [(0.02, 0), (0.48, -0.12), (0.48, 0.86)]]
        m.plate(points, 0.015, "Iris%d" % i, "charcoal")
    for name, tint in (("SlateTarget", "slate"), ("MintTarget", "mint")):
        y = 0.56 if name == "SlateTarget" else 0.565
        points = [(0.36 * math.cos(i * math.tau / 12), y,
                   3.4 + 0.36 * math.sin(i * math.tau / 12)) for i in range(12)]
        m.add(points, [tuple(reversed(range(12)))], name, 1, tint)
    m.sphere((0, 0, 3.4), 0.7, 12, 6, "MainLens")
    for side, name in ((-1, "SideLensL"), (1, "SideLensR")):
        c = (side * 0.75, -0.2, 3.2)
        m.sphere(c, 0.25, 8, 4, name)
        m.ring((c[0], 0, c[2]), 0.19, 0.25, 0.065, 8, name, "petrol")
    return m


def reset_pose(arm):
    for b in arm.pose.bones:
        b.location = (0, 0, 0)
        b.rotation_euler = (0, 0, 0)
        b.scale = (1, 1, 1)
    arm.pose.bones["HazardFace"].scale = (0.001,) * 3
    arm.pose.bones["MintTarget"].scale = (0.001,) * 3


def pose(arm, bend=0, lens_scale=1, aperture=0, hazard=False, mint=False, broken=0):
    reset_pose(arm)
    p = arm.pose.bones
    p["Segment1"].rotation_euler.x = bend
    end = Vector((0, -math.sin(bend) * 1.6, 0.3 + math.cos(bend) * 1.6))
    vector = Vector((0, 0, 3.5)) - end
    p["Segment2"].location = end - Vector((0, 0, 1.9))
    p["Segment2"].rotation_euler.x = -math.atan2(vector.y, vector.z)
    p["Segment2"].scale.z = vector.length / 1.6
    p["MainLens"].scale = (lens_scale,) * 3
    p["HazardFace"].scale = (1 if hazard else 0.001,) * 3
    p["MintTarget"].scale = (1 if mint else 0.001,) * 3
    p["SlateTarget"].scale = (0.001 if mint else 1,) * 3
    for i in range(6):
        a = i * math.tau / 6
        p["Iris%d" % i].location = (0.24 * aperture * math.cos(a), 0,
                                                0.24 * aperture * math.sin(a))
    if broken:
        p["LensRoot"].location.z = -0.55 * broken
        p["LensRoot"].rotation_euler.x = 0.8 * broken
        p["MainLens"].scale = (max(0.05, 1 - 0.95 * broken),) * 3
        for side, name in ((-1, "SideLensL"), (1, "SideLensR")):
            p[name].location = (side * 0.16 * broken, 0, -0.16 * broken)
            p[name].scale = (1 - 0.75 * broken,) * 3


def actions(arm):
    scene = bpy.context.scene
    scene.render.fps = 30
    arm.animation_data_create()
    keys = {
        "still_track": [(0, {}), (2, {})],
        "quote_warn": [(0, {"hazard": True}), (1.4, {"bend": -0.5, "lens_scale": 1.3, "hazard": True})],
        "exact_strike": [(0, {"bend": -0.5, "lens_scale": 1.3, "hazard": True}),
                         (2 / 30, {"lens_scale": 1.5, "aperture": 1, "hazard": True, "mint": True}),
                         (0.2, {"lens_scale": 1.5, "aperture": 1, "hazard": True, "mint": True})],
        "brace": [(0, {"lens_scale": 1.5, "aperture": 1, "hazard": True, "mint": True}),
                  (5, {"lens_scale": 1.5, "aperture": 1, "hazard": True, "mint": True})],
        "recover": [(0, {"lens_scale": 1.5, "aperture": 1, "mint": True}), (0.4, {}), (3, {})],
        "lens_break": [(0, {}), (0.6, {"broken": 1})],
    }
    for name, rows in keys.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for seconds, values in rows:
            frame = 1 + round(seconds * 30)
            pose(arm, **values)
            for b in arm.pose.bones:
                for prop in ("location", "rotation_euler", "scale"):
                    b.keyframe_insert(prop, frame=frame, group=b.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "CONSTANT" if any(
                                name in curve.data_path for name in ("HazardFace", "MintTarget", "SlateTarget")) else "LINEAR"
    arm.animation_data.action = None
    reset_pose(arm)
    scene.frame_start, scene.frame_end = 1, 151


def glb_stats(path):
    data = path.read_bytes()
    size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + size])
    triangles, vertices, draws = 0, 0, 0
    for mesh in doc["meshes"]:
        for p in mesh["primitives"]:
            triangles += doc["accessors"][p["indices"]]["count"] // 3
            vertices += doc["accessors"][p["attributes"]["POSITION"]]["count"]
            draws += 1
    return {"tris": triangles, "verts": vertices, "draws": draws,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "clips": [a["name"] for a in doc["animations"]]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=SKETCH / "assets/models/bosses/mind_hand.glb")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    common.reset()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    arm = rig()
    obj = geometry().object(arm, materials())
    actions(arm)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="scrapkeep-mhd-") as scratch:
        packed = Path(scratch) / "mind_hand.glb"
        bpy.ops.export_scene.gltf(filepath=str(packed), export_format="GLB", use_selection=True,
            export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
            export_frame_range=False, export_force_sampling=True, export_def_bones=False,
            export_skins=True, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
            export_extras=False, export_cameras=False, export_lights=False)
        common.canonical_indices(str(packed))
        args.out.write_bytes(packed.read_bytes())
    stats = glb_stats(args.out)
    assert 0 < stats["tris"] <= 4000 and stats["verts"] <= 7600 and stats["draws"] == 3, stats
    assert set(stats["clips"]) == set(CLIPS), stats
    print("MHD_EXPORT", json.dumps(stats, sort_keys=True))
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(stats, indent=2) + "\n")


if __name__ == "__main__":
    main()
