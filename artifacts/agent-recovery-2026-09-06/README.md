# Target continuity and recovery qualification — 6 September 2026

The maintained native player completed **three consecutive terminal trials: two wins and one ordinary defeat**. Each trial passed pause/resume, used the visible reward controls without coordinator clicks, and ended without a stall timeout or cleanup error. This qualifies the target-continuity and bounded-recovery engineering unit. It does not establish a general win rate or a human skill profile.

Run it from the project root:

```sh
npm run playtest:agent -- --trials 3 --pause-check --max-seconds 300
```

The [runner guide](../../tools/agent-player/README.md) owns current commands and behavior. The [engineering plan](../../docs/project/AGENT-PLAYTEST-ENGINEERING.md) owns remaining scope.

## Accepted policy and results

The player keeps a selected face through brief occlusion, checks expiry before reassociation, and distinguishes observed target progress from escape timing. Search rotates in place. After 14 seconds of accumulated level-framed search, bounded reverse/lateral/settle phases lead to straight relocation. Later relocations grow from 2.5 to at most 5 seconds. Fresh targets interrupt search and relocation; poor framing stops forward movement while correcting the view. Fleeting detections pause the scan budget rather than restarting it.

| Final policy trial | Outcome | Displayed time | Scrap | Active control time |
| --- | --- | ---: | ---: | ---: |
| 1 | Won; all three waves cleared | 101s | 59 | 77.19s |
| 2 | Won; all three waves cleared | 109s | 31 | 85.08s |
| 3 | Lost during wave three | 172s | 84 | 138.22s |

The [native report](stationary-live/report.md), [exact provenance](stationary-live/report.json), and per-trial action records own these results. A loss is an accepted terminal result, so this is a **three-terminal-run pass**, not three wins. Explicit defeat/restart checking was not requested in this batch; its earlier qualification remains in the [maintained-runner record](../agent-player-2026-09-06/README.md).

All **76 focused tests** passed, including retained image cues, target expiry, distractor association, scan-budget continuity, bounded transitions, stale-frame release, modal priority and cancellation. Full `npm run verify` passed in the root checkout. The final [interruption receipt](stationary-interruption/interruption-check.json) records cleanup in **0.264 seconds**, removal of both owned processes, and no cleanup errors. [Independent reviews](review/README.md) reran tests and transition probes; the final reviewer checked the completed native report against every trial and source hash.

## Comparison and rejected variants

| Variant | Recorded outcomes | Disposition |
| --- | --- | --- |
| Unchanged baseline | Won, lost, won, lost | Establishes that the old policy could complete ordinary trials; retained older timeouts still exist |
| Original candidates A and B | One timeout each | Rejected; retained for source and behavior comparison |
| Combined tracking/framing policy | Won, then timeout | Rejected as the final policy |
| Sustained-yaw correction | Timeout | Removed command cancellation, but did not establish useful exploration |
| Fixed straight relocation | Timeout | Bounded movement alone did not resolve the live failure |
| Progressive relocation with moving search | Won, then timeout | Rejected as the final policy |
| Stationary search plus progressive relocation | Won, won, lost | Passed the configured acceptance gate |

The [comparison data](development/qualification-comparison.json) verifies identical game, installed controller and served-build identities across these runs. The ordinary game constructs `OrchardGame()` with default seed **42**, and reset restores that PRNG seed. The runner neither selects nor reads a live seed. Input, capture, rendering and menu timing vary, so these are not deterministic replays or a controlled win-rate estimate.

The [synthesis](development/SYNTHESIS.md) records why the final policy differs from the rejected versions. Reproduced defects included expiry after matching, vertical-search bias from intermittent detections, horizontal search cancelling itself, and recovery episode numbers resetting mid-escape. A separate [camera-only diagnostic](camera-calibration/receipt.json) showed native turning across different views; it did not measure angular accuracy. Pure trajectory probes did not establish full-arena coverage or physical obstacle escape.

## Responsiveness and ownership

| Measured stage | Median | p95 |
| --- | ---: | ---: |
| Input tick gap | 20.07 ms | 20.11 ms |
| Consumed-frame age | 57.49 ms | 73.62 ms |
| Total visual observation | 47.46 ms | 61.63 ms |
| Semantic menu observation | 2,859.56 ms | 3,288.75 ms |

These measurements cover the local controller and observation pipeline. They exclude model API latency and complete display latency. Menu reads run outside the combat input loop. The existing 500 ms frame-authority limit and release-before-observer-cleanup behavior remain intact.

Each run owns a separate nested Linux desktop, pointer, keyboard focus and browser profile. Andrew retains the host mouse and keyboard. The desktops share his Unix account and filesystem; they are not VMs. Stop one launcher with Ctrl-C, or all managed desktop input with **Super+Ctrl+Shift+F12** or `codex-desktop stop`.

## Limits and retention

The detector is unchanged. A [conductor foot](relocation-live/trial-001/frame-00170.jpg) and [warm notification text](relocation-live/trial-001/frame-00135.jpg) produced confirmed false detections. A review of 20 late timeout captures could not positively identify the remaining enemy, so no detector-region expansion was justified. The ground-framing cue remains specific to this scene. Image change does not prove world translation, and scan time does not measure actual angular coverage.

Novice, ordinary and expert profiles, general obstacle navigation, human enjoyment, physical controller feel, deterministic replay and the development regression-comparison loop remain open. T13 continues with measured tactics/profiles and comparison integration. This work adds no game feature or control backend.

Original structured reports, semantic observations, action/timing logs and selected captures are retained. Trailing spaces were removed from three rendered interruption reports; their JSON receipts are unchanged. Private builds and most periodic screenshots remain disposable. Rejected runtime snapshots and candidate notes preserve the source variants; their reports contain complete hashes. The main source owns the accepted implementation. After the three-trial batch, only the report formatter's explanatory text changed to clarify timing and seed evidence. The [closeout smoke](closeout-smoke/report.md) checks that final source; combat, perception, flow and installed input code match the accepted batch. The [closeout receipt](closeout-check.json) owns that comparison and workspace-release checks.
