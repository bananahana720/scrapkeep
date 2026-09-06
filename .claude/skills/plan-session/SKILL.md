---
name: plan-session
description: Run the Scrapkeep planning protocol. Use for "plan session", "planning mode", "start the next session", or "what should we decide".
---

# Plan session

Read [docs/project/PLANNING.md](../../../docs/project/PLANNING.md) in full and follow it phase by phase. That document is canonical. This skill only maps its host-neutral steps to Claude Code tools.

| Protocol step | Claude Code tool |
| --- | --- |
| Preflight commands (`git status --short`, `npm run verify`) | Bash |
| Present one decision with a recommendation and 2 to 4 options | AskUserQuestion, one call per decision, "Park it" always an option |
| The Phase 2 go/no-go question | AskUserQuestion with go, revise, and park |
| Append a `docs/decisions.tsv` row or edit the register | Edit |
| Spawn a writer | Agent with `isolation: "worktree"`, model from the `feature, refactoring` role in the host model file named by `/home/andrew/.config/pstack/runtime.md` |
| Spawn the fresh reviewer | Agent without isolation, read-only, model from the `judgment and prose` role |
| Admit a lane and run the gate | Bash, `git merge` then `npm run verify`, one lane at a time |

Rules that hold across every phase.

- Do not start Phase 3 before the go row exists in `docs/decisions.tsv`.
- Do not ask Andrew anything during Phase 0.
- Do not push, publish, or deploy. Do not create a scheduled task, memory, or reminder.
- Every brief uses the poteto template verbatim. Every reviewer prompt carries the panel paragraph verbatim.

End each phase with one concrete next action in chat.
