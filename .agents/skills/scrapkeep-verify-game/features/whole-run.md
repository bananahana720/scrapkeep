# A whole run

A run is the stages of a world, each closed by its Warden, then reward gates, a launch into the next stage, the world's boss, and a summary (RUN COMPLETE or RUN OVER). Minutes of skilled play are more than a step file can script, so this feature is driven by the repo's own bot, which presses the menus as keys and is filmed as a player's screen shows it.

## Sub-features

- `WR-1` Stage 1 plays to its Warden; breaking it opens the reward gates.
- `WR-2` A gate launches the ball into the next stage at speed.
- `WR-3` World 1 to 3 progression is unparked (`Worlds.FULL_ALPHA := true`, `Tuning.FULL_ALPHA_UNLOCKED := true`): a default launch runs all three worlds (`stages=6`: Spillway Works -> Admiral Brindle, The Dig -> The Waking, The Highdraft -> The Mind); passing `--final-world=1` (or `--profile=sitting`) ends the run after world 1's boss, Admiral Brindle (`stages=2`).
- `WR-4` A death shows SCRAPPED / RUN OVER; N starts a new run as the same pilot.
- `WR-5` The summary shows time, stages, scrap, parts and kills, and `runs.ndjson` gains a row.
- `WR-6` The sitting launch (`--profile=sitting`: Heat, Overtime, Called Shot, marked hull, Moss's scale, carry a core, `--final-world=1`) plays from the title to a won run at Brindle, where the sitting's run ends.

## How to get to it (user POV)

- Start a run ([Start a run](./start-a-run.md)) and play. Hold R to restart; get scrapped for RUN OVER.

## Driving it with drive.sh

Whole runs exceed step-file length, so drive this feature through `$S/bot-run.sh` (macOS offscreen Metal or Linux `xvfb-run` with isolated saves) or `scripts/redteam/eye.mjs` (Linux-only `xvfb-run` + `opengl3`).

- **WR-6 (sitting run to Brindle):** `$S/bot-run.sh --offscreen sitting-run -- --profile=sitting` (pass `-- --profile=sitting --self-play-until=2` for a bounded 2-stage smoke). Expect exit 0, `SCRAPKEEP_MENU_READY ... profile=sitting pilots=6/6`, stage transitions, `stuck=0 hung=0 wedged=0 fell=0`, `film/film.ndjson`, and `saves/self-play-verify-bot/runs.ndjson`.
- **WR-1, WR-2 (Linux red-team film, stops at World 2 entry via `--self-play-until=3`):** `env XDG_DATA_HOME="$PWD/artifacts/local/verify-game/film-home" node scripts/redteam/eye.mjs --persona=first-timer --film=whole --out=artifacts/local/verify-game/film-whole`. Expect exit 0, `film/film.ndjson`, `reader/001.jpg ...`, and `judge/SHEET.md`. (Omit `--self-play-until=3` or use `bot-run.sh` with `--self-play-until=win` for a full `WR-3`/`WR-5` 6-stage run.)
- **WR-4 (death and new run, Linux `eye.mjs`):** `env XDG_DATA_HOME="$PWD/artifacts/local/verify-game/film-home" node scripts/redteam/eye.mjs --persona=cautious --film=wait --death-at=20 --out=artifacts/local/verify-game/film-death`.
- **Headless `--self-play` without film:** Pass `--self-play --self-play-keys=1 --self-play-until=win --self-play-watch=1` (flags in `sketches/core-loop/tools/self_play.gd` `_ready()`), always isolating saves (`HOME` and `XDG_DATA_HOME` under `artifacts/local/` on macOS, `XDG_DATA_HOME` on Linux).
- **`runs.ndjson`:** Inspect `<evidence>/saves/self-play-verify-bot/runs.ndjson` via `node scripts/run-summary.mjs --last 5 --file <path>`.

## Gotchas

- `scripts/redteam/eye.mjs` hardcodes Linux `xvfb-run` + `opengl3` (`eye.mjs:69,92`); on macOS use `$S/bot-run.sh --offscreen`. Never pass only `XDG_DATA_HOME` to raw Godot on macOS (macOS Godot reads `HOME`, see `references/lessons.md` VGM-06).
- With `--self-play-eyes=1` (`bot-run.sh` and `eye.mjs` default), `game.bot_driven` stays `false` and the bot answers the kit pick and start pick via `KEY_1` (`self_play.gd`).
- Check engine noise (`grep -c '^ERROR' <evidence>/game.log`) alongside `exit 0`; a noisy log is a finding even on a won run.
- The bot is not a player: a finished run says the path is open, never that it is fun or fair. Bands and difficulty belong to the challenge band checks (`npm run sketch:world1-bands`, `npm run challenge:bands`) and the gate.
- A planted death (`--death-at`) proves the death screen and way out, not that the hit was fair.
- `bot-run.sh` and `eye.mjs` film only kept frames and play synth audio if Oggs are absent, so neither measures frame time, look, or audio feel.
