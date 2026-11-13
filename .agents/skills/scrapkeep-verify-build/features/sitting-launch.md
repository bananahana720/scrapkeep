# The sitting launch

The app menu entry's second action, "Scrapkeep sitting", launches the game with `--profile=sitting`: all six pilots are open on a new save, and the loop mechanics Andrew wants at the sitting are on. The default launch opens Sable only.

## Sub-features

- `SL-1` `--profile=sitting` prints `SCRAPKEEP_MENU_READY ... profile=sitting pilots=6/6`.
- `SL-2` Pilot select shows six open cards, and a second pilot's key starts a run as that pilot.
- `SL-3` Control: the default launch prints `pilots=1/6`, shows five locks, and the second pilot's key starts nothing.
- `SL-4` The sitting launch never writes the player's real save.

## How to get to it (user POV)

- Right-click "Scrapkeep" in the launcher and pick "Scrapkeep sitting"; or run `./core-loop.x86_64 -- --profile=sitting`.

## Driving it with build.sh

Preconditions: baseline; game flag `--no-intro`.

- **SL-1, SL-2:** `$B drive .agents/skills/scrapkeep-verify-build/features/steps/sitting-profile.steps sitting -- --no-intro --profile=sitting`. Expect exit 0 and 16 passed steps. The picture `pilot-select-all-open` shows no lock; the `read player.class_def.id` row holds `runner_gunner` (Rivet).
- **SL-3:** `$B drive .agents/skills/scrapkeep-verify-build/features/steps/locked-pilot-control.steps control -- --no-intro`. Expect exit 0 and 13 passed steps; the picture `pilot-select-one-open` shows five locks and the state is still `class_select` four seconds after key 2.
- **SL-4:** not reachable from a drive: a driven game always saves to its own folder, so it cannot show what the sitting launch does to a player's save. The rule is tested in the repo (search the sketch tests for the sitting profile) and seen at the sitting.

## Gotchas

- "Pick one" is on the pilot select and on the kit pick. Wait for `until play 120` after the pilot key, not for those words.
- `--profile=sitting-earned` is a third launch set (a profile of its own that unlocks as a new player's does); it is not mapped here.
- The menu entry itself exists only after an install; see [Package and installer](./package-and-installer.md).
