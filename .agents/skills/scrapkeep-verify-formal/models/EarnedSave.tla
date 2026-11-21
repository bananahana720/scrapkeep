----------------------------- MODULE EarnedSave -----------------------------
(* The earned save (the Spare Frame part) and the run document that must carry its spend:
   sketches/core-loop/src/core/run_state.gd _try_death_save and to_entrance_doc / from_entrance_doc,
   sketches/core-loop/src/core/flow.gd _on_death_saved, _save, _flush_save_spend and its callers, enter_stage,
   _on_launched, _record_end, resume_run and _begin_run (from the title, the summary, the pause menu's Restart in
   sketches/core-loop/src/ui/pause_menu.gd and the held R in sketches/core-loop/src/game.gd step_restart_hold), and
   sketches/core-loop/src/core/run_store.gd save, load and clear. references/earnedsave-coverage.md has the code behind
   every step.

   A write can be refused (store.save returns write_failed, or store.clear cannot write its tombstone, and the file
   keeps its last document); the game can be quit to the desktop between any two steps; a later launch, or the same
   process from the title, can Continue the run on disk. *)
EXTENDS Naturals

CONSTANTS
  MaxFails,        \* run writes (saves and clears) that may be refused in one behaviour
  MaxWrites,       \* stage entrances, launches and Continues a behaviour may write (bounds the model)
  SpendWrite,      \* _on_death_saved writes the entrance with death_save_spent
  SpendOwed,       \* _save_spend_owed: a refused spend stays owed, every later _save carries it, show_title and
                   \* retry_stage flush it (the ES-1 fix, P7)
  OwedOnExit,      \* the same flush in _exit_tree and on NOTIFICATION_WM_CLOSE_REQUEST
  OwedOnResume,    \* resume_run in the same process sets death_save_spent on the doc and the run while owed
  ClearKeepsOwed,  \* _record_end: a refused store.clear() leaves the spend owed
  ClearFlushes,    \* not in the code: a refused clear writes the held entrance with the spend first (the ES-2 fix)
  NewRunFlushes,   \* not in the code: _begin_run writes the held entrance with an owed spend before it clears the debt
                   \* (the ES-3 fix)
  Quits,           \* the game can be closed (the pause menu's Quit, the window's close)
  ExitLands,       \* an exit's flush is never refused (the disk came back)
  Crashes          \* the process can die with no chance to write

VARIABLES
  proc,      \* the game process: "up" or "down"
  flow,      \* "title", "stage" (a run in play), "summary"
  part,      \* the run in memory holds the Spare Frame
  spent,     \* run.death_save_spent in memory
  owed,      \* flow._save_spend_owed
  held,      \* flow._entrance is not empty (the doc a flush rewrites)
  disk,      \* the run file: [run |-> a run a Continue can load, part |-> ..., spent |-> ..., id |-> its run]
  fails,     \* refused writes so far
  writes,    \* entrance, launch and Continue writes made
  rid,       \* history: which run is in memory (a Continue takes the id of the run on disk)
  runs,      \* history: runs begun so far
  fired,     \* history: earned saves fired in each run, across its Continues, by run id
  last

vars == <<proc, flow, part, spent, owed, held, disk, fails, writes, rid, runs, fired, last>>

\* flow._save -> store.save: the document lands, or (while failures remain) is refused and the file keeps its last.
Write(doc) ==
  \/ disk' = doc /\ UNCHANGED fails
  \/ fails < MaxFails /\ fails' = fails + 1 /\ UNCHANGED disk

Refused == fails' # fails

Doc(i, p, s) == [run |-> TRUE, part |-> p, spent |-> s, id |-> i]

\* flow._save(doc): an owed spend rides along; a write that lands with the flag clears the debt.
Save(i, p, s) == Write(Doc(i, p, s \/ (SpendOwed /\ owed))) /\ owed' = (owed /\ Refused)

\* flow._flush_save_spend: `_save_spend_owed and store != null and not _entrance.is_empty()`.
Owing == SpendOwed /\ owed /\ held
Flush ==
  IF Owing THEN Write(Doc(rid, part, TRUE)) /\ owed' = Refused ELSE UNCHANGED <<disk, fails, owed>>

Init ==
  /\ proc = "up" /\ flow = "title" /\ part = FALSE /\ spent = FALSE /\ owed = FALSE /\ held = FALSE
  /\ disk = [run |-> FALSE, part |-> FALSE, spent |-> FALSE, id |-> 0]
  /\ fails = 0 /\ writes = 0 /\ rid = 0 /\ runs = 0 /\ fired = [r \in 0..MaxWrites |-> 0] /\ last = "Init"

