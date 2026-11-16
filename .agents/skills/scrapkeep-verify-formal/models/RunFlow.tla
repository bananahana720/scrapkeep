---------------------------- MODULE RunFlow ----------------------------
(* A run of Scrapkeep from the title to its summary, with the launch swipe
   (launch_take.gd) that covers the cut between stages, and every way a
   player can interrupt it. Each action names the code it stands for;
   references/coverage.md has the file and function for every name here.
   Paths are under sketches/core-loop/src.

   One action is one synchronous call in the code. Nothing else runs inside
   it, so nothing else may happen inside the action. *)
EXTENDS Naturals, FiniteSets

CONSTANTS
  Stages,          \* stages before the boss arena (world 1: 2)
  MaxRuns,         \* bound on runs in one session
  Store,           \* TRUE: the real game (a death ends the run, R starts a new run). FALSE: tests and bots.
  \* The guards below are in the code today. A config that turns one off is a
  \* broken variant: it shows that the property watching it can fail.
  UntakeOnRetry,   \* flow.retry_stage calls _untake
  UntakeOnEnd,     \* flow._end_run calls _untake
  UntakeOnNewRun,  \* flow._begin_run calls _untake (added for references/findings.md F-1)
  VanishGuard,     \* flow's tick calls _warden_vanished for a sealed stage with no Warden
  EndGuard,        \* flow._on_player_died returns unless in_play
  BusyRefuses,     \* game.play_launch_take returns false while the swipe node is busy
  SwipeOwnsKeys,   \* game._screen_key and screens._input swallow every screen key while the swipe is busy
  \* An assumption about time, which this model does not count. TRUE: a Warden cannot be broken while a
  \* swipe is still on screen (a swipe lasts under 3 s; the WIND, COVER, HOLD and REVEAL constants in
  \* launch_take.gd). FALSE explores the untimed case and is expected to fail.
  StageOutlastsSwipe

VARIABLES
  fs,        \* flow.state
  stage,     \* run.stage
  run,       \* how many runs this session has begun
  over,      \* run.over
  ended,     \* how many times run_ended fired for this run
  sealed, warden,   \* flow.sealed; whether flow.warden is a live node
  launched,  \* flow._launched
  seam,      \* flow._seam_take
  taken,     \* flow._taken_part (0 is "")
  held,      \* the part ids the run holds now
  snap,      \* the part ids in the stage-start checkpoint (run.snapshot)
  scrapless, \* build.scrapless() for this run
  tPhase, tKind, tWord, tCb,   \* the one launch_take node: phase, who started it, its stamp, its on_cover
  pickLost,  \* a pilot pick whose on_cover was dropped
  svHeld, svCleared, svStage   \* the saved run document (run_store)

vars == <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
          scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

States == {"TITLE", "CLASS_SELECT", "STAGE", "BEACON", "GATES", "LAUNCH", "SUMMARY", "DEAD", "BOSS", "VICTORY"}
InPlay == fs \in {"STAGE", "BEACON", "GATES", "LAUNCH", "BOSS"}     \* flow.in_play (LAP is folded into VICTORY)
PartIds == 0 .. (MaxRuns * 10 + Stages)
PartOf(r, s) == r * 10 + s
TakeBusy == tPhase # "idle"                                         \* launch_take.busy
KeysHeard == SwipeOwnsKeys => ~TakeBusy                             \* a screen key reaches its screen

Init ==
  /\ fs = "TITLE" /\ stage = 0 /\ run = 0 /\ over = FALSE /\ ended = 0
  /\ sealed = FALSE /\ warden = FALSE /\ launched = FALSE /\ seam = FALSE /\ taken = 0
  /\ held = {} /\ snap = {} /\ scrapless = FALSE
  /\ tPhase = "idle" /\ tKind = "none" /\ tWord = 0 /\ tCb = "none"
  /\ pickLost = FALSE /\ svHeld = {} /\ svCleared = FALSE /\ svStage = 0

\* ---- pieces used inside actions (not actions themselves) ----

\* flow._untake: a running seam take is told "no part".
Untaken(guard) == IF guard /\ seam /\ TakeBusy THEN 0 ELSE tWord

\* flow.enter_stage: the checkpoint is taken, the stage is sealed with its Warden, the entrance is saved.
EnterStage(s, parts) ==
  /\ stage' = s /\ launched' = FALSE /\ snap' = parts /\ held' = parts
  /\ sealed' = TRUE /\ warden' = TRUE /\ fs' = "STAGE"
  /\ svHeld' = parts /\ svCleared' = FALSE /\ svStage' = s

