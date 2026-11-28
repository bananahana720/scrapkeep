# Developing Scrapkeep

Start with [AGENTS.md](AGENTS.md) (whose reading order begins with [START-HERE.md](project-guide/handoff/START-HERE.md)). Current alpha work lives in `sketches/core-loop` (flat on `main` under ruling ep); its gate rule is in [AGENTS.md](AGENTS.md) and [ORCHESTRATOR.md](ORCHESTRATOR.md)'s tiered gate. The [first-proof contract](docs/FIRST-BUILD-CONTRACT.md) is historical.

For heavy-lane rules, read [ORCHESTRATOR.md](ORCHESTRATOR.md), [BACKLOG.md](BACKLOG.md), and [TRACKING.md](TRACKING.md). [Engineering ADRs](adr/README.md) are accepted production architecture. Existing browser conventions below govern only the two preserved proofs.

## Install and run

Use Node matching `package.json#engines` and the committed lockfile (aligned with Vite).

```sh
npm ci
npm run dev
```

Vite serves the orchard at `http://127.0.0.1:5173/orchard.html` and the original yard at `/`. Only the baseline signup flow needs the separate API server. For a built local playtest with contact capture disabled:

```sh
npm run build
CAPTURE_ENABLED=false npm start
```

Open `http://127.0.0.1:8787/orchard.html`. If a port is occupied, inspect the owner before changing or stopping it. Vite prints its actual URL. Environment settings are documented in [.env.example](.env.example) and [lead capture](docs/LEAD-CAPTURE.md). `npm start` does not load a .env file implicitly.

## Verification

```sh
npm run verify
```

This runs project checks, the Node tests matched by `tests/*.test.js`, model invariants, the asserted baseline expedition check, a production build, and temporary-port HTTP checks for both entries and their linked assets. The frozen lead-capture suite under `tests/legacy/` is not part of it; run `npm run test:leads` separately. Each stage stops on failure. Logs, source hashes, and a machine-readable result go to `artifacts/local/verify/`. The built-entry stage starts a minimal static server for `dist/` on a temporary port, asserts that `/api/config` returns 404, and closes it. It does not start the lead-capture server, stop the user's server, or run browser automation.

