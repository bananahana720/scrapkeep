---------------------------- MODULE Rewards ----------------------------
(* How Scrapkeep banks one earned reward (an achievement row whose reward is a
   cosmetic, pilot or world unlock), across crashes, failed saves, two game
   processes on one profile and a run file written by an older build.
   references/rewards-coverage.md has the file and line behind every action and
   variable. Paths are under sketches/core-loop/src.

   One reward id stands for every id: ids do not interact. Its two settle keys are
   kept apart: the targeted key reward:<row>:<kind>:<target> (K) and the legacy key
   reward:<row>:<kind> (L) that builds before 8 November 2026 settled alone.
   progress.gd _grant_reward settles L beside K, and honours an L that has no
   targeted key as already paid.

   A game process runs one synchronous call at a time. The rest of the current
   call is the queue todo[p]; each file write in it is its own step, so another
   process or a crash can come between two writes but never inside one
   (safe_store.gd write_atomic renames a finished temp file). *)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
  Procs,             \* the game processes sharing one user:// folder
  MaxCrashes,        \* bound on crashes in the middle of a call
  MaxFails,          \* bound on failed file writes (disk full, a refused save)
  MaxGen,            \* bound on file generations (state constraint only)
  OldRun,            \* the start may be what an older build left: a live run file holding L alone
  \* Behaviour of the code. A config that flips one is a variant.
  ReconcileCopies,   \* which run-file settled ids progress.reconcile_settled copies into the profile:
                     \* "all" (before pull request 1093), "ledger" (ledger.found.* ids, never reward:* keys)
  LedgerChecked,     \* _grant_reward and grant_once refuse a key already settled
  GrantSavesOnce,    \* grant_once saves once, after the unlock (FALSE: it saves between settle and unlock)
  LegacyFromProfile, \* the legacy branch honours L only from the profile (FALSE: from the run's list too)
  PayAgainstFile,    \* an earn and a grant first take in the profile file (FALSE: they decide on memory)
  SaveLock           \* profile saves and those decisions hold the profile's save lock

VARIABLES
  dEarned, dK, dL, dUnlock, dGen,    \* profile.json on disk: achievement, the two keys, the unlock, generation
  rDoc, rK, rL, rGenD,               \* run.json on disk: "none", "live" or "tomb"; the run's two keys; generation
  up,                                \* per process: "down", "title" (no run in play) or "run"
  mEarned, mK, mL, mUnlock, pGen,    \* per process: profile._doc in memory and its generation
  mRunK, mRunL,                      \* per process: ctx.run.settled holds K, L
  rGen,                              \* per process: run_store._generation
  todo,                              \* per process: the file steps left in the current synchronous call
  nx,                                \* per process: the document profile.save() read and is about to write
  lk,                                \* the profile's save lock: a process or "none"
  pend,                              \* ghost, per process: a grant made in memory that no save has written yet
  landed,                            \* ghost: how many grants a profile save has written to disk
  crashes, fails, continued          \* ghosts: bounds and history for the reach probes

vars == <<dEarned, dK, dL, dUnlock, dGen, rDoc, rK, rL, rGenD, up, mEarned, mK, mL, mUnlock, pGen,
          mRunK, mRunL, rGen, todo, nx, lk, pend, landed, crashes, fails, continued>>
disk == <<dEarned, dK, dL, dUnlock, dGen, rDoc, rK, rL, rGenD>>
prof == <<dEarned, dK, dL, dUnlock, dGen>>
runf == <<rDoc, rK, rL, rGenD>>
mem == <<mEarned, mK, mL, mUnlock, pGen>>
ghosts == <<pend, landed, crashes, fails, continued>>

Max(a, b) == IF a > b THEN a ELSE b
Steps == {"B", "G", "U", "P", "W", "X", "R", "C"}
NoDoc == [e |-> FALSE, k |-> FALSE, l |-> FALSE, u |-> FALSE, g |-> 0]

TypeOK ==
  /\ {dEarned, dK, dL, dUnlock, rK, rL} \subseteq BOOLEAN /\ dGen \in Nat /\ rGenD \in Nat
  /\ rDoc \in {"none", "live", "tomb"}
  /\ up \in [Procs -> {"down", "title", "run"}]
  /\ mEarned \in [Procs -> BOOLEAN] /\ mK \in [Procs -> BOOLEAN] /\ mL \in [Procs -> BOOLEAN]
  /\ mUnlock \in [Procs -> BOOLEAN] /\ pGen \in [Procs -> Nat]
  /\ mRunK \in [Procs -> BOOLEAN] /\ mRunL \in [Procs -> BOOLEAN] /\ rGen \in [Procs -> Nat]
  /\ \A p \in Procs : todo[p] \in Seq(Steps)
  /\ lk \in Procs \cup {"none"}
  /\ pend \in [Procs -> BOOLEAN] /\ landed \in Nat /\ crashes \in Nat /\ fails \in Nat

\* What an older build may have left (OldRun): a live run file whose settled list holds L alone, beside
\* a profile that either never saved the earn or saved it with L and the unlock in one write.
Init ==
  /\ dK = FALSE
  /\ \/ /\ dEarned = FALSE /\ dL = FALSE /\ dUnlock = FALSE /\ dGen = 0
        /\ rDoc = "none" /\ rK = FALSE /\ rL = FALSE /\ rGenD = 0
     \/ /\ OldRun
        /\ rDoc = "live" /\ rK = FALSE /\ rL = TRUE /\ rGenD = 1
        /\ \E paid \in BOOLEAN : dEarned = paid /\ dL = paid /\ dUnlock = paid /\ dGen = IF paid THEN 1 ELSE 0
  /\ up = [p \in Procs |-> "down"]
  /\ mEarned = [p \in Procs |-> FALSE] /\ mK = [p \in Procs |-> FALSE] /\ mL = [p \in Procs |-> FALSE]
  /\ mUnlock = [p \in Procs |-> FALSE] /\ pGen = [p \in Procs |-> 0]
  /\ mRunK = [p \in Procs |-> FALSE] /\ mRunL = [p \in Procs |-> FALSE] /\ rGen = [p \in Procs |-> 0]
  /\ todo = [p \in Procs |-> <<>>] /\ nx = [p \in Procs |-> NoDoc] /\ lk = "none"
  /\ pend = [p \in Procs |-> FALSE] /\ landed = 0 /\ crashes = 0 /\ fails = 0 /\ continued = FALSE

Idle(p) == todo[p] = <<>>
At(p, s) == todo[p] # <<>> /\ Head(todo[p]) = s
Then(p, more) == todo' = [todo EXCEPT ![p] = more \o Tail(todo[p])]

\* profile.transact takes in the file: when its generation is not the one held, memory becomes the
\* merge of both (a union) (profile.gd _take_in, the same merge save() makes).
Fresh(p) == dGen # pGen[p]
InE(p) == mEarned[p] \/ (Fresh(p) /\ dEarned)
InK(p) == mK[p] \/ (Fresh(p) /\ dK)
InL(p) == mL[p] \/ (Fresh(p) /\ dL)
InU(p) == mUnlock[p] \/ (Fresh(p) /\ dUnlock)
InG(p) == IF Fresh(p) THEN Max(pGen[p], dGen) ELSE pGen[p]

\* ---- the player and the game: actions that start a synchronous call ----

\* game.gd starts: profile.load_profile, the title's run_store.load, then progress.setup, whose
\* backfill_rewards pays an earned row the ledger does not hold (step B).
Launch(p) ==
  /\ up[p] = "down"
  /\ up' = [up EXCEPT ![p] = "title"]
  /\ mEarned' = [mEarned EXCEPT ![p] = dEarned] /\ mK' = [mK EXCEPT ![p] = dK]
  /\ mL' = [mL EXCEPT ![p] = dL] /\ mUnlock' = [mUnlock EXCEPT ![p] = dUnlock]
  /\ pGen' = [pGen EXCEPT ![p] = dGen]
  /\ mRunK' = [mRunK EXCEPT ![p] = FALSE] /\ mRunL' = [mRunL EXCEPT ![p] = FALSE]
  /\ rGen' = [rGen EXCEPT ![p] = IF rDoc = "none" THEN 0 ELSE rGenD]
  /\ todo' = [todo EXCEPT ![p] = <<"B">>]
  /\ UNCHANGED <<disk, nx, lk, ghosts>>

\* flow._begin_run: the door save (_save_profile), ctx.run.begin clears the settled list, then
\* enter_stage(1) saves the entrance (_save -> run_store.save).
NewRun(p) ==
  /\ up[p] = "title" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "run"]
  /\ mRunK' = [mRunK EXCEPT ![p] = FALSE] /\ mRunL' = [mRunL EXCEPT ![p] = FALSE]
  /\ todo' = [todo EXCEPT ![p] = <<"P", "R">>]
  /\ UNCHANGED <<disk, mem, rGen, nx, lk, ghosts>>

