"""Headless recipes for the dam-era works of the flume park (stage 2, "Spillway: the flume", Arizona canal country, morning).
Each recipe id builds three GLBs under assets/models/park/: <id>.glb (the render mesh, a "<id>-col-col" collision mesh and,
for the ride pieces, the rail line), <id>_detail1.glb and <id>_detail2.glb (the two detail shells park_recipes.gd draws at
60 m and 25 m). They replace the grey-box rows; same conventions as grind.py, whose FLUME profile this module imports.

A. Box pieces (registry origin "centre", never scaled). The -col mesh is exactly the box x +-W/2, y 0..H, z +-L/2 of the
   row's size [L, H, W] (8 corners, 12 triangles), so the collider is identical to the grey box. The drawn mesh hugs the box:
   nothing stands more than 0.15 m proud of a face, nothing is recessed more than 0.3 m, the top face at y = H is flat and
   flush (roofs and caps are colour tiles, never a parapet) and the detail shells stay within 0.15 m too.
     flume_bent_50 / flume_bent_32   plank-sheathed timber bent tower: corner posts, iron strap bands, timber cap, a white
                                     bent number board (blank, tick stripes) and a cream / iron-oxide speed-tick band on
                                     both long faces.
     survey_mast_40                  board-formed concrete footing (4 m), plank mast in 2 m red / cream survey-rod bands,
                                     a copper survey plate and a string pulley block at the top.
     surge_pylon_28 / surge_pylon_48 board-formed concrete pylon, steel crossarm, glass-green insulators, copper stubs.
     crib_pier_28x28x6, _24x18x6, _20x28x6, _12x28x6, _24x28x20 and crib_wall_60x24x6
                                     squared timber courses alternating direction, rock fill recessed in the gaps, iron
                                     drift-pin heads, a timber cap.
     anchor_block_16x28x8            penstock anchor block: board-formed concrete, iron saddle ring and a cut pipe stub as
                                     flush colour on the top.
     weir_gatehouse                  small concrete gatehouse: door, gate wheel, flat roof at H.
     annex_hall                      heat-exchanger annex: concrete hall, flat roof at H, pipe runs, a big pressure dial.
     crew_bunk_ledge                 plank deck (top y = 1) on joists and knee braces down to y -5 (visual only) with
                                     numbered bunk door boards along the +X edge. The collider stays the 120 x 1 x 10 box.
B. Wedge pieces (origin "centre", never scaled). The -col mesh is the grey-box drop wedge of park_recipes.gd
   _wedge(extent, -1): six corners, a triangular prism whose top slopes from y = H at z = -L/2 to y = 0 at z = +L/2, with a
   vertical end face at z = -L/2. The sloped top is the ride surface: it carries flush colour (cells, at most 0.012 m decals).
     weir_apron, gap_work_deck, rim_road.
C. Flume ride pieces (origin "entry_lip", +Z the ride): the trough cross-section is grind.py FLUME exactly (floor y 5, crests
   y 8, walls, bents every 12 m, hoop straps, rail empties "<id>-rail_NN" on the crest).
     flume_pour_spout                14 m, level; the last 2 m of floor curve down 1 m into a pour lip. It hangs from the relic
                                     clamp: its two bents are 2 m hangers, so the drum floor stays open underneath.
     flume_siphon_span               100.8 m; the whole section rides y(z) = 5 - 21 s(z/100.8), s(t) = 3t^2 - 2t^3, built in
                                     stations, bent legs reach 11 m below the local floor.
     flume_reach_120                 120 m, level, a bent flush inside each end so the -col runs exactly 0..120 and its entry
                                     and exit sections match (flume_span's do not, so it refuses the tile fit); rows tile it
                                     end to end. Bent legs reach 11 m below the floor.
     flume_intake_16                 16 m flared mouth (entry_lip, +Z the ride): floor y 4.4 -> 5, half-width 7.0 -> 1.6 and wall
                                     height 0 -> 3, each on a smoothstep, ending exactly on the FLUME section so it butts a reach.
                                     The -col is the lofted walls and floor only (no bents, it sits on the ground); iron gate
                                     posts and a timber sluice board hung open 6 m overhead are body decoration outside it.

D. Liners (section "D. liners" below; ids liner_<row>, one GLB each now that every liner is a flush lane, selected with --liners). Decoration only: no -col mesh, the
   stamped terrain stays the only collider. Registry origin "centre", no fit: park_recipes.gd places the GLB rigidly at the row's
   `at`, y = ground(at), turned by yaw_deg, never scaled, so every vertex is conformed to ground.bin (the bake): its local y is
   ground(world x, z) - ground(at) + an offset (0.05 m base, raised features at most 0.25 m, the middle 40 % of the width flush).
   Rebuild after a re-bake. --check re-reads ground.bin and reports the vertical gap between the base mesh and the ground.

Conventions as grind.py: +Y up, one "enamel" vertex-colour slot, Southwest palette only (copper b77843, never brass),
deterministic (no randomness, rebuilds are byte-identical), the collision mesh is the object "<id>-col-col" (the importer
strips one "-col"), budgets from asset_budgets.json (landform 8000 tris, detail 1500 tris, one draw per mesh).

  prlimit (12 GiB address space) -- blender --background --threads 2 --python-exit-code 1 --python \
      sketches/core-loop/tools/blender/park/flume_works.py -- [--out-dir DIR] [--only ID] [--liners] [--count-only] [--check] [--registry]
  --check     rebuild nothing: verify the GLBs already in --out-dir (collider boxes / wedges, hugging, flume section, rails)
  --registry  print the registry.d fragment (assets/registry.d/park_flume_works.json) for these ids
  --isles     act on the islands liners (liner_run_turn_wash, liner_lookout_stair, liner_east_ribs, liner_net_post_run, liner_cloud_wash_east,
              liner_ore_chute; conformed to assets/park/park_islands/ground.bin; registry fragment assets/registry.d/park_islands_liners.json)
  --pit       act on the pit liners (liner_dump_wash_1..2, liner_canal_lip, liner_haul_road_west_5, liner_bench2_camp_lane,
              liner_bench2_east_bank; conformed to assets/park/park_pit/ground.bin), with --check, --count-only or --registry
              (assets/registry.d/park_pit_liners.json)
"""
import argparse
import hashlib
import json
import bisect
import math
from pathlib import Path
import struct
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import grind
from grind import (kit, common, block, solid, stud, disc, strut, tone, _wheel, FLUME, flume_ring, COL_NODE, BUDGET, MODELS,
                   SAND, CREAM, SLICK, OXIDE, IRON, VARNISH, CONCRETE, FORM, SAGE, JUNIPER, COPPER, DARK)

TIMBER = "7a5636"
TIMBER_DK = "4a3220"
TIMBER_LT = "8a6440"
FOOTING = "9c907a"
STEEL = "4a4844"
BOARD = "ece3cc"
GLASS = "6fa58a"
HOP = 0.15                 # nothing stands this far proud of a box face
RECESS = 0.3               # nothing sits deeper than this
RAIL_PROUD = 0.02          # flush decals on a rideable top

Surf = kit.Surface         # no pitch here: every piece is authored level in Godot space


# ------------------------------------------------------------------ geometry helpers

def hull(s, ring_a, ring_b, color):
    """A closed convex prism between two same-length 3D rings (windings are fixed by the kit's normal recalculation)."""
    n = len(ring_a)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    s.add([tuple(p) for p in ring_a] + [tuple(p) for p in ring_b], faces, color)


def loft(s, rings, color):
    n, m = len(rings[0]), len(rings)
    faces = [tuple(reversed(range(n))), tuple(range((m - 1) * n, m * n))]
    for j in range(m - 1):
        faces += [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i) for i in range(n)]
    s.add([tuple(p) for r in rings for p in r], faces, color)


def uniq(pts):
    out = []
    for p in pts:
        if not out or abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1]) > 1e-6:
            out.append(p)
    if len(out) > 1 and abs(out[0][0] - out[-1][0]) + abs(out[0][1] - out[-1][1]) < 1e-6:
        out.pop()
    return out


def thin(items, n):
    """At most n items, evenly spread, deterministic."""
    if len(items) <= n:
        return items
    return [items[int(i * len(items) / n)] for i in range(n)]


FACES = ("px", "nx", "pz", "nz")
NORMAL = {"px": (1, 0, 0), "nx": (-1, 0, 0), "pz": (0, 0, 1), "nz": (0, 0, -1)}


def is_long(face):
    return face in ("px", "nx")


def fspan(W, L, face):
    return L if is_long(face) else W


def fpt(W, L, face, u, v, d=0.0):
    """A point on a box face: u along the face (z on the long faces, x on the ends), v up, d outward."""
    hx, hz = W / 2, L / 2
    if face == "px":
        return (hx + d, v, u)
    if face == "nx":
        return (-hx - d, v, u)
    if face == "pz":
        return (u, v, hz + d)
    return (u, v, -hz - d)


def fslab(s, W, L, face, u0, u1, v0, v1, d0, d1, color):
    a, b = fpt(W, L, face, u0, v0, d0), fpt(W, L, face, u1, v1, d1)
    block(s, min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1]), min(a[2], b[2]), max(a[2], b[2]), color)


def fstud(s, W, L, face, u, v, r, h, color, d=0.0, sides=4, lift=0.0):
    ax = NORMAL[face]
    axis = (ax[0], ax[1] + lift, ax[2])
    stud(s, fpt(W, L, face, u, v, d), axis, r, h, color, sides)


def frect(s, W, L, face, u, v, w, h, ang, d0, d1, color):
    """A rectangle w by h centred at (u, v) on a face, turned by ang radians, from depth d0 to d1."""
    ca, sa = math.cos(ang), math.sin(ang)
    corners = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    pts = [(u + a * ca - b * sa, v + a * sa + b * ca) for a, b in corners]
    hull(s, [fpt(W, L, face, a, b, d0) for a, b in pts], [fpt(W, L, face, a, b, d1) for a, b in pts], color)


def fpoly(s, W, L, face, uv, d0, d1, color):
    hull(s, [fpt(W, L, face, a, b, d0) for a, b in uv], [fpt(W, L, face, a, b, d1) for a, b in uv], color)


def fdisc(s, W, L, face, u, v, r, d0, d1, color, n=16, spin=0.0):
    uv = [(u + r * math.cos(spin + math.tau * i / n), v + r * math.sin(spin + math.tau * i / n)) for i in range(n)]
    fpoly(s, W, L, face, uv, d0, d1, color)


def fsector(s, W, L, face, u, v, r0, r1, a0, a1, d0, d1, color, step=10.0):
    """An annular sector from angle a0 to a1 (degrees, from straight up, clockwise), cut in convex pieces."""
    n = max(1, int(math.ceil(abs(a1 - a0) / step)))
    for i in range(n):
        p = math.radians(a0 + (a1 - a0) * i / n)
        q = math.radians(a0 + (a1 - a0) * (i + 1) / n)
        uv = [(u + r0 * math.sin(p), v + r0 * math.cos(p)), (u + r1 * math.sin(p), v + r1 * math.cos(p)),
              (u + r1 * math.sin(q), v + r1 * math.cos(q)), (u + r0 * math.sin(q), v + r0 * math.cos(q))]
        fpoly(s, W, L, face, uv, d0, d1, color)


def faces_of(kind):
    return {"long": ("px", "nx"), "end": ("pz", "nz"), "all": FACES}[kind]


def planks(s, W, L, y0, y1, width, base, other, k0=0, depth=0.1, colorfn=None):
    """Vertical plank sheathing on all four faces: slabs depth deep (a recess), a hair apart so the core shows in the joints."""
    for fi, face in enumerate(FACES):
        span = fspan(W, L, face)
        n = max(1, round(span / width))
        w = span / n
        for i in range(n):
            u0 = -span / 2 + i * w
            col = colorfn(face, i) if colorfn else tone(base, other, k0 + i * 3 + fi, 0.35)
            fslab(s, W, L, face, u0 + 0.012, u0 + w - 0.012, y0, y1, -depth, 0.0, col)


def courses(s, W, L, y0, y1, n, base, other, relief=0.03, k0=0):
    """Board-formed concrete: n courses, alternate ones inset by relief (a recess), the top course flush."""
    hx, hz = W / 2, L / 2
    h = (y1 - y0) / n
    for i in range(n):
        ins = relief if (n - 1 - i) % 2 else 0.0
        block(s, -hx + ins, hx - ins, y0 + i * h, y0 + (i + 1) * h, -hz + ins, hz - ins, tone(base, other, k0 + i, 0.32))


def ring_band(s, W, L, y0, y1, color, out=0.08):
    hx, hz = W / 2, L / 2
    block(s, -hx - out, hx + out, y0, y1, -hz - out, hz + out, color)


def box_col(s, W, L, H):
    block(s, -W / 2, W / 2, 0.0, H, -L / 2, L / 2, DARK)


