"""Identical cast remnant, local actor origin, metres, Blender -Y faces Godot +Z.

blender -b --factory-startup --python-exit-code 1 -P enemy_swarm_remnant.py
Procedural bmesh only; no external geometry or textures.
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish
from common import Part


def build():
    common.reset()
    common.SLOTS["ancient_enamel"] = {"color": "petrol", "rough": 0.55}
    polish.enable(detail=1, subsurf=0, sharp_angle=30.0)
    root = common.empty("SwarmRemnant")
    body = Part("RemnantBody")
    corners = [(0, -0.75), (math.sqrt(3) * 0.375, 0.375), (-math.sqrt(3) * 0.375, 0.375)]
    outline = []
    for i, p in enumerate(corners):
        for neighbor in (corners[i - 1], corners[(i + 1) % 3]):
            outline.append(tuple(p[k] * 0.94 + neighbor[k] * 0.06 for k in range(2)))
    body.prism("ancient_enamel", outline, 0.20)
    body.prism("ancient_enamel", [(x * 0.86, y * 0.86) for x, y in outline], 0.025,
               matrix=common.mtx((0, 0, 0.106)))
    body.ring("paint", 0.31, 0.43, 0.015, segs=3, loc=(0, 0, 0.125),
              rot=(0, 0, -math.pi / 2), color="charcoal")
    body.ring("paint", 0.65, 0.69, 0.015, segs=3, loc=(0, 0, -0.09),
              rot=(0, 0, -math.pi / 2), color=common.mix("petrol", "charcoal", 0.3))
    bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
    body.to_object(parent=root)
    seam = Part("RemnantSeam")
    seam.ring("ancient_light", 0.355, 0.385, 0.014, segs=3, loc=(0, 0, 0.139),
              rot=(0, 0, -math.pi / 2))
    bmesh.ops.recalc_face_normals(seam.bm, faces=seam.bm.faces[:])
    seam.to_object(parent=root)
    if common.tri_total(root) > 1100:
        raise SystemExit("remnant exceeds enemy triangle budget")
    return root


if __name__ == "__main__":
    root = build()
    path = common.args()["out"] or os.path.join(common.MODELS, "world_one", "enemy_swarm_remnant.glb")
    common.export(root, path)
    print("REMNANT TRIS", common.tri_total(root), "DRAWS", 3)
