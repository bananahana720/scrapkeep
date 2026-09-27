# Warden clamp (VISUAL-LANGUAGE.md sections 9 and 11): an awakened ancient, not Fleet
# gear. A shared base (a flared cast plinth round the beacon's foot, a pivot tower on
# its rim, and two massive crab-claw C-jaws that hinge at the tower and close round the
# beacon, toothed with bare metal on the faces that bite) plus one family kit per stage
# on the tower top. The kit owns the silhouette top and carries the weak point: a
# cracked-away shell opening framed by bright broken shards, with the ancient_light
# core glowing in a charcoal cavity. Reactor relic (stage 1): a dome and three fat vent
# stacks. Swarm-remnant hive (stage 2): a honeycomb mass ringed by orbiting drones. The
# Mind's hands (stage 3): two long jointed arms over a lens cluster.
# Cast, seamless and geometric: no bolts, welds or brass. Light lives only in thin
# ancient_light seams set in charcoal grooves twice their width, and in the weak point.
# The enamel is dull petrol with sandstone dust on top faces, under the section 11 cap.
# Provenance: authored procedurally here from Blender primitives and bmesh operators;
# no external assets. Measured tris: see the TRIS lines this prints (base 4000 to
# 6000, each kit 800 to 1500).
#
# Frame and nodes (for W7 to wire; this sketch does not wire the Warden):
#   warden_clamp_base.glb  WardenClampBase > Housing, Tower > KitMount, JawL, JawR
#     The beacon stands at the origin. JawL/JawR origins sit on the vertical hinge axis
#     at x = HINGE_X. They export open (rotation JAW_OPEN about Godot Y, JawL negative,
#     JawR positive); rotation 0 is closed, tips meeting round the beacon. Below 2 m
#     nothing passes r = 2.8 m, the collider radius warden_look.gd promises.
#   warden_kit_<family>.glb  WardenKit<Family> with its origin at KitMount and +X facing
#     away from the beacon; each has a WeakPoint node, plus Vent0..2 (reactor),
#     Drone0..7 (hive), ArmL/ArmR and Shutter0..5 (mind) for motion.

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402

import common  # noqa: E402
from common import Part, Vector  # noqa: E402

ENAMEL = "petrol"
DUST = common.mix("petrol", "sandstone", 0.35)
HINGE_X = 2.8
TOWER_TOP = 7.4
JAW_R = 3.1
JAW_ZC = 4.0
JAW_OPEN = 0.45
KIT_SCALE = 1.9
REACTOR_DOME = Vector((0, 0, 0.35))
REACTOR_CRACK = Vector((0.8, 0, 0.6)).normalized()
BASE_TRIS = (4000, 6000)
KIT_TRIS = (800, 1500)


def dust(part):
    """Sandstone dust settles on the enamel's top faces."""
    part.bm.normal_update()
    if "ancient_enamel" not in part.slots:
        return
    idx = part.slots.index("ancient_enamel")
    top = [f for f in part.bm.faces if f.material_index == idx and f.normal.z > 0.6]
    part.paint(top, "ancient_enamel", DUST)


def loft(part, slot, a0, a1, segs, section, color=None, center=(0.0, 0.0), caps=True):
    """Sweeps section(t) -> [(radius, z), ...] round the vertical axis at center from
    angle a0 to a1. Sections run bottom, outward, top, inward."""
    rows = []
    for k in range(segs + 1):
        t = k / segs
        a = a0 + (a1 - a0) * t
        ca, sa = math.cos(a), math.sin(a)
        pts = section(t) if a1 > a0 else list(reversed(section(t)))
        rows.append([part.bm.verts.new((center[0] + r * ca, center[1] + r * sa, z)) for r, z in pts])
    faces = []
    n = len(rows[0])
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    if caps:
        faces.append(part.bm.faces.new(list(reversed(rows[0]))))
        faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def ring_section(r_in, r_out, z0, z1):
    return lambda t: [(r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)]


def seam(part, r, z, segs, a0=0.0, a1=math.tau, width=0.06, center=(0.0, 0.0)):
    """A lit seam: a charcoal groove twice the seam's width, the light set inside."""
    closed = a1 - a0 >= math.tau - 1e-6
    loft(part, "rubber", a0, a1, segs, ring_section(r - 0.1, r + 0.02, z - width, z + width),
         center=center, caps=not closed)
    loft(part, "ancient_light", a0, a1, segs, ring_section(r - 0.05, r + 0.035, z - width / 2, z + width / 2),
         center=center, caps=not closed)


