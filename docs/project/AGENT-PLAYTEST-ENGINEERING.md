# Agent playtesting engineering

Updated 6 September 2026. Andrew's session-close direction is to prioritize completing the remaining control and playtest engineering so the agent can accelerate game development. This document owns that work under backlog T13. The installed controller guide owns operating instructions; dated receipts own measured results. P10 still owns Andrew's feedback on play feel.

## Outcome

The maintained `npm run playtest:agent` command launches the correct game build in a separate desktop, runs a bounded playtest, saves reviewable evidence, and records outcomes. The next integration work is to compare those outcomes for regressions. The agent can use this loop while developing the game without taking Andrew's mouse or keyboard. Tooling and game changes must remain attributable to the exact versions tested.

The engineering is authorized in the session. Closing the session records the next work; it does not start a background job, create a reminder, approve a new gameplay increment, or publish the project.

## Carry-forward map

The maintained runner landed in commit `db7d8cf`. Target continuity and bounded recovery landed in `3077799`. The latter passed three consecutive terminal trials, won/won/lost, with all pause checks passed. Its [qualification](../../artifacts/agent-recovery-2026-09-06/README.md) owns the 76-test result, native timings, interruption check and retained failures. This is the current starting point; the assisted experiments below explain how the controller developed.

| Reusable capability | Maintained location | Carry-forward boundary |
| --- | --- | --- |
| Native physical input, text, pointer, capture and exact-window semantic actions | [Installed controller guide](/home/andrew/.local/share/codex-native-input/agent-desktop/README.md) | Imported by the game runner. Preserve one implementation and its focus, identity and stop checks. |
| Named agent desktops and actor leases | Controller `seat.py`, `ownership.py` and [ADR 0006](../adr/0006-agent-playtest-workspaces.md) | One GUI actor per leased desktop. Separate Git worktrees isolate source edits. Both share the host's Unix authority. |
| Build, play, menus, cleanup and provenance | [Maintained runner](../../tools/agent-player/README.md) and `scripts/agent-playtest.mjs` | One local command uses a private build and an exclusive evidence directory. No temporary player copy is required. |
| Fast assertions and native behavioral checks | [Contribution guide](../../CONTRIBUTING.md#verification) | Project verification, focused player tests and native trials establish different claims. Human feel remains P10. |
| Recovery cases and comparison material | [Recovery probe](../../tools/agent-player/tests/probe_recovery.py), fixtures and [retained qualification](../../artifacts/agent-recovery-2026-09-06/README.md) | Failed variants remain available with exact source and game identities. The reusable development comparison loop is still open. |
| Recoverable controller source | [Source snapshot and manifest](../../artifacts/agent-infrastructure-2026-09-06/README.md) | The archive preserves the external controller dependency and registration references. It is not an active fork or a tested portable installer. |

The snapshot keeps the successful source bytes in the project history. Browser profiles, runtime leases and full host configuration remain outside it. There is no configured Git remote, so this session has not established an off-machine backup.

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
| A generic green-panel heuristic falsely ended a trial. | The maintained flow now requires positive semantic screen states and unique visible controls. Pixel menu cues release input before that read. | Keep gameplay interruption separate from authoritative victory or defeat classification. |
| Failed startup and concurrent lifecycle commands could lose process ownership. | Per-child cleanup, start-time identities, bounded waits and a lifecycle lock. | Preserve ownership through cancellation, restart and disconnect tests. |
| A fresh Chromium profile still received a system-injected extension popup. | Extensions/default apps disabled in the child. | Verify window inventory and keep accessibility tied to exact PID/frame identity. |
| Renderer accessibility did not enable Chromium's native AT-SPI bridge. | Child-scoped ACCESSIBILITY_ENABLED=1, NO_AT_BRIDGE=0 and complete renderer accessibility. | Treat native app registration as separate from browser rendering and test each toolkit when needed. |
| A passed run and a passed later input fix are different evidence. | Dated screenshots, logs and installed source hashes exist. | The maintained runner must record exact game/controller/perception versions for every run. |
| Reassociation before expiry revived an old target identity. | Target age is checked before matching returning detections. | Validate lifetime before association whenever an observed object can disappear. |
| Brief detections repeatedly restarted vertical scanning and postponed search. | Persistent combat timing and an accumulated level-framed scan budget survive interruptions. | Decide explicitly which clocks pause, continue or reset. Test intermittent evidence, not only steady inputs. |
| Coupled forward turning did not establish useful exploration. | Search rotates in place; bounded relocation moves straight and yields to new targets. | Separate observation from repositioning when concurrent movement undermines the search. Command duration is not measured spatial coverage. |
| Policy memory could outlive the image that justified an action. | Existing frame authority still expires after 500 ms and releases input before observer cleanup. | Remembered state can guide the next observation; it cannot renew permission to keep acting on stale pixels. |
| A new strategy won once and then stalled. | Candidate source stayed frozen through repeated terminal trials; unsuccessful variants remain retained. | Require repeated matching-scenario evidence before admission. Small batches do not establish a win rate or human skill. |
| A fixed scenario seed was mistaken for varying random scenarios. | The ordinary constructor's seed 42 and timing limits are now explicit in reports. | Same seed is insufficient for deterministic replay when action, capture and rendering timing vary. |

These patterns are already represented in code, focused tests or provenance fields. Future work extends those mechanisms instead of relying on a new agent to remember prose. Tests cover the named failures; they do not prove general obstacle navigation or human-like tactics.

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

The earlier [maintained-player qualification](../../artifacts/agent-player-2026-09-06/README.md) records 44 focused tests, project verification, a final smoke/pause pass, three consecutive defeat/restart cycles and a 0.316-second interruption cleanup. Two visual variants won and then timed out on their next trial. Its last two configurations timed out. The recovery qualification below supersedes that combat acceptance state while retaining those failures.

The [target-continuity and recovery qualification](../../artifacts/agent-recovery-2026-09-06/README.md) completes that engineering unit: the final policy reached three consecutive terminal outcomes, won/won/lost, with pause/resume in each and no stall timeout. Seventy-six focused tests and project verification passed; same-policy interruption cleaned up in 0.264 seconds. Stationary search now has a persistent scan budget, target association survives brief occlusion, and bounded relocation changes viewpoint without mixing translation into the scan. The baseline and rejected variants remain in the qualification, so this is not a general win-rate claim.

Next are measured tactics/player profiles and baseline/candidate regression comparison. Known perception limits now include confirmed conductor-foot and warm-notification false positives, plus occluded or merged faces. Keep these cases in comparisons before claiming broader visual reliability. Do not start another open-ended plugin search unless the implementation encounters a specific missing capability.

## Resume the next engineering unit

1. Read this guide, the runner guide and the latest retained qualification. Inspect branch and working changes before editing. At closeout, unrelated publisher/design documentation remained uncommitted; it is owner work to preserve.
2. Inspect the installed controller and current tool inventory. Discover live workspace identities when a native run starts. Do not reuse a PID, window address or lease from a receipt. The source snapshot supports drift inspection without replacing the installation.
3. Run `npm run test:agent` and `npm run verify` for the current checkout. Use the runner guide's bounded smoke and pause check to establish the current native path before changing tactics.
4. Begin order 4 with a fixed scenario/configuration matrix and a baseline report. Define the metric, accepted terminal outcomes and failure categories before measuring one tactical or profile change. Keep the ordinary game and input controller fixed during that comparison. Treat novice/ordinary/expert names as test strategies until validated by human play.
5. Carry the same evidence contract into order 5's automated comparison. Its completion check requires detecting and then removing a bounded introduced regression. A new gameplay increment still follows its own project approval.

The first resumed engineering action is the fresh baseline and comparison definition. This closeout launches no tests in the background and makes no scheduling commitment. P10's human assessment of movement feel and build escalation remains the product decision the tooling supports.

## Evidence boundaries

The separate desktop shares Andrew's Unix user and filesystem authority; it is not a security VM. Direct tool discovery inside a newly refreshed Codex task has not been verified, though MCP registration and actual stdio calls passed. Chromium semantic actions and GTK button/editable-text controls are verified. General editor, Qt, modal-dialog and other compositor coverage remain open. Physical controller hardware and Andrew's judgment of fun/readability remain part of P03/P10. Agent success does not close either item.

The original `/` and `/orchard.html` entries remain distinct. No new game feature, dependency upgrade, publication or remote backup is implied by this tooling priority. Existing project verification still applies to project changes.

## Reference map

- [Maintained runner guide](../../tools/agent-player/README.md)
- [Target continuity and recovery qualification](../../artifacts/agent-recovery-2026-09-06/README.md)
- [Maintained player qualification and retained failures](../../artifacts/agent-player-2026-09-06/README.md)
- [Controller operations](/home/andrew/.local/share/codex-native-input/agent-desktop/README.md)
- [Installed controller verification](/home/andrew/.local/share/codex-native-input/agent-desktop/verification/receipt.json)
- [Dated playtest and rerun notes](../../artifacts/local/player-playtest-2026-09-06/README.md)
- [Full research and implementation report](/home/andrew/.codex/visualizations/2026/09/06/01a0756b-5162-7ec0-a604-8b599be7ff2e/linux-computer-use-progress.md)
- [Game project desk](README.md), [backlog](BACKLOG.md), [current game verification](../LIGHTNING-VERIFICATION.md)

Disposable evidence may be cleaned under `artifacts/local`; the engineering plan and its evidence limits survive here. The executable player is maintained outside disposable artifacts. Keep dated qualification receipts under `artifacts/agent-player-2026-09-06/` and `artifacts/agent-recovery-2026-09-06/` and routine runs under `artifacts/local/agent-playtests/`. The runner guide owns current commands; this plan owns remaining scope.
