# Boom Tender No. 22: a low petrol pontoon on two charcoal track pods, an oxide cable reel on a
# transverse axle, an exhaust stack at the back left and a swivelling fairlead at the bow, paying
# out a boom of five oxide floats and a small end buoy laid straight forward.
#
# Shell: boom_tender.mojulo.json -> shells/boom_tender.glb (python3 shells.py boom_tender), one
# cast mojulo SDF shell per piece (Hull, Track, Reel), joined, welded and decimated here as the
# rogue kit does (tools/blender/rogues/kit.py on the rogue lane). Small fittings are primitives.
# Spec: hull 3.2 x 2.4 x 1.3 m; reel 1.6 m across, axle along X, top 2.3 m; floats 0.9 m long,
# 0.6 m across, 0.4 m gaps; boom reach 6.5 m from the hull front (y 1.6 to 8.1).
# Refs: docs/art/reference/enemies/boom_tender/ (branch claude/boom-tender-refs).
#
# Meshes, each with its origin at its pivot, under the BoomTender root (ground under hull centre):
#   TenderHull     hull shell, tracks, stack, fairlead and fittings on fleet_paint (the flash surface).
#   TenderReel     spins about its transverse axle; origin on the axle (0, 1.5, 0.5 in Godot).
#   BoomFloat      one float at float 0's place, origin at its centre; the runtime lays the five and
#                  the end buoy from it. Three meshes, one surface each: the enemy class's 3 draws.
# Blender +Y is forward (Godot -Z), +Z up. Vertex colours are the albedo on every slot.
# Provenance: mojulo SDF shell plus procedural bmesh, no external mesh or texture.
#
# blender -b --factory-startup -P enemy_boom_tender.py -- [--out file.glb]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import common
import crew
import polish
from common import Part

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.7}
polish.enable(detail=1, subsurf=0, bevel=0.025, bevel_angle=40.0, sharp_angle=55.0)
root = common.empty("BoomTender")

WEAR = common.mix("petrol", "sandstone", 0.55)
DEEP = common.mix("petrol", "charcoal", 0.35)
WORN = common.mix("charcoal", "bone", 0.3)
CABLE = common.mix("charcoal", "oxide", 0.12)
AXLE = Vector((0, -0.5, 1.5))      # reel axle centre; drum top 1.5 + 0.8 = 2.3 m
WOUND = 0.65                       # outer radius of the wound cable
PIVOT = Vector((0, 1.40, 0.70))    # fairlead turntable on the bow gully floor
LINE_Z = 0.85                      # cable and float centre height
FLOAT_LEN, FLOAT_R, GAP = 0.9, 0.3, 0.4
BOOM_START = 1.62                  # rear tip of float 0, just past the hull front (1.6)
BUOY_R = 0.16
FLOATS = [BOOM_START + FLOAT_LEN / 2 + i * (FLOAT_LEN + GAP) for i in range(5)]
BUOY_Y = FLOATS[-1] + FLOAT_LEN / 2 + 0.06 + BUOY_R   # tip at 8.10
HULL_TRIS, TRACK_TRIS, REEL_TRIS = 2700, 700, 1600
BUDGET = 10000


# --- shell helpers, adapted from the rogue kit -------------------------------------------

def import_shells(kind):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, "shells", kind + ".glb"))
    new = sorted(set(bpy.data.objects) - before, key=lambda o: o.name)
    pieces = {}
    for obj in new:
        if obj.type == "MESH" and "_" in obj.name:
            pieces.setdefault(obj.name.split("_", 1)[0], []).append(obj)
    bpy.context.view_layer.update()
    return pieces, new


def shell_mesh(objs, tris):
    """Joins one piece's term meshes into one welded shell decimated to about `tris`."""
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
    """Copies a shell bmesh into `part` unbevelled, painting each vertex by paint(co, normal)."""
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


