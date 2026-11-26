# Strategy spine

Design proposal, 2026-09-28. Build a reason to choose the next target, route and purchase. Prime a pack, move to a better angle, spend a ram, drop or special to cash it out, then collect toward a transformation that changes the next lap.

This tightens `SYSTEMS-CHAOS.md` (archived in git history); it grants no gameplay-build authorization. Supplied worktree base is `7144a9e`. Inventory below comes from the current files, not their older comments. Reconciliation inputs are `CODEX-REVIEW-2-systems.md` at `a278b05`, `ROADMAP.md` at `6f525de`, and the working `FEEL-READABILITY.md` in sibling `core-loop-v3-feel`. Incorporate accepted decisions into the roadmap's single `DESIGN-V3.md`, then archive this input with the other lead documents. No production ADR changes are made by this proposal.

## 1. Effect rarity, separate from strength

Classify the executable effect after stripping names, colours, prices and all magnitudes. Test the highest qualifying rung first. A larger number, second copy or renamed projectile never promotes a part. A missing implementation cannot qualify on its description alone.

| Rung | Assignment test | Example | W13 reward beat |
| --- | --- | --- | --- |
| Common | Only changes an existing quantity, including capacity, recovery, reach or rebound strength. | Hot Rivets; an extra special charge. | In flow; small pickup cue. |
| Rare | Adds an event response or delivery shape, but needs each ordinary action to produce its effect. | Hits leave a burn; a landing relaunches pins. | Flare and rising bell; first activation gets one matching cue. |
| Rare-plus | Introduces an independently ticking actor/field, or changes a permitted relationship between systems. Name the actor lifetime or the before/after rule. | A following pulse field; pins can create further pins; rolling on water creates ground. | Reveal card and partner glyph. |
| Evolution | Replaces a ripe part with a transformation that changes the preferred action sequence, route or target order. Demonstrate the changed choice in paired play. | Pinball Hull makes rebound chains a route; Meteor Frame makes height a repeatable attack resource. | Crate anticipation, transformation and resolving chord. |

An on-hit burst, chance refund or once-per-stage heal is a rare behaviour, not a rule rewrite. A gun's corkscrew is a delivery shape, not an autonomous tornado. Evolution is an explicit effect tier even if compatibility storage still uses `rare_plus` plus `evolved`.

W13 also has context overrides: a first find or completed synergy can earn a reveal, and a Warden cage/cache can earn ceremony without promoting its contents. Any pause queues until calm, preserves velocity, accepts any input to skip and respects full/short settings. Combat reveals stay in motion. No common stat gets an evolution promise because its number is large.

### Inventory disposition

Counts before cuts: 28 catalogue + 58 item-table + 4 shop-cell rows = 90 authored rows. In the table, IDs in C and + are exhaustive; every other row in that family is R. E is zero throughout: the sixteen Systems evolutions are proposals, not live pool entries. Seam-gated rows count as definitions, not working effects.

| Source / actual family | Rows | C | R | + | Outside ladder | Explicit C and + assignments |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `parts.gd` weapon | 11 | 9 | 2 | 0 | 0 | C: hot_rivets, loose_trigger, long_barrel, slag_rounds, double_feed, focus_lens, sunforged_core, gatling_heart, horizon_optic |
| catalogue mobility | 6 | 4 | 2 | 0 | 0 | C: long_spool, tread_plating, boost_coil, dash_vane |
| catalogue stat | 3 | 3 | 0 | 0 | 0 | C: rivet_plating, magnet_spool, ram_plow |
| catalogue pattern | 3 | 0 | 3 | 0 | 0 | R: cross_split, spiral_wave, chain_arc |
| catalogue class | 2 | 2 | 0 | 0 | 0 | C: pylon_capacitor, runner_overclock |
| catalogue milestone | 3 | 1 | 1 | 1 | 0 | C: scrap_gravity; R: tempest_core; +: rime_heart |
| `items.gd` charge | 9 | 6 | 3 | 0 | 0 | C: cap_relay, vault_battery, sprint_cell, cloak_flask, quick_spool, reserve_tank |
| item weapon | 14 | 1 | 11 | 2 | 0 | C: tracer_round; +: ten_pin, domino_wire |
| item defense | 10 | 5 | 5 | 0 | 0 | C: spring_hull, ballast_drum, rivet_seam, crush_guard, scrap_armor |
| item mobility | 11 | 6 | 5 | 0 | 0 | C: long_lane, light_frame, glide_vane, grapple_coil, anchor_spring, low_rider |
| item utility | 11 | 2 | 7 | 0 | 2 | C: magnet_coil, fast_hands; remove synergy_lens and par_chip from loot |
| item pattern | 3 | 0 | 3 | 0 | 0 | R: fan_spread, ring_wave, helix_drill; first/last are seam-gated |
| shop cells | 4 | 4 | 0 | 0 | 0 | C: cell_weapon, cell_movement, cell_special, cell_smash |
| Total authored | 90 | 43 | 42 | 3 | 2 | E: 0. Information belongs in the base interface, not the power ladder. |

