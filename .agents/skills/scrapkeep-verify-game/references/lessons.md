# Verify-game lessons

## Lessons

- **VGM-01** · status: established · since: 2026-11-13 · origin: `scripts/sketch-smoke.mjs` import retry
  A first import of a fresh `.godot` can crash or print `SCRIPT ERROR` and still be fine on the next try. Import up to three times and take the first clean one.
  Evidence: `scripts/sketch-smoke.mjs` (`importTry`, `importWithRetry`).
  Overturned by: none
- **VGM-02** · status: provisional · since: 2026-11-13 · origin: the first drives of this skill
  Under the cloud's software renderer the title costs over a second a drawn frame: a drive that drew every frame took 4 minutes to reach the menu, and one that draws only the frames it keeps took 1 minute for 24 steps. The driver turns the render loop off between pictures, as the film tool does.
  Evidence: the thread's proof run on stage/alpha-w40 6d4320b8, 13 November 2026; `sketches/core-loop/tools/eye_film.gd`.
  Overturned by: none
- **VGM-03** · status: provisional · since: 2026-11-13 · origin: the first drives of this skill
  The boot card sits over the title for the first seconds and has its own "Play" button, and the title's controls are already in the tree under it. Words in the tree are not words a player can press: wait for `until clickable`, which asks the engine what is under the pointer, and for the boot card node to be gone.
  Evidence: `sketches/core-loop/src/boot/boot.gd`; the thread's proof run, 13 November 2026.
  Overturned by: none
- **VGM-04** · status: provisional · since: 2026-11-13 · origin: the self-play hook in the game script
  The game's `--self-play-script=<path>` hook loads any script as the bot and gives the run a save folder of its own, and it takes a path outside `res://`. A driver loaded that way leaves `bot_driven` unset, so the game shows what a player's game shows.
  Evidence: `sketches/core-loop/src/game.gd` (`_start_self_play`); `sketches/core-loop/tools/self_play.gd` (`_ready()`).
  Overturned by: none
- **VGM-05** · status: provisional · since: 2026-11-13 · origin: the first drives of this skill
  A step list can pass while the picture is wrong: a drive that pressed Continue early passed every step with the boot card frozen over the screen. Open the pictures before calling a proof.
  Evidence: the thread's proof run, 13 November 2026.
  Overturned by: none
- **VGM-06** · status: provisional · since: 2026-11-25 · origin: Mac Studio offscreen verification pass
  On macOS Godot 4.7.2 ignores `XDG_DATA_HOME` and writes `user://` under `$HOME/Library/Application Support/Godot/app_userdata/core-loop`, and `--embedded` without `--debug` segfaults inside `DisplayServerMacOSEmbedded`. Launch macOS offscreen drives with `--embedded --rendering-driver metal --debug --skip-breakpoints --ignore-error-breaks` and `HOME` set to a scratch folder under `artifacts/local/` so no Cocoa window opens and real saves are never touched.
  Evidence: `scripts/gate/display-run.mjs`; `scripts/godot-home.mjs`; `project-guide/handoff/DEVICES.md`; maintenance pass at 46576920, 25 November 2026.
  Overturned by: none

## Changelog

| Date | Change |
| --- | --- |
| 2026-11-13 | VGM-01 to VGM-05 added with the skill. |
| 2026-11-25 | VGM-06 added for macOS `--embedded --rendering-driver metal --debug` offscreen drives and `HOME` isolation. |
| 2026-11-26 | Verified all 10 `.steps` drives + `--offscreen` `scripts/bot-run.sh` sitting smoke at `aa5c74047`; closed resolved `features/work-orders-and-logbook.md` layout bug; fixed `features/start-a-run.md` (`C` key, `Carbon Tape`/`Breaker Fuse`), `features/pause-and-notes.md` (`Tab`), `features/launch-and-menus.md` (`C`/`M`/`B`), `features/whole-run.md` (`scripts/redteam/eye.mjs` Linux-only / `--self-play-eyes=1` / order), `SKILL.md`, `scripts/doctor.sh`, `scripts/bot-run.sh`, and `scripts/drive.gd`. |
