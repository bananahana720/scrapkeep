"""Fit a Tripo-generated GLB to an authored Scrapkeep asset's conventions.

blender -b --factory-startup -P tripo_fit.py -- --in tripo.glb --ref authored.glb --out fitted.glb [--yaw DEG] [--max-tris N] [--name BodyMeshName] [--match rgb|tone] [--fit height|box|fill] [--radius 0.98] [--slots "fleet_paint;x0,y0,z0,x1,y1,z1=rubber;..."]

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
   one (--name picks which, when the authored model has several meshes and the first is not the body),
   and exports a GLB with no images.
With --fit fill, each axis is scaled on its own until the mesh fills the authored bounds, which squashes or
stretches the shape: look at the render. (--fit box scales uniformly until it fits inside them; the default,
height, matches the authored height only.)
With --radius, the mesh is then narrowed about the model's up axis (X and Y together, the height stays) until no
point is farther than that many metres from the axis: an enemy must stay inside its round hit core, and a
box-shaped body that fills the authored bounds has corners that the authored shape does not.
With --slots (an enemy-style model only), the texture no longer decides the slot. A first item with no "=" names the
slot every face takes; each "x0,y0,z0,x1,y1,z1=slot" item then gives the faces that lie wholly in that box
(every corner inside; metres, Blender axes, Z up, after the fit) that slot, later items winning. A face that
crosses a box edge keeps what it had, so a slot never spills past its box. This is for a generated texture whose
colours land on the wrong authored slot. A slot name the authored model lacks, or a box that holds no face, stops
the script.
Prints one JSON line with counts.
"""
import json, math, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "0", "fit": "height", "split": "", "match": "rgb", "slots": "", "radius": "0"}
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
mesh_name = opt.get("name") or next((o.name for o in ref_meshes if o.parent is not None and o.parent.type != "MESH"), ref_meshes[0].name)
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
sv = [rext[k] / max(ext[k], 1e-6) for k in range(3)] if opt["fit"] == "fill" else [s, s, s]
ob.data.transform(Matrix.Translation(Vector((rc.x, rc.y, rmn.z))) @ Matrix.Diagonal((*sv, 1.0)) @ Matrix.Translation(Vector((-c.x, -c.y, -mn.z))))
if float(opt["radius"]) > 0:
    reach = max(math.hypot(v.co.x, v.co.y) for v in ob.data.vertices)
    if reach > float(opt["radius"]):
        k = float(opt["radius"]) / reach
        ob.data.transform(Matrix.Diagonal((k, k, 1.0, 1.0)))
        sv = [sv[0] * k, sv[1] * k, sv[2]]

# Weld the vertices Tripo split along its UV seams; a vertex-coloured asset needs no UVs, so they
# go first and the vertex count drops to what the colour borders need.
def _weld(mesh, keep_uv):
    bmw = bmesh.new(); bmw.from_mesh(mesh)
    bmesh.ops.remove_doubles(bmw, verts=bmw.verts, dist=1e-5)
    bmw.to_mesh(mesh); bmw.free()
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
LUMA = np.array([0.2126, 0.7152, 0.0722])


def tone_dist(col):
    # --match tone: compare the tint first and the lightness at a quarter weight, so a lighter or darker shade of
    # an authored colour still lands on that colour (a sky-blue wall on the authored teal, not on the pale grey).
    dl = pal_s @ LUMA - float(np.asarray(col) @ LUMA)
    dc = (pal_s - (pal_s @ LUMA)[:, None]) - (np.asarray(col) - float(np.asarray(col) @ LUMA))
    return 0.25 * dl ** 2 + np.sum(dc ** 2, axis=1)
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
        face_slot[p.index] = int(np.argmin(tone_dist(col) if opt["match"] == "tone" else np.sum((pal_s - col) ** 2, axis=1)))
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
if opt["slots"]:
    if style != "slots":
        raise SystemExit("tripo_fit: --slots needs an authored model with several material slots")
    names = [m.name for m in keep_mats]
    vco = np.array([v.co[:] for v in me.vertices])
    corners = [list(q.vertices) for q in me.polygons]
    for item in [x.strip() for x in opt["slots"].split(";") if x.strip()]:
        box, _, name = item.rpartition("=")
        if name not in names:
            raise SystemExit("tripo_fit: --slots names slot %s, the authored model has %s" % (name, names))
        k = next(i for i, q in enumerate(palette) if q[1] == names.index(name))
        if not box:
            face_slot[:] = k
            continue
        try:
            b = [float(x) for x in box.split(",")]
        except ValueError:
            b = []
        if len(b) != 6:
            raise SystemExit("tripo_fit: --slots needs six numbers and a slot name, got " + item)
        lo, hi = np.minimum(b[:3], b[3:]), np.maximum(b[:3], b[3:])
        vin = np.all((vco >= lo) & (vco <= hi), axis=1)
        inside = np.array([bool(vin[c].all()) for c in corners])
        if not inside.any():
            raise SystemExit("tripo_fit: --slots box %s holds no whole face" % box)
        face_slot[inside] = k
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

if style == "vertex":
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
_weld(me, style != "vertex")
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
                          "scale": [round(float(x), 4) for x in sv], "sockets": len(sockets), "parts": parts, "slot_centroids_blender_xyz": fwd}))