Salvage Drone is R today: `item_effects.gd` starts a four-second magnet bonus, with no drone actor. Warden Ward heals a surviving low-health player once per stage; it does not prevent lethal damage. Both descriptions must match those limits. Frost Barb currently bursts and affects materials; it does not prime an enemy yet.

The generator has six base families, five generated: weapon, mobility, defense, utility, charge; authored-only pattern is the sixth. Each generated base has 192 recipe IDs. Its four scalar affixes are 1.12/1.25/1.5/2.0, crossed with four element tokens and twelve triggers: **960**, not an unbounded pool. Each old rarity label covers 240 recipes; each element token covers 240. These are recipe counts, not distinct strategies.

| Generated template families | Templates | Recipe IDs | Effect rung |
| --- | ---: | ---: | --- |
| Rebound/vault strength scalers | 2 | 160 | C: on_rebound, on_vault |
| Hit/kill/smash/release/cloak-break/landing/pickup/damage responses; speed-to-charge; timed next-hit arm | 10 | 800 | R: the other ten triggers |
| Autonomous actors or changed system relationships | 0 | 0 | No generated + or E qualifies today. |

Remove rarity from generation's effect-strength choice. Collapse four scalar versions to one effect identity, then remove element variants that the executor never consumes, such as frost on a speed bonus. Keep explicit power tuning separate from rarity. Remove player-facing `uncommon`; source access and price need their own fields. Migrate source filters, weights, guarantees, shop tiers and old recipe decoding together, without rerolling held recipes on retry.

The eight named synergies plus `linked_spiral` are nine derived combinations, not nine extra held items: seven R behaviours and two + fields, Tesla Pylon and Pinwheel. Their first-completion reveal follows W13. Consolidate their executors with the same reaction/actor rules; preserve Found records. A proposed evolution that only supplies automatic zaps remains + until its route/sequence test passes.

## 2. Delivery belongs to the action

Every eligible part names channels, never a mouse button or weapon ID. Channels are metadata on the existing twelve triggers, not six new trigger kinds. A class has all six; a particular part can deliberately prefer one. Hits and contact can describe the same action, so each commitment carries a stable action ID, source slot, target IDs and committed geometry. Resolve each part and each target once for that action, including smash plus landing reports.

