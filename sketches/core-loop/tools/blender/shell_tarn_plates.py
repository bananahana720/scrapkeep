"""Tarn's heft layers (PD-TARN): shell_tarn_c2.glb to shell_tarn_c5.glb, the detail shells the
loader shows up to the heft class (CUSTOMIZE section 6). Each layer has the base's top-level
Core and Pod split; each part is one mesh on the paint slot (one draw), so the equipped paint
reaches every panel. Thick bone and petrol slabs scored with claw marks hang from the Pod
just inside the lattice (outer face 0.92, 0.04 thick, ROSTER-LOOK sections 2 and 5); no panel
enters the sight cone, the front face gap or a claw arm's gap.

  II   the six lowest gaps, every panel below Z -0.35
  III  the side gaps, the claw hooks out to 0.70 m past the lattice, and (Core part) thicker
       tread-cap rims, so class III is two draws (registry exception); the hooks (here and at IV
       and V) are their own ClawHooks mesh under Pod, one more draw, so the carrier bank tilts
       them with the claw arms (hero_assets BRACKET_PARTS)
  IV   most remaining gaps (the crown stays open), hooks to 0.73 m, hinge guards on both claw
       arms and a slab skirt round the pull drum
  V    every remaining non-sight gap, the heavy hooks to 0.765 m (1.74 m from the centre) with a
       second tooth row

Concept: artifacts/local/alpha/push/w13/concepts/codex/tarn/sheet.png (GAP PANEL, heft I, III
and V) and hero.png.

  Run as shell_tarn.py's header shows, under the same 12 GiB prlimit address-space cap:
    blender --background --threads 2 --python-exit-code 1 \
    --python tools/blender/shell_tarn_plates.py -- [--outdir <dir>]
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
sys.path.insert(0, str(HERE))
import common  # noqa: E402
from common import Part  # noqa: E402
import shell_base as sb  # noqa: E402
import shell_tarn as st  # noqa: E402

LAYER_CAP = (1500, 3000)      # detail class tris and verts (assets/asset_budgets.json)
PANEL_OUT = 0.92
PANEL_IN = 0.88
PANEL_SHRINK = 0.80           # corner pull toward the gap centre, so struts frame the slab
LOW_Z = -0.35
CLAW_GAP = math.radians(24)   # gaps this close to a claw arm stay open for the bracket
FRONT = Vector((0.0, 1.0, 0.12)).normalized()


def gap_diamonds():
    """(centre direction, four corner directions) per gap: the two five-way hubs on its long
    axis and the two three-way hubs on its short one."""
    hubs, _, gaps = sb.lattice_layout()
    out = []
    for g in gaps:
        five = sorted(hubs[:12], key=lambda h: -h.dot(g))[:2]
        three = sorted(hubs[12:], key=lambda h: -h.dot(g))[:2]
        out.append((g, [five[0], three[0], five[1], three[1]]))
    return out


def in_cone(p, head=sb.HEAD):
    d = Vector(p) - head
    if d.length < 1e-6:
        return False
    d.normalize()
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    axes = [(e - head).normalized() for e in sb.CHASE_EYES] + [FRONT]
    return any(d.dot(a) > cos_half for a in axes)


def corners_at(g, corners, radius):
    out = []
    for c in corners:
        p = g + (c - g) * PANEL_SHRINK
        out.append(p.normalized() * radius)
    return out


def eligible():
    """Gap indices a panel may fill: not in the sight cone (chase eyes and the front face
    view), not on a claw arm's path."""
    claw_dirs = [st.claw_frame(s)[0] for s in (1, -1)]
    ok = []
    for i, (g, corners) in enumerate(gap_diamonds()):
        pts = corners_at(g, corners, PANEL_OUT) + [g * PANEL_OUT]
        if any(in_cone(p) for p in pts):
            continue
        if any(g.angle(d) < CLAW_GAP for d in claw_dirs):
            continue
        ok.append(i)
    return ok


