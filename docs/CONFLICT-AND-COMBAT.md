# Scrapkeep conflict and combat workshop

5 September 2026. Original design proposals informed by publisher interviews and cited reference material. This is an exploration document, not an approved roster, implementation specification, or session goal. [Publisher direction](DISCOVERY.md), [market research](MARKET-RESEARCH.md), [swarm record](COMBAT-DESIGN-SWARM.md).

## The exchange we want to create

An enemy prepares an action. The pilot reads its movement and machinery, chooses a route or defensive response, and creates an opening. Exploiting that opening changes the fight: armor comes loose, an enemy becomes a projectile, a weapon falls into the scrap pile, or an enemy machine becomes useful terrain. The run's items then change the consequences of the same learned actions.

The key design hypothesis is that **defending well should feed the rolling and scavenging fantasy**. It should give the player a better trajectory, a stronger collision, a valuable part, or room to deploy a device.

Andrew requested exploration of skill-based dodging, blocking/shield timing, enemy vulnerabilities and/or immunity. Earlier confirmed preferences include low-cooldown abilities, class-specific ultimate charging, capable enemies, and spectacular growth in battle scale. The balance among evasive movement, held guard and precise parries is still a publisher question. The following baseline assumes movement leads and timed guarding adds mastery; this is not an accepted control scheme.

## Conflict candidates

| Candidate | Opposition and motive | What the heroes protect | Relationship to expeditions |
| --- | --- | --- | --- |
| Furnace Fleet | Rival animal crews operate a traveling industrial city. Its failing engines consume ever more machinery, and its captains strip other settlements to keep their own city moving. | Working pumps, village power, seedhouses, stranded residents, and the odd old components that make local life possible. | Follow a regional harvesting operation, recover useful machinery, defend a restart or evacuation, then dismantle its major harvester. |
| Wildworks Bloom | An ancient gardener cultivates a repair organism that grafts plants and discarded machines together, even across inhabited settlements. | Homes and useful systems being absorbed into a vast mechanical ecosystem. | Explore different growth systems, salvage materials and defend isolation devices before confronting the organism sustaining that region's spread. |

The coordinator and faction designer favor the **Furnace Fleet** for this concept pass. A machine's original job naturally explains its attack, its weakness and the useful scrap it leaves behind. The rival crews can be funny, proud, competent and internally divided. This is a recommendation, not accepted canon. The [generated concept sheet](art/04-furnace-fleet-enemies.png) explores four machines; [its exact prompt and inspection notes](CONCEPT-STUDY-02.md) distinguish visual exploration from gameplay or model assets.

One optional recurring antagonist is **Admiral Brindle**, a small badger commanding a furnace-city far larger than any animal should need. Brindle keeps promising that one more harvest will make the city secure. The heroes discover that the next harvest always contains somebody else's home. The conflict can remain immediately understandable while individual captains negotiate, defect or take a rivalry personally. Names, species and characterization are exploratory.

The Fleet's threat explains local defense objectives without requiring a constant global countdown. The immediate task may be keeping a pump running, protecting a companion assembly station, or holding a loading point during a recovery. Optional branches remain meaningful within the chosen 30–45-minute expedition. A completed regional operation can leave other fleet routes and captains as later challenges; the exact narrative reset and run ending remain open.

The Bloom offers stranger biological environments, but its rules need more explanation. It remains an alternative rather than a second faction automatically added to production scope. Crew cabins ejecting before machinery breaks is an optional tone idea, not a required rescue subsystem.

## First enemy family

These six regular enemies and one large harvester are a design palette, not a requirement to put seven jobs into one encounter. Ordinary steering, bumping and an aimed attack provide the baseline counters. Each tell leads to a commitment and recovery. More durable versions alone do not constitute meaningful variety.

