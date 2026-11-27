# Vertical Junkyard Biomes, Sightline Landmarks & Dynamic Setpieces Blueprint

**Status: Experimental Pillar 2 Blueprint (`experimental/vertical-setpieces`)**
**Companion prototypes:**
- Modular socket & spatial validator: [`src/experimental/arena_chunk_socket.gd`](../../src/experimental/arena_chunk_socket.gd)
- Loadable Godot 4 chunk scene: [`src/experimental/smelter_crane_chunk.tscn`](../../src/experimental/smelter_crane_chunk.tscn)
- Cover-reshaping setpiece controller: [`src/experimental/dynamic_setpieces.gd`](../../src/experimental/dynamic_setpieces.gd)
- Headless verification suite: [`tests/experimental_vertical_setpieces_test.gd`](../../tests/experimental_vertical_setpieces_test.gd)

Read alongside [STORY-MAP.md](../STORY-MAP.md), [VISUAL-LANGUAGE.md](../../VISUAL-LANGUAGE.md), [PARK.md](../PARK.md), [HEFT-DESTRUCTIBLES.md](../HEFT-DESTRUCTIBLES.md), [the World 1 map audit](../../../../project-guide/handoff/shared/world1/map-audit.md), and [the World 1 difficulty plan](../../../../project-guide/handoff/shared/world1/difficulty-plan.md).

---

## 1. Design Thesis: Turning Giant Works Into Vertical Pinball Bowls

Scrapkeep is a crew of loose cannons, bulls in the Foreman's china shop, taking their world back from a machine that believes life can be run perfectly. Today's Spillway stages already prove horizontal momentum and sightlines, but World 1's map audit identified three structural ceilings: static cover, thin vertical combat interplay, and fixed per-run arena geometry.

Pillar 2 pushes Scrapkeep's arenas into **three-tier vertical junkyard bowls** built from snap-together modular `.tscn` chunks where **the works' own machinery reshapes cover and traversal lines live during a fight**. Every biome and setpiece answers the three creative questions from [STORY-MAP.md](../STORY-MAP.md) and honors Rule 9's momentum-first law:

1. **Whose hands made it?** Each vertical space layers **Old Works** cast petrol enamel & uranium-green (`#9dff3c`) structural megastructures with **Furnace Fleet** iron-oxide requisition plating, brass tags, and bolted rigs, plus **Keeper** bolted jump pads, grind rails, and harpoon rigging.
2. **What job was it for?** Every setpiece is a looping industrial machine still performing its old job—sweeping scrap with an electromagnet, pouring slag, cycling pneumatic compactors, or launching orbital salvage pods. None are magical arena traps.
3. **Momentum stays sacred (Rule 9).** Every dynamic hazard presses a ball that stalls, stops, or camps a flat line—and **never dead-stops a ball that keeps rolling, carving, or swinging**. High ground stays safe from ground melee while remaining exposed to lobbed shells and aerial pressure. Every lower basin guarantees at least two unblocked upward momentum translators (`JUMP_PAD` or `HARPOON_ANCHOR`) so no player is ever trapped in a dead-end pit.

---

## 2. Shared Cross-Pillar Environmental Tag Contract

To compose cleanly with Pillar 1 (`exp-builds-ecology`) and Pillar 3 (`exp-director-events`), every setpiece emits and consumes the unified environmental tag vocabulary defined in `dynamic_setpieces.gd`:

