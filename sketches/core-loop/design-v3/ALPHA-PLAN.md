# Scrapkeep full alpha plan

> **Historical plan (1 to 10 Oct). Live execution state lives in [STATE.md](../../../project-guide/handoff/STATE.md) and [ROADMAP.md](../../../project-guide/handoff/ROADMAP.md); rulings are in [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md).**

Status as of 10 October 2026: waves 1 to 20 and dress waves 1 to 12 had landed. [DESIGN-V3](DESIGN-V3.md) owns the historical post-C1 design baseline, and `HANDOFF.md` (`design-v3/HANDOFF.md`, archived in git history) was the earlier handoff log; live status is in [STATE.md](../../../project-guide/handoff/STATE.md). Historical unit lists below preserve planning provenance.

## What approving this plan authorizes

1. The alpha program in `sketches/core-loop` under the light play lane, on branch `proto/alpha`.
2. A bounded tooling scope outside `sketches/` for the test runner units T1, T2, T4 and T8 (`scripts/`, `package.json`).
3. Rule-text edits to `ORCHESTRATOR.md`, `TRACKING.md`, `AGENTS.md`, the verifier agent and the task skill, as listed under Records.
4. Pushing main to the private GitHub repo at each checkpoint.
5. Step zero. Delete two stray untracked files, `sketches/core-loop/tests/=100` and `=600`, left by a reader agent's shell redirect during this planning session.

It does not authorize promotion to `native/`, new dependencies, paid services, an engine change, or any world two or three map or encounter before the checkpoint 1 verdict.

## Context

Andrew played the lab builds on main (`f5848c7`) and found the game "okay" but "hollow and shallow". He wants a full early-access alpha he can sit with: three worlds, six pilots, one assembled combat companion, item systems, achievements, customization, story, art, animation and music at one consistent level.

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
| Run | Three worlds of two stages in fixed order; 30 to 45 minutes. No free retry (replaces "one death retry per world", 22 Oct): every run starts with zero saves, and a death sends you back to world 1 with a fast restart (same pilot, or pick another). A rare earned item can save one death (details to come, DECISIONS 22 Oct). Quit/crash replays the same zone entrance free; stable offers and spent death-save facts survive reload. |
| Roster | Six pilots: Sable initially; Rivet by world-one rescue; Tarn by Brindle; Kest by Dig rescue; Tally by three ledger leaves returned to Moss; remembered cannon by Mind. Newly earned pilots are selectable next run; existing profile unlocks survive migration. |
| Harpoon | Every pilot's right-click verb, soft-lock. |
| Lab extras | All become defaults. Flags and old paths get deleted. |
| Warden loop | Drop, laps and v2 all lost. Maps and boss fights are redesigned and judged by play. |
| Controls | Too many keys, ball handling, aim and camera, abilities lack snap. |
| Side content | Combat challenges, contraption puzzles and secrets, camp quests with characters. |
| Input | Keyboard and mouse first. Gamepad after world one is complete. |
| Cadence | Multi-day program, playable checkpoints on main, pushed to the private GitHub repo at each checkpoint. |
| The one gate | He plays checkpoint 1 before any world two or three map or encounter is built. |

These replace the world-one scope lock (ROADMAP, 2026-09-28) and the Bible's four-world line. Both get amended in the records unit.

### Update after his lab play (playtest entry 10, 2026-10-01 evening)

He played drop, laps and the harpoon build that evening. His opinion of the whole did not change. Six things did sharpen. The first four reorder the slice; the last two add two units to it.

| What he said | What changes |
| --- | --- |
| He liked the v2 loop but could not tell how the Warden fight works, how much health it has, or how to beat it. | The slice's default fight is the v2 structure made readable (the posture chassis, the boss plate, state on the body). The later LEGIBILITY ruling supersedes comparison arms: the posture fight is the only slice fight and no variant row is built. The boss plate (B3) moves up to land with the chassis (B0). |
| The grapple hook with the homing smash was "super fun". | The harpoon ruling is now a play verdict. |
| He cannot tell when he is hooked, grappling does not feel satisfying, and no keys are shown. | The wave after A1 is the harpoon and readability wave: line states with a visible latch, bite feedback from the impact table, and on-screen prompts for the next action read from the bindings table. |
| The map is not fun to traverse, and traversal at speed is the point of the game. | The zone retrofit (Z3) must show a measured traversal line per pilot: a bot holds speed tier 2 or better along it with no dead stop, and harpoon anchors are spaced for a swing chain. It also authors a bay dock at each Warden site, after the bay failed to dock in his third run. |
| Synergies "just happen": he cannot tell what he did or what it means, and the same holds for map mechanics. "There's no why." | New unit WY in the readability wave. When a synergy or a map mechanic fires, the two causes and the effect are shown where it happens (two icons, an arrow, three words or fewer), read from the event table, and the first firing opens its discovery card. A test walks every synergy row and every map mechanic row and fails on one with no callout. |
| He liked that the enemy mechanics are fuller, but the enemies read as "amorphous blobs" and he cannot tell what does what. He wants recognisable designs and better animation. | New unit ER in the slice, ahead of the wind-up rows (WU). A read sheet for the Cable Reach roster: one silhouette and one wind-up pose per mechanic, drawn first and shown to Andrew before any model is built (the storyboard gate). The models and clips then follow the existing Blender recipe template. |

