# Lane 4 — docs and assets

Read-only audit. Repo root `/home/andrew/Projects/scrapkeep`, base commit `b61feb187cfdcad71700c629e315a77de4e0f975` (`git rev-parse HEAD`). Working tree had ` M TRACKING.md` and `?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` present before I started; I made no change to either. No file was written except this report.

Lane scope audited: `docs/**` minus the canonical `docs/project/**`, `docs/adr/**`, `docs/DISCOVERY.md`, plus `public/**`, `COHESION_REPORT.md`. `adr/**` (repo root) treated as canonical and read-only. Lane inventory = **199 files**.

---

## 1. Verified state — facts, each with the exact command run and its observed result

### 1.1 Inventory and weight

**F1.** `git ls-files | wc -l` → **1760** tracked entries; 1757 are regular files (3 are `.claude/skills/*` directory gitlinks, which `sha256sum` reported as `Is a directory`).

**F2.** `git ls-files -z | xargs -0 du -bc | tail -1` → **177,361,954 B** tracked total.

**F3.** Per-directory tracked bytes —
`for d in adr artifacts docs native public scripts server src tests tools …; do git ls-files -z -- "$d" | xargs -0 du -bc | tail -1; done`

| bytes | files | path |
| --- | --- | --- |
| 89,878,927 | 216 | `docs` |
| 88,183,877 | 131 | `docs/bible` |
| 87,463,831 | 30 | `docs/bible/images` |
| 363,489 | 70 | `docs/bible/production` |
| 347,297 | 30 | `docs/bible/prompts` |
| 21,020 | 30 | `docs/bible/production/generation-results` |
| 154,364 | 10 | `docs/tech` |
| 104,328 | 4 | `docs/audit-2026-09-05` |
| 99,146 | 1 | `docs/research-2026-09-05` |
| 11,964 | 4 | `docs/art-prompts` |
| 433,035 | 4 | `docs/discovery/source-notes-2026-08-21` |
| 22,149,658 | 9 | `public` |
| 22,149,367 | 8 | `public/art` |
| 63,197,644 | 1369 | `artifacts` (not my lane) |
| 355,420 | 16 | `src` |
| 195,291 | 40 | `tests` |
| 91,153 | 32 | `native` |

**F4.** Top tracked file by size: `docs/bible/images/M02-v1.png` = 3,546,764 B (`git ls-files -z | xargs -0 du -b | sort -rn | head -40`). Top 20 are all `docs/bible/images/*.png` (16 entries) and `public/art/*.png` (4 entries); the first non-image is `artifacts/agent-recovery-2026-09-06/synthesis-live/trial-002/events.ndjson` at 1,754,884 B.

**F5.** PNG dimensions (`python3` + `struct` on the IHDR chunk): the 30 bible images span 1536×1024, 1592×988, 1619×971, 1628×966, 1672×941, 1692/1693×929, 1717×916 and 1774×887; the 8 `public/art` images are 1536×1024 or 1672×941.

### 1.2 Byte-identical duplicates

**F6.** Method: `python3` → `git ls-files -z`, filter `os.path.isfile`, `sha256sum -- <files>`, group by digest.
Observed: **1757 files hashed, 1548 unique digests, 73 duplicate groups, 282 files in duplicate groups, 1,206,225 B reclaimable** if one copy of each group is kept.

**F7.** Same run, split by location:
- groups **entirely inside `artifacts/`**: **63 groups / 855,363 B**
- groups **touching my lane (`docs/` non-canonical, `public/`, `COHESION_REPORT.md`)**: **0 groups / 0 B**
- remaining 10 groups span `artifacts/` with `tools/` or `native/`; the two biggest are `tools/agent-player/tests/fixtures/boundary-stall.jpg` ≡ `artifacts/agent-recovery-2026-09-06/candidate-b/trial-001/timeout.jpg` (174,855 B) and `tools/agent-player/tests/fixtures/ground-stall.jpg` ≡ `artifacts/agent-player-2026-09-06/default-visual/trial-001/timeout.jpg` (151,352 B).
- largest artifact-only group: `artifacts/agent-player-2026-09-06/defeat-cycles/trial-00{1,2,3}/terminal.jpg` + `passive-restart/trial-001/terminal.jpg` — 4 × 87,259 B = 261,777 B.

**F8. The versioned art pairs are NOT byte-identical.** `sha256sum public/art/05-pruner-family-study.png public/art/05-pruner-family-study-v2.png public/art/06-orchard-combat-storyboard.png public/art/06-orchard-combat-storyboard-v2.png docs/bible/images/U01-v{1,2}.png docs/bible/images/U02-v{1,2,3}.png docs/bible/images/C03-v{1,2}.png docs/bible/images/M04-v{1,2}.png` → **12 distinct digests**, e.g.
`05-pruner-family-study.png c675131e…`, `…-v2.png 19894eee…`; `06-…storyboard.png e3bdbbc3…`, `…-v2.png 2d201ef7…`; `U01-v1 009487df…`, `U01-v2 a1367ace…`.

**F9. They are also visually different, not re-encodes.** `python3` + PIL: 32×32 greyscale mean-absolute-difference.
`05 v1↔v2 = 6.20`, `06 v1↔v2 = 11.91`, `U01 v1↔v2 = 11.22`, `C03 v1↔v2 = 16.22`, `M04 v1↔v2 = 3.00`, `U02 v1↔v2 = 2.70`, `U02 v2↔v3 = 4.11` (0 = identical, 255 = maximally different). All pairs are genuinely different renderings; U02 v1/v2/v3 and M04 v1/v2 are near-identical *compositions* but not the same file.

**F10. There is no duplicated art between `docs/bible/images` and `public/art`.** Same PIL run over all 30 × 8 = 240 cross-tree pairs: **closest pair is d = 35.86** (`C03-v1.png` ↔ `03-industrial-dungeon-study.png`), far above any duplicate threshold. **Overlap = 0 files, 0 bytes.** Hashes agree (`sha256sum` grouping produced no cross-tree group).

