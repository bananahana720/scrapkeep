# Crown (`park_crown`) dressing kit

> **Historical wave-18/20 dressing receipt:** Live prop placement and pins live in `sketches/core-loop/src/world/park/props/park_crown.json`, `sketches/core-loop/tests/fixtures/pins/park_crown.pin`, and [DRESSING-KITS.md](../DRESSING-KITS.md).

Dressing lane (DRESSING-KITS.md): the Blender kit and its placement. Recipe `tools/blender/park/props/crown.py`; GLBs, `manifest.json` and import stubs under `assets/models/park/props/crown/`; registry rows in `assets/registry.d/park_props_crown.json` (the Gate lane folds `registry.json`). Placement is in `src/world/park/props/park_crown.json`.

## What and why

The giant machines of Highdraft are the humans' utility fleet (construction, mining, manufacturing), per Andrew's machine ruling (#241): some are corrupted, some are loyal drones, some are looping workers. The crew sites in this kit read as plush crews living among working giants, so the scale contrast is the point: small ochre rope and petrol-enamel gear at the feet of tall machines and spires. These are working machines, never weapons. Brief: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269); where it is absent on this branch, the lane's KITS.md copy was read.

The kit tells two stories. The net-weavers are non-hostile builders, so only their gear appears (ochre rope, nets, hammocks, a loom, mending baskets), never a face or a creature. The Fleet signal crew's gear has petrol enamel `#365754` bodies, copper `#b77843` fittings, iron oxide `#9b513a` on patches, shutters, doors and the dial needle, and at most one brass tag per site, and is drawn as abandoned equipment: a hut, a weather post, a flat-lying cable spool and a tally slab, with no barrels and no gun-like masts. The ancient spires are never touched. Props use pale canvas, ochre rope, dusty sage and charcoal so they separate in value and hue from the red-orange sandstone ground, which sits close to HAZARD in hue. Brass is `#d9b44a`, used only on the Fleet tags.

| Kind | Class | LOD0 tris (a/b/c) | Height m | Tags | Story |
| --- | --- | --- | --- | --- | --- |
| `loom_frame` | hero | 11312/9768/8952 | 4.6/4.6/3.6 | machine,soft,tall | Net-weavers' floor loom: chunky bobbins on the bed and a half-woven ochre net in a leaning frame. |
| `billing_booth` | hero | 11096/11296/9976 | 4.1/4.1/4.1 | machine,sign,tall | Fleet signal crew's tally hut: faded petrol-enamel walls patched with oxide and timber, a chalkboard counting ELEVEN against TWELVE, abandoned mid-shift. |
| `storm_station` | hero | 16092/16264/8752 | 4.5/4.5/2.9 | machine,sign,tall | Fleet weather post on a squat plinth: cup anemometer, and a big barometer dial whose needle sits on STORM: YES. |
| `lookout_deck` | hero | 15464/15532/15532 | 9.3/9.1/8.4 | soft,tall | Net-weavers' log-crib lookout: lashed logs and fieldstone holding a roped plank deck (the perch, 7.05 m up), a net over the rail, a lean-to cloth that is up, half down, or gone. |
| `hammock_rig` | prop | 2328/2448/2284 | 1.4/1.4/1.4 | soft | Net-weavers' low hammock on two short posts, a blanket still in it; run down, it sags to the dust. |
| `knot_board` | prop | 2940/1752/2032 | 1.7/1.2/1.2 | soft | A mending basket of spare net and a knot board with sample splices, set down mid-lesson. |
| `spool_shed` | prop | 2980/2980/2484 | 3.0/3.0/2.1 | machine | A Fleet cable spool lying flat under a four-post canopy, its brass tag (a and b; c is the collapsed canopy and carries none) the only mark of owner. |
| `fulgurite` | prop | 1576/1696/1436 | 0.7/0.4/0.3 | - | Where lightning struck sand: pale glass tubes branching half-buried in a scorched sand scar, a bent rod lying by. |
| `watch_stool` | prop | 1500/1188/1380 | 1.5/0.9/1.4 | soft | A lookout's stool with a tarp slung over it and a thermos left on the seat: someone is coming back. |
| `dish_stones` | prop | 2580/2880/2532 | 1.6/0.4/0.7 | - | Three smooth palm dishes where someone sets a morning drink: one still steaming, one cold. |
| `rope_fence` | prop | 2060/1948/1364 | 1.2/1.3/1.3 | - | A short net-weaver rope fence between two stout posts, knotted with cloth tags, marking a mending spot. |
| `storm_lantern` | prop | 1300/1380/1156 | 1.5/1.5/1.0 | - | An unlit storm lantern hung on a short crook post, waiting for the dark to come. |
| `tally_slab` | prop | 2492/2236/2208 | 1.8/0.3/1.0 | sign | A slate tally slab the signal crew scratched with chalk: forty tallied, forty-one just begun. |
| `rabbitbrush` | prop | 2736/1812/2944 | 1.7/1.0/1.6 | plant | Dusk-flowering rabbitbrush, a sage-green clump with dusty yellow plumes; in c it has grown up through a fallen iron wheel. |
| `yucca` | prop | 2644/824/2994 | 2.4/1.6/2.1 | plant | A yucca rosette with a tall cream flower stalk; the dry one is winter-bare, the third grows through a flat gear plate. |
| `kite_pennant` | prop | 2088/2088/1492 | 1.8/1.5/0.6 | - | A crew pennant on a thick stake in a cairn: out in the wind, slack, or on the ground after the gale. |
| `clock_post` | prop | 2584/2280 | 2.6/2.5 | machine,sign | The watch crew's time clock on one post under a shingled hood; the card rack is full, 01 to 04 and FOREMAN, every card fresh. |
| `glove_bench` | prop | 1436/1668/952 | 0.5/0.6/0.5 | soft | A crew bench with a fresh pair of work gloves set out for every shift; nobody draws them. |
| `shift_board` | prop | 860/972 | 1.2/1.2 | sign | Sandwich shift board: FOREMAN column chalked MIND, the HANDS column wiped clean every morning. |
| `lost_glove` | prop | 368/480 | 0.2/0.2 | soft | A work glove dropped on a flat stone, fingers half curled; in b its pair lies beside it. |

Variants run a (in use), b (run down), c (collapsed or overgrown). Notes on swaps and reviews:

- `hammock_rig` posts stay under 1.5 m; `spool_shed` is a two-sided gabled canopy with gable boards (a single sloped plane reads as a ramp); `billing_booth`'s "ELEVEN / TWELVE" is chalk tally strokes (eleven and twelve) because the kit cannot carry text; the `storm_station` "STORM: YES" is a needle on the STORM end plus a three-stroke label slab.
- Fleet gear is weathered: petrol-enamel bodies (`crown.py` :221 and :243 give a lighter shade of the same petrol, `PETROL_LT`, on every fifth plank of the back and front walls, and :227 on every fourth plank of the side walls), three timber patches on the booth (:229-231) and two oxide patches (:246-247), copper fittings (booth stovepipe :260, storm station anemometer and vane :340, :345, :351, spool windings :567), with a stove-in panel and sagging roof on b and c, and an irregular fieldstone footing under the storm station. Its mast is short (about 4.5 m overall) with a cup anemometer and a wind vane, so it cannot read as a signal mast or turret.
- `fulgurite` is irregular branching pale-glass tubes in a sand scar with a short bent rod beside them: no radial symmetry, no disc, no knobbed stake (those read as a trap or mine).
- `loom_frame` leans back and carries an awning so it does not read as a two-post gate. Plants-through-scrap are `rabbitbrush_c` (iron wheel) and `yucca_c` (gear plate). Crew warmth: hammock blanket, thermos on a stool, mug and laundry at the booth, steaming dish stone.
- Keep `kite_pennant` 30 m from lines.

## All hands (23 October 2026)

The Mind's through-line (DECISIONS 18 Oct: the crew were its hands, numbers 01 to 04 plus FOREMAN) had no prop in the crown. Four kinds carry it: `clock_post` (the crew's time clock on one post, five cards in the rack, FOREMAN the wide slot; b is storm-struck with the hood blown off), `glove_bench` (a fresh pair set out per shift), `shift_board` (MIND chalked under FOREMAN, the HANDS column a tally) and `lost_glove`. All four are props, not heroes: the kit already carries four hero kinds against DRESSING-KITS.md's 2 or 3. The clock post stands on one round post so it never reads as a two-post gate.

