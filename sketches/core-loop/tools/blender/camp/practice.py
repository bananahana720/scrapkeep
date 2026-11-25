"""Headless recipe for the camp's practice yard: camp_trial_track.glb, camp_trial_arch.glb, camp_sandbox_yard.glb and
camp_call_box.glb (camp kit, _camp.py header). Conventions as in the kit: metres at game scale, Godot +Y up, origin on the
ground at the footprint centre unless a piece says otherwise, one enamel draw with vertex colour per GLB.

camp_trial_track (park_large): the saved-ghost time trial. A closed 9 m wide concrete loop, 42 m wide by 70 m long (inside
the 76 x 50 m footprint), its long axis along Z: two 28 m straights at x = -16 and x = +16 joined by two 16 m radius turns.
The race runs clockwise seen from above: the start straight (x = -16) heads -Z, the far straight (x = +16) heads +Z. Both
turns are banked half-pipes: the outer 7 m of the deck curves up to a 4 m wall (about 51 degrees at the lip), the angle a ball
at cruise needs, so a ball can carve high and keep its speed. Straight 1 (start) carries two rollers with a dip between
them; straight 2 carries the kicker: an 8 m run-up to a 2 m crest and a 12 m landing slope. The deck is a 0.08 m slab,
chamfered at its edges (0.5 m), with dark form-board joints every 8 m, amber lane-edge stripes and a mint start/finish line
at z = 8. A chamfered apron, ground to deck, runs in from the camp side (-X) to the start straight with a mint threshold bar.
Origin at the track's centre on the ground. Collision: the same swept solid, coarser (flat tops, banks, walls, kicker, rollers).
Sockets: start, finish (on the start line, y 1.0; the race heads -Z), arch (start-line centre on the deck, where
camp_trial_arch's origin goes), checkpoint_0..3 (every quarter of the lap on the deck centre line, the last on the start
line; deck height + 1.0), ghost_00..ghost_31 (race order from the start line, evenly spaced by lap length along the racing
line, which carves 1.8 m high in the turns; deck height + 1.0, the ball's riding height).

camp_trial_arch (gate): the start/finish arch. Origin on the ground at the centre of the start line; the ball passes along
+-Z. Two concrete posts, 10.8 m clear span, 7.2 m clear height, an iron header carrying a blank amber timer panel on the
+Z face (the runtime draws the digits), a scalloped mint start banner hanging from the header, and three medal lamps on top in
little cages (bronze = copper bulb, silver = bone, gold = amber). Collision: the posts. Sockets: timer, light_bronze,
light_silver, light_gold.

camp_sandbox_yard (park_large, like the plaza and trial track: a 44 m walk-on yard with a floor, so it takes the large budget
rather than detail, and the class cap covers its collision mesh too): the any-enemy sandbox: a fenced round yard (21.5 m fence radius) with an 8 m entry gap facing +Z,
a raked sand floor slab, iron rails on copper posts, a concrete block and a tyre stack for hard cover, and on the far side a
6 m round iron spawn grate with a brass Fleet requisition chevron. Origin at the yard centre on the ground; +Z is the entry.
Collision: fence posts, rails and the two cover pieces. Sockets: entry, spawn_pad, enemy_spawn_0..3, call_box.

camp_call_box (detail): the enemy picker: a Fleet requisition dispatch box on a post with a rotary selector dial, a big pull
lever, a paper-ticket slot, a beacon lamp and a copper pneumatic tube running down into the ground behind it, toward the
grate. Origin on the ground under the post, the front faces +Z. Collision: post and box. Sockets: interact, dial, lever, light_0.

Copper is the palette copper, never brass; the brass is the Fleet requisition tag. Mint only marks what the player uses.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/practice.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def qface(s, pts, color, want):
    """One planar polygon whose normal faces `want`; degenerate polygons are skipped."""
    n = (0.0, 0.0, 0.0)
    for k in range(1, len(pts) - 1):
        c = _cross(_sub(pts[k], pts[0]), _sub(pts[k + 1], pts[0]))
        n = (n[0] + c[0], n[1] + c[1], n[2] + c[2])
    if _dot(n, n) < 1e-12:
        return
    if _dot(n, want) < 0:
        pts = pts[::-1]
    s.add(list(pts), [tuple(range(len(pts)))], color)


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


R = 16.0
STR = 28.0
TZ = 14.0
XS = 16.0
TURN = math.pi * R
LOOP = 2 * STR + 2 * TURN
HALF = 4.5
SLAB = 0.08
BANK_H = 4.0
BANK_U0 = -2.5
START_S = 6.0
RAMP_IN = 10.0
KICK_AT = STR + TURN
CARVE = 1.8
U_TOP = [-4.5, -4.15, -3.9, -2.5, -2.4, -1.5, -0.5, 0.5, 1.5, 2.5, 3.3, 3.9, 4.15, 4.5]
U_COL = [-4.5, -2.5, -0.5, 1.5, 3.3, 4.5]


def pos(s):
    """(x, z, tx, tz) on the loop centre line at path length s (clockwise from above, start straight heading -Z)."""
    s = s % LOOP
    if s < STR:
        return (-XS, TZ - s, 0.0, -1.0)
    s -= STR
    if s < TURN:
        p = s / R
        return (-R * math.cos(p), -TZ - R * math.sin(p), math.sin(p), -math.cos(p))
    s -= TURN
    if s < STR:
        return (XS, -TZ + s, 0.0, 1.0)
    s -= STR
    p = s / R
    return (R * math.cos(p), TZ + R * math.sin(p), -math.sin(p), math.cos(p))


def bank(s):
    """0 on the straights, 1 deep in a turn, blended over RAMP_IN metres across each turn's ends."""
    out = 0.0
    for a in (STR, 2 * STR + TURN):
        for sh in (-LOOP, 0.0, LOOP):
            d = s + sh - a
            out = max(out, smooth((d + 2.0) / RAMP_IN) * smooth((TURN - d + 2.0) / RAMP_IN))
    return out


