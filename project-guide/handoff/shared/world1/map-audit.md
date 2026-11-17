# World 1 map audit against the ten map points (architect, read-only, 10 Nov 2026)

Read at 75099fa70 (`~/scratch/gate/w34/stage`). Evidence level 2 (file and line reads; nothing run). Verdict PASS+NOTES.

## Headline
World 1 already meets the "see it" points: dam and flume landmarks must be visible from 85% of open cells and a test enforces it (`tests/park_park_dam_test.gd:48,170`). The dam has three height tiers (y 0, 100, 150) and many momentum translators. Three gaps:
1. No cover against hostile fire. Ground stops the player's shots (`src/combat/hitscan.gd:29-33`, `bolts.gd:139-142`) but a lobber shell checks range only (`src/combat/lobber.gd:15,143,198`; `projectile.gd:11-16`).
2. No breathing spaces in fights. Packs spawn 60-90 m ahead on a timer, kept only off pilot corridors (`src/world/director.gd:116-120,342-363,963-970`).
3. Little per-run layout variety. Per run: stage modifier (5 rows, 40%), pockets from a 24-file library, rogue site (1 of 2), pack spots, camp pay, Dispatcher perch. Fixed: terrain, landmark, routes, contraptions, homes, events, lock waves.

## Area gaps (only the GAP and UNKNOWN cells)
- Dam approach: breathing space GAP; cover GAP; hulls PARTLY (anchors convex bands, landforms trimesh, `park_recipes.gd:1574,995`, `terrain.gd:1027`); scrap on floor line only (ruling cd, DECISIONS.md:288).
- Dam Warden yard: beam reads as a wall up close (PF-28); attack outline looks like the yard walls, no safe ground readable (PF-16); lock waves fixed; half-bowl only, lock ring lands wherever the ball crosses 200 m (`lock_rows.gd:11-14`).
- Flume: cover GAP; no recorded collision sweep result (UNKNOWN); only 3 cache spots.
- Slag Bowl: true bowl (`src/boss/arena.gd:9-19`); hull sweep `--area=arena` has no recorded result (UNKNOWN).
- Camp: flat ring (low stakes).
- Not checked: title screen, flume head-house drum shape, whether chasers path around terrain.

## Units, ranked (1-3 move no difficulty band)
| # | Unit | Points | Files | Size | Could move | Proof | When |
|---|---|---|---|---|---|---|---|
| 1 | Beam fades up close with a soft edge (PF-28) | 1, 10 | `src/presentation/landmark_beam.gd` | S | pixels | PC still at 50 m and at drop-in; sight test unchanged | 36 |
| 2 | Yard wall drawn unlike any telegraph, safe side shown (PF-16) | 5, 8 | `src/world/stage_locks.gd` (wall look only) | S | pixels | first-timer reader pass, PC stills | 36 |
| 3 | Snag sweep on flume and arena, backward-roll probe on anchor bands | 8 | `tools/qa/collision_sweep.gd`, `invisible_walls.gd`; fixes in `park_recipes.gd` | S to M | nothing unless fixes | sweep receipts at 0; `invisible_walls_test` extended | 36 |
| 4 | Small POI markers for caches, cage, rogue sites | 1, 10 | new module beside `landmark_beam.gd` | M | pixels, frame cost | PC film; must not read as pickup or enemy (DECISIONS.md:278) | 38 |
| 5 | Scrap on the skill lines | 10, 7 | `assets/park/<map>/lines.json` | S | scrap income, bands | 24-seed band read | map wave |
| 6 | Hard cover: landform stops a shell | 5, 7 | `lobber.gd`, `projectile.gd` | M | bands (eases Novice, at its cap) | 24 then 96 seeds | after 36; Andrew's taste call |
| 7 | Breather zones: tagged area where the director places no pack | 2, 3, 9 | `director.gd` spawn check, park JSON tag | M | bands, timing | 24 then 96 seeds | after 37 |
| 8 | Authored concave yard with a berm rim | 8, 5, 9 | `lock_rows.gd` site field, mojulo blockout | L | timing, bands | seeds, sweep, PC film | post-sitting |
| 9 | Reactive works lever (valve drains a lobber ledge) | 6 | `contraptions.gd`, a homes row | M | bands | seeds | post-sitting |
| 10 | Two-variant sub-regions via a modifier row | 4 | `stage_modifier.gd`, event rows | M | timing, bands | 96 seeds | post-sitting |

Do not, before the sitting: procedural terrain or stage variants (breaks tested sight lines; "World 1 first" is ruled, DECISIONS.md:33); rebuild every hull as a capsule (sweep first).

