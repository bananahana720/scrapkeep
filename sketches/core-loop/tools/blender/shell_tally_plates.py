"""Tally's four heft layers (unit PD-TALLY; ROSTER-LOOK sections 0.3 and 5, pilots/tally.md
section 5), rebuilt for the wire-tapper (unit W47-TALLY-A-3D, 24 Nov 2026; master bible section
2.3 B1: punched copper-bus plates and reel hoods bolt over the gaps from I to V): square
copper-faced relay bus plates with rows of punched holes, hung from the upright Pod just inside
the lattice (outer face 0.905 m at the centre, corners under the 0.94 m inner face), each stamped
in charcoal with its class's Roman numeral.

  II   six plates in the lower gaps, below Z -0.35; stamped II
  III  plates in the side gaps (III), and thicker six-sided tread caps on every hub
       (the layer's Core part, so the class costs two draws; registry exception)
  IV   plates in most gaps (IV) and the two reel hoods (own mesh, DrumHoods), curved bone
       (aluminium) plates over the top half of each tape deck; the deck faces stay open
  V    every remaining non-sight gap (V) and the heavy tape decks: copper flanges, brown tape and
       a second reel ring, outline break 0.20 m (own mesh, HeavyDrums). Replace.Flywheel.R and .L
       hide the light decks while the class shows (CUSTOMIZE section 6, Replace.<name>).

No plate enters the sight cone from the head to the chase eyes or the front sight line to the
face, the side gaps the drum brackets pass through stay open, and nothing passes radius 1.0
below Z -0.6. Each class is one mesh on one paint surface per part.

Pictures: artifacts/local/alpha/push/w13/concepts/codex/tally/sheet.png (GAP PANEL and heft
I, III, V panels) and hero.png; the grounded sheet g06-pilots-trio-b-tarn-tally-cannon.png.

Run it as shell_tally.py's header runs that recipe (the same 12 GiB prlimit and two threads),
with this script's path and the optional arguments -- [--outdir <dir>].
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common
from common import Part
import shell_base as sb
import shell_tally as st

LAYER_TRIS = 1500
PANEL_HALF = 0.15
PANEL_OUT = 0.905
PANEL_THICK = 0.035
FRONT_EYES = tuple(Vector((0.0, -e.y, e.z)) for e in sb.CHASE_EYES)
BRACKET_DIRS = (Vector((1, 0, 0.12)).normalized(), Vector((-1, 0, 0.12)).normalized())
BRACKET_CLEAR = math.radians(15)
HEAVY_R = st.DRUM_R + 0.01
HEAVY_DEPTH = st.DRUM_DEPTH - 0.01
HEAVY_Z = st.DRUM_Z
HEAVY_X = st.DRUM_INNER + HEAVY_DEPTH / 2
HOOD = (st.DRUM_R + 0.016, st.DRUM_R + 0.03, st.DRUM_DEPTH * 0.6)
HOOD_FROM = st.DRUM_INNER + st.SHOE_OVER + 0.004


def in_cone(points, eyes):
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    axes = [(e - sb.HEAD).normalized() for e in eyes]
    for p in points:
        d = p - sb.HEAD
        if d.length > 1e-6 and any(d.normalized().dot(a) > cos_half for a in axes):
            return True
    return False


def corners(d):
    e1, e2 = sb._frame(d)
    out = []
    for r in (PANEL_OUT, PANEL_OUT - PANEL_THICK):
        for sx in (-1, 1):
            for sy in (-1, 1):
                out.append(d * r + e1 * (sx * PANEL_HALF) + e2 * (sy * PANEL_HALF))
    out.append(d * PANEL_OUT)
    return out


def allowed(d):
    pts = corners(d)
    if in_cone(pts, sb.CHASE_EYES) or in_cone(pts, FRONT_EYES):
        return False
    if any(d.angle(b) < BRACKET_CLEAR for b in BRACKET_DIRS):
        return False
    return True


def assign():
    """Splits the allowed gaps across classes II to V by direction in the rest pose."""
    _, _, gaps = sb.lattice_layout()
    classes = {2: [], 3: [], 4: [], 5: [], "open": []}
    for i, d in enumerate(gaps):
        if not allowed(d):
            classes["open"].append(i)
        elif all(p.z < -0.35 for p in corners(d)):
            classes[2].append(i)
        elif abs(d.x) > 0.55 and d.z < 0.3:
            classes[3].append(i)
        elif d.z <= 0.6:
            classes[4].append(i)
        else:
            classes[5].append(i)
    return gaps, classes


def quad(p, centre, u, v, hu, hv, colour):
    vs = [p.bm.verts.new(centre + u * (sx * hu) + v * (sy * hv)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    return p.paint([p.bm.faces.new(vs)], "paint", colour)


NUMERALS = {
    2: ((-0.015, 0.0), (0.015, 0.0)),
    3: ((-0.03, 0.0), (0.0, 0.0), (0.03, 0.0)),
    4: ((-0.04, 0.0), (0.004, -0.32), (0.036, 0.32)),
    5: ((-0.016, -0.32), (0.016, 0.32)),
}


def plate(p, d, strokes):
    """One square relay bus plate facing along d: a copper-faced slab, two rows of four punched
    holes and the class's Roman numeral (charcoal) on the outer face, its edges and back charcoal."""
    e1, e2 = sb._frame(d)
    n = d.normalized()
    centre = n * (PANEL_OUT - PANEL_THICK / 2)
    vs = []
    for sz in (-1, 1):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(p.bm.verts.new(centre + e1 * (sx * PANEL_HALF) + e2 * (sy * PANEL_HALF) + n * (sz * PANEL_THICK / 2)))
    lo, hi = vs[:4], vs[4:]
    top = p.bm.faces.new(hi)
    bottom = p.bm.faces.new(list(reversed(lo)))
    sides = [p.bm.faces.new((lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k])) for k in range(4)]
    p.paint([top], "paint", "copper")
    p.paint([bottom], "paint", "charcoal")
    p.paint(sides, "paint", "charcoal")
    face = n * (PANEL_OUT + 0.0015)
    for row in (-1, 1):
        for k in range(4):
            c = face + e1 * (-0.09 + 0.06 * k) + e2 * (row * 0.085)
            quad(p, c, e1, e2, 0.011, 0.011, "charcoal")
    for dx, slant in NUMERALS[strokes]:
        up = (e2 * math.cos(slant) + e1 * math.sin(slant)).normalized()
        across = up.cross(n)
        quad(p, face + e1 * dx + n * 0.0005, across, up, 0.006, 0.045, "charcoal")


