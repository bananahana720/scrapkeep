"""Gap net, curtain cut: the same gap net for the runtime that hangs its net mid-gap, square to the
crossing (src/combat/gap_net.gd on the Highdraft roster), instead of strung post to post.

The net is a curtain slung across the drop that the ball crosses, not a fence between two posts.
Its tile is one 2 m column of a 16 m drop: a heavy headrope across the top, a diamond net gathered
into pleats (it hangs in folds, like cloth, and bellies a little in the draught), and a weighted
hem with lead drops at the bottom. Repeated side by side it reads as one long curtain over the gap.
The post stops leaning over the drop, because the runtime turns the crew to face the ball while
the curtain stays put: it stands upright on the rim as a hoist, a yard and block at its head and
a cable reel on its clamp, the gear that lowered the curtain. Speed sign, windsock, the back stay's
cut sleeve and the goggled crew are the same as the strung net's (gap_net_post.py).

Godot metres (X,Y,Z) map to Blender (X,-Z,Y). Origin at the roster's standard collider centre, floor
(the island rim) at Y = -1.1. The post faces Godot +Z. Same node names and sockets as
enemy_gap_net.glb, so the runtime swaps the file:
  GapNetPost    fleet_paint: rim clamp, upright mast with its yard and block, back stay with the
                hazard cut sleeve, capstan, speed sign, windsock and the crew. Flashes with the enemy.
  GapNetBatten  working_tool: the cable reel on the clamp, with hazard flanges. Origin on the reel's
                axle, so the sling recoil can shove it.
  GapNetSpan    requisition_tag: one curtain tile, local X 0..2, Y 0 (the bottom of the lead drops)
                to the top of the headrope (CURTAIN_H, less a hair), pleated along Z about 0. Object at the root's origin.
                Tiles join edge to edge along X; at its native 16 m a runtime hang of 9 m below the
                rim to 7 m above stretches it by about 0.1 per cent. Brass at rest; the runtime lights or tints it.
Sockets (empties, no draws): net_high and net_low (the tile's headrope and hem, at its centre),
post_cut, sign, crew_head. Procedural bmesh in this repository; no external meshes or textures.
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
OXIDE = "9b513a"
TILE = 2.0
CURTAIN_H = 16.0
HEM = 0.4
COLS = 4
ROWS = 7
PLEAT = 0.22
BELLY = 0.5
REEL = Vector((0.6, FLOOR + 0.48, -0.3))


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


post = Part("GapNetPost")
MAST = [(0.0, FLOOR + 0.1, 0), (0.0, 0.9, 0), (0.0, 2.15, 0), (0.0, 3.05, 0), (0.0, 3.35, 0)]
POST_SOCKETS = gap_net_post.build(post, MAST)
post.beam("fleet_paint", G(-0.55, 3.2, 0), G(0.8, 3.2, 0), 0.16, 0.16, color=OXIDE)
post.box("fleet_paint", (0.2, 0.3, 0.3), loc=g(0.72, 3.05, 0), color=STEEL)
with post.region(bevel=0.01):
    post.rod("fleet_paint", G(0.8, 2.92, 0), G(REEL.x + 0.3, REEL.y + 0.1, REEL.z), 0.035, segs=4, color="brass")
bmesh.ops.recalc_face_normals(post.bm, faces=post.bm.faces[:])
post_obj = post.to_object(parent=root)

reel = Part("GapNetBatten")
reel.cyl("working_tool", 0.3, 0.3, 0.5, segs=6, loc=g(*REEL), rot=(math.pi / 2, 0, 0), color="brass")
for dz in (-0.27, 0.27):
    reel.cyl("working_tool", 0.42, 0.42, 0.05, segs=6, loc=g(REEL.x, REEL.y, REEL.z + dz), rot=(math.pi / 2, 0, 0),
             color="hazard")
bmesh.ops.recalc_face_normals(reel.bm, faces=reel.bm.faces[:])
reel_obj = reel.to_object(origin=g(*REEL), parent=root)


def fold(i):
    return PLEAT if i % 2 == 0 else -PLEAT


def at(i, y):
    """A knot of the curtain: column i (0..COLS) at height y, pleated and bellied."""
    z = fold(i) + BELLY * math.sin(math.pi * (y - HEM) / (CURTAIN_H - HEM))
    return G(TILE * i / COLS, y, z)


def strand(part, a, b, r, color):
    """A three-sided open tube from a to b: the cheapest cord that reads from both faces."""
    axis = (b - a).normalized()
    u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = axis.cross(u)
    ring = [[p + (u * math.cos(t) + v * math.sin(t)) * r for t in (0, 2.094, 4.189)] for p in (a, b)]
    lo = [part.bm.verts.new(p) for p in ring[0]]
    hi = [part.bm.verts.new(p) for p in ring[1]]
    faces = [part.bm.faces.new((lo[k], lo[(k + 1) % 3], hi[(k + 1) % 3], hi[k])) for k in range(3)]
    part.paint(faces, "requisition_tag", color)


span = Part("GapNetSpan")
span.bevel = 0
span.subsurf = 0
TOP = CURTAIN_H - 0.12
for i in range(COLS):
    strand(span, at(i, TOP), at(i + 1, TOP), 0.12, "brass")
    strand(span, at(i, HEM), at(i + 1, HEM), 0.09, "brass")
for j in range(ROWS):
    y0 = HEM + (TOP - HEM) * j / ROWS
    y1 = HEM + (TOP - HEM) * (j + 1) / ROWS
    for i in range(COLS):
        a, b = (y0, y1) if (i + j) % 2 == 0 else (y1, y0)
        strand(span, at(i, a), at(i + 1, b), 0.06, "brass")
for i in (1, 3):
    p = at(i, HEM)
    span.cyl("requisition_tag", 0.17, 0.1, HEM, segs=4, loc=(p.x, p.y, HEM / 2), color="hazard")
for vert in span.bm.verts:
    vert.co.x = min(max(vert.co.x, 0.0), TILE)
bmesh.ops.recalc_face_normals(span.bm, faces=span.bm.faces[:])
span_obj = span.to_object(origin=(0, 0, 0), parent=root)

for name, pos in [("net_high", (TILE / 2, TOP, 0)), ("net_low", (TILE / 2, HEM, 0)),
                  *[(k, tuple(v)) for k, v in POST_SOCKETS.items()]]:
    common.empty(name, g(*pos), parent=root)

bpy.context.view_layer.update()
objs = (post_obj, reel_obj, span_obj)
points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
tile = [span_obj.matrix_world @ v.co for v in span_obj.data.vertices]
low = min(p.z for p in points)
post_top = max((post_obj.matrix_world @ v.co).z for v in post_obj.data.vertices)
print("GAP NET CURTAIN floor %.3f post top %.3f tile x %.3f..%.3f y %.3f..%.3f tris %d" % (
    low, post_top, min(p.x for p in tile), max(p.x for p in tile), min(p.z for p in tile), max(p.z for p in tile),
    common.tri_total(root)), [(o.name, common.tris(o)) for o in objs])
assert low >= FLOOR - 1e-4 and post_top <= 4.3
assert common.tri_total(root) <= 6000

opts = common.args()
path = opts["out"] or os.path.join(common.MODELS, "world_three", "enemy_gap_net_curtain.glb")
common.export(root, path)
import world_preview
world_preview.budget(path, 3, tris=6000, verts=9000)

if opts["render"]:
    RIM = 1.0
    GAP = 12.0
    WIDTH = 14.0

    def hide_span():
        span_obj.hide_render = True

    def gap():
        span_obj.hide_render = False
        mid = RIM + GAP / 2
        for k in range(int(WIDTH / TILE)):
            t = span_obj if k == 0 else span_obj.copy()
            if k:
                bpy.context.scene.collection.objects.link(t)
                t.parent = root
            t.location = (-WIDTH / 2 + TILE * k, mid, FLOOR - 9.0)
        bpy.data.objects["PreviewFloor"].location.z = -60
        for y0, y1 in ((-30, RIM), (RIM + GAP, 50)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0, (y0 + y1) / 2, FLOOR - 4))
            isle = bpy.context.object
            isle.scale = (40, y1 - y0, 8)
            isle.data.materials.append(common._flat("Island", "9aa7a0"))
        bpy.data.objects["ReferenceBall_2m"].location = (2.5, RIM + 2.0, FLOOR + 2.4)

    def live():
        mat = bpy.data.materials.get("requisition_tag")
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.97, 0.9, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0

    world_preview.render(
        "gap_net_curtain", root, opts["render"], FLOOR, "highdraft", focus=(0.1, 0, 1.6), scale=6.5, ball_x=-3.6,
        extras=hide_span, game_extras=gap, game_target=(0, RIM + GAP / 2, 0.5), game_back=15.0, game_up=4.0,
        face_yaw=0, game_yaw=0, poses=[("game_live", live)])
