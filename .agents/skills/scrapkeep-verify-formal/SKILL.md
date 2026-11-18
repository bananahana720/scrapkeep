---
name: scrapkeep-verify-formal
description: "Check by model the promises Scrapkeep's run flow and launch swipe make under every interruption (death, retry, new run, quit, Continue, either order of the gate's two signals), with a TLA+ model kept beside this skill, and check by a second model that an earned reward is banked once and never lost through crashes, failed saves and two games on one profile, and by a third that a park flood never holds full water under the ball. Use when a change touches the park event step in event_director.gd, flow.gd, launch_take.gd or the launch swipe calls in game.gd, or profile.gd, safe_store.gd, run_store.gd or the settle and grant calls in progress.gd, when a review finds an interruption that breaks a launch or a run's end, or when asked to formally verify or model-check the run flow; which tests qualify a diff stays in scrapkeep-verify, and playing the game stays in scrapkeep-verify-game."
---

# Check the run flow against its model

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns one formal check. A test plays the orders of events someone wrote down. This check tries every order of the steps in `models/RunFlow.tla`, a small model of a run from the title to its summary and of the launch swipe (the comic panel that covers the cut between stages). It does not replace a test: `scrapkeep-verify` still picks the tests for a diff, and a model result says nothing about feel, timing in seconds or drawing.

`F=.agents/skills/scrapkeep-verify-formal`. Paths in the tables are under `sketches/core-loop/src`.

## The rules

Each rule is one promise to the player. [references/coverage.md](references/coverage.md) has the code behind every step of the model.

| Rule | The promise | What breaks for the player |
| --- | --- | --- |
| `TakeNamesHeldPart` | When the swipe closes over a launch, it names a part only if the live run holds it. | The screen says a part was taken that the run does not have. |
| `SeamOwned` | The flow waits for the swipe's cut only while a swipe really owes one. | The launch never lands and the run hangs in the air. |
| `LaunchLands` | Every launch ends: the next stage, the boss or the summary. | The same hang, as a rule about time. |
| `WardenGoneOpens` | A sealed stage whose Warden is gone opens its gates. | A stage with nothing to fight and no way on. |
| `EndsOnce` | A run ends at most once. | Rewards and the run log are written twice. |
| `PickHeard` | A pilot pick is never dropped without a sign. | A press on pilot select does nothing. |
| `StampOnlySeam` | A pilot pick's swipe never carries a part's name. | The run-start swipe shows a part instead of its own word. |

## Is this change covered?

1. Run `git diff --stat <sync commit> -- <files>`, where `<files>` is every `sketches/core-loop/src` file that [references/coverage.md](references/coverage.md) cites (for the rewards model, [references/rewards-coverage.md](references/rewards-coverage.md)); `scripts/gate/model-receipts.mjs` reads the same list. A step that comes to read a new file must cite it there. The sync commit is the last line of the coverage page. That form compares the sync commit with the working tree, so it sees uncommitted changes too (VFM-09). No output: the model still describes the code, go to "Run it".
2. With output, read the diff of every function named in the coverage table, and look for a new caller of a covered function or a new writer of `_seam_take`, `_taken_part`, `_launched`, `run.over` or the swipe's `phase`. A new way to interrupt a run is a new action even when no covered function changed (VFM-05).
3. A change that removes or adds a guard the coverage table names: set that constant on the two `today-*` lines of `models/make-configs.sh` to what the code now does, so `today-*` stands for the code under check (VFM-09). Any other change: change the model from the code before you run it, never from what makes it pass. One call in the code is one action in the model; two handlers of one signal are one action with an order choice (VFM-06). Then move the sync commit.

## Run it

1. Run `bash $F/models/make-configs.sh`. It rewrites every `.cfg` from the one table of guards in that script, so a config never drifts from its neighbours. (design choice)
2. Check each config with the `astack:statechart` skill, giving it `RunFlow.tla` and the config. That skill owns the checker command and reads a result as a shortest path in plain words; give each run a new output folder outside the repository. Each run takes a few seconds.
3. Compare with this table. Anything else is a result to explain, in "Read a result".

