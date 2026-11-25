"""The crew kit: the parts every Fleet animal crew figure and hired machine shares.

A crew figure is a body the kind owns (barrel, tool, pack) plus parts from here: the
head with its snout and ears, the cast number and the HIRED stamp (and a keeper's
number plate). A kind's recipe builds its own body and tool and calls these, so a new
crew kind in any world is its body plus a few lines, and a head swap is one call.

Space is the recipes' Blender space: +Z up, the crew faces -Y (the exporter turns +Y
into Godot -Z). Recipes that author in Godot space pass points through their own g().
"""
import math

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


HALF_PI = 1.5707963267948966


def gauge_head(part, loc, radius):
    """Rack magnet: the rated-load dial, a round cast gauge on edge facing forward with a
    bone face and a charcoal needle standing past its mark."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.42, r * 0.5, r * 0.85, segs=8, loc=c + Vector((0, 0, -r * 0.625)))
        dial = c + Vector((0, 0, r * 0.45))
        part.cyl("fleet_paint", r * 1.12, r * 1.12, r * 0.5, segs=16, loc=dial, rot=(HALF_PI, 0, 0))
        front = dial.y - r * 0.25
        part.cyl("paint", r * 0.9, r * 0.9, 0.04, segs=16, loc=(c.x, front - 0.01, dial.z),
                 rot=(HALF_PI, 0, 0), color="bone")
        for a in (-0.9, -0.3, 0.3, 0.9):
            tick = dial + Vector((r * 0.72 * math.sin(a), 0, r * 0.72 * math.cos(a)))
            part.box("paint", (0.04, 0.03, r * 0.22), loc=(tick.x, front - 0.035, tick.z), rot=(0, a, 0),
                     color=CHAR)
        tip = dial + Vector((r * 0.62 * math.sin(1.25), 0, r * 0.62 * math.cos(1.25)))
        part.rod("paint", (dial.x, front - 0.04, dial.z), (tip.x, front - 0.04, tip.z), 0.035, segs=4, color=CHAR)
        part.cyl("paint", r * 0.16, r * 0.16, 0.06, segs=8, loc=(dial.x, front - 0.04, dial.z),
                 rot=(HALF_PI, 0, 0), color=CHAR)


def bollard_head(part, loc, radius):
    """Mooring winch: a mooring bollard, a waisted post under a wide cap, a bone line made
    fast round its neck."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.62, r * 0.52, r * 1.55, segs=10, loc=c + Vector((0, 0, -r * 0.275)))
        part.cyl("paint", r * 1.18, r * 1.05, r * 0.38, segs=12, loc=c + Vector((0, 0, r * 0.66)), color=CHAR)
        for z in (-0.2, 0.08):
            part.ring("paint", r * 0.5, r * 0.68, r * 0.16, segs=12, loc=c + Vector((0, 0, r * z)), color="bone")


def insulator_head(part, loc, radius):
    """Fish fence layer: the live line's insulator, three bone sheds stacked on a charcoal
    stem under a charcoal terminal cap."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("paint", r * 0.3, r * 0.3, r * 2.55, segs=8, loc=c + Vector((0, 0, r * 0.225)), color=CHAR)
        for k, z in ((1.15, -0.35), (0.98, 0.25), (0.8, 0.85)):
            part.cyl("paint", r * k, r * k * 0.45, r * 0.32, segs=12, loc=c + Vector((0, 0, r * z)), color="bone")
        part.cyl("fleet_paint", r * 0.42, r * 0.3, r * 0.4, segs=8, loc=c + Vector((0, 0, r * 1.4)))


def sheave_head(part, loc, radius):
    """Fish lift: the hoist block, a grooved charcoal sheave turning between two cast
    cheeks, with the bone line in its groove."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        hub = c + Vector((0, 0, r * 0.35))
        for side in (-1, 1):
            part.box("fleet_paint", (r * 0.28, r * 1.5, r * 2.1), loc=c + Vector((side * r * 0.62, 0, 0)))
        part.cyl("paint", r * 1.05, r * 1.05, r * 0.7, segs=16, loc=hub, rot=(0, HALF_PI, 0), color=CHAR)
        part.ring("paint", r * 1.0, r * 1.12, r * 0.3, segs=16, loc=hub, rot=(0, HALF_PI, 0), color="bone")
        part.cyl("paint", r * 0.22, r * 0.22, r * 1.5, segs=8, loc=hub, rot=(0, HALF_PI, 0), color=CHAR)


