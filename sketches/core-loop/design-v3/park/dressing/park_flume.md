# park_flume dressing, wave 18 re-proof

> **Historical wave-18/20 dressing receipt:** Live prop placement and pins live in `sketches/core-loop/src/world/park/props/park_flume.json`, `sketches/core-loop/tests/fixtures/pins/park_flume.pin`, and [DRESSING-KITS.md](../DRESSING-KITS.md).

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the flume branch, then on 2026-10-22 merges of stage/alpha-w18 (b0e64a40, which holds b22a2ca3 and #175) and the line_clear_m/telegraph foundation (07748516); the commit "Apply flume line_clear_m and telegraph rules" (8d109d1c27a262dc1ea58493a853088e44215ef8) follows them. Final merge (2026-10-22): stage/alpha-w18 f259e8cf421fc3c305b53ae104005dda40af9a41, then the accepted foundation e72fff7d96a88118e622f30658bcddb3105ae206 (gate round 7), then the foundation's stage merge be6189ec5f5c8eb33591c33ecc76d72e56828394 (merge befacd65; the tree is unchanged). The foundation commits after 07748516 change only the audit, static checks and `park_props_test`, so the pin is unchanged (plan check fingerprint 4063400762 equals the pin). The w18d audit below stands: it ran on the current placement, and the later recolour changes colours only. No `--open` windows were run.
Brief: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269), flume section.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## What and why

Flume is the canal park. The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones, and some are looping workers. The dressing reads as plush crews living among those working giants, so the scale contrast is the point: small camps, laundry, tea and tool pegs at the foot of big machinery.
This unit keeps the camps honest to their rules. Washlines (laundry) stay 30 m clear of ride lines so they do not read as grind or grapple lines (KITS.md brief). Props stay out of the `bend_relic_wakes` telegraph so a waking relic never lands on a camp.

## Plan check

`tools/park_props_plan.gd --map=park_flume --check`: `park_props_plan: park_flume 1113 instances (433 litter), 0 violations, fingerprint 4063400762`. Pin history: 875855731 (merge), 1477437796 (density fix), 2392297130 (30 m moves), 4063400762 (line_clear_m plus telegraph).
The expected `scatter_row` failure in `horseshoe_gorge` did not appear: no tall or hero instance lies inside that scatter row.

## Density fix (two windows, each filled)

The first w18 run failed two windows at 2 kinds (saltbush, bent_numbers): cannon 1200 m near (-9.6, 206) and tally 1050 m near (-16.6, 226). Each window has one sample, camera facing about +z. North of z 235 is blocked: `home_clear` (25 m of home wasteway_chasers) plus `line_clear` and `keepout` on siphon_runout_pier; a 5 m probe grid of single low pieces over x -60..40, z 190..280 found only a handful of legal cells. Added two single-piece spots on legal ground between the windows and the existing scrub: flume_s094 (mini_ties, timber_ties) at (-5, 225) and flume_s095 (mini_cup, tea_hearth) at (-5, 230). No line, landing or telegraph is touched (0 violations).

## Telegraph zones

