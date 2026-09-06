---
name: scrapkeep-task
description: Execute an authorized Scrapkeep task card with isolated work, independent review and serial admission. Use when asked to implement or continue an approved Scrapkeep card or bounded scope.
---

# Execute an authorized Scrapkeep task

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `docs/project/README.md` and `/home/andrew/.config/pstack/runtime.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Read `ORCHESTRATOR.md`, the exact `BACKLOG.md` card and `TRACKING.md` authorization, checkpoint and leases. Inspect Git state and the card's source sections. Missing authorization or prerequisite output blocks that card, even if its status says ready. A direct new scope request must be captured in the existing board before dispatch, without changing unrelated sprint authorization.

Use the matching pstack workflow for implementation. ORCHESTRATOR owns the assignment packet, concurrency, leases, review and acceptance; do not substitute an older pstack board or planning protocol. Keep the coordinator as the sole canonical record writer. Dispatch only bounded independent work with complete inputs.

## Host adapter and base identity

- Claude Code: use `scrapkeep-writer` for ordinary writes, `scrapkeep-explorer` for source inspection and `scrapkeep-reviewer` for independent artifact review. These agents pin the Claude model and role effort. For a role needing another supported effort, launch with an explicit supported agent definition; a prompt cannot change effort. Avoid built-in Explore/Plan or advisor defaults unless actual model and effort are verified to match policy.
- Claude's native worktree isolation may branch from the default branch instead of the coordinator's HEAD. Verify the resulting base and required inputs before edits. If it differs, stop that writer and create a worktree explicitly at the accepted revision, then launch the scoped session there. Never copy uncommitted owner changes wholesale to repair a missing base.
- Codex: create distinct worktrees explicitly at the accepted revision and use the available collaboration tool with the configured Astra model and effort. A task name alone provides no filesystem isolation.
- For either app, verify the explicit model/effort against the host map and the accepted launch arguments. Compare actual runtime metadata when exposed; a mismatch or rejected required model/effort blocks the lane. If the host exposes only accepted launch settings, disclose that observability limit without claiming backend identity; missing telemetry alone does not invalidate an otherwise verified artifact. Verify the actual worktree base and write scope before admission. Follow the existing prose-staging exception when applicable. A fresh reviewer remains read-only and never writes the board. The coordinator runs executable checks and supplies the exact artifact and evidence to review.

Use `scrapkeep-verify` for the candidate and integrated result. Admit one candidate at a time. Record failures and retain interrupted leases until the owner is confirmed stopped and its actual changes are inspected. Resume from TRACKING and artifacts, not a remembered PID or a chat summary. Report actual runtime identities and evidence limits.
