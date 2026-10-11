# PD-SABLE (wave 13): Sable's four heft layers, shell_sable_c2.glb to shell_sable_c5.glb, the
# detail shells B5's fit_shell_into mounts under HeftC2..HeftC5 (CUSTOMIZE section 6). Each layer
# has the base's top-level Core and Pod split. Gap panels hang from the upright Pod just inside
# the lattice (outer face radius 0.92, 0.04 m thick, ROSTER-LOOK sections 0.3 and 5) at the
# rest-pose gap centres: small rounded plates, bone face over a charcoal felt lining and edge,
# one paint surface per layer, so the equipped paint carries onto them and the felt stays dark.
#   c2  six panels in the lower gaps, every vertex below Z -0.35
#   c3  the side gaps, plus thicker rubber tread caps on Core (never past radius 0.985): 2 draws
#   c4  every remaining gap; the sight gaps stay open
#   c5  the coil mast's heavy form, the doubled coil: one open copper winding round the same mast,
#       rising to 0.25 m past the lattice. It replaces nothing, so the base CoilMast's mint tip
#       (class_accent, the working device) shows between the turns; one mast, never a second spike.
# Draws (docs/decisions.tsv 2026-10-10, shell cap 16): class III may spend 2, every other layer 1.
# A copper winding and a paint panel are two surfaces, so fix round 2 moved class V's three top
# panels (gaps 1, 2, 4) into c4 and left c5 the winding alone, one copper surface.
# Sight gaps: a panel never puts a vertex inside the 35 degree cone from the head to the chase
# eyes (shell_base.sight_cone_hits) or to the hero front camera, 20 degrees above the ring plane.
# Panels next to the module hubs (Hub.14 mast, Hub.26 spool) are cut back at that corner, so the
# brackets, the spool face and RopeExit stay clear (the class IV horseshoe of pilots/sable.md 5).
# Concept: artifacts/local/alpha/push/w13/concepts/codex/sable/sheet.png (GAP PANEL, heft I/III/V).
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/shell_sable_plates.py -- [--outdir <dir>]

import math
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402
import shell_sable as ss  # noqa: E402

LAYER_TRIS = 1500
PANEL_OUT = 0.92
PANEL_IN = 0.88
PANEL_INSET = 0.64       # fraction of the way from the gap centre to each diamond corner
CHAMFER = 0.22           # corner cut, as a fraction of each outline edge
MODULE_CUT = 0.55        # deeper cut at a corner on a module hub
LOW_Z = -0.35
FRONT_EYE_DIR = Vector((0.0, math.cos(math.radians(20)), math.sin(math.radians(20))))
MODULE_HUBS = (ss.MAST_HUB, ss.SPOOL_HUB)
# Thicker tread caps (class III): 6 sides, radius 0.09, wider than the base caps (0.07); the
# face sits at 0.9806 so the corners stay inside CORE_LIMIT and the base tread shows through.
THICK_CAP = (0.09, 0.950, 0.9806)
# The heavy coil: an open helix round the mast axis from the bracket to 0.25 m past the lattice.
# Coil radius tapers with the base mast steps (0.062 to the 0.028 tip) plus a clear gap; the wire
# is 0.036 m across with about 0.024 m between turns, so the mint tip reads through the coil.
COIL_FROM = 0.985
COIL_TOP = ss.LATTICE_OUT + 0.25
COIL_END = COIL_TOP - 0.018   # helix centreline end; the wire and its last turn's offset reach COIL_TOP
COIL_RADIUS = (0.088, 0.044)
COIL_WIRE = 0.018
COIL_TURNS = 4
COIL_SEGS = 10           # per turn


def diamonds():
    """Per gap: (index, centre direction, [four corner hub indices in ring order])."""
    hubs, links, gaps = sb.lattice_layout()
    five_of = {}
    for v, f in links:
        five_of.setdefault(f, set()).add(v)
    out = []
    for g, d in enumerate(gaps):
        near5 = sorted(range(12), key=lambda i: -hubs[i].dot(d))[:2]
        threes = [f for f, vs in five_of.items() if set(near5) <= vs]
        i, j = near5
        a, b = threes[:2]
        out.append((g, d, [i, a, j, b]))
    return hubs, out


def outline(hubs, d, corners, inset=PANEL_INSET):
    """The rounded panel outline: each diamond corner pulled toward the centre, then chamfered
    (deeper at a module hub). Returns unit directions in ring order."""
    pts = [sb._slerp(d, hubs[c].normalized(), inset) for c in corners]
    ring = []
    for k, c in enumerate(corners):
        cut = MODULE_CUT if c in MODULE_HUBS else CHAMFER
        prev, here, nxt = pts[k - 1], pts[k], pts[(k + 1) % 4]
        ring.append((here + (prev - here) * cut).normalized())
        ring.append((here + (nxt - here) * cut).normalized())
    return ring


def panel(p, d, ring):
    """A shallow domed plate: bone face (fan from a centre vertex), charcoal felt back and edge."""
    bm = p.bm
    n = len(ring)
    out = [bm.verts.new(v * PANEL_OUT) for v in ring]
    inn = [bm.verts.new(v * PANEL_IN) for v in ring]
    co = bm.verts.new(d * (PANEL_OUT + 0.004))
    ci = bm.verts.new(d * PANEL_IN)
    face = [bm.faces.new((co, out[k], out[(k + 1) % n])) for k in range(n)]
    back = [bm.faces.new((ci, inn[(k + 1) % n], inn[k])) for k in range(n)]
    edge = [bm.faces.new((out[k], inn[k], inn[(k + 1) % n], out[(k + 1) % n])) for k in range(n)]
    for f in face:
        if f.normal.dot(d) < 0:
            f.normal_flip()
    for f in back:
        if f.normal.dot(d) > 0:
            f.normal_flip()
    p.paint(face, "paint", "bone")
    p.paint(back + edge, "paint", "charcoal")