Three vignettes, appended after the 156 existing spots (which are unchanged): `hands_clock_in` (24, -140) on the bajada below the signal camp, `hands_struck_clock` (-68, 260) on the west climb under the needle strikes, `hands_glove_rest` (38, 412) on the crown approach. Nothing is on `drop_ramp`. Plan `--check`: 1,047 instances, 0 violations; pin 2080508897.

## Placement (21 October 2026, round 5)

`src/world/park/props/park_crown.json`: 24 templates, 155 spots, 925 vignette instances plus 109 litter (1034 in all), pinned (542438207; 2154852281 before the brass-per-site variant swaps, 533729188 before the floor-window spot, 2441257203 before the telegraph pass). Low vignettes stand 8 to 16 m off the line, mid ones to 40 m, heroes 24 to 60 m. Fleet templates stand only at Fleet-row points at least 60 m from `camp_signal` and the Fleet homes; nothing is within 75 m of the alcove ledge; the spires and Content greybox rows are untouched. Spots were fitted by script against `validate` (`park_props.gd` check_one), not hand-picked; plan `--check` reports 0 violations.

### Purpose and why each template reads

Each template's `story` line in the file says what it is and which moment it shows. Why they read without blocking a line or a telegraph, and what was checked:

| Template | Moment it serves | Why it reads and clears the line |
| --- | --- | --- |
| mending_yard, weaver_boneyard, hammock_camp, net_lesson, watch_post, lightning_scar | The net-weavers' working slope beside the ride | Ochre rope, nets and hammocks against the red-orange sandstone (KIT palette in DRESSING-KITS.md); heroes stand 24 m or more from a line and out of route lanes (TALL tier), low pieces 6 m or more (LOW tier), all by `validate`. |
| abandoned_booth, dead_weather_post, cable_corner, log_post, log_post_nokite, low_slab | The Fleet signal crew's abandoned equipment | Petrol enamel, copper fittings, oxide patches, at most one brass tag per site (`crown.py` :300 booth, :326 storm station a and b, :573 spool shed a and b, :775 tally slab a; each of these templates carries at most one of them), never in a camp: at least 60 m from `camp_signal` and the Fleet homes (BRIEF Fleet rule, checked by the fit script). No barrels or mast-like guns. |
| mini_hammock, mini_lesson, mini_post | Small rest spots where a full camp will not fit | Same pieces at mid height; at least 10 m from the line (MID tier). |
| low_cairn, low_slab, low_tiny | The Watch Butte drop and bare slope fills | Every prop 1.0 m or lower after scale, the `LOW_GROUND_MAX_M` cap for `low_ground_rows` (`park_props.gd`, DRESSING-KITS.md "Low ground in area rows"). |
| lookout_a/b/c | A perch the Dispatcher can stand on, and a weavers' watch landmark | Deck 7.05 m over the foot with a 3.6 m flat deck (PERCH-ANCHOR.md); it is a crib of logs with a roofed or open deck, never a mast, ladder, ramp or gate; TALL tier, 20 m clear of the line and out of route lanes. |

