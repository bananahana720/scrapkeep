# What ParkFlood.tla stands for

`models/ParkFlood.tla` checks a park ground event that fills with water (a `flood_fill` or `flash_flood` row) from its announcement to its end, with the ball free to roll into or out of any basin between any two ticks. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered file: `sketches/core-loop/src/world/event_director.gd`.

## Steps

| Model step | Code |
| --- | --- |
| `Announce` | `_advance_park`: a `WAITING` or `COOLDOWN` row is picked and becomes `ANNOUNCED` |
| `Land` | `_advance_park`: an `ANNOUNCED` row whose time has come lands when `_park_capacity`, `_park_clear` and `_park_route_safe` all hold; `live_elapsed_s`, `rise_s` and `collapse_s` reset |
| `Step` | `_park_step_live`, one call |
| `Step`, the live time is up | the first branch of `_park_step_live`: end when `_park_can_end`, else return |
| `Step`, `waits` | the early return while the water is rising and `_park_clear` is false: the family's `step` hook is not called and the rise does not advance |
| `Rose` | `rise_s` advances through `_park_clock` and stops at `fill_s` |
| `hair` | `rise_s` after a whole fill time of ticks, when the float sum sits under `fill_s` |
| `End` | `_park_end`: the row goes to `COOLDOWN` (every real flood row has `once` false) |
| `Roll` | the ball's position, which `advance` is handed each tick |
| `Clear(e)` | `_park_clear` for a ground row: false while the ball is in the row's footprint |
| `Settled(e)` | `_park_capacity`: a live row with `live_s` 0 whose rise has reached `fill_s` no longer counts against the ground cap |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `SnapRise` | `_park_clock` sets a clock to its target once the sum is within `PARK_CLOCK_SLACK_S` (pull request 1135) | `flood-broken-nosnap`, `flood-broken-nosnap-slot` | `FullWaterNeverHeld`, `FullWaterFreesItsSlot` |
| `WaitUnderBall` | the early return in `_park_step_live` while rising water's basin holds a grounded ball | `flood-broken-nowait` | `NeverRisesUnderBall` |
| `EndNeedsClear` | `_park_can_end` | `flood-broken-endunder` | `NeverEndsUnderBall` |
| `CapGuard` | `_park_capacity` against `PARK_GROUND_CAP` | `flood-broken-nocap` | `WithinCap` |

## Ticks and seconds

One model tick is one call of `advance`. `Fill` 2 and `Live` 3 are far shorter than the real rows' 4 to 10 s rise and 30 to 40 s live time; they keep the order of steps and shrink the count. Three rows against a cap of 2 is the smallest park where the cap can refuse a landing. `MaxLives` 2 lets a row land, end and land again. The seconds are read by `sketches/core-loop/tests/park_events_test.gd`.

## Configs

Run `bash models/make-flood-configs.sh`, then plain TLC on each `flood-*.cfg` with `ParkFlood.tla`.

| Config | Stands for | Must report |
| --- | --- | --- |
| `flood-today-timed` | the code, with a live time as every real flood row has | no break, in at least the pinned 74,228 distinct states |
| `flood-today-noclock` | the code, for a flood with `live_s` 0 (the shape some test rows use) | no break, in at least the pinned 468 distinct states |
| `flood-broken-*` | one guard off, as the Guards table lists | the named rule breaks |
| `flood-parked` | the question "does rising water always finish rising?", asked without the ball leaving | `RiseFinishes` breaks: finding PF-1 in [flood-findings.md](flood-findings.md) |
| `flood-reach-timed-*`, `flood-reach-noclock-*` | one probe each that says "never" about a thing that must happen | the probe breaks; one that holds means an action can no longer fire |

`FloodEnds` and `AnnouncedLands` are checked under the condition that the ball in the end stays out of every basin. They say nothing about a ball that never leaves; `flood-parked` asks that.

## Replay

`replay/flood_under_ball.gd` makes the steps of `flood-broken-nosnap` and `flood-parked` on the real director through `advance` and the family hook. Run it with `"$GODOT_BIN" --headless --path sketches/core-loop --script .agents/skills/scrapkeep-verify-formal/replay/flood_under_ball.gd`, with `HOME` set to a scratch folder on the Mac. On the commit before pull request 1135 its `held` lines print REPRODUCED at 60, 90 and 120 ticks a second; from pull request 1135 on they print NOT REPRODUCED.

## Not modelled

Weather rows, collapses and cave-ins (a collapse's clock goes through the same `_park_clock` as the rise and `park_events_test.gd` sweeps it, but the model has no collapse), the drain, the quiet window after a Warden phase breaks, the bar the landing waits for, the route check (`_park_route_safe` is taken as true), the travel margin around a footprint (`hold_clear_m` and the ball's speed), a row with `once` true, the stage ending under a live flood (`end_all`), what the `step` hook does with the water, and anything drawn or heard.

Sync commit: d8ef62133 (branch codex/w44-basin-boundary, pull request 1135, 17 November 2026, the model's first cut)