def seam_line(part, a, b, out, width=0.06):
    a, b, out = Vector(a), Vector(b), Vector(out).normalized()
    part.beam("rubber", a, b, width * 2, 0.06)
    part.beam("ancient_light", a + out * 0.03, b + out * 0.03, width, 0.04)


def housing():
    p = Part("Housing")
    loft(p, "ancient_enamel", 0, math.tau, 40,
         lambda t: [(1.4, 0.0), (2.75, 0.0), (2.75, 0.35), (2.45, 0.9), (2.35, 1.7), (2.1, 1.9), (1.4, 1.9)],
         ENAMEL, caps=False)
    seam(p, 2.52, 0.62, 40)
    for k in range(5):
        a = k * math.tau / 5 + 0.6
        d = Vector((math.cos(a), math.sin(a), 0))
        seam_line(p, d * 2.4 + Vector((0, 0, 0.95)), d * 2.36 + Vector((0, 0, 1.65)), d, width=0.05)
    dust(p)
    return p


def tower():
    p = Part("Tower")
    c = (HINGE_X, 0.0)
    loft(p, "ancient_enamel", 0, math.tau, 20,
         lambda t: [(0.0, 1.9), (1.05, 1.9), (0.85, 2.3), (0.78, 4.4), (0.66, 4.55), (0.0, 4.55)],
         ENAMEL, center=c, caps=False)
    loft(p, "ancient_enamel", 0, math.tau, 20,
         lambda t: [(0.0, 4.7), (0.66, 4.7), (0.66, TOWER_TOP - 0.3), (0.95, TOWER_TOP), (0.0, TOWER_TOP)],
         ENAMEL, center=c, caps=False)
    seam(p, 0.7, 4.62, 20, width=0.05, center=c)
    dust(p)
    return p


