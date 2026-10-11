# Traversal: park_flume (stage 2)

KD2's table (ruling R8): the 13 bands of PARK.md section 8 for the six pilot lines and the floor line, 8 seeds each through `tools/traversal_line.gd` (KB7, `--table=park --stage=2 --seeds=1,2,3,4,5,6,7,8`, `--fixed-fps 90`). Each cell is median / worst seed, then pass or MISS. The lines are `tools/park_lines/park_flume.json`.

## Greybox pass, 2026-10-11

Park file `src/world/park/park_flume.json` with its committed bake and graph (`assets/park/park_flume/`). Machine load average 34 to 61 during the runs.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached Warden (8 of 8) | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass |
| time to Warden s (median 60-120, none over 150) | 62.25 / 64.46 pass | 90.77 / 94.85 pass | 84.845 / 88.45 pass | 89.82 / 91.07 pass | 98.115 / 100.01 pass | 96.975 / 98.68 pass | 91.335 / 96.82 pass |
| segment s (medians 12-45) | [26.42, 14.22, 22.04] / 26.42 pass | [31.6, 28.23, 30.62] / 31.87 pass | [28.68, 26.4, 30.04] / 30.035 pass | [37.45, 24.29, 27.71] / 37.455 pass | [31.79, 37.28, 28.84] / 37.275 pass | [29.43, 39.9, 27.93] / 39.9 pass | [32.03, 28.48, 31] / 32.25 pass |
| flow share (median >= 0.70, none under 0.60) | 0.949 / 0.943 pass | 0.739 / 0.668 pass | 0.686 / 0.576 MISS | 0.945 / 0.931 pass | 0.732 / 0.693 pass | 0.88 / 0.867 pass | 0.684 / 0.617 MISS |
| airborne share (0.12-0.45) | 0.265 / None pass | 0.171 / None pass | 0.192 / None pass | 0.201 / None pass | 0.162 / None pass | 0.217 / None pass | 0.17 / None pass |
| dead stops (0) | 0 / 0 pass | 0 / 0 pass | 0 / 1 MISS | 0 / 0 pass | 0 / 0 pass | 0 / 1 MISS | 0 / 0 pass |
| peak m/s (>= blazing on every seed) | 51.705 / 51.39 pass | 32.48 / 31.06 pass | 31.57 / 30 pass | 30 / 24.44 MISS | 31.445 / 31.27 pass | 30.245 / 29.59 pass | 32.14 / 30 pass |
| tier-3 s (median >= 3) | 49.3 / None pass | 10.42 / None pass | 10.385 / None pass | 10.185 / None pass | 10.305 / None pass | 8.405 / None pass | 10.485 / None pass |
| quiet max s (<= 20) | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass |
| anchor gap m (<= 40) | 599.55 / 641.9 MISS | 548.6 / 555.1 MISS | 545.25 / 561 MISS | 547.4 / 551 MISS | 679.9 / 685.3 MISS | 312.95 / 322.1 MISS | 545.85 / 551.3 MISS |
| distinct ride facts (>= 3) | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 2 / 1 MISS | 1 / 1 MISS |
| length ratio (1.3-2.0) | 1.64 / None pass | 1.37 / None pass | 1.4 / None pass | 1.56 / None pass | 1.475 / None pass | 1.55 / None pass | 1.37 / None pass |
| progress m/s | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

Floor band `floor` (reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops): median 91.335, worst 181.54, pass

**Progress** is not measured: `traversal_line.gd`'s `_construct_graph` drops the stage graph on this head (ruling R12, fixed by KB7b), so every progress number is built from zeros and is not read here.

**Two bands miss on every line: the anchor gap and distinct ride facts.** Neither is a row problem a re-cut can fix on this head. `ParkRecipes.place` has no caller, so no park row is built in play: the bake stamps the rows' heights, the contraptions and the Warden reach the stage, and nothing else. The rows' ride sensors (`ride_chute`, `ride_drop`, `ride_grapple_line` on the flume reaches) never fire and their faces are not there to hook, so the only countable ride facts left are a cable (`ride_grapple_line`, the zips) and a thermal (gliders), and the anchor gap reads only the terrain's steep faces. Both bands are re-measured when the rows are placed in play (follow-up). The fix is not a band change (PARK.md section 8 owns the numbers).

**The one ride fact counted on most lines is `lift_fired`** (the hollow lift), which KB7b drops from the park set; after KB7b only the Cannon keeps one (`ride_grapple_line`, the bend zip).

**Row misses left open at the timebox** (greybox, not reworked):

- Kest and the Cannon each stop dead once, on one seed each (Kest seed 6, the Cannon seeds 4 and 6), at about [-491, -545] some 8.5 s after the drop-in: the shared opening waypoint [-500, -550] at the mesa ramp's foot. Rivet and Tally ride the same opening without a stop.
- Kest's flow share: median 0.686, worst 0.576 (band 0.70 median, 0.60 worst). The floor line's flow share: median 0.684, worst 0.617.
- Tarn's peak speed: median 30.0, worst seed 24.44 under blazing (26.6).
- The floor line's worst seed takes 181.5 s against Rivet's median 90.8 s times 2.0 (181.5): inside by 0.04 s.
