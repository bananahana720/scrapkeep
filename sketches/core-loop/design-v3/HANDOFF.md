# Alpha handoff: checkpoint 1 passed, 3 October 2026

**Checkpoint 1 passed** (playtest entry 12, EV-0624). Andrew: "really fun", "getting really close", boss "much, much more refined"; difficulty 2, pacing 3, clarity 4; all seven calls kept. He asked for the full three-world alpha for a multi-hour sitting: "full-send it to complete the game." The hard gate is open: Dig and Highdraft may be built. The coordinator role is back with the Claude session that recorded EV-0623 and EV-0624; Codex owns the Sol asset lane only.

## Wave 2 merged (3 October, proto/alpha fbd6bc6)

HC2 (readout) and HC3 (chain log and codex card) are in: gate 2 on tree 0f36041, 295 runs, 0 unquarantined failures; receipts in `artifacts/local/alpha/wave2/`. The hook chain is complete as specified; Andrew has not played it. Open after this wave: a still of combo 4 with its rings and counter (needs the GPU and workspace 10), the bot band after HC3 (skipper smash damage per fight up no more than 10%; explorer best_combo median ≥ 2 over 16 seeds with a two-hook script), and the HC2 debt in the ledger. Next per ALPHA-PLAN: M2 world one, Spillway as zone 1-1, both Wardens on the posture contract, Brindle, rescue progression, run save. Performance claims wait for a GPU-free measurement.

## Wave 1 merged (3 October, proto/alpha 8601e9e)

HC1, AS and RL are in. Gate 3 on tree d67fc25: 293 runs, 0 unquarantined failures; receipts and the Opus gate's findings in `artifacts/local/alpha/wave1/RECEIPT.md`, ledger rows in `tools/coordinator/lane-ledger.tsv`, design calls in `DESIGN-NOTES.md`. Three brief-caused gate failures taught the invariants every wave 2+ brief now names: a verdict line `name: PASS|FAIL`, a ROWS row plus `GRAMMAR_SIGNALS` and an `attack_rows_test` hash re-pin for every new bus signal, the `legibility_rows_case` LINE_ROWS set and the `objectives_case` walk. Wave 2 is HC2 (readout) and HC3 (chain log and codex card) on `wt/alpha-w2-hc2` and `wt/alpha-w2-hc3`, dispatched 3 October. Veto list for Andrew: the plate says "Find an activity" until every site is done; a rewind press is not a miss; the combo pays the chained enemy only.

## First wave of the full-send round (historical, briefed and merged)

| Unit | Spec | Owner files | Tier |
| --- | --- | --- | --- |
| HC1 hook chain state and rule | [HOOK-CHAIN.md](HOOK-CHAIN.md) | `src/combat/chain.gd` (new), `src/movement/player_ball.gd`, `src/core/event_kinds.gd` chain rows | medium (worker), alone and first |
| AS activity signposting | scout read, 3 Oct: `ui/edge_markers.gd:43-55` `targets()` returns Warden else beacon only; `core/objectives.gd:15-27` has no activity row; the sites are `ctx.activities.sites` with `done` flags (`world/activities.gd:119-133`) | `src/ui/edge_markers.gd` (one amber marker per unfinished site, from drop-in, hidden while the Warden fight is engaged), `src/core/objectives.gd` (nearest-activity row before the Warden row) | medium (worker) |
| RL run-log instrumentation | scout reads, 3 Oct: `prompts_shown` is initialised at `run_log.gd:160` and never incremented; `key_glyphs.gd` has no hook; `packs` appends the faction at `run_log.gd:283`, kinds are in the signal | `src/core/run_log.gd`, `src/ui/key_glyphs.gd` (rising-edge `prompt_shown(verb)` on `game.events`), `src/core/game_events.gd`, tests `spine_run_log_test.gd:96`, `traversal_measure_test.gd:164` | easy (hand) |

HC2 and HC3 (readout, miss cost and log) follow HC1 in one wave. Then M2 world one per ALPHA-PLAN: Spillway as zone 1-1, both Wardens on the posture contract, Brindle, rescue progression, run save. Performance must be re-measured with the GPU free before any perf claim: the sitting ran beside a GPU research loop and the ACE ring ran dry three times.

