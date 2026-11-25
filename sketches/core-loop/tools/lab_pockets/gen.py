"""Lab pockets for Challenge's pocket-against-mobility sweeps: five mojulo recipes and their ball proofs.

Lab-only geometry (board #241, Challenge option (a)): never in assets/registry.json or a shipping list, and the
folder's .gdignore keeps Godot from importing or exporting it. Build: python3 tools/lab_pockets/build.py (see README.md).

Authored in metres in mojulo's frame (x along travel, y lateral, z up) and emitted as workbench specs in cm. Writes
recipes/<shape>.json and proofs.json, which tests/lab_pockets_test.gd runs.

Numbers the sizes rest on (sketches/core-loop unless named):
  ball collision radius 0.92, gravity 26        src/movement/ball_rules.gd, tuning.gd
  cruise 14, blazing 26.6, fast 37 m/s          tuning.gd, speed_tier.gd, design-v3/TRAVERSAL.md (bot at the marble run)
  lattice 8 m: every footprint is whole cells   park_graph.gd
  half pipe section: half_pipe_concrete         tools/blender/park/halfpipes.py Concrete (F 6, R 6, H 10, batter 0.08, grade 3%)
  ride paths >= 3.52 m over walkable ground,    project-guide/handoff/DECISIONS.md, map design veto pass, 23 Oct
  slick guide walls in chokes                   (same ruling)
"""
import json
import math
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
R = 0.92
CRUISE, BLAZING, FAST = 14.0, 26.6, 37.0
ROCK, DECK, HAZARD, RAIL, SLICK = "#b98a5a", "#aaa89d", "#ff5a3c", "#4a7a8c", "#9fc4cf"
SEG = 40
RIDE_CLEAR = 3.52
KEEP = {"rotate", "t", "op", "kind", "id", "count"}


def cm(v, key=None):
    if key in KEEP:
        return v
    if isinstance(v, dict):
        return {k: cm(x, k) for k, x in v.items()}
    if isinstance(v, list):
        return [cm(x) for x in v]
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return round(v * 100, 2)
    return v


def box(c, s):
    return {"kind": "box", "center": c, "size": s}


def term(op, shape, tid=None):
    t = {"op": op, "shape": shape}
    if tid:
        t["id"] = tid
    return t


def field(fid, terms, tint=ROCK, material="stone"):
    return {"id": fid, "exact": True, "segments": SEG, "tint": tint, "material": material, "terms": cm(terms)}


def start(x, y, z_floor=0.0):
    return [x, y, round(z_floor + R + 0.02, 3)]


def vel(speed, yaw_deg):
    a = math.radians(yaw_deg)
    return [round(speed * math.cos(a), 3), round(speed * math.sin(a), 3), 0.0]


SHAPES = {}


def shape(name, cells, size_m, spec, cases, note):
    SHAPES[name] = {"cells": cells, "size_m": size_m, "spec": {"units": "cm", **spec}, "cases": cases, "note": note}


