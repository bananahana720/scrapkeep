------------------------------ MODULE YardLock ------------------------------
(* The Spillway's yard lock and its overtime bell: sketches/core-loop/src/world/stage_locks.gd (_step_lock, _lock,
   _unlock, _on_flow_changed, _on_stage_entered, _clear and the warden_engaged handler) and
   sketches/core-loop/src/world/overtime.gd (offer, ring, cash, clear), driven by the run flow in
   sketches/core-loop/src/core/flow.gd. references/yardlock-coverage.md has the code behind every step.

   One physics frame runs three ticks in tree order: game.gd's _physics_process (flow.physics_step, which engages
   the Warden when the ball is in the beacon ring), the ball's own tick (player_ball.gd, which moves it), then
   StageLocks (added to the game root by world.gd after the ball). Kills, deaths, retries, quits, Continues and the
   bell's rams come between frames. The ball's place is one of four zones measured flat from the beacon: "out"
   (outside the lock row's any-ground share), "circle" (inside it, too far for a yard shut there to hold the ball
   within the beacon ring or a strike's reach of the Warden), "near" (outside the ring, close enough that a yard shut
   there does) and "ring" (inside the beacon ring, beacon.gd in_ring). *)
EXTENDS Naturals

CONSTANTS
  Store,               \* game.gd hands flow a RunStore (a played game); FALSE is the storeless test and bot flow
  Stages,              \* stage entries a run makes before the summary (both world 1 park stages have a lock row)
  MaxEntries,          \* stage entries a behaviour may make (bounds retries, new runs and Continues)
  Waves,               \* waves in the lock row (shrunk; the dam has 5)
  MaxS,                \* the lock row's max_s, in locks ticks (shrunk; the dam's is 60 s)
  MaxRings,            \* overtime.gd MAX_RINGS
  LongFlight,          \* the ball can reach the near or ring zone from outside without touching ground in the circle
  ArmedChecksEngaged,  \* _step_lock "armed": `_engaged_s >= 0.0` spends the lock unfired
  LockedYields,        \* _step_lock "locked": an awake Warden opens the yard (not in the code: the YL-1 fix)
  FlowSpends,          \* _on_flow_changed: gates, launch, summary, title spend a shut yard and drop its wall
  DeadSpends,          \* _on_flow_changed: "dead" does the same (not in the code: the YL-2 fix)
  UnlockSpends,        \* _unlock: lock_state = "spent" first
  UnlockDropsWall,     \* _unlock: _drop_wall()
  ElifUnlock,          \* _step_lock "locked": the max_s branch and the crew branch are if/elif
  MaxSOpens,           \* _step_lock "locked": lock_left runs down and opens the yard at 0
  OfferNeedsWin,       \* _unlock: overtime.offer only when won
  CashSpends,          \* overtime.gd cash: state = "spent"
  RingCap,             \* overtime.gd ring: rings >= MAX_RINGS refuses
  OvertimeOn           \* --overtime=on and the dam row's overtime block (overtime.gd enabled, offer)

Zones == {"out", "circle", "near", "ring"}
InStage == {"stage", "gates", "launch"}  \* flow.gd in_stage(): the locks tick, the ball rolls

VARIABLES
  flow,       \* flow.gd state: "stage" (STAGE or BEACON, sealed), "gates", "launch", "dead", "summary", "title"
  stage,      \* ctx.run.stage
  entries,    \* stage entries made
  saved,      \* a run document a Continue can load
  lock,       \* lock_state: "none" (""), "armed", "locked", "spent"
  wall,       \* the ArenaLockWall node stands
  won,        \* lock_won
  wave,       \* _wave
  gap,        \* _wave_wait >= 0: the next wave is whistling in
  crewDown,   \* crew_alive() is empty
  left,       \* lock_left, in locks ticks
  engaged,    \* the Warden is awake: flow._engaged and the locks' _engaged_s >= 0 (one signal sets both)
  zone,       \* where the ball is, flat from the beacon
  grounded,   \* ctx.player.state.grounded
  yardAt,     \* the zone the yard shut in, or "none"
  ot,         \* overtime.gd state: "none" (""), "offered", "spent"
  rings,      \* overtime rings
  otPaid,     \* overtime_paid calls this activation
  otBad,      \* history: a ring or a cash came with no won yard behind it
  paid,       \* yard_cleared calls this activation
  cards,      \* show_start_card calls from the lock this activation (stage_locks.gd:369 and :521)
  phase,      \* the tick that runs next: "events" (between frames), "flow", "ball", "locks"
  last        \* the last step, for the reach probes

