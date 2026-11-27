# Warden asset hookup — VD-04-A1

> **Historical single-unit receipt:** VD-04-A1 / VD-04-A2 Warden hookup notes; live asset hook wiring lives in [src/presentation/hero_assets.gd](src/presentation/hero_assets.gd) and [CONTRACTS.md](CONTRACTS.md).

The presentation hook replaces the clamp and family-kit placeholder meshes with the four existing GLBs. Combat source, assets, collider and weak-point calculations are unchanged. The GLBs’ imported wrapper nodes are removed before attachment. `HeroWarden` is under the real Warden; `HeroKit` is under that root. The Mind’s `WeakPoint` and six shutters sit under `HeroKit/HeroLens`.

## Spatial adapter

The authored `KitMount` is at `(2.2, 7.8, 0)` above ground. Attaching the kits there would move their visible targets away from gameplay’s hit spheres. Each kit is instead translated so its authored `WeakPoint` origin equals `warden.family_point_at()`. These are ground-relative coordinates, before the Warden look’s yaw:

| Family | Kit origin | Tower top shift |
| --- | --- | --- |
| Reactor | `(-0.4725, 5.1125, 0)` | `(-2.6725, -2.6875, 0)` |
| Hive | `(-1.485, 5.485, 0)` | `(-3.685, -2.315, 0)` |
| Mind | `(-0.135, 6.23, 0)` | `(-2.335, -1.57, 0)` |

Only tower vertices above 2.2 m shift: `shift × (height − 2.2) / (7.8 − 2.2)`. The mesh is duplicated per instance; normals use the inverse transpose. This continuous affine bend/compression joins the existing lower tower to the relocated mount. Its vertical scale remains positive for all three families. Jaw hinge transforms and meshes are unchanged. Authored housing seam corners extend to radius 2.82574 m, so housing X/Z scale is 0.99, keeping the visible lower body inside the unchanged 2.8 m collider.

The base follows the existing jaw controller’s yaw. The aligned weak-point origin lies on that yaw axis and does not move away from its gameplay point. The Mind lens follows the original lens basis, with a quarter turn because its authored face is +X rather than Godot −Z.

## Preserved cues and lifecycle

The original look and kit controllers continue running. Their badge, pulse core, cap domes/plumes/crowns, magnet arm/head, Mind icon and combat telegraphs remain. Only replaced body and kit meshes lose render layers/shadows; their nodes and state remain intact. Shred strokes retain the original level visibility/material, with a tighter layout and 0.45 m stroke length. At attachment only, each becomes a 16-segment ribbon: its vertices project radially onto the actual jaw triangles, then sit 15 mm outward. Open-crack strokes use the same fitting. A height prefilter limits triangle searches, and the existing hook mesh cache shares only immutable fitted ribbons. Animated materials remain private to each Warden. No physics rays, per-frame projection, colliders or gameplay targets are added. Class-colour plating seams and open-crack glyphs follow the existing enemy tint grammar. Damage flash reads the original body material and flash amount. Kit seam energy and weak-point swelling read the original kit controller; Mind shutters spread from their saved positions while that same family-open fact is true. Base pulse light and kit-open light have separate materials.

Dynamic materials and adapted tower meshes belong to each Warden. Attachment is deferred until construction finishes and is idempotent. Wardens leave the tracking dictionary on `tree_exiting`; the presentation loop also removes invalid references. Removing the hook restores original layers/shadows, removes its registered crack glyphs and frees the attached assets.

## Evidence and limits

The focused `tests/hero_warden_assets_test.gd` exercises all three real stage Wardens, attachment, world-space weak-point alignment through yaw, connected mounts, finite transforms/vertices, lower bounds, unchanged collision, independent materials/meshes, opening/reclosing, plating, flash, retained lesson cues, death, stage changes and hook teardown. Existing hero and Warden-family tests remain relevant regression checks.

No native image or performance claim follows from headless checks. The parent owns rendered review of the bent tower, kit visibility, preserved cues and actual gameplay readability. If the adapted tower fails that review, geometry should be revised under a separate scoped decision rather than moving a gameplay hit target. `Palette.ANCIENT` now owns the shared blue; the hero hook consumes it directly.

## VD-04-A2 surface-fit correction

Independent review of 81477da found the flat copied shred strokes floated up to 0.705 m from the tapered jaws. The replacement samples both edges and the centre of every ribbon cross-section, including stroke endpoints and centre, plus every triangle interior, against independently intersected jaw triangles. The focused test requires signed radial clearance between 0.0005 m and 0.03 m for all 1,494 samples per family. Three shred levels and their source-driven visibility remain. Native readability still requires parent inspection. Prior candidate evidence is preserved under VD-04-A1.

The same stroke construction and projection helpers now prewarm those 24 immutable meshes in `HeroAssets.setup`, before `game.gd` connects title/start flow and input. Prewarming uses detached presentation builders: no enemy setup, tree entry, combat events or physics. Each live Warden retains private animated materials. This moves the measured first-fit CPU cost to startup; native first-appearance upload remains unmeasured.

The signed-clearance follow-up closes the occlusion gap in the earlier absolute-distance check. Actual Godot probes across all three families measured 0.001013756–0.029058457 m outward clearance at 15 mm projection stand-off. All 4,482 samples satisfy the positive lower bound and unchanged 30 mm upper bound; no subdivision or runtime work changed. Prior results and benchmarks remain preserved.

## Hive brood-cell correction

Andrew flagged the stage-2 dome and heat columns as reactor language. The three existing cap targets now carry six-sided enamel rims and shallow amber membranes. Open hexagonal markers above the jaws preserve ground-approach visibility without heat columns. Membranes sit at the existing `cap_points()` coordinates and keep the original hit material, flash and damage rules. This is a presentation change in `warden_look.gd`; `warden.gd` and its lesson data are unchanged. It supersedes the old heat-plume appearance in the design reference, pending the coordinator's canonical record update.


## VD-04-MAST open beacon support

The hero hook dresses only the beacon belonging to `ctx.flow.warden`. The original mast node, mesh, transform and material stay intact. Its render layers and shadow casting are suspended while two copied frustum sections preserve the original taper below and above a 2.9 m band centered on the unchanged family weak point. Six 12 cm square beams form two split rails, reaching 1.5 m to either side on the beacon's local X axis. The lamp, charge ring and beacon controller are untouched. Geometry is built once per owner attachment; there is no per-frame mesh work.

The focused test computes exact closest distance to each solid oriented beam box and a conservative vertical distance for both frusta, covering faces and interiors as well as vertices. All three families measured at least 1.440000057 m from the fixed weak-point center, exceeding its 1.3 m sphere. It also checks taper endpoints, material identity, duplicate attachment, extra-Warden isolation, death, stage replacement, hook teardown and attachment of a replacement hook to an already active Warden. Teardown removes the support immediately and restores the exact original render state. Deferred Warden callbacks now reject a hook that has left the tree.

This establishes geometric clearance and lifecycle behavior only. The two narrow rails can still cross a kit silhouette from some angles; native orbit/readability and actual render performance remain the parent's acceptance work. No target, collider, charge, placement, family or combat rule changed.

### Queen hatch state

Native front inspection after the mast correction revealed that the hive GLB's opaque rubber cap still hid the queen during its open window. The hook now splits that existing surface into a bottom-hinged child. Its closed transform reconstructs the authored pose; `family_open()` rotates it outward 90 degrees. The core and target node stay fixed, and each Warden owns its own split meshes. Focused open/close and second-Warden isolation checks pass at `ba7da85`.
