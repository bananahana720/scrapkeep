"""Swap one mesh node of an authored model for a Tripo mesh, keeping everything else.

blender -b --factory-startup -P tools/tripo/tripo_swap.py -- --in tripo.glb --ref authored.glb --node NodeName \
    --out out.glb [--yaw DEG] [--max-tris N] [--fit box|height|fill] [--region "x0,y0,z0,x1,y1,z1"]
    [--bright keep|match]

For models whose code animates named parts (enemy_clips.gd ROWS): the authored hierarchy, pivots,
sockets and the other parts stay as they are; only `--node`'s mesh is replaced. The Tripo mesh is
turned by --yaw, fitted inside that node's own bounds, and each face snaps to the nearest colour of
that node's material slots (or, for a single-material vertex-coloured node, its vertex palette; or,
for a crew enemy whose slots are white and whose colour is all vertex colour, the nearest of each
slot's own vertex colours, taking that slot).
With --region (a box in the node's own Blender space, Z up) only the node's faces whose centres lie in the box are
replaced: the Tripo mesh is fitted to those faces' bounds and the node's other faces stay as authored. The new
faces take the unshaded value in the authored second UV set (the polish bake the game multiplies paint by). This is
for a body that holds a frame or a mast the game's own drawing depends on (the netcaster's net window); --max-tris
then caps the whole node, kept faces included.
With --bright match the sampled texture is lifted until the node's mean brightness (kept faces included) reaches the
authored node's; the line printed at the end gives both means (lum, lum_ref) either way.
The texture never ships. Chain runs (out of one as --ref of the next) to swap several nodes.
Prints one JSON line with counts.
"""
import json, math, struct, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "0", "fit": "box", "region": "", "bright": "keep"}
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
region = [float(x) for x in opt["region"].split(",")] if opt["region"] else None
kept_tris = 0


def in_region(c):
    return region is not None and all(region[k] <= c[k] <= region[k + 3] for k in range(3))


if region is not None:
    if len(region) != 6:
        raise SystemExit("tripo_swap: --region takes six numbers")
    inside = [p for p in tme.polygons if in_region(p.center)]
    if not inside:
        raise SystemExit("tripo_swap: no face of %s has its centre in --region" % opt["node"])
    pts = [tme.vertices[i].co for p in inside for i in p.vertices]
    lmn = Vector([min(v[k] for v in pts) for k in range(3)])
    lmx = Vector([max(v[k] for v in pts) for k in range(3)])
    kept_tris = old_tris - sum(len(p.vertices) - 2 for p in inside)
gj, _ = read_glb(opt["ref"])
factor = {m.get("name"): m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1.0] * 4)[:3] for m in gj.get("materials", [])}
mats = [s.material for s in target.material_slots if s.material]
palette = []
ca = tme.color_attributes.active_color or (tme.color_attributes[0] if tme.color_attributes else None)


def vertex_palette(slot_index, limit):  # the node's own vertex colours on one slot (None: all), largest area first
    area = {}
    for p in tme.polygons:
        if ca is None or (slot_index is not None and p.material_index != slot_index):
            continue
        idx = p.loop_indices if ca.domain == "CORNER" else p.vertices
        c = np.mean([ca.data[j].color[:3] for j in idx], axis=0)
        key = tuple(np.round(srgb(c) * 32).astype(int))
        a, s = area.get(key, (0.0, np.zeros(3)))
        area[key] = (a + p.area, s + c * p.area)
    return [s / a for key, (a, s) in sorted(area.items(), key=lambda kv: -kv[1][0])[:limit]]


flat = {m.name.split(".")[0]: np.array(factor.get(m.name.split(".")[0], [0.8] * 3)) for m in mats}
if len(mats) > 1 and ca is not None and any(np.allclose(flat[m.name.split(".")[0]], 1.0, atol=0.02) for m in mats):
    # Crew enemies: the game paints every surface from vertex colour (enemy_casting.gd), and the slots only say
    # which surface flashes. Each slot offers its own vertex colours; a face takes the nearest and that slot.
    style = "slots+vertex"
    for k, m in enumerate(mats):
        own = flat[m.name.split(".")[0]]
        if np.allclose(own, 1.0, atol=0.02):
            for c in vertex_palette(k, 10):
                palette.append((c, k, c))
        else:  # a slot with a colour of its own (the flashing body paint): match on it, keep white vertex colour
            palette.append((own, k, np.ones(3)))
elif len(mats) > 1:
    style = "slots"
    for k, m in enumerate(mats):
        palette.append((flat[m.name.split(".")[0]], k))
else:
    style = "vertex"
    for c in vertex_palette(None, 12):
        palette.append((c, 0))
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
# --fit fill stretches each axis to the node's bounds: the part keeps the authored reach where the game's collider
# and its other parts expect it, at the price of the generated proportions. Look at the render.
sx, sy, sz = [rext[k] / max(ext[k], 1e-6) for k in range(3)] if opt["fit"] == "fill" else (s, s, s)
c, rc = (mn + mx) / 2, (lmn + lmx) / 2
me.transform(Matrix.Translation(Vector((rc.x, rc.y, lmn.z))) @ Matrix.Diagonal((sx, sy, sz, 1.0)) @ Matrix.Translation(Vector((-c.x, -c.y, -mn.z))))

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


