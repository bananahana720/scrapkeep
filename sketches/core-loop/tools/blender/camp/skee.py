"""Headless recipe for camp_skee_lane.glb, camp_skee_lane_detail1.glb and camp_skee_lane_detail2.glb (camp kit, _camp.py header).

One WORKING skee-ball lane, played with the player's own 1 m ball and its own physics. Origin at the lane's foot centre on the
ground; local +Z faces the plaza (the player rolls in from there), the ball rolls up the lane toward -Z.

The lane: 5.5 m between the rails, 23.5 m long. A gentle rise of 1.2 m over 20 m (3.4 degrees, surface y 0.1 to 1.3), then a
kicker: a 1.5 m hump over 3.5 m whose curve steepens to a lip at about 35 degrees (y 2.8, z -23.5) and throws the ball over a
3 m trough onto the target board. Felt-sage baize with mint lane arrows and a mint start bar, 1.2 m copper rails, timber
cabinet sides.
The board: 11.3 m wide, 14.2 m up the slope, inclined 35 degrees (rising toward -Z), with seven cups cut into it, each a real
pocket in the collision (a 16-sided tube 1.5 m deep with a floor, so a ball can sit in it). Opening radii (m), across the
board's u (left/right) and v (up the slope): cup_10 r 2.0 (big, low centre), cup_20 r 1.4, cup_30 and cup_40 r 1.3 (left and
right), cup_50 r 1.25, cup_100_l and cup_100_r r 1.25 (top corners). The pocket is a 16-gon, so the clear inradius is r cos(pi/16);
the smallest opening is 2.45 m across and the recipe asserts every pocket fits a 1.1 m-radius sphere. A ball that misses a
cup rolls down the board into the trough (z -26.5 to -23.5; the kicker's 1.6 m face above it keeps the ball off the lane),
whose floor falls a steady 3% toward the return gutter on the +X side (y 1.214 at x -5.65 to 0.95 at x 3.15) and meets the
gutter's head with no step. The gutter (x 3.15 to 5.65) falls one steady 3% with no flat stretch, 0.9 m over 30 m, from y 0.95
at its head (z -26.5) to 0.05 at its open end (z 3.5), and carries the ball past the return_exit socket beside the lane's foot.
3% beats the player ball's rolling resistance: at the game's gravity of 26 m/s^2 a rolling ball runs down it at (5/7) 26 0.03
= 0.56 m/s^2 against 0.30 (tuning.gd), and check_base asserts the margin.
The scoreboard arch stands over the board: two posts and a header with blank amber number panels (runtime draws the digits)
and a copper crown carrying marquee bulbs.

Class park_large for the lane, detail for both shells. Colour: felt-sage lane, mint arrows (the player's verb), copper rails,
timber cabinet sides, amber score panels. No hazard red, no letters.
Collision (everything solid and closed so the ball cannot tunnel): the lane body, both rails, the hump, the trough, the gutter and
its walls, the board with its seven pockets, the side walls, the backstop, the arch posts and header.
Physics check: scripts/cloud/skee_lab/lab.gd (README "Skee-ball physics check").
Sockets: start (foot centre, y 1.0), cup_10 .. cup_50, cup_100_l, cup_100_r (each at its cup's floor centre), score (scoreboard
face centre), return_exit (4.4, 1.08, 2.5: the centre of a ball rolling in the gutter beside the lane's foot, 1 m before its
open end), lip (0, 3.8, -23.5: the ball centre on the kicker lip; the physics lab holds forward until the ball passes it),
interact (ball height just in front of the foot) and light_00 .. light_10 (marquee bulb centres).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/skee.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
T["amber_dk"] = "9a6a16"

LANE_HW, RAIL_T, RAIL_H = 2.75, 0.4, 1.2
LANE_L, RISE, HUMP_H, HUMP_L = 23.5, 1.2, 1.5, 3.5
CAB = 6.05
W = 5.65
TH = math.radians(35.0)
ST, CT = math.sin(TH), math.cos(TH)
Z0, Y0, BL = -26.5, 1.65, 14.2
Z_END, Y_END = Z0 - BL * CT, Y0 + BL * ST
DEPTH = 1.5
NSEG = 16

CUPS = {
    "cup_10": (0.0, 2.4, 2.0), "cup_20": (0.0, 6.5, 1.4), "cup_30": (-2.6, 8.8, 1.3), "cup_40": (2.6, 8.8, 1.3),
    "cup_50": (0.0, 10.6, 1.25), "cup_100_l": (-4.0, 12.1, 1.25), "cup_100_r": (4.0, 12.1, 1.25),
}
BAND = {"cup_10": "bone", "cup_20": "bone", "cup_30": "sandstone", "cup_40": "sandstone", "cup_50": "amber",
        "cup_100_l": "amber", "cup_100_r": "amber"}

ARCH_Z0, ARCH_Z1 = -35.4, -34.0
HEAD_Y0, HEAD_Y1 = 11.6, 14.4
FACE_Z = ARCH_Z1 + 0.15
CROWN_R, CROWN_CY = 14.4, 1.5


def lane_h(d):
    """Lane surface height at distance d up the lane (0 at the foot)."""
    if d < 0.0:
        return 0.06 + 0.04 * (d + 0.6) / 0.6
    if d <= LANE_L - HUMP_L:
        return 0.1 + RISE * d / (LANE_L - HUMP_L)
    t = (d - (LANE_L - HUMP_L)) / HUMP_L
    return 0.1 + RISE + HUMP_H * (0.35 * t + 0.65 * t * t)


def lane_rows():
    run = LANE_L - HUMP_L
    rows = [-0.6, 0.0] + [run * k / 5 for k in range(1, 6)]
    rows += [run + HUMP_L * i / 7 for i in range(1, 8)]
    return rows


G_GAME, RR_GAME = 26.0, 0.30
FALL = 0.03
GX = LANE_HW + RAIL_T
GUT_END = 3.5
RET_Z = 2.5
GUT = [(Z0, 0.05 + FALL * (GUT_END - Z0)), (GUT_END, 0.05)]
TROUGH = [(-W, GUT[0][1] + FALL * (GX + W)), (GX, GUT[0][1])]


def gut_y(z):
    for (z0, y0), (z1, y1) in zip(GUT, GUT[1:]):
        if z <= z1:
            return y0 + (y1 - y0) * (z - z0) / (z1 - z0)
    return GUT[-1][1]


def P(u, v, h=0.0):
    """A point on the board: u across, v up the slope, h along the board normal."""
    return (u, Y0 + v * ST + h * CT, Z0 - v * CT + h * ST)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def plate(s, pts, drop, color):
    """A closed prism: the polygon pts extruded by the vector drop. Every piece in this recipe is a closed single-colour solid,
    so the exporter's normal pass turns every face outward."""
    n = len(pts)
    verts = list(pts) + [tuple(p[k] + drop[k] for k in range(3)) for p in pts]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    s.add(verts, faces, color)


