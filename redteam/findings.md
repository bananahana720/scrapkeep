# Red team, wave 34

Build `75099fa708`, 2026-11-10T21:17Z, 16 min in a 4-core cloud container. 6 bot runs across 1 personas and 6 pilots.

**0 blocker, 1 major, 2 minor, 3 to watch.**

## What Andrew would feel, worst first

1. **MAJOR** · stability · Hitch over 33 ms at the same moment in several runs (candidate, replay to confirm)
   A stutter in play that comes back on a beat, whoever is playing.
   Seen in 5: pylon_engineer seed 4478 as greedy: 10 shared moment(s), e.g. 262.8 s (106 ms, the boss), 266.5 s (102 ms, the boss), 270.3 s (133 ms, the boss), 272.1 s (264 ms, the boss); runner_gunner seed 4479 as greedy: 7 shared moment(s), e.g. 299.6 s (251 ms, the boss), 301.4 s (248 ms, the boss), 305.1 s (253 ms, the boss), 308.9 s (114 ms, the boss); demolitions_caster seed 4480 as greedy: 11 shared moment(s), e.g. 272.1 s (129 ms, the boss), 274.0 s (128 ms, the boss), 279.6 s (123 ms, the boss), 281.4 s (124 ms, the boss); ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/replay --policy=completionist --seeds=4478 --pilot=pylon_engineer --late-offer=take`
   replayed alone: moments 11, still hitched 0, still hitched without the music mix 0

2. **MINOR** · stage and world design · The ball gets stuck on stage 2 geometry
   You roll into a spot and have to back out and steer around, again and again.
   Seen in 1: runner_gunner seed 4479 as greedy: 6 stuck detours as greedy
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/replay --policy=completionist --seeds=4479 --pilot=runner_gunner --late-offer=take`

3. **MINOR** · stage and world design · The ball gets stuck on stage 6 geometry
   You roll into a spot and have to back out and steer around, again and again.
   Seen in 1: runner_gunner seed 4479 as greedy: 3 stuck detours as greedy
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/replay --policy=completionist --seeds=4479 --pilot=runner_gunner --late-offer=take`

## Watch (not bugs on the bar; taste or tuning)

1. **WATCH** · stability · Main-thread tick p99 over 10 ms on the cloud box
   Headroom is thin; check with MangoHud on Andrew's PC.
   Seen in 6: pylon_engineer seed 4478 as greedy: p99 13.1 ms; runner_gunner seed 4479 as greedy: p99 15.3 ms; demolitions_caster seed 4480 as greedy: p99 12 ms; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=artifacts/local/replay --policy=completionist --seeds=4478 --pilot=pylon_engineer --late-offer=take`

2. **WATCH** · in-run growth · Item fuzz outlier: frame_time
   A build costs more time per tick than its cap; timed under load on the cloud box, so recheck alone.
   Seen in 6: tally seed 4450: p99 21.4 ms (cap 16.7 ms), build cross_split hot_rivets galvanic_rounds double_feed ...; remembered_cannon seed 4451: p99 31.4 ms (cap 16.7 ms), build scrap_gravity magnet_spool cache_key sunforged_core ...; pylon_engineer seed 4452: p99 27.6 ms (cap 16.7 ms), build brace_frame scrap_gravity arc_coil double_feed ...; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/item_fuzz.gd -- --seeds=4450 --seconds=60 --out=artifacts/local/replay`

3. **WATCH** · stability · 489 scattered ticks over 33 ms
   Most likely the shared cloud box; MangoHud on Andrew's PC is the check.

## Runs

| Persona | Pilot | Seed | Outcome | Stage | Game min | Hits/piles | Tick p99 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| greedy | pylon_engineer | 4478 | won | 6 | 15.1 | 15/0 | 13.1 |
| greedy | runner_gunner | 4479 | won | 6 | 15.0 | 17/0 | 15.3 |
| greedy | demolitions_caster | 4480 | won | 6 | 14.9 | 161/0 | 12 |
| greedy | tarn | 4481 | won | 6 | 14.3 | 29/0 | 12.8 |
| greedy | tally | 4482 | won | 6 | 15.3 | 43/0 | 10.7 |
| greedy | remembered_cannon | 4483 | won | 6 | 16.1 | 15/0 | 12.9 |

Item fuzz: item_fuzz: 6 seeds, 6 anomalies, 10 of 12 trigger kinds fired naturally somewhere, written to /home/andrew/scratch/gate/w34/bC/artifacts/local/redteam/w34-greedy-20261110T211737/jobs/item-fuzz.

Placeholders by kind: none.

## Limits

Bots play the real game from the source tree headless, so this finds stalls, crashes, script errors, pile-ups, rule-breaking builds and CPU hitches. It does not see the GPU, the picture or feel: hitches are main-thread ticks on a shared 4-core box, and a stall is a candidate until a replay confirms it. Andrew's sitting and MangoHud on his PC decide those.