### 1.3 Superseded art and what is still referenced

**F11.** `grep -oE "docs/bible/images/[A-Za-z0-9-]+\.png" BIBLE.md | sort | uniq -c` → every current image is referenced **twice** (body + Appendix A); the five superseded attempts are referenced **once**: `U01-v1` (1), `U02-v1` (1), `U02-v2` (1), `C03-v1` (1), `M04-v1` (1). So the old versions are **not orphans** — the canonical `BIBLE.md` keeps them as revision history.

**F12.** Bytes:
- `docs/bible/images` superseded attempts (U01-v1, U02-v1, U02-v2, C03-v1, M04-v1) = **14,248,227 B / 5 files**
- `public/art` superseded v1 pair (`05-pruner-family-study.png`, `06-orchard-combat-storyboard.png`) = **6,415,875 B / 2 files**
- **historical superseded art total = 20,664,102 B / 7 files**

**F13.** `docs/CONCEPT-STUDY-03.md:41-44` labels both `public/art` v2 files **“selected”** and the v1 files as the edit target/reference — i.e. the v1 pair is documented, in prose, as the rejected attempt.

**F14.** `grep -ohE "docs/bible/images/[A-Za-z0-9-]+\.png" docs/bible/production/section-*.md | sort | uniq -c` → the nine staging manuscripts reference only the **current** variants (`C03-v2`, `M04-v2`, `U01-v2`, `U02-v3`).

### 1.4 Live vs documentation-only assets

**F15.** `grep -rn --include=*.js --include=*.html --include=*.mjs --include=*.json --include=*.css -E "\.png|/art/|public/art" src/ tests/ server/ scripts/ vite.config.js index.html orchard.html` → **no reference to `public/art/**` or `docs/bible/images/**`.** The only `.png` hits are output paths the browser tests *write* (`tests/browser.mjs:39`, `tests/lead-browser.mjs:101,168,195,207`) and MIME tables (`server/index.js:19`, `scripts/check-build.mjs:14`).
`index.html` references only `/favicon.svg`; `orchard.html` references only `/favicon.svg`.

**F16.** Therefore **109,613,198 B / 38 PNG files** (`public/art` 22,149,367 + `docs/bible/images` 87,463,831) are referenced **only by Markdown prose** (`BIBLE.md`, `COHESION_REPORT.md`, `docs/CONCEPT-STUDY-0*`, `docs/ART-DIRECTION.md`, `docs/audit-2026-09-05/worker-4-universe.md`) and by machine manifests under `artifacts/`. They are **documentation/design assets, not live game assets.** They are not orphans: `docs/project/ASSETS.md:9` explicitly admits “Eight concept images in public/art … retain original names”.

### 1.5 Orphans

**F17.** Strict orphan computation (basename **or** full path, corpus = every tracked UTF-8 file ≤ 3 MB excluding `node_modules/`, `dist/`, `.git/`, `artifacts/local/`; 1526 corpus files; self-matches excluded): **0 lane files have zero inbound references.** Both index-like files have inbound references: `docs/DESIGN-INDEX.md` (22 referencing files), `docs/tech/sections/README.md` (125 — inflated by loose `README.md` basename matching, see §5).

**F18.** Weaker class — lane files whose **only** inbound references are machine-generated manifests under `artifacts/` (no live code, no canonical doc, no other lane doc): **21 files / 124,507 B**:
`docs/bible/production/assets-in-progress.json`, `style-lock.json`, `section-01..09-assets.json` (9), `section-01..09-decisions.md` (9), `BIBLE-approved-step0.md.txt`.

### 1.6 Links and anchors

**F19.** `python3` link/anchor checker over the **74 lane Markdown files**: **568 local links scanned → 0 dead targets, 0 unresolvable anchors.** Relative, root-absolute (`/…`), angle-bracket (`x (`<path>`)`) and fragment-only forms were all resolved against `git ls-files` content plus on-disk existence; GitHub's slug algorithm was used (spaces → one hyphen each, punctuation stripped, case folded).

**F20.** Two earlier versions of my own checker produced **false positives** which I then eliminated: 74 “dead links” were angle-bracket syntax `label (`<../../../COHESION_REPORT.md>`)` mis-parsed as a literal `<…>` path; 10 “bad anchors” were caused by collapsing double spaces to a single hyphen (`#1-pillars--fantasy` vs my `#1-pillars-fantasy`). Corrected run: clean. **No dead links or bad anchors exist in lane.**

### 1.7 Documentation duplication (content, not bytes)

**F21.** Method: set of stripped lines > 40 chars from `BIBLE.md` (490 such lines) vs the same for each candidate file; **control set of 18 unrelated lane docs scored 0/… = 0 %.**

| file | long lines | present verbatim in `BIBLE.md` | bytes |
| --- | --- | --- | --- |
| `docs/bible/production/section-01.md` | 19 | 17 (89 %) | 6,948 |
| `section-02.md` | 31 | 26 (84 %) | 10,165 |
| `section-03.md` | 45 | 38 (84 %) | 15,384 |
| `section-04.md` | 62 | 56 (90 %) | 15,711 |
| `section-05.md` | 39 | 36 (92 %) | 12,061 |
| `section-06.md` | 65 | 61 (94 %) | 21,038 |
| `section-07.md` | 56 | 53 (95 %) | 14,909 |
| `section-08.md` | 36 | 34 (94 %) | 8,707 |
| `section-09.md` | 67 | 65 (97 %) | 11,044 |
| **total** | **420** | **386 (92 %)** | **115,967** |
| `FRONT-MATTER.md` | 21 | 9 (43 %) | 3,171 |
| `SOURCES.md` | 23 | 9 (39 %) | — |
| 15 control docs (CONCEPT-STUDY-01/03, ENEMY-ROSTER, DESIGN-AUDIT, worker-2-combat, LIGHTNING-PLAYGUIDE, MARKET-RESEARCH, RUNTIME-BLUEPRINT, WORLD-ENVIRONMENTS, LEVEL-DESIGN, CHARACTER-BIBLE, ORCHARD-ENCOUNTER-STUDY, independent-review, REVIEW-BRIEF, section-01-decisions, SECTION-BRIEF, HF-01) | 1,105 | **0 (0 %)** | — |

