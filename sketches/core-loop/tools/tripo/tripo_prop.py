"""Fit a textured Tripo mesh as a new prop that has no authored twin.

blender -b --factory-startup -P tripo_prop.py -- --in tripo.glb --out prop.glb --name PropName [--tall 4.0] [--wide 0] [--yaw 0] [--max-tris 2000] [--colours 8] [--smooth 2] [--lods "0.5,0.15"]

What it does, in order:
1. Joins the mesh, turns it by --yaw about the up axis, scales it uniformly to --tall metres high or to --wide metres
   across its longer ground side, stands its base on the origin and centres it. With both, the ground plane is
   scaled to --wide and the height to --tall separately, which squashes or stretches the shape: look at the render.
2. Samples the texture once per face and groups the faces into --colours flat colours of its own (area-weighted
   k-means in sRGB), then smooths one-face speckles away. The texture, the image and the UVs are dropped: the prop
   ships linear COLOR_0 on one material named paint, as the park props do (the loader sets vertex colour as albedo).
3. Welds the seam splits, decimates to --max-tris, names the mesh --name under a root of the same name plus "Root".
4. With --lods, also writes <out stem>_lod1.glb, _lod2.glb ... at those shares of the triangle count.
Prints one JSON line with counts and the size in metres.
"""
import json, math, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "2000", "colours": "8", "smooth": "2", "wide": "0", "tall": "0", "lods": "", "name": "Prop"}
i = 0
known = set(opt) | {"in", "out"}
while i < len(argv):
    if argv[i][2:] not in known:
        raise SystemExit("tripo_prop: unknown option " + argv[i])
    opt[argv[i][2:]] = argv[i + 1]; i += 2
if float(opt["tall"]) <= 0 and float(opt["wide"]) <= 0:
    raise SystemExit("tripo_prop: pass --tall or --wide in metres")

def srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)

def linear(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["in"])
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in objs)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.parent = None
ob.matrix_world = ob.matrix_world.copy()
for o in list(bpy.context.scene.objects):
    if o is not ob:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
me.transform(Matrix.Rotation(math.radians(float(opt["yaw"])), 4, "Z"))
co = np.array([v.co[:] for v in me.vertices]); mn = co.min(axis=0); mx = co.max(axis=0); ext = mx - mn
wide, tall = float(opt["wide"]), float(opt["tall"])
sh = wide / max(ext[0], ext[1]) if wide > 0 else tall / ext[2]
sv = tall / ext[2] if tall > 0 else sh
c = (mn + mx) / 2
me.transform(Matrix.Diagonal((sh, sh, sv, 1.0)) @ Matrix.Translation(Vector((-c[0], -c[1], -mn[2]))))

# texture -> one colour a face
img = None
for sl in ob.material_slots:
    if sl.material and sl.material.use_nodes:
        for ln in sl.material.node_tree.links:  # the image that feeds Base Color, not a normal or roughness map
            if ln.to_socket.name == "Base Color" and ln.from_node.type == "TEX_IMAGE" and ln.from_node.image:
                img = ln.from_node.image; break
    if img: break
if img is None or not me.uv_layers:
    raise SystemExit("tripo_prop: the mesh has no texture to take colours from")
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, -1)[:, :, :3]
px_s = px if img.colorspace_settings.name == "sRGB" else srgb(px)
uv = me.uv_layers.active.data
face = np.zeros((len(me.polygons), 3)); area = np.zeros(len(me.polygons))
for p in me.polygons:
    pts = [uv[li].uv for li in p.loop_indices]
    cen = sum((Vector(u) for u in pts), Vector((0, 0))) / len(pts)
    cols = []
    for u in pts + [cen, cen]:
        x = min(W - 1, max(0, int((u.x % 1.0) * W))); y = min(H - 1, max(0, int((u.y % 1.0) * H)))
        cols.append(px_s[y, x])
    face[p.index] = np.median(np.array(cols), axis=0); area[p.index] = p.area

# the prop's own palette: area-weighted k-means, seeded from the faces spread furthest apart so a small bright part
# (a lamp, a count board) keeps its own colour
k = int(opt["colours"])
cent = [face[int(np.argmax(area))]]
while len(cent) < k:
    d = np.min([np.sum((face - c0) ** 2, axis=1) for c0 in cent], axis=0)
    cent.append(face[int(np.argmax(d * np.sqrt(area)))])
cent = np.array(cent)
for _ in range(20):
    slot = np.argmin(((face[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2), axis=1)
    for j in range(k):
        m = slot == j
        if m.any(): cent[j] = (face[m] * area[m, None]).sum(axis=0) / area[m].sum()
slot = np.argmin(((face[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2), axis=1)
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
for _ in range(int(opt["smooth"])):
    new = slot.copy()
    for f in bm.faces:
        nb = [slot[g.index] for e in f.edges for g in e.link_faces if g is not f]
        if nb:
            vals, cnt = np.unique(nb, return_counts=True)
            if cnt.max() * 2 > len(nb) and vals[cnt.argmax()] != slot[f.index]:
                new[f.index] = vals[cnt.argmax()]
    slot = new
bm.free()
pal = linear(cent)
me.materials.clear()
paint = bpy.data.materials.new("paint"); paint.use_backface_culling = False; paint.diffuse_color = (1, 1, 1, 1); me.materials.append(paint)
for old in list(me.color_attributes):  # a colour layer the generator shipped would stay active and export instead
    me.color_attributes.remove(old)
ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
me.color_attributes.active_color = ca
for p in me.polygons:
    p.material_index = 0
    for li in p.loop_indices:
        ca.data[li].color = (*pal[slot[p.index]], 1.0)
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
for im in list(bpy.data.images):
    bpy.data.images.remove(im)
bmw = bmesh.new(); bmw.from_mesh(me); bmesh.ops.remove_doubles(bmw, verts=bmw.verts, dist=1e-5); bmw.to_mesh(me); bmw.free()

def tri_count(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)

def decimate(obj, cap):
    t = tri_count(obj.data)
    if cap and t > cap:
        bpy.context.view_layer.objects.active = obj
        md = obj.modifiers.new("dec", "DECIMATE"); md.ratio = cap / t
        bpy.ops.object.modifier_apply(modifier=md.name)
    return tri_count(obj.data)

tris = decimate(ob, int(opt["max-tris"]))
ob.name = opt["name"]; me.name = opt["name"]
root = bpy.data.objects.new(opt["name"] + "Root", None); bpy.context.scene.collection.objects.link(root)
ob.parent = root

def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)

export(opt["out"])
co = np.array([v.co[:] for v in me.vertices])  # the size of the full mesh, before the LOD passes thin it
lods = []
for n, share in enumerate([float(x) for x in opt["lods"].split(",") if x], 1):
    lods.append(decimate(ob, max(1, int(tris * share))))
    export(opt["out"][:-4] + "_lod%d.glb" % n)
print("PROP " + json.dumps({"out": opt["out"], "tris": tris, "lods": lods, "colours": int(len(set(slot.tolist()))),
                           "size_m": [round(float(x), 2) for x in (co.max(axis=0) - co.min(axis=0))], "scale": [round(float(sh), 4), round(float(sv), 4)]}))
