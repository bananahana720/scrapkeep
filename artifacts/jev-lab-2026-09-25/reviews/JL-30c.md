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


# JL-30c-A2 re-review (Opus 5.5, routine; verbatim)

## JL-30c-A2 re-review: `scripts/check-skills.mjs`

**Verdict: PASS+NOTES.** One condition applies. The candidate head still fails `npm run check:docs` by itself (receipt `A2-check-docs.txt:12-16`, exit 1, `plan-session/SKILL.md:22-23`). A1 split the B5 fix between the writer and the coordinator. The writer's half is present. The coordinator's half, the plan-session rewording, is in JL-30b (`/home/andrew/Projects/scrapkeep-wt-JL-30b/.agents/skills/plan-session/SKILL.md:22-23` now uses absolute `/home/andrew/.config/pstack/models/*.md`). So JL-30c must not be admitted ahead of JL-30b, and `npm run check:docs` must be rerun on the integrated head. If the coordinator expected the JL-30c head to be green on its own, B5 is still open and this becomes FAIL.

**Evidence level:** static source review only. I ran no commands. The head SHA c2ab07da comes only from the receipt `A2-README.txt:1`; I did not check it with git. Every test, verify and check-docs result below is labelled **[receipt]** because it rests on writer or coordinator files under `/home/andrew/Projects/scrapkeep-wt-JL-30c/artifacts/local/tasks/JL-30c/`.

**Runtime:** the system prompt states Opus 5.5 (`claude-opus-5-5`). `CLAUDE_EFFORT` was unavailable to me.

Paths below are under `/home/andrew/Projects/scrapkeep-wt-JL-30c/` unless given in full.

## Blocking findings
None within the candidate's scope. The integration condition above is the only gate.

## Non-blocking findings

- **F1. A bare filename with `:line` is never existence-checked.** At `scripts/check-skills.mjs:409` the `SCHEME` test (`:344`, `/^[a-z][a-z0-9+.-]*:/i`) runs before the `:line` strip at `:410`. `play.mjs:12`, `SKILL.md:22` and `BACKLOG.md:6140` all match the scheme test and are skipped. `scripts/play.mjs:1` is still checked, because the `/` breaks the match. This lets dead citations through but never produces a false alarm. Fix: strip `LINE_SUFFIX` first, or require `://`.
- **F2. Free-text regex for top-level verbs.** `:570-571` matches any lowercase `scrapkeep <word>` anywhere in any skill file, prose included and across newlines (`\s`).
  - False positives it would raise: prose such as "the scrapkeep repository" and paths like `…/Projects/scrapkeep is`. It would also flag `scrapkeep <sketch-name>`, even though a bare sketch name is a valid invocation (`scripts/play.mjs:888-894`).
  - Current content is clean: a multiline grep of JL-30b's skills finds only three `scrapkeep <verb>` hits (`scrapkeep-lab/SKILL.md:17`, `references/scenarios-and-arms.md:9`, `references/records-gates-pins.md:15`), all valid. JL-coord's skills have none.
  - Scoping the scan to backtick spans would make it safer.
- **F3. No warning when `scripts/play.mjs` is absent.** `:511` returns without a warning, which is the same silent pattern B2 was raised against. Mitigation: JL-30b `scrapkeep-lab/SKILL.md:17` cites `scripts/play.mjs`, so a rename would still be caught by the paths check.
- **F4. Some whitespace-split words give false positives.** Covered in section 3.
- **F5. A test title does not match its fixture, so one direction of the prefix rule is untested.**
  - The title at `tests/check-skills.test.js:328` says "an RML- id inside the lab skill's ledger".
  - The fixture `tests/fixtures/check-skills/wrong-prefix-scope/.agents/skills/reactive-model-loop/references/lessons.md:10` actually puts SKL-99 in the portable ledger, and the test asserts SKL-99.
  - So the RML-in-lab branch (`scripts/check-skills.mjs:793-802`) has no test.
