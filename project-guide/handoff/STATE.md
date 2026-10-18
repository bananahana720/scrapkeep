# Wave state and open PRs (18 Oct 2026, 05:55Z, end of night)

Andrew closed out for the night at 05:50Z because usage on the old account was nearly gone. He restarts in the morning, probably from the new project. Re-check every sha with `git ls-remote origin` before relying on it.

## Where the waves stand

- **main is `dc3cac54`.** That is wave 16 plus #132, #135 (this handoff pack), #136 (cloud setup) and #138 (autocompact settings).
- **Wave 17 is being stacked** on `stage/alpha-w17` at `102324cd` (draft PR #116 into main). It now carries #78, #61 and #12 along with the earlier stack. The promote-fast flow applies (last section).
- **#105** (picked music themes) re-gates after merging the stage in, because it conflicted with #12.
- **#126** (flume) passed, with the flume small median re-pinned stage-wide over 5+ seeds.
- **#73** (Rivet carve): a lighter carve change is being pushed. It needs a 4080 p1/p3 run before it promotes.
- **#137** (LATE_WORK 290, slope smoothing) is parked. Andrew tapped "Instant, 0.11 s later" at 05:46Z: flat Breaches and Full Cut hit instantly, slopes land at about 0.18 s, and "Smooth, 0.11 s" returns once dense fights get cheaper. See DECISIONS.md.
- **#140** (Sable, Cannon and Tarn idle loops) is in the gate.
- **#129** (stage entry freeze): cold boot is 8.94 s against the 5 s target on the 4080. The fix directions are in `gate/stage-entry-w16.md` in the shared folder.
- **Boss spawn freeze** is a new thread. It works from the machine's "Boss freeze frames" findings.
- **Dense fights:** a render-thread A/B is queued on the 4080. The stage 6 fight runs 30% over budget, and its arena labels are being confirmed.
- **SWAP-HITCH-6:** a self-play flag for it is being built.
- **Grown-hit sound:** Andrew gave the go-ahead at 05:45Z.
- **Landforms:** exceptions recorded for the landform checks.
- **Closed:** #22, #89, #80 and #99.
- **Pilot radio:** the music packer is at 16 of 56 takes.
- **Old drafts:** #75, #56 and #55 were closed as landed. #66, #25 and #52 were folded into #139 (`7b426bbc`, in the gate).
- **Staging still owes** the run_tier re-record, the rebuild of 3 Warden GLBs (mantle_brood, mantle_choir, kit_mind) and the reactor-band drift.

## Base reds

These fail on the base too, so they are not a PR's fault. The staging list is in `gate/stage89-full-solo.md`, and the machine's fixes are on `scratch/base-red-w16` (`effbf2fc`).

- `alpha_posture_bands_w23`: time limit.
- `bot_brindle_short`: heft 1.36 against 1.30.
- `park_reactor_fight`: 61.2 s against 53.7 s. It is one-seed chaotic and flaps even when run solo, so a fail needs a repeat.
- `bot_six_demolitions_caster`: a Kest flake, 5 in 8.
- Swarm `runner_gunner` "stall": it turned out to be cloud out-of-memory kills, not a game bug. Rerun such rows alone.
- Swarm grown and 2x misses (base grown 51.71 s). #104 is gated on no regression against `f9f58944`.
- Older cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `alpha_bot_sweep`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved.

## Open PRs and their heads

Heads as read at 04:55Z. Many have moved or merged into the stage since; re-check before use.

| PR | Title | Base | Head sha |
| --- | --- | --- | --- |
| #116 | Wave 17 stage | main | 27e15952 |
| #133 | Pilot polish: Rivet, Sable, Kest, Cannon soft-toy meshes | model-polish-pilots | dc40b3d7 |
| #131 | Ease Brindle's keyframes | polish-bosses-wardens | 832e72d0 |
| #130 | Idle loop for Tarn; Sable and Cannon idle tables | model-polish-pilots | ce4666e7 |
| #129 | Natural event marks off the main thread (stage entry freeze) | main | 913d3119 |
| #128 | Polish bosses and Wardens | model-polish-3ohh2a | 8f76b0a6 |
| #127 | Hidden rooms: crew log and a quiet tell (first-win secrets) | main | 07b24fcc |
| #126 | Flume authored pass: the momentum test | main | 5c39fa03 |
| #125 | 60 s victory lap at Meteor Crater | main | ed5c04e7 |
| #124 | Polish props and landmarks | model-polish-3ohh2a | 9f07a6eb |
| #123 | Smoother boss clip blends | stage/alpha-w16 | 05af868d |
| #122 | Tally pilot polish | model-polish-pilots | 6b072ef5 |
| #121 | Polish world 1 enemies | model-polish-3ohh2a | 4fe3b8a2 |
| #120 | The Mind: gloved hands, crew numbers, empty bench | model-polish-3ohh2a | d55360c1 |
| #119 | Polish world 2 and 3 enemies | model-polish-3ohh2a | 71d72a2f |
| #117 | Smoother enemy blends; specials play authored clips | stage/alpha-w16 | a5c07d67 |
| #115 | Tarn pilot polish; pilot clip size gate | model-polish-3ohh2a | 55b008da |
| #114 | Sinkhole authored pass (replaces #102) | stage/alpha-w16 | 0445e192 |
| #113 | The Mind's hands were the crew's (All hands lore) | stage/alpha-w16 | 44377eeb |
| #112 | Pit authored pass | stage/alpha-w16 | b5663b28 |
| #111 | Walkable camp | pilot-radio | f62a10bd |
| #109 | Smoother pilot and companion blends | stage/alpha-w16 | 615a8806 |
| #108 | Effects and surfaces pass | stage/alpha-w16 | 61aa7e68 |
| #107 | Model polish toolkit (FROZEN) | stage/alpha-w16 | 5bc84833 |
| #106 | Fast PR lane; retry the crashed first import | main | ceae93d0 |
| #105 | Picked music themes play their stages | cand/alpha-w16 | 0e951c8b |
| #104 | Overpowered pays | cand/alpha-w16 | f472f71b |
| #103 | Pilots hop out; look closer | main | 90cc00f5 |
| #101 | Dam park authored pass | main | d9cb5e50 |
| #100 | Actives obey Reduce flashes | stage/alpha-w16 | 9c4e1332 |
| #99 | Maker sets on the 61 items | project-thread-m28d9j | 22e8c43e |
| #95 | Park ride pieces | main | 9ad3a79c |
| #93 | Run-end comic page | main | 373adb25 |
| #92 | Allow three read-only commands | main | ade5fd7a |
| #84-#91 | The six actives and active offers | project-thread-m28d9j | various |
| #78 | Highdraft one-skill lines, ride pieces | stage/alpha-w17 | 74782be2 |
| #75 | ISLE-SKIRT bot fix | scratch/gate-head-692fa3ff | ed311a5f |
| #73 | Rivet ultimate carve freeze | cand/alpha-w16 | 8e40be12 |
| #69 | Dig floor fights back, Highdraft ring-outs | main | 16676580 |
| #66 | Pilot radio | camp-jukebox | 2e9a9393 |
| #61 | Wall grip: speed holds | cand/alpha-w16 | a51e4d12 |
| #56 | Relay stake post and mast models | sr10-relay-risk-stack | 991a4d56 |
| #55 | Moss's jukebox | camp-hub-model | 7afa4abf |
| #52 | Stage modifiers | main | 635085aa |
| #25 | Per-wave red team | main | 724a7c95 |
| #22 | Headless loader | main | 9e0c30ae |
| #12 | Sound bible and renders (music source of truth) | main | 74d8a113 |

Several PRs are stacked on others (the polish set on #107, #66 on #55 on the camp model, #111 on #66). Merge the bases first.

## The promote-fast flow from wave 17 (PR #106, ORCHESTRATOR)

1. A PR passes the fast lane (`npm run sketch:fast -- --base <stage>`) plus an independent reviewer, then stacks on `stage/alpha-w<N>`.
2. Each stage head gets the full cloud gate and one rotating red team persona (`node scripts/redteam/run.mjs --persona=<id>`).
3. With no new red or blocker, staging merges the stage PR to main on GitHub. That is under the coordinator's standing merge authority, with no PC prompt.
4. The PC runs GPU checks on each promoted head. A GPU red is a next-wave fix unless it's a crash.
5. A five-persona red team sweep runs at wave close. Open PRs roll into the next wave instead of blocking.
