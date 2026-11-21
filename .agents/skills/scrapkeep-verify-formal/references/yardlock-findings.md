# Findings of the yard lock model

Each finding is a break of `models/YardLock.tla` that replayed on the real game. [yardlock-coverage.md](yardlock-coverage.md) names the code behind each step. A closed finding names the change that closed it.

## Open

### YL-1. The yard shuts while the Warden is awake, and stays shut through the Warden's fight

- Rule: `NoLockInWardenFight`. Configs: `yardlock-today` (the code at `0b3624907`, a played game with a store), `yardlock-today-flight` and `yardlock-today-ranged` (each path on its own). `yardlock-guarded` turns on `LockedYields` and reports no break.
- Two paths reach it (TLC 2.19, tla2tools 1.7.4, 8 workers, Mac Studio, 21 November 2026). In every frame flow's `physics_step` and StageLocks' `_step_lock` read the same ball, flow first, and the ball moves after both (VFM-12).
  - Near, `yardlock-today`'s 13-state path: a new run enters stage 1 with the yard armed. The ball first touches ground near the beacon but outside its ring, and `_step_lock` shuts the yard round it (`_lock`). The ball rolls on inside the yard into the ring; the next frame `physics_step` finds it there and calls `_engage`, and `warden_engaged` sets `_engaged_s`. On the dam a yard shut on a ball within about 70 m of the beacon holds part of the ring (the yard is centred 10 m on from the ball, radius 26 m, wall slack 4 m, ring 30 m).
  - Strike, `yardlock-today-ranged`'s 14-state path: the ball rolls in and touches ground at the edge of the lock's any-ground share (150 m on the dam), and the yard shuts there. It holds the ball as close as 110 m to the beacon, and a shot from inside it lands on the Warden: `sketches/core-loop/src/core/flow.gd` `_on_enemy_struck` wakes the Warden on any hit, wherever the ball is, and a shot reaches `range_m` (`sketches/core-loop/src/combat/weapons.gd`: 85 m for the rapid laser, 70 for the arc caster, 95 for the pylon turret) times `weapon_range` (1.5 with a horizon optic, `sketches/core-loop/src/build/parts.gd`), so up to 142.5 m. A bare pylon turret reaches the Warden from a yard shut nearer in.
  - Either way, `_step_lock`'s "locked" branch never reads `_engaged_s` (only "armed" does, `sketches/core-loop/src/world/stage_locks.gd:367`), so the yard stays shut with the Warden awake.
- What it needs: either a ball that reaches within about 70 m of the beacon without touching ground inside the share (a jump, a launch, a harpoon swing or a drop from height), or a hit on the Warden from inside a shut yard, which needs a weapon that reaches it from there. A ball that rolls in and fires at nothing outside the Warden's ring does not reach it: `yardlock-today-unfired` reports no break. The bot and the scripted tests roll in and do not aim at the Warden from the yard, which is why no test saw it.
- Harm: the Warden's fight happens inside a shut yard. The wall springs the ball back for up to the row's `max_s` (60 s on the dam), the crew's waves keep landing in the fight, and the objective plate reads "Yard locked: break its crew." while the Warden attacks. The design line in `sketches/core-loop/src/world/stage_locks.gd` ("The Warden already awake skips it, so the lock never lands in its fight") does not hold. The clamp's own `max_s` counts from `_engaged_s` while the yard holds. The yard does open: `LockAlwaysOpens` holds on every config.
- Replay: `replay/yard_locked_in_warden_fight.gd` (the `near` and `strike` steps), copied into `sketches/core-loop/tests/` as zz_replay_yardlock.gd and run with `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/<copy>.gd` (Godot 4.7.2.stable.official.ed1daf0bf, `HOME` and `XDG_DATA_HOME` set to `artifacts/local/test-home`), on `b5737970d` (this branch with `0b3624907` merged), 21 November 2026, then deleted:

  ```
  near:
    placed 15 m outside the ring: flow stage, ball 45.0 m from the beacon (ring 30 m), grounded false, lock armed, wall false, Warden engaged false
    Lock (after 2 frames): flow stage, ball 45.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    yard centre 35.0 m from the beacon, radius 26 m
    that point is 10.0 m from the yard centre
    rolled into the ring: flow beacon, ball 25.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
    half a second later: flow beacon, ball 25.2 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
  near: REPRODUCED
  strike:
    Lock (after 2 frames): flow stage, ball 145.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    yard centre 135.0 m from the beacon; the ball goes to a point 25.0 m from the yard centre
    rolled to the yard's beacon side: flow stage, ball 110.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    the Warden is 127.2 m away; a pylon turret reaches 95 m, 142.5 m with a horizon optic
    StrikeWarden: flow stage, ball 110.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
    half a second later: flow stage, ball 110.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
  strike: REPRODUCED
  ```

  The transcript is trimmed: each step's `Start` line and Godot's engine warnings are left out. `player.reset_to` stands in for the flight or roll that brings the ball there and for the roll inside the yard, so the wall's hold is not exercised; every tick after it is the game's own. The `strike` step emits the `enemy_struck` signal that combat.gd emits for every hit, on the Warden, from 127.2 m, and reads the reach from the game's own `Weapons.BASE` and `Parts.CATALOGUE`: it stands in for an aimed shot, not a fired one. The first draft of this finding also led with a one-frame path in which the yard shut on a ball already inside the ring; its replay had in fact shut the yard with the ball 30.3 m out, and the model's frame order behind it was wrong (VFM-12), so it is withdrawn.

