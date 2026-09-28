"""Blender cleanup for a raw vertex-coloured image-to-3D mesh.

blender -b --factory-startup --python clean_blender.py -- \
    --in raw.glb --out final.glb --budget 6000 --size 7.5 --size-axis z [--tile-axis x] [--tex 1024]

Scales to real size, drops small loose fragments, optionally cuts flat ends on a tile axis,
decimates to the triangle budget, bakes vertex colour to a texture (CPU Cycles, no GPU),
smooths by angle, puts the origin at the base centre and exports a GLB. Prints one JSON line.
"""
import argparse
import json
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

AXES = {"x": 0, "y": 1, "z": 2}


def args_after_dashes():
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="src", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--budget", type=int, required=True)
    parser.add_argument("--size", type=float, required=True, help="metres along --size-axis")
    parser.add_argument("--size-axis", default="z", choices=AXES)
    parser.add_argument("--tile-axis", choices=AXES)
    parser.add_argument("--tile-trim", type=float, default=0.04, help="fraction cut from each tile end")
    parser.add_argument("--floor-cut", type=float, default=0.0, help="fraction of height cut from the bottom")
    parser.add_argument("--min-island", type=float, default=0.01, help="drop islands below this face fraction")
    parser.add_argument("--tex", type=int, default=1024)
    parser.add_argument("--smooth-angle", type=float, default=35.0)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def import_joined(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o is not obj:
            bpy.data.objects.remove(o)
    return obj


def drop_small_islands(obj, min_fraction):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen = set()
    islands = []
    for face in bm.faces:
        if face.index in seen:
            continue
        stack = [face]
        seen.add(face.index)
        island = []
        while stack:
            f = stack.pop()
            island.append(f)
            for edge in f.edges:
                for other in edge.link_faces:
                    if other.index not in seen:
                        seen.add(other.index)
                        stack.append(other)
        islands.append(island)
    total = len(bm.faces)
    doomed = [f for island in islands if len(island) < min_fraction * total for f in island]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()
    return len(islands), len(islands) - sum(1 for i in islands if len(i) < min_fraction * total)


def cut_below(obj, fraction):
    lo, hi = bounds(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    result = bmesh.ops.bisect_plane(
        bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
        plane_co=Vector((0.0, 0.0, lo.z + (hi.z - lo.z) * fraction)), plane_no=Vector((0.0, 0.0, -1.0)),
        clear_outer=True, clear_inner=False,
    )
    cut_edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()


def cut_tile_ends(obj, axis, trim):
    lo, hi = bounds(obj)
    span = hi[axis] - lo[axis]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for plane_co, sign, clear_outer in ((lo[axis] + span * trim, -1.0, True), (hi[axis] - span * trim, 1.0, True)):
        normal = Vector((0.0, 0.0, 0.0))
        normal[axis] = sign
        co = Vector((0.0, 0.0, 0.0))
        co[axis] = plane_co
        result = bmesh.ops.bisect_plane(
            bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=normal,
            clear_outer=clear_outer, clear_inner=False,
        )
        cut_edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut_edges:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()


def decimate_to(obj, budget):
    select_only(obj)
    for _ in range(4):
        current = triangles(obj)
        if current <= budget:
            break
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(budget / current * 0.995, 1e-4)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)


def vertex_colour_material(obj):
    attr = obj.data.color_attributes[0].name if obj.data.color_attributes else None
    mat = bpy.data.materials.new("hi_emit")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    if attr is None:
        emit.inputs["Color"].default_value = (0.5, 0.5, 0.5, 1.0)
    else:
        col = nodes.new("ShaderNodeVertexColor")
        col.layer_name = attr
        gamma = nodes.new("ShaderNodeGamma")
        gamma.inputs["Gamma"].default_value = 2.2
        links.new(col.outputs["Color"], gamma.inputs["Color"])
        links.new(gamma.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return attr


def bake_texture(hi, lo, size, name):
    image = bpy.data.images.new(f"{name}_basecolor", size, size, alpha=False)
    mat = bpy.data.materials.new(f"{name}_mat")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    nodes.active = tex
    lo.data.materials.clear()
    lo.data.materials.append(mat)

    select_only(lo)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    lo_min, lo_max = bounds(lo)
    reach = (lo_max - lo_min).length * 0.02
    scene.render.bake.cage_extrusion = reach
    scene.render.bake.max_ray_distance = reach * 3
    scene.render.bake.margin = 8
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="EMIT")

    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Metallic"].default_value = 0.0
    image.pack()


def main():
    a = args_after_dashes()
    hi = import_joined(a.src)
    raw_tris = triangles(hi)

    lo_b, hi_b = bounds(hi)
    scale = a.size / (hi_b - lo_b)[AXES[a.size_axis]]
    hi.scale = (scale, scale, scale)
    select_only(hi)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    if a.floor_cut > 0:
        cut_below(hi, a.floor_cut)
    island_count, kept = drop_small_islands(hi, a.min_island)
    if a.tile_axis:
        cut_tile_ends(hi, AXES[a.tile_axis], a.tile_trim)

    lo_b, hi_b = bounds(hi)
    offset = Vector(((lo_b.x + hi_b.x) / 2, (lo_b.y + hi_b.y) / 2, lo_b.z))
    hi.data.transform(Matrix.Translation(-offset))
    hi.data.update()
    cleaned_tris = triangles(hi)
    has_colour = vertex_colour_material(hi) is not None

    select_only(hi)
    bpy.ops.object.duplicate()
    lo = bpy.context.view_layer.objects.active
    lo.name = "trial_img3d"
    lo.data.materials.clear()
    decimate_to(lo, a.budget)
    lo_b, hi_b = bounds(lo)
    lo.data.transform(Matrix.Translation(Vector((0.0, 0.0, -lo_b.z))))
    hi.data.transform(Matrix.Translation(Vector((0.0, 0.0, -lo_b.z))))

    bm = bmesh.new()
    bm.from_mesh(lo.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(lo.data)
    bm.free()
    select_only(lo)
    bpy.ops.object.shade_smooth_by_angle(angle=a.smooth_angle * 3.14159265 / 180.0)
    for attr in list(lo.data.color_attributes):
        lo.data.color_attributes.remove(attr)

    bake_texture(hi, lo, a.tex, "trial_img3d")

    select_only(lo)
    bpy.ops.export_scene.gltf(
        filepath=a.out, export_format="GLB", use_selection=True, export_apply=True,
        export_image_format="AUTO", export_materials="EXPORT",
    )
    lo_b, hi_b = bounds(lo)
    print("CLEAN_JSON " + json.dumps({
        "in": a.src,
        "out": a.out,
        "raw_triangles": raw_tris,
        "islands": island_count,
        "islands_kept": kept,
        "cleaned_triangles": cleaned_tris,
        "final_triangles": triangles(lo),
        "budget": a.budget,
        "vertex_colour_baked": has_colour,
        "texture": a.tex,
        "dimensions_m": [round(v, 3) for v in (hi_b - lo_b)],
        "base_z": round(lo_b.z, 4),
    }))


main()
