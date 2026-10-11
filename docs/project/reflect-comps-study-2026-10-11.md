# Reflect: comps study session (CS-01 to CS-03), 2026-10-11

Andrew approved all five groups. Nothing below has been applied yet; the usage limit cut the session before the first edit. Resume by applying rows 1 to 12 in order, then commit `~/.config/astack` and this branch.

## Anchors located (runtime.md line numbers as of fa0810c-era astack HEAD)

- Skill selection, last sentence about `astack:a-mode`: line 19
- Conductor cycle, Review bullet ("not the smallest fix"): line 32
- Escalations paragraph ("accept a sound recommendation in one line"): line 41
- The brief: CONTEXT 60, ACCEPTANCE 61, TIMEBOX 63, FORBIDDEN 64
- Local work and external actions, first paragraph (`git branch --contains`, "run your own full suite on a scratch merge"): line 102
- Host environment constraints, "Steps that need Andrew's hands" bullet: line 116
- reverse-engineer SKILL.md: frontmatter lines 1-5 (description, when_to_use), "Engines on this machine" paragraph line 20, Run section line 22, Boundaries line 36; `references/` holds only `rea/`

## Accepted edits (apply all)

| # | Problem | Proposal | Routing |
|---|---|---|---|
| 1 | Canon amended on a main-based branch; receiver's branch taken from a session listing; zero-delta probe and usage-error `merge-tree` treated as a pass | Widen "find the receiver's live branch" to fire before any owner decision or amendment to a shared canonical document, not only before sending; name the method (`git worktree list`, `git branch --sort=-committerdate`, its events); "0 commits ahead of main" on a live branch, or a probe that exits with a usage error, is stale or INCONCLUSIVE, never a pass | runtime.md § Local work and external actions, line 102 |
| 2 | Structural gate after second FAIL was tuned on its own candidate, shipped as "must print 0 hits", then flooded on public vocabulary | After the second-FAIL sentence: the structural change is itself a candidate, ships with a planted positive control that fires before its zero is trusted, a held-out negative (public-vocabulary corpus for a prose gate), and lands in the repo's check path, not scratch; a gate that cannot separate the two is a review aid and labelled so in the brief | runtime.md § Conductor cycle, Review bullet, line 32 |
| 3 | Posture ban only on the final artifact failed three cards; upstream extraction brief said enums are the deliverable; sibling notes disagreed on shared numbers | CONTEXT: quote exact canon lines and owner decisions each unit may touch, verified before spawn; copy any ban on the final artifact into every upstream brief whose output feeds it. ACCEPTANCE: for sibling units from one source, name the owner note per shared number; carry every failure class from a prior sibling's review as a checkable line. A correction sent to a running writer is logged as a brief defect | runtime.md § The brief, lines 60, 61, 64 |
| 4 | Shell-less reviewer resumed with no SHA, diff receipt or gate receipts; acceptance commit never reviewed | A resumed review pass restates the new candidate SHA, diff receipt and verifier receipts as a fresh brief would; the commit that applies a FAIL's fixes is a new candidate that gets at least a verifier spot-check of the applied items | runtime.md § Escalations, line 41 |
| 5 | First hand-off misdescribed the receiver and carried a link | Message leads with the ruling the receiver must make (options, default), then numbered directions with their numbers, then branch locations; the scratch merge unions append-only registers, renumbers colliding IDs after the receiver's last, keeps the receiver's canon files untouched, lists every resolution as "for review, not admission" | runtime.md § Local work and external actions, after the scratch-merge sentence, line 102 |
| 6 | "Gap: needs human capture" shipped as a footnote while `assign_task` was unused | A human-only gap written into an accepted deliverable is filed as a task when the note is accepted | runtime.md § Host environment constraints, line 116 |
| 7 | Scouts needed six "stop and deliver" messages | TIMEBOX names the stop condition as questions answered or evidence found, with the time cap as outer bound | runtime.md § The brief, TIMEBOX, line 63 |
| 8 | "REA" and "decompile" said, skill named, never loaded; catalog lists it with no description | Beside the a-mode line: "reverse engineer", "decompile", "REA", "what's inside this install" load `astack:reverse-engineer` by path before any tooling. Tune description and `when_to_use` with "game install, Steam, Unity, Unreal, IL2CPP, asset bundle, pak" | runtime.md § Skill selection line 19; reverse-engineer SKILL.md frontmatter |
| 9 | Project task skill never fired for in-session cards; L-size card rejected by check:docs; check:scope never run | Description adds "including research or documentation cards the coordinator drafts with Andrew in-session"; scrapkeep-verify adds "and the receipts a reviewer gates from" | `.claude/skills/scrapkeep-task/SKILL.md`, `.claude/skills/scrapkeep-verify/SKILL.md` (symlinks into `.agents/skills/`), this branch |
| 10 | Cost quoted from the hardest layer ("days") instead of the layers holding design data | Run step 2: clone the install first, probe each container layer (data tables, asset bundles, level archives, code) in one scout wave, estimate per layer; design data rarely lives in compiled logic | reverse-engineer SKILL.md § Run step 2 |
| 11 | "Paraphrase identifiers" did not stop enum sets with counts; resculpting a rip proposed as laundering; user email in a third-party UA header | Boundaries: decoded enum members and string values are the target's content, so notes give counts by unnamed tier or type and never two or more members of one shipped set, including the coordinator's own index rows; a ripped asset stays a derivative after resculpting, measured statistics are data, the clean path is CC0 bases reshaped to measured proportions, any kept install clone is recorded as an exception outside the study folder; no user identifiers in requests to third parties | reverse-engineer SKILL.md § Boundaries and § Run step 7 |
| 12 | Engine list covers Ghidra, .NET, Electron, APK only; Unity Mono, IL2CPP and UE IoStore each cost hours | New `references/game-engines.md` linked from the engines paragraph: Unity Mono (ILSpy via the installed .NET runtime from the nupkg, `dotnet ilspycmd.dll -p -o <out> -r <Managed> <dll>`; UnityPy TypeTreeGenerator with exact version string plus the `*_monoscripts_*` bundle; pick Addressables bundles by name). Unity IL2CPP (check `global-metadata` magic `AF 1B B1 FA` before dumping, `RequireAnyKey: false` for headless, per-file prefix before `UnityFS` found by header-size arithmetic, gzip TextAssets by magic, vertex count 0 so budget by triangles). Unreal IoStore (retoc via `cargo install --git https://github.com/trumank/retoc --locked`, binary in `~/.cargo/bin` not on PATH, `retoc unpack` has no filter, scope with `to-legacy --version UE4_26 --no-shaders --no-script-objects -f <substring>`, no .usmap when no package has flag 0x2000, encrypted pak index does not block utoc/ucas). DataTables: drop designer header rows (key starts `=` or `-----`) and add a Section column before any count. Wikis: `api.php?action=query&list=allpages&aplimit=max` before guessing titles. Clean-room check posture from row 2. Re-verify flags at write time | reverse-engineer SKILL.md § The tool plus new reference |