def thin(s, pts, hint, thick, color):
    """A decal: pts lies on a surface whose outward normal is hint; the prism goes thick below it."""
    m = math.sqrt(sum(v * v for v in hint))
    plate(s, pts, tuple(-v / m * thick for v in hint), color)


TL = 0.04


def topped(s, top, bot, w0, w1, topcol, sidecol, axis="x"):
    """A closed solid: top polyline (t, y) and bottom polyline (t, y) extruded across w0..w1. axis x: t is z and w is x;
    axis z: t is x and w is z. When topcol differs from sidecol the top TL metres are separate coloured layers (topcol may be
    a list, one colour per top segment) so no vertex colour has to blend."""
    def pt(t, y, w):
        return (w, y, t) if axis == "x" else (t, y, w)
    layered = isinstance(topcol, list) or topcol != sidecol
    low = [(t, y - TL) for t, y in top] if layered else list(top)
    prof = low + list(reversed(bot))
    m = len(prof)
    verts = [pt(t, y, w) for w in (w0, w1) for t, y in prof]
    faces = [tuple(range(m)), tuple(range(2 * m - 1, m - 1, -1))]
    faces += [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
    s.add(verts, faces, sidecol)
    if layered:
        for i in range(len(top) - 1):
            c = topcol[i % len(topcol)] if isinstance(topcol, list) else topcol
            (a0, a1), (b0, b1) = top[i], top[i + 1]
            plate(s, [pt(a0, a1, w0), pt(a0, a1, w1), pt(b0, b1, w1), pt(b0, b1, w0)], (0, -TL, 0), c)


def zline(z0, z1, f):
    return [(z0, f(z0)), (z1, f(z1))]


def cup_poly(u, v, r):
    return [(u + r * math.cos((k + 0.5) * math.tau / NSEG), v + r * math.sin((k + 0.5) * math.tau / NSEG)) for k in range(NSEG)]


def board_top(s, color=True):
    """The board surface with a 16-gon hole per cup: a trapezoid decomposition, each trapezoid a 0.3 m closed prism."""
    polys = [cup_poly(*c) for _, c in sorted(CUPS.items())]
    vs = sorted({round(v, 6) for p in polys for _, v in p} | {0.0, BL})
    k = 0
    for v0, v1 in zip(vs, vs[1:]):
        if v1 - v0 < 1e-6:
            continue
        edges = []
        for p in polys:
            for i in range(NSEG):
                a, b = p[i], p[(i + 1) % NSEG]
                lo, hi = min(a[1], b[1]), max(a[1], b[1])
                if hi - lo < 1e-9 or lo > v0 + 1e-6 or hi < v1 - 1e-6:
                    continue
                f = lambda v: a[0] + (b[0] - a[0]) * (v - a[1]) / (b[1] - a[1])
                edges.append((f(v0), f(v1)))
        edges.sort(key=lambda e: e[0] + e[1])
        assert len(edges) % 2 == 0, ("odd edge crossing", v0, v1)
        bounds = [(-W, -W)] + edges + [(W, W)]
        for i in range(0, len(bounds), 2):
            a, b = bounds[i], bounds[i + 1]
            col = cp.jitter_tone("felt", k, 0.05) if color else "felt"
            k += 1
            plate(s, [P(a[0], v0), P(b[0], v0), P(b[1], v1), P(a[1], v1)], (0, -0.3 * CT, -0.3 * ST), col)


def cup_body(s):
    """Each pocket: sixteen wall plates (0.12 m thick, outside the opening) and a closed floor plate, so a ball can sit in it."""
    for cid, (u, v, r) in sorted(CUPS.items()):
        poly = cup_poly(u, v, r)
        for i in range(NSEG):
            a, b = poly[i], poly[(i + 1) % NSEG]
            mu, mv = (a[0] + b[0]) / 2 - u, (a[1] + b[1]) / 2 - v
            m = math.hypot(mu, mv)
            out = P(mu / m * 0.12, mv / m * 0.12, 0.0)
            drop = (out[0], out[1] - Y0, out[2] - Z0)
            plate(s, [P(a[0], a[1], 0.0), P(b[0], b[1], 0.0), P(b[0], b[1], -DEPTH), P(a[0], a[1], -DEPTH)], drop, "iron_hi")
        plate(s, [P(x, y, -DEPTH) for x, y in poly], (0, -0.3 * CT, -0.3 * ST), "charcoal")


def ring_board(s, u, v, r0, r1, h0, h1, color):
    """A closed rectangular-section ring lying on the board around a cup."""
    quad = [(r0, h0), (r1, h0), (r1, h1), (r0, h1)]
    verts = [P(u + r * math.cos((k + 0.5) * math.tau / NSEG), v + r * math.sin((k + 0.5) * math.tau / NSEG), h)
             for k in range(NSEG) for r, h in quad]
    faces = []
    for i in range(NSEG):
        j = (i + 1) % NSEG
        for k in range(4):
            m = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + m, j * 4 + m, j * 4 + k))
    s.add(verts, faces, color)


