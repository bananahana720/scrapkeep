# Scrapkeep publisher discovery

Updated 5 September 2026. This record owns accepted publisher direction. The notebook interview below updates the future game design; it does not expand the implemented lightning increment. The original yard remains the baseline at `/`. Historical research and build scopes retain their stated evidence limits.

## Accepted notebook interview

Andrew clarified the four notebook photos in conversation and approved recording the resulting design across the project. This section supersedes the earlier expedition duration, stage-count reconciliation and notebook interpretations. The [requirements](project/REQUIREMENTS.md) track implementation status; the [decision register](project/DECISION-REGISTER.md) tracks rulings and remaining choices; the [runtime blueprint](RUNTIME-BLUEPRINT.md) owns the target system boundaries.

### Run, worlds and levels

A successful run lasts **60–75 minutes** and crosses **four worlds**. A world contains procedurally generated compact encounter levels followed by its world boss. Clear a level and choose an exit onward. Regular levels can contain waves, exploration, events and occasional minibosses; an ordinary level does not require a boss. Completing the final encounter wins the run.

At transitions to another world, randomly offer two destinations and let the player pick one. Four worlds is the run length, not the size of the world catalogue. The catalogue size, repeat rules, first-world selection, exact levels per world and whether the final encounter is world four's boss or a separate encounter remain open. Seeded generation is accepted; the choice between authored encounter assembly and procedural terrain techniques is still design work. The notebook's five-level count and boss at every level are superseded.

### Character build and progression