\* A fact meets the row: progress._evaluate -> _earn: profile.earn, then _grant_reward (step G, which
\* adds grant_once's save when it grants), then _earn's own profile save. With PayAgainstFile the whole
\* earn is one profile.transact: it takes the save lock (SaveLock) and takes in the file first, and a row
\* the file already holds as earned is adopted and neither announced nor paid.
Earn(p) ==
  /\ up[p] = "run" /\ Idle(p) /\ ~mEarned[p]
  /\ IF PayAgainstFile
     THEN /\ ~SaveLock \/ lk = "none"
          /\ mK' = [mK EXCEPT ![p] = InK(p)] /\ mL' = [mL EXCEPT ![p] = InL(p)]
          /\ mUnlock' = [mUnlock EXCEPT ![p] = InU(p)] /\ pGen' = [pGen EXCEPT ![p] = InG(p)]
          /\ mEarned' = [mEarned EXCEPT ![p] = TRUE]
          /\ IF InE(p)
             THEN UNCHANGED <<todo, lk>>
             ELSE /\ todo' = [todo EXCEPT ![p] = <<"G", "P">> \o (IF SaveLock THEN <<"X">> ELSE <<>>)]
                  /\ lk' = IF SaveLock THEN p ELSE lk
     ELSE /\ mEarned' = [mEarned EXCEPT ![p] = TRUE]
          /\ todo' = [todo EXCEPT ![p] = <<"G", "P">>]
          /\ UNCHANGED <<mK, mL, mUnlock, pGen, lk>>
  /\ UNCHANGED <<disk, up, mRunK, mRunL, rGen, nx, ghosts>>

\* A run file save point: flow.enter_stage, _save_boss_won (PF-55) or _on_death_saved, each
\* through flow._save, whose _persist_companion may save the profile first.
Checkpoint(p) ==
  /\ up[p] = "run" /\ Idle(p)
  /\ \E pre \in {<<>>, <<"P">>} : todo' = [todo EXCEPT ![p] = pre \o <<"R">>]
  /\ UNCHANGED <<disk, up, mem, mRunK, mRunL, rGen, nx, lk, ghosts>>

\* The run ends, won or lost: flow._record_end clears the run file to a tombstone (step C),
\* then run_ended reaches progress, which saves the profile (SAVE_POINTS).
EndRun(p) ==
  /\ up[p] = "run" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "title"]
  /\ todo' = [todo EXCEPT ![p] = <<"C", "P">>]
  /\ UNCHANGED <<disk, mem, mRunK, mRunL, rGen, nx, lk, ghosts>>

