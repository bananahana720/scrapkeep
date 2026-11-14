# Packed build verification map

This directory is the maintained source for verifying the packed Linux game, the thing a player installs. Read this index before driving a build, then use the matching feature file. The drives named here passed on a cloud test build of stage `stage/alpha-w40` at 6d4320b8 on 13 November 2026.

## Baseline preconditions

- Run from the repository root with `B=.agents/skills/scrapkeep-verify-build/scripts/build.sh`.
- A build exists (`$B export` in the cloud, or `VERIFY_BUILD_EXE` naming a PC package) and `$B doctor` exits 0.
- Each drive starts as a new player with an empty save folder under its evidence folder.
- Never run a packed game against Andrew's save folder, and never install anything on the PC without his go-ahead.

## Driving conventions

- The step files and the step list are the game skill's (`.agents/skills/scrapkeep-verify-game/`); the same waits apply: `until clickable "Settings" 120`, then `until read get_node_or_null("/root/Boot") == null 30`.
- A launch flag is proven with a control run on the default launch.

## Proof and skip reporting

- Name the build with every receipt: path, commit, cloud test build or PC package, stems or synth.
- A path that needs the PC (the tarball, the installer, the recorded band, Vulkan) is reported as not reached, with the prerequisite, never as verified by a cloud drive.

## Feature entry contract

Each feature file has an H1, one paragraph on what the player sees, then four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with build.sh`, `Gotchas`.

## Features

- [Cold launch](./cold-launch.md): the packed game starts on its own, names its build, and its menus work.
- [First run on the packed build](./first-run.md): prologue to rolling in stage 1, with saves written.
- [The sitting launch](./sitting-launch.md): `--profile=sitting` opens all six pilots.
- [Package and installer](./package-and-installer.md): the tarball, its notes, the recorded band, the AppImage and the menu entry (PC only).
