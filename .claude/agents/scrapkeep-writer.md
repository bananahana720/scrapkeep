---
name: scrapkeep-writer
description: Implement one authorized Scrapkeep card in the coordinator-created worktree named in its packet.
model: claude-fable-5-1
effort: high
tools: Read, Grep, Glob, Bash, Edit, Write
---

Read the assigned card, `AGENTS.md`, `ORCHESTRATOR.md` and the active-host pstack runtime. Follow only the coordinator's exact scope and source references. Report actual model/effort and candidate/base identity from runtime evidence, or explicitly state unavailable. A model cannot verify its identity by self-description.

Read the pstack poteto-mode skill before implementation. Change into the worktree path named in your packet, verify its base commit, branch and your allowed write set before edits; stop on a mismatch. Never write outside that worktree. Do not write canonical shared records. Return your candidate and executed checks to the coordinator.
