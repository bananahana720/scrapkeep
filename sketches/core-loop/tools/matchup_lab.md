# Matchup lab

`tools/matchup_lab.gd` is lever 7 of `design-v3/ENEMY-PRIORITY.md`: a headless duel table. Each of the six pilots fights each enemy kind alone, N seeds each, and the lab records time to kill and hull lost. It prints a pilot x kind heatmap, marks the HARD cells and grades the gate. `tests/matchup_lab_test.gd` covers the pure logic and a small real table.

## Usage

```
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/matchup_lab.gd -- \
  --out=<abs ndjson> [--procs=4] [--seeds=1,2,3,4,5,6,7,8] [--cap=40] [--dodge=0.65] \
  [--pilots=tarn,tally] [--kinds=chaser,lobber] [--answer=1] [--range=18] [--idle=0] \
  [--bot-no-mix=1 --bot-no-visuals=1 --bot-no-pilot-tracks=1]

# pack mode: authored packs as the opponent instead of single kinds
godot ... -- --out=<abs ndjson> --packs=run_down,grounded|all [--table=park|alpha]  # --table only picks the pack list [--pilots=...] [--seeds=...]
```

- `--out` is required. The ndjson holds one row per duel (`pilot`, `class`, `kind`, `seed`, `give`, `outcome`, `ttk_s`, `hull_lost`, `damage_taken`, `hits`, `kill_dist_m`, `warnings`, `joined`, `duel_s`, `settle_s`, `rest_forced`, `phase`). The heatmap text is written beside it as `<out>.heatmap.txt` and printed.
- Each duel is its own Godot process (a bot run repeats exactly only in a fresh one), `--procs` at a time. Run it under `nice -n 10`, at most 6 processes.
- Runtime: about 30 to 40 s of wall time per duel, almost all of it boot, stage load and the rest wait (a duel itself is seconds). Six processes give about 7 s per duel. 27 kinds x 6 pilots x 4 seeds is 648 duels, about 80 minutes; 8 seeds doubles it. The small test table is 12 duels, about 2 minutes.
- `--from=<a.ndjson,b.ndjson> [--out=<txt>]` runs nothing: it rebuilds the heatmap and baseline gate from saved rows (use it to merge batches; the answer arm reads pending there).
- `--range=<m>` sets the spawn distance (default 18). `--idle=1` makes the pilot stand and never fight: the test's planted positive control that a duel can hurt the ball (an idle tarn 6 m from a plated brute or a lobber takes hits and loses hull). Neither is part of the table.
- `--packs=<id,id,...|all>` puts the lab in pack mode (see Pack duels); `--table=park|alpha` picks the pack table (default `park`, the table the launched game plays). In pack mode `--kinds` is ignored. An unknown pack id or table is a usage error (exit 2). `--range` still overrides the pack default of 12.
- `--bot-no-*` are the same fast flags `bot_run.gd` takes (audio mix, visuals, cosmetic pilot tracks).

## What a duel is

The harness is `tools/priority_proof.gd`'s: a calm map (no Warden, no director packs), `Game` in test mode, the bot driver, the same dodge share (`--dodge`, default 0.65: each telegraph is answered or missed once, decided from the seed). The pilot is the brawler bot (the completionist profile, which fights with every verb) playing the class under test.

**Rest start.** The drop-in leaves the ball fast, so the lab waits until the ball is grounded and slower than 0.5 m/s (`REST_SPEED`) and holds that for 2.0 s (`SETTLE_S`) before it spawns anything. If the ball has not come to rest 6 s after first landing (`REST_WAIT_S`), the lab sets its velocity to zero through the player's own `set_velocity_now` and keeps waiting; at 12 s (`SETTLE_MAX_S`) the duel starts regardless. The row records `settle_s` (seconds from first landing to the spawn) and `rest_forced` (true when the zero-velocity nudge fired).

**Beacon pinned.** The calm map's beacon charges from the start (the ball begins inside its ring, and `ctx.calm` does not stop `beacon.advance`); about 24 s later it runs gates, launch and the next stage, which frees every enemy of the duel, so a long duel read `killed` with `ttk_s` -1 and a negative `duel_s`. The lab sets `flow.beacon_seconds_override` to an unreachable value for kind and pack duels alike. As a backstop, a run whose `run.stage` changes or whose `stage_time` drops below the spawn time ends as `stage_changed` (row field `stage_changed` true), which counts as no result like `no_result` and `wall_timeout`.

**Damage.** `ctx.calm` stays on for the whole duel. It gates the Warden, the director's packs (which swamped a 40 s duel when calm was off: 12 to 27 adds joined), flood and event pushes, and hit knockback; it never gated an enemy's attack or the damage it deals (`combat._on_player_hit` always calls `run.damage`). The enemy under test attacks under the game's own rules, including its attack budget. At the spawn the lab sets max hull to 99999 (`HULL_POOL`) so a lost duel does not end the run. `hull_lost` is the run's `hull_damage` counter over the duel; `hits` and `damage_taken` count `player_hit` events from the spawn.

