"""Brindle scrap: the field's square mint chunk with a chipped, folded casting.

blender -b --factory-startup --python-exit-code 1 -P boss_pickup.py
Local origin and unit scale; one opaque mesh, no textures, no external assets.
"""
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish
from common import Part

polish.enable(detail=1, bevel=0.02)


def build():
    common.reset()
    common.SLOTS["field"] = {"color": "mint", "emit": 2.0, "rough": 0.8}
    root = common.empty("BrindleScrap")
    part = Part("ScrapChunk")
    outline = [(-0.35, -0.35), (0.21, -0.35), (0.35, -0.21),
               (0.35, 0.35), (-0.22, 0.35), (-0.35, 0.23)]
    part.prism("field", outline, 0.44, matrix=common.mtx((0, 0, -0.08)))
    part.box("field", (0.50, 0.48, 0.08), loc=(-0.03, 0.02, 0.18), rot=(0.0, 0.20, -0.08))
    part.box("field", (0.12, 0.48, 0.06), loc=(-0.17, 0.01, 0.265), rot=(0, -0.25, 0))
    part.cyl("field", 0.07, 0.07, 0.055, segs=6, loc=(0.15, 0.13, 0.27))
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    part.to_object(parent=root)
    if common.tri_total(root) > 270:
        raise SystemExit("pickup exceeds prop budget")
    return root


if __name__ == "__main__":
    root = build()
    path = common.args()["out"] or os.path.join(common.MODELS, "bosses", "boss_pickup.glb")
    common.export(root, path)
    print("PICKUP TRIS", common.tri_total(root), "DRAWS", 1)
