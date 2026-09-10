# Review — AR-07

Candidate `65bf1a3ed1a8cb593c29901b4dc701fc7d039a02` on branch `wt/AR-07`, worktree
`.claude/worktrees/AR-07`, base `33d455f1dc74de6df029b2ac8d01371d6d1bc6db`.
Card: `BACKLOG.md:3499` (`### AR-07`, revision 1). Assignment:
`artifacts/audit-repair-2026-09-10/tasks/AR-07/assignment.md`. Handoff:
`artifacts/local/tasks/AR-07/handoff.json` (gitignored, read in the worktree).

## Verdict (PASS+NOTES) and evidence method

**PASS+NOTES.** All four definition-of-done items hold, scope discipline holds, and the
candidate is behaviourally identical to base whenever no archive is declared. The notes do
not violate the definition of done, so PASS+NOTES is admissible under `ORCHESTRATOR.md`
("Handoff and review"). One note (**F1**) is nevertheless blocking for the coordinator's
*next* step, not for this card: the convention as documented in the handoff
(`handoff.json:29-30`, "the split moves the header row and the event rows verbatim" to the
approved location `docs/project/tracking/EVENTS-0001-0057.md`) makes `npm run check:docs`
exit 1 with 11 link failures, because the pre-existing link rule resolves relative links
against the containing file's directory (`scripts/check-docs.mjs:259`). The event-ID part of
the convention works exactly as stated; the "move rows verbatim" instruction does not.

Evidence method: read-only git inspection of the worktree; full-tree scratch exports of the
candidate (`git archive 65bf1a3 | tar -x`) and of the pre-card script
(`git show 33d455f:scripts/check-docs.mjs`) under `/tmp`; independent checker runs of both
scripts against (i) the candidate's own board, (ii) the current live board, and (iii) twelve
hand-built scratch scenarios including a complete simulation of the `EV-0001..EV-0057`
split; `npm test` on a `/tmp` clone of the worktree with the host `node_modules` symlinked;
`npm run check:docs`, `npm run check:project`, `node --check`, `npx prettier --check`,
`python3`, `diff`, `sha256sum`. No browser, native, network, build or `npm run verify` run.

## The convention as implemented — quoted code and the exact rule

Declaration constants (`scripts/check-docs.mjs:88-90`):

```js
const eventArchiveHeading = "## Event archive";
const eventArchiveHeadingLike = /^#{1,6}\s+Events?\s+archives?\b/i;
const isEventId = (cell) => /^EV-\d{4}$/.test(cell ?? "");
```

Source discovery and the three guards (`scripts/check-docs.mjs:407-449`, abridged to the
decisive lines):

```js
async function eventArchives(docs) {
  const archives = [];
  for (const file of await markdownFiles(docs.root)) {
    if (file === "TRACKING.md") continue;
    const { lines } = await docs.load(file);
    const declared = [];
    for (const [index, line] of lines.entries())
      if (eventArchiveHeadingLike.test(line.trim())) declared.push(index + 1);
    if (!declared.length) continue;
    const exact = [];
    for (const line of declared)
      if (lines[line - 1].trim() === eventArchiveHeading) exact.push(line);
      else
        docs.fail("tracking", file, line,
          "malformed event archive heading: " + JSON.stringify(lines[line - 1].trim()) +
          " (an event archive declares itself with a level-2 heading that is exactly " +
          JSON.stringify(eventArchiveHeading) + ")");
    if (!exact.length) continue;
    const sections = tableSections(lines, eventArchiveHeading);
    const rows = sections.flatMap((section) => section.rows)
      .filter((row) => isEventId(row.cells[0]));
    if (!rows.length) {
      docs.fail("tracking", file, exact[0],
        "declared event archive holds no EV-NNNN event rows");
      continue;
    }
    archives.push({ file, lines, sections, rows });
  }
  return archives;
}
```

Section boundary (`scripts/check-docs.mjs:377-386`): rows are every line starting `|` (not
`|---`) between the heading and the next line matching `/^##\s/`; a file may repeat
`## Event archive` and `tableSections` returns every such section. Scope
(`scripts/check-docs.mjs:130-146`): top-level `*.md`, `adr/**`, `docs/**`, every `README.md`
under `artifacts/**` except `artifacts/local/`. ID space (`scripts/check-docs.mjs:463-524`):
sources are the board plus every archive, ordered by lowest id with the board first on a tie
and file name as the final tiebreak; each source keeps its own row order; duplicates fail as
`duplicate event EV-NNNN (first seen in <file>:<line>)` and sequence gaps as
`event sequence break: EV-NNNN follows EV-MMMM`. Record naming
(`scripts/check-docs.mjs:554-565`) now walks every source, so archived events participate in
the AR-01 stale rule; `programEvent` (`scripts/check-docs.mjs:54`) is unchanged.
Fenced blocks are blanked before scanning (`visibleLines`, `scripts/check-docs.mjs:149-158`).

