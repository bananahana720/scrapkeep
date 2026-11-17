# Spillway crews at rider height

The scraper now banks its visual pivot onto the ground. Its planted claw sank **0.25 m** into the 18° test slope before this change. The largest sink and float are now **0.06 m** each. The opt-in flanker now uses an ordinary lunge against a stationary target. Keep the stock World 1 crew, ranged placement, home seats and yard rows.

The comparisons use the flume approach from the siphon toward the entry kicker at XZ (40, 255), then the wasteway or upper reach. The lane experiments use the same class, seed 1, 90 physics ticks per second and the same member bearings for each stock/flank pair. The illustrations in the handoff describe the intended read. The images here are Godot 4.7.2 captures from the running park. Audio is muted. Headless clocks below refer to physics ticks. Drawn runs render separately and can differ by several ticks.

## The scraper’s working end

The claws form the contact plane. The wedge draws back and the fin opens on windup, then the head slides down the committed lane. The baked walk and the collision body keep their existing timings. The parked singleton reached the sampled chase, late windup, lunge and recovery poses on ticks 0, 70, 85 and 117 both before and after the banking change. On flat ground the candidate’s maximum sink/float was 0.06/0.05 m. The test measures transformed mesh vertices at both roll directions. The frozen pilot prevents incidental rams during that measurement.

- Each chase panel retains its original 1280 × 720 frame. The second strip compares the old and grounded scraper across windup, lunge and recovery. [Rider sequence](chaser-rider.jpg) · [Before and after](bank-before-after.jpg)
- Front, side and rear use the same orthographic scale on the live windup and lunge. The next strip compares High with Low plus reduced motion and reduced flashes. [Working end](chaser-angles.jpg) · [Quality and comfort](comfort.jpg)
- The call, windup, strike and recovery show two chasers in the moving rider’s frame. The last two images show a grown ram cancelling the scraper and the view down its exit. At the flume runout pier, one of five shoulder-width sight rays hit the actual pier and four cleared it for each machine. [Pair and grown ram](pair-and-ram.jpg) · [Chaser and lobber behind the pier](pier.jpg)

## Which moving encounters earned their placement?

All four moving approaches began with the machines projected inside the rider’s view. The trial distinguishes this projection from the terrain-ray occlusion measurement below. Start and grown ram use 28 m/s, cruise uses 14 m/s, and the turning pilot changes direction on the first committed windup. Each arm gets one run per approach, including a stationary control. The lane and first-contact descriptors are in the trace.

| Arm | Cruising rider | 28 m/s turn after commitment | Stationary pilot, seven seconds |
| --- | --- | --- | --- |
| Stock chaser pair | First windup at tick 76, 10.6 m forward. Lost 0 HP. | First windup at 48. Lost 0 HP. | Lost 72 HP. |
| Flanker C | Call at 11, windup at 56, 18.1 m forward. Lost 5.7 HP on a committed hit. | Call at 0, windup at 45, strike at 100. Lost 0 HP and finished at 13.8 m/s. | Previously lost 36 HP. The corrected experimental branch landed both hits and matched the stock 72. |
| Oblique lobber | Windup at 174, 1.8 m ahead. By shell release at 291 the lobber was behind the camera. | Windup was 21.4 m behind the rider. All three 28 m/s approaches had passed before commitment. | Lost 12 HP. |
| Boom tender on the same unprimed approach | The 14 m/s rider saw the windup but popped zero floats. | Zero warnings in three 28 m/s passes. | Pinned and lost 5 HP. |

The flanker offered a visible response on all four moving approaches. Neither chaser arm committed behind the rider on those four approaches. A light and a grown ram cancelled the stock chaser during windup. Flanker C stays an experiment. Its straight-line decision arrived 65 ticks, about 0.72 s, before stock’s first warning, and the comparison covers one encounter seed. The lobber and unprimed tender placements miss the fast lane. [Overhead trajectories](trajectories.svg)

A second experiment staged the tender’s ordinary warning first, then released the ball down its committed sweep. Both light and grown 28 m/s riders popped all five floats for a strike and five one-scrap drops. Both were still at 27.47 m/s at the fifth pop. After 100 ticks the grown pilot was at 26.10 m/s and the light pilot at 18.38 m/s. The 7 m/s pilot was pinned, with zero pops. The outside line stayed clear with zero pops, zero pins and a 23.65 m/s exit. The roster test separately crosses spent floats again and checks the one-strike payout. This demonstrates a playable timed crossing. The ordinary arrival on this approach did not produce it. [Warning, contact and runout](boom-crossing.jpg)

## Who arrives beside the flume?

The director trial preserves the RNG sequence, isolates the home adjustment while seating the two members, and traces free-line, free-ahead and flank fallbacks separately. Seeds 1, 1, 17 and 31 each drew 20 crews per heading. The repeated seed is a replay check, so there are only three distinct seeds. The upstream control drew 41 free-line, 33 flank and 6 free-ahead anchors. Of its 141 members, 80 were visible and clear. Pulling free-line candidates towards a 22° bearing made no gain on that control. No sampled member in either arm entered a protected corridor (461 positions per arm). The normal director-home tests separately cover closed worksites, rider fallback, rejected seats and pack completion.

