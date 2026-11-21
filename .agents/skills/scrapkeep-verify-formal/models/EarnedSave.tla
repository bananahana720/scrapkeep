----------------------------- MODULE EarnedSave -----------------------------
(* The earned save (the Spare Frame part) and the run document that must carry its spend:
   sketches/core-loop/src/core/run_state.gd _try_death_save and to_entrance_doc / from_entrance_doc,
   sketches/core-loop/src/core/flow.gd _on_death_saved, _save, enter_stage, _on_launched, _end_run and resume_run,
   and sketches/core-loop/src/core/run_store.gd save, load and clear. references/rewards-findings.md (finding ES-1)
   has the code behind every step.

   A write can be refused (store.save returns write_failed and the file keeps its last document); the game can be
   quit to the desktop between any two steps, which writes nothing; a later launch can Continue the run on disk. *)
EXTENDS Naturals

CONSTANTS
  MaxFails,    \* run writes that may be refused in one behaviour
  MaxWrites,   \* stage entrances and launches a behaviour may write (bounds the model)
  SpendWrite,  \* _on_death_saved writes the entrance with death_save_spent
  SpendOwed,   \* a refused spend write is kept owed and written again before the pause menu's quit (the ES-1 fix)
  Crashes      \* the process can die with no chance to write

VARIABLES
  proc,      \* the game process: "up" or "down"
  flow,      \* "title", "stage" (a run in play), "summary"
  part,      \* the run in memory holds the Spare Frame
  spent,     \* run.death_save_spent in memory
  owed,      \* a spend write was refused and is still owed (SpendOwed only)
  disk,      \* the run file: [run |-> a run a Continue can load, part |-> ..., spent |-> ...]
  fails,     \* refused writes so far
  writes,    \* entrance and launch writes made
  fired,     \* history: earned saves fired in this run, across its Continues
  last

vars == <<proc, flow, part, spent, owed, disk, fails, writes, fired, last>>

\* flow._save -> store.save: the document lands, or (while failures remain) is refused and the file keeps its last.
Write(doc) ==
  \/ disk' = doc /\ UNCHANGED fails
  \/ fails < MaxFails /\ fails' = fails + 1 /\ UNCHANGED disk

Doc(p, s) == [run |-> TRUE, part |-> p, spent |-> s]

Init ==
  /\ proc = "up" /\ flow = "title" /\ part = FALSE /\ spent = FALSE /\ owed = FALSE
  /\ disk = [run |-> FALSE, part |-> FALSE, spent |-> FALSE]
  /\ fails = 0 /\ writes = 0 /\ fired = 0 /\ last = "Init"

\* flow._begin_run: run.begin clears the save, enter_stage writes the first entrance.
NewRun ==
  /\ proc = "up" /\ flow \in {"title", "summary"} /\ writes < MaxWrites
  /\ flow' = "stage" /\ part' = FALSE /\ spent' = FALSE /\ owed' = FALSE /\ fired' = 0
  /\ writes' = writes + 1 /\ Write(Doc(FALSE, FALSE))
  /\ last' = "NewRun" /\ UNCHANGED proc

\* A gate's reward: the run holds the Spare Frame (in memory until the next write).
TakePart ==
  /\ proc = "up" /\ flow = "stage" /\ ~part
  /\ part' = TRUE
  /\ last' = "TakePart" /\ UNCHANGED <<proc, flow, spent, owed, disk, fails, writes, fired>>

\* enter_stage or _on_launched: to_entrance_doc / to_cleared_doc carry the part and death_save_spent from memory.
\* A write that lands carries an owed spend with it.
Entrance ==
  /\ proc = "up" /\ flow = "stage" /\ writes < MaxWrites
  /\ writes' = writes + 1 /\ Write(Doc(part, spent))
  /\ owed' = (owed /\ fails' # fails)
  /\ last' = "Entrance" /\ UNCHANGED <<proc, flow, part, spent, fired>>

\* A killing hit. run_state._try_death_save: with the part and the save unspent, the hull is held, the save spent and
\* death_saved emitted, whose handler flow._on_death_saved writes the entrance with the flag. Otherwise player_died:
\* flow._end_run -> _record_end -> store.clear() leaves a tombstone, so no Continue.
Hit ==
  /\ proc = "up" /\ flow = "stage"
  /\ IF part /\ ~spent
       THEN /\ spent' = TRUE /\ fired' = fired + 1
            /\ IF SpendWrite
                 THEN /\ Write(Doc(part, TRUE))
                      /\ owed' = (SpendOwed /\ fails' # fails)
                 ELSE UNCHANGED <<disk, fails, owed>>
            /\ last' = "Saved" /\ UNCHANGED flow
       ELSE /\ flow' = "summary" /\ disk' = [disk EXCEPT !.run = FALSE] /\ owed' = FALSE
            /\ last' = "Died" /\ UNCHANGED <<spent, fired, fails>>
  /\ UNCHANGED <<proc, part, writes>>

\* A clean exit: the pause menu's Quit (get_tree().quit()) or the window's close (boot.gd sets auto_accept_quit), neither
\* of which writes the run today. Under the fix an owed spend is written first (it may be refused too).
QuitMenu ==
  /\ proc = "up"
  /\ IF SpendOwed /\ owed THEN Write(Doc(part, TRUE)) ELSE UNCHANGED <<disk, fails>>
  /\ proc' = "down" /\ owed' = FALSE
  /\ last' = "Quit" /\ UNCHANGED <<flow, part, spent, writes, fired>>

\* The process dies with no write.
Crash ==
  /\ Crashes /\ proc = "up"
  /\ proc' = "down" /\ owed' = FALSE
  /\ last' = "Crash" /\ UNCHANGED <<flow, part, spent, disk, fails, writes, fired>>

\* A new launch: the title, nothing in memory.
Launch ==
  /\ proc = "down"
  /\ proc' = "up" /\ flow' = "title" /\ part' = FALSE /\ spent' = FALSE
  /\ last' = "Launch" /\ UNCHANGED <<owed, disk, fails, writes, fired>>

\* flow.resume_run: run.from_entrance_doc reads death_save_spent and the parts from the file.
Continue ==
  /\ proc = "up" /\ flow = "title" /\ disk.run
  /\ flow' = "stage" /\ part' = disk.part /\ spent' = disk.spent
  /\ last' = "Continue" /\ UNCHANGED <<proc, owed, disk, fails, writes, fired>>

Done == UNCHANGED vars

Next == NewRun \/ TakePart \/ Entrance \/ Hit \/ QuitMenu \/ Crash \/ Launch \/ Continue \/ Done

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ proc \in {"up", "down"} /\ flow \in {"title", "stage", "summary"}
  /\ {part, spent, owed} \subseteq BOOLEAN
  /\ disk \in [run : BOOLEAN, part : BOOLEAN, spent : BOOLEAN]
  /\ fails \in 0..MaxFails /\ writes \in 0..MaxWrites /\ fired \in Nat

(* The rule. *)

\* The earned save is a once-a-run second chance: it fires at most once in a run, across every quit and Continue.
SaveOnce == fired <= 1

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeSaved == last # "Saved"
ProbeDied == last # "Died"
ProbeContinueHolding == ~(last = "Continue" /\ part)
ProbeRefused == fails = 0
=============================================================================
