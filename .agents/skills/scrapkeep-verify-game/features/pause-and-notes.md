# Pause and notes

In play, P or Esc opens the pause menu over a stopped game: Resume, New run, Field notes, Radio, Settings, Quit, beside the ball's panel. Holding Tab shows the controls and codex pages and pauses while held.

## Sub-features

- `PN-1` P opens the pause menu and the game is paused.
- `PN-2` Esc (or Resume) closes it and play goes on.
- `PN-3` Holding Tab shows the pages (the keys diagram first); letting go returns to play.
- `PN-4` New run and Quit ask first: the row reads `"Scrap this run? Press again"` or `"Quit to desktop? Press again"` and the second press does it (holding `X` for 0.6 s also quits).
- `PN-5` The game pauses itself when the window loses focus or the pad in use disconnects.

## How to get to it (user POV)

- In play: P or Esc; hold Tab for quick-view notes (`Field notes` in the pause menu pins them open); click a pause-menu row or press its hotkey (`P` Resume, `N` New run, `V` Radio, `O` Settings, `X` Quit; `--dev` with ACE music also shows `B` Breath). Note: `Tab` is hold-only (`field_notes.gd`) and does not trigger inside `pause_menu.gd`.

## Driving it with drive.sh

Preconditions: baseline; game flag `--no-intro`; a run in play (the file's first steps do that).

- **PN-1 to PN-3:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/pause-and-notes.steps pause -- --no-intro`. Expect exit 0 and 30 passed steps.
- **PN-1:** `key P`, `until read get_tree().paused 10`, `shot paused`, `ui`. The `ui` file lists Resume, New run, Field notes, Radio, Settings, Quit.
- **PN-2:** `key ESCAPE`, `until read not get_tree().paused 10`, `shot resumed`.
- **PN-3:** `down TAB`, `wait 1.5`, `shot tab-held`, `up TAB`, `wait 1`, `expect read not get_tree().paused`.
- **PN-4:** driven by `features/steps/save-quit.steps` ([Save and continue](./save-and-continue.md)): `click "Quit"`, `shot quit-asked` (the row now reads "Quit to desktop? Press again"), `quits click "Quit"`. The game quits itself with exit 0.
- **PN-5:** not reachable from a drive: the driver sends no focus change and no pad. Its test is `auto_pause_test` (`npm run sketch:smoke -- --sketch core-loop --test auto_pause_test`); say so rather than claim it.

## Gotchas

- Esc on a held card (the kit pick) is "Later", not pause. Open the pause menu only once play is unpaused.
- After the second Quit press the game is gone before the driver writes that step's row. Exit 0 without "drive: done" is the expected end.
- The pause menu's rows are found by their words; "Quit" also matches the asked row "Quit to desktop? Press again", which is what the second click needs.
