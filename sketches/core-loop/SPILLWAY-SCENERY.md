# Spillway scenery slice VD-02-A1

> **Historical single-unit receipt:** External heightfield scenery slice; superseded by the 1.6 km `park_dam` layout in [PARK.md](design-v3/PARK.md).

The downstream dam and sandstone shoulders extend Style A's regional silhouette beyond the existing playable Spillway. Cottonwood-like crowns sit on external rock shelves, with denser clusters toward the basin end. This is distant scenery; the terrain remains an enclosed heightfield. It does not implement the layered pinball map or a new river route.

`src/presentation/spillway_scenery.gd` builds seven opaque mesh batches under stage 1's geometry root. One setup hook in `src/game.gd` attaches them. Stage parking supplies visibility and lifecycle. There are no colliders, navigation nodes, scripts on scene nodes, frame callbacks, emission, decorative shadows or edits to map, camera, warnings, attachment faces or terrain vertices. No StageMap prop helpers are used because those create colliders.

All transformed triangle AABBs must lie wholly outside the actual x/z ±200 terrain square, including canopy crowns and rock overhangs. Repeated primitive meshes are combined once per shared material during setup. The focused headless test reads the resulting mesh vertices and checks this, allowed node types, material settings, triangle count and stage 1 → stage 2 → stage 1 → arena → stage 1 visibility. Seven single-surface combined meshes imply seven base geometry submissions before renderer-specific passes; actual draw calls and frame time remain unmeasured. The generated geometry contains 7,968 triangles in seven batches. The provisional incremental ceiling is 25,000 triangles and 20 draw calls.

## Parent visual and performance review

Composition assumptions: the existing downstream rim hides the dam foot; a 120 m wall crest and 175 m tower tops remain visible above it from the spawn deck. Side rock crowns extend the silhouette of existing canyon walls. Their warm matte surfaces and subdued foliage avoid the mint attachment and orange warning vocabulary. These are authored placements, not a native visual acceptance claim.

Capture the default spawn/downhill view, beacon fight with ring and lane warnings, eastern bypass, flooded basin, dense mounted build, stage 2 and boss arena. Check that scenery reads as distant, roots look planted, no near wall or attachment surface is disguised, warnings retain actual elevations and contrast, the dam does not resemble a reachable route, and stage changes leave no scenery behind. Compare equal camera/build/load frame samples with scenery on and off. If the existing rim hides too much scenery, revise external placements; do not lower the rim or change the camera for this slice.

Focused check (repository root):

```sh
XDG_DATA_HOME=/tmp/scrapkeep-vd02-data /home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path sketches/core-loop --script res://tests/spillway_scenery_test.gd
```

Native rendering, measured performance, whole-sketch smoke and human acceptance belong to the parent integration gate. This receipt is structural only.

## Stage-1 placement hold for the v3 fun lab

As of 28 September 2026, hold further Spillway scenery placement until the coordinator supplies the merged base containing `proto/core-loop-v3-lab` and `proto/core-loop-v3-interact`. Reserve the Warden bowl rim and route to the top shelf for the steam lift; both chute mouths and their trajectories toward the Warden mast for the amber kicker lips; the east line for the ambush altar; the area behind the vault plinth for the cracked wall and cache; and Moss's cradle surroundings for the double-or-nothing crate.

The existing exterior scenery remains unchanged and subject to its x/z ±200 exclusion invariant. That bound does not establish clearance or visual readability against the unmerged v3 geometry. On the refreshed base, check the new routes, destinations and interaction sightlines before revising placement. Do not infer exact footprints from the v2 map.

Warden dome open/closed states and the reactor crater are deferred appearance work. Read the lab's published state contract after integration before adapting their look. The lab leaves `hero_assets.gd`, `warden_look.gd`, `palette.gd` and terrain sky/material code untouched.
