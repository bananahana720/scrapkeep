# Hero landmark build cards

> **Historical / Partially superseded build spec (16 Oct 2026):** Landmarks and P1–P6/P8 port items are built in `assets/models/park/landmarks/` and `park_*.json`; only `hero_landmark` draw-range widening (P7, currently `300/900 m` in `assets/asset_budgets.json`) remains unbuilt.

One card per hero landmark: `landmark_dam`, `landmark_penstock_tower`, `landmark_headframe`, `landmark_sinkhole`, `landmark_sky_island` and `landmark_spire` (PARK.md section 4, the `hero_landmark` budget class). Each card gives the silhouette and parts, the Warden mounting points, the LOD budgets, the materials, the existing models and Blender recipes to reuse, how the stage's park rows fit with PARK-SEAT and PARK-TILE, and the test that would pin the result.

Written 2026-10-16 from `main` at 77b99de, by reading the sources named in each line. Blender and Godot were not run, so nothing here is measured in the engine. Triangle counts of existing GLBs come from their glTF accessors (index count / 3), read with a script.

## 0. Read first: seven facts that shape every card

1. **The landmark object is never placed.** `Placer.start` places `placed_rows(park)`, which reads only `park_rows` (`src/world/park/park_recipes.gd:722-723`, `:1012`). No other caller passes `park["landmark"]` to `place()`. A finished `landmark_<kind>.glb` would load nowhere. The stage 1 page says the landmark "stands in as greybox" (`park/stages/1-park_dam.md`, section 15); it does not, because the landmark has no `element` and `place_greybox` returns null for an empty element (`park_recipes.gd:532-534`). Port note P1.
2. **The green beam is not drawn.** `landmark.light` is validated (`park_schema.gd:30`) and `terrain.landmark_point()` exists (`src/world/terrain.gd:424`), but no code reads either one. Five stages rely on the beam for their sight read (all but the pit). Each card puts a `beam_root` empty in the GLB; the beam itself should be one shared runtime node, so it looks the same on all five stages and at every LOD. Port note P2.
3. **The drop-in vista sees the far mesh.** The ranges the code reads are in `assets/asset_budgets.json` `hero_landmark`: base to 300 m, mid to 900 m, far beyond (`park_recipes.gd:155-160`). PARK.md:312 says full to 600 m and mid to 1.4 km. Every stage's drop-in is 1.17 to 1.43 km from `sight_top` (computed from each park file's `spawn.at` and `landmark.sight_top`). With the JSON ranges, the hero shot is the 1,500-triangle far mesh. The cards budget to the JSON and design the far mesh as the hero silhouette. Port note P7 records the mismatch.
4. **Play surfaces stay park rows.** Each fight floor is a park row that the traversal bands and win proofs measured: the dam's face quarter pipe and toe apron, the head house drum, the collar dish and tipple deck, the gallery ring and caisson, the net bowl and knuckle buttes, and the crown bowl and perches. A landmark recipe dresses the space around them. Where its `-col` would add a solid that a ball or a harpoon can reach, the card says so and names the stage's lines and posture bands as re-measure work.
5. **Structure hardpoints are designed but not wired.** `wardens/reactor.md` puts two hardpoints on the gate piers (dam) and the channel cheeks (flume). `wardens/swarm.md` puts two on the gallery ring posts (sinkhole). The code uses three body offsets (`src/combat/warden.gd:103`) unless the spec gives `hardpoint_offsets` (`warden.gd:555-563`), and no park file gives them. Cards with static Wardens put `hp_0` to `hp_2` empties in the GLB at the sheets' positions. Copying them into `landmark.warden.hardpoint_offsets` is port note P4. That copy changes the fight, so the posture bands must be re-measured.
6. **Landmarks are centred, placed at ground unless given `y`.** A landmark has no registry `origin`, so its GLB origin is the footprint centre (`park_recipes.gd:163-181`). `row_transform` puts that origin at `ground(at)` unless the row has `y` (`park_recipes.gd:195-204`). Under four of the six landmarks, `ground(at)` is a stamped dish, hole or slope. Each card names a `y` datum. The schema checks only required landmark keys (`park_schema.gd:517-536`), so adding `y` needs no schema change. Port note P3.
7. **Landmarks place unfitted.** `"fit": "seat"` and `"fit": "tile"` are park-row fields for long rides (`park_recipes.gd:16-32`). A landmark is one authored piece at its footprint. The fit tools apply to the companion rows each card lists.

## 1. Shared contract

