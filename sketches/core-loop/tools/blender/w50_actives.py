"""W50 Actives 3D world & held pod models (Magnet Sling & Slag Mortar).

Four closed, watertight graphic-novel GLBs under assets/models/actives/, all within the
`prop` budget class (<= 2000 tris, <= 4600 verts, <= 2 draws), strictly using canon
src/core/palette.gd hexes (zero HAZARD #ff5a3c):

  1. act_magnet_sling_buoy.glb  - Fleet Surplus deployed horseshoe-coil cluster anchor buoy
  2. act_magnet_sling_pod.glb   - Heroic side-mount/dropped Magnet Sling rack launcher pod
  3. act_slag_mortar_shell.glb  - Redjaw Workshops heavy ribbed kiln slag mortar shell
  4. act_slag_mortar_pod.glb    - Heroic side-mount/dropped Slag Mortar kiln tube pod

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P w50_actives.py [-- --out DIR]
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
RUST = palette_gd.HEX["RUST"]
COPPER = palette_gd.HEX["COPPER"]
CHARCOAL = palette_gd.HEX["CHARCOAL"]
VERDIGRIS = palette_gd.HEX["VERDIGRIS"]
AMBER = palette_gd.HEX["AMBER"]
MINT = palette_gd.HEX["ARC"]
BRASS = palette_gd.HEX["BRASS"]
STEEL = palette_gd.HEX["STEEL"]

METAL = "hydraulic"
ARC_GLOW = "field"
AMBER_GLOW = "cons_amber_rim"

TRIS_CAP = 2000
VERTS_CAP = 4600
DRAWS_CAP = 2

ALONG_X = (0.0, math.pi / 2.0, 0.0)
ALONG_Y = (math.pi / 2.0, 0.0, 0.0)


def _register_slots():
    common.SLOTS[METAL] = {"vc": True, "rough": 0.36, "metal": 0.58}
    common.SLOTS[ARC_GLOW] = {"color": MINT, "rough": 0.32, "metal": 0.10, "emit": 1.35}
    common.SLOTS[AMBER_GLOW] = {"color": AMBER, "rough": 0.30, "metal": 0.15, "emit": 1.25}


def _ground_root(root):
    bpy.context.view_layer.update()
    lo_z = math.inf
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            wz = (o.matrix_world @ v.co).z
            if wz < lo_z:
                lo_z = wz
    if math.isfinite(lo_z) and abs(lo_z) > 1e-6:
        for o in root.children:
            o.location.z -= lo_z
        bpy.context.view_layer.update()


def build_magnet_sling_buoy(p, root):
    """Fleet Surplus cluster anchor buoy: heavy weighted anchor foot, twin copper electromagnet
    horseshoe horns, brass requisition tag, and glowing MINT #8bf0d3 central attractor core."""
    p.cyl(METAL, 0.52, 0.42, 0.14, segs=10, loc=(0.0, 0.0, 0.07), color=CHARCOAL)
    p.cyl(METAL, 0.34, 0.30, 0.18, segs=8, loc=(0.0, 0.0, 0.22), color=RUST)
    for k in range(4):
        a = k * math.pi / 2.0 + math.pi / 4.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.34, 0.12, 0.16), loc=(fx * 0.44, fy * 0.44, 0.08),
              rot=(0.0, 0.0, a), color=STEEL)

    p.cyl(METAL, 0.20, 0.18, 0.68, segs=10, loc=(0.0, 0.0, 0.64), color=CHARCOAL)
    for rz in (0.42, 0.64, 0.86):
        p.ring(METAL, 0.19, 0.28, 0.075, segs=10, loc=(0.0, 0.0, rz), color=COPPER)

    p.ring(ARC_GLOW, 0.26, 0.36, 0.070, segs=12, loc=(0.0, 0.0, 0.64))
    p.ico(ARC_GLOW, 0.19, subdiv=1, loc=(0.0, 0.0, 1.14))

    for sx in (-1.0, 1.0):
        pts = [
            Vector((sx * 0.24, 0.0, 0.36)),
            Vector((sx * 0.52, 0.0, 0.58)),
            Vector((sx * 0.56, 0.0, 1.02)),
            Vector((sx * 0.34, 0.0, 1.32)),
        ]
        for a_pt, b_pt in zip(pts, pts[1:]):
            p.rod(METAL, a_pt, b_pt, 0.078, segs=6, color=COPPER)
        for pt in pts[1:-1]:
            p.ico(METAL, 0.084, subdiv=1, loc=tuple(pt), color=CHARCOAL)
        p.box(METAL, (0.16, 0.20, 0.14), loc=(sx * 0.30, 0.0, 1.34),
              rot=(0.0, sx * math.radians(-22.0), 0.0), color=STEEL)
        p.box(ARC_GLOW, (0.04, 0.16, 0.10), loc=(sx * 0.21, 0.0, 1.32))

    p.box(METAL, (0.28, 0.05, 0.16), loc=(0.0, -0.34, 0.24), color=BRASS)

    common.empty("SocketCore", loc=(0.0, 0.0, 1.14), parent=root)
    common.empty("SocketArc", loc=(0.0, 0.0, 1.34), parent=root)


