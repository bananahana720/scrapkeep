# Structure survey: scripts
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 34   date: 2026-11-27

## Module map
(39 non-test files >= 400 lines in `scripts/` and `.github/workflows/`; 22 `*.test.mjs` files and 7 TLC `.out` fixture files under `scripts/gate/fixtures/tlc/` also exceed 400 lines and are summarized at the bottom of this section.)

scripts/dev-console.mjs | 1805 | Interactive and headless dev-console launcher, recipe runner, mailbox session daemon, and ref worktree runner | none (session files under `artifacts/local/dev-console/`) | `package.json` (`dev:console`)
scripts/sketch-fast.mjs | 1722 | PR fast-lane selector, diff hygiene checker, base-worktree failure confirmer, and Godot batch/solo runner | `running` child-process `Set`, in-memory `baseCache` / `redRuns` maps, `.git/sketch-fast/base-runs-*.json` | `.github/workflows/ci.yml`, `package.json` (`sketch:fast`), `scripts/gate/carry.mjs`
scripts/sketch-lint.mjs | 1421 | Static GDScript/toolchain linter (rules L1–L15, baseline ratchet, word-lint driver) | `codeLinesCache` and `faultWriteCache` module-level `Map`s, `scripts/sketch-lint.baseline.json` | `package.json` (`sketch:lint`), `scripts/hooks/pre-push.mjs`, `scripts/sketch-fast.mjs`, `scripts/alpha-rc.mjs`
scripts/sketch-fast.timings.json | 1413 | Per-test historical wall-clock duration table (1,408 tests) for budget planning and CI shard packing | JSON timing map on disk | `scripts/sketch-fast.mjs`, `scripts/sketch-smoke.mjs`, `scripts/ci/shard-plan.mjs`, `scripts/gate/shard.mjs`
scripts/music/lyria-tune.mjs | 1395 | Lyria/ACE-Step music stem generation, pack specs, remote SSH tuning workflow, and loudness checks | none (outputs under `artifacts/local/lyria-work/`) | `scripts/music/mx`
scripts/sketch-smoke.mjs | 1371 | Full/named/bot Godot test runner, machine slot & quiet-hold file lock, quarantine parser, and receipt writer | `/tmp/scrapkeep-sketch-smoke.slots`, `/tmp/scrapkeep-quiet-hold`, `artifacts/local/receipts/*.json` | `package.json` (`sketch:smoke`, `sketch:bots`, `sketch:gate`), `scripts/sketch-fast.mjs`, `scripts/gate/shard.mjs`, `scripts/play.mjs`
scripts/gate/pc.mjs | 1240 | Linux PC ("ahana") multi-step wave/release gate orchestrator, worktree pool, and isolated XDG step launcher | worktree pool owner map and per-step XDG/lock dirs under gate root | `package.json` (`gate:pc`)
scripts/challenge/lib.mjs | 1175 | Challenge band target tables, pilot/boss lists, NDJSON parsing, and statistical grading library | none (pure data/functions) | `scripts/challenge/run.mjs`, `scripts/gate/band-receipts.mjs`, `scripts/world1-bands.mjs`
scripts/gate/shard.mjs | 1098 | Sharded full-suite Godot runner, quiet-machine gate, solo retry, and shard markdown/JSON receipt builder | shard lock/log dirs under `--out` | `.github/workflows/ci.yml`, `package.json` (`gate:shard`), `scripts/gate/pc.mjs`, `scripts/gate/carry.mjs`
scripts/redteam/lib.mjs | 1025 | Red-team persona/pilot specs, anomaly grading, carry-list builder, and findings markdown/JSON formatter | none (pure data/functions) | `scripts/redteam/run.mjs`, `scripts/redteam/merge.mjs`, `scripts/redteam/eye.mjs`, `scripts/alpha-rc.mjs`
scripts/worktree-sandbox.mjs | 962 | Isolated detached git worktree + overlay + sandbox import cache manager for ref comparisons | lockfiles, `.sandbox-overlay.json`, `.godot/scrapkeep-sandbox-import.json` under `artifacts/local/dev-ref/` | `scripts/dev-console.mjs`
scripts/world1-bands.rows.json | 942 | Declarative World 1 promise/band threshold rows and receipt producer references | JSON table on disk | `scripts/world1-bands.mjs`, `scripts/gate/band-receipts.mjs`, `scripts/gate/map-standard-receipt.mjs`
scripts/check-skills.mjs | 903 | Structural, frontmatter, link, and portability validator for `.agents/skills/` and `.claude/skills/` | none | `package.json` (`check:skills`), `scripts/check-docs.mjs`
scripts/sketch-export.mjs | 828 | Linux x64 release export, release-gate check, packed win-proof bot runs, boss smoke, and `BUILD.txt` writer | temp isolated XDG dirs, output dir under `artifacts/local/` | `package.json` (`sketch:export`), `scripts/alpha-rc.mjs`, `scripts/cloud/export-headless.mjs`, `scripts/sketch-export-mac.mjs`
scripts/checkpoint.mjs | 780 | Multi-seed bot checkpoint runner, band evaluator, and human playtest prompt generator | none (outputs under `artifacts/local/`) | `package.json` (`sketch:checkpoint`), `scripts/sketch-nightly.mjs`, `scripts/world1-bands.mjs`
scripts/audio-gate.mjs | 777 | `ffmpeg`/`ffprobe` loudness (LUFS), true-peak, seam-click, and duration validator for audio stems | none | `scripts/gate/sound-levels-receipt.mjs`, `scripts/music/lyria-tune.mjs`, `scripts/placeholder-gate.mjs`
scripts/asset-inspect.mjs | 745 | GLB/WebP mesh triangle, material, and texture-side inspector against asset budget profiles | none | `package.json` (`asset:inspect`), `sketches/core-loop/tools/budget_audit.mjs`
scripts/world1-bands.mjs | 717 | World 1 band scorecard evaluator joining bot/gate receipts against `world1-bands.rows.json` | none | `package.json` (`sketch:world1-bands`)
scripts/token-diff.mjs | 711 | Comment/whitespace-insensitive token-stream differ for `.gd`, `.gdshader`, and `.js`/`.mjs` files | none | `package.json` (`check:token-diff`)
scripts/play.mjs | 707 | Local launcher, worktree resolver, and test/screenshot shortcut CLI (`npm run play`, `sketch:test`) | none | `package.json` (`play`, `sketch:test`), `scripts/bin/scrapkeep`
scripts/alpha-rc.mjs | 705 | Release-candidate verifier: AppImage boot timing, fresh profile shim, POSIX process-group reap, red-team carry | temp profile dirs under `os.tmpdir()` | `package.json` (`alpha:rc`)
scripts/sketch-nightly.mjs | 655 | Nightly soak orchestrator (repeated tests, bots, headless perf, fuzz, optional export) and flake-rate grader | `/tmp/scrapkeep-sketch-smoke.lock` (stale lock path), `/tmp/scrapkeep-gpu.lock`, `artifacts/local/receipts/nightly-*.json` | `package.json` (`sketch:nightly`)
scripts/challenge/run.mjs | 630 | Challenge band library builder, sharded bot runner, and comparison report CLI | run NDJSON and state dirs under `artifacts/local/` | `package.json` (`challenge:bands`)
scripts/check-agents.mjs | 611 | Validator for `.agents/` / `.claude/` agent definitions, banned model pins, hook configs, and retired script tokens | none | `package.json` (`check:agents`), `scripts/check-docs.mjs`
scripts/gate/model-receipts.mjs | 601 | Formal TLA+/TLC runner, version pin checker (`1.7.4`), planted-bug verification, and formal receipt builder | none (runs TLC under temp dirs) | `scripts/ledger-audit.mjs`, `scripts/world1-bands.rows.json`, `.agents/skills/scrapkeep-verify-formal/SKILL.md`
scripts/frametime-check.mjs | 539 | Frame-time capture launcher (MangoHud or engine CSV), quiet-hold requester, and p95/p99 budget grader | scratch user-data home under `artifacts/local/` | `package.json` (`sketch:frametime`), `scripts/alpha-rc.mjs`
scripts/challenge/gates-lib.mjs | 532 | Challenge gate job planner, bot CLI builder, and fairness/window summary rules | none (pure data/functions) | `scripts/challenge/gates.mjs`, `scripts/challenge/pack-pressure.mjs`
scripts/sketch-lint-words.mjs | 528 | Player-facing text extractor (`SOURCES` table) and W1–W7/S8 UI word linter | none | `scripts/sketch-lint.mjs`, `scripts/gate/words-on-screen-receipt.mjs`
scripts/gate/band-receipts.mjs | 505 | World 1 fight/novice/worst-window band receipt producer reading `world1-bands.rows.json` | none | `scripts/world1-bands.rows.json`, `scripts/gate/band-receipts.test.mjs`
scripts/card-runner.mjs | 492 | Unattended card planner and Claude worktree/review budget runner from `BACKLOG.md` and `STATE.md` | receipt files under `artifacts/local/` | `.agents/skills/scrapkeep-gemini-workflows/scripts/card_batch.py`
.github/workflows/ci.yml | 483 | GitHub Actions CI pipeline (`changes`, `lint`, `docs`, `node-tests` 2 shards, `web-build`, `godot-affected`, `godot-full` 8 shards, `ci-gate`) | GitHub Actions caches (`node_modules`, `apt-ffmpeg`, Godot binary, `.godot` import cache) | GitHub Actions triggers (`pull_request`, `push`, `merge_group`, `workflow_dispatch`)
scripts/placeholder-gate.mjs | 472 | Greybox/placeholder/text-marker census across park JSONs, registry, and audio assets | none | `package.json` (`sketch:placeholders`), `scripts/sketch-fast.mjs`, `scripts/alpha-rc.mjs`, `scripts/ledger-audit.mjs`
scripts/visual-qa-pack.mjs | 468 | Pure-JS PNG decoder/encoder, resizer, Rec.709 greyscale, and Machado deuteranopia contact-sheet generator | none | `scripts/dev-console.mjs`
scripts/wave-state.mjs | 455 | `STATE.md` / pointer-file consistency checker, promotion-commit parser, and red-team rotation tracker | none | `package.json` (`wave:state`), `scripts/check-docs.mjs`, `scripts/card-runner.mjs`
scripts/check-docs.mjs | 434 | Repo-wide Markdown link/anchor checker plus orchestrator invoking `check-skills`, `check-agents`, `wave-state`, `known-failing`, and `weekly` | `artifacts/local/check-docs/report.json` | `.github/workflows/ci.yml`, `package.json` (`check:docs`), `scripts/hooks/pre-push.mjs`, `scripts/sketch-fast.mjs`
scripts/pacing-check.mjs | 433 | Multi-seed bot pacing runner and World 1 pacing budget comparator | none | `package.json` (`sketch:pacing`)
scripts/gate/display-run.mjs | 427 | Windowed/offscreen drawn Godot runner with drawn-slot lock, `window-watch.mjs` guard, and process-group reaping | `/tmp/scrapkeep-drawn.slots`, scratch homes under `artifacts/local/display-run/` | `scripts/frametime-check.mjs`, `scripts/gate/model-render-receipt.mjs`, `scripts/water-flow-stills.mjs`
scripts/redteam/run.mjs | 423 | Parallel red-team bot/fuzz/eye orchestrator and findings writer | run dirs under `artifacts/local/redteam/` | `package.json` (`redteam`)
scripts/gate/snag-sweep-receipt.mjs | 414 | Map snag-sweep and control-check log grader for map-standard receipts | none | `scripts/gate/map-standard-receipt.mjs`, `scripts/gate/sitting-producers.test.mjs`