def in_cones(points):
    head = sb.HEAD
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    axes = [(e - head).normalized() for e in sb.CHASE_EYES] + [FRONT_EYE_DIR]
    for q in points:
        v = q - head
        if v.length < 1e-6:
            continue
        v.normalize()
        if any(v.dot(a) > cos_half for a in axes):
            return True
    return False


def plan():
    """Assigns each non-sight gap to a class. Returns ({class: [(gap, d, ring)]}, sight gaps)."""
    hubs, rows = diamonds()
    usable, sight = [], []
    for g, d, corners in rows:
        ring = outline(hubs, d, corners)
        pts = [v * PANEL_OUT for v in ring] + [v * PANEL_IN for v in ring]
        if in_cones(pts):
            sight.append(g)
        else:
            usable.append((g, d, corners, ring))
    usable.sort(key=lambda r: r[1].z)
    layers = {2: [], 3: [], 4: [], 5: []}
    rest = []
    for g, d, corners, ring in usable:
        inset = PANEL_INSET
        ring_low = ring
        while max(v.z * r for v in ring_low for r in (PANEL_OUT, PANEL_IN)) >= LOW_Z and inset > 0.3:
            inset -= 0.04
            ring_low = outline(hubs, d, corners, inset)
        if len(layers[2]) < 6 and max(v.z * r for v in ring_low for r in (PANEL_OUT, PANEL_IN)) < LOW_Z:
            layers[2].append((g, d, ring_low))
        else:
            rest.append((g, d, ring))
    for g, d, ring in rest:
        if abs(d.x) >= 0.5 and d.z <= 0.1:
            layers[3].append((g, d, ring))
        else:
            layers[4].append((g, d, ring))
    return layers, sight


def heavy_coil(p):
    """The doubled coil on the Pod: one copper helix round MAST_DIR, open between turns."""
    axis = ss.MAST_DIR
    u = axis.cross(Vector((0.0, 1.0, 0.0))).normalized()
    v = axis.cross(u).normalized()
    steps = COIL_TURNS * COIL_SEGS
    pts = []
    for k in range(steps + 1):
        t = k / steps
        a = t * COIL_TURNS * math.tau
        rad = COIL_RADIUS[0] + (COIL_RADIUS[1] - COIL_RADIUS[0]) * t
        along = COIL_FROM + (COIL_END - COIL_FROM) * t
        pts.append(axis * along + (u * math.cos(a) + v * math.sin(a)) * rad)
    for a, b in zip(pts, pts[1:]):
        p.rod("copper", a, b, COIL_WIRE, 4)


def thick_caps(rng):
    c = Part("Core")
    hubs, _, _ = sb.lattice_layout()
    for d in hubs:
        sb._drum(c, d, THICK_CAP[0], THICK_CAP[1], THICK_CAP[2], 6, "rubber", roll=rng.uniform(0, math.tau), bottom=False)
    sb._sharpen(c)
    return c


def build_layer(n, panels, outdir):
    common.reset()
    root = common.empty("ShellSableC%d" % n)
    core_obj = thick_caps(sb.rng_for("sable-c3")).to_object((0, 0, 0), root) if n == 3 else common.empty("Core", (0, 0, 0), root)
    p = Part("Pod")
    for _, d, ring in panels:
        panel(p, d, ring)
    if n == 5:
        heavy_coil(p)
    sb._sharpen(p)
    pod_obj = p.to_object((0, 0, 0), root)
    reach = max((pod_obj.matrix_world @ v.co).length for v in pod_obj.data.vertices)
    tris = common.tri_total(root)
    low = sb.low_reach(pod_obj)
    cone = sb.sight_cone_hits(pod_obj)
    core_r = common.max_radius(core_obj) if core_obj.type == "MESH" else 0.0
    top = max((pod_obj.matrix_world @ v.co).z for v in pod_obj.data.vertices)
    draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
    ok = tris <= LAYER_TRIS and low == 0 and cone == 0 and core_r <= sb.CORE_LIMIT + 1e-4
    ok = ok and draws <= (2 if n == 3 else 1)
    if n == 2:
        ok = ok and top < LOW_Z
    if n == 5:
        ok = ok and not panels and abs(reach - COIL_TOP) <= 0.01
    print("LAYER c%d panels=%d gaps=%s tris=%d draws=%d core_radius=%.4f pod_top_z=%.3f pod_reach=%.3f low=%d cone=%d %s"
          % (n, len(panels), [g for g, _, _ in panels], tris, draws, core_r, top, reach, low, cone, "ok" if ok else "OUT"))
    common.export(root, os.path.join(outdir, "shell_sable_c%d.glb" % n))
    return ok


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = argv[argv.index("--outdir") + 1] if "--outdir" in argv else os.path.join(common.MODELS, "world_one")
    layers, sight = plan()
    print("SIGHT gaps left open: %s" % sight)
    bad = [n for n in (2, 3, 4, 5) if not build_layer(n, layers[n], outdir)]
    if len(layers[2]) != 6:
        bad.append("c2 has %d panels, want 6" % len(layers[2]))
    if bad:
        raise SystemExit("layer checks failed: %s" % bad)


main()
