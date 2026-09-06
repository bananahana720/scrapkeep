---
name: scrapkeep-verify
description: Verify a Scrapkeep artifact or change using its documented checks and evidence limits. Use for game verification, regression checks, playtest qualification or documentation/configuration validation.
---

# Verify a Scrapkeep artifact

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `docs/project/README.md` and `/home/andrew/.config/pstack/runtime.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Read the task's acceptance criteria and `CONTRIBUTING.md`. Inspect the actual candidate and current authorization before selecting commands. Verification is scoped to the artifact; a passing unrelated suite cannot qualify it.

| Artifact | Required method |
| --- | --- |
| Documentation or agent configuration | Local structure and link checks, route/skill validation when relevant, and scenario review of the changed contract. No game build for a documentation-only scope. |
| Browser-proof code | `npm run verify`; add CONTRIBUTING's browser checks for UI, input, camera or render changes. Preserve checks for both entries. |
| Native game | Read the accepted engineering handoff and task-specific command contract. If it is unavailable, report a verification blocker rather than inventing Godot commands or substituting browser tests. |
| Maintained native player | Read `tools/agent-player/README.md` and the task scope. Use the documented controller-free checks and bounded native trials only when authorized. Acquire a fresh lease/desktop identity. |

In Claude Code use supported shell and browser tools. In Codex use the host's available tool APIs and their control restrictions. The same checks and evidence meanings apply in both apps. A missing browser yields a browser-verification gap; successful HTTP serving is not browser behavior.

Save command results and source identity under `artifacts/local/`. Distinguish static checks, staged fixtures, ordinary input replay, automated native play, human feedback and hardware/performance measurements. Report failures/skips and their implications. A screenshot or a model's success statement does not establish gameplay outcomes. Send results to the coordinator; only the coordinator admits the change and updates TRACKING.
