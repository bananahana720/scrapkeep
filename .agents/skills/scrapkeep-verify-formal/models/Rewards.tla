---------------------------- MODULE Rewards ----------------------------
(* How Scrapkeep banks one earned reward (an achievement row whose reward is a
   cosmetic, pilot or world unlock), across crashes, failed saves and two game
   processes on one profile. references/rewards-coverage.md has the file and
   line behind every action and variable. Paths are under sketches/core-loop/src.

   One reward id stands for every id: ids do not interact. The row's legacy
   settle key (progress.gd _grant_reward) is always settled in the same call as
   the targeted key, so the two are one flag here.

   A game process runs one synchronous call at a time. The rest of the current
   call is the queue todo[p]; each file write in it is its own step, so another
   process or a crash can come between two writes but never inside one
   (safe_store.gd write_atomic renames a finished temp file). *)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
  Procs,            \* the game processes sharing one user:// folder
  MaxCrashes,       \* bound on crashes in the middle of a call
  MaxFails,         \* bound on failed file writes (disk full, a refused save)
  MaxGen,           \* bound on file generations (state constraint only)
  \* Behaviour of today's code. A config that flips one is a variant.
  ReconcileImports, \* progress.reconcile_settled copies the run document's settled ids into the profile
  LedgerChecked,    \* _grant_reward and grant_once refuse an id the ledger already holds
  GrantSavesOnce    \* grant_once saves once, after the unlock (FALSE: it saves between settle and unlock)

VARIABLES
  dEarned, dSettled, dUnlock, dGen,  \* profile.json on disk: achievement, settled key, the unlock, generation
  rDoc, rSettled, rGenD,             \* run.json on disk: "none", "live" or "tomb"; the run's settled key; generation
  up,                                \* per process: "down", "title" (no run in play) or "run"
  mEarned, mSettled, mUnlock, pGen,  \* per process: profile._doc in memory and profile._loaded_generation
  mRunSettled,                       \* per process: ctx.run.settled holds the key
  rGen,                              \* per process: run_store._generation
  todo,                              \* per process: the file steps left in the current synchronous call
  nx,                                \* per process: the document profile.save() read and is about to write
  pend,                              \* ghost, per process: a grant made in memory that no save has written yet
  landed,                            \* ghost: how many grants a profile save has written to disk
  crashes, fails, continued          \* ghosts: bounds and history for the reach probes

vars == <<dEarned, dSettled, dUnlock, dGen, rDoc, rSettled, rGenD, up, mEarned, mSettled,
          mUnlock, pGen, mRunSettled, rGen, todo, nx, pend, landed, crashes, fails, continued>>
local == <<up, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, todo, nx, pend>>
disk == <<dEarned, dSettled, dUnlock, dGen, rDoc, rSettled, rGenD>>

Max(a, b) == IF a > b THEN a ELSE b
Steps == {"B", "G", "U", "P", "W", "R", "C"}
NoDoc == [e |-> FALSE, s |-> FALSE, u |-> FALSE, g |-> 0]

TypeOK ==
  /\ dEarned \in BOOLEAN /\ dSettled \in BOOLEAN /\ dUnlock \in BOOLEAN /\ dGen \in Nat
  /\ rDoc \in {"none", "live", "tomb"} /\ rSettled \in BOOLEAN /\ rGenD \in Nat
  /\ up \in [Procs -> {"down", "title", "run"}]
  /\ mEarned \in [Procs -> BOOLEAN] /\ mSettled \in [Procs -> BOOLEAN] /\ mUnlock \in [Procs -> BOOLEAN]
  /\ pGen \in [Procs -> Nat] /\ mRunSettled \in [Procs -> BOOLEAN] /\ rGen \in [Procs -> Nat]
  /\ \A p \in Procs : todo[p] \in Seq(Steps)
  /\ pend \in [Procs -> BOOLEAN] /\ landed \in Nat /\ crashes \in Nat /\ fails \in Nat

Init ==
  /\ dEarned = FALSE /\ dSettled = FALSE /\ dUnlock = FALSE /\ dGen = 0
  /\ rDoc = "none" /\ rSettled = FALSE /\ rGenD = 0
  /\ up = [p \in Procs |-> "down"]
  /\ mEarned = [p \in Procs |-> FALSE] /\ mSettled = [p \in Procs |-> FALSE]
  /\ mUnlock = [p \in Procs |-> FALSE] /\ pGen = [p \in Procs |-> 0]
  /\ mRunSettled = [p \in Procs |-> FALSE] /\ rGen = [p \in Procs |-> 0]
  /\ todo = [p \in Procs |-> <<>>] /\ nx = [p \in Procs |-> NoDoc]
  /\ pend = [p \in Procs |-> FALSE] /\ landed = 0 /\ crashes = 0 /\ fails = 0 /\ continued = FALSE

