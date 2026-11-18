---------------------------- MODULE HazardCycle ----------------------------
(* A storm's sought strike in the Spillway (W44): sketches/core-loop/src/world/events/storm_seek.gd, stepped by
   natural.gd _seek, and the enemies it strikes (hazard_hits.gd). One step is one physics tick. Each tick the ball
   and one enemy may stand anywhere, the ball may be rolling (at or above cruise, turning or not), slow (below
   cruise) or stalled (slow, and the silt's stall test holds), and a storm may break when none is on. The hazard
   then takes its own step: idle, tell (a ring on one place filling for TellTicks), strike (one tick, on the told
   place), cool (RestTicks), idle. A storm that ends takes a tell with it. Times are in ticks of the model, not
   seconds; references/hazard-coverage.md maps them to the code's seconds. *)
EXTENDS Naturals

CONSTANTS
    Places,          \* where the ball, the enemy and a tell can be
    TellTicks,       \* storm_seek.gd TELL_S
    MinTell,         \* the fairness floor, 0.6 s (scripts/challenge/fairness.json tellS)
    RestTicks,       \* storm_seek.gd REST_S
    StormTicks,      \* a lightning row's live_s
    TellGuard,       \* FALSE: the strike lands on the first tick (plant no_tell)
    SeekNeedsStall,  \* FALSE: any ball is sought (plant seek_rolling)
    StrikeWhereTold, \* FALSE: the strike re-aims at the ball when it lands
    HitsEnemies,     \* FALSE: the strike passes over enemies (plant skip_enemies)
    BallTested,      \* FALSE: the strike hits the ball wherever it stands
    SeekOn           \* FALSE: no storm ever seeks

Modes == {"rolling", "slow", "stalled"}
Phases == {"idle", "tell", "strike", "cool"}
None == "none"
Quiet == [at |-> None, told |-> None, tell |-> 0, ballIn |-> FALSE, ballHit |-> FALSE,
          enemyIn |-> FALSE, enemyHit |-> FALSE]

VARIABLES phase, told, age, rest, stormLeft, ball, enemy, mode, sought, wait, last
vars == <<phase, told, age, rest, stormLeft, ball, enemy, mode, sought, wait, last>>

Storm == stormLeft > 0
\* storm_seek.gd step: no tell begins that the storm would end under (left_s < TELL_S + LIVE_S).
CanBegin == stormLeft >= TellTicks + 1
Sought(m) == SeekOn /\ (IF SeekNeedsStall THEN m = "stalled" ELSE TRUE)
TellLength == IF TellGuard THEN TellTicks ELSE 1
Min(a, b) == IF a < b THEN a ELSE b

TypeOK ==
    /\ phase \in Phases
    /\ told \in Places \cup {None}
    /\ age \in 0..TellTicks
    /\ rest \in 0..RestTicks
    /\ stormLeft \in 0..StormTicks
    /\ ball \in Places /\ enemy \in Places /\ mode \in Modes
    /\ sought \in Modes \cup {None}
    /\ wait \in 0..(RestTicks + 2)

Init ==
    /\ phase = "idle" /\ told = None /\ age = 0 /\ rest = 0
    /\ stormLeft \in {0, StormTicks}
    /\ ball \in Places /\ enemy \in Places /\ mode \in Modes
    /\ sought = None /\ wait = 0 /\ last = Quiet

\* The world's move this tick: the ball and the enemy go anywhere, the ball's speed is anything, a storm runs down
\* or a new one may break.
World ==
    /\ ball' \in Places /\ enemy' \in Places /\ mode' \in Modes
    /\ stormLeft' \in (IF Storm THEN {stormLeft - 1} ELSE {0, StormTicks})

\* The hazard's move this tick, on the ball as it stands now (natural.gd reads the ball, then steps the storm).
Begin ==
    /\ phase = "idle" /\ Storm /\ CanBegin /\ Sought(mode)
    /\ phase' = "tell" /\ told' = ball /\ age' = 0 /\ sought' = mode
    /\ UNCHANGED <<rest, last>>

Rest ==
    /\ phase = "idle" /\ ~(Storm /\ CanBegin /\ Sought(mode))
    /\ UNCHANGED <<phase, told, age, rest, sought, last>>

Fill ==
    /\ phase = "tell" /\ Storm /\ age + 1 < TellLength
    /\ age' = age + 1
    /\ UNCHANGED <<phase, told, rest, sought, last>>

Strike ==
    /\ phase = "tell" /\ Storm /\ age + 1 >= TellLength
    /\ LET at == IF StrikeWhereTold THEN told ELSE ball IN
       last' = [at |-> at, told |-> told, tell |-> age + 1, ballIn |-> ball = at, ballHit |-> (BallTested => ball = at),
                enemyIn |-> enemy = at, enemyHit |-> HitsEnemies /\ enemy = at]
    /\ phase' = "strike" /\ age' = age + 1
    /\ UNCHANGED <<told, rest, sought>>

\* storm_seek.gd clear(): the storm ended under the tell, which never strikes.
Cleared ==
    /\ phase = "tell" /\ ~Storm
    /\ phase' = "idle" /\ told' = None /\ age' = 0 /\ sought' = None
    /\ UNCHANGED <<rest, last>>

Cool ==
    /\ phase = "strike"
    /\ phase' = "cool" /\ rest' = RestTicks /\ told' = None /\ age' = 0 /\ sought' = None
    /\ UNCHANGED last

Rested ==
    /\ phase = "cool"
    /\ rest' = rest - 1
    /\ phase' = IF rest = 1 THEN "idle" ELSE "cool"
    /\ UNCHANGED <<told, age, sought, last>>

\* How long a stalled ball has waited in a storm that could still seek it, while nothing was telling.
Waiting ==
    wait' = IF Storm /\ CanBegin /\ mode = "stalled" /\ phase \in {"idle", "cool"} THEN Min(wait + 1, RestTicks + 2) ELSE 0

Next == World /\ Waiting /\ (Begin \/ Rest \/ Fill \/ Strike \/ Cleared \/ Cool \/ Rested)

Spec == Init /\ [][Next]_vars

\* Rules, each read on the tick the strike lands.
\* A strike tells for at least MinTell, on the place it lands.
TellBeforeStrike == phase = "strike" => (last.tell >= MinTell /\ last.at = last.told)
\* Only a stalled ball is sought: a rolling one, turning or not, never; a merely slow one, not yet.
RollingNeverSought == phase \in {"tell", "strike"} => sought = "stalled"
\* A stalled ball in a storm that can still seek it waits at most the rest and one tick.
StalledSought == wait <= RestTicks + 1
\* An enemy inside the strike is struck.
EnemyStruck == phase = "strike" => (last.enemyIn => last.enemyHit)
\* The ball is hit only inside the strike, which is where the tell was: a ball that moved off escapes.
BallOnlyWhereTold == phase = "strike" => (last.ballHit => last.ballIn /\ last.at = last.told)
=============================================================================
