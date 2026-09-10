# Wave review — AR-05 and AR-06

Fresh independent reviewer (wrote neither candidate). One wave review for two disjoint write sets, one
verdict and evidence method per candidate, per [ORCHESTRATOR.md](../../ORCHESTRATOR.md#handoff-and-review)
("One fresh reviewer may read a wave's two candidates together when their write sets are disjoint").
Read-only on both worktrees and on the main checkout; the only file written is this report.

Cards: [AR-05](../../BACKLOG.md#ar-05) revision 1 attempt 2, [AR-06](../../BACKLOG.md#ar-06) revision 1
attempt 1. Packets: `artifacts/audit-repair-2026-09-10/tasks/AR-05/assignment.md`,
`.../AR-06/assignment.md`. Handoffs: `artifacts/local/tasks/AR-05/handoff.json` and
`artifacts/local/tasks/AR-06/handoff.json` (read in each candidate worktree, where the ignored
`artifacts/local/` scratch actually lives).

## Verdicts

| Card | Card revision | Candidate | Verdict (PASS / PASS+NOTES / FAIL / BLOCKED / INCONCLUSIVE) | Evidence method |
| --- | --- | --- | --- | --- |
| AR-05 | 1 (attempt 2) | `3550f63561f7b80be2e3dbd13e022254c25724fd` on `wt/AR-05`, worktree `.claude/worktrees/AR-05`, base `1a4be2ddd332e99e9637bb6f2255a4144ed3866d` | **PASS+NOTES** | Own read-only git review of the candidate commit: `git log/diff/name-status -M/ls-files/cat-file/show` against the recorded base, independent `sha256sum` of all eight moved blobs in base, commit and worktree, repo-wide `git grep` for residual and live-code references, `npm run check:docs` and `npm run check:project` re-run in the candidate worktree, line-equivalence script over the whole document diff. No build, browser or native command. |
| AR-06 | 1 (attempt 1) | `2d982eb2596aa4f6ba18cb9ed0e5ad3ee9c030fe` on `wt/AR-06`, worktree `.claude/worktrees/AR-06`, base `1a4be2ddd332e99e9637bb6f2255a4144ed3866d` | **PASS** | Own filtered diff and a comment-stripped byte comparison of both scripts against base, `node --check`, `npm test` re-run in the candidate worktree (203/203), `npm run check:docs` re-run, plus source verification of every factual claim in the three changed passages (`tests/balance.mjs`, `tests/expedition-balance.mjs`, the AR-04 diff that added the five APIs, `docs/project/sprint-0/closure.json`). No build, browser or native command. |

Neither candidate is integrated or admitted by this review, and no board or canonical record was
written. No blocking finding exists for either candidate.

## Ruling on the HF-01:39 boundary question

**I do not read `docs/tech/sections/HF-01-production-conventions.md:39` as an absolute prohibition of
the AR-05 move.** The coordinator's EV-0115 reading is correct on the text and in context, and **no
amendment is required**; the sentence can stay unamended and admission may proceed on this point.

The sentence and its context:

> No row claims the served `/` or `/orchard.html`, repository `index.html` or `orchard.html`, or root
> `src/`, `server/`, `tests/`, `tools/` and `artifacts/`. Existing browser `public/`, saves, progress
> keys and private capture records also stay outside this production allocation. Do not move, import,
> reset or consolidate them. Orchard simulation, scene rendering, procedural models and input/UI
> retain their present file owners. (HF-01:39)

Grounds:

1. **Subject and function.** HF-01 is the *production path allocation* for the future native tree.
   Its table (`HF-01:23-37`) allocates `native/**` and `source-assets/**` rows; the paragraph at `:39`
   is the closing sentence of that allocation table, naming what **no row claims**. It is a statement
   of production ownership scope, not a repository-wide immutability rule over `public/`.
2. **Antecedent and verb set.** "Existing browser `public/`, saves, progress keys and private capture
   records also **stay outside this production allocation**. Do not **move, import, reset or
   consolidate** them." Every verb names an operation a native production effort could perform on
   browser-proof material: *move* it into the native tree, *import* it through Godot's asset pipeline
   (the section's own vocabulary at `:60-61` and `:72`), *reset* it, or *consolidate* the entries. The
   imperative continues the preceding clause — keep these paths out of the production allocation —
   rather than imposing a general freeze on the file.
3. **In-section scenario.** `HF-01:95`: "A writer proposes moving orchard code into `native/runtime/`.
   The protected browser boundary rejects the move even if both files would compile. Consolidation
   needs explicit approval and its own contract." The section's own example of the forbidden "move" is
   a move *into the production allocation*, not housekeeping elsewhere in the repository.
4. **What AR-05 actually did.** It moved eight PNGs with **zero live-code references** out of Vite's
   served `public/` into `docs/art/`, beside the concept studies that cite them. Nothing was imported
   into the native tree, no browser proof was consolidated, and `/` and `/orchard.html` are untouched:
   no live file references any of the eight basenames or an `art/` served path (see AR-05 DoD 4 below),
   and `public/` still exists, retaining `favicon.svg`. The move is therefore orthogonal to the
   boundary the sentence protects.
5. **The sentence stays true for its purpose.** `public/` still exists and still sits outside the
   production allocation, so `:39` remains an accurate prospective constraint. Nothing in the admitted
   sections besides `:39` mentions browser `public/` at all (checked: `adr/**`, the five admitted
   `docs/tech/sections/*.md`, `BIBLE.md`).
6. **Separate authorization exists.** AR-05 is a card revision 1 in the authorized `audit-repair` lane
   (EV-0113), and EV-0107 records Andrew's 2026-09-10 retention-wave approval of the public/art move.
   None of the frozen material was touched: `git diff --name-only 1a4be2d 3550f63 -- BIBLE.md
   docs/bible/` is empty, and the BIBLE §7 verbatim art-direction block still hashes to the recorded
   `0f694b904454716669d844e833973852c51a6ec48c719918797b06a7841322c7`.

**If it were an absolute bar**, the route would have been an amendment, not an admission: an ADR-style
request under [ORCHESTRATOR.md](../../ORCHESTRATOR.md#specification-contradictions) against an admitted
section, Andrew's decision because it would change an accepted boundary, an updated source clause plus
a revised AR-05 card reviewed together, then propagation. I state plainly that this route is **not**
needed on my reading.

One residual observation, not a blocker: `:39` is broad enough that a future reader could misread
"do not move" as covering any edit under `public/`. If the coordinator wants to remove that ambiguity,
the cheapest correct route is a TRACKING note (or a future HF-01 revision presented as a card-revision
change) — not a unilateral edit to the admitted section, and not a reason to hold AR-05.

## Ruling on the residual dated references

**Leaving every residual `public/art` reference as a dated historical record is correct. None of them
should be rewritten, and none of them can break a check.**

- **No Markdown link is affected.** `git grep -nE '\]\([^)]*public/art' <candidate>` and the image-embed
  variant `!\[[^]]*\]\([^)]*public/art` both return **nothing** anywhere in the candidate tree. Every
  residual is prose, an inline code span, or a JSON path string.
- **Checker surface.** `scripts/check-docs.mjs:97-113` scans root `*.md`, `adr/**`, `docs/**` and only
  `artifacts/**/README.md` (excluding `artifacts/local/`), and its link scan drops code spans first
  (`:126`). The residual hits land either outside that set (all `artifacts/audit-2026-09-10/lane-*.md`,
  `DISPOSITIONS.md`, `NEXT-WORK-SHORTLIST.md`, the two `swarm-prep` JSONs, `candidate-manifest.json`) or
  in an inline code span (`artifacts/audit-2026-09-10/README.md:110`, `docs/audit-2026-09-05/worker-4-universe.md`,
  `docs/decisions.tsv:3`, `TRACKING.md:359`). `npm run check:docs` exits 0 at the candidate with 3416
  local links and 0 failures, which confirms it.
- **The records' value is the dated pairing.** `artifacts/swarm-prep-2026-09-06/baseline.json` and
  `verification.json` (8 entries each), `artifacts/publication-2026-09-06/candidate-manifest.json` and
  the `lane-5-hygiene.md` byte/`du`/`sha256` measurements record *where the images were and what they
  hashed to on that date*. Repointing them would falsify evidence, which
  [ORCHESTRATOR.md:108](../../ORCHESTRATOR.md#serial-integration-and-completion) forbids ("A new
  failure or changed requirement needs a recorded reopen or new task; it does not rewrite old
  evidence"), and would break the recorded path↔`sha256` pairing in the manifests. `docs/decisions.tsv:3`
  is the append-only 2026-09-05 decision row ([CONTRIBUTING.md:73](../../CONTRIBUTING.md)); appending a
  new dated row is allowed, editing that one is not.
- **What the coordinator should do instead (no rewriting).** Append the AR-05 completion event to
  `TRACKING.md` naming the move (EV-0115/EV-0116 record the handoff and the review assignment but not
  yet the admitted outcome); close H-09 in `artifacts/audit-2026-09-10/DISPOSITIONS.md:100` as the
  disposition table owner; and, optionally, append one dated row to `docs/decisions.tsv`. The
  answerable-sounding leftovers at `artifacts/audit-2026-09-10/README.md:110` (open question 7) and
  `NEXT-WORK-SHORTLIST.md:32,81` are dated wave text — leave them; the H-09 disposition line is the
  canonical closure point.

## AR-05 findings

**Identity, base and branch — conforms.** `git log -1 --format='%H %P'` → `3550f63561f7b80be2e3dbd13e022254c25724fd 97ea8805965e2dd93748988872936b356b9bc518`;
`97ea880`'s parent is `1a4be2ddd332e99e9637bb6f2255a4144ed3866d` = the recorded base. Branch `wt/AR-05`.
`git show --stat` on the tip shows only `docs/project/ASSETS.md` (1 line), the attempt-2 correction.

**Lease — conforms.** All 19 changed paths are inside lease AR-05-L1: the eight `public/art/*.png`
sources, the new `docs/art/` directory, and the eleven tracked documents that cited them. Each of the
eleven had at least one `public/art` occurrence at base (occurrence counts 2/1/1/2/1/7/1/1/2/1/2 = 21)
and now has none — including all four files named individually in DoD 2
(`docs/CONCEPT-STUDY-0*.md`, `docs/ART-DIRECTION.md`, `docs/project/ASSETS.md`,
`docs/project/SOURCE-DISPOSITIONS.md`). No page, build configuration, code or `.gitignore` file is
touched; `git diff --name-only 1a4be2d 3550f63 -- vite.config.js package.json src server scripts tests`
is empty.

**DoD 1 — eight PNGs under `docs/` with the same names and bytes; conforms, independently reproduced.**
`git diff --name-status -M` reports **`R100` for all eight** files. Per-file `sha256` of the base blob
(`git show 1a4be2d:public/art/<n> | sha256sum`), the candidate blob and the worktree file are
**identical for 8/8**; sizes sum to exactly **22,149,367 B**. `git ls-files public/art` → 0;
`git ls-files docs/art` → 8; the on-disk `public/` holds only `favicon.svg` (291 B).

**DoD 2 — every tracked reference updated; conforms for every live reference, with the dated records
deliberately retained.** Twelve files still contain the string `public/art`; each is a dated historical
record or an inline-code mention, none is a link, and none is a live pointer (see the ruling above).
`TRACKING.md` is the one card-named file the writer did not touch; its only hit is the dated event
EV-0107, and the packet (`assignment.md:14,33`) explicitly excluded `TRACKING.md` from the lease and
required a requested shared change instead, which the handoff lists. That card-versus-packet
inconsistency is a coordinator record item, not a candidate defect.

**DoD 3 — `public/art/` no longer exists; the first half is verified, the build half is not
established here.** `git ls-files public/art` is empty and the directory is gone. The consequence "a
production build stops copying 21 MB into `dist/art/`" requires `npm run verify`, which the card
(Backlog:3466) and packet assign to the coordinator's admission and which **I did not run**: nothing in
this review establishes a post-move `dist/` tree. Documentation-level support only: `vite.config.js` is
byte-identical to base and declares no `publicDir` override, so Vite's default `public/` remains the
only copied static directory and `docs/` is not a build input; `docs/project/ASSETS.md`'s new sentence
("now live under `docs/art/`, outside the served tree, so they no longer add build weight") is
consistent with that. **The coordinator must run `npm run verify` on the integrated result and confirm
a fresh `dist/` has no `art/` directory.** Caution: the main checkout currently holds a **stale
untracked `dist/art/` (8 PNGs, `dist/` ≈ 23 MB)** left by a pre-move build; that is pre-existing output,
not candidate content, and must not be read as evidence either way — inspect a freshly built `dist/`.

**DoD 4 — no live code reference exists or was introduced; conforms, verified by search.** Across
`index.html`, `orchard.html`, `src/`, `server/`, `scripts/`, `tests/`, `vite.config.js` and
`package.json`: 0 hits for each of the six concept basenames, for `public/art`, and for any `art/`,
`"art/`, `'art/`, `/art/` or `art/0` served path. Repo-wide, no concept basename appears outside
`docs/`, `artifacts/` and `TRACKING.md`. (The only `art` hits in live code are unrelated: a local `art`
variable in `src/collection.js:308` and the module import `./art.js` at `src/world.js:18`.)

**Diff hygiene — conforms.** A line-pair equivalence script over the whole document diff compared 20
removed/added line pairs; 18 are exactly the `public/art` → `docs/art` (`../public/art` → `art`)
substitution, and the only two exceptions are the intended attempt-2 rewrite of
`docs/project/ASSETS.md:19` and its table row at `:9`. No reflow, rewrap, reorder or unrelated edit.

**Evidence receipts — consistent.** The worktree's `residual-public-art-references.txt` (12 files, with
per-file counts) matches my own `git grep -c` exactly, as do `updated-reference-counts.txt` (21 → 0),
`hash-evidence-attempt2.txt`, `check-docs.txt` and `check-project.txt` against my re-runs.

**Non-blocking notes for the coordinator (none violates the definition of done).**

1. **DoD 3 is only half established** without the coordinator's build step (above). This is by design,
   not a candidate failure.
2. **Coordinator-owned closure work remains:** append the AR-05 completion event in `TRACKING.md` (its
   EV-0107 line still calls the move a remaining retention item) and close H-09 in
   `artifacts/audit-2026-09-10/DISPOSITIONS.md:100`. Neither is in the writer's lease.
3. **DoD 2 names `TRACKING.md` while the packet excludes it.** The card's own verification clause
   ("except any deliberately recorded historical note", Backlog:3466) plus the coordinator's sole
   ownership of TRACKING resolve this; record the disposition so the next reader does not read it as an
   unmet item.
4. **Cosmetic evidence-framing error:** the handoff prose says the residual search found "11 files";
   its own receipt and my run both show **12** (the enumeration itself is complete and correct).
5. **The stale `dist/art/` in the main checkout** should be regenerated by the admission build (above)
   so the DoD 3 observation is made on post-move output.

## AR-06 findings

**Identity, base and branch — conforms.** `git log -1 --format='%H %P'` → `2d982eb2596aa4f6ba18cb9ed0e5ad3ee9c030fe 1a4be2ddd332e99e9637bb6f2255a4144ed3866d`
(parent = recorded base). Branch `wt/AR-06`. `git show --stat` → exactly three paths:
`artifacts/README.md` (+1/-0), `scripts/native-smoke.mjs` (+8/-5), `tests/expedition-balance.mjs` (+9/-6).

**Lease — conforms.** All three changed paths are the three leased paths (`assignment.md:11-13`). No
other file is touched; `git status --porcelain` is empty in the worktree.

**DoD 4 / comment-only claim — independently tested, holds.** My filtered diff
(`git diff -U0 <base>..<candidate> -- <script> | grep -E '^[+-]' | grep -v '^[+-][+-]' | grep -vcE '^[+-][[:space:]]*//'`)
returns **0 non-comment changed lines** for `tests/expedition-balance.mjs`, **0** for
`scripts/native-smoke.mjs`, and **0** for both together. The stricter line-pair check gives the same
result: 6 removed/9 added lines in the gate and 5/8 in the harness — 28 changed lines, **0** of which
fall outside comment blocks (matching EV-0114). Stronger still: after stripping `//`-comment lines,
each candidate script is **byte-identical** to its base version (expedition 6801 → 7017 bytes,
native-smoke 26578 → 26773 bytes, stripped forms equal), so no executable statement, assertion,
threshold, message string or regex alternative could have changed.

**Forbidden-API regex — byte-identical to base.** `diff <(git show 1a4be2d:scripts/native-smoke.mjs | ...) <(git show 2d982eb:...)`
for `export const forbiddenNetworkingClasses = ...` is empty; the regex line's `sha256` is
`16082d820754e7e8c7e825f500374159f2d5c9e1293eb301c85e02c42a39b37b` at both revisions. The list is not
extended: `MultiplayerSpawner` and `MultiplayerSynchronizer` remain absent. `node --check` passes for
both scripts.

**DoD 1 (AR-03 comments) — accurate against the code.** `tests/balance.mjs:14,26,31` do exactly what
the new comment says: probe starts at `waypoint = 3`, advances at `d < 0.65`, calls `g.dash()` when
`d > 3`. `tests/expedition-balance.mjs:32,95,96-98` confirm the contrast: the gate starts at
`waypoint = 0`, advances at `d < 1`, reverses at the ends, and contains **no** `dash()` call (the only
`dash` tokens in the file are the two comment lines). The corrected defect statement matches the
accepted review: the removed line was `waypoint = (waypoint + 1) % route.length` at `01a1e63^`,
which wraps last→first and still visited every waypoint; the review's instrumented control
(`review-wave-ar03-ar04.md:62-67`) records "all 20 waypoints are still visited" and names the real
defect as the unpublished straight leg — exactly what the new comment now says. The overstatement
("stop patrolling the geometry") and the approximate "the probe's traversal" claim are both gone.

**DoD 2 (AR-04 comment) — accurate and no list extension.** The AR-04 candidate diff
(`git diff d4eadf0^..d4eadf0 -- scripts/native-smoke.mjs`) shows AR-04 added exactly five alternatives —
`MultiplayerPeer`, `WebRTC`, `SceneMultiplayer`, `DTLSServer`, `UPNP` — to the pre-existing
transport/peer set, which is what the new comment states. The comment drops "every … replication
class" and names what is absent (`MultiplayerSpawner`, `MultiplayerSynchronizer`), satisfying the DoD
either-way requirement without touching the regex.

**DoD 3 (`artifacts/README.md`) — accurate against `docs/project/sprint-0/closure.json`.** The receipt
cites the path exactly once, as `retroActions[4].reference` —
`"artifacts/local/sprint-0/final/dispatch-validation.json"` (closure.json:75), whose cause is
"GitHub rejected runner.temp in job-level env before job execution" and whose disposition names the
final S0-09 revision. No `sha256` for that path exists anywhere in the tracked tree (repo-wide
`git grep -n 'dispatch-validation'` finds the closure citation, the AR-06 card text, an earlier wave
review, a shortlist line, and the packet — no pin). The new bullet therefore names the path, links the
closure receipt, calls it unpinned, and is inserted in the established style with **no existing line
reworded, reordered or removed** (`+1/-0`). This is the third accepted follow-up carried forward at
EV-0104/EV-0112.

**Verification evidence — reproduced.** `npm test` in the candidate worktree exits **0** with
`tests 203 / pass 203 / fail 0 / cancelled 0 / skipped 0 / todo 0` (matches the handoff), and the
worktree is still clean afterwards. `npm run check:docs -- --report /tmp/ar06-check-docs.json` exits
**0**: 124 Markdown files, 3417 local links, 81 cards, 112 events, 0 failures (one more link than the
AR-05 tree, as expected from the added README bullet).

**Note (evidence limit, not a candidate defect).** I could not produce a fresh base-tree suite count: a
`git archive` copy under `/tmp` is not a git checkout, and `tests/native-smoke.test.js` derives
untracked files through git, so that run fails for environmental reasons unrelated to the candidate.
The base count is instead established by construction — every test file is unchanged between base and
candidate, and the executable content of both changed scripts is byte-identical after comment removal —
and corroborated by EV-0112 (203 pass at the integrated AR-04 result) and EV-0114 (the coordinator's
own 28-changed-lines / 0-non-comment check).

## Independent checks performed — exact command → observed result

Worktree root for AR-05 commands: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-05`;
AR-06: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-06`; base `1a4be2d` =
`1a4be2ddd332e99e9637bb6f2255a4144ed3866d`.

| Command | Observed result |
| --- | --- |
| AR-05 `git log -1 --format='%H %P'`; `git log -2 --format='%H %P %s'` | `3550f63… 97ea880…`; `97ea880… 1a4be2d…` — candidate parent chain reaches the recorded base |
| AR-06 `git log -1 --format='%H %P'` | `2d982eb… 1a4be2d…` — parent equals the recorded base |
| AR-05 `git status --porcelain`; AR-06 `git status --porcelain` | empty in both (checked before and after every run) |
| AR-05 `git show --stat HEAD`; `git diff --stat -M 1a4be2d 3550f63` | tip = 1 file/1 line; full candidate = 19 files, 20 insertions/20 deletions |
| AR-06 `git show --stat HEAD` | 3 files, 18 insertions/11 deletions |
| AR-05 `git diff --name-status -M 1a4be2d 3550f63` | 8 × `R100` (`public/art/*` → `docs/art/*`) + 11 × `M` (documents); no other status |
| AR-05 per-file `git show 1a4be2d:public/art/<n> \| sha256sum` vs `git show 3550f63:docs/art/<n> \| sha256sum` vs `sha256sum docs/art/<n>` | 8/8 OK, base = candidate = worktree; total bytes 22,149,367 |
| AR-05 `git ls-files public/art \| wc -l`; `git ls-files docs/art`; `git ls-files public/` | `0`; the eight `docs/art/*.png`; only `public/favicon.svg` |
| AR-05 `ls public/`; `ls docs/art/` | `favicon.svg` (291 B) only; eight PNGs with base sizes |
| AR-05 live-code search: `git grep -F` for six basenames, `public/art`, `"art/`, `'art/`, `/art/`, `art/0` over `index.html orchard.html src server scripts tests vite.config.js package.json` | 0 hits for every pattern; sanity control `git grep -l import` over the same set = 50 files |
| AR-05 `git grep -l <basename>` repo-wide | no basename outside `docs/`, `artifacts/`, `TRACKING.md` |
| AR-05 `git grep -n 'public/art' 3550f63` | 12 files, counts `1,4,2,1,21,11,4,8,8,8,11,1` — all interpreted prose/code-span/JSON, none a link |
| AR-05 `git grep -nE '\]\([^)]*public/art'` and the `![…]` variant | no matches anywhere in the candidate tree |
| AR-05 `npm run check:docs` (candidate worktree) | exit 0 — 124 Markdown files, 3416 local links, 81 cards, 112 events, 6 sections, 7 interim rows, 0 failures |
| AR-05 `npm run check:project` (candidate worktree) | exit 0 — 104 Markdown files, 2019 file links, package/lock metadata |
| AR-05 base occurrence count (python `git show` count) and candidate `git grep -c` | 21 occurrences across the 11 updated files at base; 0 in the same files at candidate |
| AR-05 line-pair equivalence over the whole `docs/` diff (python) | 20 pairs compared, 18 pure path substitutions, 2 expected ASSETS.md rewrites, 0 unexplained |
| AR-05 `git diff --name-only 1a4be2d 3550f63 -- BIBLE.md docs/bible/`; BIBLE §7 block `sha256` (python) | empty; `0f694b90…22c7` at both base and candidate = the recorded lock hash |
| AR-06 `git diff -U0 1a4be2d..2d982eb -- <script> \| grep -E '^[+-]' \| grep -v '^[+-][+-]' \| grep -vcE '^[+-][[:space:]]*//'` | `0` for the gate, `0` for the harness, `0` for both together (no surviving non-comment lines) |
| AR-06 comment-stripped comparison (python, `git show` both revisions) | byte-identical after removing `//` lines for both scripts |
| AR-06 regex identity: `diff` of the `forbiddenNetworkingClasses` block + `sha256sum` of the regex line | empty diff; `16082d82…b37b` at base and candidate |
| AR-06 factual source checks: `tests/balance.mjs:14,26,31`; `tests/expedition-balance.mjs:32,95-98`; `git show 01a1e63^:tests/expedition-balance.mjs`; `git diff d4eadf0^..d4eadf0 -- scripts/native-smoke.mjs` | probe starts at 3 / `d<0.65` / dashes at `d>3`; gate starts at 0 / `d<1` / no dash; pre-AR-03 code was `% route.length`; AR-04 added exactly the five named APIs |
| AR-06 `node --check tests/expedition-balance.mjs`; `node --check scripts/native-smoke.mjs` | both exit 0 |
| AR-06 `npm test` (candidate worktree) | exit 0 — tests 203, pass 203, fail 0, cancelled 0, skipped 0, todo 0 |
| AR-06 `npm run check:docs -- --report /tmp/ar06-check-docs.json` | exit 0 — 124 Markdown files, 3417 local links, 81 cards, 112 events, 0 failures |
| `grep -n 'dispatch-validation' docs/project/sprint-0/closure.json`; python JSON walk; repo-wide `git grep` | single citation at `retroActions[4].reference` (line 75); no `sha256` pin anywhere |

## Uncertain or unverifiable

- **AR-05 DoD 3's build half.** No build was run (forbidden to me by instruction). It is **not
  established** that a production build no longer emits `dist/art/`; that remains the coordinator's
  `npm run verify` step on the integrated result. The pre-existing untracked `dist/art/` in the main
  checkout is stale pre-move output and proves nothing.
- **`npm run check:scope`.** Not in my permitted command set, so I did not run it; the writer's
  `check-scope-attempt2.txt` (documentation-only, 19 paths, no build selected) is its evidence, not
  mine. I verified its factual premise independently: no code path changed.
- **A fresh base-tree `npm test` count.** Environmentally blocked (see the AR-06 note); base/candidate
  equivalence is established by byte-level construction instead.
- **Anything outside static/documentation review.** No browser, Godot/native, network or build
  behavior was exercised for either candidate; no human feel, hardware or production qualification is
  claimed or implied.
- **Historical accuracy of the residuals themselves** (e.g. whether every `docs/audit-2026-09-05`
  citation was accurate on that date) was not re-derived; I verified only that they are dated records,
  not live pointers, and cannot break a check.

## Method and limits

- **Method.** Read-only git inspection of the exact candidate commits against the recorded base,
  independent object hashing (`git show … | sha256sum`) rather than trusting the handoffs, repo-wide
  and scoped searches for residual/live references, python line-level equivalence and source-stripping
  proofs, plus fresh re-runs of the card-mandated documentation checks and the AR-06 test suite. This
  is a static evidence review of two documentation-and-comment candidates; it is one independent
  opinion ([ORCHESTRATOR.md:90](../../ORCHESTRATOR.md#handoff-and-review)).
- **Disclosure.** Running `npm run check:docs` in the AR-05 worktree regenerated its own git-ignored
  scratch report `artifacts/local/check-docs/report.json`; no tracked file changed there
  (`git status --porcelain` empty, HEAD still `3550f63`). In the AR-06 worktree, `npm test` was run in
  place and `check:docs` was directed to `/tmp`; no tracked file changed (status empty, HEAD still
  `2d982eb`). Neither worktree, branch, index nor canonical record was modified; the only file written
  by this review is this report.
- **Limits.** A passing static check cannot substitute for the coordinator's admission checks on the
  integrated result, and a comment-only diff review cannot qualify runtime behavior. `check:docs`
  validates link existence and anchors, not content correctness. The AR-05 build-copy effect and the
  AR-06 base-vs-candidate suite count are the two items this review leaves to the coordinator's own
  evidence; neither is a candidate failure.