Large test suites >= 400 lines (22 files, all pure Node `node:test` suites): `sketch-smoke.test.mjs` (1973), `challenge/lib.test.mjs` (1471), `gate/gate.test.mjs` (1246), `sketch-fast.test.mjs` (1147), `sketch-lint.test.mjs` (1062), `gate/pc.test.mjs` (907), `gate/sitting-producers.test.mjs` (864), `sketch-export.test.mjs` (835), `dev-console.test.mjs` (730), `gate/band-receipts.test.mjs` (724), `sketch-nightly.test.mjs` (686), `gate/model-receipts.test.mjs` (669), `gate/look-receipts.test.mjs` (651), `world1-bands.test.mjs` (619), `frametime-check.test.mjs` (595), `redteam/lib.test.mjs` (573), `audio-gate.test.mjs` (533), `alpha-rc.test.mjs` (527), `model-audit.test.mjs` (491), `challenge/gates-lib.test.mjs` (488), `worktree-sandbox.test.mjs` (456), `checkpoint.test.mjs` (444), `placeholder-gate.test.mjs` (430), `wave-state.test.mjs` (421).

## Outward dependencies
(All dependencies point downward from the tooling/CI layer into game code, tests, docs, or configs; no lower-to-higher layer inversion exists from `scripts/`.)

- `sketches/core-loop/tests/` | 13 files (48 direct path refs; plus 35 files referencing `tests/` relative to the sketch, 1,867 refs led by `scripts/sketch-fast.timings.json` and `scripts/sketch-lint.mjs`) | e.g. `scripts/sketch-fast.mjs` (`ALWAYS`, `PATH_RULES`), `scripts/sketch-lint.mjs` (`L15_HZ_BASELINE`, `QUARANTINE.tsv`)
- `sketches/core-loop/src/` | 18 files (62 direct path refs; plus 39 files referencing `src/` relative to the sketch, 671 refs led by `scripts/sketch-lint.mjs` and `scripts/sketch-lint-words.mjs`) | e.g. `scripts/sketch-lint.mjs` (`L14_STATIC_VAR_BASELINE`, `LIGHT_OWNERS`, `ID_COMPARE_LEGACY`), `scripts/sketch-lint-words.mjs` (`SOURCES`)
- `sketches/core-loop/tools/` | 15 files (20 direct path refs; plus 54 files referencing `tools/` relative to the sketch, 139 refs) | e.g. `scripts/sketch-smoke.mjs` (`res://tools/test_batch.gd`), `scripts/challenge/run.mjs` (`res://tools/band_run.gd`)
- `sketches/core-loop/assets/` | 8 files (15 refs) | e.g. `scripts/music/lyria-tune.mjs` (`assets/music_ace`), `scripts/sketch-fast.mjs` (`assets/registry.d/`)
- `sketches/core-loop/design-v3/` | 4 files (4 refs) | e.g. `scripts/sketch-lint.mjs` (`design-v3/NAMES.md`), `scripts/pacing-check.mjs` (`design-v3/pacing/world1-pacing.json`)
- `sketches/core-loop/project.godot` | 5 files (6 refs) | e.g. `scripts/sketch-fast.mjs` (`bridgeFindings`), `scripts/sketch-export-mac.mjs`
- `project-guide/` | 21 files (34 refs) | e.g. `scripts/known-failing.mjs` (`project-guide/handoff/KNOWN-FAILING.tsv`), `scripts/wave-state.mjs` (`project-guide/handoff/STATE.md`)
- `artifacts/` | 35 files (66 refs) | e.g. `scripts/sketch-smoke.mjs` (`artifacts/local/receipts`), `scripts/dev-console.mjs` (`artifacts/local/dev-console`)
- `.agents/` and `.claude/` | 8 files (39 `.agents/` refs) and 4 files (10 `.claude/` refs) | e.g. `scripts/check-agents.mjs`, `scripts/check-skills.mjs`
- `docs/` and `adr/` | 7 files (22 `docs/` refs) and 1 file (1 `adr/` ref) | e.g. `scripts/check-project.mjs`, `scripts/world1-bands.rows.json`
- `src/`, `server/`, `tests/` (root browser proofs, out of scope except root `package.json` wiring) | `package.json`, `scripts/ci/affected.mjs`, `scripts/ci/format-changed.mjs`, `scripts/verify.mjs` | e.g. `package.json:15-18`, `scripts/ci/format-changed.mjs:9`

## Findings

### SCR-01 `sketch-lint.mjs` has five incompatible baseline/allowlist mechanisms and no single pattern for adding a baselined rule
- kind: G
- evidence:
  - Format 1 (JSON file-path array): `scripts/sketch-lint.mjs:14-15,571-590,632-636` reads/writes `scripts/sketch-lint.baseline.json` arrays for `L1`–`L4`.
  - Format 2 (JSON per-file count map): `scripts/sketch-lint.mjs:565-570,591-626,637-644` reads/writes `{ [path]: count }` maps in `sketch-lint.baseline.json` for `WORD_RULES` (`W1`, `W2`, `W4`, `W6`, `W7`, `S8`), with stale/lowered ratchets.
  - Format 3 (inline JS `{ sites, owner/why }` object): `scripts/sketch-lint.mjs:239-291` (`LIGHT_OWNERS`, L6), `335-352` (`SIM_READS`, L8), `397-402` (`HAND_MOVED`, L10), `459-485` (`ID_COMPARE_LEGACY`, L11 — 22 entries), each hand-checked with bespoke stale-entry messages.
  - Format 4 (inline JS `Set` of `file:var` keys): `scripts/sketch-lint.mjs:767-1093` (`L14_STATIC_VAR_BASELINE`, 325 hardcoded entries in source; no stale-entry ratchet at all).
  - Format 5 (inline JS `{ [rel]: count }` map): `scripts/sketch-lint.mjs:1170-1247` (`L15_HZ_BASELINE`, 76 hardcoded entries in source; `line 1260` checks `sites.length <= listed` and never warns when counts drop or files disappear).
  - Adding a new module-dependency-direction rule (`L16`) with a baseline therefore has no reusable registration hook and cannot use `--write-baseline` without touching `BASELINED_RULES`/`WORD_RULES`/`applyBaseline`/`baselineFrom`.
