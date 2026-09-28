# Whole-game visual coverage inventory

This is a content inventory for concept development, not an execution board. The three initial treatments cover one composition only. Every row below still needs selected-style concept coverage; existing images are references, not automatic acceptance. Runtime acceptance additionally needs matching captures, motion and Andrew's play.

Sources are pinned in [source-manifest.json](source-manifest.json). Bible regions and candidate characters do not become a launch roster through inclusion here. Later sketch decisions control the current demo. The hero sphere and Warden draft include both owner requests and unselected elaboration; keep those separate.

## World and terrain

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| W01 | Yard Commons | Establishing view and banked settlement approach; Sonoran washes, repairs and lived-in community | Bible §3 |
| W02 | Spillway Works | River gorge, green corridor, dry bypass, water machinery; close gameplay view and broad landscape | Bible §3; DESIGN-V2 §8, §15 |
| W03 | Iron Orchard | Cultivated upland valley, irrigation and turning space; living plants dominate the machinery | Bible §3 |
| W04 | Foundry Crown | Forest-to-ridge transition, cableways and supported metalworking terraces | Bible §3 |
| W05 | Pale Basin | Dry pale mineral dunes, buried machinery and maintained service strips, visibly not snow | Bible §3 |
| W06 | Three demo stages | Spillway top shelf, Sluice and Weir; entry, landmark, encounter and exit sightlines | stage_defs.gd; DESIGN-V2 §14 |
| W07 | Vertical gorge layers | Undercroft, shelf and sky layer, with understandable connections and preserved momentum | I3-vertical-stage.md |
| W08 | Terrain-changing events | Before, warning, change and aftermath; readable new collider and continuous safe exit | DESIGN-V2 §9; event definitions |
| W09 | Environment material/light sheet | Dry rock, wet stone, water, foliage, metal, glass; representative sun and shade | Art lock AD-02 to AD-06 |

## Ball culture and everyday life

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| C01 | Rolling settlements | Banked streets, halfpipe plazas, useful scale and unblocked routes | DESIGN-V2 §15 |
| C02 | Nomadic camps | Packed, deployed and inhabited states; build-up/tear-down leaves physical traces | DESIGN-V2 §15 |
| C03 | Public transport | Cannons, trebuchets and launch chutes; boarding, launch direction and landing are obvious | DESIGN-V2 §15 |
| C04 | Contraptions | Lifts, valves, launchers and moving platforms; idle, available, operating and failed states | DESIGN-V2 §9; I3 |
| C05 | Cultural construction | Enclave, roost and workshop traditions expressed in supports, repairs and equipment | Bible §2; DESIGN-V2 §15 |
| C06 | Domestic objects | Work benches, storage, mugs, plants, signs and useful repairs at ball scale | Bible §2; Moss brief |

## Pilots and player machinery

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| H01 | Shared sphere and gyro | Front, side, rear, chase and cutaway; enclosure, pilot, cradle, working intake and ring clearance | Owner quote in HERO-SPHERE opening |
| H02 | Sable | Fox silhouette, mint ring language, grapple/winch/pylon hardware; idle and action views | class_def.gd; DESIGN-V2 §2 |
| H03 | Rivet | Mole silhouette, copper chevrons, laser and unstoppable sprint hardware | class_def.gd; DESIGN-V2 §2 |
| H04 | Kest | Bird silhouette, amber starbursts, explosive mechanisms and action states; right-click smoke blink and Space-held falling glide both shown | class_def.gd; DESIGN-V2 §2 |
| H05 | Growth and fabrication | Low/high build comparison plus attraction → intake → processing → functional change | AD-05; owner sphere request; growth proposal unselected |
| H06 | Player motion sheet | Idle, rolling, turn, airborne, boost, smash, hit, gyro jam and recovery; camera stays comfortable | DESIGN-V2 §15; HERO-SPHERE proposal |
| H07 | Alternate roster concepts | Tarn, Fuse and other Bible candidates; friendly ancient/transmog request with unselected identity details labeled | Bible §4; paused-session owner request |
| H08 | Small-scale readability | Pilot and working tool at actual chase distance and full growth; glass and effects must not bury either | PD-01; AD-11 |

