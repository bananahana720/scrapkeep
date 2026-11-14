---
name: worktree-isolated-session-writers
description: "A Scrapkeep session started inside a Claude worktree pins every agent's writes to the session's current worktree; coordinator-cut unit worktrees fail, use isolation worktree instead"
metadata:
  node_type: memory
  type: project
  originSessionId: f5d7ec2a-9e8b-47a6-95bf-2efe48b91870
  modified: 2026-10-10T22:23:09.918Z
---

When the desktop session runs inside an isolated Claude worktree (`.claude/worktrees/<name>`), a built-in guard refuses Write and Edit calls into any other worktree, and later also refuses Bash commands that use shell variables, `git -C` or compound chains. Measured 2026-10-10 in wave 13:
- Agents are pinned at spawn to whatever worktree the session is in. Path-based `EnterWorktree` from an agent cannot widen that.
- Coordinator-cut unit worktrees (`git worktree add` plus a packet naming the path) do not work. Opus writers stopped and left patches; Sonnet writers slipped through by writing with Bash.
- Design agents told to write into the candidate worktree wrote to the scratchpad instead.

**Why:** the ORCHESTRATOR pattern (coordinator cuts the worktree, writer works there) assumes writers can reach any path. The guard breaks that silently, and an hour of design work was lost before the cause showed.

**How to apply:**
- At session start, `EnterWorktree` with `path` into the candidate worktree (for example `scrapkeep-wt-cand-alpha-w13`) before spawning anything, so design agents can write it.
- Give implementation writers `isolation: "worktree"`. The writer runs `git reset --hard <candidate branch>` in its fresh worktree, links `node_modules`, imports Godot, works, and commits. The coordinator merges the branch.
- Workflow scripts persist under the session's project dir, which changes after `EnterWorktree`; resume from the new path.
- In the main session, edit files with Edit and Write, and run plain single commands with literal paths.

Related: [[alpha-coordinator-handoff]].
