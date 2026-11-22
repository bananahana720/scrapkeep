---
name: scrapkeep-verify-formal
description: "Check by TLA+ model, kept beside this skill, the promises Scrapkeep's run flow and launch swipe make under every interruption (death, retry, new run, quit, Continue, either order of the gate's two signals); that an earned reward or earned save is spent or banked once through crashes, failed saves and two games on one profile; that a park flood never holds full water under the ball; that a heft destructible pays once and cannot be farmed; that a yard lock opens, pays once and never shuts on an awake Warden; and that the sound arbiter and melody lease hold under fight, radio, ultimate, warning and death interruptions. Use when a change touches flow.gd, launch_take.gd, profile.gd, safe_store.gd, run_store.gd, progress.gd, event_director.gd, destructibles.gd, stage_locks.gd, overtime.gd, music_arbiter.gd, melody_lease.gd, audio.gd or ace_sequencer.gd, or when asked to formally verify or model-check; which tests qualify a diff stays in scrapkeep-verify, and playing the game stays in scrapkeep-verify-game."
---

# Check the run flow against its model

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns one formal check. A test plays the orders of events someone wrote down. This check tries every order of the steps in `models/RunFlow.tla`, a small model of a run from the title to its summary and of the launch swipe (the comic panel that covers the cut between stages). It does not replace a test: `scrapkeep-verify` still picks the tests for a diff, and a model result says nothing about feel, timing in seconds or drawing.

`F=.agents/skills/scrapkeep-verify-formal`. Paths in the tables are under `sketches/core-loop/src`.

## The rules

Each rule is one promise to the player. [references/coverage.md](references/coverage.md) has the code behind every step of the model.

| Rule                | The promise                                                                         | What breaks for the player                                   |
| ------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `TakeNamesHeldPart` | When the swipe closes over a launch, it names a part only if the live run holds it. | The screen says a part was taken that the run does not have. |
| `SeamOwned`         | The flow waits for the swipe's cut only while a swipe really owes one.              | The launch never lands and the run hangs in the air.         |
| `LaunchLands`       | Every launch ends: the next stage, the boss or the summary.                         | The same hang, as a rule about time.                         |
| `WardenGoneOpens`   | A sealed stage whose Warden is gone opens its gates.                                | A stage with nothing to fight and no way on.                 |
| `EndsOnce`          | A run ends at most once.                                                            | Rewards and the run log are written twice.                   |
| `PickHeard`         | A pilot pick is never dropped without a sign.                                       | A press on pilot select does nothing.                        |
| `StampOnlySeam`     | A pilot pick's swipe never carries a part's name.                                   | The run-start swipe shows a part instead of its own word.    |

## Is this change covered?

1. Run `git diff --stat <sync commit> -- <files>`, where `<files>` is every `sketches/core-loop/src` file that [references/coverage.md](references/coverage.md) cites (for the rewards model, [references/rewards-coverage.md](references/rewards-coverage.md)); `scripts/gate/model-receipts.mjs` reads the same list. A step that comes to read a new file must cite it there. The sync commit is the last line of the coverage page. That form compares the sync commit with the working tree, so it sees uncommitted changes too (VFM-09). No output: the model still describes the code, go to "Run it".
2. With output, read the diff of every function named in the coverage table, and look for a new caller of a covered function or a new writer of `_seam_take`, `_taken_part`, `_launched`, `run.over` or the swipe's `phase`. A new way to interrupt a run is a new action even when no covered function changed (VFM-05).
3. A change that removes or adds a guard the coverage table names: set that constant on the two `today-*` lines of `models/make-configs.sh` to what the code now does, so `today-*` stands for the code under check (VFM-09). Any other change: change the model from the code before you run it, never from what makes it pass. One call in the code is one action in the model; two handlers of one signal are one action with an order choice (VFM-06). Then move the sync commit.

## Run it

1. Run `bash $F/models/make-configs.sh`. It rewrites every `.cfg` from the one table of guards in that script, so a config never drifts from its neighbours. (design choice)
2. Check each config with the `astack:statechart` skill, giving it `RunFlow.tla` and the config. That skill owns the checker command and reads a result as a shortest path in plain words; give each run a new output folder outside the repository. Each run takes a few seconds.
3. Compare with this table. Anything else is a result to explain, in "Read a result".

