# Alpha handoff: checkpoint 1 passed, 3 October 2026

**Checkpoint 1 passed** (playtest entry 12, EV-0624). Andrew: "really fun", "getting really close", boss "much, much more refined"; difficulty 2, pacing 3, clarity 4; all seven calls kept. He asked for the full three-world alpha for a multi-hour sitting: "full-send it to complete the game." The hard gate is open: Dig and Highdraft may be built. The coordinator role is back with the Claude session that recorded EV-0623 and EV-0624; Codex owns the Sol asset lane only.

## Wave 6 landed (2026-10-04, f1f753b)

Eighteen units merged plus four fix rounds and two coordinator commits; gate 3 at 1fe63fd: 340 pass, 1 red fixed as f1f753b (test-only), quarantine build_power_curve; Opus gate read PASS+NOTES after fix B.

- HW2: hot-wire choice screen.
- META-6: companion pickups and panel.
- META-7: companion persistence.
- IN2+IN3+IN4: input and settings units.
- F7: stub boss plate and chord.
- META-3: rescue_completed emitted.
- EV1: events unit.
- RL1+RL2: run-log units.
- RS4+RS5: run-save units.
- REC: recorder unit.
- B3: Sol lane.
- C6: Sol lane.
- C8b: music_rows routed by audio.
- BS1: Sol lane.
- SC2+SC3: Sol lane.
- T1b: Sol lane.
- T5: Sol lane.
- T7a: Sol lane.
- ZS-E: Sol lane.
- Fix rounds A-D (A, B Sonnet; C, D Opus) and two coordinator commits (1fe63fd hot-wire mount, f1f753b growth test).

### Open after wave 6

- Plating retirement landing (branch wt/alpha-w6-f6 at 6677330, own gate running).
- Worlds two and three as real build tracks, per Andrew's ruling that the alpha is three worlds plus the final boss.
- The field-note collection triggers: none is unlockable in play.
- The hero relic and evolved toppers are still mapped to rare_plus.
- The explorer bot wedges on the Reach camp path.
- Tally and the remembered cannon are out of this candidate.
- Nothing has been played by a human yet.

## Wave 5 landed (2026-10-04, b927aec)

Twelve units merged; gate 3 receipt `artifacts/local/alpha/wave5/gate3.log`, Opus gate read, fix rounds A-D.

- F2b: Brindle plate, ring and chord.
- RS3+RS6: the run save lives in the run flow, one retry per world, Continue on the title.
- CG2: cogs shown everywhere, plus a cog tick.
- META-1+2: Tarn, Sable and Rivet open, locked cards tell the truth, rescue_completed signal.
- HW1: hot-wired offer API and Spark Tread.
- F5: stub boss per world row.
- META-5: companion escape window.
- SC1: enemy camps.
- C2: topper glb.
- IN1: look settings.
- D2: archive sweep.
- ZS-D2: the default table is the alpha ruleset.

### Open after wave 5

- The hot-wire choice has no screen (HW2, wave 6).
- The stub boss has no plate or chord (landed in wave 6 as F7).
- Nothing emits rescue_completed (landed in wave 6 as META-3).
- The companion has no pickups or panel (META-6) and is not persisted (META-7).
- Death, then quit, then Continue costs no retry (owner call).
- The explorer bot wedges at (63,28.5,3) walking to the Reach camp (driver pathing).
- The cog icon still means mass in the armour gauge (icon decision).
- Discovery burst and boss spill pay no cogs.
- music_rows is not routed by audio (landed in wave 6 as C8b).
- Plating-fight code is still present (F6, wave 6).
- The build_power_curve quarantine is still open (F6).

## Wave 4 landed (2026-10-04, aee2242)

Eleven units merged; gate 2 receipt `artifacts/local/alpha/wave4/gate2.log`, then the Opus gate read. Default table swap (D2) was pulled from the candidate and re-queued as ZS-D2 in wave 5 with its gate-1 failure list. Wave 5 landed at b927aec (see above).

