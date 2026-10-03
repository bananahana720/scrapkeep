"""LKR cliff recipe and shared landform authoring/CPU-preview helpers.

Blender uses Z up internally; common.export writes metre-scale Y-up glTF.
Run: blender -b --factory-startup -P this.py -- --render /path/to/renders
The two tile boundaries are invariant under a half-turn about vertical.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common

NAME = "cliff_strata"
SAND = common.srgb("sandstone")
BUFF = common.mix("sandstone", "bone", 0.45)
RED = common.mix("sandstone", "oxide", 0.38)
VARNISH = common.mix("sandstone", "charcoal", 0.74)


def blend(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def face(part, verts, tone=SAND, smooth=False):
    f = part.bm.faces.new(verts)
    part.paint([f], "paint", tone)
    f.smooth = smooth
    return f


def loft(part, rows, tones, smooth=False, cap=True):
    rings = [[part.bm.verts.new(v) for v in row] for row in rows]
    n = len(rings[0])
    for k in range(len(rings) - 1):
        for j in range(n):
            a, b = rings[k], rings[k + 1]
            face(part, [a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]],
                 tones[k % len(tones)], smooth)
    if cap:
        face(part, list(reversed(rings[0])), tones[0])
        face(part, rings[-1], tones[-1])
    return rings


def finish(part):
    bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
    obj = part.to_object()
    # Split normals at ledges and fracture corners, retaining weathered-face smoothing.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for f in list(bm.faces):
        a, b, c = [v.co for v in f.verts]
        if (b - a).cross(c - a).length < 1e-8:
            bm.faces.remove(f)
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle() < math.radians(32)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def block(name, size, seed, tone=SAND):
    """Unequal clipped rectangular rings: flat bedding, planar broken sides."""
    rng = random.Random(seed)
    p = common.Part(name)
    outline = [(-0.5, -0.29), (-0.32, -0.5), (0.28, -0.5), (0.5, -0.24),
               (0.5, 0.32), (0.25, 0.5), (-0.36, 0.5), (-0.5, 0.23)]
    outline = [(x + rng.uniform(-0.075, 0.075), y + rng.uniform(-0.075, 0.075))
               for x, y in outline]
    rows = []
    for k, (z, scale) in enumerate([(0, 0.93), (0.07, 1), (0.92, 0.97), (1, 0.86)]):
        row = []
        for x, y in outline:
            row.append((x * scale + (rng.uniform(-0.025, 0.025) if k else 0),
                        y * scale + (rng.uniform(-0.025, 0.025) if k else 0), z))
        rows.append(row)
    loft(p, rows, [blend(tone, RED, 0.08), tone, blend(tone, BUFF, 0.2)])
    for axis in range(3):
        lo = min(v.co[axis] for v in p.bm.verts)
        span = max(v.co[axis] for v in p.bm.verts) - lo
        for v in p.bm.verts:
            v.co[axis] = ((v.co[axis] - lo) / span - (0.5 if axis < 2 else 0)) * size[axis]
    return finish(p)


def attach(root, obj, loc=(0, 0, 0)):
    obj.parent = root
    obj.location = loc
    return obj


def fit(root, size):
    objects = [o for o in common.tree(root) if o.type == "MESH"]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo = [min(v[i] for v in pts) for i in range(3)]
    hi = [max(v[i] for v in pts) for i in range(3)]
    for o in objects:
        mw = o.matrix_world.copy()
        o.location = (0, 0, 0)
        o.rotation_euler = (0, 0, 0)
        o.scale = (1, 1, 1)
        for v in o.data.vertices:
            w = mw @ v.co
            v.co = [(w[i] - lo[i]) * size[i] / (hi[i] - lo[i]) -
                    (size[i] / 2 if i < 2 else 0) for i in range(3)]


def bounds(root):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in common.tree(root) if o.type == "MESH"
           for v in o.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def stage():
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = 24
    s.cycles.use_denoising = True
    s.cycles.seed = 271002
    s.cycles.max_bounces = 5
    s.render.threads_mode = "FIXED"
    s.render.threads = 8
    s.render.resolution_x = 1280
    s.render.resolution_y = 720
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = "PNG"
    s.view_settings.view_transform = "AgX"
    s.world = bpy.data.worlds.new("LKR_preview_world")
    s.world.use_nodes = True
    bg = s.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.66, 0.73, 0.8, 1)
    bg.inputs["Strength"].default_value = 0.32
    bpy.ops.mesh.primitive_plane_add(size=600)
    bpy.context.object.name = "preview_ground"
    bpy.context.object.data.materials.append(common._flat("preview_sand", "bone"))
    sun = bpy.data.lights.new("preview_sun_40deg", "SUN")
    sun.energy = 2.6
    sun.color = (1.0, 0.83, 0.65)
    sun.angle = math.radians(3)
    ob = bpy.data.objects.new(sun.name, sun)
    s.collection.objects.link(ob)
    # Rays descend at 40 degrees above the horizon, from camera-left.
    ray = Vector((0.58, 0.50, -math.tan(math.radians(40)) * math.hypot(0.58, 0.50)))
    ob.rotation_euler = ray.to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.new("preview_camera", bpy.data.cameras.new("preview_camera"))
    s.collection.objects.link(cam)
    s.camera = cam
    cam.data.type = "ORTHO"
    return cam


def sphere(x, y):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1,
                                      location=(x, y, 1))
    o = bpy.context.object
    o.name = "preview_2m_sphere"
    o.data.materials.append(common._flat("preview_scale_sphere", "bone"))
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def preview(root, name, outdir):
    lo, hi = bounds(root)
    cam = stage()
    sphere(hi.x + 2, lo.y - 1.2)
    center = Vector(((lo.x + hi.x + 3) / 2, 0, hi.z * 0.44))
    span = hi - lo
    width = max(span.x + 7, span.z * 1.777 + 6, span.y + 7) * 1.16
    cam.data.ortho_scale = width
    os.makedirs(outdir, exist_ok=True)
    for label, direction in [("front", Vector((0, -1, 0.20))),
                             ("three-quarter", Vector((0.72, -1, 0.43)))]:
        cam.location = center + direction.normalized() * width * 2
        common._look(cam, center)
        bpy.context.scene.render.filepath = os.path.join(outdir, name + "-" + label + ".png")
        bpy.ops.render.render(write_still=True)


def deliver(build, name):
    common.reset()
    root = build()
    lo, hi = bounds(root)
    count = common.tri_total(root)
    assert count <= (20000 if name == "boulders" else 8000), (name, count)
    print("LKR_GEOMETRY", name, "triangles", count, "Zup_size", list(hi - lo), flush=True)
    a = common.args()
    out = a["out"] or os.path.join(common.MODELS, "world_one", "landforms", name + ".glb")
    common.export(root, out)
    if a["render"]:
        if name == "boulders":
            arrange_boulders(root)
        preview(root, name, a["render"])


def arrange_boulders(root):
    for i, ob in enumerate(root.children):
        ob.location = ((i % 5 - 2) * 4.8, (i // 5 - 0.5) * 5.0, 0)


def build():
    root = common.empty(NAME)
    p = common.Part("cliff_strata_rock")
    xs = [-12, -11, -9.3, -7.5, -6.2, -6.05, -5.9, -4.4, -2.5,
          -0.2, 2.35, 2.5, 2.65, 4.7, 6.6, 8.15, 8.3, 8.45, 10.4, 11.3, 12]
    # Four thick beds, not a pile of rounded primitives. Thin basal recesses leave
    # genuine undercuts beneath the harder upper lip of each bed.
    rows, tones = [], []
    beds = [(0, 6, 4.1, BUFF), (6, 13.5, 3.45, RED),
            (13.5, 18, 2.7, BUFF), (18, 26, 1.95, SAND)]
    for bed, (bottom, top, radius, tone) in enumerate(beds):
        zs = [bottom, bottom + 0.23, bottom + 0.7]
        zs += [bottom + 0.7 + (top - bottom - 0.95) * i / 8 for i in range(1, 9)]
        zs += [top]
        for k, z in enumerate(zs):
            undercut = 0.58 if k == 0 else 0.48 if k == 1 else 0
            row = []
            for sign, seq in [(-1, xs), (1, list(reversed(xs)))]:
                for x in seq:
                    envelope = 0 if abs(x) >= 11.3 else math.sin(math.pi * (x + 12) / 24) ** 2
                    joint = (0.68 + 0.32 * math.sin(z * 0.73 + x)) if x in (-6.05, 2.5, 8.3) else 0
                    rough = envelope * (0.72 * math.sin(x * 1.1 + bed * 1.3) +
                                        0.16 * math.sin(z * 1.1 + x * 0.7))
                    r = radius - undercut - envelope * joint + rough
                    xx = x + envelope * 0.18 * math.sin(z * 0.65 + bed)
                    zz = z - (0.24 * envelope if z == 26 else 0)
                    row.append((xx, sign * r, zz))
            rows.append(row)
            tones.append(blend(tone, BUFF, 0.14 + 0.08 * math.sin(z * 5)))
    loft(p, rows, tones, smooth=True)
    for f in p.bm.faces:
        for loop in f.loops:
            x, y, z = loop.vert.co
            bed = next((b for b in beds if z <= b[1] + 0.00001), beds[-1])
            phase = z * 6.4 + 0.44 * x + 0.30 * math.sin(x * 1.2)
            tint = blend(bed[3], BUFF, 0.12 + 0.18 * ((math.cos(phase) + 1) / 2) ** 5)
            joint_shade = 0.12 if min(abs(x - h - 0.18 * math.sin(z * 0.65 + beds.index(bed))) for h in (-6.05, 2.5, 8.3)) < 0.12 else 0
            loop[p.col] = common.rgba(blend(tint, VARNISH, joint_shade))
    attach(root, finish(p))
    for i in range(17):
        rng = random.Random(613 + i)
        size = (rng.uniform(0.8, 2.2), rng.uniform(0.6, 1.4), rng.uniform(0.35, 1.1))
        ob = block("talus_%02d" % i, size, 800 + i, blend(SAND, BUFF, i % 3 / 3))
        ob.rotation_euler.z = rng.uniform(-0.6, 0.6)
        x = -10 + i * 1.22 + 0.24 * math.sin(i * 1.9)
        y = -4.25 - (i % 3) * 0.18 + 0.44 * math.sin(i * 1.8)
        attach(root, ob, (x, y, 0))
        rear = bpy.data.objects.new("rear_talus_%02d" % i, ob.data.copy())
        bpy.context.scene.collection.objects.link(rear)
        rear.rotation_euler.z = math.pi + ob.rotation_euler.z
        attach(root, rear, (-x, -y, 0))
    fit(root, (24, 10, 26))
    return root


def kit_sheet(outdir):
    import importlib
    common.reset()
    names = [NAME, "wave_dome", "fin_spire", "alcove", "mesa_cap", "boulders"]
    cursor = -79.0
    for name in names:
        root = build() if name == NAME else importlib.import_module(name).build()
        if name == "boulders":
            arrange_boulders(root)
        lo, hi = bounds(root)
        width = hi.x - lo.x
        x = cursor + width / 2
        root.location.x = x
        cursor += width + 5
        curve = bpy.data.curves.new("label_" + name, "FONT")
        curve.body = name.replace("_", " ")
        curve.align_x = "CENTER"
        curve.size = 1.45
        text = bpy.data.objects.new(curve.name, curve)
        bpy.context.scene.collection.objects.link(text)
        text.location = (x, -5, 29)
        text.rotation_euler.x = math.pi / 2
        curve.materials.append(common._flat("label_ink_" + name, "charcoal"))
    cam = stage()
    sphere(-82, -8)
    center_x = (-79 + cursor - 5) / 2
    cam.data.ortho_scale = cursor + 79 + 10
    cam.location = (center_x, -220, 69)
    common._look(cam, (center_x, 0, 14))
    bpy.context.scene.render.filepath = os.path.join(outdir, "kit-sheet.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        kit_sheet(common.args()["render"])
    else:
        deliver(build, NAME)