def lum(c):  # brightness of sRGB colours, one per row
    return np.asarray(c) @ np.array([0.2126, 0.7152, 0.0722])


def node_lum(mesh, layer):  # area-weighted mean brightness of what the game shows: slot colour times vertex colour
    tot = a = 0.0
    for p in mesh.polygons:
        if region is not None and mesh is tme and not in_region(p.center):
            continue
        m = mesh.materials[p.material_index] if p.material_index < len(mesh.materials) and mesh.materials[p.material_index] else None
        base = flat.get(m.name.split(".")[0], np.ones(3)) if m else np.ones(3)
        if layer is not None:
            idx = p.loop_indices if layer.domain == "CORNER" else p.vertices
            base = base * np.mean([layer.data[j].color[:3] for j in idx], axis=0)
        tot += float(lum(srgb(base))) * p.area; a += p.area
    return tot / max(a, 1e-9)


ref_lum = node_lum(tme, ca)
# With --region the node is judged whole: the faces kept outside the box count at their own brightness, so a new
# part with less bright surface than the one it replaces is lifted further.
whole_lum, kept_lum, kept_area = ref_lum, 0.0, 0.0
if region is not None:
    full, region = region, None
    whole_lum = node_lum(tme, ca); whole_area = sum(p.area for p in tme.polygons)
    region = full
    in_area = sum(p.area for p in tme.polygons if in_region(p.center))
    kept_area = whole_area - in_area
    kept_lum = (whole_lum * whole_area - ref_lum * in_area) / max(kept_area, 1e-9)
slot = np.zeros(len(me.polygons), int)
if img is not None and me.uv_layers:
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, -1)[:, :, :3]
    uv = me.uv_layers.active.data
    samp = np.zeros((len(me.polygons), 3)); area = np.array([p.area for p in me.polygons])
    for p in me.polygons:
        pts = [uv[li].uv for li in p.loop_indices]
        cen = sum((Vector(u) for u in pts), Vector((0, 0))) / len(pts)
        cols = [px[min(H - 1, max(0, int((u.y % 1.0) * H))), min(W - 1, max(0, int((u.x % 1.0) * W)))] for u in pts + [cen, cen]]
        samp[p.index] = np.median(np.array(cols), axis=0)
    def snap(cols):
        return np.argmin(((cols[:, None, :] - pal_s[None, :, :]) ** 2).sum(axis=2), axis=1)
    slot = snap(samp)
    if opt["bright"] == "match" and ref_lum > 0.0:
        # A generated texture is usually darker than the authored paint, so many faces snap to the dark colours
        # and the enemy stands out less (the board's PC look, 14 November 2026). Lift the samples until the
        # snapped faces' mean brightness reaches the authored node's.
        gain = 1.0
        for _ in range(12):
            got = float((np.sum(lum(pal_s[slot]) * area) + kept_lum * kept_area) / max(area.sum() + kept_area, 1e-9))
            if got >= whole_lum * 0.995:
                break
            gain *= max(whole_lum / max(got, 1e-6), 1.03)
            slot = snap(np.clip(samp * gain, 0.0, 1.0))
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
authored_ca = ca
if region is not None and (authored_ca is None or authored_ca.domain != "CORNER"):
    raise SystemExit("tripo_swap: --region needs the node to carry a per-corner colour layer")
ca = me.color_attributes.new(authored_ca.name if region is not None else "Col", authored_ca.data_type if region is not None else "FLOAT_COLOR", "CORNER")
ca_name = ca.name
for p in me.polygons:
    k = slot[p.index]
    p.material_index = palette[k][1] if style != "vertex" else 0
    rgb = (1.0, 1.0, 1.0) if style == "slots" else tuple(palette[k][2] if len(palette[k]) > 2 else palette[k][0])
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
if cap and region is not None:
    cap -= kept_tris
    if cap <= 0:
        raise SystemExit("tripo_swap: the faces kept outside --region already use the whole --max-tris")
if cap and tris > cap:
    md = ob.modifiers.new("dec", "DECIMATE"); md.ratio = cap / tris
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)

new_lum = node_lum(me, me.color_attributes[ca_name])
if region is not None:  # the authored faces outside the box join the new mesh, colours and slots as they were
    both = bmesh.new(); both.from_mesh(me)
    fresh = len(both.faces)
    both.from_mesh(tme); both.faces.ensure_lookup_table()
    # The authored faces bring their second UV set, which holds the polish bake (x: the share of the face out of
    # shadow, y: edge wear, 0.5 neutral). The game multiplies the slot colour by it (bake_look.gd). The new faces
    # would read (0, 0) there, fully in shadow: the hooker barrel and the netcaster torso rendered near-black for
    # that reason until 14 November 2026. They take the unshaded value instead.
    for layer in list(both.loops.layers.uv.values())[1:]:
        for f in both.faces[:fresh]:
            for loop in f.loops:
                loop[layer].uv = (1.0, 0.5)
    bmesh.ops.delete(both, geom=[f for f in both.faces[fresh:] if in_region(f.calc_center_median())], context="FACES")
    both.to_mesh(me); both.free()
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
                           "model_tris": total, "style": style, "lum": round(new_lum, 3), "lum_ref": round(ref_lum, 3), "slots_used": sorted(set(int(x) for x in slot)),
                           "scale": [round(float(v), 4) for v in (sx, sy, sz)], "kept_tris": kept_tris, "had_texture": img is not None}))
