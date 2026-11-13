# Cold launch

The packed game starts with no editor and no project folder: the boot card with the name, a Play button and the build stamp ("Build <sha7> · <date>"), then the title opening and the title menu, with Help and Achievements a key away.

## Sub-features

- `CL-1` The game starts from its own folder and prints `SCRAPKEEP_BUILD commit=<sha> ... source=export`.
- `CL-2` The boot card shows the build stamp for this commit.
- `CL-3` The title opening plays and a key skips it.
- `CL-4` The title menu shows Play, Camp, Settings, Help, Achievements, Quit, and no Continue on a fresh save.
- `CL-5` Help and Achievements open and close.

## How to get to it (user POV)

- Unpack the package and run `./core-loop.x86_64`, or pick "Scrapkeep" in the app menu after an install.

## Driving it with build.sh

Preconditions: baseline.

- **Whole feature:** `$B drive .agents/skills/scrapkeep-verify-game/features/steps/launch-and-menus.steps cold-launch`. Expect exit 0, 25 passed rows and a last line "drive: awaiting the game's own quit".
- **CL-1:** the evidence's game log holds `SCRAPKEEP_BUILD commit=<this checkout's commit>` with `source=export`, and `SCRAPKEEP_MENU_READY ... profile=default pilots=1/6`.
- **CL-2:** the `boot-card` picture shows "Build <sha7>" bottom right (a game run from source says "Dev build").
- **CL-3 to CL-5:** as in the game skill's [Launch and menus](../../scrapkeep-verify-game/features/launch-and-menus.md): the pictures `title-intro`, `title-menu`, `help`, `achievements`.

## Gotchas

- A cloud drive uses the OpenGL renderer; the PC build runs Vulkan. A cold launch here does not cover the Vulkan path or first-launch shader building.
- The drive's window is 1280x720 and never goes fullscreen; the player's first launch does.
- Without the `music_ace` folder beside the game the log warns that the synth engine plays. That is expected for a cloud test build and a fault in a PC package.
