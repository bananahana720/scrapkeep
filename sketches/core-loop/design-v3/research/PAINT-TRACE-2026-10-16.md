# Paint trace: does an equipped pilot paint show in a real run?

Status: read-only research, 2026-10-16, on `main` at 77b99de. Paths are under `sketches/core-loop/`. Godot was not run: every claim below comes from reading the code and parsing the shell GLBs with a Python script. Nothing here was played or rendered.

## Finding

Yes, the paint reaches the run. The equip, save, load and fit chain is complete and tested at the material level. But the tint probably does not *read* on most of the ball. The paint material multiplies the tint over the mesh's baked vertex colours, and the Core lattice (the large rolling part) is baked near-black on every pilot. So the colour shows on the sand-coloured weapon ring and pod, and barely shows on the lattice. Two starter paints (Salt White, Ledger Cream) are near-white, so they look the same as "No paint". This is inferred from the numbers below, and needs Andrew's eye at the sitting.

The HANDOFF line that says the cosmetics runtime was lost (`design-v3/HANDOFF.md:61`) is out of date. Paint tints landed in wave 14 (`HANDOFF.md:412`, cosmetics-paint dd359b6), and the eight-slot model, `CosmeticWear.worn`, shell variants and outfits are in the code now.

## The chain, end to end

| Step | Evidence | State |
| --- | --- | --- |
| Paint rows: 19 paints, six starters, every tint checked against hostile hues | `src/core/cosmetics.gd:34-51`, `:104`; `validate` `:137-189` | works |
| Ownership: a starter is owned, otherwise the profile must hold it | `src/core/cosmetic_wear.gd:9-11` | works |
| Equip on the class card: P key or pad X cycles owned paints, then saves | `src/ui/class_card.gd:381-388`, `:431-438`; swatch click `:303` | works |
| Equip on the Customize page (Camp, then Customize): checks pending, owned, fits, then saves | `src/ui/customize_page.gd:576-589`; reached from `camp_menu.gd:46`, `customize_page.gd:287-297`, `:505-511`; Camp opens with K on the title, `src/ui/screens.gd:455-460` | works |
| Saved shape: `"<pilot>/paint"` in one string map | `src/core/profile.gd:229-234` | works |
| One profile object for UI and game: made before presentation is set up | `src/game.gd:169`, `:190`; `src/presentation/presentation.gd:86-88`; `hero_assets.gd:190-193`; the page opens `_game.ctx.profile`, `customize_page.gd:511` | works |
| In the run, `_fit` runs every frame and refits when class, tint or variant change | `src/presentation/hero_assets.gd:492-501`, `:453-478` | works |
| Tint lookup: refuses unknown, wrong slot, other pilot, no tint, not owned; warns once | `hero_assets.gd:413-431`, `:434-437` | works |
| The tint goes to the `paint` slot only, never copper or `class_accent` | `hero_assets.gd:337-352`, `:138`, `:157-159` | works |
| Core, Pod and all four heft layers are painted (layers are children before `paint()`) | `hero_assets.gd:936-992` | works |
| Kest's ring bands keep the paint tint in their shader | `hero_assets.gd:581-591`, `:636` | works |
| The class card and Customize previews use the same `fit_shell_into` and `paint_tint` | `src/ui/class_preview.gd:189`, `:233-236`; `customize_page.gd:429-447` | works |
| Test: an owned paint sets the lifted albedo on Pod and Core; refusals; repaint at next fit | `tests/cosmetic_apply_test.gd:96-175` | passes per wave 14 gate (not re-run here) |

## What is missing or weak

### 1. The Core lattice is baked dark, so the tint barely shows there (likely, unverified)

The paint material sets `vertex_color_use_as_albedo` and `albedo_color = 1.2 × tint` over the plate texture (`hero_assets.gd:138`, `:268-305`). The rendered colour is vertex colour × plate × tint. The tint can only darken or shift a colour that is already there; it cannot brighten a black strut.

Vertex colours on `paint` surfaces, from the GLBs (glTF linear RGB, most common value, with vertex counts):

| Shell | Core lattice | Weapon ring | Pod |
| --- | --- | --- | --- |
| Sable | 0.04, 0.10, 0.09 (petrol), 1920 verts | 0.64, 0.56, 0.38 (sand), 320 | sand, 88 |
| Rivet | 0.02, 0.02, 0.02 (black), 3840 | sand, 320 | sand, 72 |
| Kest | petrol, 3840 | 0.51, 0.36, 0.22, 608; vanes 0.24, 0.14, 0.09 | petrol, 72 |
| Tarn | 0.33, 0.08, 0.04 (oxide), 3840 + black 819 | 0.22, 0.20, 0.14, 1004 | 0.06, 0.06, 0.05, 1024; claws sand |
| Tally | 0.25, 0.05, 0.06 (oxide), 1920 | 0.22, 0.20, 0.14, 1112 | 0.10, 0.10, 0.09, 872 |
| Cannon | petrol, 3840 | 0.26, 0.23, 0.16, 992 | no paint surface |

Sand (0.64, 0.56, 0.38 linear) is Palette.SAND `d2c5a5`, so a tint on sand reads cleanly. On petrol, black or oxide it stays near-black. Expected result by pilot: Sable and Rivet show the paint on the ring and pod only; Tarn on the claws only; Kest a little on the ring; Tally and the Cannon almost nowhere. Heft layers C2 to C5 add pod panels at 0.15 to 0.58 grey-sand, so the paint grows more visible as the ball classes up.

How sure: the vertex values are measured. That they look dark on screen is inferred; how Godot converts vertex colour space on import was not checked, and the plate texture and lighting were not rendered. CUSTOMIZE.md section 2 says the lattice struts use `paint` "so a class-up keeps your colour", so the design intends the lattice to carry the paint.

