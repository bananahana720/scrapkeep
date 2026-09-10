# Lane 1 — worktrees and branches

Base for every check: `main` = `b61feb187cfdcad71700c629e315a77de4e0f975` (18 ahead of
`origin/main` = `f58291842b43511cb3ea94374a504f2881b53cab`). Auditor: read-only subagent.
The only file written by this lane is this report. No git mutation, build, browser test, Godot
command or network access was performed.

## 1. Verified state — facts, each with the exact command run and its observed result

**F1. Inventory: 20 local branches, 9 linked worktrees, 10 loose branches, no third state.**
`git for-each-ref --format='%(refname:short)' refs/heads | wc -l` → `20`. `git worktree list
--porcelain | grep -c '^worktree '` → `10` (main + 9 linked). `ls -d /home/andrew/Projects/scrapkeep-wt-*`
→ 9 directories, one per registered linked worktree. `git branch -vv` → the loose set is exactly
`wt/PS-01 wt/PS-02 wt/PS-03 wt/PS-04 wt/PS-05a wt/PS-05b wt/S0-01 wt/S0-04 wt/S0-05 wt/S0-07`
(there is no plain `wt/PS-05`, `wt/S0-02`, `wt/S0-03`, `wt/S0-06`, `wt/S0-08`, `wt/S0-10`).
`git for-each-ref --format='%(refname:short)' refs/remotes` → `origin`, `origin/main`,
`origin/codex/lightning-playtest` only: **no `wt/*` branch has any remote-tracking counterpart and
no branch has an upstream** (all upstream fields empty in `git branch -vv`). No tags exist
(`git tag -l` → empty).

**F2. Classification of all 19 branches (content, not subjects).**
`git cherry main <b>` (bare, unmerged `+` lines) and `git cherry -v main <b>`:

| Branch | Tip | ahead/behind (`git rev-list --count`) | cherry `+` | Class |
| --- | --- | --- | --- | --- |
| wt/HF-01 | dabdca4 | 1 / 17 | 0 | MERGED-BY-CONTENT |
| wt/HF-02 | 18e174a | 1 / 17 | 0 | MERGED-BY-CONTENT |
| wt/HF-03a | 7209ac5 | 1 / 7 | 0 | MERGED-BY-CONTENT |
| wt/HF-04a | 72178cf | 1 / 1 | 1 | **UNADMITTED** |
| wt/HF-05 | ea522c3 | 1 / 1 | 1 | **UNADMITTED** |
| wt/S0-09-operational | 1c823f0 | 3 / 33 | 0 | MERGED-BY-CONTENT |
| wt/S0-11-operational | 1a2759f | 1 / 41 | 0 | MERGED-BY-CONTENT |
| wt/S0-12-operational | f6a9561 | 1 / 41 | 0 | MERGED-BY-CONTENT |
| wt/S0-13-operational | e5e4df9 | 2 / 36 | 0 | MERGED-BY-CONTENT |
| wt/PS-01 | cc02fb4 | 0 / 89 | 0 | MERGED (tip is ancestor of main) |
| wt/PS-02 | e023315 | 0 / 90 | 0 | MERGED |
| wt/PS-03 | 3dc1f09 | 0 / 85 | 0 | MERGED |
| wt/PS-04 | 8d88c0a | 0 / 86 | 0 | MERGED |
| wt/PS-05a | 4e887f1 | 0 / 76 | 0 | MERGED |
| wt/PS-05b | fcca2c8 | 0 / 71 | 0 | MERGED |
| wt/S0-01 | 7ed1a9d | 0 / 76 | 0 | MERGED |
| wt/S0-04 | d40e19d | 0 / 68 | 0 | MERGED |
| wt/S0-05 | ca033b3 | 0 / 61 | 0 | MERGED |
| wt/S0-07 | 90f08c4 | 0 / 61 | 0 | MERGED |

Result: **17 MERGED (7 with worktrees, 10 loose), 2 UNADMITTED (wt/HF-04a, wt/HF-05), 0 UNCLEAR.**
`git merge-base --is-ancestor <b> main` → for the 10 loose branches `ANCESTOR` (so `git branch -d`
succeeds); for the 9 worktree branches `NOT-ancestor` (so `-d` refuses and `-D` is required even
where content is fully merged).

**F3. MERGED-BY-CONTENT is byte-level content equality, not just patch-id.** For each of the 7
non-ancestor branches, `git diff --name-status $(git merge-base main <b>) <b>` lists every file the
branch touched, and each of those files was compared against main with `git rev-parse
main:<path>` vs `git rev-parse <b>:<path>`:

