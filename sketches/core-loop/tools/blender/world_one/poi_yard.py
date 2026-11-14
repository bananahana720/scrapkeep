# Point of interest props for world 1 that are built by hand, because a mesh generator returns thin shapes as lumps
# and a box is cheaper to build than to generate:
#   poi_fence_panel.glb   one repeatable stocktake yard fence panel, 6.2 m wide and 2.5 m tall, repeated every 6.2 m so the concrete feet touch: two scrap posts on
#                         concrete feet, a top and a bottom rail, and a diamond lattice standing in for chain-link.
#                         The origin is on the ground at the panel's centre; it runs along X, so panels butt post to post.
#   poi_survey_stake.glb  one survey stake, 3.2 m tall: a slim post, a striped cap and a stiff pennant, bright enough to
#                         read at speed against brown concrete and sand. One rigid mesh, origin at the foot, so the
#                         game can knock it flat by turning it about its origin.
#   poi_ring_flag.glb, poi_siren_mast.glb, poi_furnace_stacks.glb, poi_tagged_crate.glb and its four pieces,
#   poi_req_locker.glb and poi_req_locker_door.glb: the Brindle arena surroundings (W1-104); each builder's comment
#   gives its size and where its origin is.
# Each is one mesh on one material named paint with linear COLOR_0 and no texture, as the park props and the Tripo props
# (tools/tripo/tripo_prop.py) are; the loader sets vertex colour as albedo. Metres; Godot (X,Y,Z) -> Blender (X,-Z,Y).
#
#   blender -b --factory-startup --python-exit-code 1 -P sketches/core-loop/tools/blender/world_one/poi_yard.py -- [--out DIR]
import json
import math
import os
import sys
import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "world_one")

# sRGB picks from the Fleet set (STORY-MAP section 3): petrol-green enamel, charcoal, concrete, one warning orange, bone white
def lin(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

GREEN, CHAR, CONC, ORANGE, BONE, WIRE = lin("3f6f68"), lin("2e3033"), lin("8d8a84"), lin("e8742a"), lin("ece4d2"), lin("9aa3a6")


def box(bm, col, size, at, rot=None):
    m = Matrix.Translation(Vector(at)) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    geo = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    cl = bm.loops.layers.float_color.verify()
    for f in {f for v in geo["verts"] for f in v.link_faces}:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


def cylinder(bm, col, radius, height, at, sides=8):
    geo = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=height,
                                matrix=Matrix.Translation(Vector((at[0], at[1], at[2] + height / 2))))
    cl = bm.loops.layers.float_color.verify()
    for f in {f for v in geo["verts"] for f in v.link_faces}:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


FILES = {"FencePanel": "poi_fence_panel.glb", "SurveyStake": "poi_survey_stake.glb", "RingFlag": "poi_ring_flag.glb",
         "SirenMast": "poi_siren_mast.glb", "FurnaceStacks": "poi_furnace_stacks.glb"}
BRASS, RUST, SOOT, GLOW = lin("c9a24a"), lin("a8492b"), lin("4a4441"), lin("ff9a3c")


def cone(bm, col, r1, r2, height, at, sides=8, rot=None):
    m = Matrix.Translation(Vector(at)) @ (rot or Matrix.Identity(4)) @ Matrix.Translation(Vector((0, 0, height / 2)))
    geo = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r1, radius2=r2, depth=height, matrix=m)
    cl = bm.loops.layers.float_color.verify()
    for f in {f for v in geo["verts"] for f in v.link_faces}:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


def wedge(bm, col, pts_side, thick):
    # a flat shape given as (x, z) points, extruded `thick` along Y about Y = 0
    cl = bm.loops.layers.float_color.verify()
    front = [bm.verts.new(Vector((x, -thick / 2, z))) for x, z in pts_side]
    back = [bm.verts.new(Vector((x, thick / 2, z))) for x, z in pts_side]
    n = len(pts_side)
    faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    for i in range(n):
        faces.append(bm.faces.new([front[i], back[i], back[(i + 1) % n], front[(i + 1) % n]]))
    for f in faces:
        for lp in f.loops:
            lp[cl] = (*col, 1.0)


def write(name, build):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new(); build(bm)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    paint = bpy.data.materials.new("paint"); paint.use_backface_culling = False; paint.diffuse_color = (1, 1, 1, 1); me.materials.append(paint)
    me.color_attributes.active_color = me.color_attributes[0]; me.color_attributes.render_color_index = 0
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    root = bpy.data.objects.new(name + "Root", None); bpy.context.scene.collection.objects.link(root); ob.parent = root
    path = os.path.join(out, FILES[name])
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    xs = [v.co for v in me.vertices]
    size = [round(max(c[k] for c in xs) - min(c[k] for c in xs), 2) for k in range(3)]
    print("POI " + json.dumps({"out": os.path.basename(path), "tris": len(me.polygons), "verts": len(me.vertices), "size_m": size}))


