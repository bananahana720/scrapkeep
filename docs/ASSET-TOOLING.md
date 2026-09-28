# Asset export inspection

`npm run asset:inspect` reads self-contained glTF 2.0 binary (`.glb`) exports with Node built-ins. It measures triangle geometry without importing an engine, fetching a URI, modifying a mesh or calling a model. The inspector is a scoped geometry check, **not a complete glTF conformance validator**. A budget pass is not visual approval or production qualification.

## Inventory and delivery budgets

```sh
npm run asset:inspect -- export.glb
npm run asset:inspect -- export.glb --profile generic-30k
npm run --silent asset:inspect -- export.glb --nodes 0,2 --max-tris 30000 --json
npm run asset:inspect -- export.glb --scene 1 --output report.json
npm run --silent asset:inspect -- shell.glb attachment.glb --max-tris 30000 --json
npm run asset:inspect -- --help
```

The `generic-30k` profile allows at most 30,000 triangles, including exactly 30,000. `--max-tris N` supplies a nonnegative integer ceiling instead. Neither budget is implied by a filename, material, character class or export size. Without either option, status is `inventory`, never `pass`. A multi-file budget applies to the sum of each file's selected scene instances; it does not establish a common placement or assembled appearance.

Exit codes are 0 for inventory or budget pass, 2 for over-budget, and 1 for invalid/unsupported input, usage or output failure. Consumers must read `status`, not treat exit 0 alone as approval. `--json` emits a version-1 JSON report, including errors for invalid input. `--output` saves the JSON report while leaving stdout in the chosen mode. Output may replace an existing unrelated report, but cannot alias any GLB or manifest input through its absolute path, real path, symlink or device/inode identity. All inputs are captured before report writing. Inspection failures can produce a safely located receipt with `status: "invalid"`; early usage, capture or output-validation failures do not write a report.

## Explicit assemblies and LODs

A file's default scene is selected unless `--scene N` or `--nodes N,M` is supplied. Without a default, a sole scene is selected; multiple scenes require an explicit choice. Node roots select complete subtrees. A selected descendant retains its ancestors' transforms for static world bounds. Duplicate roots, overlapping selected subtrees, cycles, invalid references, multi-parent trees and empty mesh selections fail. Select alternatives by numeric IDs, never inferred names. `--nodes` and `--scene` each require one positional file and cannot be combined.

For an assembly across files, save this local JSON manifest and pass `--manifest assembly.json`:

```json
{
  "version": 1,
  "name": "Example shell and attachment",
  "parts": [
    { "file": "exports/shell.glb", "nodes": [0], "lod": "delivery" },
    { "file": "exports/attachment.glb", "nodes": [3], "lod": "delivery" }
  ]
}
```

```sh
npm run --silent asset:inspect -- --manifest assembly.json --profile generic-30k --json
```

`version`, a nonempty `name`, and nonempty `parts` are required. Each part needs a local relative `file` and nonempty numeric `nodes`; `lod` is an optional nonempty label documenting the chosen geometry. Unknown fields fail. File paths resolve relative to the manifest, including local `..` references; absolute paths and URI schemes are rejected. The manifest cannot be mixed with positional files or CLI node/scene selection. A LOD label records intent; it does not cause the inspector to switch geometry. Select one desired LOD explicitly by node roots. Extension-managed LOD is unsupported.

Each manifest entry represents one intended instance selection. Repeating the same file and nodes in **separate entries** intentionally counts another instance; within a single entry, overlap fails. A manifest has no placement transforms, so combined bounds are `null` with `unknown_no_shared_placement`, even if there is only one entry. Per-file selected static bounds remain available.

## What the report measures

- `files[].sha256`, `bytes` and absolute `path` identify captured inputs. The manifest also has a source hash.
- `inventory` counts every mesh definition once, including unused library variants and alternate LOD meshes. Identical geometry in distinct mesh definitions counts separately. Vertex counts sum primitive POSITION accessors and are not deduplicated vertices.
- `selection` counts mesh references once per selected node instance. A mesh reused in three nodes contributes three times. `assembly.triangles` sums these selected totals and is the quantity compared with the budget.
- Mesh `local_static_bounds` come from actual POSITION values. Selected `static_world_bounds` transform those values through the node hierarchy, including ancestors of selected roots. These describe all declared vertices, including unreferenced ones, rather than tight rendered-surface bounds.
- Skins, morph targets or any animation make selected world bounds unknown (`null`). Mesh-local POSITION bounds remain undeformed data. Animated, posed and runtime bounds require engine evaluation.
- Inventory reports primitives, materials, skins, animations, images and textures. Primitives are **not draw calls**. Texture decoding, material validity, skin/animation semantics, texture memory and GPU memory are unmeasured. `engine_import` is always `not_run`; `visual_acceptance` and `performance` are `not_measured`.

Supported geometry includes indexed and non-indexed TRIANGLES, unsigned scalar indices, float VEC3 positions, multiple primitives and interleaved attributes. Validation checks GLB header/chunk sizes and alignment, declared embedded buffer size, bufferView/accessor storage ranges, actual index values, finite positions, matching attribute counts and node graph structure. Matrix accessors with sub-32-bit components, sparse accessors, other primitive modes, compression, GPU instancing, unknown extensions and external/data URI buffers or images fail with diagnostics. Known optional material metadata and punctual lights do not affect triangle accounting; they are not validated as rendering features. No external URI is fetched.

## Verification

Run `node --test tests/asset-inspect.test.js`. The fixtures contain actual binary position/index storage, including three million indexed triangles, and exercise cap boundaries, explicit alternatives, repeated instances, malformed buffers and graphs, unsupported geometry and input-preserving output aliases. The tooling-only repository checks are `npm test`, `npm run check:docs`, `npm run check:project` and `npm run check:drift`; no browser or game build is needed for this command.
