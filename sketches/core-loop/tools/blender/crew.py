"""The crew kit: the parts every Fleet animal crew figure and hired machine shares.

A crew figure is a body the kind owns (barrel, tool, pack) plus parts from here: the
head with its snout and ears, the cast number and the HIRED stamp (and a keeper's
number plate). A kind's recipe builds its own body and tool and calls these, so a new
crew kind in any world is its body plus a few lines, and a head swap is one call.

Space is the recipes' Blender space: +Z up, the crew faces -Y (the exporter turns +Y
into Godot -Z). Recipes that author in Godot space pass points through their own g().
"""
import bmesh
import bpy
from mathutils import Matrix, Vector

CHAR = "charcoal"


def animal_head(part, loc, radius, snout, ears, u=10, v=6, color=CHAR):
    """The stock Fleet crew head: a round fleet_paint head (it flashes with the enemy), a
    box snout and two cone ears in vertex-colour paint.
    `snout` is (size, loc). `ears` is (radius, height, (left_loc, right_loc)).
    Returns the head's (loc, radius), the frame a replacement head is built on."""
    part.uv("fleet_paint", radius, u=u, v=v, loc=loc)
    size, at = snout
    part.box("paint", size, loc=at, color=color)
    ear_r, ear_h, sides = ears
    for at in sides:
        part.cyl("paint", ear_r, 0.0, ear_h, segs=6, loc=at, color=color)
    return Vector(loc), radius


def stencil(part, slot, text, loc, normal, height, color, depth=0.03, resolution=3):
    """Raised stencil letters (the crew number, HIRED) on a face whose outward normal is
    `normal`, centred at `loc`, `height` metres tall."""
    curve = bpy.data.curves.new("stencil", "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = depth / 2
    curve.resolution_u = resolution
    curve.size = height / 0.72
    obj = bpy.data.objects.new("stencil", curve)
    bpy.context.scene.collection.objects.link(obj)
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.curves.remove(curve)
    m = Matrix.Translation(Vector(loc) + Vector(normal).normalized() * (depth / 2)) @ _facing(normal)
    tmp = bmesh.new()
    tmp.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts[:])
    with part.region(bevel=0, subsurf=0, detail=1):
        vmap = {v: part.bm.verts.new(v.co) for v in tmp.verts}
        faces = [part.bm.faces.new([vmap[v] for v in f.verts]) for f in tmp.faces]
        part.paint(faces, slot, color)
    tmp.free()
    return faces


def number_plate(part, slot, text, loc, normal, height, plate="bone", ink="charcoal"):
    """A keeper's hand-stamped number plate (SIGHT-PERSONA.md section 3): a thin plate
    standing proud of the face whose outward normal is `normal`, the number raised on it.
    `height` is the plate's height. An old-works casting takes cast_number() instead."""
    n = Vector(normal).normalized()
    width = height * (0.45 + 0.42 * len(text))
    thick = 0.03
    face = Vector(loc) + n * (thick / 2)
    euler = _facing(normal).to_euler()
    part.box(slot, (width, height, thick), loc=tuple(face), rot=tuple(euler), color=plate)
    return stencil(part, slot, text, face + n * (thick / 2), n, height * 0.62, ink, depth=0.02)


def cast_number(part, slot, text, loc, normal, height, color="bone"):
    """The crew number cast into an old-works shell, raised straight off the face."""
    return stencil(part, slot, text, loc, normal, height, color)


def hired(part, slot, loc, normal, height, color="bone"):
    """The HIRED stamp cast in beside the number on a requisitioned old-works machine
    (SIGHT-PERSONA.md section 3: an ordinary enemy carries two marks)."""
    return stencil(part, slot, "HIRED", loc, normal, height, color, resolution=1)


def _facing(normal):
    """The rotation that turns +Z to `normal`, keeping text upright (+Y toward world up)."""
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((0, 1, 0))
    x = up.cross(n).normalized()
    y = n.cross(x)
    return Matrix((x, y, n)).transposed().to_4x4()
