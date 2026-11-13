# Game verification map

This directory is the maintained source for verifying what a player meets in the Godot game at `sketches/core-loop`. Read this index before driving the game, then use the matching feature file as the recipe. Every step file under `steps/` passed on stage `stage/alpha-w40` at 6d4320b8 on 13 November 2026, in a cloud box.

## Baseline preconditions

- Run from the repository root with `S=.agents/skills/scrapkeep-verify-game/scripts`.
- `$S/doctor.sh` exits 0.
- Each drive starts as a new player with an empty save folder, unless the recipe sets `VERIFY_GAME_HOME`. A new player has only Sable open and meets the prologue ("FIRST SHIFT") at the first pilot select.
- Never drive a game this run did not start, and never point a drive at Andrew's save folder.

## Driving conventions

- Every recipe starts with `until clickable "Settings" 120` and `until read get_node_or_null("/root/Boot") == null 30`: the title menu is up and the boot card has gone.
- Keys are the stable handles; the control tables in `sketches/core-loop/README.md` name them. Buttons are found by the words on them. Points (`click_at`) are the last resort and use the game's own 1600x900 view.
- Wait with `until`, not `wait`. A bare `wait` is only for letting a picture settle.
- The game pauses itself on held cards (the kit pick, the start pick, the pause menu). `until read not get_tree().paused 30` is the wait for play to resume.
- Take a `shot` before the press that matters and after it.

## Proof and skip reporting

- A proof is the pictures, the `steps.ndjson` rows and, for anything saved, the file under `saves/`.
- Name the feature file and the sub-feature ids covered with every receipt.
- A path that could not be reached is reported with the step that failed and its `FAILED` picture, never as verified through another path.
- Limits to state every time: software renderer, synth music, fixed frame step, no sound heard, no feel judged.

## Feature entry contract

Each feature file has an H1, one paragraph on what the player sees, then four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with drive.sh`, `Gotchas`.

## Features

- [Launch and menus](./launch-and-menus.md): boot card, title opening, title menu, Help, Achievements.
- [Start a run](./start-a-run.md): prologue, pilot select, kit pick, start pick, rolling in stage 1.
- [Settings](./settings.md): the four settings pages and a choice kept on disk.
- [Pause and notes](./pause-and-notes.md): the pause menu and the held Tab pages.
- [Save and continue](./save-and-continue.md): quit from the pause menu, Continue on the next launch.
- [A whole run](./whole-run.md): Warden, gates, the next stage, Brindle, death and the summary, played by the repo's own bot and filmed.

Not mapped yet: Camp (K on the title), Moss's bay and shop, the companion panel, pad input, the reward ceremony. Add a file when a change touches one.
