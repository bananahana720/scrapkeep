# Scrapkeep campaign enemy roster

5 September 2026. This document is the proposed complete enemy roster for the five-rung first campaign and the two expansion rungs, written as data-ready design for the planned enemy descriptor registry. Everything here is a proposal pending Andrew's approval unless it cites an implemented file. It builds on the working canon of the 5 September audit ([DESIGN-AUDIT.md](DESIGN-AUDIT.md)), which is itself recommended direction, not committed scope.

## How to read this roster

Every enemy passes the seven-field admission grammar from the combat paper: telegraph, commitment, locked geometry, recovery window, weak point, counter reward, contested resource (audit-2026-09-05/worker-2-combat.md:125-133). No enemy ships with an empty cell. Every attack carries exactly one deflect grade (worker-2-combat.md:44-47):

- **Deflectable (D).** Gapped, segmented stroke rendering plus a light rattle. Roll-Through at burst speed converts the hit to chip damage.
- **Heavy (H).** Solid, ground-coupled rendering plus a thud cue. Spacing is the only answer. Every heavy attack keeps a pure-spacing exit (worker-2-combat.md:135).
- **Grab (G).** Open jaws or a cast line oriented across a lane. Bursting through is the trap. Break range, break the coupling, or interrupt the windup.

Numbers are tuning sketches in the form hp / damage / windup s / active s / recovery s, relative to the implemented baselines in `src/orchard/simulation.js`:

| Baseline | hp | damage | windup | active | recovery | source |
| --- | --- | --- | --- | --- | --- | --- |
| Snipcart | 90 | 17 | 1.15 | 0.48 | 1.85 | sim.js:9-21 |
| Spreadleg | 115 | 20 | 1.3 | 0.7 | 2.0 | sim.js:22-34 |
| Pruner arm | 640 | 27 | 1.75 | 0.8 | 2.7 | sim.js:35-47 |

Two admission rules are load bearing and never bend: recovery is at least as long as active (worker-2-combat.md:130), and no damaging windup drops below 1.0 s at any rung (worker-2-combat.md:127, "visible windup >= ~1 s"). Weak points stay reachable by ground route at radius 1.65 (worker-2-combat.md:135). Counters pay 2.1x plus a physical drop once per attack cycle (sim.js multipliers cited at worker-2-combat.md:5).

Occupational grounding follows the taxonomy's rule 2: the machine's job must explain its location (ENEMY-TAXONOMY.md:16). Real-machinery references for the three existing families are already cited in the taxonomy reference tables (ENEMY-TAXONOMY.md:61-69, 108-117, 157-165); this pass reuses them and did no new web research. Groundings for new enemies are labeled inference from common machinery and need one reference pass before build.

## Campaign shape

The first campaign is Yard Commons, Spillway Works, Iron Orchard, Foundry Crown, Furnace City, with Windworks and Harvest Roads held as expansion rungs (audit-2026-09-05/worker-4-universe.md:58-70; DESIGN-AUDIT.md:67). Each rung fields 4-6 workers, one miniboss, one boss. All fifteen taxonomy workers, all six veterans, all three minibosses and all three family roots are reused with their names kept (ENEMY-TAXONOMY.md:212). New designs fill only Yard Commons, Furnace City and the two expansion rungs, plus one new spillway saboteur.

Roster totals in this proposal: 34 distinct workers-and-support designs across seven rungs (21 reused or reprised, 13 new), 7 minibosses (3 reused, 4 new), 7 bosses (3 reused roots, 4 new).

## Rung 1: Yard Commons (proposal)

Municipal salvage collection. Curbed maze lanes and low retaining walls; the destruction beat is tipping one loaded gantry (worker-4-universe.md:60). This rung teaches all three deflect grades one at a time. Only one worker may be in windup at once here, matching the implemented stagger (worker-2-combat.md:5).

| Enemy and occupation | Telegraph and commitment | Locked geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Scooplet** (reused, ENEMY-TAXONOMY.md:49). Curbside scrap collector. | Teeth lower, chain tightens; commits to a floor lane before lifting to unload. Yaw locks at windup start. | Straight rake lane, width ~0.65 (D). | Unload pause; basket latch on the flank. | Spilled load plus scrap; contests every loose pickup on the ground. | 75 / 14 / 1.15 / 0.6 / 1.9 (0.83x Snip hp) |
| **Binbug** (new). Wheelie-bin scuttler that swallows loose scrap. Grounding: municipal wheeled bins; inference. | Lid rattles open 1.0 s before a short nip. Commits to one hop line. | Lid-snap capsule, reach ~1.2 (D). | Long topple wobble; underside casters. | Bowling through releases everything it swallowed; contests loose scrap directly. | 28 / 8 / 1.0 / 0.3 / 1.6 (0.31x Snip hp; speed 2.4 vs Snip 1.7, sim.js:12) |
| **Curbsweep** (new). Rotary-brush street sweeper. Grounding: municipal sweeper brushes; inference. | Brushes spin up with a rising whir; commits along the curb line it faces. | Brush arc, width ~0.8 (D); its scrap-pile shove is damage-free displacement. | Hopper-dump pause; hopper hinge on the rear quarter. | Brush segment component; contests scrap by sweeping it into enemy-held piles. | 95 / 15 / 1.2 / 0.7 / 1.9 (~Snip hp) |
| **Mowling** (new). Gang-reel verge mower. Grounding: reel gang mowers; inference. | Reels drop and chatter; front weights plant; commits one straight pass. | Full-width reel line, ground-coupled (H). First heavy lesson. | Long turnaround at pass end; exposed reel linkage on either side. | Reel blade component; contests the verge lanes where scrap collects. | 110 / 21 / 1.5 / 0.8 / 2.2 (~Spreadleg hp) |
| **Bootjack** (new). Wheel-clamp cart, the yard saboteur. Grounding: vehicle wheel clamps; inference. | Marks one deployed device, approaches, ratchet knocks before closure. | Clamp jaws across the device (G); crossing the jaws mid-closure is the grab. | Slow tightening stint; tipping window on its narrow side. | Clamp module; contests deployed devices, which stay visible and recoverable (matches Clampcart rule, CONFLICT-AND-COMBAT.md:39). | 80 / 16 on grab / 1.4 / 0.5 / 2.4 |
| **Gateling** (new). Barrier-panel barrow, the yard shield carrier. Grounding: temporary crowd barriers; inference. | Panel tilts forward before a planting shove; commits to the plant spot. | Short shove capsule (D); planted panel is a directional shield per the protection table (CONFLICT-AND-COMBAT.md:130). | Anchoring stint after planting; exposed grip arms behind the panel. | The panel detaches as collectible cover; contests approach lanes for the enemies behind it. | 130 / 12 / 1.2 / 0.4 / 2.0 |

