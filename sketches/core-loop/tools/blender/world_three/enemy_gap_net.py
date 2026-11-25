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
sys.path.insert(0, HERE)
import common
import polish
from common import Part
import gap_net_post

common.reset()
polish.enable(detail=2, bevel=0.03, fit=True)
common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.85}
common.SLOTS["working_tool"] = {"vc": True, "rough": 0.5, "metal": 0.4}
common.SLOTS["requisition_tag"] = {"vc": True, "rough": 0.4, "metal": 0.5}
root = common.empty("GapNet")

FLOOR = -1.1
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
BATTEN_X = 1.15
NET_LOW = -0.55
NET_HIGH = 2.85
TILE = 2.0


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


post = Part("GapNetPost")
MAST = [(0.0, FLOOR + 0.1, 0), (0.0, 0.9, 0), (0.3, 2.15, 0), (0.85, 3.05, 0), (BATTEN_X, 3.2, 0)]
POST_SOCKETS = gap_net_post.build(post, MAST, outrigger=BATTEN_X, net_low=NET_LOW)
bmesh.ops.recalc_face_normals(post.bm, faces=post.bm.faces[:])
post_obj = post.to_object(parent=root)

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

span = Part("GapNetSpan")
span.bevel = 0
span.subsurf = 0
H = NET_HIGH - NET_LOW
ROWS = 4
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
                  *[(k, tuple(v)) for k, v in POST_SOCKETS.items()]]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (post_obj, batten_obj, span_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
low = min(p.z for p in points)
high = max(p.z for p in points)
print("GAP NET floor %.3f top %.3f tris %d" % (low, high, common.tri_total(root)),
      [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and high <= 4.0
assert common.tri_total(root) <= 6000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_gap_net.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3, tris=6000, verts=9000)

if opts["render"]:
    tiles = []

    def far_side():
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
        bpy.data.objects["PreviewFloor"].location.z = -40
        for x0, x1 in ((-30, 1.15), (2 * BATTEN_X + 4 * TILE - 1.15, 40)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, 0, FLOOR - 3))
            isle = bpy.context.object
            isle.scale = (x1 - x0, 14, 6)
            isle.data.materials.append(common._flat("Island", "9aa7a0"))

    def tell():
        mat = bpy.data.materials.get("requisition_tag")
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.97, 0.9, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0

    world_preview.render(
        "gap_net", root, opts["render"], FLOOR, "highdraft", focus=(0.6, 0, 1.4), scale=6.5, ball_x=-3.6,
        game_extras=far_side, game_target=(5.3, 0, 1.0), game_back=16.0, game_up=5.0, face_yaw=0, game_yaw=0,
        poses=[("game_live", tell)])
