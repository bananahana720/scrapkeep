# AI-Firstify Assessment Report

**Project:** Scrapkeep (`sketches/core-loop` + `src/` + tooling), branch `aifirstify_repo_gemini_workflows` at `main` (`a76ccfd35`)
**Date:** 2026-11-25
**Mode:** Re-engineer (Mode 2: Full 7-Dimension Audit + Antigravity/Gemini Uplift)

## Overall Score

| Dimension | Score | Summary |
| --- | --- | --- |
| 1. Project Structure | GREEN | `AGENTS.md` (48 lines), `CLAUDE.md` (3 lines), `GEMINI.md` (22 lines), hardened `.gitignore` (29 lines), and `scripts/sketch-fast.mjs` allowing root `GEMINI.md` alongside `.mcp.json` keep discovery clean across hosts. |
| 2. Agent Architecture | GREEN | No embedded chatbot in game or web app code (`src/`, `sketches/core-loop/src/`, `server/`); offline research callers to `api.typesafe.ai` (`tools/jev-player/`, `scripts/lab/`) stay isolated off gate paths; 6 native `.agents/agents/*.md` Gemini-tiered subagents mirror `.claude/agents/` with two-way parity enforced by `npm run check:agents`. |
| 3. Skill Usage | GREEN | 12 prescriptive skills under `.agents/skills/` (10 existing + `scrapkeep-gemini-workflows` and `scrapkeep-visual-review`), each with `references/`, `scripts/`, lesson ledgers, `.claude/skills/` symlinks, `[A-Z]{3}-\d+` `check:skills` enforcement, and zero live `astack` references. |
| 4. Scope & Complexity | YELLOW | Core Godot alpha, preserved browser proofs (`/` and `/orchard.html`), and tooling are cleanly separated, redundant uplift stubs were subtracted (`347 -> 257` lines across the Antigravity uplift surface), and legacy `server/` lead-capture code, 2 duplicate `tools/agent-player` archive copies, and retired `.codex/` configs remain pending Andrew's deletion approval. |
| 5. Context Hygiene | GREEN | Lean entry points (`AGENTS.md` 48 lines + `GEMINI.md` 22 lines + `CLAUDE.md` 3 lines) route without duplication to progressive-disclosure `.agents/rules/` (`glob` and `model_decision` triggers) and skill `references/`. |
| 6. Safety | YELLOW | No hardcoded secrets; `.env.example` only; `.gitignore` covers keys/certs/leads; `.agents/hooks.json` + `.agents/hooks/safety-gate.mjs` (covering `-f`/`-fu`/`+ref`, `-am`/`git add`, `--pathspec-from-file`, `:branch`, `branch -M`/`-C`/`-D`/`-f`, `McpBridge`, live saves, and `package.json`) pass unit/subprocess tests, while fresh-session Antigravity `PreToolUse` hook auto-discovery is not yet live-verified. |
| 7. Workflow Design | YELLOW | `scripts/check-agents.mjs` (wired into `npm run check:docs`) enforces Antigravity schema, hook integrity, Python workflow AST syntax + undefined `call_tool()` ban, and `astack` removal; `card_batch.py` (`dry_run: true`), `pr_gate_review.py` (`PASS+NOTES` on `caf208c30`), and `eye_read_workflow.py` (synthetic 1-frame planted-fault control `task-574`) ran live via `run_workflow`, while live `card_batch.py` write mode and a real `eye.mjs` gameplay capture remain open. |

## Priority Recommendations

