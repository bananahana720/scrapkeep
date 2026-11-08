# Wave state: heads, holds and base reds (8 Nov 2026, project coordinator)

Heads and open PRs change by the hour, so read them live (`git ls-remote origin`, the GitHub MCP tools for open PRs). The live board is the current wave's board issue (**#627 for wave 32**) plus `/mnt/project-files/gate/w<N>-stack-queue.md`. This file keeps what a head listing cannot show. The roadmap is [ROADMAP.md](ROADMAP.md). Rewritten 2026-11-08 by the docs pass; the 29 Oct version is in git history.

**Priority (Andrew, 23 Oct 19:31Z).** World 1 first: a finished Spillway (dam, flume, Brindle, with the camp and title lead-in) and early progression, played at a world 1 sitting (10-15 min average run, about 30 min completionist, repeatable). Worlds 2 and 3 start nothing new (ruling at).

**Now (8 Nov).** `main` = 645893f3, the wave 31 promotion (#626; full gate CLEAN on 80af241e; receipts `gate/w31-0786c1a8-gate-plan.md`). `stage/alpha-w32` was cut at main and holds #628 (deep-modules batch 1) and #629 (state-aware mix); head 24ebf5e8. Its red team is the first-timer persona, compared against `gate/w31-07fb5323/` (bots, bands) and `gate/w31-0786c1a8/` (tests).

**World 1 sitting.** Andrew played the dam on the wave 26 build on 30 Oct: fun, many invisible walls, models clipping. Every fix shipped in wave 29. He has not marked any area yet. The PC has the w32 pre-gate build installed (8 Nov 19:07Z; boss smokes PASS; cold launch to menu 6263 ms, 0 errors); rollback is the w31 AppImage. The sitting sheet needs a refresh for the build he plays.

**Promotions since wave 18.** w19 a4c5b963 (#511), w20 46245f69 (#555), w21 421c8244 (#562), w22 1a0516d1 (#567), w23 462ca7ef (#570), w24 65d34cdb (#580), w25 dc1da31a (#582), w26 83f02396 (#585), w27 a7151583, w28 1e172aee, w29 556cca8e (#606), w30 98727408 (#614), w31 645893f3 (#626).

**After each promotion.** Run the deep-modules sweep on the promoted main ([DEEP-SWEEP.md](DEEP-SWEEP.md)); it never holds a promotion. Andrew runs the PC branch-prune script (the cloud proxy refuses `git push --delete`).

## Owed non-blocking reds

Base-same reds the promotions carried, with no bisect (ruling d). A fail needs a solo rerun before it counts, and a "base" red must also be red on the bare head or on main (LESSONS 51-52). A new deterministic red blocks, and its fix lane is the PR's owner (ruling ai).

- run_tier freed-instance flake; audio_bake_cancel; hive swarm pins; posture_bands_mind and posture_bands_reactor ratio; presentation_random_guard cap; park_reactor_repeat; tree_play; tree_bot; trace_*; waking stagger, ambient_life and waking_fight; warden_counter_pulse; stage_entry_budget; bot_relay_stake; terrain_lazy_world; stage3_break; marker tests; camp_sandbox; scatter_rows; park_swap flake; music_params; telegraph_timing_pack; boss_weak_parts and crown_warden_bot caps; bot_world_arrivals cave-in; stage_locks yard-wave; matchup_lab_test; load flakes in juice, pod, hit_stop and menu_ground_behind.
- skill_band is a report now (ruling bi), not a red.
- Base-same play issues on board #627: a miniboss presses the ball under the dam Warden yard in staked runs (main 4 of 6); the Brindle charge fling shows in 4 of 18 speedrunner runs.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3, `park_permanent_capacity`, `park_reactor_rhythm` (180 s solo cap), `presentation_random_guard` (about 290 s, killed at its cap) and `bot_park_trace_repeat` (child timeout).
- Oggs-present vs Oggs-absent base: the packed music Oggs are gitignored, so cloud boxes play the synth engine while a PC with synced Oggs plays ACE. Compare a head and its base with the same Ogg state, and name it in the receipt (23 Oct, #411).

## Parked until after the sitting

- Perf: sinkhole Dispatcher 265-277 ms; EventFamilies.build 69 ms at stage 5; Dig pit beacon bursts; Jolt shape build on the main thread. Dig and world 2 perf is out of scope (ruling at). Dam perf left: f4045 riser, Warden break and engage remainders, seed 3 f14k swing, the over-16 engage spike (a real game spike; its old watch issue #512 is closed, so post perf receipts on the current board).
- Brindle cobalt pick (ruling ap); flume length levers (ruling ax); HARD rung 5 re-read (rulings aq, bc, be); w1 Novice ceiling re-read (ruling bk).

## PC capture rules

- Frame-time captures run only on an idle 4080 (device 0) through headless gamescope; the 3060 takes throughput work. A capture is void if Andrew plays or another process touches the card during it. Run the stems sync first. Power caps: 4080 280 W, 3060 140 W (#446).
- The live wallpaper pauses only for a process named exactly `godot`, so launch captures through a `godot` link and count `mpvpaper` as foreign (#446).
- Cloud perf numbers never count, and the cloud ratio differs by kind of work (LESSONS 55-58).

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md) (the tiered gate is its only owner); the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