Housekeeping owed when no agent is live: 69 worktrees, 112 unmerged branches (most `codex/job-*` of 2 October), 23 untracked `.uid` files on `main`.

## Recovery record (historical, 3 October)

Continue the existing [alpha plan](ALPHA-PLAN.md) and [roadmap](ROADMAP.md). The old v3 resume queue is historical at Git base 619b8f4 and in the recovery evidence; its music, performance and ledger work has already been integrated or given a recorded disposition. Do not restart those units.

## Current authority and location

- Integration: proto/alpha in /home/andrew/Projects/scrapkeep/.claude/worktrees/game-completion-plan-75f776. Recovery started at 619b8f43c60ef1033825815f5661d48c05af434f; main remains f5848c7 until the human checkpoint.
- Andrew approved implementation of the refined completion plan on 3 October. Three worlds, six pilots, modular SPIL-9, between-run camp, 30-to-45-minute run, one death retry per world, free unfinished-zone quit/crash replay. Mind ends the campaign.
- Hard gate: Andrew plays the checked Cable Reach before any Dig/Highdraft map or encounter is constructed. Existing concepts and probes are reusable evidence, not complete worlds.
- Dirty owner edits to Bible, decision list, persistence ADR and sitting sheet were copied and hashed under artifacts/local/alpha/recovery-2026-10-03/owner-baseline.json before reconciliation. The untracked verifier configuration is preserved.

## Immediate recovery queue

| Work | Exact source | Disposition |
| --- | --- | --- |
| Gamepad through menus | codex/job-522d27958f71f23dce5a-83d4eaf1db at 286327f | Fresh source review and clean executable gate passed; fast-forwarded into proto/alpha. Final combined tree qualification is recorded in the recovery record. Physical controller still pending |
| Shared beds on probe pieces | codex/job-2ec11c941dc3cff32a9a-6326a97874 at 515f919 | Reuse selected shader/material method after scoped admission; old probe game.gd must not replace current routing |
| Sculpted rock round four | codex/job-6ed433780b1c4b65e634-93e2af44ab at f14cb70 | Preserve recipes and assets; look and collision/integration still need their own evidence |
| DEM Reach probe | codex/job-f5d2ad54607f25e58070-f7b5ee946f at e24de55 | Throwaway terrain experiment; reuse feasibility findings, not whole-branch gameplay |

The three visual branches share older base a56959e; their changed assets and probe paths differ from current alpha. No new look rounds before the sitting, per the existing decision trail.

## Next dependency-ready work

1. Freeze the combined recovery tree, finish its exact-tree gate and Cable Reach checkpoint, then record the sitting status in artifacts/local/alpha/recovery-2026-10-03/RECOVERY.md. The 286327f source gate already passed; documentation reconciliation changes the final tree and requires another gate.
2. Ask for the existing five sitting answers. A miss allows at most ten corrective units and one more sitting; further misses require a re-plan.
3. After the verdict, finish world one while reusing the six new-kit probes. Build Tarn, Tally and cannon; a weak probe refines the required kit.
4. Settle durable run continuity and companion assembly before freezing world rewards. Then build the later-world greybox, dress the campaign, finish camp and export.

## Verification and limits

Use the approved sketch:gate and sketch:checkpoint commands and source-bound receipts. The one known build_power_curve_test quarantine belongs to the M2 Warden conversion; do not loosen its bands. Physical gamepad, current alpha fun, look/audio in play and mid-tier hardware remain unqualified. A full cold exported campaign is not yet available.

The reviewed 286327f gate ran 289 checks with zero unquarantined failures, one expected headless audio skip and the existing power-curve quarantine. Documentation checks passed after reconciliation. Eight dependency-hash mismatches predate recovery; their baseline comparison is retained rather than repinning old contract claims. Final integrated checks and the exact launch candidate are in the recovery record.

Use current runtime capabilities and pinned model roles. Historical claims that Codex cannot use Git or must run only in a visual clone are superseded. Native windows stay off Andrew's workspace; GPU work takes the existing lock. Preserve both browser proofs and all unrelated owner changes.
