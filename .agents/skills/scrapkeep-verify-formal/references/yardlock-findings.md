# Findings of the yard lock model

Each finding is a break of `models/YardLock.tla` that replayed on the real game. [yardlock-coverage.md](yardlock-coverage.md) names the code behind each step. A closed finding names the change that closed it.

## Open

### YL-1. The yard shuts while the Warden is awake, and stays shut through the Warden's fight

- Rule: `NoLockInWardenFight`. Config: `yardlock-today` (the code at `e7715dcfa`, a played game with a store). `yardlock-guarded` turns on `LockedYields` and reports no break.
- Steps, in the code's words (TLC 2.19, tla2tools 1.7.4, 8 workers, Mac Studio, 21 November 2026): a new run enters stage 1 with the yard armed. In one physics frame, flow's `physics_step` reads the ball outside the beacon ring; the ball's own tick then carries it, grounded, inside the ring; StageLocks' `_step_lock`, which runs after the ball in tree order, finds it grounded inside the lock's circle and shuts the yard (`_lock`). The next frame, `physics_step` finds the ball in the ring and calls `_engage`; `warden_engaged` sets `_engaged_s`. `_step_lock`'s "locked" branch never reads `_engaged_s` (only "armed" does, `sketches/core-loop/src/world/stage_locks.gd:367`), so the yard stays shut with the Warden awake.
- A second path reaches the same state with no one-frame timing: the ball first touches ground near the beacon but outside its ring, the yard shuts round it, and the ball rolls on inside the yard into the ring. On the dam a yard shut on a ball within about 70 m of the beacon holds part of the ring (the yard is centred 10 m on from the ball, radius 26 m, wall slack 4 m, ring 30 m).
- What it needs: the ball must reach about 70 m of the beacon without touching ground inside the lock's any-ground share (150 m on the dam), because ground anywhere in that share shuts the yard far from the Warden. A jump, a launch, a harpoon swing or a drop from height across 80 m does it; a ball that rolls in does not (`yardlock-today-rolling` reports no break). The bot and the scripted tests roll in, which is why no test saw it.
- Harm: the Warden's fight happens inside a shut yard. The wall springs the ball back for up to the row's `max_s` (60 s on the dam), the crew's waves keep landing in the fight, and the objective plate reads "Yard locked: break its crew." while the Warden attacks. The design line in `sketches/core-loop/src/world/stage_locks.gd` ("The Warden already awake skips it, so the lock never lands in its fight") does not hold. The clamp's own `max_s` counts from `_engaged_s` while the yard holds. The yard does open: `LockAlwaysOpens` holds on every config.
- Replay: `replay/yard_locked_in_warden_fight.gd` (the `ring` and `near` steps), copied into `sketches/core-loop/tests/` as zz_replay_yardlock.gd and run with `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/<copy>.gd` (Godot 4.7.2.stable.official.ed1daf0bf, `HOME` and `XDG_DATA_HOME` set to `artifacts/local/test-home`), on `e7715dcfa`, 21 November 2026, then deleted:

  ```
  ring:
    placed: flow stage, ball 30.3 m from the beacon (ring 30 m), grounded false, lock armed, wall false, Warden engaged false
    frame 1 (FlowTick, BallTick, LocksTick): flow stage, ball 30.3 m from the beacon (ring 30 m), grounded true, lock armed, wall false, Warden engaged false
    frame 2 (FlowTick, BallTick, LocksTick): flow stage, ball 29.9 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    frame 3 (FlowTick engages): flow beacon, ball 29.6 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
    half a second later: flow beacon, ball 20.2 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
    objective: Yard locked: break its crew.
  ring: REPRODUCED
  near:
    Lock (after 2 frames): flow stage, ball 45.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged false
    yard centre 35.0 m from the beacon, radius 26 m
    rolled into the ring: flow beacon, ball 25.0 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
    half a second later: flow beacon, ball 25.2 m from the beacon (ring 30 m), grounded true, lock locked, wall true, Warden engaged true
  near: REPRODUCED
  ```

  `player.reset_to` stands in for the flight that brings the ball there; every tick after it is the game's own.
- Proposed fix (not made; game code is outside this unit): in `_step_lock`'s "locked" branch, open the yard as soon as `_engaged_s >= 0.0`, the way "armed" spends it: `if _engaged_s >= 0.0: _unlock(false); return` before the `lock_left` check. That is `LockedYields`, and `yardlock-guarded` holds every rule with it. Another way, refusing to shut the yard where its wall would reach the beacon ring, also stops it but needs the ring's radius in `lock_arms`. Either is a design call for the Gate.

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
    Retry: flow stage, ball 1273.4 m from the beacon (ring 30 m), grounded false, lock armed, wall false, Warden engaged false
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
