"""Fit a textured Tripo mesh as a new prop that has no authored twin.

blender -b --factory-startup -P tripo_prop.py -- --in tripo.glb --out prop.glb --name PropName [--root RootName] [--lod-name LodMeshName] [--tall 4.0] [--wide 0] [--yaw 0] [--max-tris 2000] [--colours 8] [--smooth 2] [--lods "0.5,0.15"] [--span "3.1:4.0"] [--paint "1=#c4572a,5=#d39a3c"] [--region "x0,y0,z0,x1,y1,z1=#a8492b"]

What it does, in order:
1. Joins the mesh, turns it by --yaw about the up axis, scales it uniformly to --tall metres high or to --wide metres
   across its longer ground side, stands its base on the origin and centres it. With both, the ground plane is
   scaled to --wide and the height to --tall separately, which squashes or stretches the shape: look at the render.
2. Samples the texture once per face and groups the faces into --colours flat colours of its own (area-weighted
   k-means in sRGB), then smooths one-face speckles away. The texture, the image and the UVs are dropped: the prop
   ships linear COLOR_0 on one material named paint, as the park props do (the loader sets vertex colour as albedo).
3. Welds the seam splits, decimates to --max-tris, names the mesh --name under a root of the same name plus "Root"
   (or --root, for a sibling that must keep an authored model's node names).
   With --span "a:b", the middle is widened or narrowed right after that scaling: points a metres either side of the
   centre along X move to b metres, and the outer edge stays where it is, so an opening can be set to a planned
   width. It acts on X only, so turn the mesh with --yaw until the opening runs along X.
   With --paint "n=#rrggbb,...", found colour number n is repainted. The numbers are in the "found" list this script
   prints, and they change when a geometry option changes, so read them from a run with the same options.
   With --region "x0,y0,z0,x1,y1,z1=#rrggbb", every face whose centre lies in that box (metres, Blender axes, Z up,
   after the fit) is repainted that colour, for a part whose colour the texture lost (a wheel that must be red).
   Each face keeps its lightness against the box's average, within 0.7 to 1.3, so the part's own shapes still read.
   Several boxes are separated by semicolons. A box that holds no face stops the script.
4. With --lods, also writes <out stem>_lod1.glb, _lod2.glb ... at those shares of the triangle count.
   With --lod-name, the mesh node in those files takes that name (an authored prop's detail levels can name it
   differently from the full model, and a sibling must keep each file's node names).
Prints one JSON line with counts, the found colours with their share of the area, and the size in metres.
"""
import json, math, re, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"yaw": "0", "max-tris": "2000", "colours": "8", "smooth": "2", "wide": "0", "tall": "0", "lods": "", "name": "Prop", "span": "", "paint": "", "region": "", "root": "", "lod-name": ""}
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

def hexcol(text, option):
    if not re.fullmatch(r"#?[0-9a-fA-F]{6}", text.strip()):
        raise SystemExit("tripo_prop: %s needs a colour as #rrggbb, got %s" % (option, text))
    h = text.strip().lstrip("#")
    return [int(h[n:n + 2], 16) / 255 for n in (0, 2, 4)]


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
if opt["span"]:
    a, b = [float(x) for x in opt["span"].split(":")]
    half = max(abs(v.co.x) for v in me.vertices)
    if not (0 < a < half and 0 < b < half):
        raise SystemExit("tripo_prop: --span needs both numbers inside the half width %.2f" % half)
    for v in me.vertices:
        x = abs(v.co.x)
        v.co.x = math.copysign(x * b / a if x <= a else b + (x - a) * (half - b) / (half - a), v.co.x)

img = None
for sl in ob.material_slots:
    if sl.material and sl.material.use_nodes:
        for ln in sl.material.node_tree.links:
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
shares = [float(area[slot == j].sum() / area.sum()) for j in range(k)]
found = ["#%02x%02x%02x" % tuple(int(round(float(x) * 255)) for x in np.clip(cent[j], 0, 1)) for j in range(k)]
for item in [x for x in opt["paint"].split(",") if x]:
    if item.count("=") != 1 or not item.split("=")[0].strip().isdigit():
        raise SystemExit("tripo_prop: --paint needs number=#rrggbb, got " + item)
    j, hx = item.split("=")
    if not 0 <= int(j) < k:
        raise SystemExit("tripo_prop: --paint names colour %s, the mesh has 0 to %d" % (j, k - 1))
    cent[int(j)] = hexcol(hx, "--paint")
fcol = cent[slot].copy()
if opt["region"]:
    lum = fcol @ np.array([0.2126, 0.7152, 0.0722])
    centre = np.array([p.center[:] for p in me.polygons])
    for item in [x for x in opt["region"].split(";") if x]:
        try:
            box, hx = item.split("=")
            b = [float(x) for x in box.split(",")]
        except ValueError:
            b = []
        if len(b) != 6:
            raise SystemExit("tripo_prop: --region needs six numbers and a colour, got " + item)
        lo, hi = np.minimum(b[:3], b[3:]), np.maximum(b[:3], b[3:])
        inside = np.all((centre >= lo) & (centre <= hi), axis=1)
        if not inside.any():
            raise SystemExit("tripo_prop: --region box %s holds no face" % box)
        target = np.array(hexcol(hx, "--region"))
        mean = float((lum[inside] * area[inside]).sum() / area[inside].sum())
        shade = np.clip(lum[inside] / max(mean, 1e-6), 0.7, 1.3)
        fcol[inside] = np.clip(target[None, :] * shade[:, None], 0, 1)
fcol_lin = linear(fcol)
me.materials.clear()
paint = bpy.data.materials.new("paint"); paint.use_backface_culling = False; paint.diffuse_color = (1, 1, 1, 1); me.materials.append(paint)
for old in list(me.color_attributes):
    me.color_attributes.remove(old)
ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
me.color_attributes.active_color = ca
for p in me.polygons:
    p.material_index = 0
    for li in p.loop_indices:
        ca.data[li].color = (*fcol_lin[p.index], 1.0)
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
root = bpy.data.objects.new(opt["root"] or opt["name"] + "Root", None); bpy.context.scene.collection.objects.link(root)
ob.parent = root

def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)

export(opt["out"])
co = np.array([v.co[:] for v in me.vertices])
lods = []
for n, share in enumerate([float(x) for x in opt["lods"].split(",") if x], 1):
    lods.append(decimate(ob, max(1, int(tris * share))))
    if opt["lod-name"]:
        ob.name = opt["lod-name"]; me.name = opt["lod-name"]
    export(opt["out"][:-4] + "_lod%d.glb" % n)
print("PROP " + json.dumps({"out": opt["out"], "tris": tris, "lods": lods, "colours": int(len(set(slot.tolist()))),
                           "found": ["%d %s %.0f%%" % (j, found[j], shares[j] * 100) for j in range(k)],
                           "size_m": [round(float(x), 2) for x in (co.max(axis=0) - co.min(axis=0))], "scale": [round(float(sh), 4), round(float(sv), 4)]}))
