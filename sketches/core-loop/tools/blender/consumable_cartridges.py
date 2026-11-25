"""Pocket Consumable cartridges & world drop props (W47-C1-3D, grounded sheet g13).

Eight closed, watertight procedural GLBs under assets/models/consumables/, all within the
`prop` budget class (<= 2000 tris, <= 4600 verts, <= 2 draws), strictly using canon
src/core/palette.gd hexes (zero HAZARD #ff5a3c; flat non-emissive KINDNESS #d936b0 stripe
on foreman_memo ONLY):

  1. cons_cap_charge.glb      - Blasting Cap (Redjaw copper/charcoal demolition satchel + studs + pull ring)
  2. cons_nitro_siphon.glb    - Nitro Siphon (Spillway pressurized brass & warm golden-amber glass siphon)
  3. cons_anchor_flare.glb    - Anchor Flare (Highdraft flare canister + mint #8bf0d3 bite ring + copper cap)
  4. cons_overclock_card.glb  - Overclock Punchcard (Fleet brass-bound Hollerith card + amber #e5a044 relay pin)
  5. cons_foreman_memo.glb    - Foreman's Memo (Old Works seamless petrol casing + ONE flat #d936b0 stripe)
  6. cons_moss_patch.glb      - Moss's Emergency Patch (Keeper bolted bone/verdigris clamp + cross-rivet brace)
  7. cons_drop_cradle.glb     - World drop pickup cradle ring with amber offering collar + SocketCartridge
  8. cons_anchor_balloon.glb  - Deployed 18 m sky-grapple balloon prop with 360-deg mint bite ring + SocketBite

Axes (Blender Z-up; exported Y-up to Godot):
  - Every mesh rests cleanly with min Z = 0.0 (floor plane) and centered X/Y.
  - Deterministic bmesh + polish bake + canonical glTF indices.

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P consumable_cartridges.py [-- --out DIR]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

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
MINT = palette_gd.HEX["ARC"]
BRASS = palette_gd.HEX["BRASS"]
LEDGER = palette_gd.HEX["LEDGER"]
STEEL = palette_gd.HEX["STEEL"]
CABLE = palette_gd.HEX["CABLE"]
KINDNESS = palette_gd.HEX["KINDNESS"]
OLD_VERDIGRIS = palette_gd.HEX["OLD_VERDIGRIS"]

PAINT = "paint"
METAL = "hydraulic"
AMBER_GLASS = "cons_amber_glass"
MINT_RING = "field"
AMBER_RIM = "cons_amber_rim"
MEMO_ENAMEL = "ancient_enamel"

TRIS_CAP = 2000
VERTS_CAP = 4600
DRAWS_CAP = 2

ALONG_X = (0.0, math.pi / 2.0, 0.0)
ALONG_Y = (math.pi / 2.0, 0.0, 0.0)


def _register_slots():
    common.SLOTS[PAINT] = {"vc": True, "rough": 0.72, "metal": 0.0}
    common.SLOTS[METAL] = {"vc": True, "rough": 0.38, "metal": 0.62}
    common.SLOTS[AMBER_GLASS] = {"color": AMBER, "rough": 0.16, "metal": 0.05, "emit": 0.35}
    common.SLOTS[MINT_RING] = {"color": MINT, "rough": 0.34, "metal": 0.10, "emit": 0.55}
    common.SLOTS[AMBER_RIM] = {"color": AMBER, "rough": 0.36, "metal": 0.18, "emit": 0.32}
    common.SLOTS[MEMO_ENAMEL] = {"vc": True, "rough": 0.50, "metal": 0.0}


def _oct_outline(rx, ry):
    """Regular-feel chamfered octagon outline."""
    cx, cy = rx * 0.42, ry * 0.42
    return [
        (-rx + cx, -ry), (rx - cx, -ry),
        (rx, -ry + cy), (rx, ry - cy),
        (rx - cx, ry), (-rx + cx, ry),
        (-rx, ry - cy), (-rx, -ry + cy),
    ]


def _chamfer_rect(w, h, c):
    hw, hh = w * 0.5, h * 0.5
    return [
        (-hw + c, -hh), (hw - c, -hh),
        (hw, -hh + c), (hw, hh - c),
        (hw - c, hh), (-hw + c, hh),
        (-hw, hh - c), (-hw, -hh + c),
    ]


def _ground_root(root):
    """Shift every mesh child vertically so the asset's bounding box min Z sits exactly at 0.0."""
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