The lab spawns one enemy 18 m ahead of the ball and the bot fights it until the enemy and anything it made are down (`killed`), the pilot dies (`died`; effectively never with the large hull), or the cap passes (`capped`). Time to kill (`ttk_s`) runs from the spawn to the enemy's death; a split kind (the Splitter) is won when its pieces are down too, while `ttk_s` keeps the main body's death. Hull lost is the run's own `hull_damage` counter over the duel.

Kinds are `Director.KIND_NAMES` that the roster has built, minus `linker` (it guards a partner, so there is nothing to duel alone) and `foreman` (it never attacks; its row is its crew). Both are measured by `priority_proof.gd`. Bosses and wardens are not in `KIND_NAMES`. Every other named kind spawned and died alone in a probe run (27 kinds).

## Pack duels

A pack duel puts one named authored pack in front of the pilot instead of one kind, so a counter pack (a plated rig over a catch cup, three chasers and a lobber) can show up as a hard cell that no single-kind row reveals. The pack table is each stage's `packs` plus its `elite` from `ParkDefs.DEFS` (or `AlphaDefs.DEFS` with `--table=alpha`). `--table` only picks which pack list; pack duels play the same calm legacy map as kind duels. The parent hands each child `--pack-table=<id>`, never `--table=`, because `Game._chosen_table()` reads `--table=` from the command line and would move the duel onto a park or alpha stage map. `--packs=all` is every distinct id in first-seen stage order (a stage's packs, then its elite). Duplicate ids collapse; if one id carried different kinds in different stages the first stage's kinds are used. `pack_kinds(table, id)` and `pack_ids(table)` are the pure lookups.

- Same harness as a kind duel: rest start, calm map, `HULL_POOL`, the dodge share and the brawler driver. `ctx.calm` stays on exactly as in Damage above: it gates director packs, the Warden, flood and event pushes and hit knockback, not enemy attacks or the damage they deal, so the pack hurts the ball under the game's own rules. It is not turned off.
- Every member spawns with `combat.spawn_enemy` side by side across the line at the duel range, spaced `Director.PACK_SPREAD` (4.5 m) with the centered offsets `(i - (n-1)/2) * spread` along the side vector, as `Director._place_pack` does, each dropped with `terrain.drop_point`. The default range is 12 m (`PACK_RANGE`), shorter than 18, so the whole line is in play; `--range` overrides it. Members the roster has not built are skipped and listed in the row's `skipped`. Linker and Foreman are legitimate in packs (they are skipped only as single-kind rows).
- The driver fights the nearest live member (or anything a member made). `ttk_s` is the time the whole pack and its adds are down, the `_cleared()` rule; `first_down_s` is when the first member fell. `kill_dist_m` is -1 in pack mode.
- Row key: the row is `pack:<id>` in the `kind` field, so the table, hard cells, gate, heatmap and `--from` treat it like any kind. Each row also carries `pack` (id), `members` (kinds), `table`, `spawned` (members that spawned) and `skipped`. The heatmap label is `+<id>` cut to 9 characters.
- Answer arm: the axis is the most common `ANSWER_AXIS` among the members (ties go to the earlier entry of `AXES`), then the lookup and the paired re-duel are unchanged.
- Entering the gate: `--from=<kinds.ndjson>,<packs.ndjson>` lists kind rows first (default kind order) and pack rows after, in first-seen order, in one heatmap and one gate; pack rows count toward each pilot's hard cell like kind rows. A pack id from the park and alpha tables with the same id would share a row in a merge, so merge one table's packs at a time.
- Runtime: a pack duel costs the same boot and rest wait as a kind duel (about 30 to 40 s of wall time, 12 s of it the rest start under `--procs=2`). `--packs=all` on the park table is about 15 packs; 15 x 6 pilots x 4 seeds is 360 duels, roughly 45 minutes at six processes. The small pack smoke (2 packs x 2 pilots x 1 seed, 4 duels) takes about a minute.
- Caveats: members spawn without the Director's arrival effects: no elite affixes (the HARD-tier plated_brute affix, the Dig's PLATED on elites), so `dig_elite` and `elite` are measured unarmoured, and every member gets stage 1's HP, threat and world, not its home stage's. A pack whose members all fail to spawn records `no_result` and is left out of the table. The Director's Ballast heavy rim placement (`rim_spot`) and the park safe-spot and pack-gap filters are not reproduced; the line sits flat at the duel range. Pack duels are one pack alone on a calm map, not a live arrival with the director's pressure.

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

Caveats: duels start from rest, so a ball that never rests on a slope is nudged to zero (see `rest_forced`); hull lost is damage dealt, not a death count. Automated bots do not establish human feel.
