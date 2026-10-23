# Wave state (18 Oct 2026, 20:55Z, local coordinator; promotion note 21 Oct)

**21 Oct.** Wave 17 was promoted. `main` is 16df22d0, the merge of #116 at stage head f405e612, and `stage/alpha-w18` was cut from it. The heads, drops and carry-over are in [BASELINE-2026-10-20.md](../coord/BASELINE-2026-10-20.md). The sections below are the 18 Oct snapshot.

**21 Oct, 21:15Z. Wave 18 is open.** #239 merged, so `main` = `stage/alpha-w18` = 9cd6805e. The coordinator is back on the PC. Board: issue #241 (#149 is closed). Every PR on w17 now targets w18. Six PRs conflict with w18: #137, #191, #208, #209, #225 and #237. GPU queue rows 18 to 22 are stale and were re-requested as rows 23 to 27. Live units are in GRAPH.md "Wave 18".

Coordination moved to a local Claude Code session on Andrew's PC on 18 Oct (DECISIONS.md section 2). The live board is [project-guide/coord/GRAPH.md](../coord/GRAPH.md); this file keeps the heads and base reds behind it. The 05:55Z version is in git history. Re-check every SHA with `git ls-remote origin` before relying on it.

## Where the waves stand

- **main is `639c5cb4`**: wave 16 plus #132, #134, #135, #136, #138, #141 (handoff pack, cloud setup, autocompact settings).
- **Wave 17 stacks on `stage/alpha-w17` at `102324cd`** (draft PR #116 into main), 304 commits ahead of main; main has 7 commits the stage lacks.
- Andrew plays once, at the end of wave 21.

## Open PRs (triaged 18 Oct from `gh pr list`, merge-base and gate comments)

| Class | PRs | Next step |
| --- | --- | --- |
| In the stage already | #12, 61, 69, 93, 95, 100, 101, 103, 107, 108, 109, 111, 112, 113, 114, 115, 117, 119, 120, 121, 122, 123, 128, 130, 131, 133 | close with the promotion of #116; #95 carries an open pilot-stall note on mesa_shelf_edge and kickers |
| Ready to stack (PASS on head) | #125 `3b9bb44a`, #127 `07b24fcc`, #129 `1389e7e5`, #139 `695bc6f3`, #140 `69512b34` | stack |
| Re-gate (head moved past PASS) | #105 `747750cf`, #106 `faf2b345` (WIP --self-play commit past PASS on ceae93d0), #126 `677fd826`, #142, #144 | Gate lane |
| Needs fix | #104 `cccac816` (HOLD: grown swarm 45.01 s, ratio 1.92x; Mind small 89.2 s vs pin 101.5) | Perf lane |
| Needs GPU | #73 `083d83ca` (no receipt; stage carries its reverts de36cf11, 18811586, 8b16c4c1, 272d2eab); #137 stacks on #73 and stays parked ("Instant, 0.11 s later") | Perf lane, then GPU bench |
| Work in progress | #143 / #124 (same head `da92b6d9`), #145, #146, #147 | owning lanes |
| Config | #92 allow three read-only commands | Gate lane |
| Superseded | #84 (in main); #66, #25, #52 (inside #139) | close |

## Base reds

These fail on the base too. The machine's fixes are on `scratch/base-red-w16` (`effbf2fc`).

- `alpha_posture_bands_w23`: time limit.
- `bot_brindle_short`: passes on 2e247fc8 at heft 1.30, exactly at the 1.30 limit (20 Oct). #231 tips it to 1.36.
- `park_reactor_fight`: 61.2 s against 53.7 s; one-seed chaotic, flaps solo, needs a repeat.
- `bot_six_demolitions_caster`: Kest flake, 5 in 8.
- Swarm `runner_gunner` "stall": cloud out-of-memory kills, not a game bug; rerun alone.
- Swarm grown and 2x misses (base grown 51.71 s); #104 is gated on no regression against `f9f58944`.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `alpha_bot_sweep`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved.
- Oggs-present vs Oggs-absent base: the packed music Oggs are gitignored, so cloud boxes have none and the game plays the synth engine, while a PC with synced Oggs plays ACE. Music tests (`park_music_suspend_game_test`, `ace_tracks_test`, the phase music tests) can pass on one and fail on the other. Compare a head and its base with the same Ogg state, and name that state in the receipt (23 Oct, #411).

## Staging still owes

The run_tier re-record, the rebuild of 3 Warden GLBs (mantle_brood, mantle_choir, kit_mind) and the reactor-band drift.

## The promote-fast flow (PR #106, ORCHESTRATOR)

1. A PR passes the fast lane (`npm run sketch:fast -- --base <stage>`) plus an independent reviewer, then stacks on `stage/alpha-w<N>`.
2. Each stage head gets the full gate and one rotating red team persona (`node scripts/redteam/run.mjs --persona=<id>`).
3. With no new red or blocker, the coordinator merges the stage PR into main under the standing authority restated 18 Oct.
4. The PC GPU bench checks each promoted head. A GPU red is a next-wave fix unless it crashes.
5. A five-persona red team sweep runs at wave close. Open PRs roll into the next wave instead of blocking.