def cup_decor(s):
    for cid, (u, v, r) in sorted(CUPS.items()):
        ring_board(s, u, v, r, r + 0.2, -0.1, 0.06, "copper")
        ring_board(s, u, v, r + 0.34, r + 0.54, -0.02, 0.04, BAND[cid])
        thin(s, [P(x, y, -DEPTH + 0.04) for x, y in cup_poly(u, v, r * 0.45)], (0, CT, ST), 0.04, "amber")


def lane_profile():
    return [(-d, lane_h(d)) for d in lane_rows()]


def flat_bot(top):
    return [(top[0][0], 0.0), (top[-1][0], 0.0)]


def structure(s, col=False):
    side = lane_profile()
    felt = [cp.jitter_tone("felt", k, 0.04) for k in range(len(side) - 1)]
    topped(s, side, flat_bot(side), -LANE_HW, LANE_HW, felt, "timber", "x")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * LANE_HW, sx * (LANE_HW + RAIL_T)))
        topped(s, side, flat_bot(side), x0, x1, "timber_lt", "timber", "x")
        topped(s, [(z, y + RAIL_H) for z, y in side], side, x0, x1, "copper", "copper", "x")
    topped(s, TROUGH, flat_bot(TROUGH), Z0, -LANE_L, "iron_hi", "timber", "z")
    topped(s, [(Z0, 3.05), (-LANE_L, 3.05)], flat_bot([(Z0, 0), (-LANE_L, 0)]), -CAB, -W, "timber_lt", "timber", "x")
    s.box((CAB - 3.15, 3.05, 0.6), (-(CAB + 3.15) / 2, 3.05 / 2, -LANE_L - 0.3 + 0.6), T["timber"])
    gz = list(GUT)
    topped(s, gz, flat_bot(gz), 3.15, W, "iron_hi", "timber", "x")
    topped(s, [(z, y + 1.65) for z, y in gz], flat_bot(gz), W, CAB, "timber_lt", "timber", "x")
    bw = [(Z_END, Y_END + 1.4), (Z0, Y0 + 1.4)]
    for x0, x1 in ((-CAB, -W), (W, CAB)):
        topped(s, bw, flat_bot(bw), x0, x1, "timber_lt", "timber", "x")
    s.box((2 * CAB, Y_END + 2.6, 0.6), (0, (Y_END + 2.6) / 2, Z_END - 0.3), T["timber"])
    s.box((2 * W, Y0, 0.1), (0, Y0 / 2, Z0 - 0.05), T["timber"])
    board_top(s, color=not col)
    cup_body(s)
    zc = (ARCH_Z0 + ARCH_Z1) / 2
    for sx in (-1, 1):
        s.box((0.7, HEAD_Y0, ARCH_Z1 - ARCH_Z0), (sx * (CAB + 0.35), HEAD_Y0 / 2, zc), T["timber"])
    s.box((2 * (CAB + 0.7), HEAD_Y1 - HEAD_Y0, ARCH_Z1 - ARCH_Z0), (0, (HEAD_Y0 + HEAD_Y1) / 2, zc), T["iron"])


