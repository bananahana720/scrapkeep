---
name: project-skill-wrong-name
description: "Run the demo lab. Use for lab, harness or gate work."
---

# Run the demo lab

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root.

## Procedure

1. Run `npm run check:skills` before committing a change. (DEV-01)

## Host adapter

- Claude Code: use structured questions when available.
- Codex: use the host's own structured input tool.

## Lessons and updates

See [references/lessons.md](references/lessons.md).
