# Wave state and open PRs (18 Oct 2026, 05:15Z)

Re-check every sha with `git ls-remote origin` before relying on it. These were read from GitHub at 04:55Z.

## Where the waves stand

- **Wave 16 is on main** at `f9f58944`. Andrew pushed it at 02:06Z on 18 Oct, and it was verified. Rivet's faster carves (#73) were reverted out of it because the park carve check couldn't fire a carve.
- **Wave 17 is being stacked** on `stage/alpha-w17` (`27e15952`, draft PR #116 into main). The promote-fast flow applies: see the last section.
- **Gate passes stacked for wave 17:** #107, #101, #108, #112, #114, #113, #109, #105, #93, #103, #106, #118.
- **Still in the gate at 04:25Z:** #69, #73, #111 (camp), the polish set (#115, #119, #120, #121, #122, #124, #128, #133), #78, #126, #123, #127, #61, #104, #106.
- **PC results on `89bc14ae`:** stage entry is OK. The in-stage freezes are 3.94 s on stage 1 and 2.36 s on stage 2. Menu-ready fails at about 12 s against 5 s. "Stage entry freeze" owns both, with #129 awaiting a 4080 rerun.
- **Tests-only fix #132** was merged to main at 04:39Z outside the gate. It was kept because it's harmless. The coordinator asked Andrew whether he merged it.

## Base reds

These fail on the base too, so they are not a PR's fault. The staging list is in `gate/stage89-full-solo.md`, and the machine's fixes are on `scratch/base-red-w16` (`effbf2fc`).

- `alpha_posture_bands_w23`: time limit.
- `bot_brindle_short`: heft 1.36 against 1.30.
- `park_reactor_fight`: 61.2 s against 53.7 s. It is one-seed chaotic and flaps even when run solo, so a fail needs a repeat.
- `bot_six_demolitions_caster`: a Kest flake, 5 in 8.
- Swarm `runner_gunner` stall: grown seed 1 never latches the hive and caps at 300 s. It has its own thread, "Swarm hive stall on main".
- Swarm grown and 2x misses (base grown 51.71 s). #104 is gated on no regression against `f9f58944`.
- Older cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `alpha_bot_sweep`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3. `scatter_rows` hash mismatch is unresolved.

## Open PRs and their heads

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