| Item | Rule | Source |
| --- | --- | --- |
| Files | `assets/models/park/landmark_<kind>.glb`, `_detail1.glb`, `_detail2.glb`, `_mid.glb`, `_far.glb` | `park_recipes.gd:184-191`; `tests/park_recipes_test.gd:224-227` |
| Recipe script | One family script, `tools/blender/park/landmarks.py`, with `--only <id>`, `--out-dir`, `--count-only`, as the other park families do | PARK.md section 4; `tools/blender/park/tunnels.py` header |
| Helpers to reuse | `tools/blender/park/contraptions/_park.py` (`frustum`, `tube`, `strut`, `disc_z`, `ring_y`, `bar_xy`, `hexstud`, the dam-era palette with concrete, iron and copper `#b77843`); `tools/blender/common.py` (`material`, `empty`, `export`, `tri_total`, `report`, `render_turntable`) | read 2026-10-16 |
| Axes | +Y up, metres. Local +Z is the side that faces the arriving player; the row's `yaw_deg` turns it. Origin is the footprint centre at the card's `y` datum. | `park_map.gd:110-112` (size is [length, height, width]) |
| Base | at most 24,000 triangles and 6 draws | `asset_budgets.json` `hero_landmark` |
| Mid | at most 6,000 triangles, from 300 m (margin 30) to 900 m | same |
| Far | at most 1,500 triangles, from 900 m (margin 60), never ends | same; `park_recipes_test.gd:215-222` |
| Detail shells | at most 1,500 triangles and 1 draw each, shown to 200 m and 80 m | `detail` class; `hero_landmark.ranges.shells` |
| Collision | One `<id>-col-col` mesh in Blender, imported as `<id>-col` and never drawn. It holds only the parts a card marks "collides". | `park/caverns.py` header; `park_recipes.gd:44-46` |
| Empties | `sight_top`, `beam_root` (beam stages), `warden_anchor`, `hp_0` to `hp_2` (static mountings only), plus each card's named extras | this file |
| Clear volume | No landmark geometry within 8 m of `warden_anchor` except the card's cradle, so the Warden body (radius 2.8 m, `warden.gd:65`) and its kit read clean | this file |
| Materials | Name surfaces by the runtime slots: `dam`, `concrete`, `steel`, `stone`, `enamel` (vertex colour), `elastomer`, `glass`, `cable`, `ancient_lens` (the green rims) | `src/presentation/material_slots.gd:19-51` |
| Palette | Southwest and dam-era colours only. Copper `#b77843` for machinery, never brass. Ancient light is uranium-glass green `#9dff3c`. | PARK.md 2.3; family headers |
| Culture | No landmark is a canal-builder or cliff-builder work. All six are dam-era, mining, natural, ancient or Fleet, so none needs the `ref_` guardrail. | PARK.md section 4 |
| Registry | One `registry.d` fragment for the 30 GLBs, class `hero_landmark` for the base and `detail` for the shells, no `origin` key (so it stays centred) | `park_recipes.gd:69-71`, `:163-171` |

**Shared test.** One new `tests/park_landmarks_test.gd`, red before the GLBs land (the `place()` fallback warns and returns null), with these checks for each landmark. The cards add their own checks below.

- (a) Budget: `npm run asset:inspect -- <glb> --max-tris hero_landmark` passes for the base; the mid is at most 6,000 triangles and the far at most 1,500; each shell is at most 1,500.
- (b) Data agrees with the model: after `row_transform`, the `sight_top` empty is within 1 m of `landmark.sight_top` and `warden_anchor` is within 1 m of `landmark.warden.anchor`.
- (c) Collision fence: no `-col` triangle lies inside a route-bearing park row's footprint, or inside the engage disc (`beacon`, `reach_m`) more than 0.5 m above the fight floor, except the parts the card marks "collides, re-measure".
- (d) Placement: with P1 applied, `build_placed` on the stage yields a node named for `landmark.id` with near, mid and far views. This is the real-file version of the fake-GLB hero check at `park_recipes_test.gd:204-222`.
- (e) No drift: all six stages' park-row placement hashes stay byte-identical, as PARK-SEAT and PARK-TILE proved for their changes (`docs/decisions.tsv` rows PARK-SEAT and PARK-TILE).
- Look: blind pairs at close, mid and far through `tools/look_subjects.gd`, as KC1 to KC8 did (PARK.md, KC acceptance).

---

## Card 1. `landmark_dam`: the spillway dam (`park_dam`, stage 1)

**Row today:** `at` [0, 620], `size` [120, 120, 320], `yaw_deg` 180, so local +Z faces world -Z, toward the park. **`y` datum: 0**, the toe apron (the relic is "22 m above the toe apron" at world y 22). Sources: `src/world/park/park_dam.json` `landmark`; stage page section 3.

**Silhouette.** A curved concrete arch 320 m along the crest, with the crest at world y 121, above the plateau's y 100. Two gate towers rise from the crest's middle to y 141, joined by a gantry. The beam rises from the relic past the crest. From 1.3 km it reads as a pale bar across the canyon, two notches and a green line.