def fence(bm):
    W, H = 6.0, 2.5
    for sx in (-1, 1):  # a post at each end, wholly on this panel; panels repeat every 6.2 m, feet touching
        box(bm, CONC, (0.5, 0.5, 0.25), (sx * (W / 2 - 0.15), 0, 0.125))
        box(bm, GREEN, (0.22, 0.22, H), (sx * (W / 2 - 0.15), 0, H / 2))
        box(bm, ORANGE, (0.26, 0.26, 0.14), (sx * (W / 2 - 0.15), 0, H - 0.2))
    box(bm, CHAR, (W - 0.5, 0.1, 0.1), (0, 0, H - 0.35))
    box(bm, CHAR, (W - 0.5, 0.1, 0.1), (0, 0, 0.35))
    # the lattice: bars leaning both ways between the rails, thick enough to read as mesh from the chase camera
    lo, hi = 0.4, H - 0.4
    span = hi - lo
    n = 9
    for k in range(n):
        x0 = -W / 2 + 0.4 + (W - 0.8) * k / (n - 1)
        for lean in (-1, 1):
            x1 = x0 + lean * span
            a, b = max(-W / 2 + 0.3, min(W / 2 - 0.3, x1)), x0
            top = lo + abs(a - b)  # a bar that would leave the panel stops at the post
            length = math.hypot(a - b, top - lo)
            if length < 0.3:
                continue
            ang = math.atan2(top - lo, a - b)
            box(bm, WIRE, (length, 0.04, 0.05), ((a + b) / 2, 0, (lo + top) / 2), Matrix.Rotation(-ang, 4, "Y"))