\* flow.new_run -> _begin_run, from the title (choose_class), the summary, the pause menu's Restart or a held R in
\* play: _save_spend_owed = false, run.begin, enter_stage writes the first entrance. Nothing is flushed first, so a
\* refused first entrance leaves the old run on the file, its spend no longer owed (finding ES-3). Under
\* NewRunFlushes the held entrance is written with the spend first; either write may be refused.
NewRun ==
  /\ proc = "up" /\ writes < MaxWrites
  /\ rid' = runs + 1 /\ runs' = runs + 1
  /\ flow' = "stage" /\ part' = FALSE /\ spent' = FALSE /\ held' = TRUE /\ owed' = FALSE /\ writes' = writes + 1
  /\ IF NewRunFlushes /\ Owing
       THEN \E f1, f2 \in BOOLEAN :
              /\ fails' = fails + (IF f1 THEN 1 ELSE 0) + (IF f2 THEN 1 ELSE 0) /\ fails' <= MaxFails
              /\ disk' = IF ~f2 THEN Doc(runs + 1, FALSE, FALSE)
                         ELSE IF ~f1 THEN Doc(rid, part, TRUE) ELSE disk
       ELSE Write(Doc(runs + 1, FALSE, FALSE))
  /\ last' = IF Owing THEN (IF NewRunFlushes THEN "NewRunFlush" ELSE "NewRunOwed") ELSE "NewRun"
  /\ UNCHANGED <<proc, fired>>

\* A gate's reward: the run holds the Spare Frame (in memory until the next write).
TakePart ==
  /\ proc = "up" /\ flow = "stage" /\ ~part
  /\ part' = TRUE
  /\ last' = "TakePart" /\ UNCHANGED <<proc, flow, spent, owed, held, disk, fails, writes, rid, runs, fired>>

\* enter_stage or _on_launched (_save_cleared): to_entrance_doc / to_cleared_doc carry the part and
\* death_save_spent from memory, and _entrance is set to the doc.
Entrance ==
  /\ proc = "up" /\ flow = "stage" /\ writes < MaxWrites
  /\ writes' = writes + 1 /\ held' = TRUE /\ Save(rid, part, spent)
  /\ last' = "Entrance" /\ UNCHANGED <<proc, flow, part, spent, rid, runs, fired>>

\* A killing hit. run_state._try_death_save: with the part and the save unspent, the hull is held, the save spent and
\* death_saved emitted; flow._on_death_saved marks the spend owed (store != null) and, with an entrance held, writes
\* it with the flag. Otherwise player_died: flow._end_run -> _record_end empties _entrance and store.clear() writes a
\* tombstone, so no Continue; a refused clear leaves the file as it was.
Hit ==
  /\ proc = "up" /\ flow = "stage"
  /\ IF part /\ ~spent
       THEN /\ spent' = TRUE /\ fired' = [fired EXCEPT ![rid] = @ + 1]
            /\ IF SpendWrite /\ held
                 THEN Write(Doc(rid, part, TRUE)) /\ owed' = (SpendOwed /\ Refused)
               ELSE IF SpendWrite
                 THEN owed' = SpendOwed /\ UNCHANGED <<disk, fails>>
               ELSE UNCHANGED <<disk, fails, owed>>
            /\ last' = "Saved" /\ UNCHANGED <<flow, held>>
       ELSE /\ flow' = "summary" /\ held' = FALSE
            /\ \/ /\ disk' = [disk EXCEPT !.run = FALSE] /\ owed' = FALSE /\ UNCHANGED fails
                  /\ last' = "Died"
               \/ /\ fails < MaxFails
                  /\ IF ClearFlushes /\ SpendOwed /\ owed /\ held
                       THEN \* the held entrance with the spend, written in place of the refused tombstone
                            \/ disk' = Doc(rid, part, TRUE) /\ fails' = fails + 1 /\ owed' = FALSE
                            \/ fails + 1 < MaxFails /\ fails' = fails + 2 /\ owed' = ClearKeepsOwed
                               /\ UNCHANGED disk
                       ELSE fails' = fails + 1 /\ owed' = (owed /\ ClearKeepsOwed) /\ UNCHANGED disk
                  /\ last' = "ClearRefused"
            /\ UNCHANGED <<spent, fired>>
  /\ UNCHANGED <<proc, part, writes, rid, runs>>

\* show_title from a run or the summary: the owed spend is flushed first.
ToTitle ==
  /\ proc = "up" /\ flow \in {"stage", "summary"}
  /\ flow' = "title" /\ Flush
  /\ last' = IF Owing THEN "TitleFlush" ELSE "ToTitle"
  /\ UNCHANGED <<proc, part, spent, held, writes, rid, runs, fired>>

