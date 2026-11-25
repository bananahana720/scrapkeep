"""Headless recipe for the camp pet: camp_pet.glb, camp_pet_pen.glb and the three toys camp_toy_ball.glb, camp_toy_wrench.glb,
camp_toy_tire.glb (camp kit, _camp.py header).

camp_pet: Andrew's pick, a retired Fleet worker drone that Moss rewired as a camp pet ("Pet. One. Unpaid."). A small, friendly,
slightly dented machine about 1.3 m tall, built like a scruffy dog from the Fleet design language (rounded barrel body, cone ears,
oxide plates, charcoal, a brass requisition tag) but made soft: a rounded dark-iron body with chipped Fleet-oxide paint, one big
round warm lamp eye (glass_lt lens in a copper bezel, never mint), a smile slot, a copper collar with the brass tag hanging off
it, an antenna "tail" with a bolt on its tip, four stubby legs, and Moss's repairs: a riveted copper patch band round the belly
and a bone bandage wrap on the front-right leg. One ear is bent and the head sits a little off true: the dent.
Origin on the ground under its centre, facing +Z. "Left" is the pet's own left, which is +X when it faces +Z. Class enemy, one
draw, no collision. Sockets: head, eye, tail, mouth (where it carries a toy), paw_fl, paw_fr, paw_bl, paw_br (the paws' ground
contacts, for footstep dust). The body is one welded mesh, so these mark points; they do not move parts.

camp_pet_pen: the pet's yard, a low ring fence of 9 m radius with a 9 m gap facing +Z (the plaza side), a kennel made from a cut
oil drum with a little copper roof (entrance facing +Z), a food bowl full of bolts, a toy-bin crate and a worn patch of dirt.
Origin at the pen's centre on the ground, +Z toward the plaza. Class detail. Collision: the fence as eight chord boxes round
the ring (gap left open) and the kennel as a box. Sockets: kennel (entrance, ball height), bowl, toy_bin, pet_home (where the pet idles, on the dirt patch).

camp_toy_ball (a 0.6 m striped felt ball), camp_toy_wrench (a chunky squeaky wrench lying flat) and camp_toy_tire (a small tyre
ring lying flat): pet toys the player can bump. Origin at each toy's centre of mass (so y is symmetric about 0). Class prop each,
one draw. Collision: one box each (the ball's is its bounding cube; the runtime may use a SphereShape3D radius 0.3 instead), kept to a box
because the class budget covers the collision mesh too.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/pet.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk


def ell(s, c, r, color, nu=10, nv=6):
    """A closed ellipsoid centred at c with radii r = (rx, ry, rz): nu around, nv latitude bands."""
    cx, cy, cz = c
    rx, ry, rz = r
    verts = [(cx, cy - ry, cz)]
    for j in range(1, nv):
        th = -math.pi / 2 + math.pi * j / nv
        for i in range(nu):
            ph = math.tau * i / nu
            verts.append((cx + rx * math.cos(th) * math.cos(ph), cy + ry * math.sin(th), cz + rz * math.cos(th) * math.sin(ph)))
    verts.append((cx, cy + ry, cz))
    top = len(verts) - 1
    faces = [(0, 1 + (i + 1) % nu, 1 + i) for i in range(nu)]
    for j in range(nv - 2):
        b = 1 + j * nu
        for i in range(nu):
            k = (i + 1) % nu
            faces.append((b + i, b + k, b + nu + k, b + nu + i))
    b = 1 + (nv - 2) * nu
    faces += [(top, b + i, b + (i + 1) % nu) for i in range(nu)]
    s.add(verts, faces, color)


def surf(c, r, d):
    m = math.sqrt(sum(v * v for v in d))
    return tuple(c[k] + r[k] * d[k] / m for k in range(3))


def patch(s, c, r, d, size, color, nu=5):
    """A flat chip of paint or a plate stuck on an ellipsoid's surface in direction d."""
    p = surf(c, r, d)
    ax = max(range(3), key=lambda k: abs(d[k]))
    rad = [size, size, size]
    rad[ax] = 0.035
    q = list(p)
    q[ax] -= 0.012 * (1 if d[ax] > 0 else -1)
    ell(s, tuple(q), tuple(rad), color, nu, 3)


