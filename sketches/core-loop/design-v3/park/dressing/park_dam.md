# park_dam dressing, wave 18 re-proof

## What and why

The dam's crew sites (camps, bunks, benches, laundry) read as plush crews living among working giants: the giant machines are the humans' utility fleet (construction, mining, manufacturing), some corrupted, some loyal drones, some looping workers. Scale contrast is the point, so the crew props stay small, human-sized and homely beside them. This unit brings the dam onto the two checked rules: a per-kind line clearance for the brief's 30 m kind, and the telegraph keepout.

Base: dam head 8bca3482, merged with origin/stage/alpha-w18 f259e8cf (merge d249c53f) and the accepted foundation origin/claude/zealous-franklin-ed0sxr-lineclear e72fff7d (merge 88ce4e96), then the foundation's stage merge be6189ec (merge 9fb8910f; the tree is unchanged). Earlier rounds merged stage 9703fd14 and e83a21c2 and foundation 07748516. The later foundation commits touch only the audit, the static checks and `park_props_test`, so the plan check and pin are unchanged.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_dam --check`: 834 instances (83 litter), 5 violations on the merged rules (all `telegraph`, spot mid_tool_bench_123), then 0 violations after the move below, fingerprint 1202620946. Pin 47128334 to 1202620946 (617986039 before the 30 m pass).

## Telegraph zones

Rule: `park_props.gd` `check_one` fails a prop inside an event's own geometry grown by `hold_clear_m` (a lightning strike is a `strike_m` circle at the site point; design in `DRESSING-KITS.md`), so no prop stands where a telegraph will be drawn and damage lands. Litter that fails is dropped automatically; authored spots fail the plan check.

- `dome_lightning` (site slickrock_domes at (-110, -520), `strike_m` 6, `hold_clear_m` 0): 5 instances of mid_tool_bench_123 (cable_drum, compressor_cart, lunch_pail, sandbags, desert_scrub) stood inside the circle. The spot moved from (-108, -521) to (-124, -530), 18.4 m, the smallest of the positions tried that cleared both the circle and the 10 m mid line clearance (nearer ones on the south side failed line_clear). The `near` label (dome_5) is unchanged since the move is under 20 m.
- Litter dropped: none (83 litter before and after).
- The other five events (plunge_pool_flood, west_wash_flash_flood, east_bench_dropship, toe_vents_wake, powerhouse_boiler) had no hits.

## Tests (an earlier pass, before the be6189ec merge; the final fast lane on 36f31ac7 ran 72 tests, 1 flaky (`first_win_secrets_test`, 180 s limit under load; it passes alone in 65 to 80 s on head and base) and 0 base-red. Each run alone, GODOT_BIN 4.7.2, box load about 20; final merge re-run: park_props_test, park_park_dam_test, park_dressing_pin_test smoke PASS, sketch:lint 0 findings, check:docs 0 failures at 189 files)

