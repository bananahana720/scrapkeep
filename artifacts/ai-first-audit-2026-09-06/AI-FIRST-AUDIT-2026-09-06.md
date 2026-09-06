# AI-Firstify Assessment Report

**Project:** Scrapkeep (`bananahana720/scrapkeep`, private), HEAD `c5e61d3` on `main`, clean tree
**Date:** 2026-09-06
**Mode:** Audit (read-only)
**Focus:** the pre-Sprint 0 "prepare stage" (repo scaffold, CI, test harness, one executable hello-world per accepted TADR) against the repository's proposed documentation-only foundation sprint HF-01..HF-10.

**How this was produced.** Coordinator: Claude Fable 5.1, configured xhigh in `.claude/settings.json`; actual effort unconfirmed and possibly lower (see "Model and effort" in the last section). Ten read-only auditors ran in parallel on the project's `scrapkeep-explorer` definition (`claude-fable-5-1`, declared effort high, tools Read/Grep/Glob, no shell). That ten-way fan-out exceeds the three-delegate ceiling in `ORCHESTRATOR.md:34`; Andrew explicitly allowed a wider read-only fan-out for this audit because no auditor holds a write lease, and the ceiling is still applied to the HF sprint in Part 2. The coordinator ran every executable check up front and handed workers five receipts (`receipts/rubric.txt`, `scaffold.txt`, `board.txt`, `docs-godot.txt`, `ci-facts.txt`). One `scrapkeep-reviewer` (declared xhigh) then reviewed this assembled report; its adjustments and their dispositions are recorded in the last section. No tracked file was modified, no engine was installed or executed, nothing was published, no board event was written. Every finding is evidence level 2 (source review of the actual checkout plus coordinator-executed receipts). Every `path:line` below was cited by a worker against HEAD `c5e61d3`.

---

## The keystone finding

Andrew's prepare stage and the repository's proposed first sprint are two different things, and the repository currently contains neither.

- **What the repo proposes.** HF-01..HF-10 (`BACKLOG.md:33-52`, cards at `:155-460`) are ten documentation contracts. Every card ends with "No engine behavior or executable test is established by this card" (`BACKLOG.md:181, 211, 240, 270, 299, 329, 359, 388, 419, 460`). A grep of BACKLOG.md for `hello world`, `scaffold`, `CI`, `test harness`, `smoke test`, `project.godot`, `headless` returns nothing (`receipts/board.txt`).
- **What is on the machine.** Godot is absent from PATH, flatpak, mise, pacman and `~/.local/share/godot` (`receipts/scaffold.txt:55-61`). No `.github/`, no tracked YAML, zero workflows on the remote (`scaffold.txt:82-91`). `docs/tech/`, the output directory every HF card writes to, does not exist (`scaffold.txt:314-315`).
- **What the harness certifies.** `scripts/verify.mjs` runs six fixed stages for the two Three.js browser proofs and hashes only `src/`, `server/`, `scripts/`, `tests/` and five config files (`verify.mjs:12-19, 46-60`). It hashes no Markdown and can certify nothing about a Godot artifact.
- **The unowned prerequisite.** TADR-001 says "Pin the editor and matching export templates before the first authorized implementation" (`adr/TADR-001-engine-language-platforms.md:25`). No HF card owns that pin; it first appears as an input to TH-25 (`BACKLOG.md:1325`) and TH-29 (`:1464`), far downstream.
- **The only live gate.** Every HF card lists "Blocking questions: None". The sprint waits solely on Andrew's go/no-go (`TRACKING.md:13`), and native build authorization is recorded as none (`TRACKING.md:14`).

The HF sprint is a coherent contract stage that produces the test plans a harness would later execute. It is not a prepare stage. Part 2 audits both and proposes the missing executable stage as nine draft cards that pair with the HF cards rather than replace them.

---

## Overall Score

| Dimension | Score | Summary |
|-----------|-------|---------|
| 1. Project Structure | YELLOW | Mechanical criteria met (3-line CLAUDE.md, gitignore, 29 commits in 7 days), but authority is duplicated by name, a stale project name sits in live config, and the project's own structure check skips the root authority files. |
| 2. Agent Architecture | GREEN | No LLM calls in app code; three pinned sub-agent definitions with restricted tools; the native playtest runner is deterministic tooling, not an embedded agent. Explorer and reviewer bodies are identical, which weakens review independence. |
| 3. Skill Usage | YELLOW | Three narrow skills exist and route correctly, but they are unordered rule prose with zero numbered steps and no `references/` or `scripts/`. |
| 4. Scope & Complexity | YELLOW | Four runtimes plus a planned fifth in one repo; each is ADR-fenced, but the legacy lead-capture server sits on the live verification path and four duplicate copies of the playtest runner are tracked. |
| 5. Context Hygiene | YELLOW | Auto-loaded surface is 16 lines and disclosure works for three hops, then instructs a full read of a 478 KB Bible whose appendix repeats Section 7 thirty times. |
| 6. Safety | YELLOW | No credentials, sensitive paths excluded at git and dev-server layers, every external action so far had recorded human authorization. Scored one notch down from the worker's borderline GREEN on the reviewer's reading of the rubric: `.gitignore` misses some sensitive patterns, gates are prose rather than mechanism, and the playtest runner drives real input through an unpinned external controller. |
| 7. Workflow Design | YELLOW | Independent review is real and exercised; git discipline is strong; but validation covers less than ORCHESTRATOR promises for the queued sprint (no anchor, board or card checks) and skills are not step-by-step. |

---

## Priority Recommendations

Effort estimates are for one person or one authorized writer, documentation unless stated.