HP_F, HP_R, HP_H, HP_B, HP_GRADE, HP_LEN = 6.0, 6.0, 10.0, 0.08, 0.03, 64.0
half = [(0.0, 0.0), (HP_F, 0.0)]
half += [(HP_F + HP_R * math.cos(math.radians(a)), HP_R + HP_R * math.sin(math.radians(a))) for a in range(-81, 1, 9)]
xw = HP_F + HP_R
half += [(xw + 2.0 * HP_B, HP_R + 2.0), (xw + 3.0 * HP_B, HP_R + 3.0), (xw + (HP_H - HP_R) * HP_B, HP_H), (xw + (HP_H - HP_R) * HP_B + 0.6, HP_H + 2)]
HP_CREST = xw + (HP_H - HP_R) * HP_B
cut = [[round(y, 4), round(z, 4)] for y, z in half[::-1]] + [[round(-y, 4), round(z, 4)] for y, z in half[1:]]
cut = [[y, z] for y, z in cut if not (y == 0.0 and z == 0.0)]
HP_TILT = math.degrees(math.atan(HP_GRADE))
shape("half_pipe", "8x4", [64, 32], {"fields": [
    field("pipe", [{"op": "transform", "rotate": [0, HP_TILT, 0], "translate": [0, 0, 0], "terms": [
        term("add", box([HP_LEN / 2, 0, (HP_H - 2) / 2], [HP_LEN, 32, HP_H + 2]), "deck"),
        term("subtract", {"kind": "extrude", "profile": {"points": cut},
                          "axisFrom": {"x": -1, "y": 0, "z": 0}, "axisTo": {"x": HP_LEN + 1, "y": 0, "z": 0}}, "channel")]}], DECK)]},
    {"entry-drop": {"start": start(1, 0), "vel": vel(8, 0), "seconds": 8, "min_speed": 2.0,
                    "pass": {"exit_box": [[63, -12.4, -4], [80, 12.4, 12]], "stay_box": [[-1, -12.4, -4], [80, 12.4, 12]]}},
     "off-centre": {"start": start(1, 7.5, 0.6), "vel": vel(8, 0), "seconds": 8, "min_speed": 2.0,
                    "pass": {"exit_box": [[63, -12.4, -4], [80, 12.4, 12]], "stay_box": [[-1, -12.4, -4], [80, 12.4, 12]]}},
     "cruise-carve": {"start": start(1, 0), "vel": vel(CRUISE, 20), "seconds": 6,
                      "pass": {"exit_box": [[63, -12.4, -4], [80, 12.4, 14]], "stay_box": [[-1, -12.4, -4], [80, 12.4, 14]]}},
     "fast-carve": {"start": start(1, 0), "vel": vel(FAST, 20), "seconds": 4,
                    "pass": {"exit_box": [[63, -12.4, -4], [200, 12.4, 14]], "stay_box": [[-1, -12.4, -4], [200, 12.4, 14]]}},
     "control-fast-steep": {"start": start(1, 0), "vel": vel(FAST, 70), "seconds": 4, "expect": "fail",
                            "pass": {"exit_box": [[63, -12.4, -4], [200, 12.4, 14]], "stay_box": [[-1, -12.4, -4], [200, 12.4, 14]]}}},
    "The park's concrete channel section. Entry and off-centre drops at 8 m/s ride it out without stalling (the park test's"
    " roll); cruise and fast carve at 20 degrees; a 70 degree entry at 37 m/s clears the 10 m wall (control).")

HUMP = [[-10.5, -1], [10.5, -1]] + [[round(u, 3), round(1.5 * (1 + math.cos(math.pi * u / 10)), 3)] for u in [10 - i for i in range(21)]]
shape("rolling_wall", "4x3", [32, 24], {"fields": [
    field("roller", [term("add", box([16, 0, -0.5], [32, 24, 1]), "floor"),
                     {"op": "transform", "rotate": [90, 0, -23], "translate": [16, 0, 0],
                      "terms": [term("add", {"kind": "extrude", "profile": {"points": HUMP},
                                             "axisFrom": {"x": 0, "y": 0, "z": -17}, "axisTo": {"x": 0, "y": 0, "z": 17}}, "crest")]},
                     term("add", {"kind": "capsule", "a": [-2, -12, -2], "b": [34, -12, -2], "radius": 4}, "berm_w"),
                     term("add", {"kind": "capsule", "a": [-2, 12, -2], "b": [34, 12, -2], "radius": 4}, "berm_e"),
                     term("intersect", box([16, 0, 3.5], [32, 24, 9]), "trim")])]},
    {"cruise-over": {"start": start(1, 0), "vel": vel(CRUISE, 0), "seconds": 5,
                     "pass": {"exit_box": [[31, -12, -1], [60, 12, 12]]}},
     "fast-jump": {"start": start(1, 0), "vel": vel(FAST, 0), "seconds": 4,
                   "pass": {"exit_box": [[31, -60, -1], [200, 60, 30]], "min_peak_z": 4.5}},
     "control-slow": {"start": start(1, 0), "vel": vel(6, 0), "seconds": 6, "expect": "fail",
                      "pass": {"exit_box": [[31, -12, -1], [60, 12, 12]]}}},
    "Cruise rolls over the 3 m crest; 37 m/s jumps it; 6 m/s rolls back (control).")

