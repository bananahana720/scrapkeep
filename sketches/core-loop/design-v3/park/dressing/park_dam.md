# park_dam dressing, wave 18 re-proof

> **Historical wave-18/20 dressing receipt:** Live prop placement and pins live in `sketches/core-loop/src/world/park/props/park_dam.json`, `sketches/core-loop/tests/fixtures/pins/park_dam.pin`, and [DRESSING-KITS.md](../DRESSING-KITS.md).

## What and why

The dam's crew sites (camps, bunks, benches, laundry) read as plush crews living among working giants: the giant machines are the humans' utility fleet (construction, mining, manufacturing), some corrupted, some loyal drones, some looping workers. Scale contrast is the point, so the crew props stay small, human-sized and homely beside them. This unit brings the dam onto the two checked rules: a per-kind line clearance for the brief's 30 m kind, and the telegraph keepout.

Base: dam head 8bca3482, merged with origin/stage/alpha-w18 f259e8cf (merge d249c53f) and the accepted foundation origin/claude/zealous-franklin-ed0sxr-lineclear e72fff7d (merge 88ce4e96), then the foundation's stage merge be6189ec (merge 9fb8910f; the tree is unchanged). Earlier rounds merged stage 9703fd14 and e83a21c2 and foundation 07748516. The later foundation commits touch only the audit, the static checks and `park_props_test`, so the plan check and pin are unchanged.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_dam --check`: 834 instances (83 litter), 5 violations on the merged rules (all `telegraph`, spot mid_tool_bench_123), then 0 violations after the move below, fingerprint 1202620946 (the w18d value). The w18h row recomposition re-pinned to 280859597 (816 instances, 83 litter, 0 violations; see Rows recomposed). Pin history: 617986039, 47128334, 1202620946, 280859597.

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

## Audit (w18h, default run, mid camera, step 25 m, 258 samples; w18d before in brackets)

- props-only draw delta: max 55, median 10.5 [57, 12.0]
- draw calls: max 411, median 364.5, p95 393.9 [390, 353.0, 383.45]
- density: 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph) [24 of 49, 24 exempt]. `density_open_checked` 0, `density_open_rejected` empty (no `--open`, ruling 6332450092). Failing: the same kest window at (18.3, -32.4), 0 kinds, the corkscrew-slot hard keepout; no new fail
- bare share 38.8 percent [38.8], longest bare run 175 m; void poses 0
- Evidence: `artifacts/local/w18h/park_dam/` (local, not committed). Method: headless Godot 4.7.2, OpenGL compatibility proxy on cloud llvmpipe, 260 s; not a frame-cost proof, not human feel.

### Previous run (w18d, default run, mid camera, step 25 m, 258 samples; w18b before in brackets)

- props-only draw delta: max 57, median 12.0 [53, 11.5]
- draw calls: max 390, median 353.0, p95 383.45
- density: 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph) [24 of 49, 24 exempt]. Failing: the same kest window at (18.3, -32.4), 0 kinds, the corkscrew-slot hard keepout
- bare share 38.8 percent [38.8], longest bare run 175 m; void poses 0

## Rows recomposed (w18h)

Why: DECISIONS section 8 asks for vignettes, not scatter, and the islands gate rejected even rows of spots. A lane-wide strict scan (collinear runs within 1.5 m of a line with spacing CV under 0.1, and sets at one yaw) flagged this file.

Scan before: 135 spots, 1 collinear run, 13 one-yaw groups. The run was four heroes at x = -160, 40 m apart (wheelhouse_yard_rim_22 at z -5, mixer_graveyard_rim_23 at 35, crew_camp_rim_24 at 75, bunk_collapse_rim_25 at 115), yaws -69, -69, -69, -60, all labelled "rim fill". Scan after: 133 spots, 0 collinear runs, 12 one-yaw groups.

