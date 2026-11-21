# Findings from the rewards model

A finding is a break of `models/Rewards.tla` that replayed on the real code. [rewards-coverage.md](rewards-coverage.md) names the code behind each step. The rule for findings is the run-flow model's ([findings.md](findings.md)): a break that does not replay is a lesson, not a row here.

## Open

### ES-1. A refused write of the earned save's spend, then a quit and Continue, hands the save back for a second free life

This finding comes from a second, smaller model beside `Rewards.tla`: `models/EarnedSave.tla`, written for FV-2 from `e7715dcfa`, with its configs from `models/make-earnedsave-configs.sh`. It covers the Spare Frame's earned save and the run document that carries its spend, and leaves `Rewards.tla` and its configs as they were.

- Rule: `SaveOnce` (the earned save fires at most once in a run, across every quit and Continue). Config: `earnedsave-today` (one refused write, a quit or a crash anywhere): breaks in 387 distinct states. `earnedsave-today-nofail` (no refused write) holds in 109. `earnedsave-guarded` (the fix below, no crash) holds in 227. `earnedsave-guarded-crash` (the fix, with a crash) breaks in 382: a crash before any write lands is a gap no write order closes. `earnedsave-guarded-allfail` (the fix, no crash, every write refused) breaks in 576. `earnedsave-broken-spendwrite` (no spend write at all, no refused write) breaks in 190. The probes `earnedsave-reach-Saved`, `-Died`, `-ContinueHolding` and `-Refused` all break. TLC 2.19 (tla2tools 1.7.4), 8 workers, Mac Studio, 21 November 2026.
- Code behind the steps: `sketches/core-loop/src/core/run_state.gd` `_try_death_save` (`sketches/core-loop/src/core/run_state.gd:795-803`) sets `death_save_spent` and emits `death_saved`; `sketches/core-loop/src/core/flow.gd` `_on_death_saved` (`sketches/core-loop/src/core/flow.gd:649-654`) sets the flag on the held `_entrance` and calls `_save`, which records a refusal in `store_error` and warns once (`:703-707`) and does nothing else; `sketches/core-loop/src/core/run_store.gd` `save` returns `write_failed` and leaves the file and its held `_doc` as they were (`sketches/core-loop/src/core/run_store.gd:108-155`). The pause menu's Quit calls `get_tree().quit()` and writes nothing (`sketches/core-loop/src/ui/pause_menu.gd:293-296`), and neither does closing the window (`sketches/core-loop/src/boot/boot.gd:169` sets `auto_accept_quit`). `resume_run` loads the file and `from_entrance_doc` reads `death_save_spent` from it (`sketches/core-loop/src/core/flow.gd:579-614`, `sketches/core-loop/src/core/run_state.gd:1380`). The next stage entrance or launch writes the flag from memory (`to_entrance_doc`, `sketches/core-loop/src/core/run_state.gd:1164`), so the window runs from the refused write to the next write that lands.
- Steps, in the code's words: a run takes the Spare Frame and a stage entrance writes it into the run file; a killing hit is held by the earned save; `_on_death_saved`'s write is refused; the player quits to the desktop before the next stage entrance or launch; the game is launched again and the run Continued: the run holds the Spare Frame with `death_save_spent` false, and its next killing hit is held again.
- Harm: a second free life from a once-a-run save, and `clean_win` (which reads the flag) can be earned by a run that spent the save. It needs the run file's write to be refused at the moment of the save: a full disk, a read-only or removed save folder, or another program holding the temp file. A refusal is otherwise survivable (the run plays on), which is why nothing retries it.
- Replay: `replay/earned_save_back_on_continue.gd`, copied into `sketches/core-loop/tests/` as zz_replay_earnedsave.gd and run with `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/<copy>.gd` (Godot 4.7.2.stable.official.ed1daf0bf, `HOME` and `XDG_DATA_HOME` set to `artifacts/local/test-home`) on `e7715dcfa`, 21 November 2026, then deleted. The refused write is real: a directory sits where `sketches/core-loop/src/core/safe_store.gd` puts the run file's temp file, so `store.save` fails through its own write path; no game code was changed. **REPRODUCED**:

  ```
  step take part: disk parts hold it true, disk death_save_spent false, store_error ''
  WARNING: flow: run not saved (write_failed): could not write user://replay_earned_save/run.json: Can't open file
  step hit: alive true, flow stage, run death_save_spent true, store_error 'write_failed', disk death_save_spent false
  step quit: disk death_save_spent false
  step continue: offered true, resumed true, run death_save_spent false, parts hold it true
  step hit again: alive true, flow stage, player_died 0, run over false
  REPRODUCED
  ```

  The control (`-- --control`, the same steps with no refused write) ends the run on the second hit:

  ```
  step hit: alive true, flow stage, run death_save_spent true, store_error '', disk death_save_spent true
  step continue: offered true, resumed true, run death_save_spent true, parts hold it true
  step hit again: alive false, flow summary, player_died 1, run over true
  NOT REPRODUCED
  ```

- Proposed fix (not made; game code is outside this unit): when `_on_death_saved`'s `_save` is refused, keep the spend owed (a flow flag set from `store_error`), write `_entrance` again on every later `_save` and on each clean exit before it happens (the pause menu's Quit before `get_tree().quit()`, and the window's close request, which then needs `auto_accept_quit` off and its own handler), and clear the flag once a write lands; `resume_run` in the same process applies `death_save_spent = true` while the flag is held. That is `SpendOwed`, and `earnedsave-guarded` holds. A crash still hands the save back (`earnedsave-guarded-crash`), and so does a disk that refuses every write until the game closes (`earnedsave-guarded-allfail`); under a disk that refuses everything the Continue also rolls back the rest of the stage, so the save is then the only thing gained.

