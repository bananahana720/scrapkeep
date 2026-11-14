# blender -b --factory-startup -P pilot_fit.py -- --old pilot_x_anim.glb --new tripo.glb --out out.glb [--tris 8200] [--arm-yaw 90] [--flip 1] [--head-scale 1.35 --neck 0.5] [--drop all] [--bridge 0.5] [--cut 0] [--voxel 0.012]
import bpy, sys, math, json
from mathutils import Matrix, Vector
a = sys.argv[sys.argv.index("--") + 1:]
opt = {"--tris": "8200", "--arm-yaw": "auto", "--flip": "1", "--drop": "all"}
opt.update(dict(zip(a[::2], a[1::2])))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["--old"])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
# the authored skinned meshes (body, claws, tail, wings, cap): they give the skeleton and the list of meshes to replace
old = [o for o in bpy.data.objects if o.type == "MESH" and o.vertex_groups and (opt["--drop"] == "all" or o.name in opt["--drop"].split(","))]
body = max(old, key=lambda o: len(o.data.polygons))
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=opt["--new"])
new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
for o in bpy.data.objects: o.select_set(False)
for o in new: o.select_set(True)
bpy.context.view_layer.objects.active = new[0]
if len(new) > 1: bpy.ops.object.join()
n = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
if opt["--flip"] == "1": n.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ n.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
def wverts(o): return [o.matrix_world @ v.co for v in o.data.vertices]
def core(vs, half):  # the body column, without the arms
    return [v for v in vs if abs(v.x) < half]
# bigger head before the fit: everything above the neck line grows about the neck, with a soft band below it
if "--head-scale" in opt:
    hs = float(opt["--head-scale"]); fr = float(opt.get("--neck", "0.5")); vs0 = [v.co for v in n.data.vertices]
    a0, a1 = min(c.z for c in vs0), max(c.z for c in vs0); zn = a0 + fr * (a1 - a0); band = 0.08 * (a1 - a0)
    ring = [c for c in vs0 if abs(c.z - zn) < band and abs(c.x) < 0.2 * (a1 - a0)] or vs0
    pv = Vector((0.0, sum(c.y for c in ring) / len(ring), zn))
    for v in n.data.vertices:
        t = min(1.0, max(0.0, (v.co.z - (zn - band)) / band)); t = t * t * (3 - 2 * t)
        if t > 0: v.co = v.co + t * ((v.co - pv) * hs + pv - v.co)
ov = wverts(body); nv = wverts(n)
oz0, oz1 = min(v.z for v in ov), max(v.z for v in ov)
nz0, nz1 = min(v.z for v in nv), max(v.z for v in nv)
s = (oz1 - oz0) / (nz1 - nz0)
n.scale = (s, s, s); bpy.ops.object.transform_apply(scale=True)
nv = wverts(n)
oc = core(ov, 0.12); nc = core(nv, 0.12)
dx = -sum(v.x for v in nc) / len(nc)
dy = (min(v.y for v in oc) + max(v.y for v in oc)) / 2 - (min(v.y for v in nc) + max(v.y for v in nc)) / 2
dz = oz0 - min(v.z for v in nv)
n.location = (dx, dy, dz); bpy.ops.object.transform_apply(location=True)
# lighter mesh, then texture -> vertex colour
tri = sum(len(p.vertices) - 2 for p in n.data.polygons)
if tri > int(opt["--tris"]):
    m = n.modifiers.new("d", "DECIMATE"); m.ratio = int(opt["--tris"]) / tri
    bpy.ops.object.modifier_apply(modifier="d")
img = None
for mat in n.data.materials:
    if mat and mat.use_nodes:
        for nd in mat.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image and nd.outputs["Color"].is_linked:
                for l in nd.outputs["Color"].links:
                    if l.to_socket.name == "Base Color": img = nd.image
me = n.data
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
if img is not None:
    w, h = img.size; px = list(img.pixels); uv = me.uv_layers.active.data
    for i, d in enumerate(uv):
        x = min(w - 1, max(0, int(d.uv.x % 1.0 * w))); y = min(h - 1, max(0, int(d.uv.y % 1.0 * h)))
        k = (y * w + x) * 4
        col.data[i].color = (lin(px[k]), lin(px[k + 1]), lin(px[k + 2]), 1.0)
