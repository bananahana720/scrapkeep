# Posture sweep

Finds the Warden numbers (LEGIBILITY section 4) by playing the three fight bots over a grid, so a rerun after the map changes needs no hand work.

## Run it

One command, from the repository root (Godot 4.7.2, headless). Run it alone on the machine: it starts six child processes.

```
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd -- --out=$PWD/sketches/core-loop/tools/posture_sweep.tsv --runs=$PWD/sketches/core-loop/tools/posture_sweep_runs.tsv
```

`--out` and `--runs` must be absolute paths. Options after `--`:

| Option | Default | Meaning |
| --- | --- | --- |
| `--procs=N` | 6 | child processes, 1 to 6, each taking every Nth cell |
| `--seeds=1,2,3,4,5` | 1 to 5 | seeds per policy per cell |
| `--cap=240` | 240 | seconds of fighting before a run counts as not broken |
| `--plating=`, `--curve=`, `--shatter=` | the full grid | comma lists that narrow it, e.g. `--plating=75 --curve=2 --shatter=true` is one cell |

No data file is committed: the first sweep's `posture_sweep.tsv` and `posture_sweep_runs.tsv` were taken with a wrong fight clock and a camper column that could not count, and left the tree. The full command took 3407 s (57 minutes) at six processes on 2026-10-02, with the machine's load average between 8 and 17 of 32 threads. One cell alone takes 8 to 10 minutes in one process. Each child process gives every run its own data folder, `user://posture_sweep/part<n>of<m>/job<k>`, and clears it first.

## The seam

The game already reads its stage table through `ctx.stages`. After each `Game` is built the sweep replaces `ctx.stages` with a `Table` (an inner class of `posture_sweep.gd`) whose `of()` returns the slice row with `warden_plating` and a `posture` dictionary swapped in. No source file changes between cells. `combat.warden_spec` carries the row's `posture` to the Warden, which hands it to `BossPosture.new()`. A row with no `posture` key runs on the constants.

The rule takes these keys, each falling back to its constant: `curve` (the exponent on the clamped ratio, default 1.0), `ram_shatters` (default true), `base` (merged per kind over `BASE`, so `{"ram": 20.0}` changes the ram and leaves stomp and slam), `smash_base`, `other_base`, `other_base_charging`, `mult_min`, `mult_max`, `drain_delay`, `drain_rate`, `stagger_seconds`, `shatter_tier`. A hit's gain is `base * pow(clamp(punch / plating, mult_min, mult_max), curve)`.

Supported row keys today: `curve`, `ram_shatters` and the plating (`warden_plating`). The others work in the rule, but the boss plate (`src/ui/boss_plate.gd`) and the weak-point event (`src/combat/warden.gd`) still read `BossPosture`'s constants for the stagger length, so a row must not change `stagger_seconds` yet.

## How a run is measured

- Each run plays one seed of one policy (`brawler`, `skipper`, `camper`) on the slice table, in play, with the global RNG, the run and the bot seeded from the seed.
- A run broke the Warden when the driver noted `warden_broken_s` (`beacon_unsealed`), whatever the policy did. A camper run whose Warden broke counts as a camper break.
- Fight seconds run from the later of `warden_fight_s` (the bot's first turn to the Warden) and `warden_engaged_s` (the Warden's first ring entry or strike) to `warden_broken_s`; `BotDriver.fight_start_of` holds the rule. A skipper's roll from spawn to the Warden is not fight time. If only one of the two is noted, that one is the start.
- The driver's `fight_limit` ends a run `--cap` seconds after the same start as `fight_capped`; its `stage_limit` is raised to four caps so the brawler's growing time does not trip the old 240 s stage stall.
- A run that does not break the Warden (capped, died, stalled) counts as the cap in the medians and ranges, and in `*_never`.
- Heft is `run.heft()` at the first turn to the Warden.

## Columns of `posture_sweep.tsv`

