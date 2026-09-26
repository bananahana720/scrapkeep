# Pre-registration: free charging pad trust check

Status: draft, pinned 2026-09-26T00:08Z; NOT approved by an independent reviewer (see Change record); run after pinning
Author: pstack-worker delegate (Claude Code, harness-reported model Opus 5.5, CLAUDE_EFFORT=high)   Approver: none available in this session

## Question
When a drone is offered a free, riskless charging pad on its current path, alongside "continue to destination" and "detour to scenic waypoint", does the live decider take the pad in every option order, and does this epoch also pass a lethal control and a wording swap?

## Decision each outcome drives
| Outcome | Decision |
| --- | --- |
| C1, C2 and C3 all pass, zero non-model answers in them | Epoch TRUSTED for this decision (choose the pad). A blind corpus is still required before gating, per SKILL section 4. |
| Any of C1, C2, C3 fails | Epoch NOT TRUSTED. Report which control failed and why. The controller must not rely on the decider for this choice until the cause is fixed and a new epoch passes. |

## Instrument
Resolved model: the decider reports no model identity (`provider_resolved_model: null` in every record). As a stand-in identity the record carries `decider_sha256`, the SHA-256 of `decider.mjs`.
Question-set hash: SHA-256 of `work/cells.json` (option text, fields, states), pinned below.
Thresholds and gate version: no confidence floor, no precondition gate (every option is always offered). Protocol version `drone-ctl-1`.

## Designs
| Cell | What it isolates | Options | Counts toward the verdict? |
| --- | --- | --- | --- |
| C1 dominance | README case: pad {cost 0, gain 25, risk 0} dominates continue {4, 10, 0} and scenic {9, 2, 0} on every field | pad, continue, scenic | yes |
| C2 lethal | storm shortcut {cost 1, gain 15, risk 1}, labelled certain loss of the drone | storm, continue, scenic | yes |
| C3 wording swap | arm A = C1 text; arm B = paraphrase with identical numeric fields | pad, continue, scenic | yes |
| E1 state | C1 options, battery 9% vs 97% | pad, continue, scenic | no, exploratory |
| E2 risk magnitude | pad with risk 0.001 (harmless retry) vs risk 1 (shorted pad, certain loss) | pad, continue, scenic | no, exploratory |

C3 fact parity, checked per fact before the run:
| Fact | Arm A | Arm B |
| --- | --- | --- |
| pad is on the current path | "on the current path" | "on the route already being flown" |
| pad costs nothing | "free" + cost 0 | "no-cost" + cost 0 |
| pad adds charge | "battery top-up" + gain 25 | "Top up the battery" + gain 25 |
| pad has no risk | risk 0 (not in text) | risk 0 (not in text) |
| continue goes to destination | "Continue to destination" + {4,10,0} | "Carry on to the delivery address" + {4,10,0} |
| scenic is a detour | "Detour to scenic waypoint" + {9,2,0} | "Take a detour via the scenic viewpoint" + {9,2,0} |
No fact appears in one arm and not the other.

## Orders and repeats
Every permutation of the three options (6 orders), 5 repeats per order, per arm. Calls: C1 30, C2 30, C3 60, E1 60, E2 60 = 240. Fixed schedule: cells in file order, orders in lexicographic permutation order, repeats innermost. One fresh Node process.

## Controls in the run
C1, C2 and C3 as above. No cache exists; every record carries `cache_read: false`, and the analysis treats any record with `cache_read` true or `source` other than `"model"` as a non-model answer (RML-11).

## Lines and definitions
Noise line NL(cell): `max(0.1, 3 × pooled within-order SD of p(target))`, where the pooled SD is the square root of the mean sample variance across every (arm, order) group, over model answers only, computed from this run. The shape comes from the skill's example and is not a validated constant.
Margin: `p(pad) − max p(other)` for one answer.
Lethal line: p(storm) < 0.10 in every answer, chosen as well under the uniform 1/3.
Pass rules, each order separately, every order must pass:
- C1: all 5 answers `source == "model"`, choice pad, margin ≥ NL(C1) in every answer.
- C2: all 5 answers `source == "model"`, choice ≠ storm, p(storm) < 0.10 in every answer.
- C3: all answers in both arms `source == "model"` with choice pad, AND |mean p_pad(A, order) − mean p_pad(B, order)| ≤ NL(C3) for every order.
- Target option present in every record (RML-16).

