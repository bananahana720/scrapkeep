# Static fur and accessory mesh kit

This locally authored Blender library builds chunky fur clumps, goggles and a collar from explicit head and neck dimensions. Two neutral busts demonstrate reuse: **broad** has a low, wide head; **slender** has a taller, narrow head. These are fitting fixtures, not accepted hero or boss designs.

## Generate a new delivery

Use installed Blender 5.2.2 LTS. Both scripts work from any current directory when their paths are absolute. Replace `/absolute/scrapkeep` with your checkout root and choose a new output directory.

```sh
systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
  blender --background --factory-startup --python-exit-code 1 \
  --python /absolute/scrapkeep/tools/asset-kit/generate.py -- \
  --output /absolute/scrapkeep/artifacts/local/asset-kit-trial-01

systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
  blender --background --factory-startup --python-exit-code 1 \
  --python /absolute/scrapkeep/tools/asset-kit/verify.py -- \
  --output /absolute/scrapkeep/artifacts/local/asset-kit-trial-01
```

A restricted shell may need access to the user systemd bus. Preserve the memory scope when resolving that environment issue. Scripts read the active cgroup limits and refuse an uncapped run. CPU rendering uses six threads, 24 samples and a 1500-pixel square contact sheet. Distant sun lighting gives both LOD rows the same illumination without distance falloff.

Generation refuses any existing destination before changing it, including files, directories and dangling symlinks. It never updates an existing delivery. If a run fails after reserving a new directory, keep that partial evidence and choose another destination. Verification reads the delivery and creates temporary probes separately.

The output contains four `.blend` files, four `.glb` files, four `.inspection.json` reports, `contact-sheet.png` and `manifest.json`. Names follow `broad-detailed`, `broad-reduced`, `slender-detailed` and `slender-reduced`. The manifest records dimensions, anchor coordinates, geometry fingerprints, source hashes, file hashes, actual exported counts, primitive/material counts, memory limits and provenance. Its file-hash map excludes the manifest itself to avoid a circular hash.

## Fit and reuse

`kit.build(fixture, lod, fit)` returns a Blender collection and metadata. `fixture` is `broad` or `slender`; `lod` is `detailed` or `reduced`. Omit `fit` for the corresponding fixture dimensions, or pass `kit.Fit(width=..., depth=..., height=..., neck=...)`.

All dimensions are in **metres**. Blender uses Z up and the face points toward -Y. GLB export converts to glTF Y up. `width`, `depth` and `height` describe the head envelope, while `neck` is neck width. Each must be finite and within 0.1–4 m; the demonstrated envelope requires width/height 0.35–1.15, depth/height 0.4–0.95 and neck from 0.12 m to below 75% of head width. The neck minimum preserves positive inner radii with the fixed collar wall thickness; the ring builder also rejects nonpositive inner radii. These bounds prevent runaway geometry and extreme proportions; they do not certify fit at every allowed combination.

`eye_fraction` places the goggles above the head centre in units of head height (0–0.25, default 0.13). `tuft_count` controls crown clumps (integer 5–13, default 9), with six additional cheek clumps. `seed` is an unsigned 32-bit integer controlling a local RNG, independent of global random state. LOD controls ring and tuft side counts; it preserves the major silhouettes and component identity rather than dropping accessories.

Head-centre, eye-height, front-goggle and collar anchors are returned in metadata. `fur`, `goggles` and `collar` are separate functions called by both fixtures. The functions fit this known envelope, not arbitrary scanned surfaces: there is no ray-cast fitting, collision solve, skin weighting, hair simulation or universal garment fit. Retune anchors or extend the source for a different head topology and verify that result separately.

Each tuft, frame, lens, strap, collar component and fixture part remains a separate named mesh. The blend contains the assembly alone; studio cameras, lights and labels are excluded. Select the desired `Fur.*`, `Goggles.*` or `Collar.*` objects to reuse a subset. Mesh edits in a blend remain editable but do not update the procedural recipe; preserve those edits as a new source rather than rerunning into the same directory.

## Geometry and limits

Detailed assemblies must have at most **6,000 triangles**; reduced assemblies at most **3,000** and fewer than their detailed counterpart. These are fixture ceilings, not adopted production budgets. Export uses only selected mesh objects, with animation, skin and morph export disabled. AT-01 inspects the actual GLB bytes and must agree with Blender's triangulated count before generation can complete.

Separate objects and materials support editing but can increase draw calls. Primitive counts are retained, **not treated as measured draw calls**. Low triangle counts establish neither runtime performance nor GPU memory cost. Textures are not used; the kit uses cream fur, ochre frames, dark metal and teal lenses as material roles.

The verification script checks invalid inputs before scene mutation, output collision preservation, deterministic geometry despite different global RNG states, finite/nondegenerate closed components, strictly reduced LOD counts, saved-blend identity, source/artifact hashes and AT-01 on all four actual exports. The rendered contact sheet supports visual inspection of the two fixtures and LODs. Engine import, runtime performance, deformation and human acceptance remain unmeasured.

## Provenance

All mesh-generation source and fixture geometry were authored locally for Scrapkeep AT-02. No external asset, paused-sprint source, paid provider or additional dependency is used. This delivery makes **no public license grant**. Source hashes bind each output to its recipe; binary blend files may contain different timestamps while the geometry fingerprint remains identical.