1. **[HIGH]** Create the executable prepare stage: record a new TRACKING authorization row for a pinned Godot 4.7.2 install and a `native/` root, then import the draft cards S0-01, S0-04..S0-08 (Part 2.5) paired beside their HF cards. Without this, HF-01, HF-03, HF-04 and HF-05 will assert engine-layout and runtime facts nobody has observed. Effort: one Andrew decision plus one coordinator definition-change event; each proof card is S or M.
2. **[HIGH]** Fix the receipts contradiction before any HF card is dispatched. `BACKLOG.md:27` sends receipts to `artifacts/local/tasks/ID/`, which `.gitignore:7` ignores and `artifacts/README.md:6` calls disposable, while `ORCHESTRATOR.md:85, 98` require evidence tied to the candidate manifest. HF-10's "reproduce their paper scenarios" (`BACKLOG.md:457`) will have nothing to reproduce. Effort: 30 minutes (amendment text in Part 2.2).
3. **[HIGH]** Add `scripts/check-docs.mjs` (draft card S0-02): local links **and anchors** across root canon, `adr/` and `docs/`; BACKLOG card field completeness; TRACKING event-sequence monotonicity; required headings for `docs/tech/sections/*`. Today `check-project.mjs:66-67, 92` discards anchors and `:50-56` never scans `BACKLOG.md`, `TRACKING.md`, `ORCHESTRATOR.md` or `BIBLE.md`. The PUB-01 anchor check was ad hoc and not preserved (`artifacts/publication-2026-09-06/document-checks.json:2-5`; `scripts/` has four files). Effort: half a day, tooling code.
4. **[HIGH]** Right-size the HF cards before go: split HF-03 (module table vs dependency graph and walkthroughs), HF-04 (lifecycle vs patterns and sketches), HF-06 (Content inventory vs Persistence projection mapping) and HF-07 (envelope vs commit boundaries); move HF-10's output out of `docs/tech/sections/` because reviewers are read-only (`ORCHESTRATOR.md:31, 92`). Relocating HF-10's output changes a listed source input in twelve TH cards (`BACKLOG.md:566, 597, 628, 659, 690, 721, 753, 785, 817, 848` and two more), so those need a definition-change event too. Effort: 2-3 hours of card editing.
5. **[HIGH]** Section-scope the "read the Bible" instructions and collapse BIBLE.md Appendix A. `docs/project/README.md:3`, `ORCHESTRATOR.md:7` and `BACKLOG.md:25` tell every worker to read about 830 KB before starting; Appendix A (`BIBLE.md:904-3751`) inlines thirty prompts already stored at `docs/bible/prompts/*.txt`, producing thirty duplicate `## 7. Art Direction` headings. Collapsing needs Andrew's OK (approved document) and an update to the check described at `COHESION_REPORT.md:94`. Effort: 3-5 hours.
6. **[HIGH]** Give `scrapkeep-reviewer.md` its own body. It is byte-identical to the explorer (`scaffold.txt:233-235`); the only review criteria live in `ORCHESTRATOR.md:90`. Add the criteria, the verdict scale, "do not read the writer's brief", and "label which claims rest on coordinator receipts because you cannot run commands". This edits a project agent definition under `.claude/`, which is Claude Code configuration; the pstack preference to leave that alone unless requested applies, so it needs Andrew's ask. Effort: 30 minutes.
7. **[HIGH]** Add numbered procedures to `scrapkeep-task` and `scrapkeep-verify` (authorization check, admission checklist, packet, lease, dispatch, handoff verify, reviewer, serial integrate, done event), each step linking an ORCHESTRATOR or TRACKING anchor. Zero numbered steps today (`rubric.txt:160-163`). Effort: 1-2 hours.
8. **[HIGH]** Register non-blocking questions on HF-06, HF-07 and HF-09 before go. The cards say "Blocking questions: None" (`BACKLOG.md:314, 344, 404`) while the question index says Q-E09 affects HF-07 (`:2122`) and Q-E05 affects HF-09 (`:2066`). Add a "Registered non-blocking questions" field and require the contract to hold under every candidate answer; otherwise HF-10's review of those rows is vacuous. Effort: 30 minutes.
9. **[MEDIUM]** Decouple `scripts/check-build.mjs` (it constructs `createLeadServer` at `:5, 10-13` and uses the resulting origin at `:20, 25, 49, 63`) from the lead-capture server with a minimal static server, then quarantine `server/`, `tests/leads.test.js` and the lead form from the default verify and test paths. Medium because nothing in the prepare stage depends on it, the server is loopback-only, and it is a code change requiring Andrew's authorization under the AGENTS.md preservation rule. Effort: half a day.
10. **[MEDIUM]** Adopt the CI baseline "local-only gate now, hosted CI parked" with the four-stage path in Part 2.4. Effort: none beyond S0-02/S0-03.
11. **[MEDIUM]** Split BACKLOG.md's source dispositions and inventory (`:2714-3255`) into `docs/project/SOURCE-DISPOSITIONS.md` with a pointer; keep the card catalogue intact. `ORCHESTRATOR.md:7` and `docs/project/README.md:25` both assign source dispositions to BACKLOG, so both need a one-line amendment in the same change. Effort: 2-3 hours.
12. **[MEDIUM]** Clear stale names, dead references and machine-bound links: regenerate `.codex/environments/environment.toml` (it is autogenerated, `scaffold.txt:187`, and still says `test-game-2`); fix `docs/project/AI-WORKFLOW.md:30` (path to a different repo) and `:37` (gitignored receipt); replace the absolute `/home/andrew/...` links in the six files listed under Dimension 1 with repository-relative links or plain text; add historical banners on `docs/BUILD.md`, `docs/VERIFICATION.md`, `docs/RETENTION-*.md`, `docs/FIRST-BUILD-PLAYGUIDE.md`; correct `docs/DESIGN-INDEX.md:13, 67` and `docs/DISCOVERY.md:61`. Effort: 2-3 hours.
13. **[MEDIUM]** Add `scripts/new-worktree.sh <task-id> <base-sha>` that creates the worktree at the accepted revision and exits nonzero if HEAD differs; the last swarm's base-branch failure (`docs/PLANNING-PREP-SWARM.md:7`) was encoded only as prose. Effort: 1 hour.
14. **[MEDIUM]** Pin the playtest controller: expected-hash manifest for `agent-desktop/*.py`, fail on mismatch without an override flag (`run.py:326-328, 375-377` compare start-vs-end only), stop calling underscore-private functions (`desktop.py:41-44, 62, 75`), drop `detached: true` in `scripts/agent-playtest.mjs:17-20` or document it. Effort: 2-4 hours.
15. **[MEDIUM]** Replace the four tracked copies of `tools/agent-player` under `artifacts/agent-recovery-2026-09-06/*/implementation/` with hash manifests plus diffs. `artifacts/README.md:5` already supplies the general retention rationale for named records, so the question is whether full source copies are needed as evidence; deletion is Andrew's call under the AGENTS.md rule to preserve historical evidence. Effort: 1-2 hours.
16. **[MEDIUM]** Make approval gates mechanical for Claude sessions: `permissions.deny`/`ask` for `git push*`, `gh repo*`, `gh api*`, `npm publish`, `npm install*` in `.claude/settings.json`, and consider force-push and branch-deletion protection on `main` (not required status checks, which would sit outside the coordinator's admission role; see 2.4). Both need Andrew's explicit ask (pstack preference: leave Claude Code configuration alone unless requested; branch settings are an external action). Effort: under 1 hour.
17. **[LOW]** Harden `.gitignore` with `*.pem`, `*.crt`, `*.key`, `leads.json`, `leads-*.tmp`, `leads.lock` to mirror `vite.config.js:5-16`. Effort: 10 minutes.
18. **[LOW]** Remove the absolute home path from line 8 of all three `SKILL.md` files (the last swarm removed one once, `docs/PLANNING-PREP-SWARM.md:16`). Separately, once Andrew rules on Q-E06 (he is its owner, `TRACKING.md:173`), add a one-line license status statement to README. Effort: 30 minutes.

---

## Detailed Findings

### Dimension 1: Project Structure — YELLOW

Good:
- `CLAUDE.md` is 3 lines importing a 13-line `AGENTS.md` (`rubric.txt:4-11`). `.gitignore` excludes `.env`, `.env.*`, `.private/`, `artifacts/local/`, `node_modules/`, `dist/` (`rubric.txt:14-24`). Only `.env.example` is tracked (`rubric.txt:113`). 29 commits in the last week with action-oriented messages (`rubric.txt:27-49`). Root has 24 entries, well under the rubric's 50.

Needs work:
- Two files named `BACKLOG.md` with opposite roles: root is the live definitions owner; `docs/project/BACKLOG.md:3` is a frozen snapshot with a banner. A grep for BACKLOG hits both, and 30+ disposition rows in the root file link to the historical one by basename (`BACKLOG.md:2724-2750`).
- Two ADR directories, `adr/` (production TADRs) and `docs/adr/` (browser-proof ADRs), cross-linked (`adr/README.md:17`, `docs/adr/README.md:3`) but both labelled "ADRs" in the desk table (`docs/project/README.md:29, 33`).
- `scripts/check-project.mjs:7-19` requires three historical files but not `BIBLE.md`, `BACKLOG.md`, `TRACKING.md`, `ORCHESTRATOR.md` or `adr/README.md`; its link scan (`:50-56`) covers README, AGENTS, CONTRIBUTING, `artifacts/README.md` and `docs/**` only. The canonical authority files are the least validated files in the repository.
- Stale project name in live surfaces: `.codex/environments/environment.toml:3` is `name = "test-game-2"`; `docs/project/AI-WORKFLOW.md:30` gives a verification command with `--project /home/andrew/Projects/test-game-2`.
- `docs/project/AI-WORKFLOW.md:37` points at `artifacts/local/claude-port/REPORT.md`, which is gitignored and absent.
- Six tracked Markdown files link absolute `/home/andrew/...` paths (`docs/adr/0006-agent-playtest-workspaces.md:29`, `tools/agent-player/README.md:11`, `docs/project/AGENT-PLAYTEST-ENGINEERING.md:19, 67, 111-114`, `docs/bible/production/SOURCES.md:7, 13, 17-19`, and two artifact READMEs), and `docs/bible/production/section-06..09.md` reference `/home/andrew/Projects/test-game-2/...`. `scripts/check-project.mjs:70-73` resolves absolute targets as-is, and the old directory still exists on this machine, so `npm run check:project` passes here and would fail on a fresh clone or any CI runner. This is a published-repository hygiene defect and belongs in S0-02's scope.
- Eleven Markdown files at root; `COHESION_REPORT.md:3` and `BIBLE_DECISIONS.md:5` self-describe as dated review artifacts that fit under `docs/bible/`. About 21 loose PNG/JSON/TXT files sit at `artifacts/` top level beside dated directories (`scaffold.txt:317-354`).

### Dimension 2: Agent Architecture — GREEN

Good:
- LLM-library and agent-pattern greps are empty across `*.py`, `*.js`, `*.mjs`, `*.ts` (`rubric.txt:87-91`).
- `tools/agent-player` imports numpy, PIL, stdlib and the installed controller (`desktop.py:23-26`); its README states "No API key or paid service is used" (`tools/agent-player/README.md:11`). It is scripted, non-LLM tooling producing feedback-loop evidence, not an embedded agent; the word "agent" in the path is a grep hazard only. The identical explorer and reviewer bodies noted below are a review-quality defect and are weighted in Dimension 7, not here.
- Three sub-agent definitions pin `claude-fable-5-1` with role effort and tool allowlists; explorer and reviewer omit Bash/Edit/Write; the writer adds `isolation: worktree` (`scaffold.txt:195-231`). `.claude/settings.json` disables model switching and fallbacks (`scaffold.txt:161-170`). No custom orchestration code exists; ORCHESTRATOR.md and TRACKING.md are prose.

Needs work:
- Explorer and reviewer bodies are byte-identical (`scaffold.txt:233-235`). The only review-specific criteria live in `ORCHESTRATOR.md:90` and `:31`. Independence is structural (fresh context, read-only, "did not write the candidate") but the reviewer carries no lens of its own, and the pstack requirement to include the panel paragraph in every reviewer prompt (`/home/andrew/.config/pstack/plugin/skills/poteto-mode/SKILL.md:119`) is left to the coordinator's brief.
- Context load: every agent reads `AGENTS.md` (13 lines), `ORCHESTRATOR.md` (120) and the pstack runtime (~80) before its card; the writer also reads poteto-mode (169 lines) and its principle leaves "in full". Writer baseline is roughly 400 lines before any source file.
- No agent lists the `Skill` tool (`scaffold.txt:201, 213, 225`), so skills are coordinator-only by construction. Each `SKILL.md:8` instructs a `git rev-parse` shell command, so pasting a skill body into a read-only brief creates an impossible instruction.
- `.claude/settings.json` model string `claude-fable-5-1[1m]` differs from the agent frontmatter `claude-fable-5-1`; same family, a context-variant suffix worth confirming against the tool schema.

### Dimension 3: Skill Usage — YELLOW

Good:
- Three narrow skills exist under `.agents/skills/` and are exposed to Claude by relative symlinks resolving to one canonical body (`rubric.txt:167-173`), the design `docs/project/AI-WORKFLOW.md:41` explains.
- Progressive disclosure is achieved by pointing at repository authority documents rather than a `references/` directory (`scrapkeep-task/SKILL.md:8-10`, `scrapkeep-verify/SKILL.md:10`), a defensible substitute since the coordinator owns those files.
- `scrapkeep-verify` carries the one prescriptive element, an artifact-to-method table (`SKILL.md:12-17`).

Needs work:
- Zero numbered steps in all three files (`rubric.txt:160-163`). `scrapkeep-task` has about 24 imperatives with no order, mixing authorization, dispatch, verification and admission: the "single monolithic prompt" shape even though every rule is sound.
- No `references/` or `scripts/` anywhere under the skills (`rubric.txt:165-166`); the repository's `scripts/` are reachable only via CONTRIBUTING.
- Unwritten mechanics a memory-less coordinator must invent: the attempt/lease ID convention (only the `PUB-01-A1`/`PUB-01-L1` example at `TRACKING.md:88`), the exact worktree-at-accepted-revision commands (`scrapkeep-task/SKILL.md:17` says do it; `docs/PLANNING-PREP-SWARM.md:7` records it was done by hand), what "verify actual runtime metadata" means concretely, and the "document structure, local links/anchors, schema/contract coverage" procedure at `ORCHESTRATOR.md:104`, which has no command. Evidence of drift: blank lines at `TRACKING.md:234-238` split the append-only events table into three Markdown tables.
- All three `SKILL.md` files hardcode `/home/andrew/.config/pstack/runtime.md` at line 8 in a now-published repository.

### Dimension 4: Scope & Complexity — YELLOW

Good:
- No framework, database, auth or CI: dependencies are three.js and three fontsource packages (`scaffold.txt:35-44`); heavy-dependency grep is empty (`rubric.txt:175-176`).
- Scope is bounded by recorded decisions: two browser entries (`docs/adr/0001-two-playable-entries.md:7-11`); lead capture declared "preserved history, not a production-game dependency" (`adr/TADR-005-networking-scope.md:27`); the agent player accepted in `docs/adr/0006-agent-playtest-workspaces.md:21`.

Needs work:
- The lead server is load-bearing for the live verify path: `scripts/check-build.mjs:5, 10-13` imports and constructs `createLeadServer` as the static server for the `built-http` stage, and `:20, 25, 49, 63` use the resulting origin. Quarantining `server/` today would break `npm run verify`.
- Lead capture is a "building for others first" surface: origin allow-list, per-IP rate limit, honeypot, E.164 phone validation and SMS consent text (`server/index.js:135-198`, `server/validation.js:1-8, 70-78`) for a game whose settled direction is offline solo. `tests/leads.test.js` runs inside plain `npm test` via the glob.
- Four full tracked copies of `tools/agent-player` with tests live under `artifacts/agent-recovery-2026-09-06/{candidate-a,candidate-b,extended-live,synthesis-live}/implementation/` (`rubric.txt:94, 119-144`), inflating the 1,218-file tree and polluting grep-based audits.
- Planning mass dominates code: BIBLE.md 3,794 lines and BACKLOG.md 3,255 lines with 58 cards, 50 questions and 458 dispositions (`TRACKING.md:250`) for a native game with no engine installed.

Proposed prepare-stage split (needs Andrew's authorization under the AGENTS.md preservation rule): keep live `src/orchard/`, `orchard.html`, `tests/orchard*`, `tools/agent-player/`, `scripts/*.mjs` (after swapping in a plain static server), and the baseline yard per ADR 0001; freeze `server/`, `docs/LEAD-CAPTURE.md`, `tests/leads.test.js`, `tests/lead-browser.mjs`, the `test:leads:browser` script and the lead-form branch of `src/collection.js:69-304` (which already degrades gracefully).

### Dimension 5: Context Hygiene — YELLOW

Good:
- The chain `CLAUDE.md` (3 lines) to `AGENTS.md` (13) to `docs/project/README.md` (43 lines with a 17-row source-of-truth table at `:19-39`) is genuine progressive disclosure; total auto-loaded project context is 16 lines (`rubric.txt:4-6`).
- BACKLOG.md is well anchored for targeted reads: catalogue `:54-2006` with an H3 anchor per card, questions `:2007-2713`, dispositions `:2714-3187`, inventory `:3188-3255`.

Needs work:
- The fourth hop says "read", not "consult the section": `docs/project/README.md:3` bolds "Read the Art & Game Bible before any game work"; `ORCHESTRATOR.md:7` says "Read BIBLE.md ... BACKLOG.md ... then TRACKING.md"; `BACKLOG.md:25` says "All workers read BIBLE.md, accepted ADRs, this card, ORCHESTRATOR.md, TRACKING.md and CONTRIBUTING.md". Taken literally, and counting all of BACKLOG.md as "this card", that is roughly 7,700 lines and 830 KB before a worker starts (approximation from `rubric.txt:180-201`). This is the single biggest prepare-stage context hazard.
- BIBLE.md is mostly duplicated appendix. Body is `:1-903`; Appendix A `:904-3751` embeds all thirty submitted prompts inline in `<details>` blocks (`BIBLE.md:941-947`), each containing Section 7 verbatim, producing thirty duplicate `## 7. Art Direction` headings between `:947` and `:3654` and defeating heading navigation for the real Section 7 at `:616`. The same prompts exist as `docs/bible/prompts/*.txt` and are already linked from the table at `:908-939`. `BACKLOG.md:3194` already excludes "Appendix A repeated prompts" from its inventory.
- The source-of-truth table has no BIBLE row (only the bold sentence at `:3`), two rows labelled "ADRs" (`:29, :33`) and two labelled "verification" (`:31, :34`). The desk carries four status paragraphs (`:5-11`) duplicating TRACKING, and `TRACKING.md:254` gives a different next-session entry point than `docs/project/README.md:17`.
- `docs/` mixes live and historical with uneven labelling. Well labelled: `docs/project/BACKLOG.md:3`, `PLANNING.md:3`, `DECISION-REGISTER.md:3`, `REQUIREMENTS.md:3`. Unlabelled and present-tense: `docs/BUILD.md:1-8`, `docs/VERIFICATION.md:1-8`, `RETENTION-BUILD.md`, `RETENTION-VERIFICATION.md`, `FIRST-BUILD-PLAYGUIDE.md`. `docs/DESIGN-INDEX.md:13` still says the desk owns current status; `:67` treats engine migration as open, contradicting `adr/README.md:11`; `docs/DISCOVERY.md:61` calls the first-build guide "the current implementation".

### Dimension 6: Safety — YELLOW (borderline GREEN)

Good:
- Secrets grep hits are benign: `server/index.js:36-43` rejects configured URLs carrying credentials (a guard); `tools/agent-player/desktop.py:27, 64-67` holds a runtime lease token from the controller that is never persisted. Only `.env.example` is tracked, with non-secret defaults (`scaffold.txt:251-258`).
- Sensitive paths are excluded at two layers: `.gitignore` and `vite.config.js:5-16` (`fs.deny` for `.env`, `*.{crt,pem}`, `.git`, `.private`, `leads.json`, `leads-*.tmp`, `leads.lock`).
- The lead store is careful: directory 0700, snapshot 0600, atomic rename with directory fsync (`server/store.js:7, 106-118`), single-process lock (`:9-19`), storage forced outside `public/` and `dist/` including through symlinks (`server/index.js:125-134`), default bind `127.0.0.1` (`:294`), and "sends no email, text message, webhook, or CRM request" (`docs/LEAD-CAPTURE.md:3`).
- No script pushes, publishes, emails or calls a remote service; grep across `server/ src/ scripts/ tools/ tests/` found only loopback URLs and same-origin fetches. Publication was manual under recorded authorization (`TRACKING.md` EV-0007..0018, `artifacts/publication-2026-09-06/AUTHORIZATION.md:3-12`).

Needs work:
- Gates are documented but enforced by prose. `check-project.mjs:25-36` only asserts package/lockfile parity; the writer agent has Bash (`scaffold.txt:225`); `.claude/settings.json` has no permission deny or ask rules (`scaffold.txt:160-170`); no evidence of hooks or branch protection in the repository; the host `gh` token carries `repo` and `workflow` scopes (`scaffold.txt:72-77`). Nothing but prose stops a Bash-capable agent from `git push`.
- The playtest runner imports the controller from `~/.local/share/codex-native-input/agent-desktop` via `sys.path.insert` (`desktop.py:13-16`), calls underscore-private internals (`desktop.py:41-44, 62, 75`), hashes the controller start-vs-end but never against a pinned expected hash (`run.py:326-328, 375-377`), and `scripts/agent-playtest.mjs:17-20` spawns it detached, so a killed wrapper orphans a process holding real input authority. ADR 0006 and the README are explicit that the nested desktops are not security isolation.
- `.gitignore` misses `*.pem`, `*.crt`, `*.key` and the lead filenames (rubric pattern count 3, `rubric.txt:116`). `LEADS_DATA_DIR` accepts any path and a relative value resolves from cwd (`server/index.js:119-123`).
- No `LICENSE` file; `licenseInfo` is null on the remote (`scaffold.txt:80`). Q-E06 is open with Andrew as owner. Private repo with untracked `node_modules/` and `dist/` means no current violation; OFL and MIT notice obligations attach at distribution.

The worker scored GREEN because the rubric measures presence of controls and no automated external action exists. The reviewer read the `.gitignore` gap as the rubric's YELLOW bullet verbatim (".gitignore exists but may miss some sensitive files") and the Bash-capable writer with no deny rules as weakening "read-only access where possible"; the coordinator adopted YELLOW. Mitigating fact either way: the default lead path `.private/leads` (`scaffold.txt:258`) is already ignored.

### Dimension 7: Workflow Design — YELLOW

Good:
- A fresh read-only reviewer is defined (`ORCHESTRATOR.md:90-92`, `scrapkeep-reviewer.md`) and has been exercised with retained artifacts (`TRACKING.md:228` EV-0005, `:241` EV-0015, `artifacts/publication-2026-09-06/REVIEW.md`). Attempt bound of three and a no-erasure rule (`ORCHESTRATOR.md:92`).
- `verify.mjs` runs six fail-stop stages and hashes sources (`:12-19, 45-59`); `tests/tooling.test.js:19-67` tests the fail-stop contract; `check-build.mjs:42-48` asserts no remote asset.
- Git: 29 commits in 7 days, imperative messages, clean tree, private remote verified per blob (`TRACKING.md:244`). Integration is serial and coordinator-only (`ORCHESTRATOR.md:96-102`, `CONTRIBUTING.md:66`). The serial-integration rule is the CI substitute; it depends entirely on the coordinator running the checks.

Needs work:
- `check-project.mjs` strips anchors (`:66-67`, says so at `:92`) yet TRACKING links 60 cards by anchor (`TRACKING.md:103-161`) and card sources link section anchors (`BACKLOG.md:161-163`). `ORCHESTRATOR.md:104` requires "local links/anchors" for the documentation-only sprint; no committed tool performs the anchor half. `COHESION_REPORT.md:96` mentions an ad hoc anchor check never committed.
- No validator for TRACKING event or record-revision monotonicity or table integrity, though the schema demands them (`TRACKING.md:23, 29, 76`); the broken table at `:234-238` is the defect such a check would catch. No validator for BACKLOG card completeness even though `ORCHESTRATOR.md:39` pins the field set and the cards use a consistent bold-field schema, making a checker cheap.
- `docs/project/AI-WORKFLOW.md:35` claims the pstack verifier "covers project skill structure"; `/home/andrew/.config/pstack/verify.py:117-122` only checks that the three symlinks resolve.
- Reviewers have no Bash, so a reviewer PASS on any executable claim rests on coordinator receipts (`AI-WORKFLOW.md:21`); the reviewer definition does not tell it to label receipt-inherited claims.
- The last swarm's base-branch failure (`docs/PLANNING-PREP-SWARM.md:7`) was encoded as more prose (`scrapkeep-task/SKILL.md:17`, `AI-WORKFLOW.md:25`) rather than a script that refuses a wrong base.

---

# Part 2: Prepare-stage gap audit

## 2.1 What the prepare stage must deliver and what exists

| Prepare item | Exists today | Nearest HF coverage | Gap |
|---|---|---|---|
| Repo scaffold for the native game | No `project.godot`, `.gd`, `.tres`, `.tscn` anywhere; no `native/` root | HF-01 names path families on paper (`BACKLOG.md:171-173`) | HF-01 will guess `res://` root, `.godot/` cache and import sidecar behaviour nobody has observed; downstream cards inherit the guesses. |
| CI | None (`scaffold.txt:82-91`) | None | The bigger gap is local: no committed command checks the canonical root documents or any anchor. |
| Test harness | `npm run verify` for browser proofs only; refuses to run outside npm; six fixed stages including a Vite build (`verify.mjs:9-19`) | None; `ORCHESTRATOR.md:104` forbids running it under a no-build scope | No documentation-only check command, no Godot command, no mechanical scope selector. |
| Hello-world per TADR | None | HF-03/04 (TADR-002), HF-05/06/09 (TADR-003), HF-02/06/07/08/09 (TADR-004), HF-01/02 (TADR-001), HF-10 only (TADR-005), all paper | See 2.3. |
| Toolchain pin (TADR-001:25) | Godot absent | None; first named at TH-25 (`:1325`) and TH-29 (`:1464`) | Unowned prerequisite. |

## 2.2 HF sprint critique (Lane C)

**Verdict.** PASS+NOTES for HF-01, HF-02, HF-05, HF-08, HF-09. FAIL-as-written for HF-03, HF-04 and HF-10 (C1's verdict: size, role and output path). C2 returned "mixed" for HF-06 (L-shaped) and HF-07 (M/L); the coordinator escalates those two to FAIL-as-written on the same size-and-ownership grounds, and that escalation is the coordinator's call, not C2's. The sprint is a sound contract stage with fixable card defects; it delivers the test plans a harness would later execute, not the harness.

**Cross-cutting defects (fix before go):**

1. **Receipts are gitignored.** `BACKLOG.md:27` versus `.gitignore:7`, `artifacts/README.md:6`, `ORCHESTRATOR.md:85, 98`. Amendment: "Work under `artifacts/local/tasks/ID/` (ignored); at handoff copy every receipt the coordinator will cite into `artifacts/foundation-sprint-2026-09/tasks/ID/` and list each file in the candidate manifest."
2. **No output template and no anchor validator.** `BACKLOG.md:27` lists four required content items but no headings; `check-project.mjs:66-67, 92` discards anchors. Amendment to `BACKLOG.md:25`: "Every `docs/tech/sections/` output uses the headings Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits. The coordinator checks those headings and every local `#anchor` on admission."
3. **`docs/tech/` does not exist** (`scaffold.txt:314-315`); HF-01 and HF-02 run in parallel and both create it, while `ORCHESTRATOR.md:43` says directory ownership includes descendants. Leases must be file-level, or the coordinator pre-creates the directory with an index stub.
4. **No Godot documentation references in any card**, although `ORCHESTRATOR.md:64` requires the coordinator to retrieve primary docs before a worker relies on an API.
5. **Verification walkthroughs are not DoD items** (`HF-03:237`, `HF-04:267`, `HF-05:296`); a literal writer may leave them in a disposable receipt, and HF-10 then cannot reproduce them (`:457`).
6. **The coverage-review rule is in the wrong document and unscoped.** `BACKLOG.md:27` ("reviewer report is itself reviewed for coverage by a different reviewer") is an operating rule; `ORCHESTRATOR.md:13` owns operating rules and `:88-92` does not contain it. Read literally it doubles reviewer demand under the three-slot ceiling (`:34`).

**Per-card summary:**

| Card | Size honesty | Source omissions | Key amendment |
|---|---|---|---|
| HF-01 | M if DoD1 and DoD4 are merged | TADR-003 § Decision, CONTRIBUTING § Handoff, `docs/project/ASSETS.md`, ADR 0001, Godot project-organization docs | Add DoD 5: tag every engine-layout fact "unverified until a scaffold proof exists". Keep first, pair with S0-01. |
| HF-02 | S is optimistic; state that unfilled "unmeasured" rows are valid | `docs/FIRST-BUILD-VERIFICATION.md`, `artifacts/performance-stress*.json`, Q-E03/Q-E04 explicitly | DoD3 as a negative check: no numeric value without a `measured:<path>` or `proposed:Q-E03` tag. |
| HF-03 | L; split 03a (module table, ownership) / 03b (dependency graph, walkthroughs) | TADR-003/004 § Decision, ADR 0003, BIBLE § Inventory | DoD3 as an adjacency list a reviewer's cycle check reproduces; walkthroughs into DoD. |
| HF-04 | L; split 04a (lifecycle) / 04b (patterns and sketches) | ADR 0005, HF-02 output, BIBLE § Movement, static-typing doc | Sketches are unparseable without an editor; mark "unparsed; re-verify at scaffold proof" or replace with the S0-04 source link. |
| HF-05 | M honest | TADR-004 § Decision, HF-01 output, `ASSETS.md` | DoD2 as a state table (draft, imported, structurally valid, semantically valid, admitted, rejected-reload, pinned). |
| HF-06 | L; split 06a (Content inventory) / 06b (Persistence projection) or supply a coordinator-generated noun list | TADR-003 § Decision (the eight-family enumeration at `:25`), HF-03 output; DoD spans BIBLE § 3-9 while verification covers § 6 only | Stable row IDs plus a machine-readable copy; nine downstream cards reference "HF-06 matrix rows" by name. |
| HF-07 | M/L; split 07a (envelope, S) / 07b (commit boundaries, M) | Q-P16, Q-E09, D26/D27, BIBLE § Runs and § HUD settings, HF-03 | DoD3 "under every allowed policy" is unbounded until candidate policies are enumerated. |
| HF-08 | M honest, most atomic | TADR-004:32, TADR-001 target OS families, Godot FileAccess docs | Store the interruption matrix as enumerable test-case rows; every stage "unqualified on paper". |
| HF-09 | M honest | Q-E05 itself, TADR-004:42, HF-05 output, the two browser storage files (`src/campaign.js:115`, `src/progress-store.js:45`) | DoD3 must name the browser records it preserves. |
| HF-10 | M acceptable with a 9x5 matrix form | The nine pinned card revisions and nine receipts (gitignored) | Output moves to `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md`; a review is evidence recorded by the coordinator, not a TECH_BIBLE section. |

**Header and schedule.** Waves W1 HF-01+02, W2 HF-03, W3 HF-04+05, W4 HF-06, W5 HF-07, W6 HF-08+09, W7 HF-10 never exceed two writers plus one reviewer (`ORCHESTRATOR.md:34`). Critical path is seven waves (01 to 03 to 05 to 06 to 07 to 08/09 to 10); W2, W4 and W5 idle one writer slot; W1, W3 and W6 queue two candidates through one reviewer slot. HF-10 alone unlocks TH-01..12 (`TRACKING.md:117-128`), so a FAIL on HF-03 boundaries at W7 cascades with no earlier integrated checkpoint. The header's closing claim (`BACKLOG.md:35`, "none needs an unanswered external product value") is true only under the reading "the contract holds under every candidate answer" and contradicts the question index for HF-07 (`:2122`) and HF-09 (`:2066`). Amendments: let one fresh reviewer read a wave's two candidates together; add an integrated read of HF-01..05 before assigning HF-06; add a "Registered non-blocking questions" field.

## 2.3 Per-TADR hello-world matrix (Lane B)

Every proof below is a design. Nothing ran. Godot API claims outside the receipt are marked unverified by the workers and each draft card requires a documentation lookup before writing. B2, B3 and B4 independently recommended the plain `godot --headless --script` runner (a script that `extends SceneTree` and calls `quit()`, `receipts/docs-godot.txt:39-49`) over GUT or gdUnit4: zero dependencies, honours the free-tool rule, and a reviewer can read the entire harness. B1 used the same runner without comparing frameworks. Park gdUnit4 for TH-23-era per-system tests.

| ADR | Minimal executable proof | Harness needed | HF coverage on paper | Real gate | Draft card |
|---|---|---|---|---|---|
| TADR-001 (+ TADR-005 export/offline) | Pinned 4.7.2 install record with digests; `project.godot` in a `native/` root disjoint from both browser entries; headless boot printing an identity and exiting 0; a typed script passes and a deliberately untyped fixture fails under warnings-as-errors; static grep for networking classes finds nothing; boot repeats with network unavailable. Later: Linux and Windows export presets. | `scripts/native-smoke.mjs` as a separate command (never a `verify.mjs` stage: unconditional build stage `:17`, 120 s timeout `:67`); `.gitignore` gains `native/.godot/`; evidence under `artifacts/local/native-smoke/` | HF-01 path families, HF-02 register; the pin is unowned | Engine-install authorization row in TRACKING (distinct from Q-E01); a ratified root path; install source (official binaries with digests recommended) | S0-01, S0-09 |
| TADR-002 (+ TADR-005 pause) | Typed `SessionOwner` and `EncounterCoordinator` where only the physics callback advances a counter; an intruder `_process` and Timer are rejected; pause freezes gameplay while an ALWAYS-mode menu probe still updates; focus loss clears held input and cancels a prepared action; resume manufactures no cast. No accumulator (the browser has two: `src/orchard/main.js:747-760`, `simulation.js:140, 417-421`, exactly what TADR-002:11 says not to inherit). | Plain runner, phases A-E, exit codes 0/1/2/3, fault-injection run must fail | HF-03 module map, HF-04 lifecycle and the "minimal typed GDScript sketch" (`BACKLOG.md:263`), which is never parsed on paper | Engine install; path decision. Q-E01 gates qualification slices, not a scaffold proof; Q-E13 does not apply | S0-04 |
| TADR-003 | `SlotTreeDefinition` Resource with `id: StringName`, `content_revision`, nodes and edges; a `.tres` fixture with a `proof.` ID; a catalogue that refuses the same ID loaded from a renamed copy; the binary-tree admission rule (15 nodes, 14 edges, 8 leaves, two children per nonterminal, acyclic, no reconvergence, `TADR-003:31`, `BIBLE.md:529`) rejecting a malformed fixture with a diagnostic and nonzero exit; `duplicate()` session record mutation leaves the cached definition unchanged; a failed candidate catalogue leaves the current one active. | Plain runner as an admission-time tool | HF-05 identity and admission, HF-06 coverage matrix, whose "authoring codec" column cannot be honest without one proven round-trip (`TADR-003:45`) | Engine install; Q-E01 as above. Content values stay open by construction: the schema has no cost, effect or name fields | S0-05, S0-06 |
| TADR-004 | `SaveOwner` with stage, validate (re-reading the temp bytes), commit (rename), acknowledge, recover, resolve_lifecycle; cases: commit path, JSON round-trip (int/float typing of `generation` may surface here; Godot's JSON number typing is unverified in the receipt), newer-schema rejection without overwrite, interruption fixture with a stale temp (including the ambiguous case: a valid unrenamed newer temp carrying `revival_spent` must block automatic resumption per `TADR-004:40`), lifecycle fixture where an older checkpoint cannot revive a spent revival (`TADR-004:30`). | Plain runner; fixtures committed and copied per run; run dir under `artifacts/local/proofs/tadr-004/` | HF-07 envelope and ordering, HF-08 interruption matrix (whose file-protocol rows are literally directory states and should be fixtures from day one), HF-09 newer-format handling | Engine install. Q-E05 and Q-E09 do not block a proof with placeholder fields that never reads browser storage | S0-07, S0-08 |

What none of these prove, in the ADRs' own words: controller feel or physical-world behaviour (`TADR-001:35`), collision-query correctness (`TADR-002:46`), editor import or hot reload (`TADR-003:33`), or power-loss durability ("Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability", `TADR-004:38`). The Godot receipt exposes `flush()` and `close()` but no fsync, directory sync or lock primitive; durability on each target OS remains a qualification item.

Prior art the proofs must differ from, not port: the browser save code silently replaces a newer version with a fresh default (`src/campaign.js:112-115`) and keeps "the last usable profile" on mismatch (`src/progress-store.js:45-51`) with no migration hook; `server/store.js:103-124` already implements lock, temp, sync, rename and directory sync in Node but acknowledges in memory before the directory sync and has no startup recovery of orphan temps.

## 2.4 CI and harness recommendation (Lane D)

**Recommendation: local-only gate now; hosted CI parked, not rejected.** Two facts decide it. First, the committed docs check does not cover the canonical prepare-stage files at all (`check-project.mjs:7-19, 50-56`), and the anchor check the PUB-01 coordinator actually ran was never preserved as a command (`document-checks.json:2-5`; `scripts/` holds four files). That is a local gap bigger than "no CI". Second, the swarm's admission authority is the coordinator's serial integration (`ORCHESTRATOR.md:21, 96-102`); workers never push (branches are local worktrees merged locally, `docs/PLANNING-PREP-SWARM.md:7, 16`), so PR triggers would never fire. By inference from the sole-writer and sole-done-transition rules (`ORCHESTRATOR.md:21, 102`; the manual does not mention CI), a required status check would become a second admission authority the manual does not provide for.

| Criterion | Local-only | GitHub Actions (private) | Both |
|---|---|---|---|
| Docs | Links, anchors, card and board schema on the exact integrated tree | Same, on pushed commits only | Adds off-machine reproducibility |
| Browser proofs | `npm run verify`, no browser session | Same stages on a clean runner plus a second Node in the declared range (only 26.8.1 checked, `CONTRIBUTING.md:9`); the 120 s stage timeout may trip on a shared runner (unmeasured). Today the `project` stage would fail on any runner because tracked docs link absolute `/home/andrew/...` paths that `check-project.mjs:70-73` resolves as-is (Dimension 1) | Adds the clean-machine signal once the absolute links are fixed |
| Godot hello-worlds | Headless commands after install authorization | Needs a pinned editor download or cache per run; marketplace action support for 4.7.2 unverified | Reproducibility only |
| Exports | Local only; TADR-001:39 wants clean-machine qualification a dev machine cannot supply | The one thing CI does better; gated on Q-E06 anyway | Same |
| Cost | Zero | Free tier, roughly 2,000 Linux minutes per month with Windows at 2x (secondary sources, unverified); marketplace actions are new dependencies under the locked-dependency rule | Both |
| Evidence honesty | Command output already disclaims (`CONTRIBUTING.md:52`) | A green badge invites the over-claim `ORCHESTRATOR.md:106` and `TADR-001:35` warn about | Two signals for one evidence class |
| Swarm failure modes | One: coordinator mis-selects checks | Runs after `done` is recorded; required checks contradict the sole-writer rule; notifications are a live signal outside TRACKING (`TRACKING.md:5`) | All of the middle column |
| Secrets | None | None needed; but the existing `gh` token already carries `workflow` scope (`scaffold.txt:77`), so workflow creation must be an authorized card | None |

Staged path: **stage 0 (now)** `npm run check:docs` (S0-02) and the scope selector with a reserved `check:godot` name (S0-03), `verify.mjs` untouched; **stage 1** after engine-install authorization, `npm run check:godot` as a separate script running the S0 proofs; **stage 2 (parked)** one Linux-only advisory workflow running exactly the same commands, actions pinned by SHA, never a required check, results mirrored into TRACKING by the coordinator; **stage 3** exports, gated on Q-E06 and a distribution decision. Unpark conditions for stage 2: a second contributor or machine, or Andrew wanting an independent reproduction of the docs or Godot checks.

## 2.5 Draft Sprint 0 card set (revision 0, not imported)

Full card bodies in HF format (sources, files touched, definition of done, draft verification, boundary) are in `worker-results/B1-tadr-001-005.md`, `B2-tadr-002-005.md`, `B3-tadr-003.md`, `B4-tadr-004.md` and `D1-ci-harness.md`. Worker-local IDs are consolidated here. Paths under `native/` are provisional until HF-01 ratifies path families; if a proof is authorized first, the coordinator records the interim path in TRACKING as a question answer (`ORCHESTRATOR.md:49, 112`).

| ID | Outcome | Owner / size | Depends on | Blocking item | Pair with |
|---|---|---|---|---|---|
| S0-02 | Add `scripts/check-docs.mjs`: links and anchors across root canon, `adr/`, `docs/`; BACKLOG card completeness; TRACKING sequence monotonicity; required headings for `docs/tech/sections/*`; sha256 manifest of checked Markdown | Tooling / S | None | Coordinator ruling on whether a tooling card may run the build-containing `verify` | Before HF-01 |
| S0-03 | Add `scripts/check-scope.mjs` classifying changed paths into documentation-only, browser-proof, tooling, native or mixed and printing the required commands; reserve `check:godot`; record hosted CI as parked | Verification / S | S0-02 | None | Before HF-01 |
| S0-01 | Pin the Godot 4.7.2 toolchain (install record with digests), `native/project.godot`, typed headless boot smoke, untyped-negative fixture, static networking grep, offline rerun; `scripts/native-smoke.mjs` | Verification (Conventions co-signs path) / M | HF-01 or interim path | Engine-install and scaffold authorization row (new, distinct from Q-E01); install source decision | HF-01 wave |
| S0-04 | TADR-002/005 runtime-ownership hello-world (phases A-E, fault injection) and the HF-04 sketch replacement text | Runtime / M | S0-01, path decision | Engine install | HF-04 |
| S0-05 | TADR-003 typed Resource identity, duplicate-ID refusal, `duplicate()` immutability check | Content / S | S0-01 | Engine install | HF-05, before HF-06 |
| S0-06 | TADR-003 binary-tree admission rejection and failed-reload retention | Content / S | S0-05 | Engine install | HF-05, before HF-06 |
| S0-07 | Author the TADR-004 `SaveOwner` proof and fixtures (cases a-f, three fixture directories) | Persistence / S | HF-01 or placeholder path | None for authoring; engine install to run | HF-07 |
| S0-08 | Execute the TADR-004 proof, record engine version, OS, method and the durability non-claim | Verification / S | S0-07, S0-01 | Engine install | HF-07, before HF-08 matrix is finalized |
| S0-09 | Export presets for Linux x64 and Windows x64, `--export` mode in the smoke runner, optional advisory CI workflow | Verification / M | S0-01 | Authorization extended to templates and to pushing a workflow; Q-E06 before any export leaves the machine | Parked (stage 2-3) |

**ID mapping from the worker drafts.** B1 S0-01 is S0-01 here and B1 S0-02 is S0-09. B2's separate S0-01 (a Tooling/S host-pin card) was folded into S0-01, and B2 S0-02 is S0-04. B3 S0-01 and S0-02 are S0-05 and S0-06; B3 listed "no dependencies inside the HF sprint" and the consolidation adds S0-01 as a dependency because the pinned host must exist first. B4 S0-01 and S0-02 are S0-07 and S0-08. D1 S0-01 and S0-02 are S0-02 and S0-03. Owners and the rest of each dependency list are unchanged. S0-02's outcome also covers events-table integrity (no blank lines inside the append-only table), which is what next step 3 relies on.

**Proposed order relative to the HF sprint.** S0-02 and S0-03 now: they need no engine and make `ORCHESTRATOR.md:104` executable. After the authorization row, schedule the proofs into the writer slots the HF waves leave idle, because W1, W3 and W6 already sit at the two-writer ceiling (`ORCHESTRATOR.md:34`, Part 2.2): S0-01 in W2 beside HF-03 (HF-01 is then admitted and can ratify the root path); S0-05 and S0-07 in W4 beside HF-06 (S0-07 is authoring only and needs no engine to write); S0-04, S0-06 and S0-08 in W5 beside HF-07, one per remaining slot with S0-06 and S0-08 spilling into W6 if the reviewer slot is busy. This keeps the wave count at seven and puts every proof before the HF card whose DoD it feeds (HF-06's codec column after S0-05; HF-08's matrix after S0-08; HF-04's sketch replaced at revision 2 by the S0-04 source link). If Andrew prefers the proofs strictly beside their own HF cards, the sprint grows by two or three waves. Each paired HF card gains a "re-verify when S0-0x lands" trigger on the DoD items the workers flagged as drift-prone (path families, tick ownership, ID-versus-path identity, commit ordering).

---

## Still Needs Human Decision

Each with a recommendation and a park option. Only Andrew can make these; the coordinator will not infer any of them.

- [ ] **Engine install and scaffold authorization.** Add a TRACKING program-authorization row permitting a pinned Godot 4.7.2 standard editor and export templates on this machine and a `native/` root, distinct from Q-E01 (which gates qualification slices, not scaffold proofs). Recommend: yes, official release binaries with recorded digests (Windows reproducibility). Park: stay documentation-only; S0-02 and S0-03 still proceed.
- [ ] **Sequencing.** Pair S0 proofs beside their HF cards (recommended) versus running them after HF-10. Pairing gives HF-04's sketch, HF-06's codec column and HF-07's ordering something real to cite; following maximises drift.
- [ ] **CI baseline.** Accept "local-only gate now, hosted CI parked with named unpark conditions" (recommended), or direct stage 2 to be drafted now.
- [ ] **Headless test host.** Plain `--headless --script` runner for all S0 proofs (recommended, zero dependencies); park gdUnit4 for TH-23. Adding any test addon is a dependency change under AGENTS.md.
- [ ] **HF card amendments.** Accept the splits of HF-03, HF-04, HF-06, HF-07 (sprint grows to about 14 cards) and the HF-10 output relocation, or ship them as L with a longer attempt budget. Fix the receipts path and the non-blocking-questions field regardless.
- [ ] **Import the draft cards** through a BACKLOG definition-change event and TRACKING import, on Andrew's explicit instruction only.
- [ ] **Scope of the tooling cards.** Whether S0-02 and S0-03 may run the build-containing `npm run verify` (they touch `scripts/` and `tests/`, which `verify.mjs:53-55` hashes), or are restricted to `check:project` plus `npm test`.
- [ ] **Lead-server quarantine.** Authorize decoupling `check-build.mjs` from `server/` and freezing the lead-capture surface (AGENTS.md preservation rule).
- [ ] **BIBLE.md Appendix A collapse** to its table (approved document; affects the check at `COHESION_REPORT.md:94`).
- [ ] **Mechanical permission gates** in `.claude/settings.json` and branch protection on `main` (pstack preference says leave Claude Code configuration alone unless asked).
- [ ] **Q-E06 license** before any export stage; and whether the `gh` token keeps `workflow` scope.
- [ ] **Ambiguous save recovery (from the TADR-004 proof design).** When a valid but never-renamed newer temp file carries a spent-revival or terminal fact, the protocol refuses automatic resumption; whether that surfaces to the player as a blocked-resume state is a product choice.
- [ ] **Idle writer slots.** Whether W2, W4 and W5 may run PD-01 (depends only on HF-01) or the S0 proofs, or stay unused within an HF-only authorization.
- [ ] **Marketplace CI actions** as dependencies under the locked-dependency rule if stage 2 is ever unparked, versus official actions plus a direct pinned download only.

## Recommended Next Steps

1. Andrew reads this report and answers the first three decisions above (engine authorization, sequencing, CI baseline).
2. Coordinator records the answers as TRACKING events, applies the receipts-path and non-blocking-questions amendments to BACKLOG, and imports accepted S0 cards through a definition-change event. No writes happen before that instruction.
3. Dispatch S0-02 (check:docs) first; it needs no engine, and its first run on the current tree will surface the broken TRACKING table (`:234-238`) and any unresolved anchors before HF-01 starts.
4. If the engine row is authorized: S0-01 in the HF-01 wave, then the paired proofs in the order of 2.5.
5. Run the reviewer-body, skill-procedure and worktree-script fixes (recommendations 6, 7, 13) as one small tooling card; they change how every later card is executed.

---

## Evidence limits, worker table and review

**Method.** Source review only, evidence level 2. No engine ran; no build ran; no browser opened. Receipts were produced by the coordinator with read-only commands and Context7 documentation fetches (`docs-godot.txt`, library `/websites/godotengine_en_4_7`). Two receipt gaps were reported by workers and are carried into the draft cards as mandatory lookups: the Godot receipt contains no `_physics_process`, `Engine.physics_ticks_per_second`, `SceneTree.paused`, `DirAccess.rename` or `JSON` methods, and does not show whether `quit()` accepts an exit code. GitHub Actions allowance figures are from secondary sources and marked unverified.

**Model and effort.** Nine of ten workers reported the model as `claude-fable-5-1` from host-supplied metadata; B3 reported it from the agent frontmatter. No worker could observe its applied effort. Two explorers (A1, B1) observed a numeric `reasoning_effort` marker of 25 on their turns; the coordinator's turns also carry 25; the reviewer, launched from the xhigh definition, observed 80. The marker therefore varies with the declared effort, which means it is not a constant harness value and the coordinator is likely running below its configured xhigh, at or near explorer level. A candidate cause the reviewer identified: `.claude/settings.json` sets `model` to `claude-fable-5-1[1m]` while the effort override is keyed under `modelSettings["claude-fable-5-1"]` (`scaffold.txt:162-167`), so the override may not apply to the suffixed model ID. Under the pstack policy this is a substitution question Andrew should see, not a footnote: the coordinator role is mapped to xhigh and that pair is unconfirmed for this session. The findings do not depend on it, because every one is tied to a `path:line` a reader can check, and the xhigh reviewer independently re-verified the scores, the Part 2 designs and ten citations of its own choosing.

| Worker | Slice | Verdict | Notes |
|---|---|---|---|
| A1 | Dimensions 1, 5 | PASS+NOTES | Byte shares of BIBLE appendix inferred from line ranges, not measured |
| A2 | Dimensions 2, 3, 7 | PASS+NOTES | Skill prescriptiveness judged from text, not runtime behaviour |
| A3 | Dimensions 4, 6 | PASS+NOTES | `.private/` presence checked by Glob only (empty) |
| B1 | TADR-001 + TADR-005 export/offline | PASS+NOTES audit; FAIL coverage | Receipt gaps on export presets and typing keys marked unverified |
| B2 | TADR-002 + TADR-005 pause | Gap confirmed, design-ready | Receipt lacks physics/pause APIs; all marked unverified |
| B3 | TADR-003 | Gap confirmed, design-ready | `quit(int)` exit semantics unverified |
| B4 | TADR-004 | Gap confirmed, design-ready | Receipt lacks rename and JSON methods; fsync unassertable |
| C1 | HF-01..05, HF-10 | PASS+NOTES / FAIL-as-written for HF-03, 04, 10 | Every cited anchor confirmed to resolve |
| C2 | HF-06..09, header | Mixed; HF-06 L, HF-07 M/L | Anchor `#6-core-systems` confirmed at `BIBLE.md:469` |
| D1 | CI and harness | PASS+NOTES | Pricing primary page unread; action maintenance unverified |

No dropouts, no respawns, no format violations. Ten of ten slices returned.

**Independent review.** `scrapkeep-reviewer` (declared xhigh; observed effort marker 80; model from host metadata) returned **PASS+NOTES at evidence level 2**, conditional on its first four adjustments. It re-checked all seven scores against the rubric, the 18 recommendations, every Part 2 design against TADR-001..005 (no contradiction found; the d2 save-recovery claim, the binary-tree rule and the accumulator precedent each confirmed against the ADR and source lines), the S0 renumbering against the worker drafts, the CI recommendation against ORCHESTRATOR's sole-writer rules, and ten citations of its own choosing (all resolved; one line range imprecise, corrected above). The reviewer could not run commands; its checks on Godot absence, CI absence, token scopes, counts and byte identity rest on the coordinator receipts.

### Reviewer adjustments and dispositions

All 25 adjustments were applied; none rejected. The material ones:

1. **Effort disclosure rewritten** (adjustment 1). The reviewer observed marker 80 on its xhigh turn versus 25 on the high explorers and on the coordinator, which contradicts the original "harness-scale value" reading. The report now states the coordinator's actual effort is unconfirmed and likely below configured xhigh, with the `[1m]` model-ID versus `modelSettings` key mismatch as a candidate cause.
2. **S0 schedule corrected** (adjustment 2). The original "beside HF-01/04/05" order put three to five writers into waves already at the two-writer ceiling; the proofs are now scheduled into the idle W2, W4 and W5 slots.
3. **Absolute-path links restored** (adjustment 3). Both A1 and A3 had reported tracked docs linking `/home/andrew/...` paths; the coordinator had dropped it. Verified by the coordinator after review: six tracked files, `check-project.mjs:70-73` resolves absolute targets as-is, and `/home/andrew/Projects/test-game-2/docs/bible/images/G01-v1.png` exists on this machine, so `check:project` passes only here.
4. **Fan-out disclosure added** (adjustment 4): ten parallel workers exceeded `ORCHESTRATOR.md:34` under Andrew's explicit read-only allowance.
5. **Dimension 6 moved GREEN to YELLOW** (adjustment 21) on the rubric's literal `.gitignore` bullet; the worker's GREEN reasoning is retained in the dimension text.
6. **Recommendations re-prioritized and re-scoped** (adjustments 5-12, 23): lead-server quarantine to MEDIUM; non-blocking questions to HIGH; authorization owners named for artifact deletion, README license line, reviewer-definition edit and BACKLOG split; branch protection narrowed to force-push and deletion protection; HF-10 relocation's effect on twelve TH cards added; `environment.toml` marked autogenerated.
7. **Attribution and inference fixes** (adjustments 13-20, 22, 24, 25): worker-to-report ID mapping added; three dropped Andrew decisions restored; "will surface" softened; "all four workers" corrected to three; C2's "mixed" verdict distinguished from the coordinator's escalation; `check-build.mjs` line range corrected; "deterministic" replaced by "scripted, non-LLM"; line and byte totals labelled approximate; external pstack paths given in full; "no hooks or branch protection" reworded as "no evidence of".

One reviewer observation is recorded without a report change because it is a process fact rather than a finding: the reviewer's own checks on command output rest on coordinator receipts, exactly the receipt-inheritance the report recommends reviewer definitions disclose (recommendation 6).
