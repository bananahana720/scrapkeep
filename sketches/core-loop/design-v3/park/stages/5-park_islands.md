# Stage 5: Highdraft, the sky islands (`park_islands`)

**Decoration-only pass, 2026-10-19 (wave 18, islands unit, revised after review).** Three stamped greybox rows become `scatter` (`net_bowl`, `west_shelf`, `ore_bench`; the precedent of park_flume `horseshoe_gorge` and park_pit `floor_sump`) and six draw bake-conformed, decoration-only liners: `run_turn_wash`, `lookout_stair`, `east_ribs`, `net_post_run`, `cloud_wash_east` and `ore_chute` (`liner_<row id>`, `tools/blender/park/flume_works.py --isles`, over `assets/park/park_islands/ground.bin`, no `-col`, no `fit`). That is nine rows in all, three scatter and six liners. Reverted to `greybox` after review, with their original recipes: `slickrock_run`, `fan_band` and `net_carve` (stamped ramps: a stamped row's greybox stand-in sits at ground minus its own stamp raise, but a `scatter` row is sensor-only and its sensor box stands on the raw ground, up to half the ramp height higher, so `ride_chute` coverage of the low half of the ramp and its speed-bank clears and cues would have moved), and `isle_apron` (scatter keeps out of every footprint except ground, plain slopes, mesa edges and `scatter` rows and has no event hook, so `fan_band`, `net_carve` and `isle_apron` opened the `twin_fins`, `west_wing` and `lens_rocks` event footprints to scatter; `isle_apron`'s only change was its recipe, no data fix). They draw nothing after the stamp replaces them. For the remaining rows no event site footprint (`twin_fins`, `mooring_mesa`, `mooring_pad`, `lens_rocks`, `west_wing`) intersects any scatter row or liner: the nearest are `net_bowl` 20 m from `west_wing` and `ore_chute` 29 m from `twin_fins` in x counting the liner's 3 m margin (about 40 m true, the rows themselves); `net_post_run` (x -60 to 60, 63 with its liner margin) does not overlap `west_wing` (x -270 to -150), an 87 m gap. No collider and no ride sensor of consequence moved, for these reasons: the nine rows were stamped, so the stamp is their ground and their greybox boxes never drew or collided; scatter pieces and liners carry no `-col`; and the three ramp rows whose sensor boxes would have moved by half the ramp height are back to their original recipe. A scatter or liner row is no longer a greybox stand-in, so its sensor stands on the raw ground instead of ground minus its own stamp raise (`ParkRecipes.seat`); for the nine rows that raise is 0 (`net_bowl`, `run_turn_wash`: a cut) or the plateau stamp's own 0.01 m, so the sensors move up by at most 1 cm. Flush lanes: each liner here carries `flush_lane` in `ISLES_LINERS`. Inside any ride row's footprint of `park_islands.json` (every row with a `ride_fact`, the liner's own lane and the full-width rows `slickrock_run`, `fan_band`, `net_carve` and the rest included, with scatter's footprint math: `size[0]` along the facing, `size[2]` across) the drawn surface stands between 0.03 m and 0.12 m above the game's ground mesh, and everywhere it stands at least 0.03 m above it (`FLUSH_MIN`), with corners up to 0.22 m outside every footprint (outside them the 0.12 m band does not apply and sheet styles may stand up to 0.22 m; whole-lane flatness is not claimed). The reference is the ground mesh itself, the 2 m grid cut a, b, c / b, d, c with the b-c diagonal (`terrain.gd`), planar per triangle, not the bilinear height, and the test is exact. A lattice cell whose plain triangles keep that band stays plain (its corner offsets nudged together to fit); any other cell is cut along the ground mesh's edges and the footprints' edges, each piece set on the ground plus its relief and clamped to the band inside a footprint, with the plain neighbours taking the cut's points on the shared edge, so no cell is left out and no crack opens. Because those footprints cover all the ground the liners' rims reach, rim rocks and tufts are dropped wherever a prop would touch a footprint (rocks reach 0.7 m, tufts 0.5 m), and every islands liner ends up with no rim props at all, so none ships detail shells (no `_detail1` or `_detail2` GLB, no registry row; `park_recipes.gd` `_load` skips a missing shell and the shell list is built from what loads). Adjacent sheets are clipped so they do not overlap: `lookout_stair` stops at x = -80 where `run_turn_wash`'s lane begins and `run_turn_wash` stops there on its side (no z-fight across the old x -83 to -77 overlap). `liner_check` loads the park's ride rows and measures every triangle exactly against the ground mesh (the surface minus the ground is linear on each piece of the triangle cut by the mesh's edges and by each footprint, so its extremes are at the pieces' vertices): it fails a liner whose lowest point is under 0.03 m above the ground, whose highest point inside a footprint is over 0.12 m, that has a crack (a vertical step or a T-junction height mismatch over 3 mm), whose lane has a point no drawn triangle covers, or whose triangles exceed its registry class cap (all six fit `landform`, 8,000; `ore_chute`, the largest, is 7,966). `lookout_stair` and `east_ribs` (40 m flow_line lanes, not washes) use the `haul` style; `run_turn_wash` and `cloud_wash_east` keep `sandstone`; `net_post_run` is `haul` and `ore_chute` `rails`. Left greybox on purpose: `fin_chute` (the `fin_rim_collapse` event drops twin_fins' ground 8 m and a baked-ground liner would hang over it) and `cloud_wash_west` (the `isle_shed` impact swaps `west_wing` to a crater); `ore_adit`, `tram_head`, `keel_rib_w` and `keel_rib_e` take World-2's #183 pieces (below). Placeholder gate: 6 park_islands rows remain greybox (`net_carve`, `fin_chute`, `cloud_wash_west`, `slickrock_run`, `fan_band`, `isle_apron`), 30 across the parks on stage 958bbdcd. Wash liners use `sandstone` or `haul`, one style name per row in `flume_works.py` `ISLES_LINERS`, so a Content dry-wash kit can replace it by editing that field. Traversal: `design-v3/park/traversal/park_islands.md`, 2026-10-19.

**Over-greybox pieces, 2026-10-19.** The four rows `ore_adit`, `tram_head`, `keel_rib_w` and `keel_rib_e` now draw World-2's #183 pieces (`isle_adit_portal`, `isle_tram_head`, `isle_keel_rib`) over their unchanged greybox colliders, ride sensors and stamp marks (`place_over_greybox`, pinned by `park_over_greybox_test`); `ore_adit` also gains the portal posts' own `PieceCollider`, outside the lane (|x| >= 9.225). The keel rows' budget moves from `detail` to `landform` as World-2's 03:35Z table recommends, so they draw to landform range; the `isle_keel_rib` asset itself (about 3,700 tris) stays inside the detail class's 4,000 cap, and its registry class still reads `detail` (World-2's file).