vars == <<flow, stage, entries, saved, lock, wall, won, wave, gap, crewDown, left, engaged, zone, grounded, yardAt,
          ot, rings, otPaid, otBad, paid, cards, phase, last>>
yard == <<lock, wall, won, wave, gap, crewDown, left, yardAt, paid, cards>>
bell == <<ot, rings, otPaid, otBad>>

Min(a, b) == IF a < b THEN a ELSE b

\* The yard holds the ball (_hold_ball): it stays in the zones the shut ring covers.
Reach(z) == CASE z = "circle" -> {"circle"} [] z \in {"near", "ring"} -> {"near", "ring"} [] OTHER -> Zones

\* stage_entered: StageLocks._on_stage_entered -> _clear (overtime.clear too) and the row arms the lock; flow
\* _place_beacon seals the stage and clears _engaged. enter_stage, retry_stage, _begin_run and resume_run all reach it.
Enter(s) ==
  /\ stage' = s /\ entries' = entries + 1
  /\ flow' = "stage"
  /\ saved' = Store
  /\ lock' = "armed" /\ wall' = FALSE /\ won' = FALSE /\ wave' = 0 /\ gap' = FALSE /\ crewDown' = FALSE
  /\ left' = 0 /\ yardAt' = "none" /\ paid' = 0 /\ cards' = 0
  /\ engaged' = FALSE
  /\ zone' = "out" /\ grounded' \in BOOLEAN
  /\ ot' = "none" /\ rings' = 0 /\ otPaid' = 0 /\ otBad' = FALSE

\* _on_flow_changed for gates, launch, summary, title (and dead under DeadSpends): a shut yard is spent and its
\* wall dropped; the overtime props go (overtime.clear) whatever the lock was.
Spend(spends) ==
  /\ lock' = IF spends /\ lock = "locked" THEN "spent" ELSE lock
  /\ wall' = IF spends /\ lock = "locked" THEN FALSE ELSE wall
  /\ ot' = IF spends THEN "none" ELSE ot
  /\ rings' = IF spends THEN 0 ELSE rings
  /\ UNCHANGED <<won, wave, gap, crewDown, left, yardAt, paid, cards, otPaid, otBad>>

FlowTo(f) == flow' = f /\ Spend(FlowSpends)

(* ---- One physics frame ---- *)

\* game.gd _physics_process -> flow.physics_step: beacon.advance marks the ring entered for a ball inside it (flat),
\* and a sealed stage then calls _engage, which emits warden_engaged; StageLocks' handler sets _engaged_s.
FlowTick ==
  /\ phase = "flow" /\ phase' = "ball"
  /\ engaged' = (engaged \/ (flow = "stage" /\ zone = "ring"))
  /\ last' = "FlowTick"
  /\ UNCHANGED <<flow, stage, entries, saved, yard, zone, grounded, bell>>

\* The ball's tick. In play it may go anywhere the wall lets it; without LongFlight, a ball with the yard still
\* armed cannot reach the near or ring zone from outside them, since it touches ground in the circle first and the
\* lock shuts there (lock_arms: any ground inside LOCK_ANY_SLOPE_SHARE). Frozen off the stage.
BallTick ==
  /\ phase = "ball" /\ phase' = "locks"
  /\ IF flow \in InStage
       THEN \E z \in (IF lock = "locked" THEN Reach(yardAt) ELSE Zones), g \in BOOLEAN :
              /\ (~LongFlight /\ lock = "armed" /\ zone \in {"out", "circle"}) => z \in {"out", "circle"}
              /\ zone' = z /\ grounded' = g
       ELSE UNCHANGED <<zone, grounded>>
  /\ last' = "BallTick"
  /\ UNCHANGED <<flow, stage, entries, saved, yard, engaged, bell>>

\* _unlock(w): lock_state "spent", lock_won, the bells, _drop_wall, yard_cleared and overtime.offer on a win, then
\* show_start_card. extra is a second _unlock(TRUE) in the same tick (the max_s and crew branches without elif). The
\* counts stop at one past their rule's limit, so a plant that unlocks every tick still has a finite state space.
Unlock(w, extra) ==
  /\ lock' = IF UnlockSpends THEN "spent" ELSE "locked"
  /\ won' = (w \/ extra)
  /\ wall' = (wall /\ ~UnlockDropsWall)
  /\ paid' = Min(2, paid + (IF w THEN 1 ELSE 0) + (IF extra THEN 1 ELSE 0))
  /\ cards' = Min(2, cards + (IF extra THEN 2 ELSE 1))
  /\ IF OvertimeOn /\ (w \/ extra \/ ~OfferNeedsWin)
       THEN ot' = "offered" /\ rings' = 0 /\ otBad' = (otBad \/ ~(w \/ extra))
       ELSE UNCHANGED <<ot, rings, otBad>>
  /\ UNCHANGED <<wave, gap, crewDown, yardAt, otPaid>>

