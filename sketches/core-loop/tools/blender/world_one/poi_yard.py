# Two thin point of interest props for world 1, built by hand because a mesh generator returns thin shapes as lumps:
#   poi_fence_panel.glb   one repeatable stocktake yard fence panel, 6 m wide and 2.5 m tall: two scrap posts on
#                         concrete feet, a top and a bottom rail, and a diamond lattice standing in for chain-link.
#                         The origin is on the ground at the panel's centre; it runs along X, so panels butt post to post.
#   poi_survey_stake.glb  one survey stake, 3.2 m tall: a slim post, a striped cap and a stiff pennant, bright enough to
#                         read at speed against brown concrete and sand. One rigid mesh, origin at the foot, so the
#                         game can knock it flat by turning it about its origin.
# Each is one mesh on one material named paint with linear COLOR_0 and no texture, as the park props and the Tripo props
# (tools/tripo/tripo_prop.py) are; the loader sets vertex colour as albedo. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y).
#
#   blender -b --factory-startup --python-exit-code 1 -P sketches/core-loop/tools/blender/world_one/poi_yard.py -- [--out DIR]
import json
import math
import os
import sys
import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "world_one")

# sRGB picks from the Fleet set (STORY-MAP section 3): petrol-green enamel, charcoal, concrete, one warning orange, bone white
def lin(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

GREEN, CHAR, CONC, ORANGE, BONE, WIRE = lin("3f6f68"), lin("2e3033"), lin("8d8a84"), lin("e8742a"), lin("ece4d2"), lin("9aa3a6")


def box(bm, col, size, at, rot=None):
    m = Matrix.Translation(Vector(at)) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    geo = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    cl = bm.loops.layers.float_color.verify()
    for f in {f for v in geo["verts"] for f in v.link_faces}:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


def cylinder(bm, col, radius, height, at, sides=8):
    geo = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=height,
                                matrix=Matrix.Translation(Vector((at[0], at[1], at[2] + height / 2))))
    cl = bm.loops.layers.float_color.verify()
    for f in {f for v in geo["verts"] for f in v.link_faces}:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


def write(name, build):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new(); build(bm)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    paint = bpy.data.materials.new("paint"); paint.use_backface_culling = False; paint.diffuse_color = (1, 1, 1, 1); me.materials.append(paint)
    me.color_attributes.active_color = me.color_attributes[0]; me.color_attributes.render_color_index = 0
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    root = bpy.data.objects.new(name + "Root", None); bpy.context.scene.collection.objects.link(root); ob.parent = root
    path = os.path.join(out, {"FencePanel": "poi_fence_panel.glb", "SurveyStake": "poi_survey_stake.glb"}[name])
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    xs = [v.co for v in me.vertices]
    size = [round(max(c[k] for c in xs) - min(c[k] for c in xs), 2) for k in range(3)]
    print("POI " + json.dumps({"out": os.path.basename(path), "tris": len(me.polygons), "verts": len(me.vertices), "size_m": size}))


def fence(bm):
    W, H = 6.0, 2.5
    for sx in (-1, 1):  # a post at each end, half on this panel, so two panels share one post's width
        box(bm, CONC, (0.5, 0.5, 0.25), (sx * (W / 2 - 0.15), 0, 0.125))
        box(bm, GREEN, (0.22, 0.22, H), (sx * (W / 2 - 0.15), 0, H / 2))
        box(bm, ORANGE, (0.26, 0.26, 0.14), (sx * (W / 2 - 0.15), 0, H - 0.2))
    box(bm, CHAR, (W - 0.5, 0.1, 0.1), (0, 0, H - 0.35))
    box(bm, CHAR, (W - 0.5, 0.1, 0.1), (0, 0, 0.35))
    # the lattice: bars leaning both ways between the rails, thick enough to read as mesh from the chase camera
    lo, hi = 0.4, H - 0.4
    span = hi - lo
    n = 9
    for k in range(n):
        x0 = -W / 2 + 0.4 + (W - 0.8) * k / (n - 1)
        for lean in (-1, 1):
            x1 = x0 + lean * span
            a, b = max(-W / 2 + 0.3, min(W / 2 - 0.3, x1)), x0
            top = lo + abs(a - b)  # a bar that would leave the panel stops at the post
            length = math.hypot(a - b, top - lo)
            if length < 0.3:
                continue
            ang = math.atan2(top - lo, a - b)
            box(bm, WIRE, (length, 0.04, 0.05), ((a + b) / 2, 0, (lo + top) / 2), Matrix.Rotation(-ang, 4, "Y"))


def stake(bm):
    cylinder(bm, CONC, 0.16, 0.12, (0, 0, 0))
    cylinder(bm, BONE, 0.045, 2.6, (0, 0, 0.1), 6)
    for k in range(4):  # the striped cap: four bands, orange and bone, so it reads as a marker at speed
        cylinder(bm, ORANGE if k % 2 == 0 else BONE, 0.11, 0.14, (0, 0, 2.6 + 0.14 * k))
    # a stiff pennant, one wedge thick enough to show from behind
    cl = bm.loops.layers.float_color.verify()
    pts = [Vector((0.05, y, z)) for y in (-0.02, 0.02) for z in (3.16, 2.72)] + [Vector((0.72, y, 2.94)) for y in (-0.02, 0.02)]
    vs = [bm.verts.new(p) for p in pts]
    for idx in ((0, 1, 4), (2, 5, 3), (0, 4, 5, 2), (1, 3, 5, 4), (0, 2, 3, 1)):
        f = bm.faces.new([vs[i] for i in idx])
        for lp in f.loops:
            lp[cl] = (*ORANGE, 1.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


write("FencePanel", fence)
write("SurveyStake", stake)