\* flow._finish_stage: the next stage, or the boss arena after the world's last stage.
FinishStage(parts) ==
  IF stage = Stages
  THEN /\ fs' = "BOSS" /\ snap' = parts /\ held' = parts /\ launched' = launched
       /\ UNCHANGED <<stage, sealed, warden, svHeld, svCleared, svStage>>
  ELSE EnterStage(stage + 1, parts)

\* flow._end_run: the run is over for good; run_ended fires.
EndRun ==
  /\ tWord' = Untaken(UntakeOnEnd)
  /\ over' = TRUE /\ ended' = (IF ended < 2 THEN ended + 1 ELSE ended) /\ fs' = "SUMMARY"

\* ---- the player and the title ----

\* flow.press_start
PressStart ==
  /\ fs \in {"TITLE", "SUMMARY"} /\ KeysHeard
  /\ fs' = "CLASS_SELECT"
  /\ UNCHANGED <<stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* game.pick_pilot: launch_take.play(on_cover = choose_class). A busy take refuses and drops on_cover.
PickPilot ==
  /\ fs = "CLASS_SELECT" /\ KeysHeard
  /\ IF TakeBusy
     THEN \* dropped. A second press while this pick's own take still owes its choose loses nothing.
          /\ pickLost' = (pickLost \/ ~(tKind = "pilot" /\ tCb = "choose"))
          /\ UNCHANGED <<tPhase, tKind, tWord, tCb>>
     ELSE /\ tPhase' = "wind" /\ tKind' = "pilot" /\ tWord' = 0 /\ tCb' = "choose"
          /\ UNCHANGED pickLost
  /\ UNCHANGED <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, svHeld, svCleared, svStage>>

\* flow._begin_run, then enter_stage(1). It clears _taken_part. It does not touch _seam_take.
BeginRun ==
  /\ run < MaxRuns
  /\ run' = run + 1 /\ over' = FALSE /\ ended' = 0 /\ taken' = 0
  /\ scrapless' \in BOOLEAN
  /\ tWord' = Untaken(UntakeOnNewRun)
  /\ EnterStage(1, {})
  /\ UNCHANGED <<seam, tPhase, tKind, tCb, pickLost>>

\* flow.new_run: N on the death screen and the summary (screen keys), and in play the pause menu's Restart
\* (pause_menu.gd) and, with a store, an R held for RESTART_HOLD (game.gd). The two in-play ways are not
\* screen keys, so the swipe does not stop them.
NewRun ==
  /\ run > 0
  /\ (fs \in {"DEAD", "SUMMARY"} /\ KeysHeard) \/ InPlay
  /\ BeginRun

\* flow.show_title: Camp from the summary (screens.open_camp_from_summary), Escape from pilot select and
\* from the death screen (screens._input). The pause menu has no way to the title.
ShowTitle ==
  /\ fs \in {"CLASS_SELECT", "SUMMARY", "DEAD"} /\ KeysHeard
  /\ fs' = "TITLE"
  /\ UNCHANGED <<stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* flow.resume_run (Continue): the saved document comes back; a cleared stage lands its flight.
Resume ==
  /\ Store /\ fs = "TITLE" /\ KeysHeard /\ run > 0 /\ ~over /\ svStage > 0
  /\ taken' = 0 /\ snap' = svHeld /\ held' = svHeld
  /\ IF svCleared /\ svStage = Stages
     THEN /\ fs' = "BOSS" /\ stage' = svStage
          /\ UNCHANGED <<launched, sealed, warden, svHeld, svCleared, svStage>>
     ELSE LET s == IF svCleared THEN svStage + 1 ELSE svStage
          IN /\ stage' = s /\ launched' = FALSE /\ sealed' = TRUE /\ warden' = TRUE /\ fs' = "STAGE"
             /\ svHeld' = svHeld /\ svCleared' = FALSE /\ svStage' = s
  /\ UNCHANGED <<run, over, ended, seam, scrapless, tPhase, tKind, tWord, tCb, pickLost>>

\* ---- a stage ----

\* flow's tick: the ring starts to charge.
ToBeacon ==
  /\ fs = "STAGE" /\ fs' = "BEACON"
  /\ UNCHANGED <<stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* flow._on_enemy_killed -> _unseal: the Warden breaks and the gates open.
WardenBroken ==
  /\ fs \in {"STAGE", "BEACON"} /\ sealed /\ warden
  /\ StageOutlastsSwipe => ~TakeBusy
  /\ sealed' = FALSE /\ warden' = FALSE /\ fs' = "GATES"
  /\ UNCHANGED <<stage, run, over, ended, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* The Warden's node leaves the tree with no kill recorded (a seam fault somewhere else).
WardenFreed ==
  /\ fs \in {"STAGE", "BEACON"} /\ sealed /\ warden
  /\ warden' = FALSE
  /\ UNCHANGED <<fs, stage, run, over, ended, sealed, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* flow's tick -> _warden_vanished -> _unseal.
