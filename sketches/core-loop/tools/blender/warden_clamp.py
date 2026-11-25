import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy

import common
import polish
from common import Part, Vector

polish.enable(detail=2, bevel=0.04, bevel_angle=46.0, edge=0.0, ao_strength=0.35)

ENAMEL = "petrol"
DUST = common.mix("petrol", "sandstone", 0.35)
HINGE_X = 2.2
TOWER_TOP = 7.8
JAW_R = 3.1
JAW_Z = (2.4, 5.4)
BASE_TRIS = (4000, 14000)
KIT_TRIS = (800, 4600)


def dust(part):
    """Sandstone dust settles on the enamel's top faces."""
    part.bm.normal_update()
    idx = part.slots.index("ancient_enamel") if "ancient_enamel" in part.slots else -1
    top = [f for f in part.bm.faces if f.material_index == idx and f.normal.z > 0.6]
    part.paint(top, "ancient_enamel", DUST)
    for f in part.bm.faces:
        if f.material_index != idx:
            continue
        edge = any(len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.7 for e in f.edges)
        center = f.calc_center_median()
        if edge and math.sin(center.x*13.1+center.y*9.7+center.z*17.3) > 0.45:
            part.paint([f], "ancient_enamel", common.mix(ENAMEL, "bone", 0.20))
        elif f.normal.z < -0.15:
            part.paint([f], "ancient_enamel", common.mix(ENAMEL, "charcoal", 0.4))


def sweep(part, slot, profile, radius, a0, a1, segs, color=None, center=(0, 0), caps=True, taper=0.0, zc=0.0):
    """Sweeps a closed (dr, z) profile round the vertical axis at center, a0 to a1;
    taper shrinks the profile about height zc toward a1."""
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        ca, sa = math.cos(a), math.sin(a)
        s = 1.0 - taper * k / segs
        rows.append([part.bm.verts.new((center[0] + (radius + dr * s) * ca, center[1] + (radius + dr * s) * sa,
                                        zc + (z - zc) * s)) for dr, z in profile])
    faces = []
    n = len(profile)
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    if caps:
        faces.append(part.bm.faces.new(list(reversed(rows[0]))))
        faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def seam_ring(part, r, z, segs, a0=0.0, a1=math.tau, width=0.06):
    """A lit seam: a charcoal groove twice the seam's width, the light set inside."""
    sweep(part, "rubber", [(-0.1, z - width), (0.02, z - width), (0.02, z + width), (-0.1, z + width)],
          r, a0, a1, segs, caps=a1 - a0 < math.tau - 1e-6)
    sweep(part, "ancient_light", [(-0.05, z - width / 2), (0.035, z - width / 2), (0.035, z + width / 2),
                                  (-0.05, z + width / 2)], r, a0, a1, segs, caps=a1 - a0 < math.tau - 1e-6)


def seam_line(part, a, b, out, width=0.06):
    """A straight lit seam on a surface whose outward normal is out."""
    a, b, out = Vector(a), Vector(b), Vector(out).normalized()
    part.beam("rubber", a, b, width * 2, 0.06, roll=0.0)
    part.beam("ancient_light", a + out * 0.03, b + out * 0.03, width, 0.04)


def housing():
    p = Part("Housing")
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        foot = Vector((math.cos(a)*1.85, math.sin(a)*1.85, 0.35))
        knee = Vector((math.cos(a)*1.7, math.sin(a)*1.7, 1.35))
        hip = Vector((math.cos(a)*1.1, math.sin(a)*1.1, 2.2))
        p.box("ancient_enamel", (0.95,0.85,0.55), loc=foot, rot=(0,0,a), color=ENAMEL)
        p.rod("bare_metal", foot, knee, 0.18, 8)
        p.rod("ancient_enamel", knee, hip, 0.42, 8, color=ENAMEL, r2=0.5)
        p.ico("ancient_enamel", 0.48, 1, loc=knee, color=ENAMEL)
        seam_line(p, knee+Vector((0,0,0.05)), hip, (math.cos(a),math.sin(a),0), width=0.045)
    p.ico("ancient_enamel", 1.0, 2, loc=(0,0,2.05), scale=(2.0,2.0,0.85), color=ENAMEL)
    seam_ring(p, 1.84, 2.12, 24, width=0.06)
    return p


