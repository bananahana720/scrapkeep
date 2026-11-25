"""Mind's hand: rigid rear cast wrist and exactly three descending fingers.

Blender 5.2.2: blender -b -t 2 --python-exit-code 1 -P <recipe> --
  [--out file.glb] [--render artifacts/local/dress-preview/MWB]
Metres, X toward lens, Y up, Z lateral in the authored coordinates below.
Only the selected mantle is exported. --render reimports that GLB on CPU.

Gloves (2026-10-18): the fingers wear the lost crew's work gloves, canvas backs
with a stitched ridge, pale leather tips and a rolled, frayed cuff band over the
finger roots, vertex colour on the matte "pilot" slot. Polished (POLISH.md).
"""

import math
import json
import struct
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
import cycles_device
import polish
from common import Part

PETROL = common.srgb("petrol")
DUST = common.mix("petrol", "bone", 0.09)
CANVAS = common.mix("sandstone", "petrol", 0.42)
LEATHER = common.mix("sandstone", "bone", 0.5)
STITCH = common.mix("charcoal", "sandstone", 0.3)
GLOVE_SLOT = "pilot"


def xyz(v):
    return (v[0], -v[2], v[1])


def box(part, slot, size, center, color=None):
    return part.box(slot, (size[0], size[2], size[1]), loc=xyz(center), color=color)


def face(part, coords, slot, color=None):
    vertices = [part.bm.verts.new(Vector(xyz(v))) for v in coords]
    return part.paint([part.bm.faces.new(vertices)], slot, color)


def bridge(part, rows, slot, color=None, close_ends=False, smooth=False):
    n = len(rows[0])
    for row, nxt in zip(rows, rows[1:]):
        for k in range(n):
            f = part.bm.faces.new((row[k], nxt[k], nxt[(k + 1) % n], row[(k + 1) % n]))
            f.smooth = smooth
            part.paint([f], slot, color)
    if close_ends:
        part.paint(
            [part.bm.faces.new(list(reversed(rows[0]))), part.bm.faces.new(rows[-1])],
            slot,
            color,
        )


def clipped_stripes(part, polygon, plane):
    """Clip actual .25 m pitch diagonal stripes to a working pad in 2D."""

    def clip(poly, threshold, above):
        result = []
        for a, b in zip(poly, poly[1:] + poly[:1]):
            av, bv = a[0] + a[1], b[0] + b[1]
            ai, bi = (
                (av >= threshold) if above else (av <= threshold),
                (bv >= threshold) if above else (bv <= threshold),
            )
            if ai:
                result.append(a)
            if ai != bi:
                t = (threshold - av) / (bv - av)
                result.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
        return result

    pitch = 0.25 * math.sqrt(2)
    lo = math.floor(min(a + b for a, b in polygon) / pitch * 2)
    hi = math.ceil(max(a + b for a, b in polygon) / pitch * 2)
    for k in range(lo, hi):
        poly = clip(clip(polygon, k * pitch / 2, True), (k + 1) * pitch / 2, False)
        if len(poly) >= 3:
            face(
                part,
                [plane(a, b) for a, b in poly],
                "mantle_tool",
                "hazard" if k % 2 == 0 else "charcoal",
            )


def setup():
    common.reset()
    polish.enable(detail=1, bevel=0.02, edge=0.0, ao_strength=0.35)
    common.SLOTS["mantle_tool"] = {"vc": True, "rough": 0.85}
    common.material("ancient_enamel").node_tree.nodes["Principled BSDF"].inputs[
        "Roughness"
    ].default_value = 0.85


