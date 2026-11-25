"""Sable Cable Run Stake (replaces the last W1-23 prim_census stand-in in src/combat/stakes.gd).

Watertight Blender-authored GLB under assets/models/world_one/sable_stake.glb, centered at
mid-height (matching stakes.gd's 0.9 m cylinder collider origin so it drops cleanly at IDENTITY):
- Grounded flared charcoal anchor flange & 3 riveted steel drive fins at Z = -0.45 m
- Tapered hammered copper pylon spike rising to Z = +0.52 m
- Twin bone ceramic insulator rings + glowing MINT #8bf0d3 grapple bite collar & crown beacon

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P sable_stake.py [-- --out FILE]
"""
import math
import os
import sys

import bmesh
import bpy

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
STEEL = palette_gd.HEX["STEEL"]
MINT = palette_gd.HEX["ARC"]

METAL = "hydraulic"
FIELD = "field"

TRIS_CAP = 2000
VERTS_CAP = 4600
DRAWS_CAP = 2


def _register_slots():
    common.SLOTS[METAL] = {"vc": True, "rough": 0.36, "metal": 0.56}
    common.SLOTS[FIELD] = {"color": MINT, "rough": 0.32, "metal": 0.10, "emit": 1.6}


def build_stake():
    common.reset()
    _register_slots()
    polish.enable(detail=1, bevel=0.008, bevel_min=0.04, ao_strength=0.34, ao_reach=0.26, edge=0.14)
    root = common.empty("SableStake")
    p = Part("SableStakeMesh")

    p.cyl(METAL, 0.34, 0.26, 0.10, segs=12, loc=(0.0, 0.0, -0.40), color=CHARCOAL)
    p.ring(FIELD, 0.28, 0.36, 0.055, segs=16, loc=(0.0, 0.0, -0.38))

    for k in range(3):
        a = k * math.tau / 3.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.22, 0.055, 0.24), loc=(fx * 0.22, fy * 0.22, -0.32),
              rot=(0.0, 0.0, a), color=STEEL)

    p.cyl(METAL, 0.21, 0.11, 0.72, segs=8, loc=(0.0, 0.0, 0.00), color=COPPER)
    p.ring(METAL, 0.14, 0.22, 0.065, segs=10, loc=(0.0, 0.0, 0.04), color=BONE)
    p.ring(FIELD, 0.15, 0.23, 0.065, segs=12, loc=(0.0, 0.0, 0.24))

    for sx in (-1.0, 1.0):
        p.rod(METAL, (sx * 0.09, 0.0, 0.28), (sx * 0.21, 0.0, 0.44), 0.032, segs=6, color=CHARCOAL)
        p.ico(FIELD, 0.048, subdiv=1, loc=(sx * 0.22, 0.0, 0.46))
    p.cyl(METAL, 0.11, 0.06, 0.12, segs=8, loc=(0.0, 0.0, 0.40), color=CHARCOAL)
    p.ico(FIELD, 0.088, subdiv=1, loc=(0.0, 0.0, 0.50))

    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    obj = p.to_object(parent=root)
    common.empty("SocketArc", loc=(0.0, 0.0, 0.50), parent=root)

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    print(f"SABLE_STAKE {tris:4d}T {verts:4d}V {draws}D")
    assert tris <= TRIS_CAP and verts <= VERTS_CAP and draws <= DRAWS_CAP
    return root


def main():
    opts = common.args()
    out_path = opts["out"] or os.path.join(common.MODELS, "world_one", "sable_stake.glb")
    root = build_stake()
    common.export(root, out_path)


if __name__ == "__main__":
    main()
