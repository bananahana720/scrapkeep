# Traversal: park_flume (stage 2)

KD2's table (ruling R8): the 13 bands of PARK.md section 8 for the six pilot lines and the floor line, 8 seeds each through `tools/traversal_line.gd` (KB7, `--table=park --stage=2 --seeds=1,2,3,4,5,6,7,8 --trace`, `--fixed-fps 90`). Each cell is median / worst seed, then pass or MISS. The lines are `tools/park_lines/park_flume.json`.

## Greybox pass, fix round, 2026-10-11

Measured on commit b2da61d (park file, bake and graph; the lines file unchanged since). Machine load average 20 to 71 during the runs (three runs started after the 10 minute load wait). The table that stood here before this round was withdrawn: it was not measured on the committed park and lines files.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached Warden (every seed) | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass |
| time to Warden s (median 60-120, none over 150) | 61.925 / 63.33 pass | 104.595 / 105.18 pass | 90.26 / 91.27 pass | 85.905 / 89.33 pass | 98.49 / 100.94 pass | 87.345 / 89.7 pass | 100.65 / 104.5 pass |
| segment s (each median 12-45) | [24.86, 15.96, 20.81] / 24.855 pass | [27.05, 43.57, 34.2] / 43.57 pass | [25.37, 39.13, 25.59] / 39.125 pass | [24.28, 32.76, 29.02] / 32.76 pass | [26.63, 33.29, 38.56] / 38.56 pass | [24.84, 39.06, 23.44] / 39.065 pass | [27.42, 36.5, 36.28] / 36.75 pass |
| flow share (median >= 0.70, none under 0.60) | 0.9177 / 0.895 pass | 0.7256 / 0.6902 pass | 0.6382 / 0.6024 MISS | 0.8782 / 0.843 pass | 0.6088 / 0.5746 MISS | 0.9296 / 0.9231 pass | 0.5976 / 0.5695 reported |
| airborne share (0.12-0.45) | 0.2309 / - pass | 0.13 / - pass | 0.1638 / - pass | 0.1639 / - pass | 0.1519 / - pass | 0.2609 / - pass | 0.1225 / - pass |
| dead stops (0 on every seed) | 0 / 1 MISS | 2 / 2 MISS | 0 / 1 MISS | 2.5 / 7 MISS | 3 / 5 MISS | 1 / 2 MISS | 1.5 / 2 MISS |
| peak m/s (>= 26.6 blazing on every seed) | 54.595 / 53.79 pass | 35.025 / 32.56 pass | 30.705 / 28.85 pass | 32.38 / 31.7 pass | 35.83 / 33.17 pass | 33.93 / 31.59 pass | 35.365 / 34.3 pass |
| tier-3 s (median >= 3) | 42.975 / - pass | 8.085 / - pass | 7.155 / - pass | 9 / - pass | 8.495 / - pass | 12.345 / - pass | 8.305 / - pass |
| quiet max s (<= 20) | 10.325 / 13.22 pass | 14.195 / 15.7 pass | 16.505 / 17.17 pass | 13.8 / 13.91 pass | 17.925 / 20.59 MISS | 18.475 / 19.6 pass | 16.4 / 17.24 pass |
| anchor gap m (<= 40) | 51.65 / 94.7 MISS | 25.65 / 34.7 pass | 61.25 / 68.5 MISS | 32 / 34.5 pass | 22.4 / 24.5 pass | 218.15 / 233.8 MISS | 31.4 / 33.7 pass |
| distinct ride facts (>= 3) | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 4 pass | 5 / 5 pass |
| length ratio (1.3-2.0) | 1.47 / - pass | 1.44 / - pass | 1.34 / - pass | 1.375 / - pass | 1.35 / - pass | 1.44 / - pass | 1.355 / - pass |
| progress m/s | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

**Progress** is not measured: `traversal_line.gd`'s `_construct_graph` drops the stage graph on this head (ruling R12, fixed by KB7b).