def lifting_beam_head(part, loc, radius):
    """Stoplog setter: the stoplog grab, a cast lifting beam across the shoulders with a
    charcoal hook dropping at each end, on a short neck."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.5, r * 0.55, r * 1.15, segs=8, loc=c + Vector((0, 0, -r * 0.475)))
        beam = c + Vector((0, 0, r * 0.35))
        part.box("fleet_paint", (r * 3.0, r * 0.7, r * 0.55), loc=beam)
        for side in (-1, 1):
            end = beam + Vector((side * r * 1.3, 0, 0))
            part.rod("paint", tuple(end), tuple(end + Vector((0, 0, -r * 0.75))), r * 0.09, segs=5, color=CHAR)
            part.ring("paint", r * 0.12, r * 0.3, r * 0.14, segs=10, loc=end + Vector((0, 0, -r * 0.9)),
                      rot=(HALF_PI, 0, 0), arc=(0.0, 4.4), color=CHAR)
        part.ring("paint", r * 0.14, r * 0.32, r * 0.14, segs=10, loc=beam + Vector((0, 0, r * 0.5)),
                  rot=(HALF_PI, 0, 0), color=CHAR)


def handwheel_head(part, loc, radius):
    """Flap tender: the gate valve, a cast bonnet with a spoked charcoal handwheel standing on
    its front face, so the wheel still faces the player under a carried load."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.75, r * 0.45, r * 1.45, segs=8, loc=c + Vector((0, 0, -r * 0.325)))
        hub = c + Vector((0, -r * 0.95, -r * 0.3))
        part.rod("paint", tuple(c + Vector((0, -r * 0.4, -r * 0.3))), tuple(hub), r * 0.14, segs=6, color=CHAR)
        part.ring("paint", r * 0.62, r * 0.82, r * 0.16, segs=16, loc=hub, rot=(HALF_PI, 0, 0), color=CHAR)
        for k in range(3):
            a = k * math.pi / 3
            d = Vector((math.cos(a), 0, math.sin(a))) * r * 0.7
            part.rod("paint", tuple(hub - d), tuple(hub + d), r * 0.07, segs=4, color=CHAR)


def lantern_head(part, loc, radius):
    """Heaving-line thrower: the lock keeper's signal lantern, a cast lamp housing with a bone
    lens behind three charcoal guard bars, under a charcoal cowl and its carry ring."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.8, r * 0.7, r * 1.65, segs=10, loc=c + Vector((0, 0, -r * 0.225)))
        part.cyl("paint", r * 0.62, r * 0.62, r * 0.7, segs=10, loc=c + Vector((0, -r * 0.18, 0)), color="bone")
        for a in (-0.7, 0.0, 0.7):
            x, y = r * 0.82 * math.sin(a), -r * 0.82 * math.cos(a)
            part.box("paint", (r * 0.12, r * 0.12, r * 1.0), loc=c + Vector((x, y, 0)), color=CHAR)
        part.cyl("paint", r * 1.0, r * 0.35, r * 0.45, segs=10, loc=c + Vector((0, 0, r * 0.82)), color=CHAR)
        part.ring("paint", r * 0.2, r * 0.36, r * 0.12, segs=10, loc=c + Vector((0, 0, r * 1.2)),
                  rot=(HALF_PI, 0, 0), color=CHAR)


def screen_head(part, loc, radius):
    """Trash screen: the intake rack, a square cast frame of charcoal bars standing on edge
    and facing forward."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.45, r * 0.5, r * 0.9, segs=8, loc=c + Vector((0, 0, -r * 0.6)))
        frame = c + Vector((0, 0, r * 0.45))
        w = r * 2.2
        for sz in (-1, 1):
            part.box("fleet_paint", (w, r * 0.35, r * 0.22), loc=frame + Vector((0, 0, sz * r * 0.8)))
        for k in range(5):
            x = -w / 2 + r * 0.11 + k * (w - r * 0.22) / 4
            part.box("paint", (r * 0.1, r * 0.16, r * 1.5), loc=frame + Vector((x, 0, 0)), color=CHAR)


