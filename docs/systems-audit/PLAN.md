# Game systems audit: plan

**What this is.** An add-on workstream Andrew asked for on 11 November 2026: find and fix the weakest parts of Scrapkeep's systems, mechanics and features, with evidence from running the game. It runs beside the world 1 polish program and does not pause or re-scope wave 37. This page is Step 0 (intake). The six passes are cards SA-A to SA-F in [BACKLOG.md](../../BACKLOG.md#systems-audit-add-on-11-november-2026). Pass A's output is [systems-map.md](systems-map.md).

**Scope.** World 1 first: the title, the camp, the dam, the flume and Brindle in the Slag Bowl, and early progression (STATE.md, priority of 23 Oct; ruling at). Worlds 2 and 3 are parked. Every pass below is scoped to world 1 unless it says otherwise.

**Read at.** `stage/alpha-w37` head `995f3dd2` (11 Nov 2026, 18:30Z), plus `claude/w37-difficulty` (the parked difficulty stack) for what it changes.

## Which file stands in for which

The brief names three files. Two exist; one does not.

| Brief says | In the repo | Notes |
| --- | --- | --- |
| `BIBLE.md` | [BIBLE.md](../../BIBLE.md) exists. Its sections 1 (Pillars & Fantasy) and 6 (Core Systems) are read here. | The Bible is dated 6 Sep 2026 and harmonized in place up to 9 Nov. Where it and the Godot sketch differ, the newer word is the [Story map](../../sketches/core-loop/design-v3/STORY-MAP.md) section 4 (what each system means and plays like) and the rulings in [DECISIONS.md](../../project-guide/handoff/DECISIONS.md) (newest wins). |
| `TECH_BIBLE.md` | Does not exist. BACKLOG.md says "TECH_BIBLE.md ... remain[s a] future output". | Stand-ins: ADRs → [adr/README.md](../../adr/README.md) (TADR-001 to TADR-011). Testing strategy → [ORCHESTRATOR.md](../../ORCHESTRATOR.md) tiered gate (its only owner), [GATE.md](../../project-guide/handoff/GATE.md) and [design-v3/TESTING.md](../../sketches/core-loop/design-v3/TESTING.md). Conventions → [CONTRIBUTING.md](../../CONTRIBUTING.md), AGENTS.md (deep modules, one home for every fact, no slop) and [sketches/core-loop/CONTRACTS.md](../../sketches/core-loop/CONTRACTS.md). |
| `TRACKING.md` | [TRACKING.md](../../TRACKING.md) exists but is the September foundation board. | Live execution is the wave board named in [STATE.md](../../project-guide/handoff/STATE.md) (issue 749 for wave 37). "The backlog" for this workstream is BACKLOG.md (task definitions, per AGENTS.md), with one line in [ROADMAP.md](../../project-guide/handoff/ROADMAP.md) and a claim on the wave board, in the format [COMMS.md](../../project-guide/handoff/COMMS.md) gives. |