| Tag (`StringName`) | Emitted By (Pillar 2) | Gameplay Meaning & Cross-Pillar Synergy |
| --- | --- | --- |
| `&"magnetic"` | Suspended Electromagnetic Crane sweep | Pulls loose scrap, barrels, and metal debris into a high-value pickup ribbon; boosts Keeper scrap intake; **supercharges** (`+40%` pull) once per sweep if struck by `&"electrified"`. |
| `&"slag_coated"` | Slag-Pour Furnace lower basin | Coats floor actors and hulls; slows stalled enemies; hardens into Heft-scaled **Slag Cover Berms** when the pour ends. |
| `&"burning"` | Slag-Pour Furnace molten phase | Inflicts telegraphed thermal pressure on stalled balls (`< 0.55 x cruise`) and grounded packs; fast or airborne balls skim over unhurt. |
| `&"coolant_brittle"` | Consumed from Pillar 1/3 (Cryo/Coolant vents & builds) | **Flash-Quench Reaction (bounded 1x/cycle):** hitting an active `molten_pour` immediately solidifies the pool into **Tier-1 Brittle Slag Cover Berms** shatterable by any Class I ball at sprint speed. |
| `&"soaked_conductive"` | Consumed from Pillar 1/3 (Spillway surges / Flood events) | Triggers the same bounded **Flash-Quench Reaction** on molten slag, turning floor denial into instant breakable cover and scrap loot. |
| `&"electrified"` | Consumed from Pillar 1/3 (Arc builds / Lightning strikes) | Supercharges an active EM Crane corridor once per sweep without infinite re-trigger cascades. |

**Canonical Event Payload Schema (identical across all three experimental pillars):**
```gdscript
{
    "tag": StringName,    # one of the 6 canonical StringNames above
    "origin": Vector3,    # world-space center of the field
    "radius_m": float,    # positive radius in metres
    "source_id": String,  # deterministic source id (e.g. "em_crane:setpiece_em_crane")
    "intensity": float,   # normalized strength (> 0.0, clamped <= 2.0)
    "ttl_s": float,       # remaining lifetime in seconds (> 0.0; ticked down deterministically)
}
```

---

## 3. Modular Vertical Chunk & `Marker3D` Socket Architecture

Implemented in [`arena_chunk_socket.gd`](../../src/experimental/arena_chunk_socket.gd) and proven by [`smelter_crane_chunk.tscn`](../../src/experimental/smelter_crane_chunk.tscn).

### 3.1 Typed `Marker3D` Socket Vocabulary

Every modular chunk `.tscn` declares its gameplay attachment points as `Marker3D` children carrying both `metadata/socket_kind` and a matching Godot group (`socket_*` + `arena_socket`). This keeps authoring editor-friendly while letting runtime controllers bind setpieces and verify spatial contracts deterministically with zero hardcoded coordinates.

| Socket Kind | Group | Required Metadata | Role |
| --- | --- | --- | --- |
| `TRAVERSAL_RAIL` | `socket_traversal_rail` | `socket_id`, `tier`, `clearance_m`, `route_links` | High-speed floor loops, elevated catwalk grind lanes, upper gantry bridges, and chunk-to-chunk mating faces. |
| `JUMP_PAD` | `socket_jump_pad` | `socket_id`, `tier`, `clearance_m`, `route_links` | Pneumatic / steam vertical translators launching the ball from Tier 0 -> Tier 1 or Tier 1 -> Tier 2. |
| `HARPOON_ANCHOR` | `socket_harpoon_anchor` | `socket_id`, `tier`, `clearance_m`, `route_links` | High grapple footings (`>= 12 m`) for swinging over active basin hazards or vaulting onto upper gantries. |
| `SETPIECE_TRIGGER` | `socket_setpiece_trigger` | `socket_id`, `setpiece_kind`, `tier` | Binding origin for dynamic setpieces (`em_crane`, `slag_furnace`, `compactor_vent`); also player ram/slam trigger point. |
| `COVER_SLOT` | `socket_cover_slot` | `socket_id`, `cover_slot_index`, `tier` | Validated hard-cover drop pads (`>= 4.5 m` apart) where cranes or orbital drop-pods seat relocatable hulls. |
| `SIGHTLINE_LANDMARK` | `socket_sightline_landmark` | `socket_id`, `landmark_height_m`, `tier` | Hero silhouette anchor tested for prominence (`>= 26 m` apex, `>= 10 m` over top tier) and `>= 85%` LOS visibility. |

### 3.2 Physical Clearance & Map-Standard Validator Rules

`ArenaChunkSocket.validate_chunk(chunk_root)` enforces five hard invariants automatically in headless Godot:

