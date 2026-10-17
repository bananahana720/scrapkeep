#!/usr/bin/env python3
"""The sinkhole's "Wall pays" pass (Andrew 2026-10-17 22:37Z; "One skill per park", 22:12Z; DECISIONS.md).

Carving is the sinkhole's skill, and the Dig floor rule (src/combat/floor_rule.gd) is its hook: a ball on a wall steeper
than 25.8 degrees is off the floor, so floor threats can't reach it. This pass makes the tube walls the fast line and the
floor the slow, bitten one, by moving every rope ring and most geyser mouths onto the walls' carve band:

  ropes      16 floor ropes in four fans of four become 10, every ring on a carve band, none on the floor:
             lava_channel_14   the channel crossing: a fan of two per wall (the stage pin keeps four), floor 18
             main_tube_lower_4 the caisson swing: one per wall, fastest in the park (floor 22), toward the bowl
             east_haulage_4    the haulage cable: one per wall in the miners' drift, the slowest (floor 16)
             west_breakthrough_6 the breakthrough run: one per wall, floor 20
             rim_zip           unchanged, the rim descent into the caisson
  geysers    9 identical vents (charge 3 s, all mid-floor) get one job each:
             main_tube_upper_vent, skylight_chain_vent  the two skylight exits, mouths on the wall, charge 2 s and 3 s
             cannon_tube_vent, main_tube_lower_vent     the rhythm pair, wall, 2 s and 3 s
             west_gallery_vent                          the flood escape out of the cavern, wall, 2.5 s
             west_breakthrough_vent                     the breakthrough's hop toward the Warden, wall, 2.5 s
             east_drift_vent, east_haulage_vent         the miners' floor vents, left on the floor and slow (4 s)
             fumarole                                   unchanged
  The tube floors stay where the burrowers (lava channel) and drill crews (drifts) bite.

Each wall point sits at lateral offset `band` m from the wash centreline, inside the band where the wash is steeper than
the floor rule (park_stamps.gd wash profile, tools/blender/park/sinkhole_tubes.py band_start). A ring's height is the
floor under the old fan plus the wash's rise at that offset.

Reads the original rows from git (the parent of the commit that first ran this pass) when the file has already been
rewritten, so it is idempotent:

  python3 sketches/core-loop/tools/park_sinkhole_walls.py
"""
import json
import math
import pathlib

PARK = pathlib.Path(__file__).resolve().parent.parent / "src/world/park/park_sinkhole.json"
SAMPLE = 0.81  # of the half width: 10.5 m on a 26 m wash, inside the carve band (8.9 to 13 m)
FAN = (0.72, 0.90)  # the channel crossing's two rings per wall
# site: (rope ids, rings per wall, floor speed)
ROPES = {
    "lava_channel_14": ("tube_rope", FAN, 18.0),
    "main_tube_lower_4": ("main_tube_lower_rope", (SAMPLE,), 22.0),
    "east_haulage_4": ("east_haulage_rope", (SAMPLE,), 16.0),
    "west_breakthrough_6": ("west_breakthrough_rope", (SAMPLE,), 20.0),
}
# vent id: (on the wall, charge s)
VENTS = {
    "main_tube_upper_vent": (True, 2.0),
    "skylight_chain_vent": (True, 3.0),
    "cannon_tube_vent": (True, 2.0),
    "main_tube_lower_vent": (True, 3.0),
    "west_gallery_vent": (True, 2.5),
    "west_breakthrough_vent": (True, 2.5),
    "east_drift_vent": (False, 4.0),
    "east_haulage_vent": (False, 4.0),
}


def wash_depth(v, width, depth):
    t = abs(2.0 * v / width)
    if t >= 1.0:
        return 0.0
    if t <= 0.4:
        return depth
    w = (t - 0.4) / 0.6
    return depth * (1.0 - w * w)


def rise(v, row):
    depth, width = float(row["size"][1]), float(row["size"][2])
    return depth - wash_depth(v, width, depth)


def side_axis(row):
    yaw = math.radians(row["yaw_deg"])
    return math.cos(yaw), -math.sin(yaw)


