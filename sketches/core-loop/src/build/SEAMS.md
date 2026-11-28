# Build seams

This is what the build module (writer B) offers the other modules, and what it reads from them. [CONTRACTS.md](../../CONTRACTS.md) stays the binding contract. This file names the ids and calls on top of it.

## Reaching the build

The build entry node is `ctx.build`, set in build's `setup`. `ctx.build_module()` also finds it, and so does the older `ctx.get_meta("build")`. None of these routes loads a file from `src/build/`.

Build is set up after world and combat, so take the reference lazily, for example on `stage_entered` or the first time you need it.

On `stage_content_cleared` build clears the scrap field, the fabricators, open gates and element-made surfaces; pickups, fabricators, gates, kill drops and vault payouts run only while `ctx.flow.in_stage()`, while synergies and elements keep running in the arena.

## Weapon numbers (combat reads these, no build call needed)

Parts scale weapon numbers through tuning mods, as they scale movement. Read them with `ctx.tuning.mod(key)`, which returns 1.0 when nothing is held. Do not use `tuning.f(key)`: these keys are not tuning sliders.

| Key | Meaning |
| --- | --- |
| `weapon_damage` | multiplier on class weapon damage |
| `weapon_rate` | multiplier on fire rate (divide the cooldown by it) |
| `weapon_range` | multiplier on weapon range |
| `turret_damage` | extra multiplier on weapon damage while mounted (Pylon Capacitor) |

Parts also add flat per-hit weapon damage ("punch"), before the multipliers. Read it with `build.punch_bonus() -> float`. Gun punch is `(base per-hit + punch_bonus()) * tuning.mod("weapon_damage")`.

Build owns every tuning mod: it calls `tuning.clear_mods()` and reapplies the whole build on each recompute. A module that sets its own mods loses them at the next recompute.

## Weapon-pattern transformers (combat implements these)

Pattern levels stack. Each copy of the part adds a level, and milestones and synergies add more. Combat decides what a level draws and caps it for visual clarity.

| Id | Part that grants it | Intent |
| --- | --- | --- |
| `cross_split` | Cross Split | shots split into a cross; more arms or splits per level |
| `spiral_wave` | Spiral Wave, Tempest Core (+2) | shots spiral outward in a wave; more bolts per level |
| `chain_arc` | Chain Arc, Tempest Core (+1), Storm Lattice (+1) | a hit chains to a nearby enemy; one more jump per level |
| `storm_lattice` (transformer) | named synergy: Chain Arc plus a part with the split tag | every split bolt chains once |
| `linked_spiral` (transformer) | unnamed rule: spiral + chain tags | the spiral's chain arcs link into a ring |

Additional registered transformers in `Pattern.TRANSFORMERS` (`src/combat/pattern.gd`, 13 rows total): `fan_spread`, `helix_drill`, `halo`, `damage_tier`, `rate_tier`, `range_tier`, `capacitor`, `overclock`, `brass_drum`, and `heavy_breech`.

Build runs every other synergy transformer itself: `thermal_shock`, `lightning_rod`, `tesla_pylon`, `wrecking_ball`, `shrapnel_bloom`, `glacier_hull` and `pinwheel`. Combat may ignore them. Their strikes go through `ctx.spawner.strike` with kind `arc` or `slam`.

Read them with `build.pattern_level(id) -> int`, `build.patterns() -> Dictionary` and `build.has_transformer(id) -> bool`. Without the build reference, `ctx.run.parts.count("cross_split")` (and the same for `spiral_wave` and `chain_arc`) gives the base level. The part ids equal the pattern ids, but that fallback misses milestone and synergy levels.

## The element x material table (any module)

- `build.apply_element(element_id, at: Vector3, source := "") -> Dictionary` resolves the table once at `at` and leaves the result in the world. It returns `{element, material, behaviour, at, source, ...}`, or `{}` when the pair does nothing.
- `build.material_at(point) -> Dictionary` returns `{material, surface_y}` or `{}`.
- `build.resolve(element_id, material_id) -> Dictionary` is the pure table row, with nothing applied.
- `build.register_material(material_id, provider: Callable)`: `provider(point: Vector3) -> Dictionary` returns `{"surface_y": float}` when the point is over that material, else `{}`.

Elements are `frost`, `arc` and `kinetic`. Every slam carries kinetic. Materials are `water` and `ice` (ice is created by frost on water). The rows are:

| Pair | Behaviour |
| --- | --- |
| frost x water | an ice slab: a StaticBody3D on physics layer 1, radius 3.6 m, lasting 9 s, blinking for its last 1.5 s |
| arc x water | electrified water for 3 s: an enemy standing in it takes an 8-damage `arc` strike every 0.25 s |
| arc x ice | shatter: nearby ice bursts and strikes enemies within 6.5 m for 26 (x2 with Thermal Shock) |
| kinetic x ice | shatter: a slam on ice bursts it and strikes enemies within 5 m for 20 |

Any other pair does nothing.

### What build needs from world (writer D)

The table needs to know where water is. Either answer `ctx.terrain.material_at(point: Vector3) -> Dictionary` with `{"material": "water", "surface_y": float}` over flood water and `{}` elsewhere, or call `build.register_material("water", provider)`. Until one exists, frost and arc find no water in live play. The tests register their own water.

A stage event that brings an element uses the same table through `build.apply_element`. An example is a cold snap that freezes the flood.

## Reward gates

