--------------------------- MODULE WeaponCadence ---------------------------
(* Weapon trigger and cadence state machine (PILOT-CADENCE.md sections 2, 3.1,
   3.2, 3.5 and 8; ruling ek; Wave 46 unit E1-17):
   sketches/core-loop/src/combat/weapon_driver.gd and
   sketches/core-loop/src/combat/combat.gd.

   Models the three cadence families required by E1-17:
   - Rivet ("rivet", trigger "press"): one round per press, cylinder reload
     with a single-press notch window (early press spends it), 1-tick input
     buffer, Skid/Line Drive top-up (ends reload or tops up cylinder with
     plain rounds behind loaded hot rounds).
   - Sable ("sable_ball" / "sable_mount", trigger "tap_charge"): immediate
     spark on press, hold past threshold charges a bolt (holds at full without
     decay or auto-fire), release >= min fires charged bolt + recover; mount
     and dismount drop charge with no bolt while keeping spark floor/recover.
   - Tally ("tally", trigger "stamp"): Balance Due costs CastCost half-pressure
     units (2 = 1.0), opens a beat window where PAID refunds StampRefund
     (1 = 0.5 <= CastCost); rolling refills pressure up to MaxPressure (6 = 3.0).

   Also models:
   - Play gating (flow.in_play() and pause tree): no shot leaves outside play.
   - Attempt boundaries: stage entry, stage retry, arena entry, arena retry,
     victory lap, death, new run, Continue, and quit to title.
   - Interruptions: jam pulse (never freezes trigger/reload/charge), ultimate
     (drops charge, spends waiting/open window, keeps reload running), mount /
     dismount (drops charge, keeps floor/recover), weapon swap (resets new
     weapon to rest), and pause / unpause.
   - Procs (item_proc / _proc_volley): bypass WeaponDriver completely without
     spending a round, touching a window, or altering reload/charge/cooldown. *)
EXTENDS Naturals

CONSTANTS
    Mag,                      \* Rivet cylinder size (2 stands for 6)
    FloorTicks,               \* shot/spark/cast floor in ticks (2)
    BufferTicks,              \* input buffer span before ready (1)
    ReloadTicks,              \* Rivet reload ticks (4: 1=wait, 2=open, 3=bufferable, 4=done)
    WindowOpen,               \* tick when reload notch / stamp beat opens (2)
    WindowClose,              \* tick when reload notch closes (2; stamp closes at WindowClose+1)
    RecoverTicks,             \* Sable post-bolt recover ticks (1)
    ChargeMax,                \* Sable charge steps (2: 0=under-min, 1=partial, 2=full)
    MaxPressure,              \* Tally max pressure in half-units (6 = 3.0)
    CastCost,                 \* Tally cast cost in half-units (2 = 1.0)
    StampRefund,              \* Tally PAID stamp refund in half-units (1 = 0.5)
    MaxReadyBound,            \* bounded ticks to ready after any interrupt (4 = ReloadTicks)
    GuardPlayGate,            \* TRUE: combat._physics_process gates on in_play() and ~paused
    GuardBoundaryReset,       \* TRUE: wired attempt boundaries call weapon_driver.reset()
    AllowDirectTitleQuit,     \* FALSE on today (documents open finding WC-1: win/lap -> title)
    GuardTitleReset,          \* TRUE: quit_to_title from play/win resets weapon_driver
    GuardJamNoFreeze,         \* TRUE: jam pulse never freezes trigger, reload, or charge
    GuardInterruptDropsHold,  \* TRUE: ultimate/mount interrupts drop charge_armed/charging/buffer
    GuardPressNoRepeat,       \* TRUE: holding fire on a press weapon fires at most once
    GuardProcIsolated,        \* TRUE: item_proc / _proc_volley never mutates WeaponDriver state
    GuardEarlyPressSpends,    \* TRUE: early press before notch sets window = "spent"
    GuardWindowOnce,          \* TRUE: hitting notch ends reload and marks window = "hit"
    GuardRefundBound          \* TRUE: Tally stamp refund <= CastCost, bounded in 0..MaxPressure

