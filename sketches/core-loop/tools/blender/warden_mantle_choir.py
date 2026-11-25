"""Choir: five hollow stepped cast horns, three inset working diaphragms.

Same CLI as warden_mantle_hand.py. Horns/comb are Body-local. Shoes and
rear supports are ArmL/ArmR-local; identity mount groups are not posed.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import warden_mantle_hand as hand
from warden_mantle_hand import (
    common,
    Part,
    xyz,
    box,
    bridge,
    clipped_stripes,
    PETROL,
    DUST,
)
import polish

polish.enable(detail=1, bevel=0.03, bevel_angle=46.0, edge=0.0, ao_strength=0.35)


def build():
    hand.setup()
    root = common.empty("MantleChoir")
    body = common.empty("MountBody", parent=root)
    comb = Part("ChoirRearComb")
    box(comb, "ancient_enamel", (0.6, 0.5, 4.4), (-3.2, 3.45, 0), PETROL)
    box(comb, "rubber", (0.012, 0.1, 4.1), (-2.892, 3.51, 0))
    box(comb, "ancient_light", (0.012, 0.05, 4.06), (-2.884, 3.51, 0))
    comb.to_object(parent=body)
    horns = Part("ChoirFiveHorns")
    horns.bevel = 0
    for i, (z, h) in enumerate(
        zip((-1.76, -0.88, 0, 0.88, 1.76), (0.9, 1.35, 1.8, 2.25, 2.7))
    ):
        centers = [
            Vector((-3.47, 3.30, z)),
            Vector((-3.45, 3.30 + h * 0.55, z)),
            Vector((-3.18, 3.30 + h - 0.35, z)),
            Vector((-2.96, 3.30 + h - 0.35 * 0.65 / math.sqrt(1 + 0.65**2), z)),
        ]
        directions = [
            Vector((0, 1, 0)),
            Vector((0.12, 1, 0)).normalized(),
            Vector((0.55, 1, 0)).normalized(),
            Vector((0.65, 1, 0)).normalized(),
        ]
        outer, inner = [], []
        for center, direction in zip(centers, directions):
            u = Vector((direction.y, -direction.x, 0))
            v = Vector((0, 0, 1))
            outer.append(
                [
                    horns.bm.verts.new(
                        Vector(
                            xyz(
                                center
                                + 0.35
                                * (
                                    u * math.cos(k * math.tau / 8)
                                    + v * math.sin(k * math.tau / 8)
                                )
                            )
                        )
                    )
                    for k in range(8)
                ]
            )
            inner.append(
                [
                    horns.bm.verts.new(
                        Vector(
                            xyz(
                                center
                                + 0.25
                                * (
                                    u * math.cos(k * math.tau / 8)
                                    + v * math.sin(k * math.tau / 8)
                                )
                            )
                        )
                    )
                    for k in range(8)
                ]
            )
        bridge(horns, outer, "ancient_enamel", PETROL, smooth=True)
        bridge(
            horns,
            [list(reversed(r)) for r in inner],
            "ancient_enamel",
            "charcoal",
            smooth=True,
        )
        bridge(horns, [outer[-1], inner[-1]], "ancient_enamel", "bone")
        bridge(horns, [inner[0], outer[0]], "ancient_enamel", PETROL)
        center = centers[-1] - directions[-1] * 0.18
        u = Vector((directions[-1].y, -directions[-1].x, 0))
        v = Vector((0, 0, 1))
        polygon = [
            (0.23 * math.cos(k * math.tau / 8), 0.23 * math.sin(k * math.tau / 8))
            for k in range(8)
        ]
        if i in (0, 2, 4):
            clipped_stripes(
                horns,
                polygon,
                lambda a, b, center=center, u=u, v=v: center + u * a + v * b,
            )
    horns.to_object(parent=body)
    for side, sign in (("L", -1), ("R", 1)):
        mount = common.empty("MountArm" + side, parent=root)
        shoe = Part("ChoirShoe" + side)
        box(shoe, "ancient_enamel", (0.28, 0.35, 0.3), (0, 0, 0), PETROL)
        route = [(0, 0, 0), (-3.2, 0, 0), (-3.2, 2.8425, sign * (1.95 - 0.6075))]
        for a, b in zip(route, route[1:]):
            shoe.rod("ancient_enamel", xyz(a), xyz(b), 0.055, segs=4, color=PETROL)
        shoe.to_object(parent=mount)
    return root


if __name__ == "__main__":
    options = common.args()
    output = options["out"] or common.default_out("warden_mantle_choir")
    root = build()
    assert common.tri_total(root) <= 1100
    hand.finish(root, output, (1100, 1700, 7))
    if options["render"]:
        hand.preview(output, options["render"], "choir")
