# Area blueprint: how a place is authored, in any world

**Status: proposed, parked until the world 1 sitting is done** (ruling at; [ROADMAP](../../../../project-guide/handoff/ROADMAP.md) phase 2). Nothing here changes world 1. This page says how a map is split into areas, what each area must state, and the loop that takes an area from an idea to a built and checked place, so the Dig and the Highdraft can be brought to the Spillway's standard the same way each time. The rows that build it are in [BACKLOG.md](../../../../BACKLOG.md#area-blueprint), AB-01 to AB-08.

Andrew asked for it on 19 November 2026 (ruling ef, [DECISIONS.md](../../../../project-guide/handoff/DECISIONS.md)): "split up the map into chunks and create unique and curated areas and places for the player to play around in, and for enemies to spawn for traversal, for discovery, or like looting, or through interacting with specific things for events, whether manually or randomly triggered ... have it be some sort of blueprint ... a way to blueprint and to iterate and build upon for worlds two and three."

## What already exists

Most of the blueprint is already written down or built. This page links to it and adds only what joins it together.

| Piece | What it gives an author | Where it lives | Reach today |
| --- | --- | --- | --- |
| The park file | Landforms, routes and waymarks, enemy homes, activities and their per-run alternatives, hidden pockets, contraptions, events with triggers, weather, one landmark | [PARK.md](../PARK.md); `src/world/park/park_*.json`, read by `src/world/park/park_map.gd` and checked by `park_schema.gd` | All six stages have a file in the same format. Played runs end at Brindle while worlds 2 and 3 are parked |
| Stage sheets and journeys | Each place in words: what it is, who works there, what pulls the rider through | [stages/](stages/), [journeys/](journeys/) | All six stages |
| Regions | A map cut into named polygons, each with a purpose (fight, rest, route, landmark, reward, hub), the verbs it serves and one line of why | `assets/park/park_dam/regions.json`, `assets/park/park_flume/regions.json`, `src/boss/arena_regions.json`; one call, `Regions.at(map, point)` in `src/world/park/regions.gd`; card [W1-141](../../../../docs/promises/W1-141.md) | World 1 only: 13 on the dam, 13 on the flume, 5 in the Slag Bowl |
| Pockets | The inside of a small curated place: entrance, enemies, obstacles, hazards, a safe path | `src/world/pockets/w1/` (25 files), drawn per run by `pocket_draw.gd` | One library, named for world 1, used by every world (BACKLOG SG-06) |
| Triggers | An event starts on the stage clock, on a Warden's phase, or when the player starts an activity; eligible events enter a weighted draw | `event_rows[].trigger` (`clock_tier`, `warden_phase`, `activity`) in the park file; `src/world/event_director.gd` | All six stages |
| The map standard | Ten points every map is held to, each with a check by code or by picture | Ruling ct; [map-audit.md](../../../../project-guide/handoff/shared/world1/map-audit.md) | The receipt covers the dam and the flume; landmark sight runs on all six |
| Art | Approved landmark boards for all six stages; three approved world journeys | [storyboards/](storyboards/), `docs/art/reference/` | Named places with a picture: dam 27%, flume 45%, pit 39%, sinkhole 43%, islands 77%, crown 87% (inventory of 19 November, below) |

## What is missing

Three things, found by a search of the repository on 19 November 2026 (the inventory is on branch `scratch/area-blueprint-research`, folder `research/`).

1. **Nothing joins the rows of one place.** A home, a pocket, a device and an event that stand in the same area each name a site row or a position. No one record says "these belong to this area", so nobody can read an area whole or check it whole.
2. **No rule for edges.** Where two region polygons overlap, the lookup returns the first one. Nothing says which area owns an event, a home or a payout that sits on a boundary, or a ride that crosses one.
3. **Worlds 2 and 3 have no regions.** Stages 3 to 6 have terrain, routes, homes and events, and no purpose polygons to compare an edit against.

A fourth thing is a risk to the art, not to the design: the 71 approved journey pictures are recorded at a scratch path and their files were not found in the repository, on the Mac Studio or on the Linux PC on 19 November. AB-01 is to find them and bring them in.

## The area card

One card per region. It is a view, not a second copy: every fact stays in the row that owns it today (ruling bz), and the card is printed by a tool that asks `Regions.at` where each row stands. A purpose is a field in a row, never a branch on an id.

| The card says | Read from |
| --- | --- |
| Name, stage, outline | the region row (`id`, `polygon`) |
| What the place is for, and the verbs it serves | the region row (`purpose`, `verbs`, `why`); a verb counts only when park data backs it, as W1-141 defines |
| Who lives or works here | `home_rows`, the row's society, the ambient homes |
| What can happen here, and what starts it | `event_rows` standing in the polygon, grouped by trigger: the clock, the Warden's phase, the player's own hand, a per-run draw |
| What can be found | `activity_rows` and their alternatives, drawn pockets, caches, secrets, the stage sheet's lore finds |
| What the player can work | `contraption_rows`, devices |
| Ways in and out, by height | `routes` through the polygon: the high line, the middle, the low, and where a missed high line lands and climbs back |
| What is fixed and what a run draws | fixed: terrain, routes, landings, the landmark. Drawn per seed: which activity, which pocket, which event, which modifier |
| Its picture | an approved board or journey panel, a draft, or none |
| Its checks | which of the ten map points it carries, and its speed readings (below) |

