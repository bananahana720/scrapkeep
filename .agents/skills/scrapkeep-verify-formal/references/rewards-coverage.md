# What the rewards model stands for

`models/Rewards.tla` checks one promise in two parts: an earned reward is banked at most once, and it is never lost, through crashes, failed saves and two game processes on one profile. This page names the code behind every variable and action. Line numbers are at the sync commit at the end of this page.

Run it the same way as the run-flow model: `bash models/make-rewards-configs.sh` writes every `rewards-*.cfg`, and each config runs through the `astack:statechart` skill. A config with two game processes checks one rule and is big (tens of millions of states), so run it with plain TLC and several workers: `java -XX:+UseParallelGC -cp <tla2tools jar> tlc2.TLC -workers 8 -config rewards-<name>.cfg Rewards.tla`.

## The rules

| Rule | The promise | How it is stated |
| --- | --- | --- |
| `AtMostOnce` | No reward id is granted twice. | `landed <= 1`: no two successful profile saves each write a grant of the id that their own process made. |
| `NeverLost` | An earned and settled id is granted after any crash and reload. | Never reach `Lost`: the profile file (`user://profile.json`) holds the id settled without the unlock, and no running game holds the unlock in memory. From that state no code grants it: every load copies the file, the profile merge keeps settled ids (a union), and every grant path refuses a settled id (`sketches/core-loop/src/core/progress.gd:107-111`, `:215`). |

`NeverLost` is an invariant, not a rule about time. It names the state from which the grant can never come, so it holds exactly when the eventual promise does under today's grant guards. A design that pays settled ids again would need a different `Lost`.

## Variables

| Variable | Stands for | Code |
| --- | --- | --- |
| `dEarned`, `dSettled`, `dUnlock` | the profile file (`user://profile.json`) holds the achievement, the settled reward key, the unlocked cosmetic, pilot or world | `sketches/core-loop/src/core/profile.gd` `_doc["achievements"]`, `["settled"]`, `["cosmetics"]` |
| `dGen` | the profile file's generation | `sketches/core-loop/src/core/profile.gd:134` |
| `rDoc`, `rSettled`, `rGenD` | the run file (`user://run.json`): no file, a live run or a tombstone; the run's settled list holds the key; its generation | `sketches/core-loop/src/core/run_store.gd:144`, `:236`; `sketches/core-loop/src/core/run_state.gd:1166` |
| `up[p]` | game process `p` is closed, at the title (no run in play), or in a run | `sketches/core-loop/src/core/flow.gd` `in_play` |
| `mEarned`, `mSettled`, `mUnlock` | process `p`'s profile document in memory | `sketches/core-loop/src/core/profile.gd` `_doc` |
| `pGen[p]` | the generation `p` last loaded or saved | `sketches/core-loop/src/core/profile.gd:63`, `:98`, `:141` |
| `mRunSettled[p]` | `ctx.run.settled` holds the key | `sketches/core-loop/src/core/run_state.gd:179` |
| `rGen[p]` | the run store's `_generation` | `sketches/core-loop/src/core/run_store.gd:42` |
| `todo[p]` | the file steps left in `p`'s current synchronous call | (model only) |
| `nx[p]` | the document `profile.save` read and merged, about to be written | `sketches/core-loop/src/core/profile.gd:110-133` |
| `pend[p]`, `landed` | a grant made in memory that no save has written yet; how many grants a save has written | (ghosts) |
| `crashes`, `fails`, `continued` | bounds and history for the reach probes | (ghosts) |

One reward id stands for every id: ids do not interact. The legacy key `reward:<row>:<kind>` is always settled in the same call as the targeted key (`sketches/core-loop/src/core/progress.gd:113-114`), so the two are one flag.

## Actions

| Action | Code |
| --- | --- |
| `Launch` | the game starts: `sketches/core-loop/src/core/profile.gd:77` `load_profile`, the title's `sketches/core-loop/src/core/run_store.gd:60` `load`, then `sketches/core-loop/src/game.gd:618` `progress.setup`, whose `backfill_rewards` (`sketches/core-loop/src/core/progress.gd:85`) is step `B` |
| `NewRun` | `sketches/core-loop/src/core/flow.gd:485` `_begin_run`: the door save (`:506`), `ctx.run.begin` clears the settled list (`sketches/core-loop/src/core/run_state.gd:285`), `enter_stage(1)` saves the entrance (`sketches/core-loop/src/core/flow.gd:742`) |
| `Earn` | a fact meets the row: `sketches/core-loop/src/core/progress.gd:337` `_evaluate` to `:409` `_earn`, then step `G`, then `_earn`'s own profile save (`:419`). A granting earn therefore makes two profile saves, `grant_once`'s (`:229`) and `_earn`'s, and both are modelled: for the earn to leave nothing on disk, both must fail |
| `Checkpoint` | a run save point: `sketches/core-loop/src/core/flow.gd:742` (`enter_stage`), `:1119` `_save_boss_won` (pull request 1081, PF-55), `:649` `_on_death_saved`, `:1291` `_save_cleared`; each goes through `:703` `_save`, whose `_persist_companion` may save the profile first |
| `EndRun` | `sketches/core-loop/src/core/flow.gd:1247` `_record_end` clears the run to a tombstone (`:1259`, step `C`), then `run_ended` reaches progress, which saves the profile (`sketches/core-loop/src/core/progress.gd:331`) |
| `Continue` | `sketches/core-loop/src/core/flow.gd:579` `resume_run`: `from_entrance_doc` restores the settled list (`:595`, `sketches/core-loop/src/core/run_state.gd:1392`), `reconcile_settled` (`sketches/core-loop/src/core/flow.gd:599`, `sketches/core-loop/src/core/progress.gd:195`) adds the run's ids to the profile and saves, then the resumed stage saves its entrance |
| `Quit` | the game closes between calls; `sketches/core-loop/src/game.gd:1363` `_quit` saves nothing |
| `Crash` | the process dies with file steps still to do (bounded by `MaxCrashes`) |
| `StepB` | `sketches/core-loop/src/core/progress.gd:85-96` `backfill_rewards`: an earned row goes to `_grant_reward` |
| `StepG` | `sketches/core-loop/src/core/progress.gd:104-114` `_grant_reward` and `:213-232` `grant_once`: refuse a key either list holds (`_is_settled`, `:117`), else settle it in both lists (`settle`, `:178`), apply the unlock and save (`:229`). A refused grant saves nothing; the caller's save follows (`_earn`'s at `:419`; `backfill_rewards` makes none) |
| `StepU` | the unlock applied after a save, in `broken-midsave` only |
| `StepP` | `sketches/core-loop/src/core/profile.gd:110-133` `save`, first half: read the file, merge when its generation is not the one loaded |
| `StepW`, `FailW` | `sketches/core-loop/src/core/profile.gd:135-147` and `sketches/core-loop/src/core/safe_store.gd:13` `write_atomic`: the write lands whole or fails and leaves the old file |
| `StepR` | `sketches/core-loop/src/core/run_store.gd:108` `save`: refused over a newer tombstone, a newer live file merged (`merge`, `:252`, keeps our settled list), one atomic write that may fail |
| `StepC` | `sketches/core-loop/src/core/run_store.gd:224` `clear`: a tombstone one generation past the newest seen; may fail |