def belt(s, c, r, z, half, grow, color, n=10):
    """A closed ring round an ellipsoid-bodied animal at height-axis z (the long axis), grown grow metres proud."""
    k = math.sqrt(max(0.0, 1.0 - ((z - c[2]) / r[2]) ** 2))
    quad = [(0.97, z - half), (1.0 + grow, z - half), (1.0 + grow, z + half), (0.97, z + half)]
    verts = [(c[0] + r[0] * k * f * math.cos(math.tau * i / n), c[1] + r[1] * k * f * math.sin(math.tau * i / n), zz)
             for i in range(n) for f, zz in quad]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for q in range(4):
            m = (q + 1) % 4
            faces.append((i * 4 + q, i * 4 + m, j * 4 + m, j * 4 + q))
    s.add(verts, faces, color)


BODY_C, BODY_R = (0.0, 0.62, -0.05), (0.43, 0.32, 0.5)
HEAD_C, HEAD_R = (0.03, 0.92, 0.34), (0.38, 0.36, 0.36)
LEGS = {"fl": (0.24, 0.3), "fr": (-0.24, 0.3), "bl": (0.24, -0.34), "br": (-0.24, -0.34)}
TAIL = [(0.0, 0.8, -0.5), (0.0, 0.93, -0.74), (0.04, 1.14, -0.8), (0.0, 1.3, -0.72)]
EYE = (0.03, 0.95, 0.77)
MOUTH = (0.03, 0.66, 0.66)


def pet(s):
    ell(s, BODY_C, BODY_R, "iron", 10, 6)
    ell(s, HEAD_C, HEAD_R, "iron_hi", 10, 6)
    for k, (x, z) in sorted(LEGS.items()):
        pk.frustum(s, 0.1, 0.12, 0.07, 0.44, 6, T["iron"], at=(x, z))
        pk.frustum(s, 0.15, 0.13, 0.0, 0.09, 6, T["charcoal"], at=(x, z))
    ex, ey, ez = EYE
    pk.disc_z(s, 0, 0.27, ez - 0.25, ez - 0.07, 10, T["copper"], at=(ex, ey))
    pk.disc_z(s, 0, 0.21, ez - 0.25, ez - 0.04, 10, T["ledger"], at=(ex, ey))
    pk.disc_z(s, 0, 0.14, ez - 0.25, ez - 0.01, 10, T["glass_lt"], at=(ex, ey))
    mx, my, mz = MOUTH
    for dx, dy, roll in ((-0.09, -0.015, 0.35), (0.0, -0.035, 0.0), (0.09, -0.015, -0.35)):
        cp.obox(s, (0.1, 0.03, 0.04), (mx + dx, my + dy + 0.03, mz - 0.03), T["charcoal"], roll=roll)
    for sx in (-1, 1):
        pk.hexstud(s, (HEAD_C[0] + sx * 0.33, 0.9, 0.3), (sx, 0, 0), 0.04, 0.04, T["copper_dk"])
    pk.tube(s, (0.3, 1.1, 0.26), (0.44, 1.28, 0.2), 0.11, 0.05, 6, T["oxide"])
    pk.tube(s, (-0.24, 1.14, 0.26), (-0.46, 1.2, 0.18), 0.11, 0.05, 6, T["oxide"])
    pk.disc_z(s, 0.3, 0.38, 0.2, 0.3, 10, T["copper_dk"], at=(0.0, 0.78))
    pk.tube(s, (0.0, 0.47, 0.3), (0.0, 0.44, 0.38), 0.025, 0.025, 4, T["copper"])
    s.box((0.17, 0.21, 0.03), (0.0, 0.34, 0.4), T["brass"])
    s.box((0.05, 0.05, 0.03), (0.0, 0.31, 0.42), T["iron"])
    for a, b in zip(TAIL, TAIL[1:]):
        pk.tube(s, a, b, 0.035, 0.03, 6, T["iron_hi"])
    pk.hexstud(s, TAIL[-1], (0, 0.5, 0.2), 0.09, 0.1, T["copper"])
    patch(s, BODY_C, BODY_R, (0.5, 1.0, -0.4), 0.17, "oxide")
    patch(s, BODY_C, BODY_R, (-1.0, 0.2, 0.3), 0.14, "oxide")
    patch(s, HEAD_C, HEAD_R, (-1.0, 0.6, -0.1), 0.12, "oxide")
    patch(s, BODY_C, BODY_R, (0.9, 0.2, 0.5), 0.07, "concrete_lt")
    patch(s, BODY_C, BODY_R, (-0.2, 1.0, 0.7), 0.06, "concrete_lt")
    belt(s, BODY_C, BODY_R, -0.2, 0.1, 0.07, T["copper"])
    for i in range(4):
        a = math.tau * (i + 0.5) / 4 + 0.3
        pk.hexstud(s, (BODY_R[0] * 1.07 * math.cos(a), BODY_C[1] + BODY_R[1] * 1.07 * math.sin(a), -0.2), (math.cos(a), math.sin(a), 0), 0.035, 0.03, T["copper_dk"])
    x, z = LEGS["fr"]
    for k, y in enumerate((0.16, 0.25, 0.34)):
        pk.frustum(s, 0.135, 0.135, y, y + 0.075, 6, T["bone"] if k % 2 == 0 else T["ledger"], at=(x, z))