def caps(p, rng):
    """Class III: a thicker six-sided tread cap on every hub, rim at the core limit."""
    hubs, _, _ = sb.lattice_layout()
    rim = 0.08
    top = math.sqrt(sb.CORE_LIMIT ** 2 - rim ** 2) - 0.0005
    for d in hubs:
        sb._drum(p, d, rim, 0.950, top, 6, "rubber", roll=rng.uniform(0, math.tau), bottom=False)


def hoods(p):
    r_in, r_out, depth = HOOD
    for side in (1, -1):
        x = side * (HOOD_FROM + depth / 2)
        p.ring("paint", r_in, r_out, depth, 6, loc=(x, 0, st.DRUM_Z), rot=(0, math.pi / 2, 0),
               color="bone", arc=(math.pi / 2, 3 * math.pi / 2))


def heavy(p):
    for side in (1, -1):
        st.drum("HeavyDrums", side, (side * HEAVY_X, 0.0, HEAVY_Z), radius=HEAVY_R, depth=HEAVY_DEPTH, reel=True, part=p)


def build(n, gaps, classes, rng):
    common.reset()
    root = common.empty("ShellTallyC%d" % n)
    p = Part("Pod")
    strokes = {2: 2, 3: 3, 4: 4, 5: 5}[n]
    for i in classes[n]:
        plate(p, gaps[i], strokes)
    sb._sharpen(p)
    pod = p.to_object((0, 0, 0), root)
    if n == 4:
        hp = Part("DrumHoods")
        hoods(hp)
        sb._sharpen(hp)
        hp.to_object((0, 0, 0), pod)
    if n == 5:
        hp = Part("HeavyDrums")
        heavy(hp)
        hp.to_object((0, 0, 0), pod)
    if n == 3:
        cp = Part("Core")
        caps(cp, rng)
        sb._sharpen(cp)
        core = cp.to_object((0, 0, 0), root)
    else:
        core = common.empty("Core", (0, 0, 0), root)
    if n == 5:
        for side in ("R", "L"):
            common.empty("Replace.Flywheel." + side, (0, 0, 0), pod)
    bpy.context.view_layer.update()
    tris = common.tri_total(root)
    parts = [pod] + [c for c in pod.children if c.type == "MESH"]
    low = sb.low_reach(pod)
    cone = sb.sight_cone_hits(pod)
    front = 0
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    axes = [(e - sb.HEAD).normalized() for e in FRONT_EYES]
    world = [o.matrix_world @ v.co for o in parts for v in o.data.vertices]
    for w in world:
        dv = w - sb.HEAD
        if dv.length > 1e-6 and any(dv.normalized().dot(a) > cos_half for a in axes):
            front += 1
    pod_far = max(w.length for w in world)
    plates_far = max((w.length for w in world if w.length < 0.96), default=0.0)
    core_far = common.max_radius(core) if core.type == "MESH" else 0.0
    row = {"class": n, "plates": len(classes[n]), "gaps": classes[n], "tris": tris, "low_reach": low,
           "sight_cone": cone, "front_sight": front, "pod_far": round(pod_far, 4),
           "plate_far": round(plates_far, 4), "core_far": round(core_far, 4)}
    print("LAYER", json.dumps(row, sort_keys=True))
    ok = tris <= LAYER_TRIS and low == 0 and cone == 0 and front == 0 and core_far <= sb.CORE_LIMIT + 1e-4 \
        and plates_far < sb.LATTICE_INNER
    return root, row, ok


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = argv[argv.index("--outdir") + 1] if "--outdir" in argv else os.path.join(common.MODELS, "world_one")
    gaps, classes = assign()
    print("GAPS", json.dumps({str(k): v for k, v in classes.items()}, sort_keys=True))
    bad = []
    for n in (2, 3, 4, 5):
        rng = sb.rng_for("Tally-c%d" % n)
        root, row, ok = build(n, gaps, classes, rng)
        common.export(root, os.path.join(outdir, "shell_tally_c%d.glb" % n))
        if not ok:
            bad.append(n)
    if bad:
        raise SystemExit("layer checks failed for classes %s" % bad)


if __name__ == "__main__":
    main()