An area with no purpose, a verb with no fact behind it, a route node in no area, or an area with nothing to find, nothing to work and nothing that can happen is a finding. Not every area needs all three: a rest area is allowed to be quiet, and it is never a refuge (ruling cu).

## The loop for one area

1. **Read what is there.** Print the card. Read the stage sheet, the journey and the art for the place, and the story and tone pages (rule 10).
2. **Say what it is for.** Purpose, verbs and the one line of why. If two neighbours say the same thing, one of them changes.
3. **Draw before modelling.** A reference sheet or board for any new body or landmark (the standing "reference sheets before modelling" ruling). Existing art first; a new picture only for a place with none.
4. **Block it out.** Grey pieces at true scale, proved with the ball in headless Godot (the `scrapkeep-blockout` skill).
5. **Write the rows.** Landforms, routes, homes, activities, contraptions and events in the park file; the region in the regions file.
6. **Check it.** The schema, the map standard's lines for the stage, the region test, and the speed readings.
7. **Look at it.** Stills or a film at rider height from the same seed, before and after.
8. **Review it.** One independent review, as for any change.

Who does what: Claude threads write and the Gate's Claude reviewer admits, as today. From 19 November GPT agents may help the coordinator (ruling eg): Astra for research, analysis and a second opinion, Sol for evidence sweeps and routine checks, and either for concept art and model drafts under the reference-sheet ruling.

## The speed reference

Andrew named the 3D games of the Sonic series as a model for maps built round a fast character (ruling ef), as a reference point only: Scrapkeep's beings, props, wildlife, maps and structures stay its own. The study is [research/comps/speed3d/](../research/comps/speed3d/README.md) (card CS-04), under the same hard line as the other comparison studies: structure and tuning relationships are taken, and names, characters, layouts, art, music, text and code never are.

What it gives the blueprint:

- **Three heights of route.** A high line earned by skill, a middle, and a low one a mistake lands on, which is longer and never a stop, with the way back up in view. This is where rulings cu and cv and the reference agree: difficulty is carried by which route you hold, not by stopping the ball.
- **Notice before commitment.** Every launcher, rail and kicker shows where it leads before the rider commits, sized for the fastest entry.
- **Set pieces between stretches of control**, with a steering choice in view before the guided motion ends.
- **Quiet ground with a job**: room to read the next fork, build speed or line up a hook.
- **Pay on the line and off it**: scrap where a clean landing collects it, a part where a longer detour earns it.
- **Fixed ground, drawn content.** The fork, the landing and the climb back are the same every run so they can be learned; the seed changes what is met there.

Where the reference and a ruling disagree, the ruling wins, and the study says where: a hard fall, a forced stop or a reversal is not used (ruling cu), and a separate course behind a portal is not used at a world seam (ruling cv).

Its ten proposed readings are the blueprint's speed checks once built (AB-06): seconds from a fork to where the routes rejoin on each height, seconds of notice before a commitment, seconds between route choices, what a detour pays for its extra seconds, the longest stretch with no steering, the share of a ride above speed tier 2 on each height, hook sites where holding pays, seconds between set pieces, hull lost per minute by how the ball moves, and hand-overs that read as one motion.

## Ideas said and not yet used

From Andrew's interviews, playtest notes and the design pages, each checked against the code on 19 November. The full list with sources is in the inventory. A card session with Andrew picks which of these an area may draw on (AB-08); none is authorized by being listed.

- Allies bought at a place: a pin-carrier that follows for 30 seconds, a turret on a bank, a lift drone that refreshes an air jump.
- A buried plate that a slam uncovers; a vault that opens for beating a lap time; the reward shown on the post of a timed challenge.
- Water on lava to make a platform. Something airborne to interact with ("a floating hovercraft").
- A reward for joining an event that overlaps a boss's mechanic.
- A whole settlement built for rolling: banked streets, half-pipe plazas, launchers as public transport.
- Already written and parked: the night dam, the reversed flume, two variants of a sub-region, a valve that drains a lobber ledge, park societies and monster origins, staged story beats in worlds 2 and 3, a crew of scrap bots.
- 145 draft lore finds across the six stage sheets, not yet placed.

## What this page does not decide

When worlds 2 and 3 start (ruling at stands), which unused ideas are taken, any change to the ten map points, and any new field in the park file. The first build step, AB-02, adds a tool and no data.