FUNNEL = [[-1, -8], [8, -2.5], [8, 2.5], [-1, 8]]
shape("crevice", "4x3", [32, 24], {"fields": [
    field("rock", [term("add", box([20, 0, 4], [24, 24, 8]), "block"),
                   term("subtract", box([20, 0, 2.5], [26, 5, 5]), "slick_slot"),
                   term("subtract", box([20, 0, 7], [26, 2, 4.2]), "sky_gap")]),
    field("slick_guide", [term("add", box([3.5, 0, 2.5], [9, 24, 5]), "slick_guide"),
                          term("subtract", {"kind": "extrude", "profile": {"points": FUNNEL},
                                            "axisFrom": {"x": 0, "y": 0, "z": -0.1}, "axisTo": {"x": 0, "y": 0, "z": 5.1}}, "slick_mouth")],
          SLICK, "steel"),
    field("floor", [term("add", box([16, 0, -0.5], [32, 24, 1]), "floor")])]},
    {"cruise-funnel": {"start": start(1, 4), "vel": vel(CRUISE, -10), "seconds": 5,
                       "pass": {"exit_box": [[31, -2.5, -1], [60, 2.5, 5]], "stay_box": [[-1, -8, -1], [60, 8, 5]]}},
     "fast-funnel": {"start": start(1, 4), "vel": vel(FAST, -8), "seconds": 3,
                     "pass": {"exit_box": [[31, -2.5, -1], [200, 2.5, 5]], "stay_box": [[-1, -8, -1], [200, 8, 5]]}},
     "cruise-graze": {"start": start(1, 6), "vel": vel(CRUISE, -30), "seconds": 5,
                      "pass": {"exit_box": [[31, -2.5, -1], [60, 2.5, 5]], "stay_box": [[-1, -8, -1], [60, 8, 5]]}},
     "control-slow-graze": {"start": start(1, 6), "vel": vel(4, -60), "seconds": 5, "expect": "fail",
                            "pass": {"exit_box": [[31, -2.5, -1], [60, 2.5, 5]], "stay_box": [[-1, -8, -1], [60, 8, 5]]}}},
    "A choke: the slick guide walls turn an off-line entry into the 5 m slot without scrubbing speed (cruise graze at"
    " 30 degrees); 4 m/s at 60 degrees stalls in the mouth (control).")

PITS = [(8, -6), (14, 6), (20, -6), (26, 6)]
AVOID = [[[x - 3.5, y - 3.5, -3], [x + 3.5, y + 3.5, 0.85]] for x, y in PITS]
shape("hazard_field", "4x4", [32, 32], {"fields": [
    field("ground", [term("add", box([16, 0, -1], [32, 32, 2]), "floor")] +
          [term("subtract", {"kind": "sphere", "center": [x, y, 4.5], "radius": 6}, f"pit{i}") for i, (x, y) in enumerate(PITS)] +
          [term("add", {"kind": "capsule", "a": [-1, s * 16, -1.5], "b": [33, s * 16, -1.5], "radius": 3}, f"berm{j}")
           for j, s in enumerate((-1, 1))] +
          [term("intersect", box([16, 0, 1], [32, 32, 6]), "trim")])] +
    [field(f"hazard{i}", [term("add", {"kind": "sphere", "center": [x, y, 4.5], "radius": 6}, "hazard"),
                          term("intersect", box([x, y, -1.4], [9, 9, 0.4]), "hazard_cap")], HAZARD) for i, (x, y) in enumerate(PITS)]},
    {"cruise-lane": {"start": start(1, 0), "vel": vel(CRUISE, 0), "seconds": 4,
                     "pass": {"exit_box": [[31, -16, -2], [60, 16, 6]], "avoid_boxes": AVOID}},
     "fast-lane": {"start": start(1, 0), "vel": vel(FAST, 0), "seconds": 2,
                   "pass": {"exit_box": [[31, -16, -2], [200, 16, 6]], "avoid_boxes": AVOID}},
     "control-off-line": {"start": start(1, 0), "vel": vel(CRUISE, 12), "seconds": 4, "expect": "fail",
                          "pass": {"exit_box": [[31, -16, -2], [60, 16, 6]], "avoid_boxes": AVOID}}},
    "The straight lane misses every pit; a 12 degree line drops into one (control).")

