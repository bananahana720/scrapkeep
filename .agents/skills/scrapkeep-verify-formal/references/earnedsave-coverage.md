# What EarnedSave.tla stands for

`models/EarnedSave.tla` checks one promise: the Spare Frame's earned save fires at most once in a run, across every refused write, quit, restart, crash and Continue (`SaveOnce`). This page maps each step to the code. Its findings are ES-1 (closed by P7), ES-2 and ES-3 (both closed by P9, `93e3431d4`) in [rewards-findings.md](rewards-findings.md); none is open. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/core/flow.gd`: `_on_death_saved`, `_save`, `_flush_save_spend`, `_clear_save_spend` and their callers (`show_title`, `retry_stage`, `_notification`, `_exit_tree`, `resume_run`, `_begin_run`, `_record_end`), `enter_stage`, `_save_cleared`, and the fields `_save_spend_owed` and `_owed_entrance`.
- `sketches/core-loop/src/core/run_state.gd`: `_try_death_save`, `to_entrance_doc`, `from_entrance_doc`, `restore` (which leaves `death_save_spent` alone).
- `sketches/core-loop/src/core/run_store.gd`: `save` (returns `write_failed` and keeps the file), `load`, and `clear` (writes a tombstone; returns false and keeps the file when that write is refused).
- `sketches/core-loop/src/core/safe_store.gd`: `write_atomic`, the one write path both use.
- `sketches/core-loop/src/ui/pause_menu.gd`: the Quit entry, `get_tree().quit()`, and the Restart entry, `game.flow.new_run()` (shut only in the victory lap).
- `sketches/core-loop/src/game.gd`: `step_restart_hold`, where a held R in play calls `flow.new_run()` when the flow has a run store.
- `sketches/core-loop/src/boot/boot.gd`: `auto_accept_quit`, so the window's close quits after the close request reaches the tree.

## Steps

