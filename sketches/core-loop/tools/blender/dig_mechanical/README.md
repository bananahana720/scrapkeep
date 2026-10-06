# Dig mechanical scenery

This unit exports 26 cosmetic GLBs, 26 matching basename recipes, four shared materials and an assembly manifest. It adds no runtime loader, placement, collision, registry row or gameplay rule.

Blender 5.2.2 LTS builds metre-space geometry in the existing `world_one` frame. Godot 4.7.2 imports the GLBs. Each GLB has its basename root and the required named parts and sockets. All mesh transforms are applied. Wear and thin unlit blue inlays use vertex colour. There are no image textures, lights, cameras or combat rigs in the GLBs.

The build sources are the approved Dig `BUILD-SPEC.md`, `SHEET.md` and images in the coordinator's D1 output directory. The direct MDM assignment applies P-R6 to the original circular breach design: cover skins match the current 12x12 m and 14x10 m rectangles, tabs stay mint, and there is no unready/slate pose. Landmarks remain non-colliding scenery.

## Rebuild and verify

Run from the worktree root:

```sh
blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/dig_mechanical/kit.py -- --all
python sketches/core-loop/tools/blender/dig_mechanical/verify_exports.py
XDG_CONFIG_HOME=/tmp/mdm-godot-config node scripts/sketch-smoke.mjs --sketch core-loop --test dress_mdm_assets_test
```

Each basename recipe also accepts `--out /tmp/BASENAME.glb`. `verify_exports.py` runs every recipe in a separate Blender process and compares complete GLB bytes. It saves hashes, commands and results below `artifacts/local/dress-preview/MDM/`.

The Godot test checks every export against the independent prop caps of 270 triangles, 610 imported vertices and one draw, or lamp caps of 120 triangles, 110 imported vertices and two draws. It checks named nodes, sockets, identity mesh transforms, material resources and exact bounds. It also assembles the actual meshes offline to measure the 24 m impeller, 24 m intake and both rectangular membranes. The test has an `MDM_ASSET_ROOT` override for a scratch model directory. Removing `breach_tab.glb` from that scratch directory produces `dress_mdm_assets_test: FAIL`. The working model directory passes.

The temporary `XDG_CONFIG_HOME` is required by this sandbox. Godot otherwise tries to save editor settings in the read-only home config directory. The first cold import crashed; a subsequent import completed, and the named run passed with the temporary config directory.

## Assemble later

`assets/models/dig_mechanical/manifest.json` supplies component bounds, node names, socket coordinates, material resource paths, hashes, assembly transforms and held/rupture poses. Transform order is local scale, Godot YXZ Euler rotation, translation, then optional assembly scale. Mirrored rim halves have negative local X scale.

The cart's Chassis and the lamp modules' Bracket and Hood are named reference nodes. Their geometry is merged into the respective steel mesh to keep the one-draw cart and two-draw lamps within their class caps. The manifest identifies their authoring vertex ranges and reference positions. Those ranges describe recipe vertices, not Godot's split imported vertices. Runtime use can take the complete merged metal mesh; extraction requires an authoring-side rebuild.

The impeller assembly references eight rim sectors, the off-centre hub, four whole vanes and one chipped vane. The intake references three arched hollow petals, a throat and four spine segments. Assembly manifests contain the landmark placement sockets; the scale-ball socket is preview-only.

The breach manifest uses eight rim half-sides, three baked panels and four tabs. The rectangular panel variants preserve a physical 0.10 m Y crack, 0.9x0.55 m chip, 0.18 m dish and 0.12 m thickness. Their pivots sit on their own outer edges. The nominal 6x6 components are retained under the spec's original basenames as authoring components; placement uses the baked rectangle variants. The rim's X/Z assembly scale is explicit. Tab dimensions are 0.9x0.12x0.55 m, and the rear-edge hinge raises the front by 0.4 m.

Rupture keys describe a 0.45 s cosmetic fall. The integration owner must remove the gameplay cover through the existing swap owner and hide mint tabs immediately at rupture, then hide the falling panels after they clear the route. No eligibility threshold is added. `spent` hides panels and tabs; reset restores the ready mint appearance. There is no slate state.

Keep the landmarks outside playable ground until placement is admitted. The intake has no approved central-well placement. No stone surround is owned or exported by this unit.

## CPU previews

```sh
blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/dig_mechanical/preview.py -- --all --tag review
```

`preview.py` imports the actual GLBs, uses Cycles on CPU with 12 samples and two threads, disables GPU denoising, and renders front, side and three-quarter views. A 2 m reference sphere sits beside the subject in each camera. A tag creates a new preview folder after geometry changes.

The delivered `artifacts/local/dress-preview/MDM/final/` contains 14 subjects and 42 views covering all 26 GLBs directly or in assemblies. Completed previews are retained only when their component hashes still match. Receipts identify the new renders and retained ones. Preview coverage and file sizes are recorded beside the images. The repository ignores `artifacts/local/`, so preview evidence is untracked and appears only with `git status --short --ignored`.

Headless import, mesh measurements and CPU previews establish asset delivery. They do not establish native gameplay rendering, runtime performance or human acceptance. The coordinator owns wiring, integration checks and the blind visual review.