**Ride-surface sheet, 2026-10-21.** `cloud_wash_west` draws `isle_ride_wash_west` (`tools/blender/park/isle_ride_pieces.py`, landform class, 4,672 triangles, one draw, no `-col`) over its unchanged stamped ground, as an OVER_GREYBOX recipe: node, seat, `ride_chute` sensor and stamp mark are the greybox's own and the stamp still replaces the box. It covers the whole wash (x -226..-194, z 110..410) less a hole round `cloud_cannon_west`'s mouth, every vertex 0.04 to 0.08 m over the ground the ball rolls on (`--check` and `park_over_greybox_test` fail outside +0.03 to +0.12 m, #183). The sheet lies inside `isle_shed`'s impact overlay (the game builds it over the whole `west_wing` footprint, x -270..-150, z 100..420), which only raises ground (`event_ground.gd:236`), so where the crater rim rises the sheet is buried under the raised ground and never floats. The `.bin` files (`ground.bin`, `graph.bin`) do not move; the park-file hash pins in `bake.json` and `graph.json` do, as in the earlier over-greybox swap. Left greybox: `fin_chute`, wholly inside `twin_fins`' footprint, where `fin_rim_collapse` drops the ground 8 m and hides only `Park_twin_fins`, so a sheet would hang in the air after the collapse; and `slickrock_run`, `fan_band`, `net_carve` and `isle_apron`, full-rect stamped bands 1,600 m across the play rect, whose full dressing at 2 m cells is 136k to 283k triangles against the landform cap of 8,000, so no over-greybox piece can honestly dress them (pending a coordinator ruling).

## Round 5 measurement, 2026-10-13

Admission remains held. Candidate `3debeb8` merged without conflicts at
`1f4ad76`. The retained measurement programs are `05a0b56, faa5cd2`; the submitted head is `e496b0f`. Ruling 28
requires the committed `tools/traversal_line.gd`, SHA-256
`37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`.
All measurements before the STEP 0 merge are superseded and retained below.
The design sections and shipped appendix remain current.

The valid tool logs have no script errors. The first merged-head runs exposed
KD5's missing `fin_rim_collapse.effect.fill_s`; those invalid rows are retained
and excluded. The stage row now declares its instantaneous landing explicitly
with `fill_s: 0.0`, after a committed red-first assertion. No shared tool,
pilot-line, Warden or combat value changed. The first Rivet batch was
INCONCLUSIVE after seed 5 hit the 120-second child wall cap. Its fresh
300-second-cap recovery retains all eight seeds; every complete row from
the capped batch matches its recovery. Only the wall bound changed.

Sable seed 2 and Rivet seed 4 agree in all fields between their untraced batch,
untraced solo and traced solo. No fields were removed or normalized.
The agreement receipt (`kd5-islands-r5/agreement.json`, historical scratch artifact outside the repo) retains the raw comparisons
and source fingerprints. The shared traversal/runtime disagreement is resolved
for these named seeds. The first complete batches remain the measurements.

The table comes from raw seed rows in the independent assessment (`kd5-islands-r5/bands-independent.json`, outside the repo).
There are 56 completed rows currently. Median and worst seed
or seed range appear together. Airborne and length are judged per seed, and
anchor gap uses the maximum seed. Segment and tier-3 gates retain their median
rules. The floor uses only reach, its time cap and zero stops, per ruling 13.
Current misses are `{"sable": ["time_median"], "tally": ["length"]}`.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS |
| Time to Warden, s | 59.055 / 60.58: FAIL | 89.39 / 90.86: PASS | 74.075 / 76.2: PASS | 81.19 / 81.19: PASS | 70.215 / 70.78: PASS | 82.015 / 83.4: PASS | 82.77 / 83.35: reported, pilot band, not the floor's |
| Segment medians / worst time, s | 15.22/22.04/21.82 / 23.16: PASS | 24.505/36.425/28.48 / 37.7: PASS | 22.68/22.61/28.73 / 28.81: PASS | 22.43/31.22/27.52 / 31.4: PASS | 24.43/18.07/27.085 / 27.96: PASS | 22.73/32.31/26.94 / 32.91: PASS | 24.8/33.03/24.92 / 34.16: reported, pilot band, not the floor's |
| Flow share | 0.9451 / 0.9287: PASS | 0.8754 / 0.8422: PASS | 0.9126 / 0.8705: PASS | 0.9685 / 0.9517: PASS | 0.9682 / 0.96: PASS | 0.9889 / 0.9824: PASS | 0.8954 / 0.8954: reported, pilot band, not the floor's |
| Airborne share | 0.4034 / 0.3776..0.4084: PASS | 0.33545 / 0.2598..0.3425: PASS | 0.3581 / 0.3385..0.3608: PASS | 0.2967 / 0.2875..0.2967: PASS | 0.3246 / 0.3209..0.3276: PASS | 0.35435 / 0.3485..0.3555: PASS | 0.2914 / 0.2899..0.293: reported, pilot band, not the floor's |
| Raw dead stops | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS |
| Peak speed / tier-3 time | 55.93 m/s, 46.1 s / 55.93 m/s, 39.67 s: PASS | 30.54 m/s, 8.405 s / 29.44 m/s, 7.52 s: PASS | 29.78 m/s, 6.71 s / 28.93 m/s, 6.2 s: PASS | 30.79 m/s, 10.29 s / 30.79 m/s, 10.29 s: PASS | 27.295 m/s, 6.5 s / 26.7 m/s, 4.31 s: PASS | 28.53 m/s, 10.91 s / 27.97 m/s, 5.88 s: PASS | 32.87 m/s, 12.41 s / 31.76 m/s, 9.28 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: PASS | 5.99 / 6.57: PASS | 3.285 / 3.56: PASS | 6.1 / 6.1: PASS | 3.525 / 3.72: PASS | 3.78 / 3.78: PASS | 7.62 / 7.62: reported, pilot band, not the floor's |
| Anchor gap, m | 32.1 / 34.5: PASS | 27.6 / 32.0: PASS | 26.0 / 33.7: PASS | 19.5 / 22.9: PASS | 19.25 / 19.8: PASS | 20.9 / 20.9: PASS | 38.4 / 38.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: reported, pilot band, not the floor's |
| Length / straight distance | 1.65 / 1.65..1.66: PASS | 1.455 / 1.45..1.46: PASS | 1.36 / 1.36..1.38: PASS | 1.54 / 1.54..1.54: PASS | 1.26 / 1.26..1.26: FAIL | 1.5 / 1.5..1.5: PASS | 1.45 / 1.45..1.45: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | worst 83.35 s / cap 178.78 s; 0 stops: PASS |
| Distinct lines | Sable, Rivet and Tarn distinct on all 8 seeds in both directions (worst overlap 0.391 under 0.5, planar 8 m method); Sable, Tarn and Cannon also distinct; Rivet and Cannon not (0.501). Receipt: /home/andrew/scratch/w13/cgate/kd5-islands-r5/comparison-result.json | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack |


One bounded bank repair per failing pilot was tried at `d55b1a5`.
The full eight-seed remeasurement still failed Sable's median time, 59.07 s,
and Tally's length, 1.26 on every seed. Both trial lines had zero stops.
The banks were reverted at `e496b0f`; exact runtime-byte equivalence restores
the complete baseline and fresh win receipts. The failed trial (`kd5-islands-r5/repair-band-assessment.json`, historical scratch artifact)
is retained. No further geometry repair is authorized by this packet.

Raw stops with no matching causal enemy receipt count as terrain. No pack
exemption is claimed from the older, superseded traces. Any nonzero current
stop remains held until its matching solo trace and ruling-25 enemy probe
identify its cause. Zero-stop rows need no causal exemption.

### Effective Warden criterion

The round-5 coordinator packet resolves the brief conflict. R23 is an
engagement-only proof: every seed reaches and engages the mind Warden,
with no traversal-caused stall before engagement. The two-of-three break
requirement in the earlier brief and focus question is superseded.
The wrapper changes only the driver's stage limit to 600 seconds before
its first tick. Break time and engage-to-break time are still reported.
WT-PARK and WT-BANDS own Warden duration. KD5 does not change the Warden
row, combat values or bot behavior.

| Seed | Outcome | Engage s | Break s | Engage to break s |
| --- | --- | --- | --- | --- |
| 1 | stalled | 139.15 | null | null |
| 2 | stalled | 133.73 | null | null |
| 3 | stalled | 127.96 | null | null |

R23 verdict: PASS. Breaks observed: 0/3. The fresh win receipt (`kd5-islands-r5/win-review.json`, historical scratch artifact) retains the complete rows.

These are automated headless receipts. Human feel, dressing, listening and
physical hardware acceptance remain unqualified.

## Superseded round 4 measurement

**Status: greybox admission held. On the candidate tools, Sable seed 2 stalls in the batch and reaches solo; Rivet seed 4 changes under tracing. R22 requires the coordinator to reopen TRAV-DET. The dated sections retain both the current measurements and the earlier independent failures.**

## Round 4 candidate measurement, 2026-10-12, program head 7e6368d

Admission remains held. Candidate `9467de7` merged without conflicts at `5223b95`.
The terrain and pilot lines are unchanged. Two independent bake/graph builds
are byte-identical. These new runs use the committed candidate traversal tool
at fixed FPS 90, nice 10, through the two-core queue with at most two traversal
processes together. Every run has fresh XDG state.

R22 stops geometry work because complete seed rows still disagree on identical
inputs. The agreement receipt (`kd5-islands-r4/agreement.json`, historical scratch artifact)
retains the complete rows and every changed field. All six comparison runs have
the same runtime digest `fa895d4e75cf2271d9d8be26d79ddbc93c59710bdabf7e1ecf4c4b13cd754c13`;
individual source and asset hashes are in each run's runtime-input manifest.
The coordinator must reopen TRAV-DET. No shared tool, enemy, pilot line, Warden
row or terrain was edited, and no terrain try was spent.

| Pilot and seed | Mode | Engage s | Airborne | Flow | Path m | Raw stops |
| --- | --- | --- | --- | --- | --- | --- |
| sable 2 | batches | null, stalled | 0.1094 | 0.1639 | 2482.8 | 110 |
| sable 2 | solo-sable | 58.92 | 0.4002 | 0.9496 | 2084.8 | 0 |
| sable 2 | traced-solo-sable | 58.92 | 0.4 | 0.9496 | 2084.7 | 0 |
| rivet 4 | batches | 89.16 | 0.3312 | 0.8724 | 1817.7 | 0 |
| rivet 4 | solo-rivet | 89.16 | 0.3312 | 0.8724 | 1817.7 | 0 |
| rivet 4 | traced-solo-rivet | 89.77 | 0.3304 | 0.8815 | 1825.2 | 0 |

Sable reaches 7/8 in the untraced batch. Seed 2 has null engage time, flow 0.1639,
airborne 0.1094, quiet time 23.38 s and 110 raw stops. Its matching solo reaches
at 58.92 s with zero stops. The traced solo also reaches at 58.92 s, but airborne
and path length differ from untraced solo. Rivet's untraced batch and solo seed 4
agree completely; its traced solo changes time, airborne, flow, path and other
fields. A traced batch was not run after this disagreement, following R22.
The other four pilot batches and new distinct-line traces are held for the
shared traversal/runtime repair. Earlier receipts do not qualify this program.

The batch table below is the measured result, not a qualifying pass. Values
are computed independently from raw seed rows in the band assessment (`kd5-islands-r4/bands-independent.json`, outside the repo).
Every cell shows median and worst seed or seed range. Sable's time median uses
its seven reached seeds; its worst seed is stalled with null time. Its three
segment medians likewise use seven completed rows, while seed 2 has all three
segments null. Sable's 58.98 s median also misses the unchanged 60 s minimum.
The airborne and length checks use every raw seed, and the anchor check uses
the maximum seed. Tier-3 and segment gates retain their authored median rules.
Only reach, the time cap and zero stops gate the floor, per R13.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 7/8: FAIL | 8/8: PASS | not measured | not measured | not measured | not measured | 8/8: PASS |
| Time to Warden, s | 58.98 / null stalled seed; max reached 59.91: FAIL | 89.27 / 89.79: PASS | not measured | not measured | not measured | not measured | 81.9 / 84.09: reported, pilot band, not the floor's |
| Segment medians / worst time, s | 15.21/22.31/21.45 / 22.85: PASS | 24.435/36.385/28.425 / 36.78: PASS | not measured | not measured | not measured | not measured | 23.78/34.11/24.0 / 34.91: reported, pilot band, not the floor's |
| Flow share | 0.93275 / 0.1639: FAIL | 0.88225 / 0.8724: PASS | not measured | not measured | not measured | not measured | 0.9004 / 0.8882: reported, pilot band, not the floor's |
| Airborne share | 0.3889 / 0.1094..0.3971: FAIL | 0.33325 / 0.3295..0.3386: PASS | not measured | not measured | not measured | not measured | 0.2897 / 0.2878..0.2925: reported, pilot band, not the floor's |
| Raw dead stops | 110 total / 110 worst: FAIL | 0 total / 0 worst: PASS | not measured | not measured | not measured | not measured | 0 total / 0 worst: PASS |
| Peak speed / tier-3 time | 54.81 m/s, 45.955 s / 44.61 m/s, 6.03 s: PASS | 30.65 m/s, 8.95 s / 29.34 m/s, 7.74 s: PASS | not measured | not measured | not measured | not measured | 31.82 m/s, 9.64 s / 30.86 m/s, 7.98 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 23.38: FAIL | 6.14 / 6.81: PASS | not measured | not measured | not measured | not measured | 4.83 / 5.4: reported, pilot band, not the floor's |
| Anchor gap, m | 33.95 / 34.9: PASS | 28.9 / 33.7: PASS | not measured | not measured | not measured | not measured | 41.4 / 41.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 4: PASS | 6.0 / 6: PASS | not measured | not measured | not measured | not measured | 6.0 / 6: reported, pilot band, not the floor's |
| Length / straight distance | 1.66 / 1.64..1.99: PASS | 1.46 / 1.45..1.46: PASS | not measured | not measured | not measured | not measured | 1.46 / 1.45..1.46: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | worst 84.09 s / cap 178.54 s; 0 stops: PASS |
| Distinct lines | not measured; R22 hold | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | unresolved | 0 terrain / 0 pack | not measured | not measured | not measured | not measured | 0 terrain / 0 pack |

The floor reaches 8/8, with worst time 84.09 s against twice Rivet's 89.27 s median, a cap of 178.54 s. It has 0 raw stops.

Stop classification remains unresolved for Sable's 110 untraced stops. The solo
traces contain zero stops and cannot classify that different batch. No qualification with zero terrain stops or pack-contact exemption is claimed. Coordinates and
times are retained in the stop evidence (`kd5-islands-r4/stop-evidence.json`);
matching causal collider/enemy identities are missing. Rivet and the floor,
when their measured raw total is zero, require no stop classification receipt.
The historical 83 unclassified stops and 13 ground-contact increments below
remain evidence for `db2f034`, not classifications of this program's 110 stops.

The stage-local geometry assertion now reads all 18 step-lip markers from this
stage's authored appendix, retaining their 1 cm plateau specification. The
external mutation receipt (`kd5-islands-r4/mutations.json`)
shows waymark, rebuilt 3 m step-lip and Warden-family plants all make the stage
test red. Each was restored byte for byte with `git checkout --`. The restored
stage test passes 18 checks. Eight named smoke files pass with zero failures,
zero missing verdicts and zero omitted checks. Compilation against `9467de7`
and lint pass. These checks establish automated headless behavior, not human
feel, dressing, listening or hardware acceptance.

### R23 Warden proof on the same program

The external wrapper extends `res://tools/bot_run.gd` and sets only
`_driver.stage_limit = 600.0` before the first driver tick. The proof uses the
park table, completionist, `--from-stage=5 --stages=5`, with fresh state per seed.
R23 requires all three seeds to reach and engage with no pre-engage traversal
stall. A Warden unbroken at the limit is reported for the Warden tuning owner.
The win receipt (`kd5-islands-r4/win-review.json`)
retains every complete outcome row and the exact engage and break times.

| Seed | Outcome | Engage s | Break s | Engage to break s |
| --- | --- | --- | --- | --- |
| 1 | stalled | 141.79 | null | null |
| 2 | stalled | 132.4 | null | null |
| 3 | stalled | 126.14 | null | null |

R23 verdict: PASS. Breaks observed: 0/3. Missing or capped rows do not establish engagement.

## Acceptance review, 2026-10-12, submitted head db2f034

Admission on `db2f034` is held. The table below records the independent gate's
untraced Sable batch and the original Rivet miss. The round-3 table remains an
**earlier writer pass**, with its Rivet failure, rather than current acceptance.

| Active acceptance evidence on db2f034 | Sable | Rivet |
| --- | --- | --- |
| Reach | **FAIL: 7/8**, seed 2 stalled | 8/8 |
| Seed 2 engage time | **FAIL: null**, stalled | n/a |
| Flow minimum | **FAIL: 0.3064** | earlier writer table |
| Airborne minimum | **FAIL: 0.165** | **FAIL: 0.2482**, seed 4 |
| Length maximum | **FAIL: 2.79** | earlier writer table |
| Dead stops | **FAIL: 83 raw stops**, unclassified | 0 in earlier writer batch |
| Stop qualification | classification unresolved; zero terrain unqualified | batch/solo/trace agreement held |

The independent untraced batch (`w13-cgate/kd5-islands-r3/sable-recovery/sable.json`, historical scratch artifact)
and mode comparison (`w13-cgate/kd5-islands-r3/sable-mode-comparison.json`)
show why the earlier Sable pass cannot qualify this head. The differing traced
batch has 13 ground-contact increments, with Ground/Tiles contacts and no enemy
contact in the preceding 90 ticks. Its stop receipt (`w13-cgate/kd5-islands-r3/sable-batch-trace-stops.json`)
cannot classify the 83 untraced stops or supply a matching solo trace.

Rivet's batch/solo/traced-solo airborne values remain 0.2482/0.3070/0.3107.
The favorable repeat at 0.2517 does not replace the original miss. The
round-3 writer report (`w13-sol/kd5-islands-r3/REPORT.md`)
retains that disagreement. Coordinator ruling R22 authorizes measurement with
the candidate's imported TRAV-DET repair. Qualification requires new complete
seed-row agreement and the unchanged worst-seed bands; the two pages will use
those same receipts when they are available.


Unit KD5, wave 13, continued 12 October 2026. The park file, bake and graph are built. The dressed pass has not started. Every number marked "(start)" is a starting value to tune in play. The tables follow TADR-011 and PARK.md section 2 field for field. A schema check and a rough sight check ran on this draft; section 16 says how.

| Field | Value |
| --- | --- |
| Stage and world | 5, The Highdraft (world 3) |
| Map id and display name | `park_islands`, "Highdraft: the sky islands" |
| Warden | `mind` (the Mind's hand) on `under_island`, variant `""` (today `choir`, `src/core/alpha_defs.gd:110`; PARK.md:441 drops it) |
| Time of day | `golden` (today a morning light, `src/presentation/world_look.gd:35`) |
| Kind sheet | `design-v3/wardens/mind.md` |
| Boards | stage board `park-5-park_islands` (panels p1 to p6); key art in the concept board `park-w3` |

## In one look

You drop off a pine-topped mountain at golden hour and ride a downhill park of mesas. The animals have strung nets across every gap, so a fall always lands on rope. Over the far end of the park hangs an upside-down mountain, balanced on one hand lit in the ancients' green. The fight is in the net bowl under it.

| Number | Value (start) |
| --- | --- |
| Drop-in | the Lookout's top, 220 m |
| Net deck | 60 m, under the whole park |
| Mesas and buttes | 120 to 220 m tops; three low rocks below that on purpose (the Anvil 72 m, the knuckles 80 m) |
| The Hanging Isle | top deck 400 m, tip 82 m, 180 m across |
| The Warden | a 16 m hand: palm 82 m, knuckle hardpoints 88 m, lens 72 m; net bowl floor 44 m |
| Pilot lines, drop-in to engage | 1,516 to 1,787 m, 58 to 89 s at 20 to 26 m/s |
| Sight share (rough model) | 0.877 over 701 cells |

## 1. The Arizona landform and the society layer

**The real place.** The Madrean sky islands of south-east Arizona: forested ranges that rise out of the desert, pine on top, desert below, and relict species stranded up high when the valleys dried. Around them sit slickrock, hoodoos and dry washes. The park takes the silhouette and the ecology, not a real name (PARK.md veto 18, `BIBLE.md:979`).

**The park disguise.** Each mesa is a sky island: a height stamp with a flat, pine-dotted top. The gaps between them are the animals' net deck at 60 m (PARK.md:378 and veto 10; `design-v3/BIBLE-AMENDMENT-park.md:105`). Mesas are where you ride. Nets are where you land. Thermals, cables and balloon lifts take you back up.

**Who built what.** One society per row, so the codex reads the land.

| Society | Where on this stage | What it left | What it means in play |
| --- | --- | --- | --- |
| `none` (water and time) | the mesas, the Twin Fins, the hoodoos, the washes, the relict pines | slickrock, varnish, balanced caps | the ground itself: ramps, banks, chutes |
| the animals (no society id; filed under `none`) | the net deck, the bowl net, the posts, the balloon lifts | rope, posts, patched envelopes | the floor and the way back up; the posts are harpoon anchors |
| `dam_era` | the fire lookout on the Lookout's east rim; the stone switchback stair down its west face | a lookout log, stamped stair stones | two of the three ways off the drop-in mesa |
| `mining` | the aerial tram's timber top station on the Saddle, the tramway to the Ore Bench, the adit through it, the ore chute down to the Anvil | a ledger, an assay, a lamp, worn chute boards | the east fan: cable, tunnel, grind |
| `fleet` | the Mooring Mesa: winch posts, a moored balloon, a landing pad | mooring tags | the anchor crews' home and the dropship's landing site |
| `ancient` | the Lens Rocks (a buried hand under the east butte); the Hanging Isle | a hum, grip marks | the eruption event and the Warden |

No `hohokam` or `ancestral_puebloan` row sits on this stage, so the guardrail in PARK.md section 4 has nothing to check here.

**Material read.** Sandstone tan and slickrock pink, warm in low sun. The animals' rope in ochre. Mining in rust and timber grey. The Fleet in brass and soot. The ancients only in dull petrol enamel with uranium-glass green (#9dff3c) seams (`src/combat/warden_kit.gd:8-9`).

## 2. The hero landmark and the Warden's mounting

**The Hanging Isle.** An upside-down mountain: a pine-topped deck 180 m across at 400 m, tapering 318 m down to a tip 22 m above the net. A thin waterfall pours off its rim and turns to mist long before it reaches the net (visual only). It is the tallest thing in the park and the only thing that floats (PARK.md veto 10). A uranium-glass green beam rises from its top deck (`light: "ancient_beam"`), so the cloud deck weather never hides it.

**Why 400 m and not PARK.md's 260 m.** The landmark must be seen from 85% of open cells (PARK.md:474). With the floor at 60 m and mesas up to 220 m, a 260 m top reached about 0.72 in my rough model; a 400 m top with slimmer, lower occluders reaches about 0.88. Keeping the tip low (82 m) keeps the whole fight inside rope range. KD5's real sight test decides; the fallback is lowering the West Shelf and the Ore Bench further, not raising the floor.

**The mounting, `under_island`.** The Mind's hand cups the tip from beneath and holds the mountain up. The hand is 16 m from wrist to fingertip, the same body as on the Crown's perches. Its palm cups the tip at 82 m and its fingers curl up the rock; three knuckle hardpoints sit at 88 m, 6 m off the axis; the wrist stalk hangs below with the lens cluster at 72 m (`anchor` [0, 80, 520] as drafted). The lens follows the ball, as the mind kit does today (`src/combat/warden_kit.gd:15-16`).

**Shipped anchor (PW1, 2026-10-16): `anchor` [0, 66, 520].** At 80 m the hand hung over a 43 to 45 m floor where no ground point within 120 m held it inside the 45 m rope (`src/movement/tuning.gd:18`) at a pitch the chase camera can lock (`src/movement/chase_camera.gd`, 0.55 rad, 10 degree cone); the PARK-BOSS probe found 0 lockable points. At 66 m it locks from the ground. The hand now hangs about 14 m under the island tip; closing that gap is a dressing job, and this change adds no tether or other visual.

**The arena.** The net bowl under the isle: a 200 m net slung from the 60 m deck down to a 44 m floor. Three knuckle buttes stand in it 60 m from the axis (west, east, north), tops at 80 m, each with a banked spiral up its outside. The south side is open: that is where you arrive. From a knuckle top to the nearest hardpoint is about 37 m, inside the 45 m rope (`src/movement/tuning.gd:18`). From the bowl floor to the lens is 28 m. The engage ring (`reach_m` 120) covers the bowl; the pulse ring stays the kind sheet's 30 m.

**Shipped arena (KD5 fix round, 2026-10-12).** SR15's `beacon_ok` (tools/park_graph.gd BEACON_FLAT_M 2.5) wants every ground node within `reach_m` of the beacon within 2.5 m of the beacon's height, and the drafted bowl with its knuckles rose 27.7 m inside that disc. The shipped arena is therefore flat: the apron north of the carve's last step (z 406) is one 6 m `terrace` bench cut, floor 44 m (the kind sheet's floor), from x -800 to 800 and z 406 to 760; `net_bowl` is a 2 m dish 260 m across centred on the beacon (the net's sag, about 1.7 m inside the disc); the beacon moves 10 m north to [0, 530] so the disc (z 410 to 650) clears the 20 m step at z 406. The three knuckle buttes stand just outside the disc, 142 m from the beacon: west [-142, 530], east [142, 530] and north-west [-100, 630] (north is the bay dock's place). A knuckle top is now about 140 m from its hardpoint, outside the 45 m rope, so the "latch a knuckle" read is the thermals' job: `bowl_thermal` (east) and `bowl_thermal_w` (west, new) lift beside the knuckles, and two keel ribs (`keel_rib_w`, `keel_rib_e`, 50 m long, 12 m tall, unstamped greybox walls lying radially 45 to 95 m from the beacon) are the harpoon anchors on the floor. Andrew's stage board should see this; the kind sheet's section 3.1 arena sentence needs the same change (follow-up for the coordinator).

**The one mechanism: the pendulum tilt.** On each pulse the hand tips the island 10 degrees toward the ball (PARK.md:428). Because the island pivots high, the tip and the hand swing about 21 m away from the ball over 1.2 s, then back over 2.8 s. A camper loses the lens. A ball latched to a knuckle rides the swing and is thrown at its far end. The kind sheet has the numbers.

**Gates and bay.** The Keel Bench, north of the bowl at 80 m. Gates at z 720 facing +z. Moss's bay docks at [0, 650], 70 m behind the gates and inside the gates' 110 m hold (`src/world/bay.gd:21-23`).

**After the break.** The hand opens, goes dark and sinks into the bowl net. The island stays up, held by its own beam. No event starts in the next 20 s (PARK.md:311). You roll up the bowl's north bank onto the Keel Bench and the gates.

## 3. Region sketch

The 1.6 km square, -800 to +800 m on both axes. The fall line runs up the page, from the drop-in at the south to the landmark at the north.

```
        -800 m (west)                                      +800 m (east)
z (m)
  750                    kb kb GT kb                  
  650                    kb kb BY kb                  
  550  .. .. ro ro ro .. is is LM is .. lr lr .. .. ..
  450  .. .. ro C4 C1 ww is is is C2 ew lr lr .. .. ..
  350  .. .. ro ro ro C7 ww .. .. ew C8 .. .. .. .. ..
  250  .. .. .. .. .. ww ww .. .. ew ew .. .. .. .. ..
  150  .. .. .. .. .. ww ww .. .. ew ew .. .. .. .. ..
   50  .. .. .. .. mo C9 ww .. A2 ew C6 .. .. .. .. ..
  -50  .. .. .. .. mo H3 mo fn mi H2 mi mi mi .. .. ..
 -150  .. .. .. .. mo mo mo fn mi mi mi A3 mi .. .. ..
 -250  .. .. .. .. .. ws ws C0 mi mi mi mi mi .. .. ..
 -350  .. .. .. .. .. ws ws fn mi C3 mi mi mi .. .. ..
 -450  .. .. .. .. .. ws ws sd mi mi mi mi mi .. .. ..
 -550  .. .. .. .. .. .. lk lk lk lk .. .. .. .. .. ..
 -650                    lk lk lk lk                  
 -750                    lk lk DI lk                  
```

Each cell is 100 m. North (+z, the landmark side) is up.

| Code | Region |
| --- | --- |
| `lk` | Lookout Mesa |
| `sd` | Saddle |
| `ws` | West Shelf and hoodoos |
| `fn` | Twin Fins |
| `mi` | Tram and Ore Bench (the mine) |
| `mo` | Moorings |
| `ww` | West Wing and cloud wash |
| `ew` | East Wing and cloud wash |
| `ro` | Kite Roost |
| `lr` | Lens Rocks |
| `is` | Hanging Isle, net bowl, knuckles |
| `kb` | Keel Bench |
| `..` | Open net deck at 60 m |

| Mark | What | At [x, z] |
| --- | --- | --- |
| `A1` | enemy_camp `camp_anvil` (was `camp_moorings` at the Moorings; KD5, R7) | [0, 104] |
| `A2` | cracked_cache `cache_east_wing` (was ambush_altar `altar_anvil` on the Anvil; KD5, R7) | [210, 236] |
| `A3` | hauler_bounty `bounty_ore_bench` | [186, -60] (draft [330, -110]) |
| `H1` | home `tram_cutters` (line_cutter) | [101, -389] |
| `H2` | home `chute_cutters` (line_cutter) | [191, -19] |
| `H3` | home `mooring_anchor_crew` (anchor_crew) | [-239, -9] |
| `H4` | home `dropship_anchor_crew` (anchor_crew, dormant) | [-239, 51] |
| `H5` | home `roost_kites` (kite_drone) | [-439, 471] |
| `C0` | thermal `fin_thermal` | [-90, -230] |
| `C1` | thermal `roost_thermal` | [-400, 420] |
| `C2` | thermal `bowl_thermal` (and `bowl_thermal_w` at [-110, 470]) | [110, 470] |
| `C3` | cable `tramway` | [100, -390] |
| `C4` | cable `roost_line` | [-420, 470] |
| `C5` | lift `west_balloon_lift` | [-210, 80] |
| `C6` | lift `east_balloon_lift` | [210, 80] |
| `C7` | launcher `cloud_cannon_west` | [-210, 390] |
| `C8` | launcher `cloud_cannon_east` | [210, 390] |
| `C9` | barge `roost_ferry` | [-280, 60] |
| `BY` | bay dock | [0, 650] |
| `GT` | reward gates | [0, 720] |
| `LM` | landmark `hanging_isle` and the Warden (beacon [0, 530]) | [0, 520] |
| `DI` | drop-in | [0, -720] |

Read it as three fans between four waymarks. The drop-in fan runs from the Lookout to the Saddle. The middle fan runs from the Saddle to the Anvil, with the Moorings and the West Shelf to the west, the Twin Fins in the centre and the mine to the east. The last fan runs from the Anvil to the bowl, with a wing mesa on each side. The Kite Roost and the Lens Rocks sit off the lines on the far flanks: you see them, and you choose them.

## 4. `park_rows` draft

Conventions on this stage. `size` h of a stamped row is its top above the base plain at y = 0, because the bake raises the stamp by h. Rows that hang (nets, the chute, the grind) carry an absolute `y`. The `net_deck` row is one recipe at 60 m under the whole play rect. It sags up to 14 m between mesa feet, so every fall lands on rope (PARK.md veto 10). These are 30 rows; KD5 grows them toward PARK.md 2.2's 40 to 70 with detail rows (posts, pine stands, scrap).

**Anchor cover.** The bar is a max anchor gap of 40 m (PARK.md:464), and walkable ground is not a target (`design-v3/TRAVERSAL.md:14`). Open net and flat mesa tops are walkable. So the animals' posts carry the anchors: the `net_deck` recipe stands a 16 m post (today's post height, `src/world/map_highdraft.gd:46`) on an 80 m lattice, and every mesa top that a line crosses carries a relict pine stand with a trunk within 45 m of any point. The posts are what the nets and balloons hang from, so the anchors explain themselves.