def build_cap_charge(p, root):
    """Copper/charcoal octagonal demolition satchel cartridge + blasting cap studs + pull ring.
    Strictly zero HAZARD #ff5a3c."""
    zc = 0.155
    p.cyl(PAINT, 0.145, 0.145, 0.46, segs=8, loc=(-0.03, 0.0, zc), rot=ALONG_X, color=COPPER)
    for sx in (-1.0, 1.0):
        x_end = -0.03 + sx * 0.245
        p.cyl(PAINT, 0.132, 0.112, 0.04, segs=8, loc=(x_end, 0.0, zc),
              rot=(0.0, sx * math.pi / 2.0, 0.0), color=RUST)

    for bx in (-0.15, 0.09):
        p.cyl(METAL, 0.160, 0.160, 0.068, segs=8, loc=(bx, 0.0, zc), rot=ALONG_X, color=CHARCOAL)
        for ang_deg in (0, 90, 180, 270):
            a = math.radians(ang_deg)
            ny, nz = math.cos(a), math.sin(a)
            p.box(METAL, (0.044, 0.032, 0.032),
                  loc=(bx, ny * 0.155, zc + nz * 0.155),
                  rot=(a, 0.0, 0.0), color=STEEL)

    p.box(METAL, (0.29, 0.074, 0.030), loc=(-0.03, 0.0, zc + 0.142), color=CHARCOAL)
    for sx in (-0.115, -0.03, 0.055):
        p.cyl(METAL, 0.034, 0.029, 0.048, segs=6, loc=(sx, 0.0, zc + 0.175), color=COPPER)
        p.cyl(METAL, 0.021, 0.021, 0.020, segs=6, loc=(sx, 0.0, zc + 0.205), color=BONE)

    p.cyl(METAL, 0.058, 0.050, 0.036, segs=6, loc=(-0.295, 0.0, zc),
          rot=(0.0, -math.pi / 2.0, 0.0), color=CHARCOAL)

    p.cyl(METAL, 0.052, 0.042, 0.048, segs=8, loc=(0.245, 0.0, zc), rot=ALONG_X, color=CHARCOAL)
    p.rod(METAL, (0.25, 0.0, zc), (0.305, 0.0, zc), 0.015, segs=6, color=STEEL)
    p.ring(METAL, 0.058, 0.088, 0.026, segs=12, loc=(0.355, 0.0, zc),
           rot=(math.pi / 2.0, 0.0, 0.0), color=STEEL)

    common.empty("SocketFX", loc=(0.0, 0.0, zc + 0.22), parent=root)


def build_nitro_siphon(p, root):
    """Pressurized brass/amber glass siphon cartridge (warm golden-amber #e5a044 accent)."""
    zc = 0.155
    p.cyl(AMBER_GLASS, 0.112, 0.112, 0.30, segs=16, loc=(-0.03, 0.0, zc), rot=ALONG_X)
    p.cyl(AMBER_GLASS, 0.112, 0.068, 0.065, segs=16, loc=(0.152, 0.0, zc), rot=ALONG_X)

    p.cyl(METAL, 0.134, 0.128, 0.075, segs=12, loc=(-0.21, 0.0, zc), rot=ALONG_X, color=BRASS)
    p.cyl(METAL, 0.140, 0.140, 0.026, segs=12, loc=(-0.172, 0.0, zc), rot=ALONG_X, color=CHARCOAL)
    p.cyl(METAL, 0.055, 0.040, 0.050, segs=8, loc=(-0.268, 0.0, zc),
          rot=(0.0, -math.pi / 2.0, 0.0), color=COPPER)
    p.cyl(METAL, 0.026, 0.026, 0.032, segs=6, loc=(-0.302, 0.0, zc),
          rot=(0.0, -math.pi / 2.0, 0.0), color=STEEL)

    p.cyl(METAL, 0.130, 0.130, 0.034, segs=12, loc=(0.122, 0.0, zc), rot=ALONG_X, color=BRASS)
    p.cyl(METAL, 0.082, 0.064, 0.070, segs=12, loc=(0.215, 0.0, zc), rot=ALONG_X, color=BRASS)
    p.cyl(METAL, 0.052, 0.052, 0.065, segs=10, loc=(0.278, 0.0, zc), rot=ALONG_X, color=CHARCOAL)
    p.ring(METAL, 0.036, 0.068, 0.032, segs=12, loc=(0.318, 0.0, zc), rot=ALONG_X, color=BRASS)

    for k in range(4):
        a = math.radians(45 + k * 90)
        ry, rz = 0.126 * math.cos(a), 0.126 * math.sin(a)
        p.rod(METAL, (-0.175, ry, zc + rz), (0.125, ry, zc + rz), 0.013, segs=6, color=COPPER)

    p.box(METAL, (0.31, 0.12, 0.036), loc=(-0.03, 0.0, 0.020), color=CHARCOAL)
    p.cyl(METAL, 0.016, 0.016, 0.036, segs=6, loc=(-0.03, 0.0, zc + 0.132), color=COPPER)
    p.cyl(METAL, 0.044, 0.044, 0.024, segs=10, loc=(-0.03, 0.0, zc + 0.168),
          rot=ALONG_Y, color=BRASS)
    p.cyl(METAL, 0.032, 0.032, 0.028, segs=10, loc=(-0.03, 0.0, zc + 0.168),
          rot=ALONG_Y, color=BONE)

    common.empty("SocketFX", loc=(0.33, 0.0, zc), parent=root)


