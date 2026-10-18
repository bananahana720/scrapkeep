# Cosmetics art briefs: the 19 hidden items

Status: wave 19 brief, written 2026-10-16 from `main` at b96c2fa. Read-only research: the code, the manifest, the registry and the recipes were read, and nothing was built, rendered or played (Blender and Godot are not in the cloud). Paths are under `sketches/core-loop/`. A number marked (start) is a starting value to tune in play.

Reads with: [CUSTOMIZE.md](CUSTOMIZE.md) sections 2, 6 and 8 (slots, mounting, the earned items), the six [pilot sheets](pilots/) section 7, [research/PAINT-TRACE-2026-10-16.md](research/PAINT-TRACE-2026-10-16.md), and `tools/blender/cosmetics/README.md` (the trail and decal limits).

## Finding

The game has 19 cosmetics with no visible art. They are the `PENDING_ART` list (`src/core/cosmetics.gd:27`). The Customize page hides them, and the earned toast leaves out the "New look" line for them (`src/core/achievements.gd:179-190`). So today a player can earn an achievement and receive nothing visible.

**Five of the 19 are already built.** The shell variants Felt Rig, Calibrated, Redjaw Teeth, Abacus Lattice and Choir Barrel have their GLBs in `assets/models/world_one/` and shipping rows in `assets/registry.json` (`:4342`, `:4508`, `:4586`, `:4614`, `:4738`). They merged in wave 13 unit PD (`docs/decisions.tsv:479`, `:483`). Kest's Roost Frame came through the same unit and its id was removed from `PENDING_ART`, with a test that says so (`tests/kest_kit_test.gd:355`). The other five ids were never removed. They need one line and four test re-pins (see port notes), not art.

**Fourteen need new art:** seven trails, two decal tiles, four outfits and one companion skin. Every slot's loader already exists (`hero_assets.gd:1185` outfits, `:1274` companion skin; `cosmetic_presentation.gd:357` trails; the decal atlas). All fourteen are art-only except where a brief says otherwise. The trail atlas has 10 free tiles and the decal atlas has 8, so nothing needs a new texture.

**Decided 2026-10-16:** Andrew confirmed the cut of Kest's Rigger Harness on the project-chat card for this PR. Ship 18, cut 1. Un-hide the five shells now. Build the seven trails and two decals in one extension of the existing cosmetics recipe. Build three outfits and the Till Bell. Cut Kest's Rigger Harness for alpha (reason in its brief). That leaves 13 new pieces of art, nine of which are 2-triangle cards or atlas tiles.

## The 19 at a glance

Cost: **none** (a port line), **S** (an atlas tile or card in `build_cua.py`), **M** (a new small GLB on an existing rig).

| Item | Name | Slot | Owner | State | Cost | Call |
| --- | --- | --- | --- | --- | --- | --- |
| `shell_sable_felt` | Felt Rig | shell | Sable | built, still hidden | none | keep: un-hide |
| `shell_rivet_calibrated` | Calibrated | shell | Rivet | built, still hidden | none | keep: un-hide |
| `shell_tarn_redjaw_teeth` | Redjaw Teeth | shell | Tarn | built, still hidden | none | keep: un-hide |
| `shell_tally_abacus` | Abacus Lattice | shell | Tally | built, still hidden | none | keep: un-hide |
| `shell_cannon_choir` | Choir Barrel | shell | Cannon | built, still hidden | none | keep: un-hide |
| `trail_sable_cable` | Cable Stitch | trail | Sable | no art | S | keep |
| `trail_rivet_swarf` | Swarf Curl | trail | Rivet | no art | S | keep |
| `trail_kest_fuse_smoke` | Fuse Smoke | trail | Kest | no art | S | keep |
| `trail_tarn_claw_marks` | Claw Marks | trail | Tarn | no art | S | keep |
| `trail_tally_punch_tape` | Punch Tape | trail | Tally | no art | S | keep |
| `trail_cannon_recital` | Recital | trail | Cannon | no art | S | keep |
| `trail_any_downbeat` | Downbeat | trail | any pilot | no art | S | keep |
| `decal_sable_spool` | Spool and Wrench | decal, tile 8 | Sable | no art | S | keep |
| `decal_curtain_call` | Curtain Call | decal, tile 9 | any pilot | no art | S | keep |
| `outfit_rivet_hood` | Welding Hood | outfit | Rivet | no art | M | keep |
| `outfit_tally_eyeshade` | Eyeshade | outfit | Tally | no art | M | keep |
| `outfit_tarn_steady_cap` | Steady Cap | outfit | Tarn | no art | M | keep |
| `outfit_kest_rigger` | Rigger Harness | outfit | Kest | no art | M | **cut for alpha (confirmed)** |
| `companion_skin_till_bell` | Till Bell | companion skin | SPIL-9 | no art | M | keep |

