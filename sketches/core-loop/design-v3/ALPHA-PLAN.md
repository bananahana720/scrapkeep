# Scrapkeep full alpha plan

Status: ready for review. Built from three explorations, one architecture design, a five-lane design workflow with three critics, and a testing workflow with two critics. Nothing was run or changed.

## What approving this plan authorizes

1. The alpha program in `sketches/core-loop` under the light play lane, on branch `proto/alpha`.
2. A bounded tooling scope outside `sketches/` for the test runner units T1, T2, T4 and T8 (`scripts/`, `package.json`).
3. Rule-text edits to `ORCHESTRATOR.md`, `TRACKING.md`, `AGENTS.md`, the verifier agent and the task skill, as listed under Records.
4. Pushing main to the private GitHub repo at each checkpoint.
5. Step zero. Delete two stray untracked files, `sketches/core-loop/tests/=100` and `=600`, left by a reader agent's shell redirect during this planning session.

It does not authorize promotion to `native/`, new dependencies, paid services, an engine change, or any world two or three map or encounter before the checkpoint 1 verdict.

## Context

Andrew played the lab builds on main (`f5848c7`) and found the game "okay" but "hollow and shallow". He wants a full early-access alpha he can sit with: three worlds, four pilots, item systems, achievements, customization, story, art, animation and music at one consistent level.

His answers on 2026-10-01 changed the brief.

1. The core feel is not there yet on all four axes. Controls and camera, impact and feedback, direction and readability, and the fight loop itself.
2. None of the lab's Warden loops is the game. He wants zonal open stages worth exploring, setting-specific mechanics per world, side activities and secrets, and action-RPG feel inside a roguelite run. References are Risk of Rain 2, Gunfire Reborn, Monster Hunter and Elden Ring.
3. Testing has been the bottleneck. He wants steady speed with no loss of quality and no pile-up of debt.

So the program makes one zone click first, proves it with his play, then scales to three worlds on a test method that stays fast as content triples. Content cannot fix a loop that does not click (playtest entry 8).

## Rulings (Andrew, 2026-10-01)

| Topic | Ruling |
| --- | --- |
| Genre | Roguelite run, action-RPG feel, zonal open stages. The pilot stays in the ball. |
| Worlds | Spillway Works, then the Dig (underground), then the Highdraft (floating flotilla). Two big zones plus a world boss each. |
| Run | One run crosses all three worlds, about 60 to 70 minutes, saved at each zone entrance. Death restarts the zone with one key. |
| Roster | Sable at start. Rivet and Kest unlock through play. Tally is a late secret unlock. |
| Harpoon | Every pilot's right-click verb, soft-lock. |
| Lab extras | All become defaults. Flags and old paths get deleted. |
| Warden loop | Drop, laps and v2 all lost. Maps and boss fights are redesigned and judged by play. |
| Controls | Too many keys, ball handling, aim and camera, abilities lack snap. |
| Side content | Combat challenges, contraption puzzles and secrets, camp quests with characters. |
| Input | Keyboard and mouse first. Gamepad after world one is complete. |
| Cadence | Multi-day program, playable checkpoints on main, pushed to the private GitHub repo at each checkpoint. |
| The one gate | He plays checkpoint 1 before any world two or three map or encounter is built. |

These replace the world-one scope lock (ROADMAP, 2026-09-28) and the Bible's four-world line. Both get amended in the records unit.

## Program shape

The vehicle is `sketches/core-loop` under the light play lane. Nothing is promoted to `native/`. The integration branch is `proto/alpha`, cut from `f5848c7`. The coordinator alone merges to main.

| Milestone | What lands | Done when | Estimate |
| --- | --- | --- | --- |
| **M1 Click slice** | One zone (the Cable Reach) that feels good, with two fight structures to compare | 22 units merged, admission bands green, perf in budget, sitting sheet ready. Andrew plays. This is the hard gate. | 6 waves |
| **Track A** | Structure, test tooling, records, asset reconcile, two terrain probes | Runs beside M1 from day one. Touches no file the slice touches. | 4 waves |
| **M2 World one** | Two zones, two Wardens, Brindle on the new fight, three pilots, Rivet's unlock, world-one items, relics, achievements, lore, art and music, gamepad, run save | Checkpoint 2 on main. A full world-one run with a profile. | about 55 units |
| **M3a Worlds in greybox** | The Dig and the Highdraft playable end to end. Mechanics, four zones, six enemies, four Wardens, two world bosses | Checkpoint 3 on main. A full three-world run in greybox. | about 55 units |
| **M3b Worlds dressed** | Art, textures, wind-ups, music and lore for worlds two and three, by layer across both | Checkpoint 4 on main. | about 55 units |
| **M4 Alpha** | Tally, cosmetics, full achievements, home codex, ending, export, how-to-play | The exported Linux build launches cold and a run can be won. | about 35 units |