1. **Gyrosphere + Heft Class V Envelope:** Scrapkeep's collision sphere stays fixed at `1.0 m` radius (`2.0 m` diameter), while Heft Class V accretion extends up to `~1.1 m` off the shell (`accretion.gd`), yielding a `2.1 m` visual envelope (`4.2 m` diameter). Every `TRAVERSAL_RAIL` and `JUMP_PAD` socket must declare `clearance_m >= 4.2 m` and pass an actual 3D AABB volume probe against chunk `StaticBody3D` colliders. Pairwise `COVER_SLOT` spacing must stay `>= 4.5 m` so dropped hulls can never pinch a lane shut.
2. **3-Tier Verticality:** Every chunk populates all three elevation tiers—**Tier 0 Floor Basin (`y < 4.5 m`)**, **Tier 1 Mid Catwalk/Rail (`4.5 m <= y < 12.0 m`)**, and **Tier 2 Upper Gantry/Crane (`y >= 12.0 m`)**—with total playable vertical span `>= 12.0 m`.
3. **Hard Cover Honesty (Map Standard Point 5) & Clean Collision Layers:** Every static environment `StaticBody3D` sits on documented `WORLD_LAYER = 1` with `collision_mask = 0` (zero wasted static broadphase queries). Every static `hard` cover body must be `>= 2.0 m` tall so lobber shell raycasts (`Projectile.COVER_MASK`) and harpoon rays read identical geometry. Shattered/retracted pieces drop cleanly to `collision_layer = 0` + disabled shape.
4. **Navigation Mesh Readiness (`NavigationRegion3D` + `NavigationMesh` + `NavigationLink3D`):** Every modular `.tscn` chunk ships a validated `NavigationRegion3D` carrying a multi-tier, non-floating `NavigationMesh` (every elevated polygon sits directly on a solid `deck` collider—zero quads floating over hollow pits!) configured to Scrapkeep's `agent_radius >= 1.0 m`, `agent_height = 2.0 m`, `agent_max_slope = 45°`, joined across Tiers 0 -> 1 -> 2 by `NavigationLink3D` nodes.
5. **Risk-of-Rain Open Verticality, High-Ground Vantages & 85% Sightlines (Map Standard Point 1):** Tier 1 and Tier 2 carry explicit `vantage_point` overlook sockets providing rapid dash/grapple escape loops and clear sightlines to both the central combat basin and the `SIGHTLINE_LANDMARK` apex (`>= 26.0 m` world height, `>= 10.0 m` above Tier 2, `>= 85%` unobstructed segment-vs-AABB sight share).
6. **Continuous Loop & Zero Dead-End Pits (Map Standard Point 7 & Ruling `cv`):** Directed graph validation over `route_links` confirms zero zero-out-degree sockets, proves every Tier 0 basin socket escapes upward to Tier 1+, and verifies at least one closed cycle visiting Tiers 0 -> 1 -> 2 -> 0 without stopping.

---

## 4. Cover-Reshaping Dynamic Setpieces & Interactive Prop Pairings (`dynamic_setpieces.gd`)

All visual telegraphs obey [VISUAL-LANGUAGE.md](../../VISUAL-LANGUAGE.md): hostile danger footprints use `Palette.hazard_stripe()` (45° `#ff5a3c` HAZARD + `#242a28` charcoal stripes) with `>= 0.6 s` fairness lead time (`1.2 s`–`1.6 s` standard), zero runtime `Light3D` instantiation (L6 compliant—emissive materials only), and clean node teardown.

### 4.0 Interactive Prop-System Pairings (Player-Driven Arena Manipulation)

Beyond periodic cycles, every arena pairs shootable/rammable industrial props with live setpieces so observant players turn the environment into a weapon and cover generator:

| Prop Pairing | Trigger Verb | Physical & Elemental Outcome | Bounded Safety Rule |
| --- | --- | --- | --- |
| **EM Crane Magnet Cut (`strike_crane_magnet`)** | Shoot or harpoon-strike the overhead electromagnet during `sweep_active` | Cuts magnet power immediately, slamming the suspended `5.0 x 3.2 x 3.4 m` Salvage Cargo Hull straight onto enemies underneath (`65 HP` crush in `5.5 m` radius), emitting a burst `&"electrified"` discharge (`ttl 0.6 s`), and seating fresh layer-1 hard cover where it lands. | Safe-deflection offset (`4.6 m`, exceeding hull corner half-extent `3.02 m` + ball radius `1.0 m`) guarantees the falling hull never lands on top of the player ball. |
| **Cryo-Pipe Rupture (`rupture_cryo_pipe`)** | Shoot, ram, or slam the rim-mounted `CryoPipeAssembly` overlooking the crucible | Emits `&"coolant_brittle"` (`radius 14.0 m`, `ttl 3.0 s`) onto the shared tag bus; if `SlagPourFurnace` is in `molten_pour`, **flash-freezes the molten pool** immediately into walkable & shatterable **Tier-1 Brittle Slag Cover Berms** that even a Class I ball can shatter for scrap! | `12.0 s` pipe cooldown + per-cycle quench flag guarantees zero infinite cascade or spam loops. |
| **Compactor Bait & Eject** | Lure Fleet packs into open press throat, then trigger or time the `1.2 s` close | Snaps shut for `45 HP` crush on stalled enemies (`speed < 4.0 m/s`), while a ball rolling through at `>= cruise` receives a pneumatic eject impulse instead of a dead stop. | Minimum `1.2 s` HAZARD floor warning before every snap. |

### 4.1 Suspended Electromagnetic Crane
- **Maker:** Old Works bridge rail requisitioned by the Furnace Fleet (oxide-red hull, mast-steel truss, copper rail).
- **Cadence:** `5.0 s` idle (or early player ram/slam on `setpiece_em_crane`) -> `1.2 s` HAZARD ground corridor telegraph -> `2.6 s` active sweep -> `0.8 s` safe-checked drop -> cycle to next `COVER_SLOT`.
- **Live Arena Reshaping:**
  1. Emits `&"magnetic"` (`radius 11.0 m`) along the sweeping trolley, pulling loose scrap chunks and barrels into a high-value ribbon along the crane path.
  2. Opens a **temporary airborne Harpoon Swing Bridge** (`y = 14.0 m`, `Palette.ARC` mint live cue) tracking the boom across the pit—giving skilled players a direct aerial vault over molten slag!
  3. Physically relocates a **`5.0 x 3.2 x 3.4 m` Salvage Cargo Hull** (layer-1 hard cover blocking lobber shells) between `COVER_SLOT` sockets. If the ball is parked inside the destination pad (`< 4.6 m`), the drop holds until the ball clears so geometry never traps the player.