Every claimed element of the convention was independently reproduced: exact heading only
(`## Event archive`); path irrelevant; `TRACKING.md` never scanned as an archive; repeated
sections read; malformed heading loud; declared-but-empty loud; scope excluding
`artifacts/local/`; recommended location works for ID resolution.

## Failure-mode tests I ran — command → observed message

All scenarios: scratch tree exported from the candidate, mutated with `python3`, then

`node <root>/scripts/check-docs.mjs --root <root> --report <tmp>/r.json`

| # | scenario I built | observed result |
| --- | --- | --- |
| a | full split: `EV-0001..EV-0057` (57 rows) moved into `docs/project/tracking/EVENTS-0001-0057.md` with `## Event archive`; board keeps `EV-0058..EV-0113` | exit **1**, `archives=1`, `events=113`, **0 tracking failures** (all 124 index rows citing ≤EV-0057 resolve); 11 `links` failures — see F1. Same tree with the pre-card script: exit 1, 136 failures (125 `tracking`, 11 `links`) |
| a2 | two rows `EV-0001..EV-0002` moved to the recommended path | candidate: exit 1, 1 failure (`links ...:8 missing link target: BACKLOG.md`). Base: exit 1, 37 failures including `[HF-01](BACKLOG.md#hf-01): Last event EV-0001 is not in the events table` |
| a3 | same two rows moved to a top-level `SOME-ARCHIVE.md` (path-free proof) | exit **0**, `archives=1`, `events=113`, 0 failures |
| b | malformed declarations, one per run | exit 1, exactly one failure each: `malformed event archive heading: "### Event archive" (an event archive declares itself with a level-2 heading that is exactly "## Event archive")`; same message for `"## event archives"`, `"# Event archive"`, `"## Event Archive"`, `"## Event archive: EV-0001..EV-0057"` |
| c | `## Event archive` with a non-EV table and no EV rows | exit 1: `declared event archive holds no EV-NNNN event rows` at `docs/project/tracking/EVENTS-NONE.md:1` |
| d | duplicate: archive copies `EV-0001`/`EV-0002` that remain on the board | exit 1: `docs/project/tracking/EVENTS-0001-0002.md:5 duplicate event EV-0001 (first seen in TRACKING.md:256)` and `:6 duplicate event EV-0002 (first seen in TRACKING.md:257)` |
| e | ID in no source: `PUB-01`'s Last event set to `EV-9999` | candidate exit 1: `TRACKING.md:103 [PUB-01](BACKLOG.md#pub-01): Last event EV-9999 is not in the events table`; base produces the **identical** finding. With an archive present the same failure appears alongside the link noise |
| f | `## Event archive` inside a fenced block | exit 0, `archives=0` |
| g | `## Event archive` appended to `TRACKING.md` | exit 0, `archives=0` (board is never an archive) |
| h | one file with two `## Event archive` sections, one row each | exit 0, `archives=1`, `events=113` (both sections read) |
| i | stale across the boundary, later naming event on the board: prefix archived, `HF-01`'s row set to `EV-0002` | exit 1: `TRACKING.md:111 [HF-01](BACKLOG.md#hf-01): Last event EV-0002 predates EV-0075, which also names HF-01` |
| j | stale across the boundary, later naming event **in** the archive: tail `EV-0058..EV-0113` archived, `HF-01`'s row set to `EV-0003` | exit 1: `TRACKING.md:111 [HF-01](BACKLOG.md#hf-01): Last event EV-0003 predates EV-0075, which also names HF-01` (EV-0075 now lives in the archive); 0 non-tracking failures |

## No-behaviour-change verification — base vs candidate comparison

- **Candidate board (base-identical, 113 events).** Pre-card script and candidate both exit
  0; stdout identical except the report path (`diff` shows exactly one line, the
  `check:docs pass: …` report path); `findings` equal (7), `manifest` equal, `result` `pass`;
  the only report difference is the additive `checked.archives: 0`.
- **Current live board (`bd6cb9a`, 119 events, integrated after the candidate base).** Same
  result: identical stdout apart from the report path, identical findings, both exit 0, only
  `checked.archives: 0` added.
