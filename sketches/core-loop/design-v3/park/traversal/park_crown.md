# Traversal: stage 6, the crown (`park_crown`)

The 13 bands of PARK.md section 8, per pilot and the floor line, from `tools/traversal_line.gd` (KB7) on the park table, stage 6, seeds 1 to 8, one process per line at a time. Each cell is the median, then the worst seed where the band names one, then pass or miss. The band numbers are PARK.md's; nothing here changes them (coordinator ruling R8).

## Greybox pass, 11 October 2026 (KD6)

Measured on `src/world/park/park_crown.json` sha256 `de386d8e6cc308381a5929934aef331561b7ce0b3b03790db36138278b80d1a1`, its committed bake and graph, base `5f2139b`. Lines from `tools/park_lines/park_crown.json`. Command per line: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=6 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>`, and `--floor` for the floor line (Rivet rolling, Rivet's median as the reference). The machine ran at load 40 to 90 of 32 threads; the measures are tick-counted, so load changes wall time only.

| band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached the Warden, 8 of 8 | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass |
| time_to_warden_s, median 60 to 120, no seed over 150 | 70.3 (89.0) pass | 71.7 (73.4) pass | 66.8 (68.9) pass | 81.1 (83.9) pass | 99.4 (103.3) pass | 79.4 (80.8) pass | 55.7 (58.2) see floor row |
| segment_s medians 12 to 45 | 12.0 / 26.8 / 30.2 pass | 16.4 / 38.0 / 17.2 pass | 16.0 / 19.1 / 32.3 pass | 15.0 / 36.3 / 29.8 pass | 16.6 / 37.5 / 45.2 MISS | 16.0 / 35.3 / 27.8 pass | 17.4 / 19.8 / 17.9 pass |
| flow_share, median at least 0.70, no seed under 0.60 | 0.98 (0.93) pass | 0.89 (0.87) pass | 0.93 (0.83) pass | 0.96 (0.92) pass | 0.85 (0.78) pass | 0.91 (0.90) pass | 0.90 (0.87) pass |
| airborne_share 0.25 to 0.60 (stage 6) | 0.36 pass | 0.30 pass | 0.35 pass | 0.29 pass | 0.34 pass | 0.39 pass | 0.17 (not judged on the floor) |
| dead stops 0 on every seed | 0 (0) pass | 0 (1) MISS | 0 (1) MISS | 0 (1) MISS | 0 (1) MISS | 0 (0) pass | 0 (1) MISS |
| peak_speed_mps at least 26.6 every seed | 56.2 (54.8) pass | 44.5 (44.1) pass | 40.2 (39.7) pass | 43.2 (38.6) pass | 44.3 (43.7) pass | 39.6 (38.3) pass | 43.8 (43.2) pass |
| tier3_s median at least 3 | 51.1 pass | 10.9 pass | 9.6 pass | 8.1 pass | 13.2 pass | 8.2 pass | 14.0 pass |
| quiet_max_s at most 20 | 6.7 (7.0) pass | 5.3 (5.6) pass | 4.2 (5.3) pass | 5.9 (6.2) pass | 6.6 (7.0) pass | 5.8 (6.9) pass | 4.2 (4.3) pass |
| max anchor gap at most 40 m | 36.4 (37.9) pass | 37.2 (39.4) pass | 42.0 (45.7) MISS | 33.4 (35.8) pass | 37.3 (38.6) pass | 37.1 (38.8) pass | 33.0 (37.0) pass |
| distinct ride facts at least 3 | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 (2) pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired | 2 |
| length / straight 1.3 to 2.0 | 1.91 pass | 1.31 pass | 1.34 pass | 1.59 pass | 1.74 pass | 1.42 pass | 1.13 |
| progress (graph) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |
| floor: reaches the Warden within 2.0 times Rivet's median (143.4 s), 0 dead stops | | | | | | | reaches in 55.7 s; 1 dead stop on 1 seed: MISS |

Distinct lines: six pilots ride six different pairs of fans (Sable west then Gauntlet, Rivet east then centre, Kest centre then masts, Tarn west then masts, Tally east then Gauntlet, the Cannon east then shelf); the band asks for 3.

**What the misses are.**

- Distinct ride facts. Every pilot's third ride fact is `lift_fired`; the others are `kicker_launch` and `ride_grapple_line`. On this head nothing places the park rows at runtime (no caller of `ParkRecipes.place` under `src/`), so no row's ride sensor exists and `ride_chute`, `ride_drop`, `ride_bowl` and `ride_ledge` cannot fire on any park stage. The reachable ride facts are the kicker launch (`map.kickers` plus a baked rise), a cable, a thermal (glide only) and the lift. When KB7b drops `lift_fired` (ruling R11) every pilot reads 2: a miss the park file cannot fix.
- Dead stops: one stop on one seed for Rivet (at [33, 4], the meander bend's wall by the slot), Kest (in the bowl at [-45, 451], the Warden's perch ring), Tarn ([-1, -615] on the butte crest), Tally ([145, 446], the bowl's east rim) and the floor ([4, -593]). The two crest stops are collisions with an enemy body on the drop-in (the trace shows a `CharacterBody3D` contact and the velocity reversing at 5.98 s), not ground.
- Kest's anchor gap: 42.0 m median against 40; the previous full run on the same lines read 38.8 (worst 57.2), so it sits on the edge of the band.
- Tally's third segment (the Gauntlet fan) is 45.2 s against 45: the line rides the tether into the Gauntlet gap, then the ground east of the shelf, because the runtime places no net deck.
- The floor line's time (55.7 s) is under the pilots' 60 s floor; the floor line is judged by its own band (reach within 2.0 times Rivet's median, no dead stops), which it misses only on the one stop.

Progress is not measured: `traversal_line.gd`'s `_construct_graph` discards the graph it reads (ruling R12), so `progress_m` is built from zeros and is not evidence.