\* Continue at the title: flow.resume_run loads the run file (run_state.from_entrance_doc restores
\* settled), progress.reconcile_settled copies the profile's ids into the run's list and the run's
\* ledger ids into the profile (never its reward keys, under "ledger") and saves when the profile
\* gained one, then the resumed stage saves its entrance.
Continue(p) ==
  /\ up[p] = "title" /\ Idle(p) /\ rDoc = "live"
  /\ LET addK == ReconcileCopies = "all" /\ rK /\ ~mK[p]
         addL == ReconcileCopies = "all" /\ rL /\ ~mL[p]
     IN /\ mK' = [mK EXCEPT ![p] = mK[p] \/ addK]
        /\ mL' = [mL EXCEPT ![p] = mL[p] \/ addL]
        /\ mRunK' = [mRunK EXCEPT ![p] = rK \/ mK[p]]
        /\ mRunL' = [mRunL EXCEPT ![p] = rL \/ mL[p]]
        /\ \E ledgerAdded \in IF ReconcileCopies = "ledger" THEN BOOLEAN ELSE {FALSE} :
             todo' = [todo EXCEPT ![p] = IF addK \/ addL \/ ledgerAdded THEN <<"P", "R">> ELSE <<"R">>]
  /\ up' = [up EXCEPT ![p] = "run"]
  /\ rGen' = [rGen EXCEPT ![p] = rGenD]
  /\ continued' = TRUE
  /\ UNCHANGED <<disk, mEarned, mUnlock, pGen, nx, lk, pend, landed, crashes, fails>>

