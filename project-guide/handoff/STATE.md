# Wave state: heads, holds and base reds (23 Oct 2026, project coordinator)

Heads and open PRs change by the hour, so read them live (`git ls-remote origin`, the GitHub MCP tools for open PRs; cloud threads avoid `gh api`). The live board is [GRAPH.md](../coord/GRAPH.md) plus issue #241. This file keeps what a head listing cannot show. Updated 2026-10-23 19:50Z by the library sweep thread.

**Priority (Andrew, 19:31Z).** World 1 first: a 100% finished world 1 and early progression, played at a world 1 sitting (10-15 min average run, about 30 min completionist; timing card open, recommended end of wave 19). Worlds 2 and 3 finish running work only.

**Wave 18.** `main` = c23449cb (docs on top of the first wave 18 promotion, #326). `stage/alpha-w18` = acb55972 after batches B2 to B20; batch B21 (eight PRs plus #383, 06fe14c6) waits on a solo park_swap timing. The full gate on acb55972 is on its last chunk. Promotion is held by a stage 6 quit crash that is green on the last promoted main, so it is new this wave; a sibling is bisecting 113 stage commits. The known swarm hive band (2.06x, owed by the hive tuning PR) and `bot_skill_bar` (cloud time cap) do not hold it. The cautious persona found 0 blockers and 3 majors (stage 1 hitch at 5 s, noisy cloud bench, 1 placeholder). The 4080 release dry run on stage + #367 + #390 (15d7ac9b) is PASS+NOTES: export exit 0, 3 Vulkan boss smokes, 4 win proofs, AppImage 903 MiB.

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
- `posture_bands_swarm` (expected red until the hive tuning PR lands; Andrew ruled grown builds hit harder, 23 Oct 16:02Z): on w18 `e564e2c3`, 24 seeds a side, small 75.69 s, grown 40.67 s, 1.86x against the 2x floor; the ordinary first stagger is 50 s against the 60 to 85 s ruling. Tuning trials in `/mnt/project-files/gate/c10-swarm/README.md`. The camper leg is now `posture_bands_swarm_camper_test`. The old out-of-memory kills are gone with the parallel cap. #104 is still gated on no swarm regression against `f9f58944`.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved. `alpha_bot_sweep` and `bot_run_end` pass in the bots tier since `ba10b7c7`.
- `bot_skill_bar`: the cloud time cap.
- Stage 6 teardown SIGABRT: red on the stage base too; checked against main.

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md); the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