me.color_attributes.active_color = col; me.color_attributes.render_color_index = 0
while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
me.materials.clear()
# "pilot" is the slot name hero_assets.paint() dresses (SLOTS["pilot"])
pm = bpy.data.materials.new("pilot"); pm.use_nodes = True
bs = pm.node_tree.nodes["Principled BSDF"]; vc = pm.node_tree.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
pm.node_tree.links.new(vc.outputs["Color"], bs.inputs["Base Color"]); bs.inputs["Roughness"].default_value = 0.8
me.materials.append(pm)
# bind: the skin weights are worked out on the new mesh itself. A stand-in armature with real limb segments, its arms aimed
# at the new hands, takes Blender's automatic weights on a watertight voxel copy of the mesh; the weights are copied back to
# the mesh, and a copy of the rig then carries the arms to the authored rest pose. (Copying weights from the authored mesh
# tore the big poses: a fatter belly took the weights of the authored arm in front of it.)
def only(*objs):
    for o in bpy.data.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
def bw(name): return arm.matrix_world @ arm.data.bones[name].head_local
zlo = bw("pelvis").z; zhi = bw("neck").z; allv = wverts(n)
aim = {}
for sfx, old_sign in (("L", 1), ("R", -1)):
    sh = bw("upper_arm." + sfx); hand0 = bw("hand." + sfx); sg = 1 if sh.x > 0 else -1
    if opt["--arm-yaw"] == "auto":
        # the hand: between hips and neck (so ears, crests and cheeks never count), beside the body, level with or in front
        # of the shoulder (so a tail never counts), farthest from the shoulder
        side = [v for v in allv if zlo < v.z < zhi and v.x * sg > 0.6 * abs(sh.x) and v.y > sh.y - 0.05]
        if not side:
            print("AIM", sfx, "no hand vertices found beside the body; the arm keeps the authored angle, check it"); rot = Matrix.Identity(4)
        else:
            side.sort(key=lambda v: math.hypot(v.x - sh.x, v.y - sh.y), reverse=True)
            tips = side[:max(10, len(side) // 30)]; tip = sum(tips, Vector()) / len(tips)
            q = (hand0 - sh).rotation_difference(tip - sh); rot = q.to_matrix().to_4x4()
            print("AIM", sfx, "deg", round(math.degrees(q.angle), 1), "tips", len(tips))
    else:
        rot = Matrix.Rotation(old_sign * math.radians(float(opt["--arm-yaw"])), 4, "Z")
    aim[sfx] = Matrix.Translation(sh) @ rot @ Matrix.Translation(-sh)
# the stand-in: one bone per deforming joint, laid along the limb (the imported bones are short stubs that all point forward).
# Helper bones (h_*) keep the legs and the snout from taking the weights of the hands beside them; they fold into their owner.
ztop = max(v.z for v in allv); zbot = min(v.z for v in allv)
segs = [("pelvis", bw("pelvis") - Vector((0, 0, 0.1)), bw("spine_01")), ("spine_01", bw("spine_01"), bw("spine_02")),
    ("spine_02", bw("spine_02"), bw("neck")), ("neck", bw("neck"), bw("head")), ("head", bw("head"), Vector((bw("head").x, bw("head").y, ztop - 0.05)))]
fold = {}
for sfx in ("L", "R"):
    A = aim[sfx]; up = bw("upper_arm." + sfx); lo = A @ bw("lower_arm." + sfx); ha = A @ bw("hand." + sfx); sg = 1 if up.x > 0 else -1
    segs += [("shoulder." + sfx, bw("shoulder." + sfx), up), ("upper_arm." + sfx, up, lo), ("lower_arm." + sfx, lo, ha),
        ("hand." + sfx, ha, ha + (ha - lo).normalized() * 0.08)]
    feet = [v for v in allv if v.x * sg > 0.03 and v.z < zbot + 0.12]
    if feet:
        segs.append(("h_leg." + sfx, Vector((sg * 0.1, bw("pelvis").y, bw("pelvis").z)), sum(feet, Vector()) / len(feet))); fold["h_leg." + sfx] = "pelvis"
face = [v for v in allv if abs(v.x) < 0.08 and v.z > bw("neck").z + 0.05]
if face:
    nose = max(face, key=lambda v: v.y)
    if nose.y > bw("head").y + 0.15: segs.append(("h_snout", bw("head"), nose - Vector((0, 0.03, 0)))); fold["h_snout"] = "head"
bd = bpy.data.armatures.new("bind"); bo = bpy.data.objects.new("bind", bd); bpy.context.scene.collection.objects.link(bo)
only(bo); bpy.ops.object.mode_set(mode="EDIT")
for nm, h, t in segs:
    eb = bd.edit_bones.new(nm); eb.head = h; eb.tail = t
bpy.ops.object.mode_set(mode="OBJECT")
only(n); bpy.ops.object.duplicate(); px = bpy.context.view_layer.objects.active
rm = px.modifiers.new("r", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = float(opt.get("--voxel", "0.012")); bpy.ops.object.modifier_apply(modifier="r")
px.vertex_groups.clear()
only(px, bo); bpy.context.view_layer.objects.active = bo; bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for src_nm, dst_nm in fold.items():
    sg_ = px.vertex_groups.get(src_nm); dg = px.vertex_groups.get(dst_nm)
    if sg_ is None: continue
    for v in px.data.vertices:
        for g in v.groups:
            if g.group == sg_.index and g.weight > 0: dg.add([v.index], g.weight, "ADD")
    px.vertex_groups.remove(sg_)
# a part the automatic weights could not reach (a floating island) takes the weights of the nearest part they did reach
from mathutils import kdtree
has = [v.index for v in px.data.vertices if any(g.weight > 0 for g in v.groups)]
bare = [v.index for v in px.data.vertices if not any(g.weight > 0 for g in v.groups)]
if not has: raise SystemExit("pilot_fit: the automatic weights reached no part of the mesh")
if bare:
    kd = kdtree.KDTree(len(has))
    for i, vi in enumerate(has): kd.insert(px.data.vertices[vi].co, i)
    kd.balance(); gi = {g.index: g for g in px.vertex_groups}
    for vi in bare:
        _, i, _ = kd.find(px.data.vertices[vi].co)
        for g in px.data.vertices[has[i]].groups: gi[g.group].add([vi], g.weight, "REPLACE")
print("BIND", json.dumps({"proxy_verts": len(px.data.vertices), "filled": len(bare), "bones": [s[0] for s in segs]}))
n.vertex_groups.clear()
for b in arm.data.bones: n.vertex_groups.new(name=b.name)
dt = n.modifiers.new("dt", "DATA_TRANSFER"); dt.object = px; dt.use_vert_data = True; dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"; dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
only(n); bpy.ops.object.modifier_apply(modifier="dt")
bpy.data.objects.remove(px); bpy.data.objects.remove(bo)
# at most four bones a vertex (the glTF limit), tiny weights dropped, the rest summing to one
vg = {g.index: g for g in n.vertex_groups}
for v in me.vertices:
    gs = sorted(((g.group, g.weight) for g in v.groups), key=lambda t: -t[1]); keep = [t for t in gs[:4] if t[1] > 0.01] or gs[:1]
    tot = sum(t[1] for t in keep)
    for gidx, _ in gs: vg[gidx].remove([v.index])
    for gidx, wt in keep: vg[gidx].add([v.index], wt / tot if tot > 0 else 1.0, "REPLACE")
# forearm and hand weights belong only to skin that is joined to a hand through skin the arm mostly owns, and to the blend
# zone that fades out from it. A whisker tip, a snout or a knee that merely sits beside a hand in the voxel copy loses them.
import bmesh
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); dl = bm.verts.layers.deform.verify(); stray = 0
# the import splits a vertex along every seam, so "joined" is judged by place: vertices at one point count as one
spot = {}; place = []
for v in bm.verts: place.append(spot.setdefault((round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)), len(spot)))
links = [set() for _ in spot]
for e in bm.edges:
    i, j = place[e.verts[0].index], place[e.verts[1].index]; links[i].add(j); links[j].add(i)
for names in (("lower_arm.L", "hand.L"), ("lower_arm.R", "hand.R")):
    gi_ = [n.vertex_groups[k].index for k in names]; hi = gi_[1]
    far = [0.0] * len(spot); hand = [0.0] * len(spot)
    for v in bm.verts:
        k = place[v.index]; far[k] = max(far[k], sum(v[dl].get(g, 0.0) for g in gi_)); hand[k] = max(hand[k], v[dl].get(hi, 0.0))
    reach = {k for k in range(len(spot)) if hand[k] > 0.5}
    if not reach: print("STRAY no skin is mostly the hand's on one side; left as it is"); continue
    for floor in (0.5, 0.02):  # first through skin the arm mostly owns, then out through the blend zone
        stack = list(reach)
        while stack:
            for o in links[stack.pop()]:
                if o not in reach and far[o] >= floor: reach.add(o); stack.append(o)
    for v in bm.verts:
        if sum(v[dl].get(g, 0.0) for g in gi_) > 0.02 and place[v.index] not in reach:
            rest_w = {g: w for g, w in v[dl].items() if g not in gi_}; tot = sum(rest_w.values())
            if tot <= 0: continue
            v[dl].clear(); stray += 1
            for g, w in rest_w.items(): v[dl][g] = w / tot
bm.to_mesh(me); bm.free()
print("STRAY", stray)
# a bridge is skin that joins a forearm or hand straight to the legs, belly or head: a hand modelled resting on the chest, a
# control stick modelled from the hand down to the boot. Its weights would blend the two and it would stretch like rubber, so
# each bridge vertex goes wholly to the side that has more of it (--bridge 0.5; a lower number sends more to the arm). The few
# faces left spanning the break still stretch. For a long stick, pass --cut 1 to remove them, so a raised hand lifts the stick
# clear, and a lower --bridge to put the break at the boot end.
ARM_FAR = {"lower_arm.L", "lower_arm.R", "hand.L", "hand.R"}; LINK = {"upper_arm.L", "upper_arm.R", "shoulder.L", "shoulder.R", "spine_02"}
vname = {g.index: g.name for g in n.vertex_groups}; side_of = {}
for v in me.vertices:
    ws = {vname[g.group]: g.weight for g in v.groups}
    af = sum(w for k, w in ws.items() if k in ARM_FAR); lk = sum(w for k, w in ws.items() if k in LINK); bf = 1.0 - af - lk
    if af >= 0.98: side_of[v.index] = "arm"
    elif bf >= 0.98: side_of[v.index] = "body"
    if af > 0.02 and bf > 0.02 and lk < 0.25:
        to_arm = af / (af + bf) >= float(opt.get("--bridge", "0.5")); side_of[v.index] = "arm" if to_arm else "body"
        keep = {k: w for k, w in ws.items() if (k in ARM_FAR) == to_arm and k not in LINK}; tot = sum(keep.values())
        for k in ws: n.vertex_groups[k].remove([v.index])
        for k, w in keep.items(): n.vertex_groups[k].add([v.index], w / tot, "REPLACE")
bm = bmesh.new(); bm.from_mesh(me)
cut = [f for f in bm.faces if {"arm", "body"} <= {side_of.get(v.index) for v in f.verts}]
print("BRIDGE", json.dumps({"faces_spanning": len(cut), "cut": opt.get("--cut", "0") == "1"}))
if opt.get("--cut", "0") == "1": bmesh.ops.delete(bm, geom=cut, context="FACES")
bm.to_mesh(me); bm.free()
# carry the arms from where the new mesh has them to the authored rest pose
a2 = arm.copy(); a2.data = arm.data.copy(); a2.animation_data_clear(); bpy.context.scene.collection.objects.link(a2)
only(a2); bpy.ops.object.mode_set(mode="POSE")
for pb in a2.pose.bones: pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
for sfx in ("L", "R"):
    pb = a2.pose.bones["upper_arm." + sfx]; pb.matrix = aim[sfx] @ pb.matrix; bpy.context.view_layer.update()
bpy.ops.pose.armature_apply(selected=False)
for b in arm.data.bones:  # parents come first in this list
    a2.pose.bones[b.name].matrix = b.matrix_local; bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
md = n.modifiers.new("back", "ARMATURE"); md.object = a2
only(n); bpy.ops.object.modifier_apply(modifier="back")
wm = n.matrix_world.copy(); n.parent = None; n.matrix_world = wm
bpy.data.objects.remove(a2)
unweighted = sum(1 for v in me.vertices if not v.groups)
md = n.modifiers.new("Armature", "ARMATURE"); md.object = arm
n.parent = arm; n.matrix_parent_inverse = arm.matrix_world.inverted()
for o in old: bpy.data.objects.remove(o)
n.name = "Pilot"; me.name = "Pilot"
vs = wverts(n)
print("FIT", json.dumps({"tris": sum(len(p.vertices) - 2 for p in me.polygons), "unweighted": unweighted, "groups": len(n.vertex_groups),
    "x": [round(min(v.x for v in vs), 2), round(max(v.x for v in vs), 2)], "y": [round(min(v.y for v in vs), 2), round(max(v.y for v in vs), 2)],
    "z": [round(min(v.z for v in vs), 2), round(max(v.z for v in vs), 2)], "old_z": [round(oz0, 2), round(oz1, 2)], "actions": len(bpy.data.actions)}))
for m in bpy.data.materials:  # the authored material still holds the name; ours must be exactly "pilot"
    if m is not pm: m.name = "old_" + m.name
pm.name = "pilot"
bpy.ops.export_scene.gltf(filepath=opt["--out"], export_format="GLB", export_animations=True, export_animation_mode="ACTIONS", export_yup=True, export_apply=False)