**F22.** `FRONT-MATTER.md` vs the first 34 lines of `BIBLE.md`: char-level `difflib` similarity **0.935**; both open with “SCRAPKEEP: Art & Game Bible / **Approved product reference · 6 September 2026**”.

**F23.** The frozen Art Direction block exists **three times, byte-identically**: `docs/bible/ART-DIRECTION-LOCK.md` (whole file), `docs/bible/production/section-07.md:1-78`, and `BIBLE.md:614-691`. `python3` extraction + `sha256sum` → all three **9,260 B, sha256 `0f694b904454716669d844e833973852c51a6ec48c719918797b06a7841322c7`**, which is exactly the digest quoted in `docs/bible/production/SOURCES.md:7`. This duplication is **deliberate and documented** (“preserved byte for byte”, “the lock file is the generation copy; Section 7 remains the reader's reference”). Redundant copies = 2 × 9,260 = **18,520 B**.

**F24.** `COHESION_REPORT.md` (13,812 B) vs `docs/bible/production/independent-review.md` (14,485 B): `difflib.SequenceMatcher(...).ratio()` = **0.012** — these are **not** duplicates. (An earlier `quick_ratio()` reading of 0.941 was an upper bound and would have been a false finding.)

### 1.8 Structural hygiene

**F25.** Empty tracked files repo-wide: `git ls-files -z | xargs -0 -I{} sh -c 'test ! -s "{}" && echo "{}"'` → **exactly one**: `artifacts/foundation-sprint-2026-09/tasks/HF-03a/attempt-1/whitespace.log` (0 B), outside my lane.

**F26.** Scratch/droppings in lane: `git ls-files -- docs public COHESION_REPORT.md | grep -iE "\.(log|tmp|bak|swp|orig|rej|pyc)$|~$|DS_Store"` → **no matches**. `git status --porcelain --ignored -- docs public COHESION_REPORT.md` → **no matches**. No near-empty stubs: no lane file is ≤ 120 B (`du -b` filter).

**F27.** README/index presence: only `docs/tech/sections/README.md` exists. **No** README in `docs/`, `docs/bible/`, `docs/bible/images/`, `docs/bible/production/`, `docs/bible/prompts/`, `docs/audit-2026-09-05/`, `docs/research-2026-09-05/`, `docs/art-prompts/`, `docs/tech/`, `docs/tech/proofs/`, `docs/discovery/`, `public/`, `public/art/`.

**F28.** Prompt↔image↔result mapping. `docs/bible/`: images 30, prompts 30, generation-results 30, **perfect 1:1 in all four directions** (no missing/extra). `public/art`: **8 images, 4 prompt files**; prompts exist for 05/06 only, and the file names differ from the outputs: prompts `06-orchard-storyboard-v{1,2}.txt` vs images `06-orchard-combat-storyboard{,-v2}.png`.

**F29.** Naming families inside `docs/bible/`: uppercase-ID (`ART-DIRECTION-LOCK.md`, `images/A01-v1.png`, `prompts/A01-v1.txt`, `production/generation-results/A01-v1.json`) vs lowercase-kebab (`production/section-01.md`, `style-lock.json`). `docs/art-prompts/` uses lowercase numeric-prefix names (`05-pruner-family-v1.txt`) — a third convention for the same concept-art provenance. Also `docs/bible/production/BIBLE-approved-step0.md.txt` carries a **double extension**.

**F30.** Versioned-file conventions: art uses `-vN` suffixes everywhere (`05-…-v2`, `U02-v3`); the snapshot pair instead uses a `-final` suffix — `docs/bible/production/source-snapshot.json` and `source-snapshot-final.json`, **both 1,078 B, 11 keys each**, differing in **5** of them (`python3` JSON compare): `docs/DISCOVERY.md`, `docs/RUNTIME-BLUEPRINT.md`, `docs/project/REQUIREMENTS.md`, `docs/project/DECISION-REGISTER.md`, `docs/project/README.md`. Neither name carries a date or revision number.

**F31.** `docs/decisions.tsv` (`stat -c%s` → **26,048 B**, `wc -l` → **69 lines**) is the only `.tsv` beside the **35** `docs/*.md` files, and is cited as authoritative by `adr/README.md:37` (“the existing decision trail”) while `docs/project/DECISION-REGISTER.md` supersedes its role for current rulings. Not an orphan; a competing-authority smell.

### 1.9 Superseded-but-unbannered documents

**F32.** Banner scan `head -12 "$f" | grep -qiE "historical|supersed|frozen|preserved|no longer|earlier|older record"` over every lane Markdown file → 34 files carry an explicit historical/frozen banner (e.g. `docs/BUILD.md:3`, `docs/VERIFICATION.md:3`, `docs/RETENTION-BUILD.md:3`, `docs/RETENTION-VERIFICATION.md:3`, `docs/FIRST-BUILD-PLAYGUIDE.md:3`, `docs/LEAD-CAPTURE.md:3`, `docs/ART-DIRECTION.md:3`, `docs/FIRST-BUILD-CONTRACT.md:3`). The candidates below carry **no** banner.

**F33.** `docs/audit-2026-09-05/worker-1-architecture.md:3` states “Repo root: `/home/andrew/Projects/test-game-2`” and justifies not running git (“`git status`/`git log` fail … No further git commands were attempted”), while this repo has a working `.git` with 123 commits at `/home/andrew/Projects/scrapkeep`. `worker-3-meta.md` repeats the old root. Yet `docs/RUNTIME-BLUEPRINT.md:5` says “The older architecture audit and meta-system paper remain historical research”, `docs/DESIGN-INDEX.md:34` labels `DESIGN-AUDIT.md` “Historical audit; mass-first sequence and old run structure superseded”, and `docs/project/SOURCE-DISPOSITIONS.md` (canonical) row P09 relies on `docs/audit-2026-09-05/worker-2-combat.md` as the sole retention of the Sluiceback experiment. The four audit files themselves say only “Session-scoped audit”.

**F34.** Present-tense claims already falsified:
- `docs/ORCHARD-VISUAL-SWARM.md:3` — “Publisher discovery continues; **no session goal or gameplay implementation is set**.” The lightning increment is implemented (`docs/project/INCREMENT-01-lightning-playtest.md`, `docs/LIGHTNING-PLAYGUIDE.md`, `docs/LIGHTNING-VERIFICATION.md`).
- `docs/ORCHARD-ENCOUNTER-STUDY.md:3` — “This is a paper specification **for later prototyping**.” `docs/DESIGN-INDEX.md:20` already labels it “Historical paper sequence and pose brief”.
- `docs/DESIGN-AUDIT.md:3` — “Everything below labeled proposal is design work **awaiting Andrew's judgment**. Nothing here changes committed scope”, with no note that its mass-first sequence and fixed campaign order were superseded (`docs/DESIGN-INDEX.md:29,34`; `docs/project/SOURCE-DISPOSITIONS.md` D01/D06).
- `docs/CHARACTER-BIBLE.md:3` — “This document is **the production-guiding character reference**”, while `BIBLE.md:390` calls it “the **earlier** character reference” and `BIBLE.md` §4/§9 own character + glossary direction.

**F35.** Stale absolute paths. `grep -rn -o "test-game-2" docs/ | wc -l` → **363 occurrences across 17 lane files**, including **156 in `docs/bible/production/assets.json`**. Parsing that file: **100 `*_path` fields, all 100 absolute, all 100 pointing into `/home/andrew/Projects/test-game-2`**; **0 dangling** (all exist) and **100/100 byte-identical** to the in-repo copies. `<repo>/docs/bible/prompts/M04-v2.txt`, `docs/bible/production/independent-review.md` and `docs/research-2026-09-05/REVIEW-NOTES.md` also embed the old root.

### 1.10 The stale sibling checkout (outside the repo)

**F36.** `ls -ld /home/andrew/Projects/test-game-2` → a **real directory**, not a symlink. `du -sb` → **1,877,208,953 B (1.8 GB)**. `git -C … rev-parse HEAD` → `c5e61d3144282a0f1f638586c0361e02deff0018` (29 commits) vs this repo's 123 commits. `git -C … remote -v` → same origin `https://github.com/bananahana720/scrapkeep.git`. `git cat-file -t c5e61d3…` **in this repo → `commit`**, so its committed history is already present here.
Breakdown: `artifacts` 1,506,706,428 B — of which **`artifacts/local` = 1,443,928,778 B, git-ignored by the shared `.gitignore`**; `.git` 144,059,908; `docs` 89,483,978; `node_modules` 89,174,170; `dist` 23,194,770; `public` 22,149,658. `git status --porcelain` reports **exactly one** unique item: `?? .codex/config.toml`.

### 1.11 Art trees do not overlap and are not duplicated

**F37.** `du`/hash/PIL results combined: `docs/bible/images` (30 files, 87,463,831 B) ∩ `public/art` (8 files, 22,149,367 B) = **∅**. Same image shipped in both trees: **none, 0 bytes**. The `docs/bible/prompts` ↔ `docs/bible/images` ↔ `generation-results` triples are 1:1 by ID; `public/art` is an independent, older, eight-file concept set.

### 1.12 Repository-native checks available (not run)

**F38.** `scripts/check-docs.mjs` exists and its header states it validates “link targets … for existence and anchors”, runnable as `npm run check:docs`; `package.json` also defines `check:project`, `check:scope`, `check:build`. I did **not** run any of them: `check-docs.mjs` unconditionally `mkdir`s and `writeFile`s a report path, which would exceed my single-file write allowance. `npm run verify` and `npm run build` were out of scope by instruction.

---

## 2. Findings

Severity: **S1** authority/trust, **S2** maintenance hazard, **S3** cosmetic, **S4** disk weight. Reversibility assumes git history is retained and the file is committed.

| ID | Sev | Paths | What is wrong | Evidence (command → observed) | Proposed disposition | Reversibility |
| --- | --- | --- | --- | --- | --- | --- |
| L4-01 | S1 | `docs/bible/production/FRONT-MATTER.md`, `section-01.md` … `section-09.md` | Nine section manuscripts + a front matter present themselves as the approved Bible (“**Approved product reference · 6 September 2026**”; “Andrew approved this Art & Game Bible as the source of truth”) with **no staging banner and no statement that `BIBLE.md` is the reader's copy**. `FRONT-MATTER.md` carries an 11-row contents table that links *into* `BIBLE.md` sections (`grep -c BIBLE.md` → 11) but never says this file is staging; the nine `section-0N.md` link `BIBLE.md` **zero** times. | F21 (92 % of 420 long lines already verbatim in `BIBLE.md`; 15-doc control = 0 %), F22 (0.935 similarity to `BIBLE.md` head), `grep -c BIBLE.md docs/bible/production/section-0*.md` → 0 for all nine `section-0N.md` (only `section-02/04/09.md` mention the string, via other docs) | Add a one-line staging banner naming `BIBLE.md` as the reader's reference; keep bytes (production provenance) | Reversible (text edit) |
| L4-02 | S1 | `docs/audit-2026-09-05/worker-1..4-*.md` | No historical banner; `worker-1:3` and `worker-3` assert the repo root is `/home/andrew/Projects/test-game-2` and that git is unusable — both false for this checkout. Canonical records already treat them as historical. | F33; `grep -rn test-game-2 docs/audit-2026-09-05/` → worker-1 ×2, worker-3 ×1 | Add banner + corrected root note; keep | Reversible |
| L4-03 | S1 | `docs/DESIGN-AUDIT.md` | Unbannered; its mass-first sequence and fixed campaign order are superseded, but the file still reads as live (“awaiting Andrew's judgment”). | F34 bullet 3; `DESIGN-INDEX.md:29,34`; `SOURCE-DISPOSITIONS.md` D01/D06 | Add superseded banner naming `docs/project/DECISION-REGISTER.md` + `BIBLE.md` | Reversible |
| L4-04 | S1 | `docs/ORCHARD-VISUAL-SWARM.md`, `docs/ORCHARD-ENCOUNTER-STUDY.md` | Present-tense claims now false: “no session goal or gameplay implementation is set”, “paper specification for later prototyping”. | F34 bullets 1–2; `sed -n 1,7p` of each; `DESIGN-INDEX.md:20` | Add historical banner naming `docs/project/INCREMENT-01-lightning-playtest.md` / `docs/LIGHTNING-PLAYGUIDE.md` | Reversible |
| L4-05 | S1 | `docs/CHARACTER-BIBLE.md` | Self-describes as “**the** production-guiding character reference” while `BIBLE.md:390` calls it “the earlier character reference” and `BIBLE.md` §4/§9 own character and glossary direction. Two documents claim character authority. | F34 bullet 4; `grep -n "earlier character reference" BIBLE.md` → line 390 | Reword line 3 to “earlier character desk; BIBLE.md §4/§9 own current direction” | Reversible |
| L4-06 | S2 | `docs/bible/production/assets.json` (+ `assets-in-progress.json`, `section-0N-assets.json`, `section-0N-decisions.md`) | 363 stale absolute paths to a **1.8 GB out-of-repo sibling clone** instead of repo-relative paths. Provenance inventory resolves today but silently breaks the moment `test-game-2` is removed or diverges; an agent may edit the wrong tree. | F35 (100/100 absolute, 0 dangling, 100/100 byte-identical), F36 | Convert to repo-relative paths, or add an explicit “paths refer to the archived clone at commit c5e61d3” note. **Owner decision.** | Reversible (text edit); the archived clone it points at is not |
| L4-07 | S2 | `docs/DESIGN-INDEX.md` | Root design index dated 5 Sep; it points to `BIBLE.md` but indexes **none** of `docs/bible/**`, `docs/tech/**`, `COHESION_REPORT.md`, `BIBLE_DECISIONS.md`, or `docs/audit-2026-09-05/**` directly. A reader following the index cannot reach the newest records. | `read docs/DESIGN-INDEX.md` (67 lines, tables at 15–25 and 31–40, “Team records” at 61); lane files referenced by it: 22 | Add a “Newest records” block (Bible production, tech handoff, cohesion) to the index | Reversible |
| L4-08 | S2 | `docs/tech/`, `docs/bible/production/`, `docs/audit-2026-09-05/`, `docs/research-2026-09-05/`, `public/art/` | No README/index; only `docs/tech/sections/README.md` exists. `docs/tech/` has an index for its `sections/` child but none for `proofs/` or `native-toolchain.md`. | F27 | Add short READMEs: which files are admission records, which are provenance, what is superseded | Reversible |
| L4-09 | S2 | `docs/art-prompts/06-orchard-storyboard-v{1,2}.txt` vs `public/art/06-orchard-combat-storyboard{,-v2}.png` | Prompt file names do not match the images they produced; a basename search for the image never finds the prompt. Also a third naming convention (`05-…-v1.txt`) alongside `docs/bible/prompts/A01-v1.txt`. | F28, F29; `ls public/art docs/art-prompts` | Rename prompts to match outputs, or add a provenance table row in `docs/CONCEPT-STUDY-03.md` | Reversible (`git mv`) |
| L4-10 | S2 | `public/art` (8 png), `docs/bible/images` (30 png) | **No live reference anywhere.** 109,613,198 B referenced only by prose and machine manifests. Correct as design evidence per `docs/project/ASSETS.md:9`, but nothing in the tree states “documentation only, not shipped”. | F15 (`grep` over `src/ tests/ server/ scripts/ index.html orchard.html` → no `.png` asset references), F16 | Add one line to `docs/DESIGN-INDEX.md`/`docs/project/ASSETS.md` stating these are documentation assets; **do not delete** | N/A (no change) |
| L4-11 | S2 | `docs/bible/production/assets.json` + 9 sibling JSONs, `docs/bible/production/BIBLE-approved-step0.md.txt`, `style-lock.json`, `assets-in-progress.json`, `section-0N-decisions.md` (21 files, 124,507 B) | Reachable only through machine manifests under `artifacts/`; no human-readable inbound link. Not orphans, but invisible to a reader. | F18 | Reference them from a new `docs/bible/production/README.md` | Reversible |
| L4-12 | S2 | `docs/decisions.tsv` | 69-line TSV in a Markdown tree; still cited by `adr/README.md:37` as “the existing decision trail” while `docs/project/DECISION-REGISTER.md` owns current rulings — two decision trails. | F31; `grep -rn decisions.tsv` → `adr/README.md:37` + manifests | Add a header row/comment or a pointer note; **owner decides which trail is authoritative** | Reversible |
| L4-13 | S3 | `docs/bible/production/BIBLE-approved-step0.md.txt` | Double extension `.md.txt`; the only such file in the repo. | `git ls-files docs/bible/production` | Rename to `BIBLE-approved-step0.md` or `.txt` | Reversible |
| L4-14 | S3 | `docs/bible/production/source-snapshot.json` vs `source-snapshot-final.json` | Both 1,078 B with 11 keys, differing in 5; names carry neither date nor revision, so “which is final” is only knowable by diffing. | F30; `ls -l …source-snapshot*.json` | Rename to `source-snapshot-2026-09-06-pre.json` / `-final.json`, or add a `"revision"` field | Reversible |
| L4-15 | S3 | `COHESION_REPORT.md` (root) vs `docs/bible/production/independent-review.md` | The synthesis report lives at repo root while every sibling record (review brief, independent review, source appendix) lives under `docs/bible/production/`. | `git ls-files COHESION_REPORT.md docs/bible/production/independent-review.md`; F24 (they are **not** duplicates, ratio 0.012) | Leave in place (root link stability) or move with redirect note; **owner preference** | Reversible |
| L4-16 | S3 | `docs/bible/ART-DIRECTION-LOCK.md`, `docs/bible/production/section-07.md:1-78`, `BIBLE.md:614-691` | The frozen art-direction text exists 3× byte-identically (9,260 B each, sha256 `0f694b90…`). Deliberate and documented, but three copies can drift independently. | F23 | Keep all three (byte-identity is the guarantee); add the digest to `section-07.md`’s marker comment so drift is detectable | Reversible |
| L4-17 | S4 | `artifacts/**` duplicate groups (63 groups entirely inside `artifacts/`; 10 more spanning `tools/`+`native/`) | 1,206,225 B of byte-identical copies; largest is 4× `terminal.jpg` (261,777 B). Lane contributes **0 B**. | F6, F7 | Cross-lane: dedupe inside `artifacts/` only after the owner confirms the evidence-retention rule; never delete the `tools/agent-player/tests/fixtures/*` originals | Recoverable from git while tracked |
| L4-18 | S4 | `docs/bible/images/*-v1/v2` superseded attempts; `public/art` v1 pair | 20,664,102 B / 7 files that are superseded but **must be preserved**: `BIBLE.md` links five of them once each as revision history and `CONCEPT-STUDY-03.md:41-44` documents the v1 pair as the rejected attempt. | F11, F12, F13 | **Keep. No deletion.** Record them in an art revision ledger so a future cleaner does not reclaim them | Deletion would be irreversible for the review trail (bytes recoverable from git while tracked) |
| L4-19 | S4 | `/home/andrew/Projects/test-game-2` (outside repo) | 1,877,208,953 B stale checkout; 1,443,928,778 B of it is git-ignored `artifacts/local`; committed history already present here (`git cat-file -t c5e61d3…` → `commit`); exactly one unique untracked file `.codex/config.toml`. 68 repo files reference the path. | F36 | **Owner decision.** Archive-then-delete only after confirming nothing unique is needed | Deleting the working tree is irreversible for the ignored `artifacts/local` evidence; the committed history is not |
| L4-20 | S4 | `docs/discovery/source-notes-2026-08-21/photo-{1..4}.jpg` (433,035 B) | Irreplaceable primary sources (handwritten notes, “dated pages read 8/21/26”), preserved unrotated per `docs/HANDWRITTEN-NOTES.md:3`. | F3; `head -3 docs/HANDWRITTEN-NOTES.md` | **Keep. No deletion.** | Irreversible if deleted |
| L4-21 | S3 | `artifacts/foundation-sprint-2026-09/tasks/HF-03a/attempt-1/whitespace.log` | The only 0-byte tracked file in the repo (outside my lane). | F25 | Cross-lane: delete or fill; harmless | Recoverable from git |

**Non-findings (verified clean, do not fix):** 0 dead relative links and 0 unresolvable anchors across 74 lane Markdown files / 568 links (F19); 0 strict orphans (F17); 0 byte-identical duplicates inside `docs/`+`public/` (F7); no duplicated art between `docs/bible/images` and `public/art` (F10, F37); no scratch files, no untracked/ignored files in lane dirs, no ≤120 B stubs (F26).

---

## 3. Uncertain / needs owner decision

1. **`/home/andrew/Projects/test-game-2` (1,877,208,953 B).** Outside the repo and outside my read-only lane. Committed history is already in this repo and only one untracked file exists, but 1,443,928,778 B of it is *ignored* `artifacts/local` evidence that git cannot restore. I did not enumerate that evidence for uniqueness. **Owner must decide whether it is disposable**, and whether `docs/bible/production/assets.json` should keep pointing at it (L4-06) or be rewritten to repo-relative paths. Note both checkouts share origin `https://github.com/bananahana720/scrapkeep.git`; I did not fetch or compare against the remote.
2. **Which decision trail is authoritative — `docs/decisions.tsv` or `docs/project/DECISION-REGISTER.md`?** `adr/README.md:37` still points readers at the TSV. Resolving this changes what “superseded” means for a dozen rows (L4-12).
3. **`COHESION_REPORT.md` root placement** (L4-15). `grep -rl -F "COHESION_REPORT.md"` finds **18 non-artifact files / 156 occurrences** (mostly per-asset entries in `docs/bible/production/*assets*.json`; exactly one Markdown link each in `BIBLE.md:7` and `docs/bible/production/FRONT-MATTER.md:7`). Moving the file breaks all of them; leaving it keeps a report at repo root while its siblings are under `docs/`. Preference call.
4. **Whether the nine staging manuscripts in `docs/bible/production/` should keep full verbatim bodies** at all, or be reduced to a pointer + digest. I recommend keeping them (they are the production provenance and `docs/project/SOURCE-DISPOSITIONS.md` treats dated sources as evidence) but only a banner is clearly safe.
5. **`docs/bible/images` vs `public/art` retention.** 109,613,198 B with zero live references. `docs/project/ASSETS.md:9` says retain the eight `public/art` images “original names”; nothing in-tree states whether the 30 Bible PNGs must stay full-resolution. Owner may prefer JPEG/WebP re-encode to cut weight — that would **change bytes and break every recorded digest** in `assets.json`, `COHESION_REPORT.md` and `artifacts/swarm-prep-2026-09-06/verification.json`, so it needs an explicit decision.
6. **`docs/audit-2026-09-05/worker-2-combat.md` is load-bearing** for a canonical record: `docs/project/SOURCE-DISPOSITIONS.md` row P09 names it as the only retention of the Sluiceback experiment. Any archival move needs that row updated first.
7. **Severity of L4-07 (index staleness).** I rated it S2 because `docs/project/README.md` (canonical, not my lane) may already be the intended entry point; if it indexes `docs/bible/**` and `docs/tech/**`, `DESIGN-INDEX.md` is a redundant second index rather than a broken one. I did not re-read the canonical desk in depth to decide this.

---

## 4. Recommended atomic task cards

> Standing notes for every card below: **(a)** all deletions in this lane are irreversible only for **untracked/ignored** content — every file named here is tracked, so `git checkout <base> -- <path>` restores it while the object exists; the irreversible items are the ignored `artifacts/local` evidence in the sibling clone (L4-19) and the `docs/discovery` photographs (L4-20). **(b)** Per `AGENTS.md`, historical evidence is preserved: the superseded art versions (L4-C8), the discovery photographs and the audit papers are evidence, not clutter. **(c)** Documentation-only work: verify with structure/link checks, not builds (`AGENTS.md` line 10).

**L4-C1 — Banner the four audit papers**
Files: `docs/audit-2026-09-05/worker-1-architecture.md`, `worker-2-combat.md`, `worker-3-meta.md`, `worker-4-universe.md`.
Acceptance: each file's first 12 lines contain the word “Historical” and name `docs/project/SOURCE-DISPOSITIONS.md` and `docs/RUNTIME-BLUEPRINT.md`; `worker-1` and `worker-3` note that `/home/andrew/Projects/test-game-2` is the pre-rename root and that git is now available at `/home/andrew/Projects/scrapkeep`.
Verification: `grep -c "Historical" docs/audit-2026-09-05/*.md` ≥ 1 each; link checker reports 574+ links, 0 dead.
Size: **S**. Reversible.

**L4-C2 — Banner the Bible staging manuscripts**
Files: `docs/bible/production/FRONT-MATTER.md`, `docs/bible/production/section-01.md` … `section-09.md`.
Acceptance: each opens with a staging banner stating that `BIBLE.md` is the reader's reference and this file is the production source at revision `b61feb1`; no prose body is altered (line-overlap with `BIBLE.md` must stay ≥ 84 %).
Verification: `grep -l -i "staging\|historical" docs/bible/production/section-0[1-9].md docs/bible/production/FRONT-MATTER.md | wc -l` → 10; the §1.7 `python3` overlap check reproduces its table within ±1 line.
Size: **S**. Reversible.

**L4-C3 — Banner the superseded design records**
Files: `docs/DESIGN-AUDIT.md`, `docs/ORCHARD-ENCOUNTER-STUDY.md`, `docs/ORCHARD-VISUAL-SWARM.md`.
Acceptance: each names the newer record (`docs/project/DECISION-REGISTER.md`, `docs/project/INCREMENT-01-lightning-playtest.md`, `docs/LIGHTNING-PLAYGUIDE.md`) and drops the now-false present-tense claim identified in F34.
Verification: `grep -n "no session goal or gameplay implementation is set" docs/ORCHARD-VISUAL-SWARM.md` → no match; `grep -n "for later prototyping" docs/ORCHARD-ENCOUNTER-STUDY.md` → no match.
Size: **S**. Reversible.

**L4-C4 — Correct the character-authority claim**
Files: `docs/CHARACTER-BIBLE.md` (line 3).
Acceptance: line 3 no longer calls itself the production-guiding reference; it defers to `BIBLE.md` §4/§9 and `BIBLE_DECISIONS.md`, and keeps the existing “invented names remain creative proposals” caveat.
Verification: `sed -n 3p docs/CHARACTER-BIBLE.md`; `grep -c "production-guiding" docs/CHARACTER-BIBLE.md` → 0.
Size: **S**. Reversible.

**L4-C5 — Index the newest records in the design desk**
Files: `docs/DESIGN-INDEX.md` (+ optional `docs/tech/README.md`, `docs/bible/production/README.md`, `docs/audit-2026-09-05/README.md`).
Acceptance: a “Newest records” block links `BIBLE.md`, `BIBLE_DECISIONS.md`, `COHESION_REPORT.md`, `docs/bible/production/REVIEW-BRIEF.md`, `docs/tech/native-toolchain.md`, `docs/tech/sections/README.md`, `docs/tech/proofs/`; every new link resolves.
Verification: link checker → 0 dead, 0 bad anchors; `grep -c "docs/tech/sections/README.md" docs/DESIGN-INDEX.md` ≥ 1.
Size: **S**. Reversible.

**L4-C6 — De-stale provenance paths** *(needs the §3.1 owner answer first)*
Files: `docs/bible/production/assets.json`, `assets-in-progress.json`, `section-0N-assets.json` (9), `section-0N-decisions.md` (9), `independent-review.md`, `docs/bible/prompts/M04-v2.txt`, `docs/research-2026-09-05/REVIEW-NOTES.md`.
Acceptance: `grep -rn -o "test-game-2" docs/ | wc -l` drops from 363 to ≤ 17 (only files where the old root is deliberate history), **or** every JSON file gains a top-level `"path_base"` note naming the archived clone; `assets.json` still yields 100 resolvable, byte-identical targets, or 100 repo-relative targets that hash-match their in-repo files.
Verification: re-run the §1.9 parse script (100 path fields, 0 dangling, 100/100 identical); `grep -rn "test-game-2" docs/bible/production/assets.json` empty in the rewrite variant.
Size: **M** (10 JSON files, 363 occurrences, must not break recorded digests). Reversible.

**L4-C7 — Align prompt filenames with their outputs**
Files: `docs/art-prompts/06-orchard-storyboard-v1.txt` → `06-orchard-combat-storyboard-v1.txt`, `…-v2.txt` likewise; update `docs/CONCEPT-STUDY-03.md:43-44` and any `docs/project/ASSETS.md` reference.
Acceptance: for every image basename in `public/art`, either a same-stem prompt file exists in `docs/art-prompts/` or `docs/CONCEPT-STUDY-03.md` carries a provenance row explaining the absence; no dangling link.
Verification: link checker 0 dead; `ls docs/art-prompts public/art`; `grep -rn "orchard-storyboard-v" docs/` → only the new names.
Size: **S**. Reversible (`git mv`).

**L4-C8 — Art revision ledger (prevents an irreversible cleanup)**
Files: new `docs/bible/production/ART-REVISIONS.md` (or a section appended to `REVIEW-BRIEF.md`), referencing `docs/bible/images/U01-v1.png`, `U02-v1.png`, `U02-v2.png`, `C03-v1.png`, `M04-v1.png`, `public/art/05-pruner-family-study.png`, `public/art/06-orchard-combat-storyboard.png`.
Acceptance: each of the 7 superseded files is listed with its byte size, its superseding file, and the record that referenced it (`BIBLE.md` revision line, `COHESION_REPORT.md`, `CONCEPT-STUDY-03.md:41-44`), plus an explicit “historical evidence — do not delete” line.
Verification: the 7 paths in the ledger all exist and the sizes match `du -b`; **deletion is explicitly out of scope**; the ledger is the artifact that makes a future re-encode/deletion decision reviewable.
Size: **S**. Reversible.
**Preservation note:** the 7 files total 20,664,102 B and are historical evidence per `AGENTS.md` (“preserve historical evidence and owner changes”). Deleting them is irreversible for the review trail and would immediately break the revision-history links in the canonical `BIBLE.md`.

**L4-C9 — Dedupe machine evidence inside `artifacts/`** *(cross-lane; coordinate with the artifacts owner)*
Files: the 63 duplicate groups entirely inside `artifacts/` (855,363 B reclaimable) plus the 10 mixed groups; **never** the `tools/agent-player/tests/fixtures/*.jpg` originals.
Acceptance: `sha256sum` grouping over `git ls-files` reports ≤ 10 duplicate groups; `artifacts/local` untouched; lane byte total unchanged.
Verification: re-run §1.2 script — expect 1,206,225 → ≥ 995,870 B saved; `npm run check:project` unaffected (no `src/` change).
Size: **M**. Recoverable from git while tracked; **not reversible for any untracked copy**.

**L4-C10 — Retire the stale sibling checkout** *(owner-only; outside my scope)*
Files: `/home/andrew/Projects/test-game-2` (1,877,208,953 B; 1,443,928,778 B of it ignored `artifacts/local`).
Acceptance: before deletion, an inventory of `artifacts/local` proves nothing unique is needed, `.codex/config.toml` is copied or dismissed, and `git cat-file -t c5e61d3…` in this repo still returns `commit` afterwards; then update the 68 repo files that name the path, including `docs/bible/production/assets.json` (see L4-C6).
Verification: post-deletion re-run of the §1.9 parse script must find 0 references; `npm run check:docs` clean.
Size: **M**. **Deletion of the working tree is irreversible for the ignored evidence**; committed history is already present in this repo.

---

## 5. Method and limits

**Commands used (all read-only):** `git ls-files`, `git ls-files -z | xargs -0 du -bc`, `xargs -0 sha256sum`, `git log --diff-filter=A --format=%ad`, `git rev-parse`, `git cat-file -t`, `git status --porcelain [--ignored]`, `grep -rn/-rl/-c/-o`, `find`/`ls`, `sed`/`head`/`diff`, `du -sb`, `stat`, plus inline `python3` (hash grouping, markdown link/anchor resolution, line-overlap sets, PNG IHDR parsing, PIL 32×32 greyscale comparison, absolute-path resolution). No `git` mutating command, no build, no browser, no native/Godot command, no network.

**Deliberate omissions and their cost:**
1. **I did not run `npm run check:docs` / `check:project` / `check:scope`.** `scripts/check-docs.mjs` always `mkdir`s and `writeFile`s a report, which exceeds the single-file write allowance for this lane. Cost: my independent link/anchor result (§1.6) is not corroborated by the repo-native checker. Recommended follow-up for whoever owns a writable scope.
2. **I did not re-read the canonical `docs/project/**`, `adr/**`, or `docs/DISCOVERY.md` in depth** — they are another lane's authority. I read `docs/project/SOURCE-DISPOSITIONS.md` and `docs/project/ASSETS.md` only to ground supersession and retention claims. Cost: a supersession I attributed to `DESIGN-INDEX.md` may in fact be owned by a canonical record I did not open (§3.7).
3. **No pixel-exact image comparison.** Image similarity used 32×32 greyscale RMS, backed by `sha256` equality for any "identical" claim. Cost: two *perceptually* identical but re-encoded images would not be flagged. All "different" verdicts are conservative-safe; all "identical" verdicts rest on hashes, not on RMS.
4. **PDF/docx and other non-text assets:** none are tracked in this repo, so no such check was needed.
5. **Corpus truncation in the reference search:** files > 3 MB and non-UTF-8 files were excluded from the *text* corpus (all are images here). Images therefore contribute no inbound links of their own, which is correct — but it means "reference" always means "a text file mentions this path/basename".
6. **Basename matching is loose for generic names.** `README.md` matches 125 files; a file whose only "reference" is the bare word `README.md` would be a false negative for orphanhood. Only two lane files are index-like, both with many references, so this does not change the orphan result — but it is why I report both path-level and basename-level hits.
7. **My own tooling produced two false-positive classes that I corrected before reporting** (angle-bracket link syntax; GitHub anchor slug rules). Both corrections are recorded in §1.6 F20 so the numbers can be reproduced.
8. **No claim here is about anything outside the tracked tree** except §1.10/§3.1 (the `test-game-2` sibling checkout), which is explicitly labelled as outside the repo and outside my lane.