def build():
    setup()
    root = common.empty("MantleHand")
    mount = common.empty("MountBody", parent=root)
    wrist = Part("HandWrist")
    box(wrist, "ancient_enamel", (0.18, 1.0, 2.5), (-3.435, 4.2, 0), PETROL)
    box(wrist, "ancient_enamel", (0.97, 0.18, 2.5), (-2.86, 4.61, 0), DUST)
    box(wrist, "ancient_enamel", (0.815, 0.16, 2.5), (-3.1175, 3.78, 0), PETROL)
    for z in (-1.16, 1.16):
        box(wrist, "ancient_enamel", (0.97, 0.82, 0.18), (-2.86, 4.11, z), PETROL)
    box(wrist, "rubber", (0.012, 0.64, 2.08), (-3.338, 4.19, 0))
    for z in (-1.16, 1.16):
        box(wrist, "rubber", (0.012, 0.74, 0.1), (-2.367, 4.16, z))
        box(wrist, "ancient_light", (0.012, 0.70, 0.05), (-2.36, 4.16, z))
    wrist.to_object(parent=mount)
    fingers = Part("HandThreeFingers")
    for z in (-1.0, 0.0, 1.0):
        rows = []
        for y, depth, width in (
            (1.6, 0.53, 0.46),
            (1.73, 0.65, 0.50),
            (2.12, 0.65, 0.50),
            (3.50, 0.65, 0.50),
            (3.7, 0.48, 0.46),
        ):
            x = -2.95
            d, w, c = depth / 2, width / 2, 0.055
            section = [
                (-d + c, -w),
                (d - c, -w),
                (d, -w + c),
                (d, w - c),
                (d - c, w),
                (-d + c, w),
                (-d, w - c),
                (-d, -w + c),
            ]
            rows.append(
                [
                    fingers.bm.verts.new(Vector(xyz((x + dx, y, z + dz))))
                    for dx, dz in section
                ]
            )
        for j, (lower, upper) in enumerate(zip(rows, rows[1:])):
            for k in range(8):
                if j == 1 and k == 2:
                    continue
                fingers.paint(
                    [
                        fingers.bm.faces.new(
                            (lower[k], upper[k], upper[(k + 1) % 8], lower[(k + 1) % 8])
                        )
                    ],
                    GLOVE_SLOT,
                    LEATHER if j == 0 else CANVAS,
                )
        fingers.paint(
            [fingers.bm.faces.new(list(reversed(rows[0])))], GLOVE_SLOT, LEATHER
        )
        fingers.paint([fingers.bm.faces.new(rows[-1])], GLOVE_SLOT, CANVAS)
        fingers.beam(GLOVE_SLOT, Vector(xyz((-3.285, 2.2, z))), Vector(xyz((-3.285, 3.45, z))),
                     0.05, 0.04, color=STITCH)
        for y in (2.35, 2.75, 3.15):
            fingers.beam(GLOVE_SLOT, Vector(xyz((-3.285, y, z - 0.1))), Vector(xyz((-3.285, y, z + 0.1))),
                         0.03, 0.04, color=STITCH)
        outer = [
            (-2.625, 1.73, z - 0.195),
            (-2.625, 2.12, z - 0.195),
            (-2.625, 2.12, z + 0.195),
            (-2.625, 1.73, z + 0.195),
        ]
        inner = [
            (-2.68, 1.80, z - 0.16),
            (-2.68, 2.05, z - 0.16),
            (-2.68, 2.05, z + 0.16),
            (-2.68, 1.80, z + 0.16),
        ]
        for k in range(4):
            face(
                fingers,
                [outer[k], outer[(k + 1) % 4], inner[(k + 1) % 4], inner[k]],
                GLOVE_SLOT,
                "bone",
            )
        clipped_stripes(
            fingers,
            [(-0.125, -0.16), (0.125, -0.16), (0.125, 0.16), (-0.125, 0.16)],
            lambda a, b, z=z: (-2.677, 1.925 + a, z + b),
        )
    for z in (-1.0, 0.0, 1.0):
        box(fingers, GLOVE_SLOT, (0.72, 0.18, 0.5), (-2.95, 3.52, z), LEATHER)
        for k, dz in enumerate((-0.17, -0.05, 0.07, 0.18)):
            length = 0.1 + 0.04 * ((k * 5 + int(z + 1)) % 3)
            box(fingers, GLOVE_SLOT, (0.03, length, 0.08), (-3.32, 3.43 - length / 2, z + dz), CANVAS)
    fingers.to_object(parent=mount)
    return root


