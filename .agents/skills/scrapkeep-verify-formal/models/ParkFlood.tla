---------------------------- MODULE ParkFlood ----------------------------
(* A park ground event that fills with water (flood_fill, flash_flood) in
   sketches/core-loop/src/world/event_director.gd, from its announcement to
   its end, with the ball free to roll into and out of any basin between any
   two ticks. references/flood-coverage.md has the code behind every step.

   Time is counted in director ticks. A rise takes Fill ticks. The game adds
   a float each tick, so after Fill ticks the sum can sit a hair under the
   fill time; `hair` is that state. *)
EXTENDS Naturals, FiniteSets

CONSTANTS
  Events,         \* the ground flood rows of one park
  Fill,           \* ticks a rise takes
  Live,           \* ticks a timed flood stays live; 0 is a flood with no clock
  Cap,            \* PARK_GROUND_CAP
  MaxLives,       \* how many times one row may land (bounds the model)
  SnapRise,       \* the rise snaps to full within the clock tolerance (pull request 1135)
  WaitUnderBall,  \* rising water waits while a grounded ball is in its basin
  HoldTicks,      \* PARK_FLOOD_HOLD_CAP_S in ticks: how many ticks the wait lasts, W1-148
  HoldCap,        \* the wait is spent after HoldTicks ticks (FALSE: it lasts as long as the ball stays)
  EndNeedsClear,  \* _park_can_end: a flood ends only with its basin clear
  CapGuard        \* _park_capacity: a new ground event waits for a free slot

VARIABLES
  phase,    \* per row: "waiting", "announced", "live", "cooldown"
  rise,     \* per row: ticks risen, 0..Fill
  hair,     \* per row: Fill ticks risen but the sum is a hair short
  elapsed,  \* per row: live ticks, 0..Live
  lives,    \* per row: times landed
  ball,     \* the row whose basin holds the grounded ball, or "out"
  waited,   \* per row: ticks the rise has waited for a ball since the row landed (held_s)
  held,     \* per row: a tick skipped the step hook on water that had risen Fill ticks
  roseUnder,\* per row: a tick raised the water with the ball in the basin
  endedUnder\* per row: the flood ended with the ball in the basin

vars == <<phase, rise, hair, elapsed, lives, ball, waited, held, roseUnder, endedUnder>>

Rising(e) == rise[e] < Fill \/ hair[e]

\* _park_hold_spent: the wait for a ball is over while the water still rises.
Spent(e) == HoldCap /\ waited[e] >= HoldTicks

\* _park_clear for a ground row: false with the ball in the footprint.
Clear(e) == ball # e

\* _park_capacity counts every other live ground row that is not settled.
\* Only a flood with no clock settles, once its water is full.
Settled(e) == Live = 0 /\ ~Rising(e)
Unsettled(c) == {e \in Events \ {c} : phase[e] = "live" /\ ~Settled(e)}
Capacity(c) == ~CapGuard \/ Cardinality(Unsettled(c)) + 1 <= Cap

Init ==
  /\ phase = [e \in Events |-> "waiting"]
  /\ rise = [e \in Events |-> 0]
  /\ hair = [e \in Events |-> FALSE]
  /\ elapsed = [e \in Events |-> 0]
  /\ lives = [e \in Events |-> 0]
  /\ ball = "out"
  /\ waited = [e \in Events |-> 0]
  /\ held = [e \in Events |-> FALSE]
  /\ roseUnder = [e \in Events |-> FALSE]
  /\ endedUnder = [e \in Events |-> FALSE]

Announce(e) ==
  /\ phase[e] \in {"waiting", "cooldown"}
  /\ lives[e] < MaxLives
  /\ phase' = [phase EXCEPT ![e] = "announced"]
  /\ UNCHANGED <<rise, hair, elapsed, lives, ball, waited, held, roseUnder, endedUnder>>

\* The landing in _advance_park: capacity, a clear basin, then the clocks reset.
\* Clear is read before the reset, as the code reads it.
Land(e) ==
  /\ phase[e] = "announced"
  /\ Capacity(e)
  /\ Clear(e)
  /\ phase' = [phase EXCEPT ![e] = "live"]
  /\ rise' = [rise EXCEPT ![e] = 0]
  /\ hair' = [hair EXCEPT ![e] = FALSE]
  /\ elapsed' = [elapsed EXCEPT ![e] = 0]
  /\ lives' = [lives EXCEPT ![e] = lives[e] + 1]
  /\ waited' = [waited EXCEPT ![e] = 0]
  /\ UNCHANGED <<ball, held, roseUnder, endedUnder>>

CanEnd(e) == ~EndNeedsClear \/ Clear(e)

End(e) ==
  /\ phase' = [phase EXCEPT ![e] = "cooldown"]
  /\ endedUnder' = [endedUnder EXCEPT ![e] = endedUnder[e] \/ ball = e]