def tower():
    p = Part("Tower")
    c = (HINGE_X, 0.0)
    sweep(p, "ancient_enamel", [(-0.8, 2.2), (0.0, 2.2), (0.0, 4.6), (-0.1, 4.75), (-0.8, 4.75)],
          0.78, 0, math.tau, 20, ENAMEL, center=c, caps=False)
    sweep(p, "ancient_enamel", [(-0.7, 4.9), (-0.12, 4.9), (-0.12, TOWER_TOP - 0.25), (-0.3, TOWER_TOP),
                                (-0.7, TOWER_TOP)], 0.78, 0, math.tau, 20, ENAMEL, center=c, caps=False)
    seam_ring(p, 0.72, 4.82, 20, width=0.05)
    p.cyl("ancient_enamel", 0.48, 0.48, 0.02, 20, loc=(HINGE_X, 0, TOWER_TOP), color=ENAMEL)
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((HINGE_X, 0, 0)) + d * 0.66
        seam_line(p, base + Vector((0, 0, 5.1)), base + Vector((0, 0, TOWER_TOP - 0.4)), d, width=0.05)
    return p


def jaw(side):
    """One C-jaw, a tapering cast pincer. side +1 sweeps the +Y half, -1 the -Y half;
    the tips hook inward at -X and leave the mouth the beacon sits in."""
    p = Part("JawL" if side > 0 else "JawR")
    z0, z1 = JAW_Z
    zc = (z0 + z1) / 2
    lo, hi = (0.5, 2.85) if side > 0 else (-2.85, -0.5)
    a0, a1 = (lo, hi) if side > 0 else (hi, lo)
    body = [(-0.45, z0 + 0.4), (0.0, z0), (0.5, z0 + 0.45), (0.5, z1 - 0.45), (0.0, z1), (-0.45, z1 - 0.4)]
    flip = (lambda prof: prof) if side > 0 else (lambda prof: list(reversed(prof)))
    sweep(p, "ancient_enamel", flip(body), JAW_R, a0, a1, 26, ENAMEL, taper=0.45, zc=zc)
    s0, s1 = (0.8, 1.9) if side > 0 else (-0.8, -1.9)
    shell = [(0.42, z0 + 0.55), (0.62, z0 + 0.75), (0.62, z1 - 0.75), (0.42, z1 - 0.55)]
    sweep(p, "ancient_enamel", flip(shell), JAW_R, s0, s1, 12, ENAMEL)
    for a in (s0, s1):
        d = Vector((math.cos(a), math.sin(a), 0))
        seam_line(p, d * (JAW_R + 0.6) + Vector((0, 0, z0 + 0.8)), d * (JAW_R + 0.6) + Vector((0, 0, z1 - 0.8)), d)
    seam_ring(p, JAW_R + 0.62, zc, 12, min(s0, s1) + 0.05, max(s0, s1) - 0.05, width=0.05)
    tip = a1
    dt = Vector((math.cos(tip), math.sin(tip), 0))
    p.prism("bare_metal", [(0, -0.5), (0.85, 0.0), (0, 0.5)], 0.9,
            matrix=common.mtx(dt * (JAW_R - 0.2) + Vector((0, 0, zc)), (0, 0, tip + math.pi)))
    for k in range(4):
        a = tip - side * (0.22 + 0.22 * k)
        d = Vector((math.cos(a), math.sin(a), 0))
        p.prism("bare_metal", [(0, -0.28), (0.35, 0.0), (0, 0.28)], 0.5 - 0.06 * k,
                matrix=common.mtx(d * (JAW_R - 0.38 + 0.04 * k) + Vector((0, 0, zc)), (0, 0, a + math.pi)))
    start = Vector((math.cos(a0), math.sin(a0), 0)) * JAW_R
    p.beam("ancient_enamel", Vector((HINGE_X, side * 0.3, zc)), start + Vector((0, 0, zc)), 0.8, z1 - z0 - 0.6,
           color=ENAMEL)
    knuckles = (z0, z0 + 2.0) if side > 0 else (z0 + 1.0, z0 + 3.0)
    for z in knuckles:
        sweep(p, "ancient_enamel", [(-0.02, z), (0.34, z), (0.34, z + 0.9), (-0.02, z + 0.9)], 0.8,
              0, math.tau, 16, ENAMEL, center=(HINGE_X, 0.0), caps=False)
    seam_ring(p, 1.16, knuckles[0] + 0.45, 16, width=0.04)
    return p


