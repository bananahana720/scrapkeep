# Stage 2, `park_flume`: Spillway: the flume

World 1, Spillway Works, the world's last stage before Brindle. Warden kind `reactor` on the `flume` mounting, variant `meltdown`. Time of day `morning`. Storyboard board id `park-2-park_flume`. Status: draft for Andrew's approval (unit K-W1, 2026-10-10). Every number is a starting value to tune in play unless a file:line backs it.

## Authored pass: the momentum test (2026-10-17, WHATS-LEFT unit 3)

Andrew's ruling (2026-10-17 22:12Z, "one skill per park"): the flume tests momentum. The landforms stay. The pieces, the line and the enemy placement change so that the park reads as one held line from the weir to the head house. If you keep your speed, the flume carries you the whole way. If you lose it, you are on the ground with the canals.

**The line.** Weir intake, weir reach, gap work deck, a carry across the canal floor, hollow intake, hollow reach, siphon span, head reach, then off the head reach's end into the drum. The route is `flume_whole` (butte_gap to the landmark). The bot line is `assets/park/park_flume/momentum.json`, which has the same waypoints for all six pilots.
- The butte gap is part of the test. The gap work deck throws you onto the canal floor, and you carry your speed about 90 m over open ground into the hollow intake's flared mouth. Andrew chose this over a bridging span (card, 2026-10-18 03:09:59Z, "Keep the carry").
- The finish is the flight off the head reach into the drum. The pour spout is scenery the relic clamps on, not part of the line.
- The weir reach carries no enemies on purpose. It is the 10 s speed build.
- The siphon span is new: 100.8 m, falling 21 m on a smoothstep from the hollow floor (45) to the head reach floor (24). It pays back the speed the hollow reach costs.
- The pour spout sits inside the drum's west rim at [210.1, 437.9], its lip over the drum. Its deck is at the Warden anchor's height (-2), where the relic clamps on, and it hangs from the clamp: its two bents are 2 m hangers, so the drum floor stays open underneath. Its old spot lay across the ground way's drop over the rim, and a later spot with legs to the drum floor stalled Sable and Tally on the standard lines.
- The hollow trestle collapse (clock tier 1) still breaks the hollow reach. A rider who is late finds the flume falling under them. That is the race the park sets, and the ramp it leaves still leads down.

**Pieces** (`tools/blender/park/flume_works.py`, registry fragment `park_flume_works.json`, three GLBs each):

| Row(s) | Piece | Note |
| --- | --- | --- |
| weir, hollow and head reaches | `flume_reach_120`, tile fit | `flume_span` refuses the tile fit: it has a bent at its entry only. The reaches had been standing in as grey boxes with no warning anyone saw. The new reach has a bent flush inside both ends. |
| weir_intake, hollow_intake (new) | `flume_intake_16` | A 16 m mouth that flares from 14 m wide and floor-flush to the flume section. A ball rolling in from open ground used to hit the bare wall ends and bounce off. |
| siphon_span (new), pour_channel | `flume_siphon_span`, `flume_pour_spout` | |
| 28 flume piers, 19 bend piers, 18 bluff piers | `flume_bent_50`, `survey_mast_40`, `surge_pylon_28` | Colliders identical to the old boxes. Re-verbed `swing`: they are the anchors that carry a swing along the line. |
| crib piers and walls, anchor blocks | `crib_pier_*`, `crib_wall_60x24x6`, `anchor_block_16x28x8` | |
| gatehouse, annex, crew ledges, weir deck, gap reach, rim drop | `weir_gatehouse`, `annex_hall`, `crew_bunk_ledge`, `weir_apron`, `gap_work_deck`, `rim_road` | Box and wedge colliders as before. |
| 11 canals, washes, chutes and the weir pond | `liner_<row>` | Decoration conformed to the bake. The stamp stays the only collider. |
| 9 kickers | `plate_kicker_*` from #95, seat fit | |
| head_house_drum; horseshoe and lower gorge | `landmark`; `scatter` | |

**Enemy placement.** The weir reach has none (see the line above). Trestle drones roost on the hollow reach itself: a 20 m winch lane along the trough hooks a ball that slows on the grind. siphon_camp moves 2.8 m toward the flume, to [-26, 174], so a rider on the siphon passes the camp within its 12 m reach. Its lobbers still sit in the gorge under the span. The forecourt brutes can be beaten by keeping the flume's speed to the pour lip.

**Fragments.** See section 11 for the eight new dam-era texts: siphon span, bent board, survey mast, surge pylon, pour lip, gatehouse key, crib pier, anchor block and intake gate. They match the #53 field notes (bents numbered downhill, the siphon, the drum).

**Evidence** (headless, fixed 90 fps, `traversal_line.gd --table=park --stage=2`, every artifact tagged with its commit; automated play says nothing about feel). Head db83afa7, compared with the stage w17 base f8c87419 run the same way. Artifacts are under `artifacts/local/flume/` (std5, mom9, base4).
- Momentum line, six pilots by two seeds. 10 of the 12 runs ride every reach, the siphon and the head reach. Times to the Warden: Sable 58 s, Tarn 76 to 77, Cannon 83, Tally 88 to 90, Kest 87 to 89, Rivet 93 to 96.
  - Rivet misses on both seeds. It reaches the hollow as the collapse starts, rides the falling ramp and meets the siphon end from below, with 1 dead stop.
  - Sable seed 1 has 1 dead stop at the butte gap landing; seed 2 carries through. Tally seed 1 has 1 at the weir reach's end, leaving it at 8 m/s; seed 2 has none.
  - Kest and Tally's flow share is 0.45 to 0.62 on this line, under the 0.7 bar. Sable runs under the 60 s band floor. These bands were written for the wandering lines.
- Standard lines (`lines.json`), six pilots by four seeds.
  - Cannon, Kest, Rivet, Tally and Tarn have 0 dead stops on every seed, as on the base.
  - Sable has 1 stop on 2 of 4 seeds. One is at the weir canal floor: the path matches the base to 0.5 m and misses a 12 m waymark by 0.3 m, where the base makes it by 0.2 m. The other is at the siphon camp. Both happen on the base too from run to run: 0 of 4 seeds in one base run, 1 of 4 at the siphon camp in another.
  - Per-seed flow share falls under the 0.7 bar on one Kest seed and two Tally seeds here, and on two Kest seeds and one Tally seed on the base. Every median is inside the bar here; on the base Kest's median (0.68) is under it. The floor line has 0 dead stops on 4 seeds; its flow share is 0.59 here and 0.57 on the base, both under the bar.
- Tests on the head: park_park_flume, park_recipes_kickers, park_dressing_pin and bot_flume_exit pass. `flume_works.py --check` passes. park_schema_test's only failures are its "six stage pages" checks, from the seventh page #68 adds on the base. The earlier head's run (c2e3df3b) also passed park_place, park_bake_fresh, asset_registry, park_recipes_grind, park_anchors, flume_line_posture and posture_bands_flume, `placeholder-gate` listed no flume rows and `park-anchor-kit --check` showed 0 left.
- Re-pins, each with a dated header:
  - Stage 2 dressing pin, from siphon_camp's keep-out. With the camp at its old spot the old pin holds.
  - The collapse's `depth_m` now measures 21.441297 from the trough floor, and the collapse closes `flume_whole` as well as `flume_mid`.
  - park_recipes_kickers_test counts rows already swapped onto a piece.
  - tools/bot_driver.gd's climb route reads seated kickers, not only greybox ones. This also covers the islands' and crown's seated kickers, which no run here exercises.

**Scorecard** (intent-check, this branch): 0 flume placeholders, 161 authored rows, 20 story fragments, society share 0.66, ride-fact share 0.94. The top verb is `swing` (0.5) because the 65 piers are swing anchors. The scorecard counts verbs per row, so a park whose skill is one long line reads as its anchors. The line itself is the test.

<!-- flume-current-table -->
## Flume pass two: the head-gate surge (unit 11, 2026-10-24)

World 1 unit 11 gives the completionist something to do on the flume beyond the enemy camp. Nothing here adds an enemy kind or a pack, and the main line is unchanged: the six pilot lines still ride the weir chute.

- **Sluice Surge** (`weir_surge`, activity `surge_run`, site `weir_mesa`, ring [-427, -563], 22 m to the side of the line into the weir intake, route `flume_upper`). An opt-in race: open the head gate and a water front follows you down the weir reach, the gap work deck and the 40 m drop into the canal country. The gates stand on the riding surface (row top, then a downward ray once the colliders are up), and the front starts 40 m back up the route from its head and moves at cruise speed. Pay common or rare. A course that ends while its sluice is still announced ends the sluice too, so it never lands late. Its event row `head_gate_sluice` (industrial `sluice_surge`, 4 s `sluice_siren` on the bar, 45 s live) is what you hear: the siren is the warning, as sound is the fairness channel. The graph gives it the event role beside hold_the_relay (PARK.md 2.12).
- **The head-gate crew** (props spot flume_c01, 43 m from the ring). Their lines are the ring's word: "Head gate: wheel turning. Stay ahead of the water." on opening, "Head gate log: wheel shut. One ball through, flume dry." on a win, "Head gate: winding the wheel back." on a loss.
- **Canal altar** (`canal_altar`, `ambush_altar`, site `main_canal`, [-475, -206]), the card 2 extra activity and the park's second risk pocket. Detour 194 m; every distance rule holds.
- **Trestle cache** (`trestle_cache`, `cracked_cache`, site `canal_country_low`, [-236, -432], face south, pocket interior `sump_vault`; W1-17, 12 Nov 2026), a card 2 extra and the park's second reward pocket, on the low canal country under the trestle's turn, so it reads from the flume grind above. Detour 185 m, 220 m from the weir valve's door; every distance rule holds. Pays common or rare on its own part stream (activities.gd `_luck_id`), so it never repeats the bend cache's part. The Overtime Locker (`grade_wall`, section 8) is its hidden partner on the canal grade.
- **Spill leap** (`spill_leap_kicker` on the mesa rim at [-388, -700], and `spill_butte` at [-342, -700]). A second skill pocket off the grind line: at 22 m/s or more the kicker lands you on the butte top (97 m); at 18 to 20 m/s you stay on the mesa.
- **Dressing**: vignette parity with the Dig, 166 spots (the Dig 167); see the dressing page.
- **Rogue sites** for the roster's miniboss (`assets/park/park_flume/sites.json`, `weir_flats_rogue` and `plain_rogue`), read once the roster's loader stacks.

