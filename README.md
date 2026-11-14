# Resume Scrapkeep from a new account

1. Connect GitHub on the new account to bananahana720/scrapkeep (private). Code, stages and wip/ branches are there (git/MANIFEST.md); the repo's project-guide/handoff/ (START-HERE.md, STATE.md, ROADMAP.md, DECISIONS.md) is the source of truth.
2. Create a claude.ai project, paste project-instructions.md into its instructions, and upload the shared folder from branch `project-files-export-2026-11-14` (start with its INDEX.md).
3. Put memory/project-scrapkeep/*.md into the new project's memory (on this PC it already lives at ~/.claude/projects/-home-andrew-Projects-scrapkeep/memory/).
4. Read threads/THREADS.md for the 13 open threads and the 10 open PRs (live list at its end); restart those as new threads.
5. Republish the pages under artifacts/ (Library, Roadmap, Sitting Sheet, Decisions register) as new artifacts; artifacts/INDEX.md lists the old links, which only the old account can open.

## Where this folder lives

- On GitHub: branch `account-export-2026-11-14` holds everything here except `library/` and the generated-output tarball. Fetch it on any machine with `git fetch origin account-export-2026-11-14`.
- On this PC: /home/andrew/Projects/scrapkeep-account-export/.

## What is in it

- `git/`: MANIFEST.md (what was pushed, what stays local). The generated-output tarball stays on this PC only.
- `library/` (PC only): a partial byte copy of the shared folder, 1,168 of about 1,970 files. The full copy is the `project-files-export-2026-11-14` branch; use that one.
- `memory/`: project memory, a worktree memory folder, and three home-memory files the project memory links to.
- `threads/`: every thread with its state, summaries of the open ones, and the PR lists.
- `artifacts/`: the four key pages as files, plus links to all 38 project pages.
- `project-instructions.md`: the project's saved instructions, as of 14 Nov 2026.