\* The next value of the rise after one stepped tick.
Rose(e, h) ==
  /\ rise' = [rise EXCEPT ![e] = IF rise[e] < Fill THEN rise[e] + 1 ELSE Fill]
  /\ hair' = [hair EXCEPT ![e] = h]
  /\ roseUnder' = [roseUnder EXCEPT ![e] = roseUnder[e] \/ (Rising(e) /\ ball = e /\ ~Spent(e))]

\* _park_step_live, one call.
Step(e) ==
  /\ phase[e] = "live"
  /\ UNCHANGED <<lives, ball>>
  /\ IF Live > 0 /\ elapsed[e] = Live
     THEN \* the live time is up: end if the basin is clear, else wait
          /\ UNCHANGED <<rise, hair, elapsed, waited, held, roseUnder>>
          /\ IF CanEnd(e) THEN End(e) ELSE UNCHANGED <<phase, endedUnder>>
     ELSE LET now == IF Live > 0 THEN elapsed[e] + 1 ELSE 0
              waits == WaitUnderBall /\ Rising(e) /\ ~Clear(e) /\ ~Spent(e)
          IN /\ elapsed' = [elapsed EXCEPT ![e] = now]
             /\ IF waits
                THEN \* no step hook this tick
                     /\ waited' = [waited EXCEPT ![e] = IF waited[e] < HoldTicks THEN waited[e] + 1 ELSE waited[e]]
                     /\ held' = [held EXCEPT ![e] = held[e] \/ rise[e] = Fill]
                     /\ UNCHANGED <<phase, rise, hair, roseUnder, endedUnder>>
                ELSE /\ UNCHANGED <<waited, held>>
                     /\ \/ /\ rise[e] + 1 = Fill
                           /\ \E h \in (IF SnapRise THEN {FALSE} ELSE BOOLEAN) : Rose(e, h)
                        \/ /\ rise[e] + 1 # Fill
                           /\ Rose(e, FALSE)
                     /\ IF Live > 0 /\ now = Live /\ CanEnd(e)
                        THEN End(e)
                        ELSE UNCHANGED <<phase, endedUnder>>

Roll ==
  /\ \E b \in Events \cup {"out"} : ball' = b /\ b # ball
  /\ UNCHANGED <<phase, rise, hair, elapsed, lives, waited, held, roseUnder, endedUnder>>

Next == Roll \/ \E e \in Events : Announce(e) \/ Land(e) \/ Step(e)

Fair == \A e \in Events : WF_vars(Step(e)) /\ WF_vars(Land(e))
Spec == Init /\ [][Next]_vars /\ Fair

TypeOK ==
  /\ phase \in [Events -> {"waiting", "announced", "live", "cooldown"}]
  /\ rise \in [Events -> 0..Fill]
  /\ hair \in [Events -> BOOLEAN]
  /\ elapsed \in [Events -> 0..Live]
  /\ lives \in [Events -> 0..MaxLives]
  /\ ball \in Events \cup {"out"}
  /\ waited \in [Events -> 0..HoldTicks]

(* The rules. Each is one promise to the player. *)

\* Water that has finished rising keeps acting on a ball that rolls in.
FullWaterNeverHeld == \A e \in Events : ~held[e]

\* A flood with no clock gives its ground slot back once its water is full.
FullWaterFreesItsSlot ==
  \A e \in Events : (Live = 0 /\ phase[e] = "live" /\ rise[e] = Fill) => Settled(e)

\* Water does not rise onto a grounded ball in its basin while the wait for it lasts (the first HoldTicks ticks).
NeverRisesUnderBall == \A e \in Events : ~roseUnder[e]

\* A flood never withdraws from under a ball in its basin.
NeverEndsUnderBall == \A e \in Events : ~endedUnder[e]

\* No more ground events are unsettled at once than the cap allows.
WithinCap == Cardinality({e \in Events : phase[e] = "live" /\ ~Settled(e)}) <= Cap

\* Once the ball stays out of every basin, a timed flood ends and a flood that was announced lands.
BallOut == <>[](ball = "out")
FloodEnds == BallOut => \A e \in Events : (Live > 0 /\ phase[e] = "live") ~> (phase[e] # "live")
AnnouncedLands == BallOut => \A e \in Events : (phase[e] = "announced") ~> (phase[e] = "live")

\* The wait for a ball is bounded: asked without the ball leaving, rising water always finishes rising.
\* It did not before W1-148 (finding PF-1); flood-broken-nohold removes the cap and must break it.
HoldEnds == \A e \in Events : (phase[e] = "live" /\ Rising(e)) ~> ~(phase[e] = "live" /\ Rising(e))

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeFull == \A e \in Events : ~(phase[e] = "live" /\ ~Rising(e))
ProbeEnds == \A e \in Events : phase[e] # "cooldown"
ProbeWaits == \A e \in Events : ~(phase[e] = "live" /\ Rising(e) /\ ball = e)
ProbeCapHolds == \A e \in Events : ~(phase[e] = "announced" /\ ~Capacity(e))
ProbeSecondLife == \A e \in Events : lives[e] < 2
ProbeEndWaits == \A e \in Events : ~(Live > 0 /\ phase[e] = "live" /\ elapsed[e] = Live /\ ball = e)
=============================================================================