Measured on this branch against its base (the #413 merge, a20f09c6), park table, stage 2, seeds 1-4, medians:

| Measure | Base | Head |
| --- | --- | --- |
| Completionist, explorer bot (`--explore-by=520`) | 284 bot-s, 1-2 activities | 355 bot-s (+71), 2-3 activities; surge won on 3 of 4 seeds |
| Completionist, default bot | 211 bot-s | 219 bot-s (+8); surge won on 3 of 4 |
| Traversal, six pilots × 4 seeds | | 24 of 24 reach the Warden, no dead stops, every band inside |
| Draws, five fixed views (software GL) | 445 / 417 / 383 / 347 / 208 | 426 / 422 / 387 / 348 / 210 |
| Tower sight share | | 0.885 (floor 0.85) |

The explorer park is still under the 420-600 bot-s band; the gap is about 65 s at the floor.

## Current measurements and qualification, round 9

<!-- flume-current-receipts
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r9",
  "head": "e3a292d736c42dec397d3c3108591e2c1d886f96",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `e3a292d736c42dec397d3c3108591e2c1d886f96`, merged from candidate `e8471670d479b0609d7a4f078e1066c84cb5479d`, at `0617cf3b1f1ab30264ac12b71d4c57c5822053fe`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 62.36 / 65.06 pass | 96.675 / 99.57 pass | 85.785 / 92.01 pass | 80.5 / 81.5 pass | 93.085 / 96.22 pass | 81.515 / 84.82 pass | 96.245 / 98.49, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 20.84, 19.9] / [21.89, 22.29, 21.68] pass | [27.28, 36.245, 33.31] / [28.71, 37.16, 34.47] pass | [25.6, 35.34, 25.005] / [29.29, 35.82, 26.89] pass | [23.38, 26.86, 29.98] / [24.81, 27.12, 30.5] pass | [27.83, 31.155, 34.65] / [29.12, 32.36, 34.91] pass | [25.64, 36.795, 18.91] / [25.87, 37.2, 22.19] pass | [28.38, 30.3, 37.63] / [28.86, 31.08, 38.86], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9333 / 0.931 pass | 0.7482 / 0.7349 pass | 0.7223 / 0.6587 pass | 0.94145 / 0.9307 pass | 0.70875 / 0.6193 pass | 0.93295 / 0.9075 pass | 0.59015 / 0.5654, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2536 / [0.236, 0.2608] pass | 0.12685 / [0.1212, 0.1296] pass | 0.1608 / [0.143, 0.1645] pass | 0.17245 / [0.1652, 0.1807] pass | 0.13185 / [0.1231, 0.1448] pass | 0.1625 / [0.1313, 0.1768] pass | 0.1234 / [0.1169, 0.1321], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.14 / 46.44 pass | 7.79 / 7.59 pass | 6.975 / 3.99 pass | 9.46 / 8.34 pass | 8.42 / 6.12 pass | 11.31 / 8.18 pass | 8.155 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.385 / 17.57 pass | 8.72 / 8.87 pass | 15.205 / 15.48 pass | 12.53 / 13.2 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 31.3 / 32.9 pass | 30.6 / 33.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 31.4 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.5 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | 1.33 / [1.32, 1.37] pass | 1.35 / [1.35, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.33 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.245 / max 98.49; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-floor-inputs.json` |

### Distinct pilot lines

Mutually distinct lines: sable / seed 1, rivet / seed 5, tally / seed 5; PASS.

Each directed share counts all source trace ticks with any target tick within 8 m in XZ. All six directed shares are below 0.5. The committed documentation check recomputes the shares from qualified final-input traces and rejects a duplicated path.

| Directed overlap | Share within 8 m |
| --- | --- |
| sable → rivet | 0.27254 |
| sable → tally | 0.22590 |
| rivet → sable | 0.31723 |
| rivet → tally | 0.40292 |
| tally → sable | 0.25958 |
| tally → rivet | 0.43564 |
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-sable1-trace/sable-seed-1-trace.json`.
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-rivet5-trace/rivet-seed-5-trace.json`.
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-tally5-trace/tally-seed-5-trace.json`.

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| All 56 seeds | none | none | zero observed stops | not applicable | not applicable | population receipts above |

No stops were observed in the final 56 qualified seeds, so no pack exemption or stop probe is required. Stop-replay records are in `/home/andrew/scratch/w13/sol/kd2-flume-r9/stop-replay-comparisons.json`. A pack exemption would require a matching traced solo, an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts would count as terrain. The final population uses no exemption.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |
| tally / 5 | equal | error-free qualified |
| floor / 1 | equal | error-free qualified |

Named replay acceptance: 5/5 qualified comparisons complete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r9/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r9/input-equality.json`.

<!-- current-win-results -->
### Current win results, round 9

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 289.03 | 172.34 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-1/bots.ndjson` |
| 2 | 116.74 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-2/bots.ndjson` |
| 3 | 112.25 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing park-cue error. ACE stem files are absent in this worktree, so these runs use the existing synth fallback. Listening is not qualified. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /current-win-results -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

The corrected candidate tests judge the music bar grid booked at announcement. Both ground-slump game fixtures and the complete Z1 shared suite pass. The candidate supplies the shared posture-comparison and Warden-wiring corrections. The complete eight-file stage smoke passes. Rivet also emits missing Fin.L/Fin.R control diagnostics, which the wrapper reports separately as a partial skip; all 127 flume geometry checks run and pass. KD2 leaves those shared files unchanged. The retained round-8 baseline and head failure logs establish the inherited defect before that candidate correction.
<!-- /flume-current-table -->



## Riding surface correction, round 9

Superseded by the authored pass above: the hollow reach is now a `flume_reach_120` trough at y 40, and the collapse depth is 21.441297. The text below is kept as history.

Coordinator ruling V1 defines the intact riding surface as base plus height. The span remains at base y=44 m with height 2 m, so its mesh and solid collider top are 46 m. The warning sits 0.15 m above that top. The prepared replacement begins at the independently measured intact surface with zero fall progress. It falls continuously over the unchanged two seconds to the baked hollow floor, 23.5586042404175 m, giving depth 22.4413957595825 m. The 20 m hold-clear margin, predicted crossing hold, partial-fall pause, authored site, trigger, form, lead, swap and route changes remain fixed.

<!-- flume-historical-table-r8 -->
## Historical measurements and qualification, round 8

<!-- flume-historical-receipts-r8
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r8",
  "head": "395ba57bc8da9c6c260776ea04cc8c9520f427d0",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `395ba57bc8da9c6c260776ea04cc8c9520f427d0`, merged from candidate `f6bc6b646ad728d53744ba99580514d463ab217f`, whose runtime code is `bc07122e` at `54ca9d8912fa39e4f9243fc02221ea98faa66623`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 62.36 / 65.06 pass | 96.675 / 99.57 pass | 85.785 / 92.01 pass | 80.5 / 81.5 pass | 93.085 / 96.22 pass | 81.515 / 84.82 pass | 96.245 / 98.49, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 20.84, 19.9] / [21.89, 22.29, 21.68] pass | [27.28, 36.245, 33.31] / [28.71, 37.16, 34.47] pass | [25.6, 35.34, 25.005] / [29.29, 35.82, 26.89] pass | [23.38, 26.86, 29.98] / [24.81, 27.12, 30.5] pass | [27.83, 31.155, 34.65] / [29.12, 32.36, 34.91] pass | [25.64, 36.795, 18.91] / [25.87, 37.2, 22.19] pass | [28.38, 30.3, 37.63] / [28.86, 31.08, 38.86], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9333 / 0.931 pass | 0.7482 / 0.7349 pass | 0.7223 / 0.6587 pass | 0.94145 / 0.9307 pass | 0.70875 / 0.6193 pass | 0.93295 / 0.9075 pass | 0.59015 / 0.5654, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2536 / [0.236, 0.2608] pass | 0.12685 / [0.1212, 0.1296] pass | 0.1608 / [0.143, 0.1645] pass | 0.17245 / [0.1652, 0.1807] pass | 0.13185 / [0.1231, 0.1448] pass | 0.1625 / [0.1313, 0.1768] pass | 0.1234 / [0.1169, 0.1321], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.14 / 46.44 pass | 7.79 / 7.59 pass | 6.975 / 3.99 pass | 9.46 / 8.34 pass | 8.42 / 6.12 pass | 11.31 / 8.18 pass | 8.155 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.385 / 17.57 pass | 8.72 / 8.87 pass | 15.205 / 15.48 pass | 12.53 / 13.2 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 31.3 / 32.9 pass | 30.6 / 33.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 31.4 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.5 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | 1.33 / [1.32, 1.37] pass | 1.35 / [1.35, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.33 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.245 / max 98.49; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-floor-inputs.json` |

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| All 56 seeds | none | none | zero observed stops | not applicable | not applicable | population receipts above |

No stops were observed in the final 56 qualified seeds, so no pack exemption or stop probe is required. Stop-replay records are in `/home/andrew/scratch/w13/sol/kd2-flume-r8/stop-replay-comparisons.json`. A pack exemption would require a matching traced solo, an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts would count as terrain. The final population uses no exemption.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |
| tally / 5 | equal | error-free qualified |
| floor / 1 | equal | error-free qualified |

Named replay acceptance: 5/5 qualified comparisons complete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r8/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r8/input-equality.json`.

<!-- historical-win-results-r8 -->
### Historical win results, round 8

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 289.03 | 172.34 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-1/bots.ndjson` |
| 2 | 116.74 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-2/bots.ndjson` |
| 3 | 112.25 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing park-cue error. ACE stem files are absent in this worktree, so these runs use the existing synth fallback. Listening is not qualified. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /historical-win-results-r8 -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

<!-- /flume-historical-table-r8 -->


<!-- flume-historical-table-r7 -->
## Historical measurements and qualification, round 7

<!-- flume-historical-receipts-r7
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r7",
  "head": "dfde1de818f455214a0f1fc947e91bd21569a254",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `dfde1de818f455214a0f1fc947e91bd21569a254`, merged from candidate `1afb24f59c04f692d7e7c038012c80ec9c63cc1b` at `7f381358948e4ce97bf70a6cc4943dc12b87a0a8`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 63.06 / 64.02 pass | 96.675 / 99.42 pass | 85.665 / 91.41 pass | 80.185 / 81.43 pass | 92.825 / 94.99 pass | 81.415 / 84.87 pass | 96.465 / 97.59, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 21.11, 20.33] / [21.89, 22.3, 22.1] pass | [27.28, 36.245, 33.25] / [28.71, 37.16, 34.42] pass | [25.6, 35.34, 24.945] / [29.29, 35.82, 26.56] pass | [23.38, 26.445, 30.2] / [24.81, 26.6, 30.4] pass | [27.83, 30.895, 34.32] / [29.12, 31.76, 35.56] pass | [25.64, 36.795, 18.85] / [25.87, 37.2, 22.2] pass | [28.38, 30.08, 37.88] / [28.86, 30.57, 38.61], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9325 / 0.929 pass | 0.7631 / 0.7329 pass | 0.714 / 0.6478 pass | 0.9417 / 0.9294 pass | 0.7097 / 0.6334 pass | 0.9376 / 0.9071 pass | 0.5998 / 0.5858, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2459 / [0.225, 0.265] pass | 0.12045 / [0.1162, 0.1286] pass | 0.161 / [0.1433, 0.163] pass | 0.1689 / [0.1616, 0.1711] pass | 0.1262 / [0.1206, 0.1337] pass | 0.16445 / [0.1284, 0.1771] pass | 0.1173 / [0.1141, 0.1267], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 1 MISS | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.68 / 46.86 pass | 7.79 / 7.59 pass | 6.95 / 3.98 pass | 9.5 / 8.74 pass | 8.465 / 6.11 pass | 11.41 / 8.19 pass | 8.1 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.375 / 18.29 pass | 8.72 / 8.87 pass | 15.265 / 16.41 pass | 12.525 / 13.22 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 29.8 / 30.8 pass | 30.3 / 31.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 30.75 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.5 / [1.5, 1.52] pass | 1.43 / [1.43, 1.44] pass | 1.325 / [1.32, 1.36] pass | 1.36 / [1.36, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.34 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.465 / max 97.59; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-floor-inputs.json` |

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| sable / 2 | 41.48 | [-97.6, 159.4] | terrain |  |  | `/home/andrew/scratch/w13/sol/kd2-flume-r7/stops/stop-sable2-trace/sable-seed-2-trace.json` |

All stops are reproduced by matching batch, plain, traced and read-only probe records in `/home/andrew/scratch/w13/sol/kd2-flume-r7/stop-replay-comparisons.json`. The probe trace matches the standard trace tick for tick. Pack exemptions require an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts count as terrain. Rejected raw records remain diagnostic.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |

Named replay acceptance: 3/5 qualified comparisons complete. The stage is not admitted while this proof is incomplete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r7/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r7/input-equality.json`.

<!-- historical-win-results-r7 -->
### Historical win results, round 7

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 299.4 | 182.71 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-1/bots.ndjson` |
| 2 | 116.96 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-2/bots.ndjson` |
| 3 | 111.66 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing music cue. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /historical-win-results-r7 -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

The shared ground-slump game fixtures retain an upstream timing failure: canonical downbeat remainder 0.56098191214518 s exceeds their 0.2 s pin. The same failure occurs on unmodified STEP 0 shared code. Their geometry and clearance checks pass, as do cave-in, natural, projection and event-family fixtures. This prevents a claim that the full shared suite is green.
<!-- /flume-historical-table-r7 -->




This page follows `design-v3/PARK.md` section 2 and `adr/TADR-011-park-terrain-and-warden-kinds.md`. The draft park file in section 13 passed a scratch copy of the 2.10 checks, the route test and the line estimates in section 9. The name "The Cable Reach" retires (PARK.md:573).

**Historical round 6 qualification: BLOCKED.** Candidate `1f09c265a68f274c0ae62d2155769b643a79a233` merged without conflicts at `e69bd20c11a4acefa041a3004991f6045bba4181`. Coordinator F1 authorizes `depth_m = 20.4413957595825` and `fill_s = 2.0`. A direct read of the committed baked grid at the flume span midpoint `[-115, 5.5]` gives hollow floor `y=23.5586042404175`, below deck `y=44`; the interpolation and input hashes are in `/home/andrew/scratch/w13/sol/kd2-flume-r6/measured-depth.json`.

In round 6 those fields removed the collapse's missing-key script errors and allow the fall to finish in two seconds. The independent real-stage mesh and collider regression remains red: the shared handler projects the `trestle_hollow` footprint, not the flume span, and none of five span samples has a ramp surface. The merged music engine also logs `ERROR: music: missing park cue drop_collapse`. Registration, telegraph, landing and route facts alone cannot qualify the physical ride. Shared geometry and music fixes remain coordinator follow-ups; no substitute form, trigger, lead, hold-clear distance, route change or shared runtime edit was made.

Every earlier table remains historical. Round 6 reruns use the committed `res://tools/traversal_line.gd`, SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`, with untraced eight-seed batches and separate plain/traced solos. Error-aware qualification rejects `ERROR:` and `SCRIPT ERROR` logs even when the tool accepts a raw row. There is no complete qualified current table: 30/56 rows qualify. Receipts and input manifests are in `/home/andrew/scratch/w13/sol/kd2-flume-r6/`.

Coordinator F2 corrects the stale two-of-three break requirement. Ruling 23 requires every seed to reach and engage the Warden with no traversal-cause stall; breaks are reported separately under the unchanged 600 s wrapper. Warden fight duration belongs to the Warden fight units and Andrew's task #5.


<!-- historical-win-results-r6 -->
## Historical win results, round 6

Measured with the unchanged scratch `win_600.gd`, which only sets `stage_limit = 600.0` before tick 1. Each process uses `--table=park --from-stage=2 --stages=2 --policy=completionist`. Coordinator F2 and ruling 23 require engagement; breaks are reported separately. Historical proofs below remain historical.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 299.4 | 182.71 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-1/bots.ndjson` |
| 2 | 118.64 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-2/bots.ndjson` |
| 3 | 110.52 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-3/bots.ndjson` |

Every seed reaches and engages the Warden; none stalls before engagement. The logs contain no `get_rid` script error. Each win log contains the shared missing `drop_collapse` music cue. The reach/engagement observations satisfy ruling 23; these runs do not establish error-free whole-stage execution or the physical fallen ramp. Post-engagement beacon or gate stalls are reported above. Warden break duration stays with the Warden fight units and Andrew's task #5.
<!-- /historical-win-results-r6 -->

## Historical population qualification, round 6

Measured runtime head `ea4974b6cb21f79bd180effe5d441d140e4c2cfd`, which descends from candidate `1f09c26` through merge `e69bd20`. Later commits change the regression and these pages; runtime source, committed tool and bake/graph inputs remain identical. The committed tool SHA256 is `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. Each line uses an untraced seeds-1-to-8 batch in its own output folder. Input manifests are `population-<pilot>-inputs.json`; raw logs are `population/<pilot>/children/<position>-seed-<seed>/child.log`. All paths below are under `/home/andrew/scratch/w13/sol/kd2-flume-r6/`.

| Line | Tool-accepted rows | Error-qualified rows | Qualification |
| --- | --- | --- | --- |
| sable | 8/8 | 8/8 | complete |
| rivet | 8/8 | 0/8 | blocked by log errors or incomplete population |
| kest | 8/8 | 6/8 | blocked by log errors or incomplete population |
| tarn | 8/8 | 8/8 | complete |
| tally | 8/8 | 0/8 | blocked by log errors or incomplete population |
| cannon | 8/8 | 8/8 | complete |
| floor | 8/8 | 0/8 | blocked by log errors or incomplete population |

Total: 56/56 tool-accepted rows, 30/56 error-qualified rows. `population-qualification.json` and its log reject `SCRIPT ERROR` and `ERROR:` lines. Matching rejected records are diagnostic. `replay-qualification.json` retains the five named batch/plain/traced comparisons; `input-equality.json` proves matching runtime inputs.

The round-6 complete 13-band table remained BLOCKED. No rejected record is copied into a current table; every earlier table remains historical. `band-table.md` contains fully qualified line diagnostics, with other lines explicitly unqualified. It is not the acceptance table. Rulings 13 and 14 retain the floor's own arrival/time/zero-terrain-stop row and per-seed anchor check. Every per-seed band uses its worst seed; explicitly median-based criteria retain their medians.

Round-6 stop attribution was in `stop-classification.json` and `stop-replay-comparisons.json`. Sable seed 2 stops at 41.48 s, [-97.6, 159.4]. Batch, plain solo, traced solo and read-only probe agree; all 5,761 trace ticks match. The preceding 90 ticks contain ground contacts only. It counts as terrain under ruling 25. Its 48.6 m anchor gap exceeds 40 m. No pack exemption is inferred. Other qualified stops and unqualified raw records remain in the receipts; missing or rejected attribution cannot qualify zero terrain stops. No repair budget is consumed while the authored physical collapse and shared cue remain blocked.

**Historical round 5 qualification: BLOCKED.** STEP 0 merged candidate `3debeb86e30a63756e7e83c9950e37a79d656b68` at `56a4b80f8e9313cea755f11133dffb157eedcab7`, without conflicts. Every earlier traversal measurement is superseded by ruling 28. The bake and graph were rebuilt; the committed measuring tool is `tools/traversal_line.gd`, SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The first fresh Sable and Rivet children throw at `natural.gd:267` because the authored hollow-collapse effect lacks `depth_m`. TRAV-DET2 rejects those rows as INCONCLUSIVE. The population was stopped, so there is no accepted round-5 population, replay equality, band verdict or stop classification. No geometry repair was made. Evidence and input hashes are under `/home/andrew/scratch/w13/sol/kd2-flume-r5/`.

The real-stage stepped probe loads stage 2 and advances its director with tier 2 and one `chunk_2` notification. It records the reactor telegraph at 0.0611 s and land at 5.6111 s, with a live fallout hazard and `annex_ramp_line` open. It records the collapse telegraph at 0.2611 s and land fact at 13.9611 s, with `flume_mid` closed and `trestle_ramp_line` open. The collapse throws on missing `depth_m` during setup and `fill_s` at land. Its emitted facts do not prove a working fallen ramp. `events-stage-red.log`, `events-stage.json` and `events-verdict.json` retain the runtime result; the error-aware qualification is FAIL despite the probe's eight fact assertions passing.

Ruling 23, reaffirmed by ruling 28, makes the stage win criterion engagement-only. Engagement and breaks remain separate. The historical round-4 proof records 3/3 engages and 0/3 breaks under the wrapper that only sets `stage_limit = 600.0` before tick 1. 0/3 breaks does not pass a two-of-three break criterion. No round-5 completionist proof is claimed while the real-stage initialization has script errors. Warden fight duration stays with WT-PARK.

The two median-only tool flags remain unchanged under the coordinator's approved override. Current qualification reads raw seed records and takes the maximum anchor gap and quiet time against the unchanged 40 m and 20 s limits. `worst-controls.json` demonstrates rejection when seven passing seeds hide one 49.8 m anchor gap or one 20.59 s quiet interval. The independent checker refuses an incomplete population. The final complete table awaits a corrected shared collapse handler or approved authored depth and fill duration; historical cells below are not a current pass.

## 1. The stage in one paragraph

You drop in on the weir at the top of a mesa, where the reservoir behind stage 1's dam spills into a wooden flume. The flume runs 1.6 km across falling canal country on trestles that grow taller as the land drops away, and it ends at a penstock tower in the south-east, 90 m tall, with a green beam on top. You can ride the flume the whole way as one long grind, or drop off it into the canal fields, the trestle hollow, or the rim road above a horseshoe bend. The lines pinch twice, at a gap between two buttes and at the siphon where the canal dives under the hollow. They meet again in the head house at the tower's foot, where a reactor relic sits on the flume's last channel and boils it.

## 2. Arizona landform and society layer

**Landforms** (PARK.md:73). A weir on a 40 m mesa (`mesa_rim`), canal country falling 112 m along yaw 31 from north-west to south-east (`dry_wash` ground with a `ramp` stamp), Hohokam-style canals (`canal`), two buttes (`butte`), a trestle-spanned arroyo (`arroyo`), a horseshoe bend (`horseshoe_bend`, this stage's alone: the real one lies below a dam, in dam-era country) and a lower river gorge (`river_canyon`), the flume itself (`flume`) and the penstock works (`penstock`). Heights: the weir deck near y 146, the head house floor near y 29, the gorge floors about 95 m below their rims.

**Society layers.**

| Society | Where | What it left |
| --- | --- | --- |
| `none` | the buttes, the hollow, the bend, the gorges, the south bench | the ground itself |
| `dam_era` | the weir, the flume and its trestles, the rim road, the siphon, the wasteway, the forecourt, the head house and its annex | timber, concrete, gauges; the flume crews' signs |
| `hohokam` (reference) | the main canal, the gap cut, the lateral canal | graded canals, ridden as flow lines only |
| `dam_era` (crew camp) | the flume crews' bunk ledges cut into the mesa's south face and their timber crane booms | ledges and swing pivots; the cliff-dwelling layer is stage 1's, so world 1 shows each real culture once |
| `ancient` | the relic in the head house; a buried relic under the bend | uranium-glass green (#9dff3c) seams |
| `fleet` | a dropship lands on the south bench at tier 2 | a crew home |

The guardrail holds (PARK.md:301): the canal rows house no home, are no event's site (including the water events), and carry only `ref_` fragments. The flash flood runs in the dam-era wasteway, not in a canal.

## 3. The hero landmark and the Warden's mounting

**The penstock tower** (`landmark_penstock_tower`, `hero_landmark`). PARK.md:375 places "the flume head house at the top of the penstock tower". This draft reconciles that with the ground lines: the head house sits at the top of the penstocks, on the bluff edge where the flume ends, and the 90 m tower rises beside it as the surge tower. Every line then arrives at the head house on the ground, and the floor line can reach the Warden without a contraption (veto item 12, PARK.md:584). The penstocks leave the head house's east wall and fall 95 m down the bluff into the lower gorge. `sight_top` is the tower top, [300, 90, 560] in the shipped file; the land falls toward it from the whole park, so the drop-in looks down onto it. `light` is `ancient_beam`.

**The head house** is a round concrete drum 70 m across with 16 m walls (`head_house_drum`, a `bowl` row), roofed by open steel trusses at about 32 m. The flume enters through the north wall about 12 m up and pours down a channel onto the drum floor. Doors: the forecourt on the north-west, the annex on the south-west, the gate doors on the east facing the gorge.

**The mounting, `flume`** (PARK.md:425). The relic clamps onto the flume's pour channel, anchor [230, -2, 470], 12 m above the drum floor. Measured on the bake (KD2 fix round, 2026-10-11): the drum floor is y -14 (the `head_house_drum` terrace), the anchor y -2, and the `pour_channel` deck runs from the head reach's end at [200, 446] with its top at y -2, the anchor's height (`tests/park_park_flume_test.gd` pins it). The channel stops 38 m from the beacon, outside the 30 m engage disc, because a deck inside the disc fails `beacon_ok` (`tools/park_graph.gd:87-90`); the relic hangs at the channel's mouth and the reactor driver lays the slag lanes from its pour side (`warden_reactor.gd` `POUR_OFFSET`). The engage ring is the drum, centre [230, 480], `reach_m` 30, today's `beacon_radius` (`alpha_defs.gd:77`).

**What the mounting adds: it boils the flume.** Today's meltdown rule (`warden.gd:29-31`): every pulse leaves a slag lane toward the ball, 14 m long and 4 m wide, filling over 1 s and burning a grounded ball for 6 s at 4 damage a second (`warden.gd:56-60`, `263-291`). In the head house each lane pours out of the flume's channel and runs down the drum floor toward the ball, so the lanes come from one readable place. A ball in the air over a lane is safe and earns `slag_hop` (`codex_entries.gd:131-135`). The core window lasts 1.5 times longer, 6 s instead of 4 (`warden.gd:55`, `112-114`; `boss_posture.gd:17`).

## 4. Region sketch, and the exit to Brindle

Top-down, 80 m cells: the draft's region sketch, kept for the regions; `~` marks the draft's planned lines (the shipped lines are section 9). The placed list under it is generated from the shipped file (`src/world/park/park_flume.json`, KD2 fix round 2026-10-11): homes at their site row, contraptions at their `at` (a cable at its `from`), events at their site row.

```
x from -800 (left) to 800 m (right); z from -800 (top) to 800 m (bottom); one cell = 80 m
  -800 m m m m m n n n n n a a a a a o o o o o
  -720 m m m m D n n n n n a a a a a o o o o o
  -640 m m m ~ ~ ~ ~ n n n a a a a a o o o o o
  -560 m m ~ ~ ~ n ~ ~ n n a a a a a o o o o o
  -480 m ~ ~ ~ ~ C n n ~ n a a a a a o o o o o
  -400 f f f ~ ~ C n n ~ n a a a a a o o o o o
  -320 f f f f ~ H ~ ~ ~ r r r r r o o o o o o
  -240 f f f f f f ~ ~ ~ ~ C r r r o o o o o o
  -160 f f f f f f C ~ r r ~ ~ r r o o o o o o
   -80 f f f f f f ~ C r r r E r r o o o o o o
     0 f f f f f f ~ E ~ r ~ ~ r r o o o o o o
    80 f f f f f f ~ ~ ~ ~ ~ x q q o o o o o o
   160 s s s s s s s s ~ A ~ ~ ~ q o o o o o o
   240 s s s s s s s s ~ ~ E C ~ ~ o o o o o o
   320 s s s s s s s s s ~ C x q ~ l l l l l l
   400 s s s s s s s s s q ~ C ~ ~ l l l l l l
   480 s s s s s s s E A q q q W L l l l l l l
   560 s s s s s s s s s q q q q q l l l l l l
   640 s s s s s s s s s q q q q q l l l l l l
   720 s s s s s s s s s q q q q q l l l l l l
```

| Code | Region | What happens there |
| --- | --- | --- |
| m | The weir mesa | Drop-in, weir chute, the flume's intake, the crew camp ledges on the south face |
| n | Flume north reach | The flume's first kilometre on 40 to 50 m trestles |
| f | Canal fields | The main canal and the lateral canal, field banks, the flume trebuchet |
| g | The butte gap | First waymark: the canal and the flume thread between two buttes |
| h | The trestle hollow | An arroyo half-pipe under the flume's tallest trestles; drone home; the collapse |
| r | Rim road and the bend | The rim road over the horseshoe bend, the bend overlook, the buried relic |
| a | Upper canal country | Open ground cut by shallow dry washes (KD2's filler, section 5) |
| o | The horseshoe gorge and far rim | The bend's gorge, about 95 m deep |
| x | Siphon and wasteway | Second waymark (the siphon camp), the wasteway chute, the culvert wall |
| s | The south bench | Slickrock bench: the hauler bounty, the dropship landing |
| q | The bluff | The bluff rim, the forecourt, the head house, the annex, the tower |
| l | The lower gorge | The penstocks' fall; the launch to Brindle crosses it |

Placed things:

```
H weir_lobbers [-370, -340]
H trestle_drones [-185, 10]
H wasteway_chasers [85, 335]
H forecourt_brutes [150, 420]
H dropship_trappers [-300, 460]
C weir_valve [-160, -270]
C mesa_zip [-392, -442]
C hollow_lift [-210, -60]
C flume_trebuchet [-345, -120]
C forecourt_geyser [140, 400]
C squall_lane [120, 260]
C culvert_wall [117, 311]
C bend_zip [50, -170]
A siphon_camp [-28, 176]
A bend_cache [42, -142]
A bench_bounty [-119, 332]
E hollow_trestle_collapse [-185, 10]
E wasteway_flash_flood [85, 335]
E bench_dropship [-300, 460]
E bend_relic_wakes [150, -60]
E annex_reactor_blow [185, 525]
B bay dock [239, 480]
G gate row [300, 480]
L penstock_tower (landmark) [270, 510]
W Warden engage ring centre [230, 480]
D drop-in [-460, -650]
```

The three activities: the siphon camp (`enemy_camp` with today's Reach lobber pack and the named `loose_trigger` pay, `map_reach.gd:142`), the bend cache (`cracked_cache`) and the bench bounty (`hauler_bounty`). Today's Reach has a fourth, the ambush altar (`map_reach.gd:143`); it moves to stage 1's east bench, so world 1 keeps all four kinds and each stage has three (PARK.md:194). Since 2026-11-09 (ruling bu) the camp pays a common part rolled from the pool, with no named part (PARK.md 2.12).

**The exit to Brindle.** After the break, the reward gates stand on the bluff lip outside the drum's east doors at x 300, facing +x over the lower gorge, and the bay docks 61 m behind them over the drum (`bay.gd:37-41`, `143-153`), so `bay_dock.at` is [239, 480]. The launch throws the ball out of the east doors and across the gorge. Stage 2 is the world's last stage, so when the launch flight ends (`LAUNCH_FLIGHT` 0.6 s, `flow.gd:23`), `_finish_stage` calls `enter_boss` with the ball's velocity instead of advancing (`flow.gd:667-673`, `456-473`), and Brindle's module places the ball in the Slag Bowl (`boss.gd:15-17`). The arena stays small and authored (PARK.md:381). The park only points at it: from the bend overlook and the bluff, a smoke column and a furnace glow stand on the eastern horizon past the lower gorge, the launch arc aims at them, and the Requisition's anvil enters the music on the last chunk (section 10).

## 5. `park_rows` (219 rows, round 8 continuation 2026-10-13)

The shipped file is `src/world/park/park_flume.json`; the bake and the stage graph are under `assets/park/park_flume/` (KD2). The final file has 219 rows, including 52 rock outcrops and 26 shallow washes. The remaining 141 rows are rides and structures. The continuation rides and piers are listed below. Rows with recipes are placed in play by `ParkRecipes.build_placed`. Stamped greyboxes use the terrain collider; raised pieces use their placed colliders. Ride rows publish facts through sensors.

**The low country falls continuously.** The graph precision fix at `3fd07ae` permits the graded low terrace. It stays at +24 m above the northern datum through z -381.5, then falls to zero at z 220 along 601.5 m. The other two northern terraces retain their 15 m steps, the siphon scarp retains its 15 m lift, and the weir mesa retains its 40 m rise. The split falls between bake samples so the additive stamps do not overlap on a sampled boundary.

| Row | Element / landform / society | Verb, ride fact | Note |
| --- | --- | --- | --- |
| `canal_country`, `canal_country_mid`, `canal_country_low` | ground (plateau) / dry_wash / none | roll | the two northern terraces and low-country grade, edges at z -380, -150 and 220 |
| `siphon_scarp`, `weir_mesa` | ground (plateau) / mesa_rim / none | roll | the 15 m siphon scarp across the canal country at yaw 31; the 40 m mesa |
| `weir_deck`, `weir_gatehouse` | drop, ledge / mesa_rim / dam_era | drop `ride_drop`, roll | the drop-in deck (`greybox:drop`) and the gatehouse beside it |
| `weir_chute`, `mesa_ramp` | half_pipe, drop / flume, mesa_rim | pump, drop | the two 40 m ramps off the mesa (east under the flume, south to the canal) |
| `flume_weir_reach`, `flume_gap_reach`, `flume_hollow_reach`, `flume_head_reach`, `pour_channel` | grind_line / flume / dam_era | grind, `ride_grapple_line` | The weir, hollow, head and pour-channel deck bottoms are y 109.8, 44, 23 and -4. The gap span is a gradual climb from y 61 to 93 along its original corridor, a reversed drop wedge with the same `ride_grapple_line` fact. Its low end remains flush with the upper terrace. The hollow span now starts beside ground y 45 after the low-country regrade. The pour channel's top, -2, is the relic's height (section 3) |
| `weir_trestles`, `gap_trestles`, `hollow_trestles` | anchor_field / flume / dam_era | swing | the trestle bents either side of the weir reach's first 140 m (38 m tall), the hollow reach (16 m) retain their post fields. The gap trestles retain their layout row with no recipe; paired ride piers replace the lattice that caught Sable. The piers sit 28 m either side of the authored flume and are spaced no more than 32 m along it |
| `crew_ledges`, `crane_booms` | elevated_line, anchor_field / mesa_rim / dam_era | roll, swing | the crew camp on the mesa's south face (replaces the cliff rooms); the crane booms are a row of 40 m masts west of the mesa ramp, [-514, -395], the ramp's anchors |
| `mesa_rim_road` | drop / mesa_rim / dam_era | drop | home `weir_lobbers` |
| `main_canal`, `butte_gap`, `lateral_canal`, `main_canal_kicker` | flow_line, kicker / canal / hohokam | roll `ride_chute`, launch | `ref_` only; the gap is the first waymark |
| `west_butte`, `east_butte` | anchor_field / butte / none | swing | the gap's two buttes |
| `trestle_hollow` | half_pipe / arroyo / none | pump, `ride_chute` | 8 m deep and 40 m wide (was 60: at 60 m a ball on the floor had no anchor within 40 m); home `trestle_drones`; the collapse site |
| `rim_road`, `rim_road_kicker`, `bend_overlook`, `bend_rim_ledge`, `bend_return_wash`, `bluff_rim` | bank, kicker, ledge, half_pipe / mesa_rim, horseshoe_bend, dry_wash | bank, launch | the rim line, with `rim_flow_drop` descending from y 44 to 20 along 438 m; `bend_rim_ledge` [42, -142] holds the bend cache; the return wash carries the rim lines back to the siphon |
| `horseshoe_gorge`, `lower_gorge` | flow_line / horseshoe_bend, river_canyon / none | | channel stamps, 95 m |
| `the_siphon` | drop / canal / dam_era | drop | the second waymark's site, `greybox:drop` |
| `wasteway_chute`, `wasteway_wall_line` | half_pipe, bank / canal / dam_era | pump, bank | home `wasteway_chasers`; the flash flood; the wall line the flood opens |
| `bench_run_wash`, `bench_lip_bank` | half_pipe, bank / slickrock / none | pump, bank | the bench finish (a lip kicker was tried here and taken out: it opened anchor gaps of 57 to 77 m on the sable line) |
| `south_bench`, `bench_landing` | ground / slickrock / none | | the bounty's bench; dormant home `dropship_trappers` on the landing |
| `drum_forecourt`, `head_house_drum`, `heat_exchanger_annex` | ground, terrace, ledge / penstock / dam_era | roll, bank | home `forecourt_brutes`; the fight floor at y -14; the reactor blow site |
| `head_house_trusses`, `drum_lip_kicker`, `gate_lip` | anchor_field, kicker, ground / penstock / dam_era | swing, launch | the Warden exit: the 28 m ramp rises 14 m from the drum floor to its east lip, feeding the gate approach and trusses (`warden_exit` connected) |
| `weir_pond`, `gap_wash`, `field_bank_4`, `mesa_spill`, `pad_bank_4`, `pad_bank_5`, `pad_bank_7` | bowl, half_pipe, bank / mesa_rim, arroyo, dry_wash | bank, pump | the weir's pond and the draft's side washes and banks |

**Rock outcrops (52 rows, `<region>_outcrop_<n>`: mesa 4, canal 15, fields 12, bend 6, bench 5, bluff 10).** Sandstone outcrops 18 m across (a `butte` stamp, no recipe, so the terrain itself is the rock), set 15 to 45 m beside the pilot lines where a line had no face to hook within 40 m (PARK.md section 8's anchor band). An outcrop beside a cut (a canal, the hollow, a wash) stands 12 m, so a ball on the cut's floor sees it over the rim; the rest stand 8 m, which keeps the tower's sight share at 0.86 (14 m outcrops took it to 0.83). They replace the 25 `saguaro_*` anchor fields that tiled the map on a 320 m grid: those posts stood across the pilot lines (Sable's stops at [-245, -543] and [5, 176] were posts) and the page never authored them.

**Shallow washes (26 rows, `<region>_wash_<n>`).** Dry washes 1.5 m deep and 36 m wide, 160 to 720 m long, most running with the fall (yaw 31 or -59), cut across the open country away from every ride row so every open node is within 80 m of a row (`park_density_test`, worst 79.6 m at the south-west corner). They are terrain only (no recipe); a line crossing one rolls through a dip.

**Drum lip kicker moved 2026-10-23.** `drum_lip_kicker` moves from [253, 480] to [256.07, 480], so its back wall (the lip) lands at x 270.07, flush with the drum's east face foot. Before, the lip stood at x 267 and the gap from lip to terrace edge (first ground at or above y -0.5, x 272) was 5 m, with a floor slot about 3.5 m wide behind the wedge; a ball leaving the lip at 3 to 5 m/s met the face below the edge (about (270.5, -0.7)) and dropped into that slot. Measured on the built park by downward and horizontal physics rays: the ramp top is -12.74 at x 250, -7.94 at x 260, -0.58 at x 269 and 0.42 at x 270, the lip is x 270.07, the lip-to-edge gap is 1.93 m, and the floor slot behind the wedge is 0 m (0.93 m at y -7, where the face has risen to x 271). The `fit: seat` stretch lifts the lip to y 0.49. Bot runs (skipper, `--until=3`, `--fixed-fps 90`): seeds 10, 5 and 3 all leave the drum and reach stage 4; seed 10 with no fixed fps reaches stage 3. The graph tool (`tools/park_graph.gd` `_ride_edges`) now takes a kicker off its own nearest node when the 8 m lattice snaps the lip up a face of more than `CLIMB_M` (4 m); only this row hits that branch, so no other park's graph changed apart from the `tool_sha256` line, and `warden_exit` stays connected. Known limit: the lip (x 270.07, y 0.42 to 0.49) and the terrace edge (x 272, y 0.0) leave a 1.93 m notch; planted balls entering it from the terrace westbound at 2 to 10 m/s, or dropped over it, rest at (271.07, 0.37) with no input. Escape under input is not measured; `bot_flume_exit_test` counts a ball out only past x 272.5. (Superseded 2026-10-25: the notch is closed, next paragraph.)

**Drum lip kicker moved again 2026-10-25 (notch closed).** A player-ball probe on stage/alpha-w18 49bf68c7 found the notch is a V groove, not a ledge: downward rays read 0.42 at x 270 (the lip's top), -10.5 at x 270.5 and -0.0 at x 272 (the terrace's west face, normal (-0.99, 0.14)). A ball at rest there sits at (271.07, 0.37) touching the lip and the face with `grounded` false, so jump and boost never fire; a stick held at the terrace kept it there for 16 s, and a stick held toward gate 0 slid it 8 to 16 s along the groove and dropped it 13 m back into the drum (skipper seed 2865 sat 25 s there on 49bf68c7; completionist seed 14 on 52e5366e too). Receipt: `/mnt/project-files/gate/flume-lip-notch/PROBE.md`. The row now stands at [258.0, 480] with no `fit`, so it stands at the ground under its centre (the drum floor, -14) with its authored shape, and the 14 m rise puts the lip at x 272, y 0.0, on the terrace edge at the terrace's height. With `fit: seat` the exit is seated on the ground under it, which is now the terrace, and the far end rises 13 m (measured: 11.07 at x 270); an absolute `y` makes the row a deck in the park graph, and its deck nodes inside the beacon disc fail `beacon_ok`. The graph tool (`tools/park_graph.gd` `_ride_edges`) takes a lip that holds its own node over the face's top off from the nearest own node more than `CLIMB_M` below it, so `warden_exit` stays connected; no other park's graph changed apart from the `tool_sha256` line. Measured at z 480: ramp top -14.00 to x 244 (flush with the drum floor), -13.36 at x 250, -9.43 at 260, -3.71 at 268, -1.93 at 270, -0.98 at 271, 0.00 at 272 and the terrace 0.00 beyond; no point between x 270 and 274 dips below the ramp. `park_flume_lip_notch_probe_test` pins it: a ball dropped where the groove was is grounded in 0.24 s, a stick held east rolls it onto the terrace, a jump there rises 1.21 m, and a scripted line from the drum floor up the ramp reaches the gate level in 6.9 s. The ramp no longer ends in a step above the terrace, so a slow ball rolls on rather than leaving the lip; the curl at its top (about 45 degrees over the last 2 m) still throws a fast one.

### Continuation rides and anchor piers

The piers are placed solids with ride sensors. Their 12×4 m footprints sit beside the flume, bend zip and bluff runs. Their nominal stations were at most 32 m apart; the second rework moves them clear of all measured paths with an 18 m centre clearance. Two siphon piers had no clear candidate and were removed. The measured anchor gap below determines the band result.

| Row | Count | Element, fact, recipe | Placement |
| --- | --- | --- | --- |
| `flume_ride_pier_*` | 28 | `grind_line`, `ride_grapple_line`, `greybox:grind_line` | 50 m piers beside the ride, moved clear of measured paths |
| `bend_zip_pier_*` | 19 | `grind_line`, `ride_grapple_line`, `greybox:grind_line` | 40 m piers beside the ride, moved clear of measured paths |
| `bluff_ride_pier_*` | 18 | `grind_line`, `ride_grapple_line`, `greybox:grind_line` | 28 m piers beside the ride, moved clear of measured paths |
| `siphon_ride_pier_*` | 1 | `grind_line`, `ride_grapple_line`, `greybox:grind_line` | 32 m piers beside the ride, moved clear of measured paths |
| `mesa_entry_kicker` | 1 | kicker, `kicker_launch`, `greybox:kicker` | [-470, -495], base y 109, 24×3×20 m |
| `tally_field_kicker` | 1 | kicker, `kicker_launch`, `greybox:kicker` | [-195, 80], base y 36, 24×4×18 m; ends the field quiet stretch |
| `rim_flow_drop` | 1 | drop, `ride_drop`, `greybox:drop` | [-85, -130], base y 20, 438×24×36 m; a descending rim ride |
| `flume_entry_kicker` | 1 | kicker, `kicker_launch`, `greybox:kicker` | [40, 255], yaw 39.1, 18×4×10 m; clear of the siphon crossing and aligned with the head reach |

The siphon return, run-out and bench piers at [-85, 195], [12, 260] and [-55, 200] cover the regraded siphon reach. The bend turn pier at [78, 0] covers the measured Rivet and Kest gaps. The bench return pier at [-53, 480] covers Sable's wide exit. The forecourt surge mast at [203, 419] reaches 48 m above its ground and stays clear of the measured ground lines. The geyser carries at least 30 m/s toward its unchanged target, shortening the flight and keeping its apex beside the mounting anchors. Twenty duplicate pier footprints from the previous clearance search were removed.

The gap span is 24 m wide and climbs 32 m over its 272.9 m length, carrying the bot's corner cut on the same corridor. The mesa entry kicker retains its 3 m rise. The bench coping kicker at [-5, 438] rises 6 m over a 16 m ramp from base y 2, facing 88 degrees along the bench finish. The forecourt pad kicker at [62, 419] rises 3 m from base y 0, facing 57 degrees along Tally's pad approach. The bench coping pier at [50, 470] stands 28 m beside the hop's flight.

The gap span's base is y 61, keeping its entry below the turn's ground before the climb. The 132×6×104 m siphon approach bank at [-135, 149], facing 76 degrees, carries momentum through the nearly flat patch near [-98, 161]. Canal outcrop 14 is at [-270, -130], 24 m across and 22 m high, clear of the measured gap landing.

`turnout_kicker` now sits at [-177, 142], base y 31, 30×8×18 m. Its low entry stays below the hollow floor and its exit meets the south-end ground. `bend_return_wash` is 50 m wide. The head flume begins 32 m farther down its heading, clearing the Cannon's siphon crossing. Rock outcrops `bend_outcrop_5`, `bench_outcrop_4` and `bluff_outcrop_7` sit at [153, 12], [-30, 390] and [50, 385], outside the fixed collision sites.

The siphon approach bank remains at [-135, 149], yaw 76. Round 3 first reduced its 6 m rise to 2 m: Tally seed 5 cleared its terrain stop, but the eight-seed flow median fell to 0.6941. The second and last repair restores the 6 m rise and broadens the bank from 100×56 to 132×104 m, spreading the grade while retaining downhill carry. The final fixed-tool population determines the bands.

The round-4 bench exit grade is a stamped bank, 125×3×80 m, at [-91, 345], yaw -15. It fills the low wash floor before its exit and tapers towards the run-out, reducing the climb seen in Tally seed 5. It adds no recipe collider. This is the first of two permitted repairs at this site. The siphon approach bank is unchanged. The unchanged pilot lines and final population decide its acceptance.

The first round-4 kicker repair increased the rise from 3 to 3.25 m over its 8 m ramp. Rivet airborne median fell from 0.11995 to 0.117, and the matching seed-5 trace records a shorter local flight. The second and final repair uses a 16×6×24 m ramp at the same centre [-5,438], base y 2 and yaw 88. Its 6/16 pitch restores the original 3/8 pitch while lifting the exit farther above the landing. The pilot line and entry base stay fixed. The final population decides this last attempt; no third kicker repair is allowed.

The round-7 bounded hook repair adds `siphon_turn_coping` at [-92,128], 60×24×6 m, yaw 80, beside the ground-only reversal, and `bench_hop_coping` at [0,470], 16×28×8 m, yaw 90, beside the measured anchorless bench flight. Both are unstamped dam-era flume pieces. The bank and kicker stay unchanged. The round-7 eight-seed anchor band passed; Sable seed 2 retained its terrain stop. That round exhausted its repair allowance. Round 8 uses Y3 to authorize the local bank below.

Round 8 adds one `siphon_turn_bank` at [-97.57,153.39], a 24×4×16 m ridge at yaw 90. Its farthest corner lies 18.44 m from the reproduced stop, inside the 20 m limit in Y3. The prior approach bank and coping rows stay fixed. The same resolved span face now drives collapse clearance, warning and the physical ramp; the authored event site stays `trestle_hollow`.

## 6. `event_rows` (5 rows)

The round-7 stage regression proves registration, authored leads, common presentation records, landing facts, route changes and the live reactor fallout. It independently decodes the committed hollow floor and samples the falling flume span mesh and collider at four elapsed times through its authorized two-second fall. The candidate supplies the authored landing music cue. The earlier missing-field and missing-surface observations remain historical receipts.

| Row | Family, kind | Site | Trigger | Telegraph | What changes | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `hollow_trestle_collapse` | natural, `collapse` | trestle hollow | tier 1 | 6 s `trestle_groan` | A flume span over the hollow drops into a ramp | closes `flume_mid`, opens `trestle_ramp_line` |
| `wasteway_flash_flood` | natural, `flash_flood` | wasteway chute | tier 1 | 5 s `flood_rising` | 1.2 m of water for 30 s | closes `canal_lower`, opens `wasteway_wall` |
| `bench_dropship` | fleet, `fleet_landing` | bench landing [-300, 460] | tier 2 | 10 s `fleet_inbound` | a dropship lands and wakes `dropship_trappers` | none |
| `bend_relic_wakes` | ancient, `machine_eruption` | bend overlook | tier 1 | 8 s `ancient_stirring` | a `reactor_relic` miniboss erupts from the bend's rock | none |
| `annex_reactor_blow` | industrial, `reactor_blow` | heat-exchanger annex | Warden `chunk_2` | 5 s `reactor_overload` | a 20 m fallout ring, 6 damage, 8 s; the annex roof becomes a ramp into the drum | opens `annex_ramp_line` |

**The collapse is a ride, not a wall.** The span falls only when the ball is clear of it by `hold_clear_m` (20 m), after a 6 s groan on the flume. A ball arriving later rides off the flume's end onto the fallen span, now a ramp down into the hollow.

**The industrial row changes kind.** Stage 1 already has a boiler at chunk 2, so stage 2's is a `reactor_blow` in the annex. On the veto list.

Every route, opened or not, is connected on the stage graph (`assets/park/park_flume/graph.json`, 2026-10-11).

## 7. `home_rows` (5 homes)

| Home | Kind | Site, landform | Advantage | Counter | Reinforce | Break |
| --- | --- | --- | --- | --- | --- | --- |
| `weir_lobbers` | lobber | mesa rim road, mesa_rim | The rim road looks down the flume and the canal, two long held lines inside 75 m (`lobber.gd:12`) | Drop off the flume into the canal or back: the shell lands on the line you left (`lobber.gd:3-7`) | tier 1, 30 s, 4, `grounded` | slam, 80, 14 |
| `trestle_drones` | winch_drone | trestle hollow, arroyo | Drones roost in the bents; a 20 m winch lane along the flume (`winch_drone.gd:15`) hooks a ball that cannot step off a grind | Hold 19 m/s and the cable snaps (`winch_drone.gd:20`); a jump snaps it too | tier 1, 35 s, 3, `elite` | damage, 90, 16 |
| `wasteway_chasers` | chaser | wasteway chute, canal | One straight concrete floor, the lane a chaser lunges down | Pump the walls and come down on them from above the lane | tier 1, 25 s, 5, `run_down` | ram, 60, 12 |
| `forecourt_brutes` | plated_brute | forecourt, penstock | The forecourt is the drum's front door; a brute's 6 m slam ring (`plated_brute.gd:12`) covers the doorway every ground line rolls through | Take the forecourt geyser over the ring, or land on the brute from the bluff rim | tier 2, 40 s, 2, `elite` | damage, 140, 20 |
| `dropship_trappers` (dormant) | mag_trapper | bench landing, slickrock | A landed crew pits the bench a light ball crosses to reach the hauler | Grow past the rating, or jump and smash the disc (`mag_trapper.gd:6-9`) | tier 1, 35 s, 3, `grounded` | smash, 90, 16 |

The winch drone is the flume's natural enemy: it is the one kind whose threat is a held line, and the flume is the longest held line in world 1.

## 8. `contraption_rows` (9 rows), weather and time of day

| Row | Kind, skin | Where | What it does for the line |
| --- | --- | --- | --- |
| `weir_valve` | valve, `gauge` | the butte gap's east shelf [-160, -270]; door [-152, -252], cache [-142, -238] | The hidden pocket: ram the valve, the door sinks, the crew's cache behind it. Codex id `flume_weir_cache` (ruling R5) |
| `mesa_zip` | cable | from the mesa's south-east corner [-392, 110, -442] to the gap [-290, 55, -245] | A 225 m zip off the mesa to the butte gap; its ends sit 1 m over the baked ground so a rolling ball starts it |
| `flume_trebuchet` | launcher, `trebuchet` | canal fields [-345, -120] | Throws you into the trestle hollow at [-190, 31, -20], the hollow's floor; Tally's line takes it |
| `hollow_lift` | lift, `lift_platform` | trestle hollow [-210, -60] | Lifts 30 m to the trestle catwalk, inside harpoon range of the flume (45 m) |
| `bend_zip` | cable | bend overlook, [50, 55, -170] to [120, 40, -40] | A 150 m zip along the bend's rim; the Cannon's line rides it (`ride_grapple_line` measured) |
| `squall_lane` | thermal | bluff rim [120, 260] | The dust squall's visible wind lane, 50 m |
| `grade_wall` | cracked_wall sealing a cache | the canal grade west of the trestle hollow; wall [-267.8, 187.8] across the mouth of a cache room at [-272, 192] facing north-east | A second hidden cache, the Overtime Locker (W1-17, 12 Nov 2026): no marker; a ram at 0.85 x cruise crumbles the wall, puts a part on the pedestal and files codex id `flume_grade_cache` (camp count 8). The graph tool reads only the first sealed row as the hidden pocket, so `flume_side_spots_test` holds this one's spacing |
| `culvert_wall` | cracked_wall | beside the wasteway [117, 311], off its footprint (ruling R3) | Breaks at cruise into a culvert shortcut |
| `forecourt_geyser` | launcher, `geyser_vent` | forecourt [140, 400] | Lobs you over the brute ring and the drum wall onto the drum floor beside the relic, target [222, -12, 462] (2 m over the floor at -14) |

**Time of day: `morning`.** The sun has cleared the mesas; long shadows of the trestles fall west across the canal fields, and the head house's green seams read against a pale sky.

**Weather.** `morning_clear` (always) and `dust_squall` from tier 2: 15 s warning, 60 s live, 90 s gap, ochre fog at 0.003, a `dust` sky, a squall hiss, a `squall_shaker` music layer, collapse odds 1.5 times and flash-flood odds 0.5 times. `handling` is `"none"`.

## 9. Traversal lines

Four waymarks: `drop_in`, `butte_gap`, `siphon_camp`, `landmark`. The lines are `assets/park/park_flume/lines.json` (KD2 fix round, 2026-10-11). Segment 1 (drop-in to the butte gap): Sable takes the flume reaches off the weir; the other five and the floor line take the mesa ramp and the rim road. Segment 2 (gap to the siphon): Rivet and Kest the rim road and the bend, the Cannon the bend zip at [50, -170], Tarn and the floor line the trebuchet side and the hollow, Tally the trebuchet side then east across the fields, Sable the canal. Segment 3 (siphon to the drum): Sable, Rivet, Tarn and the floor line the bench and the forecourt, Kest the bluff, Tally the bench then the forecourt pads, the Cannon the forecourt geyser.

| Line | Waypoints |
| --- | --- |
| Sable | drop_in [-430, -615] [-369, -595] [-300, -586] [-225, -530] [-151, -472] [-180, -415] [-215, -350] [-250, -265] butte_gap [-240, -163] [-212, -100] [-200, -50] [-188, 0] [-176, 50] [-164, 100] [-142, 140] [-100, 158] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Rivet | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -199] [-120, -148] [-20, -97] [60, -56] [110, -31] [125, 0] [90, 62] [30, 114] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Kest | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -199] [-120, -148] [-20, -97] [50, -60] [110, -25] [110, 45] [40, 100] siphon_camp [20, 212] [60, 220] [120, 270] [180, 320] [240, 370] [278, 402] [258, 430] landmark |
| Tarn | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-214, 115] [-200, 140] [-110, 155] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Tally | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-195, 70] [-164, 100] [-142, 140] [-100, 158] siphon_camp [-15, 235] [-60, 300] [-100, 375] [-50, 420] [20, 392] [78, 430] [130, 445] [200, 445] landmark |
| The Cannon | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -205] [-130, -180] [-40, -172] [50, -170] [120, -40] [100, 20] [40, 100] siphon_camp [-5, 215] [40, 235] [95, 290] [125, 340] [120, 390] [160, 425] [215, 455] landmark |
| Floor line | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-214, 115] [-200, 140] [-110, 155] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |

**Round-4 greybox verdict: FAIL.** Completed final-geometry summaries cover 40/56 seed rows. Missing summaries and incomplete live runs remain pending, not passes. Candidate baseline Rivet-5, Sable-4, Tally-5 and floor-1 all reproduced solo with identical inputs under R24. Historical round-4 replay equality was PASS. Each round-4 table cell comes from that partial population, with per-seed bounds judged from the worst seed. Ruling 28 supersedes those measurements. No band, pilot line or kit changed in round 5.

**Historical measured round 4, 2026-10-12; superseded by ruling 28.** Geometry head `7838cffbf84d61dca1c0b448082e93467f3d4ae7`; candidate `b1cc003`; tool SHA256 `902da5cd3879fcc555f6ccc83a83548479d7f318d6e7783738baad4e5d2fbfe6`. Evidence `/home/andrew/scratch/w13/sol/kd2-flume-r4/final-population`, input manifests and commands.ndjson in the same round folder. R24 replaces the old export with the candidate tool. The table gives median/worst, or ranges where the band is bounded. The floor gates only its reach, time cap and zero terrain stops. Historical writer and gate measurements remain in the traversal page.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | 8 / 8 seeds pass |
| Time s, median 60–120; worst ≤150 | 63.73 / 64.8 pass | 96.055 / 98.71 pass | pending | 79.59 / 80.69 pass | 91.395 / 93.43 pass | pending | 96.77 / 98.42, reported, pilot band, not the floor's |
| Segments s, medians 12–45 | [21.66, 21.56, 20.51] / 22.08 pass | [26.99, 35.9, 33.315] / 36.62 pass | pending | [23.08, 26.01, 30.49] / 30.49 pass | [26.985, 30.355, 34.495] / 35.36 pass | pending | [27.975, 30.585, 38.2] / 38.97, reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9262 / 0.9212 pass | 0.76255 / 0.7445 pass | pending | 0.9584 / 0.9146 pass | 0.72405 / 0.6119 pass | pending | 0.5791 / 0.5594, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.238 / [0.238, 0.2602] pass | 0.1221 / [0.1098, 0.1315] pass | pending | 0.1638 / [0.1638, 0.1725] pass | 0.1256 / [0.124, 0.1301] pass | pending | 0.11945 / [0.1129, 0.1234], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0 / 0 pass | 0 / 0 pass | pending | 0 / 0 pass | 0 / 0 pass | pending | 0 / 0 pass |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.02, 45.69] / [54.02, 45.69] pass | [36.345, 8.37] / [32.76, 7.77] pass | pending | [35.48, 9.37] / [33.28, 8.71] pass | [36.41, 8.36] / [34.4, 8.14] pass | pending | [36.285, 8.11] / [34.12, 7.94], reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.74 / 8.03 pass | 11.69 / 12.15 pass | pending | 8.86 / 8.88 pass | 15.12 / 16.53 pass | pending | 12.515 / 12.78, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 30.2 / 49.8 MISS | 30.7 / 32.6 pass | pending | 28.1 / 33.4 pass | 32.8 / 35.4 pass | pending | 32.3 / 39.5, reported, pilot band, not the floor's |
| Ride facts, at least 3 | 5 / 5 pass | 5 / 5 pass | pending | 5 / 5 pass | 5 / 5 pass | pending | 5 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | pending | 1.36 / [1.36, 1.36] pass | 1.335 / [1.33, 1.34] pass | pending | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; 0 terrain stops | not applicable | not applicable | pending | not applicable | not applicable | pending | 96.77 / max 98.42; cap 192.11 pass |
| Distinct lines, reported | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | pending | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | pending | not supplied by fixed tool; not gated |
| Pack dead stops, classified separately | 0 | 0 | pending | 0 | 0 | pending | 0 |

