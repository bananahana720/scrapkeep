# Findings from the rewards model

A finding is a break of `models/Rewards.tla` that replayed on the real code. [rewards-coverage.md](rewards-coverage.md) names the code behind each step. The rule for findings is the run-flow model's ([findings.md](findings.md)): a break that does not replay is a lesson, not a row here.

## Open

### R-1. If both profile saves of a reward's earn fail and no later profile save succeeds before the game closes, a Continue settles the reward without paying it, for good

- Status (17 November 2026): fixed in code by pull request 1093 (`69870ceff`, ruling ea: never lost outranks at most once). The `today-*` configs now set `ReconcileCopies="ledger"`. This finding closes and the sync commit moves once `rewards-today-one` is checked and holds; no checker has run on the fix yet.

- Rule: `NeverLost`. Config: `rewards-today-one` (one game, at most two crashes and two failed writes). With no failed write (`rewards-today-one-nofail`) both rules hold.
- Steps, in the code's words:
  1. The player starts a run. `flow._begin_run` saves the profile and `enter_stage(1)` saves the run file.
  2. A fact earns a row whose reward is a cosmetic, a world or a pilot. `progress._earn` marks it earned. `_grant_reward` and `grant_once` settle the reward key in the run's list and in the profile, and apply the unlock, all in memory.
  3. Both profile saves of that earn fail: `grant_once`'s (`sketches/core-loop/src/core/progress.gd:229`) and `_earn`'s (`:419`). `progress` prints "granted but not saved" and "earned but not saved". The file keeps the old profile. Only a transient write failure gets past step 7: a disk that fills and then clears, or a rename refused once. A lasting cause stops step 7's save too. Another game's change is merged in, not a failure (`sketches/core-loop/src/core/profile.gd:120-122`). A newer build's file refuses this build's saves after the relaunch as well (`profile.gd:92-93`). A refused profile has `can_save` false, and `reconcile_settled` saves only when `can_save` is true (`progress.gd:205`).
  4. No profile save succeeds between the earn and the close. The run reaches its next save point (a stage entrance, a cleared stage, or the boss fall that pull request 1081 now saves), and `run_store.save` writes the run file. The run file's settled list holds the reward key.
  5. The game closes. `game._quit` saves nothing.
  6. The game starts again. `progress.setup` runs `backfill_rewards`, which pays rewards for rows the profile already holds as earned. It finds nothing, because the profile file has no earned row.
  7. The player presses Continue. `flow.resume_run` loads the run's settled list and calls `progress.reconcile_settled`. That call copies the reward key into the profile and saves it.
- Harm: the profile file now holds the reward key settled without the unlock. Every later grant refuses a settled key (`sketches/core-loop/src/core/progress.gd:107-111`, `:215`). Earning the row again marks it earned and pays nothing, and so does every later launch's backfill. This loses cosmetics and worlds. It would also lose a pilot reward with no class row, but that list (`Achievements.PENDING_PILOTS`, `sketches/core-loop/src/core/achievements.gd:40`) is empty today. A pilot with a class row comes back: `open_met_pilots` (`progress.gd:237-246`) opens every pilot whose class-row rule the earned rows meet. It runs after every earn (`:418`) and at every launch (`:78`), and once the row is earned again, the rule is met.
- Replay: `replay/reward_lost_on_continue.gd` at `04a7311c4`, 16 November 2026. It runs headless through the real `Profile`, `Progress`, `RunState` and `RunStore`. The failed write is a directory placed where `sketches/core-loop/src/core/safe_store.gd` writes the profile's temp file, so `profile.save` fails through its own path. Both saves of the earn fail ("save warnings 2"). Output:

  ```
  step launch+newrun: profile saved true, run saved ''
  step earn: earned true, cosmetic in memory true, run settled true, save warnings 2
  step checkpoint: run saved ''
  step quit: profile file earned false settled false cosmetic false
  step continue: doc loads true, from_entrance_doc true
  step reconcile: profile file earned false settled true cosmetic false
  step earn again: earned true cosmetic false
  step relaunch: earned true settled true cosmetic false
  REPRODUCED
  ```

  The control is the same script with `-- --control`, which leaves out only the failed write:

  ```
  step launch+newrun: profile saved true, run saved ''
  step earn: earned true, cosmetic in memory true, run settled true, save warnings 0
  step checkpoint: run saved ''
  step quit: profile file earned true settled true cosmetic true
  step continue: doc loads true, from_entrance_doc true
  step reconcile: profile file earned true settled true cosmetic true
  step earn again: earned true cosmetic true
  step relaunch: earned true settled true cosmetic true
  NOT REPRODUCED
  ```

