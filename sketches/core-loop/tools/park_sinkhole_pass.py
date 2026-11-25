#!/usr/bin/env python3
"""The sinkhole's authored pass: "Wall pays" and the dressing (Andrew 2026-10-17 22:37Z; "One skill per park", 22:12Z; DECISIONS.md).

Carving is the sinkhole's skill, and the Dig floor rule (src/combat/floor_rule.gd) is its hook: a ball on a wall steeper
than 25.8 degrees is off the floor, so floor threats can't reach it. This pass makes the tube walls the fast line and the
floor the slow, bitten one, by moving every rope ring and most geyser mouths onto the walls' carve band:

  ropes      16 floor ropes in four fans of four become 10, every ring on a carve band, none on the floor:
             lava_channel_14   the channel crossing: a fan of two per wall (the stage pin keeps four), floor 24
             main_tube_lower_4 the caisson swing: one per wall, fastest in the park (floor 26), toward the bowl
             east_haulage_4    the haulage cable: one per wall in the miners' drift, the slowest (floor 18)
             west_breakthrough_6 the breakthrough run: one per wall, floor 24
             rim_zip           unchanged, the rim descent into the caisson
  geysers    9 identical vents (charge 3 s, all mid-floor) get one job each:
             main_tube_upper_vent, skylight_chain_vent  the two skylight exits, mouths on the wall, charge 2 s and 3 s
             cannon_tube_vent, main_tube_lower_vent     the rhythm pair, wall, 2 s and 3 s
             west_gallery_vent                          the flood escape out of the cavern, wall, 2.5 s
             west_breakthrough_vent                     the breakthrough's hop toward the Warden, wall, 2.5 s
             east_drift_vent, east_haulage_vent         the miners' floor vents, left on the floor and slow (4 s)
             fumarole                                   unchanged
  The tube floors stay where the burrowers (lava channel) and drill crews (drifts) bite.

The dressing (park rows, DRESS): every greybox tube, cavern, drop lip and box row of the sinkhole takes its authored
piece with the seat fit (tools/blender/park/sinkhole_tubes.py, sinkhole_slabs.py). The lava tubes carry the polish band,
so they read as the ancients' work (society ancient) and their verb is bank, the carve, as are the gallery's
and the lava channel's; the drifts stay the miners'
floor (roll). The cinder cone's spire and the machine vault's bowl are the ground scatter's to dress; the trench granaries
tile the cliff dwelling row. FRAGMENTS adds the pass's field notes and COUNTERS rewrites the floor threats' counters for the floor rule.

Each wall point sits at lateral offset `band` m from the wash centreline, inside the band where the wash is steeper than
the floor rule (park_stamps.gd wash profile, tools/blender/park/sinkhole_tubes.py band_start). A ring's height is the
floor under the old fan plus the wash's rise at that offset.

Reads the original rows from git (the parent of the commit that first ran this pass) when the file has already been
rewritten, so it is idempotent. Since the pass ran, the ropes' `to` y were raised in the JSON to at least 2.35 m over
the baked ground (the cable hang's landing clearance, tests/park_cable_ends_test.gd). This pass does not read the ground,
so rerunning it writes the old, lower ends back and that test fails:

  python3 sketches/core-loop/tools/park_sinkhole_pass.py
"""
import json
import math
import pathlib

PARK = pathlib.Path(__file__).resolve().parent.parent / "src/world/park/park_sinkhole.json"
SAMPLE = 0.81
FAN = (0.72, 0.90)
ROPES = {
    "lava_channel_14": ("tube_rope", FAN, 24.0),
    "main_tube_lower_4": ("main_tube_lower_rope", (SAMPLE,), 26.0),
    "east_haulage_4": ("east_haulage_rope", (SAMPLE,), 18.0),
    "west_breakthrough_6": ("west_breakthrough_rope", (SAMPLE,), 24.0),
}
WASH = {
    ("tunnel", "lava_tube", False): ("lava_wash", "bank", "ancient"),
    ("tunnel", "lava_tube", True): ("lava_wash_short", "bank", "ancient"),
    ("tunnel", "adit", False): ("drift_wash", None, None),
    ("flooded_cavern", "cenote_pool", False): ("gallery_wash", "bank", None),
}
SLABS = {
    "skylight_1": "skylight_lip", "skylight_2": "skylight_lip", "skylight_3": "skylight_lip",
    "tube_mouth": "tube_mouth_lip", "crater_breach": "breach_lip",
    "upper_tube_cap": "miners_cap", "great_room_cap": "miners_cap",
    "great_room_floor": "great_room_deck", "haulage_rails": "haulage_bed",
}
SCATTER = ["cinder_cone", "machine_vault"]
KIT = {"trench_granaries": ("cliff_dwelling_row", "tile")}
FRAGMENTS = {
    "main_tube_upper_1": ("ancient", "ancient_polish_band"),
    "cannon_tube_2": ("ancient", "ancient_vent_mouths"),
    "main_tube_lower_1": ("mining", "mining_wall_rule"),
    "main_tube_lower_4": ("mining", "mining_rope_rings"),
}
COUNTERS = {
    "cinder_burrowers": "Carve the channel wall: a ball on the wall band is off the floor and the burrow can't reach it (floor_rule.gd), and the rope fan's rings hang on the band; or slam the marker, and the codex burrow_lane pays for the side roll.",
    "drift_drill_crews": "Ride the drift wall: the rig's ring bores the floor and a carving ball is off it (floor_rule.gd); the wall ropes carry you past, the timber sets every 6 m are claw and harpoon anchors, or smash the rig mid-bore.",
}
CINDER_DRAG = 0.08
CINDER_RECIPES = ("lava_wash", "lava_wash_short")
GLAZE_PUSH = 7.0
GLAZE_CAP = 36.0
GLAZE_RECIPES = ("lava_wash", "lava_wash_short", "gallery_wash", "drift_wash")