Earlier work this plan builds on, so it is not redone: the systems audit "Game systems: audit and plan" (Claude Doc https://claude.ai/artifact/GiVnd79hcp2tkx4UaWkAY7, 9 Nov, thread "Harmonise game systems like Isaac"), the [world 1 difficulty plan](../../project-guide/handoff/shared/world1/difficulty-plan.md) (10 Nov), and the bot balance re-measure (Library `handoff/balance-remeasure.md`, 10 Nov).

## 1. Genre, engine and pillars, as the repo states them

**Genre.** BIBLE.md section 1, Game identity:

> SCRAPKEEP is a solo-first, close-third-person action roguelite about piloting an improvised electromagnetic mech through a greasy, inhabited steam-cyberpunk Southwest. Roll into trouble, aim through it, collect the wreckage and build something outrageous inside the machine you are driving.

> A successful run crosses three worlds in a fixed order (Spillway Works, the Dig, the Highdraft) through open stages ... A winning run targets 30 to 45 minutes, about 10 to 15 per world, to be measured in play.

> Combat power is rebuilt each run. Permanent discoveries and unlocks broaden future options.

**The game in one line** (BIBLE.md, ruling cj, Andrew, 9 Nov 2026):

> A crew of loose cannons, bulls in the Foreman's china shop, take their world back from a machine that believes life can be run perfectly.

**Engine.** adr/README.md, TADR-001:

> Godot 4.7.2 standard edition, typed GDScript, Windows 11 x64 and Linux x64 qualification targets.

The game that runs is the Godot sketch at `sketches/core-loop` (AGENTS.md: "The game is a Godot sketch at `sketches/core-loop` with three worlds"). Physics: TADR-006, "Rigid Jolt bodies are the physics authority; physical outcomes are judged as rates (n ≥ 20, nondeterminism floor 0.05)".

**The three pillars** (BIBLE.md section 1, "The three pillars"):

1. **Joyful physical mastery.** "The player should want to move before a reward tells them to. Rolling has weight, jumps make space, rebounds turn collisions into opportunities, and aim lets a chosen target matter inside a crowded fight."
2. **Scrap becomes your build.** "Collecting scrap should feel like taking possession of the fight. Electromagnetic coils pull material into the mech's growing body; internal recycling turns that material into working changes to weapons and skills."
3. **A world worth crossing.** "The route should tell the player where they are and why people work there."

**Mission** (project instructions, Andrew): "every run gives the player things to look forward to, explore and discover, the way The Binding of Isaac does (never copied). Everything visual and intuitive."

**Drift to note, not fix.** The Bible's Core Systems text still describes a close-third-person mech with four slots and "one main companion". The game is a rolling gyrosphere ("The ball", Story map section 4), and TADR-011 (10 Oct) replaced the one companion with a scrap-bot crew that the code does not have (the code has SPIL-9 with two sockets). This plan does not edit the Bible. Pass D files the change requests.

## 2. Every system and mechanic, with status

Status: **playable** (in the world 1 build a player can reach it), **partial** (built but missing a part a player would expect, or built and unreachable), **spec only** (designed, no code a player meets). "Evidence" names the code read, or the run, behind the status. Pass A's map ([systems-map.md](systems-map.md)) gives each system's inputs, outputs and resources.

| # | System | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Rolling ball: roll, boost, jump, slam, speed tiers, momentum terrain | playable | `src/movement/player_ball.gd`, `rigid_ball.gd`, `speed_tier.gd`, `tuning.gd` (cruise 14 m/s) |
| 2 | Harpoon line: swing, fling, reel, hook chain | playable | `src/movement/harpoon.gd`, design-v3/HOOK-CHAIN.md |
| 3 | Carve (rolling through cracked faces) | partial: moves the ball, sends no game event, so sound, achievements and crowd rules cannot answer it | `src/core/game_events.gd` has no carve signal (re-checked 11 Nov) |
| 4 | Aim and weapons | playable | `src/combat/weapons.gd`, `hitscan.gd`, `src/movement/aim_style.gd` |
| 5 | Six pilots and their kits (Sable, Kest, Tarn, Rivet, Tally, the Cannon) | playable; the Cannon unlocks by winning | `src/core/class_def.gd`, `src/combat/*_kit.gd`, ClassDef ids in `tools/bot_run.gd` header |
| 6 | Actives (six rack actives) and the ultimate meter | playable | `src/combat/actives/`, `src/core/ultimate_meter.gd`, `src/combat/ultimate.gd` |
| 7 | Hull, scrap armour, regen, one-shot guard, escape window, earned death save | playable | `src/core/run_state.gd` (REGEN 6 hp/s after 5 s; regen only while rolling is in the parked difficulty stack) |
| 8 | Ordinary enemies, elites, pack pressure, telegraphs and the attack budget | playable | `src/combat/roster.gd`, `elite_affixes.gd`, `threat_grammar.gd`, `attack_budget.gd` |
| 9 | Reactor Wardens: guard, break, weak points, the pulse | playable | `src/combat/warden.gd`, `warden_reactor.gd`, `boss/weak_points.gd` |
| 10 | Admiral Brindle, three phases | playable | `src/boss/boss.gd`, `boss_rules.gd` |
| 11 | Rogue mini-bosses (one per stage at most) | playable | `src/combat/rogue.gd`, `src/world/rogue_director.gd` |
| 12 | Event director and stage events (flood, natural, industrial, weather, stage modifiers) | playable | `src/world/director.gd`, `event_director.gd`, `src/world/events/` |
| 13 | Park stages and side spots: rib caches, cracked caches, bet crates, ambush altar, relay stake, rescue sites, surge course, radio caches | playable | `src/world/park/`, `src/world/*.gd` |
| 14 | Scrap: pull, mass, heft class, size, armour, spill, wear | playable | `run_state.gd` HEFT_*, SPILL_*, WEAR_PER_MINUTE; `src/build/scrap_field.gd`, `accretion.gd` |
| 15 | Cogs and Moss's counter: buy, reroll, cells, sell back | playable | `src/build/shop.gd`, `fabricators.gd` COG_PRICES |
| 16 | Cores: zone-local, raise the next gate's offer, bet, burn for a heal | playable | `run_state.gd` add_core, burn_cores, gate_tier_bonus; `src/world/bet_crate.gd` |
| 17 | Item ladder: grey panels, mint parts, cobalt parts | playable | `src/build/panels.gd`, `parts.gd`, `reward_gates.gd` (cobalt from Wardens, bosses, one shop slot: Story map) |
| 18 | Pearl and gold items, brass trophies, the Mind's offerings | spec only, after the alpha | Story map section 4 |
| 19 | Maker sets and synergies (three of one maker turn on its trick) | playable; maker is not tied to place | `src/build/maker_sets.gd`, `synergies.gd`; `parts.gd` maker nudge |
| 20 | Relics | playable (from cracked caches) | `src/build/relics.gd`, `src/world/cracked_cache.gd` |
| 21 | Hot-wire (Spark Tread) | playable | `src/build/hotwire_rules.gd` |
| 22 | Upgrade tree: one binary tree per pilot, depths 1 and 2 in world 1 | playable | `src/core/upgrade_tree.gd`, `src/core/trees/` |
| 23 | Start pick of three, one reroll | playable | `src/core/start_picks.gd` |
| 24 | Trade spots: the keeper's gamble and the foreman's kindness, with memory | playable (rulings ci) | `src/world/trade_pockets.gd`, `stake_devices.gd` |
| 25 | SPIL-9 companion, two module sockets | playable | `src/core/companion.gd` |
| 26 | Scrap-bot crew (TADR-011) | spec only; the code keeps SPIL-9 | no crew cap in `src/` (grep `crew_cap`, 11 Nov) |
| 27 | Devices (Kest charges, Sable's sentry and stakes) with caps and leash | playable | `src/core/devices.gd` |
| 28 | Element by material table (TADR-009): ice on water, live water | playable where a pilot's kit casts an element | `src/build/element_field.gd`, `elements.gd` |
| 29 | Run tier (the HARD ladder, five rungs) | playable after the first win | `src/core/run_tier.gd` |
| 30 | Run flow: death, fast restart, save and resume at the stage entrance | playable | `src/core/flow.gd`, `run_store.gd` |
| 31 | Respec of a tree branch by a special opportunity (Bible section 6) | spec only | no respec opportunity in `src/world/` (grep, 11 Nov); `build.gd` "respec" means a refold of stats |
| 32 | Meta: profile, shift board rungs, pilot marks, cosmetics, codex, scrapbook, logbook | playable | `src/core/profile.gd`, `shift_board.gd`, `cosmetics.gd`, `codex.gd` |
| 33 | Head starts (meta options) | partial: the page shows "0 of 4" and nothing opens one | `src/core/meta_options.gd` `open_earned` has no caller (re-checked 11 Nov) |
| 34 | Achievements | partial: eleven are record-only | `src/core/achievements.gd` (Game systems audit, finding 5) |
| 35 | Stage variants and run modifiers (dam night shift, flume backwash, overtime, short crew) | spec only: four seeds on the shift board, "Nothing reads these yet" | `src/core/shift_board.gd` SEEDS |
| 36 | Camp: Moss, the skee lane, the trial, the sandbox, the bay | playable | `src/world/camp_hub.gd`, `camp_*.gd` |
| 37 | HUD, objectives, danger marks, call-ins and radio, tips | playable (owned by "Rebuild game UI for clarity") | `src/ui/` |
| 38 | Reactive music and sound | playable | `src/presentation/audio.gd`, `music_engine.gd` |
| 39 | Chain counter and the tricks book | playable | `src/ui/chain_counter.gd`, `src/core/secrets.gd` |

## 3. The passes: run now, on paper, or later

Brackets in Andrew's brief are filled from the repo:

- **First [15] minutes:** 15 minutes. Source: the world 1 sitting target, "10-15 min run, about 30 min completionist, repeatable" (STATE.md, priority of 23 Oct), and BIBLE.md "about 10 to 15 per world". Fifteen minutes covers the title, the camp, the dam, the flume and Brindle for a first-timer.
- **Simulate [10] hours:** 10 hours of game time per player type. Running it literally is about 75 rusher runs (7 to 8 game minutes each, measured in pass A) and about 40 completionist and 40 min-maxer runs, roughly 6 hours of wall time on a 4-core box. Andrew asked on 11 Nov (18:42Z) that long wall-clock runs never stall the work, so pass B runs 24 world 1 runs per type (the project's 24-seed rule) and carries its per-minute rates to 10 hours; it runs the full count only if a rate is still moving at 24. In-run economy resets every run (BIBLE.md "Combat power is rebuilt each run"), so 10 hours mostly measures the per-run economy across many seeds, plus the meta unlock curve (shift board rungs, pilot marks, cosmetics, codex) across those runs.

| Pass | Decision | Why |
| --- | --- | --- |
| A Systems map | **Run now.** Read-only plus docs, with a resource ledger from real bot runs. | Every world 1 system is playable (table above). |
| B Economy | **Run now for world 1.** The harness exists but needs two additions first, inside B's own files: a shopping and choosing policy, and a resource ledger. | Bots never shop and never take the start pick (red-team notes; `tools/bot_driver.gd` has no shop code), and by default leave every tree offer untaken (`tree_policy` ""), so today's bots cannot play a min-maxer. The run record carries no cogs (`tools/bot_driver.gd` record()). |
| C Mechanic feel | **Run now for world 1.** Frame sequences in the cloud through the existing capture tools; feel reads on the PC. | All world 1 mechanics are playable. Feel is a human read (AGENTS.md: "Automated play does not establish human feel"). |
| D Feature fit | **Run on paper now**, using A's map and the existing receipts. It implements nothing. | Its output is a verdict table and three proposals. |
| E First 15 minutes | **Run now for world 1 after C and D.** | Recording exists (`tools/eye_film.gd --film=whole`). |
| F Break it | **Run now for world 1.** Needs a break bot, inside F's own files. | Crash, stall, item-fuzz, fling and snag hunts exist (`scripts/redteam`, `tools/item_fuzz.gd`, `collision_sweep.gd`). No bot today saves and loads mid-action or spams inputs. |
| Any pass, worlds 2 and 3 | **Defer** until world 2 is back in scope (ruling at). | Parked. |
| Spec-only systems (rows 18, 26, 31, 35) | **On paper only**, in D. | Nothing to run. |

## 4. Does a headless simulation or scripted-input harness exist?

**Yes. No harness card is filed.** What exists, all headless, all on the park table that a launched game plays when passed `--table=park`:

| Tool | What it does | Gap for this workstream |
| --- | --- | --- |
| `tools/bot_run.gd` + `tools/bot_driver.gd` | Plays whole runs with a policy: skipper, completionist, random, camper, traversal, orbit, terrain. Skill bands (Novice, Learner, Expert) through `tools/skill_band.gd`. `--fixed-fps 90` runs faster than real time and repeats exactly. | No shop, no start pick, tree offers off by default. Record has no cogs. Multi-seed runs fork children that run `bot_run.gd` itself, so a wrapper probe must run one seed per process (found 11 Nov). |
| `scripts/challenge/run.mjs` (band table) | Novice, Learner, Expert win rates per Warden, boss and park, with Wilson intervals. | Band win counts are not a balance sensor at 24 seeds (balance re-measure finding 4). |
| `scripts/redteam/run.mjs` and `eye.mjs` | Per-wave red team: five personas, crash, stall, crowd, fuzz and frame playbooks; the player's-eye film and cold reader. Plays the park maps since PR 761 (11 Nov). | No save-and-load mid-action, no input spam. |
| `tools/item_fuzz.gd`, `tools/build_sweep.gd`, `tools/matchup_lab.gd` | Random item stacks for 60 s with invariant checks; stack and compose arms; pilot against enemy kind. | Buffs only; debuffs (curse, wear, stage modifiers) are not stacked with them. |
| `tools/first_timer.gd`, `tools/self_play.gd` | A first-timer probe; a launched game played by its own keys. | None for B; E uses them. |
| `tools/balance_report.gd` | Per-stage bands, synergy shares (flags any synergy above 60% of runs) and death clusters from a bot folder. | Reads builds, not resources. |
| `tools/eye_film.gd`, `tools/look_harness.gd`, capture tools | Frame sequences of a played run or a staged moment. | Real stills need a display (PC or xvfb). |

So pass B and pass F are not blocked. Each starts by adding what it needs in its own new files (cards SA-B and SA-F say which).

## 5. How the passes run

```
 A Systems map ──┬──► B Economy (world 1) ──────────┐
   (this thread) ├──► C Mechanic feel (world 1) ──┐ │
                 └──► D Feature fit (paper) ──────┴─┴► E First 15 min ──► F Break it
                                                                          └─ B and F again at every sprint close
```

- A runs alone first (this thread). B, C and D start as parallel threads when A is merged; each owns different files (the fences are on each card). E waits for C and D. F runs last.
- **Regression.** B and F run again at every sprint close, beside the release gate (ruling cy). Andrew's rule for this workstream: a new dominant strategy or a new high-severity break reopens the sprint, the same as a build that will not boot. That changes ORCHESTRATOR's tiered gate, which ORCHESTRATOR alone owns, so it goes to the coordinator as a change request (card SA-F). It does not change ruling cn: play findings still never hold a promotion.
- **Gate per PR.** Focused tests plus `npm run sketch:fast -- --base origin/stage/alpha-w37` and one independent review (ORCHESTRATOR tiered gate). Docs-only PRs (A, D) use `npm run check:docs` and `npm run check:project`.
- **Evidence.** Each DoD names an artifact. A pass with no artifact is not done. Numbers come only from receipts; band ratios need 24-seed medians (project measurement rule).
- **NEEDS ANDREW** only for: cutting or merging a feature, a change that conflicts with a pillar, or a balance fix that needs a design change rather than a number change. Everything else is decided and logged as a one-line assumption he can overturn.
- **Reporting.** Each pass ends with a per-system summary for the coordinator's "Systems health" digest: pass status, top open issue, last sim or bot result, what changed, and one finding in plain words.

## 6. What this plan does not do

It does not edit BIBLE.md, an ADR or ORCHESTRATOR.md. It does not touch any file that the wave 37 board, the UI thread or an open pull request holds. It does not start worlds 2 or 3.