- fix: Add a small rule-baseline registry in `scripts/sketch-lint.mjs` backed by `scripts/sketch-lint.baseline.json` supporting two generic ratchet shapes (`count` per file and `keys` set per rule) handled uniformly by `applyBaseline` and `--write-baseline`. Move mechanical legacy ratchets (`L14_STATIC_VAR_BASELINE`, `L15_HZ_BASELINE`, and `ID_COMPARE_LEGACY` counts) into `sketch-lint.baseline.json` so `sketch-lint.mjs` shrinks by ~420 lines, while keeping justified permanent allowlists (`LIGHT_OWNERS`, `SIM_READS`, `HAND_MOVED`, `FAULT_SWITCHES`) in a documented `OWNERS` section. The new dependency-direction rule then plugs into the registry in one declaration.
- files to change: `scripts/sketch-lint.mjs`, `scripts/sketch-lint.baseline.json`, `scripts/sketch-lint.test.mjs`
- size: +120 / -450 lines in `sketch-lint.mjs`; +410 lines of structured data moved to `sketch-lint.baseline.json`
- risk: low (offline static linter; no gameplay/runtime touch; well-covered by unit tests)
- behaviour-preserving: yes (same rule findings on current tree; adds missing stale-entry ratchets for L14/L15 only when entries shrink, which matches current tree counts)
- tests that cover it: `scripts/sketch-lint.test.mjs`, `scripts/gate/words-on-screen-receipt.mjs`, `scripts/hooks/pre-push.test.mjs`
- guard: unit test in `scripts/sketch-lint.test.mjs` verifying every baselined rule round-trips through `baselineFrom` -> `applyBaseline` and flags stale/lowered entries.

### SCR-02 Root `package.json` `test` script hand-lists 54 files and silently omits 15 tracked `scripts/**/*.test.mjs` suites
- kind: E
- evidence:
  - `package.json:15` hand-lists 54 paths; `scripts/ci/node-tests.mjs:24-31,118-119` derives CI's `node-tests` shards strictly by parsing `package.json`'s `scripts.test`.
  - Comparing `git ls-files 'scripts/*.test.mjs' 'scripts/**/*.test.mjs'` (67 files) against `package.json:15` shows 15 tracked test files never run by `npm test` or CI: `scripts/audio-gate.test.mjs`, `scripts/budget-audit.test.mjs`, `scripts/crash-harvest.test.mjs`, `scripts/far-faults.test.mjs`, `scripts/first-timer.test.mjs`, `scripts/fold-registry.test.mjs`, `scripts/gate/display-run.test.mjs`, `scripts/gate/sitting-played-receipt.test.mjs`, `scripts/gate/sitting-producers.test.mjs`, `scripts/gate/window-watch.test.mjs`, `scripts/ledger-audit.test.mjs`, `scripts/model-audit.test.mjs`, `scripts/palette-gd.test.mjs`, `scripts/power-read.test.mjs`, `scripts/worktree-sandbox.test.mjs`.
  - Only 2 of the 15 (`scripts/far-faults.test.mjs`, `scripts/palette-gd.test.mjs`) are referenced by `NODE_PATH_RULES` in `scripts/sketch-fast.mjs:119-131`; 10 have zero callers anywhere in the repo (`git grep -l -F <name>` returned 0 hits outside self).
- fix: Make `scripts/ci/node-tests.mjs` discover `tests/*.test.js`, `scripts/**/*.test.mjs`, and `project-guide/handoff/sitting-kit/*.test.mjs` directly from disk (with a small documented `SKIP_IN_DEFAULT` set only if any of the 15 requires Python/macOS-only tools not installed on Ubuntu CI, e.g., `model-audit.test.mjs` or `window-watch.test.mjs`), and simplify `package.json` `"test"` to `"node scripts/ci/node-tests.mjs"`. (Alternative: keep `package.json` explicit and add a lint check; auto-discovery removes the hand-kept list altogether and is strictly better.)
- files to change: `scripts/ci/node-tests.mjs`, `scripts/ci/node-tests.test.mjs`, `package.json`
- size: +45 / -25 lines
- risk: low (test discovery only; verify each of the 15 suites passes on Linux CI / Ubuntu runner before enabling, quarantining any environment-specific suite into an explicit annotated list)
- behaviour-preserving: yes (no game or script runtime behaviour changes; expands CI test coverage)
- tests that cover it: `scripts/ci/node-tests.test.mjs`, `scripts/check-project.mjs`
- guard: test in `scripts/ci/node-tests.test.mjs` failing if any tracked `scripts/**/*.test.mjs` is neither discovered nor explicitly listed with a reason.

### SCR-03 `scripts/challenge/run.mjs` duplicates `runProcess`, `pool`, and `stateEnv` verbatim from sibling `scripts/challenge/proc.mjs`
- kind: A
- evidence:
  - `scripts/challenge/proc.mjs:6-53` exports `runProcess`, `pool`, and `stateEnv` (2 callers via `git grep -n 'proc\.mjs'`: `scripts/challenge/gates.mjs:29`, `scripts/challenge/pack-pressure.mjs:7`).
  - `scripts/challenge/run.mjs:187-234` defines identical copies of `runProcess`, `pool`, and `stateEnv` in the same folder (`stateEnv` is line-for-line identical; `runProcess` differs only by capturing module-scoped `godot`/`root`).
  - `scripts/redteam/run.mjs:95-126` duplicates `runProcess` and `pool` a third time; 5 more files define separate `pool`/`lanePool`/`runPool` workers (`scripts/checkpoint.mjs:466`, `scripts/pacing-check.mjs:366`, `scripts/power-read.mjs:305`, `scripts/sketch-smoke.mjs:1101`, `scripts/sketch-fast.mjs:833`).
- fix: Immediate step: import `{ pool, runProcess, stateEnv }` from `./proc.mjs` in `scripts/challenge/run.mjs`. Follow-on: lift `pool` into the shared process module (`SCR-06`) and replace the remaining copies in `redteam/run.mjs`, `checkpoint.mjs`, `pacing-check.mjs`, `power-read.mjs`.
- files to change: `scripts/challenge/run.mjs` (immediate); `scripts/challenge/proc.mjs`, `scripts/redteam/run.mjs`, `scripts/checkpoint.mjs`, `scripts/pacing-check.mjs`, `scripts/power-read.mjs` (follow-on)
- size: +3 / -48 lines (immediate); +30 / -140 lines (follow-on)
- risk: low (pure internal refactor of offline runners)
- behaviour-preserving: yes (identical control flow and return shapes)
- tests that cover it: `scripts/challenge/lib.test.mjs`, `scripts/challenge/gates-lib.test.mjs`, `scripts/redteam/lib.test.mjs`, `scripts/checkpoint.test.mjs`, `scripts/pacing-check.test.mjs`
- guard: none needed beyond consolidating to one `scripts/lib/proc.mjs` module.

### SCR-04 Finding the Godot binary is implemented 7 different ways across 22 scripts, with hardcoded `/home/andrew/` and `4.7.2` paths
- kind: G
- evidence: `git grep -n -E 'GODOT_BIN|Godot\.app|defaultGodot|resolveGodot'` across non-test `scripts/*.mjs` hits 22 files with 7 divergent policies:
  1. `scripts/sketch-smoke.mjs:25-34` (`defaultGodotBinary`: `GODOT_BIN` -> macOS `~/Applications/Godot_4.7.2.app/...` -> Linux `/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64` -> `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`; imported by `sketch-fast.mjs:25`, `play.mjs:17`, `first-timer.mjs:5`).
  2. `scripts/dev-console.mjs:175-210` (`resolveGodotBinary`: adds `which("godot")` and `/usr/bin/godot`, throws instead of returning a missing path).
  3. `scripts/sketch-export.mjs:11-12` and `scripts/power-read.mjs:15,333` (`GODOT_BIN || "/home/andrew/.local/share/godot/4.7.2/..."` — fails on cloud and macOS if `GODOT_BIN` is unset).
  4. `scripts/pacing-check.mjs:10,404` and `scripts/gate/shard.mjs:50,744` (`GODOT_BIN || "/opt/scrapkeep-toolchain/..."` — fails on macOS and Linux PC if `GODOT_BIN` is unset).
  5. 11 scripts require `process.env.GODOT_BIN` strictly with repeated `"set GODOT_BIN to the Godot 4.7.2 editor"` messages (`import-stamp.mjs:151`, `sketch-export-mac.mjs:206`, `frametime-check.mjs:484`, `gate/pc.mjs:1063`, `gate/display-run.mjs:153`, `challenge/gates.mjs:32`, `challenge/run.mjs:52`, `challenge/pack-pressure.mjs:115`, `cloud/export-headless.mjs:19`, `redteam/eye.mjs:63`, `redteam/run.mjs:24`).
- fix: Create `scripts/lib/godot.mjs` (or expand `scripts/godot-home.mjs`) as the single owner of `resolveGodotBinary({ requireExplicit, env, platform })` and `GODOT_VERSION` (read from one shared config, see SCR-10), removing the 4 hardcoded `/home/andrew/` paths from JS scripts (replaced by `path.join(os.homedir(), ".local/share/godot/...")` on Linux). Re-export `binary` from `sketch-smoke.mjs` for compatibility until callers migrate.
- files to change: 22 files (`scripts/godot-home.mjs` or `scripts/lib/godot.mjs` plus the 21 callers listed above)
- size: +60 / -110 lines
- risk: low (explicit `GODOT_BIN` stays highest priority everywhere; fallback resolution only becomes more consistent across Mac Studio, Linux PC, and cloud)
- behaviour-preserving: yes (`GODOT_BIN` takes precedence in every path; strict callers can pass `{ fallback: false }` if they intentionally refuse implicit binaries)
- tests that cover it: `scripts/dev-console.test.mjs`, `scripts/sketch-smoke.test.mjs`, `scripts/import-stamp.test.mjs`, `scripts/gate/gate.test.mjs`, `scripts/gate/pc.test.mjs`
- guard: extend `scripts/check-docs.mjs` or add a test in `scripts/check-project.mjs` banning `/home/andrew/` literals in `scripts/**/*.mjs` (currently banned only in `.md` files).

