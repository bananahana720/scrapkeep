# JL-30c-A1 review (Opus 5.5, routine; verbatim)

## Verdict: FAIL

**Evidence level:** static source review of the candidate files, plus receipts the writer or coordinator supplied under `/home/andrew/Projects/scrapkeep-wt-JL-30c/artifacts/local/tasks/JL-30c/`. I had no shell, so I ran nothing. I did not verify the head SHA with git. `f087d31` comes from the writer receipt `README.txt:1`.

**Runtime:** the system prompt states Opus 5.5 (`claude-opus-5-5`). `CLAUDE_EFFORT` was not available to me.

All paths below are under `/home/andrew/Projects/scrapkeep-wt-JL-30c/` unless stated otherwise.

## Blocking findings

**B1. The § 4d changelog check is missing.** DESIGN.md:171 says the check verifies that `## Changelog` exists and that the newest row's date is not earlier than a retracted lesson's `overturned_by` date. `scripts/check-skills.mjs` never mentions "Changelog" (read in full, lines 1-718). No test or fixture covers it.

**B2. Check 5 (CLI verbs) never checks a verb.**
- `scripts/check-skills.mjs:353-369` warns only when nothing is exported. When `verbs`, `LAB_VERBS` or `LAB_SUBVERBS` is exported, there is no else branch, so the check falls silent and still validates nothing.
- No code pulls `scrapkeep <verb>` citations out of the skills.
- DESIGN.md:147 says verbs are "checked against" the lists. BACKLOG JL-30 DoD 2 (`/home/andrew/Projects/scrapkeep-wt-JL-coord/BACKLOG.md:6140`) requires flagging a cited command that no longer exists.
- Today the warning is honest. The trap arrives on the first export, when the warning disappears and nothing replaces it.
- One complication for a real fix: the skill cites `scrapkeep gate`, `stats` and `dash`. Those route through `labRoute` (`scripts/play.mjs:827`), not the `verbs` array at `:889`, so a naive comparison would produce false positives.

**B3. Parts of the § 4b item 7 ledger rules are missing or pass vacuously.**
- The prefix rule (RML- only in the portable ledger, SKL- only in the project ledger) is not enforced. `parseLessons` (`:442`) accepts either prefix in any file.
- If `## Lessons` is missing (`:434-435`), the function returns `[]` with no finding.
- A malformed lesson header, such as a missing `·`, is silently skipped (`:442`) instead of flagged.
- Lesson citations are recognised only as a single `(RML-nn)` (`:568`). `(SKL-15, SKL-32)` would not match.

**B4. Skipping every backtick token that contains whitespace goes beyond the packet and hides dead paths inside commands.**
- `:287` skips all such tokens, and the fixture writes this in as intended behaviour: `tests/fixtures/check-skills/not-flagged/.agents/skills/scrapkeep-lab/SKILL.md:19` holds `node scripts/does-not-exist.mjs`, and the test at `tests/check-skills.test.js:175-180` asserts it is not flagged.
- The packet's skip list (`<...>`, fences, globs, quoted schema, URLs, `:line`) contains no whitespace rule.
- DoD 2 targets exactly this kind of citation. For example, `node scripts/play.mjs` (JL-30b `scrapkeep-lab/SKILL.md:18`) is checked only because the path also appears bare on line 17.
- The whole-token `<` skip at `:288` has the same effect on `node scripts/lab/godot-launch.mjs <scenario> …` (`:17`).
- Fix: split on whitespace and check each path-shaped word, skipping only the words that contain `<`, `*` or a URL scheme.

**B5. The candidate's head fails the card's named verification command.**
- Per the writer receipt `check-docs.txt:12-17`, `npm run check:docs` exits 1. The only failures are the new skills stage's `models/claude.md` and `models/codex.md` at `.agents/skills/plan-session/SKILL.md:22-23`.
- JL-30 "Verification and evidence" (BACKLOG:6144) requires `npm run check:docs`.
- My inference: the base passed check:docs, because every other line in that receipt is INFO.
- Neither JL-30a nor JL-30b fixes plan-session (receipts `check-skills-JL-30a.txt:1-2`, `check-skills-JL-30b.txt:1-2`). As delivered, the integrated result stays red. See finding 2 under the false-positive review below.

## Non-blocking notes

- **N1. Frontmatter.** The verb test (`:192-203`) accepts any capitalised word not on a nine-word blocklist, so `Scrapkeep's …` or `Godot …` pass. Single-quoted descriptions (`:184` strips only `"`), folded or literal YAML (`>`, `|`) and CRLF files (`:155`) produce misleading failures.
- **N2. Archived events are not consulted.** EV ids are checked against TRACKING rows only (`:378`), as the packet specifies. `docs/project/tracking/EVENTS-0001-0057.md` exists, so a skill that cites EV-0001 to EV-0057 would be a false positive. It is latent: no current skill cites those.
- **N3. The result depends on the environment.** JL-30b `scrapkeep-lab/references/lessons.md:136` cites `artifacts/local/`, which is gitignored (`.gitignore:7`). It passes in worktrees that contain the directory and fails in a fresh clone.
- **N4. Check 5 runs another checkout's code.** It dynamically imports `scripts/play.mjs` from `--root` (`:342`), so `check:docs --root <other>` executes that checkout's module top level. `main` is guarded at `scripts/play.mjs:1027`, so no CLI run happens here. Reading the source statically is safer and is what the design's grep fallback implies.
- **N5.** `checkSkillsStage` calls `spawnSync` without a timeout (`scripts/check-docs.mjs:726`), so a hang would hang `check:docs`.
- **N6.** A missing TRACKING or BACKLOG becomes a failure finding with exit 1 (`:635-638`). DESIGN.md:152 says exit 2 for unreadable input.
- **N7.** The portability scan covers only `SKILL.md` and `references/*.md` (`:125-150`), not `reactive-model-loop/**` as § 4b item 8 states. That covers all current content.
- **N8. Anchored paths.** A token like `docs/x.md#heading` would be a false positive, because only `:line` suffixes are stripped (`:276`, `:292`).
- **N9.** The grepped usage string includes template-literal source text (`check-skills-own.txt:3`). Cosmetic.
- **N10. Test coverage and receipts.**
  - Missing tests: frontmatter name or description failures, the >150 warning, a link that is not a symlink, a link to the wrong target, an invalid status, an uncited lesson id, and exit 2 on an unknown flag.
  - The test title at `tests/check-skills.test.js:182` says default mode does not print JSON, but nothing asserts it.
  - There is no red-first receipt under `artifacts/local/tasks/JL-30c/`.
