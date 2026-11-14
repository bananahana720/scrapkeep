# First run on the packed build

A new player on the packed game reads the prologue, picks Sable, takes the kit pick and the start pick, and rolls in world 1's first stage; the run and the profile are saved.

## Sub-features

- `FR-1` The first-run path works on the packed game exactly as from source (the game skill's `SR-1` to `SR-5`).
- `FR-2` The save folder gains the profile, the run save and the run log.

## How to get to it (user POV)

- Launch the packed game, Space on the title, E through the prologue, 1 for Sable, 1 on each pick.

## Driving it with build.sh

Preconditions: baseline; game flag `--no-intro`.

- **FR-1:** `$B drive .agents/skills/scrapkeep-verify-game/features/steps/start-a-run.steps first-run -- --no-intro`. Expect exit 0 and 31 passed steps; the pictures `kit-pick`, `start-pick`, `dropped-in`, `after-rolling`.
- **FR-2:** the evidence's `files-written.txt` lists `self-play-verify/profile.json`, `run.json` and `runs.ndjson`.
- **Further:** any step file of the game skill (settings, pause, save and continue) runs the same way through `$B drive`.

## Gotchas

- The save folder's name starts `self-play-`: a driven game keeps its saves apart from a player's, so this does not prove the path of the player's own save file. The sitting on the PC does.
- See the game skill's [Start a run](../../scrapkeep-verify-game/features/start-a-run.md) for the traps of the picks and the pause state.