def shoulder(side):
    p = Part("Shoulder")
    p.ico("ancient_enamel", 1.0, 1, loc=(0.65, side*2.7, 5.1), scale=(1.9,1.15,1.1), color=ENAMEL)
    p.beam("ancient_enamel", (1.8,side*1.5,5.2), (-0.8,side*2.5,5.8), 0.65, 0.7, color=ENAMEL)
    for j in range(2):
        a = (1.6,side*(1.5+j*0.36),4.6)
        b = (1.0,side*(1.8+j*0.36),6.0)
        p.rod("rubber", a, b, 0.12, 6)
        p.rod("ancient_light", (1.05,side*(1.8+j*0.36),5.72), b, 0.045, 6)
    return p


def segment_shoulder(side, half, name):
    """Bisect the existing crown; the union keeps its exact exterior and bounds."""
    p = shoulder(side)
    dust(p)
    p.name = name
    normal = Vector((0, side * half, 0))
    cut = bmesh.ops.bisect_plane(p.bm, geom=list(p.bm.verts) + list(p.bm.edges) + list(p.bm.faces),
                               dist=1e-6, plane_co=Vector((0, side * 2.7, 0)), plane_no=normal,
                               clear_inner=True, clear_outer=False)
    edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_boundary]
    if edges:
        caps = bmesh.ops.holes_fill(p.bm, edges=edges, sides=0)["faces"]
        p.paint(caps, "rubber")
    return p


def shoulder_inner(side):
    p = Part("InnerL" if side > 0 else "InnerR")
    p.ico("rubber", 1.0, 1, loc=(0.65, side*2.7, 5.1), scale=(1.55, 0.85, 0.82))
    p.beam("ancient_enamel", (1.7,side*1.6,5.2), (-0.65,side*2.45,5.65), 0.35, 0.4,
           color=common.mix("oxide", "charcoal", 0.8))
    return p


def core_assembly(base):
    root = common.empty("CoreAssembly", (1.2, 0, 3.9), base)
    heart = Part("HeartSurface")
    heart.ico("ancient_light", 0.5, 2, loc=(0, 0, 3.9))
    centre = Vector((0, 0, 3.9))
    for axis in range(3):
        width = max(v.co[axis] for v in heart.bm.verts) - min(v.co[axis] for v in heart.bm.verts)
        for v in heart.bm.verts:
            v.co[axis] = centre[axis] + (v.co[axis] - centre[axis]) / width
    heart.to_object((0, 0, 3.9), root).location = (0, 0, 0)
    cage = Part("CoreCage")
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        x, y = 0.55 * math.cos(a), 0.55 * math.sin(a)
        cage.rod("rubber", (x, y, 3.35), (x, y, 4.45), 0.065, 6)
    for z in (3.35, 4.45):
        cage.ring("bare_metal", 0.43, 0.62, 0.12, 12, loc=(0, 0, z))
    cage.to_object((0, 0, 3.9), root).location = (0, 0, 0)
    return root


