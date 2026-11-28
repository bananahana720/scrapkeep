---
name: scrapkeep-verify
description: Verify a Scrapkeep artifact or change using its documented checks and evidence limits. Use for game verification, regression checks, playtest qualification or documentation/configuration validation.
---

# Verify a Scrapkeep artifact

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `GEMINI.md`, and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Verification is scoped to the artifact; a passing unrelated suite cannot qualify it.

## Procedure

1. Read the task's acceptance criteria, [STATE.md](../../../project-guide/handoff/STATE.md), and [CONTRIBUTING.md](../../../CONTRIBUTING.md) (`TRACKING.md` only for heavy-lane cards). Record the candidate identity (worktree, branch, head SHA, base SHA) before running anything.
2. Run `npm run check:scope -- <base> <candidate> [--no-build]`. It classifies the changed paths and prints the required commands for that scope. Do not add a build under a no-build scope.
3. Follow the required checks for the scope class `check:scope` reports: [ORCHESTRATOR.md](../../../ORCHESTRATOR.md#light-play-lane) owns the tiered gate rule for Godot game changes (`sketches/core-loop`), and [CONTRIBUTING.md](../../../CONTRIBUTING.md#verification) owns the CLI command definitions and scope-to-command map (documentation, agent config, browser-proof, and mixed scopes). A mixed change takes the union.
4. Run the named commands from the candidate worktree. Save each command, exit code and output under `artifacts/local/tasks/<task-id>/`, with the identity from step 1.
5. Report each check as pass, fail or skipped, with its method, version and limits. Send the report to the coordinator; only the coordinator integrates changes onto `main`.

In Antigravity use `run_command`, the `browser` subagent or Playwright for browser proofs, `godot_godot` MCP (with `stop_project` before commit), and `scrapkeep-visual-review` for multimodal inspection. In Claude Code use supported shell and browser tools. The same checks and evidence meanings apply across hosts. A missing browser yields a browser-verification gap; successful HTTP serving is not browser behavior.

A change proven with pictures (a board, a before and after pair, rounds until no improvement, frames on the Mac with no window) follows [references/picture-proof.md](references/picture-proof.md) (design choice).

When the acceptance criteria name something a player sees or presses, add a driven proof from the matching skill: `scrapkeep-verify-game` (the game from source), `scrapkeep-verify-build` (the packed Linux build) or `scrapkeep-verify-web` (the Sitting Kit and the preserved browser proofs). A driven proof adds to the rows above and replaces none of them.

Distinguish static checks, staged fixtures, ordinary input replay, automated native play, human feedback and hardware/performance measurements. A screenshot or a model's success statement does not establish gameplay outcomes. Automated lab play is not a feel verdict.
