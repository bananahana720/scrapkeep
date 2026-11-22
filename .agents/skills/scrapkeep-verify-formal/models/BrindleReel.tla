---------------------------- MODULE BrindleReel ----------------------------
(* Admiral Brindle keeps pressing while reeling (ruling ed, W1-139d & W1-139g):
   sketches/core-loop/src/boss/boss.gd and boss_rules.gd.

   When a strong build shatters a phase's chunk before PHASE_MIN_SECONDS[phase - 1],
   the phase is held and Brindle enters the reel (reeling() = chunkBroken /\ transLeft = 0).
   Instead of stopping attacks until the phase floor expires, Brindle keeps committing
   telegraphed attacks at a slowed cadence across all three hull phases (Requisition,
   Furnace, Scuttle), while every attack still respects the 0.6 s fairness tell floor
   (ChallengeDials.TELL_FLOOR), transition beats commit nothing, and any already-cued
   follow-up (Furnace reprise or Scuttle hook turn) keeps its promise with its visible
   twin (harmless ring preview or hull brace).

   Time is modelled in 1-second ticks; tells are recorded in tenths of a second
   (MinTellTenths = 6 stands for 0.6 s). MaxReelGap = 6 is the 6-second promise from
   W1-139g; the planted fault ReelAttacks = FALSE stops attacks during a reel so the
   gap reaches 7 s and breaks NoLongReelGap. *)
EXTENDS Naturals

CONSTANTS
    PhaseFloor,        \* ticks a phase holds before turning once its chunk breaks (shortened for state space, >= 8)
    TransTicks,        \* FightPhases.TRANSITION_SECONDS (2)
    CraneNormal,       \* normal phase 1 crane cadence (2 s)
    CraneReel,         \* slowed phase 1 reel cadence (4 s)
    SlagNormal,        \* normal phase 2 lead-to-next gap (7 s)
    SlagReel,          \* phase 2 reel slag commit cadence (5 s)
    ChargeRunMax,      \* longest charge run modelled (2 s)
    ChargeRestNormal,  \* normal phase 3 rest (1 s)
    ChargeRestReel,    \* slowed phase 3 reel rest (1 s)
    StunTicks,         \* wall/clash stun duration (3 s)
    MaxReelGap,        \* 6 s promise: no gap over 6 s without a committed attack while reeling
    MinTellTenths,     \* 6 tenths = 0.6 s tell floor (ChallengeDials.TELL_FLOOR)
    ReelAttacks,       \* FALSE (plant): Brindle commits no new attack while reeling -> gap hits 7 s
    ClampPhase2Reel,   \* FALSE (plant): Phase 2 keeps a 7 s normal slag timer into a reel -> gap hits 7 s
    RespectTransition, \* FALSE (plant): commits inside the transition beat -> breaks NoTransitionCommit
    TellGuard,         \* FALSE (plant): cued follow-up draws a 0.4 s tell -> breaks TellFloor
    KeepCuedPromise    \* FALSE (plant): entering reel drops an already-cued follow-up -> breaks CuedPromiseKept

Phases == 1..4
AttackStates == {"idle", "warn", "live", "hook", "recover", "stun"}

VARIABLES
    phase,         \* 1=Requisition, 2=Furnace, 3=Scuttle, 4=Chase (eject)
    phaseClock,    \* seconds elapsed in current phase, capped at PhaseFloor
    transLeft,     \* transition beat countdown (0 in phase 1 and after beat ends)
    chunkBroken,   \* whether this hull phase's chunk is shattered (_held())
    nextAttack,    \* countdown ticks to next attack commit (phases 1 & 2) or state timer (phase 3)
    attackState,   \* phase 3 charge machine state (idle in phases 1, 2, 4)
    cuedPending,   \* TRUE when a follow-up (reprise or hook) has already sounded its cue
    cuedDropped,   \* TRUE if an already-cued follow-up was dropped without committing
    reelGap,       \* consecutive non-stunned ticks while reeling without a committed attack
    lastTell,      \* tell in tenths of a second of the most recent commit (0 if none yet)
    committed,     \* TRUE on the tick an attack committed
    committedInTrans \* TRUE if an attack committed while transLeft > 0

vars == <<phase, phaseClock, transLeft, chunkBroken, nextAttack, attackState,
          cuedPending, cuedDropped, reelGap, lastTell, committed, committedInTrans>>

