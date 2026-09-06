# Maintained Linux player qualification — 6 September 2026

The independent desktop and unattended game-flow runner are operational. Combat reliability remains unfinished: development variants completed two full clears, but each subsequent trial timed out, and both latest visual configurations timed out. T13 remains active for visual tactics, equipment coverage, player profiles and regression comparison.

Run from the project root:

```sh
npm run playtest:agent -- --smoke-seconds 12 --pause-check --max-seconds 70
```

The [runner guide](../../tools/agent-player/README.md) owns commands and current behavior. The [engineering plan](../../docs/project/AGENT-PLAYTEST-ENGINEERING.md) owns remaining work. This directory preserves dated evidence, including failed trials; it is not a claim that later source versions reproduce every earlier result.

## Results

| Check | Recorded result | Evidence |
| --- | --- | --- |
| Final source: native smoke and pause/resume | Passed; 12.02 seconds of active policy time | [Smoke report](smoke-current/report.md) |
| Three consecutive ordinary defeat/restart cycles | All three reached the visible defeat screen, restarted and passed; passive policy made no attacks | [Defeat report](defeat-cycles/report.md) |
| Final source: interrupt during captured gameplay | SIGINT classified as interrupted; owned browser/compositor removed in 0.316 seconds; no cleanup errors | [Cancellation receipt](interruption-current/interruption-check.json) |
| Earlier visual development 04 | Won in displayed 87 seconds, 45 scrap; second trial timed out; batch failed | [Both trials](visual-development-04/report.md) |
| Earlier visual development 05 | Won in displayed 158 seconds, 43 scrap; second trial timed out; batch failed | [Both trials](visual-development-05/report.md) |
| Current perception/policy, default Ground Loop + Echo | Timed out at the 300-second trial limit; pause/resume passed | [Default visual report](default-visual/report.md) |
| Final source, Ground Loop + Shear Package comparison | Timed out at the 300-second trial limit; pause/resume and reward selection passed | [Companion comparison](companion-comparison/report.md) |
| Focused runner verification | 44 tests passed; independent forced output-directory race allowed exactly one owner | [Review receipt](review-current/receipt.md), [test log](review-current/self-test.log) |
| Project verification | `npm run verify` passed | [Verification log](development/project-verify.log), [machine report](development/project-verify.json) |
| Workspace release and source comparison | All test session and owner files absent; final smoke, interruption and companion comparison match closeout source | [Closeout receipt](closeout-check.json) |

The defeat batch and default visual trial preceded only the final output-directory reservation change and its tests. Their control/perception code matches closeout. The earlier wins preceded perception and/or policy changes, so they establish that unattended full clears occurred, not that the final visual policy reliably wins. Each report records exact game, runner, installed controller and served-build hashes. Source and controller stayed unchanged during every run listed above.

`passed` is acceptance of the configured run. An ordinary loss is a valid terminal outcome. An intentionally interrupted run correctly has `passed: false`, while its cancellation probe passes. Batches stop on the first timeout or infrastructure failure rather than silently skipping it.

## Responsiveness and ownership

The final companion comparison supplied 12,136 input-tick gaps and 2,031 consumed frames. Input gap p50/p95/max was **20.07/20.10/50.28 ms**; consumed-frame age was **57.61/71.27/126.12 ms**. Total visual observation p95 was **57.64 ms**. Semantic menu reads had a **3,617.56 ms p95** and ran outside the combat input loop. These are local pipeline measurements, not model API latency, complete display latency or a human reaction-time comparison.

The runner leases a named nested Hyprland desktop, uses the installed native input core, and releases controls before waiting for observation cleanup. Another agent can use another named desktop while Andrew uses the host pointer and keyboard. The separate desktop shares the Unix account and filesystem; it is not a VM. The installed [workspace qualification](/home/andrew/.local/share/codex-native-input/agent-desktop/verification/workspaces-2026-09-06/README.md) owns the earlier native-input and parent-focus checks.

Stop with **Ctrl-C**, **Super+Ctrl+Shift+F12**, or `codex-desktop stop`. The last two stop all managed agent desktop input. Final cleanup verification found no test workspace session or owner files. The interactive `game` session remained running; `studio` was configured but not running at closeout.

## What remains and why

The visual policy can miss occluded faces, merge faces into machine-body regions, and mistake decorative scenery faces for enemies. A narrow warm-eye check now rejects a confirmed white nameplate false positive while preserving the saved worker examples. Broadening the search region, requiring exactly two eye blobs, and increasing shape compactness failed to solve the retained cases without dropping true targets. These experiments are preserved under `development/`; none establishes corpus-wide accuracy.

Lost-target recovery now corrects skyward framing, searches vertically and briefly backs away while strafing. Its movement survives transient detections, and blind jump/ram inputs are suppressed. There is still no obstacle map or reliable progress measurement, so this does not solve boss occlusion or guarantee a clear. The next unit is target continuity and obstacle recovery, measured against the retained stall captures before another bounded live comparison.

Combat used screenshots and physical key/mouse input. Menu decisions used exposed accessibility controls. No hidden game state, QA teleports, health edits, coordinator reward clicks or deterministic seed produced these results. Human fun, physical controller feel, realistic skill profiles, deterministic replay and video remain unproven or unimplemented.

## Retention

Retained run directories include original reports, action/timing records, semantic observations and selected screenshots. Periodic screenshots and private builds were omitted; their original paths and build hashes remain in the reports. The full disposable runs originally lived under `artifacts/local/agent-playtests/`. Older `baseline-timeout`, `passive-restart`, `passive-restart-final`, `interruption` and `review` directories are development evidence; their names do not override source hashes or the current-result table above.
