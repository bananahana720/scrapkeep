# Agent playtesting engineering

Updated 6 September 2026. Andrew's session-close direction is to prioritize completing the remaining control and playtest engineering so the agent can accelerate game development. This document owns that work under backlog T13. The installed controller guide owns operating instructions; dated receipts own measured results. P10 still owns Andrew's feedback on play feel.

## Outcome

The maintained `npm run playtest:agent` command launches the correct game build in a separate desktop, runs a bounded playtest, saves reviewable evidence, and records outcomes. The next integration work is to compare those outcomes for regressions. The agent can use this loop while developing the game without taking Andrew's mouse or keyboard. Tooling and game changes must remain attributable to the exact versions tested.

The engineering is authorized in the session. Closing the session records the next work; it does not start a background job, create a reminder, approve a new gameplay increment, or publish the project.

## Verified starting point

- The installed controller now has named `game` and `studio` desktops, separate working directories/browser profiles, cross-process writer leases, and ten MCP tools per workspace. It supports exact-window Chromium actions and GTK button/text actions, plus bounded native input, screenshots, typing and scrolling. The existing `native_desktop` service retains its shared-desktop scope.
- Nested Hyprland gives the agent separate pointer, keyboard and focus state. Child input left the parent cursor and focused window unchanged in the measured test. The child browser uses a fresh profile with extensions disabled and an RTX 4080 OpenGL ES renderer.
- Native typing, Ctrl+Shift+K, ordinary keys after modifier release, click, drag, scroll, target/focus refusal, stop response, and lifecycle reuse/stop/restart passed. The initial installed controller passed 27 automated checks plus live MCP and application checks. The named-workspace version adds ownership, lifecycle and semantic validation; its current receipt owns the expanded check count and source hashes.
- A screenshot-only combat controller cleared all three orchard waves. The victory screen reports 155 seconds and 131 scrap. The coordinator chose rewards in visible menus and paused between development segments. This is a completed assisted run, not an unattended end-to-end player or a human enjoyment result.
- The final combat segment used a 20 ms input tick and roughly 120 ms observation cadence. Median/p95 observation age was 68.1/81.4 ms. This excludes model API latency and full display latency.
- The optimized detector matched all 319 saved screenshot detections and 26 synthetic component cases. Offline median/p95/max processing times fell from 42.45/141.65/558.38 ms to 12.66/18.89/32.97 ms.

The original assisted playthrough preceded the aggregate-modifier correction. Later maintained-runner development completed unattended clears on the corrected installed controller. Their game, player and controller hashes belong to their dated reports; those results do not imply that every later player variant clears reliably.

## Lessons to preserve in the implementation

| Finding | Mechanism already added | Implication for remaining work |
| --- | --- | --- |
| A generated text keymap can produce the wrong browser `event.code`. | Native physical input uses real evdev positions and its own compiled keymap. | Keep text entry and physical gameplay input distinct; validate application events. |
| Physical modifier key events alone did not maintain Ctrl+Shift for the letter key. | Aggregate libxkbcommon state and explicit Wayland modifier messages, with neutral cleanup. | Keep the live shortcut check in reusable verification. |
| A click could beat the compositor's cursor warp and hit the previous location. | A 40 ms positioning interval before button press. | Replace assumptions with observable cursor synchronization if available; do not remove the delay without proof. |
| Screenshot processing blocked timely control; a foreground tree made per-pixel component search pathological. | Separate input owner and observer; equivalent horizontal-span component merging. | Measure each stage independently and keep capture/detection away from the input owner. |
| A generic green-panel heuristic falsely ended a trial. | More specific game-menu geometry checks in the experiment. | Replace brittle modal detection with a tested screen-state model and accessible menu signals. |
| Failed startup and concurrent lifecycle commands could lose process ownership. | Per-child cleanup, start-time identities, bounded waits and a lifecycle lock. | Preserve ownership through cancellation, restart and disconnect tests. |
| A fresh Chromium profile still received a system-injected extension popup. | Extensions/default apps disabled in the child. | Verify window inventory and keep accessibility tied to exact PID/frame identity. |
| Renderer accessibility did not enable Chromium's native AT-SPI bridge. | Child-scoped ACCESSIBILITY_ENABLED=1, NO_AT_BRIDGE=0 and complete renderer accessibility. | Treat native app registration as separate from browser rendering and test each toolkit when needed. |
| A passed run and a passed later input fix are different evidence. | Dated screenshots, logs and installed source hashes exist. | The maintained runner must record exact game/controller/perception versions for every run. |

## Operational desktop foundation

On 6 September, the coordinator and a delegated agent used the installed controller in separate desktops. Chromium button actions and GTK button/text actions passed. GTK actions worked while Chromium retained child focus. A fresh orchard smoke test used a semantic start action, bounded native movement/fire, Escape pause, and a semantic dashboard observation. This establishes the control path; it is not another full playthrough.

Managed actions require a bounded actor lease and retain a per-workspace cross-process lock through cleanup. The historical direct player bypasses that ownership layer and must not run concurrently in a claimed desktop. The shared emergency stop remains independent of operation locks.

The [operations guide](/home/andrew/.local/share/codex-native-input/agent-desktop/README.md) owns commands and assignments. The [named-workspace receipt](/home/andrew/.local/share/codex-native-input/agent-desktop/verification/workspaces-2026-09-06/receipt.json) owns current checks, timings, captures and source hashes. [ADR 0006](../adr/0006-agent-playtest-workspaces.md) records the architecture.