1. **[HIGH]** **Live-test `.agents/hooks.json`, `card_batch.py` write mode, and `eye_read_workflow.py` in a fresh Antigravity session**: Verify `PreToolUse` hook auto-discovery, one writer card via `card_batch.py`, and `eye_read_workflow.py` against an `eye.mjs` capture. Effort: 30–45 minutes.
2. **[HIGH]** **Re-date or fix expired `KNOWN-FAILING.tsv` rows, `check:drift` mismatches, and local `/usr/bin/ffprobe` path assumptions**: `node scripts/known-failing.mjs --promotion` flags expired review dates (`2026-11-23` / `2026-11-24`), `npm run check:drift` reports 15 pre-existing hash mismatches across `docs/tech/sections/` (5) and `docs/product/sections/` (10), and `scripts/brief-check.mjs:33` hardcodes `/usr/bin/ffprobe` (causing 2 pre-existing `npm test` failures on macOS). Effort: 1–2 hours (coordinator / Gate).
3. **[MEDIUM]** **Prune retired `.codex/` and `tools/refsheets/draw.sh` assets after approval**: Under `AGENTS.md`, deletions require Andrew's explicit go-ahead. Once approved, remove `.codex/` (retired 17 Oct 2026) and migrate `tools/refsheets/draw.sh` callers to `scrapkeep-visual-review` (`image-generator` / `gemini-api-cli`). Effort: 30 minutes.
4. **[MEDIUM]** **Add optional `--host agy|claude` / Gemini backend to `card-runner.mjs` and `tools/asset-forge/forge.py`**: Both scripts still shell out only to `claude -p` (`scripts/card-runner.mjs:258`, `tools/asset-forge/forge.py:331`). Adding a Gemini CLI / Antigravity backend would unify unattended automation across hosts. Effort: 2–3 hours.
5. **[LOW]** **Quarantine legacy `server/` lead-capture code and archive duplicates**: Decouple `scripts/check-build.mjs` from `server/` and decide retention for the 2 remaining `tools/agent-player` copies (`relocation-live`, `final-live`) and `stationary-live/implementation/` under `artifacts/agent-recovery-2026-09-06/` (deferred since the `2026-09-06` audit). Effort: 2 hours.

## Detailed Findings

### Dimension 1: Project Structure

- **Baseline observed**: `AGENTS.md` (48 lines), `CLAUDE.md` (3 lines), `.gitignore` (25 lines), 34 tracked root entries (27 non-dotfile), 14,761 tracked files. `GEMINI.md`, `.agents/{rules,agents,hooks.json}`, and `scripts/sketch-fast.mjs` `GEMINI.md` allowance were absent.
- **Changes applied**: Added lean root [GEMINI.md](../../GEMINI.md) (22 lines) delegating rules to `AGENTS.md`, added `.agents/rules/`, `.agents/agents/`, and `.agents/hooks/`, updated `scripts/sketch-fast.mjs` (`ROOT_FILES_ALLOWED` permits `.mcp.json` and `GEMINI.md`) and `scripts/check-scope.mjs` (`/^GEMINI\.md$/`, `/^\.gemini\//`, and absorbing all `configuration` paths plus `tests/fixtures/check-scope/*.json` into `tooling-no-build`), and hardened `.gitignore` (29 lines) with `credentials.json` and `service-account.json`. Note: branch commits past promotion commit `a76ccfd35` incur 1 expected Gate-owned `wave-state` finding in `npm run check:docs` until stacked on `stage/alpha-w<N>`.

### Dimension 2: Agent Architecture

- **Baseline observed**: No embedded chatbot or LLM API inside the Godot game or browser UI (`grep` across `src/`, `sketches/core-loop/src/`, `server/` returned zero LLM SDKs). Offline lab/research scripts call `api.typesafe.ai/v1/systemone` (`tools/jev-player/decide.mjs:19`, `tools/jev-player/experiments/jl18c/run.mjs:31`, `scripts/lab/triage.mjs:23, 277`, `scripts/lab/verdict-tags.mjs:46`, and `scripts/lab/coverage-gap.mjs:21` importing `jevCaller` from `triage.mjs`) strictly outside gate paths. Subagent definitions existed only for Claude (`.claude/agents/*.md`, 6 files) and retired Codex (`.codex/agents/*.toml`, 7 files).
- **Changes applied**: Created 6 native Antigravity subagents under `.agents/agents/scrapkeep-*.md` with explicit `subagent: true`, `mainAgent: false`, Gemini model pins (`flash`, `pro`, `inherit` matching `AGENTS.md` rule 11 and `.claude/agents/`), and least-privilege native tool lists. Encoded structural checks in `scripts/check-agents.mjs` (`npm run check:agents`) to verify YAML frontmatter, native tool names, read-only posture on explorer/reviewer/verifier roles, and two-way `.claude/agents` <-> `.agents/agents` parity. Updated `AGENTS.md` rule 11 to reference both `.agents/agents` and `.claude/agents`.

### Dimension 3: Skill Usage

- **Baseline observed**: 10 skills in `.agents/skills/` symlinked into `.claude/skills/`, validated by `scripts/check-skills.mjs`, plus 18 live `astack`/`A stack`/Codex prose references accumulated across docs and skill host adapters during initial uplift.
- **Changes applied**: Added `scrapkeep-gemini-workflows` and `scrapkeep-visual-review` (with `SKILL.md`, `references/`, `scripts/`, `references/lessons.md`, and `.claude/skills/` symlinks), generalized `scripts/check-skills.mjs` lesson prefixes to `[A-Z]{3}-\d+`, added Antigravity `## Host adapter` notes across all 12 skills (including portable Antigravity runtime note in `reactive-model-loop`), removed all 18 live `astack`/Codex prose references (retaining only historical provenance in `references/lessons.md`), and enforced zero `astack`/`A-stack` regressions via `scripts/check-agents.mjs`.