**Miniboss: Glassjaw (proposal, name reused from the demo).** The demo's Cancrusher, Glassjaw and Old Ironroot labels are preserved in its files and flagged for reconciliation (ENEMY-TAXONOMY.md:179). Proposal: Glassjaw becomes the Yard Commons miniboss, a municipal glass-and-can jaw baler. Attacks: jaw crunch at the mouth (G, 24 dmg, windup 1.5), ejected bale that rolls a previewed lane like the implemented offcut (H, 22 dmg; offcut precedent at worker-2-combat.md:129), side rake (D, 16 dmg). Recovery after the bale eject exposes the ram guide, the ram-and-shoot weak point. Reward: **Jawplate**, a front contact plate that improves deliberate head-on bumps. Numbers 320 / as listed / 1.3-1.6 windups / 2.2-2.6 recoveries (0.5x Pruner hp). It teaches that one machine can carry all three grades.

**Boss: Old Ironroot (proposal, name reused from the demo).** The commons' ancient anchor derrick, iron footings grown into the yard. Arena: the curbed maze under its boom, with the loaded gantry from the rung's destruction beat (worker-4-universe.md:60) as the tippable set piece.

- Phase 1. Boom sweep (D, 18 dmg, windup 1.75 matching the Pruner arm, sim.js:42) plus Scooplet adds. Weak point: winch housing during sweep recovery.
- Phase 2, named escalation **Double pendulum**. After the boom stops, the hook load swings one further announced arc (H, 26 dmg); shadow previews the arc, matching the Bellhanger grammar (ENEMY-TAXONOMY.md:98). Tipping the loaded gantry into the wall crushes a footing and opens a new lane.
- Phase 3, named escalation **Root heave**. Anchor roots tear up flagstone lines previewed as raised seams (H, 24 dmg). One footing at a time fails; broken footings stay broken, matching the boss rule that removed structure never repairs (ENEMY-TAXONOMY.md:155).

Numbers 520 hp (0.8x Pruner) since it is the first boss. Contested resource: the gantry load itself, collectible after the tip.

## Rung 2: Spillway Works (proposal, family reused)

Wastewater screening and compaction. The Cancrusher family transfers whole: Scooplet, Rackspan, Crossbelly, Rinsebelly, Pressling, veterans Tandem Scooplet and Relay Crossbelly, miniboss Sluiceback, boss The Cancrusher (ENEMY-TAXONOMY.md:26-71). Admission rows below compress the taxonomy tables; jobs, tells and counters are quoted from ENEMY-TAXONOMY.md:49-53. One new saboteur is added because the family lacked device pressure.

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Scooplet** (ENEMY-TAXONOMY.md:49) | As rung 1; commits to a floor lane. | Rake lane (D). | Unload; basket latch. | Rake Comb salvage; contests dropped cargo. | 82 / 15 / 1.15 / 0.6 / 1.9 |
| **Rackspan** (ENEMY-TAXONOMY.md:50) | Comb descends, one shoulder tilts, then the load rises. Side chosen at tilt. | Descending comb bar (D); the raised boundary is damage-free geometry. | Dump stroke; drive cover on the guide housing. | Guide Roller salvage; contests crossing routes by walling them. | 120 / 16 / 1.25 / 0.6 / 2.0 |
| **Crossbelly** (ENEMY-TAXONOMY.md:51) | Cargo visibly travels toward the discharge edge. | Discharge shove (D, weak); mostly a logistics target. | Continuous; cassette mounting latch. | Crossbelt Catcher salvage; contests salvage by rerouting it to enemy destinations. | 100 / 12 / 1.2 / 0.5 / 1.9 |
| **Rinsebelly** (ENEMY-TAXONOMY.md:52) | Fill, agitate, drain states visible through the water slit. | Compressed wet plug rolls a lane (H). | Drainage interval; screw housing side. | Drain Basket salvage; contests pickups displaced by shoves. | 140 / 22 / 1.6 / 0.7 / 2.3 |
| **Pressling** (ENEMY-TAXONOMY.md:53) | Feet plant, loading cheeks stop, then one straight stroke. | Compression stroke between cheeks (H). | Retraction; side guide cover. | Press Shoe salvage; contests a lane by closing it. | 125 / 23 / 1.5 / 0.5 / 2.4 |
| **Jettling** (new saboteur) | Lays a visible hose, couples, dribble then jet. Lane fixed at coupling. | High-pressure jet lane (H, continuous); pushes deployed devices toward drains. Grounding: sewer-jetting carts; inference. | Recoupling; rear hose coupling, same grammar as Flushpot (ENEMY-TAXONOMY.md:145). | Nozzle component; contests deployed devices and companion routes. | 85 / 15 / 1.4 / 1.2 / 2.0 |

