"""Headless recipe for camp_trophy_wall.glb and camp_settings_console.glb: the Achievements and Settings stations
(camp kit, _camp.py header).

camp_trophy_wall: the Achievements station. A 12 m wide, 6 m tall copper-framed trophy board (y 1.0 to 6.0) between two
iron legs on concrete footings, a petrol-dark header band under a short canvas awning, a cog-and-laurel wreath crest on
top (no text) and two goosenecked lamps over the board. The face holds one dim bone plaque tile per achievement row:
src/core/achievements.gd ROWS has 61 rows (counted from the table, one `"id": {` line each), laid out 11 columns by 6
rows left-to-right, top-to-bottom, with 6 plaques in the last row. Two shelf ledges hold trophies: one across the board
between the third and fourth plaque rows (cups, a ball, a harpoon tip) and one in the empty right end of the last row.
Plaques are dim on purpose; the runtime lights earned ones. Origin on the ground at the footprint centre, +Z faces the
plaza. Class gate (2700 tris). Collision: both legs and the board slab (three boxes; the footings are drawn only).
Sockets: plaque_00..plaque_60 (centre of each plaque face, in table order), board (face centre), interact (front centre,
ball height), light_0 and light_1 (the two lamp bulbs).

camp_settings_console: the Settings station, a field radio switchboard. A dark iron and petrol cabinet (4 m wide, a ball
high) with a sloped dial deck, a bank of dials, one big chunky mint knob (the thing you turn), a front of slider slots,
toggle rows and a patch bay with a few cables, a speaker grille, a telegraph key on a side shelf, a tall antenna mast
with a small dish and a tip lamp, and a crate stool in front. Origin on the ground at the cabinet centre, +Z faces the
plaza; the mast stands at the back left. Class detail. Collision: the cabinet box (feet to deck).
Sockets: interact (in front, ball height) and light_0 (the antenna tip bulb, which the runtime blinks).

Both are ball-scaled, so the cabinet and the board are bigger than a person-scaled prop would be.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/stations.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk
ROWS = 61
COLS = 11
PITCH_X, PITCH_Y = 1.02, 0.56
PLAQUE = (0.88, 0.44, 0.07)
ROW_Y = [4.88, 4.32, 3.76, 2.67, 2.11, 1.55]
FACE_Z = 0.22
LEG_X = 6.35


def lh(s, x0, x1, y0, y1, z0, z1, color):
    s.box((x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color)


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


def cup(s, x, y, z, k, color="copper", k2=1.0):
    lh(s, x - 0.14, x + 0.14, y, y + 0.05, z - 0.1, z + 0.1, "iron_hi")
    pk.tube(s, (x, y + 0.05, z), (x, y + 0.2 * k2, z), 0.035, 0.035, 4, T["copper_dk"])
    pk.frustum(s, 0.06, 0.15, y + 0.2 * k2, y + 0.46 * k2, 8, T[color], caps=(True, True), at=(x, z))
    lh(s, x - 0.17, x + 0.17, y + 0.34 * k2, y + 0.39 * k2, z - 0.025, z + 0.025, T["copper_dk"])


def ball(s, x, y, z):
    lh(s, x - 0.14, x + 0.14, y, y + 0.05, z - 0.12, z + 0.12, "iron_hi")
    lathe(s, [(0.0, y + 0.05), (0.09, y + 0.05), (0.17, y + 0.14), (0.17, y + 0.27), (0.09, y + 0.36), (0.0, y + 0.36)], 5,
          T["concrete_lt"], at=(x, z))
    pk.frustum(s, 0.175, 0.175, y + 0.19, y + 0.22, 5, T["copper"], at=(x, z))


def harpoon(s, x, y, z):
    lh(s, x - 0.14, x + 0.14, y, y + 0.05, z - 0.1, z + 0.1, "iron_hi")
    pk.tube(s, (x, y + 0.05, z), (x, y + 0.3, z), 0.03, 0.03, 4, T["timber_lt"])
    lathe(s, [(0.0, y + 0.3), (0.1, y + 0.3), (0.0, y + 0.52)], 4, T["iron_hi"], at=(x, z))
    for sx in (-1, 1):
        cp.obox(s, (0.035, 0.14, 0.035), (x + sx * 0.08, y + 0.26, z), T["copper"], roll=sx * 0.5)


def laurel(s, cx, cy, z):
    """A cog medallion ringed by a half wreath of leaves; faces +Z."""
    pk.disc_z(s, 0.0, 0.3, z, z + 0.12, 12, T["copper_dk"], at=(cx, cy))
    pk.disc_z(s, 0.0, 0.18, z + 0.12, z + 0.16, 8, T["iron"], at=(cx, cy))
    for i in range(8):
        a = math.tau * i / 8
        cp.obox(s, (0.12, 0.13, 0.12), (cx + 0.38 * math.sin(a), cy + 0.38 * math.cos(a), z + 0.06), T["copper"], roll=-a)
    for sx in (-1, 1):
        for i in range(4):
            a = math.radians(200 + i * 30) * sx
            r = 0.75
            cp.obox(s, (0.12, 0.3, 0.05), (cx + r * math.sin(a), cy + r * math.cos(a), z + 0.04),
                    T["felt"] if i % 2 else T["copper_dk"], roll=-a - sx * 0.5)


def gooseneck(s, x):
    pts = [(x, 6.0, 0.0), (x, 6.95, 0.0), (x, 7.2, 0.45), (x, 7.05, 1.45)]
    for a, b in zip(pts, pts[1:]):
        pk.tube(s, a, b, 0.045, 0.045, 4, T["iron_hi"])
    lh(s, x - 0.18, x + 0.18, 5.98, 6.04, -0.18, 0.18, "iron_hi")
    pk.frustum(s, 0.1, 0.3, 6.78, 7.05, 8, T["copper"], at=(x, 1.5))
    cp.lamp(s, x, 6.76, 1.5, 0.13)


def trophy_wall(s):
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (LEG_X - 0.3), sx * (LEG_X + 0.3)))
        lh(s, sx * LEG_X - 0.7, sx * LEG_X + 0.7, 0.0, 0.45, -0.9, 0.9, "concrete")
        lh(s, sx * LEG_X - 0.7, sx * LEG_X + 0.7, 0.4, 0.47, -0.9, 0.9, "concrete_dk")
        lh(s, x0, x1, 0.45, 6.5, -0.4, 0.4, "iron")
        lh(s, x0 - 0.04, x1 + 0.04, 6.5, 6.62, -0.44, 0.44, "copper")
        lh(s, x0 - 0.04, x1 + 0.04, 0.8, 0.9, -0.44, 0.44, "copper_dk")
        pk.strut(s, (sx * LEG_X, 0.6, 0.45), (sx * 4.9, 1.0, 0.1), 0.2, 0.2, T["iron_hi"])
        pk.strut(s, (sx * LEG_X, 4.5, -0.4), (sx * LEG_X, 0.45, -2.0), 0.28, 0.28, T["iron_hi"])
    lh(s, -6.0, 6.0, 1.0, 6.0, -0.25, 0.15, "petrol_dk")
    for y0, y1 in ((1.0, 1.18), (5.2, 5.28), (5.9, 6.0)):
        lh(s, -6.05, 6.05, y0, y1, -0.25, 0.27, "copper")
    for sx in (-1, 1):
        lh(s, sx * 6.05 - 0.1 if sx < 0 else 5.95, 6.05 if sx > 0 else -5.95, 1.0, 6.0, -0.25, 0.27, "copper")
    lh(s, -5.9, 5.9, 5.28, 5.9, 0.15, 0.2, "petrol")
    for i in range(6):
        lh(s, -5.0 + i * 2.0 - 0.07, -5.0 + i * 2.0 + 0.07, 5.5, 5.64, 0.2, 0.26, "copper_dk")
    for k in range(ROWS):
        r, c = divmod(k, COLS)
        x = (c - 5) * PITCH_X
        y = ROW_Y[r]
        s.box(PLAQUE, (x, y, 0.15 + PLAQUE[2] / 2), cp.jitter_tone("b3a98f", k, 0.1))
    lh(s, -5.9, 5.9, 2.85, 2.95, 0.15, 0.55, "timber")
    lh(s, -5.9, 5.9, 2.85, 2.92, 0.55, 0.6, "copper_dk")
    lh(s, 0.4, 5.9, 1.2, 1.3, 0.15, 0.55, "timber")
    lh(s, 0.4, 5.9, 1.2, 1.27, 0.55, 0.6, "copper_dk")
    cup(s, -5.3, 2.95, 0.35, 1)
    ball(s, -4.0, 2.95, 0.35)
    harpoon(s, -2.7, 2.95, 0.35)
    cup(s, -1.3, 2.95, 0.35, 1, "copper_dk", 0.9)
    cup(s, 0.3, 2.95, 0.35, 1, "copper", 1.1)
    harpoon(s, 1.8, 2.95, 0.35)
    ball(s, 3.2, 2.95, 0.35)
    cup(s, 4.6, 2.95, 0.35, 1, "copper_dk")
    cup(s, 1.1, 1.3, 0.35, 1, "copper", 0.95)
    ball(s, 2.3, 1.3, 0.35)
    harpoon(s, 3.5, 1.3, 0.35)
    cup(s, 4.7, 1.3, 0.35, 1, "copper_dk", 0.9)
    pitch = math.atan2(0.43, 1.1)
    for i in range(8):
        cx = -6.2 + 1.55 * (i + 0.5)
        col = T["canvas"] if i % 2 == 0 else T["canvas_dk"]
        cp.obox(s, (1.55, 0.05, 1.2), (cx, 5.83, 0.82), col, pitch=pitch)
        cp.obox(s, (1.55, 0.2, 0.05), (cx, 5.6, 1.4), col, pitch=0.0)
    for sx in (-1, 1):
        pk.strut(s, (sx * 6.1, 5.95, 0.2), (sx * 6.1, 5.55, 1.4), 0.1, 0.1, T["iron_hi"])
    pk.disc_z(s, 0.0, 0.92, -0.14, -0.02, 10, T["petrol_dk"], at=(0.0, 6.9))
    lh(s, -0.3, 0.3, 5.98, 6.3, -0.14, 0.0, "iron_hi")
    laurel(s, 0.0, 6.9, -0.05)
    gooseneck(s, -3.9)
    gooseneck(s, 3.9)


def wall_sockets():
    out = {}
    for k in range(ROWS):
        r, c = divmod(k, COLS)
        out["plaque_%02d" % k] = ((c - 5) * PITCH_X, ROW_Y[r], FACE_Z)
    out["board"] = (0.0, 3.5, FACE_Z)
    out["interact"] = (0.0, 1.0, 3.0)
    out["light_0"] = (-3.9, 6.76, 1.5)
    out["light_1"] = (3.9, 6.76, 1.5)
    return out


def wall_col(s):
    for sx in (-1, 1):
        lh(s, sx * LEG_X - 0.3, sx * LEG_X + 0.3, 0.0, 6.6, -0.4, 0.4, "iron")
    lh(s, -6.0, 6.0, 1.0, 6.0, -0.25, 0.3, "iron")


def check_wall(s):
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 1e-6 and 7.0 < hi[1] < 8.0, ("wall height", lo, hi)
    assert hi[0] - lo[0] > 12.0, ("wall width", lo, hi)


DECK_FRONT_Y, DECK_BACK_Y = 1.9, 2.6
CAB_X, CAB_Z = 2.0, 0.7


def deck_y(z):
    return DECK_FRONT_Y + (CAB_Z - z) * (DECK_BACK_Y - DECK_FRONT_Y) / (2 * CAB_Z)


NORMAL = (0.0, 0.894, 0.447)


def on_deck(x, z, off=0.0):
    return (x, deck_y(z) + off * NORMAL[1], z + off * NORMAL[2])


def knob(s, x, z, r, h, color, n=8, off=0.0):
    a = on_deck(x, z, off)
    b = tuple(a[i] + NORMAL[i] * h for i in range(3))
    pk.tube(s, a, b, r, r * 0.92, n, T[color], caps=(False, True))


def dial(s, x, z, k):
    knob(s, x, z, 0.2, 0.05, "copper_dk", 8)
    knob(s, x, z, 0.15, 0.09, "bone", 8)
    a = on_deck(x, z, 0.09)
    ang = (-0.9 + 0.45 * k)
    p = (a[0] + math.sin(ang) * 0.06, a[1] + 0.03, a[2] - math.cos(ang) * 0.06 * 0.45)
    cp.obox(s, (0.03, 0.03, 0.12), p, T["iron"], yaw=ang)


def console(s):
    for sx in (-1, 1):
        for sz in (-1, 1):
            lh(s, sx * 1.75 - 0.2, sx * 1.75 + 0.2, 0.0, 0.25, sz * 0.5 - 0.2, sz * 0.5 + 0.2, "iron_hi")
    lh(s, -CAB_X, CAB_X, 0.25, DECK_FRONT_Y, -CAB_Z, CAB_Z, "iron")
    pts = [(-CAB_X, DECK_FRONT_Y, -CAB_Z), (CAB_X, DECK_FRONT_Y, -CAB_Z), (CAB_X, DECK_FRONT_Y, CAB_Z), (-CAB_X, DECK_FRONT_Y, CAB_Z),
           (-CAB_X, DECK_BACK_Y, -CAB_Z), (CAB_X, DECK_BACK_Y, -CAB_Z), (CAB_X, DECK_FRONT_Y, CAB_Z), (-CAB_X, DECK_FRONT_Y, CAB_Z)]
    s.add(pts, [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], T["petrol"])
    lh(s, -CAB_X - 0.04, CAB_X + 0.04, 0.25, 0.4, -CAB_Z - 0.04, CAB_Z + 0.04, "copper_dk")
    lh(s, -CAB_X - 0.04, CAB_X + 0.04, DECK_FRONT_Y - 0.1, DECK_FRONT_Y, CAB_Z - 0.02, CAB_Z + 0.06, "copper")
    lh(s, -1.9, -0.95, 0.55, 1.75, CAB_Z, CAB_Z + 0.05, "iron_hi")
    for i in range(6):
        lh(s, -1.82, -1.03, 0.65 + i * 0.18, 0.74 + i * 0.18, CAB_Z + 0.05, CAB_Z + 0.09, "charcoal")
    lh(s, -0.8, 0.45, 1.05, 1.75, CAB_Z, CAB_Z + 0.04, "copper_dk")
    jacks = []
    for r in range(2):
        for c in range(5):
            x, y = -0.6 + c * 0.25, 1.62 - r * 0.28
            jacks.append((x, y))
            pk.tube(s, (x, y, CAB_Z + 0.04), (x, y, CAB_Z + 0.11), 0.075, 0.075, 6, T["iron"], caps=(False, True))
    for (x0, y0), (x1, y1), col in ((jacks[0], jacks[8], "oxide"), (jacks[2], jacks[5], "canvas_dk"), (jacks[4], jacks[7], "petrol")):
        pk.tube(s, (x0, y0, CAB_Z + 0.11), (x0, y0, CAB_Z + 0.22), 0.05, 0.05, 6, T["bone"], caps=(False, True))
        pk.tube(s, (x1, y1, CAB_Z + 0.11), (x1, y1, CAB_Z + 0.22), 0.05, 0.05, 6, T["bone"], caps=(False, True))
        mid = ((x0 + x1) / 2 + 0.05, min(y0, y1) - 0.25, CAB_Z + 0.3)
        pts = [(x0, y0, CAB_Z + 0.22), mid, (x1, y1, CAB_Z + 0.22)]
        for a, b in zip(pts, pts[1:]):
            pk.strut(s, a, b, 0.045, 0.045, T[col])
    lh(s, -0.8, 0.45, 0.5, 0.9, CAB_Z, CAB_Z + 0.04, "iron_hi")
    for c in range(5):
        x = -0.65 + c * 0.28
        up = 1 if c in (0, 2, 3) else -1
        pk.tube(s, (x, 0.7, CAB_Z + 0.04), (x, 0.7 + up * 0.12, CAB_Z + 0.18), 0.035, 0.05, 4, T["bone"] if up > 0 else T["concrete_lt"], caps=(False, True))
    lh(s, 0.75, 1.9, 0.55, 1.75, CAB_Z, CAB_Z + 0.03, "iron_hi")
    for i, h in enumerate((0.3, 0.75, 0.5, 0.9)):
        x = 0.95 + i * 0.28
        lh(s, x - 0.04, x + 0.04, 0.7, 1.6, CAB_Z + 0.03, CAB_Z + 0.05, "charcoal")
        lh(s, x - 0.11, x + 0.11, 0.7 + h * 0.8 - 0.06, 0.7 + h * 0.8 + 0.06, CAB_Z + 0.05, CAB_Z + 0.12, "copper" if i != 1 else "bone")
    for i, x in enumerate((-1.55, -0.85)):
        dial(s, x, 0.15, i)
    for i, x in enumerate((-1.55, -0.85)):
        kz = -0.35
        a = on_deck(x, kz)
        pk.tube(s, a, tuple(a[j] + NORMAL[j] * 0.06 for j in range(3)), 0.28, 0.28, 8, T["iron"], caps=(False, True))
        knob(s, x, kz, 0.2, 0.08, "ledger", 8)
        ang = 0.5 - i * 0.7
        c = on_deck(x, kz, 0.08)
        cp.obox(s, (0.03, 0.03, 0.2), (c[0] + math.sin(ang) * 0.08, c[1] + 0.02, c[2] - 0.04), T["iron"], yaw=ang)
    bx, bz = 0.95, 0.0
    knob(s, bx, bz, 0.6, 0.06, "iron_hi", 12)
    for i in range(7):
        a = math.radians(-120 + i * 40)
        c = on_deck(bx + 0.52 * math.sin(a), bz - 0.52 * math.cos(a) * 0.9, 0.07)
        cp.obox(s, (0.05, 0.03, 0.1), c, T["bone"], yaw=a)
    knob(s, bx, bz, 0.42, 0.14, "mint_dk", 10, off=0.06)
    knob(s, bx, bz, 0.36, 0.28, "mint", 10, off=0.06)
    c = on_deck(bx + 0.1, bz - 0.12, 0.34)
    cp.obox(s, (0.07, 0.04, 0.28), c, T["iron"], yaw=0.5)
    lh(s, 2.05, 3.1, 1.05, 1.15, -0.45, 0.55, "timber")
    for z in (-0.35, 0.45):
        lh(s, 2.1, 2.2, 0.25, 1.05, z - 0.04, z + 0.04, "iron_hi")
    lh(s, 2.2, 2.8, 1.15, 1.22, -0.1, 0.4, "iron")
    pk.strut(s, (2.5, 1.3, 0.35), (2.5, 1.38, -0.05), 0.07, 0.04, T["copper"])
    pk.tube(s, (2.5, 1.38, 0.35), (2.5, 1.5, 0.35), 0.1, 0.09, 6, T["bone"], caps=(False, True))
    lh(s, 2.45, 2.55, 1.22, 1.3, -0.06, 0.02, "iron_hi")
    mx, mz = -2.6, -0.8
    pk.tube(s, (mx, 0.0, mz), (mx, 8.0, mz), 0.13, 0.08, 6, T["iron_hi"], caps=(False, True))
    lh(s, mx - 0.4, mx + 0.4, 0.0, 0.2, mz - 0.4, mz + 0.4, "concrete")
    for y in (2.5, 5.0):
        lh(s, mx - 0.5, mx + 0.5, y, y + 0.07, mz - 0.03, mz + 0.03, "copper")
    for ax, az in ((-2.2, -2.2), (0.6, -2.4), (-3.4, 1.4)):
        pk.strut(s, (mx, 5.0, mz), (mx + ax, 0.1, mz + az), 0.04, 0.04, T["iron"])
    dy = (mx, 6.2, mz + 0.1)
    d = (0.0, 0.34, 0.94)
    back = dy
    rim = tuple(back[i] + d[i] * 0.3 for i in range(3))
    pk.tube(s, back, rim, 0.05, 0.6, 8, T["copper_dk"], caps=(False, True))
    face = tuple(rim[i] + d[i] * 0.01 for i in range(3))
    pk.tube(s, face, tuple(face[i] + d[i] * 0.02 for i in range(3)), 0.5, 0.5, 8, T["concrete_lt"], caps=(True, True))
    horn = tuple(rim[i] + d[i] * 0.35 for i in range(3))
    pk.tube(s, rim, horn, 0.03, 0.07, 6, T["iron"], caps=(False, True))
    cp.lamp(s, mx, 8.2, mz, 0.15)
    pk.tube(s, (mx, 8.0, mz), (mx, 8.12, mz), 0.08, 0.1, 6, T["copper"], caps=(False, True))
    sx, sz = 0.1, 2.0
    lh(s, sx - 0.45, sx + 0.45, 0.0, 0.8, sz - 0.4, sz + 0.4, "timber")
    for ox in (-0.45, 0.45):
        for oz in (-0.4, 0.4):
            lh(s, sx + ox - 0.05, sx + ox + 0.05, 0.0, 0.8, sz + oz - 0.05, sz + oz + 0.05, "timber_lt")
    lh(s, sx - 0.5, sx + 0.5, 0.8, 0.87, sz - 0.45, sz + 0.45, "timber_lt")
    lh(s, sx - 0.3, sx + 0.3, 0.3, 0.5, sz + 0.4, sz + 0.43, "timber_lt")


def console_col(s):
    lh(s, -CAB_X, CAB_X, 0.0, DECK_BACK_Y, -CAB_Z, CAB_Z, "iron")


def check_console(s):
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 1e-6 and 8.0 < hi[1] < 8.6, ("console height", lo, hi)


def main():
    args = cp.options()
    cp.export("camp_trophy_wall", trophy_wall, "gate", args, col=wall_col, sockets=wall_sockets(), check=check_wall)
    cp.export("camp_settings_console", console, "detail", args, col=console_col,
              sockets={"interact": (0.0, 1.0, 3.2), "light_0": (-2.6, 8.2, -0.8)}, check=check_console)


if __name__ == "__main__":
    main()
