# PD-SABLE (wave 13): Sable's Hoberman mecha on shell_base.hoberman(). The lattice, gimbal,
# cockpit and weapon ring come from PD-0's helper; this recipe adds her machinery:
#   - the coil mast on a gap bracket at 11 o'clock from behind (rest pose: Hub.14, the upper hub
#     at 10.8 o'clock), a copper stepped coil standing 0.20 m past the lattice; its mint tip is the
#     `CoilMast` node, the mast's only class_accent surface (class V's Replace.CoilMast swaps it);
#   - the winch spool on a gap bracket at 3 o'clock (rest pose: Hub.26), a 0.12 m round bump,
#     with the ratchet pawl, the stake hatch under it and `RopeExit` at the rope mouth; all of it
#     is one mesh, `SpoolKit`, under Pod so the carrier bank tilts it (it is not in the Pod mesh);
#   - the four-wrench rack on the seat back, the rear tell: one mesh, `WrenchRack`, on one
#     class_accent surface. Its lit count is a per-instance shader parameter (`lit_count`) read
#     by the material code, never a material_override. COLOR.r carries each piece's index in
#     linear units: 0.0 the rail, 0.25, 0.5, 0.75 and 1.0 the wrenches left to right from behind,
#     so a shader lights wrench k when lit_count >= k;
#   - the twin arc emitter, copper coils at about 11 and 1 o'clock on the weapon ring's front
#     arc, parallel and pointing forward (+Y), on the ring's copper surface with the collar studs.
# Seat bone, lattice petrol (ROSTER-LOOK 0.2, 6). Controls per PILOT-CLIPS 5: twin yokes
# (Control.Grip.L/R, Control.Trigger), GaugeLever (slot 2) and SpoolBrake (slot 3) in the bank,
# the copper lap bar, two pedals.
# Concept (approved set, docs/decisions.tsv w13-look rows 2026-10-10):
#   artifacts/local/alpha/push/w13/concepts/codex/sable/hero.png, chase.png, sheet.png
#   artifacts/local/alpha/push/w13/concepts/codex/base/base-hero.png, mechanism.png
# The Felt Rig variant (CUSTOMIZE section 8, shell_sable_felt) swaps structure only: felt pads
# (rubber) on every scissor pivot instead of copper pins, and rounder eight-sided felt tread caps;
# same lattice and the machinery stays where it is.
# One X-pair per hub-to-hub link (LATTICE_PAIRS): ROSTER-LOOK section 3 rule 1 names it the first
# cut when the lattice hides the pilot, and hero.png draws single wide bars round open diamonds.
# Two pairs hid about 41 percent of the head box at the class I mid camera (PD-SABLE fix round).
# Heft layers c2 to c5 come from world_one/shell_sable_plates.py.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/shell_sable.py -- [--out <file.glb>] [--variant felt]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

# hero_assets_test holds every world-one pilot shell to 3,000..6,500 tris without the pilot;
# the shell class caps the variant at 11,000 (assets/asset_budgets.json).
BASE_BAND = (3000, 6500)
VARIANT_BAND = (3000, 11000)
LATTICE_OUT = sb.LATTICE_OUTER
LATTICE_PAIRS = 1

HUBS, _, GAPS = sb.lattice_layout()
MAST_HUB = 14            # (-0.607, 0, 0.795): 10.8 o'clock from behind, the upper hub at 11
SPOOL_HUB = 26           # (0.982, 0, -0.188): 3.4 o'clock, the side hub at 3
MAST_DIR = HUBS[MAST_HUB].normalized()
SPOOL_DIR = HUBS[SPOOL_HUB].normalized()