About 235 units. At 4 to 5 merged units per wave and 5 waves per coordinator day that is 11 to 14 working days plus Andrew's sittings. This is an estimate. The binding limits are his play time and the single GPU, not writers.

Worlds two and three go greybox first, then art by layer. Past asset batches accepted about half of builds on the first pass, so a cut at any date must still leave a consistent game.

## M1. The click slice

**Zone.** The Cable Reach (`src/world/map_gorge.gd`). It already has a landmark, three layers, five transitions and the contraption set. It moves to slot 1 so the ACE music plays there.

**What Andrew compares by playing.** Two axes, one `--variant=` row, losers deleted after his verdict.

| Axis | Arm A | Arm B |
| --- | --- | --- |
| Fight structure | **Hunt.** The Warden roams between three lairs on a telegraphed route. Zone toys hurt it (drop a tank on it, scald it, collapse a floor). Activities arm more toys. | **Duel.** A fixed arena built for the ball with swing pillars, ramps and a lift. Pilot verbs build posture. Zone growth and armed arena toys decide the pace. |
| Harpoon input | **Hold to reel.** Press fires, hold reels, release flings. | **Auto-winch.** Press fires and a body line winches by itself. |

Every other choice ships as one opinionated default, logged in `docs/decisions.tsv`.

**Design defaults in the slice.**

- **Controls.** One table, `src/core/bindings.gd`. Nine verbs in play. No key has two meanings in the same ball state, checked over a state table. The C dash, the wheel reel and F1, F3, F4 leave play. The first minute shows four slots and the rest fade in on first use.
- **Camera.** Profile rows in `chase_camera.gd`. Fall lead, boss framing, an 88 degree cap. On mouse the lock changes arm, pitch and field of view only. Damage taken never shakes.
- **Impact.** One `IMPACT` table in `event_kinds.gd` read by `weapons.gd` and `juice.gd`. Knockback differs by weapon. One hit-stop clock. Heavy hits interrupt wind-ups.
- **Enemy state on the body.** Cracks and plate cues on the part. "Latched" shows at the line's bite point. No floor rings, because the floor belongs to hostile telegraphs.
- **Direction.** One `src/core/objectives.gd` board feeds the HUD plate, edge markers, a world beacon and the map. A glyph, five words or fewer, a distance chevron.
- **Boss chassis.** Posture and a stagger are the single "hit it now" read. The 20 percent chip moves from health to posture, scaled by punch against plating, so there is still no hard wall. Health drops only in a stagger. The gun builds posture at a real rate on the telegraphing part.
- **The ordinary fight.** Two or three authored pack types per region, one elite with a visible modifier, a time-to-kill target per heft class, loot popping at speed.
- **A prize on the map.** One relic on a pedestal behind a contraption secret. Taking it asks for E.
- **Level-ups.** XP from discovery, activities and elites. Two or three picks land inside the one zone.
- **A zero-activity run can win, at a cost.** The low-gear self-challenge stays legal.

**Units.** Paths are under `sketches/core-loop/`. One owner per file across the whole slice.

