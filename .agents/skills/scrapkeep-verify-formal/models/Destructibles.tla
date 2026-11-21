---------------------------- MODULE Destructibles ----------------------------
(* A stage's heft destructibles in sketches/core-loop/src/world/destructibles.gd, the ball's line, mount and aim
   that can rest on a piece (sketches/core-loop/src/movement/player_ball.gd, _on_piece_shattered), the pickups a
   break drops and the run wallet they fill, and the stage retry that rebuilds the pieces and restores the run
   (sketches/core-loop/src/core/flow.gd retry_stage, run_state.gd restore). references/destructibles-coverage.md has
   the code behind every step.

   One physics frame runs the world tick (on_ball) and the ball tick (a press) once each, in either order. The
   camera's aim, a blast from any source and a pickup can come between any two steps. The run wallet counts what
   the destructibles paid since the stage-entry checkpoint, so the checkpoint itself is 0. *)
EXTENDS Naturals, FiniteSets

CONSTANTS
  TierA, TierB,      \* the stage's two destructible rows, by tier (1 to 5): piece 1 and piece 2
  Classes,           \* the heft classes the run can hold (run_state.gd heft_class)
  Bonuses,           \* the tier bonus a blast source may ask for (every caller today asks for 1)
  ScrapCap,          \* scrap_cap, SCRAP_CAP 35 a stage
  CogCap,            \* cog_cap, COG_CAP 20 a stage
  MaxRetries,        \* how many stage retries a behaviour may make (bounds the model)
  BonusCap,          \* on_blast: clampi(tier_bonus, 0, 1), the bonus never stacks past +1
  BlastNeedsIntact,  \* on_blast: `not p.intact` skips a shattered piece
  UnfileOnShatter,   \* _shatter: _unfile takes the piece out of the grid _near reads
  CapClamp,          \* _pay: each payout is clamped to what the stage meter still has room for
  ColliderOff,       \* _shatter: collision_layer 0 at once, so no ray or roll meets the piece again
  CutLine,           \* _on_piece_shattered: cut_line("shattered") for a world line anchored on the piece
  DropMount,         \* _on_piece_shattered: kit.mounted = false for a mount face on the piece
  ClearAim,          \* _on_piece_shattered: kit.aim = no_aim() for an aim point on the piece
  RetryRestoresRun,  \* retry_stage: run.restore() puts scrap and cogs back to the stage-entry checkpoint
  RetryClearsDrops   \* retry_stage -> stage_entered -> build.gd scrap.lay_out -> clear(): uncollected drops go

None == 0  \* the pieces are 1 and 2

VARIABLES
  heft,       \* the run's heft class
  intact,     \* per piece: intact (TRUE) or shattered
  collider,   \* per piece: the solid is live on the world layer
  paid,       \* per piece: times it paid this attempt
  scrapPaid,  \* _scrap_paid, the stage meter
  cogsPaid,   \* _cogs_paid
  dropScrap,  \* scrap pickups on the ground
  dropCogs,   \* cog pickups on the ground
  runScrap,   \* run.scrap, counted from the stage-entry checkpoint
  runCogs,    \* run.cogs, counted from the stage-entry checkpoint
  line,       \* the piece a world line is anchored on, or None
  mount,      \* the piece the pylon mount face is on, or None
  aim,        \* the piece kit.aim points at (a world aim, no body), or None
  ran,        \* the ticks of this physics frame that have run: "world", "ball"
  stage,      \* "play", "dead" (the death screen), "gone" (launched to the next stage)
  tries,      \* retries made
  overTier,   \* history: a blast broke a piece more than one tier above the class
  last,       \* the last step, for the reach probes
  freed       \* what the last break's handler let go of: "line", "mount", "aim"

vars == <<heft, intact, collider, paid, scrapPaid, cogsPaid, dropScrap, dropCogs, runScrap, runCogs,
          line, mount, aim, ran, stage, tries, overTier, last, freed>>

ball == <<line, mount, aim>>
wallet == <<dropScrap, dropCogs, runScrap, runCogs>>