Weapons == {"rivet", "sable_ball", "sable_mount", "tally"}
Flows == {"play", "dead", "title"}
Windows == {"idle", "waiting", "open", "spent", "hit"}
InterruptKinds == {"none", "jam", "ult", "mount", "swap", "pause"}
WiredBoundaries == {"stage_entry", "stage_retry", "arena_entry", "arena_retry",
                    "lap", "death", "new_run", "continue"}
Acts == {"none", "plain_fire", "reload", "notch_hit", "early_spend", "top_up",
         "spark", "charged_bolt", "mount_drop", "ult_interrupt", "boundary_reset",
         "jam_fire", "proc_no_touch", "stamp_refund"}

TriggerOf(w) ==
    IF w = "rivet" THEN "press"
    ELSE IF w \in {"sable_ball", "sable_mount"} THEN "tap_charge"
    ELSE "stamp"

Min(a, b) == IF a < b THEN a ELSE b

VARIABLES
    flow,                  \* "play" | "dead" | "title"
    paused,                \* BOOLEAN (Godot scene tree pause)
    jammed,                \* BOOLEAN (enemy field pulse silencing slots 2 & 3 only)
    weapon,                \* active weapon id
    cooldown,              \* 0..FloorTicks
    recover,               \* 0..RecoverTicks (Sable post-bolt recover)
    press_held,            \* BOOLEAN (fire button held across ticks)
    hold_t,                \* 0..1 (Sable tap threshold elapsed while charge_armed)
    buffered,              \* BOOLEAN (1-press input buffer)
    chamber,               \* 0..Mag (Rivet loaded rounds; 0 for non-press)
    hot_rounds,            \* 0..Mag (Rivet hot rounds remaining at front of cylinder)
    reloading,             \* BOOLEAN (Rivet reload in progress)
    reload_t,              \* 0..ReloadTicks
    charge_armed,          \* BOOLEAN (Sable hold armed by spark press)
    charging,              \* BOOLEAN (Sable charge actively filling)
    charge,                \* 0..ChargeMax (Sable charge level)
    window,                \* "idle" | "waiting" | "open" | "spent" | "hit"
    window_t,              \* 0..(WindowClose + 2) (Tally beat window elapsed)
    pressure,              \* 0..(MaxPressure + 2) (Tally pressure in half-units)
    just_crossed_boundary, \* TRUE immediately after an attempt boundary
    after_interrupt,       \* "none" | "jam" | "ult" | "mount" | "swap" | "pause"
    steps_since_interrupt, \* unpaused play ticks since interrupt while ~DriverReady
    press_shots,           \* 0..2 (volleys fired during current press on Rivet)
    window_pays,           \* 0..2 (notch payouts in current Rivet reload cycle)
    early_pressed,         \* BOOLEAN (early press happened before Rivet notch opened)
    shot_outside_play,     \* latch: a shot left while flow /= "play" or paused
    stuck_holding,         \* latch: an interrupt left charge_armed/charging stuck
    proc_mutated_driver,   \* latch: a proc mutated WeaponDriver state
    grew_without_roll,     \* latch: a Tally cast ended with pressure' > pressure
    last_cost,             \* last Tally cast cost
    last_refund,           \* last Tally stamp refund
    last_act               \* tag for reachability probes

vars == <<flow, paused, jammed, weapon, cooldown, recover, press_held, hold_t,
          buffered, chamber, hot_rounds, reloading, reload_t, charge_armed,
          charging, charge, window, window_t, pressure, just_crossed_boundary,
          after_interrupt, steps_since_interrupt, press_shots, window_pays,
          early_pressed, shot_outside_play, stuck_holding, proc_mutated_driver,
          grew_without_roll, last_cost, last_refund, last_act>>

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
    /\ window = "idle"
    /\ window_t = 0
    /\ (TriggerOf(weapon) = "press" => chamber = Mag)

TypeOK ==
    /\ flow \in Flows
    /\ paused \in BOOLEAN
    /\ jammed \in BOOLEAN
    /\ weapon \in Weapons
    /\ cooldown \in 0..FloorTicks
    /\ recover \in 0..RecoverTicks
    /\ press_held \in BOOLEAN
    /\ hold_t \in 0..1
    /\ buffered \in BOOLEAN
    /\ chamber \in 0..Mag
    /\ hot_rounds \in 0..Mag
    /\ hot_rounds <= chamber
    /\ reloading \in BOOLEAN
    /\ reload_t \in 0..ReloadTicks
    /\ charge_armed \in BOOLEAN
    /\ charging \in BOOLEAN
    /\ charge \in 0..ChargeMax
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
    /\ window' = "idle"
    /\ window_t' = 0
    /\ press_shots' = 0
    /\ window_pays' = 0
    /\ early_pressed' = FALSE

