"""Headless recipe for camp_plaza.glb and camp_shortcut.glb: the hub ring's floor and its two-second shortcut (camp kit,
_camp.py header).

camp_plaza: the 26 m plaza you wake on, a 48 m ring walk the stations sit on, and one spoke out to each station, all
packed caliche slabs 8 cm proud of the ground with chamfered edges a ball rolls over without a bump. The spawn medallion
at the centre is copper-rimmed with a mint chevron pointing at the launch gate (bearing 0, -Z), so the first frame of
every visit says which way the run is. Each spoke ends in a mint threshold bar on the ring, the "you can use this" read.
Origin at the plaza centre on the ground; the layout places it at the world origin with yaw 0. Class park_large.
Collision: the slab tops and chamfers (flat, so the ball's rolling feel is the ground's).
Sockets: spawn (where the ball wakes, facing -Z) and station_<id> on the ring where each spoke meets it.

camp_shortcut: the mint ramp on the gate spoke. A kicker 6 m wide and 18 m long rising to 3 m that throws a cruising ball
over the spoke so it lands at the gate in about two seconds. Origin at the ramp's centre on the ground (the foot is 9 m toward +Z, the lip 9 m toward -Z); +Z faces the
plaza, so the ball runs up it toward -Z. Class detail. Collision: the deck and the cheeks.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/plaza.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp
import layout as L

T = cp.T
SLAB = 0.08
CHAMFER = 0.5
RAMP_W, RAMP_L, RAMP_H = 6.0, 18.0, 3.0


def spokes():
    """(id, bearing, inner, outer) for every spoke: from the plaza rim to the ring walk, the gate's to the gate pad."""
    out = []
    for sid, (bearing, r) in sorted(L.STATIONS.items()):
        outer = r - (6.0 if sid == "gate" else 0.0)
        out.append((sid, bearing, L.PLAZA_R - 0.5, outer))
    return out


def spoke_segments():
    """(bearing, r0, r1) of every spoke slab: each ends at the ring walk's inner edge (the gate's crosses the ring, so it is
    two slabs, one each side of the walk) so no slab overlaps the walk coplanar."""
    out = []
    for sid, bearing, r0, r1 in spokes():
        if sid == "gate":
            out += [(bearing, r0, L.RING_R - 3.0), (bearing, L.RING_R + 3.0, r1)]
        else:
            out.append((bearing, r0, L.RING_R - 3.0))
    return out


def slab_strip(s, bearing, r0, r1, w, y, color):
    """A closed flat slab along a bearing from radius r0 to r1, w wide, top at y, with chamfered long sides."""
    b = math.radians(bearing)
    d = (math.sin(b), -math.cos(b))
    n = (math.cos(b), math.sin(b))
    pts = []
    for r in (r0, r1):
        cx, cz = d[0] * r, d[1] * r
        for off, h in ((-w / 2 - CHAMFER, 0.0), (-w / 2, y), (w / 2, y), (w / 2 + CHAMFER, 0.0)):
            pts.append((cx + n[0] * off, h, cz + n[1] * off))
    s.add(pts, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (0, 1, 2, 3), (4, 5, 6, 7), (0, 3, 7, 4)], color)


def floor(s, solid=False):
    cp.pk.frustum(s, L.PLAZA_R + CHAMFER, L.PLAZA_R, 0.0, SLAB, 48, T["plaza"])
    cp.pk.ring_y(s, L.RING_R - 3.0, L.RING_R + 3.0, 0.0, SLAB, 96, T["plaza"])
    for bearing, r0, r1 in spoke_segments():
        slab_strip(s, bearing, r0, r1, L.SPOKE_W, SLAB - 0.004, T["plaza"])


def plaza(s):
    floor(s)
    for k, r in enumerate((9.0, 17.0, 24.5)):
        cp.disc_y(s, r - 0.35, r + 0.35, SLAB, SLAB + 0.012, 48, cp.jitter_tone("plaza_dk", k))
    for k in range(12):
        a = math.tau * (k + 0.5) / 12
        cp.obox(s, (0.3, 0.012, 15.0), (math.sin(a) * 16.5, SLAB + 0.006, -math.cos(a) * 16.5), T["plaza_dk"], yaw=-a)
    cp.disc_y(s, 0.0, 4.2, SLAB, SLAB + 0.05, 32, T["copper"])
    cp.disc_y(s, 0.0, 3.7, SLAB + 0.05, SLAB + 0.07, 32, T["petrol"])
    for k in range(8):
        a = math.tau * k / 8
        cp.obox(s, (0.25, 0.03, 1.1), (math.sin(a) * 3.15, SLAB + 0.08, -math.cos(a) * 3.15), T["bone"], yaw=-a)
    chevron = [(-1.4, 0.4), (0.0, -1.0), (1.4, 0.4), (1.4, 1.2), (0.0, -0.2), (-1.4, 1.2)]
    for dz in (-1.2, 0.6):
        pts = [(x, SLAB + 0.09, z + dz) for x, z in chevron]
        s.add(pts, [tuple(range(len(pts)))[::-1]], T["mint"])
    for sid, bearing, r0, r1 in spokes():
        b = math.radians(bearing)
        r = r1 - 1.0
        cp.obox(s, (L.SPOKE_W - 0.4, 0.03, 0.6), (math.sin(b) * r, SLAB + 0.015, -math.cos(b) * r), T["mint"], yaw=-b)
    for k in range(48):
        a = math.tau * k / 48
        r = L.RING_R + 3.0 - 0.3
        cp.pk.hexstud(s, (math.sin(a) * r, SLAB, -math.cos(a) * r), (0, 1, 0), 0.18, 0.05, T["copper_dk"])