def hump(s):
    """Rollers on the start straight, the kicker and its landing slope on the far straight."""
    s = s % LOOP
    y = 0.0
    if 10.0 <= s <= 26.0:
        x = s - 10.0
        y += (0.9 if x < 8.0 else 1.1) * math.sin(math.pi * x / 8.0) ** 2
    d = s - KICK_AT
    if 4.0 <= d <= 12.0:
        y += 2.0 * ((d - 4.0) / 8.0) ** 2
    elif 12.0 < d <= 24.0:
        y += 2.0 * (1.0 - (d - 12.0) / 12.0) ** 1.5
    return y


def bank_h(u):
    x = (u - BANK_U0) / (HALF - BANK_U0)
    return BANK_H * x ** 2.2 if x > 0 else 0.0


def deck_y(s, u, b=None):
    b = bank(s) if b is None else b
    return SLAB + hump(s) + b * bank_h(u)


def profile(s, us):
    """The closed cross-section at s as (u, y) points: inner foot, top at each u in us, wall foot-to-trim, wall cap, back, outer foot.
    On the straights (no bank) the wall points coincide with the last deck point; the sweep welds them."""
    b = bank(s)
    pts = [(-HALF - 0.5, 0.0)]
    pts += [(u, deck_y(s, u, b)) for u in us]
    ye = deck_y(s, HALF, b) + 0.75 * b
    pts += [(HALF, ye - 0.3 * b), (HALF, ye), (HALF + 0.6 * b, ye), (HALF + 0.6 * b, ye - 0.2 * b), (HALF + 0.6, 0.0)]
    return pts


def frame(s):
    x, z, tx, tz = pos(s)
    return x, z, tz, -tx


def ring(s, us):
    x, z, nx, nz = frame(s)
    return [(x + nx * u, y, z + nz * u) for u, y in profile(s, us)], (nx, nz)


def sample_s(step, dense):
    vals = {round(k * step, 4) for k in range(int(LOOP / step) + 1)}
    for a, b, st in dense:
        k = 0
        while a + k * st <= b + 1e-9:
            vals.add(round(a + k * st, 4))
            k += 1
    return vals