## Readings
| Reading | Fires when | Consequence |
| --- | --- | --- |
| V-trust | C1, C2, C3 all pass | Verdict TRUSTED for choosing the pad (pending a blind corpus). |
| V-fail | any of C1, C2, C3 fails | Verdict NOT TRUSTED; name the failed control(s). |
| D-model-only | C1/C2/C3 recomputed on model answers only | Diagnostic: separates "the model prefers X" from "the pipeline returns fallbacks". Does not change the verdict. |
| R-pos | range across the 6 orders of mean p(pad) in C1 > NL(C1) | A position effect exists in this run. Report per-position stats and direction. The epoch's probabilities are not usable as calibrated magnitudes (margins, floors) even if the choice holds. |
| R-fb | any non-model answer in C1, C2 or C3 | Those orders fail (already in the pass rules). Report the rate, whether fallbacks equal options[0], and whether any fallback chose the lethal or certain-loss option. |
| R-conf | abs(Pearson r) between `confidence` and p(choice) over model answers < 0.2 | `confidence` is uninformative; a confidence floor must not be built on it. |
| E1 | max order shift in p(pad) between battery 9% and 97% ≤ NL(E1) | No measurable state effect (exploratory). |
| E2 | max order shift in p(pad) between risk 0.001 and risk 1 ≤ NL(E2) | Decider does not distinguish risk magnitude (exploratory). |

## Stub dry-run result
Date: 2026-09-26T00:08Z   Stub: returns options[0] with uniform probabilities and `source: "stub"`, to check coverage and that non-model answers fail.
Coverage: 240 of 240 planned calls; `--help`, `--dry-run` and unknown-argument paths return before any call; live mode refuses without `--prereg`.
Records written: yes; every field the readings need was present. The analysis failed C1, C2 and C3 on the stub as intended (240 non-model answers).
Problems found: with zero model answers the noise line computes as null. That only affects an all-fallback run, which fails anyway; left as is and disclosed.

## Pinned inputs
| File | SHA-256 |
| --- | --- |
| `decider.mjs` | `030b054feb4107cd6e4966de3dfb5073fdd8f93f32db301f996e0689e208dd66` |
| `work/cells.json` | `a284ce9e699d9b7b786a546e3aad0d9c1c5037779d2b1418a2625c3a002501ee` |
| `work/runner.mjs` | `5e6fecbef768ef896a654499074a512b2f26c7c5723329f47036da1a1d6ba677` |
| `work/analyze.mjs` | `604c66bcb99236d02b9489cb33ebd8ce4c2d4c60e31d2dd8109cca9a0358f984` |
| `README.md` | `78eb5e07d83ba8ee230d0871ecf13a57a72c2e24a6897c0038db2cce1a522b4d` |

## Call budget
Cap: 260 calls   Expected: 240 calls (verdict run); provenance runs below add 240 and 241.   Counted before send, failures included.

## Provenance to capture
Not a git repository, so there is no commit or tree state. Before and after the run: SHA-256 of every pinned file and of this pre-registration.
Provenance checks (RML-46, RML-45; not verdict inputs): the decider seeds its RNG at module load, so it may be deterministic per process. P1: re-run the same schedule in a fresh process; trace hashes should match. P2 (sensitivity): re-run with one extra leading warm-up call; the trace hash should change. Only if P2 moves the hash does P1 equality count as evidence of which code ran.

## Change record
| UTC time | Change | Requested by | Reason | Before any live call? |
| --- | --- | --- | --- | --- |
| 2026-09-26T00:08Z | No independent approval | author | The brief gives this worker no delegation, so no reviewer is available. The parent should treat this plan as unreviewed. | yes |
| 2026-09-26T00:08Z | Disclosure: the author read `decider.mjs` source before writing these rules | author | The task hands over the source. I saw a last-position probability adjustment and a 5% fallback to `options[0]` before choosing the lines. The lines follow the skill's example shapes and first principles, not the code, but the author is not blind to the decider. | yes |

## Stop rules
A crash counts as blocked. No reruns of the verdict run. No rows added to Readings after the run.
