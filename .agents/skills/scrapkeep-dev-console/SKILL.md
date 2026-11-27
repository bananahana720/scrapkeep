---
name: scrapkeep-dev-console
description: "Run Scrapkeep's developer console and agent CLI lever (`scripts/dev-console.mjs`, `npm run dev:console`, and `sketches/core-loop/src/dev/`) for headless state probes, combat/boss checks, warm multi-turn sessions, and silent offscreen visual sheets. Use when inspecting live game state, spawning encounters, comparing look/camera/quality renders, or running fast deterministic dev scenarios; real-input player-path proofs stay in scrapkeep-verify-game, packed Linux builds stay in scrapkeep-verify-build, and release/wave gate selection stays in scrapkeep-verify."
---

# Run Scrapkeep Dev Console & Agent CLI Lever

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns agent-driven inspection, scenario scripting, warm File-Mailbox sessions, and silent offscreen captures through `scripts/dev-console.mjs` (`npm run dev:console`) and the in-game console under `sketches/core-loop/src/dev/`. Real player-input verification stays in `scrapkeep-verify-game`, packed build checks stay in `scrapkeep-verify-build`, multimodal UI/film review stays in `scrapkeep-visual-review`, and gate selection stays in `scrapkeep-verify`.

## Procedure

1. Choose the lightest mode that answers the question: use headless default (`npm run dev:console -- run ...` or `recipe smoke|combat-probe|boss-retry-probe`) for logic, state, combat, and boss checks, and `--drawn` only when pixels or render counters are needed. (DEV-03)
2. For 1-step checks or reproducible post-mortem receipts, run `npm run dev:console -- run "<commands>" --json` (or `@file.dev`). For 3+ sequential turns against the same live state, start a warm File-Mailbox session with `serve`, send turns with `send`, inspect liveness with `status`, and tear down with `stop` when done. (DEV-01)
3. Always isolate saves under `<repo>/artifacts/local/` and keep audio silent (`--audio-driver Dummy`, plus `SDL_AUDIODRIVER=dummy` on Linux). Never pass `--windowed` unless explicitly requested; on macOS Metal offscreen (`--drawn`), keep `--embedded --rendering-driver metal --debug --skip-breakpoints --ignore-error-breaks`, and on Linux require `gamescope --backend headless` or `xvfb-run`. (DEV-02, DEV-03)
4. After `run 1` in non-`test_mode` launches, wait for the stage load and dismiss Moss's start card with `pick 1` before calling `tick <n>` or asserting active combat; use `freeze` + `tick <n>` rather than zeroing `Engine.time_scale`. (DEV-04, DEV-05)
5. Treat `dev-console` outputs as developer-console evidence, not player-input proof or human-feel sign-off: compare visual changes with `npm run dev:console -- diff <a.png> <b.png> --json` and inspect generated PNGs directly via `read_file`. (design choice)

## References

- [references/commands.md](references/commands.md): console commands, `inspect` topics, `events`, `assert` checks, `overlay` layers, `sheet` modes, and `DevSession` GDScript helper.
- [references/recipes.md](references/recipes.md): built-in recipes, headless vs silent offscreen usage, warm mailbox lifecycle, `diff`/`bench`, and evidence limits.
- [references/lessons.md](references/lessons.md): `DEV-01` onward and changelog.

## Lessons and updates

[references/lessons.md](references/lessons.md) holds DEV-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row.

## Host adapter

- Antigravity: `/scrapkeep-dev-console`. Run `npm run dev:console` commands in the foreground and open captured PNGs with `read_file`.
- Claude Code: `/scrapkeep-dev-console`. Run `npm run dev:console` commands in the foreground and inspect PNGs with `Read`.
- Report the actual model and runtime effort/tier metadata or their absence.
