# Consolidated dispositions — deslop audit 2026-09-10

Base `main` @ `b61feb1`. Sources: `parent-findings.md` + `lane-*.md` (this directory).
Lane status: **5 hygiene = landed**, 1 worktrees / 2 recovery / 3 canonical / 4 docs / 6 code = pending.
This file is disposable planning evidence (`artifacts/local/`), not a canonical record.

## A. Approved reversible cleanup — gate PASSED, execution deferred until lanes stop reading those paths

| # | Action | Scale | Reversibility | State |
| --- | --- | --- | --- | --- |
| A1 | Remove 7 verified-merged worktrees (`HF-01/02/03a`, `S0-09/11/12/13-operational`) | ~2.2 GB | content verified upstream by patch-id; re-creatable from `main` | ready (`cleanup-dry-run.sh` exit 0) |
| A2 | Delete 10 merged branch refs (`wt/S0-01/04/05/07`, `wt/PS-01…05b`) | 0 B, 10 refs | requires `-D` (upstream by patch-id, not ancestry); nothing unique | ready |
| A3 | `git worktree prune` in `test-game-2` (15 stale `/tmp` registrations) | metadata only | regenerable | ready |
| A4 | Strip generated output: `dist/`, worktree `node_modules/`, one `.godot/` | ~205 MB | rebuildable from lockfile | ready |
| A5 | ~~Copy 3 small evidence dirs out of `test-game-2`~~ | — | **WITHDRAWN after inspection** — see below | withdrawn |
| A6 | **19 safety tags `audit-2026-09-10/*`** pinning every non-main branch tip (lane 1's reversibility requirement) | 0 B | deleting a tag is trivial; makes the 7 `branch -D` reversible | **DONE and verified** (19/19 match their branch tips) |
| A7 | Regenerate `cleanup-dry-run.out` from the corrected planner (lane 1 W-07) | — | — | **DONE** (gate PASS, `node_modules` now `KEEP`) |

**Not in scope, per decision D1:** tracked evidence, historical artifacts, art, canonical restructuring.
**Excluded from removal:** `wt/HF-04a`, `wt/HF-05` (parked unadmitted candidates), `test-game-2` itself
(sole home of branch objects + 1.4 GB unique local evidence), live `node_modules/`.

## A0. Execution result (2026-09-10)

| # | Action | Outcome |
| --- | --- | --- |
| A1 | Remove 6 merged worktrees | **DONE** — directories gone |
| A2 | Delete 10 loose branch refs + 6 worktree branch refs | **DONE** — `git branch` now holds only `main`, `wt/HF-04a`, `wt/HF-05`, `wt/S0-09-operational` |
| A4 | Strip generated output | **DONE** for the 6 removed worktrees and S0-09's `node_modules`/`dist` (102 MB) |
| A6 | 19 safety tags | **DONE** — all 19 resolve; every deleted tip is still reachable |
| A3 | `git worktree prune` in `test-game-2` | pending (different clone, not yet touched) |
| A5 | Copy 3 small evidence dirs out of `test-game-2` | pending |

**Reclaimed: 43,758 MB → 42,616 MB (~1.14 GB)** across the Projects tree. Held deliberately:
`wt/HF-04a`, `wt/HF-05` (parked candidates) and `wt/S0-09-operational` (its 889 MB of unique Godot
exports await the owner decision on W-05).

**Post-cleanup verification (all passed):** 4 worktrees registered as expected; owner changes intact
(` M TRACKING.md`, `?? …/HF-04a/attempt-1/`); parked candidate blobs unchanged
(`ae84e607…`, `8ceb841d…`); all 19 tags resolve to commits; `git fsck` silent; `npm run check:docs`
still exits 0 with `0 failures`, so the cleanup broke no documented link.

**Hazard discovered and recorded (S2, operational).** `git worktree remove` on a path outside the
session workspace **fails part-way**: it deletes the `.git/worktrees/<name>` admin metadata (inside
the workspace, writable) and then fails to delete the directory itself (outside, read-only). The
result is an **orphaned 173 MB checkout that git no longer tracks** — `git worktree list` looks
clean while the bytes remain. Detected only by re-checking the filesystem rather than trusting the
tool's exit path. Anyone repeating this cleanup on a sandboxed host must verify the directories are
actually gone, not just absent from `git worktree list`.

## A0b. Corrections and recovery applied (approved 2026-09-10)

- **`staged/canonical-corrections.patch` applied** — all 9 corrections. Commit `80fc004` for the six
  non-board files; the TRACKING.md portion rode with the recovery commit below.
- **Recovery recorded in `00f64e2`** — EV-0093 coordination transfer (model/effort substitution
  reported, not silently chosen), EV-0094 HF-05-A1 handoff (candidate `ea522c3`, sha256 `7ef95df2…`,
  126 checks, HF-05-L1 closed), EV-0095 fresh wave reviewer assignment. HF-05 row → `review`, record
  revision 5. Both attempt-1 receipt sets retained in-repo.
- **`check:docs`** on the final board: `120 files, 3343 links, 77 cards, 95 events, 0 failures`.
  It first failed with `blank line inside the events table` from my own edit — caught and fixed
  before commit, which is the gate doing its job on a defect in the correction itself.
- **Still open:** the wave review is in flight; neither candidate is admitted, and integration waits
  on an independent PASS.

## A0c. A5 withdrawn, and a refinement of H-02 (verified 2026-09-10)

The plan carried "copy the three small unique `artifacts/local/` dirs out of `test-game-2`". Inspecting
the two that *are* referenced by tracked documents shows the copy would add 2.2 MB of slop and satisfy
nothing:

- `BACKLOG.md:151` (PUB-01, `done`) lists `artifacts/local/publication-2026-09-06/` under **"Files
  touched"** — a historical statement of where the writer worked, not a pointer to retained evidence.
- `docs/project/INCREMENT-01-lightning-playtest.md:57` reads *"Disposable evidence goes under
  `artifacts/local/lightning/`"* — a forward-looking **instruction** in the verification procedure.
- Tracked counterparts already exist for both: `artifacts/publication-2026-09-06/` and
  `artifacts/lightning-playtest/`. `swarm-prep` has no tracked reference at all.

**Refinement of H-02 / lane 5's count.** Those "94 missing `artifacts/local/` paths" are therefore a
mixed population, not 94 lost artifacts: completed cards' *files-touched* contracts, verification
*instructions* telling a writer where to put disposable output, and genuine dangling pointers. Only
the last class is a defect, and any future reconciliation card must classify each path before
deleting or restoring anything.

## B. Findings and dispositions

Severity: S1 authority/trust · S2 maintenance hazard · S3 cosmetic · S4 disk weight.
"Owner?" = needs Andrew's judgement, not just housekeeping.

| ID | Sev | What | Disposition | Owner? |
| --- | --- | --- | --- | --- |
| H-01 | S1 | Tracked `docs/project/sprint-0/closure.json` pins 12 sha256 entries **inside gitignored, disposable `artifacts/local/`** (12/12 present now, fragile) | **Mitigated this round**: 9 distinct files (164 KB) archived + re-verified against the pinned hashes. Remaining fix: copy into a tracked evidence dir and document pin-critical paths | yes (policy) |
| H-02 | S1 | 94 of 130 `artifacts/local/...` paths cited by tracked proof docs **no longer exist**, yet prose reads present-tense | Add evidence-status lines or repoint to surviving tracked copies | no |
| F-P2 | S1 | Parked HF-04a candidate hash matches TRACKING EV-0091 exactly; HF-05 candidate was never recorded by the board | Preserve (done); recovery lane defines board correction | no |
| F-P7 / H-11 | S1 | Published-tip reality: **94 commits unpushed**, not 18; `BACKLOG` T01 and `HOUSEKEEPING` claim no remote is configured while `origin` exists | Correct both docs; reconcile refs with `git fetch` before any publication claim | yes |
| F-P3 | S2 | Worktrees hold unique gitignored evidence a naive prune destroys (incl. one amendment draft already superseded) | **Done**: 957 files / 4.8 MB archived; only 885 MB of regenerable binaries excluded | no |
| H-03 | S2 | Uncommitted TRACKING row links **untracked** `HF-04a/attempt-1/handoff.json` → `check:docs` fails on a clean clone | Commit receipts together with the link (recovery lane) | no |
| H-07 | S2 | 9 of 12 retained evidence dirs lack `README.md`; 674 tracked files have no orientation | Add short READMEs (source commit, method, limits) | no |
| F-P5 | S3 | `TRACKING.md` has ~38 glued word+digit corruptions (`from3ab3477`, `sha7eb7ad2c…`) vs 0 in peer docs; `candidate<sha>` gluing can break parsing | Fix under the recovery/board correction; confirm cause via lane 6 | no |
| H-08 | S3 | 268 tracked files in 70 byte-identical groups inside retained evidence (877 KB redundant) | Prefer leaving as-is; hardlinking would obscure provenance | no |
| H-09 | S3 | `public/art/` 21.1 MiB has **zero live-code references** yet Vite copies it into `dist/` every build | **DONE (AR-05, integrated d6ac257)** — moved to `docs/art/`, 21 references updated across 11 documents; a fresh build now produces no `dist/art/` at all | no |
| H-10 | S3 | 27 loose undated files at `artifacts/` root (2.9 MB) | Group into a named record with a README | no |
| H-13 | S3 | `package.json` `start` and `test:balance` duplicate other scripts, referenced nowhere | Optional removal or document as aliases | no |
| H-15 | S3 | `.claude/settings.local.json` ignored only by a **host-global** rule, not the repo's | Add repo `.gitignore` line | no |
| H-12 | S3 | Only CI is a `workflow_dispatch` self-hosted job whose runner was removed → no automated gate | Accepted gap; record it explicitly | yes |
| H-14 | S3 | **Positive**: `.gitignore` is consistent — zero tracked files under ignored paths | Preserve the property | no |
| H-04 | S4 | 1.19 GiB of Godot export binaries in 14 distinct builds; only the `closed/` pair is hash-pinned | Keep `closed/`; archive-then-delete `final/` (182.9 MB) + 10 superseded S0-09 runs | yes (final/) |
| H-05 | S4 | 467.8 MiB (73% of the working tree) outside version control: 365 MiB evidence + 102 MiB build material | Adopt a size budget; prune binaries first | yes |
| H-06 | S4 | 9 worktrees = 2.45 GiB (988 MiB generated) | Covered by A1/A4 | no |
| F-P6 | S4 | `test-game-2`, a second 1.8 GB clone: **code content-superseded** (all branch blobs byte-identical to `main` except one older test runner) but holds **1.4 GB of local evidence found nowhere else** | Do not delete; copy small dirs (A5); owner decides on 1.3 GB raw captures | yes |
| F-P8 | — | `test-game-1` is *KATAMITE*, an unrelated 104 KB game, not Scrapkeep slop | Leave alone | no |

## B2. Lane 2 (recovery) and Lane 3 (canonical) findings

| ID | Sev | What | Disposition | Owner? |
| --- | --- | --- | --- | --- |
| L2-01 | S1 | **HF-05-A1 was fully delivered** (candidate `ea522c3`, clean worktree, handoff `stopped_writer: true`, 126 checks PASS) but the board says candidate `null` / review `not_run` / lease active / row `in_progress`. The finished work sits outside the authority record entirely | Record the handoff event, retain the 21 receipts as a tracked copy, set row `review` rev 5, dispose of HF-05-L1 | no |
| L3-07 / L3-08 | S1 | Same HF-05 blindness, plus `TRACKING.md:520` asserts "no active writer" while `:113`/`:119`/`:551` record one | Same fix; refresh the summary block | no |
| L2-02 / L3-06 | S1/S2 | `HF-04a` state token `IN_REVIEW` is outside the board's own enum (`:30`), the only one of 84 rows; `check-docs.mjs` never validates the state column, so the gate stays green | Set to `review`; add a fixture-backed state check to the checker | no |
| L3-01 | S1 | `README.md:13` still tells a fresh reader the foundation sprint "is proposed and has not started", contradicting EV-0078 and three `done` cards | Rewrite with citation to the authorization row | no |
| L3-02 | S1 | `docs/project/sprint-0/AUTHORIZATION.md:5` (the live scope authority) still says the fourteen-card sprint is `awaiting_review` | Add a dated supersession clause; keep history | no |
| L3-03 | S1 | `TRACKING.md` contains **three competing "current proposal" claims**, two of them awaiting_review, while the fixed fourteen-card set is authorized | Retitle as dated historical records with a superseded-by line | no |
| L3-04 / L3-05 / L3-21 | S1 | Both tracked closure receipts assert `nextProposal.status: awaiting_review`, and `scripts/sprint-close.mjs:253` *requires* that value, so the status cannot simply be edited; receipt also cites an authorization superseded twice | Add a `supersededBy` field (schema change + validator + template) | **yes** (schema) |
| L3-09 / L3-10 / H-11 | S1 | `SOURCE-DISPOSITIONS.md` (3 rows) and `DECISION-REGISTER.md` D04 still present publication/Q-E07 as unresolved though the remote exists and PUB-01 completed | Correct the rows with dates; do not reopen the other 31 open rows | no |
| L2-04 | S2 | EV-0092 claims "118 paper/source checks"; both retained receipts say **126** | Correct the uncommitted row (nothing is committed yet) | no |
| L2-05 / L2-06 | S2 | HF-05's narrative and the summary line are one state behind reality (candidate and final checks preceded the event) | Fold into the HF-05 handoff event | no |
| L2-07 / H-03 | S2 | HF-04a's 11 attempt-1 receipts are **untracked** while the uncommitted board links them → `check:docs` fails on a clean clone | Commit receipts together with the link (HF-03a pattern) | no |
| L2-08 | S2 | HF-05's 21 receipts existed **only** in the worktree's gitignored `artifacts/local/` | **Archived this session** (`preserved/wt-local/HF-05/`); recovery wants a tracked copy under `artifacts/foundation-sprint-2026-09/tasks/HF-05/attempt-1/` | no |
| L2-10 | S2 | `run_checks.py` derives the candidate from the **passed repo's HEAD** and **overwrites `handoff.json`** — re-running the documented reproduction from `main` would replace retained evidence with a wrong-candidate report | Treat retained logs as immutable; re-run only `check_contract.py`; guard in attempt 2 | no |
| L2-09 | S2 | HF-04a handoff omits task/revision/attempt/lease identity; both handoffs record the *requested* model/effort, not the actual runtime pair | Record in the review event; treat model as unverified | no |
| L2-13 / L2-12 / L2-11 | S3 | EV-0022→EV-0023 timestamp regression (committed history), attempt-checkpoint timestamps off by µs, and the glued-text/casing drift (`HF04a`, `S004`) | Leave committed history; fix uncommitted rows; optional board-format lint | no |
| L3-25 / L3-30 / L3-41 | S4 | `TRACKING.md` 123 KB: events table is **55.5%** of bytes, live state only **19.6%**, and 15 top-level sections are ordered so the live ones sit 5th/8th/11th | Archive the event log at EV-0057 into a tracked archive; reorder to authorization → index → live attempts → events → archive | **yes** |
| L3-42 / L3-43 | S4 | `BACKLOG.md` 217 KB / 3328 lines; `SOURCE-DISPOSITIONS.md` 545 lines; `BIBLE.md` 129 KB | Candidate for splitting; deferred under D1 (no canonical restructuring without approval) | **yes** |
| L3-22 / L3-23 / L3-26 / L3-27 / L3-29 | S2 | Live-looking stale guidance: host-config **line numbers** that drift (`verify.py:140-177`), evidence cited from ephemeral `/tmp`, an executable-looking historical preflight (`PLANNING.md`), a historical closeout claiming no remote, and two sprints with two different retention standards | Prose fixes; mark historical procedures "do not execute"; state the retention rule once | no |
| L3-33 | S2 | `docs/tech/sections/README.md` index lists only admitted sections and is already stale (HF-04a/HF-05 drafts exist) | State the admitted-only rule; update at each admission | no |

## B3. Owner decisions added by lanes 2–3

6. **Who resumes the coordinator role?** `TRACKING.md:15` names `/root/foundation_coordinator` (xhigh); that session is gone. ORCHESTRATOR requires a recorded coordination transfer **before** any further dispatch. No agent-side action substitutes for this.
7. **Model-map conflict:** the host map (mtime 2026-09-08/09, after this sprint) says coordinator `gpt-6-astra@high` plus Andrew's 2026-09-07 mixed-model authorization; `TRACKING.md:15` records an explicit **xhigh** coordinator selection. Which pair governs the resuming coordinator, and is any deviation recorded as a blocker?
8. **`run_checks.py` (L2-10):** review note, `changes_requested` attempt 2, or follow-up card?
9. **Reviewer capacity:** HF-04a and HF-05 are disjoint and may share one fresh wave reviewer per ORCHESTRATOR; HF-03b is `ready` but undispatched.

## B4. Lane 1 (worktrees) and Lane 4 (docs/assets) findings

| ID | Sev | What | Disposition | Owner? |
| --- | --- | --- | --- | --- |
| W-01 / W-02 | S1 | The two unadmitted candidates are absent from `main`; **only their branch refs keep them alive**, and HF-05's row still says candidate `null` | Parked + preserved (done); recovery decides recording | no |
| W-03 | S1 | `main`'s working tree is the **only** copy of EV-0090/91/92, the `IN_REVIEW` state and the untracked attempt-1 evidence | **Do not run `git clean/reset/checkout --` in `main`** before those rows are admitted | no |
| W-04 | S2 | 7 stale worktrees = 2,310,320,128 B, all clean; `-D` needed for them (patch-id-merged), `-d` works for the 10 loose branches | Executed via safety tags (**done**, see §A) | no |
| W-05 | S4 | `wt-S0-09` = 1,225,404,416 B; its Godot exports are **not** byte-identical to the retained closure-cited copies (different sha256) → **irreversible if removed**; Godot exports are not reproducible byte-for-byte | Keep the retained `closed/` pair; deleting S0-09's 927 MB of regenerable-but-unique exports is an owner decision | **yes** |
| W-07 | S3 | `cleanup-dry-run.out` was stale (said `REMOVE node_modules`) | **Fixed**: output regenerated from the corrected planner | no |
| W-06 | S3 | One dangling stash-shaped commit `4a6ad359…` (superseded content); `refs/codex` holds 10 unique blobs / 0.19 MiB | Not a cleanup target; left in place | no |
| L4-01 | S1 | `docs/bible/production/FRONT-MATTER.md` + nine section manuscripts present themselves as the **"Approved product reference"** while `BIBLE.md` is the approved Bible | Add a banner naming `BIBLE.md` as approved and this set as the production manuscript | **yes** |
| L4-02 | S1 | `docs/audit-2026-09-05/worker-*.md` carry no historical banner and assert the repo root is `/home/andrew/Projects/test-game-2` with git unusable — both false | Banner as historical; the path claim is also evidence that the sibling clone was once the working root | no |
| L4-03 / L4-04 | S1 | `docs/DESIGN-AUDIT.md`, `docs/ORCHARD-VISUAL-SWARM.md` read as live while their claims ("awaiting Andrew's judgment", "no session goal … is set") are now false | Banner or repoint to the live record | no |
| L4-05 | S1 | `docs/CHARACTER-BIBLE.md` self-describes as "**the** production-guiding character reference" while `BIBLE.md:390` calls it the earlier one | Reconcile the two claims | **yes** |
| L4-06 | S2 | `docs/bible/production/assets.json` carries **363 stale absolute paths into the 1.8 GB sibling clone** (`test-game-2`) instead of repo-relative ones | Fix the manifest to repo-relative paths — and **do not delete `test-game-2`** until it is fixed (the inventory resolves only through it) | no |
| L4-07 / L4-08 / L4-11 / L4-12 | S2 | `docs/DESIGN-INDEX.md` indexes none of `docs/bible/**`, `docs/tech/**`, `COHESION_REPORT`, `BIBLE_DECISIONS`; `docs/tech/` has no index for `proofs/` or `native-toolchain`; 9 sibling manifests are invisible to readers; `docs/decisions.tsv` is a TSV in a Markdown tree still cited as "the existing decision trail" | Add indexes; reconcile the decision trail with `DECISION-REGISTER.md` | no |
| L4-09 | S2 | Art-prompt filenames do not match the images they produced, under three naming conventions | Rename or add a mapping table | no |
| L4-10 | S2 | `public/art` (8 png) + `docs/bible/images` (30 png) = **109,613,198 B with no live reference** | Design evidence per `ASSETS.md:9`; cross-lane with H-09 (move `public/art` out of the served tree) | **yes** |

## B5. Owner decisions added by lanes 1 and 4

10. **S0-09's 927 MB of Godot exports** — unique bytes, not reproducible; main's `final/`/`closed/` copies are different files. Accept the loss, or keep?
11. **`test-game-2` retention is now doubly justified** — it is both the sole home of three branch objects and the resolution target of 363 absolute paths in the tracked Bible provenance inventory (L4-06).
12. **`public/art` + `docs/bible/images` (109.6 MB, no live reference)** — move, or accept as design evidence?

## B6. Lane 6 (code and tooling) findings

Lane 6's checks: `npm test` **187/187 pass**, `check:docs`, `check:project`, `check:scope` and
`node --check` on all 8 scripts → all exit 0. No unreachable module (16/16 reachable), all imports and
exports resolve, all 22 fixtures used, `native/` is a real 32-file Godot scaffold.

| ID | Sev | What | Disposition | Owner? |
| --- | --- | --- | --- | --- |
| L6-01 | S1 | `TRACKING.md:119` state `IN_REVIEW` is absent from the board legend (`:30`) **and** from the checker vocabulary (`sprint-close.mjs:13`); `check-docs.mjs:400-429` reads only the first and last cells, so the gate reports 0 failures on a board violating its own legend | **In the staged patch** (`IN_REVIEW` → `review`). Any new state checker must land **after** that fix or `check:docs` fails on `main` | no |
| L6-02 | S2 (S1 if distributed) | `src/orchard/main.js:783-812` gates `window.__orchard` + the 898-line QA runner on `?qa` alone — no `import.meta.env.DEV`, unlike `src/main.js:674-679`. The production bundle ships `dist/assets/orchard-browser-runner-*.js` and `__orchard`; only `/` is asserted QA-free (`tests/lead-browser.mjs:51-56`). Decision D05 Open, option (a) = gate both on DEV | Decide D05, then gate the orchard entry on DEV like the other one | **yes** (D05) |
| L6-05 | S2 | `tests/expedition-balance.mjs:12-31` hard-codes an 18-point patrol route; the game's `PATH` has 20 points (`src/game.js:2-23`) and only the *non-asserted* probe uses it — so the asserted victory gate never exercises real path geometry | Derive the route from `PATH`, or assert the probe | no |
| L6-03 | S2 | `scripts/check-build.mjs:18-26` is **byte-identical** to `server/index.js:47-55`; resolution logic has since drifted and check-build omits the data-directory guard at `server/index.js:243` | Share one module or re-sync | no |
| L6-04 | S2 | `scripts/check-project.mjs:59-78` re-implements the `check-docs.mjs:163-233` link scanner (same regex) with fence/title/escape drift — latent today | Consolidate the scanner | no |
| L6-07 | S2 | `scripts/native-smoke.mjs:30,147` networking grep covers 16 of 32 native files and misses `MultiplayerPeer`/`WebRTC`/`SceneMultiplayer`/`DTLSServer`/`UPNP`; widening is recorded at `TRACKING.md:276` but unimplemented | Widen the pattern and file set | no |
| L6-08 | S3 | 8 exports imported by nothing (`src/art.js:92`, `src/campaign.js:45`, `src/collection.js:13`, `src/game.js:203-204`, `src/orchard/simulation.js:166`, plus test/script helpers) | Remove or document | no |
| L6-09 | S3 | Agent-config mismatches: `AI-WORKFLOW.md:21` "four effort tiers" vs `ORCHESTRATOR.md:17` reserving `max` no `.claude/agents/*.md` defines; `.agents/skills/scrapkeep-task/SKILL.md:33` asks shell-less read-only agents to report `CLAUDE_EFFORT`; `AGENTS.md:11` "Fable roles" | Reconcile the four statements | no |
| L6-11 | S3 | Only 1 of 16 native `.uid` files is tracked and no ignore rule covers them | Decide the rule | no |

**Corruption verdict (closes F-P5).** Not script templating: no repo code writes `TRACKING.md` or
`BACKLOG.md` (all five `writeFile` sites target `artifacts/local/`), and `hexdump` of line 338 shows
`ner,8` with the separator byte genuinely absent and no invisible character. Template joins corrupt
fixed positions; these losses vary mid-sentence (`owner,8`, `and5`, `revision2`, `temporarydirectoryremoved`)
and appear in coordinator artifacts no script touches. Prevalence = authoring volume: 278 suspect
tokens in `TRACKING.md`, 0 in ORCHESTRATOR/BIBLE/CONTRIBUTING/AGENTS. **Fix the admitted rows; there
is no code fix.**

## B7. Coordinator re-verification of the two code findings (2026-09-10)

Both were re-checked directly, because each would drive a code card and lane claims alone are not
grounds for one:

- **L6-02 confirmed.** `src/orchard/main.js:17` is
  `const qaEnabled = new URLSearchParams(location.search).has("qa");`, line 784 is `if (qaEnabled) {`
  opening the `window.__orchard` API, and line 810 dynamically imports
  `../../tests/orchard-browser-runner.js`. There is **no `import.meta.env.DEV`** anywhere in that
  file, whereas the sibling entry gates the same pattern at `src/main.js:674`. The consequence is
  present on disk: `dist/assets/orchard-browser-runner-CLJYWHnE.js` (18 KB) exists and the string
  `__orchard` appears in `dist/assets/orchard-Cgvn2uSK.js`. A production build still loads the 898-line
  QA runner when the URL carries `?qa`.
- **L6-05 confirmed.** `src/game.js:2-23` `PATH` holds **20** points; the route hard-coded at
  `tests/expedition-balance.mjs:12-31` holds **18** and is a different shape (it starts `[1,-2]` and
  ends `[-11,-7]`). The asserted gate therefore does not patrol the shipped path.

Both remain proposals only. Neither is authorized; a code card needs its own scope, worktree and
review, and L6-02 additionally waits on decision D05.

## B8. Coordinator re-verification of the closure-receipt finding (2026-09-10)

L3-04/L3-05 re-checked directly, because the fix they imply changes a validator and needs an owner
decision:

- `docs/project/sprint-0/closure.json` → `nextProposal.status = "awaiting_review"`, `approvalOwner
  "Andrew"`, cards **HF-01 revision 2** and **HF-02 revision 2** — both long since `done`.
- `docs/project/foundation-01/closure.json` → same status, cards **HF-03a revision 1** (done) and
  **HF-03b revision 1** (`inputReady false`).
- `scripts/sprint-close.mjs:253` literally asserts
  `require(proposal.status === "awaiting_review", …)`. **Confirmed:** the stale value cannot be
  edited away without failing the validator, so the fix is an additive supersession field plus a
  schema and template update — not a text correction. That is why it is an owner decision, not a
  housekeeping edit.

Also re-measured L3-25's claim about the board's weight: `TRACKING.md` is now 125,739 bytes and the
event rows alone are 70,567 bytes — **56%** of the file, essentially as lane 3 reported (55.5% before
the three events this pass added).

## B9. Coordinator handoff verification, pre-review (2026-09-10)

ORCHESTRATOR requires the coordinator to verify that a handoff matches its lease and card **before**
recording review state. Both candidates pass on the mechanical criteria:

| Check | HF-04a `72178cf` | HF-05 `ea522c3` |
| --- | --- | --- |
| Commits in the candidate | 1 | 1 |
| Changed paths | exactly `docs/tech/sections/HF-04a-runtime-lifecycle.md` | exactly `docs/tech/sections/HF-05-content-admission.md` |
| Lease honoured (only the leased file touched) | **yes** | **yes** |
| Parent equals declared base `7a73c5b5f448…` | **match** | **match** |
| Worktree clean | yes | yes |
| Unmerged relative to `main` | 1 commit (correct) | 1 commit (correct) |

**Identity gap confirmed (L2-09).** `HF-04a`'s `handoff.json` carries only `base` and `candidate`; it
lacks `task`, `revision`, `attempt`, `lease` and `stopped_writer`. The board supplies `HF-04a-A1` /
`HF-04a-L1`, but the artifact cannot be tied to its lease on its own. `HF-05`'s handoff has the full
block, so this is a per-attempt authoring gap rather than a schema gap — `run_checks.py:29` regenerates
the schema and can carry the fields for a future attempt.

**Model/effort remains unverified.** HF-05's handoff records
`model_evidence: "Coordinator assignment confirms original successful host dispatch; no substitution"`,
which is the *coordinator's* report, not worker-observed runtime metadata. Both candidates must be
treated as having an unverified actual model/effort, as lane 2 flagged; a reviewer verdict may rely on
the artifact's content but not on the claimed model pair.

## A0d. Wave review recorded and both candidates admitted (2026-09-10)

- The fresh wave reviewer returned **PASS+NOTES for both** candidates with no blocking findings
  (`review-wave-hf04a-hf05.md`); it re-derived every count by hand and re-ran `check:docs` and
  `check:project` inside each candidate worktree.
- **HF-04a admitted** at `43ec12b` (EV-0096): reviewed bytes copied unchanged, sha256
  `7eb7ad2c…71fb` confirmed identical to the reviewed identity; section index row added.
- **HF-05 admitted** at `641f09f` (EV-0097): sha256 `7ef95df2…59a6` confirmed; index row added.
- Both reviewers' notes were recorded as **board constraints without editing either candidate**, as
  the reviewer required: run the retained `run_checks.py` / `check_contract.py` from scratch with
  output outside the retained directory and never against `main`; and correct HF-05 line 8's citation
  from TADR-004 to `adr/TADR-003-content-pipeline.md:41` at the next revision.
- Board state after admission: **5 of 14 foundation cards done** (HF-01, HF-02, HF-03a, HF-04a,
  HF-05); HF-03b remains `ready` and undispatched; HF-04b and HF-06a now have satisfied dependencies
  but stay `queued` until the coordinator prepares a dispatch.
- Integrated checks on the final tree: `check:docs` 122 files / 3392 links / 97 events / **0
  failures**; `check:project` pass.

## A0e. Publication state corrected and pushed (2026-09-10)

`git fetch origin` showed the remote tip is `f582918`, not the `c5e61d3` recorded in the stale
`test-game-2` clone. The unpublished backlog was therefore **18** commits at session start (not 94),
**22** after this session's four commits, and **0** after `git push origin main`
(`f582918..641f09f`). Lane 5's H-11 and this file's earlier text quoted the wrong basis; the
corrected account is in `parent-findings.md` F-P7.

## C. Owner decisions outstanding

1. **`artifacts/local/sprint-0/final/`** — 182.9 MB of unique export binaries + the only copy of `final/closure.json` (`ebbbe60a…`), superseded by `closed/` which equals the tracked receipt. Archive or delete?
2. **1.3 GB raw playtest captures in `test-game-2`** (`agent-playtests` 650 MB, `agent-recovery-development` 671 MB) — keep, migrate into `scrapkeep/artifacts/local/`, or drop?
3. **Retention budget** for `artifacts/` and worktrees — none is stated anywhere, so each native export run adds 183 MB and the problem regrows.
4. **`public/art/`** — move 21.1 MiB of documentation-only art out of the served tree?
5. **Is the tracked closure receipt meant to be independently re-verifiable years from now** (→ track the pinned files), or is "regenerate at the pinned source" the accepted standard (→ document it in the disposal contract)?
6. **Decision D05 (`DECISION-REGISTER.md:23`, Open)** — gate both browser-proof QA entries on `import.meta.env.DEV` (option (a))? Today the orchard entry ships its QA runner and `window.__orchard` in the production bundle (L6-02).
7. **Whether the staged corrections are approved as written** — apply `staged/canonical-corrections.patch`, amend it, or reject items. Applying it does not touch the HF-05 recovery work, which stays queued behind decision D2.