Min(a, b) == IF a < b THEN a ELSE b
MaxTimer == 10
MaxGapBound == MaxReelGap + 2

Held == phase \in 1..3 /\ chunkBroken
Reeling == Held /\ transLeft = 0

TypeOK ==
    /\ phase \in Phases
    /\ phaseClock \in 0..PhaseFloor
    /\ transLeft \in 0..TransTicks
    /\ chunkBroken \in BOOLEAN
    /\ nextAttack \in 0..MaxTimer
    /\ attackState \in AttackStates
    /\ cuedPending \in BOOLEAN
    /\ cuedDropped \in BOOLEAN
    /\ reelGap \in 0..MaxGapBound
    /\ lastTell \in {0, 4, 6, 14, 25}
    /\ committed \in BOOLEAN
    /\ committedInTrans \in BOOLEAN

Init ==
    /\ phase = 1
    /\ phaseClock = 0
    /\ transLeft = 0
    /\ chunkBroken = FALSE
    /\ nextAttack = 1
    /\ attackState = "idle"
    /\ cuedPending = FALSE
    /\ cuedDropped = FALSE
    /\ reelGap = 0
    /\ lastTell = 0
    /\ committed = FALSE
    /\ committedInTrans = FALSE

\* Helper: next tick's reelGap given whether we are reeling after this step, stunned, or just committed.
NextGap(reelingNow, stunnedNow, didCommit) ==
    IF ~reelingNow THEN 0
    ELSE IF didCommit THEN 0
    ELSE IF stunnedNow THEN reelGap
    ELSE Min(reelGap + 1, MaxGapBound)

\* Phase transition when chunk is broken and phase floor is met (_maybe_turn_phase).
TurnPhase ==
    /\ phase \in 1..3
    /\ chunkBroken
    /\ phaseClock >= PhaseFloor
    /\ phase' = phase + 1
    /\ phaseClock' = 0
    /\ transLeft' = IF phase + 1 \in {2, 3} THEN TransTicks ELSE 0
    /\ chunkBroken' = FALSE
    /\ nextAttack' = IF phase + 1 = 2 THEN 2 ELSE IF phase + 1 = 3 THEN ChargeRestNormal ELSE 0
    /\ attackState' = "idle"
    /\ cuedPending' = FALSE
    /\ cuedDropped' = FALSE
    /\ reelGap' = 0
    /\ committed' = FALSE
    /\ committedInTrans' = FALSE
    /\ UNCHANGED lastTell

\* Chunk shatters mid-phase (before or at PhaseFloor) while not in transition.
\* In boss.gd, entering a reel in Phase 2 clamps _next_attack to <= SlagReel if no cued reprise
\* is due sooner; KeepCuedPromise=FALSE models the bug of dropping an already-cued follow-up.
BreakChunk ==
    /\ phase \in 1..3
    /\ ~chunkBroken
    /\ transLeft = 0
    /\ chunkBroken' = TRUE
    /\ IF ~KeepCuedPromise /\ cuedPending THEN
          /\ cuedPending' = FALSE
          /\ cuedDropped' = TRUE
       ELSE
          /\ cuedPending' = cuedPending
          /\ cuedDropped' = cuedDropped
    /\ nextAttack' =
         IF phase = 2 /\ ReelAttacks /\ ClampPhase2Reel /\ ~cuedPending /\ nextAttack > SlagReel
         THEN SlagReel
         ELSE IF phase = 3 /\ attackState = "idle" /\ ReelAttacks /\ nextAttack > ChargeRestReel
         THEN ChargeRestReel
         ELSE nextAttack
    /\ reelGap' = 0
    /\ committed' = FALSE
    /\ committedInTrans' = FALSE
    /\ UNCHANGED <<phase, phaseClock, transLeft, attackState, lastTell>>

