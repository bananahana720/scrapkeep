# Posture sweep

Finds the slice Warden's numbers (LEGIBILITY section 4) by playing bots whose arms differ by the ball's starting scrap over a grid of plating, `curve` and `ram_shatters`. The aim: a class III ball breaks the Warden in about half a minute, a class I ball can still break it but takes at least twice as long, and a ball that only shoots from range never does. A rerun after the map changes needs no hand work.

## Run it

One command, from the repository root (Godot 4.7.2, headless). It keeps six child processes going, one run each, so run it alone on the machine.

```
"$GODOT_BIN" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd -- --out=$PWD/artifacts/local/posture_sweep.tsv --runs=$PWD/artifacts/local/posture_sweep_runs.tsv
```

`--out` and `--runs` must be absolute paths, and belong under `artifacts/local/`. Copy the two files into `tools/` only when a sweep's data is the one to keep. Options after `--`:

| Option | Default | Meaning |
| --- | --- | --- |
| `--procs=N` | 6 | child processes, 1 to 6 |
| `--seeds=1,2,3,4,5` | 1 to 5 | seeds per arm per cell |
| `--cap=240` | 240 | seconds of fighting before a run counts as not broken |
| `--plating=`, `--curve=`, `--shatter=` | the full grid | comma lists that narrow it, e.g. `--plating=110 --curve=2 --shatter=false` is one cell |
| `--arms=small,grown` | all four | names from the `ARMS` table in the tool |

The 2026-10-02 run took 2437 s (40.6 minutes) for 320 runs at six processes. The machine's load average was 12.8 (1 minute), 15.3 (5 minutes) and 12.6 (15 minutes) of 32 threads when it started and 20.1 (1 minute) 28 seconds in; the end-of-run load was not recorded. The rerun of the picked cell (20 runs) took 158 s at load 24.6.

## The arms

One table, `ARMS` in `posture_sweep.gd`: name, policy, and the ball's starting mass.

| Arm | Policy | Start mass | Stands for |
| --- | --- | --- | --- |
| small | skipper | 0 | went straight to the boss (class I) |
| mid | skipper | 225 | did one activity (class II) |
| grown | skipper | 540 | did all three (class III) |
| camper | camper | 0 | only shoots from range |

The start mass reaches the run through the existing `--start-mass` launch flag. Heft is `1 + mass / 450`. The mass at the first strike is a little above the start, not below: the skipper's roll to the Warden picks up scrap faster than wear takes it (median 1.0 to 3.0 for small, 226 for mid, 542 for grown), so the heft at the first strike is 1.00, 1.50 and 2.20.

## The seam

The game reads its stage table through `ctx.stages`. After each `Game` is built the child replaces `ctx.stages` with a `Table` (an inner class of `posture_sweep.gd`) whose `of()` returns the slice row with `warden_plating` and a `posture` dictionary swapped in. No source file changes between cells. `combat.warden_spec` carries the row's `posture` to the Warden, which hands it to `BossPosture.new()`.

Supported row keys: `curve`, `ram_shatters` and the plating (`warden_plating`). The rule accepts more (`base`, `smash_base`, `mult_min` and others, see `src/combat/boss_posture.gd`), but the boss plate (`src/ui/boss_plate.gd`) and the weak-point event (`src/combat/warden.gd`) still read the constants for the stagger length, so a row must not carry them yet.

## How a run is measured