### 4.2 Periodic Slag-Pour Furnace
- **Maker:** Furnace Fleet crucible mounted over an Old Works spillway basin (directly extending the Slag Bowl's heritage).
- **Cadence:** `4.5 s` dormant -> `1.6 s` HAZARD crucible ring telegraph -> `4.0 s` molten pour -> `8.5 s` cooled cover berms -> clean crumble & reset.
- **Live Arena Reshaping:**
  1. During `molten_pour`, floods only the inner `11.0 m` basin radius with `&"slag_coated"` + `&"burning"`, leaving the outer banked ring and `JUMP_PAD` translators open. Stalled balls on the basin floor take heat pressure, driving combat vertically onto Tier 1 catwalks and Tier 2 harpoon arcs.
  2. On cooling, forms **3 Hardened Slag Cover Berms** (`4.2 x 2.4 x 1.8 m`, layer-1 hard cover arranged on a `7.0 m` crescent with `> 5.0 m` gaps). Berms inherit **Heft Destructible tiers** (Tier 2/3 normally, or **Tier 1** if flash-quenched by `&"coolant_brittle"` / `&"soaked_conductive"`).
  3. Players can use cooled berms as real lobber cover, then ram through them at speed (or blast them with `+1` tier bonus) for scrap and shrapnel. Any unshattered berms crumble automatically before the next pour—guaranteeing the floor **never clogs permanently**.

### 4.3 Compactor Canyon Crusher Vents
- **Maker:** Old Works hydraulic sluice press looping on its abandoned maintenance schedule.
- **Cadence:** `3.0 s` sealed -> `0.8 s` open telegraph -> `3.5 s` high-speed open corridor -> `1.2 s` HAZARD close telegraph -> `0.6 s` crush snap.
- **Live Arena Reshaping:**
  1. When open, retracts its `6.4 m`-wide press ram (`collision_layer = 0`), exposing a high-speed shortcut that awards a forward momentum carry (`+10.0 m/s²`) to balls rolling at `>= cruise * 0.55`.
  2. When snapping shut, inflicts heavy crush damage (`45 HP`) on stalled enemies (`speed < 4.0 m/s`) baited into the throat and punishes a stopped ball, while a fast ball (`>= cruise`) triggers an emergency pneumatic eject boost instead of a dead stop.

---

## 5. Three Vertical Biome Architecture Blueprints

### Biome 1: The Smelter Pit (Spillway / Slag Bowl Heritage)

**Implemented prototype:** [`smelter_crane_chunk.tscn`](../../src/experimental/smelter_crane_chunk.tscn) (`80 m x 80 m` core combat bowl).
**Makers & Tone:** Cast Old-Works crucible foundation bolted over with Admiral Brindle's iron-oxide catwalks and brass-tagged crane tracks. *Foreman memo:* `"Thermal throughput is up 14%. Floor occupancy is now discouraged."` *Crew chalk:* `"Ride the crane, skip the soup."`

#### Vertical Cross-Section (Elevation in Metres)
```text
y = 46.0 m   [ === ANCIENT BEACON COLLAR (#9dff3c) === ]  <-- Sightline Landmark (>= 90% LOS)
             |    Old-Works Crucible Smokestack       |
y = 20.0 m   |  =========== EM CRANE RAIL =========== |  <-- Tier 2: EM Crane & Moving Harpoon Bridge (y=14m)
y = 16.0 m   |  [Harpoon W] === UPPER GANTRY === [Harpoon E]
             |        \                          /
y =  7.5 m   |  [Mid Catwalk W + Hard Bulkhead]  [Mid Catwalk E + Hard Bulkhead]  <-- Tier 1: Grind & Flank Ring
             |     ^                                      ^
y =  3.6 m   | [Rim Bank]                          [Rim Bank]   <-- Concave Bowl Rim (depth = 3.6 m >= 2.0 m)
y =  0.0 m   +---[JumpPad SW]--[CoverSlot W]--(SLAG BASIN r=11m)--[CoverSlot E]--[JumpPad NE]---+ Tier 0 Floor
                                                   |
                                           [Compactor Vent S]
```

#### Gameplay Loop & Setpiece Cadence
- **Sightline Landmark:** `CrucibleSpire` (`46.0 m` apex, `29.5 m` prominence above Tier 2 gantry) silhouetted against clean dawn/morning sky with uranium-green collar visible from `>= 90%` of sockets (exceeding the `85%` map standard).
- **Traversal Loop:** Floor south entry (`floor_loop_south`) -> banked rim or SW/NE Jump Pads (`y = 0.5 m -> 7.6 m`) -> 4-sided Tier 1 Catwalk grind ring (`6.5 m` wide decks) -> NW/SE Harpoon Anchors (`y = 16.5 m`) -> Upper Gantry & live EM Crane Harpoon Swing Bridge -> drop slam back into newly cooled Slag Cover Berms.
- **Setpiece Rhythm:** EM Crane (`~9.6 s` cycle) and Slag-Pour Furnace (`~18.6 s` cycle) run offset so every ~10 seconds either hard cover relocates between West/East/NW pads OR the lower basin shifts from molten vertical-push to destructible cover berms.

---

### Biome 2: Compactor Canyon (Sluice Walls & Pneumatic Press Works)

**Heritage:** World 1 Flume-to-Dig transition—deep sandstone slot canyon lined with Old Works hydraulic press walls and Fleet salvage chutes.
**Makers & Tone:** Monumental seamless petrol-enamel press pistons recessed into weathered sandstone cliffs; Keeper timber kickers bolted onto drainage shelves. *Foreman memo:* `"Scheduled compression maintains optimal corridor geometry."` *Crew chalk:* `"Don't park between the teeth."`

#### Vertical Cross-Section (Elevation in Metres)
```text
y = 42.0 m         [ === HYDRAULIC HEAD-PRESS TOWER (#9dff3c beacon) === ]  <-- Sightline Landmark
y = 21.0 m   [Canyon Rim Cableway] ============== HARPOON ZIP LINE ============== [Canyon Rim Cableway]  Tier 2
                   |                                                                     |
y = 11.0 m   [West Sluice Shelf + Glazed Wall]    (Open Canyon Drop)    [East Sluice Shelf + Glazed Wall] Tier 1
                   |   <== Pneumatic Press Ram ==>      <== Ram ==>                      |
y =  3.2 m   [Banked Ambush Berm]                                           [Banked Ambush Berm]
y =  0.0 m   +=====[Drop-Chute Ambush Basin]=====[Compactor Vent Throat]=====[Updraft Steam Lift]=====+  Tier 0
```

#### Architecture, Landmarks & Setpieces
- **3-Tier Layout (`120 m x 64 m` linear-loop canyon chunk):**
  - **Tier 0 (`y = 0.0 m`):** Sunken **Drop-Chute Ambush Basin** flanked by `3.2 m` concave canyon berms (`bowl depth = 3.2 m`). Two mandatory wide steam-lift jump pads (`6.0 m` wide) and a central **Compactor Vent Throat** guarantee rapid exits.
  - **Tier 1 (`y = 10.5 m`):** Opposite **Sluice Wall Shelves** lined with glazed wall-carve strips (`contraptions.gd` glaze push) so players wall-ride past enemy firing lines.
  - **Tier 2 (`y = 21.0 m`):** Suspended **Canyon Rim Cableway & Harpoon Zip Anchors** crossing above the press throats—letting players bait Fleet packs below, then slam the `SETPIECE_TRIGGER` valve to close the rams on stalled enemies.
- **Sightline Landmark:** `HydraulicHeadPressTower` (`42.0 m` tall counterweight frame straddling the exit arch, `21.0 m` prominence above Tier 2).
- **Dynamic Setpieces:**
  - **Synchronized Twin Compactor Vents:** Alternate left/right press gates every `9.1 s`, opening high-speed glazed shortcuts (`+10 m/s²` carry) on one side while snapping shut on the other (`45 HP` crush to stalled enemies).
  - **Drop-Chute Scrap Dump (`COVER_SLOT` shifter):** Periodic chute release drops a Tier-2 destructible crate wall onto the basin floor (`&"magnetic"` pullable debris), temporarily breaking lobber sightlines until shattered.
- **Breathing & Rhythm:** Every canyon chunk pairs one high-pressure press throat (`<= 28 s` combat stretch) with a `> 60 m` glazed wall-carve breather bend free of spawns.

---

### Biome 3: Orbital Graveyard (Highdraft Launch-Rail Gantries)

**Heritage:** Highdraft old-works launch rails & derelict cargo bays suspended above canyon catch-nets (`STORY-MAP.md`: *"Every bearing ends at the Crown. Ring-outs, nets under every gap"*).
**Makers & Tone:** Seamless cast launch-rail trusses tilted skyward, weathered iron-oxide orbital cargo pods split open by Keepers into ramps, and humming ANCIENT rail beacons. *Foreman memo:* `"Orbital freight schedule suspended pending crew re-alignment."` *Crew chalk:* `"Mind the falling crates—they make good walls."`

#### Vertical Cross-Section (Elevation in Metres)
```text
y = 48.0 m                  [ === CANTED LAUNCH-RAIL PYLON (#9dff3c) === ]   <-- Sightline Landmark (48 m apex)
                                        /
y = 24.0 m   [Upper Launch Gantry] ---/--- [Harpoon Zip-Arc] --- [Suspended Cargo Deck]   Tier 2
                  |                                                      |
y = 12.0 m   [Mid Hull Catwalk] <======== EM Recovery Crane ========> [Mid Hull Catwalk]  Tier 1
                  |                           (Air-Drop Pod)             |
y =  2.8 m   [Padded Net Nosing (Amber/Charcoal)]           [Padded Net Nosing]           Bowl Rim
y =  0.0 m   +=========[Catch-Net Recovery Deck + Updraft Thermals + Cover Slots]=======+ Tier 0 (No fatal pit)
```

#### Architecture, Landmarks & Setpieces
- **3-Tier Layout (`96 m x 96 m` open-sky vertical hub):**
  - **Tier 0 (`y = 0.0 m`):** Resilient **Catch-Net Recovery Deck** (amber/charcoal `nosing` rim `2.8 m` high, zero bottomless instant-death pits) studded with 4 high-lift updraft thermals (`JUMP_PAD` equivalents) and 4 `COVER_SLOT` drop rings.
  - **Tier 1 (`y = 12.0 m`):** Cantilevered **Salvaged Hull Catwalks** (`6.5 m` deck width) connected by banked launch kickers and long open sightlines for aerial shots.
  - **Tier 2 (`y = 24.0 m`):** **Suspended Launch-Rail Gantries** linked by `22 m` **Harpoon Zip-Arcs**—high-risk/high-reward aerial speed lanes carrying scrap ribbons and overhead dunk angles onto Wardens and packs below.
- **Sightline Landmark:** `CantedLaunchPylon` (`48.0 m` tilted Old-Works orbital rail mast with uranium-green seam strips and beacon tip, `24.0 m` above Tier 2).
- **Dynamic Setpieces:**
  - **Air-Drop Salvage Cover Pods:** Telegraphed `1.6 s` `thr_projectile` closing-bracket HAZARD reticle onto a `COVER_SLOT` -> orbital hull pod slams down (punishing stalled enemies underneath with shockwave + `&"magnetic"` scatter pulse) -> settles into a **`3.4 m` tall Tier-3/4 Heft Destructible Hard Cover bunker** until the next EM Recovery Crane lifts or recycles it!
  - **Launch-Rail Induction Surge:** Periodic `&"electrified"` pulse sweeps the Tier 2 gantry rail (`1.4 s` lane telegraph), converting stalled rail campers into arcs while supercharging fast balls (`>= cruise`) with a speed-tier launch impulse.

---

## 6. Ten-Point Map Standard Audit Matrix

Every biome is designed directly against the 10-point standard in [map-audit.md](../../../../project-guide/handoff/shared/world1/map-audit.md):

| Map Standard Point | Pass Line | The Smelter Pit | Compactor Canyon | Orbital Graveyard |
| --- | --- | --- | --- | --- |
| **1. Signposts & Sightline** | Hero landmark visible from `>= 85%` open cells/lines; reads as light up close | `CrucibleSpire` (`46 m`, `>= 90%` socket LOS verified in test) | `HydraulicHeadPressTower` (`42 m`, central canyon arch apex) | `CantedLaunchPylon` (`48 m`, canted rail silhouetted vs sky) |
| **2. Breathing** | `>= 25%` line nodes `> 60 m` from fight sites | Perimeter rim transfer ramps outside central crucible ring | Glazed wall-carve bends between press chambers | Outer catch-net launch curves & upper zip-arc exits |
| **3. Rhythm** | `>= 3` fight/quiet switches; longest heavy run `<= 45 s` | Offset Crane (`9.6 s`) & Furnace (`18.6 s`) windows create burst/breather beats | Alternating left/right press cycles cap heavy stretches at `<= 28 s` | Air-drop pod arrivals pace `20 s` skirmishes with aerial resets |
| **4. Hybrid Variety** | `>= 10` distinct seeded layouts/states per 50 seeds | Seeded initial cover-slot rotation + quench-variable berm tiers + chunk snapping | Seeded press phase offsets + alternate chute drop slots | Seeded pod drop sequence + rail surge polarity |
| **5. Cover & Reading** | Hard cover `>= 2.0 m` on layer 1; HAZARD stripes never on walls/friendly | `BulkheadMid*` (`2.6 m`), `SalvageCargoHull` (`3.2 m`), `SlagBerm` (`2.4 m`) on layer 1 | Press rams (`4.0 m`) & crate walls (`2.4 m`) on layer 1; striped crush zone only | Air-drop pods (`3.4 m`) on layer 1; amber/charcoal net nosing never striped red |
| **6. Interactive** | `>= 2` player-caused route changes per stage | Player triggers EM Crane (opens Harpoon Bridge + moves cover) & Compactor Vent; shatters Slag Berms | Player slams press valves & shatters chute barricades | Player triggers rail surge boost & shatters drop-pod bunkers |
| **7. Verticality** | `>= 3` height bands; `>= 4` rides climbing `>= 10 m`; all bands reachable | Tiers `0 / 7.6 / 16.5 m` (`16.5 m` span); 2 jump pads + 2 harpoon anchors + crane bridge | Tiers `0 / 10.5 / 21.0 m` (`21.0 m` span); steam lifts + wall-carve ramps + rim zips | Tiers `0 / 12.0 / 24.0 m` (`24.0 m` span); 4 updraft thermals + rail kickers + zip-arcs |
| **8. Bowls, Silhouettes & Snags** | Rim minus centre `>= 2.0 m`; clean silhouettes; `0` ride snags | Rim `3.6 m` over basin (`>= 2.0 m`); `>= 5.5 m` catwalk decks (`> 4.2 m` Heft V) | Berm `3.2 m` over chute basin; flush ram floor rails | Net nosing `2.8 m` over catch deck; bevelled gantry lips |
| **9. Tier & Spoke** | Hub reaching `>= 3` bands; `>= 50%` pay in top two bands | Central crucible hub radiates to all 3 tiers; magnetic scrap ribbons & upper gantry caches | Canyon junction hub links floor press, mid sluices, rim cableway | Central pylon hub radiates spokes across all 3 decks |
| **10. Markers & Line Rewards** | Sight share per marker; `>= 30%` scrap on skill lines | Magnetic crane pulls scrap along sweep path; bonus scrap on upper gantry & berm breaks | Glazed bonus line through open compactor carries scrap ribbon | Scrap lines along Tier 2 harpoon zip-arcs & pod shatters |

---

## 7. Integration & Promotion Path (Non-Breaking)

These prototypes live cleanly under `src/experimental/` and `design-v3/experimental/` with zero edits to shipped World 1–3 code:
1. **Stage Graph & Park Recipes:** Future promotion maps `Marker3D` sockets directly onto `park_<map>.json` (`park_rows`, `contraption_rows`, `landmark`) while running `ArenaChunkSocket.validate_chunk()` as a build-time preflight alongside `park_schema_test.gd` and `park_cover_tags_test.gd`.
2. **Cross-Pillar Composition & Opt-In `LiveRunBridge`:** `DynamicSetpieces.env_tag_emitted` and `apply_external_tag()` connect straight into Pillar 1's elemental reaction bus and Pillar 3's director event dispatcher using the identical 6-tag schema. `src/experimental/live_run_bridge.gd` composes all five experimental subsystems (`JuryRigSynergies`, `EcologyActors`, `AdversityDirector`, `EncounterEngine`, `DynamicSetpieces`) alongside `ExperimentalAudioBank` behind an explicit opt-in gate (`--experimental-depth=on` or `SCRAPKEEP_EXPERIMENTAL=1`), auto-selecting Spillway (stages 1–2), Dig (stages 3–4), and Highdraft (stages 5–6) `.tres` configs with zero World 1 baseline drift when disabled.
3. **Destructibles Bridge:** Cooled Slag Cover Berms already match `Destructibles.WALL_SPEED`, `RAM_MIN_PER_CRUISE`, `LOOT`, and `+1` blast tier rules—allowing seamless hand-off to `src/world/destructibles.gd` when admitted to a wave.