| Config | Stands for | Must report |
| --- | --- | --- |
| `guarded-store`, `guarded-nostore`, `guarded-lastgate` | every guard in place: the real game, the store-less test flow, and a run with no swipe at its last gate | no break |
| `today-store`, `today-nostore` | the code at the sync commit | only the open findings in [references/findings.md](references/findings.md) |
| `broken-newrun` | `_begin_run` without `_untake` | `TakeNamesHeldPart` breaks |
| `broken-retry` | `retry_stage` without `_untake` | `TakeNamesHeldPart` breaks |
| `broken-end` | `_end_run` without `_untake` | `TakeNamesHeldPart` breaks |
| `broken-vanish` | no `_warden_vanished` tick | `WardenGoneOpens` breaks |
| `broken-endguard` | `_on_player_died` without its `in_play` guard | `EndsOnce` breaks |
| `broken-keys` | screen keys not swallowed under the swipe | `PickHeard` breaks |
| `broken-busy` | a busy swipe not refused, with the time assumption off too (a busy swipe cannot meet a launch otherwise) | `SeamOwned`, `StampOnlySeam`, `LaunchLands` break |
| `reach-store`, `reach-nostore` | probes that say "never" about things that must happen | every probe breaks; one that holds means an action can no longer fire (VFM-10) |
| `untimed` | the time assumption off | `TakeNamesHeldPart` breaks, by a path no player can make |

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

| Rule | The promise | What breaks for the player |
| --- | --- | --- |
| `AtMostOnce` | No reward id is granted twice. | The earn is announced and paid twice. |
| `NeverLost` | An earned and settled reward id is granted after any crash and reload. | A cosmetic or world the player earned never arrives. |

Run it with `bash $F/models/make-rewards-configs.sh`, then each `rewards-*.cfg` as in "Run it"; the two-game configs need plain TLC with several workers. [references/rewards-coverage.md](references/rewards-coverage.md) has the code behind each step, the config table with what each config must report, and what is not modelled. Its findings are in [references/rewards-findings.md](references/rewards-findings.md). The rest of this skill (covered changes, reading a result, replays, broken variants, reach probes) applies to it unchanged.

## The flood model

A third model, `models/ParkFlood.tla`, checks a park flood from its announcement to its end in `sketches/core-loop/src/world/event_director.gd` (`_park_step_live`, `_park_capacity`, `_park_can_end`), with the ball free to roll into or out of any basin between any two ticks. Its rules:

- **FullWaterNeverHeld.** While its live time runs, water that has risen for its whole fill time is stepped on every tick, ball or no ball.
- **FullWaterFreesItsSlot.** Full water with no live time stops counting against the ground cap.
- **NeverRisesUnderBall** and **NeverEndsUnderBall.** Water neither rises nor ends while a grounded ball is in its basin.
- **WithinCap.** No more unsettled ground events are live than the cap allows.
- **FloodEnds** and **AnnouncedLands.** Once the ball stays out, every live flood ends and every announced one lands.

Run `bash $F/models/make-flood-configs.sh`, then plain TLC on each `flood-*.cfg` with `ParkFlood.tla`. [references/flood-coverage.md](references/flood-coverage.md) maps each step and guard to the code and lists what each config must report, and [references/flood-findings.md](references/flood-findings.md) holds the findings, one of them an open design question. `node scripts/gate/model-receipts.mjs --out <dir> --row flood-never-held` writes its receipt.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VFM-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. `/astack:create-formal-verification-skill maintain` brings the model back in line after changes that skipped this skill.

## Host adapter

- Claude Code: `/scrapkeep-verify-formal`.
- Report the actual model and `CLAUDE_EFFORT` or its absence.