def build_anchor_flare(p, root):
    """Upright sky-grapple balloon canister + mint #8bf0d3 bite ring + copper beacon cap."""
    p.cyl(METAL, 0.145, 0.118, 0.055, segs=12, loc=(0.0, 0.0, 0.028), color=CHARCOAL)
    for k in range(4):
        a = k * math.pi / 2.0 + math.pi / 4.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.070, 0.026, 0.130),
              loc=(fx * 0.128, fy * 0.128, 0.075),
              rot=(0.0, 0.0, a), color=STEEL)

    p.cyl(METAL, 0.106, 0.106, 0.30, segs=12, loc=(0.0, 0.0, 0.205), color=BRASS)
    for rz in (0.12, 0.205, 0.29):
        p.ring(METAL, 0.104, 0.122, 0.024, segs=12, loc=(0.0, 0.0, rz), color=COPPER)

    p.ring(MINT_RING, 0.112, 0.158, 0.044, segs=16, loc=(0.0, 0.0, 0.375))
    for k in range(4):
        a = k * math.pi / 2.0
        p.box(METAL, (0.036, 0.028, 0.056),
              loc=(math.cos(a) * 0.115, math.sin(a) * 0.115, 0.375),
              rot=(0.0, 0.0, a), color=CHARCOAL)

    p.cyl(METAL, 0.116, 0.095, 0.070, segs=12, loc=(0.0, 0.0, 0.440), color=COPPER)
    p.ring(METAL, 0.056, 0.092, 0.042, segs=12, loc=(0.0, 0.0, 0.495), color=CHARCOAL)
    p.cyl(METAL, 0.052, 0.044, 0.030, segs=12, loc=(0.0, 0.0, 0.495), color=BONE)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.525), parent=root)