## Hostiles and bosses

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| E01 | Faction construction | Bolted rust-red Fleet with brass tags versus cast petrol ancients with charcoal-grooved blue seams | VISUAL-LANGUAGE; DESIGN-V2 §11 |
| E02 | Existing core enemies | Chaser, lobber and miniboss: silhouette, telegraph, attack and recoverable weak state | roster.gd |
| E03 | Fleet control tools | Mag trapper, hooker, netcaster and bola thrower; tool and counterplay distinguish each | roster.gd |
| E04 | Fleet reinforcement tools | Plated brute, deflector and winch drone; distinct function, not recolors | roster.gd |
| E05 | Anti-ball tools | Gyro jammer, swatter, ramp-flipper and catch-trap; warning, hold/knock and break-free | roster.gd; DESIGN-V2 §15 |
| E06 | Ancient families | Reactor relic, swarm remnant and Mind's hand; radically different construction and attack behavior | roster.gd; DESIGN-V2 §10 |
| E07 | Three Wardens | Reactor, hive and Mind family; approach, charge, attack, weakness, damage and break | DESIGN-V2 §11; WARDEN-DESIGN proposal |
| E08 | Brindle | Fleet captain and Requisition; readable phases, reverse callbacks, routed outcome | DESIGN-V2 §14-15; STORY-THREADS |

## Scrap, loot and progression

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| P01 | Magnetic collection | Loose scrap and visible path into an intake, motion storyboard with beginning and endpoint | AD-05; PD-01 |
| P02 | Build-changing parts | Weapon, mobility, special and smash hardware before/after; changed function is visible | DESIGN-V2; I2-item-generator |
| P03 | Rewards and rarity | Diamond rewards, gates, cores, rare_plus notched frame; no danger-color collision | VISUAL-LANGUAGE; DESIGN-V2 §11 |
| P04 | Shop and progression | Two-choice branches, four picks, mastery variants and heft-locked shelf; at-a-glance choice consequences | DESIGN-V2 §12, §15; PROGRESSION |
| P05 | Synergy and discovery | Recognizable part relationships and codex clues; reward comprehension without a text flood | PROGRESSION; I2 |

## Combat, movement and effects

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| F01 | Four threat types | Instant, wave, projectile and lane in quiet and overlapping states; same damage geometry | threat_grammar.gd |
| F02 | Skill-shot sequence | Hold, gauge, release, travel and impact; preview and outcome agree | DESIGN-V2 §4 |
| F03 | Contact and movement | Rebound, crush, wall vault, grapple, sprint and class action cues | DESIGN-V2 §3; class data |
| F04 | Status and recovery | Hit, stun/hold, tenacity, break-free and cloak; show player agency and timing | DESIGN-V2 §10, §15 |
| F05 | Dense combat | Grown player, multiple threats, projectiles, pickups, dust and sparks; threats and exits remain readable | AD-11; TH-16 |
| F06 | Effect material sheet | Mint, copper, amber, hostile red-orange and ancient blue at game distance, with shape/value redundancy | Shared palette, class and event rows |

## Interface and transitions

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| U01 | Title and character select | Scene, focal action, pilot differences and a clear start; workshop instrumentation | DESIGN-V2 §14; primer |
| U02 | Live HUD and controls | Health, growth, charges, aim, objective and contextual keys; at most 25 fight words | DESIGN-V2 §14; VISUAL-LANGUAGE |
| U03 | Workshop choices | Mouse/keyboard focus, branch comparison, purchase and unavailable states | DESIGN-V2 §12, §15 |
| U04 | Codex and mastery | Discovery, locked/unlocked variant and next-run timing | PROGRESSION |
| U05 | Pause, settings and help | Readable hierarchy, focus, return-to-play and reduced-motion presentation | DESIGN-V2 §14; existing UI states |
| U06 | Defeat, victory, results, restart | Outcome, gained knowledge and immediate restart; final Cherenkov callback | DESIGN-V2 §14-15 |
| U07 | Screen transitions | Entry, departure, focus handoff and interrupted transitions; timings serve the action | VISUAL-LANGUAGE; SOUND-STORY |

## Quiet moments, sound and animation

| ID | Subject | Required views and what they must communicate | Source |
| --- | --- | --- | --- |
| Q01 | Moss's bay | Unseen keeper, voice/hands, lounge, useful shelf, welcoming pit-stop scale | DESIGN-V2 §12, §15; SOUND-STORY §8 |
| Q02 | Practice and fidgets | Practice yard, marble-run toy, bell and jukebox; optional interactions and clear exit | DESIGN-V2 §15 |
| Q03 | Narrative callbacks | Ancient traces, Fleet identity, small comforts and repeated objects that change meaning | STORY-THREADS; Bible §2 |
| Q04 | Music and event timing | Storyboards linked to existing cues and music motifs; retain MUSIC-GEMS | SOUND-STORY; MUSIC-GEMS |
| Q05 | Motion and comfort | Pilot anticipation/reaction, smooth camera, reduced effects and legible recovery | AD-08/11; existing settings contract |

## Coverage rule

A sheet may cover several rows when each subject and required state is identifiable. It cannot close a motion row without a storyboard and later a clip. Every row records its selected reference, critique, largest implementation discrepancy and evidence when produced. A completed concept row is not a implemented feature. The initial A/B/C comparison contributes a treatment study to W02, H01 and E07; it closes none of those categories by itself.
