# Systems audit pass B: economy sim results (before and after)

This branch holds outputs only. It shares no history with the game. It was run on Andrew's PC on 11 Nov 2026: AMD Ryzen 9 5950X (32 threads), Linux 7.2.15, Godot 4.7.2 (`/usr/bin/godot`). Headless, CPU only, no GPU. Each arm ran from its own scratch worktree.

## Arms and sources

| Arm | Runs | Commit | Branch |
| --- | --- | --- | --- |
| before | 24 rusher, 24 completionist, 24 minmax (seeds 2860 to 2883) | 87784f5a | `claude/project-thread-37yl0c` |
| after, rusher and completionist | 3 rusher, 3 completionist (seeds 2860 to 2862) | af3e49df | `scratch/sysaudit-econ-after` (first head) |
| after, minmax | 24 minmax (seeds 2860 to 2883) | 5fec469f | `scratch/sysaudit-econ-after` (head after the probe fix: the min-maxer now presses Moss's scale) |

Superseded and **not in this branch**: 7 minmax runs that started at af3e49df (seeds 2860 to 2866). They were stopped partway when the probe fix landed, and the min-maxer in them never pressed Moss's scale. They stay on the PC under `~/scratch/w37-pc/econ-out/after/minmax-*`.

Check that the fix took: the `weigh` events in the minmax ledgers number 0 in the before arm, and 166 in the after arm, across all 24 runs.

## Commands

Each command ran from the repo root of its worktree, with `GODOT_BIN=/usr/bin/godot` and `nice -n 10`:

```sh
# before, 87784f5a. The minmax type ran as a second, parallel call into the same folder; run.sh skips finished seeds.
JOBS=7 EXTRA= bash docs/systems-audit/economy/run.sh <out>/before 2860 24 rusher completionist minmax
JOBS=7 EXTRA= bash docs/systems-audit/economy/run.sh <out>/before 2860 24 minmax
# after, af3e49df
JOBS=7 EXTRA=--moss-scale=on bash docs/systems-audit/economy/run.sh <out>/after 2860 3 rusher completionist
# after, 5fec469f
JOBS=7 EXTRA=--moss-scale=on bash docs/systems-audit/economy/run.sh <out>/after-minmax-5fec 2860 24 minmax
# analysis (the 5fec469f copy of analyse.py)
python3 -I docs/systems-audit/economy/analyse.py runs/before analysis before
python3 -I docs/systems-audit/economy/analyse.py runs/after analysis after
```

Wall time:
- before: 4121 s, from 20:23:53Z to 21:32:34Z. Its minmax part took 1848 s, alongside the rest.
- after, minmax at 5fec469f: 1847 s.
- after, rusher and completionist at af3e49df: about 910 s, ending 20:39Z.

JOBS was 7 for each call. Up to three calls overlapped, so as many as 21 Godot processes ran at once. Every run uses `--fixed-fps 90`, so the load changes wall time only, not the game results.

## Layout

- `runs/<arm>/<type>-<seed>/econ-<seed>.ndjson` and `bots.ndjson`, with one `<type>-<seed>.log` per run.
- `analysis/<arm>-runs.json`, `<arm>-summary.json`, `<arm>-cogs-flow.svg`, `<arm>-cogs-held.svg`.

## Headline medians (from `analysis/*-summary.json`)

| Type | Arm | Runs | Wins | Game min | Cogs earned | Cogs spent | Cogs at end | Parts at end | Brindle s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Rusher | before | 24 | 24 | 7.00 | 1559 | 0 | 1559 | 3 | 84.1 |
| Rusher | after | 3 | 3 | 7.08 | 1630 | 0 | 1630 | 3 | 84.4 |
| Completionist | before | 24 | 23 | 9.81 | 2012.5 | 0 | 2012.5 | 6 | 85.1 |
| Completionist | after | 3 | 3 | 10.36 | 1956 | 0 | 1956 | 6 | 78.5 |
| Min-maxer | before | 24 | 24 | 6.86 | 1614.5 | 979 | 612.5 | 19 | 83.6 |
| Min-maxer | after | 24 | 22 | 6.94 | 1555.5 | 1260.5 | 496.5 | 16 | 83.3 |

The min-maxer's shelf visits (the stage 1 and stage 2 shops):

| Arm | Stage 1: bought out, share of wallet spent | Stage 2: bought out, share of wallet spent |
| --- | --- | --- |
| before | 24 of 24, 48% | 12 of 24, 89% |
| after | 19 of 24, 117% (Moss's scale tops the wallet up) | 5 of 23, 108% |

The flags are in the summary files. On both arms, the rusher and completionist hoard and spend 0 cogs, gain 0 cores, and win over 60%. In the after arm, the 3-seed rusher and completionist arms are replays, not rates.

## PR 777 arms: scale on and scale off, at 7a210caa

Both arms run the head of `scratch/sysaudit-econ-after` at 7a210caa. This probe stops the scale before a press would drop the boarding class, counts heals as regen, and writes the end row. Each arm ran 24 minmax runs, seeds 2860 to 2883. Both ran at once on the PC, from 21:55Z to 22:24Z, with a scratch data home (`env-pc.sh w37pc-econ7a21`). The run times were 1764 s for scale on and 1766 s for scale off.

```sh
JOBS=7 EXTRA=--moss-scale=on bash docs/systems-audit/economy/run.sh <out>/after-scale-on 2860 24 minmax
JOBS=7 EXTRA=            bash docs/systems-audit/economy/run.sh <out>/after-scale-off 2860 24 minmax
python3 -I docs/systems-audit/economy/analyse.py runs/after-scale-on analysis after-scale-on
python3 -I docs/systems-audit/economy/analyse.py runs/after-scale-off analysis after-scale-off
```

| Arm | Wins | Cogs earned | Cogs spent | Cogs at end | Parts at end | Weighs (all runs) | Stage 1 shelf: bought out, share of wallet | Stage 2 shelf: bought out, share of wallet |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| scale on | 24/24 | 1586.5 | 1261.5 | 517.5 | 16 | 134 | 19 of 24, 109% | 2 of 24, 108% |
| scale off | 24/24 | 1613.5 | 1115 | 499 | 13 | 0 | 13 of 24, 97% | 0 of 24, 97% |
