# Wave state: heads, holds and base reds (29 Oct 2026, project coordinator)

Heads and open PRs change by the hour, so read them live (`git ls-remote origin`, the GitHub MCP tools for open PRs; cloud threads avoid `gh api`). The live board is the current wave's board issue (#583 for wave 26; the Gate thread opens the wave 27 board) and `/mnt/project-files/gate/w<N>-stack-queue.md`. This file keeps what a head listing cannot show. Rewritten 2026-10-29 by the housekeeping thread; the 23 Oct wave 18 version is in git history.

**Priority (Andrew, 23 Oct 19:31Z).** World 1 first: a finished Spillway (dam, flume, Brindle, with the camp and title lead-in) and early progression, played at a world 1 sitting (10-15 min average run, about 30 min completionist, repeatable). Worlds 2 and 3 start nothing new (rulings at and register section 1).

**Now (29 Oct).** `main` = 83f02396, the wave 26 promotion (#585), is the world 1 sitting build. Its full gate (f724a6e6) was clean 13 of 13, the speedrunner red team was clear, and no placeholders are left. Andrew was told to play it at 19:25Z; post-sitting work comes from his marks on the sitting sheet (/mnt/project-files/world1/sitting-sheet.html). The Gate thread is cutting `stage/alpha-w27` from main; its red team is the first-timer persona, compared against `gate/w26-f724a6e6/`.

**Promotions since wave 18.** w19 a4c5b963 (#511), w20 46245f69 (#555), w21 421c8244 (#562), w22 1a0516d1 (#567), w23 462ca7ef (#570), w24 65d34cdb (#580), w25 dc1da31a (#582), w26 83f02396 (#585). Every stage up to w25 is merged into main.

**Sitting build on the PC.** AppImage in the app menu; cold launch to menu 6.4 s with 0 errors; frame rows for w25 and w26 equal within noise (#571 comment 6507342000). Audio gate PASS. What to watch while he plays is in /mnt/project-files/alpha-status/sitting-watch-list.md.

## Owed non-blocking reds

Base-same reds the promotions carried, with no bisect (ruling d). A fail needs a solo rerun before it counts, and a "base" red must also be red on the bare head or on main (LESSONS 51-52).

- run_tier freed-instance flake; audio_bake_cancel; hive swarm pins; posture_bands_mind 4/8 and reactor 3/15; presentation_random_guard cap; park_reactor_repeat; tree_play; trace_*; waking stagger and ambient_life; warden_counter_pulse; stage_entry_budget; bot_relay_stake; skill_band one-seed flip; terrain_lazy_world; stage3_break; marker tests; camp_sandbox; scatter_rows; park_swap flake; music_params; telegraph_timing_pack; boss_weak_parts and crown_warden_bot caps; bot_world_arrivals cave-in; stage_locks yard-wave.
- Cloud-only false fails: `item_fuzz_smoke`, `park_swap`, `tree_play`, `persistence_truncation`, `juice_budget` peak shake, `line_sound` HLs-3, `park_permanent_capacity`, `park_reactor_rhythm` (180 s solo cap), `presentation_random_guard` (about 290 s, killed at its cap) and `bot_park_trace_repeat` (child timeout).
- Oggs-present vs Oggs-absent base: the packed music Oggs are gitignored, so cloud boxes play the synth engine while a PC with synced Oggs plays ACE. Music tests can pass on one and fail on the other. Compare a head and its base with the same Ogg state, and name it in the receipt (23 Oct, #411).

## Parked until after the sitting

- Perf: sinkhole Dispatcher 265-277 ms; EventFamilies.build 69 ms at stage 5; Dig pit beacon bursts; Jolt shape build on the main thread (13-14 ms per tile). Dig and world 2 perf is out of scope (ruling at).
- Brindle cobalt pick (ruling ap); flume length levers (ruling ax); HARD rung 5 re-read (ruling aq).

## PC capture rules

- Frame-time captures run only on an idle 4080 (device 0) through headless gamescope; the 3060 takes throughput work. A capture is void if Andrew plays or another process touches the card during it. Run the stems sync first.
- The live wallpaper pauses only for a process named exactly `godot`, so launch captures through a `godot` link and count `mpvpaper` as foreign (#446).
- Cloud perf numbers never count, and the cloud ratio differs by kind of work (LESSONS 55-58).

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md); the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
