# park_pit dressing, wave 18 re-proof

> **Historical wave-18/20 dressing receipt:** Live prop placement and pins live in `sketches/core-loop/src/world/park/props/park_pit.json`, `sketches/core-loop/tests/fixtures/pins/park_pit.pin`, and [DRESSING-KITS.md](../DRESSING-KITS.md).

## What and why

The pit's props dress a working open-pit mine. The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The crew sites read as plush crews living among working giants, and the scale contrast is the point.

Brief citation: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269), pit section: windsock, "Tag it tall; keep 30 m from lines".

Base: pit branch head 6311cec8, then the final merge of origin/stage/alpha-w18 f259e8cf421fc3c305b53ae104005dda40af9a41 and the Dressing foundation origin/claude/zealous-franklin-ed0sxr-lineclear e72fff7d96a88118e622f30658bcddb3105ae206 (merge commits, no conflicts; ART-MISTAKES.md identical to stage). The plan check on the merged head gave fingerprint 795077205; the w18m spot moves (below) change it to 3124860388 = the file pin, so the density audit was re-run (w18m). No `--open` windows were used, so there is nothing for `density_open_checked`/`density_open_rejected` to report.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_pit --check`: 1166 instances (207 litter), 0 violations, fingerprint 3124860388. Pin 3170188153 to 3124860388. Spots now face their named row within 15 degrees; pit_011 moved from (-409, -494) to (-409, -492), 2 m, yaw -98.5, the bearing to wash_berm from the new point. Facing wash_berm from the old point put a cholla within 3.9 m of dump_wash_2 (keepout); that move clears it, with no yaw turn away from the row. Before the move the merged rules gave 8 violations, all `telegraph`, in two spots.

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
- 2026-10-21 Coordinator, #231/#234 (a PASS receipt older than a drop is void): the audit was run on this tree; the spot moves changed the plan fingerprint (795077205 to 3124860388), so the audit was re-run on this tree (w18m).
- 2026-10-21 Modeling, anchor gap tool (run commands exactly as written): every command in this note was run as written.
- 2026-10-19 World, #219 flush lanes (look at a capture before calling it done): I rendered and viewed the previews of four recoloured kinds next to the board; they are Blender renders, not game captures, and said so.
- 2026-10-21 Grading, #241 mapping claim (judged by eye on a resized still): I make no clipping or colour-accuracy claim from the resized contact sheet; colours come from the recipe constants and the guard, not from the still.


## Tests (each run alone, GODOT_BIN 4.7.2, on the merged head; box load average about 20)

- PASS: park_props_test, park_park_pit_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test (exit 0, "0 tests lack a verdict line").
- scatter_rows_test: 94 of 95 checks pass; the one failure is the main-thread step timing (24.29 ms against 8 ms) under load, and the old-map scatter hash check passes. The smoke run also hit its 180 s cap.
- run_tier_test: FAIL, 21 of 192 checks, fresh-process Continue children timed out (867 s run). Measured base-red: the clean stage b0e64a40 fails it the same way at load 17 (8 of 192, all `[runtime child seed N] exit=-1 timeout=true`). Outside this unit's files.
- `npm run sketch:lint`: pass, 0 findings. `npm run check:docs`: pass, 178 Markdown files, 0 failures.

## Audit (w18m, default run, mid camera, step 25 m, 169 samples; run on the tree whose plan fingerprint is 3124860388)

- density: 27 of 31 windows pass (4 exempt: 1 arena, 2 camp, 1 telegraph), no failing windows. Before: 27 of 31, 4 exempt, none failing.
- props-only draw delta: max 71, median 25.0 (w18d: 69, 25.0). draw calls max 374, median 298.0, p95 352.8.
- bare share 21.9 percent (before 21.3), void poses 0.

## Pose replay (from the w18d run; not repeated for w18m, whose only art-relevant change is pit_011 and the spot yaws) (before = same tree, `props/park_pit.json` moved aside, same poses; after = default run stills)

The default run wrote 11 stills (12 requested, one pose de-duplicated). Pixel change (share of pixels with a channel difference over 12):
106,-299 1.48; 126,-150 0.12; 135,-122 3.77; 148,-150 0.30; 153,-37 0.18; 21,-257 1.81; 47,205 0.38; 63,15 1.78; 79,337 0.41; 87,174 0.07; 9,-501 0.36. Median 0.38.
The poses are the barest places, mostly inside keepouts and over greybox rows. Props-off replay draws: max 354, median 280.

Stills: `artifacts/local/dressing/pit/w18/{before,after}/park_pit/`, sheet `artifacts/local/dressing/pit/w18/before_after.png` (local, not committed).


## Reference boards

Boards (all opened and viewed), per ruling 6330671507:
- `docs/art/reference/dig/dig-props-moodboard.jpg`, `dig/dig-crew-moodboard.jpg`, `dig/dig-landmark-headframe-noon.jpg`;
- `docs/art/reference/style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`;
- `docs/art/reference/pilots/pilots-balls-heft-moodboard.jpg` (relative scale only).

Boards settle look only, never mechanics, scale numbers or collision. Kit recipe: `tools/blender/park/props/pit.py` (colours at lines 24-39, `kit.py` `C` at line 59); manifest: `assets/models/park/props/pit/manifest.json`.

**Palette roles** (after the recolour in `pit.py`, from grepping each kind's colour calls; the constants OCHRE and OXIDE keep their names but now hold board colours):
- Petrol 365754 (OCHRE, OCHRE_DARK = shade 0.8, `pit.py` lines 24-25): the body of every machine kind. `haul_truck` body, cab and sunshade deck (149, 187), `drill_rig_wreck` engine house, cab and the whole mast boom (266-298), `ore_cart_stub` body (492), `water_tank` barrel and dome (532-533), `rock_bucket` shell (650).
- Oxide 9b513a (OXIDE, OXIDE_DARK = shade 0.78, lines 26-27): patches and bands only. `haul_truck` bed rims, canopy, cab roof and rib strips (`trim`, 150-215), `drill_rig_wreck` boom rib bands (290, 303) and track hubs, `ore_cart_stub` variant c's blend (35 percent), `shift_bell` clapper (387), tyre hubs (133), `water_tank` strap marks (539). No large face of a machine kind is oxide.
- Bone d2c5a5, one panel per machine kind: `haul_truck` front grille plate (172), `drill_rig_wreck` cab roof panel (275), `ore_cart_stub` side rails (497), `water_tank` hatch cap (536). It is recoloured parts, no geometry added. `bench_sign` and the tailings still use bone/TAILS (584, 229, 314).
- Copper b77843, small fittings only: `haul_truck` ram rods (223), `shift_bell` bell (385), `water_tank` hoops (535) and hose-reel cheeks (545). The build prints 15 colour-guard warnings, all "#b77843 is AMBER/COPPER/BRASS; never dominant", and no error; the guard otherwise passed (no banned hex, none within 0.08 of one, no hazard-like colour).
- Charcoal 242a28 and `cable` 2a3231: tyres, hose, windsock band (`haul_truck` 153, `drill_rig_wreck` 265, `assay_bench` 467, `water_tank` 546, `windsock` 628).
- Sandstone c6a274: windsock band only (628); host rock HOST 7d8678 and TAILS d8d2c0 are the pit-local ground and tailings, not board panels.
- VEIN is now 365754 (petrol), no longer a turquoise: thin veins on `rock(vein=True)` (106) and `core_trays` (679-705) read as petrol streaks, the board's own colour, and the no-op `mix(HOST, VEIN, 0.0)` is gone.
- Outside the board palette: timber, canvas, iron and the plant greens (SAGE, leaf), as before. Nothing is within 0.08 of Hazard, Ancient or Mint.

**Shape language.** Broad worn blocks and stout posts, rounded soft-style boulders and bursage, low-poly "hard" iron fittings with no sharp pickets (`pit.py` kinds `haul_truck`, `rope_drum_wagon`, `shift_bell`, `lunch_shelf`, `assay_bench`, `ore_cart_stub`, `water_tank`, `timber_lagging`). The crew board's soft rounded toy crews are not modelled here; the kit supplies their leavings (lunch shelf, shift bell, bench sign, lagging) beside working giants. That fits the machine lore: the giants are the humans' utility fleet, and the crew sites read as plush crews living among working giants, scale contrast the point.

**Materials.** No brass anywhere: grep of `pit.py` for brass and d9b44a is empty, and `kit.py` warns on that hex (Fleet only). Copper b77843 appears on four small fittings (the ram rods, `pit.py` line 223; the bell, line 385; the tank hoops, line 535; the reel cheeks, line 545), warned never-dominant by `kit.py` (line 72); no brass; other fittings are iron, iron_light and timber.

**Scale to the pilot ball.** The ball radius is 1.0 (`src/movement/tuning.gd:95`, `anchor_fit.json` ball_radius_m), so its diameter is 2.0 m; ratios below are to that diameter, relative only. Ratios are manifest height / 2.0. Small kinds sit under one ball: bench_sign b 0.493 / 2.0 = 0.25, timber_lagging a 0.334 / 2.0 = 0.17 and b 0.506 / 2.0 = 0.25, core_trays 0.943-0.988 / 2.0 = 0.47-0.49, shift_bell b 0.976 / 2.0 = 0.49, lunch_shelf 1.291-1.365 / 2.0 = 0.65-0.68, bursage 0.796-1.508 / 2.0 = 0.40-0.75, ore_cart_stub 1.556-1.805 / 2.0 = 0.78-0.90, assay_bench 1.822-1.925 / 2.0 = 0.91-0.96. Mid kinds run 0.58 to 1.21 balls: bench_sign a 1.429 / 2.0 = 0.71, timber_lagging c 1.308 / 2.0 = 0.65, windsock b 1.503 / 2.0 = 0.75, cholla 1.162-2.094 / 2.0 = 0.58-1.05, rock_bucket 1.406-2.426 / 2.0 = 0.70-1.21. Tall kinds run 1.28 to 1.53 balls: shift_bell a 2.56 / 2.0 = 1.28, water_tank 2.895-2.899 / 2.0 = 1.45, windsock a 3.068 / 2.0 = 1.53. The machines run 2.58 to 4.82 balls: drill_rig_wreck 5.158-5.316 / 2.0 = 2.58-2.66, rope_drum_wagon 5.75-5.914 / 2.0 = 2.88-2.96, haul_truck 6.498-9.649 / 2.0 = 3.25-4.82. No new metres asserted.

**Avoid list, checked against the kit recipe and manifest.**
- No emission: `kit.py` line 567 asserts no GLB material has `emissiveFactor`; manifest grep for emis gives 0; `pit.py` header states the lamp veto.
- No hazard stripes or coral: `kit.py` BANNED (ff5a3c, 9dff3c, 8bf0d3) plus the 0.08 near-colour rule reject them at build; grep of `pit.py` for hazard, coral, ff5a3c is empty. The windsock sock has bands of canvas, charcoal and sandstone (`pit.py` line 628), none a hazard colour.
- No cache-shaped containers: grep for crate, chest and cache is empty; the containers are open core trays, a bucket, a cart stub and a lunch shelf, none a lidded loot box. I judged shape from the recipe, not from a render.
- No taut or decorative grapple cables: the rope tail is "coiled flat, never taut" (`pit.py` lines 358-362); the water tank's `cable` pieces are a dark hose and rods (lines 546-551), not strung rope; the windsock has no cable.
- No fake ride surfaces: no kit kind is a ramp or rail, and the kit has no collision. The one flat top is the `haul_truck` level sunshade deck on four stout posts above the cab (`pit.py` lines 183 and 187, a flat 3.8 m top, perch at 212), which carries the manifest `perch` ([-1.5, 6.498, 2.157] on variant a, checked by `park_props_test`). That is allowed because DRESSING-KITS.md (Perch anchors, line 81) requires every variant 6 m or taller to carry a `perch` on its top surface; the deck is that top surface, a landing point the kit contract asks for, not a lane or ride surface. `windsock` carries `line_clear_m: 30` so tall masts stay off lines.
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

**Board drift (for review).** The two earlier items (large oxide areas on `water_tank` and `drill_rig_wreck`; absent bone panels) are fixed in the second recolour commit. Remaining: (1) the `windsock` story was rewritten to match variant a's stiff cone (`pit.py` line 619); the geometry, GLBs and bounds are unchanged (manifest radius 1.8, height 3.068); (2) the bone panels are single recoloured parts, so on `drill_rig_wreck` the bone cab roof reads as a pale cream block rather than a label plate; (3) previews are Blender flat-lit renders, not game captures. The reviewer decides FAIL and the ART-MISTAKES line.

**Recolour previews.** Rendered with `pit.py --only haul_truck,drill_rig_wreck,water_tank,core_trays --preview-dir` to `artifacts/local/dressing/pit/preview/` (local, not committed), viewed next to `dig-props-moodboard.jpg` and `enemies/enemies-dig-moodboard.jpg`. Result: every machine body, cab, boom, dome and barrel is petrol; oxide shows as rims, canopy, rib bands and hubs; copper as hoops and cheeks; bone as a single plate. Against the enemies board (oxide and charcoal crawlers with brass plates, orange hazard rings), no machine kind in the pit kit still reads in the enemy colour role: the dominant colour is petrol where the enemies are oxide, and there is no brass or hazard colour. This is my reading of flat-lit renders; the reviewer should still check it in game. Manifest radius, height and tris are unchanged (in the recolour commit the manifest and registry fragments showed no diff; only the GLBs changed: drill_rig_wreck, haul_truck, ore_cart_stub, rock_bucket, water_tank).

## w18m row, yaw and label fixes (card (b), #323)

#323's check found 1 row and 3 yaw groups in pit at c371b7c4: the row pit_012, pit_389 and pit_396 (gaps 27.7 and 23.7 m, CV 0.078 as the check prints it); the yaw groups pit_011, pit_026 and pit_898, and pit_012, pit_028 and pit_396, all at -35.6; and pit_121, pit_123 and pit_125, all at 150.9. Each spot now faces a named row from `park_rows`, rounded to 1 degree (in the 0.5 case, to 0.5).

| Spot | `at` | Yaw | Faces |
| --- | --- | --- | --- |
| pit_011 | (-409, -494) to (-409, -492) | -35.6 to -98.5 | wash_berm |
| pit_026 | same | -35.6 to -118 | wash_berm |
| pit_898 | same | -35.6 to -104 | wash_berm, turned 13 degrees off its bearing (-117) so it does not link with pit_026 at 22 m |
| pit_012 | same | -35.6 to -44 | slickrock_15 |
| pit_028 | same | -35.6 to -66 | slickrock_15 |
| pit_396 | (-312, -418) to (-313.8, -418.9) | -35.6 to -56 | slickrock_15; the move takes the row's gaps to 21.7 and 29.7 m (CV over 0.1) |
| pit_389 | same | -35.6 to 32 | rim_haul_ramp |
| pit_121 | same | 150.9 to -119 | camp_dive_windrow_1 |
| pit_125 | same | 150.9 to -112 | camp_dive_windrow_1 |
| pit_123 | same | 150.9 to -6 | bench2_east_bank |

pit_011 moved 2 m north because facing wash_berm from its old point put a cholla 3.9 m from dump_wash_2 (keepout).

Labels: the lint flagged 55 `near` labels (25 cut mid-word, 30 with leading or trailing whitespace), and 4 more (the hoist-rope wagon ones) ended on a comma; each is now "<row id>: <the template story cut at the last whole word within 60 characters>". For example, pit_011 "wash_berm, bursage and cholla thickening along " is now "wash_berm: Bursage and cholla thickening along the haul road's edge", and pit_012 "slickrock_15, the fallen shift bell with its rope " is now "slickrock_15: The fallen shift bell with its rope tail, a sign board".

Results: pin 795077205 to 3124860388. #323's check (with its row-span fix af522720, run with `--file` on this copy) reports 0 violations, 0 pattern, 0 pin, 0 lint; the old check gives 0 violations and the same fingerprint; `park_props_test` passes (226 checks, pin line PASS). Density (w18m): 27 of 31 windows pass, 4 exempt (1 arena, 2 camp, 1 telegraph), none failing, the same as before.

## w18n kit cost cut (GPU row #252 6350030903, coordinator 6350036287)

The 4080 row failed on p99 (+2.07 ms against +1.0 ms), with the extra frames in the fight state (3, 3). The coordinator asked for a cut to the kit's cost and then one new pair per side. A headless probe (each park's expansion, park_props.gd's ranges and batching, a sphere with no frustum) put bursage and cholla first: 675 of the pit's 1166 instances, about a third of the kit's triangles from the arena ring (17 points within 50 m of the Warden anchor (0, 255)), and over half on the ride lines. Hero shadows were already zero there.

Only those two kinds changed. Their blobs and knobs are now 80-tri icos with no subsurf, in place of 20-tri icos under one subsurf (120). Each bursage mound drops a blob and a stem, bursage_b drops two of its five straw stems, each cholla keeps one of its three trunk knobs and gets a 6-sided trunk (6 is the fewest sides the subsurf rounds off; 5 sides crease at 72 degrees, over crease_angle 70), and cholla_c's mat has 4 joints, not 6. The look checked against the kit previews before and after: same mounds, colours and silhouettes.

| Variant | LOD0 tris before | after |
|---|---|---|
| bursage_a / b / c | 2072 / 1712 / 2548 | 908 / 816 / 1356 |
| cholla_a / b / c | 1092 / 2484 / 2472 | 680 / 1368 / 1516 |

LOD1 and LOD2 follow (50% and 14 to 15% of LOD0). Footprint radii grow by up to 0.10 m (bursage_b 0.998 to 1.099), which drops one bursage litter instance: 1165 instances (206 litter), fingerprint 3124860388 to 3367089674, re-pinned.

Probe, kit triangles in view (draws unchanged): arena ring median 55,732 to 43,873 and peak 96,044 to 71,019; ride lines (44 points, one per 40 m) median 181,882 to 132,546 and peak 282,564 to 203,701. These are estimates, not frame costs; the new GPU pair is the test.

Density audit on the cut (default run, mid camera, step 25 m): 27 of 31 windows pass, 4 exempt, none failing, the same as before; dressing in view within 120 m (median 56) and distinct kinds (median 15) are unchanged. Its props-only primitive delta (OpenGL on cloud llvmpipe, a proxy, not a frame cost) falls from a median of 57,071 to 33,477 and a peak of 172,072 to 139,700. Props-only draws are 24 to 25 at the median, 70 to 69 at the peak.