The terrain ray from a moving pilot confirmed that the entry-kicker collider hid the stock wasteway centre at (85, 335) for the first 1.2 s. The west seat at (75.47, 342.29) stayed in the same authored footprint and was visible on all 56 samples, versus 44/56 at centre. At the fixed kicker lens, the upper route revealed 160/160 west-seated members versus 0/160 stock. The lower route revealed 80/160 versus 0/160. Sixty identical seed-one draw records replayed exactly per arm, including coordinates and ray hits. The staged landing and first-attack views use the same seed and crew. [Stock above, west below](home-arrival.jpg)

| Driver, seed 1 | Stock after 50 seconds | West after 50 seconds |
| --- | --- | --- |
| Novice, attempt 1 | 56.7 HP, 12 kills | 67.4 HP, 15 kills |
| Learner, attempt 5 | 132 HP, 26 kills | 132 HP, 30 kills |
| Expert, attempt 1 | 132 HP, 26 kills | 132 HP, 21 kills |

Both stage-two arms started at the kicker with the same two-member crew in the reinforcement queue and ran the project’s real band driver for 4,500 ticks. The natural-entry control used the ordinary stage entrance instead. All six natural-entry pilots missed this home's seats during the window and finished at 115 HP with zero kills. The targeted sample exposed an easier novice outcome, and the bands disagreed on kills. Retain the stock home. These are bounded first-pass stage windows. A whole-stage win rate and human recognition remain unmeasured.

## Who attacks first in the dam yard?

The approach sentry was a lobber at (−20, 22.66, 375) in both orders. The production lock landed all wave members on its rotating 15.6 m arc under pack 900001. Moving the odd job into the centre changes which tools overlap. It never adds a member or another attack slot. Both arrangements leave the jolt layer and hinged plate as the first tool to commit in their late waves.

| Dam wave | Stock, in bearing order | Centre alternative | First windup / first contact, stock then alternative | Five-second stationary survivors |
| --- | --- | --- | --- | --- |
| 1 | chaser, chaser, lobber | chaser, lobber, chaser | 182 / 259 in both. Stock’s second chaser hit at 318. In the alternative both hit at 259. | 3/3 in both |
| 4 | lobber, chaser, chaser, jolt layer | lobber, jolt layer, chaser, chaser | Jolt layer 135 / strike 226 in both. | 4/4 in both |
| 5 | chaser, chaser, lobber, lobber, ramp flipper | chaser, chaser, ramp flipper, lobber, lobber | Flipper 135 / strike 226 in both. | 5/5 in both |

On the frozen pilot the alternative opening cost 72 HP versus 54 HP stock. Stock gives the second scraper a separate answer. At 25 m/s the moving small pilot, grown pilot and pilot steering after a tell each removed one crew member from every sampled wave in five seconds. None took damage, and none cleared the whole wave in that window. Exit speeds ranged from 10.3 to 14.7 m/s. The table reports windup and visible tool strike separately where the tool missed the rider. [Sentry and waves 1, 4 and 5](yard-order.jpg) · [Drop bearings](yard-bearings.svg) · [Live warning, landing and release](yard-warning.jpg)

The independent lock regression drives the whole dam sequence by killing the actual crew. It logged 19 yard kills, zero individual panel drops, one panel for the clear, and the start pick. Its separate timeout opens the yard, releases surviving crew, restores their ordinary loot rolls and pays zero yard panels. The ordinary gate, pack-budget and overtime tests exercise the clamp, distinct-threat warning gap, overtime loot, retry cleanup and spacing. [All 224 stage-lock assertions](yard-clear-timeout.txt)

## Replay

Use the project’s scratch-home and import procedure. Start Godot with the indicated sketch as its project. Run each named trial with a fresh absolute output directory. Add `--pictures` to a drawn run for chase frames, `--comfort --preset=low` for the comfort comparison and `--case=turn` for the single flanker turn. The trace contains first-view ticks, warning geometry, damage, rider and body trajectories, actual ray hits, wave survivors and driver outcomes. [Compressed JSON trace](trial-data.json.gz)

```sh
godot --headless --path sketches/core-loop --fixed-fps 180 --audio-driver Dummy \
  --script res://tools/spillway_crew_trial.gd -- --trial=flank --out="$TRIAL_OUT" \
  --models=tripo --profile=sitting --table=park --ball-look=cutaway
godot --headless --path sketches/core-loop --fixed-fps 180 --audio-driver Dummy \
  --script res://tools/spillway_home_band_trial.gd -- --from-stage=2 --table=park \
  --policy=skipper --seeds=1 --band=novice --attempt=1 --home-seat=west \
  --sample-site=kicker --sample-ticks=4500 --out="$BAND_OUT"
```

The first fixture accepts `stock`, `flank`, `lobber`, `boom`, `crossing`, `yard`, `yard-drive`, `arrivals`, `home`, `cover` and `motion`. For the band comparison switch between `--home-seat=stock` and `west`. Omit `--sample-site=kicker` for the natural-entry control. The named checks include the matching chaser-windup, enemy-clips, ground-contact, attack-budget, director, sound, roster and lock suites. The crew-lamp batch found an extra transient field. Its clean, isolated run passed all 80 checks. The test-only directors re-use the stage’s actual routing and worksite logic. [Scoped check results](checks.txt) These probes establish geometry, timing and automated outcomes on Godot, with no physical display, Linux hardware or human-feel claim.