park_props_test, park_park_dam_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test: smoke PASS (no counts printed). scatter_rows_test: smoke timed out twice at its 180 s cap under load; run directly it passes, 95 checks (3m43s). run_tier_test: FAIL, 16 of 192 checks, 892 s under load (not diagnosed; no run, tier or scatter file changed in this unit). Measured base-red: the clean stage b0e64a40 fails run_tier_test the same way at load 17, 8 of 192 checks, all `[runtime child seed N] exit=-1 timeout=true`, 3531 PASS lines (coordinator's run), alongside this branch's 16 of 192 at load about 20; not re-run here per the coordinator. `npm run sketch:lint` 0 findings; `npm run check:docs` 0 failures (178 files, 6978 links). Registry fold: 1053 assets, no change.

## Reference boards

Standing rules: ruling 6330671507 (build from named boards; boards settle look only, never mechanics, scale numbers or collision) and ruling 6331210075 (read the board's GROUNDING rows first). Boards viewed for this note, all under `docs/art/reference/`:
- `style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`
- `pilots/pilots-balls-heft-moodboard.jpg` (relative scale only)
- `spillway/spillway-props-moodboard.jpg`, `spillway/spillway-crews-moodboard.jpg`, `spillway/spillway-landmarks-dam-face.jpg`

Sources for claims: the kit recipe `tools/blender/park/props/dam.py`, its palette `tools/blender/park/props/kit.py` (`C`, `BANNED`, `WARN`), and `assets/models/park/props/dam/manifest.json`. The palette pass (4b4e88ec, 6c4175c4) changed colours only, on gate_wheelhouse, compressor_cart, mixer_wreck, hardhat_rack and laundry_line (petrol, oxide, DUSK_BLUE); it changed no kit geometry. The notes below describe the kit as it stands.

**Palette roles.** Board roles, from the spillway props board (`spillway/spillway-props-moodboard.jpg`: sandstone c6a274, oxide 9b513a, charcoal 242a28, petrol 365754, bone d2c5a5, copper b77843) and the shape board (petrol "old enamel bodies"). Kind and line carrying each, from grepping `dam.py`:
- Petrol: `PETROL = "365754"` (line 227). It paints the gate_wheelhouse housing: corner posts (line 103) and horizontal rails (line 120) mixed toward charcoal, back wall planks (line 107), side wall planks with one side mixed toward concrete stain (line 113), and front planks with the door mixed toward bone (line 118). It also paints the compressor_cart body, variant a, with variant c mixed toward concrete stain at 0.4 (line 712), and the mixer_wreck cab, variants a and b, with c mixed toward concrete stain at 0.3 (line 297). This matches the board's petrol-enamel Pump Repair body. Colour guard: 365754 is 0.794 from HAZARD ff5a3c, 0.778 from ANCIENT 9dff3c and 0.848 from MINT 8bf0d3, against the 0.08 limit (`kit.py` `BANNED_NEAR`), and the kit rebuild ran `check_colour` without error.
- Oxide: `OXIDE = "9b513a"` (line 227, the board swatch) on the gate_wheelhouse hand-wheel rim in both variants (line 157), as in the board's Sluice Wheelhouse. `"rust"` (8a5a44) on the compressor_cart b body (line 712), rebar_bloom (line 909) and one stencil_post bar (line 537).
- Sandstone: `"sandstone"` and `"sandstone_dark"` on the rock, plant and ground bases of cold_campfire (line 758), desert_scrub (931), flood_staff (511), lunch_pail (578), mixer_wreck (361); sandbags (871) use `canvas_stain` and `sandstone_pale`. The mixer cab is no longer sandstone_pale.
- Charcoal: `"charcoal"` on frames, tyres and boards: cable_drum (675), cold_campfire (760), compressor_cart (714), flood_staff (501), hardhat_rack (629), lunch_pail (601), mixer_wreck (280), stencil_post (536) and survey_tripod (210).
- Bone and cloth: `"bone"` and `"canvas"` on flood_staff (507, 497), hardhat_rack (621), survey_tripod (217), gate_wheelhouse (151), laundry_line (825), stencil_post (540) and survey_tent (392).
- Crew shirts: `DUSK_BLUE` is now `mix(PETROL, "bone", 0.35)` (line 228), replacing 6c7f8c, which matched no board swatch; the crews board dresses crews in petrol and bone. It is used on hardhat_rack (line 621) and laundry_line (lines 825, 840 and 847).
- Verdigris (`C["verdigris"]` 5f8a7c) is not a body colour: it appears only on the survey_tripod ring (line 207) and the lunch_pail thermos (lines 594 and 597). Earlier text that said verdigris stands in for petrol on gate_wheelhouse and compressor_cart was wrong; neither used it.
- Copper b77843: not called anywhere in `dam.py`.
- Outside the board palette: concrete greys, timber browns, leaf and dry-grass greens (the board's reeds), `FLOWER` c9b45e, `SILVER_LEAF` 8f9a78. None is ancient green, mint or hazard (`BANNED`). The crews board's Life Lilac is not used (grounding line 171 keeps it for ambient locals).

Previews (Blender `--preview-dir`, local, not committed) in `sketches/core-loop/artifacts/local/dressing/dam/preview/`: `gate_wheelhouse_a.png` and `gate_wheelhouse_b.png` (re-rendered, petrol walls and oxide wheel), `compressor_cart_a.png`, `mixer_wreck_a.png`, `laundry_line_a.png` (crew shirts), plus the b and c variants, the LOD strips and `dam_contact_sheet.png` (an `--only` run, so the sheet covers gate_wheelhouse a and b only). Viewed against the board's Sluice Wheelhouse and Pump Repair panels: compressor_cart_a and the mixer cab now read as petrol enamel bodies on charcoal frames; the laundry shirts read as muted petrol-bone cloth. gate_wheelhouse_a and b now have petrol walls and an oxide wheel like the board panel. The panel shows no timber and no roof, so no timber is kept in the walls; the shingle roof and its timber rafters (roof block after line 125) stay as they were, since the panel shows no petrol roof to match. Steel hub, spokes, axle and ring stay iron, the chains stay `cable`, and the plinth stays concrete (the panel's plinth is sandstone block, so this is a minor difference).

**Shape language.** Broad wear and soft toy shapes: props are built from `style="hard_smooth"`, `"round"` and `"soft"` primitives (`kit.py` STYLES), with chunky bevelled boxes for the wheelhouse and compressor_cart (the board's wheelhouse and pump panels), rolled canvas and slack rope for the survey_tent, laundry_line and cable_drum (the board's survey roll and drying rope), and low rounded heaps for sandbags and rebar_bloom. Silhouettes stay readable and low except the two tall machines (gate_wheelhouse, mixer_wreck), which carry the board's giant utility-fleet reading. Neither reads as a live machine: both are static meshes with no collision or animation (ParkProps builds MultiMesh and MeshInstance3D only), the wheel is chained shut (manifest story), the mixer drum is tipped and its cab has no headlight pair (`dam.py` line 296), and the kit has no emission (`kit.py` asserts `emissiveFactor` is empty).

**Materials.** The kit uses brass in one place: the single `d9b44a` tag on stencil_post variant c, the Fleet docket marker (`dam.py` lines 526 and 542, comment "the one brass tag"). Brass reads as Fleet ownership; it is a deliberate Fleet docket there, but the dressing rule prefers copper or steel fittings, so it is named under "Board drift (for review)". Everything else is painted iron, rust, concrete, timber, canvas and rope. Each GLB is one vertex-colour material with no image and no emission (`kit.py` `inspect_glb` asserts `emissiveFactor` is empty).

**Scale to the pilot ball.** Relative only. The ball is `Tuning.RADIUS` 1.0 (`src/movement/tuning.gd` line 95), so its diameter is 2.0 in world units. Manifest heights against that diameter: lunch_pail 0.90 to 1.18 (about half to 0.6x), cold_campfire 1.23 to 1.65, laundry_line 1.857 to 1.900 and stencil_post 1.6 to 1.94 (just under one diameter), flood_staff 2.60 and hardhat_rack 2.61 (about 1.3x), compressor_cart 2.5 to 2.7 and desert_scrub 2.2 to 2.7, survey_tent 2.6 to 4.1, and the two machines gate_wheelhouse 5.7 and mixer_wreck 5.9 (about 2.9x). Crew props sit around or under the ball and the giants well above it, which is the scale contrast the "What and why" section asks for. No new metre values are asserted; the numbers come from the manifest and are unchanged.

**Avoid list, checked against `dam.py`, `kit.py` and the manifest.**
- No emission: pass. `inspect_glb` asserts it per GLB; the manifest has no emission key; no `emi` or `glow` call in `dam.py`.
- No hazard stripes or coral: pass. The only `stripe` hit is a comment, "plain, no stripes" (`dam.py` line 548). ff5a3c is in `BANNED`; no `chevron` or `coral` hit.
- No cache-shaped containers: pass. No `cache`, `chest` or `crate` in `dam.py`. lunch_pail is a small pail, cable_drum a spool, hardhat_rack a rack.
- No taut or decorative grapple cables: pass with a note. cable_drum is a flat rope coil and spilled loop (lines 659 to 703). The gate_wheelhouse cable chains are `sag=0.3` to `0.35`, thin (radius 0.022) and short (wheel to ground ring, lines 171 to 175), so they hang slack rather than span; flagged below for the reviewer.
- No fake ride surfaces: pass. Heaps and slabs (stencil_post c) are at most about 0.5 m, and the recipe comment says "nothing that stands up"; no ramp, deck or rail kind exists. Collision and ride surfaces are not decided by the board.
- No glowing lamps: pass. The two lanterns are "lantern, unlit" and "unlit lantern" (`dam.py` lines 435 and 468), `iron_light`, with no emission.
- No ancient-green or uranium-green: pass. `BANNED` holds 9dff3c; the greens in the kit are leaf, verdigris and silver-leaf plants and patina.
- Highdraft-only items (closed furnace mouths, slack nets): not applicable to the dam.

**GROUNDING rows read** (`GROUNDING.md` (main cb534a2d), no Conflict row among them):
- Line 162, dam-face landmark: in the game; the dam face is World's landform, not copied by props.
- Line 166, spillway props board (wheelhouse, tripod, bench, seals, alcove, recess): planned; the kit follows the wheelhouse, tripod and pump readings, and the drying alcove and seal bench stay board proposals until Andrew approves them.
- Line 167, no emission, hazard stripes, cache silhouettes, taut cables or fake ride surfaces; short clothesline domestic only: followed per the avoid list; laundry_line is the domestic clothesline and carries `line_clear_m` 30.
- Line 168, crews board harmless locals: ambient life, not a prop; not copied.
- Line 169, ambient life hides in boss fights: Life's system, not touched.
- Line 170, second keeper and rest alcove vignettes: not grounded; not built here.
- Line 171, Life Lilac: no lilac on props, as above.

## Board drift (for review)

- stencil_post variant c carries a brass tag (`d9b44a`, `dam.py` line 542). Against the materials board, brass is Fleet ownership; the unit's brief says dressing uses copper or steel, so this is a candidate drift. Not changed in this unit; the reviewer decides.
- gate_wheelhouse sagging chains (`dam.py` lines 171 to 175) are slack by design; named in case a reviewer reads them as decorative cables. Not changed.

## Audit (w18d, default run, mid camera, step 25 m, 258 samples; w18b before in brackets)

- props-only draw delta: max 57, median 12.0 [53, 11.5]
- draw calls: max 390, median 353.0, p95 383.45
- density: 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph) [24 of 49, 24 exempt]. Failing: the same kest window at (18.3, -32.4), 0 kinds, the corkscrew-slot hard keepout
- bare share 38.8 percent [38.8], longest bare run 175 m; void poses 0

## 12-pose replay (before = same tree, `props/park_dam.json` moved aside, same poses; after = default run stills)

Pixel change (share of pixels with a channel difference over 12), from the published 29bda9bf replay (`w18/dam/pixel_change.json` on the evidence branch): 113,-105 6.96; 118,-85 0.34; 155,-50 4.08; 161,-15 0.56; 226,76 0.50; 232,2 0.04; 233,-132 0.66; 239,93 15.40; 24,-69 1.36; 249,163 1.01; 32,-32 0.02; 97,-85 0.91. Median 0.785. An earlier replay gave 15.29, 6.80 and 5.07 for the three large values.
The poses are the barest places; most sit on the canyon floor between walls, the slot keepouts and the corkscrew, where nothing legal can stand, so the change there is small. The pixel figures are not dressing evidence on their own. The independent review of the full-size stills found that the large values at 239,93, 113,-105 and 155,-50 are world-state or render differences: no park prop is in frame at 239, and the slot_bulkhead plank state differs at 113. Visible dressing change is at 161 and 249, with far bits at 24 and 226. The bare share (38.8%) is structural. The lines run on slot-canyon floors 34 m wide, which are keepouts too narrow for low_ground_rows, and through the eye arena and telegraph sites. The density bar passes 24 of 25, and the one fail is inside the corkscrew_slot keepout.
Props-off replay draws: max 390, median 340.

Stills: `artifacts/local/dressing/dam/w18/{before,after}/park_dam/`, sheet `artifacts/local/dressing/dam/w18/before_after.png` (local, not committed).

## Kit heights to brief

The kit review found two kinds built off the dam brief (`sketches/core-loop/design-v3/park/dressing/KITS.md`, dam section; lands in #269, not on this branch). Both are rescaled in `tools/blender/park/props/dam.py`, with no change to geometry, tri budgets or colours.

- `flood_staff` (brief: "water-level staff, 2.6 m"): a 4.579 to 2.604 m, b 4.67 to 2.600 m, c unchanged at 1.732 m (fallen). LOD0 tris a 1000 to 728, b 1072 to 800, c 2240. The two upright variants are no longer auto-tagged tall.
- `laundry_line` (brief: "two posts under 2 m"; "keep at least 30 m from lines"): a and b 2.423 to 1.857 m, c 2.85 to 1.900 m. LOD0 tris unchanged (2128, 1340, 2016).
- Distance of every placed laundry_line to the nearest ride line (ParkProps `line_distance`): 14 instances, 31.0 to 115.0 m. Four were under 30 m (mid_laundry_5 24.5, _113 29.8, _125 24.9, _147 25.6) and their spots moved: _5 to (-310, -598) 33.5 m, _113 to (9, 283) 33.4 m, _125 to (-197, -451) 33.3 m (62 m move; no site within 40 m cleared 30 m), _147 to (-33, -297) 34.1 m. Unmoved: crew_camp_20 33.6, bunk_collapse_30 31.0, crew_camp_81 40.6, bunk_collapse_86 47.5, crew_camp_124 35.6, bunk_collapse_135 49.2, mid_laundry_142 31.4, canyon_15 73.4, crew_camp_rim_24 101.3, bunk_collapse_rim_25 115.0.
- The plan pin moved 1759471770 to 617986039 (new kit heights and the four spot moves). Plan check: 834 instances, 0 violations.

## 30 m brief kinds

- Kind `laundry_line` now carries `line_clear_m: 30` (`tools/blender/park/props/dam.py` `@K.kind`, manifest `line_clear_m: 30.0`), so the plan check enforces it; GLBs are byte-identical, only the manifest gained the field. Brief line (`sketches/core-loop/design-v3/park/dressing/KITS.md`, dam section; lands in #269, not on this branch): "keep at least 30 m from lines", because a washing line reads as a grind or grapple line. Measure: edge-to-line, `line_distance(centre)` minus the instance radius.
- Two of 14 instances were under: bunk_collapse_30 (v=c) edge 28.41 to 30.94; mid_laundry_142 (v=a) edge 29.14 to 31.10. The other 12 are 31.04 or more, unchanged.
- Spots moved: bunk_collapse_30 from (-15, -503) to (-12, -504), about 3.2 m; mid_laundry_142 from (-4, 300) to (-2, 300), 2 m. Near labels unchanged.
- Pin 617986039 to 47128334 for this pass.

## ART-MISTAKES entries checked

`project-guide/handoff/ART-MISTAKES.md` has 37 rows on this head; applied:
- 2026-10-21 World, #242 lane width ("called the LINE flag the actual ride line"): read `check_one` and the event plan in `park_props.gd` before moving anything, rather than assuming what a telegraph zone is (it is a strike circle here, not the site box).
- 2026-10-21 Modeling, #241 lane map ("listed units as owed that the stage held byte for byte"): in the 30 m pass, rebuilt only `laundry_line` and checked that `git status` showed no GLB change, only the manifest field (the later palette pass did rebuild the five recoloured kinds' GLBs).
- 2026-10-21 Modeling, M1 anchor gap tool (run line copied from siblings, exit 127): ran the Blender command from the packet verbatim and confirmed exit 0.
