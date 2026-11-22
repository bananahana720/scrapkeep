# What HazardCycle.tla stands for

`models/HazardCycle.tla` checks a storm's sought strike in the Spillway and the enemies it strikes. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files: `sketches/core-loop/src/world/events/storm_seek.gd` (the seek), `sketches/core-loop/src/world/events/natural.gd` (the storm that steps it), `sketches/core-loop/src/world/events/hazard_hits.gd` (the enemy strike) and `sketches/core-loop/src/combat/silt_boil.gd` (the stall test).

## Steps

| Model step                                              | Code                                                                                                                                                                                              |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `World` (the ball, an enemy, the ball's speed, a storm) | The storm's `_physics_process` feeds `StormSeek.observe` every tick; the event director steps a live lightning row (`_hazard`, then `_seek`)                                                      |
| `mode = "stalled"`                                      | `StormSeek.sought()`: below cruise (`SpeedTier`) for `SLOW_S`, and `SiltBoil.stalled()` on the last ten seconds                                                                                   |
| `CanBegin`                                              | `StormSeek.step`: no tell begins when `left_s < TELL_S + LIVE_S`                                                                                                                                  |
| `Begin`                                                 | `StormSeek.step`: one `Hazard` committed on the ball's spot (`commit_annulus`); `_seek` sends the `lightning_mark` cue                                                                            |
| `Fill`                                                  | `Hazard.step` while `state == WARN` (`TELL_S` 1.2 s, never under the hazard's 1.0 s floor)                                                                                                        |
| `Strike`                                                | `StormSeek.step` on the tick the warning ends: `hit` runs once; `_seek` tests the ball with `hazard.contains` and strikes enemies through `HazardHits.strike` with the same `contains`            |
| `Cleared`                                               | `StormSeek.clear()`, called from the storm's `_end` for a lightning row and from `release`; `StormSeek.stand_down()` drops a tell the same way when the ball enters a place a storm does not seek |
| `Cool`, `Rested`                                        | `StormSeek` `REST_S`, counted down in `observe`                                                                                                                                                   |

## Ticks and seconds

One model tick is 0.3 s: `TellTicks` 4 is the 1.2 s tell and `MinTell` 2 the 0.6 s fairness floor. `RestTicks` 3 and `StormTicks` 10 are shorter than the code's 5 s rest and 20 s storm; they set how large the bound in `StalledSought` is, not the order of steps. The seconds are read by `sketches/core-loop/tests/hazards_hit_everyone_test.gd`.

## Configs

| Config                       | Stands for                                                  | Must report                                             |
| ---------------------------- | ----------------------------------------------------------- | ------------------------------------------------------- |
| `hazard-today`               | every guard in place                                        | no break, in at least the pinned 45,981 distinct states |
| `hazard-broken-notell`       | the strike lands on the first tick                          | `TellBeforeStrike` breaks                               |
| `hazard-broken-seekrolling`  | any ball is sought                                          | `RollingNeverSought` breaks                             |
| `hazard-broken-strikeatball` | the strike re-aims at the ball                              | `TellBeforeStrike` breaks                               |
| `hazard-broken-skipenemies`  | the strike passes over enemies                              | `EnemyStruck` breaks                                    |
| `hazard-broken-noseek`       | no storm seeks                                              | `StalledSought` breaks                                  |
| `hazard-broken-hitanywhere`  | the strike hits the ball without the `hazard.contains` test | `BallOnlyWhereTold` breaks                              |

## Not modelled

The dome's own fixed strike circle, floods, the boiler's steam cone and the reactor's fallout ring (each strikes enemies through the same `HazardHits.strike` call; the test and `park_events_industrial_test` cover them), the places a storm does not seek (the reward gates, the launch, an engaged Warden's ring and the calm bay: `SiltBoil.exempt` and `bay.inside`, read in `sketches/core-loop/src/world/events/natural.gd` `_seek_exempt` and pinned by the test), more than one enemy, the enemy's death and drop, and anything drawn or heard.

Sync commit: e362998b2 (branch stage/alpha-w45, 21 November 2026, FV-3: no covered file changed since 1c94e96b5 (git diff 1c94e96b5 e362998b2 over the four files is empty). Before it, 1c94e96b5: of the covered files only natural.gd changed since 751d35bf6, joining the `world_telegraphs` group, keeping a row's kind on its state at the telegraph, and adding the read-only `telegraphs(ball)` the bot's fairness record reads, with no change to the seek, tell, strike or cool steps; 751d35bf6, a comment in hazard_hits.gd only; 5935c2ce8, the seek standing down where the silt does not boil and in the calm bay, outside the modelled steps; 158d11f47, f2aab5a7b and fcc359e25)
