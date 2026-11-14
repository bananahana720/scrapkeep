---
name: read-board-without-gh-api
description: "Read board #241 and PR comments with gh issue view / gh pr view --json, never inline gh api, which prompts Andrew every time"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 99053a69-80bd-4be5-8d1c-7c0c8c13e9bc
  modified: 2026-10-23T14:26:30.821Z
---

Read the wave board and PR threads with read-only `gh` subcommands, not `gh api`: `gh issue view 241 -R bananahana720/scrapkeep --json comments --jq '.comments[-N:][] | .createdAt+" "+.body'` and `gh pr view <n> --json comments`. Comment ids come from `.url` in that JSON.

**Why:** `gh api *` sits in the settings "ask" list, so each inline call raised an approval prompt; Andrew asked on 2026-10-23 to stop that.

**How to apply:** use gh issue/pr view for every board read. Scripts run as one command (the watcher) may keep gh api inside them. Related: [[cloud-lanes-github-bus]].