## Ruling draft (map standard)
Every park answers ten checks in four groups, momentum kept sacred.
- See it. One hero landmark on the skyline from at least 85% of open cells, ground falling toward it. Smaller signs (smoke, thin light) mark caches and objectives, never a HUD arrow. Up close a sign reads as light, not a wall. Machines stand against clean sky.
- Read it. Fight floors sit lower than their rims. Hostile marks never share a look with walls or dressing, and safe ground is always shown. Landform mass is hard cover; dressing is soft cover and never hides a telegraph. Every big piece's collider matches what is drawn, and a backward roll slides off it.
- Flow through it. At least three height tiers joined at a hub by ramps, launchers, thermals, lifts and cables. Vault, slingshot, grapple and slam turn speed into height. High ground is safe from melee, open to shells and flyers. Heavy fights cluster at the foreman's machines; open benches and carries stay free of spawns. Every route rideable without stopping.
- Get rewarded for moving. Scrap and pay lie on the skill lines; off-spine dead ends pay more. Layouts are hand-built sub-regions whose pockets, sites, modifiers and live routes are drawn per run, repeatable per seed, never random terrain. Each park has machinery the player's choices change.
Changes that move enemy placement, timing or RNG need band reads. Pixel and dressing changes need PC stills or a film.

## G. How to check each map point (architect addendum, level 2, run times are inference)

Data the checks read, all public today unless noted: stage graph `src/world/park/park_graph.gd` (`flags()`, `position()`, `zones()`, `crossings()`, `path_m()`, `disc_nodes()`, `d_landmark()`, `:259-299,401-412,588`; node flags OPEN, LINE, SIGHT_OK, DECK, UNDER `:70-80`; ride edges `ride`/`roff`/`rto` `:91-94`); park map `src/world/park/park_map.gd` (`landmark`, `contraptions`, `park`, scrap trail, `:34-50,93-95,144`); `lock_rows.row(map_id)` (`src/world/lock_rows.gd:32`); Slag Bowl constants and `surface_height()` (`src/boss/arena.gd:15-19,140-145`); per-run draws `pocket_draw.stage_sites()` (`:301`), `stage_modifier.ROWS` (`:34-40`), `rogue_director.read_sites()` (`:22`). Not public: fight sites (homes are read only inside `director.gd:616`); breathing and rhythm need one new `ParkMap.fight_sites()`.

| Point | Kind | Measure and pass line | Lives in | Planted failing case |
|---|---|---|---|---|
| 1 Signposts | CODE gate | open-cell sight share (exists) and LINE-node SIGHT_OK share, each >= 0.85 | extend `tests/park_landmark_sight_test.gd` (2.9 s) | exists (300 m wall, `:15,148-159`); add: clear SIGHT_OK on line nodes |
| 1 picture | PICTURE | 8 fixed chase-camera poses on the lines, beam at 50 m, 150 m, drop-in; "point at the landmark", "light or wall?" | new `tools/map_sheet_capture.gd`, one sheet a stage | control still with the beam hidden |
| 2 Breathing | CODE | share of LINE nodes > 60 m from every home, event footprint, yard ring: >= 0.25 (start value) | `tests/park_breath_test.gd`, needs `fight_sites()` | a home on every line segment gives 0. Blind to timer packs; breather zones (`src/world/breather_rows.gd`, checked in `tests/director_breather_test.gd`) hold those |
| 3 Rhythm | CODE | fight/quiet strip along the floor line at 20 m/s: >= 3 switches, longest heavy run <= 45 s | `tests/park_rhythm_test.gd` | all homes in the last 300 m gives 1 switch |
| 4 Hybrid | CODE | 50 seeds a stage: >= 10 distinct (pockets, rogue site, modifier) sets | `tests/park_variety_test.gd`, data only (wave 44) | no modifier, one rogue site and one fixed pocket draw give 1 set |
| 5 Cover and reading | PICTURE gate | danger marks with the ball inside and outside; blind read "where is safe" | exists: `tools/danger_read_capture.gd`, `scripts/redteam/` | control still with the yard wall in HAZARD stripes |
| 5 code | CODE, with unit 6 | rows tagged hard have a ball-layer collider >= 2 m tall; soft rows have none. No row carries a tag, so the test calls a placed row with a collider 2 m or taller hard and the ground scatter soft, and checks the shell cover dial is on, every hard row is on the layer a shell's cover ray hits, and no scatter body is | `tests/park_cover_tags_test.gd` (wave 44) | a hard row taken off the cover layer; a scatter body put on it |
| 6 Interactive | CODE | >= 2 player-caused route changes within 150 m path of a line | `tests/park_feature_census_test.gd` | strip the valve and bulkhead rows |
| 7 Verticality | CODE | >= 3 height bands each holding >= 5% of open nodes; >= 4 ride edges climbing >= 10 m; every band reachable | same census test | flatten a copy of the heights |
| 8a Bowls | CODE gate | ground at ring radius minus ground at centre >= 2 m per fight site | `tests/park_fight_bowl_test.gd` | Slag Bowl with BANK_H 0. The dam yard likely fails today (inference) |
| 8b Silhouettes | PICTURE | terrain flat in sky colour, enemies black; "count the machines" | `map_sheet_capture` silhouette mode | one machine hidden must be counted one short |
| 8c Snags | CODE | backward roll at cruise along every large piece; snag = half the speed lost in 0.2 s against a contact under 45 degrees into travel; 0 per area | `tools/qa/snag_sweep.gd` + `tests/snag_sweep_test.gd` | a 0.3 m lip box must give >= 1 snag |
| 9 Tier and spoke | CODE | hub zone whose crossings reach >= 3 height bands; >= half of cache and pocket pay points in the top two bands | census test | remove the Eye's crossings |
| 10a Markers | CODE | sight share per marker top | extend the sight test | delete one marker |
| 10b Rewards on lines | CODE | share of scrap within 8 m of a ride edge or a 4 m+ drop >= 0.3 (today about 0) | `tests/park_scrap_lines_test.gd` | all scrap on flat ground |