JOINTS = [4.0 + 8.0 * k for k in range(int(LOOP // 8.0) + 1) if abs(4.0 + 8.0 * k - START_S) > 1.5 and 4.0 + 8.0 * k < LOOP]


def track_s(drawn):
    vals = sample_s(1.0, [(KICK_AT + 2.0, KICK_AT + 26.0, 0.5), (8.0, 28.0, 0.5)] if drawn else [])
    if drawn:
        vals |= {round(START_S + d, 4) for d in (-0.7, -0.5, 0.5, 0.7)}
        for j in JOINTS:
            vals |= {round(j + d, 4) for d in (-0.25, -0.06, 0.06, 0.25)}
    return sorted(v for v in vals if 0.0 <= v < LOOP - 1e-3)


def ring_kind(sv):
    if abs(sv - START_S) <= 0.5 + 1e-6:
        return "line"
    if any(abs(sv - j) <= 0.06 + 1e-6 for j in JOINTS):
        return "joint"
    return "plain"


AMBER_U = {-3.9, -2.5, 4.15, 4.5}


def point_colour(sv, kind, j, us):
    nu = len(us)
    slab = int(sv // 8)
    if j == 0 or j >= nu + 4:
        return "concrete_dk"
    if j <= nu:
        u = us[j - 1]
        if j == 1:
            return cp.jitter_tone("concrete", slab, 0.07)
        if kind == "line":
            return "mint"
        if u in AMBER_U:
            return "amber"
        if kind == "joint":
            return "concrete_dk"
        return cp.jitter_tone("concrete", slab, 0.07)
    if j == nu + 1:
        return cp.jitter_tone("concrete_lt", slab, 0.05)
    return "copper"


def sweep(s, svals, us, drawn):
    """The track as ONE closed welded solid: rings of the closed cross-section, coincident points merged, the last ring
    joined to the first. Colour is per vertex, so the stripes, joints and start line are soft-edged ring colours."""
    verts, colors, rings = [], [], []
    for sv in svals:
        prof = ring(sv, us)[0]
        kind = ring_kind(sv) if drawn else "plain"
        idx, seen = [], {}
        for j, pt in enumerate(prof):
            key = tuple(round(c, 5) for c in pt)
            if key not in seen:
                seen[key] = len(verts)
                verts.append(pt)
                colors.append(point_colour(sv, kind, j, us) if drawn else "iron")
            idx.append(seen[key])
        rings.append(idx)
    faces = []
    n = len(rings[0])
    for i in range(len(rings)):
        ra, rb = rings[i], rings[(i + 1) % len(rings)]
        for j in range(n):
            k = (j + 1) % n
            quad = [ra[j], ra[k], rb[k], rb[j]]
            quad = [q for m, q in enumerate(quad) if q != quad[m - 1]]
            if len(set(quad)) >= 3:
                faces.append(tuple(quad))
    s.add(verts, faces, colors=colors)


def track_apron(s):
    """The roll-on apron: ground to deck over 6.5 m at the start straight's camp side, chamfered at its edges. One closed
    welded solid (top grid, flat underside, side walls where the edge stands above the ground)."""
    z0 = TZ - START_S
    xs = [(-34.5, 0.0), (-28.0, 1.0), (-20.5, 1.0)]
    zs = [(z0 - 5.0, 0.0), (z0 - 4.5, 1.0), (z0 + 4.5, 1.0), (z0 + 5.0, 0.0)]
    verts, cols, top, bot = [], [], {}, {}
    for i in range(3):
        for j in range(4):
            h = SLAB * xs[i][1] * zs[j][1]
            top[i, j] = len(verts)
            verts.append((xs[i][0], h, zs[j][0]))
            cols.append("concrete_dk" if j != 1 and j != 2 else cp.jitter_tone("concrete", 20 + min(i, 1), 0.07))
            if h > 0:
                bot[i, j] = len(verts)
                verts.append((xs[i][0], 0.0, zs[j][0]))
                cols.append("concrete_dk")
            else:
                bot[i, j] = top[i, j]
    faces = []

    def add(q):
        q = [v for m, v in enumerate(q) if v != q[m - 1]]
        if len(set(q)) >= 3:
            faces.append(tuple(q))

    for i in range(2):
        for j in range(3):
            add([top[i, j], top[i, j + 1], top[i + 1, j + 1], top[i + 1, j]])
            add([bot[i, j], bot[i + 1, j], bot[i + 1, j + 1], bot[i, j + 1]])
    for i in range(2):
        for j in (0, 3):
            add([top[i, j], top[i + 1, j], bot[i + 1, j], bot[i, j]])
    for j in range(3):
        for i in (0, 2):
            add([top[i, j], bot[i, j], bot[i, j + 1], top[i, j + 1]])
    s.add(verts, faces, colors=cols)
    cp.obox(s, (0.7, 0.03, 8.4), (-27.6, SLAB + 0.015, z0), T["mint"])
    for x in (-25.0, -23.2):
        for sz in (-1, 1):
            cp.obox(s, (0.35, 0.02, 1.8), (x - 0.4, SLAB + 0.01, z0 + sz * 0.9), T["amber"], yaw=-sz * math.radians(55))


def track_details(s):
    for a in (STR, 2 * STR + TURN):
        d = 8.0
        while d <= TURN - 7.0:
            sv = a + d
            x, z, nx, nz = frame(sv)
            b = bank(sv)
            ye = deck_y(sv, HALF, b) + 0.75 * b
            cp.pk.hexstud(s, (x + nx * (HALF + 0.3), ye, z + nz * (HALF + 0.3)), (0, 1, 0), 0.16, 0.07, T["copper_dk"])
            yaw = math.atan2(nx, nz)
            cp.obox(s, (0.9, ye - 0.2, 1.0), (x + nx * (HALF + 0.6 + 0.5), (ye - 0.2) / 2, z + nz * (HALF + 0.6 + 0.5)),
                    cp.jitter_tone("concrete_dk", int(sv), 0.08), yaw=yaw)
            d += 6.0
    track_apron(s)


def track(s):
    sweep(s, track_s(True), U_TOP, True)
    track_details(s)


def track_col(s):
    sweep(s, track_s(False), U_COL, False)
    z0 = TZ - START_S
    xa = [(-34.5, 0.0), (-28.0, SLAB), (-20.5, SLAB)]
    pts = [(x, h, z) for x, h in xa for z in (z0 - 4.5, z0 + 4.5)] + [(x, 0.0, z) for x, h in xa for z in (z0 - 4.5, z0 + 4.5)]
    s.add(pts, [(0, 2, 3, 1), (2, 4, 5, 3), (6, 7, 9, 8), (8, 9, 11, 10), (0, 2, 8, 6), (2, 4, 10, 8),
                (1, 3, 9, 7), (3, 5, 11, 9), (4, 5, 11, 10)], "iron")


GHOSTS = 32


def racing_line(sv):
    x, z, nx, nz = frame(sv)
    b = bank(sv)
    u = CARVE * b
    return (x + nx * u, deck_y(sv, u, b) + 1.0, z + nz * u)


def centre_point(sv):
    x, z, nx, nz = frame(sv)
    return (x, deck_y(sv, 0.0) + 1.0, z)


def track_sockets():
    x, z, _, _ = pos(START_S)
    out = {"start": (x, 1.0, z), "finish": (x, 1.0, z), "arch": (x, SLAB, z)}
    for k in range(4):
        out["checkpoint_%d" % k] = centre_point(START_S + LOOP * (k + 1) / 4)
    for k in range(GHOSTS):
        out["ghost_%02d" % k] = racing_line(START_S + LOOP * k / GHOSTS)
    return out


def check_track(s):
    x0, z0, _, _ = pos(0.0)
    x1, z1, _, _ = pos(LOOP - 1e-6)
    assert math.hypot(x0 - x1, z0 - z1) < 1e-3, "the loop does not close"
    assert abs(deck_y(0.0, 3.0) - deck_y(LOOP, 3.0)) < 1e-6, "deck height does not close"
    prev = None
    for k in range(int(LOOP * 4) + 1):
        sv = k / 4.0
        for u in (0.0, 4.5):
            p = (frame(sv)[0] + frame(sv)[2] * u, deck_y(sv, u), frame(sv)[1] + frame(sv)[3] * u)
            if u == 0.0:
                cur = p
        if prev is not None:
            assert abs(cur[1] - prev[1]) < 0.35 and math.hypot(cur[0] - prev[0], cur[2] - prev[2]) < 0.3, ("deck gap", sv)
        prev = cur
    gaps = []
    pts = [racing_line(START_S + LOOP * k / GHOSTS) for k in range(GHOSTS)]
    for k in range(GHOSTS):
        a, b = pts[k], pts[(k + 1) % GHOSTS]
        gaps.append(math.dist(a, b))
    assert max(gaps) < 1.35 * min(gaps) and gaps[-1] < 1.35 * min(gaps), ("ghost spacing does not close evenly", gaps)
    lo, hi = cp.bounds(s)
    assert max(abs(lo[0]), abs(hi[0])) <= 38.0 and max(abs(lo[2]), abs(hi[2])) <= 38.0, ("footprint", lo, hi)
    assert hi[0] - lo[0] <= 76.0 and hi[2] - lo[2] <= 76.0
    assert 4.5 <= hi[1] <= 5.4, ("wall height", hi[1])


POST_X = 5.9
CLEAR_Y = 7.2


def arch(s):
    for sx in (-1, 1):
        x = sx * POST_X
        s.box((1.6, 0.5, 1.6), (x, 0.25, 0), T["concrete_lt"])
        s.box((1.64, 0.06, 1.64), (x, 0.5, 0), T["concrete_dk"])
        pk.frustum(s, 0.58, 0.46, 0.5, 7.6, 8, cp.jitter_tone("concrete", 2 + sx, 0.04), caps=(False, False), at=(x, 0))
        for y in (2.0, 3.6, 5.2):
            pk.frustum(s, 0.55 - (y - 0.5) * 0.017 + 0.03, 0.55 - (y - 0.5) * 0.017 + 0.03, y, y + 0.1, 8, T["concrete_dk"], at=(x, 0))
        pk.frustum(s, 0.64, 0.64, 0.6, 1.0, 8, T["copper"], at=(x, 0))
        pk.frustum(s, 0.52, 0.52, 6.8, 7.2, 8, T["copper"], at=(x, 0))
        s.box((1.4, 0.35, 1.4), (x, 7.775, 0), T["iron_hi"])
        pk.strut(s, (x - sx * 0.45, 7.1, 0), (x - sx * 1.5, 7.8, 0), 0.25, 0.5, T["iron"])
    s.box((13.2, 1.4, 1.0), (0, 8.5, 0), T["iron"])
    for y in (7.82, 9.18):
        s.box((13.4, 0.12, 1.14), (0, y, 0), T["copper_dk"])
    for k in range(10):
        x = -5.4 + k * 1.2
        if abs(x) < 2.6:
            continue
        for sz in (-1, 1):
            pk.hexstud(s, (x, 8.5, sz * 0.5), (0, 0, sz), 0.09, 0.05, T["copper_dk"])
    s.box((4.8, 1.1, 0.14), (0, 8.5, 0.55), T["copper"])
    s.box((4.4, 0.78, 0.08), (0, 8.5, 0.62), T["amber"])
    s.box((4.5, 0.06, 0.05), (0, 8.92, 0.6), T["copper_dk"])
    teeth = 14
    w = 12.6 / teeth
    for sz in (-1, 1):
        z = sz * 0.54
        s.box((12.6, 0.28, 0.05), (0, 7.66, z), T["mint"])
        for k in range(teeth):
            x0 = -6.3 + k * w
            col = T["mint"] if k % 2 == 0 else T["mint_dk"]
            pts = [(x0, 7.52, z - 0.025), (x0 + w, 7.52, z - 0.025), (x0 + w / 2, 7.2, z - 0.025),
                   (x0, 7.52, z + 0.025), (x0 + w, 7.52, z + 0.025), (x0 + w / 2, 7.2, z + 0.025)]
            s.add(pts, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], col)
    for x, bulb in ((-2.6, "copper"), (0.0, "bone"), (2.6, "amber")):
        pk.frustum(s, 0.55, 0.5, 9.24, 9.42, 8, T["copper_dk"], at=(x, 0))
        cp.lamp(s, x, 9.9, 0, 0.3, bulb)
        for a in cp.around(4, math.pi / 4):
            bx, bz = 0.42 * math.cos(a), 0.42 * math.sin(a)
            pk.strut(s, (x + bx, 9.42, bz), (x + bx * 0.5, 10.5, bz * 0.5), 0.06, 0.06, T["iron_hi"])
        pk.frustum(s, 0.26, 0.1, 10.5, 10.68, 8, T["copper_dk"], at=(x, 0))


def arch_col(s):
    for sx in (-1, 1):
        s.box((1.6, 7.9, 1.6), (sx * POST_X, 3.95, 0), T["iron"])


def arch_sockets():
    return {"timer": (0.0, 8.5, 0.66), "light_bronze": (-2.6, 9.9, 0.0), "light_silver": (0.0, 9.9, 0.0),
            "light_gold": (2.6, 9.9, 0.0)}


def check_arch(s):
    lo, hi = cp.bounds(s)
    assert 2 * (POST_X - 0.8) >= 10.0, "clear span"
    below = [v[1] for v in s.verts if abs(v[0]) < POST_X - 0.9 and v[1] < CLEAR_Y - 1e-6]
    assert not below, ("the arch dips under the clear height", min(below))
    assert hi[1] >= 10.0 and lo[1] >= 0.0


FENCE_R = 21.5
FENCE_N = 20
GAP = 4.0 / FENCE_R
FLOOR_R = 22.0
SAND = 0.12
GRATE_AT = (0.0, -15.0)
BLOCK_AT = (-8.5, -4.0)
BLOCK_YAW = 0.4
TYRE_AT = (8.0, -5.5)
CALL_BOX_AT = (6.0, 0.0, 17.6)


def fence_pts():
    step = (math.tau - 2 * GAP) / (FENCE_N - 1)
    return [GAP + k * step for k in range(FENCE_N)]


def rail_band(s, angles, yc, color):
    """A flat band 0.24 tall and 0.08 thick mounted outside the posts, one closed welded polyline through every post."""
    pts = []
    for a in angles:
        rx, rz = math.sin(a), math.cos(a)
        rin, rout = FENCE_R + 0.2, FENCE_R + 0.28
        pts += [(rin * rx, yc - 0.12, rin * rz), (rout * rx, yc - 0.12, rout * rz),
                (rout * rx, yc + 0.12, rout * rz), (rin * rx, yc + 0.12, rin * rz)]
    faces = []
    for i in range(len(angles) - 1):
        for c in range(4):
            d = (c + 1) % 4
            faces.append((4 * i + c, 4 * i + d, 4 * i + 4 + d, 4 * i + 4 + c))
    faces.append((3, 2, 1, 0))
    last = 4 * (len(angles) - 1)
    faces.append((last, last + 1, last + 2, last + 3))
    s.add(pts, faces, color)


def flat_prism(s, outline, y, h, color, at=(0.0, 0.0)):
    """A thin closed solid: an (x, z) outline (any simple polygon, counter-clockwise or not) from y to y + h."""
    n = len(outline)
    pts = [(at[0] + x, y + dy, at[1] + z) for dy in (0.0, h) for x, z in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    s.add(pts, faces, color)


def yard(s):
    n = 20
    pk.frustum(s, FLOOR_R + 0.5, FLOOR_R, 0.0, SAND, n, T["sandstone"])
    radii = [0.0, 6.0, 11.0, 16.0, FLOOR_R * math.cos(math.pi / n) - 0.03]
    for i in range(4):
        col = cp.jitter_tone("sand", i, 0.06) if i % 2 == 0 else cp.jitter_tone("plaza", i, 0.04)
        y1 = SAND + 0.01 + 0.003 * i
        if i == 0:
            pk.frustum(s, radii[1], radii[1], SAND - 0.02, y1, n, col)
        else:
            pk.ring_y(s, radii[i] - 0.05, radii[i + 1], SAND - 0.02, y1, n, col)
    angles = fence_pts()
    for a in angles:
        pk.frustum(s, 0.21, 0.16, 0.0, 1.55, 8, T["copper"], at=(FENCE_R * math.sin(a), FENCE_R * math.cos(a)))
    rail_band(s, angles, 0.62, T["iron"])
    rail_band(s, angles, 1.2, T["iron_hi"])
    for sx, a in ((-1, -GAP + 0.0), (1, GAP)):
        x = FENCE_R * math.sin(a)
        z = FENCE_R * math.cos(a)
        s.box((0.7, 1.9, 0.7), (x + sx * 0.6, 0.95, z), T["concrete"])
        s.box((0.74, 0.15, 0.74), (x + sx * 0.6, 1.95, z), T["copper_dk"])
    bx, bz = BLOCK_AT
    cp.obox(s, (3.0, 1.5, 1.6), (bx, 0.75 + SAND, bz), cp.jitter_tone("concrete", 3, 0.05), yaw=BLOCK_YAW)
    cp.obox(s, (3.04, 0.06, 1.64), (bx, 0.5 + SAND, bz), T["concrete_dk"], yaw=BLOCK_YAW)
    cp.obox(s, (3.04, 0.06, 1.64), (bx, 1.0 + SAND, bz), T["concrete_dk"], yaw=BLOCK_YAW)
    cp.obox(s, (3.2, 0.14, 1.8), (bx, 1.55 + SAND, bz), T["concrete_lt"], yaw=BLOCK_YAW)
    tx, tz = TYRE_AT
    for k in range(3):
        y0 = SAND + k * 0.55 - (0.02 if k else 0.0)
        pk.frustum(s, 0.95, 1.0, y0, y0 + 0.5, 8, cp.jitter_tone("charcoal", k, 0.1), at=(tx + 0.04 * k, tz))
        pk.frustum(s, 1.0, 0.98, y0 + 0.45, y0 + 0.55, 8, T["iron_hi"], at=(tx + 0.04 * k, tz))
    pk.frustum(s, 0.5, 0.5, SAND + 1.6, SAND + 1.67, 8, T["charcoal"], at=(tx + 0.08, tz))
    gx, gz = GRATE_AT
    pk.frustum(s, 3.3, 3.1, SAND, SAND + 0.2, 16, T["concrete"], at=GRATE_AT)
    pk.frustum(s, 3.0, 3.0, SAND + 0.18, SAND + 0.205, 16, T["charcoal"], at=GRATE_AT)
    pk.ring_y(s, 2.7, 3.05, SAND + 0.19, SAND + 0.3, 16, T["copper"], at=GRATE_AT)
    for k in range(-2, 3):
        x = k * 1.0
        half = math.sqrt(max(2.75 ** 2 - x * x, 0.0))
        cp.obox(s, (0.2, 0.12, half * 2), (gx + x, SAND + 0.27, gz), T["iron_hi"] if k % 2 else T["iron"])
    pk.frustum(s, 1.25, 1.2, SAND + 0.25, SAND + 0.36, 12, T["iron"], at=GRATE_AT)
    chev = [(-1.0, 0.45), (0.0, -0.5), (1.0, 0.45), (1.0, 1.0), (0.0, 0.05), (-1.0, 1.0)]
    for dz in (-0.55, 0.45):
        flat_prism(s, chev, SAND + 0.355, 0.03, T["brass"], at=(gx, gz + dz))
    cx, _, cz = CALL_BOX_AT
    s.box((2.4, 0.06, 2.0), (cx, SAND + 0.03, cz), T["concrete_lt"])


def yard_col(s):
    angles = fence_pts()
    for a in angles:
        x, z = FENCE_R * math.sin(a), FENCE_R * math.cos(a)
        cp.obox(s, (0.4, 1.55, 0.4), (x, 0.775, z), "iron", yaw=a)
    for i in range(len(angles) - 1):
        a0, a1 = angles[i], angles[i + 1]
        p0 = (FENCE_R * math.sin(a0), FENCE_R * math.cos(a0))
        p1 = (FENCE_R * math.sin(a1), FENCE_R * math.cos(a1))
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        cp.obox(s, (0.2, 0.9, length), (mid[0] * 1.012, 0.8, mid[1] * 1.012), "iron", yaw=math.atan2(p1[0] - p0[0], p1[1] - p0[1]))
    bx, bz = BLOCK_AT
    cp.obox(s, (3.0, 1.5, 1.6), (bx, 0.75 + SAND, bz), "iron", yaw=BLOCK_YAW)
    tx, tz = TYRE_AT
    pk.frustum(s, 0.95, 1.0, SAND, SAND + 1.65, 10, T["iron"], at=(tx, tz))


def yard_sockets():
    gx, gz = GRATE_AT
    out = {"entry": (0.0, 1.0, FENCE_R), "spawn_pad": (gx, SAND + 0.36, gz), "call_box": CALL_BOX_AT}
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        out["enemy_spawn_%d" % k] = (gx + 1.9 * math.sin(a), SAND + 0.5, gz + 1.9 * math.cos(a))
    return out


def check_yard(s):
    lo, hi = cp.bounds(s)
    assert max(abs(lo[0]), abs(hi[0]), abs(lo[2]), abs(hi[2])) <= 23.0, ("yard extent", lo, hi)
    assert hi[1] < 3.0


def call_box(s):
    s.box((1.3, 0.25, 1.3), (0, 0.125, 0), T["concrete"])
    s.box((1.34, 0.05, 1.34), (0, 0.22, 0), T["concrete_dk"])
    pk.frustum(s, 0.27, 0.23, 0.25, 1.15, 8, T["iron"])
    pk.frustum(s, 0.34, 0.34, 0.45, 0.6, 8, T["copper"])
    s.box((1.5, 1.1, 0.8), (0, 1.65, 0), T["iron"])
    for y in (1.12, 2.18):
        s.box((1.58, 0.1, 0.88), (0, y, 0), T["copper_dk"])
    for sx in (-1, 1):
        s.box((0.1, 1.1, 0.88), (sx * 0.74, 1.65, 0), T["copper_dk"])
    s.box((1.0, 0.26, 0.04), (0, 2.0, 0.41), T["brass"])
    chev = [(-0.32, 0.07), (0.0, -0.09), (0.32, 0.07), (0.32, 0.12), (0.0, -0.04), (-0.32, 0.12)]
    qface(s, [(x, 2.0 + 0.0 - z, 0.435) for x, z in chev], T["charcoal"], (0, 0, 1))
    dc = (-0.32, 1.52)
    pk.disc_z(s, 0, 0.4, 0.4, 0.48, 16, T["copper"], at=dc)
    pk.disc_z(s, 0, 0.32, 0.48, 0.52, 16, T["sand"], at=dc)
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        pk.bar_xy(s, (dc[0] + 0.25 * math.sin(a), dc[1] + 0.25 * math.cos(a)), -a, 0.07, 0.035, 0.52, 0.545, T["charcoal"])
    pk.bar_xy(s, (dc[0] + 0.1 * math.sin(0.6), dc[1] + 0.1 * math.cos(0.6)), -0.6, 0.3, 0.07, 0.52, 0.58, T["mint"])
    pk.disc_z(s, 0, 0.07, 0.58, 0.62, 8, T["copper"], at=dc)
    s.box((0.52, 0.09, 0.05), (0.38, 1.5, 0.41), T["charcoal"])
    s.box((0.34, 0.34, 0.025), (0.38, 1.38, 0.44), T["ledger"])
    s.box((0.34, 0.03, 0.03), (0.38, 1.2, 0.445), T["bone"])
    s.box((0.1, 1.1, 0.5), (0.84, 1.75, 0), T["iron_hi"])
    s.box((0.04, 0.8, 0.14), (0.9, 1.78, 0), T["charcoal"])
    pk.strut(s, (0.95, 1.4, 0), (1.25, 2.5, 0), 0.16, 0.16, T["copper"])
    pk.tube(s, (0.95, 1.4, -0.09), (0.95, 1.4, 0.09), 0.14, 0.14, 8, T["copper_dk"])
    cp.lamp(s, 1.27, 2.62, 0, 0.2, "mint")
    pk.frustum(s, 0.3, 0.26, 2.2, 2.34, 8, T["copper"])
    cp.lamp(s, 0, 2.68, 0, 0.24, "glass_lt")
    for a in cp.around(4, math.pi / 4):
        bx, bz = 0.3 * math.cos(a), 0.3 * math.sin(a)
        pk.strut(s, (bx, 2.34, bz), (bx * 0.5, 2.98, bz * 0.5), 0.05, 0.05, T["iron_hi"])
    pk.frustum(s, 0.17, 0.08, 2.98, 3.08, 8, T["copper_dk"])
    way = [(0.3, 1.9, -0.4), (0.3, 1.9, -0.95), (0.3, 1.65, -1.2), (0.3, 0.55, -1.2), (0.3, 0.3, -1.45), (0.3, 0.3, -2.3)]
    for a, b in zip(way, way[1:]):
        pk.tube(s, a, b, 0.11, 0.11, 8, T["copper"])
    for p in way[1:-1]:
        pk.frustum(s, 0.16, 0.16, p[1] - 0.06, p[1] + 0.06, 8, T["copper_dk"], at=(p[0], p[2]))
    for z in (-0.7, -1.9):
        pk.tube(s, (0.3, 0.3 if z < -1.5 else 1.9, z - 0.08), (0.3, 0.3 if z < -1.5 else 1.9, z + 0.08), 0.15, 0.15, 8, T["copper_dk"])
    pk.frustum(s, 0.55, 0.42, 0.0, 0.32, 8, T["concrete"], at=(0.3, -2.5))
    pk.frustum(s, 0.2, 0.2, 0.31, 0.34, 8, T["charcoal"], at=(0.3, -2.5))
    pk.strut(s, (0.0, 1.0, -0.2), (0.3, 1.9, -0.4), 0.1, 0.1, T["iron_hi"])


def call_box_col(s):
    s.box((0.6, 1.2, 0.6), (0, 0.6, 0), T["iron"])
    s.box((1.6, 1.1, 0.9), (0, 1.65, 0), T["iron"])


def call_box_sockets():
    return {"interact": (0.0, 1.0, 1.7), "dial": (-0.32, 1.52, 0.62), "lever": (1.25, 2.5, 0.0), "light_0": (0.0, 2.68, 0.0)}


def check_call_box(s):
    lo, hi = cp.bounds(s)
    assert lo[1] >= -1e-6 and hi[1] < 3.6 and hi[2] <= 1.0 and lo[2] >= -3.1, (lo, hi)


def main():
    args = cp.options()
    cp.export("camp_trial_track", track, "park_large", args, col=track_col, sockets=track_sockets(), check=check_track)
    cp.export("camp_trial_arch", arch, "gate", args, col=arch_col, sockets=arch_sockets(), check=check_arch)
    cp.export("camp_sandbox_yard", yard, "park_large", args, col=yard_col, sockets=yard_sockets(), check=check_yard)
    cp.export("camp_call_box", call_box, "detail", args, col=call_box_col, sockets=call_box_sockets(), check=check_call_box)


if __name__ == "__main__":
    main()
