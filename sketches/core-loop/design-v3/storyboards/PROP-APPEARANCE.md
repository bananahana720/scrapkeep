# Stage 1 prop appearance plan

Style A gives these machines cast shoulders, broad enamel wear and readable working parts. The lift's mouth points up, kicker edges point toward takeoff, and a dial marks an explicit cost or pressure. These are appearance proposals for the lab's geometry. No gameplay code or assets were changed.

## Sources and attachment status

Direction is LOOP-REDESIGN at `1589f4f26fd437d65b5d954e2b300bd7f50e673c`, sections 2, 3, 8, 9 and 11 A. ROADMAP row 9 asks for consistent Style A across the game; these boards are one preparation step, not completion of that row.

Read-only lab snapshot `3c219ab564c55ee6c7c0ba6701363f8e9b67e972` exposes `Contraptions/return_lift`, `DropLip_west_chute/Lip` and `DropLip_east_riser/Lip`. The lip holders are world-offset terrain grids, not ready-made local ramp sockets. Their origins have Y=0 and their vertices use sampled ground height. The launcher root stays at the origin while its children use the mouth position. Blindly attaching a centred GLB to either root would misplace it.

At that snapshot, the lab places lips 19 m from the mast to meet its ballistic arc. Follow the merged geometry, never the boards' scenic distances. The inspected interact branch at `43eeeeac5657b386a438975ae369abde9a3f93e1` did not contain `src/world/interactables.gd`; the inspected lab Warden look did not publish dome/crater nodes. Names below marked **requested** are a proposed handoff contract, not claims about implemented nodes.

## Looks, recipes and ceilings

Triangle ceilings cover each complete added visual assembly after all modifiers and triangulation, including hidden moving parts and debris shown simultaneously. They are budgets to verify, not measured counts or runtime performance claims.

| Prop | Style A look and headless Blender recipe | Triangle ceiling | Attachment by name |
| --- | --- | ---: | --- |
| Steam lift | Open flared pressure mouth, two rounded copper cylinders, petrol cradle, bone dial, rubbed rim and solid amber approach trim. Build lathed 16-sided cylinders, bevelled supports and a coarse curved mouth; model the dial needle separately. Keep steam sparse around the exit. | 6,000 | Observed `Contraptions/return_lift`. Request child sockets `VisualMount`, `GaugePivot`, `SteamMouth` in mouth-local coordinates. |
| West kicker | Shallow cast amber lip trim with a bone repair patch and petrol side cheeks. Generate edge ribbons from the actual sampled lip boundary; no replacement flight surface. Broad paint, no hazard stripes. | 1,800 | Observed `DropLip_west_chute/Lip`. Retain grid; add `VisualTrim` beside it using sampled vertices and line direction. |
| East kicker | Same construction, taller curvature supplied by lab data; slightly longer cheek makes the high takeoff legible. Share materials and recipe with west lip. | 1,800 | Observed `DropLip_east_riser/Lip`, same data-driven trim seam. |
| Ambush altar | Copper post with a broad hostile red-orange/charcoal striped cap, dark fasteners and a squat base. Revolve post profile, bevel cap, vertex-colour wear in broad patches. Let source-owned ground ring carry the threat extent. | 2,600 | **Requested** `AmbushAltar/VisualMount`, `Cap`, `PromptAnchor`. |
| Cracked wall and cache | Verdigris concrete slab, one broad charcoal seam, rubbed broken edges and a recessed bone/copper cache. Build slab as a few deterministic polygon pieces, not fracture simulation. Separate intact pieces and cache lid. | 3,600 total: wall 2,400, cache 1,200 | **Requested** `CrackedWall/VisualMount`, `WallPieces`, `HiddenCache/VisualMount`. Keep cache hidden until owner reveals it. |
| Double-or-nothing crate | Stout copper crate, one red-orange/charcoal HAZARD band, bone odds dial, charcoal keyline and worn latches. Bevelled box recipe, 24-sided dial, separate needle and lid. No printed odds until actual value is supplied. | 2,400 | **Requested** `DoubleOrNothingCrate/VisualMount`, `OddsNeedle`, `LidPivot`, `PromptAnchor`. |
| Reactor dome and exposed core trim | Ancient petrol/bone enamel shell imprisoned by Fleet jaws. Two coarse hemisphere shells with thick cut rims, independent hinge pivots, small blue ancient core and class-colour rim. Author one mesh set for all states; detached shell chunks replace their attached copies. | 8,000 combined, both halves, trim and maximum visible shed pieces | Existing `WardenLook` parent; **requested** `ReactorDomeLeft`, `ReactorDomeRight`, `CoreVisualMount`, `ShedPieces`. Keep existing target location and all clamp clearances. |
| Reactor crater | Shallow scorched ceramic/concrete annulus, broad red-orange hot cracks, charcoal keylines. Build low radial strips following supplied floor samples. No raised collision wall, deep pit or tall flame curtain. Warning ribbon stays on the exact committed threat boundary. | 1,200 per active crater | **Requested** `ReactorCrater/VisualMount` plus its radius, floor samples and lifetime. Count each live instance separately. |