def build_overclock_card(p, root):
    """Hollerith punched brass-bound card cartridge with AMBER #e5a044 relay pin."""
    p.box(METAL, (0.54, 0.14, 0.070), loc=(0.0, 0.0, 0.035), color=CHARCOAL)
    for k in range(5):
        tx = -0.18 + k * 0.09
        p.box(METAL, (0.048, 0.040, 0.028), loc=(tx, -0.075, 0.026), color=BRASS)

    tilt = Matrix.Translation((0.0, 0.0, 0.225)) @ Matrix.Rotation(math.radians(78.0), 4, "X")
    w, h, n = 0.52, 0.34, 0.085
    frame_pts = [
        (-w / 2, -h / 2), (w / 2, -h / 2),
        (w / 2, h / 2 - n), (w / 2 - n, h / 2),
        (-w / 2, h / 2),
    ]
    p.prism(METAL, frame_pts, 0.042, matrix=tilt, color=BRASS)

    iw, ih, inotch = 0.45, 0.27, 0.068
    card_pts = [
        (-iw / 2, -ih / 2), (iw / 2, -ih / 2),
        (iw / 2, ih / 2 - inotch), (iw / 2 - inotch, ih / 2),
        (-iw / 2, ih / 2),
    ]
    p.prism(PAINT, card_pts, 0.052, matrix=tilt, color=LEDGER)

    hole_rows = (
        (-0.16, 0.065), (-0.08, 0.065), (0.00, 0.065), (0.08, 0.065),
        (-0.16, 0.005), (-0.04, 0.005), (0.06, 0.005), (0.15, 0.005),
        (-0.12, -0.055), (0.00, -0.055), (0.11, -0.055),
    )
    for hx, hy in hole_rows:
        m = tilt @ Matrix.Translation((hx, hy, 0.0))
        r = bmesh.ops.create_cube(p.bm, size=1.0, matrix=m @ Matrix.Diagonal((0.042, 0.022, 0.060, 1.0)))
        p.paint(p._faces(r["verts"]), PAINT, CHARCOAL)

    pin_base = tilt @ Matrix.Translation((-0.17, h / 2 + 0.030, 0.0))
    r_col = bmesh.ops.create_cone(
        p.bm, cap_ends=True, cap_tris=False, segments=8,
        radius1=0.036, radius2=0.032, depth=0.060,
        matrix=pin_base @ Matrix.Rotation(math.pi / 2.0, 4, "X"),
    )
    p.paint(p._faces(r_col["verts"]), METAL, COPPER)

    pin_tip = tilt @ Matrix.Translation((-0.17, h / 2 + 0.085, 0.0))
    r_pin = bmesh.ops.create_cone(
        p.bm, cap_ends=True, cap_tris=False, segments=10,
        radius1=0.028, radius2=0.018, depth=0.072,
        matrix=pin_tip @ Matrix.Rotation(math.pi / 2.0, 4, "X"),
    )
    p.paint(p._faces(r_pin["verts"]), PAINT, AMBER)

    bar_m = tilt @ Matrix.Translation((w / 2 + 0.016, -0.04, 0.0))
    r_bar = bmesh.ops.create_cube(p.bm, size=1.0, matrix=bar_m @ Matrix.Diagonal((0.032, 0.16, 0.046, 1.0)))
    p.paint(p._faces(r_bar["verts"]), PAINT, AMBER)

    common.empty("SocketFX", loc=(-0.17, 0.02, 0.47), parent=root)


def build_foreman_memo(p, root):
    """Seamless petrol casing with ONE flat Palette.KINDNESS #d936b0 stripe/panel ONLY.
    ZERO rivets, ZERO brass, ZERO emission/glow (strictly B6 compliant)."""
    p.prism(MEMO_ENAMEL, _chamfer_rect(0.46, 0.18, 0.035), 0.052,
            matrix=common.mtx((0.0, 0.0, 0.026)), color=VERDIGRIS)

    tilt = Matrix.Translation((0.0, 0.0, 0.215)) @ Matrix.Rotation(math.radians(68.0), 4, "X")
    p.prism(MEMO_ENAMEL, _chamfer_rect(0.52, 0.36, 0.042), 0.062, matrix=tilt, color=VERDIGRIS)

    p.prism(MEMO_ENAMEL, _chamfer_rect(0.44, 0.28, 0.018), 0.016,
            matrix=tilt @ Matrix.Translation((0.0, 0.0, 0.032)), color=LEDGER)

    p.prism(MEMO_ENAMEL, _chamfer_rect(0.066, 0.066, 0.008), 0.010,
            matrix=tilt @ Matrix.Translation((0.150, 0.074, 0.042)), color=SANDSTONE)

    p.prism(MEMO_ENAMEL, _chamfer_rect(0.084, 0.252, 0.008), 0.015,
            matrix=tilt @ Matrix.Translation((-0.146, 0.0, 0.041)), color=KINDNESS)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.39), parent=root)