**Miniboss: Sluiceback** (reused; ENEMY-TAXONOMY.md:57, CONFLICT-AND-COMBAT.md:48-56). Braced charge across a banked basin (H, 26 dmg, windup 1.7, skid recovery 2.6), brace plant (D, 14 dmg), second charge only after a separate visible preparation. Plates stay removed. Reward Valve Wheel. Numbers 380 hp. This is also the designated basin experiment for the deflect economy (DESIGN-AUDIT.md:85; worker-2-combat.md:173).

**Boss: The Cancrusher** (reused root; ENEMY-TAXONOMY.md:59). Arena: the intake-to-press stream. Consequence beat: bursting a sluice gate drains a basin mid-fight and reroutes everyone (worker-4-universe.md:61).

- Phase 1. Guided rake lanes (D, 18 dmg), one at a time; housings take ordinary damage.
- Phase 2, named escalation **Full stream**. Two subsystems preview at once: the crossbelt intake (G, 20 dmg plus displacement toward the press) runs while a rake sweeps. Breaking the sluice gate here drains the basin and permanently removes one rake lane.
- Phase 3, named escalation **Choke press**. The press axis extends into the arena (H, 30 dmg); surviving rakes gain visible bracing and upgrade to heavy, the veteran grade-shift taught mid-fight (worker-2-combat.md:47). Broken subsystems never return (ENEMY-TAXONOMY.md:59).

Numbers 900 hp (1.4x Pruner). Proposed Sorting Heart reward stands (ENEMY-TAXONOMY.md:59).

## Rung 3: Iron Orchard (proposal, family reused, two workers implemented)

Horticulture under Fleet override. Snipcart and Spreadleg are implemented at the cited baselines (sim.js:9-34); Flushpot, Discback, Graftmender complete the workers, with veterans Double-cut Snipcart and Switchback Flushpot, miniboss Rowkeeper, boss The Grand Pruner (ENEMY-TAXONOMY.md:120-155).

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Snipcart** (implemented) | Jaws spread, elbow straightens; yaw locks at windup (worker-2-combat.md:127-128). | Inward shear arcs (D; worker-2-combat.md:129). | 1.85 s; right-side housing. | Shear Linkage salvage; contests lane gaps by closing them. | 90 / 17 / 1.15 / 0.48 / 1.85 (sim.js:9-21) |
| **Spreadleg** (implemented) | Feet turn outward, ratchets chatter. | Outward foot arcs (D). | 2.0 s; ankle side. | Adjustable Brace salvage; contests the center lane by opening it under threat. | 115 / 20 / 1.3 / 0.7 / 2.0 (sim.js:22-34) |
| **Flushpot** (ENEMY-TAXONOMY.md:145) | Coupling, valve flag, dribble before discharge. Lane fixed. | Flush lane (H, continuous). | Post-discharge; rear coupling. | Diverter Valve salvage; contests row lanes. | 105 / 18 / 1.4 / 1.0 / 2.1 |
| **Discback** (ENEMY-TAXONOMY.md:146) | Stack rises, drain turns before a frontal flush. | Frontal flush (H); compressed rings are directional armor with a service opening. | Ring separation; spindle. | Ring Plates salvage; contests the head-station approach. | 130 / 20 / 1.5 / 0.7 / 2.2 |
| **Graftmender** (ENEMY-TAXONOMY.md:147) | Aligns sockets, attaches a visible lead to an uncollected module. | No damaging stroke; the lead is the interrupt target. | Continuous bench work; workbench alignment. | Alignment Reel salvage; contests uncollected enemy modules, racing the player's collection. | 70 / 0 / n-a (interruptible cast 1.6 s) / n-a / 2.0. The n-a attack cells carry this written justification per the admission rule (worker-2-combat.md:123). |

**Miniboss: Rowkeeper** (reused; ENEMY-TAXONOMY.md:151). Spread press (D, 20 dmg) and separately announced flush discharge (H, 24 dmg); the middle escape always fits the largest normal ball. Broken subsystems stay disabled. Reward Service Yoke. Numbers 420 hp.

**Boss: The Grand Pruner** (reused root; ENEMY-TAXONOMY.md:153-155). Arena: terraces around the seedhouse. Consequence beat: folding a house-sized pruning arm into a ramp (worker-4-universe.md:62).

