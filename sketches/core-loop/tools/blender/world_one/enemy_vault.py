"""Static cache at its existing collider centre, with two independently tinted belts.

blender -b --factory-startup --python-exit-code 1 -P enemy_vault.py
Procedural bmesh; box-face UVs retain enemy.gd's existing rim-mask material.
"""
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish
from common import Part


def g(x, y, z):
    return (x, -z, y)


def build():
    common.reset()
    common.SLOTS["fleet_paint"] = {"vc": True, "rough": 0.8}
    common.SLOTS["part_state"] = {"color": "petrol", "metal": 0.6, "rough": 0.4}
    common.SLOTS["working_tool"] = {"color": "bone", "rough": 0.4}
    polish.enable(detail=1, subsurf=1, bevel_angle=65.0, sharp_angle=65.0)
    root = common.empty("Vault")
    body = Part("VaultBody")
    footprint = [(-1.25, -1.44), (1.25, -1.44), (1.44, -1.25), (1.44, 1.25),
                 (1.25, 1.44), (-1.25, 1.44), (-1.44, 1.25), (-1.44, -1.25)]
    body.prism("fleet_paint", footprint, 2.30, color="petrol")
    body.prism("fleet_paint", [(x * 1.04, y * 1.04) for x, y in footprint], 0.16,
               matrix=common.mtx(g(0, 1.14, 0)), color=common.mix("petrol", "bone", 0.14))
    body.prism("fleet_paint", footprint, 0.14, matrix=common.mtx(g(0, -1.20, 0)), color="charcoal")
    body.box("fleet_paint", (0.8, 0.05, 0.52), loc=g(-0.48, -0.02, 1.46), color="oxide")
    body.box("fleet_paint", (0.15, 0.10, 1.15), loc=g(0.57, 0.18, 1.49), color="charcoal")
    body.box("fleet_paint", (0.46, 0.13, 0.16), loc=g(0.57, 0.18, 1.55), color="bone")
    for x in (-1.1, 1.1):
        for z in (-1.1, 1.1):
            body.cyl("fleet_paint", 0.085, 0.085, 0.045, segs=6, loc=g(x, 1.235, z), color="charcoal")
    body.cyl("fleet_paint", 0.16, 0.12, 1.8, segs=8, loc=g(0, 2.2, 0), color="charcoal")
    body.cyl("fleet_paint", 0.28, 0.24, 0.18, segs=8, loc=g(0, 1.36, 0), color="oxide")
    body.cyl("fleet_paint", 0.65, 0.65, 0.08, segs=10, loc=g(0, 2.78, 0), color="charcoal")
    body.cyl("fleet_paint", 0.65, 0.40, 0.14, segs=10, loc=g(0, 3.86, 0), color="petrol")
    bmesh.ops.recalc_face_normals(body.bm, faces=body.bm.faces[:])
    body.to_object(parent=root)
    plate = Part("VaultPlating")
    plate.bevel = 0
    plate.subsurf = 0
    for y in (-0.6, 0.6):
        for z in (-1.51, 1.51):
            plate.box("part_state", (3.2, 0.18, 0.35), loc=g(0, y, z))
        for x in (-1.51, 1.51):
            plate.box("part_state", (0.18, 2.84, 0.35), loc=g(x, y, 0))
    uv = plate.bm.loops.layers.uv.new("UVMap")
    for face in plate.bm.faces:
        for loop, point in zip(face.loops, ((0, 0), (1 / 3, 0), (1 / 3, 0.5), (0, 0.5))):
            loop[uv].uv = point
    bmesh.ops.recalc_face_normals(plate.bm, faces=plate.bm.faces[:])
    plate.to_object(parent=root)
    lamp = Part("VaultLamp")
    lamp.uv("working_tool", 0.6, u=10, v=6, loc=g(0, 3.3, 0))
    bmesh.ops.recalc_face_normals(lamp.bm, faces=lamp.bm.faces[:])
    lamp.to_object(parent=root)
    if common.tri_total(root) > 3600:
        raise SystemExit("vault exceeds enemy triangle budget")
    return root


if __name__ == "__main__":
    root = build()
    path = common.args()["out"] or os.path.join(common.MODELS, "world_one", "enemy_vault.glb")
    common.export(root, path)
    print("VAULT TRIS", common.tri_total(root), "DRAWS", 3)