### 2. Two starters look like no paint

Salt White `e9ecea` (`cosmetics.gd:34`) and Ledger Cream `f7f1e3` (`:44`) are close to the white the unpainted slot uses (`hero_assets.gd:138`). On sand they read as the default. HANDOFF already flags Ledger Cream (`HANDOFF.md:377`).

### 3. The test checks the material, not what you see

`cosmetic_apply_test.gd:114-115` compares `albedo_color` with the lifted tint. It never multiplies by vertex colour, so it passes whether or not the paint is visible. Its comment at `:81` ("Core is glass only today") is stale: every Core now has a `paint` surface.

### 4. Two ownership copies remain for paint

`hero_assets.gd:413-437` and `class_card.gd:365-377` repeat the ownership rule instead of asking `CosmeticWear.worn`, which CUSTOMIZE.md section 3 asks all readers to use. They agree today. This is a drift risk, not a bug.

### 5. The title stage ignores paint

`src/presentation/title_stage.gd:205` paints the title shells with the class colour only. Your paint shows on the class card, the Customize page and in the run, but not on the title. This may be intended.

## Fix cards for the coordinator

New files are not needed for any of these; each changes existing files, so the wave coordinator owns them. Run card A only after Andrew's check confirms the problem.

**A. Make paint read on the lattice (needs a look decision).** Choose one:
- A1, art: re-bake the Core and heft-layer `paint` surfaces to a light neutral (SAND or a pale grey) and keep the dark look in the plate texture or in a second, unpainted slot. Files: `tools/blender` shell recipes, `assets/models/world_one/shell_*.glb`. Cost: six shells and their variants re-exported.
- A2, shader (recommended start): give the `paint` slot a mask like SPIL-9's enamel, `ALBEDO = COLOR.rgb * mix(vec3(1.0), tint, COLOR.a)` (`src/presentation/cosmetic_presentation.gd:273-276`), but drive the mix by a target colour: lerp the vertex colour toward the tint by a fixed amount (start 0.6) so a dark strut takes the hue. Files: `hero_assets.gd` `material()` and `kest_band_material()`. Keep the cache key per tint so no per-instance material appears (CUSTOMIZE.md section 2, rule 3).
- Accept: decide the paint is a trim colour (ring and pod) and update CUSTOMIZE.md section 2 to say so.

**B. Visible-paint test.** In `tests/cosmetic_apply_test.gd`, for each pilot, compute mean (vertex colour × albedo) over `paint` surfaces with and without `paint_any_cobalt` and require a luminance or hue difference over a threshold (start 0.08). Fix the stale comment at `:81`. This turns finding 1 into a failing test before card A, and a passing one after.

**C. Starter tints.** Move Salt White and Ledger Cream away from white (or keep them and accept they read as "clean"). Files: `cosmetics.gd:34`, `:44`, plus the ROWS golden the tally-kit unit re-pinned (`HANDOFF.md:357`).

**D. One ownership copy (low).** Have `hero_assets._equipped_paint` return `CosmeticWear.worn(profile, id, "paint")` and `class_card.paint_shown` call the same. Keep `paint_tint`'s warn-once reasons.

**E. Stale handoff line.** Mark `HANDOFF.md:61` "cosmetics runtime (CUS, lost)" as superseded by wave 14 dd359b6 and the current slot code.

## Check for Andrew at the playtest sitting

About two minutes. Do it once on Sable and once on Tally.

1. On the title, press K for Camp, then Customize. Pick Sable. On Paint, choose Lagoon (a Sable starter). Watch the preview ball.
2. Back out, start a run as Sable and roll for ten seconds. Then answer: is the teal on the rolling lattice, or only on the ring and the seat pod?
3. Repeat with Tally and Ledger Cream, then with Tally and "Default". Answer: can you tell Ledger Cream from Default?
4. If you have unlocked any paint (Night Slate, Cobalt and so on), equip it and say whether it reads at speed.

Log it in playtest entry 13 under the cosmetics area. "Lattice stays dark" means run cards B then A. "Reads fine" means run C and D only.

## Outcome (2026-10-16, same day)

Cards B, A2, C, D and E landed together on branch `claude/pilot-paint-adk8qg`.

- **B:** `cosmetic_apply_test` now models what each paint surface renders (vertex colour through the material) and requires Cobalt and every starter paint to pull each pilot's Core at least half the way to the lifted tint. On the old multiply it failed all 18 pairs (every paint darkened the lattice away from its tint); with A2 all 18 pass at 0.57 to 0.76.
- **A2:** an equipped paint is a `ShaderMaterial` named `paint` that lerps the vertex colour `PAINT_TAKE` (0.6, start) toward the lifted tint, over the same triplanar plate map. Kest's ring bands use the same formula. Unpainted surfaces keep the `StandardMaterial3D`. One shader per use, one cached material per tint.
- **C:** kept Salt White and Ledger Cream as they are: with A2 they turn the dark lattice pale, so neither reads as Default any more (the test covers both).
- **D:** `hero_assets._equipped_paint` and `class_card.paint_shown` ask `CosmeticWear.worn`; the card's own `owns` copy is gone. `paint_tint` keeps its warn-once reasons.
- **E:** `HANDOFF.md:61` is marked superseded.

Stills: [paint-stills/](paint-stills/), Sable (Default, Lagoon, Salt White) and Tally (Default, Ledger Cream, Cobalt), before and after, from `tools/paint_still.gd`. They were rendered by Godot 4.7.2's Compatibility renderer on Mesa llvmpipe in the cloud (no GPU), not Forward+ on Vulkan, so the light and tone differ from the game; the tint difference is the point. Andrew's check at the sitting above still stands.
