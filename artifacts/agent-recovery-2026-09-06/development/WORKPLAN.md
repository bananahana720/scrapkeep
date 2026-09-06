# Target continuity and obstacle recovery

- [x] Read the Principles section in full.

## Feature playbook steps

1. `how` over the affected subsystem. Resolve every third-party API the change touches through `find-docs`, and search `modern-web-guidance` for each web-surface behavior it adds (Non-negotiables). Carry the IDs into the delegate brief's CONTEXT.
2. `architect` for parallel design exploration. Skipping stays as `architect skipped: <reason>`; do not fold the design decision silently into implementation.
3. Write the throughput checkpoint as four todo items. A dimension that genuinely does not apply (single file, no fan-out) keeps its item with `n/a: <reason>` rather than being dropped:
   - **Blocking first steps.** Gates run before fan-out.
   - **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
   - **Shared mutable state.** Default to splitting the target (the **separate-before-serializing-shared-state** principle skill). Serialize only for real invariants.
   - **Smallest safe decomposition.** If one worker is best, name why.
4. Delegate code-writing to a subagent using your configured feature model (default `sonnet`) with a specific scope (file paths, named data shape and its organizing structure per **principle-model-the-domain** (a state machine over scattered booleans, a table/registry over branching, a typed model over repeated shape assumptions, chosen before the delegate writes logic), and success criteria), written as the brief in the poteto-mode Subagents section; review its diff yourself. When the implementation admits multiple valid shapes (error handling, abstraction layer, test structure), delegate via the **arena** skill instead so the runners surface the alternatives and the cross-judge guards the pick. Mandatory: no skip-with-reason escape, and Laziness Protocol does not override it (the gain is review separation, not lines saved). You can spawn a subagent even though you are one; "the app is small" and "a subagent cannot spawn one" are both wrong. A subagent forbidden to spawn satisfies this by owning the diff directly with the same review separation; no "standing by" reply that waits on a nested agent. Comments per **Comments**. Surgical edits, re-ground against the source for upstream-derived files. Port shared-primitive improvements to all consumers and verify each. Commit liberally.
5. Verify on the matching surface. For a web surface, first check the diff against the retrieved `modern-web-guidance` guides. "Inconclusive" or wrong-surface is not a pass; flag it.
6. Rebase into small, ordered commits; stack follow-ups.
   Use the **sequence-verifiable-units** principle skill, building, verifying, and committing each small unit before the next.
7. If the design is contested, `interrogate` before shipping.
8. Run **Opening a PR**.


## Throughput checkpoint

- [x] Blocking first steps. Reproduce saved failures and capture a fresh baseline before changing the player. Resolve touched NumPy/Pillow APIs.
- [x] Independent workstreams. Each isolated writing candidate owns its coupled policy/perception variant. Parent owns native trials and serial admission.
- [x] Shared mutable state. Writers use separate Git worktrees. Parent serially admits code and alone owns test desktop inputs.
- [x] Smallest safe decomposition. Keep policy and perception together within each candidate; independent source reviewers do not write or operate desktops.

## Scope

Keep game code and native input core unchanged. Complete target continuity and obstacle recovery within the maintained player, with replayable failure probes and bounded ordinary native runs. Default target is three consecutive terminal visual runs without a stall timeout, plus retained-case recovery and unchanged stale-frame release. A win-rate claim needs more evidence than this small batch.

Architect skipped: the observation, policy and input-owner boundaries already exist. New recovery state stays inside those boundaries.
Step 6 rebase skipped: preserve existing branch and unrelated working edits; admit one verified local commit.
Step 7 interrogate is conditional on a contested design.
Step 8 remote PR skipped: no remote is configured and publication is not authorized.

## Arena phases

- [x] Frame. Two implementations of one bounded recovery behavior.
- [x] Fan out. Isolated Astra high and xhigh worktrees.
- [x] Cross-judge. Fresh Astra max review alongside parent diff review.
- [x] Pick. Score retained failure recovery, continuity, stale authority, timing and code clarity.
- [x] Graft. Admit only compatible improvements.
- [x] Verify. Replay cases, ordinary native game, pause and cancellation, project verification.

Data shape before code: persistent target track with screen geometry, age and association; one explicit recovery state with reason, phase start and bounded exit; compact image-derived evidence for visual progress. Observer produces evidence, policy owns decisions, existing combat loop remains the only native input owner.

Baseline observation: initial fresh unchanged run won after 85.18 active seconds. This confirms stochastic successes are possible on current code; it does not erase retained timeouts. The three-trial unchanged baseline batch completed lost, won, lost; together with the initial trial, the baseline has two wins and two losses. These are random trials, not a controlled win-rate estimate.

Integration gate passed for the stationary-scan policy: won/won/lost in three consecutive terminal trials, all pause checks passed, no stall timeout or cleanup error. Same-policy interruption cleaned up in 0.264 seconds. Seventy-six focused tests and full root project verification passed. Independent source review and production-loop probes found no required fix. The rejected original, combined, moving-search and relocation variants remain separately retained.

The final explanatory report text was corrected after confirming that the ordinary game constructor defaults to seed 42. Input/capture timing varies; the runner does not select or read a live seed. A fresh smoke check covers that final formatter source. Closeout retains the comparison, updates the canonical engineering/backlog records, and creates one scoped local commit.
