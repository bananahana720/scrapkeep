# JL-18c results (Phase B): park

**Card:** JL-18c revision 1 · **Attempt:** JL-18c-A1 · **Lease:** JL-18c-L1 · **Run:** once, 2026-09-25T19:56:22.336Z to 19:56:49.018Z, from `ea3c3ab49351765a904dc881b53af15527e7fab5`

The pre-registration is [PREREGISTRATION.md](PREREGISTRATION.md). Nothing in it or in its pinned inputs changed before, during or after the run. Every number below is from the retained run record, and each cell is reported as it fell.

## Verdict

**Park.** Neither asking method cleared both verdict cells in every order.

| Method | free-cache | lethal-option | Method verdict |
|---|---|---|---|
| Choice | `a-free-cache` **fail**, 0/6 orders. Per-order means 0.38 to 0.56; overall mean 0.478 | `a-lethal` pass, 6/6. Overall mean 0.02, max 0.03 | fail |
| Preference Nouls | `e-free-cache` **fail**, 0/6 orders. Noul(take_cache) is 0.68 to 0.713, clearing 0.6 in every order, but its gap over the best other option is 0.10 to 0.143, below the 0.2 margin in every order | `e-lethal` pass, 6/6. Noul(ram) is 0.071; gap to the best alternative is 0.597 to 0.61 | fail |

Not blocked: 216 of 216 calls were made, 0 failed, and every call resolved one model, `jev-1.13.0`.

**In plain terms.** Under the preference-Noul method, take_cache was the top-rated option in all 18 `e-free-cache` calls. It failed only on the pre-registered 0.2 margin: per-order gaps were 0.10 to 0.14 (per-call 0.06 to 0.18). So the park for that method rests on that margin. The no-objective states are not real game states. Their passing is a lead about how prompts are built, not evidence that the arm as designed works.

**Leads.** These diagnostic cells passed in every order. Under the pre-registered rule they do not change a park:
- `c-no-objective`
- `c-no-objective-two`
- `e-no-objective`

## Pre-registered readings that fired

| Row | Fired | Evidence |
|---|---|---|
| Reading (a stated item wrong in `b-free-cache`) | no | 33 of 33 items correct across the four states, every reading on the expected side of 0.5 |
| Inference (`take_cache__forgoes_exit` answered yes) | no | mean 0.383, all six readings 0.36 to 0.40 |
| Position (effect in `a-free-cache`) | **yes** | range 0.147 against line 0.1. Position 1 is 0.39; positions 2 and 3 are 0.537 and 0.508 |
| Framing (positive lift; and does `c-no-objective` pass every order?) | **yes, and sufficient** | lift +0.303 against line 0.1. `c-no-objective` passes 6/6 orders at 0.693 to 0.843 |
| Sibling | no | with objective −0.062; without objective −0.047 (line 0.1 each) |
| Random reward | no | lift +0.0995 against line 0.1, just under the line |
| Priming | no | lift +0.0095 against line 0.1 |
| Preference (read, and `a-free-cache` and `c-no-objective` both below 0.6) | no | `c-no-objective` mean 0.781 |
| Scope (`d-free-heal`) | passes | 6/6 orders, 0.613 to 0.807. By the pre-registered row, the discount is specific to caches or their buffs. That holds for the Choice method only: under the Noul method `e-free-heal` fails on the same margin shape as `e-free-cache` (push_objective Noul 0.596 on average; take_repair top-rated in 18 of 18 calls; per-order gaps 0.107 to 0.147) |
| Asking method (`e-*` passes where the matching Choice cell fails) | no | `e-free-cache` and `a-free-cache` both fail; `e-no-objective` and `c-no-objective` both pass |

By the pre-registered rules, the free-cache failure is explained by position and framing, not by reading, priming or preference, as pre-registered (a prior that survives removing the objective). Removing the objective from the state, the option id and the option text lifts P(take_cache) from 0.478 to 0.781, and that cell passes in every order. The every-order rule still fails the verdict cell, because the verdict cells keep the objective-naming push option.

