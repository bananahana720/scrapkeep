import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import common
import shell_base as sb
from common import Part

BASE_BAND = (3000, 6500)
VARIANT_BAND = (3000, 11000)
LATTICE_OUT = sb.LATTICE_OUTER
LATTICE_PAIRS = 1
HUB_SIDES = 3
CAP_SIDES = 3
FELT_CAP_SIDES = 8
RING_SEGMENTS = 32

HUBS, _, GAPS = sb.lattice_layout()
MAST_HUB = 14
SPOOL_HUB = 26
SPOOL_DIR = HUBS[SPOOL_HUB].normalized()

MAST_X = 0.48
MAST_SIDES = 6
MAST_PROFILE = [(0.80, 0.080), (0.905, 0.095), (0.905, 0.112), (0.950, 0.112), (0.958, 0.070),
                (0.978, 0.100), (0.998, 0.070), (1.018, 0.100), (1.038, 0.070), (1.058, 0.100),
                (1.078, 0.070), (1.086, 0.092), (1.120, 0.092), (1.135, 0.062)]
CHARCOAL = ("paint", "charcoal", 0.0)
BONE = ("paint", "bone", 1.0)
COPPER = ("copper", None, 1.0)
RUBBER = ("rubber", None, 1.0)
MAST_BANDS = [CHARCOAL, BONE, BONE, BONE] + [COPPER] * 6 + [BONE, BONE, BONE]
MAST_CAPS = (CHARCOAL, BONE)
MAST_TIP = (1.13, 1.18, 0.05, 0.012)
MAST_DIR = Vector((-MAST_X, 0.0, MAST_TIP[1])).normalized()

SPOOL_C = SPOOL_DIR * 1.0
SPOOL_R = 0.095
SPOOL_HALF = 0.075
SPOOL_ARM_FROM = Vector((0.30, -0.02, -0.26))
ROPE_EXIT = SPOOL_C + Vector((-0.03, SPOOL_HALF + 0.06, 0.0))
RACK_Y = -0.258
RACK_TOP = -0.062
RACK_X = (-0.0825, -0.0275, 0.0275, 0.0825)

CROWN_Z = 1.40
HEAD_SIDES = 8
HEAD_PROFILE = [(0.715, 0.090), (0.690, 0.125), (0.650, 0.125), (0.650, 0.090), (0.620, 0.090),
                (0.620, 0.170), (0.500, 0.170), (0.500, 0.184), (0.450, 0.184), (0.450, 0.170),
                (0.390, 0.150), (0.390, 0.128), (0.355, 0.128)]
HEAD_BANDS = [BONE, BONE, BONE, COPPER, COPPER, COPPER, RUBBER, RUBBER, RUBBER, COPPER, BONE, BONE]
HEAD_CAPS = (BONE, BONE)
PRONG_X = (0.40, 0.19)
PRONG_Z = (0.085, 0.075)
PRONG_HALF = ((0.032, 0.060), (0.022, 0.045))
ARM = [(1.050, 0.02), (1.040, 0.33), (0.945, 0.62), (0.840, 0.90), (0.770, 1.15), (0.580, 1.38)]
ARM_R = 0.06
ARM_SIDES = 8
ARM_COLLAR = (2, 0.5, 0.09, 0.07)
ARM_SHOE = ((0.09, 0.11, 0.13), 1.055, 0.01)
CABLE = [(1.065, -0.06, 0.03), (1.15, -0.08, 0.40), (1.10, -0.09, 0.80), (0.95, -0.09, 1.15),
         (0.78, -0.07, 1.38), (0.66, -0.04, 1.42)]
CABLE_R = 0.03
CABLE_SIDES = 5
CROWN_REACH = 1.70


def linear_to_srgb(v):
    return 0.0 if v <= 0 else (1.055 * v ** (1 / 2.4) - 0.055 if v > 0.0031308 else v * 12.92)


