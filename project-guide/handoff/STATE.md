# Wave state: the live board, the open wave and carried reds

Heads and open pull requests change by the hour, so read them live (`git ls-remote origin`, the open pull requests, the board's latest comments). This page keeps what a head listing cannot show. The table below is the one place in the repo that names the live board; every other page points here. `npm run check:docs` compares the table with git history and fails when a promotion has landed that the table does not record. The order of what is left is [ROADMAP.md](ROADMAP.md).

## Wave facts

| Fact | Value |
| --- | --- |
| Last promotion | wave 51, main ba4b8bef, direct |
| Open stage | main |
| Live board | none |
| Red team | cautious |
| Compare against | full-alpha-ba4b8bef (26 Nov ruling eq; prior 48-seed baseline w46-s1-ba46f103 on ahana) |

Under [ruling ep](DECISIONS.md) and [ruling eq](DECISIONS.md), work runs directly in flat `main` mode (`Open stage` is `main`, `Live board` is `none`) instead of per-wave `stage/alpha-w<N>` stacking; `Last promotion` records the 26 Nov 2026 Full-Alpha milestone (`ruling eq`) on `main`. For legacy wave promotions, the stage log (`git log --first-parent origin/stage/alpha-w<N>`) held the stack queue and `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>` rotated the table. "Compare against" names the receipts the next full gate reads its base values from, published on a `scratch/gate-receipts-<folder>` branch.

## Now (26 Nov 2026, Full-Alpha milestone on main under ruling eq)

**Full-Alpha milestone closes flat on `main` under [ruling eq](DECISIONS.md)** (`ba4b8bef` plus Mac/Linux determinism re-pins and ledger graduation):
- **Visual, HUD & combat polish (Worlds 1–3):** Borderlands graphic-novel visual/HUD elevation across Worlds 1–3 (ink outlines, boss plates, flourishes, Pilot Select, ending framing, contraptions), BoI Rebirth-inspired risk/reward items/relics/swaps, Molten Slag & Steam element chains, and `120 ms` input buffers with slam-plant cancels.
- **Music pipeline & posture calibration:** Hybrid Stem-Context Gemini CLI + Lyria 3.5 -> `htdemucs` 3-stem `AceSequencer` music pipeline (flagship World 2 and World 3 tracks), plus World 2/3 Warden and boss posture calibration under rulings `ct`, `cu` and `cv` (`posture_bands_mind_test` graduated at `29.6 s` grown, `2.25x` ratio, `0` camper).
- **Tooling, formal proofs, determinism & Linux pack:** Four `/reflect` tooling helpers, 11/11 TLA+ formal proofs synced and passing live TLC, cross-platform `run_tier_test` determinism re-pins on both Mac Studio (`BASE_SCHEDULE_MAC`, `BASE_RUN_MAC`) and Linux `ahana` (`BASE_SCHEDULE`, `BASE_RUN`) graduating `run_tier_test` and `posture_bands_mind_test` off [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv), and packed Linux `Scrapkeep.AppImage` + 4-action `.desktop` launcher. Rule 11 substitution note: Fable 5.2 / Opus 5.5 capacity fallback routed writing to Gemini 4 Hydrogen + Gemini 4 Neon High with independent admitting reviews on fresh Gemini 4 Neon High sessions.

### Earlier (25 Nov 2026, pre-alpha flattened on main under ruling ep)

**Waves 47-50 and open branches flatten onto `main` as a unified pre-alpha baseline under [ruling ep](DECISIONS.md)** across Phases 1-3 (`fc9680f8` plus this gate close):
- **Phase 1 unified pre-UI & W44 wins:** Flattened `w50/pre-ui-unified` (Stages A-D across 26 `w47/*`–`w50/*` branches + `stage/alpha-w47`), rebased `aifirstify_repo_gemini_workflows` (`.agents/` skills, hooks, workflows and `check:agents`), and folded audited W44 wins (`water-flows`, `area-blueprint` reconciled under ruling `ep`, `audit-launch-ring-ramp`, `W1-131`, `W1-137a`, `W1-143b`, `W1-144-mac-launch`). Worlds 1–3 are unparked in `game.gd` and Patch (7th pilot) is active behind `HIDDEN_PILOTS`/`HIDDEN_SHELLS`.
- **Phase 2 art, assets & Stage D UI:** Landed Stage D UI plus 3 UI bug fixes, 21 W50 GLBs, 38 SVGs, and Patch's hidden trail with 0 stand-ins.
- **Phase 3 hygiene, formal models & verification:** Enforced repo-wide `/no-comments` with invariants encoded in types, assertions and tests ([CONTRIBUTING.md](../../CONTRIBUTING.md)), verified 11/11 TLA+ formal models synced at `465769205` under `.agents/skills/scrapkeep-verify-formal/`, maintained the verify skills, synced `E22` (`line_cutter`) telegraph record `0.75 s` against `W49-COMBAT` (`81b3786f9`) in `telegraph_record.gd` and `LEGIBILITY.md`, closed the 2 W50 icon placeholders (`el_heat.svg` generated, dead `obj_press` alias removed -> `placeholder-gate` PASS 0), re-pinned `dam_look_capture.gd` SHA in `display-run.mjs`, taught `budget_audit` clip-only GLBs, and tracked `posture_bands_mind_test` regression (World 3 posture bands after `W47-H1`/`W49-COMBAT`) on [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) (`75/76` `sketch:fast` Godot tests PASS, 0 untracked reds).

### Earlier (22–25 Nov 2026, Wave 46 and Waves 41–45 archive)

- **Wave 46 `ahana` 48-seed baseline (`w46-s1-ba46f103`, cited in `Compare against`):** Promoted in PR `#1279` (`866dc4b05`), calibrating Dam/Flume/Brindle (`W46-S1`, PR `#1277`) and graduating `posture_bands_test`, `posture_bands_reactor_test` (`3.19x` Linux / `2.79x` Mac), and `posture_bands_flume_test`. Full gate logs for Waves 41–45 (`aac84da9f`, `212fb8e0b`, `b5fb45a7`, `a76ccfd3`, `3996f591`) remain in git history on commits prior to `fc9680f8`.
- **Import discipline:** Prepare worktrees with `node scripts/import-stamp.mjs import`; never copy `.godot/` between worktrees (LESSONS 71).

## After promotion and flat-`main` integration

Done for the World 1 sitting is read by `npm run sketch:world1-bands -- --sitting --head <sha>` ([GATE.md](GATE.md), ruling `dt`). On each promoted or milestone update on `main`, run the deep-modules sweep ([DEEP-SWEEP.md](DEEP-SWEEP.md)) and keep `node scripts/wave-state.mjs` and fast-lane timings current.

## Carried reds and findings

A test failure counts as carried only while listed with cause, owner, and review date in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) (ruling `bq`), enforced per check under ruling `dx`. Under `ruling eq`, `run_tier_test` and `posture_bands_mind_test` graduated off the ledger; remaining carried rows live in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv).

Open player-experience findings live in [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) (ruling `cn`) and never hold a promotion. Packed Oggs are gitignored; compare heads and bases with matching Ogg state (23 Oct, `#411`).

## Roadmap & machine rules

See [ROADMAP.md](ROADMAP.md) for remaining work order, [DEVICES.md](DEVICES.md) for Mac Studio and Linux `ahana` capture rules, and [ORCHESTRATOR.md](../../ORCHESTRATOR.md) for gate policy.
