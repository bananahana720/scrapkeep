# core-loop

**Can one run through three worlds, six zones and three bosses keep you rolling the whole way?**

The game in one line (Andrew, 9 November 2026, ruling cj): A crew of loose cannons, bulls in the Foreman's china shop, take their world back from a machine that believes life can be run perfectly. The [Story map](design-v3/STORY-MAP.md) says what everything means under it.

This is a throwaway Godot 4.7.2 greybox for the core-loop prototype ("Scrapkeep: First Run"), built under Andrew's design principles from playtest entry 6 (`docs/playtests/PLAYTEST-LOG.md`, archived in git history). Movement is the mobility kit v2 core (rigid physics only). Combat, the build, audio and events are the wave-2 modules. Nothing here is production code. Models, textures, fonts and the recorded music stems load from `assets/`; the rest of the world is built in script.

Play it with `scrapkeep core-loop`, from any directory: the name is this sketch's directory, so it opens the main checkout's copy, or the current worktree's copy when typed inside one; a worktree's own name (`scrapkeep <worktree>`) opens its `core-loop` too, and `scrapkeep <worktree>/<sketch>` opens exactly one. A launch with no table plays the six parks; add `--table=slice` after the name for the slice table, or `--table=default` for the old six maps. Headless tests and bot runs keep the old maps unless they name a table. After a sitting, `node scripts/run-summary.mjs --last 5` prints one line per run (table, outcome, stage, posture fight, packs and synergies) from the game's `runs.ndjson`. In play the HUD shows a key only while its action is available, beside the ball or the target; hold **Tab** for the controls and codex pages. The tester notes below are no longer drawn there. [DEMO-SPEC.md](DEMO-SPEC.md) is the progression spec Andrew accepted on 2026-09-26 (heft, plating, the Warden, cores). [CONTRACTS.md](CONTRACTS.md) is the module seam, and [DESIGN-NOTES.md](DESIGN-NOTES.md) logs every design call with the principle it serves. Hero models under `assets/models/` come from the Blender recipes in `tools/blender/`, including `tools/blender/forge/` (recipes promoted from the historical asset forge `tools/asset-forge/README.md`, archived in git history).

To play it from the app menu instead, `npm run sketch:export` then `npm run sketch:appimage` packs the export as `Scrapkeep-<sha>-x86_64.AppImage` and installs it with its icon and menu entry under `~/.local/share`; `npm run sketch:appimage -- --uninstall` takes them out again. The AppImage carries the same install script, so a copy on its own installs with `./Scrapkeep-<sha>-x86_64.AppImage --install` and removes itself with `--uninstall`. Saves and settings under `~/.local/share/godot/app_userdata/core-loop` survive an uninstall. The game opens on the main menu: Play (pilot select), Camp, Settings, Help, Achievements and Quit, and prints `SCRAPKEEP_MENU_READY ms=<ticks> profile=<default|sitting> pilots=<open>/<all> stages=<in the run>` once when the menu first shows. A fresh profile opens Sable only, and the rest unlock in play (P-R21). The menu entry's second action, "Scrapkeep sitting" (right-click it in the launcher), launches with `-- --profile=sitting`: all six pilots open and the real save is never written.

## What this build is

The alpha is three worlds, each with two zones and a boss:

| World | Zones                                     | Boss            |
| ----- | ----------------------------------------- | --------------- |
| 1     | Spillway: the top shelf; The Cable Reach  | Admiral Brindle |
| 2     | Dig: the upper bench; Dig: the deep works | The Waking      |
| 3     | Highdraft; Highdraft: the crown           | The Mind        |

Six pilots, one open from the first launch (Sable); the rest unlock in play (`src/core/class_def.gd:36,87,95`):

- **Sable**, the pylon engineer, is available from the first launch (`by: "start"`).
- **Rivet**, the runner-gunner, unlocks when you open Rivet's rescue cage (`rescue:rivet`).
- **Kest**, the demolitions caster, unlocks when you rescue the buried digger in the Dig.
- **Tarn**, the claw bruiser, unlocks when you rout Admiral Brindle: claw sweep, claw pull, clamp and rend slam.
- **Tally**, the ledger caster, unlocks when you return one ledger leaf per world to Moss. Beating a world's boss finds that world's leaf. In play, 1, 2 and 3 pick the Gather, Link and Balance Due cards, and the left mouse button runs the picked one.
- **The remembered cannon** unlocks when you quiet the Mind: cannon lane, recoil split, cannon plate and rush ring, the Mind's own lane, split-lane, rush and plate families turned on the machines.