\* The game closes between calls. Memory is gone; a grant no save wrote is gone with it.
Quit(p) ==
  /\ up[p] # "down" /\ Idle(p)
  /\ up' = [up EXCEPT ![p] = "down"]
  /\ mEarned' = [mEarned EXCEPT ![p] = FALSE] /\ mK' = [mK EXCEPT ![p] = FALSE]
  /\ mL' = [mL EXCEPT ![p] = FALSE] /\ mUnlock' = [mUnlock EXCEPT ![p] = FALSE]
  /\ pGen' = [pGen EXCEPT ![p] = 0]
  /\ mRunK' = [mRunK EXCEPT ![p] = FALSE] /\ mRunL' = [mRunL EXCEPT ![p] = FALSE]
  /\ rGen' = [rGen EXCEPT ![p] = 0]
  /\ nx' = [nx EXCEPT ![p] = NoDoc] /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ UNCHANGED <<disk, todo, lk, landed, crashes, fails, continued>>

\* The process dies with file steps still to do in its call. A save lock it held is broken by the
\* next game that finds it stale (profile.gd _lock), as if released here.
Crash(p) ==
  /\ up[p] # "down" /\ ~Idle(p) /\ crashes < MaxCrashes
  /\ up' = [up EXCEPT ![p] = "down"]
  /\ mEarned' = [mEarned EXCEPT ![p] = FALSE] /\ mK' = [mK EXCEPT ![p] = FALSE]
  /\ mL' = [mL EXCEPT ![p] = FALSE] /\ mUnlock' = [mUnlock EXCEPT ![p] = FALSE]
  /\ pGen' = [pGen EXCEPT ![p] = 0]
  /\ mRunK' = [mRunK EXCEPT ![p] = FALSE] /\ mRunL' = [mRunL EXCEPT ![p] = FALSE]
  /\ rGen' = [rGen EXCEPT ![p] = 0]
  /\ nx' = [nx EXCEPT ![p] = NoDoc] /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ todo' = [todo EXCEPT ![p] = <<>>]
  /\ lk' = IF lk = p THEN "none" ELSE lk
  /\ crashes' = crashes + 1
  /\ UNCHANGED <<disk, landed, fails, continued>>

\* ---- the steps inside a call ----

\* progress.setup -> backfill_rewards: an earned row goes to _grant_reward.
StepB(p) ==
  /\ At(p, "B")
  /\ Then(p, IF mEarned[p] THEN <<"G">> ELSE <<>>)
  /\ UNCHANGED <<disk, up, mem, mRunK, mRunL, rGen, nx, lk, ghosts>>

\* progress._grant_reward and grant_once. With PayAgainstFile it is one profile.transact: the save lock
\* (taken here unless the earn around it holds it) and the file taken in. Then, on the lists held:
\*   - L held and no targeted key: the legacy branch settles K and pays nothing (the old build paid).
\*     It reads L from the profile only under LegacyFromProfile, else from the run's list as well.
\*   - K held: refused, nothing saved here.
\*   - else settle L and K in both lists, apply the unlock and save (grant_once).
StepG(p) ==
  /\ At(p, "G")
  /\ LET locking == PayAgainstFile /\ SaveLock /\ lk # p
         eK == IF PayAgainstFile THEN InK(p) ELSE mK[p]
         eL == IF PayAgainstFile THEN InL(p) ELSE mL[p]
         eU == IF PayAgainstFile THEN InU(p) ELSE mUnlock[p]
         eE == IF PayAgainstFile THEN InE(p) ELSE mEarned[p]
         eG == IF PayAgainstFile THEN InG(p) ELSE pGen[p]
         release == IF locking THEN <<"X">> ELSE <<>>
         legacy == (IF LegacyFromProfile THEN eL ELSE eL \/ mRunL[p]) /\ ~(eK \/ mRunK[p])
         held == eK \/ mRunK[p]
     IN /\ ~locking \/ lk = "none"
        /\ lk' = IF locking THEN p ELSE lk
        /\ mEarned' = [mEarned EXCEPT ![p] = eE] /\ pGen' = [pGen EXCEPT ![p] = eG]
        /\ IF LedgerChecked /\ legacy
           THEN /\ mK' = [mK EXCEPT ![p] = TRUE] /\ mRunK' = [mRunK EXCEPT ![p] = TRUE]
                /\ mL' = [mL EXCEPT ![p] = eL] /\ mUnlock' = [mUnlock EXCEPT ![p] = eU]
                /\ Then(p, release)
                /\ UNCHANGED <<mRunL, pend>>
           ELSE IF LedgerChecked /\ held
           THEN /\ mK' = [mK EXCEPT ![p] = eK] /\ mL' = [mL EXCEPT ![p] = eL]
                /\ mUnlock' = [mUnlock EXCEPT ![p] = eU]
                /\ Then(p, release)
                /\ UNCHANGED <<mRunK, mRunL, pend>>
           ELSE /\ mK' = [mK EXCEPT ![p] = TRUE] /\ mL' = [mL EXCEPT ![p] = TRUE]
                /\ mRunK' = [mRunK EXCEPT ![p] = TRUE] /\ mRunL' = [mRunL EXCEPT ![p] = TRUE]
                /\ IF GrantSavesOnce
                   THEN /\ mUnlock' = [mUnlock EXCEPT ![p] = TRUE]
                        /\ pend' = [pend EXCEPT ![p] = TRUE]
                        /\ Then(p, <<"P">> \o release)
                   ELSE /\ mUnlock' = [mUnlock EXCEPT ![p] = eU]
                        /\ Then(p, <<"P", "U", "P">> \o release)
                        /\ UNCHANGED pend
  /\ UNCHANGED <<disk, up, rGen, nx, landed, crashes, fails, continued>>