- **F6. Frontmatter failure paths are partly untested.** Only a name mismatch and a missing description are tested. No test covers a description over 1024 characters or one that does not start with an allowlisted verb. The allowlist (`:45-53`) is stricter than the contract's "starts with a verb" (DESIGN.md:143), but a miss fails loudly with a named finding. All five real first words (Design, Run, Verify, Execute, Plan) are on the list.
- **F7. Changelog edge cases pass silently.**
  - A retracted lesson whose `Overturned by` field has no ISO date is skipped (`:741-742`).
  - A `## Changelog` section with no date rows passes unless a dated retraction exists.
- **F8. Packet discrepancy.** The packet says the red-first run was "19 pass / 47 fail". The receipt says 19 pass / 23 fail out of 42 (`A2-red-first.txt:43-46`).
- **F9. Possible add/add conflict at integration.** JL-30b already contains `/home/andrew/Projects/scrapkeep-wt-JL-30b/scripts/check-skills.mjs`, which carries A2 text ("Gitignore matching…"), and its `package.json:22` has `check:skills`.
  - If that copy differs from c2ab07d, merging the two branches will conflict.
  - The receipt `A2-check-skills-JL-30b.txt` does not say which copy of the script produced it.
  - I did not diff the two files (inference).

## 1. A1 items

| Item | Status | Fix | Proving test |
| --- | --- | --- | --- |
| B1 | Closed | `:713-757`, called at `:773`. Missing section fails; newest-row date is compared with the retracted lesson's Overturned-by date | test.js:278, :284 |
| B2 | Closed | Static parse at `:469-584`. A warning is raised when no list is found (`:521-547`) | :295 (bad top verb and bad sub-verb), :303 (valid verbs, including pipe-separated), :309 (warns and never fails) |
| B3 | Closed | Missing `## Lessons` fails (`:764-765`); malformed header fails (`:670-688`, `:766-772`); prefix scope in both directions (`:793-812`); multi-id citations (`:880-893`) | :316, :322, :328 (SKL direction only, F5), :338 |
| B4 | Closed | Each word is checked separately; only words containing `<`, `*` or a scheme are skipped (`:406-409`). The A1 fixture line `node scripts/does-not-exist.mjs` has been removed from `not-flagged` | :347 |
| B5 | Writer half closed | Skill-relative fallback at `:415-416`. Candidate still red on its own; see the condition at the top | :357 |
| N1 | Closed | Allowlist, single quotes, `>`/`\|` block scalars, CRLF (`:45-53`, `:84-86`, `:186-229`). The fixture really has CRLF: 21 `\r$` lines | :391, :397 |
| N2 | Closed | Archived `EVENTS-*.md` rows are read (`:597-604`) | :373 |
| N3 | Closed | `:356-391`, `:417-427` | :380 |
| N4 | Closed | No import; source is read with `readNormalized` (`:512`) | Indirect |
| N5 | Closed | 30 s timeout and ETIMEDOUT handling in `scripts/check-docs.mjs:726-740` | None (fine) |
| N6 | Closed | `:959-972` | :526, :542 (exit 2 and no JSON) |
| N7 | Closed | `walkFiles` over the whole portable directory (`:915-927`) | :415 |
| N8 | Closed | `:346`, `:410` | :366 (base fixture `reactive-model-loop/references/lessons.md:5`) |
| N9 | Closed | Limits text is a plain string (`:10-17`); the usage string is no longer grepped | — |
| N10 | Closed | Name mismatch, missing description, over-150 warning, file that is not a symlink, wrong symlink target, invalid status, uncited id, unknown flag exits 2 with null findings, no JSON in default mode (`:169`), and a red-first receipt | test.js:438, :444, :471, :479, :487, :496, :511, :260; red-first in `A2-red-first.txt` |

**[receipt]** All tests pass on A2: `A2-verify.txt:9-10,24` shows "PASS tests", and `scripts/verify.mjs:14` maps that step to `npm test`.

## 2. Static verb parse

- **What each tree yields:**
  - JL-30c `scripts/play.mjs`:
    - `LAB_VERBS` at `:814` gives stats, gate and dash.
    - `LAB_SUBVERBS` at `:819` gives run, program and verdicts.
    - `verb === "lab"` at `:833`.
    - `const verbs = [...]` at `:889` gives play, test, watch, shot, list and help.
  - JL-coord `/home/andrew/Projects/scrapkeep-wt-JL-coord/scripts/play.mjs` has the same lists at `:816`, `:821`, `:836` and `:892`, with `watch: "watch.mjs"` added at `:825`.
  - All of these match the regexes at `:470-506`, including the multi-line object bodies.