def lathe(part, slot, profile, centre, axis="y", segs=16, color=None):
    """Solid of revolution: profile is [(offset along axis, radius)], radius 0 at closed ends."""
    c = Vector(centre)
    a = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[axis]
    u = Vector((0, 0, 1)) if axis != "z" else Vector((1, 0, 0))
    w = a.cross(u)
    rows = []
    for t, r in profile:
        if r <= 1e-6:
            rows.append([part.bm.verts.new(c + a * t)])
        else:
            rows.append([part.bm.verts.new(c + a * t + (u * math.cos(2 * math.pi * k / segs)
                                                       + w * math.sin(2 * math.pi * k / segs)) * r)
                         for k in range(segs)])
    faces = []
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(segs):
            j = (k + 1) % segs
            if len(r0) == 1:
                faces.append(part.bm.faces.new((r0[0], r1[j], r1[k])))
            elif len(r1) == 1:
                faces.append(part.bm.faces.new((r0[k], r0[j], r1[0])))
            else:
                faces.append(part.bm.faces.new((r0[k], r0[j], r1[j], r1[k])))
    bmesh.ops.recalc_face_normals(part.bm, faces=faces)
    return part.paint(faces, slot, color)


# --- paint ------------------------------------------------------------------------------

def hull_paint(c, n):
    if c.x < -0.75 and c.y < -1.15 and c.z > 1.37:
        return WORN if c.z > 2.0 else "charcoal"                       # exhaust stack
    if abs(c.x) < 0.73 and -1.4 < c.y < 0.4 and c.z < 1.27:
        return DEEP                                                    # reel well
    if abs(c.x) < 0.24 and c.y > 0.55 and c.z < 1.27:
        return DEEP                                                    # cable gully
    if c.z < 0.42:
        return common.mix("petrol", "charcoal", 0.45)                  # belly grime
    if c.z > 1.2 and (abs(c.x) > 1.06 or abs(c.y) > 1.46):
        return WEAR                                                    # deck edge wear
    if c.z > 1.36 and 0.66 < abs(c.x) < 0.9:
        return WEAR if n.z > 0.7 else "petrol"                         # reel pedestals
    if c.y > 1.2 and c.z < 0.8:
        return common.mix("petrol", "sandstone", 0.3)                  # bow scuffs
    return "petrol"


def track_paint(c, n):
    return WORN if n.z > 0.75 else "charcoal"


def reel_paint(c, n):
    r = Vector((c.y - AXLE.y, c.z - AXLE.z)).length
    if abs(c.x) > 0.74:
        return "charcoal"                                              # axle stubs
    if abs(c.x) > 0.64:
        return "brass" if r < 0.24 else "oxide"                        # hub bosses
    if abs(c.x) > 0.555 or r > 0.67:
        return common.mix("oxide", "sandstone", 0.35) if r > 0.77 else "oxide"   # flanges
    return CABLE


pieces, imported = import_shells("boom_tender")
shells = {"Hull": shell_mesh(pieces["Hull"], HULL_TRIS), "Track": shell_mesh(pieces["Track"], TRACK_TRIS),
          "Reel": shell_mesh(pieces["Reel"], REEL_TRIS)}
for obj in imported:
    bpy.data.objects.remove(obj, do_unlink=True)

# --- TenderHull ---------------------------------------------------------------------------
hull = Part("TenderHull")
add_shell(hull, shells["Hull"], "fleet_paint", hull_paint)
add_shell(hull, shells["Track"], "fleet_paint", track_paint)
for s in (-1, 1):
    # Grouser ribs and road-wheel hubs on the outer face of each track pod (unbevelled: budget).
    with hull.region(bevel=0, subsurf=0, detail=1):
        for k in range(12):
            y = -1.27 + k * 0.23
            hull.box("fleet_paint", (0.03, 0.05, 0.36), loc=(s * 1.185, y, 0.24), color=WORN)
        for y in (-1.0, -0.33, 0.33, 1.0):
            hull.cyl("fleet_paint", 0.12, 0.12, 0.04, segs=10, loc=(s * 1.195, y, 0.24), rot=(0, math.pi / 2, 0),
                     color="charcoal")
            hull.cyl("fleet_paint", 0.045, 0.045, 0.03, segs=6, loc=(s * 1.225, y, 0.24), rot=(0, math.pi / 2, 0),
                     color="brass")
    # Brass bearing caps on the reel pedestals, deck bollards.
    hull.cyl("fleet_paint", 0.13, 0.11, 0.04, segs=12, loc=(s * 0.88, AXLE.y, AXLE.z), rot=(0, math.pi / 2, 0),
             color="brass")
    for y in (1.2, -0.95):
        hull.cyl("fleet_paint", 0.06, 0.06, 0.12, segs=8, loc=(s * 1.0, y, 1.39), color="brass")
        hull.cyl("fleet_paint", 0.085, 0.085, 0.025, segs=8, loc=(s * 1.0, y, 1.46), color="brass")