**Ride facts.** Every park row with a recipe is built in play with its collider and ride sensor (`terrain.gd:218-220`, `ParkRecipes.build_placed`), so the anchor gap and distinct ride facts are row bands on this head. `lift_fired`, `crater_ride` and `wall_crumbled` drop out at KB7b (R11); the per-line fact lists below show which facts each pass rests on. Without `lift_fired` every line still counts at least 4 facts, so distinct ride facts passes after KB7b.

**Distinct lines.** 4 mutually distinct lines (Sable, Rivet, Tally, the Cannon), from the seed-1 traces (shared share under 0.5 both ways); the band asks for 3.

**Row misses open at the timebox** (fixed by reworking rows in a later round, never the band):

- Dead stops, clustered at fixed sites: the hollow's south end near [-160, 145] (Tarn on every seed, the floor line), the rim bend's foot near [121, 1] (Rivet), the bench pads near [-45, 413] and [39, 408] (Tally), the siphon's east side near [17, 223] (the Cannon, every seed), the butte gap's mouth [-255, -263] (Sable, one seed) and [90, 33] (Kest, one seed).
- Flow share: Kest (median 0.638), Tally (0.609) and the floor line (0.598) under 0.70; these are the lines with the stall sites above.
- Anchor gap: Sable (median 51.7 m, the flume reaches between the weir and the gap), Kest (61.3 m, the bluff run) and the Cannon (218 m, the bend zip crossing, where the cable alone carries the line) over 40 m.
- Floor rule: the time holds (worst 209.19 s against 2.0 times Rivet's 104.6 s median), the dead stops (median 1.5) miss.

```
Floor rule (`floor`, reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops): median 100.65, worst 209.19, MISS

sable seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-255.2, -262.9], 'time': 23.05}]; ride facts ['boost', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
rivet seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [122.6, 1.2], 'time': 54.17}, {'at': [-467.5, -460.1], 'time': 14.01}, {'at': [120.6, 1.3], 'time': 56.64}, {'at': [123.9, 1.3], 'time': 55.9}, {'at': [123.0, 0.2], 'time': 56.45}, {'at': [120.6, 1.3], 'time': 55.91}, {'at': [118.8, 0.2], 'time': 56.46}, {'at': [122.5, 1.3], 'time': 55.98}, {'at': [123.5, 1.3], 'time': 56.14}, {'at': [121.6, 1.3], 'time': 55.64}, {'at': [120.5, 0.2], 'time': 56.19}, {'at': [121.5, 1.3], 'time': 55.31}, {'at': [120.2, 0.4], 'time': 55.83}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special', 'sprint']
kest seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [89.9, 32.6], 'time': 53.16}]; ride facts ['blink', 'dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'special']
tarn seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-160.2, 143.4], 'time': 46.42}, {'at': [-160.2, 143.4], 'time': 47.1}, {'at': [-160.5, 145.0], 'time': 50.22}, {'at': [-163.0, 144.9], 'time': 51.11}, {'at': [-160.5, 145.7], 'time': 46.0}, {'at': [-160.3, 146.2], 'time': 46.68}, {'at': [-160.2, 143.6], 'time': 46.02}, {'at': [-160.3, 143.5], 'time': 46.77}, {'at': [-160.7, 144.8], 'time': 50.51}, {'at': [-160.5, 148.2], 'time': 51.4}, {'at': [-115.8, 154.5], 'time': 54.59}, {'at': [-160.4, 145.1], 'time': 46.26}, {'at': [-161.5, 144.1], 'time': 46.89}, {'at': [-160.3, 143.9], 'time': 47.29}, {'at': [-160.3, 144.0], 'time': 48.2}, {'at': [-160.5, 145.1], 'time': 50.45}, {'at': [-162.2, 145.5], 'time': 51.31}, {'at': [-160.6, 147.0], 'time': 52.51}, {'at': [-160.3, 144.3], 'time': 46.07}, {'at': [-159.4, 142.4], 'time': 47.03}, {'at': [-160.5, 146.4], 'time': 46.32}, {'at': [-158.4, 148.0], 'time': 47.07}, {'at': [-160.3, 144.3], 'time': 46.34}, {'at': [-159.7, 142.3], 'time': 47.3}, {'at': [-160.3, 144.2], 'time': 46.19}, {'at': [-160.3, 143.1], 'time': 47.07}, {'at': [-160.7, 144.8], 'time': 50.57}]; ride facts ['dash', 'jump', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
tally seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-44.4, 414.1], 'time': 78.59}, {'at': [-42.4, 415.5], 'time': 79.24}, {'at': [39.4, 408.1], 'time': 85.99}, {'at': [-46.0, 412.5], 'time': 79.11}, {'at': [-44.5, 412.4], 'time': 79.75}, {'at': [-42.6, 415.7], 'time': 81.02}, {'at': [39.3, 407.9], 'time': 87.15}, {'at': [-46.6, 412.2], 'time': 78.91}, {'at': [-46.5, 413.5], 'time': 79.44}, {'at': [39.4, 409.8], 'time': 86.68}, {'at': [-46.4, 412.4], 'time': 80.53}, {'at': [-42.8, 414.7], 'time': 81.67}, {'at': [39.3, 407.2], 'time': 88.14}, {'at': [-46.5, 412.4], 'time': 78.28}, {'at': [-42.9, 414.9], 'time': 79.32}, {'at': [-46.7, 412.0], 'time': 79.57}, {'at': [-47.5, 411.6], 'time': 80.1}, {'at': [-46.8, 410.4], 'time': 80.71}, {'at': [39.3, 406.9], 'time': 87.76}, {'at': [45.5, 415.6], 'time': 89.07}, {'at': [-43.9, 415.1], 'time': 77.73}, {'at': [-43.4, 414.5], 'time': 77.84}, {'at': [39.5, 409.6], 'time': 85.46}, {'at': [-46.7, 412.1], 'time': 77.79}, {'at': [-44.4, 415.1], 'time': 80.71}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
cannon seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [17.6, 222.7], 'time': 66.84}, {'at': [18.1, 221.2], 'time': 67.05}, {'at': [17.1, 223.1], 'time': 67.76}, {'at': [17.1, 223.2], 'time': 68.99}, {'at': [18.1, 222.4], 'time': 68.15}, {'at': [16.1, 224.4], 'time': 70.08}, {'at': [16.5, 223.6], 'time': 68.05}, {'at': [17.4, 222.7], 'time': 69.06}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
floor seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-160.6, 146.8], 'time': 55.09}, {'at': [-220.1, 105.1], 'time': 49.39}, {'at': [-159.8, 142.5], 'time': 55.58}, {'at': [-160.3, 144.0], 'time': 54.17}, {'at': [-160.4, 144.5], 'time': 54.99}, {'at': [-160.2, 143.4], 'time': 53.68}, {'at': [-159.7, 142.4], 'time': 54.36}, {'at': [-160.4, 144.3], 'time': 53.64}, {'at': [-160.1, 142.8], 'time': 54.52}, {'at': [-160.3, 143.5], 'time': 54.33}, {'at': [-160.2, 143.3], 'time': 53.77}, {'at': [-160.3, 144.1], 'time': 54.09}]; ride facts ['kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line']

Shared share (ticks of row line within 8 m of column line), seed 1:
| | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.00 | 0.25 | 0.07 | 0.32 | 0.21 | 0.08 |
| rivet | 0.27 | 1.00 | 0.65 | 0.58 | 0.36 | 0.41 |
| kest | 0.06 | 0.71 | 1.00 | 0.31 | 0.31 | 0.45 |
| tarn | 0.37 | 0.58 | 0.30 | 1.00 | 0.63 | 0.32 |
| tally | 0.27 | 0.39 | 0.29 | 0.65 | 1.00 | 0.33 |
| cannon | 0.08 | 0.47 | 0.45 | 0.35 | 0.34 | 1.00 |

largest set of mutually distinct lines: 4 ['sable', 'rivet', 'tally', 'cannon']
```

## Continuation baseline-alignment, 2026-10-12

Source head `01afdeb0ebde5da40013d049de1728fa13132c9c`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/baseline-alignment`. Seeds per line: {"sable": 8, "rivet": 8, "kest": 8, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 62.07 / 64.05 pass | 104.235 / 105.18 pass | 90.26 / 91.27 pass | 88.12 / 88.12 pass | 97.92 / 97.92 pass | 88.63 / 88.63 pass | 101 / 101 pass |
| Segments s, medians 12–45 | [24.815, 15.745, 20.62] / 25.63 pass | [27.045, 43.57, 34.205] / 43.9 pass | [25.365, 39.125, 25.59] / 40.46 pass | [24.32, 34.6, 29.19] / 34.6 pass | [25.94, 33.44, 38.53] / 38.53 pass | [26.09, 39.09, 23.43] / 39.09 pass | [27.43, 37, 36.56] / 37 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9178 / 0.8935 pass | 0.7256 / 0.6937 pass | 0.6381 / 0.6024 MISS | 0.8774 / 0.8774 pass | 0.6128 / 0.6128 MISS | 0.8946 / 0.8946 pass | 0.5914 / 0.5914 reported |
| Airborne, median .12–.45 | 0.2348 / [0.2253, 0.2631] pass | 0.1285 / [0.122, 0.141] pass | 0.1638 / [0.1564, 0.1685] pass | 0.1651 / [0.1651, 0.1651] pass | 0.1463 / [0.1463, 0.1463] pass | 0.1913 / [0.1913, 0.1913] pass | 0.1217 / [0.1217, 0.1217] pass |
| Dead stops, every seed 0 | 0 / 1 MISS | 2 / 2 MISS | 0 / 1 MISS | 4 / 4 MISS | 3 / 3 MISS | 2 / 2 MISS | 1 / 1 MISS |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.835, 43.52] / [51.87, 40.46] pass | [35.025, 8.055] / [32.56, 7.69] pass | [30.705, 7.155] / [28.85, 4.79] pass | [32.41, 8.97] / [32.41, 8.97] pass | [35.77, 8.1] / [35.77, 8.1] pass | [33.08, 12.03] / [33.08, 12.03] pass | [35.21, 7.86] / [35.21, 7.86] pass |
| Quiet s, worst ≤20 | 10.285 / 13.2 pass | 14.195 / 15.7 pass | 16.505 / 17.17 pass | 13.81 / 13.81 pass | 17.16 / 17.16 pass | 20.14 / 20.14 MISS | 17.11 / 17.11 pass |
| Anchor gap m, worst ≤40 | 49.55 / 81.3 MISS | 25.75 / 34.7 pass | 61.25 / 68.5 MISS | 34.5 / 34.5 pass | 24.5 / 24.5 pass | 174.8 / 174.8 MISS | 29.6 / 29.6 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.475 / [1.45, 1.5] pass | 1.44 / [1.44, 1.45] pass | 1.34 / [1.33, 1.35] pass | 1.38 / [1.38, 1.38] pass | 1.35 / [1.35, 1.35] pass | 1.42 / [1.42, 1.42] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 101 / max 101; cap 208.47 MISS |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.252 | 0.081 | 0.304 | 0.207 | 0.087 |
| rivet | 0.276 | 1.000 | 0.647 | 0.578 | 0.364 | 0.413 |
| kest | 0.064 | 0.706 | 1.000 | 0.309 | 0.309 | 0.444 |
| tarn | 0.359 | 0.582 | 0.301 | 1.000 | 0.632 | 0.326 |
| tally | 0.272 | 0.392 | 0.294 | 0.652 | 1.000 | 0.318 |
| cannon | 0.075 | 0.468 | 0.445 | 0.349 | 0.339 | 1.000 |

Dead-stop sites by seed:

- sable seed 2: [{"at": [-156.1, -425.7], "time": 15.28}]
- rivet seed 1: [{"at": [122.6, 1.2], "time": 54.17}]
- rivet seed 2: [{"at": [-467.5, -460.1], "time": 14.01}, {"at": [120.6, 1.3], "time": 56.64}]
- rivet seed 3: [{"at": [123.9, 1.3], "time": 55.9}, {"at": [123.0, 0.2], "time": 56.45}]
- rivet seed 4: [{"at": [120.6, 1.3], "time": 55.91}, {"at": [118.8, 0.2], "time": 56.46}]
- rivet seed 5: [{"at": [122.5, 1.3], "time": 55.98}]
- rivet seed 6: [{"at": [122.2, 1.3], "time": 56.12}]
- rivet seed 7: [{"at": [121.6, 1.3], "time": 55.64}, {"at": [120.5, 0.2], "time": 56.19}]
- rivet seed 8: [{"at": [121.5, 1.3], "time": 55.31}, {"at": [120.2, 0.4], "time": 55.83}]
- kest seed 5: [{"at": [89.9, 32.6], "time": 53.16}]
- tarn seed 1: [{"at": [-160.2, 143.4], "time": 46.42}, {"at": [-160.2, 143.4], "time": 47.1}, {"at": [-160.5, 145.0], "time": 50.22}, {"at": [-163.0, 144.9], "time": 51.11}]
- tally seed 1: [{"at": [-44.4, 414.1], "time": 78.59}, {"at": [-42.4, 415.5], "time": 79.24}, {"at": [39.4, 408.1], "time": 85.99}]
- cannon seed 1: [{"at": [18.7, 221.8], "time": 70.05}, {"at": [19.0, 221.1], "time": 70.16}]
- floor seed 1: [{"at": [-160.6, 146.8], "time": 55.09}]

Progress from the fresh stage graph, reported:

- sable: median 22.035 m/s, worst 21.24 m/s.
- rivet: median 13.2 m/s, worst 13.07 m/s.
- kest: median 15.265 m/s, worst 15.13 m/s.
- tarn: median 15.6 m/s, worst 15.6 m/s.
- tally: median 14.03 m/s, worst 14.03 m/s.
- cannon: median 15.12 m/s, worst 15.12 m/s.
- floor: median 13.61 m/s, worst 13.61 m/s.

## Continuation rework1-probe, 2026-10-12

Source head `60f1a3fa882eeea84571e10528379b908440dace`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/rework1-probe`. Seeds per line: {"sable": 2, "rivet": 1, "kest": 1, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 2 / 2 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 64.785 / 65.4 pass | 107.47 / 107.47 pass | 95.01 / 95.01 pass | 80.69 / 80.69 pass | 94.62 / 94.62 pass | 94.71 / 94.71 pass | 100.72 / 100.72 pass |
| Segments s, medians 12–45 | [27.01, 18.24, 19.525] / 27.02 pass | [26.89, 46.33, 34.23] / 46.33 MISS | [26.2, 41.92, 26.88] / 41.92 pass | [23.48, 28.24, 28.96] / 28.96 pass | [26.48, 33.54, 34.59] / 34.59 pass | [25.9, 42.86, 25.94] / 42.86 pass | [27.95, 36, 36.77] / 36.77 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.8757 / 0.868 pass | 0.644 / 0.644 MISS | 0.5292 / 0.5292 MISS | 0.9456 / 0.9456 pass | 0.7364 / 0.7364 pass | 0.8189 / 0.8189 pass | 0.5828 / 0.5828 reported |
| Airborne, median .12–.45 | 0.236 / [0.2241, 0.2479] pass | 0.1181 / [0.1181, 0.1181] MISS | 0.1668 / [0.1668, 0.1668] pass | 0.169 / [0.169, 0.169] pass | 0.139 / [0.139, 0.139] pass | 0.2564 / [0.2564, 0.2564] pass | 0.1237 / [0.1237, 0.1237] pass |
| Dead stops, every seed 0 | 1.5 / 2 MISS | 4 / 4 MISS | 3 / 3 MISS | 1 / 1 MISS | 1 / 1 MISS | 7 / 7 MISS | 1 / 1 MISS |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.77, 39.005] / [54.52, 38.18] pass | [36.26, 7.77] / [36.26, 7.77] pass | [30.98, 6.92] / [30.98, 6.92] pass | [33.99, 9.06] / [33.99, 9.06] pass | [35.77, 8.28] / [35.77, 8.28] pass | [31.19, 12.7] / [31.19, 12.7] pass | [35.18, 8.68] / [35.18, 8.68] pass |
| Quiet s, worst ≤20 | 12.92 / 13.22 pass | 11.39 / 11.39 pass | 17.64 / 17.64 pass | 13.64 / 13.64 pass | 14.07 / 14.07 pass | 16.79 / 16.79 pass | 16.71 / 16.71 pass |
| Anchor gap m, worst ≤40 | 47.65 / 59.5 MISS | 53 / 53 MISS | 34.8 / 34.8 pass | 32.1 / 32.1 pass | 70.2 / 70.2 MISS | 218.5 / 218.5 MISS | 29.6 / 29.6 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.445 / [1.43, 1.46] pass | 1.46 / [1.46, 1.46] pass | 1.35 / [1.35, 1.35] pass | 1.35 / [1.35, 1.35] pass | 1.34 / [1.34, 1.34] pass | 1.47 / [1.47, 1.47] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 100.72 / max 100.72; cap 214.94 MISS |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.286 | 0.088 | 0.384 | 0.251 | 0.093 |
| rivet | 0.332 | 1.000 | 0.647 | 0.580 | 0.379 | 0.449 |
| kest | 0.074 | 0.699 | 1.000 | 0.317 | 0.313 | 0.470 |
| tarn | 0.407 | 0.646 | 0.332 | 1.000 | 0.685 | 0.341 |
| tally | 0.256 | 0.421 | 0.314 | 0.665 | 1.000 | 0.335 |
| cannon | 0.109 | 0.490 | 0.467 | 0.334 | 0.331 | 1.000 |

Dead-stop sites by seed:

- sable seed 1: [{"at": [-96.7, 159.0], "time": 42.48}]
- sable seed 2: [{"at": [-212.1, -528.1], "time": 10.77}, {"at": [-189.3, -513.3], "time": 12.17}]
- rivet seed 1: [{"at": [-280.6, -230.6], "time": 27.45}, {"at": [-248.6, -224.6], "time": 32.35}, {"at": [82.8, -44.5], "time": 54.45}, {"at": [83.3, -45.1], "time": 55.46}]
- kest seed 1: [{"at": [-281.3, -229.3], "time": 26.8}, {"at": [-248.4, -225.0], "time": 31.13}, {"at": [86.9, -36.0], "time": 52.69}]
- tarn seed 1: [{"at": [-282.0, -228.1], "time": 24.13}]
- tally seed 1: [{"at": [-281.9, -228.1], "time": 27.14}]
- cannon seed 1: [{"at": [-280.5, -230.8], "time": 26.51}, {"at": [-279.6, -232.5], "time": 27.21}, {"at": [-275.8, -240.3], "time": 28.45}, {"at": [-247.8, -226.2], "time": 31.47}, {"at": [68.0, 260.4], "time": 77.11}, {"at": [86.9, 278.5], "time": 79.7}, {"at": [86.0, 279.5], "time": 80.41}]
- floor seed 1: [{"at": [-280.8, -230.4], "time": 28.49}]

Progress from the fresh stage graph, reported:

- sable: median 21.13 m/s, worst 21.06 m/s.
- rivet: median 12.78 m/s, worst 12.78 m/s.
- kest: median 14.5 m/s, worst 14.5 m/s.
- tarn: median 17.03 m/s, worst 17.03 m/s.
- tally: median 14.56 m/s, worst 14.56 m/s.
- cannon: median 14.14 m/s, worst 14.14 m/s.
- floor: median 13.67 m/s, worst 13.67 m/s.

## Continuation rework2-probe, 2026-10-12

Source head `901f99b72b0f6a90e03d815da645e9de1480b7a4`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/rework2-probe`. Seeds per line: {"sable": 2, "rivet": 1, "kest": 1, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 2 / 2 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 57.765 / 57.78 MISS | 101.44 / 101.44 pass | 92.43 / 92.43 pass | 80.48 / 80.48 pass | 94.55 / 94.55 pass | 86.6 / 86.6 pass | 99.3 / 99.3 pass |
| Segments s, medians 12–45 | [22.04, 14.42, 21.29] / 22.69 pass | [26.89, 39.9, 34.63] / 39.9 pass | [26.2, 39.17, 27.06] / 39.17 pass | [23.48, 27.6, 29.39] / 29.39 pass | [26.48, 33.24, 34.81] / 34.81 pass | [25.9, 39.13, 21.56] / 39.13 pass | [27.95, 35.46, 35.89] / 35.89 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9343 / 0.9204 pass | 0.7515 / 0.7515 pass | 0.5983 / 0.5983 MISS | 0.9678 / 0.9678 pass | 0.6845 / 0.6845 MISS | 0.9233 / 0.9233 pass | 0.6025 / 0.6025 reported |
| Airborne, median .12–.45 | 0.2777 / [0.2686, 0.2868] pass | 0.131 / [0.131, 0.131] pass | 0.1606 / [0.1606, 0.1606] pass | 0.1734 / [0.1734, 0.1734] pass | 0.136 / [0.136, 0.136] pass | 0.2711 / [0.2711, 0.2711] pass | 0.1185 / [0.1185, 0.1185] MISS |
| Dead stops, every seed 0 | 0.5 / 1 MISS | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.59, 45.175] / [54.39, 44.14] pass | [36.26, 7.87] / [36.26, 7.87] pass | [30.98, 6.99] / [30.98, 6.99] pass | [33.99, 9.27] / [33.99, 9.27] pass | [35.77, 8.44] / [35.77, 8.44] pass | [31.19, 12.76] / [31.19, 12.76] pass | [35.18, 8.56] / [35.18, 8.56] pass |
| Quiet s, worst ≤20 | 10.075 / 11.46 pass | 11.86 / 11.86 pass | 16.67 / 16.67 pass | 13.81 / 13.81 pass | 14.5 / 14.5 pass | 17.78 / 17.78 pass | 16.62 / 16.62 pass |
| Anchor gap m, worst ≤40 | 33.35 / 38.2 pass | 41 / 41 MISS | 64.7 / 64.7 MISS | 31.5 / 31.5 pass | 22 / 22 pass | 219.2 / 219.2 MISS | 31.4 / 31.4 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.455 / [1.42, 1.49] pass | 1.43 / [1.43, 1.43] pass | 1.34 / [1.34, 1.34] pass | 1.36 / [1.36, 1.36] pass | 1.34 / [1.34, 1.34] pass | 1.44 / [1.44, 1.44] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 99.3 / max 99.3; cap 202.88 pass |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.311 | 0.084 | 0.443 | 0.265 | 0.088 |
| rivet | 0.324 | 1.000 | 0.651 | 0.606 | 0.377 | 0.425 |
| kest | 0.062 | 0.704 | 1.000 | 0.321 | 0.325 | 0.468 |
| tarn | 0.440 | 0.642 | 0.326 | 1.000 | 0.685 | 0.340 |
| tally | 0.267 | 0.399 | 0.320 | 0.668 | 1.000 | 0.337 |
| cannon | 0.084 | 0.476 | 0.469 | 0.354 | 0.353 | 1.000 |

Dead-stop sites by seed:

- sable seed 2: [{"at": [29.6, 213.1], "time": 38.62}]

Progress from the fresh stage graph, reported:

- sable: median 23.805 m/s, worst 23.77 m/s.
- rivet: median 13.54 m/s, worst 13.54 m/s.
- kest: median 14.9 m/s, worst 14.9 m/s.
- tarn: median 16.9 m/s, worst 16.9 m/s.
- tally: median 14.57 m/s, worst 14.57 m/s.
- cannon: median 15.47 m/s, worst 15.47 m/s.
- floor: median 13.84 m/s, worst 13.84 m/s.

## Continuation carry-population, 2026-10-12

Source head `53283b50be494f9a2409b0499f2b06d283f0eeed`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r2/carry-population`. Seeds per line: {"sable": 8, "rivet": 8, "kest": 8, "tarn": 0, "tally": 0, "cannon": 0, "floor": 0}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor measures are reported except its own time-and-stop rule.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | pending | pending | pending |
| Time s, median 60–120; worst ≤150 | 62.685 / 63.45 pass | 96.065 / 99.57 pass | 86.19 / 93.21 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Segments s, medians 12–45 | [21.63, 20.7, 19.695] / 22.36 pass | [27.55, 35.49, 32.85] / 37.29 pass | [25.665, 34.795, 25.27] / 38 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9355 / 0.9315 pass | 0.7519 / 0.7215 pass | 0.7005 / 0.5394 MISS | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.246 / [0.2365, 0.2743] pass | 0.1217 / [0.1139, 0.1299] pass | 0.1573 / [0.1424, 0.1672] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Dead stops, every seed 0 | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | pending | pending | pending | pending |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.915, 46.715] / [54.6, 45.23] pass | [36.025, 8.225] / [32.01, 7.59] pass | [31.515, 6.785] / [31.19, 4.04] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.78 / 8.04 pass | 11.7 / 12.19 pass | 17.53 / 19.3 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 28.2 / 32.2 pass | 27.9 / 30.1 pass | 22.35 / 50.3 MISS | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Ride facts, at least 3 | 5 / 4 pass | 5 / 5 pass | 4 / 4 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.49, 1.52] pass | 1.43 / [1.43, 1.43] pass | 1.33 / [1.32, 1.35] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | pending | pending | pending | pending |
| Distinct lines, at least 3 | 0 / stage not measured | 0 / stage not measured | 0 / stage not measured | pending | pending | pending | pending, reported, pilot band, not the floor's |

Distinct-line proof: not measured on these inputs.


Dead-stop sites by seed:


Progress from the fresh stage graph, reported:

- sable: median 21.995 m/s, worst 21.59 m/s.
- rivet: median 14.42 m/s, worst 13.9 m/s.
- kest: median 16.095 m/s, worst 14.88 m/s.

**Round-2 greybox verdict: FAIL, timebox closed.** The stock untraced final population completed 30 of 56 runs: Sable, Rivet and Kest eight each, Tarn six, and Tally, Cannon and floor unrun. All completed runs recorded zero dead stops. Kest seed 2 flow is 0.5394 against the per-seed minimum 0.60; seed 3 anchor gap is 50.3 m against 40 m. The current distinct-line proof and win proof remain unrun. The dressed prerequisite was not met. Partial Tarn console results remain diagnostic, without an eight-seed summary. See `/tmp/claude-1000/w13-sol/kd2-flume-r2/REPORT.md` and `carry-population/inputs.json` for the version-bound evidence.

The cutoff was 15:51:38 UTC; captured session 47094 stopped at 15:51:45 UTC with exit 130 through the tool call. No matching runner or Godot process remained. Gameplay hashes stayed identical; the closing commit changes only these evidence pages.