\* retry_stage (a held R in the storeless flow, a stage replay): the owed spend is flushed first; run.restore leaves
\* death_save_spent as it is.
Retry ==
  /\ proc = "up" /\ flow = "stage"
  /\ Flush
  /\ last' = IF Owing THEN "RetryFlush" ELSE "Retry"
  /\ UNCHANGED <<proc, flow, part, spent, held, writes, rid, runs, fired>>

\* A clean exit: the pause menu's Quit (get_tree().quit(), then _exit_tree) or the window's close
\* (NOTIFICATION_WM_CLOSE_REQUEST, then _exit_tree). Under OwedOnExit the owed spend is flushed first.
QuitMenu ==
  /\ Quits /\ proc = "up"
  /\ IF OwedOnExit /\ Owing
       THEN IF ExitLands THEN disk' = Doc(rid, part, TRUE) /\ UNCHANGED fails ELSE Write(Doc(rid, part, TRUE))
       ELSE UNCHANGED <<disk, fails>>
  /\ proc' = "down" /\ owed' = FALSE /\ held' = FALSE
  /\ last' = IF OwedOnExit /\ Owing THEN "ExitFlush" ELSE "Quit"
  /\ UNCHANGED <<flow, part, spent, writes, rid, runs, fired>>

\* The process dies with no write.
Crash ==
  /\ Crashes /\ proc = "up"
  /\ proc' = "down" /\ owed' = FALSE /\ held' = FALSE
  /\ last' = "Crash" /\ UNCHANGED <<flow, part, spent, disk, fails, writes, rid, runs, fired>>

\* A new launch: the title, nothing in memory.
Launch ==
  /\ proc = "down"
  /\ proc' = "up" /\ flow' = "title" /\ part' = FALSE /\ spent' = FALSE
  /\ last' = "Launch" /\ UNCHANGED <<owed, held, disk, fails, writes, rid, runs, fired>>

\* flow.resume_run: run.from_entrance_doc reads death_save_spent and the parts from the file; in the same process an
\* owed spend is set on the doc and the run; enter_stage (or a cleared doc's flush and the next entrance) writes it.
Continue ==
  /\ proc = "up" /\ flow = "title" /\ disk.run /\ writes < MaxWrites
  /\ LET s == disk.spent \/ (OwedOnResume /\ SpendOwed /\ owed)
     IN /\ flow' = "stage" /\ part' = disk.part /\ spent' = s
        /\ writes' = writes + 1 /\ held' = TRUE /\ rid' = disk.id /\ Save(disk.id, disk.part, s)
        /\ last' = IF s /\ ~disk.spent THEN "ResumeForced" ELSE "Continue"
  /\ UNCHANGED <<proc, runs, fired>>

Done == UNCHANGED vars

Next == NewRun \/ TakePart \/ Entrance \/ Hit \/ ToTitle \/ Retry \/ QuitMenu \/ Crash \/ Launch \/ Continue \/ Done

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ proc \in {"up", "down"} /\ flow \in {"title", "stage", "summary"}
  /\ {part, spent, owed, held} \subseteq BOOLEAN
  /\ disk \in [run : BOOLEAN, part : BOOLEAN, spent : BOOLEAN, id : 0..MaxWrites]
  /\ fails \in 0..MaxFails /\ writes \in 0..MaxWrites /\ rid \in 0..MaxWrites /\ runs \in 0..MaxWrites
  /\ fired \in [0..MaxWrites -> Nat]

(* The rule. *)

\* The earned save is a once-a-run second chance: it fires at most once in a run, across every quit, restart and
\* Continue. A new run has its own.
SaveOnce == \A r \in DOMAIN fired : fired[r] <= 1

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeSaved == last # "Saved"
ProbeDied == last # "Died"
ProbeContinueHolding == ~(last \in {"Continue", "ResumeForced"} /\ part)
ProbeRefused == fails = 0
ProbeOwed == ~owed
ProbeTitleFlush == ~(last = "TitleFlush" /\ disk.spent)
ProbeRetryFlush == ~(last = "RetryFlush" /\ disk.spent)
ProbeExitFlush == ~(last = "ExitFlush" /\ disk.spent)
ProbeResumeForced == last # "ResumeForced"
ProbeClearRefused == last # "ClearRefused"
ProbeNewRunOwed == last # "NewRunOwed"
ProbeNewRunFlush == ~(last = "NewRunFlush" /\ disk.spent)
=============================================================================
