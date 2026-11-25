import json
import math
import os
import sys
import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(HERE, "..", "..", "..", "assets", "models")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(MODELS, "world_one")
TALL = 1.4
TOP = 1.02


def lin(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


SOURCE = {"fur": lin("a99a84"), "belly": lin("c4b8a2"), "hat": lin("a48f55"), "band": lin("6e5734"), "mitt": lin("8f6b4c"),
          "tail": lin("7d6450"), "nose": lin("3b302a")}
ORANGE, BRASS = lin("e8742a"), lin("c9a24a")
DRESS = {"hat": ORANGE, "band": BRASS}


def nearest(c):
    n = math.sqrt(sum(x * x for x in c)) or 1.0
    best, gap = None, 9.0
    for name, ref in SOURCE.items():
        rn = math.sqrt(sum(x * x for x in ref))
        d = sum((c[k] / n - ref[k] / rn) ** 2 for k in range(3))
        if d < gap:
            best, gap = name, d
    return best


def write(source, name, filename):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, "bosses", "arena_bowl_yard.glb"))
    ob = bpy.data.objects[source]
    for other in [o for o in bpy.data.objects if o is not ob]:
        bpy.data.objects.remove(other, do_unlink=True)
    me = ob.data
    me.transform(ob.matrix_world)
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    if len(me.color_attributes) != 1 or me.color_attributes[0].domain != "CORNER":
        raise SystemExit(source + " must carry exactly one per-corner colour layer")
    if "paint" not in [m.name for m in me.materials]:
        raise SystemExit(source + " has no material named paint")
    skin = [m.name for m in me.materials].index("paint")
    old = me.color_attributes[0]
    old_name = old.name
    shaded = [tuple(d.color[:3]) for d in old.data]
    new = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for li, c in enumerate(shaded):
        new.data[li].color = (*c, 1.0)
    slope = Vector((0.0, -0.85, 1.0)).normalized()
    mid = Vector((0.0, 0.0, 0.68))
    half = 0.07 / math.sqrt(1.0 + 0.85 * 0.85)
    bm = bmesh.new(); bm.from_mesh(me)
    cl = bm.loops.layers.float_color["Col"]

    def paint_of(f):
        return nearest([sum(lp[cl][k] for lp in f.loops) / len(f.loops) for k in range(3)])

    def trunk(f):
        return f.material_index == skin and paint_of(f) in ("fur", "belly")

    def wears_sash(f):
        return trunk(f) and 0.3 < f.calc_center_median().z < TOP

    up = Vector((0.0, 0.0, 1.0))
    for point, normal in ((mid + slope * half, slope), (mid - slope * half, slope), (up * TOP, up)):
        faces = [f for f in bm.faces if trunk(f) and 0.2 < f.calc_center_median().z < TOP + 0.2]
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=point, plane_no=normal)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    for f in bm.faces:
        paint = paint_of(f)
        target = DRESS.get(paint)
        if wears_sash(f) and abs((f.calc_center_median() - mid).dot(slope)) < half:
            target = ORANGE
        if target:
            for lp in f.loops:
                k = min(1.3, lum(lp[cl]) / lum(SOURCE[paint]))
                lp[cl] = (*(min(1.0, t * k) for t in target), 1.0)
    bm.to_mesh(me); bm.free()
    me.color_attributes.remove(me.color_attributes[old_name])
    me.color_attributes.active_color = me.color_attributes[0]
    me.color_attributes.render_color_index = 0
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    for poly in me.polygons:
        poly.material_index = 0
    me.materials.clear()
    paint = bpy.data.materials.new("paint"); paint.use_backface_culling = False; paint.diffuse_color = (1, 1, 1, 1)
    me.materials.append(paint)
    top = max(v.co.z for v in me.vertices)
    low = min(v.co.z for v in me.vertices)
    s = TALL / (top - low)
    me.transform(Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -low)))
    ob.name = name; me.name = name
    root = bpy.data.objects.new(name + "Root", None); bpy.context.scene.collection.objects.link(root); ob.parent = root
    path = os.path.join(out, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    xs = [v.co for v in me.vertices]
    size = [round(max(c[k] for c in xs) - min(c[k] for c in xs), 2) for k in range(3)]
    print("POI " + json.dumps({"out": filename, "tris": len(me.polygons), "verts": len(me.vertices), "size_m": size, "scale": round(s, 3)}))


write("CrewFan", "ParadeCrewCheer", "poi_parade_crew_cheer.glb")
write("CrewPennant", "ParadeCrewStandard", "poi_parade_crew_standard.glb")