def stake(bm):
    cylinder(bm, CONC, 0.16, 0.12, (0, 0, 0))
    cylinder(bm, BONE, 0.045, 2.6, (0, 0, 0.1), 6)
    for k in range(4):  # the striped cap: four bands, orange and bone, so it reads as a marker at speed
        cylinder(bm, ORANGE if k % 2 == 0 else BONE, 0.11, 0.14, (0, 0, 2.6 + 0.14 * k))
    # a stiff pennant, one wedge thick enough to show from behind
    cl = bm.loops.layers.float_color.verify()
    pts = [Vector((0.05, y, z)) for y in (-0.02, 0.02) for z in (3.16, 2.72)] + [Vector((0.72, y, 2.94)) for y in (-0.02, 0.02)]
    vs = [bm.verts.new(p) for p in pts]
    for idx in ((0, 1, 4), (2, 5, 3), (0, 4, 5, 2), (1, 3, 5, 4), (0, 2, 3, 1)):
        f = bm.faces.new([vs[i] for i in idx])
        for lp in f.loops:
            lp[cl] = (*ORANGE, 1.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def ring_flag(bm):
    # A ring edge marker, 2 m tall: a weighted dome foot, a spring, a short upright post, and one broad orange pennant with a bone stripe.
    cone(bm, CHAR, 0.34, 0.2, 0.16, (0, 0, 0), 10)
    for k in range(4):
        cylinder(bm, WIRE if k % 2 == 0 else CHAR, 0.075, 0.06, (0, 0, 0.16 + 0.06 * k), 8)
    cylinder(bm, BONE, 0.04, 1.6, (0, 0, 0.4), 6)
    cylinder(bm, ORANGE, 0.07, 0.08, (0, 0, 1.92), 6)
    wedge(bm, ORANGE, [(0.04, 1.95), (0.04, 1.25), (0.95, 1.6)], 0.04)
    wedge(bm, BONE, [(0.04, 1.68), (0.04, 1.52), (0.5, 1.6)], 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def siren_mast(bm):
    # The muster siren, 6 m tall: a concrete foot, a petrol-green pole with climbing rungs, a hand-crank box at hand
    # height, a brass horn at the top pointing along +X, and a tally flag under it.
    box(bm, CONC, (0.9, 0.9, 0.3), (0, 0, 0.15))
    cylinder(bm, GREEN, 0.11, 5.3, (0, 0, 0.3), 8)
    for k in range(7):
        box(bm, CHAR, (0.5, 0.05, 0.05), (0, 0, 1.6 + 0.45 * k))
    box(bm, RUST, (0.42, 0.34, 0.5), (0, -0.2, 1.25))
    cylinder(bm, CHAR, 0.03, 0.3, (0.3, -0.2, 1.2), 6)
    box(bm, BRASS, (0.08, 0.08, 0.2), (0.3, -0.2, 1.5))
    box(bm, CHAR, (0.5, 0.4, 0.4), (0, 0, 5.35))
    cone(bm, BRASS, 0.14, 0.62, 1.1, (0.2, 0, 5.35), 12, Matrix.Rotation(math.radians(90), 4, "Y"))
    cone(bm, CHAR, 0.6, 0.64, 0.06, (1.3, 0, 5.35), 12, Matrix.Rotation(math.radians(90), 4, "Y"))
    cylinder(bm, ORANGE, 0.14, 0.12, (0, 0, 5.88), 8)
    wedge(bm, ORANGE, [(-0.1, 5.0), (-0.1, 4.2), (-1.3, 4.2), (-1.0, 4.6), (-1.3, 5.0)], 0.05)
    wedge(bm, BONE, [(-0.1, 4.7), (-0.1, 4.5), (-1.1, 4.5), (-1.02, 4.6), (-1.1, 4.7)], 0.06)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def furnace_stacks(bm):
    # The horizon mark east of the flume, 60.2 m tall and read from 600 m: three tapered stacks on one long charging
    # house, soot-dark with a warning band each and a glowing mouth, the middle one tallest.
    box(bm, SOOT, (46.0, 14.0, 9.0), (0, 0, 4.5))
    box(bm, RUST, (46.6, 14.6, 1.2), (0, 0, 9.0))
    for x, h, r in ((-15.0, 46.0, 3.6), (0.0, 60.0, 4.4), (15.0, 52.0, 3.8)):
        cone(bm, SOOT, r, r * 0.62, h - 9.0, (x, 0, 9.0), 10)
        cone(bm, ORANGE, r * 0.74, r * 0.7, 2.4, (x, 0, 9.0 + (h - 9.0) * 0.72), 10)
        cone(bm, GLOW, r * 0.66, r * 0.7, 1.4, (x, 0, h - 1.2), 10)
    for x in (-19.0, -9.0, 9.0, 19.0):
        box(bm, GLOW, (3.0, 14.2, 3.2), (x, 0, 3.4))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


WOOD, WOOD_D = lin("b98a55"), lin("8a6238")


def tagged_crate(bm):
    # A requisition crate, a 1.2 m cube: plank faces inside a darker corner frame, a rust band, and one big brass tag
    # hanging on the front (-Y). The tag is part of this mesh; the game swings the whole crate when it is hit.
    box(bm, WOOD, (1.08, 1.08, 1.08), (0, 0, 0.6))
    for x in (-0.55, 0.55):
        for y in (-0.55, 0.55):
            box(bm, WOOD_D, (0.1, 0.1, 1.2), (x, y, 0.6))
    for z in (0.05, 1.15):
        for y in (-0.55, 0.55):
            box(bm, WOOD_D, (1.2, 0.1, 0.1), (0, y, z))
        for x in (-0.55, 0.55):
            box(bm, WOOD_D, (0.1, 1.2, 0.1), (x, 0, z))
    box(bm, RUST, (1.14, 1.14, 0.12), (0, 0, 0.6))
    box(bm, CHAR, (0.03, 0.03, 0.2), (0.0, -0.61, 0.98))
    box(bm, BRASS, (0.46, 0.05, 0.34), (0.0, -0.63, 0.74))
    box(bm, BONE, (0.3, 0.02, 0.06), (0.0, -0.66, 0.78))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _piece(kind):
    # four pieces a broken crate leaves, each about its own centre so the game can throw and spin it
    def build(bm):
        if kind == "a":  # a corner: two plank faces and the post between them
            box(bm, WOOD, (0.7, 0.08, 0.7), (0.0, -0.31, 0.0)); box(bm, WOOD, (0.08, 0.7, 0.7), (-0.31, 0.0, 0.0))
            box(bm, WOOD_D, (0.1, 0.1, 0.8), (-0.31, -0.31, 0.0))
        elif kind == "b":  # a plank face with a piece of the rust band
            box(bm, WOOD, (0.9, 0.08, 0.6), (0, 0, 0)); box(bm, RUST, (0.94, 0.1, 0.12), (0, 0, 0.05))
            box(bm, WOOD_D, (0.1, 0.1, 0.66), (0.42, 0, 0))
        elif kind == "c":  # the lid, split
            box(bm, WOOD, (0.9, 0.5, 0.08), (0, 0, 0)); box(bm, WOOD_D, (0.96, 0.1, 0.1), (0, 0.24, 0))
            box(bm, WOOD_D, (0.1, 0.56, 0.1), (-0.43, 0, 0))
        else:  # the brass tag on its hook, the piece the player follows
            box(bm, BRASS, (0.46, 0.05, 0.34), (0, 0, -0.09)); box(bm, BONE, (0.3, 0.02, 0.06), (0, -0.03, -0.05))
            box(bm, CHAR, (0.03, 0.03, 0.2), (0, 0.0, 0.16))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return build


def _locker_shell(bm):
    # 3.0 m wide, 2.5 m tall and 1.5 m deep over everything, lamp included; the front (-Y) is open where the door hangs
    box(bm, CONC, (3.0, 1.5, 0.2), (0, 0, 0.1))
    box(bm, GREEN, (2.8, 0.1, 2.0), (0, 0.65, 1.2))
    for x in (-1.35, 1.35):
        box(bm, GREEN, (0.1, 1.4, 2.0), (x, 0, 1.2))
    box(bm, CHAR, (2.9, 1.5, 0.14), (0, 0, 2.27))
    box(bm, GREEN, (2.8, 1.4, 0.1), (0, 0, 0.25))
    box(bm, CHAR, (2.6, 1.2, 0.06), (0, 0, 1.2))  # one shelf, seen when the door is open
    box(bm, BRASS, (0.5, 0.5, 0.4), (-0.7, 0.1, 0.5)); box(bm, BRASS, (0.36, 0.36, 0.3), (0.5, 0.2, 1.38))  # what is inside
    for x in (-1.35, 1.35):
        box(bm, BRASS, (0.12, 0.06, 2.0), (x, -0.72, 1.2))
    box(bm, BRASS, (2.8, 0.06, 0.12), (0, -0.72, 2.14))
    box(bm, ORANGE, (0.3, 0.3, 0.16), (1.0, 0, 2.42))  # the lamp on top


def req_locker(bm):
    _locker_shell(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def req_locker_door(bm):
    # The brass front, 2.56 m by 1.8 m, hinged on its left edge as seen from the front: the origin is the hinge foot,
    # so the game turns the door about its own up axis to pop it. Placed at (-1.28, 0.3, 0.7) in Godot axes on the
    # locker, which is its open front.
    box(bm, BRASS, (2.56, 0.08, 1.8), (1.28, 0, 0.9))
    box(bm, RUST, (2.3, 0.04, 0.16), (1.28, -0.05, 0.9))
    for x in (0.3, 2.26):
        for z in (0.2, 1.6):
            box(bm, CHAR, (0.1, 0.05, 0.1), (x, -0.05, z))
    cone(bm, CHAR, 0.2, 0.2, 0.08, (2.1, -0.06, 0.9), 10, Matrix.Rotation(math.radians(90), 4, "X"))  # the wheel handle
    box(bm, BONE, (0.5, 0.03, 0.3), (0.7, -0.05, 1.4))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _small_crate(bm, at, size=0.8):
    # a rack crate: a plank box, a darker lid rim and one brass tag on its front (-Y)
    x, y, z = at
    box(bm, WOOD, (size, size, size), (x, y, z + size / 2))
    box(bm, WOOD_D, (size + 0.06, size + 0.06, 0.08), (x, y, z + size - 0.04))
    box(bm, BRASS, (0.34, 0.05, 0.26), (x, y - size / 2 - 0.03, z + size * 0.5))
    box(bm, BONE, (0.22, 0.02, 0.05), (x, y - size / 2 - 0.06, z + size * 0.55))


def _tag_rack(bm):
    # 3 m wide, 3 m tall and 2 m deep: four rust angle posts on a concrete slab, two shelves of three tagged crates
    # each, and a striped awning; the tags face the front (-Y)
    box(bm, CONC, (3.0, 2.0, 0.15), (0, 0, 0.075))
    for x in (-1.4, 1.4):
        for y in (-0.9, 0.9):
            box(bm, RUST, (0.12, 0.12, 2.6), (x, y, 1.45))
    for z in (0.5, 1.6):
        box(bm, CHAR, (2.9, 1.9, 0.08), (0, 0, z))
        for k, x in enumerate((-0.92, 0.0, 0.92)):
            _small_crate(bm, (x, -0.25 + 0.1 * ((k + int(z)) % 2), z + 0.04))
    for k in range(5):  # the awning, five stripes sloping to the front
        box(bm, ORANGE if k % 2 == 0 else BONE, (0.6, 2.0, 0.08), (-1.2 + 0.6 * k, 0, 2.85), Matrix.Rotation(math.radians(8), 4, "X"))
    box(bm, RUST, (3.0, 0.1, 0.1), (0, 0.95, 2.95))


def tag_rack(bm):
    _tag_rack(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def tag_rack_leaning(bm):
    # the same rack tipped 14 degrees to its right about its right foot line, with one crate fallen to the ground
    _tag_rack(bm)
    bmesh.ops.transform(bm, matrix=Matrix.Translation((1.5, 0, 0)) @ Matrix.Rotation(math.radians(14), 4, "Y") @ Matrix.Translation((-1.5, 0, 0)), verts=bm.verts)
    low = min(v.co.z for v in bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, -low), verts=bm.verts)
    lo, hi = min(v.co.x for v in bm.verts), max(v.co.x for v in bm.verts)
    bmesh.ops.translate(bm, vec=(-(lo + hi) / 2 - 0.45, 0, 0), verts=bm.verts)
    _small_crate(bm, (hi - (lo + hi) / 2 - 0.45 + 0.5, -0.3, 0.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def scooter_shed(bm):
    # A tiny tin garage, 4 m wide, 3 m deep and 3 m tall with its pennant: petrol-green corrugated walls, a sloping
    # charcoal roof, an open door on the front (-Y) too small for comfort, and a pennant pole on the ridge. The
    # scooter is a second model and stands inside at the origin.
    box(bm, CONC, (4.0, 3.0, 0.12), (0, 0, 0.06))
    box(bm, GREEN, (3.8, 0.1, 2.0), (0, 1.4, 1.1))
    for x in (-1.85, 1.85):
        box(bm, GREEN, (0.1, 2.8, 2.0), (x, 0, 1.1))
    for x in (-1.5, 1.5):
        box(bm, GREEN, (0.8, 0.1, 2.0), (x, -1.4, 1.1))
    box(bm, GREEN, (2.2, 0.1, 0.5), (0, -1.4, 1.85))
    for x in (-1.14, 1.14):
        box(bm, BRASS, (0.08, 0.12, 1.5), (x, -1.42, 0.87))
    box(bm, BRASS, (2.36, 0.12, 0.08), (0, -1.42, 1.62))
    for k in range(7):  # corrugation ribs on the side walls
        for x in (-1.92, 1.92):
            box(bm, WIRE, (0.04, 0.08, 1.9), (x, -1.2 + 0.4 * k, 1.1))
    box(bm, CHAR, (4.0, 3.0, 0.1), (0, 0, 2.2), Matrix.Rotation(math.radians(-6), 4, "X"))
    box(bm, RUST, (4.0, 0.12, 0.12), (0, -1.5, 2.06))
    cylinder(bm, BONE, 0.04, 0.8, (1.5, 0, 2.2), 6)
    wedge(bm, ORANGE, [(1.46, 3.0), (1.46, 2.58), (0.8, 2.79)], 0.04)
    box(bm, ORANGE, (0.3, 0.06, 0.2), (0, -1.47, 1.86))  # the lamp over the door
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


FILES.update({"TaggedCrate": "poi_tagged_crate.glb", "TaggedCratePieceA": "poi_tagged_crate_piece_a.glb", "TaggedCratePieceB": "poi_tagged_crate_piece_b.glb",
              "TaggedCratePieceC": "poi_tagged_crate_piece_c.glb", "TaggedCratePieceD": "poi_tagged_crate_piece_d.glb",
              "ReqLocker": "poi_req_locker.glb", "ReqLockerDoor": "poi_req_locker_door.glb",
              "TagRack": "poi_tag_rack.glb", "TagRackLeaning": "poi_tag_rack_leaning.glb", "ScooterShed": "poi_scooter_shed.glb"})
for _name, _build in (("FencePanel", fence), ("SurveyStake", stake), ("RingFlag", ring_flag), ("SirenMast", siren_mast), ("FurnaceStacks", furnace_stacks),
                      ("TaggedCrate", tagged_crate), ("TaggedCratePieceA", _piece("a")), ("TaggedCratePieceB", _piece("b")), ("TaggedCratePieceC", _piece("c")),
                      ("TaggedCratePieceD", _piece("d")), ("ReqLocker", req_locker), ("ReqLockerDoor", req_locker_door),
                      ("TagRack", tag_rack), ("TagRackLeaning", tag_rack_leaning), ("ScooterShed", scooter_shed)):
    write(_name, _build)