### Numbers and where they come from

- Tris: lookout_deck 15464/15532/15532 at LOD0 against the hero band 6000 to 20000 (`kit.py` BUDGET); LOD1 and LOD2 land in the 40 to 60 percent and 10 to 20 percent bands (manifest `tris`). Other kinds are in the table above, from the manifest.
- Scales: 1.15 to 1.3 on mid pieces came from the round 3 "chunkier" fix list; the explicit 1.0 on low pieces keeps watch_stool b (0.94 m), rabbitbrush b (0.98 m) and dish_stones c (0.74 m) at or under the 1.0 m cap (manifest `height`); lookout_deck is 1.0 so its deck sits at 7.05 m inside the 6 to 10 m perch band (manifest `perch`).
- Style: soft blobs use a bare icosahedron and flat rods to hold the tri budget (crown.py, comments there); the lookout reuses the kit's hard and flat styles.
- Perch coverage: `perch_coverage.gd crown` 23 of 200 before, 61 of 200 after (measured in a scratch tree; the target was 36). Seven `lookout_*` spots; one stands near `gauntlet_net_2` because the ride-row keepouts leave only that pocket within 60 m of the nets.

### Density windows (audit r7) and bare poses

Superseded by "Spot added for the floor window" and "Audit (final, 22 October 2026)" below: the floor window's first legal cell was filled by `crown_fb_01` (the `no_cell` probe stops at the first cell and never counted the rest; #323's `filled:` probe found a second, filled in "w18m row fixes" below), and stays a documented fail (ruling 6332450092). This section is the r7 record.

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

