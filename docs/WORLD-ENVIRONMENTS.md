# World and environment kits

Updated 5 September 2026 after the notebook interview. These are candidate environment kits for the world catalogue. [Discovery](DISCOVERY.md#accepted-notebook-interview) owns the accepted four-world, 60–75 minute run with compact procedural encounter levels and world bosses. At transitions to another world the player picks one of two randomly selected destinations.

The seven kits below are a creative library, not a fixed campaign order, a launch commitment or the number of worlds visited in a run. Catalogue size, repeat rules, starting world and final-boss placement remain open. Requisition fiction, biome-specific mechanics, lighting and exact dimensions remain proposals. The old mass-as-currency model was not adopted.

## World content and rewards

A selected world supplies its encounter palette, terrain vocabulary, themed enemies, event/secret-room opportunities and item pool. Rare enemies, events, secrets and bosses should award items whose appearance and effects belong to that area and universe. Attunement can connect those items to specific characters or other items; fixed endpoint-combination bonuses belong to the build system rather than the world's random loot roll.

A world definition must work at its selected position in a generated route. Do not assume the player previously visited another named biome to learn a necessary counter or traversal mechanic. Level milestones contribute to all four trees, including opening-world slot unlocks; exact encounter counts and costs remain design work. See [level design](LEVEL-DESIGN.md) and the [runtime blueprint](RUNTIME-BLUEPRINT.md) for those boundaries.

## Historical orchard technology snapshot

These observations were recorded against the first proof. Numerical constants and source-line locations are historical; the current caster has jumping, rebounds and denser waves. Recheck against the [lightning contract](project/INCREMENT-01-lightning-playtest.md) before using a kit's cost estimate.

- One scalar heightfield drives everything. `groundHeight(x, z)` is a single exported function (src/orchard/simulation.js:57-59, a 2.5 unit ramp between z equals -14 and -23). The scene samples it for the ground mesh, fences, signs, worn tracks, telegraph decals, and the camera floor (src/orchard/scene.js:166, 195, 292, 348, 511, 397). Any biome whose terrain reads as a heightfield inherits all of this for the cost of one function.
- Attack telegraphs are world-space capsules the renderer draws exactly as the simulation collides them (src/orchard/simulation.js:72-76, src/orchard/scene.js:508-558). Any biome hazard expressed as capsules gets preview, active stroke, and fairness for free.
- Handling is a velocity servo with four visible knobs: speed target 7.4 (brake 2.2) at src/orchard/simulation.js:323, acceleration 25 (brake 48, brace adds 4) at src/orchard/simulation.js:329, a burst dash gated by `p.dashTime` (src/orchard/simulation.js:322, 608), and collision radius, which today only grows the hitbox and eases ram counters (src/orchard/simulation.js:606-611, docs/DESIGN-AUDIT.md:26). Every traversal twist below is written against exactly these four parameters.
- Dressing is cheap when instanced or batched: 3 tree rows per side, 900 grass cones, one merged deco pass (src/orchard/scene.js:222-273, 38-59). Large structures use an invisible camera-blocker proxy (src/orchard/scene.js:282-288).
- The sign system is a canvas texture on a cream board: 1024x128, cream #e8ddb5, sage border #667252, dark green text #344c3c, posts, placed as "THE IRON ORCHARD", "CUTTINGS / 01", "SUPPORT ROW / 02", "SEEDHOUSE / 03" (src/orchard/scene.js:289-330).
- Audio is synthesized at runtime with WebAudio oscillators (src/orchard/main.js:99, 113; R14 at docs/project/REQUIREMENTS.md:20). No sample libraries are assumed anywhere below.

## Shared world systems

### Route clearance contract (proposal, restating docs/ORCHARD-ENCOUNTER-STUDY.md:47-56 as rules)

Let D be the diameter of the largest ordinary-growth collision envelope, not decorative wobble. Every biome route must pass:

1. Every mandatory route keeps at least 2D clear width outside the union of active enemy tool footprints, checked at maximum ordinary growth and expected entry speed.
2. No mandatory passage under or through an enemy. The outer ground route is always the dependable alternative.
3. Windup durations give the player a reachable exit from intended approach positions. Width never substitutes for a reachable exit.
4. Deployed devices, loose dressing, and consequence-beat wreckage must not silently close rule 1 or rule 2 routes. Wreckage that changes traversal gets a visible support and a usable landing (docs/ORCHARD-ENCOUNTER-STUDY.md:78).
5. The chase camera must show the committed tool and one achievable exit; the camera looks 6.2 units ahead of the ball (src/orchard/scene.js:399) and backs off with growth (distance 7.2 plus radius times 1.8, src/orchard/scene.js:382). Overhangs and tunnels must clear that orbit or register camera blockers.
6. Broken structures remain broken for the rest of the stage (docs/ORCHARD-ENCOUNTER-STUDY.md:37).

### Wayfinding and zone signs (proposal, extending the orchard sign system)

- Civic signs keep the orchard layout everywhere: cream board, biome-colored border, dark text, "AREA NAME / NN" (src/orchard/scene.js:290-292). NN ascends along the route spine, so the number doubles as a progress bar. Boss aprons get a double-post wide board.
- A second sign class tells the Requisition story: the Fleet notice. Same board tech, rust border, gear-tooth corner stamps, always bolted slightly crooked over or beside a civic sign. Crooked-over-straight is the one-glance grammar for "this place is conscripted, not abandoned."
- Every conscripted machine keeps its civic service plate (the ORCH-7 salvage plate precedent, docs/audit-2026-09-05/worker-4-universe.md:78) plus a stenciled Fleet requisition number. Popping the bolt visually voids the stencil.
- The orchard's faint worn track rings (src/orchard/scene.js:331-358) generalize: track rings mark machine patrol loops and defense arenas in every biome, in each biome's ground accent. Players learn that a ring means a working machine cycles here.

### Weather and time (contested, one recommendation)

Options considered: dynamic weather, day-night cycles, or fixed lighting keyframes. The orchard's lighting is static and tuned (hemisphere, sun, rim, fixed fog at src/orchard/scene.js:85-116), and the telegraph decals live at low opacity (src/orchard/scene.js:496-506) where weather noise would tax readability. Palette is also the biome identity carrier. **Recommendation:** one fixed time-of-day lighting keyframe per biome, no dynamic weather in the first campaign. Weather appears only as consequence-beat punctuation, local and authored: the drained basin's mist, the jammed fan's dust, the hammer's ember rain. This keeps every stroke readable and makes each rung's postcard stable for art and marketing.

### Figurine base chips (proposal, per docs/audit-2026-09-05/worker-4-universe.md:127 rule 2)

One 40 to 60 mm terrain module per biome doubles as the figurine base: Yard curb corner, Spillway sluice-gate lip, Orchard apron with nursery tray, Foundry rail-siding curve, Windworks louver ring, Harvest Roads flatbed deck edge, Furnace City conveyor street plate. Each is named in its biome's module table below so the game kit and the product share one Blender source.

## Candidate biome kits

Each kit below is a proposal. References to rungs in the retained fiction and tuning prose describe the old library progression, not mandatory run order. Module sizes are stated in D (route clearance unit) and simulation units where the orchard gives a reference: the orchard's central path band is 14 units wide with soil shoulders to x equals 18.9 and fences at 20 (src/orchard/scene.js:168-171, 192-199).

### 1. Yard Commons (candidate home world)

**Terrain modules.** Curb straight (4 units, matches the orchard fence bay rhythm at src/orchard/scene.js:193), curb corner 90 (4x4, the figurine chip), retaining wall low (1.5 high, bankable), maze tee, service ramp, allotment plot (6x4), gantry footing (3x3, tippable), depot facade (camera blocker). Eight modules; everything is orthogonal and curb-joined, per the concept's zigzag maze language (docs/ART-DIRECTION.md:13 prompt).
**Traversal twist.** Curb banking. Curb contact converts lateral velocity instead of zeroing it, unlike the arena clamp that kills velocity on the axis it stops (src/orchard/simulation.js:346-355). Touches acceleration only: a curb is a free steering assist worth roughly the 25 accel budget for one bounce. Speed target, burst, and radius stay at reference values. The yard is the calibration rig where the player learns the servo before any biome bends it.
**Interactive and destructible set.** Cones and crates (collectible mass), stacked pallet walls (ram-through), one loaded gantry per court. Consequence beat: tip the gantry into a wall, the first "I did that" (docs/audit-2026-09-05/worker-4-universe.md:60). Mechanic: the gantry has one bolted foot as a weak point; a burst-speed ram pops it and the fall is telegraphed with the standard capsule preview.
**Requisition set dressing.** The first crooked Fleet notice over the commons board. One requisitioned yard collector parked with its bolt highlighted, before any fight, so the player reads the grammar in safety. Chalk service marks by keepers on every un-conscripted machine.
**Palette keyframe.** The canon itself: warm ivory #d4d3bf, petrol #183b3e, deep navy #0c1e23, amber-orange #ff9c52, mint #a6f4d6 (docs/ART-DIRECTION.md:13). Accent: safety orange edges. The yard is the reference key every other rung shifts from.
**Light and atmosphere.** Late golden afternoon, long warm shadows, near-black petroleum sky with haze per the concept prompt (docs/ART-DIRECTION.md:13). Highest value contrast of any rung; nothing competes with the tutorial reads.
**Audio identity.** Bright square-wave pickup chirps and a simple two-oscillator triad bed. Curb bounces get a short pitched click that rises with retained speed, teaching the banking reward by ear.
**Defense space.** Objective (the depot reactor) on a raised pad inside a 1.5D standoff keep-out: no deploys, no enemy path. The keep-out nests inside the levels lane's objective ring at radius 14 to 18 units (LEVEL-DESIGN.md:63-66). Devices anchor on that ring, one per class per lane, never in lanes (LEVEL-DESIGN.md:146-151). Two curb-fed approach lanes at 2D or wider feed the ring.
**What the player protects.** The commons itself: allotment plots, residents' stored belongings, the keepers' depot. Lived-in clutter that is never collectible, extending the never-absorbed rule (docs/audit-2026-09-05/worker-4-universe.md:86).

### 2. Spillway Works (candidate)

**Terrain modules.** Channel straight (3D wide floor, 1 unit walls), channel bend 45, bypass gutter (2D, the guaranteed dry route), settling basin (12x12, drainable), sluice gate (3 units wide, the figurine chip and the beat trigger), weir step (0.6 unit drop, one-way at reference accel), catwalk pier (camera blocker), pumphouse facade, reed-bed margin. Nine modules.
**Traversal twist.** Water as a current field, one signed scalar plus a flow vector per channel. Wet channels add the flow vector to the servo's target velocity (the speed target at src/orchard/simulation.js:323-325 gets a bias term): with the flow you effectively roll above 7.4, against it below. Submerged floors also cut acceleration from 25 toward roughly 15 (drag). Burst is deliberately unaffected, so a burst across a wet channel is the skill answer. Radius untouched. Draining a basin removes both modifiers at once, which is the point of the beat.
**Interactive and destructible set.** Trash-rack grilles (ram-through, drop scrap), stacked silt bags (bankable, erode when wet), pump valves (spin on contact to reroute one gutter), the sluice gate. Consequence beat: burst a sluice gate mid-fight and drain the whole basin over about four seconds, rerouting every current, grounding float-type enemies, and exposing sunken scrap (docs/audit-2026-09-05/worker-4-universe.md:61). Mechanic: the gate's requisition bolt is the weak point; it only pops to a burst-speed ram, and the drain is previewed with capsule decals along the new waterline.
**Requisition set dressing.** Screen rakes and presses wear municipal water-board livery under fresh Fleet stencils. Fleet notices posted at every gate ladder read as tonnage quotas. Chalk tide marks by keepers show where the water should sit, so a wrong water level is itself set dressing for the conscription.
**Palette keyframe (hex values are proposals).** Patched pale concrete #c8c6b2, wet petrol water #14343f, galvanized zinc #9fada8, sediment ochre #b19a6c, safety-orange gate hardware #ff9c52. Accent: galvanized zinc over petrol water. Mint stays reserved for gauges and pickups so it keeps its energy meaning from the canon.
**Light and atmosphere.** Cool overcast noon bounced off wet concrete, tight fog range pulled in from the orchard's 48 to 110 (src/orchard/scene.js:86) to sell the low channel air. Specular water is the only gloss in the game so far; everything else stays matte.
**Audio identity.** Filtered white noise as the water bed, lowpass cutoff mapped to local water level so the drain beat is audible as a falling sweep. Drips as sparse sine pings. Rake strokes get a dragged ratchet from a pulsed square, honoring the mechanical-cadence rule (docs/ORCHARD-ENCOUNTER-STUDY.md:39).
**Defense space.** Defend the pumphouse intake: the objective sits at basin edge, approach lanes are one wet channel (fast for enemies too) and one dry gutter, both 2D. The drain beat legitimately reshapes the defense mid-encounter, which is the biome's tactical thesis.
**What the player protects.** The town's water: the pumphouse that keeps homes dry and the reed-bed margins with herons and frogs. Wildlife and the working pump are never collectible.

### 3. The Iron Orchard (bounded encounter implemented)

**Terrain modules (naming what exists, then extending).** Terrace ramp (the 2.5 unit groundHeight rise, src/orchard/simulation.js:57-59), turning apron (the encounter clearing, worn track rings at src/orchard/scene.js:338-342), tree row (instanced trunk, leaf, apple set at src/orchard/scene.js:222-266), fence bay (4 unit rhythm), nursery table, irrigation stand, seedhouse facade, greenhouse (camera-blocked large structure, src/orchard/scene.js:275-288), apron with nursery tray (the figurine chip). The extension work is packaging these as reusable placements rather than the current single hand-laid arena.
**Traversal twist.** Grip bands. Soft cultivated soil multiplies acceleration by about 0.8; swept aprons are reference; terrace lips demand either the ramp route or a burst to climb. Touches acceleration and burst, never speed target, so the top-speed feel stays constant and the choice is where you can reach it. The current build already renders the three ground bands (path, soil, sage at src/orchard/scene.js:168-173) that this twist would activate.
**Interactive and destructible set.** Prop stacks, twig piles (mass), irrigation stands (knock to spray, brief grip change), Pruner arms. Consequence beat: fold a damaged house-sized pruning arm into a bank or ramp with visible support and usable landing (docs/ORCHARD-ENCOUNTER-STUDY.md:78, docs/audit-2026-09-05/worker-4-universe.md:62).
**Requisition set dressing.** Already the canon source: bolted control overrides on maintenance machines, a cared-for cultivated place worth saving (docs/ORCHARD-ENCOUNTER-STUDY.md:13). Add Fleet quota notices nailed to fence posts and one civic sign per zone already implemented (src/orchard/scene.js:289-292).
**Palette keyframe (implemented, cite not propose).** Sage #718a61, cream #eee2bb, soil #bbae7e, leaf #4b7445, orange #f28c42 (src/orchard/scene.js:14-24). Accent: sage enamel with apple decals.
**Light and atmosphere.** Implemented: soft blue-green sky #b4cbd0, warm hemisphere and amber sun, cool rim light (src/orchard/scene.js:85-116). The morning-in-a-workplace key. Keep as the reference implementation other biomes vary from.
**Audio identity.** The existing synthesized set (src/orchard/main.js:99-113) is the baseline. Shear snips as paired detuned squares, one per blade plane.
**Defense space.** The seedhouse terrace: a 1.5D standoff keep-out around the seedhouse door, no deploys and no enemy path inside it, nested inside the objective ring at radius 14 to 18 units (LEVEL-DESIGN.md:63-66). Anchors sit on that ring, one per class per lane, never in lanes (LEVEL-DESIGN.md:146-151). The terrace ramp and the outer service route are the two 2D lanes, per the existing bypass contract (docs/ORCHARD-ENCOUNTER-STUDY.md:49-51).
**What the player protects.** Healthy trees, protected contact surfaces, repaired equipment (docs/ORCHARD-ENCOUNTER-STUDY.md:13). The generalization rule for all biomes: every rung names its cultivated thing, and that thing is never collectible.

### 4. Foundry Crown (candidate)

**Terrain modules.** Rail siding straight (groove 1D wide), rail siding curve (the figurine chip), switch point, slag drum (rollable heavy prop), casting rack aisle (3D), crane aisle floor (open 6D arena), ladle gantry (overhead mover, camera blocker), quench pool (1x weir step reuse from Spillway), furnace hammer footing. Nine modules, two reused.
**Traversal twist.** Rails and overhead motion. Historical mass-gated rail proposal, not adopted: a grooved rail captures the ball above half mass: while riding, effective speed target rises from 7.4 toward 9, but lateral acceleration drops to zero until a switch point or a burst breaks the groove. That is a straight trade on the two servo knobs (src/orchard/simulation.js:323, 329) and it makes mass (radius) a route decision, which is the audit's keystone ask (docs/DESIGN-AUDIT.md:26, 42). Swinging ladle loads are moving hazard capsules on schedules; their shadows are the tell, per the family silhouette rule (docs/audit-2026-09-05/worker-4-universe.md:115).
**Interactive and destructible set.** Casting racks (topple into bank angles), slag drums (heavy deflectable projectiles when rammed), chain hoists (drop their load on a weak-point hit). Consequence beat: the furnace hammer craters the arena on a fixed telegraphed schedule; wrecked carriages become new bank angles (docs/audit-2026-09-05/worker-4-universe.md:63). The player learns to fight on the hammer's clock and then to bait enemies under it.
**Requisition set dressing.** Cranes and clampcarts keep foundry-guild livery and shift boards under Fleet stencils. The Fleet notice here is a production ledger, numbers climbing rung over rung. Keepers' lamp room glows warm behind glass as the untouched heart of the place.
**Palette keyframe (hex values are proposals).** Ash ivory #b8b2a4, fire-dark iron #241f1c, copper #b06a3f, ember glow #ffb066 (emissive), petrol gloom #183b3e. Accent: copper and ember glow in a dark aisle. This rung absorbs the Fleet sheet's weathering gap deliberately: dark is the place, not the machines' character (docs/audit-2026-09-05/worker-4-universe.md:18).
**Light and atmosphere.** The first interior-dark rung. Low hemisphere, no sun; ladles and the furnace mouth are the key lights, amber and local. Telegraph decals get a brightness pass here because the floor is dark; that is a named art-pipeline task, not a free assumption.
**Audio identity.** Sub-sine hammer thumps on the arena schedule, FM bell partials for struck castings, a slow detuned drone for the furnace. The hammer countdown is audible two beats early, honoring cadence-over-color.
**Defense space.** Defend the lamp room and pattern loft door: crane aisle as the 6D arena, two rail-fed lanes at 2D, hammer crater zone marked by a permanent track ring. Overhead movers must never violate contract rule 2.
**What the player protects.** The master patterns, generations of wooden casting patterns in the loft, and the swallows nesting in the crane aisle rafters.

### 5. The Windworks (candidate)

**Terrain modules.** Canvas duct run (3D bore), plenum chamber (8x8), louver ring (the figurine chip), intake cone, exhaust jet nozzle, streamer mast (current preview), gallery catwalk, great fan housing (camera blocker), canary gallery front. Nine modules.
**Traversal twist.** Air adds and steals momentum. Intake cones apply a directed acceleration term toward themselves; exhaust jets aligned with a burst extend its carry; headwinds cut the effective speed target from 7.4 toward 5.5. Touches acceleration, burst, and speed target, and every current is previewed by fabric streamers before the player commits, extending the preview grammar (docs/audit-2026-09-05/worker-4-universe.md:64).
**Interactive and destructible set.** Louver banks (spin to redirect a current), patch canvas (ram-through, current leaks out), counterweight dampers. Consequence beat: jam the great fan and a whole gallery's airflow reverses, dragging loose scrap past the player as collectible weather (docs/audit-2026-09-05/worker-4-universe.md:64).
**Requisition set dressing.** Ventilation crawlers wear mine-cooperative livery. The Fleet notice is an air-tax schedule. Keepers' chalk arrows on ducts show the correct flow direction, so a reversed streamer reads as wrongness without a word.
**Palette keyframe (hex values are proposals).** Canvas #d9d0af, plenum steel #7e8a88, dust haze #a79c86, petrol #183b3e, mint gauges #a6f4d6. Accent: mint instrumentation in dusty shafts. The one rung where mint is the accent, because breathable air is the energy of the place.
**Light and atmosphere.** Shafted light through louvers in dusty air, visible beams, low fog. Directionality of light matches current direction wherever possible so light itself is wayfinding.
**Audio identity.** The wind is the instrument: filtered noise beds whose bandpass follows local flow speed, and the great fan is a detuned saw pair whose beat frequency is its health bar. The reversal beat is a pitch inversion every player will hear.
**Defense space.** Defend the canary gallery and fresh-air head: plenum chamber arena, one duct lane and one catwalk lane at 2D, currents legal in lanes only if a still bypass exists (contract rule 1).
**What the player protects.** The mine town's breathable air: the fresh-air galleries, the canary coops, roosting bats. The stakes are invisible, so the canaries make them visible.

### 6. The Harvest Roads (candidate)

**Terrain modules.** Roadbed straight, roadbed cut (banked), flatbed deck (4x8, moving floor), coupler gap (0.5 to 1.5 units), waystation platform, hedgerow margin, cargo stack (lashed homes and harvest, protected), road-train engine footing (camera blocker), flatbed deck edge (the figurine chip). Nine modules.
**Traversal twist.** The floor has a velocity. Flatbed surfaces add a frame velocity to the servo target, so relative handling stays reference while world-space routes slide. Coupler gaps make radius a traversal stat for the first time: a grown ball bridges a gap a small ball must burst across. Touches speed target (frame bias) and radius, leaving acceleration alone so deck fighting feels like home (docs/audit-2026-09-05/worker-4-universe.md:65).
**Interactive and destructible set.** Lashing points (cut to spill collectible cargo the Fleet stole, never residents' marked belongings), brake rigs per car, couplers. Consequence beat: derail the harvest train by burst-ramming the lead coupler at a banked cut; a kilometer of stolen cargo avalanches back toward home (docs/audit-2026-09-05/worker-4-universe.md:65). The avalanche must obey contract rule 4 and leave the bypass open.
**Requisition set dressing.** This is the Fleet's own turf: native Fleet machines with gear-tooth heraldry (docs/audit-2026-09-05/worker-4-universe.md:65), waybills stapled to every cargo stack naming the town each crate came from. Reading the waybills is the quiet story of the whole campaign.
**Palette keyframe (hex values are proposals).** Fleet rust stripe #8a4a2e, stubble field #c6b98f, road iron #3c403d, notice cream #e8ddb5, hazard amber #ff9c52. Accent: rust-striped Fleet livery rolling through stripped countryside.
**Light and atmosphere.** Dusty late day, low sun raking the stubble, the train's own running lights warming the decks as evening falls along the run. The only rung whose horizon visibly moves.
**Audio identity.** A wheel-cadence clatter loop from gated noise bursts, tempo mapped to floor velocity, with slow pitch bends as cars pass. Coupler strikes are single deep square hits.
**Defense space.** Defend a waystation as the train bears down: platform arena, the roadbed and the hedgerow service path as the two 2D lanes. Aboard the train, each deck is its own small arena and the standoff keep-out is the car itself.
**What the player protects.** The stolen cargo, homes and harvests to be recovered intact, plus the waystations and hedgerow wildlife along the road.

### 7. The Furnace City (candidate finale setting)

**Terrain modules.** Conveyor street plate (the figurine chip), tilting deck section (8x8), counterweight district block (scheduled mover), service corridor (2D, the guaranteed honest route), stack base, heat-main crossing, crew-quarters facade (protected), engine gallery (boss arena, camera-blocked), mooring gantry. Nine modules, several re-skinning Foundry and Harvest Roads tech.
**Traversal twist.** The arena is a machine that moves (docs/audit-2026-09-05/worker-4-universe.md:66). Tilting decks add a persistent downslope acceleration bias; conveyor streets reuse the Harvest Roads frame velocity; counterweight districts move whole blocks on telegraphed schedules, applying the enemy commitment grammar to architecture itself. Every knob bent earlier in the campaign returns at once, and the service corridors are always reference-handling relief valves per contract rule 1.
**Interactive and destructible set.** Steam mains (vent to stall a district's schedule), counterweight latches, mooring lines. Consequence beat: city blocks shear away while the player rolls the service corridors, the ball unchanged, maximum Gurren tone (docs/audit-2026-09-05/worker-4-universe.md:66; escalation reading at docs/MARKET-RESEARCH.md:96).
**Requisition set dressing.** Inverted: here the civic livery IS Fleet livery, and the crooked notices are keepers' chalk marks left by previous raids. The conscription grammar the player learned now reads in mirror, which lands the premise without a line of dialogue.
**Palette keyframe (hex values are proposals).** Deep navy #0c1e23 dominant, furnace orange #ff7a3d, scorched iron #46342b, brass heraldry #c69f5a, sparse mint #a6f4d6. Accent: furnace glow under a navy night, the traveling-city silhouette burning orange (docs/audit-2026-09-05/worker-4-universe.md:66).
**Light and atmosphere.** Night exterior lit by the city's own fire, rim-lit chimneys, ember particles reusing the existing instanced particle pool (src/orchard/scene.js:142-150). The darkest and hottest keyframe; mint pickups glow hardest here by contrast.
**Audio identity.** The city is a failing organ: layered detuned drones that lose tuning as districts are disabled, klaxon squares for schedule warnings, and silence as the rarest effect, spent only after a block shears away.
**Defense space.** Reversed stakes: protect the crew quarters and escape gantries of the Fleet's own conscripted workers during engine-gallery fights. Two service corridors at 2D flank every set piece.
**What the player protects.** The Fleet's people. The city eats homes, the keeper does not, even here, which is the ending's argument and the never-absorbed rule at full scale.

## Next biome after the orchard (contested, one recommendation)

Candidates remain Yard Commons, Spillway Works and Foundry Crown. Spillway Works remains a paper recommendation because its current-field idea and Cancrusher family offer a distinct encounter. The older claim that it is necessarily the cheapest extension has not been verified against the caster controller. The basin deflect experiment is parked, and adjacency in the old campaign ladder is no longer a selection reason.

D10/P07 owns the next kit choice; D09/P12 owns the first-world and route policy. Choosing a content kit does not choose its fixed run position.

**Minimum viable kit:** 6 of the 9 modules (channel straight, channel bend, bypass gutter, settling basin, sluice gate, pumphouse facade), 3 enemies (Scooplet, Rackspan, Sluiceback), the one sluice-drain consequence beat, the palette keyframe, two civic signs plus one Fleet notice, and the water-noise audio bed. Everything else in the kit is additive after the drain beat proves out.

## Evidence limits

The following bullets preserve the original environment research's evidence statement. Its implementation observations are a first-proof snapshot. Accepted notebook direction above supersedes the campaign order and mass assumptions; the candidate kits remain unimplemented beyond their explicitly cited orchard elements.

- Read this session: docs/audit-2026-09-05/worker-4-universe.md, docs/ART-DIRECTION.md, docs/ORCHARD-ENCOUNTER-STUDY.md, docs/MARKET-RESEARCH.md, docs/DESIGN-AUDIT.md, docs/project/REQUIREMENTS.md, docs/project/ASSETS.md, src/orchard/scene.js in full, and targeted portions of src/orchard/simulation.js (lines 40-90, 315-360, 600-620) plus grep of src/orchard/models.js function names and src/orchard/main.js audio lines. Claims about those files cite exact lines.
- Not read: docs/ENEMY-TAXONOMY.md, docs/CONFLICT-AND-COMBAT.md, and the other audit workers directly; taxonomy and combat claims here are cited through worker-4 and DESIGN-AUDIT quotations of them and inherit any transcription error.
- All module names, sizes, hex values outside src/orchard/scene.js:14-24 and docs/ART-DIRECTION.md:13, parameter multipliers, and beat timings are design proposals, not measured or playtested values. D has no confirmed numeric value in anything read this session; it is defined, not measured (docs/ORCHARD-ENCOUNTER-STUDY.md:47).
- No runtime was executed, no image generated, no repo file written. The Foundry telegraph-brightness note and every handling multiplier need the same fixture-probe treatment the audit used before any number hardens.
- The original kit fiction used the proposed Requisition premise and seven-rung ladder. The ladder is now historical, and mass-as-currency was not adopted. Reusing a kit does not accept those assumptions.