def jaw(side):
    """One crab-claw C-jaw in the closed pose: a tall palm that tapers to a hooked tip,
    its inner face toothed with bare metal. side +1 sweeps the +Y half, -1 the -Y."""
    p = Part("JawL" if side > 0 else "JawR")
    a_hinge, a_tip = 0.32, math.pi - 0.1
    a0, a1 = (a_hinge, a_tip) if side > 0 else (-a_hinge, -a_tip)

    def hook(t):
        return 0.95 * max(0.0, (t - 0.78) / 0.22) ** 2

    def width(t):
        return 0.45 + 1.0 * math.sin(math.pi * min(t, 0.9) / 0.9 * 0.5 + 0.25) ** 1.5 * (1.0 - 0.75 * t)

    def half(t):
        return 1.5 * (1.0 - 0.6 * t) + 0.25

    def body(t):
        ri = JAW_R - 0.45 - hook(t)
        w, h = width(t), half(t)
        return [(ri, JAW_ZC - h + 0.25), (ri + 0.3 * w, JAW_ZC - h), (ri + w, JAW_ZC - 0.5 * h),
                (ri + w, JAW_ZC + 0.5 * h), (ri + 0.3 * w, JAW_ZC + h), (ri, JAW_ZC + h - 0.25)]

    loft(p, "ancient_enamel", a0, a1, 30, body, ENAMEL)
    s0, s1 = 0.18, 0.66
    sa, sb = a0 + (a1 - a0) * s0, a0 + (a1 - a0) * s1

    def palm(u):
        t = s0 + (s1 - s0) * u
        ri, w, h = JAW_R - 0.45 - hook(t), width(t), half(t)
        return [(ri + w - 0.05, JAW_ZC - 0.62 * h), (ri + w + 0.16, JAW_ZC - 0.55 * h),
                (ri + w + 0.16, JAW_ZC + 0.55 * h), (ri + w - 0.05, JAW_ZC + 0.62 * h)]

    loft(p, "ancient_enamel", sa, sb, 14, palm, ENAMEL)
    for z_sign in (-1, 1):
        def groove(u, z_sign=z_sign, width_=0.05):
            t = s0 + (s1 - s0) * u
            r = JAW_R - 0.45 - hook(t) + width(t) + 0.17
            z = JAW_ZC + z_sign * 0.66 * half(t)
            return [(r - 0.1, z - width_), (r + 0.02, z - width_), (r + 0.02, z + width_), (r - 0.1, z + width_)]

        def light(u, z_sign=z_sign):
            t = s0 + (s1 - s0) * u
            r = JAW_R - 0.45 - hook(t) + width(t) + 0.17
            z = JAW_ZC + z_sign * 0.66 * half(t)
            return [(r - 0.05, z - 0.025), (r + 0.035, z - 0.025), (r + 0.035, z + 0.025), (r - 0.05, z + 0.025)]

        loft(p, "rubber", sa, sb, 14, groove)
        loft(p, "ancient_light", sa, sb, 14, light)
    for k in range(7):
        t = 0.3 + 0.1 * k
        a = a0 + (a1 - a0) * t
        d = Vector((math.cos(a), math.sin(a), 0))
        ri = JAW_R - 0.45 - hook(t)
        h = half(t) * 1.5
        p.prism("bare_metal", [(0, -0.26), (0.5, 0.0), (0, 0.26)], h,
                matrix=common.mtx(d * (ri + 0.12) + Vector((0, 0, JAW_ZC)), (0, 0, a + math.pi)))
    for k in range(6):
        t = 0.22 + 0.11 * k
        a = a0 + (a1 - a0) * t
        d = Vector((math.cos(a), math.sin(a), 0))
        ri = JAW_R - 0.45 - hook(t)
        root = d * (ri + 0.2 * width(t)) + Vector((0, 0, JAW_ZC + half(t) - 0.1))
        p.rod("bare_metal", root, root + Vector((0, 0, 0.75 - 0.05 * k)) - d * 0.35, 0.2, 4, r2=0.01)
    tip = Vector((math.cos(a1), math.sin(a1), 0))
    p.prism("bare_metal", [(0, -0.4), (0.9, -0.1), (0.2, 0.45)], half(1.0) * 1.6,
            matrix=common.mtx(tip * (JAW_R - 0.45 - hook(1.0) + 0.1) + Vector((0, 0, JAW_ZC)),
                              (0, 0, a1 + math.pi - side * 0.5)))
    start = Vector((math.cos(a0), math.sin(a0), 0)) * (JAW_R - 0.1)
    p.beam("ancient_enamel", Vector((HINGE_X, side * 0.2, JAW_ZC)), start + Vector((0, 0, JAW_ZC)), 0.9,
           2 * half(0.0) - 0.5, color=ENAMEL)
    knuckles = (2.2, 4.25) if side > 0 else (3.2, 5.25)
    for z in knuckles:
        loft(p, "ancient_enamel", 0, math.tau, 16, ring_section(0.8, 1.25, z, z + 0.95), ENAMEL,
             center=(HINGE_X, 0.0), caps=False)
    seam(p, 1.28, knuckles[0] + 0.47, 16, width=0.04, center=(HINGE_X, 0.0))
    dust(p)
    return p


def shards(part, center, facing, radius, count, rng, length=(0.25, 0.5), r=0.07):
    """Bright broken shell teeth ringing an opening, pointing into it."""
    f = Vector(facing).normalized()
    u = f.cross(Vector((0, 0, 1)))
    if u.length < 1e-3:
        u = Vector((1, 0, 0))
    u.normalize()
    v = f.cross(u).normalized()
    c = Vector(center)
    for k in range(count):
        phi = k * math.tau / count + rng.uniform(-0.15, 0.15)
        rim = c + (u * math.cos(phi) + v * math.sin(phi)) * radius
        inward = (c - rim).normalized()
        tip = rim + inward * rng.uniform(*length) + f * rng.uniform(0.05, 0.2)
        part.rod("bare_metal", rim - f * 0.05, tip, r * rng.uniform(0.8, 1.3), 4, r2=0.006)


