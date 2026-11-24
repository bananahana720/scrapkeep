# The mend ward's post (W46-18, activities.gd _build_ward): the keepers' mending station that stands in a dead end off
# every line, over the ward's charcoal ring and its verdigris charge fill (both drawn by the game). A keeper repair on
# old works stone (STORY-MAP section 3): a stepped slate plinth bound by an iron strap and copper rivets, a weathered
# iron column with a bolted foot flange, a verdigris mend collar, a mismatched copper patch plate, a hand wheel at
# hand height on the front, a spanner hung on the side, and a flared verdigris lamp head under a wide roof, so the
# outline reads from the chase camera as a lamp post you roll up to and stop at. Copper, not brass: brass tags are the
# Fleet's (STORY-MAP section 2). Never mint (LEGIBILITY section 1): mint means "press now", and a ward asks the ball to
# hold still. Procedural bmesh, vertex coloured, one mesh and one slot (one draw) for ModelKit.whole; every piece is a
# closed solid that shares no vertex with another, so the file is watertight. Metres; Godot (X,Y,Z) -> Blender
# (X,-Z,Y); the front faces +Z; origin on the ground at the middle of the plinth. Fits the 0.9 x 2.4 x 0.9 m post it
# replaces.
#
#   blender -b --factory-startup --python-exit-code 1 -P sketches/core-loop/tools/blender/world_one/mend_ward_post.py -- [--out DIR] [--render DIR]
import math
import os
import sys
import bmesh
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
from common import Part

SLOT = "ward_metal"
common.SLOTS[SLOT] = {"vc": True, "rough": 0.8, "metal": 0.0}

TAU = math.tau
HEX = {"slate_dk": "56636f", "slate": "6f7f8f", "slate_hi": "8a98a6", "iron": "2b2724", "iron_hi": "4a4e4c",
       "iron_rust": "5a4136", "verdigris": "4f7f7a", "verdigris_dk": "365754", "copper": "b77843",
       "copper_dk": "8d5a32", "lamp": "c9d2bf", "charcoal": "242a28"}
FOOT, HEIGHT = 0.9, 2.4
COL_R, COL_Y0, COL_Y1 = 0.18, 0.56, 2.02
WHEEL_Y = 1.62
LIMIT_TRIS, LIMIT_DRAWS = 2000, 1
# The game's ward ring (activities.gd MendWard.RING_M) and the ball (radius 0.92), for the stills only.
RING_M, BALL_R = 5.0, 0.92


def c(name):
    return common.srgb(HEX[name])


def g(x, y, z):
    return (x, -z, y)


def box(p, size, at, color, rot=(0, 0, 0)):
    """A box sized and placed in the Godot frame (x, y up, z)."""
    p.box(SLOT, (size[0], size[2], size[1]), loc=g(*at), rot=rot, color=c(color))


def bolt(p, at, normal, r=0.03, h=0.035, color="copper_dk"):
    n = Vector(normal).normalized()
    a = Vector(at)
    p.rod(SLOT, g(*(a - n * h * 0.4)), g(*(a + n * h)), r, segs=6, color=c(color))


def plinth(p):
    # Two stepped slate blocks, the upper one sunk a hair into the lower so no faces share corners, and a worn cap stone.
    box(p, (FOOT, 0.22, FOOT), (0, 0.11, 0), "slate_dk")
    box(p, (0.76, 0.31, 0.76), (0, 0.365, 0), "slate")
    box(p, (0.6, 0.07, 0.6), (0, 0.545, 0), "slate_hi")
    # The iron strap that binds the upper block, three copper rivets a face.
    box(p, (0.79, 0.08, 0.79), (0, 0.42, 0), "iron")
    for k in range(4):
        a = TAU * k / 4
        n = Vector((math.sin(a), 0.0, math.cos(a)))
        side = Vector((math.cos(a), 0.0, -math.sin(a)))
        for s in (-0.26, 0.0, 0.26):
            at = n * 0.395 + side * s + Vector((0, 0.42, 0))
            bolt(p, tuple(at), tuple(n), r=0.028, h=0.03)
    # Corner chocks on the base, keeper-cut wedges that stop the block walking.
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        at = (0.4 * math.sin(a), 0.265, 0.4 * math.cos(a))
        box(p, (0.12, 0.1, 0.12), at, "iron_rust", rot=(0, 0, a))