Pieces == {1, 2}
Tier == [p \in Pieces |-> IF p = 1 THEN TierA ELSE TierB]

Min(a, b) == IF a < b THEN a ELSE b

\* LOOT in destructibles.gd: tier -> [scrap, cogs]. A tier 1 piece pays 1 scrap half the time (TIER1_CHANCE), from
\* its own seeded stream; the model takes either.
ScrapOf(t) == CASE t = 1 -> {0, 1} [] t = 2 -> {2} [] t = 3 -> {3} [] OTHER -> {4}
CogsOf(t) == CASE t = 1 -> 0 [] t = 2 -> 1 [] OTHER -> 2

\* _near finds a piece only while it is filed in the grid.
Findable(p) == intact[p] \/ ~UnfileOnShatter

Init ==
  /\ heft \in Classes
  /\ intact = [p \in Pieces |-> TRUE]
  /\ collider = [p \in Pieces |-> TRUE]
  /\ paid = [p \in Pieces |-> 0]
  /\ scrapPaid = 0 /\ cogsPaid = 0
  /\ dropScrap = 0 /\ dropCogs = 0
  /\ runScrap = 0 /\ runCogs = 0
  /\ line = None /\ mount = None /\ aim = None
  /\ ran = {}
  /\ stage = "play"
  /\ tries = 0
  /\ overTier = FALSE
  /\ last = "Init"
  /\ freed = {}

\* _shatter, one call: the collider switch, _unfile, _pay and the piece_shattered signal, whose one listener is the
\* ball's _on_piece_shattered. All of it runs inside the on_ball or on_blast call that decided the break.
ShatterCleanup(p) ==
  /\ intact' = [intact EXCEPT ![p] = FALSE]
  /\ collider' = [collider EXCEPT ![p] = collider[p] /\ ~ColliderOff]
  /\ paid' = [paid EXCEPT ![p] = paid[p] + 1]
  /\ \E s \in ScrapOf(Tier[p]) :
       LET sc == IF CapClamp THEN Min(s, ScrapCap - scrapPaid) ELSE s
           cc == IF CapClamp THEN Min(CogsOf(Tier[p]), CogCap - cogsPaid) ELSE CogsOf(Tier[p])
       IN /\ scrapPaid' = scrapPaid + sc
          /\ cogsPaid' = cogsPaid + cc
          /\ dropScrap' = dropScrap + sc
          /\ dropCogs' = dropCogs + cc
  /\ line' = IF CutLine /\ line = p THEN None ELSE line
  /\ mount' = IF DropMount /\ mount = p THEN None ELSE mount
  /\ aim' = IF ClearAim /\ aim = p THEN None ELSE aim
  /\ freed' = {x \in {"line", "mount", "aim"} :
                 \/ x = "line" /\ CutLine /\ line = p
                 \/ x = "mount" /\ DropMount /\ mount = p
                 \/ x = "aim" /\ ClearAim /\ aim = p}
  /\ UNCHANGED <<runScrap, runCogs>>

\* The world tick: world.gd _physics_process -> on_ball(ball, velocity, run.heft_class(), delta). The ball's sweep
\* meets at most one piece in the model; it breaks one of the ball's class or lighter, fast enough (_bar); anything
\* else is a wall.
OnBall(p) ==
  /\ intact[p] /\ Findable(p)
  /\ heft >= Tier[p]
  /\ ShatterCleanup(p)

WorldTick ==
  /\ stage = "play" /\ "world" \notin ran
  /\ ran' = ran \cup {"world"}
  /\ \/ \E p \in Pieces : OnBall(p) /\ last' = "OnBall"
     \/ /\ last' = "WorldTick" /\ freed' = {}
        /\ UNCHANGED <<intact, collider, paid, scrapPaid, cogsPaid, wallet, ball>>
  /\ UNCHANGED <<heft, stage, tries, overTier>>