Foundation `be6189ec` (lineclear, e72fff7d plus a stage f259e8cf merge) and stage `origin/stage/alpha-w18` f259e8cf are both ancestors of this branch: stage merged at 9d3b53f3, lineclear first at d3ebc525 and again, at be6189ec, at 376a90f2 (merge commits only). ART-MISTAKES.md matches the stage version (diff empty). `park_props_plan --check`: 1034 instances (109 litter), 0 violations, fingerprint 542438207, which is the pin in `park_crown.json`. It moved from 533729188 to 2154852281 when one spot was added (below), then to 542438207 when tally_slab a became c in `abandoned_booth` and `cable_corner` and the spool_shed c tag was removed (at most one brass tag per site); the recolour changes GLB colours only, not placement.

### Spot added for the floor window (22 October 2026)

`crown_fb_01`, template `floor_brush` (one `rabbitbrush` b at scale 0.85), at (-18.75, -398.75), the cell the audit probe found for the floor window (9.7, -441.9). Story: "One dry rabbitbrush clump the net-weaver crews leave standing on the one scrap of legal ground beside the floor line, a gray-brown tuft in the dust the giant machines roll past." (Variant b is the dry winter brush.) I fitted 576 two-prop variants (fulgurite, tally_slab, rabbitbrush, yucca, dish_stones, watch_stool within 3 m, scales 0.85 and 1.0); only the brush alone passes `check_one` (the kicker keepout within 4.6 m and the 25 degree slope exclude the rest), so the window stays at one kind in view, not three (a documented density fail, see Audit). Correction (w18m): this was not the only legal cell. The `no_cell` probe stops at the first cell and never counted them; the template story's "one scrap" was stale, so the coordinator reworded it in 7f7ee982 to "the few scraps of legal ground".

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

Ruling 6329579296: an `--open` window carries a reason the audit checks (`no_cell` is checked against a probe of every variant at every placement scale; `runout:<kicker>` against the kicker run-out). Ruling #241 (6332450092): the floor window (9.7, -441.9) is a documented density fail, with no `--open` arg, so no false reason ships. Run: `--open=8:-476.3:10:no_cell --open=-32.8:-319.1:10:runout:bajada_lip`, out `artifacts/local/w18g` (not committed; llvmpipe, a proxy and not a frame-cost proof).

| Measure | Value |
| --- | --- |
| density windows | 41: 25 pass, 15 exempt (arena 6, telegraph 7, open:no_cell 1, open:runout 1), 1 fail |
| `density_open_checked` | 2 |
| `density_open_rejected` | [] |
| draw delta (props only) | max 61, median 22.0 |
| draw_calls | max 563, median 433.5 |
| bare share | 34.4% |
| void poses | 2 |

The one density fail is the floor window (9.7, -441.9), 1 kind in view. Its first legal cell, found by the probe (rabbitbrush/b at scale 0.85, (-18.8, -398.8)), is filled by `crown_fb_01`. The probe stops at the first cell, so it never counted the cells; #323's `filled:` probe found a free legal cell at (-16.25, -398.75) too (see "w18m row fixes" below). Nothing else fits there: the kicker keepout (4.6 m) and the 25 degree slope bound every other cell, and 576 two-prop variants all failed `check_one`. The sable (`no_cell`) and tarn (`runout:bajada_lip`) windows were accepted.

Bare poses kept as named: 11 (17.3, -541.0) and 16 (8.1, -416.9) are on the Watch Butte drop (slope and the `bajada_lip` kicker keepout, no legal cell in view); 208 (124.5, 237.5) is on the gauntlet platform where `home_clear` and `gauntlet_west` block every level cell. The audit's second void pose is sample 143 (-32.8, -319.1), the tarn window, inside the `bajada_lip` run-out (its `--open` reason above).

Smoke: `park_props_test` PASS (226), `park_park_crown_test` PASS (50), `park_dressing_pin_test` PASS (8), `asset_registry_test` PASS; `npm run sketch:lint` 0 findings; `npm run check:docs` pass. `run_tier_test` is base-red: clean stage b0e64a40 fails it the same way at load 17 (8 of 192, child timeouts). Fast lane: `sketch:fast --base origin/stage/alpha-w18` passes on 8fdd9ad2 (merge base f259e8cf) in 910 s, 73 run, 0 flaky, 0 base-red, `visible_odds_test` 118.5 s; the earlier run's `visible_odds_test` timeout came at load above 7. The later head changes this note only.

