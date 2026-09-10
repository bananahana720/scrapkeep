# Lane 6 — code and tooling

Read-only audit of `src/**`, `server/**`, `tests/**`, `scripts/**`, `tools/**`, `native/**`, `index.html`,
`orchard.html`, `vite.config.js`, `package.json`, `.claude/**`, `.agents/**`, `.codex/**`.
Repo `/home/andrew/Projects/scrapkeep`, branch `main`, HEAD `b61feb1` ("docs: assign runtime lifecycle and
content admission contracts"), Node `v26.8.1`, npm `11.19.0`.
`AGENTS.md` and `CONTRIBUTING.md` were read first, then the source-of-truth map they name.

---

## 1. Verified state — facts, each with the exact command run and its observed result

### 1.1 Working-tree and revision state

| Fact | Command | Observed |
| --- | --- | --- |
| HEAD and branch | `git rev-parse --short HEAD && git rev-parse --abbrev-ref HEAD` | `b61feb1`, `main` |
| Tree is not clean on entry | `git status --porcelain` | ` M TRACKING.md` and `?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/` |
| Tree unchanged after every audit command | `git status --porcelain` (re-run at end) | identical two lines — no tracked file was added, modified or removed by this lane |
| Uncommitted board change is small and substantive | `git diff --stat TRACKING.md` | `1 file changed, 10 insertions(+), 6 deletions(-)` — new EV-0090/0091/0092 rows, HF-04a row revision 3→5, HF-04a-A1/HF-05-A1 checkpoint blocks |
| Node/npm | `node --version && npm --version` | `v26.8.1`, `11.19.0` |

### 1.2 The permitted checks — exit codes and output summaries

| Command | Exit | Observed result |
| --- | --- | --- |
| `npm test` | **0** | `ℹ tests 187 / ℹ pass 187 / ℹ fail 0 / cancelled 0 / skipped 0 / todo 0 / duration_ms 4001` |
| `npm run check:docs` | **0** | `check:docs pass: 120 Markdown files, 3340 local links, 77 cards, 92 events, 4 sections, 7 interim rows, 0 failures. Report: artifacts/local/check-docs/report.json`, plus 7 `INFO tracking … interim row without a BACKLOG link` lines (TRACKING.md:104-110) |
| `npm run check:project` | **0** | `Project checks passed: 102 Markdown files, 1961 file links, package/lock metadata.` |
| `npm run check:scope -- HEAD~3 HEAD` | **0** | `scope: documentation-only (15 changed paths)`; required commands `npm run check:docs`, `npm run check:project` |
| `node --check <file>` × 8 | **0** | `scripts/{agent-playtest,check-build,check-docs,check-project,check-scope,native-smoke,sprint-close,verify}.mjs` all `OK` |

Not run, per instruction: `npm run verify`, `npm run build`, `npm run native:smoke`, `npm run test:*`,
Playwright/browser runs, installs, and every Godot/network command.

### 1.3 Dead modules and exports (item 1)

* **No unreachable module exists.** A read-only reachability walk from the three real entry points
  (`index.html` → `src/main.js`, `orchard.html` → `src/orchard/main.js`, `package.json` → `server/index.js`)
  resolved every static and dynamic relative import: `16 src+server .js files, UNREACHABLE: none`
  (18 modules visited = 16 product modules + the two QA runners that `src/**/main.js` imports dynamically).
  Import map observed: `src/main.js` → game/world/audio/collection/campaign/heroes; `src/orchard/main.js` →
  simulation/scene; `src/world.js` → game/heroes/art + three addons; `src/collection.js` → campaign/heroes/progress-store.
* **Every file in `src/` and `server/` has an importer.** `src/audio.js` (exported `AudioEngine`) is imported
  by `src/main.js`; `src/art.js` by `src/world.js`; `server/{store,validation}.js` by `server/index.js`.
* **8 exports are never imported by any other module.** An import-statement-level scan
  (`node -e` collecting every `import {…} from` binding, then testing each `export` name) returned:
  `src/art.js:92 consolidate`, `src/campaign.js:45 MODIFIERS`, `src/collection.js:13 escapeHtml`,
  `src/game.js:203 clamp`, `src/game.js:204 distance`, `src/orchard/simulation.js:166 toolSegments`,
  `tests/expedition-balance.mjs:5 simulate`, `scripts/sprint-close.mjs:20 checkReceipt`.
  All eight are used **inside** their own file (`grep -c` per file: consolidate 6, MODIFIERS 2, escapeHtml 4,
  clamp 7, distance 9, toolSegments 3), so the dead surface is the `export` keyword, not the code.
  `checkReceipt` is the clearest case: `tests/sprint-close.test.js:56` runs the script through
  `spawnSync(process.execPath, [script, …])` and never imports it.
* **No unused local function was found** in `src/` or `server/` (heuristic scan of every non-exported
  `function`/`const f = (`/`class` declaration: the only hits were the jQuery-style `$` helper in the two
  `main.js` entry points).
* **Branches that cannot trigger (real, small):** `config.localOnly` is a literal `true` at
  `server/index.js:112` and the option is never read from `options` (`grep -rn "localOnly" src server tests`
  → `server/index.js:112`, `src/collection.js:59`, `src/collection.js:186`, `src/collection.js:291`,
  `tests/legacy/leads.test.js:280` asserting `true`). The `else` arms of the two local-only ternaries
  (`src/collection.js:186`, `src/collection.js:291`) can therefore never render, in either the API default or
  the client fallback. Documented as deliberate at `docs/LEAD-CAPTURE.md:38`.
* **QA entry points are gated, asymmetrically:** `window.__scrapkeep` at `src/main.js:675` sits inside
  `if (import.meta.env.DEV)` (`src/main.js:674-679`); `window.__orchard` at `src/orchard/main.js:784` sits
  inside `if (qaEnabled)` (`src/orchard/main.js:783-812`) where `qaEnabled` is only the URL check at
  `src/orchard/main.js:17` — no DEV gate.

### 1.4 Duplicated logic (item 2), quantified

| Duplicate | Locators | Size | Drift |
| --- | --- | --- | --- |
| Static-server path safety | `server/index.js:47-55` vs `scripts/check-build.mjs:18-26` | 9 lines each | **Byte-identical** — `diff <(sed -n '47,55p' server/index.js) <(sed -n '18,26p' scripts/check-build.mjs)` → no output, `IDENTICAL` |
| Static request resolution | `server/index.js:219-246` vs `scripts/check-build.mjs:28-54` | 28 vs 27 lines | Same decode → reject `\` and dot-parts → `path.resolve(dist, "." + pathname)` → `isWithin` → `realpath` → `isWithin` → `stat().isFile()`; check-build omits the data-directory exclusion at `server/index.js:243` |
| MIME table | `server/index.js:14-31` (18 entries) vs `scripts/check-build.mjs:9-16` (6 entries) | 18 vs 8 lines | Subset only |
| Markdown link scanning | `scripts/check-project.mjs:59-78` vs `scripts/check-docs.mjs:163-233` | 20 vs 71 lines | Same regex at `check-project.mjs:64` and `check-docs.mjs:168`, same scheme skip, same `split("#")` + `decodeURIComponent` + `access()`. check-project removes fenced blocks wholesale (`:60-63`) while check-docs blanks them per line to keep line numbers (`:94-104`); check-docs strips link titles (`:171`) and check-project does not; check-docs owns the absolute-link and `../`-escape rules (`:175-182`, `:204-212`) |
| Script boilerplate | root computation ×7 (`check-build:7`, `check-docs:6-9`, `check-project:6`, `check-scope:5-8`, `native-smoke:19`, `sprint-close:302`, `verify:7`); `parseArguments` (`check-docs:35-50` vs `check-scope:93-108`); sha256 helper (`check-docs:148`, `sprint-close:16`, `verify:57-60`, `native-smoke:279-288`); recursive walker (`check-docs:61-71`, `check-project:39-49`, `native-smoke:134-143`, `verify:34-44`); spawnSync wrapper (`verify:64-70` vs `native-smoke:41-61`) | ≈100 lines | **No shared module exists**: `ls scripts/` → 8 `.mjs` + `new-worktree.sh`, no `lib/` |
| Baseline patrol simulation | `tests/balance.mjs:9-48` vs `tests/expedition-balance.mjs:5-110` | 40 vs 106 lines | The asserted one hard-codes an 18-point route (`expedition-balance.mjs:12-31`); the probe one uses the exported `PATH` (`balance.mjs:22` ← `src/game.js:2-23`, 20 points) |

* `scripts/sprint-close.mjs` explicitly states it "does not … mutate canonical records" (`:297`) and its
  `main` only reads a receipt and prints a verdict. No shared parsing/validation code drifted between it and
  the other five scripts beyond the boilerplate above.

### 1.5 Tests, fixtures and runners (item 3)

* **No test asserts removed behavior.** All static imports in all 18 test modules resolve
  (`missing static imports: 0`), all 39 named imports exist as exports, and every flag the tests pass is still
  parsed (`--root`/`--report` `check-docs.mjs:40-41`; `--root`/`--no-build` `check-scope.mjs:97-98`;
  `--root` `sprint-close.mjs:303-304`).
* **`npm test` does not include `tests/legacy/`** and cannot: `package.json:15` is `node --test tests/*.test.js`,
  and the shell expansion of that glob is exactly 10 files with `legacy present in expansion? 0`.
  `tests/legacy/leads.test.js` (358 lines, 13 `test(` declarations) is wired only as
  `package.json:13 "test:leads": "node --test tests/legacy/leads.test.js"`, which is honest and matches
  `CONTRIBUTING.md:31,41,47` verbatim. It is not referenced by `scripts/verify.mjs:12-19`.
* **The two QA runners are live, not orphaned.** `tests/browser-runner.js:11 installQA` is dynamically imported
  by `src/main.js:677` (DEV + `?qa`) and reached by `npm run test:browser` through the page
  (`tests/browser.mjs:23,25,31-32`); `tests/orchard-browser-runner.js:7 installOrchardQA` is dynamically
  imported by `src/orchard/main.js:810` (any `?qa`). No `.mjs` imports either file, which is why a naive grep
  reads them as orphans. `dist/assets/orchard-browser-runner-CLJYWHnE.js` (20 K) exists in the current build,
  and `dist/assets/*.js` contains `installOrchardQA` and `__orchard`; no `browser-runner` chunk and no
  `__scrapkeep` exist in `dist`.
* **Fixtures: zero unused.** All 22 files under `tests/fixtures/` are tracked
  (`diff <(find …) <(git ls-files …)` → identical). Each of the 15 `check-docs` fixture directories is named in
  `tests/check-docs.test.js` (base ×4, broken-anchor/duplicate-event/event-gap/malformed-percent ×2, the other
  10 ×1); the 7 `base` files are pinned by the exact 7-key manifest assertion at `check-docs.test.js:52-60`;
  `tests/fixtures/check-scope/cases.json` drives 11 scenarios + 1 malformed-invocation test = the 12 tests that
  file reports. The `base/**` tree is **not** stale copies: it is a deliberately minimal stub (7-25 line files)
  used only by `check-docs.test.js`, not by `tests/sprint-close.test.js`, which builds its own git fixtures in
  `mkdtemp` (`tests/sprint-close.test.js:14-51`).
* **Runner duplication is small:** normalised-line Jaccard 0.028 (249 vs 551 significant lines, 22 shared), one
  identical 2-line helper (`browser-runner.js:32-33` == `orchard-browser-runner.js:19-20`). The duplication is
  design shape, already recorded at `docs/audit-2026-09-05/worker-1-architecture.md:117`.
* **Historical record, not drift:** `TRACKING.md:282` (EV-0034) says native:smoke ran "ten checks"; the script
  now builds 12 default-mode checks (4 base + 3 proof pairs + `engine-pin` at `scripts/native-smoke.mjs:701` +
  `source-preservation` at `:716`). Event rows are append-only historical snapshots, so this is not a stale
  live claim; no non-TRACKING doc asserts a native check count
  (`grep -rn "ten checks\|four checks\|checks PASS" --include='*.md' .` outside TRACKING → no matches).

### 1.6 Canonical-record writers and the TRACKING corruption (item 4)

* **No script writes any canonical record.** Commands and results:
  * `grep -rn "TRACKING\|BACKLOG" scripts/` → only reads and path classification: `check-project.mjs:14`
    (required-file list), `check-docs.mjs:245,337,391-392,403,410,436` (reading `BACKLOG.md`/`TRACKING.md`).
  * `grep -rn "writeFile\|appendFile\|createWriteStream\|writeFileSync\|appendFileSync\|rename" scripts/` →
    6 hits, all writing under `artifacts/local/…`: `verify.mjs:29,71`, `check-docs.mjs:523`,
    `native-smoke.mjs:763,782`.
  * Repo-wide, including Python/shell/YAML/TOML:
    `grep -rnE '(open|write_text|writeFile|appendFile|tee|>>?)[^\n]{0,40}(TRACKING\.md|BACKLOG\.md)' --include='*.py' --include='*.js' --include='*.mjs' --include='*.sh' --include='*.yml' --include='*.toml' .` → **no matches**.
  * Consequence: **there are no backup files to check, because no script rewrites a canonical file.** The
    ORCHESTRATOR rule that only the coordinator writes canonical records is not violated by tooling. The
    canonical writers are human/agent edits plus `git`.
* **The corruption is a deleted separator, not a mangled delimiter.** `sed -n '338p' TRACKING.md | hexdump -C`
  over the suspect span prints `6e 65 72 2c 38 20 66 …` = `ner,8 f…`; the file is ASCII-only at that point
  (`LC_ALL=C grep -c $'[\x80-\xFF]'` on the line → `0`; 279 non-ASCII bytes exist in the whole file, none in
  line 338). So the space is genuinely absent — no invisible or zero-width character.
* **Prevalence (three counts, strongest first):**
  * ≥75 unambiguous space-loss tokens: `grep -oE '(revision|rev|attempt|ttempt|candidate|source|checks|check|fail|exit|level|row|owner|scenario|scenarios|table|tables|modules|edges|owners|files|paths|rows|tests|artifacts|report)[0-9]{1,4}' TRACKING.md | wc -l` → `75`, led by `revision2` ×12, `revision1` ×9, `rev2` ×8, `revision3` ×7, `ttempt2` ×5.
  * 15 missing spaces after a comma before a digit: `grep -oE '[a-zA-Z],[0-9]' TRACKING.md | wc -l` → `15` (e.g. `r,8`, `s,3`).
  * 278 broad suspect tokens: `grep -oE '[a-z]{3,}[0-9]{1,3}' TRACKING.md | grep -vE 'sha256|bananahana720' | wc -l` → `278` (272 in `git show HEAD:TRACKING.md`).
* **The same signature appears in coordinator-authored files no script touches**, e.g.
  `artifacts/foundation-sprint-2026-09/tasks/HF-04a/assignment.md:10`
  ("admitted at3f56a82ea7b74ebd6769b5ea50653d9d2452453a, admin7a73c5b5; sectionsha95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
  "all5 tabletop step tables", "HF04b revision2"), and
  `artifacts/foundation-sprint-2026-09/amendments/AM-FF-001/request.md:7,11` (`revision1`, `revision2`, `DoD2`).
* **Prevalence tracks coordinator prose volume, not tooling:** `TRACKING.md` 278 suspect tokens (123 KB),
  `BACKLOG.md` 2, and `ORCHESTRATOR.md` / `BIBLE.md` / `CONTRIBUTING.md` / `AGENTS.md` **0**.
* The three newest rows are corrupt **in the uncommitted working-tree change** (`git diff TRACKING.md`):
  EV-0090 contains the reported `one C-TICK owner,8 forbidden callback families,P0-P6 fixed phases,O1-O4 control operations and5 tabletop tables`;
  EV-0091 contains `candidate72178cf58a39e9ca1c70922eca830776573f3ce8`, `sectionsha7eb7ad2c…`;
  EV-0092 contains `seven-state,16-edge`, `118 paper/source checks`.
* **Independent corroboration that only whitespace is lost:** `artifacts/local/audit-2026-09-10/preserved/PRESERVED.md:17-19`
  reports that the EV-0091 token `sha7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb`
  matches the parked HF-04a candidate byte-for-byte. The digits survive; only the space before them is gone.

### 1.7 Housekeeping markers (item 5)

| Directory | TODO/FIXME/HACK/XXX | `console.*` | `debugger` |
| --- | --- | --- | --- |
| `src/` (shipped game code) | 0 | **0** | 0 |
| `server/` (shipped runtime) | 0 | 1 — `server/index.js:296`, the startup banner | 0 |
| `scripts/` (tooling) | 0 | 25 | 0 |
| `tests/` (tooling) | 0 | 12 | 0 |
| `tools/` (Python tooling) | 0 | 0 | 0 |
| `native/` (proof code) | 0 | 0 | 0 |
| **Total** | **0** | **38** | **0** |

Per-file top offenders are all tooling: `scripts/check-scope.mjs` 10, `tests/native-smoke.test.js` 7,
`scripts/native-smoke.mjs` 4, `scripts/check-docs.mjs` 4, `scripts/sprint-close.mjs` 3, then 1-2 each in
`tests/orchard-models.mjs`, `scripts/check-project.mjs`, `tests/lead-browser.mjs`, `tests/expedition-balance.mjs`,
`tests/browser.mjs`, `server/index.js`, `scripts/check-build.mjs`, `scripts/agent-playtest.mjs`.
Commands: `grep -rnE '\b(TODO|FIXME|HACK|XXX)\b' <dir>` (all 0, including `*.gd` in `native/`),
`grep -rnE 'console\.(log|warn|error|debug|info)' <dir>`, `grep -rnE '\bdebugger\b' <dir>`.
No debug hook leaks into the production yard bundle: `grep -rl "__scrapkeep" dist/assets/` → no match.

### 1.8 Dependency and packaging hygiene (item 6)

* **Every `package.json` script target exists.** `node -e` over `package.json` with `fs.existsSync` per target:
  19 file-resolving scripts, all `OK`, 4 non-file commands (`dev`, `build`, `preview` via vite; `test` via glob).
  No missing target.
* **No orphan script.** Every script name appears in `CONTRIBUTING.md`'s table (`:33-51`); `npm start` is used at
  `README.md:41` and `CONTRIBUTING.md:20,23`; `test:balance` is acknowledged as the compatibility alias of
  `probe:balance` at `CONTRIBUTING.md:44`. Executable callers: `scripts/verify.mjs:12-19` runs
  `check:project`, `test`, `test:orchard:models`, `test:expedition`, `build`, `check:build`.
* **Every declared dependency is imported.** `three` (7 `from "three"` + 10 addon imports),
  `@fontsource/barlow-condensed` (`src/main.js:1-2`, `src/orchard/main.js:1-2`),
  `@fontsource/dm-sans` (`src/main.js:3-5`, `src/orchard/main.js:3-5`),
  `@fontsource/ibm-plex-mono` (`src/main.js:6`, consumed by `--mono` at `src/style.css:10` and 18 uses in
  `src/collection.css`). The "declared but never imported" hypothesis is **disproven**.
  No undeclared bare import exists (`grep -rhoE 'from "[^."][^"]*"'` → only `node:*`, `three`, `three/addons/*`,
  `playwright`, `@fontsource/*`, all declared).
* **Lockfile is consistent:** `package-lock.json` `lockfileVersion: 3`; resolved versions match the installed
  tree exactly (`three 0.180.0`, `@fontsource/* 5.3.0`, `playwright 1.63.0`, `prettier 3.9.6`, `vite 7.3.6`),
  and `check:project` asserts root `engines`/`dependencies`/`devDependencies` against the lock (`check-project.mjs:25-37`).
* **`engines` is adequate for the APIs used.** `"node": "^20.19.0 || >=22.12.0"`; the newest runtime features in
  the tree are `Array.prototype.findLastIndex` (`src/campaign.js:153`) and `structuredClone`
  (`tests/sprint-close.test.js:207`), both well below that floor. Actual host `v26.8.1` satisfies it, matching
  `CONTRIBUTING.md:9`.
* **Both permitted checks pass right now** (see 1.2) — `npm test` 187/187 and `check:*` exit 0.
* **Disk weight:** `node_modules` 86 M, `dist` 23 M of which `dist/art` is 22 M copied verbatim from the
  tracked `public/art/` (8 PNGs, 2.0-3.4 MB each, 22 MB total). No HTML/JS/CSS references `public/art/`
  (`grep -rn "art/0\|/art/" src server index.html orchard.html tests scripts` → no matches); the files are
  linked only from `docs/**`. Four of the eight are two superseded pairs (`05-pruner-family-study.png` +
  `-v2`, `06-orchard-combat-storyboard.png` + `-v2`, ≈5.9 MB).

### 1.9 Agent/host config coherence (item 7)

Verified coherent (no finding):

* `CLAUDE.md:4` "The project skills are available in `.claude/skills`" is true: `.claude/skills/` holds three
  **directory symlinks** (`plan-session`, `scrapkeep-task`, `scrapkeep-verify`) resolving into
  `.agents/skills/*`, so the two apps cannot drift by copy. `git ls-files -s .claude/skills` shows mode `120000`
  entries, not duplicate blobs. `AGENTS.md:6` "Both apps share the canonical bodies under `.agents/skills/`" is true.
* All six `.claude/agents/*.md` `name:` values match their filenames and are referenced by `ORCHESTRATOR.md:17`,
  `docs/project/AI-WORKFLOW.md:21` and `.agents/skills/scrapkeep-task/SKILL.md:31`; no orphan definition, no
  dangling reference. `docs/project/AI-WORKFLOW.md:21`'s "Six project agent definitions" matches the 6 files.
* `AGENTS.md:11` / `/home/andrew/.config/pstack/models/codex.md:3` "Codex uses configured Astra roles" is a
  **sanctioned stricter project rule**, not a contradiction: the host map's own line 4 says
  "Honor a project's explicit stricter routing rules unless Andrew changes them", even though the map also
  records Andrew's 2026-09-07 authorization of mixed models (three of the eleven `~/.codex/agents/*.toml`
  pin `gpt-5.6-terra`/`-luna`/`-sol`).
* Read-only vs write tool lists match the bodies (`tools: Read, Grep, Glob` for explorer/reviewer;
  `+ Bash, Edit, Write` for the three writers) and `.claude/settings.json`'s deny/ask lists match
  `docs/project/AI-WORKFLOW.md:25`.

Confirmed incoherent (reported as L6-10): the four-effort-tier enumeration vs the reserved fifth tier, the
"Fable roles" phrasing, the `CLAUDE_EFFORT` reporting instruction that read-only agents have no shell to obey,
and the autogenerated `.codex` environment file that an event row assigned as a writer's target.

### 1.10 Native tree (item 8)

* **It is a real Godot 4.7 project scaffold with real proof code, not an empty placeholder.**
  `git ls-files native/ | wc -l` → `32`; `find native -type f | wc -l` → `32`;
  `git status --porcelain --ignored native/` → **empty** (nothing untracked, nothing ignored inside `native/`).
  16 `.gd` files, 1,779 lines, 1,489 code / 15 comment / 275 blank; 119 `check(`-style call sites across the
  four runners (`tadr-004/proof_runner.gd` 72, `integration/smoke.gd` 25, `tadr-002/proof_runner.gd` 13,
  `tadr-003/proof_runner.gd` 9). `native/project.godot` (16 lines) is a real project file with six
  warning-as-error typing keys; `native/export_presets.cfg` (39 lines) declares `Linux x64` and `Windows x64`.
  Hand-written logic exists, e.g. Kahn cycle detection and DFS reachability at
  `native/proofs/tadr-003/definitions/tree_rules.gd:58-83` and the stage→validate→commit→acknowledge protocol at
  `native/proofs/tadr-004/save_owner.gd:46-114`. `native/README.md:38,80` states the proof-only limits.
* **Zero TODO/FIXME/HACK/XXX and zero `stub`/`unimplemented` markers** in `native/`. The 32 `placeholder` hits
  are fixture identifiers (`id = &"proof.tree.placeholder"`), and the honest scope limits are explicit
  (`native/README.md:34,38,53,80`; machine-readable `"not_asserted"` at `native/proofs/tadr-004/proof_runner.gd:454-458`).
* **Generated-file hygiene:** `.godot/` and `*.import` are gitignored (`.gitignore:19-20`) and neither exists
  today. `__pycache__/` and `*.pyc` are gitignored (`.gitignore:10-11`); `git ls-files | grep -c '\.pyc$'` → `0`.
  One asymmetry: `native/integration/smoke.gd.uid` is tracked while the other 15 `.gd` files have no `.uid`,
  and no `*.uid` rule exists in `.gitignore` (`git check-ignore -v native/integration/smoke.gd.uid` → not
  ignored). The runner's copy/walk filters exclude `.godot` and `.import` but not `.uid`
  (`scripts/native-smoke.mjs:139-140`, `:685-687`).
* **Native check coverage gap:** the networking grep scans only `.gd` + `project.godot` with a 9-class pattern
  (`scripts/native-smoke.mjs:30`, `:147`), i.e. 16 of 32 files, and omits `MultiplayerPeer`, `WebRTC`,
  `SceneMultiplayer`, `DTLSServer` and `UPNP`. The widening is an accepted follow-up recorded at
  `TRACKING.md:276` (EV-0028) but not implemented. Its PASS text is honest about the coverage
  ("no networking class named in N scanned files", `scripts/native-smoke.mjs:169-171`). The rule it defends is
  real: `adr/TADR-005-networking-scope.md:23` decides offline solo with no networking subsystem.

---

## 2. Findings

Severity: **S1** authority/trust · **S2** maintenance hazard · **S3** cosmetic · **S4** disk weight.

| ID | Sev | Locator (file:line) | What is wrong | Evidence (command → observed) | Proposed disposition | Reversibility |
| --- | --- | --- | --- | --- | --- | --- |
| L6-01 | **S1** | `TRACKING.md:119` (state cell), against the legend at `TRACKING.md:30`; checker gap at `scripts/check-docs.mjs:400-429` | The live board's HF-04a row carries state `IN_REVIEW` — wrong case and not a vocabulary member (`review` is). The canonical legend is `queued, blocked, ready, in_progress, review, changes_requested, done, parked or cancelled` and `scripts/sprint-close.mjs:13` enumerates the same set lowercase. `check:docs` **cannot** catch it: `checkTracking` reads only `row.cells[0]` and the last cell (`grep -n "cells\" scripts/check-docs.mjs` → 349, 353, 401, 412), so the state column is never validated | `sed -n '30p' TRACKING.md` → the 9-state legend; `sed -n '119p' TRACKING.md` → `\| [HF-04a (`BACKLOG.md#hf-04a`) \| 1 \| 5 \| IN_REVIEW \| none \| none \| EV-0091 \|`; `npm run check:docs` → **exit 0**, `0 failures`; every other row in the index is lowercase (`awk` over the section → 56 `queued`, 25 `done`, 1 `ready`, 1 `in_progress`, 1 `IN_REVIEW`) | Coordinator (sole canonical writer, `AGENTS.md:11`) corrects the cell to `review` or `in_progress` using the HF-04a-A1 block (`TRACKING.md:536-546` says "Review: fresh ff-hf04a-review pending") and admits EV-0090/0091/0092. Separately, a writer card extends `checkTracking` to validate the state cell against the legend and emit a `failure`, with a fixture. **Ordering matters**: land the checker only after the row is corrected, or `check:docs` starts failing on `main` | Row edit: trivially reversible (one cell). Checker: reversible by `git revert`; may surface more legacy rows, so ship as `failure` only after a full-board pass confirms this is the only violation |
| L6-02 | **S2** (S1 if either proof is ever distributed) | `src/orchard/main.js:783-812` (gate at `:17`), `src/orchard/main.js:810`; build output `dist/assets/orchard-browser-runner-CLJYWHnE.js`; assertion gap at `tests/lead-browser.mjs:51-56`; open decision `docs/project/DECISION-REGISTER.md:23` (D05, status Open) | The production orchard bundle ships the 898-line QA harness as a lazy chunk and installs `window.__orchard` (live `game`, `world`, `start()`, `pause()`, `clearInput()`, `snapshot()`, `controls()`, `performance()`, `events()`) for anyone who appends `?qa`. The yard entry is correctly DEV-gated (`src/main.js:674-679`); the orchard is not. The recommendation already on file (D05 option (a): gate both entries on `import.meta.env.DEV`) is unapplied, and the only production QA-exclusion assertion covers `/` only | `ls dist/assets` → `orchard-browser-runner-CLJYWHnE.js` (20 K); `grep -c installOrchardQA dist/assets/*.js` → `1` in each of the orchard chunk and the runner chunk; `grep -rl __scrapkeep dist/assets/` → no match; `grep -rl __orchard dist/assets/` → `dist/assets/orchard-Cgvn2uSK.js`; `grep -n "__orchard\|qa-panel" tests/lead-browser.mjs` → only line 54, on the `/` entry; `docs/project/DECISION-REGISTER.md:23` → "Option (a) … The current orchard installs the bridge on `?qa` alone in production" with status **Open** | Owner decision on D05; then add a build-time gate (`import.meta.env.DEV` or an explicit build flag) to `src/orchard/main.js:783`, extend the production assertion to `/orchard.html`, and close D05 / `Q-E08` (`BACKLOG.md:2716`) | Reversible (source + rebuild). The `?qa` path is documented as supported today (`CONTRIBUTING.md:58`), so gating it is a deliberate behaviour change that must be recorded in the decision register |
| L6-03 | **S2** | `scripts/check-build.mjs:18-26,28-54,9-16` vs `server/index.js:47-55,219-246,14-31`; missing guard at `server/index.js:243` | The check that qualifies the built entries re-implements the production static server's path-safety logic instead of exercising it. `isWithin` is byte-identical in both files, so a hardening fix to one silently skips the other; the MIME table is a drifted subset; `check-build` has no equivalent of the data-directory exclusion | `diff <(sed -n '47,55p' server/index.js) <(sed -n '18,26p' scripts/check-build.mjs)` → no output, `IDENTICAL (9 lines each)`; the built-HTTP stage is wired into verification at `scripts/verify.mjs:18` | Extract the predicate and request resolver into one module (e.g. `scripts/lib/static-paths.mjs` reused by both, or have `check-build.mjs` start `createLeadServer({captureEnabled:false, distDirectory})` on port 0 and assert `/api/config` is absent); add the data-directory rule to the shared helper | Reversible. Touches the production server, so it is a browser-proof change: acceptance requires `npm run verify` (`AGENTS.md:10`) |
| L6-04 | **S2** | `scripts/check-project.mjs:59-78` vs `scripts/check-docs.mjs:163-233` | Two Markdown link validators drifted apart: identical link regex, but `check-project` drops fenced blocks wholesale (breaking the line-number basis the other preserves by blanking), never strips a link title (`check-docs.mjs:171`), and omits the absolute-link and `../`-escape rules. Today the divergence is latent — no document uses a titled link — but a titled link would make `check:project` fail while `check:docs` passes | `grep -n 'matchAll(/!\?' scripts/check-project.mjs scripts/check-docs.mjs` → `check-project.mjs:64` and `check-docs.mjs:168` are the same pattern; `grep -rnE '\]\([^)]+ +"[^"]*"\)' --include='*.md' .` → no matches; `npm run check:project` exit 0 and `npm run check:docs` exit 0 in the same tree | Make `check:project` call one exported link checker (or a shared `scripts/lib/markdown-links.mjs`) and keep `check-docs` as the superset; update `CONTRIBUTING.md:35-36` scope wording if the overlap changes | Reversible; tooling only, but both commands are documented verification surfaces, so keep their exit semantics |
| L6-05 | **S2** | `tests/expedition-balance.mjs:12-31` (route) and `:5-110`; contrast `tests/balance.mjs:22` and `src/game.js:2-23` | The **asserted** expedition gate (`npm run test:expedition`, a `verify` stage via `scripts/verify.mjs:16`) patrols a hand-written 18-point route that is not the game's `PATH` (20 points), while the non-asserted balance probe uses the real `PATH`. Two patrol implementations and two routes mean a `PATH`/geometry change is not exercised by the gate that asserts victories, so the gate can stay green while path-following behaviour changes | `node -e 'import("./src/game.js")…'` → `PATH points: 20` with `[-12,-7] … [3,8]`; `sed -n '12,31p' tests/expedition-balance.mjs` → 18 points starting `[1,-2]`, `[-2,-5.5]`; `grep -n "PATH\[waypoint\]" tests/balance.mjs` → `:22` uses the exported path; `npm test` exit 0 does not cover this file | Derive the patrol route from `PATH` in `tests/expedition-balance.mjs`, or document in the file why the probe route is intentionally independent, and either use or un-export the `simulate` helper | Reversible (test-only), but changing the route changes the asserted outcomes, so the acceptance must re-run the gate and record the new baseline |
| L6-06 | **S2** | `TRACKING.md:338` (EV-0090, the reported row) plus 277 other tokens; coordinator artifacts e.g. `artifacts/foundation-sprint-2026-09/tasks/HF-04a/assignment.md:10`, `artifacts/foundation-sprint-2026-09/amendments/AM-FF-001/request.md:7,11` | Canonical and near-canonical prose written by the coordinator loses the separating space before numerals and after commas (`owner,8 forbidden callback families`, `and5 tabletop tables`, `revision2`, `candidate72178cf58a…`, `temporarydirectoryremoved`, `npmci`). Meaning survives but the trust record reads as machine-mangled and can misstate counts at a glance | See 1.6: `hexdump -C` on the span → `6e 65 72 2c 38` (`ner,8`), ASCII only; `grep -oE '(revision\|rev\|attempt\|ttempt\|candidate\|…)[0-9]{1,4}' TRACKING.md \| wc -l` → `75`; `grep -oE '[a-zA-Z],[0-9]' TRACKING.md \| wc -l` → `15`; broad pattern → `278` (272 in HEAD); `grep -rn "TRACKING\|BACKLOG" scripts/` → reads only; repo-wide writer grep → **no matches**; prevalence `TRACKING 278 / BACKLOG 2 / ORCHESTRATOR+BIBLE+CONTRIBUTING+AGENTS 0` | **Not a script's templating bug** — see the verdict in §3.1. No repo-side fix applies; the correction belongs to whoever admits the affected rows. A cheap guard would be a lint in `check-docs` that flags `[a-z]{3,}\d{1,4}` and `,\d` inside TRACKING event rows with an allowlist (`sha256`, `bananahana720`, hex hashes) — worth doing only after the owner decides whether the writing path can be fixed | Row prose edits: reversible. A lint can be added later without touching history, since it is a read-only check |
| L6-07 | **S2** | `scripts/native-smoke.mjs:30` (pattern), `:147` (file filter), `:157-173` (report) | The `networking-grep` check that backs "no networking class in `native/`" scans 16 of 32 native files (only `.gd` + `project.godot`) and omits `MultiplayerPeer`, `WebRTC`, `SceneMultiplayer`, `DTLSServer`, `UPNP`. The accepted widening is recorded as a follow-up in a canonical event (`TRACKING.md:276`) but not implemented, so the gap persists across a check that the native proof story relies on (`adr/TADR-005-networking-scope.md:23`) | `sed -n '30p;147p' scripts/native-smoke.mjs` → the 9-class regex and `(file) => file.endsWith(".gd") \|\| file.endsWith("project.godot")`; `find native -type f \| wc -l` → 32; `grep -n "MultiplayerPeer\|WebRTC" scripts/native-smoke.mjs` → no match; `grep -rn "widen the networking grep" TRACKING.md` → `TRACKING.md:276` | Widen the filter to every text file under `native/` (keeping the `.godot`/`.import` exclusions) and add the five class names; extend `tests/native-smoke.test.js` with a fixture that names one added class and expects failure | Reversible (tooling), and the widened check could fail — that is the point; land it with the follow-up card so a real hit is triaged rather than suppressed |
| L6-08 | **S3** | `src/art.js:92`, `src/campaign.js:45`, `src/collection.js:13`, `src/game.js:203`, `src/game.js:204`, `src/orchard/simulation.js:166`, `tests/expedition-balance.mjs:5`, `scripts/sprint-close.mjs:20` | Eight `export`ed symbols are imported by no other module; all are used internally, so this is dead API surface rather than dead code. `checkReceipt` in particular is exercised only as a subprocess (`tests/sprint-close.test.js:56`) | Import-binding scan (`node -e`): the 8 names have no `import {…} from` binding anywhere; internal-use counts `consolidate 6, MODIFIERS 2, escapeHtml 4, clamp 7, distance 9, toolSegments 3`; `grep -rn checkReceipt` → `sprint-close.mjs:20,315` only | Drop the `export` keyword on the six product symbols and the two tooling symbols, or add a test that deliberately consumes them. Do **not** delete the functions | Trivially reversible; zero runtime effect |
| L6-09 | **S3** | root ×7 (`check-build.mjs:7`, `check-docs.mjs:6-9`, `check-project.mjs:6`, `check-scope.mjs:5-8`, `native-smoke.mjs:19`, `sprint-close.mjs:302`, `verify.mjs:7`); `parseArguments` `check-docs.mjs:35-50` vs `check-scope.mjs:93-108`; sha256 helper `check-docs.mjs:148`, `sprint-close.mjs:16`, `verify.mjs:57-60`, `native-smoke.mjs:279-288`; walker `check-docs.mjs:61-71`, `check-project.mjs:39-49`, `native-smoke.mjs:134-143`, `verify.mjs:34-44`; spawn wrapper `verify.mjs:64-70` vs `native-smoke.mjs:41-61`; report write `check-docs.mjs:523`, `native-smoke.mjs:763,782`, `verify.mjs:29-32` | ≈100 lines of copy-paste boilerplate with no shared module (`ls scripts/` → 8 `.mjs` + `new-worktree.sh`, no `lib/`). Each copy is a place a fix can be forgotten | `grep -n 'fileURLToPath(import.meta.url)' scripts/*.mjs` → 7 distinct root computations; `grep -n "function parseArguments" scripts/*.mjs` → 2 near-identical 16-line flag loops; `grep -n 'createHash("sha256")' scripts/*.mjs` → 4 | Extract `scripts/lib/cli.mjs` (root, `--flag value` parsing) and `scripts/lib/digest.mjs` (`sha256Hex`, `walkFiles`) **when a card already touches two of these scripts**, per `CONTRIBUTING.md:65` ("introduce shared code when both entries need the same behavior") | Reversible; tooling-only, no behaviour change if the helpers are pure |
| L6-10 | **S3** | (a) `docs/project/AI-WORKFLOW.md:21` vs `ORCHESTRATOR.md:17`; (b) `AGENTS.md:11` vs `.claude/agents/*.md:4`; (c) `.agents/skills/scrapkeep-task/SKILL.md:33` vs `.claude/agents/scrapkeep-explorer.md:6`; (d) `.codex/environments/environment.toml:1` vs `TRACKING.md:271` (EV-0023) and commit `7317431` | Four internal coherence defects in the agent/host config: **(a)** "four effort tiers" is enumerated while `ORCHESTRATOR.md:17` reserves a fifth (`max`) that **no** `.claude/agents/*.md` defines, so it cannot be dispatched; **(b)** "Claude uses configured Fable roles" — `claude-fable-5-1` is a model, not a role; the roles are the six `scrapkeep-*` files, and no `fable*` definition exists; **(c)** the skill tells the coordinator to "ask each agent to report" `CLAUDE_EFFORT`, but the three read-only agents carry no `Bash` tool, so only writers can run `env \| grep CLAUDE_EFFORT`; **(d)** the tracked Codex environment file says "THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY" while an event row assigns it as a writer's file and a commit edited it | `for f in .claude/agents/*.md; do sed -n '1,7p' "$f"; done` → efforts `high, xhigh, medium, low, high, medium` (no `max`); `grep -rniI 'fable' .claude .codex .agents AGENTS.md CLAUDE.md` → only model strings; `grep -rn 'isolation' .claude/` → none (deliberate, documented at `ORCHESTRATOR.md:17`); `cat -n .codex/environments/environment.toml` → 6 lines, autogenerated header; `git log -- .codex/environments/environment.toml` → `7317431` (PS-02) | One wording pass: (a) either define a `max` agent definition or delete the reservation; (b) say "Fable model at four effort tiers"; (c) either grant the read-only agents a reporting path or state that effort is reported by writers and the coordinator only; (d) add an explicit exception line to the autogenerated header's owner process, or remove the file from writer write sets. No behaviour change | Reversible, documentation/config only. Note the pstack verifier drift (`~/.config/pstack/verify.py:28,183-184` rejects `low`/`medium`; `:253-255` requires `isolation: worktree`) is **already documented** at `docs/project/AI-WORKFLOW.md:42` as Andrew's shared-setup change — do not re-open it as a new finding |
| L6-11 | **S3** | `native/integration/smoke.gd.uid` (tracked) vs the other 15 `.gd` files; `.gitignore:16-20`; `scripts/native-smoke.mjs:139-140,685-687` | One `.uid` is tracked while its 15 siblings have none, and `*.uid` is not ignored, so the tree's convention is undefined. The smoke runner performs a real editor import (`--editor --import`, `scripts/native-smoke.mjs:546-550`) and its file walks filter `.godot` and `.import` but not `.uid`, so a future import that emits the missing UIDs would leave `native/` dirty after every run | `git ls-files native/ \| grep -c 'uid$'` → `1`; `find native -name '*.gd' \| wc -l` → `16`; `find native -name '*.gd.uid' \| wc -l` → `1`; `git check-ignore -v native/integration/smoke.gd.uid` → not ignored; `grep -n 'X' .gitignore`-equivalent → no `*.uid` rule | Decide once: either add `native/**/*.gd.uid` to `.gitignore` and untrack the single file, or commit all generated UIDs and add a `.uid` note to `native/README.md`, and align `scripts/native-smoke.mjs`'s copy filter with the decision | Reversible; the untracked-file question is answerable only after an import run (see §3.4) |
| L6-12 | **S3** | `scripts/check-scope.mjs:43`; `package.json:6-28`; `CONTRIBUTING.md:40` | `check:scope` prints `npm run check:godot (reserved name, currently unavailable until the engineering handoff)` as a **required command** for native changes, but no such script exists in `package.json`, so the printed requirement is not runnable. It is honest about being reserved, and `tests/fixtures/check-scope/cases.json` asserts only the substring, so the test cannot notice the difference | `node -e 'const p=require("./package.json");console.log(Object.keys(p.scripts).includes("check:godot"))'` → `false`; `sed -n '42,45p' scripts/check-scope.mjs` → the reserved-command text; `CONTRIBUTING.md:40` → "Reserved name … no script exists yet" | Either add a stub `check:godot` that exits 2 with "unavailable until the engineering handoff" (making every printed command executable and keeping the reserved name honest), or keep as-is and note in the CONTRIBUTING row that the selector can print an unavailable command | Reversible |
| L6-13 | **S4** | `package.json:18,25` (`test:balance`, `probe:balance` → `tests/balance.mjs`) | Two npm entry points run the same 61-line probe file and **nothing executes either one**: no caller in `scripts/verify.mjs`, `.github/`, or any other script; the only reference is the prose table at `CONTRIBUTING.md:44`. They are documented manual probes, so this is weight rather than breakage — but `probe:balance` is the live name and `test:balance` the alias, and neither is reachable from any automated path | `grep -rn "probe:balance\|test:balance" --include='*.md' --include='*.json' .` (excluding node_modules/artifacts) → `CONTRIBUTING.md:44`, `package.json:18,25` only; `grep -n "balance" scripts/verify.mjs` → no match | Keep as documented manual probes, or fold the alias away and leave one name; if the probe is meant to inform balance decisions, give it a card and a recorded run rather than an unreferenced script | Reversible; removing the alias is a one-line change plus a `CONTRIBUTING.md:44` edit |
| L6-14 | **S4** | `public/art/*.png` (8 files, 22 MB) → `dist/art/` (22 MB) | 22 MB of tracked concept art is copied verbatim into every production build although no game code, HTML or CSS references it; the only consumers are `docs/**` links. Two pairs are superseded drafts (`05-pruner-family-study.png`/`-v2` and `06-orchard-combat-storyboard.png`/`-v2`, ≈5.9 MB), and `public/` is the one place that guarantees shipping | `ls -la public/art` → 8 PNGs, 2,064,675-3,399,947 bytes each; `du -sh dist/art` → `22M`; `du -sh public` → `22M`; `grep -rn "art/0\|/art/" --include='*.js' --include='*.html' --include='*.css' src server index.html orchard.html tests scripts` → **no matches**; `grep -rln "public/art/" --include='*.md' .` → docs only | Move the concept art out of `public/` (e.g. `docs/art/`) and update the Markdown links, or record explicitly why it must ship; delete or clearly mark the two superseded drafts | Reversible via git; the move is mechanical but touches many doc links (lane 4 owns link churn) |

---

## 3. Uncertain / needs owner decision

### 3.1 The TRACKING text-corruption question — verdict

**It is not a script's string templating. It is the coordinator/agent text-writing path.** Evidence, in order of strength:

1. **No code in the repository writes a canonical record.** `grep -rn "TRACKING\|BACKLOG" scripts/` returns
   reads and path classification only (`check-project.mjs:14`; `check-docs.mjs:245,337,391-392,403,410,436`).
   All five `writeFile` sites in `scripts/` target `artifacts/local/**` (`verify.mjs:29,71`,
   `check-docs.mjs:523`, `native-smoke.mjs:763,782`). A repo-wide search including Python, shell, YAML and TOML
   for a write or append to `TRACKING.md`/`BACKLOG.md` returns **no matches**. There is therefore no code path
   that *could* join text with a count.
2. **The corruption is a removed separator, at arbitrary positions.** `hexdump -C` proves the byte is absent
   (`6e 65 72 2c 38` = `ner,8`), with no zero-width or non-ASCII character on the line. A template join bug
   produces corruption at *fixed* positions inside one template and would hit every row built from that
   template; here the losses land mid-sentence and vary (`owner,8`, `and5`, `revision2`, `npmci`,
   `temporarydirectoryremoved`, `at3f56a82`, `original100`, `seven-state,16-edge`), across many templates.
3. **The corruption is not confined to TRACKING and not confined to one file type.**
   `artifacts/foundation-sprint-2026-09/tasks/HF-04a/assignment.md:10` and
   `artifacts/foundation-sprint-2026-09/amendments/AM-FF-001/request.md:7,11` show the same signature, and
   nothing in `scripts/`, `tools/` or `server/` writes those paths either.
4. **Prevalence follows authoring volume, not tooling:** TRACKING 278 suspect tokens, `BACKLOG.md` 2,
   `ORCHESTRATOR.md`/`BIBLE.md`/`CONTRIBUTING.md`/`AGENTS.md` 0. TRACKING is the file with by far the most
   coordinator-generated prose.
5. **The same uncommitted diff that carries the corruption also carries `IN_REVIEW`** (L6-01), a token no
   script in the repo can emit: `scripts/sprint-close.mjs:13` enumerates the state vocabulary in lowercase.
   A writer that ignores the vocabulary it is checked against is being authored, not templated.
6. **Corroboration that no characters are lost:** `artifacts/local/audit-2026-09-10/preserved/PRESERVED.md:17-19`
   matched the corrupt-looking token `sha7eb7ad2c…` to the parked candidate byte-for-byte, so only whitespace
   is missing.

**Inference, labelled as inference:** the defect is in how the coordinator agent's generated prose is
materialised — a model-output/prompt-side habit (possibly compounded by a host-harness text transform I cannot
inspect, because the harness lives outside this repository). The repository cannot fix it with a code change;
the actionable parts are (a) correct the prose on the rows being admitted, (b) decide whether a whitespace lint
is worth adding to `check-docs`, and (c) if a host transform is suspected, investigate the host harness —
which is /home/andrew's setup, not this project's code. **Owner: Andrew + coordinator.**

### 3.2 The true state of HF-04a

`TRACKING.md:119` says `IN_REVIEW`; the HF-04a-A1 block at `TRACKING.md:536-546` says "Review: fresh
ff-hf04a-review pending" and records a candidate `72178cf5…` with a lease that is "closed, writer stopped".
`review` is the vocabulary member that matches a worker handoff with review pending (`TRACKING.md:57`), so the
row is most likely meant to read `review`. **Owner: coordinator** (only the coordinator writes canonical
records, `AGENTS.md:11`). Do not let a writer card guess this value.

### 3.3 Whether the orchard QA bridge should ship (D05 / Q-E08)

`docs/project/DECISION-REGISTER.md:23` recommends option (a) — gate both entries on `import.meta.env.DEV` —
and is still **Open**; `BACKLOG.md:2716` records the same question. The historical row is frozen
(`docs/project/BACKLOG.md:14`, T02) and root `BACKLOG.md` has no T02, so the live tracking is `Q-E08`.
Because `CONTRIBUTING.md:58` documents production `/orchard.html?qa` as a supported verification path, gating it
also changes how the orchard is verified. **Owner: Andrew** (packaging/distribution decision). If the answer is
(b) keep it, the mitigation is to make the exposure explicit in the release notes and keep the production
assertion covering both entries.

### 3.4 Unverifiable-here items that need a decision or a run

* Whether Godot 4.7.2 emits `.gd.uid` for the 15 scripts that lack one (L6-11). One import run answers it; this
  lane may not run the engine.
* Whether the native networking grep would actually hit anything once widened (L6-07) — the answer may require a
  triage, not just a patch.
* `npm run test:leads`, `npm run test:browser`, `npm run test:leads:browser`, `npm run test:agent` and every
  browser/Godot command were out of scope, so their runtime status is unknown. Only `npm test` and the
  `check:*` trio were executed.
* `~/.config/pstack/verify.py`'s current exit code was not executed; its staleness is documented at
  `docs/project/AI-WORKFLOW.md:42` and that documentation matches the file's static content
  (`:28,183-184,253-255`).
* Whether to keep the project's stricter "Astra-only" Codex rule or adopt the host map's 2026-09-07 mixed-model
  authorization (`~/.config/pstack/models/codex.md:3-4`). The host map explicitly defers to a project's stricter
  rule, so nothing is broken; the wording is the only defect found (L6-10b).

---

## 4. Recommended atomic task cards

Constraints honoured: no dependency upgrades, no engine migration, no new game features (`AGENTS.md:9`);
canonical-record edits stay with the coordinator (`AGENTS.md:11`); browser-proof code changes must run
`npm run verify` (`AGENTS.md:10`); no card below claims native or browser evidence it cannot produce.

**Card L6-A — Validate the TRACKING task-state cell (size S)**
* Files: `scripts/check-docs.mjs`, `tests/check-docs.test.js`, new fixture
  `tests/fixtures/check-docs/invalid-state/TRACKING.md`, `CONTRIBUTING.md` (the `check:docs` row).
* Change: in `checkTracking`, validate the state cell (`row.cells[2]` of the Task state index) against the
  legend vocabulary read from `TRACKING.md`'s `| state |` row (`TRACKING.md:30`), emitting a `failure` with the
  row's line number. Add a fixture whose state cell is `IN_REVIEW` and expect exit 1 with that failure.
* Observable acceptance: `npm test` → exit 0 and the new case present; `npm run check:docs` → exit 0 **after**
  the coordinator corrects `TRACKING.md:119`.
* Verification method: run `npm test` (187 + new) and `npm run check:docs` on the real board; confirm the
  fixture-driven failure line names the new fixture file and line.
* Ordering constraint: this card must not be integrated before the coordinator's row correction, otherwise
  `check:docs` fails on `main`.

**Card L6-B — Gate the orchard QA bridge and extend the production assertion (size M)**
* Files: `src/orchard/main.js`, `tests/lead-browser.mjs` (or `tests/browser.mjs`), `docs/project/DECISION-REGISTER.md`
  (D05 status — owner-only edit), `CONTRIBUTING.md` (orchard QA row).
* Change: gate the `window.__orchard` block and the runner import at `src/orchard/main.js:783-812` on a
  build-time condition following D05 option (a) (mirroring `src/main.js:674`), and extend the production
  no-QA assertion so it covers `/orchard.html` as well as `/`.
* Observable acceptance: `npm run verify` → exit 0; after `npm run build`,
  `ls dist/assets | grep -c orchard-browser-runner` → `0` (currently `1`).
* Verification method: `npm run verify` (its built-entry stage starts a temporary static server and checks both
  entries), plus the explicit `dist/assets` chunk count; browser replay of `/orchard.html?qa` under the dev
  server is the applicable browser check in `CONTRIBUTING.md:58`.
* Not this card: choosing the D05 option. That is Andrew's decision; this card implements the chosen one.

**Card L6-C — One static-path implementation for the production server and the built-entry check (size M)**
* Files: `scripts/check-build.mjs`, `server/index.js`, new `scripts/lib/static-paths.mjs` (or equivalent),
  `tests/` (`node --test` coverage for the shared predicate).
* Change: move `isWithin` and the decode → reject → resolve → realpath → stat sequence into one module used by
  both; keep the production-only data-directory exclusion as an explicit parameter so `check-build` cannot
  silently omit it again.
* Observable acceptance: `npm run verify` → exit 0 (includes `check:build`); `grep -c "function isWithin" server/index.js scripts/check-build.mjs`
  → `0 0` with exactly one definition in the shared module.
* Verification method: `npm run verify`, whose stages already include the production build and the built-HTTP
  checks; confirm the 404 assertions for `/.git/HEAD`, `/../package.json`, `/%2e%2e/package.json` still pass.

**Card L6-D — Make the asserted expedition gate patrol the game's path (size S)**
* Files: `tests/expedition-balance.mjs`, `CONTRIBUTING.md` (if the probe's meaning changes).
* Change: derive the patrol route from the exported `PATH` (`src/game.js:2-23`) instead of the hard-coded
  18-point array at `tests/expedition-balance.mjs:12-31`, or add a comment stating why the probe route is
  deliberately independent and record the reason. Un-export `simulate` if nothing consumes it.
* Observable acceptance: `npm run test:expedition` → exit 0 with the four existing assertions
  (`idle ⇒ gameover`, `patrol ⇒ victory`, `risk` yields both outcomes) still holding, and the run JSON's route
  provenance visible.
* Verification method: run `npm run test:expedition` before and after and diff the outcomes; this is a
  deterministic simulation, so the comparison is exact.

**Card L6-E — Widen the native networking check to the whole tree (size S)**
* Files: `scripts/native-smoke.mjs`, `tests/native-smoke.test.js`, `native/README.md` (coverage sentence).
* Change: scan every text file under `native/` except `.godot`/`.import` caches, and add `MultiplayerPeer`,
  `WebRTC`, `SceneMultiplayer`, `DTLSServer`, `UPNP` to `networkingClasses`. Add a unit case that names an added
  class and expects the failure text.
* Observable acceptance: `npm test` → exit 0 with the new case; the check's `detail` string reports a scanned
  count equal to the number of tracked native text files (`git ls-files native/ | wc -l` minus non-text
  fixtures is not asserted, so record the observed number in the card's handoff).
* Verification method: `npm test` for the unit case; the widened scan is a pure regex over files, so a
  `node -e` dry run of the filter is sufficient evidence for the card, with `npm run native:smoke` reserved for
  the native handoff (`AGENTS.md:10`).

**Card L6-F — Decide where the concept art lives (size S, owner-gated)**
* Files: `public/art/**`, the `docs/**` Markdown links that reference `public/art/`, `CONTRIBUTING.md`
  ("Keep `node_modules/`, `dist/` … untracked" note) if placement policy is stated.
* Change: move the eight PNGs to a documentation location (e.g. `docs/art/`) and update links, or record the
  decision to keep them shipped; mark or delete the two superseded pairs.
* Observable acceptance: `git ls-files public/art | wc -l` → `0` after the move, `npm run check:docs` → exit 0
  (all links resolve), and a build no longer contains `dist/art` — `test -d dist/art && echo present`.
* Verification method: `npm run check:docs` for the links plus `npm run build` followed by
  `test -d dist/art`; `npm run check:project` also covers the file links.

**Not a card (coordinator work, recorded here for completeness):** correcting `TRACKING.md:119` to the true
state and admitting EV-0090/0091/0092, including fixing the separated-word corruption in those three rows, is
canonical-record writing and belongs to the coordinator alone (`AGENTS.md:11`, `ORCHESTRATOR.md`).

---

## 5. Method and limits

**Method.** Every claim above comes from a read-only command executed in this session, quoted with its output
in §1-§2. The commands were: `npm test`, `npm run check:docs`, `npm run check:project`,
`npm run check:scope -- HEAD~3 HEAD`, `node --check` on all eight `scripts/*.mjs`, `node --version`/`npm --version`,
and read-only `git` queries (`rev-parse`, `status`, `diff`, `ls-files`, `log`, `show`, `check-ignore`),
`grep`/`awk`/`sed`/`find`/`ls`/`wc`/`diff`/`hexdump`/`du`, and inline `node -e` analyses for import graphs,
export reachability, npm-script target existence and duplicate-line measurement. Two read-only subagents
audited the agent/host config plus the native tree, and the test/fixture surface; I re-ran their load-bearing
commands myself (the repo-wide canonical-writer grep, the `dist` QA-chunk grep, the `.claude/skills` symlink
listing, the `.uid` counts, the fixture-usage counts, the import-resolution check, and the host model map), and
where a subagent's conclusion was too strong I corrected it in place — notably the Codex "Astra-only"
claim, which the host map itself sanctions at `~/.config/pstack/models/codex.md:4`, and the pstack verifier
drift, which `docs/project/AI-WORKFLOW.md:42` already documents.

**Side effects.** Running the permitted `npm run check:docs` rewrote its own report at
`artifacts/local/check-docs/report.json` (gitignored, and the behaviour `CONTRIBUTING.md:36` documents). No
tracked file changed: `git status --porcelain` before and after this lane is identical
(` M TRACKING.md`, `?? artifacts/foundation-sprint-2026-09/tasks/HF-04a/attempt-1/`). This report is the only
file this lane created.

**Limits.**

* No runtime evidence: `npm run verify`, `npm run build`, `npm run native:smoke`, every `npm run test:*`,
  browser/Playwright runs, installs and all network/Godot commands were out of scope. Claims about the built
  bundle come from inspecting the existing `dist/` artifact, which may predate HEAD.
* The native tree was assessed statically (file inventory, `project.godot`, presets, runner sources). Whether
  the pinned Godot 4.7.2 boots any of it is asserted by `native:smoke` and was not re-run.
* The agent/host analysis reads `/home/andrew/.config/pstack/**` and `/home/andrew/.codex/agents/*.toml`, which
  are outside the repository and not version-pinned by it; they can change without a commit here.
* `check:docs`'s state-column gap (L6-01) is proven by reading `checkTracking`'s cell indices and by the
  passing 0-failure run against a board that violates its own legend. What the checker *should* validate beyond
  the vocabulary (allowed transitions, revision monotonicity) was not examined.
* The TRACKING corruption verdict in §3.1 is bounded by what this repository can show. I proved no repo code
  writes canonical records and that the defect's signature is incompatible with a fixed template. I cannot
  inspect the host harness that materialises the coordinator's prose, so "a host-side transform exists" remains
  an unverified hypothesis, not a finding.
* Severity is assigned by blast radius against the rubric given (S1 authority/trust, S2 maintenance hazard,
  S3 cosmetic, S4 disk weight). L6-01 is the only S1: a canonical board that contradicts its own legend while
  the check that guards it reports 0 failures. L6-02 would become S1 if either browser proof is distributed
  before D05 is decided.
