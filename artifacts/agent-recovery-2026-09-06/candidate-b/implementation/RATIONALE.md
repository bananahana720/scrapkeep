# Candidate B recovery rationale

PASS+NOTES at evidence level 4. This candidate gives the maintained player target continuity and bounded obstacle-recovery attempts. Actual escape success and game completion need the parent's native comparison.

The worktree is `/tmp/scrapkeep-recovery-b`, branch `codex/agent-recovery-b`, based on HEAD `db7d8cfd21f5bbb710e756c2eda3f285c15f87f6`. Changes are uncommitted. No native input, desktop, browser, game source, installed controller, dependency, or publication changes were made.

## Data and decisions

`TargetTrack` stores an identity number, screen point, face box, last-seen active time, progress time, best observed width, and best alignment error. Association uses screen distance and width similarity. It prefers the existing track over a new face near the crosshair. An unmatched track remains for 0.8 seconds, during which movement stops and restrained yaw follows its last position. A fresh unmatched face may replace it after that interval.

`Recovery` stores one phase, reason, start, deadline, attempt count, and side. The phases are track, occluded, search, reverse, lateral, settle, and exhausted. No-target search starts deliberate forward movement after 0.8 seconds. Loss beyond 3 seconds triggers escape. Each escape reverses for 0.8 seconds, strafes for 0.9 seconds, then settles for 0.3 seconds. The side alternates. The next attempt cannot start until 6 seconds after the previous attempt started. Four unsuccessful attempts lead to exhausted state and empty Intent. A new target or measurable target geometry progress can resume play.

A target that has neither grown 15 percent nor improved normalized alignment by 0.06 for 7 seconds can trigger escape even while the detector repeatedly sees its face. This is an image-derived progress proxy. It does not establish player translation, attack damage, or a collision.

The observer computes image change on two side bands from a 64 by 48 grayscale sample. It excludes the main HUD and center avatar region. It attaches only changed fraction, mean luminance delta, and measurement basis. The sample stays private to the observer. Low measured change lasting 1.5 seconds triggers an escape reason. Pixel change never resets target-progress time.

Combat receives only an additional compact policy diagnostics field in each saved combat-frame record. The existing frame-age release, expiry, lease calculation, dispatch, and cleanup paths remain unchanged. Target memory grants no input authority.

Model the Domain shaped the two dataclasses and phase transitions. Poteto-mode's bounded no-nested-agent exception kept implementation in this one worktree. The parent owns independent review and admission.

## Alternatives rejected

| Alternative | Reason |
| --- | --- |
| Expanded eye detector | The inspected timeout has a large central player assembly and no verified worker face. Widening color thresholds risks calling the player or scenery an enemy. Existing detection stays unchanged. |
| Nearest face every frame | It abandons a selected face when a distractor reaches the crosshair. |
| Image change as movement success | Yaw, animation, and avatar motion can change pixels without translation. |
| Unlimited escape cycles | A fresh sequence of frozen rendered frames otherwise renews movement forever. Exhausted state makes this failure observable and releases input. |
| Separate recovery input worker | It would split input ownership and weaken the existing lease and cleanup guarantees. |

The exhaustion threshold can stop an otherwise viable search. The parent should compare this tradeoff against continued movement in long targetless scenes. Association is geometric, so overlapping similar faces can exchange identity. Sky recovery remains the existing hysteresis heuristic. Side-band change is not optical flow and can miss activity outside its sample.

## Verification

`npm run test:agent` passed 59 tests. The retained test log is `artifacts/local/recovery-candidate/test-agent.log`. New cases cover distractor continuity, brief occlusion, replacement after expiry, approaching distant faces, no progress despite image change, target growth, bounded recovery phases, exhausted state, passive behavior, fresh frozen scenes, and stale release with a remembered target. A combat-loop test drives fake fresh captures for 32 seconds and asserts that exhausted recovery clears the native state.

Two existing scheduling expectations changed. Search now moves forward after escape instead of standing still. The vertical-scan test samples through the full escape interval rather than expecting the old backpedal schedule. Existing menu, stale-frame, cancellation, cleanup, and flow guarantees remain tested.

The command below produced `artifacts/local/recovery-candidate/retained-probe.json`, including source and input hashes.

```sh
/home/andrew/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/agent-player/tests/probe_recovery.py --retained-root /home/andrew/Projects/test-game-2/artifacts/local/agent-playtests --output artifacts/local/recovery-candidate/retained-probe.json
```

The probe processed 8 retained images. The four worker-face fixture targets remain detectable. The nameplate fixture and all 6 timeout images yield zero targets. Repeating each image with fresh capture identities reaches exhausted state by 25.8 simulated active seconds and returns empty Intent. Comparing the two different fixtures gives a changed fraction of 0.8095. Those unrelated screenshots are not a movement sequence.

Detection plus scene measurement took median 10.76 ms, p95 16.95 ms, and maximum 19.34 ms over 80 local calls. This excludes image capture, decode, native dispatch, and real gameplay. `git diff --check` passes. The parent owns full project verification and native trials.

## Throughput checkpoint

- Blocking first steps. The parent supplied the integration contract and resolved NumPy and Pillow documentation. This candidate read poteto-mode, Model the Domain, project conventions, and the retained timeout before code.
- Independent workstreams. Candidate B owns this worktree. The parent compares it with the separate candidate.
- Shared mutable state. Only the existing observer publishes frames. Policy state belongs to the existing combat input owner.
- Smallest safe decomposition. One writer owns the coupled policy, image evidence, diagnostics, and regression tests. Nested delegation is forbidden by the brief.

Architectural comparison and independent review belong to the parent's arena. Commits, rebases, PR creation, and live trials are excluded by the candidate contract. The next step is serial parent review and native comparison against the unchanged baseline.