## Backlog (mechanisms, not prose)

1. Enum gate into the repo check path: `scripts/check-cleanroom.mjs` wired into `check:docs` for `research/comps/**`, planted positive fixture that must fail, public-wiki vocabulary exemption, run over CS-01 and CS-02 too. Scrapkeep card.
2. Shared-register branch check at scrapkeep-task admission: for each register the card writes (BIBLE.md, BIBLE_DECISIONS.md, adr/, docs/decisions.tsv, TRACKING event numbering), name the branch holding its newest accepted copy; `check:docs` could refuse a Bible/ADR edit whose merge-base with the newest `cand/*` predates that file's last commit there. Scrapkeep card; also resolve TADR-011 vs BD-15.
3. Reviewer packet and acceptance-commit spot-check in ORCHESTRATOR § Handoff and review and scrapkeep-task step 8. Scrapkeep card.
4. Card size hint before drafting: template says "Size S or M; split an L before dispatch"; `check:docs` prints the split hint. Scrapkeep card.
5. Rewrite `docs/project/ASSETS.md` lines 22-23 once: study copies and derived data stay under `~/scratch/game-study/` until the study closes; install clones deleted at card acceptance unless an exception is recorded. Scrapkeep card.
6. Catalog shows no description for most astack skills though frontmatter matches grill-me's: check `claude plugin details astack` and the listing budget; add a `verify.py` check. astack repo.
7. Wall on the user's email or identifiers in `curl`/`wget` header args to non-local hosts. hooks repo.
8. `check:docs` flags "gap:" or "needs human" lines in `research/comps/**` for assign_task at acceptance. Scrapkeep card.
9. `astack:scout` definition: stop when the named questions are answered or sources exhausted; report partial on the time cap. astack repo.

## Rejected (already covered or not decision-changing)

Verdicts already define INCONCLUSIVE; ORCHESTRATOR.md:118 already names the heavy lane for Bible edits; ORCHESTRATOR.md:7 already says read the Bible section first; scrapkeep-reviewer-medium already requires a diff receipt; Verdicts already say a later fix is a new candidate. Delegate count correction and praise for plan-time questions: measurements, no edit. The "surviving citation defect" was checked: the Roboquest notes cite PLAYTEST-LOG line 83, which holds the principle; already fixed.

## Reviewer runtime

Judgment Fable, tooling Opus, divergent Fable, synthesizer Fable. Transcript under `~/.claude/projects/-home-andrew-Projects-scrapkeep--claude-worktrees-steam-game-asset-decompile-907d39/da91c556-518c-4a8e-997a-21a3d8047234.jsonl`, 60 delegates plus 23 resumes.
