# Terrain kind

A headless Claude Code agent writes a numpy recipe for a seamless, painted PBR ground tile. The
forge builds it, validates it and shows a 2 x 2 lit repeat. You get albedo, normal, roughness,
ao and height PNGs plus a Godot `StandardMaterial3D` `.tres`. `promote` moves an accepted
version into the core-loop sketch.

```sh
F=tools/asset-forge/forge.py
python3 $F make terrain --pack core-loop --name sand_ground "sun-baked sandstone ground ..."
python3 $F run artifacts/local/forge/core-loop/sand_ground/v001      # rebuild + revalidate, no model call
python3 $F promote sand_ground v001                                  # --force replaces
```

`make` and `revise` spend Claude quota; `run`, `list`, `compare` and `promote` do not. The pack
gives `category` `prop` only (`band` and `sizes` are the allowed texture size in pixels,
256 to 1024; one draw call).

## Files

| File | Role |
| --- | --- |
| `kind.toml`, `brief.md` | kind registration; the agent's rules and the full texlib API |
| `texlib.py` | the toolkit (numpy, so it only runs inside Blender's Python) |
| `entry.py` | runs in Blender: recipe -> maps -> PNGs, `.tres`, preview; always writes `result.json` |
| `validate.py` | stdlib; re-reads the PNGs, never trusts the agent |
| `promote.py` | copies into `sketches/core-loop/assets/textures/<asset>/` |

Blender is only the interpreter here: system Python has no numpy, Blender 5.2's has 2.3.4. The
agent cannot Read `texlib.py` before its first run (the forge copies only the pack's example
recipes), so `brief.md` carries the whole API and `entry.py` copies `texlib.py` to `reference/`
for later runs.

## Recipe contract

`recipe.py` defines `build(params)` and returns a dict: `height` (n x n float, required),
`albedo` (n x n x 3 sRGB float, required, built with `tl.ramp`), and optional `roughness`,
`ao`, `normal_strength` (default 1.5) and `uv_scale`. The normal is always derived from the
height. Outputs in `out/`: `<asset>_albedo.png` (8-bit RGB), `_normal.png` (8-bit RGB, OpenGL
Y+, Godot's convention), `_roughness.png`, `_ao.png` (8-bit grey), `_height.png` (16-bit grey),
`<asset>.tres`. `preview/sheet.png` is the lit 2 x 2 repeat with a strip of the five maps.

## texlib API

Every generator is periodic on a wrapped lattice, deterministic from `seed`; fields are float32
(n, n) in 0 to 1, colour images (n, n, 3) sRGB float.

| Group | Functions |
| --- | --- |
| Noise | `value_noise(n, period, seed)`, `gradient_noise(n, period, seed)`, `fbm(n, period, octaves, seed, kind, gain, lacunarity)` (period multiplied by an integer lacunarity, default doubled, per octave), `ridged`, `worley(n, cells, seed, mode)` with wrapped 3 x 3 neighbour search, modes f1 / f2 / edge / id |
| Filters | `blur(a, sigma)` (FFT, wrapped), `warp(a, amount, period, seed)` (wrapped domain warp), `shift`, `normalize`, `remap`, `smoothstep`, `contrast`, `posterize(t, levels, soften)` |
| Colour | `ramp(t, stops, palette, steps)`, `palette_rgb(palette, role)` |
| Derived | `normal_from_height(h, strength)` (OpenGL Y+), `ao_from_height(h, radius, strength)` |
| Output | `write_png(path, arr, bits)` (filter 0), `tres_text(asset, uv_scale, height_scale)`, `light_tile`, `preview_sheet` |
| Metric | `seam_metric(a)` |

`.tres` text uses the placeholder folder `res://__FORGE_TEXTURES__/<asset>`; `promote`
rewrites it to the real `res://assets/textures/<asset>`. Height is attached with the parallax
(`heightmap_enabled`) off, since deep parallax is costly.

## Checks and thresholds

| Check | Pass | Warn | Fail |
| --- | --- | --- | --- |
| `maps_present` | five PNGs exist | | any missing |
| `size` | square, equal across maps, power of two, inside the pack band | | any violation (`size_equal`, `size_square`, `size_pot`, `size_band`) |
| `seam` | max over five maps and both axes of (mean wrap-pair difference) / (mean adjacent-pair difference, floor 0.002) up to 2.0 | above 2.0 | above 3.0 |
| `palette` | albedo pixels all within 0.04 (sRGB distance) of a palette colour or a straight mix of two | under 1% off | 1% or more off |
| `relief` | height std at least 0.02 | | flat |
| `smoothness` | lag-1 neighbour correlation of height 0.8 or more | 0.6 to 0.8 | below 0.6 (per-pixel noise) |
| `normal_unit` | mean length error under 0.03 | | above |
| `normal_z` | 99.9% of normals face up | | below |
| `normal_y_plus` | green follows +d(height)/d(row) and red follows -d(height)/dx, correlation 0.6 or more | | either below (a DirectX normal reads negative) |
| `tres`, `preview` | `.tres` is a StandardMaterial3D naming all five maps; sheet exists | sheet missing | `.tres` bad |

Seam calibration (512 px unless noted, `test_terrain.py` at 256 px): texlib fbm 0.92 to 1.2,
worley 1.1 to 1.4, FFT blur 0.96, warp 1.06; a sine wrapped at its steepest point 1.6 (the
worst honest case). Defects: linear ramp 255 to 500, tile with an 8 px border 39 to 73,
cropped noise 45 to 68, a blob cut by the tile edge 33, a small corner blob 13. Warn at 2.0
and fail at 3.0 leave room on both sides. The validator re-reads the PNGs in pure Python and
matches texlib's numpy metric to within a few percent (tested).

## Stated gaps

- A seam metric of 1 proves the wrap pair looks like its neighbours, not that the tile hides
  repetition at distance. Look at the 2 x 2 sheet; the validator cannot judge taste.
- Palette truth holds for the albedo pixels only; lighting, the engine's colour grading and
  triplanar blending change what the player sees. The sRGB-versus-linear import of the
  albedo and normal map is Godot's call at import.
- A passing tile says nothing about in-engine look or performance. Godot import and load of
  the promoted `.tres` is checked separately, not by `forge run`.
- `forge.py` shows the agent "triangle band" wording for the pixel band; `brief.md` says to
  read it as a pixel size. A forge-level fix is outside this kind.
