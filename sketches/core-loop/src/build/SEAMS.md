# Build seams

This is what the build module (writer B) offers the other modules, and what it reads from them. [CONTRACTS.md](../../CONTRACTS.md) stays the binding contract. This file names the ids and calls on top of it.

## Reaching the build

The build entry node is published on the context as `ctx.get_meta("build")`. This is a stopgap: a `ctx.build` field is a pending spine request. Once the spine adds it, `ctx.build` is the same node. Neither route loads a file from `src/build/`.

Build is set up after world and combat, so take the reference lazily, for example on `stage_entered` or the first time you need it.

## Weapon numbers (combat reads these, no build call needed)

Parts scale weapon numbers through tuning mods, as they scale movement. Read them with `ctx.tuning.mod(key)`, which returns 1.0 when nothing is held. Do not use `tuning.f(key)`: these keys are not tuning sliders.

| Key | Meaning |
| --- | --- |
| `weapon_damage` | multiplier on class weapon damage |
| `weapon_rate` | multiplier on fire rate (divide the cooldown by it) |
| `weapon_range` | multiplier on weapon range |
| `turret_damage` | extra multiplier on weapon damage while mounted (Pylon Capacitor) |

Build owns every tuning mod: it calls `tuning.clear_mods()` and reapplies the whole build on each recompute. A module that sets its own mods loses them at the next recompute.

## Weapon-pattern transformers (combat implements these)

Pattern levels stack. Each copy of the part adds a level, and milestones and synergies add more. Combat decides what a level draws and caps it for visual clarity.

| Id | Part that grants it | Intent |
| --- | --- | --- |
| `cross_split` | Cross Split | shots split into a cross; more arms or splits per level |
| `spiral_wave` | Spiral Wave, Tempest Core (+2) | shots spiral outward in a wave; more bolts per level |
| `chain_arc` | Chain Arc, Tempest Core (+1), Storm Lattice (+1) | a hit chains to a nearby enemy; one more jump per level |
| `storm_lattice` (transformer) | synergy: Cross Split + Chain Arc | every split bolt chains once |
| `thermal_shock` (transformer) | synergy: Frost Vane + Arc Coil | handled inside build; combat may ignore it |

Read them with `build.pattern_level(id) -> int`, `build.patterns() -> Dictionary` and `build.has_transformer(id) -> bool`. Without the build reference, `ctx.run.parts.count("cross_split")` (and the same for `spiral_wave` and `chain_arc`) gives the base level. The part ids equal the pattern ids, but that fallback misses milestone and synergy levels.

## The element x material table (any module)

- `build.apply_element(element_id, at: Vector3, source := "") -> Dictionary` resolves the table once at `at` and leaves the result in the world. It returns `{element, material, behaviour, at, source, ...}`, or `{}` when the pair does nothing.
- `build.material_at(point) -> Dictionary` returns `{material, surface_y}` or `{}`.
- `build.resolve(element_id, material_id) -> Dictionary` is the pure table row, with nothing applied.
- `build.register_material(material_id, provider: Callable)`: `provider(point: Vector3) -> Dictionary` returns `{"surface_y": float}` when the point is over that material, else `{}`.

Elements are `frost` and `arc`. Materials are `water` and `ice` (ice is created by frost on water). The rows are:

| Pair | Behaviour |
| --- | --- |
| frost x water | an ice slab: a StaticBody3D on physics layer 1, radius 3.6 m, lasting 9 s, blinking for its last 1.5 s |
| arc x water | electrified water for 3 s: an enemy standing in it takes an 8-damage `arc` strike every 0.25 s |
| arc x ice | shatter: nearby ice bursts and strikes enemies within 6.5 m for 26 (x2 with Thermal Shock) |

Any other pair does nothing.

### What build needs from world (writer D)

The table needs to know where water is. Either answer `ctx.terrain.material_at(point: Vector3) -> Dictionary` with `{"material": "water", "surface_y": float}` over flood water and `{}` elsewhere, or call `build.register_material("water", provider)`. Until one exists, frost and arc find no water in live play. The tests register their own water.

A stage event that brings an element uses the same table through `build.apply_element`. An example is a cold snap that freezes the flood.

## Offer records (presentation and HUD may read)

`reward_offered(offers)` records keep the contract keys `part_id`, `at`, `facing` and `width`. They add `name`, `text`, `rarity` (`common`, `rare`, `epic`), `tier` (1 to 3) and `synergy` (the name of the synergy this gate would complete, or `""`).

`build.part_info(part_id)` returns `{id, name, text, rarity, tier, family}` for a toast, a sound or a card.

## Milestone parts (world triggers, build grants)

`run.record_milestone(event_id)` publishes `milestone_won`, and build grants the part with source `milestone`:

| Event id | Part |
| --- | --- |
| `surge_run` | Rime Heart: you freeze water you roll over, cruise +10% |
| `hold_the_relay` | Tempest Core: spiral +2, chain +1, fire rate +30% |
| any other | the first of Scrap Gravity, Tempest Core, Rime Heart not yet held |

Gates and fabricators never offer milestone parts.