### SCR-05 Scratch Godot data-folder isolation bypasses `scripts/godot-home.mjs` in 11 scripts, breaking macOS save isolation in 4 of them
- kind: G
- evidence:
  - `scripts/godot-home.mjs:1-10` exists specifically because Godot on macOS ignores `XDG_DATA_HOME` and writes `user://` under `$HOME/Library/Application Support`, so `userDataEnv(dir)` moves `HOME` on `darwin` and preserves `HOME` on Linux. Only 8 scripts import `godot-home.mjs` (`git grep -l 'godot-home\.mjs' -- scripts/ | grep -v test` -> 8 files: `challenge/proc.mjs`, `challenge/run.mjs`, `frametime-check.mjs`, `gate/pc.mjs`, `gate/shard.mjs`, `import-stamp.mjs`, `sketch-fast.mjs`, `sketch-smoke.mjs`).
  - 4 Godot-spawning scripts set `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/`XDG_CACHE_HOME` manually WITHOUT moving `HOME` on macOS: `scripts/redteam/run.mjs:146-150,320-324`, `scripts/cloud/export-headless.mjs:126-131`, `scripts/sketch-export.mjs:472-479`, `scripts/sketch-nightly.mjs:294-295`.
  - `scripts/frametime-check.mjs:16,97,501` imports `userDataEnv` for engine captures (`line 501`) yet also builds a separate `{ XDG_DATA_HOME: data, XDG_CONFIG_HOME: config }` without `HOME` at `line 97`.
  - 5 scripts roll their own full `HOME` + `XDG_*` env unconditionally on all platforms: `scripts/dev-console.mjs:226-252`, `scripts/gate/display-run.mjs:29-47`, `scripts/worktree-sandbox.mjs:693-696`, `scripts/alpha-rc.mjs:295-308`, `scripts/sketch-export-mac.mjs:236,299`.
  - `scripts/sketch-smoke.mjs:981` and `scripts/sketch-fast.mjs:893,1324,1351` create `mkdtempSync(path.join(os.tmpdir(), ...))` inside `scratchHomeEnv`/`userDataEnv` inline and never `rmSync` the temp directories.
- fix: Make `scripts/godot-home.mjs` the sole owner of scratch Godot env setup by adding `scratchGodotEnv(dir, { xdgAll = false, forceHome = false, create = true, platform = process.platform })` and `withScratchGodotEnv(prefix, opts, fn)` (which cleans up in `finally`), and migrate all 11 bypassing scripts plus the 4 leaking inline `mkdtempSync` calls in `sketch-smoke.mjs` and `sketch-fast.mjs`.
- files to change: `scripts/godot-home.mjs`, `scripts/redteam/run.mjs`, `scripts/cloud/export-headless.mjs`, `scripts/sketch-export.mjs`, `scripts/sketch-nightly.mjs`, `scripts/frametime-check.mjs`, `scripts/dev-console.mjs`, `scripts/gate/display-run.mjs`, `scripts/worktree-sandbox.mjs`, `scripts/sketch-export-mac.mjs`, `scripts/sketch-smoke.mjs`, `scripts/sketch-fast.mjs`
- size: +45 / -115 lines
- risk: low (on Linux `XDG_*` values are unchanged; on macOS, fixes real `~/Library/Application Support` save leaks)
- behaviour-preserving: yes on Linux; fixes missing macOS isolation on Darwin
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-export.test.mjs`, `scripts/frametime-check.test.mjs`, `scripts/dev-console.test.mjs`, `scripts/gate/display-run.test.mjs`, `scripts/gate/pc.test.mjs`, `scripts/worktree-sandbox.test.mjs`
- guard: unit test in `scripts/sketch-smoke.test.mjs` (or new `scripts/godot-home.test.mjs`) + grep check in `scripts/check-project.mjs` ensuring scripts that set `XDG_DATA_HOME` for child spawns go through `godot-home.mjs`.

