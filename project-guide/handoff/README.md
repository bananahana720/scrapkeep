# Scrapkeep handoff pack (18 Oct 2026)

This pack moves Scrapkeep from Andrew's current project to a fresh project on his other account. The repo is the only thing both projects share. That's why this pack lives in it at `project-guide/handoff/`, with a copy in the old project's shared folder at `handoff/`.

## What Andrew does, in order

Caution first: pages, Claude Docs, threads, cards, memory and Remote Control sessions belong to the old account and do not move. Everything a new coordinator needs is in this folder.

1. On the new account, create the project. Use the name and description in [NEW-GOAL.md](NEW-GOAL.md).
2. Paste [NEW-INSTRUCTIONS.md](NEW-INSTRUCTIONS.md) (everything below its line) into the project instructions.
3. Attach the GitHub repo bananahana720/scrapkeep. If the new account's GitHub isn't connected, connect it first.
4. Paste [NEW-MEMORY.md](NEW-MEMORY.md) into project memory. If memory can't be pasted directly, the coordinator copies it in on its first turn.
5. Send the message in [BOOTSTRAP-PROMPT.md](BOOTSTRAP-PROMPT.md) as the first chat message.
6. On the PC, sign the Claude app in to the new account, so new Remote Control sessions can start in `/home/andrew/Projects/scrapkeep`.
7. Optional: share the old pages you still use (Library, Sitting Kit, design questions) from the old account, or let the new coordinator rebuild them. The list is in [LIBRARY.md](LIBRARY.md).

Before you leave the old project, let its open threads finish or park. Every open PR is listed in [STATE.md](STATE.md) with its head, so nothing is lost if a thread stops mid-work.

## Files

| File | What it holds |
| --- | --- |
| [START-HERE.md](START-HERE.md) | The one file the new coordinator reads first |
| [NEW-GOAL.md](NEW-GOAL.md) | Project name, one-line goal, description |
| [NEW-INSTRUCTIONS.md](NEW-INSTRUCTIONS.md) | Project instructions: the 13 Direction principles and how we work |
| [NEW-MEMORY.md](NEW-MEMORY.md) | Cleaned project memory, current truth only |
| [BOOTSTRAP-PROMPT.md](BOOTSTRAP-PROMPT.md) | First chat message for the new coordinator |
| [STATE.md](STATE.md) | Wave state, every open PR with its head, base reds, the promote-fast flow |
| [THREADS.md](THREADS.md) | Live threads at the move: role, owned PRs, what each waits on |
| [DEVICES.md](DEVICES.md) | The PC (4080 machine and music sessions, GPU sharing, reboot rule) and what the cloud can and can't do |
| [DECISIONS.md](DECISIONS.md) | The full decisions register, current to 18 Oct 04:42Z |
| [LESSONS.md](LESSONS.md) | Lessons and ways of working, 42 lessons |
| [RECONCILE.md](RECONCILE.md) | Conflicts with older decision records and how each was settled |
| [LIBRARY.md](LIBRARY.md) | Every old page, with status (private to the old account) |
| old-memory/ | Only in the old shared folder `handoff/old-memory/` (raw memory files, not committed). NEW-MEMORY.md is the cleaned version |
| [shared/](shared/) | Text files from the old shared folder that threads rely on: sitting watch list, attack id registry, card queue, what's left, tone and sound bibles, intent-check method and script, bot shard brief, placeholder breakdown, Waking stagger table, ambition map, alpha scope |

## Not carried over

- **Music and render files** (69 MB in the old shared folder `music/`). The music source of truth is PR #12, and the ACE stems are on the PC.
- **Gate receipts and red team runs** (`gate/`, `redteam/`). Each PR's receipt is a comment on the PR.
- **Uploaded images and pilot-paint stills.**

Keeping it current: until the move, the "Project library and lessons learned" thread keeps this folder in step with the register. After the move, the new project owns it.