| Branch | Files changed by the branch | main blob vs branch blob |
| --- | --- | --- |
| wt/HF-01 | `docs/tech/sections/HF-01-production-conventions.md` (A) | `a3b5be958f` = `a3b5be958f` |
| wt/HF-02 | `docs/tech/sections/HF-02-constraints-evidence.md` (A) | `235d76142d` = `235d76142d` |
| wt/HF-03a | `docs/tech/sections/HF-03a-module-map.md` (A) | `ec06cb2392` = `ec06cb2392` |
| wt/S0-09-operational | `.github/workflows/native-smoke.yml`, `docs/tech/native-toolchain.md`, `native/export_presets.cfg`, `scripts/native-smoke.mjs`, `tests/native-smoke.test.js` | all 5 identical (`78a4d5e842`, `a37cc36d7f`, `d3d91bf3de`, `8e9ae0ffb5`, `95bf743136`) |
| wt/S0-11-operational | `docs/project/sprint-0/amendment-examples.md`, `…/amendment-request.md` | both identical (`79a836db6b`, `4be96e939e`) |
| wt/S0-12-operational | `native/README.md`, `native/integration/smoke.gd`, `…/smoke.gd.uid`, `…/smoke.tscn`, `native/project.godot` | all 5 identical (`6c4e51fc4c`, `87474f2069`, `cefd004099`, `b5009d005f`, `946fc56fb7`) |
| wt/S0-13-operational | 11 files incl. `scripts/sprint-close.mjs`, `tests/sprint-close.test.js`, `docs/project/sprint-0/closure-receipt.md`, 6 fixtures | all 11 identical (`51342de7f3`, `9d0da8acc3`, `86a9cd7dab`, …) |

An independent second method agrees: `git show <sha> | git patch-id --stable` for every branch commit
matches exactly one main commit — `dabdca4`→`a618e26` (`8a40a27e…`), `18e174a`→`2a4f2ef`
(`d588beaa…`), `7209ac5`→`3f56a82` (`890c496e…`), `76cbb6c`→`dddb5b7` (`7f8b2a30…`),
`19192bb`→`196e17b` (`51abc592…`), `1c823f0`→`e54e429` (`e5667531…`), `1a2759f`→`0185087`
(`0f101c58…`), `f6a9561`→`aea16db` (`a4e714a7…`), `ad18bf8`→`685a4ac` (`b8a5f7e7…`),
`e5e4df9`→`25262d2` (`dec980fd…`). Deleting these refs therefore loses **no unique content**.

**F4. The two UNADMITTED candidates are genuinely absent from main.**
`git cherry -v main wt/HF-04a` → `+ 72178cf58a39e9ca1c70922eca830776573f3ce8`;
`git cherry -v main wt/HF-05` → `+ ea522c3eac2cb12c44d9918910a3ec0b10a604c0`.
`git rev-parse main:docs/tech/sections/HF-04a-runtime-lifecycle.md` → `fatal: path … does not exist
in 'main'`; likewise for HF-05. `git log --all --diff-filter=A -- docs/tech/sections/HF-04a-runtime-lifecycle.md docs/tech/sections/HF-05-content-admission.md`
returns only the two branch commits themselves. `git for-each-ref --contains <candidate>` → only
`refs/heads/wt/HF-04a` / `refs/heads/wt/HF-05`; **those two refs are the sole thing keeping the
candidates alive.**

| Card | Candidate commit | Parent | File | Git blob | sha256 | Size |
| --- | --- | --- | --- | --- | --- | --- |
| HF-04a | `72178cf58a39e9ca1c70922eca830776573f3ce8` | `7a73c5b5f44806c83924661b054051818174f07e` | `docs/tech/sections/HF-04a-runtime-lifecycle.md` | `ae84e607f2354207dba011a6e47dcadca237cbdb` | `7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb` | 207 lines, 47 613 B |
| HF-05 | `ea522c3eac2cb12c44d9918910a3ec0b10a604c0` | `7a73c5b5f44806c83924661b054051818174f07e` | `docs/tech/sections/HF-05-content-admission.md` | `8ceb841d535cc78a94d1b9024d93bc544c91028f` | `7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6` | 202 lines, 31 203 B |

`sha256sum` of the parked HF-04a file equals the hash recorded in the uncommitted `TRACKING.md`
EV-0091 (`sha7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb`) → the parked commit
is the candidate the board claims. For HF-05 the board row still says `Candidate identity: null`
(last event EV-0092) → commit `ea522c3` was never recorded.

