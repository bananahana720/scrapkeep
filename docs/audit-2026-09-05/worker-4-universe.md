# Worker 4 — Universe and art direction bible draft (Scrapkeep)

Session: 2026-09-05. Read-only pass over the repo; this file is the only write. Every claim about existing material cites a path/line observed this session. New fiction and rules are labeled **PROPOSAL**. Evidence level: paper/art review only — no image generation, no runtime test, no repo change.

Sources read in full: `docs/ART-DIRECTION.md`, `docs/CONCEPT-STUDY-01.md`, `docs/CONCEPT-STUDY-02.md`, `docs/CONCEPT-STUDY-03.md`, `docs/ENEMY-TAXONOMY.md`, `docs/CONFLICT-AND-COMBAT.md`, `docs/HANDWRITTEN-NOTES.md`, `docs/ORCHARD-VISUAL-SWARM.md`, `docs/project/ASSETS.md`. Images inspected with Read: all 8 files in `public/art/` and `docs/discovery/source-notes-2026-08-21/photo-3.jpg` (its "5 levels / pick one from 2 / items are meaningful" lines are legible and match the transcription at `docs/HANDWRITTEN-NOTES.md:50-56`). Skimmed: `docs/art-prompts/05-pruner-family-v2.txt`, `docs/art-prompts/06-orchard-storyboard-v2.txt`, plus targeted greps of `docs/DISCOVERY.md`, `docs/MARKET-RESEARCH.md`, `docs/BASELINE-GUIDE.md`, `docs/FIRST-BUILD-*`, `src/campaign.js`, `src/heroes.js`.

Accepted direction honored throughout: the coordinator judged concept study 01 "too orderly and manufactured" for the Katamari identity and asked future studies to make the accumulated, irregular scrap mass and rolling character more prominent (`docs/DISCOVERY.md:175`). Bounded growth: visible growth stays within mech-scale routes while battle scale and destruction escalate, Gurren Lagann as tone reference (`docs/DISCOVERY.md:37`, `docs/MARKET-RESEARCH.md:18`, `docs/COMBAT-DESIGN-SWARM.md:22`).

---

## 1. World premise

### Existing material

- Two conflict candidates are on the table: **Furnace Fleet** (rival animal crews' traveling industrial city whose failing engines consume ever more machinery) and **Wildworks Bloom** (an ancient gardener's plant/machine graft organism). The coordinator and faction designer favor the Fleet; it is "a recommendation, not accepted canon" (`docs/CONFLICT-AND-COMBAT.md:15-27`).
- Optional antagonist **Admiral Brindle**, a small badger promising that "one more harvest" will secure the city (`docs/CONFLICT-AND-COMBAT.md:22`).
- The orchard family already runs on a different fiction hook: local maintenance machines redirected "through bolted control overrides," with the orchard itself still cared for and worth protecting (`docs/ENEMY-TAXONOMY.md:122,166`). Enemy machines are autonomous; faces are control boxes, no animal operators (`docs/CONCEPT-STUDY-03.md:15`, `docs/ORCHARD-VISUAL-SWARM.md`, Decisions list).
- Visual evidence of a tone gap: the Fleet sheet (`public/art/04-furnace-fleet-enemies.png`) reads heavily weathered rust-and-ivory with furnace glow — the study itself notes the surface treatment is "more weathered and industrial than the playful motion we intend" (`docs/CONCEPT-STUDY-02.md:15`) — while the orchard family (`public/art/05-pruner-family-study-v2.png`) is sage/cream/ochre, apple decals, a maintained workplace. The baseline palette is warm ivory #d4d3bf, petrol #183b3e, deep navy #0c1e23, amber-orange #ff9c52, mint #a6f4d6 (`docs/ART-DIRECTION.md:13`).

### Competing premises (each one paragraph) — **PROPOSAL**

