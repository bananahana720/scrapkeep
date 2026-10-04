# Posture sweep

Finds the slice Warden's numbers (LEGIBILITY section 4) by playing bots whose arms differ by the ball's starting scrap over a grid of plating, `curve` and `ram_shatters`. The aim: a class III ball breaks the Warden in about half a minute, a class I ball can still break it but takes at least twice as long, and a ball that only shoots from range never does. A rerun after the map changes needs no hand work.

## Run it

One command, from the repository root (Godot 4.7.2, headless). It keeps six child processes going, one run each, so run it alone on the machine.

```
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd -- --out=$PWD/artifacts/local/posture_sweep.tsv --runs=$PWD/artifacts/local/posture_sweep_runs.tsv
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