### First measurements (branch claude/w35-mapchecks at ffb98b10, level 4: run three times, identical, planted cases fire)

| Stage | Measure | Value | Pass line | Result |
|---|---|---|---|---|
| dam | open ground that sees the landmark | 0.88 | 0.85 | pass |
| dam | riding-line nodes that see the landmark | 1.00 | 0.85 | pass |
| flume | open ground that sees the landmark | 0.87 | 0.85 | pass |
| flume | riding-line nodes that see the landmark | 1.00 | 0.85 | pass |
| dam yard | rim minus centre, worst site median | 2.35 m (14 Nov, the kicker moved past the ring; 3.25 m with it inside; 0.72 after PF-46, 2.97 before it) | 2.0 m | pass: a bowl 116 m across the incline foot (clear of both lane fins), 48 m along the ride and 5 m deep, centred on (0, 432), where the yard shuts since PF-46. The test reads the line nodes near x 0; a probe of lock centres at z 430 every 6 m from x -54 to 54 (every lane down the incline) reads at least 2.1 m. The apron kicker (3 m ramp, not 5 m) stands just past the shut yard's ring, centred on (0, 476) instead of (0, 448), so the yard's floor is open ground, and while the yard is shut the play camera reaches out 12 m and lifts to the steepest pitch it allows (chase_camera.gd "locked" row); the flat flume yard gets the same lift, a wider look at its crew (both assumptions Andrew can overturn, 14 Nov). The dark band PC stills showed at the west lane fin's foot is the terrain's coarse far rings drawn round the chase camera while a free still camera looks elsewhere; tools/dam_look_capture.gd hands the rings to its camera, and from the yard in play the foot reads clean |
| flume yard | rim minus centre, worst site median | -0.41 m | 2.0 m | OWED: the fight floor is flat |
| Slag Bowl | rim minus centre | 10.0 m | 2.0 m | pass |
| dam | player-changed features near a line | 5 | 2 | pass |
| dam | height bands in use | 3 (5.3% / 60.5% / 34.2%) | 3 | marginal: low band 5.3% against 5% |
| dam | rides climbing 10 m or more | 4 | 4 | pass, no margin |
| dam | hub zones reaching 3 bands | 1 | 1 | weak: it is the open ground zone, not a built hub |
| flume | player-changed features near a line | 8 | 2 | pass |
| flume | height bands in use | 3 (48.8% / 38.8% / 12.4%) | 3 | pass |
| flume | rides climbing 10 m or more | 4 | 4 | pass since 17 Nov, no margin (was 3, OWED). The fourth is the gap table (`gap_table_kicker` onto `gap_table`, graph climb 13.7 m, PR 1119): a sheer 14 m table centred at (-301,-328), north-west of the butte gap and east of the mesa rim road (north is -z here, as `canyon_wall_north` at z -800). Its one way up is the 14 m kicker on its north face, lip on the face line; it drops off its south lip toward the gap. A real ball rides it (`tests/park_gap_table_climb_test.gd`, Mac, 17 Nov): holding forward it tops out from rest; not holding forward it needs 27 m/s at the foot and rolls back from 22 m/s, so it is a climb but no speed gate. The other three are the drum lip kicker (30 m), the flume entry kicker (21 m) and one bend zip pier (16 m) |
| flume | hub zones reaching 3 bands | 5 | 1 | pass |
| dam | riding-line nodes 60 m clear of every fight site (point 2) | 0.57 | 0.25 | pass (0.43 before 12 Nov; see the note under this table) |
| flume | riding-line nodes 60 m clear of every fight site (point 2) | 0.255 | 0.25 | pass, no margin: the head gate sluice is the surge run's harmless water front, not a fight (12 Nov). The flume reach and the wasteway chute still lie along the lines. The flume has no breather row since W1-31 (`src/world/breather_rows.gd`): the director's own packs stay off the riding lines by its corridor rule alone (`src/world/director.gd` `_park_safe`, no spot within `PARK_CORRIDOR_M`, 8 m, of a pilot line). Assumption Andrew can overturn: that corridor rule, without a landing breather, keeps the flume's lines clear enough of the director's packs |
| dam | floor line heavy/quiet switches at 20 m/s, quiet gaps under 5 s between fights folded (point 3) | 3 | 3 | pass since 12 Nov, no margin (was 2, OWED; see the note under this table). The drop-in is quiet for 7 s, then the domes camp, the dome lightning and the west wash run 42 s heavy |
| dam | longest heavy run on the floor line (point 3) | 41.8 s | 45 s | pass since 12 Nov (was 46.2 s, OWED) |
| flume | floor line switches; longest heavy run (point 3) | 9; 15.0 s | 3; 45 s | pass |

