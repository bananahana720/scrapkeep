"""W50 Orbital Flywheel Satellite & Kit-Swap Relic 3D VFX Props.

Five closed, watertight graphic-novel GLBs under assets/models/vfx/, all within the
`prop` budget class (<= 2000 tris, <= 4600 verts, <= 2 draws), strictly using canon
src/core/palette.gd hexes (zero HAZARD #ff5a3c, zero KINDNESS purple):

  1. orbital_flywheel_sat.glb  - Single-surface (1D) toothed gyro flywheel satellite for MultiMeshInstance3D
  2. relic_halo_orb.glb        - Sable W3 halo_coil orbiting ceramic-and-mint lightning insulator orb
  3. relic_drill_auger.glb     - Rivet W1 drill_auger fluted spiral crusher drill bit
  4. relic_voltaic_halo.glb    - Sable W1 voltaic_ring flying brass conductive turbine ring
  5. relic_snare_beacon.glb    - Kest W3 updraft_snare airborne apex vortex trap cage

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P w50_orbitals_relics.py [-- --out DIR]
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

import common  # noqa: E402
import palette_gd  # noqa: E402
import polish  # noqa: E402
from common import Part  # noqa: E402

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


def _register_slots():
    common.SLOTS[METAL] = {"vc": True, "rough": 0.34, "metal": 0.56}
    common.SLOTS[ARC_GLOW] = {"color": MINT, "rough": 0.30, "metal": 0.10, "emit": 1.45}
    common.SLOTS[AMBER_GLOW] = {"color": AMBER, "rough": 0.30, "metal": 0.15, "emit": 1.35}


def build_orbital_flywheel_sat(p, root):
    """Single-draw (1D) toothed gyro flywheel satellite centered at origin (0, 0, 0) for
    MultiMeshInstance3D in orbital_satellites.gd (replaces raw BoxMesh!)."""
    # Heavy outer flywheel rim + 6 chunky impact gear teeth around perimeter.
    p.ring(METAL, 0.24, 0.38, 0.16, segs=12, loc=(0.0, 0.0, 0.0), color=AMBER)
    for k in range(6):
        a = k * math.tau / 6.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.14, 0.12, 0.18), loc=(fx * 0.41, fy * 0.41, 0.0),
              rot=(0.0, 0.0, a), color=COPPER)
    # 3 heavy charcoal spokes + riveted brass/bone central gyro spindle.
    for k in range(3):
        a = k * math.pi / 3.0
        p.box(METAL, (0.52, 0.085, 0.10), loc=(0.0, 0.0, 0.0), rot=(0.0, 0.0, a), color=CHARCOAL)
    p.cyl(METAL, 0.13, 0.13, 0.28, segs=10, loc=(0.0, 0.0, 0.0), color=BRASS)
    p.cyl(METAL, 0.07, 0.07, 0.36, segs=8, loc=(0.0, 0.0, 0.0), color=BONE)
    common.empty("SocketCenter", loc=(0.0, 0.0, 0.0), parent=root)


def build_relic_halo_orb(p, root):
    """Sable W3 halo_coil orbiting lightning insulator orb (centered at origin)."""
    # Central glowing MINT discharge sphere.
    p.ico(ARC_GLOW, 0.24, subdiv=1, loc=(0.0, 0.0, 0.0))
    # Equatorial ribbed bone insulator collar + copper retaining ring.
    p.ring(METAL, 0.25, 0.36, 0.10, segs=12, loc=(0.0, 0.0, 0.0), color=BONE)
    p.ring(METAL, 0.34, 0.40, 0.06, segs=12, loc=(0.0, 0.0, 0.0), color=COPPER)
    # Four radial brass spark-gap horns.
    for k in range(4):
        a = k * math.pi / 2.0
        fx, fy = math.cos(a), math.sin(a)
        p.rod(METAL, (fx * 0.30, fy * 0.30, 0.0), (fx * 0.48, fy * 0.48, 0.14), 0.036, segs=6, color=BRASS)
        p.ico(ARC_GLOW, 0.055, subdiv=1, loc=(fx * 0.50, fy * 0.50, 0.16))
    # Top & bottom charcoal axial caps.
    for sz in (-0.28, 0.28):
        p.cyl(METAL, 0.14, 0.09, 0.10, segs=8, loc=(0.0, 0.0, sz),
              rot=(math.pi if sz < 0 else 0.0, 0.0, 0.0), color=CHARCOAL)
    common.empty("SocketCenter", loc=(0.0, 0.0, 0.0), parent=root)


def build_relic_drill_auger(p, root):
    """Rivet W1 drill_auger fluted industrial crusher bit rising out of crater floor (Z >= 0)."""
    # Heavy charcoal crater collar ring at ground plane.
    p.ring(METAL, 0.52, 0.78, 0.16, segs=12, loc=(0.0, 0.0, 0.08), color=CHARCOAL)
    # Tapered steel core auger shaft.
    p.cyl(METAL, 0.46, 0.14, 1.38, segs=10, loc=(0.0, 0.0, 0.72), color=STEEL)
    # Stepped helical copper cutting flights spiraling up the shaft (bold graphic-novel read!).
    levels = 6
    for i in range(levels):
        t = i / float(levels - 1)
        z = 0.22 + t * 1.06
        r_out = 0.64 * (1.0 - t * 0.62)
        ang = i * math.radians(52.0)
        p.box(METAL, (r_out * 2.0, 0.18, 0.12), loc=(0.0, 0.0, z),
              rot=(math.radians(14.0), 0.0, ang), color=COPPER)
    # Glowing AMBER hot friction crown tip + collar pips.
    p.cyl(AMBER_GLOW, 0.16, 0.05, 0.22, segs=8, loc=(0.0, 0.0, 1.48))
    for k in range(4):
        a = k * math.pi / 2.0
        p.box(AMBER_GLOW, (0.14, 0.08, 0.10), loc=(math.cos(a) * 0.68, math.sin(a) * 0.68, 0.18),
              rot=(0.0, 0.0, a))
    common.empty("SocketTip", loc=(0.0, 0.0, 1.60), parent=root)


def build_relic_voltaic_halo(p, root):
    """Sable W1 voltaic_ring flying brass conductive turbine ring (unit radius ~1.0 m, scaled live)."""
    # Main chamfered brass conductive hoop.
    p.ring(METAL, 0.76, 0.96, 0.14, segs=16, loc=(0.0, 0.0, 0.0), color=BRASS)
    # Inner glowing MINT arc track ring.
    p.ring(ARC_GLOW, 0.68, 0.78, 0.08, segs=16, loc=(0.0, 0.0, 0.0))
    # Six chunky angled copper capacitor fins around outer rim.
    for k in range(6):
        a = k * math.tau / 6.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.22, 0.10, 0.18), loc=(fx * 1.02, fy * 1.02, 0.0),
              rot=(0.0, 0.0, a + math.radians(18.0)), color=COPPER)
    common.empty("SocketCenter", loc=(0.0, 0.0, 0.0), parent=root)


def build_relic_snare_beacon(p, root):
    """Kest W3 updraft_snare airborne apex vortex trap cage (centered at origin)."""
    # Upper & lower riveted copper vortex shroud rings.
    p.ring(METAL, 0.36, 0.48, 0.10, segs=12, loc=(0.0, 0.0, 0.34), color=COPPER)
    p.ring(METAL, 0.36, 0.48, 0.10, segs=12, loc=(0.0, 0.0, -0.34), color=COPPER)
    # 4 vertical charcoal cage ribs clamping the snare core.
    for k in range(4):
        a = k * math.pi / 2.0
        fx, fy = math.cos(a), math.sin(a)
        p.rod(METAL, (fx * 0.42, fy * 0.42, -0.34), (fx * 0.42, fy * 0.42, 0.34), 0.042, segs=6, color=CHARCOAL)
        # Side updraft louver vane fins.
        p.box(METAL, (0.20, 0.05, 0.28), loc=(fx * 0.52, fy * 0.52, 0.0),
              rot=(0.0, 0.0, a + math.radians(24.0)), color=BONE)
    # Glowing AMBER explosive snare core suspended inside.
    p.ico(AMBER_GLOW, 0.22, subdiv=1, loc=(0.0, 0.0, 0.0))
    common.empty("SocketCenter", loc=(0.0, 0.0, 0.0), parent=root)


ASSETS = {
    "orbital_flywheel_sat": (
        build_orbital_flywheel_sat,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.04, "ao_strength": 0.32, "ao_reach": 0.24, "edge": 0.14},
    ),
    "relic_halo_orb": (
        build_relic_halo_orb,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.04, "ao_strength": 0.30, "ao_reach": 0.24, "edge": 0.12},
    ),
    "relic_drill_auger": (
        build_relic_drill_auger,
        {"detail": 1, "bevel": 0.010, "bevel_min": 0.05, "ao_strength": 0.34, "ao_reach": 0.32, "edge": 0.14},
    ),
    "relic_voltaic_halo": (
        build_relic_voltaic_halo,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.05, "ao_strength": 0.30, "ao_reach": 0.28, "edge": 0.12},
    ),
    "relic_snare_beacon": (
        build_relic_snare_beacon,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.05, "ao_strength": 0.32, "ao_reach": 0.26, "edge": 0.12},
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

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    print(f"VFX_PROP {name:24s} {tris:4d}T {verts:4d}V {draws}D")
    assert tris <= TRIS_CAP, f"{name}: {tris} tris exceeds {TRIS_CAP}"
    assert verts <= VERTS_CAP, f"{name}: {verts} verts exceeds {VERTS_CAP}"
    assert draws <= DRAWS_CAP, f"{name}: {draws} draws exceeds {DRAWS_CAP}"
    if name == "orbital_flywheel_sat":
        assert draws == 1, f"{name}: MultiMesh satellite must be strictly 1 draw, got {draws}"
    return root


def main():
    opts = common.args()
    out_dir = opts["out"] or os.path.join(common.MODELS, "vfx")
    os.makedirs(out_dir, exist_ok=True)
    for name in ASSETS:
        root = build_one(name)
        common.export(root, os.path.join(out_dir, name + ".glb"))


if __name__ == "__main__":
    main()