| Part | Size and place (local) | Job | Collides |
| --- | --- | --- | --- |
| Arch wall | 320 m chord across x, bowed 25 m toward -Z (upstream), from y 30 to the crest at 121; buttress cheeks to x ±160 | The skyline bar | Yes. It is out of reach from play except at the crest. |
| Face cladding | From the top of the `dam_face_quarter` stamp (30 m) down to it, flush within 0.12 m | Covers the stamp's join; the stamp stays the ridden face | No. The stamp is the surface. |
| Crest deck and parapet | 8 m deck at y 121, parapet 1.2 m | Holds `crest_rail` visually | Deck yes, parapet yes |
| Gate towers | 12 × 12 m, at x ±18, rising from the crest to 141 | The two notches | Yes |
| Gantry | Beam between tower tops at y 141; the `sight_top` empty sits on its centre at (0, 141, -20) | Gives `sight_top` a solid point | Yes |
| Spillway gates | Two radial gate leaves, 12 m wide each, over the relic; separate meshes `gate_l` and `gate_r` with hinge empties `gate_l_hinge` and `gate_r_hinge` | Open on each pulse (`gates_open`, `wardens/reactor.md:100`) | No. The sheet is the warden driver's. |
| Relic cradle | Recessed concrete seat around `warden_anchor` (0, 22, 30), back plate only | Frames the relic | No |

**Warden mounting points.** `warden_anchor` (0, 22, 30). Hardpoints for P4: `hp_0` is the relic crown (body offset (0, 1.6, 0), as today). `hp_1` and `hp_2` are the gate-pier noses at the relic's height, ±10 m across the face, offsets (±10, 0, 0). From the beacon at (0, 0, 45) local they are about 28 m away, inside the 45 m rope. The towers' inner faces stand at least 24 m apart, so the 24 m sheet fits between them (`warden_reactor.gd:32`). `beam_root` sits at the anchor.

**LOD.** The base adds cast courses, service frames and form-board joints. The mid keeps a 24-segment arch slab, the crest, the towers, the gantry and closed gates, within 6,000 triangles. The far keeps a 12-segment arch, the crest line and the two tower boxes, within 1,500. Because of fact 3, the far mesh is the drop-in hero: spend its triangles on the crest line and the tower notches, not on the face.

**Materials.** `dam` (the `target_dam.gdshader` slot, which keeps imported maps and vertex colours) for the wall; `steel` for the gates and gantry; copper trim; `ancient_lens` rims on the hardpoint noses.

**Reuse.**
- `tools/blender/world_one/dam.py` and `assets/models/world_one/dam.glb` (2,340 triangles, 3 draws): the I01 facade of cast courses and repaired service frames, built for the old flat 270 × 100 m wall. Bend it along the arc for `_detail1`.
- The `dam` material slot and `target_dam.gdshader`.
- The concrete palette and form-board joints of `spillway_tunnel` (`tools/blender/park/tunnels.py`).
- The strut and tube helpers in `_park.py` for the gate arms.
- The relic body is `warden_reactor.glb` plus `warden_kit_reactor.glb`, drawn by `warden_look.gd`. It is not part of this recipe.

**Fit with PARK-TILE and PARK-SEAT.** `crest_rail` (300 m `rail`) tiles `pipeline_rail` (5,656 triangles; family pieces have matching ends, per the `park/grind.py` header). Three copies at 0.83 stretch is inside 0.75 to 1.5; confirm with `tools/seat_probe.gd` `fit=tile`. `gate_piers` stays an `anchor_field`. `east_abutment` and `powerhouse` sit outside the 320 × 120 m footprint. The stage page assigns them to "the landmark asset unit" (section 15), but they need their own small recipes; this card leaves them out.

**Test that pins it.** The shared checks, plus:
- The gap between the towers' inner faces is at least `SHEET_WIDTH` (24 m).
- Both hinge empties exist and the gate meshes are separate nodes.
- No `-col` lies below y 30 inside x ±160, so the face stays the stamp's.
- Re-run `tests/posture_bands_test.gd` for stage 1 and the six stage 1 lines. The wall is out of reach, so this re-run should show no change; it confirms that.

**Open.** P6: who swings the gates. `warden_reactor.gd` owns the sheet; the gate swing needs one line that reads the hinge empties.

---

## Card 2. `landmark_penstock_tower`: the penstock tower and head house (`park_flume`, stage 2)

**Row today:** `at` [270, 510], `size` [140, 90, 120], `yaw_deg` 31. **`y` datum: 0**, the bluff grade (the tower is 90 m tall and its top is at y 90). In local coordinates, the tower is on +Z and the head house on -Z: `sight_top` (0, 90, 58.3), `warden_anchor` (-13.7, -2, -54.9), beacon (-18.8, 0, -46.3). Sources: `park_flume.json` `landmark`; stage page section 3.

