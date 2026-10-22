# Crown (`park_crown`) dressing kit

Dressing lane (DRESSING-KITS.md): the Blender kit and its placement. Recipe `tools/blender/park/props/crown.py`; GLBs, `manifest.json` and import stubs under `assets/models/park/props/crown/`; registry rows in `assets/registry.d/park_props_crown.json` (the Gate lane folds `registry.json`). Placement is in `src/world/park/props/park_crown.json`.

## What and why

The giant machines of Highdraft are the humans' utility fleet (construction, mining, manufacturing), per Andrew's machine ruling (#241): some are corrupted, some are loyal drones, some are looping workers. The crew sites in this kit read as plush crews living among working giants, so the scale contrast is the point: small ochre rope and petrol-enamel gear at the feet of tall machines and spires. These are working machines, never weapons. Brief: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269); where it is absent on this branch, the lane's KITS.md copy was read.

The kit tells two stories. The net-weavers are non-hostile builders, so only their gear appears (ochre rope, nets, hammocks, a loom, mending baskets), never a face or a creature. The Fleet signal crew's gear has petrol enamel `#365754` bodies, copper `#b77843` fittings, iron oxide `#9b513a` only as patches, and one brass tag, and is drawn as abandoned equipment: a hut, a weather post, a flat-lying cable spool and a tally slab, with no barrels and no gun-like masts. The ancient spires are never touched. Props use pale canvas, ochre rope, dusty sage and charcoal so they separate in value and hue from the red-orange sandstone ground, which sits close to HAZARD in hue. Brass is `#d9b44a`, used only on the Fleet tags.

| Kind | Class | LOD0 tris (a/b/c) | Height m | Tags | Story |
| --- | --- | --- | --- | --- | --- |
| `loom_frame` | hero | 11312/9768/8952 | 4.6/4.6/3.6 | machine,soft,tall | Net-weavers' floor loom: chunky bobbins on the bed and a half-woven ochre net in a leaning frame. |
| `billing_booth` | hero | 11096/11296/9976 | 4.1/4.1/4.1 | machine,sign,tall | Fleet signal crew's tally hut: faded petrol-enamel walls patched with oxide and timber, a chalkboard counting ELEVEN against TWELVE, abandoned mid-shift. |
| `storm_station` | hero | 16092/16264/8752 | 4.5/4.5/2.9 | machine,sign,tall | Fleet weather post on a squat plinth: cup anemometer, and a big barometer dial whose needle sits on STORM: YES. |
| `lookout_deck` | hero | 15464/15532/15532 | 9.3/9.1/8.4 | soft,tall | Net-weavers' log-crib lookout: lashed logs and fieldstone holding a roped plank deck (the perch, 7.05 m up), a net over the rail, a lean-to cloth that is up, half down, or gone. |
| `hammock_rig` | prop | 2328/2448/2284 | 1.4/1.4/1.4 | soft | Net-weavers' low hammock on two short posts, a blanket still in it; run down, it sags to the dust. |
| `knot_board` | prop | 2940/1752/2032 | 1.7/1.2/1.2 | soft | A mending basket of spare net and a knot board with sample splices, set down mid-lesson. |
| `spool_shed` | prop | 2980/2980/2656 | 3.0/3.0/2.1 | machine | A Fleet cable spool lying flat under a four-post canopy, its brass tag the only mark of owner. |
| `fulgurite` | prop | 1576/1696/1436 | 0.7/0.4/0.3 | - | Where lightning struck sand: pale glass tubes branching half-buried in a scorched sand scar, a bent rod lying by. |
| `watch_stool` | prop | 1500/1188/1380 | 1.5/0.9/1.4 | soft | A lookout's stool with a tarp slung over it and a thermos left on the seat: someone is coming back. |
| `dish_stones` | prop | 2580/2880/2532 | 1.6/0.4/0.7 | - | Three smooth palm dishes where someone sets a morning drink: one still steaming, one cold. |
| `rope_fence` | prop | 2060/1948/1364 | 1.2/1.3/1.3 | - | A short net-weaver rope fence between two stout posts, knotted with cloth tags, marking a mending spot. |
| `storm_lantern` | prop | 1300/1380/1156 | 1.5/1.5/1.0 | - | An unlit storm lantern hung on a short crook post, waiting for the dark to come. |
| `tally_slab` | prop | 2492/2236/2208 | 1.8/0.3/1.0 | sign | A slate tally slab the signal crew scratched with chalk: forty tallied, forty-one just begun. |
| `rabbitbrush` | prop | 2736/1812/2944 | 1.7/1.0/1.6 | plant | Dusk-flowering rabbitbrush, a sage-green clump with dusty yellow plumes; in c it has grown up through a fallen iron wheel. |
| `yucca` | prop | 2644/824/2994 | 2.4/1.6/2.1 | plant | A yucca rosette with a tall cream flower stalk; the dry one is winter-bare, the third grows through a flat gear plate. |
| `kite_pennant` | prop | 2088/2088/1492 | 1.8/1.5/0.6 | - | A crew pennant on a thick stake in a cairn: out in the wind, slack, or on the ground after the gale. |

Variants run a (in use), b (run down), c (collapsed or overgrown). Notes on swaps and reviews:

- `hammock_rig` posts stay under 1.5 m; `spool_shed` is a two-sided gabled canopy with gable boards (a single sloped plane reads as a ramp); `billing_booth`'s "ELEVEN / TWELVE" is chalk tally strokes (eleven and twelve) because the kit cannot carry text; the `storm_station` "STORM: YES" is a needle on the STORM end plus a three-stroke label slab.
- Fleet gear is weathered: petrol-enamel bodies (a lighter shade of the same petrol on every fifth plank), two oxide patches and a timber patch on the booth, copper fittings (booth stovepipe, storm station anemometer and vane, spool windings), with a stove-in panel and sagging roof on b and c, with a stove-in panel and sagging roof on b and c, and an irregular fieldstone footing under the storm station. Its mast is short (about 4.5 m overall) with a cup anemometer and a wind vane, so it cannot read as a signal mast or turret.
- `fulgurite` is irregular branching pale-glass tubes in a sand scar with a short bent rod beside them: no radial symmetry, no disc, no knobbed stake (those read as a trap or mine).
- `loom_frame` leans back and carries an awning so it does not read as a two-post gate. Plants-through-scrap are `rabbitbrush_c` (iron wheel) and `yucca_c` (gear plate). Crew warmth: hammock blanket, thermos on a stool, mug and laundry at the booth, steaming dish stone.
- Keep `kite_pennant` 30 m from lines.

## Placement (21 October 2026, round 5)

`src/world/park/props/park_crown.json`: 23 templates, 154 spots, 924 vignette instances plus 109 litter (1033 in all), pinned (533729188; 2441257203 before the telegraph pass). Low vignettes stand 8 to 16 m off the line, mid ones to 40 m, heroes 24 to 60 m. Fleet templates stand only at Fleet-row points at least 60 m from `camp_signal` and the Fleet homes; nothing is within 75 m of the alcove ledge; the spires and Content greybox rows are untouched. Spots were fitted by script against `validate` (`park_props.gd` check_one), not hand-picked; plan `--check` reports 0 violations.

### Purpose and why each template reads

Each template's `story` line in the file says what it is and which moment it shows. Why they read without blocking a line or a telegraph, and what was checked:

| Template | Moment it serves | Why it reads and clears the line |
| --- | --- | --- |
| mending_yard, weaver_boneyard, hammock_camp, net_lesson, watch_post, lightning_scar | The net-weavers' working slope beside the ride | Ochre rope, nets and hammocks against the red-orange sandstone (KIT palette in DRESSING-KITS.md); heroes stand 24 m or more from a line and out of route lanes (TALL tier), low pieces 6 m or more (LOW tier), all by `validate`. |
| abandoned_booth, dead_weather_post, cable_corner, log_post | The Fleet signal crew's abandoned equipment | Oxide and charcoal, one brass tag, never in a camp: at least 60 m from `camp_signal` and the Fleet homes (BRIEF Fleet rule, checked by the fit script). No barrels or mast-like guns. |
| mini_hammock, mini_lesson, mini_post | Small rest spots where a full camp will not fit | Same pieces at mid height; at least 10 m from the line (MID tier). |
| low_cairn, low_slab, low_tiny | The Watch Butte drop and bare slope fills | Every prop 1.0 m or lower after scale, the `LOW_GROUND_MAX_M` cap for `low_ground_rows` (`park_props.gd`, DRESSING-KITS.md "Low ground in area rows"). |
| lookout_a/b/c | A perch the Dispatcher can stand on, and a weavers' watch landmark | Deck 7.05 m over the foot with a 3.6 m flat deck (PERCH-ANCHOR.md); it is a crib of logs with a roofed or open deck, never a mast, ladder, ramp or gate; TALL tier, 20 m clear of the line and out of route lanes. |

### Numbers and where they come from

- Tris: lookout_deck 15464/15532/15532 at LOD0 against the hero band 6000 to 20000 (`kit.py` BUDGET); LOD1 and LOD2 land in the 40 to 60 percent and 10 to 20 percent bands (manifest `tris`). Other kinds are in the table above, from the manifest.
- Scales: 1.15 to 1.3 on mid pieces came from the round 3 "chunkier" fix list; the explicit 1.0 on low pieces keeps watch_stool b (0.94 m), rabbitbrush b (0.98 m) and dish_stones c (0.74 m) at or under the 1.0 m cap (manifest `height`); lookout_deck is 1.0 so its deck sits at 7.05 m inside the 6 to 10 m perch band (manifest `perch`).
- Style: soft blobs use a bare icosahedron and flat rods to hold the tri budget (crown.py, comments there); the lookout reuses the kit's hard and flat styles.
- Perch coverage: `perch_coverage.gd crown` 23 of 200 before, 61 of 200 after (measured in a scratch tree; the target was 36). Seven `lookout_*` spots; one stands near `gauntlet_net_2` because the ride-row keepouts leave only that pocket within 60 m of the nets.

### Density windows (audit r7) and bare poses

- cannon (34.1, -336.2): filled by the fill spots `crown_mv_*` at (72, -360) and (78, -330) (low_tiny and low_cairn, fitted to the camera cone); the r8 audit no longer lists it.
- floor (9.7, -441.9), sable (8, -476.3), tarn (-32.8, -319.1): no legal spot in view. These samples ride the elevated Watch Butte drop (terrain 108.8, 132.5 and 116.1 m high); the ground within 60 m in the camera cone is either steeper than the 25 degree slope rule or inside a kicker keepout, and level ground beside it is 40 m or more lower, outside the 60 m view. A cone scan of the camera frustum (width 72.5 degree field of view, 60 m, pitch -0.3) found 0 legal cells for each: floor and sable are all `slope` and `line_clear`, tarn is `kicker run-out` of `bajada_lip` plus `slope`. The audit has no arena or camp exemption for them.
- Bare poses in the 12-pose replay: 11 (17.3, -541.0) and 16 (8.1, -416.9) are on the drop (slope and the `bajada_lip` kicker ramp, 0 legal cells in view); 115 (-24.6, 474.1) improved from 3 to more core items (needs 5), where `warden bowl` and `crown_spire` keepouts leave only a thin strip; 208 (124.5, 237.5), the one void pose, stands on the gauntlet platform over a drop, and `home_clear` of the gauntlet_anchor_crew home plus the `gauntlet_west` row block everything level.

Known gaps: the three windows and the poses named above stay bare for those reasons.

### 30 m brief kinds

- Kind: `kite_pennant`. Brief line (KITS.md, crown): keep it at least 30 m from lines, so it does not read as a kite drone. The plan check does not enforce this. The measure is edge distance: `Context.line_distance(centre)` minus the instance radius (the `line_clear` measure in `park_props.gd`), probed with `kind_dist_probe.gd` (scratch, not committed). The target is 30.5 m or more.
- Before: 38 pennants, 10 under 30.5 m. After: 28 pennants, 0 under 30.5 m (the nearest is crown_63 at 30.73 m). The other 28 did not move; their edge_m is unchanged, from 30.73 to 65.39 m.
- Fix: the ten short spots keep their other props and use a template copy without the pennant (the file schema has per-template props only, no per-spot override; `park_props.gd` expand). No spot moved, so no `near` label changed.

| Spot | edge_m before | Change | edge_m after |
| --- | --- | --- | --- |
| crown_07 | 22.58 | pennant dropped (template `*_nokite`) | none left |
| crown_20 | 17.84 | pennant dropped (template `*_nokite`) | none left |
| crown_27 | 21.55 | pennant dropped (template `*_nokite`) | none left |
| crown_35 | 23.03 | pennant dropped (template `*_nokite`) | none left |
| crown_43 | 26.59 | pennant dropped (template `*_nokite`) | none left |
| crown_55 | 26.80 | pennant dropped (template `*_nokite`) | none left |
| crown_80 | 28.01 | pennant dropped (template `*_nokite`) | none left |
| crown_90 | 27.92 | pennant dropped (template `*_nokite`) | none left |
| crown_98 | 21.20 | pennant dropped (template `*_nokite`) | none left |
| crown_102 | 22.16 | pennant dropped (template `*_nokite`) | none left |

Pin before 2069366017, after 2441257203; plan check 0 violations (1057 instances).

### Base line and plan check (22 October 2026)

Foundation `be6189ec` (lineclear, e72fff7d plus a stage f259e8cf merge) and stage `origin/stage/alpha-w18` f259e8cf are both ancestors of this branch: stage merged at 9d3b53f3, lineclear first at d3ebc525 and again, at be6189ec, at 376a90f2 (merge commits only). ART-MISTAKES.md matches the stage version (diff empty). `park_props_plan --check`: 1034 instances (109 litter), 0 violations, fingerprint 2154852281, which is the new pin (it was 533729188). The pin moved because one spot was added (below); the recolour changes GLB colours only, not placement.

### Spot added for the floor window (22 October 2026)

`crown_fb_01`, template `floor_brush` (one `rabbitbrush` b at scale 0.85), at (-18.75, -398.75), the cell the audit probe found for the floor window (9.7, -441.9). Story: "One rabbitbrush the net-weaver crews leave standing on the one scrap of legal ground beside the floor line, a patch of green in the dust the giant machines roll past." I fitted 576 two-prop variants (fulgurite, tally_slab, rabbitbrush, yucca, dish_stones, watch_stool within 3 m, scales 0.85 and 1.0); only the brush alone passes `check_one` (the kicker keepout within 4.6 m and the 25 degree slope exclude the rest), so the window can reach one kind in view, not three.

### Telegraph zones

Rule: `park_props.gd` `check_one` keeps props out of each event's site box grown by `hold_clear_m`, lightning strike circles and industrial `hazard_m` circles (DRESSING-KITS.md). On the merged head 82 instances failed it, all in two events: `meander_flash_flood` (hold 20 m, 60 instances in 11 spots) and `split_spire_strike` (hold 30 m on a 50 by 50 m site, a 55 m half box, 22 instances in 5 spots). No lightning circle or industrial hazard circle held an instance. Spots moved by the smallest legal distance found by script (old to new `at`): crown_46 (155.6,-114.0) to (161.6,-114.0); crown_69 (-30.0,102.0) to (-24.8,105.0); crown_23 (74.0,-258.0) to (65.0,-242.4); crown_32 (74.0,-210.0) to (62.0,-210.0); crown_63 (-54.0,38.0) to (-64.4,44.0); crown_05 (146.0,-338.0) to (156.4,-344.0); crown_53 (122.0,-50.0) to (111.6,-44.0); crown_39 (74.0,-154.0) to (56.0,-154.0); crown_67 (18.0,78.0) to (18.0,102.0); crown_66 (-14.0,70.0) to (-20.3,129.7); crown_mv_07 (78.0,-330.0) to (96.0,-361.2); crown_14 (74.0,-298.0) to (32.4,-274.0); crown_61 (-22.0,14.0) to (-15.5,-39.6); crown_20 (144.0,-266.0) to (216.0,-266.0); crown_33 (144.0,-210.0) to (57.6,-184.6); crown_43 (144.0,-114.0) to (144.0,-18.0). The `near` label was updated for the ones that moved more than 20 m. Litter dropped by the rule: 24 (133 to 109). The props stay clear of telegraphs because every authored instance passes the rule in the plan check.

Spots that moved more than 30 m (new nearest row from the spot's `near` label, whether the story still reads):

| Spot | Move | New nearest row | Story still reads there? |
| --- | --- | --- | --- |
| crown_43 | 96 m, to (144.0, -18.0) | `east_ribs` | Yes: a lightning scar with a lantern beside a ribbed rock row reads as a place the storm walked. |
| crown_33 | about 90 m, to (57.6, -184.6) | `meander` | Yes: a fallen loom left to the brush suits a wash. |
| crown_20 | 72 m, to (216.0, -266.0) | `kick_emid_1` | Mostly: a mending lesson beside a kicker is plausible, but it sits far from camp gear (stills review). |
| crown_66 | about 60 m, to (-20.3, 129.7) | `spire_top_ramp` | Weak: a one-hammock rest "mid-climb" fits a ramp, but the old spot was on the Watch Butte approach (stills review). |
| crown_61 | about 55 m, to (-15.5, -39.6) | `hoodoo_9` | Yes: a stool and lantern on a rock by a hoodoo reads as a watch point. |

### 30 m brief kinds (enforced)

`kite_pennant` now carries `line_clear_m: 30` in `crown.py` and the manifest (the GLBs are byte-identical; only the manifest line and the recipe line changed), so the plan check enforces the 30 m edge distance and the earlier probe-only measure is no longer needed.

### Audit (final, 22 October 2026)

Ruling 6329579296: an `--open` window carries a reason the audit checks (`no_cell` is checked against a probe of every variant at every placement scale; `runout:<kicker>` against the kicker run-out). Run: `--open=9.7:-441.9:10:no_cell --open=8:-476.3:10:no_cell --open=-32.8:-319.1:10:runout:bajada_lip`, out `artifacts/local/w18f` (not committed; llvmpipe, a proxy and not a frame-cost proof).

| Measure | Value |
| --- | --- |
| density windows | 41: 25 pass, 15 exempt (arena 6, telegraph 7, open:no_cell 1, open:runout 1), 1 fail |
| `density_open_checked` | 3 |
| `density_open_rejected` | 1 (floor 9.7/-441.9) |
| draw delta (props only) | max 63, median 20.5 |
| draw_calls | max 547, median 458.5 |
| bare share | 34.4% |
| void poses | 2 |

Rejected window: floor (9.7, -441.9), reason `no_cell`. The probe's `why`: "probe rabbitbrush/b@0.85 has a legal cell at (-18.8, -398.8) in the view frustum (48 probe variants ...)". I placed that rabbitbrush (`crown_fb_01`), but the probe tests the empty cell, so it still reports it, and the window has one kind in view (needs three). No other cell exists, so this is a tool-semantics question for the coordinator. The other two windows were accepted (sable `no_cell`, tarn `runout:bajada_lip`).

Bare poses kept as named: 11 (17.3, -541.0) and 16 (8.1, -416.9) are on the Watch Butte drop (slope and the `bajada_lip` kicker keepout, no legal cell in view); 208 (124.5, 237.5) is on the gauntlet platform where `home_clear` and `gauntlet_west` block every level cell.

Smoke: `park_props_test` PASS (226), `park_park_crown_test` PASS (50), `park_dressing_pin_test` PASS (8), `asset_registry_test` PASS; `npm run sketch:lint` 0 findings; `npm run check:docs` pass. `run_tier_test` is base-red: clean stage b0e64a40 fails it the same way at load 17 (8 of 192, child timeouts).

### Reference boards

Boards looked at (all under `docs/art/reference/`): `highdraft/highdraft-props-moodboard.jpg`, `highdraft/highdraft-crew-moodboard.jpg`, `highdraft/highdraft-landmark-cableway-terrace.jpg`, `style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`, `pilots/pilots-balls-heft-moodboard.jpg`. GROUNDING rows are from GROUNDING.md (main cb534a2d).

**Palette roles.** The props board swatch strip is Sandstone `#c6a274`, Oxide `#9b513a`, Charcoal `#242a28`, Petrol `#365754`, Bone `#d2c5a5`, Copper `#b77843`; the style boards add Brass `#d9b44a`, Amber, Mint, Hazard, Ancient, Life. The board's machine bodies are petrol enamel with copper fittings and bone panels, oxide as scrap patches. The kit now follows that (this unit's recolour, `crown.py` `PETROL`, `PETROL_LT`, `COPPER`): booth walls, storm station box and spool barrel are petrol or a lighter shade of it; copper is on the booth stovepipe, the storm station anemometer cap, arms and vane rod, and the spool windings; oxide is two patches on the booth and the locker door and needle on the storm station. Every colour constant and where it maps:

- Petrol `365754` and shade (`PETROL_LT` = petrol x1.3): billing_booth walls, storm_station body, spool_shed barrel. Copper `b77843`: as above. Brass `d9b44a`: the single Fleet tag on billing_booth, storm_station (not c) and spool_shed, and one on tally_slab a; the Materials board labels brass Fleet ownership and VISUAL-LANGUAGE gives Fleet crews one brass requisition tag, so kept.
- Oxide `oxide` and `oxide_dark` (sun-bleached mixes of `9b513a`/`74402f`) and `rust` `8a5a44` (a darker oxide): patches and rings. Charcoal `242a28`, with `iron` `4a4e4c`, `iron_light` `6b706c`, `slate` `2f3634`, `cable` `2a3231`: shades of Charcoal (rubber, seams, outlines on the board). Sandstone `c6a274` with `sandstone_dark`, `sandstone_pale`, `soil` `6a5a42`: Sandstone and its shades. `canvas`, `canvas_dark`, `canvas_stain`, `bone`, `chalk`: Bone `d2c5a5` shades (labels and cloth).
- Not on any swatch (see Board drift): `timber`, `timber_dark`, `timber_pale`, `timber_grey` (loom frames, posts, decks, lines 102 to 859 across 14 kinds); `ochre`, `ochre_dark`, `ochre_pale` (net-weaver rope, lines 128 to 859); `sage`, `sage_dark`, `sage_pale`, `leaf_dark`, `dry_grass`, `flower` (plants, lantern glass and thermos; lines 304 to 871); `concrete`, `concrete_dark`, `concrete_light`, `concrete_stain` (footings, tally slab; lines 213 to 851); `glass`, `glass_dark`, `steam` (lantern glass, fulgurite, steam; lines 374 to 724).

**Shape language.** Broad worn plates and soft toy shapes: the booth and storm station are flat enamel boxes with a few patches, soft blobs for dish stones, stool tarps and hammocks (bare icosahedra, `crown.py` styles `soft`/`round`), ropes as flat coils. No tiny chips: the oxide patches are two boxes, not a scatter.

**Materials.** Brass is used, and only as the Fleet tag (list above); fittings are copper or steel (`iron`), not additional brass. The Old Enamel panel's warm fittings are copper, as the style README requires.

**Scale to the pilot ball.** `Tuning.RADIUS` is 1.0 (`src/movement/tuning.gd`), so the ball is about 2.0 m across; relative to it (manifest heights): loom_frame 4.6/4.6/3.6 is about 2.3/2.3/1.8 balls, billing_booth 4.1 about 2.05, storm_station 4.5/4.5/2.9 about 2.3/2.3/1.5, lookout_deck 9.3/9.1/8.4 about 4.7/4.5/4.2, spool_shed 3.0/3.0/2.1 about 1.5/1.5/1.05, knot_board 1.7/1.2/1.2 under one ball, and every low kind under one ball. The pilots board is relative only; no metres are asserted from it.

**Avoid list (grep of `crown.py` and the manifest).**
- Emission: none (no emissive material, the kit allows one vertex-colour material; the only "glow" hit is a comment saying steam is opaque, line about 660).
- Hazard stripes or coral (`ff5a3c`): none; `kit.py` bans it and a near-miss within 0.08.
- Cache-shaped containers: none (booth, post, spool shed and slabs are not boxes with hatches or lids; the spool is a flat-lying drum under a canopy).
- Taut or decorative grapple cables: none; ropes are slack with sag, or coiled flat.
- Fake ride surfaces: none; lookout deck is a raised plank deck 6 to 10 m up and `hammock_rig` posts stay under 1.5 m.
- Glowing lamps: none; `storm_lantern` is unlit sage_pale or glass_dark glass on charcoal.
- Ancient-green `9dff3c`, mint `8bf0d3`, amber `e5a044`: none in the kit (the greens are dusty sage plant colours).
- Highdraft: the kit has no furnace mouth at all, so none is open or amber; slack nets are hung on lookout, loom and hammock frames (`net()`, ochre), not two-mast netcaster silhouettes (flagged for art review).

**GROUNDING rows read.** Line 231 (Crown Spire with a green beacon): not ours, the kit never touches spires. Line 233 (cableway baskets, ground road stays open): not built; no kit prop crosses the ground road. Line 234 (Conflict, amber furnace glow): not copied; no furnace, no glow. Lines 237 to 239 (net mending, slack bundles, net-repair alcoves): followed by the mending-yard and net-lesson templates, nets are slack and ochre, never in ride lines (plan check). Line 245 (cable baskets and furnace mouths as warm marks): not built. Line 247 (wind-secured mugs and gloves, Look only): not copied, needs Andrew's yes; the thermos and mug are the existing crew warmth.

### Board drift (for review)

- Timber, ochre, sage and plant greens, concrete greys, glass and steam have no swatch on the props board or the style palette. They are the net-weaver and plant colours of the kit's earlier rounds; I did not recolour them in this unit (the instruction was machine bodies only). Kinds and lines are in the Palette roles list above. Brass is on the style palette but is used as the single Fleet tag only.
- The loom_frame is tagged `machine` but is timber and rope, so it has no petrol; it is the net-weavers' own craft (the board shows hand rope and timber around the machines).
- Petrol `365754` is dark against the dusk ground; the previews show the booth and storm station reading as dark silhouettes against the pale props. A stills review should check them in the park at dusk.

### ART-MISTAKES entries checked

Read all rows of `project-guide/handoff/ART-MISTAKES.md`. Applied: 2026-10-21 World #242 "Read the function before describing what a flag means" (I read `check_one` for the telegraph and line_clear_m rules before moving spots); 2026-10-21 Coordinator #222 "Measure a number at the moment it applies" (the plan check on the merged head is the authority, not the earlier PASS); 2026-10-21 Coordinator #231 and #234 "check the last gate's drop list before stacking" (merged the current stage and re-ran the plan check). My own rows from this lane (audits outside the lock, the `P()` scale argument, `expand()` resetting the low rows) were re-read before this unit.