### The legibility spec (2026-10-01 night)

Andrew then gave the coordinator creative charge: decide, fill gaps and cut, and bring him a veto list. [LEGIBILITY.md](LEGIBILITY.md) is the result and is the build spec for the waves after A1. Where it differs from M1 below, it wins: one fight (the posture chassis) with no Hunt or Duel arm and no `--variant=` row, 9 verbs, 6 enemy kinds, standing activities in place of timed events, and its own unit list and gate order (the visual merge, G1, wave R1, B0b, B0a, wave R2, wave R3, then checkpoint 1). The read sheet (ER) covers only what the visual branch has not built: that branch holds nine enemy models, merged in unit AR.

## Current alpha refinements (3 October 2026)

These implement Andrew's approved refinement. They supersede stale historical rows below without authorizing later-world construction before the first sitting.

- **Progression:** one tree per pilot, four safe growth picks, thirty nodes and sixteen endpoints; world-one depth cap two, later worlds depths three and four. Path, Relic and Parts; Common, Rare, Relic, Evolved plus the hot-wired stripe. Scrap is size/temporary armour, Cogs spend, cores zone-local. No permanent stat boosts.
- **Companion:** one SPIL-9 hover chassis, two unordered module sockets and any two different conductive-primer, ram-brace and escape-corridor families. Run-found pieces; acquire without auto-equipping, assemble at intermission. No new combat key or companion health economy. Escape acts after a survived low-hull hit, never revives or spends/refills a retry. Body/chirp cues expose ready/spent state; no recursive procs. Camp pet is separate.
- **Camp:** reuse the approved layout; launch gate, lockers, Moss, achievements, settings, one skee-ball lane, pet/toys, time-trial ghost/medals and any-enemy sandbox. Camp is between runs only. Target roll launch within five seconds or shortcut within two; interim menus support unlocks, ledger returns and assembly before full camp construction.
- **World and story:** reuse the approved Arizona world keyframes, enemy read sheets and terrain probes. Breakable enemy homes stop that kind's stage arrivals and pay scrap. Short skippable Moss/crew exchanges, field notes and item text; the ancient catastrophe stays ambiguous.
- **Look and audio:** approved Sol concepts replace older stills as the look target. Reuse rigs, recipes and existing music gems. Synth composes guides and keyed SFX; ACE performs music; runtime controls dynamics. Your play/listen remains the acceptance verdict.
- **Order:** recover pending candidates and records; freeze Cable Reach and get the sitting verdict; finish world one alongside the new-kit probes; settle persistence and companion before rewards freeze; build later-world greybox; dress worlds and camp; cold-export the complete alpha.

## Program shape

The vehicle is `sketches/core-loop` under the light play lane. Nothing is promoted to `native/`. The integration branch is `proto/alpha`, cut from `f5848c7`. The coordinator alone merges to main.

| Milestone | What lands | Done when | Estimate |
| --- | --- | --- | --- |
| **M1 Click slice** | One Cable Reach zone with the accepted posture fight, harpoon and legible activities | 22 units merged, admission bands green, perf in budget, sitting sheet ready. Andrew plays. This is the hard gate. | 6 waves |
| **Track A** | Structure, test tooling, records, asset reconcile, two terrain probes | Runs beside M1 from day one. Touches no file the slice touches. | 4 waves |
| **M2 World one** | Two zones, two Wardens, Brindle on the new fight, existing pilots, Rivet/Tarn unlock progression, world-one items, relics, achievements, lore, art and music, gamepad, run save | Checkpoint 2 on main. A full world-one run with a profile. | about 55 units |
| **M3a Worlds in greybox** | The Dig and the Highdraft playable end to end. Mechanics, four zones, six enemies, four Wardens, two world bosses | Checkpoint 3 on main. A full three-world run in greybox. | about 55 units |
| **M3b Worlds dressed** | Art, textures, wind-ups, music and lore for worlds two and three, by layer across both | Checkpoint 4 on main. | about 55 units |
| **M4 Alpha** | Six complete pilots, assembled companion, camp with practice and recreation, cosmetics, full achievements, codex, ending, export and how-to-play | The exported Linux build launches cold and a run can be won. | about 35 units |

