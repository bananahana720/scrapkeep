# A whole run

A run is the stages of a world, each closed by its Warden, then reward gates, a launch into the next stage, the world's boss, and a summary (RUN COMPLETE or RUN OVER). Minutes of skilled play are more than a step file can script, so this feature is driven by the repo's own bot, which presses the menus as keys and is filmed as a player's screen shows it.

## Sub-features

- `WR-1` Stage 1 plays to its Warden; breaking it opens the reward gates.
- `WR-2` A gate launches the ball into the next stage at speed.
- `WR-3` World 1–3 progression is unparked (`Worlds.FULL_ALPHA := true`, `Tuning.FULL_ALPHA_UNLOCKED := true`): a default launch runs all three worlds (`stages=6`: Spillway Works -> Admiral Brindle, The Dig -> The Waking, The Highdraft -> The Mind); passing `--final-world=1` (or `--profile=sitting`) ends the run after world 1's boss, Admiral Brindle (`stages=2`).
- `WR-4` A death shows SCRAPPED / RUN OVER; N starts a new run as the same pilot.
- `WR-6` The sitting launch (`--profile=sitting`: Heat, Overtime, Called Shot, marked hull, Moss's scale, carry a core, `--final-world=1`) plays from the title to a won run at Brindle, where the sitting's run ends.
- `WR-5` The summary shows time, stages, scrap, parts and kills, and `runs.ndjson` gains a row.

## How to get to it (user POV)

- Start a run ([Start a run](./start-a-run.md)) and play. Hold R to restart; get scrapped for RUN OVER.

## Driving it with the film (scripts/redteam/eye.mjs)

Preconditions: `GODOT_BIN` set; the project imported; a display or `xvfb-run`. The film tool and the bare bot do not move the game's save folder themselves, so every command here starts with a scratch one: set `F="XDG_DATA_HOME=$PWD/artifacts/local/verify-game/film-home"` and launch with `env $F`. Without it the bot would write beside the player's own saves on Andrew's PC, which needs his go-ahead. About four wall seconds for each game second in the cloud, so a whole film is a long run: follow the project's rule for where long runs go.

- **WR-6 (the sitting run to Brindle), run 13 November 2026:** `.agents/skills/scrapkeep-verify-game/scripts/bot-run.sh sitting-run -- --profile=sitting`, in the background. It sets its own scratch save folder. Expect exit 0 and, in `game.log`, `SCRAPKEEP_MENU_READY ... profile=sitting pilots=6/6`, then `self-play: stage 1 exit taken`, `stage 2 entered`, `boss arena entered`, `boss defeated`, `run won`, and a watch line with `stuck=0 hung=0 wedged=0 fell=0`. `film/film.ndjson` has a row a kept picture (flow state, stage, objective plate, hull); `saves/self-play-verify-bot/runs.ndjson` gains the run's row with `outcome` `won`. That run: won at 398 game seconds, 168 pictures, 22 wall minutes in the cloud. Then count the engine's complaints: `grep -c '^ERROR' game.log` (see Gotchas).
- **WR-1 to WR-3, WR-5 (a first-timer's whole run):** `env $F node scripts/redteam/eye.mjs --persona=first-timer --film=whole --out=artifacts/local/verify-game/film-whole`. Expect exit 0. `film/film.ndjson` has one row a kept frame with the game's own state; `reader/001.jpg ...` are the pictures; `judge/SHEET.md` sets each picture beside what the game knew.
- **WR-4 (death and the new run):** `env $F node scripts/redteam/eye.mjs --persona=cautious --film=wait --death-at=20 --out=artifacts/local/verify-game/film-death`. The film holds the death screen and the second run in play.
- **The same run without pictures** (stage entries, exits, the boss, a stall detector): the `--self-play` flags in the header of `sketches/core-loop/tools/self_play.gd`, for example `--self-play --self-play-keys=1 --self-play-until=win --self-play-watch=1`, launched with the same `env $F`. Quit code 0 is the goal reached, 1 the run ended first, 3 a stall.
- **`runs.ndjson`:** the bot's log is in its own save folder, so name it: `find artifacts/local/verify-game/film-home -name runs.ndjson`, then `node scripts/run-summary.mjs --last 5 --file <that file>`. With no `--file` the tool reads the player's own log, which is not this run's.

## Gotchas

- Apart from the sitting run, these commands were not run when this skill was written (13 November 2026); the film tool and its flags are the red team's and are documented in `scripts/redteam/README.md`. Run `node scripts/redteam/eye.mjs` with no flags to see the personas if a flag is refused.
- The sitting run of 13 November logged 3,276 `The axis ... must be normalized` errors from the enemies' gait and motion scripts and 1,124 `Too many instances using shader instance variables` errors. The second may belong to the cloud's renderer; the first does not. A won run with a noisy log is not a clean run: read the counts.
- The game still knows a bot is driving in a film (unlike `drive.sh`), so the launch take and the start-pick card do not show; [Start a run](./start-a-run.md) covers those by hand.
- The bot is not a player: a finished run says the path is open, never that it is fun or fair. Bands and difficulty belong to the challenge band checks (`npm run sketch:world1-bands`, `npm run challenge:bands`) and the gate.
- A planted death (`--death-at`) is a test plant: it proves the death screen and the way out, not that the hit was fair.
- The film draws only the frames it keeps, so it is never a frame-time reading.
- Cloud boxes play the synth music; a PC with synced stems plays the recorded band. Say which.
