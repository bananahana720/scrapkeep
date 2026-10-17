# Customization assets

CUA supplies thirteen animated trail cards, ten shell decal masks and six companion enamel swatches. The approved D7 BUILD-SPEC at base `955e7e55aa10a69c3d0f6c71d0bd2eb4763c5970` owns the first six trails and eight decals; the wave 19 earned items (seven trails, decals 8 and 9) follow `design-v3/COSMETICS-ART-BRIEFS.md`. All art is authored procedurally here. No downloaded artwork, gameplay code or registry changes are included.

Run from the repository root with Blender 5.2.2:

```sh
blender -b --factory-startup --threads 2 -P sketches/core-loop/tools/blender/cosmetics/build_cua.py
blender -b --factory-startup --threads 2 -P sketches/core-loop/tools/blender/cosmetics/build_cua.py -- --out /tmp/scrapkeep-cua-rerun
python3 sketches/core-loop/tools/blender/cosmetics/inspect_cua.py --compare /tmp/scrapkeep-cua-rerun
XDG_CONFIG_HOME=/tmp/scrapkeep-cua-godot-config node scripts/sketch-smoke.mjs --sketch core-loop --test dress_cua_assets_test
blender -b --factory-startup --threads 2 -P sketches/core-loop/tools/blender/cosmetics/preview_cua.py
```

The temporary XDG configuration directory keeps headless Godot's editor settings inside the sandbox. The preview recipe uses Cycles CPU, two threads and eight samples. It writes three arena-scale views of every item, plus a clip key pose and a maximum-density threat fixture for every trail, under `artifacts/local/dress-preview/CUA/`. A 2 m reference ball appears in every view. Decals use material composition on a shell fixture. Paints use a dimensioned SPIL-9 proxy; the companion modelling unit owns the final hull. These fixtures are never exported as assets.

`assets/cosmetics/cua_manifest.json` records every path, byte size, hash, tint, physical mark size, atlas rectangle, clip and attachment rule. GLBs use one metre per unit, Godot +Y up and -Z forward. A card is centred at `BallTrail`; the consumer positions this origin at the floor plus 0.04 m. The named particles are `ChalkPuff`, `FlatStamp`, `CrescentPuff`, `Chip`, `PairedTuft`, `WashPuff`, `CableDash`, `Swarf`, `SmokeWisp`, `ClawPair`, `TapeStrip`, `RecitalMarks` and `BeatTick`. Each card's clip is one of `fade_shrink`, `fade`, `rotate_fade`, `tumble_fade`, `expand_fade` and `flatten_fade`; `build_trail` keys the motion on the clip name. `size_m` is (across, along) the ball's travel. The first six tiles keep their atlas cells; `TRAIL_CELLS` places the rest in the free cells.

Each GLB has two triangles, four vertices and one `fx_neutral` surface. All reference one external 512×512 atlas. Twenty-four selected cards cost 48 triangles and 96 vertices. One submitted draw requires the later consumer to batch those cards with one shared atlas material. Twenty-four instantiated GLBs would cost twenty-four draws and violate the spec.

Trail alpha peaks at 36/255, with no emission or additive blending. A maximum-density straight wake has no more than two overlapping cards at a point, retaining at least 73% of the threat's colour contrast. The consumer must fade cosmetics first where they intersect a committed threat, including folded paths. Enforce the 24-card, 1.8 m, 0.45 s, 0.45 m width and 0.25 m height limits; suppress emission when stationary, paused or airborne. These are attachment instructions, not implemented game behavior.

Core glTF animation cannot animate material alpha. The exported clips carry shrink, curl rotation, chip tumble, tuft expansion and wash flattening. The manifest supplies the opacity envelope to apply alongside the clip, reaching zero at the declared lifetime. There is no idle emission, root movement or combat phase in these cosmetic clips. Primer, ram and escape phases remain the companion modelling unit's clips and gameplay scripts' facts.

Decals add zero triangles, vertices or surfaces. Each `AtlasTexture` is named `DecalMask`; all ten share the 1024×1024 atlas, plus individual white-alpha motif masks for composition. Bake one selected mark into an existing `HeroCore` enamel surface. The manifest's `size_m` measures the visible motif; `mask_bounds_px` and `tile_size_m` account for the transparent gutter. Keep 0.04 m clear of plate edges and state-cue masks, and keep it off `HeroPod`, glass and pilot. The shell assets at the base do not provide a designated decal UV plate; the later wiring unit must resolve that projection without adding geometry or surfaces. The material fixture demonstrates the mark, not native shell attachment.

Paint `.tres` files are matte, non-emissive `paint` swatches with the same vertex-colour treatment as `hero_assets.gd`. Copy the swatch tint onto a duplicate of the existing Hull/Deck enamel material. Do not replace the final hull's material wholesale or tint socket collars, rubber, steel, EscapeWitness, module working faces, combat effects or HUD. Swatches add no geometry, textures, rig or clips. The existing hull and module clips apply unchanged.

The Godot test imports each GLB and checks the required nodes, clip names, duration, actual geometry, clip bounds, material, atlas, PNG pixels and paint resources. Its missing-node and missing-clip probes mutate a scratch GLB under `user://cua-negative/`; the original assets remain untouched. Run the script with `-- --cua-break=missing-node` or `-- --cua-break=missing-clip` to expect `dress_cua_assets_test: FAIL` and a diagnostic naming the missing requirement.

Budget, imported-model and CPU fixture evidence do not establish live native threat readability, runtime fade behavior, controller support, performance or Andrew's acceptance. No `src/` file is edited by this unit.