| Channel | Sable | Rivet | Kest | Tally (DESIGN-V3, Tally's program cards) |
| --- | --- | --- | --- | --- |
| Hit | Arc caster or mounted turret impact | Laser impact | Sticky explosion impact | Capacitor discharge and Link arc impact; noncontact, governed as guns |
| Ram/contact | Roll, winch collision or enemy rebound | Roll or sprint ram, including Ram Fins | Roll or post-blink collision | Roll or surge ram and rebound |
| Drop/slam | Hard landing / arc slam | Hard landing / shockwave skid | Hard landing / demo slam | Hard landing / Stamp slam |
| Special | Detonation gauge; tree variants retain this channel | Overdrive blast / Point Blank | Detonation line | `plate_return`'s corridor, firing on the enemies inside it when the plate folds |
| Kill | Any owned kill, at victim position | Same | Same | Same |
| Pickup | Scrap collected, at collection position | Same | Same | Same |

Hit uses `on_hit`; contact filters its ram/stomp source or `on_rebound`; drop uses `on_smash`/`on_land`; special uses `on_charge_release` filtered to the special slot and its actual affected geometry; kill/pickup use their existing kinds. Kest's charged weapon also emits release: it must not masquerade as a special. Tree-triggered specials carry provenance so free echoes cannot open fresh proc roots.

Keep native kits and all 30-node trees. Adapt their output facts: Sable's Cannonball/Beachhead, Rivet's Gunline/Juggernaut and Kest's traps/stealth remain distinct ways to reach the shared channels. Tally's mapping is specified in DESIGN-V3 (Tally's program cards); pil-G7 implements it.

Universal patterns change the geometry at a hit: Cross Split emits short radial fragments, Chain Arc jumps to a neighbour, Spiral Wave sweeps outward from that contact. Ball/melee impacts can deliver all three without gaining a firing input. Translate `shot` elements to hit; Frost Vane's dash trail gets an equivalent moving-contact trail for a kit without air dash. Rime Heart supplies a small enemy frost-contact response on dry ground as well as its water-road rule, so water is an opportunity rather than a prerequisite.

Universal punch scales direct delivery damage. Do not retain weapon-rate, gun-range or rope-only bonuses in the universal pool: fold those into class trees with their proper weapon/movement tuning. Move the ten explicitly class-gated catalogue/item rows there too. Four shop cells remain slot services, offered only when extra capacity can actually be spent before refill; zero-cooldown weapon/smash cells are suppressed. This removes dead offers without pretending every capacity increase is useful.

## 3. One prime-and-detonate grammar

Start with **shock**, **frost**, **pin**. Arc applies shock; frost applies frost; pin is a new polymorph status delivered by kinetic items, not a fourth element. Reserve burn for later; radiation uses shock ticks until it earns a distinct decision. Each prime lasts four seconds after its latest application, with one mark per kind and at most three per enemy. Show a compact cluster of distinct shape glyphs and expiry arcs in the owning class colour. Owning two primers must not silently disable either item.

Any equipped primer can use any of the six channels. Start deterministic: Static Burr primes shock on hit, Frost Barb primes frost on hit, and repurpose Pin Setter to prime pin on contact. Offer-card channel glyphs disclose these bindings. Kill/pickup primers affect at most three enemies within 6 m; with none nearby, bank one primer for the next direct hit within four seconds. Fields and slimes use the same apply operation.

Detonators are a later special, damaging ram/contact or hard drop/slam, or an incoming second element shown below. Test only primes present before the root action, oldest eligible first, with status ID breaking ties. At most one reaction per target per action; consume that prime and do not re-prime that target in that action. Unconsumed marks remain. Otherwise apply each equipped primer once, refreshing its own mark. A ball-only pilot primes on its first contact and detonates on a distinct re-contact after separation and at least 0.5 s. Merely resting against an enemy does neither repeatedly.

| Existing prime | Later special / heavy contact / hard landing | Incoming arc hit | Incoming frost hit |
| --- | --- | --- | --- |
| Shock | **Discharge**: arc jumps to up to three neighbours | Refresh shock, no reaction | **Short Circuit**: damage and 0.6 s root on the target |
| Frost | **Shatter**: short shard burst, at most six targets | **Shatter**, same result | Refresh frost, no reaction |
| Pin | **Bowl Over**: the pinned enemy is knocked flying as a bowling pin into its neighbours, which enter the pin rule's chain (Strike, Spare and Turkey callbacks) | Apply shock alongside, no reaction | Apply frost alongside, no reaction |

Nine cells, five reacting pairs, four named reactions: Discharge, Shatter, Short Circuit, Bowl Over. Heavy-action lookup wins over incoming-element lookup, so an arc slam does not detonate twice. A normal kinetic hit applies its equipped primer; it is not automatically a heavy detonation. **The pin prime is a polymorph** (Andrew, 2026-09-28: "turn them into bowling pins or something stupid or funny like that"). A primed enemy pops into a bowling pin for up to 1.5 s: it can't move or start attacks, it wobbles when touched, and it keeps its hit points. Cancel its interrupted telegraph through the attack owner; animation alone cannot cancel damage. Projectiles already released remain live. The detonation, Bowl Over, bowls it: the pin flies along the hit direction and knocks up to three neighbours into the existing pin rule (DESIGN-V2 §3, `lanes.gd` Strike, Spare and Turkey), so the joke feeds the ball culture's own scoring. The pin swap is presentation over the same enemy body, not a new enemy. Bosses resist: a pin-shaped flicker and a resisted cue, without cancelling a boss attack or extending its window.

No trigger literally becomes a status. `on_hit`, `on_kill`, `on_pickup` normally apply primes; `on_smash`, `on_land`, eligible `on_rebound` and special `on_charge_release` normally detonate. A primer row can explicitly bind those latter channels instead. `timed` services actors; `on_speed_tier_up` keeps charge/refund behaviour. `on_damage_taken` retains retaliation but never unlocks an uncapped counter-chain. `on_vault` and `on_cloak_break` remain class-tree events; remove them from universal generation. All twelve kinds remain closed.

Keep one kind per pass, `MAX_CHAIN_DEPTH = 1`, zero proc coefficient for build-owned damage and no item-generated fresh proc roots. Reactions neither apply primes nor spawn actors. Actor pulses may apply primes directly but never detonate or post item triggers; their kills pay normal bounded encounter scrap without item-proc recursion. A separate player commitment is needed to cash them out.

Extend the existing table design, not individual abilities: enemy statuses and terrain materials have distinct target types resolved by one shared dispatcher. Preserve `frost:water` road, `arc:water` electrification, and `arc:ice`/`kinetic:ice` shatter. Ice and enemy-frost use the same Shatter result and shared per-action target budget; overlapping ice and frost do not double-hit. Thermal Shock becomes this sequence's recipe plus its explicit tuning, not a second reaction engine. Resolve committed geometry once for damage and drawing, as TADR-009 requires.

Preserve Systems §6: one hostile controller per pack, at most two holds pending across packs, and total player hold time at most 1.8 s in any 4 s, followed by existing 2.5 s immunity. A third controller waits; it does not hide an extra hold in a reaction. Every hostile control still uses `player.crowd_control` and `holds.gd`, including Rivet's sprint immunity. Enemy pin/root share a per-enemy 1.8 s/4 s control budget and 2.5 s immunity too; refreshing primes cannot reset it. This enemy clock is new, not a claim that player Holds already supports enemies.

## 4. Persistent actors with a screen cost

Use Feel §1.2's single `density.gd` ledger: `clamp(0.35*threats/6 + 0.35*fx/40 + 0.3*enemies/12, 0, 1)`, 0.25 s rise / 0.6 s fall. The costs below are proposed P5-equivalent reservations within its 40-effect budget, not a second scalar. Shared caps still include 64 bolts, 12 zap lines and 8 rings. No actor gets a private pool that escapes those counts.

| Kind | Per-player hard cap / lifetime | Peak reserved P5 cost per instance | Strategic job |
| --- | --- | ---: | --- |
| Following pulse field | 1 / while equipped; 0.75 s tick, two targets | 3: field glow + two arcs | Prime shock while passing close; leave the pack and return with a drop. |
| Radiation zone, deferred | 1 / 6 s, three targets per 1 s tick | 3: footprint glow + two coalesced wisps | Place shock on a route enemies will cross. |
| Orbiting/spitting tornado, deferred | 1 / 6 s; at most two live spits | 4: body decoration + trail + two spits | Sweep a different lane; random heading is seeded and shown before a spit. |
| Slimes | 2 / 4 s each; one small blast each | 2: body decoration + blast | A kill drops a slime; after 1 s it hops to the nearest enemy within 6 m, bursts to prime pin, then expires. |

First two actors are the field and slime. Replace Tempest Core's bundled pattern numbers with the field; replace Scrap Gravity's stat bundle with slimes. These IDs become + only when the actors work. Reuse Tesla Pylon's two-target pulse implementation, with one shared field cap if both sources are owned. Pinwheel shares the actor ledger as well.

At cap, refresh the same field or replace the oldest slime; never multiply output on refresh. Keep a combined budget of eight reserved P5 units for new actors. Admission at a full budget deterministically refreshes an owned instance or refuses a new spawn and records it. Density only sheds decoration after admission, never damage, targeting geometry or live actor lifetime. Account child spits once in the shared bolt/effect ledger. No creature breeding, actor-on-actor spawning or loot from your own actors. Clear every actor on stage teardown/retry; rebuild from run state without duplicates.

Friendly actors wear class colour, a clean rounded owner collar and the class instrument; never red or HAZARD stripes. Their effect glyph distinguishes shock, frost and pin without changing ownership hue. Actual damaging footprints/heads are P3 committed geometry; ornamental glow is P5 and yields first. No tornado fog hides an enemy edge, window beam, hold binding or kicker lip. Friendly actors have no blocking collision with the ball and never alter its velocity for visual effect.

## 5. Optional active/consumable layer

**Cut the fifth slot from the first build.** Existing F specials already bank to four charges and provide deliberate detonation. A fifth key would repeat that decision before its absence has been felt. Keep these six candidate effects as a bounded later test, not six items to build now.

If a fifth slot earns admission, it holds exactly one device: either a 30 s recharge active with two stored charges, or a consumable stack of up to three with no automatic refill. Swapping in Moss's bay replaces it; no off-slot backpack. Use the existing charge presentation but add explicit refill policy: current `AbilityState.tick`, stage refill and generic charge grants must not manufacture consumables. Snapshot stock in run state; buying spends wallet only and never grants repeatable heft for each refill.

| Candidate | Mode | Choice it adds |
| --- | --- | --- |
| Detonator tin | Consumable | Detonate all primed targets in a shown 8 m radius, at most six; each uses its own matrix row. |
| Primer canister | Consumable | Prime up to six enemies in a shown radius with the prime chosen at the bay; do not detonate on application. |
| Frost stamp | Active | Prime frost in a narrow lane; save its second charge for a second drop line. |
| Grounding fork | Active | Apply arc in a short cone, shattering old frost and priming unmarked enemies with shock. |
| Pin rack | Consumable | Pin everything near you now; hold the special for when enemies crowd the landing. |
| Salvage lure | Active | Move up to three existing primes from distant marked enemies to nearer unmarked enemies; consume originals, no duplication. |

Admission requires paired play to show a distinct hold/spend decision unavailable through F, without worsening threat reading. If admitted, replace Moss's redundant capacity-cell shopping with device stocking, and fold permanent capacity picks into the existing tree; do not retain both economies. Otherwise cut this layer permanently from the final draft.

## 6. The decisions and their loops

| Layer | Decision | Information the player sees | Loop fed |
| --- | --- | --- | --- |
| Moment to moment | Aim, dodge, mark a target, then choose contact or special to detonate. | Committed danger edges, prime glyphs/expiry, ready charge pips. | Action → prime → reposition → reaction → kill/scrap. |
| Per fight | Route through a marked pack or save the drop for the Warden opening; spend one charge or stockpile. | Target cluster, landing geometry, return lane, boss aperture and integrity. | Lap → drop/opening → earned choice → return. |
| Per stage | Spend on a missing primer, actor or recipe piece; take a disclosed bet or the safe route. | Shelf price against wallet, missing partner glyph, gate preview, bet stake/odds if that optional family is admitted. | Explore → earn → buy/risk → break reward. |
| Per run | Commit to rebound chains or height attacks; nominate one evolution before the break. | Ripe socket, partner tag, selected rig silhouette, actual prior-run discoveries. | Build hypothesis → acquire pair → transform → test on next stage → try another run. |

Keep Systems' clock and build-aware director; measure delivered power before increasing population. Preserve the source of each reward. Fund drop choices from a finite Warden integrity budget, settle skipped thresholds at break and reject repeated contacts; stronger drops must not lose picks. Bets/rule parts remain roadmap-deferred. If later admitted, begin with one skill trial and one fully disclosed luck wager, not the whole catalogue. No new currencies or permanent progression layer.

## 7. Minimum build order and exact files

All paths below are relative to `sketches/core-loop/`; **new** means proposed, not present. These are serial build units for the coordinator after authorization, not fresh parallel assignments. Shared files and W11/W13/Feel reservations require admission before the next unit edits them.

| Unit / smallest output | Exact files | Gate before continuing |
| --- | --- | --- |
| M0 Delivered-damage baseline and provenance | `src/combat/combat.gd`, `src/combat/enemy.gd`, `src/combat/bolts.gd`, `src/core/game_events.gd`, `src/core/run_log.gd`, `tools/bot_driver.gd`, `tools/balance_report.gd`; **new** `tests/combat_delivered_damage_test.gd` | HP actually removed at near/mid/far range, retirement counts and drops-to-break; source/target/action attribution reconciles. |
| M1 Effect ladder, cuts and six channels across three kits | `src/build/parts.gd`, `src/build/items.gd`, `src/build/item_gen.gd`, `src/build/part_def.gd`, `src/build/build_sheet.gd`, `src/build/build.gd`, `src/build/triggers.gd`, `src/build/item_effects.gd`, `src/build/shop.gd`, `src/build/synergies.gd`, `src/build/reward_gates.gd`, `src/build/fabricators.gd`, `src/core/run_state.gd`, `src/core/class_def.gd`, `src/core/ability_state.gd`, `src/core/upgrade_tree.gd`, `src/core/trees/sable.gd`, `src/core/trees/rivet.gd`, `src/core/trees/kest.gd`, `src/combat/pattern.gd`, `src/combat/combat.gd`; `tests/build_catalogue_test.gd`, `tests/item_trigger_test.gd`; **new** `tests/build_channels_test.gd` | Counts reconcile; no numeric +; six natural channels per class; action dedup; retry preserves old recipes. |
| M2 Three primes, four reactions, shared CC cap | `src/build/elements.gd`, `src/build/element_field.gd`, `src/build/item_effects.gd`, `src/build/build.gd`, `src/build/synergies.gd`, `src/build/items.gd`, `src/combat/combat.gd`, `src/combat/enemy.gd`, `src/combat/chaser.gd`, `src/combat/lobber.gd`, `src/combat/counter.gd`, `src/combat/swarm_remnant.gd`, `src/combat/fleet.gd`, `src/combat/holds.gd`, `src/movement/player_ball.gd`, `src/world/director.gd`, `src/core/event_kinds.gd`; **new** `src/combat/reactions.gd`, `tests/combat_reactions_test.gd` | Matrix, geometry, no self-detonation, hostile hold admission and shared enemy CC clock all hold. Enemy action owners explicitly suspend startup and cancel interrupted attacks; changing the base animation alone fails. |
| M3 Two actors, integrated with Feel F1a | `src/build/item_effects.gd`, `src/build/build.gd`, `src/build/parts.gd`, `src/build/synergies.gd`, `src/presentation/vfx.gd`; **new** `src/build/persistent_actors.gd`, `tests/build_actor_budget_test.gd`; shared planned `src/presentation/density.gd` | Field + slimes only; same simulation under dense/quiet rendering; caps include synergies and child effects. |
| M4 Two evolutions and their W13 handoff | **new** `src/build/evolutions.gd`, `tests/build_evolution_test.gd`; `src/build/parts.gd`, `src/build/build.gd`, `src/build/item_effects.gd`, `src/build/accretion.gd`, `src/core/run_state.gd`, `src/core/event_kinds.gd`, `src/movement/player_ball.gd`; `tests/build_catalogue_test.gd` | Pinball Hull + Meteor Frame only. Nominate before break; ripe ×2, a different held partner with speed/kinetic respectively; consume ripe copies, retain partner and explicit inherited effects/tags/heft. Eligibility precedes break rewards. Physical rebound and changed route measured. W13 consumes tier/result events in its own reserved files. |
| M5 Paired strategy and dense-motion qualification | `tools/bot_driver.gd`, `tools/bot_run.gd`, `tools/balance_report.gd`, `tools/item_fuzz.gd`, `tests/item_fuzz_smoke_test.gd`; **new** `tests/build_strategy_test.gd`; Feel's planned `tools/stress_capture.gd` | Measures below on one admitted candidate; coordinator runs smoke and records Andrew's play. |

Defer burn, radiation, tornadoes, the fifth slot, Screaming Spiral/Glacier Wake and the other twelve evolutions, meta, rule parts, curses, blessed Wardens and seed-entry UI. Retain the live enemy population cap. An unavailable seam is not permission to build an extra system.

Cut numeric duplicates from offers: fold Slag Rounds/Sunforged Core/Ram Plow into Hot Rivets plus existing health progression; Double Feed/Gatling Heart into class fire-rate tuning; Long Barrel/Focus Lens/Horizon Optic/Tracer Round into class reach tuning; Tread Plating/Low Rider into Light Frame; Rivet Plating into Rivet Seam; Magnet Spool into Magnet Coil; Long Spool into Sable's grapple tuning. Preserve Spring Hull, Tumbler Bearing and pair tags used by the two first evolutions. Replace Tempest Core/Scrap Gravity bundles with the two actors. Merge Reserve Tank and class capacity-item duplicates into the existing charge/tree choices. Cut Par Chip/Synergy Lens as loot; show splits and recipe hints through the existing opt-in interface.

Disable fresh generic recipe offers for the first build; retain deterministic decoding for old runs. Re-admit generated families only after channel and effect tests pass. Drop seam-gated Fan Spread/Helix Drill from new offers rather than building them now. Move Feedback Loop's still-missing cloak extension to the deferred class-tree work. Preserve HAPPY-ACCIDENTS' five records and unresolved KEEP/KILL calls; rarity reassignment or offer removal does not silently decide those verdicts.

Before deleting an ID, migrate every synergy `shown` reference and evolution pair carrier that used it to a retained equivalent, with the same distinct-part condition and deliberate tag coverage. Audit class gates and milestone event rewards too. Keep old-ID decoding and discovery history; remove only redundant new-offer/execution paths after callers migrate. Re-measure recipe reach at the actual break, including consumption and finite rewards; do not reuse the earlier 47.5%/84% simulator result as proof.

## 8. Measures and decision gates

All bands are proposed acceptance targets, not measured successes. ROADMAP rows 3/5/6/11 require the same candidate; row 10 additionally needs the separate quiet-GPU native performance runs. Automation establishes use and consequence; Andrew judges readability, humour and whether another run sounds interesting.

| Measure | Method | Initial pass band |
| --- | --- | --- |
| Prime-and-detonate is used and pays | Sixteen fixed seeds per class, stage and paired bot policy. Same build, route budget and action cadence; compare deliberate prime→detonate against timing-blind action order. Attribute actual HP removed once by action/source, clamp overkill, exclude scenery, report boss/adds separately and report zero-damage runs. | Reaction damage / all player-owned delivered damage **15–30%** in reaction-equipped runs; deliberate policy at least **10%** faster median matched-pack clears. At least **50%** of eligible live primes consumed by a later player action. Pinned time is reported separately as attacks denied; Bowl Over chains count their real damage only. |
| No offered part is dead on a class | Enumerate every retained offer and active tree variant for Sable/Rivet/Kest; exercise six channels naturally with movement/combat bots. Require its primary effect, not incidental heft or base punch, to change damage, resources, route access or cooldown in a valid fixture. Class-only rows cannot enter universal offers. Compare low/high-frequency delivery for proc dominance. | **0 dead offered rows**, **100%** retained effect-family coverage per class; six of six channels observed without event injection. Once Tally's kit lands, exercise its six channels with the same bots; program effects count as noncontact. |
| Effect rarity is honest | Exhaustive retained catalogue plus all admitted generated recipes. Each + names an actor implementation/cap or an executable before/after rule predicate. Observe spawn/ticks or changed rule outcome. | **100%** of + rows spawn an actor or install a demonstrated rule; **0** scalar-only rare/+ rows. Evolution needs paired evidence of changed route, target order or action sequence. |
| Control and chain limits hold | Overlap enemy controllers, prime refreshes, pin/root, actor kills and special echoes; inspect the one action/CC ledgers through teardown/retry. | Player pending holds ≤2; one controller/pack; hard control ≤1.8 s/4 s and 2.5 s immunity; one target reaction/action; chain depth ≤1; no actor/proc recursion. |
| Spectacle still reads | Actor caps and Feel ledger every frame; dense moving footage at 1080p with the same damage schedule as low density; W13's first-fire cue exercised once per new effect. | No cap overflow or governed threat/target geometry; fight HUD ≤25 words, calm ≤40. Andrew can distinguish a prime, detonation and hostile warning while moving. |

The historical fuzzer only exercised ten of twelve triggers naturally; smash and vault were injected. M5 must close the relevant natural-action gaps rather than counting bus injection as class coverage. Wacky control and persistent actors earn expansion only after these measures, not through a larger count of item names.

## Andrew's answers (2026-09-28)

1. **Primes:** shock, frost and pin first. Andrew then changed wobble's dancing Jig into the pin polymorph: enemies become bowling pins that Bowl Over sends into their neighbours, feeding the lanes' Strike, Spare and Turkey callbacks. Burn and damage over time come in the next pass.
2. **Active slot:** deferred. F's stockpiled charges stay the consumable layer. Add a slot only if play shows a decision is missing.
