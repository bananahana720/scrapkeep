# A whole run

A run is the stages of a world, each closed by its Warden, then reward gates, a launch into the next stage, the world's boss, and a summary (RUN COMPLETE or RUN OVER). Minutes of skilled play are more than a step file can script, so this feature is driven by the repo's own bot, which presses the menus as keys and is filmed as a player's screen shows it.

## Sub-features

- `WR-1` Stage 1 plays to its Warden; breaking it opens the reward gates.
- `WR-2` A gate launches the ball into the next stage at speed.
- `WR-3` The last stage launches into Admiral Brindle's arena; the boss has phases.
- `WR-4` A death shows RUN OVER; N starts a new run as the same pilot.
- `WR-5` The summary shows time, stages, scrap, parts and kills, and `runs.ndjson` gains a row.

## How to get to it (user POV)

- Start a run ([Start a run](./start-a-run.md)) and play. Hold R to restart; get scrapped for RUN OVER.

## Driving it with the film (scripts/redteam/eye.mjs)

Preconditions: `GODOT_BIN` set; the project imported; a display or `xvfb-run`. About four wall seconds for each game second in the cloud, so a whole film is a long run: follow the project's rule for where long runs go.

- **WR-1 to WR-3, WR-5 (a first-timer's whole run):** `node scripts/redteam/eye.mjs --persona=first-timer --film=whole --out=artifacts/local/verify-game/film-whole`. Expect exit 0. `film/film.ndjson` has one row a kept frame with the game's own state; `reader/001.jpg ...` are the pictures; `judge/SHEET.md` sets each picture beside what the game knew.
- **WR-4 (death and the new run):** `node scripts/redteam/eye.mjs --persona=cautious --film=wait --death-at=20 --out=artifacts/local/verify-game/film-death`. The film holds the death screen and the second run in play.
- **The same run without pictures** (stage entries, exits, the boss, a stall detector): the `--self-play` flags in the header of `sketches/core-loop/tools/self_play.gd`, for example `--self-play --self-play-keys=1 --self-play-until=win --self-play-watch=1`. Quit code 0 is the goal reached, 1 the run ended first, 3 a stall.
- **`runs.ndjson`:** `node scripts/run-summary.mjs --last 5` prints one line a run from the game's log.

## Gotchas

- These two commands were not run when this skill was written (13 November 2026); the film tool and its flags are the red team's and are documented in `scripts/redteam/README.md`. Run `node scripts/redteam/eye.mjs` with no flags to see the personas if a flag is refused.
- The bot is not a player: a finished run says the path is open, never that it is fun or fair. Bands and difficulty belong to `scrapkeep-lab` and the gate.
- A planted death (`--death-at`) is a test plant: it proves the death screen and the way out, not that the hit was fair.
- The film draws only the frames it keeps, so it is never a frame-time reading.
- Cloud boxes play the synth music; a PC with synced stems plays the recorded band. Say which.