def weak_point(center, facing, core_r, rim_r, rng, count=9):
    """The cracked opening: shards round a charcoal cavity with the core glowing in it."""
    w = Part("WeakPoint")
    f = Vector(facing).normalized()
    c = Vector(center)
    w.ico("rubber", core_r * 1.5, 2, loc=c - f * core_r * 0.6)
    w.ico("ancient_light", core_r, 2, loc=c)
    shards(w, c + f * core_r * 0.2, f, rim_r, count, rng, length=(rim_r * 0.35, rim_r * 0.7), r=rim_r * 0.13)
    return w


def kit_reactor(rng):
    p = Part("Body")
    p.cyl("ancient_enamel", 1.05, 1.15, 0.35, 16, loc=(0, 0, 0.175), color=ENAMEL)
    dc = REACTOR_DOME
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=16, v_segments=8, radius=1.25,
                                    matrix=common.mtx(dc, (0, 0, 0), (1, 1, 0.9)))
    low = [v for v in res["verts"] if v.co.z < dc.z - 1e-4]
    bmesh.ops.delete(p.bm, geom=low, context="VERTS")
    shell = p._faces([v for v in res["verts"] if v.is_valid])
    crack = [f for f in shell if (f.calc_center_median() - dc).normalized().dot(REACTOR_CRACK) > 0.74]
    bmesh.ops.delete(p.bm, geom=crack, context="FACES")
    shell = [f for f in shell if f.is_valid]
    p.paint(shell, "ancient_enamel", ENAMEL)
    seam(p, 1.24, dc.z + 0.12, 16, 0.9, math.tau - 0.9, width=0.05)
    dust(p)
    return p


def reactor_extras(rng):
    wp_c = REACTOR_DOME + REACTOR_CRACK * 1.15
    out = [(weak_point(wp_c, REACTOR_CRACK, 0.6, 0.85, rng, count=10), tuple(wp_c))]
    for k in range(3):
        a = math.radians(60 + 120 * k)
        at = Vector((1.0 * math.cos(a), 1.0 * math.sin(a), 0.55))
        v = Part("Vent%d" % k)
        loft(v, "ancient_enamel", 0, math.tau, 8,
             lambda t: [(0.0, 0.0), (0.42, 0.0), (0.36, 1.7), (0.52, 2.15), (0.34, 2.2), (0.0, 2.2)],
             ENAMEL, center=(at.x, at.y), caps=False)
        for q in v.bm.verts:
            q.co.z += at.z
        seam(v, 0.37, at.z + 1.4, 8, width=0.04, center=(at.x, at.y))
        dust(v)
        out.append((v, tuple(at)))
    return out


def kit_hive(rng):
    p = Part("Body")
    p.cyl("ancient_enamel", 1.0, 0.85, 0.35, 6, loc=(0, 0, 0.175), color=ENAMEL)
    hc = Vector((0, 0, 1.25))
    p.ico("ancient_enamel", 1.2, 2, loc=hc, scale=(1, 1, 0.9), color=ENAMEL)
    n = 28
    lit = 0
    for k in range(n):
        y = 1.0 - (k + 0.5) / n * 1.3
        r = math.sqrt(max(0.0, 1.0 - y * y))
        ang = k * 2.39996
        d = Vector((math.cos(ang) * r, math.sin(ang) * r, y))
        if d.dot(Vector((0.85, 0, 0.5)).normalized()) > 0.8:
            continue
        at = hc + Vector((d.x * 1.18, d.y * 1.18, d.z * 1.06))
        rot = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        p.cyl("ancient_enamel", 0.3, 0.27, 0.34, 6, loc=at, rot=rot, color=ENAMEL)
        if k % 3 == 0 and lit < 9:
            lit += 1
            p.cyl("rubber", 0.2, 0.2, 0.04, 6, loc=at + d * 0.17, rot=rot)
            p.cyl("ancient_light", 0.12, 0.12, 0.05, 6, loc=at + d * 0.18, rot=rot)
    dust(p)
    return p


