# What EarnedSave.tla stands for

`models/EarnedSave.tla` checks one promise: the Spare Frame's earned save fires at most once in a run, across every refused write, quit, restart, crash and Continue (`SaveOnce`). This page maps each step to the code. Its findings are ES-1 (closed by P7), ES-2 and ES-3 (open) in [rewards-findings.md](rewards-findings.md). `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/core/flow.gd`: `_on_death_saved`, `_save`, `_flush_save_spend` and its callers (`show_title`, `retry_stage`, `_notification`, `_exit_tree`, `resume_run`), `_begin_run`, `enter_stage`, `_save_cleared`, `_record_end`, and the flag `_save_spend_owed`.
- `sketches/core-loop/src/core/run_state.gd`: `_try_death_save`, `to_entrance_doc`, `from_entrance_doc`, `restore` (which leaves `death_save_spent` alone).
- `sketches/core-loop/src/core/run_store.gd`: `save` (returns `write_failed` and keeps the file), `load`, and `clear` (writes a tombstone; returns false and keeps the file when that write is refused).
- `sketches/core-loop/src/core/safe_store.gd`: `write_atomic`, the one write path both use.
- `sketches/core-loop/src/ui/pause_menu.gd`: the Quit entry, `get_tree().quit()`, and the Restart entry, `game.flow.new_run()` (shut only in the victory lap).
- `sketches/core-loop/src/game.gd`: `step_restart_hold`, where a held R in play calls `flow.new_run()` when the flow has a run store.
- `sketches/core-loop/src/boot/boot.gd`: `auto_accept_quit`, so the window's close quits after the close request reaches the tree.

## Steps

