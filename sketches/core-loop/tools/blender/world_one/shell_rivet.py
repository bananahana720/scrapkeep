import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
from mathutils import Vector

import common
import rivet_revolvers as revolvers
import shell_base as sb
from common import Part

SHELL_BAND = (3000, 11000)
ENAMEL = "charcoal"
SEAT = "bone"
BANK = (("Lever", "lever"), ("WinchLever", "lever"))

DRILL_Z = -0.22
DRILL_Y0 = 0.88
DRILL_STEPS = ((0.88, 1.00, 0.17, 0.155), (1.00, 1.10, 0.13, 0.11), (1.10, 1.18, 0.09, 0.07))
LENS_R = 0.06
DRILL_SIDES = 10
LENS_DEPTH = 0.006
MOUTH_DEPTH = 0.01
TICK_DEPTH = 0.008
STACK_X = 0.25
STACK_Y = -0.20
STACK_BASE = 0.80
STACK_R = 0.055
STACK_RISE = 0.18
STACK_TOP = round(math.sqrt(sb.LATTICE_OUTER ** 2 - STACK_X ** 2 - STACK_Y ** 2) + STACK_RISE, 3)
BRACKET_FOOT = (0.22, -0.20, -0.12)
BRACKET_R = 0.02
FIN_AT = ((38.0, -32.0), (-38.0, -32.0))
FIN_IN, FIN_OUT = 0.978, 0.983
FIN_TIP, FIN_TAIL, FIN_HALF = 0.11, 0.07, 0.07
TICK_R = round(sb.BAR_WIDTH * 0.42, 4)


