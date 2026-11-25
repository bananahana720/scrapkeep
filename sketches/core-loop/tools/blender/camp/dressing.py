"""Headless recipe for the camp dressing kit: nine small GLBs that dress the ring between the stations (camp kit, _camp.py
header). Warm timber, canvas, copper and soft lamp light, so the camp reads as somewhere to stay. All are ball-scaled (the
ball is 2 m across), origin on the ground at the footprint centre, local +Z facing the plaza, flat-shaded, one enamel draw.

Class prop (270 tris / 610 verts): camp_lamp_post, camp_signpost, camp_bench, camp_crate_stack, camp_barrel, camp_fence.
Class detail (1500 / 3000), because a prop's budget cannot hold the silhouette: camp_fire_pit (stone ring, crossed logs,
flames and a tripod kettle), camp_tool_rack (a framed rack of wrenches and a harpoon tip) and camp_tarp (a sagging canvas
on two poles with guy ropes).

camp_lamp_post: a 4.5 m timber post with a copper bracket arm and a caged bulb hanging from it, toward +Z.
  Socket light_0 at the bulb centre. Collision: the post and its footing as one box.
camp_signpost: a 3.6 m timber post with three arrow boards pointing different ways, each with a plain icon (a dial, a star,
  a ball; no letters). Collision: the post.
camp_fire_pit: a ring of ten stones, three crossed logs on a charcoal bed, three flames, and a kettle hung from an iron
  tripod. Socket light_0 at the fire. Collision: the stone ring as a low cylinder (r 1.7, 0.5 m).
camp_bench: a plank bench (2.8 m) on two crate legs. Collision: one box.
camp_crate_stack: three salvage crates (two stacked, one beside) with a brass Fleet requisition tag on the front one.
  Collision: three boxes.
camp_barrel: an oil drum with a dent and a copper band. Collision: a cylinder.
camp_fence: a 4 m rail section, two posts and two rails, origin at its centre. Collision: both posts and the rail slab.
camp_tool_rack: an A-frame rack with a rail of wrenches, a hammer and a spare harpoon tip. No collision (it dresses a
  wall of crates and never blocks the ball).
camp_tarp: a 5 x 4 m canvas awning on two tall poles at the back with ropes to pegs at the front, sagging. No collision.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/dressing.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk


def lh(s, x0, x1, y0, y1, z0, z1, color):
    s.box((x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color)


def plank(s, k, x0, x1, y0, y1, z0, z1, name="timber"):
    lh(s, x0, x1, y0, y1, z0, z1, cp.jitter_tone(name, k, 0.14))


def col_box(s, x0, x1, y0, y1, z0, z1):
    lh(s, x0, x1, y0, y1, z0, z1, "iron")


def lathe(s, prof, n, color, at=(0.0, 0.0)):
    """A closed welded solid of revolution about +Y: prof is a list of (radius, y) from the bottom up; a radius of 0 is a point
    on the axis (the first and last entries are normally 0 to close the ends)."""
    verts, rings = [], []
    for r, y in prof:
        if r <= 0.0:
            rings.append([len(verts)] * n)
            verts.append((at[0], y, at[1]))
        else:
            rings.append([len(verts) + k for k in range(n)])
            verts += [(at[0] + r * math.sin(a), y, at[1] + r * math.cos(a)) for a in pk.around(n, math.pi / n)]
    faces = []
    for ra, rb in zip(rings, rings[1:]):
        for k in range(n):
            q = [ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]]
            q = [v for m, v in enumerate(q) if v != q[m - 1]]
            if len(set(q)) >= 3:
                faces.append(tuple(q))
    s.add(verts, faces, color)


def height_check(lo_h, hi_h):
    def check(s):
        lo, hi = cp.bounds(s)
        assert abs(lo[1]) < 0.06 and lo_h < hi[1] < hi_h, ("height", lo, hi)
    return check


BULB = (0.0, 3.8, 1.0)


def lamp_post(s):
    lh(s, -0.3, 0.3, 0.0, 0.3, -0.3, 0.3, "concrete")
    plank(s, 0, -0.14, 0.14, 0.3, 4.5, -0.14, 0.14)
    lh(s, -0.19, 0.19, 0.9, 1.05, -0.19, 0.19, "copper_dk")
    lh(s, -0.19, 0.19, 3.9, 4.05, -0.19, 0.19, "copper")
    lh(s, -0.05, 0.05, 4.0, 4.1, 0.1, 1.05, "copper")
    pk.strut(s, (0, 3.5, 0.14), (0, 4.02, 0.7), 0.07, 0.07, T["copper"])
    lh(s, -0.04, 0.04, 3.95, 4.0, 0.98, 1.02, "iron")
    pk.tube(s, (0, 3.95, 1.0), (0, 4.1, 1.0), 0.02, 0.02, 4, T["iron"])
    lh(s, -0.2, 0.2, 3.98, 4.04, 0.8, 1.2, "copper")
    lh(s, -0.17, 0.17, 3.45, 3.5, 0.83, 1.17, "copper")
    for sx in (-1, 1):
        for sz in (-1, 1):
            lh(s, sx * 0.17 - 0.015, sx * 0.17 + 0.015, 3.5, 3.98, 1.0 + sz * 0.17 - 0.015, 1.0 + sz * 0.17 + 0.015, "iron")
    lathe(s, [(0.0, 3.55), (0.04, 3.55), (0.13, 3.8), (0.05, 3.95), (0.0, 3.95)], 6, T["glass_lt"], at=(0.0, 1.0))
    lathe(s, [(0.0, 4.04), (0.22, 4.04), (0.02, 4.28), (0.0, 4.28)], 4, T["copper_dk"], at=(0.0, 1.0))


def lamp_col(s):
    col_box(s, -0.3, 0.3, 0.0, 4.5, -0.3, 0.3)


def arrow_board(s, base, yaw, flip, length, h, thick, color):
    """A pentagon arrow board standing on the post: u points along the arrow (flip points it the other way), w is the face."""
    f = -1.0 if flip else 1.0
    ca, sa = math.cos(yaw), math.sin(yaw)
    hd = 0.45

    def w(u, v, t):
        u *= f
        return (base[0] + u * ca + t * sa, base[1] + v, base[2] - u * sa + t * ca)

    outline = [(-0.2, -h / 2), (length - hd, -h / 2), (length, 0.0), (length - hd, h / 2), (-0.2, h / 2)]
    pts = [w(u, v, t) for t in (-thick / 2, thick / 2) for u, v in outline]
    n = len(outline)
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    s.add(pts, faces, color)
    return w


def signpost(s):
    lh(s, -0.4, 0.4, 0.0, 0.25, -0.4, 0.4, "concrete_dk")
    plank(s, 1, -0.13, 0.13, 0.25, 3.6, -0.13, 0.13)
    lh(s, -0.18, 0.18, 3.6, 3.72, -0.18, 0.18, "copper")
    boards = [(3.15, 0.3, False, "timber_lt", "dial"), (2.55, -0.25, True, "petrol", "star"), (1.95, -0.85, False, "oxide", "ball")]
    for y, yaw, flip, col, icon in boards:
        w = arrow_board(s, (0.0, y, 0.0), yaw, flip, 1.5, 0.5, 0.1, col)
        t = 0.07
        if icon == "dial":
            ca, sa = math.cos(yaw), math.sin(yaw)
            c = w(0.55, 0, t)
            pk.tube(s, c, (c[0] + sa * 0.03, c[1], c[2] + ca * 0.03), 0.17, 0.17, 6, T["bone"], caps=(False, True))
            cp.obox(s, (0.04, 0.2, 0.03), (c[0] + sa * 0.04, c[1] + 0.05, c[2] + ca * 0.04), T["iron"], yaw=yaw)
        elif icon == "star":
            c = w(0.55, 0, t)
            for k in range(2):
                cp.obox(s, (0.34, 0.09, 0.04), (c[0], c[1], c[2]), T["bone"], yaw=yaw if not flip else yaw, roll=k * math.pi / 2 + 0.0)
        else:
            c = w(0.55, 0, t)
            ca, sa = math.cos(yaw), math.sin(yaw)
            pk.tube(s, c, (c[0] + sa * 0.04, c[1], c[2] + ca * 0.04), 0.15, 0.15, 6, T["amber"], caps=(False, True))
    for sx, sz in ((-1, -1), (1, 1), (1, -1)):
        lh(s, sx * 0.3 - 0.12, sx * 0.3 + 0.12, 0.25, 0.4, sz * 0.25 - 0.1, sz * 0.25 + 0.1, "concrete_lt")


def post_col(s):
    col_box(s, -0.2, 0.2, 0.0, 3.6, -0.2, 0.2)


def fire_pit(s):
    R = 1.35
    for i in range(10):
        a = math.tau * i / 10
        sz = (0.58, 0.42 + 0.06 * (i % 3), 0.5)
        cp.obox(s, sz, (R * math.sin(a), sz[1] / 2 - 0.02, R * math.cos(a)), cp.jitter_tone("concrete", i * 3 + 1, 0.2), yaw=a + 0.15 * (i % 3))
    pk.frustum(s, 1.15, 1.15, 0.0, 0.18, 10, T["charcoal"], caps=(False, True))
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        cp.obox(s, (0.3, 0.16, 0.24), (1.22 * math.sin(a), 0.5, 1.22 * math.cos(a)), cp.jitter_tone("concrete_lt", i, 0.15), yaw=a + 0.3 * (i % 2))
    for k, (yaw, y) in enumerate(((0.3, 0.28), (2.4, 0.32), (4.5, 0.36))):
        d = (math.sin(yaw), math.cos(yaw))
        pk.tube(s, (-d[0] * 0.95, y, -d[1] * 0.95), (d[0] * 0.95, y + 0.12, d[1] * 0.95), 0.12, 0.11, 6, T["timber"] if k != 1 else T["timber_lt"], caps=(True, True))
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        base = (0.38 * math.sin(a), 0.4, 0.38 * math.cos(a))
        top = (base[0] * 0.5, 1.0 + 0.2 * (k % 2), base[2] * 0.5)
        pk.tube(s, base, top, 0.2, 0.0001, 5, T["amber"] if k % 2 == 0 else "f4c36a", caps=(True, False))
    pk.tube(s, (0, 0.4, 0), (0, 0.85, 0), 0.14, 0.0001, 5, "ffe9a8", caps=(False, False))
    top = (0.0, 2.7, -0.15)
    for k in range(3):
        a = math.tau * k / 3 + 0.9
        pk.tube(s, (2.0 * math.sin(a), 0.0, -0.15 + 2.0 * math.cos(a)), top, 0.06, 0.05, 5, T["iron_hi"], caps=(True, False))
    lh(s, -0.1, 0.1, 2.62, 2.74, -0.25, -0.05, "copper")
    pk.tube(s, (0, 2.62, -0.15), (0, 1.5, -0.15), 0.025, 0.025, 4, T["iron"], caps=(False, False))
    ky = 1.0
    kc = (0.0, 0.0, -0.15)
    pk.frustum(s, 0.42, 0.34, ky, ky + 0.5, 10, T["iron"], caps=(True, True), at=(kc[0], kc[2]))
    pk.frustum(s, 0.32, 0.12, ky + 0.5, ky + 0.62, 10, T["copper"], caps=(False, True), at=(kc[0], kc[2]))
    pk.tube(s, (0.3, ky + 0.2, kc[2]), (0.62, ky + 0.42, kc[2]), 0.09, 0.05, 5, T["iron"], caps=(False, True))
    for sx in (-1, 1):
        lh(s, sx * 0.4 - 0.02, sx * 0.4 + 0.02, ky + 0.5, ky + 0.95, kc[2] - 0.02, kc[2] + 0.02, "iron_hi") if False else None
    pk.strut(s, (-0.38, ky + 0.5, kc[2]), (0.0, ky + 0.98, kc[2]), 0.04, 0.04, T["iron_hi"])
    pk.strut(s, (0.38, ky + 0.5, kc[2]), (0.0, ky + 0.98, kc[2]), 0.04, 0.04, T["iron_hi"])
    cp.obox(s, (0.12, 0.12, 0.7), (1.9, 0.07, 0.9), T["timber_lt"], yaw=0.5)
    cp.obox(s, (0.12, 0.12, 0.6), (-1.8, 0.07, 1.0), T["timber"], yaw=-0.4)


def fire_col(s):
    pk.frustum(s, 1.7, 1.7, 0.0, 0.5, 10, "iron")


def crate_leg(s, cx, cz, k, w=0.55, h=0.62):
    lh(s, cx - w / 2, cx + w / 2, 0.0, h, cz - 0.3, cz + 0.3, cp.jitter_tone("timber_lt", k, 0.12))
    for dy in (0.18, 0.44):
        lh(s, cx - w / 2 - 0.02, cx + w / 2 + 0.02, dy, dy + 0.08, cz - 0.32, cz + 0.32, "timber")


def bench(s):
    for k, cx in enumerate((-1.0, 1.0)):
        crate_leg(s, cx, 0.0, k)
    for k, z in enumerate((-0.17, 0.17)):
        plank(s, k + 3, -1.4, 1.4, 0.62, 0.76, z - 0.16, z + 0.16, "timber_lt")
    lh(s, -1.38, -1.0, 0.56, 0.62, -0.28, 0.28, "timber")
    lh(s, 1.0, 1.38, 0.56, 0.62, -0.28, 0.28, "timber")


def bench_col(s):
    col_box(s, -1.4, 1.4, 0.0, 0.76, -0.35, 0.35)


def crate(s, cx, cy, cz, size, yaw, k):
    h = size / 2
    cp.obox(s, (size, size, size), (cx, cy + h, cz), cp.jitter_tone("timber_lt", k, 0.12), yaw=yaw)
    ca, sa = math.cos(yaw), math.sin(yaw)
    for sx in (-1, 1):
        for sz in (-1, 1):
            ox, oz = sx * (h - 0.03), sz * (h - 0.03)
            cp.obox(s, (0.1, size + 0.02, 0.1), (cx + ox * ca + oz * sa, cy + h, cz - ox * sa + oz * ca), cp.jitter_tone("timber", k + 2, 0.1), yaw=yaw)
    cp.obox(s, (size * 1.1, 0.09, 0.03), (cx + sa * (h + 0.005), cy + h, cz + ca * (h + 0.005)), cp.jitter_tone("timber", k + 5, 0.1), yaw=yaw, roll=math.pi / 4)
    return ca, sa


def crate_stack(s):
    crate(s, -0.55, 0.0, 0.0, 1.2, 0.05, 1)
    crate(s, -0.5, 1.2, -0.05, 1.0, -0.25, 4)
    ca, sa = crate(s, 0.85, 0.0, 0.25, 0.95, 0.35, 7)
    fx, fz = 0.85 + 0.475 * math.sin(0.35), 0.25 + 0.475 * math.cos(0.35)
    n = (math.sin(0.35), math.cos(0.35))
    cp.obox(s, (0.34, 0.22, 0.03), (fx + n[0] * 0.07, 0.62, fz + n[1] * 0.07), T["brass"], yaw=0.35)
    cp.obox(s, (0.2, 0.05, 0.02), (fx + n[0] * 0.09, 0.62, fz + n[1] * 0.09), T["iron"], yaw=0.35)


def crate_col(s):
    cp.obox(s, (1.15, 2.2, 1.15), (-0.55, 1.1, -0.02), "iron", yaw=-0.1)
    cp.obox(s, (0.95, 0.95, 0.95), (0.85, 0.475, 0.25), "iron", yaw=0.35)


def barrel(s):
    R, H = 0.46, 1.1
    pk.frustum(s, R, R, 0.0, H, 12, T["petrol"], caps=(True, True))
    pk.frustum(s, R + 0.02, R + 0.02, 0.38, 0.55, 12, T["copper"], caps=(False, False))
    for y in (0.04, 0.96):
        pk.frustum(s, R + 0.025, R + 0.025, y, y + 0.1, 12, T["iron_hi"], caps=(False, False))
    pk.frustum(s, 0.1, 0.1, H, H + 0.04, 6, T["iron"], caps=(False, True), at=(0.17, 0.12))
    pk.frustum(s, 0.06, 0.06, H, H + 0.03, 5, T["copper_dk"], caps=(False, True), at=(-0.2, -0.1))
    cp.obox(s, (0.3, 0.2, 0.04), (-0.1, 0.78, R - 0.02), "2a4442", yaw=0.0, roll=0.25)
    cp.obox(s, (0.18, 0.1, 0.03), (-0.1, 0.78, R - 0.005), "1f3331", yaw=0.0, roll=0.25)
    cp.obox(s, (0.4, 0.05, 0.03), (0.0, 0.2, R), T["oxide"], yaw=0.0, roll=0.15)


def barrel_col(s):
    pk.frustum(s, 0.47, 0.47, 0.0, 1.1, 8, "iron")


def fence(s):
    for k, x in enumerate((-1.9, 1.9)):
        plank(s, k + 5, x - 0.09, x + 0.09, 0.0, 1.3, -0.09, 0.09)
        lh(s, x - 0.12, x + 0.12, 1.3, 1.36, -0.12, 0.12, "copper_dk")
    for k, (y0, y1) in enumerate(((0.42, 0.58), (0.88, 1.04))):
        plank(s, k, -1.9, 1.9, y0, y1, 0.09, 0.15, "timber_lt")
    cp.obox(s, (0.1, 1.0, 0.04), (0.0, 0.73, 0.18), T["timber"], roll=0.0)
    cp.obox(s, (0.12, 1.1, 0.04), (0.9, 0.7, 0.19), T["timber"], roll=-0.7)
    lh(s, -1.9 - 0.1, -1.9 + 0.1, 0.9, 1.0, 0.15, 0.17, "iron")
    lh(s, 1.9 - 0.1, 1.9 + 0.1, 0.9, 1.0, 0.15, 0.17, "iron")
    lh(s, 1.9 - 0.1, 1.9 + 0.1, 0.45, 0.55, 0.15, 0.17, "iron")
    lh(s, -1.9 - 0.1, -1.9 + 0.1, 0.45, 0.55, 0.15, 0.17, "iron")


def fence_col(s):
    col_box(s, -2.0, -1.8, 0.0, 1.36, -0.12, 0.12)
    col_box(s, 1.8, 2.0, 0.0, 1.36, -0.12, 0.12)
    col_box(s, -1.8, 1.8, 0.4, 1.06, 0.0, 0.16)


def wrench(s, x, y, length, z, color, k):
    """A hanging open-end wrench, shaft down, head up: a shaft and a U of three boxes."""
    lh(s, x - 0.04, x + 0.04, y - length, y, z, z + 0.04, color)
    lh(s, x - 0.11, x + 0.11, y, y + 0.07, z, z + 0.04, color)
    lh(s, x - 0.11, x - 0.06, y + 0.07, y + 0.2, z, z + 0.04, color)
    lh(s, x + 0.06, x + 0.11, y + 0.07, y + 0.2, z, z + 0.04, color)


def tool_rack(s):
    for sx in (-1, 1):
        x = sx * 1.1
        for sz in (-1, 1):
            pk.strut(s, (x, 0.0, sz * 0.5), (x, 2.0, 0.0), 0.12, 0.12, cp.jitter_tone("timber", 2 + sx + sz, 0.12))
        lh(s, x - 0.08, x + 0.08, 0.45, 0.55, -0.4, 0.4, "timber_lt") if False else None
        pk.strut(s, (x, 0.5, -0.35), (x, 0.5, 0.35), 0.1, 0.08, T["timber_lt"])
        lh(s, x - 0.12, x + 0.12, 1.98, 2.08, -0.12, 0.12, "copper")
    for y, k in ((1.7, 0), (0.9, 1)):
        pk.tube(s, (-1.2, y, 0.0), (1.2, y, 0.0), 0.05, 0.05, 6, T["iron_hi"], caps=(True, True))
    lh(s, -1.2, 1.2, 1.55, 1.85, -0.06, -0.02, "timber")
    for k, (x, ln) in enumerate(((-0.95, 0.75), (-0.62, 0.62), (-0.3, 0.85))):
        wrench(s, x, 1.68, ln, 0.03, "copper" if k != 1 else "iron_hi", k)
    lh(s, 0.0, 0.06, 1.0, 1.66, 0.04, 0.09, "timber_lt")
    lh(s, -0.12, 0.18, 1.52, 1.66, 0.02, 0.12, "iron")
    pk.tube(s, (0.75, 0.9, 0.08), (0.75, 0.2, 0.08), 0.03, 0.035, 6, T["timber_lt"], caps=(False, True))
    pk.tube(s, (0.75, 0.9, 0.08), (0.75, 1.3, 0.08), 0.1, 0.0001, 6, T["iron_hi"], caps=(True, False))
    for sx in (-1, 1):
        cp.obox(s, (0.05, 0.22, 0.04), (0.75 + sx * 0.1, 0.87, 0.08), T["iron_hi"], roll=-sx * 0.55)
    pk.tube(s, (0.75, 0.82, 0.08), (0.75, 0.9, 0.08), 0.07, 0.07, 6, T["copper"], caps=(False, False))
    pk.frustum(s, 0.2, 0.2, 1.4, 1.62, 8, T["canvas_dk"], caps=(True, True), at=(0.35, 0.1))


NX, NZ = 8, 6
TW, TD = 5.0, 4.0
BACK_Y, FRONT_Y = 3.3, 2.3
SAG = 0.32


def tarp_y(x, z):
    t = (TD / 2 - z) / TD
    base = FRONT_Y + (BACK_Y - FRONT_Y) * t
    return base - SAG * (1 - (2 * x / TW) ** 2) * math.sin(math.pi * min(max(t, 0.0), 1.0) ** 0.9) * 0.8 - 0.1 * (1 - (2 * x / TW) ** 2)


def tarp(s):
    top = {}
    for i in range(NX + 1):
        for j in range(NZ + 1):
            x = -TW / 2 + TW * i / NX
            z = TD / 2 - TD * j / NZ
            top[(i, j)] = (x, tarp_y(x, z), z)
    thick = 0.05
    verts, cols, hi, lo = [], [], {}, {}
    for i in range(NX + 1):
        for j in range(NZ + 1):
            p = top[(i, j)]
            name = "canvas" if (min(i, NX - 1) // 2) % 2 == 0 else "canvas_dk"
            hi[i, j] = len(verts)
            verts.append(p)
            cols.append(cp.jitter_tone(name, i * 5 + j, 0.05))
            lo[i, j] = len(verts)
            verts.append((p[0], p[1] - thick, p[2]))
            cols.append(cp.jitter_tone(name, i * 5 + j + 3, 0.05))
    faces = []
    for i in range(NX):
        for j in range(NZ):
            faces.append((hi[i, j], hi[i, j + 1], hi[i + 1, j + 1], hi[i + 1, j]))
            faces.append((lo[i, j], lo[i + 1, j], lo[i + 1, j + 1], lo[i, j + 1]))
    for i in range(NX):
        faces.append((hi[i, 0], hi[i + 1, 0], lo[i + 1, 0], lo[i, 0]))
        faces.append((hi[i, NZ], lo[i, NZ], lo[i + 1, NZ], hi[i + 1, NZ]))
    for j in range(NZ):
        faces.append((hi[0, j], lo[0, j], lo[0, j + 1], hi[0, j + 1]))
        faces.append((hi[NX, j], hi[NX, j + 1], lo[NX, j + 1], lo[NX, j]))
    s.add(verts, faces, colors=cols)
    for sx in (-1, 1):
        px = sx * (TW / 2 + 0.1)
        pk.tube(s, (px, 0.0, -TD / 2 - 0.05), (px, BACK_Y + 0.35, -TD / 2 - 0.05), 0.1, 0.07, 6, T["timber"], caps=(True, True))
        lh(s, px - 0.1, px + 0.1, BACK_Y + 0.35, BACK_Y + 0.43, -TD / 2 - 0.15, -TD / 2 + 0.05, "copper")
        lh(s, px - 0.25, px + 0.25, 0.0, 0.1, -TD / 2 - 0.25, -TD / 2 + 0.15, "concrete")
        fx = sx * (TW / 2)
        fy = tarp_y(sx * TW / 2, TD / 2)
        pk.strut(s, (fx, fy - 0.03, TD / 2), (sx * (TW / 2 + 0.5), 0.12, TD / 2 + 0.9), 0.04, 0.04, T["canvas_dk"])
        cp.obox(s, (0.1, 0.4, 0.1), (sx * (TW / 2 + 0.5), 0.15, TD / 2 + 0.9), T["timber_lt"], pitch=-0.35)
        pk.strut(s, (sx * (TW / 2 + 0.1), BACK_Y + 0.3, -TD / 2 - 0.05), (sx * (TW / 2 + 0.9), 0.1, -TD / 2 - 1.5), 0.035, 0.035, T["canvas_dk"])
        cp.obox(s, (0.1, 0.4, 0.1), (sx * (TW / 2 + 0.9), 0.15, -TD / 2 - 1.5), T["timber_lt"], pitch=0.35)
    pk.strut(s, (0, tarp_y(0, -1.5) - 0.05, -1.5), (0, 2.55, -1.5), 0.03, 0.03, T["iron"])
    lh(s, -0.12, 0.12, 2.0, 2.05, -1.62, -1.38, "copper")
    pk.tube(s, (0, 2.05, -1.5), (0, 2.5, -1.5), 0.1, 0.07, 6, T["glass_lt"], caps=(True, True))
    lh(s, -0.13, 0.13, 2.5, 2.56, -1.63, -1.37, "copper")


def main():
    args = cp.options()
    cp.export("camp_lamp_post", lamp_post, "prop", args, col=lamp_col, sockets={"light_0": BULB}, check=height_check(4.2, 4.8))
    cp.export("camp_signpost", signpost, "prop", args, col=post_col, check=height_check(3.4, 3.9))
    cp.export("camp_fire_pit", fire_pit, "detail", args, col=fire_col, sockets={"light_0": (0.0, 0.8, 0.0)}, check=height_check(2.6, 3.0))
    cp.export("camp_bench", bench, "prop", args, col=bench_col, check=height_check(0.7, 0.9))
    cp.export("camp_crate_stack", crate_stack, "prop", args, col=crate_col, check=height_check(2.0, 2.5))
    cp.export("camp_barrel", barrel, "prop", args, col=barrel_col, check=height_check(1.1, 1.3))
    cp.export("camp_fence", fence, "prop", args, col=fence_col, check=height_check(1.2, 1.5))
    cp.export("camp_tool_rack", tool_rack, "detail", args, check=height_check(1.9, 2.3))
    cp.export("camp_tarp", tarp, "detail", args, check=height_check(3.4, 4.0))


if __name__ == "__main__":
    main()