\* The unlock applied after a save, in the broken variant only.
StepU(p) ==
  /\ At(p, "U")
  /\ mUnlock' = [mUnlock EXCEPT ![p] = TRUE]
  /\ pend' = [pend EXCEPT ![p] = TRUE]
  /\ Then(p, <<>>)
  /\ UNCHANGED <<disk, up, mEarned, mK, mL, pGen, mRunK, mRunL, rGen, nx, lk, landed, crashes, fails, continued>>

\* profile.save, first half: take the save lock unless this call holds it (SaveLock), _read, and merge
\* when the file's generation is not the one held.
StepP(p) ==
  /\ At(p, "P")
  /\ LET locking == SaveLock /\ lk # p
     IN /\ ~locking \/ lk = "none"
        /\ lk' = IF locking THEN p ELSE lk
        /\ Then(p, IF locking THEN <<"W", "X">> ELSE <<"W">>)
  /\ nx' = [nx EXCEPT ![p] = [e |-> InE(p), k |-> InK(p), l |-> InL(p), u |-> InU(p), g |-> InG(p)]]
  /\ UNCHANGED <<disk, up, mem, mRunK, mRunL, rGen, ghosts>>

\* profile.save, second half: SafeStore.write_atomic, and _doc becomes what was written.
StepW(p) ==
  /\ At(p, "W")
  /\ dEarned' = nx[p].e /\ dK' = nx[p].k /\ dL' = nx[p].l /\ dUnlock' = nx[p].u /\ dGen' = nx[p].g + 1
  /\ mEarned' = [mEarned EXCEPT ![p] = nx[p].e] /\ mK' = [mK EXCEPT ![p] = nx[p].k]
  /\ mL' = [mL EXCEPT ![p] = nx[p].l] /\ mUnlock' = [mUnlock EXCEPT ![p] = nx[p].u]
  /\ pGen' = [pGen EXCEPT ![p] = nx[p].g + 1]
  /\ landed' = IF pend[p] THEN landed + 1 ELSE landed
  /\ pend' = [pend EXCEPT ![p] = FALSE]
  /\ Then(p, <<>>)
  /\ nx' = [nx EXCEPT ![p] = NoDoc]
  /\ UNCHANGED <<runf, up, mRunK, mRunL, rGen, lk, crashes, fails, continued>>

\* The write fails and the old file stays; memory keeps what it had (save returns false).
FailW(p) ==
  /\ At(p, "W") /\ fails < MaxFails
  /\ fails' = fails + 1
  /\ Then(p, <<>>)
  /\ nx' = [nx EXCEPT ![p] = NoDoc]
  /\ UNCHANGED <<disk, up, mem, mRunK, mRunL, rGen, lk, pend, landed, crashes, continued>>

\* The save lock is let go at the end of the save or transaction that took it.
StepX(p) ==
  /\ At(p, "X")
  /\ lk' = "none"
  /\ Then(p, <<>>)
  /\ UNCHANGED <<disk, up, mem, mRunK, mRunL, rGen, nx, ghosts>>

