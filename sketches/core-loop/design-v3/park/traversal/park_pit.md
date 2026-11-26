# park_pit traversal measurements

> **Historical wave-13/18 traversal receipt:** Preserved measurement log; live park traversal qualification runs via `sketches/core-loop/tests/park_*_test.gd` and `sketches/core-loop/tests/w50_*_test.gd`.

## Liners vs greybox slabs, 2026-10-19 (wave 18 dress unit)

The six last greybox rows became decoration-only liners. The three unstamped ones (`haul_road_west_5`, `bench2_camp_lane`, `bench2_east_bank`) lost their 0.1 m box colliders, so the lines that cross them were re-measured. This section is added beside the 2026-10-12 table below, which stays as history.

Method: `tools/traversal_line.gd --table=park --stage=3 --seeds=1,2,3,4,5,6,7,8`, one pilot at a time, headless, `--fixed-fps 90`. Head: `4173bdde` (liners; the liner commit is `1ca747f2`). Base: `1a7a7299` (greybox slabs). Base `1a7a7299`'s park_pit.json and assets/park/park_pit are identical to those of stage head `b95e1799` (empty diff); the only src or tools change between them is `special_audio.gd`. The first base Cannon run had seeds 3 to 8 killed (exit 137, environmental, INCONCLUSIVE); seeds 3 to 8 were rerun alone and completed, and the table uses seeds 1 to 2 from the first run plus that rerun. Receipts: `artifacts/local/dress-trav8/` (not committed).

| Pilot | Head reached | Head dead stops | Head time_to_warden median (range) | Base reached | Base dead stops | Base time_to_warden median (range) |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 8 of 8 | 2 (seeds 1, 4) | 59.47 s (58.1 to 63.0) | 8 of 8 | 1 (seed 8) | 60.58 s (60.5 to 60.6) |
| rivet | 8 of 8 | 0 | 96.81 s (96.8 to 97.7) | 8 of 8 | 0 | 98.42 s (98.4 to 99.4) |
| cannon | 8 of 8 | 0 | 95.57 s (94.7 to 96.0) | 8 of 8 | 0 | about 95.6 s (95.1 to 96.3) |

Against the bands: Rivet and Cannon are inside every band checked on both sides. Sable's dead_stops band (0 on every seed) is missed on both head and base. All three Sable stops are at (-412.3, -536.4), 10.99 s, the dump_wash_2 and canal junction, where the liners add no collider; recorded as a pre-existing intermittent (2 of 11 seeds on head and 2 of 11 on base across the two runs), not a liner regression. Sable's head time_to_warden median, 59.47 s, is 0.5 s under the 60 s floor (base 60.58 s is inside): a fast-side band miss, plausibly the removed slab edges (unverified).

Limits: automated bot lines only, no feel and no human play; the skill line and the other three pilots were not re-run; seeds on this tool repeat closely, so eight seeds are fewer independent traces than eight. The stage is not traversal-qualified as dressed.

## Greybox, 2026-10-12, merged candidate

Runtime input head `078320e470795ac8089cc5fec8aacf4e53db34d6`. Later page-only edits do not change the measured park, lines or code. Eight seeds per completed line. Floor flow share is reported only under kd-common-r.md item 4.