- **Fixtures.** I rebuilt each fixture root the way `tests/check-docs.test.js` does and ran
  both scripts. Nineteen pre-existing fixtures are byte-identical in findings; the sole
  difference is `duplicate-event`, where the message gains ` (first seen in TRACKING.md:20)`
  (see F2). Every new fixture fails under the pre-card script and passes/fails under the
  candidate exactly as the handoff claims (`archive-resolves` base 3 failures → candidate 0;
  `archive-missing-id` base 4 → candidate 1, the EV-0099 case; `archive-duplicate-id` and
  `archive-row-stale-later` base unrelated failures → candidate the intended single failure;
  `archive-stale-later` base 0 → candidate the intended stale failure;
  `archive-heading-malformed` base 0 → candidate 2 malformed-heading failures).
- **Diff audit of `scripts/check-docs.mjs`.** No `docs.fail` call was removed, skipped or made
  conditional; every removed line is refactoring (`tableRows` → `tableSections`, loop
  restructuring) or the duplicate-message change. The state-vocabulary block, the
  `Last event is not an EV-NNNN id` / `is not in the events table` block and the `predates`
  block are untouched context lines; `programEvent` is unchanged.
- **`npm test`** on a `/tmp` clone of the worktree (node_modules symlinked from the host):
  **211 tests, 211 pass, 0 fail** — reproduces the handoff. (The worktree has no
  `node_modules`; a bare `git archive` export without `.git` fails one native-smoke test that
  runs `git ls-files`, which is why I cloned.)
- **`npm run check:docs`** in that clone: exit 0, `check:docs pass: 124 Markdown files, 3423
  local links, 84 cards, 113 events, 6 sections, 7 interim rows, 0 failures.`