def rope_rows(site, old, row):
    prefix, rings, floor = ROPES[site]
    fan = [c for c in old if c["id"].startswith(prefix + "_")]
    # the fan runs across the tube; its two middle ropes ride the floor
    mid = sorted(fan, key=lambda c: c["id"])[1:3]
    def centre(key):
        return [sum(c[key][k] for c in mid) / len(mid) for k in range(3)]
    a, b = centre("from"), centre("to")
    dx, dz = b[0] - a[0], b[2] - a[2]
    n = math.hypot(dx, dz)
    sx, sz = dz / n, -dx / n
    half = float(row["size"][2]) / 2.0
    out = []
    k = 1
    for side in (-1.0, 1.0):
        for frac in rings:
            v = side * frac * half
            out.append({
                "id": "%s_%d" % (prefix, k), "kind": "cable", "site": site, "recipe": "",
                "from": [round(a[0] + sx * v, 1), round(a[1] + rise(v, row), 1), round(a[2] + sz * v, 1)],
                "to": [round(b[0] + sx * v, 1), round(b[1] + rise(v, row), 1), round(b[2] + sz * v, 1)],
                "radius": 3.4, "floor": floor,
            })
            k += 1
    return out


def vent_row(c, row):
    wall, charge = VENTS[c["id"]]
    c = dict(c)
    c["charge"] = charge
    if not wall:
        return c
    # onto the wall on the target's side of the tube
    ax, az = row["at"]
    sx, sz = side_axis(row)
    yaw = math.radians(row["yaw_deg"])
    u = (c["at"][0] - ax) * math.sin(yaw) + (c["at"][1] - az) * math.cos(yaw)
    lateral = (c["target"][0] - ax) * sx + (c["target"][2] - az) * sz
    v = math.copysign(SAMPLE * float(row["size"][2]) / 2.0, lateral)
    c["at"] = [round(ax + math.sin(yaw) * u + sx * v, 1), round(az + math.cos(yaw) * u + sz * v, 1)]
    return c


def original():
    """The contraption rows before this pass: the file's own rows if they still hold the floor fans, else git's."""
    import subprocess
    text = PARK.read_text()
    if '"id": "tube_rope_4"' in text and '"id": "east_haulage_rope_4"' in text:
        return text
    rel = PARK.relative_to(pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=PARK.parent, text=True).strip()))
    show = lambda rev: subprocess.check_output(["git", "show", "%s:%s" % (rev, rel)], cwd=PARK.parent, text=True)
    head = show("HEAD")
    if '"id": "east_haulage_rope_4"' in head:
        return head
    # the commit that ran this pass removed the fourth haulage rope; its parent holds the floor fans
    log = subprocess.check_output(["git", "log", "--format=%H", "-S", '"id": "east_haulage_rope_4"', "--", str(rel)], cwd=PARK.parent, text=True).split()
    return show(log[0] + "^")


def main():
    old = json.loads(original())
    rows = {r["id"]: r for r in old["park_rows"]}
    old_c = old["contraption_rows"]
    lines = PARK.read_text().split("\n")
    head = lines.index(' "contraption_rows": [')
    first = head + 1
    last = next(i for i in range(first, len(lines)) if lines[i].startswith(" ]")) - 1
    new = []
    done = set()
    for c in old_c:
        site = c.get("site", "")
        if c["kind"] == "cable" and site in ROPES:
            if site not in done:
                new += rope_rows(site, old_c, rows[site])
                done.add(site)
            continue
        if c["id"] in VENTS:
            new.append(vent_row(c, rows[c["site"]]))
            continue
        new.append(c)
    body = ["  " + json.dumps(c, ensure_ascii=False) + "," for c in new]
    body[-1] = body[-1].rstrip(",")
    tail = "," if lines[last].endswith(",") else ""
    body[-1] += tail
    lines[first:last + 1] = body
    text = "\n".join(lines)
    json.loads(text)
    PARK.write_text(text)


if __name__ == "__main__":
    main()
