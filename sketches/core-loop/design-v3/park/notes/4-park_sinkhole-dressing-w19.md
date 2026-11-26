# Stage 4, park_sinkhole: fixes for the wave 19 dressing

Written 17 October 2026 from the intent check at `2fce8953` (originally stored in retired `/mnt/project-files/alpha-status/intent-check/results/w16-2fce8953.md`) and a read of `src/world/park/park_sinkhole.json` at the same commit. The check flagged three things: ride facts on 5% of rows, 16 near-identical zip cables and 9 geysers, and 466 placeholders, the most in the game. (Historical wave 19 dressing log; anchor posts and `lava_tube_run` work subsequently integrated.)

## What the numbers really say

- **Ride facts are not missing; the scorecard undercounts them.** The 5% counts rows with an explicit `ride_fact` over all 496 rows, and 339 of those rows are anchor-post fields that never carry one. A tunnel, half-pipe, drop, bowl or flooded cavern gets its family's fact at run time (`park_recipes.gd` `ELEMENT_FACTS`), so 143 of the 157 built rows (91%) fire a ride fact. Only the 14 ground rows and the 10 kickers (launch path, not a fact) have none. Fix in the scorecard: count `row.ride_fact or ELEMENT_FACTS[row.element]` over non-anchor rows. The same dilution puts the society share at 7%; over built rows it is 20% (32 mining rows).
- **The real thinness is one ride fact everywhere.** 73 of the 74 tubes and all 24 tube half-pipes fire the same `ride_chute`. The stage reads as one long chute because, to the systems that score and score music, it is one.

## Fixes for the dressing unit

1. **Swap the tubes onto the landed lava tube kit.** `assets/models/park/lava_tube_run.glb` and its `bend_n30` and `bend_p30` variants are already in the tree. Give the 73 `greybox:tunnel` lava-tube rows `lava_tube_run`, picking the bend by the yaw change to the next row of the same route (within 15 degrees straight, else the matching 30 degree bend). That removes 73 placeholders and gives the roofed half of the line its roof. The colliders change, so re-run the stage's traversal bands (PARK.md 8) and re-pin `tests/park_park_sinkhole_test.gd` in the same unit.
2. **Swap the rest that already have a recipe.** 11 `greybox:flooded_cavern` rows to `cenote_pool` (the west gallery) or `flooded_shaft` (the caisson), and the 10 `greybox:drop` rows in shafts to `shaft_drop`. 21 more placeholders, same band re-run.
3. **Anchor posts.** 339 of the 466 placeholders are `greybox:anchor_field`. PR #32's anchor-post kit (the 877 anchor fields across the parks) clears them in every park at once; land it before counting this stage again. After 1 to 3 and #32 the stage keeps about 33 placeholders (half-pipes, bowls, ledges, the elevated line, the grind line).
4. **Give the four rope sets four different jobs.** Today each of `lava_channel_14`, `main_tube_lower_4`, `east_haulage_4` and `west_breakthrough_6` hangs four parallel ropes 6 m apart at one height and length. Proposed:
   - `lava_channel_14`: keep two ropes, raised and lengthened, as a rope crossing over the lava channel; missing it drops you into the slower channel line, not a dead stop.
   - `main_tube_lower_4`: one long swing rope that throws you out of the tube toward the caisson bowl, the stage's one rope moment that leads to the Warden.
   - `east_haulage_4`: one haulage cable with a moving skip (a `lift` paired with the cable) so the mining crew's line is a working machine, not a gymnastics rig.
   - `west_breakthrough_6`: one rope down through the breakthrough's skylight, a descent rather than a crossing.
5. **Give the nine geysers distinct jobs.** Eight of the nine share radius 5, floor 16, charge 3 s and min flight 2.2 s (the fumarole has radius 3.5), so they read as one machine repeated. Proposed, keeping the count:
   - two exits: `main_tube_upper_vent` and `skylight_chain_vent` throw you out through a skylight to the surface (a skip for the speedrunner, a reveal of the sinkhole's rim for the first-timer);
   - one secret: `east_drift_vent` throws you onto the drift valve's ledge, the way into the shut door;
   - one escape: `west_gallery_vent` fires on the cenote drain's telegraph and lifts you clear of the flood;
   - one combat tool: `main_tube_lower_vent` lands you on the Warden's back in the caisson;
   - the rest pulse on the bar at different charges (2, 3 and 4 s) so a run through them has a rhythm, and `fumarole` stays the cinder cone's long launch.
6. **People.** 32 rows are the mining crew's and none of the tubes say who walked them. With the lamp lines this pass hangs in the adits (dig_scenery.gd park pass), give the adit rows the `mining` society and a fragment each, and give the lava tubes one ancient line (the tube makers) so the stage has two peoples, not none.

## Done in this pass (cheap, no park file edits)

The sinkhole's file is being rebaked on PR #29 (the full gallery ring and the 20 m bowl), so this pass changes no rows. It does dress the stage: the Dig park pass now seats the cut kit along the tubes and adits, hangs lamp lines on the tube and adit walls (the world look's lamp pool lights them), and wires the Dig's grit and lamp flicker effects (`dig_scenery.gd` `build_park`). Three Signal cache spots sit on the caisson bowl, over the gallery ring and on the pump gallery ledge (`tools/radio_cache_spots.gd`); rerun that tool after #29 lands, because the gallery ring (y -107.74) lies under this bake's ground and the bowl floor moves.