def column(p):
    # The iron column, eight flats with one facing the front, tapering a little to its head.
    p.cyl(SLOT, COL_R, COL_R * 0.9, COL_Y1 - COL_Y0, segs=8, loc=g(0, (COL_Y0 + COL_Y1) / 2, 0),
          rot=(0, 0, math.pi / 8), color=c("iron_hi"))
    # Its foot flange, bolted down with eight copper heads.
    p.cyl(SLOT, 0.29, 0.23, 0.1, segs=8, loc=g(0, 0.63, 0), rot=(0, 0, math.pi / 8), color=c("iron"))
    for k in range(8):
        a = TAU * k / 8
        at = (0.25 * math.sin(a), 0.69, 0.25 * math.cos(a))
        bolt(p, at, (0, 1, 0), r=0.024, h=0.025)
    # A rust bleed band where water sat on the flange.
    p.cyl(SLOT, COL_R + 0.008, COL_R * 0.99, 0.12, segs=8, loc=g(0, 0.76, 0), rot=(0, 0, math.pi / 8), color=c("iron_rust"))


def mend_collar(p):
    # The verdigris collar where the column was mended: a fat band with darker lips and six copper bolts round it.
    y = 1.24
    p.cyl(SLOT, 0.255, 0.255, 0.24, segs=12, loc=g(0, y, 0), color=c("verdigris"))
    for dy in (-0.135, 0.135):
        p.ring(SLOT, 0.2, 0.285, 0.04, segs=12, loc=g(0, y + dy, 0), color=c("verdigris_dk"))
    for k in range(6):
        a = TAU * k / 6 + TAU / 12
        n = (math.sin(a), 0.0, math.cos(a))
        bolt(p, (0.255 * n[0], y, 0.255 * n[2]), n, r=0.026, h=0.03, color="copper")
    # The head collar under the lamp.
    p.cyl(SLOT, 0.235, 0.235, 0.08, segs=12, loc=g(0, COL_Y1 - 0.03, 0), color=c("copper_dk"))


def patch(p):
    # A mismatched copper plate bolted over a crack on the front, skewed, four iron bolts.
    at = Vector((0.03, 0.95, 0.178))
    tilt = 0.12
    # A turn about Godot +Z is a turn about Blender -Y.
    box(p, (0.2, 0.26, 0.03), tuple(at), "copper", rot=(0, -tilt, 0))
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x = sx * 0.07 * math.cos(tilt) - sy * 0.1 * math.sin(tilt)
        y = sx * 0.07 * math.sin(tilt) + sy * 0.1 * math.cos(tilt)
        bolt(p, (at.x + x, at.y + y, at.z + 0.015), (0, 0, 1), r=0.02, h=0.02, color="iron")


def wheel(p):
    # The hand wheel on the front, where a keeper's hands go: stem, hub, four spokes and a rim, rubbed copper.
    z = COL_R * 0.95 + 0.14
    p.rod(SLOT, g(0, WHEEL_Y, COL_R * 0.8), g(0, WHEEL_Y, z), 0.035, segs=8, color=c("iron"))
    p.cyl(SLOT, 0.055, 0.055, 0.07, segs=8, loc=g(0, WHEEL_Y, z), rot=(math.pi / 2, 0, 0), color=c("copper_dk"))
    p.ring(SLOT, 0.17, 0.215, 0.045, segs=16, loc=g(0, WHEEL_Y, z), rot=(math.pi / 2, 0, 0), color=c("copper"))
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        p.rod(SLOT, g(0.05 * math.cos(a), WHEEL_Y + 0.05 * math.sin(a), z),
              g(0.18 * math.cos(a), WHEEL_Y + 0.18 * math.sin(a), z), 0.016, segs=5, color=c("copper_dk"))


def spanner(p):
    # A spanner hung on a hook on the right side: the mend's tool, left where the next keeper will want it.
    x = COL_R * 0.95
    p.rod(SLOT, g(x - 0.03, 1.52, 0), g(x + 0.09, 1.52, 0), 0.016, segs=5, color=c("iron"))
    p.beam(SLOT, g(x + 0.08, 1.48, 0), g(x + 0.08, 1.06, 0), 0.055, 0.02, color=c("iron_hi"))
    # The open jaw at its foot, in the side's plane, its gap facing the ground (angle 0 points down after the turn).
    p.ring(SLOT, 0.035, 0.075, 0.025, segs=10, loc=g(x + 0.08, 1.02, 0), rot=(0, math.pi / 2, 0),
           arc=(math.radians(40), math.radians(320)), color=c("iron_hi"))