Every character has four customizable slots: **weapon, main hero skill, mobility and ultimate**. Each slot has its own character-specific branching tree with eight possible endpoints. A slot follows one route; crosspathing is not part of this structure. Andrew clarified the branching shape during the 6 September Bible review: one root forks to two upgrade nodes, each forks again to four nodes, and each of those forks to eight endpoints. Every nonterminal node has exactly two children; the selected path stays in one connected lineage. Four slots does not prescribe four playable characters. See the [Bible systems reference](../BIBLE.md#6-core-systems).

Begin a run with a weapon and special mobility. Ordinary movement is always available. The main hero skill and ultimate unlock during the opening world. Both slot access and deeper upgrades advance through combat, encounters, events, objectives and area milestones, without elapsed-time gates. A normal successful route should reach an endpoint in all four trees by the final boss. Exact node effects, costs and milestone allocations remain open; the binary branching shape is settled. Major mechanical upgrades should also change visible character, weapon or effect design.

Changing a selected skill-tree branch requires a special respec opportunity, such as a room or event. This is separate from reconfiguring acquired items between fights, which remains accepted. Optional transformative items may replace core movement or attacks; compatible shared modifiers can affect the player, devices and companion. One main companion remains the run's anchor, with temporary helpers possible as effects.

### Loot and secret combinations

Items are a separate, randomly encountered source of meaningful build changes. Rare enemies, random events, secret rooms and bosses can award them. Their appearance and mechanics belong to the world, area and universe that produces them. They may augment or attune to specific characters, other items, or both.

Certain combinations of selected slot endpoints grant **fixed secret bonuses** to a route or the whole character. The same eligible combination produces the same effect. The surprise comes from discovering the recipe, not rerolling its reward. Recipe effects, eligibility and disclosure details remain future content work. Exceptional combinations may dominate familiar encounters; the existing earned-dominance ruling still applies.

### Defeat, saving and permanent progression

Each run has one standard revival. A subsequent death ends the run. Save completed progress and the build between levels, then resume at the next level entrance. Consumed revival and resolved rewards must survive saving and loading without being granted twice. Exact revival health, placement and interruption during an unfinished level remain open implementation decisions.

Discoveries and permanent unlocks survive defeat. Between runs, unlock options and challenges while rebuilding combat power during each run. A discovered secret recipe can become permanent knowledge; its combat bonus still requires the eligible build in the current run. Permanent profile data and a resumable run checkpoint serve different purposes.

### Reference boundaries and creative direction

- Overwatch informs distinct weapons, active aiming and hero abilities.
- Bloons informs only the tower upgrade-tree design pattern for the four character slots. It does not introduce tower-defense gameplay, an economy or crosspath rules.
- Hades informs encounter levels, maps and area progression.

The chaos magician combines a directed weapon with a shorter-range automatic field, like a mobile Tesla coil. It can release multiple elements and effects. The character is an overconfident novice, usually capable of the intended spell but occasionally miscasting. Some failures genuinely hurt or inconvenience the magician. This is not an always-random attack kit, an electricity-only rule, or approval of an instability meter. Miscast frequency, severity and the element pool remain open.

The current lightning prototype is a distinct implemented kit, with two combat abilities alongside primary, mobility and ultimate. It does not implement these four upgrade trees or the chaos trait. Mapping that prototype or the proposed Fuse character to the future magician is still design work.

Andrew delegated creative development of names, personalities, visual expression and comic mishaps. The newly conscious bomb drone is character inspiration; it does not require a learning system or a companion role. Other notebook sketches remain available for creative exploration. Proposed names, species and fiction remain labeled as inventions, and uncertain handwriting stays uncertain in the [source transcription](HANDWRITTEN-NOTES.md).

## Approved lightning caster direction

Andrew played the first orchard proof and requested an MMORPG-style caster/shooter with hero weapons and abilities. He clarified that this describes combat and character systems; solo expeditions remain the scope and co-op comes later. Movement was decent, but he wanted physical impacts, double jumping and bouncing across small enemies. He found the scattered, tiny HUD hard to read and requested a toggleable management dashboard.

The implemented increment uses one lightning hero with primary fire, two combat abilities, mobility and an ultimate. Mouse movement controls the view, right mouse focuses third-person aim, and holding/releasing a targeted ability previews/casts its actual path or area. Three denser waves replace the first proof's fixed encounter.

The planning choices are approved: growth feels powerful and playful; rare optional items can replace core movement and attacks; shared modifiers affect compatible weapons, devices and companions; exceptional builds can dominate; acquired items can be reconfigured between fights; one main companion anchors a run. The [lightning increment](project/INCREMENT-01-lightning-playtest.md) includes Ground Loop, Echo and the existing priming companion as a small playable example. Andrew explicitly requested implementation of that plan. It supersedes the audit's mass-and-deflect proposal as the next build, while the remaining research stays proposed.

## Historical first-build scope

After the research and visual passes, Andrew approved building the first orchard proof and setting its session goal. The authorized entry is `/orchard.html`, with the original yard preserved at `/`.

The first build implements a close third-person rolling ball, aimed charge-release pulses, a low-cooldown burst, braking, Snipcart's inward jaws, Spreadleg's outward feet, and one large Pruner arm. The arm also tosses an announced rolling offcut to pressure distant attacks. Earned Shear and Brace parts change behavior and appearance; one optional following Shear Buddy primes nearby enemies. The proof uses the existing Three.js runtime. No engine migration, full class roster, co-op, complete expedition, or permanent progression is included.

The simulation and model work is delivered and admitted. The live DOM-input expedition, visual inspection, production build, and regression checks passed. The [play guide](FIRST-BUILD-PLAYGUIDE.md), [build-team record](FIRST-BUILD-SWARM.md), and [verification receipt](FIRST-BUILD-VERIFICATION.md) describe the current implementation and evidence. The verification receipt records the accepted first-build result and the remaining playtest limits.

## Publisher direction

Andrew wants a standalone PC/controller game, with physical figurines as a companion product. His earlier interview established **Katamari-like rolling, collecting and chaotic collisions as a core part of the appeal and character design**, alongside the later caster/shooter direction. Cute animal pilots live inside an irregular ball of accumulated scrap, weapons and machinery. Classes, aimed attacks, item combinations and infrastructure should reinforce that physical identity. The intended view is close third person, with increasingly epic themed difficulty areas. Bumping enemies and, eventually, other players is part of the fantasy; solo first remains confirmed.

The requested class fantasies are grapple traversal, hovering mortar bombardment, a cyborg laser ball, and a lightning wizard ball. Map discoveries and earned rewards should include both class-specific upgrades and general improvements.

The strongest stated reference for item combinations is **The Binding of Isaac's item philosophy**. Andrew also loves **Team Fortress 2's class diversity**, enjoyed **Mann vs. Machine co-op**, and loves **Gunfire Reborn** and dungeon crawlers whose level design fits their world. These references establish taste; exact item rules remain open, while the expedition structure is confirmed below.

Andrew specifically named **Brimstone and its combinations**, and **Mom's Knife as a high-damage skill-shot ability**, as memorable Isaac examples. The combat target includes satisfying aimed attacks as well as transformative loot. This does not yet settle charge timing, projectile behavior, attack automation or exact controls.

Andrew chose **solo first, with co-op explored later**. The first playable experience must stand on its own. TF2/MvM remain references for distinct class contributions, not a requirement to implement multiplayer now.

Andrew identified **Dungeon Defenders** as the reference for autonomous, thematic class infrastructure. Every class should deploy its own devices and engage with the environment. He explicitly prefers **mostly combat: quick tactical deployments made while moving**, rather than substantial preparation before a wave. Deployment is therefore an integral combat action within the themed expedition structure confirmed below.

Andrew enjoys **AI companions and infrastructure built on the fly**. Autonomous support is part of the desired play experience. He also wants enemies to have a fighting chance and gameplay to remain challenging and engaging.

Andrew clarified the desired companion impact: **prime enemies for damage or status effects, buff the player or eventual teammates, and intervene during clutch emergency moments**. Their value should be evident in combat. He chose to **find and assemble different companions from run loot, creating unusual combinations**. One main companion is confirmed; roster, detailed component rules and direct command controls remain open. Solo-first scope still applies.

Andrew explicitly prefers **low-cooldown abilities and ultimate moves that charge through class-specific mechanics**. Exact timings, charging rules and the ultimate abilities themselves remain design work.

The earlier interview proposed 30–45 minute themed expeditions. That duration is superseded by the [accepted notebook interview](#accepted-notebook-interview): four worlds and 60–75 minutes, with compact procedural levels and world bosses.

Between expeditions, **unlock new classes, items, companion parts and challenges; rebuild combat power during each run**. This settles the earlier question about permanent combat-stat progression.

Andrew selected **visible growth within mech scale, still fitting the designed routes**, then invoked **Gurren Lagann's increasingly enormous battles and destruction**. The coordinator's current interpretation is bounded physical growth with escalating enemy, environmental and destruction scale. Literal giant transformations or a different physical-growth rule remain exploratory; the anime reference has not automatically replaced the explicit route-scale answer.

Andrew asked the coordinator and subagents to concentrate on **market research that extracts useful patterns and produces an original direction**. The focused comparison and research-team record are in [MARKET-RESEARCH.md](MARKET-RESEARCH.md). At that research stage, gameplay implementation and a session goal remained later decisions. The subsequent authorization is recorded in the first-build scope above.

Andrew subsequently requested an **agent swarm to explore the game's conflict, enemy designs and variety, minibosses and major bosses, skill-based dodging, blocking/shield timing, vulnerabilities and immunity mechanics**. The first coordinated proposals are in [CONFLICT-AND-COMBAT.md](CONFLICT-AND-COMBAT.md), with a [team record](COMBAT-DESIGN-SWARM.md) and [enemy concept study](CONCEPT-STUDY-02.md). The Furnace Fleet conflict, its roster and a shared dodge/guard baseline are proposals. The desired defensive rhythm and a favorite boss encounter remain interview questions; requesting exploration did not approve a particular parry or immunity system.

Andrew then requested **boss-derived branching enemy taxonomies**, with the coordinator acting as PM and agents researching real references beyond video games. He wants enemy mechanics, appearance and environments grounded in believable physical and occupational details. [ENEMY-TAXONOMY.md](ENEMY-TAXONOMY.md) develops three proposed families through material processing, lifting machinery and orchard maintenance; [the taxonomy swarm record](ENEMY-TAXONOMY-SWARM.md) tracks completed research and review. The named lineages and expanded roster are design proposals, not committed production scope.

Four notebook photos, dated 21 August 2026 on the dated pages, are preserved without alteration in `docs/discovery/source-notes-2026-08-21/`. The source transcription and interpretation are in [HANDWRITTEN-NOTES.md](HANDWRITTEN-NOTES.md). They describe an earlier game concept; their specific roster and five-level structure are candidates for Scrapkeep rather than automatically accepted production scope.

Andrew authorized continued design work without routine confirmation and invited the coordinator to show notable results. The [orchard encounter study](ORCHARD-ENCOUNTER-STUDY.md) connects the enemy family to a concrete rolling/counter/collection sequence; the [visual study](CONCEPT-STUDY-03.md) records generated art and its limits. That request continued research and concept development. It did not itself select production scope or create a session goal. The later build authorization is separate and recorded above. The [design desk](DESIGN-INDEX.md) is the entry point to the growing project documents.

## Working design hypotheses

- Shared items can change the consequences of a class's signature action while preserving its recognizable controls. A grapple class should have a useful grapple before any lucky drop.
- Scavenging should visibly alter the machine. Collected parts can affect movement, attacks, and how the player controls a threatened space.
- The combination of piloting and items may be strongest when positioning determines where an exceptional build produces its best result.
- Themed areas should change encounters and traversal opportunities as well as scenery: crane anchors, elevated approaches, reflective structures, or conductive machinery are possible examples.
- A large world and a close camera create a defense-awareness problem. Clear threat communication and the ability to reposition need testing before committing to map scale.
- Enjoying MvM does not imply mandatory team roles, a required healer, or multiplayer in the first prototype.
- Class infrastructure should function autonomously after a quick deployment. Extra interaction with it should reward movement or a well-aimed attack without requiring routine babysitting.

These hypotheses are untested. No claim of player enjoyment, balance, commercial demand, or performance follows from the research.

### Working expedition flow

The [accepted notebook interview](#run-worlds-and-levels) owns the run structure. Level completion carries the build forward and creates the between-level save boundary. World completion offers two destination choices when another world remains. Item reward formats are separate decisions; a two-world offer does not prescribe two-item rewards. Device persistence across levels and recovery between encounters remain open.

### Example item exploration

**Echo Canister** is a proposed shared item whose class effect repeats at its original location after a delay. A grapple could leave a delayed pulling pulse at an anchor; a mortar could deliver a second impact; a laser could leave a beam afterimage; lightning could discharge again from its first conductor. This is an example for discussing Andrew's taste, not a finalized item or implementation contract.

Optional attack and movement replacements and earned dominance are accepted. Harmful item combinations need their own design; the chaos magician's accepted occasional failures do not settle every item tradeoff.

### Class infrastructure exploration

The requirement for autonomous, thematic infrastructure and combat-time deployment is confirmed. The examples and economy recommendation below are design proposals, not accepted ability specifications.

| Class        | Autonomous structure example                                                   | Optional player interaction                                                                         |
| ------------ | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Grapple      | A winch mast intermittently pulls light enemies away from a dangerous approach | Swing from the mast to wind up a stronger pull, combining repositioning with crowd control          |
| Hover mortar | A compact mortar nest bombards a nearby approach                               | An aimed airborne designation directs its next volley; baseline fire continues without instructions |
| Laser        | A prism sentry covers a narrow firing corridor                                 | Land a charged shot through its prism to redirect or split the player's attack around terrain       |
| Lightning    | Linked storm rods periodically discharge across the space between them         | Rolling past deposits charge; the class attack can discharge through the network                    |

The shared-item question now covers both the pilot's weapons and compatible deployed structures. For example, an Echo Canister could create a delayed repeat in the player's attack and in a structure's discharge, with different placement consequences. No exact eligibility, stacking or balance rules have been selected.

Coordinator recommendation: preserve the ball's accumulated size and personal arsenal when deploying basic infrastructure. Scavenging can also earn construction capacity, so growth expands the player's reach. Limit structures through deployment capacity, placement and timing. A detachable-weapon economy could be an optional later item or variant; imposing it on all deployment risks making building feel like a loss of earned growth. The specific resource, caps, lifetime, recall and placement rules remain undecided.

Quick deployment should suit the chosen combat emphasis. Avoid a required stationary building screen or routine reload/repair chores in the initial concept. Any aiming/preview interaction needs controller playtesting alongside mobility and the signature skill shot.

### Frequent abilities and earned ultimates

Confirmed direction: low-cooldown abilities and class-specific ultimate charging. The following table illustrates distinct combat rhythms; names, effects and triggers are proposals.

| Class        | Example useful actions that earn ultimate charge                                                     | Example ultimate payoff                                                                                         |
| ------------ | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Grapple      | Successful swing attacks, displacing threatening enemies, releasing stored winch energy into a group | Gather a temporary mass of scrap around the ball, then choose a powerful slingshot trajectory through the siege |
| Hover mortar | Well-placed airborne bombardments and successful designated nest volleys                             | Transform into a flying artillery platform with a brief period of expanded lift and coordinated bombardment     |
| Laser        | Piercing lined-up threats, hitting exposed weak points, or landing a redirected shot through a prism | Sustain a major cutting beam whose route can be shaped through the deployed prism setup                         |
| Lightning    | Effective multi-enemy chains and discharges through strategically placed conductors                  | Ride lightning between deployed rods, with each relocation triggering a network pulse                           |

The intended rhythm is frequent decisions followed by an earned change in play. Charge should reward useful class-specific contributions. Shared items may modify compatible attacks, autonomous devices and ultimate effects, so the run build remains relevant throughout. No numbers, timer model or detailed effect-composition rules are settled.

### Autonomous support and enemy counterplay

The companion behavior preference is now explicit. The examples below are coordinator proposals for expressing it:

| Desired contribution | Example behavior                                                             | Player opportunity                                                        |
| -------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Prime a target       | Apply a visible conductive mark to a threatening enemy                       | Land a signature attack to trigger a stronger effect or spread the status |
| Provide a buff       | Project a brief protective or offensive field during a committed attack      | Finish the charged shot or use the opening to reposition                  |
| Clutch intervention  | Intercept a charging enemy, deploy a decoy or create a short escape corridor | Recover through movement and a deliberate follow-up action                |

Recommended design emphasis: make the companion's contribution readable through animation, effects and reactions. A rescue should create a recoverable opportunity that the player can exploit. Its availability and recovery should be understandable so the player can learn to trust it while enemies remain threatening. Direct damage may be part of a companion's kit, but setup, support and intervention are the confirmed attractions.

Companions are acquired and assembled through run loot, as confirmed by Andrew. Item changes can alter their behaviors as part of the build, such as a rescue decoy leaving a status field or a priming effect spreading after a successful skill shot. The exact assembly process remains open.

One candidate is a small modular assembly: a found chassis supplies the form and movement, while additional loot changes its support behavior. For example, a hovering salvage drone could gain a conductive applicator that primes enemies and a rescue module that creates a brief escape corridor. This is a concept for discussing how literal assembly should be, not a chosen slot system or a promise of multiple full companion rosters. Class interactions could emerge from shared companions, such as using the same priming effect with either a laser skill shot or a lightning chain.

Coordinator recommendation: devices and companions should do useful work independently while creating opportunities for player intervention. Enemies should contest that support through readable behavior. These examples are proposed encounter designs, not implemented AI:

| Enemy example   | Pressure on the player's setup                                       | Opportunity for response                                       |
| --------------- | -------------------------------------------------------------------- | -------------------------------------------------------------- |
| Saboteur        | Approaches an exposed device and begins a visible dismantling action | Interrupt it, reposition the device or protect its approach    |
| Shield carrier  | Covers a group's advance from one direction                          | Flank, displace it or use the class's indirect attack geometry |
| Flanking raider | Takes an alternate approach to bypass concentrated fire              | Place a quick interception device or use mobility to intervene |

Enemy actions need visible commitments and understandable consequences. Challenge should come from choosing positions, targets and timing as well as enemy strength. Exceptional item combinations can still overwhelm familiar threats; harder encounters can introduce new behaviors and spatial demands. Earned dominance is accepted; specific enemy adaptation remains design work.

## Research findings and sources

### Design references

- [Edmund McMillen's original Isaac design explanation, 2011](https://edmundmcmillen.blogspot.com/2011/09/binding-of-isaac-gameplay-explained.html) describes items altering statistics, attacks, appearance and play, and rooms organized by chapter and difficulty. This is historical design intent, not a current Repentance interaction reference.
- [Valve's Two Cities material](https://www.teamfortress.com/twocities/rottenburg/) describes different MvM contributions such as Medic revival/shielding and Soldier direct-hit benefits. [MvM achievements](https://www.teamfortress.com/mvm/bounty/) also recognize displacement, team buffs and multi-target disruption. These illustrate contribution diversity without prescribing an optimal team.
- [Gunfire Reborn](https://store.steampowered.com/app/1217060/Gunfire_Reborn/) combines distinct heroes, random weapon rewards and themed procedural adventure stages. Andrew's preference makes it a central reference for further examination.
- [Original Dungeon Defenders](https://store.steampowered.com/app/65800/Dungeon_Defenders/) explicitly combines direct hero combat with class-specific defenses and basic attacks. Andrew adopts thematic class infrastructure as a reference while preferring quick deployments during combat. The reference does not establish a requirement to copy its preparation cadence, hero switching or multiplayer structure.

### Competitive set

| Reference                                                                                       | Why it matters                                                                                                                                            |
| ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Go Mecha Ball](https://store.steampowered.com/app/2008510/Go_Mecha_Ball/)                      | A close existing combination of rolling mechs, acrobatic movement and roguelite weapons/upgrades. A rolling mech alone cannot be the claimed distinction. |
| [Roboquest](https://store.steampowered.com/app/692890/Roboquest/)                               | Responsive movement, class-specific upgrade choices and synergies.                                                                                        |
| [Risk of Rain 2](https://store.steampowered.com/app/632360/Risk_of_Rain_2/)                     | Third-person character mastery and escalating item interactions.                                                                                          |
| [Orcs Must Die! Deathtrap](https://store.steampowered.com/app/2273980/Orcs_Must_Die_Deathtrap/) | Close-camera action, class powers, traps and roguelite defense.                                                                                           |
| [The Riftbreaker](https://store.steampowered.com/app/780310/The_Riftbreaker/)                   | The relationship between mecha combat, exploration and defending an expanding base.                                                                       |
| [Dungeon Defenders](https://store.steampowered.com/app/65800/Dungeon_Defenders/)                | Class identity across both direct combat and autonomous infrastructure; a central publisher reference.                                                    |

The initial price comparison found displayed dollar prices of $19.99 for Gunfire Reborn, $24.99 each for Roboquest and Risk of Rain 2, and $29.99 for Deathtrap on 5 September 2026. These are storefront observations, not a recommended Scrapkeep price. No sales or revenue estimate was established.

A research lead inspected a purposive sample of 28 English Steam reviews across Roboquest, Risk of Rain 2 and Deathtrap. The sample mixed selected positive/negative and recent reviews, with one older Roboquest review. It surfaced questions about progression grind, constrained builds, readability and co-op reliability. It is not representative and does not establish how common the issues are or whether historical defects remain. Valve/Steam reviews are player reports, not verified reproductions.

[Robot Entertainment's January 2025 patch explanation](https://robotentertainment.com/news-archive/2025/1/31/patch-107) explicitly addresses limited map control for smaller groups. For Scrapkeep, the corresponding research question is whether a solo pilot can influence enough of a battlefield while using enjoyable traversal.

## Technical and visual direction under consideration

At the research baseline, the original yard rendered in 3D with planar movement and collision, a fixed orthographic camera, and visible height derived from radius and bounce. Those descriptions still apply to that baseline. The later orchard proof adds a chase camera, ground-following terrace height, and articulated machine poses. Free vertical traversal and a complete imported character-animation system remain outside the proof.

The technology lead resolved and queried Context7 libraries `/mrdoob/three.js` and `/websites/godotengine_en_stable`. Documentation supports possible collision/movement/import approaches; it does not prove a working controller or performance in this game.

The first proof stays in Three.js to preserve the JavaScript game and browser delivery. The engine decision for a larger native production remains open. Godot was identified during research as a candidate with character movement, spring-arm camera collision, and scene import, at the cost of porting existing systems.

Free/open-source candidates include [Godot](https://godotengine.org/license/), [Three.js](https://github.com/mrdoob/three.js/blob/dev/LICENSE), [Blender](https://www.blender.org/about/license/), [Krita](https://krita.org/en/about/license/) and [Audacity](https://www.audacityteam.org/). [Kenney asset pages](https://kenney.nl/support) and [Poly Haven assets](https://polyhaven.com/license) offer CC0 source material. Individual assets and optional model dependencies still need checking when selected.

Built-in image generation is available for concept development, but is not an open-source tool. Local generative workflows are candidates rather than an adopted dependency. Raster art and generated video do not constitute production meshes, rigs or game animation clips.

The proposed art workflow is concept image and paintover, model/rig/pivot authoring in Blender, animation authoring, then import and verification in the chosen runtime. The [first image study](../public/art/03-industrial-dungeon-study.png) is complete and visually inspected. It explores an enclosed animal cockpit, close chase camera and an industrial dungeon while retaining the current cream/orange/mint palette. The [prompt and inspection notes](CONCEPT-STUDY-01.md) are preserved. Following the Katamari clarification, the coordinator judges this study too orderly and manufactured: future studies should make the accumulated, irregular scrap mass and physical rolling character more prominent. The image does not settle level topology, species or final art direction and is not evidence of runtime performance or gameplay.

## Historical research team record

This table describes the earlier research pass, not the later build verification. The [first-build team record](FIRST-BUILD-SWARM.md) tracks implementation and review.

All delegated roles used `gpt-6-astra` at high reasoning effort.

| Lead               | Completed work                                                                                  | Evidence limit                                                      |
| ------------------ | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Combat and camera  | Source inspection, movement/action-defense references, 28-review player-response sample         | No live movement prototype or representative player survey          |
| Classes and world  | Class/loot concepts, world alternatives, Isaac/TF2 follow-up, and infrastructure economy review | Concepts and source interpretation; balance untested                |
| Technology and art | Architecture inspection, Context7 queries, free-tool shortlist                                  | No engine migration, imported animation or performance verification |
| Coordinator        | Publisher interview, competition synthesis, visual study and this record                        | Discovery remains open                                              |

## Remaining design decisions

Settled choices are recorded in the [decision register](project/DECISION-REGISTER.md); they should not be asked again without a new reason. The following work remains:

1. World catalogue, repeat rules, first-world selection, final-boss placement, level counts and the procedural generation technique.
2. Tree shapes, costs and milestone allocation; special respec presentation; fixed secret recipes and discovery feedback.
3. Revival health and placement, unfinished-level interruption behavior, checkpoint persistence and profile migration.
4. Chaos element/effect pool, failure frequency and severity, and its relationship to the proposed roster and implemented lightning kit.
5. Device persistence and recall, detailed companion assembly and commands, harmful item tradeoffs, and the terrain effects of exceptional transformations.

The lightning playtest remains the active product task. The notebook interview authorizes design alignment; later gameplay implementation needs a bounded scope of its own.
