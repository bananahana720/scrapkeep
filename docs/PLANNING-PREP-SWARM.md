# Planning-prep swarm record

Historical team record for the completed planning-preparation pass. The [housekeeping remote record](project/HOUSEKEEPING.md#environment-constraint) supersedes the no-remote claim under Evidence limits, and the [historical planning protocol](project/PLANNING.md) supersedes the claim there that the protocol's first execution is the next session; [ORCHESTRATOR.md](../ORCHESTRATOR.md) now owns dispatch. The text below retains its original dated wording.

5 September 2026. Team record for the housekeeping and planning-preparation pass Andrew requested after the deep-research swarm. The goal was to review that research, settle the environment, and give the repository a planning mode that settles decisions with Andrew before any swarm implements. Nothing in this pass changed game behavior, dependencies, or scope.

## What ran

The coordinator ran the baseline checks first. `npm run verify` passed all six stages on the working tree as handed over. The coordinator then initialized Git on branch `main` with baseline commit `4db9b31`, created one worktree per writer, and fanned out four workers in parallel. The harness's worktree isolation could not resolve a base branch because the repository did not exist when the session started, so the worktrees were created by hand and each writer received its path in its brief.

| Lane | Model | Output | Verdict |
| --- | --- | --- | --- |
| Decision register | fable | [Decision register](project/DECISION-REGISTER.md), 48 entries in three tiers with a first-session agenda | PASS+NOTES, level 4 for links, level 2 for coverage |
| Planning protocol | fable | [Planning protocol](project/PLANNING.md) and the `plan-session` Claude Code project skill | PASS+NOTES, level 4 |
| Desk consistency | sonnet | Git-state text in [CONTRIBUTING](../CONTRIBUTING.md), [AGENTS](../AGENTS.md), [closeout](project/HOUSEKEEPING.md), backlog T01; three appended [decision trail](decisions.tsv) rows for the audit, the research pass, and the Git init | PASS, level 4 (reported as "ship it") |
| Ground-truth check | sonnet, read-only | Verification of the numbers the audit cites from `src/orchard/`, below | PASS+NOTES, level 2 |

The coordinator merged the three writer branches with no-fast-forward merges, narrowed register entry D04 to the remaining remote question because the local checkout now exists, wired the desk cross-links, removed a hardcoded home path from the skill, and wrote this record. One fresh read-only reviewer (fable) then inspected the integrated diff and returned PASS+NOTES at evidence level 3: coverage of all 25 review-notes questions confirmed, no path to implementation before a recorded go, no stale environment text in the desk. Its six findings were applied, except that dated audit records keep their original environment text as history.

## Ground-truth check

Every measured constant the [design audit](DESIGN-AUDIT.md) cites matches current source at evidence level 2: top roll speed 7.4 at `simulation.js:323`, acceleration 25 at `:329`, the Snipcart windup, active and recovery durations in `ENEMY_CONFIG`, the 2.1x counter multiplier and 1.3x primed multiplier on one line at `:681`, burst speed 19 at `:297`, the z-only `groundHeight` ramp at `:57`, and the global `_workerGap` windup gate at `:407`. The 73-test count holds. Two probe-table numbers derive arithmetically from the cited constants (0.25 s to 85 percent speed; 1.15 u/s a quarter second after release).

Three notes for the planning conversation.

- The audit lists "approach 0.25 s" beside three `ENEMY_CONFIG` durations. That number is the per-enemy initial attack cooldown passed to `_makeEnemy` (`simulation.js:152`), not an approach-phase duration; approach is distance-gated, not timed.
- The audit's "kind-string branching duplicated across three files" is under-cited by its own working paper, which names two files. A third, `src/orchard/main.js`, does branch on kind for labels, so the count is right and the citation is incomplete. The registry recommendation stands.
- The 90-degree realign figures (0.30 s, 0.14 s braking) carry no citation and could not be reproduced from static code under two plausible definitions. Treat them as live-probe measurements without a recorded method.

The 9.5 u/s deflect threshold has no counterpart in code; no deflect mechanic exists. Save schema v2 is proposal only; the current profile checks are literal comparisons against `1` (`campaign.js:115`, `progress-store.js:45`) with no migration hook.

## Evidence limits

No game code changed, so the first-build browser receipts remain the orchard evidence. The register's coverage of the review notes' 25 open questions was checked by inspection, not by a script. The ground-truth check read source and ran the Node tests; it launched no browser. The planning protocol has not yet been run end to end; its first execution is the next session. No remote exists, so the new history is not backed up off this machine.
