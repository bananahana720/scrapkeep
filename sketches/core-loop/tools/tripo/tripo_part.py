"""Fit an untextured Tripo mesh as a ball part's own shape (src/build/accretion.gd PART_GLB).

blender -b --factory-startup -P tripo_part.py -- --in tripo.glb --out part_<id>_tripo.glb [--max-tris 1000] [--tall 0.65] [--wide 0.6] [--cut-above 0.6] [--touch 0.02]

Joins the mesh, welds seam splits, drops floating fragments, decimates to --max-tris, scales it uniformly to sit inside
--wide across and --tall high, stands its base on the origin, drops materials, UVs and colours
(the game paints the part in its rarity colour), and exports one mesh named Part.
Prints one JSON line with counts.
"""
import json, sys
import bpy, bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"max-tris": "1000", "tall": "0.65", "wide": "0.6", "cut-above": "1.0", "touch": "0.02"}
i = 0
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1]; i += 2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["in"])
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bmesh.ops.triangulate(bm, faces=bm.faces)
# Drop floating fragments (a thin stray wire sets the bounds and shrinks the part). A model is often
# built from separate shells that touch, so a shell stays when its bounding box overlaps, within --touch
# (2 %) of the model's size, a shell already kept (low-poly shells cross without sharing near
# vertices, so a vertex-distance test drops bases; a fragment inside another shell's box survives); the walk starts from the shell with the most faces.
seen = set(); islands = []
for f in bm.faces:
    if f in seen:
        continue
    stack = [f]; isl = []; seen.add(f)
    while stack:
        g = stack.pop(); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h not in seen:
                    seen.add(h); stack.append(h)
    islands.append(isl)
def box(isl):
    pts = [v.co for f in isl for v in f.verts]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))
boxes = [box(isl) for isl in islands]
allp = [v.co for v in bm.verts]
margin = float(opt["touch"]) * max(max(p[k] for p in allp) - min(p[k] for p in allp) for k in range(3))
order = sorted(range(len(islands)), key=lambda n: -len(islands[n]))
kept = {order[0]}; grew = True
while grew:
    grew = False
    for n in order:
        if n in kept:
            continue
        for m in kept:
            if all(boxes[n][0][k] <= boxes[m][1][k] + margin and boxes[m][0][k] <= boxes[n][1][k] + margin for k in range(3)):
                kept.add(n); grew = True
                break
stray = [f for n, isl in enumerate(islands) if n not in kept for f in isl]
if stray:
    bmesh.ops.delete(bm, geom=stray, context="FACES")
# --cut-above F removes faces whose centre is above fraction F of the height, for a floating
# fragment a thin strand still joins to the body.
if float(opt["cut-above"]) < 1.0:
    zs = [v.co.z for v in bm.verts]
    limit = min(zs) + (max(zs) - min(zs)) * float(opt["cut-above"])
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > limit], context="FACES")
bm.to_mesh(me); bm.free()
cap = int(opt["max-tris"])
if len(me.polygons) > cap:
    mod = ob.modifiers.new("d", "DECIMATE"); mod.ratio = cap / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier="d")
    me = ob.data
co = [v.co.copy() for v in me.vertices]
mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
size = mx - mn
scale = min(float(opt["wide"]) / max(size.x, size.y), float(opt["tall"]) / size.z)
mid = (mn + mx) / 2
for v in me.vertices:
    v.co = Vector(((v.co.x - mid.x) * scale, (v.co.y - mid.y) * scale, (v.co.z - mn.z) * scale))
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
while me.color_attributes:
    me.color_attributes.remove(me.color_attributes[0])
me.materials.clear()
# Smooth across shallow edges, hard across edges sharper than 40 degrees.
for p in me.polygons:
    p.use_smooth = True
bpy.ops.object.shade_auto_smooth(angle=0.698)
ob.name = "Part"; me.name = "Part"
for o in list(bpy.context.scene.objects):
    if o is not ob:
        bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath=opt["out"], export_format="GLB", export_materials="NONE", export_yup=True, export_apply=True)
print("PART " + json.dumps({"out": opt["out"], "tris": len(me.polygons), "verts": len(me.vertices),
    "size_m": [round(size.x * scale, 3), round(size.y * scale, 3), round(size.z * scale, 3)]}))
