"""Shared finish for the rogue fleet bodies: one-piece mojulo shells plus small parts.

Each rogue's shells are a mojulo workbench recipe (`<kind>.mojulo.json` beside this file):
one sampled `fields` entry per moving piece, its term ids prefixed with the piece name.
`shells.py` mints and exports them to `shells/<kind>.glb`; the recipes here import that
glb, join and weld each piece's term meshes into one smooth shell, decimate it to budget,
repaint it from the palette and give it whole to one pose bone. The contract is the
miniboss one: <Kind>Hull (fleet_paint), <Kind>Armour (part_state), <Kind>Core (core_state),
rigid weights, origin at the collider centre, forward Godot -Z (Blender +Y).
"""
import json
import math
import os
import struct

import bmesh
import bpy
from mathutils import Vector

import common
from crew import stencil

HERE = os.path.dirname(os.path.abspath(__file__))
SHELLS = os.path.join(HERE, "shells")


def setup():
    common.reset()
    common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.7}
    common.SLOTS["part_state"] = {"vc": True, "rough": 0.4, "metal": 0.6}
    common.SLOTS["core_state"] = {"color": "petrol", "rough": 0.4}


def import_shells(kind):
    """Imports shells/<kind>.glb and returns {piece: [mesh objects]}, keyed by term-id prefix."""
    path = os.path.join(SHELLS, kind + ".glb")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    pieces = {}
    new = sorted(set(bpy.data.objects) - before, key=lambda o: o.name)
    for obj in new:
        if obj.type == "MESH" and "_" in obj.name:
            pieces.setdefault(obj.name.split("_", 1)[0], []).append(obj)
    bpy.context.view_layer.update()
    return pieces, new


def drop(objs):
    for obj in objs:
        bpy.data.objects.remove(obj, do_unlink=True)


def shell_mesh(objs, tris, offset):
    """Joins one piece's term meshes into a welded closed shell decimated to about `tris`
    triangles, moved by `offset` (metres). Returns a bmesh in recipe space."""
    bm = bmesh.new()
    for obj in sorted(objs, key=lambda o: o.name):
        piece = bmesh.new()
        piece.from_mesh(obj.data)
        piece.transform(obj.matrix_world)
        tmp = bpy.data.meshes.new("tmp")
        piece.to_mesh(tmp)
        piece.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.002)
    bmesh.ops.translate(bm, vec=Vector(offset), verts=bm.verts[:])
    mesh = bpy.data.meshes.new("shell")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("shell", mesh)
    bpy.context.scene.collection.objects.link(obj)
    count = len(mesh.polygons)
    if count > tris:
        mod = obj.modifiers.new("Budget", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = tris / count
        mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    out = bmesh.new()
    out.from_mesh(obj.evaluated_get(dg).to_mesh())
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bmesh.ops.recalc_face_normals(out, faces=out.faces[:])
    return out


def add_shell(part, src, slot, paint):
    """Copies a shell bmesh into `part` with no extra bevel or subdivision (the surface net
    already rounds every edge). `paint(position, normal)` returns each vertex's colour, so
    wear and grime blend across faces and add no colour seams. Hard colour borders (brass
    bands, flange rims, windows) are separate small parts: a face-painted border on a
    decimated surface comes out jagged."""
    with part.region(bevel=0, subsurf=0, detail=1):
        src.normal_update()
        vmap = {v: part.bm.verts.new(v.co) for v in src.verts}
        tone = {v: common.rgba(paint(v.co, v.normal)) for v in src.verts}
        faces = []
        for f in sorted(src.faces, key=lambda f: f.index):
            try:
                nf = part.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            faces.append((nf, [tone[v] for v in f.verts]))
        for nf, colours in faces:
            part.paint([nf], slot)
            for loop, c in zip(nf.loops, colours):
                loop[part.col] = c
            nf.smooth = True
    src.free()
    return [f for f, _ in faces]


def weights(part):
    """Returns bind(index): every vertex not yet weighted goes wholly to bone `index`."""
    layer = part.bm.verts.layers.deform.verify()

    def bind(index):
        for vertex in part.bm.verts:
            if not vertex[layer]:
                vertex[layer][index] = 1.0
    return bind


def governor(part, slot, base, height=0.9, scale=1.0):
    """The brass flyball governor: spindle, collar, two hinged arms and weighted balls,
    standing on `base`. It is the visible reason the machine is free (BRIEFS canon)."""
    b = Vector(base)
    s = scale
    top = b + Vector((0, 0, height * s))
    part.cyl(slot, 0.09 * s, 0.11 * s, 0.12 * s, segs=8, loc=b + Vector((0, 0, 0.06 * s)), color="charcoal")
    part.rod(slot, tuple(b), tuple(top), 0.035 * s, segs=6, color="brass")
    part.cyl(slot, 0.07 * s, 0.07 * s, 0.08 * s, segs=8, loc=top, color="brass")
    collar = b + Vector((0, 0, height * 0.45 * s))
    part.cyl(slot, 0.06 * s, 0.06 * s, 0.07 * s, segs=8, loc=collar, color="brass")
    for side in (-1, 1):
        ball = b + Vector((side * 0.36 * s, 0, height * 0.55 * s))
        part.rod(slot, tuple(top), tuple(ball), 0.025 * s, segs=5, color="brass")
        part.rod(slot, tuple(collar), tuple((ball + collar) / 2 + Vector((0, 0, 0.02 * s))), 0.02 * s,
                 segs=5, color="brass")
        part.uv(slot, 0.13 * s, u=8, v=6, loc=ball, color="brass")


def cut_line(part, slot, points, radius=0.06):
    """The Mind's command line, cut: an oxide cable along `points` ending in a frayed end
    of copper strands. Both must read at 40 m (BRIEFS canon)."""
    pts = [Vector(p) for p in points]
    for a, b in zip(pts, pts[1:]):
        part.rod(slot, tuple(a), tuple(b), radius, segs=6, color="oxide")
    end = pts[-1]
    d = (pts[-1] - pts[-2]).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d)
    part.cyl(slot, radius * 1.3, radius * 1.3, radius * 1.2, segs=6, loc=end,
             rot=Vector((0, 0, 1)).rotation_difference(d).to_euler(), color="charcoal")
    for i, (a, u) in enumerate([(0.0, 1.0), (1.2, 0.6), (2.4, 1.1), (3.6, 0.8), (4.8, 1.2)]):
        spread = side * math.cos(a) + up * math.sin(a)
        tip = end + d * (0.22 + 0.06 * (i % 2)) + spread * 0.12 * u
        part.rod(slot, tuple(end), tuple(tip), radius * 0.28, segs=4, color="copper")


