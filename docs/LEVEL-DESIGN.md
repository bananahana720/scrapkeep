# Level design: spatial grammar for expedition stages

5 September 2026. This document proposes the spatial grammar for Scrapkeep expedition stages, from per-beat pocket sizing through a fully worked Iron Orchard stage buildable against the current runtime, and it is a proposal desk document, not committed scope.

Confirmed constraints this grammar serves: themed 30 to 45 minute expeditions with exploration, combat and defense encounters, optional branches, and a boss (docs/project/REQUIREMENTS.md:17, R11); close third person with ordinary growth fitting designed routes (REQUIREMENTS.md:8, R02); readable enemy commitments (REQUIREMENTS.md:9, R03). Working canon from the 5 September audit, pending Andrew's approval wherever it is load-bearing below: three stages of five beats each (docs/audit-2026-09-05/worker-3-meta.md:38), the Roll-Through deflect with deflectable, heavy, and grab attack grades (docs/audit-2026-09-05/worker-2-combat.md:39-48), the biome ladder with Iron Orchard as a campaign rung (docs/DESIGN-AUDIT.md:67), and the reconciliation that an expedition routes three stages through the campaign's biomes (docs/DESIGN-AUDIT.md:78).

## The measured envelope

Every size in this document is justified against these observed numbers.

| Quantity | Value | Source |
| --- | --- | --- |
| Max roll speed | 7.4 u/s (2.2 braking) | src/orchard/simulation.js:323 |
| Burst | 19 u/s for 0.24 s, 4.56 u displacement | simulation.js:297-299 |
| Burst cooldown | max(0.85, 1.45 - brace x 0.22) s | simulation.js:300 |
| Steering accel | 25 (48 braking) + brace x 4 | simulation.js:329 |
| Player radius | 1.0 to 1.65, so max diameter D = 3.3 u | simulation.js:778-781 |
| Proven arena | x [-19,19], z [-37,27]: 38 x 64 u | simulation.js:1-6 |
| Terrain height | one ramp band, 0 to 2.5 u over z -14 to -23, z only | simulation.js:57-59 |
| Enemy wake radii | 12 / 13 / 22 (snipcart / spreadleg / pruner) | simulation.js:12, 25, 38 |
| Enemy windups | 1.15 / 1.3 / 1.75 s | simulation.js:16, 29, 42 |
| Pruner toss line | released 6.51 u ahead, 31.5 u path, 9 u/s, 3.5 s life | simulation.js:513-524, 536-537, 567 |
| Chase camera | fov 65, distance (7.2 + radius x 1.8) x zoom, so 9.0 to 10.2 u | src/orchard/scene.js:87, 382 |
| Enemy label horizon | labels render only within 24 u | src/orchard/main.js:600-603 |
| Threat banner | nearest windup or active enemy, four direction buckets | main.js:575-598 |
| One-windup rule | one non-Pruner windup at a time, 0.8 s stagger | simulation.js:406-413, 422 |
| Concurrency proven | 5 enemies, max 4 live offcuts, 1 companion | simulation.js:151-157, 527 |
| Seed determinism | OrchardGame({seed}), LCG in _random | simulation.js:124-126, 751-754 |

Derived: crossing the proven arena lengthwise takes 8.6 s at max roll. A threat at the 24 u label horizon gives 3.2 s of closing warning at max roll, against windups of 1.15 to 1.75 s. The clearance unit is D = 3.3 u; the study's construction rule is 2D = 6.6 u clear width for a dependable route (docs/ORCHARD-ENCOUNTER-STUDY.md:47-49).

The standing problems this grammar must answer: a large world and a close camera create a defense-awareness problem (docs/DISCOVERY.md:55); the windup pose is subtle at chase distance and the world-space banner carries most of the warning load (docs/DESIGN-AUDIT.md:28); and a precise player cleared all five enemies in about 37 seconds without damage (docs/project/BACKLOG.md:9, P02; 37.05 s in docs/FIRST-BUILD-CONTRACT.md:28), so combat length cannot be the pacing mechanism.

## Spatial grammar per beat (proposal)