**Premise A — The Fleet is the whole answer.** The Furnace Fleet's traveling city is dying of its own appetite; its captains strip regions of working machinery and its own machines do the fighting. Every enemy in every biome is a Fleet machine shipped in for the harvest. *Grounded-machinery:* strong for Fleet-native machines (plows, clampcarts, cranes), but weak in remote biomes — why would a traveling city carry orchard pruners and drip-irrigation filters? It fights the taxonomy's rule 2, "its job must explain its location" (`docs/ENEMY-TAXONOMY.md:18`). *Tone:* the current Fleet art skews grim-industrial (see gap above); everything looking Fleet-made narrows the palette toward rust. *Expandability:* every new biome needs new Fleet imports, so families converge visually.

**Premise B — The Requisition: the Fleet is the answer, delivered through local machines.** The Fleet is still the single antagonist — Brindle's city really is starving — but its instrument is the **requisition bolt**: a bolted-on override (already canon-adjacent in the orchard fiction, `docs/ENEMY-TAXONOMY.md:122`) that conscripts a region's own working machines into harvest duty. Spillway screens, foundry cranes and orchard pruners keep doing their real jobs — collecting, lifting, cutting — only now the material they gather is the town itself, fed down the line toward the Fleet. Animal pilots are the region's **keepers**: maintenance crews who know these machines because they service them, now piloting improvised scrap balls to knock the bolts off, salvage the parts, and keep the pumps, seedhouses and homes running. *Grounded-machinery:* strongest — every enemy is literally the biome's occupational equipment, and its job explains its location, anatomy, wear and salvage for free. *Tone:* comedy and menace both come from workplaces misbehaving; keepers vs. a proud rival crew keeps it cute, never horror. *Expandability:* any human-scale industry is a future biome (waterworks, ventilation, rail, the Fleet city itself), each with a native palette shift under the shared baseline; Fleet-liveried machines appear as escorts/overseers so the antagonist stays visible everywhere.

**Premise C — Wildworks Bloom.** The gardener's graft organism absorbs homes and machines into a mechanical ecosystem (`docs/CONFLICT-AND-COMBAT.md:18`). *Grounded-machinery:* weakest — grafted plant/machine hybrids drift away from believable occupational detail, and the doc itself says its rules "need more explanation" (`docs/CONFLICT-AND-COMBAT.md:26`). *Tone:* stranger and riskier; body-horror adjacency threatens the cute-pilot identity. *Expandability:* high but at the cost of the machine-detail constraint.

### Recommendation: **Premise B — The Requisition**

