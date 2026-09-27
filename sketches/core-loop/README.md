# core-loop

**Does one run of Scrapkeep, from title through three stages to a summary, keep you rolling the whole way?**

This is a throwaway Godot 4.7.2 greybox for the core-loop prototype ("Scrapkeep: First Run"), built under Andrew's design principles from [playtest entry 6](../../docs/playtests/PLAYTEST-LOG.md#6-mobility-kit-v2-first-human-play-and-design-principles). The whole run is here: a title, two classes, three stages, a beacon to charge in each one, reward gates to roll through, a launch into the next stage, and a summary. Death shows a one-key retry.

Movement is the mobility kit v2 core (rigid physics only). Combat, the build, audio and events are the wave-2 modules. Nothing here is production code, and there are no assets: everything is built in script from primitives.

Play it with `scrapkeep core-loop`. In play the HUD shows a key only while its action is available, beside the ball or the target; hold **Tab** for the field notes below, which keep the full list. [DEMO-SPEC.md](DEMO-SPEC.md) is the progression spec Andrew accepted on 2026-09-26 (heft, plating, the Warden, cores). [CONTRACTS.md](CONTRACTS.md) is the module seam, and [DESIGN-NOTES.md](DESIGN-NOTES.md) logs every design call with the principle it serves.

## The loop

1. **Title.** Press Space.
2. **Class.** Press 1 for the Pylon engineer or 2 for the Runner-gunner. Both share the whole mobility kit. The names are candidates.
3. **Stage.** You drop in already rolling, with the beacon in sight. The objective line at the top always says what to do next: your punch against the Warden's plating, and the stage's hint.
4. **Warden.** One Warden clamps each beacon. Breaking it is the stage's one must, and the gates open wherever you are when it breaks. Scrap you roll up adds heft, and heft multiplies your punch. Events and vaults add bonus cores, the pips beside the objective, which raise the gate tiers.
5. **Reward gates.** Two arches appear ahead of you. Roll through one to take its part.
6. **Launch.** Taking a gate launches you into the next stage at the speed you were going.
7. **Summary.** After stage 3 you see stages, scrap, parts, kills, events won and time. N runs again as the same class.

If you are scrapped, press R to retry the stage from its start, N for a new run, or C to choose a class.

## Controls

| Keys | Does |
| --- | --- |
| W A S D | drive, relative to where the camera looks |
| mouse | look |
| Space | jump, double jump, hold falling to glide; slingshots off a pylon |
| Shift | boost; airborne it is the air dash |
| Ctrl | brake; airborne it is the slam |
| left mouse | fire the class weapon (hold); both classes |
| F | runner: overdrive blast; engineer: pylon discharge (planting fires it free) |
| right mouse | fire the grapple at the reticle's target; release to let go |
| Q (hold) | winch: haul toward the hook |
| E | plant a pylon on a steep face or a close wall hook; press again to drop off |
| mouse wheel | down pays rope out, up notches it in |
| Tab (hold) | field notes and the codex; the game pauses while held; Q and E switch pages |
| - / = | music volume down / up |
| [ / ] | effects volume down / up |
| M | mute or unmute |
| F6 | boss tempo: 129, or 172 while held |
| P | pause or resume |
| R (hold) | retry the stage from its start |
| F1 | tuning panel (frees the mouse) |
| F3 | physics interpolation on or off (off by default) |
| F4 | save every tuning value to `user://tuning-<time>.json` |
| Esc | free the mouse; press again to quit |

On the screens outside play, every choice is also a button: click it, or press the key on its cap.

| Keys | Does |
| --- | --- |
| Space | title: start; summary: choose a class |
| 1, 2, ... | class select: one number per class card, left to right |
| R | death screen: retry the stage, or the fight in the arena |
| T | arena death screen: replay stage 3 from its start |
| N | death or summary: new run as the same class |
| C | death screen: choose a class |

## Field notes