Dead-stop sites by seed:

- None in the 40 completed summary rows; unmeasured rows remain pending.

**Tricks each line offers** (`class_def.gd:87-122`):

- **Sable**: the flume reaches off the weir, the canal past the trebuchet side, the bench, the forecourt.
- **Rivet**: the mesa ramp and rim road, the bend on the rim, the bench finish; every straight is a sprint lane.
- **Kest**: Rivet's rim and bend, then east along the bluff into the drum.
- **Tarn**: the mesa ramp, the trebuchet side of the gap, the hollow end to end, the bench. R27 keeps this measured line for round 4; the reported siphon claw-up probe below informs the coordinator journey decision.
- **Tally**: the trebuchet side, east across the fields to the siphon, the bench and the forecourt pads.
- **The Cannon**: the rim road, the bend zip, the forecourt geyser into the drum.

### Stop classification

All 40 completed final summary rows have zero raw stops; unmeasured rows remain pending. The candidate baseline had zero raw stops in 56/56 rows. The old Kest-2, Tally-3 and Cannon-2 exemptions are retired; no anonymous enemy contact is exempted. Floor seed 1 has zero stops in candidate baseline and matching solo. The old gate receipt remains classified as terrain. The R26 third siphon-bank repair was not used. The final bench grade is a separate site.

