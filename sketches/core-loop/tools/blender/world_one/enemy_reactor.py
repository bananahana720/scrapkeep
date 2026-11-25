import math
import os
import sys
import bmesh
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import common
import polish
from common import Part

common.reset()
polish.enable(detail=1, subsurf=0, bevel_angle=65.0, sharp_angle=65.0)
root = common.empty('Reactor')

def shell(part, rows, slot, colors, caps=True, sectors=16):
    rings = []
    for y, radius in rows:
        rings.append([part.bm.verts.new(Vector((radius * math.cos(k * math.tau / sectors),
                     radius * math.sin(k * math.tau / sectors), y))) for k in range(sectors)])
    for j in range(len(rows) - 1):
        for k in range(sectors):
            n = (k + 1) % sectors
            part.paint([part.bm.faces.new((rings[j][k], rings[j][n], rings[j+1][n], rings[j+1][k]))],
                       slot, colors[j] if isinstance(colors, list) else colors)
    if caps:
        part.paint([part.bm.faces.new(list(reversed(rings[0]))), part.bm.faces.new(rings[-1])], slot,
                   colors[0] if isinstance(colors, list) else colors)

body = Part('ReactorBody')
shell(body, [(-1.2, 1.55), (-1.02, 1.50), (-0.50, 1.06), (0.16, 1.18), (0.28, 1.50)],
      'ancient_enamel', 'petrol')
shell(body, [(0.28, 1.50), (0.65, 1.42), (1.05, 1.16), (1.36, 0.72), (1.50, 0.30)],
      'ancient_enamel', 'petrol')
body.cyl('paint', 1.073, 1.08, 0.22, segs=16, loc=(0, 0, -0.49), color='charcoal')
body.ring('paint', 1.40, 1.55, 0.12, segs=16, loc=(0, 0, -1.14), color=common.mix('petrol','charcoal',0.35))
body.ring('paint', 1.40, 1.505, 0.10, segs=16, loc=(0, 0, 0.28), color=(0.29,0.40,0.38))
bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
for v in body.bm.verts:
    v.co.x *= 0.76
    v.co.y *= 0.76
body.to_object(parent=root)

stack = Part('ReactorStack')
stack.bevel = 0
shell(stack, [(-0.60,0.32), (-0.30,0.30), (0.28,0.28), (0.50,0.28), (0.60,0.28)],
      'paint', [(0.22,0.33,0.31), 'petrol', 'charcoal', 'charcoal'], caps=False, sectors=8)
stack.ring('paint', 0.20, 0.28, 0.08, segs=8, loc=(0,0,0.56), color=(0.29,0.40,0.38))
stack.cyl('paint', 0.20, 0.20, 0.18, segs=8, loc=(0,0,0.40), color='charcoal')
stack.cyl('paint', 0.284, 0.284, 0.10, segs=8, loc=(0,0,0.39), color='3d8bff', caps=False)
bmesh.ops.recalc_face_normals(stack.bm, faces=stack.bm.faces[:])
stack.to_object(parent=root)
body_obj = bpy.data.objects['ReactorBody']
stack_obj = bpy.data.objects['ReactorStack']
assembly_tris = common.tris(body_obj) + 3 * common.tris(stack_obj)
draws = len(body_obj.data.materials) + len(stack_obj.data.materials)
print('ASSEMBLY_TRIS', assembly_tris, 'DRAWS', draws,
      'BODY_TRIS', common.tris(body_obj), 'STACK_TRIS', common.tris(stack_obj))
if assembly_tris > 5100 or draws > 3:
    raise SystemExit('C31 assembled budget exceeded')
opts = common.args()
common.export(root, opts['out'] or os.path.join(common.MODELS, 'world_one', 'enemy_reactor.glb'))
