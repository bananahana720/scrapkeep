--------------------------- MODULE WeaponCadence ---------------------------
(* Weapon trigger and cadence state machine (PILOT-CADENCE.md sections 2,
   3.1-3.6 and 8; ruling ek; Wave 46 units E1-17 and E2-08):
   sketches/core-loop/src/combat/weapon_driver.gd and
   sketches/core-loop/src/combat/combat.gd.

   Models all six pilot trigger families faithfully matching shipped code:
   - Rivet ("rivet", trigger "press"): one round per press, cylinder reload
     with a single-press notch window (early press spends it), 1-tick input
     buffer, Skid/Line Drive top-up (ends reload or tops up cylinder with
     plain rounds behind loaded hot rounds).
   - Sable ("sable_ball" / "sable_mount", trigger "tap_charge"): immediate
     spark on press, hold past threshold charges a bolt (holds at full without
     decay or auto-fire), release >= min fires charged bolt + recover; mount
     and dismount drop charge with no bolt while keeping spark floor/recover.
   - Kest ("kest", trigger "lob_snap"): hold-to-aim / release-to-throw (or
     tap tail-drop) with throw floor, snap window [WindowOpen, WindowClose]
     strictly inside the throw floor, snap press with hold-lock (never opens
     the lob gauge even if held), early press spending the window, Detonation
     Line consuming an open window at most once, plain detonation clearing
     the window, and interrupt dropping lob gauge / snap hold-lock.
   - Tarn ("tarn", trigger "beats"): press-only 1 -> 2 -> 3 combo order (never
     auto-repeats on hold), Beat 1 combo timeout back to Beat 0, Beat 2
     opening the Beat 3 window [WindowOpen, WindowClose] inside Beat 2's
     floor, early press spending the window, Beat 3 recovery, and interrupt
     resetting beat count to 0.
   - Tally ("tally", trigger "stamp"): Balance Due costs CastCost half-pressure
     units (2 = 1.0), opens a beat window where PAID refunds StampRefund
     (1 = 0.5 <= CastCost); early press spends the window; press-only (no hold
     repeat); rolling at cruise refills fractional pressure up to MaxPressure
     (6 = 3.0).
   - Cannon ("cannon", trigger "lock"): hold-paint lane with closing brackets,
     release band selecting Pulse (< WindowOpen), Rail ([WindowOpen,
     WindowClose]), or Barrage (> WindowClose) with post-release recovery and
     input buffer; interrupt dropping the painted lane cleanly without firing.

   Also models:
   - Play gating (flow.in_play() and pause tree): no shot leaves outside play.
   - Attempt boundaries: stage entry, stage retry, arena entry, arena retry,
     victory lap, death, new run, Continue, and quit to title.
   - Interruptions: jam pulse (never freezes trigger/reload/charge/paint),
     ultimate (drops charge, lob gauge, snap lock, painted lane, beat count,
     and buffer; spends waiting/open window; keeps reload running), mount /
     dismount (drops charge, keeps floor/recover), weapon swap (resets new
     weapon to rest), and pause / unpause.
   - Procs (item_proc / _proc_volley): bypass WeaponDriver completely without
     spending a round/pressure, touching a window, or altering reload, charge,
     beat, paint, or cooldown. *)
EXTENDS Naturals