def base_weeds(s, W, L, k0, count=10, faces=FACES, color=SAGE):
    """Weeds at the base: short sage cones leaning off the face, 0.12 m, within the hugging rule."""
    items = []
    for face in faces:
        span = fspan(W, L, face)
        for i in range(count if is_long(face) else max(3, count // 3)):
            items.append((face, -span / 2 + span * (i + 0.5 + 0.3 * ((i * 5 + k0) % 3 - 1)) / (count if is_long(face) else max(3, count // 3))))
    for j, (face, u) in enumerate(items):
        fstud(s, W, L, face, u, 0.05 + 0.1 * (j % 3), 0.05 + 0.02 * (j % 2), 0.12, tone(color, JUNIPER, j + k0, 0.4), sides=3, lift=0.6)


def streaks(s, W, L, k0, faces, y_lo, y_hi, count, color=VARNISH):
    for j in range(count):
        face = faces[j % len(faces)]
        span = fspan(W, L, face)
        u = -span / 2 + span * (((j * 7 + k0) % 17) + 0.5) / 17
        v0 = y_lo + (y_hi - y_lo) * (((j * 3 + k0) % 5) / 8.0)
        fslab(s, W, L, face, u, u + 0.12 + 0.06 * (j % 3), v0, v0 + 1.5 + (j % 4) * 0.7, 0.0, 0.012, color)


# ------------------------------------------------------------------ A. timber bent towers

def bent_straps(H):
    out, y = [], 4.0
    while y < H - 1.5:
        if abs(y - H / 2) > 2.4 and not (H - 6.4 < y < H - 2.8):
            out.append(y)
        y += 10.0
    return out


def bent_body(s, H):
    W, L = 4.0, 12.0
    hx, hz = W / 2, L / 2
    block(s, -hx + 0.1, hx - 0.1, 0.9, H - 0.4, -hz + 0.1, hz - 0.1, TIMBER_DK)
    planks(s, W, L, 0.9, H - 0.4, 0.4, TIMBER, TIMBER_DK)
    block(s, -hx - 0.12, hx + 0.12, 0.0, 1.0, -hz - 0.12, hz + 0.12, FOOTING)
    for sx in (-1, 1):
        for sz in (-1, 1):
            xa, xb = sorted((sx * (hx - 0.4), sx * (hx + 0.07)))
            za, zb = sorted((sz * (hz - 0.4), sz * (hz + 0.07)))
            block(s, xa, xb, 1.0, H - 0.4, za, zb, tone(TIMBER_DK, TIMBER, sx + 2 * sz, 0.4))
    block(s, -hx - 0.1, hx + 0.1, H - 0.4, H, -hz - 0.1, hz + 0.1, TIMBER_DK)
    for k, y in enumerate(bent_straps(H)):
        ring_band(s, W, L, y - 0.25, y + 0.25, tone(STEEL, DARK, k), 0.10)
    # Diagonal braces, one per 10 m bay, alternating hands, flush on the long faces (0.16 square, at most 0.12 proud).
    ys = [1.5] + [y for y in range(10, int(H - 3), 10)] + [H - 3.0]
    for face in ("px", "nx"):
        for k in range(len(ys) - 1):
            a, b = (-5.2, ys[k]), (5.2, ys[k + 1])
            if k % 2:
                a, b = (5.2, ys[k]), (-5.2, ys[k + 1])
            strut(s, fpt(W, L, face, a[0], a[1]), fpt(W, L, face, b[0], b[1]), 0.16, tone(TIMBER_DK, TIMBER, k, 0.5))
    mid = H / 2
    for face in ("px", "nx"):
        # Speed-tick band: a cream ground and twelve iron-oxide stripes, 0.5 m on 1.0 m, readable as riders pass.
        fslab(s, W, L, face, -5.9, 5.9, mid - 1.5, mid + 1.5, 0.0, 0.03, CREAM)
        for i in range(12):
            fslab(s, W, L, face, -5.9 + i * 1.0, -5.4 + i * 1.0, mid - 1.5, mid + 1.5, 0.0, 0.045, OXIDE)
        # Bent number board: blank white board with black tick stripes, no text.
        fslab(s, W, L, face, -2.4, 2.4, H - 6.0, H - 3.2, 0.0, 0.06, BOARD)
        for i in range(7):
            fslab(s, W, L, face, -2.1 + i * 0.7 - 0.07, -2.1 + i * 0.7 + 0.07, H - 5.6, H - 3.6, 0.06, 0.085, DARK)


def bent_d1(s, H):
    W, L = 4.0, 12.0
    for k, y in enumerate(bent_straps(H)):
        for face in FACES:
            for u in ([-5.0, -3.0, -1.0, 1.0, 3.0, 5.0] if is_long(face) else [-1.2, 1.2]):
                fstud(s, W, L, face, u, y, 0.07, 0.04, tone(STEEL, DARK, k + int(u * 3)), d=0.10, sides=4)
    for face in ("px", "nx"):
        for u in (-2.2, 2.2):
            for v in (H - 5.8, H - 3.4):
                fstud(s, W, L, face, u, v, 0.05, 0.04, STEEL, d=0.06)
    for sx in (-1, 1):
        for sz in (-1, 1):
            for v in (H - 6.0, H - 14.0):
                if v > 3:
                    stud(s, (sx * (W / 2 + 0.1), v, sz * (L / 2 - 0.25)), (sx, 0, 0), 0.06, 0.04, tone(STEEL, DARK, int(v)), 4)


def bent_d2(s, H):
    W, L = 4.0, 12.0
    streaks(s, W, L, int(H), ("px", "nx", "pz", "nz"), 1.5, H * 0.6, 16)
    base_weeds(s, W, L, int(H), 9)


# ------------------------------------------------------------------ A. survey mast

def mast_body(s):
    W, L, H = 4.0, 12.0, 40.0
    hx, hz = W / 2, L / 2
    courses(s, W, L, 0.0, 4.0, 8, CONCRETE, FORM)
    block(s, -hx + 0.1, hx - 0.1, 4.0, H - 0.3, -hz + 0.1, hz - 0.1, TIMBER_DK)
    for b in range(18):
        y0, y1 = 4.0 + b * 2.0, 4.0 + (b + 1) * 2.0
        block(s, -hx, hx, y0, y1, -hz, hz, tone(OXIDE if b % 2 == 0 else CREAM, TIMBER_DK, b, 0.12))
    for face in FACES:
        span = fspan(W, L, face)
        n = int(span / (0.6 if is_long(face) else 0.8))
        for i in range(1, n):
            u = -span / 2 + span * i / n
            fslab(s, W, L, face, u - 0.02, u + 0.02, 4.1, H - 0.5, 0.0, 0.02, TIMBER_DK)
    # Copper survey plate on the +X face, with a string-line pulley block flush at the top of the +Z end.
    fslab(s, W, L, "px", -0.9, 0.9, 5.0, 6.4, 0.0, 0.07, COPPER)
    fslab(s, W, L, "px", -0.7, 0.7, 5.2, 6.2, 0.07, 0.085, tone(COPPER, VARNISH, 3, 0.25))
    fslab(s, W, L, "pz", -0.5, 0.5, H - 2.0, H - 0.9, 0.0, 0.12, STEEL)
    fdisc(s, W, L, "pz", 0.0, H - 1.45, 0.36, 0.12, 0.15, COPPER, 12)


def mast_d1(s):
    W, L, H = 4.0, 12.0, 40.0
    for u in (-0.75, 0.75):
        for v in (5.15, 6.25):
            fstud(s, W, L, "px", u, v, 0.05, 0.05, STEEL, d=0.07)
    for k in range(10):
        y = 6.0 + k * 3.7
        for face in ("px", "nx"):
            fstud(s, W, L, face, -4.0 + (k % 3) * 4.0, y, 0.06, 0.04, STEEL, d=0.0)
    for v in (H - 1.85, H - 1.05):
        for u in (-0.35, 0.35):
            fstud(s, W, L, "pz", u, v, 0.045, 0.03, DARK, d=0.12)
    for k in range(14):
        y = 0.5 + k * 0.25
        if y < 3.8:
            fstud(s, W, L, "pz" if k % 2 else "nz", -1.4 + (k % 5) * 0.7, y, 0.045, 0.03, DARK)


def mast_d2(s):
    W, L, H = 4.0, 12.0, 40.0
    streaks(s, W, L, 7, ("px", "nx", "pz", "nz"), 0.3, 18.0, 18)
    base_weeds(s, W, L, 4, 10)


# ------------------------------------------------------------------ A. surge pylons

def pylon_body(s, H):
    W, L = 4.0, 12.0
    n = round(H / 1.4)
    courses(s, W, L, 0.0, H, n, CONCRETE, FORM)
    y = 6.0
    while y < H - 4.5:
        ring_band(s, W, L, y, y + 0.3, tone(FORM, CONCRETE, int(y)), 0.08)
        y += 6.0
    for face in ("px", "nx"):
        for v, w in ((H - 2.7, 0.6), (H - 4.6, 0.4)):
            fslab(s, W, L, face, -5.5, 5.5, v - w / 2, v + w / 2, 0.0, 0.04, STEEL)
        for i in range(5):
            u = -4.5 + i * 2.25
            fstud(s, W, L, face, u, H - 2.7, 0.14, 0.09, GLASS, d=0.04, sides=6)
            fstud(s, W, L, face, u, H - 3.9, 0.06, 0.14, COPPER, d=0.0, sides=6)
            fstud(s, W, L, face, u, H - 5.3, 0.1, 0.1, GLASS, d=0.04, sides=6)
    for face in ("pz", "nz"):
        fslab(s, W, L, face, -1.8, 1.8, H - 3.0, H - 2.4, 0.0, 0.05, STEEL)


def pylon_d1(s, H):
    W, L = 4.0, 12.0
    for i in range(round(H / 1.4)):
        y = 0.7 + i * 1.4
        if y > H - 0.5:
            break
        for face in faces_of("long"):
            fstud(s, W, L, face, -3.5 + (i % 4) * 2.4, y, 0.05, 0.03, DARK)
    for face in ("px", "nx"):
        for u in (-5.2, 5.2):
            for v in (H - 2.7, H - 4.6):
                fstud(s, W, L, face, u, v, 0.06, 0.04, DARK, d=0.04)


def pylon_d2(s, H):
    W, L = 4.0, 12.0
    streaks(s, W, L, int(H), ("px", "nx", "pz", "nz"), 1.0, H * 0.75, 18)
    base_weeds(s, W, L, int(H), 10)


# ------------------------------------------------------------------ A. timber crib piers and wall

def crib_layout(L, W):
    nA = max(2, round(W / 3.0) + 1)
    nB = max(2, round(L / 3.0) + 1)
    xs = [-W / 2 + 0.5 + (W - 1.0) * i / (nA - 1) for i in range(nA)]
    zs = [-L / 2 + 0.5 + (L - 1.0) * i / (nB - 1) for i in range(nB)]
    return xs, zs


def crib_body(s, L, H, W):
    hx, hz = W / 2, L / 2
    xs, zs = crib_layout(L, W)
    nc = int(H) - 1
    for k0 in range(0, nc, 4):
        k1 = min(nc, k0 + 4)
        block(s, -hx + 0.25, hx - 0.25, k0, k1, -hz + 0.25, hz - 0.25, tone(SAND, VARNISH, k0 // 4, 0.55))
    for k in range(nc):
        y0, y1 = k + 0.015, k + 0.985
        if k % 2 == 0:
            for i, xc in enumerate(xs):
                block(s, xc - 0.5, xc + 0.5, y0, y1, -hz, hz, tone(TIMBER, TIMBER_DK, k + i * 2, 0.5))
        else:
            for i, zc in enumerate(zs):
                block(s, -hx, hx, y0, y1, zc - 0.5, zc + 0.5, tone(TIMBER, TIMBER_DK, k + i * 2 + 1, 0.5))
    # Timber cap: whole-footprint planks along Z, flush top.
    n = max(2, round(W / 1.0))
    for i in range(n):
        block(s, -hx + W * i / n + 0.01, -hx + W * (i + 1) / n - 0.01, H - 1.0, H, -hz, hz, tone(TIMBER_LT, TIMBER_DK, i, 0.4))


def crib_d1(s, L, H, W):
    xs, zs = crib_layout(L, W)
    pins = []
    for k in range(int(H) - 1):
        if k % 2 == 0:
            for xc in xs:
                for face in ("pz", "nz"):
                    pins.append((face, xc, k + 0.5))
        else:
            for zc in zs:
                for face in ("px", "nx"):
                    pins.append((face, zc, k + 0.5))
    for j, (face, u, v) in enumerate(thin(pins, 118)):
        fstud(s, W, L, face, u, v, 0.09, 0.09, tone(STEEL, DARK, j), d=0.0, sides=4)


def crib_d2(s, L, H, W):
    streaks(s, W, L, int(L + H), ("px", "nx", "pz", "nz"), 1.0, H * 0.8, 24)
    base_weeds(s, W, L, int(L), 8)


# ------------------------------------------------------------------ A. anchor block

def octa_pts(a, y):
    r = a / math.cos(math.pi / 8)
    return [(r * math.cos(math.pi / 8 + math.tau * k / 8), y, r * math.sin(math.pi / 8 + math.tau * k / 8)) for k in range(8)]


def octa(s, a, y0, y1, color):
    hull(s, octa_pts(a, y0), octa_pts(a, y1), color)


def octa_ring(s, a0, a1, y0, y1, color):
    p0, q0, p1, q1 = octa_pts(a0, y0), octa_pts(a1, y0), octa_pts(a0, y1), octa_pts(a1, y1)
    for k in range(8):
        j = (k + 1) % 8
        hull(s, [p0[k], p0[j], q0[j], q0[k]], [p1[k], p1[j], q1[j], q1[k]], color)


def anchor_body(s):
    W, L, H = 8.0, 16.0, 28.0
    hx, hz = W / 2, L / 2
    t = 0.3
    courses(s, W, L, 0.0, H - t, 28, CONCRETE, FORM)
    for y in (4.0, 9.0, 14.0):
        ring_band(s, W, L, y, y + 0.3, tone(FORM, CONCRETE, int(y)), 0.08)
    for k, y in enumerate((H - 4.0, H - 2.6)):
        ring_band(s, W, L, y, y + 0.5, STEEL, 0.12)
    a = 3.0
    top = H - t
    for sx in (-1, 1):
        block(s, min(sx * a, sx * hx), max(sx * a, sx * hx), top, H, -hz, hz, CONCRETE)
    for sz in (-1, 1):
        block(s, -a, a, top, H, min(sz * a, sz * hz), max(sz * a, sz * hz), CONCRETE)
    c = a * math.tan(math.pi / 8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            tri = [(sx * a, top, sz * c), (sx * a, top, sz * a), (sx * c, top, sz * a)]
            up = [(x, H, z) for x, _, z in tri]
            hull(s, tri, up, tone(CONCRETE, FORM, sx + 2 * sz))
    octa_ring(s, 2.3, a, top, H, FORM)
    octa_ring(s, 1.5, 2.3, top, H, STEEL)
    octa_ring(s, 1.0, 1.5, top, H, tone(IRON, DARK, 2))
    octa(s, 1.0, top, H, DARK)
    for face in ("px", "nx"):
        for u in (-6.0, -2.0, 2.0, 6.0):
            fslab(s, W, L, face, u - 0.4, u + 0.4, H - 4.2, H - 2.4, 0.12, 0.14, tone(STEEL, DARK, int(u)))


def anchor_d1(s):
    W, L, H = 8.0, 16.0, 28.0
    for k, y in enumerate((H - 3.75, H - 2.35)):
        for face in FACES:
            for u in ([-7.0, -4.0, -1.5, 1.5, 4.0, 7.0] if is_long(face) else [-2.5, 0.0, 2.5]):
                fstud(s, W, L, face, u, y, 0.08, 0.03, DARK, d=0.12)
    for i in range(14):
        y = 1.0 + i * 1.9
        for face in ("px", "nx"):
            fstud(s, W, L, face, -6.0 + (i % 5) * 3.0, y, 0.05, 0.03, DARK)


def anchor_d2(s):
    W, L, H = 8.0, 16.0, 28.0
    streaks(s, W, L, 11, ("px", "nx", "pz", "nz"), 1.0, 20.0, 22)
    base_weeds(s, W, L, 3, 9)


# ------------------------------------------------------------------ A. gatehouse and annex hall

def roof_tiles(s, W, L, H, t, nx, nz, base, other):
    hx, hz = W / 2, L / 2
    for i in range(nx):
        for j in range(nz):
            block(s, -hx + W * i / nx + 0.01, -hx + W * (i + 1) / nx - 0.01, H - t, H, -hz + L * j / nz + 0.01, -hz + L * (j + 1) / nz - 0.01,
                  tone(base, other, i * 3 + j * 5, 0.3))


def gatehouse_body(s):
    W, L, H = 12.0, 12.0, 10.0
    courses(s, W, L, 0.0, H - 0.4, 10, CONCRETE, FORM)
    roof_tiles(s, W, L, H, 0.4, 3, 3, FORM, CONCRETE)
    ring_band(s, W, L, H - 1.3, H - 0.9, FORM, 0.1)
    ring_band(s, W, L, 0.0, 0.6, FOOTING, 0.08)
    # Door on the +Z face: timber leaf, iron straps, a lintel and jambs.
    fslab(s, W, L, "pz", -1.1, 1.1, 0.0, 3.4, 0.0, 0.06, TIMBER)
    for v in (0.8, 1.7, 2.6):
        fslab(s, W, L, "pz", -1.1, 1.1, v - 0.1, v + 0.1, 0.06, 0.09, STEEL)
    fslab(s, W, L, "pz", -1.5, 1.5, 3.4, 3.9, 0.0, 0.12, FORM)
    for sg in (-1, 1):
        fslab(s, W, L, "pz", min(sg * 1.1, sg * 1.5), max(sg * 1.1, sg * 1.5), 0.0, 3.4, 0.0, 0.12, FORM)
    # Gate wheel: spoked hand wheel on a short stem, mounted on the +Z face right of the door.
    verts, faces = _wheel(0.0, 0.0, 0.0, 0.8)
    s.add([(3.6 + a, 6.2 + b, L / 2 + 0.08 + c) for a, b, c in verts], faces, COPPER)
    fslab(s, W, L, "pz", 3.55, 3.65, 6.15, 6.25, 0.0, 0.13, STEEL)
    # Flush window panes.
    for face in ("px", "nx"):
        for u in (-3.0, 3.0):
            fslab(s, W, L, face, u - 0.8, u + 0.8, 5.0, 6.6, 0.0, 0.02, DARK)
    fslab(s, W, L, "nz", -2.0, 2.0, 5.0, 6.6, 0.0, 0.02, DARK)


def gatehouse_d1(s):
    W, L, H = 12.0, 12.0, 10.0
    for sg in (-1, 1):
        for v in (0.5, 1.5, 2.5, 3.5):
            fstud(s, W, L, "pz", sg * 1.3, v, 0.05, 0.03, DARK, d=0.12)
    for i in range(12):
        for face in FACES:
            fstud(s, W, L, face, -4.5 + (i % 4) * 3.0, 0.7 + (i // 4) * 2.7 + (i % 2) * 0.5, 0.05, 0.03, DARK)
    for a in range(8):
        ang = math.tau * a / 8
        stud(s, (3.6 + 0.8 * math.cos(ang) * 0.9, 6.2 + 0.8 * math.sin(ang) * 0.9, L / 2 + 0.11), (0, 0, 1), 0.03, 0.03, STEEL, 4)


def gatehouse_d2(s):
    W, L, H = 12.0, 12.0, 10.0
    streaks(s, W, L, 9, ("px", "nx", "pz", "nz"), 0.5, 5.0, 14)
    base_weeds(s, W, L, 6, 6)


def annex_body(s):
    W, L, H = 24.0, 40.0, 14.0
    courses(s, W, L, 0.0, H - 0.4, 14, CONCRETE, FORM)
    roof_tiles(s, W, L, H, 0.4, 3, 5, FORM, CONCRETE)
    ring_band(s, W, L, H - 1.6, H - 1.2, FORM, 0.1)
    ring_band(s, W, L, 0.0, 0.7, FOOTING, 0.08)
    for fx in range(-16, 17, 8):
        for face in ("nx",):
            fslab(s, W, L, face, fx - 0.5, fx + 0.5, 0.0, H - 0.4, 0.0, 0.1, tone(FORM, CONCRETE, fx))
    # Pipe runs along the +X long face: three 8-sided pipes (r 0.13), flanges every 6 m, two vertical risers.
    for k, v in enumerate((2.6, 3.7, 4.8)):
        solid(s, disc(W / 2, v, 0.13, 8, math.pi / 8), -17.0, 17.0, tone(STEEL, OXIDE, k, 0.3))
        for z in range(-15, 16, 6):
            solid(s, disc(W / 2, v, 0.145, 8, math.pi / 8), z - 0.1, z + 0.1, tone(OXIDE, DARK, z))
    for k, z in enumerate((-17.0, 17.0)):
        n = 8
        pa = [(W / 2 + 0.13 * math.cos(math.pi / 8 + math.tau * i / n), 2.6, z + 0.13 * math.sin(math.pi / 8 + math.tau * i / n)) for i in range(n)]
        pb = [(x, 8.6, zz) for x, _, zz in pa]
        hull(s, pa, pb, tone(STEEL, OXIDE, k, 0.3))
    # The pressure dial on the +X face: iron rim, cream face, red band, ticks, needle, copper hub.
    u, v = 6.0, 9.4
    fdisc(s, W, L, "px", u, v, 2.4, 0.0, 0.1, STEEL, 24)
    fdisc(s, W, L, "px", u, v, 2.15, 0.1, 0.12, CREAM, 24)
    fsector(s, W, L, "px", u, v, 1.35, 1.95, 30.0, 120.0, 0.12, 0.14, OXIDE)
    for i in range(11):
        ang = math.radians(-120 + i * 24)
        frect(s, W, L, "px", u + 1.75 * math.sin(ang), v + 1.75 * math.cos(ang), 0.07, 0.35, -ang, 0.12, 0.135, DARK)
    ang = math.radians(48)
    frect(s, W, L, "px", u + 0.65 * math.sin(ang), v + 0.65 * math.cos(ang), 0.1, 1.3, -ang, 0.12, 0.14, STEEL)
    fdisc(s, W, L, "px", u, v, 0.22, 0.12, 0.15, COPPER, 12)


def annex_d1(s):
    W, L, H = 24.0, 40.0, 14.0
    u, v = 6.0, 9.4
    for i in range(12):
        ang = math.tau * i / 12
        fstud(s, W, L, "px", u + 2.28 * math.cos(ang), v + 2.28 * math.sin(ang), 0.05, 0.04, DARK, d=0.1)
    for z in range(-15, 16, 6):
        for vv in (2.6, 4.8):
            stud(s, (W / 2 + 0.1, vv, z + 0.1), (1, 0, 0), 0.04, 0.04, DARK, 4)
    for face in ("nx", "pz", "nz"):
        for i in range(16):
            fstud(s, W, L, face, -fspan(W, L, face) / 2 + 2.0 + i * (fspan(W, L, face) - 4.0) / 15.0, 1.5 + (i % 4) * 2.8, 0.05, 0.03, DARK)


def annex_d2(s):
    W, L, H = 24.0, 40.0, 14.0
    streaks(s, W, L, 13, ("px", "nx", "pz", "nz"), 0.5, 9.0, 26)
    base_weeds(s, W, L, 8, 12)


# ------------------------------------------------------------------ A. crew bunk ledge

def ledge_body(s):
    W, L, H = 10.0, 120.0, 1.0
    hx, hz = W / 2, L / 2
    nc = 30
    for j in range(nc):
        z0, z1 = -hz + L * j / nc, -hz + L * (j + 1) / nc
        for i in range(2):
            x0, x1 = -hx + hx * i, -hx + hx * (i + 1)
            block(s, x0 + 0.01, x1 - 0.01, 0.0, H, z0 + 0.012, z1 - 0.012, tone(TIMBER_LT, TIMBER_DK, j * 2 + i, 0.4))
    for j in range(nc + 1):
        z = -hz + L * j / nc
        block(s, -hx + 0.3, hx - 0.3, -0.6, 0.0, z - 0.15, z + 0.15, tone(TIMBER, TIMBER_DK, j, 0.45))
    for sx in (-1, 1):
        block(s, sx * 4.5 - 0.2, sx * 4.5 + 0.2, -0.9, -0.6, -hz, hz, tone(TIMBER_DK, TIMBER, 2, 0.3))
    for z in range(-60, 61, 12):
        zc = max(-hz + 0.2, min(hz - 0.2, float(z)))
        for sx in (-1, 1):
            block(s, sx * 4.5 - 0.2, sx * 4.5 + 0.2, -5.0, -0.9, zc - 0.2, zc + 0.2, tone(TIMBER, TIMBER_DK, z, 0.4))
            strut(s, (sx * 4.5, -3.2, zc), (sx * 2.7, -0.6, zc), 0.16, tone(TIMBER_DK, TIMBER, z + 1, 0.4))
            strut(s, (sx * 4.5, -3.2, zc), (sx * 4.5, -3.2, zc + 3.0), 0.16, tone(TIMBER_DK, TIMBER, z + 2, 0.4)) if zc + 3.0 <= hz else None
        block(s, -4.5, 4.5, -3.4, -3.0, zc - 0.12, zc + 0.12, tone(TIMBER_DK, TIMBER, z + 3, 0.4))
    # Numbered bunk door boards on the +X edge: blank boards, one to four tick stripes by bunk.
    for j in range(nc):
        zc = -hz + L * (j + 0.5) / nc
        fslab(s, W, L, "px", zc - 0.45, zc + 0.45, 0.1, 0.9, 0.0, 0.06, BOARD)
        n = 1 + j % 4
        for t in range(n):
            u = zc - 0.06 * (n - 1) * 2 / 2 + 0.12 * t - 0.06 * (n - 1)
            fslab(s, W, L, "px", u - 0.02, u + 0.02, 0.25, 0.75, 0.06, 0.08, DARK)


def ledge_d1(s):
    W, L, H = 10.0, 120.0, 1.0
    for j in range(30):
        zc = -60.0 + 4.0 * (j + 0.5)
        for dz in (-0.35, 0.35):
            fstud(s, W, L, "px", zc + dz, 0.5, 0.04, 0.03, DARK, d=0.06)
    for j in range(0, 31, 2):
        z = max(-59.9, min(59.9, -60.0 + 4.0 * j))
        for sx in (-1, 1):
            stud(s, (sx * 4.3, -0.3, z), (sx, 0, 0), 0.06, 0.05, STEEL, 4)
    for z in range(-60, 61, 12):
        z = max(-59.8, min(59.8, z))
        for sx in (-1, 1):
            stud(s, (sx * 4.7, -1.5, float(z)), (sx, 0, 0), 0.07, 0.04, STEEL, 4)


def ledge_d2(s):
    W, L, H = 10.0, 120.0, 1.0
    for j in range(24):
        z = -57.0 + j * 4.7
        fslab(s, W, L, "px", z, z + 0.14, 0.1, 0.9, 0.0, 0.012, VARNISH)
    for z in range(-60, 61, 12):
        z = max(-59.7, min(59.7, z))
        for sx in (-1, 1):
            for i in range(3):
                stud(s, (sx * 4.5 + 0.25 * (i - 1), -4.95, z + 0.1 * (i % 2)), (0, 0.8, 0.2), 0.05, 0.12, tone(SAGE, JUNIPER, z + i, 0.4), 3)


# ------------------------------------------------------------------ B. wedges

def wy(L, H, z):
    return H * (L / 2 - z) / L


def wedge_cell(s, W, L, H, x0, x1, z0, z1, color):
    pts = uniq([(z0, 0.0), (z1, 0.0), (z1, wy(L, H, z1)), (z0, wy(L, H, z0))])
    hull(s, [(x0, y, z) for z, y in pts], [(x1, y, z) for z, y in pts], color)


def wedge_col(s, L, H, W):
    wedge_cell(s, W, L, H, -W / 2, W / 2, -L / 2, L / 2, DARK)


def side_poly(s, W, sign, pts, d0, d1, color):
    pts = uniq(pts)
    x0, x1 = sign * (W / 2 + d0), sign * (W / 2 + d1)
    hull(s, [(x0, y, z) for z, y in pts], [(x1, y, z) for z, y in pts], color)


def side_band(s, W, L, H, sign, ya, yb, d0, d1, color):
    hz = L / 2
    za, zb = hz - ya * L / H, hz - yb * L / H
    side_poly(s, W, sign, [(-hz, ya), (za, ya), (zb, yb), (-hz, yb)], d0, d1, color)


def side_post(s, W, L, H, sign, z0, z1, d1, color, gap=0.06):
    z1c = min(z1, L / 2)
    top = lambda z: max(0.0, wy(L, H, z) - gap)
    side_poly(s, W, sign, [(z0, 0.0), (z1c, 0.0), (z1c, top(z1c)), (z0, top(z0))], 0.0, d1, color)


def edges_columns(edges, W):
    return list(zip(edges[:-1], edges[1:]))


def apron_body(s):
    L, H, W = 44.0, 0.5, 30.0
    nx, nz = 6, 8
    for i in range(nx):
        for j in range(nz):
            wedge_cell(s, W, L, H, -W / 2 + W * i / nx + 0.0, -W / 2 + W * (i + 1) / nx, -L / 2 + L * j / nz, -L / 2 + L * (j + 1) / nz,
                       tone(CONCRETE, FORM, i * 5 + j * 3, 0.35))


def apron_d1(s):
    L, H, W = 44.0, 0.5, 30.0
    for j in range(1, 8):
        z = -L / 2 + L * j / 8
        for sg in (-1, 1):
            side_poly(s, W, sg, [(z - 0.1, 0.0), (z + 0.1, 0.0), (z + 0.1, wy(L, H, z + 0.1)), (z - 0.1, wy(L, H, z - 0.1))], 0.0, 0.012, VARNISH)
    for i in range(1, 6):
        x = -W / 2 + W * i / 6
        z0, z1 = -L / 2 + 2.0, L / 2 - 2.0
        pts = [(z0, wy(L, H, z0)), (z1, wy(L, H, z1)), (z1, wy(L, H, z1) + 0.012), (z0, wy(L, H, z0) + 0.012)]
        hull(s, [(x - 0.04, y, z) for z, y in pts], [(x + 0.04, y, z) for z, y in pts], VARNISH)


def apron_d2(s):
    L, H, W = 44.0, 0.5, 30.0
    for k in range(18):
        x = -W / 2 + 1.0 + (k * 13 % 28)
        z = -L / 2 + 1.5 + (k * 7 % 39)
        pts = [(z, wy(L, H, z)), (z + 1.2, wy(L, H, z + 1.2)), (z + 1.2, wy(L, H, z + 1.2) + 0.01), (z, wy(L, H, z) + 0.01)]
        hull(s, [(x, y, zz) for zz, y in pts], [(x + 0.5 + 0.15 * (k % 3), y, zz) for zz, y in pts], tone(SAND, VARNISH, k, 0.5))
    for k in range(10):
        stud(s, (-W / 2 + 0.03, 0.08, -L / 2 + 4.0 + k * 4.0), (-1, 0.5, 0), 0.05, 0.1, tone(SAGE, JUNIPER, k, 0.4), 3)


GAP = [272.9, 32.0, 24.0]


def gap_body(s):
    L, H, W = GAP
    hz = L / 2
    xedges = [-12.0, -11.4, -5.7, -5.4, -0.15, 0.15, 5.4, 5.7, 11.4, 12.0]
    cols = edges_columns(xedges, W)
    nz = 34
    for j in range(nz):
        z0, z1 = -hz + L * j / nz, -hz + L * (j + 1) / nz
        for i, (xa, xb) in enumerate(cols):
            if i in (0, 8):
                color = tone(TIMBER_DK, TIMBER, j + i, 0.4)
            elif i in (2, 6):
                color = CREAM if j % 2 == 0 else tone(TIMBER_LT, TIMBER, j, 0.3)
            elif i == 4:
                color = BOARD if j % 2 == 1 else tone(TIMBER_LT, TIMBER, j + 1, 0.3)
            else:
                color = tone(TIMBER_LT, TIMBER, j * 2 + i, 0.45)
            wedge_cell(s, W, L, H, xa, xb, z0, z1, color)
    # Sheathed trestle framing on the two triangular side faces: posts, rails and X braces, 0.1 m proud.
    zs = [-hz + 0.25 + (L - 0.5) * k / 20 for k in range(21)]
    for sg in (-1, 1):
        for k, z in enumerate(zs):
            side_post(s, W, L, H, sg, z - 0.25, z + 0.25, 0.1, tone(TIMBER_DK, TIMBER, k, 0.4))
        for k, y in enumerate((8.0, 16.0, 24.0)):
            side_band(s, W, L, H, sg, y - 0.2, y + 0.2, 0.0, 0.08, tone(TIMBER, TIMBER_DK, k, 0.4))
        for k in range(20):
            za, zb = zs[k], zs[k + 1]
            ya = 0.5
            yb = min(wy(L, H, zb) - 0.6, 7.5)
            if yb < 2.0:
                continue
            if k % 2:
                strut(s, (sg * W / 2, ya, zb), (sg * W / 2, yb, za), 0.16, tone(TIMBER_DK, TIMBER, k + 1, 0.4)) if wy(L, H, za) > yb + 0.3 else None
            else:
                strut(s, (sg * W / 2, ya, za), (sg * W / 2, yb, zb), 0.16, tone(TIMBER_DK, TIMBER, k + 1, 0.4))
    # End face (z = -L/2, vertical): sheathing planks, rails, posts.
    for i in range(30):
        fslab(s, W, L, "nz", -W / 2 + W * i / 30 + 0.01, -W / 2 + W * (i + 1) / 30 - 0.01, 0.0, H, 0.0, 0.05, tone(TIMBER_LT, TIMBER, i, 0.4))
    for k, y in enumerate((8.0, 16.0, 24.0)):
        fslab(s, W, L, "nz", -W / 2, W / 2, y - 0.25, y + 0.25, 0.05, 0.12, tone(TIMBER, TIMBER_DK, k, 0.4))
    for k, x in enumerate((-12.0, -6.0, 0.0, 6.0, 12.0)):
        fslab(s, W, L, "nz", max(-W / 2, x - 0.3), min(W / 2, x + 0.3), 0.0, H, 0.05, 0.12, tone(TIMBER_DK, TIMBER, k, 0.4))


def gap_d1(s):
    L, H, W = GAP
    hz = L / 2
    zs = [-hz + 0.25 + (L - 0.5) * k / 20 for k in range(21)]
    items = []
    for sg in (-1, 1):
        for k, z in enumerate(zs):
            for y in (2.0, 5.0, 9.0, 13.0):
                if wy(L, H, z) - 0.8 > y:
                    items.append((sg, z, y))
    for j, (sg, z, y) in enumerate(thin(items, 84)):
        stud(s, (sg * (W / 2 + 0.1), y, z), (sg, 0, 0), 0.07, 0.04, tone(STEEL, DARK, j), 4)
    for k in range(6):
        for y in (6.0, 12.0, 18.0, 28.0):
            if y < H - 1.0:
                stud(s, (-11.0 + k * 4.4, y, -hz - 0.05), (0, 0, -1), 0.07, 0.05, tone(STEEL, DARK, k), 4)


def gap_d2(s):
    L, H, W = GAP
    hz = L / 2
    for j in range(24):
        z = -hz + 4.0 + j * 11.0
        for sg in (-1, 1):
            if (j + (sg > 0)) % 2:
                continue
            ytop = wy(L, H, z)
            if ytop > 3.0:
                side_poly(s, W, sg, [(z, 0.2), (z + 0.2, 0.2), (z + 0.2, wy(L, H, z + 0.2) * 0.8), (z, ytop * 0.8)], 0.0, 0.012, VARNISH)
    for j in range(16):
        z = -hz + 6.0 + j * 16.5
        x = -11.0 + (j * 7 % 22)
        pts = [(z, wy(L, H, z)), (z + 1.5, wy(L, H, z + 1.5)), (z + 1.5, wy(L, H, z + 1.5) + 0.012), (z, wy(L, H, z) + 0.012)]
        hull(s, [(x, y, zz) for zz, y in pts], [(x + 0.4, y, zz) for zz, y in pts], tone(SAND, VARNISH, j, 0.5))
    for k in range(10):
        stud(s, (-W / 2 - 0.02, 0.05, -hz + 3.0 + k * 3.0), (-1, 0.6, 0), 0.05, 0.1, tone(SAGE, JUNIPER, k, 0.4), 3)


ROAD = [438.0, 24.0, 36.0]


def road_body(s):
    L, H, W = ROAD
    hz = L / 2
    xedges = [-18.0, -17.2, -9.0, -4.4, -3.0, 3.0, 4.4, 9.0, 17.2, 18.0]
    cols = edges_columns(xedges, W)
    nz = 24
    for j in range(nz):
        z0, z1 = -hz + L * j / nz, -hz + L * (j + 1) / nz
        for i, (xa, xb) in enumerate(cols):
            if i in (0, 8):
                color = tone(TIMBER, TIMBER_DK, j + i, 0.5)
            elif i in (1, 7):
                color = tone(SAND, SLICK, j * 3 + i, 0.3)
            elif i in (3, 5):
                color = tone(VARNISH, SAND, j + i, 0.35)
            else:
                color = tone(SAND, CREAM, j * 2 + i, 0.3)
            wedge_cell(s, W, L, H, xa, xb, z0, z1, color)
    for k, (ya, yb) in enumerate(((1.0, 2.4), (4.2, 6.0), (8.0, 9.2), (12.0, 14.4), (17.0, 18.2), (21.0, 22.4))):
        for sg in (-1, 1):
            side_band(s, W, L, H, sg, ya, yb, 0.0, 0.03, tone(SLICK, CREAM, k, 0.45))
    for m in range(4):
        z = -hz + 50.0 + 100.0 * m
        for sg in (-1, 1):
            top = wy(L, H, z)
            if top < 2.9:
                continue
            side_poly(s, W, sg, [(z - 0.07, 0.0), (z + 0.07, 0.0), (z + 0.07, 2.6), (z - 0.07, 2.6)], 0.0, 0.1, STEEL)
            side_poly(s, W, sg, [(z - 0.5, 1.4), (z + 0.5, 1.4), (z + 0.5, 2.6), (z - 0.5, 2.6)], 0.1, 0.14, BOARD)


def road_d1(s):
    L, H, W = ROAD
    hz = L / 2
    for m in range(4):
        z = -hz + 50.0 + 100.0 * m
        for sg in (-1, 1):
            if wy(L, H, z) < 2.9:
                continue
            for t in range(1 + m % 3):
                zz = z - 0.12 * m + 0.2 * t - 0.1 * (m % 3) + 0.1
                side_poly(s, W, sg, [(zz - 0.03, 1.55), (zz + 0.03, 1.55), (zz + 0.03, 2.1), (zz - 0.03, 2.1)], 0.14, 0.15, DARK)
    for j in range(40):
        z = -hz + 4.0 + j * 10.7
        if wy(L, H, z) > 3.0:
            for sg in (-1, 1):
                stud(s, (sg * (W / 2), min(wy(L, H, z) - 1.0, 0.8 + (j % 4)), z), (sg, 0, 0), 0.07, 0.04, tone(STEEL, DARK, j), 4)


def road_d2(s):
    L, H, W = ROAD
    hz = L / 2
    for j in range(30):
        z = -hz + 10.0 + j * 14.2
        x = -2.5 + (j * 5 % 5)
        pts = [(z, wy(L, H, z)), (z + 3.0, wy(L, H, z + 3.0)), (z + 3.0, wy(L, H, z + 3.0) + 0.012), (z, wy(L, H, z) + 0.012)]
        hull(s, [(x, y, zz) for zz, y in pts], [(x + 0.3, y, zz) for zz, y in pts], tone(SAND, VARNISH, j, 0.5))
    for k in range(30):
        z = -hz + 5.0 + k * 14.5
        for sg in (-1, 1):
            if wy(L, H, z) > 1.0 and k % 2 == (sg > 0):
                stud(s, (sg * (W / 2 + 0.02), 0.08, z), (sg, 0.6, 0), 0.05, 0.1, tone(SAGE, JUNIPER, k, 0.4), 3)


# ------------------------------------------------------------------ C. flume ride pieces

def smooth(t):
    t = min(1.0, max(0.0, t))
    return 3 * t * t - 2 * t ** 3


SIPHON_L = 100.8
SPOUT_L = 14.0
SIPHON_STEP = 1.8
REACH_L = 120.0


def siphon_dy(z):
    return -21.0 * smooth(z / SIPHON_L)


def spout_floor_dy(z):
    t = max(0.0, (z - (SPOUT_L - 2.0)) / 2.0)
    return -1.0 * t * t


def zero(z):
    return 0.0


def stations(length, step):
    n = max(1, int(round(length / step)))
    return [length * i / n for i in range(n + 1)]


def spout_floor_stations():
    return [0.0, 3.0, 6.0, 9.0, 12.0] + [12.0 + 2.0 * i / 8 for i in range(1, 9)]


def spec_flume(rid):
    if rid == "flume_reach_120":
        return {"length": REACH_L, "wall_dy": zero, "floor_dy": zero, "wall_z": stations(REACH_L, 12.0),
                "floor_z": stations(REACH_L, 12.0), "bents": [0.35] + [12.0 * k for k in range(1, 10)] + [REACH_L - 0.35],
                "legs": lambda z: FLUME["floor_y"] - 11.0, "rail_n": 10}
    if rid == "flume_pour_spout":
        return {"length": SPOUT_L, "wall_dy": zero, "floor_dy": spout_floor_dy, "wall_z": [0.0, 3.5, 7.0, 10.5, 14.0],
                "floor_z": spout_floor_stations(), "bents": [0.0, 12.0], "legs": lambda z: FLUME["under"] - 2.0, "rail_n": 2}
    return {"length": SIPHON_L, "wall_dy": siphon_dy, "floor_dy": siphon_dy, "wall_z": stations(SIPHON_L, SIPHON_STEP),
            "floor_z": stations(SIPHON_L, SIPHON_STEP), "bents": [12.0 * k for k in range(9)] + [SIPHON_L],
            "legs": lambda z: FLUME["floor_y"] + siphon_dy(z) - 11.0, "rail_n": 8}


def wring(side, z, dy, top_drop=0.0):
    f = FLUME
    pts = [(f["wall_in"], f["under"]), (f["base_out"], f["under"]), (f["crest_out"], f["top"] - top_drop), (f["crest_in"], f["top"] - top_drop), (f["wall_in"], f["floor_y"])]
    ring = [(side * x, y + dy, z) for x, y in pts]
    return ring if side > 0 else ring[::-1]


def fring(z, dy):
    f = FLUME
    return [(-f["wall_in"], f["under"] + dy, z), (f["wall_in"], f["under"] + dy, z), (f["wall_in"], f["floor_y"] + dy, z), (-f["wall_in"], f["floor_y"] + dy, z)]


def frame2(s, z, col, k, dy, low):
    f = FLUME
    under = f["under"] + dy
    paint = lambda a, i=0: DARK if col else tone(a, VARNISH, k + i)
    for side in (-1, 1):
        strut(s, (side * 2.6, under - 0.05, z), (side * 3.7, low, z), 0.5, paint(IRON))
    block(s, -4.3, 4.3, under - 0.6, under, z - 0.35, z + 0.35, paint(IRON, 1))
    if not col:
        strut(s, (-3.4, low + 1.5, z), (3.4, under - 0.6, z), 0.22, paint(OXIDE, 2))
        strut(s, (3.4, low + 1.5, z), (-3.4, under - 0.6, z), 0.22, paint(OXIDE, 3))
        mid = (under + low) / 2
        if under - low > 8.0:
            block(s, -3.5, 3.5, mid - 0.15, mid + 0.15, z - 0.12, z + 0.12, paint(OXIDE, 4))


def flume_col2(spec):
    def build(s):
        f = FLUME
        wz = spec["wall_z"]
        for side in (-1, 1):
            loft(s, [wring(side, z, spec["wall_dy"](z)) for z in wz], DARK)
        loft(s, [fring(z, spec["floor_dy"](z)) for z in spec["floor_z"]], DARK)
        for z in spec["bents"]:
            frame2(s, z, True, 0, spec["wall_dy"](z), spec["legs"](z))
    return build


def flume_body2(spec):
    def build(s):
        f = FLUME
        wz = spec["wall_z"]
        for j in range(len(wz) - 1):
            za, zb = wz[j], wz[j + 1]
            for side in (-1, 1):
                loft(s, [wring(side, za, spec["wall_dy"](za), 0.04), wring(side, zb, spec["wall_dy"](zb), 0.04)], tone(CONCRETE, FORM, j + (side > 0), 0.4))
                xa, xb = sorted((side * f["crest_in"], side * f["crest_out"]))
                ca = [(xa, f["top"] - 0.04 + spec["wall_dy"](za), za + 0.01), (xb, f["top"] - 0.04 + spec["wall_dy"](za), za + 0.01),
                      (xb, f["top"] + spec["wall_dy"](za), za + 0.01), (xa, f["top"] + spec["wall_dy"](za), za + 0.01)]
                cb = [(x, y - spec["wall_dy"](za) + spec["wall_dy"](zb), zb - 0.01) for x, y, _ in ca]
                hull(s, ca, cb, tone(CONCRETE, CREAM, j * 5 + (side > 0), 0.3))
        fz = spec["floor_z"]
        for j in range(len(fz) - 1):
            loft(s, [fring(fz[j], spec["floor_dy"](fz[j])), fring(fz[j + 1], spec["floor_dy"](fz[j + 1]))], tone(VARNISH, CONCRETE, j, 0.5))
        for k, z in enumerate(spec["bents"]):
            frame2(s, z, False, k, spec["wall_dy"](z), spec["legs"](z))
            for side in (-1, 1):
                dy = spec["wall_dy"](z)
                ring = [(side * f["base_out"], f["under"] + dy), (side * (f["base_out"] + 0.06), f["under"] + dy),
                        (side * (f["crest_out"] + 0.06), f["top"] - 0.5 + dy), (side * f["crest_out"], f["top"] - 0.5 + dy)]
                hull(s, [(x, y, z - 0.2) for x, y in ring], [(x, y, z + 0.2) for x, y in ring], tone(IRON, DARK, int(z)))
        if spec["length"] == SPOUT_L:
            # Pour lip: an iron beam across the floor end and a copper splash plate flush on the floor's lip.
            fe = fring(SPOUT_L, spec["floor_dy"](SPOUT_L))
            block(s, -f["wall_in"], f["wall_in"], f["under"] - 1.4, f["under"] - 1.0, SPOUT_L - 0.5, SPOUT_L, tone(IRON, DARK, 3))
    return build


def flume_rail2(spec, rid):
    n, f = spec["rail_n"], FLUME
    out = []
    for k in range(n + 1):
        z = grind.END_INSET + (spec["length"] - 2 * grind.END_INSET) * k / n
        out.append((grind.FLUME_RAIL_X, f["top"] + spec["wall_dy"](z), z))
    return out


def flume_d1_2(spec):
    def build(s):
        f = FLUME
        for k, z in enumerate(spec["bents"]):
            dy = spec["wall_dy"](z)
            for side in (-1, 1):
                for yy in (4.8, 6.6):
                    frac = (yy - f["under"]) / (f["top"] - f["under"])
                    stud(s, (side * (f["base_out"] + 0.06 + (f["crest_out"] - f["base_out"]) * frac), yy + dy, z + 0.2), (0, 0, 1), 0.06, 0.04, tone(IRON, DARK, int(z)))
            for sx in (-3.7, 3.7):
                stud(s, (sx, f["under"] - 0.3 + dy, z + 0.35), (0, 0, 1), 0.07, 0.05, tone(IRON, DARK, 3))
        wz = spec["wall_z"]
        for j in range(2, len(wz) - 1, 4):
            z = wz[j]
            dy = spec["wall_dy"](z)
            for side in (-1, 1):
                xa, xb = sorted((side * (f["crest_in"] + 0.15), side * (f["crest_out"] - 0.15)))
                hz_ = 0.1
                block(s, xa, xb, f["top"] + dy, f["top"] + dy + 0.012, z - hz_, z + hz_, tone(IRON, VARNISH, j))
    return build


def flume_d2_2(spec):
    def build(s):
        f = FLUME
        n = 18 if spec["length"] > 50 else 6
        for k in range(n):
            z = 1.0 + k * (spec["length"] - 2.0) / n
            dy = spec["wall_dy"](z)
            side = -1 if k % 2 else 1
            xo = side * (f["base_out"] + 0.4 * (0.5 + 0.5 * ((k * 3) % 4) / 3.0)) + side * 0.015
            block(s, min(xo, xo + side * 0.008), max(xo, xo + side * 0.008), f["under"] + 0.4 + dy, f["under"] + 3.0 + dy, z, z + 0.18, VARNISH)
        for k, z in enumerate(spec["bents"]):
            dy = spec["wall_dy"](z)
            for side in (-1, 1):
                block(s, side * 3.9 - 0.04, side * 3.9 + 0.04, f["under"] - 0.5 + dy, f["under"] - 0.05 + dy, z + 0.2, z + 0.3, tone(OXIDE, IRON, int(z)))
            if spec["legs"](z) < 0.5:
                low = spec["legs"](z)
                grind.tuft(s, 3.9 + 0.2 * (k % 3), low, z + 0.8, 0.9, k)
                grind.tuft(s, -3.9 - 0.2 * (k % 3), low, z - 0.8, 0.8, k + 1)
    return build


# ------------------------------------------------------------------ C. flume intake

INTAKE_L = 16.0
INTAKE_MOUTH_DROP = 0.6        # the floor at the mouth sits this far below the flume floor
INTAKE_FLARE = 5.4             # the half-width at the mouth is wall_in + this (7.0)
INTAKE_WALL_H = 3.0            # the wall stands this far above the floor at the flume end (top - floor_y)
INTAKE_STEP = 1.0
GATE_X = 3.0                   # gate posts stand this far outside the mouth half-width
GATE_UP = 7.0                  # post tops above the mouth floor
GATE_BOARD_UP = 6.0            # the open sluice board hangs this far above the mouth floor


def intake_s(z):
    return smooth(z / INTAKE_L)


def intake_floor(z):
    return FLUME["floor_y"] - INTAKE_MOUTH_DROP * (1.0 - intake_s(z))


def intake_half(z):
    return FLUME["wall_in"] + INTAKE_FLARE * (1.0 - intake_s(z))


def intake_h(z):
    return INTAKE_WALL_H * intake_s(z)


def intake_wring(side, z, drop=0.0):
    """The wring() section on the flared trough: same five points and order, every x and y offset by the local flare."""
    f, xi, yf, h = FLUME, intake_half(z), intake_floor(z), intake_h(z)
    pts = [(xi, yf - 1.0), (xi + (f["base_out"] - f["wall_in"]), yf - 1.0), (xi + (f["crest_out"] - f["wall_in"]), yf + h - drop),
           (xi + (f["crest_in"] - f["wall_in"]), yf + h - drop), (xi, yf)]
    ring = [(side * x, y, z) for x, y in pts]
    return ring if side > 0 else ring[::-1]


def intake_fring(z):
    xi, yf = intake_half(z), intake_floor(z)
    return [(-xi, yf - 1.0, z), (xi, yf - 1.0, z), (xi, yf, z), (-xi, yf, z)]


def intake_zs():
    n = int(round(INTAKE_L / INTAKE_STEP))
    return [INTAKE_L * i / n for i in range(n + 1)]


def intake_col(s):
    zs = intake_zs()
    for side in (-1, 1):
        loft(s, [intake_wring(side, z) for z in zs], DARK)
    loft(s, [intake_fring(z) for z in zs], DARK)


def intake_straps():
    """Hoop strap stations: only where the wall stands over 1.5 m for the strap's whole width."""
    return [z for z in (9.0, 11.0, 13.0, 15.0) if intake_h(z - 0.2) > 1.5]


def intake_gate(s, paint_iron, paint_timber):
    """Two iron gate posts outside the wings and a timber sluice board hung open overhead; outside the collider."""
    yf0 = intake_floor(0.0)
    px = intake_half(0.0) + GATE_X
    top = yf0 + GATE_UP
    for k, side in enumerate((-1, 1)):
        block(s, side * px - 0.3, side * px + 0.3, yf0 - 1.0, top, 0.2, 0.8, paint_iron(k))
        block(s, side * px - 0.4, side * px + 0.4, top, top + 0.15, 0.1, 0.9, paint_iron(k + 2))
    block(s, -px + 0.3, px - 0.3, top - 0.5, top - 0.2, 0.3, 0.7, paint_timber(0))
    by = yf0 + GATE_BOARD_UP
    block(s, -px + 0.6, px - 0.6, by, by + 0.7, 0.35, 0.65, paint_timber(1))
    for k, side in enumerate((-1, 1)):
        block(s, side * (px - 1.5) - 0.06, side * (px - 1.5) + 0.06, by + 0.7, top - 0.5, 0.47, 0.53, paint_iron(k + 4))


def intake_body(s):
    f = FLUME
    zs = intake_zs()
    for j in range(len(zs) - 1):
        za, zb = zs[j], zs[j + 1]
        for side in (-1, 1):
            loft(s, [intake_wring(side, za, 0.04 * intake_s(za)), intake_wring(side, zb, 0.04 * intake_s(zb))], tone(CONCRETE, FORM, j + (side > 0), 0.4))
        loft(s, [intake_fring(za), intake_fring(zb)], tone(VARNISH, CONCRETE, j, 0.5))
    for k, z in enumerate(intake_straps()):
        for side in (-1, 1):
            def band(zz, side=side):
                pos = intake_wring(1, zz)
                a, b = pos[1], pos[2]
                lo = a[1] + 0.8
                frac = (lo - a[1]) / (b[1] - a[1])
                p, q = (a[0] + (b[0] - a[0]) * frac, lo), (b[0] + (a[0] - b[0]) * (0.4 / (b[1] - a[1])), b[1] - 0.4)
                out = 0.08
                return [(side * (p[0] + out), p[1], zz), (side * p[0], p[1], zz), (side * q[0], q[1], zz), (side * (q[0] + out), q[1], zz)]
            hull(s, band(z - 0.2), band(z + 0.2), tone(IRON, DARK, k * 2 + (side > 0)))
    intake_gate(s, lambda k: tone(IRON, DARK, k), lambda k: tone(TIMBER, TIMBER_DK, k, 0.5))


def intake_d1(s):
    """Drift pins on the outer wall face, one row low, one high, every 2 m."""
    f = FLUME
    for j, z in enumerate(intake_zs()[1::2]):
        yf, h, xi = intake_floor(z), intake_h(z), intake_half(z)
        x0, y0 = xi + (f["base_out"] - f["wall_in"]), yf - 1.0
        x1, y1 = xi + (f["crest_out"] - f["wall_in"]), yf + h
        for row, frac in enumerate((0.3, 0.7)):
            if row == 1 and h < 0.8:
                continue
            x, y = x0 + (x1 - x0) * frac, y0 + (y1 - y0) * frac
            for side in (-1, 1):
                nrm = (side * (y1 - y0), -(x1 - x0), 0.0)
                stud(s, (side * x, y, z), nrm, 0.07, 0.05, tone(IRON, DARK, j + row), 4)


def intake_d2(s):
    """Bolt heads on the gate posts, the board hangers and the hoop straps."""
    yf0 = intake_floor(0.0)
    px = intake_half(0.0) + GATE_X
    for k, v in enumerate((1.0, 2.5, 4.0, 5.5)):
        for side in (-1, 1):
            stud(s, (side * (px - 0.3), yf0 + v, 0.5), (-side, 0, 0), 0.06, 0.05, tone(STEEL, DARK, k), 6)
            stud(s, (side * px, yf0 + v, 0.8), (0, 0, 1), 0.06, 0.05, tone(STEEL, DARK, k + 1), 6)
    for side in (-1, 1):
        for dz in (-1, 1):
            stud(s, (side * (px - 0.7), yf0 + GATE_BOARD_UP + 0.35, 0.5 + dz * 0.15), (0, 0, dz), 0.05, 0.04, STEEL, 6)
    for k, z in enumerate(intake_straps()):
        f = FLUME
        for side in (-1, 1):
            xi, yf, h = intake_half(z), intake_floor(z), intake_h(z)
            xa, ya = xi + (f["base_out"] - f["wall_in"]), yf - 1.0
            xb, yb = xi + (f["crest_out"] - f["wall_in"]), yf + h
            lo = ya + 0.8
            frac = (lo - ya) / (yb - ya)
            x, y = xa + (xb - xa) * frac + 0.08, (lo + yb - 0.4) / 2
            stud(s, (side * (x + 0.04), y, z + 0.2), (0, 0, 1), 0.06, 0.04, tone(STEEL, DARK, k), 4)


# ------------------------------------------------------------------ registry of recipes

def box(rid, size, body, d1, d2):
    return {"kind": "box", "size": size, "body": body, "d1": d1, "d2": d2}


def wedge(rid, size, body, d1, d2):
    return {"kind": "wedge", "size": size, "body": body, "d1": d1, "d2": d2}


def crib(L, H, W):
    return box(None, [float(L), float(H), float(W)], lambda s: crib_body(s, L, H, W), lambda s: crib_d1(s, L, H, W), lambda s: crib_d2(s, L, H, W))


RECIPES = {
    "flume_bent_50": box(None, [12.0, 50.0, 4.0], lambda s: bent_body(s, 50.0), lambda s: bent_d1(s, 50.0), lambda s: bent_d2(s, 50.0)),
    "flume_bent_32": box(None, [12.0, 32.0, 4.0], lambda s: bent_body(s, 32.0), lambda s: bent_d1(s, 32.0), lambda s: bent_d2(s, 32.0)),
    "survey_mast_40": box(None, [12.0, 40.0, 4.0], mast_body, mast_d1, mast_d2),
    "surge_pylon_28": box(None, [12.0, 28.0, 4.0], lambda s: pylon_body(s, 28.0), lambda s: pylon_d1(s, 28.0), lambda s: pylon_d2(s, 28.0)),
    "surge_pylon_48": box(None, [12.0, 48.0, 4.0], lambda s: pylon_body(s, 48.0), lambda s: pylon_d1(s, 48.0), lambda s: pylon_d2(s, 48.0)),
    "crib_pier_28x28x6": crib(28, 28, 6),
    "crib_pier_24x18x6": crib(24, 18, 6),
    "crib_pier_20x28x6": crib(20, 28, 6),
    "crib_pier_12x28x6": crib(12, 28, 6),
    "crib_pier_24x28x20": crib(24, 28, 20),
    "crib_wall_60x24x6": crib(60, 24, 6),
    "anchor_block_16x28x8": box(None, [16.0, 28.0, 8.0], anchor_body, anchor_d1, anchor_d2),
    "weir_gatehouse": box(None, [12.0, 10.0, 12.0], gatehouse_body, gatehouse_d1, gatehouse_d2),
    "annex_hall": box(None, [40.0, 14.0, 24.0], annex_body, annex_d1, annex_d2),
    "crew_bunk_ledge": box(None, [120.0, 1.0, 10.0], ledge_body, ledge_d1, ledge_d2),
    "weir_apron": wedge(None, [44.0, 0.5, 30.0], apron_body, apron_d1, apron_d2),
    "gap_work_deck": wedge(None, GAP, gap_body, gap_d1, gap_d2),
    "rim_road": wedge(None, ROAD, road_body, road_d1, road_d2),
    "flume_pour_spout": {"kind": "flume", "size": [SPOUT_L, 8.0, 8.0]},
    "flume_siphon_span": {"kind": "flume", "size": [SIPHON_L, 8.0, 8.0]},
    "flume_reach_120": {"kind": "flume", "size": [REACH_L, 8.0, 8.0]},
    "flume_intake_16": {"kind": "intake", "size": [INTAKE_L, 5.0, 14.0], "col": intake_col, "body": intake_body, "d1": intake_d1, "d2": intake_d2},
}
IDS = list(RECIPES)
for _rid, _spec in RECIPES.items():
    if _spec["kind"] == "flume":
        _f = spec_flume(_rid)
        _spec.update({"col": flume_col2(_f), "body": flume_body2(_f), "d1": flume_d1_2(_f), "d2": flume_d2_2(_f), "flume": _f})
    elif _spec["kind"] == "intake":
        pass
    elif _spec["kind"] == "box":
        _spec["col"] = (lambda s, sz=_spec["size"]: box_col(s, sz[2], sz[0], sz[1]))
    else:
        _spec["col"] = (lambda s, sz=_spec["size"]: wedge_col(s, sz[0], sz[1], sz[2]))


# ------------------------------------------------------------------ D. liners (decoration only, conformed to the bake)

GROUND_BINS = {"park_flume": kit.SKETCH / "assets/park/park_flume/ground.bin", "park_pit": kit.SKETCH / "assets/park/park_pit/ground.bin",
               "park_islands": kit.SKETCH / "assets/park/park_islands/ground.bin"}
GROUND_N = 801                 # 801 x 801 float32, row-major z then x, 2 m apart over -800..800
GROUND_STEP = 2.0
GROUND_HALF = 800.0
SILT = "b9a98a"
EARTH = "9c7650"
STONE = "a8957a"
COPING = "d9ccaa"
BASE_OFF = 0.05                # the liner surface rides this far above the baked ground
EDGE_OFF = 0.02                # and eases to this at its outer edge, where it meets untouched ground
HI_LIFT = 0.02                 # never lower than this above either triangulation of a ground cell
FLUSH_LANE = 0.12             # flush_lane liners: the most any drawn vertex inside the lane stands above the ground
FLUSH_RIM_GAP = 0.5           # and rim rock bodies start this far outside the lane edge
FEATURE_MAX = 0.25             # stones, cobbles, lips and joints stay under this above the ground
MARGIN = 3.0                   # the liner runs this far past the row's rims
SLEEPER_PITCH = 2.0            # rails style: a tie every 2 m, 0.5 m wide
SLEEPER_HALF = 0.25
PANEL = 8.0                    # concrete panel length
JOINT_HALF = 0.15              # half the width of a form joint
BASE_TRIS = 7900               # under the landform budget of 8000
ROCKS_MAX = 48                 # 20 tris each
TUFTS_MAX = 60                 # 18 tris each
CHECK_MIN, CHECK_MAX = -0.05, 0.30

LINERS = {
    "liner_trestle_hollow": {"style": "sandstone", "at": (-185.0, 10.0), "size": (289.0, 8.0, 40.0), "yaw": 14.0, "flush_lane": True},
    "liner_gap_wash": {"style": "sandstone", "at": (-255.0, -335.0), "size": (180.0, 4.0, 40.0), "yaw": -16.0, "flush_lane": True},
    "liner_mesa_spill": {"style": "sandstone", "at": (-570.0, -520.0), "size": (120.0, 4.0, 30.0), "yaw": 90.0, "flush_lane": True},
    "liner_bend_return_wash": {"style": "sandstone", "at": (75.0, 35.0), "size": (147.6, 4.0, 50.0), "yaw": -28.3, "flush_lane": True},
    "liner_bench_run_wash": {"style": "sandstone", "at": (-80.0, 305.0), "size": (190.0, 4.0, 30.0), "yaw": -15.0, "flush_lane": True},
    "liner_wasteway_chute": {"style": "concrete", "at": (85.0, 335.0), "size": (214.0, 10.0, 30.0), "yaw": 37.4, "gauge": True, "flush_lane": True},
    "liner_weir_chute": {"style": "concrete", "at": (-299.0, -595.0), "size": (140.0, 40.0, 30.0), "yaw": 90.0, "flush_lane": True},
    "liner_weir_pond": {"style": "pond", "at": (-650.0, -690.0), "size": (140.0, 3.0, 160.0), "yaw": 0.0, "flush_lane": True},
    "liner_main_canal": {"style": "canal", "at": (-385.0, -275.0), "size": (177.2, 3.0, 40.0), "yaw": 73.6, "flush_lane": True},
    "liner_butte_gap": {"style": "canal", "at": (-280.0, -230.0), "size": (80.0, 3.0, 24.0), "yaw": 30.0, "flush_lane": True},
    "liner_lateral_canal": {"style": "canal", "at": (-270.0, 15.0), "size": (286.5, 3.0, 40.0), "yaw": 29.2, "flush_lane": True},
}
LINER_IDS = list(LINERS)
# The pit's rows (park_pit bake). Each size and yaw is the row's own in src/world/park/park_pit.json; a liner is placed rigidly at the
# row's `at` (no fit), so these must follow the row if it moves. "gap": the canal is left out where the arroyo cuts it or the mound
# at its west end rises (ground more than 0.35 m off the canal's own level), so no lining bridges a cut or climbs a hill.
PIT_LINERS = {
    "liner_dump_wash_1": {"park": "park_pit", "style": "sandstone", "at": (-465.7, -531.2), "size": (67.8, 10.0, 36.0), "yaw": 74.8, "flush_lane": True},
    "liner_dump_wash_2": {"park": "park_pit", "style": "sandstone", "at": (-402.3, -519.4), "size": (61.7, 10.0, 36.0), "yaw": 84.6, "flush_lane": True},
    "liner_canal_lip": {"park": "park_pit", "style": "canal", "at": (-356.0, -501.0), "size": (300.0, 0.1, 16.0), "yaw": 45.0, "gap": 0.35, "flush_lane": True},
    "liner_haul_road_west_5": {"park": "park_pit", "style": "haul", "at": (-95.0, 200.0), "size": (103.0, 0.1, 24.0), "yaw": 60.9, "flush_lane": True},
    "liner_bench2_camp_lane": {"park": "park_pit", "style": "haul", "at": (250.0, -152.0), "size": (70.0, 0.1, 20.0), "yaw": 90.0, "flush_lane": True},
    "liner_bench2_east_bank": {"park": "park_pit", "style": "haul", "at": (337.5, -60.0), "size": (190.0, 0.1, 40.0), "yaw": 0.0, "flush_lane": True},
}
PIT_LINER_IDS = list(PIT_LINERS)
LINERS.update(PIT_LINERS)
# The islands' decoration-only pass (park_islands bake). fin_chute (the twin_fins collapse drops its ground 8 m) and cloud_wash_west
# (the west_wing impact swaps in a crater) are not here: a baked-ground liner would float over the swapped ground.
# "flush_lane": nothing drawn inside any ride row's footprint of the park stands more than FLUSH_LANE (0.12 m) above the ground, because
# a ride lane may carry no visible bump that is not solid; the cap holds at every vertex of a cell that touches a footprint, so the
# interpolated surface obeys it too. The sandstone, haul and rails styles are also flat across their whole lane (|x| <= the row's
# half-width) and rim rocks start at hw + FLUSH_RIM_GAP. liner_check fails the build otherwise.
ISLES_LINERS = {
    "liner_run_turn_wash": {"park": "park_islands", "style": "sandstone", "at": (-60.0, -516.0), "size": (60.0, 4.0, 40.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
    "liner_lookout_stair": {"park": "park_islands", "style": "haul", "at": (-100.0, -520.0), "size": (160.0, 0.01, 40.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
    "liner_east_ribs": {"park": "park_islands", "style": "haul", "at": (100.0, -520.0), "size": (160.0, 0.01, 40.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
    "liner_net_post_run": {"park": "park_islands", "style": "haul", "at": (0.0, 200.0), "size": (160.0, 0.01, 120.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
    "liner_cloud_wash_east": {"park": "park_islands", "style": "sandstone", "at": (210.0, 260.0), "size": (300.0, 0.01, 30.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
    "liner_ore_chute": {"park": "park_islands", "style": "rails", "at": (110.0, 0.0), "size": (150.0, 0.01, 16.0), "yaw": 0.0, "flush_lane": True, "flush_surface": False},
}
ISLES_LINER_IDS = list(ISLES_LINERS)
LINERS.update(ISLES_LINERS)
LINER_NOTES = {
    "sandstone": "banded sandstone ledges along both wall bands, cobble scatter on the floor margins, varnish streaks",
    "concrete": "board-formed concrete liner panels with dark form joints and a worn cream coping strip at the rims",
    "pond": "concrete rim ring and a stone pitched lining around a flush floor",
    "canal": "earthen bank berms, cobble armouring at the lip and a silt floor, a shaped reference to how an earth canal holds its lip",
    "rails": "a low light-rail bed: two rails 0.03 m proud of a gravel bed with flush colour bands for the tie sleepers, cobbles along the verges",
    "haul": "a graded gravel haul surface with two tyre-rut bands, cobbles along both verges and sage tufts beyond them",
}
LINER_NOTES_EXTRA = {"liner_wasteway_chute": "; a painted gauge staff on one wall"}

_GROUND = {}


def ground_rows(park="park_flume"):
    """A park bake's ground heights, decoded once from Godot's compressed file (GCPF, zstd blocks)."""
    if park not in _GROUND:
        import numpy
        import zstandard
        raw = GROUND_BINS[park].read_bytes()
        assert raw[:4] == b"GCPF", raw[:4]
        mode, block, total = struct.unpack_from("<3I", raw, 4)
        assert mode == 2, mode
        count = -(-total // block)
        sizes = struct.unpack_from("<%dI" % count, raw, 16)
        pos = 16 + 4 * count
        out = bytearray()
        dec = zstandard.ZstdDecompressor()
        for size in sizes:
            out += dec.decompress(raw[pos:pos + size], max_output_size=block)
            pos += size
        assert len(out) == total == GROUND_N * GROUND_N * 4, (len(out), total)
        _GROUND[park] = numpy.frombuffer(bytes(out), dtype="<f4").reshape(GROUND_N, GROUND_N).astype("float64")
    return _GROUND[park]


def ground_at(x, z, park="park_flume"):
    """(bilinear height, highest of the bilinear and both diagonal triangulations of the cell) at world x, z."""
    g = ground_rows(park)
    fx = min(max((x + GROUND_HALF) / GROUND_STEP, 0.0), GROUND_N - 1 - 1e-9)
    fz = min(max((z + GROUND_HALF) / GROUND_STEP, 0.0), GROUND_N - 1 - 1e-9)
    ix, iz = int(fx), int(fz)
    u, v = fx - ix, fz - iz
    h00, h10, h01, h11 = float(g[iz, ix]), float(g[iz, ix + 1]), float(g[iz + 1, ix]), float(g[iz + 1, ix + 1])
    bil = h00 * (1 - u) * (1 - v) + h10 * u * (1 - v) + h01 * (1 - u) * v + h11 * u * v
    da = h00 + u * (h10 - h00) + v * (h11 - h10) if u >= v else h00 + v * (h01 - h00) + u * (h11 - h01)
    db = h00 + u * (h10 - h00) + v * (h01 - h00) if u + v <= 1.0 else h11 + (1 - u) * (h01 - h11) + (1 - v) * (h10 - h11)
    return bil, max(bil, da, db)


def ss(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def hh(i, j, k=0):
    """A deterministic hash in [0, 1)."""
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) % 1009 / 1009.0


FLUSH_PROP_REACH = {"rock": 0.7, "tuft": 0.5}    # how far a rock or tuft reaches from its centre
_RIDES = {}


def ride_footprints(park):
    """Every row of the park with a ride fact, as (id, at, along-half, across-half, facing, across-axis), the footprint math of
    scatter's keep-out (size[0] along the facing, size[2] across it)."""
    if park not in _RIDES:
        rows = json.loads((kit.SKETCH / "src/world/park" / (park + ".json")).read_text())["park_rows"]
        out = []
        for r in rows:
            if not r.get("ride_fact"):
                continue
            yaw = math.radians(float(r["yaw_deg"]))
            out.append((r["id"], r["at"], r["size"][0] / 2.0, r["size"][2] / 2.0, (math.sin(yaw), math.cos(yaw)), (math.cos(yaw), -math.sin(yaw))))
        _RIDES[park] = out
    return _RIDES[park]


def in_ride_footprint(row, lx, lz, reach=0.0):
    """Whether the liner-local point, widened by reach, is inside any ride row's footprint of the park (the liner's own lane included)."""
    x, z = row.world(lx, lz)
    for rid, at, hl, hw, f, a in ride_footprints(row.park):
        dx, dz = x - at[0], z - at[1]
        if abs(dx * f[0] + dz * f[1]) <= hl + reach + 1e-6 and abs(dx * a[0] + dz * a[1]) <= hw + reach + 1e-6:
            return True
    return False


def _sat_overlap(pa, pb):
    """Whether two convex quads (four points each, in order) overlap by more than a touch: separating axis over their edges."""
    for poly in (pa, pb):
        for k in range(4):
            a, b = poly[k], poly[(k + 1) % 4]
            nx, nz = a[1] - b[1], b[0] - a[0]
            norm = math.hypot(nx, nz) or 1.0
            nx, nz = nx / norm, nz / norm
            pa_ = [x * nx + z * nz for x, z in pa]
            pb_ = [x * nx + z * nz for x, z in pb]
            if max(pa_) < min(pb_) - 1e-4 or max(pb_) < min(pa_) - 1e-4:
                return False
    return True


def box_touches_footprint(row, x0, x1, z0, z1):
    """Whether the liner-local box [x0, x1] x [z0, z1] touches any ride row's footprint of the park (the surface drawn over
    the box is then capped at every one of its vertices, so no interpolated point inside a footprint can stand above the band)."""
    box = [row.world(x, z) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
    for rid, at, hl, hw, f, a in ride_footprints(row.park):
        corners = [(at[0] + sf * hl * f[0] + sa * hw * a[0], at[1] + sf * hl * f[1] + sa * hw * a[1])
                   for sf, sa in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        if _sat_overlap(box, corners):
            return True
    return False


def flush_capped(row, cells):
    """The vertex keys of every cell (a list of ((key, lx, lz) x 3 or 4)) that touches a footprint."""
    out = set()
    for cell in cells:
        lxs = [c[1] for c in cell]
        lzs = [c[2] for c in cell]
        if box_touches_footprint(row, min(lxs), max(lxs), min(lzs), max(lzs)):
            out.update(c[0] for c in cell)
    return out


SETTLE_SINK = 0.03     # a settled vertex goes no lower than this under the ground
SETTLE_PASSES = 12
SETTLE_AIM = 5e-5      # and aims this far under the band, so float32 export never tips a sample over it


def surface_lattice(n=None):
    n = n or SURFACE_N
    return [(a / n, b / n, (n - a - b) / n) for a in range(n + 1) for b in range(n + 1 - a)]


def settle_cells(row, verts, cells):
    """Make the drawn surface itself obey the band. verts: key -> [lx, y, lz, bil]; cells: lists of 3 or 4 keys in drawing order.
    Every sample of a cell's triangles (both diagonals of a quad, as the triangulation is the exporter's) that lies inside a ride
    footprint is held to FLUSH_LANE above the ground: the cell's vertices are lowered by the excess, never more than SETTLE_SINK under
    the ground, over a few passes. A cell that still exceeds the band (a cliff or cut the sampling bridges) is dropped, so the
    baked ground, which is solid, shows there. Returns the indices of the dropped cells."""
    lattice = surface_lattice()
    plans = []
    for ci, cell in enumerate(cells):
        xs_ = [verts[k][0] for k in cell]
        zs_ = [verts[k][2] for k in cell]
        if not box_touches_footprint(row, min(xs_), max(xs_), min(zs_), max(zs_)):
            continue
        tris = [(0, 1, 2)] if len(cell) == 3 else [(0, 1, 2), (0, 2, 3), (1, 2, 3), (1, 3, 0)]
        samples = []
        for t in tris:
            for u, v, w in lattice:
                x = u * verts[cell[t[0]]][0] + v * verts[cell[t[1]]][0] + w * verts[cell[t[2]]][0]
                z = u * verts[cell[t[0]]][2] + v * verts[cell[t[1]]][2] + w * verts[cell[t[2]]][2]
                if in_ride_footprint(row, x, z):
                    wts = [0.0] * len(cell)
                    wts[t[0]], wts[t[1]], wts[t[2]] = u, v, w
                    samples.append((wts, ground_at(*row.world(x, z), row.park)[0] - row.g0))
        if samples:
            plans.append((ci, cell, samples))

    def excess(cell, samples):
        return max(sum(wt * verts[k][1] for wt, k in zip(wts, cell)) - g for wts, g in samples) - (FLUSH_LANE - SETTLE_AIM)
    for _ in range(SETTLE_PASSES):
        moved = False
        for ci, cell, samples in plans:
            e = 0.0
            e = excess(cell, samples)
            if e > 0.0:
                for k in cell:
                    verts[k][1] = max(verts[k][1] - e, verts[k][3] - row.g0 - SETTLE_SINK)
                moved = True
        if not moved:
            break
    return {ci for ci, cell, samples in plans if excess(cell, samples) > 1e-5}


def flush_clip(row, spec):
    """(exl, exr) of a flush_lane row's sheet: where another flush_lane liner's lane starts on that side within the z range
    of both sheets, the sheet stops at that lane's edge, so adjacent sheets do not overlap or z-fight."""
    exl = exr = row.ex
    if spec["yaw"] != 0.0:      # a turned row is separated from its flush neighbours by flush_cull, cell by cell
        return exl, exr
    for oid, o in LINERS.items():
        if not o.get("flush_lane") or o is spec or o.get("park") != spec.get("park") or o["yaw"] != 0.0:
            continue
        if abs(o["at"][1] - spec["at"][1]) >= (o["size"][0] + spec["size"][0]) / 2.0 + 2 * MARGIN:
            continue
        lo, hi = o["at"][0] - o["size"][2] / 2.0, o["at"][0] + o["size"][2] / 2.0
        mine_hi, mine_lo = spec["at"][0] + row.hw, spec["at"][0] - row.hw
        if lo >= mine_hi - 1e-6:
            exr = min(exr, lo - spec["at"][0])
        elif hi <= mine_lo + 1e-6:
            exl = min(exl, spec["at"][0] - hi)
    return exl, exr


def lane_strict(row):
    """Whether a flush row's whole lane (|x| <= hw) is flat, not only the part inside a ride footprint: the sheet styles, whose
    lane is the ride surface. The concrete, canal and pond styles keep their wall, lip and rim relief outside every footprint."""
    return row.style in ("sandstone", "haul", "rails")


def flush_peers(rid):
    """The flush_lane rows of the same park that a turned row shares ground with, as (earlier, id): the pairs flush_clip cannot
    clip (it is axis-aligned and handles only two unturned rows). Of two such rows the one earlier in LINERS wins the overlap."""
    spec = LINERS[rid]
    order = list(LINERS)
    out = []
    for oid, o in LINERS.items():
        if oid == rid or not o.get("flush_lane") or o.get("park") != spec.get("park"):
            continue
        if spec["yaw"] == 0.0 and o["yaw"] == 0.0:
            continue
        out.append((order.index(oid) < order.index(rid), oid))
    return out


_ROWS = {}


def plan_row(rid):
    if rid not in _ROWS:
        _ROWS[rid] = Row(rid)
    return _ROWS[rid]


def gap_dropped(rid, lx, lz):
    """Whether the row's own mesh leaves out the cell holding the liner-local point (its gap rule), so it covers nothing there."""
    wrow = plan_row(rid)
    if wrow.gap is None:
        return False
    xs, zs, _, _ = rect_plan(wrow)
    i = min(max(bisect.bisect_right(xs, lx) - 1, 0), len(xs) - 2)
    j = min(max(bisect.bisect_right(zs, lz) - 1, 0), len(zs) - 2)
    return max(abs(wrow.sample(x, z)[0] - wrow.g0) for x in (xs[i], xs[i + 1]) for z in (zs[j], zs[j + 1])) > wrow.gap


def sheet_zone(rid, x, z):
    """2 inside the lane of the row at world (x, z), 1 inside its sheet (lane plus MARGIN), else 0 (also 0 where the row's own
    mesh drops the cell for its gap rule)."""
    spec = LINERS[rid]
    yaw = math.radians(spec["yaw"])
    c, s = math.cos(yaw), math.sin(yaw)
    dx, dz = x - spec["at"][0], z - spec["at"][1]
    lx, lz = dx * c - dz * s, dx * s + dz * c
    hw, hl = spec["size"][2] / 2.0, spec["size"][0] / 2.0
    if spec["style"] == "pond":
        return 0        # the pond's sheet is elliptical; assert_pond_clear keeps every other flush row of the park off it
    if abs(lx) <= hw and abs(lz) <= hl:
        zone = 2
    elif abs(lx) <= hw + MARGIN and abs(lz) <= hl + MARGIN:
        zone = 1
    else:
        return 0
    return 0 if spec.get("gap") is not None and gap_dropped(rid, lx, lz) else zone


def flush_covered(row, lx, lz):
    """Whether another flush_lane row's sheet takes the liner-local point: it is inside that row's lane and not this row's, or in
    both sheets and that row is the earlier one."""
    x, z = row.world(lx, lz)
    mine = sheet_zone(row.rid, x, z)
    for earlier, oid in row.peers:
        theirs = sheet_zone(oid, x, z)
        if theirs > mine or (theirs == mine and theirs and earlier):
            return True
    return False


def flush_cell_covered(row, x0, x1, z0, z1):
    """Whether a cell is wholly taken by other flush sheets: its centre and all four corners are covered. A cell only partly
    covered stays, so a seam never leaves a sliver with no surface (both sheets are capped inside any footprint)."""
    pts = ((x0 + x1) / 2.0, (z0 + z1) / 2.0), (x0, z0), (x1, z0), (x1, z1), (x0, z1)
    return all(flush_covered(row, x, z) for x, z in pts)


def assert_pond_clear(rid):
    """sheet_zone treats a pond as covering nothing, so no pond's bounding sheet may overlap another flush row of its park."""
    spec = LINERS[rid]

    def sheet(sp):
        yaw = math.radians(sp["yaw"])
        c, s = math.cos(yaw), math.sin(yaw)
        ex, ez = sp["size"][2] / 2.0 + MARGIN, sp["size"][0] / 2.0 + MARGIN
        return [(sp["at"][0] + x * c + z * s, sp["at"][1] - x * s + z * c) for x, z in ((-ex, -ez), (ex, -ez), (ex, ez), (-ex, ez))]
    for oid, o in LINERS.items():
        if oid == rid or not o.get("flush_lane") or o.get("park") != spec.get("park"):
            continue
        if "pond" in (spec["style"], o["style"]):
            assert not _sat_overlap(sheet(spec), sheet(o)), "%s: flush sheet overlaps %s, and a pond's sheet is not culled" % (rid, oid)


class Row:
    """A liner's row: the world <-> GLB-local transform of park_recipes.gd row_transform, and the ground under it."""

    def __init__(self, rid):
        spec = LINERS[rid]
        self.rid, self.style = rid, spec["style"]
        self.park = spec.get("park", "park_flume")
        self.gap = spec.get("gap")          # a lining left out wherever the ground departs this far from the row's own level
        self.gauge = spec.get("gauge", False)
        self.flush = spec.get("flush_lane", False)
        self.ax, self.az = spec["at"]
        self.L, self.H, self.W = spec["size"]
        yaw = math.radians(spec["yaw"])
        self.c, self.s = math.cos(yaw), math.sin(yaw)
        self.g0 = ground_at(self.ax, self.az, self.park)[0]
        self.hw, self.hl = self.W / 2.0, self.L / 2.0
        self.ex, self.ez = self.hw + MARGIN, self.hl + MARGIN
        self.exl = self.exr = self.ex           # the sheet's extent on the -x and +x side (flush_lane rows clip at a neighbouring lane)
        self.settle = self.flush and spec.get("flush_surface", True)    # the sampled-surface rule (the islands rows predate it)
        self.peers = flush_peers(rid) if self.flush else []
        if self.flush:
            assert_pond_clear(rid)
        if self.flush:
            self.exl, self.exr = flush_clip(self, spec)
        self.gauge_z = -0.3 * self.L
        self.cache = {}

    def world(self, lx, lz):
        return self.ax + lx * self.c + lz * self.s, self.az - lx * self.s + lz * self.c

    def sample(self, lx, lz):
        key = (round(lx, 5), round(lz, 5))
        if key not in self.cache:
            self.cache[key] = ground_at(*self.world(lx, lz), self.park)
        return self.cache[key]


def fill(keys, step):
    keys = sorted(set(round(k, 4) for k in keys))
    out = [keys[0]]
    for a, b in zip(keys, keys[1:]):
        n = max(1, int(math.ceil((b - a) / step - 1e-9)))
        out += [a + (b - a) * t / n for t in range(1, n + 1)]
    return out


def across_stations(row, step):
    hw, W = row.hw, row.W
    if row.flush and (row.exl != row.ex or row.exr != row.ex):
        return across_clipped(row, step)
    k = [0.0, 0.2 * W, row.ex] + ([hw] if row.flush and row.style == "haul" else [])
    if row.style == "sandstone":
        k += [hw, 0.1 * W, 0.3 * W]
    elif row.style == "concrete":
        k += [hw - 0.6, hw - 0.1, hw + 0.7, hw + 1.2, hw - 1.0]
    elif row.style == "haul":
        k += [3.0, 4.0, hw - 1.0, hw - 0.3, hw + 0.5, hw + 2.0]
    elif row.style == "rails":
        k += [1.45, 1.75, 2.4, hw - 1.0, hw - 0.3, hw + 0.5, hw + 2.0]
    else:
        k += [hw - 1.5, hw - 0.5, hw + 0.8, hw + 2.4]
    k = sorted(set(round(v, 4) for v in k))
    return fill([-v for v in k[1:]] + k, step)


def across_clipped(row, step):
    """across_stations of a flush_lane row whose sheet stops short of its margin on one side: the stations are those of the
    full sheet, cut at exl / exr (which themselves become stations)."""
    full = Row.__new__(Row)
    full.__dict__.update(row.__dict__)
    full.exl = full.exr = full.ex
    xs = across_stations(full, step)
    return fill([-row.exl] + [x for x in xs if -row.exl < x < row.exr] + [row.exr], step)


def along_stations(row, step):
    k = [-row.ez, row.ez]
    if row.style == "concrete":
        z = -row.hl + PANEL
        while z < row.hl - 1.0:
            k += [z - JOINT_HALF, z + JOINT_HALF]
            z += PANEL
        if row.gauge:
            k += [row.gauge_z - 0.55, row.gauge_z + 0.55]
    elif row.style == "rails":
        z = -row.hl + SLEEPER_PITCH
        while z < row.hl - 1.0:
            k += [z - SLEEPER_HALF, z + SLEEPER_HALF]
            z += SLEEPER_PITCH
    return fill(k, step)


def edge_weight(dist):
    return ss(dist / 1.5)


def verge_bump(d, d0=0.0):
    """flush_lane verge: nothing inside the lane; the cobbles rise from d0 (the lane edge, or the last lane station for the
    rails style, whose tie bands leave no triangle budget for another) to a crest 0.5 m on and fade by 2 m."""
    d -= d0
    if d <= 0 or d >= 2.0:
        return 0.0
    return ss(d / 0.5) if d < 0.5 else 1.0 - ss((d - 0.5) / 1.5)


def rect_off(row, lx, lz, gh):
    """Height of the liner above the ground at a vertex (before the lift that keeps it clear of the bake)."""
    W, hw, st = row.W, row.hw, row.style
    a = abs(lx)
    d = a - hw
    wt = ss((a - 0.2 * W) / (0.08 * W)) if d <= 0 else 1.0
    off = BASE_OFF
    if st == "sandstone":
        if d < 0 or (d == 0 and not row.flush):
            q = (gh / 0.9) % 1.0
            f = ss(q / 0.6) if q < 0.88 else ss((1.0 - q) / 0.12)
            off += wt * (0.06 if row.flush else 0.19) * f
    elif st == "concrete":
        p = lz + row.hl
        m = p % PANEL
        if 1.0 < p < row.L - 1.0 and min(m, PANEL - m) <= JOINT_HALF + 1e-6 and d <= 0:
            off += 0.07 * wt
        off += 0.13 * ss((d + 0.6) / 0.5) * (1.0 - ss((d - 0.7) / 0.5))
        if row.gauge and lx > 0 and abs(lz - row.gauge_z) <= 0.56 and d <= -0.6:
            off += 0.05 * wt
        off = min(off, FEATURE_MAX)
    elif st == "rails":
        a_ = abs(lx)
        if 1.45 <= a_ <= 1.75 and 1.0 < lz + row.hl < row.L - 1.0:
            off += 0.03
        elif row.flush:
            off += 0.08 * verge_bump(d, -0.3)
        elif -1.0 < d < 1.4:
            bump = ss((d + 1.0) / 0.8) if d < 0.2 else 1.0 - ss((d - 0.2) / 1.2)
            off += 0.08 * bump
    elif st == "haul":
        if row.flush:
            off += 0.10 * verge_bump(d)
        elif -1.0 < d < 1.4:      # cobbles along the verge, low and soft: nothing in the lane stands up
            bump = ss((d + 1.0) / 0.8) if d < 0.2 else 1.0 - ss((d - 0.2) / 1.2)
            off += 0.10 * bump
    else:
        if -0.5 < d < 2.4:
            bump = ss((d + 0.5) / 1.3) if d < 0.8 else 1.0 - ss((d - 0.8) / 1.6)
            off += 0.17 * bump
    return off


def rect_colour(row, lx, lz, gh, i, j):
    W, hw, st = row.W, row.hw, row.style
    a = abs(lx)
    d = a - hw
    out_of_run = abs(lz) > row.hl
    if st == "sandstone":
        if d > 0 or out_of_run:
            return tone(SAGE, SAND, i + j, 0.35) if hh(i, j, 3) < 0.10 else tone(SAND, CREAM, i * 3 + j, 0.5)
        if a < 0.2 * W:
            if a > 0.1 * W and hh(i, j, 1) < 0.35:
                return tone((VARNISH, OXIDE, CREAM, SLICK)[int(hh(i, j, 2) * 4)], SAND, i + j, 0.4)
            return tone(SAND, CREAM, i * 5 + j, 0.55)
        if a < 0.3 * W and hh(i, j, 1) < 0.28:
            return tone((VARNISH, OXIDE, CREAM, SLICK)[int(hh(i, j, 2) * 4)], SAND, i + j, 0.4)
        if a > 0.3 * W and hh(int((lz + row.ez) // 2.4), 7, 5) < 0.14:
            return tone(VARNISH, DARK, i + j, 0.4)
        band = int(gh / 0.9) % 4
        return tone((SAND, SLICK, CREAM, OXIDE)[band], VARNISH, band * 5 + (i + j) % 3, 0.28)
    if st == "concrete":
        if out_of_run and (d > -0.35 or abs(lz) > row.hl + 0.01):
            return tone(SAND, CREAM, i * 3 + j, 0.5)
        p = lz + row.hl
        m = p % PANEL
        if 1.0 < p < row.L - 1.0 and min(m, PANEL - m) <= JOINT_HALF + 0.02 and d <= -0.3:
            return tone(FORM, DARK, i + j, 0.55)
        if -0.35 <= d <= 0.95:
            return tone(CONCRETE, COPING, i + j, 0.5) if hh(i, j, 4) < 0.22 else tone(COPING, CREAM, i + j, 0.4)
        if d > 0.95:
            return tone(SAND, SAGE, i * 3 + j, 0.4) if hh(i, j, 3) < 0.10 else tone(SAND, CREAM, i * 3 + j, 0.5)
        if row.gauge and lx > 0 and abs(lz - row.gauge_z) <= 0.6 and 0.2 * W < a < hw - 0.5:
            tick = int(math.floor((gh - row.g0) / 0.5))
            return OXIDE if tick % 4 == 0 else (CREAM if tick % 2 == 0 else DARK)
        panel = int(p // PANEL)
        return tone(CONCRETE, FORM, panel * 3 + (1 if lx > 0 else 0), 0.3)
    if st == "rails":
        if d > 2.0 or out_of_run:
            return tone(SAGE, SAND, i + j, 0.35) if hh(i, j, 3) < 0.07 else tone(SAND, CREAM, i * 3 + j, 0.5)
        if -1.0 <= d <= 0.8:
            return tone((STONE, VARNISH, CREAM, STONE)[int(hh(i, j, 2) * 4)], SAND, i + j, 0.45) if hh(i, j, 1) < 0.5 else tone(EARTH, SAND, i + j, 0.4)
        if d > 0.8:
            return tone(EARTH, SAND, i * 2 + j, 0.35)
        if 1.45 <= a <= 1.75:
            return tone(IRON, DARK, i + j, 0.3)
        p = lz + row.hl
        m = p % SLEEPER_PITCH
        if a <= 2.4 and 1.0 < p < row.L - 1.0 and min(m, SLEEPER_PITCH - m) <= SLEEPER_HALF + 1e-6:
            return tone(VARNISH, DARK, i + j, 0.4)
        return tone(SAND, SILT, i * 5 + j, 0.5) if hh(i, j, 6) < 0.8 else tone(CREAM, SAND, i + j, 0.4)
    if st == "haul":
        if d > 2.0 or out_of_run:
            return tone(SAGE, SAND, i + j, 0.35) if hh(i, j, 3) < 0.07 else tone(SAND, CREAM, i * 3 + j, 0.5)
        if -1.0 <= d <= 0.8:
            return tone((STONE, VARNISH, CREAM, STONE)[int(hh(i, j, 2) * 4)], SAND, i + j, 0.45) if hh(i, j, 1) < 0.5 else tone(EARTH, SAND, i + j, 0.4)
        if d > 0.8:
            return tone(EARTH, SAND, i * 2 + j, 0.35)
        if 3.0 <= a <= 4.0:
            return tone(IRON, VARNISH, i + j, 0.45)
        return tone(SAND, SILT, i * 5 + j, 0.5) if hh(i, j, 6) < 0.8 else tone(CREAM, SAND, i + j, 0.4)
    # canal
    if d > 2.4 or out_of_run:
        return tone(SAGE, SAND, i + j, 0.35) if hh(i, j, 3) < 0.07 else tone(SAND, CREAM, i * 3 + j, 0.5)
    if -1.5 <= d <= 0.6:
        if hh(i, j, 1) < 0.55:
            return tone((STONE, VARNISH, CREAM, STONE)[int(hh(i, j, 2) * 4)], SAND, i + j, 0.45)
        return tone(EARTH, SAND, i + j, 0.4)
    if d > 0.6:
        return tone(EARTH, SAND, i * 2 + j, 0.35)
    if a < 0.2 * W:
        return tone(SILT, CREAM, i * 5 + j, 0.5)
    return tone(EARTH, SILT, i + j, 0.5)


def pond_geometry(row):
    """Ellipse axes of the footprint (rim) and of the liner (rim plus the margin), and the rim's rho at the liner edge."""
    a_rim, b_rim = row.W / 2.0, row.L / 2.0
    return a_rim, b_rim, a_rim + MARGIN, b_rim + MARGIN


def pond_rho(row, lx, lz):
    a, b = row.hw, row.hl
    return math.sqrt((lx / a) ** 2 + (lz / b) ** 2)


def pond_off(row, rho, ring):
    off = BASE_OFF
    wt = ss((rho - 0.4) / 0.08) * (1.0 - ss((rho - 0.9) / 0.03))
    off += wt * 0.06 * (ring % 2)
    off += 0.13 * ss((rho - 0.86) / 0.04) * (1.0 - ss((rho - 1.0) / 0.03))
    return min(off, FEATURE_MAX)


def pond_colour(row, rho, ring, i):
    if rho < 0.4:
        return tone(CONCRETE, CREAM, ring * 3 + i, 0.45)
    if 0.88 <= rho <= 1.02:
        return tone(CONCRETE, COPING, ring + i, 0.5) if hh(ring, i, 4) < 0.2 else tone(COPING, CREAM, ring + i, 0.4)
    if rho > 1.02:
        return tone(SAGE, SAND, ring + i, 0.35) if hh(ring, i, 3) < 0.08 else tone(SAND, CREAM, ring * 3 + i, 0.5)
    base = (STONE, SAND, VARNISH, CREAM)[int(hh(ring, i, 2) * 4)]
    return tone(base, STONE, ring + i, 0.4 if ring % 2 else 0.25)


def poly_up(s, pts, color):
    """One face wound counter-clockwise seen from above (the sheet is open, so the winding is trusted, not recomputed)."""
    nx = ny = nz = 0.0
    for k, p in enumerate(pts):
        q = pts[(k + 1) % len(pts)]
        nx += (p[1] - q[1]) * (p[2] + q[2])
        ny += (p[2] - q[2]) * (p[0] + q[0])
        nz += (p[0] - q[0]) * (p[1] + q[1])
    face = list(range(len(pts)))
    if ny < 0:
        face.reverse()
    s.add([tuple(p) for p in pts], [tuple(face)], color)


class LinerSurf(Surf):
    """kit.Surface.finish without the bmesh normal recalculation, which cannot tell the top of an open sheet."""

    def finish(self, root):
        bpy, bmesh, common_ = kit.bpy, kit.bmesh, kit.common
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([kit.xyz(v) for v in self.verts], [], self.faces)
        mesh.update()
        attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        for poly in mesh.polygons:
            poly.use_smooth = False
            for li in poly.loop_indices:
                attr.data[li].color = common_.rgba(self.colors[mesh.loops[li].vertex_index])
        mesh.color_attributes.active_color = attr
        mesh.materials.append(kit.material(self.slot))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        tri = obj.modifiers.new("FixedTriangles", "TRIANGULATE")
        tri.quad_method = "FIXED"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=tri.name)
        return obj


def lifted(row, bil, hi, off, flat=False, cap=None):
    """Local y of a liner vertex: off above the bilinear ground; off the floor band it also clears either triangulation of the
    ground cell (by at most 0.04 m extra, so steep cells never lift the liner far)."""
    y = bil + off
    if not flat:
        y = max(y, min(hi + HI_LIFT, y + 0.04))
    y = min(y, bil + FEATURE_MAX + 0.03)
    if cap is not None:
        y = min(y, bil + cap)
    return y - row.g0


def refine(vals, bent, tol=0.25, min_gap=0.5, passes=2):
    """Halve every interval over which the ground departs from a straight line by more than tol (down to min_gap), so the
    liner follows a cliff or a cut the 2 m sampling would otherwise bridge. A steady slope never triggers it."""
    for _ in range(passes):
        out = [vals[0]]
        for a, b in zip(vals, vals[1:]):
            if b - a >= 2 * min_gap - 1e-9 and bent(a, b) > tol:
                out.append((a + b) / 2.0)
            out.append(b)
        vals = out
    return vals


_PLANS = {}


def rect_plan(row):
    """(xs, zs, tris, step) for the finest sampling whose base fits the landform budget."""
    if row.rid in _PLANS:
        return _PLANS[row.rid]
    xs0 = across_stations(row, 2.0)
    for step in (2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 16.0):
        zs = refine(along_stations(row, step),
                    lambda a, b: max(abs(row.sample(x, (a + b) / 2.0)[0] - (row.sample(x, a)[0] + row.sample(x, b)[0]) / 2.0) for x in xs0))
        xs = refine(xs0, lambda a, b: max(abs(row.sample((a + b) / 2.0, z)[0] - (row.sample(a, z)[0] + row.sample(b, z)[0]) / 2.0) for z in zs))
        tris = 2 * (len(xs) - 1) * (len(zs) - 1)
        if tris <= BASE_TRIS:
            _PLANS[row.rid] = (xs, zs, tris, step)
            return _PLANS[row.rid]
    raise AssertionError(row.rid)


def pond_rings(row, step_m=3.5):
    a_rim, b_rim, a_ext, b_ext = pond_geometry(row)
    ref = ((a_ext / a_rim) + (b_ext / b_rim)) / 2.0
    keys = [0.0, 0.4, 0.48, 0.86, 0.9, 1.0, 1.03, ref]
    out = [0.0]
    for a, b in zip(keys, keys[1:]):
        n = max(1, int(math.ceil((b - a) * min(a_rim, b_rim) / step_m - 1e-9)))
        out += [(a + (b - a) * t / n) / ref for t in range(1, n + 1)]
    return out, ref


def pond_plan(row):
    rings, ref = pond_rings(row)
    for nang in (96, 88, 80, 72, 64, 56, 48):
        tris = nang + 2 * nang * (len(rings) - 2)
        if tris <= BASE_TRIS:
            return rings, ref, nang, tris
    raise AssertionError(row.rid)


def liner_base(row):
    def build(s):
        if row.style == "pond":
            rings, ref, nang, _ = pond_plan(row)
            a_rim, b_rim, a_ext, b_ext = pond_geometry(row)
            lat = []
            pts_ = {}
            for k, r in enumerate(rings):
                for i in range(1 if k == 0 else nang):
                    phi = math.tau * i / nang
                    pts_[(k, i)] = (a_ext * r * math.cos(phi), b_ext * r * math.sin(phi))
            capv = set()
            if row.flush:
                cells = []
                for k in range(len(rings) - 1):
                    for i in range(nang):
                        j = (i + 1) % nang
                        keys = [(0, 0), (1, i), (1, j)] if k == 0 else [(k, i), (k, j), (k + 1, j), (k + 1, i)]
                        cells.append([(q, pts_[q][0], pts_[q][1]) for q in keys])
                capv = flush_capped(row, cells)
            for k, r in enumerate(rings):
                line = []
                for i in range(1 if k == 0 else nang):
                    phi = math.tau * i / nang
                    lx, lz = a_ext * r * math.cos(phi), b_ext * r * math.sin(phi)
                    bil, hi = row.sample(lx, lz)
                    rho = pond_rho(row, lx, lz)
                    off = pond_off(row, rho, k)
                    we = edge_weight((ref - rho) * min(a_rim, b_rim))
                    off = EDGE_OFF + (off - EDGE_OFF) * we
                    cap = FLUSH_LANE if row.flush and ((k, i) in capv or in_ride_footprint(row, lx, lz)) else None
                    line.append(((lx, lifted(row, bil, hi, off, rho <= 0.4 + 1e-6, cap), lz), bil, rho))
                lat.append(line)
            lost = set()
            if row.settle:
                verts = {(k, i): [pts_[(k, i)][0], lat[k][i][0][1], pts_[(k, i)][1], lat[k][i][1]] for k in range(len(rings)) for i in range(len(lat[k]))}
                cells = []
                for k in range(len(rings) - 1):
                    for i in range(nang):
                        j = (i + 1) % nang
                        cells.append([(0, 0), (1, i), (1, j)] if k == 0 else [(k, i), (k, j), (k + 1, j), (k + 1, i)])
                lost = settle_cells(row, verts, cells)
                lat = [[((pts_[(k, i)][0], verts[(k, i)][1], pts_[(k, i)][1]), lat[k][i][1], lat[k][i][2]) for i in range(len(lat[k]))] for k in range(len(rings))]
            cell_no = -1
            for k in range(len(rings) - 1):
                for i in range(nang):
                    j = (i + 1) % nang
                    cell_no += 1
                    if cell_no in lost:
                        continue
                    if k == 0:
                        quad = [lat[0][0], lat[1][i], lat[1][j]]
                    else:
                        quad = [lat[k][i], lat[k][j], lat[k + 1][j], lat[k + 1][i]]
                    rho = sum(q[2] for q in quad) / len(quad)
                    poly_up(s, [q[0] for q in quad], pond_colour(row, rho, k, i))
            return
        xs, zs, _, _ = rect_plan(row)
        lat = []
        capv = set()
        if row.flush:
            capv = flush_capped(row, [[((j, i), xs[i], zs[j]), ((j, i + 1), xs[i + 1], zs[j]), ((j + 1, i + 1), xs[i + 1], zs[j + 1]),
                                       ((j + 1, i), xs[i], zs[j + 1])] for j in range(len(zs) - 1) for i in range(len(xs) - 1)])
        for jz, lz in enumerate(zs):
            line = []
            for ix, lx in enumerate(xs):
                bil, hi = row.sample(lx, lz)
                off = rect_off(row, lx, lz, bil)
                we = edge_weight(min((row.exr - lx) if lx >= 0 else (row.exl + lx), row.ez - abs(lz)))
                off = EDGE_OFF + (off - EDGE_OFF) * we
                cap = FLUSH_LANE if row.flush and ((jz, ix) in capv or in_ride_footprint(row, lx, lz) or (lane_strict(row) and abs(lx) <= row.hw + 1e-6)) else None
                line.append(((lx, lifted(row, bil, hi, off, abs(lx) <= 0.2 * row.W + 1e-6, cap), lz), bil))
            lat.append(line)
        lost = set()
        if row.settle:
            verts = {(j, i): [xs[i], lat[j][i][0][1], zs[j], lat[j][i][1]] for j in range(len(zs)) for i in range(len(xs))}
            cells = [[(j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)] for j in range(len(zs) - 1) for i in range(len(xs) - 1)]
            lost = settle_cells(row, verts, cells)
            lat = [[((xs[i], verts[(j, i)][1], zs[j]), lat[j][i][1]) for i in range(len(xs))] for j in range(len(zs))]
        for j in range(len(zs) - 1):
            for i in range(len(xs) - 1):
                if (j * (len(xs) - 1) + i) in lost:
                    continue
                quad = [lat[j][i], lat[j + 1][i], lat[j + 1][i + 1], lat[j][i + 1]]
                if row.gap is not None and max(abs(q[1] - row.g0) for q in quad) > row.gap:
                    continue
                gh = sum(q[1] for q in quad) / 4.0
                lx, lz = (xs[i] + xs[i + 1]) / 2.0, (zs[j] + zs[j + 1]) / 2.0
                if row.peers and flush_cell_covered(row, xs[i], xs[i + 1], zs[j], zs[j + 1]):
                    continue
                poly_up(s, [q[0] for q in quad], rect_colour(row, lx, lz, gh, i, j))
    return build


# Detail shells: where things sit on the rims. Rocks stay low (cobbles, 0.25 m above the ground at most), tufts are sage.

def settled(row, lx, lz, rad=0.7, limit=0.3):
    """Whether the ground is calm enough under a prop of this radius for it not to hang or sink."""
    c = row.sample(lx, lz)[0]
    return all(abs(row.sample(lx + dx, lz + dz)[0] - c) <= limit for dx, dz in ((rad, 0), (-rad, 0), (0, rad), (0, -rad)))


def rim_points(row, count, kind, salt):
    """(lx, lz) positions along both rims, evenly spread with a deterministic jitter, outside the ride bands. A position on
    steep ground is moved up to six times along the rim and dropped if none is calm."""
    pts = []
    if row.style == "pond":
        a, b = row.hw, row.hl
        lo, hi = {"rock": (0.5, 0.88), "chip": (1.0, 1.035), "tuft": (1.0, 1.036)}[kind]
        for k in range(count):
            phi = math.tau * (k + 0.5 + 0.4 * (hh(k, salt) - 0.5)) / count
            rho = lo + (hi - lo) * hh(k, salt, 1)
            pts.append((a * rho * math.cos(phi), b * rho * math.sin(phi)))
        return [p for p in pts if settled(row, *p)]
    hw = row.hw
    lo, hi = {
        "sandstone": {"rock": (hw - 0.4, hw + 2.6), "tuft": (hw + 0.6, hw + 2.8)},
        "concrete": {"rock": (hw + 1.3, hw + 2.8), "tuft": (hw + 1.3, hw + 2.8)},
        "canal": {"rock": (hw - 1.3, hw + 0.1), "tuft": (hw + 2.0, hw + 2.8)},
        "haul": {"rock": (hw - 0.8, hw + 0.4), "tuft": (hw + 1.2, hw + 2.8)},
        "rails": {"rock": (hw - 0.8, hw + 0.4), "tuft": (hw + 1.2, hw + 2.8)},
    }[row.style][kind]
    if row.flush and kind == "rock":
        lo = max(lo, hw + 0.6 + FLUSH_RIM_GAP)      # a rock's radius reaches 0.6 m from its centre
        hi = max(hi, lo + 1.0)
    per = max(1, count // 2)
    span = row.ez * 2.0 - 1.4
    for side in (-1, 1):
        for k in range(per):
            for tries in range(6):
                lz = -row.ez + 0.7 + span * (k + 0.5 + 0.7 * (hh(k, salt, side + 2 + 9 * tries) - 0.5)) / per
                lz = min(max(lz, -row.ez + 0.9), row.ez - 0.9)
                lx = side * (lo + (hi - lo) * hh(k, salt, side + 5 + 9 * tries))
                if row.flush and in_ride_footprint(row, lx, lz, FLUSH_PROP_REACH[kind]):
                    continue
                if settled(row, lx, lz) and (row.gap is None or abs(row.sample(lx, lz)[0] - row.g0) <= row.gap):
                    pts.append((lx, lz))
                    break
    return pts


def surface_off(row, lx, lz, bil):
    if row.style == "pond":
        return pond_off(row, pond_rho(row, lx, lz), 0)
    return rect_off(row, lx, lz, bil)


def rock_pal(row):
    return {"sandstone": (SAND, VARNISH), "concrete": (CONCRETE, FORM), "canal": (STONE, VARNISH), "haul": (STONE, VARNISH), "rails": (STONE, VARNISH), "pond": (STONE, SAND)}[row.style]


def liner_rocks(row):
    def build(s):
        pts = rim_points(row, ROCKS_MAX, "rock", 11)
        pa, pb = rock_pal(row)
        for k, (lx, lz) in enumerate(pts):
            bil, hi = row.sample(lx, lz)
            off = surface_off(row, lx, lz, bil)
            r = 0.3 + 0.3 * hh(k, 21)
            lift = 0.08 + 0.10 * hh(k, 22)
            yaw = math.tau * hh(k, 23)
            low, high = [], []
            for n in range(6):
                ang = yaw + math.tau * n / 6
                rr = r * (0.75 + 0.25 * ((n + k) % 3) / 2.0)
                px, pz = lx + rr * math.cos(ang), lz + rr * math.sin(ang)
                gb = row.sample(px, pz)[0]
                low.append((px, gb + off - 0.03 - row.g0, pz))
                hx, hz = lx + (px - lx) * 0.55, lz + (pz - lz) * 0.55
                hb = row.sample(hx, hz)[0]
                high.append((hx, min(hb + off + lift, hb + FEATURE_MAX) - row.g0, hz))
            hull(s, low, high, tone(pa, pb, k, 0.35))
    return build


def liner_tufts(row):
    def build(s):
        pts = rim_points(row, TUFTS_MAX, "tuft", 13)
        for k, (lx, lz) in enumerate(pts):
            bil, hi = row.sample(lx, lz)
            x, y, z = lx, bil - row.g0 - 0.02, lz
            size = 0.45 + 0.3 * hh(k, 31)
            for j in range(3):
                a = math.tau * (j / 3.0 + 0.11 * (k % 5))
                base = [(x + size * 0.12 * math.cos(math.tau * i / 4), y, z + size * 0.12 * math.sin(math.tau * i / 4)) for i in range(4)]
                tip = (x + math.cos(a) * size * 0.28, y + size * (0.9 - 0.15 * j), z + math.sin(a) * size * 0.28)
                s.add(base + [tip], [(3, 2, 1, 0)] + [(i, (i + 1) % 4, 4) for i in range(4)],
                      tone(SAGE if (k + j) % 3 else JUNIPER, VARNISH, k + j, 0.3))
    return build


def liner_build(rid, out_dir):
    row = Row(rid)
    plans = [(rid, [(rid + "_body", liner_base(row))], "base", LinerSurf)]
    if not row.flush:       # a flush_lane liner has no rim props, so no detail shells (the loader skips a missing shell)
        plans += [
            (rid + "_detail1", [(rid + "_detail1_mesh", liner_rocks(row))], "detail", Surf),
            (rid + "_detail2", [(rid + "_detail2_mesh", liner_tufts(row))], "detail", Surf),
        ]
    rows = []
    for name, builders, kind, surf_cls in plans:
        common.reset()
        kit.PARTS.clear()
        root = common.empty(name + "_recipe")
        for obj_name, fn in builders:
            s = surf_cls(obj_name, "enamel", smooth=False)
            fn(s)
            s.finish(root)
        path = Path(out_dir) / (name + ".glb")
        common.export(root, str(path))
        info = grind.gltf_info(path)
        m = info["metrics"]
        assert m["triangles"] <= BUDGET[kind]["tris"], (name, m["triangles"], BUDGET[kind])
        if kind == "detail":
            assert m["vertices"] <= 3000, (name, m["vertices"])
        assert m["materials"] == ["enamel"], (name, m["materials"])
        assert m["draws"] == 1, (name, m["draws"])
        assert not any("-col" in n for n in info["nodes"]), (name, info["nodes"])
        entry = {"file": path.name, "triangles": m["triangles"], "vertices": m["vertices"], "draws": m["draws"],
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print("FLUME_WORKS_EXPORT", rid, json.dumps(entry, sort_keys=True))
        rows.append(entry)
    return rows


SURFACE_N = 4        # barycentric lattice per triangle: (N+1)(N+2)/2 samples, vertices, edge midpoints and the centroid region included


def surface_in_footprints(row, pts, tris):
    """(highest, count) of the interpolated height above the ground over a barycentric lattice of every triangle, for the
    samples inside a ride footprint (ground by the same bilinear sample as the vertices)."""
    best, n = 0.0, 0
    n_ = SURFACE_N
    lattice = [(a / n_, b / n_, (n_ - a - b) / n_) for a in range(n_ + 1) for b in range(n_ + 1 - a)]
    for t in tris:
        p = [pts[i] for i in t]
        for u, v, w in lattice:
            x = u * p[0][0] + v * p[1][0] + w * p[2][0]
            z = u * p[0][2] + v * p[1][2] + w * p[2][2]
            if not in_ride_footprint(row, x, z):
                continue
            y = u * p[0][1] + v * p[1][1] + w * p[2][1]
            n += 1
            best = max(best, y + row.g0 - row.sample(x, z)[0])
    return best, n


def liner_check(rid, out_dir):
    """Re-read ground.bin and measure the base mesh against it; confirm there is no -col node anywhere."""
    row = Row(rid)
    fails = []
    for name in (rid,) if row.flush else (rid, rid + "_detail1", rid + "_detail2"):
        doc, binary = read_glb(Path(out_dir) / (name + ".glb"))
        if any("-col" in n["name"] for n in doc["nodes"]):
            fails.append("%s: has a -col node" % name)
        meshes = mesh_nodes(doc)
        if len(meshes) != 1:
            fails.append("%s: %d mesh nodes" % (name, len(meshes)))
            continue
        pts = mesh_positions(doc, binary, meshes[0])
        gaps = []
        for x, y, z in pts:
            gaps.append(y + row.g0 - row.sample(x, z)[0])
        lo, hi = min(gaps), max(gaps)
        if row.flush:
            lane = [g for (x, y, z), g in zip(pts, gaps) if lane_strict(row) and abs(x) <= row.hw + 1e-6]
            lane_max = max(lane) if lane else 0.0
            print("FLUME_WORKS_FLUSH", name, "lane verts %d  highest inside |x| < %.1f: %.3f m (limit %.2f)  %s" % (
                len(lane), row.hw, lane_max, FLUSH_LANE, "PASS" if lane_max <= FLUSH_LANE + 1e-4 else "FAIL"))
            if lane_max > FLUSH_LANE + 1e-4:
                fails.append("%s: %.3f m above the ground inside the lane (flush_lane limit %.2f)" % (name, lane_max, FLUSH_LANE))
            ride = [g for (x, y, z), g in zip(pts, gaps) if in_ride_footprint(row, x, z)]
            ride_max = max(ride) if ride else 0.0
            print("FLUME_WORKS_FLUSH", name, "inside any ride footprint: %d verts, highest %.3f m (limit %.2f)  %s" % (
                len(ride), ride_max, FLUSH_LANE, "PASS" if ride_max <= FLUSH_LANE + 1e-4 else "FAIL"))
            if ride_max > FLUSH_LANE + 1e-4:
                fails.append("%s: %.3f m above the ground inside a ride row's footprint (flush_lane limit %.2f)" % (name, ride_max, FLUSH_LANE))
            surf_max, surf_n = surface_in_footprints(row, pts, mesh_triangles(doc, binary, meshes[0]))
            if row.settle:
                print("FLUME_WORKS_FLUSH", name, "drawn surface inside any ride footprint: %d samples, highest interpolated %.3f m (limit %.2f)  %s" % (
                    surf_n, surf_max, FLUSH_LANE, "PASS" if surf_max <= FLUSH_LANE + 1e-4 else "FAIL"))
            else:
                print("FLUME_WORKS_FLUSH", name, "drawn surface (rule not enforced for this row): %d samples, highest interpolated %.3f m" % (surf_n, surf_max))
                surf_max = 0.0
            if surf_max > FLUSH_LANE + 1e-4:
                fails.append("%s: drawn surface %.3f m above the ground inside a ride row's footprint (flush_lane limit %.2f)" % (name, surf_max, FLUSH_LANE))
            if name == rid + "_detail1":
                near = min([abs(x) for x, y, z in pts] or [0.0])
                if near < row.hw + FLUSH_RIM_GAP - 1e-3:
                    fails.append("%s: rock vertex at |x| %.2f, inside hw + %.1f" % (name, near, FLUSH_RIM_GAP))
        if name == rid:
            ok = CHECK_MIN - 1e-4 <= lo and hi <= CHECK_MAX + 1e-4
            print("FLUME_WORKS_LINER", rid, "base verts %d  vertical gap to ground %.3f .. %.3f m (allowed %.2f .. %.2f)  no -col: %s  %s" % (
                len(pts), lo, hi, CHECK_MIN, CHECK_MAX, "yes" if not any('-col' in n['name'] for n in doc['nodes']) else "NO", "PASS" if ok else "FAIL"))
            if not ok:
                fails.append("%s: gap %.3f .. %.3f outside %.2f .. %.2f" % (name, lo, hi, CHECK_MIN, CHECK_MAX))
            floor = [g for (x, y, z), g in zip(pts, gaps) if abs(x) <= 0.2 * row.W and row.style != "pond"]
            if floor and max(floor) > BASE_OFF + 0.03 + 1e-4:
                fails.append("%s: floor band %.3f m above the ground" % (name, max(floor)))
        else:
            print("FLUME_WORKS_LINER", name, "shell verts %d  gap %.3f .. %.3f m" % (len(pts), lo, hi))
            limit = FEATURE_MAX + 0.02 if name.endswith("1") else 0.75
            if hi > limit:
                fails.append("%s: stands %.3f m proud (limit %.2f)" % (name, hi, limit))
    return fails


# ------------------------------------------------------------------ export, build, check

def export(name, builders, rail, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name + "_recipe")
    for obj_name, fn in builders:
        s = Surf(obj_name, "enamel", smooth=False)
        fn(s)
        s.finish(root)
    for k, p in enumerate(rail):
        common.empty("%s-rail_%02d" % (name, k), kit.xyz(p), root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    return path


def build(rid, out_dir):
    if rid in LINERS:
        return liner_build(rid, out_dir)
    spec = RECIPES[rid]
    rail = flume_rail2(spec["flume"], rid) if spec["kind"] == "flume" else []
    plans = [
        (rid, [(rid + "_body", spec["body"]), (rid + COL_NODE, spec["col"])], rail, "base"),
        (rid + "_detail1", [(rid + "_detail1_mesh", spec["d1"])], [], "detail"),
        (rid + "_detail2", [(rid + "_detail2_mesh", spec["d2"])], [], "detail"),
    ]
    rows = []
    for name, builders, rails, kind in plans:
        path = export(name, builders, rails, out_dir)
        info = grind.gltf_info(path)
        tris = info["metrics"]["triangles"]
        assert tris <= BUDGET[kind]["tris"], (name, tris, BUDGET[kind])
        assert info["metrics"]["materials"] == ["enamel"], (name, info["metrics"]["materials"])
        draws = info["metrics"]["draws"] - (1 if kind == "base" else 0)    # the -col mesh is never drawn
        assert draws <= (1 if kind == "base" else BUDGET[kind]["draws"]), (name, draws)
        if kind == "base":
            assert (rid + COL_NODE) in [m[0] for m in info["meshes"]], (name, info["meshes"])
            assert sum(1 for n in info["nodes"] if n.startswith(rid + "-rail_")) == len(rail), (name, info["nodes"])
        row = {"file": path.name, "triangles": tris, "draws": draws, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print("FLUME_WORKS_EXPORT", rid, json.dumps(row, sort_keys=True))
        rows.append(row)
    return rows


def read_glb(path):
    data = Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    binary = data[20 + length + 8:]
    return doc, binary


def mesh_positions(doc, binary, node_name):
    """All vertex positions of the mesh on the named node, in the node's local space (the recipe roots are identity)."""
    node = next(n for n in doc["nodes"] if n.get("name") == node_name)
    out = []
    for prim in doc["meshes"][node["mesh"]]["primitives"]:
        acc = doc["accessors"][prim["attributes"]["POSITION"]]
        view = doc["bufferViews"][acc["bufferView"]]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        for i in range(acc["count"]):
            out.append(struct.unpack_from("<3f", binary, base + i * stride))
    return out


def mesh_triangles(doc, binary, node_name):
    """Every triangle of the mesh on the named node as three vertex indices."""
    node = next(n for n in doc["nodes"] if n.get("name") == node_name)
    out = []
    for prim in doc["meshes"][node["mesh"]]["primitives"]:
        acc = doc["accessors"][prim["indices"]]
        view = doc["bufferViews"][acc["bufferView"]]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        fmt, size = {5123: ("<H", 2), 5125: ("<I", 4), 5121: ("<B", 1)}[acc["componentType"]]
        idx = [struct.unpack_from(fmt, binary, base + i * size)[0] for i in range(acc["count"])]
        out += [tuple(idx[i:i + 3]) for i in range(0, len(idx) - 2, 3)]
    return out


def mesh_nodes(doc):
    return [n["name"] for n in doc["nodes"] if "mesh" in n]


def bbox(pts):
    return [min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)]


def corners_of(rid):
    spec = RECIPES[rid]
    L, H, W = spec["size"]
    hx, hz = W / 2, L / 2
    if spec["kind"] == "box":
        return {(x, y, z) for x in (-hx, hx) for y in (0.0, H) for z in (-hz, hz)}
    return {(-hx, 0.0, -hz), (hx, 0.0, -hz), (hx, 0.0, hz), (-hx, 0.0, hz), (-hx, H, -hz), (hx, H, -hz)}


def check(rid, out_dir):
    """Programmatic verification of one recipe's GLBs. Returns a list of failure strings (empty when it passes)."""
    if rid in LINERS:
        return liner_check(rid, out_dir)
    spec = RECIPES[rid]
    if spec["kind"] == "intake":
        return intake_check(rid, out_dir)
    fails = []
    L, H, W = spec["size"]
    base = Path(out_dir) / (rid + ".glb")
    doc, binary = read_glb(base)
    if spec["kind"] in ("box", "wedge"):
        pts = mesh_positions(doc, binary, rid + COL_NODE)
        uniq_pts = {tuple(round(c, 4) for c in p) for p in pts}
        want = {tuple(round(c, 4) for c in p) for p in corners_of(rid)}
        if uniq_pts != want:
            fails.append("%s: -col corners %s != %s" % (rid, sorted(uniq_pts), sorted(want)))
        lo, hi = bbox(pts)
        if max(abs(lo[0] + W / 2), abs(hi[0] - W / 2), abs(lo[1]), abs(hi[1] - H), abs(lo[2] + L / 2), abs(hi[2] - L / 2)) > 0.001:
            fails.append("%s: -col bbox %s %s" % (rid, lo, hi))
        # Hugging: the drawn base and both shells stay within HOP outward (decals on a slope within 0.02) of the box.
        tops = {"box": 0.001, "wedge": 0.02}[spec["kind"]]
        for name in (rid, rid + "_detail1", rid + "_detail2"):
            d, b = read_glb(Path(out_dir) / (name + ".glb"))
            node = next(n for n in mesh_nodes(d) if not n.endswith("-col"))
            lo2, hi2 = bbox(mesh_positions(d, b, node))
            under_ok = rid == "crew_bunk_ledge"
            limits = [(lo2[0], -W / 2 - HOP, "min x"), (lo2[2], -L / 2 - HOP, "min z"), (lo2[1], -0.001 if not under_ok else -5.0 - 1e-3, "min y")]
            for v, lim, label in limits:
                if v < lim - 1e-4:
                    fails.append("%s %s %s %.3f < %.3f" % (name, node, label, v, lim))
            if hi2[0] > W / 2 + HOP + 1e-4 or hi2[2] > L / 2 + HOP + 1e-4:
                fails.append("%s proud %s" % (name, hi2))
            if hi2[1] > H + (tops if "detail" in name or spec["kind"] == "wedge" else 0.001) + 1e-4:
                fails.append("%s above the top: %.4f > %.4f" % (name, hi2[1], H))
            if name == rid:
                # No recess deeper than RECESS: the base spans the box to within RECESS on the +/- faces it must touch.
                if lo2[0] > -W / 2 + RECESS or hi2[0] < W / 2 - RECESS or lo2[2] > -L / 2 + RECESS or hi2[2] < L / 2 - RECESS:
                    fails.append("%s: base does not reach the box faces %s %s" % (rid, lo2, hi2))
                if spec["kind"] == "box" and abs(hi2[1] - H) > 0.001:
                    fails.append("%s: base top %.4f != H %.4f" % (rid, hi2[1], H))
    else:
        f = FLUME
        pts = mesh_positions(doc, binary, rid + COL_NODE)
        sect = {(round(abs(p[0]), 3), round(p[1], 3)) for p in pts if abs(p[2]) < 1e-4}
        for x, y in ((f["wall_in"], f["under"]), (f["base_out"], f["under"]), (f["crest_out"], f["top"]), (f["crest_in"], f["top"]), (f["wall_in"], f["floor_y"])):
            if (round(x, 3), round(y, 3)) not in sect:
                fails.append("%s: section point %s missing at z 0 (%s)" % (rid, (x, y), sorted(sect)))
        if f["crest_out"] - f["crest_in"] < grind.MIN_TOP:
            fails.append("rideable strip %.2f < %.2f" % (f["crest_out"] - f["crest_in"], grind.MIN_TOP))
        ring = flume_ring(1)
        for a, b in zip(ring, ring[1:] + ring[:1]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            if abs(dy) > 1e-9 and abs(dx) > 1e-9 or abs(dx) < 1e-9 and abs(dy) > 1e-9:
                ny = abs(dx) / math.hypot(dx, dy)
                if ny > 0.7 and not (a[1] == b[1] == f["top"]):
                    fails.append("flat face in the ring %s -> %s" % (a, b))
        length = spec["size"][0]
        lo, hi = bbox(pts)
        if lo[2] < -0.36 or hi[2] > length + 0.36:
            fails.append("%s: z extent %s %s" % (rid, lo[2], hi[2]))
        rails = sorted(n["name"] for n in doc["nodes"] if n["name"].startswith(rid + "-rail_"))
        if len(rails) != spec["flume"]["rail_n"] + 1:
            fails.append("%s: %d rail empties" % (rid, len(rails)))
        if rid == "flume_siphon_span":
            want_low = f["floor_y"] - 21.0 - 11.0
            if lo[1] > want_low + 0.5 or lo[1] < want_low - 0.1:
                fails.append("%s: legs reach y %.2f, want %.2f" % (rid, lo[1], want_low))
            nd = {n["name"]: n for n in doc["nodes"]}
            last = nd[rails[-1]]["translation"]
            if abs(last[1] - (f["top"] - 21.0 * smooth((length - grind.END_INSET) / length))) > 0.01:
                fails.append("%s: last rail empty y %s" % (rid, last))
    return fails


def intake_check(rid, out_dir):
    fails = []
    f = FLUME
    doc, binary = read_glb(Path(out_dir) / (rid + ".glb"))
    pts = mesh_positions(doc, binary, rid + COL_NODE)
    # The z = 16 section is the FLUME ring (and wring(side, 16, 0) is its source).
    want = {(round(abs(p[0]), 3), round(p[1], 3)) for side in (-1, 1) for p in wring(side, INTAKE_L, 0.0)}
    end = [p for p in pts if abs(p[2] - INTAKE_L) < 1e-3]
    for x, y in want:
        if not any(abs(abs(p[0]) - x) <= 0.01 and abs(p[1] - y) <= 0.01 for p in end):
            fails.append("%s: z=16 section point %s missing" % (rid, (x, y)))
    for p in end:
        if not any(abs(abs(p[0]) - x) <= 0.01 and abs(p[1] - y) <= 0.01 for x, y in want):
            fails.append("%s: z=16 section has an extra point %s" % (rid, p))
    mouth = [p for p in pts if abs(p[2]) < 1e-3]
    top0 = max(p[1] for p in mouth)
    if abs(top0 - (f["floor_y"] - INTAKE_MOUTH_DROP)) > 0.01:
        fails.append("%s: mouth floor %.3f != %.3f" % (rid, top0, f["floor_y"] - INTAKE_MOUTH_DROP))
    lo, hi = bbox(pts)
    if lo[2] < -0.36 or hi[2] > INTAKE_L + 0.36 or hi[2] < INTAKE_L - 0.36 or lo[2] > 0.36:
        fails.append("%s: z extent %s %s" % (rid, lo[2], hi[2]))
    for p in pts:
        z = min(INTAKE_L, max(0.0, p[2]))
        if p[1] > intake_floor(z) + intake_h(z) + 0.01:
            fails.append("%s: -col vertex above the wall top %s" % (rid, p))
            break
    for p in pts:
        z = min(INTAKE_L, max(0.0, p[2]))
        if abs(p[0]) < intake_half(z) - 0.01 and p[1] > intake_floor(z) + 0.01:
            fails.append("%s: -col vertex inside the trough above the floor %s" % (rid, p))
            break
    rails = [n for n in doc["nodes"] if n["name"].startswith(rid + "-rail_")]
    if rails:
        fails.append("%s: unexpected rail empties" % rid)
    return fails


FLUSH_NOTES = {
    "sandstone": "a flush sandstone sheet: banded strata relief of at most 0.06 m with colour bands and varnish streaks inside the lane",
    "haul": "a flush graded gravel sheet with two tyre-rut colour bands and a verge band of low cobble relief",
    "rails": "a flush light-rail bed: two rails 0.03 m proud of a gravel bed, flush colour bands for the tie sleepers and a verge band of low cobble relief",
    "concrete": "a board-formed concrete chute with form joints, coping bands, wall relief and the painted gauge staff: the joints, the wall and the gauge are capped to the 0.12 m band inside every ride row's footprint, not removed, and keep their full relief outside",
    "canal": "a canal lining with a lip band, earth batter and colour bands: the lip is capped to the 0.12 m band inside every ride row's footprint, not removed, and keeps its full relief outside",
    "pond": "a stone-pitched pond lining with a concrete rim ring and a flush floor: the rim ring and the pitching are capped to the 0.12 m band inside every ride row's footprint, not removed, and keep their full relief outside",
}


def liner_registry(rid):
    park = LINERS[rid].get("park", "park_flume")
    if LINERS[rid].get("flush_lane"):
        text = ("Decoration only, conformed to the " + park + " bake; rebuild after a re-bake. Procedural, authored in this repository from Blender bmesh sheets; no external mesh. "
                "No -col mesh: the stamped terrain stays the only collider. Ships " + FLUSH_NOTES[LINERS[rid]["style"]] + ". "
                + ("Flush lane: the drawn surface, vertices and interpolated triangles, inside any ride row's footprint stays within 0.12 m of the ground" if LINERS[rid].get("flush_surface", True) else "Flush lane: every vertex inside any ride row's footprint stays within 0.12 m of the ground") + (", the verge band included" if LINERS[rid]["style"] in ("sandstone", "haul", "rails") else "") + ", and the sheet ships no rim props (no rocks, no tufts) and no detail shells.")
        return [{"id": rid, "path": "res://assets/models/park/%s.glb" % rid, "class": "landform", "origin": "centre",
                 "ships": True, "loader": "src/world/park/park_recipes.gd",
                 "provenance": {"recipe": "tools/blender/park/flume_works.py", "note": text}}]
    note = ("Decoration only, conformed to the " + park + " bake; rebuild after a re-bake. Procedural, authored in this repository from Blender bmesh sheets; no external mesh. No -col mesh: the stamped terrain stays the only collider. "
            + LINER_NOTES[LINERS[rid]["style"]] + LINER_NOTES_EXTRA.get(rid, "") + ".")
    rows = []
    for name, base, text in ((rid, True, note),
                             (rid + "_detail1", False, "Decoration only, conformed to the %s bake; rebuild after a re-bake. Detail shell 1 of %s, drawn by range (the detail class): small rocks on the rims." % (park, rid)),
                             (rid + "_detail2", False, "Decoration only, conformed to the %s bake; rebuild after a re-bake. Detail shell 2 of %s, drawn by range (the detail class): sage tufts on the rims." % (park, rid))):
        rows.append({"id": name, "path": "res://assets/models/park/%s.glb" % name, "class": "landform" if base else "detail", "origin": "centre",
                     "ships": True, "loader": "src/world/park/park_recipes.gd",
                     "provenance": {"recipe": "tools/blender/park/flume_works.py", "note": text}})
    return rows


def registry_doc(pit=False, isles=False):
    rows = []
    for rid in (ISLES_LINER_IDS if isles else PIT_LINER_IDS if pit else IDS + LINER_IDS):
        if rid in LINERS:
            rows += liner_registry(rid)
            continue
        spec = RECIPES[rid]
        origin = "entry_lip" if spec["kind"] in ("flume", "intake") else "centre"
        notes = {
            "flume_bent_50": "the flume crews' plank-sheathed timber bent tower, 50 m, with bent number board and speed-tick band",
            "flume_bent_32": "the flume crews' plank-sheathed timber bent tower, 32 m, with bent number board and speed-tick band",
            "survey_mast_40": "the flume survey crew's mast: concrete footing, survey-rod banded timber, copper plate, pulley block",
            "surge_pylon_28": "board-formed concrete surge-line pylon, 28 m, steel crossarm and glass-green insulators",
            "surge_pylon_48": "board-formed concrete surge-line pylon, 48 m, steel crossarm and glass-green insulators",
            "anchor_block_16x28x8": "dam-era penstock anchor block with a flush iron saddle ring and cut pipe stub",
            "weir_gatehouse": "small concrete weir gatehouse with door, gate wheel and flat roof",
            "annex_hall": "heat-exchanger annex hall with a flat rideable roof, pipe runs and a pressure dial",
            "crew_bunk_ledge": "the flume crews' bunk ledge: plank deck on joists and knee braces with numbered bunk boards",
            "weir_apron": "concrete weir apron wedge with form joints as colour",
            "gap_work_deck": "the flume crews' timber work deck wedge down the butte gap, lane stripes and trestle framing",
            "rim_road": "dam-era rim road wedge: graded sand surface, wheel ruts, curb logs, mileposts",
            "flume_pour_spout": "level 14 m flume with a curved pour lip; same trough section as flume_span; rail empties on the crest",
            "flume_siphon_span": "100.8 m flume whose whole section falls 21 m on a smoothstep profile; bents to 11 m below the floor",
            "flume_reach_120": "level 120 m flume reach with a bent at both ends so it tiles; bents to 11 m below the floor",
            "flume_intake_16": "dam-era flume intake: a 16 m mouth whose walls and floor flare from 14 m wide and flush to the flume section, so a ball rolling in from open ground is funnelled into the trough; sluice gate hung open overhead",
        }
        note = notes.get(rid, "timber crib pier or wall, squared courses with recessed rock fill and iron drift pins")
        for name, suffix in ((rid, ""), (rid + "_detail1", "d1"), (rid + "_detail2", "d2")):
            base = not suffix
            rows.append({
                "id": name, "path": "res://assets/models/park/%s.glb" % name, "class": "landform" if base else "detail", "origin": origin,
                "ships": True, "loader": "src/world/park/park_recipes.gd",
                "provenance": {"recipe": "tools/blender/park/flume_works.py",
                               "note": ("Procedural, authored in this repository from Blender bmesh solids; no external mesh. " + note + ". Collider identical to the grey box it replaces." if base and spec["kind"] not in ("flume", "intake")
                                        else "Procedural, authored in this repository from Blender bmesh solids; no external mesh. " + note + "." if base
                                        else "Detail shell %s of %s, drawn by range (the detail class), additive to the base." % (suffix[1], rid))},
            })
    return {"assets": rows}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true", help="build into a scratch directory and print counts; ship nothing")
    parser.add_argument("--check", action="store_true", help="verify the GLBs in --out-dir instead of building")
    parser.add_argument("--liners", action="store_true", help="act on the liner ids only (default: the original pieces)")
    parser.add_argument("--registry", action="store_true", help="print the registry.d fragment")
    parser.add_argument("--isles", action="store_true", help="the islands liners (assets/registry.d/park_islands_liners.json)")
    parser.add_argument("--pit", action="store_true", help="the pit liners (assets/registry.d/park_pit_liners.json) instead of the flume's")
    args = parser.parse_args(argv)
    if args.registry:
        print(json.dumps(registry_doc(args.pit, args.isles), indent=1))
        return
    ids = [rid for rid in (ISLES_LINER_IDS if args.isles else PIT_LINER_IDS if args.pit else LINER_IDS if args.liners else IDS) + ([args.only] if args.only else []) if not args.only or rid == args.only]
    ids = list(dict.fromkeys(ids))
    if args.check:
        bad = []
        for rid in ids:
            fails = check(rid, args.out_dir)
            print("FLUME_WORKS_CHECK", rid, "PASS" if not fails else "FAIL")
            bad += fails
        for line in bad:
            print("FLUME_WORKS_FAIL", line)
        if bad:
            sys.exit(1)
        return
    out_dir = tempfile.mkdtemp(prefix="flume_works_count_") if args.count_only else args.out_dir
    for rid in ids:
        build(rid, out_dir)


if __name__ == "__main__":
    main()
