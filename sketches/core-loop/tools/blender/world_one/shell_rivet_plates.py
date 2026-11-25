import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Quaternion, Vector

import common
import shell_base as sb
import shell_rivet as rivet
from common import Part

PANEL_OUT = 0.915
PANEL_DEPTH = 0.04
PANEL_H = 0.14
STRIPE = 0.6
C2_TOP = -0.36
LAYER_TRIS = 1500
LAYER_VERTS = 3000
FRONT_GAP = 7
SCALES = (1.0, 0.85, 0.7, 0.55)
SLIDES = (0, 2, 4, 6, 8, 10)
TOWARD = 8
CAP_THICK = (0.085, 0.950, 0.981)
TREAD_H = 0.03
TREAD_PROUD = 0.003
FRONT_EYES = tuple(Vector((e.x, -e.y, e.z)) for e in sb.CHASE_EYES)
HEAVY_STEPS = ((0.87, 0.97, 0.21, 0.195), (0.97, 1.02, 0.18, 0.165), (1.02, 1.09, 0.14, 0.13),
               (1.09, 1.14, 0.125, 0.115))
HEAVY_LENS = (1.14, 1.184, 0.064, 0.105, 0.004)
HEAVY_SIDES = 10
RING_CLEAR = ((sb.RING_BAND[0], sb.RING_BAND[1], sb.RING_BAND[3] - sb.RING_BAND[2] / 2 - 0.006,
               sb.RING_BAND[3] + sb.RING_BAND[2] / 2 + 0.006),
              (sb.RING_COLLAR[0], sb.RING_COLLAR[1], sb.RING_COLLAR[3] - sb.RING_COLLAR[2] / 2,
               sb.RING_COLLAR[3] + sb.RING_COLLAR[2] / 2))
_REAR = min(rivet.DRILL_Y0, HEAVY_STEPS[0][0])
_WIDE = max(rivet.DRILL_STEPS[0][2], HEAVY_STEPS[0][2])
SWEEP_R = _REAR - 0.02
SWEEP_Z = (rivet.DRILL_Z - _WIDE - 0.02, rivet.DRILL_Z + _WIDE + 0.02)
KEEP_OUT = []
for _s in (-1, 1):
    KEEP_OUT.append(("stack", (_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_BASE - 0.05),
                     (_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_TOP), 0.11))
    KEEP_OUT.append(("bracket", (_s * rivet.BRACKET_FOOT[0], rivet.BRACKET_FOOT[1], rivet.BRACKET_FOOT[2]),
                     (_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_BASE), 0.06))
    KEEP_OUT.append(("gimbal boss", (_s * 0.76, 0, 0), (_s * 0.92, 0, 0), 0.08))
ALLOWED_OPEN = ("front drill gap", "sight cone")


