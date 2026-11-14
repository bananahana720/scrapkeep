# blender -b --factory-startup -P pilot_touch.py -- --in fit.glb --out out.glb [--head 1.0] [--fwd 0.57] [--tail 1] [--half 0.43]
# After pilot_fit.py: enlarge the head by its skin weights, keep the snout inside the cockpit's forward limit, and tuck a tail stub in.
import bpy, sys, json
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
opt = {"--head": "1.0", "--fwd": "0.57", "--tail": "1", "--half": "0.43"}
opt.update(dict(zip(a[::2], a[1::2])))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["--in"])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
n = max([o for o in bpy.data.objects if o.type == "MESH" and o.vertex_groups], key=lambda o: len(o.data.vertices))
me = n.data; mw = n.matrix_world; mwi = mw.inverted()
fam = set()
for b in arm.data.bones:
    if b.name == "head" or any(p.name == "head" for p in b.parent_recursive): fam.add(b.name)
gi = {g.index: g.name for g in n.vertex_groups}
w = [sum(g.weight for g in v.groups if gi[g.group] in fam) for v in me.vertices]
co = [mw @ v.co for v in me.vertices]
hv = [c for c, x in zip(co, w) if x > 0.5]
s = float(opt["--head"])
hz = (arm.matrix_world @ arm.data.bones["head"].head_local).z
p = Vector((0.0, max(c.y for c in hv), hz))
for i, c in enumerate(co):
    if w[i] > 0: co[i] = c + w[i] * ((c - p) * s + p - c)
ex = max(c.y for c in co) - float(opt["--fwd"])
if ex > 0:
    for i in range(len(co)): co[i].y -= ex  # the whole pilot slides back, so the skin stays whole
# a pilot that fits the width but sits off centre slides sideways until it is centred
xs = [c.x for c in co]; half = float(opt["--half"])
if max(abs(min(xs)), abs(max(xs))) > half and max(xs) - min(xs) <= 2 * half:
    mid = (max(xs) + min(xs)) / 2
    for i in range(len(co)): co[i].x -= mid
# a pilot wider than the cockpit narrows evenly about its centre (Kest's elbows: 6 percent)
xs = [c.x for c in co]
if max(xs) - min(xs) > 2 * half:
    mid = (max(xs) + min(xs)) / 2; k = 2 * half / (max(xs) - min(xs))
    for i in range(len(co)): co[i].x = (co[i].x - mid) * k
    print("NARROW", round(k, 3))
# tail stub: pink corners low at the back
tail = 0
if opt["--tail"] == "1":
    col = me.color_attributes.active_color
    vc = {}
    for l in me.loops:
        c = col.data[l.index].color if col.domain == "CORNER" else col.data[l.vertex_index].color
        vc[l.vertex_index] = c
    ymin = min(c.y for c in co); zmin = min(c.z for c in co)
    pick = [i for i, c in enumerate(co) if w[i] == 0 and c.y < ymin + 0.22 and c.z < zmin + 0.3 and i in vc and vc[i][0] > 0.5 and vc[i][2] > 0.15 and vc[i][2] > 0.25 * vc[i][0]]
    tail = len(pick)
    if pick:
        cen = sum((co[i] for i in pick), Vector()) / len(pick)
        tgt = cen + Vector((0, 0.12, 0.10))
        ps = set(pick)
        for i in pick: co[i] = tgt + (co[i] - cen) * 0.0
        # repaint with the nearest non-tail colour
        near = min((i for i in vc if i not in ps and w[i] == 0), key=lambda i: (co[i] - tgt).length)
        for l in me.loops:
            if l.vertex_index in ps and col.domain == "CORNER": col.data[l.index].color = vc[near]
for v, c in zip(me.vertices, co): v.co = mwi @ c
me.update()
hv = [c for c, x in zip(co, w) if x > 0.5]
print("TOUCH", json.dumps({"tail_verts": tail, "y": [round(min(c.y for c in co), 2), round(max(c.y for c in co), 2)],
    "z": [round(min(c.z for c in co), 2), round(max(c.z for c in co), 2)], "x": [round(min(c.x for c in co), 2), round(max(c.x for c in co), 2)],
    "head_w": round(max(c.x for c in hv) - min(c.x for c in hv), 2), "head_h": round(max(c.z for c in hv) - min(c.z for c in hv), 2), "actions": len(bpy.data.actions)}))
bpy.ops.export_scene.gltf(filepath=opt["--out"], export_format="GLB", export_animations=True, export_animation_mode="ACTIONS", export_yup=True, export_apply=False)