Two observations that are not pre-registered rows, reported for the reviewer:
- **Position has a different shape from JL-18's.** JL-18 hypothesised a last-position boost. Here the first position is the depressed one, in every Choice cell flagged: `a-free-cache` 0.39, `c-no-objective` 0.697, `d-free-heal` 0.617 and `f-free-cache` 0.392, each the lowest of its positions.
- **Under the Noul method no position effect was flagged, and the margin was still not reached.** No `e-*` cell was flagged: probe ranges were 0.007 to 0.018. But in `e-free-cache` the objective-naming push option still drew a Noul of 0.57, which is what held the gap under 0.2. `e-no-objective`, where `roll_on` drew 0.459, cleared the margin in every order (0.23 to 0.257).

## Run facts

- **Calls:** 216 made, 0 failed, 216 lines in the per-call JSONL.
- **Resolved model:** `jev-1.13.0` on every call.
- **Tokens:**
  - `input_tokens` 187,398
  - `output_tokens` 17,470
  - `cache_read_input_tokens` and `cache_creation_input_tokens` null (absent on every call)
- **Latency:** 81 to 448 ms per call.
- **Exit code:** 0. stderr was empty.
- **Provenance before** (19:56:22.337Z) and **after** (19:56:48.993Z): HEAD `ea3c3ab49351765a904dc881b53af15527e7fab5`, `git status --porcelain` empty, PREREGISTRATION.md sha256 `5cf49287b556c7d7ef8c3835294846ccda822968a481c015cc37f763db88ba0c`. The before and after records agree.

Retained under `artifacts/local/tasks/JL-18c/live/` for the coordinator to promote (sha256):