def pet_sockets():
    out = {"head": HEAD_C, "eye": EYE, "tail": TAIL[0], "mouth": MOUTH}
    for k, (x, z) in sorted(LEGS.items()):
        out["paw_" + k] = (x, 0.0, z)
    return out


def check_pet(s):
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 0.01 and 1.25 < hi[1] < 1.45, ("pet height", lo, hi)
    assert hi[2] > 0.7 and lo[2] > -0.95 and hi[0] < 0.75 and lo[0] > -0.75, ("pet footprint", lo, hi)


PEN_R = 9.0
POST_ANGLES = [a for a in range(-180, 180, 15) if abs(a) > 20]
KENNEL = (-3.5, -5.5)
BOWL = (3.4, -4.4)
BIN = (-6.0, -1.5)
HOME = (1.2, -1.8)


def pen_pt(a, r=PEN_R):
    a = math.radians(a)
    return (r * math.sin(a), r * math.cos(a))


def fence(s, col=False):
    for a in POST_ANGLES:
        x, z = pen_pt(a)
        if col:
            s.box((0.35, 1.0, 0.35), (x, 0.5, z), T["timber"])
        else:
            s.box((0.26, 1.0, 0.26), (x, 0.5, z), T["timber"])
    for a in POST_ANGLES:
        nxt = -180 if a + 15 == 180 else a + 15
        if nxt not in POST_ANGLES:
            continue
        (x0, z0), (x1, z1) = pen_pt(a), pen_pt(a + 15)
        mid = math.radians(a + 7.5)
        ln = math.hypot(x1 - x0, z1 - z0)
        if col:
            cp.obox(s, (ln, 0.6, 0.12), ((x0 + x1) / 2, 0.55, (z0 + z1) / 2), T["timber"], yaw=mid)
        else:
            cp.obox(s, (ln, 0.3, 0.08), ((x0 + x1) / 2, 0.62, (z0 + z1) / 2), T["timber_lt"], yaw=mid)


def kennel_box(s):
    s.box((1.9, 2.0, 2.0), (KENNEL[0], 1.0, KENNEL[1]), T["iron"])


