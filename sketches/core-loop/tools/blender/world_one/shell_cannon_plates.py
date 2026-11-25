"""The Cannon's heft layers (wave 13, unit PD-CANNON): seamless verdigris carapace panels that
fill the lattice gaps from the bottom up, one detail shell per heft class.

Concept: artifacts/local/alpha/push/w13/concepts/codex/cannon/sheet.png (GAP PANEL; heft I, III
and V) and hero.png; design: ROSTER-LOOK sections 0.3, 2 and 5, pilots/cannon.md section 5.

  blender --background --threads 2 --python-exit-code 1 \
    --python world_one/shell_cannon_plates.py -- [--outdir <dir>] [--count-only] [--ring-scrap]
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
The barrel-borne scrap of pilots/cannon.md section 5 (II muzzle brake, III breech jacket, IV
skirt from the bearing collar) is built on PD-0b's WeaponRing layer route (Pod > WeaponRing in a
layer GLB rides the base ring and yaws with the aim) only under --ring-scrap, and is not shipped
(PD-CANNON fix round 2): it is a mesh on a third moving frame beside Carapace on Pod (and the
class III collars on Core), so each layer would cost one draw more, 2 / 3 / 2 at classes II to
IV against the 1 / 2 / 1 layer caps, and no exception is granted. --ring-scrap with --outdir
writes the measured candidates for the coordinator's call. The scrap rides WeaponRing, not
MainBarrel, so it would hold the barrel's rest pitch; nothing pitches MainBarrel at run time yet.
Ruling R2 (2026-10-11): dropped for the alpha; gap panels carry heft, the barrel stays seamless.
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
import common
from common import Part
import shell_base as sb
import shell_cannon as sc

OUTDIR = HERE.parents[2] / "assets/models/world_one"
LAYER_TRIS = 1500
LAYER_VERTS = 3000
R_OUT = 0.92
R_TOP = 0.928
R_IN = 0.89
GIMBAL_CLEAR = sb.GIMBAL_OUTER[1] + 0.003
K5, K3, CLIP = 0.58, 0.74, 0.24
PLATEAU = 0.72
FRONT_EYES = tuple(Vector((e.x, -e.y, e.z)) for e in sb.CHASE_EYES)
VERDIGRIS = "47736a"
RIM = common.mix(VERDIGRIS, "charcoal", 0.30)
BACK = common.mix(VERDIGRIS, "charcoal", 0.50)
DUST = common.mix(VERDIGRIS, "736b5a", 0.35)
CLASSES = (2, 3, 4, 5)
GUARD = (sc.RUSH[1] + 0.014, sc.RUSH[1] + 0.036, 0.05, sc.RUSH[3] - 0.015)
COLLAR = (sb.HUB_CAP[0] + 0.002, sb.HUB_CAP[0] + 0.024, 0.950, 0.979)


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


def heavy_forms(part, pod):
    """Class V: a cast hood over each split port (a top slab and an outer lip), standing the port
    0.20 m past the lattice and staying above Z -0.6, and a cast guard ring round the rush ring.
    The two hoods are one mesh under pod, PortHoods, so the carrier bank tilts them with the ports
    (one more draw, 2 at class V); the guard ring stays on Carapace (inside the 0.99 limit)."""
    hoods = Part("PortHoods")
    for side in (1, -1):
        c, n, f, u = sc.port_axes(side)
        rad, fwd, up = sc.PORT_SIZE
        length = fwd + 0.06
        sc.oriented_box(hoods, "ancient_enamel", c + u * (up / 2 + 0.016) + n * 0.03, (n, f, u),
                        (rad + 0.10, length, 0.026), RIM)
        sc.oriented_box(hoods, "ancient_enamel", c + n * (rad / 2 + 0.065) + u * 0.05, (n, f, u),
                        (0.026, length, up / 2 + 0.04), VERDIGRIS)
    hoods.bm.normal_update()
    bmesh.ops.recalc_face_normals(hoods.bm, faces=hoods.bm.faces[:])
    sb._sharpen(hoods)
    hoods.to_object((0, 0, 0), pod)
    r_in, r_out, depth, z = GUARD
    part.ring("ancient_enamel", r_in, r_out, depth, 12, loc=(0, 0, z), color=RIM)


SCRAP_IRON = common.mix("736b5a", "charcoal", 0.45)
SCRAP_PLATE = common.mix(VERDIGRIS, "736b5a", 0.6)
JACKET = (1.25, 0.11)
SKIRT = (1.062, 0.012, 14)


def ring_scrap(n):
    """(Part, origin) of class n's barrel-borne scrap in Pod space with the barrel at rest
    pitch, or None: II a slotted muzzle brake, III a jacket over the breech half's top, IV a
    short skirt of plates hung from the bearing collar."""
    p = Part("RingScrap%d" % n)
    y_m = sc.MUZZLE_Y
    if n == 2:
        p.ring("ancient_enamel", sc.MUZZLE_R[0], 0.125, 0.086, 8, loc=(0, y_m + 0.047, 0), rot=(math.pi / 2, 0, 0),
               color=SCRAP_IRON)
        for side in (-1, 1):
            p.box("ancient_enamel", (0.035, 0.05, 0.10), loc=(side * 0.14, y_m + 0.047, 0), color=SCRAP_PLATE)
        origin = sc.PIVOT
    elif n == 3:
        y, length = JACKET
        r_in = sc.body_r(y - length / 2) + sc.BAND_PROUD + 0.004
        p.ring("ancient_enamel", r_in, r_in + 0.028, length, 6, loc=(0, y, 0), rot=(math.pi / 2, 0, 0),
               color=SCRAP_PLATE, arc=(math.pi / 6, 5 * math.pi / 6))
        for dy in (-0.035, 0.035):
            p.ring("ancient_enamel", r_in + 0.028, r_in + 0.038, 0.014, 6, loc=(0, y + dy, 0),
                   rot=(math.pi / 2, 0, 0), color=SCRAP_IRON, arc=(math.pi / 6, 5 * math.pi / 6))
        origin = sc.PIVOT
    elif n == 4:
        r, thick, count = SKIRT
        c_in, c_out, c_h, c_z = sb.RING_COLLAR
        top = c_z - c_h / 2
        for k in range(count):
            a = (k + 0.5) * math.tau / count
            h = 0.07 + 0.02 * ((k * 5) % 3) / 2
            p.box("ancient_enamel", (0.20, thick, h), loc=(r * math.cos(a), r * math.sin(a), top - h / 2),
                  rot=(0, 0, a + math.pi / 2), color=SCRAP_PLATE if k % 2 else SCRAP_IRON)
        origin = Vector()
    else:
        return None
    sb._sharpen(p)
    return p, origin


def scrap_checks(obj, n, pod_points, step=0.01):
    """(lattice clearance, Pod vertices inside the scrap's yaw sweep) for one class's scrap; the
    barrel-borne pieces are taken over the barrel's whole pitch range."""
    pitches = [sc.PITCH[0] + (sc.PITCH[1] - sc.PITCH[0]) * i / 18 for i in range(19)] if n in (2, 3) else [0.0]
    bins, closest = {}, 9.0
    for v in obj.data.vertices:
        w = obj.matrix_world @ v.co
        for deg in pitches:
            q = sc._pitched(w, deg) if deg else w
            closest = min(closest, q.length)
            k, r = round(q.z / step), math.hypot(q.x, q.y)
            lo, hi = bins.get(k, (r, r))
            bins[k] = (min(lo, r), max(hi, r))
    hits = 0
    for p in pod_points:
        for k in (math.floor(p.z / step), math.ceil(p.z / step)):
            span = bins.get(k)
            if span and span[0] - 0.01 <= math.hypot(p.x, p.y) <= span[1] + 0.01:
                hits += 1
                break
    return closest, hits


def build_layer(n, panels, hubs, gaps, rng, scrap=False):
    """One layer's root, Pod and the panel vertex positions (for the rush-ring check)."""
    root = common.empty("ShellCannonC%d" % n)
    core = common.empty("Core", (0, 0, 0), root)
    if n == 3:
        tread_collars(hubs).to_object((0, 0, 0), core)
    pod = common.empty("Pod", (0, 0, 0), root)
    made = ring_scrap(n) if scrap else None
    if made is not None:
        ring = common.empty("WeaponRing", (0, 0, 0), pod)
        made[0].to_object(made[1], ring)
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
        heavy_forms(part, pod)
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


def check(n, root, pod, points, bins, count, pod_points=()):
    scrap_ok, extra = True, 0
    for o in common.tree(pod):
        if o.type == "MESH" and o.name.startswith("RingScrap"):
            clear, hits = scrap_checks(o, n, pod_points)
            extra = len(o.data.materials)
            scrap_ok = clear > sb.CORE_LIMIT and hits == 0
            print("RING_SCRAP c%d tris %d draws %d lattice clearance %.3f (> %.3f) Pod hits %d %s"
                  % (n, common.tris(o), extra, clear, sb.CORE_LIMIT, hits, "ok" if scrap_ok else "OUT"))
    tris = common.tri_total(root)
    meshes = [o for o in common.tree(root) if o.type == "MESH"]
    draws = sum(len(o.data.materials) for o in meshes)
    hood_draws = 1 if n == 5 else 0
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
    return (scrap_ok and count > 0 and tris <= LAYER_TRIS and draws == (2 if n == 3 else 1) + extra + hood_draws
            and cone == 0 and front == 0
            and sweep == 0 and low == 0 and inner >= GIMBAL_CLEAR and outer <= sb.LATTICE_INNER - 0.005
            and core_far <= sb.CORE_LIMIT + 1e-4 and down >= rush + 1.0)


def remove(root):
    for o in reversed(common.tree(root)):
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    common.reset()
    base = sc.build_shell("")
    bins = sc.sweep_bins(base["ring"], base["barrel"])
    scrap = bool(flag("--ring-scrap"))
    if scrap and not flag("--outdir") and not flag("--count-only"):
        raise SystemExit("--ring-scrap writes unshipped candidates: give --outdir or --count-only")
    pod_points = [o.matrix_world @ v.co for o in sb.cone_meshes(base["pod"])
                  if o.name.split(".")[0] not in sc.SWEEP_SKIP for v in o.data.vertices] if scrap else []
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
        root, pod, points = build_layer(n, classes[n], hubs, gaps, rng, scrap)
        if not check(n, root, pod, points, bins, len(classes[n]), pod_points):
            bad.append(n)
        elif not flag("--count-only"):
            common.export(root, os.path.join(outdir, "shell_cannon_c%d.glb" % n))
        remove(root)
    if bad:
        raise SystemExit("cannon layers out of contract, not written: %s" % bad)


if __name__ == "__main__":
    main()