## Ordered work and completion checks

The order below is the default execution sequence. Complete and verify each unit before expanding scope. Broader desktop parity follows demonstrated game-development needs.

| Order | Work | Complete when |
| --- | --- | --- |
| 1 | Maintain one controller and a reusable game runner. Move executable player/perception code out of ignored disposable artifacts; remove copied input implementations; provide explicit configuration, source provenance, startup checks and a single local command. | A fresh process launches the intended build, discovers the child dynamically, verifies capture and input, runs a bounded smoke trial, and closes or leaves it paused according to the command. No temporary paths or copied core files are required. Final installed input changes receive a new full game run. |
| 2 | Complete unattended game flow. Model start, pointer lock, active combat, pause, reward selection, equipment, defeat, victory and restart. Add semantic menu actions using fresh observations, unique targets and refusal of stale/ambiguous matches. | Three consecutive trials reach a correctly reported terminal state without coordinator menu clicks. Reward choice is configurable. At least one defeat/restart path and pause/recovery path are exercised. Inputs release on timeout, focus loss, stop and disconnect; failures receive accurate reasons. |
| 3 | Produce reproducible evidence and timing. Record game and controller hashes, configuration, available scenario seed, environment, timestamps, actions, outcomes, latency stages and actual video where needed. Keep screenshot-only play separate from instrumented diagnostics. | One command produces a concise report and replayable action record. A saved failure can be reproduced or explicitly marked non-reproducible. Reports distinguish win/loss, timeout, perception failure, stale frame, focus loss and infrastructure error. A run cannot be compared against a different build by accident. |
| 4 | Improve visual tactics and player profiles. Handle occlusion, obstacles, telegraphs, boss behavior, spacing and ability timing. Add deliberately bounded novice, ordinary and skillful control profiles. | Repeated comparisons on the same supported scenarios report survival, clear time, damage, ability use, stalls and input/observation latency. Improvements are measured against the current controller. Profiles are test strategies until human play validates their labels. |
| 5 | Integrate the playtest loop with development. Keep fast simulation/build checks and native behavioral tests complementary. Compare baseline/candidate evidence and report concrete defects with reproduction steps. | A representative input/camera change and a gameplay change are checked through build, native run, comparison and reviewable findings without Andrew operating the test. An intentionally introduced bounded regression is detected, then removed. |
| 6 | Expand only the missing tool coverage. Add GTK/Qt/editor accessibility, semantic actions or other compositor support when a game-development task needs them. | Each admitted app has an identity/capture/input/stop test and documented limits. A full macOS clone, remote streaming, new VM infrastructure and unrelated desktop integrations do not displace orders 1–5 without a concrete need. |

The maintained source now lives in `tools/agent-player/` and imports the installed controller. It builds privately, owns a dedicated desktop lease, handles visible menus, and writes source-versioned reports. Core start, combat, default reward/equipment, pause/resume, defeat, victory and restart paths have live evidence. Arbitrary equipment checkbox editing remains unsupported; defaults auto-equip. Evidence records are inspectable and rerunnable, not deterministic replay.

The [maintained-player qualification](../../artifacts/agent-player-2026-09-06/README.md) records 44 focused tests, project verification, a final smoke/pause pass, three consecutive defeat/restart cycles and a 0.316-second interruption cleanup. Two earlier visual variants won and then timed out on their next trial. Both latest visual configurations timed out; reliable full clears are unfinished.

The next engineering unit is target continuity and obstacle recovery, measured against retained stall captures before another bounded live comparison. Known detector limits include occluded or merged faces and decorative scenery faces. Follow that with player profiles and baseline/candidate regression comparison. Do not start another open-ended plugin search unless this implementation encounters a specific missing capability.

## Evidence boundaries

The separate desktop shares Andrew's Unix user and filesystem authority; it is not a security VM. Direct tool discovery inside a newly refreshed Codex task has not been verified, though MCP registration and actual stdio calls passed. Chromium semantic actions and GTK button/editable-text controls are verified. General editor, Qt, modal-dialog and other compositor coverage remain open. Physical controller hardware and Andrew's judgment of fun/readability remain part of P03/P10. Agent success does not close either item.

The original `/` and `/orchard.html` entries remain distinct. No new game feature, dependency upgrade, publication or remote backup is implied by this tooling priority. Existing project verification still applies to project changes.

## Reference map

- [Maintained runner guide](../../tools/agent-player/README.md)
- [Maintained player qualification and retained failures](../../artifacts/agent-player-2026-09-06/README.md)
- [Controller operations](/home/andrew/.local/share/codex-native-input/agent-desktop/README.md)
- [Installed controller verification](/home/andrew/.local/share/codex-native-input/agent-desktop/verification/receipt.json)
- [Dated playtest and rerun notes](../../artifacts/local/player-playtest-2026-09-06/README.md)
- [Full research and implementation report](/home/andrew/.codex/visualizations/2026/09/06/01a0756b-5162-7ec0-a604-8b599be7ff2e/linux-computer-use-progress.md)
- [Game project desk](README.md), [backlog](BACKLOG.md), [current game verification](../LIGHTNING-VERIFICATION.md)

Disposable evidence may be cleaned under `artifacts/local`; the engineering plan and its evidence limits survive here. The executable player is maintained outside disposable artifacts. Keep dated qualification receipts under `artifacts/agent-player-2026-09-06/` and routine runs under `artifacts/local/agent-playtests/`. The runner guide owns current commands; this plan owns remaining scope.