def finish(root, path, cap):
    common.export(root, path)
    data = open(path, "rb").read()
    size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + size])
    for mat in gltf["materials"]:
        if mat["name"] == "mantle_tool":
            mat["pbrMetallicRoughness"]["baseColorFactor"] = [0, 0, 0, 1]
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    binary_chunk = data[20 + size :]
    total = 20 + len(text) + len(binary_chunk)
    open(path, "wb").write(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(text), 0x4E4F534A)
        + text
        + binary_chunk
    )
    counts = [0, 0, 0]
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            counts[0] += gltf["accessors"][primitive["indices"]]["count"] // 3
            counts[1] += gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
            counts[2] += 1
    assert all(0 < actual <= limit for actual, limit in zip(counts, cap)), (counts, cap)
    assert (
        len(gltf["materials"]) <= 5
        and not gltf.get("animations")
        and not gltf.get("skins")
    )
    print(
        "MWB_EXPORT",
        os.path.basename(path),
        "T/V/D",
        counts,
        "M",
        len(gltf["materials"]),
        "rest tools dark",
    )


def preview(path, outdir, name):
    common.reset()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    if name == "choir":
        for side, sign in (("L", -1), ("R", 1)):
            bpy.data.objects["MountArm" + side].location = xyz(
                (0, 0.6075, sign * 0.6075)
            )
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (
        0.25,
        0.28,
        0.30,
        1,
    )
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32, ring_count=16, radius=1, location=xyz((-3.2, 1, 4.1))
    )
    ball = bpy.context.object
    ball.name = "ReferenceBall_2m"
    mat = bpy.data.materials.new("ReferenceSlate")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        0.21,
        0.23,
        0.25,
        1,
    )
    ball.data.materials.append(mat)
    for p in ball.data.polygons:
        p.use_smooth = True
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    plane = bpy.context.object
    floor = bpy.data.materials.new("StudioFloor")
    floor.use_nodes = True
    floor.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        0.13,
        0.15,
        0.16,
        1,
    )
    plane.data.materials.append(floor)
    for label, loc, energy, size in (
        ("Key", (3, -4, 10), 1500, 6),
        ("Fill", (-6, 1, 8), 950, 5),
    ):
        light = bpy.data.lights.new(label, "AREA")
        light.energy, light.shape, light.size = energy, "DISK", size
        obj = bpy.data.objects.new(label, light)
        scene.collection.objects.link(obj)
        obj.location = loc
        obj.rotation_euler = (
            (Vector(xyz((-3.2, 3, 0))) - obj.location)
            .to_track_quat("-Z", "Y")
            .to_euler()
        )
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 9.4
    bpy.context.view_layer.update()
    points = [
        o.matrix_world @ v.co
        for o in scene.objects
        if o.type == "MESH" and o not in (ball, plane)
        for v in o.data.vertices
    ]
    os.makedirs(outdir, exist_ok=True)
    for state in ("closed", "charge"):
        if state == "charge":
            tool = bpy.data.materials["mantle_tool"]
            bsdf = tool.node_tree.nodes.get("Principled BSDF")
            attr = tool.node_tree.nodes.new("ShaderNodeVertexColor")
            attr.layer_name = "Color"
            tool.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
            tool.node_tree.links.new(
                attr.outputs["Color"], bsdf.inputs["Emission Color"]
            )
            bsdf.inputs["Emission Strength"].default_value = 0.5
        for label, offset in (
            ("front", (14, 0, 0)),
            ("side", (0, -14, 0)),
            ("three-quarter", (11, -11, 5)),
        ):
            direction = Vector(offset)
            right = Vector((-direction.y, direction.x, 0)).normalized()
            lo = min(p.dot(right) for p in points)
            hi = max(p.dot(right) for p in points)
            base = Vector((-3.2, 0, 1))
            ball.location = base + right * (hi + 1.65 - base.dot(right))
            target = Vector((-3.2, 0, 3.1))
            target += right * ((lo + hi + 2.65) / 2 - target.dot(right))
            cam.location = target + direction
            cam.rotation_euler = (
                (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            )
            scene.render.filepath = os.path.join(
                outdir, name + "_" + state + "_" + label + ".png"
            )
            bpy.ops.render.render(write_still=True)
    print(
        "MWB_PREVIEW",
        name,
        "Cycles " + bpy.context.scene.cycles.device + " 12 samples; 2m ball; 3 views per closed/charge state",
    )


if __name__ == "__main__":
    options = common.args()
    output = options["out"] or common.default_out("warden_mantle_hand")
    root = build()
    assert common.tri_total(root) <= 6000
    finish(root, output, (6000, 11200, 5))
    if options["render"]:
        preview(output, options["render"], "hand")