`bend_relic_wakes` (machine_eruption, site `bend_overlook`, half 15 x 70, `hold_clear_m` 15) holds the zone. The rule is `park_props.gd` `check_one` ("telegraph": no prop inside the event's geometry grown by `hold_clear_m`; damage and telegraph share the committed geometry, DRESSING-KITS.md). Litter that fails is dropped by `expand`; authored spots fail the plan check.
- Inside before: 16 authored instances (flume_v72 9, flume_v80 2, flume_v82 5) plus 7 litter (440 to 433 litter instances).
- Spots moved: flume_v72 [150.0, -70.0] to [186.0, -70.0] (36 m); flume_v80 [130.0, 30.0] to [131.0, 33.9] (4 m); flume_v82 [120.0, -130.0] to [120.0, -162.0] (32 m). Each is the nearest of a 15-degree by 2 m ring search (to 60 m) whose every instance passes `check_one`.
- `near` labels: flume_v82 is now `bend_zip_pier_18` (30.1 m, grind_line). flume_v72 stays `bend_overlook` (still nearest, 37.4 m, bank). flume_v80 moved 4 m and is unchanged.
- Story check: v72 tie yard, v80 tie yard and v82 sluice shed remain beside the bend; v82's shed now stands 30 m from a zip pier, not at the water, which the kit story ("sluice shed with its wheel") does not name; flagged for World/Art.
- Plan check after: 0 violations.

## Tests (each run alone, GODOT_BIN 4.7.2, 2026-10-22)

park_props_test, park_park_flume_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test and run_tier_test each exit 0 (the smoke runner prints verdicts, not assert counts, for passing runs). scatter_rows_test timed out at the runner's 180 s on a loaded box with every assert PASS, then exit 0 in 113.8 s on a rerun. `sketch:lint` 0 findings; `check:docs` pass (178 files, 0 failures). Registry fold unchanged.

## Audit (w18d, after line_clear_m and telegraph; default run, mid camera, step 25 m, 238 samples)

Method: `park_props_audit.gd` via the lock wrapper, OpenGL compatibility on cloud llvmpipe (not a frame-cost proof). Before values are the w18 run below. The brief's "density 2 of 10" figure does not match that run's summary (36 of 36 non-exempt); this run is compared with the summary.
- density: 36 of 45 windows pass, 9 exempt (arena 5, telegraph 4), `density_fail_windows` empty (before: 36 of 36, 9 exempt)
- props-only draw delta: max 46, median 24.5 (before 46, 24.0); draw calls max 429, median 308.0, p95 407.6
- bare share 21.8 percent (52 of 238; before 21.0), longest bare run 100 m, void poses 0
- Artifacts: `artifacts/local/dressing/flume/w18d/park_flume/` (local, not committed)

### Previous audit (w18, before this unit)

- props-only draw delta: max 46, median 24.0 (peak pose idx 149 at -48.7, -111.6)
- draw calls: max 467, median 317.5, p95 428.6 (llvmpipe, varies run to run); primitives max 811390 (median 658772)
- density: 36 of 36 non-exempt windows pass (1.0; 9 exempt: 5 arena, 4 telegraph); no failing windows
- bare share 21.0 percent (50 of 238), longest bare run 100 m; bare ground share 21.0, longest 100 m; void poses 0
- median dressing core in view within 60 m 11.0, distinct kinds within 120 m median 18

## 12-pose replay

Before and after both come from replays of the same poses (before = same tree with `props/park_flume.json` moved aside; after = replay with the file), so each pose is taken at the same moment. The earlier before frame at 235,123 caught a hazard telegraph and the post at 101,-204 was a timing difference; both are gone.
Pixel change (share of pixels with a channel difference over 12): 101,-204 3.75 (residual shadow and light, post present in both); 107,169 0.07; 137,213 1.92; 149,-49 0.66; 208,-104 2.01; 227,32 0.61; 235,123 0.02; 30,-298 0.66; 59,-20 0.46; 8,-468 0.00; 89,-213 0.59; 91,-232 0.18. Median 0.60.
The poses are the barest places, mostly in keepouts, so props rarely fill the frame there. Replay draws: after max 427, median 293.5; before max 441, median 288; replay props-only delta max 50, median 14.

Stills: `artifacts/local/dressing/flume/w18/{before,after}/park_flume/` (replays), `after-full/` (default run), sheet `before_after.png` (local, not committed).

## 30 m brief kinds

Kind `washline`. Brief line (lane KITS.md, flume): "At least 30 m from lines". Measure: edge-to-line, `Context.line_distance(centre)` minus the instance radius, as `check_one` uses for `line_clear`. Target 30.5 m or more. The spot schema has no per-spot override, so offenders were moved, not stripped.

| spot | edge_m before | edge_m after | old `at` | new `at` |
|---|---|---|---|---|
| flume_v10 | 21.82 | 53.53 | -340.0, -570.0 | -348.3, -539.1 |
| flume_v42 | 27.57 | 31.14 | -130.0, -440.0 | -126.0, -440.0 |
| flume_v65 | 28.49 | 31.50 | 10.0, -120.0 | 9.0, -123.9 |
| flume_v69 | 26.52 | 31.70 | 50.0, -30.0 | 50.0, -24.0 |
| flume_v96 | 29.42 | 30.86 | -50.0, 340.0 | -48.1, 339.5 |
| flume_v99 | 22.43 | 32.13 | -120.0, 360.0 | -130.0, 360.0 |
| flume_v105 | 17.90 | 38.87 | 120.0, 300.0 | 164.5, 255.5 |
| flume_v47_r8_4 | 28.58 | 32.24 | -244.0, -103.1 | -248.0, -103.1 |

The other 9 instances already passed and are unchanged. flume_v10 (32 m move) and flume_v105 (63 m move; nothing legal within 45 m) changed `near` to the nearest park row by centre: weir_trestles and bluff_ride_pier_9. Pin 1477437796 to 2392297130. Plan check: 0 violations. Probe: under30_edge=0.

The `washline` kind now carries `line_clear_m: 30` in `tools/blender/park/props/flume.py` (manifest `"line_clear_m": 30.0`), and `park_props.gd` `check_one` takes the larger of the tier and the kind value, so the plan check enforces it. The 8 moves above stay valid under it.

Do the moved spots' stories still hold? Nearest feature is from `park_flume.json` park_rows (ground rows excluded), by centre:
- flume_v10 (32 m move, washday "by the trestles"): nearest is weir_trestles (anchor_field), 23.1 m. Holds, the label is now `weir_trestles`.
- flume_v105 (63 m move, camp_corner): nearest is bluff_ride_pier_9 (grind_line), 16.7 m, then bluff_ride_pier_12. A crew camp in the lee of a pier. Holds, the label is now `bluff_ride_pier_9`; a camp corner has no row-specific story.
- The other six moved 1 to 10 m; their nearest rows and stories are unchanged.

## ART-MISTAKES entries checked

`project-guide/handoff/ART-MISTAKES.md`, read before the unit:
- 2026-10-21 World #242 lane width ("read the function before describing a flag"): I read `park_props.gd` `expand()` and `check_one` before saying the spot schema has no per-spot override, and read the telegraph rule before describing it.
- 2026-10-21 Modeling M1 anchor gap tool (a run line copied without running it): the Blender rebuild command was run, exit 0, and the diff confirmed only the manifest `line_clear_m` line changed.
- 2026-10-21 Animation #261 receipt (SHAs typed from memory): SHAs in this unit's report are pasted from `git rev-parse`.
- 2026-10-21 Animation A1 (pkill by text pattern): no process was killed by pattern.

## Reference boards

Rulings 6330671507 (reference before making) and 6331210075 (board grounding). Boards settle look only, not mechanics, scale numbers or collision. I opened each board image before citing it.

Boards (under `docs/art/reference/`):
- `spillway/spillway-props-moodboard.jpg`, `spillway/spillway-landmarks-flume-carry.jpg`, `spillway/spillway-landmarks-moodboard.jpg`;
- `style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`;
- `pilots/pilots-balls-heft-moodboard.jpg` (scale, relative only).

**Palette roles.** The Spillway props board (`spillway-props-moodboard.jpg`, whose printed swatches give the six hexes; `spillway/README.md` line 52 names petrol, bone and sandstone) paints waterworks machines in petrol enamel 365754 with copper or steel fittings, on sandstone, oxide, charcoal and bone. Per role, from grepping each kind's colour calls in `tools/blender/park/props/flume.py` (the `C` table is `kit.py` lines 59-67; `PETROL` and `COPPER` are raw hex at the top of the recipe, because the foundation PR owns `kit.py`):
- Machine bodies in petrol 365754 (`PETROL`, line 38): boom_crane_wreck winch-cab walls (lines 82 to 85), winch drum (94) and hook block (159); sluice_shed housing walls (273 to 277), gable roof planks (292, petrol and a darker petrol mix), axle and hub (301, 304); gauge_dial_shed hut walls (551 to 554) and back plate (562); pipe_section variant a body (698; variants b and c keep rust). The board panels followed are Sluice Wheelhouse (a petrol housing on a stone block with a wheel) and Pump Repair (petrol body, copper and steel fittings). The Spillway board has no gauge hut, so I took the nearest panel, Pump Repair, for gauge_dial_shed. The crane has no board panel; its working parts are timber on the carry board's trestles, so the boom, lattice, roof and A-frame stay timber and iron; the petrol parts are the winch cab walls, the drum and the hook block, with a bone cap plate on the A-frame (line 110).
- Oxide 9b513a (`OXIDE`, line 39): the sluice wheel spokes (line 311), as the Wheelhouse wheel. The paddles stay timber (line 313); the rims are dark timber, iron_light on variant a (303); the wheel pit is concrete (316).
- Bone d2c5a5 (`BONE`, line 40), one part per machine kind: boom_crane_wreck A-frame cap plate (line 110), sluice_shed name plate over the door (279), gauge_dial_shed dial face (563). No new geometry.
- Copper b77843 fittings, small accents only: boom_crane_wreck crank ring and pipe_section end flanges. It is a WARN colour in `kit.py`, so the build prints a warning, no error.
- Steel fittings stay iron or iron_light: the flange bolts (line 704), hoops, crank spokes and the dial ring.
- Verdigris 5f8a7c is not a machine colour here. It is on a flask (sluice_shed, line 324), a cup (tea_hearth, line 441) and a shirt and a cloth heap (washline, lines 465 and 472): small accents.
- Sandstone c6a274 is unused: hearth stones and the shed footing are grey concrete.
- Timber, canvas, concrete and charcoal carry the rest; the leaf greens are olive, not Ancient.
Colour guard (`kit.py` `check_colour` runs at build): both rebuilds exited 0 with no banned or hazard-like colour; only the copper WARN line printed. Tris, radius and height are unchanged for every variant of the four recoloured kinds (identical KIT_BUILT lines; manifest and registry byte-identical). Previews (`artifacts/local/dressing/flume/preview/`, local) looked at against the props board:
- sluice_shed_a: reads as the board's petrol Wheelhouse, a petrol housing and roof with an oxide spoked wheel, timber paddles and a bone name plate.
- gauge_dial_shed_a: a petrol hut with a bone dial face and a timber roof; reads as a petrol machine hut like Pump Repair.
- pipe_section_a: a petrol drum with copper flanges, like Pump Repair.
- boom_crane_wreck_a: the winch cab, drum and hook block are petrol, the A-frame carries a bone cap plate, and the boom stays timber. It reads as a petrol cab with a timber crane, not a fully petrol machine; that is deliberate (no crane panel on the boards) and I flag it for review.

**Shape language.** Broad worn, soft toy shapes: `flume.py` builds with `style="round"` and `hard_smooth` blobs, low sleepers (line 65, "never a crate"), draped shirts, and rounded shed and hearth masses, like the Pump repair and Wheelhouse panels. Silhouettes stay low and wide beside the tall machinery.

**Materials.** The kit uses no brass: no `d9b44a`, `brass` or amber appears in `flume.py` and none in the `C` table, per the Materials board's rule that brass is Fleet ownership. Copper b77843 (`COPPER`, line 41) appears only as the crane's crank ring (line 97) and the pipe flanges (line 701); `kit.py` line 72 makes it a WARN colour, never dominant. Other fittings are iron, iron_light and rust.

**Scale to the pilot ball.** The ball radius is 1.0 m, so diameter 2.0 m (`src/movement/tuning.gd:95`; `anchor_fit.json` `ball_radius_m` 1.0). Manifest kit heights against it, relative only: tea_hearth 0.8 (0.4 ball), bent_numbers 0.9 to 1.0, saltbush 0.8 to 1.0, washline 1.46, tool_peg 1.5 to 1.6, bunk_cots 1.0 to 1.95 (under one ball), skiff_on_blocks 3.1 to 3.4, boom_crane_wreck 4.8 and sluice_shed 5.6 (about 2.4 and 2.8 balls). Camp props stay under or near one ball and the sheds sit at a few balls: the plush-crew-among-giants contrast. No new metres asserted.

**Avoid list** (checked against the kit and the manifest):
- no emission: pass. `kit.py` line 567 asserts no `emissiveFactor` in any GLB, and the flume manifest has 0 `emissive` entries;
- no hazard stripes or coral: pass. No stripe code in `flume.py`; `kit.py` bans ff5a3c and near colours and hazard-like hues (line 105);
- no cache-shaped containers: pass. Sleepers are "never a crate" (line 65); the only box-like props are the sheds;
- no taut or decorative grapple cables: pass with a note. The washline is a draped slack line (line 453, "never taut"). The boom_crane_wreck chains (lines 151 to 162) are heaped slack chain with sag 0.2 to 0.7, a wreck's rigging, not a line; variant a at 0.2 is the least slack, so review should look at it;
- no fake ride surfaces: pass. All props are low clutter or sheds; `check_one` keeps them off ride rows;
- no glowing lamps: pass. The crane's lantern (lines 163 to 165) is unlit chalk white `e6e3d6`, with no emission;
- no ancient-green or uranium-green: pass. No 9dff3c or near colour (`kit.py` line 69); the leaf greens are olive (6f7f4a, 4f5e38), not the board's bright Ancient green;
- Highdraft items: not applicable to flume.

**GROUNDING rows read** (`GROUNDING.md` (main cb534a2d), scratchpad copy):
- line 159 (carry board): not a prop row; the unit keeps props off the carry and ride rows through `check_one`. No Conflict.
- line 161 (Canal country and Surge tower): destination read stays the landmark; props stay low. No Conflict.
- line 167 (props: no emission, stripes, cache silhouettes, taut cables, fake ride surfaces; short clothesline domestic only): the avoid list above; the washline is the domestic line.
- line 172 (ancient light only on the distant beacon): no kit prop carries ancient light.
- line 173 (intakes, bunk ledges and siphon pieces as route structures): not changed; the camps sit beside them.
- No Conflict row in 159, 161, 167, 172 or 173: nothing marked "not copied".

## Board drift (for review)

Fixed in this round: machine bodies were iron grey and rust, not the board's petrol with copper or steel fittings; the sluice, gauge hut and crane cab are now petrol bodies (see Palette roles). Washline gained `line_clear_m: 30` in the earlier commit and now also has a recolour (verdigris shirt and cloth, unchanged here). Open items, none changed in this unit:
- boom_crane_wreck variant a chain sag 0.2 is the nearest to a taut read.
- The concrete, timber and canvas neutrals are outside the 13 palette chips, though the boards' materials show them.
- The tea_hearth kettle reads as a dark sphere: needs a play-check.
- tool_peg is the kit's only gate-like silhouette: needs a play-check against "no fake ride surfaces".
- timber_ties in the even-spaced litter layer is a prop, not ground cover. Dropping it would change the pin and the audit, so it is deferred and named here (ART-MISTAKES 2026-10-19 #219: cut or refit, never drop geometry to pass a check).
- v82's sluice shed has a weak story at its new spot (30 m from bend_zip_pier_18, not at water); World could swap the template.

ART-MISTAKES rows checked: 2026-10-19 World #219 flush lanes, "never drop geometry to pass a check" (the recolour changes colour, drops nothing; timber_ties is deferred, not removed); 2026-10-21 Grading #241 mapping claim, "measure before claiming" (the palette claims come from grepping the recipe lines and the previews were opened, not from memory).

## w18m row, yaw and label fixes (card (b), #323)

The plan check listed one yaw group: flume_m014, flume_m038 and flume_v104, all at yaw -9.1 and within 24 m of each other. No row group was listed.

- flume_v104 (tie_yard at [-40.0, 460.0]) turns from yaw -9.1 to -33. It now faces bench_return_pier, the row its label names, at [-53, 480] (dx -13, dz 20, atan2 gives -33 degrees). Its position is unchanged.
- flume_m014 and flume_m038 stay at -9.1 with their positions unchanged. Their link is now a pair, which the card allows. Turning them to face the floor line (yaw 171) broke line_clear and keepout for their litter props, so I left them. The chain breaks at v104 alone.
- Labels: 38 `near` labels fixed, all that the lint flagged (30 cut mid-word, and 8 padded with a trailing space: v04, v32, v42, v65, v81, v88, v106 and v114). Each now reads "<place>: <story cut at the last whole word within 60 characters>", where the place is the one the old label named: a row id, or "verge of the line" for spots that name no row (32 flume labels use it, as before this round; it is not a row id). Fourteen unflagged "verge of the line" labels ended on a comma, "...a split plank by the verge,"; they now carry that 54-character story in full, "...by the verge, left to grow." Examples: flume_v03 "weir_gatehouse: Boom 3 on its blocks beside the winch cab, the lock still"; flume_m009 "verge of the line: A cold hearth, one cup and a cot left out."
- New pin 633467776 (was 4063400762), an intended re-pin. The check via `--file` reports 0 violations, 0 pattern, 0 pin, 0 lint; the old check in this tree reports 0 violations at the same fingerprint; park_props_test passes, including "park_flume expansion matches its pin".
- Density (w18m audit, no `--open`): 36 of 45 windows pass, 9 exempt (arena 5, telegraph 4), none failing, as before.

## Flume pass two: the head-gate crew and vignette parity (unit 11, 2026-10-24)
- New template `head_gate_crew` (gauge shed, cot, hearth, tool peg, milepost, numbers, ties, saltbush; story "The head-gate crew's post: the wheel chalked OPEN, three cups on the rail, a cot pulled up to the gauge window so nobody sleeps through the siren.") at spot flume_c01 [-386, -550], yaw 0, on the weir mesa 43 m from the surge ring at [-427, -563]. A search probe placed it after earlier spots failed route_lane, line_clear or keepout once the ring moved off Sable's line.
- The crew's lines are the ring's word (activities.gd SURGE_WORDS): "Head gate: wheel turning. Stay ahead of the water." on opening, "Head gate log: wheel shut. One ball through, flume dry." on a win, "Head gate: winding the wheel back." on a loss.
- New template `shift_tally` (story "A shift board nailed to a milepost: names, a tally of days, and the last line left blank.").
- Dressing parity with the Dig by vignette spots (coordinator ruling, 24 Oct 05:58Z; DECISIONS section 8): 70 generated spots flume_p001 to flume_p070, crew vignettes 22 to 46 m beside authored rows and small verge pieces 12 to 22 m off the pilot and floor lines, each validated alone with ParkProps.validate and kept 30 m from every other spot. The file now holds 166 spots (was 95; the Dig holds 167).
- New pin 841567897 (was 633467776; re-pinned after the surge ring moved off the approach, and again after flume_n037 moved 8 m west, [30.4, -101.5] to [22.4, -101.5], out of the keepout of bend_cache at its #431 spot [42, -96]; 0 violations), an intended re-pin. park_props_test passes (305 checks); the pattern scan and label lint return none. The tower's sight share is 0.8849 against the 0.85 floor.

## w20 canyon walls (the park edge, 27 Oct)

Why: the line-rider red team (w20 e646632d, `/mnt/project-files/gate/w20-e646632d-redteam-line-rider.md`) found no wall on the flume's west, north and south: a ball held outward reached the map edge (+-799) and was snapped 19 m back to the play rect, several times a try. East, the play rect ends at x 520 but the ground ran on, and the ball rolled free to x 756 with no rescue.

What changed:
- Four `canyon_wall_*` rows as the dam's (mesa_rim ground, `greybox:ground`, `stamp` mesa, no `y`, 32 m, mesa edges by "Edges are ground"). West, north and south are 30 m deep at the square's edge, feet +-785, 5 m past the play rect. The east row runs 550 m in from the edge, foot x 525, 5 m past the play rect's x 520, its top flat out to the edge.
- Five east-west washes (`canal_wash_1`, `_3`, `_4`, `_6`, `bluff_wash_3`) now end at x 513, 12 m short of the east foot, so their east ends stay dead ends and they stay graph anchors (the radio find's `canal_wash_1` spot, panel rib reads); their west ends are unchanged. `canal_wash_2` lies wholly under the east wall and leaves `anchors()`; it was outside the play rect.
- Graph: zones 162 -> 166; no wall-top node (7,168) is reachable from the spawn. Rib cache spots are identical on stages 1 and 2 over seeds 1-24. Dressing re-pinned 1001921675 -> 3830422007 (the trimmed wash ends).
- `park_flume_rim_roll_test`: the dam rim test's shots in the north-east and south-west corners, and the play rect meeting every foot within 10 m.