def hive_extras(rng):
    facing = Vector((0.85, 0, 0.5)).normalized()
    wp_c = Vector((0, 0, 1.25)) + facing * 1.32
    q = weak_point(wp_c, facing, 0.5, 0.78, rng, count=10)
    ring = [(q, tuple(wp_c))]
    tilt = 0.35
    for k in range(8):
        a = k * math.tau / 8
        at = Vector((2.15 * math.cos(a), 2.15 * math.sin(a) * math.cos(tilt), 1.3 + 2.15 * math.sin(a) * math.sin(tilt)))
        d = Part("Drone%d" % k)
        m = common.mtx(at, (0, 0, a + math.pi / 2)) @ common.mtx((0, 0, 0), (-tilt * math.cos(a), 0, 0))
        d.prism("ancient_enamel", [(0.0, 0.42), (-0.34, -0.22), (0.0, -0.1), (0.34, -0.22)], 0.08, matrix=m,
                color=ENAMEL)
        d.prism("ancient_light", [(0.0, 0.16), (-0.1, -0.06), (0.1, -0.06)], 0.1, matrix=m)
        ring.append((d, tuple(at)))
    return ring


def kit_mind(rng):
    p = Part("Body")
    p.cyl("ancient_enamel", 0.7, 0.55, 0.5, 12, loc=(0, 0, 0.25), color=ENAMEL)
    p.cyl("ancient_enamel", 0.26, 0.2, 1.7, 10, loc=(0, 0, 1.35), color=ENAMEL)
    p.cyl("ancient_enamel", 0.55, 0.5, 0.35, 12, loc=(0, 0, 0.62), color=ENAMEL)
    head = Vector((0.1, 0, 2.5))
    p.ico("ancient_enamel", 0.75, 2, loc=head, scale=(0.85, 1, 0.95), color=ENAMEL)
    seam(p, 0.25, 1.5, 10, width=0.04)
    dust(p)
    return p


def mind_extras(rng):
    out = []
    for side, name in ((1, "ArmL"), (-1, "ArmR")):
        arm = Part(name)
        pts = [Vector((0, side * 0.3, 1.2)), Vector((-0.1, side * 1.5, 2.9)), Vector((-1.3, side * 2.2, 3.9)),
               Vector((-2.7, side * 1.5, 3.8))]
        for a, b in zip(pts, pts[1:]):
            arm.rod("ancient_enamel", a, b, 0.13, 6, color=ENAMEL, r2=0.09)
        for q in pts[1:]:
            arm.ico("ancient_enamel", 0.2, 1, loc=q, color=ENAMEL)
        arm.ring("rubber", 0.16, 0.24, 0.05, 8, loc=pts[2], rot=(math.pi / 2, 0, 0))
        arm.ring("ancient_light", 0.18, 0.225, 0.06, 8, loc=pts[2], rot=(math.pi / 2, 0, 0))
        tip = pts[-1]
        for k in range(3):
            a = (k - 1) * 0.55
            end = tip + Vector((-0.6 * math.cos(a), side * 0.6 * math.sin(a), -0.55))
            arm.rod("bare_metal", tip, end, 0.06, 4, r2=0.015)
        dust(arm)
        out.append((arm, tuple(pts[0])))
    facing = Vector((0.8, 0, 0.6)).normalized()
    head = Vector((0.1, 0, 2.5))
    lens_c = head + facing * 0.72
    lens = weak_point(lens_c, facing, 0.44, 0.7, rng, count=8)
    u = facing.cross(Vector((0, 0, 1))).normalized()
    v = facing.cross(u).normalized()
    for off in ((0.28, 0.0), (-0.28, 0.0), (0.0, 0.28), (0.0, -0.28)):
        at = lens_c + u * off[0] * 1.3 + v * off[1] * 1.3 + facing * 0.05
        rot = Vector((0, 0, 1)).rotation_difference(facing).to_euler()
        lens.cyl("rubber", 0.12, 0.12, 0.06, 8, loc=at, rot=rot)
        lens.cyl("ancient_light", 0.08, 0.08, 0.08, 8, loc=at + facing * 0.01, rot=rot)
    out.append((lens, tuple(lens_c)))
    for k in range(6):
        a = k * math.tau / 6
        s = Part("Shutter%d" % k)
        at = lens_c + (u * math.cos(a) + v * math.sin(a)) * 0.82 - facing * 0.05
        rot = Vector((0, 0, 1)).rotation_difference(facing).to_euler()
        m = common.mtx(at, tuple(rot)) @ common.mtx((0, 0, 0), (0, 0, a))
        s.prism("ancient_enamel", [(0.0, -0.17), (0.34, 0.0), (0.0, 0.17)], 0.05, matrix=m, color=ENAMEL)
        out.append((s, tuple(at)))
    return out


