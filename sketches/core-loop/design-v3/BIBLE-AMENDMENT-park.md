# Bible amendment draft: the park and the Warden kinds

Status: **draft for Andrew's approval.** Nothing here is in `BIBLE.md` yet. When Andrew approves the stage storyboards and Warden sheets, and [TADR-011](../../../adr/TADR-011-park-terrain-and-warden-kinds.md) becomes Accepted, the coordinator applies the amendments he keeps, in place, as the 2 October harmonization was applied (`BIBLE.md:5`). The working design is [PARK.md](PARK.md).

Line numbers are `BIBLE.md` on `cand/alpha-w13` at 38ceda3. Each amendment gives where, the text now (quoted short), the proposed text (exact), and why. "Insert" adds text; "Replace" swaps the quoted sentence or passage.

## What the amendments do, in one table

| # | Where | Change |
| --- | --- | --- |
| 1 | Header, `BIBLE.md:5` | Records the harmonization |
| 2 | Game identity, `BIBLE.md:44` | A stage is an Arizona park |
| 3 | Five regions, `BIBLE.md:121` | The three worlds as parks; the societies that shaped them |
| 4 | Maps & Areas, after `BIBLE.md:177` | New subsection: how a park stage is built |
| 5 | Spillway Works, `BIBLE.md:207` | Park vocabulary for world one |
| 6 | Maps & Areas, after Spillway Works | Two short world pages: the Dig and the Highdraft |
| 7 | The complete loop, `BIBLE.md:473` | Wardens live in the landmark |
| 8 | Encounters, `BIBLE.md:519` | Four event families and their rules |
| 9 | Encounters, after `BIBLE.md:525` | New subsection: Wardens |
| 10 | Runs, regions, `BIBLE.md:580` | How stages are assembled |
| 11 | Music direction, `BIBLE.md:755` | Events land on the downbeat without delaying danger |
| 12 | AD-06, `BIBLE.md:655` | Societies terraformed the land; real cultures stay references |
| 13 | Glossary, `BIBLE.md:819-903` | New terms and places |

## 1. Header

**Where:** `BIBLE.md:5`, after "...and each world allows one retry."

**Insert:**

> On [approval date] the map, encounter and Warden passages were harmonized with Andrew's park decisions of 10 October 2026 (`adr/TADR-011-park-terrain-and-warden-kinds.md`, `sketches/core-loop/design-v3/PARK.md`): every stage is an Arizona park about 1.6 km square around one hero landmark, each world has one Warden kind in two mountings, and stage events come in four families from one table.

**Why:** the header already records each harmonization with its date and sources.

## 2. Game identity

**Where:** `BIBLE.md:44`. **Now:** "through open stages, each a bounded 3D space on momentum terrain that the player enters, roams for loot, secrets and threats, and leaves through an exit, with a boss in each world."

**Replace with:**

> through open stages, each a bounded 3D space on momentum terrain that the player enters, roams for loot, secrets and threats, and leaves through an exit, with a boss in each world. Each stage is a park: about 1.6 km of Arizona whose landforms work as skate-park furniture for a rolling ball, around one hero landmark seen from everywhere, where that stage's Warden lives.

**Why:** Andrew's seed of 9 October and his size call of 10 October.

## 3. Five regions

**Where:** `BIBLE.md:121`. **Now:** "The accepted run visits three worlds in a fixed order: Spillway Works, then the Dig underground, then the Highdraft's floating flotilla."

**Replace with:**

> The accepted run visits three worlds in a fixed order: Spillway Works, a canyon of dams, canals and flumes; then the Dig, an open-pit mine and the lava tubes and sinkholes beneath it; then the Highdraft's floating flotilla, mesas and buttes standing out of a cloud deck, strung with the animals' nets and cables, around one island that truly floats. Each world is two parks. Earlier societies terraformed every one of them: canal builders and cliff builders long ago, then miners and the dam crews, and now the Furnace Fleet. What they left is the park the player rides.

**Why:** the "floating flotilla" stays true without asking a heightfield to float: the cloud deck hides the low ground so the mesas read as islands, the barges stay the moving islands (`sketches/core-loop/src/world/map_highdraft.gd:3-8`), and one landmark island floats. The societies are Andrew's settled call (session plan, "Calls I make", society layers feed codex fragments).

## 4. New subsection: the park

**Where:** insert after `BIBLE.md:177` (the end of "Reading the catalogue"), before "### Yard Commons".

**Insert:**

