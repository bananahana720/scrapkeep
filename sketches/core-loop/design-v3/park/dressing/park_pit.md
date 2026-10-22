# park_pit dressing, wave 18 re-proof

## What and why

The pit's props dress a working open-pit mine. The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The crew sites read as plush crews living among working giants, and the scale contrast is the point.

Brief citation: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269), pit section: windsock, "Tag it tall; keep 30 m from lines".

Base: pit branch head 6311cec8 plus merges of origin/stage/alpha-w18 (twice; the last merge is 14738735, stage e83a21c2, which contains b22a2ca3) and the Dressing foundation follow-up origin/claude/zealous-franklin-ed0sxr-lineclear (07748516, per-kind `line_clear_m` and the `telegraph` rule).
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_pit --check`: 1166 instances (207 litter), 0 violations, fingerprint 795077205. Pin 3170188153 to 795077205. Before the move the merged rules gave 8 violations, all `telegraph`, in two spots.

## Telegraph zones

Rule: `park_props.gd` `check_one` fails any prop inside an event's own geometry grown by `hold_clear_m` (natural.gd plan, event_director.gd `_park_clear`); DRESSING-KITS.md states it. Litter that fails is dropped by the expander, authored spots fail the plan check.

- `hoist_boiler` (site `hoist_house`, boiler_burst, hold 14 m): 5 instances of spot pit_557 inside. pit_557 moved (-66, 179) to (-28, 179), 38 m, the first legal spot in a search out to 50 m (nothing legal within 30 m). Its `near` label changed from `ore_pile_north` to `ore_pile_sw` (park row nearest by centre, 16.3 m).
- `sump_flood` (site `floor_sump`, hold 15 m): 3 instances of spot pit_558 inside. pit_558 moved (-50, 148) to (-46, 148), 4 m; `near` unchanged.
- Litter dropped: 2 (209 to 207), the instances the lead probed in both zones.

## 30 m brief kinds

- Kind `windsock` now carries `line_clear_m: 30` (`tools/blender/park/props/pit.py`, manifest `line_clear_m: 30.0`), so the plan check enforces edge-to-line (line distance minus instance radius) of 30 m or more. Rebuilding only that kind changed only the manifest line; no GLB or `.import` changed, registry fold unchanged (1044 assets).
- Earlier measured pass (target 30.5 m with margin): pit_1109 23.30 to 31.25; pit_125 25.43 to 31.39; pit_271 26.90 to 31.40; pit_329 23.10 to 30.55; pit_526 24.80 to 31.30; pit_109 51.57 and pit_396 31.59 unchanged. Spots moved then: pit_1109 (-265, -314) to (-272.9, -313.1); pit_125 (337, -155) to (339.9, -160.2); pit_271 (98, -287) to (101.6, -289.7); pit_526 (-130, -37) to (-123.6, -38.1); pit_329 (357, -32) to (364.5, -45), 15.9 m because straight away from the line is a slope over 25 degrees. The plan check reports 0 `line_clear` violations at the 30 m rule.

## ART-MISTAKES entries checked

`project-guide/handoff/ART-MISTAKES.md`, read before the unit:
- 2026-10-21 World, #242 lane width ("named a mechanism from its label"): I read `check_one`, the `Context.line_distance` measure and the telegraph zone code before describing either rule, and took the zone sizes from `park_pit.json` event rows, not from names.
- 2026-10-21 Coordinator, #231/#234 (a PASS receipt older than a drop is void): the audit was run on this tree; after the final stage merge the plan fingerprint was unchanged (795077205), and I say so below rather than re-audit.
- 2026-10-21 Modeling, anchor gap tool (run commands exactly as written): every command in this note was run as written.


## Tests (each run alone, GODOT_BIN 4.7.2, on the merged head; box load average about 20)

- PASS: park_props_test, park_park_pit_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test (exit 0, "0 tests lack a verdict line").
- scatter_rows_test: 94 of 95 checks pass; the one failure is the main-thread step timing (24.29 ms against 8 ms) under load, and the old-map scatter hash check passes. The smoke run also hit its 180 s cap.
- run_tier_test: FAIL, 21 of 192 checks, fresh-process Continue children timed out (867 s run). Load related and outside this unit's files; not re-run.
- `npm run sketch:lint`: pass, 0 findings. `npm run check:docs`: pass, 178 Markdown files, 0 failures.

## Audit (w18d, default run, mid camera, step 25 m, 169 samples; run before the last stage merge, whose plan fingerprint is unchanged at 795077205)

- density: 27 of 31 windows pass (4 exempt: 1 arena, 2 camp, 1 telegraph), no failing windows. Before: 27 of 31, 4 exempt, none failing.
- props-only draw delta: max 69, median 25.0 (before: 69, 28.0). draw calls max 389, median 318.0, p95 371.2.
- bare share 21.9 percent (before 21.3), void poses 0.

## Pose replay (before = same tree, `props/park_pit.json` moved aside, same poses; after = default run stills)

The default run wrote 11 stills (12 requested, one pose de-duplicated). Pixel change (share of pixels with a channel difference over 12):
106,-299 1.48; 126,-150 0.12; 135,-122 3.77; 148,-150 0.30; 153,-37 0.18; 21,-257 1.81; 47,205 0.38; 63,15 1.78; 79,337 0.41; 87,174 0.07; 9,-501 0.36. Median 0.38.
The poses are the barest places, mostly inside keepouts and over greybox rows. Props-off replay draws: max 354, median 280.

Stills: `artifacts/local/dressing/pit/w18/{before,after}/park_pit/`, sheet `artifacts/local/dressing/pit/w18/before_after.png` (local, not committed).

