---
name: scrapkeep-verify-game
description: "Verify a Scrapkeep game feature by launching the Godot game from source and playing it with real keys and clicks, with pictures, step rows and the save files as proof. Use when a change touches something a player sees or presses (menus, pilot select, a run, pause, settings, saves) and you need to show it working in the running game; which checks qualify a diff stays in scrapkeep-verify, bot batches and pins in scrapkeep-lab, the packed Linux build in scrapkeep-verify-build, and the browser pages in scrapkeep-verify-web."
---

# Verify a game feature in the running game

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns one thing: a proof that a player-facing feature of `sketches/core-loop` works, made by driving the launched game the way a player does. It does not pick the checks a pull request needs (`scrapkeep-verify`), run bot batches or pins (`scrapkeep-lab`), or qualify the packed build (`scrapkeep-verify-build`). A drive is not a feel verdict and not a frame-time reading: Andrew's play and the 4080 own those.

All commands run from the repository root. `S=.agents/skills/scrapkeep-verify-game/scripts`.

## Launch

1. Godot 4.7.2 must be found: `GODOT_BIN`, else `godot` on `PATH`, else the cloud toolchain at `/opt/scrapkeep-toolchain/` (`tools/cloud/setup.sh` installs it). (design choice)
2. Import once per checkout, and again after assets change: `"$GODOT_BIN" --headless --path sketches/core-loop --import`. It takes about ten minutes in the cloud. A first import can crash or print `SCRIPT ERROR`; run it up to three times and accept the first run that exits 0 with no `SCRIPT ERROR` line (`scripts/sketch-smoke.mjs` `importWithRetry` has the rule). (VGM-01)
3. There is no server to keep alive. Each drive is its own short game process: `$S/drive.sh <steps file> [<evidence name>] [-- <game flags>]`. It starts the game on a display of its own (`xvfb-run`), at 1280x720 and a fixed 30 frames a game second, plays the step file and quits. A menu drive takes about a minute in the cloud. (VGM-02)
4. Ready means the line `SCRAPKEEP_MENU_READY` in `<evidence>/game.log` and a first step that waits for the menu: `until clickable "Settings" 120`, then `until read get_node_or_null("/root/Boot") == null 30` so the boot card has gone. (VGM-03)
5. Useful game flags after `--`: `--no-intro` (skip the title opening), `--table=park|slice|default`, `--profile=sitting` (all six pilots open), `--dev`. On a machine with a graphics card and somebody watching, set `VERIFY_GAME_DISPLAY=1` and add `--drive-live=1`.

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

Everything lands in `artifacts/local/verify-game/<evidence name>/`: the pictures (`NN-<name>.png`), `steps.ndjson` (one row a step: the step, pass or fail, game seconds, flow state, paused), `NN-ui.txt`, `game.log`, `identity.txt` (commit, branch, dirty paths, Godot version, exit code), `steps.txt`, and a `saves` folder with `files-written.txt` (a copy of the game's save folder as the run left it). That folder is gitignored scratch: attach the decisive pictures and rows to the pull request's receipt, or copy them to the area's folder under `/mnt/project-files/`.

Proof standards:

- Drive the player's path. `read` may confirm a value; it never sets one, and a call that changes game state is not a proof.
- Show the action and the result: a picture before the press and one after, not only the last screen.
- Check the side effect on disk when there is one: the settings, run, profile and run-log files in the evidence's `saves` folder (`files-written.txt` lists them).
- Open the pictures yourself (the Read tool shows them). A passing step list says the steps ran; only the picture says what the player saw. (VGM-05)
- State the limits in the receipt: software renderer, synth music (no recorded stems in the cloud), fixed frame step, no sound heard, no feel judged.

## Cleanup

`drive.sh` removes its own scratch save folder when the game exits. After a failed or interrupted drive, run `$S/cleanup.sh`: it removes stale pid files and scratch save folders and keeps every evidence folder. It leaves running drives alone (another agent may own one); `--stop <evidence name>` stops yours by its pid file. Pass a shared save folder (`VERIFY_GAME_HOME`) to remove it too. Never kill Godot by name: the Gate, the Godot MCP or Andrew may be running one.

## Helpers

- `$S/doctor.sh`: the read-only health check.
- `$S/drive.sh <steps file> [<evidence name>] [-- <game flags>]`: one drive. Exit 0 every step passed, 1 a step failed (it takes a `FAILED` picture first), 2 a bad flag or evidence name, 3 the game quit by itself before the file ended (end with `quits <step>` when it should), 143 interrupted, 124 the wall timeout (137 if it had to be killed; `VERIFY_GAME_TIMEOUT`, default 1500 s; run a long drive in the background so the tool's own limit does not cut it). `VERIFY_GAME_HOME=<dir>` keeps one save folder across drives.
- `$S/bot-run.sh <evidence name> [-- <game flags>]`: films the repo's bot playing a whole run with scratch saves, for flows too long to script (the sitting launch to Brindle: `-- --profile=sitting`). Exit 0 the goal was reached, 1 the run ended first, 3 a stall, 2 a bad argument or no Godot, 124 the wall timeout (`VERIFY_GAME_TIMEOUT`, default 7000 s; 137 if it had to be killed), 143 interrupted. A 1 or 3 with no `self-play:` line in `game.log` is the display failing to start, not the bot. A long run: start it in the background.
- `$S/cleanup.sh [--stop <evidence name>] [<shared save folder>]`: teardown that keeps evidence.
- `scripts/drive.gd`: the driver the game loads; its header is the step reference.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VGM-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. Keep the feature map honest with `/astack:create-verification-skill maintain`.

## Host adapter

- Claude Code: `/scrapkeep-verify-game`.
- Report the actual model and `CLAUDE_EFFORT` or its absence.
