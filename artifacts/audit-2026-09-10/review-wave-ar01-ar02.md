# Wave review — AR-01 and AR-02

Reviewer: fresh independent reviewer `session-e9629c7c-7375-4edb-9843-169478797b0f` (delegated).
Wrote neither candidate, holds no write lease, made no repo or worktree write; the only file written
is this report. Reviewed tree: repository root `8f1df2f34ef4c98f007dc17e7a51a632dc1c8214` with the two
candidate worktrees read at their recorded commits. Method is stated per finding; every count below was
re-derived from the trees, not read from the handoffs.

## Verdicts

| Card | Card revision | Candidate | Verdict | Evidence method |
| --- | --- | --- | --- | --- |
| AR-01 | 2 (`BACKLOG.md:3340`, revision-2 wording at `BACKLOG.md:3355`) | `61fee5b0ae473aab0bff5f34a0254e83bf7e89fb`, branch `wt/AR-01`, worktree `.claude/worktrees/AR-01`, parent `641f09f54a37af15da2ea35ced7f281f60959d13` | **PASS+NOTES** | identity/lease re-read with `git log -1 --format`, `git show --stat`, `git status --porcelain`; candidate checker re-run against its own board and against the current canonical board; own fixture matrix (base-overlay copies in `/tmp`) with candidate vs. self-built strict variant (exclusion line deleted); regex-term ablation; own `git archive` clean-tree extraction; synthetic HF-05 reproduction |
| AR-02 | 1 (`BACKLOG.md:3367`) under lease amendment AR-02-L2 (`EV-0099`, `artifacts/audit-repair-2026-09-10/tasks/AR-02/assignment.md:70-83`) | `c5c02d32a07a092f78c08273cd1e8fb876e4f975`, branch `wt/AR-02`, worktree `.claude/worktrees/AR-02`, parent `08660f99507f8ad06d2223b7086dbb3a18ebaaef` | **PASS+NOTES** | identity/lease re-read; own Python `path` + `sha256` + `git ls-files` walk; `cmp` sweep against the originals; JSON structural diff of `closure.json` vs base; `node scripts/sprint-close.mjs` on candidate and base receipts; own `git archive` clean-tree extraction of base and candidate; simulated integration overlay (root `HEAD` + candidate files) in `/tmp` |

Both candidates satisfy every Definition-of-done item of their card revision. The notes below are
recorded constraints for the coordinator; none of them violates a definition of done.

## AR-01 findings

**AR-01-F1 — DoD 1, state vocabulary (card `BACKLOG.md:3354`; `TRACKING.md:30`). PASS.**
Artifacts: `scripts/check-docs.mjs:36-46` (`taskStates`), `:441-446`, `:462-477`;
`tests/fixtures/check-docs/state-in-review/TRACKING.md`; `tests/fixtures/check-docs/state-vocabulary/TRACKING.md`.
Observation: the vocabulary is byte-equal to `TRACKING.md:30` (`queued, blocked, ready, in_progress,
review, changes_requested, done, parked, cancelled`). The historical token now fails, quoted from the
candidate checker against the fixture: `FAILURE tracking TRACKING.md:7 [HF-01](BACKLOG.md#hf-01): state
"IN_REVIEW" is not in the state vocabulary (queued, blocked, ready, in_progress, review,
changes_requested, done, parked, cancelled)`, exit 1, 1 failure. The nine-member fixture passes with
`checked.states=9`; on the live boards the counter reads 84 (candidate base board) and 88 (current
canonical board), both 0 failures. The question-index states are deliberately not checked (`:35`,
`stateIndex` is only read when `heading === "## Task state index"`, `:444`), which matches the card's
"task-index `State` cell" scope. No violated requirement.