def pen(s):
    fence(s)
    kx, kz = KENNEL
    pk.tube(s, (kx, 0.85, kz - 0.9), (kx, 0.85, kz + 0.9), 0.85, 0.85, 12, T["oxide"])
    for dz in (-0.6, 0.0, 0.6):
        pk.tube(s, (kx, 0.85, kz + dz - 0.04), (kx, 0.85, kz + dz + 0.04), 0.88, 0.88, 12, T["iron_hi"])
    pk.disc_z(s, 0, 0.5, kz + 0.9, kz + 0.94, 12, T["charcoal"], at=(kx, 0.62))
    s.box((1.0, 0.62, 0.04), (kx, 0.31, kz + 0.92), T["charcoal"])
    pk.disc_z(s, 0.5, 0.6, kz + 0.9, kz + 0.96, 12, T["iron_hi"], at=(kx, 0.62))
    for sx in (-1, 1):
        cp.obox(s, (0.95, 0.07, 2.3), (kx + sx * 0.62, 1.93, kz + 0.05), T["copper"], roll=-sx * math.radians(30))
    s.box((0.12, 0.14, 2.35), (kx, 2.22, kz + 0.05), T["copper_dk"])
    bx, bz = BOWL
    pk.frustum(s, 0.34, 0.5, 0.0, 0.26, 12, T["copper"], at=(bx, bz))
    pk.frustum(s, 0.5, 0.52, 0.26, 0.31, 12, T["copper_dk"], at=(bx, bz))
    for k, (dx, dz, dy) in enumerate(((0, 0, 0.42), (0.2, 0.1, 0.36), (-0.18, 0.12, 0.35), (0.1, -0.2, 0.35),
                                       (-0.15, -0.14, 0.36), (0.28, -0.1, 0.33), (-0.3, 0.0, 0.33))):
        cp.pk.hexstud(s, (bx + dx, 0.26, bz + dz), (0.3 * (k % 3 - 1), 1, 0.2 * (k % 2 - 0.5)), 0.07, dy - 0.2, T["iron_hi"] if k % 2 else T["concrete_lt"])
    tx, tz = BIN
    s.box((1.3, 0.1, 0.9), (tx, 0.05, tz), T["timber"])
    for sx in (-1, 1):
        s.box((0.1, 0.7, 0.9), (tx + sx * 0.6, 0.35, tz), T["timber"])
    for sz in (-1, 1):
        s.box((1.3, 0.7, 0.1), (tx, 0.35, tz + sz * 0.4), T["timber_lt"])
    s.box((1.36, 0.06, 0.06), (tx, 0.72, tz + 0.4), T["copper_dk"])
    ell(s, (tx - 0.2, 0.62, tz - 0.05), (0.26, 0.26, 0.26), "petrol", 8, 4)
    cp.obox(s, (0.7, 0.1, 0.14), (tx + 0.25, 0.78, tz - 0.05), T["copper"], yaw=0.5, roll=0.4)
    hx, hz = HOME
    cp.disc_y(s, 0, 3.0, 0.0, 0.02, 14, T["plaza_dk"], at=(hx, hz))
    cp.disc_y(s, 0, 2.0, 0.02, 0.035, 12, T["varnish"], at=(hx, hz))
    for dx, dz in ((-0.8, 0.4), (0.9, -0.5), (0.2, 0.9)):
        cp.disc_y(s, 0, 0.22, 0.035, 0.045, 6, T["plaza_dk"], at=(hx + dx, hz + dz))
    cp.obox(s, (0.5, 0.1, 0.14), (hx - 1.3, 0.08, hz - 0.6), T["bone"], yaw=0.7)


def pen_sockets():
    return {"kennel": (KENNEL[0], 1.0, KENNEL[1] + 1.8), "bowl": (BOWL[0], 0.3, BOWL[1]), "toy_bin": (BIN[0], 0.7, BIN[1]),
            "pet_home": (HOME[0], 0.0, HOME[1])}


def pen_col(s):
    n, lo, hi = 8, 30.0, 330.0
    step = math.radians((hi - lo) / n)
    half = step / 2
    sag = PEN_R * (1 - math.cos(half))
    for i in range(n):
        mid = math.radians(lo) + step * (i + 0.5)
        ln = 2 * PEN_R * math.sin(half) + 0.35
        rc = PEN_R * math.cos(half) + sag / 2
        cp.obox(s, (ln, 1.0, 0.35 + sag), (rc * math.sin(mid), 0.5, rc * math.cos(mid)), T["timber"], yaw=mid)
    kennel_box(s)