**Silhouette.** A 90 m round concrete surge tower with a flared bell top beside a low round head house, 70 m across, under open steel trusses. The flume's last reach runs into the drum's north wall, and three penstocks drop over the bluff edge to the east.

| Part | Size and place | Job | Collides |
| --- | --- | --- | --- |
| Surge tower | Ø 18 m tapering to 14 m, 90 m tall, at about (0, 0, 58); a bell flare and a steel gallery ring at 84 m | The skyline mark | Yes. It is outside the engage disc. |
| Drum liner | A concrete skin on the inner wall of the `head_house_drum` terrace stamp (floor y -14), flush within 0.12 m | Makes the cut read as a building | No. The stamp is the wall. |
| Drum parapet | 4 m above grade on the drum rim, with gaps where the forecourt (NW), annex (SW) and gate doors (E) cross the rim; gaps sized to every route row that crosses it | The building outline | Yes, but the gaps follow the route rows |
| Roof trusses | Open steel trusses spanning the drum at y 18 (32 m above the floor) | Roof read | No. The `head_house_trusses` anchor-field posts stay the harpoon truth. |
| Flume inlet | The last flume reach entering the north wall 12 m above the floor, spilling to `pour_channel` | Shows where the slag comes from | No (`pour_channel` is a row) |
| Penstock heads | Three Ø 4 m valve collars on the east wall | Starts the penstocks the rows carry | No |

**Warden mounting points.** `warden_anchor` is at world [230, -2, 470], the mouth of the pour channel. Hardpoints for P4: `hp_0` is the relic crown. `hp_1` and `hp_2` are the channel's two cheeks, 5 m either side of the channel axis and 4 m above its deck. The channel runs from [200, 446] to the anchor, so the world-axis offsets are (-3.1, 4, 3.9) and (3.1, 4, -3.9). Keep 8 m clear of geometry around the anchor; the slag lanes leave from `POUR_OFFSET` (`warden_reactor.gd:51`). `beam_root` sits on the tower top, at `sight_top`.

**LOD.** The base adds formwork joints, rivet rows on the trusses and penstock collars. The mid keeps the tower, the parapet ring, a simplified truss lattice and the inlet. The far keeps the tower (a 12-sided frustum and bell) and the drum ring.

**Materials.** `concrete` for the tower and drum; `steel` for the trusses and gallery ring; copper `#b77843` for the valve collars; `ancient_lens` rims on the cheeks.

**Reuse.**
- `tools/blender/park/grind.py`: `flume_span` (3,644 triangles) for the inlet reach and `penstock_run` (2,928) for the collars' pipe profile.
- `tools/blender/park/contraptions/_park.py` `frustum`, `ring_y` and `disc_z` for the tower, bell and gallery.
- The truss lattice follows the `strut` helper (as `dig_mechanical/strut_tall.glb`, 132 triangles, does).

**Fit with PARK-TILE and PARK-SEAT.** The bluff penstock rides (`bluff_ride_pier_*` and the penstock rows) tile `penstock_run`. The family ends match by design (`park/grind.py`: "a row longer than one piece tiles them end to end"). Seat any row under 1.5 piece lengths and tile anything longer (PARK-TILE notes, `docs/decisions.tsv`). `heat_exchanger_annex` is the `reactor_blow` event's swap target, so it stays a row with its own dressing. It is not part of this card.

**Test that pins it.** The shared checks, plus:
- Every parapet gap contains the centre line of each route row that crosses the drum rim, so the drum's routes stay open.
- The truss mesh has no `-col`.
- Re-run the round 9 qualification set the stage page lists (its "Current measurements" section) to confirm the parapet changes no line.

---

## Card 3. `landmark_headframe`: the headframe (`park_pit`, stage 3)

**Row today:** `at` [0, 255], `size` [40, 120, 30], `yaw_deg` 180. **`y` datum: -100**, the pit floor. `ground(at)` is the bottom of the 10 m `collar_dish`, so leaving `y` unset would sink the frame. Locally, `sight_top` is (0, 120, 0) and the hive path runs from (0, 4, 0) to (0, 34, 0) (world y -96 and -66). Sources: `park_pit.json`; stage page section 2.

**Silhouette.** A black steel A-frame 120 m tall over the main shaft. Two 14 m sheave wheels sit at the top, a tipple deck is 40 m up, and back legs rake toward the hoist house. No beam: at noon the silhouette carries the read. Its top is 20 m above the plain, so it shows over the rim from the plateau.

