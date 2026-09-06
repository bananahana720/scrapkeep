---
name: plan-session
description: Plan the next Scrapkeep scope or discuss its unresolved decisions. Use for "plan session", "what should we decide", or planning the next Scrapkeep session.
---

# Plan a Scrapkeep session

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `docs/project/README.md` and `/home/andrew/.config/pstack/runtime.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Read the current authorization/checkpoint in `TRACKING.md`, relevant cards in `BACKLOG.md` and `ORCHESTRATOR.md`. Consult `BIBLE.md` and accepted ADRs for the exact topic. Inspect current changes without running a build preflight.

Explain the next eligible work and what blocks it. Keep accepted direction settled. Discuss one material publisher choice at a time with a recommendation and a park option. Missing engineering facts come from inspection first. Prepare a bounded scope with inputs, permitted files and observable acceptance.

Planning does not dispatch writers or start a sprint. Record decisions in the existing canonical records only when authorized; never create a competing queue. A request to implement an approved scope routes to `scrapkeep-task`.

## Host adapter

- Claude Code: use `AskUserQuestion` when available for bounded choices. Read `models/claude.md` through the pstack runtime for any separately authorized delegation.
- Codex: use the actual structured input tool supplied by the host, respecting its mode restrictions. Do not invent `AskUserQuestion` or `Agent` tools. Read `models/codex.md` for separately authorized delegation.
- If no structured question tool exists, ask one concise question in chat. End with the concrete next decision or eligible task.
