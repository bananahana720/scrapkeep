---
name: scrapkeep-verify-build
description: "Verify the packed Linux build of Scrapkeep (the exported core-loop.x86_64 that Andrew installs) by cutting or naming a build, checking it is this checkout's, and playing it with real keys and clicks. Use when a change could differ between the source and the shipped pack (export settings, included files, the boot card, the launch profiles, saves, the installer) or before a build goes to Andrew; a feature in the game run from source is scrapkeep-verify-game, the release gate and promotion checks stay in scrapkeep-verify and the Gate, and browser pages are scrapkeep-verify-web."
---

# Verify the packed Linux build

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns one thing: a proof that the packed game starts and plays as a player would meet it, outside the editor. It reuses the driver and the step files of `scrapkeep-verify-game`; read that skill's Drive section for the step list. It does not replace the release gate, the 4080 frame budget, the boss smoke on Vulkan or Andrew's sitting, and a cloud test build is never a package to ship.

All commands run from the repository root. `B=.agents/skills/scrapkeep-verify-build/scripts/build.sh`.

## Launch

1. Cloud (Linux x86_64): `GODOT_BIN=/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64 $B export` runs `node scripts/cloud/export-headless.mjs`: import, the release gate's placeholder test, the "Linux x64" export, and two headless boots. It took 41 seconds on an imported checkout and writes the build under the gitignored cloud-export folder in `artifacts/local/`. It has no recorded stems, no Vulkan boss smoke and no tarball. (VBD-01)
2. PC (Linux x86_64): the package is cut by `npm run sketch:export` (stems, boss smoke, tarball), which is the Gate's job and needs an idle card. To drive one, set `VERIFY_BUILD_EXE=<path to its core-loop.x86_64>`; do not cut one from this skill. On macOS (such as the Mac Studio), executing the Linux x86_64 `core-loop.x86_64` binary is `verified-unreachable`; macOS has its own `macOS` preset (`npm run sketch:export-mac`, gated on Andrew's go-ahead in `project-guide/handoff/DEVICES.md`) outside this Linux-pack skill.
3. There is no server to keep alive. Each drive is one short game process on a display of its own: `$B drive <steps file> [<evidence name>] [-- <game flags>]`.
4. Ready is the line `SCRAPKEEP_MENU_READY ms=<n> profile=<default|sitting|sitting-earned> pilots=<open>/<all> stages=<in the run>` in the evidence's game log (`stages=6` on default full-alpha or with `--final-world=last`, `stages=2` on `--profile=sitting` or `--profile=sitting-earned` alone), and a first step `until clickable "Settings" 120`.

## Doctor

`$B doctor` is read-only. It boots the build headless for two frames with a scratch save folder and fails unless the `SCRAPKEEP_BUILD commit=` line names this checkout's commit: a build of another commit proves nothing about this one. It also says whether the recorded band's folder is beside the game and whether this is a cloud test build. Run it before the first drive, after every export, and after any drive that surprises you.

## Drive

`$B drive` plays a step file through the packed game with the game skill's driver, loaded through the game's own `--self-play-script` hook from a path outside the pack, so the shipped pack is driven as it ships: nothing is added to it. (VBD-02)

| Feature | Command |
| --- | --- |
| Cold launch and menus | `$B drive .agents/skills/scrapkeep-verify-game/features/steps/launch-and-menus.steps cold-launch` |
| First run | `$B drive .agents/skills/scrapkeep-verify-game/features/steps/start-a-run.steps first-run -- --no-intro` |
| The sitting launch | `$B drive .agents/skills/scrapkeep-verify-build/features/steps/sitting-profile.steps sitting -- --no-intro --profile=sitting` |

Every step file of `scrapkeep-verify-game` runs on the packed build the same way. Start from the feature file under [features/](features/README.md); a proof through one entry point is incomplete when the map lists others.

## Evidence

Each drive writes `artifacts/local/verify-build/<evidence name>/` with the same files as the game skill: pictures, the step rows, the game log, the identity file (it names the packed game's path), and a copy of the save folder. Attach the decisive pictures and rows to the pull request or copy them to the area's folder under `/mnt/project-files/`; `artifacts/local/` is scratch.

Proof standards:

- Say which build: the path, the commit from `SCRAPKEEP_BUILD`, cloud test build or PC package, stems present or not.
- Prove a launch flag by what it changes on screen and pair it with a control: the sitting launch shows six open pilots and key 2 starts a run, the default launch shows five locks and key 2 starts nothing.
- Check what a safe mode skips by looking: a drive's save folder is under the evidence folder, and Andrew's own saves are never opened. List the files written.
- Open the pictures before calling a proof. (VBD-03)
- Limits to state: software renderer, synth music in the cloud, fixed frame step, no sound heard, no frame time, no feel.

## Cleanup

`$B cleanup` removes stale pid files and scratch save folders and leaves running drives alone (`--stop <evidence name>` stops yours); evidence stays. A packed build under `artifacts/local/` is about 230 MB: it is scratch, but deleting old ones still follows the project's rule for deletes (ask Andrew first), and never one a proof still names.

## Helpers

- `$B export | latest | doctor [<packed game>] | drive <steps> [<name>] [-- <flags>] | cleanup`.
- The driver and its step reference: `.agents/skills/scrapkeep-verify-game/scripts/drive.gd`.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VBD-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row. Keep `features/` current with `/pstack:maintain-verification-skill`.

## Host adapter

- Antigravity: `/scrapkeep-verify-build`. Open captured PNGs directly via `read_file` for Gemini multimodal checks, and report active Gemini model/tier.
- Claude Code: `/scrapkeep-verify-build`.
- Report the actual model and active effort or tier (or its absence).
