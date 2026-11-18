# Findings of the flood model

Each finding is a break the model found that replayed on the real game. A closed finding names the change that closed it.

## PF-0. Full water was held when the ball rolled in (closed by pull request 1135)

**Steps.** A flood lands. It rises for its whole fill time with the ball away. The ball rolls into the basin on the next tick.

**What happened.** The rise is a sum of tick lengths. At 60, 90 and 120 ticks a second the sum after a whole fill time sat just under `fill_s`, so the director still counted the water as rising, and rising water waits while a grounded ball is in its basin. The `step` hook was not called, and it stayed uncalled for as long as the ball stayed.

**Harm.** The family's step is skipped for full water while the ball stays. On this tree that step sets depth, drawing and foam; once the hazards branch (pull request 1123) is stacked it also taxes a slow ball in deep water, and then water that looks full would do nothing to a ball that rolls in at that moment and stops.

**Model.** `flood-broken-nosnap` breaks `FullWaterNeverHeld`.

**Replay.** `replay/flood_under_ball.gd`, on stage commit bf8056479: `held 60 Hz: REPRODUCED`, `held 90 Hz: REPRODUCED`, `held 120 Hz: REPRODUCED`, `held 144 Hz: NOT REPRODUCED`. On pull request 1135 (c485ca53c): NOT REPRODUCED at all four rates.

## PF-1. A ball parked in a basin stops the flood from ever rising (open, a design question)

**Steps.** A flood lands with the ball away. The ball rolls into the basin, or within the row's clearance around it (`hold_clear_m`, 12 to 15 m), before the water has risen and stays there.

**What happens.** Rising water waits under a grounded ball, with no limit. The flood's live time keeps running meanwhile. When the ball at last rolls out after the live time is up, the flood ends on the next tick without ever having risen.

**Harm.** Stopping in the basin is the safe move: it cancels the flood. AGENTS.md rule 9 says hardness presses a ball that slows or stops. Here a stopped ball is the one thing the water will not touch. The wait is deliberate (it keeps water from rising onto a rider with no warning, and `sketches/core-loop/tests/park_events_test.gd` checks it), so this is a question for Andrew, not a slip: should rising water wait under a ball only for a bounded time, or only for a ball that is moving?

**Model.** `flood-parked` breaks `RiseFinishes`.

**Replay.** `replay/flood_under_ball.gd`, on bf8056479 and on c485ca53c alike: `parked: REPRODUCED (50 s with the ball in the basin, live time 20 s: step hook calls 0, water rose false, flood ended false)`, then `after the ball leaves for 5 s: step hook calls 0, flood ended true`.

**Not changed here.** Pull request 1135 fixes PF-0 only. This finding predates it.

## PF-2. Full water stops stepping once its live time is up and the ball is still near (open, found by review)

**Steps.** A flood with a live time rises fully. The ball sits in or near the basin until the live time runs out.

**What happens.** The first branch of `_park_step_live` returns without the step hook when the live time is up and the flood cannot end because the ball is not clear. The flood stays live and is no longer stepped for as long as the ball stays.

**Harm.** None a player can see on this tree. Once a step taxes a slow ball in deep water (pull request 1123), a ball that outstays the flood stops being taxed.

**Model.** Not seen: the model's live-time branch leaves `held` unchanged, and `FullWaterNeverHeld` is stated for the live time only. Found by reading the code in review, not by the checker and not replayed.

