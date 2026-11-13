# Save and continue

A run is saved as it goes. Quit from the pause menu, launch again, and the title offers Continue first and names Play "New run". Continue puts the player back in the saved stage.

## Sub-features

- `SC-1` A new profile's title has no Continue.
- `SC-2` Quit from the pause menu (asked twice) ends the game and leaves `run.json` in the save folder.
- `SC-3` The next launch's title shows Continue (C) and "New run".
- `SC-4` Continue enters the saved run's stage.

## How to get to it (user POV)

- In play: P, Quit, Quit again. Launch again. On the title: C, or click Continue.

## Driving it with drive.sh

Preconditions: baseline; game flag `--no-intro`; one shared save folder for both drives, under the evidence root so cleanup may remove it: `H=artifacts/local/verify-game/save-home`.

- **SC-1, SC-2:** `VERIFY_GAME_HOME=$H $S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/save-quit.steps save-quit -- --no-intro`. Expect exit 0, 26 passed rows and a last line "drive: awaiting the game's own quit" (the last step is `quits click "Quit"`: the game ended itself on the second Quit click). `save-quit/files-written.txt` lists `self-play-verify/run.json`.
- **SC-3, SC-4:** `VERIFY_GAME_HOME=$H $S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/save-continue.steps save-continue -- --no-intro`. Expect exit 0 and 13 passed steps. `title-continue` shows Continue and New run; `continued` shows the saved stage; the `read run.stage` row holds the stage number.
- **Afterwards:** `$S/cleanup.sh $H`.

## Gotchas

- Without `VERIFY_GAME_HOME` each drive is a new player and Continue never shows.
- On 13 November 2026 a continued stage 1 run opened at the stage's start on the kit pick again, not where the ball had rolled to. That is what the build did, recorded here so a drive does not read it as its own fault; whether it is intended is the save system's owner's call.
- Pressing C before the boot card has gone (inside about two seconds of the menu showing) leaves the card frozen over the paused kit pick: the card's fade stops while the game is paused. Keep the `until read get_node_or_null("/root/Boot") == null 30` step. On board issue 934 since 13 November 2026. The repro is `features/steps/early-continue.steps`, run after `save-quit.steps` with the same `VERIFY_GAME_HOME` and `-- --no-intro`: it fails at its `/root/Boot` check until the fix lands, and passes after.
- The repo's own bot has the same path with planted checks: `tools/self_play.gd --self-play-keys=1 --self-play-save=<name>` then `--self-play-continue=1` (the header of `sketches/core-loop/tools/self_play.gd`).