A locked pilot's card names what unlocks it, and a pilot you earn is selectable from the next run.

## The loop

1. **Title.** Continue appears first when a saved run is valid. Start (Space; the button reads New run when a saved run exists) begins a run, and the menu also offers Help (H), Achievements (A) and Settings (S); with the recorded music on, B cycles the breath.
2. **Pilot.** Press 1 to 6, or click a card: Sable, Rivet, Kest, Tarn, Tally or the remembered cannon. A locked pilot's card names what unlocks it. Every pilot has its own weapon, movement, special and smash on the same keys.
3. **Upgrade pick.** The run opens with an upgrade pick; Esc is "Later" and keeps the pick waiting.
4. **Stage.** You drop in already rolling, with the beacon in sight. The objective at the top says what to do next, and names the nearest activity with the metres to it.
5. **Warden.** One Warden clamps each beacon. Breaking it is the stage's one must, and the gates open wherever you are when it breaks.
6. **Reward gates and Moss's bay.** Roll through one of two arches to take its part. A hover barge, Moss's workshop bay, docks behind the gate row when it finds room: an opt-in pit stop with a shop and a practice yard.
7. **Launch.** Taking a gate launches you into the next stage at the speed you were going.
8. **Boss.** The last stage of a world launches you into that world's boss arena. Beat the boss to rout it. A victory screen naming what was won (SPILLWAY RECLAIMED, for one) follows, and the run continues into the next world's first stage; the last world's boss ends the run.
9. **Summary.** The summary reads RUN COMPLETE or RUN OVER, with time, stages, scrap, parts, kills, events won and whether the earned save was used. N runs again as the same pilot. Anything you were holding when the summary opened (Space, the fire button, a pad button) is ignored until you let go; the next fresh press works at once, with no wait.

If you are scrapped, a death ends the run as RUN OVER: there is no free stage retry. Press N for a new run as the same pilot, or Space to choose a pilot. An earned save (an item, once a run, if you carry it) catches one lethal hit instead; once spent it stays spent for the run. M opens the companion panel from the summary when the run holds pieces.

## Controls

| Keys       | Does                                                                                                                                                                                                                                                                                          |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| W A S D    | drive, relative to where the camera looks                                                                                                                                                                                                                                                     |
| mouse      | look                                                                                                                                                                                                                                                                                          |
| Space      | jump and double jump. Sable: vault kick at a steep face in the air; mounted, hold and release to slingshot. Kest: hold falling to glide; hold in your own blast to rocket jump                                                                                                                |
| 1, 2, 3    | select the active ability slot (`cl_bay_1..3` on the 1-2-3 bar; see `design-v3/SKILL-BAR.md`)                                                                                                                                                                                                 |
| LMB        | fire the pilot's weapon (`design-v3/PILOT-CADENCE.md`) or cast the selected ability slot                                                                                                                                                                                                       |
| RMB        | the harpoon: press bites the aim point, hold keeps the line, release flings. During a charge it cancels                                                                                                                                                                                       |
| Ctrl       | haul the line in: a smash on a body, a winch on the world. With no line: the brake on the ground, the slam in the air                                                                                                                                                                         |
| Shift      | your go verb: Sable's boost, Rivet's sprint (hold), Kest's smoke blink                                                                                                                                                                                                                        |
| Q          | ultimate set piece (`cl_ultimate`, when charged; recall while active)                                                                                                                                                                                                                          |
| F          | active item trigger (`cl_active`; `cl_special` is retired)                                                                                                                                                                                                                                     |
| C          | use carried consumable (`cl_consumable`)                                                                                                                                                                                                                                                       |
| . , / ;    | radio next / previous / skip / pin                                                                                                                                                                                                                                                             |
| E          | interact with the device you face within 18 m (the lock holds after you pass it): hold it for anything with a cost or a bet, press it for a cache; inside an amber lane it arms the ride. Sable, with nothing in reach: plant a pylon on a steep face or a close wall hook; again to drop off |
| Tab (hold) | field notes and the codex; the game pauses while held; Q / E switch pages                                                                                                                                                                                                                     |
| - / =      | music volume down / up (also in the pause menu)                                                                                                                                                                                                                                               |
| [ / ]      | effects volume down / up (also in the pause menu)                                                                                                                                                                                                                                             |
| M          | mute or unmute                                                                                                                                                                                                                                                                                |
| P / Esc    | pause menu: resume, restart the run, field notes, music and effects volume, quit; restart and quit ask first (press again)                                                                                                                                                                    |
| R (hold)   | restart the run: a new run as the same pilot, from world 1 (not during the victory lap); release before holding again                                                                                                                                                                                                        |
| F1         | launched with --dev only: tuning panel (frees the mouse)                                                                                                                                                                                                                                      |
| F3         | launched with --dev only: frame smoothing on/off for this session (Settings, Display keeps it)                                                                                                                                                                                                                       |
| F4         | launched with --dev only: save every tuning value to user://tuning-<time>.json                                                                                                                                                                                                                |
| Esc        | outside play: quit                                                                                                                                                                                                                                                                            |