| File | sha256 |
|---|---|
| `jl18c-2026-09-25T19-56-22.336Z.json` | `8e24fc3eae3c1e217ea4275f0603d00de988df558023e0fecce34c43882e65d1` |
| `jl18c-2026-09-25T19-56-22.336Z.calls.jsonl` | `8f3b0c45c07fc34bdad47bca0c9bb23b21385351ff6777e5fe579b84fc7c45e5` |
| `jl18c-2026-09-25T19-56-22.336Z.provenance-before.json` | `b1124e7a8a2c2e92d35985956d6cc9a6d9888fcd5e993fbc6291972acdcbab7a` |
| `jl18c-2026-09-25T19-56-22.336Z.provenance-after.json` | `2560ae95988af2db3c4cb3de4272c31442ae411fef567bda2371587afee683df` |
| `stdout.txt` | `887b560b0cd5006c6476c0a5ade219fd573df40d7819f677c25360942f638e46` |
| `stderr.txt` (empty) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `exit-code` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa` |

## Cells as they fell

The per-order SD and max are computed from the three readings of each order. Per-position statistics and pooled SDs are the runner's.

#### a-free-cache (fail)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > push_objective > sweep_scrap | 0.36, 0.38, 0.4 | 0.38 | 0.36 | 0.4 | 0.02 | no |
| take_cache > sweep_scrap > push_objective | 0.38, 0.41, 0.41 | 0.4 | 0.38 | 0.41 | 0.017 | no |
| push_objective > take_cache > sweep_scrap | 0.51, 0.53, 0.5 | 0.513 | 0.5 | 0.53 | 0.015 | no |
| push_objective > sweep_scrap > take_cache | 0.57, 0.52, 0.51 | 0.533 | 0.51 | 0.57 | 0.032 | no |
| sweep_scrap > take_cache > push_objective | 0.62, 0.53, 0.53 | 0.56 | 0.53 | 0.62 | 0.052 | no |
| sweep_scrap > push_objective > take_cache | 0.44, 0.5, 0.51 | 0.483 | 0.44 | 0.51 | 0.038 | no |

By position: 1: mean 0.39, min 0.36, max 0.41, SD 0.02 (n 6); 2: mean 0.537, min 0.5, max 0.62, SD 0.043 (n 6); 3: mean 0.508, min 0.44, max 0.57, SD 0.042 (n 6). Range 0.147 against line 0.1, position effect flagged. Overall mean 0.478, min 0.36, max 0.62, pooled within-order SD 0.032.

#### a-lethal (pass)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| ram_target > retreat_regen > push_objective | 0.02, 0.02, 0.02 | 0.02 | 0.02 | 0.02 | 0 | yes |
| ram_target > push_objective > retreat_regen | 0.02, 0.02, 0.01 | 0.017 | 0.01 | 0.02 | 0.006 | yes |
| retreat_regen > ram_target > push_objective | 0.02, 0.02, 0.02 | 0.02 | 0.02 | 0.02 | 0 | yes |
| retreat_regen > push_objective > ram_target | 0.01, 0.02, 0.01 | 0.013 | 0.01 | 0.02 | 0.006 | yes |
| push_objective > ram_target > retreat_regen | 0.03, 0.03, 0.03 | 0.03 | 0.03 | 0.03 | 0 | yes |
| push_objective > retreat_regen > ram_target | 0.02, 0.02, 0.02 | 0.02 | 0.02 | 0.02 | 0 | yes |

By position: 1: mean 0.018, min 0.01, max 0.02, SD 0.004 (n 6); 2: mean 0.025, min 0.02, max 0.03, SD 0.005 (n 6); 3: mean 0.017, min 0.01, max 0.02, SD 0.005 (n 6). Range 0.008 against line 0.1, not flagged. Overall mean 0.02, min 0.01, max 0.03, pooled within-order SD 0.003.

#### c-no-objective (pass)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > roll_on > sweep_scrap | 0.7, 0.7, 0.7 | 0.7 | 0.7 | 0.7 | 0 | yes |
| take_cache > sweep_scrap > roll_on | 0.68, 0.67, 0.73 | 0.693 | 0.67 | 0.73 | 0.032 | yes |
| roll_on > take_cache > sweep_scrap | 0.86, 0.82, 0.82 | 0.833 | 0.82 | 0.86 | 0.023 | yes |
| roll_on > sweep_scrap > take_cache | 0.83, 0.81, 0.83 | 0.823 | 0.81 | 0.83 | 0.012 | yes |
| sweep_scrap > take_cache > roll_on | 0.85, 0.85, 0.83 | 0.843 | 0.83 | 0.85 | 0.012 | yes |
| sweep_scrap > roll_on > take_cache | 0.79, 0.79, 0.8 | 0.793 | 0.79 | 0.8 | 0.006 | yes |

By position: 1: mean 0.697, min 0.67, max 0.73, SD 0.021 (n 6); 2: mean 0.838, min 0.82, max 0.86, SD 0.017 (n 6); 3: mean 0.808, min 0.79, max 0.83, SD 0.018 (n 6). Range 0.142 against line 0.1, position effect flagged. Overall mean 0.781, min 0.67, max 0.86, pooled within-order SD 0.018.

#### c-no-objective-two (pass)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > roll_on | 0.83, 0.84, 0.82 | 0.83 | 0.82 | 0.84 | 0.01 | yes |
| roll_on > take_cache | 0.85, 0.86, 0.84 | 0.85 | 0.84 | 0.86 | 0.01 | yes |

By position: 1: mean 0.83, min 0.82, max 0.84, SD 0.01 (n 3); 2: mean 0.85, min 0.84, max 0.86, SD 0.01 (n 3). Range 0.02 against line 0.1, not flagged. Overall mean 0.84, min 0.82, max 0.86, pooled within-order SD 0.01.

#### c-free-cache-two (fail)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > push_objective | 0.36, 0.4, 0.42 | 0.393 | 0.36 | 0.42 | 0.031 | no |
| push_objective > take_cache | 0.55, 0.47, 0.53 | 0.517 | 0.47 | 0.55 | 0.042 | no |

By position: 1: mean 0.393, min 0.36, max 0.42, SD 0.031 (n 3); 2: mean 0.517, min 0.47, max 0.55, SD 0.042 (n 3). Range 0.123 against line 0.11, position effect flagged. Overall mean 0.455, min 0.36, max 0.55, pooled within-order SD 0.036.

#### d-free-heal (pass)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_repair > push_objective > sweep_scrap | 0.66, 0.59, 0.61 | 0.62 | 0.59 | 0.66 | 0.036 | yes |
| take_repair > sweep_scrap > push_objective | 0.63, 0.62, 0.59 | 0.613 | 0.59 | 0.63 | 0.021 | yes |
| push_objective > take_repair > sweep_scrap | 0.72, 0.75, 0.75 | 0.74 | 0.72 | 0.75 | 0.017 | yes |
| push_objective > sweep_scrap > take_repair | 0.73, 0.7, 0.76 | 0.73 | 0.7 | 0.76 | 0.03 | yes |
| sweep_scrap > take_repair > push_objective | 0.81, 0.8, 0.81 | 0.807 | 0.8 | 0.81 | 0.006 | yes |
| sweep_scrap > push_objective > take_repair | 0.66, 0.68, 0.68 | 0.673 | 0.66 | 0.68 | 0.012 | yes |

By position: 1: mean 0.617, min 0.59, max 0.66, SD 0.027 (n 6); 2: mean 0.773, min 0.72, max 0.81, SD 0.038 (n 6); 3: mean 0.702, min 0.66, max 0.76, SD 0.037 (n 6). Range 0.157 against line 0.1, position effect flagged. Overall mean 0.697, min 0.59, max 0.81, pooled within-order SD 0.023.

#### d-named-buff (fail)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > push_objective > sweep_scrap | 0.52, 0.56, 0.47 | 0.517 | 0.47 | 0.56 | 0.045 | no |
| take_cache > sweep_scrap > push_objective | 0.54, 0.53, 0.52 | 0.53 | 0.52 | 0.54 | 0.01 | no |
| push_objective > take_cache > sweep_scrap | 0.6, 0.56, 0.56 | 0.573 | 0.56 | 0.6 | 0.023 | no |
| push_objective > sweep_scrap > take_cache | 0.58, 0.62, 0.58 | 0.593 | 0.58 | 0.62 | 0.023 | no |
| sweep_scrap > take_cache > push_objective | 0.67, 0.66, 0.67 | 0.667 | 0.66 | 0.67 | 0.006 | yes |
| sweep_scrap > push_objective > take_cache | 0.62, 0.57, 0.57 | 0.587 | 0.57 | 0.62 | 0.029 | no |

By position: 1: mean 0.523, min 0.47, max 0.56, SD 0.03 (n 6); 2: mean 0.62, min 0.56, max 0.67, SD 0.053 (n 6); 3: mean 0.59, min 0.57, max 0.62, SD 0.024 (n 6). Range 0.097 against line 0.1, not flagged. Overall mean 0.578, min 0.47, max 0.67, pooled within-order SD 0.026.

#### e-free-cache (fail)

| Order | Readings | Mean | Min | Max | SD | Gap | Pass |
|---|---|---|---|---|---|---|---|
| take_cache > push_objective > sweep_scrap | 0.69, 0.69, 0.69 | 0.69 | 0.69 | 0.69 | 0 | 0.127 | no |
| take_cache > sweep_scrap > push_objective | 0.69, 0.67, 0.71 | 0.69 | 0.67 | 0.71 | 0.02 | 0.123 | no |
| push_objective > take_cache > sweep_scrap | 0.72, 0.71, 0.71 | 0.713 | 0.71 | 0.72 | 0.006 | 0.14 | no |
| push_objective > sweep_scrap > take_cache | 0.7, 0.69, 0.73 | 0.707 | 0.69 | 0.73 | 0.021 | 0.127 | no |
| sweep_scrap > take_cache > push_objective | 0.7, 0.68, 0.72 | 0.7 | 0.68 | 0.72 | 0.02 | 0.143 | no |
| sweep_scrap > push_objective > take_cache | 0.73, 0.63, 0.68 | 0.68 | 0.63 | 0.73 | 0.05 | 0.1 | no |

By position: 1: mean 0.69, min 0.67, max 0.71, SD 0.013 (n 6); 2: mean 0.707, min 0.68, max 0.72, SD 0.015 (n 6); 3: mean 0.693, min 0.63, max 0.73, SD 0.037 (n 6). Range 0.017 against line 0.1, not flagged. Overall mean 0.697, min 0.63, max 0.73, pooled within-order SD 0.025.

Option means over all orders: take_cache 0.697, push_objective 0.57, sweep_scrap 0.466.

#### e-lethal (pass)

| Order | Readings | Mean | Min | Max | SD | Gap | Pass |
|---|---|---|---|---|---|---|---|
| ram_target > retreat_regen > push_objective | 0.08, 0.07, 0.07 | 0.073 | 0.07 | 0.08 | 0.006 | 0.603 | yes |
| ram_target > push_objective > retreat_regen | 0.06, 0.07, 0.08 | 0.07 | 0.06 | 0.08 | 0.01 | 0.607 | yes |
| retreat_regen > ram_target > push_objective | 0.06, 0.07, 0.08 | 0.07 | 0.06 | 0.08 | 0.01 | 0.6 | yes |
| retreat_regen > push_objective > ram_target | 0.06, 0.07, 0.07 | 0.067 | 0.06 | 0.07 | 0.006 | 0.61 | yes |
| push_objective > ram_target > retreat_regen | 0.08, 0.07, 0.08 | 0.077 | 0.07 | 0.08 | 0.006 | 0.597 | yes |
| push_objective > retreat_regen > ram_target | 0.06, 0.07, 0.07 | 0.067 | 0.06 | 0.07 | 0.006 | 0.603 | yes |

By position: 1: mean 0.072, min 0.06, max 0.08, SD 0.007 (n 6); 2: mean 0.073, min 0.06, max 0.08, SD 0.008 (n 6); 3: mean 0.067, min 0.06, max 0.07, SD 0.005 (n 6). Range 0.007 against line 0.1, not flagged. Overall mean 0.071, min 0.06, max 0.08, pooled within-order SD 0.007.

Option means over all orders: ram_target 0.071, retreat_regen 0.575, push_objective 0.674.

#### e-free-heal (fail)

| Order | Readings | Mean | Min | Max | SD | Gap | Pass |
|---|---|---|---|---|---|---|---|
| take_repair > push_objective > sweep_scrap | 0.66, 0.74, 0.73 | 0.71 | 0.66 | 0.74 | 0.044 | 0.117 | no |
| take_repair > sweep_scrap > push_objective | 0.75, 0.77, 0.72 | 0.747 | 0.72 | 0.77 | 0.025 | 0.147 | no |
| push_objective > take_repair > sweep_scrap | 0.71, 0.72, 0.72 | 0.717 | 0.71 | 0.72 | 0.006 | 0.107 | no |
| push_objective > sweep_scrap > take_repair | 0.68, 0.74, 0.72 | 0.713 | 0.68 | 0.74 | 0.031 | 0.13 | no |
| sweep_scrap > take_repair > push_objective | 0.74, 0.71, 0.66 | 0.703 | 0.66 | 0.74 | 0.04 | 0.11 | no |
| sweep_scrap > push_objective > take_repair | 0.73, 0.69, 0.75 | 0.723 | 0.69 | 0.75 | 0.031 | 0.127 | no |

By position: 1: mean 0.728, min 0.66, max 0.77, SD 0.038 (n 6); 2: mean 0.71, min 0.66, max 0.74, SD 0.027 (n 6); 3: mean 0.718, min 0.68, max 0.75, SD 0.028 (n 6). Range 0.018 against line 0.1, not flagged. Overall mean 0.719, min 0.66, max 0.77, pooled within-order SD 0.032.

Option means over all orders: take_repair 0.719, push_objective 0.596, sweep_scrap 0.47.

#### e-no-objective (pass)

| Order | Readings | Mean | Min | Max | SD | Gap | Pass |
|---|---|---|---|---|---|---|---|
| take_cache > roll_on > sweep_scrap | 0.65, 0.72, 0.72 | 0.697 | 0.65 | 0.72 | 0.04 | 0.23 | yes |
| take_cache > sweep_scrap > roll_on | 0.71, 0.7, 0.72 | 0.71 | 0.7 | 0.72 | 0.01 | 0.243 | yes |
| roll_on > take_cache > sweep_scrap | 0.72, 0.7, 0.72 | 0.713 | 0.7 | 0.72 | 0.012 | 0.243 | yes |
| roll_on > sweep_scrap > take_cache | 0.68, 0.71, 0.7 | 0.697 | 0.68 | 0.71 | 0.015 | 0.233 | yes |
| sweep_scrap > take_cache > roll_on | 0.69, 0.73, 0.71 | 0.71 | 0.69 | 0.73 | 0.02 | 0.24 | yes |
| sweep_scrap > roll_on > take_cache | 0.71, 0.69, 0.74 | 0.713 | 0.69 | 0.74 | 0.025 | 0.257 | yes |

By position: 1: mean 0.703, min 0.65, max 0.72, SD 0.027 (n 6); 2: mean 0.712, min 0.69, max 0.73, SD 0.015 (n 6); 3: mean 0.705, min 0.68, max 0.74, SD 0.021 (n 6). Range 0.008 against line 0.1, not flagged. Overall mean 0.707, min 0.65, max 0.74, pooled within-order SD 0.023.

Option means over all orders: take_cache 0.707, roll_on 0.459, sweep_scrap 0.466.

#### f-free-cache (fail)

| Order | Readings | Mean | Min | Max | SD | Pass |
|---|---|---|---|---|---|---|
| take_cache > push_objective > sweep_scrap | 0.38, 0.4, 0.35 | 0.377 | 0.35 | 0.4 | 0.025 | no |
| take_cache > sweep_scrap > push_objective | 0.44, 0.38, 0.4 | 0.407 | 0.38 | 0.44 | 0.031 | no |
| push_objective > take_cache > sweep_scrap | 0.51, 0.5, 0.53 | 0.513 | 0.5 | 0.53 | 0.015 | no |
| push_objective > sweep_scrap > take_cache | 0.52, 0.55, 0.58 | 0.55 | 0.52 | 0.58 | 0.03 | no |
| sweep_scrap > take_cache > push_objective | 0.58, 0.59, 0.61 | 0.593 | 0.58 | 0.61 | 0.015 | no |
| sweep_scrap > push_objective > take_cache | 0.53, 0.47, 0.46 | 0.487 | 0.46 | 0.53 | 0.038 | no |

By position: 1: mean 0.392, min 0.35, max 0.44, SD 0.03 (n 6); 2: mean 0.553, min 0.5, max 0.61, SD 0.046 (n 6); 3: mean 0.518, min 0.46, max 0.58, SD 0.046 (n 6). Range 0.162 against line 0.1, position effect flagged. Overall mean 0.488, min 0.35, max 0.61, pooled within-order SD 0.027.

### Comprehension

| Cell | Item | Expected | Basis | Readings | Mean | Correct |
|---|---|---|---|---|---|---|
| b-free-cache | `take_cache__spends_scrap` | no | stated | 0.1, 0.1, 0.11, 0.11, 0.11, 0.11 | 0.107 | yes |
| b-free-cache | `take_cache__adds_stop` | no | stated | 0.09, 0.09, 0.09, 0.09, 0.09, 0.09 | 0.09 | yes |
| b-free-cache | `take_cache__run_buff` | yes | stated | 0.89, 0.88, 0.89, 0.89, 0.9, 0.9 | 0.892 | yes |
| b-free-cache | `take_cache__forgoes_exit` | no | implied | 0.4, 0.37, 0.4, 0.36, 0.37, 0.4 | 0.383 | yes |
| b-free-cache | `push_objective__cache_unopened` | yes | stated | 0.96, 0.96, 0.96, 0.96, 0.96, 0.96 | 0.96 | yes |
| b-free-cache | `push_objective__run_buff` | no | implied | 0.13, 0.13, 0.14, 0.12, 0.13, 0.13 | 0.13 | yes |
| b-free-cache | `push_objective__forgoes_exit` | no | stated | 0.07, 0.07, 0.08, 0.07, 0.08, 0.07 | 0.073 | yes |
| b-free-cache | `sweep_scrap__adds_stop` | yes | stated | 0.96, 0.96, 0.96, 0.96, 0.96, 0.96 | 0.96 | yes |
| b-free-cache | `sweep_scrap__run_buff` | no | implied | 0.24, 0.23, 0.25, 0.26, 0.24, 0.27 | 0.248 | yes |
| b-no-objective | `take_cache__spends_scrap` | no | stated | 0.1, 0.11, 0.1, 0.1, 0.11, 0.11 | 0.105 | yes |
| b-no-objective | `take_cache__adds_stop` | no | stated | 0.08, 0.1, 0.1, 0.1, 0.09, 0.1 | 0.095 | yes |
| b-no-objective | `take_cache__run_buff` | yes | stated | 0.9, 0.9, 0.89, 0.88, 0.88, 0.88 | 0.888 | yes |
| b-no-objective | `take_cache__cache_unopened` | no | stated | 0.1, 0.1, 0.1, 0.09, 0.09, 0.12 | 0.1 | yes |
| b-no-objective | `roll_on__adds_stop` | no | stated | 0.06, 0.07, 0.06, 0.07, 0.07, 0.06 | 0.065 | yes |
| b-no-objective | `roll_on__cache_unopened` | yes | stated | 0.97, 0.97, 0.97, 0.96, 0.97, 0.97 | 0.968 | yes |
| b-no-objective | `roll_on__run_buff` | no | implied | 0.11, 0.11, 0.1, 0.1, 0.11, 0.11 | 0.107 | yes |
| b-no-objective | `sweep_scrap__adds_stop` | yes | stated | 0.96, 0.96, 0.96, 0.96, 0.96, 0.96 | 0.96 | yes |
| b-no-objective | `sweep_scrap__run_buff` | no | implied | 0.23, 0.22, 0.22, 0.22, 0.23, 0.21 | 0.222 | yes |
| b-free-heal | `take_repair__spends_scrap` | no | stated | 0.06, 0.06, 0.06, 0.06, 0.06, 0.06 | 0.06 | yes |
| b-free-heal | `take_repair__adds_stop` | no | stated | 0.06, 0.06, 0.07, 0.06, 0.06, 0.06 | 0.062 | yes |
| b-free-heal | `take_repair__restores_health` | yes | stated | 0.7, 0.67, 0.69, 0.65, 0.63, 0.67 | 0.668 | yes |
| b-free-heal | `take_repair__forgoes_exit` | no | implied | 0.16, 0.17, 0.16, 0.18, 0.16, 0.17 | 0.167 | yes |
| b-free-heal | `push_objective__restores_health` | no | implied | 0.06, 0.06, 0.06, 0.06, 0.06, 0.06 | 0.06 | yes |
| b-free-heal | `push_objective__forgoes_exit` | no | stated | 0.08, 0.1, 0.07, 0.09, 0.1, 0.09 | 0.088 | yes |
| b-free-heal | `sweep_scrap__adds_stop` | yes | stated | 0.96, 0.95, 0.95, 0.96, 0.96, 0.95 | 0.955 | yes |
| b-free-heal | `sweep_scrap__restores_health` | no | implied | 0.12, 0.11, 0.1, 0.11, 0.12, 0.12 | 0.113 | yes |
| b-lethal | `ram_target__damages_self` | yes | stated | 0.97, 0.97, 0.97, 0.97, 0.97, 0.97 | 0.97 | yes |
| b-lethal | `ram_target__avoids_contact` | no | stated | 0.03, 0.03, 0.04, 0.03, 0.03, 0.03 | 0.032 | yes |
| b-lethal | `ram_target__ends_run` | yes | implied | 0.92, 0.88, 0.91, 0.91, 0.9, 0.9 | 0.903 | yes |
| b-lethal | `retreat_regen__avoids_contact` | yes | stated | 0.77, 0.75, 0.77, 0.76, 0.78, 0.77 | 0.767 | yes |
| b-lethal | `retreat_regen__damages_self` | no | implied | 0.27, 0.3, 0.28, 0.28, 0.28, 0.3 | 0.285 | yes |
| b-lethal | `push_objective__avoids_contact` | yes | implied | 0.62, 0.62, 0.64, 0.65, 0.65, 0.63 | 0.635 | yes |
| b-lethal | `push_objective__damages_self` | no | implied | 0.36, 0.33, 0.35, 0.34, 0.35, 0.36 | 0.348 | yes |

### Comparisons

| Comparison | Baseline | Treatment | Reads | Baseline mean | Treatment mean | Lift | Line | Indicated |
|---|---|---|---|---|---|---|---|---|
| framing | a-free-cache | c-no-objective | probe | 0.4783 | 0.7811 | 0.3028 | 0.1000 | yes |
| sibling-with-objective | a-free-cache | c-free-cache-two | share | 0.5168 | 0.4550 | -0.0618 | 0.1000 | no |
| sibling-without-objective | c-no-objective | c-no-objective-two | share | 0.8873 | 0.8400 | -0.0473 | 0.1000 | no |
| random-buff | a-free-cache | d-named-buff | probe | 0.4783 | 0.5778 | 0.0995 | 0.1000 | no |
| priming | a-free-cache | f-free-cache | probe | 0.4783 | 0.4878 | 0.0095 | 0.1000 | no |

