# Candidate A

PASS+NOTES at evidence level 4 for controller-free tracking, recovery scheduling, image-change measurement and stale-frame release. Native obstacle escape and game outcomes are INCONCLUSIVE because this candidate did not open a desktop or dispatch input.

Worktree `/tmp/scrapkeep-recovery-a`. Branch `codex/agent-recovery-a`. Base HEAD `db7d8cfd21f5bbb710e756c2eda3f285c15f87f6`. Changes are uncommitted.

The maintained player now retains its selected screen target across a closer-to-crosshair distractor and up to 0.7 active seconds of occlusion. Association uses previous center and box width, so it establishes geometric continuity rather than semantic enemy identity. Loss beyond the grace period discards the old track. During occlusion it strafes and avoids issuing look correction from a remembered pixel position.

Model the Domain changed the implementation choice. `TargetTrack` owns center, box, last-seen time, selection time and apparent-approach history. `RecoveryState` owns phase, reason, phase start and side. This replaces the old independent loss/disengagement clocks. Existing sky hysteresis remains a framing cue.

Search strafes while yawing and scanning vertically. After three search seconds, or two seconds of unchanged peripheral pixels, a bounded escape sequence backs and strafes for 0.8 seconds, strafes while yawing for 0.8 seconds, and advances diagonally for 1.2 seconds. Each episode alternates sides. Reacquiring a target cannot interrupt the sequence, which exits after 2.8 active seconds, rounded to the next fresh observation. Menus pause the existing active clock.

A distant target that has not grown in apparent width by 15 percent in 4.5 seconds triggers recovery even if animation or camera movement changes the image. A persistent nearer target triggers after seven seconds. These are bounded fallback attempts, not proof that an obstacle exists. Width growth is labeled apparent approach and never claims world translation.

The observer samples 544 grayscale values from two peripheral scene bands at a 64 by 36 image scale. It excludes the central player region and the normal HUD bands. Signed subtraction produces changed-pixel fraction and mean luminance difference. Only these scalars enter frame diagnostics. Sample arrays stay in the observer thread. New diagnostics include selected geometry and age, phase, reason, phase age, side and progress evidence.

## Alternatives rejected

| Alternative | Reason |
| --- | --- |
| Broaden the dark-face detector around timeout screenshots | The inspected default timeout has a large player assembly over the crosshair. The existing five timeout images still produce zero verified faces. Identifying a new enemy cue requires a separately grounded detector change. |
| Reset loss whenever any face appears | A distractor can otherwise erase selected-target history and prevent recovery. |
| Treat changing pixels as forward progress | Yaw, animation and scenery motion can change pixels without useful translation. Apparent target growth is evaluated separately and still labeled uncertain. |
| Keep stationary scans between backpedal episodes | A stalled view can keep scanning forever. Every search and escape phase now includes deliberate movement. |
| Add optical flow, another control backend or hidden-state navigation | These add dependencies or authority beyond this task. A compact image comparison and policy state fit the established boundary. |

## Executed verification

`npm run test:agent` passed all 56 tests. The log is `artifacts/local/recovery-candidate/test-agent.log`.

The suite tests target continuity through a nearer distractor, brief occlusion and later reacquisition, expiry of a track despite an unrelated detection, persistent-face recovery despite changing pixels, apparent approach, timed phase exits and alternating sides, passive behavior, sky hysteresis, retained real images, center-avatar/HUD exclusion and signed luminance differences. The original flow, failure, cleanup and frame-authority tests still pass. An additional combat test establishes that a remembered target cannot extend the original frame's 0.5-second authority lease.

Three previous policy expectations changed deliberately. Search now moves after an escape instead of becoming stationary; escape lasts 2.8 seconds instead of 1.5; vertical scanning is checked after the new escape phases rather than during backpedal. Stale-frame, passive, cleanup and flow expectations were retained.

Executed retained-image probe:

```sh
/home/andrew/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/agent-player/tests/probe_recovery.py /home/andrew/Projects/test-game-2/artifacts/agent-player-2026-09-06
```

Output is `artifacts/local/recovery-candidate/retained-probe.json`. It includes source hashes, retained-image hashes, targets, phase traces and measured timing. All five timeout screenshots still yield zero detections. Identical-image change is zero. Cross-view changed fractions range from 0.5607 to 0.9485. Each frozen-image policy replay enters back, side and advance phases and resumes search with the alternate side on the next episode. Detection plus scene sampling averaged 14.398 ms with a 17.387 ms maximum across five images on this run. This small offline sample excludes capture, modal detection and native dispatch; it is not a live performance estimate.

`git diff --check` passed. No source file outside the assigned Python scope was changed. `combat.py` has one added diagnostics call; input authority, release, cleanup and native dispatch are unchanged. No dependency, game/controller edit, commit or publication occurred. Full `npm run verify` and native comparison belong to parent integration because this candidate's write scope is restricted.

## Remaining limits

Screen-space association can confuse nearby similar faces and can drop a real target after large camera movement. The detector remains blind where it previously returned no target. Peripheral visual stillness is conservative evidence, not an obstacle classifier. Flat ground or rotation may confuse it. Timed recovery can move toward a different obstacle. The parent reported a fresh unchanged baseline win during this task, so offline progress does not establish that this candidate improves win rate or completion time.

The next action is the parent's same-settings native comparison against the unchanged baseline, retaining successes and failures with source hashes. Admit this candidate only if the live outcomes and recovery traces justify it.
