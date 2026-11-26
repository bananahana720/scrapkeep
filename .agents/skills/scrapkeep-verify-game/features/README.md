# Game verification map

This directory is the maintained source for verifying what a player meets in the Godot game at `sketches/core-loop`. Read this index before driving the game, then use the matching feature file as the recipe. Every step file under `steps/` and a live `bot-run.sh --offscreen` sitting run passed at `aa5c74047` on 26 November 2026 (macOS offscreen `--embedded` Metal).

## Baseline preconditions

- Run from the repository root with `S=.agents/skills/scrapkeep-verify-game/scripts`.
- `$S/doctor.sh` exits 0.
- Each drive starts as a new player with an empty save folder, unless the recipe sets `VERIFY_GAME_HOME`. A new player has only Sable open and meets the prologue ("FIRST SHIFT") at the first pilot select.
- Never drive a game this run did not start, and never point a drive at Andrew's save folder.

## Driving conventions

- Every recipe that presses the title menu starts with `until clickable "Settings" 120` and `until read get_node_or_null("/root/Boot") == null 30`: the title menu is up and the boot card has gone. (The launch recipe watches the boot card and the opening first, so it waits on them by name.)
- Keys are the stable handles; the control tables in `sketches/core-loop/README.md` name them. Buttons are found by the words on them. Points (`click_at`) are the last resort and use the game's own 1600x900 view.
- Wait with `until`, not `wait`. A bare `wait` is only for letting a picture settle.
- The game pauses itself on held cards (the kit pick, the start pick, the pause menu). `until read not get_tree().paused 30` is the wait for play to resume.
- Take a `shot` before the press that matters and after it.

## Proof and skip reporting

- A proof is the pictures, the `steps.ndjson` rows and, for anything saved, the file under `saves/`.
- Name the feature file and the sub-feature ids covered with every receipt.
- A path that could not be reached is reported with the step that failed and its `FAILED` picture, never as verified through another path.
- Limits to state every time: dummy audio, fixed 30 fps frame step, synth music when stems are absent, offscreen renderer (Linux software `opengl3` or macOS `--embedded` Metal), no sound heard, no feel or RTX 4080 frame time judged.

## Feature entry contract

Each feature file has an H1, one paragraph on what the player sees, then four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with drive.sh`, `Gotchas`.

## Features

- [Launch and menus](./launch-and-menus.md): boot card, title opening, title menu, Help, Achievements, and hotkeys to Work orders (O) and Logbook (L).
- [Work orders and logbook](./work-orders-and-logbook.md): Work Orders (O: Orders, Licenses, Overrides) and the 5-tab Logbook (L: Entries, Crew arcs, Chemistry, Wire trail, Foreman).
- [Start a run](./start-a-run.md): prologue, pilot select (including Alt Loadouts on L), kit pick, start pick (RunTier ladder and active overrides), rolling in stage 1, and ConsumableSlot HUD.
- [Settings](./settings.md): the four settings pages (Display, Controls with Active and Cartridge conflict names, Look, Feel) and a choice kept on disk.
- [Pause and notes](./pause-and-notes.md): the pause menu and the held Tab pages.
- [Save and continue](./save-and-continue.md): quit from the pause menu, Continue on the next launch.
- [Launch switches](./launch-switches.md): the ball look (cutaway default vs today), the Tripo models and the Stocktake yard, each proven as a pair.
- [A whole run](./whole-run.md): Wardens, gates, the next stage, worlds 1-3 (Brindle, the Waking, the Mind) or sitting world 1, death and the summary, played by the repo's own bot and filmed.

Not mapped yet: Camp (`K` on the title), Moss's bay and 4-face `ShopCounter` (`buy`, `stock` for tri-terminal/consumables/Pocket Belt, `fab` for Scrapper/Press ingots, `sell`), in-run `ConsumableSlot` cartridge use (`C`), the companion panel (`M`), pad input, the reward ceremony. Add a file when a change touches one.
