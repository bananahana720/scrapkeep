---
name: scrapkeep-verify-game
description: "Verify a Scrapkeep game feature by launching the Godot game from source and playing it with real keys and clicks, with pictures, step rows and the save files as proof. Use when a change touches something a player sees or presses (menus, pilot select, a run, pause, settings, saves) and you need to show it working in the running game; which checks qualify a diff stays in scrapkeep-verify, the packed Linux build in scrapkeep-verify-build, and the browser pages in scrapkeep-verify-web."
---

# Verify a game feature in the running game

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns one thing: a proof that a player-facing feature of `sketches/core-loop` works, made by driving the launched game the way a player does. It does not pick the checks a pull request needs (`scrapkeep-verify`) or qualify the packed build (`scrapkeep-verify-build`). A drive is not a feel verdict and not a frame-time reading: Andrew's play and the 4080 own those.

All commands run from the repository root. `S=.agents/skills/scrapkeep-verify-game/scripts`.

## Launch

1. Godot 4.7.2 must be found: `GODOT_BIN`, else the binary `node scripts/godot-home.mjs --bin` prints (`resolveGodotBinary` in `scripts/godot-home.mjs` lists where it looks on each machine; the cloud's copy comes from `tools/cloud/setup.sh`). (design choice)
2. Import once per checkout, and again after assets change: `node scripts/import-stamp.mjs import` (or `"$GODOT_BIN" --headless --path sketches/core-loop --import`). Run it up to three times and take the first exit 0 with no `SCRIPT ERROR` (`scripts/sketch-smoke.mjs` `importWithRetry`). (VGM-01)
3. Each drive runs a short isolated game process: `$S/drive.sh [--offscreen] <steps file> [<evidence name>] [-- <game flags>]`. On Linux it draws under `xvfb-run` + `opengl3`; on macOS it runs offscreen (`--embedded --rendering-driver metal --debug --audio-driver Dummy`, zero Cocoa window, `HOME` isolated under `artifacts/local/`). Both run at `1280x720` and 30 fixed frames per game second. (VGM-02, VGM-06)
4. Ready means `SCRAPKEEP_MENU_READY` in `<evidence>/game.log`, plus first steps `until clickable "Settings" 120` and `until read get_node_or_null("/root/Boot") == null 30`. (VGM-03)
5. Useful flags after `--`: `--no-intro`, `--table=park|alpha|slice|default`, `--profile=sitting` (6 pilots open), `--dev`. Set `VERIFY_GAME_DISPLAY=1` and `--drive-live=1` only when watching a live window is intended.

## Doctor

Run `$S/doctor.sh` first, and again whenever a drive does something you did not expect. It is read-only. It prints the checkout and commit, and fails on a missing or wrong Godot, an unimported project, a missing display, or a `McpBridge` autoload left in `project.godot` by a Godot MCP session (another session is running the game from this checkout). It lists drives already running; more than one is safe, because each has its own display and save folder.

## Drive

A step file is plain text, one step a line; `scripts/drive.gd` lists every step in its header. The game loads the driver through its own `--self-play-script` hook, so nothing tells the game a bot is playing: the boot card, the prologue, the kit pick and the start pick all show, and every key and click goes through Godot's input path. (VGM-04)

| Step | Use it for |
| --- | --- |
| `key SPACE`, `key 1`, `key P`, `down W` / `up W`, `tap_until E no_text "FIRST SHIFT" 90` | the keys the README's control tables name; they are the stable handles |
| `click "Settings"`, `until clickable "Continue" 10` | a button by the words on it; a click fails if something covers it, or while the mouse is the camera's (in play) |
| `until state class_select 30`, `until play 60`, `until text "Rig your kit" 60` | waiting for the game, never a bare `wait`, before the next press |
| `shot <name>`, `ui` | a picture; the list of every visible control with its words and box |
| `read <expression>`, `until read not get_tree().paused 30` | a live value from the game node, written to the row as ground truth |

Start from the feature file under [features/](features/README.md) that matches the change, copy its step file from `features/steps/`, and add the steps that show your change. A proof that drives one convenient entry point is incomplete when the map lists others.

## Evidence

Everything lands in `artifacts/local/verify-game/<evidence name>/`: pictures (`NN-<name>.png`), `steps.ndjson`, `NN-ui.txt`, `game.log`, `identity.txt`, `steps.txt`, `files-written.txt`, and the saves folder. Attach decisive pictures and rows to the pull request receipt.

Proof standards:

- Drive the player's path; `read` confirms state without changing it.
- Capture a picture before and after each key press, and inspect the save files listed in `<evidence>/files-written.txt`.
- Open captured images with `read_file` before claiming a pass. (VGM-05)
- State renderer and audio limits: dummy audio driver, fixed frame step, synth music if Oggs are absent, software `opengl3` on Linux `xvfb-run` or Metal offscreen on macOS (never an RTX 4080 look or frame-time proxy).

## Cleanup

`drive.sh` removes its own scratch save folder on exit. Run `$S/cleanup.sh` after failed or interrupted drives (`--stop <name>` stops one running drive by PID file; pass `VERIFY_GAME_HOME` to clean a shared save folder). Never kill Godot by name.

## Helpers

| Script | Role | Exit codes / notes |
| --- | --- | --- |
| `$S/doctor.sh [--offscreen]` | Read-only check | `0` ok, `1` missing Godot/import/display or `McpBridge` in `project.godot` |
| `$S/drive.sh [--offscreen] <steps> [<name>] [-- <flags>]` | Real-input step drive | `0` pass, `1` step fail (or display fail if 0 rows), `2` bad args, `3` unexpected quit, `124`/`137` timeout (`VERIFY_GAME_TIMEOUT`, default `1500` s), `143` stopped; `VERIFY_GAME_HOME=<dir>` shares saves |
| `$S/bot-run.sh [--offscreen] <name> [-- <flags>]` | Offscreen bot film & saves | `0` goal reached, `1` ended early, `3` stall, `2` bad args, `124`/`137` timeout (default `7000` s), `143` stopped |
| `$S/cleanup.sh [--stop <name>] [<shared dir>]` | Safe teardown | Keeps evidence folders and removes scratch home dirs |
| `scripts/drive.gd` | In-game step driver | Header lists every step verb and `read` rule |

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VGM-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. Keep `features/` current with `/pstack:maintain-verification-skill`.

## Host adapter

- Antigravity: `/scrapkeep-verify-game`. Open captured PNGs directly via `read_file` for Gemini multimodal checks, use `godot_godot` MCP only with `stop_project` before commit, and report active Gemini model/tier.
- Claude Code: `/scrapkeep-verify-game`.
- Report the actual model and active effort or tier (or its absence).
