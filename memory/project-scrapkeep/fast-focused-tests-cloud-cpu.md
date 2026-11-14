---
name: fast-focused-tests-cloud-cpu
description: "2026-10-22 test pace and hardware routing - focused per-PR tests, full gate only at promotion, CPU work in the cloud, PC for GPU and local state"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 99053a69-80bd-4be5-8d1c-7c0c8c13e9bc
  modified: 2026-11-11T13:10:27.442Z
---

Andrew, 22 Oct 2026: work at a quick, iterative pace. Each PR runs focused tests on the feature it changes plus `npm run sketch:fast`, aiming for 10 minutes or less. No bot sweeps, medians, full-tier runs or personas per PR. The full gate runs once per promotion on the stage head. A 4080 row is one pair per side, with a median only within 10% of the bar. Board #241 comments 6349401106 and 6349414700.

CPU-only work (headless tests, bots, replays, bands) runs in the cloud by default. The PC keeps 4080 timing, 3060 renders and local-state checks, and takes a CPU run only when the cloud can't.

**Why:** long tests left everyone waiting, and hardware shouldn't be the bottleneck. Progress first, integration bugs at promotion.

Andrew, 10 Nov 2026 (local coordinator session, mid wave 34 gate): "be sure to test/verify, UAT and such efficiently ... optimize test time for the hardware and cloud session compute capabilities." Ruling cs moved the gate onto the PC; this restates that the PC and the cloud are sized to the work, not the old 4-core defaults.

Andrew, 11 Nov 2026 (ruling cy, mid wave 36, after two full gates of about 5 hours each in one day): "things are taking really, really long ... save time on focusing UAT or testing or red teaming, bot runs, what have you, in the areas of changes"; "I only challenge because we've been doing this for days, and I feel like this step has been a huge bottleneck historically and repeatedly"; "that's not to say to throw out the infra ... this could be just like on a major release type of thing that we'll do at the very end of like a sprint"; "I want to get down to it with just DevOpsing and developing fast with you being a really efficient coordinator and automated verifier". He also asked for difficulty tuning to move to the end, with polish, mechanics, animations and bugs first.

What that changed (ORCHESTRATOR's tiered gate block owns it):
- A promotion runs the wave gate: node suite, every non-bot test, and the bot and band tests the wave's changes reach, by name (`tally.mjs --wave`).
- The full gate (all bot blocks, bands A to C, red team) is the release gate: once at the end of a sprint, on the head a sitting build is cut from.
- Difficulty tuning lands last in a sprint, after the polish waves, before the release gate.
- Never sit waiting on a gate. Cut the next stage from the current stage head and keep building while a gate runs.
- My reading of why he was right: every red of the first wave 36 gate sat in a file or fight the wave changed, and the three hours of wide sweeps found nothing else.

What the first PC gate measured (my reading, 10 Nov):
- The runner's slot pool is one per `SCRAPKEEP_LOCK_DIR`. `shard.mjs` reruns a failed test with `SMOKE_SLOTS=1`, which is slot 0 of that pool, so with one pool for the PC every lane's solo reruns and every bot shard queued for one slot (two reruns waited 35 minutes with no Godot child). Give each lane its own lock dir (`~/scratch/gate/lane-shard2.sh`) and budget by Godot processes, about 16 on the 32-thread PC (measured: 31 processes had 62 runnable threads and ran at 87% of a core each, so each wants about two threads and 31 run at half speed), with base runs at nice 19.
- Never queue the bot blocks behind a test shard in one lane: spread them over idle worktrees.
- Starting every lane at once sent the load to 97; start head lanes first and add base lanes as the load allows.
- A gated head's receipts are the next wave's base, so keep `~/scratch/gate/w<N>-<head>/` and skip the base rerun.
- Cloud sessions (env `scrap`) take CPU jobs that compare with nothing on the PC (the red team persona pass) without asking. A cloud job that must match a PC run seed for seed waits until one label has been shown identical on both. A cloud session request only starts while the conversation is open in the desktop app, and no note comes when it ends: check its branch and the board.

**How to apply:** brief every lane with this. Don't queue CPU runs on the PC. Widen a check only when a focused test points outside its unit or a shared contract changes. Related: [[alpha-coordinator-handoff]], [[pc-gpu-rules]].
