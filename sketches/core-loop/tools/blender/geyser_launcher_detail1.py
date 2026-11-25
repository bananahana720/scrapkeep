"""Detail layer 1 for the geyser launcher: an additive steel shell at the base's origin, authored from gap list A
(artifacts/local/alpha/push/w12/units/rc-geyser_launcher/gaps_A.md): block rivets, top-course bolts and joints, the
grate's rim lip, the nozzle's bolted flange and neck band, rubber-bush post collars, cap lips, spout fittings and the
pipe's threaded tip. The footprint fix (low stone well, geyser_launcher.py `clearance`) applies to this shell too. Switchback Enclaves habit: the posts sit in charcoal rubber bushes and the grate is held by
exposed service bolts. Class "detail" (1500 tris, 3000 verts, 1 draw). Colours are TONES rows of
geyser_launcher.py; no state key is painted here.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/geyser_launcher_detail1.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import geyser_launcher as g
import polish
from geyser_launcher import kit, frustum, polar, tone

DETAIL = [2000, 3300, 1]
SIZE = [6.749, 1.161, 6.749]


def frame(n):
    nx, ny, nz = n
    a = (0.0, 1.0, 0.0) if abs(ny) < .9 else (1.0, 0.0, 0.0)
    u = (a[1] * nz - a[2] * ny, a[2] * nx - a[0] * nz, a[0] * ny - a[1] * nx)
    lu = math.sqrt(sum(c * c for c in u))
    u = tuple(c / lu for c in u)
    v = (ny * u[2] - nz * u[1], nz * u[0] - nx * u[2], nx * u[1] - ny * u[0])
    return u, v


def bolt(s, c, n, r, h, color, k=6):
    u, v = frame(n)
    ring = []
    for d in (0.0, h):
        for i in range(k):
            a = math.tau * i / k
            ring.append(tuple(c[j] + n[j] * d + r * (math.cos(a) * u[j] + math.sin(a) * v[j]) for j in range(3)))
    faces = [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)] + [tuple(range(k, 2 * k))]
    s.add(ring, faces, color)


def plate(s, c, n, up, half_w, half_h, t, color):
    side = (up[1] * n[2] - up[2] * n[1], up[2] * n[0] - up[0] * n[2], up[0] * n[1] - up[1] * n[0])
    v = []
    for d in (0.0, t):
        for ku, ks in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
            v.append(tuple(c[j] + n[j] * d + up[j] * ku * half_h + side[j] * ks * half_w for j in range(3)))
    s.add(v, [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], color)


def radial(a):
    return (math.sin(a), 0.0, math.cos(a))


def build(s):
    dark, copper = tone("grate"), tone("copper")
    n, ro, ri, y0, y1, gap = g.BLOCKS
    for i in range(n):
        a = math.tau * (i + .5) / n
        d = ro * math.cos(math.pi / n)
        bolt(s, polar(d, a, (y0 + y1) / 2), radial(a), .07, .05, dark)
    sn, sro, sy0, sy1 = g.SLAB
    for i in range(12):
        bolt(s, polar(3.18, math.tau * (i + .25) / 12, sy1), (0, 1, 0), .1, .05, dark)
    for i in range(0, sn, 2):
        a = math.tau * i / sn
        d = sro * math.cos(math.pi / sn)
        plate(s, polar(d, a, (sy0 + sy1) / 2), radial(a), (0, 1, 0), .035, (sy1 - sy0) / 2, .02, dark)
    gy0, gy1 = g.GRATE_Y
    frustum(s, g.R_TORUS_IN + .02, g.R_TORUS_IN - .04, gy1 - .02, gy1 + .07, 16, dark, caps=(False, False))
    frustum(s, g.R_TORUS_IN - .04, g.R_TORUS_IN - .1, gy1 + .07, gy1 + .07, 16, dark, caps=(False, False))
    for i in range(8):
        bolt(s, polar(2.8, math.tau * (i + .5) / 8, gy1), (0, 1, 0), .08, .05, dark)
    fr, fy = g.NOZZLE[1]
    for i in range(8):
        bolt(s, polar(fr - .12, math.tau * i / 8, fy), (0, 1, 0), .07, .05, copper)
    frustum(s, .72, .72, -.8, -.75, 8, dark, caps=(False, False))
    pr, py0, _ = g.POST
    cr, _, cy1 = g.CAP
    for deg in g.POSTS:
        a = math.radians(deg)
        x, _, z = polar(g.POST_R, a, 0)
        frustum(s, pr + .08, pr + .05, py0, py0 + .14, 8, dark, caps=(False, True), at=(x, z))
        frustum(s, cr + .04, cr + .04, cy1 - .08, cy1, 8, copper, caps=(True, True), at=(x, z))
        t = (math.cos(a), 0.0, -math.sin(a))
        end = pr - .04 + g.SPOUT[0] - .02
        bolt(s, (x + t[0] * end, g.SPOUT[2], z + t[2] * end), t, .13, .08, copper)
    plen, pside, py = g.PIPE
    bolt(s, (0.0, py, g.NOZZLE[2][0] - .05 + plen - .02), (0, 0, 1), .08, .1, copper)
    bolt(s, (0.0, py, g.NOZZLE[2][0] - .05 + plen + .08), (0, 0, 1), .04, .08, tone("pipe"))


def main():
    polish.enable(bevel=.02, bevel_min=.25, **g.kit.BAKE)
    g.export(g.NAME + "_detail1", "Detail1", "steel", build, SIZE, {}, g.out_dir(), budget=DETAIL, tag="GEYSER_D1")


if __name__ == "__main__":
    main()
