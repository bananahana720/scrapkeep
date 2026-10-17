# Lore alpha draft: the six park stages and the three worlds

**Status: DRAFT for Andrew's review. Nothing here is approved or ported.** Written 2026-10-16 on `claude/lore-alpha-draft-k6merj` from `main` at `77b99de`. The alpha scope puts story work after Andrew's playtest sitting, so this file waits for that sitting. Andrew marks each row keep, change or cut. The coordinator then ports the kept rows into `src/core/lore_rows.gd`. This file edits no game code.

Sources:

- Row shape, kinds and word caps: `src/core/lore_rows.gd`. The caps are exchange 14, field note 40 and intro 12 words. `content_registry.gd:437-440` counts words by spaces, and this draft counts them the same way.
- Voice: [LORE-TONE-SAMPLE.md](LORE-TONE-SAMPLE.md), approved 2026-10-04. Dry work-crew notes and shift logs with a quiet wrong thing underneath.
- Cast: `docs/CHARACTER-BIBLE.md` (repo root) and [pilots/](pilots/). Moss is the depot provisioner. Brindle is a badger who speaks in ledger arithmetic, rounds every number up, thanks regions as if they volunteered and never threatens. The Fleet calls everything inventory. Nobody is evil, and machines are workers.
- Stage facts: [park/stages/](park/stages/), sections 1 to 3 of each sheet. Each sheet's codex-fragment table holds a separate set of lines. No row here repeats a fragment from those tables.

## How the rows map to the game

| Zone | Stage | Park map | Warden | Boss intro plays here |
| --- | --- | --- | --- | --- |
| 1-1 | 1 | `park_dam` | reactor on the dam face | no |
| 1-2 | 2 | `park_flume` | reactor, meltdown, in the head house | yes, Brindle |
| 2-1 | 3 | `park_pit` | swarm hive on the headframe hoist | no |
| 2-2 | 4 | `park_sinkhole` | swarm, brood, over the caisson pool | yes, the Waking |
| 3-1 | 5 | `park_islands` | the Mind's hand under the Hanging Isle | no |
| 3-2 | 6 | `park_crown` | the Mind's hand on the three perch spires | yes, the Mind |

The zone is `world-local`, as `moss_bubble.gd:123` builds it. The stage numbers come from `src/core/park_defs.gd:73-124`.

## Port notes for the coordinator

These facts about today's code decide how the rows go in. Each one cites the line that shows it.

1. **One exchange per zone.** `moss_bubble.gd:126-132` plays only the first exchange id it meets in a zone. `codex.gd:291-293` marks every exchange row in the zone as heard. A second exchange in a zone never plays, but it shows as heard. So a park exchange replaces the zone's old exchange. Do not add it next to the old one.
2. **One intro of each kind per zone.** `moss_bubble.gd:162-166` takes the first warden intro and the first boss intro in each zone. A park intro goes in ahead of the old one or replaces it.
3. **Boss intros play only in a world's last zone.** `_on_boss_arena_entered` (`moss_bubble.gd:154-155`) uses the zone the arena opens in, and only the last stage of a world opens the arena. Today's boss intros in 1-1, 2-1 and 3-1 (`lore.spillway.intro.brindle`, `lore.dig_entry.intro.waking` and `lore.highdraft_deck.intro.mind`) never play. This draft writes boss intros for 1-2, 2-2 and 3-2 only.
4. **Field notes come up in row order.** `codex.gd:297-310` hands out the next unknown note of the zone in row order. Park notes added after the old notes come up last. Put them first if the park should speak first.
5. **Keep zones grouped.** `codex.gd:299-302` orders zones by their first row. Put each new row inside its zone's block.
6. **Re-pin the table hash.** `content_registry.gd:92` pins a hash of `lore_rows.ROWS`, so the hash changes with any port.
7. **The world rows are field notes.** The table has no world-level kind. Each world's three notes go in that world's first zone (1-1, 2-1, 3-1), with ids under `lore.world_*`. A new kind would need code, so this draft adds none.

### Old rows the park stages contradict (Andrew's call)

The old rows were written for the old stage maps. Most still fit the parks. These do not:

| Zone | Old rows | Why they clash | Suggestion |
| --- | --- | --- | --- |
| 1-2 | the whole `lore.reach.*` set: the cable crew exchange, the seven notes, the "Cable Reach Warden" intro and the Brindle cableway intro | `park_flume` has no cableway, shaft or bell. It is a wooden flume on trestles that ends at a penstock tower and head house. | Replace the set with the `lore.park_flume.*` rows below. Two of the old lines are approved sample lines (tone sample, Spillway lines 7 to 10). Andrew decides if they move or retire. |
| 3-2 | `lore.highdraft_core.note.1` to `.3`, `.6` and `.7` (islands, long bridge spans, the barge, the middle island) | `park_crown` is buttes, a bajada and spires under a storm. The islands are stage 5. The crown sheet says the old lines stay. | Keep them if Andrew reads the crown as more of the Highdraft. Otherwise move them to 3-1 and let the park rows lead. |

## The rows

Each block is ready to paste into `ROWS` in `lore_rows.gd`. The word counts are in the check table at the end.

### Stage 1, the dam (zone 1-1)

Facts used: a dawn drop-in from a survey deck, three runs through slot canyons and a lined wash, the Eye in a sandstone fin, the construction incline, a 120 m dam face that works as a quarter pipe, a relic clamped 22 m up, and spillway gates that open on each pulse to run a water sheet up the face. A Fleet dropship lands on the east bench.

```gdscript
	{
		"id": "lore.park_dam.moss.deck", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.park_dam.exchange", "speaker": "Moss", "skippable": true,
		"text": "Long drop from the deck. I'll be at the toe with a seal.",
	},
	{
		"id": "lore.park_dam.crew.gates", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.park_dam.exchange", "speaker": "Dam crew", "skippable": true,
		"text": "Gates opened at dawn. Nobody on the wheel.",
	},
	{
		"id": "lore.park_dam.moss.wheel", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.park_dam.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then ride the water up. Leave the wheel alone.",
	},
	{
		"id": "lore.park_dam.note.gate_log", "kind": "field_note", "zone": "1-1",
		"text": "Gate log: spillway gates opened four times before breakfast. Wheel chained. Chain still warm.",
	},
	{
		"id": "lore.park_dam.note.plumb", "kind": "field_note", "zone": "1-1",
		"text": "Survey deck: plumb bob hangs toward the dam. Wind from the south. Bob reported to the foreman.",
	},
	{
		"id": "lore.park_dam.note.slot", "kind": "field_note", "zone": "1-1",
		"text": "Slot canyon tag: flood line painted at the narrows. Line repainted higher each season. The rim has not moved.",
	},
	{
		"id": "lore.park_dam.note.eye", "kind": "field_note", "zone": "1-1",
		"text": "Eye inspection: wind through the fin whistles one note. Crew tuned the compressor to match. Compressor now refuses other notes.",
	},
	{
		"id": "lore.park_dam.note.incline", "kind": "field_note", "zone": "1-1",
		"text": "Incline ticket: brake shoes replaced. Bucket went down anyway. Bucket came back up full of river.",
	},
	{
		"id": "lore.park_dam.note.apron", "kind": "field_note", "zone": "1-1",
		"text": "Toe apron stencil: STAND CLEAR OF THE FACE. Chalk tally underneath counts the balls that didn't.",
	},
	{
		"id": "lore.park_dam.note.fleet", "kind": "field_note", "zone": "1-1",
		"text": "Fleet docket: east bench cleared for landing. Dam listed as surplus concrete. Relic listed twice.",
	},
	{
		"id": "lore.park_dam.intro.warden", "kind": "intro", "zone": "1-1", "subject": "warden",
		"text": "Dam Warden. Gates open on its count, not ours.",
	},
```

### Stage 2, the flume (zone 1-2)

Facts used: a weir on a mesa feeds a 1.6 km wooden flume on trestles, with a siphon under the hollow, a rim road over a horseshoe bend, and crew bunks and crane booms on the mesa face. The flume ends at a 90 m penstock tower and a head house drum, where the relic boils the flume's last channel into slag lanes. A Fleet dropship lands on the south bench. Brindle's arena follows.