def strip(s, d0, d1, x0, x1, lift, color):
    """A flat painted strip on the lane between d0 and d1 (split at the lane's row edges)."""
    cuts = [d0] + [d for d in lane_rows() if d0 < d < d1] + [d1]
    for a, b in zip(cuts, cuts[1:]):
        thin(s, [(x0, lane_h(a) + lift, -a), (x1, lane_h(a) + lift, -a), (x1, lane_h(b) + lift, -b), (x0, lane_h(b) + lift, -b)],
             (0, 1, 0), 0.02, color)


def chevron(s, d, color):
    outer = [(-1.1, d - 0.5), (0.0, d + 0.7), (1.1, d - 0.5)]
    inner = [(1.1, d - 1.0), (0.0, d + 0.2), (-1.1, d - 1.0)]
    thin(s, [(x, lane_h(dd) + 0.03, -dd) for x, dd in outer + inner], (0, 1, 0), 0.02, color)


def cap(s, pts, x0, x1, lift, color, side="iron"):
    topped(s, [(z, y + lift) for z, y in pts], pts, x0, x1, color, side, "x")


def crown_pt(a):
    return (CROWN_R * math.sin(a), CROWN_CY + CROWN_R * math.cos(a))


BULB_ANGLES = [math.radians(a) for a in (-24, -18, -12, -6, 0, 6, 12, 18, 24)]


def bulbs():
    out = []
    for a in BULB_ANGLES:
        x, y = crown_pt(a)
        out.append((x, y + 0.05, ARCH_Z1 + 0.12))
    for sx in (-1, 1):
        out.append((sx * (CAB + 0.35), HEAD_Y0 + 0.3, ARCH_Z1 + 0.12))
    return out