LastWave == crewDown /\ ~gap /\ wave + 1 >= Waves

\* StageLocks._physics_process -> _step_lock, only while flow.in_stage() and the stage has a lock row.
LocksTick ==
  /\ phase = "locks" /\ phase' = "events"
  /\ IF flow \notin InStage \/ lock \in {"none", "spent"}
       THEN UNCHANGED yard /\ UNCHANGED bell /\ last' = "LocksTick"
     ELSE IF lock = "armed"
       THEN IF (ArmedChecksEngaged /\ engaged) \/ flow # "stage"
              THEN /\ lock' = "spent" /\ cards' = cards + 1
                   /\ last' = IF flow # "stage" THEN "SkipUnsealed" ELSE "SkipEngaged"
                   /\ UNCHANGED <<wall, won, wave, gap, crewDown, left, yardAt, paid>> /\ UNCHANGED bell
            ELSE IF grounded /\ zone # "out"
              \* _lock: the wall, lock_left = max_s, the first wave lands (none when ctx.can_spawn() refuses).
              THEN /\ lock' = "locked" /\ wall' = TRUE /\ left' = MaxS /\ yardAt' = zone
                   /\ wave' = 0 /\ gap' = FALSE /\ crewDown' \in BOOLEAN
                   /\ last' = "Lock"
                   /\ UNCHANGED <<won, paid, cards>> /\ UNCHANGED bell
            ELSE UNCHANGED yard /\ UNCHANGED bell /\ last' = "LocksTick"
     ELSE \* "locked"
       LET runDown == MaxSOpens /\ left <= 1
       IN /\ left' = IF MaxSOpens /\ left > 0 THEN left - 1 ELSE left
          /\ IF LockedYields /\ engaged
               THEN Unlock(FALSE, FALSE) /\ last' = "Yield"
             ELSE IF runDown
               THEN Unlock(FALSE, ~ElifUnlock /\ LastWave) /\ last' = "UnlockTimeout"
             ELSE IF crewDown /\ ~gap
               THEN IF wave + 1 >= Waves
                      THEN Unlock(TRUE, FALSE) /\ last' = "UnlockWon"
                      ELSE /\ gap' = TRUE /\ last' = "WaveWhistle"
                           /\ UNCHANGED <<lock, wall, won, wave, crewDown, yardAt, paid, cards>> /\ UNCHANGED bell
             ELSE IF gap
               \* _wave_wait runs out (one tick here): the next wave lands.
               THEN /\ gap' = FALSE /\ wave' = wave + 1 /\ crewDown' \in BOOLEAN /\ last' = "WaveLands"
                    /\ UNCHANGED <<lock, wall, won, yardAt, paid, cards>> /\ UNCHANGED bell
             ELSE UNCHANGED <<lock, wall, won, wave, gap, crewDown, yardAt, paid, cards>> /\ UNCHANGED bell
                  /\ last' = "LocksTick"
  /\ UNCHANGED <<flow, stage, entries, saved, engaged, zone, grounded>>

(* ---- Between frames ---- *)

EndEvents ==
  /\ phase = "events" /\ phase' = "flow"
  /\ last' = "EndEvents"
  /\ UNCHANGED <<flow, stage, entries, saved, yard, engaged, zone, grounded, bell>>

Ev(name) == phase = "events" /\ last' = name /\ UNCHANGED phase

\* The shut yard's crew goes down (the kills of the current wave).
KillCrew ==
  /\ Ev("KillCrew")
  /\ flow = "stage" /\ lock = "locked" /\ ~crewDown /\ ~gap
  /\ crewDown' = TRUE
  /\ UNCHANGED <<flow, stage, entries, saved, lock, wall, won, wave, gap, left, yardAt, paid, cards, engaged, zone,
                 grounded>>
  /\ UNCHANGED bell

