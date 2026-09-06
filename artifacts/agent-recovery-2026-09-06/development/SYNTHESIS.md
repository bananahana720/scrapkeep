# Target continuity and recovery synthesis

The accepted policy separates stationary scanning from bounded straight relocation. Its ordinary native acceptance batch passed with two wins and one defeat, all pause checks passed, and no stall timeout or cleanup error. The preceding progressive-relocation batch won once in displayed 121 seconds with 88 scrap, then timed out. No candidate is admitted by offline tests alone.

## Candidate choice

Candidate B supplies the core state structure: size-aware association, separate observed-progress and retry clocks, forward search, and original combat strafe. Candidate A supplies continued bounded retries. The fresh Astra max judge scored both initial candidates 8/10 and provisionally preferred A because B permanently stopped after four attempts. Removing that stop from B preserves the stronger progress model with fewer grafts. A's escape completion incorrectly reset observed target progress; that behavior was not retained.

Both original candidates timed out in one native trial each. The combined 65-test version won once, then timed out. The 67-test sustained-yaw version and 70-test fixed-relocation version each timed out. The unchanged game creates OrchardGame with its default seed of 42 and resets that PRNG seed between runs. The runner does not set or read a live seed. Asynchronous input/capture timing changes behavior, and some development runs overlapped; these are not deterministic replays or a controlled performance ranking. Reports and source snapshots preserve the distinct versions.

## Reproduced corrections

Track expiry now precedes association. A face returning at 1.0 seconds cannot reuse a track last seen at 0.1 when the grace period is 0.8 seconds. Size-aware matching avoids choosing a differently sized distractor solely because it is slightly closer. Completing an escape never invents observed target progress.

The old vertical scan restarted whenever a face briefly appeared. In a 16-second intermittent-detection replay it issued 66 downward search updates and none upward. The persistent-clock scan balanced 33 positive and 33 negative updates. A level/sky/ground state owns mutually exclusive framing corrections. Ground occupied 1.0 and 0.629 of two downward captures, versus 0 to 0.032 in ten sampled baseline views. This is a scene-specific color cue, not camera-pose estimation.

Candidate B's horizontal search reversed every six seconds. Independent probes reproduced cancellation: a 72-second search accumulated only 15 net command units. Sustained yaw removed that cancellation. The original yaw receipt's full_turn_counts field mistakenly used the pitch factor of 0.002; actual yaw uses 0.003 at default sensitivity, or about 2,094.4 counts per revolution. The before/after command sums remain valid. A separate 12-second camera-only native probe showed the view turning across different parts of the arena; it did not measure angular delivery accuracy.

Simultaneous forward movement and turning can keep exploration local. A 2.5-second straight relocation phase broadened a collision-free intended trajectory, but its native trial still timed out. A later probe including rectangular arena bounds found that a fixed longer relocation was not better from every starting point; no coverage guarantee is inferred. The preceding progressive-relocation candidate lengthens later relocation episodes from 2.5 to at most 5 seconds and preserves at least 3 seconds of scanning afterward. Fresh targets interrupt relocation; bad framing suppresses forward translation while correcting pitch. That version passed 71 tests and project verification, but failed native acceptance after one win and one timeout.

## Perception and input limits

A review of 20 late timeout captures could not positively identify the remaining enemy. It found a conductor foot falsely detected as a face; the coordinator also found warm toast lettering classified as eyes. These examples do not justify widening the detector's search region. The detector is unchanged in this engineering step. The large rolling sphere is the player, so a blocked reticle alone does not identify a physical obstacle or a stuck player.

Combat uses screenshots and visible accessibility controls in ordinary menus. No hidden simulation-state reads, QA fixture, enemy placement change, or controller rewrite produced the trials. Policy memory does not extend the existing 500 ms capture authority. Named desktops retain separate input focus and shared Unix-account authority.

## Workflow and review

Astra roles were routed through the configured runtime: how explainer at medium; original writing candidates at high and xhigh; cross-judge at max; fresh source/comment reviewers at high. This records coordinator execution history, not independent verification of other agents' identities. No model diversity is claimed.

Model the Domain shaped TargetTrack, Recovery and framing state. Fix Root Causes produced expiry, pitch and yaw reproducers. Build the Lever produced the maintained retained-image probe and comparable run summaries. Separate Before Serializing Shared State kept writers in disjoint worktrees and native players in separate desktops. Prove It Works keeps live acceptance separate from passing tests. Sequence Work into Verifiable Units preserves baseline, rejected candidates and final comparison independently.

Comment review requested removal of two new module prose summaries; both were removed. Source reviews found no new constraint or suppression comments. Opening a PR publication is skipped because no remote is configured. Unrelated working edits remain outside this task's commit.

## Stationary scan candidate

The original baseline turned in place during search. An isolated Astra xhigh writer separated scanning from translation while preserving the new target, framing and escape logic. Search accumulates 14 seconds of level-framed activity before lost-target escape and relocation. Its budget pauses through tracking, occlusion and framing correction, and resets only when relocation begins. This avoids indefinite postponement by fleeting detections. Fresh targets retain priority. Seventy-six tests pass in both the candidate worktree and root checkout. Full project verification runs in root because the isolated worktree lacks an ignored historical artifact linked from the unchanged engineering guide. The exact policy hash is 4bf6006a49770f885a3314d524ab19f5ed8f34c17ca7d914b3f011d6bcb9c09b. Native results passed: won/won/lost at displayed 101s, 109s and 172s, respectively. This closes the configured terminal-outcome gate, not a three-win or human-skill gate. Same-policy interruption completed in 0.264 seconds. A subsequent report-text correction clarifies asynchronous timing and live-seed limits; it changes no play behavior and receives a final smoke check.
