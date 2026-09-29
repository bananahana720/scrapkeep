# C13 Bola thrower: throw-state evidence (captures only)

Base is integration pin int-pin2 (d70ef7a, old C13 loop), head is branch claude/asset-c13b (a4a0e95 plus this evidence commit; no change under src, assets or tools). Cameras asset-front30, asset-side30, asset-rear30; modes lit and subject-black; 1920x1080, seed 280928. Frames live under `capture-throw/<state>/{head,base}/{lit,subject-black}/` (PNGs stay local, gitignored), pairs under `capture-throw/<state>/pair/`, the `--call` chain of each run in its `frames.json` ("call"), and the state read back per call in `capture-throw/<state>/readback-{head,base}.txt`. Tools: `throw-tools/`.

## How a state is staged (no code change)

The thrower never enters WARN under the capture's calm setup: the ball starts 126 to 144 m away and `attack_range` is 30. Every run replays the same chain through the capture tool's `--call` (Node `set` and `set_indexed`, JSON arguments):

1. `attack_range` 0 and `walk_speed` 0 on `/root/Game/Spawn_bola_thrower`; the thrower is put at (80, 30.85065, -100) with `set_indexed global_position:x/y/z` and left to land (90 physics frames).
2. `/root/Game/Player/RigidBall`: `set_indexed` global_position to (80, 31.2, -92) and zero linear velocity, 90 frames to settle, then `freeze` true. The ball ends near (79.9, 31.24, -89.9) moving 1.7 m/s toward +z.
3. `attack_range` 30 (1 frame): the thrower's own `_warn` runs (`phase` 1, `_t` 0, telegraph committed by `_commit`, with its launch point and flight trace). Then `_t` is set to sample minus one physics step (1/90 s) and one frame runs, so the sampled `_t` is exact after that step. Release states first set `_t` 0.5 (one frame; the thrower's own `_go_live` runs) then the flight `_t`.
4. The capture tool freezes the tree, and its `--freeze` puts the thrower at (80, 30.85065, -100) with rotation 0. This differs from the earlier resting captures (y 29.74855, the ground under the thrower, 1.1 m lower than where the capsule rests); the camera centre moves with it (y 32.35065). It does not change the crew or loop.

State holds: at both trees the readback after every call shows phase and `_t` as below (the same probe replays the tool's `parse_call` and `callv` headless; the native lit frames match: loop away from the crew at release, back on the crew at recovery). Base holds identically (same phase, `_t`, flight positions); its loop is the old flat hoop.

## State samples (head readback; base phase, `_t` and loop position identical)

`_t` is seconds; `warn_seconds` 0.5, `FLIGHT` 1.3 (physics 90 Hz). Exposure is |ring axis . unit line of sight| from the loop to each camera (front30 / side30 / rear30; 1.0 is face-on). Opening is background pixels enclosed by the subject in subject-black (hole.py's method), base / head, at front30, side30, rear30.

| state | phase | `_t` | flying | held | loop position | exposure f/s/r | opening front30 | opening side30 | opening rear30 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| wind25 | 1 | 0.125 | false | false | (80.0, 33.05065, -100.0) | 0.612 / 0.585 / 0.641 | 11 / 369 | 0 / 388 | 11 / 391 |
| wind60 | 1 | 0.3 | false | false | (80.0, 33.05065, -100.0) | 0.612 / 0.585 / 0.641 | 11 / 370 | 0 / 391 | 11 / 390 |
| wind95 | 1 | 0.475 | false | false | (80.0, 33.05065, -100.0) | 0.612 / 0.585 / 0.641 | 11 / 368 | 0 / 389 | 11 / 393 |
| rel30 | 2 | 0.39 | true | false | (79.81661, 37.14035, -96.0291) | 0.672 / 0.425 / 0.559 | 11 / 442 | 0 / 236 | 11 / 566 |
| rel70 | 2 | 0.91 | true | false | (79.57209, 35.90835, -90.73456) | 0.647 / 0.329 / 0.583 | 11 / 316 | 0 / 125 | 11 / 941 |
| rel95 | 2 | 1.235 | true | false | (79.41927, 31.56823, -87.42548) | 0.590 / 0.326 / 0.709 | 11 / 163 | 0 / 128 | 11 / 1573 |
| land | 2 | 1.35 | false | true | (80.0, 33.05065, -100.0) | 0.612 / 0.585 / 0.641 | 11 / 372 | 0 / 384 | 11 / 393 |
States: wind25, wind60, wind95 are 25, 60 and 95 percent of `warn_seconds` (`_t` 0.125, 0.3, 0.475); rel30, rel70, rel95 are flight 0.30, 0.70 and 0.95 (`_t` 0.39, 0.91, 1.235, loop `top_level`); land is `_t` 1.35, 0.05 s after landing: the loop is back on the crew at its seat, the landing ring held the ball (`held` true, the wrap).

## Most edge-on sample

The asset test's own measure (world axis component, |x| for side30, |z| for front30 and rear30) is constant at 0.571 to 0.627 in every state, because the whirl is about the ring axis and the seat does not change; its floor is 0.45. By line of sight the loop is most edge-on at side30 in flight: 0.325 at rel95 and 0.329 at rel70 (openings 128 and 125 px, against 236 at rel30). The minimum falls between rel70 and rel95, so rel95 was added as the closest sampled pose; the lowest sampled opening is side30 at rel70 (125 px) and the lowest exposure is side30 at rel95. Front30 opening is smallest at rel95 (163 px). Rest-pose openings for reference are in JUDGE.md (356, 391, 378).

## Checks

- Zero errors: every capture exit 0; each pair manifest lists no errors or notes in either mode. The only engine lines are the two "BUG, indexing did not unpair geometries from light" lines that the earlier resting captures also print.
- Subject-black frames hold exactly two values (0 and 127) in all 42 head and base frames.
- Base opening: 11, 0, 11 px at every state (flat hoop, as at rest); head 125 to 1573 px, never below the 250 px minimum except side30 during flight rel70 and rel95 (125, 128 px) at the oblique line of sight, which is the edge-on read to judge.
- `enemy_bola_thrower_asset_test` passes (`throw-evidence-asset-test.log`).