| Config                                                 | Stands for                                                                                               | Must report                                                                    |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `guarded-store`, `guarded-nostore`, `guarded-lastgate` | every guard in place: the real game, the store-less test flow, and a run with no swipe at its last gate  | no break                                                                       |
| `today-store`, `today-nostore`                         | the code at the sync commit                                                                              | only the open findings in [references/findings.md](references/findings.md)     |
| `broken-newrun`                                        | `_begin_run` without `_untake`                                                                           | `TakeNamesHeldPart` breaks                                                     |
| `broken-retry`                                         | `retry_stage` without `_untake`                                                                          | `TakeNamesHeldPart` breaks                                                     |
| `broken-end`                                           | `_end_run` without `_untake`                                                                             | `TakeNamesHeldPart` breaks                                                     |
| `broken-vanish`                                        | no `_warden_vanished` tick                                                                               | `WardenGoneOpens` breaks                                                       |
| `broken-endguard`                                      | `_on_player_died` without its `in_play` guard                                                            | `EndsOnce` breaks                                                              |
| `broken-keys`                                          | screen keys not swallowed under the swipe                                                                | `PickHeard` breaks                                                             |
| `broken-busy`                                          | a busy swipe not refused, with the time assumption off too (a busy swipe cannot meet a launch otherwise) | `SeamOwned`, `StampOnlySeam`, `LaunchLands` break                              |
| `reach-store`, `reach-nostore`                         | probes that say "never" about things that must happen                                                    | every probe breaks; one that holds means an action can no longer fire (VFM-10) |
| `untimed`                                              | the time assumption off                                                                                  | `TakeNamesHeldPart` breaks, by a path no player can make                       |

A `broken-*` config that reports no break means the model can no longer see that fault. Fix the model before trusting any pass (VFM-03).

The world 1 done read takes this check as two receipts, `run-always-ends` and `rewards-banked-once`. `node scripts/gate/model-receipts.mjs --out <dir>` writes them. It runs plain TLC on `today-store` with the `broken-vanish` and `broken-endguard` plants, and on `rewards-today-one`, `rewards-today-two-once` and `rewards-today-two-lost` with the `rewards-broken-ledger`, `rewards-broken-midsave`, `rewards-broken-legacyrun`, `rewards-broken-stale` and `rewards-broken-nolock` plants, each with a timeout. A receipt fails while step 1 of "Is this change covered?" shows a changed file, and the script refuses a checkout with uncommitted changes under this skill or `sketches/core-loop/src`. The rewards receipt always names what the model cannot see: the save lock is taken as perfect, and ruling ea lets two games pay twice when both saves of the first game's earn fail.

## Read a result

1. A break in a `guarded-*` or `today-*` config is a candidate, not a bug. Tell it as steps in the code's words, using the coverage table. (VFM-02)
2. Replay it on the real game, one model step per call, before you report it. Copy the closest script from `$F/replay/` into `sketches/core-loop/tests/` under a name starting `zz_replay_`, change its steps, and run it with `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/<name>.gd`, with `XDG_DATA_HOME` set to a scratch folder as `AGENTS.md` requires on the PC. Run the same script on the sync commit as a control when the break comes from a change. Delete the copy afterwards. (VFM-02, VFM-09)
3. If a step cannot be made in the game, the model is wrong. Ask what stops the step: an input rule (the swipe swallows screen keys), a clock (a stage cannot be cleared inside one swipe), or a guard you did not model. Put that in the model as a named constant, keep a config that turns it off, and record the lesson. Do not delete the step to get a pass. (VFM-01, VFM-02)
4. If every step replays, it is a finding about the code. Add it to [references/findings.md](references/findings.md) with the steps, the harm and the replay's output. Do not weaken the rule, and do not change game code unless the task is that fix. (design choice)
5. When a fix lands, its guard constant flips in `make-configs.sh` (`today-*` must then match `guarded-*`), the finding closes, and the sync commit moves.

## Change the model on purpose

