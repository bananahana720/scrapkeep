# PD-RIVET heft layers: shell_rivet_c2.glb to shell_rivet_c5.glb, the detail shells B5's loader
# shows up to the heft class (CUSTOMIZE section 6; ROSTER-LOOK sections 0.3 and 5; pilots/rivet.md
# section 5, "Gap panels across heft classes"). Rivet's panels are raked chevron plates, petrol
# with an oxide chevron (bone at class V), pointing forward. They hang from the upright Pod at the
# rest-pose gap positions the Core's Gap empties mark, outer face at radius 0.915, inside the
# lattice's inner face (0.94), so the struts roll past in front of them.
#   II   six panels in the lower gaps, every vertex below Z -0.36
#   III  the side gaps; a Core part with wider 6-sided tread caps (corners inside 0.985)
#   IV   most remaining gaps; collars round the stack bases
#   V    every remaining non-sight gap; the heavy drill (five steps, lens 0.20 m) on Pod, with
#        Replace.Drill hiding the base drill while the layer shows
# No panel enters the sight cones (rear to the chase eyes, front to the face), the front drill
# gap, the stack brackets or the gimbal bosses. Concept: concepts/codex/rivet/sheet.png (GAP
# PANEL, heft I, III and V) and hero.png.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/shell_rivet_plates.py -- [--outdir <dir>]
#
# Each layer is one surface per part (detail class: 1 draw); class III has two parts and class
# V's Pod carries the heavy drill's copper and lens, so their registry rows carry exceptions.

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import shell_base as sb  # noqa: E402
import shell_rivet as rivet  # noqa: E402
from common import Part  # noqa: E402

PANEL_OUT = 0.915
PANEL_DEPTH = 0.04
PANEL_H = 0.14
STRIPE = 0.6
C2_TOP = -0.36
LAYER_TRIS = 1500
LAYER_VERTS = 3000
# Heavy drill, class V: (y0, y1, r0, r1); the lens at the base drill's tip, so DrillTip still
# marks it. Steps past the collar (y > 1.03) stay under r 0.145 so their tops clear Z -0.075.
HEAVY_STEPS = ((0.88, 0.95, 0.22, 0.21), (0.95, 1.02, 0.19, 0.18), (1.02, 1.08, 0.145, 0.135),
               (1.08, 1.13, 0.125, 0.115), (1.13, 1.18, 0.105, 0.10))
HEAVY_LENS = 0.10
# Wider than the base cap (0.07), so its rim shows round it; the face sits at 0.981 so the hexagon's
# corners stay inside CORE_LIMIT (sqrt(0.981^2 + 0.085^2) = 0.9847).
CAP_THICK = (0.085, 0.950, 0.981)
FRONT_EYES = tuple(Vector((e.x, -e.y, e.z)) for e in sb.CHASE_EYES)
# Keep-out capsules (a, b, radius), Blender axes: the drill, the stacks and their brackets, the
# gimbal bosses.
KEEP_OUT = [((0, 0.80, rivet.DRILL_Z), (0, 1.25, rivet.DRILL_Z), 0.27)]
for _s in (-1, 1):
    KEEP_OUT.append(((_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_BASE - 0.05),
                     (_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_TOP), 0.11))
    KEEP_OUT.append(((_s * rivet.BRACKET_FOOT[0], rivet.BRACKET_FOOT[1], rivet.BRACKET_FOOT[2]),
                     (_s * rivet.STACK_X, rivet.STACK_Y, rivet.STACK_BASE), 0.06))
    KEEP_OUT.append(((_s * 0.76, 0, 0), (_s * 0.92, 0, 0), 0.08))


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


def panel_points(d):
    """The panel's corner points (outer and inner face) for the gap direction d."""
    u, v = frame(d)
    pts = []
    for depth in (PANEL_OUT, PANEL_OUT - PANEL_DEPTH):
        for x, y in outline(PANEL_H):
            pts.append(d * depth + u * x + v * y)
    return pts


def slide_down(d, top):
    """Rotates d toward -Z until every panel point is below top (at most 20 degrees)."""
    for step in range(41):
        pts = panel_points(d)
        if max(p.z for p in pts) < top:
            return d
        axis = d.cross(Vector((0, 0, -1)))
        if axis.length < 1e-6:
            return d
        d = (d * math.cos(math.radians(0.5)) + axis.normalized().cross(d) * math.sin(math.radians(0.5))).normalized()
    return None


def usable(d):
    pts = panel_points(d)
    if any(in_cone(p, sb.CHASE_EYES) or in_cone(p, FRONT_EYES) for p in pts):
        return False
    if any(p.length > sb.LATTICE_INNER - 0.003 for p in pts):
        return False
    return not any(seg_dist(p, a, b) < r for p in pts for a, b, r in KEEP_OUT)