def jet_deflector_head(part, loc, radius):
    """Outlet guard (deflector): the flip-bucket nozzle that turned the outlet jet off the
    bank, a cast elbow rising from the shoulders to a flared mouth with a charcoal lip."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.62, r * 0.5, r * 1.15, segs=10, loc=c + Vector((0, 0, -r * 0.475)))
        bend = c + Vector((0, 0, r * 0.4))
        mouth = bend + Vector((0, -r * 0.65, r * 0.3))
        part.rod("fleet_paint", tuple(c + Vector((0, 0, r * 0.05))), tuple(bend), r * 0.38, segs=10)
        part.uv("fleet_paint", r * 0.4, u=10, v=6, loc=bend)
        part.rod("fleet_paint", tuple(bend), tuple(mouth), r * 0.38, segs=10, r2=r * 0.62)
        lip = mouth + (mouth - bend).normalized() * r * 0.02
        part.ring("paint", r * 0.5, r * 0.66, r * 0.12, segs=12, loc=lip,
                  rot=Vector((0, 0, 1)).rotation_difference(mouth - bend).to_euler(), color=CHAR)


def current_meter_head(part, loc, radius):
    """Current meter (gyro jammer): the cup rotor that spun in the stream to read its flow,
    three charcoal arms with a bone cup each, on a cast bearing."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.55, r * 0.4, r * 1.35, segs=10, loc=c + Vector((0, 0, -r * 0.375)))
        hub = c + Vector((0, 0, r * 0.45))
        part.cyl("paint", r * 0.25, r * 0.25, r * 0.35, segs=8, loc=hub, color=CHAR)
        for deg in (30, 150, 270):
            a = math.radians(deg)
            d = Vector((math.cos(a), math.sin(a), 0))
            tip = hub + d * r * 0.95
            part.rod("paint", tuple(hub), tuple(tip), r * 0.07, segs=4, color=CHAR)
            side = Vector((-d.y, d.x, 0))
            part.cyl("paint", r * 0.32, r * 0.12, r * 0.4, segs=8, loc=tip,
                     rot=Vector((0, 0, 1)).rotation_difference(side).to_euler(), color="bone")


def brush_head(part, loc, radius):
    """Screen sweeper (swatter): the sweep's brush, a cast stock across the head with a row
    of charcoal bristle tufts standing up from it."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.6, r * 0.5, r * 1.2, segs=10, loc=c + Vector((0, 0, -r * 0.45)))
        stock = c + Vector((0, 0, r * 0.3))
        part.box("fleet_paint", (r * 2.0, r * 0.6, r * 0.4), loc=stock)
        for k in range(5):
            x = -r * 0.8 + k * r * 0.4
            part.cyl("paint", r * 0.17, r * 0.1, r * 0.75, segs=6, loc=stock + Vector((x, 0, r * 0.55)), color=CHAR)


def buoy_head(part, loc, radius):
    """Buoy lifter (winch drone): a channel buoy, a cast float with a bone day band under a
    charcoal cone and its lamp cage."""
    with part.region(subsurf=0, detail=1):
        c, r = Vector(loc), radius
        part.cyl("fleet_paint", r * 0.7, r * 0.8, r * 1.2, segs=12, loc=c + Vector((0, 0, -r * 0.45)))
        part.cyl("paint", r * 0.82, r * 0.82, r * 0.25, segs=12, loc=c + Vector((0, 0, -r * 0.25)), color="bone")
        part.cyl("paint", r * 0.72, r * 0.12, r * 0.8, segs=12, loc=c + Vector((0, 0, r * 0.55)), color=CHAR)
        lamp = c + Vector((0, 0, r * 1.1))
        part.uv("paint", r * 0.18, u=8, v=5, loc=lamp, color="bone")
        for k in range(3):
            a = k * math.tau / 3
            d = Vector((math.cos(a), math.sin(a), 0)) * r * 0.24
            part.rod("paint", tuple(lamp + d + Vector((0, 0, -r * 0.22))), tuple(lamp + d + Vector((0, 0, r * 0.22))),
                     r * 0.035, segs=4, color=CHAR)


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
    return stencil(part, slot, text, loc, normal, height, color, resolution=2)


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