| Model step | Code |
| --- | --- |
| `Write(doc)`, `Save(p, s)` | flow.gd `_save(doc)`: while `_save_spend_owed`, the doc gets `death_save_spent = true`; `store.save` lands it or returns `write_failed` with the file as it was; a write that lands with the flag clears the debt |
| `Flush` | `_flush_save_spend`: `_save_spend_owed and store != null and not _entrance.is_empty()` -> `_entrance["death_save_spent"] = true` and `_save(_entrance)` |
| `NewRun` | `new_run` -> `_begin_run`, from the title (`choose_class`), the summary, the pause menu's Restart or a held R in play (`step_restart_hold`): `_save_spend_owed = false` with no flush, `run.begin`, `enter_stage` writes the first entrance; a refused one leaves the old run on the file (finding ES-3). The model gives each run an id, so `SaveOnce` counts the saves of the run a Continue loads |
| `TakePart` | a gate's reward adds the Spare Frame to the run in memory |
| `Entrance` | `enter_stage` and `_save_cleared` (the launch): `_entrance` is set to the doc built from memory, then `_save` |
| `Hit` (`Saved`) | `run_state._try_death_save`: the hull is held, `death_save_spent = true`, `death_saved` emitted; flow `_on_death_saved` sets `_save_spend_owed` (`store != null`) and, with an entrance held, writes it with the flag |
| `Hit` (`Died`, `ClearRefused`) | `player_died` -> `_end_run` -> `_record_end`: `_entrance = {}`, then `store.clear()`; a cleared file clears the debt, a refused clear keeps it (`ClearKeepsOwed`) and leaves the run on disk |
| `ToTitle` | `show_title` flushes first |
| `Retry` | `retry_stage` flushes first; `run.restore()` does not touch `death_save_spent` |
| `QuitMenu` | the pause menu's Quit (`get_tree().quit()`) and the window's close (`NOTIFICATION_WM_CLOSE_REQUEST`, handled by flow's `_notification`): `_exit_tree` flushes before the process ends |
| `Crash` | the process dies with no write |
| `Launch` | a new process: the title, nothing in memory, `_save_spend_owed` false |
| `Continue` | `resume_run`: `from_entrance_doc` reads the parts and `death_save_spent` from the file; in the same process an owed spend sets the flag on the doc and the run (`OwedOnResume`); `enter_stage` (or a cleared doc's flush and the next entrance) writes it |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `SpendOwed` | `_save_spend_owed`, carried by `_save` and flushed by `show_title` and `retry_stage` (P7) | `earnedsave-broken-spendowed` (the code before P7, finding ES-1) | `SaveOnce` |
| `OwedOnExit` | `_exit_tree` and `_notification` flush | `earnedsave-broken-exitflush` | `SaveOnce` |
| `OwedOnResume` | `resume_run` sets the flag while owed | `earnedsave-broken-resumeforce` (two refusals, no quit) | `SaveOnce` |
| `ClearKeepsOwed` | `_record_end` clears the debt only when `store.clear()` lands | `earnedsave-broken-clearowed` (two refusals, no quit) | `SaveOnce` |
| `SpendWrite` | `_on_death_saved` writes the entrance at all | `earnedsave-broken-spendwrite` (no refused write) | `SaveOnce` |
| `ClearFlushes` | not in the code: a refused clear writes the held entrance with the spend first (the ES-2 fix) | `earnedsave-es2-only` (FALSE, the code) | `SaveOnce` |
| `NewRunFlushes` | not in the code: `_begin_run` writes the held entrance with an owed spend before it clears the debt (the ES-3 fix) | `earnedsave-today-inprocess` (FALSE, the code) | `SaveOnce` |

## Configs

Run `bash models/make-earnedsave-configs.sh`, then plain TLC on each `earnedsave-*.cfg` with `EarnedSave.tla`. The code's table: one refused write, a quit anywhere, no crash, four writes a behaviour.

| Config | Stands for | Must report |
| --- | --- | --- |
| `earnedsave-today`, `earnedsave-guarded` | the code at the sync commit | no break, 3,014 distinct states |
| `earnedsave-today-nofail` | no refused write | no break, 879 distinct states |
| `earnedsave-today-inprocess` | two refused writes in one process (the spend and a restart's first entrance), Continued from the title | `SaveOnce` (finding ES-3) |
| `earnedsave-newrun-fixed` | the same with `NewRunFlushes` | no break, 3,435 distinct states |
| `earnedsave-today-clearfail` | two refused writes, a quit anywhere, the exit's write landing | `SaveOnce` (TLC's shortest path is ES-3's restart) |
| `earnedsave-es2-only` | the same with `NewRunFlushes`, so the break is the spend and the tombstone refused | `SaveOnce` (finding ES-2) |
| `earnedsave-clearfail-fixed` | `earnedsave-today-clearfail` with `ClearFlushes` | `SaveOnce`: the ES-2 fix alone leaves ES-3 |
| `earnedsave-both-fixed` | the same with `ClearFlushes` and `NewRunFlushes` | no break, 6,407 distinct states |
| `earnedsave-guarded-crash` | a crash anywhere | `SaveOnce`: a crash before any write lands, which no write order closes |
| `earnedsave-guarded-allfail` | three refused writes | `SaveOnce`: a disk that refuses every write until the game closes |
| `earnedsave-broken-*` | one guard off, as the Guards table lists; `broken-resumeforce` and `broken-clearowed` carry `NewRunFlushes`, so `earnedsave-newrun-fixed` is their table with the guard on | `SaveOnce` |
| `earnedsave-reach-*` | a save fires, a run dies, a Continue holds the part, a write and a clear are refused, a spend is owed, the title, retry and exit flush it, an in-process Continue forces it, a restart drops an owed spend, and the fixed restart writes it | the probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row earned-save-safe` writes the receipt from `earnedsave-today` with the five `earnedsave-broken-*` plants, and names ES-2, ES-3, the crash and the all-fail disk as gaps.

## Not modelled

One run file and one Spare Frame; the `.prev` copy `_begin_run` keeps (`store.keep_prev`; no game code calls `restore_prev`, so no Continue reads it); the boss arena (it writes no entrance; `_save_boss_won` sets `_entrance` past the fall); the run's other fields; seconds. `replay/earned_save_after_p7.gd` replays ES-1's path (now NOT REPRODUCED), ES-2's and ES-3's (both REPRODUCED) on the real game.

Sync commit: e362998b2 (branch stage/alpha-w45, 21 November 2026, P7 a12e9adf3: `_save_spend_owed` and its flushes in flow.gd; run_state.gd, run_store.gd, safe_store.gd, pause_menu.gd and boot.gd unchanged since e7715dcfa; game.gd's step_restart_hold read at e362998b2)