## Constants

| Constant | Today | What a config changes |
| --- | --- | --- |
| `Procs` | `{p1}` or `{p1, p2}` | one game, or two on one `user://` folder |
| `MaxCrashes`, `MaxFails`, `MaxGen` | 2, 2, 6 (two games: 1 crash, generation 5, and 0, 1 or 2 failed writes as the config says) | bounds; `MaxGen` is a state constraint |
| `ReconcileCopies` | `"all"` | `"ledger"` in `guarded-*` and the `broken-*` configs built on it: the narrow candidate fix. `reconcile_settled` still copies ledger ids (`ledger.found.*`, settled at `sketches/core-loop/src/core/progress.gd:325-326`), never `reward:*` keys. The model holds one reward key and no ledger id, so it shows the fix's one effect on the reward: the key is not copied, and Continue may still save the profile because a ledger id was copied |
| `LedgerChecked` | TRUE | FALSE in `broken-ledger`: grants ignore the settled ledger |
| `GrantSavesOnce` | TRUE | FALSE in `broken-midsave`: `grant_once` saves between the settle and the unlock (the comment at `sketches/core-loop/src/core/progress.gd:214` names this fault) |

## Configs

| Config | Stands for | Must report |
| --- | --- | --- |
| `rewards-today-one` | the code, one game | `NeverLost` breaks (finding R-1 in [rewards-findings.md](rewards-findings.md)); `AtMostOnce` holds |
| `rewards-today-one-nofail` | the code, one game, no failed write | both hold |
| `rewards-today-two-once`, `rewards-today-two-nofail-once` | the code, two games | `AtMostOnce` breaks: each game grants the id it earned (R-2) |
| `rewards-today-two-lost`, `rewards-today-two-nofail-lost` | the code, two games | `NeverLost` breaks; with no failed write, by the lost-update route in R-1 |
| `rewards-guarded-one` | the narrow fix, one game | both hold |
| `rewards-guarded-two-once` | the narrow fix, two games | `AtMostOnce` breaks as today (R-2) |
| `rewards-guarded-two-lost` | the narrow fix, two games, up to two failed writes | `NeverLost` holds (98,483,331 states, about six minutes on 8 workers) |
| `rewards-broken-ledger` | `guarded-one` with grants ignoring the ledger | `AtMostOnce` breaks |
| `rewards-broken-midsave` | `guarded-one` with a save between settle and unlock | `NeverLost` breaks |
| `rewards-reach` | probes that say "never" about a grant landing, a Continue, a failed write, a crash, a tombstone and a run document holding the settled id | every probe breaks |

## Not modelled

The `.prev` run copy (`keep_prev`, `restore_prev`) and its restore; a profile file that cannot be read or comes from a newer build (both stop all profile saves for the session: covered as failed writes, not as their own state); the profile backup on a schema upgrade; the ledger leaves (`ledger.found.*`, where the settle is itself the grant, so a run-document settle without a profile save loses nothing); a row's reward target changing after the earn; more than one reward id; a run's merge of an older in-memory run document on load (`sketches/core-loop/src/core/run_store.gd:95`).

Known gaps in the save points:

- `EndRun` leaves out `_record_end`'s own profile saves before the tombstone: the ladder save on a win (`sketches/core-loop/src/core/flow.gd:1253`) and `_persist_companion` (`:1257`). A save that succeeds there writes the grant, so leaving them out only adds paths that lose; it hides no loss.
- `Checkpoint` writes the run's current settled list. `_on_death_saved` (`sketches/core-loop/src/core/flow.gd:652-653`) rewrites the stored `_entrance` document, which was built at the last entrance or cleared save and can predate an earn, so in the code that save may carry an older settled list than the model's. It can only drop a key from the run file, which makes R-1 need a later save point; it adds no path.
- `_save_cleared` (`sketches/core-loop/src/core/flow.gd:1291-1295`) is folded into `Checkpoint` with the other `_save` callers.

Sync commit: 04a7311c4
