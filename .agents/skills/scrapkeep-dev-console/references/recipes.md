# Dev Console CLI Recipes & Usage

Entry point: `npm run dev:console -- <subcommand> [options]` (`scripts/dev-console.mjs`). All runs isolate `HOME` and `XDG_*` under `<repo>/artifacts/local/dev-console/` and force `--audio-driver Dummy` (plus `SDL_AUDIODRIVER=dummy` on Linux).

## Built-in recipes

| Recipe | Default mode | Purpose |
| --- | --- | --- |
| `smoke` | `--headless` | Boot into World 1 stage 1, dismiss start card, inspect state/player/perf, assert stage + finite |
| `combat-probe` | `--headless` | Spawn chasers, lobber, and jolt layer; tick 90 frames; inspect enemies/telegraphs/events; clear hard and assert 0 |
| `boss-retry-probe` | `--headless` | Enter stage 2 boss, jump to phase 2, retry arena cleanly, then verify lethal death to summary with zero anomalies |
| `look-sheet` | `--drawn` | Hide HUD, freeze frame, capture labeled `sheet presets look_sheet` offscreen |
| `cam-sheet` | `--drawn` | Hide HUD, freeze frame, capture labeled `sheet cams cam_sheet` offscreen |
| `quality-pair` | `--drawn` | Hide HUD, freeze frame, capture side-by-side `sheet quality quality_pair` offscreen |
| `overlay-check` | `--drawn` | Spawn active enemies, tick 90 frames, enable `overlay all`, freeze, switch to `cam high`, save `shot overlay_check` |
| `perf-budget` | `--drawn` | Warp to stage landmark offscreen and inspect `perf` and `prims` |

Example:

```sh
npm run dev:console -- recipe smoke --json
npm run dev:console -- recipe look-sheet --out artifacts/local/look-check --json
```

## Headless vs silent offscreen (`--drawn`)

- **Headless (default)** for `run`, `serve`, `bench`, and logic recipes: passes `--headless --audio-driver Dummy`, opens zero windows, plays zero sound, and never steals desktop focus.
- **Silent offscreen (`--drawn`)** for visual recipes and explicit captures:
  - **macOS (`darwin`)**: `--embedded --rendering-driver metal --debug --skip-breakpoints --ignore-error-breaks --audio-driver Dummy --resolution <WxH>`.
  - **Linux (`linux`)**: wraps Godot inside `gamescope --backend headless -W <W> -H <H> --` (preferred) or `xvfb-run -a -s "-screen 0 <W>x<H>x24"` with `--audio-driver Dummy`. If neither headless compositor is installed, the CLI refuses with exit code `2` rather than opening a visible window.
- **`--windowed`**: opt-in only; never passed by default.

## Warm File-Mailbox session lifecycle

Use a warm session when exploring across 3+ sequential turns (~7 ms sync turn RTT vs ~6.7 s per cold boot):

```sh
npm run dev:console -- serve --session probe --table park --seed 7 --json
npm run dev:console -- send --session probe "calm on; run 1; wait 60; pick 1; tick 15" --json
npm run dev:console -- send --session probe "spawn chaser 2; tick 30; inspect enemies" --json
npm run dev:console -- status --session probe --json
npm run dev:console -- stop --session probe --json
```

`serve` checks for stale PIDs and removes dead `<inbox>/ready.json` files before starting. `stop` sends `quit` through the mailbox, waits up to 5 seconds for clean exit, and falls back to `SIGTERM` if needed.

## Pixel diff and benchmark

- **Pixel diff** (pure Node `node:zlib`, 8-bit RGB/RGBA/Gray, PNG filters 0–4):
  `npm run dev:console -- diff <before.png> <after.png> --json`
  Returns `{width, height, total_pixels, changed_pixels, changed_pct, mean_abs_delta, max_delta, identical}`.
- **Cold vs warm benchmark**:
  `npm run dev:console -- bench --turns 10 --json`

## Evidence limits

- Dev-console runs prove engine state, command effects, assertion outcomes, and captured frames under scripted control.
- They do **not** prove player-facing menu/input wiring (use `scrapkeep-verify-game`), packed Linux exports (use `scrapkeep-verify-build`), release gate admission (use `scrapkeep-verify`), or human game feel.