What changed:
- Pruned mixer_graveyard_rim_23 and bunk_collapse_rim_25. They stood 80 and 110 m from the ride line, outside the 60 m density window (the audit's kinds radius is 120 m and the camera far plane 700 m, so they may still show at distance), so they added a stamped row and nothing to any density window. The audit shows no density change.
- Kept wheelhouse_yard_rim_22 at (-160, -5), yaw -40, label "west rim lookout over the dam face". The writer reports that a trial move to (-150, -12) failed the plan check (slope and the wash_fin_west keepout on the rim edge; no receipt kept), so it stays; only its yaw and label changed. Its neighbour tool_wall_rim_21 is a different template and 41 m away.
- Moved crew_camp_rim_24 from (-160, 75) to (-176, 72), yaw -95, label "west rim hollow ... looking across the canyon". The offset breaks the line; the spot is legal (0 violations).
- Canyon fill: rewrote the labels of low_spool_stub_canyon_13, low_slump_bags_canyon_14, mid_laundry_canyon_15, low_chalk_tally_canyon_16 and mid_hat_wall_canyon_17 to a place and a moment. Yaws changed from 89 to 70, 100, 128, 112 and 60; pour_site_159 became 85 and wheelhouse_yard_160 92 (their slot_fin_far and eye_fin_east labels already named a place). Some neighbours still sit within 12 degrees: 14/16 12 at 30 m, 14/tool_wall_158 7 at 35.9 m, 159/158 8 at 50 m, 159/160 7 at 50 m, 14/canyon_11 7 at 54 m, 14/160 8 at 65.5 m, 13/17 10 at 66.3 m, 159/canyon_11 8 at 69.5 m (verifier measure, pairs within 70 m). Others differ more: 14/159 15, 16/160 20. Spots 13, 14, 16 and 17 still stand along x = 72 to 78 at the loose scan's tolerance, now with varied yaws; the strict scan finds no row. No canyon spot moved.

Remaining one-yaw groups: the 7 that card (b)'s check flags (the north canyon fill, the tally fill with spool_121, the three dome camp trios and the canyon 18/19 group, plus the z -550 row) were fixed in w18l; see "w18l row and yaw fixes" below. The looser lane scans (70 m reach) still list clusters that the card (b) rule (3 or more spots linked within 24 m, yaws within 1 degree) does not flag. These include the line-facing canyon fill itself: canyon_5, 8 and 9 share yaw -87 (no two of them closer than 24.3 m, so the 24 m link joins at most a pair), canyon_7, 10 and 11 share -83, tally_0 and tally_3 share 77, and p134 and canyon_18 share -104. They share a yaw because each faces the same straight stretch of line from beside it, so their fronts face the rider. Not changed here.

New counts: 133 spots (was 135), 816 instances (was 834), 83 litter, 0 plan violations, pin 1202620946 to 280859597 (intended re-pin).

## 12-pose replay (before = same tree, `props/park_dam.json` moved aside, same poses; after = default run stills)

Pixel change (share of pixels with a channel difference over 12), from the published 29bda9bf replay (`w18/dam/pixel_change.json` on the evidence branch): 113,-105 6.96; 118,-85 0.34; 155,-50 4.08; 161,-15 0.56; 226,76 0.50; 232,2 0.04; 233,-132 0.66; 239,93 15.40; 24,-69 1.36; 249,163 1.01; 32,-32 0.02; 97,-85 0.91. Median 0.785. An earlier replay gave 15.29, 6.80 and 5.07 for the three large values.
The poses are the barest places; most sit on the canyon floor between walls, the slot keepouts and the corkscrew, where nothing legal can stand, so the change there is small. The pixel figures are not dressing evidence on their own. The independent review of the full-size stills found that the large values at 239,93, 113,-105 and 155,-50 are world-state or render differences: no park prop is in frame at 239, and the slot_bulkhead plank state differs at 113. Visible dressing change is at 161 and 249, with far bits at 24 and 226. The bare share (38.8%) is structural. The lines run on slot-canyon floors 34 m wide, which are keepouts too narrow for low_ground_rows, and through the eye arena and telegraph sites. The density bar passes 24 of 25, and the one fail is inside the corkscrew_slot keepout.
Props-off replay draws: max 390, median 340.

Stills: `artifacts/local/dressing/dam/w18/{before,after}/park_dam/`, sheet `artifacts/local/dressing/dam/w18/before_after.png` (local, not committed).

## Kit heights to brief

The kit review found two kinds built off the dam brief (`sketches/core-loop/design-v3/park/dressing/KITS.md`, dam section; lands in #269, not on this branch). Both are rescaled in `tools/blender/park/props/dam.py`, with no change to geometry, tri budgets or colours.

- `flood_staff` (brief: "water-level staff, 2.6 m"): a 4.579 to 2.604 m, b 4.67 to 2.600 m, c unchanged at 1.732 m (fallen). LOD0 tris a 1000 to 728, b 1072 to 800, c 2240. The two upright variants are no longer auto-tagged tall.
- `laundry_line` (brief: "two posts under 2 m"; "keep at least 30 m from lines"): a and b 2.423 to 1.857 m, c 2.85 to 1.900 m. LOD0 tris unchanged (2128, 1340, 2016).
- Distance of every placed laundry_line to the nearest ride line (ParkProps `line_distance`): 14 instances, 31.0 to 115.0 m at w18c; at w18h, 13 instances, 33.3 to 111.7 m (verifier probe, which reproduces the w18c values for rim_24, rim_25 and canyon_15 on the 2e08ecc4 file). Four were under 30 m (mid_laundry_5 24.5, _113 29.8, _125 24.9, _147 25.6) and their spots moved: _5 to (-310, -598) 33.5 m, _113 to (9, 283) 33.4 m, _125 to (-197, -451) 33.3 m (62 m move; no site within 40 m cleared 30 m), _147 to (-33, -297) 34.1 m. Unmoved: crew_camp_20 33.6, bunk_collapse_30 31.0 (33.5 re-measured at w18h), crew_camp_81 40.6, bunk_collapse_86 47.5, crew_camp_124 35.6, bunk_collapse_135 49.2, mid_laundry_142 31.4 (33.4 re-measured at w18h), canyon_15 73.4 (72.7 at w18h: its yaw change moved the line), crew_camp_rim_24 101.3 (111.7 at w18h: the spot moved 16.3 m, to (-176, 72), and its line stands at (-182.4, 64.9)), bunk_collapse_rim_25 115.0 (pruned in w18h, so 13 instances remain).
- The plan pin moved 1759471770 to 617986039 (new kit heights and the four spot moves). Plan check then: 834 instances, 0 violations (816 after w18h).

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

## w18l row and yaw fixes (card (b), #323)

Card (b)'s check flagged dam for 1 row and 6 yaw groups (the row's trio is also one yaw group). This round fixes all 7, which covers the fix list from the coordinator (canyon_5 to 11, tool_wall_158, tally_0, 2, 3 and spool_121). No spot was added or deleted.

Yaw. Each changed spot now faces the nearest point on the closest ride line (yaw = degrees(atan2(dx, dz)), the kit front being local +Z). Their old yaws pointed away from the rider. Where two linked spots would land within 3 degrees (a margin over the rule's 1 degree), one was turned 4 degrees (the table gives the turn) toward a point on the same line a little up or down it; the label names that point. The tool also said five spots could not take the line-facing yaw: crew_camp_81 (a laundry_line prop 23.2 m from a line, 30 wanted), tally_0 (flood_staff on a 26.9 degree slope), spool_121 (sandbags 6.1 m from east_lane_fin), canyon_11 (sandbags 6.2 m from slot_fin_far) and canyon_19 (a compressor_cart 5.2 m from slot_fin_far). Each moved by the smallest step that passed (1 to 2 m, canyon_11 from x 72 to 74, except crew_camp_81, 6.3 m back from the line). Two more moves break the row and the x = 72 column: low_slump_bags_17 from z -550 to -547 (3 m off the z -550 line, so the trio no longer sits within 1.5 m of one line) and canyon_9 from x 72 to 76.

| Spot | at (old -> new) | yaw (old -> new) | near label (new) | Target faced |
| --- | --- | --- | --- | --- |
| mid_tool_bench_16 | [-263, -550] -> same | -172 -> 4 | sable line z -534 | sable line at (-262, -534), -4 deg off the nearest point |
| low_slump_bags_17 | [-245, -550] -> [-245, -547] | -172 -> 12 | sable line z -536 | sable line at (-243, -536), 4 deg off the nearest point |
| low_lunch_rock_18 | [-226, -549] -> same | -172 -> 8 | sable line z -539 | sable line at (-225, -539), 0 deg off the nearest point |
| low_slump_bags_31 | [-32, -489] -> same | 72 -> -108 | sable line z -493 | sable line at (-46, -493), 0 deg off the nearest point |
| mid_tool_bench_32 | [-36, -471] -> same | 72 -> -104 | sable line z -475 | sable line at (-52, -475), 4 deg off the nearest point |
| low_lunch_rock_33 | [-44, -454] -> same | 72 -> -108 | sable line z -458 | sable line at (-57, -458), 0 deg off the nearest point |
| crew_camp_81 | [-12, -680] -> [-14, -686] | -173 -> -24 | rivet line z -650 | rivet line at (-30, -650), 0 deg off the nearest point |
| low_slump_bags_82 | [9, -663] -> same | -173 -> 7 | cannon line z -649 | cannon line at (11, -649), 0 deg off the nearest point |
| low_spool_stub_121 | [53, 470] -> [52, 470] | -103 -> 81 | kest line z 473 | kest line at (71, 473), 4 deg off the nearest point |
| low_tool_roll_134 | [-10, -657] -> same | -173 -> 11 | cannon line z -647 | cannon line at (-8, -647), 4 deg off the nearest point |
| mid_hat_wall_153 | [38, 127] -> same | 76 -> -100 | cannon line z 122 | cannon line at (10, 122), 4 deg off the nearest point |
| tool_wall_158 | [80, -10] -> same | 93 -> -91 | cannon line z -11 | cannon line at (19, -11), -4 deg off the nearest point |
| low_chalk_tally_tally_0 | [46, 398] -> [45, 398] | -103 -> 77 | kest line z 407 | kest line at (86, 407), 0 deg off the nearest point |
| low_spool_stub_tally_2 | [52, 428] -> same | -103 -> 81 | kest line z 432 | kest line at (80, 432), 4 deg off the nearest point |
| low_brittle_rebar_tally_3 | [52, 452] -> same | -103 -> 77 | kest line z 457 | kest line at (74, 457), 0 deg off the nearest point |
| low_slump_bags_canyon_5 | [78, -107] -> same | 93 -> -87 | cannon line z -104 | cannon line at (14, -104), 0 deg off the nearest point |
| mid_pour_edge_canyon_7 | [90, -89] -> same | 93 -> -83 | cannon line z -80 | cannon line at (16, -80), 4 deg off the nearest point |
| low_tool_roll_canyon_8 | [72, -71] -> same | 93 -> -87 | cannon line z -68 | cannon line at (16, -68), 0 deg off the nearest point |
| low_chalk_tally_canyon_9 | [72, -47] -> [76, -47] | 93 -> -87 | cannon line z -44 | cannon line at (18, -44), 0 deg off the nearest point |
| mid_overgrown_canyon_10 | [84, -59] -> same | 93 -> -83 | cannon line z -51 | cannon line at (17, -51), 4 deg off the nearest point |
| low_cold_fire_canyon_11 | [72, -29] -> [74, -29] | 93 -> -83 | cannon line z -22 | cannon line at (19, -22), 4 deg off the nearest point |
| low_cold_fire_canyon_18 | [48, 109] -> same | 76 -> -104 | cannon line z 101 | cannon line at (15, 101), 0 deg off the nearest point |
| mid_tool_bench_canyon_19 | [66, 109] -> [66, 110] | 76 -> -100 | cannon line z 101 | cannon line at (15, 101), 4 deg off the nearest point |
| low_cold_fire_p134 | [29, 124] -> same | 76 -> -104 | cannon line z 119 | cannon line at (11, 119), 0 deg off the nearest point |

Labels. 26 dam labels were the template story cut mid-word at 40 characters. They now read "<row id>: <story cut at the last whole word within 60 characters>"; for example low_lunch_rock_1 is "dome_16: Three pails on a flat rock and a brittlebush seedling: lunch" (was "...a brittle") and bunk_collapse_30 is "dome_19: A collapsed canvas tent with a washing line and boots," cut at its last whole word. The 24 changed spots above use "<line> line z <station>: <story cut>" naming the line point they face; 3 of the 26 are among them, so 23 spots changed label only. The row ids dome_2, dome_4, dome_7, dome_19 and the_eye are no longer in the 24 spots' labels.

Checks (headless Godot 4.7.2, Linux).
- New check (`park_props_plan --map=park_dam --check`, scan merged in a separate tree): 816 instances, 0 violations, 0 pattern, 0 pin, 0 lint.
- Old check on this branch alone: 0 violations, fingerprint 2441315749 (matches the pin).
- Pin: 280859597 to 2441315749 (intended re-pin; positions, yaws and moves changed the expansion).
- park_props_test: exit 0, "[park_dam expansion matches its pin]" passes.
- Density (w18l, no `--open`): 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph); failing: kest (18.3, -32.4), the same corkscrew window. No new fail. Draw calls max 391, median 363.5; bare share 38.8 percent, longest bare run 175 m. Not a frame-cost proof, not human feel.
- Loose lane scans for comparison: strict scan 0 runs and 12 one-yaw clusters before, 0 runs and 7 after; the proto scan 1 row and 16 yaw groups before, 0 rows and 14 after.
- Labels that ended on a dangling word ("a tripod resting on", "a kettle, a washing", "the odds") or a trailing comma were cut back to the previous clause: 15 spots, `near` text only, so the pin is unchanged. Five more (two ending "left where", three ending "at the") were missed here and are fixed in w18n below.

## w18n rows after the #323 span fix

The row rule in #323 first skipped any line-defining pair more than 40 m apart, so w18l missed three rows whose end spots sit 55 to 67 m apart. Card 1 caps only the consecutive gaps (at most 40 m), and af522720 on the scan branch now allows pairs up to 80 m. Three spots moved, one each, each by 2 m or more perpendicular; labels are unchanged.

| spot | at | yaw |
| --- | --- | --- |
| bunk_collapse_30 | [-12, -504] -> [-5, -512] | 72 -> 48 |
| low_lunch_rock_132 | [-49, 291] -> [-49, 286] | 35, kept |
| low_peg_line_view_4 | [-222, -522] -> [-218, -522] | 146, kept |

The first try for bunk_collapse_30 (-17, -504) broke its laundry line's 30 m clearance, so it moved to (-5, -512), about 5 m off the row. Its yaw 72 predates w18l, which did not re-aim it. Review found it faced exactly away from sable, 32.6 m west (bearing -108.4). The spot stands between two ride lines: the cannon, kest and tally trunk is 41.7 m east (bearing 47.7). Turned to -108 toward sable, its laundry line came 24.9 m from the line (want 30), and moving it back far enough made a new row. So it now faces the trunk, which three lines share, at yaw 48. The other two moved spots keep their yaws.

Checks (headless Godot 4.7.2, Linux).
- New check with `--file` against dam plus af522720: 816 instances, 0 violations, 0 pattern, 0 pin, 0 lint. `rows.py <file> 80` prints "triples 0".
- Old check on this branch alone: 0 violations, fingerprint 746751661 (matches the pin).
- Pin: 2441315749 to 2928990529, then 746751661 after the yaw turn (intended re-pins).
- park_props_test: exit 0, "[park_dam expansion matches its pin]" passes.
- Density (no `--open`): 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph); failing: kest (18.3, -32.4), unchanged. No new fail.