def assign():
    """Gap indices per class, II to V, each gap in one class only."""
    diamonds = gap_diamonds()
    free = eligible()
    low = [i for i in free if all(p.z < LOW_Z for p in corners_at(*diamonds[i], PANEL_OUT))]
    c2 = sorted(low, key=lambda i: diamonds[i][0].z)[:6]
    rest = [i for i in free if i not in c2]
    c3 = [i for i in rest if abs(diamonds[i][0].x) > 0.55 and diamonds[i][0].z < 0.45]
    rest = [i for i in rest if i not in c3]
    c4 = [i for i in rest if diamonds[i][0].z < 0.55]
    c5 = [i for i in rest if i not in c4]
    return {2: c2, 3: c3, 4: c4, 5: c5}


def slab(p, g, corners, index):
    """One thick slab: outer and inner faces, four walls, three claw scores proud of the face."""
    outer = [p.bm.verts.new(c) for c in corners_at(g, corners, PANEL_OUT)]
    inner = [p.bm.verts.new(c) for c in corners_at(g, corners, PANEL_IN)]
    color = "petrol" if index % 3 == 0 else "bone"
    faces = [p.bm.faces.new(outer), p.bm.faces.new(list(reversed(inner)))]
    for k in range(4):
        j = (k + 1) % 4
        faces.append(p.bm.faces.new((inner[k], inner[j], outer[j], outer[k])))
    p.paint(faces, "paint", color)
    # Make the outer face point outward whatever order the corners came in.
    if faces[0].calc_center_median().dot(faces[0].normal) < 0:
        for f in faces:
            f.normal_flip()
    # Claw scores: three parallel dark gouges across the face, diagonal to the long axis.
    centre = g * (PANEL_OUT + 0.002)
    e_long = (corners[0] - corners[2]).normalized()
    e_long = (e_long - g * e_long.dot(g)).normalized()
    e_short = g.cross(e_long).normalized()
    across = (e_long * 0.55 + e_short).normalized()
    along = g.cross(across).normalized()
    score = "bone" if color == "petrol" else "charcoal"
    for k in (-1, 0, 1):
        mid = centre + along * (0.035 * k)
        a, b = mid - across * 0.07, mid + across * 0.07
        w = along * 0.006
        q = [p.bm.verts.new(v) for v in (a - w, b - w, b + w, a + w)]
        f = p.bm.faces.new(q)
        if f.normal.dot(g) < 0:
            f.normal_flip()
        p.paint([f], "paint", score)


# The hook's offset along the hinge pin, to the side away from the chase camera: it lies beside the
# jaws' swing plane (the jaws are JAW_THICK thick, the ram sits on the camera side), so the jaws
# open round it at any angle and never pass through it (E2-04).
HOOK_OFFSET = 0.095
HOOK_THICK = 0.06
HOOK_HEIGHT = 2.6      # the hook's depth over the 2026-10 outline, chunky to match the jaws


def hook(p, side_sign, reach, teeth=False):
    """A fixed hooked claw finger beside the jaws on the claw arm's bracket, out to reach past the
    lattice; teeth adds the second tooth row along its lower edge (class V). From the chase
    camera it sits behind the closed jaws and shows past their tips: the longer reach."""
    d, axis, up, hinge, tip = st.claw_points(side_sign, reach)
    length = (tip - hinge).length
    base = hinge - axis * (side_sign * HOOK_OFFSET)
    pts = [(0.0, 0.0), (0.0, 0.03), (0.6 * length, 0.045), (0.92 * length, 0.03),
           (length, -0.005), (0.97 * length, -0.05), (0.90 * length, -0.012)]
    if teeth:
        for k in range(3):
            u0 = 0.78 * length - k * 0.16 * length
            pts += [(u0 - 0.04 * length, -0.03), (u0 - 0.08 * length, -0.004)]
    pts.append((0.1 * length, -0.004))
    pts = [(u, v * HOOK_HEIGHT) for u, v in pts]
    st._plane_prism(p, "paint", list(reversed(pts)), HOOK_THICK, base, d, up, color="bone")
    return tip


