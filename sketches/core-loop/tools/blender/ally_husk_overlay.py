"""W47-TALLY-B-3D: Ghost Shift ally-husk ownership hardware overlays (24 Nov 2026).

Reusable zero-new-enemy-GLB hardware overlays that attach cleanly to wrecked ordinary Fleet oxide
bodies (chaser, lobber, plated_brute, boom_tender, and World 2/3 ordinary machines) so raised
Ghost-Shift allies read unmistakably against hostile Fleet machines and amber relic pickups at
Blazing speed and in 320 px greyscale (Master Bible §2.3, §2.5, §6.1, §9 Wave 47D; Opus Critique
Blocker 5 & N9; Taste & Mechanics Rubric §2 Tally Ghost Shift, B6).

Outputs under sketches/core-loop/assets/models/ally_husk/:
  ally_husk_clip.glb   Amber-sparking copper alligator jumper clip (attach x2 per husk).
                       Origin (0, 0, 0) at jaw bite seam; jaws clamp along -Y (Godot +Z),
                       insulated charcoal handles flare along +Y (Godot -Z).
                       Sockets: socket_bite, socket_spark, socket_lead.
  ally_husk_tag.glb    Forged oxblood/amber Hollerith punched work-order card tag (attach x1).
                       Origin (0, 0, 0) at slot bezel base; notched card rises along +Z (Godot +Y).
                       Sockets: socket_slot, socket_tick_0, socket_tick_1, socket_tick_2.
  ally_husk_mast.glb   Raised amber-sparking Jacob's-ladder clip mast & frayed trailing copper lead.
                       Origin (0, 0, 0) at chassis clamp pedestal; mast rises to +1.56 m (+Z / Godot +Y)
                       and frayed 3-strand lead sweeps rearward along -Y (Godot +Z).
                       Sockets: socket_base, socket_arc_left, socket_arc_right, socket_lead_tip,
                       socket_clip_feed_l, socket_clip_feed_r.
  ally_husk_lead.glb   1.0 m arched insulated copper jumper lead segment bridging clip <-> mast.
                       Origin (0, 0, 0) to (0, 1.0, 0) (Godot (0, 0, 0) to (0, 0, -1.0)).
                       Sockets: socket_start, socket_end.

Recommended Godot-space enemy anchor offsets (for W47-TALLY-B-CODE ally_husk_look.gd):
  chaser        (forward -Z, y in [-1.5, 1.5]):
    clip_l = (-0.82, 0.56,  0.04)  rot_deg = (  0,  75,  10)
    clip_r = ( 0.82, 0.56,  0.04)  rot_deg = (  0, -75, -10)
    tag    = ( 0.00, 0.88, -0.46)  rot_deg = ( 12,   0,   0)
    mast   = ( 0.00, 1.16,  0.34)  rot_deg = (  0,   0,   0)
  plated_brute  (forward +Z, y in [-1.1, 1.38]):
    clip_l = (-1.42, 0.88,  0.10)  rot_deg = (  0, 105,  10)
    clip_r = ( 1.42, 0.88,  0.10)  rot_deg = (  0,-105, -10)
    tag    = ( 0.00, 1.08,  1.16)  rot_deg = (-10, 180,   0)
    mast   = ( 0.00, 1.10, -0.35)  rot_deg = (  0, 180,   0)
  lobber        (forward +Z, y in [-2.0, 5.0]):
    clip_l = (-1.12, 1.28, -0.10)  rot_deg = (  0,  95,   8)
    clip_r = ( 1.12, 1.28, -0.10)  rot_deg = (  0, -95,  -8)
    tag    = ( 0.00, 0.52,  0.84)  rot_deg = (-14, 180,   0)
    mast   = ( 0.86, 1.48, -0.82)  rot_deg = (  0, 165,  -8)
  boom_tender   (forward -Z, y in [0.0, 2.3]):
    clip_l = (-1.14, 1.02, -0.20)  rot_deg = (  0,  82,   8)
    clip_r = ( 1.14, 1.02, -0.20)  rot_deg = (  0, -82,  -8)
    tag    = ( 0.00, 1.18, -1.26)  rot_deg = ( 12,   0,   0)
    mast   = ( 0.00, 1.56,  0.82)  rot_deg = (  0,   0,   0)

Colour discipline (B6 — enforced by assertion):
  Warm Palette.AMBER #E5A044, Palette.COPPER #B77843, Tally oxblood #5E232D, Palette.CHARCOAL #242A28,
  Palette.SAND/bone #D2C5A5, Palette.LEDGER_CREAM #F7F1E3, and Palette.STEEL #9AA0A0 ONLY.
  NEVER Palette.HAZARD #FF5A3C, Palette.ANCIENT #9DFF3C, Palette.KINDNESS #D936B0, or Palette.ARC #8BF0D3.

Material slots (standard HeroAssets.SLOTS — <= 2 draws per GLB, detail class budget):
  hydraulic     Metallic vertex-colour hardware (copper, charcoal, oxblood, bone, steel)
  paint         Matte vertex-colour card/insulation (vertex alpha 0 so no equipped paint tints it)
  class_accent  Emissive warm Palette.AMBER #E5A044 (sparks, arc, shift-tick punch holes)

Usage:
  blender --background --factory-startup --threads 2 --python-exit-code 1 \\
    --python sketches/core-loop/tools/blender/ally_husk_overlay.py -- [--out-dir DIR]
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common
from common import Part

OUT_DIR = os.path.join(common.MODELS, "ally_husk")

CAP_TRIS = 4000
CAP_VERTS = 8000
CAP_DRAWS = 2

AMBER = "e5a044"
COPPER = "b77843"
OXBLOOD = "5e232d"
CHARCOAL = "242a28"
BONE = "d2c5a5"
CREAM = "f7f1e3"
STEEL = "9aa0a0"

FORBIDDEN_HEXES = {"ff5a3c", "9dff3c", "d936b0", "8bf0d3"}
ALLOWED_HEXES = {AMBER, COPPER, OXBLOOD, CHARCOAL, BONE, CREAM, STEEL}
assert ALLOWED_HEXES.isdisjoint(FORBIDDEN_HEXES), "B6 colour guard violated"


def setup_slots():
    """Configure common.SLOTS so class_accent exports as warm emissive Palette.AMBER #E5A044."""
    common.SLOTS["class_accent"] = {"color": AMBER, "emit": 1.6, "rough": 0.35}
    common.SLOTS["hydraulic"] = {"vc": True, "metal": 0.45, "rough": 0.36}
    common.SLOTS["paint"] = {"vc": True, "rough": 0.82}