- Proposed fix (not made; game code is outside this unit): in `_step_lock`'s "locked" branch, open the yard as soon as `_engaged_s >= 0.0`, the way "armed" spends it: `if _engaged_s >= 0.0: _unlock(false); return` before the `lock_left` check. That is `LockedYields`, and `yardlock-guarded` holds every rule with it. Refusing to shut the yard where its wall would reach the beacon ring stops only the near path: a shot from a yard shut at the share's edge still wakes the Warden. The fix is a design call for the Gate.

### YL-2. In a storeless flow the dead screen keeps the yard shut and its wall standing

- Rule: `WallOnlyWhileLocked`. Config: `yardlock-today-nostore` (`NoLockInWardenFight` left out, so the checker gets past YL-1). `yardlock-guarded-nostore` turns on `DeadSpends` and reports no break.
- Steps: a storeless flow (`flow.store == null`: the headless tests and the bots that do not opt in) enters stage 1; the ball touches ground in the circle and the yard shuts; the ball dies. `_on_player_died` sets DEAD, and `_on_flow_changed` has no `"dead"` in its list, so the lock stays `"locked"` and the wall stands behind the dead screen. The locks stop ticking (`in_stage()` is false). A retry's `stage_entered` clears it.
- Harm: none for a player. A played game always has a store, and a death there ends the run through the summary, which spends the yard (the replay's control). A bot or test that reads `lock_active()` or the HUD's `yard_locked` on the dead screen sees a shut yard.
- Replay: the same script's `dead` and `control` steps, same run:

  ```
  dead:
    Lock: flow stage, ball 140.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    Death: flow dead, ball 140.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    half a second later: flow dead, ball 140.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    Retry: flow stage, ball 1273.3 m from the beacon (ring 30 m), grounded false, lock armed, wall false, Warden engaged false
  dead: REPRODUCED
  control:
    Death: flow summary, ball 140.0 m from the beacon (ring 30 m), grounded true, lock spent, wall true, Warden engaged false
    half a second later: flow summary, ball 140.0 m from the beacon (ring 30 m), grounded true, lock spent, wall false, Warden engaged false
  control (store): NOT REPRODUCED
  ```

  The control's wall still shows on the death frame because `_drop_wall` frees it with `queue_free`; it is gone the next frame.

- Proposed fix: add `"dead"` to the list in `_on_flow_changed` (`DeadSpends`).

## No candidate

`StartCardOnce`, `YardPaysOnce`, `OvertimeOnlyAfterWin` and `LockAlwaysOpens` report no break on any today or guarded config, so nothing needed a replay. The lock's two `show_start_card` calls (`sketches/core-loop/src/world/stage_locks.gd:369` and `:521`) sit in branches that each set `lock_state = "spent"` first, and nothing but `stage_entered` arms a lock again. A yard spent by a flow change calls neither. That leaves one thing the model does not check, noted here for the next change to this model: on stage 1 the start card waits for the yard (`sketches/core-loop/src/core/flow.gd` `start_pick_waits`), and its tiles exist only on stage 1 (`sketches/core-loop/src/ui/start_pick_card.gd` `show_picks`). If the Warden breaks while the yard is still shut (which YL-1 makes possible) or vanishes then, the yard is spent by `gates` with no `show_start_card`, and the run may never be offered its start pick. It was not replayed.
