# park_islands traversal

## Greybox continuation, 2026-10-12, program head d6923b0

Verdict: FAIL, evidence level 4. Seven lines, eight seeds each, measured on one
frozen park file and lines file through the shipped traversal tool at fixed FPS 90
and nice 10. The complete JSON summaries and traces are in
`/tmp/claude-1000/w13-sol/kd5-islands-r2/greybox-final2/`.

Sable's stop is cleared and every Sable band passes. Kest reaches on all eight
seeds but seed 1 stops once at [-70, -511.4] and its anchor gap is 42.2 m against
40 m. The Run's two reworks are exhausted. Tally seed 7 peaks at 26.52 m/s against
the 26.6 m/s minimum. The dressed pass is not started.

The table applies the coordinator's current rulings. Anchor gap uses the worst
seed, not the tool's median-only Boolean. The floor is judged only by its own row;
its other numbers are reported. Ride facts use KB7b's narrowed set. The graph
reader is fixed on this head, so progress is measured and reported.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass |
| Time to Warden, s | 61.51 / 62.17: pass | 95.145 / 95.48: pass | 78.97 / 83.85: pass | 85.09 / 85.93: pass | 74.76 / 75.33: pass | 86.705 / 87.94: pass | 89.555 / 92.71: reported, pilot band, not the floor's |
| Segment medians, s | 15.3/22.4/23.99 / 24.36: pass | 24.35/36.33/34.54 / 36.59: pass | 22.72/23.56/32.09 / 32.82: pass | 22.29/30.96/31.61 / 32.01: pass | 24.35/18.09/32.13 / 32.47: pass | 23.12/31.92/31.63 / 33.08: pass | 24.77/33.85/31.0 / 34.46: reported, pilot band, not the floor's |
| Flow share | 0.9387 / 0.9321: pass | 0.8626 / 0.8519: pass | 0.8792 / 0.8502: pass | 0.9624 / 0.9534: pass | 0.9703 / 0.9424: pass | 0.9868 / 0.9803: pass | 0.869 / 0.8275: reported, pilot band, not the floor's |
| Airborne share | 0.3925 / 0.3728..0.4171: pass | 0.3135 / 0.2535..0.3199: pass | 0.3309 / 0.3252..0.3402: pass | 0.2817 / 0.2749..0.2883: pass | 0.3078 / 0.297..0.3309: pass | 0.327 / 0.3209..0.3431: pass | 0.2682 / 0.2579..0.2768: reported, pilot band, not the floor's |
| Dead stops | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 1.0: MISS | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass |
| Peak speed / tier-3 time | 55.515 m/s, 48.23 s / 54.24 m/s, 42.11 s: pass | 30.29 m/s, 9.11 s / 29.89 m/s, 6.82 s: pass | 30.11 m/s, 9.24 s / 27.48 m/s, 3.66 s: pass | 31.335 m/s, 11.32 s / 30.41 m/s, 9.94 s: pass | 27.075 m/s, 5.775 s / 26.52 m/s, 4.32 s: MISS | 28.55 m/s, 7.735 s / 27.28 m/s, 4.72 s: pass | 32.115 m/s, 10.53 s / 31.39 m/s, 8.47 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: pass | 7.385 / 8.09: pass | 6.355 / 6.5: pass | 6.1 / 6.54: pass | 6.155 / 6.52: pass | 6.325 / 6.4: pass | 7.475 / 8.14: reported, pilot band, not the floor's |
| Anchor gap, m | 34.15 / 38.9: pass | 29.3 / 32.6: pass | 27.65 / 42.2: MISS | 19.95 / 22.5: pass | 18.25 / 24.4: pass | 26.25 / 36.7: pass | 33.6 / 39.8: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: reported, pilot band, not the floor's |
| Length / straight distance | 1.73 / 1.69..1.74: pass | 1.54 / 1.54..1.54: pass | 1.44 / 1.43..1.47: pass | 1.61 / 1.61..1.62: pass | 1.33 / 1.33..1.34: pass | 1.58 / 1.57..1.58: pass | 1.54 / 1.54..1.54: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | 89.555 s / cap 190.29 s, stops 0: pass |
| Distinct lines | sable, rivet, kest, tarn, cannon: pass | n/a | n/a | n/a | n/a | n/a | n/a |

