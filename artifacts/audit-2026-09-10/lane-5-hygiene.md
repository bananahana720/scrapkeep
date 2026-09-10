# Lane 5 — repo hygiene and evidence weight

Read-only audit. Repo root `/home/andrew/Projects/scrapkeep`, HEAD `b61feb187cfdcad71700c629e315a77de4e0f975` (`docs: assign runtime lifecycle and content admission contracts`), branch `main...origin/main [ahead 18]`. Audit date 2026-09-10. No mutating git command, no build, no network, no deletion was run. The only file written is this report.

**Snapshot warning (read first).** Sibling audit lanes were writing to `artifacts/local/audit-2026-09-10/` while this audit ran. Every size under `artifacts/local/` therefore moves. Tracked figures are stable (HEAD did not change); untracked figures are a snapshot. All `artifacts/local/` and ignored-material totals below are taken from a **final consolidated measurement at `2026-09-10T16:37:01Z`**, in which `artifacts/local` = 385,170,842 B across 1,782 files. The first measurement, taken minutes earlier in the same run, read 382,901,876 B across 708 files — a **+2,268,966 B / +1,074 file** delta produced entirely by the sibling lanes' reports, not by anything this audit did. Where the two differ, this report uses the later figure and names the earlier one.

Scope: `artifacts/**`, `public/**` (weight and live-asset reachability only), `dist/**`, `.gitignore`, `.github/**`, `.env.example`, `package.json`/`package-lock.json`, `node_modules` presence, top-level clutter (`COHESION_REPORT.md` skipped — another lane), and the sibling worktrees at `/home/andrew/Projects/scrapkeep-wt-*`. `public/art` duplicate-art analysis belongs to another lane; this lane records only live-asset reachability and the `dist/` copy weight.

## 1. Verified state — facts, each with the exact command run and its observed result

### 1.1 Git object weight

| # | Command | Observed result |
|---|---|---|
| F1 | `git count-objects -vH` | `count: 131`, `size: 1.07 MiB`; `in-pack: 2658`, `packs: 3`, `size-pack: 131.23 MiB`; `prune-packable: 0`, `garbage: 0`, `size-garbage: 0 bytes` |
| F2 | `git cat-file --batch-all-objects --batch-check='%(objecttype) %(objectsize)'` | `blob 1894 objects 185,949,112 B (177.3 MiB)`; `commit 137 / 55,612 B`; `tree 758 / 498,574 B` |
| F3 | `git rev-list --objects --all \| git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \| awk '$1=="blob"{print $2,$3,$4}' \| sort -k2 -n \| tail -10` | Largest blobs, all PNG: `docs/bible/images/M02-v1.png` 3.38 MiB (`aa7fe988`), `U01-v1.png` 3.29 (`ec2c5a24`), `public/art/06-orchard-combat-storyboard-v2.png` 3.24 (`02f1f852`), `06-orchard-combat-storyboard.png` 3.24 (`b6f37dc3`), `docs/bible/images/M00-v1.png` 3.16 (`c4eb6140`), `M01-v1.png` 3.10, `P01-v1.png` 3.10, `C04-v1.png` 3.07, `E02-v1.png` 3.01, `F01-v1.png` 3.00 |
| F4 | `du -sb .git` / `du -sh .git` | `141,063,243 B` / `136M` |
| F5 | `git ls-files -z \| xargs -0 -r du -cb \| tail -1` | tracked working-tree total `177,361,954 B` (169.1 MiB) |
| F6 | `git ls-files -z \| du -cb --files0-from=-`, same with `--others --exclude-standard`, same with `--others --ignored --exclude-standard` | `TRACKED 177,361,954`; `UNTRACKED 73,618`; `IGNORED 490,470,379` at first measurement, re-measured `492,739,345` at `2026-09-10T16:37:01Z` (see snapshot warning) |
| F7 | per-top-level aggregation of `git ls-files` + `os.path.getsize` | `docs 216 files / 85.72 MiB`; `artifacts 1369 / 60.27 MiB`; `public 9 / 21.12 MiB`; `tools 26 / 0.71`; root files `17 / 0.56`; `src 16 / 0.34`; `tests 40 / 0.19`; `native 32 / 0.09`; `scripts 9 / 0.08`; `adr 6 / 0.03`; `server 4 / 0.02`; `.agents 3`; `.claude 11`; `.github 1`; `.codex 1` |
| F8 | tracked bytes by extension | `.png 64 files / 108.77 MiB`; `.jpg 165 / 22.19`; `.ndjson 35 / 20.46`; `.json 742 / 12.93`; `.md 218 / 2.34`; `.txt 236 / 0.70`; `.js 32 / 0.50`; `.log 119 / 0.30`; `.gz 2 / 0.26`; `.py 42 / 0.21`; `.patch 4 / 0.19`; `.mjs 13 / 0.09` |

Tracked-binary weight: **`.png + .jpg` = 130.96 MiB of the 169.1 MiB tracked total (77%)**; `docs/bible/images` alone is `30 files / 87,463,831 B`, `public/art` is `8 files / 22,149,367 B`.

### 1.2 `artifacts/` size inventory

`du -sh artifacts/*/ | sort -rh`, with file counts and tracked/untracked byte splits from the final consolidated snapshot (`2026-09-10T16:37:01Z`):

| Directory | `du -sh` | apparent bytes (`du -sb`) | tracked bytes | untracked bytes | files |
|---|---|---|---|---|---|
| `artifacts/local/` | 367M | 385,170,842 | **0** | 385,170,842 | 1,782 |
| `artifacts/agent-recovery-2026-09-06/` | 39M | 39,795,831 | 39,795,831 | 0 | 516 |
| `artifacts/agent-player-2026-09-06/` | 17M | 16,719,742 | 16,719,742 | 0 | 268 |
| `artifacts/prepare-stage-2026-09-06/` | 1.9M | 613,891 | 613,891 | 0 | 393 |
| `artifacts/visual-iterations/` | 1.1M | 1,101,862 | 1,101,862 | 0 | 8 |
| `artifacts/lightning-playtest/` | 844K | 816,976 | 816,976 | 0 | 19 |
| `artifacts/foundation-sprint-2026-09/` | 572K | 346,453 | 272,835 | 73,618 | 93 |
| `artifacts/agent-infrastructure-2026-09-06/` | 328K | 320,602 | 320,602 | 0 | 6 |
| `artifacts/publication-2026-09-06/` | 292K | 264,982 | 264,982 | 0 | 13 |
| `artifacts/ai-first-audit-2026-09-06/` | 244K | 217,457 | 217,457 | 0 | 16 |
| `artifacts/swarm-prep-2026-09-06/` | 100K | 83,046 | 83,046 | 0 | 8 |
| `artifacts/housekeeping-2026-09-05/` | 72K | 42,080 | 42,080 | 0 | 10 |
| `artifacts/orchard-first-build/` | 8.0K | 4,811 | 4,811 | 0 | 2 |
| **total** `artifacts/` | **431M** | **448,442,104** | **63,197,644** | **385,244,460** | 3,160 (1,369 tracked + 1,791 untracked) plus 27 loose root files; the live `find` count read 3,161 during concurrent writes |

`du -sh artifacts/` → `431M` (the block-rounded figure is stable because the growth is small text files); `du -sh --exclude=.git .` → `648M`; `du -sb --exclude=.git .` → `670,136,968 B`.

Top 25 files under `artifacts/` (`find artifacts -type f -printf '%s\t%p\n' | sort -rn | head -25`), exact byte sizes:

| Bytes | Path |
|---|---|
| 109,339,248 | `artifacts/local/sprint-0/final/scrapkeep.exe` |
| 109,339,248 | `artifacts/local/sprint-0/closed/scrapkeep.exe` |
| 73,590,176 | `artifacts/local/sprint-0/final/scrapkeep.x86_64` |
| 73,590,176 | `artifacts/local/sprint-0/closed/scrapkeep.x86_64` |
| 4,505,921 | `artifacts/local/sprint-0/final/visible/data/godot/app_userdata/scrapkeep-native-proofs/vulkan/pipelines.forward_plus.nvidia_geforce_rtx_4080.cache` |
| 4,505,897 | `artifacts/local/sprint-0/closed/visible-2/…/pipelines.forward_plus.nvidia_geforce_rtx_4080.cache` |
| 3,180,290 | `artifacts/local/sprint-0/closed/visible/…/pipelines.forward_plus.nvidia_geforce_rtx_4080.cache` |
| 1,754,884 | `artifacts/agent-recovery-2026-09-06/synthesis-live/trial-002/events.ndjson` |
| 1,741,325 | `artifacts/agent-recovery-2026-09-06/final-live/trial-001/events.ndjson` |
| 1,726,157 | `artifacts/agent-recovery-2026-09-06/extended-live/trial-002/events.ndjson` |
| 1,707,117 | `artifacts/agent-recovery-2026-09-06/relocation-live/trial-001/events.ndjson` |
| 1,278,151 | `artifacts/agent-recovery-2026-09-06/candidate-b/trial-001/events.ndjson` |
| 1,225,788 | `artifacts/agent-recovery-2026-09-06/synthesis-live/trial-001/events.ndjson` |
| 1,209,525 | `artifacts/agent-recovery-2026-09-06/candidate-a/trial-001/events.ndjson` |
| 1,107,089 | `artifacts/agent-recovery-2026-09-06/stationary-live/trial-003/events.ndjson` |
| 944,963 | `artifacts/agent-player-2026-09-06/visual-development-04/trial-002/events.ndjson` |
| 900,277 | `artifacts/agent-player-2026-09-06/visual-development-05/trial-002/events.ndjson` |
| 868,375 | `artifacts/agent-player-2026-09-06/default-visual/trial-001/events.ndjson` |
| 865,350 | `artifacts/agent-player-2026-09-06/companion-comparison/trial-001/events.ndjson` |
| 835,101 | `artifacts/browser-regression.png` (loose file at `artifacts/` root) |
| 763,154 | `artifacts/agent-player-2026-09-06/baseline-timeout/trial-001/events.ndjson` |
| 702,070 | `artifacts/agent-recovery-2026-09-06/extended-live/trial-001/events.ndjson` |
| 683,814 | `artifacts/agent-recovery-2026-09-06/stationary-live/trial-002/events.ndjson` |
| 633,833 | `artifacts/expedition-menu.png` (loose) |
| 606,754 | `artifacts/agent-recovery-2026-09-06/stationary-live/trial-001/events.ndjson` |

**`artifacts/local/sprint-0/` alone is 381,543,138 B = 99.1% of `artifacts/local/`.** Of that, the four Godot executables are 365,858,848 B — 95.9% of `sprint-0/` and 95.0% of all of `artifacts/local/`. These files are stable; the sibling lanes wrote only small text into `artifacts/local/audit-2026-09-10/`.

### 1.3 Ignored / untracked material in the main checkout