\* A hit on the sealed Warden from any source (combat.gd emits enemy_struck for every hit): flow._on_enemy_struck ->
\* _engage, wherever the ball is. The longest strike is a scrap_rockets lock (LOCK_REACH 42 m), so the ball is near.
StrikeWarden ==
  /\ Ev("StrikeWarden")
  /\ flow = "stage" /\ ~engaged /\ zone \in {"near", "ring"}
  /\ engaged' = TRUE
  /\ UNCHANGED <<flow, stage, entries, saved, zone, grounded>> /\ UNCHANGED yard /\ UNCHANGED bell

\* The Warden broken (flow._on_enemy_killed -> _unseal -> _set_state(GATES)).
KillWarden ==
  /\ Ev("KillWarden")
  /\ flow = "stage" /\ engaged /\ zone = "ring"
  /\ FlowTo("gates")
  /\ UNCHANGED <<stage, entries, saved, engaged, zone, grounded>>

\* A Warden that left the tree with no kill (flow.physics_step -> _warden_vanished -> _unseal): the gates open
\* wherever the ball is, awake Warden or not.
WardenVanished ==
  /\ Ev("WardenVanished")
  /\ flow = "stage"
  /\ FlowTo("gates")
  /\ UNCHANGED <<stage, entries, saved, engaged, zone, grounded>>

\* A reward taken and the launch (_on_reward_chosen, _on_launched): _set_state(LAUNCH).
Launch ==
  /\ Ev("Launch")
  /\ flow = "gates"
  /\ FlowTo("launch")
  /\ UNCHANGED <<stage, entries, saved, engaged, zone, grounded>>

\* The flight lands: the next stage's entrance, or the summary after the last (_finish_stage, _advance_from).
Land ==
  /\ Ev("Land")
  /\ flow = "launch"
  /\ IF stage < Stages /\ entries < MaxEntries
       THEN Enter(stage + 1)
       ELSE FlowTo("summary") /\ saved' = FALSE /\ UNCHANGED <<stage, entries, engaged, zone, grounded>>

\* flow._on_player_died: with a store the run ends (_end_run -> SUMMARY); without one, the dead screen (DEAD).
Death ==
  /\ Ev("Death")
  /\ flow \in InStage
  /\ IF Store
       THEN FlowTo("summary") /\ saved' = FALSE
       ELSE flow' = "dead" /\ Spend(DeadSpends) /\ UNCHANGED saved
  /\ UNCHANGED <<stage, entries, engaged, zone, grounded>>

