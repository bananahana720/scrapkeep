# Scrapkeep project instructions

Read [the project desk](docs/project/README.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before substantive work. Personal pstack preferences and host policy still apply. This file contains only project conventions.

- Treat `docs/DISCOVERY.md` as publisher direction, `docs/project/REQUIREMENTS.md` as its scope map, and `docs/project/BACKLOG.md` as the ordered open work. A proposal is not approval to build.
- Preserve both entries, `/` and `/orchard.html`, until their consolidation is an explicit decision. Their simulations and QA modes differ.
- Keep orchard combat state in `src/orchard/simulation.js`, rendering in `scene.js`, procedural models in `models.js`, and input/UI orchestration in `main.js`. Consult the integration contract before changing interfaces.
- Damage and telegraphs must consume the same committed geometry. A visually convincing animation is insufficient evidence of a correct hitbox.
- Use the locked dependencies and existing free local tools. No dependency upgrade, engine migration, paid service, deployment, or new full-game feature is implied by housekeeping.
- Run `npm run verify` for a completed change. This checks local project structure, asserted tests, models, and production serving. Use the browser checks in CONTRIBUTING when UI, input, camera, or render behavior changes; the command does not establish those.
- Writing agents use disjoint worktrees by default; separate staging copies are the fallback only on a host without Git. The coordinator admits changes serially. All Codex agents use the configured Astra roles.
- Keep evidence scoped to the version and method actually checked. Write disposable outputs under `artifacts/local/`; preserve named historical build evidence. See `artifacts/README.md`.
- Update the relevant ADR when a durable decision changes, and the backlog when an item is resolved. Keep one canonical record per concern. No task, reminder, or persistent memory is created by a project note.
