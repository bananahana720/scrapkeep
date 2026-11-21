# What YardLock.tla stands for

`models/YardLock.tla` checks the Spillway's yard lock (the ring wall that shuts round the ball near the beacon and lands its crew in waves) and the overtime bell a won yard offers, under every interruption the run flow allows: a Warden that wakes (by the ring or a strike), breaks or vanishes, a death, a retry, a new run, a quit and a Continue, and the next stage's entry. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/world/stage_locks.gd`: the lock's states, `_step_lock`, `_lock`, `_unlock`, `_on_flow_changed`, `_on_stage_entered` and `_clear`, and the `warden_engaged` handler that sets `_engaged_s`.
- `sketches/core-loop/src/world/lock_rows.gd`: the dam's and the flume's lock rows (`within_m`, `radius_m`, `ahead_m`, `max_s`, `waves`, `overtime`).
- `sketches/core-loop/src/world/overtime.gd`: `offer`, `ring`, `cash`, `clear`, `_step_touches`.
- `sketches/core-loop/src/core/flow.gd`: `physics_step` (the ring entry and `_engage`), `show_start_card`, `start_pick_waits`, `enter_stage`, `retry_stage`, `_begin_run`, `resume_run`, `show_title`, `_on_player_died`, `_end_run`, `_unseal`, `_warden_vanished`, `_on_reward_chosen`, `_on_launched`, `_finish_stage`, `_set_state`.
- `sketches/core-loop/src/core/beacon.gd`: `in_ring` (flat distance) and `advance`, which marks the ring entered.
- `sketches/core-loop/src/game.gd`: the tree order behind the frame (the ball is added before the world module, whose `setup` adds StageLocks to the game root; `_physics_process` calls `flow.physics_step`).
- `sketches/core-loop/src/world/world.gd`: `locks = StageLocks.new()` and `ctx.root.add_child(locks)`.
- `sketches/core-loop/src/movement/player_ball.gd`: the ball's own physics tick, `reset_to`, and `state.grounded`.
- `sketches/core-loop/src/combat/combat.gd`: every hit emits `enemy_struck`, which wakes a sealed Warden.
- `sketches/core-loop/src/combat/actives/scrap_rockets.gd`: `LOCK_REACH` 42 m, the longest reach a player's strike has.

## Steps

| Model step | Code |
| --- | --- |
| `FlowTick` | game.gd `_physics_process` -> flow.gd `physics_step`: for STAGE and BEACON, `beacon.advance(delta, ball, sealed)` marks the ring entered for a ball inside it by flat distance (`in_ring`), and a sealed stage then calls `_engage`, which emits `warden_engaged`; StageLocks' handler (`setup`) sets `_engaged_s` from -1 to 0 |
| `BallTick` | the ball's own `_physics_process`. The game root runs first, then its children in tree order: the ball (added at `_ready`) before StageLocks (added by the world module's `setup`), so in one frame flow reads the ball where it was and StageLocks reads it where it is now |
| `LocksTick` | StageLocks `_physics_process`: returns unless `ctx.flow.in_stage()` and the stage has a row, then `_step_lock`. "armed": `_engaged_s >= 0.0 or not ctx.flow.sealed` spends the lock and calls `show_start_card` (stage_locks.gd:369); otherwise a grounded ball for which `lock_arms` holds (inside `within_m` on level ground, or on any ground inside `LOCK_ANY_SLOPE_SHARE` of it) shuts the yard (`_lock`). "locked": `lock_left -= delta`, `_hold_ball`, then `lock_left <= 0` -> `_unlock(false)`, elif the crew is down and no wave is whistling -> `_unlock(true)` on the last wave or the next wave's whistle, elif the whistle runs out -> the next wave lands. Nothing in "locked" reads `_engaged_s` |
| `Unlock(w, extra)` | `_unlock(won)`: `lock_state = "spent"`, `lock_won`, survivors lose `yard_crew`, `arena_unlocked`, `_drop_wall`, on a win `build.yard_cleared` and `overtime.offer`, a clamp pip, then `show_start_card` (stage_locks.gd:521). `extra` is only the `broken-elif` plant |
| `Spend` | `_on_flow_changed` for `gates`, `launch`, `summary`, `title`, `victory`: a shut yard is spent and its wall dropped, the collar dropped, `overtime.clear()`. `dead`, `boss` and `lap` are not in the list. No `show_start_card` |
| `Enter(s)` | `stage_entered`, emitted by `enter_stage` (from `_begin_run`, `resume_run`, `_advance_from`) and `retry_stage`: `_on_stage_entered` -> `_clear` (wall, collar, overtime) and the map's row arms the lock; flow's `_place_beacon` seals the stage and clears `_engaged` |
| `KillCrew` | the shut yard's crew dies (`crew_alive()` empty). `ctx.can_spawn()` refusing a wave is the `crewDown` choice in `_lock` and `WaveLands` |
| `StrikeWarden` | combat.gd emits `enemy_struck` for every hit; flow.gd `_on_enemy_struck` calls `_engage` for a hit on the sealed Warden, wherever the ball is. The longest strike is a scrap_rockets lock (`LOCK_REACH` 42 m; the glass lance reaches 40), so the model lets it land from the near and ring zones |
| `KillWarden` | `_on_enemy_killed` -> `_unseal` -> `_set_state(GATES)`. The clamp (`locked()`, `max_s`) is not modelled; the model lets the Warden break once it is awake and the ball is in its ring |
| `WardenVanished` | `physics_step`'s `_warden_vanished` -> `_unseal`: the gates open with no engagement |
| `Launch`, `Land` | `_on_reward_chosen` / `_on_launched` -> LAUNCH; the flight's end -> `_finish_stage` -> the next stage's `enter_stage`, or the summary after the run's last stage |
| `Death` | `_on_player_died`: with a store `_end_run(false)` -> SUMMARY; without one `_set_state(DEAD)` |
| `Retry`, `NewRun`, `Quit`, `Continue`, `Start` | `retry_stage` (storeless flows: a held R, the dead screen's key); `new_run` from the dead screen, the summary, or in play (the pause menu's restart, and a held R with a store: game.gd `step_restart_hold`); `show_title` or a quit to the desktop and back; `resume_run`, which enters the saved entrance again or, from a save written at the launch, lands the flight in the next stage (`_finish_stage`); the title's `press_start` and `choose_class` |
| `Ring`, `Cash` | overtime.gd `_step_touches`: a ram at the bell calls `ring()` (refused at `MAX_RINGS`), at the pot `cash()` (refused with no ring; `state = "spent"`) |

The ball's place is one of four zones measured flat from the beacon. On the dam (beacon ring 30 m, `within_m` 200, so any ground counts inside 150 m; the yard centred `ahead_m` 10 m on from the ball, `radius_m` 26, `WALL_SLACK` 4): "ring" is inside the 30 m ring; "near" is outside it but within about 82 m, where a yard shut on the ball can hold it within the ring (30 + 10 + 26 + 4 = 70 m) or within a strike's 42 m of the Warden (42 + 40 = 82 m); "circle" is the rest of the any-ground share, from about 82 m to 150 m; "out" is everything else, the incline's 150 to 200 m band included (it shuts the yard only on level ground, which the model counts as "circle").

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `ArmedChecksEngaged` | `_step_lock` "armed": `_engaged_s >= 0.0` spends the lock unfired | `yardlock-broken-armedguard` | `NoLockInWardenFight` |
| `FlowSpends` | `_on_flow_changed`: a shut yard spent, its wall dropped | `yardlock-broken-flowspend` | `WallOnlyWhileLocked` |
| `UnlockDropsWall` | `_unlock`: `_drop_wall()` | `yardlock-broken-wall` | `WallOnlyWhileLocked` |
| `MaxSOpens` | `_step_lock` "locked": `lock_left` runs down and `_unlock(false)` at 0 | `yardlock-broken-maxs` | `LockAlwaysOpens` |
| `UnlockSpends` | `_unlock`: `lock_state = "spent"` | `yardlock-broken-repay` | `YardPaysOnce` |
| `ElifUnlock` | `_step_lock` "locked": the `max_s` branch and the crew branch are `if`/`elif` | `yardlock-broken-elif` | `StartCardOnce` |
| `OfferNeedsWin` | `_unlock`: `overtime.offer` only `if won` | `yardlock-broken-offer` | `OvertimeOnlyAfterWin` |
| `CashSpends` | overtime.gd `cash`: `state = "spent"` | `yardlock-broken-cash` | `OvertimeOnlyAfterWin` |
| `RingCap` | overtime.gd `ring`: `rings >= MAX_RINGS` refuses | `yardlock-broken-ringcap` | `OvertimeOnlyAfterWin` |
| `LockedYields` | not in the code: "locked" opens the yard once `_engaged_s >= 0.0` (the YL-1 fix) | `yardlock-today` (FALSE, the code) | `NoLockInWardenFight` |
| `DeadSpends` | not in the code: `"dead"` in `_on_flow_changed`'s list (the YL-2 fix) | `yardlock-today-nostore` (FALSE, the code) | `WallOnlyWhileLocked` |

Each plant starts from `yardlock-guarded` (both fixes on), so it breaks only its own rule (VFM-03).

## Assumptions

- `LongFlight`: the ball can reach the near or ring zone with the yard still armed, which needs it to cross the any-ground share (150 to about 82 m from the beacon) without touching ground: a jump, a launch, a harpoon swing or a fall from height. With it off, a ball that touches ground in the circle shuts the yard there, too far from the Warden for the ball to enter the ring or strike it from inside the yard (`yardlock-today-rolling`). Every stage entry, retry and Continue places the ball outside the circle (the dam's entry is about 1,270 m out), so a rolling ball always meets the share first.
- One locks tick runs out a wave's whistle; `max_s` is 5 locks ticks and the lock row 2 waves, so a won yard keeps time on its clock (as a 60 s lock does) and a slow one times out.

## Bounds

A run of two stages, both with a lock row (the dam and the flume), three stage entries a behaviour (retries, new runs and Continues count), two waves, `max_s` of 5 ticks, `MAX_RINGS` 3. The yard's panel and the start-card calls are counted per activation (per stage entry), capped at 2 so a plant that unlocks every tick stays finite.

## Configs

Run `bash models/make-yardlock-configs.sh`, then plain TLC on each `yardlock-*.cfg` with `YardLock.tla` (`LockAlwaysOpens` is a temporal property, so each config with it checks liveness under weak fairness of the three ticks).

| Config | Stands for | Must report |
| --- | --- | --- |
| `yardlock-today` | the code at the sync commit, in a played game | `NoLockInWardenFight` (finding YL-1) |
| `yardlock-today-rolling` | the same code, with `LongFlight` off | no break, in at least the pinned 47,997 distinct states |
| `yardlock-today-nostore` | the code in a storeless flow (tests, bots), `NoLockInWardenFight` left out | `WallOnlyWhileLocked` (finding YL-2) |
| `yardlock-guarded`, `yardlock-guarded-nostore` | both fixes on, with and without a store | no break (144,089 and 131,620 distinct states) |
| `yardlock-broken-*` | one guard off from `guarded`, as the Guards table lists | the named rule breaks |
| `yardlock-reach-*` | one probe each that says "never" about a thing that must happen: a lock shuts, shuts near the beacon, is won, times out, is skipped for an awake Warden, is skipped on an unsealed stage, lands a second wave, is spent by a flow change, the bell rings and is cashed, the Warden wakes, a strike lands on it, a Continue, a retry (storeless), a lock on the second stage | the probe breaks; one that holds means an action can no longer fire |

`node scripts/gate/model-receipts.mjs --out <dir> --row yard-lock-safe` writes the receipt from `yardlock-today-rolling` and the nine `yardlock-broken-*` plants. `yardlock-today` is not in the receipt while YL-1 is open: the receipt names YL-1 and YL-2 as gaps on every run. When the YL-1 fix lands, `LockedYields` flips to TRUE in the script's table, `yardlock-today` must report no break, and it replaces `yardlock-today-rolling` in the receipt.

## Not modelled

The Warden's clamp (`gate`, packs, `also`, its own `max_s`), the sentry, the wall's spring and bounce (a held ball stays in the zones the ring covers), the wave marks and sounds, more than one crew member, the bell's sluice and flood, the boss arena and victory lap (no lock row reaches them), seconds, and anything drawn or heard. `show_start_card`'s other callers (`_begin_run`, `retry_stage`, `resume_run`, `_engage`, the start card's own buttons, the workshop and the launch take) are outside the rule `StartCardOnce`, which counts the lock's two calls.

Sync commit: e7715dcfa (branch stage/alpha-w45, 21 November 2026, FV-2: the model written from this commit)
