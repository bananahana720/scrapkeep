"""Gap net: the Highdraft's net post, the netcaster re-homed (WORLD-ROSTERS.md, the Highdraft roster).

Two of these clamp onto facing island rims with a live net strung across the gap between them. The
net catches an airborne ball crossing below its tear speed and slings it back; above tear speed the
ball rips through. Silhouette: a bowed davit leaning out over the drop, a windsock on top and a
net trailing off sideways; nothing else in the roster leans out over an edge. The Netcaster was two
upright masts and a crossbar (a gate); this is one bent arm that hangs a net into the sky. The
read for the answer is on the post itself: a round speed sign facing the player (go faster than
this), and a hazard sleeve on the back stay (cut a post).

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). Origin at the roster's standard collider centre, floor
(the island rim) at Y = -1.1. The post faces Godot +Z; the gap and the net are along +X.
Three meshes, three surfaces, opaque vertex colour, no baked glow:
  GapNetPost    fleet_paint: rim clamp, bowed mast, back stay with its hazard cut sleeve, capstan,
                speed sign, windsock and the crew in goggles. Flashes with the enemy.
  GapNetBatten  working_tool: the upright batten at the net's edge with its spring tensioners.
                Origin on the batten line, so the sling recoil can shove it along +-Z.
  GapNetSpan    requisition_tag: one 2 m tile of diamond net, from the batten (local X = 0) to
                X = 2, between net_low and net_high. The runtime repeats it along +X to the far
                post (a second instance, turned 180 degrees about Y, with its span hidden) and
                lights it while live. Brass at rest; a torn net is the runtime hiding the tiles.
Sockets (empties, no draws): net_high, net_low (the batten ends), post_cut (the stay's sleeve),
sign (the speed sign's centre), crew_head. Procedural bmesh in this repository.
Run: blender -b --factory-startup -P <this file> -- [--out file.glb] [--render dir]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "..", "world_two"))
import common
from common import Part
import fleet_crew

common.reset()
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.85}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.5, "metal": 0.4}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
root = common.empty("GapNet")

FLOOR = -1.1
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
OXIDE = "9b513a"
BATTEN_X = 1.15
NET_LOW = -0.55
NET_HIGH = 2.85
TILE = 2.0


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


post = Part("GapNetPost")
# Rim clamp: a deck plate bolted to the island edge with two jaws over the lip at +X.
post.box("fleet_paint", (2.0, 1.3, 0.16), loc=g(0.05, FLOOR + 0.08, 0), color=CHAR)
for dz in (-0.5, 0.5):
    post.box("fleet_paint", (0.3, 0.3, 0.42), loc=g(0.95, FLOOR + 0.21, dz), color="hazard")
    post.box("fleet_paint", (0.18, 0.18, 0.12), loc=g(-0.8, FLOOR + 0.22, dz), color=WORN)
# The bowed mast: three segments leaning out over the drop.
MAST = [(0.0, FLOOR + 0.1, 0), (0.0, 0.9, 0), (0.3, 2.15, 0), (0.85, 3.05, 0), (BATTEN_X, 3.2, 0)]
for (a, b), w in zip(zip(MAST, MAST[1:]), (0.34, 0.3, 0.24, 0.18)):
    post.beam("fleet_paint", G(*a), G(*b), w, w, color=OXIDE)
post.beam("fleet_paint", G(0.0, 0.25, 0), G(0.0, 0.55, 0), 0.38, 0.38, color="bone")
for joint in MAST[1:4]:
    post.box("fleet_paint", (0.36, 0.36, 0.3), loc=g(*joint), color=OXIDE)
# Lower outrigger to the batten foot.
post.beam("fleet_paint", G(0.0, -0.3, 0), G(BATTEN_X, NET_LOW, 0), 0.16, 0.16, color=STEEL)
# Back stay: mast head to a ground anchor behind, with the hazard sleeve, the cut mark.
STAY_TOP = Vector((0.3, 2.15, 0))
STAY_FOOT = Vector((-1.75, FLOOR + 0.15, 0))
post.rod("fleet_paint", G(*STAY_TOP), G(*STAY_FOOT), 0.045, segs=5, color="brass")
CUT = STAY_TOP.lerp(STAY_FOOT, 0.55)
d = (STAY_FOOT - STAY_TOP).normalized()
post.rod("fleet_paint", G(*(CUT - d * 0.22)), G(*(CUT + d * 0.22)), 0.11, segs=6, color="hazard")
post.box("fleet_paint", (0.36, 0.36, 0.24), loc=g(-1.75, FLOOR + 0.12, 0), color=STEEL)
# Speed sign at eye height, facing the player: hazard ring, bone face, a charcoal bar (the
# tear speed as a "go at least this fast" roundel; the runtime may paint the number on).
SIGN = Vector((-0.02, 1.25, 0.32))
post.cyl("fleet_paint", 0.48, 0.48, 0.06, segs=8, loc=g(*SIGN), rot=(math.pi / 2, 0, 0), color="hazard")
post.cyl("fleet_paint", 0.36, 0.36, 0.07, segs=8, loc=g(SIGN.x, SIGN.y, SIGN.z + 0.01), rot=(math.pi / 2, 0, 0),
         color="bone")
for dy in (-0.1, 0.1):
    post.box("fleet_paint", (0.42, 0.08, 0.08), loc=g(SIGN.x, SIGN.y + dy, SIGN.z + 0.05), color=CHAR)
post.box("fleet_paint", (0.08, 0.08, 0.28), loc=g(SIGN.x + 0.2, SIGN.y, SIGN.z + 0.05), color=CHAR)
# Windsock on a short pole at the masthead: the Highdraft's wind, always showing.
post.rod("fleet_paint", G(0.85, 3.05, 0), G(0.65, 3.85, 0), 0.04, segs=5, color=CHAR)
for k in range(3):
    r0, r1 = 0.24 - 0.05 * k, 0.19 - 0.05 * k
    a = Vector((0.65 - 0.36 * k, 3.75, 0.0))
    b = a + Vector((-0.36, -0.08, 0.0))
    post.rod("fleet_paint", G(*a), G(*b), r0, segs=6, color="hazard" if k % 2 == 0 else "bone", r2=r1)
# Capstan the crew winds to tension the net, and the crew on it, in goggles and a long scarf.
post.cyl("fleet_paint", 0.22, 0.26, 0.55, segs=6, loc=g(-0.55, FLOOR + 0.43, 0.25), color=STEEL)
post.cyl("fleet_paint", 0.32, 0.32, 0.06, segs=8, loc=g(-0.55, FLOOR + 0.72, 0.25), color=CHAR)
post.rod("fleet_paint", G(-0.55, FLOOR + 0.75, 0.25), G(-0.05, FLOOR + 0.82, 0.62), 0.04, segs=5, color=WORN)
CREW = Vector((-0.05, 0.25, 0.85))
post.cyl("fleet_paint", 0.36, 0.3, 0.95, segs=8, loc=g(CREW.x, FLOOR + 0.62, CREW.z), color=OXIDE)
post.box("fleet_paint", (0.62, 0.42, 0.14), loc=g(CREW.x, FLOOR + 1.03, CREW.z), color="petrol")
post.beam("fleet_paint", G(CREW.x - 0.15, -0.25, CREW.z - 0.25), G(CREW.x - 0.95, -0.15, CREW.z - 0.65),
          0.24, 0.05, color="bone")
fleet_crew.head(post, CREW, r=0.3, facing=(0.0, 1.0), hat="goggles")
for side in (-1, 1):
    post.rod("fleet_paint", G(CREW.x + side * 0.32, -0.22, CREW.z), G(CREW.x + side * 0.2, -0.55, CREW.z - 0.35),
             0.07, segs=5, color=OXIDE)
bmesh.ops.recalc_face_normals(post.bm, faces=post.bm.faces[:])
post_obj = post.to_object(parent=root)

# Batten: the upright at the net's edge, with spring tensioners top and bottom.
batten = Part("GapNetBatten")
batten.beam("working_tool", G(BATTEN_X, NET_LOW - 0.1, 0), G(BATTEN_X, NET_HIGH + 0.1, 0), 0.12, 0.12, color=WORN)
for y in (NET_LOW, NET_HIGH):
    batten.cyl("working_tool", 0.12, 0.12, 0.36, segs=6, loc=g(BATTEN_X - 0.12, y, 0), rot=(0, math.pi / 2, 0),
               color=STEEL)
    batten.cyl("working_tool", 0.16, 0.16, 0.06, segs=6, loc=g(BATTEN_X - 0.3, y, 0), rot=(0, math.pi / 2, 0),
               color=CHAR)
for y in (0.5, 1.6):
    batten.box("working_tool", (0.2, 0.2, 0.14), loc=g(BATTEN_X, y, 0), color="hazard")
bmesh.ops.recalc_face_normals(batten.bm, faces=batten.bm.faces[:])
batten_obj = batten.to_object(origin=g(BATTEN_X, 0, 0), parent=root)

# Net tile: top and bottom ropes, zigzag strands between them (diamonds), all thin and opaque
# so the ball reads through the gaps. Local X 0..TILE from the batten.
span = Part("GapNetSpan")
H = NET_HIGH - NET_LOW
ROWS = 4  # even, so the zigzag rows mirror into diamonds and tiles join
COLS = 4
for y in (NET_LOW, NET_HIGH):
    span.beam("requisition_tag", G(BATTEN_X, y, 0), G(BATTEN_X + TILE, y, 0), 0.07, 0.07, color="brass")
for j in range(ROWS):
    y0 = NET_LOW + H * j / ROWS
    y1 = NET_LOW + H * (j + 1) / ROWS
    for i in range(COLS):
        x0 = BATTEN_X + TILE * i / COLS
        x1 = BATTEN_X + TILE * (i + 1) / COLS
        a, b = (y0, y1) if (i + j) % 2 == 0 else (y1, y0)
        span.beam("requisition_tag", G(x0, a, 0), G(x1, b, 0), 0.045, 0.045, color="brass")
bmesh.ops.recalc_face_normals(span.bm, faces=span.bm.faces[:])
span_obj = span.to_object(origin=g(BATTEN_X, 0, 0), parent=root)

for name, pos in [("net_high", (BATTEN_X, NET_HIGH, 0)), ("net_low", (BATTEN_X, NET_LOW, 0)),
                  ("post_cut", tuple(CUT)), ("sign", tuple(SIGN)), ("crew_head", tuple(CREW))]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (post_obj, batten_obj, span_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
print("GAP NET floor %.3f top %.3f tris %d" % (low, high, common.tri_total(root)),
      [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and high <= 4.0
assert common.tri_total(root) <= 1100

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_gap_net.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3)

if opts["render"]:
    tiles = []

    def far_side():
        # Preview only: three more net tiles and the far post, an 8 m gap, as placed in play.
        for k in range(1, 4):
            t = span_obj.copy()
            t.data = span_obj.data
            bpy.context.scene.collection.objects.link(t)
            t.parent = root
            t.location = span_obj.location + Vector((TILE * k, 0, 0))
            tiles.append(t)
        far = bpy.data.objects.new("FarPost", None)
        bpy.context.scene.collection.objects.link(far)
        far.parent = root
        far.location = (2 * BATTEN_X + 4 * TILE, 0, 0)
        far.rotation_euler.z = math.pi
        for o in (post_obj, batten_obj):
            c = o.copy()
            bpy.context.scene.collection.objects.link(c)
            c.parent = far
            c.location = o.location
        # A floor gap: the preview floor is cut away between the rims.
        bpy.data.objects["PreviewFloor"].location.z = -40
        for x0, x1 in ((-30, 1.15), (2 * BATTEN_X + 4 * TILE - 1.15, 40)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, 0, FLOOR - 3))
            isle = bpy.context.object
            isle.scale = (x1 - x0, 14, 6)
            isle.data.materials.append(common._flat("Island", "9aa7a0"))

    def tell():
        # The live net: requisition_tag lit white, as the runtime does.
        mat = bpy.data.materials.get("requisition_tag")
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.97, 0.9, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0

    world_preview.render(
        "gap_net", root, opts["render"], FLOOR, "highdraft", focus=(0.6, 0, 1.4), scale=6.5, ball_x=-3.6,
        game_extras=far_side, game_target=(5.3, 0, 1.0), game_back=16.0, game_up=5.0, face_yaw=0, game_yaw=0,
        poses=[("game_live", tell)])
