"""Headless recipe for the camp's launch gate and pilot lockers, six GLBs (camp kit, _camp.py header).

camp_launch_gate (+ _detail1, _detail2): the hero piece, 70 m dead ahead of the spawn; rolling through it starts a run.
Two chunky petrol pylons with copper bands on dark iron plinths hold a header beam 9.4 m above the pad, clear opening 12 m
wide (the checks insist on 11 m by 9 m). A 12 x 12 m iron launch pad sits 8 cm proud with chamfered edges like the plaza's
slabs, a mint centre track and four mint chevrons pointing -Z. On the header: a copper cog emblem with a mint chevron (no
text), a row of amber marquee bulbs, and a drag-race start tree (two amber lamps, then one mint) on a post above it, with
amber beacons on the header ends. Behind the gate (-Z) a 10 m catapult rail with a shuttle sled and buffer stop.
Origin at the pad centre on the ground; +Z faces the plaza, the ball rolls through toward -Z. Class gate.
Collision: both pylons (plinth and shaft), the header, and the pad as one flat chamfered slab. Nothing collides in the opening.
Sockets: launch_trigger (pad centre, y 1.0), sign (header front centre, over the emblem's rim; the runtime label hangs on
it), light_tree_0..2 (top to bottom), light_marquee_00..21 (14 on the header, 4 up each pylon front).
detail1: rivet and bolt rows, cable runs, signal boxes. detail2: small pipes, panel seams, bulb cages. Class detail.

camp_lockers (+ _detail1, _detail2): the pilot lockers station. Six open-front bays in a shallow arc (radius 30 m, concave
toward +Z), about 22 m wide, in the PILOTS order left to right (-X to +X). Each bay: dark petrol cabinet with copper trim,
~3.2 m wide and 4 m tall, a class-colour band across its top, a swung-open door carrying the class shape as a raised
emblem (ring, chevron, burst, cross, square, lane), a round turntable plinth where the pilot stands, a shelf, a coat
hook and a timber bench in front; one canvas awning roof over all six. Origin on the ground at the arc's centre line
(middle of the cabinets' fronts); +Z faces the plaza. Class gate.
Collision: seven boxes: the back wall as two three-bay runs, the two end walls and the benches as two three-bay runs (no
per-bay dividers; the class budget covers collision too). Not the cubby insides.
Sockets: locker_<pilot id> at each plinth's top centre, interact (front centre, y 1.0).
detail1: vents, hinges, padlocks, rivets. detail2: hanging helmet, goggles, scarf and tool silhouettes, stickers.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/gate_lockers.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk
OPEN_HALF, OPEN_TOP = 5.5, 9.0
PAD_TOP = 0.08


def bx(s, size, center, color, flat=False):
    """A box; flat=True drops the bottom face for pieces that stand on something."""
    hx, hy, hz = (v / 2 for v in size)
    cx, cy, cz = center
    pts = [(cx + a * hx, cy + b * hy, cz + c * hz) for a, b, c in
           [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
    s.add(pts, faces[:2] + faces[3:] if flat else faces, color)


def stud(s, p, normal, r, h, color, n=4):
    """A small bolt head standing out along normal (a lean 4-sided closed version of _park.hexstud)."""
    nv = pk.Vector(normal).normalized()
    pk.tube(s, pk.Vector(p), pk.Vector(p) + nv * h, r, r * 0.85, n, color)


class Xf:
    """Draws into a parent surface through a yaw turn and an offset, so a bay is built once in its own frame."""

    def __init__(self, base, origin=(0.0, 0.0, 0.0), yaw=0.0):
        self.base, self.o, self.c, self.s = base, origin, math.cos(yaw), math.sin(yaw)

    def pt(self, p):
        x, y, z = p
        return (self.o[0] + x * self.c + z * self.s, self.o[1] + y, self.o[2] - x * self.s + z * self.c)

    def add(self, verts, faces, color="petrol", colors=None):
        self.base.add([self.pt(v) for v in verts], faces, color, colors)


PX_IN, PW, PD = 6.0, 2.6, 2.4
PCX = PX_IN + PW / 2
Y_HDR0, HDR_H = 9.4, 3.0
Y_HDR1 = Y_HDR0 + HDR_H
HDR_HW, HDR_HZ = 8.9, 1.3
PAD = 12.0
RAIL_Z0, RAIL_LEN = -6.5, 10.0
EMB = (0.0, 11.0)
Z_FRONT = HDR_HZ
TREE_Y = (13.6, 14.8, 16.0)
MARQUEE_Y = 10.05
MARQUEE_X = [sx * (1.6 + 0.9 * j) for sx in (-1, 1) for j in range(7)]
PYLON_BULB_Y = (3.3, 4.2, 6.2, 7.1)


def marquee_points():
    pts = [(x, MARQUEE_Y, Z_FRONT + 0.15) for x in MARQUEE_X]
    for sx in (-1, 1):
        pts += [(sx * PCX, y, PD / 2 + 0.1) for y in PYLON_BULB_Y]
    return pts


def pad_slab(s, color):
    """The launch pad: 12 x 12 top, 13 x 13 foot, 8 cm proud, chamfered on all four sides like the plaza's slabs."""
    h, f = PAD / 2, PAD / 2 + 0.5
    pts = [(-f, 0, -f), (f, 0, -f), (f, 0, f), (-f, 0, f), (-h, PAD_TOP, -h), (h, PAD_TOP, -h), (h, PAD_TOP, h), (-h, PAD_TOP, h)]
    s.add(pts, [(4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], color)


def gate(s):
    pad_slab(s, T["iron"])
    h = PAD / 2
    for sz in (-1, 1):
        bx(s, (PAD - 0.4, 0.018, 0.3), (0, PAD_TOP + 0.009, sz * (h - 0.25)), T["copper"], True)
    for sx in (-1, 1):
        bx(s, (0.3, 0.018, PAD - 0.4), (sx * (h - 0.25), PAD_TOP + 0.009, 0), T["copper"], True)
    for k, x in enumerate((-2.9, 2.9)):
        bx(s, (0.06, 0.008, PAD - 1.2), (x, PAD_TOP + 0.004, 0), T["iron_hi"], True)
    for k, z in enumerate((-3.0, 3.0)):
        bx(s, (PAD - 1.2, 0.008, 0.06), (0, PAD_TOP + 0.004, z), T["iron_hi"], True)
    bx(s, (1.8, 0.014, PAD - 1.0), (0, PAD_TOP + 0.007, 0), T["mint_dk"], True)
    for apex in (3.8, 1.6, -0.6, -2.8):
        for sx in (-1, 1):
            cp.obox(s, (0.5, 0.02, 2.6), (sx * 0.92, PAD_TOP + 0.01, apex + 0.92), T["mint"], yaw=sx * math.pi / 4)
    for sx in (-1, 1):
        for sz in (-1, 1):
            stud(s, (sx * (h - 0.6), PAD_TOP, sz * (h - 0.6)), (0, 1, 0), 0.14, 0.018, T["copper_dk"], 6)
    for sx in (-1, 1):
        cx = sx * PCX
        bx(s, (3.2, 0.9, 3.2), (sx * 7.4, 0.45, 0), T["iron_hi"], True)
        bx(s, (PW, Y_HDR0 - 0.9, PD), (cx, 0.9 + (Y_HDR0 - 0.9) / 2, 0), T["petrol"])
        for ax in (-1, 1):
            for az in (-1, 1):
                bx(s, (0.32, Y_HDR0 - 0.9, 0.32), (cx + ax * (PW / 2 - 0.04), 0.9 + (Y_HDR0 - 0.9) / 2, az * (PD / 2 - 0.04)),
                   T["iron"])
        for k, y in enumerate((2.2, 5.2, 8.2)):
            bx(s, (PW + 0.3, 0.45, PD + 0.3), (cx, y, 0), cp.jitter_tone("copper", k + (sx > 0)))
        bx(s, (3.2, 0.5, 2.8), (sx * 7.4, Y_HDR0 - 0.25, 0), T["iron_hi"])
        bx(s, (1.5, 3.4, 0.05), (cx, 4.65, PD / 2 + 0.02), T["petrol_dk"])
    for x, y, z in marquee_points()[14:]:
        pk.disc_z(s, 0, 0.2, z - 0.1, z + 0.12, 6, T["amber"], at=(x, y))
    bx(s, (2 * HDR_HW, HDR_H, 2 * HDR_HZ), (0, Y_HDR0 + HDR_H / 2, 0), T["petrol"])
    bx(s, (2 * HDR_HW + 0.1, 0.35, 2 * HDR_HZ + 0.2), (0, Y_HDR0 + 0.175, 0), T["iron"])
    bx(s, (2 * HDR_HW + 0.4, 0.3, 2 * HDR_HZ + 0.4), (0, Y_HDR1 + 0.15, 0), T["copper"])
    bx(s, (2 * HDR_HW - 0.4, 0.28, 0.16), (0, MARQUEE_Y - 0.05, Z_FRONT + 0.08), T["copper_dk"])
    for sx in (-1, 1):
        bx(s, (6.0, 1.5, 0.1), (sx * 5.2, 11.15, Z_FRONT + 0.05), T["petrol_dk"])
        for k in range(3):
            cp.obox(s, (0.5, 0.5, 0.05), (sx * (3.6 + 1.6 * k), 11.15, Z_FRONT + 0.12), T["amber"], roll=math.pi / 4)
        bx(s, (6.0, 0.1, 0.14), (sx * 5.2, 11.95, Z_FRONT + 0.1), T["copper"])
        bx(s, (6.0, 0.1, 0.14), (sx * 5.2, 10.35, Z_FRONT + 0.1), T["copper"])
    for x, y, z in marquee_points()[:14]:
        pk.disc_z(s, 0, 0.2, z - 0.1, z + 0.12, 6, T["amber"], at=(x, y))
    ex, ey = EMB
    pk.disc_z(s, 0, 1.1, Z_FRONT, Z_FRONT + 0.16, 12, T["copper"], at=EMB)
    for k in range(10):
        a = math.tau * k / 10
        pk.bar_xy(s, (ex - 1.27 * math.sin(a), ey + 1.27 * math.cos(a)), a, 0.4, 0.38, Z_FRONT, Z_FRONT + 0.16, T["copper"])
    pk.disc_z(s, 0, 0.8, Z_FRONT + 0.16, Z_FRONT + 0.22, 12, T["petrol"], at=EMB)
    th = math.radians(40)
    for sx in (-1, 1):
        pk.bar_xy(s, (ex + sx * math.sin(th) * 0.5, ey + 0.3 - math.cos(th) * 0.5), -sx * th, 1.0, 0.3,
                  Z_FRONT + 0.22, Z_FRONT + 0.34, T["mint"])
    bx(s, (2.8, 0.3, 1.8), (0, Y_HDR1 + 0.45, 0), T["iron_hi"], True)
    bx(s, (1.2, 4.2, 1.0), (0, 14.8, 0), T["petrol_dk"], True)
    for sx in (-1, 1):
        pk.strut(s, (sx * 2.0, Y_HDR1 + 0.5, 0), (sx * 0.5, 14.0, 0), 0.3, 0.3, T["iron"])
    for k, y in enumerate(TREE_Y):
        pk.disc_z(s, 0, 0.55, 0.5, 0.95, 8, T["copper"], at=(0, y))
        pk.disc_z(s, 0, 0.4, 0.95, 1.15, 8, T["mint"] if k == 2 else T["amber"], at=(0, y))
        bx(s, (1.1, 0.12, 0.6), (0, y + 0.64, 1.0), T["iron"], True)
    pk.frustum(s, 0.6, 0.1, 16.9, 17.7, 8, T["copper"], at=(0, 0))
    for sx in (-1, 1):
        pk.frustum(s, 0.55, 0.55, Y_HDR1 + 0.3, Y_HDR1 + 0.8, 8, T["copper"], caps=(False, True), at=(sx * 8.0, 0))
        pk.frustum(s, 0.42, 0.18, Y_HDR1 + 0.8, Y_HDR1 + 1.35, 8, T["amber"], at=(sx * 8.0, 0))
    z0, z1 = RAIL_Z0, RAIL_Z0 - RAIL_LEN
    zc = (z0 + z1) / 2
    for sx in (-1, 1):
        bx(s, (0.26, 0.2, RAIL_LEN), (sx * 1.0, 0.1, zc), T["copper_dk"], True)
        bx(s, (0.1, 0.05, RAIL_LEN), (sx * 1.0, 0.225, zc), T["copper"], True)
    bx(s, (0.5, 0.06, RAIL_LEN), (0, 0.03, zc), T["iron_hi"], True)
    for k in range(8):
        bx(s, (3.0, 0.1, 0.4), (0, 0.05, z0 - 0.7 - 1.25 * k), cp.jitter_tone("timber", k), True)
    bx(s, (1.8, 0.3, 2.2), (0, 0.35, z0 - 2.4), T["iron"], True)
    bx(s, (1.9, 0.1, 2.3), (0, 0.55, z0 - 2.4), T["copper"], True)
    pk.disc_z(s, 0, 0.18, z0 - 3.55, z0 - 3.4, 6, T["amber"], at=(0, 0.45))
    bx(s, (3.6, 0.8, 0.5), (0, 0.4, z1 - 0.25), T["iron_hi"], True)
    bx(s, (3.8, 0.2, 0.6), (0, 0.9, z1 - 0.25), T["copper"], True)


def gate_col(s):
    pad_slab(s, T["iron"])
    for sx in (-1, 1):
        bx(s, (3.2, 0.9, 3.2), (sx * 7.4, 0.45, 0), T["iron"])
        bx(s, (PW, Y_HDR0 - 0.9, PD), (sx * PCX, 0.9 + (Y_HDR0 - 0.9) / 2, 0), T["iron"])
    bx(s, (2 * HDR_HW, HDR_H, 2 * HDR_HZ), (0, Y_HDR0 + HDR_H / 2, 0), T["iron"])


def gate_sockets():
    out = {"launch_trigger": (0.0, 1.0, 0.0), "sign": (0.0, EMB[1], Z_FRONT + 0.05)}
    for k, y in enumerate(TREE_Y):
        out["light_tree_%d" % k] = (0.0, y, 1.0)
    for k, p in enumerate(marquee_points()):
        out["light_marquee_%02d" % k] = p
    return out


def check_open(s):
    for x, y, z in s.verts:
        if abs(x) < OPEN_HALF and abs(z) < 2.0:
            assert not (0.2 < y < OPEN_TOP), ("geometry in the gate opening", (x, y, z))
        if abs(x) < OPEN_HALF and abs(z) < PAD / 2 + 0.4 and y < 3.0:
            assert y <= 0.1 + 1e-6, ("pad rises over 0.1 m", (x, y, z))


def check_gate(s):
    check_open(s)
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 1e-6 and hi[1] < 18.5, ("gate height", lo, hi)
    pad_top = max(y for x, y, z in s.verts if abs(x) < OPEN_HALF and abs(z) < PAD / 2 and y < 3.0)
    assert pad_top <= 0.1 + 1e-6, ("pad top", pad_top)


def check_gate_col(s):
    check_open(s)


def gate_detail1(s):
    for sx in (-1, 1):
        for y in (10.5, 11.8):
            for k in range(11):
                stud(s, (sx * (2.4 + 0.58 * k), y, Z_FRONT + 0.1), (0, 0, 1), 0.07, 0.05, T["copper_dk"])
        for y in (2.2, 5.2, 8.2):
            for k in range(5):
                stud(s, (sx * PCX + (k - 2) * 0.5, y, PD / 2 + 0.15), (0, 0, 1), 0.07, 0.06, T["iron_hi"])
        bx(s, (1.0, 0.85, 0.35), (sx * PCX, 1.45, PD / 2 + 0.17), T["iron_hi"])
        pk.disc_z(s, 0, 0.14, PD / 2 + 0.34, PD / 2 + 0.4, 6, T["amber"], at=(sx * PCX, 1.45))
        bx(s, (1.1, 0.08, 0.45), (sx * PCX, 1.92, PD / 2 + 0.2), T["copper_dk"])
    for sx in (-1, 1):
        pk.strut(s, (sx * PCX, 1.0, -PD / 2 - 0.1), (sx * PCX, Y_HDR1 + 0.5, -PD / 2 - 0.1), 0.14, 0.14, T["iron"])
        pk.strut(s, (sx * PCX, Y_HDR1 + 0.55, -PD / 2 - 0.1), (sx * 2.0, Y_HDR1 + 0.55, -0.2), 0.14, 0.14, T["iron"])
        pk.strut(s, (sx * 2.0, Y_HDR1 + 0.55, -0.2), (sx * 0.4, Y_HDR1 + 0.55, -0.2), 0.14, 0.14, T["iron"])
        for k in range(4):
            bx(s, (0.24, 0.24, 0.3), (sx * PCX, 1.8 + 2.0 * k, -PD / 2 - 0.1), T["iron_hi"])
    for k in range(5):
        stud(s, (-0.8 + 0.4 * k, 12.9, 0.95), (0, 0, 1), 0.07, 0.05, T["copper_dk"])
    for k in range(4):
        stud(s, (-1.4 + 0.93 * k, 0.65, RAIL_Z0 - RAIL_LEN - 0.5), (0, 0, 1), 0.08, 0.06, T["copper_dk"])
    for sx in (-1, 1):
        pk.strut(s, (sx * 0.6, 0.12, RAIL_Z0 - 0.2), (sx * 0.6, 0.12, RAIL_Z0 - 1.6), 0.1, 0.06, T["iron"])


def gate_detail2(s):
    for sx in (-1, 1):
        for dz in (-0.5, 0.5):
            pk.tube(s, (sx * (PX_IN + PW + 0.15), 1.0, dz), (sx * (PX_IN + PW + 0.15), 8.9, dz), 0.1, 0.1, 6, T["copper_dk"])
        for y in (2.2, 5.2, 8.2):
            bx(s, (0.18, 0.2, 1.4), (sx * (PX_IN + PW + 0.15), y, 0), T["copper"])
    pk.tube(s, (-8.4, 9.9, -HDR_HZ - 0.15), (8.4, 9.9, -HDR_HZ - 0.15), 0.1, 0.1, 6, T["copper_dk"])
    pk.tube(s, (-8.4, 11.9, -HDR_HZ - 0.15), (8.4, 11.9, -HDR_HZ - 0.15), 0.07, 0.07, 6, T["iron_hi"])
    for sx in (-1, 1):
        for k in range(5):
            bx(s, (0.04, 1.5, 0.03), (sx * (2.6 + 1.2 * k), 11.15, Z_FRONT + 0.115), T["iron"])
        for y in (3.7, 6.7):
            bx(s, (PW, 0.05, 0.04), (sx * PCX, y, PD / 2 + 0.05), T["iron"])
        bx(s, (0.05, 8.0, 0.04), (sx * PCX, 5.0, PD / 2 + 0.05), T["iron"])
    for x, y, z in marquee_points()[:14]:
        bx(s, (0.5, 0.05, 0.08), (x, y + 0.24, z + 0.12), T["copper"])
        bx(s, (0.5, 0.05, 0.08), (x, y - 0.24, z + 0.12), T["copper"])
    for y in TREE_Y:
        for sx in (-1, 1):
            bx(s, (0.06, 0.5, 0.5), (sx * 0.57, y, 1.0), T["iron"])
    for sx in (-1, 1):
        bx(s, (0.04, 0.012, 11.0), (sx * 4.6, PAD_TOP + 0.006, 0), T["iron_hi"], True)


ARC_R, SPACING = 30.0, 3.4
BAY_BACK, BAY_FRONT = -1.3, 1.1
DOOR_W, DOOR_ANG = 1.2, math.radians(125)
HINGE = (-1.5, 1.15)
BENCH_Z = 2.45
ROOF_PITCH = 0.16
DOOR_YAW = math.atan2(-math.sin(DOOR_ANG), math.cos(DOOR_ANG))


def bay_frame(s, k):
    th = (k - 2.5) * SPACING / ARC_R
    return Xf(s, (ARC_R * math.sin(th), 0.0, ARC_R * (1 - math.cos(th))), -th)


def door_frame(bay):
    return Xf(bay, (HINGE[0], 0.0, HINGE[1]), DOOR_YAW)


def emblem(d, shape, color, u=0.6, v=2.3):
    """The class shape, raised on the door's visible face (door-frame -Z), about 0.8 m across."""
    z0, z1 = -0.115, -0.05
    bar = lambda c, ang, ln, w: pk.bar_xy(d, c, ang, ln, w, z0, z1, color)
    if shape == "ring":
        pk.disc_z(d, 0.28, 0.45, z0, z1, 10, color, at=(u, v))
    elif shape == "chevron":
        th = math.radians(45)
        for sx in (-1, 1):
            bar((u + sx * math.sin(th) * 0.3, v - 0.1 - math.cos(th) * 0.3), -sx * th, 0.7, 0.2)
    elif shape == "burst":
        for ang in (0, 45, 90, 135):
            bar((u, v), math.radians(ang), 0.9, 0.16)
    elif shape == "cross":
        bar((u, v), 0, 0.85, 0.22)
        bar((u, v), math.pi / 2, 0.85, 0.22)
    elif shape == "square":
        for sx in (-1, 1):
            bar((u + sx * 0.33, v), 0, 0.8, 0.14)
            bar((u, v + sx * 0.33), math.pi / 2, 0.52, 0.14)
    elif shape == "lane":
        for sx in (-1, 1):
            bar((u + sx * 0.22, v), 0, 0.9, 0.16)
    else:
        raise ValueError(shape)


def bay_shell(b, k, pid, cname, shape):
    petrol = cp.jitter_tone("petrol", k, 0.04)
    for sx in (-1, 1):
        bx(b, (0.2, 4.0, BAY_FRONT - BAY_BACK), (sx * 1.5, 2.0, (BAY_FRONT + BAY_BACK) / 2), petrol, True)
        bx(b, (0.26, 3.4, 0.1), (sx * 1.5, 1.7, BAY_FRONT + 0.02), T["copper"], True)
    bx(b, (3.5, 4.0, 0.2), (0, 2.0, BAY_BACK + 0.1), petrol, True)
    bx(b, (2.8, 2.8, 0.06), (0, 1.9, BAY_BACK + 0.23), T["concrete_dk"], True)
    bx(b, (3.7, 0.2, 2.8), (0, 4.1, -0.1), T["iron_hi"], True)
    bx(b, (3.2, 0.55, 0.3), (0, 3.7, 0.95), T["petrol_dk"])
    bx(b, (3.0, 0.3, 0.06), (0, 3.7, 1.13), T[cname])
    pk.frustum(b, 0.9, 0.85, 0.0, 0.25, 8, T["iron_hi"], caps=(False, True), at=(0, -0.1))
    pk.frustum(b, 0.72, 0.72, 0.25, 0.32, 8, T["copper"], caps=(False, True), at=(0, -0.1))
    bx(b, (2.6, 0.1, 0.55), (0, 2.7, BAY_BACK + 0.5), T["timber"])
    for sx in (-1, 1):
        pk.strut(b, (sx * 1.0, 2.0, BAY_BACK + 0.2), (sx * 1.0, 2.64, BAY_BACK + 0.72), 0.1, 0.1, T["copper_dk"])
    pk.tube(b, (1.0, 3.1, BAY_BACK + 0.28), (1.0, 3.1, BAY_BACK + 0.55), 0.04, 0.04, 5, T["copper"])
    pk.tube(b, (1.0, 3.1, BAY_BACK + 0.55), (1.0, 3.3, BAY_BACK + 0.55), 0.04, 0.04, 5, T["copper"])
    d = door_frame(b)
    bx(d, (DOOR_W, 3.25, 0.1), (DOOR_W / 2, 1.775, 0), petrol)
    for u in (0.04, DOOR_W - 0.04):
        bx(d, (0.08, 3.1, 0.04), (u, 1.775, -0.07), T["copper"])
    bx(d, (DOOR_W - 0.16, 0.08, 0.04), (DOOR_W / 2, 3.2, -0.07), T["copper"])
    bx(d, (0.08, 0.35, 0.1), (DOOR_W - 0.2, 1.4, -0.1), T["copper"])
    emblem(d, shape, T[cname])
    bx(b, (2.0, 0.12, 0.5), (0, 0.55, BENCH_Z), T["timber"])
    for sx in (-1, 1):
        bx(b, (0.12, 0.5, 0.42), (sx * 0.85, 0.25, BENCH_Z), T["iron"], True)
    roof_y = lambda z: 4.75 - (z - 0.55) * math.sin(ROOF_PITCH)
    cp.obox(b, (3.7, 0.1, 3.9), (0, 4.75, 0.55), cp.jitter_tone("canvas", k, 0.08), pitch=ROOF_PITCH)
    zf = 0.55 + 1.95 * math.cos(ROOF_PITCH)
    bx(b, (3.7, 0.4, 0.06), (0, roof_y(zf) - 0.28, zf), T["canvas_dk"])
    for j in range(3):
        cp.obox(b, (0.42, 0.42, 0.05), (-1.2 + 1.2 * j, roof_y(zf) - 0.55, zf), T["canvas_dk"], roll=math.pi / 4)
    for sx in (-1, 1):
        pk.strut(b, (sx * 1.6, 4.2, 1.0), (sx * 1.6, roof_y(2.3) - 0.08, 2.3), 0.1, 0.1, T["iron"])


def lockers(s):
    for k, (pid, cname, shape) in enumerate(cp.PILOTS):
        bay_shell(bay_frame(s, k), k, pid, cname, shape)


def lockers_col(s):
    """Seven boxes (the class budget covers collision too): the back wall as two three-bay runs, the two end walls, and the
    benches as two three-bay runs. A run is one straight box in the middle bay's frame, deep enough to cover the arc's drift
    (the bays curve toward +Z by up to ~0.4 m at a run's ends), so no per-bay dividers; the cubby insides stay open."""
    def sag(half):
        return ARC_R * (1 - math.cos(half / ARC_R))
    for k in (1, 4):
        b = bay_frame(s, k)
        d = 0.2 + sag(5.15) / 2
        bx(b, (10.3, 4.0, d), (0, 2.0, BAY_BACK + d / 2), T["iron"])
        d = 0.5 + sag(4.4)
        bx(b, (8.8, 0.61, d), (0, 0.305, BENCH_Z - 0.25 + d / 2), T["iron"])
    for k, sx in ((0, -1), (5, 1)):
        bx(bay_frame(s, k), (0.2, 4.0, BAY_FRONT - BAY_BACK), (sx * 1.5, 2.0, (BAY_FRONT + BAY_BACK) / 2), T["iron"])


def lockers_sockets():
    out = {}
    for k, (pid, cname, shape) in enumerate(cp.PILOTS):
        out["locker_" + pid] = bay_frame(None, k).pt((0.0, 0.32, -0.1))
    out["interact"] = (0.0, 1.0, 3.4)
    return out


def check_lockers(s):
    lo, hi = cp.bounds(s)
    assert hi[0] - lo[0] <= 24.0 and hi[2] - lo[2] <= 6.0 and hi[1] <= 6.0 and lo[1] > -1e-6, ("lockers footprint", lo, hi)


def lockers_detail1(s):
    for k, (pid, cname, shape) in enumerate(cp.PILOTS):
        b = bay_frame(s, k)
        for j in range(3):
            bx(b, (1.4, 0.07, 0.05), (0, 3.15 + 0.17 * j, BAY_BACK + 0.28), T["iron"])
        d = door_frame(b)
        for y in (0.6, 1.8, 3.0):
            bx(d, (0.12, 0.3, 0.14), (0.02, y, -0.02), T["copper"])
        bx(d, (0.2, 0.16, 0.1), (DOOR_W - 0.2, 1.1, -0.12), T["iron_hi"])
        bx(d, (0.05, 0.1, 0.06), (DOOR_W - 0.2, 1.25, -0.12), T["copper_dk"])
        for j in range(6):
            stud(b, (-1.25 + 0.5 * j, 3.7, 1.1), (0, 0, 1), 0.06, 0.06, T["copper_dk"])


def lockers_detail2(s):
    for k, (pid, cname, shape) in enumerate(cp.PILOTS):
        b = bay_frame(s, k)
        z = BAY_BACK + 0.62
        if k == 0:
            pk.frustum(b, 0.22, 0.14, 2.65, 2.98, 8, T[cname], at=(1.0, z + 0.1))
            bx(b, (0.04, 0.4, 0.04), (1.0, 3.1, z - 0.02), T["iron"])
        elif k == 1:
            bx(b, (0.1, 0.8, 0.05), (1.0, 2.7, z - 0.1), T["iron_hi"])
            bx(b, (0.3, 0.14, 0.05), (1.0, 3.12, z - 0.1), T["iron_hi"])
        elif k == 2:
            bx(b, (0.16, 0.8, 0.05), (1.0, 2.8, z - 0.1), T["amber"])
            bx(b, (0.22, 0.1, 0.05), (1.0, 2.38, z - 0.1), T["canvas_dk"])
        elif k == 3:
            for dx in (-0.14, 0.14):
                pk.disc_z(b, 0, 0.12, z - 0.14, z - 0.06, 6, T["glass_lt"], at=(1.0 + dx, 2.92))
            bx(b, (0.5, 0.04, 0.05), (1.0, 2.92, z - 0.18), T["timber_lt"])
        elif k == 4:
            bx(b, (0.5, 0.65, 0.04), (1.0, 2.8, z - 0.1), T["ledger"])
            bx(b, (0.2, 0.08, 0.06), (1.0, 3.1, z - 0.1), T["copper"])
        else:
            bx(b, (0.08, 0.7, 0.05), (1.0, 2.75, z - 0.1), T["timber"])
            bx(b, (0.4, 0.22, 0.08), (1.0, 3.12, z - 0.1), T["iron_hi"])
        pk.tube(b, (-1.0, 3.1, BAY_BACK + 0.28), (-1.0, 3.1, BAY_BACK + 0.5), 0.04, 0.04, 5, T["copper"])
        pk.frustum(b, 0.12, 0.1, 2.75, 3.0, 6, T["oxide"], at=(-0.9, BAY_BACK + 0.8))
        cp.obox(b, (0.3, 0.3, 0.03), (-1.0, 3.7, 1.17), T["bone"], roll=math.pi / 4)
        cp.obox(b, (0.3, 0.3, 0.03), (1.0, 3.7, 1.17), T["bone"], roll=math.pi / 4 * (1 + (k % 2)))
        pk.disc_z(b, 0, 0.14, 1.12, 1.17, 6, T["copper_dk"], at=(0.0, 3.7))
        pk.disc_z(b, 0, 0.12, 1.12, 1.17, 6, T["oxide"], at=(1.55, 2.2))


def main():
    args = cp.options()
    base_g = cp.surface("camp_launch_gate", gate)
    base_l = cp.surface("camp_lockers", lockers)
    for nm, fn in (("camp_launch_gate_detail1", gate_detail1), ("camp_launch_gate_detail2", gate_detail2)):
        sh = cp.surface(nm, fn)
        check_open(sh)
        cp.inside(sh, base_g)
    for nm, fn in (("camp_lockers_detail1", lockers_detail1), ("camp_lockers_detail2", lockers_detail2)):
        cp.inside(cp.surface(nm, fn), base_l)
    cp.export("camp_launch_gate", gate, "gate", args, col=gate_col, sockets=gate_sockets(), check=check_gate)
    cp.export("camp_launch_gate_detail1", gate_detail1, "detail", args, check=check_open)
    cp.export("camp_launch_gate_detail2", gate_detail2, "detail", args, check=check_open)
    cp.export("camp_lockers", lockers, "gate", args, col=lockers_col, sockets=lockers_sockets(), check=check_lockers)
    cp.export("camp_lockers_detail1", lockers_detail1, "detail", args)
    cp.export("camp_lockers_detail2", lockers_detail2, "detail", args)


if __name__ == "__main__":
    main()