def rig(root, name, rows, meshes):
    """Builds the rigid pose armature `name` from (bone, head) rows and binds `meshes`."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    arm.parent = root
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, at in rows:
        b = data.edit_bones.new(bone)
        b.head = at
        b.tail = Vector(at) + Vector((0, 0, .3))
    bpy.ops.object.mode_set(mode="OBJECT")
    for mesh in meshes:
        for bone, _ in rows:
            mesh.vertex_groups.new(name=bone)
        mod = mesh.modifiers.new("RigidPose", "ARMATURE")
        mod.object = arm
        mesh.parent = arm
    return arm


def finish(part, parent):
    """Part.to_object, then gives each vertex wholly to its heaviest bone (smoothing can
    average weights across a seam) so the pose stays rigid."""
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    obj = part.to_object(parent=parent)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.deform.active
    if layer is not None:
        for vertex in bm.verts:
            w = vertex[layer]
            if len(w) > 1:
                keep = max(sorted(w.keys()), key=lambda k: w[k])
                w.clear()
                w[keep] = 1.0
        bm.to_mesh(obj.data)
    bm.free()
    return obj


def export(root, out, meshes, tris_cap=8800, verts_cap=4900):
    bpy.context.view_layer.update()
    triangles = common.tri_total(root)
    draws = sum(len(o.data.materials) for o in meshes)
    if triangles > tris_cap or draws != 3:
        raise SystemExit("rogue budget exceeded: %d T / %d D" % (triangles, draws))
    common.export(root, out)
    with open(out, "rb") as stream:
        data = stream.read()
    gltf = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    vertices = sum(gltf["accessors"][s["attributes"]["POSITION"]]["count"]
                   for mesh in gltf["meshes"] for s in mesh["primitives"])
    if vertices > verts_cap:
        raise SystemExit("rogue vertex ceiling exceeded: %d" % vertices)
    print("ROGUE_ASSET %s %d T / %d V / %d D" % (os.path.basename(out), triangles, vertices, draws))
    return triangles, vertices, draws
