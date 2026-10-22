# park_pit dressing, wave 18 re-proof

## What and why

The pit's props dress a working open-pit mine. The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The crew sites read as plush crews living among working giants, and the scale contrast is the point.

Brief citation: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269), pit section: windsock, "Tag it tall; keep 30 m from lines".

Base: pit branch head 6311cec8, then the final merge of origin/stage/alpha-w18 f259e8cf421fc3c305b53ae104005dda40af9a41 and the Dressing foundation origin/claude/zealous-franklin-ed0sxr-lineclear e72fff7d96a88118e622f30658bcddb3105ae206 (merge commits, no conflicts; ART-MISTAKES.md identical to stage). The plan check on the merged head gives fingerprint 795077205 = the file pin, so the w18d audit stands (the props and placement path did not change). No `--open` windows were used, so there is nothing for `density_open_checked`/`density_open_rejected` to report.
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
- run_tier_test: FAIL, 21 of 192 checks, fresh-process Continue children timed out (867 s run). Measured base-red: the clean stage b0e64a40 fails it the same way at load 17 (8 of 192, all `[runtime child seed N] exit=-1 timeout=true`). Outside this unit's files.
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


## Reference boards

Boards (all opened and viewed), per ruling 6330671507:
- `docs/art/reference/dig/dig-props-moodboard.jpg`, `dig/dig-crew-moodboard.jpg`, `dig/dig-landmark-headframe-noon.jpg`;
- `docs/art/reference/style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`;
- `docs/art/reference/pilots/pilots-balls-heft-moodboard.jpg` (relative scale only).

Boards settle look only, never mechanics, scale numbers or collision. Kit recipe: `tools/blender/park/props/pit.py` (colours at lines 22-45, `kit.py` `C` at line 59); manifest: `assets/models/park/props/pit/manifest.json`.

**Palette roles.** The pit kit sits in the props board's Sandstone, Oxide, Charcoal, Bone panels, not exactly in hex: OCHRE a8905a, OXIDE 8a5a44, HOST 7d8678, TAILS d8d2c0, plus `kit.py` sandstone c6a274 (exact board hex), charcoal 242a28 (exact), bone d2c5a5 (exact), canvas, timber, iron and plant greens (SAGE, leaf). Outside the board's palette: VEIN 4f9c92 (a dull turquoise used only as thin copper-carbonate veins on rock and core trays, `pit.py` lines 32, 106, 679-705; it is not within 0.08 of Mint 8bf0d3, which `kit.py` enforces), HOST grey-green rock and the plant greens (not Ancient 9dff3c; guarded the same way). No Petrol 365754 enamel panels and no Copper b77843 fittings appear, which the board's machine props have (see drift).

**Shape language.** Broad worn blocks and stout posts, rounded soft-style boulders and bursage, low-poly "hard" iron fittings with no sharp pickets (`pit.py` kinds `haul_truck`, `rope_drum_wagon`, `shift_bell`, `lunch_shelf`, `assay_bench`, `ore_cart_stub`, `water_tank`, `timber_lagging`). The crew board's soft rounded toy crews are not modelled here; the kit supplies their leavings (lunch shelf, shift bell, bench sign, lagging) beside working giants. That fits the machine lore: the giants are the humans' utility fleet, and the crew sites read as plush crews living among working giants, scale contrast the point.

**Materials.** No brass anywhere: grep of `pit.py` for brass and d9b44a is empty, and `kit.py` warns on that hex (Fleet only). Fittings are iron, iron_light and timber, not copper or brass.

**Scale to the pilot ball.** The ball radius is 1.0 (`src/movement/tuning.gd:95`, `src/world/park/anchors/anchor_fit.json` ball_radius_m), so its diameter is 2.0 on the pilots data; relative only. Manifest heights: small kinds sit under one ball (bench_sign b 0.49, timber_lagging a/b 0.33-0.51, core_trays 0.94-0.99, shift_bell b 0.98); mid kinds run about 1 to 1.5 balls (lunch_shelf 1.29-1.37, ore_cart_stub 1.56-1.81, assay_bench 1.82-1.93, rock_bucket 1.41-2.43, bursage 0.8-1.5, cholla 1.16-2.09); tall kinds 1.5 to 1.9 balls (shift_bell a 2.56, water_tank 2.90, windsock a 3.07); the machines 2.6 to 4.8 balls (drill_rig_wreck 5.16-5.32, rope_drum_wagon 5.75-5.91, haul_truck 6.50-9.65). No new metres asserted.

**Avoid list, checked against the kit recipe and manifest.**
- No emission: `kit.py` line 567 asserts no GLB material has `emissiveFactor`; manifest grep for emis gives 0; `pit.py` header states the lamp veto.
- No hazard stripes or coral: `kit.py` BANNED (ff5a3c, 9dff3c, 8bf0d3) plus the 0.08 near-colour rule reject them at build; grep of `pit.py` for hazard, coral, ff5a3c is empty. The windsock sock has bands of canvas, charcoal and sandstone (`pit.py` line 627), none a hazard colour.
- No cache-shaped containers: grep for crate, chest and cache is empty; the containers are open core trays, a bucket, a cart stub and a lunch shelf, none a lidded loot box. I judged shape from the recipe, not from a render.
- No taut or decorative grapple cables: the rope tail is "coiled flat, never taut" (`pit.py` lines 358-362); the water tank's `cable` pieces are a dark hose and rods (lines 546-551), not strung rope; the windsock has no cable.
- No fake ride surfaces: no kit kind is a ramp, rail or flat deck; the kit has no collision, and `windsock` carries `line_clear_m: 30` so tall masts stay off lines.
- No glowing lamps: `haul_truck` story says every lamp is dark; no lamp geometry.
- No ancient-green or uranium-green: greens are muted sage and leaf; see the Ancient/Mint guard above.
- Highdraft items (closed furnace mouths, slack nets) do not apply to the pit.

**GROUNDING.md (main cb534a2d) rows read** (`docs/art/reference/GROUNDING.md`):
- 195: headframe legs solid; World's rows, not dressed here (no headframe props touched).
- 196: hoist as a moving machine; Animation's, not copied into props.
- 197: shallow collar dish; kept clear, only World's.
- 198: terraced faces and parked haul vehicles as history; `haul_truck` is parked dead, not traffic.
- 205: work clusters in recesses off the carve line; vignette clusters stay clear (plan check keepouts); hoist bearing and sorting screen are not modelled.
- 206: coil stores and pump manifold are look only; `rope_drum_wagon` rope lies flat, not a grapple point.
- 211: crew shapes soft and rounded; the kit stays soft, no sharp nubs.
- 213: open-sky daylight, unlit lamps; the lamp veto holds.
- 214: mining infrastructure as a playground; the props leave routes alone.
- 215: crew alcove subordinate to the headframe; pit vignettes stay off the headframe swing rows and now off the telegraph zones.

None of the rows read is a Conflict row, so none is "not copied".

**Board drift (for review).** The props board shows machines in Petrol enamel with Copper fittings (hoist bearing, coil stores, pump manifold); the pit kit has neither Petrol nor Copper fittings and substitutes ochre, oxide and grey-green host. VEIN 4f9c92 is also outside the board's palette. I did not change the kit; the reviewer decides FAIL and the ART-MISTAKES line.