# Mast: copper steps along MAST_DIR (radius from centre, bar radius), tip to 0.20 m past the lattice.
MAST_STEPS = [(0.985, 1.05, 0.062), (1.05, 1.10, 0.050), (1.10, 1.14, 0.038)]
MAST_TIP = (1.14, LATTICE_OUT + 0.20, 0.028)
MAST_ARM_FROM = Vector((-0.20, -0.14, -0.08))
# Spool: drum on a fore-aft axle, centred on SPOOL_DIR at radius 1.0; flange radius 0.095, so it
# reaches 1.095, 0.12 m past the lattice, and its top (Z -0.093) clears the ring collar (-0.07).
SPOOL_C = SPOOL_DIR * 1.0
SPOOL_R = 0.095
SPOOL_HALF = 0.075
SPOOL_ARM_FROM = Vector((0.30, -0.02, -0.26))
ROPE_EXIT = SPOOL_C + Vector((-0.03, SPOOL_HALF + 0.06, 0.0))
# Rack on the seat back (back face Y -0.24 with the DecalPlate), under the sight cone.
RACK_Y = -0.258
RACK_TOP = -0.062
RACK_X = (-0.0825, -0.0275, 0.0275, 0.0825)
# Twin arc emitter: angle from +Y on the ring, coil radius, length.
EMITTER_ANGLE = math.radians(24)
EMITTER = (0.044, 0.17)


def linear_to_srgb(v):
    return 0.0 if v <= 0 else (1.055 * v ** (1 / 2.4) - 0.055 if v > 0.0031308 else v * 12.92)


def merge(target, part):
    """Appends a Part's triangles to an existing mesh object (same world frame, identity at
    the origin), remapping its slots onto the target's materials, so the Pod stays one mesh."""
    tmp = part.to_object((0, 0, 0), None)
    names = [m.name for m in target.data.materials]
    remap = []
    for m in tmp.data.materials:
        if m.name not in names:
            target.data.materials.append(m)
            names.append(m.name)
        remap.append(names.index(m.name))
    bm = bmesh.new()
    bm.from_mesh(target.data)
    before = len(bm.faces)
    bm.from_mesh(tmp.data)
    bm.faces.ensure_lookup_table()
    for f in bm.faces[before:]:
        f.material_index = remap[f.material_index]
    bm.to_mesh(target.data)
    bm.free()
    data = tmp.data
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(data)


def mast_kit(p):
    """Coil mast steps (copper) and its gap bracket (rubber), on the Pod."""
    for r0, r1, rad in MAST_STEPS:
        p.rod("copper", MAST_DIR * r0, MAST_DIR * r1, rad, 6)
    p.rod("rubber", MAST_DIR * 0.93, MAST_DIR * 0.99, 0.034, 6)
    p.beam("rubber", MAST_ARM_FROM, MAST_DIR * 0.95, 0.04)


def coil_tip(name="CoilMast", tip=MAST_TIP):
    """The mint tip, the mast's working device and its only class_accent surface."""
    t = Part(name)
    r0, r1, rad = tip
    t.rod("class_accent", MAST_DIR * r0, MAST_DIR * r1, rad, 6, r2=0.008)
    return t


def spool_kit(p):
    """Winch spool on a fore-aft axle at 3 o'clock: copper flanges, bone rope drum, charcoal axle,
    bracket, stake hatch and fairlead (all on the paint surface in charcoal vertex colour, alpha 0 so
    no equipped paint takes them, and the kit spends two draws), a copper ratchet pawl and the rope mouth."""
    c = SPOOL_C
    for side in (-1, 1):
        p.cyl("copper", SPOOL_R, SPOOL_R, 0.02, 8, loc=c + Vector((0, side * SPOOL_HALF, 0)), rot=(math.pi / 2, 0, 0))
    p.cyl("paint", 0.072, 0.072, 2 * SPOOL_HALF - 0.02, 8, loc=c, rot=(math.pi / 2, 0, 0), color="bone", caps=False)
    p.rod("paint", c + Vector((0, -SPOOL_HALF - 0.03, 0)), c + Vector((0, SPOOL_HALF + 0.03, 0)), 0.02, 4, color="charcoal", alpha=0)
    p.beam("paint", SPOOL_ARM_FROM, c + Vector((-0.04, 0, 0)), 0.04, color="charcoal", alpha=0)
    # Stake hatch under the spool (the stakes ride inside it).
    p.box("paint", (0.10, 0.12, 0.05), loc=c + Vector((-0.04, 0.0, -SPOOL_R - 0.035)), color="charcoal", alpha=0)
    # Ratchet pawl on the rear flange (it clacks when Bank Shot locks the line).
    p.box("copper", (0.02, 0.012, 0.06), loc=c + Vector((0.0, -SPOOL_HALF - 0.016, SPOOL_R - 0.01)), rot=(0, 0.5, 0))
    # Fairlead: the rope mouth at the front, where RopeExit sits.
    p.beam("paint", c + Vector((-0.03, SPOOL_HALF, 0.0)), ROPE_EXIT, 0.035, color="charcoal", alpha=0)