WardenVanished ==
  /\ VanishGuard
  /\ StageOutlastsSwipe => ~TakeBusy
  /\ fs \in {"STAGE", "BEACON"} /\ sealed /\ ~warden
  /\ sealed' = FALSE /\ fs' = "GATES"
  /\ UNCHANGED <<stage, run, over, ended, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* One gate choice. world.gd launches inside the reward_chosen signal, so flow hears reward_chosen and
\* launched in one synchronous emission, in either order (launchFirst). build grants the part in the same
\* emission. flow._on_reward_chosen, flow._on_launched, flow._play_seam_take, game.play_launch_take.
GateTaken(launchFirst) ==
  /\ fs = "GATES"
  /\ LET id      == PartOf(run, stage)
         granted == IF scrapless THEN 0 ELSE id
         parts   == IF scrapless THEN held ELSE held \cup {id}
         starts  == (stage # Stages) /\ ~TakeBusy     \* a take really starts
         plays   == IF BusyRefuses THEN starts ELSE (stage # Stages)   \* what _play_seam_take returns
         spend(t) == 0                                 \* _play_seam_take always empties _taken_part
     IN /\ held' = parts
        /\ fs' = "LAUNCH" /\ launched' = TRUE
        /\ svHeld' = parts /\ svCleared' = TRUE /\ svStage' = stage
        /\ seam' = plays
        /\ IF launchFirst
           THEN \* _on_launched first: the take starts with the old _taken_part; then _on_reward_chosen
                \* stamps it (when a seam take is running) or keeps the id in _taken_part.
                IF starts
                THEN /\ tPhase' = "wind" /\ tKind' = "seam" /\ tCb' = "cut"
                     /\ tWord' = granted /\ taken' = spend(taken)
                ELSE /\ UNCHANGED <<tPhase, tKind, tCb>>
                     /\ tWord' = IF plays /\ TakeBusy THEN granted ELSE tWord
                     /\ taken' = IF plays THEN spend(taken) ELSE granted
           ELSE \* _on_reward_chosen first: a true _seam_take stamps whatever take is running and leaves
                \* _taken_part alone; a false one keeps the id. Then _on_launched hands _taken_part over.
                LET t1 == IF seam THEN taken ELSE granted
                    w1 == IF seam /\ TakeBusy THEN granted ELSE tWord
                IN IF starts
                   THEN /\ tPhase' = "wind" /\ tKind' = "seam" /\ tCb' = "cut"
                        /\ tWord' = t1 /\ taken' = spend(t1)
                   ELSE /\ UNCHANGED <<tPhase, tKind, tCb>> /\ tWord' = w1 /\ taken' = spend(t1)
  /\ UNCHANGED <<stage, run, over, ended, sealed, warden, snap, scrapless, pickLost>>

\* flow's tick in LAUNCH: with no take, the flight's end finishes the stage.
FlightEnds ==
  /\ fs = "LAUNCH" /\ launched /\ ~seam
  /\ FinishStage(held)
  /\ UNCHANGED <<run, over, ended, seam, taken, scrapless, tPhase, tKind, tWord, tCb, pickLost>>

\* ---- the launch swipe (launch_take.advance; it runs through a pause) ----

TakeWind ==
  /\ tPhase = "wind" /\ tPhase' = "cover"
  /\ UNCHANGED <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* Full cover: on_cover runs once. "cut" is flow._cut_under_cover; "choose" is game.pick_pilot's closure.
TakeCover ==
  /\ tPhase = "cover" /\ tPhase' = "hold" /\ tCb' = "none"
  /\ IF tCb = "cut"
     THEN /\ seam' = FALSE
          /\ IF fs = "LAUNCH" /\ launched
             THEN FinishStage(held)
             ELSE UNCHANGED <<fs, stage, launched, held, snap, sealed, warden, svHeld, svCleared, svStage>>
          /\ UNCHANGED <<run, over, ended, taken, scrapless, tWord>>
     ELSE IF tCb = "choose" /\ fs = "CLASS_SELECT" /\ run < MaxRuns
          THEN /\ run' = run + 1 /\ over' = FALSE /\ ended' = 0 /\ taken' = 0
               /\ scrapless' \in BOOLEAN
               /\ tWord' = Untaken(UntakeOnNewRun)
               /\ EnterStage(1, {})
               /\ UNCHANGED seam
          ELSE UNCHANGED <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                           scrapless, tWord, svHeld, svCleared, svStage>>
  /\ UNCHANGED <<tKind, pickLost>>

TakeHold ==
  /\ tPhase = "hold" /\ tPhase' = "reveal"
  /\ UNCHANGED <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* launch_take._end: idle again, the stamp is plain again.
TakeEnd ==
  /\ tPhase = "reveal" /\ tPhase' = "idle" /\ tKind' = "none" /\ tWord' = 0
  /\ UNCHANGED <<fs, stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tCb, pickLost, svHeld, svCleared, svStage>>

\* ---- interruptions ----

\* flow._on_player_died: with a store the run ends; without one the death screen shows.
Death ==
  /\ IF EndGuard THEN InPlay ELSE fs # "TITLE" /\ run > 0
  /\ IF Store
     THEN /\ EndRun
          /\ UNCHANGED <<stage, run, sealed, warden, launched, seam, taken, held, snap,
                         scrapless, tPhase, tKind, tCb, pickLost, svHeld, svCleared, svStage>>
     ELSE /\ fs' = "DEAD"
          /\ UNCHANGED <<stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                         scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

\* flow.retry_stage (store-less flows; the arena has its own retry, which calls no _untake).
Retry ==
  /\ ~Store /\ run > 0
  /\ fs \notin {"TITLE", "CLASS_SELECT", "SUMMARY", "VICTORY"}
  /\ IF fs = "BOSS"
     THEN /\ held' = snap
          /\ UNCHANGED <<fs, stage, launched, sealed, warden, tWord>>
     ELSE /\ tWord' = Untaken(UntakeOnRetry)
          /\ held' = snap /\ launched' = FALSE
          /\ sealed' = TRUE /\ warden' = TRUE /\ fs' = "STAGE"
          /\ UNCHANGED stage
  /\ UNCHANGED <<run, over, ended, seam, taken, snap, scrapless, tPhase, tKind, tCb, pickLost,
                 svHeld, svCleared, svStage>>

\* flow._on_boss_defeated, then the victory clock: flow._end_run_won -> _end_run(true).
BossDefeated ==
  /\ fs = "BOSS" /\ fs' = "VICTORY"
  /\ UNCHANGED <<stage, run, over, ended, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tWord, tCb, pickLost, svHeld, svCleared, svStage>>

VictoryEnds ==
  /\ fs = "VICTORY"
  /\ EndRun
  /\ UNCHANGED <<stage, run, sealed, warden, launched, seam, taken, held, snap,
                 scrapless, tPhase, tKind, tCb, pickLost, svHeld, svCleared, svStage>>

Next ==
  \/ PressStart \/ PickPilot \/ NewRun \/ ShowTitle \/ Resume
  \/ ToBeacon \/ WardenBroken \/ WardenFreed \/ WardenVanished
  \/ GateTaken(TRUE) \/ GateTaken(FALSE) \/ FlightEnds
  \/ TakeWind \/ TakeCover \/ TakeHold \/ TakeEnd
  \/ Death \/ Retry \/ BossDefeated \/ VictoryEnds

\* The game's own clocks always run: the flow's tick and the swipe.
Fair ==
  /\ WF_vars(WardenVanished) /\ WF_vars(FlightEnds)
  /\ WF_vars(TakeWind) /\ WF_vars(TakeCover) /\ WF_vars(TakeHold) /\ WF_vars(TakeEnd)

Spec == Init /\ [][Next]_vars /\ Fair

\* ---- what must hold ----

TypeOK ==
  /\ fs \in States /\ stage \in 0 .. Stages /\ run \in 0 .. MaxRuns
  /\ ended \in 0 .. 2 /\ taken \in PartIds /\ tWord \in PartIds
  /\ held \subseteq PartIds /\ snap \subseteq PartIds
  /\ tPhase \in {"idle", "wind", "cover", "hold", "reveal"}
  /\ tKind \in {"none", "pilot", "seam"} /\ tCb \in {"none", "cut", "choose"}

\* P1. When the swipe closes over a launch, it names a part only if the live run holds it.
TakeNamesHeldPart == (tPhase = "cover" /\ tKind = "seam" /\ tWord # 0) => (tWord \in held /\ ~over)

\* P7. A pilot pick's swipe never carries a part's name.
StampOnlySeam == (tKind = "pilot") => (tWord = 0)

\* P2. flow._seam_take is true only while a seam take still owes its cut.
SeamOwned == seam => (tKind = "seam" /\ tCb = "cut")

\* P3. run_ended fires at most once for a run.
EndsOnce == ended <= 1

\* P4. A pilot pick is never silently dropped.
PickHeard == ~pickLost

\* P5. A launch always lands: the flight never waits for a cut nobody will make.
LaunchLands == (fs = "LAUNCH" /\ launched) ~> ~(fs = "LAUNCH" /\ launched)

\* P6. A sealed stage whose Warden is gone opens.
WardenGoneOpens == (fs \in {"STAGE", "BEACON"} /\ sealed /\ ~warden) ~> ~(fs \in {"STAGE", "BEACON"} /\ sealed /\ ~warden)
=============================================================================