def sharpen(part, crease=0.75):
    """Smooth faces, mark edges sharper than crease rad hard (matching shell_base._sharpen)."""
    part.bm.normal_update()
    for f in part.bm.faces:
        f.smooth = True
    for e in part.bm.edges:
        if e.is_manifold and e.calc_face_angle() > crease:
            e.smooth = False


def add_spark_bolt(part, pts, radius=0.016, slot="class_accent"):
    """Closed jagged electric arc along 3D polyline pts on the emissive AMBER slot."""
    for a, b in zip(pts, pts[1:]):
        part.rod(slot, a, b, radius, segs=5)
    for p in pts[1:-1]:
        part.ico(slot, radius * 1.45, subdiv=1, loc=p)


def add_spark_diamond(part, loc, sx=0.045, sy=0.045, sz=0.085, rot=(0, 0, 0), slot="class_accent"):
    """Closed faceted diamond spark flash — sharp angular electrical silhouette."""
    m = common.mtx(loc, rot)
    pts = [
        (sx, 0, 0), (0, sy, 0), (-sx, 0, 0), (0, -sy, 0),
        (0, 0, sz), (0, 0, -sz),
    ]
    vs = [part.bm.verts.new(m @ Vector(p)) for p in pts]
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append(part.bm.faces.new((vs[i], vs[j], vs[4])))
        faces.append(part.bm.faces.new((vs[j], vs[i], vs[5])))
    return part.paint(faces, slot)


def add_cable(part, pts, radius, slot, color, segs=8, alpha=1.0):
    """Watertight segmented cable tube with spherical joint knuckles so zero seams open."""
    for a, b in zip(pts, pts[1:]):
        part.rod(slot, a, b, radius, segs=segs, color=color, alpha=alpha)
    for p in pts[1:-1]:
        faces = part.ico(slot, radius * 1.04, subdiv=1, loc=p, color=color)
        if alpha != 1.0:
            part.paint(faces, slot, color, alpha=alpha)