- A new interruption (a new screen, key, menu entry or signal that can fire during a launch or at a run's end): add an action, enabled in every state where the code allows the call, not only where it is expected. (VFM-05)
- A new guard in the code: add a constant to the `CONSTANTS` block of `models/RunFlow.tla` and, defaulting to TRUE, to the table in `models/mkcfg.sh`, use it in the action, and add a `broken-*` config that turns it off and names the rule that must break. A guard no rule can see failing does not get a constant. (VFM-03, VFM-04)
- A rule is stated at the moment the player sees it. `TakeNamesHeldPart` is read when the swipe closes, not for as long as the word stays up. (VFM-08)
- Bounds: a world 1 run as the sitting launch plays it (two stages, the boss, then the summary) and two runs. Raise `Stages` or `MaxRuns` in `mkcfg.sh` when a change depends on a third. A run that goes on past the boss into another world is not modelled. (design choice)

## What a pass does not cover

A pass covers the model within its bounds and its time assumption (VFM-07). Not modelled: the camp gate's way into a run, the victory lap, stage replay from the death screen, the arena's own retry beyond "the run stays in the boss state", a run that continues past the boss, saves beyond one run document, the difference between the swipe's own word and no word, seconds, and anything drawn. `references/coverage.md` lists them.

## The rewards model

A second model, `models/Rewards.tla`, checks how an earned reward is banked: `sketches/core-loop/src/core/progress.gd`'s earn, settle, `grant_once` and `reconcile_settled`, the profile and run stores, and `sketches/core-loop/src/core/safe_store.gd`'s writes, with a crash between any two file writes, failed writes, two game processes on one profile and a run file an older build left with the legacy reward key. Its rules:

| Rule         | The promise                                                            | What breaks for the player                           |
| ------------ | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| `AtMostOnce` | No reward id is granted twice.                                         | The earn is announced and paid twice.                |
| `NeverLost`  | An earned and settled reward id is granted after any crash and reload. | A cosmetic or world the player earned never arrives. |

Run it with `bash $F/models/make-rewards-configs.sh`, then each `rewards-*.cfg` as in "Run it"; the two-game configs need plain TLC with several workers. [references/rewards-coverage.md](references/rewards-coverage.md) has the code behind each step, the config table with what each config must report, and what is not modelled. Its findings are in [references/rewards-findings.md](references/rewards-findings.md). The rest of this skill (covered changes, reading a result, replays, broken variants, reach probes) applies to it unchanged.

## The hazard model

A further model, `models/HazardCycle.tla`, checks a storm's sought strike in the Spillway (W44): `sketches/core-loop/src/world/events/storm_seek.gd`, stepped by `sketches/core-loop/src/world/events/natural.gd`, and the enemies it strikes through `sketches/core-loop/src/world/events/hazard_hits.gd`. One tick at a time the ball and one enemy go anywhere, the ball rolls, slows or stalls, a storm breaks or runs down, and the hazard goes idle, tell, strike, cool. Its rules:

| Rule                 | The promise                                                                             | What breaks for the player                              |
| -------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `TellBeforeStrike`   | A strike tells for at least 0.6 s, on the place it lands.                               | Lightning hits with no warning, or not where it warned. |
| `RollingNeverSought` | Only a stalled ball is sought; a rolling one, turning or not, never.                    | Rolling and kiting stop being free (ruling cu).         |
| `StalledSought`      | A stalled ball in a storm that can still strike is sought within the rest and one tick. | Parking under a storm costs nothing.                    |
| `EnemyStruck`        | An enemy inside the strike is struck.                                                   | A pack dragged through the strike walks out whole.      |
| `BallOnlyWhereTold`  | The ball is hit only inside the told ring, so a ball that rolls off escapes.            | A dodge that worked still costs scrap.                  |

Run it with `bash $F/models/make-hazard-configs.sh`, then each `hazard-*.cfg` as in "Run it". `hazard-today` must report no break; each `hazard-broken-*` must break the rule its line in the script names. `node scripts/gate/model-receipts.mjs --row hazards-hit-everyone --out <dir>` writes its receipt. [references/hazard-coverage.md](references/hazard-coverage.md) has the code behind each step and what is not modelled.

## The flood model

Another model, `models/ParkFlood.tla`, checks a park flood from its announcement to its end in `sketches/core-loop/src/world/event_director.gd` (`_park_step_live`, `_park_capacity`, `_park_can_end`), with the ball free to roll into or out of any basin between any two ticks. Its rules:

- **FullWaterNeverHeld.** Water that has risen for its whole fill time is stepped on every tick, ball or no ball, while its live time runs and after it while the ball keeps the flood from ending (finding PF-2, closed by 60e2fccf5).
- **FullWaterFreesItsSlot.** Full water with no live time stops counting against the ground cap.
- **NeverRisesUnderBall** and **NeverEndsUnderBall.** Water does not rise for the first 2 s of the ball in its basin, grounded or not (the bounded wait), and does not end while the ball is in its basin.
- **HoldEnds.** The wait is bounded: rising water always finishes rising, ball or no ball (finding PF-1, closed by W1-148).
- **WithinCap.** No more unsettled ground events are live than the cap allows.
- **FloodEnds** and **AnnouncedLands.** Once the ball stays out, every live flood ends and every announced one lands.

Run `bash $F/models/make-flood-configs.sh`, then plain TLC on each `flood-*.cfg` with `ParkFlood.tla`. [references/flood-coverage.md](references/flood-coverage.md) maps each step and guard to the code and lists what each config must report, and [references/flood-findings.md](references/flood-findings.md) holds the findings, one of them open (PF-3). `node scripts/gate/model-receipts.mjs --out <dir> --row flood-never-held` writes its receipt.

## The destructibles model

One more model, `models/Destructibles.tla`, checks a stage's heft destructibles (W45-C) in `sketches/core-loop/src/world/destructibles.gd`: a piece broken by the ball's roll or by a blast, the scrap and cogs it drops against the stage's cap, the line, mount and aim that can rest on it (`_on_piece_shattered` in `sketches/core-loop/src/movement/player_ball.gd`), and the stage retry that rebuilds the pieces and restores the run. The world tick and the ball tick run in either order each frame. Its rules:

| Rule                     | The promise                                                                                     | What breaks for the player                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `PaysOnce`               | A piece pays at most once an attempt, and a stage's pieces never pay past 35 scrap and 20 cogs. | Rubble pays again, or one stage pays past its cap.              |
| `RetryNoFarm`            | A retried stage banks at most one attempt's worth over the stage-entry checkpoint.              | Break, retry, repeat is an endless income.                      |
| `NoLineOnRubble`         | At a frame's end no line, mount or aim rests on a shattered piece.                              | The ball hangs from, sits on, or fires at a thing that is gone. |
| `NoColliderAfterShatter` | A shattered piece is never a live solid.                                                        | The ball hits an invisible wall where the piece stood.          |
| `TierCapNeverStacks`     | A blast breaks at most one tier above the class.                                                | Stacked bonuses skip the heft the tiers stand for.              |

Run `bash $F/models/make-destructibles-configs.sh`, then plain TLC on each `destructibles-*.cfg` with `Destructibles.tla`. [references/destructibles-coverage.md](references/destructibles-coverage.md) maps each step and guard to the code and lists what each config must report; [references/destructibles-findings.md](references/destructibles-findings.md) holds the findings (none open). `node scripts/gate/model-receipts.mjs --out <dir> --row destructibles-safe` writes its receipt.

## The yard lock model

`models/YardLock.tla` checks the Spillway's yard lock and its overtime bell (FV-2): `sketches/core-loop/src/world/stage_locks.gd` and `sketches/core-loop/src/world/overtime.gd`, driven by the run flow in `sketches/core-loop/src/core/flow.gd`. In one physics frame flow's tick and the locks' tick read the same ball, flow first, and the ball moves after both in the physics server; every interruption comes between frames. Its rules:

| Rule                   | The promise                                                                                               | What breaks for the player                                        |
| ---------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `WallOnlyWhileLocked`  | The wall stands only while the yard is shut on a stage in play.                                           | A wall left over a stage the run has left.                        |
| `LockAlwaysOpens`      | A shut yard always opens while the stage plays on.                                                        | The ball is trapped.                                              |
| `NoLockInWardenFight`  | As the locks tick ends, the yard is never shut while the Warden is awake (woken by the ring or a strike). | The Warden's fight happens inside the yard's wall, with its crew. |
| `YardPaysOnce`         | A yard pays its panel at most once an activation.                                                         | The yard pays twice.                                              |
| `OvertimeOnlyAfterWin` | The bell is offered, rung and cashed only after a won yard, three rings at most, one payout.              | The pot pays without the yard won, or twice.                      |
| `StartCardOnce`        | The lock calls `show_start_card` at most once an activation.                                              | The start card pops twice.                                        |

Run `bash $F/models/make-yardlock-configs.sh`, then plain TLC on each `yardlock-*.cfg` with `YardLock.tla`. [references/yardlock-coverage.md](references/yardlock-coverage.md) maps each step and guard to the code and lists what each config must report; [references/yardlock-findings.md](references/yardlock-findings.md) holds the findings, two open: YL-1 (the yard stays shut through the Warden's fight, when a ball first lands near the beacon or shoots the Warden from inside the yard) and YL-2 (a storeless flow's dead screen keeps the wall). `node scripts/gate/model-receipts.mjs --out <dir> --row yard-lock-safe` writes its receipt from `yardlock-today-unfired` while YL-1 is open, and names both findings as gaps.

`models/EarnedSave.tla` is a smaller model beside the rewards model: the Spare Frame's earned save and the run file that must carry its spend (`sketches/core-loop/src/core/run_state.gd` `_try_death_save`, `sketches/core-loop/src/core/flow.gd` `_on_death_saved`, `_save`, `resume_run`). Run `bash $F/models/make-earnedsave-configs.sh`, then plain TLC on each `earnedsave-*.cfg`. Its rule `SaveOnce` breaks on the code (finding ES-1 in [references/rewards-findings.md](references/rewards-findings.md)): a refused spend write, a quit and a Continue hand the save back.

## The sound arbiter model

`models/SoundArbiter.tla` checks the Sound V4 music ownership arbiter and melodic lane lease across `sketches/core-loop/src/presentation/music_arbiter.gd`, `sketches/core-loop/src/presentation/melody_lease.gd`, `sketches/core-loop/src/presentation/audio.gd` and `sketches/core-loop/src/presentation/ace_sequencer.gd`:

| Rule | The promise | What breaks for the player |
| ---- | ----------- | -------------------------- |
| `WardenOwnsFightMusic` | An engaged, sealed Warden plays the sectioned stage pack unless radio is pinned. | A live champion flat pack silences Warden form drops. |
| `BossMusicInArena` | Inside a boss arena with unpinned radio, the boss track owns the deck. | Unpinning radio mid-boss drops back to stage roam. |
| `BossFinaleWinsOverAll` | Boss phase 3 finale owns the deck even over a pinned radio. | Pinned radio holds over the final boss phase. |
| `UltimateRestoresChampion` | Leaving an ultimate or radio while a champion lives restores the champion pack. | Returning from an ultimate drops champion music to roam. |
| `DeathClearsUltFlight` | Player death clears armed ultimate flight state. | Stale flight flags survive death. |
| `OneMelodyNoClash` | June's set-director answer plays only on allowed stage sections with no warning. | June talks over a warning, drop or directed break. |
| `NoStaleTrim` | Any active stem trim matches the live deck epoch and June's lease. | A cancelled bar trim dims stems on the next section or pack. |

Run `bash $F/models/make-sound-configs.sh`, then plain TLC on each `sound-*.cfg` with `SoundArbiter.tla`. [references/sound-coverage.md](references/sound-coverage.md) maps each step and guard to the code; [references/sound-findings.md](references/sound-findings.md) records the four closed findings (SA-1 to SA-4). `node scripts/gate/model-receipts.mjs --out <dir> --row sound-arbiter-safe` writes its receipt.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VFM-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. `/astack:create-formal-verification-skill maintain` brings the model back in line after changes that skipped this skill.

## Host adapter

- Claude Code: `/scrapkeep-verify-formal`.
- Report the actual model and `CLAUDE_EFFORT` or its absence.
