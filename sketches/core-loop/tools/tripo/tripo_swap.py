"""Swap one mesh node of an authored model for a Tripo mesh, keeping everything else.

blender -b --factory-startup -P tools/tripo/tripo_swap.py -- --in tripo.glb --ref authored.glb --node NodeName \
    --out out.glb [--yaw DEG] [--max-tris N] [--fit box|height]

For models whose code animates named parts (enemy_clips.gd ROWS): the authored hierarchy, pivots,
sockets and the other parts stay as they are; only `--node`'s mesh is replaced. The Tripo mesh is
turned by --yaw, fitted inside that node's own bounds, and each face snaps to the nearest colour of
that node's material slots (or, for a single-material vertex-coloured node, its vertex palette).
The texture never ships. Chain runs (out of one as --ref of the next) to swap several nodes.
Prints one JSON line with counts.
"""
import json, math, struct, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "0", "fit": "box"}
i = 0
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1]; i += 2


def srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def read_glb(path):
    raw = open(path, "rb").read(); n = struct.unpack("<I", raw[12:16])[0]
    return json.loads(raw[20:20 + n]), raw[20 + n:]


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["ref"])
ref_objs = set(bpy.context.scene.objects)
target = bpy.data.objects.get(opt["node"])
if target is None or target.type != "MESH":
    raise SystemExit("no mesh node named %s in %s" % (opt["node"], opt["ref"]))
tme = target.data
# the node's bounds in its own local space
lmn = Vector([min(v.co[k] for v in tme.vertices) for k in range(3)])
lmx = Vector([max(v.co[k] for v in tme.vertices) for k in range(3)])
old_tris = sum(len(p.vertices) - 2 for p in tme.polygons)
gj, _ = read_glb(opt["ref"])
factor = {m.get("name"): m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1.0] * 4)[:3] for m in gj.get("materials", [])}
mats = [s.material for s in target.material_slots if s.material]
palette = []
if len(mats) > 1:
    style = "slots"
    for k, m in enumerate(mats):
        palette.append((np.array(factor.get(m.name.split(".")[0], [0.8] * 3)), k))
else:
    style = "vertex"
    ca = tme.color_attributes.active_color or (tme.color_attributes[0] if tme.color_attributes else None)
    area = {}
    for p in tme.polygons:
        if ca is None:
            break
        idx = p.loop_indices if ca.domain == "CORNER" else p.vertices
        c = np.mean([ca.data[j].color[:3] for j in idx], axis=0)
        key = tuple(np.round(srgb(c) * 32).astype(int))
        a, s = area.get(key, (0.0, np.zeros(3)))
        area[key] = (a + p.area, s + c * p.area)
    for key, (a, s) in sorted(area.items(), key=lambda kv: -kv[1][0])[:12]:
        palette.append((s / a, 0))
    if not palette:
        palette.append((np.array(factor.get(mats[0].name.split(".")[0], [0.8] * 3)) if mats else np.ones(3), 0))

bpy.ops.import_scene.gltf(filepath=opt["in"])
new = [o for o in bpy.context.scene.objects if o not in ref_objs]
meshes = [o for o in new if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
mw = ob.matrix_world.copy(); ob.parent = None; ob.matrix_world = mw
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
me.transform(Matrix.Rotation(math.radians(float(opt["yaw"])), 4, "Z"))
mn = Vector([min(v.co[k] for v in me.vertices) for k in range(3)])
mx = Vector([max(v.co[k] for v in me.vertices) for k in range(3)])
ext, rext = mx - mn, lmx - lmn
s = (rext.z / max(ext.z, 1e-6)) if opt["fit"] == "height" else min(rext[k] / max(ext[k], 1e-6) for k in range(3))
c, rc = (mn + mx) / 2, (lmn + lmx) / 2
me.transform(Matrix.Translation(Vector((rc.x, rc.y, lmn.z))) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-c.x, -c.y, -mn.z))))

# Weld the vertices Tripo split along its UV seams; a vertex-coloured asset needs no UVs, so they
# go first and the vertex count drops to what the colour borders need.
def _weld(mesh, keep_uv):
    bmw = bmesh.new(); bmw.from_mesh(mesh)
    bmesh.ops.remove_doubles(bmw, verts=bmw.verts, dist=1e-5)
    bmw.to_mesh(mesh); bmw.free()
img = None
for sl in ob.material_slots:
    if sl.material and sl.material.use_nodes:
        img = next((n.image for n in sl.material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
    if img:
        break
pal_s = srgb(np.array([p[0] for p in palette]))
slot = np.zeros(len(me.polygons), int)
if img is not None and me.uv_layers:
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, -1)[:, :, :3]
    uv = me.uv_layers.active.data
    for p in me.polygons:
        pts = [uv[li].uv for li in p.loop_indices]
        cen = sum((Vector(u) for u in pts), Vector((0, 0))) / len(pts)
        cols = [px[min(H - 1, max(0, int((u.y % 1.0) * H))), min(W - 1, max(0, int((u.x % 1.0) * W)))] for u in pts + [cen, cen]]
        slot[p.index] = int(np.argmin(np.sum((pal_s - np.median(np.array(cols), axis=0)) ** 2, axis=1)))
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
for _ in range(2):
    nxt = slot.copy()
    for f in bm.faces:
        nb = [slot[g.index] for e in f.edges for g in e.link_faces if g is not f]
        if nb:
            vals, cnt = np.unique(nb, return_counts=True)
            if cnt.max() * 2 > len(nb):
                nxt[f.index] = vals[cnt.argmax()]
    slot = nxt
bm.free()
me.materials.clear()
for m in mats:
    me.materials.append(m)
ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
for p in me.polygons:
    k = slot[p.index]
    p.material_index = palette[k][1] if style == "slots" else 0
    rgb = (1.0, 1.0, 1.0) if style == "slots" else tuple(palette[k][0])
    for li in p.loop_indices:
        ca.data[li].color = (*rgb, 1.0)
while len(me.uv_layers) > 1:
    me.uv_layers.remove(me.uv_layers[-1])
if style == "vertex":
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
_weld(me, style != "vertex")
tris = sum(len(p.vertices) - 2 for p in me.polygons)
cap = int(opt["max-tris"])
if cap and tris > cap:
    md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = cap / tris
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)

# hand the new mesh to the authored node, then drop the import
old = target.data
target.data = me
me.name = old.name
for o in new:
    bpy.data.objects.remove(o, do_unlink=True)
for im in list(bpy.data.images):
    bpy.data.images.remove(im)
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)
bpy.ops.export_scene.gltf(filepath=opt["out"], export_format="GLB", export_image_format="NONE",
                          export_vertex_color="ACTIVE", export_all_vertex_colors=False)
# carry the authored material definitions over by name
oj, rest = read_glb(opt["out"])
byname = {m.get("name"): m for m in gj.get("materials", [])}
oj["materials"] = [byname.get(m.get("name"), m) for m in oj.get("materials", [])]
js = json.dumps(oj, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<I", len(js)) + b"JSON" + js + rest
open(opt["out"], "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print("SWAP " + json.dumps({"out": opt["out"], "node": opt["node"], "node_tris": tris, "node_tris_before": old_tris,
                           "model_tris": total, "style": style, "slots_used": sorted(set(int(x) for x in slot)),
                           "scale": round(s, 4), "had_texture": img is not None}))