- Each run is its own process (`--arm`, `--run-seed`), with its own data folder and its own `XDG_*_HOME`. A bot run repeats exactly only in a fresh process (unit SD; `tests/bot_repeat_test.gd`), and the child applies the same spawn-order signs, audio bake and tick-based hit-stop as `tools/bot_run.gd`. Before this sweep, seed 1 of small and grown was run twice and gave the same fight seconds to the hundredth; the rerun of the picked cell gave 20 identical runs.
- Each sweep invocation puts its children's data under `<user data>/posture_sweep/p<parent pid>/job<n>` and removes a job's folder once its row is recorded, so two sweeps at once cannot share state.
- A run broke the Warden when the driver noted `warden_broken_s` (`beacon_unsealed`).
- **The clock the bands use.** Fight seconds run from the later of the bot's turn to the Warden (`turn_s`, the driver's `warden_fight_s`) and the first contact of any kind on it (`struck_s`, the first `enemy_struck` on the Warden) to `warden_broken_s`. `engaged_s` (the driver's `warden_engaged_s`, the first ring entry or strike, whichever is first) is recorded and not used for the fight clock. With no contact noted, `BotDriver.fight_start_of` stands in. The driver's own cap (`--cap` seconds after its `fight_start_of`) ends a run slightly sooner than the same cap counted from the strike; a run past the cap counts as the cap either way.
- A run that does not break the Warden (capped, died, stalled) counts as the cap in the medians and ranges.
- `mass` and `heft` are `run.mass` and `run.heft()` at the first contact.

## Columns

`posture_sweep_runs.tsv`, one row per run: `arm`, `seed`, `plating`, `curve`, `ram_shatters`, `outcome` (the driver's: `broken`, `fight_capped`, `died`, `stalled`; or `wall_timeout` and `no_result` when the child was killed or wrote nothing), `broke`, `engaged_s`, `struck_s`, `turn_s`, `fight_s` (the cap when it did not break), `mass`, `heft`, `game_s` (stage seconds the run lasted) and `note` (the run's anomaly kinds from `RunState.note_anomaly`, then the driver's `stall_state`; empty when none).

`posture_sweep.tsv`, one row per cell: `plating`, `curve`, `ram_shatters`; per arm `<arm>_median_s`, `_min_s`, `_max_s`, `_broke` (runs that broke the Warden), `_mass_median`, `_heft_median`; then `small_to_grown`, the four bands (`band_grown`, `band_small`, `band_mid`, `band_camper`, each `pass` or `miss`) and `pass`.

## Bands, fixed before the run

A cell passes only if all hold, on medians over five seeds, a run that never broke the Warden counted at the cap:

1. grown: fight of 25 to 45 s.
2. small: at least 2.0 times the grown median, at most 150 s, and it broke the Warden in 5 of 5.
3. mid: strictly between the grown and small medians.
4. camper: broke the Warden in 0 of 5.

**Pick.** Among passing cells, the largest small-to-grown ratio whose small median is at most 120 s; ties go to the lower plating, then `curve` 1, then `ram_shatters` true. The picked cell is run a second time, and a miss on any band there means the next passing cell is taken instead.

## Result, 2026-10-02

Grid: plating 70, 90, 110, 130; `curve` 1, 2; `ram_shatters` true, false; five seeds per arm, 16 cells, 320 runs, all four arms. Four cells pass every band: 110 / 2 / true, 110 / 2 / false, 130 / 2 / true and 130 / 2 / false. The two 130 cells have a small median over 120 s and are not eligible. Of the two 110 cells, `ram_shatters` false has the larger ratio (3.59 against 3.30), so the pick is **plating 110, curve 2, `ram_shatters` false**. Its second run (all four arms, five seeds) matched the first run for run: 20 of 20 fight seconds identical, all four bands pass again. Medians for the pick: grown 25.5 s, mid 44.9 s, small 91.8 s, camper never; ratio 3.59. The grown median sits 0.5 s above the band's lower edge.

| Plating | Curve | Rams shatter | Grown (25-45) | Small | Small/grown (>=2.0) | Small broke | Mid | Camper broke | Misses |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 70 | 1 | true | 19.4 s (miss) | 30.5 s | 1.57 | 5 of 5 | 23.3 s (pass) | 0 of 5 | grown 19.4 s outside 25 to 45; ratio 1.57 under 2.0 |
| 70 | 1 | false | 19.4 s (miss) | 34.0 s | 1.75 | 5 of 5 | 26.5 s (pass) | 0 of 5 | grown 19.4 s outside 25 to 45; ratio 1.75 under 2.0 |
| 70 | 2 | true | 19.4 s (miss) | 37.4 s | 1.92 | 5 of 5 | 22.0 s (pass) | 0 of 5 | grown 19.4 s outside 25 to 45; ratio 1.92 under 2.0 |
| 70 | 2 | false | 19.4 s (miss) | 46.6 s | 2.40 | 5 of 5 | 26.5 s (pass) | 0 of 5 | grown 19.4 s outside 25 to 45 |
| 90 | 1 | true | 20.4 s (miss) | 41.0 s | 2.01 | 5 of 5 | 31.0 s (pass) | 0 of 5 | grown 20.4 s outside 25 to 45 |
| 90 | 1 | false | 20.6 s (miss) | 41.3 s | 2.01 | 5 of 5 | 41.1 s (pass) | 0 of 5 | grown 20.6 s outside 25 to 45 |
| 90 | 2 | true | 19.5 s (miss) | 56.5 s | 2.90 | 5 of 5 | 43.0 s (pass) | 0 of 5 | grown 19.5 s outside 25 to 45 |
| 90 | 2 | false | 22.3 s (miss) | 80.4 s | 3.61 | 5 of 5 | 50.8 s (pass) | 0 of 5 | grown 22.3 s outside 25 to 45 |
| 110 | 1 | true | 25.0 s (pass) | 44.2 s | 1.77 | 5 of 5 | 31.2 s (pass) | 0 of 5 | ratio 1.77 under 2.0 |
| 110 | 1 | false | 25.1 s (pass) | 48.2 s | 1.92 | 5 of 5 | 34.9 s (pass) | 0 of 5 | ratio 1.92 under 2.0 |
| 110 | 2 | true | 25.5 s (pass) | 84.2 s | 3.30 | 5 of 5 | 42.8 s (pass) | 0 of 5 | none: all four bands pass |
| 110 | 2 | false | 25.5 s (pass) | 91.8 s | 3.59 | 5 of 5 | 44.9 s (pass) | 0 of 5 | none: all four bands pass |
| 130 | 1 | true | 28.0 s (pass) | 44.4 s | 1.59 | 5 of 5 | 36.1 s (pass) | 0 of 5 | ratio 1.59 under 2.0 |
| 130 | 1 | false | 34.3 s (pass) | 44.4 s | 1.29 | 5 of 5 | 47.8 s (miss) | 0 of 5 | ratio 1.29 under 2.0; mid 47.8 s not between grown and small |
| 130 | 2 | true | 40.8 s (pass) | 121.2 s | 2.97 | 5 of 5 | 51.4 s (pass) | 0 of 5 | none: all four bands pass |
| 130 | 2 | false | 42.7 s (pass) | 125.3 s | 2.94 | 5 of 5 | 55.1 s (pass) | 0 of 5 | none: all four bands pass |

Reading it: below plating 110 the grown ball arrives with so much heft (2.20) that it breaks the Warden in under 25 s whatever the curve. Curve 1 never separates the arms by 2.0 times at a plating a grown ball can still fight in 25 s or more. Curve 2 does, because it squares the ratio of punch to plating: a small ball's rams fall under the plating and gain little, a grown ball's land above it. At plating 130 curve 2 pushes the small median past 120 s.

`pin`: `tests/posture_bands_test.gd` plays the slice row on seeds 1 to 3 for small, grown and camper and holds the bands and the picked medians for those seeds (small 82.4 s, grown 39.2 s, re-pinned 2026-10-04, wave 9, after the bot_driver and warden_variant changes) to within 10 percent.

## Superseded: the first sweep (unit BN)

The first sweep (brawler against skipper, plating 45 to 90, no data kept) is superseded. It started the fight clock at the bot's turn, counted a camper break only when the bot had struck, and its "grown" bot reached the Warden at heft 1.04 to 1.10 because the bot does not know the map's activities. Its figures are not evidence for any pick. This sweep takes growth as given by starting the ball with the scrap a grown player would hold.

The first sweep's repeatability note is also superseded: unit SD found the cause (a scrap pickup's swirl side and a counter's strafe came from object-id parity) and fixed it for bot runs.

## Rerun on the merged wave, 2026-10-02

The first pick was made before growth pays (`kill_scrap` 4.0 on the slice row) joined it. With both in, kills during the fight pay four times the scrap, so a small ball grows mid-fight, and the picked cell's small median fell from 91.8 s to 85.8 s. The same grid was rerun on the merged build (320 runs, six processes, the machine otherwise idle). The pick rule chose the same cell, plating 110, `curve` 2, `ram_shatters` false: grown 25.5 s, mid 54.5 s, small 85.8 s, camper 0 of 5, ratio 3.36. The two tables in `tools/` are this rerun's.

Grown seed 2 broke the Warden only after 94.1 s, against 23.6 to 36.1 s for the other four seeds, so three-seed medians that include it sit under the 25 s floor. `tests/posture_bands_test.gd` therefore checks the bands on this five-seed table and pins its live seeds 1 to 3 to this rerun's medians for the same seeds (small 73.75 s, grown 24.66 s). Why grown seed 2 is slow is not yet traced.

## Alpha Wardens, 2026-10-03

The alpha table's two zone Wardens (Spillway reactor, plating 90, hp 650; Cable Reach swarm, plating 110, hp 800; posture `{curve 2.0, ram_shatters false}` on both) are not swept over the plating grid. They are played as they stand by `tools/bot_run.gd --table=alpha --policy=skipper|completionist --seeds=N --ticks=24000`, one process per seed and policy, and read from `bots.ndjson`. A fight is the stage clock at `warden_broken_s` less `warden_fight_s`, the bot's turn to the Warden. This is not the sweep's clock (it has no first-strike term), so the numbers are comparable among alpha rows only. The skipper goes straight to each Warden; the completionist does each stage's activities first (it turned to the Reach Warden at about 140 s). Runs repeat exactly in a fresh process.

Seeds 1, 2, 3, fight seconds (stage 1 / stage 2 skipper, stage 2 completionist):

| Seed | Spillway skipper | Reach skipper | Reach completionist |
| --- | --- | --- | --- |
| 1 | 66.50 | 41.95 | 29.01 |
| 2 | 63.90 | 64.99 | 26.16 |
| 3 | 67.16 | 40.07 | 20.35 |
| median | 66.5 | 42.0 | 26.2 |

Bands in `tests/posture_bands_test.gd`, set from these medians with room for a changed build: Spillway skipper median 45 to 90 s; Reach skipper median 30 to 80 s; Reach completionist median at most 1.25 times the Reach skipper's (measured 0.62). The completionist is faster, not slower, because it arrives with heft 2.8 to 3.0 against the skipper's 1.3 to 1.5; the factor only guards against a regression where doing the activities makes the fight longer. The Reach skipper's seed 2 (65 s) sits well above seeds 1 and 3 (about 40 s), so the three-seed median is not a tight estimate. No alpha camper arm: the slice camper row still holds the range-only rule on the same posture chassis.

2026-10-04, after B2's two-hook completionist hand (`tools/bot_driver.gd`): the Reach completionist fights are 26.82, 50.46 and 31.38 s on seeds 1, 2, 3 (median 31.4 s, 0.75 times the skipper's 42.0 s; skipper rows unchanged). Seed 2 broke the Warden at 190.47 s of the stage 2 clock after leaving stage 1 at 104.4 s, past the old 24000-tick cap, so the alpha rows now run 30000 ticks. With `--chain-hand=0` seed 2's fight is 26.16 s, as above: the hand slows the fight but does not starve it.

## Full current-driver rerun, 2026-10-04

**Owner decision: the documented pick rule now chooses plating 110, curve 2, `ram_shatters` true.** It passes all four bands with a small-to-grown ratio of 2.62, above the current pick's 2.44. Its confirmation run also passes every band and reproduces all 20 rows exactly. The slice pick remains **110 / 2 / false** under the writer brief; changing it requires an owner decision.

Measured on accepted `cand/alpha-w9`, base `aec5d2ed9a2937cb5ec4b57bb5259fed17cce029`, in `wt/alpha-w10-posture-sweep-full`. The full grid was rerun with the current `tools/bot_driver.gd`: 16 cells, all four arms, seeds 1 to 5, cap 240 s, six child processes, fixed FPS 90. Both committed TSVs now come entirely from this invocation. Every small, mid and grown run broke the Warden (240 runs); every camper reached its fight cap without breaking it (80 runs). There were no child timeouts, missing results or anomaly notes. Coverage, medians, ranges, break counts, ratios and bands were checked against the 320 raw rows. The sweep and driver sources stayed unchanged during measurement.

Three cells pass every band and the 120 s small-median eligibility limit:

| Rank | Plating | Curve | Rams shatter | Small | Mid | Grown | Small/grown | Camper broke |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 110 | 2 | true | 82.40 s | 37.66 s | 31.41 s | 2.62337 | 0 of 5 |
| 2, current pick | 110 | 2 | false | 80.96 s | 48.87 s | 33.22 s | 2.43709 | 0 of 5 |
| 3 | 130 | 2 | false | 83.48 s | 50.85 s | 39.21 s | 2.12905 | 0 of 5 |

There is no ratio tie, so the plating, curve and shatter tie-breakers do not apply. The new leader was rerun separately with all four arms and five seeds, as the pick rule requires. All 20 fight times and full rows match the grid, and all four bands pass again. The current pick also reproduces all 20 full rows of its committed wave-9 rerun.

Old means the table at `aec5d2e`, which mixed older grid measurements with the current pick's 2026-10-04 rerun. New means this full current-driver grid. Medians below are seconds, rounded as stored in the cell TSV; arrows show old to new. A camper median of 240 s means the cap, not a break.

| Plating | Curve | Rams shatter | Small old -> new | Mid old -> new | Grown old -> new | Camper old -> new | Ratio old -> new | Bands now |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 70 | 1 | true | 31.3 -> 33.0 | 23.3 -> 26.4 | 19.4 -> 19.6 | 240.0 -> 240.0 | 1.61 -> 1.69 | miss |
| 70 | 1 | false | 35.5 -> 35.6 | 26.0 -> 26.4 | 19.4 -> 19.6 | 240.0 -> 240.0 | 1.83 -> 1.82 | miss |
| 70 | 2 | true | 40.8 -> 38.5 | 22.0 -> 29.4 | 19.4 -> 19.6 | 240.0 -> 240.0 | 2.10 -> 1.97 | miss |
| 70 | 2 | false | 51.1 -> 46.3 | 26.0 -> 32.1 | 19.4 -> 19.6 | 240.0 -> 240.0 | 2.63 -> 2.36 | miss |
| 90 | 1 | true | 40.6 -> 37.9 | 28.5 -> 29.9 | 20.4 -> 21.2 | 240.0 -> 240.0 | 1.99 -> 1.78 | miss |
| 90 | 1 | false | 40.3 -> 38.6 | 31.8 -> 39.8 | 20.6 -> 21.2 | 240.0 -> 240.0 | 1.96 -> 1.82 | miss |
| 90 | 2 | true | 50.7 -> 56.3 | 38.6 -> 36.6 | 19.5 -> 23.0 | 240.0 -> 240.0 | 2.60 -> 2.45 | miss |
| 90 | 2 | false | 74.6 -> 59.8 | 49.0 -> 46.3 | 22.3 -> 23.9 | 240.0 -> 240.0 | 3.35 -> 2.50 | miss |
| 110 | 1 | true | 46.0 -> 39.9 | 31.2 -> 33.2 | 25.0 -> 28.8 | 240.0 -> 240.0 | 1.84 -> 1.39 | miss |
| 110 | 1 | false | 46.0 -> 45.3 | 38.4 -> 36.1 | 25.1 -> 28.8 | 240.0 -> 240.0 | 1.83 -> 1.57 | miss |
| 110 | 2 | true | 74.2 -> 82.4 | 46.2 -> 37.7 | 25.5 -> 31.4 | 240.0 -> 240.0 | 2.91 -> 2.62 | pass |
| 110 | 2 | false | 81.0 -> 81.0 | 48.9 -> 48.9 | 33.2 -> 33.2 | 240.0 -> 240.0 | 2.44 -> 2.44 | pass |
| 130 | 1 | true | 39.0 -> 41.7 | 36.1 -> 32.8 | 32.4 -> 28.9 | 240.0 -> 240.0 | 1.20 -> 1.44 | miss |
| 130 | 1 | false | 40.8 -> 42.5 | 43.9 -> 41.2 | 33.6 -> 31.7 | 240.0 -> 240.0 | 1.21 -> 1.34 | miss |
| 130 | 2 | true | 83.8 -> 72.4 | 51.0 -> 50.6 | 35.0 -> 38.5 | 240.0 -> 240.0 | 2.40 -> 1.88 | miss |
| 130 | 2 | false | 107.6 -> 83.5 | 63.6 -> 50.9 | 41.3 -> 39.2 | 240.0 -> 240.0 | 2.60 -> 2.13 | pass |

The current pick's live seeds 1 to 3 have small median 82.40 s and grown median 39.20 s, exactly the existing pins. Neither moved more than 10 percent. `EXPECT_SMALL_S` stays 82.4 and `EXPECT_GROWN_S` stays 39.2; `tests/posture_bands_test.gd` is unchanged.

The grid took **2820.6 s (47.0 minutes)**. Load averages at start were 3.1 / 3.6 / 6.9 and at end 17.9 / 21.8 / 20.9 (1 / 5 / 15 minutes, 32 threads). The leader's confirmation took **232.5 s (3.9 minutes)**. The import exited 0 but could not save global editor settings under the sandbox. Runs used writable `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` under the local evidence folder. Missing ACE music stems caused the existing synth fallback in the child runs; no Godot errors occurred in the sweep. These measurements establish bot combat bands, not human feel or audio acceptance.

Commands from the assigned repository root, with the same Godot 4.7.2 binary as above. `E` is the absolute path to `artifacts/local/posture-sweep-full-2026-10-04` in this worktree; set the three `XDG_*_HOME` variables to `$E/data`, `$E/config` and `$E/cache` for the run commands.

```sh
G="${GODOT_BIN:-godot}"
E="$PWD/artifacts/local/posture-sweep-full-2026-10-04"
"$G" --headless --path sketches/core-loop --import
export XDG_DATA_HOME="$E/data"
export XDG_CONFIG_HOME="$E/config"
export XDG_CACHE_HOME="$E/cache"
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd -- --out="$E/posture_sweep.tsv" --runs="$E/posture_sweep_runs.tsv"
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd -- --out="$E/leader-repeat.tsv" --runs="$E/leader-repeat-runs.tsv" --plating=110 --curve=2 --shatter=true
"$G" --headless --path sketches/core-loop --script res://tests/posture_bands_test.gd
npm run sketch:lint
```

All five commands above exited 0. `posture_bands_test` printed `PASS (9 checks)` in 106.3 s, and `sketch:lint` passed in 0.3 s. Receipts and before/after comparisons are under `artifacts/local/posture-sweep-full-2026-10-04/`. The initial timing-wrapper attempt exited 127 before launching Godot because `/usr/bin/time` was absent; a Python wrapper recorded the successful runs' wall seconds and exit codes instead.

## World 2 and 3 Wardens and bosses, 2026-10-04

The four world 2 and world 3 Wardens (Dig upper bench reactor, plating 130, hp 950; Dig deep works swarm, 150 / 1100; Highdraft mind, 170 / 1250; Highdraft crown mind, 190 / 1400; posture `{curve 2.0, ram_shatters false}` on all four) and the two world bosses, played as they stand by the skipper on `tools/bot_run.gd --table=alpha`, one process per seed and world. World 2 runs start with `--from-stage=3 --until=4`, so a run ends as the world 2 boss's victory enters stage 5. World 3 runs start with `--from-stage=5` and run to the run's end. No `entrance.json` exists in a fresh `--out`, so each run starts normally and is then sent to the stage: the ball enters stage 3 and stage 5 at heft 1.0 (`warden_fight_heft` in the stage notes), not grown as in a full run. A fight is `warden_broken_s` less `warden_fight_s` from the `bots.ndjson` stage notes, as in "Alpha Wardens" above. A boss is its `defeated_s` on the driver's boss clock (stepped sim time, not wall time). A Warden never broken counts at the driver's 240 s stall limit (`STAGE_LIMIT`); a boss never beaten counts at the 240 s cap. Medians are the upper median of eight (the fifth value sorted), the same rule as the tests.

The owner's ruling stands throughout: the Warden default stays "ram racks posture" (`ram_shatters` false; `docs/decisions.tsv`, 2026-10-04). These rows were measured as they are and nothing was tuned.

Seeds 1 to 8, skipper, fight and boss seconds, outcome and wall seconds per process (16 processes at once):

| Seed | Class | Stage 3 | Stage 4 | World 2 boss | World 2 run | Stage 5 | Stage 6 | World 3 boss | World 3 run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | runner_gunner | 69.10 | 42.04 | 22.02 | until, 67.3 s | 97.84 | never (240) | not reached | stalled at 6, 140.2 s |
| 2 | demolitions_caster | 67.51 | 48.95 | 21.33 | until, 77.5 s | 91.76 | never (240) | not reached | stalled at 6, 159.8 s |
| 3 | tarn | 62.76 | 41.32 | 18.13 | until, 61.1 s | 98.50 | never (240) | not reached | stalled at 6, 134.7 s |
| 4 | pylon_engineer | 68.90 | 40.59 | 24.43 | until, 63.6 s | 218.98 | never (240) | not reached | stalled at 6, 211.9 s |
| 5 | runner_gunner | 77.78 | 44.20 | 15.32 | until, 69.1 s | 98.99 | never (240) | not reached | stalled at 6, 141.1 s |
| 6 | demolitions_caster | 65.45 | 54.67 | 18.67 | until, 79.5 s | never (240) | not reached (240) | not reached | stalled at 5, 122.4 s |
| 7 | tarn | 68.00 | 38.69 | 15.22 | until, 64.5 s | 122.02 | never (240) | not reached | stalled at 6, 146.7 s |
| 8 | pylon_engineer | 71.44 | 38.09 | 22.50 | until, 65.3 s | never (240) | not reached (240) | not reached | stalled at 5, 137.1 s |
| median | | 68.90 | 42.04 | 21.33 | | 122.02 | 240 | 240 | |

Recorded at a four-pilot roster (seed % 4); the Class column no longer matches seed % 6.

Bands, fixed before the results: each Warden's median within 0.7 x to 1.6 x the stage-2 Reach skipper window (`REACH_SKIPPER_S` 30 to 80 s in `tests/alpha_posture_bands_test.gd`), so 21 to 128 s. This multiple is the w23 brief's reading of the plan, not a measured window. Each boss's median under 240 s.

Band reading:

- Stage 3 (68.9 s), stage 4 (42.0 s) and the world 2 boss (21.3 s) are inside their bands. World 2 holds neither a sponge nor a pushover for the skipper.
- Stage 5 (122.0 s) is inside the band by 6 s, but only five of eight seeds broke it in time; seed 4 took 219 s, and seeds 6 and 8 stalled in the beacon state with the Warden unbroken.
- Stage 6 misses: no seed broke the crown Warden in 240 s. All six that reached it stalled in the beacon state (`stall_state` "beacon"), with `wall_turns` 123 to 184 against 0.1 to 45 on the stage 5 fights that broke (153 and 55 on the two stage 5 stalls). The bot spent the stage turning off walls, so this may be a reach problem on the crown map rather than a sponge. That is an inference from the notes and was not traced.
- The world 3 boss misses because no run reached it.

Wall time for the eight-seed run was about 224 s (start 19:12:00, end 19:15:44 local). Load averages were 0.92 / 2.87 / 3.87 at start and 6.61 / 9.27 / 6.66 at end (1 / 5 / 15 minutes, 32 threads). The world 3 processes set the time: a run that stalls on stage 5 and then on stage 6 plays more than 480 game seconds.

`tests/alpha_posture_bands_w23_test.gd` now plays the six pinned (pilot, seed) pairs of "World 2 and 3 bands, pilots named, 2026-10-05 (wave 16)" below (twelve processes) and checks the same bands. On 2026-10-04 it ran seeds 1 to 4 by `seed % size` and took 189 s wall at load 2.44 at start. With the pins it took 111 s wall at load 4.25 at start (2026-10-05, PASS, 31 checks).

Commands from the worktree root:

```sh
G="${GODOT_BIN:-godot}"
"$G" --headless --path sketches/core-loop --import
# one of each per seed s in 1..8, all at once
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/w23-posture-bands-2026-10-04/w2-$s --policy=skipper --seeds=$s --table=alpha --from-stage=3 --until=4
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/w23-posture-bands-2026-10-04/w3-$s --policy=skipper --seeds=$s --table=alpha --from-stage=5
"$G" --headless --path sketches/core-loop --script res://tests/alpha_posture_bands_w23_test.gd
```

These are bot combat bands. They do not establish human feel.

## World 2 and 3 bands, pilots named, 2026-10-05 (wave 16)

The same Wardens, bosses, fight and boss measures, caps and band rule as the 2026-10-04 section above, re-recorded with each seed's pilot named. Method: base `cedd6b2` with this unit's `--pilot` change, skipper on `tools/bot_run.gd --table=alpha`, `--pilot=<class id>` per seed, eight seeds, 16 processes at once (one per seed and world), `--fixed-fps 90`. World 2 runs start `--from-stage=3 --until=4`; world 3 runs start `--from-stage=5`. Medians are the upper median of eight (the fifth value sorted). A Warden never broken counts at 240 s (`STAGE_LIMIT`); a boss never beaten counts at the 240 s cap. The bot's own mapping (`seed % roster size`) moves when the roster grows, so the pilot is named per seed. Seeds 1 to 6 are the pins in `tests/alpha_posture_bands_w23_test.gd`. Seeds 7 and 8 play the pilots those seeds played on 2026-10-04. Six of eight rows (seeds 1, 2, 3, 4, 7 and 8) compare directly with the old table.

| Seed | Class | Stage 3 | Stage 4 | World 2 boss | World 2 run | Stage 5 | Stage 6 | World 3 boss | World 3 run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | runner_gunner | 70.16 | 39.74 | 15.16 | until, 71.8 s | 109.17 | 53.42 | 11.74 | won, 88.0 s |
| 2 | demolitions_caster | 54.94 | 41.33 | 15.42 | until, 70.8 s | 85.14 | 48.10 | 9.11 | won, 82.7 s |
| 3 | tarn | 54.26 | 37.51 | 13.52 | until, 59.5 s | 91.42 | 49.97 | 10.38 | won, 81.2 s |
| 4 | pylon_engineer | 62.67 | 37.98 | 19.63 | until, 64.7 s | 128.41 | 82.05 | 12.09 | won, 108.1 s |
| 5 | tally | 59.69 | 38.71 | 21.08 | until, 65.4 s | 128.85 | 53.53 | 13.46 | won, 91.2 s |
| 6 | remembered_cannon | 70.50 | 39.66 | 15.70 | until, 86.8 s | 80.05 | 50.12 | 13.97 | won, 96.2 s |
| 7 | tarn | 56.20 | 37.39 | 13.52 | until, 61.7 s | 94.35 | 57.43 | 14.16 | won, 85.0 s |
| 8 | pylon_engineer | 70.81 | 43.54 | 24.16 | until, 71.5 s | 150.22 | 34.94 | 12.18 | won, 100.0 s |
| median | | 62.67 | 39.66 | 15.70 | | 109.17 | 53.42 | 12.18 | |

Each record's `class` matches its `--pilot`. No run stalled. Seeds 1 to 6 give the same seconds as the w23 test's run on the same tree.

Band reading (Wardens 21 to 128 s, bosses under 240 s):

- Stage 3 (62.67 s) is inside its band.
- Stage 4 (39.66 s) is inside its band.
- The world 2 boss (15.70 s) is inside its band.
- Stage 5 (109.17 s) is inside its band by 19 s. Three single runs are above 128 s: Sable on seeds 4 and 8 (128.41 and 150.22) and Tally on seed 5 (128.85). All three broke the Warden.
- Stage 6 (53.42 s) is inside its band. Every seed broke the crown Warden; the 2026-10-04 stalls do not recur at this base.
- The world 3 boss (12.18 s) is inside its band. Every run won.

Wall time: 121 s (start 15:00:23, end 15:02:24 local). Load averages: 5.94 / 8.47 / 8.77 at start, 16.72 / 13.34 / 10.61 at end (1 / 5 / 15 minutes, 32 threads).

Commands from the worktree root:

```sh
G="${GODOT_BIN:-godot}"
"$G" --headless --path sketches/core-loop --import
# one of each per (s, p) in (1 runner_gunner) (2 demolitions_caster) (3 tarn) (4 pylon_engineer)
# (5 tally) (6 remembered_cannon) (7 tarn) (8 pylon_engineer), all at once
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/w16-band-pilot-pins/w2-$s --policy=skipper --seeds=$s --pilot=$p --table=alpha --from-stage=3 --until=4
"$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/w16-band-pilot-pins/w3-$s --policy=skipper --seeds=$s --pilot=$p --table=alpha --from-stage=5
"$G" --headless --path sketches/core-loop --script res://tests/alpha_posture_bands_w23_test.gd
```

These are bot combat bands. They do not establish human feel.