def cinder_row(park_rows):
    strips = []
    for r in park_rows:
        if r["recipe"] in CINDER_RECIPES and r["stamp"] == "wash":
            strips.append([r["at"][0], r["at"][1], r["yaw_deg"], r["size"][0], round(0.2 * float(r["size"][2]), 2)])
    return {"id": "tube_cinder", "kind": "cinder", "site": "lava_channel_1", "recipe": "", "strips": strips, "drag": CINDER_DRAG}


def glaze_row(park_rows):
    strips = []
    for r in park_rows:
        if r["recipe"] in GLAZE_RECIPES and r["stamp"] == "wash":
            half = float(r["size"][2]) / 2
            strips.append([r["at"][0], r["at"][1], r["yaw_deg"], r["size"][0], round(0.62 * half, 2), round(0.98 * half, 2)])
    return {"id": "tube_glaze", "kind": "glaze", "site": "lava_channel_1", "recipe": "", "strips": strips, "push": GLAZE_PUSH, "cap": GLAZE_CAP}


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
    ax, az = row["at"]
    sx, sz = side_axis(row)
    yaw = math.radians(row["yaw_deg"])
    u = (c["at"][0] - ax) * math.sin(yaw) + (c["at"][1] - az) * math.cos(yaw)
    lateral = (c["target"][0] - ax) * sx + (c["target"][2] - az) * sz
    v = math.copysign(SAMPLE * float(row["size"][2]) / 2.0, lateral)
    c["at"] = [round(ax + math.sin(yaw) * u + sx * v, 1), round(az + math.cos(yaw) * u + sz * v, 1)]
    return c


def dress(row):
    r = dict(row)
    if not str(r["recipe"]).startswith("greybox:"):
        return r
    if r["id"] in SCATTER:
        r["recipe"] = "scatter"
        return r
    if r["id"] in KIT:
        r["recipe"], r["fit"] = KIT[r["id"]]
        return r
    if r["id"] in SLABS:
        r["recipe"] = SLABS[r["id"]]
        r["fit"] = "seat"
        return r
    key = (r["element"], r["landform"], float(r["size"][0]) < 40.5)
    if r["stamp"] == "wash" and key in WASH:
        recipe, verb, society = WASH[key]
        r["recipe"] = recipe
        r["fit"] = "seat"
        if verb:
            r["verb"] = verb
        if society and r["society"] == "none":
            r["society"] = society
    return r


def tag(row):
    carved = row["recipe"] in ("lava_wash", "lava_wash_short", "gallery_wash") and row["verb"] in ("roll", "swing")
    if carved or (row["element"] == "half_pipe" and row["id"].startswith("lava_channel_") and row["verb"] == "pump"):
        row = dict(row)
        row["verb"] = "bank"
    if row["id"] in FRAGMENTS:
        row = dict(row)
        row["society"], row["fragment"] = FRAGMENTS[row["id"]]
    return row


def original():
    """The rows before this pass: the file's own if it still holds the floor fans, else HEAD's, else the parent of the
    commit that removed the fourth haulage rope (the commit that first ran this pass)."""
    import subprocess
    text = PARK.read_text()
    if '"id": "east_haulage_rope_4"' in text:
        return text
    top = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=PARK.parent, text=True).strip()
    rel = str(PARK.relative_to(top))
    git = lambda *a: subprocess.check_output(["git", *a], cwd=top, text=True)
    head = git("show", "HEAD:" + rel)
    if '"id": "east_haulage_rope_4"' in head:
        return head
    log = git("log", "--format=%H", "-S", '"id": "east_haulage_rope_4"', "--", rel).split()
    return git("show", log[0] + "^:" + rel)


def main():
    old = json.loads(original())
    rows = {r["id"]: r for r in old["park_rows"]}
    old_c = old["contraption_rows"]
    lines = PARK.read_text().split("\n")
    new = []
    done = set()
    for c in old_c:
        site = c.get("site", "")
        if c["kind"] == "cable" and site in ROPES:
            if site not in done:
                new += rope_rows(site, old_c, rows[site])
                done.add(site)
            continue
        if c["kind"] in ("cinder", "glaze"):
            continue
        if c["id"] in VENTS:
            new.append(vent_row(c, rows[c["site"]]))
            continue
        new.append(c)
    head_rows = lines.index(' "park_rows": [')
    k = head_rows + 1
    while lines[k].startswith("  {"):
        tail_k = "," if lines[k].endswith(",") else ""
        row = json.loads(lines[k].rstrip(","))
        lines[k] = "  " + json.dumps(tag(dress(row)), ensure_ascii=False) + tail_k
        k += 1
    head_homes = lines.index(' "home_rows": [')
    k = head_homes + 1
    while lines[k].startswith("  {"):
        tail_k = "," if lines[k].endswith(",") else ""
        home = json.loads(lines[k].rstrip(","))
        if home["id"] in COUNTERS:
            home["counter"] = COUNTERS[home["id"]]
        lines[k] = "  " + json.dumps(home, ensure_ascii=False) + tail_k
        k += 1
    head = lines.index(' "contraption_rows": [')
    first = head + 1
    last = next(i for i in range(first, len(lines)) if lines[i].startswith(" ]")) - 1
    current = [json.loads(ln.rstrip(",")) for ln in lines if ln.startswith('  {"id": ') and '"element": ' in ln]
    new.append(cinder_row(current))
    new.append(glaze_row(current))
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