- The gates open on `flow_changed("gates")`, never on `beacon_charge_changed`. A sealed beacon's shown charge can reach 1.0 a tick before the Warden's kill is recorded.
- The gates stand downhill of the ball. Build searches headings nearest the ball's line and picks gate spots whose approach stays within 0.75 m of the ground under the ball, falling back to the least-climbing spot (`reward_gates.choose_placement`).

## Offer records (presentation and HUD may read)

`reward_offered(offers)` records keep the contract keys `part_id`, `at`, `facing` and `width`. They add:

- `name`, `headline` ("{name}: {verb}. Punch +{n}"), `verb`, `punch` and `text`
- `rarity` (`common`, `uncommon`, `rare`, `rare_plus`) and `tier` (1 to 3)
- `synergy`: the name of the named synergy this gate would complete, or `""`
- `mark`: the label's star line: `* completes X *`, `* ingredient: ??? *`, `* ingredient: X *` once discovered, or `""`

With --actives on, a gate may stand one more arch for an active (`src/combat/actives/active_offers.gd`): its `part_id` is `active:<id>`, `family` is `active`, `active` and `maker` name it, `rarity` is `rare` or `relic`, and `mark` is `* active, <Maker> *`. Rolling through racks it (`combat.actives.take`) and adds no part.

`build.part_info(part_id)` returns `{id, name, verb, text, punch, tags, rarity, tier, family}` for a toast, a sound or a card.

## Rarity by source

| Source | Rarities |
| --- | --- |
| Gate, 0 bonus cores | common or uncommon |
| Gate, 1 bonus core | uncommon or rare |
| Gate, 2 or more | rare or rare-plus |
| Fabricator | uncommon |
| Vault (`enemy_killed` kind `vault`) | one rare part, `add_part(id, "vault")`; with --actives on, sometimes a rare active too, racked at once |
| Won event (`milestone_won`) | rare-plus |

The gate reads `ctx.run.gate_tier_bonus()`.

## Synergies and the codex (category `build`)

A named synergy is its hint card read literally: its shown part plus any other held part carrying its second tag. The hint reads, for example, "Chain Arc + something that splits". Another part carrying the chain tag does not stand in for Chain Arc. Unnamed tag rules (spiral + chain) fire on any two parts carrying the pair's tags.

`build.codex_declarations()` returns one card per named synergy: `{id, category: "build", name, hint, clue, text, shown, tags}`. With `ctx.codex`:

- Build declares its eight cards on the first tick of play, not in `setup`. `spine_codex_test` counts exact entries right after class select; see the handoff's spine request.
- On a synergy's first activation in a run, build calls `mark_discovered(id, at, ["player"])`.
- On an unnamed interaction's first firing in a run, build calls `mark_found(text, "build", ["player"])`.
- The codex publishes `synergy_discovered` and `interaction_found` and grants the discovery burst. Build never emits those two.

`build.discovered()` and `build.found()` hold the run's own view. `build.is_known(id)` also reads the saved codex.

## Element results (presentation)

Every element-table result publishes `element_resolved(element_id, material_id, behaviour, at)`. The behaviour is `create_surface`, `electrify` or `shatter`.

## Mass, heft and cores

- Accretion is drawn from `run.mass`, `run.parts` and `run.heft_class()`, never from the wallet. A fabricator purchase keeps every chunk. On `scrap_lost`, the chunks the lost mass carried fly toward the event's `at`. The shell scales 7% per heft class above I; the collider never changes.
- The magnet's heft reach is `min(18, 6 * sqrt(heft))` m at standstill, plus 0.3 m per m/s of speed. Pull scales by the same factor.
- A Warden's scrap (`enemy_killed` kind `warden`) drops in a 20 m line along the ball's heading.
- Gate tier reads `run.gate_tier_bonus()`.
- A vault kill calls `run.add_core("vault", at)` after its rare part.
- A won event's bonus core is world's grant (`run.add_core("event", at)` at the event's ring); build grants only the milestone part.

## Milestone parts (world triggers, build grants)

`run.record_milestone(event_id)` publishes `milestone_won`, and build grants the part with source `milestone`:

| Event id | Part |
| --- | --- |
| `surge_run` | Rime Heart: you freeze water you roll over, cruise +10% |
| `hold_the_relay` | Tempest Core: spiral +2, chain +1, fire rate +30% |
| any other | the first of Scrap Gravity, Tempest Core, Rime Heart not yet held |

Fabricators and vaults never offer milestone parts. Only a gate overcharged by two or more bonus cores can.

## Maker sets (any module)

Every item, Moss cell, relic and active row names its `maker` (`maker_sets.gd` lists the seven). Holding a set's piece count of distinct pieces (three, or two for Moss's Spares) turns its bonus on for the run; `maker_bonuses.gd` does what each bonus does.

- `build.maker_counts() -> Dictionary`: maker id to distinct pieces held, counting parts, relics and the racked active.
- `build.maker_bonuses() -> Array`: the live bonus ids, in `MakerSets.SETS` order.
- `build.maker_fires_twice() -> bool`: the active rack asks this at release (Open Frame: fired in the air, fire twice).
- A set completing is announced once a run as `cause_armed("set_" + bonus)`, and each firing as `cause_fired("set_" + bonus, target, at)`. No `CAUSE_ROWS` row exists for them yet, so presentation draws nothing of its own; the bonuses draw with combat's effect rings and sparks.
- Offers lean 1.5x toward a maker's unheld pieces once two of its parts are held (`PartOffers.maker_nudge`). The nudge reads held parts only, since an offer draw sees the part list and not the relics or the rack; the set counts read all three.
- Rounded Up deals its extra through combat's wear-trail bypass (`combat.trail_deal`), the same route the primer mesh uses: a door pass would round its own extra again.