Init ==
    /\ flow = "play"
    /\ paused = FALSE
    /\ jammed = FALSE
    /\ weapon \in {"rivet", "sable_ball", "tally"}
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
\* Rivet ("rivet", trigger "press") tick: weapon_driver.gd _step_press
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
                      charge_armed, charging, charge, window_t, pressure,
                      stuck_holding, proc_mutated_driver, grew_without_roll,
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
                   buffered, charge_armed, charging, charge, window_t, pressure,
                   press_shots, shot_outside_play, stuck_holding,
                   proc_mutated_driver, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* Sable ("sable_ball" / "sable_mount", trigger "tap_charge"): _step_tap_charge
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
                      reloading, reload_t, window, window_t, pressure,
                      press_shots, window_pays, early_pressed, stuck_holding,
                      proc_mutated_driver, grew_without_roll, last_cost, last_refund>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, recover, hold_t, buffered, charge_armed,
                            charging, charge, shot_outside_play>>
          ELSE
             LET fireSpark == readyNow /\ (pressed \/ buffered)
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
             IF armedAfterSpark THEN
                IF held /\ ~released THEN
                   IF fireSpark THEN
                      /\ cooldown' = cdAfterSpark
                      /\ recover' = recNext
                      /\ buffered' = bufAfterSpark
                      /\ charge_armed' = armedAfterSpark
                      /\ charging' = chargingAfterSpark
                      /\ charge' = chargeAfterSpark
                      /\ hold_t' = holdAfterSpark
                      /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
                      /\ TrackProgress(TRUE)
                      /\ last_act' = IF jammed THEN "jam_fire" ELSE "spark"
                   ELSE
                      \* Hold advances past tap threshold (1 tick) then fills charge to ChargeMax.
                      /\ cooldown' = cdAfterSpark
                      /\ recover' = recNext
                      /\ buffered' = bufAfterSpark
                      /\ charge_armed' = TRUE
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
                /\ shot_outside_play' = (shot_outside_play \/ (fireSpark /\ OutsidePlay))
                /\ TrackProgress(readyNow)
                /\ last_act' = IF fireSpark THEN (IF jammed THEN "jam_fire" ELSE "spark") ELSE "none"

\* ---------------------------------------------------------------------------
\* Tally ("tally", trigger "stamp"): PILOT-CADENCE.md §3.5 + pattern.gd refund
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
       IN
       /\ press_held' = held
       /\ just_crossed_boundary' = FALSE
       /\ UNCHANGED <<flow, paused, jammed, weapon, recover, hold_t, chamber,
                      hot_rounds, reloading, reload_t, charge_armed, charging,
                      charge, press_shots, window_pays, early_pressed,
                      stuck_holding, proc_mutated_driver>>
       /\ IF jamFrozen THEN
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<cooldown, buffered, window, window_t, pressure,
                            shot_outside_play, grew_without_roll, last_cost,
                            last_refund>>
          ELSE IF pressed /\ cdNext > 0 THEN
             \* Press during floor: before window opens spends window; near ready buffers plain cast.
             /\ cooldown' = cdNext
             /\ window' = IF wNow = "waiting" THEN "spent" ELSE wNow
             /\ window_t' = IF wNow = "waiting" THEN 0 ELSE wtNext
             /\ buffered' = (cdNext <= BufferTicks)
             /\ TrackProgress(FALSE)
             /\ last_act' = "none"
             /\ UNCHANGED <<pressure, shot_outside_play, grew_without_roll,
                            last_cost, last_refund>>
          ELSE IF (pressed \/ buffered) /\ cdNext = 0 /\ pressure >= CastCost THEN
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
             /\ TrackProgress(cdNext = 0)
             /\ last_act' = "none"
             /\ UNCHANGED <<pressure, shot_outside_play, grew_without_roll,
                            last_cost, last_refund>>

