# Experimental Builds, Salvage Economy & Scrap Ecology Blueprint (Pillars 1 & 3)

**Status:** Experimental prototype & design blueprint (`experimental/builds-ecology` on `stage/alpha-w47`).  
**Scope:** Pillars 1 (Jury-Rigged Builds, Modular Chassis & Overclock Instability) and 3 (Ecological Scrap Ecosystem: Interactive Props, Neutral Mechanical Couriers, Role-Based Enemy States), built on a shared Environmental Tag Substrate designed for direct composition with `exp-director-events` and `exp-vertical-setpieces`.

---

## 1. Design Thesis: Unmistakably Scrapkeep

Scrapkeep is a crew of loose cannons, bulls in the Foreman's china shop, taking their world back from an AI that believes life can be optimised into perfection ([STORY-MAP.md](../STORY-MAP.md)). Today's shipped `src/build/` layer already has strong foundations — maker tricks (`src/build/synergies.gd`), bounded trigger passes (`src/build/triggers.gd`), bit-masked shot mutations (`src/build/shot_bits.gd`), element-by-material rules (`src/build/elements.gd`, `src/build/element_field.gd`), and two hot-wired parts (`src/build/hotwire_rules.gd`).

This experimental track pushes those exact seams forward in three directions without violating any core ruling:

1. **No flat stat-sticks, ever.** Every experimental chassis part is a decoupled Godot 4 `Resource` (`src/experimental/part_resource.gd`) mounted to a physical chassis slot (`WEAPON`, `DASH_LINE`, `CORE_HUSK`) that rewires a player verb, emits or consumes environmental tags, and carries a concrete **give-and-take trade-off** (STORY-MAP §5.3: *"every gain trades against something, and mixed parts that work together beat any one perfect answer"*).
2. **Overclock heat obeys Rule 9 (momentum-first difficulty).** Chaining jury-rigged triggers heats the rig. Running hot (`HOT` / `REDLINE`) rewards bold lines with wider slag trails, extra sawblade lightning hops, and bigger vents. Hitting `REDLINE` opens a **Vent-or-Meltdown gamble**: slam or dash at speed (`>= 12 m/s`) to dump heat into an AoE shockwave, or stall (`< 6 m/s`) and cook your own plating. Keeping cruise (`>= 14 m/s`) cools the rig via airflow and cooks zero hull.
3. **The arena is a living mechanical ecosystem, not a flat bowling lane.** Props, neutral mechanical couriers, and role-based Fleet/Old Works machines all speak the same six environmental tags (`src/experimental/env_tags.gd`). Rupturing a Pressurized Coolant Tank, punting an Explosive Slag Drum into a Shielded Bulwark, or harpooning a fleeing Fleet Hauler Drone all feed directly into your chassis build — and every shortcut carries a readable risk (like a Hauler Drone's Requisition Aggro Ping).

---

## 2. Shared Environmental Tag Substrate (`src/experimental/env_tags.gd`)

### 2.1 Cross-Pillar Contract

To guarantee frictionless integration with sibling experimental pillars (`exp-director-events` hazards & Refurbished Elites, and `exp-vertical-setpieces` EM Cranes & Slag-Pour Furnaces), all three pillars share the exact same canonical vocabulary and payload schema:

- **Canonical `StringName` tags (6):**
  `&"electrified"`, `&"burning"`, `&"slag_coated"`, `&"magnetic"`, `&"coolant_brittle"`, `&"soaked_conductive"`.
- **Canonical payload schema:**
  ```gdscript
  {
      "tag": StringName,       # one of CANONICAL_TAGS
      "origin": Vector3,       # world-space epicentre
      "radius_m": float,       # > 0.0
      "source_id": String,     # non-empty producer identifier
      "intensity": float,      # 0.0 .. 10.0 (scales damage/radius cleanly)
      "ttl_s": float,          # >= 0.0 (zone or actor status lifetime)
  }
  ```

### 2.2 Closed Reaction Matrix (Default-Deny)

Extending `src/build/elements.gd`'s default-deny discipline, `EnvTags.REACTIONS` resolves unordered canonical pairs into deterministic arena reactions:

| Pair | Reaction ID | Gameplay Effect | Consumes | Derived Tag (Depth +1) |
| --- | --- | --- | --- | --- |
| `electrified + slag_coated` | `&"conductive_arc_chain"` | Slag acts as a live busbar; arcs jump up to 3 nearby targets and sever tethers (`1.45x`). | `slag_coated` | — |
| `burning + coolant_brittle` | `&"thermal_shatter_steam"` | Violent flash-quench shatters brittle armor (`1.85x`, `0.5` armor shred) and leaves wet condensate. | `burning`, `coolant_brittle` | `&"soaked_conductive"` (`3.5 s`) |
| `electrified + magnetic` | `&"rail_surge"` | Electromagnetic Lorentz kick snaps metal targets inward (`knock: 18`) and boosts ball speed (`+6.5 m/s`). | `magnetic` | — |
| `electrified + soaked_conductive` | `&"spillway_discharge"` | Spillway's wet-conducts-arc rule (`SPILLWAY-ROSTER.md`): wide `8.0 m` discharge severs tethers (`1.5x`). | `soaked_conductive` | — |
| `burning + slag_coated` | `&"molten_rekindle"` | Re-liquefies cooling slag, scorching armor (`0.25` shred, `1.35x`). | `burning` | — |
| `coolant_brittle + slag_coated` | `&"quench_slag_crust"` | Rapidly hardens molten slag into brittle crust that breaks **1 heft tier lower** (composes with `destructibles.gd` and Slag-Pour cover berms!). | `slag_coated` | — |
| `burning + soaked_conductive` | `&"boiler_cloud"` | Steam pressure ring shoves stalled enemies outward (`knock: 12`). | `burning`, `soaked_conductive` | — |
| `coolant_brittle + magnetic` | `&"cryo_clamp"` | Supercooled magnetic lock slows non-elite machines (`0.45x` speed; elites resist per `Elements.elite_rules`). | `magnetic` | — |

### 2.3 Bounded Cascade Safety (Inspired by `DeferredEffects.tla` & `Triggers.Bus`)

A tag reaction that emits a secondary tag (such as `thermal_shatter_steam -> soaked_conductive`) could easily infinite-loop in naive event graphs. `env_tags.gd` prevents runaway cascades by construction:

1. **Finite depth cap:** `MAX_CASCADE_DEPTH = 2` (depth `0` = direct trigger, depth `1` = first derived emission, depth `2` = terminal; anything deeper is refused and tallied in `stats["depth_capped"]`).
2. **Per-pass reaction budget:** `MAX_REACTIONS_PER_PASS = 12` bounds worst-case frame work in dense clusters.
3. **Per-pass `(subject_key, reaction_id)` guard:** Mirrors `Triggers.Bus.resolving` — any given zone or actor resolves a specific reaction at most once per `apply_tag()` pass (`stats["duplicate_refused"]`).
4. **Consumption on fire:** Every reaction consumes at least one triggering tag so two overlapping persistent zones cannot ping-pong across ticks.
5. **Deterministic spatial ordering:** Overlapping zones and actors are sorted by `(distance_sq, id)` before resolution, guaranteeing reproducible results across runs and `--shuffle`.

---

## 3. Modular Chassis, `.tres` Part Resources & Overclock Risk (`part_resource.gd`, `jury_rig_synergies.gd`)

### 3.1 Physical Chassis Slots, Data-Driven `.tres` Assets & Zero Pairwise Hardcoding

Rather than stacking flat percentage buffs, experimental jury-rigged parts are **real Godot 4 `.tres` Resource assets** under `sketches/core-loop/src/experimental/resources/parts/*.tres`, backed by `PartResource` (`src/experimental/part_resource.gd`) and fitted into three concrete chassis assemblies on the gyrosphere:

- **`WEAPON`**: replaces or mutates active fire / prop-siphon projectiles.
- **`DASH_LINE`**: modifies dashes, slams, and harpoon snaps.
- **`CORE_HUSK`**: modifies scrap intake, thermal venting, and reaction responses around the ball's Hoberman shell.

Every `.tres` resource declares its `maker` (aligned with `src/build/maker_sets.gd`), `trigger` (`&"on_dash"`, `&"on_harpoon_snap"`, `&"on_scrap_pickup"`, `&"on_overheat"`, `&"on_prop_rupture"`, `&"on_weapon_fire"`, `&"on_slam"`, `&"on_tag_reaction"`), `emits_tags`, `consumes_tags`, `heat_cost`, behavioral `effect_id`, and mandatory `trade_off`, `visual_tell`, and `audio_tell` fields validated by `PartResource.validate()`.

**Zero hardcoded pairwise part-ID checks:** `jury_rig_synergies.gd` never checks `if part_a and part_b` or `has_part(&"...")`. Instead, cross-part synergies emerge automatically through three decoupled mechanisms:
1. **`tag_reaction_synergy`**: Part B applies a tag that reacts in `EnvTags` with a zone or actor tag carrying `source_id = "part:<PartA>"`.
2. **`tag_bridge_synergy`**: Part B consumes/bridges an existing `EnvTags` zone (e.g. `slag_coated` or `soaked_conductive`) placed by another equipped part.
3. **`signal_chain_synergy`**: Part A's reaction or prop-rupture event propagates along the bounded event bus (`MAX_EVENTS_PER_PASS = 16`, per-pass `(part_id, trigger)` dedup) and wakes a distinct reactive part subscribed to `&"on_tag_reaction"` or `&"on_overheat"`.

Dropping a brand-new 9th `.tres` part into `resources/parts/` automatically composes with all existing parts and arena props without changing a line of GDScript (explicitly proven in `experimental_builds_ecology_test.gd` with `custom_cryo_anchor`).

### 3.2 Eight Authored `.tres` Jury-Rigged Parts (Three Batches)

| Batch | `.tres` Asset | Maker | Slot | Trigger | Tags (Emit / Consume) | Heat | Give-and-Take Trade-Off |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **A: Flow & Arc** | `arc_welder_dash.tres` | Highdraft Roosts | `DASH_LINE` | `on_dash` | Emits `slag_coated`, `electrified` | `+22` | Heavy line heat per dash; stalling on redline cooks hull. |
| **A: Flow & Arc** | `magnetized_sawblades.tres` | Redjaw | `WEAPON` | `on_weapon_fire` | Emits `magnetic` / Consumes `slag_coated`, `electrified`, `soaked_conductive`, `coolant_brittle` | `+14` | Blades curve toward live magnetic zones (skill shot or self-deflection) and add volley heat. |
| **A: Flow & Arc** | `harpoon_grounding_spike.tres` | Mind-glass | `DASH_LINE` | `on_harpoon_snap` | Emits `electrified` / Consumes `magnetic`, `slag_coated`, `soaked_conductive` | `-15` | Clean snaps dump heat; slow or missed tether reels add `+12` line heat instead. |
| **B: Foundry & Quench** | `slag_skid_crucible.tres` | Fleet Surplus | `DASH_LINE` | `on_slam` | Emits `slag_coated`, `burning` | `+24` | Requires fast roll (`>= 10 m/s`) to spill cleanly; slow slams dump heat back into the rig. |
| **B: Foundry & Quench** | `brine_tap_vent.tres` | Spillway Works | `CORE_HUSK` | `on_overheat` | Emits `coolant_brittle`, `soaked_conductive` / Consumes `burning` | `-65` | Slows passive airflow cooling (`0.7x`) below redline, daring you to run hot and slam-vent. |
| **B: Foundry & Quench** | `thermite_flail_spool.tres` | Waking-made | `CORE_HUSK` | `on_tag_reaction` | Emits `burning` | `+10` | Grants `+1` temporary heft break tier on nearby reactions, but spikes heat straight into redline. |
| **C: Salvage & Audit** | `hoard_coil_ballast.tres` | Moss's Spares | `CORE_HUSK` | `on_scrap_pickup` | Emits `magnetic` | `+8` | Builds pickup heat; stalling while magnetized pulls metal enemy shells closer. |
| **C: Salvage & Audit** | `requisition_leech.tres` | Fleet Surplus | `WEAPON` | `on_prop_rupture` | Consumes `coolant_brittle`, `burning`, `electrified` | `+16` | Doubles prop salvage and fires a homing siphon bolt, but broadcasts a Fleet audit ping (`22 m`). |

### 3.3 Documented Multi-Part Synergy Chains per Item Batch

Each batch produces 2–3 distinct emergent multi-part chains purely through `EnvTags` and event-bus signals:

**Batch A — Flow & Arc Conductors**
1. **Weld-Line Chainsaw** (`arc_welder_dash.tres` + `magnetized_sawblades.tres`): Dash paints a conductive `slag_coated` + `electrified` seam; firing Magnetized Sawblades across it bridges the entire seam (`tag_bridge_synergy` + `conductive_arc_chain` + `rail_surge`), jumping lightning across `3 + heat_chain_bonus` targets!
2. **Overclocked Live-Seam Whip** (`arc_welder_dash.tres` + `magnetized_sawblades.tres` + `thermite_flail_spool.tres`): The sawblade bridge reaction fires `on_tag_reaction`, waking Thermite Flail Spool (`signal_chain_synergy`) to ignite nearby drums and bump heft break tier by `+1`, while pushing heat into `HOT`/`REDLINE` for extra chain hops.
3. **Grounded Rail Slingshot** (`hoard_coil_ballast.tres` + `harpoon_grounding_spike.tres` + `magnetized_sawblades.tres`): Sweeping scrap pulses `magnetic` (`Hoard-Coil`); snapping a harpoon grounds `electrified` right into the magnetized pack (`rail_surge` momentum kick + `-15` heat dump) before sawblades finish the clustered targets.

**Batch B — Foundry & Quench Crucible**
1. **Flash-Quench Crucible** (`slag_skid_crucible.tres` + `brine_tap_vent.tres`): High-speed slam pours `burning` + `slag_coated` and drives the rig into `REDLINE`; slamming again vents `Brine-Tap` via `on_overheat`, triggering `thermal_shatter_steam` (`tag_reaction_synergy`, `1.85x` shatter + `0.5` armor shred) and leaving `soaked_conductive` condensate on the floor.
2. **Live Harpoon Foundry** (`slag_skid_crucible.tres` + `harpoon_grounding_spike.tres`): Crucible slam lays hot slag; snapping a harpoon over the pool grounds `electrified` into `conductive_arc_chain` while simultaneously venting `-15` of the crucible's `+24` heat cost.
3. **Cryo-Saw Shatter** (`brine_tap_vent.tres` + `magnetized_sawblades.tres`): Redline brine vent coats nearby Bulwarks in `coolant_brittle` and `soaked_conductive`; Magnetized Sawblades trigger `cryo_clamp` AND `spillway_discharge` on the same volley!

**Batch C — Salvage & Audit Manipulators**
1. **Audit Detonation Chain** (`requisition_leech.tres` + `thermite_flail_spool.tres`): Punting a Slag Drum or popping a Coolant Tank fires `on_prop_rupture` -> `Requisition Leech` doubles salvage and fires a homing siphon bolt -> `signal_chain_synergy` wakes `Thermite Flail Spool` to ignite adjacent props into a room-clearing cascade.
2. **Magnet-Bowl Harvester** (`hoard_coil_ballast.tres` + `requisition_leech.tres`): Picking up loose scrap yanks nearby Scrap Piles and Slag Drums inward (`magnetic`); slamming through the gathered cluster bowls enemies AND fires Requisition Leech bolts while daring the Fleet audit ping!

### 3.4 Overclock Heat Curve (Rule 9 Verification)

| Heat Band | Range | Synergy Power (`overclock_scale`) | Extra Chain Hops | Moving Fast (`>= 14 m/s`) | Stalled (`< 6 m/s`) |
| --- | --- | --- | --- | --- | --- |
| `cool` | `0 .. 39` | `1.00x` | `+0` | Cools `9.0 / s`, `0` hull cook | Cools `2.0 / s`, `0` hull cook |
| `hot` | `40 .. 79` | `1.15x .. 1.45x` | `+1` | Cools `9.0 / s`, `0` hull cook | Cools `2.0 / s`, `0` hull cook |
| `redline` | `80 .. 120` | `1.75x` | `+2` | Fast slam/dash (`>= 12 m/s`) vents `55–65` heat into AoE shockwave; `0` hull cook! | **Meltdown Cook:** takes up to `14.0 dps` plating burn until you move or vent! |

---

## 4. Ecological Scrap Ecosystem (`src/experimental/ecology_actors.gd`)

### 4.1 Interactive Props

Interactive props complement `src/world/destructibles.gd` (heft-tiered obstacles) by acting as **tactical verbs** that react to momentum and `EnvTags`:

| Prop | Momentum Interaction | Tag Interaction | Tactical Payoff |
| --- | --- | --- | --- |
| **Pressurized Coolant Tank** | Any ball impact ruptures immediately. | `burning` auto-ruptures it. | Emits `coolant_brittle` (`6.5 m`) + `soaked_conductive` (`5.5 m`) + `-30` quench cooling bonus for Overclock rigs! |
| **Explosive Fuel / Slag Drum** | Ball at `>= 12 m/s` **punts** it forward as a sliding kinetic bomb; slam detonates on the spot. | `burning` or `electrified` detonates it; pulled by `magnetic`. | Colliding with an enemy detonates for `32` blast damage + `burning` + `slag_coated` pool. |
| **Harvestable / Throwable Scrap Pile** | Roll gently (`< 14 m/s`) to harvest `4` scrap + `1` cog; slam or roll at `>= 14 m/s` to **bowl** it through up to 4 enemies (`24` dmg each). | Pulled inward by `magnetic` zones (easy grouping!). | Forces a crisp split-second decision: safe scrap now, or kinetic bowling strike + bonus scrap! |
| **Live Exposed Power Conduit** | Striking discharges `electrified` (`5.0 m`) then enters an `8.0 s` bounded cooldown. | Automatically arcs if adjacent (`<= 5 m`) to `soaked_conductive` or `slag_coated`. | Turns flooded lanes and slag trails into reusable environmental traps without infinite spam. |

### 4.2 Lore-Safe Neutral Mechanical Couriers

Per `STORY-MAP.md`, ambient lilac critters are strictly harmless and Fleet animal people are never targets. Neutral couriers are **100% mechanical** Old Works / Furnace Fleet logistics machines:

- **Fleet Requisition Hauler Drone (`hauler_drone`)**: Cast old-works hull stamped with Brindle's brass tag, carrying `1` high-tier unrefined core, `6` scrap, and `3` cogs. Flees toward extraction at `11.5 m/s` (slower than ball cruise `14.0 m/s`, so staying fast catches it). Taking damage or a harpoon snap spills immediate scrap/cogs AND emits a **Requisition Aggro Ping** (`26 m`) that alerts nearby Fleet enemies to intercept. Counter-play: `electrified` stalls its thruster for `1.5 s`, and `magnetic` tugs it off its escape vector.
- **Old Works Audit Skitter-Cart (`audit_skitter_cart`)**: Nimble wheeled ledger drone (`12.5 m/s`) loaded with cogs (`5`). `coolant_brittle` freezes its wheels (`0.4x` speed) for an easy smash.

### 4.3 Role-Based Enemy Ecosystem FSMs & Tag Counter Matrix

Each archetype has an old-works job (`SPILLWAY-ROSTER.md`), a decoupled state machine, and crisp environmental counters:

| Role | Old-Works Job | Baseline Behaviour | Primary Tag & Verb Counters |
| --- | --- | --- | --- |
| **Swarmer** (`swarmer`) | Pipe-Pig Runner | Fast (`9.0 m/s`) pack pursuit leading straight lines (turns slip it). | `burning` breaks pack cohesion (panic `REPOSITION`); `coolant_brittle` amplifies kinetic hits (`1.6x`); `electrified` jolts (`0.8 s` `DISRUPTED`). |
| **Shielded Bulwark** (`shielded_bulwark`) | Stoplog Setter | Holds `SHIELD_BRACE`, blocking `75%` frontal damage. | `magnetic` yanks its heavy steel shield sideways (`DISRUPTED`, exposing rear); `coolant_brittle` cuts block to `20%` and lets a slam/ram shatter the shield outright; `burning + slag_coated` heat-soaks and drops the shield. |
| **Arc Sniper** (`arc_sniper`) | Signal-Tower Relay | Telegraphs a `1.1 s` lane shot from range; repositions if rushed (`< 8 m`). | `electrified` overloads its capacitors (`14` self-arc + cancels windup into `DISRUPTED`); `magnetic` deflects its aim vector (`0.45 rad`); `soaked_conductive` halves its range and boosts arc damage `1.5x`. |
| **Weld-Healer** (`weld_healer`) | Patch-Tether Tender | Seeks wounded allies (`14 m`) and enters `TETHER_HEAL` (`8 hp/s`). | `electrified` OR a **Harpoon Snap** immediately severs the tether, stuns the healer (`2.5 s` `DISRUPTED`), and sends a `15` arc feedback jolt into its healed patient! `coolant_brittle` halves weld rate. |

---

## 5. Visual & Audio Readability Contract (`VISUAL-LANGUAGE.md`)

Every experimental tag and part follows Scrapkeep's colour-meaning and CVD-redundancy laws:

- **Zero `Palette.HAZARD` (`#ff5a3c`) on player-created tags or parts.** `HAZARD` with 45° stripes remains strictly reserved for hostile telegraphs (including the Arc Sniper's `1.1 s` lane tell and the Hauler Drone's Requisition Aggro Ping ring if hostile reinforcements answer).
- **Palette + Shape + Sound triad (defined in `EnvTags.VISUAL_GRAMMAR`):**
  - `electrified`: `Palette.ARC` (`#8bf0d3`) · jagged ring-bolt · `arc_crackle`
  - `burning`: `Palette.COPPER` (`#b77843`) · starburst ember · `forge_hiss`
  - `slag_coated`: `Palette.AMBER` (`#e5a044`) · hex puddle with charcoal keyline · `slag_bubble`
  - `magnetic`: `Palette.COBALT` (`#3d8bff`) · inward four-corner brackets · `coil_hum`
  - `coolant_brittle`: `Palette.ICE` (`#c8f0ff`) · hex shard crust · `cryo_tick`
  - `soaked_conductive`: `Palette.water_tone()` (`#548b84`) · concentric ripple pool · `sluice_wash`
- **Overclock Heat Gauge:** Sits beside Heft as a workshop pressure needle (never a red filled bar, per `VISUAL-LANGUAGE.md` §7), ticking copper in `HOT` and pulsing bone-to-oxide at `<= 3 Hz` (`FlashGuard`-compliant) in `REDLINE`, with a clear hiss/steam visual around the ball's vents.
- **Words-on-screen budget:** Emergent combos emit a single 3-word callout (`"Weld line live"`, `"Quench shattered"`, `"Rail surged"`) reusing `synergies.gd`'s icon-plus-three-words pattern — zero walls of text.

---

## 6. Production Integration Plan & Open Decisions

### 6.1 Concrete Integration Seams (Zero-Risk Phased Fold-In)

1. **Phase A — Tag Field beside `element_field.gd`:** Mount `EnvTags` on `Context` beside `element_field.gd`. Mirror `element_field.gd`'s `"arc"`, `"frost"`, and `"water"` events into `EnvTags.apply_tag()` so existing Spillway water floods automatically carry `&"soaked_conductive"` and compose with `exp-vertical-setpieces` (Slag-Pour Furnaces & EM Cranes) and `exp-director-events` (Rising Slag Tide & Magnetic Storm).
2. **Phase B — Chassis Slots beside `build.gd` & `parts.gd`:** Expose the 3 jury-rigged slots (`WEAPON`, `DASH_LINE`, `CORE_HUSK`) via a dedicated workshop bench at Moss's camp or rare Keeper's Gamble gates (`trade_pockets.gd`), forwarding `Triggers.Bus` commitments (`on_dash`, `on_slam`, `on_pickup`) plus new `on_harpoon_snap` and `on_prop_rupture` hooks into `JuryRigSynergies.dispatch()`.
3. **Phase C — Ecology Actors beside `destructibles.gd` & `spawner.gd`:** Register interactive prop rows in stage maps alongside `destructible_rows` (using the same exclusion validator from `destructibles.gd` so props never block ridden rails or grapple footings). Spawn `NeutralCourier` patrols through `director.gd` at low cadence (at most 1 live per stage) and graduate `Shielded Bulwark` and `Weld-Healer` into World 1 Flume / Slag Bowl packs after band verification.

### 6.2 Trade-Offs & Open Questions for Andrew

- **Overclock Heat visibility on base vs. jury-rigged runs:** Should the Overclock thermal gauge appear *only* once the player equips at least one heat-generating jury-rigged part (keeping the first 3 minutes uncluttered), or always sit on the HUD? **Recommendation:** show dynamically only when a heat-bearing part is fitted.
- **Requisition Aggro Ping fairness line (F1/F3):** When a player shoots a Hauler Drone, alerted Fleet bots should play a visible brass requisition wave + horn tell (`>= 0.6 s`) before lunging so the aggro ping always passes `difficulty-plan.md`'s F1 telegraph check.
- **Slag-Pour & Coolant crust heft synergy:** `quench_slag_crust` drops a slag berm's break tier by 1. Confirm during combined experimental integration with `exp-vertical-setpieces` that `heft_tier_drop` hooks cleanly into `dynamic_setpieces.gd`'s cooled cover berms.