| Part | Size and place | Job | Collides |
| --- | --- | --- | --- |
| Front legs | Two lattice legs from the collar corners (x ±12, z ±10) to the apex at y 114 | The A | Yes. They stand inside the 42 m engage ring: re-measure. |
| Back legs | Two raking legs toward the hoist house (local +X, about 75 m away at (75, 0, 40)), meeting the front legs at the sheave deck | The rake | Yes, re-measure |
| Sheave deck and wheels | Deck at y 110; two 14 m wheels at y 114 to 121 on the axis, `sight_top` on the wheel tops | The crown | Deck yes; wheels no |
| Shaft collar | A steel collar ring, 12 m square, at the floor | Frames the shaft | No (the dish is the row) |
| Hive well | A clear square 12 m wide from y 0 to 38 on the axis | The hive's path; nothing may enter it | n/a |
| Ropes | Two drawn ropes from the sheaves to the hoist house | Read of the hoist | No |

**Warden mounting points.** The Warden moves, so there are no structure hardpoints; the hive's three grip cells are body offsets (`wardens/swarm.md` table). The GLB carries:
- `warden_anchor` at (0, 4, 0) and `hoist_high` at (0, 34, 0), matching `landmark.warden.path`.
- `sheave_rope` at (0, 110, 0): where the hive's own rope starts. The rope's length changes with the hive's movement, so `warden_swarm.gd` or `warden_look.gd` should draw it, not the static GLB.
- The tipple deck row sits at world [0, 240], y -60, which is local (0, 40, 15). The frame's tipple girders must meet that row's 24 × 16 m deck without covering its top.

**LOD.** The base is the full lattice, rivet plates, ladders and the sheave spokes. The mid replaces lattice legs with box legs with cross-braces and the wheels with 16-segment discs. The far is four box legs, the deck and two wheel discs. The A-and-wheels outline is the whole read, so keep both wheels in the far mesh.

**Materials.** `steel` (black iron `#2b2724` from `_park.py`); `cable` for the ropes; copper only on the hoist fittings. No green: this stage has no beam.

**Reuse.**
- `tools/blender/dig_mechanical/strut_tall.py` and `strut_bent.py` (132 and 92 triangles) as the lattice module.
- `impeller_rim_sector` for the sheave rims (64 triangles).
- The `steel` slot material `assets/materials/dig_mechanical/steel.tres`.
- `_park.py` `strut` and `tube` for the legs.
- The tipple lift (`park/contraptions/lift_platform.glb`, 1,460 triangles) is already the contraption skin at `tipple_lift`; dress the frame around it, not over it.

**Fit with PARK-TILE and PARK-SEAT.** `conveyor_gallery` (200 m `rail` at [-262.5, 40]) tiles `pipeline_rail` (two copies, stretch 0.83). `hoist_house` (a `ledge`) needs its own recipe and is not in this card. `collar_dish`, `tipple_deck` and `floor_sump` stay rows.

**Test that pins it.** The shared checks, plus:
- No `-col` triangle lies inside the 12 m hive well from y 0 to 38.
- `hoist_high` and `warden_anchor` match the `path` within 0.5 m.
- Re-run stage 3's six lines, the floor line and `tests/posture_bands_test.gd` for stage 3. The legs are new solids inside the ring, so this re-run is required.

**Open.** The legs make new harpoon anchors next to the hive. That is probably good, since a leg swing onto the tipple deck is a new line, but it is new behaviour. If the coordinator wants no change to the fight, the legs' `-col` can stop at y 40, above the tipple deck.

---

## Card 4. `landmark_sinkhole`: the sinkhole (`park_sinkhole`, stage 4)

**Row today:** `at` [0, 350], `size` [250, 120, 250], `yaw_deg` 0. **`y` datum: 0**, the plateau rim (`sight_top` is 140 m above the plain at y 140). Locally, `sight_top` is (0, 140, 38) and `warden_anchor` is (0, -99, 38). Sources: `park_sinkhole.json`; stage page section 2.

**Silhouette.** A hole, so from the plateau the landmark is its light column. Up close it is a 250 m round collapse: basalt over pale limestone with mineral stains, a timber gallery ring, a riveted caisson around the pool and the brood's nest on the wall.

| Part | Size and place | Job | Collides |
| --- | --- | --- | --- |
| Rim coping | A broken basalt lip ring on the opening's edge, at most 0.12 m proud of the baked ground | Reads the edge from the plateau | No. The bake owns the rim, so no route changes. |
| Wall stain cards | Vertex-colour quads flush to the stamped wall within 0.3 m, in mineral-stain streaks | Strata and stain that terrain colour cannot draw | No |
| Gallery ring | Timber deck and corbels where the `gallery_ring` row exists (world [0, 300], y -108.24, 70 m wide). Elsewhere, bare corbels and a collapsed deck. | Shows only the ring a ball can actually ride | No. The row is the deck. |
| Caisson lip | Riveted steel ring at radius 40 m around the pool centre, 1 m high | Frames the rising pool | No |
| Headgear | Timber A-legs and a cap beam over the pump-gallery side, outside the pool radius | Mining read | Legs no; cap beam no |
| Nest socket | Broken cells and timber on the wall around `warden_anchor`, 8 m clear radius | The brood's home | No |
| Lamps | Lamp modules on the gallery ring | Ties to the lamp swarm | No |