The former 235-unit and 11-to-14-day estimate is retired. Recovery found three of six playable pilots and zero of three complete worlds; shared infrastructure is substantially ahead of world content. Recount remaining bounded units after recovery, separated by systems, worlds, pilots, presentation and packaging. Report built, integrated, automatically checked and human-accepted status separately; no completion percentage is established.

Worlds two and three go greybox first, then art by layer. Past asset batches accepted about half of builds on the first pass, so a cut at any date must still leave a consistent game.

## M1. The click slice

**Zone.** The Cable Reach (`src/world/map_gorge.gd`). It already has a landmark, three layers, five transitions and the contraption set. It moves to slot 1 so the ACE music plays there.

**What Andrew compares by playing.** Two axes, one `--variant=` row, losers deleted after his verdict.

| Axis | Arm A | Arm B |
| --- | --- | --- |
| Fight structure | **Hunt.** The Warden roams between three lairs on a telegraphed route. Zone toys hurt it (drop a tank on it, scald it, collapse a floor). Activities arm more toys. | **Duel.** A fixed arena built for the ball with swing pillars, ramps and a lift. Pilot verbs build posture. Zone growth and armed arena toys decide the pace. |
| Harpoon input | **Hold to reel.** Press fires, hold reels, release flings. | **Auto-winch.** Press fires and a body line winches by itself. |

After entry 10 the fight axis has a third value and it is the default: the v2 structure (find the Warden at its beacon and break it) on the readable posture chassis. Hunt and Duel are compared against it.

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

**Admission to play.** Bots and fixed checks only decide whether the build is worth Andrew's time. They verify movement-dependent victory, the value of exploration and growth, and native resource budgets. Every numerical threshold stays. Each band is verified against the existing passing and deliberately failing calibration cases (`scripts/checkpoint.test.mjs`) before its measured result counts. The three rejected builds (v2 at `19fc173`, drop, laps) remain historical evidence; no automatic band establishes fun, and Andrew's five sitting answers and play verdict stay required before later-world construction. (Andrew, 3 October 2026, EV-0623; this supersedes the earlier "red on the three rejected builds" rule, which was never executed because drop and laps are deleted and v2 predates the harness.)

- The hold-fire camper cannot win. An arena-only player can, slower than the explorer.
- The skipper wins more slowly than the completionist on the current posture fight; no Hunt arm is required.
- The explorer wins at least 60 percent of 16 seeds with more heft and more parts.
- Perf on the densest fight at 1080p. CPU main thread p99 at most 10 ms, GPU p99 at most 7 ms.
- Smoke green on the checkpoint SHA and one Fable integrated read.

**What only his play decides.** Written before he sits down and read from his own run log.

- He enters two or more activities unprompted in a run.
- He lands harpoon smashes into packs and keeps doing it.
- He spends time in the zone before the Warden in at least one run.
- He starts a second run without being asked.
- The existing five sitting questions on the single current slice: loop, best moment, worst frustration, play-again verdict, and difficulty/pacing/clarity.

Start the sitting with harpoon into an ordinary pack to judge the revised feedback. Entry 10 already records Andrew finding homing smash super fun; this sitting tests the current implementation.

**If the verdict is "still not there".** One more slice round of at most ten units aimed at his worst frustration, then a second sitting. A third round stops the program for a re-plan with him.

## Track A. Day one, independent of the verdict

| Unit | Goal | Writes |
| --- | --- | --- |
| A1 | Stage and world tables, `ctx.stages`, a two-world test double | `src/core/worlds.gd` (new), `stage_defs.gd` after B0, `context.gd` |
| A2 | Profile store with schema and migrations. Fable review. | `src/core/profile.gd` (new) |
| A3 | Achievement and cosmetic rows with validators | `src/core/achievements.gd`, `cosmetics.gd` (new) |
| A5 | Export recipe and the ACE path fix | `export_presets.cfg`, `scripts/sketch-export.mjs` (new), `src/presentation/ace_sequencer.gd` |
| AR | Copy the asset sheet and judge files from the visual clone into the repo, then merge the clone's accepted assets, rig and clip recipes as one serial integrator merge | `assets/models/`, `tools/blender/`, `src/presentation/pilot_reactions.gd` |
| AB | Asset registry, budget classes and a registry test | `assets/registry.json`, `assets/asset_budgets.json` |
| AM | Reproducible music packaging from a committed sources file | `tools/ace/package_music.py`, `tools/ace/sources.json` |
| P1, P2 | Terrain probes. A Dig tunnel with a second floor and a Highdraft island with a net deck. Check camera, collider and bot pathing. | throwaway branch, findings only |
| T1 to T8 | Test tooling. See the testing section. T1 and T2 run first. | `scripts/`, `tests/`, rule files |
| REC | TRACKING event, decision rows, ROADMAP rewritten to M1 through M4, ORCHESTRATOR stale lines, the Bible's world count | canonical docs, coordinator only |

