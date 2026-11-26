# Dev Console Lessons Ledger

Each lesson captures a verified transport, runtime, or workspace-isolation rule for Scrapkeep's developer console and CLI lever.

## Lessons

- **DEV-01** · status: established · since: 2026-11-26 · origin: Phase 1 transport bakeoff (cold batch vs loopback TCP vs File-Mailbox)
  Use Deterministic Batch (`--dev-file` + `--dev-out`) for reproducible single-shot checks and Warm File-Mailbox (`--dev-inbox`) for multi-turn agent exploration: File-Mailbox achieved ~7.2 ms median sync RTT (~7.5 s total for 10 turns vs 66.2 s for 10 cold boots) matching loopback TCP (~8 ms) at 3.4x smaller runtime code (~141 LOC) with zero sockets or port collisions.
  Evidence: Phase 1 bakeoff on `macOS M5 Max` (commit `6b76830b0`, batch branch `d6493d08e`, mailbox branch `869f994ba`); `scripts/dev-console.mjs`.
  Overturned by: —

- **DEV-02** · status: established · since: 2026-11-26 · origin: macOS Metal offscreen bakeoff & display-run alignment
  On macOS (`darwin`), offscreen `--drawn` captures with `--embedded --rendering-driver metal` must also pass `--debug --skip-breakpoints --ignore-error-breaks`; bare `--embedded --rendering-driver metal` aborts in `mvk::SPIRVToMSLConverter` (`SIGABRT`).
  Evidence: Phase 1 Workload 3 on `macOS M5 Max` (154 ms crash without debug flags vs 1280x720 non-black PNG pass with debug flags); `scripts/gate/display-run.mjs`; `scripts/dev-console.mjs`.
  Overturned by: —

- **DEV-03** · status: established · since: 2026-11-26 · origin: workspace protection & silent-by-default design
  Default every CLI logic run, warm session, and benchmark to `--headless --audio-driver Dummy` (plus `SDL_AUDIODRIVER=dummy` on Linux) with `HOME`/`XDG_*` isolated strictly under `artifacts/local/`; resolve `GODOT_BIN` before overriding `HOME`, and refuse bare Linux `--drawn` launches when neither `gamescope` nor `xvfb-run` is present unless `--windowed` is explicitly requested.
  Evidence: `scripts/dev-console.mjs`; `scripts/dev-console.test.mjs`; `scripts/godot-home.mjs`.
  Overturned by: —

- **DEV-04** · status: established · since: 2026-11-26 · origin: Phase 1 non-test_mode Workshop start-card discovery
  Starting a run via `run 1` in non-`test_mode` opens Moss's Workshop start-card briefing (`workshop.pausing() == true`), which holds `get_tree().paused = true`; unattended scripts must wait for the stage load and run `pick 1` before `tick <n>` or active-play assertions.
  Evidence: Phase 1 batch prototype run (`d6493d08e`); `sketches/core-loop/src/dev/dev_console.gd:357-371`; `scripts/dev-console.mjs`.
  Overturned by: —

- **DEV-05** · status: established · since: 2026-11-26 · origin: Engine.time_scale zeroing NaN guard & freeze_for_dev ownership
  Never set `Engine.time_scale = 0.0` to freeze or single-step the simulation (it divides by zero and produces NaN transforms); freeze through `game.freeze_for_dev(true)` and step physics frames by counting `_physics_process` ticks while temporarily unfreezing.
  Evidence: `sketches/core-loop/src/dev/dev_fight.gd:165-185`; commit `6b76830b0` (`game.freeze_for_dev`).
  Overturned by: —

## Changelog

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-11-26 | new lesson | DEV-01, DEV-02, DEV-03, DEV-04, DEV-05 | Phase 1 bakeoff & Phase 2 `dev-lever` (`scripts/dev-console.mjs`) | pending |