Labels, gate review: five labels still ended on a dangling word, because the lint accepts a whole-word ending. rebar_thicket_45 and rebar_thicket_89 ("...slab chunks left where") now end "...left where the forms came down". pour_site_55, pour_site_93 and pour_site_159 ("...in silt at the") now end "...in silt at the last pour". `near` text only, so the pin stays 746751661. No dam label now ends on a comma, a space or a dangling word.

## w18p outskirts, floor and edge (4080 park stills, acb55972)

Why: from above, the dam read as rows of identical props on flat sand, and the park ended in a hard straight line over a flat grey plane. The rows were not this file's vignettes. They were the 26 hoodoo and saguaro anchor fields that fill the outskirts (`park_recipes.gd` `anchor_posts`: a 20 m staggered lattice, one variant per field). The straight line was the square's 100 to 150 m edge standing as a wall over a 0 m apron.

What changed (no change to this file's spots, kit, draws or tri budgets):
- Natural stands (`park_recipes.gd` NATURAL_STANDS): a hoodoo field or saguaro stand at least 60 m across moves each lattice post up to 7 m, seeded by the row id, and keeps it 12 m from its neighbours. A post near the field's edge moves less, and a post beside a lane or footprint gap stays put. Lane edge posts never move. Post counts, colliders and the one MultiMesh per field are unchanged. 4,465 of the dam's 6,058 posts move. The pit, sinkhole and islands stands move too (26, 850 and 2 posts). `park_anchor_stand_test` holds every park to its count, the gap and the 40 m reach (dam worst 36.1 m to a post centre, 0 of 18,698 points lost).
- Mesa rim (`tools/park_bake.gd` APRON_RIMS, dam only): the apron carries the square's edge height out to a lip 6 to 100 m beyond the square. The lip wanders along the edge, and a warp cuts bays and spurs across it. It then falls over 55 to 95 m as a cliff and talus to the 0 m floor, with 11 rounded buttes standing beyond. The apron is drawn, never collided, so no line, post or bot meets it. `park_apron_rim_test`: seam 2.33 m, the half-height line 79.0 m out on average with a 17.3 m spread, 0 m at the region's edge, and the flume's apron is byte-identical. The other parks' bakes changed only in `bake.json`'s tool hash (and `graph.json`'s bake hash). Their binaries are unchanged.
- Floor patches (`park_terrain.gd` FLOOR_PATCHES, dam only): Terrain3D's macro variation draws darker, scoured patches and warm wash stains, at full strength on flat floor and fading on slopes, from one shared 256 px noise tile. It runs in the shader that already draws the floor, so it adds no draw, vertex or texture slot. Other parks get white multipliers, which draw as before.
- Debris clumps (`scatter.gd` CLUMPS, dam only): the ground scatter keeps a candidate with a chance that follows a 70 m noise field. Rocks, pebbles, scrap and cable therefore gather in patches instead of an even sprinkle. Each row draws 1/keep times its candidates, and the keep chance is clamped symmetrically about keep (0 to 2 keep), so the expected count and the draws stay the same.

