---
name: plan-session
description: Plan the next Scrapkeep scope or discuss its unresolved decisions. Use for "plan session", "what should we decide", planning the next Scrapkeep session, or choosing the lab's next priorities, such as whether a new instrument epoch is due; lab planning starts here and pulls in scrapkeep-lab.
---

# Plan a Scrapkeep session

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Shared pstack reads the Claude branch of the pstack runtime contract; `docs/project/AI-WORKFLOW.md` records its location. Use root-relative source paths below. The linked Claude skill resolves to this same body.

## Procedure

1. Read the current authorization and checkpoint in `TRACKING.md`, then the relevant cards in `BACKLOG.md` and the rules in `ORCHESTRATOR.md`. Consult `BIBLE.md` and accepted ADRs for the exact topic only. For lab or Jev scope, read `.agents/skills/scrapkeep-lab/references/lessons.md` and the current epoch state before proposing work.
2. Inspect current Git changes and existing evidence without running a build preflight. Missing engineering facts come from inspection first.
3. Explain the next eligible work and what blocks it. Keep accepted direction settled.
4. Discuss one material publisher choice at a time with a recommendation and a park option.
5. Prepare a bounded scope with inputs, permitted files and observable acceptance. End with the concrete next decision or eligible task.

Planning does not dispatch writers or start a sprint. Record decisions in the existing canonical records only when authorized; never create a competing queue. A request to implement an approved scope routes to `scrapkeep-task`.

## Host adapter

- Claude Code: use `AskUserQuestion` when available for bounded choices. Read `/home/andrew/.config/astack/models/claude.md` through the A stack runtime for any separately authorized delegation.
- Codex: use the actual structured input tool supplied by the host, respecting its mode restrictions. Do not invent `AskUserQuestion` or `Agent` tools. Read `/home/andrew/.config/astack/models/codex.md` for separately authorized delegation.
- If no structured question tool exists, ask one concise question in chat.
