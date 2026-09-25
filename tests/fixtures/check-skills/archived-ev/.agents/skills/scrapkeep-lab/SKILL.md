---
name: scrapkeep-lab
description: "Run the demo lab. Use for lab, harness or gate work."
---

# Run the demo lab

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root.

## Procedure

1. Run `npm run check:skills` before committing a change. (SKL-01)
2. Event EV-0090 (N2: resolved via the archived events file, not TRACKING.md itself) covers the setup.

## Host adapter

- Claude Code: use structured questions when available.
- Codex: use the host's own structured input tool.

## Lessons and updates

See [references/lessons.md](references/lessons.md).