\* Tally rolling at cruise refills half a pressure unit up to MaxPressure.
TallyRollRefill ==
    /\ flow = "play" /\ ~paused
    /\ weapon = "tally"
    /\ pressure < MaxPressure
    /\ pressure' = pressure + 1
    /\ just_crossed_boundary' = FALSE
    /\ last_act' = "none"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   hold_t, buffered, chamber, hot_rounds, reloading, reload_t,
                   charge_armed, charging, charge, window, window_t,
                   after_interrupt, steps_since_interrupt, press_shots,
                   window_pays, early_pressed, shot_outside_play, stuck_holding,
                   proc_mutated_driver, grew_without_roll, last_cost, last_refund>>

\* ---------------------------------------------------------------------------
\* Procs: combat.gd _proc_volley -> _fire(weapon, "item_proc")
\* ---------------------------------------------------------------------------
ProcVolley ==
    /\ InPlayTick
    /\ just_crossed_boundary' = FALSE
    /\ shot_outside_play' = (shot_outside_play \/ OutsidePlay)
    /\ IF GuardProcIsolated THEN
          /\ proc_mutated_driver' = proc_mutated_driver
          /\ last_act' = "proc_no_touch"
          /\ UNCHANGED <<cooldown, chamber, hot_rounds, window, buffered,
                         charge, charging, charge_armed>>
       ELSE
          \* Planted fault: proc touches WeaponDriver (spends chamber or resets cooldown).
          /\ proc_mutated_driver' = TRUE
          /\ chamber' = IF chamber > 0 THEN chamber - 1 ELSE chamber
          /\ cooldown' = FloorTicks
          /\ last_act' = "none"
          /\ UNCHANGED <<hot_rounds, window, buffered, charge, charging, charge_armed>>
    /\ UNCHANGED <<flow, paused, jammed, weapon, recover, press_held, hold_t,
                   reloading, reload_t, window_t, pressure, after_interrupt,
                   steps_since_interrupt, press_shots, window_pays,
                   early_pressed, stuck_holding, grew_without_roll,
                   last_cost, last_refund>>

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
                      reload_t, charge_armed, charging, charge, window,
                      window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, stuck_holding,
                      proc_mutated_driver, grew_without_roll, last_cost,
                      last_refund>>

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
                      reload_t, charge_armed, charging, charge, window,
                      window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, stuck_holding,
                      proc_mutated_driver, grew_without_roll, last_cost,
                      last_refund>>

\* Ultimate starts: combat.gd -> weapon_driver.interrupt(INTERRUPT_ULTIMATE).
\* Drops charge and buffer, spends waiting/open window, keeps reload running.
InterruptUltimate ==
    /\ flow = "play" /\ ~paused
    /\ just_crossed_boundary' = FALSE
    /\ IF GuardInterruptDropsHold THEN
          /\ charge' = 0
          /\ charging' = FALSE
          /\ charge_armed' = FALSE
          /\ hold_t' = 0
          /\ buffered' = FALSE
          /\ stuck_holding' = stuck_holding
       ELSE
          \* Planted fault: ultimate forgets to drop charge_armed / charging.
          /\ stuck_holding' = (stuck_holding \/ charge_armed \/ charging)
          /\ UNCHANGED <<charge, charging, charge_armed, hold_t, buffered>>
    /\ window' = IF window \in {"waiting", "open"} THEN "spent" ELSE window
    /\ window_t' = IF window \in {"waiting", "open"} THEN 0 ELSE window_t
    /\ IF ~DriverReady THEN
          /\ after_interrupt' = "ult"
          /\ steps_since_interrupt' = 0
       ELSE
          /\ UNCHANGED <<after_interrupt, steps_since_interrupt>>
    /\ last_act' = "ult_interrupt"
    /\ UNCHANGED <<flow, paused, jammed, weapon, cooldown, recover, press_held,
                   chamber, hot_rounds, reloading, reload_t, pressure,
                   press_shots, window_pays, early_pressed, shot_outside_play,
                   proc_mutated_driver, grew_without_roll, last_cost, last_refund>>

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
                      chamber, hot_rounds, reloading, reload_t, window,
                      window_t, pressure, press_shots, window_pays,
                      early_pressed, shot_outside_play, proc_mutated_driver,
                      grew_without_roll, last_cost, last_refund>>