- **Outcomes, derived by reading, not by running:**
  - `scrapkeep gate`, `stats` and `dash` pass in both trees.
  - `scrapkeep lab watch` passes against JL-coord and fails against JL-30c. That is correct, because JL-30c has no `watch`.
  - `scrapkeep lab nosuch` fails with a `lab sub-verb` finding. The top-level scan passes it on `lab`, so it is not reported twice.
  - `scrapkeep gate <run>` works because `<` does not match `[A-Za-z]`.
- **Fragility (non-blocking; each fails loudly or only lets citations through):**
  - `extractQuotedArray` stops at the first `]`, and quoted text in a comment inside the array would be picked up.
  - `extractObjectKeys` counts braces without regard to strings, and it would treat nested-object keys as verbs.
  - `extractLiteralVerbCases` also matches text in comments. For example, the fixture comment `base/scripts/play.mjs:4` contributes `lab`. It misses `"lab" === verb` and `case "lab":`.
  - Template-literal quotes are accepted.
  - A renamed or computed list produces loud false failures, not silent passes. The one exception is F3.

## 3. Whitespace split

- **Clean cases:**
  - `npm run check:docs`: `check:docs` has no slash and no path suffix, so it is not path-checked.
  - `--call-cap 5000`, `key=value`, `v1.2.3` and `[--arm`: not path-shaped.
  - The JL-30b `SKILL.md:17` command: only `scripts/lab/godot-launch.mjs` is checked.
- **False positives (only inside backticks):**
  - `and/or` and `pass/fail`, because `PATH_PREFIX` (`:343`) matches `and/`.
  - `out=artifacts/x.json` and `$ROOT/scripts/x.mjs`, which match on the `.json`/`.mjs` suffix.
  - `1.0/2.0`.
  - A path with trailing punctuation, such as `scripts/x.mjs,`.
- **Real skills:** a grep of JL-30b for these shapes found none. **[receipt]** `A2-check-skills-JL-30b.txt:1` shows 5 skills and 0 findings.

## 4. Skill-relative resolution and the gitignore warning

Both are sound.

- **Skill-relative resolution:**
  - The fallback runs only after the root lookup fails (`:414-416`). It could hide a dead root path only if a file with the same name exists under the citing skill's directory, which is unlikely.
  - Edge case: `../..` in a cited path can make `path.join` resolve outside the repository.
- **Gitignore warning:**
  - It applies only to dead paths that match root `.gitignore` patterns, which cannot be tracked anyway.
  - A tracked dead path such as `scripts/lab/x.mjs` still fails.
  - One gap: negation patterns are dropped (`:360`), so a dead `.env.example` would only warn, because of `.gitignore:5-6`.
  - Existing ignored paths pass silently, so a fresh clone differs from a local worktree only at warning level.

## 5. N6 and check-docs

- **Exit 2:** it prints no JSON. `scripts/check-docs.mjs:750-763` turns that into a named failure: "did not print a JSON findings array (exit 2): TRACKING.md is missing…".
- **Skip rule:** the stage skips when `.agents/skills` is absent (`:725`). No `tests/fixtures/check-docs` tree has `.agents`: the glob over `tests/fixtures/**/.agents/**` returns only check-skills fixtures. So the check-docs fixture tests are unaffected.
- **[receipt]** Those tests pass (`A2-verify.txt:10`).

## 6. Tests and style

- **Tests:** 42 cases, hermetic (`mkdtemp` plus `finally rm`). Symlinks are made after the copy (`tests/check-skills.test.js:18-37`). Each failure case asserts the named check plus a message token. The red-first receipt shows 23 new tests failing against A1.
- **Built-ins only:** the script and the tests import only built-ins (`scripts/check-skills.mjs:1-3`, test.js:1-7).
- **Style:** it follows check-docs, with a `Findings` class, an `exists` helper and one-line output.
- **Wiring:** `package.json:15,22` wires `check:skills`, and `test` globs `tests/*.test.js`.
- **Scope [receipt]:** check:scope classifies the change as tooling and requires only `npm run verify` (`A2-check-scope.txt:6,46-47`).