def build_moss_patch(p, root):
    """Keeper bolted bone-and-verdigris repair cartridge with bold cross-rivet clamp."""
    p.box(METAL, (0.34, 0.14, 0.052), loc=(0.0, 0.0, 0.026), color=CHARCOAL)

    tilt = Matrix.Translation((0.0, 0.0, 0.235)) @ Matrix.Rotation(math.radians(74.0), 4, "X")
    p.prism(PAINT, _oct_outline(0.24, 0.24), 0.048, matrix=tilt, color=VERDIGRIS)
    p.prism(PAINT, _oct_outline(0.195, 0.195), 0.028,
            matrix=tilt @ Matrix.Translation((0.0, 0.0, 0.028)), color=BONE)

    arm_l, arm_w, arm_d = 0.31, 0.072, 0.032
    m_h = tilt @ Matrix.Translation((0.0, 0.0, 0.050))
    r_h = bmesh.ops.create_cube(p.bm, size=1.0, matrix=m_h @ Matrix.Diagonal((arm_l, arm_w, arm_d, 1.0)))
    p.paint(p._faces(r_h["verts"]), METAL, STEEL)
    r_v = bmesh.ops.create_cube(p.bm, size=1.0, matrix=m_h @ Matrix.Diagonal((arm_w, arm_l, arm_d, 1.0)))
    p.paint(p._faces(r_v["verts"]), METAL, STEEL)

    c_m = tilt @ Matrix.Translation((0.0, 0.0, 0.072))
    r_c = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=6,
                                radius1=0.042, radius2=0.038, depth=0.026, matrix=c_m)
    p.paint(p._faces(r_c["verts"]), METAL, COPPER)

    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bm_m = tilt @ Matrix.Translation((sx * 0.145, sy * 0.145, 0.046))
            rb = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=6,
                                       radius1=0.022, radius2=0.022, depth=0.022, matrix=bm_m)
            p.paint(p._faces(rb["verts"]), METAL, CHARCOAL)
    for rx, ry in ((-0.125, 0.0), (0.125, 0.0), (0.0, -0.125), (0.0, 0.125)):
        rm = tilt @ Matrix.Translation((rx, ry, 0.070))
        rr = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=6,
                                   radius1=0.017, radius2=0.017, depth=0.018, matrix=rm)
        p.paint(p._faces(rr["verts"]), METAL, COPPER)

    l_m = tilt @ Matrix.Translation((0.255, 0.0, 0.010))
    r_l = bmesh.ops.create_cube(p.bm, size=1.0, matrix=l_m @ Matrix.Diagonal((0.045, 0.15, 0.032, 1.0)))
    p.paint(p._faces(r_l["verts"]), METAL, COPPER)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.47), parent=root)


def build_drop_cradle(p, root):
    """Compact worn-steel & copper pickup cradle ring with AMBER #e5a044 offering collar."""
    p.ring(METAL, 0.24, 0.37, 0.070, segs=16, loc=(0.0, 0.0, 0.035), color=CHARCOAL, taper=0.025)
    p.ring(METAL, 0.22, 0.32, 0.030, segs=16, loc=(0.0, 0.0, 0.082), color=STEEL, taper=0.012)

    p.cyl(METAL, 0.24, 0.24, 0.048, segs=16, loc=(0.0, 0.0, 0.024), color=CHARCOAL)

    for k in range(3):
        a = k * math.tau / 3.0 + math.pi / 6.0
        fx, fy = math.cos(a), math.sin(a)
        p.box(METAL, (0.14, 0.10, 0.056), loc=(fx * 0.36, fy * 0.36, 0.028),
              rot=(0.0, 0.0, a), color=COPPER)
        p.cyl(METAL, 0.022, 0.022, 0.026, segs=6, loc=(fx * 0.39, fy * 0.39, 0.064), color=STEEL)

    p.ring(AMBER_RIM, 0.185, 0.225, 0.032, segs=16, loc=(0.0, 0.0, 0.104))

    common.empty("SocketCartridge", loc=(0.0, 0.0, 0.22), parent=root)