| Enemy and visual identity | Job and visible action | Common answers | What it leaves or changes |
| --- | --- | --- | --- |
| **Scooplet**: low bucket tricycle with an overflowing basket | Collects unclaimed loose scrap. Its scoop rattles open, sweeps a straight route, then pauses to unload. | Bump its side during the sweep; hit its basket latch during unloading. | A spilled, collectible load and a scoop-themed pickup component. A later linked scrap train makes interception angle matter. |
| **Plowback**: broad split plow ahead of a narrow chassis | Escorts a column. Stabilizers lower, it drives a committed line, then the plow opens to vent. | Flank its rear; hit the central mechanism while it vents. | The plow becomes a bank surface before it is collected as armor. An offset pair changes the available approach. |
| **Pegjack**: tall stapler head on spindly legs | Pins temporary guide rails across useful routes. A stripe previews the rail before the hammer falls. | Bump a leg before anchoring; shoot the retraction crank afterward. Ordinary attacks also break its rails. | Construction pins and new route geometry. A later fork redirects traffic rather than sealing the entire arena. |
| **Bellows Skimmer**: airbag on skids with an oversized nozzle | Pushes targets out of useful lines. The bag inflates, nozzle direction locks, then it exhales and lands deflated. | Cross its line before the jet; hit its intake or ram its landing recovery. | A lift or knockback component. A later suction variant uses a visibly different nozzle posture. |
| **Spoolmender**: walking sewing machine with a bright spool | Reconnects disabled enemy modules with a visible cable while stationary. | Sever the cable with an ordinary shot; bump it out of position. | A support component for a companion. It only repairs uncollected enemy parts; earned player parts stay secure. |
| **Clampcart**: forklift jaws around an empty cradle | Captures a deployed device through a visible mark, closing ratchet and slow retreat. | Hit a hinge during closure; ram its side to tip the cart and release the device. | A clamp module. Captured infrastructure stays visible and recoverable; later escorts complicate the rescue route. |
| **Kiln Strider**: furnace torso on enormous industrial legs | A large harvester reaches for the defended system. Glow and ground shadow precede a committed step or intake; cooling shutters open afterward. | Hit a reachable cooling mechanism; roll an industrial weight into the planted joint. | Armor becomes ramps and the recovered heart supplies a major reward. Later attacks change one route at a time. |

Kiln Strider is an alternative large-encounter concept alongside the major bosses below, not an additional mandatory boss. Enemy collection, repair and theft should create occasional contested decisions. Combining all of them continuously would make the run a maintenance exercise.