**F5. Every worktree is clean; the dirt is in main.**
`git -C <each wt> status --short` → 0 lines for all 9.
`git status --short --branch` in `/home/andrew/Projects/scrapkeep` →
`## main...origin/main [ahead 18]`, ` M TRACKING.md`,
`?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/`.
`git diff --stat TRACKING.md` → `1 file changed, 10 insertions(+), 6 deletions(-)`, containing
EV-0090/EV-0091/EV-0092 and the HF-04a `IN_REVIEW` / HF-05 checkpoint rows. The untracked
`attempt-1/` holds 10 files (`find … -type f | wc -l` → 10, `du -sh` → 96K); `diff -rq
artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1
/home/andrew/Projects/scrapkeep-wt-HF-04a/artifacts/local/tasks/HF-04a` → no output, i.e. the
untracked copy is byte-identical to the HF-04a worktree's local evidence.

**F6. Disk usage, exact bytes (`du -s --block-size=1`), and no hard-link sharing.**
`du -s --block-size=1 /home/andrew/Projects/scrapkeep /home/andrew/Projects/scrapkeep-wt-*`:

| Path | Bytes | Approx |
| --- | --- | --- |
| …/scrapkeep (main) | 821 141 504 | 784 MiB |
| …-wt-HF-01 | 180 862 976 | 173 MiB |
| …-wt-HF-02 | 180 850 688 | 173 MiB |
| …-wt-HF-03a | 181 141 504 | 173 MiB |
| …-wt-HF-04a | 181 510 144 | 173 MiB |
| …-wt-HF-05 | 181 575 680 | 173 MiB |
| …-wt-S0-09-operational | 1 225 404 416 | 1.14 GiB |
| …-wt-S0-11-operational | 180 637 696 | 173 MiB |
| …-wt-S0-12-operational | 180 670 464 | 173 MiB |
| …-wt-S0-13-operational | 180 752 384 | 173 MiB |
| **9 linked worktrees total** | **2 673 405 952** | **2.49 GiB** |

Identical file across checkouts is a real copy, not a hard link: `stat -c '%i %h %s'` on
`docs/bible/images/A01-v1.png` → inode `1636077` (main), `1750549` (HF-01), `1732605` (S0-09), link
count 1 each. Deleting a worktree therefore returns its full byte count.

Inside `wt-S0-09-operational`: `artifacts/local` 932 093 952 B, of which `native-export`
914 677 760 B (5 × 73 590 176 B Linux `scrapkeep.x86_64` + 5 × 109 339 248 B Windows
`scrapkeep.exe` + small files), `native-smoke` 17 047 552 B, `tasks` 286 720 B, `verify` 65 536 B,
`check-docs` 16 384 B; plus ignored `node_modules` 89 391 104 B and `dist` 23 273 472 B. Every other
worktree's non-tracked weight is only its ignored `artifacts/local` (36–180 KB, `find | wc -l` 10–21
files) — plus `native/.godot/` in wt-S0-12 (reported by `git status --short --ignored`).

Each light worktree's 173 MB is mostly tracked content the repo needs: `docs/bible` 88 453 120 B
(30 tracked images under `docs/bible/images`), tracked `artifacts/` ≈ 63–64 MB, `public/` 22 MB.
In main: `.git` 136 MB (`git count-objects -vH` → 2658 in-pack, 3 packs, 131.23 MiB pack, 131 loose
objects 1.07 MiB), ignored `artifacts/local` 390 643 712 B (of which `sprint-0/final` 181 MB and
`sprint-0/closed` 185 MB, both cited by the committed `docs/project/sprint-0/closure.json`),
`node_modules` 89 391 104 B, `dist` 23 273 472 B.

**F7. Worktree registration is healthy; nothing is prunable, nothing is locked.**
`ls .git/worktrees/` → 9 dirs; for each, `cat .git/worktrees/<id>/gitdir` → target exists
(`/home/andrew/Projects/scrapkeep-wt-<X>/.git` present for all 9). No `locked` file in any admin
dir. `git worktree list --porcelain` reports a live path, HEAD and branch for all 9, and every
reported HEAD equals its branch tip. There is no `.gitmodules`. (`git worktree prune --dry-run` was
deliberately **not** run — forbidden by the audit constraint; the checks above establish the same
result without it.) Each admin dir does contain a stale 0-byte `MERGE_RR` plus an `ORIG_HEAD`
pointing at the merge-base used to create the worktree (`3ab3477`, `9cb8f51`, `7a73c5b5`, `0061112`,
`1eb4a22`, `6b23945`), with no `MERGE_HEAD`, `MERGE_MSG`, rebase or cherry-pick state — residue, not
an in-progress operation.