One of each row, including both lips and one crater, totals **27,400 triangles**. That excludes existing Warden clamp/body, heroes, world scenery, UI and particle geometry. Concurrent crater count is not known here; the coordinator must provide it before an aggregate ceiling is set. Do not describe 27,400 as the whole scene or Warden budget.

## Anticipation props for the next sitting

These are separate from the immediate greybox dressing. A dormant ally housing can use 4,000 triangles for drone, dial and nest. A mast cage gets 2,000 including its rarity frame and preview rig silhouette. One evolution socket insert gets 600, fitted to a real accretion chunk. These proposed additions total 6,600 triangles before instance multiplication.

The socket uses the paired part's actual family glyph. The cage reuses reward-gate rarity toppers and holds equipment, not a captive-looking miniature creature. Keep the drop badge separate. The ally seam is dark while dormant, briefly ancient blue on wake if the owner publishes that event, and mint while running. No new state transitions come from the model.

## Dressing contract

Extend the existing deferred `hero_assets.gd` node hook only after the merged base arrives. Resolve exact roots by owner and name, then attach one `StyleAVisual` child. A second attachment must find and reuse it. Unknown nodes keep their greybox and produce one diagnostic.

Ask the lab owner to name placeholder meshes and supply local transforms. Cache each replaced mesh's render layers and shadow mode, as the current hero hook does. Hide only agreed placeholder surfaces after successful asset loading; restore them on teardown or failed attachment. Do not hide a whole subtree that contains the live gauge, threat ribbon or prompt.

Reusing the existing material-slot cache is the starting point. Paint and ancient enamel retain vertex colours, copper/bare metal remain restrained, and ancient light reads `Palette.ANCIENT`. Class trim reads the current class definition. Dynamic gauges and state effects need per-owner mutable material state or instance parameters; do not animate shared cached materials across props.

The lab owns collisions, launcher aim, charge, needle value, state, warning geometry, odds, cost, interaction range and prompt selection. Appearance consumes those values. Dome transforms follow a supplied openness value or published pivot transforms, never a second timer. Crater decoration follows the committed region and lifetime, never its own radius or damage test.

Preserve the core's overhead impact corridor and side/rear visibility. Keep cage, brace and beam outside that corridor using real hit geometry. Dial and prompt need an uncluttered region from the chase camera at 6 m; the family silhouette and real glyph must survive at 30 m. Steam cannot hide the mouth, gauge or destination.

## Headless production and verification

No recipe prototype or local render was run in this session. `nvidia-smi` failed to communicate with the driver, so GPU occupancy could not be verified. The image boards came from built-in imagegen.

For a later authorized recipe run, first query `nvidia-smi` for process identity and used memory. If another process uses more than 3 GB, wait. Missing telemetry also holds the GPU job. Do not stop an audio job. Every Blender render runs headless in a separate capped scope:

```sh
systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
  blender -b --factory-startup -P sketches/core-loop/tools/blender/RECIPE.py -- \
  --out /tmp/scrapkeep-prop.glb --render /tmp/scrapkeep-prop-preview
```

This is a command template; RECIPE.py does not exist yet. Use the existing `common.py` material/export helpers, deterministic seeds, coarse primitives and bounded bevels. Avoid subdivision and simulation. Save source blend, GLB and evaluated/exported triangle counts; count all selected children, not a representative piece. Confirm unit scale, pivots, transforms, material names, bounds and no degenerate faces.

Render changed geometry to new filenames. Inspect front, rear, above, open and closed views, then capture the merged game at chase distance with all three classes. The decisive checks are clear launch mouths, unchanged collision and threat footprints, visible core access, no wrong-state glow, readable silhouettes and unobstructed E prompt space. Still art cannot establish animation, native feel or performance.