- **`npm run check:project`**: exit 0. **`node --check scripts/check-docs.mjs`**: ok.
- **`npx prettier --check`**: both leased files fail at base and at the candidate (reproduced
  the handoff's claim; the writer did not reformat).

## Findings

Every finding: criterion (card locator) · artifact locator · observation · violated
requirement · severity.

**F1 — the documented split breaks the link check at the approved location.**
Criterion: `BACKLOG.md#ar-07` DoD 1 and "Verification and evidence" ("State the file-name
convention … so the coordinator can perform the split against it"); handoff claim
`handoff.json:29-30` ("The table uses the same columns as TRACKING.md … so the split moves
the header row and the event rows verbatim"). Locator: `scripts/check-docs.mjs:259`
(`path.posix.join(path.posix.dirname(file), decodedPath)`) and `:271`
(`missing link target:`); `handoff.json:30`; fixture gap at
`tests/fixtures/check-docs/archive-resolves/docs/project/tracking/EVENTS-0001-0002.md:11-12`
(synthetic rows carry no relative links).
Observation: moving the 57 real rows verbatim to `docs/project/tracking/EVENTS-0001-0057.md`
yields `npm run check:docs` exit 1 with 11 failures, e.g.
`docs/project/tracking/EVENTS-0001-0057.md:8 missing link target: BACKLOG.md`,
`…:11 missing link target: artifacts/swarm-prep-2026-09-06/candidate-manifest.json`,
`…:13 missing link target: artifacts/publication-2026-09-06/AUTHORIZATION.md`,
`…:41 missing link target: docs/project/sprint-0/AUTHORIZATION.md` (11 total). The same 57
rows moved to a repository-top-level file give exit 0. All 124 index rows citing ≤EV-0057 do
resolve correctly; the failure is the pre-existing link rule, not the new archive rule.
Violated requirement: none by the letter of DoD 1-4 (the card is checker-capability only and
its boundary defers the split), but the handoff's convention is incomplete for the step it
exists to enable. Severity: **high — blocks the planned split**. The coordinator must not
perform the split as documented; options are (i) place the archive at a path where the moved
relative links resolve (a location change from Andrew's chosen `docs/project/tracking/`),
(ii) rewrite the 11 relative links while moving (deviating from "verbatim"), or (iii) file a
follow-up card making the link rule archive-aware. Fixtures cannot detect this because their
archive rows have no relative links.

**F2 — the duplicate message changed, so "same messages" is inaccurate.**
Criterion: `BACKLOG.md#ar-07` Verification ("Keep the existing summary format intact") and
handoff close-out claim `handoff.json:108` ("still pass unchanged with the same messages").
Locator: `scripts/check-docs.mjs:499-512`; output at `duplicate-event` fixture
(`duplicate event EV-0001` → `duplicate event EV-0001 (first seen in TRACKING.md:20)`).
Observation: the suffix is additive and more informative; the pre-existing test regex still
matches and `npm test` passes; the board has no duplicates so board stdout is unaffected.
Violated requirement: none (a strict reading of "same messages" is inaccurate, not a
regression). Severity: **low**.

**F3 — "tracked" is not actually enforced.**
Criterion: `BACKLOG.md#ar-07` DoD 1 ("tracked archive files"). Locator:
`scripts/check-docs.mjs:407-412` scans the working tree via `markdownFiles`, not `git ls-files`.
Observation: an in-scope untracked Markdown file with `## Event archive` is honoured exactly
like a tracked one, so a stray scratch archive under `docs/` could resolve ids or create
duplicates. Mitigated by the existing exclusion of `artifacts/local/` and by the
coordinator's clean-worktree check. Violated requirement: a literal reading of "tracked" is
not enforced (the rest of the checker has the same working-tree convention). Severity: **low**.

**F4 — the malformed-heading guard constrains future documentation.**
Criterion: card DoD 1 (declaration convention) / handoff limits `handoff.json:115`. Locator:
`scripts/check-docs.mjs:89` (`eventArchiveHeadingLike`) and `:419-427`. Observation: any real
heading beginning `Event archive`/`Event archives` outside a fence in a scanned file fails the
check, so the coordinator must document the convention in `TRACKING.md` (exempt), in prose, or
inside a fenced block. Verified safe in a fence (test f) and loud outside one (test b).
Severity: **info** (documented by the writer).

**F5 — the candidate base is behind the live board.**
Criterion: `ORCHESTRATOR.md` "Admission and assignment" item 5 (base is the accepted
integrated state). Locator: candidate parent `33d455f`, live `HEAD bd6cb9a` (AR-05/AR-06
integration, 119 events). Observation: no live change since the base touches
`scripts/check-docs.mjs`, `tests/check-docs.test.js` or `tests/fixtures/check-docs/**`
(`git diff --name-only 33d455f..HEAD -- <lease>` is empty), and base vs candidate parity still
holds on the live board, but integration must re-run the checks on the rebased result.
Severity: **info** (coordinator's integration step).

## Uncertain or unverifiable

- `npm run verify` was not run: this packet forbids it and `check:scope` classifies the change
  set as `tooling` and refuses `--no-build`, requiring `npm run verify`. The build-requiring
  verification for this path class is therefore **unestablished by me** and remains the
  coordinator's step at integration. `check:scope` also confirms all 13 changed paths are in
  lease AR-07-L1.
- The worktree has no `node_modules`, so I could not reproduce the writer's literal
  `npm test` invocation in place; I reproduced the suite on a clone of the candidate tree with
  the host modules. The 211/211 result is from that clone, not from the worktree.
- I did not reproduce `artifacts/local/tasks/AR-07/evidence.mjs` or its 17 case runs; I built
  my own twelve scenarios instead, which cover the four required cases plus the extra guards.
- The full split simulation is my scratch copy, not a coordinator commit; the real split may
  differ (this is what F1 is about).
- The card and assignment say "117 index rows whose `Last event` is at or before EV-0057"; on
  this board I count **124** (74 task + 50 question index rows). The card's number is stale,
  not a defect.
- Role limit: one reviewer is one independent opinion; the split itself and `npm run verify`
  remain unreviewed until the coordinator integrates.

## Method and limits

Read-only git (`show`, `log`, `diff`, `rev-parse`, `archive`, `ls-files`, `check-ignore`),
`node`, `npm test` / `npm run check:docs` / `npm run check:project` (on a `/tmp` clone or a
`/tmp` export, never writing into the repo or the worktree), `node --check`,
`npx prettier --check`, `grep`, `diff`, `sha256sum`, `python3`. The platform wipes `/tmp`
between shell invocations, so each scenario re-exported the tree inside a single invocation.
The only repository write is this report. Structural documentation checks only: no build,
browser, native, network or remote check is implied, and no conclusion is drawn about runtime
or game behaviour. Scope, identity and cleanliness verified at review time: parent
`33d455f1dc74de6df029b2ac8d01371d6d1bc6db`, 13 changed paths, worktree
`git status --porcelain` empty; `TRACKING.md` sha256
`f3b7aca0e09f8a6a6512f957e99770dc8dfe31f0ac62d357364a26afc10ec399` and `BACKLOG.md` sha256
`77e41ccbffe04c6e5016c13c37453c53e9cb8a12599a028ec88b24b9186ed24a` byte-identical to base;
no archive created (`docs/project/tracking/` absent from the worktree; the only `EVENTS-*`
tracked files are the six fixture files).