**F8. Stash and unreachable-object state.**
`git stash list` → empty. `git fsck --no-progress --dangling` (no `--lost-found`, no writes) →
`dangling commit 4a6ad359a7966e86950c2e1dc0be67ddc2e17f5a`, 11 dangling trees, 1 dangling blob.
`git log -1` on that commit → subject `WIP on wt/PS-01: 01917d9 Add check:docs, check:scope and
new-worktree.sh (PS-01 checkpoint 1)`, parents `01917d9` (ancestor of main) and `bd218ed`
(`index on wt/PS-01…`); `git show` → 6 added CONTRIBUTING.md lines. `git for-each-ref --contains
4a6ad359…` → no refs. Every one of those 6 lines is already covered by main's `CONTRIBUTING.md`
(rows `check:docs` line 36, `check:scope` line 37 — main's row is a superset adding `native-player`
and the `other`/`empty` clauses —, `new-worktree.sh` line 38, `check:godot` line 40 with the same
"Reserved name for the native proof checks" wording, and the `Scope-to-command map` paragraph line
53). Inference (not a byte-equality proof, because main re-padded the table): this is superseded
stash residue, safe to let `git gc` prune.

**F9. Codex checkpoint refs are metadata, not hidden weight.**
`git for-each-ref refs/codex` → 2 tree refs
(`…/43a7fe04…/1788735398000/7e7a7947-…` → `6a963f40d3f0e904b16494093c4acfc9577d06ed` and
`…/76d30d71…/1788732611580/9b76269a-…` → `22f064f0154f134144433c92b9c2eefe6c8f174a`). Each tree
contains ~1700 entries / ~169 MiB of blob content, but comparing against every object reachable from
`refs/heads` + `refs/remotes` (`comm` of `git ls-tree -r` blob ids against `git rev-list --objects`)
→ first tree has **10 unique blobs (0.19 MiB)**, second has **0 unique blobs**. They are not a
deslop target.

**F10. Worktree-local (gitignored) content, and content that exists nowhere in main.**
For every file under each worktree's `artifacts/local`, I checked (a) identity with the same path in
main (`cmp`), (b) whether an identical blob exists anywhere in main's history
(`git hash-object` ∩ `git rev-list --objects main`), and (c) whether the archived copy at
`artifacts/local/audit-2026-09-10/preserved/wt-local/<wt>/` is identical. Files whose content is
absent from main's history:

| Worktree | unique-content files | bytes | archived in `preserved/wt-local/` | not archived |
| --- | --- | --- | --- | --- |
| HF-01 | 1 (`tasks/HF-01/check-docs.json`) | 15 389 | 1 | 0 |
| HF-02 | 1 (`tasks/HF-02/check-docs-report.json`) | 15 387 | 1 | 0 |
| HF-03a | 0 | 0 | 0 | 0 |
| HF-04a | 9 | 73 618 | 9 (also byte-identical to main's untracked `…/HF-04a/attempt-1/`) | 0 |
| HF-05 | 15 (incl. `handoff.json`, `scenario-review.md`, `paper-check*.json`) | 117 424 | 15 | 0 |
| S0-09-operational | 265 | 928 118 957 | 251 | **14 = 927 725 380 B** |
| S0-11-operational | 1 (`check-docs/report.json`) | 14 948 | 1 | 0 |
| S0-12-operational | 0 | 0 | 0 | 0 |
| S0-13-operational | 1 (`check-docs/report.json`) | 15 064 | 1 | 0 |

The 14 deliberately unarchived files are exactly the regenerable Godot outputs:
5 × `native-export/windows/run-*/scrapkeep.exe` (109 339 248 B each),
5 × `native-export/linux/run-*/scrapkeep.x86_64` (73 590 176 B each) and
4 × `native-smoke/run-*/cache/godot/editor_doc_cache-4.7.res` (~3.27 MB each). They are **not**
byte-identical to main's retained `artifacts/local/sprint-0/final|closed` exports
(`sha256sum` main `final/scrapkeep.x86_64` = `285413af94b6…`, worktree `run-zZkI5H/scrapkeep.x86_64`
= `7f6d712d2f88…`; main `final/scrapkeep.exe` = `bc46787c6561…`, worktree `run-zZkI5H/scrapkeep.exe`
= `86b050849318…`), so their deletion is irreversible; main's `final/` and `closed/` are the
closure-cited copies and stay.
Notably, `wt-S0-09`'s `tasks/S0-09/revision2-bootstrap-receipt.json` (1260 B),
`revision2-check-docs.log` (1241 B) and `revision2-check-project.log` (237 B) exist **only** there;
they are in the archive, so removal is safe.

## 2. Findings

| ID | Sev | Paths | What is wrong | Evidence (command → observed) | Proposed disposition | Reversibility |
| --- | --- | --- | --- | --- | --- | --- |
| W-01 | S1 | branch `wt/HF-04a`, `docs/tech/sections/HF-04a-runtime-lifecycle.md` | Unadmitted candidate at `72178cf` is in no main commit; board (uncommitted TRACKING) lists it `IN_REVIEW` with review never run. `git cherry -v main wt/HF-04a` → `+ 72178cf…`; `git rev-parse main:docs/tech/sections/HF-04a-runtime-lifecycle.md` → `fatal: path … does not exist`; `git for-each-ref --contains 72178cf` → only `refs/heads/wt/HF-04a` | Keep worktree and branch parked (decision D2); route to fresh independent review; must not enter cleanup | Deleting the branch is **not** reversible (content would be lost after gc); worktree removal alone is reversible only while the branch/tag exists |
| W-02 | S1 | branch `wt/HF-05`, `docs/tech/sections/HF-05-content-admission.md` | Second unadmitted candidate `ea522c3`; authority record never names it — TRACKING says `Candidate identity: null`, last event EV-0092 pre-candidate. `git cherry -v main wt/HF-05` → `+ ea522c3…`; `grep -n "Candidate identity" TRACKING.md` → HF-05 row still `null` | Preserve; coordinator records the candidate identity and lease state before any admission decision | Same as W-01 |
| W-03 | S1 | `/home/andrew/Projects/scrapkeep/TRACKING.md` (working copy), `artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` | The cut-off session's canonical record edits (EV-0090/91/92, HF-04a `IN_REVIEW`, HF-05 checkpoint) exist only in the working tree, and the HF-04a handoff evidence only as untracked files; `git checkout -- TRACKING.md`, `git stash`, `git clean -fdx` or a naive "reset the dirty repo" would destroy both | `git status --short --branch` → ` M TRACKING.md`, `?? …/HF-04a/attempt-1/`; `git diff --stat TRACKING.md` → 10 insertions/6 deletions; `find …/attempt-1 -type f | wc -l` → 10 | Coordinator admits the TRACKING rows and the attempt-1 evidence (archive copy already exists under `preserved/`); no cleanup may run `git clean`/`checkout --` on these paths | Not reversible once reset; archive copy in `preserved/tracking-uncommitted.diff` + `TRACKING.working-copy.md` is the current safety net |
| W-04 | S2 | `wt/HF-01`, `wt/HF-02`, `wt/HF-03a`, `wt/S0-09-operational`, `wt/S0-11-operational`, `wt/S0-12-operational`, `wt/S0-13-operational` | Seven worktrees whose branch content is byte-identical in main still occupy 2 310 320 128 B; they are stale execution scaffolding, not workspaces | Per-file blob equality (F3) + patch-id match (F3) + all clean (F5) | Remove all seven worktrees, then delete their branch refs with `git branch -D` | Worktrees: reversible via `git worktree add <path> <branch\|tag>` (tracked content only). Branches: reversible only via the recorded SHAs/tags; ignored per-worktree evidence is **not** restored |
| W-05 | S4 | `/home/andrew/Projects/scrapkeep-wt-S0-09-operational` (1 225 404 416 B) | Largest single reclaim target; 914 677 760 B is regenerable Godot export output, 89 391 104 B worktree `node_modules`, 23 273 472 B `dist`; only ~394 KB of its local content is non-regenerable evidence (already archived) | `du -s --block-size=1 <path>` → 1 225 404 416; per-dir `du` → native-export 914 677 760, node_modules 89 391 104, dist 23 273 472; unique-content table F10 | Remove the whole worktree (covers exports, `node_modules`, `dist`); alternative partial option: delete only `artifacts/local/native-export` to reclaim 872 MiB and keep the worktree | Worktree removal reversible for tracked files only; exports are gone unless re-run (`node scripts/native-smoke.mjs --export` on pinned 4.7.2) |
| W-06 | S2 | 9 × `.git/worktrees/<id>/MERGE_RR` and `ORIG_HEAD` | Every worktree admin dir still carries a 0-byte `MERGE_RR` (merge-conflict rerere marker) and `ORIG_HEAD` from an earlier merge with no operation in progress; harmless but it looks like interrupted state and would mislead a resumer | `ls -a .git/worktrees/scrapkeep-wt-HF-01/` → `MERGE_RR`, `ORIG_HEAD`; `stat -c%s …/MERGE_RR` → 0; no `MERGE_HEAD`/`rebase-*` present | Removed automatically by `git worktree remove`; for parked worktrees leave as-is or clean later with `git rerere`/`git update-ref -d ORIG_HEAD` (operator) | Cosmetic; no content at risk |
| W-07 | S3 | `artifacts/local/audit-2026-09-10/cleanup-dry-run.out` | The saved dry-run receipt is stale relative to the planner: it lists `REMOVE node_modules 86MB` for the live repo, while the current `cleanup-dry-run.sh` prints `KEEP node_modules (live tooling; removing it breaks the checks)` | `grep -n node_modules cleanup-dry-run.out` → lines 52–53 `REMOVE`; `grep -n node_modules cleanup-dry-run.sh` → line 47 comment + line 52 `KEEP` | Regenerate the receipt after the next planner edit; keep node_modules in the live repo | Reversible (file regenerate) |
| W-08 | S3 (S2 edge) | dangling commit `4a6ad359a7966e86950c2e1dc0be67ddc2e17f5a` | An orphaned stash-shaped WIP commit for `wt/PS-01` is unreachable and invisible to `git stash list`; it survives only because nothing has gc'd it. Its 6 CONTRIBUTING.md lines are all superseded by main | `git fsck --no-progress --dangling` → `dangling commit 4a6ad359…`; `git stash list` → empty; `git log -1 4a6ad359…` → `WIP on wt/PS-01 …`; main `CONTRIBUTING.md` lines 36–40, 53 cover the same commands | No action needed; optionally record the SHA in the audit note before gc (this report does) | Irreversible after gc, but no unique content (inference, F8) |
| W-09 | S4 | `refs/codex/turn-diffs/checkpoints/**` (2 tree refs) | Two Codex turn-diff checkpoint trees each describe ~169 MiB of repo content and look like heavy leftovers | `git for-each-ref refs/codex`; `comm -23 <(git ls-tree -r <tree> \| awk '{print $3}' \| sort -u) <(git rev-list --objects <all heads+remotes> \| awk '{print $1}' \| sort -u)` → 10 unique blobs / 0.19 MiB and 0 unique blobs | Keep (tool metadata); not a disk win. Do not delete blindly — they are the Codex turn-diff history | Deleting refs drops 0.19 MiB of unique blobs plus the diff index; not needed |
| W-10 | S4 | `/home/andrew/Projects/scrapkeep` ignored output | Main holds 390 643 712 B `artifacts/local` (366 MB of it `sprint-0/final` + `sprint-0/closed`, cited by committed `docs/project/sprint-0/closure.json`), 89 391 104 B `node_modules`, 23 273 472 B `dist`; 476 MB that look like slop to a naive pass but are cited evidence or live tooling | `du -s --block-size=1 artifacts/local node_modules dist`; `grep -rn "sprint-0/final\|sprint-0/closed" docs/project/sprint-0/closure.json` → cited paths | Keep all three; `dist/` is regenerable but is live build output for the audit lanes | `dist/`: regenerable by build; `node_modules`: reinstall; `artifacts/local/sprint-0/*`: cited closure evidence, not reversible |
| W-11 | S3 | `wt/S0-07` tip `90f08c4`, `wt/S0-04` tip `d40e19d` | Branch names and commit subjects do not line up (`wt/S0-07` subject says "(S0-08)"; `wt/S0-04`'s subject references S0-04 while its content family is S0-04/S0-06) — a board/naming drift signal, not a content risk | `git log -1 --format='%h %s' wt/S0-07` → `90f08c4 Execute the TADR-004 save-owner proof and record evidence (S0-08)`; `git log -1 --format='%h %s' wt/S0-04` → `d40e19d Run native proofs from the smoke runner and record S0-04` | Note for lane 3 (canonical) / lane 2 (recovery); no branch action | N/A |

## 3. Uncertain / needs owner decision

1. **HF-05 candidate of record.** Is `ea522c3` the intended deliverable, or an unrecorded partial
   written just before the crash? TRACKING (`Candidate identity: null`) does not say. The coordinator
   must record the identity or declare the commit an unadmitted attempt before review.
2. **HF-04a / HF-05 writer leases.** ORCHESTRATOR ("Ownership, checkpoints and interruption")
   requires confirming the worker stopped, preserving evidence, then releasing or transferring the
   lease. This audit can see the processes are gone (no git state, no locks) but not the board's
   lease objects; the coordinator must record recovery before the parked worktrees are ever removed.
3. **The 927 725 380 B of excluded Godot exports and caches.** They are the only copy of those exact
   bytes, but they are regenerable build output inside a directory the project itself calls
   disposable, and main's closure-cited `final/`/`closed/` exports are retained. Archive or accept
   loss — owner call (D1 approves removing generated output; "preserve historical evidence" cuts the
   other way).
4. **The 10 loose merged branch refs.** All content is in main and they cost 0 bytes; keeping them
   preserves the original task/branch mapping as an audit trail, deleting them tidies `git branch`.
5. **The two Codex checkpoint tree refs** (0.19 MiB unique). Tool metadata of unclear retention
   value; owner/coordinator call.
6. **Whether `wt/S0-07`'s "(S0-08)" subject indicates a mis-recorded board event** — lane 3 territory.
7. **Partial vs full S0-09 cleanup.** Removing the worktree destroys the regenerable exports and its
   `node_modules` (89 MB) in one step; deleting only `artifacts/local/native-export` keeps the
   worktree usable as a native-proof environment. D1 allows either; the worktree is stale by 33
   commits, so full removal is the tidier choice.

## 4. Recommended atomic task cards

**C-1 — Freeze and re-verify the cleanup gate (S)**
Files/commands (run from `/home/andrew/Projects/scrapkeep`):
`git rev-parse main` (expect `b61feb187cfdcad71700c629e315a77de4e0f975`); `git status --short`
(expect exactly ` M TRACKING.md` and the untracked `…/HF-04a/attempt-1/`); then for
`b in wt/HF-01 wt/HF-02 wt/HF-03a wt/S0-09-operational wt/S0-11-operational wt/S0-12-operational wt/S0-13-operational`,
print `git cherry main $b | grep -c '^+'` (expect 0) and
`git -C "$(git worktree list --porcelain | awk -v r="refs/heads/$b" '$1=="worktree"{w=$2} $1=="branch"&&$2==r{print w}')" status --porcelain | wc -l` (expect 0).
Observable acceptance: base SHA unchanged, every candidate shows `0/0`, no branch ahead of main has
gained commits. Verification: `bash artifacts/local/audit-2026-09-10/cleanup-dry-run.sh` → `GATE: PASS`.

**C-2 — Make branch deletion reversible with backup tags (S)**
Files/commands: `git tag "audit-2026-09-10/${b//\//_}" "$b"` for every `b` in
`git for-each-ref --format='%(refname:short)' refs/heads | grep '^wt/'`.
Observable acceptance: `git tag -l 'audit-2026-09-10/*' | wc -l` → 19 and
`git rev-parse audit-2026-09-10/wt_HF-04a` → `72178cf58a39e9ca1c70922eca830776573f3ce8`.
Verification: `git for-each-ref --format='%(refname:short) %(objectname:short)' refs/tags/audit-2026-09-10`
compared against the F2/F4 table. Reversibility: `git tag -d` restores the pre-cleanup state.

**C-3 — Regenerate the stale dry-run receipt and hash-manifest the preserved archive (S)**
Files: `artifacts/local/audit-2026-09-10/cleanup-dry-run.out` (stale, W-07),
`artifacts/local/audit-2026-09-10/preserved/**` (957 files, 5 009 408 B, verified to contain all
non-regenerable unique content per F10).
Commands: `bash artifacts/local/audit-2026-09-10/cleanup-dry-run.sh > artifacts/local/audit-2026-09-10/cleanup-dry-run.out`;
`find artifacts/local/audit-2026-09-10/preserved -type f -print0 | sort -z | xargs -0 sha256sum > artifacts/local/audit-2026-09-10/preserved/MANIFEST.sha256`.
Observable acceptance: receipt shows `KEEP node_modules` and `GATE: PASS`; manifest lists 957 files.
Verification: `sha256sum -c artifacts/local/audit-2026-09-10/preserved/MANIFEST.sha256` → all OK.

**C-4 — Remove the seven content-merged worktrees (M)**
Files/commands (after C-1…C-3):
`git worktree remove /home/andrew/Projects/scrapkeep-wt-HF-01`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-HF-02`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-HF-03a`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-S0-09-operational`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-S0-11-operational`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-S0-12-operational`
`git worktree remove /home/andrew/Projects/scrapkeep-wt-S0-13-operational`
(no `--force` needed: all seven verified clean and no `locked` file exists). Do **not** touch
`scrapkeep-wt-HF-04a` / `scrapkeep-wt-HF-05` (D2).
Observable acceptance: `git worktree list` shows main + HF-04a + HF-05 only;
`du -s --block-size=1 /home/andrew/Projects/scrapkeep-wt-*` total drops from 2 673 405 952 to
363 085 824 (reclaim **2 310 320 128 B**). Verification: `git worktree list --porcelain`,
`git fsck --no-progress --dangling` (no new dangling commits beyond `4a6ad359…`), `du` before/after.
Reversibility: tracked content restored by `git worktree add <path> <branch|tag>`; the worktrees'
ignored `artifacts/local`, `dist`, `node_modules` are not restored (non-regenerable parts archived).

**C-5 — Delete the seventeen content-merged branch refs (S)**
Files/commands:
`git branch -D wt/HF-01 wt/HF-02 wt/HF-03a wt/S0-09-operational wt/S0-11-operational wt/S0-12-operational wt/S0-13-operational`
(patch-id-merged but not ancestors — `-d` refuses);
`git branch -d wt/PS-01 wt/PS-02 wt/PS-03 wt/PS-04 wt/PS-05a wt/PS-05b wt/S0-01 wt/S0-04 wt/S0-05 wt/S0-07`
(tips are ancestors of main).
Observable acceptance: `git branch` shows `main`, `wt/HF-04a`, `wt/HF-05`; every deleted tip still
resolves through its `audit-2026-09-10/*` tag. Verification: `git rev-parse <tag>` for all 19,
`git merge-base --is-ancestor <sha> main` for the 10 loose ones. Reversibility: `git branch <name> <tag>`
recreates any ref exactly; without C-2 it is **not** reversible for the seven `-D` branches.

**C-6 — Resolve the two parked candidates (M)**
Files: `docs/tech/sections/HF-04a-runtime-lifecycle.md`, `docs/tech/sections/HF-05-content-admission.md`,
`TRACKING.md` (HF-04a/HF-05 rows), review records under `artifacts/foundation-sprint-2026-09/tasks/<ID>/`.
Commands: assign fresh independent reviewers per ORCHESTRATOR "Handoff and review" against candidates
`72178cf` / `ea522c3` (tags from C-2 preserve them if the worktrees are later removed); record the
HF-05 candidate identity first. Observable acceptance: each card has a recorded verdict
(PASS/PASS+NOTES/FAIL/BLOCKED/INCONCLUSIVE) and an admitted integrated identity, or a
`changes_requested`/`blocked` state. Verification: `git log main --oneline -- docs/tech/sections/HF-04a-runtime-lifecycle.md`
non-empty if admitted, plus the TRACKING event. Reversibility: n/a (governance step).

**C-7 — Admit the cut-off coordinator's records and evidence (S/M)**
Files: `TRACKING.md` (10 insertions / 6 deletions incl. EV-0090–EV-0092),
`artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` (10 files).
Commands: coordinator reviews `preserved/tracking-uncommitted.diff` against the live working copy,
then stages and commits the corrected rows and the attempt-1 evidence (docs-only path; no build).
Observable acceptance: `git status --short` → empty; `git show HEAD:TRACKING.md` contains EV-0090,
EV-0091, EV-0092. Verification: `git show HEAD:TRACKING.md | grep -c 'EV-009[012]'` → 3;
`git cat-file -e HEAD:artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/handoff.json`.
Reversibility: git history (revert); the pre-admission state is preserved in `preserved/`.

## 5. Method and limits

Method: every classification was computed twice by independent means — (a) `git cherry` unmerged
markers, (b) `git patch-id --stable` matching against all of main's commits, and (c) for the seven
content-merged branches, byte comparison of every branch-touched file against main's blob
(`git rev-parse main:<path>` vs `git rev-parse <b>:<path>`). Disk numbers are exact bytes from
`du -s --block-size=1`; per-worktree byte composition from `du` per subtree. Worktree-local evidence
was classified by hashing every file in all nine worktrees (`git hash-object`) and testing blob
existence against `git rev-list --objects main`, then cross-checked against the archive under
`artifacts/local/audit-2026-09-10/preserved/wt-local/` with `cmp`.

What I did **not** check (limits):
- No mutating git command was run: no add/commit/checkout/switch/stash/clean/reset/worktree
  add|remove|prune/`branch -d|D`/fetch/push; the report you are reading is the only file written.
- `git worktree prune --dry-run` was not run (forbidden); prunability was established from
  `.git/worktrees/<id>/gitdir` targets, the absence of `locked` files, and matching counts.
- No network: `origin/*` refs were not refreshed, so remote state is as of the last fetch
  (last-known: `origin/main` `f582918`, `origin/codex/lightning-playtest`; no `wt/*` remote refs).
- No build, install, `npm` script, browser check or Godot/native command; no `npm ci`, no
  `node_modules` inspection beyond size.
- No verification of the content quality of the HF-04a/HF-05 sections — that is reviewer work, not
  an audit of identity.
- The 14 excluded Godot binaries/caches were sized and hashed but not opened or executed; I did not
  compare their behaviour to main's retained exports (only observed that sha256 differs).
- I did not inventory open file handles, OS locks, or IDE state for the worktrees; no process check
  beyond git state and absence of `locked`/`MERGE_HEAD` markers.
- Only `/home/andrew/Projects/scrapkeep` (+ its nine worktrees) was audited; other repositories
  under `/home/andrew/Projects/` were not touched.
- `git fsck` ran without `--lost-found` (no writes); dangling objects were counted, and only the
  dangling commit was inspected in detail. Dangling blobs/trees were not individually attributed.