These mirror `src/ui/field_notes.gd`, which is what the Tab overlay prints.

### Testing in this build

- One run: title, class, then three stages. A Warden clamps each stage's beacon. Break it, roll through a reward gate, and launch into the next stage. A summary follows stage 3.
- Growth is heft. Scrap you roll up becomes mass, parts add more, and heft multiplies your punch. Under the objective, the top bar is your punch and the hatched bar the Warden's plating; get the punch past the white notch.
- Outweigh fodder and you roll straight through it with no speed lost. Events and vaults drop bonus cores, the diamonds beside the objective, which raise the gate tiers.
- The pylon banks the speed you plant with. Space slingshots you off along the face with that speed plus a boost, and E drops off where you are. The camera goes to the shoulder while you are mounted.
- Death takes one key. R retries the stage from its start with the scrap, health and parts you entered with, and N starts a new run as the same class. Hold R in play to retry the stage.

### Questions for you

- Was the Warden a goal or a chore? Did growth feel like enough growth?
- Does the loop read without instructions: where to go, what the beacon wants, what a gate gives?
- Does the launch into the next stage feel like momentum carried, or like a load screen?
- Is the shoulder view while mounted enough to see what you are shooting?
- Is retry fast enough that dying costs you nothing but the stage?

### What to try first

1. Pick a class with its number key or a click. You drop in already rolling. The Warden is at the beacon you can see from the drop, and a chevron at the screen edge points to it when it is out of view.
2. Roll the scrap lines on the way down. Watch the heft dial's needle climb, and your punch bar grow under the objective.
3. Break the Warden; close to it, the objective says how. The gates open wherever you are. Roll through one to take its part.
4. Hit a steep face at speed and press E. Fire with left mouse, then press Space to slingshot off.
5. Get scrapped on purpose, then press R. You are back at the stage start in under a second.

## Layout

| Path | Owner | Holds |
| --- | --- | --- |
| `src/game.gd` | spine | the root: builds the spine, sets up the modules in order, input, pause, hit-stop |
| `src/core/` | spine | the bus, `event_kinds`, run state and heft, classes, stage dials, the flow and the Warden gate, the beacon, the context, the codex, the run log, the palette |
| `src/movement/` | spine | the v2 rigid ball, augments, tuning and the chase camera |
| `src/ui/` | spine | HUD, screens, field notes, tuning panel, reticle |
| `src/combat/` | writer A | weapons, enemies, damage, the spawner |
| `src/build/` | writer B | scrap, parts, reward gates |
| `src/presentation/` | writer C | juice, SFX, music (a no-op stub for now) |
| `src/world/` | writer D | terrain, the flood, the director, the launch |

## Checks

`npm run sketch:smoke` runs the headless import, a 300-frame boot and every test in `tests/`. The spine tests are:

- `spine_run_test.gd` drives a scripted full run through every flow state and measures speed through each gate and each launch.
- `spine_restart_test.gd` checks that a retry restores the stage-start snapshot, from play and from the death screen.
- `spine_event_kinds_test.gd` checks that every bus signal has a well-formed `event_kinds` row.
- `spine_movement_test.gd` covers slam, winch, aim, mount, the momentum bank and the slingshot.
- `spine_live_test.gd` runs a short fight through the module seams.
- `spine_heft_test.gd` covers mass, heft, classes, cores, restore, and handling that does not change with heft.
- `spine_warden_gate_test.gd` checks the Warden seal, charge from damage, the break that opens the gates anywhere, and `warden_engaged`.
- `spine_objective_test.gd` checks the objective line, the heft label and the core pips.
- `spine_crush_test.gd` checks the crush pass-through against the ram that bounces.
- `spine_codex_test.gd` covers the codex registry, the burst, the logs, saving, and the Tab pages.
- `spine_run_log_test.gd` checks that a run writes one record with three stages, and that a death adds one.

Automated checks say nothing about feel. Andrew's play is the review.
