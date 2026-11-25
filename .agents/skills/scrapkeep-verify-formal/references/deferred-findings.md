# Findings of the deferred effects model

Each finding is a break of `models/DeferredEffects.tla` that replayed on the real game. [deferred-coverage.md](deferred-coverage.md) names the code behind each step. A closed finding names the change that closed it.

## Open

None. `deferred-today` (the code at `465769205`, including `_deferred_procs`, `_draining_procs`, `DamageDoor.in_pass()`, and `_det_cord_queue`) holds `ProcDepthOne`, `NoEchoAcrossAttempt` and `ShotBitsCap` in 9,955,877 distinct states (TLC 2.19, tla2tools 1.7.4, 12 workers, Mac Studio, 25 November 2026; up from 2,196,005 at `e362998b2`), every one of its twenty-four `deferred-broken-*` plants breaks the rule it names, and its `deferred-reach-*` probes break.

## Closed before the model

The model was written after P7 (a12e9adf3), so the leaks P7 fixed never broke a code config. Its plants put each one back, and each breaks:

- `deferred-broken-keepcast`: `_start_attempt` without `_cast_pending = {}` and `_bite_pending = false` lets a cast or bite begun in one attempt land in the next (`NoEchoAcrossAttempt`).
- `deferred-broken-keepguards`: `_start_attempt` without `_guards.clear()` carries a guard link into the next attempt (`NoEchoAcrossAttempt`).
- `deferred-broken-contactmark`: `_door_caps` erasing an expired row without `_drop_exposed` leaves the exposure mark standing on a live enemy with no row (`ShotBitsCap`).
- `deferred-broken-deathmark`: the died handler erasing the rows without `_drop_exposed` leaves the mark on the body until it is freed (`ShotBitsCap`).

## No candidate

A death does not clear the echo, the pike count, the guards, heat, the exposure rows or the bolts (`_on_player_died` clears the line load, the cast and bite, the strips and bells, the aftershocks and the rakes). They cannot fire: combat's tick returns outside play, and every way back into play passes `_start_attempt` (`deferred-reach-KeptOverDeath` shows them held over a death; `deferred-broken-ungated` shows the gate is what holds them). Backwash's `_on_wake_dash` has no `in_play` check of its own; the model takes the ball's input as frozen outside play and does not check it.
