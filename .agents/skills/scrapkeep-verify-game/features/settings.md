# Settings

Settings has four pages, Display, Controls, Look and Feel. Each row is a toggle or a chooser, a change applies at once, and it is kept for the next launch.

## Sub-features

- `ST-1` Settings opens from the title (S or a click) and from the pause menu.
- `ST-2` Display lists Fullscreen, Quality, Less motion, Fewer flashes, Frame smoothing, Wide picture.
- `ST-3` The page tabs Display, Controls, Look, Feel each open their page.
- `ST-4` A changed row is written to `settings.json` in the save folder.
- `ST-5` Esc or Back returns to where Settings was opened from.

## How to get to it (user POV)

- Title: S, or click Settings.
- In play: P or Esc for the pause menu, then Settings.

## Driving it with drive.sh

Preconditions: baseline; game flag `--no-intro`.

- **Whole feature:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/settings.steps settings -- --no-intro`. Expect exit 0 and 22 passed steps.
- **ST-1, ST-2:** `click "Settings"`, `until text "Less motion" 10`, `shot display-before`.
- **ST-4:** `click "Less motion"`, `shot display-after`. The toggle's knob moves between the two pictures, and `saves/self-play-verify/settings.json` holds `"comfort": {"reduced_motion": 1.0}`.
- **ST-3:** `click "Controls"`, `shot controls`, `ui`; the same for `Look` and `Feel`.
- **ST-5:** `key ESCAPE`, `until clickable "Settings" 10`.
- **From the pause menu:** start a run as in [Start a run](./start-a-run.md), `key P`, `until clickable "Settings" 10`, `click "Settings"`.

## Gotchas

- A row is one control whose words are its name ("Less motion"); the value is drawn, not written. Prove a change with the two pictures and the file, not with `expect text`.
- A drive never follows the Fullscreen setting: a game with no player's save folder keeps the window its command gave it. Prove fullscreen on the PC.
- Quality changes what is drawn; under the software renderer the pictures are not a look proof.