| Wave | Unit | Goal | Writes | Tier |
| --- | --- | --- | --- | --- |
| 0 | R1 | Playtest entry 9 and its verdict line from today's answers | `docs/playtests/PLAYTEST-LOG.md`, `verdicts.ndjson` | coordinator |
| 0 | K0 | Probe, then flip the lab flags to their winners and mend the tests | `src/movement/tuning.gd`, flag-passing tests | medium |
| 1 | C1 | Bindings table, key cleanup, one hit-stop clock | `src/core/bindings.gd` (new), `src/game.gd`, `src/movement/intent.gd`, `src/ui/key_glyphs.gd` | medium |
| 1 | C2 | Harpoon canon, both reel arms, verb on the aim record | `src/movement/harpoon.gd`, `player_ball.gd`, `augments.gd`, `augment_kit.gd` | medium |
| 1 | C3 | Camera profiles | `src/movement/chase_camera.gd` | medium |
| 1 | C4 | Impact table, no shake on damage | `src/core/event_kinds.gd`, `src/presentation/juice.gd`, `src/combat/weapons.gd` | medium |
| 1 | C5 | Flinch, stagger, interrupt, state marks on the body | `src/combat/enemy.gd`, `src/presentation/status_marks.gd` (new), `presentation.gd` | medium |
| 2 | B0 | Posture chassis and loop-mode deletion as one unit. Merged alone, first. Fable review. | `src/combat/warden.gd`, `boss_posture.gd` (new), `warden_drop.gd` and `loop_mode.gd` and `lap_course*.gd` (deleted), `src/core/flow.gd`, `stage_defs.gd`, every `LoopMode` reader | hard |
| 2 | O1 | Objective board, plate, beacon, edge markers | `src/core/objectives.gd` (new), `src/ui/hud.gd`, `objective_view.gd`, `edge_markers.gd` | medium |
| 2 | Z1 | Zone schema, validator and seeded slot filler | `src/world/stage_map.gd`, `zone_schema.gd`, `zone_seed.gd` (new) | medium |
| 2 | PK | Pack loop and one run-wide clock | `src/world/director.gd` | medium |
| 3 | Z3 | Retrofit the Cable Reach. Regions, slots, ten hard points, four secrets, a line per pilot | `src/world/map_gorge.gd`, `terrain.gd` | hard |
| 3 | Z4 | Interactables read zone slots | `src/world/interactables.gd`, `interact.gd` | medium |
| 3 | B3 | Boss plate | `src/ui/boss_plate.gd` (new) | easy |
| 3 | WU | Wind-up rows tied to each enemy's own phase timing | `src/presentation/windup_rows.gd` (new) | medium |
| 3 | TL | Run log records activities, secrets, harpoon smashes and time before the Warden | `src/core/run_log.gd` | easy |
| 4 | VH | Hunt arm | `src/combat/boss_hunt.gd`, `src/world/hunt_lairs.gd` (new) | hard |
| 4 | VD | Duel arm | `src/combat/boss_duel.gd`, `src/world/duel_arena.gd` (new) | medium |
| 4 | Z5 | A bounty and a contraption secret | `src/world/bounty.gd` (new), `cracked_cache.gd` | medium |
| 4 | RL | Relic rows, a socket in run state, the pedestal | `src/build/relics.gd`, `src/world/relic_pedestal.gd` (new), `src/core/run_state.gd` | medium |
| 4 | LV | Level-up bar | `src/core/pilot_level.gd` (new), `src/world/world.gd` | medium |
| 5 | BT | Bot policies (camper, lair-chaser, brawler, explorer), admission bands, checkpoint script | `tools/bot_driver.gd`, `balance_report.gd`, `tools/coordinator/checkpoint.sh` (new) | medium |
| 5 | SS | Sitting sheet and the one `--variant=` row | `SITTING.md` (new), `tuning.gd` | easy |

**Admission to play.** Bots and fixed checks only decide whether the build is worth Andrew's time. Each band must be red on the three rejected builds (v2 at `19fc173`, drop, laps) before it counts.

- The hold-fire camper cannot win. An arena-only player can, slower than the explorer.
- The lair-chaser, the real skipper under Hunt, pays a measured cost.
- The explorer wins at least 60 percent of 16 seeds with more heft and more parts.
- Perf on the densest fight at 1080p. CPU main thread p99 at most 10 ms, GPU p99 at most 7 ms.
- Smoke green on the checkpoint SHA and one Fable integrated read.

**What only his play decides.** Written before he sits down and read from his own run log.

- He enters two or more activities unprompted in a run.
- He lands harpoon smashes into packs and keeps doing it.
- He spends time in the zone before the Warden in at least one run.
- He starts a second run without being asked.
- The five sitting questions per arm, then which arms win.

The first five minutes of the sitting are harpoon into an ordinary pack, since no harpoon play is on record.

**If the verdict is "still not there".** One more slice round of at most ten units aimed at his worst frustration, then a second sitting. A third round stops the program for a re-plan with him.

