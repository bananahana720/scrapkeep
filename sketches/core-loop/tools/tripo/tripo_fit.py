"""Fit a Tripo-generated GLB to an authored Scrapkeep asset's conventions.

blender -b --factory-startup -P tripo_fit.py -- --in tripo.glb --ref authored.glb --out fitted.glb [--yaw DEG] [--max-tris N]

What it does, in order:
1. Reads the authored asset: its bounds, its socket empties, and its palette. The palette is the
   authored material slots' base colours when it has several slots (enemy style), or the distinct
   vertex colours of its single material (camp style).
2. Imports the Tripo mesh, joins it, turns it by --yaw about the up axis, scales it uniformly to
   the authored height, stands it on the ground and centres it over the authored footprint.
3. Samples the Tripo texture once per face and snaps the colour to the nearest palette entry, so
   colour stays flat per slot (the colour law); faces take that slot's material (enemy style) or
   that vertex colour on the single material (camp style). The texture and its image are dropped.
4. Decimates to --max-tris if over, copies the authored sockets, names the mesh after the authored
   one, and exports a GLB with no images.
Prints one JSON line with counts.
"""
import json, math, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "0", "fit": "height", "split": ""}
i = 0
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1]; i += 2

def srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)

def bounds(objs):
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx

bpy.ops.wm.read_factory_settings(use_empty=True)

# 1. authored reference
bpy.ops.import_scene.gltf(filepath=opt["ref"])
ref = list(bpy.context.scene.objects)
ref_meshes = [o for o in ref if o.type == "MESH"]
rmn, rmx = bounds(ref_meshes)
sockets = [(o.name, o.matrix_world.translation.copy()) for o in ref if o.type == "EMPTY" and o.parent is not None]
root_name = next((o.name for o in ref if o.parent is None), "root")
mesh_name = next((o.name for o in ref_meshes if o.parent is not None and o.parent.type != "MESH"), ref_meshes[0].name)
pivots = {o.name: o.matrix_world.translation.copy() for o in ref_meshes}
mats = []
for o in ref_meshes:
    for s in o.material_slots:
        if s.material and s.material not in mats:
            mats.append(s.material)
palette = []  # (linear rgb, material index)
if len(mats) > 1:
    style = "slots"
    # Read baseColorFactor from the GLB itself: the importer links Base Color to a vertex-colour
    # node, so the socket's default value is not the slot colour.
    import struct
    raw = open(opt["ref"], "rb").read()
    gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
    factor = {m.get("name"): m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [0.8] * 4)[:3] for m in gj["materials"]}
    for k, m in enumerate(mats):
        palette.append((np.array(factor.get(m.name.split(".")[0], [0.8] * 3)), k))
else:
    style = "vertex"
    area = {}
    for o in ref_meshes:
        me = o.data
        ca = me.color_attributes.active_color or (me.color_attributes[0] if me.color_attributes else None)
        if ca is None:
            continue
        for p in me.polygons:
            if ca.domain == "CORNER":
                c = np.mean([ca.data[li].color[:3] for li in p.loop_indices], axis=0)
            else:
                c = np.mean([ca.data[vi].color[:3] for vi in p.vertices], axis=0)
            key = tuple(np.round(srgb(c) * 32).astype(int))
            a, s = area.get(key, (0.0, np.zeros(3)))
            area[key] = (a + p.area, s + c * p.area)
    for key, (a, s) in sorted(area.items(), key=lambda kv: -kv[1][0])[:12]:
        palette.append((s / a, 0))
keep_mats = [m.copy() for m in mats] if style == "slots" else [mats[0].copy() if mats else bpy.data.materials.new("enamel")]
for k, m in enumerate(keep_mats):
    m.name = (mats[k].name if mats else "enamel")
for o in ref:
    bpy.data.objects.remove(o, do_unlink=True)
for m in mats:
    bpy.data.materials.remove(m)
for k, m in enumerate(keep_mats):
    m.name = m.name.split(".")[0]

# 2. Tripo mesh
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
ob.data.transform(Matrix.Rotation(math.radians(float(opt["yaw"])), 4, "Z"))
mn, mx = bounds([ob])
ext = mx - mn; rext = rmx - rmn
s = (rext.z / max(ext.z, 1e-6)) if opt["fit"] == "height" else min(rext[k] / max(ext[k], 1e-6) for k in range(3))
rc = (rmn + rmx) / 2; c = (mn + mx) / 2
ob.data.transform(Matrix.Translation(Vector((rc.x, rc.y, rmn.z))) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-c.x, -c.y, -mn.z))))

# 3. texture -> flat palette per face
me = ob.data
img = None
for sl in ob.material_slots:
    if sl.material and sl.material.use_nodes:
        for n in sl.material.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image; break
    if img: break
