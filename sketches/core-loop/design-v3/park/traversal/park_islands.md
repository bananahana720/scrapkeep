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
