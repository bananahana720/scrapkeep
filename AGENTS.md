# Scrapkeep project instructions

Read [the project desk](docs/project/README.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before substantive work. Personal pstack preferences and host policy still apply.

- `BIBLE.md` and accepted `adr/` records own game and production direction. `BACKLOG.md` owns task definitions, `TRACKING.md` owns live execution and questions, and `ORCHESTRATOR.md` owns assignment, isolation, review and integration. Read the task's exact sources; a proposed sprint or ready card is not authorization to start it.
- Use `plan-session` for planning, `scrapkeep-task` for authorized cards and `scrapkeep-verify` for artifact-specific verification. Both apps share the canonical bodies under `.agents/skills/`.
- Preserve `/` and `/orchard.html` as separate browser proofs until consolidation is explicitly approved. Their tests do not qualify the future native game.
- Keep orchard combat state in `src/orchard/simulation.js`, rendering in `scene.js`, procedural models in `models.js`, and input/UI orchestration in `main.js`. Consult the lightning integration contract before changing interfaces. Damage and telegraphs consume the same committed geometry.
- Use locked dependencies and existing free local tools. Housekeeping does not authorize dependency upgrades, engine migration, new game features, paid services or deployment.
- For completed browser-proof code changes, run `npm run verify` and the applicable browser checks in CONTRIBUTING. For documentation/configuration-only work, use scoped structure, link and behavioral checks; do not run builds under a no-build scope. Native checks come from the approved engineering handoff, not guessed commands.
- Writing agents use disjoint worktrees with verified base identity. The coordinator alone admits changes and writes canonical execution records. Follow ORCHESTRATOR's scoped prose-staging exception. Codex uses configured Astra roles; Claude uses the project agent definitions, which pin Opus 5 for writing, Sonnet 5 for lookup and Fable 5.1 medium for consequential review. Read the active host model map, check actual model/effort, and report substitutions as blockers.
- Save disposable evidence under `artifacts/local/`; preserve historical evidence and owner changes. Report the checked version and method. Automated play does not establish human feel or physical hardware support.
- Update the relevant ADR when a durable decision changes. Keep definitions in BACKLOG and execution state in TRACKING. A project note creates no reminder, scheduled work or persistent memory.