def plaza_sockets():
    out = {"spawn": (0.0, 1.0, 0.0)}
    for sid, bearing, r0, r1 in spokes():
        b = math.radians(bearing)
        out["station_" + sid] = (math.sin(b) * r1, SLAB, -math.cos(b) * r1)
    return out


def check_plaza(s):
    lo, hi = cp.bounds(s)
    assert hi[1] < 0.2 and lo[1] > -0.01, ("plaza must stay a flat floor", lo, hi)
    assert hi[2] <= 0.0 + L.RING_R + 3.6 and lo[2] >= -(L.GATE_R + 0.1), ("plaza extent", lo, hi)


def ramp_profile(t):
    """Deck height along the ramp, t in 0..1 from the foot (+Z end) to the lip: a smooth kicker curve."""
    return RAMP_H * (t * t * (1.5 - 0.5 * t))


def solid_profile(s, x0, x1, rows, color, sink=0.0):
    """One closed solid between x0 and x1 under a side profile: bottom at y = 0, top at the (z, y) rows (y may be 0 at the
    first row, where the section is a point). Shared vertices, so it is one manifold shell."""
    n = len(rows)
    pts = []
    for z, y in rows:
        pts += [(x0, y - sink, z), (x1, y - sink, z)]
    base = len(pts)
    for z, y in rows:
        pts += [(x0, 0.0, z), (x1, 0.0, z)]
    faces = []
    for i in range(n - 1):
        a0, a1, b0, b1 = 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3
        faces += [(a0, b0, b1, a1)]
        c0, c1, d0, d1 = base + a0, base + a1, base + b0, base + b1
        faces += [(c0, c1, d1, d0)]
        faces += [(a0, c0, d0, b0), (a1, b1, d1, c1)]
    faces += [(base, base + 1, 1, 0), (2 * n - 2, 2 * n - 1, base + 2 * n - 1, base + 2 * n - 2)]
    s.add(pts, faces, color)


def shortcut(s):
    n = 12
    hw = RAMP_W / 2
    rows = []
    for i in range(n + 1):
        t = i / n
        rows.append((RAMP_L / 2 - t * RAMP_L, ramp_profile(t)))
    solid_profile(s, -hw, hw, rows, T["mint_dk"])
    for sx in (-1, 1):
        a, b = sorted((sx * (hw - 0.1), sx * (hw + 0.6)))
        solid_profile(s, a, b, rows, T["iron"], sink=0.0)
    for i in range(n):
        (z0, y0), (z1, y1) = rows[i], rows[i + 1]
        col = T["mint"] if i % 2 == 0 else T["mint_dk"]
        pts = [(x, max(y + dy, 0.0), z) for dy in (-0.05, 0.02) for (z, y) in ((z0, y0), (z1, y1)) for x in (-hw + 0.02, hw - 0.02)]
        s.add(pts, [(0, 1, 3, 2)[::-1], (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)], col)
    zl, yl = rows[-1]
    cp.obox(s, (RAMP_W + 1.2, yl, 0.6), (0, yl / 2, zl + 0.3), T["iron"])
    cp.obox(s, (RAMP_W + 1.4, 0.2, 0.8), (0, yl + 0.05, zl + 0.4), T["copper"])
    chevron = [(-1.3, 0.5), (0.0, -0.8), (1.3, 0.5), (1.3, 1.2), (0.0, -0.1), (-1.3, 1.2)]
    for k in range(3):
        zc = RAMP_L / 2 - (0.22 + 0.24 * k) * RAMP_L
        top = [(x, ramp_profile((RAMP_L / 2 - (z + zc)) / RAMP_L) + 0.06, z + zc) for x, z in chevron]
        bot = [(x, y - 0.03, z) for x, y, z in top]
        m = len(chevron)
        faces = [tuple(range(m)), tuple(range(2 * m - 1, m - 1, -1))]
        faces += [(i, (i + 1) % m, (i + 1) % m + m, i + m) for i in range(m)]
        s.add(top + bot, faces, T["amber"])
    for k, (z, y) in enumerate(rows[2::3]):
        for sx in (-1, 1):
            cp.pk.hexstud(s, (sx * (hw + 0.6), max(y - 0.3, 0.2), z), (sx, 0, 0), 0.08, 0.06, T["copper_dk"])


def shortcut_col(s):
    n = 12
    hw = RAMP_W / 2 + 0.6
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        z0, z1 = RAMP_L / 2 - t0 * RAMP_L, RAMP_L / 2 - t1 * RAMP_L
        y0, y1 = ramp_profile(t0), ramp_profile(t1)
        pts = [(-hw, y0, z0), (hw, y0, z0), (hw, y1, z1), (-hw, y1, z1), (-hw, 0, z0), (hw, 0, z0), (hw, 0, z1), (-hw, 0, z1)]
        s.add(pts, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 4, 7, 3), (1, 2, 6, 5), (0, 1, 5, 4), (2, 3, 7, 6)], T["iron"])


def check_shortcut(s):
    lo, hi = cp.bounds(s)
    assert abs(lo[1]) < 1e-6 and RAMP_H - 0.1 < hi[1] < RAMP_H + 0.4, ("ramp height", lo, hi)
    assert hi[2] <= RAMP_L / 2 + 0.01 and lo[2] >= -RAMP_L / 2 - 0.7, ("ramp length", lo, hi)


def main():
    args = cp.options()
    cp.export("camp_plaza", plaza, "park_large", args, col=floor, sockets=plaza_sockets(), check=check_plaza)
    cp.export("camp_shortcut", shortcut, "detail", args, col=shortcut_col,
              sockets={"lip": (0.0, RAMP_H, -RAMP_L / 2)}, check=check_shortcut)


if __name__ == "__main__":
    main()