\* Phase 1 (Requisition): crane sweeps on a timer, slowed during reel when ReelAttacks=TRUE.
StepPhase1 ==
    /\ phase = 1
    /\ ~(chunkBroken /\ phaseClock >= PhaseFloor)
    /\ LET canCommit == (nextAttack = 0) /\ (~Reeling \/ ReelAttacks)
           cadence == IF Reeling THEN CraneReel ELSE CraneNormal
           clockNext == Min(phaseClock + 1, PhaseFloor)
       IN
       /\ phaseClock' = clockNext
       /\ IF canCommit THEN
             /\ nextAttack' = cadence
             /\ lastTell' = 14
             /\ committed' = TRUE
             /\ reelGap' = NextGap(Reeling, FALSE, TRUE)
          ELSE
             /\ nextAttack' = IF nextAttack > 0 THEN nextAttack - 1 ELSE 0
             /\ lastTell' = lastTell
             /\ committed' = FALSE
             /\ reelGap' = NextGap(Reeling, FALSE, FALSE)
       /\ committedInTrans' = FALSE
       /\ UNCHANGED <<phase, transLeft, chunkBroken, attackState, cuedPending, cuedDropped>>

\* Phase 2 (Furnace): transition beat -> slag rings + cued reprises; during reel, slowed reel slag
\* cadence (SlagReel <= 5 s) while honouring any already-cued reprise.
StepPhase2 ==
    /\ phase = 2
    /\ ~(chunkBroken /\ phaseClock >= PhaseFloor)
    /\ LET inTrans == transLeft > 0
           allowTrans == ~inTrans \/ ~RespectTransition
           clockNext == Min(phaseClock + 1, PhaseFloor)
           transNext == IF inTrans THEN transLeft - 1 ELSE 0
           reelingNext == chunkBroken /\ transNext = 0
           tellCued == IF TellGuard THEN 6 ELSE 4
       IN
       /\ phaseClock' = clockNext
       /\ transLeft' = transNext
       /\ IF cuedPending /\ allowTrans THEN
             \* Already-cued reprise commits on the very next tick (CUE_LEAD = 0.5 s).
             /\ cuedPending' = FALSE
             /\ nextAttack' = IF reelingNext THEN SlagReel ELSE SlagNormal
             /\ lastTell' = tellCued
             /\ committed' = TRUE
             /\ committedInTrans' = inTrans
             /\ reelGap' = NextGap(reelingNext, FALSE, TRUE)
          ELSE IF nextAttack = 0 /\ allowTrans /\ (~Reeling \/ ReelAttacks) THEN
             \* Commit a lead/reel slag ring (tell = 2.5 s = 25 tenths).
             /\ IF Reeling THEN
                   /\ cuedPending' = FALSE
                   /\ nextAttack' = SlagReel
                ELSE
                   \* Normal Furnace schedules a cued follow-up reprise (or directly cues after drain).
                   /\ cuedPending' \in {FALSE, TRUE}
                   /\ nextAttack' = SlagNormal
             /\ lastTell' = 25
             /\ committed' = TRUE
             /\ committedInTrans' = inTrans
             /\ reelGap' = NextGap(reelingNext, FALSE, TRUE)
          ELSE
             /\ cuedPending' = cuedPending
             /\ nextAttack' = IF nextAttack > 0 THEN nextAttack - 1 ELSE 0
             /\ lastTell' = lastTell
             /\ committed' = FALSE
             /\ committedInTrans' = FALSE
             /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
       /\ UNCHANGED <<phase, chunkBroken, attackState, cuedDropped>>

