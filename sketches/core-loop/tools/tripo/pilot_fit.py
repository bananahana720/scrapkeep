# blender -b --factory-startup -P pilot_fit.py -- --old pilot_x_anim.glb --new tripo.glb --out out.glb [--tris 8200] [--arm-yaw 90] [--flip 1] [--head-scale 1.35 --neck 0.5]
import bpy, sys, math, json
from mathutils import Matrix, Vector
a = sys.argv[sys.argv.index("--") + 1:]
opt = {"--tris": "8200", "--arm-yaw": "auto", "--flip": "1", "--drop": "all"}
opt.update(dict(zip(a[::2], a[1::2])))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["--old"])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
# the authored skinned meshes (body, claws, tail, wings, cap): they lend their weights and are then replaced
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
# bind: a copy of the rig posed to the new mesh's arms takes the automatic weights, then carries the mesh back
def out_angle(dx, dy): return math.atan2(abs(dx), dy)  # 0 = straight forward, 90 deg = straight out to the side
if opt["--arm-yaw"] == "auto":
    ub = arm.data.bones["upper_arm.L"]; hb = arm.data.bones["hand.L"]
    sh = arm.matrix_world @ ub.head_local; hd0 = arm.matrix_world @ hb.head_local
    # the hands: between hips and neck (so ears, crests and cheeks never count), beside the body, level with or in front of
    # the shoulder (so a tail never counts), farthest from the shoulder
    zlo = (arm.matrix_world @ arm.data.bones["pelvis"].head_local).z; zhi = (arm.matrix_world @ arm.data.bones["neck"].head_local).z
    side = [v for v in wverts(n) if zlo < v.z < zhi and abs(v.x) > 0.6 * abs(sh.x) and v.y > sh.y - 0.05] or wverts(n)
    side.sort(key=lambda v: math.hypot(abs(v.x) - abs(sh.x), v.y - sh.y), reverse=True)
    tips = side[:max(10, len(side) // 30)]
    print("YAW tips", len(tips))
    tx = sum(abs(v.x) for v in tips) / len(tips); ty = sum(v.y for v in tips) / len(tips)
    yaw = out_angle(tx - abs(sh.x), ty - sh.y) - out_angle(hd0.x - sh.x, hd0.y - sh.y)
    print("YAW deg", round(math.degrees(yaw), 1))
else:
    yaw = math.radians(float(opt["--arm-yaw"]))
a2 = arm.copy(); a2.data = arm.data.copy(); a2.animation_data_clear(); bpy.context.scene.collection.objects.link(a2)
def swing(sign_l):
    for nm, sg in (("upper_arm.L", 1), ("upper_arm.R", -1)):
        pb = a2.pose.bones[nm]; hd = pb.head.copy()
        pb.matrix = Matrix.Translation(hd) @ Matrix.Rotation(sign_l * sg * yaw, 4, "Z") @ Matrix.Translation(-hd) @ pb.matrix
        bpy.context.view_layer.update()
def only(*objs):
    for o in bpy.data.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
# the old meshes, posed with the arms where the new mesh has them, lend their weights
only(*old); bpy.ops.object.duplicate()
src = bpy.context.view_layer.objects.active
if len(bpy.context.selected_objects) > 1: bpy.ops.object.join()
src = bpy.context.view_layer.objects.active
for md in src.modifiers:
    if md.type == "ARMATURE": md.object = a2
only(a2); bpy.ops.object.mode_set(mode="POSE")
for pb in a2.pose.bones: pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
if yaw != 0: swing(1)
bpy.ops.object.mode_set(mode="OBJECT")
only(src)
names = [g.name for g in src.vertex_groups]
for md in list(src.modifiers):
    if md.type == "ARMATURE": bpy.ops.object.modifier_apply(modifier=md.name)
for nm in names: n.vertex_groups.new(name=nm)
dt = n.modifiers.new("dt", "DATA_TRANSFER"); dt.object = src; dt.use_vert_data = True; dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"; dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
only(n); bpy.ops.object.modifier_apply(modifier="dt")
bpy.data.objects.remove(src)
if yaw != 0:
    only(a2); bpy.ops.object.mode_set(mode="POSE"); bpy.ops.pose.armature_apply(selected=False); swing(-1); bpy.ops.object.mode_set(mode="OBJECT")
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