def validate_and_export(root, out_path):
    """Check detail class triangle/vertex/draw budgets and export deterministic GLB."""
    bpy.context.view_layer.update()
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    tris = sum(common.tris(o) for o in meshes)
    verts = sum(len(o.data.vertices) for o in meshes)
    draws = sum(len(o.data.materials) for o in meshes)
    for o in meshes:
        for mat in o.data.materials:
            if mat.name in ("field", "ancient_light", "mantle_tool"):
                raise SystemExit(f"B6 violation: forbidden slot {mat.name} on {root.name}")
    print(f"BUILT {root.name:16s} tris={tris:4d}/{CAP_TRIS} verts={verts:4d}/{CAP_VERTS} draws={draws}/{CAP_DRAWS}")
    if tris > CAP_TRIS or verts > CAP_VERTS or draws > CAP_DRAWS:
        raise SystemExit(
            f"{root.name} exceeds detail budget: tris={tris} verts={verts} draws={draws}"
        )
    common.export(root, out_path)
    return {"name": root.name, "tris": tris, "verts": verts, "draws": draws, "path": out_path}


def build_clip(out_dir):
    common.reset()
    setup_slots()
    root = common.empty("AllyHuskClip")
    p = Part("ClipMesh")

    for s in (-1, 1):
        p.beam("hydraulic", (0.0, 0.0, s * 0.036), (0.0, 0.24, s * 0.068), 0.14, 0.034, color=COPPER)
        for sx in (-1, 1):
            p.beam("hydraulic", (sx * 0.064, 0.015, s * 0.030), (sx * 0.064, 0.25, s * 0.056),
                   0.022, 0.052, color=COPPER)
            for k in range(4):
                ty = 0.028 + k * 0.048
                tz = s * (0.016 + k * 0.007)
                tooth_tip_z = -s * 0.014
                tooth = [
                    (ty - 0.020, tz),
                    (ty + 0.020, tz),
                    (ty + (0.006 if s > 0 else -0.006), tooth_tip_z),
                ]
                if s < 0:
                    tooth.reverse()
                m = Matrix.Translation((sx * 0.058, 0.0, 0.0)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
                outline = [(-z, y) for y, z in tooth]
                p.prism("hydraulic", outline, 0.028, matrix=m, color=COPPER)

        for sx in (-1, 1):
            p.box("hydraulic", (0.024, 0.095, 0.095), loc=(sx * 0.078, 0.25, s * 0.038), color=COPPER)

        p.beam("hydraulic", (0.0, 0.24, s * 0.055), (0.0, 0.44, s * 0.115), 0.125, 0.044, color=COPPER)
        p.beam("hydraulic", (0.0, 0.34, s * 0.088), (0.0, 0.58, s * 0.168), 0.155, 0.076, color=CHARCOAL)
        for k in range(3):
            t = 0.39 + k * 0.068
            gz = s * (0.104 + k * 0.024)
            p.box("hydraulic", (0.168, 0.024, 0.090), loc=(0.0, t, gz), rot=(s * 0.30, 0.0, 0.0), color=CHARCOAL)
        p.box("hydraulic", (0.150, 0.045, 0.072), loc=(0.0, 0.59, s * 0.172), rot=(s * 0.30, 0.0, 0.0), color=OXBLOOD)

    p.cyl("hydraulic", 0.032, 0.032, 0.205, segs=8, loc=(0.0, 0.25, 0.0), rot=(0.0, math.pi / 2, 0.0), color=STEEL)
    for ox in (-0.036, 0.0, 0.036):
        p.ring("hydraulic", 0.044, 0.068, 0.022, segs=10, loc=(ox, 0.25, 0.0), rot=(0.0, math.pi / 2, 0.0), color=COPPER)

    p.cyl("hydraulic", 0.042, 0.034, 0.09, segs=8, loc=(0.0, 0.635, -0.178),
          rot=(math.pi / 2 + 0.28, 0.0, 0.0), color=COPPER)
    p.cyl("hydraulic", 0.034, 0.026, 0.06, segs=8, loc=(0.0, 0.695, -0.195),
          rot=(math.pi / 2 + 0.28, 0.0, 0.0), color=OXBLOOD)

    add_spark_bolt(p, [
        (-0.085, 0.02, -0.025), (-0.115, 0.055, 0.015), (-0.092, 0.095, 0.055), (-0.068, 0.13, 0.025)
    ], radius=0.014)
    add_spark_bolt(p, [
        (0.085, 0.015, 0.025), (0.120, 0.050, -0.012), (0.095, 0.095, -0.052), (0.068, 0.135, -0.020)
    ], radius=0.014)
    add_spark_bolt(p, [
        (-0.072, -0.015, 0.028), (-0.020, -0.032, -0.010), (0.024, -0.028, 0.022), (0.072, -0.015, -0.024)
    ], radius=0.015)
    add_spark_diamond(p, (-0.095, 0.015, 0.035), sx=0.034, sy=0.034, sz=0.078, rot=(0.2, 0.45, 0.0))
    add_spark_diamond(p, (0.095, 0.015, -0.030), sx=0.034, sy=0.034, sz=0.078, rot=(-0.2, -0.45, 0.0))
    p.ring("class_accent", 0.070, 0.086, 0.018, segs=10, loc=(0.0, 0.25, 0.0), rot=(0.0, math.pi / 2, 0.0))

    sharpen(p)
    p.to_object(parent=root)

    common.empty("socket_bite", (0.0, 0.0, 0.0), root)
    common.empty("socket_spark", (0.0, 0.01, 0.04), root)
    common.empty("socket_lead", (0.0, 0.72, -0.20), root)

    return validate_and_export(root, os.path.join(out_dir, "ally_husk_clip.glb"))


def build_tag(out_dir):
    common.reset()
    setup_slots()
    root = common.empty("AllyHuskTag")
    p = Part("TagMesh")

    p.box("paint", (0.56, 0.14, 0.11), loc=(0.0, 0.0, 0.045), color=COPPER, alpha=0.0)
    p.box("paint", (0.60, 0.11, 0.045), loc=(0.0, 0.0, 0.012), color=CHARCOAL, alpha=0.0)
    for sx in (-1, 1):
        p.cyl("paint", 0.028, 0.028, 0.16, segs=6, loc=(sx * 0.24, 0.0, 0.055),
              rot=(math.pi / 2, 0.0, 0.0), color=STEEL)
        p.paint(p.bm.faces[-8:], "paint", STEEL, alpha=0.0)

    tilt = math.radians(10.0)
    card_mtx = Matrix.Translation((0.0, 0.0, 0.09)) @ Matrix.Rotation(tilt, 4, "X")

    def card_box(size, loc, color, slot="paint"):
        m = card_mtx @ Matrix.Translation(loc) @ Matrix.Diagonal((*size, 1.0))
        r = bmesh.ops.create_cube(p.bm, size=1.0, matrix=m)
        return p.paint(p._faces(r["verts"]), slot, color if slot == "paint" else None,
                       alpha=0.0 if slot == "paint" else 1.0)

    card_outline = [
        (-0.26, 0.00),
        (0.26, 0.00),
        (0.26, 0.52),
        (0.12, 0.66),
        (-0.26, 0.66),
    ]
    prism_mtx = card_mtx @ Matrix.Rotation(math.pi / 2, 4, "X")
    faces = p.prism("paint", card_outline, 0.046, matrix=prism_mtx, color=CREAM)
    p.paint(faces, "paint", CREAM, alpha=0.0)

    header_outline = [
        (-0.266, 0.49),
        (0.266, 0.49),
        (0.266, 0.52),
        (0.12, 0.666),
        (-0.266, 0.666),
    ]
    hfaces = p.prism("paint", header_outline, 0.056, matrix=prism_mtx, color=OXBLOOD)
    p.paint(hfaces, "paint", OXBLOOD, alpha=0.0)
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])

    card_box((0.11, 0.054, 0.22), (-0.31, 0.0, 0.46), OXBLOOD)
    card_box((0.028, 0.062, 0.24), (-0.36, 0.0, 0.46), COPPER)

    card_box((0.026, 0.058, 0.49), (-0.262, 0.0, 0.245), COPPER)
    card_box((0.026, 0.058, 0.52), (0.262, 0.0, 0.260), COPPER)
    card_box((0.55, 0.060, 0.032), (0.0, 0.0, 0.015), COPPER)

    punch_rows = [
        (-0.16, 0.14, 0.075), (-0.02, 0.14, 0.055), (0.14, 0.14, 0.095),
        (-0.14, 0.23, 0.095), (0.05, 0.23, 0.065), (0.17, 0.23, 0.045),
        (-0.15, 0.56, 0.120), (0.04, 0.56, 0.080),
    ]
    for px, pz, pw in punch_rows:
        card_box((pw, 0.062, 0.042), (px, 0.0, pz), CHARCOAL)

    for tx in (-0.15, 0.0, 0.15):
        card_box((0.076, 0.068, 0.092), (tx, 0.0, 0.365), AMBER, slot="class_accent")
    card_box((0.050, 0.066, 0.085), (-0.31, 0.0, 0.46), AMBER, slot="class_accent")

    card_box((0.34, 0.078, 0.022), (0.0, 0.0, 0.075), STEEL)

    sharpen(p)
    p.to_object(parent=root)

    common.empty("socket_slot", (0.0, 0.0, 0.0), root)
    for i, tx in enumerate((-0.15, 0.0, 0.15)):
        pos = card_mtx @ Vector((tx, 0.0, 0.365))
        common.empty(f"socket_tick_{i}", tuple(pos), root)

    return validate_and_export(root, os.path.join(out_dir, "ally_husk_tag.glb"))