def thick_caps(p):
    """Class III: a wider rubber-dark rim round every tread cap, on paint charcoal, kept
    inside the core limit. Top annulus and outer wall only (24 triangles a hub)."""
    hubs, _, _ = sb.lattice_layout()
    r_in, r_out, lo, hi, sides = sb.HUB_CAP[0], 0.088, 0.950, 0.978, 6
    for d in hubs:
        e1, e2 = sb._frame(d)
        ring = [math.cos(k * math.tau / sides) * e1 + math.sin(k * math.tau / sides) * e2 for k in range(sides)]
        top_in = [p.bm.verts.new(d * hi + r_in * q) for q in ring]
        top_out = [p.bm.verts.new(d * hi + r_out * q) for q in ring]
        bot_out = [p.bm.verts.new(d * lo + r_out * q) for q in ring]
        faces = []
        for k in range(sides):
            j = (k + 1) % sides
            faces.append(p.bm.faces.new((top_in[k], top_out[k], top_out[j], top_in[j])))
            faces.append(p.bm.faces.new((top_out[k], bot_out[k], bot_out[j], top_out[j])))
        p.paint(faces, "paint", "charcoal")


def guards(p):
    """Class IV: a petrol guard round each claw hinge and a bone slab skirt under the drum."""
    for sign in (1, -1):
        _, axis, up, hinge, _ = st.claw_points(sign, st.CLAW_REACH[0])
        p.rod("paint", hinge - axis * (st.BOSS[1] + 0.02), hinge + axis * (st.BOSS[1] + 0.02), st.BOSS[0] + 0.025, 6, color="petrol")
    c = st.DRUM_CENTRE
    # Half shell below and behind the drum, inside the gimbal sweep (0.829).
    p.ring("paint", st.DRUM_RADIUS + 0.018, st.DRUM_RADIUS + 0.03, 2 * st.DRUM_HALF + 0.04, 6,
           loc=tuple(c), rot=(0, math.pi / 2, 0), arc=(math.pi * 0.35, math.pi * 1.25), color="bone")


def layer(n, gaps):
    root = common.empty("ShellTarnC%d" % n)
    diamonds = gap_diamonds()
    pod = Part("Pod")
    for i in gaps:
        slab(pod, diamonds[i][0], diamonds[i][1], i)
    reach = st.CLAW_REACH[n - 1]
    tips = []
    if n >= 3:
        hooks = Part("ClawHooks")
        for sign in (1, -1):
            tips.append(hook(hooks, sign, reach, teeth=(n == 5)))
    if n == 4:
        guards(pod)
    sb._sharpen(pod)
    if n == 3:
        core = Part("Core")
        thick_caps(core)
        sb._sharpen(core)
        core_obj = core.to_object((0, 0, 0), root)
    else:
        core_obj = common.empty("Core", (0, 0, 0), root)
    pod_obj = pod.to_object((0, 0, 0), root)
    if n >= 3:
        sb._sharpen(hooks)
        hooks.to_object((0, 0, 0), pod_obj)
    return root, core_obj, pod_obj, tips


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = Path(argv[argv.index("--outdir") + 1]) if "--outdir" in argv else SKETCH / "assets/models/world_one"
    plan = assign()
    print("GAPS eligible %d of 30: %s" % (len(eligible()), {k: len(v) for k, v in plan.items()}))
    ok = True
    for n in (2, 3, 4, 5):
        common.reset()
        root, core, pod, tips = layer(n, plan[n])

        bpy.context.view_layer.update()
        tris = common.tri_total(root)
        verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
        draws = sum(1 for o in common.tree(root) if o.type == "MESH")
        cone = sb.sight_cone_hits(pod)
        low = sb.low_reach(pod)
        core_r = common.max_radius(core) if core.type == "MESH" else 0.0
        reach = max((t.length - sb.LATTICE_OUTER for t in tips), default=st.CLAW_REACH[0])
        far = max(common.max_radius(o) for o in common.tree(root) if o.type == "MESH")
        below = all(t.z > sb.LOW_Z for t in tips)
        good = (tris <= LAYER_CAP[0] and cone == 0 and low == 0 and core_r <= sb.CORE_LIMIT + 1e-4
                and abs(reach - st.CLAW_REACH[n - 1]) < 0.005 and far <= st.REACH_CAP and below)
        print("LAYER c%d panels=%d tris=%d verts=%d draws=%d cone=%d low=%d core_r=%.4f claw_reach=%.3f max_r=%.3f %s"
              % (n, len(plan[n]), tris, verts, draws, cone, low, core_r, reach, far, "ok" if good else "OUT"))
        ok &= good
        common.export(root, str(outdir / ("shell_tarn_c%d.glb" % n)))
    if not ok:
        raise SystemExit("Tarn layer checks failed")
    print("TARN_PLATES: PASS")


if __name__ == "__main__":
    main()
