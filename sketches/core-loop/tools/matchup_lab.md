# Matchup lab

`tools/matchup_lab.gd` is lever 7 of `design-v3/ENEMY-PRIORITY.md`: a headless duel table. Each of the six pilots fights each enemy kind alone, N seeds each, and the lab records time to kill and hull lost. It prints a pilot x kind heatmap, marks the HARD cells and grades the gate. `tests/matchup_lab_test.gd` covers the pure logic and a small real table.

## Usage

```
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/matchup_lab.gd -- \
  --out=<abs ndjson> [--procs=4] [--seeds=1,2,3,4,5,6,7,8] [--cap=40] [--dodge=0.65] \
  [--pilots=tarn,tally] [--kinds=chaser,lobber] [--answer=1] \
  [--bot-no-mix=1 --bot-no-visuals=1 --bot-no-pilot-tracks=1]
```

- `--out` is required. The ndjson holds one row per duel (`pilot`, `class`, `kind`, `seed`, `give`, `outcome`, `ttk_s`, `hull_lost`, `damage_taken`, `hits`, `kill_dist_m`, `warnings`, `joined`, `duel_s`, `phase`). The heatmap text is written beside it as `<out>.heatmap.txt` and printed.
- Each duel is its own Godot process (a bot run repeats exactly only in a fresh one), `--procs` at a time. Run it under `nice -n 10`, at most 6 processes.
- Runtime: about 30 to 40 s of wall time per duel, almost all of it boot, stage load and settle (a duel itself is seconds). Six processes give about 7 s per duel. 27 kinds x 6 pilots x 4 seeds is 648 duels, about 80 minutes; 8 seeds doubles it. The small test table is 12 duels, about 2 minutes.
- `--bot-no-*` are the same fast flags `bot_run.gd` takes (audio mix, visuals, cosmetic pilot tracks).

## What a duel is

The harness is `tools/priority_proof.gd`'s: a calm map (no Warden, no director packs), `Game` in test mode, the bot driver, the same dodge share (`--dodge`, default 0.65: each telegraph is answered or missed once, decided from the seed). The pilot is the brawler bot (the completionist profile, which fights with every verb) playing the class under test. After 1 s grounded the lab spawns one enemy 18 m ahead of the ball and the bot fights it until the enemy and anything it made are down (`killed`), the pilot dies (`died`), or the cap passes (`capped`). Time to kill (`ttk_s`) runs from the spawn to the enemy's death; a split kind (the Splitter) is won when its pieces are down too, while `ttk_s` keeps the main body's death. Hull lost is the run's own `hull_damage` counter over the duel.

Kinds are `Director.KIND_NAMES` that the roster has built, minus `linker` (it guards a partner, so there is nothing to duel alone) and `foreman` (it never attacks; its row is its crew). Both are measured by `priority_proof.gd`. Bosses and wardens are not in `KIND_NAMES`. Every other named kind spawned and died alone in a probe run (27 kinds).

## HARD cell, exactly

- Cell value: the median over the cell's seeds of time to kill. A duel not won (died, capped, wall timeout counts as no result and is left out) counts the cap.
- Row: one kind across the six pilots. Row median: the median of its six cell medians, floored at 1.0 s (`MIN_ROW_S`) so a row of near-instant kills cannot make a one-second cell hard.
- A cell is HARD when its median is strictly greater than 2.0 x its row median (`HARD_RATIO`).

## Gate

1. Every pilot has at least one HARD cell. PASS or FAIL.
2. The brawler bot wins each hard cell once given that cell's answer item. A win is a kill in at least half the seeds with a median time no longer hard against the baseline row median. The answer item is the first part id (sorted) whose row carries an `answers` tag for the cell's axis and whose `class` gate admits the pilot. The axis per kind is `ANSWER_AXIS` in the lab (range, spread, fuse, cc, air, plating; a kind not listed answers to range). The part is handed over with `run.add_part` before the spawn and the cell is re-duelled on the same seeds.
   `answers` tags exist only on the Systems lane's branch. On a base without them the lookup finds no field, and every hard cell reports `answer: pending (no answers tags on this base)`; the second gate line is then INCONCLUSIVE, never a pass or a fail.

The verdict is FAIL if part 1 fails or any answer arm is lost, INCONCLUSIVE if any answer is pending, otherwise PASS.

## Reading the heatmap

Rows are kinds with their row median in seconds; columns are pilots. Each cell reads `median-ttk[median-hull-lost]`, and a `*` marks a HARD cell. A cell of `40.0*` with seeds all capped means the pilot never killed that kind inside the cap. A `-` means no run produced a result. After the grid, one line per pilot lists its hard cells with the answer-arm status, then the gate lines.

Caveats: the duel starts 1 s after landing, so the ball still carries the drop-in's speed; fast contact kills can flatten rows of light kinds. Automated bots do not establish human feel.
