# Dress push: where to resume

Read this first after a usage limit, an account switch or a fresh session. The approved plan is `/home/andrew/.claude/plans/let-s-plan-an-agent-dazzling-shamir.md`; the board is [DRESS-MANIFEST](DRESS-MANIFEST.md); rulings P-R1 to P-R4 are in `docs/decisions.tsv`.

## How units run

- Dispatch: `sketches/core-loop/tools/coordinator/sol_dispatch.sh --role write|verify|judge --wave wN --unit ID --cwd DIR --brief FILE [--add-dir DIR]`, one harness background task per unit. Receipts: `artifacts/local/alpha/push/<wave>/<unit>/<role>/` (cmd.txt, run.log, report.md, exit, summary.txt).
- Writers are `gpt-6.1-sol` high on the fast tier (`service_tier="priority"`); verifiers `gpt-6-astra` high; judges read-only Sol. Up to 8 writers and 3 verifiers at once.
- A Codex process outlives a Claude session. Before relaunching a unit, check `exit` in its receipt folder and `ps -eo pid,args | grep 'codex exec'`.

## State

| When (UTC) | Wave | In flight | Next step |
| --- | --- | --- | --- |
| 2026-10-06 17:50 | w1 | D1 to D8 direction sheets (writers, cwd `artifacts/local/alpha/push/w1/<D>/out`, briefs in `w1/briefs/`). D2 relaunched once after an instant kill (exit 137, empty log). | Read each report; build the review page; cut wave 2: the five salvage ports (C19 gyro jammer, C20 swatter, C21 ramp flipper, C22 catch trap, C31 reactor, branches `codex/asset-cNN` in `artifacts/local/visual-development/look-pass-4a` of the main checkout), the dress coverage test and wiring unit, and the first enemy builds from D3. |