After this, each pilot has a shell variant and a trail, Sable has a decal, and every slot except bay decoration has at least one earned item, so each slot is proven end to end.

## Rules every brief keeps

From CUSTOMIZE.md section 2 and the cosmetics README. They are listed once here, not in each brief.

- Looks only. No light node, no emission, no per-instance material. Materials come from the shared cache by surface slot name: `pilot` (white, vertex colour, rough 0.9), `paint` (takes the pilot's paint tint), `copper`, `class_accent`, `glass`, `bare_metal` (`hero_assets.gd:141-159`, `:283`).
- Copper, never brass: brass is the Furnace Fleet and the boss (`cosmetics.gd:29`). Every row's tint is already validated against the hostile hues, so the briefs keep the row tints.
- Nothing moves the weapon ring, hubs, sockets or kit nodes, and nothing enters the sight cone (CUSTOMIZE.md section 2, rule 4).
- **Trails:** one 2-triangle card per row, one shared 512×512 atlas (4×4 tiles of 128 px; tiles 0 to 5 are used). The emitter samples every 0.03 s, keeps at most 24 cards within 1.8 m, and turns each card to face along the ball's travel (`cosmetic_presentation.gd:6-8`, `:397`). Each card stays within 0.45 m wide and 0.25 m long, lives at most 0.45 s, and has alpha that peaks at 36/255 (README). The atlas holds alpha only; the row tint colours the card, so **one colour per trail**. The clip is one of the six existing clip shapes, or a new one built the same way.
- **Decals:** one tile in the 1024×1024 mask atlas (4×4 tiles of 256 px; tiles 0 to 7 are used, rows already point at 8 and 9). A white mark on the shared low-key underlay disc, in the row tint. `decal_shape()` in `build_cua.py` draws each tile; its last branch is a bare `else` (the moth, tile 7), so new tiles need `elif index == 7` first.
- **Outfits:** one GLB whose top-level nodes are named for `pilot-v1` bones (`head`, `goggles`, `spine_02`, and so on; `tools/blender/PILOT-RIG.md:23-40`). Each one mounts on a `BoneAttachment3D` (`hero_assets.gd:1202-1227`). `detail` budget: target 400 triangles (start), cap 1,500, 1 draw. A node named `Replace.<name>` hides the pilot's node `<name>`. An optional `AnimationPlayer` plays clips named like the pilot's (for example `ult_windup`). Cloth and leather use the `pilot` slot with baked vertex colour, so the paint tint does not recolour them. Rims and buckles use `copper`.
- **Readability.** The pilot sits inside a 0.98 m glass dome, seen from a 7.5 m chase camera. A head piece changes the silhouette; anything below the shoulders is mostly hidden by the pod and the weapon ring.

## Shells that are already built (5)

Each is a full variant base with the default heft layers borrowed for classes II to V, as CUSTOMIZE.md section 6's fallback allows. The registry rows name the recipe. Nothing to build. Andrew's check at the sitting: unlock it with the debug profile or by earning it, equip it in Camp, then Customize, and say whether it reads as different from the default shell.

| Item | What it looks like (sheet) | Recipe and evidence |
| --- | --- | --- |
| Felt Rig | Lattice struts wrapped in grey felt bands, rubber bushings at the pivot pins. Switchback noise control (`pilots/sable.md:323`). The muffled-roll sound stays a separable extra (CUSTOMIZE.md section 10). | registry `:4586`; `tests/world_one_shell_sable_test.gd:16` |
| Calibrated | Enamel scale marks on the struts, rubbed calibration bands, numbered drill steps (`pilots/rivet.md:310`). | `tools/blender/world_one/shell_rivet.py --variant calibrated`; registry `:4508`, 15 draws under the 16 cap |
| Redjaw Teeth | Bone-white replacement teeth with copper rivets on both ring blades and claw arms, and a spare-tooth rack (`pilots/tarn.md:352`). | registry `:4738`; 17-draw exception ruled at `docs/decisions.tsv:483` |
| Abacus Lattice | Copper abacus beads threaded on the struts (`pilots/tally.md:299`). The beads are static; "slide with speed" was not built. | registry `:4614`; 6,744 triangles (`docs/decisions.tsv:479`) |
| Choir Barrel | The barrel housing recast with the Mind's six choir shutters round the bore (`pilots/cannon.md:460`). | registry `:4342`; `tests/pilot_cannon_asset_test.gd:19` |

**Interaction with the paint trace.** A shell variant is geometry and vertex colour, so it shows whether or not paint fixes A1 or A2 land. If A1 (re-bake the lattice light) is chosen, these five variants must be re-baked too: the trace's list of "six shells" becomes eleven.

## Trails (7)

All seven go into `TRAILS` in `tools/blender/cosmetics/build_cua.py` as tiles 6 to 12 of `trail_atlas.png`, with a branch each in `trail_shape()`. Then `inspect_cua.py` and `dress_cua_assets_test` re-run as the README shows, and the manifest gains seven entries. The rows already carry the right `asset` ids.

### Cable Stitch (`trail_sable_cable`), Sable, tint `8bf0d3` mint

- **Look:** a dashed cable paid out behind the ball. Each card is one short rounded dash, so the 0.03 s samples string into a stitched line.
- **Part:** `BallTrail`.
- **Card:** node `CableDash`, 0.12 × 0.03 m (start), clip `fade`, life 0.35 s. Shape: a capsule (two end circles joined by a bar), so it reads as rope, not as Ink Stitch's flat stamp.
- **Reuse:** the `fade` clip and the `polygon` and `ellipse` helpers. Close to Ink Stitch (tile 1).
- **Change from the sheet:** the sheet wants mint and copper. A card has one tint, so the copper is dropped.
- **Call: keep.** It is Sable's cable read, it is cheap, and it is the only Sable item besides the decal.

### Swarf Curl (`trail_rivet_swarf`), Rivet, tint `ae7240` copper-brown

- **Look:** small curls of machining swarf left behind the ball.
- **Card:** node `Swarf`, 0.07 × 0.05 m, clip `tumble_fade` (Forge Chips' clip), life 0.30 s. Shape: an open spiral of about 1.5 turns, a thinner, shorter version of the snail-shell spiral in `decal_shape()` index 2.
- **Change from the sheet:** "thicker while sprinting" needs emitter code that reads speed. Dropped for alpha; a separable extra.
- **Call: keep.** It is cheap, and it is Rivet's only item besides the hood.

### Fuse Smoke (`trail_kest_fuse_smoke`), Kest, tint `8c8577` smoke grey

- **Look:** a grey smoke ribbon.
- **Card:** node `SmokeWisp`, 0.16 × 0.07 m, clip `expand_fade` (Moth Tuft's), life 0.40 s. Shape: one long soft ellipse with a pinched waist, so the overlapping cards read as one ribbon.
- **Change from the sheet:** the spark that crawls back along the ribbon needs emission, which trails may not have (README: no emission or additive blending). Dropped.
- **Call: keep.** It is cheap. With the harness cut (below) and the Roost Frame already live, Kest keeps two items.

### Claw Marks (`trail_tarn_claw_marks`), Tarn, tint `d2c5a5` bone

- **Look:** two parallel scored lines in the dirt, like claws dragged behind the ball.
- **Card:** node `ClawPair`, 0.40 × 0.06 m, clip `fade`, life 0.40 s. Shape: two thin strokes with ragged ends, 0.34 m apart (start), along the travel axis.
- **Change from the sheet:** the sheet's 0.6 m spacing is wider than the 0.45 m card cap, so the lines are narrowed to 0.34 m. "Broken every 1.5 m like tooth gaps" cannot come from one card at a 0.03 s sample rate. The ragged ends give a broken look instead.
- **Call: keep.** It is Tarn's drag read and it is cheap.

### Punch Tape (`trail_tally_punch_tape`), Tally, tint `f7f1e3` ledger cream

- **Look:** a ribbon of cream card tape with punched holes.
- **Card:** node `TapeStrip`, 0.14 × 0.05 m, clip `fade`, life 0.35 s. Shape: a rectangle with three round holes cut out on its centre line.
- **Watch:** near-white at 36/255 alpha may barely show on pale sand. It has the same risk as Salt Skip and the Ledger Cream paint (PAINT-TRACE finding 2). Andrew's eye decides at the sitting. The fix is a tint change, not new art.
- **Call: keep.**

### Recital (`trail_cannon_recital`), Cannon, tint `6fb3a6` pale verdigris

- **Look:** four small marks in family order behind the ball: a bar, a V, a ring and a quarter fan.
- **Card:** node `RecitalMarks`, 0.30 × 0.07 m, clip `fade`, life 0.45 s. Shape: the four marks in a row on one card, in the family order along the travel axis.
- **Change from the sheet:** the sheet's 0.6 s fade is over the 0.45 s cap, so it is 0.45 s. A sequence that cycles one mark per card needs emitter code, so the order is drawn on one card instead.
- **Call: keep.** It hints at the Cannon's hidden discovery, and that is the point of the item.

### Downbeat (`trail_any_downbeat`), any pilot, tint `8a5a3a` copper

- **Look:** copper ticks across the path. The skill bar's first-ultimate reward. It also draws during a set piece's flight (`cosmetic_presentation.gd:65`).
- **Card:** node `BeatTick`, 0.10 × 0.025 m, laid across the travel axis, clip `fade`, life 0.30 s.
- **Change from CUSTOMIZE.md section 8:** "spaced one beat apart" needs the emitter to sample on the music clock instead of every 0.03 s (`cosmetic_presentation.gd:8`). The art-only version is a dense tick row. Beat spacing is a separable extra for the coordinator, about 10 lines in `_step_trail`.
- **Call: keep.** Every player earns it early (the first ultimate), so a hidden one is the most visible gap of the 19.

## Decals (2)

Both go into `DECALS` in `build_cua.py` as indices 8 and 9, at tint `d2c5a5` and about 0.44 m square. They need branches in `decal_shape()`, then a re-run of the manifest and the test. The rows already point at masks 8 and 9.

### Spool and Wrench (`decal_sable_spool`), Sable, tile 8

- **Look:** a cable spool seen side-on (two flanges and a wound drum), crossed by an open-ended wrench on the diagonal (`pilots/sable.md:322`).
- **Part:** the decal surface every delivered decal uses (CUSTOMIZE.md section 2, `decal` row).
- **Reuse:** the `ellipse` and `line` helpers. The thimble (tile 3) shows how voids are cut.
- **Call: keep.**

### Curtain Call (`decal_curtain_call`), any pilot, tile 9

- **Look:** two stage curtains drawn apart over a cracked circle, a Warden core split by a zigzag. Earned by shattering an open Warden core with an ultimate (`SKILL-BAR.md:462`).
- **Reuse:** the drape folds can be the fern's leaf ellipses (tile 0) rotated and stacked down each side.
- **Call: keep.** It is cheap, and it is the only shared decal.

## Outfits (4)

Each is one new recipe under `tools/blender/` that exports `assets/cosmetics/outfits/<id>.glb`, plus a registry row, so `Cosmetics.asset_paths()` resolves the row's `asset` (`cosmetics.gd:216-228`). These are the only items that need a modelling pass. Test pattern: mount it on the pilot GLB with `fit_outfit_scene` (`hero_assets.gd:1190`) and check the triangle count, that it has one draw, and that it has no light.

### Welding Hood (`outfit_rivet_hood`), Rivet

- **Look:** a flip-up welding hood over the visor, in scuffed bone with a dark glass slot and a copper hinge pin (`pilots/rivet.md:309`).
- **Part:** node `head` (the shell) and node `goggles` (the lens plate), on the Rivet rig (`pilot_rivet_anim.glb`).
- **Animation:** an `AnimationPlayer` with one clip, `ult_windup`, that rotates the shell down about 70° over 0.12 s, then holds. Rivet's clip table already has `ult_windup` (`src/presentation/clips/rivet.json`), so `react()` plays both.
- **Reuse:** Rivet's head anchors in his shell recipe (`rig_pilot.py`), the `common.Part` helpers, and the `copper` slot.
- **Budget:** about 350 triangles (start).
- **Call: keep.** It is the only outfit that moves, so it proves the outfit clip route, and the snap-down on wind-up is readable from the chase camera.

### Eyeshade (`outfit_tally_eyeshade`), Tally

- **Look:** a mulberry visor with a copper rim, and sleeve garters (`pilots/tally.md:298`).
- **Part:** node `head` (the visor); `upper_arm.R` and `upper_arm.L` (the garters). Tally's rig uses the Rivet bone schema (`tools/blender/pilot_tally.py:55-58`).
- **Reuse:** Tally's head anchors in `pilot_tally.py`. Mulberry goes in vertex colour on the `pilot` slot, and the rim uses `copper`.
- **Budget:** about 300 triangles; the garters are thin rings of about 40 each.
- **Call: keep.** The visor is a strong silhouette on the head, and mulberry stands out against Tally's cream.

### Steady Cap (`outfit_tarn_steady_cap`), Tarn

- **Look:** a clean welding cap with one Redjaw stripe, in place of his battered one (`pilots/tarn.md:353`).
- **Part:** node `head`, plus an empty node `Replace.Cap` that hides the battered cap. That cap is already its own mesh node named `Cap` (`tools/blender/pilot_tarn.py:105`, `:206-207`, `:271-272`).
- **Reuse:** the battered cap's crown and brim code at `pilot_tarn.py:206`. Copy it, remove the dents, and add one stripe in vertex colour. This is the cheapest outfit.
- **Budget:** about 250 triangles.
- **Call: keep.** The split it needs already exists, and the before-and-after read is the joke ("Hold still. The machine, I mean.").

### Rigger Harness (`outfit_kest_rigger`), Kest. **Cut for alpha (confirmed by Andrew, 2026-10-16)**

- **Look:** a load rigger's harness with carabiners and a coil of tag line (`pilots/kest.md:396`).
- **Part:** `spine_02`, `shoulder.R` and `shoulder.L`.
- **Why cut:** it is the only outfit worn on the body, not the head. From the chase camera the pod and the weapon ring cover it, so it would add a modelling pass for an item players mostly cannot see. Kest's shoulders also carry the wing fans (`WingUpper`, `WingFan`), so straps there would clash with them and need a fit pass of their own. Kest keeps the Roost Frame shell and the Fuse Smoke trail.
- **If kept instead:** move the read to the head: a rigger's hard hat with a coiled tag line clipped to it, on `head`, about 350 triangles. That reads, and it stays clear of the wings.
- **What a cut does:** see "What cutting an item means" below.

## Companion skin (1)

### Till Bell (`companion_skin_till_bell`), SPIL-9

- **Look:** a small copper shop-till bell on SPIL-9's deck: a dome on a short post with a striker button (CUSTOMIZE.md section 8). It sits off the deck's centre line, so it stays clear of the socket collars.
- **Part:** a top-level node named `Deck`, mounted with `fit_companion_skin` (`hero_assets.gd:1274-1281`; it is painted with the class tint as accent).
- **Reuse:** SPIL-9's deck dimensions from `tools/blender/companion/build_spil9.py:156`, `:184`, and the `copper` slot.
- **Budget:** about 200 triangles, target 600 (start), 1 draw.
- **Check first:** that `Deck` is a skeleton bone in the shipped companion GLB, not only a mesh node. `_mount_on_bones` skips a part whose name is not a bone (`hero_assets.gd:1213`), and this has not been verified.
- **Call: keep.** It is the first companion skin, so it proves the slot. It is small, and SPIL-9 is on screen all run.

## What cutting an item means

A cut is not a delete. The plan is: remove the row from `ROWS` and from `PENDING_ART`, and remove the `reward` from its grant row in `achievements.gd`, so the achievement still unlocks and its toast shows the title only (`achievements.gd:182-190`). A save that already owns the id keeps the string. `CosmeticWear` reads the row, and an id with no row is never worn (`cosmetic_wear.gd:10`). This was inferred from the code; the profile's load path was not traced in full. Re-pin `tests/kest_kit_test.gd:345-354`, which lists the harness.

Optional: point the freed grant at a new Kest paint row. A paint needs no art, but the paint trace says a paint may hardly show on her lattice, so this is only worth doing after paint card A.

## Port notes for the wave coordinator

This PR adds only this file. These are the lines other files need, in order.

1. **Un-hide the five built shells.** `src/core/cosmetics.gd:27`: remove `shell_rivet_calibrated`, `shell_tally_abacus`, `shell_tarn_redjaw_teeth`, `shell_sable_felt` and `shell_cannon_choir` from `PENDING_ART`. Re-pin, with dated headers:
   - `tests/sable_kit_test.gd:318` becomes "Felt Rig is live": not pending, and the GLB exists (copy `kest_kit_test.gd:355`).
   - `tests/rivet_set_piece_test.gd:849-850`: only the trail and hood wait; the shell is live.
   - `tests/tally_set_piece_test.gd:645`, `tests/tarn_set_piece_test.gd:249`: check pending on the trail and outfit only, and keep the no-price check on all three.
   - Then run `customization_system_test` and `ui_customize_page_test`, which check that every non-pending row resolves to real art.
2. **Trails and decals.** `tools/blender/cosmetics/build_cua.py`: add the seven `TRAILS` rows and their `trail_shape()` branches, and add `DECALS` indices 8 and 9 with their `decal_shape()` branches (change the bare `else` to `elif index == 7`). Re-export, then re-run `inspect_cua.py --compare` and `dress_cua_assets_test`. Then remove the nine ids from `PENDING_ART`.
3. **Outfits and skin.** One recipe each and one registry row each, in `registry.d` or `assets/registry.json`, whichever the coordinator uses for new rows. Remove each id from `PENDING_ART` as its art lands.
4. **The cut (confirmed by Andrew, 2026-10-16).** Remove `outfit_kest_rigger` from `ROWS` (`cosmetics.gd:88`) and `PENDING_ART`, and remove the reward from `ach_kest_homecoming` in `achievements.gd`. Update the CUSTOMIZE.md section 8 totals (outfits 3) and re-pin `kest_kit_test.gd:345-354`. *Done 2026-10-16 with one change: the validator requires every achievement to carry a reward, so Homecoming now pays a new Kest paint, `paint_kest_rigger` "Rigger Blue" (the optional route below).*
5. **Optional extras, not part of alpha:** beat-spaced Downbeat emission, a thicker Swarf Curl while sprinting, the muffled roll for Felt Rig.

## How this was checked

- The 19 ids are read from `cosmetics.gd:27`.
- Built or not: a file check for each GLB or mask, its `assets/registry.json` row, and `git log` on each GLB (all from 1633f9a, w13-close).
- Atlas sizes come from the PNG headers: trail 512×512, decal 1024×1024. The tile layout comes from the manifest's `uv_rect` (0.25) and `MASK_TILES` (16).
- The trail limits come from `cosmetic_presentation.gd:6-8` and the cosmetics README. The outfit and skin mounts come from `hero_assets.gd:1182-1281`. The Tarn cap split comes from `pilot_tarn.py`.
- Not checked: the in-game look of any item, whether SPIL-9's `Deck` is a bone, the import colour space, and whether the trail tints read on each stage's ground. These need Godot on Andrew's machine.