- F2a: Brindle's hull is a posture body on the boss contract.
- RS2: run store on disk with a tombstone on clear and a stale-save refusal (cause run_ended).
- CG1: the cog wallet; shop and fabricators spend cogs, scrap raises mass only.
- F4: world-one Warden fights tested on real maps.
- B1: smash damage per fight in the run log.
- ZS-C: zone schema and test-time zone slots for world-one maps.
- ZS-D: the Weir retired from the alpha table path (default swap itself is ZS-D2).
- C5: lore wiring; zone-entry exchanges advance on interact only.
- C8: music rows and a pack resolver (data layer).
- B2: the explorer bot's two-hook hand.
- TR1: tree depth cap follows the stage table's world index.

### Open after wave 4

- Shop UI still says scrap (CG2, wave 5).
- Brindle has no plate/arc/chord read and emits no posture signal (F2b).
- A stagger does not cancel a Brindle charge in flight (design call, open).
- Hero gate toppers for relic and evolved map to Topper_rare_plus until tools/blender/reward_gate.py is regenerated.
- run_seed is unused by offers.
- No field note can be unlocked in play (lore collection triggers).
- music_rows.gd is not routed by audio.gd.
- TR1's world.gd:610 stage schedule and the Sable route migration.
- Default table swap re-queued as ZS-D2 with its failure list.
- B2 explorer chain band unmet (5/16 seeds reach combo 2).

### Lessons for briefs

- Name every suite-wide invariant (bus signal rows plus the ROWS_HASH re-pin, pinned sets, has_method guards on enemy calls, the verdict line format, the per-test 180 s cap) and ask writers to run the sibling tests their fence can break.
- Name which table a test runs on (the default table is now the alpha ruleset; legacy FirstWorld holds the full catalogue). Any test asserting counts of sites, pilots, trees or parts must derive them from the table.
- A modal that pauses the tree must check game.bot_driven.
- A deferred add_child on the game leaks at exit when a test frees the game the same frame.
- A gem's part can complete an evolution, so count parts by id.

## Wave 3 merged (4 October, proto/alpha 13fe55a)

Twelve units merged after two gate runs; gate 2 passed except the quarantined build_power_curve_test. Receipts: `artifacts/local/alpha/wave3/gate1.log` and `gate2.log`; ledger rows in `tools/coordinator/lane-ledger.tsv`, design calls in `DESIGN-NOTES.md`, rulings in `docs/decisions.tsv`. Units: F1 boss contract, ZS-B alpha table, RS1 entrance document, RR1 rarity ladder, META-4 companion model, C3 wind-up rows, C4 lore rows, F3b guard-rack burst, C1 hero asset guards, ZS-A Spillway zone 1-1, T8 nightly runner, D1 DESIGN-V3.

**Wave 4 ran** from base 13fe55a (landed at aee2242, see above): Claude units F2a, RS2, CG1, F4, B1; Sol units ZS-D, ZS-C, D2, C5, C8, B2, TR1.

**Wave 5 candidates:** F5, F6, RS3, RS6, CG2, META-1..3, HW1, EV1, RL1, RL2, SC1..3, C2, C6, C7, T1b, T5, T6, T7a/b, IN1..4.

### Open after wave 3

- spine_crush_test and spine_heft_test still drive from (-110,-120) across the new causeway and strike slower; they pass, but it is no longer flat ground.
- No test runs the alpha swarm Warden end to end through flow; the rack's proximity-scatter path is untested.
- T8 has had no real nightly run (dry-run only).
- DESIGN-V3 needs a line per later wave.
- The entrance document, cogs, companion and run_seed have no consumer yet.
- shop.gd fallback once minted old-id recipes (fixed in the review round).
- Playtest entry 12 lacks Andrew's hand label; `npm test` fails on it. Pre-existing, Andrew's.

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