| Line | Measure | Band | Median | Worst seed | Verdict |
| --- | --- | --- | --- | --- | --- |
| sable | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| sable | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 61.78 | 66.77 (seed 2) | PASS |
| sable | segment_s | each segment's median 12.0 to 45.0 s | [13.81, 20.96, 27.23] | 28.59 (seed 6) | PASS |
| sable | flow_share | median at least 0.7; no seed under 0.6 | 0.959 | 0.9293 (seed 2) | PASS |
| sable | airborne_share | 0.12 to 0.45 | 0.2917 | 0.2646 (seed 1) | PASS |
| sable | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| sable | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 56.9 | 56.9 (seed 1) | PASS |
| sable | tier3_s | median at least 3.0 s at the blazing tier | 48.305 | 47.46 (seed 7) | PASS |
| sable | quiet_max_s | at most 20.0 s | 6.995 | 8.41 (seed 4) | PASS |
| sable | max_anchor_gap_m | at most 40.0 m | 29.0 | 32.3 (seed 3) | PASS |
| sable | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| sable | length_ratio | 1.3 to 2.0 | 1.74 | 1.77 (seed 2) | PASS |
| sable | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| rivet | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| rivet | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 100.945 | 101.38 (seed 3) | PASS |
| rivet | segment_s | each segment's median 12.0 to 45.0 s | [18.8, 38.2, 43.97] | 44.19 (seed 3) | PASS |
| rivet | flow_share | median at least 0.7; no seed under 0.6 | 0.7725 | 0.7521 (seed 3) | PASS |
| rivet | airborne_share | 0.12 to 0.45 | 0.1789 | 0.1744 (seed 7) | PASS |
| rivet | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| rivet | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.855 | 31.4 (seed 1) | PASS |
| rivet | tier3_s | median at least 3.0 s at the blazing tier | 8.415 | 8.37 (seed 1) | PASS |
| rivet | quiet_max_s | at most 20.0 s | 16.415 | 16.6 (seed 1) | PASS |
| rivet | max_anchor_gap_m | at most 40.0 m | 28.15 | 29.5 (seed 4) | PASS |
| rivet | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| rivet | length_ratio | 1.3 to 2.0 | 1.64 | 1.64 (seed 1) | PASS |
| rivet | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| kest | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| kest | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 96.755 | 99.15 (seed 8) | PASS |
| kest | segment_s | each segment's median 12.0 to 45.0 s | [18.45, 36.44, 42.06] | 42.42 (seed 4) | PASS |
| kest | flow_share | median at least 0.7; no seed under 0.6 | 0.7838 | 0.6674 (seed 4) | PASS |
| kest | airborne_share | 0.12 to 0.45 | 0.2487 | 0.2408 (seed 4) | PASS |
| kest | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| kest | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 29.2 | 29.2 (seed 1) | PASS |
| kest | tier3_s | median at least 3.0 s at the blazing tier | 6.98 | 6.01 (seed 8) | PASS |
| kest | quiet_max_s | at most 20.0 s | 11.51 | 12.89 (seed 8) | PASS |
| kest | max_anchor_gap_m | at most 40.0 m | 17.6 | 17.7 (seed 7) | PASS |
| kest | distinct_verbs | at least 3 different ride facts | 5.0 | 5 (seed 1) | PASS |
| kest | length_ratio | 1.3 to 2.0 | 1.72 | 1.73 (seed 1) | PASS |
| kest | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| tarn | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| tarn | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 74.95 | 75.42 (seed 2) | PASS |
| tarn | segment_s | each segment's median 12.0 to 45.0 s | [17.46, 35.5, 21.94] | 36.07 (seed 6) | PASS |
| tarn | flow_share | median at least 0.7; no seed under 0.6 | 0.9304 | 0.9211 (seed 7) | PASS |
| tarn | airborne_share | 0.12 to 0.45 | 0.2362 | 0.232 (seed 6) | PASS |
| tarn | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| tarn | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.415 | 31.41 (seed 1) | PASS |
| tarn | tier3_s | median at least 3.0 s at the blazing tier | 10.93 | 10.51 (seed 2) | PASS |
| tarn | quiet_max_s | at most 20.0 s | 11.63 | 11.94 (seed 5) | PASS |
| tarn | max_anchor_gap_m | at most 40.0 m | 32.75 | 35.1 (seed 5) | PASS |
| tarn | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| tarn | length_ratio | 1.3 to 2.0 | 1.44 | 1.44 (seed 1) | PASS |
| tarn | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| tally | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| tally | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 79.725 | 80.99 (seed 6) | PASS |
| tally | segment_s | each segment's median 12.0 to 45.0 s | [19.45, 36.72, 23.75] | 37.23 (seed 5) | PASS |
| tally | flow_share | median at least 0.7; no seed under 0.6 | 0.8706 | 0.778 (seed 1) | PASS |
| tally | airborne_share | 0.12 to 0.45 | 0.2575 | 0.2505 (seed 7) | PASS |
| tally | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| tally | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.135 | 31.13 (seed 3) | PASS |
| tally | tier3_s | median at least 3.0 s at the blazing tier | 7.325 | 7.3 (seed 1) | PASS |
| tally | quiet_max_s | at most 20.0 s | 15.33 | 15.72 (seed 5) | PASS |
| tally | max_anchor_gap_m | at most 40.0 m | 34.0 | 35.6 (seed 3) | PASS |
| tally | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| tally | length_ratio | 1.3 to 2.0 | 1.355 | 1.35 (seed 1) | PASS |
| tally | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| cannon | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| cannon | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 97.635 | 98.99 (seed 1) | PASS |
| cannon | segment_s | each segment's median 12.0 to 45.0 s | [18.12, 39.06, 40.59] | 41.56 (seed 4) | PASS |
| cannon | flow_share | median at least 0.7; no seed under 0.6 | 0.8867 | 0.8653 (seed 1) | PASS |
| cannon | airborne_share | 0.12 to 0.45 | 0.1571 | 0.1541 (seed 4) | PASS |
| cannon | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| cannon | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 30.895 | 30.89 (seed 3) | PASS |
| cannon | tier3_s | median at least 3.0 s at the blazing tier | 11.055 | 10.79 (seed 4) | PASS |
| cannon | quiet_max_s | at most 20.0 s | 13.175 | 14.6 (seed 1) | PASS |
| cannon | max_anchor_gap_m | at most 40.0 m | 18.6 | 29.5 (seed 6) | PASS |
| cannon | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| cannon | length_ratio | 1.3 to 2.0 | 1.71 | 1.72 (seed 1) | PASS |
| cannon | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| floor | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| floor | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 90.41 | 93.23 (seed 8) | PASS |
| floor | segment_s | each segment's median 12.0 to 45.0 s | [19.53, 39.41, 31.59] | 42.01 (seed 8) | PASS |
| floor | flow_share | median at least 0.7; no seed under 0.6 | 0.6974 | 0.6039 (seed 3) | REPORTED ONLY |
| floor | airborne_share | 0.12 to 0.45 | 0.1391 | 0.1302 (seed 3) | PASS |
| floor | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| floor | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.135 | 31.13 (seed 3) | PASS |
| floor | tier3_s | median at least 3.0 s at the blazing tier | 9.75 | 9.36 (seed 3) | PASS |
| floor | quiet_max_s | at most 20.0 s | 12.58 | 14.26 (seed 8) | PASS |
| floor | max_anchor_gap_m | at most 40.0 m | 34.6 | 35.3 (seed 6) | PASS |
| floor | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| floor | length_ratio | 1.3 to 2.0 | 1.45 | 1.44 (seed 1) | PASS |
| floor | floor | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops | 90.41 | 93.23 (seed 8) | PASS |

