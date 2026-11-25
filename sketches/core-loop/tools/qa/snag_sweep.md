# Snag sweep

`snag_sweep.gd` rolls a ball at cruise along and over each large static piece of one map and lists
the places where it loses at least half its speed against a contact facing its line of travel.
What a piece, a lane and a snag are is in `snag_probe.gd`; the planted control is
`tests/snag_sweep_test.gd` (run it first: a sweep that says zero means nothing if that test is red).

## Run

One map, one process:

    $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/qa/snag_sweep.gd -- \
      --map=park_flume --out=<file.json>

`--map` is a park table map (`park_flume`, `park_dam`, ...) or `arena` (the Slag Bowl). Run it with
`nice -n 10` and with the environment line from CONTRIBUTING sourced. The flume is 1012 lanes: four shards
together took 35 minutes of process time (wave 36, load 40 to 78), so shard it.

## Shard and merge

Four shards at once (each finished in 486 to 575 s of wall time at load 40 to 78 on the wave 36 PC), then
one merge (it boots no map):

    ... --script res://tools/qa/snag_sweep.gd -- --map=park_flume --out=flume-0of4.json --shard=0/4
    ... --shard=1/4 ... --shard=2/4 ... --shard=3/4
    ... --script res://tools/qa/snag_sweep.gd -- --merge=flume-0of4.json,flume-1of4.json,flume-2of4.json,flume-3of4.json --out=flume.json

The merge refuses a file from a killed run (`"complete": false`) or from another map or seed.

## What comes out

Printed: start and end wall time and the 1-minute load, then the summary. The JSON holds no clock, so
two runs of one shard compare with `cmp`. It is rewritten after every piece, so a killed run leaves
what it finished.

- `classes_raw`, `classes_places`: snag counts by what was hit. `piece`: the piece the lane was aimed
  at (or a part of it). `ground`: terrain tiles or the map's own floor. `other`: any other collider.
  `moving`: a lift, barge or other moving body, whatever lane met it (see Moving pieces). A contact with
  an actor (anything that takes damage: an enemy, a boss piece such as Brindle's hull in the bowl) is
  not the map and is never a snag.
- `places`: snags within 2 m of each other on one collider are one row with `count`, `worst_loss`,
  `speed_before` and `speed_after` at the worst, `pieces` (how many pieces' lanes reached it) and
  `drawn` (a drawn mesh covers the contact; under `--headless` a MultiMesh is not indexed, so false
  is a lower bound, see `multimesh_trusted`).
- `classes_ride_raw`, `classes_ride_places`, `ride_places`: the same counts and deduped places
  filtered to `ride` lanes (low rideable pieces the ball rolls over). A ride lane runs 10 m before
  the entry edge (`RUN_M`) and 5 m past the exit edge (`RIDE_RUNOUT_M`), enough to register any
  exit-rim snag or immediate exit blocker without driving 9+ m across open ground into a separate
  building.
- `controls`, `seams`: lanes over rideable open ground, 60 m long, at least 8 m from any piece,
  whose authored heightfield stays at or below 30 degrees across a 2 m corridor (skipping canyon
  cliffs, spires and rock fins while keeping gentle ground, ramps and tile seams). A snag there is
  the ground itself, not a piece, and `seams` lists each place once.
- `snags`: every raw row.

## Bounds and exit codes

Only pieces standing over the stage's ground tiles count (`pieces_off_map` says how many did not,
e.g. the bay's barge far below the map). The arena counts the bowl's own ramps, kickers and masts as
pieces, shape by shape; its floor, rim and wall are ground.

Exit 0 done, 1 more than 20% of lanes skipped (the message names why, from `skipped_reasons`), 2 bad
arguments or an unreadable file.

## Moving pieces

A lift, barge or other moving piece is met at whatever point of its cycle the lane's ball arrives, so one
sweep pass neither clears nor convicts it. Judge a moving piece's row with a phase test that steps time to
fixed points of its cycle and rolls each lane at each, as `tests/park_hollow_lift_roll_test.gd` does for the
flume's hollow lift and `tests/park_service_lift_roll_test.gd` for the dam's (wave 36: swept alone it showed
0 snags; at fixed phases the plate landing on a ball that rolled under it while raised stops the ball dead,
cycle 2.5 to 3.4 s after firing). Since wave 37 a lift is a cap on a solid drum and both tests pass.

Sweep one piece alone with `--only=<path substring>`, e.g. `--map=park_flume --only=hollow_lift`. Until
wave 37 that skipped 3 of the drum lift's 8 lanes with `no_floor at Stage2` and exited 1: the lift rests in
a hollow, so those lanes start on a bank higher than the lift's top, and the drop ray started inside the
ground. A lane that meets no floor from over the piece now drops again from over the ground at its start
(0 skipped, exit 0). The two drum contacts it then reads are class `moving`.

## Pieces that are not ridden

A piece no taller than the ride height is ridden unless the whole ball passes under it. One held up at least
the ball's height (2 m) over the highest floor under its centre and corners gets no lanes: a lane rolls on the
floor, so it would pass under the piece and meet only what holds it up. A piece hung lower keeps its lanes,
because the ball can wedge under it. Until wave 37 the Slag Bowl's four crossbars, 19 m up their
masts, were ridden this way and gave all 16 of the bowl's piece-lane snags, each a ball rolled into a mast;
the flume's crew ledges, 6.5 m over the mesa rim, gave its 3 ride-lane ground snags. `snag_sweep_test`
plants a bar 10 m over its floor (no lanes) and one 1.8 m over it (its lanes).

## Limits

Calm world, one ball at cruise, headless. It finds speed loss against a contact that faces the line of
travel; it does not say a bot or a player will meet the place. `snag_sweep.gd` calls the private
`game.flow._finish_stage()` for the arena, as seven other tools and tests do.
