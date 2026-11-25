"""W50 Economy World Stations & Props (Scrapper, Part Press, Tri-Terminal, Scrap Ingot).

Four closed, watertight graphic-novel GLBs under assets/models/stations/, all within the
`prop` budget class (<= 2000 tris, <= 4600 verts, <= 2 draws), strictly using canon
src/core/palette.gd hexes (zero HAZARD #ff5a3c, zero KINDNESS purple):

  1. station_scrapper.glb     - Heavy jaw-crusher Scrapper station (hopper + twin copper rollers + flywheel + ingot tray)
  2. station_part_press.glb   - Heavy gantry Part Press 3D printer (H-frame + hydraulic ram + glowing amber die bed)
  3. station_tri_terminal.glb - Moss's 3-bay Tri-Terminal booth (1 lit eye bay + 2 brass-shuttered bays)
  4. prop_scrap_ingot.glb     - Stamped bevelled metal Scrap Ingot bar with riveted tier collar

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P w50_stations.py [-- --out DIR]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))

import common
import palette_gd
import polish
from common import Part

BONE = palette_gd.HEX["SAND"]
SANDSTONE = palette_gd.HEX["SANDSTONE"]
RUST = palette_gd.HEX["RUST"]
COPPER = palette_gd.HEX["COPPER"]
CHARCOAL = palette_gd.HEX["CHARCOAL"]
VERDIGRIS = palette_gd.HEX["VERDIGRIS"]
AMBER = palette_gd.HEX["AMBER"]
BRASS = palette_gd.HEX["BRASS"]
STEEL = palette_gd.HEX["STEEL"]
LEDGER = palette_gd.HEX["LEDGER"]

METAL = "hydraulic"
AMBER_GLOW = "cons_amber_rim"

TRIS_CAP = 2000
VERTS_CAP = 4600
DRAWS_CAP = 2

ALONG_X = (0.0, math.pi / 2.0, 0.0)
ALONG_Y = (math.pi / 2.0, 0.0, 0.0)


def _register_slots():
    common.SLOTS[METAL] = {"vc": True, "rough": 0.42, "metal": 0.48}
    common.SLOTS[AMBER_GLOW] = {"color": AMBER, "rough": 0.30, "metal": 0.15, "emit": 1.15}


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


def build_station_scrapper(p, root):
    """Heavy industrial Scrapper jaw-crusher station (2.6 m wide x 2.8 m tall):
    wide flared intake hopper, twin toothed copper crusher drums, side flywheel, ingot chute."""
    p.box(METAL, (2.30, 1.95, 0.22), loc=(0.0, 0.0, 0.11), color=CHARCOAL)
    for sx in (-1.05, 1.05):
        for sy in (-0.85, 0.85):
            p.box(METAL, (0.32, 0.32, 0.28), loc=(sx, sy, 0.14), color=STEEL)

    p.box(METAL, (1.88, 1.56, 1.24), loc=(0.0, -0.05, 0.84), color=VERDIGRIS)
    for sx in (-0.94, 0.94):
        p.box(METAL, (0.14, 1.62, 1.28), loc=(sx, -0.05, 0.84), color=CHARCOAL)
    p.box(METAL, (1.46, 0.14, 0.72), loc=(0.0, 0.76, 0.92), color=RUST)

    p.cyl(METAL, 0.86, 1.22, 0.78, segs=4, loc=(0.0, -0.05, 1.84),
          rot=(0.0, 0.0, math.pi / 4.0), color=COPPER)
    p.ring(METAL, 0.96, 1.26, 0.12, segs=4, loc=(0.0, -0.05, 2.22),
           rot=(0.0, 0.0, math.pi / 4.0), color=CHARCOAL)

    for sy in (-0.30, 0.20):
        p.cyl(METAL, 0.24, 0.24, 1.38, segs=8, loc=(0.0, sy, 1.62), rot=ALONG_X, color=STEEL)
        for rx in (-0.42, 0.0, 0.42):
            p.ring(METAL, 0.23, 0.30, 0.10, segs=6, loc=(rx, sy, 1.62), rot=ALONG_X, color=COPPER)

    p.cyl(METAL, 0.12, 0.12, 0.36, segs=8, loc=(1.10, -0.05, 0.94), rot=ALONG_X, color=STEEL)
    p.ring(METAL, 0.46, 0.62, 0.14, segs=12, loc=(1.22, -0.05, 0.94), rot=ALONG_X, color=COPPER)
    for k in range(3):
        a = k * math.pi / 3.0
        p.box(METAL, (0.10, 0.12, 1.02), loc=(1.22, -0.05, 0.94), rot=(a, 0.0, 0.0), color=CHARCOAL)

    p.box(METAL, (1.10, 0.62, 0.16), loc=(0.0, -0.96, 0.44),
          rot=(math.radians(18.0), 0.0, 0.0), color=STEEL)
    for sx in (-0.52, 0.52):
        p.box(METAL, (0.10, 0.64, 0.24), loc=(sx, -0.96, 0.52),
              rot=(math.radians(18.0), 0.0, 0.0), color=CHARCOAL)
    p.box(AMBER_GLOW, (0.86, 0.12, 0.22), loc=(0.0, -0.84, 0.66))
    p.box(METAL, (0.48, 0.22, 0.14), loc=(0.0, -1.04, 0.52),
          rot=(math.radians(18.0), 0.0, 0.0), color=BONE)

    common.empty("SocketHopper", loc=(0.0, -0.05, 2.28), parent=root)
    common.empty("SocketTray", loc=(0.0, -1.04, 0.60), parent=root)
    common.empty("SocketPrompt", loc=(0.0, 0.0, 2.75), parent=root)


def build_station_part_press(p, root):
    """Heavy gantry Part Press / 3D Printer station (2.6 m wide x 3.1 m tall):
    massive cast H-frame columns, overhead copper hydraulic ram, glowing AMBER fabrication anvil."""
    p.box(METAL, (2.48, 1.96, 0.24), loc=(0.0, 0.0, 0.12), color=CHARCOAL)
    p.box(METAL, (2.06, 1.60, 0.48), loc=(0.0, 0.0, 0.46), color=VERDIGRIS)

    for sx in (-0.98, 0.98):
        p.box(METAL, (0.36, 0.54, 2.36), loc=(sx, 0.0, 1.56), color=CHARCOAL)
        p.box(METAL, (0.42, 0.26, 2.10), loc=(sx, 0.0, 1.56), color=COPPER)
        p.box(METAL, (0.46, 0.64, 0.16), loc=(sx, 0.0, 0.34), color=STEEL)

    p.box(METAL, (2.48, 0.78, 0.46), loc=(0.0, 0.0, 2.74), color=RUST)
    p.box(METAL, (2.56, 0.84, 0.12), loc=(0.0, 0.0, 2.52), color=CHARCOAL)
    for sx in (-0.72, 0.72):
        p.cyl(METAL, 0.18, 0.16, 0.42, segs=10, loc=(sx, 0.0, 3.16), color=BRASS)

    p.cyl(METAL, 0.28, 0.28, 0.72, segs=12, loc=(0.0, 0.0, 2.32), color=COPPER)
    p.cyl(METAL, 0.15, 0.15, 0.62, segs=10, loc=(0.0, 0.0, 1.82), color=STEEL)
    p.box(METAL, (1.16, 0.78, 0.22), loc=(0.0, 0.0, 1.54), color=CHARCOAL)
    p.box(METAL, (1.02, 0.66, 0.08), loc=(0.0, 0.0, 1.40), color=BONE)

    p.box(METAL, (1.36, 1.06, 0.18), loc=(0.0, 0.0, 0.78), color=STEEL)
    p.box(AMBER_GLOW, (0.98, 0.68, 0.10), loc=(0.0, 0.0, 0.90))
    p.box(AMBER_GLOW, (1.10, 0.10, 0.14), loc=(0.0, -0.40, 2.74))

    p.box(METAL, (0.38, 0.48, 0.56), loc=(-1.34, 0.0, 1.24),
          rot=(0.0, math.radians(-16.0), 0.0), color=COPPER)

    common.empty("SocketBed", loc=(0.0, 0.0, 1.02), parent=root)
    common.empty("SocketRam", loc=(0.0, 0.0, 1.42), parent=root)
    common.empty("SocketPrompt", loc=(0.0, 0.0, 3.45), parent=root)


def build_station_tri_terminal(p, root):
    """Moss's W50 Tri-Terminal kiosk (2.7 m wide x 2.1 m tall):
    three angled Keeper/brass display bays — left bay lit AMBER (revealed), middle & right
    hooded with riveted brass mystery shutters."""
    p.box(METAL, (2.68, 1.06, 0.20), loc=(0.0, 0.0, 0.10), color=CHARCOAL)
    p.box(METAL, (2.48, 0.90, 0.86), loc=(0.0, 0.04, 0.62), color=VERDIGRIS)
    p.box(METAL, (2.58, 0.98, 0.12), loc=(0.0, 0.02, 1.08), color=COPPER)

    for idx, bx in enumerate((-0.82, 0.0, 0.82)):
        p.box(METAL, (0.72, 0.66, 0.78), loc=(bx, 0.08, 1.52), color=CHARCOAL)
        p.box(METAL, (0.76, 0.82, 0.10), loc=(bx, -0.02, 1.94),
              rot=(math.radians(10.0), 0.0, 0.0), color=RUST)
        if idx == 0:
            p.box(METAL, (0.58, 0.08, 0.56), loc=(bx, -0.25, 1.52), color=BONE)
            p.box(AMBER_GLOW, (0.48, 0.08, 0.46), loc=(bx, -0.27, 1.52))
        else:
            p.box(METAL, (0.58, 0.08, 0.56), loc=(bx, -0.25, 1.52), color=BRASS)
            for sz in (1.36, 1.52, 1.68):
                p.box(METAL, (0.52, 0.06, 0.06), loc=(bx, -0.29, sz), color=CHARCOAL)
            p.box(AMBER_GLOW, (0.14, 0.06, 0.14), loc=(bx, -0.30, 1.52))

    p.box(METAL, (2.56, 0.14, 0.10), loc=(0.0, 0.16, 2.04), color=STEEL)
    p.cyl(METAL, 0.04, 0.03, 0.42, segs=6, loc=(-1.12, 0.16, 2.24), color=COPPER)
    p.ico(AMBER_GLOW, 0.075, subdiv=1, loc=(-1.12, 0.16, 2.48))
    p.box(METAL, (0.28, 0.12, 0.32), loc=(1.18, -0.36, 0.72), color=BRASS)

    common.empty("SocketBay0", loc=(-0.82, -0.32, 1.52), parent=root)
    common.empty("SocketBay1", loc=(0.0, -0.32, 1.52), parent=root)
    common.empty("SocketBay2", loc=(0.82, -0.32, 1.52), parent=root)
    common.empty("SocketPrompt", loc=(0.0, 0.0, 2.55), parent=root)


def build_prop_scrap_ingot(p, root):
    """Chunky stamped trapezoidal Scrap Ingot bar with riveted copper/amber tie strap."""
    trap = [(-0.22, -0.10), (0.22, -0.10), (0.16, 0.10), (-0.16, 0.10)]
    rot_m = Matrix.Translation((0.0, 0.0, 0.10)) @ Matrix.Rotation(math.pi / 2.0, 4, "X")
    p.prism(METAL, trap, 0.56, matrix=rot_m, color=STEEL)
    p.box(METAL, (0.16, 0.58, 0.22), loc=(0.0, 0.0, 0.11), color=COPPER)
    p.box(AMBER_GLOW, (0.08, 0.60, 0.07), loc=(0.0, 0.0, 0.21))
    for sy in (-0.18, 0.18):
        p.cyl(METAL, 0.036, 0.036, 0.22, segs=6, loc=(0.0, sy, 0.11), color=BONE)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.26), parent=root)


ASSETS = {
    "station_scrapper": (
        build_station_scrapper,
        {"detail": 1, "bevel": 0.014, "bevel_min": 0.24, "ao_strength": 0.34, "ao_reach": 0.55, "edge": 0.12},
    ),
    "station_part_press": (
        build_station_part_press,
        {"detail": 1, "bevel": 0.014, "bevel_min": 0.20, "ao_strength": 0.34, "ao_reach": 0.55, "edge": 0.12},
    ),
    "station_tri_terminal": (
        build_station_tri_terminal,
        {"detail": 1, "bevel": 0.012, "bevel_min": 0.16, "ao_strength": 0.32, "ao_reach": 0.48, "edge": 0.12},
    ),
    "prop_scrap_ingot": (
        build_prop_scrap_ingot,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.06, "ao_strength": 0.34, "ao_reach": 0.26, "edge": 0.14},
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
    print(f"STATION {name:24s} {tris:4d}T {verts:4d}V {draws}D size=({dims[0]:.2f}, {dims[1]:.2f}, {dims[2]:.2f})m minZ={lo[2]:.4f}")
    assert tris <= TRIS_CAP, f"{name}: {tris} tris exceeds {TRIS_CAP}"
    assert verts <= VERTS_CAP, f"{name}: {verts} verts exceeds {VERTS_CAP}"
    assert draws <= DRAWS_CAP, f"{name}: {draws} draws exceeds {DRAWS_CAP}"
    assert abs(lo[2]) < 1e-3, f"{name}: min Z {lo[2]} not grounded at 0"
    return root


def main():
    opts = common.args()
    out_dir = opts["out"] or os.path.join(common.MODELS, "stations")
    os.makedirs(out_dir, exist_ok=True)
    for name in ASSETS:
        root = build_one(name)
        common.export(root, os.path.join(out_dir, name + ".glb"))


if __name__ == "__main__":
    main()