**Warden mounting points.** `warden_anchor` is (0, -99, 38). Hardpoints for P4: `hp_0` is the nest's crown grip cell (body offset). `hp_1` and `hp_2` are the existing `ring_post_w` and `ring_post_e` anchor-field rows at world [±20, 393]. The swarm sheet puts their hardpoints at y -96, so the offsets from the anchor are (±20, 3, 5). The posts are already world anchors as rows; P4 only changes which line flares and gets snipped. The pool volume is `warden_swarm.gd`'s: radius 40 m (`POOL_RADIUS`) centred 38 m from the nest (`POOL_OFFSET`), so on the landmark's axis. Nothing may enter it between y -120 and -100. `beam_root` sits at the nest; the column rises to `sight_top`.

**LOD.** The base is the full ring dressing, caisson rivets, headgear and stain cards. The mid is the rim coping, the ring deck, the caisson ring and the headgear silhouette. The far is the rim coping only, as a 48-segment ring. From the drop-in the hole cannot be seen into, so the beam is the whole far read; this card relies on P2 more than any other.

**Materials.** `stone` (`assets/materials/dig_stone/stone.tres`) for the coping and stains; `enamel` vertex colour for the timber; `steel` for the caisson; copper anchor eyes; `ancient_lens` around the nest.

**Reuse.**
- `tools/blender/park/caverns.py`: the cenote and cavern-shell palette, the timber and cap-beam builders of `flooded_shaft` (for the headgear), the copper anchor-eye look and the `Water` sheet in the `glass` slot. As placed models: `cenote_pool` 6,008 triangles, `flooded_shaft` 5,038, `cavern_shell` 10,836.
- `tools/blender/dig_stone/` `stone_material.py` and `stone_surface.py` for the coping, and `bed_rubble.glb` (2,432 triangles) as a source for broken rim pieces.
- `dig_mechanical/lamp_straight_module.glb` and `lamp_curve_module.glb` (46 triangles each) along the ring.

**Fit with PARK-TILE and PARK-SEAT.** The main tube, east haulage and west breakthrough segments, and the west gallery's `flooded_cavern` rows, are already authored as short segments (about 50 to 60 m), so they can seat one `lava_tube_run` (48 m, with ±30 degree bends) or `cavern_shell` per segment rather than tile. `caisson_bowl` stays a row. It is a candidate for `flooded_shaft` only if its 80 m footprint matches; check with `seat_probe` first.

**Test that pins it.** The shared checks, plus:
- No geometry of any kind lies inside the pool cylinder (radius 40 m around the pool centre, y -120 to -100). This keeps `warden_swarm.gd`'s rising pool visible at every step.
- The ring deck dressing's plan lies within the `gallery_ring` row's footprint, with a tolerance of 0.5 m.
- `park_landmark_sight_test.gd` is unchanged: it reads baked heights only.

**Open.** The stage page says the gallery ring is a 15 m shelf "all the way round" at the 100 m mark (section 2). The shipped row is a 70 m arc at y -108.24. This card dresses the shipped row and shows the rest as collapsed. A full ring would be a greybox change (KD4 rows), not a landmark change.

---

## Card 5. `landmark_sky_island`: the Hanging Isle (`park_islands`, stage 5)

**Row today:** `at` [0, 520], `size` [180, 318, 180], `yaw_deg` 0. **`y` datum: 200**, the tilt pivot. `warden_mind.gd` tips the island about a pivot `PIVOT_HEIGHT` (118 m) above the tip (`src/combat/warden_mind.gd:39`), and the tip is at world 82. With the origin on the pivot, the tilt is one rotation of the landmark node. Locally, the deck rim is at y 200 (world 400), the tip at y -118 (world 82), `warden_anchor` at (0, -120, 0) and `sight_top` at (0, 200, 0). Sources: `park_islands.json`; stage page section 2; `wardens/mind.md` section 3.

**Silhouette.** An upside-down mountain: a pine-topped deck 180 m across at 400 m, tapering 318 m to a tip 22 m above the net. A thin waterfall pours off the rim and turns to mist. The beam rises from the top deck. It is the tallest thing in the park and the only thing that floats.

**This landmark is mostly built.** `floating_island` in `tools/blender/park/skyislands.py` is the Hanging Isle at the same numbers: deck 180 m, rim y 0, tip at y -318, a 28 m clear lane across the deck. Its model is `assets/models/park/floating_island.glb` (4,344 triangles, 1 draw, plus a 1,040-triangle `-col`), with shells of 418 and 171 triangles. No stage row places it. The card promotes it: same builder, re-origined to the pivot (shift by (0, +200, -90), since `floating_island` is authored entry-lip at z 0 to 180), with three LOD exports and the `hero_landmark` additions.