def build_mast(out_dir):
    common.reset()
    setup_slots()
    root = common.empty("AllyHuskMast")
    p = Part("MastMesh")

    p.box("hydraulic", (0.44, 0.38, 0.10), loc=(0.0, 0.0, 0.05), color=CHARCOAL)
    p.box("hydraulic", (0.34, 0.30, 0.12), loc=(0.0, 0.0, 0.14), color=OXBLOOD)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.bolt((sx * 0.17, sy * 0.14, 0.10), (0, 0, 1), r=0.028, h=0.032, segs=6, slot="hydraulic")
            p.paint(p.bm.faces[-8:], "hydraulic", STEEL)
        p.box("hydraulic", (0.07, 0.14, 0.09), loc=(sx * 0.23, 0.0, 0.085), color=COPPER)

    p0 = Vector((0.0, 0.0, 0.16))
    p_mid = Vector((0.0, -0.14, 0.72))
    p_top = Vector((0.0, -0.28, 1.24))
    p.rod("hydraulic", p0, p_mid, 0.068, segs=8, r2=0.058, color=COPPER)
    p.rod("hydraulic", p_mid, p_top, 0.054, segs=8, r2=0.044, color=COPPER)
    p.beam("hydraulic", (0.0, -0.16, 0.10), (0.0, -0.14, 0.66), 0.045, 0.045, color=CHARCOAL)

    mast_dir = (p_top - p0).normalized()
    mast_rot = Vector((0, 0, 1)).rotation_difference(mast_dir).to_euler()
    for t in (0.44, 0.78):
        c = p0.lerp(p_top, t)
        p.cyl("hydraulic", 0.145, 0.105, 0.065, segs=10, loc=tuple(c - mast_dir * 0.045), rot=mast_rot, color=BONE)
        p.cyl("hydraulic", 0.095, 0.095, 0.045, segs=10, loc=tuple(c), rot=mast_rot, color=CHARCOAL)
        p.cyl("hydraulic", 0.130, 0.085, 0.065, segs=10, loc=tuple(c + mast_dir * 0.045), rot=mast_rot, color=BONE)
        p.cyl("hydraulic", 0.082, 0.082, 0.036, segs=8, loc=tuple(c - mast_dir * 0.095), rot=mast_rot, color=COPPER)

    cross_c = p_top - mast_dir * 0.04
    p.box("hydraulic", (0.88, 0.09, 0.085), loc=tuple(cross_c), rot=mast_rot, color=CHARCOAL)
    p.box("hydraulic", (0.22, 0.125, 0.125), loc=tuple(cross_c), rot=mast_rot, color=OXBLOOD)
    p.cyl("class_accent", 0.072, 0.072, 0.048, segs=8, loc=tuple(p_top + mast_dir * 0.025), rot=mast_rot)

    horn_tips = []
    for sx in (-1, 1):
        base_pt = cross_c + Vector((sx * 0.34, 0.0, 0.02))
        elbow_pt = cross_c + Vector((sx * 0.24, -0.02, 0.16))
        tip_pt = cross_c + Vector((sx * 0.42, -0.06, 0.38))
        p.cyl("hydraulic", 0.065, 0.055, 0.055, segs=8, loc=tuple(base_pt), color=BONE)
        p.rod("hydraulic", base_pt, elbow_pt, 0.034, segs=6, r2=0.028, color=COPPER)
        p.rod("hydraulic", elbow_pt, tip_pt, 0.028, segs=6, r2=0.018, color=COPPER)
        p.ico("hydraulic", 0.034, subdiv=1, loc=tuple(elbow_pt), color=COPPER)
        p.ico("hydraulic", 0.030, subdiv=1, loc=tuple(tip_pt), color=COPPER)
        add_spark_diamond(p, tip_pt + Vector((0, 0, 0.02)), sx=0.042, sy=0.042, sz=0.088,
                          rot=(0.0, sx * 0.35, 0.0))
        horn_tips.append(tip_pt)

    arc_pts = [
        horn_tips[0],
        cross_c + Vector((-0.20, -0.04, 0.44)),
        cross_c + Vector((-0.04, -0.07, 0.36)),
        cross_c + Vector((0.08, -0.05, 0.48)),
        cross_c + Vector((0.23, -0.04, 0.41)),
        horn_tips[1],
    ]
    add_spark_bolt(p, arc_pts, radius=0.020)

    lead_pts = [
        p0.lerp(p_top, 0.72) + Vector((0.0, -0.08, 0.0)),
        Vector((0.06, -0.46, 1.06)),
        Vector((-0.05, -0.74, 0.96)),
        Vector((0.04, -1.00, 0.78)),
        Vector((0.00, -1.24, 0.68)),
    ]
    add_cable(p, lead_pts, 0.038, "hydraulic", CHARCOAL, segs=8)
    for a, b in ((lead_pts[1], lead_pts[2]), (lead_pts[2], lead_pts[3])):
        mid = a.lerp(b, 0.5)
        d = (b - a).normalized()
        p.rod("hydraulic", mid - d * 0.045, mid + d * 0.045, 0.046, segs=8, color=OXBLOOD)

    cuff = lead_pts[-1]
    p.rod("hydraulic", lead_pts[-2].lerp(cuff, 0.75), cuff + Vector((0.0, -0.04, -0.02)),
          0.048, segs=8, r2=0.040, color=COPPER)
    fray_strands = [
        [cuff, cuff + Vector((-0.11, -0.15, 0.08)), cuff + Vector((-0.18, -0.27, 0.14))],
        [cuff, cuff + Vector((0.02, -0.18, -0.05)), cuff + Vector((0.05, -0.32, -0.11))],
        [cuff, cuff + Vector((0.12, -0.14, 0.05)), cuff + Vector((0.20, -0.25, 0.02))],
    ]
    for strand in fray_strands:
        add_cable(p, strand, 0.017, "hydraulic", COPPER, segs=6)
        add_spark_diamond(p, strand[-1], sx=0.038, sy=0.038, sz=0.075, rot=(0.6, 0.2, 0.0))

    add_spark_bolt(p, [
        fray_strands[0][-1],
        cuff + Vector((-0.02, -0.28, 0.07)),
        fray_strands[2][-1],
    ], radius=0.013)

    sharpen(p)
    p.to_object(parent=root)

    common.empty("socket_base", (0.0, 0.0, 0.0), root)
    common.empty("socket_arc_left", tuple(horn_tips[0]), root)
    common.empty("socket_arc_right", tuple(horn_tips[1]), root)
    common.empty("socket_lead_tip", tuple(cuff + Vector((0.0, -0.28, 0.0))), root)
    feed = p0.lerp(p_top, 0.44)
    common.empty("socket_clip_feed_l", (feed.x - 0.13, feed.y, feed.z), root)
    common.empty("socket_clip_feed_r", (feed.x + 0.13, feed.y, feed.z), root)

    return validate_and_export(root, os.path.join(out_dir, "ally_husk_mast.glb"))


