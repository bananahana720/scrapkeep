# W1-133a source identity and Tarn round zero

PR head `27c6e5fb137d11ecc5461bab574a357493e84872`, stage base `4f9017c58537e6e6785c00f6d4d45cdcd6e6f1be`. These runs used headless Godot 4.7.2.stable.official.ed1daf0bf and scratch homes. [Fast check](fast.json) · [Focused checks](focused.json)

| Check | Observed |
| --- | --- |
| Previous producer | A tracked edit to park_defs.gd was present before dispatch. The producer at `aa6510a4f` published its original HEAD after eight valid gameplay and control passes. This reproduces the stamping gap. |
| Clean source | Eight clean passes and controls completed. Every worker recorded the pinned commit. |
| Source changed during a run | The caller was edited after its first completed row. The producer exited 2 and preserved the previous receipt byte for byte. [Control outcomes](provenance-controls.json) |
| Focused suite | 6 named tests passed on the first run. The suite recorded a failure at the miniboss charge reach assertion. The [candidate rerun](body-solo.json) failed the same assertion and the [untouched stage control](body-stage.json) failed the same assertion. A [disposable copy of the stage test](body-direction-probe.json) passed when it sampled along the committed charge direction. The matchup fixture covers dirty inputs before dispatch and between workers, different checkouts at one commit, and a path alias for the same checkout. |
| Complete sweep | 624 ordinary passes and 96 zero-lead controls. Every row reported the pinned head. [Raw receipt](fast-threat.json) |
| Straight | 208 of 208 lost zero hull. 32 encountered a committed threat. Attacking kinds: ramp_flipper. |
| Weaving | 208 of 208 lost zero hull. |
| Stopped | 208 of 208 lost hull. |
| Zero lead | 96 of 96 controls witnessed a real strike and counted zero threats. |
| Comparison with the retained run | Across 624 matched rows, 0 threat counts and 0 hull-loss totals changed. |

### Where a straight pass met a threat

| Stage and pack | Straight passes with a threat | Committed threats |
| --- | --- | --- |
| 1/run_down | 0 / 16 | 0 |
| 1/grounded | 0 / 16 | 0 |
| 1/live_wire | 0 / 16 | 0 |
| 1/sluice_line | 0 / 16 | 0 |
| 1/flap_run | 16 / 16 | 16 |
| 1/elite | 0 / 16 | 0 |
| 2/run_down | 0 / 16 | 0 |
| 2/grounded | 0 / 16 | 0 |
| 2/shift_crew | 0 / 16 | 0 |
| 2/crossed_wires | 0 / 16 | 0 |
| 2/weir_strung | 0 / 16 | 0 |
| 2/flap_line | 16 / 16 | 24 |
| 2/elite | 0 / 16 | 0 |

Raw receipt SHA256 `cdce70bbc7b8171557d89f1ab509ab5dd889520fc9147c005ae5e737add9a189`. The earlier data stay at their recorded head. The audit did not establish mixed inputs in that data.

Shared-route and warning-picture proof, Sol gameplay QA and Gate admission remain pending.