\* Weapon swap (relic / tree pick / pilot change): old state dropped, new weapon at rest.
SwapWeapon ==
    /\ flow = "play" /\ ~paused
    /\ \E nextW \in {"rivet", "sable_ball", "tally"} :
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
                       proc_mutated_driver, grew_without_roll>>

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
                             charge_armed, charging, charge, window, window_t,
                             press_shots, window_pays, early_pressed,
                             after_interrupt, steps_since_interrupt>>
        /\ pressure' = IF weapon = "tally" THEN MaxPressure ELSE 0
        /\ last_cost' = 0
        /\ last_refund' = 0
        /\ last_act' = "boundary_reset"
        /\ UNCHANGED <<weapon, shot_outside_play, stuck_holding,
                       proc_mutated_driver, grew_without_roll>>

\* Quit to title: flow.show_title().
\* After death (flow = "dead"), _on_player_died already reset weapon_driver.
\* Finding WC-1 (AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE): after a
\* boss win or victory lap close, combat.gd does not reset weapon_driver on
\* run_ended or flow_changed("title"), leaving stale driver state on TITLE.
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
                         charge_armed, charging, charge, window, window_t,
                         press_shots, window_pays, early_pressed,
                         after_interrupt, steps_since_interrupt>>
    /\ last_cost' = 0
    /\ last_refund' = 0
    /\ last_act' = "boundary_reset"
    /\ UNCHANGED <<weapon, pressure, shot_outside_play, stuck_holding,
                   proc_mutated_driver, grew_without_roll>>

\* ---------------------------------------------------------------------------
\* Next-state relation & specification
\* ---------------------------------------------------------------------------
Next ==
    \/ (\E inp \in AllowedInputs : StepRivet(inp) \/ StepSable(inp) \/ StepTally(inp))
    \/ TopUpCylinder
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
\* The six player-facing invariants (PILOT-CADENCE.md §8, E1-17)
\* ---------------------------------------------------------------------------

\* 1. No shot leaves while outside play (in_play = FALSE or paused).
NoShotOutsidePlay == ~shot_outside_play

\* 2. Charge, reload, hot rounds, window, buffer and chamber are at rest
\*    immediately after every attempt boundary.
RestAfterBoundary == just_crossed_boundary => AtRest

\* 3. From any state, a jam, ultimate, mount/dismount, weapon swap, or pause
\*    returns the trigger to ready in bounded steps, never stuck holding/jammed.
BoundedReadyAfterInterrupt ==
    /\ steps_since_interrupt <= MaxReadyBound
    /\ ~stuck_holding

\* 4. One press gives at most one volley on a press weapon, and procs never
\*    spend a round, open/spend a window, or alter reload/charge/cooldown.
OneVolleyPerPress ==
    /\ press_shots <= 1
    /\ ~proc_mutated_driver

\* 5. Rivet's reload notch pays at most once per reload cycle; an early press
\*    before the notch opens spends the window so mashing cannot hit it.
WindowPaysAtMostOnce ==
    /\ window_pays <= 1
    /\ (early_pressed => window_pays = 0)

\* 6. Tally's stamp refund never exceeds the cast cost (refund <= cost), so
\*    pressure stays within [0, max] and cannot grow without rolling.
RefundNeverExceedsSpend ==
    /\ pressure \in 0..MaxPressure
    /\ last_refund <= last_cost
    /\ ~grew_without_roll

\* ---------------------------------------------------------------------------
\* Reachability probes (each MUST fail on weaponcadence-reach-*.cfg)
\* ---------------------------------------------------------------------------
ProbePlainFire     == last_act /= "plain_fire"
ProbeReload        == ~reloading
ProbeNotchHit      == last_act /= "notch_hit"
ProbeEarlySpend    == ~(weapon = "rivet" /\ reloading /\ early_pressed /\ window = "spent")
ProbeTopUp         == last_act /= "top_up"
ProbeSpark         == last_act /= "spark"
ProbeChargedBolt   == last_act /= "charged_bolt"
ProbeMountDrop     == last_act /= "mount_drop"
ProbeUltInterrupt  == last_act /= "ult_interrupt"
ProbeBoundaryReset == ~just_crossed_boundary
ProbeJamFire       == last_act /= "jam_fire"
ProbeProcNoTouch   == last_act /= "proc_no_touch"
ProbeStampRefund   == last_act /= "stamp_refund"
=============================================================================
