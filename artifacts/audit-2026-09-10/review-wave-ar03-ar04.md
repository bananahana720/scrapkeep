# Wave review — AR-03 and AR-04

Fresh independent reviewer (did not write either candidate). One wave review, two disjoint write
sets, one verdict per candidate (`ORCHESTRATOR.md` → Handoff and review, wave-review rule). Read-only
on both worktrees and on the main checkout; the only file written is this report.

## Verdicts

| Card | Card revision | Candidate | Verdict (PASS / PASS+NOTES / FAIL / BLOCKED / INCONCLUSIVE) | Evidence method |
| --- | --- | --- | --- | --- |
| AR-03 | 1 | `01a1e631ab67e14768d9a10ff1c260b7472fc58a` on `wt/AR-03` | **PASS+NOTES** | Fresh run of the gate in the candidate worktree + `node --test tests/*.test.js`; independent scratch copies of `src/` + gate with `PATH` mutated two ways; instrumented pre-fix gate controls for the baseline claim. |
| AR-04 | 1 | `d4eadf0e83a11107c54c1467c84559745a19f9d5` on `wt/AR-04` | **PASS+NOTES** | Fresh `node --test tests/native-smoke.test.js` (21 pass) and full suite (203 pass); direct `repositoryFiles`/`networkingScan`/`networkingGrep` calls; the pre-change (base) module imported into a scratch harness against the planted fixtures; report-vs-tree cross-check. |

Both candidates are inside their leases, both worktrees are clean, and both changed-path sets are
disjoint, so the single-reviewer wave rule applies. Notes below do not violate either definition of
done; they are disclosures for the coordinator.

## AR-03 findings

**Identity and lease — conforms.** `git log -1 --format='%H %P'` in
`.claude/worktrees/AR-03` → `01a1e631ab67e14768d9a10ff1c260b7472fc58a 642afe0eadd9a7f97c3bd1352609faf8560f70d5`
(parent = recorded base). `git show --stat` → one changed path, `tests/expedition-balance.mjs`
(+102/−32). `git status --porcelain` empty before and after this review. The changed path is the
leased file (`tests/balance.mjs` was optional and was correctly left alone — it does not duplicate
the route: it imports `PATH` at `tests/balance.mjs:1` and indexes it at `:22`).

**Boundary — conforms.** `git diff 642afe0e 01a1e63 -- src/` is empty; `PATH` and every gameplay
value are untouched.

**DoD 1 — the asserted route derives from `PATH`; conforms, independently reproduced.**
`tests/expedition-balance.mjs:1` imports `PATH`; `:14-20` `patrolRoute(source = PATH)` returns a
point-for-point copy of the binding; `:27` makes it the default route of `simulate`; `:129-133`
asserts `route` deep-equals `PATH`. I did not accept the writer's demo: I copied the candidate
worktree's `src/` and gate into a scratch tree and mutated the scratch `PATH` only.
- Scratch `PATH` + the midpoint of its final segment (`[6, 8]`, 21 points): a scratch probe
  printed `{shippedPoints: 21, derivedPoints: 21, first: [-12,-7], last: [6,8]}` — the derived route
  follows the mutated binding. The same scratch gate then **exits 1** with
  `AssertionError … safe patrol must complete the expedition` — the drift is noticed rather than
  silently absorbed.
- Scratch `PATH` with `PATH[0]` moved `[-12,-7] → [-10,-7]`: gate exits 0, and the asserted runs
  consume the changed geometry (safe ending bases `[100, 45, 29]`, risk 2 loss / 7 win, versus the
  shipped `[31, 52, 117]` and 7/2). `src/game.js` was never modified in the repo.

**DoD 2 — probe and gate share one geometry; conforms.** Both consume the `src/game.js` `PATH`
binding. (Traversal parameters still differ; see note 2.)

**DoD 3 — assertions still pass; conforms.** `node tests/expedition-balance.mjs` in the worktree
exits 0: idle 3/3 gameover, safe patrol 3/3 victory, risk 7 loss / 2 win, 15 runs, every run
terminates, all 12 patrol runs report 20 route points and `visited` exactly `[0…19]`.