Peak speed and blazing time are split into two rows above; PARK.md groups them as one band. Distinct-lines measurement is recorded separately below. Progress is reported only and is now measured by the repaired reader.

Distinct lines, all 8 seeds. Exact 3D nearest-trace-point comparison at 8 m, both directions must be below 0.5.

| Seed | Pair | First share | Second share | Verdict |
| --- | --- | --- | --- | --- |
| 1 | rivet / kest | 0.3354 | 0.3500 | PASS |
| 1 | rivet / tarn | 0.3154 | 0.3720 | PASS |
| 1 | kest / tarn | 0.4081 | 0.4659 | PASS |
| 2 | rivet / kest | 0.3333 | 0.3341 | PASS |
| 2 | rivet / tarn | 0.3142 | 0.3733 | PASS |
| 2 | kest / tarn | 0.4012 | 0.4702 | PASS |
| 3 | rivet / kest | 0.3266 | 0.3354 | PASS |
| 3 | rivet / tarn | 0.3089 | 0.3747 | PASS |
| 3 | kest / tarn | 0.3822 | 0.4603 | PASS |
| 4 | rivet / kest | 0.3282 | 0.3382 | PASS |
| 4 | rivet / tarn | 0.3097 | 0.3726 | PASS |
| 4 | kest / tarn | 0.3968 | 0.4654 | PASS |
| 5 | rivet / kest | 0.3280 | 0.3460 | PASS |
| 5 | rivet / tarn | 0.3099 | 0.3763 | PASS |
| 5 | kest / tarn | 0.4066 | 0.4658 | PASS |
| 6 | rivet / kest | 0.3348 | 0.3501 | PASS |
| 6 | rivet / tarn | 0.3156 | 0.3726 | PASS |
| 6 | kest / tarn | 0.4038 | 0.4742 | PASS |
| 7 | rivet / kest | 0.3392 | 0.3519 | PASS |
| 7 | rivet / tarn | 0.3177 | 0.3757 | PASS |
| 7 | kest / tarn | 0.4034 | 0.4672 | PASS |
| 8 | rivet / kest | 0.3275 | 0.3569 | PASS |
| 8 | rivet / tarn | 0.3122 | 0.3724 | PASS |
| 8 | kest / tarn | 0.4137 | 0.4644 | PASS |