def build_lead(out_dir):
    common.reset()
    setup_slots()
    root = common.empty("AllyHuskLead")
    p = Part("LeadMesh")

    steps = 8
    pts = []
    for k in range(steps + 1):
        t = k / steps
        arch = 0.13 * math.sin(math.pi * t)
        pts.append(Vector((0.0, t, arch)))
    add_cable(p, pts, 0.028, "hydraulic", CHARCOAL, segs=8)

    for a, b in ((pts[0], pts[1]), (pts[-1], pts[-2])):
        d = (b - a).normalized()
        p.rod("hydraulic", a, a + d * 0.065, 0.038, segs=8, color=COPPER)
        p.rod("hydraulic", a + d * 0.065, a + d * 0.125, 0.036, segs=8, color=OXBLOOD)

    for t in (0.33, 0.67):
        idx = int(round(t * steps))
        c = pts[idx]
        d = (pts[min(idx + 1, steps)] - pts[max(idx - 1, 0)]).normalized()
        p.rod("hydraulic", c - d * 0.032, c + d * 0.032, 0.036, segs=8, color=COPPER)
        p.ico("class_accent", 0.044, subdiv=1, loc=tuple(c))

    sharpen(p)
    p.to_object(parent=root)

    common.empty("socket_start", (0.0, 0.0, 0.0), root)
    common.empty("socket_end", (0.0, 1.0, 0.0), root)

    return validate_and_export(root, os.path.join(out_dir, "ally_husk_lead.glb"))


