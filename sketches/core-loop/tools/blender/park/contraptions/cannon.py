"""Headless recipe for the cannon skin: cannon.glb, cannon_detail1.glb, cannon_detail2.glb (KC9, PARK.md section 4, recipe
`cannon`; the launcher row's style `cannon`).

A Gorge-era dam gun in Southwest salvage: a flared dark-iron barrel hooped in copper, held on iron cheeks and a copper
trunnion, its breech sunk in a buttress of dam-era concrete (form-board joints, copper straps) on a poured pad. It takes the code
barrel's place (src/world/contraptions.gd:431-447): the same axis (aim plus UP * 0.9, 42 degrees), centre (0, 2, -5) round the
mouth, length 8, radius 2.0 at the breech growing to 2.8 at the muzzle. The code's amber ring (radius 3.5 to 4.0 at the mouth,
y -0.8) stays code-drawn, so the whole recipe stays behind it: the pad ends at z -4.1.

Origin at the launcher's mouth point (the ground is y -1.0), +Y up, +Z the aim; the code turns the node about Y to the row's
aim. The barrel's lower back would go under the ground, so the barrel starts where its underside meets y -1.0 (axis offset -2.0
from the centre) and the buttress closes the breech. Class `landform` (8,000 tris, 1 draw) for the base, `detail` for the
shells. No lights, no -col mesh (a launcher has no collider).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/cannon.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
D = Vector((0.0, 0.9, 1.0)).normalized()
C = Vector((0.0, 2.0, -5.0))
GROUND = -1.0
S_BREECH, S_MUZZLE = -2.0, 4.0


def r_at(s_):
    return 2.4 + 0.1 * s_


def at(s_):
    return C + D * s_


def base(s):
    s.box((9.0, 0.8, 8.0), (0, GROUND + 0.4, -8.1), T["concrete_lt"])
    s.box((4.4, 3.4, 4.5), (0, 0.7, -7.3), T["concrete"])
    for y in (-0.3, 0.6, 1.5):
        s.box((4.44, 0.05, 4.54), (0, y, -7.3), T["concrete_dk"])
    for z in (-8.9, -5.9):
        s.box((4.5, 3.46, 0.3), (0, 0.7, z), T["copper_dk"])
    pk.tube(s, at(S_BREECH), at(S_MUZZLE), r_at(S_BREECH), r_at(S_MUZZLE), 16, T["iron"])
    for s_ in (-1.0, 1.0, 3.0):
        pk.tube(s, at(s_ - 0.25), at(s_ + 0.25), r_at(s_ - 0.25) + 0.12, r_at(s_ + 0.25) + 0.12, 16, T["copper"])
    pk.tube(s, at(S_MUZZLE - 0.5), at(S_MUZZLE), r_at(S_MUZZLE) + 0.1, r_at(S_MUZZLE) + 0.14, 16, T["iron_hi"])
    pk.tube(s, at(S_MUZZLE), at(S_MUZZLE + 0.06), 1.75, 1.75, 14, T["charcoal"])
    for sx in (-1, 1):
        x = sx * 3.1
        pk.strut(s, (x, 0.1, -6.6), (x, 2.0, -5.0), 0.7, 0.8, T["iron"])
        pk.strut(s, (x, 0.1, -3.7), (x, 2.0, -5.0), 0.7, 0.8, T["iron"])
        s.box((0.9, 0.5, 3.8), (x, -0.1, -5.0), T["iron_hi"])
        s.box((0.9, 1.6, 1.5), (x, 2.0, -5.0), T["iron_hi"])
    pk.tube(s, (-3.6, C.y, C.z), (3.6, C.y, C.z), 0.42, 0.42, 10, T["copper"])


def detail1(s):
    for sx in (-1, 1):
        for row in range(3):
            for col in range(2):
                pk.hexstud(s, (sx * 3.55, 1.5 + row * 0.5, -5.0 + (col - 0.5) * 0.8), (sx, 0, 0), 0.08, 0.07, T["copper_dk"])
        for k in range(5):
            pk.hexstud(s, (sx * 3.1, 0.15, -6.5 + k * 0.7), (0, 1, 0), 0.08, 0.06, T["iron"])
    u = Vector((1.0, 0.0, 0.0))
    v = D.cross(u)
    for s_ in (-1.0, 1.0, 3.0):
        for k in range(8):
            a = math.tau * k / 8
            n = u * math.cos(a) + v * math.sin(a)
            pk.hexstud(s, tuple(at(s_) + n * (r_at(s_) + 0.12)), tuple(n), 0.07, 0.06, T["copper_dk"])
    for sx in (-1, 1):
        for z in (-8.9, -5.9):
            pk.hexstud(s, (sx * 2.25, 1.5, z), (sx, 0, 0), 0.08, 0.07, T["copper"])


def detail2(s):
    for k in range(10):
        s.box((0.14, 0.14, 0.02), (-1.65 + (k % 5) * 0.825, 0.1 + (k // 5) * 1.6, -9.56), T["charcoal"])
    for sx in (-1, 1):
        pk.ring_y(s, 0.12, 0.3, 2.43, 2.55, 8, T["iron"], at=(sx * 1.3, -7.3))
        s.box((1.2, 0.2, 0.8), (sx * 3.4, -0.1, -4.6), T["concrete_dk"])
    pk.tube(s, at(S_MUZZLE - 0.7), at(S_MUZZLE - 0.5), r_at(S_MUZZLE) + 0.02, r_at(S_MUZZLE) + 0.02, 16, T["varnish"])
    pk.tube(s, (0, 2.35, -6.2), (0, 2.65, -6.2), 0.18, 0.18, 8, T["copper"])
    for k in range(5):
        s.box((0.1, 0.9 - 0.1 * k, 0.04), (-1.8 + k * 0.9, 1.0, -9.57), T["rust"])


def check_base(s):
    lo, hi = pk.bounds(s)
    assert abs(lo[1] - GROUND) < 0.06, ("cannon does not stand on the ground", lo[1])
    assert hi[1] > 4.0 and abs((lo[0] + hi[0]) / 2) < 0.2 and hi[2] > -4.0 and lo[2] < -6.0, ("cannon bounds", lo, hi)
    for x, y, z in s.verts:
        assert y >= GROUND - 0.06, ("part below the ground", (x, y, z))
        assert not (z > -4.05 and y < -0.45), ("something stands inside the launch ring", (x, y, z))


def main():
    args = pk.options()
    base_s = pk.build("cannon", base, "landform")
    check_base(base_s)
    for name, fn in (("cannon_detail1", detail1), ("cannon_detail2", detail2)):
        pk.inside(pk.build(name, fn, "detail"), [base_s])
    pk.export("cannon", base, "landform", args.out_dir, args.count_only, check_base)
    pk.export("cannon_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("cannon_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