| Command | Use and limits |
| --- | --- |
| `npm run check:project` | Required canonical files and `package.json`/`package-lock.json` parity checks. Markdown links and anchors are checked by `npm run check:docs`; runtime behavior and full import analysis are outside this check. |
| `npm run check:docs` | Repo-wide documentation structural check (every Markdown file outside pruned dirs like `artifacts/local`, `tests/fixtures`, `sketches/core-loop/addons`, `node_modules`): relative file links and `#anchor` targets (rejecting absolute `/...` links), `check:skills`, `check:agents`, `wave-state`, `known-failing` / `weekly-list`, duplicate `DECISIONS.md` ruling letters, and `sketches/core-loop/ARCHITECTURE.md` sync against `sketches/core-loop/src/` and `context.gd`. Writes findings and a sha256 manifest to `artifacts/local/check-docs/report.json`. Exit 1 on any failure, 2 on an internal error. No build, runtime, browser or remote check is implied. |
| `npm run check:skills` | Staleness check for the skills under `.agents/skills/`: frontmatter `name` and `description`, the `.claude/skills` symlink, every cited repository path, `npm run` script, `scrapkeep` verb, the lesson ledgers (status, evidence, `Overturned by` on a retracted lesson), the portable skill's forbidden-token list, and `SKILL.md` body size. `npm run check:docs` runs it and `npm run check:agents` as stages. Exit 0 clean, 1 findings, 2 usage or unreadable input. It checks that citations exist, not that a cited line still supports its lesson. |
| `npm run check:agents` | Structural check for `.agents/` (subagent YAML frontmatter, native tools, read-only posture, two-way `.claude/agents` parity, `.agents/rules/` triggers/size, `.agents/hooks.json` handlers/scripts, Python workflow AST syntax + undefined `call_tool()` ban, and dead `astack` references). `npm run check:docs` runs it as a stage. Exit 0 clean, 1 findings, 2 usage or unreadable input. |
| `npm run check:scope -- <base> <candidate> [--no-build]` | Classifies changed paths between revisions (`sketch`, `documentation-only`, `browser-proof`, `tooling`, `tooling-no-build`, `native`, `configuration`, `mixed`, `other`, `empty`) and prints required commands. `tooling-no-build` covers `scripts/*.mjs`, `tests/*.test.js`, `tests/fixtures/check-scope/*.json`, config paths (`.agents/`, `.claude/`, `.codex/`, `.gemini/`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.gitignore`, `.env.example`), `package.json` `scripts`-only diffs, and co-located docs; `--no-build` exits non-zero when build-requiring paths appear. |
| `npm run check:token-diff` | Lexes `.gd`, `.gdshader`, `.js`, `.mjs`, `.ts` across `<base>` vs working tree or `--staged`, stripping non-pragma comments while normalizing `# smoke:` (lines 1-5), `# lint:`, and `// lint:` pragmas. Exits 0 if token-identical, 1 on diff, 2 on error. |
| `scripts/new-worktree.sh <task-id> <base-sha>` | Creates `../scrapkeep-wt-<task-id>` on branch `wt/<task-id>` at the exact 40-hex commit and links `node_modules` via `npm run worktree:deps` when `package-lock.json` matches. Refuses existing paths/branches or mismatched bases. |
| `npm run worktree:deps` | Symlinks `node_modules` in a git worktree to the primary checkout when `package-lock.json` sha256 matches and primary `oxfmt`/`oxlint` exist (also run by `hooks:install`, `scripts/hooks/pre-push.mjs`, and `scripts/ci/node-tests.mjs`). |
| `npm run sketch:smoke` | Light-play-lane check for every `sketches/*/project.godot`: headless import, 300-frame boot, and all `tests/*.gd` scripts with the pinned Godot binary or `GODOT_BIN`. Fails on errors, failures, or missing `<name>: PASS` verdicts. |
| `npm run sketch:fast` | Fast PR lane (`-- --base <ref>`, default `origin/main`). Pass `--test <name-or-glob>` to run matching `tests/*.gd` directly; otherwise runs `sketch:lint`, placeholder non-increase check, `check:docs` (on `.md` changes), reached Node tests, Godot import, 300-frame boot, and reached `core-loop` tests cheapest-first within `--budget` s (default 900). Only red-twice-on-head and green-on-base fails the lane; writes receipts under `artifacts/local/receipts/fast-*.json` (logs under `fast-*-logs/`). Gate ownership stays in [ORCHESTRATOR.md](ORCHESTRATOR.md). |
| `npm run play` / `scrapkeep` | Manages light-play-lane sketches across `git worktree list`: `list` / no arg (list sketches, branches, heads), `help`, `play <name>`, `test [name] [--jobs=N] [--repeat=N]`, `watch [name]`, and `shot <name> [out.png]`. `npm run sketch:test` aliases `play test`. |
| `npm run check:godot` | Reserved name for the native proof checks. Unavailable until the engineering handoff and engine-install authorization; no script exists yet. |
| `npm test` | Asserted simulation, progress storage, renderer geometry and tooling tests. Run `npm ci` first. A test that the box cannot exercise is skipped with its reason ([tests/preconditions.mjs](tests/preconditions.mjs)): as root, the two locked-write tests; in a shallow clone, the seven tests that read old commits (`git fetch --unshallow origin` lifts it). `SCRAPKEEP_WHOLE_TESTS=1 npm test` turns those skips into errors; the promotion run uses it ([GATE.md](project-guide/handoff/GATE.md)). |
| `npm run test:orchard:models` | Finite transforms, articulated tool geometry, and cockpit enclosure. |
| `npm run test:expedition` | Asserted outcomes for deterministic baseline expeditions. |
| `npm run probe:balance` | Exploratory baseline balance output. No assertions and no pass/fail quality claim. `test:balance` remains a compatibility alias. |
| `npm run check:build` | Built HTML and linked-asset HTTP checks. Build first. |
| `npm run test:browser` | Existing baseline replay; requires running Vite, Chromium, and an environment permitting browser automation. |
| `npm run test:leads` | Frozen lead-server tests in `tests/legacy/leads.test.js` against a temporary data directory. Legacy evidence only; not part of `npm test` or `npm run verify`. |
| `npm run test:leads:browser` | Built baseline signup checks using synthetic records and its own temporary server. Requires Chromium. |

Scope-to-command map. Run `npm run check:scope -- <base> <candidate>` on a candidate first. Documentation-only changes need `npm run check:docs` and `npm run check:project` and no build. A `tooling-no-build` change, confined to `scripts/*.mjs`, `tests/*.test.js`, `tests/fixtures/check-scope/*.json`, `package.json` scripts entries, configuration paths, and documentation, needs `npm test`, `npm run check:docs`, `npm run check:project` (plus the configuration scenario review when configuration paths are included) and no build. Browser-proof or build-requiring tooling changes need `npm run verify`, plus the browser checks below where UI paths changed. Configuration changes need `check:docs` and a scenario review against ORCHESTRATOR.md and AGENTS.md. A mixed set needs the union.

Set `CHROMIUM_PATH` for a non-default browser path and `GAME_URL` for the baseline replay's Vite origin. The supported interactive paths are:

- Baseline development `/?qa&quality=low`: **Run regression replay**. Baseline QA is excluded from production.
- Orchard development or production `/orchard.html?qa`: **Run DOM input replay**, **Run state fixtures**, and **Run input expedition**. Record them separately. Fixture screenshots stage state; the input expedition uses ordinary handlers with scripted precision. **Run 60-second bounded stress** stages durable enemies and the full build, then requires normal simulation, rendering and attack activity for sixty seconds. Its JSON records graphics identity, frame samples, simulation advancement and renderer counters. Keep the tab visible during replays.
- A normal URL: inspect start, gameplay, pause/help, results and restart after presentation changes. Test actual hardware before claiming controller or mobile support.

No browser session, human enjoyment, or performance benchmark is implied by `npm run verify`.

## Asset inspection

Use `npm run asset:inspect` before admitting an exported GLB or assembling parts from a model collection. It reads local files, counts actual exported geometry and checks an explicitly selected budget. Inventory is not approval. A budget pass does not prove engine import, visual quality or rendered performance. The tool does not change meshes or replace the sketch's Godot asset tests.

## Editing conventions

Use native JavaScript ES modules, two-space indentation, double quotes, semicolons, and `oxfmt` / `oxlint` on files you change. Avoid repository-wide formatting while fixing one issue. Keep functions and data near their actual callers; introduce shared code when both entries need the same behavior, not merely similar names.

Gameplay constants belong in the simulation. Detailed values stay in code and the integration contract rather than being copied into every document. Encode invariants into static types, `assert(...)`, unit tests, or `npm run sketch:lint` rules rather than prose; comments survive only for unchangeable external Godot, OS, driver, or hardware quirks and machine-parsed headers (such as `# lint:` or test block markers). Add tests for a concrete failure or gameplay invariant, and name the behavior they establish.

Use an ADR for a durable module boundary, delivery/runtime choice, or data/asset ownership decision. Amend its status or supersede it when the decision changes. Product feature ideas go in the backlog first. The source-of-truth map prevents a new session summary from replacing accepted requirements.

## Handoff and version control

After a change, update its canonical docs, record executed checks and material limits, and update [STATE.md](project-guide/handoff/STATE.md) / [DECISIONS.md](project-guide/handoff/DECISIONS.md) as appropriate. BACKLOG.md owns definitions, not live status. The append-only [decision trail](docs/decisions.tsv) records meaningful choices, not every command.

The repository preserves local history beginning at baseline `4db9b31`. Andrew authorized the private GitHub repository `bananahana720/scrapkeep`, with `main` as the default branch (legacy wave stacking used `stage/alpha-w<N>`; ruling ep runs flat on `main`). [STATE.md](project-guide/handoff/STATE.md) records the live integration branch and [TRACKING.md](TRACKING.md) records the historical heavy-lane board. Inspect the current branch and worktree before editing; never infer them from a historical receipt. Commit reviewed changes before integrating, preserve owner work, and keep writing agents in disjoint worktrees. Experimental branches remain local unless separately authorized.

Keep `node_modules/`, `dist/`, secrets and disposable evidence untracked (see `.gitignore`). [Artifact retention](artifacts/README.md) describes the remaining artifact buckets.
