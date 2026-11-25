# Package and installer

On the PC, `npm run sketch:export` cuts `scrapkeep-core-loop-<sha7>.tar.gz` (the game, the recorded band in `music_ace/`, `HOW-TO-RUN.txt` and `BUILD.txt`), and `npm run sketch:appimage` wraps it as `Scrapkeep-<sha>-x86_64.AppImage` and installs it for the current user with an icon and an app menu entry that has two sitting actions: `"Scrapkeep sitting (fresh profile, unlocks earned)"` (`--profile=sitting-earned`) and `"Scrapkeep sitting (all pilots, save untouched)"` (`--profile=sitting`).

## Sub-features

- `PK-1` The tarball unpacks to a folder whose game runs from any directory, with `music_ace/` beside it.
- `PK-2` `HOW-TO-RUN.txt` names the build; `BUILD.txt` records the win proof lines.
- `PK-3` The AppImage installs with `--install` and leaves with `--uninstall`; saves survive an uninstall.
- `PK-4` The app menu shows "Scrapkeep" with the two sitting actions (`--profile=sitting-earned` and `--profile=sitting`).

## How to get to it (user POV)

- `sketches/core-loop/README.md`, "Run the Linux build" and the AppImage paragraph; `sketches/core-loop/SITTING.md`, "Cold launch the exported alpha".

## Driving it with build.sh

Preconditions: Andrew's PC (the stems are gitignored and live there, the boss smoke needs Vulkan, `appimagetool` is not in the cloud), an idle card for the export, and Andrew's go-ahead for anything written outside the repository (an install writes under `~/.local/share`).

- **PK-1, PK-2:** not reachable in the cloud. On the PC, unpack the package into a scratch folder, then `VERIFY_BUILD_EXE=<that folder>/core-loop.x86_64 $B doctor` (it must report the commit and "music_ace is beside the game") and `VERIFY_BUILD_EXE=... VERIFY_GAME_DISPLAY=1 $B drive .agents/skills/scrapkeep-verify-game/features/steps/launch-and-menus.steps pc-cold-launch -- --drive-live=1`. Read `HOW-TO-RUN.txt` and `BUILD.txt` into the receipt.
- **PK-3, PK-4:** not driven by this skill. The installer's own tests are `scripts/sketch-appimage.test.mjs` (`npm test`); the install itself is Andrew's step or needs his go-ahead, with `XDG_DATA_HOME` pointed at a scratch folder for a dry look at what it writes.

## Gotchas

- None of this file's rows was driven when the skill was written (13 November 2026): the prerequisite is the PC. Report them as not reached, never as covered by a cloud drive.
- `sketches/core-loop/export_presets.cfg` also carries a `[preset.2]` `macOS` preset (`npm run sketch:export-mac` -> `Scrapkeep.app`, gated on Andrew's go-ahead per `project-guide/handoff/DEVICES.md`); on macOS the Linux x86_64 package is `verified-unreachable`.
- A cloud test build has no tarball and no stems; `$B doctor` says so.
- On the PC the game must run with a scratch save folder (the drive does that); the PC safety check and the idle-card rule for timing still apply.