**AR-01-F2 — DoD 2, unresolvable and stale `Last event` (card `BACKLOG.md:3355`). PASS.**
Artifacts: `scripts/check-docs.mjs:416-429` (record-level event map), `:478-516` (rule).
Observation: both failure forms fire as written. `last-event-unresolvable` → exit 1 with
`TRACKING.md:7 … Last event is not an EV-NNNN id: "not-yet"` and `TRACKING.md:8 PS-01 (interim): Last
event EV-0099 is not in the events table`. `last-event-predates` → exit 1 with `TRACKING.md:7 … Last
event EV-0001 predates EV-0002, which also names HF-01`. `last-event-current` (row pointing at the
latest event naming the record) → exit 0. No violated requirement.

**AR-01-F3 — DoD 2, the exclusion is documented and carries a negative control (card `BACKLOG.md:3355`). PASS.**
Artifacts: `scripts/check-docs.mjs:47-54` (comment naming EV-0077/EV-0078 and the batch-event rule plus
`const programEvent = /authorization|coordination|closure/i`); `tests/check-docs.test.js:85-91`
("every board state passes and a program-level event does not make rows stale"); fixture
`tests/fixtures/check-docs/state-vocabulary/TRACKING.md:36` (EV-0010, kind `Coordinator /
authorization`, names all nine records with a higher sequence).
Observation (my own strict variant, exclusion line deleted, not the writer's file): the fixture passes
at the candidate (exit 0) and fails 9/9 task rows without the exclusion — every one quoting
`predates EV-0010, which also names …`. The negative control is therefore in the tracked test suite and
is genuinely load-bearing, not an extra scratch script. No violated requirement.

**AR-01-F4 — DoD 4, current board passes with no board edit (card `BACKLOG.md:3357`). PASS.**
Artifacts: `TRACKING.md`, `BACKLOG.md` in both trees; checker `scripts/check-docs.mjs`.
Observation: `git diff 641f09f HEAD -- TRACKING.md BACKLOG.md` in the candidate worktree is empty, and
no changed path in the candidate is a board file. The candidate checker run against its own board:
`check:docs pass: 122 Markdown files, 3392 local links, 77 cards, 97 events, 6 sections, 7 interim
rows, 0 failures`, `checked.states=84`. Extended check the handoff did not run: the same checker run
against the **current canonical board** at repository root (`81 cards, 101 events`, four AR rows added
after the candidate's base) also passes: `check:docs pass: 123 Markdown files, 3400 local links, 81
cards, 101 events, 6 sections, 7 interim rows, 0 failures`, `checked.states=88`. No violated
requirement.

**AR-01-F5 — no existing check weakened, skipped or made conditional (packet
`artifacts/audit-repair-2026-09-10/tasks/AR-01/assignment.md:56`; ORCHESTRATOR "Serial integration and
completion"). PASS.**
Artifact: `git -C .claude/worktrees/AR-01 diff 641f09f 61fee5b0 -- scripts/check-docs.mjs`.
Observation: exactly two lines were removed —
`-      const lastEvent = row.cells[row.cells.length - 1] ?? "";` and
`-  return { events: sequence.size, interim };` — and both are replaced by strictly larger behaviour
(header-named column with the old last-cell fallback; the same return plus `states`). Every existing
`docs.fail` site is intact; `:445-446` adds a new failure (`task index has no State column`) instead of
silently skipping a table. The header change is behaviour-preserving on this board: both live index
tables carry `Last event` as the final column (`Task state index` cols=7 @6, `Question state index`
cols=5 @4, audited with a parser over `TRACKING.md`), and the check loop only covers those two tables
(`:435`). No violated requirement.

**AR-01-F6 — the historical defect it targets is now caught (card `BACKLOG.md:3355`, "the HF-05 case"). PASS.**
Artifact: synthetic reproduction in `/tmp` (fixture base copied, `<a id="hf-05">` added) with the
historical shape — row `[HF-05](BACKLOG.md#hf-05)` `Last event EV-0002` while checkpoint `EV-0003`
(kind `Coordinator / checkpoint`) names `HF-05`.
Observation: `FAILURE tracking TRACKING.md:7 [HF-05](BACKLOG.md#hf-05): Last event EV-0002 predates
EV-0003, which also names HF-05`. Independently, rolling the real board's HF-05 row back to `EV-0089`
in an archived copy of the candidate tree produces exactly one new tracking failure naming the later
event. No violated requirement.

**AR-01-F7 — NOTE (board bookkeeping, candidate not at fault): the card's `Files touched` does not list the fixture files the lease authorizes.**
Locators: `BACKLOG.md:3350` (`Files touched: scripts/check-docs.mjs; tests/check-docs.test.js`) versus
lease AR-01-L1 (`assignment.md:12-14`: `… tests/fixtures/check-docs/** (new fixture directories only)`)
and delivered paths `tests/fixtures/check-docs/{state-in-review,state-vocabulary,last-event-predates,last-event-unresolvable,last-event-current}/TRACKING.md`.
Observation: all 7 changed paths are inside the issued lease, and the lease is the coordinator's
authorization; but `TRACKING.md:33` requires a record's `owned_files` to be a subset of the pinned
card's permitted files, and the card's permitted set is the two-file `Files touched` line. This is a
card/lease consistency gap on the coordinator's side. Recommended: at admission, record a card
revision that adds `tests/fixtures/check-docs/**` to `Files touched`, or record the lease-to-card
relation in the admission event. Severity: low.

**AR-01-F8 — NOTE: the free-text exclusion is broader than the two events that make it necessary, but it is exactly what revision 2 specifies.**
Locators: `scripts/check-docs.mjs:47-54`; card `BACKLOG.md:3355`; handoff uncertainty in
`artifacts/local/tasks/AR-01/handoff.json:91-93`.
Observation (my own ablation, replacing the regex with each subset and re-running against the current
canonical board): no exclusion → 9 failures; `authorization|coordination` only → 2 failures
(`EV-0077`, `Coordinator / sprint closure`, leaves HF-01/HF-02 stale); `authorization|closure` → 0;
`coordination|closure` → 0; `closure` alone → 9 failures. So `authorization` and `coordination` are
redundant with each other on this board while `closure` carries EV-0077; the union is what makes the
board pass. The regex matches 12 events on the candidate board, of which only EV-0077 and EV-0078
conceal any staleness today; the other ten (e.g. EV-0023, EV-0035, EV-0057, EV-0058, EV-0064, EV-0065,
which do name real cards) are excluded without currently hiding a stale row. That is the card's own
definition (kind cell "names authorization, coordination or closure"), it is documented in the checker,
and the card already records the migration trigger to a structured event-kind field. Ruling: the
exclusion is **load-bearing** (9 live rows fail without it, all reported against EV-0078; 2 of those
rows — HF-01 and HF-02 — are also made stale by EV-0077, which is why the `closure` term is required in
addition) and **correctly scoped to revision 2**, with a known residual false-negative
surface if a future record-level event's kind cell contains one of the three words. Severity: low
(documented, card-permitted).

**AR-01-F9 — NOTE (evidence honesty): handoff metadata is revision-1 stamped and one clause is unqualified.**
Locator: `artifacts/local/tasks/AR-01/handoff.json:3` (`"card_revision": 1`), `:79` (acceptance item 2
wording without "record-level"), `:91-93` (uncertainty discloses the reconciliation and the strict
reading).
Observation: the handoff was authored under card revision 1 and the coordinator's `EV-0100` records the
revision-1→2 change and directs review against revision 2; the implementation satisfies revision 2.
The `rule_last_event_semantics` section states the revised semantics correctly. No false claim;
reviewers should read the handoff as revision-1 provenance. Severity: informational.

## AR-02 findings

**AR-02-F1 — identity, lease and cleanliness. PASS.**
Artifacts: `git -C .claude/worktrees/AR-02 log -1 --format='%H %P'` →
`c5c02d32a07a092f78c08273cd1e8fb876e4f975 08660f99507f8ad06d2223b7086dbb3a18ebaaef` (parent equals
the recorded base `c5c02…/handoff.json:6`); `git show --stat` → 13 changed paths, all inside AR-02-L2
(`artifacts/sprint-0-closure-2026-09-06/**`, `docs/project/sprint-0/closure.json` path values only,
`artifacts/README.md`, `docs/project/sprint-0/README.md`); `git status --porcelain` empty.
Observation: `git log --all -- artifacts/local` on the branch is empty — no commit on `wt/AR-02` ever
tracked anything under `artifacts/local/`, so the attempt-1 force-add was fully withdrawn. No violated
requirement.

**AR-02-F2 — DoD 1, nine copies byte-identical to the pins (card `BACKLOG.md:3381`). PASS.**
Artifacts: `artifacts/sprint-0-closure-2026-09-06/` (10 tracked files: 9 copies + `README.md`);
`git ls-files artifacts/sprint-0-closure-2026-09-06` → 10 paths.
Observation (own walk, `git ls-files` required for every pin): `pinned=12 present+match=12 missing=0
mismatch=0 untracked=0 under_artifacts_local=0 → RESULT PASS`. Independent `cmp` sweep of all nine
copies against `artifacts/local/sprint-0/closed/` in the main checkout: 9/9 identical, and each file's
`sha256` equals its pinned value (`docs.log ec6fb1d6ea41`, `project.log cf6a6119ecee`,
`integrated-review.md 1c269139cc2b` ×2, `native-report.json 9360ba38365d` ×3,
`visible-receipt.json 09abf7bfbd9d`, `ci-native-report.json a1dc6bb304e8`, `verify.log 0cefb3bceec8`,
`coverage-review.md d7e062ea253b`, `runner-cleanup.json e184c6f38414`). No violated requirement.

**AR-02-F3 — DoD 2, pins resolve through tracked files and leave `artifacts/local/` (card `BACKLOG.md:3382`). PASS.**
Artifacts: `docs/project/sprint-0/closure.json`; `.gitignore:7`.
Observation: 0 of the 12 pinned `path` values remain under `artifacts/local/`; `git ls-files
artifacts/local` in the candidate worktree is empty (0 lines); `git check-ignore -q` on all 13 changed
paths exits non-zero for every one. No violated requirement.

**AR-02-F4 — DoD 3, disposal contract (card `BACKLOG.md:3383`, relocated to `artifacts/README.md` by AR-02-L2). PASS with NOTE.**
Artifacts: `artifacts/README.md:12-42`; `docs/project/sprint-0/README.md:32-34`;
`artifacts/sprint-0-closure-2026-09-06/README.md:1-43`.
Observation: the tracked contract names all nine distinct / twelve cited pin-critical paths in a table
(`artifacts/README.md:22-36`), names the receipt and the read-only pin check to run before pruning, and
adds a "Cited under `local/` but not hash-pinned" section. NOTE: that section lists
`artifacts/local/native-smoke/report.json`, `artifacts/local/tasks/S0-09/review.md`,
`artifacts/local/tasks/S0-13/review.md` and the two screenshot directories, but omits
`artifacts/local/sprint-0/final/dispatch-validation.json`, which is cited by the receipt itself at
`docs/project/sprint-0/closure.json:75` (`retroActions[].reference`). It is not hash-pinned, so DoD 3's
"pin-critical path" set is fully covered; the omission is in the advisory catch-all section. The
handoff claim that the contract names "the cited-but-unpinned local paths" is therefore incomplete by
one path (`handoff.json:24`, `:166`). Severity: low; fix on the next touch of `artifacts/README.md`.

**AR-02-F5 — DoD 4, the closure validator still accepts the receipt (card `BACKLOG.md:3384`). PASS.**
Artifacts: `scripts/sprint-close.mjs` (absent from the candidate diff); receipts.
Observation: `node scripts/sprint-close.mjs docs/project/sprint-0/closure.json` in the candidate
worktree → `outcome pending_evidence`, 1 issue: `checkout HEAD differs from tested commit`, 0 `failed`,
`nextProposal` untouched. The same validator on the base receipt in the same worktree → 13 issues
(12× `evidence file is missing or unreadable` + the HEAD issue), so the repoint removes 12 issues and
adds none. The script has no write path (`grep` for `writeFile|mkdir|rm(|copyFile` is empty), so the
run is read-only. No violated requirement.

**AR-02-F6 — path-only repoint of the receipt. PASS.**
Artifact: `docs/project/sprint-0/closure.json` candidate vs `git show 08660f9:…`.
Observation: structural comparison with every `path` value masked is equal; the `sha256` list is
identical; gate `status` values identical; `nextProposal` byte-identical
(`awaiting_review`/`Andrew`, unchanged); exactly 12 of 12 `path` values differ on exactly 12 diff
lines. No violated requirement.

**AR-02-F7 — NOTE (medium): the candidate's own tree is not clean-checkout green, though the defect is pre-existing at its base and is already fixed upstream.**
Artifacts: candidate `git archive HEAD` extraction (no `artifacts/local`) → `check:docs fail: 123
Markdown files, 3416 local links, 81 cards, 99 events, …, 4 failures`, all
`FAILURE links BACKLOG.md:3346|3373|3401|3427 missing link target:
artifacts/local/audit-2026-09-10/lane-{5,6}-…md`. Control: the untouched base `08660f9` extracted the
same way produces the identical 4-failure set (`122 Markdown files`), so nothing in the candidate
causes it. The links were fixed by the coordinator's `0b7b84e` (audit set promoted to tracked
`artifacts/audit-2026-09-10/`, card citations repointed), which is a descendant of the candidate's base
and outside its lease.
Observation: **simulated serial integration** (root `HEAD` archive + the candidate's four changed
artifacts overlaid, no `artifacts/local/`) → `check:docs pass: 124 Markdown files, 3416 local links, 81
cards, 101 events, 0 failures`; `check:project → Project checks passed: 104 Markdown files, 2019 file
links`; the integrated pin walk is `present+match=12`. Also reproduced the handoff's `proofZeroAdded`
base half: base `08660f9` + the two audit files present in `artifacts/local/audit-2026-09-10/` → 0
failures. Requirement: the standing clean-checkout property (canonical records must not link to
gitignored files) holds for the integrated result but **not** for the candidate tree in isolation.
Required coordinator action: admit AR-02 only onto `0b7b84e` or later and re-run `npm run check:docs`
on the integrated result (as I did), not on the candidate worktree. Severity: medium for the procedure,
not for the candidate.

**AR-02-F8 — NOTE (board bookkeeping): the card still names `artifacts/local/README.md`, which AR-02-L2 withdrew.**
Locators: `BACKLOG.md:3377` (`Files touched: … artifacts/local/README.md (new); …`) and
`BACKLOG.md:3383` (`3. artifacts/local/README.md states the disposal contract …`) versus `EV-0099` and
`assignment.md:70-83` (L2 moves the contract to `artifacts/README.md`; the tracked location is now
verified empty of any file under `artifacts/local/`).
Observation: the delivered artifact matches the amended lease and the review instruction, so no
candidate requirement is violated; but the card's revision-1 text is now unsatisfiable and contradicts
the lease. Recommended: record AR-02 card revision 2 (DoD 3 and `Files touched`) before admission, so
the board does not carry a definition that the accepted deliverable deliberately does not meet.
Severity: low.

**AR-02-F9 — NOTE (evidence honesty): two handoff claims need their provenance stated.**
Locators: `artifacts/local/tasks/AR-02/handoff.json:127` ("the base receipt produced 14 issues");
`artifacts/sprint-0-closure-2026-09-06/README.md:9` ("Copies taken … during card AR-02 attempt A1, from
base commit `641f09f…`").
Observation: on the clean A2 worktree the base receipt produces **13** issues; the recorded 14
(`validator-before.json`) additionally contains `tracked worktree is dirty`, an A1-pre-commit state
that no longer exists, and the handoff quotes only the 12 missing-evidence issues. The number is not
false for the state it describes, but the sentence is not reproducible as written. Likewise the new
README states the A1 copy provenance (base `641f09f`) while the candidate's base is `08660f9`; that is
historically true because attempt 2 folded attempt 1 into one commit, but a reader of this commit alone
cannot tell the copies were first taken at a different base — the tracked bytes are byte-identical to
the pins, so nothing depends on it. Both are documentation
imprecision, not dishonest claims. Severity: informational; worth one correction line if the README is
touched again.

## Independent checks performed — exact command → observed result

AR-01 (worktree `.claude/worktrees/AR-01`, base `641f09f`):

- `git -C .claude/worktrees/AR-01 log -1 --format='%H %P'` → `61fee5b0… 641f09f5…` (parent = recorded base).
- `git -C .claude/worktrees/AR-01 status --porcelain` → empty (clean, before and after my runs).
- `git -C .claude/worktrees/AR-01 diff 641f09f 61fee5b0` → 7 paths: `scripts/check-docs.mjs`, `tests/check-docs.test.js`, 5 new fixture directories; `-- scripts/check-docs.mjs | grep '^-'` → only the two replaced lines.
- `node .claude/worktrees/AR-01/scripts/check-docs.mjs --root .claude/worktrees/AR-01 --report /tmp/…` → exit 0, `0 failures`, `checked={"files":122,"links":3392,"cards":77,"events":97,"states":84,"sections":6}`.
- `node .claude/worktrees/AR-01/scripts/check-docs.mjs --root /home/andrew/Projects/scrapkeep --report /tmp/…` (candidate checker, current canonical board) → exit 0, `0 failures`, `checked={"files":123,"links":3400,"cards":81,"events":101,"states":88,"sections":6}`.
- `npm test` in the worktree → `tests 193, pass 193, fail 0`; `node --test .claude/worktrees/AR-01/tests/check-docs.test.js` → `tests 26, pass 26, fail 0`.
- `npm run check:project` in the worktree → exit 0, `104 Markdown files, 2011 file links` (equals the handoff claim).
- Fixture matrix (base-overlay copies in `/tmp`), candidate vs. my own strict variant built by deleting the `programEvent …continue` line from the candidate source: `base` 0/0 vs 0/0; `state-vocabulary` 0 failures vs **9 failures** (negative control proven); `state-in-review` 1/1 vs 1; `last-event-predates` 1/1 vs 1; `last-event-unresolvable` 2/2 vs 2; `last-event-current` 0 vs 0.
- Ablation over the current board: no exclusion → 9 failures (all EV-0078, lines 111,112,114,115,116,121,122,123,124); `authorization|coordination` → 2 (EV-0077); `authorization|closure` → 0; `coordination|closure` → 0; `closure` alone → 9.
- Strict control against the candidate's own board → 9 failures, identical messages/lines to the writer's `artifacts/local/tasks/AR-01/strict-report.json` (whose script differs from the candidate only by `if (false && …)`), and identical to the handoff claims.
- Synthetic HF-05 fixture and a rolled-back HF-05 row in an archived candidate tree → the stale-row failure fires naming the later record-level event.
- Record-id extractor audit over the live events table → 141 distinct record IDs named; the only extracted keys that are not live index records are non-row keys (`HF-03/04/06/07`, `AM-F01-001`, `AM-FF-001`) or interim rows my link-only comparator excluded (`PS-01…PS-06`), so no false-key collision surface was observed.

AR-02 (worktree `.claude/worktrees/AR-02`, base `08660f9`):

- `git -C .claude/worktrees/AR-02 log -1 --format='%H %P'` → `c5c02d32… 08660f99…`; `git status --porcelain` → empty.
- `git -C .claude/worktrees/AR-02 show --stat HEAD` → 13 paths; `git diff --name-only 08660f9 c5c02d3 | git check-ignore -q` per path → none ignored.
- Own Python walk (`/tmp`, requires `git ls-files` membership) over `docs/project/sprint-0/closure.json` → `pinned=12 present+match=12 missing=0 mismatch=0 untracked=0 under_artifacts_local=0 → PASS`.
- `git -C .claude/worktrees/AR-02 ls-files artifacts/local` → 0 paths; `git log --all -- artifacts/local` → empty; `git ls-files artifacts/sprint-0-closure-2026-09-06` → 10.
- `cmp` sweep 9/9 identical against `/home/andrew/Projects/scrapkeep/artifacts/local/sprint-0/closed/`; `grep -o 'artifacts/local…' closure.json` → 4 residual non-pin references only (`retroActions` ×3 + one pinned original path in a retroAction).
- Base/candidate JSON diff with `path` masked → equal; `sha256` list equal; statuses equal; `nextProposal` equal; 12/12 paths changed.
- `git -C .claude/worktrees/AR-02 archive HEAD | tar -x -C /tmp/…` then `node scripts/check-docs.mjs --root …` → exit 1, 4 failures (all `BACKLOG.md` links into `artifacts/local/audit-2026-09-10/`); same extraction at `08660f9` → identical 4 failures.
- Simulated integration (root `HEAD` archive + candidate's 4 artifacts, no `artifacts/local`) → `check:docs` exit 0 (124 files, 0 failures); `check:project` exit 0 (2019 links); pin walk 12/12.
- `node scripts/sprint-close.mjs docs/project/sprint-0/closure.json` (candidate) → `pending_evidence`, 1 issue; on the base receipt in the same worktree → 13 issues (12 missing + HEAD).
- `npm run check:docs` at repository root `8f1df2f` → exit 0, `123 Markdown files … 0 failures`; `npm run check:project` at root → exit 0.

## Uncertain or unverifiable

- Closure gate results were not re-run and are not re-verified: the card's boundary forbids it, and the review only establishes that the recorded bytes are preserved and readable by the receipt checker. The copies prove byte identity, not that the recorded runs passed.
- The two large export binaries whose hashes `native-report.json` records are not pinned and not copied (`artifacts/sprint-0-closure-2026-09-06/README.md:32`); their reproducibility is out of scope.
- The AR-01 exclusion's future behaviour is unverifiable by construction: a future record-level event whose kind cell contains "authorization", "coordination" or "closure" would be skipped (false negative), and a program-scoped event whose kind avoids all three would flag rows (false positive). Both directions are documented by the writer and permitted by revision 2, which defers to a structured event-kind field.
- `npm run verify`, builds, browser, Playwright and Godot/native checks were not run (forbidden by the task and by both packets' no-build scope); no runtime claim is made.
- I could not directly observe the A1-era dirty worktree that produced the recorded 14-issue validator run; that figure rests on the retained `validator-before.json` only.
- The 193-test suite was run as a whole; I re-ran only `tests/check-docs.test.js` (26 cases) individually. The remaining tests are unchanged by the candidate and are not part of either DoD.
- One reviewer is one independent opinion; this wave report itself is not second-pass reviewed.

## Method and limits

Read-only review. Allowed commands only: `git show/log/diff/rev-parse/ls-files/check-ignore/archive`,
`npm test`, `npm run check:docs`, `npm run check:project`, `node`, `grep`, `cmp`, `sha256sum`, `python3`,
all analysis artifacts built under `/tmp` and discarded. No repo or worktree write; no `npm run verify`,
build, browser or native command; no installs or network. Verification of the two never-written
candidates was done on their recorded commits and on unmodified extracts of those commits, so every
result names a source identity.

One incidental side effect is disclosed: `npm run check:docs` at repository root rewrites its own
default report at the disposable, gitignored `artifacts/local/check-docs/report.json` (nothing tracked,
pre-existing path; all other runs used `--report /tmp/…`). The writers' own scratch evidence in the two
worktrees was not touched, and both worktrees remained clean after the review.

Limits: fixture-level and script-level evidence only; no build, runtime, browser, native or human
evidence is implied, and none was used. Counts are re-derived from the stated commits and are valid
only for those commits; anything produced at a different base needs its own result.