## Closed

### R-3. A run file from a build before 8 November, holding only the old reward key, makes the earn in a continued run settle the reward unpaid, for good

- Closed (17 November 2026, W1-117, branch w44/rewards-once): the legacy branch of `_grant_reward` reads the legacy key from the profile only (`sketches/core-loop/src/core/progress.gd:143`). A run file's legacy key no longer counts as paid, so the earn pays the reward. `rewards-today-one` holds all rules (98,319 states, starts that include an older build's run file); `rewards-broken-legacyrun` and `rewards-guarded-one` break `NeverLost`.
- Rule: `NeverLost`. Config: `rewards-broken-legacyrun` (the code before the fix, everything else as today). No crash and no failed write in this build is needed.
- Steps, in the code's words: an older build (before `b12465e84`, which settled `reward:<row>:<kind>` alone) earns the row in a run; both profile saves of the earn fail; the run file saves its settled list with the legacy key. The player updates the game and presses Continue. `reconcile_settled` copies nothing of the run's reward keys (pull request 1093). The row's fact comes again in the continued run, and `_earn` calls `_grant_reward`. Its legacy branch found the legacy key in the run's list and no targeted key, took the reward as paid by the older build, and settled the targeted key into the profile with no unlock. `_earn`'s save wrote it.
- Harm: the profile holds the targeted key settled without the cosmetic, world or pilot, and every later grant refuses it.
- How likely: low. It needs a run file still live from a build before 8 November, both profile saves of that earn failing in the older build (or a profile lost beside a surviving run file), and the row earned again in the continued run.
- Replay: `sketches/core-loop/tests/reward_once_routes_test.gd`, `_old_run_key_paid_not_lost`. On the code before the fix (`sketches/core-loop/src/core/progress.gd` from `6c63cb465`, the rest of this branch), 17 November 2026, it fails three checks:

  ```
  [R-3 the earn in the continued run pays the reward] earned true settled true cosmetic false -> FAIL
  [R-3 the file never holds the key settled without the unlock]  -> FAIL
  [R-3 the next launch pays it no more]  -> FAIL
  ```

  With the fix all 28 checks of the test pass. The test builds the older build's files with this build's stores: a profile saved without the earn, and a run file whose settled list holds `reward:routes_row:cosmetic` alone. No build from before 8 November was run.

- Evidence limit: the run file's shape is this build's entrance document with the old key in its settled list; `settled` is optional in that document (`sketches/core-loop/src/core/run_state.gd:1112`), and the run store's schema has not changed since (still 1).

### R-2. Two games on one profile each pay the same reward

- Closed (17 November 2026, W1-117, branch w44/rewards-once): an earn and a grant are one `profile.transact` (`sketches/core-loop/src/core/profile.gd:138`). It holds the profile's save lock, a directory beside the file that one game makes at a time, and first takes in what another game saved since this one read the file. Game B then finds the row earned and the reward settled in the file, and neither announces nor pays it. Every profile save holds the same lock, so no save comes between another game's read and its write. `rewards-today-two-once` holds `AtMostOnce` (8,009,266 states) and `rewards-today-two-lost` holds `NeverLost` (19,042,013 states). The take-in alone is not enough: `rewards-broken-nolock` breaks `AtMostOnce` when B takes in the file and A saves its grant before B writes. With up to two failed writes `AtMostOnce` still breaks (`rewards-ruled-two-twofail-once`): game A pays in memory and both its saves fail, game B pays because the file has nothing, and A's next save writes A's grant too. That is ruling ea's trade: refusing B would lose the reward if A closed.
- Replay after the fix: `sketches/core-loop/tests/reward_once_routes_test.gd`, `_two_games_earn_once` and `_two_launches_backfill_once`. On the code before the fix it fails two checks; with the fix they pass:

  ```
  [R-2 game B, loaded before A's save, neither announces nor pays it again] announced 1 -> FAIL
  [R-2 the second launch's backfill, loaded before it, pays nothing] granted 1 -> FAIL
  ```

  The interleaving that needs the lock (B reads the file inside its save, A writes, B writes) cannot be made in one headless process; only the model checks it. The skill's replays `replay/reward_twice_two_games.gd` and `replay/reward_lost_on_continue.gd` both print NOT REPRODUCED at `4aa18e666` (17 November 2026, copied into `sketches/core-loop/tests/` and run through `scripts/sketch-smoke.mjs`).

- Rule: `AtMostOnce`. Configs: `rewards-broken-stale`, `rewards-guarded-two-once` (the code before the fix).
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

### R-1. If both profile saves of a reward's earn fail and no later profile save succeeds before the game closes, a Continue settles the reward without paying it, for good

- Closed (17 November 2026): pull request 1093 (`69870ceff`) made `reconcile_settled` skip `reward:*` keys, the narrow fix below (ruling ea: never lost outranks at most once). With `ReconcileCopies="ledger"`, `rewards-today-one` holds both rules (48,537 states) and both two-game `NeverLost` configs hold. The fault stays checkable: `rewards-broken-midsave` and the history below.

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
