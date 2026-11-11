# Red team, wave 35

Build `0e258a0e19`, 2026-11-11T05:14Z, 7 min in a 4-core cloud container. 6 bot runs across 1 personas and 6 pilots.

**0 blocker, 0 major, 0 minor, 4 to watch.**

## What Andrew would feel, worst first

Nothing the bug bar grades.

## Watch (not bugs on the bar; taste or tuning)

1. **WATCH** · stability · Main-thread tick p99 over 10 ms on the cloud box
   Headroom is thin; check with MangoHud on Andrew's PC.
   Seen in 6: pylon_engineer seed 4584 as line-rider: p99 12.8 ms; runner_gunner seed 4585 as line-rider: p99 13.1 ms; demolitions_caster seed 4586 as line-rider: p99 16.2 ms; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/replay --policy=traversal --seeds=4584 --pilot=pylon_engineer --from-stage=1 --ticks=8100`

2. **WATCH** · in-run growth · Item fuzz outlier: frame_time
   A build costs more time per tick than its cap; timed under load on the cloud box, so recheck alone.
   Seen in 6: demolitions_caster seed 4550: p99 25.0 ms (cap 16.7 ms), build spiral_wave frost_barb loose_trigger frost_barb ...; tarn seed 4551: p99 22.6 ms (cap 16.7 ms), build scrap_gravity rivet_seam tempest_core fast_hands ...; tally seed 4552: p99 21.1 ms (cap 16.7 ms), build rime_rounds double_feed scrap_gravity cross_split ...; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/item_fuzz.gd -- --seeds=4550 --seconds=60 --out=artifacts/local/replay`

3. **WATCH** · stability · 31 scattered ticks over 33 ms
   Most likely the shared cloud box; MangoHud on Andrew's PC is the check.

4. **WATCH** · stability · Dense fight CPU frame p99 19.348 ms, max 46.877 ms
   The biggest crowd the game builds costs more than a frame.
   p99 19.348, max 46.877, p50 8.009

## Runs

| Persona | Pilot | Seed | Outcome | Stage | Game min | Hits/piles | Tick p99 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| line-rider | pylon_engineer | 4584 | ticks_done | 1 | 1.5 | 8/0 | 12.8 |
| line-rider | runner_gunner | 4585 | ticks_done | 2 | 1.5 | 5/0 | 13.1 |
| line-rider | demolitions_caster | 4586 | ticks_done | 3 | 1.5 | 16/0 | 16.2 |
| line-rider | tarn | 4587 | ticks_done | 4 | 1.5 | 9/0 | 17.3 |
| line-rider | tally | 4588 | ticks_done | 5 | 1.5 | 15/0 | 14.7 |
| line-rider | remembered_cannon | 4589 | ticks_done | 6 | 1.5 | 1/0 | 15.3 |

Item fuzz: item_fuzz: 6 seeds, 6 anomalies, 10 of 12 trigger kinds fired naturally somewhere, written to /home/andrew/scratch/gate/w35-0e258a0e/wt/1/artifacts/local/redteam/w35-line-rider-20261111T051435/jobs/item-fuzz.

Placeholders by kind: none.

## Limits

Bots play the real game from the source tree headless, so this finds stalls, crashes, script errors, pile-ups, rule-breaking builds and CPU hitches. It does not see the GPU, the picture or feel: hitches are main-thread ticks on a shared 4-core box, and a stall is a candidate until a replay confirms it. Andrew's sitting and MangoHud on his PC decide those.