RAIL_R = 0.25
RZ = RIDE_CLEAR + RAIL_R + 0.08
PILLARS = [(6, -7.8), (6, 7.8), (12, -10.3), (12, 10.3), (18, -7.8), (18, 7.8), (24, -10.3), (24, 10.3), (29, -7.8), (29, 7.8)]
RAILS = [[[2, s * 6, RZ], [10, s * 4, RZ + 0.4], [22, s * 4, RZ + 0.4], [30, s * 6, RZ]] for s in (-1, 1)]
shape("rail_grove", "4x3", [32, 24], {
    "fields": [field("grove", [term("add", box([16, 0, -0.5], [32, 24, 1]), "floor")] +
                     [term("add", {"kind": "capsule", "a": [x, y, 0], "b": [x, y, 6], "radius": 0.9}, f"pillar{i}")
                      for i, (x, y) in enumerate(PILLARS)])] +
              [field(f"rail_post{i}", [term("add", {"kind": "capsule", "a": [p[0], p[1], 0], "b": [p[0], p[1], p[2]], "radius": 0.18}, "rail_post")], RAIL, "steel")
               for i, p in enumerate(pt for r in RAILS for pt in r)],
    "sweeps": [{"path": cm(r), "radius": cm(RAIL_R), "sides": 10, "tint": RAIL, "material": "steel"} for i, r in enumerate(RAILS)]},
    {"cruise-lane": {"start": start(1, 0), "vel": vel(CRUISE, 0), "seconds": 4,
                     "pass": {"exit_box": [[31, -12, -1], [60, 12, 8]]}},
     "fast-lane": {"start": start(1, 0), "vel": vel(FAST, 0), "seconds": 2,
                   "pass": {"exit_box": [[31, -12, -1], [200, 12, 8]]}},
     "control-into-pillar": {"start": start(1, -7.8), "vel": vel(CRUISE, 0), "seconds": 4, "expect": "fail",
                             "pass": {"exit_box": [[31, -12, -1], [60, 12, 8]], "stay_box": [[-1, -9.5, -1], [60, -6, 8]]}}},
    "The floor lane passes under both rails, whose underside clears the floor by at least 3.52 m; riding a rail is a"
    " contraption, not physics, so it is not proven here.")


def main():
    (HERE / "recipes").mkdir(exist_ok=True)
    proofs = {}
    for name, s in SHAPES.items():
        (HERE / "recipes" / f"{name}.json").write_text(json.dumps(s["spec"], indent=1) + "\n")
        proofs[name] = {"cells": s["cells"], "size_m": s["size_m"], "note": s["note"], "cases": s["cases"]}
    meta = {"ball_radius": R, "gravity": 26.0, "ride_clear_m": RIDE_CLEAR, "rail_radius_m": RAIL_R,
            "half_pipe": {"floor_half_m": HP_F, "radius_m": HP_R, "wall_m": HP_H, "crest_half_m": round(HP_CREST, 3),
                          "grade": HP_GRADE, "length_m": HP_LEN}}
    (HERE / "proofs.json").write_text(json.dumps({"meta": meta, "shapes": proofs}, indent=1) + "\n")
    print(json.dumps({k: list(v["cases"]) for k, v in proofs.items()}))


if __name__ == "__main__":
    main()