def head(p):
    # The lamp head: a flared verdigris bowl, a pale lamp band, a wide verdigris roof and a copper finial at 2.4 m.
    p.cyl(SLOT, 0.2, 0.33, 0.13, segs=12, loc=g(0, 2.085, 0), color=c("verdigris"))
    p.cyl(SLOT, 0.25, 0.25, 0.11, segs=12, loc=g(0, 2.2, 0), color=c("lamp"))
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        box(p, (0.045, 0.12, 0.045), (0.265 * math.sin(a), 2.2, 0.265 * math.cos(a)), "iron", rot=(0, 0, -a))
    p.cyl(SLOT, 0.42, 0.08, 0.13, segs=12, loc=g(0, 2.315, 0), color=c("verdigris_dk"))
    p.cyl(SLOT, 0.43, 0.43, 0.025, segs=12, loc=g(0, 2.245, 0), color=c("verdigris"))
    p.cyl(SLOT, 0.045, 0.025, 0.05, segs=8, loc=g(0, HEIGHT - 0.03, 0), color=c("copper"))


def build():
    root = common.empty("MendWard")
    p = Part("MendWardPost")
    plinth(p)
    column(p)
    mend_collar(p)
    patch(p)
    wheel(p)
    spanner(p)
    head(p)
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    p.to_object(parent=root)
    return root


def check(root):
    bpy.context.view_layer.update()
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    tris = common.tri_total(root)
    draws = sum(len(o.data.materials) for o in meshes)
    verts = sum(len(o.data.vertices) for o in meshes)
    lo = Vector((min(v.co.x for o in meshes for v in o.data.vertices), min(v.co.y for o in meshes for v in o.data.vertices),
                 min(v.co.z for o in meshes for v in o.data.vertices)))
    hi = Vector((max(v.co.x for o in meshes for v in o.data.vertices), max(v.co.y for o in meshes for v in o.data.vertices),
                 max(v.co.z for o in meshes for v in o.data.vertices)))
    size = hi - lo
    print("DEVICE_BUDGET mend_ward_post", tris, "T", verts, "V", draws, "D", "size %.2f x %.2f x %.2f m (x, y up, z)"
          % (size.x, size.z, size.y), "floor %.3f" % lo.z)
    if tris > LIMIT_TRIS or draws > LIMIT_DRAWS:
        raise SystemExit("mend_ward_post budget exceeded: %d T %d D" % (tris, draws))
    if size.x > FOOT + 0.01 or size.y > FOOT + 0.01 or size.z > HEIGHT + 0.01 or abs(lo.z) > 1e-4:
        raise SystemExit("mend_ward_post outgrew its 0.9 x 2.4 x 0.9 m post or left the ground")


def preview(outdir):
    """Cycles stills with the game's ring, a half-full charge fill and a ball for scale: close 3/4, front, and the
    chase camera's distance (13 m back, 5.5 m up)."""
    import cycles_device
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewSky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("bone")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, -0.002))
    bpy.context.object.data.materials.append(common._flat("PreviewGround", "sandstone"))
    ctx = Part("PreviewContext")
    for slot in ("ward_ring",):
        common.SLOTS[slot] = {"vc": True, "rough": 0.9, "metal": 0.0}
    ctx.cyl("ward_ring", RING_M, RING_M, 0.08, segs=48, loc=(0, 0, 0.04), color=c("charcoal"))
    ctx.cyl("ward_ring", RING_M * 0.55, RING_M * 0.55, 0.08, segs=48, loc=(0, 0, 0.1), color=c("verdigris"))
    ctx.uv("ward_ring", BALL_R, u=32, v=16, loc=g(-2.9, BALL_R + 0.08, 1.2), color="bone")
    ctx.to_object()
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(48), math.radians(12), math.radians(35))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(outdir, exist_ok=True)
    views = [("close_three_quarter", (2.4, 1.9, 3.1), (0, 1.25, 0), 40.0),
             ("close_front", (0.0, 1.5, 4.2), (0, 1.2, 0), 40.0),
             ("chase_distance", (3.0, 5.5, 13.0), (0, 1.2, 0), 50.0)]
    for label, eye, target, fov in views:
        cam.location = Vector(g(*eye))
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov)
        common._look(cam, g(*target))
        scene.render.filepath = os.path.join(outdir, "mend_ward_post_%s.png" % label)
        bpy.ops.render.render(write_still=True)
        print("STILL", scene.render.filepath)


opts = common.args()
out_dir = opts["out"] or os.path.join(common.MODELS, "world_one")
common.reset()
post = build()
check(post)
common.export(post, os.path.join(out_dir, "mend_ward_post.glb"))
if opts["render"]:
    preview(opts["render"])
