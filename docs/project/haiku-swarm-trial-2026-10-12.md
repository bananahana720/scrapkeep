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

Interim reading, 2026-10-13, 17 dispatched units (waves 1 and 2, the KE3 to KE5 family wave and the determinism follow-ups). Reported to Andrew before any routing or pin change.

**Rule 1, Haiku writers: 5 of 17 admitted inside the pipeline (29%).** Under the 35% line. Taking out the correct stop (CAVE-IN) and the two failures attributed to the brief (STRAFE-DET, FU-SABLE-BANK) gives 5 of 14 (36%), just over it. Either way the rule lands on "Haiku writers for mechanical units only".

| Outcome | Units |
| --- | --- |
| ADMIT inside the pipeline (5) | KE7 (round 2), FU-RIVET-SHADOW (round 1), KE-FORMS (round 1), CUE-FORMS (round 2), DOMINO-DET (round 2) |
| FIX after the fix round, `writer` (9) | KE9, KC10, KB6, SR9, KE3 fleet, KE4 ancient, KE5 industrial, IDENTITY-DET, SQ5 (BLOCKED with five invalid structured outputs) |
| FIX, `brief` (2) | STRAFE-DET (the clause banned an equality key), FU-SABLE-BANK (wrong pilot name in the command) |
| Correct stop (1) | CAVE-IN: BLOCKED with no edits after 3 minutes; the engine could not lower ground, so the unit needed a design change |

All five admitted units were record tables or single-file fixes with a named pattern. The writer failures share three classes: checks that compare copies of a row instead of asking the owner (KE3 to KE5), in-test controls that pass by construction, and private reaches across files. Run discipline failed independently of the code: reports filed before the smoke finished (DOMINO-DET, IDENTITY-DET and several verifiers), a fix round left uncommitted (IDENTITY-DET), and at least six structured-output failures (five on SQ5, one on the ancient fix writer).

Merge check: no unit admitted by the pipeline failed it. SR9, admitted only after coordinator re-pins, did; the merge check, not the verifier or the gate, found its loot-parity and readout-layer pins.

Where Haiku stopped, Codex Sol finished: KC10 in one round, KE-FAM (the KE3 to KE5 heads) in two, SQ5, KE9 and PC-PACK from scratch, CAVE-IN in five.

**Rule 2, Haiku verifier: control passed; misses at the adoption line.** The planted SQ6 floor defect was caught by name. Gate high findings on criteria the Haiku verifier marked ok: KE7 (weather.gd:94) and KE4 ancient (PASS+NOTES against a gate FIX); SR9's pins were missed by the verifier and the gate alike. That is 2 to 3 misses in about 14 verified units, at or just over 1 in 5. Reading: useful as a pre-gate filter that catches FAILs early (it correctly failed fleet and industrial); never a substitute for the Opus gate.

**Rule 3, Haiku scouts: adopted.** Four of four spot-checked readiness claims held. One inventory claim (which worktrees exist) was wrong, so scouts read code, not the filesystem state of other sessions.

**Cost.** The KE3 to KE5 wave: 16 agents, 2.04M tokens, 25 minutes, zero admitted.

**Confounds.** Machine load 28 to 45 from the park loops caused at least two smoke timeouts. Haiku units came later in the wave, on a candidate with more tests and stricter pins. Sample sizes: 17 Haiku units against 26 merged baseline units, unpaired.

**Recommended routing (not applied until Andrew agrees):** Haiku writers, verifier and gate pipeline for record tables, single-file determinism fixes and other units whose files and pattern are named; Codex Sol for anything crossing files or needing design; Haiku scouts for readiness triage; the Opus gate unchanged. **What would reverse it:** five consecutive cross-file units admitted by Haiku inside the pipeline with a clean merge check.