Idle(p) == todo[p] = <<>>
At(p, s) == todo[p] # <<>> /\ Head(todo[p]) = s
Then(p, more) == todo' = [todo EXCEPT ![p] = more \o Tail(todo[p])]

\* ---- the player and the game: actions that start a synchronous call ----

\* game.gd starts: profile.load_profile, the title's run_store.load, then progress.setup, whose
\* backfill_rewards pays an earned row the ledger does not hold (step B).
Launch(p) ==
  /\ up[p] = "down"
  /\ up' = [up EXCEPT ![p] = "title"]
  /\ mEarned' = [mEarned EXCEPT ![p] = dEarned]
  /\ mSettled' = [mSettled EXCEPT ![p] = dSettled]
  /\ mUnlock' = [mUnlock EXCEPT ![p] = dUnlock]
  /\ pGen' = [pGen EXCEPT ![p] = dGen]
  /\ mRunSettled' = [mRunSettled EXCEPT ![p] = FALSE]
  /\ rGen' = [rGen EXCEPT ![p] = IF rDoc = "none" THEN 0 ELSE rGenD]
  /\ todo' = [todo EXCEPT ![p] = <<"B">>]
  /\ UNCHANGED <<disk, nx, pend, landed, crashes, fails, continued>>

\* flow._begin_run: the door save (_save_profile), ctx.run.begin clears the settled list, then
\* enter_stage(1) saves the entrance (_save -> run_store.save).
NewRun(p) ==
  /\ up[p] = "title" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "run"]
  /\ mRunSettled' = [mRunSettled EXCEPT ![p] = FALSE]
  /\ todo' = [todo EXCEPT ![p] = <<"P", "R">>]
  /\ UNCHANGED <<disk, mEarned, mSettled, mUnlock, pGen, rGen, nx, pend, landed, crashes, fails, continued>>

\* A fact meets the row: progress._evaluate -> _earn: profile.earn, then _grant_reward (step G),
\* then _earn's own profile save.
Earn(p) ==
  /\ up[p] = "run" /\ Idle(p) /\ ~mEarned[p]
  /\ mEarned' = [mEarned EXCEPT ![p] = TRUE]
  /\ todo' = [todo EXCEPT ![p] = <<"G">>]
  /\ UNCHANGED <<disk, up, mSettled, mUnlock, pGen, mRunSettled, rGen, nx, pend, landed, crashes, fails, continued>>

\* A run document save point: flow.enter_stage, _save_boss_won (PF-55) or _on_death_saved, each
\* through flow._save, whose _persist_companion may save the profile first.
Checkpoint(p) ==
  /\ up[p] = "run" /\ Idle(p)
  /\ \E pre \in {<<>>, <<"P">>} : todo' = [todo EXCEPT ![p] = pre \o <<"R">>]
  /\ UNCHANGED <<disk, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, nx, pend, landed, crashes, fails, continued>>

\* The run ends, won or lost: flow._record_end clears the run document to a tombstone (step C),
\* then run_ended reaches progress, which saves the profile (SAVE_POINTS).
EndRun(p) ==
  /\ up[p] = "run" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "title"]
  /\ todo' = [todo EXCEPT ![p] = <<"C", "P">>]
  /\ UNCHANGED <<disk, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, nx, pend, landed, crashes, fails, continued>>

\* Continue at the title: flow.resume_run loads the run document (run_state.from_entrance_doc
\* restores settled), progress.reconcile_settled makes both lists one set and saves when the
\* profile gained an id, then the resumed stage saves its entrance.
Continue(p) ==
  /\ up[p] = "title" /\ Idle(p) /\ rDoc = "live"
  /\ LET added == ReconcileImports /\ rSettled /\ ~mSettled[p]
     IN /\ mSettled' = [mSettled EXCEPT ![p] = mSettled[p] \/ added]
        /\ mRunSettled' = [mRunSettled EXCEPT ![p] = rSettled \/ mSettled[p]]
        /\ todo' = [todo EXCEPT ![p] = IF added THEN <<"P", "R">> ELSE <<"R">>]
  /\ up' = [up EXCEPT ![p] = "run"]
  /\ rGen' = [rGen EXCEPT ![p] = rGenD]
  /\ continued' = TRUE
  /\ UNCHANGED <<disk, mEarned, mUnlock, pGen, nx, pend, landed, crashes, fails>>