def flag(name, default=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return default
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def direction(az_deg, el_deg):
    az, el = math.radians(az_deg), math.radians(el_deg)
    return Vector((math.cos(el) * math.sin(az), math.cos(el) * math.cos(az), math.sin(el)))


def plug(part, centre, normal, radius, sides, depth, slot, color=None, roll=0.0):
    """A closed flush mark: the flat polygon _disc draws, its rim closed to a point depth behind
    it, buried in the part under it (sides more triangles than the open disc)."""
    c, n = Vector(centre), Vector(normal).normalized()
    e1, e2 = sb._frame(n)
    rim = [part.bm.verts.new(c + radius * (math.cos(roll + k * math.tau / sides) * e1
                                           + math.sin(roll + k * math.tau / sides) * e2)) for k in range(sides)]
    tip = part.bm.verts.new(c - n * depth)
    faces = [part.bm.faces.new(rim)] + [part.bm.faces.new((rim[(k + 1) % sides], rim[k], tip)) for k in range(sides)]
    return part.paint(faces, slot, color)


def fin(part, centre_dir):
    """A copper fin lying on the lattice: a raked triangle whose tip points toward the front gap,
    each vertex on the sphere, the face split once so it follows the curve (20 tris)."""
    d = centre_dir.normalized()
    front = Vector((0, 1, 0))
    u = (front - d * front.dot(d)).normalized()
    v = d.cross(u).normalized()
    tip = u * FIN_TIP
    a = -u * FIN_TAIL + v * FIN_HALF
    b = -u * FIN_TAIL - v * FIN_HALF
    outline = [tip, (tip + a) / 2, a, (a + b) / 2, b, (b + tip) / 2]
    def on(p, r):
        return (d * FIN_OUT + p).normalized() * r
    top = [part.bm.verts.new(on(p, FIN_OUT)) for p in outline]
    bot = [part.bm.verts.new(on(p, FIN_IN)) for p in outline]
    faces = []
    for ring, flip in ((top, False), (bot, True)):
        for tri in ((0, 1, 5), (1, 2, 3), (3, 4, 5), (1, 3, 5)):
            vs = [ring[i] for i in tri]
            faces.append(part.bm.faces.new(list(reversed(vs)) if flip else vs))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        faces.append(part.bm.faces.new((bot[i], bot[j], top[j], top[i])))
    part.paint(faces, "copper")


def scale_ticks(part, pairs):
    """Calibrated: a bone scale tick on the first outer strut bar of every link, a quarter of the
    way along from the five-way hub (one per link keeps the shell inside 11,600 verts). Returns
    the ticks' faces."""
    ticks = []
    hubs, links, _ = sb.lattice_layout()
    r_bar = sb.LATTICE_OUTER - sb.STRUT_PAIR / 4
    for i, j in links:
        a, b = hubs[i], hubs[j]
        s = a.cross(b).normalized()
        span = sb.HUB_CLEAR / (sb.HUB_RADIUS * a.angle(b))
        for k in range(min(pairs, 1)):
            t0 = span + (1 - 2 * span) * k / pairs
            t1 = span + (1 - 2 * span) * (k + 1) / pairs
            p0 = sb._slerp(a, b, t0) * r_bar - s * sb.CHAIN_WIDTH / 2
            p1 = sb._slerp(a, b, t1) * r_bar + s * sb.CHAIN_WIDTH / 2
            n = ((p0 + p1) / 2).normalized()
            p = p0.lerp(p1, 0.28) + n * (sb.STRUT_PAIR / 4 + 0.0015)
            ticks += plug(part, p, n, TICK_R, 4, TICK_DEPTH, "paint", "bone", roll=0.785)
    return ticks


def make_lattice(variant):
    base = sb.lattice

    def lattice(part, enamel="petrol", pairs=2, hub_sides=8, cap_sides=8, rng=None,
                strut_width=sb.BAR_WIDTH, cap_width=sb.CAP_WIDTH):
        out = base(part, enamel, pairs, hub_sides, cap_sides, rng, strut_width, cap_width)
        for az, el in FIN_AT:
            fin(part, direction(az, el))
        ticks = scale_ticks(part, pairs) if variant else []
        for e in part.bm.edges:
            e.smooth = True
        sb._sharpen(part, angle=1.1)
        for f in ticks:
            for e in f.edges:
                e.smooth = True
        return out
    return lattice


def stacks(p, variant):
    """Twin copper stacks on slim gap brackets, a rubber rim, the glowing mouth on top."""
    height = STACK_TOP - STACK_BASE
    for side in (-1, 1):
        x = side * STACK_X
        p.cyl("copper", STACK_R, STACK_R, height, 8, loc=(x, STACK_Y, STACK_BASE + height / 2))
        p.cyl("rubber", STACK_R + 0.007, STACK_R + 0.007, 0.03, 8, loc=(x, STACK_Y, STACK_TOP - 0.012))
        plug(p, (x, STACK_Y, STACK_TOP + 0.0045), (0, 0, 1), STACK_R - 0.012, 6, MOUTH_DEPTH, "class_accent")
        if variant:
            for z in (STACK_BASE + 0.13, STACK_BASE + 0.19):
                p.cyl("paint", STACK_R + 0.004, STACK_R + 0.004, 0.016, 8, loc=(x, STACK_Y, z), color="bone")
        fx, fy, fz = BRACKET_FOOT
        p.rod("rubber", (side * fx, fy, fz), (x, STACK_Y, STACK_BASE + 0.02), BRACKET_R, 6)


def make_cockpit(variant):
    base = sb.cockpit

    def cockpit(seat="bone", bank=BANK):
        p = base(seat, bank)
        stacks(p, variant)
        _, ly, lz = sb.LAP_HANDS["LapBar.R"]
        p.cyl("copper", 0.03, 0.03, 0.02, 6, loc=(0, ly + 0.01, lz + 0.05), rot=(math.pi / 2, 0, 0))
        p.rod("copper", (0, ly, lz), (0, ly + 0.01, lz + 0.035), 0.01, 4)
        return p
    return cockpit


def drop_neutral_seat(r):
    """Removes the neutral weapon seat (the box and rod in front of the band at 12 o'clock)."""
    b_out = sb.RING_BAND[1]
    seeds = [v for v in r.bm.verts if v.co.y > b_out + 0.02 and abs(v.co.x) < 0.09 and abs(v.co.z) < 0.08]
    island, stack = set(seeds), list(seeds)
    while stack:
        v = stack.pop()
        for e in v.link_edges:
            w = e.other_vert(v)
            if w not in island:
                island.add(w)
                stack.append(w)
    r.bm.verts.index_update()
    bmesh.ops.delete(r.bm, geom=sorted(island, key=lambda v: v.index), context="VERTS")


def studs_to_copper(r):
    """The collar's bearing studs show copper (ROSTER-LOOK 0.7); the ring now has a copper slot.
    A stud is E1-03's closed pin head (shell_base._stud): four triangles round the collar's outer
    face, the only triangles there (the collar, band and clamp blocks are quads). Returns the count."""
    c_in, c_out, _, c_z = sb.RING_COLLAR
    faces = [f for f in r.bm.faces if len(f.verts) == 3
             and all(abs(v.co.z - c_z) < 0.016 and c_out - 0.005 < Vector((v.co.x, v.co.y, 0)).length < c_out + 0.02
                     for v in f.verts)]
    r.bm.faces.index_update()
    r.paint(sorted(faces, key=lambda f: f.index), "copper")
    return len(faces) // 4 if len(faces) % 4 == 0 else -1


def make_ring():
    base = sb.weapon_ring

    def weapon_ring(enamel_band="bone"):
        r = base(enamel_band)
        drop_neutral_seat(r)
        studs = studs_to_copper(r)
        if studs != 12:
            raise SystemExit("expected 12 collar studs, found %d" % studs)
        r.box("copper", (0.07, 0.04, 0.035), loc=(0, (sb.RING_COLLAR[0] + sb.RING_COLLAR[1]) / 2, -0.0875))
        sb._sharpen(r)
        return r
    return weapon_ring


def drill(variant):
    """The stepped drill cone (Drill, which spins about its own +Y axis) with the lens disc."""
    d = Part("Drill")
    for n, (y0, y1, r0, r1) in enumerate(DRILL_STEPS):
        d.cyl("copper", r0, r1, y1 - y0, DRILL_SIDES, loc=(0, (y0 + y1) / 2, DRILL_Z), rot=(-math.pi / 2, 0, 0))
        if variant:
            for k in range(n + 1):
                a = math.pi / 2 + (k - n / 2) * 0.32
                p = Vector((math.cos(a) * (r0 - 0.004), y0 + 0.012, DRILL_Z + math.sin(a) * (r0 - 0.004)))
                d.box("copper", (0.018, 0.02, 0.018), loc=p)
    tip = DRILL_STEPS[-1][1]
    plug(d, (0, tip + 0.0015, DRILL_Z), (0, 1, 0), LENS_R, 10, LENS_DEPTH, "class_accent")
    sb._sharpen(d)
    return d


def pilot():
    """The seated mole the shell carries as its placeholder (hidden in play; the animated pilot
    from pilot_rivet_anim.glb takes its place). Same shapes as the VD-01 seat, fewer segments, all
    smooth: E1-09 cut it to keep the Calibrated shell inside the 11,600-vertex shell cap once
    E1-03's closed bars split more lattice vertices."""
    f = Part("Pilot")
    fur = common.mix("charcoal", "bone", 0.32)
    pink = common.mix("oxide", "bone", 0.55)
    f.uv("pilot", 0.23, 8, 6, loc=(0, 0, 1.1), scale=(1.12, 0.96, 0.93), color=fur)
    f.uv("pilot", 0.1, 6, 3, loc=(0, 0.21, 1.045), scale=(1.05, 1.15, 0.72), color=pink)
    f.uv("pilot", 0.055, 6, 3, loc=(0, 0.31, 1.052), scale=(1, 0.58, 0.68), color=pink)
    f.ring("pilot", 0.224, 0.247, 0.035, 6, loc=(0, 0, 1.16), color="charcoal", arc=(math.pi - 0.2, 2 * math.pi + 0.2))
    for side in (-1, 1):
        f.uv("pilot", 0.06, 6, 3, loc=(side * 0.225, 0.0, 1.135), scale=(0.7, 0.75, 1), color=fur)
        f.ring("pilot", 0.052, 0.076, 0.04, 6, loc=(side * 0.092, 0.195, 1.165), rot=(math.pi / 2, 0, 0), color="copper")
        ex, ey, ez = side * 0.092, 0.218, 1.165
        f.uv("pilot", 0.047, 6, 3, loc=(ex, ey, ez), scale=(1, 0.6, 1.1), color="charcoal")
        f.box("pilot", (0.0235, 0.0141, 0.0235), loc=(ex + 0.0141, ey + 0.04, ez + 0.0165), color="bone")
    f.rod("pilot", (-0.024, 0.212, 1.17), (0.024, 0.212, 1.17), 0.011, 4, color="copper")
    for v in f.bm.verts:
        v.co = (v.co - Vector((0, 0, 1.1))) * 1.2325 + Vector((0, 0.015, 0.17))
    jacket = "bone"
    f.uv("pilot", 0.26, 8, 4, loc=(0, -0.005, -0.17), scale=(1.07, 0.78, 1.0), color=jacket)
    f.uv("pilot", 0.13, 6, 3, loc=(0, 0.035, 0.005), scale=(1.2, 0.75, 0.6), color="bone")
    for side in (-1, 1):
        f.uv("pilot", 0.12, 6, 3, loc=(side * 0.18, 0.18, -0.3), scale=(1, 1.5, 0.85), color="oxide")
        f.rod("pilot", (side * 0.18, 0.2, -0.3), (side * 0.2, 0.38, -0.46), 0.09, 4, color="petrol")
        f.uv("pilot", 0.1, 6, 3, loc=(side * 0.2, 0.45, -0.48), scale=(1, 1.4, 0.6), color="charcoal")
        f.uv("pilot", 0.12, 6, 3, loc=(side * 0.22, 0.005, -0.09), scale=(1.0, 0.85, 1.12), color=jacket)
        f.rod("pilot", (side * 0.24, 0.015, -0.09), (side * 0.36, 0.24, -0.12), 0.09, 4, color=jacket)
        f.rod("pilot", (side * 0.36, 0.24, -0.12), (side * 0.32, 0.4, 0.04), 0.07, 4, color="charcoal")
        f.uv("pilot", 0.075, 6, 3, loc=(side * 0.32, 0.4, 0.05), color="sandstone")
        f.beam("pilot", (side * 0.16, 0.22, -0.25), (side * 0.14, 0.19, 0.06), 0.035, 0.02, color="copper")
    sb._sharpen(f, angle=math.pi)
    return f


def build(variant=False):
    """Builds Rivet's mecha under a new root and returns the hoberman() dict plus drill."""
    saved = (sb.lattice, sb.cockpit, sb.weapon_ring)
    sb.lattice, sb.cockpit, sb.weapon_ring = make_lattice(variant), make_cockpit(variant), make_ring()
    try:
        name = "RivetCalibrated" if variant else "Rivet"
        shell = sb.hoberman(name, enamel=ENAMEL, seat=SEAT, pairs=2, bank=BANK, pilot=pilot(),
                            hub_sides=6, cap_sides=6)
    finally:
        sb.lattice, sb.cockpit, sb.weapon_ring = saved
    ring, pod = shell["ring"], shell["pod"]
    shell["drill"] = drill(variant).to_object((0, DRILL_Y0, DRILL_Z), ring)
    common.empty("DrillTip", (0, DRILL_STEPS[-1][1] + 0.0015, DRILL_Z), ring)
    for tag, point in revolvers.MUZZLES.items():
        common.empty("LaserMuzzle." + tag, point, ring)
    for side, tag in ((-1, "L"), (1, "R")):
        common.empty("Exhaust." + tag, (side * STACK_X, STACK_Y, STACK_TOP + 0.0045), pod)
    return shell


def main():
    common.reset()
    common.preview_class("copper")
    variant = flag("--variant")
    if variant not in (None, "calibrated"):
        raise SystemExit("unknown variant %s" % variant)
    shell = build(variant == "calibrated")
    name = "RivetCalibrated" if variant else "Rivet"
    tris = common.tri_total(shell["root"], skip=(shell["pilot"].name,))
    print("HOBERMAN %s tris=%d core=%d pod=%d ring=%d drill=%d pilot=%d"
          % (name, tris, common.tris(shell["core"]), common.tris(shell["pod"]), common.tris(shell["ring"]),
             common.tris(shell["drill"]), common.tris(shell["pilot"])))
    print("STACK_TOP %.3f (lattice outline %.3f + %.2f)" % (STACK_TOP, STACK_TOP - STACK_RISE, STACK_RISE))
    default = "shell_rivet_calibrated.glb" if variant else "shell_rivet.glb"
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", default)
    sb.finish(name, shell["root"], shell["core"], shell["pilot"], shell_band=SHELL_BAND,
              pod_obj=shell["pod"], out=out)


if __name__ == "__main__":
    main()