\* on_blast from a source that resolved its ring: the ball's slam and Redline (player_ball.gd _break_props) or a
\* combat source through ctx.break_props (ultimates, sticky, silo battery, quake knock). Every caller passes the run's
\* heft class and a bonus of 1; a source asking for more is checked against the clamp.
OnBlast(p, b) ==
  /\ stage = "play"
  /\ Findable(p)
  /\ intact[p] \/ ~BlastNeedsIntact
  /\ heft + Min(b, BonusCap) >= Tier[p]
  /\ ShatterCleanup(p)
  /\ overTier' = (overTier \/ Tier[p] > heft + 1)
  /\ last' = IF Tier[p] = heft + 1 THEN "OnBlastBonus" ELSE "OnBlast"
  /\ UNCHANGED <<heft, ran, stage, tries>>

\* The camera frame: game.gd aim_along stores what the crosshair ray hits in kit.aim. It meets a piece only while
\* its collider is live; it can also point at anything else.
AimPiece(p) ==
  /\ stage = "play" /\ collider[p] /\ aim # p
  /\ aim' = p
  /\ last' = "AimPiece" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, line, mount, ran, stage, tries, overTier>>

AimAway ==
  /\ stage = "play" /\ aim # None
  /\ aim' = None
  /\ last' = "AimAway" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, line, mount, ran, stage, tries, overTier>>

