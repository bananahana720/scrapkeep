---
name: plan-session
description: Plan the next Scrapkeep scope or discuss its unresolved decisions. Use for "plan session", "what should we decide", or planning the next Scrapkeep session.
---

# Plan a Scrapkeep session

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `GEMINI.md`, and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

## Procedure

1. Read `project-guide/handoff/STATE.md` and `project-guide/handoff/DECISIONS.md`, then the relevant cards in `BACKLOG.md` and the rules in `ORCHESTRATOR.md`. Consult `BIBLE.md` and accepted ADRs for the exact topic only.
2. Inspect current Git changes and existing evidence without running a build preflight. Missing engineering facts come from inspection first.
3. Explain the next eligible work and what blocks it. Keep accepted direction settled.
4. Discuss one material publisher choice at a time with a recommendation and a park option.
5. Prepare a bounded scope with inputs, permitted files and observable acceptance. End with the concrete next decision or eligible task.

Planning does not dispatch writers or start a sprint. Record decisions in the existing canonical records only when authorized; never create a competing queue. A request to implement an approved scope routes to `scrapkeep-task`.

## Host adapter

- Antigravity: `/plan-session`. Use `ask_question` for bounded choices, `research` for broad read-only exploration, and `GEMINI.md` / `AGENTS.md` Rule 11 for worker routing.
- Claude Code: use `AskUserQuestion` when available for bounded choices and `.claude/agents/` as Rule 11's fallback for any separately authorized delegation.
- Codex (GPT 6.2 Astra/Sol, rulings `ec`/`ee`/`ej`): limited to world 1 promise cards, QA passes, concept art, model drafts, and non-admitting second opinions; use the host's structured input tool when available.
- If no structured question tool exists, ask one concise question in chat.