\* run_store.save: refused over a newer tombstone; a newer live file is merged (merge keeps our
\* settled list); one atomic write. A failed write changes nothing.
StepR(p) ==
  /\ At(p, "R")
  /\ IF rDoc = "tomb" /\ rGenD > rGen[p]
     THEN UNCHANGED <<runf, rGen, fails>>
     ELSE LET now == IF rDoc = "live" /\ rGenD > rGen[p] THEN rGenD ELSE rGen[p]
          IN \/ /\ rDoc' = "live" /\ rK' = mRunK[p] /\ rL' = mRunL[p] /\ rGenD' = now + 1
                /\ rGen' = [rGen EXCEPT ![p] = now + 1]
                /\ UNCHANGED fails
             \/ /\ fails < MaxFails /\ fails' = fails + 1
                /\ UNCHANGED <<runf, rGen>>
  /\ Then(p, <<>>)
  /\ UNCHANGED <<prof, up, mem, mRunK, mRunL, nx, lk, pend, landed, crashes, continued>>

\* run_store.clear: a readable file becomes a tombstone one generation past the newest seen.
StepC(p) ==
  /\ At(p, "C")
  /\ LET seen == Max(rGen[p], IF rDoc = "none" THEN 0 ELSE rGenD)
     IN IF rDoc = "none"
        THEN /\ rGen' = [rGen EXCEPT ![p] = 0]
             /\ UNCHANGED <<runf, fails>>
        ELSE \/ /\ rDoc' = "tomb" /\ rK' = FALSE /\ rL' = FALSE /\ rGenD' = seen + 1
                /\ rGen' = [rGen EXCEPT ![p] = seen + 1]
                /\ UNCHANGED fails
             \/ /\ fails < MaxFails /\ fails' = fails + 1
                /\ rGen' = [rGen EXCEPT ![p] = 0]
                /\ UNCHANGED runf
  /\ Then(p, <<>>)
  /\ UNCHANGED <<prof, up, mem, mRunK, mRunL, nx, lk, pend, landed, crashes, continued>>

Next == \E p \in Procs :
  \/ Launch(p) \/ NewRun(p) \/ Earn(p) \/ Checkpoint(p) \/ EndRun(p) \/ Continue(p)
  \/ Quit(p) \/ Crash(p)
  \/ StepB(p) \/ StepG(p) \/ StepU(p) \/ StepP(p) \/ StepW(p) \/ FailW(p) \/ StepX(p)
  \/ StepR(p) \/ StepC(p)

Spec == Init /\ [][Next]_vars

Bounded == dGen <= MaxGen /\ rGenD <= MaxGen

\* ---- the rules ----

\* Banked at most once: no two profile saves each write a grant of the id that their own process made.
AtMostOnce == landed <= 1

\* Never lost. The profile file holds K, or L, settled without the unlock, and no running game holds the
\* unlock in memory. From there nothing grants it: every load and every take-in copies the file, merges
\* keep settled ids (a union), every grant path refuses a settled K, and the legacy branch counts an L
\* with no targeted key as paid. A game still inside a grant whose unlock is queued (step U) also holds it.
Unlocking(p) == \E i \in 1 .. Len(todo[p]) : todo[p][i] = "U"
Lost == (dK \/ dL) /\ ~dUnlock /\ \A p \in Procs : ~(up[p] # "down" /\ (mUnlock[p] \/ Unlocking(p)))
NeverLost == ~Lost

\* The lock is held only inside a call: a process that holds it has steps left.
LockInCall == lk = "none" \/ ~Idle(lk)

\* ---- reach probes: each says "never" about something that must be able to happen ----
ProbeLands == landed = 0
ProbeContinue == ~continued
ProbeFail == fails = 0
ProbeCrash == crashes = 0
ProbeTomb == rDoc # "tomb"
ProbeRunSettled == ~(rDoc = "live" /\ rK)
\* A continued run from an older build earns the row while its list holds L alone.
ProbeOldEarn == ~\E p \in Procs : up[p] = "run" /\ mEarned[p] /\ mRunL[p] /\ ~mRunK[p]
\* One game waits on the save lock the other holds.
ProbeLockWait == ~\E p, q \in Procs : p # q /\ lk = q /\ (At(p, "P") \/ At(p, "G"))
=============================================================================