def kit_reactor(rng):
    p = Part("WardenKitReactor")
    p.cyl("ancient_enamel", 1.0, 0.72, 0.5, 16, loc=(0, 0, 0.25), color=ENAMEL)
    p.cyl("ancient_enamel", 0.72, 1.15, 0.5, 16, loc=(0, 0, 0.75), color=ENAMEL)
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=16, v_segments=8, radius=1.3,
                                    matrix=common.mtx((0, 0, 1.0), (0, 0, 0), (1, 1, 0.72)))
    low = [v for v in res["verts"] if v.co.z < 0.99]
    bmesh.ops.delete(p.bm, geom=low, context="VERTS")
    shell = p._faces([v for v in res["verts"] if v.is_valid])
    crack = [f for f in shell if f.calc_center_median().x > 0.55 and abs(f.calc_center_median().y) < 0.62
             and f.calc_center_median().z < 1.75]
    bmesh.ops.delete(p.bm, geom=crack, context="FACES")
    shell = [f for f in shell if f.is_valid]
    p.paint(shell, "ancient_enamel", ENAMEL)
    p.bm.verts.index_update()
    edge = sorted({v for f in shell for v in f.verts if any(e.is_boundary for e in v.link_edges) and v.co.z > 1.02},
                  key=lambda v: v.index)
    for v in edge:
        v.co += Vector((rng.uniform(-0.09, 0.09), rng.uniform(-0.09, 0.09), rng.uniform(-0.06, 0.06)))
    seam_ring(p, 1.27, 1.2, 16, 0.8, math.tau - 0.8, width=0.05)
    for side in [-1, 1]:
        p.box("ancient_enamel", (0.7,0.35,0.55), loc=(-0.3,side*0.95,1.4), rot=(0.0,side*0.3,0.0), color=ENAMEL)
    dust(p)
    return p


def reactor_extras():
    core = Part("WeakPoint")
    core.ico("ancient_light", 0.55, 2, loc=(0.35, 0, 1.25))
    core.cyl("rubber", 0.62, 0.62, 0.12, 16, loc=(0.35, 0, 1.25), rot=(0, math.pi / 2, 0))
    vents = []
    for k in range(3):
        a = math.pi + (k - 1) * 0.95
        at = Vector((0.95 * math.cos(a), 0.95 * math.sin(a), 1.45))
        v = Part("Vent%d" % k)
        n = 10 // common.DETAIL
        v.cyl("ancient_enamel", 0.3, 0.24, 1.2, n, loc=at + Vector((0, 0, 0.6)), color=ENAMEL)
        v.ring("ancient_enamel", 0.2, 0.36, 0.14, n, loc=at + Vector((0, 0, 1.2)), color=DUST)
        v.ring("rubber", 0.22, 0.3, 0.1, n, loc=at + Vector((0, 0, 0.75)))
        v.ring("ancient_light", 0.25, 0.305, 0.04, n, loc=at + Vector((0, 0, 0.75)))
        vents.append((v, at))
    return [(core, (0.35, 0, 1.25))] + vents


def hexagon():
    """Six sides under any polish detail: the hive reads by its hexagons."""
    return 6 // common.DETAIL


def hex_cell(p, center, r, h, color, slot="ancient_enamel"):
    p.cyl(slot, r, r * 0.92, h, hexagon(), loc=center, color=color)


def kit_hive(rng):
    p = Part("WardenKitHive")
    p.cyl("ancient_enamel", 1.2, 1.0, 0.4, hexagon(), loc=(0, 0, 0.2), color=ENAMEL)
    cells = []
    r = 0.32
    for ring, z in ((0, 0.9), (1, 0.9), (2, 0.75), (1, 1.6), (0, 1.75)):
        if ring == 0:
            cells.append((Vector((0, 0, z)), 0.8 if z < 1 else 1.0))
            continue
        for k in range(6 * ring):
            a = k * math.tau / (6 * ring) + (0.3 if z > 1.2 else 0)
            d = ring * r * 1.75
            cells.append((Vector((d * math.cos(a), d * math.sin(a), z)), 0.9 - 0.2 * ring + rng.uniform(-0.1, 0.1)))
    for k, (c, h) in enumerate(cells):
        if c.x > 0.6 and abs(c.y) < 0.4 and c.z < 1.2:
            continue
        hex_cell(p, c, r, h, ENAMEL)
        if k % 2 == 0:
            p.cyl("rubber", r * 0.7, r * 0.7, 0.03, hexagon(), loc=c + Vector((0, 0, h / 2)))
            p.cyl("ancient_light", r * 0.45, r * 0.45, 0.04, hexagon(), loc=c + Vector((0, 0, h / 2 + 0.005)))
    for side in [-1, 1]:
        p.box("ancient_enamel", (0.7,0.3,0.5), loc=(-0.65,side*0.92,0.7), rot=(0.0,side*0.3,0.0), color=ENAMEL)
    dust(p)
    return p


