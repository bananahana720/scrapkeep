# Wave state: heads, holds and base reds (22 Oct 2026, local coordinator)

Heads and open PRs change by the hour, so read them live: `git ls-remote origin` for branch heads and `gh pr list` for open PRs. The live board is [GRAPH.md](../coord/GRAPH.md). This file keeps what a head listing cannot show.

**State on 22 Oct, 16:15Z.** The first wave 18 promotion is done: `main` = d7878a1b (#326, candidate 3eb3f12f, Gate PASS+NOTES), and #328 and #339 landed after it. `stage/alpha-w18` was 9acc1a89 after batches B2 (Systems motion fixes) and B3. B3 stacked the older #235 head, so Gate must restack #235 at 4b22b5fd, the head that passed row 26d at 3.6 ms. The next promotion needs #235 at 4b22b5fd, #325 (worker races), #322 (Mind freezes) and four follow-ups: the swarm camper check (Challenge), warden_reactor ownership (Systems), a 10-run replay of the crashing seed on main (Gate), and the slow bot tier on the PC.

- **Held:** the six park kits (#246, #251, #252, #306, #309, #313) wait on their 4080 cost rows and on row and yaw fixes. #317 and #327 wait on World's lava-bend fix. #314 waits on the drainage-ridge tint, #284 on the dark live core, and #297 on its box-path cost. #307 lands, re-measured after #270.
- **Benches:** the 4080 times one row at a time on CCD0. The 3060 and CCD1 take stills and correctness runs in parallel (ruling 6345030303). An isolation check (dam kit, 3 runs alone against 3 with CCD1 busy, 0.5 ms bar) decides whether that holds.
- **Orphan:** #228 is being revived by a PC session. Close it at wave 18 close if that fails.
- **Playtest watch list:** the one-off headless crash, cockpit parts poking past the ball on wall rides, camp props at speed (islands is 78% bare), and any stage-change or periodic stutter still open. The standing list is `project-guide/handoff/shared/alpha-status/sitting-watch-list.md`.

## Base reds

These fail on the base too. The machine's fixes are on `scratch/base-red-w16` (`effbf2fc`).

- `alpha_posture_bands_w23`: time limit.
- `park_reactor_fight`: 61.2 s against 53.7 s; one-seed chaotic, flaps solo, needs a repeat.
- `bot_six_demolitions_caster`: Kest flake, 5 in 8.
- Swarm `runner_gunner` "stall": cloud out-of-memory kills, not a game bug; rerun alone.
- Swarm grown and 2x misses (base grown 51.71 s). Overpowered pays work is gated on no regression against `f9f58944`.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `alpha_bot_sweep`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved.

A fail needs a solo rerun before it counts.

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md) and the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