def build_anchor_balloon(p, root):
    """Hovering sky-grapple balloon canister deployed by Anchor Flare (g13 Row 2 Col 2).
    Bone/verdigris ribbed gas-bag + copper crown cap + 360-deg mint #8bf0d3 bite ring + tow eye."""
    p.ring(PAINT, 0.095, 0.155, 0.045, segs=12, loc=(0.0, 0.0, 0.155),
           rot=(math.pi / 2.0, 0.0, 0.0), color=STEEL)
    p.cyl(PAINT, 0.11, 0.14, 0.09, segs=8, loc=(0.0, 0.0, 0.34), color=CHARCOAL)

    for k in range(4):
        a = k * math.pi / 2.0 + math.pi / 4.0
        cx, cy = math.cos(a), math.sin(a)
        p.rod(PAINT, (cx * 0.10, cy * 0.10, 0.36), (cx * 0.56, cy * 0.56, 0.78),
              0.026, segs=6, color=CHARCOAL)

    p.ring(MINT_RING, 0.52, 0.65, 0.095, segs=16, loc=(0.0, 0.0, 0.80))

    p.cyl(PAINT, 0.56, 0.66, 0.16, segs=12, loc=(0.0, 0.0, 0.92), color=COPPER)

    p.uv(PAINT, 0.72, u=12, v=8, loc=(0.0, 0.0, 1.48), scale=(1.0, 1.0, 0.92), color=BONE)
    p.ring(PAINT, 0.68, 0.76, 0.14, segs=12, loc=(0.0, 0.0, 1.48), color=VERDIGRIS)
    for k in range(6):
        a = k * math.tau / 6.0
        cx, cy = math.cos(a), math.sin(a)
        p.rod(PAINT, (cx * 0.54, cy * 0.54, 0.98), (cx * 0.71, cy * 0.71, 1.48),
              0.028, segs=6, color=VERDIGRIS)
        p.rod(PAINT, (cx * 0.71, cy * 0.71, 1.48), (cx * 0.30, cy * 0.30, 2.08),
              0.028, segs=6, color=VERDIGRIS)

    p.cyl(PAINT, 0.32, 0.24, 0.12, segs=12, loc=(0.0, 0.0, 2.12), color=COPPER)
    p.cyl(PAINT, 0.12, 0.12, 0.08, segs=8, loc=(0.0, 0.0, 2.22), color=CHARCOAL)

    common.empty("SocketBite", loc=(0.0, 0.0, 0.80), parent=root)


def build_scrap_dice(p, root):
    """Cast brass-and-petrol executive audit die with indented charcoal pips and corner collars.
    Zero HAZARD #ff5a3c; zero KINDNESS purple (pure brass/petrol/ledger Old Works ledger hardware)."""
    p.prism(METAL, _chamfer_rect(0.42, 0.42, 0.075), 0.052,
            matrix=common.mtx((0.0, 0.0, 0.026)), color=VERDIGRIS)
    p.ring(METAL, 0.145, 0.185, 0.032, segs=12, loc=(0.0, 0.0, 0.068), color=COPPER)

    tilt = (
        Matrix.Translation((0.0, 0.0, 0.275))
        @ Matrix.Rotation(math.radians(24.0), 4, "X")
        @ Matrix.Rotation(math.radians(18.0), 4, "Y")
    )
    half = 0.145
    die_outline = _chamfer_rect(half * 2.0, half * 2.0, 0.036)
    p.prism(METAL, die_outline, half * 2.0, matrix=tilt, color=BRASS)

    face_rots = [
        (Matrix.Identity(4), 6),
        (Matrix.Rotation(math.pi, 4, "X"), 1),
        (Matrix.Rotation(math.pi / 2.0, 4, "X"), 5),
        (Matrix.Rotation(-math.pi / 2.0, 4, "X"), 2),
        (Matrix.Rotation(-math.pi / 2.0, 4, "Y"), 4),
        (Matrix.Rotation(math.pi / 2.0, 4, "Y"), 3),
    ]
    pip_layouts = {
        1: [(0.0, 0.0)],
        2: [(-0.055, -0.055), (0.055, 0.055)],
        3: [(-0.060, -0.060), (0.0, 0.0), (0.060, 0.060)],
        4: [(-0.055, -0.055), (0.055, -0.055), (-0.055, 0.055), (0.055, 0.055)],
        5: [(-0.058, -0.058), (0.058, -0.058), (0.0, 0.0), (-0.058, 0.058), (0.058, 0.058)],
        6: [(-0.058, -0.064), (0.058, -0.064), (-0.058, 0.0), (0.058, 0.0), (-0.058, 0.064), (0.058, 0.064)],
    }
    for rot_m, count in face_rots:
        fm = tilt @ rot_m
        p.prism(PAINT, _chamfer_rect(0.215, 0.215, 0.022), 0.018,
                matrix=fm @ Matrix.Translation((0.0, 0.0, half + 0.006)), color=VERDIGRIS)
        pip_col = AMBER if count >= 5 else LEDGER
        for px, py in pip_layouts[count]:
            pm = fm @ Matrix.Translation((px, py, half + 0.019))
            r_pip = bmesh.ops.create_cone(
                p.bm, cap_ends=True, cap_tris=False, segments=8,
                radius1=0.022, radius2=0.018, depth=0.016, matrix=pm,
            )
            p.paint(p._faces(r_pip["verts"]), PAINT, pip_col)

    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bm = tilt @ Matrix.Translation((sx * 0.135, sy * 0.135, 0.0))
            rb = bmesh.ops.create_cube(p.bm, size=1.0, matrix=bm @ Matrix.Diagonal((0.044, 0.044, 0.072, 1.0)))
            p.paint(p._faces(rb["verts"]), METAL, CHARCOAL)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.50), parent=root)


