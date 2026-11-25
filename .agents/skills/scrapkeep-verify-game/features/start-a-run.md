# Start a run

From the title a new player reads the prologue, picks a pilot, takes the kit pick and the start pick, and drops into world 1's first stage already rolling, with the objective plate, the health and armour bars and the skill bar on screen.

## Sub-features

- `SR-1` Prologue ("FIRST SHIFT") shows on a new profile's first pilot select; E turns each line.
- `SR-2` Pilot select shows six cards; a new profile has Sable open and five locked. When an unlocked pilot owns alternate loadouts, the focused card shows an `AltLoadoutRow` (`L` / pad `Y` cycles between `Stock kit` and unlocked alt loadouts); owned paints cycle on `P` / pad `X`.
- `SR-3` Picking a pilot (its number, or a click) runs the launch swipe (`FWOOSH!`) and opens the kit pick ("Rig your kit. Pick one."), with the game paused.
- `SR-4` The start pick (`StartPickCard`, "Moss packed three. Take one.") has keys 1 to 3 and a Reroll (`V` or click). On a fresh profile (before the first win, `RunTier.top_unlocked(profile) < HARD`) in stage 1 with a yard lock ahead (`flow.start_pick_waits()`), the start pick waits until the player reaches the yard rather than pausing at the drop. Once `RunTier` unlocks (after a win), `StartPickCard` opens right after the kit pick with the `Tier` rung ladder, comparison meters, hover/focus contract lines, and any armed Foreman override code names along the bottom.
- `SR-5` Play begins unpaused in stage 1; W A S D drives the ball. The bottom-right `ConsumableSlot` HUD widget appears once the ball holds a cartridge from the 9-consumable pool (or has `Duplicator Spool` / `Overload Fuse` armed), expands to two slots with `Pocket Belt`, and fires on `C` (`cl_consumable`).

## How to get to it (user POV)

- Title, then Space or a click on Play.
- After a death or on the summary: N for the same pilot, Space for pilot select.
- Launch with `-- --profile=sitting` to have all six pilots open (the "Scrapkeep sitting" menu entry).

## Driving it with drive.sh

Preconditions: baseline; game flag `--no-intro`.

- **Whole feature:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/start-a-run.steps start-a-run -- --no-intro`. Expect exit 0 and 30 passed steps.
- **SR-1:** `key SPACE`, `until state class_select 30`, `shot prologue`, `tap_until E no_text "FIRST SHIFT" 90`. The row's `taps` counts the lines turned.
- **SR-2:** `until text "Sable" 10`, `shot pilot-select`. The picture shows one lit card and five with a lock.
- **SR-3:** `key 1`, `until text "Rig your kit" 60`, `until read launch_take == null or not launch_take.busy() 30`, `expect read get_tree().paused`, `shot kit-pick`, `key 1`.
- **SR-4:** On a fresh profile, `read flow.start_pick_waits()` returns `true` at the drop because the start pick waits for the stage 1 yard lock (`flow.gd:start_pick_at_yard`). With a profile that has a recorded win (`RunTier.top_unlocked >= HARD`), add `until text "Take one" 30`, `shot start-pick`, `key 1` right after the kit pick.
- **SR-5:** `until read not get_tree().paused 30`, `until play 30`, `shot dropped-in`, `read player.ball_position()`, `down W`, `until read player.state.velocity.length() > 3.0 15`, `wait 5`, `up W`, `shot after-rolling`, `read player.ball_position()`. The two positions differ and the second picture shows new ground. `saves/self-play-verify/run.json` and `runs.ndjson` exist.

## Gotchas

- The launch swipe (`FWOOSH!`) still covers the screen when `until text "Rig your kit"` first matches. Wait on `until read launch_take == null or not launch_take.busy() 30` before taking `shot kit-pick` or pressing `key 1`.
- The flow state reads `stage` while the kit pick and the start pick are still up. `until play` is true too early; wait on `get_tree().paused`.
- Key 1 on the kit pick takes the first card. Esc is "Later" and keeps the pick waiting.
- The camera does not turn by itself: `look <dx> <dy>` moves it, and W drives where it looks.
- Enemies arrive within seconds. A drive that idles in play for long can end on the death screen (`state dead`).
- With `--profile=sitting` the pilot cards differ (all open) and the real save is never written; say which profile a proof used.
