# Runtime blueprint

Historical boundary sketch for the pre-production runtime. [TADR-002](../adr/TADR-002-runtime-model.md) owns the accepted runtime model and supersedes the ownership table in section 1; the [HF-03a module map](tech/sections/HF-03a-module-map.md) owns the admitted module contract. The text below retains its original dated wording.

Updated 5 September 2026 after the notebook interview. [Discovery](DISCOVERY.md#accepted-notebook-interview) owns accepted product direction. This blueprint owns the target system responsibilities and design constraints; proposed modules and persistence work are not implemented by this documentation update.

The [lightning increment](project/INCREMENT-01-lightning-playtest.md) owns the current integration contract, and [lightning verification](LIGHTNING-VERIFICATION.md) owns executed evidence. The older [architecture audit](audit-2026-09-05/worker-1-architecture.md) and [meta-system paper](audit-2026-09-05/worker-3-meta.md) remain historical research. Their three-stage expedition, mass-first sequence and schema-v2 sketch no longer define the target runtime.

## 1. System ownership

| Responsibility        | Owns                                                                                                                                                                          | Boundary                                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Content definitions   | Characters; weapon, main hero skill, mobility and ultimate trees; items; world/encounter content; fixed secret recipes                                                        | Stable definitions describe possibilities. They do not store a player's selections or mutate progress. |
| Encounter simulation  | Movement, attacks, cooldowns, enemies, hazards, pickups, immediate effects and combat outcomes                                                                                | DOM-free authoritative state. Input supplies intent; rendering consumes committed results.             |
| Run state             | Seed, offered/selected worlds, current level, slot unlocks and selected paths, acquired/equipped items, main companion, revival availability, checkpoints and terminal status | Carries the combat build between levels. Ends on victory, terminal defeat or abandonment.              |
| Permanent progression | Discoveries, unlocked options and challenges, learned secret recipes, completed-run results                                                                                   | Survives runs. It does not retain the run's combat bonuses or increase permanent combat stats.         |

Preserve [ADR 0001](adr/0001-two-playable-entries.md), [ADR 0002](adr/0002-simulation-boundary.md) and [ADR 0003](adr/0003-authoritative-attack-geometry.md). Both `/` and `/orchard.html` remain available. Orchard combat stays in `simulation.js`, rendering in `scene.js`, procedural models in `models.js`, and input/UI orchestration in `main.js` until a scoped refactor changes that layout.

A future extraction may introduce a run coordinator, content registries and a persistence adapter. Those are proposed responsibilities, not a request to create directories, a third entry point or a new engine. The yard's profile implementation is a compatibility reference, not an automatically reusable expedition schema.

## 2. Run coordination and checkpoints

A run crosses four worlds in a successful 60–75 minutes. A world contains compact procedural encounter levels and its world boss. Ordinary levels may have waves, exploration, events and occasional minibosses. They do not each require a boss. World catalogue size and run length are separate values.

The outer run coordinator consumes encounter outcomes. It does not reach into rendering or duplicate combat logic. Proposed lifecycle:

| Event                                               | Run-level effect                                                                                                            |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Start run                                           | Select character and initialize seed, weapon, special mobility and one standard revival. Normal movement is available.      |
| Complete opening-world milestones                   | Unlock main hero skill and ultimate; apply earned progression through the selected slot routes.                             |
| Clear ordinary level                                | Preserve earned progress and resolved rewards, offer onward exits, and prepare a checkpoint at the next level entrance.     |
| Complete world while another remains                | Preserve build; offer two randomly selected world destinations; record the player's choice before entering that world.      |
| First lethal defeat with standard revival available | Consume the revival once and restore play under the future revival policy.                                                  |
| Lethal defeat after revival is consumed             | Mark run terminal and settle its result once; preserve permanent discoveries and unlocks.                                   |
| Complete final encounter                            | Mark victory and settle once. Whether this is world four's boss or a separate encounter remains open.                       |
| Resume completed-level checkpoint                   | Restore carried progress and choices at the next level entrance without re-awarding completed rewards or refilling revival. |

Pause remains an encounter/input concern under [ADR 0005](adr/0005-caster-input-and-dashboard.md). A paused dashboard is not itself a save checkpoint.

### State carried between levels

The checkpoint needs the run identity and seed, selected character, offered/selected route choices, world and level cursor, unlocked slots, selected tree paths and earned progress, inventory/equipment, companion build, remaining revival, resolved rewards and terminal status. Any adopted persistent terrain effects need an explicit scope and identity. Enemy positions, projectiles and transient cast effects belong to the current encounter, not a promise of mid-combat serialization.

The persistence design must represent unresolved exit or reward choices without losing an earned clear or rerolling an already offered choice. The completed-level save must become durable before the next encounter begins. Saving, loading, repeated completion events and terminal-result settlement must not duplicate rewards or revival. A stale checkpoint must not resurrect a terminal run or restore a consumed revival.

Exact serialization, storage transactions, revival health/placement and behavior on quitting or crashing during an unfinished level remain D27/D58 work. Between-level resume is accepted; it is no longer an open choice between resume and unconditional abandonment.

## 3. Content and build interfaces

### 3.1 Character kits and progression trees

Each character definition owns four trees: weapon, main hero skill, mobility and ultimate. Each tree uses the binary shape Andrew specified during the 6 September Bible review: one root → two upgrade nodes → four upgrade nodes → eight endpoints. Every nonterminal has two children, and a run follows one connected lineage per slot without crosspathing or reconvergence. This does not prescribe four playable characters. Define node effects and gameplay milestones/costs when P11 is scoped; see the [Bible systems reference](../BIBLE.md#6-core-systems).

A normal successful route should reach all four endpoints by the final boss. Weapon and special mobility are usable at entry; the other two slots unlock during world one. Progression consumes gameplay accomplishments and milestones, not time spent waiting in the live game. Ordinary movement never depends on a slot unlock.

Treat the current prototype's primary, two combat abilities, mobility and ultimate as its implemented input arrangement. Mapping those actions into the future four-tree design remains content work. A deployment action is not automatically a fifth progression tree.

### 3.2 Encounter and enemy definitions

Enemy definitions should retain the existing commitment contract: a readable preparation, committed geometry, an achievable response and visible recovery or vulnerability. Damage and presentation read the same resolved attack descriptor. Shapes can be lines, arcs, zones or other supported geometry without giving the renderer independent hitbox authority.

The [enemy roster](ENEMY-ROSTER.md) contains candidate family admissions, rewards and attack descriptions. Its deflectable/heavy/grab labels and numerical tables are research proposals, not implemented guarantees. Mass penalties and Roll-Through are not required foundations for caster encounters.

### 3.3 Items, attunement and fixed combinations

Items have separate acquisition and equipment state. Rare enemies, events, secret rooms and bosses draw from world/area-appropriate content. Attunement expresses compatibility with characters and/or other items. Fixed secret recipes match selected slot endpoints and produce a repeatable route or character bonus; they are not random reward rolls.

Resolve the active build from character selections, equipped items, compatible companion/device modifiers and eligible recipes. Reconfiguration replaces the derived result rather than appending bonuses to yesterday's result. The dashboard and simulation must describe the same effective build. Derived caches, if any, must be rebuildable from these authoritative selections.

Skill-tree respec requires a special room/event opportunity. Equipment rearrangement remains available between fights. These are separate permissions and UI actions. Loading a save grants neither an extra respec nor duplicate recipe effects.

Optional items may replace movement or attacks. Shared effects apply only to compatible player, device and companion actions; they do not imply every modifier applies everywhere. One main companion anchors the build; temporary helper effects do not establish a multi-companion management system. Detailed stacking and attunement recipes remain P13 work.

### 3.4 World, level and randomness definitions

Keep a world definition separate from its occurrence in a run, and a compact encounter level separate from a whole world. Route generation selects eligible world destinations; level generation creates encounters inside the selected world. A two-destination world choice is not a two-item reward offer.

Seeded arrangement of authored encounters is still a candidate generation technique, alongside procedural terrain assembly. Do not hardcode the former five-pocket stage or fixed campaign ladder into run state. Catalogue size, repeat rules, first world and final encounter placement remain open.

Keep random processes identifiable: route offers, level layouts, loot and combat miscasts must be reproducible from their recorded state. One process should not silently change another because presentation consumed a random value. Fixed secret recipe evaluation uses no random draw. Separate seeded streams or explicit stored outcomes are implementation options to settle during scoping.

### 3.5 Chaos magician

The accepted character direction is directed fire plus a shorter-range automatic field, multiple elements/effects and occasional miscasts, including failures that harm or inconvenience the magician. Most casting should express the intended action. No instability meter, always-random kit or electricity-only restriction is accepted.

Resolve a miscast once when its gameplay outcome commits, then share that resolved attack/effect descriptor with collision, preview updates and rendering. Presentation must not reroll the element or damage area. If the intended preview can change on miscast, the targeting design must communicate that uncertainty and the resolved result honestly. The exact disclosure, warning timing and harmful outcomes require P14 design and testing.

The fixed lightning proof does not implement this trait. Fuse, the proposed squirrel identity, is one creative candidate, not an automatic mapping of the approved mechanic.

## 4. Permanent profile and migration

Permanent data records discoveries, unlocked options/challenges, learned secret recipes and settled results. A recipe's discovery persists, but its combat effect is recomputed from the current run's eligible endpoints. Starting a new run resets the combat build and restores the standard revival allowance for that new run only.

The old save-v2 proposal is superseded as a concrete schema. D27/T05 must specify profile and checkpoint versioning, storage behavior and migration after the required state is known. Preserve the yard's existing profiles, blueprint data and receipt identities while both entries remain live. Do not reuse the yard's hero IDs or wave bounds as constraints on the new world/character model.

The existing progress store's single-settlement approach is useful prior work; compatibility has not been established for the new run lifecycle. The timing of discovery/profile writes and recovery from interrupted writes remain implementation decisions. No migration runs as part of this documentation alignment.

## 5. Scene and asset lifecycle

Proposed ownership: keep the renderer, camera and reusable effect resources alive across encounters; create and dispose level-specific environment and dynamic content at level transitions. Generate only the selected route's required content, unless measured loading cost justifies preloading options. Do not couple a world-choice screen to speculative loading of every possible destination.

[ADR 0004](adr/0004-procedural-prototype-assets.md) remains the asset rule. World kits and historical pocket studies provide candidate reusable geometry. Test camera clearance, maximum ordinary growth, jump/rebound routes and committed telegraph readability for assembled encounters. The older draw-call budgets and terrain dimensions are historical estimates, not approved limits for a full procedural run.

## 6. Movement and encounter physics

Preserve the implemented caster movement, double jump, enemy rebounds and height-aware attack geometry documented by the lightning contract. Ordinary growth should stay playful. Optional transformations may replace movement; they must still communicate reachable routes and attack consequences.

The audit's mass-as-currency, handling penalties, Shed Vent and deflect-first sequence were not adopted. The [combat paper](audit-2026-09-05/worker-2-combat.md) preserves those experiments if revisited. No physics library is added by this blueprint.

Future generated levels require terrain and enemy-admission work selected against actual encounters. P08/T06/T07 cover telemetry, possible lane-aware windup scheduling and terrain sampling. The old global one-windup and five-pocket assumptions are historical; the lightning proof already supports denser waves and multiple worker commitments.

## 7. Input and dashboard

Preserve mouse-controlled third-person aiming, accurate targeted previews, jump/rebound handling and the current pause/capture lifecycle. The simulation owns actions and their outcomes. The UI displays available slots, selected route progress and current effects; it must distinguish a locked slot, an unavailable upgrade, a permitted equipment swap and a special respec opportunity.

The dashboard should make active effects, useful stats, progression and map position easy to read. A secret bonus needs understandable feedback when discovered without exposing every recipe in advance. Exact layouts and disclosure rules are future UI work. Co-op and touch remain deferred; controller mappings still need hardware evidence.

## 8. Audio and character expression

Use the existing free local tools and synthesized sound. Audio consolidation remains a possible scoped refactor. Miscasts, attunement and major upgrades need recognizable visual or sound feedback without obscuring enemy warnings. Character barks, names and comic reactions are creative material, not new simulation requirements. A newly conscious drone does not require an AI service or learning model.

## 9. Validation strategy

The following are design scenarios and future acceptance requirements, not tests of implemented progression:

| Scenario                         | Required outcome                                                                                                                                                  |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Normal successful route          | Four worlds, gameplay-earned opening-world slot unlocks, and one endpoint in every tree by the final boss; assess 60–75 minutes through human play.               |
| Equipment change versus respec   | Between-fight equipment changes work without changing selected tree branches; a branch change consumes only the designated special opportunity.                   |
| Secret recipe, reload and respec | Same eligible endpoint combination gives the same effect once; reload does not stack it; losing eligibility removes the derived effect while retaining discovery. |
| First and second defeat          | First uses the run's single standard revival; subsequent defeat terminates it; loading cannot refill that spent revival.                                          |
| Level clear, choice and resume   | Completed progress and resolved rewards survive; already offered choices are stable; continue at the next entrance without replay rewards.                        |
| World offer versus item offer    | Two destination choices affect route state; reward presentation follows its own content policy.                                                                   |
| New run after defeat or victory  | Discoveries/unlocked options survive; old equipment power, endpoints and active secret bonuses do not.                                                            |
| Chaos cast                       | A fixed seed/state reproduces the same committed outcome; collision and presentation share the resolved geometry, including any self-harm.                        |

For implementation, use deterministic simulation and persistence tests for these concrete behaviors, plus browser/input checks for the player-facing flow. Keep synthetic replays, screenshots, hardware results and human playtests distinct. The latest recorded lightning checks do not establish full-run balance, saves or progression.

Run the repository's required verification command for completed changes. Performance budgets remain tied to named hardware and measured encounters under T03/D28. The existing sixty-second lightning stress is evidence for that tested configuration, not a full-world performance guarantee.

## 10. Remaining implementation decisions and engine gate

P11–P14 and T05 own bounded design follow-ups. Resolve generation technique, world pool/route policy, final encounter placement, milestone/cost allocation, revival/interruption policy and miscast tuning before scoping their dependent gameplay increment. Their open status does not reopen the accepted direction above.

The [accepted production ADRs](../adr/README.md) settle Godot and typed GDScript for the future game. The locked Three.js/Vite stack remains the implementation of the existing proofs. D29's engine-open wording is historical. The [execution backlog](../BACKLOG.md) and [tracking board](../TRACKING.md) own follow-up work and its status. Neither these architecture decisions nor the historical four-increment sequence authorize a gameplay build.

## Evidence limits

This is a documentation alignment based on the accepted interview and current project contracts. The proposed coordinator, registries, full-run checkpoint, profile migration, progression trees, secret recipes and chaos mechanics remain unimplemented. Historical research keeps its original source and measurement limits. Current runtime verification is recorded separately in [lightning verification](LIGHTNING-VERIFICATION.md).