## Track A. Day one, independent of the verdict

| Unit | Goal | Writes |
| --- | --- | --- |
| A1 | Stage and world tables, `ctx.stages`, a two-world test double | `src/core/worlds.gd` (new), `stage_defs.gd` after B0, `context.gd` |
| A2 | Profile store with schema and migrations. Fable review. | `src/core/profile.gd` (new) |
| A3 | Achievement and cosmetic rows with validators | `src/core/achievements.gd`, `cosmetics.gd` (new) |
| A5 | Export recipe and the ACE path fix | `export_presets.cfg`, `scripts/sketch-export.mjs` (new), `src/presentation/ace_sequencer.gd` |
| AR | Copy the asset sheet and judge files from the visual clone into the repo, then merge the clone's accepted assets, rig and clip recipes as one serial integrator merge | `assets/models/`, `tools/blender/`, `src/presentation/pilot_reactions.gd` |
| AB | Asset registry, budget classes and a registry test | `assets/registry.json`, `tools/asset_budgets.json` |
| AM | Reproducible music packaging from a committed sources file | `tools/ace/package_music.py`, `tools/ace/sources.json` |
| P1, P2 | Terrain probes. A Dig tunnel with a second floor and a Highdraft island with a net deck. Check camera, collider and bot pathing. | throwaway branch, findings only |
| T1 to T8 | Test tooling. See the testing section. T1 and T2 run first. | `scripts/`, `tests/`, rule files |
| REC | TRACKING event, decision rows, ROADMAP rewritten to M1 through M4, ORCHESTRATOR stale lines, the Bible's world count | canonical docs, coordinator only |

If a terrain probe fails, that world switches to a setting that fits the heightmap before any M3 unit is cut. The fallback is Pale Basin or Foundry Crown and it goes back to Andrew.

Not in Track A. World two and three music, direction sheets and story arcs wait for the verdict.

## M2. World one complete

- **Fight.** The winning structure extends to both zones' Wardens and to Brindle through a frozen boss contract and a contract test. The losing arm is deleted.
- **Zones.** The Spillway is rebuilt as zone 1-1 by merging in the Weir's halfpipe, mesa and causeway. `map_weir.gd` and `map_sluice.gd` are deleted. The Cable Reach is zone 1-2.
- **Structure.** Flow across worlds, lazy terrain per world, director and Warden family from the stage row, music and HUD from rows (architecture units W1 to W6). A stub boss keeps later worlds completable.
- **Build.** Three layers. Path is the kit tree by level-up. Relics rewrite one slot each and are found on the map. Parts stack tags toward synergies and two evolutions.
- **Economy.** Scrap is size and armour. Cogs are the only spend currency. Cores stay zone-local. One damage order.
- **Rarity.** Common, Rare, Relic, Evolved, with a hot-wired stripe. Scalar-only rows leave everything above Common.
- **Meta.** Profile wired in. Rivet unlocks by a rescue camp quest in world one. About 20 achievement rows. Locked class cards show the achievement text.
- **Side content.** Combat challenges, contraption secrets and one camp per zone with a named reward.
- **Run save.** The existing `run_state.gd` snapshot is written at each zone entrance through `safe_store.gd`. Fable review.
- **Input.** Gamepad bindings, stick look with aim assist, paged settings, rebinding, fullscreen and a quality switch.
- **Content.** World-one asset waves from the clone's 67-unit sheet at its minimum set, painted tileables, wind-up rows, zone and boss music, lore rows with word caps.
- **Docs.** One `DESIGN-V3.md` of 400 lines or fewer, written after the verdict. The other design docs move to `archive/`.

## M3. Worlds two and three

**M3a, greybox, both worlds end to end.**

| | The Dig | The Highdraft |
| --- | --- | --- |
| Mechanic | Breach. Slam marked floors and walls to drop a level or open a route. Slamming through onto enemies is an attack. | Lift. Thermals, moving islands, harpoon swings between them. A fall lands on a net deck, never death. |
| Enemies | Burrower, drill crew, lamp swarm | Line cutter, anchor crew, kite drone |
| Wardens | Meltdown core, brood | The Mind's hand, the choir |
| World boss | The Waking, fought floor by floor | The Mind, bounded and telegraphed, never a hard counter |
| Unlock | Kest's rescue camp | Tally's third fragment |