### Dimension 4: Scope & Complexity

- **Baseline observed**: Godot sketch (`sketches/core-loop`), preserved browser proofs (`/` and `/orchard.html`), and Node/Python tooling coexist with ADR fences; initial Antigravity uplift totaled 347 lines across `GEMINI.md`, `.agents/rules/*.md`, new skill docs, and `docs/project/AI-WORKFLOW.md` (including duplicate `model-tiers.md` and `legibility-checklist.md` stubs).
- **Changes applied & remaining**: Deleted both redundant stubs, deduplicated `GEMINI.md` and `godot-core-loop.md`, and trimmed `AI-WORKFLOW.md` (`347 -> 257` lines total across the Antigravity uplift surface). Scored **YELLOW** because removing pre-existing retired surfaces (`server/`, 2 remaining `tools/agent-player` copies under `artifacts/agent-recovery-2026-09-06/`, `.codex/`, and `tools/refsheets/draw.sh`) requires Andrew's explicit deletion go-ahead under `AGENTS.md`.

### Dimension 5: Context Hygiene

- **Baseline observed**: `CLAUDE.md` + `AGENTS.md` were compact (51 lines total), and skills separated `references/` + `scripts/`, but Antigravity lacked scoped `.agents/rules/` progressive-disclosure files.
- **Changes applied**: Created three flat progressive-disclosure rules in `.agents/rules/` (`godot-core-loop.md` 12 lines, `browser-proofs.md` 12 lines via `trigger: glob`; `creative-and-visual.md` 11 lines via `trigger: model_decision`), paired with a 22-line `GEMINI.md` pointer (`astack`-free) verified under `<= 100` lines and `<= 24 KB` rule budgets by `scripts/check-agents.mjs`.

### Dimension 6: Safety

- **Baseline observed**: Zero hardcoded secrets; `.env.example` only; `.gitignore` excluded `.env`, `*.pem`, `*.crt`, `*.key`, `leads.*`. Approval gates lived only in `.claude/settings.json`.
- **Changes applied**: Created `.agents/hooks.json` and `.agents/hooks/safety-gate.mjs` (`PreToolUse` on `run_command`, `edit_file`, `write_file`, `write_to_file`, `replace_file_content`, `multi_replace_file_content`) parsing git global flags (`-C`, `-c`, `--no-pager`), shell chains (`git add && git commit`), bundled force/all flags (`-fu`, `-am`), `--pathspec-from-file`, colon-delete refspecs (`:<branch>`), and file path args to `deny` force pushes, `npm publish`, `gh repo delete`, live Godot save writes, and `McpBridge` commits in `sketches/core-loop/project.godot`, and `ask` on `main`/unqualified/delete pushes, package mutations, `gh repo`/`api`, `git reset --hard`, `git branch -D`/`-f`/`-M`/`-C`, and `sketches/core-loop/package.json` edits. Verified in `tests/antigravity-hooks.test.js`; scored **YELLOW** pending live Antigravity `PreToolUse` auto-discovery observation.

### Dimension 7: Workflow Design

- **Baseline observed**: Strong Node validation (`check:skills`, `check:project`, `check:docs`, `check:scope`) and `card-runner.mjs`, but workflows lacked native `run_workflow` scripts or structural enforcement of `.agents/` files.
- **Changes applied**: Added `scripts/check-agents.mjs` (`npm run check:agents`, wired into `scripts/check-docs.mjs`, including AST rejection of undefined `call_tool()` calls in Python workflow scripts) and three `run_workflow` scripts (`pr_gate_review.py`, `card_batch.py`, `eye_read_workflow.py`) using Python `subprocess.run` after live execution proved `call_tool` does not exist in Antigravity's `run_workflow` runtime. Executed `card_batch.py` (`dry_run: true`) cleanly, passed live `pr_gate_review.py` (`PASS+NOTES` on `caf208c30` via `scrapkeep-reviewer-medium`), and passed a live synthetic 1-frame planted-fault smoke test of `eye_read_workflow.py` (`task-574` on `artifacts/local/eye-smoke-fixture/`, Blind Reader reported the mouse eyeshade sheet and Film Judge returned `FAIL` with 3 `blocker` discrepancies); scored **YELLOW** until live `card_batch.py` write mode and a real `eye.mjs` gameplay capture are exercised.