def build_wreck(out_dir):
    """Replaces raw BoxMesh + SphereMesh in ally_husk_look.build_wreck_marker():
    slumped canted oxide Fleet housing with popped access hatch, copper jumper terminal stubs,
    and glowing warm AMBER #E5A044 salvage spark bead (strictly B6 compliant, zero HAZARD)."""
    common.reset()
    setup_slots()
    root = common.empty("AllyHuskWreck")
    p = Part("WreckMesh")

    p.box("hydraulic", (1.06, 1.18, 0.10), loc=(0.0, 0.0, 0.05), color=CHARCOAL)
    for sx in (-0.48, 0.48):
        p.box("hydraulic", (0.14, 1.24, 0.12), loc=(sx, 0.0, 0.06), color=STEEL)

    hull_rot = (math.radians(12.0), math.radians(-14.0), math.radians(18.0))
    p.box("hydraulic", (0.94, 1.06, 0.48), loc=(0.0, 0.0, 0.34), rot=hull_rot, color=OXBLOOD)
    p.box("hydraulic", (0.78, 0.90, 0.12), loc=(0.02, 0.0, 0.56), rot=hull_rot, color=CHARCOAL)

    p.box("hydraulic", (0.56, 0.52, 0.07), loc=(-0.14, 0.04, 0.68),
          rot=(math.radians(10.0), math.radians(-38.0), math.radians(18.0)), color=STEEL)
    for sx in (-0.12, 0.14):
        p.cyl("hydraulic", 0.055, 0.048, 0.24, segs=8, loc=(sx, -0.02, 0.66), color=COPPER)
        p.cyl("hydraulic", 0.032, 0.032, 0.08, segs=6, loc=(sx, -0.02, 0.80), color=BONE)

    add_spark_bolt(p, [
        (-0.12, -0.02, 0.80), (-0.03, 0.04, 0.88), (0.05, -0.04, 0.84), (0.14, -0.02, 0.80)
    ], radius=0.018)
    add_spark_diamond(p, (0.01, 0.0, 0.92), sx=0.075, sy=0.075, sz=0.14)

    sharpen(p)
    p.to_object(parent=root)
    common.empty("socket_spark", (0.01, 0.0, 0.92), root)
    return validate_and_export(root, os.path.join(out_dir, "ally_husk_wreck.glb"))


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build W47-TALLY-B-3D Ghost Shift ally-husk overlay GLBs")
    parser.add_argument("--out-dir", default=OUT_DIR, help="Output directory for exported GLBs")
    return parser.parse_args(argv)


def main():
    opts = parse_args()
    os.makedirs(opts.out_dir, exist_ok=True)
    built = [
        build_clip(opts.out_dir),
        build_tag(opts.out_dir),
        build_mast(opts.out_dir),
        build_lead(opts.out_dir),
        build_wreck(opts.out_dir),
    ]
    total_tris = sum(b["tris"] for b in built)
    print(f"ALLY_HUSK_OVERLAY PASS: {len(built)} GLBs built, combined tris={total_tris}")


if __name__ == "__main__":
    main()
