# The park: six Arizona stages at four times the size

Status: wave 13 lane-2 design spec (park and Wardens). The direction is [TADR-011](../../../adr/TADR-011-park-terrain-and-warden-kinds.md) (Proposed; implemented in `sketches/core-loop` with Worlds 1–3 unparked under ruling `ep`). The Bible amendment draft is in [BIBLE-AMENDMENT-park.md](BIBLE-AMENDMENT-park.md). Based on the wave-13 session decisions; the creative-charge calls are listed in section 11.

Paths are under `sketches/core-loop/` unless they start with `adr/`, `artifacts/`, `docs/` or `BIBLE.md`. Every number marked "start" is a starting value to tune in play. A **park element** is a landform that works as a piece of skate-park furniture. A **waymark** is a named point a traversal line must pass. A **line** is one pilot's authored route from the drop-in to the Warden. A **mounting** is where and how a Warden sits in its landmark. An **enemy home** is a place in the park that spawns one enemy kind and gives it an advantage.

## Contents

1. What changes and why
2. The tables
3. The terrain route on Terrain3D v1.0.2
4. Recipe landform families
5. The event grammar
6. The six stages at a glance, and the storyboard format
7. The Warden kinds
8. Traversal acceptance
9. Performance budgets
10. Implementation map, waves K-B to K-F
11. Risks and the veto list
12. Stages
13. Veto list for Andrew (consolidated)

## 1. What changes and why

Andrew's seed, 9 October (`artifacts/local/alpha/push/w12/DESIGN-SEED-park.md`): the maps should be way bigger, with ramps, ways to navigate, underground, and empty or flooded caverns. Arizona is vast, so disguise the video-game furniture (tunnels, ramps) as its own landforms. Think of a huge skate park per world, map and stage; boss arenas keep their own small thing. The deserts should feel like a living place you want to explore, terraformed by the societies that lived there. The one relationship to build on: the ball is the skater and the terrain is the park, so every landform carries a verb the ball already has (roll, slam, harpoon, boost, glide) and every enemy kind has a home whose shape gives it the advantage (principle 24, 2 October).

| Today | After wave 13 |
| --- | --- |
| A 400 m square heightfield at 2 m, no holes (`src/world/terrain.gd:26-29`) | About 1.6 km square per stage on Terrain3D, with holes for tunnels and caverns |
| One trimesh from the grid, the only collider (`terrain.gd:383-391`) | The same rule kept: trimesh tiles from the same 2 m grid, hole cells left out; Terrain3D collision off |
| Geometry and props as code in `src/world/map_*.gd` | One park file per stage, `src/world/park/<map_id>.json`, read by every system |
| One immobile clamp at a beacon on every stage (`src/combat/warden.gd:10-16`) | Three Warden kinds, one per world, each in two mountings inside a hero landmark; every Warden a harpoon anchor |
| Warden families reactor, swarm, reactor, swarm, mind, mind (`src/core/alpha_defs.gd:69-120`) | reactor, reactor, swarm, swarm, mind, mind |
| No timed events on the alpha table (`alpha_defs.gd:13-15`, `src/world/event_director.gd:62-64`) | Events, homes, contraptions and weather from tables, on the difficulty clock and Warden phases |
| One provisional line for three pilots on one stage (`tools/traversal_lines.json`) | A measured line per pilot per stage, six by six, as hard acceptance |

Gates Andrew accepted: a storyboard per stage and per Warden kind approved by click before terrain or bodies are built; a measured traversal line per pilot per stage; greybox first, dressing second.

## 2. The tables

### 2.1 The park file

