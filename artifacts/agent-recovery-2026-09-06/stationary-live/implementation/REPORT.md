# Stationary scan candidate

Frozen for the parent's native comparison. Controller-free behavior passes at evidence level 4. Native gameplay efficacy remains untested for this candidate.

The policy separates targetless camera search from straight relocation. Search holds no movement keys and requests yaw 180. It accumulates 14 seconds only while actively scanning a level-framed view. The parent reports that the existing native vision and control cadence needs about 14 seconds for a full sweep at this yaw. The value therefore gives the camera a complete observation budget before relocation. It does not depend on an enemy position or a selected run seed.

`Recovery.scan_seconds` owns that accumulated budget. Tracking, brief occlusion, framing correction, and escape phases pause it. A fleeting detection cannot reset it. Starting relocation consumes the completed scan budget and begins the next one at zero. A fresh accepted target interrupts search or relocation on its observation. Existing target association, the 0.8-second track grace, and target movement controls remain unchanged.

Relocation follows the existing 0.8-second reverse, 0.9-second lateral, and 0.3-second settle sequence. Its initial duration remains 2.5 seconds, grows by 0.75 seconds with each escape attempt, and caps at 5 seconds. Relocation requests forward movement with zero yaw. It pauses forward movement while correcting sky or ground framing. Deadlines still use their original boundaries when a policy update arrives late. Exploration has no fixed attempt limit.

Completed scan recovery takes precedence over a simultaneous frozen-scene trigger. Otherwise a persistently unchanged scene could keep selecting the shorter escape and indefinitely postpone relocation after sufficient search. Frozen-scene and target-stall recovery retain their existing triggers and cooldown. The existing absolute vertical-sweep direction remains unchanged.

The Model the Domain principle kept the new accumulated budget in the existing Recovery object. Laziness Protocol kept target selection, detector rules, combat frame authority, input ownership, and game code unchanged. Prove It Works led to executable checks for scan and movement exclusion, the full scan budget, target interruption, framing pauses, flickering detections, repeated attempts, and phase deadlines.

`npm run test:agent` passes all 76 tests. `git diff --check` passes. `npm run verify` stops at the project link check because this isolated worktree lacks the preserved `artifacts/local/player-playtest-2026-09-06/README.md` linked by the project engineering document. The parent confirmed that the root checkout has that historical artifact and will run the full gate before admission. This candidate did not change the missing artifact or its link.

A brief extra attempt to remove the prior loss timer changed reacquisition framing and vertical-sweep bias. Tests caught both regressions. That extra attempt was fully reverted before the final successful test run. Neither change is part of the frozen candidate.

The three source changes are in `candidate.patch`, relative to the parent's copied 71-test candidate. The worktree already contained inherited modifications, so a raw diff against HEAD also includes parent work. `manifest.json` records the frozen changed-file hashes, incremental patch hash, and all Python, Markdown, and fixture files under `tools/agent-player`. HEAD is `db7d8cfd21f5bbb710e756c2eda3f285c15f87f6`, on branch `codex/recovery-stationary`.

The next action is a fresh ordinary native comparison from this exact worktree. A controller-free pass does not establish a gameplay clear, better recovery, controller feel, or human enjoyment.