- Phase 1. Single terrace sweep per the implemented arm (H, 27 dmg, windup 1.75, recovery 2.7; sim.js:35-47) plus announced offcuts (H).
- Phase 2, named escalation **Spool winding**. The binding reel visibly winds, identifying the next committed arm (ENEMY-TAXONOMY.md:153); irrigation surge lanes preview through ripples (CONFLICT-AND-COMBAT.md:86). Interrupting the spool latch cancels the preparation.
- Phase 3, named escalation **Terrace shear**. Two arms alternate on separate terraces with offcut crossfire; every folded arm is a ramp toward the seedhouse weak point. Removed arms never rebuild (ENEMY-TAXONOMY.md:153).

Numbers: each arm at the implemented 640; three arms plus a 400 hp core. Graft Spool reward stands (CONFLICT-AND-COMBAT.md:90).

## Rung 4: Foundry Crown (proposal, family reused)

Foundry lifting and dispatch. Pegjack, Reelrat, Bellhanger, Brakebogie, Clampcart, veterans Forkguide Pegjack and Shieldload Clampcart, miniboss Yardmaster, boss Counterweight Crown (ENEMY-TAXONOMY.md:73-118). Brakebogie's admission row is already worked as the template example (worker-2-combat.md:125-133).

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Pegjack** (ENEMY-TAXONOMY.md:96) | Feet spread, cable lifts along a marked strip. | Tensioned cable line (H, static hazard); foot stomp (D, 14). | Post-tension; guide latch. | Guide Wheel salvage; contests routes by dividing them. | 100 / 18 line, 14 stomp / 1.3 / 0.6 / 2.0 |
| **Reelrat** (ENEMY-TAXONOMY.md:97) | Slow snare cast, drum stops paying out, braces, pulls once. | Snare (G; grab family per worker-2-combat.md:46); the single pull (H, 20). | Post-pull; oversized coupling. | Return Reel salvage; contests whatever its line attaches to, devices included. | 110 / 20 / 1.5 / 0.6 / 2.2 |
| **Bellhanger** (ENEMY-TAXONOMY.md:98) | Rear weight moves; cradle shadow describes the arc. | Cradle arc (D; confirmed gapped in the worked playthrough, worker-2-combat.md:160). | Planted frame; tilt latch. | Swing Yoke salvage; contests the apron space under its arc. | 150 / 20 / 1.5 / 0.7 / 2.3 |
| **Brakebogie** (ENEMY-TAXONOMY.md:99; row at worker-2-combat.md:125-133) | Plates shift, route flag moves, brake releases. | Own hull on rails (H, only on the marked line). | Braked at the stop, 2.2 s; stack latch drops a ballast plate. | Ballast plate becomes bank surface plus mass; contests its hauled cargo, intercept or let pass. | 160 / 24 / 1.4 flag interval / travel / 2.2 |
| **Clampcart** (ENEMY-TAXONOMY.md:100) | Marks one deployed device, sequential closing knocks. | Jaw closure (G, 18). | Tilt-and-retreat; hinge release. | Hinged Grip salvage; contests deployed devices, recoverable after capture. | 120 / 18 / 1.4 / 0.5 / 2.2 |

**Miniboss: Yardmaster** (reused; ENEMY-TAXONOMY.md:104). Brakebogie travel cues (H on the line), then Bellhanger sweep (D, 24). Bait the swing and ram the stationary carriage, or shoot the latch to dump the load. Removed ballast shortens later sweeps. Reward Travel Yoke. Numbers 480 hp.

**Boss: Counterweight Crown** (reused root; ENEMY-TAXONOMY.md:106; CONFLICT-AND-COMBAT.md:68-78). Arena: the crane aisle with three counterweight carriages on a curved track. Consequence beat: the furnace hammer craters the arena and wrecks become bank angles (worker-4-universe.md:63).

- Phase 1. Carriage interception at bends (H on the line, 24 dmg); latches take ordinary damage.
- Phase 2, named escalation **Bell and hook**. Bell, descending hook and a persistent footprint announce the hammer (H, 34 dmg, windup 1.9); a debris wave follows, blocked by bulkheads (CONFLICT-AND-COMBAT.md:74). The relay choice opens: divert a slow strike or attack another carriage.
- Phase 3, named escalation **Stop and switch**. Track direction visibly reverses with one carriage left (CONFLICT-AND-COMBAT.md:76); hook gains a cable-snatch (G) over the crater field; wrecks are the new banks.

Numbers 1100 hp. Counterweight Heart reward stands (CONFLICT-AND-COMBAT.md:78).

## Rung 5: Furnace City (proposal, new plus overseer reprises)

