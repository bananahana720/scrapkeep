"""Bring a mojulo glb into the park props kit contract, and render comparison stills.

Trial tooling only (the mojulo prop trial, 23 Oct 2026); nothing here edits the kit.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P adopt.py -- \
  adopt <mojulo.glb> <out_dir> <base> [--bake] [--decode] [--weld] [--target TRIS]
blender -b ... -P adopt.py -- still <out.png> <glb> [<glb> ...]

`adopt` drops mojulo's ground plate, joins its meshes into one Surface (`--decode` treats
COLOR_0 as sRGB, as the dam hero's export did; this trial's exact-field export was already
linear: timber_dark #5d4630 arrives as 0.109, 0.061, 0.030), gives it the kit's vertex-colour `paint`
slot, seats the foot centre on the floor, optionally runs the kit's AO and wear bake
(polish.bake), then writes LOD0, LOD1 and LOD2 with the kit's own writer and decimator.
`still` renders with the kit's preview camera, so kit and mojulo stills match.
"""
import json
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

KIT = Path(__file__).resolve().parents[2] / "sketches/core-loop/tools/blender/park/props"
sys.path.insert(0, str(KIT))
sys.path.insert(0, str(KIT.parents[1]))
import common  # noqa: E402
import kit  # noqa: E402
import polish  # noqa: E402


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def drop_loose(me):
    """Removes vertices with no faces; the glTF writer drops them, so seating must ignore them."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()


def adopt(src, out_dir, base, bake, decode, weld, target=0):
    common.reset()
    polish.enable(detail=1)
    bpy.ops.import_scene.gltf(filepath=str(src))
    # Mojulo adds a "static" ground plate (a contact shadow under the object); the kit has none.
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("static")]:
        bpy.data.objects.remove(o)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    me = obj.data
    attr = me.color_attributes[0]
    if attr.domain != "CORNER" or attr.data_type != "FLOAT_COLOR":
        bpy.ops.geometry.color_attribute_convert(domain="CORNER", data_type="FLOAT_COLOR")
        attr = me.color_attributes[0]
    attr.name = "Color"
    cols = [0.0] * (4 * len(attr.data))
    attr.data.foreach_get("color", cols)
    if decode:
        cols = [srgb_to_linear(v) if i % 4 != 3 else v for i, v in enumerate(cols)]
        attr.data.foreach_set("color", cols)
    me.color_attributes.active_color = attr
    me.materials.clear()
    me.materials.append(common.material("paint"))
    for p in me.polygons:
        p.material_index = 0
    drop_loose(me)
    if weld:
        # Mojulo writes each triangle's corners apart (38k vertices for 17k triangles, 3x the
        # kit's). Weld coincident corners and shade smooth, as the kit does, so the rounded
        # bevels carry the edge highlight.
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        for f in bm.faces:
            f.smooth = True
        # Unbevelled corners (over about 40 degrees) stay sharp, so a flat slab does not
        # shade like a pillow.
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.7:
                e.smooth = False
        bm.to_mesh(me)
        bm.free()
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    me.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    me.update()
    root = common.empty(base)
    common.place(obj, (0, 0, 0), root)
    if target:
        # A sampled field's surface net is uniform, so a small body lands far over its band;
        # collapse it to the record's budget before the bake, as the LODs are made.
        lod0 = kit.Kit.decimate(None, root, obj, target)
        bpy.data.objects.remove(obj)
        obj = lod0
        drop_loose(obj.data)
    if bake:
        bpy.context.view_layer.update()
        polish.bake(root, polish.options())
    out_dir.mkdir(parents=True, exist_ok=True)
    t0 = common.tris(obj)
    stats = [kit.Kit.write(None, root, obj, out_dir / (base + ".glb"))]
    for suffix, target in (("_lod1", kit.LOD1_TARGET), ("_lod2", kit.LOD2_TARGET)):
        lod = kit.Kit.decimate(None, root, obj, max(round(t0 * target), kit.LOD2_MIN_TRIS))
        # Collapse on mojulo's many small closed solids leaves loose vertices below the floor;
        # the kit's re-seat reads them and the writer drops them, so the LOD floated 3 to 5 cm.
        drop_loose(lod.data)
        floor = min(v.co.z for v in lod.data.vertices)
        for v in lod.data.vertices:
            v.co.z -= floor
        stats.append(kit.Kit.write(None, root, lod, out_dir / (base + suffix + ".glb")))
        bpy.data.objects.remove(lod)
        low = stats[-1]["bounds"][0][1]
        assert abs(low) <= kit.FLOOR_TOL, "%s%s: bottom at y %.3f, not 0" % (base, suffix, low)
    print("ADOPTED " + json.dumps({"base": base, "bake": bake, "tris": [s["tris"] for s in stats],
                                   "bounds": stats[0]["bounds"], "sha256": [s["sha256"] for s in stats]}), flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    if argv[0] == "adopt":
        adopt(Path(argv[1]), Path(argv[2]), argv[3], "--bake" in argv, "--decode" in argv, "--weld" in argv,
              int(argv[argv.index("--target") + 1]) if "--target" in argv else 0)
    elif argv[0] == "still":
        kit.render([Path(p) for p in argv[2:]], Path(argv[1]), 900, 700, spread=len(argv) > 3)
    else:
        raise SystemExit("unknown mode " + argv[0])


main()