- Evidence limit: the replay drives the stores and `progress` directly, with a test row on `boss_defeated`, not the whole game. It calls `reconcile_settled` the way `flow.resume_run` does (`sketches/core-loop/src/core/flow.gd:595-599`). No one has made the path by hand.
- A second way in, with two games and no failed write. This is a candidate, not replayed; its config is `rewards-today-two-nofail-lost`. Game B reads the profile file inside `profile.save`. Game A then saves its grant. B then writes the document it read over A's. Both writes carry the same generation, so neither game sees the other's write and neither merges (`sketches/core-loop/src/core/profile.gd:120`). A's run file still holds the key, A closes, and a Continue settles the key without the unlock, as in step 7. A replay needs a pause between `profile.save`'s read and its write, and one headless process cannot make that pause, so only the model checks this route. The window is one save call wide.
- Why the code does this: the run's settled list exists so that a Continue never pays twice. `sketches/core-loop/tests/unlock_settle_once_test.gd` asserts it: "a profile without the id still sees the run document's grant". That is "at most once" ruling over "never lost".
- The decision for Andrew: does "never lost" outrank "at most once"?
  - The candidate fix is narrow. `reconcile_settled` keeps copying ledger ids (`ledger.found.*`, settled at `progress.gd:325-326`), whose settle is the grant. It stops copying `reward:*` keys. The `guarded-*` configs model this with `ReconcileCopies="ledger"`. Under it, Continue may still save the profile because a ledger id was copied.
  - Results: in `rewards-guarded-one`, both rules hold for one game (48,537 states). In `rewards-guarded-two-lost`, `NeverLost` holds for two games with up to two failed writes (98,483,331 states). `AtMostOnce` still breaks for two games (R-2).
  - How the reward arrives with one game: the continued run still refuses the grant, because its own list holds the key (`progress.gd:117-118`). `_earn` saves the row as earned and not settled (`:419`), and the next launch's `backfill_rewards` pays it once. The reward arrives one launch late.
  - Behaviour change: a profile wiped (or lost) while a run file survives is paid again at the next launch. Today the run file's list stops that payment.
  - `sketches/core-loop/tests/unlock_settle_once_test.gd` does not tell the two designs apart. Its "profile without the id" check calls `grant_once` straight after `reconcile_settled`, inside the run, and the run's own list refuses that grant under either design.

### R-2. Two games on one profile each pay the same reward

- Rule: `AtMostOnce`. Configs: `rewards-today-two-once` and `rewards-today-two-nofail-once`. The candidate fix does not change it (`rewards-guarded-two-once`).
- Steps: two game processes load the same profile before either earns the row. Game A earns the row, grants it and saves. Game B earns it too. B's own profile in memory has no settled key, so B grants again. B's save finds a newer generation on disk and merges (a union). The model needs no crash and no failed write for this.
- Harm: both games announce the earn and run the grant. The file holds the unlock once, because every unlock is a set member, so nothing is doubled on disk. A reward that is not a set member would be paid twice.
- Replay: `replay/reward_twice_two_games.gd` at `04a7311c4`, 16 November 2026. It runs headless with two `Profile` and `Progress` pairs on one file, as two processes hold them. Output:

  ```
  step A earns: A cosmetic true, earn announced 1, file generation 2
  step B earns: B cosmetic true, earn announced 1, file generation 4
  step file: cosmetic held 1 time(s), settled true
  REPRODUCED
  ```

  The control is the same script with `-- --control`, where game B loads the profile after A's save:

  ```
  step A earns: A cosmetic true, earn announced 1, file generation 2
  step B earns: B cosmetic true, earn announced 0, file generation 2
  step file: cosmetic held 1 time(s), settled true
  NOT REPRODUCED
  ```

- Evidence limit: two objects in one process, not two game processes. Two games on one `user://` folder is not a normal way to play. The profile's merge exists so that it loses nothing, not so that it pays once.