```gdscript
	{
		"id": "lore.park_flume.crew.warm", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Flume crew", "skippable": true,
		"text": "Flume's running warm today. Fish came down the trestles cooked.",
	},
	{
		"id": "lore.park_flume.moss.flask", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then don't drink from it. I packed you a flask.",
	},
	{
		"id": "lore.park_flume.crew.weir", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Flume crew", "skippable": true,
		"text": "Flask's warm too. You filled it at the weir.",
	},
	{
		"id": "lore.park_flume.note.weir", "kind": "field_note", "zone": "1-2",
		"text": "Weir gauge: reservoir steady. Flume carrying more than the weir lets through. Difference logged as rain. No rain.",
	},
	{
		"id": "lore.park_flume.note.bents", "kind": "field_note", "zone": "1-2",
		"text": "Trestle crew: bents numbered downhill. Count comes out one higher walking back up.",
	},
	{
		"id": "lore.park_flume.note.siphon", "kind": "field_note", "zone": "1-2",
		"text": "Siphon card: water goes under the hollow and comes up warmer. Pipe is cold the whole way.",
	},
	{
		"id": "lore.park_flume.note.milepost", "kind": "field_note", "zone": "1-2",
		"text": "Rim road milepost: someone painted the bend's depth on it. Crossed out. Painted deeper.",
	},
	{
		"id": "lore.park_flume.note.boom", "kind": "field_note", "zone": "1-2",
		"text": "Crane boom log: boom 3 locked for the night. Found swung toward the tower by morning. Lock still on.",
	},
	{
		"id": "lore.park_flume.note.drum", "kind": "field_note", "zone": "1-2",
		"text": "Head house log: flume poured onto the drum floor all shift. Floor dry by supper. Drains never fitted.",
	},
	{
		"id": "lore.park_flume.note.fleet", "kind": "field_note", "zone": "1-2",
		"text": "Fleet tally: flume flow, eleven hundred buckets an hour. Rounded to twelve. Crew asked where the hundred went.",
	},
	{
		"id": "lore.park_flume.intro.warden", "kind": "intro", "zone": "1-2", "subject": "warden",
		"text": "Head House Warden. Flume boiling. Flow still logged as normal.",
	},
	{
		"id": "lore.park_flume.intro.brindle", "kind": "intro", "zone": "1-2", "subject": "brindle",
		"text": "Brindle: A boiling flume. Twelve hundred tons of steam. Thank you.",
	},
```

### Stage 3, the open pit (zone 2-1)

Facts used: a copper pit at noon, with five benches, a spiral haul road, heat shimmer, dust devils from clock tier 2 and turquoise seams on the faces. A 120 m headframe has two sheave wheels, and the hive rides its hoist rope up and down. The pit also has a conveyor gallery and a hoist house. A Fleet drill barge lands on bench 3.

```gdscript
	{
		"id": "lore.park_pit.moss.noon", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.park_pit.exchange", "speaker": "Moss", "skippable": true,
		"text": "Noon in the pit. I filled your tank and wet your hat.",
	},
	{
		"id": "lore.park_pit.crew.bell", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.park_pit.exchange", "speaker": "Bench crew", "skippable": true,
		"text": "Hoist bell rang at the collar. Cage hasn't come up since.",
	},
	{
		"id": "lore.park_pit.moss.benches", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.park_pit.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then go down by the benches. Leave the cage to it.",
	},
	{
		"id": "lore.park_pit.note.haul", "kind": "field_note", "zone": "2-1",
		"text": "Haul road log: last truck down at shift end. Engine heard climbing all night. No truck at the top.",
	},
	{
		"id": "lore.park_pit.note.rope", "kind": "field_note", "zone": "2-1",
		"text": "Hoist ticket: rope paid out to the collar. Drum kept turning. Rope length now exceeds shaft.",
	},
	{
		"id": "lore.park_pit.note.sheave", "kind": "field_note", "zone": "2-1",
		"text": "Sheave inspection: both wheels true. One turns when the other stops. Rope not threaded yet.",
	},
	{
		"id": "lore.park_pit.note.devil", "kind": "field_note", "zone": "2-1",
		"text": "Dust devil report: spun up on bench 2, crossed the floor, climbed the haul road at posted speed.",
	},
	{
		"id": "lore.park_pit.note.seam", "kind": "field_note", "zone": "2-1",
		"text": "Face survey: turquoise seam on the north wall moved a bench lower overnight. Survey pins stayed put.",
	},
	{
		"id": "lore.park_pit.note.belt", "kind": "field_note", "zone": "2-1",
		"text": "Conveyor sign-out: belt stopped for lunch. Lunch tins arrived at the hoist house anyway.",
	},
	{
		"id": "lore.park_pit.note.fleet", "kind": "field_note", "zone": "2-1",
		"text": "Fleet docket: drill barge assigned to bench 3. Pit listed as a hole, pre-dug. Crew credit withheld.",
	},
	{
		"id": "lore.park_pit.intro.warden", "kind": "intro", "zone": "2-1", "subject": "warden",
		"text": "Headframe Warden. Hive rides the hoist. Nobody on the brake.",
	},
```

