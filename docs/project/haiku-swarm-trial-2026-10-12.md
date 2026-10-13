# Haiku swarm trial, wave 13 (2026-10-12)

Andrew, 2026-10-12: task Haiku agent swarms through dynamic workflows for every parallel unit of this wave and the waves after it; Opus reviews and integrates; the point is to pressure-test Haiku agents orchestrated by Opus. Swarm size medium to large.

This file is written before any trial result exists (runtime contract, "Judging a model or effort trial").

## Roles

| Role | Model | Notes |
| --- | --- | --- |
| Triage scouts, writers, pre-gate verifiers, fix writers | Haiku 5.5, medium | One scout per unit block; one writer per unit in its own worktree |
| Acceptance gate | Opus 5.5, medium (`scrapkeep-reviewer-medium`) | Read-only, judges the diff against the unit block |
| Coordinator: selection, rulings, merge, merge check | Opus 5.5 main session | Same merge check as every wave-13 unit |

The Codex Sol loops already running keep their lanes; Haiku takes systems units (W13-INTEGRATION-3 section 3) that no running unit touches, plus small follow-ups.

## Population

The 31 unmerged systems unit blocks in `sketches/core-loop/design-v3/research/comps/W13-INTEGRATION-3.md` (SR16 excluded, it is after the alpha), and the open follow-ups in `HANDOFF-2026-10-12-1048.md` item 3. Units are dispatched when the triage and the coordinator find their code dependencies merged and their files clear of running units.

## Measures

Per unit: gate rounds to ADMIT (writer, then one fix round; the pipeline stops there), findings by attribution (`writer`, `verifier-miss`, `brief`, `owner`, `env`), output tokens and wall time per unit and per 100 changed lines (`~/.claude/hooks/bin/workflow-cost.py`), and whether the merged tree passes the merge check.

Baseline: the 26 systems units already merged. Most Sol units merged at round 3 (two FIX rounds), Sonnet and Opus units at round 1 or 2.

## Decision rules

1. **Haiku writers for systems units.** Adopt when at least 60% of dispatched units reach ADMIT within the pipeline (writer plus one fix round) and no admitted unit fails the coordinator's merge check. Reject for systems units when under 35%; between, keep Haiku for mechanical units only.
2. **Haiku pre-gate verifier.** A planted-defect control runs first: a Haiku verifier checks a branch where the coordinator broke one ACCEPTANCE line of an already-merged unit (SQ6's half-base cooldown floor). The verifier must return FAIL naming that line. If it passes the control, every Haiku verify verdict is treated as level 1 and the Opus gate is the only check. Separately, count gate high findings on criteria the Haiku verifier marked ok (`verifier-miss`); adopt the Haiku verifier when that happens in at most 1 of every 5 units.
3. **Haiku triage scouts.** The coordinator spot-checks three readiness claims against the code; adopt when all three hold.

Each rule can fail. One unit on a side is not a finding; units differ in size, so per-100-lines figures are reported with counts.

## Confounds

Machine load from the Codex park loops (load 28 to 45); briefs are the same unit blocks Sol and Sonnet used; the gate is Opus medium for both sides; Haiku units come later in the wave, on a candidate with more tests.

## Result

To be filled at the trial's close, reported to Andrew before any model pin changes.