def wrench_rack():
    """Four wrenches on a rail, one class_accent surface; COLOR.r encodes the piece index."""
    r = Part("WrenchRack")
    rail = (linear_to_srgb(0.0),) * 3
    r.box("class_accent", (0.22, 0.014, 0.018), loc=(0, RACK_Y + 0.004, RACK_TOP), color=rail)
    for k, x in enumerate(RACK_X):
        idx = linear_to_srgb((k + 1) / 4)
        col = (idx, idx, idx)
        r.box("class_accent", (0.020, 0.012, 0.13), loc=(x, RACK_Y, RACK_TOP - 0.08), color=col)
        r.box("class_accent", (0.046, 0.012, 0.03), loc=(x, RACK_Y, RACK_TOP - 0.02), color=col)
    return r


def sable_ring():
    """PD-0's ring (bone band, charcoal clamps, dark collar) with the neutral mount block
    replaced by the twin arc emitter; collar studs and emitter coils share the copper surface."""
    r = Part("WeaponRing")
    b_in, b_out, b_h, b_z = sb.RING_BAND
    r.ring("paint", b_in, b_out, b_h, sb.RING_SEGMENTS, loc=(0, 0, b_z), color="bone")
    for k in range(10):
        a = (k + 0.5) * math.tau / 10
        r.box("rubber", (0.06, b_out - b_in + 0.012, b_h + 0.012), loc=((b_in + b_out) / 2 * math.cos(a),
              (b_in + b_out) / 2 * math.sin(a), b_z), rot=(0, 0, a + math.pi / 2))
    c_in, c_out, c_h, c_z = sb.RING_COLLAR
    r.ring("rubber", c_in, c_out, c_h, sb.RING_SEGMENTS, loc=(0, 0, c_z))
    for k in range(12):
        a = k * math.tau / 12 + 0.13
        n = Vector((math.cos(a), math.sin(a), 0))
        sb._disc(r, n * (c_out + 0.002) + Vector((0, 0, c_z)), n, 0.012, 6, "copper")
    rad, length = EMITTER
    for side in (-1, 1):
        a = side * EMITTER_ANGLE
        base = Vector((math.sin(a), math.cos(a), 0)) * (b_out + rad + 0.004)
        r.box("rubber", (0.07, 0.06, 0.05), loc=base - Vector((math.sin(a), math.cos(a), 0)) * 0.03)
        r.rod("copper", base - Vector((0, 0.04, 0)), base + Vector((0, length - 0.04, 0)), rad, 6)
        r.rod("rubber", base + Vector((0, length - 0.04, 0)), base + Vector((0, length, 0)), rad * 0.7, 6)
    sb._sharpen(r)
    return r


def emitter_tips():
    out = []
    rad, length = EMITTER
    for side, tag in ((-1, "L"), (1, "R")):
        a = side * EMITTER_ANGLE
        base = Vector((math.sin(a), math.cos(a), 0)) * (sb.RING_BAND[1] + rad + 0.004)
        out.append(("Emitter." + tag, base + Vector((0, length, 0))))
    return out