### Reference boards

Boards looked at (all under `docs/art/reference/`): `highdraft/highdraft-props-moodboard.jpg`, `highdraft/highdraft-crew-moodboard.jpg`, `highdraft/highdraft-landmark-cableway-terrace.jpg`, `style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`, `pilots/pilots-balls-heft-moodboard.jpg`. GROUNDING rows are from GROUNDING.md (main cb534a2d).

**Palette roles.** The props board swatch strip is Sandstone `#c6a274`, Oxide `#9b513a`, Charcoal `#242a28`, Petrol `#365754`, Bone `#d2c5a5`, Copper `#b77843`; the style boards add Brass `#d9b44a`, Amber, Mint, Hazard, Ancient, Life. The board's machine bodies are petrol enamel with copper fittings and bone panels, oxide as scrap patches. The kit now follows that (this unit's recolour, `crown.py` `PETROL`, `PETROL_LT`, `COPPER`): booth walls, storm station box and spool barrel are petrol or a lighter shade of it; copper is on the booth stovepipe, the storm station anemometer cap, arms and vane rod, and the spool windings; oxide is two patches on the booth front (:246-247), the booth's window shutters (:288, `oxide_dark`) and side door (:302), and the storm station's locker door (:325) and needle (:367). Every colour constant and where it maps:

- Petrol `365754` and shade (`PETROL_LT` = petrol x1.3): billing_booth walls, storm_station body, spool_shed barrel. Copper `b77843`: as above. Brass `d9b44a`: one tag each on billing_booth (:300), storm_station a and b (:326), spool_shed a and b (:573) and tally_slab a (:775), never two in one template (`abandoned_booth`, `dead_weather_post` and `cable_corner` were changed to guarantee it: the booth and spool sites use tally_slab c, and the spool shed c has no tag); the Materials board labels brass Fleet ownership and VISUAL-LANGUAGE gives Fleet crews one brass requisition tag, so kept.
- Oxide `oxide` and `oxide_dark` (sun-bleached mixes of `9b513a`/`74402f`) and `rust` `8a5a44` (a darker oxide): patches and rings. Charcoal `242a28`, with `iron` `4a4e4c`, `iron_light` `6b706c`, `slate` `2f3634`, `cable` `2a3231`: shades of Charcoal (rubber, seams, outlines on the board). Sandstone `c6a274` with `sandstone_dark`, `sandstone_pale`, `soil` `6a5a42`: Sandstone and its shades. `canvas`, `canvas_dark`, `canvas_stain`, `bone`, `chalk`: Bone `d2c5a5` shades (labels and cloth).
- Not on any swatch (see Board drift): `timber`, `timber_dark`, `timber_pale`, `timber_grey` (loom frames, posts, decks; lines 102 to 859 across 13 kinds plus the `bobbin` helper at :102-103); `ochre`, `ochre_dark`, `ochre_pale` (net-weaver rope; lines 128 to 860 across 9 kinds); `sage`, `sage_dark`, `sage_pale`, `leaf_dark`, `dry_grass`, `flower` (plants, lantern glass and thermos; lines 304 to 872 across 10 kinds); `concrete`, `concrete_dark`, `concrete_light`, `concrete_stain` (footings, tally slab; lines 213 to 852 across 8 kinds); `glass`, `glass_dark`, `steam` (lantern glass, fulgurite, steam; lines 374 to 725 across 4 kinds).

**Shape language.** Broad worn plates and soft toy shapes: the booth and storm station are flat enamel boxes with a few patches, soft blobs for dish stones, stool tarps and hammocks (bare icosahedra, `crown.py` styles `soft`/`round`), ropes as flat coils. No tiny chips: the oxide is a handful of patch boxes (:246-247, :288, :302, :325) and the dial needle (:367), not a scatter.

**Materials.** Brass is used, and only as the Fleet tag (list above); fittings are copper or steel (`iron`), not additional brass. The Old Enamel panel's warm fittings are copper, as the style README requires.

