# core-loop

**Does one run of Scrapkeep, from title through three stages to a summary, keep you rolling the whole way?**

This is a throwaway Godot 4.7.2 greybox for the core-loop prototype ("Scrapkeep: First Run"), built under Andrew's design principles from [playtest entry 6](../../docs/playtests/PLAYTEST-LOG.md#6-mobility-kit-v2-first-human-play-and-design-principles). The whole run is here: a title, two classes, three stages, a beacon to charge in each one, reward gates to roll through, a launch into the next stage, and a summary. Death shows a one-key retry.

This is the wave 1 spine. Movement is the mobility kit v2 core (rigid physics only), and the stage is the Spillway terrain. Combat, the build, audio and events are minimal stubs until the wave 2 modules replace them. Nothing here is production code, and there are no assets: everything is built in script from primitives.

Play it with `scrapkeep core-loop`. Hold **Tab** in game for the field notes below. [CONTRACTS.md](CONTRACTS.md) is the module seam, and [DESIGN-NOTES.md](DESIGN-NOTES.md) logs every design call with the principle it serves.

## The loop

1. **Title.** Press Space.
2. **Class.** Press 1 for the Pylon engineer or 2 for the Runner-gunner. Both share the whole mobility kit. The names are candidates.
3. **Stage.** You drop in already rolling. The objective line at the top always says what to do next and how far the beacon is.
4. **Beacon.** Roll into its ring to charge it and keep moving inside the ring. Leaving pauses the charge.
5. **Reward gates.** When the beacon is charged, two arches appear ahead of you. Roll through one to take its part.
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
| left mouse | fire the class weapon (hold) |
| F | class special |
| right mouse | fire the grapple at the reticle's target; release to let go |
| Q (hold) | winch: haul toward the hook |
| E | plant a pylon on a steep face or a close wall hook; press again to drop off |
| mouse wheel | down pays rope out, up notches it in |
| Tab (hold) | field notes; the game pauses while held |
| P | pause or resume |
| R (hold) | retry the stage from its start |
| F1 | tuning panel (frees the mouse) |
| F3 | physics interpolation on or off (off by default) |
| F4 | save every tuning value to `user://tuning-<time>.json` |
| Esc | free the mouse; press again to quit |

On the screens outside play:

| Keys | Does |
| --- | --- |
| Space | title: start; summary: choose a class |
| 1 or 2 | class select: Pylon engineer or Runner-gunner |
| R | death screen: retry the stage |
| N | death or summary: new run as the same class |
| C | death screen: choose a class |

## Field notes

These mirror `src/ui/field_notes.gd`, which is what the Tab overlay prints.

### Testing in this build

- The spine of the core loop: title, class, three stages, beacon, reward gates, launch, summary. Combat, build, audio and events are minimal stubs; the real ones land next.
- Momentum is sacred. The beacon charges while you roll inside its ring, reward gates are arches you roll through, and the launch keeps your horizontal speed into the next stage.
- The pylon banks the speed you plant with. Space slingshots you off along the face with that speed plus a boost, and E drops off where you are. The camera goes to the shoulder while you are mounted.
- Death takes one key. R retries the stage from its start with the scrap, health and parts you entered with, and N starts a new run as the same class. Hold R in play to retry the stage.

### Questions for you

- Does the loop read without instructions: where to go, what the beacon wants, what a gate gives?
- Does the launch into the next stage feel like momentum carried, or like a load screen?
- Is the shoulder view while mounted enough to see what you are shooting?
- Is retry fast enough that dying costs you nothing but the stage?

### What to try first

1. Pick either class with 1 or 2. You drop in already rolling, so take the chute down to the mid shelf.
2. Roll into the beacon's ring and keep moving inside it. Leaving pauses the charge.
3. When it charges, two arches appear ahead of you. Roll through one to take its part.
4. Hit a steep face at speed and press E. Fire with left mouse, then press Space to slingshot off.
5. Get scrapped on purpose, then press R. You are back at the stage start in under a second.

## Layout

| Path | Owner | Holds |
| --- | --- | --- |
| `src/game.gd` | spine | the root: builds the spine, sets up the modules in order, input, pause, hit-stop |
| `src/core/` | spine | the bus, `event_kinds`, run state, classes, stage dials, the flow, the beacon, the context, the palette |
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

Automated checks say nothing about feel. Andrew's play is the review.