# Stack collar, crew number both sides, one HIRED by the 22 (left) and one on the reel housing.
hull.cyl("fleet_paint", 0.125, 0.125, 0.05, segs=10, loc=(-0.92, -1.35, 1.62), color="brass")
for s in (-1, 1):
    crew.stencil(hull, "fleet_paint", "22", (s * 1.2, 0.3, 0.8), (s, 0, 0), 0.42, "bone",
                 depth=0.02, resolution=1)
crew.stencil(hull, "fleet_paint", "HIRED", (-1.2, 0.95, 0.8), (-1, 0, 0), 0.09, "bone",
             depth=0.02, resolution=1)
crew.stencil(hull, "fleet_paint", "HIRED", (-0.85, AXLE.y + 0.32, AXLE.z - 0.12), (-1, 0, 0), 0.05, "bone",
             depth=0.02, resolution=1)
# Paid-out cable from the drum's upper tangent to the fairlead's rear rollers.
feed = Vector((0, 1.27, LINE_Z))
d = AXLE - feed
ang = math.atan2(d.z, d.y) - math.asin(WOUND / d.length)   # the upper tangent line's heading from the feed
tangent = AXLE + Vector((0, math.sin(ang), -math.cos(ang))) * WOUND
hull.rod("fleet_paint", tuple(tangent), tuple(feed), 0.03, segs=6, color=CABLE)
clear = tangent.z + (feed.z - tangent.z) * (0.57 - tangent.y) / (feed.y - tangent.y)
# Fairlead turntable on the bow gully floor (fixed; the boom swings at the runtime pivot).
fair = hull  # the fairlead rides the hull: one draw
fair.bevel = 0.0
p = PIVOT
TOP = 1.46                         # cheek tops stand proud of the 1.3 m deck so the fairlead reads
fair.cyl("fleet_paint", 0.19, 0.19, 0.05, segs=14, loc=(0, p.y, p.z + 0.025), color="brass")
fair.cyl("fleet_paint", 0.15, 0.15, 0.03, segs=12, loc=(0, p.y, p.z + 0.065), color="charcoal")
for s in (-1, 1):
    fair.box("fleet_paint", (0.035, 0.30, TOP - p.z - 0.08), loc=(s * 0.13, p.y, (TOP + p.z + 0.08) / 2), color="charcoal")
    fair.box("fleet_paint", (0.04, 0.31, 0.03), loc=(s * 0.13, p.y, TOP), color="brass")
    for dz in (0.075, -0.075):
        fair.cyl("fleet_paint", 0.035, 0.035, 0.02, segs=8, loc=(s * 0.155, p.y - 0.09, LINE_Z + dz),
                 rot=(0, math.pi / 2, 0), color="brass")
    # Vertical guide rollers at the mouth.
    fair.cyl("fleet_paint", 0.035, 0.035, TOP - p.z - 0.12, segs=8, loc=(s * 0.068, p.y + 0.11, (TOP + p.z + 0.08) / 2),
             color="charcoal")
    fair.cyl("fleet_paint", 0.045, 0.045, 0.025, segs=8, loc=(s * 0.068, p.y + 0.11, TOP - 0.02), color="brass")
