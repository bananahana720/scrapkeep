---
name: isolated-worktree-gitignored-output-lost
description: "An isolation:worktree agent's gitignored output (artifacts/local) is deleted when its worktree auto-cleans; point output-only agents at ~/scratch"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 99053a69-80bd-4be5-8d1c-7c0c8c13e9bc
  modified: 2026-10-23T01:50:32.097Z
---

On 2026-10-23 a greybox agent spawned with `isolation: worktree` wrote all its stills, glbs, scripts and logs under `artifacts/local/` (gitignored). The worktree had no tracked changes, so the harness auto-removed it on finish and the whole 23-minute output was lost; only mojulo's own store (`~/.mojulo/data/outcomes/`) survived.

**Why:** worktree auto-clean keys on tracked changes and commits, not on ignored files.

**How to apply:** for agents whose deliverable is untracked output (renders, greyboxes, receipts), either spawn without worktree isolation and give an absolute output dir under `~/scratch/w<N>/`, or require a commit of the output. Related: [[worktree-isolated-session-writers]], [[tmp-tmpfs-quota]].