def build_kit(name, body, extras):
    """Kits are modelled at unit scale and grown so the family owns the silhouette top."""
    for part, origin in [(body, (0, 0, 0))] + list(extras):
        for v in part.bm.verts:
            v.co *= KIT_SCALE
    extras = [(part, tuple(c * KIT_SCALE for c in origin)) for part, origin in extras]
    root = common.empty(name)
    body.to_object((0, 0, 0), root)
    for part, origin in extras:
        part.to_object(origin, root)
    return root


def main():
    common.reset()
    a = common.args()
    rng = random.Random("scrapkeep-warden")
    base = common.empty("WardenClampBase")
    housing().to_object((0, 0, 0), base)
    tower_obj = tower().to_object((HINGE_X, 0, 0), base)
    common.empty("KitMount", (HINGE_X, 0, TOWER_TOP), tower_obj)
    jaws = []
    for side in (1, -1):
        j = jaw(side).to_object((HINGE_X, 0, 0), base)
        j.rotation_euler = (0, 0, -side * JAW_OPEN)
        jaws.append(j)
    rows = [("base", common.tri_total(base), BASE_TRIS)]
    out_dir = os.path.dirname(a["out"]) if a["out"] else common.MODELS
    common.export(base, os.path.join(out_dir, "warden_clamp_base.glb"))
    kits = []
    for fam, body, extras in (("reactor", kit_reactor, reactor_extras), ("hive", kit_hive, hive_extras),
                              ("mind", kit_mind, mind_extras)):
        root = build_kit("WardenKit" + fam.capitalize(), body(rng), extras(rng))
        rows.append(("kit_" + fam, common.tri_total(root), KIT_TRIS))
        common.export(root, os.path.join(out_dir, "warden_kit_%s.glb" % fam))
        # Blender names are file-global; free this kit's names (WeakPoint, Body) for the next.
        for o in common.tree(root)[1:]:
            o.name = fam + "_" + o.name
        kits.append((fam, root))
    ok = common.report("warden", rows)
    if a["render"]:
        render(a["render"], base, jaws, kits)
    if not ok:
        raise SystemExit("warden budget out of range")


def render(out_dir, base, jaws, kits):
    # Preview only, never exported: the beacon mast the jaws close round.
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=13.0, location=(0, 0, 6.5))
    bpy.context.active_object.data.materials.append(common.material("rubber"))
    for fam, root in kits:
        root.parent = base
        root.location = (HINGE_X, 0, TOWER_TOP)
    sheets = []
    for fam, root in kits:
        for other_fam, other in kits:
            for o in common.tree(other):
                o.hide_render = other_fam != fam
        parts = [common.render_turntable(base, "warden_%s_side" % fam, out_dir, [
            ("game", 30.0, 0.25, 65, (1920, 1080), 0.5),
            ("close", 20.0, 0.22, 50, (800, 800)),
        ], ground_z=0.0, target=(0, 0, 5.0), yaws=(0, 90, 250))]
        parts.append(common.render_turntable(base, "warden_%s_top_open" % fam, out_dir, [
            ("top", 30.0, 1.25, 65, (1920, 1080), 0.5)], ground_z=0.0, target=(0, 0, 4.0), yaws=(90,)))
        for j in jaws:
            j.rotation_euler = (0, 0, 0)
        parts.append(common.render_turntable(base, "warden_%s_top_closed" % fam, out_dir, [
            ("top", 30.0, 1.25, 65, (1920, 1080), 0.5)], ground_z=0.0, target=(0, 0, 4.0), yaws=(90,)))
        for j, side in zip(jaws, (1, -1)):
            j.rotation_euler = (0, 0, -side * JAW_OPEN)
        tops = os.path.join(out_dir, "warden_%s_tops.png" % fam)
        common.subprocess.run(["montage", parts[1], parts[2], "-tile", "2x", "-geometry", "+4+4",
                               "-background", "#242a28", tops], check=True)
        sheets += [parts[0], tops]
    out = os.path.join(out_dir, "warden_sheet.png")
    common.subprocess.run(["montage", *sheets, "-tile", "1x", "-geometry", "+0+4", "-background", "#242a28",
                           out], check=True)
    print("SHEET", out)


main()
