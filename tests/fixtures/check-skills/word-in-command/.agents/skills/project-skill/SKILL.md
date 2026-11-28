---
name: project-skill
description: "Run the demo lab. Use for lab, harness or gate work."
---

# Run the demo lab

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root.

## Procedure

1. Run `npm run check:skills` before committing a change. (DEV-01)
2. See `scripts/play.mjs` for the launcher. Card JL-01 and event EV-0001 cover the setup.
3. Run it with `node scripts/does-not-exist.mjs` (B4: a path-shaped word inside a command is now checked).

## Host adapter

- Claude Code: use structured questions when available.
- Codex: use the host's own structured input tool.

## Lessons and updates

See [references/lessons.md](references/lessons.md).