def hive_extras():
    q = Part("WeakPoint")
    at = Vector((1.1, 0, 0.9))
    q.cyl("ancient_enamel", 0.46, 0.4, 0.9, hexagon(), loc=at, rot=(0, math.pi / 2, 0), color=ENAMEL, caps=False)
    q.ico("ancient_light", 0.3, 2, loc=at + Vector((0.05, 0, 0)))
    q.cyl("rubber", 0.5, 0.5, 0.06, hexagon(), loc=at + Vector((0.45, 0, 0)), rot=(0, math.pi / 2, 0))
    out = [(q, tuple(at))]
    for k in range(6):
        a = k * math.tau / 6 + math.pi / 6
        at_d = Vector((1.55 * math.cos(a), 1.55 * math.sin(a), 1.9 + 0.15 * (k % 2)))
        d = Part("Drone%d" % k)
        d.prism("ancient_enamel", [(0.0, 0.34), (-0.3, -0.2), (0.3, -0.2)], 0.07,
                matrix=common.mtx(at_d, (0, 0, a - math.pi / 2)), color=ENAMEL)
        d.prism("ancient_light", [(0.0, 0.14), (-0.1, -0.06), (0.1, -0.06)], 0.09,
                matrix=common.mtx(at_d, (0, 0, a - math.pi / 2)))
        out.append((d, tuple(at_d)))
    return out


def kit_mind(rng):
    p = Part("WardenKitMind")
    p.cyl("ancient_enamel", 0.62, 0.5, 0.5, 20, loc=(0, 0, 0.25), color=ENAMEL)
    p.cyl("ancient_enamel", 0.24, 0.2, 1.4, 12, loc=(0, 0, 1.2), color=ENAMEL)
    seam_ring(p, 0.23, 1.2, 12, width=0.04)
    for side in [-1, 1]:
        p.prism("ancient_enamel", [(-0.65,0), (0.5,-0.3), (0.6,0.3), (-0.4,0.4)], 0.4,
                matrix=common.mtx((-0.25,side*0.5,1.25)), color=ENAMEL)
    dust(p)
    return p


def mind_extras():
    out = []
    for side, name in ((1, "ArmL"), (-1, "ArmR")):
        arm = Part(name)
        pts = [Vector((0, side * 0.45, 0.45)), Vector((-0.2, side * 1.3, 2.1)), Vector((-1.2, side * 1.9, 3.1)),
               Vector((-2.3, side * 1.4, 3.4))]
        for a, b in zip(pts, pts[1:]):
            arm.rod("ancient_enamel", a, b, 0.11, 6, color=ENAMEL, r2=0.08)
        for q in pts[1:]:
            with arm.region(detail=1):
                arm.ico("ancient_enamel", 0.17, 1, loc=q, color=ENAMEL)
                arm.ring("ancient_light", 0.12, 0.18, 0.03, 8, loc=q, rot=(math.pi / 2, 0, 0))
        tip = pts[-1]
        with arm.region(bevel=0, detail=1):
            for k in range(3):
                a = (k - 1) * 0.6
                end = tip + Vector((-0.45 * math.cos(a), side * 0.45 * math.sin(a), -0.35))
                arm.rod("bare_metal", tip, end, 0.04, 5, r2=0.015)
        out.append((arm, tuple(pts[0])))
    lens = Part("WeakPoint")
    c = Vector((0.1, 0, 2.2))
    with lens.region(detail=1):
        lens.ico("ancient_enamel", 0.42, 2, loc=c, scale=(0.8, 1, 1), color=ENAMEL)
    for k, off in enumerate(((0, 0), (0.22, 0.2), (-0.22, 0.2), (0.22, -0.2), (-0.22, -0.2))):
        at = c + Vector((0.34, off[0], off[1]))
        r = 0.13 if k == 0 else 0.08
        lens.cyl("rubber", r + 0.04, r + 0.04, 0.08, 8, loc=at, rot=(0, math.pi / 2, 0))
        lens.cyl("ancient_light", r, r, 0.1, 8, loc=at + Vector((0.02, 0, 0)), rot=(0, math.pi / 2, 0))
    out.append((lens, tuple(c)))
    for k in range(6):
        a = k * math.tau / 6
        s = Part("Shutter%d" % k)
        at = c + Vector((0.3, 0.36 * math.cos(a), 0.36 * math.sin(a)))
        s.prism("ancient_enamel", [(0, -0.12), (0.3, 0), (0, 0.12)], 0.04,
                matrix=common.mtx(at, (a, -math.pi / 2, 0)) @ common.mtx((0, 0, 0), (0, 0, math.pi / 2)),
                color=ENAMEL)
        out.append((s, tuple(at)))
    return out


