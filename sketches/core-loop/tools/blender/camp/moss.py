"""Headless recipe for camp_moss_stall.glb (+ _detail1, _detail2): Moss's station on the hub ring (camp kit, _camp.py header).

Moss is the provisioner who packs what you forgot, so the stall is a salvage counter that has a spare of everything: a long
timber-topped workbench under a corrugated canopy on four iron posts, a pegboard back wall hung with tool silhouettes, a row
of parts bins, crates stacked high at one end (every crate is "the spare"), and a small jib crane over a companion bench where
the SPIL-9 hover chassis is assembled between runs. The shipped jukebox (moss_jukebox_cabinet.glb) stands at the `jukebox`
socket beside the counter; the runtime places it.

Origin on the ground at the counter's front centre line; +Z faces the plaza, so the player rolls up to the counter front.
Footprint about 14 x 9 m with the rug, canopy top about 6 m. Class gate (2,700 tris) for the base; detail shells are class detail.
Collision: the counter, the back wall, the crate stack and the posts (boxes). Sockets: interact (counter front, y 1.0),
moss (behind the counter, where Moss stands), companion_bench (the bench top), jukebox (ground spot for the cabinet),
light_0..2 (the canopy lamps).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/moss.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
W = 12.0
BACK_Z = -5.0
COUNTER_Z = -1.0
CANOPY_Y = 5.4
LAMPS = [(-4.0, 4.7, -1.4), (0.0, 4.7, -1.4), (4.0, 4.7, -1.4)]
BENCH = (5.0, 1.0, -3.2)


def counter(s):
    cp.obox(s, (8.4, 1.0, 1.4), (-1.4, 0.5, COUNTER_Z), T["timber"])
    cp.obox(s, (8.8, 0.14, 1.7), (-1.4, 1.07, COUNTER_Z), T["timber_lt"])
    cp.obox(s, (8.86, 0.12, 0.08), (-1.4, 1.07, COUNTER_Z + 0.86), T["copper"])
    for k in range(6):
        cp.obox(s, (1.34, 0.86, 0.06), (-5.0 + k * 1.44, 0.5, COUNTER_Z + 0.73), cp.jitter_tone("timber", k, 0.12))
    cp.obox(s, (0.9, 0.5, 0.6), (-4.6, 1.39, COUNTER_Z - 0.2), T["iron"])
    cp.pk.tube(s, (-4.12, 1.45, COUNTER_Z - 0.2), (-3.85, 1.45, COUNTER_Z - 0.2), 0.05, 0.05, 6, T["copper"])
    cp.obox(s, (1.0, 0.06, 0.7), (-2.6, 1.17, COUNTER_Z - 0.1), T["ledger"], yaw=0.12)
    cp.obox(s, (0.04, 0.07, 0.66), (-2.6, 1.18, COUNTER_Z - 0.1), T["charcoal"], yaw=0.12)
    cp.pk.frustum(s, 0.32, 0.22, 1.14, 1.6, 10, T["copper"], at=(1.6, COUNTER_Z - 0.2))
    cp.pk.frustum(s, 0.08, 0.05, 1.6, 1.72, 8, T["iron"], at=(1.6, COUNTER_Z - 0.2))
    cp.pk.tube(s, (1.88, 1.35, COUNTER_Z - 0.2), (2.2, 1.6, COUNTER_Z - 0.2), 0.07, 0.04, 6, T["copper"])
    cp.pk.frustum(s, 0.12, 0.12, 1.14, 1.36, 8, T["bone"], at=(2.4, COUNTER_Z + 0.25))


def back_wall(s):
    cp.obox(s, (W, 3.6, 0.3), (0, 1.8, BACK_Z), T["petrol"])
    cp.obox(s, (W - 0.6, 2.4, 0.06), (-0.0, 2.3, BACK_Z + 0.18), T["canvas_dk"])
    for k, x in enumerate((-4.8, -3.6, -2.4)):
        cp.obox(s, (0.18, 1.1 - 0.15 * k, 0.05), (x, 2.4, BACK_Z + 0.24), T["iron_hi"])
        cp.pk.disc_z(s, 0.12, 0.26, BACK_Z + 0.22, BACK_Z + 0.27, 8, T["iron_hi"], at=(x, 2.95 - 0.07 * k))
    cp.obox(s, (1.6, 0.5, 0.05), (-0.6, 3.0, BACK_Z + 0.24), T["iron_hi"], roll=0.08)
    cp.pk.disc_z(s, 0.35, 0.55, BACK_Z + 0.22, BACK_Z + 0.32, 12, T["copper"], at=(1.6, 2.6))
    for cx, r in ((3.5, -0.43), (4.1, 0.43)):
        cp.obox(s, (0.3, 1.43, 0.05), (cx, 2.65, BACK_Z + 0.24), T["copper"], roll=r)
    for k in range(5):
        x = -5.0 + k * 1.5
        cp.obox(s, (1.3, 0.8, 1.0), (x, 0.4, BACK_Z + 0.75), T["iron"])
        cp.obox(s, (1.1, 0.12, 0.8), (x, 0.82, BACK_Z + 0.75), cp.jitter_tone("oxide", k, 0.18))


def crates(s):
    stack = [((-6.4, 0.0, -2.4), 1.6, 0.1), ((-6.4, 1.6, -2.5), 1.5, -0.12), ((-6.3, 3.1, -2.4), 1.3, 0.2),
             ((-6.5, 0.0, -0.4), 1.4, -0.06), ((-6.4, 1.4, -0.5), 1.2, 0.15)]
    for k, ((x, y, z), size, yaw) in enumerate(stack):
        cp.obox(s, (size, size, size), (x, y + size / 2, z), cp.jitter_tone("timber_lt", k, 0.14), yaw=yaw)
        cp.obox(s, (size + 0.04, 0.14, size + 0.04), (x, y + size * 0.82, z), T["iron"], yaw=yaw)
    cp.obox(s, (0.4, 0.26, 0.04), (-6.4, 0.9, -1.58), T["brass"], yaw=0.1)


def canopy(s):
    for x in (-W / 2, W / 2):
        for z in (0.6, BACK_Z + 0.1):
            cp.pk.frustum(s, 0.16, 0.16, 0.0, CANOPY_Y, 8, T["iron"], at=(x, z))
            cp.pk.frustum(s, 0.24, 0.24, 0.0, 0.4, 8, T["concrete"], at=(x, z))
    n = 9
    for k in range(n):
        x0 = -W / 2 - 0.4 + k * (W + 0.8) / n
        x1 = x0 + (W + 0.8) / n + 0.03
        col = cp.jitter_tone("copper" if k % 3 else "oxide", k, 0.1)
        up = 0.015 * (k % 2)
        top = [(x0, CANOPY_Y + 0.6 + up, BACK_Z - 0.4), (x1, CANOPY_Y + 0.6 + up, BACK_Z - 0.4),
               (x1, CANOPY_Y - 0.2 + up, 1.4), (x0, CANOPY_Y - 0.2 + up, 1.4)]
        s.add(top + [(x, y - 0.06, z) for x, y, z in top],
              [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], col)
    slope = math.atan2(0.8, 1.4 - (BACK_Z - 0.4))
    run = math.hypot(0.8, 1.4 - (BACK_Z - 0.4))
    for k in range(18):
        x = -W / 2 + 0.1 + k * (W - 0.2) / 17
        cp.obox(s, (0.12, 0.08, run), (x, CANOPY_Y + 0.24, (1.4 + BACK_Z - 0.4) / 2), T["copper_dk"], pitch=slope)
    sy = CANOPY_Y - 1.15
    for x in (-0.5, 0.5):
        cp.pk.tube(s, (x, CANOPY_Y - 0.3, 1.4), (x, sy + 0.5, 1.4), 0.03, 0.03, 4, T["iron_hi"])
    cp.pk.disc_z(s, 0.0, 0.62, 1.34, 1.46, 12, T["petrol"], at=(0.0, sy))
    for k in range(10):
        a = math.tau * k / 10
        cp.obox(s, (0.24, 0.2, 0.12), (0.7 * math.sin(a), sy + 0.7 * math.cos(a), 1.4), T["petrol"], roll=-a)
    cp.obox(s, (0.18, 0.95, 0.06), (0.0, sy, 1.49), T["bone"], roll=0.75)
    cp.pk.disc_z(s, 0.1, 0.24, 1.46, 1.52, 8, T["bone"], at=(0.33, sy + 0.33))
    cp.obox(s, (W + 1.0, 0.25, 0.25), (0, CANOPY_Y - 0.2, 1.4), T["iron"])
    cp.obox(s, (W + 1.0, 0.25, 0.25), (0, CANOPY_Y + 0.55, BACK_Z - 0.4), T["iron"])
    for x, y, z in LAMPS:
        cp.pk.tube(s, (x, CANOPY_Y - 0.05, z), (x, y + 0.35, z), 0.03, 0.03, 4, T["iron"])
        cp.pk.frustum(s, 0.45, 0.12, y + 0.05, y + 0.4, 10, T["copper"], at=(x, z))
        cp.lamp(s, x, y, z, 0.18)


def companion_bench(s):
    x, y, z = BENCH
    cp.obox(s, (2.6, 0.12, 1.6), (x, y - 0.06, z), T["iron_hi"])
    for dx in (-1.1, 1.1):
        for dz in (-0.65, 0.65):
            cp.obox(s, (0.12, y - 0.12, 0.12), (x + dx, (y - 0.12) / 2, z + dz), T["iron"])
    cp.pk.frustum(s, 0.14, 0.14, 0.0, 4.2, 8, T["petrol"], at=(x + 1.3, z - 1.0))
    cp.pk.strut(s, (x + 1.3, 4.1, z - 1.0), (x - 0.6, 4.1, z + 0.2), 0.22, 0.28, T["petrol"])
    cp.pk.strut(s, (x + 1.3, 3.2, z - 1.0), (x + 0.2, 4.0, z - 0.3), 0.12, 0.12, T["petrol"])
    cp.pk.tube(s, (x - 0.5, 4.0, z + 0.15), (x - 0.5, 2.2, z + 0.15), 0.025, 0.025, 4, T["iron_hi"])
    cp.pk.tube(s, (x - 0.5, 2.2, z + 0.15), (x - 0.35, 1.95, z + 0.15), 0.07, 0.04, 6, T["copper"])
    cp.pk.ring_y(s, 0.45, 0.62, y + 0.35, y + 0.5, 14, T["copper"], at=(x, z))
    cp.pk.frustum(s, 0.12, 0.12, y, y + 0.35, 6, T["iron"], at=(x, z))


def base(s):
    counter(s)
    back_wall(s)
    crates(s)
    canopy(s)
    companion_bench(s)
    cp.obox(s, (7.0, 0.03, 2.8), (-1.4, 0.015, 1.6), T["oxide"])
    cp.obox(s, (7.1, 0.025, 0.2), (-1.4, 0.018, 3.0), T["mint"])


def col(s):
    cp.obox(s, (8.8, 1.13, 1.7), (-1.4, 0.565, COUNTER_Z), T["iron"])
    cp.obox(s, (W, 3.6, 0.6), (0, 1.8, BACK_Z), T["iron"])
    cp.obox(s, (1.8, 4.5, 3.6), (-6.4, 2.25, -1.5), T["iron"])
    cp.obox(s, (2.6, 1.0, 1.6), (BENCH[0], 0.5, BENCH[2]), T["iron"])
    for x in (-W / 2, W / 2):
        for z in (0.6, BACK_Z + 0.1):
            cp.obox(s, (0.4, CANOPY_Y, 0.4), (x, CANOPY_Y / 2, z), T["iron"])


def detail1(s):
    for x in (-W / 2, W / 2):
        for z in (0.6, BACK_Z + 0.1):
            for y in (0.9, 2.2, 3.5, 4.8):
                cp.pk.frustum(s, 0.2, 0.2, y, y + 0.08, 8, T["copper_dk"], at=(x, z))
    for k in range(9):
        x = -5.6 + k * 1.4
        cp.pk.hexstud(s, (x, 3.45, BACK_Z + 0.16), (0, 0, 1), 0.06, 0.05, T["copper_dk"])
        cp.pk.hexstud(s, (x, 0.15, BACK_Z + 0.16), (0, 0, 1), 0.06, 0.05, T["copper_dk"])
    cp.pk.tube(s, (-5.8, 3.75, BACK_Z + 0.25), (5.8, 3.75, BACK_Z + 0.25), 0.09, 0.09, 6, T["copper"])
    cp.pk.tube(s, (5.8, 3.75, BACK_Z + 0.25), (5.8, 0.3, BACK_Z + 0.25), 0.09, 0.09, 6, T["copper"])
    for x in (-5.2, -1.4, 2.4):
        cp.obox(s, (0.1, 0.5, 0.5), (x, 0.82, COUNTER_Z + 0.55), T["iron_hi"])


def detail2(s):
    for k in range(7):
        a = k * 0.9
        cp.pk.hexstud(s, (-0.6 + 0.25 * math.cos(a), 1.14, COUNTER_Z - 0.3 + 0.22 * math.sin(a)), (0, 1, 0), 0.05, 0.05,
                      T["iron_hi"])
    cp.pk.disc_z(s, 0.0, 0.24, COUNTER_Z + 0.2, COUNTER_Z + 0.32, 10, T["bone"], at=(0.4, 1.38))
    cp.pk.disc_z(s, 0.24, 0.3, COUNTER_Z + 0.18, COUNTER_Z + 0.34, 10, T["copper"], at=(0.4, 1.38))
    for k in range(5):
        x = -5.0 + k * 1.5
        cp.pk.hexstud(s, (x - 0.3, 0.9, BACK_Z + 0.7), (0, 1, 0), 0.08, 0.06, cp.jitter_tone("copper", k, 0.2))
        cp.pk.hexstud(s, (x + 0.25, 0.9, BACK_Z + 0.9), (0, 1, 0), 0.07, 0.06, T["iron_hi"])
    cp.obox(s, (0.5, 0.36, 0.03), (-1.8, 3.2, BACK_Z + 0.25), T["bone"], roll=-0.1)
    cp.obox(s, (0.4, 0.26, 0.035), (-1.8, 3.2, BACK_Z + 0.26), T["petrol_dk"], roll=-0.1)


def sockets():
    out = {"interact": (-1.4, 1.0, 1.8), "moss": (-1.4, 0.0, -2.6), "companion_bench": BENCH, "jukebox": (7.6, 0.0, -1.2)}
    for k, p in enumerate(LAMPS):
        out["light_%d" % k] = p
    return out


def check(s):
    lo, hi = cp.bounds(s)
    assert hi[0] - lo[0] <= 14.5 and hi[2] - lo[2] <= 9.0 and hi[1] <= 6.2, ("moss stall footprint", lo, hi)


def main():
    args = cp.options()
    b = cp.surface("camp_moss_stall", base)
    for name, fn in (("camp_moss_stall_detail1", detail1), ("camp_moss_stall_detail2", detail2)):
        cp.inside(cp.surface(name, fn), b)
    cp.export("camp_moss_stall", base, "gate", args, col=col, sockets=sockets(), check=check)
    cp.export("camp_moss_stall_detail1", detail1, "detail", args)
    cp.export("camp_moss_stall_detail2", detail2, "detail", args)


if __name__ == "__main__":
    main()
