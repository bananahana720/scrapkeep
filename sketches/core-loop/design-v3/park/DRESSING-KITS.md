# Park dressing kits (Dressing lane, wave 17)

Andrew, 19 Oct 01:40 (DECISIONS.md section 8): the parks feel empty. Each park should read as lived in or run down, with many distinct props placed naturally, and no stretch of ground along the ride should look bare. Hero assets go up to about 20,000 triangles at LOD0, with LOD1 and LOD2. The look is Soft toy (18 Oct 00:40): chunky, bevelled and smooth. Machines keep crisp edges with rounded bevels; round bodies go smooth. Readability comes first. Dressing must never be mistaken for an enemy, a pickup or a climbable route.

This page is the lane's contract. Writers build to it, and reviewers judge against it.

## What this lane owns, and what it never touches

| Owned (new files unless noted) | Purpose |
| --- | --- |
| `tools/blender/park/props/kit.py` | Shared prop builder: polish, LOD1 and LOD2, AO, export, manifest, registry fragment, contact sheet |
| `tools/blender/park/props/<park>.py` | One kit recipe per park: dam, flume, pit, sinkhole, islands, crown |
| `assets/models/park/props/<park>/` | The kit's GLBs (`<kind>_<v>.glb`, `_lod1.glb`, `_lod2.glb`) and `manifest.json` |
| `assets/registry.d/park_props_<park>.json` | Registry rows (the Gate lane re-folds `registry.json`) |
| `src/world/park/props/park_<park>.json` | Vignette data: templates, spots and litter |
| `src/presentation/park_props.gd` | Runtime: expand, validate, seat, batch and range |
| `tools/park_props_plan.gd`, `tools/park_props_audit.gd` | Spot finder and validator; ride-path audit, stills and draw counts |
| `tests/park_props_test.gd` | Clearance, schema, budgets, ranges, shadows and determinism, with planted controls |
| `src/presentation/presentation.gd` (edit, a few lines) | Installs ParkProps beside SetDressing |
| `assets/asset_budgets.json` (edit) | Two classes: `dress_hero`, `dress_prop` |

Never edited: park JSON, bakes, graph, `lines.json`, landforms and landmarks (`landmarks.py`, World), anchor fields (World), the crown and pit greybox rows (Content), enemies, scrap, gates and telegraphs. Props carry no collision, so movement, schedules and run hashes cannot move. `run_tier_test` and the park ride tests prove that on each park PR.

## Kits

Each park has a kit of at least 12 kinds, and each kind has 2 or 3 variants (different geometry, not only a tint). Each kit tells that park's story: who lived or worked there and what they left behind, such as tools, debris, signage, laundry, campfires, stacked timber, broken machines and plants growing through scrap.

| Class | LOD0 triangles | LOD1 | LOD2 | Draws | Shadows |
| --- | --- | --- | --- | --- | --- |
| `dress_hero` (2 or 3 kinds per park) | 6,000 to 20,000 | about 50% (40 to 60) | about 15% (10 to 20) | 1 per LOD | LOD0 only |
| `dress_prop` | 300 to 3,000 | about 50% | about 15% (at least 40 tris) | 1 per LOD | never |

- Each GLB has one surface, one vertex-colour material, baked AO and wear (`polish.py`), its origin at the foot centre, the floor at y 0, and Y up after import.
- Builds are deterministic: a rebuild is byte-identical.
- `manifest.json` lists, per variant: kind, class, footprint radius, height, triangles per LOD, and tags (`tall`, `plant`, `sign`, `machine`, `soft`).

## Readability rules (hard)

- **Colours.** Never use HAZARD `#ff5a3c`, or any red, orange or amber stripes. Never use ANCIENT `#9dff3c` or MINT `#8bf0d3`. Nothing is emissive, and every lamp is unlit; pit and sinkhole have a lamp veto. Never use AMBER `#e5a044` or COPPER `#b77843` as a dominant colour. BRASS `#d9b44a` goes only on Fleet-owned gear. Rust and charcoal sit beside timber, canvas or sandstone so they never read as Fleet.
- **Shapes to avoid:**
  - crates, barrels, bolt-holed boxes and stacked tins (these read as caches or breakables);
  - four-facet bolt-holed chunks (scrap);
  - two-post arches with a lintel (gates);
  - ramps, wedges, stairs, leaning ladders and loading boards (kickers and routes);
  - long rails, taut cables and grindable edges;
  - tall poles on a regular spacing (harpoon anchors);
  - hanging or spinning machines;
  - anything with eyes, legs or a face (enemies; critters belong to the Life lane).
- **Placement.** These are the validator's minimums (`park_props.gd` `validate`), checked for every expanded instance:
  - Clear of every `lines.json` leg (pilots and floor) by at least 15 m. Props over 3 m tall and heroes stay at least 30 m clear. Props within 30 m of a line stay under 1.5 m tall.
  - Outside `ParkRecipes.clear_zones` route lanes (20 m half-width) and outside `ParkSites` keepouts: built row footprints, the landmark, spawn, beacon, gates, activity sites, rescue cages and kickers.
  - At least 25 m from enemy `home_rows` and camps, and inside the play rect.
  - On ground no steeper than 25 degrees, with the foot seated on the baked ground.
- **Vignettes, not scatter.** Props stand in clusters that each tell one moment: a camp corner, a collapsed workshop, an overgrown cart, a laundry line. A sparse litter layer (small debris and plants, 25 to 60 m off the line) carries the eye between vignettes. Repeated small props use MultiMesh.

## Frame cost

- Ranges are set on every view. Heroes: LOD0 to 70 m, LOD1 to 180 m, LOD2 to 450 m. Props: LOD0 to 35 m, LOD1 to 90 m, LOD2 to 200 m. Litter: LOD1 to 70 m only. Fade mode is self, with margins.
- Draws: one MultiMesh per (mesh, LOD) per vignette, and litter batched per 160 m chunk. The bar is dressing adding at most 120 draws at any sampled ride-path pose, measured as the OpenGL proxy in the cloud. The park stays inside PARK.md's caps: draws p99 at most 1.3 times base on s3, and at most 1,400 on p1.
- Litter batches extend `visibility_range_end` by the chunk's spread (the farthest member from the bounds centre), because a visibility range is measured to the batch's bounds centre, not to each member (same reasoning as `set_dressing.gd`). A chunk therefore keeps every member visible out to 70 m.
- Heroes keep LOD0 shadows and full ranges on the low preset; the low preset only drops litter and halves the props' LOD0 and LOD1 ends.
- No shadow casters on small props or litter.
- The ruling is DECISIONS.md section 8, "Lived-in parks", 19 Oct 01:40, on main.
- Every park PR posts `NEEDS: gpu` on the Wave board for a 4080 A/B. Cloud frame times never count.

## Evidence per park PR

The receipt is `VERDICT ... head <sha>`, plus:
- triangles and draws before and after (audit tool);
- props and distinct kinds in view along the ride, before and after;
- `park_props_test`, `park_park_<park>_test`, `run_tier_test`, `pocket_line_clear_test` and the fast lane, with nonzero counts;
- stills from the player camera, before and after (software GL in the cloud: layout and read only);
- an independent reviewer's verdict.
