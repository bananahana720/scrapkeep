# Developing Scrapkeep

Start with the [project desk](docs/project/README.md). The code map and decisions are in the [ADR index](docs/adr/README.md); the [orchard contract](docs/FIRST-BUILD-CONTRACT.md) owns detailed state and geometry conventions.

## Install and run

Use Node matching `package.json#engines` and the committed lockfile. The declared range follows the installed Vite requirement. This session ran Node 26.8.1; other supported versions have not been checked here.

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

This runs project checks, all Node tests, model invariants, the asserted baseline expedition check, a production build, and temporary-port HTTP checks for both entries and their linked assets. Each stage stops on failure. Logs, source hashes, and a machine-readable result go to `artifacts/local/verify/`. The check creates its own temporary HTTP server with capture disabled and closes it. It does not stop the user's server or run browser automation.

| Command | Use and limits |
| --- | --- |
| `npm run check:project` | Canonical file/link and package-lock metadata checks. It does not check remote URLs, Markdown anchors, or prove architectural correctness. |
| `npm test` | Asserted simulation, storage/API, and renderer geometry tests. |
| `npm run test:orchard:models` | Finite transforms, articulated tool geometry, and cockpit enclosure. |
| `npm run test:expedition` | Asserted outcomes for deterministic baseline expeditions. |
| `npm run probe:balance` | Exploratory baseline balance output. No assertions and no pass/fail quality claim. `test:balance` remains a compatibility alias. |
| `npm run check:build` | Built HTML and linked-asset HTTP checks. Build first. |
| `npm run test:browser` | Existing baseline replay; requires running Vite, Chromium, and an environment permitting browser automation. |
| `npm run test:leads:browser` | Built baseline signup checks using synthetic records and its own temporary server. Requires Chromium. |

Set `CHROMIUM_PATH` for a non-default browser path and `GAME_URL` for the baseline replay's Vite origin. In Codex, follow the available browser tool's control restrictions. The supported interactive paths are:

- Baseline development `/?qa&quality=low`: **Run regression replay**. Baseline QA is excluded from production.
- Orchard development or production `/orchard.html?qa`: **Run DOM input replay**, **Run state fixtures**, and **Run input expedition**. Record them separately. Fixture screenshots stage state; the input expedition uses ordinary handlers with scripted precision.
- A normal URL: inspect start, gameplay, pause/help, results and restart after presentation changes. Test actual hardware before claiming controller or mobile support.

No browser session, human enjoyment, or performance benchmark is implied by `npm run verify`.

## Editing conventions

Use native JavaScript ES modules, two-space indentation, double quotes, semicolons, and the installed Prettier on files you change. Avoid repository-wide formatting while fixing one issue. Keep functions and data near their actual callers; introduce shared code when both entries need the same behavior, not merely similar names.

Gameplay constants belong in the simulation. Detailed values stay in code and the integration contract rather than being copied into every document. Explain a non-obvious invariant in a comment; do not narrate routine code. Add tests for a concrete failure or gameplay invariant, and name the behavior they establish.

Use an ADR for a durable module boundary, delivery/runtime choice, or data/asset ownership decision. Amend its status or supersede it when the decision changes. Product feature ideas go in the backlog first. The source-of-truth map prevents a new session summary from replacing accepted requirements.

## Handoff and version control

After a change, update its canonical docs, record executed checks and material limits, and leave one concrete next action in the project desk/backlog. The append-only [decision trail](docs/decisions.tsv) records meaningful choices, not every command.

This environment currently exposes an unusable read-only `.git` placeholder. Do not fabricate commits or initialize a replacement to satisfy a workflow. The backlog tracks a normal-checkout handoff. In a real checkout, inspect status, review changes, and use that repository's branch/review conventions.

Keep `node_modules/`, `dist/`, secrets and disposable evidence untracked. [Artifact retention](artifacts/README.md) and [asset provenance](docs/project/ASSETS.md) describe the remaining buckets.
