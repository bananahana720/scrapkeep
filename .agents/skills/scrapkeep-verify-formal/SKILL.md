---
name: scrapkeep-verify-formal
description: "Verify Scrapkeep invariants across 11 TLA+ specs (RunFlow, Rewards, HazardCycle, ParkFlood, Destructibles, YardLock, EarnedSave, DeferredEffects, BrindleReel, SoundArbiter, WeaponCadence) with TLC. Use when editing flow.gd, launch_take.gd, game.gd, profile.gd, safe_store.gd, run_store.gd, progress.gd, storm_seek.gd, natural.gd, hazard_hits.gd, event_director.gd, destructibles.gd, stage_locks.gd, overtime.gd, combat.gd, bolts.gd, boss.gd, boss_rules.gd, weapon_driver.gd, music_arbiter.gd, melody_lease.gd, deck_moves.gd, audio.gd, or ace_sequencer.gd, or when asked to formally verify; qualifying tests stay in scrapkeep-verify, and playing the game stays in scrapkeep-verify-game."
---

# Verify invariants with formal TLA+ models

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill runs finite-state TLC checks across eleven TLA+ specifications (`F=.agents/skills/scrapkeep-verify-formal`). It complements tests (`scrapkeep-verify`): TLC tries every modeled interleaving and interruption, while timing in real seconds, physics geometry, and rendering stay in Godot tests.

## 1. Check whether code drifted

1. For any model you touch, run `git diff --stat <sync commit> -- <files>`, taking `<files>` and the last-line `<sync commit>` from that model's coverage page (`scripts/gate/model-receipts.mjs` parses the exact same fields). That comparison reads the working tree too, so uncommitted edits appear immediately. (VFM-09)
2. With non-empty diff output, inspect every modified covered function and check for new callers or new state-changing transitions (VFM-05, VFM-06). If a named guard moved, flip its constant in `models/make-*-configs.sh`; otherwise update the model before running TLC, never afterward to force a pass.

## 2. Run TLC and receipts

1. Regenerate `.cfg` files for the 10 scripted models: `for s in $F/models/make-*.sh; do bash "$s"; done` (`WeaponCadence.tla` uses static `models/weaponcadence-*.cfg` files with no generator script). (design choice)
2. Run all 11 gate receipts (requires Java and `tla2tools-1.7.4.jar`; see `project-guide/handoff/DEVICES.md`): `node scripts/gate/model-receipts.mjs --jar "$TLA2TOOLS" --out <out-dir>` (pass a scratch folder under `artifacts/local/` or `--row <row-id>` for one model). The script fails on dirty source or missing planted mutant breaks (VFM-03, VFM-07).
3. Run an individual config into an isolated scratch folder outside `sketches/` using `java -XX:+UseParallelGC -cp "$TLA2TOOLS" tlc2.TLC -workers 4 -metadir /tmp/tlc-out -config $F/models/<cfg>.cfg $F/models/<Spec>.tla`, or use `pstack`'s `statechart` skill on the spec and config. Multi-process `Rewards.tla` configs want `-workers 4`; run `rewards-reach` probes individually because `-continue` crashes TLC 1.7.4.

## 3. Read a break and replay it

1. Translate any `today-*` counterexample trace into code steps using the matching coverage table. (VFM-02)
2. Replay in place against Godot (no copy into `tests/` needed, VFM-13): `"$GODOT_BIN" --headless --path sketches/core-loop --script $F/replay/<script>.gd` (with isolated `HOME` on macOS or `XDG_DATA_HOME` on Linux). Run the sync commit as control when debugging a new change. (VFM-09)
3. If the replay cannot execute the trace step in real code, model the missing guard constant (keep a `broken-*` config that disables it) and record a lesson. If it reproduces, log the bug in the model's findings doc, and update `make-*.sh` + sync commit once fixed. (VFM-01, VFM-03, VFM-04, VFM-11, VFM-12, VFM-14)

## 4. Models index

| Model | Receipt row | Generator | Coverage & findings | Core scope |
| --- | --- | --- | --- | --- |
| `RunFlow.tla` | `run-always-ends` | `make-configs.sh` | [coverage.md](references/coverage.md), [findings.md](references/findings.md) | Run transitions, launch swipe, Warden vanish, retry/end |
| `Rewards.tla` | `rewards-banked-once` | `make-rewards-configs.sh` | [rewards-coverage.md](references/rewards-coverage.md), [rewards-findings.md](references/rewards-findings.md) | Achievement grant idempotency & durability across 2 processes |
| `HazardCycle.tla` | `hazards-hit-everyone` | `make-hazard-configs.sh` | [hazard-coverage.md](references/hazard-coverage.md) | Storm sought lightning tell, stalled vs rolling, enemy/ball hits |
| `ParkFlood.tla` | `flood-never-held` | `make-flood-configs.sh` | [flood-coverage.md](references/flood-coverage.md), [flood-findings.md](references/flood-findings.md) | Flood fill expiry, 2 s ball hold cap, ground cap, BF findings |
| `Destructibles.tla` | `destructibles-safe` | `make-destructibles-configs.sh` | [destructibles-coverage.md](references/destructibles-coverage.md), [destructibles-findings.md](references/destructibles-findings.md) | Heft tiers, blast/cap charges, scrap/cog/cons caps, shatter cleanup |
| `YardLock.tla` | `yard-lock-safe` | `make-yardlock-configs.sh` | [yardlock-coverage.md](references/yardlock-coverage.md), [yardlock-findings.md](references/yardlock-findings.md) | Yard ring lock, Warden wake unlock, overtime bell, P7 fixes |
| `EarnedSave.tla` | `earned-save-safe` | `make-earnedsave-configs.sh` | [earnedsave-coverage.md](references/earnedsave-coverage.md), [rewards-findings.md](references/rewards-findings.md) | Spare Frame death save across refused writes, quits, restarts |
| `DeferredEffects.tla` | `deferred-effects-safe` | `make-deferred-configs.sh` | [deferred-coverage.md](references/deferred-coverage.md), [deferred-findings.md](references/deferred-findings.md) | Depth-1 deferred queues, procs, shot bits, marks across resets |
| `BrindleReel.tla` | `brindle-presses` | `make-brindlereel-configs.sh` | [brindlereel-coverage.md](references/brindlereel-coverage.md) | Brindle reel cadence across phases 1–3, tell floor, cued follow-ups |
| `SoundArbiter.tla` | `sound-arbiter-safe` | `make-sound-configs.sh` | [sound-coverage.md](references/sound-coverage.md), [sound-findings.md](references/sound-findings.md) | Deck priority stack, melody lease, trim epochs, deck pump/shots |
| `WeaponCadence.tla` | `weapon-cadence-safe` | static `weaponcadence-*.cfg` | [weaponcadence-coverage.md](references/weaponcadence-coverage.md) | All 6 pilots (`press`, `tap_charge`, `lob_snap`, `beats`, `stamp`, `lock`) |

Always run reachability probes (`reach-*` / `-reach*`) after model changes to verify actions stay reachable. (VFM-08, VFM-10)

## Lessons and updates

[references/lessons.md](references/lessons.md) holds VFM-01 onward (`established`, `provisional`, `retracted`). On any retracted lesson, fill `Overturned by`, update this skill in the same commit, and append a `## Changelog` row. Re-sync models after unverified code edits using `/pstack:maintain-formal-verification-skill`.

## Host adapter

- Antigravity: `/scrapkeep-verify-formal`. Run TLC via `run_command` and report active Gemini model/tier.
- Claude Code: `/scrapkeep-verify-formal`.
- Report actual model and active effort or tier metadata (or its absence).