One file per stage: `src/world/park/<map_id>.json`. A fixture park for tests lives beside them as `src/world/park/park_test.json`. Coordinates are metres. `at` is `[x, z]` on the ground plane, with x east and +z toward the landmark side (today's fall line runs from the spawn at -z to the beacon at +z, `tools/traversal_lines.json`). `y`, where given, is absolute world height in metres; the bake sets the stage's base plain at y = 0 and stamps raise or cut it. `yaw_deg` turns a piece about the vertical axis, 0 facing +z. `size` is `[length, height, width]` in metres along the piece's own axes.

Top-level keys, all required:

| Key | Type | Meaning |
| --- | --- | --- |
| `schema` | string | `"scrapkeep-park/1"` |
| `map` | string | The map id, the same string as the stage row's `map` |
| `size_m` | number | Side of the play square, 1600 (start) |
| `time_of_day` | string | One of `dawn`, `morning`, `noon`, `afternoon`, `golden`, `dusk` (section 6) |
| `spawn` | object | `{"at": [x, z], "heading_deg": n}`: the drop-in point and facing |
| `play_rect` | array | `[x, z, width, depth]`: where spawns and rescues stay (the stage_map field, `src/world/stage_map.gd:24-25`) |
| `landmark` | object | The landmark row (2.3) |
| `waymarks` | array | Ordered ids from `drop_in`, through park row ids, to `landmark`. Every line passes them in order |
| `routes` | array | The route graph (2.8) |
| `park_rows` | array | 2.2 |
| `event_rows` | array | 2.4 |
| `home_rows` | array | 2.5 |
| `contraption_rows` | array | 2.6 |
| `weather_rows` | array | 2.7 |
| `activity_rows` | array | 2.8 |

The stage table keeps what it owns. `alpha_defs.gd` (and the temporary `park_defs.gd`, section 10) holds the stage number, world, display name, `warden_family`, `warden_variant`, music, pressure, packs and Warden numbers. The park file never repeats them; the validator cross-checks against them.

### 2.2 `park_rows`

One row per park element. A stage starts with 40 to 70 rows (start).

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique in the stage, snake_case |
| `element` | enum | Park element kind: `half_pipe`, `flow_line`, `grind_line`, `rail`, `bowl`, `terrace`, `tunnel`, `drop`, `flooded_cavern`, `elevated_line`, `ledge`, `crater_bowl`, `sky_island`, `kicker`, `bank`, `anchor_field`, `ground` |
| `landform` | enum | The Arizona disguise: `slot_canyon`, `arroyo`, `dry_wash`, `slickrock`, `canal`, `flume`, `penstock`, `pipeline`, `dam_face`, `open_pit`, `tailings_bench`, `headframe`, `lava_tube`, `adit`, `shaft`, `spillway_tunnel`, `sinkhole`, `cenote_pool`, `flooded_shaft`, `cliff_dwelling`, `mesa_rim`, `butte`, `spire`, `hoodoo_field`, `saguaro_stand`, `travertine_terrace`, `horseshoe_bend`, `river_canyon`, `gooseneck`, `meteor_crater`, `sky_island` |
| `society` | enum | Who made it: `none` (water and time), `hohokam`, `ancestral_puebloan`, `mining`, `dam_era`, `fleet` (the Furnace Fleet's present works), `ancient` (the pre-collapse machines) |
| `at` | [x, z] | Centre of the footprint. A GLB recipe whose registry row says origin entry_lip is placed by the loader so its entry lip sits at the rear of the footprint and its ride runs +Z (turned by yaw_deg) through at to the far edge; park rows never carry a lip position (KC-INT, 2026-10-11). |
| `y` | number or null | Absolute height for a piece that does not sit on the ground (a rail, a hung line, a floating island); null sits it on the baked ground |
| `size` | [l, h, w] | Footprint and height in metres |
| `yaw_deg` | number | Turn about the vertical axis |
| `verb` | enum | The traversal verb it carries: `roll`, `pump`, `grind`, `launch`, `drop`, `swing`, `glide`, `lift`, `bank`, `slam`, `cast` (a place the skill bar clears, not the ball: the pit's ability test) |
| `ride_fact` | string | The `WORLD_ROWS` kind it publishes when ridden (`src/core/event_kinds.gd:824`), for example `ride_chute`, `ride_grapple_line`, `thermal_ride`; `kicker_launch` for a kicker; `""` for a plain `ground` row. New facts are added to `WORLD_ROWS` by unit KC0 |
| `home` | string | A `home_rows` id this element houses, or `""`. The enemy kind lives on the home row, not here |
| `recipe` | string | A recipe id from section 4 (`assets/models/park/<recipe>.glb`), `greybox:<element>` during greybox, or `""` for a height-only element |
| `stamp` | enum | The height stamp the bake applies: `""`, `wash`, `channel`, `ridge`, `mesa`, `butte`, `spire`, `bowl`, `terrace`, `crater`, `sinkhole`, `ramp`, `plateau` |
| `hole` | bool | True cuts a Terrain3D hole and drops the collider cells under the footprint (tunnel mouths, cavern openings, the sinkhole) |
| `budget` | enum | The asset budget class of its recipe: `landform`, `park_large`, `hero_landmark`, `detail` (section 9) |
| `routes` | array | Route ids this element belongs to (2.8) |
| `fragment` | string | A codex fragment id found here, or `""` (society layers feed the codex). A `ref_` prefix marks a reference fragment that describes a real culture's technique (section 4) |
| `hide_on` | string | Optional. An event row id whose `effect.swap` hides this row (node and collider) while the swap is applied and shows it again on revert. The event must be a natural collapse or impact event with a swap |

Example, stage 1:

```json
{"id": "west_wash", "element": "half_pipe", "landform": "arroyo", "society": "dam_era",
 "at": [-360, -420], "y": null, "size": [460, 12, 34], "yaw_deg": 20,
 "verb": "pump", "ride_fact": "ride_chute", "home": "culvert_chasers",
 "recipe": "half_pipe_concrete", "stamp": "wash", "hole": false, "budget": "landform",
 "routes": ["main", "west"], "fragment": "dam_era_wash_liner"}
```

### 2.3 `landmark`

One object per stage. It is the hero landmark and the Warden's home.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique id, also usable as a waymark (`landmark`) |
| `kind` | enum | `dam`, `penstock_tower`, `headframe`, `sinkhole`, `sky_island`, `spire` |
| `at`, `size`, `yaw_deg` | as park rows | Footprint |
| `recipe` | string | The landmark recipe id (`landmark_<kind>`) |
| `budget` | string | Always `hero_landmark` |
| `sight_top` | [x, y, z] | The point the sight test aims at (2.10) |
| `sight_share` | number | Required share of open play cells that see `sight_top`, 0.85 (start) |
| `beacon` | [x, z] | Centre of the engage ring; the flow's `beacon_point` reads it |
| `reach_m` | number | Engage ring radius (today 30, `alpha_defs.gd` `beacon_radius`) |
| `warden` | object | `{"mounting": id, "anchor": [x, y, z], "path": [[x, y, z], ...], "hardpoints": n}`. `mounting` must be one of the stage's Warden kind's two mountings (section 7). `path` is empty unless the Warden moves |
| `bay_dock` | object | `{"at": [x, z], "facing_deg": n}`: where Moss's bay docks after the break, so `bay.gd:120-169` never searches |
| `gate_slots` | array | `[{"at": [x, z], "facing_deg": n}]`: the reward gates (the stage_map field, `stage_map.gd:33-35`) |
| `light` | string | `ancient_beam` or `""`: a uranium-glass green (#9dff3c) column that keeps the landmark readable through fog |
| `music` | string | The `WORLD_ROWS` kind for its hum (today `landmark_hum`) |
| `fragment` | string | Codex fragment found at the landmark |

### 2.4 `event_rows`

One row per event the stage can run. A stage starts with 4 to 6 rows, at least one natural and at least one other family (start).

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique in the stage |
| `kind` | enum | The code module that runs it: `flood_fill`, `drain`, `cave_in`, `collapse`, `impact`, `flash_flood`, `lightning`, `fleet_landing`, `machine_eruption`, `boiler_burst`, `reactor_blow`. `cave_in` and `impact` are today's `terrain_event.gd` kinds |
| `family` | enum | `natural`, `fleet`, `ancient`, `industrial`. Each kind allows one family (section 5) |
| `site` | string | The park row id where it happens; one area per row |
| `trigger` | object | `{"on": "clock_tier", "value": n}` with n from 0 to 4 (the director's `effective_tier()`, `src/world/director.gd:163-165`), or `{"on": "warden_phase", "value": p}` with p one of `engaged`, `stagger`, `chunk_1`, `chunk_2`, `chunk_3`, `broken` |
| `weight` | number | Relative odds among rows eligible on the same tick (the director's own stream picks) |
| `telegraph` | object | `{"lead_s": n, "form": kind, "on_bar": bool}`. `lead_s` is the minimum warning. `form` names a `WORLD_ROWS` kind, so colour, shape and sound come from one row. `on_bar` true rounds the landing up to the next downbeat, adding at most one bar |
| `live_s` | number | How long it stays active; 0 means it stays for the rest of the stage (a landed barge, an awakened machine) |
| `effect` | object | Kind-specific values (section 5) |
| `route_change` | object | `{"closes": [route ids], "opens": [route ids]}` |
| `hold_clear_m` | number | The change waits while the ball is within this distance of the footprint (today's hold rule, `src/world/terrain_event.gd:7-11`) |
| `cooldown_s` | number | Seconds before the row is eligible again |
| `once` | bool | True fires at most once per stage attempt |
| `music_cue` | object | `{"telegraph": cue id, "land": cue id}` from the music cue table (`src/presentation/music_rows.gd`, a `CUES` table added by unit KE8) |

### 2.5 `home_rows`

One row per enemy home. A stage starts with 4 to 6 homes (start).

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique in the stage |
| `enemy` | string | The roster kind it spawns (`src/combat/roster.gd` rows; the director's `KIND_NAMES`, `director.gd:46-49`) |
| `site` | string | The park row id it sits in |
| `landform` | enum | Copied for the storyboard caption; must equal the site row's landform |
| `advantage` | string | One line: why this kind is strong here |
| `counter` | string | One line: the readable answer the shape also offers |
| `reinforce` | object | `{"from_tier": n, "every_s": s, "max_alive": n, "pack": pack id}`. `pack` names a pack in the stage row's `packs` or `PACKS` (`alpha_defs.gd:42-46`, `86-120`) |
| `break` | object | `{"by": "ram" or "slam" or "smash" or "damage", "hp": n, "scrap": n}`. `ram` means a ram at speed tier 2 or better |
| `stops_kind` | bool | True: breaking it stops that kind's arrivals on this stage (DESIGN-V3 "World and story") |
| `dormant` | bool | True: inactive until an event row activates it (a Fleet landing) |

### 2.6 `contraption_rows`

The contraptions are momentum tools you ride, never stops (`src/world/contraptions.gd:9-13`). A row is today's contraption spec with three added keys. A stage starts with 8 to 12 rows (start).

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique in the stage |
| `kind` | enum | Today's kinds: `barge`, `lift`, `launcher`, `cable`, `valve`, `cracked_wall`, `thermal` (`contraptions.gd:86-101`) |
| `site` | string | The park row it belongs to |
| `recipe` | string | Its skin: `gauge`, `geyser_vent`, `cannon`, `trebuchet`, `lift_platform`, `barge`, or `""` for the code primitive |
| the kind's spec keys | as today | Exactly the keys `contraptions.gd` reads now, for example a launcher's `style`, `at`, `radius`, `target`, `floor`, `min_flight`, `charge` (`src/world/map_gorge.gd:345-372` shows every kind). Arrays become Vector2 or Vector3 in `park_map.gd` |

### 2.7 `weather_rows`

Weather changes the view, the sound and the odds of events. It never changes the ball's handling. A stage starts with 1 or 2 rows (start).

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Unique in the stage |
| `kind` | enum | `clear`, `monsoon`, `dust_squall`, `heat_shimmer`, `cave_mist`, `cloud_deck`, `thunderstorm` |
| `trigger` | object | As event rows, or `{"on": "always"}` |
| `lead_s`, `live_s`, `gap_s` | number | Warning, duration, and the gap before it can return |
| `fog` | object | `{"density": n, "color": "#rrggbb"}` written over the world look's fog while live |
| `sky` | string | A sky state id the world look applies (`storm_build`, `dust`, `clear`) |
| `sound` | string | Its ambient bed |
| `music_layer` | string | A music layer it adds while live |
| `event_odds` | object | `{event row id: multiplier}` while live |
| `handling` | string | Always `"none"`. The validator refuses any other value |

Wind that pushes the ball is never weather. A visible wind lane is a `thermal` contraption row, so it reads like the ride it is.

### 2.8 `routes`, `activity_rows`, `waymarks`

`routes` is the route graph the nav proof walks: `[{"id": "main", "from": "drop_in", "to": "landmark", "via": [park row ids]}]`. A route is open unless a live event closed it. The rule "a route always open" is tested on this graph (section 5).

`activity_rows`: `{"id", "activity", "site", "at", ...}` where `activity` is one of the `ACTIVITY_ROWS` kinds (`enemy_camp`, `surge_run`, `ambush_altar`, `cracked_cache`, `hauler_bounty`, `event_kinds.gd:616`) and the remaining keys are the ones `activity_sites` carries today (`pack`, `pay`; `src/world/map_spillway.gd:98`). Three per stage, signposted from the drop-in. A row may list `alts`, each `{"activity", "pack"}`, and each run draws one of the row and its alts from its seed (activities.gd `drawn`, W1-70). An alt keeps the row's place, site, pay and pocket role (section 2.12): a camp stays a camp, an altar or bounty stays a risk; a cache, surge course or relay row lists none (park_schema.gd `_activity_alts`). Every map check reads the row, so each alt is checked in its place.

`waymarks`: 3 to 5 ids in order, the first `drop_in`, the last `landmark`, the middle ones park row ids or activity row ids (start: two middle waymarks, one of them an activity).

### 2.9 Where each table lives and who reads it

| Table | Lives in | Read by |
| --- | --- | --- |
| Stage header (`size_m`, `spawn`, `play_rect`, `time_of_day`) | the park file | `park_map.gd` (spawn, heading, play rect), the world look (time-of-day row), the bake |
| `park_rows` | the park file | the bake (`tools/park_bake.gd`: stamps, holes, surface map), `park_recipes.gd` (recipe placement and colliders), scatter (keep-out footprints), materials (`material_at` from the surface map), the nav proof and route test, the codex (fragments), the traversal tool (ride facts, waymarks), the storyboard plot |
| `landmark` | the park file | `park_map.gd` (beacon, gate slots, landmark point), Warden spawn (mounting, anchor, path), `bay.gd` (dock slot), the sight test, music (hum), light (beam), the storyboard plot |
| `event_rows` | the park file | `event_director.gd` (schedule, telegraph, hold, effect), the route test, music (cues), the world facts bus, the storyboard plot |
| `home_rows` | the park file | `director.gd` (arrivals and reinforcements), combat (breaking a home), the storyboard plot |
| `contraption_rows` | the park file | `contraptions.gd`, through `park_map.gd` deriving today's `map.contraptions` |
| `weather_rows` | the park file | `event_director.gd` (weather schedule), the world look (fog, sky), audio (bed), music (layer) |
| `activity_rows` | the park file | `park_map.gd` deriving today's `activity_sites`, the edge markers |
| `routes`, `waymarks` | the park file | the route test, the traversal tool, the storyboard plot |
| Time-of-day light | `src/presentation/world_look.gd`, a new `TIME_ROWS` table keyed by the six ids | the world look on stage entry; `ROWS` stays per world for sky kind, air and fog (`world_look.gd:14-46`) |
| Music cues | `src/presentation/music_rows.gd`, a new `CUES` table | the music engine |
| Warden kind, variant, numbers | `src/core/alpha_defs.gd` rows | combat's `warden_spec` (`src/combat/combat.gd:2458-2480`), `warden.gd` |
| Pilot lines and bars | `assets/park/<map_id>/lines.json`, one per stage | `tools/traversal_line.gd` |

`src/world/park/park_map.gd` extends `stage_map.gd`, loads the JSON once, and fills every field today's systems already read (`spawn`, `heading`, `beacon`, `play_rect`, `contraptions`, `kickers`, `gate_slots`, `activity_sites`, `landmark`, `scatter`), so the bay, flow, director and contraptions keep their interfaces.

### 2.10 Validation (`src/world/park/park_schema.gd`)

`park_schema_test.gd` fails, naming the row id, when:

- a field is missing, or an enum value is not in its list;
- an id repeats, or a reference does not resolve (`home`, `site`, `routes`, `waymarks`, `event_odds`, `effect.home`, a `route_change` id);
- `landmark.warden.mounting` is not a mounting of the stage row's `warden_family`;
- a `home_rows.reinforce.pack` is not in the stage's packs;
- an event's `family` is not the one its `kind` allows, or its `telegraph.lead_s` is under the floor for its family (section 5);
- a `weather_rows.handling` is anything but `"none"`;
- a `recipe` names no registry row (allowed only with the `greybox:` prefix);
- a home row's `landform` differs from its site row's;
- a row whose `society` is `hohokam` or `ancestral_puebloan` has a `home`, a `fragment` that is not a `ref_` id, or is the `site` of an event row of kind `cave_in`, `collapse`, `impact`, `machine_eruption`, `fleet_landing`, `boiler_burst` or `reactor_blow` (the guardrail in section 4).

### 2.11 The stage graph

The bake has a second step. `tools/park_graph.gd` reads the park file and the bake's `ground.bin`, `holes.bin` and `under.bin` and writes `assets/park/<map_id>/graph.bin` (nodes, edges, flags and two distance fields, zstd) and `graph.json` (schema, map, the park file's and `bake.json`'s sha256, node and edge counts). The graph is the stage's one measured space. The park file stays the authored truth: the graph checks the spawn, the landmark and the activities and never moves them.

| Part | Rule (start) |
| --- | --- |
| Node | One per 8 m on the 2 m grid (every fourth cell), at the ground height, or on a hole cell at the `under.bin` floor; plus one per 8 m over the footprint of every park row whose `y` is not null, at that `y` (the net deck, a hung rail, a floating island) |
| Ground edge | Joins 8-neighbours both ways when the climb is at most 4 m over 8 m; any drop is a one-way edge down |
| Ride edge | Read from the stage's own rows, never inferred from terrain, and tagged with its row id. A `launch` park row (a `kicker`) gives a one-way edge from its takeoff node (the node under its lip, or its own nearest node when that one stands more than the 4 m climb above it, 2026-10-23) to the nearest node of the row that follows it in each route's `via` (its authored landing); a `launcher` contraption a one-way edge to its `target`; a `cable` contraption a one-way edge from `from` to `to`; a `grind` park row (`grind_line`, `rail`) joins its two end nodes both ways along its line; a `thermal` or `lift` contraption a one-way edge up from its `at` to the nearest node within its `height` or `rise`; a `glide` park row a one-way edge down along its yaw. Its length in path metres is its straight length |
| `open` | No roof above the node: the sight test's open cell (8) |
| `line` | Within 8 m of the shortest graph path from `spawn.at` through the `waymarks` in order to `landmark.beacon` (the same 8 m corridor as event rule 2, section 5) |
| `guarded` | Inside a row whose `society` is `hohokam` or `ancestral_puebloan` (the guardrail in 2.10) |
| `warden` | Inside the engage ring, `reach_m` round `landmark.beacon` |
| `door_ok` | `open`, not `line`, not `guarded`, not `warden` |
| `sight_ok` | A clear ray from 2 m above the node to a `line` node within 240 m |
| `d_landmark` | Path metres to `landmark.beacon` |
| `d_spawn` | Path metres from `spawn.at` |

Readers: the spawn and pocket checks (2.12), `director.gd`'s home arrivals (a home is ahead when its site's `d_landmark` is smaller than the ball's), the traversal tool's `progress_m`, and `tools/park_plot.py`, which draws the `line` nodes under the journey polylines. Two rules hold on every stage: every route in `routes` is a connected path in the graph through its `via` rows over ground and ride edges, so the authored graph and the measured one agree (stage 5's `main` crosses by `fin_nose_kicker` to the raised `net_deck`, `design-v3/park/stages/5-park_islands.md:478`; PARK.md:380); and the spawn's `d_landmark` lies in the farthest quarter of `open` nodes. The spawn-to-beacon path over the graph's longest shortest path is reported per stage (start target 0.6), not gated.

### 2.12 Pockets

Every stage carries four pockets: its three `activity_rows` and one hidden pocket. One activity sits on the line, an `enemy_camp`, usually a waymark; a `surge_run` qualifies once `src/world/activities.gd` has a rule for it (today it has none, so a park row naming it builds nothing, `activities.gd:13-15`). The other two sit off it: one reward (`cracked_cache`) and one risk (`ambush_altar` or `hauler_bounty`). The hidden pocket is a `contraption_rows` row that opens a sealed space, a `valve` or a `cracked_wall`, with a visible tell, and its site row's `routes` lists three or more route ids. Detour is the price, and the pay follows it. Two distances, two points: `sight_ok` (240 m) is measured to the pocket's door from a line node that sees it, and the detour (150 to 600 m) is path length from the line to the pocket's pay point, so a door sits near the line and the pay sits deep (coordinator ruling after the draft re-check, 2026-10-10 w13-park). The on-line activity's part is `common` only: the camp rolls a common part from the pool (ruling bu, 2026-11-09; it paid a named Hot Rivets or Loose Trigger every run before), and a park row may still name a part, which wins over the roll (`activities.gd` `pay_table`); the off-line pocket with the smaller detour rolls `common` or `rare`, today's roll (`activities.gd:27`); the one with the larger detour, which this section makes the reward, rolls `rare` only (start). Scrap stays 180 on every activity (`activities.gd:28`), so the heft pace does not move and no price is set (BIBLE.md:513). Each activity row carries its `pay.rarities` in the park file. A player who skips every pocket loses only the detour.

An opt-in event may stand beside the four pockets (W13 SR10, Andrew's card tap 2026-10-17 16:37Z): the Spillway dam and the Highdraft islands each carry one `hold_the_relay` row, and the flume carries its surge course, a `surge_run` row (unit 11, 2026-10-24). `tools/park_graph.gd` gives each the role `event`, which the pocket count, the pay ladder and the reward ratio leave out, while its door still keeps the sight and clear-ring rules. Its centre sits at least 48 m off the floor line, so no line rolls through its 24 m ring by accident.

The rules scale the comps pocket spec (`research/comps/pocket-placement.md:30-42`) by four, the park's size against a small stage (section 1). Every distance is a path distance on the stage graph (2.11), from the door node, the graph node nearest the activity's `at`.

| Rule | Comps start | Park (start) |
| --- | --- | --- |
| Door to spawn | at least 60 m | at least 240 m |
| Door to `landmark.beacon` | at least 80 m | at least 320 m |
| Door to door | at least 50 m | at least 200 m |
| Sightline | a `line` node within 60 m | `sight_ok`: a `line` node within 240 m |
| Clear ring | 10 m round each door | 40 m round each door: no home site, no event `site` footprint, no `contraption_rows` hazard |
| Off the line | guaranteed pockets not on the shortest route | reward and risk doors are not `line` nodes |
| Detour | price grows with detour | `detour_m`, the path length from the nearest line node to the pocket's pay point (`tools/park_graph.gd`, KB8b), is 150 to 600 m for the reward and risk pockets, about 10 to 30 s at the 20 m/s mean the stage lines assume; the reward carries the larger detour. `door_m`, the same measure to the door, sits beside it in `graph.json`; an activity row has one `at`, so its door and pay point are one node until SR15 adds an optional `door` field (coordinator ruling, 2026-10-11 w13-park) |
| Count | 3 to 5, plus one per stage, cap 8 | four on every stage in wave 13; a park with a completionist card 2 extra (the open card's default, two more activities a park) may carry a second reward or risk pocket, which keeps every distance rule while the pay ladder ranks the first pair (coordinator, 2026-10-24). A card 2 extra row carries `"extra": "card_2"` and stands beside the drawn pockets: the draw counts only the other authored sites against its slots (stage_modifier.gd authored). Every stage draws at least one pocket (stage_modifier.gd `MIN_DRAWN`, ruling bu, 2026-11-09): the dam's four authored sites pass stage 1's three, so it drew none and never rolled a stage modifier; it now draws one, as the flume does. In world 1 a drawn pocket also stands on level ground (5 m of rise at most under its footprint), clear of the rescue cage and of every secret's spot, and outside the rogue sites' discs (pocket_draw.gd `TIDY`); worlds 2 and 3 wait for their own pass. A drawn pocket rolls its part on its own stream, so it never pays what the stage's authored site of its kind pays (activities.gd `_luck_id`) |

The on-line activity keeps only the clear ring and the sightline. The hidden pocket keeps every rule except the beacon distance: its door opens a sealed space and pulls no play toward the Warden, so it needs only to stay off `warden` nodes. A door that fails a rule moves within its site row first, then the KD unit moves the activity's `at` or its site row in the stage's park file; the band tables of section 8 do not move to make a pocket pass (PARK.md:476).

**Readings fixed after the draft round (2026-10-11).** Two rounds of straight-line checks on the six journey drafts disagreed with each other and with the journeys, so the rules above read this way from here on:

1. Every distance in the table is a path distance on KB8's graph. Until a stage has its `graph.bin`, a straight-line estimate is advisory, is written as `_est`, and never moves an activity or a row.
2. The on-line activity may be a waymark, and its kind is whatever the journey puts on the line (a `hauler_bounty` on the line is allowed when the journey has it there). The off-line pair stays one reward and one risk.
3. The journey's positions win over the starting values. This narrows the sentence above: a KD unit moves a pocket only when the graph shows a breach of the clear ring, the door-to-door minimum or the route-open rule; a detour or sightline miss is logged for the sitting and the band tables still do not move.
4. The clear ring counts home sites, destructive event sites (cave-in, collapse, blow, eruption) and contraption hazards. A flood or a drain is not destructive, so a door may stand inside its site. When a home and a door collide, the home moves, not the door.
5. A draft that moved a pocket off its journey position to satisfy a straight-line estimate carries both positions; the KD unit picks by the graph and restores the journey's position when rule 3 allows it.

## 3. The terrain route on Terrain3D v1.0.2

**Regions.** Rendering uses `vertex_spacing` 1.0 m and `region_size` 1024 vertices, so a region is 1024 m square. Four regions, at region coordinates (-1,-1), (0,-1), (-1,0) and (0,0), cover -1024 m to +1024 m: the 1600 m play square and a 224 m apron. The apron holds the rims, mesas and walls that rise into the skyline. Beyond 1024 m there is no ground; the sky and distant silhouette cards close the view. The probe found Terrain3D snaps the import origin to its region grid and fixed it with a region-aligned image (P-ADDON A3), so the bake writes region-aligned images.

**The bake.** `tools/park_bake.gd` runs headless, reads the park file, applies each row's stamp in order, and writes `assets/park/<map_id>/`:

| File | Content |
| --- | --- |
| `ground.bin` | 801 by 801 heights at 2 m over -800 to +800, float32, zstd (`FileAccess.open_compressed`) |
| `apron.bin` | the 1 m heights of the apron ring and the region padding, float32, zstd |
| `holes.bin` | one byte per 2 m cell: 1 under a `hole` footprint |
| `under.bin` | for hole cells, the floor height of the recipe beneath, from a downward ray against its collision mesh |
| `surface.bin` | one byte per 2 m cell: the material slot from the row's landform (sand, sandstone, concrete, tailings, basalt, net) |
| `bake.json` | schema, map, the park file's sha256, the bake tool's sha256, height range, cell counts |

The runtime never evaluates stamps. `park_bake_fresh_test.gd` recomputes the park file's hash and fails when `bake.json` disagrees, so a table edit without a re-bake goes red. Two bakes of one file give identical bytes. The 1 m render heights are the 2 m grid's two-triangle interpolation plus the stage's relief noise from `FastNoiseLite.get_image` (native, fast); the relief amplitude stays at today's 0.12 to 0.14 m (`src/world/map_spillway.gd:70`, `map_dig.gd:62`, `map_dig_deep.gd:26`). Visual and collider differ by at most that amplitude, as the P-GROUND relief view does today.

**Holes.** A cell marked in `holes.bin` gets `Terrain3DData.set_control_hole` on its four 1 m vertices and no triangles in the collider tile. The recipe under it (a tunnel mouth, a cavern, the sinkhole) supplies the surface. `terrain.height(x, z)` in a hole cell returns the `under.bin` floor, and `layer_at` (`terrain.gd:222`) reports `under`, so spawns, scatter and rescues never land on air.

**The collider.** One path, trimesh tiles:

- Tiles are 160 m square, 80 by 80 cells of the 2 m grid, 12,800 triangles each, 100 tiles per stage, 1.28 million triangles in all.
- Each cell uses the same two triangles and winding that `terrain.gd:345-370` uses today and that `_grid_height` interpolates (`terrain.gd:265`), so the query and the collider are one surface.
- Terrain3D's collision mode stays 0 (DISABLED). `addon_load_test.gd` from the probe asserts it and fails loud on mode 1 (P-ADDON (c)).
- Recipes collide through a trimesh from each GLB's `-col` mesh.
- A terrain event swaps one tile's shape on one tick, as `terrain_event.gd:7-11` swaps a finished collider today.
- Tiles build on `WorkerThreadPool`; the bodies enter the tree on the main thread at no more than 5 per frame.
- `park_collider_parity_test.gd` samples 10,000 seeded points per stage and requires `height()` and a downward ray on the collider to agree within 1 cm; hole cells must have no terrain hit.

Why not Terrain3D's collision: it would make a second height source beside the 2 m grid that combat, spawns, scatter and the bay read, and every terrain event would have to update both. The probe measured mode 0 working with a loud test, so the single trimesh rule costs nothing to keep. If the tiles miss the memory budget (section 9), HeightMapShape3D tiles built from the same grid may replace them, only after passing the same parity test with holes.

**Level of detail.** Terrain3D's clipmap with its defaults, `mesh_lods` 7 and `mesh_size` 48 (start), which reaches past 2.3 km, the distance from one corner of the play square to the far landmark. No `Camera3D.far` override exists in `src/`, so the 4000 m default stands. Recipes use `visibility_range_end`: base mesh 600 m, first detail shell 120 m, second 40 m (start). The hero landmark carries three levels: full to 600 m, a mid mesh of at most 6,000 triangles to 1.4 km, and a far mesh of at most 1,500 triangles beyond.

**Scatter.** The P-GROUND mechanism on native MultiMesh (`src/world/scatter.gd`, `scatter_rows.gd`), now chunked to the collider's 160 m tiles: one `MultiMeshInstance3D` per row per chunk, each with its own visibility range (rocks 220 m, pebbles 90 m, start). Today's batches span the whole map and cannot use a range (`scatter.gd:8-9`); chunks fix that. The per-map vertex budget of 400,000 (`scatter_rows.gd:22-23`) becomes a budget on what is visible from any one camera. Pieces stand on `height()`, never on a collider above it, which removes the floating rocks the probe saw. The Terrain3D instancer and Proton Scatter are not used.

**Materials.** `surface.bin` feeds Terrain3D's control map texture ids. The colour map comes from the landform tints in `Palette`, with today's slope tint for faces a pylon can bite (`terrain.gd:330-345`) moved into a shared function the bake calls, so the concrete-grey wall the probe lost comes back. As a look rule the park ground skips the tint inside the footprints of park_pit's six berm rows (`dump_berm_east`, `dump_berm_west`, `rim_road_berm`, `haul_ramp_berm`, `wash_berm` and `bench3_west_berm`, each padded 2 m, named once in `PylonBite.BERM_ROWS`): those berm flanks stay bitable (101 of 108 flank and foot samples in the probe posted on #241 6345448625) but untinted by design, so the tint under-reports them; the padded footprints also untint 51 vertices where `dump_berm_east`'s end and `haul_ramp_berm` touch the pit rim's top edge (coordinator 6342820238 item 3, 6345347272 item 4, NEEDS 6350588099). The slot multipliers are render-corrected against the 3060 bench, not only the board: basalt is `ParkTerrain.render_corrected()` (board over rendered Lab, per channel in linear light, because Terrain3D's `_color_maps` is `source_color`), and tailings are scaled by `TAILINGS_NOON_SCALE` so the noon pit's floor sits 10 L* off its horizon haze (#241 6352984236, 6353059714); the basalt correction comes from one 3060 measurement, the tailings scale is a cast-model prediction, and both wait for the 3060 re-measure. The Highdraft's net pattern never enters the colour map; the net deck is a recipe.

**Editor plugin.** `project.godot` gets no `[editor_plugins]` entry for Terrain3D; every smoke import otherwise fails on an exit leak (P-ADDON deviation 2). The vendor drop keeps the Linux x86_64 and Windows x86_64 release binaries (TADR-001 targets both) and the MIT licence; the probe stripped Windows, which is reversed here.

**Streaming.** None inside a stage: the whole park is resident. Between stages, the next stage's bake, Terrain3D data and collider tiles load on worker threads from the `warden_engaged` signal (`src/core/flow.gd:778`); the fight lasts 25 s or more in the posture bands, so the data is ready before the break. The swap applies on the launch flight's landing, the moment `terrain.use()` runs today (`terrain.gd:116-131`). Only the active stage and the next one are ever resident.

**Memory.** Estimates to be measured in unit KB6:

| Item | Per stage (estimate) |
| --- | --- |
| Terrain3D maps, 4 regions of 1024², height, control and colour | about 48 MB in RAM plus about the same as GPU textures |
| Collider: Godot face arrays (36 bytes per triangle) plus Jolt's mesh | about 46 MB plus about 15 to 25 MB |
| Bake files loaded | about 6 MB |
| Recipes and scatter | measured per family under the asset budget |

Peak is two stages during a swap.

## 4. Recipe landform families

Each family is one Blender recipe script under `tools/blender/park/<family>.py` that builds several recipe ids, each with two detail shells (the wave 12 `detail` class), a `-col` collision mesh, a registry fragment folded by `tools/fold_registry.py`, and a look subject with blind pairs at close, mid and far range. Placement comes only from `park_rows.recipe`.

| Family | Park elements | Arizona disguise and society | Verb and ride fact | Collider and hole | Budget class | Starting recipe ids |
| --- | --- | --- | --- | --- | --- | --- |
| Half-pipes and flow lines | `half_pipe`, `flow_line` | Slot canyons, arroyos, dry washes; concrete liners from the dam crews | `pump`, `roll`; `ride_chute` | Trimesh U-section, 12 to 40 m wide, walls 6 to 14 m, segments straight and bent 15 or 30 degrees | `landform` | `half_pipe_concrete`, `slot_canyon_flow`, `wash_dropin_lip` |
| Grind lines and rails | `grind_line`, `rail` | Hohokam canal lips, flumes, penstocks, pipelines | `grind` (harpoon bite, then `RideRail`); `ride_grapple_line` | Trimesh lip plus a rail line for `ride_rail.gd` | `landform` | `canal_lip`, `flume_span`, `penstock_run`, `pipeline_rail` |
| Bowls and terraces | `bowl`, `terrace` | Open-pit copper mine benches, tailings benches | `bank`, `pump`; `ride_bowl` (new) | Height stamp plus a recipe coping lip, 1.5 m radius | `landform` | `bench_coping`, `tailings_lip`, `pit_haul_ramp` |
| Tunnels and drops | `tunnel`, `drop` | Lava tubes, mine adits and shafts, spillway tunnels | `drop`, `roll`; `ride_chute`, `ride_drop` (new) | Trimesh tube with interior floor; `hole` true at the mouths. Mouths face along the fall line and roof lips bevel back 3 m, because a roof facing a ball in flight is a wall (`design-v3/TRAVERSAL.md:110`) | `park_large` | `lava_tube_run`, `adit_mouth`, `shaft_drop`, `spillway_tunnel` |
| Flooded caverns | `flooded_cavern` | Karst sinkholes, cenote pools, flooded shafts | `swing` on stalactite and shaft-timber anchors, `drop` into soft pools that keep planar speed; `ride_drop` | Trimesh cavern shell, `hole` true at the opening; pool depth 1.2 m at most, so a ball rolls out | `park_large` | `cenote_pool`, `flooded_shaft`, `cavern_shell` |
| Elevated lines and ledges | `elevated_line`, `ledge` | Ancestral Puebloan cliff dwellings, mesa rims | `swing` (projecting roof beams as pivot posts), `roll`, `bank`; `ride_ledge` (new) | Trimesh ledges at least 8 m deep; beams are harpoon targets | `landform` | `cliff_dwelling_row`, `mesa_rim_ledge`, `viga_pivot` |
| The Meteor Crater bowl | `crater_bowl` | Meteor Crater, the one landform older than any society | `pump`, `bank`; `ride_bowl` | Height stamp plus a rim recipe | `park_large` | `crater_event` (40 to 60 m, the impact event's crater), `crater_ending` (400 m, the ending bowl) |
| Sky-island hops | `sky_island`, `kicker` | The Madrean sky islands, buttes and spires; the animals' nets and balloons | `launch`, `glide`, `lift`; `kicker_launch`, `ride_glide_drop`, `thermal_ride`, `ride_hop` (new) | Mesas and buttes are height stamps; lips, kickers, the net deck and the one floating island are recipes | `landform`, `park_large` for the floating island | `mesa_lip_kicker`, `net_deck`, `floating_island` |

The Gorge-only pieces (gauge, geyser, cannon, trebuchet, lift) ship as contraption skins, not park elements: their `recipe` goes on `contraption_rows`. The hero landmarks are one recipe each (`landmark_dam`, `landmark_penstock_tower`, `landmark_headframe`, `landmark_sinkhole`, `landmark_sky_island`, `landmark_spire`) under the `hero_landmark` class.

**The real-culture guardrail.** The Hohokam and the Ancestral Puebloans are real peoples whose descendants live in Arizona today. Their canals and cliff dwellings are references for how a landform was shaped, never enemies, loot or targets. In the game, the canal builders and the cliff builders are fictional predecessor peoples whose works echo those techniques; the reference names live in the Bible's external-references glossary, not in the fiction. A row with `society` `hohokam` or `ancestral_puebloan` houses no enemy home, is never the site of a ground-changing or destructive event, and carries only a `ref_` codex fragment, which describes the work and the water or stone it managed and makes no claim to speak for a living people. The schema check in 2.10 enforces this. Mining, the dam era, the Fleet and the ancients carry no such limit.

## 5. The event grammar

Every event row obeys five rules. The tests in unit KE1 hold each one.

1. **Telegraph first.** An event announces itself with its `form` row (colour, shape, sound) and a music riser, at least `lead_s` before it can touch the ball. Floors: 3 s for a hazard with no ground change, 5 s for a ground change, 8 s for a Fleet landing or an ancient eruption (start). With `on_bar` true, the landing waits for the next downbeat, adding at most one bar (1.4 s at 172 BPM), so the change lands on the drop. Hostile changes use the hostile family's colour and a falling, pure sound; rides use a rising, breathy one (the grammar at `event_kinds.gd:818-822`).
2. **Never stop the ball.** No event applies drag, a stun, a hold or a slow. A hazard costs scrap armour or lifts the ball straight up, as the Warden's pulse does without touching planar speed (`warden.gd:18-23`). New geometry never appears within `hold_clear_m` of the ball or across its next 2 s of travel; the change waits until the ball is clear (the hold rule, `terrain_event.gd:7-11`). Rising water never rises under the ball, and event water is at most 1.2 m deep, the pool depth a ball rolls out of (section 4, flooded caverns); deeper water would need swim handling the code does not have. A Fleet landing or eruption footprint never crosses an 8 m corridor around a measured pilot line unless the same row opens another route.
3. **A route always open.** After any set of events that may be live together, the route graph still connects `drop_in` to `landmark`. `park_routes_test.gd` walks every allowed combination.
4. **A music cue.** The telegraph cue rises over the lead; the land cue is a drop on the landing downbeat. Natural events use the stage band; Fleet events borrow Brindle's anvil and brass; ancient events use their family's sound (the reactor's tritone pedal, the swarm buzz that locks into a quartal chord, the Mind's inverted class motif); industrial events use the steam whistle rising into a percussion hit.
5. **Bounded overlap.** At most two ground-changing events live at once, one Fleet event, one ancient eruption. No new event starts within 20 s after a Warden break, so the gates and the bay stay calm (start).

**Kinds and families.**

| Family | Kinds | Effect keys |
| --- | --- | --- |
| natural | `flood_fill`, `drain`, `cave_in`, `collapse`, `impact`, `flash_flood`, `lightning` | `depth_m`, `fill_s`, `material`; `swap` (an overlay id); `strike_m`, `damage` |
| fleet | `fleet_landing` | `vessel` (`drill_barge` or `dropship`), `home` (a dormant home row id), `footprint_m` |
| ancient | `machine_eruption` | `miniboss` (a roster ancient kind), `swap` |
| industrial | `boiler_burst`, `reactor_blow` | `hazard`, `hazard_m`, `damage`, `swap` |

**The dial.** `clock_tier` reads the director's `effective_tier()`: the clock tier, one step every 45 s up to `MAX_TIME_TIERS` (2 on the alpha table, 4 on park stages with veto item 16), plus 2 after a Warden break (`director.gd:83-85`, `160-165`). The cap is a design constant chosen with the stages, not a tuning knob: it changes only with a dated decisions row. The dial raises how many enemies come and how soon (`cap()`, `interval()`) and which event rows may fire. It never raises enemy health, a price or a Warden's numbers (`director.gd:7-8`; TADR-010:45).

**Triggers.** `warden_phase` reads the fight: `engaged` (`flow.gd:778`), `stagger` (each one, `warden.gd:526`), `chunk_1` to `chunk_3` (a chunk lost), `broken`.

One example row per family:

```json
{"id": "plunge_pool_flood", "kind": "flood_fill", "family": "natural", "site": "plunge_pool",
 "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
 "telegraph": {"lead_s": 6.0, "form": "flood_rising", "on_bar": true},
 "live_s": 35.0, "effect": {"depth_m": 1.2, "fill_s": 10.0, "material": "water"},
 "route_change": {"closes": ["pool_floor"], "opens": ["pool_rim"]},
 "hold_clear_m": 12.0, "cooldown_s": 90.0, "once": false,
 "music_cue": {"telegraph": "riser_natural", "land": "drop_flood"}}
```

```json
{"id": "bench3_drill_barge", "kind": "fleet_landing", "family": "fleet", "site": "bench_3_apron",
 "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0,
 "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true},
 "live_s": 0.0, "effect": {"vessel": "drill_barge", "home": "barge_drill_crew", "footprint_m": [40, 18]},
 "route_change": {"closes": [], "opens": ["barge_ramp"]},
 "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true,
 "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}}
```

```json
{"id": "tube_machine_wakes", "kind": "machine_eruption", "family": "ancient", "site": "lava_tube_junction",
 "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0,
 "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true},
 "live_s": 0.0, "effect": {"miniboss": "swarm_remnant", "swap": "eruption_lip"},
 "route_change": {"closes": ["tube_floor"], "opens": ["eruption_lip"]},
 "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true,
 "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}}
```

```json
{"id": "powerhouse_boiler", "kind": "boiler_burst", "family": "industrial", "site": "powerhouse",
 "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0,
 "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true},
 "live_s": 8.0, "effect": {"hazard": "steam_cone", "hazard_m": [24, 10], "damage": 6.0, "swap": "powerhouse_roof_ramp"},
 "route_change": {"closes": ["powerhouse_floor"], "opens": ["roof_ramp_line"]},
 "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true,
 "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
```

The `form` ids `flood_rising`, `fleet_inbound`, `ancient_stirring`, `boiler_pressure` and their landing facts are new `WORLD_ROWS` rows (unit KE1). The miniboss runs through `src/combat/miniboss.gd`.

## 6. The six stages at a glance

Map ids and display names are exact. The other columns carry the storyboards' refined numbers (the K-CRITIC pass, 2026-10-10); each stage page under `park/stages/` explains any change from the first start.

| Stage | World | Map id | Display name | Landform theme | Hero landmark | Warden kind and mounting | Time of day | Weather |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 Spillway Works | `park_dam` | Spillway: the dam | Slot canyons, a lined arroyo and washes as half-pipes; dam-era canal headworks on the east bench; cliff dwellings on the west wall; the plunge pool bowl | The spillway dam, 120 m face, 320 m crest, at the south end | `reactor` on `dam_face` (open air) | `dawn` | Monsoon build-up |
| 2 | 1 Spillway Works | `park_flume` | Spillway: the flume | Hohokam canal fields, a 1.2 km flume on trestles, penstocks as grind lines; the horseshoe bend; the flume crews' ledge camp on the mesa face | The penstock tower, 90 m, where the flume ends in the east | `reactor` on `flume` (in a building, the flume head house) | `morning` | Dust squall |
| 3 | 2 The Dig | `park_pit` | The Dig: the open pit | An open-pit copper mine 900 m across and 100 m deep: benches as terraces, the haul road as a spiral flow line, tailings benches, adits in the walls | The headframe, 120 m, over the main shaft on a 100 m deep pit floor, its top 20 m above the plain | `swarm` on `headframe` (suspended on the hoist cable) | `noon` | Heat shimmer and dust devils |
| 4 | 2 The Dig | `park_sinkhole` | The Dig: the sinkhole | A plateau cut by lava tubes, adits and flooded caverns; at least 40% of each line under a roof | The sinkhole, 250 m wide and 120 m deep, open to the sky, with a light column | `swarm` on `sinkhole` (underground, nesting on the wall above the pool) | `afternoon` | Cave mist and drip |
| 5 | 3 The Highdraft | `park_islands` | Highdraft: the sky islands | Mesas and buttes 120 to 220 m tall on the heightfield, a net deck strung between them at 60 m, thermals and cables across the gaps | The Hanging Isle, its top deck at 400 m and its tip at 82 m, the one island that floats | `mind` on `under_island` (suspended beneath it, holding it up) | `golden` | Thermals and a rising cloud deck |
| 6 | 3 The Highdraft | `park_crown` | Highdraft: the crown | Monument Valley buttes, hoodoo forests as harpoon anchor fields, spires | The Crown Spire, 330 m, with three perch spires around it | `mind` on `spires` (flying between the three perches) | `dusk` | Thunderstorm with lightning |

The boss arenas (Brindle, the Waking, the Mind) stay authored and small. Meteor Crater is the ending bowl, entered after the Mind, built from `crater_ending`. No stage places it; stages carry only the 40 to 60 m `crater_event` an impact leaves. Today's ending is three 12 s world flyovers then 18 s of credits (`src/ui/ending_sequence.gd:15-24`); the crater becomes the ending's last set, a fourth beat after the Highdraft flyover where the camera drops over the rim and the credits roll over the bowl (unit KC10 in `artifacts/local/alpha/push/w13/design/K-UNITS.md`). Since Andrew's design answer Q16 (2026-10-17, "60 s free roll"), the ending is the three flyovers, then a 60 s playable victory lap in the bowl with no enemies, hazards or fail state (`src/world/victory_lap.gd`), then the credits over the bowl.

**Signature events, start.** Stage 1: the plunge pool floods (natural); the pump house boiler blows (industrial). Stage 2: a trestle span collapses into a ramp (natural); the heat-exchanger annex beside the head house blows at the Warden's second chunk (industrial, `reactor_blow`). Stage 3: a drill barge lands on a bench and sets up a drill crew home (Fleet); a tailings bench collapses (natural). Stage 4: a cave-in opens a new tube (natural); a buried machine erupts in a tube junction (ancient). Stage 5: a dropship lands on a mesa and sets up an anchor crew home (Fleet); the cloud deck rises over the net (weather). Stage 6: lightning strikes marked spires (natural); a machine erupts from a spire's foot (ancient).

**Enemy homes, start.** Spillway: chasers in wash culverts, lobbers on the canyon service ledges, mag trappers in the pump house, plated brutes in the spillway tunnel mouth, reactor relics in vent pits at the dam toe. The Dig: burrowers in tailings, drill crews in adits, lamp swarms in dark shafts, swarm remnants in the sinkhole cells. The Highdraft: line cutters at cable anchors, anchor crews on mesa rims, kite drones in thermal columns, Mind's hands on spire tops. Each world's ancient enemy is the same kind as its Warden.

**Time of day.** The six picks make one day across a run: dawn at the dam to dusk at the crown. The sun's height tells the player how far the run has come. Each id is a row in `world_look.gd` `TIME_ROWS` (sun rotation, colour, energy, ambient), entered with the stage.

### 6.1 The storyboard and sheet format

**As built in wave 13 (coordinator, 2026-10-10).** The stage page is the per-stage storyboard. The pictures come per world, not per stage: `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json`, `park-w2.json` and `park-w3.json` each hold three vistas per stage and four pictures for the world's Warden kind. Codex image generation (gpt-6-astra) draws them, because Andrew rejected FLUX for intricate subjects on 2026-10-10 (`docs/decisions.tsv`); the briefs and results sit under `concepts/codex/park/<unit>/`. Andrew approves by click on the concept-board artifact page, and the coordinator records each approval in `docs/decisions.tsv`. The set went through two cleanup rounds before the gate (`concepts/codex/park/fix1/`, `fix2/`, audits under `park/audit2/`): round 1 edited for the set rules, round 2 recoloured every ancient light to green by a masked ImageMagick hue shift (`fix2/recolour/recolour.sh`, no model call) and fixed one subject per picture by Astra edit, with the coordinator judging each candidate against the six set rules rather than pixel identity outside the edit box (`docs/decisions.tsv` 2026-10-10 19:09). Board version 5 carries the 30 pictures; the finish drift and the page-proportion misses listed in the audit are carried deviations, not blockers. The package layout and panel names below are the original plan; `p1_overhead` from `tools/park_plot.py` is still due with the KD greybox.

**The gate moved from pictures to journeys (coordinator, 2026-10-10, later the same day).** Andrew asked for the clicks to follow the player's journey to each Warden with connecting material, not a grid of concept art. Each world now has a journey page under `park/journeys/` (`world-1-spillway-works.md`, `world-2-the-dig.md`, `world-3-the-highdraft.md`): the journey in one paragraph, the world arc, every beat of both stages with You, You see, Pull, Pressure, Seconds, Music and Panel, the bay between the stages, the Warden climax beat by beat to the drop finisher and the exit, the overhead route as `park_rows` ids, and the connecting material. The 30 pictures above sit on the beats they show; 41 new panels (`concepts/codex/journeys/world-N/`) fill the beats they did not, drawn by Astra from the beat's Panel brief, audited per world and cleaned in one edit round (15 panels). `tools/concept/journey_page.py` renders the three journeys as one click-gate page (96 beats, 68 pictures); Andrew approves or reworks per beat and once per world, and the verdicts land in the page's `journeys` store, which the coordinator reads back into `docs/decisions.tsv`. A stage's build (KD units) starts after its world's journey is approved.

The original plan:

```
design-v3/park/
  stages/<n>-<map_id>.md            the stage design page (one per stage)
  storyboards/
    boards/park-<n>-<map_id>.json   a concept-board spec per stage
    boards/warden-<kind>.json       a concept-board spec per Warden kind
    images/<board_id>/<panel>_<seed>.png and .t.jpg
    catalog.json                    the scrapkeep-storyboard/1 catalog
    manifest.json                   built, with hashes
    build_package.py                copy of design-v3/storyboards/build_package.py, HERE set to this folder
design-v3/wardens/<kind>.md         the Warden kind sheet (reactor.md, swarm.md, mind.md)
```

A board spec uses the concept-board shape `tools/concept/gen_board.py` and `board_widget.py` read: `{"style", "seeds", "steps", "subjects": {panel: prompt}, "labels": {panel: title}, "roles": {panel: one line}}`. Stage boards have six panels: `p1_overhead` (drawn from the park file by `tools/park_plot.py`, not generated, so the plan view and the build share one source), `p2_drop_in` (the view from the drop-in, landmark on the skyline), `p3_line` (a ride on the line), `p4_home` (an enemy home in its landform), `p5_event` (an event's telegraph and its result), `p6_warden` (the Warden in its mounting). Warden boards have five: `w1_body`, `w2_mount_a`, `w3_mount_b`, `w4_anchor` (latch, ride, fire from the line), `w5_break` (stagger, break, drop finisher). `catalog.json` entries follow the existing catalog (`design-v3/storyboards/catalog.json`: `id`, `title`, `group`, `selected`, `source`, `initial`, `correction`, `largest`, `panels`, `versions`) with `group` set to `park` or `warden` and one added field, `approved`: `{"by": "andrew", "date", "decisions_row"}` or null. Board ids are `park-<n>-<map_id>` and `warden-<kind>`. The widget's Approve button sends "Approve storyboard <board id> seed <seed>"; the coordinator records the approval in `catalog.json` and `docs/decisions.tsv`. Boards render on card 0 through `tools/coordinator/gpu_queue.sh` and `tools/concept/run_board.sh`.

## 7. The Warden kinds

**The shared posture grammar stays.** Every Warden fights on posture (`src/combat/boss_posture.gd`; `design-v3/LEGIBILITY.md` section 4): a pulse telegraphed for 2 s every 6 s (`warden.gd:40-42`), posture from 0 to 100 that drains after 3 s without gain, a 4 s stagger at 100 that opens the core, four chunks with at most one lost per stagger, and the harpoon drop as the finisher that shatters an open core (principle 23: at the Warden the harpoon is a drop finisher, never a bowl hammer). Plating, health and the posture curve stay on the stage rows. Detail per kind lives in `design-v3/wardens/<kind>.md`.

**Every Warden is a harpoon anchor.**

- **Latch.** Each Warden carries 3 hardpoints (start), rimmed in the ancients' green, that the harpoon bites from rope range (45 m, `src/movement/tuning.gd:18`). A hardpoint line is a world-style line that follows the body: the anchor moves with it, as `augments.gd:697-702` already does for enemies.
- **Ride.** On a hardpoint line the ball swings as on a world line (`augments.gd:670-688`) and the winch shortens it. Unlike an enemy line, it does not drop when the ball passes inside the minimum rope (`augments.gd:711`); the ball orbits or hangs.
- **Fire from the line.** The weapon slot fires while the ball hangs. Gun bolts add 1.5 posture each, as today.
- **Drag.** When the mounting moves (the hoist cage, the flying hand, the tilting island), the anchor moves and the rope's tension carries the ball. Letting go keeps the ball's velocity.
- **Resist.** Once per pulse cycle the Warden shrugs: a hardpoint with a line on it flares for the pulse's 2 s telegraph, then the line drops on the pulse. The ball keeps its velocity plus the pulse's upward lift. During a stagger every hardpoint holds, and a release above the open core followed by haul is the drop finisher.

**The kinds and their mountings.** The kind ids are the existing family ids (`src/combat/roster.gd:31-33`). Each mounting adds one mechanism.

| Kind id | Display | World | Mounting id | Where | Mechanism to play around | Variant |
| --- | --- | --- | --- | --- | --- | --- |
| `reactor` | The reactor relic | Spillway Works | `dam_face` | Open air, on the dam's curved face 18 to 25 m above the toe apron | The spillway gates open on each pulse and a water sheet runs down the face for 3 s; riding the sheet carries the ball up the curved apron into the relic | `""` |
| `reactor` | The reactor relic | Spillway Works | `flume` | In a building, the flume head house at the top of the penstock tower | It boils the flume: slag lanes run down the channel toward the ball, and its core window lasts 1.5 times longer (today's meltdown, `warden.gd:28-31`) | `meltdown` |
| `swarm` | The swarm remnant | The Dig | `headframe` | Suspended on the hoist cable inside the headframe | The cage rises and falls on a 12 s cycle (start), exposed at the top for 4 s; latching drags the ball up the headframe; the drop finisher comes from the sheave wheel | `""` |
| `swarm` | The swarm remnant | The Dig | `sinkhole` | Underground, nesting on the sinkhole wall above the pool | A lamp swarm guards it (today's brood, `warden.gd:31-32`); the pool rises one step per chunk lost, lifting the floor toward the nest | `brood` |
| `mind` | The Mind's hand | The Highdraft | `under_island` | Suspended beneath the floating island, holding it up | The island deck tilts 10 degrees toward the ball on each pulse (start); the lens follows the ball | `""` |
| `mind` | The Mind's hand | The Highdraft | `spires` | Flying between three perch spires | It moves to the next perch every 8 s (today's choir cycle, `warden.gd:62`); the open lens seat is the current perch; a stagger braces against the ball's top habit; latching drags the ball along its flight | `choir` |

The three variants keep their codex entries (`slag_hop`, `brood_dark`, `choir_switch`, `src/combat/codex_entries.gd:133-146`, `174-176`) and the deep-works and crown lore lines (`src/core/lore_rows.gd:224`, `342`). A Warden that moves needs an engage ring larger than its path; `reach_m` on the landmark row sets it, and the pulse ring stays the kind sheet's number.

**Reconciling the stage rows with one kind per world.** Unit KF0 edits `alpha_defs.gd:69-120`:

| Stage | `warden_family` now | after | `ancient` now | after | `warden_variant` now | after | Mounting |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | reactor | reactor | reactor_relic | reactor_relic | `""` | `""` | `dam_face` |
| 2 | swarm | **reactor** | swarm_remnant | **reactor_relic** | `""` | **`meltdown`** | `flume` |
| 3 | reactor | **swarm** | reactor_relic | **swarm_remnant** | meltdown | **`""`** | `headframe` |
| 4 | swarm | swarm | swarm_remnant | swarm_remnant | brood | brood | `sinkhole` |
| 5 | mind | mind | mind_hand | mind_hand | choir | **`""`** | `under_island` |
| 6 | mind | mind | mind_hand | mind_hand | choir | choir | `spires` |

`Roster.warden_family(stage)` indexes by stage (`roster.gd:185-186`), not world; KF0 changes it to read the world, so a row without the key still gets its world's kind. The posture bands were calibrated per stage with the old families (`tests/alpha_posture_bands_test.gd`); stages 2, 3 and 5 are re-measured and re-pinned with dated headers. The Mind boss keeps its own choir Warden (`src/boss/mind.gd:58`).

## 8. Traversal acceptance

The traversal measure (`design-v3/TRAVERSAL.md`) carries over with its definitions: flow share, dead stop, max anchor gap, and the bot's 0.15 s reaction and 0.4 s press gap (`TRAVERSAL.md:9-20`). The park adds measures and runs on every stage for every pilot.

**The lines.** Each stage has one line per pilot in `assets/park/<map_id>/lines.json`: `{"map", "stage", "pilots": {pilot: {"waypoints": [[x, z] or waymark id], "bar": {"band": "PARK.md section 8", "airborne_share": [lo, hi]}}}, "floor": {"waypoints": [...]}}`. Pilot keys are `sable`, `rivet`, `kest`, `tarn`, `tally`, `cannon` (class ids `pylon_engineer`, `runner_gunner`, `demolitions_caster`, `tarn`, `tally`, `remembered_cannon`, `src/core/class_def.gd:87-122`). Every line starts at `drop_in`, names each of the stage's waymark ids in order and ends at `landmark`. The `bar` object carries only what varies by stage (the airborne band); every other band is the table below. The `floor` line is ridden with no harpoon and no contraption.

**The bands** per pilot per stage, 8 seeds (start):

| Measure | Band |
| --- | --- |
| Reached the Warden | 8 of 8 seeds |
| Drop-in to Warden engage (`time_to_warden_s`) | median 60 to 120 s; no seed over 150 s |
| Waymark to waymark (`segment_s`) | each segment's median 12 to 45 s |
| Flow share (speed tier 2, 16.1 m/s, or above) | median at least 0.70; no seed under 0.60 |
| Fraction airborne (`airborne_share`) | 0.12 to 0.45; stages 5 and 6: 0.25 to 0.60 |
| Dead stops | 0 on every seed |
| Peak planar speed (`peak_speed_mps`) | at least 26.6 m/s (the blazing tier, 1.9 times cruise 14, `src/movement/speed_tier.gd:5-8`) on every seed; at least 3 s at that tier (`tier3_s`, median) |
| Longest quiet stretch (`quiet_max_s`) | at most 20 s with no ride fact, kicker launch, bite or drop of 4 m or more |
| Max anchor gap | at most 40 m |
| Distinct verbs (`distinct_verbs`) | at least 3 different ride facts per line |
| Line length over straight distance | 1.3 to 2.0 |
| Floor line | reaches the Warden in at most 2.0 times the pilot line's median time, 0 dead stops |
| Distinct lines per stage | at least 3 across the six pilots; two lines are distinct when fewer than half their ticks lie within 8 m of each other |

**How the bot measures.** `tools/traversal_line.gd` gains `--table=park --stage=<n> --pilot=<key>` for all six pilots and `--floor`. Its sampler adds `airborne_share` (ticks with no ground contact over all counted ticks), `peak_speed_mps`, `tier3_s`, `segment_s` (stage seconds between waymark passes, a waymark counting as passed within 12 m), `quiet_max_s` and `distinct_verbs`, on top of today's `flow_share`, `dead_stops`, `max_anchor_gap_m`, `time_to_warden_s`, `path_length_m`, `rides` and `uphill_m`. `RunLog.Traversal` (`src/core/run_log.gd:41`) gains the same airborne share and peak speed, so Andrew's own runs log the numbers the bot is judged by. 288 runs per pass (6 stages by 6 pilots by 8 seeds), six in parallel.

**Where it is recorded.** Per seed and summary JSON under `artifacts/local/traversal/park/<map_id>/<pilot>.json` (local evidence, not committed), a committed table per stage in `design-v3/park/TRAVERSAL-PARK.md` written at each greybox pass and each dressed pass, and a `docs/decisions.tsv` row when a stage passes. A stage that misses a band does not merge; its unit's fix round reworks the park rows, not the band. The numbers judge a bot; Andrew's sitting judges the fun (`TRAVERSAL.md:123`).

**Two more stage tests.** `park_landmark_sight_test.gd`: on a 50 m grid over the play square, excluding hole and roofed cells, at least `sight_share` of points have a clear ray from 2 m above the ground to `landmark.sight_top` over the baked heights. `park_density_test.gd`: no open play cell lies more than 80 m from a non-ground park row's footprint (start; the base `plain` ground row covers the whole square and would make the rule vacuous, so `ground` rows do not count, the same split `park_map.gd` makes for the scatter keep-out; coordinator ruling at the KD-T merge, 2026-10-11).

## 9. Performance budgets

Absolute numbers come only from Andrew's display. On card 1 under the GPU queue, only ratios count (the probe ran at about 7 FPS under the offload path). The base is the `cand/alpha-w13` head before K-B merges, recorded by SHA in KB6.

| Measure | Budget | Where |
| --- | --- | --- |
| CPU main-thread p99 | at most 10 ms | `scripts/checkpoint.mjs:43`; measured with card 1 to itself, because P-GROUND saw process p99 rise to 18.3 ms with siblings on the card |
| GPU p99 | at most 1.3 times the base, same scene, card 1; at most 7 ms on Andrew's display (`checkpoint.mjs:44`) | `tools/perf_bench.gd` scenes s3 and the new p1, p2 |
| Frame p99 | at most 1.3 times the base | same |
| Draws p99 | at most 1.3 times the base on s3; at most 1,400 on p1 (start; s3 measured 1,022 on the probe's base). The probe measured 2.06 times with unmerged scatter chunks (TADR-011:15), so KB5 merges each chunk's scatter into one MultiMesh per kind to meet this; if KB6 still reads over 1.3 times while GPU and frame p99 pass, the coordinator brings the draws number to Andrew rather than failing the wave | same |
| Visible scatter vertices | at most 400,000 from any camera | `scatter_rows.gd:22-23` |
| Static memory | at most 350 MB more than the base with two stages resident (start). Estimate, not measured: a 1.28 million triangle trimesh is about 46 MB of faces plus its BVH, roughly 100 MB a stage; four 1024 m regions of height, control and colour maps are about 48 MB a stage; two stages land near 300 MB, so KB6 measures before any stage is built | `Performance.MEMORY_STATIC` |
| Video memory | at most 300 MB more than the base (start) | `Performance.RENDER_VIDEO_MEM_USED` |
| Stage swap | no main-thread frame over 33 ms during the launch flight; next stage ready within 20 s of Warden engage | KB6 swap probe |
| Recipes | `landform` 8,000 triangles, 1 draw (exists); `park_large` 16,000 triangles, 2 draws (new); `hero_landmark` 24,000 triangles, 6 draws, mid mesh 6,000, far mesh 1,500 (new); `detail` 1,500, 1 draw (exists) | `assets/asset_budgets.json` |

New bench scenes: p1 is the drop-in vista with the landmark across the park and no fight; p2 is a dense fight at the landmark with one event live.

## 10. Implementation map, waves K-B to K-F

Every unit writes in its own worktree, gets a verifier and one fix round; the coordinator merges. Red-then-green Godot tests, `node scripts/sketch-lint.mjs --sketch core-loop`, the related smoke and a fence check with `git diff --name-status` against SCOPE apply to every write unit.

### Wave K-B, terrain base (no storyboard needed; it builds only the test park)

**KB1 Vendor Terrain3D.** SCOPE: `addons/terrain_3d/` (Linux and Windows x86_64 release binaries, licence), `tests/addon_load_test.gd` ported from `wt/w12-addon` e8f0df8. ACCEPTANCE: clean headless import; `addon_load_test` passes including collision mode 0, and fails on mode 1 (the receipt); no `[editor_plugins]` entry. Order: first. Conflicts: none.

**KB2 Park schema and loader.** SCOPE: `src/world/park/park_schema.gd`, `park_map.gd`, `park_test.json` (a full 1.6 km fixture with a few rows of each table), `tests/park_schema_test.gd`, `tests/park_map_test.gd`. ACCEPTANCE: every check in 2.10 fails red on a planted bad row; `park_map` fills every stage_map field from the fixture. Order: with KB1. Conflicts: none.

**KB3 Bake.** SCOPE: `tools/park_bake.gd`, `src/world/park/park_stamps.gd`, `assets/park/park_test/`, `tests/park_bake_fresh_test.gd`. ACCEPTANCE: two bakes give identical bytes; the freshness test goes red on a table edit. Order: after KB2.

**KB4 Park terrain and collider.** SCOPE: `src/world/park/park_terrain.gd`, `src/world/terrain.gd` (route `park_*` map ids to `park_terrain`, the height and layer queries, threaded next-stage load, the swap on landing), `tests/park_collider_parity_test.gd`, `park_holes_test.gd`, `park_swap_test.gd`. ACCEPTANCE: four regions at 1024 and 1 m spacing; 100 tiles of 160 m; parity within 1 cm at 10,000 points; hole cells have no terrain collider and read the floor beneath; every existing terrain and map test still green on the old maps. Fable review. Order: after KB3. Conflicts: `terrain.gd` (only KB4 in K-B).

**KB5 Scatter chunks.** SCOPE: `src/world/scatter.gd`, `scatter_rows.gd`, `tests/scatter_rows_test.gd`. ACCEPTANCE: 160 m chunks with ranges; visible vertices at most 400,000 at the fixture's worst camera; old maps' transforms unchanged. Order: after KB4.

**KB6 Perf and memory probe on card 1.** SCOPE: `tools/perf_bench.gd` (scenes p1 and p2), evidence under `artifacts/local/alpha/push/w13/`. ACCEPTANCE: section 9 ratios against the recorded base; memory and swap numbers reported; the collider fallback decision written down. Order: after KB5.

**KB7 Traversal tool for parks.** SCOPE: `tools/traversal_line.gd`, `src/core/run_log.gd` (Traversal fields only), `tests/traversal_measure_test.gd`, `assets/park/park_test/lines.json`. ACCEPTANCE: the new measures on the fixture, with a planted dead stop caught. Order: after lane 1's bot adapter (B4) merges, because both touch the bot's presses; `run_log.gd` is also edited by B3, so KB7 merges after B3. Conflicts: `tools/bot_driver.gd` (read only here), `run_log.gd`.

### Wave K-C, landform recipes (after the family look is approved on the first stage board)

**KC0 Placement and registry.** SCOPE: `src/world/park/park_recipes.gd` (load GLBs, trimesh from `-col`, visibility ranges, detail shells, `greybox:` stand-ins), `assets/asset_budgets.json` (`park_large`, `hero_landmark`), `src/core/event_kinds.gd` (new ride facts `ride_bowl`, `ride_drop`, `ride_ledge`, `ride_hop`), `tests/park_recipes_test.gd`. Order: first in K-C. Conflicts: `event_kinds.gd` and `asset_budgets.json` (KC0 only; lane 1 edits to `event_kinds.gd` merge serially).

**KC1 to KC8, one per family** (section 4). SCOPE each: `tools/blender/park/<family>.py`, `assets/models/park/<recipe>*.glb`, a registry fragment, a look subject fragment. ACCEPTANCE: `npm run asset:inspect -- <glb> --max-tris <class>` passes; the collider is the `-col` trimesh; a headless roll along each recipe fires its ride fact with no dead stop; blind pairs read at close, mid and far. Order: parallel, GPU jobs through `gpu_queue.sh`. Conflicts: the registry fold and `tools/look_subjects.gd` are folded serially by the coordinator.

**KC9 Contraption skins.** SCOPE: recipes for gauge, geyser vent, cannon, trebuchet, lift platform, barge; `contraptions.gd` reads `recipe` through `RecipeProps`. Conflicts: `contraptions.gd` (KC9 only).

### Wave K-D, six stage rebuilds (each after its storyboard is approved)

**KD0 Park table.** The coordinator adds `src/core/park_defs.gd` (alpha rows with the six park map ids and the KF0 Warden columns) and the `--table=park` option. Order: before KD1.

**KD1 to KD6, one per stage.** SCOPE each: `src/world/park/<map_id>.json`, `assets/park/<map_id>/`, `assets/park/<map_id>/lines.json`, `tests/park_<map_id>_test.gd`, `design-v3/park/stages/<n>-<map_id>.md`. ACCEPTANCE: schema and freshness green; the greybox traversal bands met for all six pilots and the floor line; sight share and density tests green; the route test green; a win proof on `--table=park` for the stage; then recipes swapped in and the bands met again; stage tests re-pinned with dated headers. Order: parallel, each gated on its storyboard. Conflicts: none between units; `park_defs.gd` edits are the coordinator's.

**KD7 Switch.** When all six pass: `alpha_defs.gd` takes the park map ids, `park_defs.gd` is deleted, and the old `map_*.gd` files retire with their tests (subtract to add). Coordinator, with an Opus gate read.

### Wave K-E, dynamics (after the first stage's greybox lands)

**KE1 Event rows engine.** SCOPE: `src/world/event_director.gd` (read `event_rows` and `weather_rows`; the two trigger kinds; telegraph with the lead floor and downbeat; the general hold rule; overlap caps; facts), new `WORLD_ROWS` forms in `event_kinds.gd`, `tests/park_events_test.gd`, `tests/park_routes_test.gd`. ACCEPTANCE: each trigger fires in a stepped headless run; no lead is shorter than `lead_s`; no change lands within `hold_clear_m`; caps hold over 10,000 seeded steps; the route graph stays connected after every fact. Order: first in K-E. Conflicts: `event_director.gd` (KE1 only); `event_kinds.gd` after KC0.

**KE2 Natural kinds**, **KE3 Fleet landings and dormant homes**, **KE4 Ancient eruptions** (through `miniboss.gd`), **KE5 Industrial kinds.** SCOPE each: its own file under `src/world/events/`, its tests. Order: parallel after KE1.

**KE6 Homes and reinforcements.** SCOPE: `src/world/director.gd` (arrivals from live homes 60 to 250 m ahead, else today's ring; breaking a home stops its kind), `tests/director_homes_test.gd`. Conflicts: `director.gd` (KE6 only).

**KE7 Weather and time of day.** SCOPE: the weather path in the event director's weather module, `src/presentation/world_look.gd` (`TIME_ROWS`, weather fog and sky), tests. Conflicts: `world_look.gd` (KE7 only).

**KE8 Music cues.** SCOPE: `src/presentation/music_rows.gd` (`CUES`), the music engine's cue hook, tests. Conflicts: music files (KE8 only).

### Wave K-F, three Warden kinds (the reconciliation can start at once; bodies after the kind sheets are approved)

**KF0 Reconciliation.** SCOPE: `alpha_defs.gd` rows per section 7, `roster.gd` `warden_family` by world, `tests/alpha_posture_bands_test.gd` re-pinned. Coordinator-serial on `alpha_defs.gd`.

**KF1 Mounting and anchor framework.** SCOPE: `src/combat/warden.gd` (mounting spec, hardpoints, the moving anchor, the shrug), `src/movement/augments.gd` (the Warden-line exemption from the minimum-rope drop), `tests/warden_anchor_test.gd`. ACCEPTANCE: a bot latches each kind, rides at least 3 s, fires from the line, is dragged by a moving mounting, keeps its velocity on a shrug, and finishes with a drop. Order: after KF0.

**KF2 to KF4, one per kind's mechanisms.** SCOPE: `src/combat/warden_reactor.gd`, `warden_swarm.gd`, `warden_mind.gd`, tests. ACCEPTANCE: each mounting's mechanism in a stepped run; `tests/posture_bands_test.gd` gains a band per kind.

**KF5 to KF7, one body per kind.** SCOPE: `tools/blender/warden_<kind>.py`, its GLB and clips (idle, pulse, active), `hero_assets.gd` rows, a look subject. Order: after the kind sheet is approved.

**KF8 Wiring.** SCOPE: `warden_look.gd`, `warden_kit.gd` (read the kind body), and each park file's `landmark.warden` object only. Order: after KD and KF5 to KF7. Conflicts: the park files belong to KD units, so KF8 edits `landmark.warden` only, after they merge.

## 11. Risks and the veto list

### Risks, each with its cheapest check

| Risk | Check |
| --- | --- |
| Hollow stretches at sixteen times today's area (the plan's named concern) | The storyboard gate; `quiet_max_s` at most 20 s; the density test; the greybox measured before dressing |
| The collider's memory and build time at 1.28 million triangles | KB6 measures; the HeightMapShape3D fallback with the same parity test |
| The probe's look regressions: floating rocks, cup rocks, the lost wall tint, the Highdraft grid colour | Scatter on `height()`; closed kit meshes; the shared slope tint; the net kept out of the colour map |
| A bot line is not fun (`TRAVERSAL.md:123`) | Andrew's sitting, with the run log's flow share and airborne share beside his notes |
| Layered events bury the next useful action | The overlap caps; the 20 s calm after a break; his sitting |
| CPU main-thread p99 over 10 ms, seen unexplained in P-GROUND | Measure with card 1 to itself before any verdict |
| Six parks, three Warden kinds and six pilots in one session | The parks stay behind `--table=park`; an export at every wave close |
| Shared files across lanes (`bot_driver.gd`, `run_log.gd`, `event_kinds.gd`) | The serial order in section 10 |
| Terrain3D's Windows binary is unqualified | KB1 keeps it; a Windows export check before the switch |
| A larger stage loses more on interruption (TADR-010) | Unchanged policy; revisit once stage length is measured |

### Veto list: calls made under the creative charge

1. **New map ids and names.** `park_dam`, `park_flume`, `park_pit`, `park_sinkhole`, `park_islands`, `park_crown`. Stage 2 becomes "Spillway: the flume", so the Cable Reach name retires.
2. **One day across a run.** Dawn at the dam to dusk at the crown. The Highdraft moves from its approved morning light to golden hour and dusk.
3. **Variants become second mountings.** `meltdown` on the flume, `brood` in the sinkhole, `choir` on the spires; stages 1, 3 and 5 fight the plain kind.
4. **One collider path.** Trimesh tiles from the 2 m grid; Terrain3D collision off; HeightMapShape3D only as a measured fallback.
5. **1 m render spacing.** Four regions of 1024 m; the 2 m grid stays the physics truth.
6. **JSON park files.** One per stage, so the bake, the storyboard plot and the game read the same source.
7. **Events land on the downbeat.** The lead rounds up to the next bar, at most one bar longer.
8. **Weather never changes handling.** Wind exists only as marked lanes (thermal rows).
9. **The Warden shrugs a line.** Once per pulse cycle, telegraphed; letting go keeps velocity.
10. **Highdraft islands are mostly mesas.** Only the landmark island floats; the net deck catches falls between mesas.
11. **The sinkhole stage is a cut plateau.** At least 40% of each line under a roof, not a fully roofed cave.
12. **A floor line is required.** No harpoon and no contraption must still reach every Warden within twice the pilot line's time.
13. **Meteor Crater after the Mind.** The ending bowl is a 400 m authored bowl; the same recipe family makes the 40 to 60 m impact craters.
14. **Terrain3D ships with its Windows binary.**
15. **Old maps retire.** Once all six parks pass, the old maps and their tests go.
16. **The difficulty clock's cap on park stages.** Raise `MAX_TIME_TIERS` from 2 to 4 (`director.gd:84`), so tiers 3 and 4 arrive at 135 s and 180 s and a long roam keeps getting harder. KE1 measures pack pressure against the posture bands before it lands.
17. **Real cultures stay references.** The canal and cliff builders are fictional peoples in the game; their rows house no enemies, take no destructive events and carry only `ref_` fragments (section 4). The Spillway lobbers moved from cliff-dwelling ledges to the canyon service ledges for this.
18. **Real place names stay design names.** "Meteor Crater" names the ending bowl in design documents; its in-game name is chosen with its storyboard, so the Bible's rule that references assign no real park names to the fictional map (`BIBLE.md:979`) still holds.

## 12. Stages

The index after the K-CRITIC coherence pass (2026-10-10). Each row is the stage page's own number; the page under `park/stages/` is the source.

| Stage | Landmark (seen from the drop-in) | Warden kind and mounting | Signature flow line | Signature event |
| --- | --- | --- | --- | --- |
| 1 `park_dam` | The spillway dam: 120 m face, 320 m crest, green beam, 1.3 km south of the drop-in | `reactor` on `dam_face`: each pulse opens the gates and a 3 s water sheet is a road up the face to the core | Survey deck, slickrock domes, the shelf lip, the upper slot, the Eye, the incline's 94 m drop, the toe apron | The plunge pool floods to 1.2 m (natural); the pump house boiler bursts (industrial) |
| 2 `park_flume` | The penstock tower, 90 m, on the east bluff, green beam | `reactor` on `flume` (`meltdown`): slag lanes run down the head house channel; the core window lasts 1.5 times longer | Weir deck, the main canal's bends to the butte gap, the lateral canal, the siphon, the wasteway, the forecourt, the drum | A trestle span collapses into a ramp (natural); the heat-exchanger annex blows at the Warden's second chunk (industrial) |
| 3 `park_pit` | The headframe, 120 m on a 100 m deep pit floor, its top 20 m above the plain | `swarm` on `headframe`: the hive rides the hoist on a 12 s cycle, low for contact, high for the line | The dump top's 55 m face, the arroyo half-pipe, the canal lip grind, the rim haul ramp, the benches down to the collar | A drill barge lands and sets up a drill crew home (Fleet); a tailings bench collapses (natural) |
| 4 `park_sinkhole` | The sinkhole, 250 m wide and 120 m deep, with a light column | `swarm` on `sinkhole` (`brood`): a lamp guard; the pool floor rises 5 m per chunk lost | The cinder cone's crater bowl, the breach, the lava channel, the main tube, the great room, the gallery ring | A cave-in opens a new tube (natural); a machine erupts in a tube junction (ancient) |
| 5 `park_islands` | The Hanging Isle: deck at 400 m, tip at 82 m, the one island that floats | `mind` on `under_island`: the island tips 10 degrees on each pulse and throws a latched ball | The Lookout's lip, the Slickrock Run S, the Saddle, the Fin Chute, 80 m of air off the fin nose, the Anvil ramp, the net bowl | A dropship lands and sets up an anchor crew home (Fleet); the cloud deck rises over the net (weather) |
| 6 `park_crown` | The Crown Spire, 330 m, three perch spires, green beam | `mind` on `spires` (`choir`): it flies perch to perch every 8 s and carries a latched ball | Watch Butte's nose, the slickrock S, the Turnstone, the gooseneck, the split spire, the Crown's bowl | Lightning strikes marked spires on the beat (natural); a Mind's hand erupts from a spire's foot (ancient) |

After the Mind, the ending bowl (Meteor Crater, `crater_ending`) is the ending sequence's last set, not a stage (section 6, unit KC10).

## 13. Veto list for Andrew (consolidated)

Calls made under the creative charge, newest first. Each is reversible by one table or text edit.

1. World 1 shows each real culture once: cliff dwellings on stage 1, Hohokam canals on stage 2. Stage 1's canal becomes dam-era headworks; stage 2's cliff rooms become the flume crews' ledge camp.
2. No deflector in world 1 (plan: harpoon-spam answers enter from world 2). Stage 1's deflector home becomes winch drones, stage 2's becomes plated brutes, both from the `elite` pack; KF0 also takes the `rebound` pack out of world 1 (`alpha_defs.gd:42-46`).
3. Event water is at most 1.2 m deep, the depth a ball rolls out of; the plunge-pool flood drops from 3.0 m.
4. Landmarks take the storyboards' sizes: the headframe 120 m in a 100 m pit, the Hanging Isle's deck at 400 m, the Crown Spire 330 m.
5. A signature landform stays on its stage: the horseshoe bend is stage 2's alone; stage 1 gets a river canyon, stage 6 a gooseneck, and stage 5's tram station is no longer a headframe.
6. ~~Meteor Crater is a camera set at the end of the ending sequence, with the credits over the bowl, not a playable lap.~~ Vetoed 2026-10-17 (design answer Q16): a 60 s free roll in the bowl, then the credits over it (`src/world/victory_lap.gd`).
7. The swarm's rising pool floor never lifts a grounded ball; the step waits for the pulse's pop.
8. Tiers 3 and 4 (item 16) gate three events: stage 1's dome lightning, stage 3's adit wake, stage 4's cenote drain. Without item 16 they never fire.
9. Draws: the probe read 2.06 times; KB5 merges scatter to reach 1.3 times, and a pass on GPU and frame with draws still over comes to you.
10. Under the island, the Mind's shrug waits for the swing to end (1.2 s), so the drag throws you (`wardens/mind.md` section 10).
11. One day across a run, dawn to dusk: the Highdraft gives up its approved morning light (item 2).
12. The six parks ship behind `--table=park` and replace the old maps only when all six pass (items 15 and KD7).
