"""The Cannon's heft layers (wave 13, unit PD-CANNON): seamless verdigris carapace panels that
fill the lattice gaps from the bottom up, one detail shell per heft class.

Concept: artifacts/local/alpha/push/w13/concepts/codex/cannon/sheet.png (GAP PANEL; heft I, III
and V) and hero.png; design: ROSTER-LOOK sections 0.3, 2 and 5, pilots/cannon.md section 5.

  blender --background --threads 2 --python-exit-code 1 \
    --python world_one/shell_cannon_plates.py -- [--outdir <dir>] [--count-only]
under prlimit's 12 GiB address-space cap (tools/blender/PILOT-RIG.md:72).

Writes world_one/shell_cannon_c2.glb to shell_cannon_c5.glb. Each layer has the base's Core and
Pod split (CUSTOMIZE section 6): Pod is an empty holding one mesh, Carapace, on ancient_enamel
(one draw), whose origin sits at the panels' centre so hero_assets slams it in from that side.
Class III adds Core > TreadCollars, the thicker rubber tread caps (a second draw, the registry
exception ROSTER-LOOK section 5 names).

  II   panels in the lower gaps, every vertex below Z -0.35
  III  the side gaps, and the thicker tread caps on every hub
  IV   most of the rest; the crown stays open
  V    every gap but the sight gaps, and the heavy forms of the split ports and the rush ring
Not built: the barrel-borne scrap of pilots/cannon.md section 5 (II muzzle brake, III breech
jacket, IV skirt from the bearing collar). It must yaw with WeaponRing, and a layer mounts only
Core and Pod (C4); on Pod it would leave the barrel and enter the ring's sweep.
No panel ever fills a sight gap: the gaps on the 35 degree cone from the pilot's head to the
chase eyes and to the front eyes stay open at every class. Panels hang inside the lattice
(outer face 0.92 to 0.93, inner 0.89), outside the gimbal sweep (0.862), so none can enter the
weapon ring's or the barrel's sweep; the recipe checks both anyway.
"""
import math
import os
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))
import common  # noqa: E402
from common import Part  # noqa: E402
import shell_base as sb  # noqa: E402
import shell_cannon as sc  # noqa: E402

OUTDIR = HERE.parents[2] / "assets/models/world_one"
LAYER_TRIS = 1500
LAYER_VERTS = 3000
# Panel radii (ROSTER-LOOK section 2: outer face 0.92 just inside the lattice's 0.94 inner face).
R_OUT = 0.92
R_TOP = 0.928      # the raised cast plateau
R_IN = 0.89        # inner face; its chords stay outside the gimbal sweep
GIMBAL_CLEAR = sb.GIMBAL_OUTER[1] + 0.003
# Corner pull toward the gap centre (gnomonic plane): five-way tips, three-way tips, tip clip.
K5, K3, CLIP = 0.58, 0.74, 0.24
PLATEAU = 0.72
FRONT_EYES = tuple(Vector((e.x, -e.y, e.z)) for e in sb.CHASE_EYES)
# Verdigris under the section 11 enamel cap (HSV value and saturation at most 0.45).
VERDIGRIS = "47736a"
RIM = common.mix(VERDIGRIS, "charcoal", 0.30)
BACK = common.mix(VERDIGRIS, "charcoal", 0.50)
DUST = common.mix(VERDIGRIS, "736b5a", 0.35)
CLASSES = (2, 3, 4, 5)
# Heavy forms at class V: a cast sleeve round each split port, a cast guard round the rush ring.
GUARD = (sc.RUSH[1] + 0.014, sc.RUSH[1] + 0.036, 0.05, sc.RUSH[3] - 0.015)
COLLAR = (0.072, 0.094, 0.950, 0.979)  # tread collar r_in, r_out, low, high (under CORE_LIMIT)


def flag(name):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return None
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def gap_corners(g, hubs):
    """The two five-way hubs and the two three-way hubs that bound the gap at direction g."""
    five = sorted(range(12), key=lambda i: g.angle(hubs[i]))[:2]
    three = sorted(range(12, 32), key=lambda i: g.angle(hubs[i]))[:2]
    return [hubs[i] for i in five], [hubs[i] for i in three]