def plan():
    """Assigns gaps to classes. Returns {2: [dirs], 3: [...], 4: [...], 5: [...]}."""
    _, _, gaps = sb.lattice_layout()
    front = 7
    out = {2: [], 3: [], 4: [], 5: []}
    lower = sorted((i for i, g in enumerate(gaps) if g.z < -0.8), key=lambda i: i)
    # The five bottom gaps plus the rear lower one nearest straight behind (chase view).
    rear = min((i for i, g in enumerate(gaps) if -0.6 < g.z < -0.4), key=lambda i: gaps[i].y)
    used = set()
    for i in lower + [rear]:
        d = slide_down(gaps[i].copy(), C2_TOP)
        if d is not None and usable(d):
            out[2].append(d)
            used.add(i)
    for i, g in enumerate(gaps):
        if i in used or i == front:
            continue
        side = abs(g.x) > 0.6 and g.z < 0.6
        if side and usable(g):
            out[3].append(g)
            used.add(i)
    for i, g in enumerate(gaps):
        if i in used or i == front or not usable(g):
            continue
        out[4 if g.z < 0.6 else 5].append(g)
        used.add(i)
    return out


def chevron(part, d, body, stripe):
    u, v = frame(d)
    basis = Matrix((u, v, d)).transposed().to_4x4()
    m = Matrix.Translation(d * (PANEL_OUT - PANEL_DEPTH / 2)) @ basis
    part.prism("paint", outline(PANEL_H), PANEL_DEPTH, matrix=m, color=body)
    ms = Matrix.Translation(d * (PANEL_OUT + 0.003)) @ basis
    part.prism("paint", outline(PANEL_H * STRIPE), 0.012, matrix=ms, color=stripe)


def heavy_drill(p):
    for y0, y1, r0, r1 in HEAVY_STEPS:
        p.cyl("copper", r0, r1, y1 - y0, rivet.DRILL_SIDES, loc=(0, (y0 + y1) / 2, rivet.DRILL_Z), rot=(-math.pi / 2, 0, 0))
    sb._disc(p, (0, HEAVY_STEPS[-1][1] + 0.0025, rivet.DRILL_Z), (0, 1, 0), HEAVY_LENS, 12, "class_accent")


def build(n, dirs):
    common.reset()
    root = common.empty("ShellRivetC%d" % n)
    body, stripe = ("bone", "oxide") if n == 5 else ("petrol", "oxide")
    pod = Part("Pod")
    for d in dirs:
        chevron(pod, d, body, stripe)
    if n == 4:
        z = math.sqrt(sb.LATTICE_INNER ** 2 - rivet.STACK_X ** 2 - rivet.STACK_Y ** 2) - 0.07
        for side in (-1, 1):
            pod.cyl("paint", rivet.STACK_R + 0.02, rivet.STACK_R + 0.02, 0.05, 8,
                    loc=(side * rivet.STACK_X, rivet.STACK_Y, z), color="petrol")
    if n == 5:
        heavy_drill(pod)
    sb._sharpen(pod)
    if n == 3:
        core = Part("Core")
        hubs, _, _ = sb.lattice_layout()
        for d in hubs:
            sb._drum(core, d, CAP_THICK[0], CAP_THICK[1], CAP_THICK[2], 6, "rubber", roll=0.0, bottom=False)
        sb._sharpen(core, angle=1.1)
        core_obj = core.to_object((0, 0, 0), root)
    else:
        core_obj = common.empty("Core", (0, 0, 0), root)
    pod_obj = pod.to_object((0, 0, 0), root)
    if n == 5:
        common.empty("Replace.Drill", (0, 0, 0), pod_obj)
    return root, core_obj, pod_obj


def check(n, root, core_obj, pod_obj, count):
    tris = common.tri_total(root)
    verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
    far = common.max_radius(pod_obj)
    # Everything but the heavy drill (which reaches out through the front gap) stays inside the
    # lattice's inner face.
    panel_far = max(((pod_obj.matrix_world @ v.co).length for v in pod_obj.data.vertices
                     if abs(v.co.x) > 0.3 or v.co.z > 0.0 or v.co.y < 0.8), default=0.0)
    cone = sb.sight_cone_hits(pod_obj)
    low = sb.low_reach(pod_obj)
    core_far = common.max_radius(core_obj) if core_obj.type == "MESH" else 0.0
    top = max((pod_obj.matrix_world @ v.co).z for v in pod_obj.data.vertices)
    ok = tris <= LAYER_TRIS and cone == 0 and low == 0 and core_far <= sb.CORE_LIMIT + 1e-4 and panel_far <= sb.LATTICE_INNER
    if n == 2:
        ok = ok and top < C2_TOP and count == 6
    print("LAYER c%d panels=%d tris=%d verts=%d pod_far=%.3f panel_far=%.3f core_far=%.4f top_z=%.3f cone=%d low=%d %s"
          % (n, count, tris, verts, far, panel_far, core_far, top, cone, low, "ok" if ok else "OUT"))
    return ok


def main():
    common.preview_class("copper")
    outdir = flag("--outdir") or os.path.join(common.MODELS, "world_one")
    layout = plan()
    print("PLAN " + " ".join("c%d:%d" % (n, len(layout[n])) for n in sorted(layout)))
    bad = []
    for n in (2, 3, 4, 5):
        root, core_obj, pod_obj = build(n, layout[n])
        if not check(n, root, core_obj, pod_obj, len(layout[n])):
            bad.append(n)
        common.export(root, os.path.join(outdir, "shell_rivet_c%d.glb" % n))
    if bad:
        raise SystemExit("layer checks failed for classes %s" % bad)


if __name__ == "__main__":
    main()
