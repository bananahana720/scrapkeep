# Wave state: heads, holds and base reds (23 Oct 2026, project coordinator)

Heads and open PRs change by the hour, so read them live (`git ls-remote origin`, the GitHub MCP tools for open PRs; cloud threads avoid `gh api`). The live board is [GRAPH.md](../coord/GRAPH.md) plus issue #241. This file keeps what a head listing cannot show. Updated 2026-10-23 19:50Z by the library sweep thread.

**Priority (Andrew, 19:31Z).** World 1 first: a 100% finished world 1 and early progression, played at a world 1 sitting (10-15 min average run, about 30 min completionist; timing card open, recommended end of wave 19). Worlds 2 and 3 finish running work only.

**Wave 18.** Promoted 23 Oct 22:10Z: `main` = a08d7463 (#415: stage a14c658a, which is acb55972 plus #401's stage 6 quit-crash fix). The promotion receipt on #415 lists three reds new this wave and owed to a fix lane: `ui_build_readout`, `ending_sequence` and `bot_repeat`. `stage/alpha-w18` now carries B21 (eight PRs plus #383), B22, #393, B24 and main's docs; the queue is in /mnt/project-files/gate/w18-stack-queue.md. The known swarm hive band (owed by the hive tuning PR) and `bot_skill_bar` (cloud time cap) stay known reds. The cautious persona found 0 blockers. The 4080 release dry run on stage + #367 + #390 (15d7ac9b) is PASS+NOTES: export exit 0, 3 Vulkan boss smokes, 4 win proofs, AppImage 903 MiB.

- **Post-promotion queue, in order:** #390 (export include fix, first), #380, #252, #379, #373, #375, #362, #341, #329, #334, #377, #385, #388, sinkhole flash flood, #376, #272, #228, #384, #386 (after #372). The PR that adds the boss weak-point tests must commit their five `.uid` files before it stacks.
- **Held:** #351 (stalls the seed 6 skipper at stage 4; bare acb55972 wins; thread "Stage 4 stall on seed 6") and #374 (needs #351 fixed or another seed).
- **Merges:** each batch needs Andrew's typed line naming the thread, the action and each PR number (LESSONS 47).
- **New today:** draft PRs #391 (fight phases framework and Brindle, register section 7 row) and #392 (item ladder, register section 6 row).
- **GPUs:** both run throughput work; 4080 timing only when it would otherwise idle (pause file on the PC). The timing chain: crown, islands, Reactor, Swarm, then the C16 rows, then #386 rows.

## Base reds

A fail needs a solo rerun before it counts, and a "base" red must also be red on the bare head or on main (LESSONS 51-52).

- `alpha_posture_bands_w23`: time limit.
- `bot_brindle_short`: passes on 2e247fc8 at heft 1.30, exactly at the 1.30 limit (20 Oct). #231 tips it to 1.36.
- `park_reactor_fight`: 61.2 s against 53.7 s; one-seed chaotic, flaps solo, needs a repeat.
- `bot_six_demolitions_caster`: Kest flake, 5 in 8.
- `posture_bands_swarm`: green after the swarm hive option 1 tune (23 Oct): 24 seeds a side, small 72.89 s, grown 33.95 s, 2.15x; first stagger 50.32 s inside its restated 40-60 s band. The camper leg is `posture_bands_swarm_camper_test`. #104 is still gated on no swarm regression against `f9f58944`.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved. `alpha_bot_sweep` and `bot_run_end` pass in the bots tier since `ba10b7c7`.
- `bot_skill_bar`: the cloud time cap.
- Stage 6 teardown SIGABRT: red on the stage base too; checked against main.

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md); the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
