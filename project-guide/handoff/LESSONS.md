# Scrapkeep lessons and ways of working

Rules this project learned the hard way, 16 to 23 Oct 2026. Each lesson is the rule, then why. Owner: the project coordinator (the claude.ai Scrapkeep project from 23 Oct; the PC session held it 18 to 23 Oct). Lesson numbers stay fixed so older receipts still match; gaps are lessons that no longer apply (git history has them). Last updated 2026-10-23.

## Lanes and the cloud container

14. **One cloud lane per independent unit; split long sweeps by seed or pilot.** Targets: ask to draft PR under 2 h, draft PR to gate verdict under 4 h, no gate-passed PR waiting over 12 h.
16. **Background tasks cap at 2 hours; the box has 4 vCPU, 15 GB RAM, about 30 GB disk and no GPU.** A full gate takes about 2 h in the cloud, so shard it.
17. **The session-start hook installs Godot 4.7.2, Blender 5.2.2 (PyPI `bpy`) and npm deps** in about 70 s fresh, 2 s cached. download.blender.org is blocked; the `scripts/cloud/blender` shim covers it.
18. **GPU work stays on the 4080:** frame times, ACE-Step music renders, Eevee/Vulkan captures, the real export proof. Cloud perf numbers never count (the bench swings 24-146 ms p99 between sandboxes).

## Gating and testing

19. **No lane grades its own work.** A game change is done only when a tool check passes (smoke, lab gate, placeholder gate) and an independent reviewer agrees.
20. **The Gate lane is the gate of record, except GPU checks.** Sibling lanes run bot shards from [BOT-SHARDS.md](shared/gate/BOT-SHARDS.md). Pass tests by base name (`--test bot_six_tally_test`), not `res://` path. Shards don't push, comment or fix.
21. **Known cloud-only false fails (not the PR's fault):** `item_fuzz_smoke` (CPU contention), `park_swap` (frame budgets), `tree_play`, `alpha_bot_sweep` and `alpha_posture_bands_w23` (child timeouts), `persistence_truncation` (runs as root, chmod ignored). `scatter_rows` hash mismatch is unresolved. The Gate lane judges these, not the shard.
22. **"Flake" is not a cause.** The effects RNG test failed on and off for a day; the real cause was a 65 s limit on a busy machine (now 180 s). Find the cause before re-running.
23. **Red team every wave, carrying the last findings.** Camper stalls without a Warden break and traversal stalls are by design. A hitch counts only when it lands at the same run moment across seeds.
24. **When fourteen tunings don't fix a design goal, it's a design question.** The Dispatcher stayed cheap to ignore through 14 tunings; one pitch to Andrew ("Escalate") settled it.

## Permission prompts

25. **Allow-once prompts come from compound shell commands.** Pipes, `&&` and `cd` chains don't match allow-list rules. Fix: one checked-in script with subcommands (the music session's `scripts/music/mx`), allow-listed in `.claude/settings.local.json`, called as one plain command.
26. **The PC allow-list covers test and check scripts, read-only git, and pushes to `cand/*` and `scratch/*` only.** Never main, force-push or installs.

## Music

27. **Never replace a pick unless he picks the new take by ear.** Theme-consistent retakes sounded "boring" to him (15:59Z 17 Oct); energy, switch-ups and electro bass win over neat theory.
27a. **A place music layer never sits inside an arena.** In the Crown, crown_ramp's sensor sat in the Warden's bowl and the ball re-crossed it mid-fight; each layer change shifted the on-bar telegraphs and turned a 6,262-tick win into a 14,410-tick cap (17 Oct 22:24Z). Put the sensor outside the arena, or have the music director lock layers during a fight.

## Records

28. **One register for decisions.** Check `project-guide/handoff/DECISIONS.md` before proposing anything that might already be decided; he dislikes re-deciding and the tokens spent rediscovering old calls (19:46Z 17 Oct).
32. **New shared files go in an area folder, never the root.** Superseded drafts are deleted; git keeps the history.

## Habits