def flag(name, default=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return default
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def in_cone(p, eyes):
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    d = p - sb.HEAD
    if d.length < 1e-6:
        return False
    d.normalize()
    return any(d.dot((e - sb.HEAD).normalized()) > cos_half for e in eyes)


def frame(d):
    """Tangent frame at gap direction d: u toward the front (+Y) so the chevron points forward;
    straight down for gaps facing front or back."""
    front = Vector((0, 1, 0))
    u = front - d * front.dot(d)
    if u.length < 0.2:
        u = Vector((0, 0, -1)) - d * (-d.z)
    u.normalize()
    return u, d.cross(u).normalized()


def outline(h):
    return [(h, 0.0), (-h, 0.9 * h), (-0.35 * h, 0.0), (-h, -0.9 * h)]


def panel_points(d, h=PANEL_H):
    """The panel's corner points (outer and inner face) for the gap direction d."""
    u, v = frame(d)
    pts = []
    for depth in (PANEL_OUT, PANEL_OUT - PANEL_DEPTH):
        for x, y in outline(h):
            pts.append(d * depth + u * x + v * y)
    return pts


def slide_down(d, top, h=PANEL_H):
    """Rotates d toward -Z until every panel point is below top (at most 20 degrees)."""
    for step in range(41):
        pts = panel_points(d, h)
        if max(p.z for p in pts) < top:
            return d
        axis = d.cross(Vector((0, 0, -1)))
        if axis.length < 1e-6:
            return d
        d = (d * math.cos(math.radians(0.5)) + axis.normalized().cross(d) * math.sin(math.radians(0.5))).normalized()
    return None


def hits(pts, top=None):
    """Names every keep-out the panel points touch; empty when the panel fits."""
    out = set()
    if any(in_cone(p, sb.CHASE_EYES) or in_cone(p, FRONT_EYES) for p in pts):
        out.add("sight cone")
    if any(p.length > sb.LATTICE_INNER - 0.003 for p in pts):
        out.add("lattice")
    if any(Vector((p.x, p.y)).length > SWEEP_R and SWEEP_Z[0] < p.z < SWEEP_Z[1] for p in pts):
        out.add("drill sweep")
    for reason, a, b, r in KEEP_OUT:
        if any(seg_dist(p, a, b) < r for p in pts):
            out.add(reason)
    if top is not None and max(p.z for p in pts) >= top:
        out.add("above Z %.2f" % top)
    return out


def fit(g, top=None):
    """Places a panel in the gap at direction g: the largest size, then the smallest slide (up to
    10 degrees, eight ways round) that touches no keep-out. Returns (d, h, None) or
    (None, None, reasons at full size, centred)."""
    t1, t2 = sb._frame(g)
    for scale in SCALES:
        h = PANEL_H * scale
        for deg in SLIDES:
            ways = [Vector((0, 0, 0))] if deg == 0 else [
                t1 * math.cos(k * math.tau / TOWARD) + t2 * math.sin(k * math.tau / TOWARD) for k in range(TOWARD)]
            for w in ways:
                d = g.copy() if deg == 0 else (Quaternion(g.cross(w).normalized(), math.radians(deg)) @ g).normalized()
                if not hits(panel_points(d, h), top):
                    return d, h, None
    return None, None, sorted(hits(panel_points(g), top))


def plan():
    """Assigns gaps to classes. Returns ({2: [(d, h)], 3: [...], 4: [...], 5: [...]}, open) where
    open maps a gap index to the reasons it stays open."""
    _, _, gaps = sb.lattice_layout()
    out = {2: [], 3: [], 4: [], 5: []}
    open_gaps = {FRONT_GAP: ["front drill gap"]}
    lower = [i for i, g in enumerate(gaps) if g.z < -0.8]
    rear = min((i for i, g in enumerate(gaps) if -0.6 < g.z < -0.4), key=lambda i: gaps[i].y)
    used = set(open_gaps)
    for i in lower + [rear]:
        start = slide_down(gaps[i].copy(), C2_TOP) or gaps[i]
        d, h, why = fit(start, C2_TOP)
        if d is not None:
            out[2].append((d, h))
            used.add(i)
    for i, g in enumerate(gaps):
        if i in used or not (abs(g.x) > 0.6 and g.z < 0.6):
            continue
        d, h, why = fit(g)
        if d is not None:
            out[3].append((d, h))
            used.add(i)
    for i, g in enumerate(gaps):
        if i in used:
            continue
        d, h, why = fit(g)
        if d is None:
            centre = g * PANEL_OUT
            sight = in_cone(centre, sb.CHASE_EYES) or in_cone(centre, FRONT_EYES)
            open_gaps[i] = (["sight cone"] if sight else []) + [w for w in why if w != "sight cone" or not sight]
            continue
        out[4].append((d, h))
        used.add(i)
    return out, open_gaps


def chevron(part, d, h, body, stripe):
    u, v = frame(d)
    basis = Matrix((u, v, d)).transposed().to_4x4()
    m = Matrix.Translation(d * (PANEL_OUT - PANEL_DEPTH / 2)) @ basis
    part.prism("paint", outline(h), PANEL_DEPTH, matrix=m, color=body)
    ms = Matrix.Translation(d * (PANEL_OUT + 0.003)) @ basis
    part.prism("paint", outline(h * STRIPE), 0.012, matrix=ms, color=stripe)


def tread(part, n):
    """The class III chevron tread: a raised rubber chevron on a wide cap's face."""
    e1, e2 = sb._frame(n)
    basis = Matrix((e1, e2, n)).transposed().to_4x4()
    m = Matrix.Translation(n * (CAP_THICK[2] + TREAD_PROUD / 2)) @ basis
    part.prism("rubber", outline(TREAD_H), TREAD_PROUD, matrix=m)


def heavy_drill():
    """The class V drill module: five copper steps over the base drill, the last a thick annulus
    whose front face is the 0.20 m lens round the base drill's glowing lens."""
    w = Part("WeaponRing")
    for y0, y1, r0, r1 in HEAVY_STEPS:
        w.cyl("copper", r0, r1, y1 - y0, HEAVY_SIDES, loc=(0, (y0 + y1) / 2, rivet.DRILL_Z), rot=(-math.pi / 2, 0, 0))
    y0, y1, r_in, r_out, taper = HEAVY_LENS
    w.ring("copper", r_in, r_out, y1 - y0, HEAVY_SIDES, loc=(0, (y0 + y1) / 2, rivet.DRILL_Z),
           rot=(-math.pi / 2, 0, 0), taper=taper)
    sb._sharpen(w)
    return w


def build(n, panels):
    common.reset()
    root = common.empty("ShellRivetC%d" % n)
    if n == 5:
        core_obj = common.empty("Core", (0, 0, 0), root)
        pod_obj = common.empty("Pod", (0, 0, 0), root)
        heavy_drill().to_object((0, 0, 0), pod_obj)
        return root, core_obj, pod_obj
    body, stripe = "petrol", "oxide"
    pod = Part("Pod")
    for d, h in panels:
        chevron(pod, d, h, body, stripe)
    if n == 4:
        z = math.sqrt(sb.LATTICE_INNER ** 2 - rivet.STACK_X ** 2 - rivet.STACK_Y ** 2) - 0.07
        for side in (-1, 1):
            pod.cyl("paint", rivet.STACK_R + 0.02, rivet.STACK_R + 0.02, 0.05, 8,
                    loc=(side * rivet.STACK_X, rivet.STACK_Y, z), color="petrol")
    sb._sharpen(pod)
    if n == 3:
        core = Part("Core")
        hubs, _, _ = sb.lattice_layout()
        for d in hubs:
            sb._drum(core, d, CAP_THICK[0], CAP_THICK[1], CAP_THICK[2], 6, "rubber", roll=0.0, bottom=False)
            tread(core, d)
        sb._sharpen(core, angle=1.1)
        core_obj = core.to_object((0, 0, 0), root)
    else:
        core_obj = common.empty("Core", (0, 0, 0), root)
    pod_obj = pod.to_object((0, 0, 0), root)
    return root, core_obj, pod_obj


def check_drill(root, pod_obj):
    """Class V: one mesh, WeaponRing under Pod, inside the drill sweep band, clear of the ring band
    and collar, the lens face centred on DrillTip and 0.20 m across."""
    tris = common.tri_total(root)
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    verts = sum(len(o.data.vertices) for o in meshes)
    ring = meshes[0] if len(meshes) == 1 else None
    pts = [ring.matrix_world @ v.co for v in ring.data.vertices] if ring else []
    outside = sum(1 for p in pts if not (Vector((p.x, p.y)).length > SWEEP_R and SWEEP_Z[0] < p.z < SWEEP_Z[1]))
    clash = sum(1 for p in pts for r_in, r_out, z0, z1 in RING_CLEAR
                if r_in <= Vector((p.x, p.y)).length <= r_out and z0 <= p.z <= z1)
    front = max((p.y for p in pts), default=0.0)
    face = [p for p in pts if p.y > front - 1e-4]
    centre = sum(face, Vector()) / max(1, len(face))
    tip = Vector((0, rivet.DRILL_STEPS[-1][1] + 0.0015, rivet.DRILL_Z))
    across = 2 * max((Vector((p.x, p.z - rivet.DRILL_Z)).length for p in face), default=0.0)
    steps = len(HEAVY_STEPS) + 1
    ok = (ring is not None and ring.name == "WeaponRing" and ring.parent == pod_obj and tris <= LAYER_TRIS
          and verts <= LAYER_VERTS and len(ring.data.materials) == 1 and outside == 0 and clash == 0
          and (centre - tip).length < 0.01 and abs(across - 0.20) < 0.006)
    print("LAYER c5 drill steps=%d tris=%d verts=%d slots=%d outside_sweep=%d ring_clash=%d lens_to_tip=%.4f lens_across=%.3f %s"
          % (steps, tris, verts, len(ring.data.materials) if ring else 0, outside, clash, (centre - tip).length, across,
             "ok" if ok else "OUT"))
    return ok


def check(n, root, core_obj, pod_obj, panels):
    if n == 5:
        return check_drill(root, pod_obj)
    tris = common.tri_total(root)
    verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
    far = common.max_radius(pod_obj)
    cone = sb.sight_cone_hits(pod_obj)
    low = sb.low_reach(pod_obj)
    core_far = common.max_radius(core_obj) if core_obj.type == "MESH" else 0.0
    top = max((pod_obj.matrix_world @ v.co).z for v in pod_obj.data.vertices)
    swept = sum(1 for v in pod_obj.data.vertices if (pod_obj.matrix_world @ v.co).length > 0.85
                and hits([pod_obj.matrix_world @ v.co]) & {"drill sweep"})
    ok = (tris <= LAYER_TRIS and verts <= LAYER_VERTS and cone == 0 and low == 0 and swept == 0
          and core_far <= sb.CORE_LIMIT + 1e-4 and far <= sb.LATTICE_INNER)
    if n == 2:
        ok = ok and top < C2_TOP and len(panels) == 6
    small = sum(1 for _, h in panels if h < PANEL_H - 1e-6)
    print("LAYER c%d panels=%d (shrunk %d) tris=%d verts=%d pod_far=%.3f core_far=%.4f top_z=%.3f cone=%d low=%d swept=%d %s"
          % (n, len(panels), small, tris, verts, far, core_far, top, cone, low, swept, "ok" if ok else "OUT"))
    return ok


def main():
    common.preview_class("copper")
    outdir = flag("--outdir") or os.path.join(common.MODELS, "world_one")
    layout, open_gaps = plan()
    print("PLAN " + " ".join("c%d:%d" % (n, len(layout[n])) for n in sorted(layout))
          + " paneled:%d open:%d" % (sum(len(v) for v in layout.values()), len(open_gaps)))
    _, _, gaps = sb.lattice_layout()
    for i in sorted(open_gaps):
        g = gaps[i]
        print("OPEN Gap.%02d at (%.2f, %.2f, %.2f): %s" % (i, g.x, g.y, g.z, ", ".join(open_gaps[i])))
    bad = [i for i, why in open_gaps.items() if why[0] not in ALLOWED_OPEN]
    if bad:
        raise SystemExit("gaps open for a reason other than the drill or a sight cone: %s" % sorted(bad))
    for n in (2, 3, 4, 5):
        root, core_obj, pod_obj = build(n, layout[n])
        if not check(n, root, core_obj, pod_obj, layout[n]):
            bad.append(n)
        common.export(root, os.path.join(outdir, "shell_rivet_c%d.glb" % n))
    if bad:
        raise SystemExit("layer checks failed for classes %s" % bad)


if __name__ == "__main__":
    main()