The Fleet flagship: every family's overseer variants plus city-scale engine works, Brindle's seat (worker-4-universe.md:66). The rung's worker mix is three new city natives plus the six taxonomy veterans appearing in Fleet overseer livery (Tandem Scooplet, Relay Crossbelly, Forkguide Pegjack, Shieldload Clampcart, Double-cut Snipcart, Switchback Flushpot; ENEMY-TAXONOMY.md:55, 102, 149). Reprises count as returning designs, not new species.

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Stokerling** (new). Firebox stoker. Grounding: boiler stoking shovels; inference. | Shovel dips into a clinker cart, glow builds, lob arc previews as a landing ring. | Lobbed clinker splash (H, area), mirroring the mortar's landing-ring grammar (worker-2-combat.md:94). | Reload at the cart; shovel pivot. | Clinker becomes brief hazard then collectible slag; contests floor space. | 130 / 22 / 1.6 / 0.6 / 2.3 |
| **Beltwarden** (new). Conveyor-street switchman. Grounding: belt-conveyor transfer stations; inference. | Lever throw posture before a street section reverses; wrench swing up close. | Wrench swing (D, 16); belt reversal is damage-free geometry that carries enemies in and the player out. | Post-throw; the switch cabinet it must return to. | Switch handle component; contests the floor's direction itself. | 115 / 16 / 1.2 / 0.5 / 2.0 |
| **Requisitioner** (new). Override-bolt applicator crew, the premise made into an enemy (Requisition premise, DESIGN-AUDIT.md:45). | Raises the bolt driver, marks one deployed device or companion, three driver knocks. | Bolt drive on the mark (G against devices and companions); a snapped bolt shot at the player (D, 14). | Driver rewind; magazine on its back. | The Override Bolt itself, a Scrapbook-worthy salvage; contests devices and companions by conscripting them until the bolt is popped. | 95 / 14 / 1.4 / 0.5 / 2.2 |

**Miniboss: Quartermaster (new).** The requisition depot machine; catalogs conscripted equipment and issues it back out. Parallel of Yardmaster in name and teaching role. Attacks: catalog clamp (G, 20, Clampcart grammar at scale), issue chute that fires crated machines down a previewed lane (H, 24), ledger stamp (D, 16). Recovery after the issue chute exposes the sorting drum. Reward: **Manifest Plate**, a component that tags one enemy's next drop as guaranteed salvage. Numbers 520 hp.

**Boss: The Prime Mover (new).** Brindle's engine room, the traction drive the city walks on. Arena: tilting decks and conveyor streets (worker-4-universe.md:66). Consequence beat: city blocks shear away while service corridors stay rollable.

- Phase 1. Piston strokes cross the deck on previewed rails (H, 32 dmg, windup 1.9) while Requisitioner squads pressure devices.
- Phase 2, named escalation **Deck list**. The counterweight district visibly shifts and the whole deck tilts; every lane acquires a slope the player's mass now matters on. Conveyor streets reverse on Beltwarden cues. Shearing a block breaks one piston's steam feed for good.
- Phase 3, named escalation **Open firebox**. Brindle overdrives the engine; firebox doors lock open as the glowing weak point, guarded by lifeline cables that cast as snares (G). Deflectable vent blasts (D, 18) give the deflect economy its finale. Broken pistons never restart.

Numbers 1400 hp. Contested resource: the city's stolen cargo, spilling as blocks shear. Brindle himself stays a character beat, not a hitbox (CONFLICT-AND-COMBAT.md:22).

## Expansion rung: Windworks (proposal, parked family unparked)

Mine and city ventilation; the parked Bellows family becomes the biome (ENEMY-TAXONOMY.md:177; worker-4-universe.md:64). Bellows Skimmer and Bellows Maw are reused with their CONFLICT designs (CONFLICT-AND-COMBAT.md:37, 58-64).

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Bellows Skimmer** (reused, CONFLICT-AND-COMBAT.md:37) | Bag inflates, nozzle direction locks, then it exhales. | Jet push lane (H, displacement). | Lands deflated; intake. | Lift or knockback component; contests useful lines by shoving off them. | 100 / 16 / 1.35 / 0.6 / 2.1 |
| **Ductling** (new). Flexible-duct crawler. Grounding: flexible ventilation ducting; inference. | Duct segment rears like a hose before a whip. | Duct whip (D, 12). | Recoil coil; clamp collar. | Duct collar component; contests airflow routes by rerouting currents. | 60 / 12 / 1.1 / 0.4 / 1.8 |
| **Louverjack** (new). Louver-bank adjuster, the shield carrier. Grounding: ventilation louvers; inference. | Louver panel angles before a slam; carried panels cover allies. | Louver slam (D, 15); closed panels are directional cover. | Re-latching; actuator arm behind the panel. | Louver panel as collectible cover; contests firing lines. | 125 / 15 / 1.25 / 0.5 / 2.0 |
| **Vaneling** (new). Anemometer scout. Grounding: vane anemometers; inference. | Vanes spin toward the player, then a colored streamer marks them. | No damaging stroke; its mark calls gust strikes from ducts (justified n-a, the mark is the interrupt target). | Continuous; the vane rotor. | Vane rotor component; contests position by marking it. | 50 / 0 / mark cast 1.3 / n-a / 1.8 |
| **Damperling** (new). Damper operator, the saboteur. Grounding: HVAC fire dampers; inference. | Carries a damper frame to a deployed device, drop previewed as a shadow. | Damper drop encases a device (G against devices, 0 player dmg). | Bolting stint after the drop; exposed spindle. | Damper frame becomes cover; contests devices by starving them of the arena. | 90 / 0 / 1.5 / 0.5 / 2.4 |

**Miniboss: Bellows Maw** (reused; CONFLICT-AND-COMBAT.md:58-64). Suction cone with fabric-strip tell (G by geometry, bursting into the cone is the trap), compressed bundle shot (H, 22), shutter snap (D, 16). Breaking one shutter permanently removes that intake. The vacuum never strips the player's accumulated body (CONFLICT-AND-COMBAT.md:64). Reward Accordion Lung. Numbers 400 hp.

