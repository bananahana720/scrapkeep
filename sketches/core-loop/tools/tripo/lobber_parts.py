"""Split a fitted whole-model lobber into the three parts the game moves.

blender -b --factory-startup -P lobber_parts.py -- --in fitted.glb --ref assets/models/world_one/enemy_lobber.glb --out enemy_lobber_tripo.glb [--half 1.15] [--top 4.9] [--bulb-r 0.895]

--in is tripo_fit.py's output for a whole lobber: one mesh in the authored slots (rubber, fleet_paint, requisition_tag),
at the authored height. The prompt must give a brass ball joint between the chassis and the tube, because the ball is
found as the largest joined patch of requisition_tag faces. The script stops if that patch is not a ball on the axis
in the middle of the height (a brass tag or trim picked by mistake). What it does, in order:
1. Squeezes the ground plane so the model fits inside --half metres of the axis (the collider is 2.4 m square).
2. Finds the ball and stretches the model in two pieces along the height, so the ball's centre lands on the authored
   LobberBulb pivot, the base stays where it was and the top lands at --top.
3. Cuts three meshes at the authored pivots: LobberBulb (the ball, one requisition_tag slot, centred on the pivot and
   scaled so it reaches --bulb-r from it: the bulb is the warning before a shot, and a warning must never read weaker
   than the one it replaces, so the default is the authored bulb's 0.9 m, just inside the test's limit), LobberBarrel (all above the ball: rubber, fleet_paint) and LobberBody (the rest: fleet_paint, rubber).
   Tag faces outside the ball join fleet_paint, so the file draws five times, as the authored one does.
Prints one JSON line with counts.
"""
import json, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {"half": "1.15", "top": "4.9", "bulb-r": "0.895"}
known = set(opt) | {"in", "out", "ref"}
i = 0
while i < len(argv):
    if argv[i][2:] not in known:
        raise SystemExit("lobber_parts: unknown option " + argv[i])
    opt[argv[i][2:]] = argv[i + 1]; i += 2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["ref"])
pivot = {o.name: o.matrix_world.translation.copy() for o in bpy.context.scene.objects if o.type == "MESH"}
root_name = next(o.name for o in bpy.context.scene.objects if o.parent is None)
for need in ("LobberBody", "LobberBarrel", "LobberBulb"):
    if need not in pivot:
        raise SystemExit("lobber_parts: the reference has no " + need)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["in"])
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if len(objs) != 1:
    raise SystemExit("lobber_parts: expected one fitted mesh, found %d" % len(objs))
ob = objs[0]
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ob.name = "fitted"
me = ob.data; me.name = "fitted"
weld = bmesh.new(); weld.from_mesh(me)
bmesh.ops.remove_doubles(weld, verts=weld.verts, dist=0.0005)
weld.to_mesh(me); weld.free()
names = [m.name for m in me.materials]
for need in ("rubber", "fleet_paint", "requisition_tag"):
    if need not in names:
        raise SystemExit("lobber_parts: the fitted mesh has no slot " + need)
TAG, PAINT, RUBBER = names.index("requisition_tag"), names.index("fleet_paint"), names.index("rubber")

co = np.array([v.co[:] for v in me.vertices])
squeeze = min(1.0, float(opt["half"]) / np.abs(co[:, :2]).max())
co[:, :2] *= squeeze
base, top = co[:, 2].min(), co[:, 2].max()
bulb_z = pivot["LobberBulb"].z

bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
tagged = [f for f in bm.faces if f.material_index == TAG]
if not tagged:
    raise SystemExit("lobber_parts: no requisition_tag faces; the prompt needs a brass ball joint")
pool = set(tagged); islands = []
while pool:
    seed = pool.pop(); isle = [seed]; todo = [seed]
    while todo:
        f = todo.pop()
        for e in f.edges:
            for g in e.link_faces:
                if g in pool:
                    pool.discard(g); isle.append(g); todo.append(g)
    islands.append(isle)
ball = max(islands, key=lambda isle: sum(f.calc_area() for f in isle))
ball_idx = {f.index for f in ball}
ball_verts = sorted({v.index for f in ball for v in f.verts})
blo, bhi = co[ball_verts].min(axis=0), co[ball_verts].max(axis=0)
centre = (blo + bhi) / 2
zc = centre[2]
ball_top = bhi[2]
size = bhi - blo
if not base + 0.3 * (top - base) < zc < base + 0.85 * (top - base):
    raise SystemExit("lobber_parts: the largest brass patch sits at height %.2f, not between the chassis and the tube" % zc)
if np.hypot(centre[0], centre[1]) > 0.15 or size.min() < 0.5 * size.max() or size.max() < 0.4:
    raise SystemExit("lobber_parts: the largest brass patch is not a ball on the axis (centre %s, size %s)" % (centre.round(2), size.round(2)))

def warp(z):
    return np.where(z < zc, base + (z - base) * (bulb_z - base) / (zc - base), bulb_z + (z - zc) * (float(opt["top"]) - bulb_z) / (top - zc))

ball_top_w = float(warp(np.array([ball_top]))[0])
co[:, 2] = warp(co[:, 2])
own = np.array([centre[0], centre[1], bulb_z])
reach = np.linalg.norm(co[ball_verts] - own, axis=1).max()
shrink = float(opt["bulb-r"]) / reach
co[ball_verts] = np.array([0.0, 0.0, bulb_z]) + (co[ball_verts] - own) * shrink
for v, c in zip(bm.verts, co):
    v.co = Vector(c)

part_of = {}
for f in bm.faces:
    if f.index in ball_idx:
        part_of[f.index] = "LobberBulb"
    elif f.calc_center_median().z > ball_top_w:
        part_of[f.index] = "LobberBarrel"
    else:
        part_of[f.index] = "LobberBody"
    if part_of[f.index] != "LobberBulb" and f.material_index == TAG:
        f.material_index = PAINT
bm.to_mesh(me); bm.free()

order = {"LobberBody": ["fleet_paint", "rubber"], "LobberBarrel": ["rubber", "fleet_paint"], "LobberBulb": ["requisition_tag"]}
mats = {m.name: m for m in me.materials}
root = bpy.data.objects.new(root_name, None); bpy.context.scene.collection.objects.link(root)
counts = {}
for part, slots in order.items():
    src = bmesh.new(); src.from_mesh(me); src.faces.ensure_lookup_table()
    bmesh.ops.delete(src, geom=[f for f in src.faces if part_of[f.index] != part], context="FACES")
    if not src.faces:
        raise SystemExit("lobber_parts: no faces for " + part)
    for f in src.faces:
        f.material_index = slots.index(names[f.material_index]) if names[f.material_index] in slots else 0
    for v in src.verts:
        v.co -= pivot[part]
    pm = bpy.data.meshes.new(part); src.to_mesh(pm); src.free()
    for s in slots:
        pm.materials.append(mats[s])
    used = {p.material_index for p in pm.polygons}
    if used != set(range(len(slots))):
        raise SystemExit("lobber_parts: %s uses slots %s, wants all of %s" % (part, sorted(used), slots))
    po = bpy.data.objects.new(part, pm); bpy.context.scene.collection.objects.link(po)
    po.parent = root; po.location = pivot[part]
    counts[part] = len(pm.polygons)
bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=opt["out"], export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
                          export_image_format="NONE", export_animations=False)
print("PARTS " + json.dumps({"out": opt["out"], "tris": counts, "squeeze": round(float(squeeze), 3), "ball_centre_was": round(float(zc), 2),
                             "ball_reach": round(float(reach * shrink), 2), "ball_scale": round(float(shrink), 2), "top": float(opt["top"])}))
