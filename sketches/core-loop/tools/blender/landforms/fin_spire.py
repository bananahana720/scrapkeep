"""Jointed fin with a pinched neck, flat collar shoulder and hard cap."""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_strata as kit

NAME = "fin_spire"


def build():
    root = kit.common.empty(NAME)
    p = kit.common.Part(NAME + "_rock")
    profile = [(0, 3.8), (0.8, 3.75), (2.2, 3.35), (2.3, 3.0),
               (5.5, 2.65), (5.65, 2.95), (6.0, 2.95), (6.15, 2.4),
               (9.0, 2.1), (10.8, 1.85), (10.8, 2.3), (11.25, 2.3),
               (11.25, 1.9), (13.4, 1.65), (15.8, 1.4), (17.8, 1.5),
               (19.4, 1.65), (19.4, 3.7), (20.2, 4.0), (21.5, 3.95), (22, 3.4)]
    expanded = []
    for k, (z, radius) in enumerate(profile):
        if k:
            pz, pr = profile[k - 1]
            n = max(1, math.ceil((z - pz) / 0.7))
            for j in range(1, n):
                t = j / n
                expanded.append((pz + (z - pz) * t, pr + (radius - pr) * t + 0.05 * math.sin(j * 2.6 + k)))
        expanded.append((z, radius))
    outline = [(-1, -0.36), (-0.82, -0.85), (-0.38, -1), (0.08, -0.91),
               (0.16, -0.72), (0.24, -0.92), (0.72, -0.73), (1, -0.27),
               (0.91, 0.53), (0.47, 0.83), (-0.08, 1), (-0.7, 0.71)]
    rows, tones = [], []
    for k, (z, radius) in enumerate(expanded):
        row = []
        for i, (ox, oy) in enumerate(outline):
            chip = 1 - 0.07 * ((i * 7 + int(z / 4)) % 5) / 4
            x = radius * ox * chip + 0.23 * math.sin(z * 0.4)
            y = radius * 0.61 * oy * chip
            zz = z + (0.12 * math.sin(i * 2.4) if 19.4 < z < 22 else 0)
            row.append((x, y, zz))
        rows.append(row)
        tones.append(kit.blend(kit.SAND, kit.BUFF if k % 4 else kit.RED, 0.30))
    kit.loft(p, rows, tones, smooth=True)
    kit.attach(root, kit.finish(p))
    kit.fit(root, (8, 5, 22))
    return root


if __name__ == "__main__":
    kit.deliver(build, NAME)