Shared vocabulary. A stage is a spine of pockets. A pocket is one bounded playable space with its own encounter budget. A mouth is a readable opening between pockets or into a branch. A ring is a closed circuit of at least 2D width. All sizes assume the current handling; if the mass-in-handling experiment (DESIGN-AUDIT.md:84) changes accel or top speed, re-derive from the table above.

### Explore pocket

- Size: 30 to 40 u wide, 40 to 70 u long. That is 5.4 to 9.5 s to cross at max roll, and the proven 38 x 64 arena is the ceiling reference (simulation.js:1-6).
- No wake zone for the first 20 u from the entry mouth, so arrival is always a safe read (the study's arrive beat: tools do ordinary work before aggression, ORCHARD-ENCOUNTER-STUDY.md:21).
- Scrap lines trace the intended route the way the current build's nine floor pickups trace the approach (simulation.js:162-172). Density guidance is in the pacing section.
- At most two awake-able workers, placed so their wake circles (12 to 13 u) do not overlap the entry read.
- Vertical: one ramp band of at most 2.5 u rise, matching the only terrain shape the runtime supports today (simulation.js:57-59; docs/FIRST-BUILD-CONTRACT.md:8).

### Combat pocket

- Size: 24 to 36 u across. Rationale: from the pocket center every enemy stays inside the 24 u label horizon (main.js:600-603), and the pocket fits inside one banner-plus-look read. Worker wake radii of 12 to 13 fit without reaching the mouths.
- Pocket separation: 26 u or more between a combat pocket's enemies and any neighboring pocket, so wakes never chain (max worker wake 13, pruner-class 22, simulation.js:12, 25, 38).
- Enemy budget: 3 to 5 concurrent, within the proven 5-enemy envelope (simulation.js:151-157). The one-windup rule (simulation.js:406-413) means adding bodies does not add simultaneous strokes; difficulty scales through geometry, attack grades, and offcut lanes instead.
- Always two exits. The study's rule stands: windup must leave a reachable exit from intended approach positions, and width cannot compensate for an unreachable exit (ORCHARD-ENCOUNTER-STUDY.md:49).
- Floor scrap is sparse (4 or fewer); counters pay the rest, once per attack cycle (simulation.js:689-695), so collecting mid-fight stays the tactical layer.

### Optional branch

- Mouth: 8 to 12 u wide. 8 u reads as tight (barely more than 2D = 6.6), 12 u as roomy. Mouth width is the honest escape-budget signal.
- Depth: 30 to 60 u, 45 to 120 s of content.
- The guard's wake circle starts at least 2 u inside the mouth, so looking is free and entering is the commitment (wakes 12 to 13, simulation.js:12, 25).
- Full patterns in the branch section below.

### Defense arena

- Size: 44 to 60 u across, with a objective ring of radius 14 to 18 u around the defended object.
- Lane mouths sit 20 to 26 u from the object, inside the label horizon from the ring.
- Adjacent mouths at most 35 u apart along the ring: 4.7 s at max roll, about 3.5 s with a burst. This number is the repositioning contract (see the defense section).
- Anchor points for all four class infrastructures on the ring, never inside lanes, so deploying never requires standing in traffic (quick deployment while moving, docs/DISCOVERY.md:25).

### Boss arena

- Size: 48 to 64 u across, ring route of at least 2D at all times.
- Must contain the full toss threat line: release 6.51 u ahead of the arm plus 31.5 u of travel is 38 u (simulation.js:513-524), and offcuts expire at the bounds anyway (simulation.js:567-572), so the arena diagonal should exceed 40 u for the toss to read as a dodgeable lane rather than an instant wall hit.
- Destruction changes the space per the boss section below without ever narrowing the ring under 2D.

### Threat-communication rules (extends the implemented banner)

The implemented banner shows one line for the nearest windup or active enemy, bucketed AHEAD, LEFT, RIGHT, BEHIND YOU (main.js:575-598). The audit found it carries most of the warning load (DESIGN-AUDIT.md:28). Proposed extensions:

1. One line only, priority ordered: grab, then heavy, then deflectable, then proximity. Today ordering is distance only (main.js:577-580). Grades are pending Roll-Through approval (worker-2-combat.md:47).
2. In defense arenas the banner names the mouth, not just the direction: "LEFT MOUTH, SABOTEUR ON RODS."
3. On-camera commitments may rely on pose plus the 17-sample stroke preview (simulation.js:488-492). Off-camera commitments always banner.
4. No windup-capable enemy spawns inside the rear 120 degrees within its own reach of the player. Rear threats must enter through a mouth or seam first, so BEHIND YOU always has a spatial explanation.
5. Lead-time invariant: any threat whose first damaging action can land within 2 s must have been on screen or in banner scope at least 3 s earlier. This is directly checkable in telemetry.

## Authored versus generated (proposal, one recommendation)

Three models, judged against the 30 to 45 minute target (REQUIREMENTS.md:17), the daily-seed and friend-challenge mechanisms the meta lane keeps (worker-3-meta.md:70, 132-134, citing src/campaign.js:206-256), production cost, and replay variety (the delayed-variety complaint the meta lane cites at worker-3-meta.md:21).

| Criterion | A: fully authored stages | B: tile assembly from terrain kits | C: seeded arrangement of authored pockets |
| --- | --- | --- | --- |
| 30-45 min fit | Exact, tuned once | Length drifts with tile luck | Exact: seed picks from fixed-budget pocket sequences |
| Daily seed / friend challenge | Meaningless (same stage daily) | Fully meaningful | Fully meaningful: seed encodes pocket order, branch content, admissions |
| Production cost | Highest per replayable hour; every variant is a full stage | Lowest per square unit, highest in kit tooling and QA of emergent junctions | Per-pocket cost; each pocket built and cleared once, reused many arrangements |
| Replay variety | Weakest; the exact complaint pattern the meta lane flags | Highest, but incoherent | High and coherent |
| Clearance and camera contract | Verified by hand once | Emergent junctions can silently close the 2D route; this generalizes the study's route-closure worry about clutter and deployed devices (ORCHARD-ENCOUNTER-STUDY.md:51) to generated junctions | Verified per pocket at author time; seams are the only join risk |
| Readability | Best | Worst; wake overlaps and rear spawns become luck | Good; separation rules enforced at the pocket boundary |

Recommendation: Model C, seeded arrangement of authored pockets. Each biome owns a pocket library (explore, combat, branch, defense, boss variants), every pocket individually passes the clearance and camera contract (ORCHARD-ENCOUNTER-STUDY.md:47-53), and the seed selects the arrangement, branch contents, enemy admissions, and boss layout variant. The runtime is already seed-deterministic (simulation.js:124-126, 751-754), so the daily seed stays a shared puzzle and friend challenges encode a full arrangement. The universe lane's terrain modules double as the pocket kit pieces and the figurine bases (worker-4-universe.md:126). Model B's kit still exists, but as authoring vocabulary, not as a runtime assembler.

### Pocket record schema (proposal)

Model C needs an authorable record per pocket instance, not just the per-type size bands above. Proposed shape:

```
pocket_record {
  pocket_id             unique within the biome library
  type                  explore | combat | branch | defense | boss
  biome_tag             e.g. iron_orchard
  footprint             { width, length } in u, inside the type's band
  mouths                [ { id, position, width, connects_to } ]
                        connects_to names a spine slot, a branch record, or null for a dead end
  enemy_admission_list  enemy kinds this pocket may admit, with placement anchors
  wake_exclusion_zones  regions no wake circle may reach, e.g. the 20 u entry read
  scrap_density         floor scrap count, per the density guidance below
  vertical_profile      ramp bands, each at most 2.5 u rise (simulation.js:57-59)
}
```

Seed mapping: a stage template is an ordered list of typed slots, one per beat. The seed drives the existing LCG (simulation.js:124-126, 751-754). Each slot consumes one draw to index into the biome's pocket list of that slot's type; further draws pick branch contents, admissions from the pocket's admission list, and the boss layout variant. Same seed, same arrangement. Reuse check for the comparison table's cost and variety claims: P01 telemetry logs pocket_id per arrangement, and each library pocket should appear in at least 2 of the first 10 seeded arrangements, which is what makes the per-pocket cost claim checkable rather than asserted.

## Branch design patterns (proposal)

### How a mouth reads risk and reward before commitment

- Reward: visible from the mouth as a lit silhouette, using the real pickup or chassis model where one exists (models module renders pickups and companions, FIRST-BUILD-CONTRACT.md:34-35). Sighting at the mouth registers a Scrapbook seen-not-taken entry (worker-3-meta.md:104), so skipping is recorded, not lost.
- Risk: the guard is visible or audible from the mouth doing its occupational work, exactly the arrive-beat rule (ORCHARD-ENCOUNTER-STUDY.md:21). Its wake starts 2 u or more inside the mouth. Looking is free; crossing the mouth line is the commitment.
- Cost: mouth width (8 tight to 12 roomy) plus a visible depth cue (a lamp line or scrap trail showing how far in the reward sits) telegraphs the time price.

### Three reusable branch shapes

1. The loop. Leaves the spine and rejoins it 20 to 30 u ahead. A toll fight midway, a scrap line plus one cache as payment. 45 to 60 s. The loop is never faster than the spine, so skipping it is always a clean pacing choice.
2. The cellar. A dead end 30 to 40 u deep, in and back through the same mouth. The richest rewards live here (companion chassis, a transformative item), and the return trip faces the now-awake guard. 60 to 90 s.
3. The gallery. A parallel corridor beside the spine, raised up to 2.5 u (the only vertical the runtime supports, simulation.js:57-59), overlooking the next pocket. Risk is exposure to an offcut lane; reward is scouting: Scrapbook sightings, and an entry angle or firing line into the next combat pocket that suits mortar and laser sightlines. 30 to 45 s.

### What a branch may gate

A branch may gate additive build content only: items, companion parts, scrap mass, Scrapbook entries, ult-charge opportunities. A branch must never gate the stage exit, the boss's spatial counter route, baseline class function, or the run's only repair economy. This extends the standing rule that baseline attacks always work and no loot is mandatory (FIRST-BUILD-CONTRACT.md:26); hearts must keep dropping on the spine through kills and boss-class counters as they do today (simulation.js:693-694, 722).

## Defense arena patterns (proposal)

Lane counts follow the meta lane's escalation, where two lanes arrive as the stage 2 twist (worker-3-meta.md:52): stage 1 runs one lane plus a flanker seam, stage 2 runs two lanes plus a seam, stage 3 runs three mouths with one that shifts mid-encounter. Defense beats are timer-held, 2.5 minutes at stage 1 (worker-3-meta.md:49); clearing fast earns collection and deploy time between waves, never a shorter beat. That is half the answer to P02.

### Deploy surfaces and anchors, all four classes

Anchors sit on the objective ring. Every arena provides at least one anchor per class per lane. The confirmed part is the requirement for autonomous, thematic infrastructure deployed during combat (DISCOVERY.md:25, 83); the four device examples below are the publisher record's proposals, not accepted ability specifications (DISCOVERY.md:83, 85-91).

| Class | Anchor requirement | Placement rule |
| --- | --- | --- |
| Grapple winch mast (DISCOVERY.md:87) | Post socket with overhead clearance | Ring point at a lane midpoint, so the mast drags light enemies off the lane axis |
| Hover mortar nest (DISCOVERY.md:88) | Flat pad about 3 u, open sky | Ring point with sightline over two mouths; the 0.9 s shell flight (worker-2-combat.md:94) needs the arc unobstructed |
| Laser prism sentry (DISCOVERY.md:89) | Corridor mouth 8 u or narrower, wall plate opposite | Covers the seam, the narrowest approach, and gives Refraction shots a bend point |
| Lightning storm rods (DISCOVERY.md:90) | Paired sockets flanking a lane, 6 to 10 u gap | The lane itself becomes the arc gap; rolling past deposits charge |

### How pressure roles path

The three pressure roles are proposed encounter designs (DISCOVERY.md:127), not implemented AI (docs/DISCOVERY.md:129-133).

- Saboteur: takes the shortest lane to the nearest deployed device and begins a visible dismantle of 6 s or more. It never spawns inside the ring; it enters at a mouth so the banner can name it.
- Shield carrier: fronts the widest lane at walking pace, covering the group from one direction. The ring is the flanking tool; its cover never faces two mouths at once.
- Flanking raider (DISCOVERY.md:133), flanker for short below: uses the seam, and every seam crossing has a fixed audible cue plus banner line. Flankers are the only role allowed to end up behind the camera, and only after a named crossing.

Runtime note: the one-windup rule serializes worker strokes globally (simulation.js:406-413, 422). Multi-lane defense needs that gap to become per-lane, or waves will queue politely behind one another. Target shape: the single stagger gate becomes a map keyed by lane id, one gate per mouth, seam included. Acceptance test: two lanes in the stage-1 defense arena each hold an active windup at the same time, and neither suppresses the other. This is a needed simulation extension, flagged in the backlog items.

### The repositioning rule (answers DISCOVERY.md:55)

One read, one burst. From any mouth on the objective ring, any adjacent mouth is reachable in at most 5 s (35 u of ring at 7.4 u/s, less with a burst), and every threat to the objective or a device announces at least 6 s before its first damaging action: the saboteur's dismantle length, the shield carrier's walking advance, the flanker's seam cue. Banner read plus travel therefore always beats the threat clock, without the camera ever needing to see everything at once. Local dodges stay on the 1.15 to 1.75 s windup economy, which is unchanged. If playtest telemetry shows hits arriving from threats that never entered banner scope 3 s ahead, the arena, not the player, failed.

## Boss arena patterns (proposal)

Each biome's boss beat is its consequence-scale beat: the fight changes the place while the ball keeps fitting the routes (REQUIREMENTS.md:19, R13). The governing invariant everywhere: a closed ring of at least 2D width exists at every phase. Destruction adds geometry inward (banks, chords, bowls); it never subtracts the ring.

- Iron Orchard, Grand Pruner. Terrace ring around the greenhouse hub. Countered pruning structures fold into banks and ramps with visible supports and usable landing areas, per the study's own consequence rule (ORCHARD-ENCOUNTER-STUDY.md:74-79). Folds are chords across the ring interior that open counter routes toward the binding spool, whose latch interrupts preparation without whole-boss immunity (ORCHARD-ENCOUNTER-STUDY.md:43).
- Spillway Works, Cancrusher (taxonomy root per the working canon). Basin arena; phase transitions drain or flood channels, so lanes move rather than vanish. Every newly opened channel is cut at 2D minimum. Offcut-style debris rides the water line, reusing the announced-projectile grammar (simulation.js:513-539).
- Foundry Crown, Counterweight Crown. The furnace hammer craters the arena and wrecked carriages become new bank angles, exactly the universe lane's row (worker-4-universe.md:63). Craters are bowls with a full-width rim route; the rim is the ring.

Phase rule: each destruction transition is a scripted 10 to 15 s beat with no new windups, doubling as the boss fight's internal rest beat and as a floor on boss duration that a high-damage build cannot skip.

## Pacing map, 38-minute reference run (proposal)

Built on the meta lane's minute map (worker-3-meta.md:44-53). Tension is a 1 to 5 design intent, not a measurement.

| Time | Beat | Tension | What holds the clock |
| --- | --- | --- | --- |
| 0:00-1:00 | Embark, class select, roll-in | 1 | Fixed |
| 1:00-5:00 | Stage 1 explore pocket | 2 | Travel distance and collection weaving |
| 5:00-8:00 | Combat pockets plus branch | 3 | Travel between pockets, branch commitment; combat floor is short |
| 8:00-10:30 | Defense arena | 4 | Wave timers, never kill speed |
| 10:30-12:30 | Stage 1 boss | 5 | Phase gates with destruction transitions |
| 12:30-13:00 | Interstitial, no threats | 1 | Fixed rest |
| 13:00-26:00 | Stage 2, five beats, +1 min explore, two-lane defense, chassis branch | 2 to 5 | Same holders, larger spine |
| 26:00-38:00 | Stage 3: compressed explore, biggest defense, finale boss about 4 min | 3 to 5 | Defense timers plus boss phases |

Rest beats are structural: the two interstitials, a 30 to 45 s post-defense sweep with spawns off, and the 10 s gate landing before each boss with the banner silent. Rule: no two tension-4-plus segments touch without at least 30 s at tension 2 or below.

### Collectible density guidance, and the P02 answer

The current build spreads 9 floor scrap across the whole 38 x 64 arena (simulation.js:162-172) and a precise player cleared everything in about 37 s (BACKLOG.md:9), meaning combat carried both the clock and the collection. Stage design inverts that:

- Explore pockets: 12 to 18 floor scrap each, one piece per 4 to 6 s of intended rolling, laid in lines that draw the route.
- Combat pockets: 4 or fewer on the floor; counters pay once per attack cycle (simulation.js:689-695).
- Defense arenas: 6 to 9 scrap pre-seeded at ring anchors as deploy fuel (3 scrap per device under the combat lane's economy, worker-2-combat.md:71).
- Boss arenas: start clean; scrap arrives only through counters.

The P02 rule: combat cannot carry the clock. A precise player may collapse combat to its floor, and the stage must still hold at least 60 percent of its design duration through travel distance (spine length), branch commitment time, timer-held defense waves, and boss phase gates. For the 12-minute reference stage: about 5 min of traversal and collection, 2.5 min of timer-held defense, at least 2 min of phase-gated boss, 0.5 min interstitial. A 37-second-per-pocket clear still lands near 10 minutes, comfortably above the floor at about 83 percent. Kill speed compresses only combat's own slice, about a sixth of the stage.

## Worked example: Iron Orchard, expedition stage 1 (proposal)

Sized to demonstrated runtime capability: one 38 x 64 arena with 5 concurrent enemies, 4 live offcuts, a z-based ramp band, a greenhouse backdrop of 22 x 13 x 12 at (0, 2.5, -39), pickups, one companion, world-space banner and labels (simulation.js:1-6, 151-157, 527, 57-59; FIRST-BUILD-CONTRACT.md:36; main.js:575-618). The stage is five such pocket-scale spaces joined by mouths; no single pocket exceeds what src/orchard already renders. Total footprint about 200 x 90 u. North is -Z (forward at yaw 0, FIRST-BUILD-CONTRACT.md:6). On the pacing map, R is folded inside the defense beat's 8:00-10:30 row; it is not a sixth clock item, and the boss row starts when the player crosses the opened gate.

```
   north = -Z          Legend  ==  mouth/gate    ~ ramp band (0 to 2.5)
                               S scrap line      * branch reward
                               W enemy placement M ring anchor
+--------------------------------------------------------------------+
|  E  BOSS TERRACE  56 x 48                                           |
|     ring route width >= 6.6 at all phases                           |
|        ############ greenhouse hub ############                     |
|        #  [W GP arm A]          [W GP arm B] #                      |
|        #        binding spool (latch)        #                      |
|        ###############====####################                      |
|     folded-bank chords appear here in phase 3   ~ ~ ~ ramp          |
+--------------------------====R====----------------------------------+
|      R  ROWKEEPER TRELLIS GATE, 12 u wide, aisle spanner rig        |
+--------------------------==== ====----------------------------------+
|  D  DEFENSE ARENA  48 x 44      defended object: nursery cistern    |
|                                                                     |
|   M2 seam (6.6 u) . . . .   (cistern)  . . . . M1 lane (10 u)       |
|     objective ring r 15: M mast | M pad | M plate | M rod pair      |
|     pre-seeded scrap x 8 at anchors                                 |
+-----------==-----------------------------------==-------------------+
|           ||  B2 CELLAR                        ||  B1 LOOP          |
|           ||  mouth 8, depth 34                ||  mouth 12, 55 u   |
|           ||  * companion chassis              ||  * shear cache, S |
|           ||  W spreadleg pair                 ||  W snipcart toll  |
|           ==                                   ==  + offcut lane    |
|  B  COMBAT POCKET  34 x 30                                          |
|     W snipcart x2 (flanks), W spreadleg x1 (center)                 |
|     floor scrap <= 4; two exits (north mouths above)                |
+--------------------------~~~~~~--------------------------------------+
|  A  EXPLORE POCKET  38 x 56          S S S along the service line   |
|     14 floor scrap, wake-free first 20 u                            |
|     W snipcart (sorting, wake 12), W spreadleg (tending, wake 13)   |
|     start: south edge                                               |
+--------------------------------------------------------------------+
```

### Encounter table

Attack grades are pending Roll-Through approval (worker-2-combat.md:47). All enemies except the Rowkeeper are implemented kinds (simulation.js:8-48).

| Space | Enemies and placement | Content and drops | Notes |
| --- | --- | --- | --- |
| A explore | 1 snipcart at mid-left, 1 spreadleg at mid-right; wake circles clear of the entry read | 14 floor scrap in two lines; first Scrapbook sightings | Teaching beat, mirrors the study's 90 s sequence (ORCHARD-ENCOUNTER-STUDY.md:19-27) |
| B combat | 2 snipcarts on the flanks, 1 spreadleg center; separation keeps wakes off both branch mouths | Counter drops only; 4 floor scrap | One-windup rule makes this a routing puzzle, not a damage race |
| B1 loop branch | 1 snipcart toll mid-loop; an offcut lane crosses the far leg (announced straight path, simulation.js:450-466) | Shear cache (ram damage economy, FIRST-BUILD-PLAYGUIDE.md:57), scrap line | Rejoins spine before D; never faster than the spine |
| B2 cellar branch | Spreadleg pair guarding the chamber; return trip fights them awake | Companion chassis (assembly loot, DISCOVERY.md:29) | Richest reward, deepest commitment |
| D defense | Waves below | 8 pre-seeded scrap at ring anchors | Timer-held 2.5 min |
| R Rowkeeper | Miniboss, admission row below | Service Yoke on defeat (ENEMY-ROSTER.md:89); trellis pins latch at gate-row sockets in the gate terrain, locking rows open for the remainder of the expedition | Teaches grade escalation before the boss |
| E boss | Grand Pruner, two arms plus spool | Pick-one-of-two reward (worker-3-meta.md:104) | Phases below |

### Defense wave composition (stage 1, one lane plus seam, 2.5 min timer)

| Window | M1 lane (10 u) | M2 seam (6.6 u) | Pressure role expressed |
| --- | --- | --- | --- |
| 0:00-0:50 | 2 snipcarts, staggered | 1 spreadleg | Baseline lane pressure |
| 0:50-1:40 | Shield-role spreadleg fronting 1 snipcart | Saboteur-role snipcart paths to the nearest deployed device, visible dismantle over 6 s | Banner names the mouth |
| 1:40-2:30 | Offcut tosser beyond the mouth opens a rolling lane down M1 (reuses the implemented offcut hazard, simulation.js:526-539) | Flanker spreadleg crosses the seam after the audible cue | Peak read load, still one read one burst |

Runtime caveat: role behaviors (saboteur, shield, flanker) are unimplemented concepts (DISCOVERY.md:129-133), and wave 3 threatens as drawn only after the per-lane windup extension in the defense section lands.

### Rowkeeper miniboss, seven-field admission row (proposal)

The Rowkeeper is an existing named miniboss in the Grand Pruner family (ENEMY-TAXONOMY.md:136). This gate space uses the incumbent spec as the enemies lane keeps it: a service-aisle spanner with a spreading assembly and a separately announced flush discharge, spread press deflectable at 20, flush discharge heavy at 24, 420 hp, reward Service Yoke (ENEMY-ROSTER.md:89; ENEMY-TAXONOMY.md:151). The enemies lane owns the roster; this document specifies only the gate space around that spec. A rail-mounted comb-carriage variant is offered to the enemies lane as a separate proposal and is not adopted here.

Per the admission grammar (worker-2-combat.md:121-135): telegraph, the spreading assembly braces toward its working rows at least 1.5 s before the press, and the flush discharge announces separately before its lane fires (ENEMY-TAXONOMY.md:151); commitment, each assembly runs its announced footprint only, and the two footprints never close the middle escape, which always fits the largest normal ball (ENEMY-ROSTER.md:89); locked geometry, the spanner works the 12 u gate aisle, spread press deflectable, flush discharge heavy; recovery, post-stroke servicing with the brace exposed; weak point, the exposed brace after a spread, or the flow coupling on the flank (ENEMY-TAXONOMY.md:151); counter reward, scrap, with the Service Yoke on defeat, and broken subsystems stay disabled; contested resource, the gate rows themselves. Gate-terrain reward, distinct from the miniboss reward: the gate carries trellis pin sockets, one per row, and latching a pin locks that row open for the remainder of the expedition. Pins are terrain interactions in the gate space, not Rowkeeper counter drops, so each latched row widens the player's route into the terrace without re-specing the enemy.

### Grand Pruner boss arena

Terrace ring 56 x 48 around the greenhouse hub (backdrop proven at 22 x 13 x 12, FIRST-BUILD-CONTRACT.md:36). Phase 1: one arm, implemented behavior, sweep reach 6.51 and the 38 u toss line contained inside the ring (simulation.js:35-47, 513-524). Phase 2: second arm activates on the far quadrant; the binding spool band visibly selects the active arm (ORCHARD-ENCOUNTER-STUDY.md:43); the trellis rows the player opened at R determine which service alcoves are usable cover. Phase 3: sufficiently countered structures fold into a bank ramp, a chord across the ring interior that grants the counter route to the spool latch (ORCHARD-ENCOUNTER-STUDY.md:74-79). Each phase transition is a 10 to 15 s no-windup destruction beat. The ring never narrows below 6.6 u; offcut lanes always have a lateral exit within the burst-plus-roll reach of about 8 u per second of warning.

## Playtest telemetry for P01 (proposal)

What to record in the human playtest (BACKLOG.md:7) to validate this grammar. The sim already exposes stats and a drainable event stream (simulation.js:179-186, 843-847); items 2, 3, and 7 need small event additions.

1. Per-beat timestamps: entry and exit times for each pocket, against the pacing map.
2. Time-to-clear per combat pocket, distribution against the 37 s precision floor (BACKLOG.md:9).
3. Every hurt event tagged with the attacker's bearing relative to the camera (front, side, rear) and whether the banner covered it in the prior 3 s. Directly tests DISCOVERY.md:55 and the lead-time invariant.
4. Repositioning distance and camera yaw churn during the defense beat, per wave.
5. Branch behavior: mouth sightings, entry rate, latency from first sight to commitment, abandon rate.
6. Collection split per beat: floor scrap versus counter drops (drop events, simulation.js:689-695).
7. Off-screen hits: hurt events from enemies outside the 24 u label horizon or outside the frustum (labels, main.js:600-618).
8. Boss: time per phase, sweep hits versus offcut hits, spool counter attempts and successes.
9. Death and near-death (hp under 25) locations by pocket, as a heatmap.
10. Banner reliance: reaction time from banner change to input change, and whether BEHIND YOU lines precede rear hits.
11. Input device split: overshoot and abandon rate at tight mouths (8 u), and banner reaction time, split keyboard-and-mouse versus gamepad. The solo PC/controller pillar flags controller interactions as needing playtesting (DISCOVERY.md:15, 96), and the tightest clearances here are thumbstick geometry.

Proposed pass criteria to pre-register, not agreed acceptance criteria: no more than 1 in 10 hits arrives without banner or screen coverage 3 s prior; a mid-skill stage 1 lands between 10 and 14 min; a precise player cannot land under 8; branch entry rate is neither near 0 nor near 1.

## Evidence limits

All constants cited to src/orchard/simulation.js, scene.js, main.js, and the docs above were read in this session. Every size, count, timer, and pattern in the grammar, the branch and defense and boss sections, the pacing map, the worked example, and the telemetry thresholds is a design proposal; none has fixture, playtest, or performance evidence. The Roll-Through deflect grades, the three-stage five-beat skeleton, the biome ladder, the Requisition premise, and the pressure roles are working canon from the 5 September audit, all pending Andrew's approval; the Rowkeeper is an existing taxonomy miniboss (ENEMY-TAXONOMY.md:136, 151) with no implementation. The 3.2 s label-horizon warning and the 8.6 s arena crossing are arithmetic on cited constants, not measurements of play. Two runtime gaps are load-bearing and observed, not designed around silently. First, groundHeight ignores x and samples z only (simulation.js:57-59), so multi-pocket terrain needs a terrain-field extension. Target signature: keep the existing groundHeight(x, z) call but resolve it per pocket, through a local height sample in each pocket record or a heightmap keyed by pocket_id. Acceptance test: each of stage 1's five pockets reports correct height at its own ramp band, with no cross-pocket bleed. Second, the global one-windup stagger (simulation.js:406-413) must become per-lane before any multi-lane defense wave can pressure as drawn; the target shape and acceptance test are in the defense section. Inference, uncited: the estimate that the chase camera reads about 30 to 40 u of ground ahead is judged from fov 65 and the 9 to 10.2 u chase distance (scene.js:87, 382), not from a captured frame.