`plating`, `curve`, `ram_shatters` name the cell. Then, for the brawler and the skipper, the median, minimum and maximum fight seconds over the seeds; `skipper_to_brawler` is the ratio of the two medians; `camper_broke` is how many camper runs broke the Warden; `brawler_heft_median` is the brawler's median heft at its first strike; `brawler_never`, `skipper_never`, `camper_never` count runs that never broke it; `brawler_died` and `skipper_died` count deaths among them. `posture_sweep_runs.tsv` has one row per run: `plating`, `curve`, `ram_shatters`, `policy`, `seed`, `outcome` (the driver's: `broken`, `fight_capped`, `died`, `stalled`), `broke`, `engaged_s` (seconds into the stage when the Warden was engaged, empty if never), `fight_s` (the cap when it did not break), `heft`, `game_s` (stage seconds the run lasted) and `note` (the run's anomaly kinds from `RunState.note_anomaly`, such as `warden_vanished`, then the driver's `stall_state`; empty when none, so a seal that opened because the Warden left the tree shows).

## Reading it against the bands

A cell meets the bands when all of these hold over seeds 1 to 5:

- `brawler_median_s` is 60 to 150 and `brawler_never` is 0.
- `skipper_to_brawler` is at least 1.5, or `skipper_never` is at least 3.
- `camper_broke` is 0.
- The two rule bands (50 hits outside a stagger leave health unchanged; a build at the 0.2 floor gains posture on every ram) are unit checks in `tests/unit/boss_posture_case.gd`, and hold under any `curve` because the floor ratio is above zero.

## Superseded: the 2026-10-02 result, old clock start

This table was measured with the first sweep, which started the fight clock at the bot's first turn to the Warden (so a skipper's roll from spawn counted) and counted a camper break only when the bot had struck. Both are fixed; the figures below are not evidence for any pick. The coordinator reruns the full sweep after growth on the map changes.

No cell met every band then. The sweep ran on the Reach before the map's activities landed.

| Cell (plating, curve, ram_shatters) | Brawler median | Brawler broke | Skipper median | Ratio | Camper broke | Misses |
| --- | --- | --- | --- | --- | --- | --- |
| 90, 2, true | 55.3 s | 5 of 5 | 87.0 s | 1.57 | 0 | brawler median under 60 by 4.7 s |
| 90, 3, false | 87.1 s | 4 of 5 | 131.4 s | 1.51 | 0 | one brawler seed never broke it |
| 75, 3, true | 70.2 s | 5 of 5 | 79.5 s | 1.13 | 0 | ratio 1.13 against 1.5 |
| 90, 3, true | 98.6 s | 5 of 5 | 109.2 s | 1.11 | 0 | ratio 1.11 against 1.1 |

The cause is in the build, not the curve. The brawler's median heft at its first strike is 1.04 to 1.10 across the grid, against the skipper's 1.0, so growth before the fight raises punch by under 10 percent and no exponent on the ratio can turn that into a doubled fight. Raising plating lengthens both bots' fights together. The ratio moves only when the grown build reaches the Warden with a clearly higher heft, which the map's activities are meant to supply.

## Repeatability

The same seed on the same build does not always give the same fight. Across two runs of cell 45 / 1 / true (15 runs each), the camper runs are not counted here, since the old sweep could not record a camper break; of the 10 runs that broke the Warden, 5 repeated to the hundredth of a second and 3 differed by more than 10 percent (brawler seed 3 by 23.0 percent, 28.61 s against 22.02 s; seed 4 by 12.3; seed 5 by 11.4). Three plain `bot_run.gd` processes started together on brawler seeds 1 to 5 disagreed on seeds 1, 3 and 5 (up to 5.5 percent), so the sweep is not the cause, and removing the chase camera's `randf_range` jitter (`src/movement/chase_camera.gd` line 199) did not make runs repeat. The cause was not found. Suspects, not tested: the audio bake and stem-load worker tasks (`src/presentation/audio.gd` lines 276 and 293), which finish at a wall-clock-dependent frame and allocate objects, and Jolt's body ordering. Read a medians difference under about 25 percent as noise until that is fixed.
