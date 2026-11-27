# Launch and menus

The game opens on a dark boot card with the name and a Play button while the game loads behind it. The card fades, a new profile's title opening plays ("Any key skips"), and the title menu stands: Play, Camp, Settings, Help, Achievements, Quit, each with its key on a cap.

## Sub-features

- `LM-1` Boot card shows within seconds and carries the build stamp ("Dev build <sha7>").
- `LM-2` Title opening plays once for a new profile and any key skips it.
- `LM-3` Title menu shows six choices; with a saved run it also shows Continue and Play reads "New run" (and Companion `M` when pieces are owned). Hotkeys `O` (Work orders) and `L` (Logbook) also open directly from the title; see [Work orders and logbook](./work-orders-and-logbook.md).
- `LM-4` Help page (H) opens and Esc closes it.
- `LM-5` Achievements page (A) opens with the Shift Board, World Acts strip (once unlocked), achievement rows, and footer links to Work orders (`O`) and Logbook (`L`); Esc closes it.
- `LM-6` Esc on the title moves the focus to Quit; pressing Quit ends the game.

## How to get to it (user POV)

- Launch the game: `scrapkeep core-loop` on the PC, the "Scrapkeep" menu entry for an installed build.
- On the title: click a choice, or press its key (`Space` Play, `C` Continue when saved, `K` Camp, `M` Companion when pieces exist, `S` Settings, `H` Help, `A` Achievements, `O` Work orders, `L` Logbook, `B` ACE Breath, `Esc` focus Quit).

## Driving it with drive.sh

Preconditions: baseline; no game flags (the opening must play).

- **Whole feature:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/launch-and-menus.steps`. Expect exit 0, 25 passed rows and a last line "drive: awaiting the game's own quit" (the game ended itself on Quit).
- **LM-1:** `until text "Play" 120` then `shot boot-card`. The picture shows the card and "Dev build" bottom right; `game.log` has `SCRAPKEEP_BUILD commit=<the checkout's commit>`.
- **LM-2:** `until text "Any key skips" 60`, `shot title-intro`, `key SPACE`. The picture shows the opening's caption; after the key the menu is clickable.
- **LM-3:** `until clickable "Settings" 30`, `expect state title`, `shot title-menu`, `ui`. The `ui` file lists Play, Camp, Settings, Help, Achievements, Quit.
- **LM-4, LM-5:** `click "Help"` (or `key H`), `shot help`, `key ESCAPE`, `until clickable "Achievements" 10`; the same for Achievements.
- **LM-6:** `key ESCAPE`, `shot quit-focused`, then `quits click "Quit"` as the last step. `quits` passes only when the game ends itself within 10 s of that click; a game that quits anywhere else in a step file makes `drive.sh` exit 3.

## Gotchas

- The boot card also has a button that says "Play". `until text "Play"` is true as soon as the card shows; wait for `until clickable "Settings"` before pressing anything meant for the title.
- Words under the fading boot card count as drawn for `until text`. Use `until clickable`, which asks the engine what the pointer is over.
- `--no-intro` removes LM-2. A second launch on a kept save folder does not replay the opening either.
- Pictures are 1280x720; the boxes in a `ui` file are in the game's 1600x900 view.