def build_duplicator_spool(p, root):
    """Keeper twin-reel carbon duplicator tape cartridge with copper reels and AMBER index tab."""
    p.box(METAL, (0.50, 0.14, 0.048), loc=(0.0, 0.0, 0.024), color=CHARCOAL)

    tilt = Matrix.Translation((0.0, 0.0, 0.215)) @ Matrix.Rotation(math.radians(78.0), 4, "X")
    p.prism(METAL, _chamfer_rect(0.54, 0.34, 0.038), 0.072, matrix=tilt, color=VERDIGRIS)
    p.prism(METAL, _chamfer_rect(0.47, 0.26, 0.024), 0.084, matrix=tilt, color=BONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            rm = tilt @ Matrix.Translation((sx * 0.20, sy * 0.098, 0.0))
            rb = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=6,
                                       radius1=0.018, radius2=0.018, depth=0.098, matrix=rm)
            p.paint(p._faces(rb["verts"]), METAL, CHARCOAL)

    for sx in (-0.135, 0.135):
        rm = tilt @ Matrix.Translation((sx, 0.015, 0.0))
        rt = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=12,
                                   radius1=0.092, radius2=0.092, depth=0.104, matrix=rm)
        p.paint(p._faces(rt["verts"]), METAL, CHARCOAL)
        for sz in (-0.056, 0.056):
            fm = tilt @ Matrix.Translation((sx, 0.015, sz))
            rf = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=12,
                                       radius1=0.106, radius2=0.106, depth=0.018, matrix=fm)
            p.paint(p._faces(rf["verts"]), METAL, COPPER)
        rh = bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=8,
                                   radius1=0.038, radius2=0.032, depth=0.145, matrix=rm)
        p.paint(p._faces(rh["verts"]), METAL, STEEL)

    b_m = tilt @ Matrix.Translation((0.0, -0.145, 0.0))
    rb_bar = bmesh.ops.create_cube(p.bm, size=1.0, matrix=b_m @ Matrix.Diagonal((0.30, 0.055, 0.088, 1.0)))
    p.paint(p._faces(rb_bar["verts"]), METAL, CHARCOAL)
    t_m = tilt @ Matrix.Translation((0.0, 0.185, 0.0))
    rt_tab = bmesh.ops.create_cube(p.bm, size=1.0, matrix=t_m @ Matrix.Diagonal((0.20, 0.056, 0.068, 1.0)))
    p.paint(p._faces(rt_tab["verts"]), AMBER_RIM)

    common.empty("SocketFX", loc=(0.0, 0.0, 0.44), parent=root)


def build_overload_fuse(p, root):
    """Heavy industrial ceramic-and-copper cartridge fuse with MINT #8bf0d3 arc filament window
    and brass knife-blade contact tabs. Zero HAZARD #ff5a3c."""
    zc = 0.155
    p.cyl(METAL, 0.108, 0.108, 0.28, segs=12, loc=(0.0, 0.0, zc), rot=ALONG_X, color=BONE)
    for rx in (-0.085, 0.0, 0.085):
        p.ring(METAL, 0.104, 0.132, 0.028, segs=12, loc=(rx, 0.0, zc), rot=ALONG_X, color=BONE)

    p.ring(MINT_RING, 0.108, 0.138, 0.044, segs=14, loc=(-0.042, 0.0, zc), rot=ALONG_X)
    p.ring(MINT_RING, 0.108, 0.138, 0.044, segs=14, loc=(0.042, 0.0, zc), rot=ALONG_X)
    p.box(MINT_RING, (0.14, 0.042, 0.042), loc=(0.0, 0.0, zc + 0.125))

    for sx in (-1.0, 1.0):
        p.cyl(METAL, 0.132, 0.132, 0.095, segs=12, loc=(sx * 0.185, 0.0, zc), rot=ALONG_X, color=COPPER)
        p.cyl(METAL, 0.140, 0.140, 0.026, segs=12, loc=(sx * 0.142, 0.0, zc), rot=ALONG_X, color=CHARCOAL)
        p.box(METAL, (0.115, 0.032, 0.118), loc=(sx * 0.285, 0.0, zc), color=BRASS)
        p.cyl(METAL, 0.024, 0.024, 0.285, segs=6, loc=(sx * 0.185, 0.0, zc), color=STEEL)

    p.box(METAL, (0.36, 0.14, 0.038), loc=(0.0, 0.0, 0.019), color=CHARCOAL)

    common.empty("SocketFX", loc=(0.0, 0.0, zc + 0.16), parent=root)