\* Phase 3 (Scuttle): transition beat -> charge state machine (idle -> warn -> live -> hook/recover/stun).
StepPhase3 ==
    /\ phase = 3
    /\ ~(chunkBroken /\ phaseClock >= PhaseFloor)
    /\ LET inTrans == transLeft > 0
           allowTrans == ~inTrans \/ ~RespectTransition
           clockNext == Min(phaseClock + 1, PhaseFloor)
           transNext == IF inTrans THEN transLeft - 1 ELSE 0
           reelingNext == chunkBroken /\ transNext = 0
           restNext == IF reelingNext THEN ChargeRestReel ELSE ChargeRestNormal
           tellCued == IF TellGuard THEN 6 ELSE 4
       IN
       /\ phaseClock' = clockNext
       /\ transLeft' = transNext
       /\ CASE attackState = "idle" ->
               IF nextAttack = 0 /\ allowTrans /\ (~Reeling \/ ReelAttacks) THEN
                  /\ attackState' = "warn"
                  /\ nextAttack' = 1
                  /\ lastTell' = 14
                  /\ committed' = TRUE
                  /\ committedInTrans' = inTrans
                  /\ cuedPending' = FALSE
                  /\ reelGap' = NextGap(reelingNext, FALSE, TRUE)
               ELSE
                  /\ attackState' = "idle"
                  /\ nextAttack' = IF nextAttack > 0 THEN nextAttack - 1 ELSE 0
                  /\ lastTell' = lastTell
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ cuedPending' = cuedPending
                  /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
          [] attackState = "warn" ->
               /\ attackState' = "live"
               /\ nextAttack' \in 1..ChargeRunMax
               /\ committed' = FALSE
               /\ committedInTrans' = FALSE
               /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
               /\ UNCHANGED <<lastTell, cuedPending>>
          [] attackState = "live" ->
               IF nextAttack > 1 THEN
                  /\ attackState' = "live"
                  /\ nextAttack' = nextAttack - 1
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
                  /\ UNCHANGED <<lastTell, cuedPending>>
               ELSE
                  \* Charge ends: wall/clash stun, hook turn (if lead & not blocked), or recover.
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
                  /\ UNCHANGED lastTell
                  /\ \/ ( \* Short stop cues hook turn (even during reel when ReelAttacks=TRUE)
                          /\ (~Reeling \/ ReelAttacks)
                          /\ attackState' = "hook"
                          /\ nextAttack' = 1
                          /\ cuedPending' = TRUE )
                     \/ ( \* Recover after hook or normal stop
                          /\ attackState' = "recover"
                          /\ nextAttack' = 1
                          /\ cuedPending' = FALSE )
                     \/ ( \* Wall bait or bow clash stuns the hull
                          /\ attackState' = "stun"
                          /\ nextAttack' = StunTicks
                          /\ cuedPending' = FALSE )
          [] attackState = "hook" ->
               IF allowTrans THEN
                  /\ attackState' = "warn"
                  /\ nextAttack' = 1
                  /\ lastTell' = tellCued
                  /\ committed' = TRUE
                  /\ committedInTrans' = inTrans
                  /\ cuedPending' = FALSE
                  /\ reelGap' = NextGap(reelingNext, FALSE, TRUE)
               ELSE
                  /\ attackState' = "hook"
                  /\ nextAttack' = nextAttack
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
                  /\ UNCHANGED <<lastTell, cuedPending>>
          [] attackState = "recover" ->
               /\ attackState' = "idle"
               /\ nextAttack' = restNext
               /\ committed' = FALSE
               /\ committedInTrans' = FALSE
               /\ reelGap' = NextGap(reelingNext, FALSE, FALSE)
               /\ UNCHANGED <<lastTell, cuedPending>>
          [] attackState = "stun" ->
               IF nextAttack > 1 THEN
                  /\ attackState' = "stun"
                  /\ nextAttack' = nextAttack - 1
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ reelGap' = NextGap(reelingNext, TRUE, FALSE)
                  /\ UNCHANGED <<lastTell, cuedPending>>
               ELSE
                  /\ attackState' = "idle"
                  /\ nextAttack' = restNext
                  /\ committed' = FALSE
                  /\ committedInTrans' = FALSE
                  /\ reelGap' = NextGap(reelingNext, TRUE, FALSE)
                  /\ UNCHANGED <<lastTell, cuedPending>>
       /\ UNCHANGED <<phase, chunkBroken, cuedDropped>>

\* Phase 4 (Chase): scooter phase, fight ends.
StepChase ==
    /\ phase = 4
    /\ committed' = FALSE
    /\ committedInTrans' = FALSE
    /\ UNCHANGED <<phase, phaseClock, transLeft, chunkBroken, nextAttack, attackState,
                   cuedPending, cuedDropped, reelGap, lastTell>>

Next == TurnPhase \/ BreakChunk \/ StepPhase1 \/ StepPhase2 \/ StepPhase3 \/ StepChase

Spec == Init /\ [][Next]_vars

\* --- Invariants -------------------------------------------------------------------------

\* W1-139g: While Brindle reels, no gap over 6 s passes without a committed attack.
NoLongReelGap == Reeling => reelGap <= MaxReelGap

\* Ruling cu / ChallengeDials.TELL_FLOOR: every committed attack warns for at least 0.6 s.
TellFloor == lastTell = 0 \/ lastTell >= MinTellTenths

\* FightPhases.in_transition: no attack commits during a phase transition beat.
NoTransitionCommit == ~committedInTrans

\* An already-cued follow-up (Furnace reprise or Scuttle hook turn) is never dropped by a reel.
CuedPromiseKept == ~cuedDropped
=============================================================================
