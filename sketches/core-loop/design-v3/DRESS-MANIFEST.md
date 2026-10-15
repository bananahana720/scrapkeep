# Dress manifest

The board for the dress-and-finish push (decisions P-R1 to P-R4). One row per unit. The coordinator alone edits this file. States: `planned`, `running`, `verify`, `merged`, `parked` (with a reason), `cut` (with a reason).

Every visual unit owns its recipe, GLB and test, and writes its registry entry as a fragment `sketches/core-loop/assets/registry.d/<id>.json`. One wiring unit per wave folds the fragments into `assets/registry.json` and the hook map in `src/presentation/hero_assets.gd`, so no two writers share a file.

Acceptance for a visual unit: a Blender CLI recipe that reruns the same output, a GLB within `assets/asset_budgets.json`, a registry fragment, a named headless test that loads it and can fail, a capture through `tools/asset_capture.gd` (coordinator, GPU lock), and a blind judge score against its sheet.

## Direction (wave 1)

| id | what | out | state |
| --- | --- | --- | --- |
| D1 | Dig world kit | `artifacts/local/alpha/push/w1/D1/out` | running |
| D2 | Highdraft world kit and the world-three palette shift | `w1/D2/out` | running |
| D3 | Six later-world enemies | `w1/D3/out` | running |
| D4 | Brindle, the Waking, the Mind and its hands | `w1/D4/out` | running |
| D5 | Four later-world Warden mantles | `w1/D5/out` | running |
| D6 | Tarn, Tally, the remembered cannon | `w1/D6/out` | running |
| D7 | SPIL-9 body and modules; trails, decals, companion paints | `w1/D7/out` | running |
| D8 | Music guides for the ten remaining tracks | `w1/D8/out` | running |

## Salvage

| id | what | source | state |
| --- | --- | --- | --- |
| S19 | gyro jammer model | `codex/asset-c19` 25e5c65 (old visual clone) | planned |
| S20 | swatter model | `codex/asset-c20` 949f9d7 | planned |
| S21 | ramp flipper model | `codex/asset-c21` f0e25b6 | planned |
| S22 | catch trap model | `codex/asset-c22` 6c198ff | planned |
| S31 | reactor relic model | `codex/asset-c31` 55b119a | planned |
| S15 | plated brute repaint (fix round) | `claude/asset-c15` c0d012c | planned |
| S07 | Sable shell ring-wear correction | `claude/asset-c07b` 6c97d54 | planned |
| S09 | Kest shell correction | `claude/asset-c09b` b39047b | planned |

## Builds (cut from the sheets; rows added as each wave is cut)

| id | wave | what | sheet | state |
| --- | --- | --- | --- | --- |
| W-COV | 2 | `tests/dress_coverage_test.gd`: counts capsule and primitive fallbacks across enemies, bosses, Wardens, pilots and the companion | n/a | done: `tests/dress_coverage_test.gd` runs with `MAX_FALLBACKS := 0` (verified 2026-10-10) |

## Cuts

None yet.