> ### How a park stage is built
>
> A stage is a park about 1.6 km square. Every landform in it carries one thing the ball already does. Washes and slot canyons are half-pipes to pump. Canals, flumes and penstocks are grind lines the harpoon bites. Open-pit benches are bowls and terraces to bank around. Lava tubes and mine adits are tunnels and drops. Sinkholes and flooded shafts are caverns to swing through and drop into. Cliff dwellings and mesa rims are ledges and elevated lines. Mesas and buttes are hops between kickers. The player should be able to read each landform's verb from its shape before trying it.
>
> One hero landmark stands in each park, the tallest built thing in it, placed so it can be seen from almost anywhere. The Warden lives in it. It gives direction without arrows.
>
> Every enemy kind has a home in the landform that gives it the advantage, and the same shape offers a readable answer: brutes hold tunnel mouths a ram can break, lobbers hold ledges a harpoon can reach. Breaking a home stops that kind's arrivals on the stage.
>
> A park changes while the player rides it (section 6, Encounters). It always keeps a way through: a ball with no harpoon and no contraption can still reach the Warden, so no verb is ever compulsory and suspended paths never become required tightropes (Spillway Works, below).
>
> Time of day is fixed per stage, and the six stages make one day across a run, from dawn at the first dam to dusk among the last spires. Boss arenas are not parks; they stay authored and small. The run ends in an impact crater, a bowl modelled on Meteor Crater, the one landform older than any society.
>
> Each park is approved as a storyboard before its ground is built, greyboxed before it is dressed, and accepted only when a measured line for every pilot crosses it fast, airborne often and without a dead stop. A bot's numbers do not establish that a park is fun; play does.

**Why:** the park principle (Andrew, 9 and 10 October; principle 24 of 2 October), the floor-route rule (`BIBLE.md:177`, `207`, `243`), the storyboard and traversal gates Andrew accepted.

## 5. Spillway Works

**Where:** `BIBLE.md:207`. **Now:** "Terrain vocabulary includes river shelves, settling basins, channel bends, gate aprons and higher dry service routes."

**Replace that sentence with:**

> Terrain vocabulary includes river shelves, settling basins, channel bends, gate aprons and higher dry service routes. As parks, its washes and slot canyons are half-pipes, old canal lips and the flume are grind lines, the plunge pool below the dam is a bowl, and cliff dwellings in the canyon walls are ledges. Its two hero landmarks are the spillway dam and the penstock tower at the head of the flume. The green river corridor stays: the park is laid along it, not over it.

**Why:** stage 1 (`park_dam`) and stage 2 (`park_flume`) in PARK.md section 6. The rest of the Spillway page holds: floods and drains are already its stage events (`BIBLE.md:209`), and the dry route rule is the floor line.

## 6. New world pages: the Dig and the Highdraft

**Where:** insert after the Spillway Works page (before "### The Iron Orchard", `BIBLE.md:213`). These two worlds have no page today; the catalogue holds only Spillway Works of the three (`BIBLE.md:169`).

**Insert:**

> ### The Dig
>
> *World two of the accepted run. Key art follows the approved stage storyboards.*
>
> The Dig turns a route into a descent. Its first park is an open-pit copper mine about 900 m across and 150 m deep: stepped benches to bank around, a spiral haul road that is one long flow line, tailings benches, and adits that run into the walls. Its hero landmark is the headframe over the main shaft. Its second park is a plateau cut by lava tubes, adits and flooded caverns, where most of each line runs under a roof, opening onto a sinkhole 250 m wide with a column of daylight falling into its pool.
>
> Miners shaped the first park and water and old lava shaped the second. The swarm remnant, the ancient cause of the Dig, nests in both: hung on the hoist cable in the headframe and on the sinkhole wall above the pool. Noon heat and dust devils in the pit, mist and dripping water below.
>
> ### The Highdraft
>
> *World three of the accepted run. Key art follows the approved stage storyboards.*
>
> The Highdraft turns a route into a flight. Mesas and buttes 120 to 220 m tall rise out of a cloud deck, with the animals' net deck strung between them, thermals rising past their rims and cables crossing the gaps. Barges are the moving islands. Its first park's landmark is the one island that truly floats, held up from beneath by the Mind's hand. Its second park is a field of buttes, hoodoos and spires around the Crown spire, where the Mind's hand flies between three perches. Golden light on the islands, then a thunderstorm at dusk among the spires.

**Why:** stages 3 to 6 in PARK.md section 6. The Bible already names both worlds (`BIBLE.md:18`, `121`) without describing them.

