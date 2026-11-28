"""Patch (hidden 7th pilot, line_splicer) — paw-print husk overlay (design-v3/pilots/patch.md, rulings dl & en).

One closed, watertight graphic-novel GLB:
  assets/models/world_one/patch_husk_sticker.glb - Paw-print sticker badge + dangling cut command cable +
                                                   punch-card timer overlay for Patch's raised hands.

Patch's pilot (assets/models/pilot_patch_anim.glb) and shell (assets/models/world_one/shell_patch.glb)
come from tools/build_patch_glbs.py.

Colour discipline (pilots/patch.md §4):
  Patch's test-card pink (#ea7fa0, CVD-safe & distinct from HAZARD #ff5a3c and KINDNESS #d936b0)
  with cold white (#e8f0f2) fallback accent, charcoal, bone, copper & verdigris Keeper hardware.

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P pilot_patch.py [-- --out DIR]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))

import common
import palette_gd
import polish
from common import Part

BONE = palette_gd.HEX["SAND"]
COPPER = palette_gd.HEX["COPPER"]
CHARCOAL = palette_gd.HEX["CHARCOAL"]

PATCH_PINK = "ea7fa0"
COLD_WHITE = "e8f0f2"

ALONG_Y = (math.pi / 2.0, 0.0, 0.0)


def _setup_slots():
    common.SLOTS["pilot"] = {"vc": True, "rough": 0.88, "metal": 0.0}
    common.SLOTS["paint"] = {"vc": True, "rough": 0.76, "metal": 0.0}
    common.SLOTS["hydraulic"] = {"vc": True, "rough": 0.36, "metal": 0.54}
    common.SLOTS["class_accent"] = {"color": PATCH_PINK, "emit": 0.65, "rough": 0.42}
    common.SLOTS["bare_metal"] = {"color": BONE, "lighten": 0.25, "metal": 0.6, "rough": 0.45}
    common.SLOTS["rubber"] = {"color": CHARCOAL, "rough": 0.95}
    common.SLOTS["copper"] = {"color": COPPER, "metal": 0.6, "rough": 0.4}


def build_patch_husk_sticker(out_path):
    """Patch's hand-ownership overlay (pilots/patch.md §4): paw-print sticker over Fleet tag +
    trailing cut command cable + overhead punch-card timer badge."""
    common.reset()
    _setup_slots()
    polish.enable(detail=1, bevel=0.006, bevel_min=0.04, ao_strength=0.28, ao_reach=0.22, edge=0.10)
    root = common.empty("PatchHuskSticker")
    p = Part("PatchHuskStickerMesh")

    p.cyl("paint", 0.24, 0.24, 0.036, segs=12, loc=(0.0, 0.0, 0.24), rot=ALONG_Y, color=COLD_WHITE)
    p.cyl("class_accent", 0.085, 0.085, 0.046, segs=10, loc=(0.0, -0.005, 0.20), rot=ALONG_Y)
    for tx, tz in ((-0.10, 0.30), (-0.036, 0.34), (0.036, 0.34), (0.10, 0.30)):
        p.cyl("class_accent", 0.038, 0.038, 0.048, segs=8, loc=(tx, -0.006, tz), rot=ALONG_Y)

    pts = [
        Vector((0.0, 0.04, 0.24)),
        Vector((0.14, 0.22, 0.20)),
        Vector((0.06, 0.44, 0.12)),
        Vector((0.18, 0.66, 0.06)),
    ]
    for a_pt, b_pt in zip(pts, pts[1:]):
        p.rod("paint", a_pt, b_pt, 0.028, segs=6, color=CHARCOAL)
    for pt in pts[1:-1]:
        p.ico("paint", 0.030, subdiv=1, loc=tuple(pt), color=CHARCOAL)
    p.ico("class_accent", 0.052, subdiv=1, loc=tuple(pts[-1]))

    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    obj = p.to_object(parent=root)
    common.empty("SocketSticker", loc=(0.0, 0.0, 0.24), parent=root)

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    print(f"PATCH_HUSK_STICKER {tris:4d}T {verts:4d}V {draws}D")
    assert tris <= 2000 and verts <= 4600 and draws <= 2
    common.export(root, out_path)


def main():
    opts = common.args()
    models_root = opts["out"] or common.MODELS
    build_patch_husk_sticker(os.path.join(models_root, "world_one", "patch_husk_sticker.glb"))


if __name__ == "__main__":
    main()