**Boss: The Greatfan (new).** The gallery's main ventilation plant. Arena: the fan hall with streamers previewing every current (worker-4-universe.md:64). Consequence beat: jam the fan and the gallery's airflow reverses, dragging loose scrap past the player.

- Phase 1. Intake pull lanes reshape rolling while blade tips sweep a fixed ring (H, 28 dmg).
- Phase 2, named escalation **Reverse pitch**. Blades visibly re-pitch one by one; flow reverses arena-wide, and everything the intake hoarded becomes incoming debris volleys (D, 14 dmg).
- Phase 3, named escalation **Surge stall**. The fan hunts between pull and push in announced pulses; feeding it mass, the Shed Vent verb (worker-2-combat.md:70), jams the hub and opens the bearing weak point. Jammed blades stay jammed.

Numbers 1000 hp. Contested resource: rolling momentum itself; the fan adds and steals it.

## Expansion rung: Harvest Roads (proposal, parked concepts unparked)

Fleet logistics convoy; fighting on and between moving flatbeds (worker-4-universe.md:65). Plowback and Clampcart return as Fleet escorts (ENEMY-TAXONOMY.md:176; CONFLICT-AND-COMBAT.md:35, 39); Kiln Strider becomes the rung boss (concept at CONFLICT-AND-COMBAT.md:40; parked status at ENEMY-TAXONOMY.md:178).

| Enemy | Telegraph and commitment | Geometry and grade | Recovery and weak point | Counter reward and contested resource | Numbers |
| --- | --- | --- | --- | --- | --- |
| **Plowback** (reused, CONFLICT-AND-COMBAT.md:35) | Stabilizers lower, then a committed line. | Plow line (H); the plow face is frontal cover for the column behind. | Vent stint with plow open; central mechanism. | Plow becomes bank then armor salvage; contests the escort lane. | 170 / 24 / 1.6 / 0.8 / 2.4 |
| **Clampcart** (reprise, Fleet livery) | As rung 4. | Jaw closure (G, 18). | Retreat; hinge. | Hinged Grip; contests devices on moving beds, harder rescues. | 120 / 18 / 1.4 / 0.5 / 2.2 |
| **Linkdray** (new). Coupling tender. Grounding: drawbar couplings on road trains; inference. | Coupling bar swings wide before a latch throw; decoupling opens announced gaps between flatbeds. | Bar swing (D, 15); the gap it opens is damage-free geometry with a real fall cost. | Re-latching; the drawhead. | Coupling pin component; contests the train's continuity, and so the player's footing. | 110 / 15 / 1.3 / 0.5 / 2.0 |
| **Outrider** (new). Convoy scout tricycle, the flanking raider. Grounding: convoy outriders; inference. | Leans into a dart line, pennant snaps straight. | Dart pass (D, 12), fast but shallow. | Wide turnaround; rear wheel. | Pennant marker salvage; contests loose cargo by tagging it for pickup crews. | 70 / 12 / 1.1 / 0.4 / 1.9 (speed ~3.0, the fastest worker) |
| **Hitchjack** (new). Tow-hitch cart, the saboteur. Grounding: tow dollies; inference. | Backs toward a deployed device, hitch jaw gapes, three reverse beeps. | Hitch grab (G against devices); it drags the device toward the train rather than dismantling it. | Straining haul stint; hitch pin. | Hitch assembly component; contests devices by relocation, a moving rescue. | 90 / 0 / 1.4 / 0.5 / 2.3 |

**Miniboss: Roadmaster (new).** The convoy pilot engine; Yardmaster and Quartermaster's naming line continues. Attacks: brake-check halt sending a shockwave down the couplings (H, 24, previewed by a horn and brake-light cascade), coupling whip (D, 16), cargo dump across a previewed lane (H, 22). Recovery at the sander dome. Reward: **Air Brake**, a component making the player's own hard brake shove nearby light enemies. Numbers 500 hp.

**Boss: Kiln Strider (reused concept promoted).** The taxonomy parks it as an alternative large harvester, not a fourth mandatory boss (ENEMY-TAXONOMY.md:178); this rung is where it stops being parked. Recommendation: adopt Kiln Strider as the Harvest Roads boss. Arena: the moving train and roadbed beside it. Consequence beat: derail the harvest train; a kilometer of stolen cargo avalanches home (worker-4-universe.md:65).

- Phase 1. Glow and ground shadow precede each committed step (H, 30 dmg footprint) or intake reach (G cone contesting cargo), with cooling shutters opening afterward as the weak point (all three cues from CONFLICT-AND-COMBAT.md:40).
- Phase 2, named escalation **Twin stride**. Two legs preview in sequence; its strides now land on the train itself, snapping couplings. The player can steer the panic, wedging a loaded flatbed under a descending foot to derail the train.
- Phase 3, named escalation **Open kiln**. After the derailment the shutters lock open, the heart glows reachable, and avalanching cargo crosses the field as both hazard and ammunition, the offcut ram-return rule at scale (worker-2-combat.md:146).

Numbers 1300 hp. Armor becomes ramps and the recovered heart is the major reward (CONFLICT-AND-COMBAT.md:40).

## Support-pressure roles per biome (proposal)

DISCOVERY names three pressure roles against the player's setup: saboteur, shield carrier, flanking raider (DISCOVERY.md:129-133). Mapping, so every biome contests devices and companions:

| Biome | Saboteur | Shield carrier | Flanking raider |
| --- | --- | --- | --- |
| Yard Commons | Bootjack (clamps devices) | Gateling (barrier panel) | Curbsweep (curb-line approach) |
| Spillway Works | Jettling (jets devices off anchors) | Rackspan (raised boundary as cover; ENEMY-TAXONOMY.md:50) | Scooplet via bypass gutters (side routes at ENEMY-TAXONOMY.md:71) |
| Iron Orchard | Graftmender (binds and reconnects; ENEMY-TAXONOMY.md:147) | Discback (ring armor; ENEMY-TAXONOMY.md:146) | Switchback Flushpot (lane change; ENEMY-TAXONOMY.md:149) |
| Foundry Crown | Clampcart (device capture; ENEMY-TAXONOMY.md:100) | Shieldload Clampcart (carried plate; ENEMY-TAXONOMY.md:102) | Brakebogie (arrives by siding; ENEMY-TAXONOMY.md:99) |
| Furnace City | Requisitioner (conscripts devices and companions) | Shieldload Clampcart overseer | Beltwarden (delivers flankers by belt) |
| Windworks | Damperling (encases devices) | Louverjack (louver panels) | Bellows Skimmer (jet-shove flanks; CONFLICT-AND-COMBAT.md:37) |
| Harvest Roads | Hitchjack (drags devices away) | Plowback (plow face; CONFLICT-AND-COMBAT.md:35) | Outrider (dart passes) |

Graftmender's device pressure is an extension: today it targets only uncollected enemy modules (ENEMY-TAXONOMY.md:147). Proposal: it may also bind a deployed device out of alignment, never confiscating it, matching the recoverable-device rule (CONFLICT-AND-COMBAT.md:39).

## Veteran and elite modifier system (proposal)

The taxonomy already defines a veteran as a modification of one existing enemy, never just a higher health bar (ENEMY-TAXONOMY.md:9), and the combat paper gives elites a real axis: upgrade exactly one attack, taught visibly (worker-2-combat.md:47; CONFLICT-AND-COMBAT.md:120, 167). System:

1. **One attack, one change.** A veteran modifies exactly one attack, chosen from three legal upgrade types. Grade shift: deflectable to heavy, shown by a bolted ground-coupling brace, solid stroke rendering and the thud cue (worker-2-combat.md:47). Follow-up: a second, separately signaled stroke with its own visible linkage, the Double-cut Snipcart and Tandem Scooplet pattern (ENEMY-TAXONOMY.md:55, 149). Destination: the committed action gains a visible second target or handoff, the Relay Crossbelly and Switchback Flushpot pattern (ENEMY-TAXONOMY.md:55, 149).
2. **Illegal upgrades.** Never a windup below 1.0 s, never tracking after commit, never a grab without visible jaws or line, never a new attack the base enemy lacks, never stat-only durability (ENEMY-TAXONOMY.md:9; CONFLICT-AND-COMBAT.md:167).
3. **How it is taught.** A family's first veteran appears alone in its own beat and performs the upgraded attack once against terrain or a prop before engaging, so the changed tell is read risk-free. The bolted brace or extra linkage stays visible on the silhouette from first sight.
4. **What it pays.** A veteran guarantees its family salvage component (the named drops in the family tables, ENEMY-TAXONOMY.md:49-53, 96-100, 143-147) instead of rolling for it, plus 2 extra scrap, plus the **Override Bolt** itself as a collectible that feeds the Scrapbook's seen-not-taken ledger when declined (DESIGN-AUDIT.md:44, 60).
5. **Numbers.** Hp x1.25, damage unchanged. The threat increase comes from the upgraded attack, not from arithmetic.

## Difficulty curve (proposal)

What escalates across the campaign:

- **Simultaneous committed attacks.** Escalation is per lane in defense beats. Rungs 1-2 keep one non-boss windup at a time per lane, with the 0.8 s stagger applied inside each lane (worker-2-combat.md:5); the global one-windup cap is retained for roaming combat pockets. This depends on the levels lane's per-lane windup gate extension, which specifies the target shape and acceptance test (LEVEL-DESIGN.md:161). Rungs 3-4 allow two staggered windups per arena. Rung 5 and expansions allow two plus one boss subsystem. Never more.
- **Grade mix.** Yard is mostly deflectable with one heavy teacher and one grab teacher. Grabs and heavies rise as a share of attacks each rung; Furnace City is roughly a third each.
- **Geometry.** Static lanes, then water-level lanes, then terraces, then moving carriages, then floors that move and tilt. The arena joins the enemy roster by rung 5.
- **Contested resources.** Loose scrap, then devices, then companions and cargo, then the floor itself.
- **Veteran frequency.** None in rung 1, one family veteran in rung 2, veterans as standard mix by rung 5.

What never escalates, the readability floor:

- No damaging windup under 1.0 s (worker-2-combat.md:127).
- Commitment is honest: no re-aim after lock, ever (worker-2-combat.md:128).
- Recovery at least as long as active (worker-2-combat.md:130).
- Weak points reachable by ground route at radius 1.65 (worker-2-combat.md:135).
- Shape, motion and sound carry every tell; color never encodes the answer alone (CONFLICT-AND-COMBAT.md:120).
- Every heavy keeps a pure-spacing exit; attacks demanding incompatible reactions never arrive together without a route out (CONFLICT-AND-COMBAT.md:106, 161).
- Earned Shear and Brace parts are never confiscated (worker-2-combat.md:73; ENEMY-TAXONOMY.md:24).