## 7. The complete loop

**Where:** `BIBLE.md:473`. **Now:** "Each world has two zones with a Warden each and then a world boss."

**Replace with:**

> Each world has two zones with a Warden each, living in its zone's hero landmark, and then a world boss.

## 8. Encounters: event families

**Where:** `BIBLE.md:519`. **Now:** "Which events, weather and terrain consequences each region carries, and their frequency, overlap and intensity, remain open (Q-P24, Q-P38)."

**Replace that sentence with:**

> Stage events come in four families from one table per stage: natural (a flood fills a bowl, a cave-in opens a tunnel, a collapse drops a line, lightning strikes marked spires), Fleet incursion (a drill barge or dropship lands and sets up a new enemy home), ancient awakening (a buried machine erupts as a miniboss) and industrial (a boiler or reactor blows, a hazard that also changes the ground). They fire as the stage's difficulty rises and as its Warden fight turns. Every event announces itself with its own colour, shape and sound before it can touch the player, never stops the ball, and always leaves a way through. Weather changes what the player sees and hears and how often events come, never how the ball handles; wind that pushes is a marked lane the player chooses to ride. The starting set per stage is in the park design; frequency, overlap and intensity remain open, to be settled in play (Q-P24, Q-P38).

**Why:** Andrew's dynamic-stages call and the four families (session plan). The existing rules on this page (announce, rise and recede, readable layered chaos) stay as they are and cover the new families.

## 9. New subsection: Wardens

**Where:** insert after `BIBLE.md:525` (the end of "Encounters, waves and enemies"), before "### Four slots and milestone progression".

**Insert:**

> ### Wardens
>
> A Warden is the ancient machine that holds a zone. Each world has one Warden kind, its local ancient cause, shown in two mountings in its two zones: the reactor relic in Spillway Works (on the dam face, then in the flume's head house), the swarm remnant in the Dig (hung on the headframe's hoist cable, then nesting in the sinkhole), and the Mind's hand in the Highdraft (holding up the floating island, then flying between spires). A Warden takes its flavour from its landform, and each mounting adds one mechanism to play around: a water sheet to ride up the dam, a cage that rises and falls, a deck that tilts, a hand that moves between perches.
>
> Every Warden fights on one readable grammar. It announces a pulse before it fires. Pressure on it fills toward a stagger that opens its core. It breaks in chunks, at most one per stagger. The harpoon drop onto an open core is the finisher.
>
> Every Warden is also a harpoon anchor. The player can latch its hardpoints, ride the line, fire from the line, and be carried when the Warden or its mounting moves. A Warden may shrug a line off after a visible warning; letting go never costs the ball its speed.

**Why:** Andrew's Warden calls (session plan: three kinds, one per world, two mountings, every Warden a harpoon anchor); PARK.md section 7. Enemies are never reskins: each kind owns its body and mechanism.

## 10. Runs, regions, exits and saves

**Where:** `BIBLE.md:580`. **Now:** "Procedural technique remains open. Seeded authored encounter assembly and procedural terrain assembly are still candidate approaches."

**Replace with:**

> Stage ground is authored: each park is a table of landforms, homes, events, contraptions and weather, baked into terrain before play (TADR-011). Within it, encounters are seeded by the event director. Procedural terrain assembly is not used for the accepted worlds.

**Why:** TADR-011 chooses authored park tables; the director's seeded encounters are TADR-010's.

## 11. Music direction

**Where:** `BIBLE.md:755`. **Now:** "Danger must never wait for a beat." and "a short stinger can announce an event before it becomes dangerous".

**Insert after** "...weather carries its own ambience layer in each region.":

> An event's warning sounds at once, never quantized. Only its landing may wait for the next downbeat, by at most one bar, so the change in the world and the drop in the music arrive together; waiting lengthens the warning and never shortens it. Each event family carries its own sound: the stage's band for natural events, the Fleet's anvil and brass for incursions, the ancient cause's motif for an awakening, a steam whistle rising into a hit for an industrial blow.