**Baseline shift — verified, and the control claim is confirmed.** Re-running the **pre-fix** gate
(`git show 642afe0e:tests/expedition-balance.mjs`) reproduces the writer's "before" profile exactly:
idle 3/3, safe 3/3 with bases `[100, 100, 125]`, risk 2/7. The candidate reproduces the "after"
profile exactly: safe bases `[31, 52, 117]`, risk 7/2. Control: appending one waypoint (`[-11,0.5]`)
to the pre-fix gate's hard-coded 18-point route makes the pre-fix gate exit 1 on
`risk play must be able to lose` (risk 0/9, i.e. red). The writer's brittleness-control claim is
therefore **verified, not merely asserted**: sensitivity to a one-point route change pre-dates this
candidate.

**What the traversal change does and does not change (extra control I ran).** I instrumented the
pre-fix gate to record arrivals:
- Pre-fix geometry + modulo wrap: all 18 waypoints visited.
- Shipped `PATH` + modulo wrap: all 20 waypoints are still visited (arrivals ≈ 1100–1490 per run);
  the wrap does not strand the player. So the in-code comment at `:84-87` ("would … stop patrolling
  the geometry it claims to patrol") **overstates** the defect. The real defect is the unpublished
  straight leg from the last shipped point back to the first, once per lap — the player still touches
  every waypoint but leaves the published route between them.
- The traversal change is load-bearing for the assertion set, and the baseline shift is
  geometry-driven: shipped `PATH` with the **old** modulo wrap yields safe bases `[100, 100, 125]`
  but risk **0/9**, which would fail the pre-fix assertions (red); the candidate's end-to-end
  traversal on the **old** 18-point route yields risk 3/6 with safe bases unchanged at
  `[100, 100, 125]`. Only the candidate's combination (real geometry + end-to-end traversal) passes
  all four assertions. The four predicates are textually identical to the base ones on the same
  15-run sample/seed set/upgrade priority/1600 s cap, so they still mean what they meant; what moved
  is the geometry they evaluate, exactly as audit L6-05 anticipated.

**No weakened checks.** `git diff … | grep '^-'` removes only: the old import line, the hard-coded
18-point route, the modulo-wrap arrival block, three assertion lines that are re-added with the same
predicates plus messages (`:147-164`), and the old `note` string. The fourth balance assertion (idle)
and the termination assertion are untouched context. No assertion was skipped, loosened or made
conditional; the sample of 15 runs is unchanged.

**Evidence honesty — confirmed.** Two fresh gate runs are identical apart from `wallSeconds`, and
the fresh output equals the writer's `artifacts/local/tasks/AR-03/candidate-expedition.json` exactly
(ignoring `wallSeconds`).

**Notes (non-blocking).**
1. The new baseline (`risk 2/7 → 7/2`; safe bases `100/100/125 → 31/52/117`) is a real change to the
   asserted profile and is now a **nearer cliff** for the win assertion (scavenger ends at base 31).
   Audit L6-05 required the acceptance to re-run the gate and record the new baseline; the handoff
   records it and this review verified it, so the coordinator should accept it explicitly when
   admitting, and record it in the board evidence.
2. The comment at `:82-83` says "with the probe's traversal in `tests/balance.mjs`". The *geometry*
   is shared (DoD 2 satisfied), but the traversal parameters are not identical: the probe starts at
   waypoint 3, advances at `d < 0.65` and dashes when `d > 3` (`tests/balance.mjs:14,26,31`); the
   gate starts at 0, advances at `d < 1` and never dashes. The descriptor is approximate.
3. `:125` keeps the pre-existing filename-based entry guard; renaming the file disables the gate
   silently. Pre-existing and outside this card's scope (the writer reports it too).
4. `simulate` remains exported with a new optional 5th parameter; no module imports it, so nothing
   is broken (audit L6-08 records it as dead API surface).

## AR-04 findings

**Identity and lease — conforms.** `git log -1 --format='%H %P'` in `.claude/worktrees/AR-04` →
`d4eadf0e83a11107c54c1467c84559745a19f9d5 642afe0eadd9a7f97c3bd1352609faf8560f70d5`. Eight changed
paths, all inside lease AR-04-L1: `scripts/native-smoke.mjs`, `tests/native-smoke.test.js`, six new
files under `tests/fixtures/native-smoke/planted/`. Worktree clean before and after this review
(including after the suite, which creates and removes its own `derived/` fixture).

**Boundary — conforms.** `git diff 642afe0e d4eadf0 -- native/` is empty; no engine change.

**DoD 1 — repository-derived file list; conforms.** `scripts/native-smoke.mjs:155-157`
(`derivationCommand`) and `:159-181` (`repositoryFiles`) run
`git ls-files -z --cached --others --exclude-standard -- <dir>`, and `:222-229` (`networkingScan`)
feeds the result to the scan that `main()` now calls at `:746`. No extension filter and no
hard-coded list remains. Observed coverage: **32 of 32** tracked files under `native/`, and my
independent `git ls-files -z --cached --others --exclude-standard -- native` returned the identical
32-path set (the check's `scannedFiles` equals it). The pre-change filter covered **17** (16 `.gd` +
`project.godot`) of the 32, so the card's "16 of 32" counts scripts only and the handoff's correction
to 17 is right. The new list also includes non-script files (`native/README.md`,
`native/export_presets.cfg`, `.uid`, `.tscn`, `.tres`, `.json`).

**DoD 2 — five APIs in the forbidden set; conforms.** `scripts/native-smoke.mjs:35-36` exports
`forbiddenNetworkingClasses` =
`HTTPRequest|ENet|WebSocket|MultiplayerAPI|PacketPeer|StreamPeer|HTTPClient|UDPServer|TCPServer|MultiplayerPeer|WebRTC|SceneMultiplayer|DTLSServer|UPNP`.
All nine pre-existing families are retained and the five named APIs are added. No removals.

**DoD 3 — planted fixture fails, real tree passes, count stated; conforms, reproduced.**
`networkingScan("tests/fixtures/native-smoke/planted")` → `status: "fail"` over 6 scanned files with
the exact message `networking class named at tests/fixtures/native-smoke/planted/planted_dtls_server.txt:2:DTLSServer,
… planted_multiplayer_peer.txt:2:MultiplayerPeer, … planted_prose_note.md:3:ENet,
… planted_scene_multiplayer.txt:2:SceneMultiplayer, … planted_upnp.txt:2:UPNP, … planted_web_rtc.txt:2:WebRTC`;
`networkingScan("native")` → `status: "pass"`, `no networking class named in 32 scanned files`.

**Pre-change blindness — demonstrated, not assumed.** I imported the base module
(`git show 642afe0e:scripts/native-smoke.mjs`) into a scratch harness whose only edit was an appended
probe block: it walked all 6 planted files, the legacy extension filter kept **0**, and its
`networkingGrep` returned `status: "pass"`, `detail: "no networking class named in 0 scanned files"`
— the pre-change check passes a directory full of planted networking classes. Separately, the legacy
regex matches only `planted_prose_note.md` among the 6 walked files (its `ENet` alternative), and
that file was excluded by the legacy extension filter; the five new symbols match the legacy regex
nowhere. So the old check was blind twice over: by extension and by symbol list.

**Empty list now fails.** `networkingGrep([])` → `status: "fail"`, `scannedFiles: []`,
`detail: "no file was derived for the native networking scan; an unread tree cannot pass"`
(`:205`, `:215`). The condition is in the check status itself, and `main()` derives the overall
verdict from every check status, so an empty derivation cannot pass vacuously.

**No weakened checks.** `git diff --numstat` for the test file is 153 insertions / 1 deletion (the
import line); the script is 71/19. Every removed line is the superseded old regex, old extension
filter, old hit format, old status/detail expressions, or the now-unused `const files = sourceFiles;`
(`sourceFiles` is still used for `hashFiles`), and no existing test was deleted. The check also got
strictly stronger: a wider file list, five more symbols, a class name in each hit, and the empty-list
failure.

**Evidence honesty — confirmed as far as static cross-checking goes.** The writer's
`artifacts/local/tasks/AR-04/native-smoke.txt` shows 12/12 PASS including
`networking-grep … no networking class named in 32 scanned files`, and
`artifacts/local/native-smoke/report.json` has `sourceCommit:
d4eadf0e83a11107c54c1467c84559745a19f9d5`, `sourceDirty: false`, `verdict: "pass"`, 12 checks all
pass, and a `networking-grep.scannedFiles` list that equals my independent derivation of the
candidate tree. Its `generatedAt` (17:20:12Z) is 8 s after the commit timestamp (17:20:04Z). I did
**not** rerun `npm run native:smoke` (Godot) because it is outside the reviewer's allowed command
set; see "Uncertain or unverifiable".

**Notes (non-blocking).**
1. The new comment at `:30-34` says the list carries "Every transport, peer and replication class the
   offline-solo decision excludes", but `MultiplayerSpawner` and `MultiplayerSynchronizer` — Godot's
   replication nodes, and `adr/TADR-005-networking-scope.md` excludes replication — are absent. The
   card named exactly five APIs and the DoD is met; the comment is the overstatement. The writer
   records the same gap as an observation. If the coordinator wants the list to match its own
   comment, that is a follow-up card, not a change to this candidate.
2. Hit lines changed format from `path:line` to `path:line:Class`; no code parses the old format
   (only historical report artifacts contain the string) and the report schema key set is unchanged.
3. New intended behavior: untracked, non-ignored files under `native/` are scanned, so a developer's
   stray scratch file there can now fail the smoke. That is what stops a new file from escaping.
4. `artifacts/local/tasks/AR-04/native-scan-evidence.txt` lists `native/project.godot` among
   "non-script files now scanned", but the old filter already scanned `project.godot`; the true
   newly-scanned count is 15, which the handoff states correctly. Cosmetic evidence-framing error.

## Independent checks performed — exact command → observed result

Read-only git (run from `/home/andrew/Projects/scrapkeep`):

| Command | Observed result |
| --- | --- |
| `git -C .claude/worktrees/AR-03 log -1 --format='%H %P'` | `01a1e631ab67e14768d9a10ff1c260b7472fc58a 642afe0eadd9a7f97c3bd1352609faf8560f70d5` |
| `git -C .claude/worktrees/AR-04 log -1 --format='%H %P'` | `d4eadf0e83a11107c54c1467c84559745a19f9d5 642afe0eadd9a7f97c3bd1352609faf8560f70d5` |
| `git -C <worktree> status --porcelain` (both, before and after) | empty |
| `git show --stat 01a1e63` | 1 path, `tests/expedition-balance.mjs` +102/−32 |
| `git show --stat d4eadf0` | 8 paths; script +71/−19, test +153/−1, 6 new fixtures |
| `git diff --name-only 642afe0e 01a1e63` | `tests/expedition-balance.mjs` only |
| `git diff 642afe0e 01a1e63 -- src/` | empty |
| `git diff --name-only 642afe0e d4eadf0` | the 8 leased paths only |
| `git diff 642afe0e d4eadf0 -- native/` | empty |
| `git diff 642afe0e <cand> \| grep '^-'` (both) | only superseded/substituted lines; no assertion, test or check removed |
| `git ls-files -- native` count | 32 tracked; 16 `.gd` + 1 `project.godot` passed the old filter |

Behavioural checks (run inside each candidate worktree, which is the only tree that contains the
candidate; `node_modules` resolves up to the main checkout and was not modified):

| Command | Observed result |
| --- | --- |
| `node tests/expedition-balance.mjs` (AR-03 worktree) | exit 0; 20-point route from `src/game.js PATH`; idle 3/3 gameover; safe 3/3 victory bases `[31,52,117]`; risk 7/2; all terminate; every patrol run `routePoints=20`, `visited=[0…19]` |
| same, run twice and compared | identical apart from `wallSeconds`; identical to `artifacts/local/tasks/AR-03/candidate-expedition.json` |
| `node --test tests/*.test.js` (AR-03 worktree) | exit 0; tests 193, pass 193, fail 0 |
| `node --test tests/native-smoke.test.js` (AR-04 worktree) | exit 0; tests 21, pass 21, fail 0 |
| `node --test tests/*.test.js` (AR-04 worktree) | exit 0; tests 203, pass 203, fail 0 |
| `node --check` on the three changed JS files | syntax OK |
| `repositoryFiles("native")` via the candidate module | 32 absolute paths; set equals my `git ls-files` derivation |
| `networkingScan()` (native) | `pass`, `no networking class named in 32 scanned files`, derivation `git ls-files -z --cached --others --exclude-standard -- native` |
| `networkingScan("tests/fixtures/native-smoke/planted")` | `fail` over 6 files with the quoted 6-hit message |
| `networkingGrep([])` | `fail`, `scannedFiles: 0`, `no file was derived … an unread tree cannot pass` |
| `report.json` networking-grep `scannedFiles` vs independent derivation | equal (32); `sourceCommit = d4eadf0e…`, `sourceDirty: false`, 12/12 checks pass |

Scratch controls (each in a single disposable scratch tree; the repo and both worktrees were not
written; private `/tmp` is per-command here, so each control was built and run in one command):

| Control | Observed result |
| --- | --- |
| Candidate `src/`+gate copy, scratch `PATH` + midpoint of final segment (21 points) | probe: `shippedPoints 21, derivedPoints 21, last [6,8]`; gate exit 1, `AssertionError … safe patrol must complete the expedition` |
| Candidate copy, scratch `PATH[0] = [-10,-7]` | gate exit 0; safe bases `[100,45,29]`, risk 2/7 — the derived route and the asserted outcomes both moved |
| Pre-fix gate (`642afe0e` copy) as shipped | idle 3/3; safe 3/3 bases `[100,100,125]`; risk 2/7 |
| Pre-fix gate + one waypoint `[-11,0.5]` appended to its 18-point route | exit 1 on `risk play must be able to lose` (risk 0/9) — writer's brittleness control verified |
| Pre-fix gate, shipped `PATH` substituted, modulo wrap kept, asserts neutered | safe 3/3 bases `[100,100,125]`; risk 0/9; all 20 waypoints visited — would be red under the pre-fix assertions |
| Candidate gate, end-to-end traversal, old 18-point route | safe 3/3 bases `[100,100,125]`; risk 3/6; visited 18 |
| Base module (`642afe0e` script) imported with an appended probe against the candidate's planted fixtures | walked 6, legacy filter kept 0, legacy `networkingGrep` → `pass` / `0 scanned files`; legacy regex matched only `planted_prose_note.md` among the 6 |

## Uncertain or unverifiable

- **`npm run native:smoke` was not rerun by this reviewer.** It is outside the reviewer's allowed
  command set (it runs the Godot binary). What the writer's evidence establishes: the report names the
  candidate as `sourceCommit` with a clean tree, its scan list equals the tree I independently
  derived, and its 12 checks pass — i.e. the evidence is internally consistent with this candidate.
  What it does not establish: that I observed that execution, nor any export, renderer, input, feel
  or hardware qualification (the report's own `limits` say the same). The check remains
  hardware-dependent, writer-reported evidence.
- **AR-03 baseline acceptance is a judgement, not a fact.** The four assertions pass and the shift is
  verified and pre-figured by audit L6-05, but whether the new profile (`risk 7/2`; safe ending base
  31 for scavenger) is an acceptable balance statement for the asserted gate is the coordinator's
  recorded decision, not something this review can settle.
- **`npm run verify` was not run for either candidate** (AR-03's path classifies as tooling, so its
  admission requires it; `npm run build`/browser checks are outside this review).
- **Probe/gate coupling is by shared import, not by an assertion inside the probe.** `tests/balance.mjs`
  is unchanged, so nothing would fail if a future edit re-hard-coded a route in the probe; the card's
  requirement is that the two *use* the same geometry, which they do today.
- The `native:smoke` run's Godot binary hash/version pin was read from the report, not recomputed
  against the binary.

## Method and limits

- Reviewer is fresh and wrote neither candidate; read-only git only, no git mutation in the repo or
  either worktree, no `npm run verify`, no build, no browser/Playwright, no installs, no network, no
  Godot execution, and no edit outside this report.
- The candidate worktrees have no `node_modules` of their own; running the test scripts there
  resolved dependencies upward to the main checkout's `node_modules` without modifying it. Test
  suites were run with `node --test` directly (equivalent to `npm test`) because `npm test` in a
  worktree would use the same binaries; the counts (193 and 203) match the handoffs.
- All mutating experiments ran in disposable scratch trees containing copies of the candidate or base
  files; `src/game.js` was never modified in the repository, and the only edits to copies were the
  documented `PATH`/route perturbations and, where stated, assertion neutering in controls.
- Evidence classes: source inspection, deterministic script execution, scratch-fixture controls and
  static report cross-checks. No human play, no physical hardware, no browser, no native execution.
  AR-03's balance numbers are automated-simulation results, not human feel or balance judgement.
- One reviewer is one independent opinion; the coordinator still owns admission, the `verify` gate
  and the board record.