def build_magnet_sling_pod(p, root):
    """Heroic Magnet Sling held/dropped rack pod: twin brass-and-copper horseshoe rail launcher
    cradling a glowing MINT #8bf0d3 magnetic buoy slug."""
    p.box(METAL, (0.48, 0.54, 0.12), loc=(0.0, 0.0, 0.06), color=CHARCOAL)
    p.box(METAL, (0.36, 0.62, 0.26), loc=(0.0, -0.04, 0.25), color=RUST)
    for sx in (-0.22, 0.22):
        p.box(METAL, (0.12, 0.72, 0.20), loc=(sx, 0.16, 0.30), color=COPPER)
        p.box(METAL, (0.15, 0.14, 0.24), loc=(sx, 0.48, 0.30), color=STEEL)
        p.box(METAL, (0.14, 0.10, 0.22), loc=(sx, 0.22, 0.30), color=CHARCOAL)
    p.cyl(METAL, 0.18, 0.18, 0.44, segs=12, loc=(0.0, -0.34, 0.30), rot=ALONG_X, color=BRASS)
    p.ring(METAL, 0.17, 0.21, 0.06, segs=12, loc=(0.0, -0.34, 0.30), rot=ALONG_X, color=CHARCOAL)
    p.cyl(ARC_GLOW, 0.12, 0.12, 0.32, segs=12, loc=(0.0, 0.26, 0.30), rot=ALONG_Y)
    p.ring(ARC_GLOW, 0.13, 0.19, 0.05, segs=12, loc=(0.0, 0.44, 0.30), rot=ALONG_Y)

    common.empty("SocketMuzzle", loc=(0.0, 0.54, 0.30), parent=root)


def build_slag_mortar_shell(p, root):
    """Redjaw Workshops heavy kiln slag mortar shell: fluted cast-iron bomb body, copper drive
    band, brass impact fuze nose, and glowing AMBER #e5a044 molten slag vent slits (zero HAZARD)."""
    p.ring(METAL, 0.22, 0.28, 0.14, segs=12, loc=(0.0, 0.0, 0.10), color=CHARCOAL)
    for k in range(4):
        a = k * math.pi / 2.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.24, 0.045, 0.26), loc=(fx * 0.18, fy * 0.18, 0.15),
              rot=(0.0, 0.0, a), color=STEEL)

    p.cyl(METAL, 0.22, 0.32, 0.26, segs=12, loc=(0.0, 0.0, 0.34), color=CHARCOAL)
    p.cyl(METAL, 0.32, 0.30, 0.32, segs=12, loc=(0.0, 0.0, 0.62), color=RUST)
    p.cyl(METAL, 0.30, 0.14, 0.24, segs=12, loc=(0.0, 0.0, 0.89), color=CHARCOAL)

    p.ring(METAL, 0.30, 0.365, 0.10, segs=12, loc=(0.0, 0.0, 0.54), color=COPPER)
    for k in range(4):
        a = k * math.pi / 2.0 + math.pi / 4.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(AMBER_GLOW, (0.10, 0.06, 0.20), loc=(fx * 0.29, fy * 0.29, 0.72),
              rot=(0.0, 0.0, a))
    p.cyl(METAL, 0.14, 0.08, 0.12, segs=10, loc=(0.0, 0.0, 1.06), color=BRASS)
    p.ico(AMBER_GLOW, 0.075, subdiv=1, loc=(0.0, 0.0, 1.15))

    common.empty("SocketCore", loc=(0.0, 0.0, 0.60), parent=root)