def lathe(part, rings, bands, caps, sides, place):
    """One closed lathe: rings [(t, radius)], place(t, angle, radius) -> Vector. Each band between
    rings k and k+1 takes bands[k] (slot, colour, alpha); caps are the first and last ring's faces."""
    bm = part.bm
    rows = [[bm.verts.new(place(t, (j + 0.5) * math.tau / sides, rad)) for j in range(sides)] for t, rad in rings]
    first = bm.faces.new(list(reversed(rows[0])))
    last = bm.faces.new(rows[-1])
    sides_f = [[bm.faces.new((a[j], a[(j + 1) % sides], b[(j + 1) % sides], b[j])) for j in range(sides)]
               for a, b in zip(rows, rows[1:])]
    bmesh.ops.recalc_face_normals(bm, faces=[first, last] + [f for band in sides_f for f in band])
    for face, (slot, color, alpha) in ((first, caps[0]), (last, caps[1])):
        part.paint([face], slot, color, alpha)
    for band, (slot, color, alpha) in zip(sides_f, bands):
        part.paint(band, slot, color, alpha)


def tube(part, pts, radius, sides, style):
    """A closed tube through pts, its rings square to the path (each ring halves the turn there)."""
    pts = [Vector(p) for p in pts]
    bm = part.bm
    rows = []
    up = Vector((0.0, 1.0, 0.0))
    for k, c in enumerate(pts):
        a = pts[max(k - 1, 0)]
        b = pts[min(k + 1, len(pts) - 1)]
        t = (b - a).normalized()
        e1 = up - t * up.dot(t)
        e1.normalize()
        e2 = t.cross(e1)
        rows.append([bm.verts.new(c + radius * (math.cos(j * math.tau / sides) * e1 + math.sin(j * math.tau / sides) * e2))
                     for j in range(sides)])
    faces = [bm.faces.new(list(reversed(rows[0]))), bm.faces.new(rows[-1])]
    for a, b in zip(rows, rows[1:]):
        faces += [bm.faces.new((a[j], a[(j + 1) % sides], b[(j + 1) % sides], b[j])) for j in range(sides)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    slot, color, alpha = style
    part.paint(faces, slot, color, alpha)


def mast(part, side):
    """A coil mast on X side * MAST_X, Y 0; the right one (side 1) ends in a copper tip."""
    x = side * MAST_X
    lathe(part, MAST_PROFILE, MAST_BANDS, MAST_CAPS, MAST_SIDES,
          lambda z, a, r: Vector((x + r * math.cos(a), r * math.sin(a), z)))
    if side > 0:
        z0, z1, r0, r1 = MAST_TIP
        part.rod("copper", (x, 0, z0), (x, 0, z1), r0, 6, r2=r1)


def coil_tip(name="CoilMast"):
    """The left mast's mint tip, its working device and only class_accent surface."""
    t = Part(name)
    z0, z1, r0, r1 = MAST_TIP
    t.rod("class_accent", (-MAST_X, 0, z0), (-MAST_X, 0, z1), r0, 6, r2=r1)
    return t


def spool_kit(p):
    """Winch spool on a fore-aft axle at 3 o'clock: copper flanges, bone rope drum, charcoal axle,
    bracket, stake hatch and fairlead (all on the paint surface in charcoal vertex colour, alpha 0 so
    no equipped paint takes them, and the kit spends two draws), a copper ratchet pawl and the rope mouth."""
    c = SPOOL_C
    for side in (-1, 1):
        p.cyl("copper", SPOOL_R, SPOOL_R, 0.02, 8, loc=c + Vector((0, side * SPOOL_HALF, 0)), rot=(math.pi / 2, 0, 0))
    p.cyl("paint", 0.072, 0.072, 2 * SPOOL_HALF - 0.02, 8, loc=c, rot=(math.pi / 2, 0, 0), color="bone")
    p.rod("paint", c + Vector((0, -SPOOL_HALF - 0.03, 0)), c + Vector((0, SPOOL_HALF + 0.03, 0)), 0.02, 4, color="charcoal", alpha=0)
    p.beam("paint", SPOOL_ARM_FROM, c + Vector((-0.04, 0, 0)), 0.04, color="charcoal", alpha=0)
    p.box("paint", (0.10, 0.12, 0.05), loc=c + Vector((-0.04, 0.0, -SPOOL_R - 0.035)), color="charcoal", alpha=0)
    p.box("copper", (0.02, 0.012, 0.06), loc=c + Vector((0.0, -SPOOL_HALF - 0.016, SPOOL_R - 0.01)), rot=(0, 0.5, 0))
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


def prong(r, side, up):
    """A closed tapered copper prong (eight corners): root buried in the front collar, the point
    leaning toward the head axis at the gap."""
    bm = r.bm
    corners = []
    for x, dz, (hz, hy) in ((PRONG_X[0], PRONG_Z[0], PRONG_HALF[0]), (PRONG_X[1], PRONG_Z[1], PRONG_HALF[1])):
        zc = CROWN_Z + up * dz
        corners.append([bm.verts.new((side * x, sy * hy, zc + sz * hz)) for sy, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    a, b = corners
    faces = [bm.faces.new(list(reversed(a))), bm.faces.new(b)]
    faces += [bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j])) for j in range(4)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    r.paint(faces, "copper")


def crown_side(r, side):
    """One side of the crown: shoe, yoke arm and collar, heavy cable, emitter head and its fork."""
    size, rad, z = ARM_SHOE
    r.box("rubber", size, loc=(side * rad, 0, z))
    tube(r, [(side * x, 0.0, z) for x, z in ARM], ARM_R, ARM_SIDES, COPPER)
    k, t, cr, length = ARM_COLLAR
    a, b = Vector((side * ARM[k][0], 0, ARM[k][1])), Vector((side * ARM[k + 1][0], 0, ARM[k + 1][1]))
    mid = a.lerp(b, t)
    d = (b - a).normalized() * (length / 2)
    r.rod("paint", mid - d, mid + d, cr, 6, color="bone")
    tube(r, [(side * x, y, z) for x, y, z in CABLE], CABLE_R, CABLE_SIDES, RUBBER)
    lathe(r, HEAD_PROFILE, HEAD_BANDS, HEAD_CAPS, HEAD_SIDES,
          lambda x, a, rad: Vector((side * x, rad * math.cos(a), CROWN_Z + rad * math.sin(a))))
    for up in (-1, 1):
        prong(r, side, up)


def sable_ring():
    """PD-0's ring (bone band, charcoal clamps, dark collar with closed copper studs) at
    RING_SEGMENTS, with the neutral mount block replaced by the crown arc emitter. The crown shares
    the ring's three surfaces."""
    r = Part("WeaponRing")
    b_in, b_out, b_h, b_z = sb.RING_BAND
    r.ring("paint", b_in, b_out, b_h, RING_SEGMENTS, loc=(0, 0, b_z), color="bone")
    for k in range(10):
        a = (k + 0.5) * math.tau / 10
        r.box("rubber", (0.06, b_out - b_in + 0.012, b_h + 0.012), loc=((b_in + b_out) / 2 * math.cos(a),
              (b_in + b_out) / 2 * math.sin(a), b_z), rot=(0, 0, a + math.pi / 2))
    c_in, c_out, c_h, c_z = sb.RING_COLLAR
    r.ring("rubber", c_in, c_out, c_h, RING_SEGMENTS, loc=(0, 0, c_z))
    for k in range(12):
        a = k * math.tau / 12 + 0.13
        n = Vector((math.cos(a), math.sin(a), 0))
        sb._stud(r, n * (c_out + 0.002) + Vector((0, 0, c_z)), n, 0.012, 0.006, "copper")
    for side in (-1, 1):
        crown_side(r, side)
    sb._sharpen(r)
    return r


def emitter_tips():
    return [("Emitter." + tag, Vector((side * PRONG_X[1], 0.0, CROWN_Z))) for side, tag in ((-1, "L"), (1, "R"))]


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
    sb._sharpen(f)
    return f


def felt_pads(core):
    """Felt Rig: the copper pivot pins (shell_base._stud heads just past the lattice face, closed to
    a point PIN_DEPTH under it) become rubber felt pads, head and buried sides alike, so each pin
    stays one closed island. Hub bodies (larger faces, or reaching in to the drum's inner end) stay copper."""
    names = [m.name for m in core.data.materials]
    copper, rubber = names.index("copper"), names.index("rubber")
    moved = 0
    for poly in core.data.polygons:
        if poly.material_index != copper or poly.area > 0.002:
            continue
        radii = [core.data.vertices[i].co.length for i in poly.vertices]
        if min(radii) >= sb.LATTICE_OUTER - sb.PIN_DEPTH - 0.002 and max(radii) <= sb.LATTICE_OUTER + 0.007:
            poly.material_index = rubber
            moved += 1
    return moved


def crown_report(ring, kit, tip):
    """Prints the crown's reach and its clearance from the masts in (horizontal radius, height): the
    ring yaws about Z against the banked masts, so a ring vertex can only meet a mast vertex at the
    same height and horizontal radius. Returns False when the reach or the clearance is out."""
    def rz(o):
        mw = o.matrix_world
        return [((mw @ v.co).xy.length, (mw @ v.co).z, (mw @ v.co).length) for v in o.data.vertices]
    ring_pts = rz(ring)
    mast_pts = [p for p in rz(kit) + rz(tip) if p[1] > 0.5]
    reach = max(p[2] for p in ring_pts)
    gap = min(math.hypot(a[0] - b[0], a[1] - b[1]) for a in ring_pts for b in mast_pts if a[1] > 0.3)
    low = min(p[1] for p in ring_pts)
    ok = reach <= CROWN_REACH and gap >= 0.03
    print("CROWN reach=%.4f cap=%.2f mast_gap=%.4f ring_low_z=%.4f %s" % (reach, CROWN_REACH, gap, low, "ok" if ok else "OUT"))
    return ok


def build(variant=""):
    felt = variant == "felt"
    name = "SableFelt" if felt else "Sable"
    shell = sb.hoberman(name, enamel="petrol", seat="bone", pairs=LATTICE_PAIRS,
                        bank=(("GaugeLever", "lever"), ("SpoolBrake", "lever")), pilot=pilot(),
                        hub_sides=HUB_SIDES, cap_sides=FELT_CAP_SIDES if felt else CAP_SIDES)
    pod, ring = shell["pod"], shell["ring"]
    if felt:
        print("FELT_PADS %d pivot triangles moved from copper to rubber" % felt_pads(shell["core"]))
    spool = Part("SpoolKit")
    spool_kit(spool)
    for side in (-1, 1):
        mast(spool, side)
    sb._sharpen(spool)
    kit = spool.to_object((0, 0, 0), pod)
    tip = coil_tip().to_object((-MAST_X, 0, MAST_TIP[0]), pod)
    common.empty("RopeExit", ROPE_EXIT, pod)
    wrench_rack().to_object((0, RACK_Y, RACK_TOP), pod)
    new_ring = sable_ring().to_object((0, 0, 0), None)
    old = ring.data
    ring.data = new_ring.data
    bpy.data.objects.remove(new_ring)
    bpy.data.meshes.remove(old)
    ring.data.name = "WeaponRing"
    for tag, at in emitter_tips():
        common.empty(tag, at, ring)
    bpy.context.view_layer.update()
    shell["crown_ok"] = crown_report(ring, kit, tip)
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
    if not shell["crown_ok"]:
        raise SystemExit("crown reach or mast clearance out for " + name)


if __name__ == "__main__":
    main()