Post height (coordinator call on #396): the 26 outskirts fields stood 2 m tall (`size[1]` 2), which squashed the hoodoo and saguaro GLBs into disc and spool shapes. They now stand 10 m (`size[1]` 10, drawn 1.1x the authored 9 m; 10 is the nearest height `anchors/anchor_fit.json` already fits for every hoodoo and saguaro variant), and the fitted colliders scale with them. Post count and positions are unchanged, so grapple reach is too. Stage 1 park bots (`--table=park --stages=1`, seeds 1 to 6): all six skipper rows unchanged; four of six completionist rows unchanged, seed 3 19,190 to 19,423 ticks (+2.6 s) and seed 6 15,970 to 16,568 ticks (+6.6 s), both in the find beat, no route lost. The fallback (2 m colliders under a mesh drawn 9 m) kept the rows but failed `park_anchor_corner_probe_test` with 44 dam bounces more than 1.5 m from the drawn post, because a 2 m fit spans the whole squashed mesh while the drawn post's foot is narrower, so it was dropped. Lane edge posts still line each lane at 12 m.

Stills: `artifacts/local/dam_edge/{before,after}/` (local, not committed; method: headless-display Godot 4.7.2 under xvfb-run on cloud llvmpipe, OpenGL compatibility; a magenta 3 m control block planted 6 m east of the ball is in frame in `top_ball`, `dayarc`, `high` and `player`). Composition and colour only. Frame cost and feel are not judged here.

## w18 unit 10 canyon walls (the park edge, 26 Oct)

Why: the edge still had nothing to read. On 0e2bc2f0 the ground ran flat (100 to 150 m, the same height 40 m in) to the play square's edge, and a ball held outward was snapped 39 m back to the play rect at +-799 m (`flow.gd` `_rescue_if_fallen`) with no cue, once or twice per roll (4 of 4 rolls east and west). Past the square, the w18p mesa lip kept going, so the ground looked like it went on. The board (`docs/art/reference/spillway/spillway-landmarks-dam-face.jpg`) frames the dam with stepped sandstone canyon walls.

What changed:
- Four `canyon_wall_*` rows (`element` ground, `landform` mesa_rim, `greybox:ground`, `stamp` mesa, no `y`): 32 m high, centred on each edge and 1,680 m long, so each is a mesa edge by Andrew's "Edges are ground" (`park_map.gd` `mesa_edge`, `placeholder-gate.mjs` `isMesaEdge`) and counts as terrain, not a placeholder. The face rises over 0.3 x 32 = 9.6 m from its foot (x +-765, z 765 south, z -775 north, so the north play rect edge at -780 stays on the face and a rescue there rolls down), then a flat top runs out to the edge and the apron rim carries it on. The corners, where two rows add, stand 64 m. The mesa_rim landform paints the sandstone slot, which the edge already had (surface.bin is unchanged), so the faces take the auto-shader's steep strata. The ground's height range is now -8.0 to 214.5 m (was 168.9).
- Eighteen outskirts anchor fields (hoodoo and saguaro, ids 1 to 26) stop 12 m short of the nearest foot, so no post stands on a face and the gap between a post and a face is never ball-sized. Their other edges are unchanged.
- Graph: no wall-top node is reachable from the spawn (2,181 band nodes, 0 reached). Zones 100 -> 104 (one per wall); shelf_sag_corner_3 and 4 are no longer dead ends (the east and west walls touch them), so they leave `anchors()`. Neither was in the rib cache pool (detour over 300 m), but `director.gd` `off_spine` now reads 0 there, so a kill in those two outskirts pockets pays the plain panel rate instead of the rib rate. The world 1 radio find (`secrets.gd` `dam_shift_radio`) stood there, so its two spots moved to the flat dead ends left off every line: `east_rim_bench` (232, 184) and `service_ledge` (-184, 488), both facing north (follow-up PR to #488). Wave 19 moved the service_ledge spot again, to `slot_fin_far` (44, -244) facing north-east: its face looked across a 24 m slot, so only a jump broke it (red team, 26 Oct). The same pass moved the turbine seep's `powerhouse` spot onto the deck (104, 496) facing east, off the ramp a roll could not climb fast enough; a follow-up moved it to mid-deck (120, 530) facing north, because a 50 degree roll at the east-facing face dropped off the deck edge (cautious red team on b9c07752). The north play rect edge (z -780) lies 5 m up the north face, so a director or rogue spot clamped to it lands on the face and rolls down. Reported, not gated: longest path estimate 2,375 -> 3,144 m (it starts its sweep on a wall top), spawn-to-beacon share 0.569 -> 0.430.
- `park_dam_rim_roll_test`: the real ball on the park table in the north-east and south-west corners: pressed into the corner it meets both faces and rests within 2 m of each foot (on the base, with no wall, it runs 3.6 m past in the north-east, and launches are snapped back: 8 of 28 checks fail there) with no snap; it escapes back and along each wall (12.7 to 16.7 m in 1.5 s); sent square at each of the four walls at 45 m/s it climbs 4.9 to 5.2 m and rolls back to the basin floor with no snap. Every wall's crest is at least 28.9 m over its foot (east, z -140). A full run on all four sides and four corners (3 spots a side) passed the same checks before the test was cut to fit its smoke cap. `park_dam_fin_foot_probe_test` (the 25 Oct wedge spot) stays green, 8 of 8.