**12 Nov 2026 re-read (branch `claude/w38-fight-sites`, `park_breath_test` and `park_rhythm_test`, one run each; the tests read files only, so a run replays exactly).** `fight_sites()` had two errors that cancelled out on the dam. It counted a lightning row's whole landform (the dam's 260 x 240 m slickrock domes) as a fight, but the game strikes one `strike_m` disc at the site's centre (`natural.gd` plan and `_hazard`). And it left out the activities that fight (an enemy camp, an ambush altar, a relay), such as the three-chaser `domes_camp` that sits on the dam's floor line. Both are fixed. The dam's rhythm now passes with no margin (3 switches, longest heavy run 41.8 s) and its OWED entries are pruned. The flume's breathing read 0.18 because the head gate sluice counted as a fight; it is the surge run's water front, which commits no hazard and never hurts (`events/industrial.gd` handle), so `fight_sites()` now skips it (`ParkMap.NOT_FIGHTS`) and the flume passes at 0.255, no margin. Both world 1 maps now meet points 2 and 3 with nothing owed.

Points 2 and 3 read `ParkMap.fight_sites()` (homes, event sites, the Warden ring, the yard lock ring) in `tests/park_breath_test.gd` and `tests/park_rhythm_test.gd` (wave 37, run twice, identical, planted cases fire). Neither sees the director's timer packs.

**17 Nov 2026 (wave 44, branch `w44/map-standard-checks`).** Points 4 and 5 now have code checks (`tests/park_variety_test.gd`, `tests/park_cover_tags_test.gd`; rows 4 and 5 code in the table above). First readings: 50 run seeds draw 47 (dam) and 45 (flume) distinct sets against 10 (game layout seed 20260926), with 2 rogue sites and 4 modifiers drawn on each (5 counted a run that drew no modifier as one; the test counts only real ids since 17 Nov, branch `w44/flume-climb-sites`); pockets count apart by exact graph node. Both parks have the shell cover dial on, every row with a collider 2 m or taller (dam 6, flume 97) on the shell's cover layer, and no scatter body on it; that point 5 check passes by construction (every row body is on layer 1, the cover mask is 1), so the receipt keeps point 5's tagged cover open. Live routes are not drawn per run on any map. The done read's `map-standard` row reads every MAPCHECK line of the dam and the flume through `scripts/gate/map-standard-receipt.mjs`, which lists the items ruled to wait. Still without a check: the point 1 and 8b pictures (`tools/map_sheet_capture.gd` does not exist), and 8c prints no MAPCHECK line (`tests/snag_sweep_test.gd` holds only the planted control).

The audit guessed the dam yard would fail the bowl check; measured, it is the flume yard that fails. Follow-up: add the three tests to the "park data" PATH_RULES in scripts/sketch-fast.mjs so a park JSON change selects them. The OWED-entry-now-passes rule was read, not run.

Best value for build time: (1) line-weighted landmark sight, (2) bowl depth at fight sites, (3) the feature and translator census covering points 6, 7 and 9.
Review aids until a planted case exists: silhouettes, cover overlay, and the rhythm and breathing start values before calibration.

Acceptance lines for map units: beam near-fade (sight test still >= 0.85 plus a beam sheet read as "light"); yard wall look (`danger_read_capture` yard still plus a reader pass, HAZARD control still flagged); snag sweep (0 on flume and arena, planted lip fires, `collision_sweep` invisible 0); POI markers (each marker's sight share passes plus a blind "not a pickup" read); scrap, breathers, cover, yard bowl (their tests plus 24/96-seed band reads).