def pilot():
    """The in-shell placeholder fox (hidden by fit_pilot_into under the animated rig)."""
    f = Part("Pilot")
    f.uv("pilot", 0.15, 10, 6, loc=(0, 0.0, -0.12), scale=(1.0, 0.8, 1.1), color="oxide")
    f.uv("pilot", 0.13, 12, 8, loc=(0, 0.02, 0.17), scale=(1.05, 0.9, 0.95), color="oxide")
    f.uv("pilot", 0.06, 8, 6, loc=(0, 0.13, 0.13), scale=(0.8, 1.3, 0.6), color="bone")
    f.uv("pilot", 0.09, 10, 6, loc=(0, 0.0, 0.27), scale=(1.15, 1.1, 0.45), color="petrol")
    for side in (-1, 1):
        sb.ear(f, (side * 0.08, -0.01, 0.27), 0.13, 0.09, side * -0.26, "oxide", inner="bone", tip="charcoal")
        sb.eye(f, (side * 0.05, 0.12, 0.19), 0.022)
    # Smooth shading shares vertices across the round parts, which keeps the shell inside the
    # class's 11,600-vertex cap (the hidden placeholder still counts there).
    sb._sharpen(f)
    return f


def felt_pads(core):
    """Felt Rig: the copper pivot pins (small discs just past the lattice face) become rubber
    felt pads. Hub bodies stay copper."""
    names = [m.name for m in core.data.materials]
    copper, rubber = names.index("copper"), names.index("rubber")
    moved = 0
    for poly in core.data.polygons:
        if poly.material_index != copper or poly.area > 0.0012:
            continue
        radii = [core.data.vertices[i].co.length for i in poly.vertices]
        if min(radii) >= sb.LATTICE_OUTER and max(radii) <= sb.LATTICE_OUTER + 0.007:
            poly.material_index = rubber
            moved += 1
    return moved


def build(variant=""):
    felt = variant == "felt"
    name = "SableFelt" if felt else "Sable"
    shell = sb.hoberman(name, enamel="petrol", seat="bone", pairs=LATTICE_PAIRS,
                        bank=(("GaugeLever", "lever"), ("SpoolBrake", "lever")), pilot=pilot(),
                        hub_sides=6, cap_sides=8 if felt else 6)
    pod, ring = shell["pod"], shell["ring"]
    if felt:
        print("FELT_PADS %d pivot triangles moved from copper to rubber" % felt_pads(shell["core"]))
    kit = Part("SableKit")
    mast_kit(kit)
    sb._sharpen(kit)
    merge(pod, kit)
    # The spool stands 0.12 m past the lattice at 3 o'clock, so it is its own mesh, SpoolKit (copper and
    # paint, its dark parts in charcoal vertex colour: two draws), which hero_assets banks with the carrier instead of leaving
    # it level and past the ball on a wall.
    spool = Part("SpoolKit")
    spool_kit(spool)
    sb._sharpen(spool)
    spool.to_object((0, 0, 0), pod)
    coil_tip().to_object(MAST_DIR * MAST_STEPS[0][0], pod)
    common.empty("RopeExit", ROPE_EXIT, pod)
    wrench_rack().to_object((0, RACK_Y, RACK_TOP), pod)
    # Swap the ring mesh for Sable's; the WeaponMount empty and the node stay.
    new_ring = sable_ring().to_object((0, 0, 0), None)
    old = ring.data
    ring.data = new_ring.data
    bpy.data.objects.remove(new_ring)
    bpy.data.meshes.remove(old)
    ring.data.name = "WeaponRing"
    for tag, at in emitter_tips():
        common.empty(tag, at, ring)
    return name, shell


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    variant = argv[argv.index("--variant") + 1] if "--variant" in argv else ""
    common.reset()
    name, shell = build(variant)
    tris = common.tri_total(shell["root"], skip=(shell["pilot"].name,))
    print("SABLE %s tris=%d core=%d pilot=%d" % (name, tris, common.tris(shell["core"]), common.tris(shell["pilot"])))
    fname = "shell_sable_felt.glb" if variant == "felt" else "shell_sable.glb"
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", fname)
    sb.finish(name, shell["root"], shell["core"], shell["pilot"],
              shell_band=VARIANT_BAND if variant else BASE_BAND, pod_obj=shell["pod"], out=out)


if __name__ == "__main__":
    main()