The independent round-3 gate classified floor seed 1 as terrain at 50.303 s, [-189.34,20.43,142.24], from its matching ground-only trace. Receipt: /tmp/claude-1000/w13-cgate/kd2-flume-r3/floor-solo1-trace-replay.json.

### Win proof under R23

The wrapper extends tools/bot_run.gd and only sets stage_limit to 600.0 while driver ticks are zero. KF8-WIRE mounts the reactor Warden at its authored anchor. The coordinator R23 criterion requires all three seeds to engage without a traversal stall; a fight that lasts the remaining stage limit belongs to Warden tuning.

| Seed | Engage s | Break s | Engage to break s | Outcome |
| --- | --- | --- | --- | --- |
| 1 | 116.39 | None | None | stalled / beacon |
| 2 | 117.43 | None | None | stalled / beacon |
| 3 | 143.06 | None | None | stalled / beacon |

R23 engage proof PASS. Raw receipts `/home/andrew/scratch/w13/sol/kd2-flume-r4/win-seed-*/bots.ndjson`. No Warden tuning or placement workaround was applied.

### Tarn journey probe, reported under R27

R27 keeps the bench line as the measured Tarn traversal for this round. That ruling does not amend the approved journey. A separate eight-seed probe steers from the siphon through [20,225], the entry kicker at [40,255], and along the last reach. Waypoints are in the round folder, never tools/park_lines. A reach counts only with ground contact on Park_flume_head_reach/Collider, within the authored 8 m-wide deck footprint and at its 25 m deck height. The coordinator owns the journey decision and text. No geometry was changed for the claw-up.

| Seed | Last reach reached | Reach s | To Warden s | Stops |
| --- | --- | --- | --- | --- |
| 1 | False | None | 74.42 | [{"at": [112.7, 355.1], "time": 64.5}] |
| 2 | False | None | 76.04 | [{"at": [113.5, 353.8], "time": 65.63}] |
| 3 | False | None | 73.74 | [{"at": [110.6, 351.6], "time": 63.76}] |
| 4 | False | None | 76.04 | [{"at": [113.5, 353.8], "time": 65.63}] |
| 5 | False | None | 72.87 | [] |
| 6 | False | None | 72.87 | [] |
| 7 | False | None | 74.42 | [{"at": [112.7, 355.1], "time": 64.5}] |
| 8 | False | None | 72.87 | [] |

