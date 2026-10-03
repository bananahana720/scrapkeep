"""Continuous slickrock, curved cross-beds with at most 0.18 m relief."""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_strata as kit

NAME = "wave_dome"


def bedding(x, y):
    return (y + 3.8 * math.sin(x * 0.13) + 0.045 * x * x - 0.04 * x * y) * math.tau / 2.0


def build():
    root = kit.common.empty(NAME)
    p = kit.common.Part(NAME + "_rock")
    # Follow the curved bedding coordinates with the topology. A uniform polar
    # grid undersampled thin crests and made the exported relief look painted.
    columns = 37
    stations = [(2 * bed + offset, lift, buff) for bed in range(-12, 19)
                for offset, lift, buff in [(0, 0.015, 0.3), (0.075, 0.18, 0.95),
                                          (0.20, 0.03, 0.65), (0.65, 0.015, 0.3)]]
    rows = []
    for s, lift, buff in stations:
        row = []
        for j in range(columns):
            x = -15 + 30 * j / (columns - 1)
            extent = math.sqrt(max(0, 225 - x * x))
            y = (s - 3.8 * math.sin(x * 0.13) - 0.045 * x * x) / (1 - 0.04 * x)
            y = max(-extent, min(extent, y))
            r = min(1, math.hypot(x, y) / 15)
            a = math.atan2(y, x)
            base = 9 * (1 - r * r) ** 2 * (1 + 0.23 * math.sin(a) * r + 0.18 * math.cos(2 * a) * r * r)
            z = base + lift * math.sin(math.pi * r) ** 2
            row.append(p.bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(len(rows) - 1):
        for j in range(columns - 1):
            vs = [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
            f = kit.face(p, vs, smooth=True)
            for loop, row_index in zip(f.loops, [i, i, i + 1, i + 1]):
                tone = kit.blend(kit.RED, kit.BUFF, stations[row_index][2])
                loop[p.col] = kit.common.rgba(tone)
    kit.bmesh.ops.remove_doubles(p.bm, verts=list(p.bm.verts), dist=0.000001)
    boundary = [e for e in p.bm.edges if e.is_boundary]
    caps = kit.bmesh.ops.holes_fill(p.bm, edges=boundary, sides=0)['faces']
    p.paint(caps, 'paint', kit.SAND)
    for f in caps:
        f.smooth = False
    kit.attach(root, kit.finish(p))
    kit.fit(root, (30, 30, 9))
    return root


if __name__ == "__main__":
    kit.deliver(build, NAME)
