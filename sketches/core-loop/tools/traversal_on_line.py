#!/usr/bin/env python3
"""Share of a traversal trace that stays on the pilot's authored line.

    python3 tools/traversal_on_line.py tools/traversal_lines.json <pilot> <trace.json> [<trace.json> ...]

A trace is the per-tick file the traversal tool writes: {"ticks": [{"at": [x, y, z],
"time": s, "planar_speed": v, "grounded": bool, "dead_stops": n, ...}, ...]}.
For each trace it prints the share of ticks whose planar distance to the waypoint
polyline is 8 m or less, counted from the first tick within 8 m of the third waypoint
(the ride's mouth) to the last tick, the largest distance off the line and where, the
longest airborne stretch, and the lowest planar speed after the mouth. The last line is
the median share. Exit 1 when the median is under 0.85.
"""
import json
import statistics
import sys

NEAR = 8.0
BAR = 0.85


def distance(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    span = dx * dx + dz * dz
    t = 0.0 if span == 0.0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / span))
    cx, cz = ax + t * dx, az + t * dz
    return ((px - cx) ** 2 + (pz - cz) ** 2) ** 0.5


def off_line(p, points):
    return min(distance(p, points[i], points[i + 1]) for i in range(len(points) - 1))


def main():
    lines_path, pilot = sys.argv[1], sys.argv[2]
    points = json.load(open(lines_path))["pilots"][pilot]["waypoints"]
    mouth = points[min(2, len(points) - 1)]
    shares = []
    for path in sys.argv[3:]:
        ticks = json.load(open(path))["ticks"]
        start = 0
        for i, tick in enumerate(ticks):
            if ((tick["at"][0] - mouth[0]) ** 2 + (tick["at"][2] - mouth[1]) ** 2) ** 0.5 <= NEAR:
                start = i
                break
        ride = ticks[start:]
        on = 0
        worst = (0.0, None)
        air = longest_air = 0
        slowest = (1e9, None)
        for tick in ride:
            p = (tick["at"][0], tick["at"][2])
            d = off_line(p, points)
            if d <= NEAR:
                on += 1
            if d > worst[0]:
                worst = (d, tick)
            if tick["grounded"]:
                air = 0
            else:
                air += 1
                longest_air = max(longest_air, air)
            if tick["planar_speed"] < slowest[0]:
                slowest = (tick["planar_speed"], tick)
        share = on / len(ride) if ride else 0.0
        shares.append(share)
        step = ride[1]["time"] - ride[0]["time"] if len(ride) > 1 else 0.0
        at = worst[1]["at"] if worst[1] else [0, 0, 0]
        slow_at = slowest[1]["at"] if slowest[1] else [0, 0, 0]
        print("%s: on-line share %.3f from t=%.1f s; farthest off %.1f m at (%.0f, %.0f, %.0f) t=%.1f s; "
              "longest flight %.2f s; slowest %.1f m/s at (%.0f, %.0f, %.0f); dead stops %d"
              % (path.split("/")[-1], share, ride[0]["time"] if ride else 0.0, worst[0], at[0], at[1], at[2],
                 worst[1]["time"] if worst[1] else 0.0, longest_air * step, slowest[0], slow_at[0], slow_at[1], slow_at[2],
                 ticks[-1]["dead_stops"]))
    median = statistics.median(shares) if shares else 0.0
    print("%s: median on-line share %.3f over %d traces (bar %.2f)" % (pilot, median, len(shares), BAR))
    sys.exit(0 if median >= BAR else 1)


main()
