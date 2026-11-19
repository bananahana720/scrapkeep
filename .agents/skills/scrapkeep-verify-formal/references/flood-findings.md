# Findings of the flood model

Each finding is a break the model found that replayed on the real game. A closed finding names the change that closed it.

## PF-0. Full water was held when the ball rolled in (closed by pull request 1135)

**Steps.** A flood lands. It rises for its whole fill time with the ball away. The ball rolls into the basin on the next tick.

**What happened.** The rise is a sum of tick lengths. At 60, 90 and 120 ticks a second the sum after a whole fill time sat just under `fill_s`, so the director still counted the water as rising, and rising water waits while a grounded ball is in its basin. The `step` hook was not called, and it stayed uncalled for as long as the ball stayed.

**Harm.** The family's step is skipped for full water while the ball stays. On this tree that step sets depth, drawing and foam; once the hazards branch (pull request 1123) is stacked it also taxes a slow ball in deep water, and then water that looks full would do nothing to a ball that rolls in at that moment and stops.

**Model.** `flood-broken-nosnap` breaks `FullWaterNeverHeld`.

**Replay.** `replay/flood_under_ball.gd`, on stage commit bf8056479: `held 60 Hz: REPRODUCED`, `held 90 Hz: REPRODUCED`, `held 120 Hz: REPRODUCED`, `held 144 Hz: NOT REPRODUCED`. On pull request 1135 (c485ca53c): NOT REPRODUCED at all four rates.

## PF-1. A ball parked in a basin stops the flood from ever rising (closed by W1-148)

**Steps.** A flood lands with the ball away. The ball rolls into the basin before the water has risen and stays there.

**What happened.** Rising water waited under a grounded ball, with no limit. The flood's live time kept running meanwhile. When the ball at last rolled out after the live time was up, the flood ended on the next tick without ever having risen.

**Harm.** Stopping in the basin was the safe move: it cancelled the flood, and since pull request 1123 it also dodged the deep-water tax. AGENTS.md rule 9 says hardness presses a ball that slows or stops.

**Why the wait exists.** `git log -S` finds the check in `9b956f657`, the commit that scheduled park rows; its message gives no reason. The design page does: `sketches/core-loop/design-v3/PARK.md` rule 2, "Never stop the ball", says new geometry never appears under the ball and "rising water never rises under the ball" (the hold rule), so the water never changes under a grounded ball with no warning, such as on its landing frame.

**Closed by.** W1-148 keeps the wait and caps it: `PARK_FLOOD_HOLD_CAP_S` (2 s of a flood's live time). Time with a ball in the footprint counts toward the cap whether the ball is grounded or not, so hopping in place cannot hold a flood off. The cap is only in the step gate of `_park_step_live`; `_park_clear`, and so `_park_can_end`, still refuse to end a flood under a ball. The cap is an assumption Andrew can overturn.

**Model.** `flood-broken-nohold` (no cap) breaks `HoldEnds`; `flood-today-timed` holds it.

**Replay.** `replay/flood_under_ball.gd` printed `parked: REPRODUCED` on bf8056479 and c485ca53c; on the W1-148 director it prints NOT REPRODUCED.

## PF-2. Full water stops stepping once its live time is up and the ball is still near (open, found by review)

**Steps.** A flood with a live time rises fully. The ball sits in or near the basin until the live time runs out.

**What happens.** The first branch of `_park_step_live` returns without the step hook when the live time is up and the flood cannot end because the ball is not clear. The flood stays live and is no longer stepped for as long as the ball stays.

**Harm.** None a player can see on this tree. Once a step taxes a slow ball in deep water (pull request 1123), a ball that outstays the flood stops being taxed.

**Model.** Not seen: the model's live-time branch leaves `skipped` unchanged, and `FullWaterNeverHeld` is stated for the live time only. Found by reading the code in review, not by the checker and not replayed.

## PF-3. A ball near a flood but outside its footprint still holds the water off, without limit (open)

**Steps.** A flood lands. The ball sits outside its footprint but inside the row's clearance margin (`hold_clear_m`; the real flood rows use 12, 15 and 20 m) and stays.

**What happens.** `_park_clear` holds the rise while the ball is within the margin, and the cap does not count this wait. The live time keeps running. The ball is not in the water, so the deep-water tax cannot reach it.

**Harm.** Parking near a flood, not in it, still cancels it, for the whole live time. Left open on purpose in W1-148 (an assumption Andrew can overturn): capping it would raise the water toward a ball 12 to 20 m away, which the hold rule is there to prevent. The model does not see it: its ball is either in the basin or out.

**Measured (wave 44 audit, 19 Nov 2026, stage f42a22574, a headless fixture on the dam's plunge pool row that counted rise steps and read the rim route).** A ball parked 6 m outside the footprint, inside the margin, got zero rise steps through stage time 55 s, 48 s after the flood's start, and the rim route stayed open. A ball that left that point after 12 s let the rise step again, and the flood ended at 42 s. With the ball clear the flood rose and ended. A ball that entered the basin after the start was capped as W1-148 intends: the first rise step came 2.1 s after the start. So the margin can take the whole fill today. A fix has to keep a safe landing beside the water and still stop the margin holding the water off for the flood's whole live time (BACKLOG row W1-162).