Each world boss is capped at Brindle's phase count and built on the M2 boss contract. Tree depths three and four become world two and three picks. Six relics per world.

**M3b, dressed, by layer across both worlds.** Direction sheets first, then models, textures, wind-up rows, music takes and lore. Each asset is one unit with its own recipe and files. The production cut order applies. World three reuses world two's textures with a palette shift before anything else is cut.

## M4. Alpha

Tally (ball-only base kit, equips any pilot's relics and transmogs to match), cosmetics and the loadout row, the full achievement set, the home-menu codex, the ending as three fragment cards, title and summary music, the Linux export with stems beside the binary, a README and an in-game how-to-play. Pressure valves and modifiers are the first cut if time runs short.

## Testing method

**What limits speed.** Full-suite runs per merged unit, queued on one machine lock. One core-loop smoke is about 470 seconds at 219 tests (scaled from 388 s at 182 runs in the lane ledger). A per-lane unit pays four runs. A five-writer wave pays seven to nine, close to an hour of lock time. Single-test speed is not the limit.

**What limits quality.** The suite's weight is in the wrong tier. 166 of 219 tests build a full `Game`, yet 31 of the bug hunt's 40 clusters needed no scene. The misses were flag combinations, restart and lifecycle state, table contracts and bugs introduced by fixes. And 153 of the 166 Game tests run the v2 default configuration that this plan deletes, so today's green mostly describes a game that is going away.

**Tiers.** Each tier is cited only for what it can show.

| Tier | Shows | Who runs it | Budget |
| --- | --- | --- | --- |
| Lint | Source contracts. No wall-clock reads in tests, no raw file writes, no dangling flag literals, no stray files | Writer on save, step 0 of the gate | under 5 s |
| Unit and table cases | Rules, boundaries, state machines. Every content row is well formed, its references resolve, and it is reachable (in a drop pool, a spawn table, a zone). One process for all cases. | Writer while building | under 15 s |
| Named tests | The tests nearest the change, by packet list or prefix glob | Writer before handoff. Never merge evidence. | under 60 s |
| Gate | Lint, then the full smoke, then a pinned bot slice, on one exact tree. One command, `sketch:gate`. | Integrator, once per candidate | one run |
| Sweeps | Restart parity (dirty states crossed with restart paths) and a small pilot-by-world covering array in a real `Game` | Inside the gate | inside the run |
| Nightly | Full bot matrix, item fuzz, perf medians, repeat runs for flake rate. A red nightly blocks the next wave's admission. | Coordinator | under 60 min |
| Captures | Rendered stills against references with known-bad controls | Visual units, GPU lock | under 3 min |
| Play | It works as a game | Andrew | his time |

New worlds, zones, enemies, items, relics, achievements and pilots enter through registered tables. A row is covered by the validators, so tripling content adds rows and cases, not processes. Content tables are split one file per world and per pilot so five writers do not collide on one literal. Sweeps assert a minimum row count so an emptied table cannot pass.

**Review shape.** This is the largest saving, so it goes first.

- Writers run lint, unit cases and named tests. They do not run the full smoke.
- The integrator runs the gate once on the merged candidate.
- The coordinator accepts that receipt when admission is a fast-forward to the same tree. The candidate is built on the integration head and admission is frozen during the gate.
- The gate reviewer runs nothing.
- A five-writer wave pays one or two full runs, down from seven to nine.
- Wave k+1 writers start when wave k is handed to the integrator, on disjoint fences.

**Receipts are written by the runner, not typed by an agent.** Tree hash, a clean-tree check, the test list, per-test result and check count, the skip list, whether the gitignored music stems were present, lock wait and durations. A receipt with unexpected skips is not merge evidence. Check counts are diffed against the base, and any drop or removed assertion is listed for the gate to rule on.

**Rules that stop debt.**

- Red then green for every fix, on the same command. The red commit holds only the test.
- Every new test names its rule and carries one broken-rule receipt. The integrator picks the mutation for consequential units and samples one other unit per wave.
- The unit that deletes a flag or variant deletes its tests, its row and its doc line. It ships a triage table (delete, keep and strip, rewrite). Every bug-hunt regression test is kept or has a named reason.
- A refused `set_option` or unknown flag is an error in test mode. Today it is silent and 60 call sites would go green on defaults.
- A flake needs a reproduction on the base commit. Failing only on the candidate is a regression. Only the coordinator edits the quarantine file, at most three entries, each with an owner and a two-wave deadline. No retry loops.
- Scenario tests have a 15 second target. New tests use one shared helper.
- Old-save fixtures for the profile and the run save load on every new build.
- A new world or boss is not done until a bot completes it on a fixed set of seeds.

**Units.** T1 and T2 run on day one. The rest follow in Track A.

| Unit | Goal | Writes |
| --- | --- | --- |
| T1 | `--test <glob>`, a slot semaphore in place of the single lock, the runner-written receipt, the PASS-line rule, the one `sketch:gate` command, and the review-shape rule text | `scripts/sketch-smoke.mjs`, `package.json`, `ORCHESTRATOR.md`, `scrapkeep-verifier.md`, the task skill |
| T2 | Measure. An empty process start, a `Game` build, cold and warm import, one smoke per pool width, and one smoke with the shipping flags forced on. Sets the baseline that later thresholds multiply. | `artifacts/local/test-baseline/`, `design-v3/TESTING.md` (new) |
| T3 | Unit harness and shared helper with three converted cases | `tests/unit/`, `tests/unit_suite_test.gd`, `tests/support/t.gd` (new) |
| T4 | Lint and the quarantine file | `scripts/sketch-lint.mjs`, `tests/QUARANTINE.tsv` (new) |
| T5 | Content registry, a validator per table with a bad-row fixture per rule, tables split per world and pilot, one golden per table regenerated by the integrator | `src/core/content_registry.gd` (new), the table files |
| T6 | Restart-parity sweep and the covering-array scenario. Proved by reverting each of five named bug-hunt fixes in a worktree that has the stems. | `tests/reset_parity_test.gd`, `tests/unit/flag_matrix_case.gd` (new) |
| T7 | Retire wall-clock reads and the solo tail | the 16 wall-clock tests |
| T8 | Nightly script | `scripts/sketch-nightly.mjs` (new) |

T5 merges before the first content wave. T6 merges before the first pilot or boss unit. The exploit gate is unit BT in the slice, and its known-bad control is the entry-8 build reproduced.

**Decisions held for the measurement.** Widening the pool past eight, converting the 35 node-free tests, skipping a warm import, and keeping five standing writer worktrees so the import cache stays warm. Each has a probe in T2 and is built only if its number says so. No move to gdUnit4 or GUT. Its 4.7.2 support is unconfirmed and nothing measured needs it.

**Measures, with the threshold that changes the method.**

| Measure | Baseline | Trigger |
| --- | --- | --- |
| Merged units per wall-hour, and the wave wall split (writing, lock wait, integrator, gate) | unmeasured | set from the first two waves |
| Full-suite runs per merged unit | 4 per lane, about 1.4 batched | above 1.0 for two waves means a role is rerunning. Target 0.5. |
| Brief to merge per unit | 0.6 to 0.7 h batched | median above 0.7 h for two waves |
| Fix rounds per unit | 28 rounds over 35 units | rising two waves running |
| First-gate fail rate, non-environment | 0 of 5 batched | above 1 in 5 returns that unit class to per-lane review |
| Escapes found by Andrew or bots after merge | 1 | any game-breaking escape pauses new units |
| Suite wall | set by T2 | above 1.25 times baseline starts a subtract pass |
| Lock wait | unmeasured | p90 above 3 minutes |
| Flake rate | unmeasured | above 1 percent or more than three quarantined |

**Still a risk.** Named tests can hide a break until the gate, where it arrives in a batch of five. Validators only cover content that enters through tables. Simulation is not deterministic without `--fixed-fps`. Bots do not measure fun.

## How waves run

- **Shape.** Up to five Sonnet writers in coordinator-made worktrees (`scripts/new-worktree.sh`, run from the main checkout), one Opus integrator (`pstack:pstack-worker`) that checks each unit against its receipts, merges a candidate branch and runs the gate once in a detached worktree, then one read-only Opus gate (`scrapkeep-reviewer-medium`). At most two loops, then Andrew. Until T1 lands, the integrator's one smoke is the only full run per wave.
- **Small sequential waves.** Each wave's results are read before the next wave is cut. Nothing here is one large workflow planned up front.
- **Lane rule.** One build and at most one fix round per unit, then merge or park with notes.
- **Fable review** for the chassis and loop deletion, the profile and run save, damage geometry, the world structure seam, every unit after an escape, and the integrated read before each checkpoint.
- **Briefs** use the project packet (GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN, REPORT). Each names its fence, its own test and one rule the test must catch when broken.
- **Board.** `tools/coordinator/lane-ledger.tsv` with wave and milestone columns, TRACKING events at checkpoints only, a decision trail in `docs/decisions.tsv`. No separate pstack board.
- **Machine.** One smoke per wave, never per unit. GPU jobs go through an ordered queue under `/tmp/scrapkeep-gpu.lock`. Native windows open on workspace 10 only.
- **Model pins.** The project agent definitions match the pstack map. One stale line to fix. The task skill says effort high and the definitions say medium.

## Verification

- Per unit. Its own headless test, red then green for fixes, one broken-rule check per new test.
- Per wave. `npm run sketch:smoke -- --sketch core-loop` once on the candidate, the gate's read of the diff and receipts.
- Per checkpoint. `tools/coordinator/checkpoint.sh` runs smoke, 16-seed bots, the report bands, item fuzz and a native perf capture, and writes one receipt under `artifacts/local/checkpoint-<sha>/`. Then the Fable integrated read, the merge to main, `npm run verify` and `check:skills` on main, and the push.
- Never claimed without Andrew's play. That it is fun, that it reads, that the look hits the concept art, that the music works in a fight.

## Risks

| Risk | Probe or guard |
| --- | --- |
| Flipping defaults breaks tests that never mention a flag | K0 first runs every test with each winning flag on and counts failures before any default changes |
| B0 is wide and touches the run spine | Merged alone and first in its wave, Fable review, camper assertion re-homed before the loop tests go |
| The Hunt arm needs a Warden that moves, and it is built as a fixed clamp | A one-day stand-in that carries the existing node along a route polyline before VH is briefed |
| Admission bands pass a hollow build again | Each band must be red on the three rejected builds |
| Caves and floating islands fight a one-height terrain model | Probes P1 and P2 during M1 |
| The visual clone forked 315 commits ago and holds uncommitted sheets | AR copies the sheets first and merges as one serial unit |
| ACE stems are gitignored and the packaging path is dead | AM and A5. Writers test on synth and the checkpoint build verifies ACE at the point of use. |
| Art acceptance near 50 percent on one GPU | Greybox first, minimum set per world, the cut order |
| Andrew's review load | Keyframe approvals, tone samples and music checks are batched into each sitting |
| Six idle boss modules interfere | The boss contract test instantiates two and runs a Brindle fight |

## Records and stale documents

- Playtest entry 9 from today's answers, with the build SHA and a verdict line.
- TRACKING event for the program. ROADMAP's definition of done rewritten to M1 through M4. HANDOFF replaced.
- ORCHESTRATOR lines 34, 36 and 116 (Fable exhausted, flags until the sitting, one writer and no reviewer). TRACKING lines 19 to 21. `AI-WORKFLOW.md` agent map.
- Bible world count and run length. Memory rule 18.
- The home memory note `core-loop-v3-handoff` is superseded once entry 9 is logged.

## What needs Andrew's hands

1. Play checkpoint 1 with `scrapkeep core-loop` and the four variant combinations on `SITTING.md`.
2. Answer the five sitting questions per arm and pick the winners.
3. Approve a ten-line tone sample of lore per world when it appears in a checkpoint note.
4. Approve keyframe sheets for new enemy and boss forms, batched per sitting.
5. Judge music in play at each checkpoint.
6. Launch the exported build cold at M4.

## Reused, not rebuilt

- `run_state.gd` snapshot and restore for the run save. `safe_store.gd` for every new document.
- `UpgradeTree.apply_pick` and its op vocabulary for relics. Three variant ability rows already exist.
- `event_kinds.gd` and the signal bus for achievements, toasts, sound and HUD wording.
- `contraptions.gd`, `interactables.gd` families and `event_director.gd` for activities.
- `tools/bot_run.gd`, `balance_report.gd`, `item_fuzz.gd`, `stress_capture.gd`, `visual_capture.gd` for evidence.
- The clone's asset sheet, judge rubric, pilot rig and reaction clips.
- `native/export_presets.cfg` and `scripts/native-smoke.mjs` as the export recipe.