CONSTANTS
    Mag,                      \* Rivet cylinder size (2 stands for 6)
    FloorTicks,               \* shot/spark/cast/beat1/recover floor in ticks (2)
    BufferTicks,              \* input buffer span before ready (1)
    ReloadTicks,              \* Rivet reload ticks (4: 1=wait, 2=open, 3=bufferable, 4=done)
    WindowOpen,               \* tick when notch / snap / beat3 / stamp / rail opens (2)
    WindowClose,              \* tick when notch / snap / beat3 / rail closes (2; stamp closes at WindowClose+1)
    RecoverTicks,             \* Sable post-bolt recover ticks (1)
    ChargeMax,                \* Sable charge steps (2: 0=under-min, 1=partial, 2=full)
    MaxPressure,              \* Tally max pressure in half-units (6 = 3.0)
    CastCost,                 \* Tally cast cost in half-units (2 = 1.0)
    StampRefund,              \* Tally PAID stamp refund in half-units (1 = 0.5)
    MaxReadyBound,            \* bounded ticks to ready after any interrupt (4 = ReloadTicks)
    GuardPlayGate,            \* TRUE: combat._physics_process gates on in_play() and ~paused
    GuardBoundaryReset,       \* TRUE: wired attempt boundaries call weapon_driver.reset()
    AllowDirectTitleQuit,     \* TRUE on today (WC-1 closed by W46-FIX1 PR #1229)
    GuardTitleReset,          \* TRUE: quit_to_title from play/win resets weapon_driver
    GuardJamNoFreeze,         \* TRUE: jam pulse never freezes trigger, reload, charge, or paint
    GuardInterruptDropsHold,  \* TRUE: ultimate/mount interrupts drop charge_armed/charging/lob_charging/buffer
    GuardPressNoRepeat,       \* TRUE: holding fire on press/stamp weapons fires at most once
    GuardProcIsolated,        \* TRUE: item_proc / _proc_volley never mutates WeaponDriver state
    GuardEarlyPressSpends,    \* TRUE: early press before window opens sets window = "spent"
    GuardWindowOnce,          \* TRUE: hitting Rivet notch ends reload and marks window = "hit"
    GuardRefundBound,         \* TRUE: Tally stamp refund <= CastCost, bounded in 0..MaxPressure
    GuardSnapOnce,            \* TRUE: Kest snap press marks window = "hit" and detonates live charge
    GuardDetLineConsumes,     \* TRUE: Kest Detonation Line consume_snap_window marks window = "hit" once
    GuardSnapHoldLock,        \* TRUE: Kest snap press sets _snap_hold_lock so holding never opens lob gauge
    GuardBeatsNoRepeat,       \* TRUE: Tarn beats is press-only and never auto-repeats on hold
    GuardBeatsOrder,          \* TRUE: Tarn Beat 3 requires Beat 1 -> Beat 2 -> open window order
    GuardLockInterruptClears  \* TRUE: Cannon interrupt(INTERRUPT_ULTIMATE) clears _lane_painted without firing

Weapons == {"rivet", "sable_ball", "sable_mount", "kest", "tarn", "tally", "cannon"}
BaseWeapons == {"rivet", "sable_ball", "kest", "tarn", "tally", "cannon"}
Flows == {"play", "dead", "title"}
Windows == {"idle", "waiting", "open", "spent", "hit"}
InterruptKinds == {"none", "jam", "ult", "mount", "swap", "pause"}
WiredBoundaries == {"stage_entry", "stage_retry", "arena_entry", "arena_retry",
                    "lap", "death", "new_run", "continue"}
Acts == {"none", "plain_fire", "reload", "notch_hit", "early_spend", "top_up", "hot_reload",
         "spark", "charged_bolt", "instant_charge_arm", "mount_drop", "ult_interrupt", "boundary_reset",
         "jam_fire", "proc_no_touch", "stamp_refund",
         "kest_throw", "kest_snap", "kest_detline",
         "tarn_beat3",
         "cannon_pulse", "cannon_rail", "cannon_barrage", "cannon_interrupt"}

TriggerOf(w) ==
    IF w = "rivet" THEN "press"
    ELSE IF w \in {"sable_ball", "sable_mount"} THEN "tap_charge"
    ELSE IF w = "kest" THEN "lob_snap"
    ELSE IF w = "tarn" THEN "beats"
    ELSE IF w = "tally" THEN "stamp"
    ELSE "lock"

Min(a, b) == IF a < b THEN a ELSE b
Max(a, b) == IF a > b THEN a ELSE b

\* Derived tick bounds (keeps .cfg numeric constants compact and consistent).
LobFloorTicks    == WindowClose + 1    \* 3: snap window [2,2] sits strictly inside Kest throw floor
Beat2FloorTicks  == WindowClose + 1    \* 3: beat-3 window [2,2] sits strictly inside Tarn beat-2 floor
BeatTimeoutTicks == FloorTicks + 1     \* 3: Tarn beat-1 combo expires 1 tick after beat-1 floor
LockHoldMax      == WindowClose + 1    \* 3: Cannon hold bands 0..1=Pulse, 2=Rail, 3=Barrage
MaxCooldown      == Max(FloorTicks, LobFloorTicks)
MaxRecover       == Max(RecoverTicks, FloorTicks)

VARIABLES
    flow,                  \* "play" | "dead" | "title"
    paused,                \* BOOLEAN (Godot scene tree pause)
    jammed,                \* BOOLEAN (enemy field pulse silencing slots 2 & 3 only)
    weapon,                \* active weapon id
    cooldown,              \* 0..MaxCooldown
    recover,               \* 0..MaxRecover (Sable bolt / Tarn beat-3 / Cannon release recover)
    press_held,            \* BOOLEAN (fire button held across ticks)
    hold_t,                \* 0..LockHoldMax (Sable tap threshold / Kest lob / Cannon lock hold)
    buffered,              \* BOOLEAN (1-press input buffer)
    chamber,               \* 0..Mag (Rivet loaded rounds; 0 for non-press)
    hot_rounds,            \* 0..Mag (Rivet hot rounds remaining at front of cylinder)
    reloading,             \* BOOLEAN (Rivet reload in progress)
    reload_t,              \* 0..ReloadTicks
    charge_armed,          \* BOOLEAN (Sable hold armed by spark press)
    charging,              \* BOOLEAN (Sable charge actively filling)
    charge,                \* 0..ChargeMax (Sable charge level)
    instant_charge,        \* BOOLEAN (Sable Spire Vault instant max-charge window, ARC_CASTER only)
    lob_charging,          \* BOOLEAN (Kest lob gauge open and aiming)
    snap_hold_lock,        \* BOOLEAN (Kest snap press hold-lock blocking gauge open until release)
    live_charge,           \* BOOLEAN (Kest live thrown charge associated with current snap window)
    beat,                  \* 0..2 (Tarn beat combo state: 0=rest, 1=after beat 1, 2=after beat 2)
    beat_t,                \* 0..BeatTimeoutTicks (Tarn beat-1 combo timeout counter)
    lane_painted,          \* BOOLEAN (Cannon ground lane painted and brackets closing)
    window,                \* "idle" | "waiting" | "open" | "spent" | "hit"
    window_t,              \* 0..(WindowClose + 2) (snap / beat-3 / stamp / lock window elapsed)
    pressure,              \* 0..(MaxPressure + 2) (Tally pressure in half-units)
    just_crossed_boundary, \* TRUE immediately after an attempt boundary
    after_interrupt,       \* "none" | "jam" | "ult" | "mount" | "swap" | "pause"
    steps_since_interrupt, \* unpaused play ticks since interrupt while ~DriverReady
    press_shots,           \* 0..2 (volleys fired during current press on press/beats/stamp)
    window_pays,           \* 0..2 (window payouts in current reload/charge/beat/stamp cycle)
    early_pressed,         \* BOOLEAN (early press happened before current window opened)
    shot_outside_play,     \* latch: a shot left while flow /= "play" or paused
    stuck_holding,         \* latch: an interrupt left charge/lob/painted state stuck
    proc_mutated_driver,   \* latch: a proc mutated WeaponDriver state
    snap_opened_gauge,     \* latch: a Kest snap press illegally opened the lob gauge
    beat_skip_pay,         \* latch: Tarn Beat 3 fired without Beat 1 -> Beat 2 -> open window
    grew_without_roll,     \* latch: a Tally cast ended with pressure' > pressure
    last_cost,             \* last Tally cast cost
    last_refund,           \* last Tally stamp refund
    last_act               \* tag for reachability probes

vars == <<flow, paused, jammed, weapon, cooldown, recover, press_held, hold_t,
          buffered, chamber, hot_rounds, reloading, reload_t, charge_armed,
          charging, charge, instant_charge, lob_charging, snap_hold_lock, live_charge,
          beat, beat_t, lane_painted, window, window_t, pressure,
          just_crossed_boundary, after_interrupt, steps_since_interrupt,
          press_shots, window_pays, early_pressed, shot_outside_play,
          stuck_holding, proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
          grew_without_roll, last_cost, last_refund, last_act>>

\* Trigger cooldown/recover/reload readiness (voluntary player holds such as Sable
\* full charge, Kest lob aim, or Cannon hold-paint are not lockups; interrupts
\* that fail to clear them are caught by `stuck_holding`).
DriverReady == cooldown = 0 /\ recover = 0 /\ ~reloading

AtRest ==
    /\ cooldown = 0
    /\ recover = 0
    /\ ~press_held
    /\ hold_t = 0
    /\ ~buffered
    /\ ~reloading
    /\ reload_t = 0
    /\ hot_rounds = 0
    /\ ~charging
    /\ ~charge_armed
    /\ charge = 0
    /\ ~instant_charge
    /\ ~lob_charging
    /\ ~snap_hold_lock
    /\ ~live_charge
    /\ beat = 0
    /\ beat_t = 0
    /\ ~lane_painted
    /\ window = "idle"
    /\ window_t = 0
    /\ (TriggerOf(weapon) = "press" => chamber = Mag)

TypeOK ==
    /\ flow \in Flows
    /\ paused \in BOOLEAN
    /\ jammed \in BOOLEAN
    /\ weapon \in Weapons
    /\ cooldown \in 0..MaxCooldown
    /\ recover \in 0..MaxRecover
    /\ press_held \in BOOLEAN
    /\ hold_t \in 0..LockHoldMax
    /\ buffered \in BOOLEAN
    /\ chamber \in 0..Mag
    /\ hot_rounds \in 0..Mag
    /\ hot_rounds <= chamber
    /\ reloading \in BOOLEAN
    /\ reload_t \in 0..ReloadTicks
    /\ charge_armed \in BOOLEAN
    /\ charging \in BOOLEAN
    /\ charge \in 0..ChargeMax
    /\ instant_charge \in BOOLEAN
    /\ lob_charging \in BOOLEAN
    /\ snap_hold_lock \in BOOLEAN
    /\ live_charge \in BOOLEAN
    /\ beat \in 0..2
    /\ beat_t \in 0..BeatTimeoutTicks
    /\ lane_painted \in BOOLEAN
    /\ window \in Windows
    /\ window_t \in 0..(WindowClose + 2)
    /\ pressure \in 0..(MaxPressure + 2)
    /\ just_crossed_boundary \in BOOLEAN
    /\ after_interrupt \in InterruptKinds
    /\ steps_since_interrupt \in 0..(MaxReadyBound + 2)
    /\ press_shots \in 0..2
    /\ window_pays \in 0..2
    /\ early_pressed \in BOOLEAN
    /\ shot_outside_play \in BOOLEAN
    /\ stuck_holding \in BOOLEAN
    /\ proc_mutated_driver \in BOOLEAN
    /\ snap_opened_gauge \in BOOLEAN
    /\ beat_skip_pay \in BOOLEAN
    /\ grew_without_roll \in BOOLEAN
    /\ last_cost \in 0..(CastCost + 2)
    /\ last_refund \in 0..(CastCost + 2)
    /\ last_act \in Acts

\* Helper: reset all driver fields to rest for weapon `w`.
ResetDriver(w) ==
    /\ cooldown' = 0
    /\ recover' = 0
    /\ press_held' = FALSE
    /\ hold_t' = 0
    /\ buffered' = FALSE
    /\ chamber' = IF TriggerOf(w) = "press" THEN Mag ELSE 0
    /\ hot_rounds' = 0
    /\ reloading' = FALSE
    /\ reload_t' = 0
    /\ charge_armed' = FALSE
    /\ charging' = FALSE
    /\ charge' = 0
    /\ instant_charge' = FALSE
    /\ lob_charging' = FALSE
    /\ snap_hold_lock' = FALSE
    /\ live_charge' = FALSE
    /\ beat' = 0
    /\ beat_t' = 0
    /\ lane_painted' = FALSE
    /\ window' = "idle"
    /\ window_t' = 0
    /\ press_shots' = 0
    /\ window_pays' = 0
    /\ early_pressed' = FALSE

Init ==
    /\ flow = "play"
    /\ paused = FALSE
    /\ jammed = FALSE
    /\ weapon \in BaseWeapons
    /\ cooldown = 0
    /\ recover = 0
    /\ press_held = FALSE
    /\ hold_t = 0
    /\ buffered = FALSE
    /\ chamber = IF TriggerOf(weapon) = "press" THEN Mag ELSE 0
    /\ hot_rounds = 0
    /\ reloading = FALSE
    /\ reload_t = 0
    /\ charge_armed = FALSE
    /\ charging = FALSE
    /\ charge = 0
    /\ instant_charge = FALSE
    /\ lob_charging = FALSE
    /\ snap_hold_lock = FALSE
    /\ live_charge = FALSE
    /\ beat = 0
    /\ beat_t = 0
    /\ lane_painted = FALSE
    /\ window = "idle"
    /\ window_t = 0
    /\ pressure = IF weapon = "tally" THEN MaxPressure ELSE 0
    /\ just_crossed_boundary = FALSE
    /\ after_interrupt = "none"
    /\ steps_since_interrupt = 0
    /\ press_shots = 0
    /\ window_pays = 0
    /\ early_pressed = FALSE
    /\ shot_outside_play = FALSE
    /\ stuck_holding = FALSE
    /\ proc_mutated_driver = FALSE
    /\ snap_opened_gauge = FALSE
    /\ beat_skip_pay = FALSE
    /\ grew_without_roll = FALSE
    /\ last_cost = 0
    /\ last_refund = 0
    /\ last_act = "none"

\* Helper: update bounded-ready tracker on an unpaused play step.
TrackProgress(becameReady) ==
    IF after_interrupt = "none" THEN
        /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
    ELSE IF becameReady THEN
        /\ after_interrupt' = "none"
        /\ steps_since_interrupt' = 0
    ELSE
        /\ after_interrupt' = after_interrupt
        /\ steps_since_interrupt' = Min(steps_since_interrupt + 1, MaxReadyBound + 2)

\* Legal button inputs given current press_held state.
AllowedInputs ==
    IF press_held THEN {"hold", "release"}
    ELSE {"idle", "press_tap", "press_hold"}

InPlayTick == (flow = "play" /\ ~paused) \/ ~GuardPlayGate
OutsidePlay == (flow /= "play" \/ paused)

\* ---------------------------------------------------------------------------
\* 1. Rivet ("rivet", trigger "press") tick: weapon_driver.gd _step_press
\* ---------------------------------------------------------------------------
StepRivet(inp) ==
    /\ weapon = "rivet"
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           cdNext == IF jamFrozen THEN cooldown
                     ELSE IF cooldown > 0 THEN cooldown - 1 ELSE 0
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, recover, hold_t,
                      charge_armed, charging, charge, instant_charge, lob_charging,
                      snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                      window_t, pressure, stuck_holding, proc_mutated_driver,
                      snap_opened_gauge, beat_skip_pay, grew_without_roll,
                      last_cost, last_refund>>
       /\ IF jamFrozen THEN
             \* Planted fault: jam freezes timers, reload, and firing.
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, buffered, chamber, hot_rounds, reloading,
                            reload_t, window, press_shots, window_pays,
                            early_pressed, shot_outside_play>>
          ELSE IF reloading THEN
             LET rt == Min(reload_t + 1, ReloadTicks)
                 wNow ==
                     IF window \in {"spent", "hit"} THEN window
                     ELSE IF rt < WindowOpen THEN "waiting"
                     ELSE IF rt <= WindowClose THEN "open"
                     ELSE "spent"
             IN
             IF pressed /\ wNow = "open" THEN
                \* Sweet-spot notch hit: shuts cylinder, loads Mag hot rounds, fires 1st!
                /\ window_pays' = Min(window_pays + 1, 2)
                /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                /\ press_shots' = IF held THEN 1 ELSE 0
                /\ buffered' = FALSE
                /\ IF GuardWindowOnce THEN
                      /\ reloading' = FALSE
                      /\ reload_t' = 0
                      /\ window' = "hit"
                      /\ chamber' = Mag - 1
                      /\ hot_rounds' = Mag - 1
                      /\ cooldown' = FloorTicks
                      /\ TrackProgress(TRUE)
                   ELSE
                      \* Planted fault: notch does not close reload or mark window hit.
                      /\ reloading' = TRUE
                      /\ reload_t' = reload_t
                      /\ window' = "open"
                      /\ chamber' = chamber
                      /\ hot_rounds' = hot_rounds
                      /\ cooldown' = 0
                      /\ TrackProgress(FALSE)
                /\ UNCHANGED early_pressed
                /\ last_act' = "notch_hit"
             ELSE
                LET spentEarly == pressed /\ wNow = "waiting"
                    wAfterPress ==
                        IF spentEarly THEN
                            IF GuardEarlyPressSpends THEN "spent" ELSE "waiting"
                        ELSE wNow
                    earlyNext == early_pressed \/ spentEarly
                    bufAfterPress ==
                        IF pressed /\ ~spentEarly /\ (ReloadTicks - rt <= BufferTicks)
                        THEN TRUE ELSE buffered
                IN
                IF rt >= ReloadTicks THEN
                   \* Reload finishes: full plain cylinder; fire buffered press if latched.
                   /\ reloading' = FALSE
                   /\ reload_t' = 0
                   /\ window' = "idle"
                   /\ window_pays' = 0
                   /\ early_pressed' = FALSE
                   /\ TrackProgress(TRUE)
                   /\ IF bufAfterPress /\ Mag > 0 THEN
                         /\ buffered' = FALSE
                         /\ chamber' = Mag - 1
                         /\ hot_rounds' = 0
                         /\ cooldown' = FloorTicks
                         /\ press_shots' = IF held THEN 1 ELSE 0
                         /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                         /\ last_act' = IF jammed THEN "jam_fire" ELSE "plain_fire"
                      ELSE
                         /\ buffered' = FALSE
                         /\ chamber' = Mag
                         /\ hot_rounds' = 0
                         /\ cooldown' = 0
                         /\ press_shots' = 0
                         /\ UNCHANGED shot_outside_play
                         /\ last_act' = "none"
                ELSE
                   /\ reloading' = TRUE
                   /\ reload_t' = rt
                   /\ window' = wAfterPress
                   /\ early_pressed' = earlyNext
                   /\ buffered' = bufAfterPress
                   /\ cooldown' = 0
                   /\ press_shots' = 0
                   /\ TrackProgress(FALSE)
                   /\ UNCHANGED <<chamber, hot_rounds, window_pays, shot_outside_play>>
                   /\ last_act' = IF spentEarly THEN "early_spend" ELSE "reload"
          ELSE
             \* Not reloading: press, buffer release, or planted hold-repeat.
             LET baseShots == IF pressed THEN 0
                              ELSE IF held THEN press_shots ELSE 0
                 fireNow ==
                     /\ chamber > 0
                     /\ cdNext = 0
                     /\ (pressed \/ buffered \/ (held /\ ~pressed /\ ~GuardPressNoRepeat))
                 bufferNow ==
                     /\ pressed
                     /\ chamber > 0
                     /\ cdNext > 0
                     /\ cdNext <= BufferTicks
             IN
             IF fireNow THEN
                LET newChamber == chamber - 1
                    newHot == IF hot_rounds > 0 THEN hot_rounds - 1 ELSE 0
                    startReload == (newChamber = 0)
                IN
                /\ chamber' = newChamber
                /\ hot_rounds' = newHot
                /\ buffered' = FALSE
                /\ press_shots' = IF held THEN Min(baseShots + 1, 2) ELSE 0
                /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                /\ TrackProgress(TRUE)
                /\ IF startReload THEN
                      /\ reloading' = TRUE
                      /\ reload_t' = 0
                      /\ window' = "waiting"
                      /\ window_pays' = 0
                      /\ early_pressed' = FALSE
                      /\ cooldown' = 0
                      /\ last_act' = "reload"
                   ELSE
                      /\ reloading' = FALSE
                      /\ reload_t' = 0
                      /\ window' = "idle"
                      /\ window_pays' = 0
                      /\ early_pressed' = FALSE
                      /\ cooldown' = FloorTicks
                      /\ last_act' = IF jammed THEN "jam_fire" ELSE "plain_fire"
             ELSE
                /\ cooldown' = cdNext
                /\ buffered' = IF bufferNow THEN TRUE ELSE FALSE
                /\ press_shots' = IF held THEN baseShots ELSE 0
                /\ TrackProgress(cdNext = 0)
                /\ UNCHANGED <<chamber, hot_rounds, reloading, reload_t, window,
                               window_pays, early_pressed, shot_outside_play>>
                /\ last_act' = "none"

\* Rivet Skid landing / Line Drive: weapon_driver.gd top_up_cylinder()
TopUpCylinder ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "rivet"
    /\ (reloading \/ chamber < Mag)
    /\ just_crossed_boundary' = FALSE
    /\ IF reloading THEN
          /\ reloading' = FALSE
          /\ reload_t' = 0
          /\ window' = "idle"
          /\ window_pays' = 0
          /\ early_pressed' = FALSE
          /\ chamber' = Mag
          /\ hot_rounds' = 0
          /\ cooldown' = 0
          /\ TrackProgress(TRUE)
       ELSE
          /\ chamber' = Mag
          /\ UNCHANGED <<reloading, reload_t, window, window_pays, early_pressed,
                         hot_rounds, cooldown, after_interrupt, steps_since_interrupt>>
    /\ last_act' = "top_up"
    /\ UNCHANGED <<flow, paused, jammed, weapon, recover, press_held, hold_t,
                   buffered, charge_armed, charging, charge, instant_charge, lob_charging,
                   snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                   window_t, pressure, press_shots, shot_outside_play,
                   stuck_holding, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* Rivet relic swap hot reload: weapon_driver.gd hot_reload_cylinder()
HotReloadCylinder ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "rivet"
    /\ (reloading \/ chamber < Mag \/ hot_rounds < Mag)
    /\ just_crossed_boundary' = FALSE
    /\ chamber' = Mag
    /\ hot_rounds' = Mag
    /\ IF reloading THEN
          /\ reloading' = FALSE
          /\ reload_t' = 0
          /\ window' = "idle"
          /\ window_pays' = 0
          /\ early_pressed' = FALSE
          /\ cooldown' = 0
          /\ TrackProgress(TRUE)
       ELSE
          /\ UNCHANGED <<reloading, reload_t, window, window_pays, early_pressed,
                         cooldown, after_interrupt, steps_since_interrupt>>
    /\ last_act' = "hot_reload"
    /\ UNCHANGED <<flow, paused, jammed, weapon, recover, press_held, hold_t,
                   buffered, charge_armed, charging, charge, instant_charge, lob_charging,
                   snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                   window_t, pressure, press_shots, shot_outside_play,
                   stuck_holding, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* 2. Sable ("sable_ball" / "sable_mount", trigger "tap_charge"): _step_tap_charge
\* ---------------------------------------------------------------------------
StepSable(inp) ==
    /\ weapon \in {"sable_ball", "sable_mount"}
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           released == inp = "release"
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           cdNext == IF jamFrozen THEN cooldown
                     ELSE IF cooldown > 0 THEN cooldown - 1 ELSE 0
           recNext == IF jamFrozen THEN recover
                      ELSE IF recover > 0 THEN recover - 1 ELSE 0
           readyNow == ~jamFrozen /\ cdNext = 0 /\ recNext = 0
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, chamber, hot_rounds,
                      reloading, reload_t, lob_charging, snap_hold_lock,
                      live_charge, beat, beat_t, lane_painted, window,
                      window_t, pressure, press_shots, window_pays,
                      early_pressed, stuck_holding, proc_mutated_driver,
                      snap_opened_gauge, beat_skip_pay, grew_without_roll,
                      last_cost, last_refund>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, recover, hold_t, buffered, charge_armed,
                            charging, charge, instant_charge, shot_outside_play>>
          ELSE
             LET fireSpark == readyNow /\ (pressed \/ buffered)
                 instantNow == fireSpark /\ instant_charge /\ weapon = "sable_ball"
                 waitTicks == IF cdNext > recNext THEN cdNext ELSE recNext
                 bufferSpark == ~readyNow /\ pressed /\ waitTicks <= BufferTicks
                 armedAfterSpark == IF fireSpark THEN held ELSE charge_armed
                 chargingAfterSpark == IF fireSpark THEN FALSE ELSE charging
                 chargeAfterSpark == IF fireSpark THEN 0 ELSE charge
                 holdAfterSpark == IF fireSpark THEN 0 ELSE hold_t
                 cdAfterSpark == IF fireSpark THEN FloorTicks ELSE cdNext
                 bufAfterSpark == IF fireSpark THEN FALSE
                                  ELSE IF bufferSpark THEN TRUE ELSE FALSE
             IN
             IF instantNow THEN
                /\ cooldown' = FloorTicks
                /\ recover' = RecoverTicks
                /\ buffered' = FALSE
                /\ charge_armed' = FALSE
                /\ charging' = FALSE
                /\ charge' = 0
                /\ hold_t' = 0
                /\ instant_charge' = FALSE
                /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                /\ TrackProgress(TRUE)
                /\ last_act' = "charged_bolt"
             ELSE IF armedAfterSpark THEN
                IF held /\ ~released THEN
                   IF fireSpark THEN
                      /\ cooldown' = cdAfterSpark
                      /\ recover' = recNext
                      /\ buffered' = bufAfterSpark
                      /\ charge_armed' = armedAfterSpark
                      /\ charging' = chargingAfterSpark
                      /\ charge' = chargeAfterSpark
                      /\ hold_t' = holdAfterSpark
                      /\ instant_charge' \in IF instant_charge THEN {TRUE, FALSE} ELSE {FALSE}
                      /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                      /\ TrackProgress(TRUE)
                      /\ last_act' = IF jammed THEN "jam_fire" ELSE "spark"
                   ELSE
                      \* Hold advances past tap threshold (1 tick) then fills charge to ChargeMax.
                      /\ cooldown' = cdAfterSpark
                      /\ recover' = recNext
                      /\ buffered' = bufAfterSpark
                      /\ charge_armed' = TRUE
                      /\ instant_charge' \in IF instant_charge THEN {TRUE, FALSE} ELSE {FALSE}
                      /\ IF holdAfterSpark = 0 THEN
                            /\ hold_t' = 1
                            /\ charging' = FALSE
                            /\ charge' = 0
                         ELSE
                            /\ hold_t' = 1
                            /\ charging' = TRUE
                            /\ charge' = Min(chargeAfterSpark + 1, ChargeMax)
                      /\ UNCHANGED shot_outside_play
                      /\ TrackProgress(readyNow)
                      /\ last_act' = "none"
                ELSE
                   \* Released while charge_armed: fire bolt iff charging /\ charge >= 1.
                   LET fireBolt == chargingAfterSpark /\ chargeAfterSpark >= 1 IN
                   /\ cooldown' = cdAfterSpark
                   /\ recover' = IF fireBolt THEN RecoverTicks ELSE recNext
                   /\ buffered' = bufAfterSpark
                   /\ charge_armed' = FALSE
                   /\ charging' = FALSE
                   /\ charge' = 0
                   /\ hold_t' = 0
                   /\ instant_charge' \in IF fireBolt /\ weapon = "sable_ball" THEN {FALSE}
                                          ELSE IF instant_charge THEN {TRUE, FALSE} ELSE {FALSE}
                   /\ shot_outside_play' = (shot_outside_play \/ ((fireSpark \/ fireBolt) /\ OutsidePlay))
                   /\ TrackProgress(readyNow)
                   /\ last_act' = IF fireBolt THEN "charged_bolt"
                                  ELSE IF fireSpark THEN (IF jammed THEN "jam_fire" ELSE "spark")
                                  ELSE "none"
             ELSE
                /\ cooldown' = cdAfterSpark
                /\ recover' = recNext
                /\ buffered' = bufAfterSpark
                /\ charge_armed' = FALSE
                /\ charging' = FALSE
                /\ charge' = 0
                /\ hold_t' = 0
                /\ instant_charge' \in IF instant_charge THEN {TRUE, FALSE} ELSE {FALSE}
                /\ shot_outside_play' = (shot_outside_play \/ (fireSpark /\ OutsidePlay))
                /\ TrackProgress(readyNow)
                /\ last_act' = IF fireSpark THEN (IF jammed THEN "jam_fire" ELSE "spark") ELSE "none"

\* Sable Spire Vault instant max-charge: weapon_driver.gd arm_instant_max_charge()
ArmInstantCharge ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "sable_ball"
    /\ ~instant_charge
    /\ instant_charge' = TRUE
    /\ charging' = IF charge_armed THEN TRUE ELSE charging
    /\ charge' = IF charge_armed THEN ChargeMax ELSE charge
    /\ just_crossed_boundary' = FALSE
    /\ last_act' = "instant_charge_arm"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   hold_t, buffered, chamber, hot_rounds, reloading, reload_t,
                   charge_armed, lob_charging, snap_hold_lock, live_charge,
                   beat, beat_t, lane_painted, window, window_t, pressure,
                   after_interrupt, steps_since_interrupt, press_shots,
                   window_pays, early_pressed, shot_outside_play,
                   stuck_holding, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* 3. Kest ("kest", trigger "lob_snap"): weapon_driver.gd _step_lob_snap &
\*    combat.gd _step_sticky_weapon / _fire_line / _detonate
\* ---------------------------------------------------------------------------
StepKest(inp) ==
    /\ weapon = "kest"
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           released == inp = "release"
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           cdNext == IF jamFrozen THEN cooldown
                     ELSE IF cooldown > 0 THEN cooldown - 1 ELSE 0
           lockNext == IF ~held THEN FALSE ELSE snap_hold_lock
           wtNext == IF jamFrozen THEN window_t
                     ELSE IF window \in {"waiting", "open"} THEN Min(window_t + 1, WindowClose + 2)
                     ELSE window_t
           wNow == IF jamFrozen THEN window
                   ELSE IF window \in {"waiting", "open"} THEN
                       IF wtNext < WindowOpen THEN "waiting"
                       ELSE IF wtNext <= WindowClose THEN "open"
                       ELSE "spent"
                   ELSE window
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, recover, chamber,
                      hot_rounds, reloading, reload_t, charge_armed, charging,
                      charge, instant_charge, beat, beat_t, lane_painted, pressure,
                      press_shots, stuck_holding, proc_mutated_driver,
                      beat_skip_pay, grew_without_roll, last_cost, last_refund>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, hold_t, buffered, lob_charging,
                            snap_hold_lock, live_charge, window, window_t,
                            window_pays, early_pressed, shot_outside_play,
                            snap_opened_gauge>>
          ELSE IF pressed /\ wNow = "open" THEN
             \* Snap hit inside [WindowOpen, WindowClose]: bursts charge bigger,
             \* sets _snap_hold_lock = held so holding never opens the lob gauge.
             /\ cooldown' = cdNext
             /\ hold_t' = 0
             /\ buffered' = FALSE
             /\ window_pays' = Min(window_pays + 1, 2)
             /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
             /\ IF GuardSnapOnce THEN
                   /\ window' = "hit"
                   /\ window_t' = wtNext
                   /\ live_charge' = FALSE
                ELSE
                   \* Planted fault: snap fails to consume window or clear live charge.
                   /\ window' = "open"
                   /\ window_t' = window_t
                   /\ live_charge' = live_charge
             /\ IF GuardSnapHoldLock THEN
                   /\ snap_hold_lock' = held
                   /\ lob_charging' = FALSE
                   /\ snap_opened_gauge' = snap_opened_gauge
                ELSE
                   \* Planted fault: snap press leaks into opening lob gauge while held.
                   /\ snap_hold_lock' = FALSE
                   /\ lob_charging' = held
                   /\ snap_opened_gauge' = (snap_opened_gauge \/ held)
             /\ UNCHANGED early_pressed
             /\ TrackProgress(cdNext = 0)
             /\ last_act' = "kest_snap"
          ELSE
             LET spentEarly == pressed /\ wNow = "waiting"
                 wAfterPress ==
                     IF spentEarly THEN
                         IF GuardEarlyPressSpends THEN "spent" ELSE "waiting"
                     ELSE wNow
                 earlyNext == early_pressed \/ spentEarly
             IN
             IF ~lob_charging THEN
                LET wantStart == pressed \/ buffered \/ (held /\ ~lockNext)
                    canStart == cdNext = 0 /\ ~lockNext
                IN
                IF wantStart /\ canStart THEN
                   IF ~held THEN
                      \* Immediate tail-drop throw (tap or buffered with button up).
                      /\ cooldown' = LobFloorTicks
                      /\ hold_t' = 0
                      /\ buffered' = FALSE
                      /\ lob_charging' = FALSE
                      /\ snap_hold_lock' = FALSE
                      /\ live_charge' = TRUE
                      /\ window' = "waiting"
                      /\ window_t' = 0
                      /\ window_pays' = 0
                      /\ early_pressed' = FALSE
                      /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                      /\ UNCHANGED snap_opened_gauge
                      /\ TrackProgress(TRUE)
                      /\ last_act' = IF jammed THEN "jam_fire" ELSE "kest_throw"
                   ELSE
                      \* Hold opens lob gauge without throwing yet.
                      /\ cooldown' = 0
                      /\ hold_t' = 0
                      /\ buffered' = FALSE
                      /\ lob_charging' = TRUE
                      /\ snap_hold_lock' = lockNext
                      /\ live_charge' = live_charge
                      /\ window' = wAfterPress
                      /\ window_t' = wtNext
                      /\ early_pressed' = earlyNext
                      /\ UNCHANGED <<window_pays, shot_outside_play, snap_opened_gauge>>
                      /\ TrackProgress(TRUE)
                      /\ last_act' = "none"
                ELSE
                   LET bufNow == pressed /\ ~spentEarly /\ cdNext > 0 /\ cdNext <= BufferTicks
                                 /\ wAfterPress \notin {"open", "waiting"}
                   IN
                   /\ cooldown' = cdNext
                   /\ hold_t' = 0
                   /\ buffered' = bufNow
                   /\ lob_charging' = FALSE
                   /\ snap_hold_lock' = lockNext
                   /\ live_charge' = live_charge
                   /\ window' = wAfterPress
                   /\ window_t' = wtNext
                   /\ early_pressed' = earlyNext
                   /\ UNCHANGED <<window_pays, shot_outside_play, snap_opened_gauge>>
                   /\ TrackProgress(cdNext = 0)
                   /\ last_act' = IF spentEarly THEN "early_spend" ELSE "none"
             ELSE
                \* Lob gauge open: holding up to 1 tick aims farther; release or cap throws.
                IF held /\ ~released /\ hold_t = 0 THEN
                   /\ cooldown' = cdNext
                   /\ hold_t' = 1
                   /\ buffered' = FALSE
                   /\ lob_charging' = TRUE
                   /\ snap_hold_lock' = lockNext
                   /\ live_charge' = live_charge
                   /\ window' = wAfterPress
                   /\ window_t' = wtNext
                   /\ early_pressed' = earlyNext
                   /\ UNCHANGED <<window_pays, shot_outside_play, snap_opened_gauge>>
                   /\ TrackProgress(cdNext = 0)
                   /\ last_act' = "none"
                ELSE
                   /\ cooldown' = LobFloorTicks
                   /\ hold_t' = 0
                   /\ buffered' = FALSE
                   /\ lob_charging' = FALSE
                   /\ snap_hold_lock' = lockNext
                   /\ live_charge' = TRUE
                   /\ window' = "waiting"
                   /\ window_t' = 0
                   /\ window_pays' = 0
                   /\ early_pressed' = FALSE
                   /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                   /\ UNCHANGED snap_opened_gauge
                   /\ TrackProgress(cdNext = 0)
                   /\ last_act' = IF jammed THEN "jam_fire" ELSE "kest_throw"

\* Kest Detonation Line (combat.gd _fire_line -> weapon_driver.consume_snap_window):
\* If the caught charge's snap window is open, takes the snap burst and consumes
\* the window once; otherwise detonates plain and notifies charge gone.
KestDetonationLine ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "kest"
    /\ live_charge
    /\ just_crossed_boundary' = FALSE
    /\ IF window = "open" THEN
          /\ window_pays' = Min(window_pays + 1, 2)
          /\ IF GuardDetLineConsumes THEN
                /\ window' = "hit"
                /\ live_charge' = FALSE
             ELSE
                \* Planted fault: Detonation Line takes snap burst without consuming window.
                /\ window' = "open"
                /\ live_charge' = TRUE
          /\ UNCHANGED <<window_t, early_pressed>>
          /\ last_act' = "kest_detline"
       ELSE
          /\ live_charge' = FALSE
          /\ window' = IF window \in {"waiting", "open", "spent"} THEN "idle" ELSE window
          /\ window_t' = IF window \in {"waiting", "open", "spent"} THEN 0 ELSE window_t
          /\ window_pays' = 0
          /\ early_pressed' = FALSE
          /\ last_act' = "none"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   hold_t, buffered, chamber, hot_rounds, reloading, reload_t,
                   charge_armed, charging, charge, instant_charge, lob_charging, snap_hold_lock,
                   beat, beat_t, lane_painted, pressure, after_interrupt,
                   steps_since_interrupt, press_shots, shot_outside_play,
                   stuck_holding, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* Kest live charge detonates plain on fuse expiry or enemy contact:
\* combat.gd _detonate(charge, false) -> weapon_driver.notify_lob_charge_gone(tok).
KestChargePlainDetonate ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "kest"
    /\ live_charge
    /\ just_crossed_boundary' = FALSE
    /\ live_charge' = FALSE
    /\ window' = IF window \in {"waiting", "open", "spent"} THEN "idle" ELSE window
    /\ window_t' = IF window \in {"waiting", "open", "spent"} THEN 0 ELSE window_t
    /\ window_pays' = 0
    /\ early_pressed' = FALSE
    /\ last_act' = "none"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   hold_t, buffered, chamber, hot_rounds, reloading, reload_t,
                   charge_armed, charging, charge, instant_charge, lob_charging, snap_hold_lock,
                   beat, beat_t, lane_painted, pressure, after_interrupt,
                   steps_since_interrupt, press_shots, shot_outside_play,
                   stuck_holding, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* 4. Tarn ("tarn", trigger "beats"): weapon_driver.gd _step_beats
\* ---------------------------------------------------------------------------
StepTarn(inp) ==
    /\ weapon = "tarn"
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           cdNext == IF jamFrozen THEN cooldown
                     ELSE IF cooldown > 0 THEN cooldown - 1 ELSE 0
           recNext == IF jamFrozen THEN recover
                      ELSE IF recover > 0 THEN recover - 1 ELSE 0
           baseShots == IF pressed THEN 0
                        ELSE IF held THEN press_shots ELSE 0
           holdRepeat == held /\ ~pressed /\ ~GuardBeatsNoRepeat
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, hold_t, chamber,
                      hot_rounds, reloading, reload_t, charge_armed, charging,
                      charge, instant_charge, lob_charging, snap_hold_lock, live_charge,
                      lane_painted, pressure, stuck_holding,
                      proc_mutated_driver, snap_opened_gauge,
                      grew_without_roll, last_cost, last_refund>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, recover, buffered, beat, beat_t, window,
                            window_t, press_shots, window_pays, early_pressed,
                            shot_outside_play, beat_skip_pay>>
          ELSE
             LET bt1Next == IF beat = 1 THEN beat_t + 1 ELSE 0
                 beatAfterTimeout == IF beat = 1 /\ bt1Next > BeatTimeoutTicks THEN 0 ELSE beat
                 btAfterTimeout == IF beat = 1 /\ bt1Next <= BeatTimeoutTicks THEN bt1Next ELSE 0
             IN
             IF beatAfterTimeout = 2 THEN
                LET wtNext == Min(window_t + 1, WindowClose + 2)
                    wNow ==
                        IF window \in {"spent", "hit"} THEN window
                        ELSE IF wtNext < WindowOpen THEN "waiting"
                        ELSE IF wtNext <= WindowClose THEN "open"
                        ELSE "spent"
                IN
                IF (pressed \/ holdRepeat) /\ wNow = "open" THEN
                   \* Beat 3 hit inside [WindowOpen, WindowClose]: heavy sweep + recovery.
                   /\ beat' = 0
                   /\ beat_t' = 0
                   /\ cooldown' = 0
                   /\ recover' = FloorTicks
                   /\ window' = "hit"
                   /\ window_t' = 0
                   /\ buffered' = FALSE
                   /\ window_pays' = Min(window_pays + 1, 2)
                   /\ press_shots' = IF held THEN Min(baseShots + 1, 2) ELSE 0
                   /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                   /\ UNCHANGED <<early_pressed, beat_skip_pay>>
                   /\ TrackProgress(TRUE)
                   /\ last_act' = "tarn_beat3"
                ELSE
                   LET spentEarly == pressed /\ wNow = "waiting"
                       wAfterPress ==
                           IF spentEarly THEN
                               IF GuardEarlyPressSpends THEN "spent" ELSE "waiting"
                           ELSE wNow
                       earlyNext == early_pressed \/ spentEarly
                       bufAfterPress ==
                           IF pressed /\ ~spentEarly /\ cdNext > 0 /\ cdNext <= BufferTicks
                           THEN TRUE ELSE buffered
                   IN
                   IF cdNext = 0 THEN
                      \* Beat 2 floor ended without Beat 3 -> back to Beat 0; press/buffer fires Beat 1.
                      /\ window_t' = 0
                      /\ window_pays' = 0
                      /\ early_pressed' = FALSE
                      /\ UNCHANGED beat_skip_pay
                      /\ TrackProgress(TRUE)
                      /\ IF pressed \/ bufAfterPress \/ holdRepeat THEN
                            /\ beat' = 1
                            /\ beat_t' = 0
                            /\ cooldown' = FloorTicks
                            /\ recover' = 0
                            /\ window' = "idle"
                            /\ buffered' = FALSE
                            /\ press_shots' = IF held THEN Min(baseShots + 1, 2) ELSE 0
                            /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                            /\ last_act' = IF jammed THEN "jam_fire" ELSE "plain_fire"
                         ELSE
                            /\ beat' = 0
                            /\ beat_t' = 0
                            /\ cooldown' = 0
                            /\ recover' = 0
                            /\ window' = "idle"
                            /\ buffered' = FALSE
                            /\ press_shots' = IF held THEN baseShots ELSE 0
                            /\ UNCHANGED shot_outside_play
                            /\ last_act' = "none"
                   ELSE
                      /\ beat' = 2
                      /\ beat_t' = 0
                      /\ cooldown' = cdNext
                      /\ recover' = recNext
                      /\ window' = wAfterPress
                      /\ window_t' = wtNext
                      /\ early_pressed' = earlyNext
                      /\ buffered' = (pressed /\ ~spentEarly /\ cdNext <= BufferTicks)
                      /\ press_shots' = IF held THEN baseShots ELSE 0
                      /\ UNCHANGED <<window_pays, shot_outside_play, beat_skip_pay>>
                      /\ TrackProgress(FALSE)
                      /\ last_act' = IF spentEarly THEN "early_spend" ELSE "none"
             ELSE
                LET readyNow == cdNext = 0 /\ recNext = 0
                    wCleared == IF beatAfterTimeout = 0 /\ readyNow /\ window \in {"hit", "spent"}
                                THEN "idle" ELSE window
                IN
                IF (pressed \/ buffered \/ holdRepeat) /\ readyNow THEN
                   /\ buffered' = FALSE
                   /\ press_shots' = IF held THEN Min(baseShots + 1, 2) ELSE 0
                   /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                   /\ TrackProgress(TRUE)
                   /\ IF ~GuardBeatsOrder THEN
                         \* Planted fault: skips straight to Beat 3 without 1 -> 2 -> 3 order.
                         /\ beat' = 0
                         /\ beat_t' = 0
                         /\ cooldown' = 0
                         /\ recover' = FloorTicks
                         /\ window' = "hit"
                         /\ window_t' = 0
                         /\ window_pays' = 1
                         /\ early_pressed' = FALSE
                         /\ beat_skip_pay' = TRUE
                         /\ last_act' = "tarn_beat3"
                      ELSE IF beatAfterTimeout = 1 THEN
                         \* Beat 2: opens Beat 3 window inside Beat 2 floor.
                         /\ beat' = 2
                         /\ beat_t' = 0
                         /\ cooldown' = Beat2FloorTicks
                         /\ recover' = 0
                         /\ window' = "waiting"
                         /\ window_t' = 0
                         /\ window_pays' = 0
                         /\ early_pressed' = FALSE
                         /\ UNCHANGED beat_skip_pay
                         /\ last_act' = IF jammed THEN "jam_fire" ELSE "plain_fire"
                      ELSE
                         \* Beat 1: starts combo timer.
                         /\ beat' = 1
                         /\ beat_t' = 0
                         /\ cooldown' = FloorTicks
                         /\ recover' = 0
                         /\ window' = "idle"
                         /\ window_t' = 0
                         /\ window_pays' = 0
                         /\ early_pressed' = FALSE
                         /\ UNCHANGED beat_skip_pay
                         /\ last_act' = IF jammed THEN "jam_fire" ELSE "plain_fire"
                ELSE
                   LET waitTicks == IF cdNext > recNext THEN cdNext ELSE recNext
                       bufNow == pressed /\ ~readyNow /\ waitTicks <= BufferTicks
                   IN
                   /\ beat' = beatAfterTimeout
                   /\ beat_t' = btAfterTimeout
                   /\ cooldown' = cdNext
                   /\ recover' = recNext
                   /\ window' = wCleared
                   /\ window_t' = 0
                   /\ window_pays' = IF beatAfterTimeout = 0 /\ readyNow THEN 0 ELSE window_pays
                   /\ early_pressed' = IF beatAfterTimeout = 0 /\ readyNow THEN FALSE ELSE early_pressed
                   /\ buffered' = bufNow
                   /\ press_shots' = IF held THEN baseShots ELSE 0
                   /\ UNCHANGED <<shot_outside_play, beat_skip_pay>>
                   /\ TrackProgress(readyNow)
                   /\ last_act' = "none"

\* ---------------------------------------------------------------------------
\* 5. Tally ("tally", trigger "stamp"): weapon_driver.gd _step_stamp /
\*    commit_stamp + combat.gd _step_cards / _step_roll_restore / _run_balance
\* ---------------------------------------------------------------------------
StepTally(inp) ==
    /\ weapon = "tally"
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           cdNext == IF jamFrozen THEN cooldown
                     ELSE IF cooldown > 0 THEN cooldown - 1 ELSE 0
           wtNext == IF jamFrozen THEN window_t
                     ELSE IF window \in {"waiting", "open"} THEN Min(window_t + 1, WindowClose + 2)
                     ELSE 0
           wNow ==
               IF window \in {"idle", "spent"} THEN window
               ELSE IF wtNext < WindowOpen THEN "waiting"
               ELSE IF wtNext <= WindowClose + 1 THEN "open"
               ELSE "spent"
           baseShots == IF pressed THEN 0
                        ELSE IF held THEN press_shots ELSE 0
           holdRepeat == held /\ ~pressed /\ ~GuardPressNoRepeat
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, recover, hold_t, chamber,
                      hot_rounds, reloading, reload_t, charge_armed, charging,
                      charge, instant_charge, lob_charging, snap_hold_lock, live_charge,
                      beat, beat_t, lane_painted, stuck_holding,
                      proc_mutated_driver, snap_opened_gauge, beat_skip_pay>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, buffered, window, window_t, pressure,
                            press_shots, window_pays, early_pressed,
                            shot_outside_play, grew_without_roll, last_cost,
                            last_refund>>
          ELSE IF pressed /\ cdNext > 0 THEN
             \* Press during floor: before window opens spends window; near ready buffers plain cast.
             LET spentEarly == (wNow = "waiting")
                 wAfterPress ==
                     IF spentEarly THEN
                         IF GuardEarlyPressSpends THEN "spent" ELSE "waiting"
                     ELSE wNow
             IN
             /\ cooldown' = cdNext
             /\ window' = wAfterPress
             /\ window_t' = IF spentEarly /\ GuardEarlyPressSpends THEN 0 ELSE wtNext
             /\ window_pays' = 0
             /\ early_pressed' = (early_pressed \/ spentEarly)
             /\ buffered' = (cdNext <= BufferTicks)
             /\ press_shots' = IF held THEN baseShots ELSE 0
             /\ TrackProgress(FALSE)
             /\ last_act' = IF spentEarly THEN "early_spend" ELSE "none"
             /\ UNCHANGED <<pressure, shot_outside_play, grew_without_roll,
                            last_cost, last_refund>>
          ELSE IF (pressed \/ buffered \/ holdRepeat) /\ cdNext = 0 /\ pressure >= CastCost THEN
             LET isStamp == pressed /\ wNow = "open"
                 ref == IF ~isStamp THEN 0
                        ELSE IF GuardRefundBound THEN StampRefund
                        ELSE CastCost + 1
                 rawP == pressure - CastCost + ref
                 newP == IF GuardRefundBound THEN Min(rawP, MaxPressure) ELSE rawP
             IN
             /\ cooldown' = FloorTicks
             /\ buffered' = FALSE
             /\ pressure' = newP
             /\ window' = "waiting"
             /\ window_t' = 0
             /\ window_pays' = IF isStamp THEN 1 ELSE 0
             /\ early_pressed' = IF isStamp THEN early_pressed ELSE FALSE
             /\ press_shots' = IF held THEN Min(baseShots + 1, 2) ELSE 0
             /\ last_cost' = CastCost
             /\ last_refund' = ref
             /\ grew_without_roll' = (grew_without_roll \/ (newP > pressure))
             /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
             /\ TrackProgress(TRUE)
             /\ last_act' = IF isStamp THEN "stamp_refund"
                            ELSE IF jammed THEN "jam_fire" ELSE "plain_fire"
          ELSE
             /\ cooldown' = cdNext
             /\ buffered' = FALSE
             /\ window' = wNow
             /\ window_t' = IF wNow \in {"waiting", "open"} THEN wtNext ELSE 0
             /\ window_pays' = 0
             /\ early_pressed' = IF wNow = "spent" THEN early_pressed ELSE FALSE
             /\ press_shots' = IF held THEN baseShots ELSE 0
             /\ TrackProgress(cdNext = 0)
             /\ last_act' = "none"
             /\ UNCHANGED <<pressure, shot_outside_play, grew_without_roll,
                            last_cost, last_refund>>

\* Tally rolling at cruise refills fractional pressure (+0.5 = +1 half-unit) up to MaxPressure.
TallyRollRefill ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "tally"
    /\ pressure < MaxPressure
    /\ pressure' = pressure + 1
    /\ just_crossed_boundary' = FALSE
    /\ last_act' = "none"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   hold_t, buffered, chamber, hot_rounds, reloading, reload_t,
                   charge_armed, charging, charge, instant_charge, lob_charging, snap_hold_lock,
                   live_charge, beat, beat_t, lane_painted, window, window_t,
                   after_interrupt, steps_since_interrupt, press_shots,
                   window_pays, early_pressed, shot_outside_play, stuck_holding,
                   proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                   grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* 6. Cannon ("cannon", trigger "lock"): weapon_driver.gd _step_lock /
\*    _release_lock + combat.gd _step_cannon_paint / _fire_cannon_lane
\* ---------------------------------------------------------------------------
StepCannon(inp) ==
    /\ weapon = "cannon"
    /\ InPlayTick
    /\ LET pressed == inp \in {"press_tap", "press_hold"}
           held == inp \in {"press_hold", "hold"}
           released == inp = "release"
           jamFrozen == jammed /\ ~GuardJamNoFreeze
           recNext == IF jamFrozen THEN recover
                      ELSE IF recover > 0 THEN recover - 1 ELSE 0
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, chamber,
                      hot_rounds, reloading, reload_t, charge_armed, charging,
                      charge, instant_charge, lob_charging, snap_hold_lock, live_charge,
                      beat, beat_t, pressure, press_shots, window_pays,
                      early_pressed, stuck_holding, proc_mutated_driver,
                      snap_opened_gauge, beat_skip_pay, grew_without_roll,
                      last_cost, last_refund>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<recover, hold_t, buffered, lane_painted, window,
                            window_t, shot_outside_play>>
          ELSE IF ~lane_painted THEN
             LET wIdle == IF recNext = 0 /\ window = "hit" THEN "idle" ELSE window IN
             IF (pressed \/ buffered) /\ recNext = 0 THEN
                IF ~held \/ released THEN
                   \* Instant tap (or buffered with button up): paints and immediately releases Pulse.
                   /\ lane_painted' = FALSE
                   /\ hold_t' = 0
                   /\ buffered' = FALSE
                   /\ recover' = FloorTicks
                   /\ window' = "idle"
                   /\ window_t' = 0
                   /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                   /\ TrackProgress(TRUE)
                   /\ last_act' = "cannon_pulse"
                ELSE
                   \* Press & hold: paints ground lane, brackets start closing.
                   /\ lane_painted' = TRUE
                   /\ hold_t' = 0
                   /\ buffered' = FALSE
                   /\ recover' = 0
                   /\ window' = "waiting"
                   /\ window_t' = 0
                   /\ UNCHANGED shot_outside_play
                   /\ TrackProgress(TRUE)
                   /\ last_act' = "none"
             ELSE
                LET bufNow == pressed /\ recNext > 0 /\ recNext <= BufferTicks IN
                /\ lane_painted' = FALSE
                /\ hold_t' = 0
                /\ buffered' = bufNow
                /\ recover' = recNext
                /\ window' = wIdle
                /\ window_t' = 0
                /\ UNCHANGED shot_outside_play
                /\ TrackProgress(recNext = 0)
                /\ last_act' = "none"
          ELSE
             \* Lane is painted: hold closes brackets through Pulse -> Rail -> Barrage; release fires.
             IF held /\ ~released THEN
                LET htNext == Min(hold_t + 1, LockHoldMax)
                    wBand == IF htNext < WindowOpen THEN "waiting"
                             ELSE IF htNext <= WindowClose THEN "open"
                             ELSE "spent"
                IN
                /\ lane_painted' = TRUE
                /\ hold_t' = htNext
                /\ buffered' = FALSE
                /\ recover' = recNext
                /\ window' = wBand
                /\ window_t' = htNext
                /\ UNCHANGED shot_outside_play
                /\ TrackProgress(recNext = 0)
                /\ last_act' = "none"
             ELSE
                LET isRail == hold_t >= WindowOpen /\ hold_t <= WindowClose
                    isBarrage == hold_t > WindowClose
                IN
                /\ lane_painted' = FALSE
                /\ hold_t' = 0
                /\ buffered' = FALSE
                /\ recover' = FloorTicks
                /\ window' = IF isRail THEN "hit" ELSE "idle"
                /\ window_t' = 0
                /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                /\ TrackProgress(recNext = 0)
                /\ last_act' = IF isRail THEN "cannon_rail"
                               ELSE IF isBarrage THEN "cannon_barrage"
                               ELSE "cannon_pulse"

\* ---------------------------------------------------------------------------
\* Procs: combat.gd _proc_volley -> _fire(weapon, "item_proc") /
\*        _run_balance(..., "item_proc") / _fire_cannon_lane(..., "item_proc")
\* ---------------------------------------------------------------------------
ProcVolley ==
    /\ InPlayTick
    /\ just_crossed_boundary' = FALSE
    /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
    /\ IF GuardProcIsolated THEN
          /\ proc_mutated_driver' = proc_mutated_driver
          /\ last_act' = "proc_no_touch"
          /\ UNCHANGED <<cooldown, chamber, hot_rounds, window, buffered,
                         charge, charging, charge_armed, lob_charging,
                         snap_hold_lock, live_charge, beat, beat_t,
                         lane_painted>>
       ELSE
          \* Planted fault: proc touches WeaponDriver (spends chamber or resets cooldown).
          /\ proc_mutated_driver' = TRUE
          /\ chamber' = IF chamber > 0 THEN chamber - 1 ELSE chamber
          /\ cooldown' = FloorTicks
          /\ last_act' = "none"
          /\ UNCHANGED <<hot_rounds, window, buffered, charge, charging,
                         charge_armed, lob_charging, snap_hold_lock,
                         live_charge, beat, beat_t, lane_painted>>
    /\ UNCHANGED <<flow, paused, jammed, weapon, recover, press_held, hold_t,
                   reloading, reload_t, instant_charge, window_t, pressure, after_interrupt,
                   steps_since_interrupt, press_shots, window_pays,
                   early_pressed, stuck_holding, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* Interruptions (PILOT-CADENCE.md §2.3)
\* ---------------------------------------------------------------------------

\* Enemy jam pulse: silences slots 2 & 3 only; never freezes weapon_driver.
ToggleJam ==
    /\ flow = "play" /\ ~paused
    /\ LET nextJam == ~jammed IN
       /\ jammed' = nextJam
       /\ just_crossed_boundary' = FALSE
       /\ IF nextJam /\ ~DriverReady /\ after_interrupt = "none" THEN
             /\ after_interrupt' = "jam"
             /\ steps_since_interrupt' = 0
          ELSE
             /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
       /\ last_act' = "none"
       /\ UNCHANGED <<flow, paused, weapon, cooldown, recover, press_held,
                      hold_t, buffered, chamber, hot_rounds, reloading,
                      reload_t, charge_armed, charging, charge, instant_charge, lob_charging,
                      snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                      window, window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, stuck_holding,
                      proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                      grew_without_roll, last_cost, last_refund>>

\* Pause / Unpause: pauses tree timers without resetting them.
TogglePause ==
    /\ flow = "play"
    /\ LET nextPaused == ~paused IN
       /\ paused' = nextPaused
       /\ just_crossed_boundary' = FALSE
       /\ IF ~nextPaused /\ ~DriverReady /\ after_interrupt = "none" THEN
             /\ after_interrupt' = "pause"
             /\ steps_since_interrupt' = 0
          ELSE
             /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
       /\ last_act' = "none"
       /\ UNCHANGED <<flow, jammed, weapon, cooldown, recover, press_held,
                      hold_t, buffered, chamber, hot_rounds, reloading,
                      reload_t, charge_armed, charging, charge, instant_charge, lob_charging,
                      snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                      window, window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, stuck_holding,
                      proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                      grew_without_roll, last_cost, last_refund>>

\* Ultimate starts: combat.gd -> weapon_driver.interrupt(INTERRUPT_ULTIMATE)
\* + _clear_cannon_paint() + cancel weapon gauge.
\* Drops charge, lob gauge, snap lock, painted lane, beat count, and buffer;
\* spends waiting/open window; keeps reload running; never fires a shot.
InterruptUltimate ==
    /\ flow = "play" /\ ~paused
    /\ just_crossed_boundary' = FALSE
    /\ LET holdLeaked == (~GuardInterruptDropsHold /\ (charge_armed \/ charging \/ lob_charging))
           paintLeaked == (~GuardLockInterruptClears /\ lane_painted)
       IN
       /\ IF GuardInterruptDropsHold THEN
             /\ charge' = 0
             /\ charging' = FALSE
             /\ charge_armed' = FALSE
             /\ instant_charge' = FALSE
             /\ lob_charging' = FALSE
             /\ snap_hold_lock' = FALSE
          ELSE
             /\ UNCHANGED <<charge, charging, charge_armed, instant_charge, lob_charging, snap_hold_lock>>
       /\ IF GuardLockInterruptClears THEN
             /\ lane_painted' = FALSE
          ELSE
             /\ UNCHANGED lane_painted
       /\ IF GuardInterruptDropsHold /\ (weapon /= "cannon" \/ GuardLockInterruptClears) THEN
             /\ hold_t' = 0
             /\ buffered' = FALSE
          ELSE
             /\ UNCHANGED <<hold_t, buffered>>
       /\ stuck_holding' = (stuck_holding \/ holdLeaked \/ paintLeaked)
    /\ beat' = 0
    /\ beat_t' = 0
    /\ window' = IF window \in {"waiting", "open"} THEN "spent" ELSE window
    /\ window_t' = IF window \in {"waiting", "open"} THEN 0 ELSE window_t
    /\ IF ~DriverReady THEN
          /\ after_interrupt' = "ult"
          /\ steps_since_interrupt' = 0
       ELSE
          /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
    /\ last_act' = IF weapon = "cannon" /\ lane_painted THEN "cannon_interrupt" ELSE "ult_interrupt"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   chamber, hot_rounds, reloading, reload_t, live_charge,
                   pressure, press_shots, window_pays, early_pressed,
                   shot_outside_play, proc_mutated_driver, snap_opened_gauge,
                   beat_skip_pay, grew_without_roll, last_cost, last_refund>>

\* Sable mount / dismount: combat.gd -> weapon_driver.interrupt(INTERRUPT_MOUNT)
\* + _switch_weapon mount_swap (drops charge & buffer, preserves cooldown & recover).
InterruptMount ==
    /\ flow = "play" /\ ~paused
    /\ weapon \in {"sable_ball", "sable_mount"}
    /\ LET nextW == IF weapon = "sable_ball" THEN "sable_mount" ELSE "sable_ball" IN
       /\ weapon' = nextW
       /\ just_crossed_boundary' = FALSE
       /\ IF GuardInterruptDropsHold THEN
             /\ charge' = 0
             /\ charging' = FALSE
             /\ charge_armed' = FALSE
             /\ hold_t' = 0
             /\ buffered' = FALSE
             /\ stuck_holding' = stuck_holding
          ELSE
             /\ stuck_holding' = (stuck_holding \/ charge_armed \/ charging)
             /\ UNCHANGED <<charge, charging, charge_armed, hold_t, buffered>>
       /\ IF ~DriverReady THEN
             /\ after_interrupt' = "mount"
             /\ steps_since_interrupt' = 0
          ELSE
             /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
       /\ last_act' = IF charge_armed \/ charging THEN "mount_drop" ELSE "none"
       /\ UNCHANGED <<flow, paused, jammed, cooldown, recover, press_held,
                      chamber, hot_rounds, reloading, reload_t, instant_charge, lob_charging,
                      snap_hold_lock, live_charge, beat, beat_t, lane_painted,
                      window, window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, proc_mutated_driver,
                      snap_opened_gauge, beat_skip_pay, grew_without_roll,
                      last_cost, last_refund>>

\* Weapon swap (relic / tree pick / pilot change): old state dropped, new weapon at rest.
SwapWeapon ==
    /\ flow = "play" /\ ~paused
    /\ \E nextW \in BaseWeapons :
        /\ TriggerOf(nextW) /= TriggerOf(weapon)
        /\ weapon' = nextW
        /\ ResetDriver(nextW)
        /\ pressure' = IF nextW = "tally" THEN MaxPressure ELSE 0
        /\ just_crossed_boundary' = FALSE
        /\ after_interrupt' = "none"
        /\ steps_since_interrupt' = 0
        /\ last_cost' = 0
        /\ last_refund' = 0
        /\ last_act' = "none"
        /\ UNCHANGED <<flow, paused, jammed, shot_outside_play, stuck_holding,
                       proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                       grew_without_roll>>

\* ---------------------------------------------------------------------------
\* Attempt boundaries (PILOT-CADENCE.md §2.3)
\* ---------------------------------------------------------------------------

\* Wired boundaries: stage_entry, stage_retry, arena_entry, arena_retry, lap,
\* death, new_run, continue. Each calls weapon_driver.reset() in combat.gd.
BoundaryWired ==
    /\ \E b \in WiredBoundaries :
        /\ (b \in {"stage_entry", "stage_retry", "arena_entry", "arena_retry", "lap", "death"}
                => flow = "play")
        /\ (b \in {"new_run", "continue"} => flow \in {"play", "dead", "title"})
        /\ flow' = IF b = "death" THEN "dead" ELSE "play"
        /\ paused' = FALSE
        /\ jammed' = FALSE
        /\ just_crossed_boundary' = TRUE
        /\ IF GuardBoundaryReset THEN
              /\ ResetDriver(weapon)
              /\ after_interrupt' = "none"
              /\ steps_since_interrupt' = 0
           ELSE
              \* Planted fault: attempt boundary omits weapon_driver.reset().
              /\ UNCHANGED <<cooldown, recover, press_held, hold_t, buffered,
                             chamber, hot_rounds, reloading, reload_t,
                             charge_armed, charging, charge, instant_charge, lob_charging,
                             snap_hold_lock, live_charge, beat, beat_t,
                             lane_painted, window, window_t, press_shots,
                             window_pays, early_pressed, after_interrupt,
                             steps_since_interrupt>>
        /\ pressure' = IF weapon = "tally" THEN MaxPressure ELSE 0
        /\ last_cost' = 0
        /\ last_refund' = 0
        /\ last_act' = "boundary_reset"
        /\ UNCHANGED <<weapon, shot_outside_play, stuck_holding,
                       proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                       grew_without_roll>>

\* Quit to title: flow.show_title() / summary close.
\* WC-1 closed by W46-FIX1 PR #1229: combat.gd calls weapon_driver.reset() and
\* _clear_cannon_paint() on run_ended and flow_changed("summary" | "title").
QuitToTitle ==
    /\ (flow = "dead" \/ (AllowDirectTitleQuit /\ flow = "play"))
    /\ flow' = "title"
    /\ paused' = FALSE
    /\ jammed' = FALSE
    /\ just_crossed_boundary' = TRUE
    /\ IF GuardTitleReset THEN
          /\ ResetDriver(weapon)
          /\ after_interrupt' = "none"
          /\ steps_since_interrupt' = 0
       ELSE
          /\ UNCHANGED <<cooldown, recover, press_held, hold_t, buffered,
                         chamber, hot_rounds, reloading, reload_t,
                         charge_armed, charging, charge, instant_charge, lob_charging,
                         snap_hold_lock, live_charge, beat, beat_t,
                         lane_painted, window, window_t, press_shots,
                         window_pays, early_pressed, after_interrupt,
                         steps_since_interrupt>>
    /\ last_cost' = 0
    /\ last_refund' = 0
    /\ last_act' = "boundary_reset"
    /\ UNCHANGED <<weapon, pressure, shot_outside_play, stuck_holding,
                   proc_mutated_driver, snap_opened_gauge, beat_skip_pay,
                   grew_without_roll>>

\* ---------------------------------------------------------------------------
\* Next-state relation & specification
\* ---------------------------------------------------------------------------
Next ==
    \/ (\E inp \in AllowedInputs :
            StepRivet(inp) \/ StepSable(inp) \/ StepKest(inp)
            \/ StepTarn(inp) \/ StepTally(inp) \/ StepCannon(inp))
    \/ TopUpCylinder
    \/ HotReloadCylinder
    \/ ArmInstantCharge
    \/ KestDetonationLine
    \/ KestChargePlainDetonate
    \/ TallyRollRefill
    \/ ProcVolley
    \/ ToggleJam
    \/ TogglePause
    \/ InterruptUltimate
    \/ InterruptMount
    \/ SwapWeapon
    \/ BoundaryWired
    \/ QuitToTitle

Spec == Init /\ [][Next]_vars

\* ---------------------------------------------------------------------------
\* The six player-facing invariants (PILOT-CADENCE.md §8, E1-17, E2-08)
\* ---------------------------------------------------------------------------

\* 1. No shot leaves while outside play (in_play = FALSE or paused).
NoShotOutsidePlay == ~shot_outside_play

\* 2. Charge, reload, hot rounds, lob gauge, snap lock, beat count, painted lane,
\*    window, buffer, and chamber are at rest immediately after every boundary.
RestAfterBoundary == just_crossed_boundary => AtRest

\* 3. From any state, a jam, ultimate, mount/dismount, weapon swap, or pause
\*    returns the trigger to ready in bounded steps, never stuck holding/painted.
BoundedReadyAfterInterrupt ==
    /\ steps_since_interrupt <= MaxReadyBound
    /\ ~stuck_holding

\* 4. One press gives at most one volley on press/beats/stamp weapons, Kest's
\*    snap press never opens the lob gauge while held, and procs never mutate
\*    WeaponDriver state.
OneVolleyPerPress ==
    /\ press_shots <= 1
    /\ ~proc_mutated_driver
    /\ ~snap_opened_gauge

\* 5. Every timing window (Rivet notch, Kest snap + Detonation Line, Tarn Beat 3,
\*    Tally PAID stamp) pays at most once per cycle, early press spends it, and
\*    Tarn Beat 3 can only pay in 1 -> 2 -> 3 order.
WindowPaysAtMostOnce ==
    /\ window_pays <= 1
    /\ (early_pressed => window_pays = 0)
    /\ ~beat_skip_pay

\* 6. Tally's stamp refund never exceeds the cast cost (refund <= cost), so
\*    pressure stays within [0, max] and cannot grow without rolling.
RefundNeverExceedsSpend ==
    /\ pressure \in 0..MaxPressure
    /\ last_refund <= last_cost
    /\ ~grew_without_roll

\* ---------------------------------------------------------------------------
\* Reachability probes (each MUST fail on weaponcadence-reach-*.cfg)
\* ---------------------------------------------------------------------------
ProbePlainFire       == last_act /= "plain_fire"
ProbeReload          == ~reloading
ProbeNotchHit        == last_act /= "notch_hit"
ProbeEarlySpend      == ~(weapon = "rivet" /\ reloading /\ early_pressed /\ window = "spent")
ProbeTopUp           == last_act /= "top_up"
ProbeSpark           == last_act /= "spark"
ProbeChargedBolt     == last_act /= "charged_bolt"
ProbeMountDrop       == last_act /= "mount_drop"
ProbeUltInterrupt    == last_act /= "ult_interrupt"
ProbeBoundaryReset   == ~just_crossed_boundary
ProbeJamFire         == last_act /= "jam_fire"
ProbeProcNoTouch     == last_act /= "proc_no_touch"
ProbeStampRefund     == last_act /= "stamp_refund"
ProbeKestThrow       == last_act /= "kest_throw"
ProbeKestSnap        == last_act /= "kest_snap"
ProbeKestDetLine     == last_act /= "kest_detline"
ProbeTarnBeat3       == last_act /= "tarn_beat3"
ProbeCannonPulse     == last_act /= "cannon_pulse"
ProbeCannonRail      == last_act /= "cannon_rail"
ProbeCannonBarrage   == last_act /= "cannon_barrage"
ProbeCannonInterrupt == last_act /= "cannon_interrupt"
=============================================================================