def build_slag_mortar_pod(p, root):
    """Heroic Slag Mortar held/dropped rack pod: heavy canted Redjaw kiln mortar barrel on
    bolted recoil trunnions with glowing AMBER muzzle throat and brass pressure gauge."""
    p.box(METAL, (0.56, 0.62, 0.12), loc=(0.0, 0.0, 0.06), color=CHARCOAL)
    for sx in (-0.25, 0.25):
        p.box(METAL, (0.10, 0.42, 0.32), loc=(sx, -0.04, 0.24), color=RUST)
        p.cyl(METAL, 0.065, 0.065, 0.14, segs=8, loc=(sx, -0.02, 0.34), rot=ALONG_X, color=STEEL)

    b_start = Vector((0.0, -0.24, 0.24))
    b_mid = Vector((0.0, 0.06, 0.45))
    b_end = Vector((0.0, 0.38, 0.68))
    p.rod(METAL, b_start, b_mid, 0.22, segs=12, r2=0.20, color=CHARCOAL)
    p.rod(METAL, b_mid, b_end, 0.20, segs=12, r2=0.23, color=RUST)
    p.rod(METAL, b_start.lerp(b_end, 0.38), b_start.lerp(b_end, 0.48), 0.245, segs=12, color=COPPER)
    p.rod(METAL, b_start.lerp(b_end, 0.64), b_start.lerp(b_end, 0.74), 0.245, segs=12, color=COPPER)
    p.rod(METAL, b_start.lerp(b_end, 0.90), b_end, 0.265, segs=12, color=CHARCOAL)
    p.ico(AMBER_GLOW, 0.165, subdiv=1, loc=tuple(b_end - Vector((0.0, 0.03, 0.02))))
    p.box(AMBER_GLOW, (0.44, 0.16, 0.09), loc=(0.0, -0.02, 0.36))
    p.ico(METAL, 0.11, subdiv=1, loc=tuple(b_start - Vector((0.0, 0.07, 0.05))), color=BRASS)

    common.empty("SocketMuzzle", loc=tuple(b_end), parent=root)


ASSETS = {
    "act_magnet_sling_buoy": (
        build_magnet_sling_buoy,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.14, "ao_strength": 0.34, "ao_reach": 0.28, "edge": 0.14},
    ),
    "act_magnet_sling_pod": (
        build_magnet_sling_pod,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.10, "ao_strength": 0.34, "ao_reach": 0.26, "edge": 0.14},
    ),
    "act_slag_mortar_shell": (
        build_slag_mortar_shell,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.10, "ao_strength": 0.36, "ao_reach": 0.26, "edge": 0.14},
    ),
    "act_slag_mortar_pod": (
        build_slag_mortar_pod,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.10, "ao_strength": 0.36, "ao_reach": 0.26, "edge": 0.14},
    ),
}


def build_one(name):
    builder, pol_opts = ASSETS[name]
    common.reset()
    _register_slots()
    polish.enable(**pol_opts)
    root = common.empty(name)
    part = Part(name + "_mesh")
    builder(part, root)
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    obj = part.to_object(parent=root)
    _ground_root(root)

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    lo = [min((obj.matrix_world @ v.co)[i] for v in obj.data.vertices) for i in range(3)]
    hi = [max((obj.matrix_world @ v.co)[i] for v in obj.data.vertices) for i in range(3)]
    dims = [hi[i] - lo[i] for i in range(3)]
    print(f"ACTIVE {name:24s} {tris:4d}T {verts:4d}V {draws}D size=({dims[0]:.2f}, {dims[1]:.2f}, {dims[2]:.2f})m minZ={lo[2]:.4f}")
    assert tris <= TRIS_CAP, f"{name}: {tris} tris exceeds {TRIS_CAP}"
    assert verts <= VERTS_CAP, f"{name}: {verts} verts exceeds {VERTS_CAP}"
    assert draws <= DRAWS_CAP, f"{name}: {draws} draws exceeds {DRAWS_CAP}"
    assert abs(lo[2]) < 1e-3, f"{name}: min Z {lo[2]} not grounded at 0"
    return root


def main():
    opts = common.args()
    out_dir = opts["out"] or os.path.join(common.MODELS, "actives")
    os.makedirs(out_dir, exist_ok=True)
    for name in ASSETS:
        root = build_one(name)
        common.export(root, os.path.join(out_dir, name + ".glb"))


if __name__ == "__main__":
    main()