KIT_SCALE = 1.35


def build_kit(name, body, extras):
    """Kits are modelled at unit scale and grown so the family reads at range."""
    for part, origin in [(body, (0, 0, 0))] + list(extras):
        for v in part.bm.verts:
            v.co *= KIT_SCALE
    extras = [(part, tuple(c * KIT_SCALE for c in origin)) for part, origin in extras]
    root = common.empty(name)
    body_obj = body.to_object((0, 0, 0), root)
    body_obj.name = "Body"
    for part, origin in extras:
        part.to_object(origin, root)
    return root


def main():
    common.reset()
    a = common.args()
    rng = random.Random("scrapkeep-warden")
    base = common.empty("WardenClampBase")
    h = housing()
    dust(h)
    h.to_object((0, 0, 0), base)
    t = tower()
    dust(t)
    tower_obj = t.to_object((HINGE_X, 0, 0), base)
    common.empty("KitMount", (HINGE_X, 0, TOWER_TOP), tower_obj)
    for side in (1, -1):
        j = jaw(side)
        dust(j)
        jaw_obj = j.to_object((HINGE_X, 0, 0), base)
        for half in (1, -1):
            index = (0 if side > 0 else 1) + (0 if half > 0 else 2)
            segment = segment_shoulder(side, half, "ArmourSegment%d" % index).to_object((HINGE_X, 0, 0), jaw_obj)
            segment.location = (0, 0, 0)
        inner = shoulder_inner(side).to_object((HINGE_X, 0, 0), jaw_obj)
        inner.location = (0, 0, 0)
    core_assembly(base)
    rows = [("base", common.tri_total(base), BASE_TRIS)]
    out_dir = os.path.dirname(a["out"]) if a["out"] else common.MODELS
    common.export(base, os.path.join(out_dir, "warden_clamp_base.glb"))
    if "--base-only" in sys.argv:
        if not common.report("warden", rows):
            raise SystemExit("warden budget out of range")
        return
    kits = []
    for fam, body, extras in (("reactor", kit_reactor, reactor_extras), ("hive", kit_hive, hive_extras),
                              ("mind", kit_mind, mind_extras)):
        root = build_kit("WardenKit" + fam.capitalize(), body(rng), extras())
        rows.append(("kit_" + fam, common.tri_total(root), KIT_TRIS))
        common.export(root, os.path.join(out_dir, "warden_kit_%s.glb" % fam))
        # Blender names are file-global; free this kit's names (WeakPoint, Body) for the next.
        for o in common.tree(root)[1:]:
            o.name = fam + "_" + o.name
        kits.append((fam, root))
    ok = common.report("warden", rows)
    if a["render"]:
        sheets = []
        bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=12.0, location=(0, 0, 6.0))
        bpy.context.active_object.data.materials.append(common.material("rubber"))
        for fam, root in kits:
            root.parent = base
            root.location = (HINGE_X, 0, TOWER_TOP)
        for fam, root in kits:
            for other_fam, other in kits:
                for o in common.tree(other):
                    o.hide_render = other_fam != fam
            sheets.append(common.render_turntable(base, "warden_" + fam, a["render"], [
                ("game", 30.0, 0.25, 65, (1920, 1080), 0.5),
                ("close", 17.0, 0.2, 50, (800, 800)),
            ], ground_z=0.0, target=(0, 0, 4.0), yaws=(0, 90, 200)))
        out = os.path.join(a["render"], "warden_sheet.png")
        common.subprocess.run(["montage", *sheets, "-tile", "1x", "-geometry", "+0+4", "-background", "#242a28",
                               out], check=True)
        print("SHEET", out)
    if not ok:
        raise SystemExit("warden budget out of range")


main()
