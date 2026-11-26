---
name: plan-session
description: Plan the next Scrapkeep scope or discuss its unresolved decisions. Use for "plan session", "what should we decide", or planning the next Scrapkeep session.
---

# Plan a Scrapkeep session

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

## Procedure

1. Read `project-guide/handoff/STATE.md` and `project-guide/handoff/DECISIONS.md`, then the relevant cards in `BACKLOG.md` and the rules in `ORCHESTRATOR.md`. Consult `BIBLE.md` and accepted ADRs for the exact topic only.
2. Inspect current Git changes and existing evidence without running a build preflight. Missing engineering facts come from inspection first.
3. Explain the next eligible work and what blocks it. Keep accepted direction settled.
4. Discuss one material publisher choice at a time with a recommendation and a park option.
5. Prepare a bounded scope with inputs, permitted files and observable acceptance. End with the concrete next decision or eligible task.

Planning does not dispatch writers or start a sprint. Record decisions in the existing canonical records only when authorized; never create a competing queue. A request to implement an approved scope routes to `scrapkeep-task`.

## Host adapter

- Claude Code: use `AskUserQuestion` when available for bounded choices. For any separately authorized delegation, AGENTS.md rule 11 names the workers; pstack's own role models are in `~/.claude/rules/pstack-models.md`.
- Codex: use the actual structured input tool supplied by the host, respecting its mode restrictions. Do not invent `AskUserQuestion` or `Agent` tools. AGENTS.md rule 11 names the workers for separately authorized delegation.
- If no structured question tool exists, ask one concise question in chat.
