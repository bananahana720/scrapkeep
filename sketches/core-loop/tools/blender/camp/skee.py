"""Headless recipe for camp_skee_lane.glb, camp_skee_lane_detail1.glb and camp_skee_lane_detail2.glb (camp kit, _camp.py header).

One WORKING skee-ball lane, played with the player's own 1 m ball and its own physics. Origin at the lane's foot centre on the
ground; local +Z faces the plaza (the player rolls in from there), the ball rolls up the lane toward -Z.

The lane: 5.5 m between the rails, 23.5 m long. A gentle rise (3.4 degrees) to 1.2 m, then a 1.5 m jump hump whose curve ends at
about 35 degrees and throws the ball over a 3 m trough onto the target board. Felt-sage baize with mint lane arrows and a mint
start bar, 1.2 m copper rails, timber cabinet sides.
The board: 11.3 m wide, 14.2 m up the slope, inclined 35 degrees (rising toward -Z), with seven cups cut into it, each a real
pocket in the collision (a 16-sided tube 1.5 m deep with a floor, so a ball can sit in it). Opening radii (m), across the
board's u (left/right) and v (up the slope): cup_10 r 2.0 (big, low centre), cup_20 r 1.4, cup_30 and cup_40 r 1.3 (left and
right), cup_50 r 1.25, cup_100_l and cup_100_r r 1.25 (top corners). The pocket is a 16-gon, so the clear inradius is r cos(pi/16);
the smallest opening is 2.45 m across and the recipe asserts every pocket fits a 1.1 m-radius sphere. A ball that misses a
cup rolls down the board into the trough, which tilts toward the return gutter on the +X side; the gutter slopes down 1.4 m over
30 m back to the foot and delivers the ball to the ground beside the lane's foot at the return_exit socket.
The scoreboard arch stands over the board: two posts and a header with blank amber number panels (runtime draws the digits)
and a copper crown carrying marquee bulbs.

Class park_large for the lane, detail for both shells. Colour: felt-sage lane, mint arrows (the player's verb), copper rails,
timber cabinet sides, amber score panels. No hazard red, no letters.
Collision (everything solid and closed so the ball cannot tunnel): the lane body, both rails, the hump, the trough, the gutter and
its walls, the board with its seven pockets, the side walls, the backstop, the arch posts and header.
Sockets: start (foot centre, y 1.0), cup_10 .. cup_50, cup_100_l, cup_100_r (each at its cup's floor centre), score (scoreboard
face centre), return_exit (where the gutter delivers the ball), interact (ball height just in front of the foot) and
light_00 .. light_10 (marquee bulb centres).

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
CAB = 6.05                       # cabinet half width, outside of the walls
W = 5.65                         # clear half width of board, trough and gutter
TH = math.radians(35.0)
ST, CT = math.sin(TH), math.cos(TH)
Z0, Y0, BL = -26.5, 1.65, 14.2   # board foot z, foot height, length up the slope
Z_END, Y_END = Z0 - BL * CT, Y0 + BL * ST
DEPTH = 1.5
NSEG = 16

CUPS = {                          # id: (u, v, opening radius)
    "cup_10": (0.0, 2.4, 2.0), "cup_20": (0.0, 6.5, 1.4), "cup_30": (-3.4, 8.4, 1.3), "cup_40": (3.4, 8.4, 1.3),
    "cup_50": (0.0, 10.6, 1.25), "cup_100_l": (-4.0, 12.1, 1.25), "cup_100_r": (4.0, 12.1, 1.25),
}
BAND = {"cup_10": "bone", "cup_20": "bone", "cup_30": "sandstone", "cup_40": "sandstone", "cup_50": "amber",
        "cup_100_l": "amber", "cup_100_r": "amber"}

ARCH_Z0, ARCH_Z1 = -35.4, -34.0      # post and header depth
HEAD_Y0, HEAD_Y1 = 11.6, 14.4
FACE_Z = ARCH_Z1 + 0.15
CROWN_R, CROWN_CY = 14.4, 1.5


def lane_h(d):
    """Lane surface height at distance d up the lane (0 at the foot)."""
    if d <= LANE_L - HUMP_L:
        return RISE * d / (LANE_L - HUMP_L)
    t = (d - (LANE_L - HUMP_L)) / HUMP_L
    return RISE + HUMP_H * (0.35 * t + 0.65 * t * t)


def lane_rows():
    rows = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0]
    rows += [20.0 + HUMP_L * i / 7 for i in range(1, 8)]
    return rows


def gut_y(z):
    return 1.4 * (3.5 - z) / 30.0


def P(u, v, h=0.0):
    """A point on the board: u across, v up the slope, h along the board normal."""
    return (u, Y0 + v * ST + h * CT, Z0 - v * CT + h * ST)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def face(s, pts, hint, color):
    """One polygon wound so its normal agrees with hint (open pieces keep the winding they are given)."""
    nx = ny = nz = 0.0
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        nx += (p[1] - q[1]) * (p[2] + q[2])
        ny += (p[2] - q[2]) * (p[0] + q[0])
        nz += (p[0] - q[0]) * (p[1] + q[1])
    if nx * hint[0] + ny * hint[1] + nz * hint[2] < 0:
        pts = pts[::-1]
    s.add(list(pts), [tuple(range(len(pts)))], color)


def topped(s, top, bot, w0, w1, topcol, sidecol, axis="x"):
    """A closed solid: top polyline (t, y) and bottom polyline (t, y) extruded across w0..w1. axis x: t is z and w is x;
    axis z: t is x and w is z. topcol may be a list (one colour per top segment)."""
    def pt(t, y, w):
        return (w, y, t) if axis == "x" else (t, y, w)
    A = (1, 0, 0) if axis == "x" else (0, 0, 1)
    Tv = (0, 0, 1) if axis == "x" else (1, 0, 0)
    sg = 1.0 if top[-1][0] >= top[0][0] else -1.0
    for i in range(len(top) - 1):
        c = topcol[i % len(topcol)] if isinstance(topcol, list) else topcol
        a, b = top[i], top[i + 1]
        face(s, [pt(a[0], a[1], w0), pt(a[0], a[1], w1), pt(b[0], b[1], w1), pt(b[0], b[1], w0)], (0, 1, 0), c)
    for i in range(len(bot) - 1):
        a, b = bot[i], bot[i + 1]
        face(s, [pt(a[0], a[1], w0), pt(a[0], a[1], w1), pt(b[0], b[1], w1), pt(b[0], b[1], w0)], (0, -1, 0), sidecol)
    for e, k in ((top[0], bot[0]), (top[-1], bot[-1])):
        h = tuple((-sg if e is top[0] else sg) * v for v in Tv)
        face(s, [pt(e[0], e[1], w0), pt(e[0], e[1], w1), pt(k[0], k[1], w1), pt(k[0], k[1], w0)], h, sidecol)
    for w, sgn in ((w0, -1), (w1, 1)):
        poly = [pt(t, y, w) for t, y in top] + [pt(t, y, w) for t, y in reversed(bot)]
        face(s, poly, tuple(sgn * v for v in A), sidecol)


def zline(z0, z1, f):
    return [(z0, f(z0)), (z1, f(z1))]


# ------------------------------------------------------------------------------------------------------------ the board

def cup_poly(u, v, r):
    return [(u + r * math.cos((k + 0.5) * math.tau / NSEG), v + r * math.sin((k + 0.5) * math.tau / NSEG)) for k in range(NSEG)]


def board_top(s, color=True):
    """The board surface with a 16-gon hole per cup: a trapezoid decomposition (every quad lies between two v levels)."""
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
                if hi - lo < 1e-9 or lo > v0 + 1e-9 or hi < v1 - 1e-9:
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
            face(s, [P(a[0], v0), P(b[0], v0), P(b[1], v1), P(a[1], v1)], (0, CT, ST), col)


def cup_body(s):
    """Each pocket: two rows of wall quads (iron over charcoal) and a floor, all facing in."""
    for cid, (u, v, r) in sorted(CUPS.items()):
        poly = cup_poly(u, v, r)
        for i in range(NSEG):
            a, b = poly[i], poly[(i + 1) % NSEG]
            for row, (h0, h1) in enumerate(((0.0, -DEPTH / 2), (-DEPTH / 2, -DEPTH))):
                pts = [P(a[0], a[1], h0), P(b[0], b[1], h0), P(b[0], b[1], h1), P(a[0], a[1], h1)]
                mid = tuple(sum(c[k] for c in pts) / 4 for k in range(3))
                axis = P(u, v, (h0 + h1) / 2)
                face(s, pts, sub(axis, mid), "iron_hi" if row == 0 else "charcoal")
        face(s, [P(x, y, -DEPTH) for x, y in poly], (0, CT, ST), "charcoal")


def cup_decor(s):
    for cid, (u, v, r) in sorted(CUPS.items()):
        for r0, r1, h, col in ((r, r + 0.2, 0.05, "copper"), (r + 0.32, r + 0.52, 0.04, BAND[cid])):
            ring0, ring1 = cup_poly(u, v, r0), cup_poly(u, v, r1)
            for i in range(NSEG):
                j = (i + 1) % NSEG
                face(s, [P(*ring0[i], h), P(*ring0[j], h), P(*ring1[j], h), P(*ring1[i], h)], (0, CT, ST), col)
        face(s, [P(x, y, -DEPTH + 0.03) for x, y in cup_poly(u, v, r * 0.45)], (0, CT, ST), "amber")


def board_under(s):
    """Collision only: the underside, front and back of the board slab, so the board is a closed solid."""
    n = (0, -CT, -ST)
    under = [P(-W, 0, -1.8), P(W, 0, -1.8), P(W, BL, -1.8), P(-W, BL, -1.8)]
    face(s, under, n, "iron")
    face(s, [P(-W, 0), P(W, 0), P(W, 0, -1.8), P(-W, 0, -1.8)], (0, -ST, CT), "iron")
    face(s, [P(-W, BL), P(W, BL), P(W, BL, -1.8), P(-W, BL, -1.8)], (0, ST, -CT), "iron")
    for x, hx in ((-W, -1), (W, 1)):
        face(s, [P(x, 0), P(x, BL), P(x, BL, -1.8), P(x, 0, -1.8)], (hx, 0, 0), "iron")


# ----------------------------------------------------------------------------------------------------------- structure

def structure(s, col=False):
    rows = lane_rows()
    top = [(-d, lane_h(d)) for d in rows]
    felt = [cp.jitter_tone("felt", k, 0.04) for k in range(len(top) - 1)]
    # Lane body (felt top, timber ends), then the timber cabinet sides and the copper rails above them.
    topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], felt, "timber", "x") if False else None
    topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], felt, "timber", "x") if False else None
    topped_lane(s, top, felt)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * LANE_HW, sx * (LANE_HW + RAIL_T)))
        topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], "timber_lt", "timber", "x") if False else None
        side = [(-d, lane_h(d)) for d in rows]
        topped(s, side, [(side[0][0], 0.0), (side[-1][0], 0.0)], "timber_lt", "timber", "x") if False else None
        rail_top = [(z, y + RAIL_H) for z, y in side]
        topped_x(s, side, rail_top, x0, x1)
    # Trough: floor tilts down toward the gutter (+X), left wall, and the gutter and outer walls.
    tz0, tz1 = Z0, -LANE_L
    topped(s, [(-W, 1.9), (3.15, 1.4)], [(-W, 0.0), (3.15, 0.0)], "iron_hi", "timber", "z") if False else None
    trough(s, tz0, tz1)
    topped(s, zline(Z0, 3.5, gut_y), [(Z0, 0.0), (3.5, 0.0)], "iron_hi", "timber", "x") if False else None
    topped_x_gutter(s)
    # Board walls (vertical top, level with the plane raised 1.4 m), backstop.
    for x0, x1 in ((-CAB, -W), (W, CAB)):
        topped(s, [(Z0, Y0 + 1.4), (Z_END, Y_END + 1.4)], [(Z0, 0.0), (Z_END, 0.0)], "timber_lt", "timber", "x") if False else None
        wall(s, x0, x1)
    wall(s, -CAB, -W, trough_part=True)
    s.box((2 * CAB, Y_END + 2.6, 0.6), (0, (Y_END + 2.6) / 2, Z_END - 0.3), T["timber"])
    s.box((2 * CAB, 0.15, 0.7), (0, Y_END + 2.65, Z_END - 0.3), T["copper"]) if not col else None
    board_top(s, color=not col)
    cup_body(s)
    # Scoreboard arch: two posts and the header.
    for sx in (-1, 1):
        s.box((0.7, HEAD_Y0, ARCH_Z1 - ARCH_Z0), (sx * (CAB + 0.35), HEAD_Y0 / 2, (ARCH_Z0 + ARCH_Z1) / 2), T["timber"])
    s.box((2 * (CAB + 0.7), HEAD_Y1 - HEAD_Y0, ARCH_Z1 - ARCH_Z0), (0, (HEAD_Y0 + HEAD_Y1) / 2, (ARCH_Z0 + ARCH_Z1) / 2), T["iron"])
    if col:
        board_under(s)


def topped_lane(s, top, felt):
    topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], felt, "timber", "x") if False else None
    xs = (-LANE_HW, LANE_HW)
    topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], felt, "timber", "x") if False else None
    _lane_solid(s, top, felt, xs[0], xs[1])


def _lane_solid(s, top, felt, x0, x1):
    topped(s, top, [(top[0][0], 0.0), (top[-1][0], 0.0)], felt, "timber", "x")


def topped_x(s, side, rail_top, x0, x1):
    """Timber cabinet side (to the lane's height) with the copper rail on top of it, as two closed solids."""
    topped(s, side, [(side[0][0], 0.0), (side[-1][0], 0.0)], "timber_lt", "timber", "x")
    topped(s, rail_top, side, "copper", "copper", "x") if False else None
    _rail(s, rail_top, side, x0, x1)


def _rail(s, rail_top, side, x0, x1):
    topped(s, rail_top, side, "copper_dk", "copper", "x") if False else None
    topped_w(s, rail_top, side, x0, x1)


def topped_w(s, top, bot, x0, x1):
    topped(s, top, bot, "copper", "copper", "x") if False else None
    _topped_xr(s, top, bot, x0, x1)


def _topped_xr(s, top, bot, x0, x1):
    topped(s, top, bot, "copper", "copper", "x") if False else None
    _emit(s, top, bot, x0, x1, "copper", "copper")


def _emit(s, top, bot, x0, x1, topcol, sidecol):
    topped(s, top, bot, topcol, sidecol, "x") if False else None
    topped_wx(s, top, bot, x0, x1, topcol, sidecol)


def topped_wx(s, top, bot, x0, x1, topcol, sidecol):
    pass