for dz in (0.075, -0.075):
    fair.cyl("fleet_paint", 0.035, 0.035, 0.23, segs=8, loc=(0, p.y - 0.09, LINE_Z + dz), rot=(0, math.pi / 2, 0),
             color=WORN)
fair.box("fleet_paint", (0.3, 0.05, 0.035), loc=(0, p.y + 0.11, TOP), color="charcoal")
fair.rod("fleet_paint", (0, p.y - 0.13, LINE_Z), (0, BOOM_START, LINE_Z), 0.03, segs=6, color=CABLE)

bmesh.ops.recalc_face_normals(hull.bm, faces=hull.bm.faces[:])
hull_obj = hull.to_object(parent=root)

# --- TenderReel ---------------------------------------------------------------------------
reel = Part("TenderReel")
reel.bevel = 0.0
add_shell(reel, shells["Reel"], "paint", reel_paint)
for s in (-1, 1):
    for k in range(6):
        a = 2 * math.pi * k / 6
        reel.cyl("paint", 0.03, 0.03, 0.03, segs=6,
                 loc=(s * 0.635, AXLE.y + 0.5 * math.cos(a), AXLE.z + 0.5 * math.sin(a)),
                 rot=(0, math.pi / 2, 0), color="brass")
reel_obj = reel.to_object(origin=tuple(AXLE), parent=root)

# --- BoomFloat -----------------------------------------------------------------------------
# One float, at float 0's place, with cable stubs to half the gap each side: boom_tender.gd lays
# five copies along the boom and a small one as the end buoy, so the boom is one draw.
L2 = FLOAT_LEN / 2
FLOAT_PROFILE = [(-L2, 0.0), (-L2 + 0.012, 0.1), (-L2 + 0.04, 0.19), (-L2 + 0.09, 0.26), (-L2 + 0.15, FLOAT_R),
                 (L2 - 0.15, FLOAT_R), (L2 - 0.09, 0.26), (L2 - 0.04, 0.19), (L2 - 0.012, 0.1), (L2, 0.0)]
f = Part("BoomFloat")
f.bevel = 0.0
c = Vector((0, FLOATS[0], LINE_Z))
lathe(f, "paint", FLOAT_PROFILE, c, segs=14, color="oxide")
f.ring("paint", FLOAT_R - 0.02, FLOAT_R + 0.014, 0.16, segs=14, loc=tuple(c), rot=(math.pi / 2, 0, 0),
       color="hazard")
f.cyl("paint", 0.055, 0.045, 0.05, segs=8, loc=tuple(c + Vector((0, 0, FLOAT_R + 0.035))), color="brass")
f.uv("paint", 0.05, u=6, v=4, loc=tuple(c + Vector((0, 0, FLOAT_R + 0.09))), color="brass")
for sgn in (-1, 1):
    tip = c + Vector((0, sgn * (L2 + 0.03), 0))
    f.ring("paint", 0.025, 0.055, 0.025, segs=6, loc=tuple(tip), rot=(0, math.pi / 2, 0), color="charcoal")
    f.rod("paint", tuple(tip), tuple(c + Vector((0, sgn * (L2 + GAP / 2), 0))), 0.025, segs=6, color=CABLE)
float_obj = f.to_object(origin=tuple(c), parent=root)

bpy.context.view_layer.update()
meshes = [hull_obj, reel_obj, float_obj]
tris = common.tri_total(root)
print("BOOM_TENDER", tris, "T", {o.name: common.tris(o) for o in meshes})
print("BOOM_TENDER cable clearance at gully mouth z %.3f, tangent %s" % (clear, tuple(round(v, 3) for v in tangent)))
if tris > BUDGET or "fleet_paint" not in [m.name for m in hull_obj.data.materials]:
    raise SystemExit("boom tender budget or slot contract broken")
opts = common.args()
common.export(root, opts["out"] or os.path.join(common.MODELS, "world_one", "enemy_boom_tender.glb"))