### Stage 4, the sinkhole (zone 2-2)

Facts used: a basalt plateau over lava tubes, lit only by skylights, with a great room cavern and cave mist all afternoon. A monsoon cell arrives from clock tier 2. The sinkhole has a timber gallery ring at the 100 m mark and a caisson pool. The brood nests over the pool, and the pool rises one step each time the brood loses a chunk. A Fleet drill barge bores down from the east plateau. The Waking's arena follows.

```gdscript
	{
		"id": "lore.park_sinkhole.moss.skylights", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Moss", "skippable": true,
		"text": "Long dark ride today. I'll hang a lamp at every skylight.",
	},
	{
		"id": "lore.park_sinkhole.crew.caisson", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Pump crew", "skippable": true,
		"text": "Pumped the caisson dry at shift change. It's filling from the bottom.",
	},
	{
		"id": "lore.park_sinkhole.moss.ring", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then get your boots up on the gallery ring.",
	},
	{
		"id": "lore.park_sinkhole.note.skylight", "kind": "field_note", "zone": "2-2",
		"text": "Skylight log: noon light through skylight three. Lamp swarm under it went dark. Then lit, one at a time.",
	},
	{
		"id": "lore.park_sinkhole.note.echo", "kind": "field_note", "zone": "2-2",
		"text": "Great room ticket: echo test passed. Shout returned in the foreman's voice. Foreman was outside.",
	},
	{
		"id": "lore.park_sinkhole.note.ring", "kind": "field_note", "zone": "2-2",
		"text": "Gallery ring card: hundred-metre shelf checked. Water mark on the timbers sits above the shelf. Pool has never reached it. Yet.",
	},
	{
		"id": "lore.park_sinkhole.note.mist", "kind": "field_note", "zone": "2-2",
		"text": "Mist report: cave mist settles in rings above the pool. Ring count matches the pump strokes. Pump is off.",
	},
	{
		"id": "lore.park_sinkhole.note.monsoon", "kind": "field_note", "zone": "2-2",
		"text": "Monsoon card: rain poured into the sinkhole all afternoon. Pool level unchanged. Gauge noted it was busy.",
	},
	{
		"id": "lore.park_sinkhole.note.rack", "kind": "field_note", "zone": "2-2",
		"text": "Lamp rack: every lamp hung back facing the sinkhole. The rack faces the door.",
	},
	{
		"id": "lore.park_sinkhole.note.fleet", "kind": "field_note", "zone": "2-2",
		"text": "Fleet docket: drill barge to bore the east plateau. Hole requested for the hole below. Request approved in duplicate.",
	},
	{
		"id": "lore.park_sinkhole.intro.warden", "kind": "intro", "zone": "2-2", "subject": "warden",
		"text": "Brood Warden. The pool rises a step each time it breaks.",
	},
	{
		"id": "lore.park_sinkhole.intro.waking", "kind": "intro", "zone": "2-2", "subject": "waking",
		"text": "Waking: The pool was mine first. You may keep the lamps.",
	},
```

### Stage 5, the sky islands (zone 3-1)

Facts used: pine-topped mesas at golden hour, with a net deck strung under every gap and thermals, cables and balloon lifts that carry the ball back up. The stage has a fire lookout, an aerial tram, the Anvil and a Fleet mooring mesa. The Hanging Isle is an upside-down mountain held up by the Mind's hand. Its waterfall turns to mist before it reaches the net, and on each pulse the hand tips it 10 degrees toward the ball. Kest comes from the Highdraft Roosts (`pilots/kest.md:21`).