\* The ball tick's press, one of: _press_harpoon fires to kit.aim's point (no new ray); the pylon mount takes the face
\* its own ray finds (augments.gd _mount_spot, _steepest_face) or, with no face in reach, the anchor of a world line
\* (no ray); or a release lets go of the line and the mount. Or no press.
LatchLine == aim # None /\ line = None /\ line' = aim /\ last' = "LatchLine" /\ UNCHANGED mount
MountPiece(p) == mount = None /\ (collider[p] \/ line = p) /\ mount' = p /\ last' = "MountPiece" /\ UNCHANGED line
ReleaseBall == (line # None \/ mount # None) /\ line' = None /\ mount' = None /\ last' = "ReleaseBall"
BallIdle == last' = "BallTick" /\ UNCHANGED <<line, mount>>

BallTick ==
  /\ stage = "play" /\ "ball" \notin ran
  /\ ran' = ran \cup {"ball"}
  /\ LatchLine \/ (\E p \in Pieces : MountPiece(p)) \/ ReleaseBall \/ BallIdle
  /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, aim, stage, tries, overTier>>

FrameEnd ==
  /\ ran = {"world", "ball"}
  /\ ran' = {}
  /\ last' = "FrameEnd" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, ball, stage, tries, overTier>>

\* build.gd: scrap.step hands each pickup the ball reaches to run.add_scrap, and each gear to run.add_cogs.
Collect ==
  /\ stage = "play"
  /\ \/ dropScrap > 0 /\ dropScrap' = dropScrap - 1 /\ runScrap' = runScrap + 1 /\ UNCHANGED <<dropCogs, runCogs>>
     \/ dropCogs > 0 /\ dropCogs' = dropCogs - 1 /\ runCogs' = runCogs + 1 /\ UNCHANGED <<dropScrap, runScrap>>
  /\ last' = "Collect" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, ball, ran, stage, tries, overTier>>

\* flow.gd retry_stage (a held R in a storeless flow, or the death screen's stage replay): run.restore(), then
\* stage_entered(stage, true), whose handlers rebuild the pieces (world.gd _host_destructibles -> build -> teardown
\* zeroes the meter) and lay the scrap field out again (build.gd scrap.lay_out -> clear()). The ball's line, mount
\* and aim are left as they were: the model does not lean on the respawn to drop them.
RetryStage ==
  /\ stage \in {"play", "dead"}
  /\ tries < MaxRetries
  /\ intact' = [p \in Pieces |-> TRUE]
  /\ collider' = [p \in Pieces |-> TRUE]
  /\ paid' = [p \in Pieces |-> 0]
  /\ scrapPaid' = 0 /\ cogsPaid' = 0
  /\ runScrap' = IF RetryRestoresRun THEN 0 ELSE runScrap
  /\ runCogs' = IF RetryRestoresRun THEN 0 ELSE runCogs
  /\ dropScrap' = IF RetryClearsDrops THEN 0 ELSE dropScrap
  /\ dropCogs' = IF RetryClearsDrops THEN 0 ELSE dropCogs
  /\ stage' = "play"
  /\ tries' = tries + 1
  /\ last' = "RetryStage" /\ freed' = {}
  /\ UNCHANGED <<heft, ball, ran, overTier>>

\* The launch to the next stage, and a death. A death in a run with a store ends the run; the death screen's stage
\* replay is RetryStage.
StageExit ==
  /\ stage = "play" /\ stage' = "gone"
  /\ last' = "StageExit" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, ball, ran, tries, overTier>>

Death ==
  /\ stage = "play" /\ stage' = "dead"
  /\ last' = "Death" /\ freed' = {}
  /\ UNCHANGED <<heft, intact, collider, paid, scrapPaid, cogsPaid, wallet, ball, ran, tries, overTier>>

\* Nothing left to do: the stage is behind the ball, or the retries are spent.
Over ==
  /\ stage = "gone" \/ (stage = "dead" /\ tries = MaxRetries)
  /\ UNCHANGED vars

Next ==
  \/ WorldTick \/ BallTick \/ FrameEnd
  \/ \E p \in Pieces, b \in Bonuses : OnBlast(p, b)
  \/ \E p \in Pieces : AimPiece(p)
  \/ AimAway \/ Collect \/ RetryStage \/ StageExit \/ Death \/ Over

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ heft \in Classes
  /\ intact \in [Pieces -> BOOLEAN]
  /\ collider \in [Pieces -> BOOLEAN]
  /\ paid \in [Pieces -> Nat]
  /\ {scrapPaid, cogsPaid, dropScrap, dropCogs, runScrap, runCogs, tries} \subseteq Nat
  /\ {line, mount, aim} \subseteq Pieces \cup {None}
  /\ ran \subseteq {"world", "ball"}
  /\ stage \in {"play", "dead", "gone"}
  /\ overTier \in BOOLEAN
  /\ freed \subseteq {"line", "mount", "aim"}

(* The rules. Each is one promise to the player. *)

\* A piece pays at most once an attempt, and a stage's pieces never pay past the stage's cap.
PaysOnce ==
  /\ \A p \in Pieces : paid[p] <= 1
  /\ scrapPaid <= ScrapCap
  /\ cogsPaid <= CogCap

\* Retrying a stage never banks more than one attempt's worth: the run holds at most the checkpoint plus the cap.
RetryNoFarm == runScrap <= ScrapCap /\ runCogs <= CogCap

\* At the end of a physics frame no line, mount or aim rests on a shattered piece.
NoLineOnRubble ==
  ran = {} => \A p \in Pieces : ~intact[p] => (line # p /\ mount # p /\ aim # p)

\* A shattered piece is never a live solid.
NoColliderAfterShatter == \A p \in Pieces : ~intact[p] => ~collider[p]

\* No blast breaks a piece more than one tier above the class.
TierCapNeverStacks == ~overTier

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeOnBall == last # "OnBall"
ProbeOnBlast == last # "OnBlast"
ProbeOnBlastBonus == last # "OnBlastBonus"
ProbeAim == last # "AimPiece"
ProbeLatch == last # "LatchLine"
ProbeMount == last # "MountPiece"
ProbeRelease == last # "ReleaseBall"
ProbeCollect == last # "Collect"
ProbeRetry == last # "RetryStage"
ProbeExit == last # "StageExit"
ProbeDeath == last # "Death"
ProbeFreesLine == "line" \notin freed
ProbeFreesMount == "mount" \notin freed
ProbeFreesAim == "aim" \notin freed
ProbeScrapCap == scrapPaid < ScrapCap
ProbeCogCap == cogsPaid < CogCap
ProbeSecondAttemptBanks == ~(tries > 0 /\ runScrap > 0 /\ runCogs > 0)
=============================================================================