pal = np.array([p[0] for pal_i, p in enumerate(palette)]) if palette else np.zeros((1, 3))
pal_s = srgb(pal)
face_slot = np.zeros(len(me.polygons), int)
if img is not None and me.uv_layers:
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, -1)[:, :, :3]
    if img.colorspace_settings.name == "sRGB":
        px_s = px  # pixels are stored as sRGB-encoded floats for 8-bit images
    else:
        px_s = srgb(px)
    uv = me.uv_layers.active.data
    for p in me.polygons:
        cols = []
        pts = [uv[li].uv for li in p.loop_indices]
        cen = sum((Vector(u) for u in pts), Vector((0, 0))) / len(pts)
        for u in pts + [cen, cen]:
            x = min(W - 1, max(0, int((u.x % 1.0) * W))); y = min(H - 1, max(0, int((u.y % 1.0) * H)))
            cols.append(px_s[y, x])
        col = np.median(np.array(cols), axis=0)
        face_slot[p.index] = int(np.argmin(np.sum((pal_s - col) ** 2, axis=1)))
# Two passes of neighbour-majority smoothing: palette snapping turns painted rust spots and bolt
# dots into one-face speckles, which read as noise at game distance.
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
for _ in range(int(opt.get("smooth", "2"))):
    new = face_slot.copy()
    for f in bm.faces:
        nb = [face_slot[g.index] for e in f.edges for g in e.link_faces if g is not f]
        if nb:
            vals, cnt = np.unique(nb, return_counts=True)
            if cnt.max() * 2 > len(nb) and vals[cnt.argmax()] != face_slot[f.index]:
                new[f.index] = vals[cnt.argmax()]
    face_slot = new
bm.free()
me.materials.clear()
for m in keep_mats:
    me.materials.append(m)
ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
for p in me.polygons:
    k = face_slot[p.index]
    p.material_index = palette[k][1] if style == "slots" else 0
    rgb = (1.0, 1.0, 1.0) if style == "slots" else tuple(palette[k][0])
    for li in p.loop_indices:
        ca.data[li].color = (*rgb, 1.0)
for n in [l.name for l in me.uv_layers][1:]:
    me.uv_layers.remove(me.uv_layers[n])
for im in list(bpy.data.images):
    bpy.data.images.remove(im)

# 4. budget, names, sockets, export
tris = sum(len(p.vertices) - 2 for p in me.polygons)
cap = int(opt["max-tris"])
if cap and tris > cap:
    md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = cap / tris
    bpy.ops.object.modifier_apply(modifier=md.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
ob.name = mesh_name; me.name = mesh_name
root = bpy.data.objects.new(root_name, None); bpy.context.scene.collection.objects.link(root)
ob.parent = root
parts = {}
zmin_all = min(v.co.z for v in me.vertices); zh = max(v.co.z for v in me.vertices) - zmin_all
for spec in [x for x in opt["split"].split(",") if x]:
    name, rule = spec.split("=")
    bits = rule.split(":"); kind, frac = bits[0], float(bits[1])
    only = bits[2] if len(bits) > 2 else ""  # restrict the part to one material slot by name
    only_idx = next((k for k, m in enumerate(me.materials) if m.name == only), -1) if only else -1
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    sel = [f for f in bm.faces if ((f.calc_center_median().z - zmin_all) / zh < frac) == (kind == "zmax")
           and (only_idx < 0 or f.material_index == only_idx)]
    keep = set(sel)
    bm2 = bm.copy(); bm2.faces.ensure_lookup_table()
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.index not in {g.index for g in keep}], context="FACES")
    bmesh.ops.delete(bm, geom=sel, context="FACES")
    bm.to_mesh(me); bm.free()
    m2 = bpy.data.meshes.new(name); bm2.to_mesh(m2); bm2.free()
    for mat in me.materials: m2.materials.append(mat)
    o2 = bpy.data.objects.new(name, m2); bpy.context.scene.collection.objects.link(o2)
    piv = pivots.get(name, Vector((0, 0, 0)))
    m2.transform(Matrix.Translation(-piv)); o2.parent = ob; o2.location = piv
    parts[name] = sum(len(p.vertices) - 2 for p in m2.polygons)
for name, loc in sockets:
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e)
    e.parent = root; e.location = loc
bpy.ops.export_scene.gltf(filepath=opt["out"], export_format="GLB", export_image_format="NONE",
                          export_vertex_color="ACTIVE", export_all_vertex_colors=False)
# Carry the authored material definitions over by name (the importer's node graph does not
# round-trip baseColorFactor), so slot colours, metal and roughness match the authored asset.
import struct
def read_glb(path):
    raw = open(path, "rb").read(); n = struct.unpack("<I", raw[12:16])[0]
    return json.loads(raw[20:20 + n]), raw[20 + n:]
rj, _ = read_glb(opt["ref"]); oj, rest = read_glb(opt["out"])
byname = {m.get("name"): m for m in rj.get("materials", [])}
oj["materials"] = [byname.get(m.get("name"), m) for m in oj.get("materials", [])]
js = json.dumps(oj, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<I", len(js)) + b"JSON" + js + rest
open(opt["out"], "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
used = sorted(set(int(x) for x in face_slot))
fwd = {}
for k in used:
    cs = [p.center for p in me.polygons if p.material_index == k]
    if cs: fwd[k] = [round(sum(c[a] for c in cs) / len(cs), 2) for a in range(3)]
print("FIT " + json.dumps({"out": opt["out"], "tris": tris, "verts": len(me.vertices), "style": style,
                          "palette": len(palette), "slots_used": used, "had_texture": img is not None,
                          "scale": round(s, 4), "sockets": len(sockets), "parts": parts, "slot_centroids_blender_xyz": fwd}))