**Why:** music drops tied to game moments (Andrew's principle) would otherwise contradict "Danger must never wait for a beat". This keeps both: danger's warning never waits, the landing lines up with the drop.

## 12. AD-06, Southwest landscapes

**Where:** `BIBLE.md:655`, after "Terrain influences where people build and how their machines move."

**Insert:**

> People also shaped the terrain. Arizona's works are the references for that layer: canals in the manner of the Hohokam, cliff dwellings in the manner of the Ancestral Puebloans, open-pit mines and headframes, and the dams, flumes and penstocks of the dam era. In the fiction, the canal builders and cliff builders are fictional predecessor peoples whose works echo those techniques. The Hohokam and the Ancestral Puebloans are real peoples whose descendants live in Arizona today, so their works are never enemy homes, loot or targets to destroy, and the codex describes the engineering and the water or stone it managed without claiming to speak for a living people. Mining, the dam crews and the Furnace Fleet carry no such limit.

**Why:** Andrew's society layers feed the codex. The Bible already keeps real references out of the fiction (`BIBLE.md:979`: references "do not assign real park names to the fictional map"); this extends the same care to real cultures and is enforced by the park schema (PARK.md section 2.10).

## 13. Glossary

**Where:** "Game, people, cultures and places" (`BIBLE.md:819-840`), "External references and technical names" (from `BIBLE.md:855`) and "Common system terms" (`BIBLE.md:888-903`), each alphabetized.

**Insert into "Game, people, cultures and places":**

| Canonical name | Status | Definition |
| --- | --- | --- |
| The Dig | Accepted world | World two: an open-pit mine and the lava tubes, adits and flooded sinkhole beneath it. Its Warden kind is the swarm remnant. |
| The Highdraft | Accepted world | World three: mesas and buttes over a cloud deck, nets, thermals and cables, one floating island. Its Warden kind is the Mind's hand; its boss is the Mind. |
| Mind's hand | Accepted Warden kind | The Highdraft's Warden kind: a hand of the Mind that holds up the floating island or flies between perch spires. |
| Reactor relic | Accepted Warden kind | Spillway Works' Warden kind: an ancient reactor seated on the dam face or in the flume's head house. |
| Swarm remnant | Accepted Warden kind | The Dig's Warden kind: an ancient swarm that hangs on the headframe's hoist cable or nests on the sinkhole wall. |

**Insert into "External references and technical names":**

| Name | Use in this Bible |
| --- | --- |
| Ancestral Puebloans | Reference for cliff dwellings as ledges and elevated lines. A real people with living descendants; never an inhabitant, enemy or loot source in the fiction. |
| Hohokam | Reference for canal lips as grind lines. A real people with living descendants; never an inhabitant, enemy or loot source in the fiction. |
| Madrean sky islands | Landscape reference for isolated mountains rising above desert, informing the Highdraft's islands. |
| Meteor Crater | Landscape reference for the run's ending bowl and the craters an impact event leaves. The in-game name is chosen with its storyboard. |
| Terrain3D | Technical name. The open-source (MIT) Godot terrain addon that draws park ground, cuts tunnel and cavern holes and supplies level of detail (TADR-011). |

**Insert into "Common system terms":**

| Term | Shared meaning |
| --- | --- |
| Enemy home | A place in a park that spawns one enemy kind and gives it an advantage; breaking it stops that kind's arrivals on the stage. |
| Hero landmark | The one tallest built thing in a park, seen from almost anywhere, where the Warden lives. |
| Mounting | Where and how a Warden sits in its landmark: open air, underground, in a building, suspended or flying. Each Warden kind has two. |
| Park | A stage built as about 1.6 km of Arizona whose landforms work as skate-park furniture for the ball, each carrying a verb the ball already has. |
| Stage event family | One of four kinds of stage change: natural, Fleet incursion, ancient awakening, industrial. |
| Warden | The ancient machine that holds a zone, fought on the posture grammar and usable as a harpoon anchor. |

## Not changed

- The five-region catalogue, its key art and its candidate status (`BIBLE.md:165-267`), apart from the two pages added for worlds outside it.
- The run's world order, retries and save rules (`BIBLE.md:576-586`), apart from amendment 10.
- AD-11's "Never turn every landscape into a scrap heap" (`BIBLE.md:685`): the park keeps each landform, its vegetation and its natural scale.

## For Andrew: keep or veto

These are the amendment's own calls. PARK.md section 11 lists the design calls.

1. **The Highdraft's "floating flotilla" becomes mesas over a cloud deck,** with barges as the moving islands and one island that truly floats (amendments 3 and 6).
2. **Procedural terrain assembly is dropped for the accepted worlds** (amendment 10).
3. **Events land on the downbeat;** the warning still never waits (amendment 11).
4. **Real cultures stay references,** with fictional canal and cliff builders in the game and no enemies, loot or destruction at their works (amendment 12).
5. **The Dig and the Highdraft get Bible pages now,** in prose, with key art to follow the storyboards (amendment 6).