```gdscript
	{
		"id": "lore.park_islands.crew.nets", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.park_islands.exchange", "speaker": "Net crew", "skippable": true,
		"text": "Nets are strung under every gap. Fall all you like.",
	},
	{
		"id": "lore.park_islands.moss.rather", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.park_islands.exchange", "speaker": "Moss", "skippable": true,
		"text": "I'd rather you didn't. Those nets are older than the crew.",
	},
	{
		"id": "lore.park_islands.crew.taut", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.park_islands.exchange", "speaker": "Net crew", "skippable": true,
		"text": "Somebody under the isle keeps them taut for us.",
	},
	{
		"id": "lore.park_islands.note.lookout", "kind": "field_note", "zone": "3-1",
		"text": "Fire lookout log: isle's waterfall seen from the tower. Mist never reaches the net. Net is wet anyway.",
	},
	{
		"id": "lore.park_islands.note.balloon", "kind": "field_note", "zone": "3-1",
		"text": "Balloon lift ticket: envelope patched again. Patch came back sewn in a stitch nobody here knows.",
	},
	{
		"id": "lore.park_islands.note.tram", "kind": "field_note", "zone": "3-1",
		"text": "Tram ticket: cable sags toward the isle at golden hour. Straightens after dark. Towers not adjusted.",
	},
	{
		"id": "lore.park_islands.note.thermal", "kind": "field_note", "zone": "3-1",
		"text": "Thermal card: column over the Anvil lifts at golden hour only. Kest's roost crew calls it the evening lift. Logged as weather.",
	},
	{
		"id": "lore.park_islands.note.tilt", "kind": "field_note", "zone": "3-1",
		"text": "Pendulum note: isle tipped ten degrees toward the lookout. Then back. Lookout had only waved.",
	},
	{
		"id": "lore.park_islands.note.fleet", "kind": "field_note", "zone": "3-1",
		"text": "Mooring tag: balloon reclassified as cargo. Cargo reclassified as ballast. Ballast keeps trying to leave.",
	},
	{
		"id": "lore.park_islands.intro.warden", "kind": "intro", "zone": "3-1", "subject": "warden",
		"text": "Keel Warden. One hand under the isle. Holding, not lifting.",
	},
```

### Stage 6, the crown (zone 3-2)

Facts used: a dusk drop-in from the Watch Butte under a building thunderstorm, a bajada fan, a gooseneck meander, needle spires and the Gauntlet net. Lightning strikes on the beat. The 330 m Crown Spire stands over three perch spires, and the Mind's hand flies between the perches every 8 s. A Fleet lightning collector stands by the Crown, and signal masts carry its wire. The Mind's arena follows.

```gdscript
	{
		"id": "lore.park_crown.moss.storm", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Moss", "skippable": true,
		"text": "Storm's building over the Crown. Last crossing. I'll wait at the gates.",
	},
	{
		"id": "lore.park_crown.crew.beat", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Signal crew", "skippable": true,
		"text": "Lightning's keeping time. Struck the masts on the beat all evening.",
	},
	{
		"id": "lore.park_crown.moss.offbeat", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then roll on the off-beat. Supper's after.",
	},
	{
		"id": "lore.park_crown.note.watch", "kind": "field_note", "zone": "3-2",
		"text": "Watch log: storm cell over the Crown since noon. Wind from every side. Cloud has not moved.",
	},
	{
		"id": "lore.park_crown.note.bajada", "kind": "field_note", "zone": "3-2",
		"text": "Bajada card: a hundred washes, one fan. Every wash runs toward the Crown, including the uphill ones.",
	},
	{
		"id": "lore.park_crown.note.meander", "kind": "field_note", "zone": "3-2",
		"text": "Meander card: flash flood filled the gooseneck in minutes. Drained in hours. Left one ball track, going upstream.",
	},
	{
		"id": "lore.park_crown.note.needles", "kind": "field_note", "zone": "3-2",
		"text": "Needle survey: forty needles counted at dusk. Recount by lightning: forty-one. The new one is taller.",
	},
	{
		"id": "lore.park_crown.note.perches", "kind": "field_note", "zone": "3-2",
		"text": "Perch inspection: three spire tops, three palm-wide dishes. Two dry after rain. One warm.",
	},
	{
		"id": "lore.park_crown.note.gauntlet", "kind": "field_note", "zone": "3-2",
		"text": "Gauntlet net mends: every tear stitched from the Crown side. No crew posted on the Crown side.",
	},
	{
		"id": "lore.park_crown.note.fleet", "kind": "field_note", "zone": "3-2",
		"text": "Collector tag: storm delivered twelve strikes. Fleet billed for eleven. The Admiral rounded up.",
	},
	{
		"id": "lore.park_crown.intro.warden", "kind": "intro", "zone": "3-2", "subject": "warden",
		"text": "Crown Warden. One hand, three perches. It keeps the count.",
	},
	{
		"id": "lore.park_crown.intro.mind", "kind": "intro", "zone": "3-2", "subject": "mind",
		"text": "Mind: Your lane was committed before the storm. Please arrive on time.",
	},
```