| Part | Change from `floating_island` | Collides |
| --- | --- | --- |
| Deck and taper | As built; raise ring and strata counts to use the 24,000 budget on the underside, which is what players see from the bowl | See Open |
| Waterfall | New: a ribbon off the rim (`glass` slot, teal vertex colour) that ends in mist cards about 150 m down | No |
| Keel ribs | New: rusted ribs on the lower taper where the hand's fingers curl | No |
| Tip | The lowest 40 m, cupped by the hand: leave the hand's 16 m reach clear | See Open |
| `beam_root` | On the top deck centre | n/a |

**Warden mounting points.** The Warden is the hand (`warden_mind.glb`, `warden_mantle_hand.glb`). Its three knuckle hardpoints are body offsets that ride the island's tilt and sink (`warden_mind.gd:12-16`), so the GLB carries no `hp_` empties. It carries `warden_anchor` (0, -120, 0), `tip` (0, -118, 0) and `pivot` (0, 0, 0). The landmark node must apply the tilt (`TILT_DEGREES` 10) and the sink (`ISLAND_SINK` 2 m) that `warden_mind.gd` publishes through `island_tilted`, `island_tilt_deg` and the sink fields. Only the tests subscribe today (`tests/warden_mind_test.gd:200`; `tests/posture_bands_mind_test.gd:219`). Port note P5.

**LOD.** The base is the deck with pines, the strata taper, the waterfall and the ribs. The mid is the taper at half the rings, the deck as a disc with clumps, and the waterfall as one ribbon. The far is a 12-sided inverted cone, the deck disc and the beam root. A floating inverted cone reads at any range.

**Materials.** As `floating_island`: one vertex-colour surface named `elastomer` (the matte slot); `glass` for the water; copper on the ribs. The Highdraft modules use a texture pipeline instead (`highdraft/islands.py`, `island_large.glb` with `island_large_sandstone-strata.webp`). Keep the park family's vertex colours, but sample the strata colours from that webp so the isle matches the world.

**Fit with PARK-TILE and PARK-SEAT.** None for the landmark. `net_bowl`, the knuckles and the keel-rib rows stay rows. The PARK-TILE note "floating_island's yes is weak" (`docs/decisions.tsv` PARK-TILE) is about tiling a row; this card does not tile it.

**Test that pins it.** The shared checks, plus:
- The `pivot` empty is at the GLB origin, and `tip` is `PIVOT_HEIGHT` below it within 0.5 m.
- After P5, a 10 degree tilt in `tests/warden_mind_test.gd` moves the landmark node's `tip` by about 20.5 m (the sheet's swing, `wardens/mind.md:72`).
- Nothing lies within 16 m of `warden_anchor` except the tip.
- Re-run stage 5's posture bands once the node tilts, since the island becomes visible motion.

**Open.** Whether the tip collides. The knuckle-butte tops and the bowl were measured with no island solid. A tip collider within rope range of the bowl (the tip is 38 m above the 44 m floor) would make a moving harpoon bite, and it would need an `AnimatableBody3D` driven by the tilt, not a static trimesh. Default in this card: visual only, so the shipped bands hold. Adding the bite is a design call for Andrew's sitting.

---

## Card 6. `landmark_spire`: the Crown Spire (`park_crown`, stage 6)

**Row today:** `at` [0, 470], `size` [50, 330, 50], `yaw_deg` 0. **`y` datum: -12**, the bowl floor (`landmark.warden.bowl_floor`). The spire stands in the 12 m deep bowl and its top is at world 330, so it is 342 m tall locally. Locally, `sight_top` is (0, 342, 0) and the perch path runs (0, 30, 45), (39, 30, -22.5), (-39, 30, -22.5). Sources: `park_crown.json`; stage page section 2.

**Silhouette.** A single sandstone spire: a talus skirt, a sheer banded shaft and a dark caprock. Three perch spires stand around it at 45 m. The beam rises from its tip, and the storm's lightning prefers it.

**A clash to fix before building.** The hand flies perch to perch on a 3 s arc that peaks only 9 m above the perches (`warden_mind.gd:45-46`, `PERCH_OFFSETS` at `:51`). The flight from perch 2 to perch 3 runs along local z -22.5, which passes 22.5 m from the spire's axis. A 50 m base (radius 25 m) would put the spire across that flight path and across the ball it drags. KD6 measured the fight with no spire solid in the bowl: the stage's rows are only the bowl, the perch posts and the collector. Default in this card: the shaft is at most 30 m across (radius 15 m) from the bowl floor to local y 60, then widens to the 50 m that the sight model assumed. That keeps 7.5 m of clearance for the hand's body on the 2-to-3 leg. The sight test reads baked heights, not this mesh (PARK.md section 8), so narrowing the base does not move the sight share.

