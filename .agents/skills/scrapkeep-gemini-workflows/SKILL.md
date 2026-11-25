---
name: scrapkeep-gemini-workflows
description: "Run Antigravity dynamic workflows and Gemini multi-agent fan-outs for Scrapkeep PR reviews, wave checks, and backlog card batches. Use when orchestrating parallel subagent reviews, running Python run_workflow pipelines, routing Gemini model tiers, or batch-executing eligible BACKLOG cards in Antigravity; single-card heavy-lane admission stays in scrapkeep-task, and check selection stays in scrapkeep-verify."
---

# Orchestrate Antigravity & Gemini Workflows

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `GEMINI.md`, and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill coordinates multi-step and fan-out work in Google Antigravity using `run_workflow` Python scripts, native `.agents/agents/scrapkeep-*.md` subagents, and Gemini model tiers. Single-card heavy-lane admission belongs to `scrapkeep-task`, and artifact check selection to `scrapkeep-verify`.

## Procedure

1. Choose the smallest orchestration surface that fits: act directly for 1–2 targeted steps, call `invoke_subagent` for a single delegated lookup or review, or call `run_workflow` when fanning out across files, cards, or staged pipelines. (AGW-01)
2. Follow `AGENTS.md` Rule 11 (`ruling ej`) for worker routing — Gemini 4 Neon at high effort owns code, tests, gate runs, and every independent admission review (Rule 4). Use `.agents/agents/scrapkeep-*.md` (`flash` for lookup/bounded writers, `pro` for verifier/fallback review, `inherit` for Neon-high review) as Rule 11's fallback tier map per `GEMINI.md` and `references/workflow-patterns.md` (`workspace="share"` for writers, `tools: [read_file]` only for reviewers). (AGW-02)
3. Run scoped PR checks (`check:scope`-selected commands + `check:skills`) and independent review via `run_workflow` with `scripts/pr_gate_review.py`, defaulting `base` to the open stage in `project-guide/handoff/STATE.md` and defaulting the reviewer model to `inherit` (so a Gemini 4 Neon high session satisfies Rule 4/11; never admit a unit on a downgraded model) while passing only acceptance criteria, diff, and receipts to the reviewer. (AGW-03)
4. Plan and execute eligible S/M backlog cards via `node scripts/card-runner.mjs --json` and `scripts/card_batch.py` (`dry_run: true` first; `workspace="share"` writer commits on a branch, coordinator runs `git diff` + `sketch:fast` via `subprocess.run`, and a fresh read-only reviewer inspects diff + receipts without reading writer notes; never push or stack). (AGW-04)
5. Write every workflow pattern using `phase`, `parallel`, `pipeline`, `agent`, `subprocess.run`, and structured JSON `finish` schemas as detailed in [references/workflow-patterns.md](references/workflow-patterns.md). (design choice)
6. Report verdicts, commands run, changed paths, active Gemini model/tier from runtime metadata (or state unavailable), and evidence limits per `project-guide/handoff/COMMS.md`. (design choice)

## Lessons and updates

[references/lessons.md](references/lessons.md) holds AGW-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row.

## Host adapter

- Antigravity: `/scrapkeep-gemini-workflows`. Use `run_workflow`, `invoke_subagent`, and `.agents/agents/scrapkeep-*.md`.
- Claude Code: `/scrapkeep-gemini-workflows` (or run `scripts/card-runner.mjs` and subagent reviews via `.claude/agents/scrapkeep-*.md`).