**Scale to the pilot ball.** `Tuning.RADIUS` is 1.0 (`src/movement/tuning.gd`), so the ball is about 2.0 m across; relative to it (manifest `height` divided by 2.0): hammock_rig 1.352/1.363/1.365 = 0.68/0.68/0.68, knot_board 1.673/1.162/1.163 = 0.84/0.58/0.58, fulgurite 0.661/0.402/0.311 = 0.33/0.20/0.16, watch_stool 1.473/0.941/1.372 = 0.74/0.47/0.69, dish_stones 1.558/0.426/0.737 = 0.78/0.21/0.37, rope_fence 1.239/1.263/1.288 = 0.62/0.63/0.64, storm_lantern 1.528/1.528/1.031 = 0.76/0.76/0.52, tally_slab 1.816/0.309/1.048 = 0.91/0.15/0.52, rabbitbrush 1.741/0.977/1.648 = 0.87/0.49/0.82, yucca 2.354/1.625/2.069 = 1.18/0.81/1.03 (yucca a and c are taller than the ball), kite_pennant 1.782/1.543/0.592 = 0.89/0.77/0.30. The larger ones: loom_frame 4.571/4.579/3.600 = 2.29/2.29/1.80, billing_booth 4.102 = 2.05, storm_station 4.517/4.519/2.927 = 2.26/2.26/1.46, lookout_deck 9.308/9.058/8.401 = 4.65/4.53/4.20, spool_shed 2.982/2.981/2.102 = 1.49/1.49/1.05. The pilots board is relative only; no metres are asserted from it.

**Avoid list (grep of `crown.py` and the manifest).**
- Emission: none (no emissive material, the kit allows one vertex-colour material; the only "glow" hit is a comment saying steam is opaque, `crown.py` :662).
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
- `spool_shed` story (`crown.py` :531, manifest :339) still says "its brass tag the only mark of owner" for all variants, but variant c carries no tag after :572-573; the recipe docstring (:4) still says "one brass tag". A story or docstring fix needs a kit rebuild of the manifest, so it waits for the polish pass; the placement rule (at most one tag per site) holds.
- Petrol `365754` is dark against the dusk ground; the previews show the booth and storm station reading as dark silhouettes against the pale props. A stills review should check them in the park at dusk.

### ART-MISTAKES entries checked

Read all rows of `project-guide/handoff/ART-MISTAKES.md`. Applied: 2026-10-21 World #242 "Read the function before describing what a flag means" (I read `check_one` for the telegraph and line_clear_m rules before moving spots); 2026-10-21 Coordinator #222 "Measure a number at the moment it applies" (the plan check on the merged head is the authority, not the earlier PASS); 2026-10-21 Coordinator #231 and #234 "check the last gate's drop list before stacking" (merged the current stage and re-ran the plan check). My own rows from this lane (audits outside the lock, the `P()` scale argument, `expand()` resetting the low rows) were re-read before this unit.

### w18m row fixes and floor-window fill (card (b), #323)