## Changes Made (Re-engineer mode only)

| Action | File | Description |
| --- | --- | --- |
| Created | `GEMINI.md` | Lean 22-line Antigravity entry point, Gemini tier map, skills & MCP routing |
| Created | `.agents/rules/*.md` | 3 progressive-disclosure rules (`godot-core-loop`, `browser-proofs`, `creative-and-visual`) |
| Modified | `.gitignore` | Added `credentials.json` and `service-account.json` |
| Created | `.agents/agents/scrapkeep-*.md` | 6 native Antigravity Gemini-tiered subagent definitions |
| Created | `.agents/hooks.json`, `.agents/hooks/safety-gate.mjs` | Mechanical `PreToolUse` safety gate (including `McpBridge`, `-fu`, `-am`, `:branch` guards) |
| Created | `tests/antigravity-hooks.test.js` | Unit and subprocess CLI tests for `safety-gate.mjs` |
| Created | `scripts/check-agents.mjs`, `tests/check-agents.test.js` | Structural verifier for `.agents/` schema, two-way parity, hooks, `astack` ban, and Python AST |
| Modified | `package.json`, `scripts/check-docs.mjs` | Registered `npm run check:agents` and wired `checkAgentsStage` into `check:docs` |
| Modified | `scripts/sketch-fast.mjs`, `scripts/sketch-fast.test.mjs` | Allowed root `GEMINI.md` alongside `.mcp.json` in `ROOT_FILES_ALLOWED` |
| Modified | `scripts/check-skills.mjs`, `tests/check-skills.test.js` | Generalized lesson prefix matching to `[A-Z]{3}-\d+` and added tests |
| Modified | `scripts/check-scope.mjs`, `tests/check-scope.test.js`, `tests/fixtures/check-scope/cases.json` | Classified `GEMINI.md` and `.gemini/` as `configuration`; exempted config + test fixture from build |
| Created | `.agents/skills/scrapkeep-gemini-workflows/*`, `.claude/skills/scrapkeep-gemini-workflows` | `run_workflow` orchestration skill (`subprocess.run`), `workflow-patterns.md`, `lessons.md`, `pr_gate_review.py`, `card_batch.py`, symlink |
| Created | `.agents/skills/scrapkeep-visual-review/*`, `.claude/skills/scrapkeep-visual-review` | Gemini multimodal & MCP visual QA skill, `refsheets-gemini.md`, `lessons.md`, `eye_read_workflow.py`, symlink |
| Modified | `.agents/skills/*/SKILL.md` (10 existing skills) | Added Antigravity / Gemini host adapter notes and removed all live `astack`/Codex refs |
| Modified | `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `project-guide/handoff/START-HERE.md`, `.agents/skills/README.md`, `docs/project/AI-WORKFLOW.md` | Removed dead `astack`/Codex references and registered Antigravity checks and workflows |
| Created | `artifacts/ai-first-audit-2026-11-25/*` | Audit report, README, and `decisions.tsv` provenance trail |

## Still Needs Human Decision

- [ ] Approve deletion/archiving of retired `.codex/` configs and legacy `tools/refsheets/draw.sh` (Codex image lane retired 17 Oct 2026).
- [ ] Approve whether `scripts/card-runner.mjs` and `tools/asset-forge/forge.py` should gain a Gemini CLI / Antigravity host flag alongside `claude -p`.
- [ ] Approve pruning/archiving legacy `server/` lead-capture code and the 2 remaining `tools/agent-player` copies under `artifacts/agent-recovery-2026-09-06/`.
- [ ] Re-date or fix expired `project-guide/handoff/KNOWN-FAILING.tsv` rows (`node scripts/known-failing.mjs --promotion`), reconcile the 15 pre-existing `npm run check:drift` mismatches in `docs/tech/sections/` and `docs/product/sections/`, and decide macOS `ffprobe` fallback in `scripts/brief-check.mjs:33`.

## Recommended Next Steps

1. Run `npm run check:agents && npm run check:skills && npm run check:project && npm run check:scope -- main HEAD --no-build` in any Antigravity or CI session, and verify `artifacts/local/check-docs/report.json` has zero non-`wave-state` failures while off `stage/alpha-w<N>`.
2. Open a new Antigravity session in this repository to confirm live `.agents/hooks.json` auto-discovery and run `eye_read_workflow.py` on a real `eye.mjs` capture.
3. Use `pr_gate_review.py` via `run_workflow` on future PRs against `stage/alpha-w<N>`.
