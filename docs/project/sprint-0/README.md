# Operational Sprint 0 handoff

[TRACKING](../../../TRACKING.md#operational-sprint-0-closure-record) owns the current outcome, exact tested commit and pending actions. [The recorded closure receipt](closure.json) preserves the checked evidence manifest. [Authorization](AUTHORIZATION.md) owns the scope. The integrated app uses synthetic values to exercise session ownership, coordinated ticks, typed content, mutable-state isolation and save/resume across processes. It is a technical proof with a success screen and Exit button. It contains no playable game loop.

## Reproduce the local job

Use a clean checkout at the integrated commit named in the closure receipt, the pinned Godot editor and verified export templates from [the toolchain record](../../tech/native-toolchain.md), and locked Node dependencies.

```sh
npm ci
npm run check:docs
npm run check:project
npm run verify
node scripts/native-smoke.mjs --export
node --test tests/sprint-close.test.js tests/check-docs.test.js
```

The native command records each command, source identity, toolchain hashes, positive and injected-failure outcomes, export hashes and saved-state hashes in `artifacts/local/native-smoke/report.json`. Read its artifact paths to find the Linux and Windows executables. A successful Windows export proves no Windows execution. The report's per-process stage/resume commands can be repeated with a fresh disposable data directory. For a visible Linux run, omit `--headless` and `--auto-exit`, retain `--display-driver wayland` on this host, then click Exit after observing success. Do not point the synthetic app at personal save data.

The workflow is manual and targets the `scrapkeep-s0` label on a one-job local self-hosted runner. Andrew approved the first run; [CI run 34060932888](https://github.com/bananahana720/scrapkeep/actions/runs/34060932888) passed at `e54e429c76f3d83641c0127b4e44fe7eb8b2098f`, and its runner was removed. A future registration needs scope authorization to let GitHub Actions execute locally. This run used no hosted runner, reported an empty billable map and uploaded zero artifacts. Report JSON remains in local evidence and the job log/summary. No runner service was installed. The closed run has no remaining registered runner or local runner directory.

## Close the sprint

Use [the receipt schema](closure-receipt.md) to preserve evidence. Follow [the authoritative procedure](../../../ORCHESTRATOR.md#sprint-closure) through [the reusable prompt](../prompts/sprint-close.md). Reconcile the delivery cards, amendments and stopped leases before evaluating the receipt. S0-14 is the closure-control card; it is excluded from its own selected delivery set and completes only when that set passes.

Preserve the clean tested source identity separately from the later administrative commit that records the result. The checker grants no dispatch authority. A failure recorded as a backlog repair remains a failed current gate. Repeating identical receipt bytes against unchanged source and evidence must yield the same result without creating another event.

For future gameplay sprints, retain Andrew's playtest against the stated playable objective and the Bible's physical mastery, visible build change and world-discovery decision tests. Automated checks cannot approve enjoyment; missing required human evidence leaves closure pending.

## Retained evidence

`artifacts/local/sprint-0/closed/` retains the clean-checkout verification, native reports, CI run/log/timing/artifact receipts, fresh reviews, visible-2 screen/Exit receipt, runner cleanup and repeated closure result. The earlier `final/` directory retains the pending closure; the first `closed/visible/` attempt records the capture timeout separately from the successful repeat. Local evidence is ignored by Git. The committed closure manifest names its exact hashes; restore those files at the pinned source to replay the receipt checker, or regenerate evidence through the documented gates. Windows execution and Pillars/enjoyment remain untested.
