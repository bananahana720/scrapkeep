"""Finish a fitted Tripo model: the polish bake in its second UV set, and optionally lifted colours and leg struts.

blender -b --factory-startup -P tools/tripo/tripo_finish.py -- --in fitted.glb --out out.glb \
    [--lift "Node=1.2,..."] [--strut "Node:x0,y0,z0:x1,y1,z1:radius:slot;..."] [--drop-under "Node=20,..."]

The bake. An authored enemy carries the polish bake in UV2 (x: the share of the corner out of shadow, y: edge
wear, 0.5 neutral; tools/blender/POLISH.md), and the game reads it on every swapped-in material (src/presentation/
bake_look.gd): the shade multiplies the paint, and on Fleet paint the worn convex edges and the rim lift toward
bone. A generated mesh came out of tripo_fit.py or tripo_swap.py with no second UV set, so the game skipped it:
no shade and no bone edge. Beside an authored model that has both it read flat and darker, and the render check
failed the generated chaser and the boom tender hull on that (wave 46: view brightness 0.79 of the authored).
This runs polish.py's own bake over the whole model, so the parts shade each other, and writes UV2 on every mesh
that has fewer than two UV sets. A mesh that already has two (an authored part a swap kept) is left as it is, and
no vertex colour changes, so a part never takes the shade twice.

--lift multiplies a node's vertex colours by a factor (in sRGB, clamped to white), for a generated body whose
snapped colours sit darker than the authored paint.

--strut adds a closed eight-sided rod to a node, from one point to another (metres, glTF axes: Y up, the node's own
space), in the named material slot of that node. It is for a part the game moves apart from the body: the
generated chaser's short claws stay put while its body rears 0.3 m up, 0.7 m back and 42 degrees over in the
wind-up (chaser.gd _pose), and a rod from each claw up into the body keeps the two joined, as the authored chaser's
long legs do. At rest the rod sits inside the body, so the still pose does not change. The rods are added before
the bake, so they shade and are shaded like the rest.

The authored material definitions carry over by name. Prints one JSON line.
"""
import json, math, os, struct, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import polish  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"lift": "", "strut": "", "drop-under": ""}
i = 0
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1]; i += 2
for need in ("in", "out"):
    if need not in opt:
        raise SystemExit("tripo_finish: --%s is needed" % need)


def read_glb(path):
    raw = open(path, "rb").read(); n = struct.unpack("<I", raw[12:16])[0]
    return json.loads(raw[20:20 + n]), raw[20 + n:]


def srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def linear(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))


def mesh_node(name, flag):
    ob = bpy.data.objects.get(name)
    if ob is None or ob.type != "MESH":
        raise SystemExit("tripo_finish: --%s names %r, not a mesh node of %s" % (flag, name, opt["in"]))
    return ob


def gl_to_blender(p):  # the glTF importer turns Y up into Z up: (x, y, z) -> (x, -z, y)
    return Vector((p[0], -p[2], p[1]))


def add_strut(ob, a, b, radius, slot):
    me = ob.data
    names = [m.name.split(".")[0] if m else "" for m in me.materials]
    if slot not in names:
        raise SystemExit("tripo_finish: --strut slot %r is not a material of %s (%s)" % (slot, ob.name, names))
    a, b = gl_to_blender(a), gl_to_blender(b)
    axis = b - a
    if axis.length < 1e-4:
        raise SystemExit("tripo_finish: --strut needs two different points")
    u = axis.normalized().orthogonal().normalized()
    v = axis.normalized().cross(u)
    bm = bmesh.new(); bm.from_mesh(me)
    ring = []
    for end in (a, b):
        ring.append([bm.verts.new(end + (u * math.cos(k * math.pi / 4) + v * math.sin(k * math.pi / 4)) * radius) for k in range(8)])
    faces = [bm.faces.new((ring[0][k], ring[0][(k + 1) % 8], ring[1][(k + 1) % 8], ring[1][k])) for k in range(8)]
    faces.append(bm.faces.new(list(reversed(ring[0]))))
    faces.append(bm.faces.new(ring[1]))
    for f in faces:
        f.material_index = names.index(slot)
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    made = bmesh.ops.triangulate(bm, faces=faces)["faces"]
    layer = bm.loops.layers.color.active if bm.loops.layers.color else None
    if layer is not None:  # a slots-styled node carries white vertex colour: the slot alone colours the rod
        for f in made:
            for l in f.loops:
                l[layer] = (1.0, 1.0, 1.0, 1.0)
    bm.to_mesh(me); bm.free()
    me.update()