Each cell is median / worst seed. Anchor gap uses the maximum seed, per ruling 14. Peak and tier-3 time share the PARK.md row. The airborne and length cells show the seed range beside the median. The floor uses its own row only, with Rivet as the shipped tool reference.

Progress is measured on the fixed graph reader and reported separately: sable 20.74 m/s; rivet 13.475 m/s; kest 16.205 m/s; tarn 14.99 m/s; tally 17.065 m/s; cannon 14.71 m/s; floor 14.315 m/s.

sable: 8 seed rows, stops [].

rivet: 8 seed rows, stops [].

kest: 8 seed rows, stops [[1, [{"at": [-70.0, -511.4], "time": 16.41}]]].

tarn: 8 seed rows, stops [].

tally: 8 seed rows, stops [].

cannon: 8 seed rows, stops [].

floor: 8 seed rows, stops [].

## Warden proof on the same program head

Completionist seeds 1-3, --table=park --from-stage=5 --stages=5, through the
eight-core CPU queue with the specified 1500 s cap. The command exited 0.
All three reached the engaged anchored mind Warden and stalled at the beacon;
none recorded a break. This is the R11 deviation, with exact outcome rows
quoted in REPORT.md. No latch-cause claim is added beyond the brief's ruling.

| Seed | Outcome | Stage reached | Warden engage (s) | Warden break | Stall state |
| --- | --- | --- | --- | --- | --- |
| 1 | stalled | 5 | 141.62 | None | beacon |
| 2 | stalled | 5 | 142.82 | None | beacon |
| 3 | stalled | 5 | 141.82 | None | beacon |

## Verification and limits

The eight named smoke files pass, with import making nine runs, zero skipped
tests and zero missing verdicts. Compile checking against 6710ac0 selects three
scripts and reports zero bad. Lint reports zero findings. Two fresh shipped-tool
rebuilds reproduce all eight committed outputs byte for byte. The freshness
plant turns the stage test red on park_sha256, then restoration turns it green.
Receipts with the local-run prefix cover this program head.

These are program and headless game measurements. They do not establish human
feel, visual acceptance, listening acceptance or physical hardware support.

## Earlier inherited pass, archived

The following is retained as historical text. It describes the earlier c002df7
plus WIP candidate, not d6923b0. Its median-only anchor interpretation is obsolete:
the old Kest worst gap 44.1 m fails ruling 14, and floor-only pilot measures are
reported under ruling 13. The old R12 progress defect is fixed on the current head.

~~~~text
# Traversal bands: park_islands (stage 5, the Highdraft)

KD5's traversal table under ruling R8. One section per pass, newest first. The bands are PARK.md section 8's; stage 5's airborne band is 0.25 to 0.60. Seeds 1 to 8 per line, one process at a time, on the KD5 head (c002df7 plus this unit's stage files). KB9 is on this head: park rows are placed at runtime and the ride sensors fire (ride_chute, ride_bowl, ride_grapple_line, ride_drop, ride_hop and kicker_launch show on every line), so the first run's blocker (ParkRecipes.place had no caller in src/) is gone.

The progress band is not measured: traversal_line.gd reads the stage graph wrongly on this head (R12, KB7b), and every run prints that known out-of-bounds line. The ride-fact count is shown twice: the tool's own count, and the count without lift_fired, crater_ride and wall_crumbled (KB7b's narrowed set). Both are 6 on every line.

## Greybox pass, 2026-10-12 (commit c002df7+wip)

Eight seeds per line (1 to 8): `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=5 --pilot=<key>|--floor --seeds=1,2,3,4,5,6,7,8 --trace`. Each cell is median / worst seed, then pass or miss against PARK.md section 8, as the tool's band rows report them. The airborne band is stage 5's, 0.25 to 0.60.

