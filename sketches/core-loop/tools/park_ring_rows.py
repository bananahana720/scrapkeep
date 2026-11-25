#!/usr/bin/env python3
"""The sinkhole's full gallery ring (storyboard 4, call B, Andrew 2026-10-16; DECISIONS.md).

Rewrites src/world/park/park_sinkhole.json in place, one row per line as the file keeps them:

  gallery_ring, gallery_ring_2..24   the ring deck: 24 ledge rows, 15 m wide from radius 46 to 61
                                     round the pool centre (0, 350), the board's deck. Each is a
                                     zero-height plateau stamp, so the bake paints the ring and
                                     keeps the floor, and the row places only its ride_ledge sensor
                                     (park_recipes.gd stamp_replaces). `gallery_ring` keeps its id,
                                     home and routes and becomes the north segment. The landmark's
                                     timber deck (landmark_sinkhole) dresses every segment but the
                                     three in the lower tubes' trough (TROUGH): the others carry
                                     recipe `landmark`, and the ground scatter dresses the trough's
                                     (recipe `scatter`), keeping the wash open for the tube mouths.
  gallery_cut_1..15                  the south wall cut back to radius 66 between x -45 and 45,
                                     so the ring passes behind the nest. Columns 6 m wide with
                                     edges on odd metres, so no 2 m bake vertex sits in two cuts.
  pump_gallery                       moved 13 m east to (73, 350), outside the ring.
  route gallery_lap                  gallery_ring round all 24 segments to the landmark.

Angles run clockwise from north (-z, the arriving side): x = r sin a, z = 350 - r cos a.
Run again on the edited file and it rewrites the same rows (idempotent).

  python3 sketches/core-loop/tools/park_ring_rows.py
"""
import json
import math
import pathlib
import re

PARK = pathlib.Path(__file__).resolve().parent.parent / "src/world/park/park_sinkhole.json"
CENTRE = (0.0, 350.0)
R_IN, R_OUT = 46.0, 61.0
SEGMENTS = 24
CUT_R = 66.0
CUT_Z0 = 399.0
CUT_EDGES = list(range(-45, 46, 6))
PUMP_AT = [73, 350]
TROUGH = {0, 1, 2}

KEYS = ["id", "element", "landform", "society", "at", "y", "size", "yaw_deg", "verb", "ride_fact", "home",
        "recipe", "stamp", "hole", "budget", "routes", "fragment"]


def row(**kw):
    base = {"element": "ground", "landform": "sinkhole", "society": "mining", "y": None, "verb": "roll",
            "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": False, "budget": "landform",
            "routes": [], "fragment": ""}
    base.update(kw)
    return {k: base[k] for k in KEYS}


def polar(r, deg):
    a = math.radians(deg)
    return [round(CENTRE[0] + r * math.sin(a), 1), round(CENTRE[1] - r * math.cos(a), 1)]


def ring_rows(old):
    mid = (R_IN + R_OUT) * 0.5
    step = 360.0 / SEGMENTS
    length = round(2.0 * R_OUT * math.sin(math.radians(step * 0.5)) + 0.2, 1)
    out = []
    for k in range(SEGMENTS):
        deg = k * step
        first = k == 0
        out.append(row(
            id="gallery_ring" if first else "gallery_ring_%d" % (k + 1),
            element="ledge", at=polar(mid, deg), size=[length, 0, R_OUT - R_IN],
            yaw_deg=round((90.0 - deg + 180.0) % 360.0 - 180.0, 1), ride_fact="ride_ledge",
            home=old["home"] if first else "", recipe="scatter" if k in TROUGH else "landmark", stamp="plateau",
            routes=[r for r in old["routes"] if r != "gallery_lap"] + ["gallery_lap"] if first else ["gallery_lap"],
            fragment=old["fragment"] if first else ""))
    return out


def cut_rows():
    out = []
    for n, (x0, x1) in enumerate(zip(CUT_EDGES, CUT_EDGES[1:]), 1):
        inner = 0.0 if x0 < 0 < x1 else min(abs(x0), abs(x1))
        length = math.ceil(CENTRE[1] + math.sqrt(CUT_R * CUT_R - inner * inner)) - CUT_Z0
        out.append(row(id="gallery_cut_%d" % n, element="ground", at=[(x0 + x1) * 0.5, CUT_Z0 + length * 0.5],
                       size=[length, -100, x1 - x0], yaw_deg=0, stamp="plateau"))
    return out


def dumps(obj):
    return json.dumps(obj, ensure_ascii=False)


def main():
    lines = PARK.read_text().split("\n")
    generated = re.compile(r'^  \{"id": "(gallery_ring_\d+|gallery_cut_\d+|gallery_post_\d+)"')
    lines = [ln for ln in lines if not generated.match(ln)]
    lines = [ln for ln in lines if not ln.startswith('  {"id": "gallery_lap", ')]
    at = next(i for i, ln in enumerate(lines) if ln.startswith('  {"id": "gallery_ring", '))
    old = json.loads(lines[at].rstrip(","))
    new = cut_rows() + ring_rows(old)
    lines[at:at + 1] = ["  " + dumps(r) + "," for r in new]
    if not lines[at + len(new) - 1 + 1].lstrip().startswith("{"):
        lines[at + len(new) - 1] = lines[at + len(new) - 1].rstrip(",")
    pump = next(i for i, ln in enumerate(lines) if ln.startswith('  {"id": "pump_gallery", '))
    tail = "," if lines[pump].endswith(",") else ""
    p = json.loads(lines[pump].rstrip(","))
    p["at"] = PUMP_AT
    lines[pump] = "  " + dumps(p) + tail
    warden = next(i for i, ln in enumerate(lines) if ln.startswith('  {"id": "warden_line", '))
    lap = {"id": "gallery_lap", "from": "gallery_ring", "to": "landmark",
           "via": ["gallery_ring"] + ["gallery_ring_%d" % (k + 1) for k in range(1, SEGMENTS)]}
    lines.insert(warden + 1, "  " + dumps(lap) + ",")
    text = "\n".join(lines)
    json.loads(text)
    PARK.write_text(text)


if __name__ == "__main__":
    main()