If a terrain probe fails, that world switches to a setting that fits the heightmap before any M3 unit is cut. The fallback is Pale Basin or Foundry Crown and it goes back to Andrew.

Not in Track A. World two and three music, direction sheets and story arcs wait for the verdict.

## M2. World one complete

- **Fight.** The accepted posture structure extends to both zones' Wardens and Brindle through one frozen boss contract and contract tests. Retire unreachable lab alternatives after the checkpoint verdict; do not build comparison arms.
- **Zones.** The Spillway is rebuilt as zone 1-1 by merging in the Weir's halfpipe, mesa and causeway. `map_weir.gd` and `map_sluice.gd` are deleted. The Cable Reach is zone 1-2.
- **Structure.** Flow across worlds, lazy terrain per world, director and Warden family from the stage row, music and HUD from rows (architecture units W1 to W6). A stub boss keeps later worlds completable.
- **Build.** Three layers. Path is the kit tree by level-up. Relics rewrite one slot each and are found on the map. Parts stack tags toward synergies and two evolutions.
- **Economy.** Scrap is size and armour. Cogs are the only spend currency. Cores stay zone-local. One damage order.
- **Rarity.** Common, Rare, Relic, Evolved, with a hot-wired stripe. Scalar-only rows leave everything above Common.
- **Meta.** Profile wired in. Rivet unlocks by a world-one rescue quest and Tarn by Brindle; Kest unlocks by the Dig rescue. Locked cards show truthful conditions. Preserve existing earned unlocks; commit new quest and boss rewards exactly once.
- **Side content.** Combat challenges, contraption secrets and one camp per zone with a named reward.
- **Run save.** Extend `run_state.gd` and `safe_store.gd` for versioned durable zone-entrance snapshots, death-save expenditure (was per-world retry, replaced 22 Oct), stable offers/generation, Cogs, path and inventory, and companion assembly. Free quit/crash replay restores the entrance; unlocks settle once. Consequential review covers migrations and interrupted transitions.
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

Complete Tarn's claw kit, Tally's mechanical Gather/Link/Balance Due card kit and the remembered cannon. Reuse their six placeholder probes after checkpoint 1; weak results refine a required pilot. Mind and cannon share the four lane/split-lane/rush/plate attack families. Finish the assembled companion, camp, cosmetics, full achievements, discoveries, ending, title/summary music, Linux package with required stems, README and in-game how-to-play. Additional lounge games and decorative expansion remain optional; no fourth world or extra final boss is added.

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
- Per wave. `npm run sketch:gate` once on the combined candidate, followed by the independent read of the diff and receipts. A documentation commit changes the admitted tree, so ORCHESTRATOR requires a new gate for that tree.
- Per checkpoint. After the exact candidate has its gate receipt, `npm run sketch:checkpoint -- --before` runs sixteen seeds for each existing bot policy, checks the fixed posture bands and captures native 1080p performance. Its results are under `artifacts/local/checkpoint/`. After Andrew plays, `npm run sketch:checkpoint -- --after <runs.ndjson>` reads his run log; the five answers and fun verdict remain human evidence. Main integration, applicable browser-proof checks and checkpoint push follow the verdict.
- Never claimed without Andrew's play. That it is fun, that it reads, that the look hits the concept art, that the music works in a fight.

## Risks

| Risk | Probe or guard |
| --- | --- |
| Flipping defaults breaks tests that never mention a flag | K0 first runs every test with each winning flag on and counts failures before any default changes |
| B0 is wide and touches the run spine | Merged alone and first in its wave, Fable review, camper assertion re-homed before the loop tests go |
| The Hunt arm needs a Warden that moves, and it is built as a fixed clamp | A one-day stand-in that carries the existing node along a route polyline before VH is briefed |
| Admission bands pass a hollow build again | Each band is checked against the deliberately failing calibration cases; a hollow build is caught by Andrew's sitting, which no band replaces (EV-0623; formerly "red on the three rejected builds") |
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

1. Play checkpoint 1 with the fresh-save command in `SITTING.md`, one Cable Reach table and one posture fight.
2. Answer the five sitting questions for the single Cable Reach slice.
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

## Wave 13 (opened 10 October 2026)

Historical. Wave 13 ran on branch `cand/alpha-w13` with three lanes: Pilots ([SKILL-BAR](SKILL-BAR.md), [PILOTS](PILOTS.md), [ROSTER-LOOK](ROSTER-LOOK.md)), Park and Wardens ([PARK](PARK.md)) and Polish. Later coordination state is tracked in [STATE.md](../../../project-guide/handoff/STATE.md).