Primary-source patterns include enemies with different objectives in [Robot Entertainment's enemy-design article](https://robotentertainment.com/news-archive/2024/10/7/enemies-enemies-enemies), and an arming interval that gives the defender a response in [Valve's Sentry Buster description](https://www.teamfortress.com/mvm/machines/). The Fleet machines and their specific mechanics are original proposals.

## Minibosses

### Sluiceback, the spillway lesson

A squat drain-clearing machine wears overlapping sluice-gate plates, an armored shovel nose and oversized valve wheels. Start with one charge across an open banked basin. Its reversing wheels, lowered shovel and accelerating rattle announce commitment. The player can cross the lane, use a buttress or scrap skip, then strike its exposed flank during the skid.

Its armor reduces damage rather than making the whole body invulnerable. An ordinary aimed attack can break a hinge; a banked ram can loosen a side; baiting a charge into a skip creates a third opportunity. A removed plate stays removed. The player sees that side's shove weaken and gains a broader contact surface.

The next pattern adds one planted side brace. After it breaks, Sluiceback can perform a second charge with a separate tell. The first version should test a single charge before adding that sequence. Contact with the lowered attacking shovel is dangerous; ordinary rear contact remains useful for ramming.

A bumper can improve the bank angle, and a companion can prime a hinge or interrupt a charge. Neither is required. Proposed reward **Valve Wheel** lets braking after a meaningful enemy impact store a sideways release, discharged as a shove during the next deliberate turn. Whether this feels controllable needs testing.

### Bellows Maw, the pressure lesson

A ventilation machine with an accordion torso and two intake shutters draws in loose scrap, then coughs out compressed bundles. Fabric strips and expanding bellows show suction direction; compression and a whistle announce its shot.

Cross the intake cone, shelter behind a plinth, damage an open shutter, or push a cart into the intake to jam it. Breaking one shutter permanently removes that intake. The surviving side changes the geometry and alternates focused suction with a slower bundle shot. Loose bundles become objects the player can redirect after landing.

The vacuum does not strip the player's accumulated body, and ordinary ground routes must allow an escape. A companion can mark the active shutter, while devices hold a side lane. Proposed reward **Accordion Lung** turns a firm landing into a short shove-and-collection cone. Bellows Maw should not accompany Sluiceback until their forced movement and dodge lanes have been tested together.

## Major bosses

### Counterweight Crown, the foundry siege

A traveling crane spans the foundry. Three low counterweight carriages follow a curved track under a colossal furnace hammer. The player remains within normal mech-scale routes while interacting with machinery that controls a much larger threat.

Teach the player to disrupt one carriage at a bend. Latches take ordinary damage; a well-placed ram or rolling slag drum can also damage the assembly. Broken supports stay broken, weaken the hammer and leave useful wreckage. No waiting-only weak-point window is required.

The next exchange offers a choice between attacking another carriage and diverting a slow strike at a nearby relay. The bell, descending hook and persistent footprint announce the hammer. Leave the footprint; use a bulkhead against the debris wave. The hammer is a spatial hazard, not a required parry test.

With one carriage left, a visible stop-and-switch changes track direction. Broken wrecks supply new bank angles. The relay sits on the current combat loop and has one local approach for infrastructure to cover. In this proposed encounter, losing the relay removes an environmental advantage rather than immediately failing the expedition. Other defense objectives may have different stakes, communicated before combat.

Proposed reward **Counterweight Heart** loads a visible weight through meaningful collisions; a committed skill shot releases that force through the attack's existing geometry. This connects mechanical destruction, precision combat and run growth.

### The Grand Pruner, the walking orchard

A migrating mechanical greenhouse carries broad terraces around a central seedhouse. Huge branch arms operate outside the rolling routes; reachable pruning assemblies and irrigation machinery create the actual fight. This can fit a Fleet-controlled harvester or the alternative Bloom conflict. It should have one chosen story role later.

A single branch sweep teaches the first exchange. Shaking leaves, straightening joints and spinning teeth announce it. Ground routes lead behind buttresses or inside the arm's elbow. The player rams a retracted housing or attacks its slats, while an active cutter remains dangerous.

An irrigation surge, previewed through ripples, later changes the best route. Slats can be shot away, peeled with repeated housing impacts, or struck with a pushed irrigation cart. Breaking a pruning assembly folds it into a ramp. The finale combines the established attacks along routes the player helped create.

Ordinary paths connect every required terrace. Grapple, hover and infrastructure supply additional approaches. The player does not need to defend a distant second objective during the demanding personal encounter. Damage can finish the boss without executing every terrain trick, and earned power may shorten or skip familiar exchanges.

Proposed reward **Graft Spool** links an impact point to the next deployed device; displaced enemies crossing the temporary link trigger a compatible device effect. This is the most complex reward proposed here and would need careful readability and effect-composition work.

The bosses borrow the general ideas of removable components and multiple approaches described by [Guerrilla](https://blog.playstation.com/2021/11/08/rebuilding-the-awe-inspiring-machines-of-horizon-forbidden-west/), and combat-time construction described by [Dungeon Defenders' designer](https://blog.playstation.com/2011/10/03/dungeon-defenders-takes-over-psn-october-18th-with-move-3d-support/). Their names, sequences and rewards above are original proposals. The existing demo's Cancrusher, Glassjaw and Old Ironroot names remain available; no rename is committed.

## Shared defensive rules to explore

### Contact, damage and recovery

Ordinary body contact produces a bump, ram or shove. Damage comes from an enemy's readable committed attack or visibly hazardous machinery. Small enemies should remain satisfying to bowl through. A crusher's closing jaws can hurt; simply touching its harmless rear body should not secretly deal the same damage.

Separate visible scrap wobble from loss of player control. Reserve hard stagger for clearly signaled heavy attacks, and allow a chance to steer or defend after receiving one. Repeated contacts from the same impact should not become repeated unavoidable hits. The length and form of recovery protection require a playable test.

The current demo already distinguishes bug, runner, tank and boss enemies through statistics and size, then advances them along a common path. It applies player ram damage during overlap. The new active attack and defense concepts would be new behavior, not a description of what is already playable. See [enemy creation](../src/game.js#L446), [path movement and ram handling](../src/game.js#L715), and [existing sector and boss names](../src/campaign.js#L21).

### Rolling, dodging and guarding

Every class should have a useful baseline answer before receiving loot. Ordinary steering and braking create space. A directional burst provides a stronger evasive move with an understandable exit trajectory. Compare purely spatial evasion against a brief protected interval for discrete attack contact; neither is selected yet. A burst must not allow the player to remain safely inside a sustained hazard.

A held scrap guard folds plates toward the aimed threat while the ball can still drift. Impacts visibly strain it. Raising the guard near impact could reduce strain and store energy for the next ram. An early guard still helps against ordinary attacks. A perfect timing reward should never be the only way to finish an ordinary encounter.

Guard direction should be visibly understandable even as the shell spins. How aiming, braking, firing and guard input interact belongs in the controller test. Do not assign exact buttons, frame windows, damage percentages or resource timings from this document.

| Proposed attack family | What the player can read | Baseline answers | Rewarding opening |
| --- | --- | --- | --- |
| Strike or single shot | Raised tool or distinct muzzle charge, then a committed path | Roll outside the path; face and guard; burst across the committed attack | Follow-through or reload exposes a mechanism |
| Heavy guard breaker | Braced silhouette, forceful windup and broken-shield cue | Leave its footprint; interrupt an exposed mechanism where the attack permits it | A miss leaves the attacker planted or overextended |
| Clamp or tether | Open jaws or cable launcher with a grab cue | Break range or line of sight; dodge across the released trajectory; interrupt windup | A failed grab exposes the reel or hinge |
| Ground hazard or sustained beam | Visible boundary, direction and activation cue | Move out; use terrain; interrupt its source where possible | The source is committed while projecting the hazard |
| Volley or sweep | Audible cadence and a visible sweep direction with gaps | Use the gaps, cover and short guards; dodge one contact while exiting | Reload or end-of-sweep recovery |

Enemy animations, sounds and shape cues should reinforce one another. Color alone should not encode the answer. Establish when an attack stops tracking the player. An upgraded enemy can add a new follow-up, but must visibly teach that change.

The reference distinction between guarding, guard counters and parries comes from [Bandai's Elden Ring starter guide](https://en.bandainamcoent.eu/elden-ring/news/elden-ring-starter-guide-tips-know-playing-the-game). The value of distinguishing unguardable attack responses appears in [FromSoftware's Sekiro manual](https://www.fromsoftware.jp/manual/sekiroshadowsdietwice/stadia/action2.html). These support different defensive choices, not a decision to adopt those games' rhythms.

## Vulnerability, armor, resistance and immunity

Give important protections at least two class-independent answers. Class powers and loot can create faster, stranger, or more rewarding answers.

| Protection | Broad answer | Alternative answer | Visible consequence |
| --- | --- | --- | --- |
| Directional shield | Roll around its protected arc | Bait its attack and hit the exposed recovery | The shield moves, dents, detaches or changes ownership as salvage |
| Breakable armor | Sustained ordinary attacks eventually break it | Aim at a joint or use a deliberate high-speed ram | An actual plate comes off and the protected attack changes |
| Projected ward | Attack or ram the exposed emitter | Exploit a visible opening during the carrier's attack | The emitter breaks or the ward visibly retracts |
| Elemental resistance | The element still damages it, less efficiently | Break the visible resistance device or expose an unprotected area | Insulation, grounding equipment or cooling gear changes physically |
| Resistance to repeated displacement | Continue doing damage | Break a brace or exploit its committed attack | A brace and its recovery state explain why the same shove behaves differently |

Whole-enemy elemental immunity is a poor default for a run that may specialize in one damage type. Short protection can work when its cause is obvious and the player can end or bypass it through a common action. Avoid long boss-wide immunity that merely makes the player wait. A plate blocking damage does not require the entire enemy to become invulnerable.

Distinguish damage from status and movement. A huge boss may resist being flung across the arena while lightning still hurts it and contributes to a visible stagger or overload response. This is a proposal; the exact status model remains open. Do not silently change damage rules when a player assembles an exceptional combination.

Precision should improve the result. It can remove a weapon sooner, preserve a better component, or create a longer opening. Ordinary competent play must still progress. [Guerrilla describes detachable collectible components and different machine behaviors](https://blog.playstation.com/2017/02/24/the-making-of-horizon-zero-dawns-machines/). [Monster Hunter Wilds' official guide describes wounds, targeted destruction and material rewards](https://www.playstation.com/en-us/games/monster-hunter-wilds/monster-hunter-wilds-starters-guide/). Scrapkeep's proposal extends that relationship into physical collection with the ball.

## Class advantages and loot interactions

| Class fantasy | How it can exploit a common opening | Proposed ultimate contribution |
| --- | --- | --- |
| Grapple | Redirect a committed charge, swing behind a shield, pull a loosened part into a collision route | Useful displacement, successful trajectory attacks and contested salvage |
| Hover mortar | Cross a ground threat in a short airborne arc and designate an exposed mechanism | Well-placed bombardments and coordinated infrastructure volleys |
| Cyborg laser | Line up exposed joints and nearby enemies, or use a prism to attack around a shield | Accurate piercing shots and redirected hits on important openings |
| Lightning | Use a loosened conductive part or primed enemy to extend a chain through a formation | Effective chains and purposeful network discharges |

These are advantages, not exclusive keys. Every boss route must work with baseline movement and attacks. An inaccessible weak point cannot require the hover class; a shield cannot require lightning. No exact ultimate accounting is settled, and safe repetitive farming should not be the fastest intended charge method.

Examples of proposed shared loot: a spring plate turns a successful guard into a stronger rebound; an echo module repeats a compatible impact effect; a magnet catches nearby loosened parts along the exit path. Class items can change those consequences while preserving recognizable controls. The counterplay system must leave room for a strong build to kill quickly, disable a group, or skip a familiar pattern.

Companions should prime, support or rescue visibly. A companion can brace one side of a threatened defense, mark a vulnerable component, or interrupt a charge to open an escape. Its clutch intervention should create an action the player can take. A solo encounter's essential escape cannot depend on finding a particular companion part.

## Encounter pressure and readability

Think about enemy combinations by the decisions they create. One pursuer plus one lane-shaping attacker can create an interesting route choice. Adding several overlapping pulls, ground hazards and guard breakers can erase every response. The designer must check the escape paths in the actual camera and geometry, including the largest ordinary ball size.

Use a constraint on simultaneous committed attacks rather than assuming every visible enemy must attack at once. Other enemies can reposition, carry scrap, threaten a device, or prepare the next exchange. This is a design rule to test, not a proposed fixed count. Attacks that demand incompatible reactions must not arrive together without an available route out.

Offscreen enemies need clear approach cues and enough time to enter the player's awareness. Keep the current danger readable above loot, companion and ultimate effects. Camera control, reduced shake and effect density belong in testing. Guerrilla's combat explanation describes distinct audio cues for melee and ranged machine attacks, a useful primary-source pattern for this work. [Horizon Forbidden West combat article](https://blog.playstation.com/2021/12/06/horizon-forbidden-west-outsmart-your-enemies/).

During a boss's demanding personal attack, the defense objective should not simultaneously require an immediate intervention elsewhere. Alternate which problem demands attention. Infrastructure can buy an opportunity to pursue salvage or exploit a boss opening, but should not be routinely erased by unavoidable map-wide attacks.

Elite variants should add a readable job or follow-up: a charger can tow cover for another enemy; a projector can relocate its emitter; a scavenger can leave a traceable escape route. Avoid stacking random properties that obscure the base enemy or invalidate a class.

## Evidence and open choices

All new behaviors are paper designs. No fun, timing, balance, AI implementation or performance claim is verified. The comparison sources establish reference mechanics; they do not establish that our combination will work.

Publisher input still needed: preferred defensive rhythm, a favorite fight to unpack, and the intended late-run relationship between hero size and world scale. A conflict/faction choice follows the candidate comparison, rather than silently becoming canon.

## Recommended first design experiment

Use Sluiceback in one banked basin with the baseline ball, an ordinary aimed attack, a movable skip and an optional bumper. Compare evading the charge, exploiting its recovery and breaking a plate through different approaches. Add the proposed timed-guard reward only as a comparison against an appropriate ordinary attack, not as a way to parry every crusher or heavy hazard.

Then repeat with a dense late-run scrap silhouette and one behavior-changing item. Check whether the player can identify the danger, choose an exit, understand why a collision succeeded, and explain what the item changed. A later composition can add one Plowback, then a clearly announced Clampcart intervention. Do not introduce suction until its combination with the charge has a valid, readable escape route.

This is a candidate for a later build goal. No prototype was created in this pass. A fresh Astra reviewer found no concrete class lock, required companion, forced-motion loop or distant mandatory objective in the paper designs. That review does not prove the timings or spatial layouts work. It did identify wording that could overstate the confirmed defensive preference; the opening paragraph now records these mechanics as requested exploration.