\* The game closes between calls. Memory is gone; a grant no save wrote is gone with it.
Quit(p) ==
  /\ up[p] # "down" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "down"]
  /\ mEarned' = [mEarned EXCEPT ![p] = FALSE] /\ mSettled' = [mSettled EXCEPT ![p] = FALSE]
  /\ mUnlock' = [mUnlock EXCEPT ![p] = FALSE] /\ pGen' = [pGen EXCEPT ![p] = 0]
  /\ mRunSettled' = [mRunSettled EXCEPT ![p] = FALSE] /\ rGen' = [rGen EXCEPT ![p] = 0]
  /\ nx' = [nx EXCEPT ![p] = NoDoc] /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ UNCHANGED <<disk, todo, landed, crashes, fails, continued>>

\* The process dies with file steps still to do in its call.
Crash(p) ==
  /\ up[p] # "down" /\ ~Idle(p) /\ crashes < MaxCrashes
  /\ up' = [up EXCEPT ![p] = "down"]
  /\ mEarned' = [mEarned EXCEPT ![p] = FALSE] /\ mSettled' = [mSettled EXCEPT ![p] = FALSE]
  /\ mUnlock' = [mUnlock EXCEPT ![p] = FALSE] /\ pGen' = [pGen EXCEPT ![p] = 0]
  /\ mRunSettled' = [mRunSettled EXCEPT ![p] = FALSE] /\ rGen' = [rGen EXCEPT ![p] = 0]
  /\ nx' = [nx EXCEPT ![p] = NoDoc] /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ todo' = [todo EXCEPT ![p] = <<>>]
  /\ crashes' = crashes + 1
  /\ UNCHANGED <<disk, landed, fails, continued>>

\* ---- the steps inside a call ----

\* progress.setup -> backfill_rewards: an earned row goes to _grant_reward.
StepB(p) ==
  /\ At(p, "B")
  /\ Then(p, IF mEarned[p] THEN <<"G">> ELSE <<>>)
  /\ UNCHANGED <<disk, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, nx, pend, landed, crashes, fails, continued>>

\* progress._grant_reward and grant_once: refuse a key either list holds (_is_settled), else
\* settle it in both lists and apply the unlock. Every path ends in a profile save (grant_once's,
\* and _earn's; the two saves of one unchanged document are one step P here).
StepG(p) ==
  /\ At(p, "G")
  /\ IF LedgerChecked /\ (mSettled[p] \/ mRunSettled[p])
     THEN /\ Then(p, <<"P">>)
          /\ UNCHANGED <<mSettled, mRunSettled, mUnlock, pend>>
     ELSE /\ mSettled' = [mSettled EXCEPT ![p] = TRUE]
          /\ mRunSettled' = [mRunSettled EXCEPT ![p] = TRUE]
          /\ IF GrantSavesOnce
             THEN /\ mUnlock' = [mUnlock EXCEPT ![p] = TRUE]
                  /\ pend' = [pend EXCEPT ![p] = TRUE]
                  /\ Then(p, <<"P">>)
             ELSE /\ Then(p, <<"P", "U", "P">>)
                  /\ UNCHANGED <<mUnlock, pend>>
  /\ UNCHANGED <<disk, up, mEarned, pGen, rGen, nx, landed, crashes, fails, continued>>

\* The unlock applied after a save, in the broken variant only.
StepU(p) ==
  /\ At(p, "U")
  /\ mUnlock' = [mUnlock EXCEPT ![p] = TRUE]
  /\ pend' = [pend EXCEPT ![p] = TRUE]
  /\ Then(p, <<>>)
  /\ UNCHANGED <<disk, up, mEarned, mSettled, pGen, mRunSettled, rGen, nx, landed, crashes, fails, continued>>

\* profile.save, first half: _read, and merge when the file's generation is not the one loaded.
StepP(p) ==
  /\ At(p, "P")
  /\ LET merge == dGen # pGen[p]
     IN nx' = [nx EXCEPT ![p] =
                 [e |-> mEarned[p] \/ (merge /\ dEarned),
                  s |-> mSettled[p] \/ (merge /\ dSettled),
                  u |-> mUnlock[p] \/ (merge /\ dUnlock),
                  g |-> IF merge THEN Max(pGen[p], dGen) ELSE pGen[p]]]
  /\ Then(p, <<"W">>)
  /\ UNCHANGED <<disk, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, pend, landed, crashes, fails, continued>>

\* profile.save, second half: SafeStore.write_atomic, and _doc becomes what was written.
StepW(p) ==
  /\ At(p, "W")
  /\ dEarned' = nx[p].e /\ dSettled' = nx[p].s /\ dUnlock' = nx[p].u /\ dGen' = nx[p].g + 1
  /\ mEarned' = [mEarned EXCEPT ![p] = nx[p].e] /\ mSettled' = [mSettled EXCEPT ![p] = nx[p].s]
  /\ mUnlock' = [mUnlock EXCEPT ![p] = nx[p].u] /\ pGen' = [pGen EXCEPT ![p] = nx[p].g + 1]
  /\ landed' = IF pend[p] THEN landed + 1 ELSE landed
  /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ Then(p, <<>>)
  /\ nx' = [nx EXCEPT ![p] = NoDoc]
  /\ UNCHANGED <<rDoc, rSettled, rGenD, up, mRunSettled, rGen, crashes, fails, continued>>

