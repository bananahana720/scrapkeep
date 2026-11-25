import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common

FALL_X = [-103.0, -47.0, 37.0, 93.0]
FALL_Y = (30.0, 120.0)
FALL_HALF = 7.0
FALL_Z = 227.0
FALL_ROWS = 5
POOL_X = 138.0
POOL_Z = (203.0, 231.0)
POOL_Y = (27.8, 28.2)
POOL_QUADS = 16

CEILING = {"V": 180, "T": 120, "D": 2}


def to_blender(x, y, z):
    """Godot (x, y up, z) to the Blender Z-up frame the exporter converts back."""
    return (x, -z, y)


def make(name, verts, faces, normal_up):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(to_blender(*v)) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    for face in bm.faces:
        if face.normal.dot(normal_up) < 0:
            face.normal_flip()
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(water_material())
    return obj


def water_material():
    mat = bpy.data.materials.get("water_scenery")
    if mat is None:
        mat = bpy.data.materials.new("water_scenery")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = common.rgba("petrol")
        bsdf.inputs["Roughness"].default_value = 0.27
    return mat


def fall_sheet(fx, seed):
    """Two columns, six rings. Row heights are unequal; left and right edges bite inward by
    different amounts per ring; the ridge between them shifts and bellies in depth."""
    rng = random.Random(seed)
    lo, hi = FALL_Y
    cuts = sorted(rng.uniform(0.12, 0.88) for _ in range(FALL_ROWS - 1))
    ys = [hi] + [hi - c * (hi - lo) for c in reversed(cuts)] + [lo]
    ys.sort(reverse=True)
    verts, faces = [], []
    for i, y in enumerate(ys):
        top = i == 0
        bottom = i == len(ys) - 1
        bite = 1.9 if (top or bottom) else 1.2
        left = -FALL_HALF + rng.uniform(0.0, bite)
        right = FALL_HALF - rng.uniform(0.0, bite)
        ridge = left + (right - left) * rng.uniform(0.35, 0.65)
        z_edge = FALL_Z + 0.25
        z_ridge = FALL_Z - rng.uniform(0.0, 0.25)
        verts += [(fx + left, y, z_edge), (fx + ridge, y, z_ridge), (fx + right, y, z_edge)]
    for r in range(len(ys) - 1):
        a = r * 3
        faces += [(a, a + 1, a + 4, a + 3), (a + 1, a + 2, a + 5, a + 4)]
    return verts, faces


def tailrace(seed):
    """One strip of quads across x. The dam side stays straight and hidden; the lip toward the
    play area wanders inward, and the two ends round off, so no ruler edge reads."""
    rng = random.Random(seed)
    verts, faces = [], []
    n = POOL_QUADS
    for i in range(n + 1):
        t = i / n
        x = -POOL_X + 2 * POOL_X * t
        end = 1.0 if 0 < i < n else 0.0
        near = POOL_Z[0] + rng.uniform(0.6, 4.6) * end + (3.0 if end == 0.0 else 0.0)
        far = POOL_Z[1] - (0.0 if end else 3.0)
        y = POOL_Y[0] + 0.25 + rng.uniform(-0.15, 0.15)
        verts += [(x, y, near), (x, y, far)]
    for i in range(n):
        a = i * 2
        faces.append((a, a + 2, a + 3, a + 1))
    return verts, faces


common.reset()
root = common.empty("WaterEdges")
for k, fx in enumerate(FALL_X):
    v, f = fall_sheet(fx, 500 + k)
    parts = make("SpillSheet%d" % k, v, f, (0, 1, 0))
    parts.parent = root
sheets = [o for o in bpy.data.objects if o.name.startswith("SpillSheet")]
for o in bpy.data.objects:
    o.select_set(o in sheets)
bpy.context.view_layer.objects.active = sheets[0]
bpy.ops.object.join()
sheets[0].name = "SpillSheets"
sheets[0].data.name = "SpillSheets"
sheets[0].parent = root
v, f = tailrace(900)
pool = make("Tailrace", v, f, (0, 0, 1))
pool.parent = root

meshes = [o for o in root.children]
tri = common.tri_total(root)
vert = sum(len(o.data.vertices) for o in meshes)
ok = common.report("water_edges", [("all", tri, (1, CEILING["T"]))]) and vert <= CEILING["V"] and len(meshes) <= CEILING["D"]
print("VERTS", vert, "MESHES", len(meshes), "CEILING", CEILING)
if not ok:
    raise SystemExit("water_edges over its G05 ceiling")
common.export(root, common.args()["out"] or os.path.join(common.MODELS, "world_one", "water_edges.glb"))