def check_pen(s):
    lo, hi = cp.bounds(s)
    assert max(hi[0], -lo[0], hi[2], -lo[2]) < PEN_R + 0.4 and -PEN_R - 0.4 < lo[2], ("pen extent", lo, hi)
    assert all(abs(a) > 20 for a in POST_ANGLES), "the gap faces +Z"
    assert 2 * PEN_R * math.sin(math.radians(15)) > 4.0, "the gap must clear the ball"


BALL_R = 0.3
BALL_COLS = ["petrol", "canvas", "petrol", "canvas", "petrol", "canvas", "petrol"]


def lathe(s, radius, angles, colors, n):
    for k in range(len(angles) - 1):
        a0, a1 = angles[k], angles[k + 1]
        pk.frustum(s, radius * math.cos(a0), radius * math.cos(a1), radius * math.sin(a0), radius * math.sin(a1), n, T[colors[k]])


def ball(s):
    lathe(s, BALL_R, [math.radians(-75 + 150 * i / 7) for i in range(8)], BALL_COLS, 8)
    pk.hexstud(s, (0.0, BALL_R * 0.9, 0.0), (0, 1, 0), 0.03, 0.04, T["copper_dk"])


def ball_col(s):
    s.box((2 * BALL_R, 2 * BALL_R, 2 * BALL_R), (0.0, 0.0, 0.0), T["iron"])


def wrench(s):
    s.box((0.46, 0.14, 0.15), (-0.04, 0.0, 0.0), T["copper"])
    s.box((0.1, 0.14, 0.34), (0.27, 0.0, 0.0), T["copper"])
    for sz in (-1, 1):
        s.box((0.18, 0.14, 0.11), (0.4, 0.0, sz * 0.115), T["copper"])
    ell(s, (-0.34, 0.0, 0.0), (0.12, 0.1, 0.1), "ledger", 8, 4)
    pk.tube(s, (-0.27, 0.0, 0.0), (-0.22, 0.0, 0.0), 0.085, 0.085, 8, T["copper_dk"])
    for x in (-0.12, 0.08):
        pk.hexstud(s, (x, 0.07, 0.0), (0, 1, 0), 0.04, 0.03, T["copper_dk"])
    s.box((0.4, 0.03, 0.05), (-0.04, 0.08, 0.0), T["copper_dk"])


def wrench_col(s):
    s.box((0.92, 0.14, 0.34), (0.0, 0.0, 0.0), T["iron"])


TIRE_R, TIRE_T = 0.36, 0.15


def tire(s):
    prof = [(1.0, 0.0), (0.5, 0.87), (-0.5, 0.87), (-1.0, 0.0), (-0.5, -0.87), (0.5, -0.87)]
    n = 12
    verts = [(math.sin(math.tau * i / n) * (TIRE_R + TIRE_T * pr), TIRE_T * py, math.cos(math.tau * i / n) * (TIRE_R + TIRE_T * pr))
             for i in range(n) for pr, py in prof]
    m = len(prof)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for q in range(m):
            r = (q + 1) % m
            faces.append((i * m + q, i * m + r, j * m + r, j * m + q))
    s.add(verts, faces, T["charcoal"])
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        cp.obox(s, (0.07, 0.04, 0.2), (math.sin(a) * TIRE_R, TIRE_T * 0.87, math.cos(a) * TIRE_R), T["iron_hi"], yaw=a)
    s.box((0.05, 0.05, 0.05), (TIRE_R + TIRE_T * 0.9, 0.05, 0.0), T["copper"])


def tire_col(s):
    s.box((1.0, 2 * TIRE_T, 1.0), (0.0, 0.0, 0.0), T["iron"])


def main():
    args = cp.options()
    cp.export("camp_pet", pet, "enemy", args, sockets=pet_sockets(), check=check_pet)
    cp.export("camp_pet_pen", pen, "detail", args, col=pen_col, sockets=pen_sockets(), check=check_pen)
    cp.export("camp_toy_ball", ball, "prop", args, col=ball_col)
    cp.export("camp_toy_wrench", wrench, "prop", args, col=wrench_col)
    cp.export("camp_toy_tire", tire, "prop", args, col=tire_col)


if __name__ == "__main__":
    main()