It keeps the team's Furnace Fleet recommendation intact (the Fleet *is* the answer), while making the biome roster the larger answer's delivery mechanism. It is the only premise that simultaneously explains both existing visual families: the fire-dark Fleet machines in `public/art/04-furnace-fleet-enemies.png` (the Fleet's own equipment) and the sage/cream orchard workers with bolted control boxes in `public/art/05-pruner-family-study-v2.png` (requisitioned locals). It also resolves the tone gap: Fleet steel stays dark and hungry; requisitioned machines keep their friendly workplace liveries, wrongness carried by the bolt, not by grime.

### One-page canonical version — **PROPOSAL** (pending Andrew's approval; supersedes nothing)

> **SCRAPKEEP — The Requisition**
>
> The world runs on machines that work. Spillway screens rake the storm drains, orchard carts sort the pruned twigs, foundry cranes swing cooled castings into racks. Every town has its keepers — small animals with big toolboxes who grease the joints, chalk the service marks and know every machine by its rattle.
>
> Then the Furnace Fleet came over the ridge: a traveling industrial city, chimneys like a pipe organ, hauling its own horizon behind it. The Fleet was magnificent once. Now its engines are failing, and a failing furnace-city eats. Admiral Brindle — a badger you could hold in two paws, commanding more iron than any animal should need — keeps promising the crews that *one more harvest* will make the city secure. The next harvest is always somebody else's home.
>
> The Fleet doesn't fight its own battles. Its press-gangs move ahead of the city bolting **requisition units** onto whatever a region already runs: the pump-house rakes, the orchard pruners, the foundry hammer. The machines aren't evil and they aren't broken — they're doing their jobs perfectly, for the wrong boss. A rake still rakes; now it rakes up fences. A clampcart still carries; now it carries away the turret you just built.
>
> The keepers fight back the only way keepers can: with the junk pile. A rolling salvage ball — glass cockpit at the heart, everything else accumulated — grows by collecting exactly what the Fleet came to steal. Every part knocked off a requisitioned machine is a part the keeper understands, because the keeper used to service it. Beat the machines gently: pop the bolt, salvage the surplus, and the orchard goes back to being an orchard.
>
> The Fleet's answer to a troublesome region is escalation — bigger travel-rigs, the great harvesters, and finally the city itself wading in. The keepers' answer never changes size on the outside: the ball still fits the service roads. What changes is what a rolling ball of a town's whole toolkit can bring down.
>
> *Pilots are keepers, not soldiers. Machines are workers, not monsters. Nothing living or lived-in ever ends up in the ball.*

---

## 2. Biome ladder

### Existing material

Three worked family roots exist: **The Cancrusher** (spillway), **Counterweight Crown** (foundry), **The Grand Pruner** (walking orchard), plus miniboss Sluiceback (`docs/ENEMY-TAXONOMY.md:11`). Parked concepts: a **ventilation family** (Bellows Skimmer/Maw) and **Kiln Strider**, an alternative large harvester (`docs/ENEMY-TAXONOMY.md:177-178`). The playable baseline yard has its own sector/boss names (Cancrusher, Glassjaw, Old Ironroot per `docs/CONFLICT-AND-COMBAT.md:102` citing `src/campaign.js:21`) and the first-build orchard slice exists (`docs/FIRST-BUILD-PLAYGUIDE.md:3`). Andrew's notebook proposes dungeon worlds of **5 levels with end-level bosses** (`docs/HANDWRITTEN-NOTES.md:50-56`, confirmed legible in `docs/discovery/source-notes-2026-08-21/photo-3.jpg`). Expeditions are 30–45 min (`docs/COMBAT-DESIGN-SWARM.md:22`).

### The ladder — **PROPOSAL** (7 rungs; extends the three taxonomy roots)

| # | Biome | Occupation → enemy family | Traversal twist that changes rolling | Destruction-scale beat | Visual signature (one line) |
|---|---|---|---|---|---|
| 1 | **Yard Commons** (home) | Municipal salvage collection — Scooplet-strain collectors and yard bugs (baseline enemies, `docs/BASELINE-GUIDE.md:26`) | Curbed maze lanes and low retaining walls; banking off orange-edged curbs is the first skill (`public/art/01-yard-concept.png`) | Tip one loaded gantry into a wall — the first "I did that?" | Warm ivory concrete, safety-orange edges, mint crates under a near-black sky |
| 2 | **Spillway Works** | Wastewater screening/compaction — Cancrusher family: Scooplet, Rackspan, Crossbelly, Rinsebelly, Pressling; Sluiceback miniboss (`docs/ENEMY-TAXONOMY.md:26-71`) | Wet channels, bypass gutters and drainable basins: water level changes which lanes roll fast and which bank | Burst a sluice gate and drain a whole basin mid-fight, rerouting everyone | Patched pale concrete, tide lines and sediment rings, galvanized steel over petrol water |
| 3 | **The Iron Orchard** | Horticulture — Grand Pruner family: Snipcart, Spreadleg, Flushpot, Discback, Graftmender; Rowkeeper miniboss (`docs/ENEMY-TAXONOMY.md:120-155`; first playable slice exists, `docs/FIRST-BUILD-PLAYGUIDE.md:3`) | Terraces, turning aprons and previewed irrigation lanes; soft cultivated ground vs. swept aprons changes grip | Fold a house-sized pruning arm into a ramp; the greenhouse boss walks (`public/art/05-pruner-family-study-v2.png`) | Sage enamel, cream links, ochre pads, apple decals — living green the ball must protect, not eat |
| 4 | **Foundry Crown** | Foundry lifting/dispatch — Counterweight Crown family: Pegjack, Reelrat, Bellhanger, Brakebogie, Clampcart; Yardmaster miniboss (`docs/ENEMY-TAXONOMY.md:73-118`) | Curved rail sidings, slag drums and swinging loads: moving shadows and cables are the terrain | The furnace hammer craters the arena; wrecked carriages become new bank angles (`docs/CONFLICT-AND-COMBAT.md:68-78`) | Fire-dark iron and copper under a tall crane aisle, ladles glowing amber in petrol gloom |
| 5 | **The Windworks** (expansion rung) | Mine/city ventilation — the parked Bellows family unparked as its own biome (`docs/ENEMY-TAXONOMY.md:177`; Bellows Maw at `docs/CONFLICT-AND-COMBAT.md:58-64`) | Intake cones and exhaust jets add/steal rolling momentum; fabric streamers preview every current | Jam the great fan and a whole gallery's airflow reverses, dragging loose scrap past you | Canvas ducts, riveted plenums and spinning louvers, mint gauges in dusty shafts |
| 6 | **The Harvest Roads** (expansion rung) | Fleet logistics convoy — Kiln Strider as traveling harvester plus Fleet escorts Plowback/Clampcart (`docs/ENEMY-TAXONOMY.md:176,178`; `public/art/04-furnace-fleet-enemies.png`) | Fighting on and between moving flatbeds and road-trains; the floor itself has a velocity | Derail the harvest train; a kilometer of stolen cargo avalanches back toward home | Rust-striped Fleet livery and gear-tooth heraldry rolling through stripped countryside |
| 7 | **The Furnace City** | The Fleet flagship — every family's overseer variants plus city-scale engine works; Brindle's seat (`docs/CONFLICT-AND-COMBAT.md:17,22`) | The arena is a machine that moves: tilting decks, counterweight districts, streets that are conveyor beds | City blocks shear away while you roll its service corridors — maximum Gurren tone, ball unchanged | A traveling city silhouette — chimneys, cranes, plows — burning orange against deep navy |

**How the ladder escalates without breaking mech-scale routes.** The ball's dependable collision envelope never outgrows the service roads (`docs/DISCOVERY.md:37`; envelope hypothesis at `docs/MARKET-RESEARCH.md:39`, adopted in `docs/ORCHARD-VISUAL-SWARM.md` Decisions). Three other axes carry the Gurren escalation instead: (1) **machine scale** — worker → miniboss → area boss within each family, already the taxonomy's teaching order (`docs/ENEMY-TAXONOMY.md:9`); (2) **architecture scale** — the "arena" grows from a curbed yard to a walking greenhouse to a traveling city, while playable routes stay corridor-width (the Crown fight already models this: mech-scale routes interacting with machinery that controls a much larger threat, `docs/CONFLICT-AND-COMBAT.md:70`); (3) **consequence scale** — the same learned actions (bank, ram, pop a hinge) graduate from tipping a cart to draining a basin to shearing a city block, which is exactly the "hero's actions have increasingly enormous consequences" reading in `docs/MARKET-RESEARCH.md:96`.

**Reconciling with the notebook's five-level structure (contested → one recommendation):** the notebook's dungeon worlds have 5 levels with end bosses (`docs/HANDWRITTEN-NOTES.md:50-52`) and it is a candidate, not committed scope (`docs/HANDWRITTEN-NOTES.md:79`). **Recommendation:** ship the first campaign as rungs 1→2→3→4→7 (five levels, five bosses, matching the notes), and hold Windworks (5) and Harvest Roads (6) as the first two expansion rungs — they are already designed as parked families, so nothing is invented for the shelf.

---

## 3. The scrap ball as the protagonist's portrait

### Existing material and the accepted critique

Four ball generations exist in art: the orderly radial turret sphere (`public/art/01-yard-concept.png`, `public/art/02-arsenal-concept.png` — evenly spaced cannons on a faceted sphere with mint slit eyes, per prompt at `docs/ART-DIRECTION.md:21`); the hooped armor-ring ball with a fox pilot (`public/art/03-industrial-dungeon-study.png`); and the irregular mismatched-plate balls with a visible hamster capsule in `public/art/04-furnace-fleet-enemies.png` (bottom-right scale reference), `public/art/05-pruner-family-study-v2.png` (with a readable "ORCH-7" salvage plate) and `public/art/06-orchard-combat-storyboard-v2.png`. The coordinator's accepted critique targets the first generation: too orderly and manufactured (`docs/DISCOVERY.md:175`). Study 02's own prompt already encodes the correction: "clearly look like an accumulated rolling ball, not a manufactured smooth mech" (`docs/CONCEPT-STUDY-02.md:28`). The first build implements a stabilized enclosed hamster cockpit inside an irregular scrap cage, cabin max radius 0.868 of the unit ball (`docs/FIRST-BUILD-CONTRACT.md:32`, `docs/FIRST-BUILD-VERIFICATION.md:7,31`).

### Visual rules — **PROPOSAL** ("the ball is the save file you can see")

1. **No radial symmetry, ever.** Attachments cluster where they were collected, not on a grid. Silhouette target is a lumpy convex-ish polygon whose bumps differ on every axis — the `04`/`06` balls, never the `01`/`02` turret sphere. Rule of thumb: if any three attachments are equidistant, move one.
2. **The cockpit is the single invariant.** One glass capsule, animal always readable, gyro-stabilized, framed by a cream collar so it pops from any scrap density (implemented: `docs/FIRST-BUILD-CONTRACT.md:32`). Everything else may churn; the face of the character never does.
3. **Parts keep their provenance.** A salvaged plate keeps its source livery and stencil — orchard sage with apple decals, spillway galvanizing and tide stains, Fleet fire-dark iron — following the material-specific palette rule (steel, copper and enamel must not share one orange surface, `docs/ENEMY-TAXONOMY.md:183`). Reading the ball tells you which biomes this run visited and which bosses died: the ball is the run's diary.
4. **The silhouette states the build.** The class-signature mechanism is always the largest, most asymmetric protrusion (grapple mast, mortar dish, laser spine, lightning rods — classes per `docs/DISCOVERY.md:17`); boss-earned parts (Valve Wheel, Counterweight Heart, Graft Spool — `docs/CONFLICT-AND-COMBAT.md:56,78,90`) get silhouette-breaking placements so a veteran can read another player's build at thumbnail size. Loose cannons keep horizontal silhouettes and energy cells square mint cages, extending the existing readability rule (`docs/ART-DIRECTION.md:36`).
5. **Some things are NEVER absorbed:** the cockpit and any glass; living plants and trees (the orchard stays worth protecting, `docs/ENEMY-TAXONOMY.md:122,166`); inhabited structures and residents' belongings (premise rule — the Fleet eats homes, the keeper does not); companion cores (companions dock, they are not consumed); other pilots' capsules. Decorative scrap may wobble expressively **outside** the dependable collision envelope — expression never taxes control (`docs/MARKET-RESEARCH.md:39`, `docs/ORCHARD-VISUAL-SWARM.md` Decisions).
6. **Wear is honest.** Fresh salvage is clean-edged; long-carried plates gain abrasion on their leading faces only — contact history follows physics, matching the taxonomy's wear layer (`docs/ENEMY-TAXONOMY.md:187-194`).

---

## 4. Pilot and character design language

### Existing material

- Requested class fantasies: **grapple traversal, hovering mortar bombardment, cyborg laser ball, lightning wizard ball** (`docs/DISCOVERY.md:17`).
- Current baseline roster (playable): **Pip the scavenger** (speed/pickup/vacuum), **Rivet the engineer**, **Moss the warden** (`docs/BASELINE-GUIDE.md:28-30`; Pip in `src/heroes.js:16`, `src/campaign.js:4-6` — "If it rattles, Pip can probably make it shoot.").
- Species is visually contested: study 01 shows an orange **foxlike** pilot (`docs/CONCEPT-STUDY-01.md:20`), studies 03's images and the first build show a **hamster** (`docs/CONCEPT-STUDY-03.md:31`, `docs/FIRST-BUILD-VERIFICATION.md:7`); Brindle is a badger (`docs/CONFLICT-AND-COMBAT.md:22`). Notebook personalities (beast-mode shifter, gunslinger, chaos caster, oil-slick, conscious bomb drone) are candidates, not requirements (`docs/HANDWRITTEN-NOTES.md:33-38,74-84`).
- Enemy canon: machines are autonomous, faces are control boxes, no animal operators (`docs/CONCEPT-STUDY-03.md:15`, `docs/ORCHARD-VISUAL-SWARM.md` Decisions).

### Rules — **PROPOSAL**

**Small-screen distinctness (the capsule is ~64px in the chase camera):** each pilot gets (1) one saturated accent color owned by no other pilot, worn as a scarf/harness inside the capsule; (2) a unique **ear-plus-headgear silhouette** readable in the dome as pure shape (round ears + goggles ≠ tall ears + hood ≠ folded ears + welding visor); (3) a signature idle posture (leaning forward, lounging, gripping two levers). Faces carry emotion; silhouettes carry identity.

**Pip species (contested → one recommendation):** make **Pip the hamster** canonical. The playable build already models it (`docs/FIRST-BUILD-VERIFICATION.md:7,31`), a hamster inside a rolling ball is the game's thesis as a sight gag, and the storyboard's "happy protected hamster" (`docs/art-prompts/06-orchard-storyboard-v2.txt`) is the character. The study-01 fox is freed to become a second pilot.

**Species/personality slots for the four class fantasies** (all **PROPOSAL**; reconciling with the baseline trio is future work — Rivet and Moss can inherit slots):

| Class fantasy (`docs/DISCOVERY.md:17`) | Pilot slot | Why the species reads |
| --- | --- | --- |
| Grapple traversal | **Pip**, hamster keeper — the scavenger identity already shipped (`docs/BASELINE-GUIDE.md:28`); orange accent | Small body, huge momentum: the whole fantasy of swinging mass |
| Hover mortar | A **fox** artillerist (recovers study 01's pilot, `docs/CONCEPT-STUDY-01.md:20`); rust-red accent, long ears + aviator cap silhouette | Patient, watchful posture suits the bombardment fantasy |
| Cyborg laser | A **mole** machinist with a lens visor; mint accent — candidate heir to Rivet's engineer slot | Weak eyes, perfect aim through instruments: the visor IS the character |
| Lightning wizard | A **chaos-caster squirrel**, 75%-trained and sure of itself — direct adoption of the notebook's amateur spellcaster (`docs/HANDWRITTEN-NOTES.md:37`, interpreted at `:81`); static-charged tail as the silhouette | Erratic energy without random control loss, per the interpretation note |

**Enemy silhouette rules per family** (extends the taxonomy's anatomy inheritance, `docs/ENEMY-TAXONOMY.md:7`): **Spillway** = horizontal working axes — every machine is a stroke along a line (rake, belt, ram), silhouettes longer than tall, tells travel front-to-back. **Foundry** = verticals and suspended masses — gantries, hanging loads, counterweights; the dangerous shape is above, its shadow is the tell (`docs/ENEMY-TAXONOMY.md:75`). **Orchard** = forked circular joints and shear curves — the fork-pivot-link kit shared from Snipcart to Grand Pruner (`docs/CONCEPT-STUDY-03.md:13`; visible in `public/art/05-pruner-family-study-v2.png`). **Ventilation** (future) = expanding/contracting volumes; **Fleet natives** = wedge-and-armor frontality (Plowback's shield, `public/art/04-furnace-fleet-enemies.png`). One test governs all: family recognizable from the black silhouette alone, per the color-independence rule (`docs/ENEMY-TAXONOMY.md:21`, `docs/CONFLICT-AND-COMBAT.md:120`).

---

## 5. Figurine-readiness

Figurines are a companion product (`docs/DISCOVERY.md:15`); the current signup art "is a character concept, not a photo or print-ready model" (`docs/BASELINE-GUIDE.md:42`, `docs/RETENTION-VERIFICATION.md:36`).

### Five rules — **PROPOSAL**

1. **Self-supporting stance.** The ball rests on a flattened contact patch (in-fiction: compressed scrap) giving ≥3 contact points; walkers need both feet plus tool-tip or tail grounded. No pose requiring the clear dome to bear load.
2. **Base = biome chip.** Every base is a 40–60mm terrain module straight from the game kit — orange-edged curb, rail siding curve, orchard apron with a nursery tray — so bases identify biomes the way silhouettes identify families, and the game's modular terrain doubles as product design.
3. **Part separation mirrors the game's attachment system.** Attachments that snap onto the ball in-game are separate plug-in physical parts with ≥3mm minimum feature thickness and one dominant axis per part; blades and shear tips get thickened "display grind" edges (Snipcart's thin bypass shears in `public/art/05-pruner-family-study-v2.png` would need this). This keeps one Blender source usable for runtime LOD and print master.
4. **Paintable palette.** ≤5 flat matte colors per figure drawn from the canonical hexes (`docs/ART-DIRECTION.md:13`) plus per-biome accent, applied in large blocks with crisp bevel boundaries — the "flat matte surfaces, crisp beveled cubes" language is already the render target. Steel/copper/enamel read as three different paints, per the CCI-derived material rule (`docs/ENEMY-TAXONOMY.md:183`).
5. **The 5cm monochrome test.** Primer-grey at 5cm, front three-quarter view: family must be identifiable and the cockpit + one signature part visible. This is the same silhouette test the game already imposes (`docs/ENEMY-TAXONOMY.md:21`), so passing in-game is progress toward passing in resin.

### Who passes today (inference from image inspection, not physical test)

- **Passes:** the accumulated ball with hamster capsule as drawn in `public/art/04-furnace-fleet-enemies.png` (bottom-right) and `public/art/05-pruner-family-study-v2.png` — round, self-supporting, big paint blocks, capsule focal point. **Plowback** (`public/art/04`) — a self-standing wedge with a separable plow plate already drawn detached. **Spreadleg** v2 (`public/art/05`) — two broad padded feet are a built-in base.
- **Marginal:** **Snipcart** — chunky cart passes; raised open shears violate rule 3 without thickening. **Sluiceback** (`public/art/04`) — good mass, but its many overlapping loose plates want consolidation into ≤4 separable pieces.
- **Fails as a single figurine:** **Counterweight Crown** and **Grand Pruner** — they are playsets/dioramas, not figures (the concept sheets themselves present them as compressed design views, `docs/CONCEPT-STUDY-02.md:15`, `docs/CONCEPT-STUDY-03.md:17`). The `01`/`02` orderly turret sphere would mold easily but fails the story rules in section 3 — do not productize the design the critique retired.

---

## 6. Art pipeline — next five steps

The proposed workflow is concept/paintover → Blender model/rig → animation → import/verify in runtime (`docs/DISCOVERY.md:175`). Free-tool constraint: Blender, Krita, Audacity, Kenney/Poly Haven CC0 (`docs/DISCOVERY.md:171`); the built-in generator is available but not open-source, and rasters are not production meshes (`docs/DISCOVERY.md:173`, `docs/CONCEPT-STUDY-03.md:46`). Asset admission rules (record source, license, transformations; keep editables out of `dist/`) per `docs/project/ASSETS.md:17-18`. All five steps below are **PROPOSAL**; order is by how much each de-risks.

1. **Ball build-state turnaround sheet** — *Krita paintover over real screenshots of the first-build hero* (captures exist per `docs/ART-DIRECTION.md:41`). 3 growth stages × 4 class signatures on one sheet, applying section 3's rules. **Acceptance:** in a monochrome thumbnail lineup, a viewer names class and early/mid/late stage for ≥10 of 12 cells; no cell reads as a radial turret sphere. **Feeds runtime:** becomes the placement rulebook for `createHero()` attachments (`docs/FIRST-BUILD-CONTRACT.md:32`), replacing today's ad-hoc spherical placement with history-clustered placement.
2. **Snipcart articulated Blender blockout** — *Blender, glTF export*, executing the taxonomy's own recommended next study: the shared fork-and-brace assembly across Snipcart/Spreadleg/Grand Pruner (`docs/ENEMY-TAXONOMY.md:220`). Model the fork joint once, reuse at three scales. **Acceptance:** the position/brace/operate/release rhythm (`docs/ENEMY-TAXONOMY.md:139`) reads at gameplay chase-camera distance in a Three.js import; closed-cut pose actually closes (fixing the storyboard's unresolved closure limit, `docs/CONCEPT-STUDY-03.md:17,31`). **Feeds runtime:** the first authored enemy rig for the Iron Orchard slice, replacing procedural approximations.
3. **Pip capsule and expression sheet** — *Krita turnaround*: hamster canon (section 4), harness, 5 expressions, capsule collar design. **Acceptance:** identity and emotion readable at 64px; closes the species decision; capsule geometry fits the verified 0.868 cabin envelope (`docs/FIRST-BUILD-VERIFICATION.md:31`). **Feeds runtime:** cockpit remodel + the figurine dome master (rule 5.1) + signup-page art consistency (`docs/RETENTION-VERIFICATION.md:36`).
4. **Biome palette keyframes** — *Krita paintovers*, one per campaign rung, starting Spillway and Foundry (rungs 2 and 4): derive each biome's 5-swatch shift from the canonical hexes (`docs/ART-DIRECTION.md:13`), including the Fleet-livery reconciliation so rust never swallows the cream/orange/mint identity (the study-02 gap, `docs/CONCEPT-STUDY-02.md:15`). **Acceptance:** all rung keyframes in one lineup read as the same game; each biome nameable from swatches alone. **Feeds runtime:** material constants for the world/art modules (`docs/project/ASSETS.md:8` inventories `src/art.js`, `src/world.js`).
5. **Figurine test blockout** — *Blender*: 60mm Pip-ball from step 1's mid-stage, decimated, split per rule 5.3 into ball + capsule + 2 signature parts + biome-chip base. **Acceptance:** passes the 5cm monochrome test as a grey render; part thicknesses ≥3mm; slicer report shows minimal supports (paper check only — an actual print is a later, separately-authorized purchase). **Feeds runtime:** the separation cuts double as the ball's LOD/attachment seams, and the base chip is a real terrain module — product work that pays the game back.

---

## Verdict

**Evidence level: paper and image review only (documents + 9 images inspected in-session); no runtime, no generation, no repo writes.** Existing material is strong enough to draft a coherent bible: the three occupational families, the accepted anti-orderly critique, the bounded-growth ruling and the two existing visual families jointly *imply* the Requisition premise rather than fight it. Main open contests resolved with single recommendations: premise B (Requisition), 5-rung first campaign from a 7-rung catalog, Pip-as-hamster, and no productization of the retired orderly ball. Biggest unresolved risk observed: the Fleet sheet's grim weathering vs. the baseline palette (`docs/CONCEPT-STUDY-02.md:15`) — addressed by pipeline step 4.