| Band | Rule | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden | 8 of 8 seeds | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass |
| Time to Warden (s) | median 60.0 to 120.0 s; no seed over 150.0 s | 65.71 / 68.3 pass | 94.27 / 94.77 pass | 76.19 / 81.19 pass | 85.16 / 86.32 pass | 73.48 / 75.57 pass | 84.92 / 85.72 pass | 88.66 / 91.28 pass |
| Segment medians (s) | each segment's median 12.0 to 45.0 s | 19.15/23.17/21.38 / 25.09 pass | 24.32/36.28/33.55 / 36.28 pass | 22.19/23.35/31.44 / 31.43 pass | 22.13/31.16/31.95 / 32 pass | 24.73/17.95/30.66 / 30.66 pass | 23.17/31.97/29.95 / 31.97 pass | 24.63/33.96/29.78 / 33.96 pass |
| Flow share | median at least 0.7; no seed under 0.6 | 0.93 / 0.89 pass | 0.87 / 0.86 pass | 0.89 / 0.87 pass | 0.96 / 0.95 pass | 0.97 / 0.95 pass | 0.99 / 0.99 pass | 0.87 / 0.84 pass |
| Airborne share | 0.25 to 0.6 | 0.4 / - pass | 0.31 / - pass | 0.34 / - pass | 0.29 / - pass | 0.32 / - pass | 0.33 / - pass | 0.26 / - pass |
| Dead stops | 0 on every seed | 1 / 2 miss | 0 / 0 pass | 0 / 1 miss | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| Peak speed (m/s) | at least 26.6 m/s (the blazing tier) on every seed | 54.74 / 53.02 pass | 30.52 / 29.74 pass | 29.4 / 28.41 pass | 31.39 / 29.99 pass | 30.05 / 29.18 pass | 29.91 / 28.91 pass | 32.6 / 31.1 pass |
| Tier-3 time (s) | median at least 3.0 s at the blazing tier | 49.27 / - pass | 9.02 / - pass | 6.46 / - pass | 12.81 / - pass | 7.17 / - pass | 10.74 / - pass | 11.09 / - pass |
| Longest quiet (s) | at most 20.0 s | 6.36 / 7.51 pass | 5.97 / 6.64 pass | 3.22 / 3.33 pass | 6.12 / 6.57 pass | 3.32 / 3.33 pass | 3.3 / 3.84 pass | 4.78 / 7.98 pass |
| Max anchor gap (m) | at most 40.0 m | 35.1 / 36.6 pass | 29.65 / 33.1 pass | 35.5 / 44.1 pass | 17.05 / 23.4 pass | 17.15 / 21 pass | 31.7 / 38.6 pass | 37.2 / 40.4 pass |
| Distinct ride facts | at least 3 different ride facts | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass |
| Length ratio | 1.3 to 2.0 | 1.74 / - pass | 1.54 / - pass | 1.43 / - pass | 1.62 / - pass | 1.33 / - pass | 1.57 / - pass | 1.53 / - pass |
| floor | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops | n/a | n/a | n/a | n/a | n/a | n/a | 88.66 / 188.53 pass |
| Distinct lines (stage) | at least 3 across the six pilots | 5 (cannon, kest, rivet, sable, tarn) pass |
| Ride facts, KB7b set | at least 3 without lift_fired, crater_ride, wall_crumbled | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass |
| Progress | PARK.md section 8 | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) |

- Sable: verbs seen boost, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Rivet: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special, sprint.
- Kest: verbs seen blink, dash, jump, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Tarn: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Tally: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Cannon: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Floor: verbs seen kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop.

Misses: sable dead_stops; kest dead_stops.

Notes on this pass.

- Sable: one dead stop on 5 of 8 seeds at the Saddle. The ball reaches the last leg before the waymark at 40 to 45 m/s heading north-east, overshoots the waymark by about 40 m across the saddle step at z -350, and climbs back. A re-cut approach (a curve that meets the Saddle heading east) was tried on 8 seeds: four seeds still stopped once, seed 4 stuck at (-80, -433) and missed the Warden, so the shipped line keeps the pass-4 approach. Open.
- Kest: one dead stop on seeds 1 and 4, at (-62, -514) and (-111, -195). Open.
- The anchor gap band is judged on the median, which passes everywhere. Kest's worst seed is 44.1 m and the floor's 40.4 m.
- The machine load ran 30 to 166 during the pass. The bands come from fixed-fps simulation and are not timing-gated.
~~~~