34. **A check that can't fire proves nothing.** Rivet's faster carves (#73) were reverted out of wave 16 because the park carve check never got a carve to fire, so its timing said nothing. Before trusting a pass, confirm the measured thing happened.
35. **Put the measured number in the pitch.** The Rivet Breach pitches carried the 4080 numbers (24.47 ms against 16.7 ms; 0.11 s as the fastest smooth slope hit) and were answered in seconds.
36. **Usage limits stop sessions and they don't self-resume.** After the reset the coordinator messages each lane again and restates the head SHA.
38. **An NVIDIA driver auto-update locks the 4080 until a reboot** ("Driver/library version mismatch"). Ask him to reboot after any update; no pacman hold.
39. **Band sweeps OOM on the 4-core cloud box.** posture_bands sweeps spawn about 24 children; a missing record counts as 300 s. Rerun a 300 s or timeout row alone before calling it red.
40. **Promote fast.** The rules are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md) and the board's test gates in [GRAPH.md](../coord/GRAPH.md): fast lane plus a reviewer to stack, the full gate once per promotion, GPU checks on each promoted head.

## Coordination from the PC

43. **GitHub is the bus for cloud lanes.** Claude Code cloud sessions cannot message other sessions. A lane posts a receipt comment on each PR (verdict, head SHA, commands, nonzero test counts) and raises a hand on the wave's "Wave board" issue. The local coordinator reads both at every check-in, at least every 30 minutes. Local sessions message the coordinator directly.
44. **Escalation goes one step at a time.** An agent asks its lane coordinator; a lane asks the local coordinator; only the coordinator goes to Andrew, with a stakeholder pitch (what's at stake, options with tradeoffs, a recommendation, the measured number, what would change it). Keep building on the recommendation while a pitch waits.
45. **Sync the records before splitting into worktrees.** Lanes clone main, so the rulings, the ownership table and the graph land on main first; a lane that starts from stale docs re-decides settled calls.
46. **Cap concurrent cloud lanes and let each fan out inside its sandbox.** The cap is 7 (19 Oct) and was raised to 11 on 21 Oct. Lanes that run their own agents and workflows replace a dozen flat sessions; the dozen used up the old account in a day.

## Learned 19 to 23 Oct

47. **Check the current stage before you build, and claim the unit first.** A 3-day rate-limit stall left threads rebuilding work that had already landed (dam, flume, islands and sinkhole kits). Before starting, read the stage log (`git log origin/stage/alpha-w<N>`) and the open PRs for the unit, then post a claim on the Wave board. A unit with no claim has no owner.
48. **A merge needs a lane that works before the gate passes.** The coordinator's merges were refused by the auto-mode safety check ("merge without review"), so gate-passed PRs sat. The Gate lane's stacking by `git push` of merge commits to the stage kept working; the coordinator's PR merges did not. Decide who merges, and test it on a no-op, before a promotion is due.
49. **A gate receipt names a head, and it expires when that head moves.** Once a stage head is promoted or restacked, every receipt on the old head needs a re-gate. Check the head SHA on the receipt against the branch before you stack.
50. **Renderer audits need a display.** Density and still audits that use the renderer read 0 when run headless without one. Run them under `xvfb-run -a` (or on the 3060), and treat a 0 as a broken instrument until a planted control reads non-zero.
51. **Bot frame captures need the warmed band** (`--warm-band=1`, #372). Without it the first band load lands inside the capture and reads as a freeze.
52. **Band ratios need 24-seed medians.** Ratios such as grown-against-small at a hive swing too much at 4 to 8 seeds to rule on. Use 24 seeds, run solo at `--fixed-fps 90`, before a ratio goes into a pitch.
53. **One run of a noisy measure is not a finding.** Readability, lighting and frame numbers are the median of 3 runs on a held pose (ART-MISTAKES, 22 Oct). Report a row only from its posted receipt, never from the queue.
54. **Name what is on the ground and in the sky before scoring a still.** Park stills were reviewed for 11 days on Terrain3D's default checkerboard because each review scored only the asked-for subject.
55. **A handoff is a post, not a memory.** When the coordinator changes seat (account switch, new session), every lane pushes, posts `HANDOFF <lane>` on the Wave board with heads, next steps and open NEEDS, and goes idle. The next coordinator starts from those posts.

