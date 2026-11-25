"""MWA: rigid reactor add-on, metres; X-forward/Y-up converted to Blender Z-up.

Run: blender -b --factory-startup --threads 2 --python-exit-code 1 --python
sketches/core-loop/tools/blender/warden_mantle_meltdown.py -- [--out file.glb]
Only --render DIR renders: reimports the actual GLB, Cycles CPU, three views.
No original kit, gameplay, loader, collider or animation is exported.
"""
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

HERE = Path(__file__).resolve().parent
HELPERS = HERE if (HERE / "common.py").exists() else Path.cwd() / "sketches/core-loop/tools/blender"
sys.path.insert(0, str(HELPERS))
import common
import cycles_device
import polish

polish.enable(detail=2, bevel=0.03, bevel_angle=46.0, edge=0.0, ao_strength=0.35)

ENAMEL = "365754"
UV_PITCH = .25 * math.sqrt(2)
VENTS = [(-.746009, 1.9575, -1.043205), (-1.2825, 1.9575, 0), (-.746009, 1.9575, 1.043205)]


def xyz(v):
    return Vector((v[0], -v[2], v[1]))


def setup():
    common.reset()
    common.SLOTS["mantle_tool"] = {"color": "charcoal", "rough": .9}
    mat = common.material("mantle_tool")
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    image = bpy.data.images.new("MantleStripes025m", width=128, height=128)
    pixels = []
    for y in range(128):
        for x in range(128):
            color = "hazard" if ((x + y) % 128) < 64 else "charcoal"
            pixels.extend((*common.srgb(color), 1))
    image.pixels.foreach_set(pixels)
    image.pack()
    tex.image = image
    tex.extension = "REPEAT"
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 1
    mat.node_tree.links.new(tex.outputs["Color"], multiply.inputs[1])
    multiply.inputs[2].default_value = (.004, .004, .004, 1)
    mat.node_tree.links.new(multiply.outputs[0], nodes.get("Principled BSDF").inputs["Base Color"])


def face(part, points, slot, color=None, uvs=None):
    verts = [part.bm.verts.new(xyz(p)) for p in points]
    f = part.bm.faces.new(verts)
    part.paint([f], slot, color)
    if uvs is not None:
        uv = part.bm.loops.layers.uv.verify()
        for loop, value in zip(f.loops, uvs):
            loop[uv].uv = value
    return f


def strip(part, rings, slots, colors, closed=False, uv_length=None):
    """Connected profile sweep, fixed winding and face order, no primitive stacking."""
    verts = []
    for row in rings:
        cache = {}
        made = []
        for v in row:
            key = tuple(v)
            if key not in cache:
                cache[key] = part.bm.verts.new(xyz(v))
            made.append(cache[key])
        verts.append(made)
    uv = part.bm.loops.layers.uv.verify()
    for k in range(len(rings) if closed else len(rings) - 1):
        nxt = (k + 1) % len(rings)
        for j in range(len(rings[0]) - 1):
            f = part.bm.faces.new((verts[k][j], verts[nxt][j], verts[nxt][j+1], verts[k][j+1]))
            part.paint([f], slots[j], colors[j])
            if slots[j] == "mantle_tool":
                for loop, (u, v) in zip(f.loops, ((k, rings[k][j][1]), (k+1, rings[nxt][j][1]),
                                                (k+1, rings[nxt][j+1][1]), (k, rings[k][j+1][1]))):
                    loop[uv].uv = (u * uv_length / UV_PITCH, v / UV_PITCH)


def box(part, slot, size, center, color=None):
    return part.box(slot, (size[0], size[2], size[1]), loc=xyz(center), color=color)


def finish(part, parent):
    bmesh.ops.remove_doubles(part.bm, verts=list(part.bm.verts), dist=.000001)
    bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    return part.to_object(parent=parent)


def make_shell(parent):
    p = common.Part("MeltRearShell")
    rings = []
    steps = 7
    for k in range(steps + 1):
        a = math.radians(55) + math.radians(250) * k / steps
        ca, sa = math.cos(a), math.sin(a)
        rings.append([(-.55 + 1.35*r*ca, h, 1.70*r*sa)
                      for r, h in ((1, .925), (1, 1.125), (.72, 1.60), (.28, 1.775), (.28, 1.675), (.91, .925), (1, .925))])
    strip(p, rings, ["ancient_enamel"]*6, [ENAMEL]*6)
    for row in (rings[0][:-1], list(reversed(rings[-1][:-1]))):
        face(p, row, "rubber")
    for slot, lo, hi, offset in (("rubber", 1.30, 1.40, .008), ("ancient_light", 1.325, 1.375, .012)):
        for k in range(6):
            points = []
            for a, h in ((135+90*k/6, lo), (135+90*(k+1)/6, lo),
                         (135+90*(k+1)/6, hi), (135+90*k/6, hi)):
                r = 1 - .28*(h-1.125)/.475 + offset
                points.append((-.55+1.35*r*math.cos(math.radians(a)), h,
                               1.70*r*math.sin(math.radians(a))))
            face(p, points, slot)
    bmesh.ops.recalc_face_normals(p.bm, faces=list(p.bm.faces))
    upper = [f for f in p.bm.faces if f.material_index == p.slots.index("ancient_enamel")
             and f.normal.z > .6 and f.calc_center_median().z > 1.5]
    for f in upper[1::3][:3]:
        p.paint([f], "ancient_enamel", common.mix("petrol", "bone", .42))
    p.bm.faces.ensure_lookup_table()
    host = p.bm.faces[1]
    a, b, c, d = [v.co.copy() for v in host.verts]
    across = (b-a).normalized()*.012
    path = []
    for u, v in ((.65, .05), (.4, .48), (.58, .92)):
        path.append((a*(1-u)+b*u)*(1-v)+(d*(1-u)+c*u)*v+host.normal*.004)
    for start, end in zip(path, path[1:]):
        f = p.bm.faces.new([p.bm.verts.new(point) for point in
                            (start-across, start+across, end+across, end-across)])
        p.paint([f], "rubber")
    obj = finish(p, parent)
    return obj


