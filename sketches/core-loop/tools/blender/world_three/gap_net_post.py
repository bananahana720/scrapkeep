"""The gap net's rim post (GapNetPost), shared by the strung net (enemy_gap_net.py) and the
mid-gap curtain (enemy_gap_net_curtain.py): rim clamp, mast, back stay with its hazard cut
sleeve, speed sign, windsock, capstan and the crew in goggles, all on fleet_paint. The recipes
differ in the mast: `mast` is its joint list in Godot metres, from the deck to the head; the stay
runs from mast[2], the windsock stands on mast[3]. `outrigger` adds the lower arm out to a batten
at (outrigger, net_low). Returns the sockets the post owns: post_cut, sign and crew_head.
Under polish the crew is the shared soft critter and thin stays, poles and the scarf keep narrow
bevels; the windsock is cloth, so it takes none.
"""
import math

from mathutils import Vector

import fleet_crew

FLOOR = -1.1
STEEL = "53686d"
WORN = "a8aaa3"
CHAR = "charcoal"
OXIDE = "9b513a"


def g(x, y, z):
    return (x, -z, y)


def G(*p):
    return Vector(g(*p))


def build(post, mast, outrigger=None, net_low=None):
    post.box("fleet_paint", (2.0, 1.3, 0.16), loc=g(0.05, FLOOR + 0.08, 0), color=CHAR)
    for dz in (-0.5, 0.5):
        post.box("fleet_paint", (0.3, 0.3, 0.42), loc=g(0.95, FLOOR + 0.21, dz), color="hazard")
        post.box("fleet_paint", (0.18, 0.18, 0.12), loc=g(-0.8, FLOOR + 0.22, dz), color=WORN)
    for (a, b), w in zip(zip(mast, mast[1:]), (0.34, 0.3, 0.24, 0.18)):
        post.beam("fleet_paint", G(*a), G(*b), w, w, color=OXIDE)
    post.beam("fleet_paint", G(0.0, 0.25, 0), G(0.0, 0.55, 0), 0.38, 0.38, color="bone")
    for joint in mast[1:4]:
        post.box("fleet_paint", (0.36, 0.36, 0.3), loc=g(*joint), color=OXIDE)
    if outrigger is not None:
        post.beam("fleet_paint", G(0.0, -0.3, 0), G(outrigger, net_low, 0), 0.16, 0.16, color=STEEL)
    stay_top = Vector(mast[2])
    stay_foot = Vector((-1.75, FLOOR + 0.15, 0))
    with post.region(bevel=0.01):
        post.rod("fleet_paint", G(*stay_top), G(*stay_foot), 0.045, segs=5, color="brass")
    cut = stay_top.lerp(stay_foot, 0.55)
    d = (stay_foot - stay_top).normalized()
    post.rod("fleet_paint", G(*(cut - d * 0.22)), G(*(cut + d * 0.22)), 0.11, segs=6, color="hazard")
    post.box("fleet_paint", (0.36, 0.36, 0.24), loc=g(-1.75, FLOOR + 0.12, 0), color=STEEL)
    sign = Vector((-0.02, 1.25, 0.32))
    with post.region(bevel=0.012):
        post.cyl("fleet_paint", 0.48, 0.48, 0.06, segs=8, loc=g(*sign), rot=(math.pi / 2, 0, 0), color="hazard")
        post.cyl("fleet_paint", 0.36, 0.36, 0.07, segs=8, loc=g(sign.x, sign.y, sign.z + 0.01),
                 rot=(math.pi / 2, 0, 0), color="bone")
        for dy in (-0.1, 0.1):
            post.box("fleet_paint", (0.42, 0.08, 0.08), loc=g(sign.x, sign.y + dy, sign.z + 0.05), color=CHAR)
        post.box("fleet_paint", (0.08, 0.08, 0.28), loc=g(sign.x + 0.2, sign.y, sign.z + 0.05), color=CHAR)
    sx, sy = mast[3][0], mast[3][1]
    with post.region(bevel=0.01):
        post.rod("fleet_paint", G(sx, sy, 0), G(sx - 0.2, sy + 0.8, 0), 0.04, segs=5, color=CHAR)
    with post.region(bevel=0):
        for k in range(3):
            r0, r1 = 0.24 - 0.05 * k, 0.19 - 0.05 * k
            a = Vector((sx - 0.2 - 0.36 * k, sy + 0.7, 0.0))
            b = a + Vector((-0.36, -0.08, 0.0))
            post.rod("fleet_paint", G(*a), G(*b), r0, segs=6, color="hazard" if k % 2 == 0 else "bone", r2=r1)
    post.cyl("fleet_paint", 0.22, 0.26, 0.55, segs=6, loc=g(-0.55, FLOOR + 0.43, 0.25), color=STEEL)
    post.cyl("fleet_paint", 0.32, 0.32, 0.06, segs=8, loc=g(-0.55, FLOOR + 0.72, 0.25), color=CHAR)
    with post.region(bevel=0.01):
        post.rod("fleet_paint", G(-0.55, FLOOR + 0.75, 0.25), G(-0.05, FLOOR + 0.82, 0.62), 0.04, segs=5,
                 color=WORN)
    crew = Vector((-0.05, 0.25, 0.85))
    with post.region(bevel=0, subsurf=2, detail=1):
        post.cyl("fleet_paint", 0.36, 0.3, 0.95, segs=8, loc=g(crew.x, FLOOR + 0.62, crew.z), color=OXIDE)
    post.box("fleet_paint", (0.62, 0.42, 0.14), loc=g(crew.x, FLOOR + 1.03, crew.z), color="petrol")
    with post.region(bevel=0.01):
        post.beam("fleet_paint", G(crew.x - 0.15, -0.25, crew.z - 0.25), G(crew.x - 0.95, -0.15, crew.z - 0.65),
                  0.24, 0.05, color="bone")
    fleet_crew.head(post, crew, r=0.3, facing=(0.0, 1.0), hat="goggles")
    with post.region(bevel=0, subsurf=1, detail=1):
        for side in (-1, 1):
            post.rod("fleet_paint", G(crew.x + side * 0.32, -0.22, crew.z),
                     G(crew.x + side * 0.2, -0.55, crew.z - 0.35), 0.07, segs=5, color=OXIDE)
    return {"post_cut": cut, "sign": sign, "crew_head": crew}