def outline(g, hubs):
    """Six unit directions of a hexagonal panel: the diamond pulled in, its five-way tips clipped."""
    (a, b), (c, d) = gap_corners(g, hubs)
    e1, e2 = sb._frame(g)

    def proj(v):
        w = v / v.dot(g) - g
        return Vector((w.dot(e1), w.dot(e2)))
    pa, pb, pc, pd = proj(a) * K5, proj(b) * K5, proj(c) * K3, proj(d) * K3
    ring = [pa.lerp(pc, CLIP), pc, pb.lerp(pc, CLIP), pb.lerp(pd, CLIP), pd, pa.lerp(pd, CLIP)]
    return [(g + e1 * p.x + e2 * p.y).normalized() for p in ring], g


def panel_points(dirs, g):
    """Vertex positions of one panel: outer rim, plateau, plateau centre, back ring, back centre."""
    plate = [d.lerp(g, 1 - PLATEAU).normalized() for d in dirs]
    return ([d * R_OUT for d in dirs], [d * R_TOP for d in plate], g * R_TOP,
            [d * R_IN for d in dirs], g * R_IN)


def add_panel(part, dirs, g, rng):
    rim, top, centre, back, back_c = panel_points(dirs, g)
    bm = part.bm
    vr = [bm.verts.new(p) for p in rim]
    vt = [bm.verts.new(p) for p in top]
    vc = bm.verts.new(centre)
    vb = [bm.verts.new(p) for p in back]
    vbc = bm.verts.new(back_c)
    rims, tops, backs, sides = [], [], [], []
    for i in range(6):
        j = (i + 1) % 6
        rims.append(bm.faces.new((vr[i], vr[j], vt[j], vt[i])))
        tops.append(bm.faces.new((vt[i], vt[j], vc)))
        backs.append(bm.faces.new((vb[j], vb[i], vbc)))
        sides.append(bm.faces.new((vb[i], vb[j], vr[j], vr[i])))
    face = common.mix(VERDIGRIS, "petrol", rng.uniform(0.0, 0.25)) if g.z < 0.3 else DUST
    part.paint(rims, "ancient_enamel", RIM)
    part.paint(tops, "ancient_enamel", face)
    part.paint(backs + sides, "ancient_enamel", BACK)
    return rims + tops + backs + sides


def in_cones(p, eyes_sets):
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    d = p - sb.HEAD
    if d.length < 1e-6:
        return False
    d.normalize()
    return any(d.dot((e - sb.HEAD).normalized()) > cos_half for eyes in eyes_sets for e in eyes)


def classify(hubs, gaps):
    """{class: [gap index]} and the sight gaps, from each panel's own vertices."""
    out = {n: [] for n in CLASSES}
    sight = []
    for i, g in enumerate(gaps):
        dirs, g = outline(g, hubs)
        rim, top, centre, back, back_c = panel_points(dirs, g)
        pts = rim + top + [centre] + back + [back_c]
        if any(in_cones(p, (sb.CHASE_EYES, FRONT_EYES)) for p in pts):
            sight.append(i)
            continue
        top_z = max(p.z for p in pts)
        if top_z < -0.35:
            out[2].append(i)
        elif abs(g.x) >= abs(g.y) and top_z < 0.55:
            out[3].append(i)
        elif g.z < 0.70:
            out[4].append(i)
        else:
            out[5].append(i)
    return out, sight


def tread_collars(hubs):
    """Class III: a wider rubber tread round every hub cap, outer side and top only."""
    p = Part("TreadCollars")
    r_in, r_out, lo, hi = COLLAR
    for h in hubs:
        e1, e2 = sb._frame(h)
        ring = [math.cos(k * math.tau / 6 + 0.26) * e1 + math.sin(k * math.tau / 6 + 0.26) * e2 for k in range(6)]
        ti = [p.bm.verts.new(h * hi + r_in * q) for q in ring]
        to = [p.bm.verts.new(h * hi + r_out * q) for q in ring]
        bo = [p.bm.verts.new(h * lo + r_out * q) for q in ring]
        faces = []
        for k in range(6):
            j = (k + 1) % 6
            faces.append(p.bm.faces.new((ti[k], ti[j], to[j], to[k])))
            faces.append(p.bm.faces.new((to[k], to[j], bo[j], bo[k])))
        p.paint(faces, "rubber")
    sb._sharpen(p)
    return p


def heavy_forms(part):
    """Class V: a cast hood over each split port (a top slab and an outer lip), standing the port
    0.20 m past the lattice and staying above Z -0.6, and a cast guard ring round the rush ring."""
    for side in (1, -1):
        c, n, f, u = sc.port_axes(side)
        rad, fwd, up = sc.PORT_SIZE
        length = fwd + 0.06
        sc.oriented_box(part, "ancient_enamel", c + u * (up / 2 + 0.016) + n * 0.03, (n, f, u),
                        (rad + 0.10, length, 0.026), RIM)
        sc.oriented_box(part, "ancient_enamel", c + n * (rad / 2 + 0.065) + u * 0.05, (n, f, u),
                        (0.026, length, up / 2 + 0.04), VERDIGRIS)
    r_in, r_out, depth, z = GUARD
    part.ring("ancient_enamel", r_in, r_out, depth, 12, loc=(0, 0, z), color=RIM)


