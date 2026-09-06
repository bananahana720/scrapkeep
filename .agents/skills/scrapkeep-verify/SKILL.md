---
name: scrapkeep-verify
description: Verify a Scrapkeep artifact or change using its documented checks and evidence limits. Use for game verification, regression checks, playtest qualification or documentation/configuration validation.
---

# Verify a Scrapkeep artifact

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Shared pstack reads the Claude branch of the pstack runtime contract; `docs/project/AI-WORKFLOW.md` records its location. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Verification is scoped to the artifact; a passing unrelated suite cannot qualify it.

## Procedure

1. Read the task's acceptance criteria, the current authorization in `TRACKING.md` and `CONTRIBUTING.md`. Record the candidate identity (worktree, branch, head SHA, base SHA) before running anything.
2. Run `npm run check:scope -- <base> <candidate> [--no-build]`. It classifies the changed paths and prints the required commands for that scope. Do not add a build under a no-build scope.
3. Select the method row below for the artifact class `check:scope` reports. A mixed change takes every applicable row.
4. Run the named commands from the candidate worktree. Save each command, exit code and output under `artifacts/local/tasks/<task-id>/`, with the identity from step 1.
5. Report each check as pass, fail or skipped, with its method, version and limits. Send the report to the coordinator; only the coordinator admits the change and updates TRACKING.

| Artifact | Required method |
| --- | --- |
| Documentation or agent configuration | `npm run check:docs` (links, anchors, BACKLOG card completeness, TRACKING event sequence), `npm run check:project`, skill and agent frontmatter validation when touched, and scenario review of the changed contract. No game build for a documentation-only scope. |
| Browser-proof code | `npm run verify`; add CONTRIBUTING's browser checks for UI, input, camera or render changes. Preserve checks for both entries. |
| Native game | Read the accepted engineering handoff and task-specific command contract. If it is unavailable, report a blocker; `check:godot` is reserved until that handoff lands. Do not invent Godot commands or substitute browser tests. |
| Maintained native player | Read `tools/agent-player/README.md` and the task scope. Use the documented controller-free checks and bounded native trials only when authorized. Acquire a fresh lease/desktop identity. |

In Claude Code use supported shell and browser tools. In Codex use the host's available tool APIs and their control restrictions. The same checks and evidence meanings apply in both apps. A missing browser yields a browser-verification gap; successful HTTP serving is not browser behavior.

Distinguish static checks, staged fixtures, ordinary input replay, automated native play, human feedback and hardware/performance measurements. A screenshot or a model's success statement does not establish gameplay outcomes.