\* flow.retry_stage: storeless flows only (a held R, the dead screen's key).
Retry ==
  /\ Ev("Retry")
  /\ ~Store /\ flow \in InStage \cup {"dead"} /\ entries < MaxEntries
  /\ Enter(stage)

\* flow.new_run from the dead screen or the summary, or a restart in play (the pause menu's restart, a held R with
\* a store: game.gd step_restart_hold): stage 1 again.
NewRun ==
  /\ Ev("NewRun")
  /\ flow \in InStage \cup {"dead", "summary"} /\ entries < MaxEntries
  /\ Enter(1)

\* Quit to the title (show_title) or to the desktop and back; the run document stays.
Quit ==
  /\ Ev("Quit")
  /\ flow \in InStage \cup {"dead", "summary"}
  /\ FlowTo("title")
  /\ UNCHANGED <<stage, entries, saved, engaged, zone, grounded>>

\* flow.resume_run: the saved entrance entered again, or a save written at the launch (a cleared stage) landing its
\* flight in the next stage.
Continue ==
  /\ Ev("Continue")
  /\ flow = "title" /\ saved /\ entries < MaxEntries
  /\ \E s \in {stage, Min(stage + 1, Stages)} : Enter(s)

\* overtime.gd _step_touches: a ram at the bell rings it; at the pot cashes it. The ball rams only in play.
Ring ==
  /\ Ev("Ring")
  /\ flow \in InStage /\ ot = "offered" /\ rings < (IF RingCap THEN MaxRings ELSE MaxRings + 1)
  /\ rings' = rings + 1
  /\ otBad' = (otBad \/ ~won)
  /\ UNCHANGED <<flow, stage, entries, saved, yard, engaged, zone, grounded, ot, otPaid>>

Cash ==
  /\ Ev("Cash")
  /\ flow \in InStage /\ ot = "offered" /\ rings > 0 /\ otPaid < 2
  /\ ot' = IF CashSpends THEN "spent" ELSE "offered"
  /\ otPaid' = otPaid + 1
  /\ otBad' = (otBad \/ ~won)
  /\ UNCHANGED <<flow, stage, entries, saved, yard, engaged, zone, grounded, rings>>

Init ==
  /\ flow = "title" /\ stage = 1 /\ entries = 0 /\ saved = FALSE
  /\ lock = "none" /\ wall = FALSE /\ won = FALSE /\ wave = 0 /\ gap = FALSE /\ crewDown = FALSE /\ left = 0
  /\ engaged = FALSE /\ zone = "out" /\ grounded = FALSE /\ yardAt = "none"
  /\ ot = "none" /\ rings = 0 /\ otPaid = 0 /\ otBad = FALSE /\ paid = 0 /\ cards = 0
  /\ phase = "events" /\ last = "Init"

\* The title's new run (press_start, choose_class -> _begin_run).
Start ==
  /\ Ev("Start")
  /\ flow = "title" /\ entries < MaxEntries
  /\ Enter(1)

Events == KillCrew \/ StrikeWarden \/ KillWarden \/ WardenVanished \/ Launch \/ Land \/ Death \/ Retry \/ NewRun \/ Quit \/ Continue \/ Ring \/ Cash
          \/ Start

Next == FlowTick \/ BallTick \/ LocksTick \/ EndEvents \/ Events

\* Frames keep coming: time passes while the game runs.
Spec == Init /\ [][Next]_vars /\ WF_vars(FlowTick) /\ WF_vars(BallTick) /\ WF_vars(LocksTick) /\ WF_vars(EndEvents)

TypeOK ==
  /\ flow \in InStage \cup {"dead", "summary", "title"}
  /\ stage \in 1..Stages /\ entries \in 0..MaxEntries /\ saved \in BOOLEAN
  /\ lock \in {"none", "armed", "locked", "spent"}
  /\ {wall, won, gap, crewDown, engaged, grounded, otBad} \subseteq BOOLEAN
  /\ wave \in 0..Waves /\ left \in 0..MaxS
  /\ zone \in Zones /\ yardAt \in Zones \cup {"none"}
  /\ ot \in {"none", "offered", "spent"} /\ rings \in 0..(MaxRings + 1) /\ otPaid \in 0..2
  /\ paid \in 0..2 /\ cards \in 0..2
  /\ phase \in {"events", "flow", "ball", "locks"}

(* The rules. Each is one promise to the player. *)

\* The yard's wall stands only while the yard is shut on a stage in play.
WallOnlyWhileLocked == wall => (lock = "locked" /\ flow \in InStage)

\* A shut yard always opens while the stage plays on: the wall never traps the ball.
LockAlwaysOpens == (lock = "locked" /\ flow \in InStage) ~> (lock # "locked" \/ flow \notin InStage)

\* The steps LocksTick names itself by.
LocksSteps == {"LocksTick", "Lock", "Yield", "UnlockTimeout", "UnlockWon", "WaveWhistle", "WaveLands", "SkipEngaged",
               "SkipUnsealed"}

\* Read as the locks tick ends (VFM-08): the yard is never shut while the Warden is awake. A strike lands between
\* frames, after the locks have ticked, so the first locks tick to see it is the next frame's.
NoLockInWardenFight == last \in LocksSteps => ~(lock = "locked" /\ engaged)

\* A yard pays its panel (build.gd yard_cleared) at most once an activation.
YardPaysOnce == paid <= 1

\* The bell is offered, rung and cashed only after a won yard, rings at most MAX_RINGS times and pays once.
OvertimeOnlyAfterWin == ~otBad /\ rings <= MaxRings /\ otPaid <= 1 /\ (ot # "none" => won)

\* The lock calls show_start_card at most once an activation.
StartCardOnce == cards <= 1

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeLock == last # "Lock"
ProbeLockNear == ~(lock = "locked" /\ yardAt = "near")
ProbeWon == last # "UnlockWon"
ProbeTimeout == last # "UnlockTimeout"
ProbeSkipEngaged == last # "SkipEngaged"
ProbeSkipUnsealed == last # "SkipUnsealed"
ProbeWave == last # "WaveLands"
ProbeRing == last # "Ring"
ProbeCash == last # "Cash"
ProbeFlowSpend == ~(lock = "spent" /\ ~won /\ flow \in {"gates", "summary", "title"} /\ yardAt # "none")
ProbeEngaged == ~engaged
ProbeStrike == last # "StrikeWarden"
ProbeContinue == last # "Continue"
ProbeRetry == last # "Retry"
ProbeSecondStage == ~(stage = 2 /\ lock = "locked")
=============================================================================