def build_layer(n, panels, hubs, gaps, rng):
    """One layer's root, Pod and the panel vertex positions (for the rush-ring check)."""
    root = common.empty("ShellCannonC%d" % n)
    core = common.empty("Core", (0, 0, 0), root)
    if n == 3:
        tread_collars(hubs).to_object((0, 0, 0), core)
    pod = common.empty("Pod", (0, 0, 0), root)
    part = Part("Carapace%d" % n)
    centre = Vector()
    points = []
    for i in panels:
        dirs, g = outline(gaps[i], hubs)
        add_panel(part, dirs, g, rng)
        rim, top, c, back, back_c = panel_points(dirs, g)
        points += rim + top + [c] + back + [back_c]
        centre += g
    if n == 5:
        heavy_forms(part)
    part.bm.normal_update()
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    sb._sharpen(part)
    part.to_object(centre / max(len(panels), 1) * R_OUT, pod)
    bpy.context.view_layer.update()
    return root, pod, points


def rush_reach():
    """Largest angle from straight down that the rush ring and its class V guard cover."""
    return math.degrees(math.atan2(GUARD[1], -(GUARD[3] + GUARD[2] / 2)))


def nearest(pod):
    """Closest approach to the ball centre over every vertex and edge midpoint under pod."""
    best = 9.0
    for o in common.tree(pod):
        if o.type != "MESH":
            continue
        mw = o.matrix_world
        vs = [mw @ v.co for v in o.data.vertices]
        best = min([best] + [v.length for v in vs]
                   + [((vs[e.vertices[0]] + vs[e.vertices[1]]) / 2).length for e in o.data.edges])
    return best


def check(n, root, pod, points, bins, count):
    tris = common.tri_total(root)
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    draws = sum(len(o.data.materials) for o in meshes)
    cone = sb.sight_cone_hits(pod)
    front = sb.sight_cone_hits(pod, eyes=FRONT_EYES)
    sweep = sc.sweep_hits(pod, bins)
    low = sb.low_reach(pod)
    inner = nearest(pod)
    outer = max(p.length for p in points)
    down = min(math.degrees(Vector((0, 0, -1)).angle(p)) for p in points)
    core_far = max((common.max_radius(o) for o in meshes if o.parent is not None
                    and o.parent.name == "Core"), default=0.0)
    rush = rush_reach()
    print("LAYER c%d panels %d tris %d draws %d sight %d front %d sweep %d low %d nearest %.3f "
          "panel_outer %.3f core %.4f down %.1f (rush %.1f)"
          % (n, count, tris, draws, cone, front, sweep, low, inner, outer, core_far, down, rush))
    return (count > 0 and tris <= LAYER_TRIS and draws == (2 if n == 3 else 1) and cone == 0 and front == 0
            and sweep == 0 and low == 0 and inner >= GIMBAL_CLEAR and outer <= sb.LATTICE_INNER - 0.005
            and core_far <= sb.CORE_LIMIT + 1e-4 and down >= rush + 1.0)


def remove(root):
    for o in reversed(common.tree(root)):
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    common.reset()
    base = sc.build_shell("")
    bins = sc.sweep_bins(base["ring"], base["barrel"])
    # Object names are global in Blender: the base's Core and Pod go before a layer takes them.
    remove(base["root"])
    hubs, _, gaps = sb.lattice_layout()
    classes, sight = classify(hubs, gaps)
    print("PLATES sight gaps %s" % sight)
    for n in CLASSES:
        print("PLATES class %d gaps %s" % (n, classes[n]))
    rng = sb.rng_for("Cannon-plates")
    outdir = flag("--outdir") or str(OUTDIR)
    bad = []
    for n in CLASSES:
        root, pod, points = build_layer(n, classes[n], hubs, gaps, rng)
        if not check(n, root, pod, points, bins, len(classes[n])):
            bad.append(n)
        elif not flag("--count-only"):
            common.export(root, os.path.join(outdir, "shell_cannon_c%d.glb" % n))
        remove(root)
    if bad:
        raise SystemExit("cannon layers out of contract, not written: %s" % bad)


if __name__ == "__main__":
    main()
