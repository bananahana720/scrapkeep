# Warden asset hookup — VD-04-A1

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

The original look and kit controllers continue running. Their badge, pulse core, cap domes/plumes/crowns, magnet arm/head, Mind icon and combat telegraphs remain. Only replaced body and kit meshes lose render layers/shadows; their nodes and state remain intact. Shred strokes are copied onto the new jaw faces and read the original stroke visibility/material. Class-colour plating seams and open-crack glyphs follow the existing enemy tint grammar. Damage flash reads the original body material and flash amount. Kit seam energy and weak-point swelling read the original kit controller; Mind shutters spread from their saved positions while that same family-open fact is true. Base pulse light and kit-open light have separate materials.

Dynamic materials and adapted tower meshes belong to each Warden. Attachment is deferred until construction finishes and is idempotent. Wardens leave the tracking dictionary on `tree_exiting`; the presentation loop also removes invalid references. Removing the hook restores original layers/shadows, removes its registered crack glyphs and frees the attached assets.

## Evidence and limits

The focused `tests/hero_warden_assets_test.gd` exercises all three real stage Wardens, attachment, world-space weak-point alignment through yaw, connected mounts, finite transforms/vertices, lower bounds, unchanged collision, independent materials/meshes, opening/reclosing, plating, flash, retained lesson cues, death, stage changes and hook teardown. Existing hero and Warden-family tests remain relevant regression checks.

No native image or performance claim follows from headless checks. The parent owns rendered review of the bent tower, kit visibility, preserved cues and actual gameplay readability. If the adapted tower fails that review, geometry should be revised under a separate scoped decision rather than moving a gameplay hit target. `Palette.ANCIENT` is a parent-owned integration change; this candidate retains the existing alias.