| id | element / landform | society | at, y | size l x h x w, yaw | verb, ride fact | stamp, budget | routes | home | fragment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lookout_mesa` | sky_island / sky_island | none | [0, -660], null | 260 x 220 x 300 | drop, ride_drop | mesa, landform | main, west, east, slab, envelope |  | none_sky_island_relicts |
| `fire_lookout` | anchor_field / mesa_rim | dam_era | [130, -640], null | 8 x 24 x 8 | swing, ride_grapple_line | none, detail | east |  | dam_era_lookout_log |
| `lookout_stair` | flow_line / mesa_rim | dam_era | [-110, -560], null | 240 x 45 x 14, 20 deg | roll, ride_ledge | ramp, landform | west, envelope |  | dam_era_switchback_stones |
| `slickrock_run` | flow_line / slickrock | none | [0, -560], null | 220 x 45 x 90 | pump, ride_chute | ramp, landform | main, slab |  |  |
| `east_ribs` | kicker / slickrock | none | [110, -500], null | 14 x 2.5 x 50, -30 deg | launch, ride_hop | ramp, landform | east |  |  |
| `saddle` | bank / slickrock | none | [0, -400], null | 100 x 175 x 220 | bank, ride_bowl | ridge, landform | main, west, east, slab, envelope |  |  |
| `twin_fins` | sky_island / butte | none | [0, -230], null | 260 x 140 x 120 | drop, ride_drop | mesa, landform | main, slab |  | none_fin_varnish |
| `fin_chute` | half_pipe / butte | none | [0, -230], 128 | 260 x 12 x 40 | pump, ride_chute | none, landform | main |  |  |
| `fin_nose_kicker` | kicker / butte | none | [0, -95], null | 16 x 4 x 30 | launch, ride_hop | ramp, landform | main |  |  |
| `net_deck` | bowl / sky_island | none | [0, 0], 60 | 1500 x 14 x 1100 | bank, ride_bowl | none, park_large | main, west, slab, envelope |  | net_knot_tally |
| `anvil_rock` | sky_island / butte | none | [0, 60], null | 40 x 72 x 40 | launch, ride_hop | butte, landform | main, west, east, slab, envelope |  | none_desert_varnish |
| `west_shelf` | terrace / mesa_rim | none | [-200, -280], null | 300 x 130 x 160 | bank, ride_bowl | terrace, landform | west, envelope |  |  |
| `hoodoo_garden` | anchor_field / hoodoo_field | none | [-250, -160], null | 120 x 40 x 100 | swing, ride_grapple_line | none, landform | west |  | none_hoodoo_ash |
| `mooring_mesa` | sky_island / mesa_rim | fleet | [-240, -10], null | 180 x 130 x 160 | drop, ride_drop | mesa, landform | west, envelope | mooring_anchor_crew | fleet_mooring_tags |
| `mooring_pad` | ground / mesa_rim | fleet | [-240, 50], null | 50 x 2 x 40 | roll, (none) | plateau, landform | (none) | dropship_anchor_crew |  |
| `tram_head` | anchor_field / mesa_rim | mining | [100, -390], null | 20 x 26 x 20 | swing, ride_grapple_line | none, landform | east | tram_cutters | mining_tram_ledger |
| `ore_bench` | terrace / tailings_bench | mining | [290, -150], null | 220 x 130 x 200 | bank, ride_bowl | terrace, landform | east |  | mining_ore_bench_assay |
| `ore_adit` | tunnel / adit | mining | [290, -130], null | 100 x 10 x 12 | drop, ride_drop | none, hole, park_large | east |  | mining_adit_lamp |
| `ore_chute` | grind_line / flume | mining | [190, -20], 100 | 233 x 4 x 3, -59 deg | grind, ride_grapple_line | none, landform | east | chute_cutters | mining_ore_chute |
| `west_wing` | sky_island / mesa_rim | none | [-210, 250], null | 320 x 120 x 120 | drop, ride_drop | mesa, landform | west |  |  |
| `cloud_wash_west` | half_pipe / dry_wash | none | [-210, 250], null | 320 x 10 x 30 | pump, ride_chute | wash, landform | west |  |  |
| `east_wing` | sky_island / mesa_rim | none | [210, 250], null | 320 x 120 x 120 | drop, ride_drop | mesa, landform | east |  |  |
| `cloud_wash_east` | half_pipe / dry_wash | none | [210, 250], null | 320 x 10 x 30 | pump, ride_chute | wash, landform | east |  |  |
| `kite_roost` | sky_island / butte | none | [-440, 470], null | 140 x 170 x 140 | lift, thermal_ride | butte, landform | (none) | roost_kites |  |
| `lens_rocks` | sky_island / butte | ancient | [430, 470], null | 120 x 150 x 120 | drop, ride_drop | butte, landform | (none) |  | ancient_lens_rock_hum |
| `net_bowl` | bowl / sky_island | none | [0, 520], 44 | 200 x 16 x 200 | bank, ride_bowl | none, park_large | main, west, east, slab, envelope |  | net_bowl_mends |
| `knuckle_w` | bank / butte | none | [-60, 520], null | 36 x 80 x 36 | bank, ride_bowl | butte, landform | west |  |  |
| `knuckle_e` | bank / butte | none | [60, 520], null | 36 x 80 x 36 | bank, ride_bowl | butte, landform | east |  |  |
| `knuckle_n` | bank / butte | none | [0, 580], null | 36 x 80 x 36 | bank, ride_bowl | butte, landform | (none) |  |  |
| `keel_bench` | ground / mesa_rim | none | [0, 700], null | 120 x 80 x 240 | roll, (none) | plateau, landform | (none) |  |  |

Row notes:

- `lookout_mesa`: the drop-in. Its flat top carries the relict pines and the two dam-era pieces. Three ways off it: the Slickrock Run north, the stair west, the fire lookout swing east.
- `saddle`: the first waymark. A bank 220 m wide between the Lookout and the Fins; every line carves it.
- `twin_fins` and `fin_chute`: two parallel fins of rock with a 40 m half-pipe between them, floor at 128 m. The `fin_nose_kicker` at their north end throws you over 80 m of air onto the net short of the Anvil.
- `anvil_rock`: the second waymark and the ambush altar. A 72 m stub rising 12 m out of the net, with a 0.3 grade ramp on its south side (today's ramp grade, `src/world/map_highdraft.gd:38`), so the floor line climbs it.
- `ore_adit`: the stage's one tunnel. Mouths face along the fall line and the roof lips bevel back 3 m (PARK.md section 4, `design-v3/TRAVERSAL.md:110`).
- `west_wing` and `east_wing`: long low mesas that carry the cloud washes and the cannons into the arena.
- `knuckle_w`, `knuckle_e`, `knuckle_n`: the arena's launch towers; their spirals are `bank` rides.
- `keel_bench`: the gates' ground, level with the bowl's north rim.

**Shipped (KD5 greybox, 2026-10-11): how the greybox file differs from this table.** The shipped file is generated, not hand-edited, and the appendix holds it whole. Its ground is a stepped fall line, not the mesa-and-net silhouette above: park-wide `ground` shelves set each band's floor, 1,120 m `drop` ramps with sheer north edges make the steps (the Lookout steps, the Run steps, the Fin fan steps, the landing step, the Anvil steps and the carve steps), and spire-stamped `anchor_field` rows (the cairns and the hoodoo posts, about 280 of them) stand 24 m or more off every planned line and 14 m or more off every measured ball trace as the harpoon anchors. The named rows of this table keep their ids, routes, ride facts and fragments. KB9 places every row at runtime, so two shapes changed in this unit: a greybox row with no stamp stood as a flat box of its size on the ground under its centre, proud of the steps (a 2 m slab on `east_ribs`, a 10 m block for `ore_adit`), so those marker rows now carry a 1 cm `plateau` stamp, which replaces the box and keeps the ride sensor; and the step lips (`*_step_lip_*`, 1,120 m `kicker` rows on the steps' own sheer edges) became markers the same way, because their wedges met a fast ball face-on (Rivet fell from 19.8 to 7 m/s on `carve_step_lip_7`). `lookout_lip` and `fin_nose_kicker` keep their wedges. The mesa silhouette, the net deck at 60 m and the island read are the dressed pass's job (section 16).

**Fix round (2026-10-12).** Every 1,120 m sheet row (shelves, drops, lips, the stamped bands) now runs the full 1,600 m square at x 0, so the margins outside the play rect are stage ground instead of a 115 to 270 m drop to y 0; PARK.md section 8's density and sight tests read the whole square (worst open node was 404.5 m from a row, sight share 0.751). `isle_apron` is a `terrace` row (one 6 m bench cut, no ride sensor) and the arena rows changed as section 2 says. `tram_head` is the mesa-rim station ledge of the KD5 note: a `ledge` with a 3 m `plateau` stamp, 30 m square at [118, -398], one climb step over the Saddle (the 22 m spire it was had no path from the Saddle, so route `east` broke). Removed: `isle_post_1` to `_4`, `_7`, `_8` (spires inside the flat beacon disc) and `hoodoo_post_283`, `_284` (Sable met them leaving the tramway). Added: `isle_post_9`, `_10` (16 m spires on the carve's last shelf at [-100, 398] and [100, 398]), `hoodoo_post_287` at [235, -72], `keel_rib_w`, `keel_rib_e`; `isle_post_5`, `_6` stand 30 m. The park file has 405 rows.

## 5. Routes, waymarks and activities

**Shipped routes and activities, KD5 continuation, 2026-10-12.** Values below come from the park file.

| Route | From | To | Via |
| --- | --- | --- | --- |
| `main` | drop_in | landmark | lookout_mesa, lookout_lip, slickrock_run, run_turn_wash, saddle, twin_fins, fin_chute, fin_nose_kicker, net_deck, anvil_rock, net_post_run, net_bowl |
| `west` | drop_in | landmark | lookout_mesa, lookout_lip, lookout_stair, saddle, west_shelf, hoodoo_garden, mooring_mesa, mooring_pad_ramp, net_deck, anvil_rock, west_wing, cloud_wash_west, knuckle_w, net_bowl |
| `east` | drop_in | landmark | lookout_mesa, lookout_lip, east_ribs, saddle, tram_head, ore_bench, ore_adit, ore_chute, anvil_rock, east_wing, cloud_wash_east, knuckle_e, net_bowl |
| `slab` | drop_in | landmark | lookout_mesa, lookout_lip, slickrock_run, run_turn_wash, saddle, twin_fins, net_deck, anvil_rock, net_bowl |
| `envelope` | drop_in | landmark | lookout_mesa, lookout_lip, lookout_stair, saddle, west_shelf, mooring_mesa, net_deck, anvil_rock, net_bowl |
| `fan_chute` | saddle | anvil_rock | saddle, twin_fins, fin_chute, fin_nose_kicker, net_deck, anvil_rock |
| `fan_west` | saddle | anvil_rock | saddle, west_shelf, hoodoo_garden, mooring_mesa, mooring_pad_ramp, net_deck, anvil_rock |
| `fan_east` | saddle | anvil_rock | saddle, tram_head, ore_bench, ore_adit, ore_chute, anvil_rock |
| `fan_slab` | saddle | anvil_rock | saddle, twin_fins, net_deck, anvil_rock |
| `fan_envelope` | saddle | anvil_rock | saddle, west_shelf, mooring_mesa, net_deck, anvil_rock |
| `carve_net` | anvil_rock | net_bowl | anvil_rock, net_post_run, net_bowl |
| `wing_west` | anvil_rock | net_bowl | anvil_rock, west_wing, cloud_wash_west, knuckle_w, net_bowl |
| `wing_east` | anvil_rock | net_bowl | anvil_rock, east_wing, cloud_wash_east, knuckle_e, net_bowl |

Waymarks, in order: `drop_in`, `saddle`, `anvil_rock`, `landmark`.

| Activity | Kind | Site | At [x, z] | Pack | Pay |
| --- | --- | --- | --- | --- | --- |
| `camp_anvil` | enemy_camp | anvil_rock | [0, 104] | anchor_crew, anchor_crew, line_cutter | `{"named": "rivet_plating"}` |
| `cache_east_wing` | cracked_cache | east_wing | [210, 236] | default | `{"rarities": ["rare"]}` |
| `bounty_ore_bench` | hauler_bounty | ore_bench | [186, -60] | default | `{"rarities": ["common", "rare"]}` |

Renames under R7: `camp_moorings` became `camp_anvil`; `altar_anvil` became `cache_east_wing`.
The Anvil landform is waymark 2; the camp is its on-line common-part activity. The reward is
a rare cracked cache on the East Wing; the risk is a common-or-rare bounty at the Ore Bench.
The Kite Roost cache was not restored: activity rows have one `at` and no separate door field,
so the graph requires the door and pay point to share a site within 240 m sight distance.
The East Wing departure from the journey remains a coordinator ruling, with old and new
journey sentences in the unit report. The cache moved clear of Kest's east-wing path after
the traversal bot collided with its old position. The graph pocket table is in section 16.

Only the fin collapse closes routes; `west` and `east` remain open. The burner opens the
envelope without closing a route, which R7's event ruling allows. Hidden pocket `saddle_seam`
remains a cracked wall at [230, -420], pay at [236, -426], on the Saddle site.

## 6. `event_rows` draft

**Shipped events, KD5 continuation, 2026-10-12.**

| Event | Kind / family | Site | Trigger | Lead / live (s) | Effect | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `fin_rim_collapse` | collapse / natural | twin_fins | `{"on": "clock_tier", "value": 1}` | 6.0 / 0.0 | `{"depth_m": 8.0, "fill_s": 0.0, "swap": "fin_slab_ramp"}` | `{"closes": ["main", "fan_chute"], "opens": ["slab", "fan_slab"]}` |
| `mooring_burner_blow` | boiler_burst / industrial | mooring_mesa | `{"on": "clock_tier", "value": 2}` | 5.0 / 10.0 | `{"hazard": "burner_flare", "hazard_m": [22, 12], "damage": 6.0, "swap": "envelope_drape"}` | `{"closes": [], "opens": ["envelope", "fan_envelope"]}` |
| `mooring_dropship` | fleet_landing / fleet | mooring_pad | `{"on": "clock_tier", "value": 2}` | 10.0 / 0.0 | `{"vessel": "dropship", "home": "dropship_anchor_crew", "footprint_m": [36, 16]}` | `{"closes": [], "opens": []}` |
| `lens_rocks_wake` | machine_eruption / ancient | lens_rocks | `{"on": "clock_tier", "value": 2}` | 9.0 / 0.0 | `{"miniboss": "mind_hand", "swap": "lens_rock_crater"}` | `{"closes": [], "opens": []}` |
| `isle_shed` | impact / natural | west_wing | `{"on": "warden_phase", "value": "chunk_1"}` | 6.0 / 0.0 | `{"strike_m": 20.0, "damage": 8.0, "swap": "crater_event"}` | `{"closes": [], "opens": []}` |

No event director rule is changed here. Tier-2 events may overlap the approach or fight; the calm period is shared director behavior and remains a coordinator follow-up. The five events keep their authored music cues and on-bar telegraphs.

## 7. `home_rows` draft

**Shipped homes, KD5 continuation, 2026-10-12.**

| Home | Enemy | Site / landform | Reinforcement | Break | Dormant |
| --- | --- | --- | --- | --- | --- |
| `tram_cutters` | line_cutter | tram_head / mesa_rim | `{"from_tier": 1, "every_s": 30.0, "max_alive": 3, "pack": "draft_cut"}` | `{"by": "ram", "hp": 120.0, "scrap": 30}` | False |
| `chute_cutters` | line_cutter | ore_chute / flume | `{"from_tier": 2, "every_s": 40.0, "max_alive": 2, "pack": "draft_cut"}` | `{"by": "ram", "hp": 100.0, "scrap": 25}` | False |
| `mooring_anchor_crew` | anchor_crew | mooring_mesa / mesa_rim | `{"from_tier": 0, "every_s": 35.0, "max_alive": 3, "pack": "draft_anchor"}` | `{"by": "slam", "hp": 140.0, "scrap": 35}` | False |
| `dropship_anchor_crew` | anchor_crew | mooring_pad / mesa_rim | `{"from_tier": 2, "every_s": 30.0, "max_alive": 3, "pack": "draft_anchor"}` | `{"by": "smash", "hp": 160.0, "scrap": 40}` | True |
| `roost_kites` | kite_drone | kite_roost / butte | `{"from_tier": 1, "every_s": 25.0, "max_alive": 4, "pack": "draft_kites"}` | `{"by": "damage", "hp": 160.0, "scrap": 30}` | False |

Line cutters occupy the tram and ore chute; anchor crews occupy the Moorings and dropship pad; kite drones occupy the Roost. The graph checks the home sites against every pocket clear ring.

## 8. `contraption_rows` draft

**Shipped contraptions, KD5 continuation, 2026-10-12.**

| Contraption | Kind | Site | Recipe | Spec |
| --- | --- | --- | --- | --- |
| `fin_thermal` | thermal | twin_fins | primitive | `{"at": [-90, -230], "radius": 6.0, "height": 240.0}` |
| `roost_thermal` | thermal | kite_roost | primitive | `{"at": [-400, 420], "radius": 6.0, "height": 220.0}` |
| `bowl_thermal` | thermal | knuckle_e | primitive | `{"at": [110, 470], "radius": 6.0, "height": 160.0}` |
| `bowl_thermal_w` | thermal | knuckle_w | primitive | `{"at": [-110, 470], "radius": 6.0, "height": 160.0}` |
| `tramway` | cable | tram_head | primitive | `{"from": [95, 192.6, -372], "to": [262, 165.2, -216], "radius": 4.5, "floor": 18.0}` |
| `ore_line` | cable | ore_chute | primitive | `{"from": [236, 119.6, -36], "to": [40, 113.2, 40], "radius": 4.5, "floor": 18.0}` |
| `roost_line` | cable | kite_roost | primitive | `{"from": [-420, 173.0, 470], "to": [-75, 62.7, 515], "radius": 4.5, "floor": 18.0}` |
| `west_tether` | cable | anvil_rock | primitive | `{"from": [-60, 108.0, 84], "to": [-208, 89.1, 160], "radius": 4.5, "floor": 18.0}` |
| `east_tether` | cable | anvil_rock | primitive | `{"from": [60, 108.0, 84], "to": [208, 89.1, 160], "radius": 4.5, "floor": 18.0}` |
| `keel_line` | cable | net_post_run | primitive | `{"from": [60, 74.7, 316], "to": [-60, 69.0, 392], "radius": 4.5, "floor": 18.0}` |
| `west_balloon_lift` | lift | west_wing | lift_platform | `{"at": [-400, 180], "radius": 5.0, "rise": 60.0, "charge": 4.0, "offset": 0.0}` |
| `east_balloon_lift` | lift | east_wing | lift_platform | `{"at": [400, 180], "radius": 5.0, "rise": 60.0, "charge": 4.0, "offset": 2.0}` |
| `cloud_cannon_west` | launcher | cloud_wash_west | cannon | `{"style": "cannon", "at": [-210, 392], "radius": 4.0, "target": [-75, 82, 505], "floor": 30.0, "min_flight": 3.0, "charge": 2.5}` |
| `cloud_cannon_east` | launcher | cloud_wash_east | cannon | `{"style": "cannon", "at": [210, 392], "radius": 4.0, "target": [75, 82, 505], "floor": 30.0, "min_flight": 3.0, "charge": 2.5}` |
| `roost_ferry` | barge | mooring_mesa | barge | `{"a": [-280, 108.4, 60], "b": [-430, 172.5, 420], "size": [14, 2, 14], "travel": 18.0, "dwell": 3.0, "offset": 0.0}` |
| `saddle_seam` | cracked_wall | saddle | primitive | `{"at": [230, -420], "size": [10, 6, 1.4], "turn": 1.2, "cache": {"at": [236, -426]}}` |

Cables use their explicit world coordinates. Balloon lifts and cloud cannons remain optional side rides; the measured lines take the Anvil tethers or keel cable. Thermals use the shipped primitive, with no thermal recipe id invented.

## 9. Weather and the fixed time of day

**Shipped weather, KD5 continuation, 2026-10-12.** Time of day is `golden`.

| Weather | Kind | Trigger | Spec |
| --- | --- | --- | --- |
| `golden_air` | clear | `{"on": "always"}` | `{"lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0025, "color": "#f0c08e"}, "sky": "clear", "sound": "high_wind_bed", "music_layer": "", "event_odds": {}, "handling": "none"}` |
| `cloud_rise` | cloud_deck | `{"on": "clock_tier", "value": 2}` | `{"lead_s": 8.0, "live_s": 60.0, "gap_s": 60.0, "fog": {"density": 0.006, "color": "#ece7da"}, "sky": "clear", "sound": "cloud_hush_bed", "music_layer": "layer_cloud_pad", "event_odds": {"mooring_dropship": 2.0}, "handling": "none"}` |

The cloud deck rises below the net; handling is unchanged. Weather and music are the authored rows, not listening acceptance.

## 10. Traversal lines

**The flow line.** A skater drops off the Lookout's north lip and carves the Slickrock Run as an S. They bank across the Saddle and pump the Fin Chute, wall to wall, for 260 m. Then they hit the fin nose kicker and take 80 m of air over the net. They roll up the Anvil's ramp through the altar ring, then cross the net to the bowl, one long carve. That is the `floor` line: 1,269 m with no harpoon and no contraption. The pilot lines take a side fan in at least one of the three segments, which gives them length, air and a second verb.

| line | fans taken (segment 1, 2, 3) | length m | straight m | ratio | segment lengths m | time at 20 to 26 m/s | segments at 20 m/s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| sable | W, C, E | 1531 | 1120 | 1.37 | 464, 495, 572 | 59 to 77 s | 23 s, 25 s, 29 s |
| rivet | E, E, C | 1630 | 1120 | 1.45 | 449, 811, 370 | 63 to 82 s | 22 s, 41 s, 18 s |
| kest | C, T, E | 1624 | 1120 | 1.45 | 405, 648, 572 | 62 to 81 s | 20 s, 32 s, 29 s |
| tarn | W, W, W | 1784 | 1120 | 1.59 | 464, 747, 572 | 69 to 89 s | 23 s, 37 s, 29 s |
| tally | E, C, W | 1516 | 1120 | 1.35 | 449, 495, 572 | 58 to 76 s | 22 s, 25 s, 29 s |
| cannon | C, E, W | 1787 | 1120 | 1.6 | 405, 811, 572 | 69 to 89 s | 20 s, 41 s, 29 s |
| floor | C, C, C | 1269 | 1120 | 1.13 | 405, 495, 370 | 49 to 63 s | 20 s, 25 s, 18 s |

Every pilot line sits inside PARK.md's ratio band of 1.3 to 2.0 (PARK.md:466). The floor line is held to its own bar: reach the Warden within twice the pilot median (PARK.md:467). Segments run 18 to 41 s at 20 m/s, inside the 12 to 45 s band. At 26 m/s Tally's and Sable's lines finish just under 60 s; if the bot averages that fast, the fix is a longer carve in the last fan, not a slower park.

**The tricks each line offers.**

- **Sable (vault and slingshot): west, centre, east.** Off the Lookout's west rim down the dam-era stair, vaulting the switchback lips. Carve the Saddle, pump the Fin Chute, and slingshot off a pylon at the fin nose: the longest flight on the stage. From the altar, east to the balloon lift, the cloud wash and the cannon onto the east knuckle.
- **Rivet (sprint): east, east, centre.** Swing the fire lookout off the east rim and sprint the ribs into the Saddle. Grapple the tram head and ride the tramway down to the Ore Bench. Drop through the adit, sprint onto the ore chute and grind 60 m down to the Anvil. Then a flat-out sprint across the net into the bowl: the stage's peak-speed line.
- **Kest (glide and rocket jump): centre, thermal, east.** Carve the Run, then rocket-jump from the Saddle's west lip into the fin thermal. Climb to about 250 m, then glide west over the shelf and the Moorings and down to the altar. Finish east; or take the bowl thermal at the end for a first slam from above the hand.
- **Tarn (claw pull): west, west, west.** Claw down the stair's cairns and across the West Shelf. Pull from hoodoo to hoodoo through the garden and drop off the Moorings to the net. Then the west balloon lift, the cloud wash and the cannon.
- **Tally (surge): east, centre, west.** The lookout swing and the ribs, then a surge down the Fin Chute that holds chute speed into the kicker. Finish west.
- **The Cannon (recoil): centre, east, west.** Recoil-hop out of the Run's lips, grapple the tram head and ride the tramway. Recoil off the bench edge onto the chute, then cross west to the lift, the wash and the cannon. A cannon riding a cannon.

**Against the bands** (PARK.md:452-468), as designed and before any bot run:

| Band | How this park meets it |
| --- | --- |
| Time to engage, 60 to 120 s | 58 to 89 s at 20 to 26 m/s; see the note on fast bots above |
| Segments, 12 to 45 s | 18 to 41 s at 20 m/s; the longest are the east middle fan (811 m) |
| Flow share at least 0.70 | the park falls 176 m from drop-in to bowl floor; no line climbs except the Anvil ramp (12 m) and the knuckle spirals after engage |
| Airborne 0.25 to 0.60 | the fin nose flight (about 2.5 s), the cannon flights (at least 3 s each, `min_flight`), the tramway and roost line (rail time has no ground contact), the thermal climbs and glides, the Lookout's lips. Estimate 0.30 to 0.45 (start); KD5 measures |
| Peak speed at least 26.6 m/s, 3 s at that tier | the Slickrock Run drops 45 m, the fin nose flight drops 80 m, the ore chute drops 60 m |
| Quiet stretch at most 20 s | every line meets a ride fact at most about 300 m apart (12 to 15 s): lips, chutes, banks, kickers, cables, cannons |
| Max anchor gap 40 m | the post lattice and pine stands (section 4); mesa faces and the fins' walls |
| Distinct verbs at least 3 | 4 to 6 per line (roll, pump, bank, launch, swing, grind, drop, lift, glide) |
| Distinct lines at least 3 | Sable, Rivet and Kest share no fan |

**`assets/park/park_islands/lines.json` as shipped (KD5 greybox, 2026-10-11).** Waypoints are [x, z] or a waymark id. The fans are the draft's; each fan is now a smooth arc of waypoints about 40 m apart (sharp zigzags cost the bot up to 15 m/s per turn), every line passes its cable's `from`, the second waymark is `anvil_rock`, and the floor line takes the west fan in segment 2 (centre, west, centre): all-centre measured a length ratio of 1.2, under the band.

**Sable's line changed (KD5 continuation, after KB9).** On the head with runtime rows Sable's west, centre, east line reached the Warden in 54 s median with a 11.4 s middle segment, under both bands (60 s, 12 s). Sable now rides west, east, east: its own west fan (the stair diagonal, then a right-hand curve that meets the Saddle heading east, north of the Saddle's edge), the tramway, then straight from the cable's foot to the ore chute's foot (`[109, -39]`) with no leg on the steps between, because a 35 to 45 m/s ball that misses a leg there drops a sheer step edge and cannot climb back to it (one seed rolled under the -100 edge for 200 s); and the east finish on a wider curve. The bot reaches its legs in order within 12 m (`tools/bot_driver.gd` TRAVERSE_REACHED), so every leg on the stepped ground sits where a fast ball passes or north of the edge it guards. The east fan's own legs below the tramway (Rivet, the Cannon) are one per step band for the same reason. The trick text above still describes the draft's fans; Sable's slingshot reads on the tramway's foot and the east tether now.

**Sable's line re-cut again (KD5 fix round, 2026-10-12).** The verifier measured a dead stop on 6 of 8 seeds at the Saddle: Sable met the waymark heading north-north-east at 45 m/s, overshot it by 40 m and climbed back into the -390 step face. The leg before the Saddle is now `[-45, -430]`, so the ball meets the waymark heading north-east, and the leg after it (`[60, -385]`) is gone, so it leaves straight for the tramway's foot. With no stop Sable reached the Warden in 59 s median, under the 60 s band, so from the tramway's foot it now rides four points of the Ore Bench arc Rivet and the Cannon ride (`[284, -170]`, `[273, -129]`, `[228, -92]`, `[150, -60]`) before the chute foot. Sable's middle segment therefore shares the bench with Rivet and the Cannon; its first and last segments are its own.

```json
{
 "map": "park_islands",
 "stage": 5,
 "pilots": {
  "sable": {"waypoints": ["drop_in", [-46, -712], [-85, -701], [-116, -689], [-140, -675], [-156, -659], [-165, -641], [-166, -622], [-160, -600], [-95, -490], [-45, -430], "saddle", [95, -372], [262, -216], [284, -170], [273, -129], [228, -92], [150, -60], [109, -39], [40, -5], [8, 22], "anvil_rock", [25, 66], [60, 84], [208, 160], [231, 186], [248, 211], [257, 236], [260, 261], [257, 285], [247, 309], [230, 332], [207, 355], [177, 378], [140, 400], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "rivet": {"waypoints": ["drop_in", [35, -700], [66, -680], [92, -660], [114, -641], [132, -621], [145, -601], [153, -582], [158, -562], [157, -543], [152, -524], [143, -505], [129, -486], [111, -467], [89, -448], [62, -429], [30, -410], "saddle", [60, -385], [95, -372], [262, -216], [277, -193], [284, -170], [283, -149], [273, -129], [255, -110], [228, -92], [193, -76], [150, -60], [109, -39], [75, -18], [49, 6], [30, 30], "anvil_rock", [30, 70], [55, 95], [73, 122], [86, 151], [93, 181], [93, 212], [88, 245], [77, 280], [60, 316], [-60, 392], [0, 420], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "kest": {"waypoints": ["drop_in", [30, -702], [52, -684], [67, -666], [74, -648], [74, -630], [67, -611], [52, -593], [30, -574], [0, -555], [-33, -534], [-58, -514], [-73, -494], [-80, -475], [-78, -457], [-68, -439], [-48, -422], [-20, -405], "saddle", [-60, -360], [-90, -300], [-90, -230], [-109, -204], [-122, -178], [-130, -152], [-132, -126], [-128, -100], [-118, -74], [-102, -48], [-80, -22], [-53, 4], [-20, 30], "anvil_rock", [25, 66], [60, 84], [208, 160], [223, 188], [231, 216], [232, 245], [227, 275], [215, 305], [197, 336], [172, 368], [140, 400], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "tarn": {"waypoints": ["drop_in", [-46, -712], [-85, -701], [-116, -689], [-140, -675], [-156, -659], [-165, -641], [-166, -622], [-160, -600], [-30, -470], "saddle", [-49, -377], [-93, -363], [-133, -349], [-168, -334], [-198, -318], [-224, -302], [-245, -285], [-261, -268], [-273, -249], [-280, -231], [-282, -212], [-279, -192], [-272, -171], [-260, -150], [-235, -108], [-208, -71], [-181, -39], [-152, -12], [-123, 9], [-93, 24], [-62, 35], [-30, 40], "anvil_rock", [-60, 84], [-208, 160], [-223, 188], [-231, 216], [-232, 245], [-227, 275], [-215, 305], [-197, 336], [-172, 368], [-140, 400], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "tally": {"waypoints": ["drop_in", [35, -700], [66, -680], [92, -660], [114, -641], [132, -621], [145, -601], [153, -582], [158, -562], [157, -543], [152, -524], [143, -505], [129, -486], [111, -467], [89, -448], [62, -429], [30, -410], "saddle", [0, -350], [0, -310], [0, -270], [0, -220], [0, -170], [0, -130], [4, -70], "anvil_rock", [-60, 84], [-208, 160], [-223, 188], [-231, 216], [-232, 245], [-227, 275], [-215, 305], [-197, 336], [-172, 368], [-140, 400], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "cannon": {"waypoints": ["drop_in", [30, -702], [52, -684], [67, -666], [74, -648], [74, -630], [67, -611], [52, -593], [30, -574], [0, -555], [-33, -534], [-58, -514], [-73, -494], [-80, -475], [-78, -457], [-68, -439], [-48, -422], [-20, -405], "saddle", [60, -385], [95, -372], [262, -216], [277, -193], [284, -170], [283, -149], [273, -129], [255, -110], [228, -92], [193, -76], [150, -60], [109, -39], [75, -18], [49, 6], [30, 30], "anvil_rock", [-60, 84], [-208, 160], [-223, 188], [-231, 216], [-232, 245], [-227, 275], [-215, 305], [-197, 336], [-172, 368], [-140, 400], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}}
 },
 "floor": {"waypoints": ["drop_in", [30, -702], [52, -684], [67, -666], [74, -648], [74, -630], [67, -611], [52, -593], [30, -574], [0, -555], [-33, -534], [-58, -514], [-73, -494], [-80, -475], [-78, -457], [-68, -439], [-48, -422], [-20, -405], "saddle", [-49, -377], [-93, -363], [-133, -349], [-168, -334], [-198, -318], [-224, -302], [-245, -285], [-261, -268], [-273, -249], [-280, -231], [-282, -212], [-279, -192], [-272, -171], [-260, -150], [-235, -108], [-208, -71], [-181, -39], [-152, -12], [-123, 9], [-93, 24], [-62, 35], [-30, 40], "anvil_rock", [30, 70], [55, 95], [73, 122], [86, 151], [93, 181], [93, 212], [88, 245], [77, 280], [60, 316], [-60, 392], [0, 420], "landmark"]}
}
```

## 11. The music arc

The stage keeps today's music: theme 2 with the `highdraft` ACE set (`src/core/alpha_defs.gd:101`; `src/presentation/music_rows.gd:12`). The arc follows the gem rules: keep the core, escalate on game-state thresholds, add layers and never swap them, and land the payoff on the gameplay moment (G11, `src/presentation/MUSIC-GEMS.md`). The Mind never enters the band (`SOUND-STORY.md:280`); its quote is a cue on the game frame (`SOUND-STORY.md:72`).

| Where or what | What you hear | Rule |
| --- | --- | --- |
| Drop-in on the Lookout | the theme's intro bars over the high wind bed | G1 |
| Off the Lookout's lip | the launch is the build, the landing on the Saddle is the first drop | G9 |
| The Fin Chute | the hats layer joins while you pump | G10, add a layer |
| The fin nose flight | the longest build on the stage: the A7b9 holds through the air, the net landing resolves it | G2, G9 |
| The Moorings, while a crew is live | the Fleet's anvil and brass, one layer per difficulty tick | `SOUND-STORY.md:74` |
| The cloud rise | `layer_cloud_pad` while it holds | weather `music_layer` |
| The landmark approach | the landmark hum under the band (`landmark_hum`, `src/core/event_kinds.gd:847`) | |
| Engage | the Warden pivot | G3 |
| Engage | the Mind's quote, once: your class motif inverted, last note flat, on sine, on the frame | `SOUND-STORY.md:61`; kind sheet section 6 |
| Each charge | only the quote's wrong last note, held on sine for the 2 s charge, landing on the pulse as the island tips | kind sheet section 6 |
| Half broken; three quarters | the key lift; the sinister break | G7 |
| The break | the unseal drop, then the rice-cooker clear | G2, G9 |

Event cues (proposed ids for KE8's `CUES` table, PARK.md 2.4): `riser_natural` into `drop_collapse` or `drop_impact`; `riser_industrial` into `drop_boiler` (the steam whistle rising into a percussion hit, PARK.md:310); `riser_fleet` into `drop_fleet_anvil`; `riser_mind_quote` into `drop_mind_wrong`. Each land cue hits the downbeat the event lands on.

## 12. Codex fragments from the society layer

Draft copy, one line each, in the voice of the lore lines (`SOUND-STORY.md:212-219`). Ids match the `fragment` fields.

| Id | Found at | Text (draft) |
| --- | --- | --- |
| `none_sky_island_relicts` | `lookout_mesa` | The pines up here are relicts, stranded when the valleys dried. They are not the only thing up here that got stranded. |
| `dam_era_lookout_log` | `fire_lookout` | Lookout log: smoke at the fins, 14:10. Smoke at the fins, 14:12. It is not smoke. It is going the wrong way. |
| `dam_era_switchback_stones` | `lookout_stair` | Every stair stone is stamped with a crew number. Crew 7 stamped theirs upside down, all the way down. |
| `none_fin_varnish` | `twin_fins` | Desert varnish takes centuries per shade. One stripe on the west fin is fresh. |
| `net_knot_tally` | `net_deck` | Knot count, west gap: 40,112. Re-tied after the storm: 40,112. Someone is counting with us. |
| `none_desert_varnish` | `anvil_rock` | The Anvil rings when the wind is right. The wind is never right at noon. |
| `none_hoodoo_ash` | `hoodoo_garden` | A hoodoo's cap is welded ash; the soft stone under it goes first. Balance is borrowed time. |
| `fleet_mooring_tags` | `mooring_mesa` | Mooring tag: INVENTORY. DO NOT FLOAT. |
| `mining_tram_ledger` | `tram_head` | Tram ledger: buckets up, 212. Buckets down, 212. Buckets that came down heavier than they went up: 3. |
| `mining_ore_bench_assay` | `ore_bench` | Assay: copper, good. Silver, fair. One sample green and warm; it would not go in the crucible. |
| `mining_adit_lamp` | `ore_adit` | Carbide lamp found burning. The carbide ran out years ago. |
| `mining_ore_chute` | `ore_chute` | The chute boards are worn smooth on the inside. Also, oddly, on the outside. |
| `ancient_lens_rock_hum` | `lens_rocks` | The rocks hum one step below whatever you are whistling. |
| `net_bowl_mends` | `net_bowl` | Mend log: the bowl net under the isle never needs mending. Nobody mends it. |
| `ancient_keel_grip` | the landmark | The grip marks on the isle's tip are older than the rock they grip. |
| `net_weaver_post_tags` | `net_posts_1` | Post tag, west gap: TIE HERE. Older tag under it: TIE HERE TOO. |
| `net_weaver_cairn_count` | `lookout_cairn_1` | Cairn on the Lookout: one stone per crossing. The top stone is warm. |
| `net_weaver_post_run` | `net_post_run` | Every post on the run leans downwind by the same amount. The weavers call this surveying. |
| `fleet_cage_manifest` | `mooring_pad` | Mooring manifest: one pack rat, filed under INVENTORY. Inventory disputes the filing. |
| `dam_era_spill_lips` | `lookout_spill_lip_w` | Survey note: two spill lips cut at the lookout's shoulders, for runoff. The runoff uses the stairs. |
| `dam_era_watch_net` | `lookout_watch_net` | Standing order: log anything that falls off the mesa. Net added in '31. The log got shorter. |
| `fleet_kite_lip` | `shelf_kite_lip` | Fleet notice: this lip launches kites, not crew. Crew launched to date: 9. Notice amended. |
| `net_weaver_shelf_hammock` | `shelf_hammock` | One hammock, slung where the hoodoos drop things. They have dropped a pilot. Logged as a thing. |
| `fleet_cage_approach` | `cage_approach_lip_s` | The bookkeeper's cage faces the pad so she can audit landings. Four complaints filed about the landings. |
| `fleet_catch_net` | `cage_catch_net` | Under-mooring net, rated for cargo. Pilots count as cargo under Fleet circular 12. |
| `fleet_ledger_lip` | `ledger_lip` | Lip entered in the ledger: one launch, outgoing. Incoming not yet reconciled. |
| `mining_saddle_spoil` | `saddle_spoil_lip` | Spoil bank, east saddle. Graded smooth, then graded into a ramp by somebody who was not the grader. |
| `net_weaver_spoil_net` | `tram_spoil_net` | The weavers re-strung the tram's old spoil net and kept the ore it caught. They call it rent. |
| `mining_assay_lip` | `assay_lip` | Assay office sign: SAMPLES BY HAND ONLY. Under it, a lip. Samples arrive faster now. |
| `net_weaver_wing_hammocks` | `wing_hammock_e` | Wing hammocks, east and west, at the cloud line. What misses the wash lands in the weavers' record. |
| `fleet_roost_launch` | `roost_launch_lip` | Roost launch lip: point at the isle, release on the gust. Gust schedule posted. The gust has not read it. |
| `fleet_drying_net` | `roost_drying_net` | Kite sails dry here. One has been drying since the Fleet arrived. Do not ask whose. |
| `ancient_lens_lip` | `lens_lip` | The lip points at the lens rocks. Nobody cut it. The grain runs the wrong way for weather. |
| `net_weaver_keel_nets` | `keel_net_w` | Two nets flank the keel bench, knotted to the bowl's count. The count is still 40,112. |
| `net_weaver_field_lips` | `post_field_lip_1` | Post fields, four corners, a lip in each. Weavers ride them to inspect the knots. Inspection is the excuse. |

**Authored pass, 17 October 2026** (Andrew's "Now, light", "Rescue on the isles" and "Either path"). The net-weavers are a society row now (`net_weaver`): the net carve, the net bowl, the post run, the twelve post fields and the five cairns. The Fleet's mooring crew keeps the Moorings, the west shelf and the kite roost (its kite drones are Fleet stock). The weavers also cut the net carve's steps and set the three knuckle banks round the net bowl, and the dam-era lookout crew built the lookout steps below the fire lookout. Natural landforms stay `none`. Society share over hand-built rows goes from 11% to 37%. The file's optional `rescue_rows` stand `tally_cage` on `mooring_mesa` at [-290, 30], facing the pad, 70 m from it and about 100 m off Tarn's line and the floor line. The row names its pilot as data (`"pilot": "tally"`, quest `isles`). Freeing her earns `isles_rescued`, and Tally's class row opens on that or on three ledger leaves, whichever comes first (`class_def.gd` unlock `or`).

**Islands authored pass, 17 October 2026** (follow-up to the crown pass; the w16 intent check put the Highdraft at 152 hand-built rows against the 187 that 70% of the Spillway asks). Thirty-eight GLB rows (`mesa_lip_kicker` seat-fit lips and `net_deck` nets), all `routes: []`, at least 39 m off every pilot line and the floor line, and placeholder-free, so the placeholder total holds at 1442. Each lip throws into something: a net, a thermal, the cage, or the next fan.

- *The rescue approach.* `cage_approach_lip_s` at [-325, -130] throws north up the Moorings toward Tally's cage; `cage_approach_lip_w` at [-400, -20] throws east onto the mesa from the post field; `cage_catch_net` (y 115, [-400, 100]) catches a short throw under the moorings; `ledger_lip` and `manifest_lip` carry a freed pilot back to the west wing.
- *The Lookout.* The dam-era crew's `lookout_spill_lip_w` and `_e` on the mesa's shoulders, `lookout_pine_lip` off the pines, and `lookout_watch_net` (y 249) east of the fire lookout.
- *The shelves and the saddle.* `saddle_gust_lip_w`, the mine's `saddle_spoil_lip`, the Fleet's `shelf_kite_lip` into the west post field, the weavers' `shelf_hammock` (y 199) and `saddle_hammock_e` (y 224), and `hoodoo_cap_lip` past the hoodoo garden.
- *The mine.* `tram_head_lip`, `assay_lip`, `adit_spill_lip`, `chute_trestle_lip`, and the weavers' `tram_spoil_net` (y 194).
- *The wings.* `wing_gust_lip_w` and `_e` toss off the wing mesas into `wing_hammock_w` (y 89) and `wing_hammock_e` (y 85) at the cloud line.
- *The far flanks.* The Fleet's `roost_launch_lip` on top of the kite roost, aimed at the isle, with `roost_foot_lip` and `roost_drying_net` at its foot; the lens rocks' `lens_lip`, `lens_foot_lip` and the weavers' `lens_hum_net`; `keel_net_w` and `_e` flanking the keel bench; one lip in each corner post field (`post_field_lip_1` to `_4`) and `east_post_lip` and `west_post_lip` on the middle fields.

Every new row has a society (net-weavers 19, Fleet 9, mining 5, dam-era 3, ancient 2). Islands hand-built rows go from 97 to 135 and its society share from 37% to 55%; the Highdraft totals 204 against the 187 bar. The crown takes fourteen flank rows in the same PR so it stays over half the raised park median (stage 6 page section 17).

**One skill per park: grapple** (Andrew's Q4 answer, 22:12Z 17 October: "the islands test grapple"). The landforms stay; the lines and enemies change to read as grapple. The skill line (`assets/park/park_islands/skill_line.json`, Rivet) rides six cables end to end, each one carrying on the last one's heading, from the Lookout to the keel: `lookout_line` (new, [200, -600] to [95, -392]) drops off the Lookout's east shoulder to the tram station, then `tramway`, `bench_line` (new, [310, -180] to [250, -40]) over the assay terrace, `chute_line` (new, [260, -20] to [216, 158]) past the adit to the east wing, `wing_line` (new, [180, 200] to [66, 306]) across the cloud wash, and `keel_line` under the isle. The four new cables have a 6 m hook radius and start at least 25 m off every other pilot's line and the floor line (`tests/park_skill_lines_test.gd`). A first draft that started them on Rivet's and Sable's lines hooked those pilots off their own lines, and they stalled 60 to 109 times. The new `lookout_cutters` home (line cutters, spawning anywhere in the `lookout_mesa` footprint) joins the tram and chute cutters along the relay. A line cutter cuts a hooked harpoon line only (`src/combat/line_cutter.gd`), not a cable ride, so they press the harpoon gaps between the cables, not the cables themselves. The ballast heavies on the Moorings stay as the islands' ring-out threat.

Ridden with `tools/traversal_line.gd --table=park --stage=5 --pilot=rivet --lines=res://assets/park/park_islands/skill_line.json` on seeds 1 to 4 (with the ride pieces of PR #95): all four engage the Warden in 79 to 86 s with 0 or 1 dead stops, 6 distinct ride facts and `ride_grapple_line` firing; the line steers between the Lookout's hoodoo posts 34 to 36. All six pilots' own lines still engage on seeds 1 and 2. The 18 step lips stay greybox for now: on `mesa_shelf_edge` Sable's own line stalled 108 to 133 times at `run_step_lip_1`, and the check already counts the step edges as ground. The evidence limit: the bot bites only in fights (`tools/bot_driver.gd`), so no run here shows a harpoon swing between cables.

**Signal caches** (RADIO.md on PR #66; rows for PR #68's `tools/radio_cache_spots.gd` SPOTS):

| Take | Spot here | Row | The reach |
| --- | --- | --- | --- |
| `take-hanging-isle-liquid` | under the Hanging Isle's tip, 24 m off its axis (clear of the hand's 16 m reach), 28 m over the net bowl | `{"stage": 5, "x": 24.0, "z": 520.0, "at": 70.0}` | glide in off a bowl thermal, or swing on the tip's harpoon anchor |
| `take-islands-kite-chime` | among the kite anchors on the kite roost, the far west island | `{"stage": 5, "x": -455.0, "z": 490.0, "drop": 250.0}` | ride `roost_thermal` up 50 m and land on the roost |
| `take-highdraft-first-light` (legend) | above the highest kite tether, 12 m over `roost_line`'s top anchor, above the cloud deck | `{"stage": 5, "x": -420.0, "z": 470.0, "at": 185.0}` | top out the roost thermal, then glide back onto a point 31 m above the roost with no surface under it |

Today's 3-1 lore lines (`src/core/lore_rows.gd:232-288`, the post docket at `:274` and the beacon watch at `:278`) stay; they still fit a park of posts and a lens.

## 13. What stays from today's stage

| Kept | Where it lives |
| --- | --- |
| Packs `draft_cut`, `draft_anchor`, `draft_kites` | `src/core/alpha_defs.gd:106-110` |
| Warden plating 170, health 1,250, posture curve 2.0 x 1.10, ram does not shatter | `alpha_defs.gd:104-105`, pressure row `alpha_defs.gd:64` |
| Beacon seconds 25; scrap density 1.0; kill scrap 5 | `alpha_defs.gd:103` |
| Music theme 2, ACE `highdraft` | `alpha_defs.gd:101`; `music_rows.gd:12` |
| The world 3 Warden band: 0.7 x 35 to 1.6 x 80 s, so 24.5 to 128 s | `tests/alpha_posture_bands_w23_test.gd:26-27` |
| Line cutter, anchor crew, kite drone, Mind's hand, unchanged | `src/combat/line_cutter.gd:3-16`, `anchor_crew.gd:3-16`, `kite_drone.gd:5-18`, `mind_hand.gd:7-28` |

What changes: the map id (`highdraft` to `park_islands`), the heading (today -z, `src/world/map_highdraft.gd:68`; the park runs +z), the variant (`choir` to `""`), the time of day, and `beacon_radius` 30 becomes the landmark's `reach_m` 120.

**Tests to re-pin, each with a dated header.**

| Test | What it pins today | After |
| --- | --- | --- |
| `tests/highdraft_zone_test.gd` | slots, the 10 m net deck, the bridge route (`:10`) | replaced by `tests/park_park_islands_test.gd` (KD5) |
| `tests/highdraft_lift_test.gd` | posts on island rims, three thermals (`:11`) | the post lattice and the contraption rows |
| `tests/bot_highdraft_lift_test.gd` | a bot rides the Lift | the bot rides `fin_thermal` |
| `tests/highdraft_warden_bot_test.gd` | the skipper breaks the stage 5 choir Warden (`:10`) | re-measured on `under_island`, variant `""` |
| `tests/highdraft_gate_bot_test.gd` | the skipper reaches the gates (`:10`) | the Keel Bench gates |
| `tests/highdraft_light_test.gd` | the morning light and cream cloud deck (`:7`) | the `golden` row |
| `tests/highdraft_scenery_test.gd`, `highdraft_materials_test.gd`, `highdraft_fx_test.gd`, `highdraft_tone_test.gd` | today's island kit (`highdraft_scenery_test.gd:16`, `highdraft_materials_test.gd:9`) | retire with the old map at KD7; the recipe tests replace them |
| `tests/warden_variants_test.gd` | variants reach the Warden (`:7`) | stage 5 now has none |
| `tests/alpha_posture_bands_w23_test.gd` | stage 5 inside the world 3 band | re-measured and re-pinned (PARK.md:444) |
| The ending fly-over | copies the Highdraft terrain and hides its grid floor (`src/ui/ending_sequence.gd:233-234`) | reads the park terrain; checked in KD7 |

**Shipped (KD5 greybox, 2026-10-11).** `tests/park_park_islands_test.gd` is in: it pins the bake and graph freshness, the waymark order, the four pocket roles and their 2.12 distances, the landmark and the mind Warden's `under_island` row, and that every named waypoint of the seven lines resolves, each pin with a planted copy that must fail. The `highdraft_*` tests keep pinning today's map, which `--table=alpha` still plays, until KD7 retires it; the packs, Warden numbers, beacon seconds and music rows above are unchanged by the park file.

**Fix round (2026-10-12).** The stage test's header is re-dated; its PARK.md 2.12 distances now come from tools/park_graph.gd's own constants (SIGHT_M, DOOR_SPAWN_M, DOOR_BEACON_M, DOOR_DOOR_M, DETOUR_MIN_M, DETOUR_MAX_M) instead of copied literals, and its graph-ruling pin (no breach, `beacon_ok`, 13 routes connected, the spawn rule passing) holds on the shipped file. `tests/park_table_test.gd` now accepts a valid ParkMap for stage 5 when its park file is present, from the candidate fix 1f09581. It remains a shared test outside this unit's write scope.

**Round 3 verification, 2026-10-12.** The candidate merge brings BAY-LIMIT,
so the bay uses this park's real dock bounds. Completionist seeds 1 to 3 measure
the unchanged mind Warden through a 600 s stage-limit wrapper. Engage-to-break
seconds and exact outcome rows are in the round report; the table below records
what follows each break. The old 240 s/R11 exception is retired.

| Seed | Outcome | Stage reached | Engage s | Break s | Engage to break s | Warden damage | After break |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | stages_done | 6 | 143.43 | 260.74 | 117.31 | {'ram': 1250.0} | entered stage 6; stages_done |
| 2 | stages_done | 6 | 138.85 | 236.58 | 97.73 | {'ram': 781.3, 'slam': 156.3, 'stomp': 312.5} | entered stage 6; stages_done |
| 3 | stages_done | 6 | 130.47 | 196.88 | 66.41 | {'ram': 625.0, 'slam': 625.0} | entered stage 6; stages_done |


## 14. Storyboard frames

Seven frames, in play order. Panels p1 to p6 of the stage board map onto frames 1 to 6; frame 7 is a spare for the exit.

1. **Drop-in vista (p2_drop_in).** Golden hour from the drop-in on the Lookout's south end, 2 m above the ground, looking north. Relict pines frame the left edge; the fire lookout stands on the right rim. Below, the Slickrock Run curls down to the Saddle. Beyond, the Twin Fins, the net glinting between mesas, the two wing mesas and, 1.2 km away, the upside-down mountain with its green beam. The three activity markers sit on the horizon line.
2. **First flow line (p3_line).** Chase camera low behind the ball in the Fin Chute, mid-pump on the east wall, the west fin's sunlit face filling the left of frame. Ahead, the fin nose kicker and open sky; the island floats in the gap.
3. **An enemy home (p4_home).** The Mooring Mesa's rim from the net below: brass winch posts, a moored patchwork balloon, an anchor crew's cable lane reaching down toward the ball as it crosses. The counter is in the frame: the roost ferry passing overhead.
4. **An event firing (p5_event).** The fin rim collapse in two beats: the crumble line glowing along the west fin's rim with the 6 s mark, then the slab leaning against the fin as a new ramp, dust rolling over the net.
5. **The landmark approach.** From the Anvil's altar ring: the net running north to the bowl, the knuckle buttes, and the isle filling the top half of frame, its tip 22 m above the net and the hand's green seams visible.
6. **The Warden fight (p6_warden).** Inside the bowl, looking up: the hand cupping the tip, the lens open in a stagger, a harpoon line from the ball to a knuckle, the island tilted 10 degrees. The pulse ring on the net.
7. **The exit.** The hand dark in the net; the ball rolling up the north bank onto the Keel Bench; three reward gates and Moss's bay docking above them, the island still hanging overhead in the last light.

`p1_overhead` was planned to be plotted from this park file by `tools/park_plot.py` (an unbuilt helper not present in the checkout), not generated.

## 15. Calls made here, and open questions

**Calls made under the creative charge (veto list).**

1. The Hanging Isle is an upside-down mountain: top at 400 m, not 260 m, for the sight rule; its tip at 82 m keeps the fight in rope range.
2. The net deck is one park-wide recipe at 60 m with 16 m posts on an 80 m lattice; the posts are the open-net anchors.
3. Relict pine stands on mesa tops are the mesa-top anchors.
4. The arena is a bowl net with three knuckle buttes; the south side stays open. (Fix round: SR15's flat beacon disc made it a flat 2 m dish with the knuckles 142 m out and two keel ribs on the floor; section 2.)
5. The under-island mechanism is the pendulum tilt (kind sheet).
6. Three waymarks, with the Anvil's altar as the second one, so the segments balance (370 to 811 m).
7. The cloud deck rises to 4 m under the net and never over it.
8. The fin rim collapse closes the centre route at tier 1 and opens the slab ramp.
9. The moored balloon's burner is the industrial event; its envelope becomes a ramp.
10. The island sheds a boulder on the Warden's first chunk; the crater is a ride.
11. `reach_m` is 120, so the engage ring covers the bowl; the pulse ring stays 30 m.
12. The animals' nets, posts and balloons carry society `none`, with `net_` fragments.

**Open questions for the coordinator.**

- The animals have no society id. Add `animal`, or keep `none`?
- The sight numbers come from a box model on a 50 m grid (section 16). KD5's test is the judge.

## 16. Checks run on this draft

- Schema: a Python mirror of PARK.md 2.10's checks (enums, references, home landform equals site landform, packs in the stage row, lead floors by family, the society guardrail, `handling` "none", contraption keys per kind) passed with no issues.
- Routes: with every closing event live, `west` and `east` stay open.
- Lines: lengths clipped at the engage ring, segment lengths between waymark passes.
- Sight: a 50 m grid over the play rect, eye 2 m above a box model of the stamped rows on a 60 m floor, cells under the island excluded, ray sampled every 10 m: 0.877 over 701 cells.
- None of this ran in Godot. The traversal bands, the sight test and the density test run in KD5.

**Measured on the shipped greybox, KD5 continuation, 2026-10-12.**
The shipped graph tool includes the accepted float32 comparison fix and lower-index predecessor ties.
The coordinator admitted the regression and fix as d86e7a9 and 3fd07ae and rebuilt park_test in 9ac8969.
The unit report names the final head, exact commands, tool times and artifact hashes. The headless
numbers qualify the checks they measure; Andrew's stage board and play remain the visual and feel verdict.

Graph ruling: beacon_ok True, spawn.run True, spawn.ok True, farther_share 0.135; 13 routes, 13 connected; 0 breaches.

| Pocket | Role | Graph door [x,z] | d_spawn | d_beacon | door_m | detour_m | sight_ok | Clear ring | Nearest door | Pay |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| camp_anvil | online | [0, 104] | 857 | 451 | 0 | 0 | True | [] | -1 | common / rivet_plating |
| cache_east_wing | reward | [208, 240] | 1074 | 389 | 208 | 208 | True | [] | 318 | rare |
| bounty_ore_bench | risk | [184, -56] | 757 | 685 | 184 | 184 | True | [] | 318 | common, rare |
| saddle_seam | hidden | [232, -416] | 408 | 1073 | 235 | 240 | True | [] | 390 |  |

Spawn to beacon 1306 m by path. Reward ratio 0.580 against the reported 1.5 target; full_visit_ratio 1.313 against 3.0. The reward-ratio miss is reported, not gated.

The cache moved off Kest's east-wing path to [210,236]. Its nearby hoodoo post moved
from [204,241] to [280,241] to clear the door's ray. The Anvil's third artificial step
was reduced from 2.5 m to 0.01 m after Sable's trace showed a ground contact halving
speed during a return turn across z84. The main Anvil slope and named waymark remain.
The Run's third step keeps its original 4 m height after a global reduction
gave Sable an excessive anchor gap. A local 60 by 40 m wash at [-60,-516] is
the second Run rework, on the main and slab routes, confined to Kest's turn.
Three hoodoo posts beside the Anvil-to-east-tether flight were raised from
10 m to 30 m after the diagnostic sampler located 52 m and 69 m anchor gaps above
the short posts. These are geometry reworks; the acceptance bands are unchanged.

Current traversal bands and all seed misses are in `design-v3/park/traversal/park_islands.md`.
The unit report retains prior failed runs, the bounded reworks and the final acceptance result.
The dressed pass starts only after the whole greybox list passes. No recipe coverage, draws,
triangles, stills or human acceptance is claimed for this greybox.

**Earlier writer pass: round 3 fixed-tool traversal, 2026-10-12.**

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass |
| Time to Warden, s | 60.92 / 61.88: pass | 95.84 / 96.87: pass | 78.6 / 85.1: pass | 85.75 / 85.81: pass | 75.065 / 76.86: pass | 86.575 / 86.62: pass | 88.93 / 90.34: reported, pilot band, not the floor's |
| Segment medians, s | 15.21/22.31/23.53 / 23.81: pass | 24.43/36.39/34.7 / 36.78: pass | 22.63/23.62/32.21 / 33.97: pass | 22.58/31.6/31.62 / 31.74: pass | 24.81/17.98/31.95 / 32.82: pass | 23.07/32.02/31.38 / 32.17: pass | 23.78/34.11/31.03 / 34.91: reported, pilot band, not the floor's |
| Flow share | 0.9363 / 0.9324: pass | 0.8594 / 0.8456: pass | 0.9036 / 0.7952: pass | 0.963 / 0.9562: pass | 0.9705 / 0.9383: pass | 0.9909 / 0.9804: pass | 0.8582 / 0.8582: reported, pilot band, not the floor's |
| Airborne share | 0.3878 / 0.3747..0.4019: pass | 0.3116 / 0.2482..0.3156: MISS | 0.3497 / 0.3192..0.3516: pass | 0.2808 / 0.2801..0.2843: pass | 0.3096 / 0.3043..0.3157: pass | 0.3304 / 0.3293..0.3385: pass | 0.2694 / 0.2689..0.2734: reported, pilot band, not the floor's |
| Dead stops | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass |
| Peak speed / tier-3 time | 54.915 m/s, 47.91 s / 54.29 m/s, 47.39 s: pass | 30.53 m/s, 8.99 s / 29.34 m/s, 7.74 s: pass | 30.01 m/s, 8.22 s / 27.12 m/s, 3.57 s: pass | 30.55 m/s, 10.595 s / 30.55 m/s, 10.59 s: pass | 27.065 m/s, 5.89 s / 26.86 m/s, 5.33 s: pass | 28.86 m/s, 8.965 s / 27.86 m/s, 5.21 s: pass | 31.82 m/s, 9.64 s / 30.86 m/s, 7.98 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: pass | 7.505 / 7.71: pass | 6.37 / 6.51: pass | 5.91 / 6.53: pass | 6.115 / 6.53: pass | 6.23 / 6.36: pass | 8.01 / 8.01: reported, pilot band, not the floor's |
| Anchor gap, m | 33.95 / 34.9: pass | 25.3 / 33.7: pass | 21.7 / 27.4: pass | 19.05 / 22.0: pass | 17.6 / 20.4: pass | 22.8 / 30.5: pass | 41.4 / 41.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: reported, pilot band, not the floor's |
| Length / straight distance | 1.73 / 1.71..1.74: pass | 1.54 / 1.54..1.55: pass | 1.44 / 1.44..1.47: pass | 1.61 / 1.61..1.62: pass | 1.33 / 1.33..1.34: pass | 1.57 / 1.57..1.58: pass | 1.54 / 1.54..1.54: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | 88.93 s / cap 191.68 s, stops 0: pass |
| Distinct lines | sable, kest, tarn: pass | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack |

Each cell is median / worst seed. Anchor gap uses the maximum seed, per ruling 14. Peak and tier-3 time share the PARK.md row. The airborne and length cells show the seed range beside the median. The floor uses its own row only, with Rivet as the shipped tool reference.

Progress is measured on the fixed graph reader and reported separately: sable 20.94 m/s; rivet 13.38 m/s; kest 16.225 m/s; tarn 14.875 m/s; tally 16.99 m/s; cannon 14.735 m/s; floor 14.42 m/s.

sable: 8 seed rows, stops [].

rivet: 8 seed rows, stops [].

kest: 8 seed rows, stops [].

tarn: 8 seed rows, stops [].

tally: 8 seed rows, stops [].

cannon: 8 seed rows, stops [].

floor: 8 seed rows, stops [].

## Appendix: the park file as shipped

`src/world/park/park_islands.json` as KD5's greybox ships it (2026-10-11), generated with the bake and graph beside it. The draft this page started from is in git history; the tables above say where the shipped file differs from it.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_islands",
 "size_m": 1600,
 "time_of_day": "golden",
 "spawn": {"at": [0, -720], "heading_deg": 0},
 "play_rect": [-560, -780, 1120, 1540],
 "landmark": {"id": "hanging_isle", "kind": "sky_island", "at": [0, 520], "size": [180, 318, 180], "yaw_deg": 0, "recipe": "landmark_sky_island", "budget": "hero_landmark", "sight_top": [0, 400, 520], "sight_share": 0.85, "beacon": [0, 530], "reach_m": 120, "warden": {"mounting": "under_island", "anchor": [0, 66, 520], "path": [], "hardpoints": 3, "family": "mind", "harpoon_anchor": true}, "bay_dock": {"at": [0, 650], "facing_deg": 0}, "gate_slots": [{"at": [-20, 720], "facing_deg": 0}, {"at": [0, 720], "facing_deg": 0}, {"at": [20, 720], "facing_deg": 0}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "ancient_keel_grip"},
 "waymarks": ["drop_in", "saddle", "anvil_rock", "landmark"],
 "routes": [
  {"id": "main", "from": "drop_in", "to": "landmark", "via": ["lookout_mesa", "lookout_lip", "slickrock_run", "run_turn_wash", "saddle", "twin_fins", "fin_chute", "fin_nose_kicker", "net_deck", "anvil_rock", "net_post_run", "net_bowl"]},
  {"id": "west", "from": "drop_in", "to": "landmark", "via": ["lookout_mesa", "lookout_lip", "lookout_stair", "saddle", "west_shelf", "hoodoo_garden", "mooring_mesa", "mooring_pad_ramp", "net_deck", "anvil_rock", "west_wing", "cloud_wash_west", "knuckle_w", "net_bowl"]},
  {"id": "east", "from": "drop_in", "to": "landmark", "via": ["lookout_mesa", "lookout_lip", "east_ribs", "saddle", "tram_head", "ore_bench", "ore_adit", "ore_chute", "anvil_rock", "east_wing", "cloud_wash_east", "knuckle_e", "net_bowl"]},
  {"id": "slab", "from": "drop_in", "to": "landmark", "via": ["lookout_mesa", "lookout_lip", "slickrock_run", "run_turn_wash", "saddle", "twin_fins", "net_deck", "anvil_rock", "net_bowl"]},
  {"id": "envelope", "from": "drop_in", "to": "landmark", "via": ["lookout_mesa", "lookout_lip", "lookout_stair", "saddle", "west_shelf", "mooring_mesa", "net_deck", "anvil_rock", "net_bowl"]},
  {"id": "fan_chute", "from": "saddle", "to": "anvil_rock", "via": ["saddle", "twin_fins", "fin_chute", "fin_nose_kicker", "net_deck", "anvil_rock"]},
  {"id": "fan_west", "from": "saddle", "to": "anvil_rock", "via": ["saddle", "west_shelf", "hoodoo_garden", "mooring_mesa", "mooring_pad_ramp", "net_deck", "anvil_rock"]},
  {"id": "fan_east", "from": "saddle", "to": "anvil_rock", "via": ["saddle", "tram_head", "ore_bench", "ore_adit", "ore_chute", "anvil_rock"]},
  {"id": "fan_slab", "from": "saddle", "to": "anvil_rock", "via": ["saddle", "twin_fins", "net_deck", "anvil_rock"]},
  {"id": "fan_envelope", "from": "saddle", "to": "anvil_rock", "via": ["saddle", "west_shelf", "mooring_mesa", "net_deck", "anvil_rock"]},
  {"id": "carve_net", "from": "anvil_rock", "to": "net_bowl", "via": ["anvil_rock", "net_post_run", "net_bowl"]},
  {"id": "wing_west", "from": "anvil_rock", "to": "net_bowl", "via": ["anvil_rock", "west_wing", "cloud_wash_west", "knuckle_w", "net_bowl"]},
  {"id": "wing_east", "from": "anvil_rock", "to": "net_bowl", "via": ["anvil_rock", "east_wing", "cloud_wash_east", "knuckle_e", "net_bowl"]}
 ],
 "park_rows": [
  {"id": "net_deck", "element": "ground", "landform": "sky_island", "society": "none", "at": [0, -9.0], "y": null, "size": [1540, 50.0, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["main", "west", "slab", "envelope", "fan_chute", "fan_west", "fan_slab", "fan_envelope"], "fragment": "none_net_deck_rivets"},
  {"id": "lookout_mesa", "element": "sky_island", "landform": "sky_island", "society": "none", "at": [0, -690.0], "y": null, "size": [180, 28, 1600], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west", "east", "slab", "envelope"], "fragment": "none_sky_island_relicts"},
  {"id": "slickrock_run", "element": "flow_line", "landform": "slickrock", "society": "none", "at": [0, -515.0], "y": null, "size": [170, 36, 1600], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "slab"], "fragment": ""},
  {"id": "slickrock_run_shelf", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -690.0], "y": null, "size": [178, 36, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "saddle", "element": "bank", "landform": "slickrock", "society": "none", "at": [0, -390.0], "y": null, "size": [80, 8, 1600], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west", "east", "slab", "envelope", "fan_chute", "fan_west", "fan_east", "fan_slab", "fan_envelope"], "fragment": ""},
  {"id": "saddle_shelf", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -605.0], "y": null, "size": [348, 8, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_band", "element": "flow_line", "landform": "butte", "society": "none", "at": [0, -225.0], "y": null, "size": [250, 48, 1600], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": "none_fin_varnish"},
  {"id": "fan_band_shelf", "element": "ground", "landform": "butte", "society": "none", "at": [0, -565.0], "y": null, "size": [428, 48, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "landing_hill", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -65.0], "y": null, "size": [70, 24, 1600], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "landing_hill_shelf", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -440.0], "y": null, "size": [678, 24, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_rock", "element": "sky_island", "landform": "butte", "society": "none", "at": [0, 46.0], "y": null, "size": [152, 16, 1600], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west", "east", "slab", "envelope", "fan_chute", "fan_west", "fan_east", "fan_slab", "fan_envelope", "carve_net", "wing_west", "wing_east"], "fragment": "none_desert_varnish"},
  {"id": "anvil_rock_shelf", "element": "ground", "landform": "butte", "society": "none", "at": [0, -405.0], "y": null, "size": [748, 16, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_face", "element": "drop", "landform": "butte", "society": "none", "at": [0, 123.0], "y": null, "size": [2, 12, 1600], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_face_shelf", "element": "ground", "landform": "butte", "society": "none", "at": [0, -329.0], "y": null, "size": [900, 12, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "net_carve", "element": "half_pipe", "landform": "sky_island", "society": "none", "at": [0, 265.0], "y": null, "size": [282, 24, 1600], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": "net_knot_tally"},
  {"id": "net_carve_shelf", "element": "ground", "landform": "sky_island", "society": "none", "at": [0, -328.0], "y": null, "size": [902, 24, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "isle_apron", "element": "terrace", "landform": "sky_island", "society": "none", "at": [0, 583.0], "y": null, "size": [354, 6, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "terrace", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "isle_apron_shelf", "element": "ground", "landform": "sky_island", "society": "none", "at": [0, -187.0], "y": null, "size": [1184, 14, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_lip", "element": "kicker", "landform": "mesa_rim", "society": "none", "at": [0, -606], "y": null, "size": [12, 4, 300], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "landform", "routes": ["main", "west", "east", "slab", "envelope"], "fragment": ""},
  {"id": "lookout_cairn_1", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-24, -748], "y": null, "size": [8, 16, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "lookout_cairn_2", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [24, -748], "y": null, "size": [8, 16, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "lookout_cairn_3", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [0, -762], "y": null, "size": [8, 16, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fire_lookout", "element": "anchor_field", "landform": "mesa_rim", "society": "dam_era", "at": [150, -700], "y": null, "size": [8, 24, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": "dam_era_lookout_log"},
  {"id": "lookout_pines", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-150, -700], "y": null, "size": [10, 20, 10], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "lookout_step_1", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [0, -740.0], "y": null, "size": [40.0, 3, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_step_lip_1", "element": "kicker", "landform": "mesa_rim", "society": "none", "at": [0, -726.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_step_2", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [0, -700.0], "y": null, "size": [40.0, 3, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_step_3", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [0, -660.0], "y": null, "size": [40.0, 3, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_step_lip_3", "element": "kicker", "landform": "mesa_rim", "society": "none", "at": [0, -646.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_step_4", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [0, -620.0], "y": null, "size": [40.0, 3, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_1", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -580.0], "y": null, "size": [32.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_lip_1", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -570.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_2", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -548.0], "y": null, "size": [32.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_lip_2", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -538.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_3", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -516.0], "y": null, "size": [32.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_turn_wash", "element": "flow_line", "landform": "slickrock", "society": "none", "at": [-60, -516], "y": null, "size": [60, 4, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main", "slab"], "fragment": ""},
  {"id": "run_step_lip_3", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -506.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_4", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -484.0], "y": null, "size": [32.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_lip_4", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -474.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_5", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -452.0], "y": null, "size": [32.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "run_step_lip_5", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -442.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "saddle_step_1", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -410.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "saddle_step_2", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -370.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lookout_stair", "element": "flow_line", "landform": "mesa_rim", "society": "dam_era", "at": [-100, -520], "y": null, "size": [160, 0.01, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["west", "envelope"], "fragment": "dam_era_switchback_stones"},
  {"id": "east_ribs", "element": "flow_line", "landform": "slickrock", "society": "none", "at": [100, -520], "y": null, "size": [160, 0.01, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east"], "fragment": ""},
  {"id": "saddle_cairn_w", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-150, -400], "y": null, "size": [10, 16, 10], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saddle_cairn_e", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [200, -400], "y": null, "size": [10, 16, 10], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "twin_fins", "element": "sky_island", "landform": "butte", "society": "none", "at": [0, -220], "y": null, "size": [240, 0.01, 140], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["main", "slab", "fan_chute", "fan_slab"], "fragment": "none_fin_varnish"},
  {"id": "fin_west", "element": "sky_island", "landform": "butte", "society": "none", "at": [-43.0, -234.0], "y": null, "size": [190, 60, 32], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fin_east", "element": "sky_island", "landform": "butte", "society": "none", "at": [45.0, -234.0], "y": null, "size": [190, 60, 32], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fin_chute", "element": "half_pipe", "landform": "butte", "society": "none", "at": [0, -220], "y": null, "size": [240, 0.01, 56], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "isle_ride_fin_chute", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["main", "fan_chute"], "fragment": "", "hide_on": "fin_rim_collapse"},
  {"id": "fan_step_1", "element": "drop", "landform": "butte", "society": "none", "at": [0, -320.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_1", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -306.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_2", "element": "drop", "landform": "butte", "society": "none", "at": [0, -280.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_2", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -266.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_3", "element": "drop", "landform": "butte", "society": "none", "at": [0, -240.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_3", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -226.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_4", "element": "drop", "landform": "butte", "society": "none", "at": [0, -200.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_4", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -186.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_5", "element": "drop", "landform": "butte", "society": "none", "at": [0, -160.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_5", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -146.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_6", "element": "drop", "landform": "butte", "society": "none", "at": [0, -120.0], "y": null, "size": [40.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fan_step_lip_6", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -106.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fin_nose_kicker", "element": "kicker", "landform": "butte", "society": "none", "at": [0, -106], "y": null, "size": [12, 4, 56], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "mesa_lip_kicker_12x4x56", "fit": "seat", "stamp": "", "hole": false, "budget": "landform", "routes": ["main", "fan_chute"], "fragment": "", "hide_on": "fin_rim_collapse"},
  {"id": "west_shelf", "element": "terrace", "landform": "mesa_rim", "society": "none", "at": [-215, -260], "y": null, "size": [160, 0.01, 170], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:terrace", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["west", "envelope", "fan_west", "fan_envelope"], "fragment": ""},
  {"id": "hoodoo_garden", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-245, -135], "y": null, "size": [90, 2, 170], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["west", "fan_west"], "fragment": "none_hoodoo_ash"},
  {"id": "hoodoo_cap_1", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-290, -150], "y": null, "size": [10, 22, 10], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_cap_2", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-170, -120], "y": null, "size": [10, 22, 10], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mooring_mesa", "element": "sky_island", "landform": "mesa_rim", "society": "fleet", "at": [-240, -20], "y": null, "size": [140, 0.01, 180], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "mooring_anchor_crew", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["west", "envelope", "fan_west", "fan_envelope"], "fragment": "fleet_mooring_tags"},
  {"id": "mooring_pad", "element": "ground", "landform": "mesa_rim", "society": "fleet", "at": [-300, -40], "y": null, "size": [40, 0.01, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_anchor_crew", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mooring_pad_ramp", "element": "drop", "landform": "mesa_rim", "society": "fleet", "at": [-130, 30], "y": null, "size": [60, 5, 140], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["west", "fan_west"], "fragment": ""},
  {"id": "tram_head", "element": "ledge", "landform": "mesa_rim", "society": "mining", "at": [118, -398], "y": null, "size": [30, 3, 30], "yaw_deg": 0, "verb": "drop", "ride_fact": "", "home": "tram_cutters", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "fan_east"], "fragment": "mining_tram_ledger"},
  {"id": "ore_bench", "element": "terrace", "landform": "tailings_bench", "society": "mining", "at": [290, -150], "y": null, "size": [200, 0.01, 220], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:terrace", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "fan_east"], "fragment": "mining_ore_bench_assay"},
  {"id": "ore_adit", "element": "tunnel", "landform": "adit", "society": "mining", "at": [196, -62], "y": null, "size": [30, 0.01, 14], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:tunnel", "stamp": "plateau", "hole": false, "budget": "park_large", "routes": ["east", "fan_east"], "fragment": "mining_adit_lamp"},
  {"id": "ore_chute", "element": "grind_line", "landform": "flume", "society": "mining", "at": [110, 0], "y": null, "size": [150, 0.01, 16], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "chute_cutters", "recipe": "greybox:grind_line", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "fan_east"], "fragment": "mining_ore_chute"},
  {"id": "landing_step_1", "element": "drop", "landform": "slickrock", "society": "none", "at": [0, -70.0], "y": null, "size": [50.0, 4, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "landing_step_lip_1", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, -51.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_step_1", "element": "drop", "landform": "butte", "society": "none", "at": [0, -11.0], "y": null, "size": [38.0, 2.5, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_step_2", "element": "drop", "landform": "butte", "society": "none", "at": [0, 27.0], "y": null, "size": [38.0, 2.5, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_step_3", "element": "drop", "landform": "butte", "society": "none", "at": [0, 65.0], "y": null, "size": [38.0, 0.01, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "anvil_step_4", "element": "drop", "landform": "butte", "society": "none", "at": [0, 103.0], "y": null, "size": [38.0, 2.5, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_1", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 146.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_lip_1", "element": "kicker", "landform": "sky_island", "society": "none", "at": [0, 160.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_2", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 186.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_3", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 226.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_lip_3", "element": "kicker", "landform": "sky_island", "society": "none", "at": [0, 240.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_4", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 266.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_5", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 306.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_lip_5", "element": "kicker", "landform": "sky_island", "society": "none", "at": [0, 320.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_6", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 346.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_7", "element": "drop", "landform": "sky_island", "society": "none", "at": [0, 386.0], "y": null, "size": [40.0, 2, 1600], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "carve_step_lip_7", "element": "kicker", "landform": "sky_island", "society": "none", "at": [0, 400.0], "y": null, "size": [12, 0.01, 1600], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_wing", "element": "sky_island", "landform": "mesa_rim", "society": "none", "at": [-210, 260], "y": null, "size": [320, 0.01, 120], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["west", "wing_west"], "fragment": ""},
  {"id": "cloud_wash_west", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-210, 260], "y": null, "size": [300, 0.01, 30], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "isle_ride_wash_west", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["west", "wing_west"], "fragment": ""},
  {"id": "east_wing", "element": "sky_island", "landform": "mesa_rim", "society": "none", "at": [210, 260], "y": null, "size": [320, 0.01, 120], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "wing_east"], "fragment": ""},
  {"id": "cloud_wash_east", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [210, 260], "y": null, "size": [300, 0.01, 30], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "wing_east"], "fragment": ""},
  {"id": "kite_roost", "element": "sky_island", "landform": "butte", "society": "none", "at": [-440, 470], "y": null, "size": [140, 110, 140], "yaw_deg": 0, "verb": "lift", "ride_fact": "thermal_ride", "home": "roost_kites", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lens_rocks", "element": "sky_island", "landform": "butte", "society": "ancient", "at": [430, 470], "y": null, "size": [120, 90, 120], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": "ancient_lens_rock_hum"},
  {"id": "net_post_run", "element": "half_pipe", "landform": "sky_island", "society": "none", "at": [0, 200], "y": null, "size": [160, 0.01, 120], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["main", "carve_net"], "fragment": ""},
  {"id": "net_bowl", "element": "bowl", "landform": "sky_island", "society": "none", "at": [0, 530], "y": null, "size": [260, 2.0, 260], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "park_large", "routes": ["main", "west", "east", "slab", "envelope", "carve_net", "wing_west", "wing_east"], "fragment": "net_bowl_mends"},
  {"id": "knuckle_w", "element": "bank", "landform": "butte", "society": "none", "at": [-142, 530], "y": null, "size": [36, 19, 36], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "butte", "hole": false, "budget": "landform", "routes": ["west", "wing_west"], "fragment": ""},
  {"id": "knuckle_e", "element": "bank", "landform": "butte", "society": "none", "at": [142, 530], "y": null, "size": [36, 19, 36], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "butte", "hole": false, "budget": "landform", "routes": ["east", "wing_east"], "fragment": ""},
  {"id": "knuckle_n", "element": "bank", "landform": "butte", "society": "none", "at": [-100, 630], "y": null, "size": [36, 19, 36], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "keel_rib_w", "element": "ledge", "landform": "sky_island", "society": "ancient", "at": [-27.9, 465.8], "y": null, "size": [50, 12, 3], "yaw_deg": -156.5, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "keel_rib_e", "element": "ledge", "landform": "sky_island", "society": "ancient", "at": [27.9, 465.8], "y": null, "size": [50, 12, 3], "yaw_deg": 156.5, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "isle_post_5", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-126, 444], "y": null, "size": [8, 30, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "isle_post_6", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [126, 444], "y": null, "size": [8, 30, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "isle_post_9", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-100, 398], "y": null, "size": [8, 16, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "isle_post_10", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [100, 398], "y": null, "size": [8, 16, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "keel_ramp", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [0, 620], "y": null, "size": [40, 0.01, 80], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "keel_bench", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [0, 700], "y": null, "size": [120, 0.01, 120], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "greybox:ground", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "net_posts_1", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-440, -620], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_2", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-440, -420], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_3", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [440, -620], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_4", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [440, -420], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_5", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-440, -220], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_6", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [440, -220], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_7", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-460, -10], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_8", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [460, -10], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_9", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-440, 220], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_10", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [440, 220], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_11", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [-300, 640], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "net_posts_12", "element": "anchor_field", "landform": "sky_island", "society": "none", "at": [300, 640], "y": null, "size": [200, 16, 200], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_1", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-5, -748], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_2", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-25, -744], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_3", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-44, -741], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_4", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-65, -736], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_5", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-84, -730], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_6", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-106, -723], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_7", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-125, -716], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_8", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-147, -710], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_9", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-123, -653], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_10", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-133, -643], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_11", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-123, -603], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_12", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-109, -589], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_13", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-95, -575], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_14", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-81, -560], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_15", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-64, -543], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_16", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-27, -507], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_17", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-13, -493], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_18", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [0, -469], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_19", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [7, -450], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_20", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [14, -431], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_21", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [21, -740], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_22", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [38, -730], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_23", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [22, -673], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_24", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [36, -660], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_25", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [45, -645], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_26", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [98, -613], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_27", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -623], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_28", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [64, -567], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_29", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [13, -596], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_30", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [25, -538], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_31", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-22, -574], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_32", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-111, -434], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_33", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [77, -706], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_34", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [96, -692], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_35", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [113, -679], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_36", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [155, -636], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_37", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [119, -590], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_38", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [179, -593], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_39", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [130, -560], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_40", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [182, -528], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_41", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [123, -529], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_42", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [161, -482], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_43", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [106, -502], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_44", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [133, -449], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_45", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [81, -478], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_46", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [99, -420], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_47", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [50, -455], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_48", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [34, -445], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_49", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-113, -600], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_50", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-101, -386], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_51", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-92, -394], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_52", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, -339], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_53", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-125, -381], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_54", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-126, -322], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_55", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-170, -364], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_56", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-162, -306], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_57", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-206, -346], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_58", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-194, -288], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_59", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-245, -321], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_60", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-225, -265], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_61", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-279, -290], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_62", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-244, -243], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_63", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-305, -244], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_64", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-253, -216], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_65", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-307, -188], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_66", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-247, -186], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_67", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-286, -140], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_68", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-228, -151], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_69", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-266, -105], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_70", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-208, -118], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_71", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-241, -69], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_72", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-184, -86], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_73", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-214, -35], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_74", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-159, -57], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_75", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-183, -2], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_76", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-132, -32], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_77", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-149, 25], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_78", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-103, -12], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_79", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-107, 48], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_80", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-87, 56], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_81", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -338], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_82", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -326], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_83", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -322], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_84", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -314], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_85", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -310], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_86", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -302], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_87", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -298], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_88", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -290], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_89", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -286], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_90", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -278], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_91", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -274], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_92", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -266], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_93", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -262], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_94", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -254], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_95", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -250], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_96", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -242], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_97", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -238], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_98", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -230], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_99", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -226], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_100", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -220], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_101", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -216], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_102", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -208], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_103", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -204], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_104", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -196], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_105", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -192], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_106", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -184], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_107", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -180], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_108", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -172], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_109", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -170], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_110", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -162], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_111", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -158], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_112", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -150], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_113", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -146], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_114", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [40, -138], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_115", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -134], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_116", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-40, -123], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_117", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-39, -111], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_118", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-38, -99], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_119", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-37, -87], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_120", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [37, -84], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_121", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, -75], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_122", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [38, -72], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_123", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [38, -61], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_124", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, -59], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_125", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [43, -49], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_126", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-37, -47], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_127", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-25, -39], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_128", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-26, -19], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_130", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [88, -404], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_131", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [79, -349], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_132", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [132, -376], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_133", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [108, -322], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_134", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [161, -349], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_135", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [137, -294], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_136", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [190, -321], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_137", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [169, -264], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_138", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [222, -291], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_139", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [202, -234], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_140", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [254, -261], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_141", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [272, -245], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_142", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [288, -230], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_143", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [302, -215], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_144", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [313, -190], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_145", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [317, -170], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_146", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [317, -141], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_147", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [313, -121], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_148", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [312, -91], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_149", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [306, -81], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_150", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [291, -81], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_287", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [245, -140], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_151", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [259, -54], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_152", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [239, -50], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_153", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [220, -46], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_154", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [200, -43], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_155", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [181, -38], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_156", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [158, -31], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_157", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [140, -23], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_158", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [122, -14], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_159", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [103, -3], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_160", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [95, 10], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_161", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [95, 20], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_162", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [85, 22], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_163", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [84, 32], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_164", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [72, 28], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_165", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [66, 51], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_166", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-51, -315], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_167", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-110, -322], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_168", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-62, -292], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_169", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-118, -272], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_170", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-62, -252], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_171", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-62, -232], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_172", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-74, -204], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_173", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-131, -221], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_174", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-91, -177], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_175", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-151, -179], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_176", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-102, -150], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_177", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-159, -134], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_178", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-103, -118], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_179", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-150, -79], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_180", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-92, -85], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_181", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-82, -68], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_182", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-49, -31], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_183", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, -18], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_184", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [225, -216], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_185", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [212, -201], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_186", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [199, -186], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_187", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [186, -171], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_188", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [173, -156], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_189", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [160, -141], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_190", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [147, -125], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_191", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [131, -107], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_192", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [118, -92], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_193", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [105, -77], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_194", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [61, -46], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_195", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, 102], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_196", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-54, 113], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_197", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-98, 72], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_198", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-90, 131], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_199", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-133, 90], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_200", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-125, 149], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_201", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-169, 108], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_202", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-161, 167], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_203", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-204, 127], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_204", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-185, 177], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_205", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-244, 168], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_206", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-199, 207], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_207", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-259, 219], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_208", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-204, 241], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_209", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-256, 269], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_210", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-198, 272], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_211", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-243, 311], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_212", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-185, 301], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_213", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-223, 347], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_214", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-165, 331], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_215", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-197, 382], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_216", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-141, 360], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_217", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-164, 416], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_218", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-128, 373], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_219", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-108, 376], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_220", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-89, 379], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_221", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [4, 380], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_222", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [75, 59], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_223", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [30, 110], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_224", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [43, 127], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_225", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [52, 144], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_226", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [113, 145], "y": null, "size": [8, 30, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_227", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [64, 181], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_228", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [121, 201], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_229", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [64, 216], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_230", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [116, 244], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_231", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [56, 252], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_232", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [104, 288], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_233", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [45, 283], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_234", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [75, 340], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_235", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [28, 303], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_236", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [41, 361], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_237", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-46, 350], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_238", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-63, 361], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_239", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [91, 68], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_240", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [108, 77], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_241", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [129, 151], "y": null, "size": [8, 30, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_242", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [172, 110], "y": null, "size": [8, 30, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_243", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [165, 169], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_244", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [212, 130], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_245", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [187, 180], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_246", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [197, 198], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_247", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [203, 219], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_248", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [280, 241], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_249", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [201, 260], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_250", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [195, 279], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_251", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [189, 294], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_252", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [179, 312], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_253", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [168, 328], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_254", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [155, 344], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_255", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [141, 360], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_256", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [164, 416], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_257", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [128, 373], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_258", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [108, 376], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_259", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [89, 379], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_260", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [69, 382], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_261", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [49, 385], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_262", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [28, 382], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_263", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [16, 377], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_264", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [248, 162], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_265", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [261, 180], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_266", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [276, 205], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_267", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [282, 224], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_268", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [287, 249], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_269", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [287, 272], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_270", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [281, 299], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_271", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [274, 318], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_272", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [262, 335], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_273", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [247, 355], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_274", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [233, 369], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_275", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [215, 385], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_276", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [199, 397], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_277", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-36, -344], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_279", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [35, -432], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_280", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [12, -418], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_281", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [171, -48], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_282", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [29, 50], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_post_285", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [21, -12], "y": null, "size": [8, 10, 8], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""}
 ],
 "event_rows": [
  {"id": "fin_rim_collapse", "kind": "collapse", "family": "natural", "site": "twin_fins", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "cave_in_crumble", "on_bar": true}, "live_s": 0.0, "effect": {"depth_m": 8.0, "fill_s": 0.0, "swap": "fin_slab_ramp"}, "route_change": {"closes": ["main", "fan_chute"], "opens": ["slab", "fan_slab"]}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}},
  {"id": "mooring_burner_blow", "kind": "boiler_burst", "family": "industrial", "site": "mooring_mesa", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true}, "live_s": 10.0, "effect": {"hazard": "burner_flare", "hazard_m": [22, 12], "damage": 6.0, "swap": "envelope_drape"}, "route_change": {"closes": [], "opens": ["envelope", "fan_envelope"]}, "hold_clear_m": 16.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_boiler"}},
  {"id": "mooring_dropship", "kind": "fleet_landing", "family": "fleet", "site": "mooring_pad", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_anchor_crew", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet_anvil"}},
  {"id": "lens_rocks_wake", "kind": "machine_eruption", "family": "ancient", "site": "lens_rocks", "trigger": {"on": "clock_tier", "value": 2}, "weight": 0.6, "telegraph": {"lead_s": 9.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "mind_hand", "swap": "lens_rock_crater"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 18.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_mind_quote", "land": "drop_mind_wrong"}},
  {"id": "isle_shed", "kind": "impact", "family": "natural", "site": "west_wing", "trigger": {"on": "warden_phase", "value": "chunk_1"}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "impact_incoming", "on_bar": true}, "live_s": 0.0, "effect": {"strike_m": 20.0, "damage": 8.0, "swap": "crater_event"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 30.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_impact"}}
 ],
 "home_rows": [
  {"id": "tram_cutters", "enemy": "line_cutter", "site": "tram_head", "landform": "mesa_rim", "advantage": "The tramway is the east fan's air path; cutters on the station deck throw across the cable while you hang on it.", "counter": "Drop off the cable early onto the Ore Bench or glide under the arc; the deck sits level with the saddle's east lip, so a ram from the lip reaches it.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 3, "pack": "draft_cut"}, "break": {"by": "ram", "hp": 120.0, "scrap": 30}, "stops_kind": true, "dormant": false},
  {"id": "chute_cutters", "enemy": "line_cutter", "site": "ore_chute", "landform": "flume", "advantage": "Trestle tops overlook the grind; a cut line drops you off the chute's high end onto the net.", "counter": "Grind it low and fast: the reticle closes on where you will be, and the chute's speed carries you past it.", "reinforce": {"from_tier": 2, "every_s": 40.0, "max_alive": 2, "pack": "draft_cut"}, "break": {"by": "ram", "hp": 100.0, "scrap": 25}, "stops_kind": false, "dormant": false},
  {"id": "mooring_anchor_crew", "enemy": "anchor_crew", "site": "mooring_mesa", "landform": "mesa_rim", "advantage": "Winch posts line the mooring rim over the net; a ball crossing below is hooked onto the deck.", "counter": "Jump the cable lane before it fills, or come in high off the roost ferry and slam the post from above.", "reinforce": {"from_tier": 0, "every_s": 35.0, "max_alive": 3, "pack": "draft_anchor"}, "break": {"by": "slam", "hp": 140.0, "scrap": 35}, "stops_kind": true, "dormant": false},
  {"id": "dropship_anchor_crew", "enemy": "anchor_crew", "site": "mooring_pad", "landform": "mesa_rim", "advantage": "The landed dropship's ramp is a winch deck facing the net; it doubles the moorings' crew.", "counter": "Its ramp is also a kicker: roll up it at speed and smash the winch on the way over.", "reinforce": {"from_tier": 2, "every_s": 30.0, "max_alive": 3, "pack": "draft_anchor"}, "break": {"by": "smash", "hp": 160.0, "scrap": 40}, "stops_kind": false, "dormant": true},
  {"id": "roost_kites", "enemy": "kite_drone", "site": "kite_roost", "landform": "butte", "advantage": "The roost's sunny face holds a thermal that keeps them above ram reach.", "counter": "Shoot them while they circle or leave the dive mark; Kest rides the same column above them and slams.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 4, "pack": "draft_kites"}, "break": {"by": "damage", "hp": 160.0, "scrap": 30}, "stops_kind": true, "dormant": false}
 ],
 "contraption_rows": [
  {"id": "fin_thermal", "kind": "thermal", "site": "twin_fins", "recipe": "", "at": [-90, -230], "radius": 6.0, "height": 240.0},
  {"id": "roost_thermal", "kind": "thermal", "site": "kite_roost", "recipe": "", "at": [-400, 420], "radius": 6.0, "height": 220.0},
  {"id": "bowl_thermal", "kind": "thermal", "site": "knuckle_e", "recipe": "", "at": [110, 470], "radius": 6.0, "height": 160.0},
  {"id": "bowl_thermal_w", "kind": "thermal", "site": "knuckle_w", "recipe": "", "at": [-110, 470], "radius": 6.0, "height": 160.0},
  {"id": "tramway", "kind": "cable", "site": "tram_head", "recipe": "", "from": [95, 192.6, -372], "to": [262, 165.2, -216], "radius": 4.5, "floor": 18.0},
  {"id": "ore_line", "kind": "cable", "site": "ore_chute", "recipe": "", "from": [236, 119.6, -36], "to": [40, 113.2, 40], "radius": 4.5, "floor": 18.0},
  {"id": "roost_line", "kind": "cable", "site": "kite_roost", "recipe": "", "from": [-420, 173.0, 470], "to": [-75, 62.7, 515], "radius": 4.5, "floor": 18.0},
  {"id": "west_tether", "kind": "cable", "site": "anvil_rock", "recipe": "", "from": [-60, 108.0, 84], "to": [-208, 89.1, 160], "radius": 4.5, "floor": 18.0},
  {"id": "east_tether", "kind": "cable", "site": "anvil_rock", "recipe": "", "from": [60, 108.0, 84], "to": [208, 89.1, 160], "radius": 4.5, "floor": 18.0},
  {"id": "keel_line", "kind": "cable", "site": "net_post_run", "recipe": "", "from": [60, 74.7, 316], "to": [-60, 69.0, 392], "radius": 4.5, "floor": 18.0},
  {"id": "west_balloon_lift", "kind": "lift", "site": "west_wing", "recipe": "lift_platform", "at": [-400, 180], "radius": 5.0, "rise": 60.0, "charge": 4.0, "offset": 0.0},
  {"id": "east_balloon_lift", "kind": "lift", "site": "east_wing", "recipe": "lift_platform", "at": [400, 180], "radius": 5.0, "rise": 60.0, "charge": 4.0, "offset": 2.0},
  {"id": "cloud_cannon_west", "kind": "launcher", "site": "cloud_wash_west", "recipe": "cannon", "style": "cannon", "at": [-210, 392], "radius": 4.0, "target": [-75, 82, 505], "floor": 30.0, "min_flight": 3.0, "charge": 2.5},
  {"id": "cloud_cannon_east", "kind": "launcher", "site": "cloud_wash_east", "recipe": "cannon", "style": "cannon", "at": [210, 392], "radius": 4.0, "target": [75, 82, 505], "floor": 30.0, "min_flight": 3.0, "charge": 2.5},
  {"id": "roost_ferry", "kind": "barge", "site": "mooring_mesa", "recipe": "barge", "a": [-280, 108.4, 60], "b": [-430, 172.5, 420], "size": [14, 2, 14], "travel": 18.0, "dwell": 3.0, "offset": 0.0},
  {"id": "saddle_seam", "kind": "cracked_wall", "site": "saddle", "recipe": "", "at": [230, -420], "size": [10, 6, 1.4], "turn": 1.2, "cache": {"at": [236, -426]}}
 ],
 "weather_rows": [
  {"id": "golden_air", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0025, "color": "#f0c08e"}, "sky": "clear", "sound": "high_wind_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "cloud_rise", "kind": "cloud_deck", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 8.0, "live_s": 60.0, "gap_s": 60.0, "fog": {"density": 0.006, "color": "#ece7da"}, "sky": "clear", "sound": "cloud_hush_bed", "music_layer": "layer_cloud_pad", "event_odds": {"mooring_dropship": 2.0}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "camp_anvil", "activity": "enemy_camp", "site": "anvil_rock", "at": [0, 104], "pack": ["anchor_crew", "anchor_crew", "line_cutter"], "pay": {"named": "rivet_plating"}},
  {"id": "cache_east_wing", "activity": "cracked_cache", "site": "east_wing", "at": [210, 236], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "bounty_ore_bench", "activity": "hauler_bounty", "site": "ore_bench", "at": [186, -60], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
}
```