def base(s):
    structure(s)
    side = lane_profile()
    for sx in (-1, 1):
        strip(s, 0.0, LANE_L - 0.6, sx * 2.45 - 0.07, sx * 2.45 + 0.07, 0.015, "bone")
    strip(s, 1.2, 1.8, -2.3, 2.3, 0.02, "mint")
    for k, d in enumerate((3.2, 7.2, 11.2, 15.2, 18.8)):
        chevron(s, d, "mint" if k % 2 == 0 else "mint_dk")
    for d in (6.0, 10.0, 14.0, 18.0):
        strip(s, d, d + 0.14, -2.3, 2.3, 0.012, "bone")
    y6, y7 = lane_h(LANE_L - 0.5), lane_h(LANE_L)
    topped(s, [(-(LANE_L - 0.5), y6 + 0.04), (-LANE_L, y7 + 0.04)], [(-(LANE_L - 0.5), y6), (-LANE_L, y7)],
           -LANE_HW, LANE_HW, "copper", "copper_dk", "x")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * LANE_HW, sx * (LANE_HW + RAIL_T)))
        cap(s, [(z, y + RAIL_H) for z, y in side], x0 - 0.08, x1 + 0.08, 0.1, "iron_hi")
    bw = [(Z_END, Y_END + 1.4), (Z0, Y0 + 1.4)]
    gz = [(z, y + 1.65) for z, y in GUT]
    for x0, x1 in ((-CAB - 0.05, -W + 0.05), (W - 0.05, CAB + 0.05)):
        cap(s, bw, x0, x1, 0.12, "copper", "copper_dk")
    cap(s, gz, W - 0.05, CAB + 0.05, 0.12, "copper", "copper_dk")
    cap(s, [(Z0, 3.05), (-LANE_L, 3.05)], -CAB - 0.05, -W + 0.05, 0.12, "copper", "copper_dk")
    s.box((2 * CAB + 0.2, 0.18, 0.8), (0, Y_END + 2.69, Z_END - 0.3), T["copper"])
    cup_decor(s)
    zc = (ARCH_Z0 + ARCH_Z1) / 2
    s.box((2 * (CAB + 0.7) + 0.2, 0.22, 0.2), (0, HEAD_Y1 + 0.11, ARCH_Z1 - 0.05), T["copper"])
    s.box((2 * (CAB + 0.7) + 0.2, 0.22, 0.2), (0, HEAD_Y0 - 0.11, ARCH_Z1 - 0.05), T["copper"])
    for x, w in ((-5.4, 1.2), (-3.3, 1.7), (-1.1, 1.7), (1.1, 1.7), (3.3, 1.7), (5.4, 1.2)):
        s.box((w + 0.3, 2.3, 0.06), (x, 13.0, ARCH_Z1 + 0.03), T["amber_dk"])
        s.box((w, 2.0, 0.06), (x, 13.0, ARCH_Z1 + 0.09), T["amber"])
    pts = [crown_pt(math.radians(a)) for a in range(-27, 28, 3)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        cp.obox(s, (math.hypot(x1 - x0, y1 - y0) + 0.06, 0.4, 1.0), ((x0 + x1) / 2, (y0 + y1) / 2, zc),
                T["copper"], roll=math.atan2(y1 - y0, x1 - x0))
    for sx in (-1, 1):
        s.box((1.0, 0.3, 1.8), (sx * (CAB + 0.35), HEAD_Y0 - 0.15, zc), T["copper"])
        s.box((0.9, 0.5, 1.6), (sx * (CAB + 0.35), 0.25, zc), T["copper_dk"])
    for x, y, z in bulbs():
        cp.lamp(s, x, y, z, 0.28)
    thin(s, [P(-W, 0.0, 0.03), P(W, 0.0, 0.03), P(W, 0.25, 0.03), P(-W, 0.25, 0.03)], (0, CT, ST), 0.05, "copper")


def detail1(s):
    side = lane_profile()
    zs = [-d for d in (1.0, 4.5, 8.0, 11.5, 15.0, 18.5, 21.5)]
    for sx in (-1, 1):
        for z in zs:
            y = lane_h(-z) + RAIL_H * 0.5 + 0.2
            cp.pk.hexstud(s, (sx * (LANE_HW + RAIL_T), y, z), (sx, 0, 0), 0.09, 0.07, T["copper_dk"])
            cp.pk.hexstud(s, (sx * LANE_HW, y, z), (-sx, 0, 0), 0.09, 0.06, T["copper_dk"])
    for f in (0.35, 0.7):
        for sx in (-1, 1):
            xo = sx * (LANE_HW + RAIL_T)
            x0, x1 = sorted((xo, xo + sx * 0.03))
            a, b = (0.0, lane_h(0.0)), (-20.0, lane_h(20.0))
            topped(s, [(a[0], a[1] * f + 0.03), (b[0], b[1] * f + 0.03)], [(a[0], a[1] * f - 0.03), (b[0], b[1] * f - 0.03)],
                   x0, x1, "timber", "timber", "x")
    for k in range(9):
        z = -22.0 + 3.0 * k + 0.0
        if z > 3.0:
            break
        s.box((2.4, 0.07, 0.22), (4.4, gut_y(z) + 0.035, z), T["iron"])
    for sx in (-1, 1):
        zc = (ARCH_Z0 + ARCH_Z1) / 2
        for y in (2.0, 5.5, 9.0):
            s.box((0.86, 0.22, 1.5), (sx * (CAB + 0.35), y, zc), T["copper_dk"])


def detail2(s):
    for k in range(12):
        x = -6.0 + 12.0 * k / 11
        cp.pk.hexstud(s, (x, HEAD_Y0 + 0.2, ARCH_Z1 - 0.05), (0, 0, 1), 0.07, 0.07, T["copper_dk"])
    for k in range(10):
        a = BULB_ANGLES[min(k, 8)]
        x, y = crown_pt(a + math.radians(3.0))
        cp.pk.hexstud(s, (x, y - 0.25, ARCH_Z1 + 0.0), (0, 0, 1), 0.06, 0.06, T["iron"])
    for sx in (-1, 1):
        for v in (1.5, 4.0, 6.5, 9.0, 11.5, 13.5):
            cp.pk.hexstud(s, P(sx * W, v, 0.8), (-sx, 0, 0), 0.09, 0.07, T["copper_dk"])
            cp.pk.hexstud(s, P(sx * CAB, v, 0.8), (sx, 0, 0), 0.09, 0.07, T["copper_dk"])
    for x in (-4.4, -2.2, 0.0, 2.2, 4.4):
        s.box((0.12, 2.3, 0.05), (x, 13.0, ARCH_Z1 + 0.14), T["iron"])


def sockets():
    out = {"start": (0.0, 1.0, 0.0), "score": (0.0, 13.0, FACE_Z + 0.1), "return_exit": (4.4, gut_y(RET_Z) + 1.0, RET_Z),
           "lip": (0.0, lane_h(LANE_L) + 1.0, -LANE_L),
           "interact": (0.0, 1.0, 1.5)}
    for cid, (u, v, r) in sorted(CUPS.items()):
        out[cid] = P(u, v, -DEPTH + 0.0)
    for i, p in enumerate(bulbs()):
        out["light_%02d" % i] = p
    return out


def check_base(s):
    for cid, (u, v, r) in sorted(CUPS.items()):
        inr = r * math.cos(math.pi / NSEG)
        assert inr >= 1.1 and 2 * inr >= 2.4, (cid, "opening too small for a 1.1 m sphere", inr)
        assert DEPTH >= 1.2 and abs(u) + r <= W - 0.3 and 0.2 <= v - r and v + r + 0.5 <= BL, (cid, "outside board")
    items = sorted(CUPS.items())
    for i, (a, (ua, va, ra)) in enumerate(items):
        for b, (ub, vb, rb) in items[i + 1:]:
            gap = math.hypot(ua - ub, va - vb) - ra - rb
            assert gap >= 0.6, (a, b, "cups too close", gap)
    assert 5.0 / 7.0 * G_GAME * FALL >= 1.5 * RR_GAME, "drain fall does not beat rolling resistance"
    for (z0, y0), (z1, y1) in zip(GUT, GUT[1:]):
        assert (y0 - y1) / (z1 - z0) >= FALL - 1e-9, ("gutter falls less than FALL", z0, z1)
    for (x0, y0), (x1, y1) in zip(TROUGH, TROUGH[1:]):
        assert (y0 - y1) / (x1 - x0) >= FALL - 1e-9, ("trough falls less than FALL", x0, x1)
    assert GUT[0][0] == Z0 and abs(GUT[0][1] - TROUGH[-1][1]) < 1e-9 and 0.0 < RET_Z < GUT_END, "gutter head or return_exit"
    assert TROUGH[0][1] <= Y0 and lane_h(LANE_L) - TROUGH[0][1] >= 1.0, "trough under the board's foot and the hump's lip"
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 0.01 and 15.5 < hi[1] < 16.6, ("height", lo, hi)
    assert 2 * LANE_HW == 5.5 and abs(lane_h(LANE_L) - lane_h(LANE_L - HUMP_L) - HUMP_H) < 1e-6
    assert lo[2] > -39.5 and hi[2] <= 4.0, ("length", lo, hi)


def main():
    args = cp.options()
    base_s = cp.surface("camp_skee_lane", base)
    for name, fn in (("camp_skee_lane_detail1", detail1), ("camp_skee_lane_detail2", detail2)):
        cp.inside(cp.surface(name, fn), base_s)
    cp.export("camp_skee_lane", base, "park_large", args, col=lambda s: structure(s, col=True), sockets=sockets(),
              check=check_base)
    cp.export("camp_skee_lane_detail1", detail1, "detail", args)
    cp.export("camp_skee_lane_detail2", detail2, "detail", args)


if __name__ == "__main__":
    main()