| Model step | Code |
| --- | --- |
| `Write(doc)`, `Save(i, p, s)` | flow.gd `_save(doc)`: stamps `death_save_spent = true` only when the live run spent it (`ctx.run.death_save_spent`), so a new run's entrance is never poisoned by an older run's owed spend; `store.save` lands it or returns `write_failed` with the file as it was; any landed write clears the debt (`_clear_save_spend`), while a refused write carrying `death_save_spent` updates `_owed_entrance` and a refused fresh-run write leaves an older `_owed_entrance` intact |
| `Flush` | `_flush_save_spend`: when `_save_spend_owed` and `store != null`, writes `_owed_entrance` (falling back to `_entrance`) with `death_save_spent = true` through `_save` |
| `NewRun` | `new_run` -> `_begin_run`, from the title (`choose_class`), the summary, the pause menu's Restart or a held R in play (`step_restart_hold`): calls `_flush_save_spend()` first (`NewRunFlushes`, P9), then `run.begin`, then `enter_stage` writes the new run's first entrance. A landed flush writes the old run's spend, a landed new entrance replaces the old run on disk and clears the debt without marking the new run spent, and if both are refused `_owed_entrance` stays held until a later write or tombstone lands. The model gives each run an id, so `SaveOnce` counts the saves of the run a Continue loads |
| `TakePart` | a gate's reward adds the Spare Frame to the run in memory |
| `Entrance` | `enter_stage` and `_on_launched` (`_save_cleared`): `_entrance` is set to the doc built from memory, then `_save` |
| `Hit` (`Saved`) | `run_state._try_death_save`: the hull is held, `death_save_spent = true`, `death_saved` emitted; flow `_on_death_saved` sets `_save_spend_owed` (`store != null`), snapshots `_owed_entrance` with `death_save_spent = true`, and writes `_entrance` |
| `Hit` (`Died`, `ClearRefused`) | `player_died` -> `_end_run` -> `_record_end`: `_entrance = {}`, then `store.clear()`; a landed tombstone calls `_clear_save_spend()`, while a refused clear calls `_flush_save_spend()` on `_owed_entrance` (`ClearFlushes`, P9) and keeps `_owed_entrance` and `_save_spend_owed` if that write is refused too (`ClearKeepsOwed`) so a later title or exit flush lands it once the disk recovers |
| `ToTitle` | `show_title` flushes first |
| `Retry` | `retry_stage` flushes first; `run.restore()` does not touch `death_save_spent` |
| `QuitMenu` | the pause menu's Quit (`get_tree().quit()`) and the window's close (`NOTIFICATION_WM_CLOSE_REQUEST`, handled by flow's `_notification`): `_exit_tree` flushes `_owed_entrance` before the process ends |
| `Crash` | the process dies with no write |
| `Launch` | a new process: the title, nothing in memory, `_save_spend_owed` false, `_owed_entrance` empty |
| `Continue` | `resume_run`: `from_entrance_doc` reads the parts and `death_save_spent` from the file; in the same process an owed spend sets the flag on the doc and the run (`OwedOnResume`); `enter_stage` (or a cleared doc's flush, updating `_owed_entrance` to that doc first, and the next entrance) writes it |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `SpendOwed` | `_save_spend_owed`, carried by `_save` and flushed by `show_title` and `retry_stage` (P7) | `earnedsave-broken-spendowed` (the code before P7, finding ES-1) | `SaveOnce` |
| `OwedOnExit` | `_exit_tree` and `_notification` flush | `earnedsave-broken-exitflush` | `SaveOnce` |
| `OwedOnResume` | `resume_run` sets the flag while owed | `earnedsave-broken-resumeforce` (two refusals, no quit) | `SaveOnce` |
| `ClearKeepsOwed` | `_record_end` clears the debt only when `store.clear()` or its flush lands | `earnedsave-broken-clearowed` (three refusals, no quit: spend, clear and immediate flush refused) | `SaveOnce` |
| `SpendWrite` | `_on_death_saved` writes the entrance at all | `earnedsave-broken-spendwrite` (no refused write) | `SaveOnce` |
| `ClearFlushes` | `_record_end` flushes `_owed_entrance` on a refused clear and keeps it if writes are still refused (P9, finding ES-2) | `earnedsave-broken-clearflush` (two refusals, exit lands; ES-2 path) | `SaveOnce` |
| `NewRunFlushes` | `_begin_run` flushes `_owed_entrance` before starting the new run and keeps it until a write lands (P9, finding ES-3) | `earnedsave-broken-newrunflush` (two refusals, no quit; ES-3 path) | `SaveOnce` |

## Configs

Run `bash models/make-earnedsave-configs.sh`, then plain TLC on each `earnedsave-*.cfg` with `EarnedSave.tla`. The code's default table: one refused write, a quit anywhere, no crash, four writes a behaviour, all seven guards on.

| Config | Stands for | Must report |
| --- | --- | --- |
| `earnedsave-today`, `earnedsave-guarded` | the code at the sync commit (one refused write, quit anywhere) | no break, 3,014 distinct states |
| `earnedsave-today-nofail` | no refused write | no break, 879 distinct states |
| `earnedsave-today-inprocess` | two refused writes in one process (the table ES-3 used to break) | no break, 3,361 distinct states |
| `earnedsave-today-clearfail` | two refused writes, a quit anywhere, the exit's write landing (the table ES-2 used to break) | no break, 6,407 distinct states |
| `earnedsave-today-sustained` | three refused writes in a row across a refused death or restart, disk back before exit (matches `replay/earned_save_after_p7.gd`) | no break, 11,102 distinct states |
| `earnedsave-guarded-crash` | a crash anywhere | `SaveOnce`: a crash before any write lands, which no write order closes |
| `earnedsave-guarded-allfail` | three refused writes with exit flush also refusable | `SaveOnce`: a disk that refuses every write until the game closes |
| `earnedsave-broken-*` | one guard off each, as the Guards table lists (`broken-clearflush` is ES-2's path; `broken-newrunflush` is ES-3's) | `SaveOnce` |
| `earnedsave-reach-*` | a save fires, a run dies, a Continue holds the part, a write and a clear are refused, a spend is owed, the title, retry, exit, refused clear and restart flush it, a refused clear and refused restart keep `_owed_entrance` under sustained refusal, an in-process Continue forces it, and a restart without `NewRunFlushes` drops it | the probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row earned-save-safe` writes the receipt from `earnedsave-today`, `earnedsave-today-inprocess`, `earnedsave-today-clearfail` and `earnedsave-today-sustained` with all seven `earnedsave-broken-*` plants, and names the hard crash and the all-fail disk as gaps.

## Not modelled

One run file and one Spare Frame; the `.prev` copy `_begin_run` keeps (`store.keep_prev`; no game code calls `restore_prev`, so no Continue reads it); the boss arena (it writes no entrance; `_save_boss_won` sets `_entrance` past the fall); the run's other fields; seconds. `replay/earned_save_after_p7.gd` replays ES-1's, ES-2's and ES-3's paths on the real game (all three NOT REPRODUCED).

Sync commit: 747c6bda4 (branch w46/08-shift-variants, 22 November 2026, W46-08 fix round 1: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, calling `ShiftVariants.on_stage_retry(ctx.run)` in `retry_stage` after `ctx.run.restore()` and passing `gate != null and gate.yard_ahead()` into `ShiftVariants.wakes_warden` in `physics_step`. Save, flush, clear, Continue and earned-save spend paths are unchanged, so no modelled step changed. Before it, 1b050f4c2 (branch w46/08-shift-variants, 22 November 2026, W46-08: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, wiring shift_variants.gd into `stage_def`, `stage_look_id`, `_begin_run`, `physics_step` and `_on_enemy_killed`. Save, flush, clear, Continue and earned-save spend paths are unchanged, so no modelled step changed. Before it, 02e8934b5 (branch w46/t2-warm-resets, 22 November 2026, W46-T2: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, adding read-only `trace_snapshot()` for band_trace.gd. Save, flush, clear and earned-save paths are unchanged, so no modelled step changed. Before it, 74653f437 (stage/alpha-w46, 22 November 2026, W46-T1 PR #1197: of the covered files only `sketches/core-loop/src/game.gd` changed: its reduced-motion static writes move into `static func set_motion_statics(on)`, which `set_reduced_motion` calls (and now also sets `CallerTile.reduced_motion`), so the test batch can reset them. No flow, save, reward, yard lock, aim, mount or swipe call changed, so no modelled step changed. Before it, 93e3431d4 (branch w45/p9-earned-save-two-refusals, 21 November 2026, P9: `_owed_entrance` and `_clear_save_spend` in flow.gd, flushing before `_begin_run` and on refused `store.clear()` in `_record_end` while keeping `_owed_entrance` until a write or tombstone lands, closing ES-2 and ES-3; run_state.gd, run_store.gd, safe_store.gd, pause_menu.gd, game.gd and boot.gd unchanged since e362998b2)))))

Sync commit: 01ada29a0 (branch w50/sync-w47-w49-unified, 25 November 2026, W50-SYNC: of the covered files `sketches/core-loop/src/core/flow.gd`, `sketches/core-loop/src/core/run_state.gd` and `sketches/core-loop/src/game.gd` changed for event prewarm, Brindle cobalt pick settlement, pocket consumables serialization in entrance docs, and full-alpha launch progression; `_try_death_save`, `_on_death_saved`, `_save`, `_flush_save_spend`, `_clear_save_spend`, `_owed_entrance`, run_store and safe_store are unchanged)

Sync commit: 4657692058523576912f6adeaf30d560a6ffa8c9 (25 November 2026, Phase 3 formal maintenance: boot.gd, safe_store.gd, run_store.gd, and pause_menu.gd had 0 substantive hunks (Phase 2 `/no-comments` only); flow.gd adds `start_pick_open()`, `sync_relics()` inside `resume_run()`, and public wrapper `save_boss_won()`; run_state.gd adds overrides and `scrap_ingots` entrance fields; game.gd leaves `step_restart_hold` unchanged; `_try_death_save`, `_on_death_saved`, `_save`, `_flush_save_spend`, `_clear_save_spend`, `_owed_entrance`, `_record_end`, `_begin_run`, and `resume_run` earned-save spend logic are unchanged; in sync)

Sync commit: ed9db9fcf611e7a1bdf7810614f9867a771bb14c (27 November 2026, Full-Alpha Wave C integration on branch swarm/full-alpha-complete: of the covered files only `sketches/core-loop/src/game.gd` changed, adding the opt-in `--dev` console hook; zero earned-save grant, spend, clear, or retry paths changed; `#106` live TLC clean; in sync)
