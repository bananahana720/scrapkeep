# Traversal: stage 6, the crown (`park_crown`)

## Round 3, 12 October 2026

BLOCKED. Automated native evidence level 4. Geometry measurement head `b6b5cdb`. Completed final eight-seed batches: 6/7. Pending cells are FIX.

The candidate carries TRAV-DET, KE6, KF8-WIRE and REWARD-PARK from the clean merge `103facb49985d8f717198e3decef9ed30ab797aa` of `d8e5077`. The merged traversal tool still fails repeatability with equal head and recorded input hashes. Kest seed 1 records one stop in the batch and none in either solo mode. Tarn seed 1's trace agrees with the batch, while its untraced solo differs by 1.47 s and other core metrics. `baseline-repeatability.json` and `runtime-equality.json` retain the comparisons and source identity. Ruling 24 blocks traversal tuning and stage admission. No threshold, pilot line, kit, Warden row or shared tool was changed.

Evidence folder: `/home/andrew/scratch/w13/sol/kd6-crown-r3`. Every current measured table below comes from this round's final runs. Numeric IN cells remain unqualified while repeatability is unresolved.

Cells are independently recomputed medians, with the worst seed where the rule uses it. IN means numerically inside the band; it does not qualify admission while repeatability is blocked.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8; IN | 8; IN | 8; IN | 8; IN | 8; IN | 8; IN | pending; FIX |
| time_to_warden_s | 57.4 (59.57); MISS | 69.3 (69.8); IN | 64.63 (65.05); IN | 78.81 (79.26); IN | 77.03 (78.11); IN | 76.01 (77.4); IN | pending; FIX |
| segment_s | 17.71 / 17.74 / 21.93; IN | 16.57 / 39.12 / 13.6; IN | 16.28 / 19.7 / 28.805; IN | 15.01 / 37.035 / 26.59; IN | 16.8 / 38.41 / 21.81; IN | 15.81 / 38.41 / 22.445; IN | pending; FIX |
| flow_share | 0.9642 (0.9552); IN | 0.8805 (0.8686); IN | 0.8713 (0.8639); IN | 0.94795 (0.9447); IN | 0.8201 (0.778); IN | 0.92225 (0.8959); IN | pending; FIX |
| airborne_share | 0.2635; IN | 0.3087; IN | 0.25495; IN | 0.2205; MISS | 0.3754; IN | 0.3802; IN | pending; FIX |
| dead_stops | 0 (0); IN | 0 (0); IN | 0 (0); IN | 0 (0); IN | 0 (1); MISS | 0 (0); IN | pending; FIX |
| peak_speed_mps | 54.85 (53.96); IN | 43.72 (43.72); IN | 39.055 (39.05); IN | 42.35 (41.9); IN | 44.62 (43.75); IN | 42.75 (37.94); IN | pending; FIX |
| tier3_s | 37.1; IN | 11.53; IN | 7.92; IN | 8.43; IN | 8.51; IN | 8.67; IN | pending; FIX |
| quiet_max_s | 7.69 (7.69); IN | 6.43 (6.43); IN | 4.52 (5.39); IN | 5.505 (5.52); IN | 5.8 (6.27); IN | 10.66 (10.76); IN | pending; FIX |
| max_anchor_gap_m | 44.7 (44.7); MISS | 35.8 (37.9); IN | 25 (31.2); IN | 23.75 (23.8); IN | 36.8 (39); IN | 35.9 (37); IN | pending; FIX |
| distinct_verbs | 5 (5); IN | 5 (5); IN | 4 (4); IN | 4 (4); IN | 5 (5); IN | 5 (5); IN | pending; FIX |
| length_ratio | 1.48; IN | 1.25; MISS | 1.27; MISS | 1.54; IN | 1.34; IN | 1.38; IN | pending; FIX |
| Distinct lines, at least 3 | pending final eight-seed tick witness; FIX | | | | | | |
| Floor own row | | | | | | | pending; FIX |

## Stop records and repeatability

The round-2 Tarn stop at [11.3,-596.4], 7.58 s is superseded under ruling 24. On the merged baseline, all eight Tarn seeds, its untraced seed-1 solo and its traced seed-1 solo record zero stops. Their full run hashes and differing core metrics remain in `baseline-repeatability.json`. This retires the old row without asserting a pack classification or deterministic stage acceptance.

The merged baseline adds Kest seed 1's non-reproducing stop and Tally seed 6's reproducible terrain stop at [144.2,340.1], 72.58 s. The matching Tally trace contacts `Park_sentinel_40/Collider` and the ground tile in the preceding 90 ticks, with no enemy contact. `tally-stop-window.json` records the window. No pack stop is exempted. Final-head classification status follows.

- tally seed 6, 72.58 s at [144.2, 340.1]: terrain: matched solo trace contacts Park_sentinel_40/Collider and Tile5_7; no enemy contact; final-tally-stop-window.json.

## Win proof

`win.gd` extends `res://tools/bot_run.gd` and only sets `driver.stage_limit=600.0` before the first tick. Each completionist seed uses the park table, stage 6, its own fresh output and XDG state, an eight-core CPU allocation and a 1800 s wall cap. `commands.ndjson` records the exact commands, exits and hashes. Ruling 23 requires every seed to reach and engage; break times and failures remain reported. Ruling 26 forbids a get_rid script error.

```sh
python /home/andrew/scratch/w13/sol/kd6-crown-r3/win_queued.py
```

| Seed | Class | Engaged s | Broken s | Engage to break s | Warden damage | Outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | runner_gunner | 115.86 | 466.24 | 350.38 | {"ram": 350.0, "slam": 700.0, "stomp": 350.0} | stalled; gates |
| 2 | demolitions_caster | 116.25 | 431.56 | 315.31 | {"ram": 525.0, "slam": 700.0, "stomp": 175.0} | stalled; gates |
| 3 | tarn | 160.8 | pending | pending | {"ram": 350.0, "slam": 175.0, "stomp": 175.0} | stalled; beacon |

## Geometry checks

The 59 metadata-only coverage rows are replaced by 106 greybox field patches, with 5,538 physical posts loaded by the real stage loader. Their footprints keep 24 m corridors around the fixed pilot lines and the gate approach, plus 44 m pocket and cradle clearances. The Crown-specific density check excludes non-producing rows and reads the existing 80 m limit from `park_density_test.gd`. Effective density is 62.264095 m worst over 40,650 open nodes; emptying one coverage row while retaining its metadata produces 200.0 m and fails after freshness is restored.

The physical perch check reads placed collider centres and tops against mind.md's approved positions and 12 m tops. The Warden anchor [0,18,515] and flight path are unchanged. A height-only mutation fails at a 15.000 m top after a fresh bake and graph. These mechanical passes do not establish traversal preservation or human feel.

The map-aware docking probe derives both cradles from the authored gate slots, passes the active ParkMap, requires both bounds/height checks with AND, and checks live docking. The retired no-map probe's red log is history in `legacy-dock.log`; no gate or shared bay bound was moved.