def drop_small_islands(ob, min_verts):
    """Remove disconnected mesh islands (grouped by welded position so hard edges stay joined) with fewer than min_verts unique vertices."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    by_pos = {}
    for v in bm.verts:
        k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        by_pos.setdefault(k, []).append(v)
    adj = {k: set() for k in by_pos}
    for f in bm.faces:
        ks = [(round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in f.verts]
        for a in ks:
            for b in ks:
                if a != b:
                    adj[a].add(b)
    seen = set()
    kill = []
    for k in by_pos:
        if k in seen:
            continue
        comp = []; stack = [k]; seen.add(k)
        while stack:
            u = stack.pop(); comp.append(u)
            for w in adj[u]:
                if w not in seen:
                    seen.add(w); stack.append(w)
        if len(comp) < min_verts:
            for u in comp:
                kill.extend(by_pos[u])
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(me); me.update()
    bm.free()
    return len(kill)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["in"])
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
roots = [o for o in bpy.context.scene.objects if o.parent is None]
lifted = {}
for item in [x for x in opt["lift"].split(",") if x]:
    name, _, factor = item.partition("=")
    ob = mesh_node(name, "lift")
    layer = ob.data.color_attributes.active_color or (ob.data.color_attributes[0] if ob.data.color_attributes else None)
    if layer is None:
        raise SystemExit("tripo_finish: --lift %r: the node has no vertex colours" % name)
    f = float(factor)
    for d in layer.data:
        c = d.color
        rgb = linear(srgb(c[:3]) * f)
        d.color = (float(rgb[0]), float(rgb[1]), float(rgb[2]), c[3])
    lifted[name] = f
dropped = {}
for item in [x for x in opt["drop-under"].split(",") if x]:
    name, _, limit = item.partition("=")
    n = drop_small_islands(mesh_node(name, "drop-under"), int(limit))
    if n:
        dropped[name] = n
struts = []
for item in [x for x in opt["strut"].split(";") if x]:
    parts = item.split(":")
    if len(parts) != 5:
        raise SystemExit("tripo_finish: --strut takes Node:x0,y0,z0:x1,y1,z1:radius:slot, not %r" % item)
    a = [float(x) for x in parts[1].split(",")]
    b = [float(x) for x in parts[2].split(",")]
    add_strut(mesh_node(parts[0], "strut"), a, b, float(parts[3]), parts[4])
    struts.append(parts[0])
had = {o.name: len(o.data.uv_layers) for o in meshes}
# polish.bake writes UV2 for a mesh with under two UV sets and leaves vertex colours alone when no slot is named.
opts = dict(polish.DEFAULTS, bake_slots=())
for root in roots:
    polish.bake(root, opts)
baked = sorted(o.name for o in meshes if had[o.name] < 2 and len(o.data.uv_layers) >= 2)
for im in list(bpy.data.images):
    bpy.data.images.remove(im)
bpy.ops.export_scene.gltf(filepath=opt["out"], export_format="GLB", export_image_format="NONE",
                          export_vertex_color="ACTIVE", export_all_vertex_colors=False)
gj, _ = read_glb(opt["in"])
oj, rest = read_glb(opt["out"])
byname = {m.get("name"): m for m in gj.get("materials", [])}
# The importer splits a material in two where one mesh uses vertex colour and another does not ("rubber.001"):
# each name goes back to one authored material, so the slots stay as the input had them.
names = [m.get("name", "").split(".")[0] for m in oj.get("materials", [])]
unique = list(dict.fromkeys(names))
for mesh in oj.get("meshes", []):
    for prim in mesh.get("primitives", []):
        if "material" in prim:
            prim["material"] = unique.index(names[prim["material"]])
oj["materials"] = [byname.get(n, {"name": n}) for n in unique]
js = json.dumps(oj, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<I", len(js)) + b"JSON" + js + rest
open(opt["out"], "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
print("FINISH " + json.dumps({"out": opt["out"], "baked": baked, "kept": sorted(set(had) - set(baked)), "lifted": lifted,
                              "dropped": dropped, "struts": struts, "model_tris": tris}))