### SCR-06 Child-process timeout and reaping is implemented 13 ways across 14 scripts, and 10 fail to reap child process groups
- kind: G
- evidence:
  - Process-group reaping (`detached: true` + `process.kill(-pid, ...)`): 3 separate implementations — `scripts/alpha-rc.mjs:380-402` (`stopGroup`: `SIGTERM` -> grace -> `SIGKILL` + `waitGroupDead` polling `ps`), `scripts/gate/display-run.mjs:49-108` (`launch`: `SIGKILL` to `-child.pid` on timeout/SIGINT/SIGTERM/AbortSignal), `scripts/sketch-nightly.mjs:296-326` (`runProcess`: `SIGKILL` to `-child.pid`).
  - Non-detached `SIGTERM` -> 5 s `SIGKILL` on direct child PID only: `scripts/sketch-smoke.mjs:950-974` (`spawnCollect`), `scripts/sketch-fast.mjs:595-622` (`spawnText`), `scripts/dev-console.mjs:873-910`.
  - Non-detached immediate `child.kill("SIGKILL")` on direct child PID only (orphans grandchild processes such as `xvfb-run` -> `godot` or sub-shells): `scripts/sketch-smoke.mjs:1022-1031,1051-1070` (two inline copies that don't even reuse `spawnCollect`), `scripts/sketch-fast.mjs:729-770,777-817,889-901` (three inline copies), `scripts/challenge/proc.mjs:6-30`, `scripts/challenge/run.mjs:187-211`, `scripts/redteam/run.mjs:95-112`, `scripts/gate/shard.mjs:511-525`, `scripts/pacing-check.mjs:348-358`, `scripts/play.mjs:193-205`, `scripts/power-read.mjs:285-295` (note `power-read.mjs:69` wraps Godot in `xvfb-run`, so killing only the `xvfb-run` wrapper PID leaves Godot running!).
- fix: Create one `scripts/lib/proc.mjs` owning `runProcess(command, args, { cwd, env, timeoutMs, killGraceMs, signal, logFile, onChild, reapGroup = true })` using `detached: true` + POSIX process-group reaping (`SIGTERM` -> grace -> `SIGKILL` when `killGraceMs > 0`, or immediate `SIGKILL` to `-pid`), plus `pool(tasks, width)`. Migrate `sketch-smoke.mjs`, `sketch-fast.mjs`, `challenge/proc.mjs`, `redteam/run.mjs`, `gate/shard.mjs`, `gate/display-run.mjs`, `sketch-nightly.mjs`, `pacing-check.mjs`, `power-read.mjs`, `play.mjs`, and `dev-console.mjs`. (`alpha-rc.mjs`'s streaming `TITLE_INTERACTIVE`/`MENU_READY` AppImage launcher stays specialized, calling the shared `stopGroup` helper.)
- files to change: `scripts/lib/proc.mjs` (new) + 13 scripts listed above
- size: +130 / -340 lines
- risk: medium (process signals and exit-code/timeout semantics are tested by `alpha-rc.test.mjs`, `display-run.test.mjs`, `sketch-smoke.test.mjs`, `sketch-fast.test.mjs`, `sketch-nightly.test.mjs`; keep each caller's exact return shape via thin adapter or matched options)
- behaviour-preserving: yes (reaping child groups on timeout/abort is strictly safer and prevents leaked Godot grandchildren like `power-read.mjs`'s `xvfb-run`)
- tests that cover it: `scripts/alpha-rc.test.mjs`, `scripts/gate/display-run.test.mjs`, `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/sketch-nightly.test.mjs`, `scripts/dev-console.test.mjs`
- guard: unit tests in `scripts/lib/proc.test.mjs` verifying grandchild process-group termination on timeout and `AbortSignal`.

### SCR-07 `scripts/sketch-nightly.mjs` locks the retired `scrapkeep-sketch-smoke.lock` instead of `sketch-smoke.mjs`'s slot/quiet-hold lock
- kind: A
- evidence:
  - `scripts/sketch-smoke.mjs:351-620` implements the active machine lock at `<lockDir>/scrapkeep-sketch-smoke.slots/slot-*` and coordinates with `<quietDir>/scrapkeep-quiet-hold` (`holdQuietSync` / `acquireSlot` / `acquireMachine`). `sketch-fast.mjs:1307`, `frametime-check.mjs:532`, and `gate/display-run.mjs:116` all use it.
  - `scripts/sketch-nightly.mjs:15` already imports `* as smoke from "./sketch-smoke.mjs"`, yet `scripts/sketch-nightly.mjs:559-581` defines a local `acquireMachine(deadline)` locking `<lockDir>/scrapkeep-sketch-smoke.lock`. Nightly runs therefore never interlock with `sketch:smoke`, `sketch:fast`, `display-run`, or `frametime-check`'s quiet hold.
- fix: Add an optional `deadline` / `timeoutMs` parameter to `acquireSlot` (extracted into `scripts/lib/machine-lock.mjs` per SCR-16), delete `scripts/sketch-nightly.mjs:559-581`, and call `acquireSlot` (holding all slots or using `holdQuietSync` for exclusive nightly soak).
- files to change: `scripts/sketch-nightly.mjs`, `scripts/sketch-smoke.mjs` (or `scripts/lib/machine-lock.mjs`), `scripts/sketch-nightly.test.mjs`
- size: +15 / -28 lines
- risk: low (only affects nightly lock coordination; fixes a real mutual-exclusion bug)
- behaviour-preserving: no (intentionally fixes nightly failing to wait for active smoke/fast/frametime runs)
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-nightly.test.mjs`
- guard: test in `scripts/sketch-nightly.test.mjs` verifying nightly waits on an active `acquireSlot` / `holdQuietSync` lease.

### SCR-08 Six dead or test-only scripts with zero callers in npm scripts, CI workflows, hooks, skills, docs, or other scripts
- kind: B
- evidence (verified across the entire repo at commit `23e93551`):
  - Zero references anywhere in repo (0 hits):
    1. `scripts/challenge/pack-pressure.mjs` (258 lines) — `git grep -n -F pack-pressure.mjs` -> 0 hits.
    2. `scripts/sysaudit/first15-chart.mjs` (127 lines; sole file in `scripts/sysaudit/`) — `git grep -n -F first15-chart.mjs` -> 0 hits.
  - Test-only (referenced ONLY by their own unit test; zero npm script, CI, hook, skill, doc, or script callers):
    3. `scripts/park-anchor-kit.mjs` (79 lines) — `git grep -n -F park-anchor-kit.mjs` -> 1 hit (`scripts/park-anchor-kit.test.mjs:3`). Its migration target `"recipe": "greybox:anchor_field"` has **0 occurrences** left in all 6 real park files (`sketches/core-loop/src/world/park/park_{dam,flume,pit,sinkhole,islands,crown}.json`).
    4. `scripts/first-timer.mjs` (359 lines) — `git grep -n -F first-timer.mjs` -> 1 hit (`scripts/first-timer.test.mjs:6`; test omitted from `package.json`).
    5. `scripts/power-read.mjs` (394 lines) — `git grep -n -F power-read.mjs` -> 1 hit (`scripts/power-read.test.mjs:3`; test omitted from `package.json`).
    6. `scripts/splash-probe.mjs` (138 lines) — `git grep -n -F splash-probe.mjs` -> 1 hit (`scripts/splash-probe.test.mjs:3`).
  - Also test-only helper: `scripts/challenge/flume-opening.mjs` (45 lines) — `git grep -n -F flume-opening.mjs` -> 1 hit (`scripts/challenge/curve-reads.test.mjs:3`).
- fix: Per `AGENTS.md`'s deletion rule, list `pack-pressure.mjs`, `sysaudit/first15-chart.mjs`, and completed migration `park-anchor-kit.mjs` (+ test) for owner deletion go-ahead; ask the owner whether `first-timer.mjs`, `power-read.mjs`, `splash-probe.mjs`, and `flume-opening.mjs` should be deleted or wired into `package.json` / handoff docs.
- files to change: up to 7 scripts + 4 companion test files + `package.json` (`park-anchor-kit.test.mjs`, `splash-probe.test.mjs`)
- size: +0 / -1,400 to -2,000 lines (if all removed)
- risk: low (zero active callers anywhere in the repo)
- behaviour-preserving: yes (no active workflow, skill, hook, or npm script invokes them)
- tests that cover it: `scripts/park-anchor-kit.test.mjs`, `scripts/first-timer.test.mjs`, `scripts/power-read.test.mjs`, `scripts/splash-probe.test.mjs`, `scripts/challenge/curve-reads.test.mjs`
- guard: a cheap check in `scripts/check-project.mjs` flagging any non-library script under `scripts/` with no reference in `package.json`, `.github/workflows/`, `.agents/`, `docs/`, `project-guide/`, or another script.

### SCR-09 Retired `QUARANTINE.tsv` runtime machinery (~170 lines) and 4 dead/test-only exports in `sketch-smoke.mjs` and `sketch-fast.mjs`
- kind: B
- evidence:
  - `sketches/core-loop/tests/QUARANTINE.tsv` is empty (header only), and `scripts/sketch-lint.mjs:16,209-217` enforces `MAX_QUARANTINE = 0` (`"QUARANTINE.tsv is retired (max 0), use KNOWN-FAILING.tsv"`).
  - Despite retirement, `scripts/sketch-smoke.mjs:667-765,813,823-824,844-849,1239-1241,1303-1304,1333-1334` (~120 lines) and `scripts/sketch-fast.mjs:34-38,1290-1301,1550,1564-1570,1665-1672` (~50 lines) still read, parse, check expiry, and format `QUARANTINE.tsv` on every run.
  - Dead/test-only exports in `scripts/sketch-smoke.mjs`:
    - `FOREIGN_CLAIM_MAX_MS` (`line 362`): `git grep -n -F FOREIGN_CLAIM_MAX_MS` -> 1 hit (self only; 0 callers).
    - `waitForMachine` (`line 628`), `namedRunMustWait` (`line 622`): `git grep -n -w -E 'namedRunMustWait|waitForMachine'` -> hits only in `sketch-smoke.mjs` and `sketch-smoke.test.mjs` (test-only; `waitForMachine` is a shallow duplicate of `acquireMachine`).
    - `takeBatch` (`line 182`, re-exported by `sketch-fast.mjs:40,56`): `git grep -n -w takeBatch` -> hits only in `sketch-smoke.mjs`, `sketch-fast.mjs` re-export, and `sketch-fast.test.mjs` (production exclusively uses `takeBatchPacked`).
- fix: Remove `FOREIGN_CLAIM_MAX_MS`, `waitForMachine`, `namedRunMustWait`, and `takeBatch` (migrate tests to `acquireSlot` and `takeBatchPacked`). Keep L5 in `sketch-lint.mjs` blocking any non-empty `QUARANTINE.tsv`, and strip the runtime quarantine reader/formatter from `sketch-smoke.mjs` and `sketch-fast.mjs` (keeping empty `quarantined: []` in receipt schema only if external consumers read it, or dropping after confirming with owner).
- files to change: `scripts/sketch-smoke.mjs`, `scripts/sketch-fast.mjs`, `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`
- size: +10 / -230 lines
- risk: low (`QUARANTINE.tsv` is already enforced empty by `sketch-lint` L5; dead exports have zero production callers)
- behaviour-preserving: yes (receipt fields can remain empty arrays if needed; exit codes and test execution unchanged)
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/sketch-lint.test.mjs`
- guard: `sketch-lint.mjs` L5 (`MAX_QUARANTINE = 0`) already prevents any quarantine rows from returning.

### SCR-10 Godot version pin (`4.7.2-stable`) and 50 lines of CI Godot setup/cache are duplicated across 25 files and two `ci.yml` jobs
- kind: E
- evidence:
  - `4.7.2` / `4.7.2-stable` / `4.7.2.stable` is hardcoded in 20+ scripts and workflows: `.github/workflows/ci.yml:27-29`, `scripts/sketch-smoke.mjs:25,30-31`, `scripts/dev-console.mjs:189,201-202,208`, `scripts/sketch-export.mjs:11,466`, `scripts/sketch-export-mac.mjs:208`, `scripts/cloud/export-headless.mjs:47,153`, `scripts/gate/shard.mjs:50`, `scripts/gate/pc.mjs:1065`, `scripts/pacing-check.mjs:10`, `scripts/power-read.mjs:15`, `scripts/import-stamp.mjs:152`, `scripts/frametime-check.mjs:487`, `scripts/sketch-appimage.mjs`, `scripts/challenge/{gates,run,pack-pressure}.mjs`, `scripts/redteam/{eye,run}.mjs`.
  - `.github/workflows/ci.yml:285-334` (`godot-affected`) and `376-425` (`godot-full`) duplicate 50 lines verbatim: `godot-cache`, curl+sha512+python-unzip+sha256 install, `sketch-tree` hash, `import-cache`, and `import-stamp.mjs check || import`.
  - Similarly `node_modules` cache + `npm ci` is repeated 3 times in `.github/workflows/ci.yml:91-100,166-175,243-252`.
  - Default test timeout `180_000` (`sketch-smoke.mjs:41`, `sketch-fast.mjs:64,896,1321,1350`) and `40 * 60_000` (`challenge/gates.mjs:34`, `challenge/run.mjs:54`, `redteam/run.mjs:92`) and `"sketches/core-loop"` (53 files) are repeated as raw literals.
- fix: Create `scripts/toolchain.json` owning `godotVersion`, `godotTemplateVersion`, `godotZipSha512`, `godotBinSha256`, and `sketchDir`; read it in `scripts/lib/godot.mjs` (SCR-04) and in `.github/workflows/ci.yml`. Extract the duplicated 50-line CI Godot+import block into `.github/actions/setup-godot/action.yml` (and optionally `.github/actions/setup-node-cached/action.yml`).
- files to change: `scripts/toolchain.json` (new), `.github/actions/setup-godot/action.yml` (new), `.github/workflows/ci.yml`, plus scripts migrated in SCR-04
- size: +80 / -120 lines
- risk: low (pure configuration/workflow deduplication; verify CI workflow parses and `scripts/ci/promotion-pr.test.mjs` still passes)
- behaviour-preserving: yes (identical pinned version, hashes, cache keys, and commands)
- tests that cover it: `scripts/ci/promotion-pr.test.mjs`, `scripts/import-stamp.test.mjs`, `scripts/sketch-export.test.mjs`
- guard: test in `scripts/check-project.mjs` asserting `ci.yml` and `scripts/toolchain.json` stay in sync (or `ci.yml` reads `toolchain.json` directly so drift is impossible).

### SCR-11 Hand-maintained pilot/park ID tables, surface-classification regexes, and `sketch-fast.mjs` `PATH_RULES` drift across scripts
- kind: E
- evidence:
  - Pilot IDs (`pylon_engineer`..`remembered_cannon`) are hand-listed in 7 scripts (`git grep -l pylon_engineer -- scripts/ | grep -v test` -> 7): `scripts/challenge/lib.mjs`, `scripts/redteam/lib.mjs`, `scripts/first-timer.mjs:10-25`, `scripts/power-read.mjs:17-24`, `scripts/gate/six-pilots-receipt.mjs`, `scripts/sketch-export.mjs`, and `scripts/sketch-lint.mjs:437-457` (`CANONICAL_IDS` hand-lists 19 map + pilot IDs instead of parsing `src/core/{class_def,park_defs,alpha_defs}.gd`, even though `sketch-lint.mjs:88` already parses `tuning.gd`).
  - Park IDs (`park_dam`..`park_crown`) are hand-listed in 7 scripts (`git grep -l park_dam -- scripts/ | grep -v test` -> 7): `scripts/dev-console.mjs`, `scripts/gate/map-standard-receipt.mjs`, `scripts/gate/snag-sweep-receipt.mjs`, `scripts/park-anchor-kit.mjs`, `scripts/poi-census.mjs`, `scripts/sketch-lint.mjs`, `scripts/world1-bands.mjs`.
  - Repo surface-classification regexes are duplicated in 3 places with drift: `scripts/ci/affected.mjs:8-15` (`DOCS_PATTERN`, `NODE_PATTERN`, `WEB_PATTERN`, `GODOT_PATTERN`), `scripts/hooks/pre-push.mjs:26-27` (`DOCS_OR_PKG`), and `scripts/sketch-fast.mjs:217-229` (`classify`).
  - `scripts/sketch-fast.mjs:76-118` (`PATH_RULES`) hand-lists 20 park/map-standard test paths; programmatic check shows `src/world/park/park_dam.json` already has 15 direct `res://` referrers and `src/core/park_defs.gd` has 70, whereas `assets/registry.d/park_anchors.json` and `assets/models/warden.glb` have 0 direct `res://` referrers (only the asset-registry rule and non-`res://`-loaded park tests truly need `PATH_RULES`). Also `scripts/sketch-fast.timings.json` is missing 77 of the 1,485 current tests on disk (all defaulting to 180 s `DEFAULT_ESTIMATE_MS`).
- fix: Add one small `scripts/lib/game-defs.mjs` that parses canonical pilot and park/map IDs from `sketches/core-loop/src/core/{class_def,park_defs,alpha_defs}.gd` and have `sketch-lint.mjs`, `challenge/lib.mjs`, `redteam/lib.mjs`, and gate scripts import it. Export shared path classifiers from `scripts/ci/affected.mjs` for `pre-push.mjs` and `sketch-fast.mjs`. Prune `PATH_RULES` entries already guaranteed by `res://` traversal (or derive park-test membership via a test header tag like `# fast: park` / `# fast: map-standard`).
- files to change: `scripts/lib/game-defs.mjs` (new), `scripts/sketch-lint.mjs`, `scripts/ci/affected.mjs`, `scripts/hooks/pre-push.mjs`, `scripts/sketch-fast.mjs`, `scripts/challenge/lib.mjs`, `scripts/redteam/lib.mjs`, `scripts/world1-bands.mjs`
- size: +95 / -140 lines
- risk: low-to-medium (`PATH_RULES` pruning must preserve tier-0 always-run guarantees for park/map-standard tests checked by `scripts/ci/selection-mutation.test.mjs` and `scripts/sketch-fast.test.mjs`)
- behaviour-preserving: yes (same IDs and selected test sets, now derived from the owning `.gd` tables)
- tests that cover it: `scripts/sketch-lint.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/ci/affected.test.mjs`, `scripts/ci/selection-mutation.test.mjs`, `scripts/hooks/pre-push.test.mjs`
- guard: `scripts/sketch-lint.test.mjs` and `scripts/ci/selection-mutation.test.mjs` already pin rule behaviour; parsing from `src/core/*_defs.gd` prevents ID drift automatically.

### SCR-12 Reading git state (`git()`, `gitState()`, `cleanHead()`) is re-implemented across 35 scripts
- kind: G
- evidence:
  - 35 non-test `.mjs` files invoke `"git"` directly (31 via `spawnSync`, 4 via `execFileSync`: `deep-sweep.mjs:16`, `sprint-close.mjs`, `stems-sync.mjs`, `world1-bands.mjs`).
  - 11 files define bespoke `git(...)` wrappers with inconsistent throw-vs-null semantics and buffer sizes: `sketch-smoke.mjs:634`, `sketch-fast.mjs:563`, `checkpoint.mjs:447`, `deep-sweep.mjs:16`, `gate/carry.mjs:55`, `gate/model-receipts.mjs:474`, `gate/pc.mjs:1037`, `gate/shard.mjs:492`, `import-stamp.mjs:22`, `wave-state.mjs:237`, `gate/clean-head.mjs:8`.
  - 3 files define separate `gitState()` functions returning `{ head, tree, clean, dirty_paths }`: `scripts/sketch-smoke.mjs:640-648`, `scripts/sketch-nightly.mjs:542-557`, `scripts/alpha-rc.mjs:670`.
  - `scripts/gate/clean-head.mjs` already owns `root` and `cleanHead` (imported by 9 gate scripts), while 5 other `scripts/gate/*receipt*.mjs` scripts ignore it.
- fix: Promote `scripts/gate/clean-head.mjs` into `scripts/lib/git.mjs` exporting `REPO_ROOT`, `git(args, opts)`, `gitOptional(args, opts)`, `gitState(cwd)`, and `cleanHead(cwd)`, keeping `scripts/gate/clean-head.mjs` as a temporary re-export or updating the 9 gate imports directly.
- files to change: `scripts/lib/git.mjs` (new), `scripts/gate/clean-head.mjs`, plus the 13 scripts with local `git()`/`gitState()` wrappers (and incrementally the remaining callers)
- size: +65 / -150 lines
- risk: low (pure utility consolidation; watch `maxBuffer` for `deep-sweep.mjs` and `sketch-fast.mjs` diffs, default to 64 MB or pass explicitly)
- behaviour-preserving: yes
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/sketch-nightly.test.mjs`, `scripts/alpha-rc.test.mjs`, `scripts/deep-sweep.test.mjs`, `scripts/import-stamp.test.mjs`, `scripts/gate/gate.test.mjs`
- guard: none needed beyond standardizing new scripts on `scripts/lib/git.mjs`.

### SCR-13 Recursive directory walking (`walk()`) is re-implemented 12 times with inconsistent prune lists, and `check-project.mjs` duplicates `check-docs.mjs`
- kind: G
- evidence:
  - 10 scripts define dedicated `walk()` functions: `scripts/sketch-lint.mjs:1268`, `scripts/sketch-fast.mjs:235`, `scripts/audio-gate.mjs:96`, `scripts/check-agents.mjs`, `scripts/check-docs.mjs:38`, `scripts/check-skills.mjs`, `scripts/crash-harvest.mjs`, `scripts/export-include-check.mjs:58`, `scripts/placeholder-gate.mjs:300`, `scripts/sysaudit/first15-chart.mjs:14`.
  - 2 more define identically shaped recursive walkers: `scripts/check-project.mjs:27-35` (`markdown()`) and `scripts/verify.mjs:34-41` (`sourceFiles()`).
  - Prune rules diverge: `check-docs.mjs:54-67` prunes `.git`, `node_modules`, `.godot`, `dist`, `build`, `.venv`, `__pycache__`, `artifacts/local`, `tests/fixtures`, `sketches/core-loop/addons`; `sketch-fast.mjs:237` skips all dotfiles; `sketch-lint.mjs:1271` skips nothing.
  - Furthermore, `scripts/check-project.mjs:27-44` walks `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `artifacts/README.md`, and `docs/**/*.md` to check links — a strict subset of what `scripts/check-docs.mjs` already runs across every `.md` file in the repo.
- fix: Add `scripts/lib/walk.mjs` exporting `walkFiles(dir, { extensions, pruneDirs, relativeTo })` with POSIX-normalized paths, migrate the 10 active walkers to it, and drop the duplicated Markdown link-checking block from `scripts/check-project.mjs` (leaving `check-project.mjs` focused on required files and `package.json`/`package-lock.json` parity).
- files to change: `scripts/lib/walk.mjs` (new), `scripts/check-project.mjs`, and the 9 active scripts with local `walk()` helpers
- size: +45 / -180 lines
- risk: low (offline checkers/linters only; note CI runs `check:project` in the `lint` job even when `docs` is skipped, so confirm whether `docs/` link checks must stay in `lint` or only in `docs`)
- behaviour-preserving: yes for `walk()`; removing duplicate link check from `check-project.mjs` slightly changes which CI job checks `docs/` links on non-doc PRs (note: `docs` job runs whenever any `.md` changes)
- tests that cover it: `scripts/sketch-lint.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/audio-gate.test.mjs`, `scripts/placeholder-gate.test.mjs`, `scripts/export-include-check.test.mjs`, `scripts/crash-harvest.test.mjs`
- guard: `scripts/ci/affected.test.mjs` verifies `docs` triggers on every `.md` edit.

### SCR-14 Receipt writing, naming, and CLI scaffolding are duplicated across 3 runner scripts and 15 `scripts/gate/*receipt*.mjs` producers
- kind: G
- evidence:
  - Runner receipts: `scripts/sketch-smoke.mjs:662-665,1143-1152` (`receiptFileName`, `writeReceipt` -> `artifacts/local/receipts/<label>-<tree12>-<stamp>.json`), `scripts/sketch-nightly.mjs:583-589` (duplicates `writeReceipt`, reuses `smoke.receiptFileName`), and `scripts/sketch-fast.mjs:703-705,982-985` (defines its own `receiptBaseName(label, head, startedAt)` using `head` instead of `tree` and inlines directory creation + JSON write).
  - Gate receipt producers: 15 files match `scripts/gate/*receipt*.mjs` (`band-receipts`, `contact-orders-receipt`, `core-feel-receipt`, `installed-build-receipt`, `map-standard-receipt`, `model-receipts`, `model-render-receipt`, `release-gate-receipt`, `sitting-played-receipt`, `six-pilots-receipt`, `snag-sweep-receipt`, `sound-levels-receipt`, `sound-recipes-receipt`, `stand-ins-receipt`, `words-on-screen-receipt`). Each repeats `--head`/`--out` CLI parsing, `COMMIT = /^[0-9a-f]{7,40}$/` validation (duplicated in `world1-bands.mjs`, `band-receipts.mjs`, `snag-sweep-receipt.mjs`, etc.), and `mkdirSync` + `writeFileSync(..., JSON.stringify(..., null, 2) + "\n")`.
- fix: Create `scripts/lib/receipt.mjs` owning `writeJsonReceipt(file, data)`, `runnerReceiptPath(root, label, id, startedAt)`, and `COMMIT_SHA_RE`, plus a small `scripts/gate/receipt-cli.mjs` helper for standard `--head`/`--out` parsing and `cleanHead` fallback across `scripts/gate/*-receipt.mjs`.
- files to change: `scripts/lib/receipt.mjs` (new), `scripts/gate/receipt-cli.mjs` (new), `scripts/sketch-smoke.mjs`, `scripts/sketch-fast.mjs`, `scripts/sketch-nightly.mjs`, and the 15 `scripts/gate/*receipt*.mjs` files
- size: +90 / -260 lines
- risk: low (preserves every receipt's exact JSON schema and file path)
- behaviour-preserving: yes
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/sketch-nightly.test.mjs`, `scripts/gate/band-receipts.test.mjs`, `scripts/gate/feel-receipts.test.mjs`, `scripts/gate/look-receipts.test.mjs`, `scripts/gate/map-standard-receipt.test.mjs`, `scripts/gate/model-receipts.test.mjs`, `scripts/gate/sitting-played-receipt.test.mjs`, `scripts/gate/sitting-producers.test.mjs`, `scripts/gate/sound-receipts.test.mjs`
- guard: existing receipt producer tests verify output JSON shape and CLI exit codes.

### SCR-15 62 scripts hand-roll CLI argument loops (zero use `node:util` `parseArgs`) and 71 duplicate `isMain()` entrypoint guards with 3 variants
- kind: G
- evidence:
  - Programmatic scan across 104 non-test `.mjs` files in `scripts/`: **62 files** hand-roll `for (let i = 0; i < argv.length; i++)` or `for (const arg of argv)` flag loops, and **0 files** use Node's built-in `parseArgs` from `node:util`. Conventions diverge wildly: `--flag value` (`sketch-smoke.mjs:321`, `sketch-fast.mjs:185`, `ci/node-tests.mjs:79`) vs `--flag=value` (`power-read.mjs:42`, `splash-probe.mjs:30`, `challenge/pack-pressure.mjs:26`); unknown flags are silently ignored in `sketch-smoke.mjs:321-330` and `sketch-fast.mjs:185-209` (risking silent typos like `--budeget`), while `ci/node-tests.mjs:96` and `hooks/pre-push.mjs:242` throw.
  - **71 non-test `.mjs` files** repeat the ESM `isMain` entrypoint check in 3 inconsistent variants: 13 define `function isMain()` with `try { realpathSync } catch { resolve }` (e.g. `ci/node-tests.mjs:102-109`, `hooks/pre-push.mjs:248-255`), 32 call bare `realpathSync(process.argv[1])` (e.g. `sketch-lint.mjs:1421`, `sketch-smoke.mjs:1371`), and 26 call `path.resolve(process.argv[1])` without `realpathSync` (e.g. `deep-sweep.mjs:278`, `import-stamp.mjs:229`, `park-anchor-kit.mjs:79`), which silently skips `main()` when invoked through a symlink.
- fix: Add `scripts/lib/cli.mjs` exporting `isMain(metaUrl)` (using the safe `try { realpathSync } catch { resolve }` pattern) and a thin wrapper around `node:util` `parseArgs` with strict unknown-flag rejection. Migrate the 26 broken `path.resolve`-only guards and `sketch-smoke.mjs`/`sketch-fast.mjs` silent unknown-flag loops first, then adopt `cli.mjs` as scripts are touched.
- files to change: `scripts/lib/cli.mjs` (new), plus 26 symlink-fragile scripts (high priority) and incrementally the 62 hand-rolled CLI parsers
- size: +40 / -180 lines (for `isMain` + priority parsers)
- risk: low (strict unknown-flag checks on `sketch-smoke.mjs`/`sketch-fast.mjs` must be verified against every caller in `package.json`, `ci.yml`, `gate/shard.mjs`, `gate/pc.mjs`)
- behaviour-preserving: yes for valid invocations; turns silent CLI flag typos into explicit usage errors
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/ci/node-tests.test.mjs`, `scripts/ci/affected.test.mjs`, `scripts/ci/format-changed.test.mjs`, `scripts/ci/check-budget.test.mjs`, `scripts/hooks/pre-push.test.mjs`
- guard: `oxlint` or a `check-project.mjs` check warning on bare `path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)`.

### SCR-16 `scripts/sketch-smoke.mjs` (1,371 L) and `scripts/sketch-fast.mjs` (1,722 L) bundle 4 unrelated subsystems each along clean private-state seams
- kind: H
- evidence:
  - `scripts/sketch-smoke.mjs` (1,371 lines, 73 exports) contains 4 separable subsystems with disjoint state:
    1. Machine slot pool & quiet-hold lock (`lines 351–632`, 282 lines): imported by `sketch-fast.mjs`, `frametime-check.mjs`, and `gate/display-run.mjs`, forcing unrelated tools to import the entire smoke test runner (which also eagerly computes `export const binary = defaultGodotBinary()` at module load!).
    2. Test directive parsing (`# smoke: solo|bots|fixed-fps=|timeout=`), batch packing (`takeBatchPacked`, `splitBatch`), and verdict judging (`judge`, `failingLines`, `countChecks`) (`lines 55–309, 857–905`, ~300 lines).
    3. Retired `QUARANTINE.tsv` code (`lines 667–765`, ~100 lines; see SCR-09).
    4. CLI runner, import retry, process pool, receipt builder (`lines 907–1371`, ~460 lines).
  - `scripts/sketch-fast.mjs` (1,722 lines, 53 exports) bundles:
    1. Test dependency index, `PATH_RULES`, and budget planner (`lines 61–403`, 343 lines).
    2. PR diff hygiene, removed-check detector, and carried-PR staleness check (`lines 451–561, 999–1135`, ~245 lines).
    3. Base-worktree failure confirmation and `.git/sketch-fast/base-runs-*.json` cache (`lines 405–449, 849–885, 1431–1593`, ~245 lines).
    4. Godot batch/solo runner (`lines 595–847`, ~250 lines), duplicating `sketch-smoke.mjs`'s runner and re-exporting 7 batch symbols from `sketch-smoke.mjs:50-58`.
- fix: Extract along those exact seams into `scripts/lib/machine-lock.mjs` (`acquireSlot`, `acquireMachine`, `holdQuietSync`, `quietHolder`), `scripts/lib/godot-test-runner.mjs` (directives, `takeBatchPacked`, `splitBatch`, `judge`, `runBatch`, `runTest`), and `scripts/lib/fast-diff-checks.mjs` (`hygieneFindings`, `bridgeFindings`, `checksRemoved`, `carriedPrs`, `placeholderIncrease`). Keep re-exports in `sketch-smoke.mjs` and `sketch-fast.mjs` during migration so tests stay green in small PRs.
- files to change: `scripts/sketch-smoke.mjs`, `scripts/sketch-fast.mjs`, `scripts/lib/machine-lock.mjs` (new), `scripts/lib/godot-test-runner.mjs` (new), `scripts/lib/fast-diff-checks.mjs` (new), plus callers `scripts/frametime-check.mjs`, `scripts/gate/display-run.mjs`, `scripts/ci/shard-plan.mjs`, `scripts/sketch-nightly.mjs`
- size: +650 / -650 lines (net neutral move, cutting both files below ~800 lines)
- risk: medium (central test runners; mitigate by moving one seam per PR with temporary re-exports)
- behaviour-preserving: yes (pure code motion)
- tests that cover it: `scripts/sketch-smoke.test.mjs`, `scripts/sketch-fast.test.mjs`, `scripts/ci/shard-plan.test.mjs`, `scripts/gate/display-run.test.mjs`, `scripts/frametime-check.test.mjs`
- guard: `scripts/deep-sweep.mjs` D5 (giant file growth) covers GDScript; a simple line-count budget in `scripts/check-project.mjs` can flag new >1,000-line scripts.

### SCR-17 `scripts/cloud/export-headless.mjs` duplicates the Linux export, addon copy, and win-proof loop of `scripts/sketch-export.mjs`
- kind: A
- evidence:
  - `scripts/cloud/export-headless.mjs:6-15` already imports 8 helpers (`WIN_PROOFS`, `playProofTries`, `proofLibraries`, `releaseGateFailures`, `winProofBotArgs`, `winProofFailures`, `winProofLine`, `winProofTimeoutMs`) from `scripts/sketch-export.mjs`.
  - Lines `49–159` then re-implement the exact same pipeline as `scripts/sketch-export.mjs`: editor import (`49`), release gate (`50-59`), `--export-release "Linux x64"` (`65-69`), 300/600-frame headless boots (`70-74`), `--export-pack "Linux x64 proof"` (`81-84`), `readdirSync(addons, { recursive: true })` copy (`85-94`, matching `sketch-export.mjs:766-775`), `playOnce` XDG isolation (`105-144`, missing `godot-home.mjs`), and `BUILD.txt` writer (`148-159`, hardcoding `"godot: 4.7.2.stable"`).
- fix: Add a `--headless-only` / `--skip-gpu-smoke` mode to `scripts/sketch-export.mjs` (which already owns the export pipeline and `withIsolatedXdg`) and turn `scripts/cloud/export-headless.mjs` into a 10-line forwarding CLI (or update `scripts/cloud/README.md` and retire it).
- files to change: `scripts/sketch-export.mjs`, `scripts/cloud/export-headless.mjs`, `scripts/sketch-export.test.mjs`
- size: +25 / -145 lines
- risk: low (export pipeline is well-tested in `sketch-export.test.mjs` and only differs by omitting GPU boss smoke and ACE stems)
- behaviour-preserving: yes
- tests that cover it: `scripts/sketch-export.test.mjs`
- guard: unit test in `scripts/sketch-export.test.mjs` covering `--headless-only` mode.

### SCR-18 `scripts/sketch-fast.mjs` duplicates `globToRegExp`, `godotIdentity`, and `runBatch` (and misses outside-batch error detection)
- kind: A
- evidence:
  - Glob-to-RegExp: `scripts/sketch-fast.mjs:277-290` (`expand`) re-implements `*` glob escaping even though `sketch-fast.mjs:33` imports `matchesGlob` from `sketch-smoke.mjs:287-298`; two more copies live in `scripts/ci/node-tests.mjs:15-17` and `scripts/known-failing.mjs:116-123`.
  - Binary identity: `scripts/sketch-fast.mjs:1437-1438` builds `binaryId = "${binary} ${size} ${mtimeMs}"` instead of calling `godotIdentity(binary)` already imported at `line 46` from `scripts/import-stamp.mjs:28-35`.
  - Batch execution divergence: `scripts/sketch-smoke.mjs:1043-1099` (`runBatchJobs`) checks `batchHasOutsideError(outside)` and reruns the whole batch solo if an `ERROR`/`SCRIPT ERROR` occurred outside `BATCH START..END` markers; `scripts/sketch-fast.mjs:773-818` (`runBatch`) destructures only `{ done, cut, rest } = splitBatch(...)` and silently drops `outside`, so an engine error during batch teardown or between tests is not caught in `sketch:fast`.
- fix: Export `globToRegExp` cleanly (without stripping `.gd` unconditionally) from `scripts/lib/godot-test-runner.mjs` (SCR-16), replace `binaryId` in `sketch-fast.mjs:1438` with `godotIdentity(binary)`, and share one `runBatch` implementation (from SCR-16) that checks `batchHasOutsideError(outside)` in both `sketch:smoke` and `sketch:fast`.
- files to change: `scripts/sketch-fast.mjs`, `scripts/sketch-smoke.mjs`, `scripts/ci/node-tests.mjs`, `scripts/known-failing.mjs`, `scripts/sketch-fast.test.mjs`
- size: +20 / -65 lines
- risk: low (unifying `runBatch` closes a real silent-error gap in `sketch-fast.mjs`)
- behaviour-preserving: yes on clean batches; catches outside-batch engine errors on dirty batches in `sketch-fast.mjs` (matching `sketch-smoke.mjs`)
- tests that cover it: `scripts/sketch-fast.test.mjs`, `scripts/sketch-smoke.test.mjs`, `scripts/import-stamp.test.mjs`
- guard: unit test in `scripts/sketch-fast.test.mjs` asserting `outside` `SCRIPT ERROR` triggers solo fallback just like `sketch-smoke.test.mjs`.

## Not findings
- `scripts/gate/{installed-build,release-gate,six-pilots,words-on-screen}-receipt.mjs` have zero `package.json`/CI callers, but they are active sitting-kit receipt producers invoked on demand by the Gate and covered by `scripts/gate/sitting-producers.test.mjs` (the real bug is that `sitting-producers.test.mjs` is omitted from `package.json`, covered in SCR-02).
- `scripts/check-agents.mjs` is not listed as a top-level step in `.github/workflows/ci.yml`, because `scripts/check-docs.mjs:269-308,368` invokes it directly (along with `check-skills`, `wave-state`, `known-failing`, and `weekly`) whenever the `docs` CI job runs.
- `scripts/worktree-sandbox.mjs:36,662` uses its own `scrapkeep-sandbox-import.json` rather than `import-stamp.mjs`'s `scrapkeep-import.json`, which is intentional because sandbox worktrees layer overlay files over a detached ref and already delegate the actual import passes and `godotIdentity` to `import-stamp.mjs:26-28,716`.
- `scripts/sketch-fast.mjs:68-75` (`ALWAYS` list of 6 repo-scan tests) and `scripts/sketch-fast.mjs:94-101` (`assets/` `PATH_RULES`) cannot be derived from `res://` text search because binary `.glb`/`.png` and `registry.d/*.json` files are loaded dynamically; keeping those explicit is necessary.
- `scripts/hooks/pre-push` (4-line POSIX shell shim calling `scripts/hooks/pre-push.mjs`) is not a redundant shallow wrapper; git hooks must be executable files under `.git/hooks/pre-push` and delegating immediately to Node keeps the logic cross-platform and unit-testable.
- `scripts/ensure-node-modules.mjs` (worktree symlink of `node_modules` from the main clone) is intentionally self-contained with zero non-builtin imports so it can run before `node_modules` exists.
- `scripts/ci/oxlint.json` disables 19 style/micro-perf rules (`no-await-in-loop`, `no-shadow`, etc.) while keeping `correctness`, `suspicious`, and `perf` categories at `error`; that is a deliberate baseline for CLI scripts, not slop.
- `scripts/sketch-lint.mjs` `LIGHT_OWNERS`, `SIM_READS`, `HAND_MOVED`, and `FAULT_SWITCHES` are permanent justified ownership/invariant allowlists (each row carries a human `owner`/`why` rationale), distinct from mechanical legacy ratchets like `L14`/`L15`/`ID_COMPARE_LEGACY`.
- `scripts/gate/display-run.mjs` hardcodes SHA-256 hashes of 3 GDScript capture tools (`lines 209-230`); this is an intentional tamper-check for watched capture runs, not a stale constant.

## Needs the owner
- Deletion go-ahead (`AGENTS.md` rule) for confirmed zero-caller / finished-migration scripts: `scripts/challenge/pack-pressure.mjs`, `scripts/sysaudit/first15-chart.mjs`, `scripts/park-anchor-kit.mjs` (+ `scripts/park-anchor-kit.test.mjs`), and retirement decision (delete vs wire into `package.json`/docs) for test-only scripts `scripts/first-timer.mjs`, `scripts/power-read.mjs`, `scripts/splash-probe.mjs`, and `scripts/challenge/flume-opening.mjs`.
- Decision on whether to delete `sketches/core-loop/tests/QUARANTINE.tsv` completely (already retired with `MAX_QUARANTINE = 0` in `sketch-lint.mjs`) and drop `quarantined`/`quarantine_expired` fields from smoke/fast JSON receipts.
- Confirmation on whether `scripts/music/lyria-tune.mjs` hardcoded Linux PC paths (`/home/andrew/Projects/scrapkeep-alpha-cut`, `/home/andrew/.local/share/ACE-Step-1.5/.venv/bin/python`, `/home/andrew/.local/share/demucs-venv/bin/demucs`) should stay as defaults (overridable by env) or move to a local machine config outside the repo.
- Decision on whether `scripts/ci/node-tests.mjs` auto-discovery should include all 15 currently omitted `scripts/**/*.test.mjs` suites on Ubuntu CI (notably `model-audit.test.mjs`, `audio-gate.test.mjs`, `gate/display-run.test.mjs`, `gate/window-watch.test.mjs`) or mark host-specific ones (macOS `osascript` / Python Blender tools) as opt-in.