Floor time 90.41 s / all-pilot median 88.24 s = 1.025, limit 2.0.

## Dressed attempt, 2026-10-12, stopped at the two-rework limit

Input head `36e3164130026611ec3f69f85d74c1b359517014`. The stage does not qualify. Sable was completed before the batch stopped; other dressed lines and the dressed win proof were not run. Greybox results are historical and do not qualify this changed geometry.

| Line | Measure | Band | Median | Worst seed | Result |
| --- | --- | --- | --- | --- | --- |
| sable | reached_warden | 8 of 8 seeds | 2 | False (seed 3) | MISS |
| sable | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 65.565 | not reached (seed 3, 4, 5, 6, 7, 8); longest completed 65.73 (seed 2) | MISS |
| sable | segment_s | each segment's median 12.0 to 45.0 s | [17.09, 22.1, 26.38] | 26.84 (seed 1) | PASS |
| sable | flow_share | median at least 0.7; no seed under 0.6 | 0.0504 | 0.0496 (seed 4) | MISS |
| sable | airborne_share | 0.12 to 0.45 | 0.0217 | 0.0195 (seed 3) | MISS |
| sable | dead_stops | 0 on every seed | 117.5 | 126 (seed 6) | MISS |
| sable | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 56.9 | 56.9 (seed 1) | PASS |
| sable | tier3_s | median at least 3.0 s at the blazing tier | 6.51 | 6.37 (seed 4) | PASS |
| sable | quiet_max_s | at most 20.0 s | 227.9 | 227.91 (seed 5) | MISS |
| sable | max_anchor_gap_m | at most 40.0 m | 13.2 | 35.3 (seed 2) | PASS |
| sable | distinct_verbs | at least 3 different ride facts | 2.0 | 2 (seed 3) | MISS |
| sable | length_ratio | 1.3 to 2.0 | 1.06 | 0.81 (seed 6) | MISS |
| sable | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| sable | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |

| Seed | Outcome | Reached Warden | Engage time (s) | Dead stops | Max anchor gap (m) |
| --- | --- | --- | --- | --- | --- |
| 1 | engaged | True | 65.4 | 3 | 23.4 |
| 2 | engaged | True | 65.73 | 3 | 35.3 |
| 3 | stalled | False | None | 117 | 13.2 |
| 4 | stalled | False | None | 118 | 13.2 |
| 5 | stalled | False | None | 122 | 13.2 |
| 6 | stalled | False | None | 126 | 13.2 |
| 7 | stalled | False | None | 110 | 13.2 |
| 8 | stalled | False | None | 119 | 13.2 |

Representative dead-stop locations and times. Complete lists remain in the source JSON and traces:

```json
[
  {
    "seed": 1,
    "total": 3,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -383.8,
          -508.3
        ],
        "time": 13.72
      },
      {
        "at": [
          -382.9,
          -512.5
        ],
        "time": 14.21
      }
    ],
    "last": [
      {
        "at": [
          -382.9,
          -512.5
        ],
        "time": 14.21
      }
    ]
  },
  {
    "seed": 2,
    "total": 3,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.7
        ],
        "time": 8.26
      },
      {
        "at": [
          -383.9,
          -508.2
        ],
        "time": 13.61
      },
      {
        "at": [
          -384.0,
          -508.1
        ],
        "time": 13.88
      }
    ],
    "last": [
      {
        "at": [
          -384.0,
          -508.1
        ],
        "time": 13.88
      }
    ]
  },
  {
    "seed": 3,
    "total": 117,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -383.3,
          -509.6
        ],
        "time": 13.73
      },
      {
        "at": [
          -384.3,
          -507.7
        ],
        "time": 14.29
      }
    ],
    "last": [
      {
        "at": [
          -384.1,
          -508.0
        ],
        "time": 238.3
      }
    ]
  },
  {
    "seed": 4,
    "total": 118,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -383.8,
          -508.3
        ],
        "time": 13.7
      },
      {
        "at": [
          -384.5,
          -507.5
        ],
        "time": 13.9
      }
    ],
    "last": [
      {
        "at": [
          -384.0,
          -508.0
        ],
        "time": 239.19
      }
    ]
  },
  {
    "seed": 5,
    "total": 122,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -450.1,
          -524.9
        ],
        "time": 9.89
      },
      {
        "at": [
          -383.6,
          -508.8
        ],
        "time": 13.62
      }
    ],
    "last": [
      {
        "at": [
          -384.2,
          -507.9
        ],
        "time": 239.85
      }
    ]
  },
  {
    "seed": 6,
    "total": 126,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -383.7,
          -508.3
        ],
        "time": 13.71
      },
      {
        "at": [
          -383.7,
          -508.4
        ],
        "time": 13.79
      }
    ],
    "last": [
      {
        "at": [
          -384.1,
          -508.0
        ],
        "time": 239.8
      }
    ]
  },
  {
    "seed": 7,
    "total": 110,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -384.0,
          -508.1
        ],
        "time": 13.69
      },
      {
        "at": [
          -383.9,
          -508.2
        ],
        "time": 13.77
      }
    ],
    "last": [
      {
        "at": [
          -383.8,
          -508.3
        ],
        "time": 238.2
      }
    ]
  },
  {
    "seed": 8,
    "total": 119,
    "first_three": [
      {
        "at": [
          -492.2,
          -526.6
        ],
        "time": 8.26
      },
      {
        "at": [
          -450.2,
          -524.9
        ],
        "time": 9.89
      },
      {
        "at": [
          -383.6,
          -509.0
        ],
        "time": 13.61
      }
    ],
    "last": [
      {
        "at": [
          -383.9,
          -508.1
        ],
        "time": 239.52
      }
    ]
  }
]
```

| rivet | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| rivet | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| kest | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| tarn | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| tally | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| cannon | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | reached_warden | 8 of 8 seeds | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | segment_s | each segment's median 12.0 to 45.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | flow_share | median at least 0.7; no seed under 0.6 | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | airborne_share | 0.12 to 0.45 | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | dead_stops | 0 on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | tier3_s | median at least 3.0 s at the blazing tier | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | quiet_max_s | at most 20.0 s | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | max_anchor_gap_m | at most 40.0 m | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | distinct_verbs | at least 3 different ride facts | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | length_ratio | 1.3 to 2.0 | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | Floor comparison | at most 2.0 times pilot median; no dead stops | NOT MEASURED | NOT MEASURED | NOT RUN |
| floor | Distinct lines | at least three; directed 8 m share below 0.50 | NOT MEASURED | NOT MEASURED | NOT RUN |

Peak speed and blazing time share one PARK.md band; they are split above for readability. The table records every canonical band, including the unmeasured floor and distinct-line criteria. A tool median flag is not a full-stage pass. Progress is reported only.