Receipts `/home/andrew/scratch/w13/sol/kd2-flume-r4/journey-probe/tarn-seed-*-trace.json`; per-seed results `/home/andrew/scratch/w13/sol/kd2-flume-r4/journey-rows.json`.

## 10. Music arc

The stage row keeps theme 1, the sluice palette with the funk slap bass (`alpha_defs.gd:75`; `harmony.gd:117`; MUSIC-GEMS.md:18), and its `ace` id `cable_reach` (renaming an audio id buys nothing). Cue ids are proposals for KE8.

| Where or when | What the music does |
| --- | --- |
| Drop-in on the weir | The calm layer over the weir's water hiss; the slap bass enters as the ball first grinds the flume or reaches the canal |
| The flume's long grind | A held groove; each trestle bent the ball passes ticks a hat accent, so speed reads as tempo-locked ticks (cue `trestle_ticks`) |
| The butte gap | A one-bar break as the lines pinch, the groove back on the far side (cue `gap_break`) |
| Wasteway flash flood, trestle collapse | Stage-band riser over the lead, the drop on the landing |
| Dropship | Brindle's anvil and brass, one layer (SOUND-STORY.md:74) |
| Bend relic wakes | The Ab pedal and the Geiger tick (SOUND-STORY.md:59, 140) |
| Dust squall | `squall_shaker` layer while live |
| The siphon | A low-pass dip under the hollow, open on the far side |
| Warden engage | The world-1 Warden pivot to four on the floor at 129 (MUSIC-GEMS.md:13); the Ab pedal under every 2 s charge (SOUND-STORY.md:69) |
| Slag lanes | The lane's 1 s fill is a rising hiss; the burn is a dry crackle on the Geiger tick |
| Half broken, three quarters | The half-step lift, then the sinister break (MUSIC-GEMS.md:17) |
| Annex reactor blow (chunk 2) | Steam whistle into a percussion hit |
| Last chunk | Brindle's anvil enters under the sinister break: the boss is next |
| Break and launch | The unseal drop; the launch over the gorge rides into Brindle's music (G6, MUSIC-GEMS.md:16) |

## 11. Codex fragments from the society layer

| Id | Found at | Draft text |
| --- | --- | --- |
| `dam_era_flume_survey` | weir deck | Flume line surveyed by eye and string. The string was wrong twice. The flume is right. |
| `dam_era_trestle_tag` | flume, gap reach | Trestle 41. Inspected. Inspected again because 40 fell down. |
| `dam_era_road_marker` | mesa rim road | Rim road. Watch for falling crews. |
| `dam_era_siphon_plate` | the siphon | Inverted siphon: the water goes down, under, and up again. So will you. |
| `dam_era_wasteway_gauge` | wasteway chute | Wasteway gauge. When it reads high, the weir is dumping. Leave. |
| `dam_era_rim_milepost` | rim road | Milepost 3. The bend is prettier from here than from the bottom. |
| `dam_era_headhouse_log` | head house | Head house log: flow normal. Relic warm. Do not let it touch the flume. Note added: it touched the flume. |
| `dam_era_annex_dial` | heat-exchanger annex | A dial with one red band. The needle is in it. |
| `headhouse_relic_plate` | the landmark | The relic's cast plate, the same green as the dam's. Two of them. There were always more than one. |
| `ref_canal_headgate` | main canal | A headgate where the canal leaves the river: a gap in a stone and brush weir, set so the river feeds the canal at its own pace. |
| `ref_canal_gap_cut` | butte gap | The canal threads the gap between two buttes on the only line that keeps its fall. |
| `ref_canal_turnout` | lateral canal | Turnouts let the main canal feed smaller ones; the fields get their water in turn. |
| `dam_era_crew_bunks` | crew ledges | Flume crew bunks, cut into the mesa face. Bunk 6 has the view. Bunk 6 also has the draught. |
| `dam_era_boom_tag` | crane booms | Boom 3. Swung every trestle bent into place. Swings other things now. |
| `dam_era_siphon_span` | siphon span | Siphon span, rated for water at walking pace. Logged one ball at sixty. Span unchanged. Rating unchanged. |
| `dam_era_bent_board` | flume bent 1, weir end | Bent 1. Counting starts at the weir. Paint the ticks bigger; nobody reads them at speed. |
| `dam_era_survey_mast` | bend survey mast 1 | Survey mast 1. String from here to the bend, re-strung daily. The bend moved twice. The masts did not. |
| `dam_era_surge_pylon` | bluff surge pylon 1 | Surge line, pylon 1. Line carries the head house telephone. Head house rings first. |
| `dam_era_pour_lip` | pour channel | Pour lip. The flume ends at the drum rim and lets go. The water never minded the drop. |
| `dam_era_gatehouse_key` | weir gatehouse | Gatehouse key on the inside hook. Door locked from the outside. Crew uses the window. |
| `dam_era_crib_pier` | siphon bench pier | Crib pier, timber and river rock. Built to hold the siphon still. Holds most things still. |
| `dam_era_anchor_block` | bench coping pier | Anchor block for a penstock that was never laid. Poured anyway. The pour was already paid for. |
| `dam_era_intake_gate` | weir intake | Intake gate, hung open. Opened once in the dam's first spring. Nobody has found the crank since. |

The `ref_` texts need a fact check before they ship.

## 12. What stays from today's stage, and what has no table yet

**The stage row changes at KF0** (PARK.md:438, 544): `warden_family` `swarm` to `reactor`, `ancient` `swarm_remnant` to `reactor_relic`, `warden_variant` `""` to `meltdown` (`alpha_defs.gd:75-80`). **Stays:** plating 110, hp 800, `beacon_seconds` 25, `beacon_radius` 30, curve 2.0 with `ram_shatters` false, `PRESSURE[1]`, `PACKS` and `ELITE` (`alpha_defs.gd:42-47`, `61`). Display name "Spillway: the flume", map id `park_flume`.

**One knock-on to catch.** The meltdown mantle is keyed to stage 3 with family `reactor` (`hero_assets.gd:11-12`). After KF0, stage 3 fights the swarm, so that row mounts nothing ("a mismatch mounts nothing", `hero_assets.gd:10`) and stage 2's meltdown Warden has no mantle. KF0 or KF8 moves the row to stage 2.

**Warden band timing.** `REACH_SKIPPER_S` is 35 to 80 s and the completionist at most 1.25 times the skipper (`tests/alpha_posture_bands_test.gd:32`, `34`, `100-103`). Those were measured on the swarm's guard rack. The meltdown's 6 s core window shortens fights and its slag lanes lengthen them, so KF0 re-measures and re-pins with a dated header (PARK.md:444).

**Tests to re-pin** (names from the `tests/` listing; KD2 confirms): `alpha_posture_bands_test.gd`, `warden_variants_test.gd`, `warden_meltdown_slag_test.gd`, `warden_family_test.gd`, `world_one_wardens_test.gd`, `world_warden_flow_test.gd`, `stage_bay_test.gd`, `hero_warden_assets_test.gd`, `boss_flow_test.gd` (the hand-off to Brindle), and the win proof on `--table=park`.

**Fields today's map carries that the park file has no table for:** the Reach's three authored lines (`map_reach.gd:5-14`) retire into the pilot lines; its 13 `scrap_lines` (`map_reach.gd:120-134`) became the `scrap_trail` of the floor line in `assets/park/park_flume/lines.json` (ruling cd, 9 Nov: scrap on the beat, no gears or hoops); its kicker (`map_reach.gd:135`) becomes kicker rows. The four swing pillars at today's Warden site (`map_reach.gd:11`) become the head house's roof-truss anchors.

## 13. The shipped park file

The park file is `src/world/park/park_flume.json` (KD2 greybox continuation 2026-10-12, 219 park rows) and the lines are `assets/park/park_flume/lines.json`; the stage test `tests/park_park_flume_test.gd` pins them. Changes from the draft:

- Removed `cliff_rooms` and `viga_beams`; added the crew camp (`crew_ledges`, `crane_booms`), the three terraces, `bend_rim_ledge`, `drum_lip_kicker` and sized filler rows (no tiled saguaro grid).
- Removed `bend_far_rim`: the bend cache moved onto `bend_rim_ledge` [42, -142] beside the rim line.
- `weir_valve` stands on the butte gap with codex id `flume_weir_cache` (R5); `culvert_wall` sits off the wasteway footprint (R3).
- `warden_exit` runs `drum_lip_kicker`, `head_house_trusses`, `head_house_drum`; `landmark.warden` is the reactor on the flume mounting with `harpoon_anchor` true.
- Every `_est`, `_detour_m` and `pocket_est` key is gone; the numbers below come from `assets/park/park_flume/graph.json`.

| Pocket | Role | Door [x, z] | door_m | detour_m | d_spawn | d_landmark | sight_ok | pay |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `siphon_camp` | online | [-24, 176] | 0 | 0 | 1002 | 414 | True | common |
| `bend_cache` | reward | [40, -144] | 227 | 227 | 753 | 714 | True | rare |
| `bench_bounty` | risk | [-120, 336] | 171 | 171 | 1129 | 415 | True | common, rare |
| `weir_valve` | hidden | [-152, -248] | 99 | 99 | 558 | 906 | True | the cache |

The graph reports `reward_ratio` 0.532 against its starting target of at least 1.5. This reading is reported, not gated. Since ruling ac (26 Oct) `reward_ratio` has no target: the beacon is the park's far end, so no legal door reaches 1.5 (DECISIONS.md section 8).

The authored gates at [300, 480] use `bay.gd`'s active `play_rect` boundary. The stage fixture checks the deck samples and at least one level cradle against that map, checks clearance at both allowed lifts, and rejects a control dock at [700, 480].

