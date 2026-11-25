"""One Splitter pod: a 113 degree sphere wedge with its snout, eye, legs and seam edges.

enemy_splitter.py welds three of these round a vertical axis into the fat ball;
enemy_splitter_piece.py builds one alone at a smaller size, so the pieces that pop out
are visibly the wedges the ball was made of. Godot metres (X,Y,Z) map to Blender (X,-Z,Y).
Azimuth 0 points along Godot -Z, the way the chaser leads; azimuths turn toward +X.
"""
import math

HALF = math.radians(56.5)
LATS = [-78, -55, -30, -8, 14, 36, 58, 78]
LONS = 5
OXIDE = "9b513a"
OXIDE_HI = "a8603f"
CHAR = "charcoal"
BONE = "bone"


def g(x, y, z):
    return (x, -z, y)


def _dir(az, lat):
    """Unit direction in Godot space: azimuth from -Z toward +X, latitude up."""
    c = math.cos(math.radians(lat))
    return (c * math.sin(az), math.sin(math.radians(lat)), -c * math.cos(az))


def _bulge(t):
    """Radius factor across the wedge (t -1..1): lobes swell so three-in-one reads."""
    return 1.0 + 0.12 * math.cos(t * math.pi / 2)


def build(body, glow, az, r, centre=(0.0, 0.0, 0.0), tally=0, legs=True, back_glow=False):
    """Adds one pod to two Parts. body takes the shell, legs and stencils (fleet_paint,
    vertex colour); glow takes the eye and seam edges (requisition_tag, lit at runtime).
    Returns the snout tip and the pod's outward unit direction, both in Godot space."""
    from mathutils import Vector

    cx, cy, cz = centre

    def at(p):
        return Vector(g(p[0] + cx, p[1] + cy, p[2] + cz))

    rows = []
    for lat in LATS:
        row = []
        for k in range(LONS + 1):
            t = -1.0 + 2.0 * k / LONS
            a = az + t * HALF
            rr = r * _bulge(t) * (0.93 if lat > 40 else 1.0)
            d = _dir(a, lat)
            row.append(body.bm.verts.new(at((d[0] * rr, d[1] * rr, d[2] * rr))))
        rows.append(row)
    spine_lo = body.bm.verts.new(at((0.0, -r * 0.98, 0.0)))
    spine_hi = body.bm.verts.new(at((0.0, r * 0.93 * 0.98, 0.0)))
    for j in range(len(rows) - 1):
        for k in range(LONS):
            f = body.bm.faces.new((rows[j][k], rows[j][k + 1], rows[j + 1][k + 1], rows[j + 1][k]))
            band = 2 <= j <= 4
            color = OXIDE_HI if band and k == 2 else OXIDE
            body.paint([f], "fleet_paint", color)
    for k in range(LONS):
        body.paint([body.bm.faces.new((rows[0][k + 1], rows[0][k], spine_lo))], "fleet_paint", CHAR)
        body.paint([body.bm.faces.new((rows[-1][k], rows[-1][k + 1], spine_hi))], "fleet_paint", OXIDE)
    for side, col in ((0, 0), (1, LONS)):
        wall = [spine_lo] + [rows[j][col] for j in range(len(rows))] + [spine_hi]
        face = body.bm.faces.new(wall if side else list(reversed(wall)))
        body.paint([face], "fleet_paint", CHAR)

    out = Vector(_dir(az, 0))
    side = Vector(_dir(az + math.pi / 2, 0))
    up = Vector((0, 1, 0))

    def surf(lat, t, lift=0.0):
        a = az + t * HALF
        rr = r * _bulge(t) * (0.93 if lat > 40 else 1.0) + lift
        d = _dir(a, lat)
        return (d[0] * rr, d[1] * rr, d[2] * rr)

    strap = [surf(-6, t, 0.03 * r) for t in (-0.92, -0.31, 0.31, 0.92)]
    for a, b in zip(strap, strap[1:]):
        body.beam("fleet_paint", at(a), at(b), 0.09 * r, 0.16 * r, color=CHAR)

    base = Vector(surf(4, 0, -0.04 * r))
    tip = base + out * (0.36 * r) + up * (-0.04 * r)
    body.rod("fleet_paint", at(base), at(tip), 0.15 * r, segs=6, color=CHAR, r2=0.04 * r)
    eye = Vector(surf(24, 0, 0.0))
    glow.beam("requisition_tag", at(eye - side * 0.17 * r), at(eye + side * 0.17 * r),
              0.08 * r, 0.11 * r, roll=0.0)

    for i in range(tally):
        t = (i - (tally - 1) / 2) * 0.16
        dt = 0.035
        quad = [surf(42, t - dt, 0.014 * r), surf(42, t + dt, 0.014 * r),
                surf(56, t + dt, 0.014 * r), surf(56, t - dt, 0.014 * r)]
        face = body.bm.faces.new([body.bm.verts.new(at(q)) for q in quad])
        body.paint([face], "fleet_paint", BONE)

    if back_glow:
        for t in (-1.0, 1.0):
            pts = [surf(lat, t, 0.015 * r) for lat in (-60, -20, 20, 60)]
            for a, b in zip(pts, pts[1:]):
                glow.beam("requisition_tag", at(a), at(b), 0.07 * r, 0.05 * r)

    if legs:
        for t in (-0.55, 0.55):
            hip = Vector(surf(-48, t, -0.05 * r))
            d = Vector(_dir(az + t * HALF, 0))
            knee = hip + d * (0.4 * r) + up * (-0.08 * r)
            foot = Vector((knee.x, -1.225 * r, knee.z))
            body.rod("fleet_paint", at(hip), at(knee), 0.09 * r, segs=4, color=CHAR)
            body.rod("fleet_paint", at(knee), at(foot), 0.06 * r, segs=4, color=CHAR, r2=0.13 * r)

    return tip, out