- **N11. The JL-30b receipt looks stale.** `check-skills-JL-30b.txt:3` reports a backticked `SKILL.md` at the RML ledger line 3, but the current `/home/andrew/Projects/scrapkeep-wt-JL-30b/.agents/skills/reactive-model-loop/references/lessons.md:3` has no backticks. The receipt probably predates JL-30b's current tree. The coordinator's JL-coord copy still has the backticks.

## The nine checks

| # | Check | Location | Status |
| --- | --- | --- | --- |
| 1 | Frontmatter | `:154-204` | Present, weak (N1) |
| 2 | Link | `:228-269` | Correct. `lstat`, then `realpath` compared on both sides; the dangling case is handled |
| 3 | Paths | `:278-304` | Present. Skip rules as packeted, plus the over-broad whitespace skip (B4). Fences blanked (`:95-104`); absolute and `~/` paths skipped (`:293`) |
| 4 | npm | `:315-332` | Correct, including `npm test` |
| 5 | Verbs | `:336-370` | Stub (B2) |
| 6 | Ids | `:392-426` | Correct per packet. Scans raw content, so an EV id inside a code fence is caught (`:394`). `JL-26-A2` resolves as JL-26. `JL-30a` has no BACKLOG anchor, so it would be flagged; that is correct, since sub-attempt ids are not cards |
| 7 | Lessons | `:432-578` | Partial (B1, B3). The origin-map requirement when `scrapkeep-lab` exists is correct (`:534-562`), and its heading matches JL-30b `lessons.md:179` |
| 8 | Portability | `:582-599` | Correct token list (`:17-34`), scoped to the portable directory |
| 9 | Size | `:206-223` | >150 warns, >250 fails. Correct |

**CLI contract:** `--root`, `--json`, exit 0/1/2, one line per finding plus a count, and the stated-limits line (`:10-13`, `:680-710`) all match the contract, apart from N6.

## False-positive review against the real skills

The writer reports three classes of finding:

1. **`npm run check:skills` missing in JL-30b.** A true finding. It resolves when JL-30c merges.
2. **`models/claude.md` and `models/codex.md` in plan-session.** Heuristic false positives. The files exist under `/home/andrew/.config/pstack/models/`, outside the repository.
3. **Bare `SKILL.md`** (JL-coord `reactive-model-loop/references/lessons.md:3`). A false positive. It refers to the skill's own file.

Classes 2 and 3 conform to the spec as written but will force prose rewording rather than catch staleness. DESIGN.md:57 says references resolve relative to SKILL.md.

Suggested fix: fall back to resolving against the citing skill's directory before failing, which also covers `references/x.md`. Have plan-session write the pstack path in `~/` form, which the check already skips.

The rest of the JL-30b lab SKILL.md paths are root-relative and pass (receipt).

## Integration, tests and style

**`check-docs.mjs` integration** (`scripts/check-docs.mjs:716-762`, `:774`, `:792`):
- It skips cleanly when there is no `.agents/skills` (`:725`).
- Failures fold in as `skills` with the original file:line and `[check]` prefix. Warnings become INFO.
- Non-JSON output or a null status becomes an explicit failure.
- Performance: each fixture run takes about 55-120 ms (`npm-test.txt:79-93`). I infer that is acceptable for `check:docs`.

**Tests** (`tests/check-skills.test.js`):
- Hermetic: each fixture is copied into an `mkdtemp` directory and removed in `finally`.
- Symlinks are created after the copy, so none is committed and there is no `fs.cp` rewriting (`:13-27`). That is correct.
- Each failing case asserts the named check and its message token.
- 15/15 pass per `npm-test.txt:79-93`, and the suite reports 656 passing with 0 failing (`:669-677`).
- `npm run verify` passes (`verify.txt:24`). check:scope classifies the change as tooling and requires only `npm run verify` (`check-scope.txt:6-31`).

**Style:** Node built-ins only (`scripts/check-skills.mjs:1-3`). The `Findings` class with `fail`/`warn`, the `exists` helper and the output format mirror check-docs.

## Required for attempt 2

- Implement the changelog and overturn-date check (B1).
- Make check 5 compare cited verbs against a statically read list that includes the lab-routed verbs, or warn unconditionally until it does (B2).
- Add the ledger prefix rule, and report a missing `## Lessons` heading and malformed lesson headers (B3).
- Check path words inside commands (B4).
- Get `check:docs` green on the integrated head: add skill-relative resolution and have the coordinator reword plan-session:22-23 (B5).
- Add a test for each of these.