def make_bell(index, parent):
    p = common.Part("MeltVentBell%d" % index)
    segments = 10
    inner = .3 / math.cos(math.pi / segments)
    profile = [(.44, -.025), (.475, 1.425), (.475, 1.475), (.44, 1.525),
               (inner+.035, 1.525), (inner, 1.49), (inner, 1.425), (inner, -.025), (.44, -.025)]
    rings = []
    for k in range(segments):
        a = math.tau * k / segments
        rings.append([(r*math.cos(a), y, r*math.sin(a)) for r, y in profile])
    strip(p, rings, ["ancient_enamel"]*5 + ["rubber", "mantle_tool", "rubber"],
          [ENAMEL]+["bone"]*4 + [None, None, None], closed=True,
          uv_length=2*inner*math.sin(math.pi/segments))
    obj = finish(p, parent)
    for poly in obj.data.polygons:
        poly.use_smooth = poly.material_index == p.slots.index("mantle_tool")
    return obj


def export_checked(root, path, ceiling):
    common.export(root, str(path))
    data = Path(path).read_bytes()
    n = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20+n])
    # Blender's multiply-node exporter preserves the texture but drops its scalar.
    tool = next(m for m in g["materials"] if m["name"] == "mantle_tool")
    tool["pbrMetallicRoughness"]["baseColorFactor"] = [.004, .004, .004, 1]
    encoded = json.dumps(g, separators=(",", ":"), ensure_ascii=False).encode()
    encoded += b" " * (-len(encoded) % 4)
    rest = data[20+n:]
    data = (struct.pack("<III", 0x46546c67, 2, 20+len(encoded)+len(rest))
            + struct.pack("<II", len(encoded), 0x4e4f534a) + encoded + rest)
    Path(path).write_bytes(data)
    tris = verts = draws = 0
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            tris += g["accessors"][prim["indices"]]["count"] // 3
            verts += g["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    assert 0 < tris <= ceiling[0] and verts <= ceiling[1] and draws <= ceiling[2], (tris, verts, draws)
    assert len(g["materials"]) <= 5 and not g.get("animations") and not g.get("skins")
    assert "baseColorTexture" in tool["pbrMetallicRoughness"], "striped tool texture was not exported"
    print("MWA_EXPORT %s T=%d V=%d D=%d M=%d SHA256=%s" %
          (Path(path).name, tris, verts, draws, len(g["materials"]), hashlib.sha256(data).hexdigest()))


def preview(path, outdir, family, label):
    """Preview the reimported standalone GLB, with mounts posed at source sockets."""
    common.reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    if family == "reactor":
        for i, at in enumerate(VENTS):
            bpy.data.objects["MountVent%d" % i].location = xyz(at)
    bpy.context.view_layer.update()
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    min_y = min((o.matrix_world @ v.co).z for o in objects for v in o.data.vertices)
    for o in [o for o in bpy.context.scene.objects if o.parent is None]:
        o.location.z -= min_y
    bpy.context.view_layer.update()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=(0, -4.1, 1))
    ball = bpy.context.object
    ball.name = "ReferenceBall2m"
    ball.data.materials.append(common.material("bare_metal"))
    for poly in ball.data.polygons:
        poly.use_smooth = True
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.015))
    ground = bpy.context.object
    ground.data.materials.append(common.material("rubber"))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.cycles.denoising_use_gpu = False
    scene.cycles.seed = 0
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("MWAStudio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.42, .48, .53, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55
    scene.world = world
    for name, at, power, size in (("Key", (6, -5, 9), 1800, 7), ("Fill", (-4, 3, 7), 1300, 6)):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = size
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = at
        common._look(obj, (-.5, -1.4, 1.7))
    cam = bpy.data.objects.new("MWACamera", bpy.data.cameras.new("MWACamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 8.8
    centre = Vector((-.45, 0, 1.6))
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    revision = hashlib.sha256(Path(path).read_bytes()).hexdigest()[:8]
    for name, direction in (("front", (12, 0, 1.5)), ("side", (0, -12, 1.5)), ("three-quarter", (10, -10, 5))):
        right = Vector((direction[1], -direction[0], 0)).normalized()
        ball.location = Vector((centre.x, centre.y, 1)) + right*4
        target = centre + right*1.5
        cam.location = target + Vector(direction)
        common._look(cam, target)
        scene.render.filepath = str(outdir / (label + "-" + revision + "-" + name + ".png"))
        bpy.ops.render.render(write_still=True)
    print("MWA_PREVIEW %s CPU samples=12 views=3 reference_ball_diameter=2m" % label)


def main():
    setup()
    root = common.empty("MantleMeltdown")
    mount = common.empty("MountBody", parent=root)
    make_shell(mount)
    for i in range(3):
        make_bell(i, common.empty("MountVent%d" % i, parent=root))
    opts = common.args()
    path = opts["out"] or common.default_out("warden_mantle_meltdown")
    export_checked(root, path, (1000, 1600, 12))
    if opts["render"]:
        preview(path, opts["render"], "reactor", "meltdown")


if __name__ == "__main__":
    main()
