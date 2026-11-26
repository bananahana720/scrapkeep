# First run on the packed build

A new player on the packed game reads the prologue, picks Sable, takes the kit pick (the start pick waits until the stage 1 yard lock on a fresh profile), and rolls in stage 1; the run and profile are saved.

## Sub-features

- `FR-1` The first-run path works on the packed game the same as from source (see [Start a run](../../scrapkeep-verify-game/features/start-a-run.md) `SR-1` to `SR-5`).
- `FR-2` The save folder gains the profile, the run save and the run log.

## How to get to it (user POV)

- Launch the packed game, Space on the title, E through the prologue, 1 for Sable, 1 on the kit pick (and 1 on the start pick once unlocked or at the stage 1 yard lock).

## Driving it with build.sh

Preconditions: baseline; game flag `--no-intro`.

- **FR-1:** `$B drive .agents/skills/scrapkeep-verify-game/features/steps/start-a-run.steps first-run -- --no-intro`. Expect exit 0 and 30 passed steps; captures `prologue`, `pilot-select`, `kit-pick`, `dropped-in`, and `after-rolling`. (`StartPickCard` is deferred until the stage 1 yard lock on a fresh profile.)
- **FR-2:** the evidence's `files-written.txt` lists `self-play-verify/profile.json`, `run.json` and `runs.ndjson`.
- **Further:** any step file of the game skill (settings, pause, save and continue) runs the same way through `$B drive`.

## Gotchas

- The save folder's name starts `self-play-`: a driven game keeps its saves apart from a player's, so this does not prove the path of the player's own save file. The sitting on the PC does.
- See the game skill's [Start a run](../../scrapkeep-verify-game/features/start-a-run.md) for the traps of the picks and the pause state.
