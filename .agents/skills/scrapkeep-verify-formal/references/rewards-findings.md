# Findings from the rewards model

A finding is a break of `models/Rewards.tla` that replayed on the real code. [rewards-coverage.md](rewards-coverage.md) names the code behind each step. The rule for findings is the run-flow model's ([findings.md](findings.md)): a break that does not replay is a lesson, not a row here.

## Open

### R-1. One failed profile save, then a Continue, settles a reward without paying it, for good

- Rule: `NeverLost`. Config: `rewards-today-one` (one game, at most two crashes and two failed writes). With no failed write (`rewards-today-one-nofail`) both rules hold.
- Steps, in the code's words:
  1. The player starts a run. `flow._begin_run` saves the profile and `enter_stage(1)` saves the run file.
  2. A fact earns a row whose reward is a cosmetic, pilot or world. `progress._earn` marks it earned, and `_grant_reward` and `grant_once` settle the reward key in both the run's list and the profile, and apply the unlock, all in memory.
  3. The profile save fails (`profile.save` returns false; disk full, a profile file another build or another game changed, or a refused profile). `progress` prints "granted but not saved" and "earned but not saved". The file keeps the old profile.
  4. The run reaches its next save point (a stage entrance, or the boss fall that pull request 1081 now saves) and `run_store.save` writes the run file, whose settled list holds the reward key. No profile save happens in between.
  5. The game closes. `game._quit` saves nothing.
  6. The game starts again. `progress.setup` runs `backfill_rewards`, which finds nothing: the profile file has no earned row.
  7. The player presses Continue. `flow.resume_run` loads the run's settled list and calls `progress.reconcile_settled`, which copies the reward key into the profile and saves it.
- Harm: the profile file now holds the reward key settled without the unlock. Every later grant refuses a settled key (`sketches/core-loop/src/core/progress.gd:107-111`, `:215`), so earning the row again marks it earned and pays nothing, and every later launch's backfill pays nothing. The player never gets the cosmetic, pilot or world.
- Replay: `replay/reward_lost_on_continue.gd` at `04a7311c4`, 16 November 2026, headless, through the real `Profile`, `Progress`, `RunState` and `RunStore`. The failed write is a directory placed where `sketches/core-loop/src/core/safe_store.gd` writes the profile's temp file, so `profile.save` fails through its own path. Output:

  ```
  step earn: earned true, cosmetic in memory true, run settled true, save warnings 2
  step checkpoint: run saved ''
  step quit: profile file earned false settled false cosmetic false
  step continue: doc loads true, from_entrance_doc true
  step reconcile: profile file earned false settled true cosmetic false
  step earn again: earned true cosmetic false
  step relaunch: earned true settled true cosmetic false
  REPRODUCED
  ```

  The same script with the failed write removed prints `NOT REPRODUCED` (cosmetic true at every step).
- Evidence limit: the replay drives the stores and `progress` directly with a test row on `boss_defeated`, not the whole game; it calls `reconcile_settled` the way `flow.resume_run` does (`sketches/core-loop/src/core/flow.gd:595-599`). No one has made the path by hand.
- A second way in, with two games and no failed write (config `rewards-today-two-nofail-lost`; a candidate, not replayed): game B reads the profile file inside `profile.save`, game A then saves its grant, and B writes the document it read over A's. Both writes carry the same generation, so neither game sees the other and merges (`sketches/core-loop/src/core/profile.gd:120`). A's run file still holds the key, A closes, and a Continue settles it without the unlock as in step 7. The replay needs a pause between `profile.save`'s read and its write, which one headless process cannot make, so this route is checked by the model only. The window is one save call wide.
- Why the code does this: the run's settled list exists so a Continue never pays twice. `sketches/core-loop/tests/unlock_settle_once_test.gd` asserts it: "a profile without the id still sees the run document's grant". That is "at most once" ruling over "never lost".
- The decision for Andrew: does "never lost" outrank "at most once"? The model's candidate fix is to stop `reconcile_settled` copying the run's settled reward keys into the profile (`ReconcileImports=FALSE`). In `rewards-guarded-one` both rules then hold for one game, and in `rewards-guarded-two-lost` `NeverLost` holds for two games (44,399,537 states); `AtMostOnce` still breaks for two games (R-2). For one game: the continued run still refuses the grant (its own list holds the key), but the profile saves the row as earned and unsettled, and the next launch's `backfill_rewards` pays it. The reward arrives one launch late. Ledger ids (`ledger.found.*`), whose settle is the grant, would still need the copy, so the fix would have to tell reward keys from ledger ids.

### R-2. Two games on one profile each pay the same reward

- Rule: `AtMostOnce`. Configs: `rewards-today-two-once` and `rewards-today-two-nofail-once`; the candidate fix does not change it (`rewards-guarded-two-once`).
- Steps: two game processes load the same profile before either earns the row. Game A earns it, grants it and saves. Game B earns it too: its own profile in memory has no settled key, so it grants again, and its save finds a newer generation on disk and merges (a union). The model needs no crash and no failed write for this.
- Harm: both games announce the earn and run the grant. The file holds the unlock once, because every unlock is a set member, so nothing is doubled on disk. A reward that is not a set member would be paid twice.
- Replay: `replay/reward_twice_two_games.gd` at `04a7311c4`, 16 November 2026, headless, with two `Profile` and `Progress` pairs on one file, as two processes hold them. Output:

  ```
  step A earns: A cosmetic true, earn announced 1, file generation 2
  step B earns: B cosmetic true, earn announced 1, file generation 4
  step file: cosmetic held 1 time(s), settled true
  REPRODUCED
  ```

  With game B loading the profile after A's save, the same script prints `earn announced 0` and `NOT REPRODUCED`.
- Evidence limit: two objects in one process, not two game processes. Two games on one `user://` folder is not a normal way to play; the profile's merge exists so that it loses nothing, not so that it pays once.