CONSUMABLES = {
    "cons_cap_charge": (
        build_cap_charge,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.04, "ao_strength": 0.36, "ao_reach": 0.26, "edge": 0.14},
    ),
    "cons_nitro_siphon": (
        build_nitro_siphon,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.05, "ao_strength": 0.34, "ao_reach": 0.26, "edge": 0.12},
    ),
    "cons_anchor_flare": (
        build_anchor_flare,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.04, "ao_strength": 0.34, "ao_reach": 0.26, "edge": 0.14},
    ),
    "cons_overclock_card": (
        build_overclock_card,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.05, "ao_strength": 0.30, "ao_reach": 0.24, "edge": 0.12},
    ),
    "cons_foreman_memo": (
        build_foreman_memo,
        {
            "detail": 1,
            "bevel": 0.008,
            "bevel_min": 0.03,
            "ao_strength": 0.20,
            "ao_reach": 0.22,
            "edge": 0.0,
            "bake_keep": (common.rgba(KINDNESS)[:3],),
        },
    ),
    "cons_moss_patch": (
        build_moss_patch,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.04, "ao_strength": 0.36, "ao_reach": 0.25, "edge": 0.14},
    ),
    "cons_scrap_dice": (
        build_scrap_dice,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.04, "ao_strength": 0.30, "ao_reach": 0.24, "edge": 0.10},
    ),
    "cons_duplicator_spool": (
        build_duplicator_spool,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.04, "ao_strength": 0.34, "ao_reach": 0.25, "edge": 0.12},
    ),
    "cons_overload_fuse": (
        build_overload_fuse,
        {"detail": 1, "bevel": 0.006, "bevel_min": 0.04, "ao_strength": 0.34, "ao_reach": 0.25, "edge": 0.12},
    ),
    "cons_drop_cradle": (
        build_drop_cradle,
        {"detail": 1, "bevel": 0.007, "bevel_min": 0.05, "ao_strength": 0.34, "ao_reach": 0.26, "edge": 0.12},
    ),
    "cons_anchor_balloon": (
        build_anchor_balloon,
        {"detail": 1, "bevel": 0.008, "bevel_min": 0.08, "ao_strength": 0.34, "ao_reach": 0.22, "edge": 0.10},
    ),
}


def build_one(name):
    builder, pol_opts = CONSUMABLES[name]
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
    print(
        f"CONSUMABLE {name:20s} {tris:4d}T {verts:4d}V {draws}D "
        f"size=({dims[0]:.2f}, {dims[1]:.2f}, {dims[2]:.2f})m minZ={lo[2]:.4f}"
    )
    assert tris <= TRIS_CAP, f"{name}: {tris} tris exceeds {TRIS_CAP}"
    assert verts <= VERTS_CAP, f"{name}: {verts} verts exceeds {VERTS_CAP}"
    assert draws <= DRAWS_CAP, f"{name}: {draws} draws exceeds {DRAWS_CAP}"
    assert abs(lo[2]) < 1e-3, f"{name}: min Z {lo[2]} not grounded at 0"
    return root


def main():
    opts = common.args()
    out_dir = opts["out"] or os.path.join(common.MODELS, "consumables")
    os.makedirs(out_dir, exist_ok=True)
    for name in CONSUMABLES:
        root = build_one(name)
        glb_path = os.path.join(out_dir, name + ".glb")
        common.export(root, glb_path)


if __name__ == "__main__":
    main()