The new scan (#323) found 8 row groups in crown and no yaw groups. I moved 12 spots off their lines, 11 of them now 2 m or more from their old line (crown_mv_08's own sideways move is 1.61 m; it started off the line). crown_16 stays 0.68 m from its line and clears the rule only through the spacing change (CV now 0.1 or more), kept every template and `near` (the one story change is the `floor_brush` rewording above), and left all yaws alone. No move created a yaw group, and the lint stays at 0.

| spot | old `at` | new `at` |
|---|---|---|
| crown_07 | (117, -376.8) | (117, -373.8) |
| crown_13 | (18, -298) | (18, -294.5) |
| crown_16 | (-6, -290) | (-6, -286.5) |
| crown_73 | (-6, 126) | (-9, 126) |
| crown_mv_06 | (110, 290) | (110, 293) |
| crown_mv_08 | (26, 500) | (26, 503) |
| crown_lo_13 | (46, -714) | (46, -717) |
| crown_lo_12 | (86, -658) | (82.5, -658) |
| crown_lo_05 | (62, -586) | (62, -589) |
| crown_lo_10 | (-2, -658) | (-5.5, -660) |
| crown_lo_11 | (-2, -698) | (-5.5, -698) |
| crown_lo_15 | (-2, -594) | (-5.5, -594) |

The nine-spot low-ground group (crown_lo_03 to 17) is broken by moving lo_05, lo_10, lo_11 and lo_15, so no three of its spots stay on a line with even gaps. Several first tries failed `line_clear` (lo_13, lo_10, lo_15, lo_05, crown_73) and were moved the other way. Each of the 8 groups lost at least one spot from its line; the other spots did not move.

Floor window (9.7, -441.9): #323's `filled:` probe found a free legal cell at (-16.25, -398.75). I added `crown_fb_02`, template `floor_brush`, yaw 90, `near` "floor line, net-weaver gear", at that cell; it passes the plan check. It is the same single kind as `crown_fb_01`, so the window still sees 1 kind and stays a documented density fail (ruling 6332450092). The `filled:` claim was then run on this branch (22ac117f) merged with #323 at af522720, in a scratch tree: `--open=9.7:-441.9:10:filled:-16.25:-398.75` is rejected with the next free legal cell at (-13.75, -398.75), 2.5 m further east (llvmpipe audit, `density_open_checked` 3, the other two windows accepted). The legal ground beside the floor line runs on east in 2.5 m cells, so filling it one brush at a time would build a new row of identical brushes. The window stays a documented density fail (ruling 6332450092) with no `--open` arg; dressing that strip with three kinds is a separate card.

With two brush spots on the floor, the `floor_brush` story now reads "the few scraps of legal ground" instead of "the one scrap of legal ground". The story is not in the fingerprint, so the pin is unchanged. The quote in "Spot added for the floor window" above is the old text, kept as the record.

Results: pin 3161838182 (was 542438207). The new check, run with `--file` on this copy in a tree holding the scan code, reports 0 violations, 0 pattern, 0 pin, 0 lint. The old check reports 0 violations, same fingerprint. `park_props_test` passes. The density audit gives 41 windows: 25 pass, 15 exempt (arena 6, telegraph 7, open:no_cell 1, open:runout 1), 1 fail, the same as before; `density_open_checked` 2, `density_open_rejected` none.

#### Round 2: long-span rows and parallel columns (#323 af522720)

The row rule had skipped line-defining pairs over 40 m, though card 1 caps only the gaps. With the fix, crown failed on two more rows: (crown_lo_03, 05, 08) and (crown_lo_04, 09, 11). The verifier also noted that my x = -2 column had become two parallel lines 3.5 m apart, and that lo_23, lo_14 and lo_07 still sat on x = 86. I gave the spots varied offsets of 2 to 6 m, with no two moved spots sharing an x within 1 m. Yaws, templates and `near` are unchanged.

| spot | old `at` | new `at` |
|---|---|---|
| crown_lo_03 | (30, -578) | (33, -575) |
| crown_lo_08 | (-2, -570) | (-6.5, -568) |
| crown_lo_09 | (-50, -650) | (-53.5, -651) |
| crown_lo_10 | (-5.5, -660) | (-2.2, -664) |
| crown_lo_11 | (-5.5, -698) | (-9, -702) |
| crown_lo_14 | (86, -610) | (84, -607) |
| crown_lo_15 | (-5.5, -594) | (-10.6, -596) |
| crown_lo_17 | (-2, -618) | (-7.6, -616) |
| crown_lo_23 | (86, -578) | (91.5, -580) |
| crown_lo_33 | (-2, -746) | (-5, -746) |

crown_lo_07 stays at (86, -634) in this round (superseded by the follow-up below). Every move I tried for it failed the plan check (`line_clear` to the east, `slope` and `seat` or a new row to the west), so only lo_14 and lo_23 left the x = 86 column. Pin 804932062 (was 3161838182). The results are in the hand-back to the coordinator and in the commit message.

Round 2 follow-up: crown_lo_07 moves 7 m south along its column, from (86, -634) to (86, -641). That breaks the loose line it still made with crown_lo_12 and crown_lo_14 (gaps 24.1 and 26.9 m within a 3 m band; the 1.5 m rule did not flag it). So a legal move did exist; the sideways moves still fail `line_clear` or make a new row. crown_lo_10 moves from (-2.2, -664) to (-2.2, -662), which breaks its line with crown_lo_04 and crown_lo_27 (gaps 25.7 and 24.9 m, CV 0.017, within a 2 m band). One loose line is left in the low ground: crown_lo_03, 06 and 29, gaps 29.9 and 25.2 m, CV 0.085, within a 2 m band but not 1.5 m. Yaws, templates and `near` are unchanged. Pin 2071410145 (was 804932062).