In play the game pauses itself: the pause menu opens when the window loses focus or the pad in use disconnects, and it stays open until you resume.

On the screens outside play, every choice is also a button: click it, or press the key on its cap.

| Keys                             | Does                                                                                                                   |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Space                            | title: start; summary: choose a pilot (pad B on the summary)                                                           |
| H                                | title: the how-to-play page; H or Esc closes it                                                                        |
| 1, 2, ...                        | pilot select: one number per pilot card, left to right                                                                 |
| N                                | summary: new run as the same pilot (pad A on the summary)                                                              |
| 1 or 2, A/D then Enter, or click | upgrade pick (run start, Moss's bay, or stage clear if you skipped the bay); Esc is "Later" and keeps the pick waiting |
| roll up slowly to Moss's counter | opens the shop: click a plate or move focus with the keys; T talks to Moss                                             |

## Field notes

These mirror `src/ui/field_notes.gd`. The Tab overlay no longer prints them.

### Testing in this build

- One run: title, pilot, then the stages of each world. A Warden clamps each stage's beacon. Grow, crack its guard, smash its open core, then roll through a reward gate, and launch into the next stage. A boss victory launches the next world; the summary follows the last world's boss.
- Growth is heft. Scrap you roll up becomes mass, parts add more, and heft multiplies your punch. The plate at the top of the screen is the Warden's guard: hits fill its bar, a full bar staggers the Warden and opens its core, and a hit on the open core shatters one of its chunks. A light ball fills the bar slowly, so grow and come back.
- Outweigh fodder and you roll straight through it with no speed lost. Events and vaults drop bonus cores, the diamonds beside the objective, which raise the gate tiers.
- Sable's pylon banks the speed you plant with. Space slingshots you off along the face with that speed plus a boost, and E drops off where you are. The camera goes to the shoulder while you are mounted.
- Death takes one key. A death ends the run; N starts a new run as the same pilot, and a fresh press of N rolls it at once (a key held through the death waits for its release). Hold R in play to restart the run.

### Questions for you

- Was the Warden a goal or a chore? Did growth feel like enough growth?
- Does the loop read without instructions: where to go, what the beacon wants, what a gate gives?
- Does the launch into the next stage feel like momentum carried, or like a load screen?
- Is the shoulder view while mounted enough to see what you are shooting?
- Is a new run fast enough that dying costs you nothing but the run?

### What to try first

1. Pick a pilot with its number key or a click. You drop in already rolling. The Warden is at the beacon you can see from the drop, and a chevron at the screen edge points to it when it is out of view.
2. Roll the scrap lines on the way down. Scrap is your armour and your weight, and a heavier ball hits harder.
3. Break the Warden. The line at the top of the screen says what it wants next. At the dam, ride the water sheet up the face into its core; at the flume, latch your line onto it and fire. Its gates open when it breaks; roll through one to take its part.
4. As Sable, hit a steep face at speed and press E. Fire with left mouse, then hold and release Space to slingshot off.
5. Get scrapped on purpose, then hold R. You are in a new run as the same pilot, back at world 1.

## Run the Linux build

A built package is a `scrapkeep-core-loop-<sha7>.tar.gz`, where `<sha7>` is the commit it was built from.

1. Extract the archive anywhere.
2. Keep the `music_ace/` folder next to `core-loop.x86_64`. Without it the game plays its built-in synth music instead of the recorded stems.
3. Run `./core-loop.x86_64` from any directory.
4. Saves live in `~/.local/share/godot/app_userdata/core-loop/`. For a fresh first launch, rename that folder first and rename it back afterwards to keep your progress.
5. On the title, press H for how to play and the controls.

## Build the package

`npm run sketch:export` builds a Linux x86_64 release of this sketch and boots it headless for 300 frames. It writes `artifacts/local/core-loop-export/<stamp>/` with `core-loop.x86_64`, `music_ace/`, `BUILD.txt` and `HOW-TO-RUN.txt`, and the `scrapkeep-core-loop-<sha7>.tar.gz` beside that folder. The game reads `BUILD.txt` from beside its executable (`src/core/build_stamp.gd`): every launch prints one `SCRAPKEEP_BUILD commit=<sha> dirty=<bool> built=<stamp> source=<export|checkout|none>` line, and the boot card's corner and the foot of the settings page read "Build <sha7> · <day>". A run from the project reads the checkout's HEAD and says "Dev build <sha7>".

- `npm run sketch:export -- --stems-from=<music_ace folder>` names where the recorded stems are copied from. The default is the main checkout's `sketches/core-loop/assets/music_ace`. The stems are gitignored and cannot be regenerated, so the export fails if the folder lacks any stem the manifest names; point the flag at a folder that holds `spillway/*.ogg`.
- `npm run sketch:export -- --win-proof` (flags go after `--`) also exports the "Linux x64 proof" pack into a sibling `<stamp>-win-proof/` folder and plays one skipper-bot run on it from a fresh `user://`. It fails unless the bot wins the run, so a passing line proves the exported pack finishes a run, not that the release template's runtime does.

## Layout

| Path                | Owner    | Holds                                                                                                                                                        |
| ------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `src/game.gd`       | spine    | the root: builds the spine, sets up the modules in order, input, pause, hit-stop                                                                             |
| `src/boss/`         | spine    | the boss fights: Admiral Brindle, the Waking and the Mind                                                                                                    |
| `src/core/`         | spine    | the bus, `event_kinds`, run state and heft, classes, stage dials, the flow and the Warden gate, the beacon, the context, the codex, the run log, the palette |
| `src/movement/`     | spine    | the v2 rigid ball, augments, tuning and the chase camera                                                                                                     |
| `src/ui/`           | spine    | HUD, screens, field notes, tuning panel, reticle                                                                                                             |
| `src/combat/`       | writer A | weapons, enemies, damage, the spawner                                                                                                                        |
| `src/build/`        | writer B | scrap, parts, reward gates                                                                                                                                   |
| `src/presentation/` | writer C | juice, SFX, the music engine and the ACE stem sequencer                                                                                                      |
| `src/world/`        | writer D | terrain, the flood, the director, the launch, Moss's bay                                                                                                     |

## Checks

`npm run sketch:smoke` runs the headless import, a 300-frame boot and every test in `tests/`. `npm run sketch:gate` runs `sketch:lint`, then the smoke run with a receipt. The spine tests are:

- `spine_run_test.gd` drives a scripted full run through every flow state and measures speed through each gate and each launch.
- `spine_restart_test.gd` checks that a retry restores the stage-start snapshot, from play and from the storeless death screen (tests and bots only; a real run ends on the summary).
- `spine_event_kinds_test.gd` checks that every bus signal has a well-formed `event_kinds` row.
- `spine_movement_test.gd` covers slam, winch, aim, mount, the momentum bank and the slingshot.
- `spine_live_test.gd` runs a short fight through the module seams.
- `spine_heft_test.gd` covers mass, heft, classes, cores, restore, and handling that does not change with heft.
- `spine_warden_gate_test.gd` checks the Warden seal, charge from damage, the break that opens the gates anywhere, and `warden_engaged`.
- `spine_objective_test.gd` checks the objective line, the heft label and the core pips.
- `spine_crush_test.gd` checks the crush pass-through against the ram that bounces.
- `spine_codex_test.gd` covers the codex registry, the burst, the logs, saving, and the Tab pages.
- `spine_run_log_test.gd` checks that a scripted run writes one record with a record per stage, and that a death adds one.

Automated checks say nothing about feel. Andrew's play is the review.
