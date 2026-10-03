"""Forty-metre butte crown, fractured cliff belt and short angular talus skirt."""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_strata as kit

NAME = "mesa_cap"


def build():
    root = kit.common.empty(NAME)
    p = kit.common.Part(NAME + "_rock")
    n = 96
    rows, tones = [], []
    profile = [(0, 20), (1.9, 18.9), (3.1, 17.6), (3.1, 16.5),
               (4, 16.3), (4.8, 16.5), (5.6, 16.45), (6.3, 16.6), (6.45, 17.2), (6.65, 17.2),
               (6.65, 16.6), (7.4, 16.45), (8.4, 16.55), (9.5, 16.5), (10.4, 16.4), (11.6, 16.4), (11.6, 17.5),
               (12, 17.8), (13.7, 17.9), (14, 17.4)]
    for k, (z, r) in enumerate(profile):
        row = []
        for i in range(n):
            a = i * math.tau / n
            broken = 0.87 + 0.10 * math.sin(3 * a + 0.3) + 0.06 * math.sin(7 * a + 1.0)
            joint = 1.2 if i in (5, 29, 68, 85) and z > 3 else 0
            radius = r * broken - joint
            row.append((radius * math.cos(a), radius * math.sin(a), z))
        rows.append(row)
        tones.append(kit.blend(kit.SAND, kit.RED, 0.32) if 3.1 <= z < 11.6 else kit.BUFF)
    kit.loft(p, rows, tones)
    kit.attach(root, kit.finish(p))
    for i in range(25):
        a = i * math.tau / 25 + 0.13
        size = (0.9 + (i % 4) * 0.32, 0.75 + (i % 3) * 0.4, 0.5 + (i % 5) * 0.14)
        kit.attach(root, kit.block("mesa_talus_%02d" % i, size, 4600 + i, kit.SAND),
                   (18.4 * math.cos(a), 18.4 * math.sin(a), 0.1))
    kit.fit(root, (40, 40, 14))
    return root


if __name__ == "__main__":
    kit.deliver(build, NAME)