## Registry fields this roster implies (proposal)

The audit already recommends the admission grammar as a data registry replacing kind-string branching (DESIGN-AUDIT.md:43, 85). This roster implies these exact fields per enemy descriptor:

- `id`, `name`, `family` (cancrusher, crown, pruner, yard, city, bellows, roads), `biome`, `tier` (worker, veteran, miniboss, boss), `pressureRole` (none, saboteur, shieldCarrier, flankingRaider), `occupation` (one line), `groundingRef` (URL or inference flag).
- `telegraph`: duration s, cue list (shape, motion, sound), preview type (stroke capsules, lane, ring, shadow, flag).
- `commitment`: lock type (yaw, lane, rail, arc, target mark).
- `attacks[]`: name, grade (deflectable, heavy, grab), geometry (capsule set, width, reach), damage, active s, targets (player, device, companion, cargo).
- `recovery`: duration s, announce string, exposure geometry.
- `weakPoint`: location, ram window, shot window (the implemented offsets at worker-2-combat.md:5).
- `counterReward`: multiplier, drop table, once-per-cycle flag.
- `contestedResource`: enum plus free text.
- `salvageComponent`: named component and its effect hook into the modifier pipeline (DESIGN-AUDIT.md:36).
- `veteranUpgrade`: the one legal modification, its taught tell, its extra pay.
- `stats`: hp, radius, speed, wake, spacing, matching the existing ENEMY_CONFIG shape (sim.js:8-48).
- `bossPhases[]` (bosses only): arena beat, named escalation, subsystem removal flags.

## First 12 enemies to build, in order (recommendation)

1. **Snipcart.** Migrate the implemented enemy into the registry first; it proves the descriptor shape against known behavior (sim.js:9-21).
2. **Spreadleg.** Second migration confirms the registry handles two bodies without new branching (DESIGN-AUDIT.md:86 gate).
3. **Sluiceback.** The basin experiment the combat paper demands before anything builds on the deflect economy (worker-2-combat.md:173; DESIGN-AUDIT.md:85).
4. **Scooplet.** First collector; stands up the contested-resource loop the whole roster leans on.
5. **Binbug.** Cheapest swarm body; tests bowling-through mass feed at rung 1 tuning.
6. **Curbsweep.** First pure deflectable teacher in the yard's grade curriculum.
7. **Mowling.** First heavy teacher; proves the solid-stroke rendering and thud cue read at chase distance.
8. **Bootjack.** First grab and first device saboteur; tests the device-capture rescue loop solo.
9. **Glassjaw.** First miniboss; one machine carrying all three grades validates the grade UI.
10. **Brakebogie.** The admission table's own worked template row, and the first rail-committed body (worker-2-combat.md:125-133).
11. **Clampcart.** Grab against devices at rung 4 pressure; pairs with Bootjack learnings.
12. **Old Ironroot.** First boss; three phases and named escalations exercise the bossPhases fields end to end.

This order front-loads the registry proof, the deflect experiment and the full grade curriculum before any second-biome content.

## Contested choices, one recommendation each

- Demo labels Glassjaw and Old Ironroot are preserved in the playable files and flagged for reconciliation (ENEMY-TAXONOMY.md:179). Recommendation: adopt them as the Yard Commons miniboss and boss so the demo names become campaign canon instead of orphans.
- Scooplet appears in two rungs. Recommendation: keep it; the yard version is the same machine at lighter tuning, and meeting it again in the spillway is the taxonomy's teaching order working (ENEMY-TAXONOMY.md:9).
- Kiln Strider is parked as an alternative concept (ENEMY-TAXONOMY.md:178). Recommendation: promote it to Harvest Roads boss and nothing else; it stays out of the first campaign.
- Plowback is retained but uncounted (ENEMY-TAXONOMY.md:176). Recommendation: give it the Harvest Roads escort slot it was designed for.
- Spillway lacked device pressure. Recommendation: admit Jettling rather than stretching Rinsebelly into a saboteur it was not shaped to be.

## Evidence limits

All designs here are paper proposals; no fun, balance, AI or performance claim is made, matching the standing posture (CONFLICT-AND-COMBAT.md:171; DESIGN-AUDIT.md:93). Implemented numbers are cited to `src/orchard/simulation.js:8-48` as read this session; taxonomy, combat, conflict, audit, discovery and universe claims are cited to the file and line read this session. All hp, damage and timing values outside the three implemented baselines are tuning sketches, not verified numbers. No web research was performed in this session; occupational groundings for the thirteen new designs are labeled inference and each needs one reference pass with URL and access date before the registry row is considered grounded, per the taxonomy's own citation discipline (ENEMY-TAXONOMY.md:216). The support-role extension of Graftmender and the promotion of Kiln Strider, Glassjaw and Old Ironroot go beyond current taxonomy text and are exactly the reconciliations the taxonomy already anticipates (ENEMY-TAXONOMY.md:179). Everything resting on the 5 September audit canon, including the rung order, the deflect grades and the Requisition premise, is pending Andrew's approval of that audit.