### The three worlds

These notes speak for a whole world and tie its two stages together. Each world's notes go in that world's first zone (port note 7), and they come up after the stage notes unless the coordinator puts them first.

```gdscript
	{
		"id": "lore.world_spillway.note.water_board", "kind": "field_note", "zone": "1-1",
		"text": "Water board ledger: dam fills the reservoir, reservoir feeds the flume, flume feeds the head house. Head house returns more than it was sent.",
	},
	{
		"id": "lore.world_spillway.note.roster", "kind": "field_note", "zone": "1-1",
		"text": "Crew roster, Spillway: dam shift, flume shift, one keeper on the ball. Keeper column left blank. Moss fills it in after supper.",
	},
	{
		"id": "lore.world_spillway.note.notice", "kind": "field_note", "zone": "1-1",
		"text": "Fleet notice, posted at both ends of the river: ALL WATER IS NOW INVENTORY. Below it, in chalk: Tell the river.",
	},
	{
		"id": "lore.world_dig.note.mine_plan", "kind": "field_note", "zone": "2-1",
		"text": "Mine plan: open pit above, deep works below, one buried lens between. Plan stamped APPROVED by a hand older than the stamp.",
	},
	{
		"id": "lore.world_dig.note.assay", "kind": "field_note", "zone": "2-1",
		"text": "Assay office: copper from the pit, copper from the tubes. Same seam. Seam runs toward the sinkhole and does not stop.",
	},
	{
		"id": "lore.world_dig.note.headcount", "kind": "field_note", "zone": "2-1",
		"text": "Shift change rule: count heads at the collar and again at the gallery ring. Write both numbers down. Do not compare them.",
	},
	{
		"id": "lore.world_highdraft.note.roost_chart", "kind": "field_note", "zone": "3-1",
		"text": "Roost chart, Highdraft: islands at golden hour, the Crown at dusk. Every bearing on the chart ends at the Crown, including north.",
	},
	{
		"id": "lore.world_highdraft.note.handbook", "kind": "field_note", "zone": "3-1",
		"text": "Net crew handbook: strung under every gap from the Lookout to the Crown. Rule one, check the knots. Rule two, check who checked them.",
	},
	{
		"id": "lore.world_highdraft.note.wind", "kind": "field_note", "zone": "3-1",
		"text": "Fleet weather report: Highdraft wind requisitioned for fleet sails. Wind declined. Report filed under weather.",
	},
```

## Check

A short Python script, run in this session, parsed every fenced block above and compared the rows with `src/core/lore_rows.gd` at `77b99de`. It counted words by spaces, as `content_registry.gd:438` does. Results:

| Check | Result |
| --- | --- |
| Rows in this draft | 77 (today's table has 72) |
| Ids repeated inside the draft | none |
| Ids that clash with today's rows | none |
| Rows over their word cap | none. The longest exchange line has 13 words (cap 14), the longest field note 24 (cap 40) and the longest intro 12 (cap 12). |
| Zones and intro subjects | all valid. The subjects are `warden`, or the world's boss: `brindle` in world 1, `waking` in world 2, `mind` in world 3. |
| Exchanges per zone | one each, three lines each |

| Zone | Exchange lines | Field notes | Intros |
| --- | --- | --- | --- |
| 1-1 | 3 | 7 stage + 3 world | 1 |
| 1-2 | 3 | 7 | 2 |
| 2-1 | 3 | 7 stage + 3 world | 1 |
| 2-2 | 3 | 7 | 2 |
| 3-1 | 3 | 6 stage + 3 world | 1 |
| 3-2 | 3 | 7 | 2 |

Not checked: the rows have not been loaded by Godot, which is not installed in the cloud container. The coordinator's port runs `content_registry` validation. Tone and feel are Andrew's to judge.