\* The write fails and the old file stays; memory keeps what it had (save returns false).
FailW(p) ==
  /\ At(p, "W") /\ fails < MaxFails
  /\ fails' = fails + 1
  /\ Then(p, <<>>)
  /\ nx' = [nx EXCEPT ![p] = NoDoc]
  /\ UNCHANGED <<disk, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, rGen, pend, landed, crashes, continued>>

\* run_store.save: refused over a newer tombstone; a newer live file is merged (merge keeps our
\* settled list); one atomic write. A failed write changes nothing.
StepR(p) ==
  /\ At(p, "R")
  /\ IF rDoc = "tomb" /\ rGenD > rGen[p]
     THEN UNCHANGED <<rDoc, rSettled, rGenD, rGen, fails>>
     ELSE LET now == IF rDoc = "live" /\ rGenD > rGen[p] THEN rGenD ELSE rGen[p]
          IN \/ /\ rDoc' = "live" /\ rSettled' = mRunSettled[p] /\ rGenD' = now + 1
                /\ rGen' = [rGen EXCEPT ![p] = now + 1]
                /\ UNCHANGED fails
             \/ /\ fails < MaxFails /\ fails' = fails + 1
                /\ UNCHANGED <<rDoc, rSettled, rGenD, rGen>>
  /\ Then(p, <<>>)
  /\ UNCHANGED <<dEarned, dSettled, dUnlock, dGen, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, nx, pend, landed, crashes, continued>>

\* run_store.clear: a readable file becomes a tombstone one generation past the newest seen.
StepC(p) ==
  /\ At(p, "C")
  /\ LET seen == Max(rGen[p], IF rDoc = "none" THEN 0 ELSE rGenD)
     IN IF rDoc = "none"
        THEN /\ rGen' = [rGen EXCEPT ![p] = 0]
             /\ UNCHANGED <<rDoc, rSettled, rGenD, fails>>
        ELSE \/ /\ rDoc' = "tomb" /\ rSettled' = FALSE /\ rGenD' = seen + 1
                /\ rGen' = [rGen EXCEPT ![p] = seen + 1]
                /\ UNCHANGED fails
             \/ /\ fails < MaxFails /\ fails' = fails + 1
                /\ rGen' = [rGen EXCEPT ![p] = 0]
                /\ UNCHANGED <<rDoc, rSettled, rGenD>>
  /\ Then(p, <<>>)
  /\ UNCHANGED <<dEarned, dSettled, dUnlock, dGen, up, mEarned, mSettled, mUnlock, pGen, mRunSettled, nx, pend, landed, crashes, continued>>

Next == \E p \in Procs :
  \/ Launch(p) \/ NewRun(p) \/ Earn(p) \/ Checkpoint(p) \/ EndRun(p) \/ Continue(p)
  \/ Quit(p) \/ Crash(p)
  \/ StepB(p) \/ StepG(p) \/ StepU(p) \/ StepP(p) \/ StepW(p) \/ FailW(p) \/ StepR(p) \/ StepC(p)

Spec == Init /\ [][Next]_vars

Bounded == dGen <= MaxGen /\ rGenD <= MaxGen

\* ---- the rules ----

\* Banked at most once: no two profile saves each write a grant of the id.
AtMostOnce == landed <= 1

\* Never lost. The profile file holds the key settled without the unlock, and no running game
\* holds the unlock in memory. From there nothing grants it: every load copies the file
\* (profile.gd load_profile), merges keep settled ids (profile.gd merge, a union), and every grant
\* path refuses a settled key (progress.gd _grant_reward lines 107-111, grant_once line 215).
\* A game still inside a grant whose unlock is queued (step U) also holds it.
Unlocking(p) == \E i \in 1 .. Len(todo[p]) : todo[p][i] = "U"
Lost == dSettled /\ ~dUnlock /\ \A p \in Procs : ~(up[p] # "down" /\ (mUnlock[p] \/ Unlocking(p)))
NeverLost == ~Lost

\* ---- reach probes: each says "never" about something that must be able to happen ----
ProbeLands == landed = 0
ProbeContinue == ~continued
ProbeFail == fails = 0
ProbeCrash == crashes = 0
ProbeTomb == rDoc # "tomb"
ProbeRunSettled == ~(rDoc = "live" /\ rSettled)
=============================================================================