`git ls-files -z --others --ignored --exclude-standard | du -cb --files0-from=- | tail -1` → `492,739,345` total at `2026-09-10T16:37:01Z` (first measurement: `490,470,379`; the +2,268,966 B delta is the sibling lanes' `artifacts/local/audit-2026-09-10/` output). Component breakdown:

| Component | Bytes | MiB |
|---|---|---|
| `artifacts/local/` | 385,170,842 | 367.34 |
| `node_modules/` | 84,188,160 (`du -sb`; raw file-size sum is 107,133,881 — npm hardlink dedup) | 80.28 |
| `dist/` | 23,194,770 | 22.12 |
| `tools/agent-player/__pycache__/` + `tools/agent-player/tests/__pycache__/` | 87,084 + 98,379 = 185,463 | 0.18 |
| `.claude/settings.local.json` | 110 | 0.00 |
| **Total ignored** | **492,739,345** | **469.91** |
| Untracked, not ignored (`git status --porcelain` `??`) | 73,618 | 0.07 |
| **Bytes a clean checkout would not contain** | **492,812,963** | **469.98** |

`git status --porcelain --ignored` (complete output): ` M TRACKING.md`; `?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/`; `!! .claude/settings.local.json`; `!! artifacts/local/`; `!! dist/`; `!! node_modules/`; `!! tools/agent-player/__pycache__/`; `!! tools/agent-player/tests/__pycache__/`.

### 1.4 Tracked junk and `.gitignore` coverage

`git ls-files -z | xargs -0 -r git check-ignore --no-index | wc -l` → **`0`**. **No tracked file lives under a path the current `.gitignore` excludes.** Specifically verified zero tracked under each now-ignored pattern: `native/*.import` → 0, `__pycache__` → 0, `^dist/` → 0, `^node_modules/` → 0, `^artifacts/local/` → 0, `^\.claude/worktrees/` → 0, real `.env` → 0 (the single `\.env` match is the tracked `.env.example`, protected by `!.env.example`).

`.gitignore` (222 B) in full: `node_modules/`, `dist/`, `.private/`, `.env`, `.env.*`, `!.env.example`, `artifacts/local/`, `npm-debug.log*`, `.DS_Store`, `__pycache__/`, `*.pyc`, `*.pem`, `*.crt`, `*.key`, `leads.json`, `leads-*.tmp`, `leads.lock`, `.claude/worktrees/`, `native/.godot/`, `native/**/*.import`.

Tracked material that *looks* like scratch but is deliberate retained evidence: 119 tracked `*.log` files, all under `artifacts/**` (317,085 B total, 0.30 MiB) — build/test/check receipts cited by `TRACKING.md` events. No tracked `__pycache__`, `*.import`, `*.pyc`, tarball, `*.exe` or editor backup file exists anywhere in the repo. `native/.godot/` does not exist in the main checkout (`ls native/` → `export_presets.cfg`, `integration/`, `project.godot`, `proofs/`, `README.md`, `tests/`).

`.claude/settings.local.json` is ignored by a **global** rule, not the repo's file: `git check-ignore -v` → `/home/andrew/.config/git/ignore:1:**/.claude/settings.local.json`.

### 1.5 `artifacts/local/` — the disposable tier

Present subdirectories (`du -sb artifacts/local/*/ | sort -rn`, final snapshot; `audit-2026-09-10/` belongs to the sibling audit lanes and was growing throughout this run):

| Directory | Files | Bytes |
|---|---|---|
| `sprint-0/` | 329 | 381,543,138 |
| `audit-2026-09-10/` | 969 | 2,092,524 |
| `tasks/` | 122 | 747,168 |
| `ai-first-audit-2026-09-06/` | 16 | 217,457 |
| `native-smoke/` | 106 | 170,536 |
| `foundation-01/` | 20 | 114,137 |
| `proofs/` | 204 | 110,859 |
| `foundation-full/` | 7 | 69,746 |
| `verify/` | 7 | 51,709 |
| `check-docs/` | 1 | 15,619 |

(The `audit-2026-09-10/` file count moved 1 → 969 during this run; at the start it held only the sibling `PLAN.md`, 4,075 B.)

`sprint-0/` splits into `final/` (181M, the superseded pending closure) and `closed/` (185M, the admitted closure), plus 26 loose receipts/logs at its root. `artifacts/local/tasks/` holds receipts for 12 task ids: `AM-FF-001`, `foundation-01-review`, `HF-01`, `HF-02`, `HF-03a`, `HF-04a`, `HF-06a`, `S0-09`, `S0-10`, `S0-11`, `S0-12`, `S0-13`.

**References into `artifacts/local/` from tracked text.** `grep -rhoE 'artifacts/local/[A-Za-z0-9._/-]+'` over tracked `*.md/*.json/*.js/*.mjs/*.py/*.txt` yields **130 distinct paths**; `36` exist on disk, `94` do not. The misses split into three classes:

- **Genuinely missing evidence asserted as observed** (real finding, see H-02): `artifacts/local/tasks/S0-01/ctx7-godot.txt`, `…/S0-01/probe-warning-key.txt`, `artifacts/local/tasks/S0-04/**` (entire dir), `…/S0-05/**`, `…/S0-07/**`, `artifacts/local/tasks/HF-03a/check_contract.py`, `artifacts/local/proofs/tadr-004/run-20260906T190853Z-1788721733739` (and `…3959`).
- **Forward-looking planned paths** in `BACKLOG.md` card definitions — e.g. `artifacts/local/tasks/TH-01/` … `TH-31/`, `SC-01/`…`SC-08/`, `LG-01/`…`LG-07/`, `PD-01/`…`PD-03/`, `HF-04b/`, `HF-05/`, `HF-07a/`…`HF-10/`. `BACKLOG.md:26` states the contract explicitly: "Work under `artifacts/local/tasks/ID/` (ignored). At handoff copy every receipt the coordinator will cite into `artifacts/foundation-sprint-2026-09/tasks/ID/` … because `artifacts/local/` is not committed." These are not defects.
- **Schema examples** — `artifacts/local/sprint-0/prior-task-review.md` appears only inside the `EXAMPLE-PRIOR` JSON block of `docs/project/sprint-0/closure-receipt.md:47`; `artifacts/local/tasks/ID/` is a literal placeholder.

**Only-copy check.** `docs/project/sprint-0/closure.json` is tracked and contains **12 `path`+`sha256` evidence entries, all under `artifacts/local/sprint-0/closed/`**. A read-only Python walk verified **12 present, 0 missing, 0 hash-mismatch**:

```
ec6fb1d6ea41  artifacts/local/sprint-0/closed/docs.log
cf6a6119ecee  artifacts/local/sprint-0/closed/project.log
1c269139cc2b  artifacts/local/sprint-0/closed/integrated-review.md   (cited twice)
9360ba38365d  artifacts/local/sprint-0/closed/native-report.json     (cited three times)
09abf7bfbd9d  artifacts/local/sprint-0/closed/visible-receipt.json
a1dc6bb304e8  artifacts/local/sprint-0/closed/ci-native-report.json
0cefb3bceec8  artifacts/local/sprint-0/closed/verify.log
d7e062ea253b  artifacts/local/sprint-0/closed/coverage-review.md
e184c6f38414  artifacts/local/sprint-0/closed/runner-cleanup.json
```

`docs/project/sprint-0/closure.json` is byte-identical to `artifacts/local/sprint-0/closed/closure.json` (both `6a2b53d55919…`); the superseded `artifacts/local/sprint-0/final/closure.json` is `ebbbe60a252a…`. Additional tracked strings in the same file cite `artifacts/local/tasks/S0-09/review.md` and `artifacts/local/tasks/S0-13/review.md` (both currently present, 1,140 B and 1,068 B).

Other only-copies inside `artifacts/local/`:
- `artifacts/local/native-smoke/report.json` (28,515 B, `4b56bf536db4…`) — `docs/tech/native-toolchain.md:71` says "The report remains at `artifacts/local/native-smoke/report.json`". The three tracked copies under `artifacts/prepare-stage-2026-09-06/` are older and different (`…/tasks/S0-01/native-smoke-report.json` is 3,555 B, `7c5c38d30b0c…`).
- `artifacts/local/proofs/tadr-004/` — 204 files / 110,859 B of run directories referenced by `docs/tech/proofs/S0-07-save-owner.md` and `S0-08-save-evidence.md`.
- `artifacts/local/sprint-0/closed/visible/` and `closed/visible-2/` — the visible-run screenshots behind `visible-receipt.json`.

The four export binaries in main are all-distinct builds (`sha256sum`): `final/scrapkeep.exe` `bc46787c6561…`, `final/scrapkeep.x86_64` `285413af94b6…`, `closed/scrapkeep.exe` `fb26b01d2eb9…`, `closed/scrapkeep.x86_64` `012a9b481558…`. Only the `closed/` pair is inside the tracked chain — `closed/native-report.json` records `fb26b01d2eb9…`/`012a9b481558…`, and `closed/coverage-review.md:27` independently reconfirms the Linux hash. The `final/` pair is not hash-pinned by any tracked file.

### 1.6 Retention and duplication

- sha256 over all 1369 tracked files under `artifacts/`: **70 byte-identical groups covering 268 files**, `1,417,895 B` inside those groups, **`877,086 B` (0.84 MiB) redundant**. Largest groups: `agent-player-2026-09-06/defeat-cycles/trial-001|002|003/terminal.jpg` + `passive-restart/trial-001/terminal.jpg` (4 copies, 87,259 B each); `defeat-cycles/trial-00{1,2,3}/restarted-paused.jpg` (3 copies, 124,973 B each); and a structural `artifacts/prepare-stage-2026-09-06/receipts/<X>` == `artifacts/prepare-stage-2026-09-06/tasks/<card>/<X>` mirror (≈30 of the 70 groups).
- README/manifest coverage across the 12 retained evidence directories (excluding `artifacts/local/`):

| Directory | Files | Bytes | `README.md` | `manifest.json` or `implementation-manifest.json` |
|---|---|---|---|---|
| `agent-infrastructure-2026-09-06/` | 6 | 320,602 | yes | yes |
| `agent-player-2026-09-06/` | 268 | 16,719,742 | yes | no |
| `agent-recovery-2026-09-06/` | 516 | 39,795,831 | yes | no (4 nested `implementation-manifest.json` exist under `candidate-a/`, `candidate-b/`, `extended-live/`, `synthesis-live/`) |
| `ai-first-audit-2026-09-06/` | 16 | 217,457 | **no** | **no** |
| `foundation-sprint-2026-09/` | 93 | 346,453 | **no** | **no** |
| `housekeeping-2026-09-05/` | 10 | 42,080 | **no** | **no** |
| `lightning-playtest/` | 19 | 816,976 | **no** | yes |
| `orchard-first-build/` | 2 | 4,811 | **no** | **no** |
| `prepare-stage-2026-09-06/` | 393 | 613,891 | **no** | **no** |
| `publication-2026-09-06/` | 13 | 264,982 | **no** | **no** |
| `swarm-prep-2026-09-06/` | 8 | 83,046 | **no** | **no** |
| `visual-iterations/` | 8 | 1,101,862 | **no** | **no** |

**9 of 12 lack `README.md`; 10 of 12 lack any manifest; 9 lack both.** Only `artifacts/README.md` (1,616 B) exists as a directory-level policy document, and it is one of 27 loose files sitting at the `artifacts/` root (2,943,529 B total).

- `artifacts/` root clutter: 27 loose files, 2,943,529 B — `artifacts/browser-regression.png` (835,101), `artifacts/expedition-menu.png` (633,833), `stress-scene-final.png`, `figurine-collection.png`, `01-title-screen.png`, `02-gameplay.png`, `stress-scene.png`, `expedition-mobile-menu.png`, `hero-preview.png`, `figurine-mobile.png`, `03-pause.png`, `05-mobile-gameplay.png`, `04-mobile-title.png`, `06-landscape-title.png`, `07-mobile-upgrade.png`, `expedition-balance.json`, `performance-stress.json`, `performance-stress-final.json`, `browser-tests.json`, `lead-browser-tests.json`, `balance.json`, `retention-tests.txt`, `balance-log.txt`, `retention-build.txt`, `build.txt`, `simulation-tests.txt`, `README.md`.

### 1.7 `public/` and `dist/`

- `du -sb public` → `22,149,658 B`; 9 files. `public/art/` holds 8 PNGs totalling `22,149,367 B` (21.1 MiB); `public/favicon.svg` is 291 B.
- Live-asset reachability: grepping each `public/**` basename across `index.html`, `orchard.html`, `src/`, `server/`, `scripts/`, `tests/` returns **`public/favicon.svg` referenced 2 times and all 8 `public/art/*.png` referenced 0 times**. They are reachable only as documentation images (`docs/ART-DIRECTION.md`, `docs/BASELINE-GUIDE.md:70`, `docs/CONCEPT-STUDY-01/02/03.md`, `docs/CONFLICT-AND-COMBAT.md`, `docs/DISCOVERY.md:215`, `docs/COMBAT-DESIGN-SWARM.md:29`). `docs/CONCEPT-STUDY-03.md:37` states the generated-image originals live outside the repo, so these are the in-repo copies.
- `dist/` is untracked build output: `git ls-files dist | wc -l` → `0`; `du -sb dist` → `23,194,770 B`; 31 files. `dist/art/` alone is `22.1 MiB`, and all 8 files are **byte-identical** to their `public/art/` sources (`sha256sum` comparison → `IDENTICAL` ×8). The remaining 23 files are `dist/assets/*` bundles, fonts and the two entry HTML files.

### 1.8 CI and configuration

- `.github/` contains exactly one file: `.github/workflows/native-smoke.yml` (3,921 B). It triggers on `workflow_dispatch` only, `permissions: contents: read`, one job on `runs-on: [self-hosted, linux, x64, scrapkeep-s0]`, `timeout-minutes: 20`, steps pinned by SHA (`actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`), downloads Godot 4.7.2 editor and export templates with `sha512sum --check`, then runs:

```
npm ci
npm run check:docs
npm run check:project
node --test tests/native-smoke.test.js
node scripts/native-smoke.mjs --export
```

and finally cats `artifacts/local/native-smoke/report.json` into the job summary. The workflow cannot execute today without a newly authorized runner registration: `docs/project/sprint-0/AUTHORIZATION.md:15` requires a temporary one-job runner, `docs/project/sprint-0/README.md:20` records "the runner was removed", and `docs/project/sprint-0/closure.json:64` records "job34060932888 passed and runner removed". The workflow's `artifacts/local/native-smoke/report.json` output path is inside the gitignored disposable tree.
- CONTRIBUTING command coverage: every `npm run <x>` CONTRIBUTING names exists in `package.json` **except `check:godot`**, which `CONTRIBUTING.md` itself documents as reserved ("Unavailable until the engineering handoff and engine-install authorization; no script exists yet"), as do `.agents/skills/scrapkeep-verify/SKILL.md:25` and `docs/project/AI-WORKFLOW.md:42`. This is a deliberate documented asymmetry, not drift. CONTRIBUTING's `npm ci` matches the workflow. The workflow's `node --test tests/native-smoke.test.js` is reachable from CONTRIBUTING only via `npm test` (`node --test tests/*.test.js`).
- `package.json` scripts with **zero external references** (`grep -rl "npm run <script>\b"` outside `package.json`): `start` (identical body to `server`) and `test:balance` (identical body to `probe:balance`; both are `node tests/balance.mjs`). `preview`/`build`/`check:build` have 1–5 references each. All 21 scripts are valid; there is no script with a broken path.
- `.env.example` (220 B) declares 8 keys — `BRAND_NAME`, `STORE_URL`, `PRIVACY_URL`, `CAPTURE_ENABLED`, `HOST`, `PORT`, `APP_ORIGIN`, `LEADS_DATA_DIR`. Grepping `process\.env\.<KEY>` across the repo (excluding `node_modules`, `.git`, `artifacts`, `dist`) finds **a reader for every one**: 1 each for `BRAND_NAME`, `STORE_URL`, `PRIVACY_URL`, `CAPTURE_ENABLED`, `HOST`, `PORT`, `LEADS_DATA_DIR`; 2 for `APP_ORIGIN`. **No dead key.** Undocumented-but-read variables also exist in the tooling layer (`GODOT_BIN`, `GODOT_TEMPLATES_ARCHIVE`, `ARTIFACT_DIR`, `CHROMIUM_PATH`, `GAME_URL`, `CODEX_PLAYER_PYTHON`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`) — these belong to runner/CI configuration, not `.env`.
- **Remote state contradicts two documents.** `git remote -v` → `origin https://github.com/bananahana720/scrapkeep.git (fetch/push)`; `git rev-parse --abbrev-ref --symbolic-full-name @{u}` → `origin/main`; `git rev-list --left-right --count origin/main...main` → `0  18`; `git log --oneline -1 origin/main` → `f582918 Close Sprint 0 after verified local CI and fresh reviews`. `docs/project/BACKLOG.md:11` (card T01) and `docs/project/HOUSEKEEPING.md:22` both still assert "No remote is configured yet" and "nothing leaves this machine yet".
- `package-lock.json` is present (38,603 B) and `node_modules/` is installed (19 top-level entries, 84,188,160 B).

### 1.9 Worktree disk

`git worktree list` → 10 entries (main + 9 worktrees). Per worktree, with `du -sb` and `git -C <wt> ls-files -z | xargs -0 -r du -cb`:

| Worktree | Total B | Tracked B | `node_modules` B | `dist` B | `artifacts/local` B | Export binaries B |
|---|---|---|---|---|---|---|
| `scrapkeep-wt-S0-09-operational` | 1,213,267,742 | 176,878,530 | 84,188,160 | 23,194,770 | 929,006,196 | 914,647,120 |
| `scrapkeep-wt-HF-05` | 177,493,859 | 177,376,349 | 0 | 0 | 117,436 | 0 |
| `scrapkeep-wt-HF-04a` | 177,466,452 | 177,392,759 | 0 | 0 | 73,618 | 0 |
| `scrapkeep-wt-HF-03a` | 177,211,580 | 177,162,103 | 0 | 0 | 49,402 | 0 |
| `scrapkeep-wt-HF-01` | 177,032,477 | 176,995,901 | 0 | 0 | 36,502 | 0 |
| `scrapkeep-wt-HF-02` | 177,023,940 | 176,994,551 | 0 | 0 | 29,315 | 0 |
| `scrapkeep-wt-S0-13-operational` | 176,945,358 | 176,883,730 | 0 | 0 | 61,542 | 0 |
| `scrapkeep-wt-S0-11-operational` | 176,876,229 | 176,826,862 | 0 | 0 | 49,281 | 0 |
| `scrapkeep-wt-S0-12-operational` | 176,852,323 | 176,821,370 | 0 | 0 | 25,458 | 0 |
| **9-worktree total** | **2,630,169,960** | **1,593,332,155** | 168,376,320 | 46,389,540 | 929,448,750 | 914,647,120 |

(The `du -sc -k` form of the same total reads `2,610,748` KiB — block-rounded disk usage rather than apparent bytes; all figures in this table are `du -sb`.)

The nine worktrees hold **nine near-identical tracked checkouts** (~176.9 MB each; 1,593,332,155 B of tracked content in total) plus **1,036,831,680 B (988.8 MiB) of generated material**. `S0-09-operational` alone carries 1,036,389,126 B of generated material — 85.4% of its own 1,213,267,742 B.

S0-09's `artifacts/local/native-export/` holds **five complete export runs** (`run-02WkfB`, `run-9EJekq`, `run-QNbRbl`, `run-WwLUR5`, `run-zZkI5H`), each one `scrapkeep.exe` (109,339,248 B) plus one `scrapkeep.x86_64` (73,590,176 B). `sha256sum` over all 14 export binaries in the repo + this worktree shows **all 14 hashes distinct** — Godot exports are not reproducible here. None of S0-09's ten hashes (`23208b49`, `284fef9d`, `21c922a1`, `eeeef4fc`, `7f6d712d`, `9a28dce9`, `9c1013b6`, `b9abf07e`, `d4173779`, `86b05084`) matches the hash-pinned `closed/` pair (`fb26b01d`, `012a9b48`), so they are superseded intermediates recorded nowhere tracked.

Combined, the main checkout and the S0-09 worktree hold **14 distinct Godot export binaries totalling 1,280,505,968 B (1.19 GiB)**.

### 1.10 Reclaimable totals

| Tier | Bytes | MiB | Composition | Evidence impact |
|---|---|---|---|---|
| A — regenerable build material | 214,951,323 | 205.0 | main `dist` 23,194,770 + main `node_modules` 84,188,160 + main `__pycache__` 185,463 + S0-09 `node_modules` 84,188,160 + S0-09 `dist` 23,194,770 | none (rebuildable from lockfile and sources) |
| B — disposable evidence | 1,314,619,592 | 1,253.7 | main `artifacts/local` 385,170,842 + S0-09 `artifacts/local` 929,006,196 + other 8 worktrees' `artifacts/local` 442,554 | destroys the 12 hash-pinned files behind `docs/project/sprint-0/closure.json` unless copied first |
| **A + B** | **1,529,570,915** | **1,458.7** | — | — |
| C — tracked historical evidence (not recommended) | 63,197,644 main `artifacts/**` (177,361,954 all tracked) | 60.3 | — | destroys retained evidence |

Tier B's main-checkout share is the moving target described in the snapshot warning: it was 382,901,876 B when first measured and 385,170,842 B at `2026-09-10T16:37:01Z`. Tier A and Tier C are unaffected by the concurrent writes.

## 2. Findings

| ID | Sev | Paths | What is wrong | Evidence (command → observed) | Proposed disposition | Reversibility |
|---|---|---|---|---|---|---|
| H-01 | **S1** | `docs/project/sprint-0/closure.json`; `artifacts/local/sprint-0/closed/{docs.log,project.log,integrated-review.md,native-report.json,visible-receipt.json,ci-native-report.json,verify.log,coverage-review.md,runner-cleanup.json}`; `.gitignore:7`; `AGENTS.md:12` | The tracked canonical sprint-closure receipt pins 12 sha256 evidence entries, **all inside the gitignored, explicitly disposable `artifacts/local/`**. The audit chain for a tracked authority record is currently valid (12/12 present and matching) but reproducible only while a directory the project authorises cleaning still exists. Nothing in `.gitignore`, `artifacts/README.md` or `docs/project/sprint-0/README.md` marks these 12 paths as pin-critical. | Python walk of `docs/project/sprint-0/closure.json` over 12 `path`+`sha256` pairs → `present+match=12 missing=0 hash-mismatch=0`; `sha256sum docs/project/sprint-0/closure.json artifacts/local/sprint-0/closed/closure.json` → both `6a2b53d55919…`; `grep -n 'artifacts/local' .gitignore` → `7:artifacts/local/` | Copy the 9 distinct pinned files (12 `path`+`sha256` entries; `native-report.json` is cited three times and `integrated-review.md` twice) into a retained dated evidence directory, commit them, and add a `pin-critical` note to `artifacts/local/README.md` naming them. Do not delete the originals. | Reversible only by copying today. Once pruned, the recorded hashes can be satisfied only by regenerating through the documented gates at the pinned source — which `docs/project/sprint-0/README.md:32` says is possible but is not the same files. |
| H-02 | **S1** | `docs/tech/proofs/S0-04-runtime-ownership.md:73,94,95,105,106,107`; `docs/tech/proofs/S0-05-content-identity.md:11,51`; `docs/tech/proofs/S0-07-save-owner.md:10,34,72,121`; `docs/tech/proofs/S0-08-save-evidence.md:11,24,38,82,93`; `native/README.md:34`; `docs/tech/sections/HF-03a-module-map.md:111`; `docs/tech/sections/HF-01-production-conventions.md:53,112`; `docs/tech/sections/HF-02-constraints-evidence.md:103` | Tracked proof/section documents state that specific disposable receipts were produced and are retained, but the referenced paths no longer exist. `artifacts/local/tasks/S0-01/`, `S0-04/`, `S0-05/`, `S0-06/`, `S0-07/`, `S0-08/` are **entirely absent**, as are `artifacts/local/tasks/HF-01/check-docs.json`, `artifacts/local/tasks/HF-03a/check_contract.py` and the exact S0-08 run directories. The prose still reads as present-tense evidence. | `grep -rhoE 'artifacts/local/[A-Za-z0-9._/-]+' … \| sort -u` → 130 distinct paths; existence loop → `36 present`, 94 missing; `ls artifacts/local/tasks/` → `AM-FF-001 foundation-01-review HF-01 HF-02 HF-03a HF-04a HF-06a S0-09 S0-10 S0-11 S0-12 S0-13` (no S0-01…S0-08); `ls artifacts/local/proofs/tadr-004/` → `run-20260906T201109Z…`, `run-20260906T203606Z…`, `run-20260906T204536Z…` (the S0-08-cited `run-20260906T190853Z-1788721733739/…3959` are gone) | Add an explicit evidence-status line to each affected section ("local receipts were disposable and are no longer present; the surviving record is X") or repoint to the tracked copies that do exist (`artifacts/prepare-stage-2026-09-06/tasks/S0-01/{ctx7-godot.txt,probe-warning-key.txt}` and `artifacts/foundation-sprint-2026-09/tasks/HF-03a/{attempt-1,coordinator-integrated}/check_contract.py`). | Reversible — prose edit only. No file is restored by this. |
| H-03 | **S2** | `TRACKING.md` (working-tree change, `HF-04a-A1 full foundation attempt` block); `artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` (10 files, 73,618 B) | The uncommitted `TRACKING.md` edit adds the markdown link `original attempt (`artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/handoff.json`)` pointing at a file that is **untracked** (`?? `). `scripts/check-docs.mjs` scans every root-level `*.md` and fails with `missing link target:` when the target is absent, so this passes only because the untracked directory happens to sit on this disk; a clean clone with the line committed gets a broken link and a `check:docs` failure. It also places attempt output inside a retained evidence directory without committing it, contrary to `BACKLOG.md:26`'s rule that receipts the coordinator will cite must be copied into the retained tree. | `git status --porcelain` → ` M TRACKING.md`, `?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/`; `git diff TRACKING.md` → adds the attempt-1 handoff link; `sed -n '73,90p' scripts/check-docs.mjs` → `markdownFiles` includes root `*.md`; `scripts/check-docs.mjs:214` → `missing link target: ` | Commit the 10 attempt-1 files together with the `TRACKING.md` line, or move the link target into a tracked path. Do not commit the link first. | Reversible; nothing is destroyed. The untracked directory is currently the only copy of the HF-04a attempt-1 receipts. |
| H-04 | **S4** | `artifacts/local/sprint-0/final/{scrapkeep.exe,scrapkeep.x86_64}`; `artifacts/local/sprint-0/closed/{scrapkeep.exe,scrapkeep.x86_64}`; `scrapkeep-wt-S0-09-operational/artifacts/local/native-export/{linux,windows}/run-*/` | **1.19 GiB of Godot export binaries in 14 distinct builds**, 95.9% of `artifacts/local/sprint-0/` (95.0% of all `artifacts/local/`) in main and 75.4% of the S0-09 worktree. Only the `closed/` pair is inside the tracked hash chain; the `final/` pair and all ten S0-09 runs are superseded intermediates recorded nowhere tracked, and the 10 S0-09 hashes match neither the pinned pair nor each other. Godot exports here are not reproducible, so each copy is unique bytes. | `find artifacts/local -name '*.exe' -o -name '*.x86_64' \| xargs -r du -cb \| tail -1` → `365,858,848`; per-worktree binary totals → S0-09 `914,647,120`, all others `0`; `sha256sum` over all 14 → 14 distinct digests; `artifacts/local/sprint-0/closed/native-report.json` records `fb26b01d2eb9…`/`012a9b481558…` and `closed/coverage-review.md:27` reconfirms the Linux hash | Keep `closed/` (pinned). Archive-then-delete the `final/` pair only after noting in `TRACKING.md:439` that the files are gone and the hashes survive in `final/native-report.json`; delete S0-09 `native-export/` outright after recording that its ten builds were superseded. | Deleting the `final/` pair and the S0-09 runs is irreversible for those exact bytes, but no tracked document pins them. Deleting `closed/` breaks H-01 and must not happen. |
| H-05 | **S4** | main checkout: `artifacts/local/` 385,170,842; `node_modules/` 84,188,160; `dist/` 23,194,770; `tools/agent-player/**/__pycache__/` 185,463; `artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` 73,618 (untracked, not ignored) | **492,812,963 B (470.0 MiB) that a clean checkout would not contain** — 73.5% of the 670,136,968 B working tree — sits outside version control, of which 367.3 MiB is disposable evidence and 102.6 MiB is regenerable build material (`dist` + `node_modules` + `__pycache__`). `.gitignore` covers all of it correctly; the issue is volume, not rule gaps. The 2.3 MiB by which `artifacts/local` grew during this audit shows the tier grows without any deliberate retention act. | `git ls-files -z --others --ignored --exclude-standard \| du -cb --files0-from=- \| tail -1` → `492,739,345`; `--others --exclude-standard` → `73,618`; `du -sb --exclude=.git .` → `670,136,968`; component table in §1.3 | Adopt a size budget for `artifacts/local/` and prune the export binaries (H-04) and superseded `sprint-0/final/` first. | Fully reversible for `dist/`/`node_modules`/`__pycache__` (rebuildable). Evidence deletion is covered by H-01/H-04. |
| H-06 | **S4** | `/home/andrew/Projects/scrapkeep-wt-*` (9 worktrees) | The nine worktrees consume **2,630,169,960 B (2.45 GiB)**, of which 1,593,332,155 B is nine near-identical tracked checkouts of the same repository and **1,036,831,680 B (988.8 MiB) is generated material**. `S0-09-operational` alone is 1,213,267,742 B and is 85.4% generated. Quantified only; branch/worktree retention is another lane's decision. | `du -sb /home/andrew/Projects/scrapkeep-wt-*` summed → `2,630,169,960`; per-worktree table in §1.9; generated-material sum (`node_modules`+`dist`+`artifacts/local`) → `1,036,831,680` | Strip generated material from `S0-09-operational` (1,036,389,126 B) and the nine small `artifacts/local/` trees (442,554 B) without touching any worktree or branch. | Fully reversible — `node_modules`/`dist` rebuild from the lockfile; the S0-09 `native-export` runs are unique bytes (see H-04). |
| H-07 | **S2** | `artifacts/{ai-first-audit-2026-09-06,foundation-sprint-2026-09,housekeeping-2026-09-05,orchard-first-build,prepare-stage-2026-09-06,publication-2026-09-06,swarm-prep-2026-09-06,visual-iterations,lightning-playtest}/` | 9 of 12 retained evidence directories have no `README.md`; 10 of 12 have no manifest of any kind; 9 have neither. `artifacts/README.md` requires every record to state "source version, test method and limitations" and to be linked from its owning verification document, but **562 tracked files** (`prepare-stage` 393, `foundation-sprint` 93, `lightning-playtest` 19, `ai-first-audit` 16, `publication` 13, `housekeeping` 10, `visual-iterations` 8, `swarm-prep` 8, `orchard-first-build` 2) carry no directory-level orientation. | Per-directory loop testing `[ -f "$d/README.md" ]` and `[ -f "$d/manifest.json" -o -f "$d/implementation-manifest.json" ]` → table in §1.6; file counts from the §1.2 snapshot; `find artifacts -name 'implementation-manifest.json'` → only 4, all nested under `agent-recovery-2026-09-06/` | Add a short `README.md` to each of the 9 (source commit, method, evidence limits, link to the owning doc). Skip `manifest.json` where `implementation-manifest.json` already exists. | Reversible — additive only. |
| H-08 | **S3** | 268 tracked files across `artifacts/**` in 70 sha256 groups | Byte-identical duplication inside retained evidence: 1,417,895 B inside duplicate groups, 877,086 B (0.84 MiB) redundant. Roughly 30 groups are the structural `artifacts/prepare-stage-2026-09-06/receipts/<X>` ↔ `artifacts/prepare-stage-2026-09-06/tasks/<card>/<X>` mirror; the rest are repeated terminal-state JPEG captures across trials (e.g. 4 identical `terminal.jpg`, 3 identical `restarted-paused.jpg`). | Python sha256 over `git ls-files artifacts` → `groups=70 files_in_groups=268 bytes_in_groups=1417895 redundant_bytes=877086`; largest groups listed in §1.6 | Low priority. If pursued, keep the `tasks/<card>/` copy and record the `receipts/` mirror as an index, or accept the duplication as evidence-navigation cost. Do not deduplicate by hardlink — it obscures provenance. | Reversible with caution; deleting the wrong copy of a cited receipt is an evidence loss. Prefer leaving as is. |
| H-09 | **S3** | `public/art/01-yard-concept.png` … `06-orchard-combat-storyboard-v2.png` (8 files, 22,149,367 B); `dist/art/` (identical copy, 22.1 MiB) | 21.1 MiB of tracked PNG sits in the live static-asset directory but has **zero references from live code** (`index.html`, `orchard.html`, `src/`, `server/`, `scripts/`, `tests/`); it is reachable only as documentation images from `docs/*.md`. Vite copies all 8 byte-identically into `dist/art/` on every build, so each build duplicates 21.1 MiB of non-served art. | Per-file basename grep loop → `UNREFERENCED` ×8, `ref(2): public/favicon.svg`; `git grep -n 'public/art'` → hits only in `docs/*.md`; `sha256sum` comparison `public/art/*` vs `dist/art/*` → `IDENTICAL` ×8 | Move the concept art under `docs/` (or `docs/art/`) beside its owning concept studies so Vite stops publishing it, updating the 12 `docs/*.md` links. Duplicate-art analysis is another lane's — this finding is live-asset reachability plus the 22.1 MiB per-build `dist/` copy. | Reversible (path move + link rewrite). `docs/CONCEPT-STUDY-03.md:37` notes the originals are outside the repo, so the in-repo copy must be preserved somewhere. |
| H-10 | **S3** | 27 loose files at the `artifacts/` root, 2,943,529 B | Retained evidence is filed at the top level of `artifacts/` with no directory and inconsistent naming — bare `01-title-screen.png`…`07-mobile-upgrade.png`, `browser-regression.png`, `expedition-menu.png`, `stress-scene*.png`, `hero-preview.png`, `figurine-*.png`, `balance.json`, `balance-log.txt`, `build.txt`, `retention-tests.txt`, `retention-build.txt`, `simulation-tests.txt`, `browser-tests.json`, `lead-browser-tests.json`, `expedition-balance.json`, `performance-stress{,-final}.json`, plus the policy file `artifacts/README.md`. The dated directories use `YYYY-MM-DD`; these files carry no date. | `find artifacts -maxdepth 1 -type f \| wc -l` → `27`; `find artifacts -maxdepth 1 -type f -printf '%s\n' \| awk '{s+=$1} END{print s}'` → `2943529`; `ls -la artifacts/` listing in §1.6 | Group the dated-but-undated loose files into a named record (e.g. `artifacts/browser-first-build/`) with its own README; leave `README.md` in place as the policy file. | Reversible move; the risk is breaking `docs/FIRST-BUILD-VERIFICATION.md` and `docs/LIGHTNING-VERIFICATION.md` links — verify with `npm run check:docs` after the move. |
| H-11 | **S2** | `docs/project/BACKLOG.md:11` (card T01); `docs/project/HOUSEKEEPING.md:22` | Two tracked documents state that no git remote is configured and that nothing has left the machine. Reality: `origin` is configured, `main` tracks `origin/main`, and `main` is **18 commits ahead** of `origin/main` (`f582918`). The stale claim is in the backlog card that is supposed to own publishing, so the board points at work that is partly done and leaves 18 unpushed commits unrecorded. | `git remote -v` → `origin https://github.com/bananahana720/scrapkeep.git`; `git rev-parse --abbrev-ref --symbolic-full-name @{u}` → `origin/main`; `git rev-list --left-right --count origin/main...main` → `0  18`; `git status -sb` → `## main...origin/main [ahead 18]`; `grep -rn "No remote is configured"` → the two doc lines | Correct both documents to state that `origin` exists, that 18 commits are unpushed, and restate T01 as "push the 18 pending commits" rather than "choose a remote". | Reversible — prose edit only. |
| H-12 | **S3** | `.github/workflows/native-smoke.yml` | The repository's only CI is a single `workflow_dispatch`-only workflow that requires `runs-on: [self-hosted, linux, x64, scrapkeep-s0]`, and the one authorized runner was registered for a single job and then removed with zero remaining registrations. It therefore cannot run as-is, and there is consequently no automated gate of any kind. This is the documented, authorized design (not drift), but it means `npm run verify`, `check:docs`, `check:project` and the native proofs run only when a human invokes them. | `find .github -type f` → exactly `./.github/workflows/native-smoke.yml` (3,921 B); `docs/project/sprint-0/README.md:20` → "its runner was removed"; `docs/project/sprint-0/closure.json:64` → "job34060932888 passed and runner removed"; `.agents/.../scrapkeep-verify/SKILL.md:25` → `check:godot` reserved | No change proposed — record it as an accepted gap in `docs/project/AI-WORKFLOW.md` if not already, so a future reader does not assume CI guards `main`. | Not applicable (no change). |
| H-13 | **S3** | `package.json` scripts `start`, `test:balance`; `CONTRIBUTING.md` `check:godot` row; `.env.example` | Dead-weight configuration: `start` duplicates `server` and `test:balance` duplicates `probe:balance` (identical `node tests/balance.mjs`), and neither alias is referenced anywhere outside `package.json`. Documented-but-absent `check:godot` is deliberate and self-describing, so it is not a defect. `.env.example` is fully live — no key lacks a reader. | `for s in <21 scripts>; do grep -rl "npm run $s\b" … \| wc -l; done` → `start 0`, `test:balance 0`, all others 2–24; `grep -n 'check:godot' CONTRIBUTING.md` → reserved-name row; per-key `grep -rn "process\.env\.<KEY>"` → ≥1 reader for all 8 keys | Optional: drop `start` and `test:balance`, or add a `## Aliases` note. Leave `check:godot` alone — its reservation is asserted in four places. | Reversible — but `start`/`test:balance` may be muscle memory; removing them is cosmetic. |
| H-14 | **S3** | `.gitignore` vs `git ls-files` | **Positive result:** the ignore rules are internally consistent — no tracked file sits under a path the current `.gitignore` excludes, so the usual "ignored but still tracked" trap is absent. | `git ls-files -z \| xargs -0 -r git check-ignore --no-index \| wc -l` → `0`; per-pattern counts all `0`; `git ls-files artifacts/local \| wc -l` → `0`; `git ls-files dist \| wc -l` → `0` | No action. Preserve this property; any future "track the report so it survives" change must move the file, not negate the rule. | Not applicable. |
| H-15 | **S3** | `.claude/settings.local.json` | A local settings file is ignored by a **host-global** rule, not the repository's `.gitignore`. On another machine or for another contributor the file is untracked-but-visible and can be committed by accident. | `git check-ignore -v .claude/settings.local.json` → `/home/andrew/.config/git/ignore:1:**/.claude/settings.local.json`; `grep -c 'claude' .gitignore` → no repo rule for it (only `.claude/worktrees/`) | Add `.claude/settings.local.json` to `.gitignore` so the repository owns its own ignore policy. | Reversible — one line. |

## 3. Uncertain / needs owner decision

1. **Are the 12 hash-pinned `artifacts/local/sprint-0/closed/` files meant to survive?** `AGENTS.md:12` and `artifacts/README.md` call `artifacts/local/` disposable, yet `docs/project/sprint-0/closure.json` treats 12 files there as authority-bearing. Only the owner can say whether the tracked receipt is intended to be independently re-verifiable years from now (→ copy into tracked evidence) or whether "replay by regeneration at the pinned source" is the accepted standard (→ no copy needed, but the disposal contract should say so explicitly).
2. **Is `artifacts/local/sprint-0/final/` still needed?** `TRACKING.md:439` calls it "pending receipt … (also retained at git commit caa1a75)" while `docs/project/sprint-0/README.md:32` calls it "the earlier `final/` directory [that] retains the pending closure". The tracked `docs/project/sprint-0/closure.json` equals the `closed/` copy, not the `final/` one, so `final/` looks superseded — but it holds 182.9 MB of unique export binaries and the only copy of `final/closure.json` (`ebbbe60a252a…`). Owner should decide archive vs delete.
3. **Is `artifacts/local/native-smoke/report.json` the canonical native report?** `docs/tech/native-toolchain.md:71` says it is, but it lives in the disposable tree while three older, different, smaller copies are tracked under `artifacts/prepare-stage-2026-09-06/`. The 68,881 B S0-09-worktree report (`da8612d779a0…`) is a fourth variant. Which one is authoritative is not stated.
4. **Does `public/art/` belong in the served asset tree?** It is documentation-only art in the Vite `public/` directory, costing 22.1 MiB tracked and 22.1 MiB per build in `dist/art/`. Another lane owns the duplicate-art question; the move decision is cross-lane.
5. **What is the accepted retention size for `artifacts/` and for worktrees?** No budget appears in `artifacts/README.md`, `CONTRIBUTING.md` or `docs/project/HOUSEKEEPING.md`. Without a stated budget, H-04/H-05/H-06 will regrow: each native export run adds 183 MB.
6. **`tools/agent-player/**/__pycache__/` (185,463 B) — is it meant to be importable tooling?** It is ignored and untracked, which is correct, but its presence means the Python player was executed in place; if a `.gitignore`-adjacent cleanup script ever runs `git clean -xdf`, the player's cached bytecode is harmless to lose. Low stakes, listed for completeness.
7. **`.claude/settings.local.json`'s host-global ignore (H-15)** — should the repository own this rule, given the project explicitly relies on `.claude/skills` symlinks and a shared pstack?

## 4. Recommended atomic task cards

### T5-1 — Copy the sprint-0 closure chain into tracked evidence
- **Files:** create `artifacts/sprint-0-closure-2026-09-06/` containing the 9 distinct files currently pinned by `docs/project/sprint-0/closure.json` (`docs.log`, `project.log`, `integrated-review.md`, `native-report.json`, `visible-receipt.json`, `ci-native-report.json`, `verify.log`, `coverage-review.md`, `runner-cleanup.json`) plus a `README.md`; edit `docs/project/sprint-0/closure.json` only if the owner wants the `path` values repointed, and `artifacts/local/README.md` (new) to name the 12 pin-critical paths.
- **Observable acceptance:** the 9 files exist under a tracked path; re-running the audit's Python hash walk against `docs/project/sprint-0/closure.json` reports `present+match=12` resolving through tracked files; `git ls-files artifacts/sprint-0-closure-2026-09-06 | wc -l` = 10.
- **Verification method:** `npm run check:docs` (documentation-only scope; no build) plus the read-only Python `path`+`sha256` walk from §1.5 re-run by a second agent.
- **Size:** M. **Flag:** this card is the mitigation for H-01. Removing `artifacts/local/sprint-0/closed/` **before** this copy lands destroys the only copy of evidence referenced by a tracked authority record.

### T5-2 — Reconcile dangling `artifacts/local/` references in tracked proof documents
- **Files:** `docs/tech/proofs/S0-04-runtime-ownership.md`, `S0-05-content-identity.md`, `S0-07-save-owner.md`, `S0-08-save-evidence.md`; `docs/tech/sections/HF-01-production-conventions.md`, `HF-02-constraints-evidence.md`, `HF-03a-module-map.md`; `native/README.md`.
- **Observable acceptance:** every `artifacts/local/...` path asserted in the present tense either exists on disk or is annotated as no longer retained; §1.5's existence loop over these files reports zero unannotated misses; repointed paths resolve to the tracked copies at `artifacts/prepare-stage-2026-09-06/tasks/S0-01/` and `artifacts/foundation-sprint-2026-09/tasks/HF-03a/`.
- **Verification method:** `npm run check:docs` (link and anchor validation only, per the script's own scope note: "Structural documentation checks only. No build, runtime, browser or remote check is implied").
- **Size:** M. **Flag:** does not restore anything — it corrects the record. Restoring the S0-01/S0-04/S0-05/S0-07 receipts is not possible; only the tracked duplicates listed above can be repointed to.

### T5-3 — Commit the HF-04a attempt-1 receipts with the TRACKING link
- **Files:** `TRACKING.md` (the 9-line diff); `artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` (10 files, 73,618 B, currently untracked: `contract-report.json`, `check-docs.json`, `check_contract.py`, `handoff.json`, `run_checks.py`, `docs.log`, `scope.log`, `project.log`, `contract.log`, plus an empty `whitespace.log`).
- **Observable acceptance:** `git status --porcelain` shows no `??` entry for `attempt-1/`; the link `original attempt (`artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/handoff.json`)` resolves from a clean checkout; `npm run check:docs` exit 0.
- **Verification method:** `git ls-files artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` returns 10 paths; `npm run check:docs`.
- **Size:** S. **Flag:** the untracked directory is currently the only copy of the HF-04a attempt-1 receipts — do not `git clean` it.

### T5-4 — Correct the stale remote claims in BACKLOG T01 and HOUSEKEEPING
- **Files:** `docs/project/BACKLOG.md:11` (card T01 row), `docs/project/HOUSEKEEPING.md:22`.
- **Observable acceptance:** neither file contains "No remote is configured yet"; both state that `origin` is `github.com/bananahana720/scrapkeep.git` and that `main` is 18 commits ahead of `origin/main`; T01's completion criterion becomes "push the pending commits", not "choose a remote".
- **Verification method:** `grep -rn "No remote is configured" docs/` → no matches; `git rev-list --left-right --count origin/main...main` → `0 18` unchanged.
- **Size:** S.

### T5-5 — Add directory READMEs to the nine retained evidence directories that lack one
- **Files:** `artifacts/ai-first-audit-2026-09-06/README.md`, `artifacts/foundation-sprint-2026-09/README.md`, `artifacts/housekeeping-2026-09-05/README.md`, `artifacts/lightning-playtest/README.md`, `artifacts/orchard-first-build/README.md`, `artifacts/prepare-stage-2026-09-06/README.md`, `artifacts/publication-2026-09-06/README.md`, `artifacts/swarm-prep-2026-09-06/README.md`, `artifacts/visual-iterations/README.md`.
- **Observable acceptance:** each new README names the source commit or hash set, the method actually performed, the evidence limits, and the owning verification document, per `artifacts/README.md`'s own retention rule; 12 of 12 retained evidence directories have a `README.md`.
- **Verification method:** `for d in artifacts/*/; do [ "$d" = "artifacts/local/" ] || [ -f "$d/README.md" ]; done` returns true for all; `npm run check:docs` exit 0 (the scanner walks `artifacts/**/README.md`).
- **Size:** M.

### T5-6 — Add `artifacts/local/README.md` stating the disposal contract and pin-critical paths
- **Files:** create `artifacts/local/README.md`; note `artifacts/README.md` already describes the directory (1,616 B).
- **Observable acceptance:** the file states that the directory is disposable, lists the 12 paths currently pinned by `docs/project/sprint-0/closure.json` by name, states that `artifacts/local/native-smoke/report.json` is cited as canonical by `docs/tech/native-toolchain.md:71`, and instructs a cleaner to run the read-only pin check before deleting anything.
- **Verification method:** the pin check itself — a Python walk of every tracked `*.json` for `path`+`sha256` pairs under `artifacts/local/` returns 12 matches in `docs/project/sprint-0/closure.json` and 0 elsewhere (the `artifacts/agent-player-2026-09-06/**/report.json` hits are self-referential path strings, not `artifacts/local` pins — verify by filtering).
- **Size:** S. **Flag:** this card writes inside the disposable tree by design; it is the one file that must survive a prune.

### T5-7 — Reduce export-binary retention
- **Files:** `artifacts/local/sprint-0/final/scrapkeep.exe`, `artifacts/local/sprint-0/final/scrapkeep.x86_64` (182,929,424 B); `scrapkeep-wt-S0-09-operational/artifacts/local/native-export/**` (914,647,120 B); a note added to `TRACKING.md:439`.
- **Observable acceptance:** the `closed/` pair and all 12 hash-pinned `closed/` files remain byte-identical (`closed/native-report.json` still `9360ba38365d…`, `closed/coverage-review.md` still `d7e062ea253b…`); reclaimed bytes measured by `du -sb` before/after = 1,097,576,544 B; `docs/project/sprint-0/closure.json`'s pin check still reports `present+match=12`.
- **Verification method:** re-run the §1.5 Python pin walk and `sha256sum artifacts/local/sprint-0/closed/*` before and after; `git status --porcelain` unchanged (nothing tracked is touched).
- **Size:** M. **Flag:** destroys the only copy of `final/`'s two exports and of S0-09's ten export builds. Nothing tracked pins them, but the owner should confirm before deletion, because the hashes in `final/native-report.json` survive only in the same disposable tree.

### T5-8 — Strip generated material from the worktrees (no branch or worktree removal)
- **Files:** `scrapkeep-wt-S0-09-operational/{node_modules,dist,artifacts/local/native-export,artifacts/local/native-smoke}` (1,036,389,126 B); the eight other worktrees' `artifacts/local/` (442,554 B).
- **Observable acceptance:** `du -sb` total across `/home/andrew/Projects/scrapkeep-wt-*` drops from 2,630,169,960 B to 1,593,338,280 B (arithmetic: 2,630,169,960 − 1,036,831,680); `git worktree list` still shows 10 entries; `git -C <wt> status --porcelain` shows no tracked modification in any worktree.
- **Verification method:** `du -sb /home/andrew/Projects/scrapkeep-wt-*` before/after; `git worktree list` unchanged; `git -C <wt> ls-files | wc -l` unchanged per worktree.
- **Size:** M. **Flag:** branch and worktree retention is explicitly another lane's call — this card removes only generated material and touches no ref. It destroys the S0-09 `native-export` runs, which duplicates T5-7's flag.

### T5-9 — Move documentation-only concept art out of the served asset tree
- **Files:** `public/art/*.png` (8 files, 22,149,367 B) → a `docs/`-side location; the 12 `docs/*.md` links that reference them (`ART-DIRECTION.md`, `BASELINE-GUIDE.md:70`, `COMBAT-DESIGN-SWARM.md:29`, `CONCEPT-STUDY-01.md:3,7`, `CONCEPT-STUDY-02.md:9`, `CONCEPT-STUDY-03.md:9,11,23,25,37`, `CONFLICT-AND-COMBAT.md:20`, `DISCOVERY.md:215`).
- **Observable acceptance:** `grep -rl "public/art" docs/ src/ *.html` returns nothing; all 8 files exist under the new path with unchanged sha256; a rebuild (owner-run, out of this lane's scope) produces a `dist/` with no `art/` directory, cutting 22.1 MiB per build.
- **Verification method:** `npm run check:docs` for link/anchor integrity; `sha256sum` comparison before/after; owner-run `npm run build` then `du -sb dist/art` → absent.
- **Size:** M. **Flag:** coordinate with the lane that owns duplicate docs art, and preserve the in-repo copies — `docs/CONCEPT-STUDY-03.md:37` says the generation originals live outside the repository.

## 5. Method and limits

**Method.** Every number in this report comes from a command run in this session against `/home/andrew/Projects/scrapkeep` or a read-only read of a file in it. Sizes are reported two ways where they differ: `du -sh` (disk usage, block-rounded, matching intuition about "how much space is taken") and `du -sb` (apparent byte sum, using `du`'s inode dedup so npm hardlinks are counted once). The authoritative byte totals in §1.10 use `du -sb`. Tracked/untracked/ignored splits use `git ls-files` piped into a **single** `du -cb --files0-from=-` invocation — an earlier attempt with `xargs` split the list across multiple `du` processes and the `tail -1` under-reported the ignored total as 65 MB; that error was caught and corrected to 490,470,379 B (first measurement) and 492,739,345 B (final snapshot). Git object weight is reported as `git count-objects -vH` (`size-pack 131.23 MiB`) and independently as `git cat-file --batch-all-objects --batch-check` (`blob 1894 / 185,949,112 B`), which differ because the pack is delta-compressed while the second is the logical object size.

Duplication used sha256 over file contents: for tracked `artifacts/**` via `git ls-files -z artifacts | xargs -0 sha256sum` grouped in Python; for the 14 export binaries and the `public/art` ↔ `dist/art` comparison via direct `sha256sum`. Evidence-pin verification used a recursive Python walk of `docs/project/sprint-0/closure.json` collecting every `{path, sha256}` pair and re-hashing each target.

**Limits.**
- Read-only throughout. No `git add`, `commit`, `push`, `checkout`, `restore`, `clean`, `gc`, `prune` or `worktree` mutation; no `npm install`, `npm run build`, `npm run verify`, `npm run check:*`, no browser, no Godot, no network. **`npm run check:docs` was not executed**, so every claim about what it would report is derived from reading `scripts/check-docs.mjs` (scan scope at lines 73–90; failure text at line 214) rather than from its observed output.
- The audit's own write is confined to `artifacts/local/audit-2026-09-10/lane-5-hygiene.md`. A sibling file `artifacts/local/audit-2026-09-10/PLAN.md` (4,075 B, 2026-09-10 09:34) existed before this run and belongs to another lane; it is counted in §1.5's `artifacts/local/` inventory but was not read or modified.
- `git status --porcelain` was taken at HEAD `b61feb1` with `TRACKING.md` modified and one untracked directory. This is a mid-flight working tree: H-03 is about an uncommitted change and would be resolved by committing or reverting, so it does not describe committed state.
- The missing-reference counts in §1.5 include forward-looking paths from `BACKLOG.md` card definitions and literal schema placeholders. Only the class identified as asserted-and-missing in H-02 is a defect; the raw counts (130 referenced, 36 present, 94 missing) must not be quoted as 94 defects.
- Sizes are a single-host snapshot: the S0-09 worktree's 1.2 GB, the 14 export binaries and the 2.63 GB worktree total are point-in-time and will change as soon as any export or `npm ci` runs. `node_modules` byte counts differ between `du -sb` (84,188,160) and a raw file-size sum (107,133,881) because npm hardlinks the same content into multiple package directories; `du` reports the true occupancy.
- **Concurrent writes.** `artifacts/local/audit-2026-09-10/` was written by sibling audit lanes throughout this run (1 file / 4,075 B at the start; 969 files / 2,092,524 B at `2026-09-10T16:37:01Z`). Every `artifacts/local/` and ignored-material figure here is that snapshot; the same commands at a different moment return different numbers, so a reader re-running them should expect drift of a few MiB, all inside `artifacts/local/audit-2026-09-10/`. Tracked figures, the export-binary inventory and the worktree table are unaffected.
- Human game feel, physical hardware support, Windows execution and gameplay qualification are outside this lane and were not assessed. No claim is made about the correctness of any evidence's content — only about its presence, size, duplication and reachability.
- Branch safety, worktree retention decisions, `COHESION_REPORT.md`, and duplicate documentation art are other lanes' scope. Worktree disk is quantified here (H-06) with no recommendation to delete a branch or worktree.