The park file, verbatim (park_schema_test reads this block):

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_flume",
 "size_m": 1600,
 "time_of_day": "morning",
 "spawn": {"at": [-460, -650], "heading_deg": 31},
 "play_rect": [-780, -780, 1300, 1560],
 "landmark": {"id": "penstock_tower", "kind": "penstock_tower", "at": [270, 510], "size": [140, 90, 120], "yaw_deg": 31, "recipe": "landmark_penstock_tower", "budget": "hero_landmark", "sight_top": [300, 90.0, 560], "sight_share": 0.85, "beacon": [230, 480], "reach_m": 30, "warden": {"family": "reactor", "mounting": "flume", "anchor": [230, -2.0, 470], "path": [], "hardpoints": 3, "harpoon_anchor": true}, "bay_dock": {"at": [239, 480], "facing_deg": 90}, "gate_slots": [{"at": [300, 466], "facing_deg": 90}, {"at": [300, 480], "facing_deg": 90}, {"at": [300, 494], "facing_deg": 90}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "headhouse_relic_plate"},
 "waymarks": ["drop_in", "butte_gap", "siphon_camp", "landmark"],
 "routes": [
  {"id": "flume_upper", "from": "drop_in", "to": "butte_gap", "via": ["weir_deck", "weir_chute", "flume_weir_reach", "flume_gap_reach"]},
  {"id": "canal_upper", "from": "drop_in", "to": "butte_gap", "via": ["weir_deck", "mesa_ramp", "main_canal"]},
  {"id": "camp_rim", "from": "drop_in", "to": "butte_gap", "via": ["crew_ledges", "crane_booms", "mesa_rim_road"]},
  {"id": "flume_mid", "from": "butte_gap", "to": "the_siphon", "via": ["flume_hollow_reach"]},
  {"id": "canal_mid", "from": "butte_gap", "to": "the_siphon", "via": ["lateral_canal"]},
  {"id": "hollow_run", "from": "butte_gap", "to": "the_siphon", "via": ["trestle_hollow"]},
  {"id": "trestle_ramp_line", "from": "butte_gap", "to": "the_siphon", "via": ["flume_hollow_reach", "trestle_hollow"]},
  {"id": "rim_mid", "from": "butte_gap", "to": "the_siphon", "via": ["rim_road", "rim_flow_drop", "bend_overlook"]},
  {"id": "flume_lower", "from": "the_siphon", "to": "landmark", "via": ["flume_entry_kicker", "flume_head_reach", "pour_channel", "head_house_drum"]},
  {"id": "canal_lower", "from": "the_siphon", "to": "landmark", "via": ["wasteway_chute", "drum_forecourt", "head_house_drum"]},
  {"id": "wasteway_wall", "from": "the_siphon", "to": "landmark", "via": ["wasteway_wall_line", "drum_forecourt", "head_house_drum"]},
  {"id": "rim_lower", "from": "the_siphon", "to": "landmark", "via": ["bluff_rim", "head_house_drum"]},
  {"id": "forecourt_entry", "from": "drum_forecourt", "to": "landmark", "via": ["drum_forecourt", "head_house_drum"]},
  {"id": "bench_run", "from": "the_siphon", "to": "landmark", "via": ["bench_run_wash", "bench_exit_grade", "bench_lip_bank", "drum_forecourt", "head_house_drum"]},
  {"id": "annex_ramp_line", "from": "drum_forecourt", "to": "landmark", "via": ["heat_exchanger_annex", "head_house_drum"]},
  {"id": "warden_exit", "from": "landmark", "to": "gate_lip", "via": ["drum_lip_kicker", "head_house_trusses", "head_house_drum"]}
 ],
 "park_rows": [
  {"id": "canal_country", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -690.0], "y": null, "size": [620.0, 15.0, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_country_mid", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -575.0], "y": null, "size": [850.0, 15.0, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_country_low", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -690.75], "y": null, "size": [618.5, 24, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_country_grade", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -80.75], "y": null, "size": [601.5, 24, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_scarp", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [-553.2, -920.6], "y": null, "size": [2400, 15.0, 2400], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_mesa", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [-560.0, -620.0], "y": null, "size": [360.0, 40.0, 380.0], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_deck", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-460, -650], "y": null, "size": [44, 0.5, 30], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper", "canal_upper"], "fragment": "dam_era_flume_survey"},
  {"id": "weir_gatehouse", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-480, -625], "y": null, "size": [12, 10, 12], "yaw_deg": 31, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "weir_chute", "element": "half_pipe", "landform": "flume", "society": "dam_era", "at": [-299.0, -595], "y": null, "size": [140, 40.0, 30], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "mesa_ramp", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [-470, -369.0], "y": null, "size": [140, 40.0, 40], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": ""},
  {"id": "flume_weir_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-270.0, -520.0], "y": 109.8, "size": [260.8, 2, 8], "yaw_deg": 67.0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "weir_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-325.6, -543.6], "y": null, "size": [140, 38, 40], "yaw_deg": 67.0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_gap_reach", "element": "drop", "landform": "flume", "society": "dam_era", "at": [-215.0, -349.5], "y": 61, "size": [272.9, 32, 24], "yaw_deg": 152, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:drop", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": "dam_era_trestle_tag"},
  {"id": "gap_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-215.0, -349.5], "y": null, "size": [272.9, 14, 40], "yaw_deg": -28.0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_hollow_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-115.0, 5.5], "y": 44.0, "size": [373.0, 2, 8], "yaw_deg": 30.6, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_mid", "trestle_ramp_line"], "fragment": ""},
  {"id": "hollow_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-115.0, 5.5], "y": null, "size": [373.0, 16, 40], "yaw_deg": 30.6, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_head_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [124.1, 349.9], "y": 23.0, "size": [265.8, 2, 8], "yaw_deg": 39.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_lower"], "fragment": ""},
  {"id": "pour_channel", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [200.0, 446.0], "y": -4.0, "size": [14.0, 2, 8], "yaw_deg": 38.4, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": ["flume_lower"], "fragment": ""},
  {"id": "crew_ledges", "element": "elevated_line", "landform": "mesa_rim", "society": "dam_era", "at": [-600, -432], "y": 76.5, "size": [120, 1, 10], "yaw_deg": 90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_crew_bunks"},
  {"id": "crane_booms", "element": "anchor_field", "landform": "mesa_rim", "society": "dam_era", "at": [-514, -395], "y": null, "size": [100, 40, 20], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["camp_rim"], "fragment": "dam_era_boom_tag"},
  {"id": "mesa_rim_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-370.0, -340.0], "y": null, "size": [156.2, 1, 14], "yaw_deg": 39.8, "verb": "drop", "ride_fact": "ride_drop", "home": "weir_lobbers", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_road_marker"},
  {"id": "main_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-385.0, -275.0], "y": null, "size": [177.2, 3, 40], "yaw_deg": 73.6, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": "ref_canal_headgate"},
  {"id": "main_canal_kicker", "element": "kicker", "landform": "canal", "society": "hohokam", "at": [-368, -270], "y": null, "size": [10, 3, 8], "yaw_deg": 73.6, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "butte_gap", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-280, -230], "y": null, "size": [80, 3, 24], "yaw_deg": 30, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["flume_upper", "canal_upper", "camp_rim", "flume_mid", "canal_mid", "hollow_run", "trestle_ramp_line", "rim_mid"], "fragment": "ref_canal_gap_cut"},
  {"id": "west_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-345, -195], "y": null, "size": [70, 100, 70], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-215, -270], "y": null, "size": [60, 90, 60], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lateral_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-270.0, 15.0], "y": null, "size": [286.5, 3, 40], "yaw_deg": 29.2, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_mid"], "fragment": "ref_canal_turnout"},
  {"id": "turnout_kicker", "element": "kicker", "landform": "dry_wash", "society": "none", "at": [-177, 142], "y": 31.0, "size": [30, 8, 18], "yaw_deg": 80, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "trestle_hollow", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-185, 10], "y": null, "size": [289, 8, 40], "yaw_deg": 14, "verb": "pump", "ride_fact": "ride_chute", "home": "trestle_drones", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["hollow_run", "trestle_ramp_line"], "fragment": ""},
  {"id": "rim_road", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-85, -130], "y": null, "size": [438, 2, 40], "yaw_deg": 63, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": "dam_era_rim_milepost"},
  {"id": "rim_road_kicker", "element": "kicker", "landform": "mesa_rim", "society": "dam_era", "at": [-163, -170], "y": null, "size": [10, 3, 8], "yaw_deg": 63, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_overlook", "element": "bank", "landform": "horseshoe_bend", "society": "none", "at": [150, -60], "y": null, "size": [140, 2, 30], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": ""},
  {"id": "horseshoe_gorge", "element": "flow_line", "landform": "horseshoe_bend", "society": "none", "at": [290, -60], "y": null, "size": [500, 95, 180], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "the_siphon", "element": "drop", "landform": "canal", "society": "dam_era", "at": [-21.7, 186.3], "y": null, "size": [45, 3, 40], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": "dam_era_siphon_plate"},
  {"id": "wasteway_chute", "element": "half_pipe", "landform": "canal", "society": "dam_era", "at": [85.0, 335.0], "y": null, "size": [214.0, 10, 30], "yaw_deg": 37.4, "verb": "pump", "ride_fact": "ride_chute", "home": "wasteway_chasers", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_lower"], "fragment": "dam_era_wasteway_gauge"},
  {"id": "wasteway_wall_line", "element": "bank", "landform": "canal", "society": "dam_era", "at": [45.0, 365.0], "y": null, "size": [214.0, 2, 16], "yaw_deg": 37.4, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": ["wasteway_wall"], "fragment": ""},
  {"id": "bluff_rim", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [180.0, 320.0], "y": null, "size": [312.4, 2, 30], "yaw_deg": 50.2, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_lower"], "fragment": ""},
  {"id": "lower_gorge", "element": "flow_line", "landform": "river_canyon", "society": "none", "at": [430, 420], "y": null, "size": [500, 95, 120], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "drum_forecourt", "element": "ground", "landform": "penstock", "society": "dam_era", "at": [150, 420], "y": null, "size": [40, 2, 60], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "forecourt_brutes", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["forecourt_entry", "canal_lower", "wasteway_wall", "bench_run"], "fragment": ""},
  {"id": "head_house_drum", "element": "terrace", "landform": "penstock", "society": "dam_era", "at": [230, 480], "y": null, "size": [80, 14, 80], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:terrace", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["flume_lower", "rim_lower", "forecourt_entry", "annex_ramp_line", "canal_lower", "wasteway_wall", "warden_exit", "bench_run"], "fragment": "dam_era_headhouse_log"},
  {"id": "heat_exchanger_annex", "element": "ledge", "landform": "penstock", "society": "dam_era", "at": [185, 525], "y": null, "size": [40, 14, 24], "yaw_deg": 35, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": ["annex_ramp_line"], "fragment": "dam_era_annex_dial"},
  {"id": "head_house_trusses", "element": "anchor_field", "landform": "penstock", "society": "dam_era", "at": [284, 480], "y": 16.0, "size": [48, 14, 20], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "drum_lip_kicker", "element": "kicker", "landform": "penstock", "society": "dam_era", "at": [258.0, 480], "y": null, "size": [28, 14, 34], "yaw_deg": 90, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "gate_lip", "element": "ground", "landform": "penstock", "society": "dam_era", "at": [292, 480], "y": null, "size": [40, 2, 70], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "bench_run_wash", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-80, 305], "y": null, "size": [190, 4, 30], "yaw_deg": -15, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": ""},
  {"id": "bench_lip_bank", "element": "bank", "landform": "slickrock", "society": "none", "at": [20, 438], "y": null, "size": [230, 2, 30], "yaw_deg": 88, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": ""},
  {"id": "south_bench", "element": "ground", "landform": "slickrock", "society": "none", "at": [-200, 520], "y": null, "size": [260, 6, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_landing", "element": "ground", "landform": "slickrock", "society": "none", "at": [-300, 460], "y": null, "size": [70, 4, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_trappers", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "weir_pond", "element": "bowl", "landform": "mesa_rim", "society": "dam_era", "at": [-650, -690], "y": null, "size": [140, 3, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "gap_wash", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-255, -335], "y": null, "size": [180, 4, 40], "yaw_deg": -16, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "field_bank_4", "element": "bank", "landform": "dry_wash", "society": "none", "at": [-470, -120], "y": null, "size": [400, 2, 30], "yaw_deg": 20, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_spill", "element": "half_pipe", "landform": "mesa_rim", "society": "none", "at": [-570, -520], "y": null, "size": [120, 4, 30], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_return_wash", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [75.0, 35.0], "y": null, "size": [147.6, 4, 50], "yaw_deg": -28.3, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pad_bank_4", "element": "bank", "landform": "dry_wash", "society": "none", "at": [-152, -296], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pad_bank_5", "element": "bank", "landform": "dry_wash", "society": "none", "at": [288, 272], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pad_bank_7", "element": "bank", "landform": "dry_wash", "society": "none", "at": [120, 136], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_rim_ledge", "element": "ledge", "landform": "horseshoe_bend", "society": "none", "at": [42, -142], "y": null, "size": [40, 2, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_1", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-105, 281], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_2", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-33, 297], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_3", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-64, 362], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_4", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-30, 390], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_5", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-116, 426], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_1", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [118, -77], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_2", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [-36, -68], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_3", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [18, -40], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_4", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [46, 12], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_5", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [153, 12], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_6", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [38, 48], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [13, 102], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [144, 255], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [160, 339], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [8, 351], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [211, 381], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [237, 402], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [50, 385], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [163, 461], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [27, 466], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [96, 467], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-366, -628], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-224, -502], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-144, -493], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-425, -350], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-423, -323], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-375, -310], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-443, -254], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-399, -245], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-385, -238], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-189, -220], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_11", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-120, -205], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_12", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-80, -205], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_13", "element": "anchor_field", "landform": "butte", "society": "none", "at": [32, -191], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_14", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-270, -130], "y": null, "size": [24, 22, 24], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_15", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-40, -151], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-296, -113], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-282, -84], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-241, -78], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-355, -69], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-227, -22], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-325, -16], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-296, 36], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-212, 40], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-133, 86], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-247, 123], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_11", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-120, 127], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_12", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-180, 165], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_1", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-422, -647], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_2", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-478, -589], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_3", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-482, -521], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_4", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-488, -454], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_wash_1", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-440, 240], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_2", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-480, 360], "y": null, "size": [520, 1.5, 36], "yaw_deg": -59, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_3", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-360, 440], "y": null, "size": [520, 1.5, 36], "yaw_deg": -59, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_4", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-760, 560], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_5", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-120, 560], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_6", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-360, 640], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_7", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-400, 720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [520, -40], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [680, 0], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [600, 240], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [760, 320], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_3", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [400, 720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [240, -720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [640, -720], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_3", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [280, -640], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_4", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [360, -520], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_5", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-80, -480], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_6", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [360, -440], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_7", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [760, -400], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_8", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [80, -320], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_9", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-600, -160], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fields_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-720, 80], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fields_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-600, 200], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-440, -760], "y": null, "size": [160, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-760, -680], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_4", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-400, -480], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_1", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-396.6, -538.5], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_3", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-368.9, -527.4], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_5", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-341.3, -516.2], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_6", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-320.4, -568.2], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_7", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-313.6, -505.1], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_8", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-292.7, -557.1], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_9", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-285.9, -494.0], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_10", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-265.1, -546.0], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_11", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-258.3, -482.9], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_13", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-230.6, -471.8], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_15", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-202.9, -460.7], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_17", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-149.9, -512.7], "y": null, "size": [12, 50, 4], "yaw_deg": 68.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_19", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-182.8, -469.3], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_21", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-196.6, -442.4], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_22", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-136.0, -411.4], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_23", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-210.4, -415.5], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_24", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-160.5, -390.0], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_25", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-224.1, -388.7], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_26", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-174.3, -363.1], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_27", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-237.9, -361.8], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_28", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-188.1, -336.2], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_29", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-251.7, -334.9], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_30", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-201.9, -309.3], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_31", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-265.5, -308.0], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_32", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-215.6, -282.5], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_33", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-282.9, -282.9], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_34", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-229.4, -255.6], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_ride_pier_35", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-292.9, -263.1], "y": null, "size": [12, 50, 4], "yaw_deg": -27.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_1", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-130.3, -202.7], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_3", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-102.4, -201.9], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_5", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-74.6, -201.2], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_7", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-48.2, -144.5], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_8", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-46.8, -200.5], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_9", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-20.4, -143.8], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_10", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [-18.9, -199.8], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_11", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [7.5, -143.1], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_12", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [8.9, -199.1], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_13", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [35.4, -142.4], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_14", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [36.8, -198.3], "y": null, "size": [12, 40, 4], "yaw_deg": 88.5, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_15", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [32.3, -143.7], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_16", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [81.7, -170.3], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_17", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [46.3, -117.7], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_18", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [95.7, -144.3], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_19", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [60.3, -91.7], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_20", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [109.7, -118.3], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_21", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [123.6, -92.2], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_zip_pier_23", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [137.6, -66.2], "y": null, "size": [12, 40, 4], "yaw_deg": 28.3, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_1", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [53.2, 185.1], "y": null, "size": [12, 28, 4], "yaw_deg": 75.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_3", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [87.9, 206.8], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_5", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [107.9, 223.5], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_7", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [127.9, 240.2], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_9", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [147.9, 256.8], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_11", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [132.1, 316.5], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_12", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [167.9, 273.5], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_13", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [152.1, 333.2], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_14", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [187.9, 290.2], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_15", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [172.1, 349.8], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_16", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [207.9, 306.8], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_17", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [192.1, 366.5], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_18", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [227.9, 323.5], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_19", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [212.1, 383.2], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_20", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [247.9, 340.2], "y": null, "size": [12, 28, 4], "yaw_deg": 50.2, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_21", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [231.5, 399.4], "y": null, "size": [12, 28, 4], "yaw_deg": 49.9, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_22", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [267.5, 356.6], "y": null, "size": [12, 28, 4], "yaw_deg": 49.9, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_ride_pier_23", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [286.6, 372.6], "y": null, "size": [12, 28, 4], "yaw_deg": 49.9, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "siphon_ride_pier_1", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [31.9, 162.3], "y": null, "size": [12, 32, 4], "yaw_deg": 20.6, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_entry_kicker", "element": "kicker", "landform": "mesa_rim", "society": "dam_era", "at": [-470, -495], "y": 109.0, "size": [24, 3, 20], "yaw_deg": 0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "tally_field_kicker", "element": "kicker", "landform": "dry_wash", "society": "dam_era", "at": [-195, 80], "y": 36.0, "size": [24, 4, 18], "yaw_deg": 35, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "rim_flow_drop", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-85, -130], "y": 20, "size": [438, 24, 36], "yaw_deg": 63, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": ""},
  {"id": "flume_entry_kicker", "element": "kicker", "landform": "flume", "society": "dam_era", "at": [40, 255], "y": null, "size": [18, 4, 10], "yaw_deg": 39.1, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["flume_lower"], "fragment": ""},
  {"id": "bend_turn_pier", "element": "grind_line", "landform": "mesa_rim", "society": "dam_era", "at": [78, 0], "y": null, "size": [28, 28, 6], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_return_pier", "element": "grind_line", "landform": "slickrock", "society": "dam_era", "at": [-53, 480], "y": null, "size": [24, 18, 6], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "forecourt_surge_mast", "element": "grind_line", "landform": "penstock", "society": "dam_era", "at": [203, 419], "y": null, "size": [12, 48, 4], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_return_pier", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-85, 195], "y": null, "size": [20, 28, 6], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_runout_pier", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [12, 260], "y": null, "size": [12, 28, 6], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_bench_pier", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-55, 200], "y": null, "size": [24, 28, 20], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_coping_kicker", "element": "kicker", "landform": "slickrock", "society": "dam_era", "at": [-5, 438], "y": 2, "size": [16, 6, 24], "yaw_deg": 88, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "forecourt_pad_kicker", "element": "kicker", "landform": "penstock", "society": "dam_era", "at": [62, 419], "y": 0, "size": [8, 3, 20], "yaw_deg": 57, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_coping_pier", "element": "grind_line", "landform": "slickrock", "society": "dam_era", "at": [50, 470], "y": null, "size": [16, 28, 8], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_turn_coping", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-92, 128], "y": null, "size": [60, 24, 6], "yaw_deg": 80, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_hop_coping", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [0, 470], "y": null, "size": [16, 28, 8], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "siphon_approach_bank", "element": "bank", "landform": "slickrock", "society": "none", "at": [-135, 149], "y": null, "size": [132, 6, 104], "yaw_deg": 76, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_turn_bank", "element": "bank", "landform": "slickrock", "society": "none", "at": [-97.57, 153.39], "y": null, "size": [24, 4, 16], "yaw_deg": 90, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_exit_grade", "element": "bank", "landform": "slickrock", "society": "none", "at": [-91, 345], "y": null, "size": [125, 3, 80], "yaw_deg": -15, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": ""}
 ],
 "event_rows": [
  {"id": "hollow_trestle_collapse", "kind": "collapse", "family": "natural", "site": "trestle_hollow", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "trestle_groan", "on_bar": true}, "live_s": 0.0, "effect": {"swap": "trestle_ramp", "face": {"at": [-115.0, 5.5], "size": [373.0, 2, 8], "yaw_deg": 30.6}, "depth_m": 22.4413957595825, "fill_s": 2.0}, "route_change": {"closes": ["flume_mid"], "opens": ["trestle_ramp_line"]}, "hold_clear_m": 20.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}},
  {"id": "wasteway_flash_flood", "kind": "flash_flood", "family": "natural", "site": "wasteway_chute", "trigger": {"on": "clock_tier", "value": 1}, "weight": 0.6, "telegraph": {"lead_s": 5.0, "form": "flood_rising", "on_bar": true}, "live_s": 30.0, "effect": {"depth_m": 1.2, "fill_s": 4.0, "material": "water"}, "route_change": {"closes": ["canal_lower"], "opens": ["wasteway_wall"]}, "hold_clear_m": 15.0, "cooldown_s": 120.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flash_flood"}},
  {"id": "bench_dropship", "kind": "fleet_landing", "family": "fleet", "site": "bench_landing", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_trappers", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "bend_relic_wakes", "kind": "machine_eruption", "family": "ancient", "site": "bend_overlook", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "reactor_relic", "swap": "bend_vent_lip"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "annex_reactor_blow", "kind": "reactor_blow", "family": "industrial", "site": "heat_exchanger_annex", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "reactor_overload", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "fallout_ring", "hazard_m": [20, 20], "damage": 6.0, "swap": "annex_ramp"}, "route_change": {"closes": [], "opens": ["annex_ramp_line"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "weir_lobbers", "enemy": "lobber", "site": "mesa_rim_road", "landform": "mesa_rim", "advantage": "From the rim road a lobber looks down the flume and the canal, two long held lines inside its 75 m range (lobber.gd:12).", "counter": "Drop off the flume into the canal, or the other way: the shell lands on the line you left (lobber.gd:3-7).", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 4, "pack": "grounded"}, "break": {"by": "slam", "hp": 80.0, "scrap": 14}, "stops_kind": true, "dormant": false},
  {"id": "trestle_drones", "enemy": "winch_drone", "site": "trestle_hollow", "landform": "arroyo", "advantage": "Drones roost in the trestle bents; a 20 m winch lane along the flume (winch_drone.gd:15) hooks a ball that cannot step off a grind.", "counter": "Hold 19 m/s and the cable snaps on its own (winch_drone.gd:20); a jump snaps it too.", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "elite"}, "break": {"by": "damage", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "wasteway_chasers", "enemy": "chaser", "site": "wasteway_chute", "landform": "canal", "advantage": "The wasteway floor is one straight concrete lane, the lane a chaser lunges down.", "counter": "Pump the wasteway walls and come down on them from above the lane.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 5, "pack": "run_down"}, "break": {"by": "ram", "hp": 60.0, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "forecourt_brutes", "enemy": "plated_brute", "site": "drum_forecourt", "landform": "penstock", "advantage": "The forecourt is the drum's front door, and a brute's 6 m slam ring (plated_brute.gd:12) covers the doorway every ground line rolls through.", "counter": "Take the forecourt geyser over the ring into the drum, or come off the bluff rim and land on the brute from above.", "reinforce": {"from_tier": 2, "every_s": 40.0, "max_alive": 2, "pack": "elite"}, "break": {"by": "damage", "hp": 140.0, "scrap": 20}, "stops_kind": true, "dormant": false},
  {"id": "dropship_trappers", "enemy": "mag_trapper", "site": "bench_landing", "landform": "slickrock", "advantage": "A landed crew pits the bench a light ball crosses to reach the hauler.", "counter": "Grow past the rating, or jump and smash the disc (mag_trapper.gd:6-9).", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "grounded"}, "break": {"by": "smash", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "weir_valve", "kind": "valve", "site": "butte_gap", "recipe": "gauge", "at": [-160, -270], "door": {"at": [-152, -252], "size": [12, 6, 1], "turn": 0.6}, "cache": {"at": [-142, -238]}, "codex": {"id": "flume_weir_cache", "title": "Pressure keeps the change", "category": "world", "name": "Pressure keeps the change", "hint": "A cracked wheel beside a copper door.", "clue": "Ram the valve on the Reach's west shelf + the copper door", "text": "A rolling ram turns the old valve. Behind the sinking door, the crew's spare parts wait."}},
  {"id": "mesa_zip", "kind": "cable", "site": "mesa_rim_road", "recipe": "", "from": [-392, 110.0, -442], "to": [-290, 55.0, -245], "radius": 4.0, "floor": 18.0},
  {"id": "hollow_lift", "kind": "lift", "site": "trestle_hollow", "recipe": "lift_platform", "at": [-210, -60], "radius": 4.5, "rise": 30.0, "charge": 3.2, "offset": 0.0},
  {"id": "flume_trebuchet", "kind": "launcher", "site": "canal_country", "recipe": "trebuchet", "style": "trebuchet", "at": [-345, -120], "radius": 3.5, "target": [-190, 31.0, -20], "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
  {"id": "forecourt_geyser", "kind": "launcher", "site": "drum_forecourt", "recipe": "geyser_vent", "style": "geyser", "at": [140, 400], "radius": 3.5, "target": [222, -12.0, 462], "floor": 30.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "squall_lane", "kind": "thermal", "site": "bluff_rim", "recipe": "", "at": [120, 260], "radius": 6.0, "height": 50.0},
  {"id": "culvert_wall", "kind": "cracked_wall", "site": "wasteway_chute", "recipe": "", "at": [117, 311], "size": [10, 6, 1.4], "turn": 1.2, "break_at_cruise": true},
  {"id": "bend_zip", "kind": "cable", "site": "bend_overlook", "recipe": "", "from": [50, 55.0, -170], "to": [120, 40.0, -40], "radius": 4.0, "floor": 18.0}
 ],
 "weather_rows": [
  {"id": "morning_clear", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0006, "color": "#b4c6d2"}, "sky": "clear", "sound": "bench_morning_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "dust_squall", "kind": "dust_squall", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 15.0, "live_s": 60.0, "gap_s": 90.0, "fog": {"density": 0.003, "color": "#c8a878"}, "sky": "dust", "sound": "squall_hiss", "music_layer": "squall_shaker", "event_odds": {"hollow_trestle_collapse": 1.5, "wasteway_flash_flood": 0.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "siphon_camp", "activity": "enemy_camp", "site": "the_siphon", "at": [-28, 176], "pack": ["lobber", "lobber", "lobber"], "pay": {"named": "loose_trigger", "rarities": ["common"]}},
  {"id": "bend_cache", "activity": "cracked_cache", "site": "bend_rim_ledge", "at": [42, -96], "face": [0, 1], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "bench_bounty", "activity": "hauler_bounty", "site": "south_bench", "at": [-119, 332], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
}
```

The pilot lines, verbatim:

```json
{
  "map": "park_flume",
  "stage": 2,
  "pilots": {
    "sable": {"waypoints": ["drop_in", [-430, -615], [-369, -595], [-300, -586], [-225, -530], [-151, -472], [-180, -415], [-215, -350], [-250, -265], "butte_gap", [-240, -163], [-212, -100], [-200, -50], [-188, 0], [-176, 50], [-164, 100], [-142, 140], [-100, 158], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "rivet": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -199], [-120, -148], [-20, -97], [60, -56], [110, -31], [125, 0], [90, 62], [30, 114], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "kest": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -199], [-120, -148], [-20, -97], [50, -60], [110, -25], [110, 45], [40, 100], "siphon_camp", [20, 212], [60, 220], [120, 270], [180, 320], [240, 370], [278, 402], [258, 430], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tarn": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-214, 115], [-200, 140], [-110, 155], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tally": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-195, 70], [-164, 100], [-142, 140], [-100, 158], "siphon_camp", [-15, 235], [-60, 300], [-100, 375], [-50, 420], [20, 392], [78, 430], [130, 445], [200, 445], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "cannon": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -205], [-130, -180], [-40, -172], [50, -170], [120, -40], [100, 20], [40, 100], "siphon_camp", [-5, 215], [40, 235], [95, 290], [125, 340], [120, 390], [160, 425], [215, 455], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
  },
  "floor": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-214, 115], [-200, 140], [-110, 155], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"]}
}
```

## 14. Storyboard

Board `park-2-park_flume`. `p1_overhead` is plotted; the rest are generated. Three vista subjects for this stage are on `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json`.

| Panel | Frame |
| --- | --- |
| `p1_overhead` | Frame 0 |
| `p2_drop_in` | Frame 1 |
| `p3_line` | Frame 2 |
| `p4_home` | Frame 3 |
| `p5_event` | Frame 4 |
| `p6_warden` | Frame 6 |

**Frame 0, the plan.** The section 4 grid to scale: the mesa top-left, the flume's long S to the tower bottom-right, the pinches at the gap and the siphon, the gorges on the east.

**Frame 1, the drop-in vista.** From the weir deck in clear morning light, looking south-east down a long fall of canal country. The flume leaves the weir at your feet on timber trestles and runs away in a long S, its trestles growing taller as the land drops; green canal lines cut the tan fields; two buttes stand at the first bend; at the far end, 1.3 km away and below you, a slim concrete tower with a green beam stands beside a round head house on a bluff over a gorge.

**Frame 2, the first flow line.** Chase camera beside the ball grinding the flume 45 m above the ground, the timber channel a ribbon ahead, the trestle bents flicking past below, the butte gap opening ahead with the canal glinting through it.

**Frame 3, an enemy home.** The trestle hollow from its floor: an arroyo half-pipe, the flume's tallest trestles striding across it 49 m up, winch drones roosting in the bents, one drone's winch lane drawn along the flume, the ball high on the hollow's wall below them.

**Frame 4, an event firing.** The hollow trestle collapse in two beats. Left: the span groaning, dust falling from its joints, the warning colour over the full 373×8 m flume span. Right: the span down at an angle into the hollow, a ramp now, and the ball riding off the broken flume end onto it.

**Frame 5, the landmark approach.** Up the wasteway chute toward the forecourt: the round head house filling the frame, the tower rising behind it, the flume's last reach entering its north wall, plated brutes walking the forecourt, a slam ring dusting the doorway.

**Frame 6, the Warden fight.** Inside the drum: steel trusses overhead, the relic clamped on the flume's pour channel 12 m up with green seams blazing, two orange slag lanes running down the floor toward the ball, and the ball in the air over one of them, a harpoon line taut to a truss.

**Frame 7, the exit.** Through the east doors after the break: the three gates on the bluff lip, the bay over the drum, the ball launched out across the lower gorge toward a smoke column and a furnace glow on the eastern horizon, where the Requisition waits.

**Flush liners, 2026-10-19 (coordinator's #183 ruling; World's 07:32Z recommendation (a)).** All 11 bake-conformed liners of this stage (`liner_trestle_hollow`, `liner_gap_wash`, `liner_mesa_spill`, `liner_bend_return_wash`, `liner_bench_run_wash`, `liner_wasteway_chute`, `liner_weir_chute`, `liner_weir_pond`, `liner_main_canal`, `liner_butte_gap`, `liner_lateral_canal`) carry `flush_lane` in `tools/blender/park/flume_works.py`. A liner has no `-col`, so anything visible in a ride lane taller than the 0.12 m flush band must be solid; the rule is that inside any ride row's footprint of `park_flume` the drawn surface stands no more than 0.12 m above the ground. The reference is the game's ground mesh itself (`terrain.gd`'s 2 m grid cut a, b, c / b, d, c along the b-c diagonal, planar per triangle, not the bilinear height), and the test is exact: the surface minus that mesh is linear on each piece of a triangle cut by the mesh's edges and the footprints' edges, so `--check` (`liner_check`) reads the extremes at those pieces' vertices. Inside any ride row's footprint the surface stands between 0.03 m and 0.12 m above the ground mesh; everywhere else it stands at least 0.03 m above it (`FLUSH_MIN`; Terrain3D's own diagonals and LOD can fold the drawn ground above the collider planes), and its corners may rise up to 0.22 m outside every footprint. Nothing is left out: a lattice cell whose plain triangles keep that band stays plain (its corner offsets may be nudged together to fit), and any other cell is cut along the ground mesh's edges and the footprints' edges, each piece set on the ground plus its relief and clamped to the band inside a footprint, while a plain neighbour takes the shared edge's kink points, and `--check` fails the build on any crack or T-junction step. `--check` also fails a liner with a crack (a vertical step or a T-junction height mismatch over 3 mm), a lane point no drawn triangle covers (apart from cells another flush row takes), or more triangles than its registry class cap. Outside every footprint (the margin strips past a row's ends, say) the band does not apply: sheet styles may stand up to 0.22 m there, and the floor band is relaxed from 0.08 m to 0.12 m inside a footprint and 0.22 m outside one; whole-lane flatness is not claimed or checked. The concrete walls, joints and gauge staff, the canal lips and the pond's rim ring and pitching keep their look outside every footprint and are held to the band inside one (the pond lies almost entirely inside ride footprints, so its relief is mostly capped). The sheets ship no rim rocks, tufts or detail shells, so the 22 `liner_*_detail{1,2}.glb` are deleted (the loader skips a missing shell, and nothing pinned them). Colliders, sensors and the bake are unchanged; this is draw-only. Turned liners whose sheets overlap (`gap_wash`, `main_canal` and `butte_gap`) no longer z-fight: where two flush sheets overlap, the row whose lane holds the cell keeps it, where two lanes cross (or neither holds it) the earlier row wins, and a cell only partly covered stays. The cut costs triangles, so five liners take larger registry classes (the class only sets the cap; the park rows' `budget` stays `landform`): `liner_trestle_hollow` (13.9k), `liner_gap_wash` (9.5k), `liner_main_canal` (9.5k) and `liner_lateral_canal` (14.3k) are `park_large` (16,000), and `liner_wasteway_chute` (22.3k) is `hero_landmark` (24,000, the only class above it). The builder reads each liner's cap from its class.