| Part | Size and place | Job | Collides |
| --- | --- | --- | --- |
| Talus skirt | Radius 15 m at the floor, no more than 3 m high | Ground join | Yes. Re-measure. |
| Lower shaft | Ø 30 m from y 0 to 60 | Keeps the flight lane clear | Yes. Re-measure. |
| Upper shaft | Widens to Ø 50 m by y 120, then tapers to Ø 20 m at y 330, in banded strata | The skyline column | Yes, but out of reach above y 60 |
| Caprock | Dark cap from y 330 to 342; `sight_top` and `beam_root` on top | Tip read; the lightning target | Yes |
| Lightning scars | Glassy streak cards down the upper shaft | Ties to the lightning event | No |

**Warden mounting points.** The hand moves, so there are no `hp_` empties. The GLB carries `perch_1` to `perch_3` at the path points, so the test can measure clearances from the model. The perch spires are `anchor_field` rows (`perch_spire_1` to `perch_spire_3`, 12 × 23.73 m posts). They stay the anchor truth and are not part of this GLB.

**LOD.** The base is the strata bands, talus blocks, erosion flutes and scars. The mid is a 16-sided banded shaft and the cap. The far is a 10-sided lofted shaft and the cap, within 1,500 triangles. It is a tall thin shape, so its far read is free.

**Materials.** `rock` or `stone` with the red-and-cream slickrock vertex colours of `skyislands.py`; desert varnish streaks; `glass` for the fulgurite scars; `ancient_lens` on the cap around `beam_root`.

**Reuse.**
- `tools/blender/park/skyislands.py`: the strata banding and slickrock palette of `mesa_lip_kicker` and `floating_island`.
- `tools/blender/park/ledges.py` `mesa_rim_ledge` (1,000 triangles) for caprock edging.
- `highdraft/sky_mesa.glb` (116 triangles) as a reference for the far-read proportion.
- Crown lore lines (`src/core/lore_rows.gd:342`) for the codex fragment, not the mesh.

**Fit with PARK-TILE and PARK-SEAT.** None for the landmark. `crown_collector` (the Fleet ledge at y 64) needs its own recipe and is not in this card. `crown_ramp` (a kicker) can seat `mesa_lip_kicker` once its 30 m length is within 1.5 times the 12 m piece; it is not, so leave it greybox or author a longer kicker.

**Test that pins it.** The shared checks, plus:
- Sample `warden_mind.gd`'s flight arc between every perch pair at 0.05 s steps: the spire's `-col` stays at least 6 m from the arc (the hand's body plus a margin).
- The spire's `-col` radius at y below 60 is at most 15 m.
- Re-run stage 6's lines and posture bands. The spire is a new solid and a new harpoon anchor inside the 120 m engage disc, so this re-run is required.

**Open.** The 30 m lower shaft departs from the stage page's "50 m across at its base". It is reversible by one constant in the recipe. If Andrew wants the full 50 m base, the perch ring has to move out instead (`PERCH_OFFSETS` and the three perch rows), which is a KD6 change.

---

## Port notes for the coordinator

These lines touch files this branch must not edit (`sketches/core-loop/src`, `assets`, `tools`, `tests`). Each one is needed before the landmark GLBs show or work.

| Id | File | Change |
| --- | --- | --- |
| P1 | `src/world/park/park_recipes.gd` (`placed_rows`, `:722-723`) | Add the landmark object to the placed set when its recipe is not "". Without this, no landmark GLB is ever placed. |
| P2 | a presentation script that reads `landmark.light` | Draw one `ancient_beam` column from the GLB's `beam_root` to `sight_top` and beyond, unshaded `#9dff3c`, outside the LOD views |
| P3 | the six `src/world/park/<map_id>.json` `landmark` objects | Add `y`: dam 0, flume 0, pit -100, sinkhole 0, islands 200, crown -12. Check against each stage's bake before committing. |
| P4 | `park_dam.json`, `park_flume.json`, `park_sinkhole.json` `landmark.warden` | Optional: `hardpoint_offsets` from cards 1, 2 and 4. Re-measure the posture bands. |
| P5 | the landmark node for `park_islands` | Apply `warden_mind.gd`'s published tilt and sink to the landmark node about its origin |
| P6 | `src/combat/warden_reactor.gd` | Swing `gate_l` and `gate_r` about their hinge empties on `gates_open` |
| P7 | `assets/asset_budgets.json` or PARK.md:312 | Make the `hero_landmark` ranges and PARK.md agree: 300 / 900 m in the JSON against 600 / 1,400 m in PARK.md |
| P8 | `assets/registry.d/` | One `park_landmarks.json` fragment for the 30 GLBs; fold with `tools/fold_registry.py` |
| P9 | `design-v3/park/stages/1-park_dam.md` section 15 | Correct "stands in as greybox": the landmark places nothing today (fact 1) |
