# World 1 visual assets critique (12 Nov 2026)

Andrew asked on 12 November 2026 for a deep and wide design critique of world 1, split by silo. This page is the visual assets silo: models, materials, colour and light, item and pickup art, HUD and icon art, style and stand-ins. Effects (VFX, hit feedback, telegraph look, screen effects) belong to the effects critique and play design to the gameplay critique; what this page found for them is passed on at the end. Every finding is a row in [BACKLOG.md](../../../../BACKLOG.md#world-1-and-scaling-backlog-12-november-2026): W1-21 to W1-29, W1-46 to W1-48 and SG-13 to SG-16.

Read at `cand/w40` 6b9cb42e (`stage/alpha-w39` 618dfc9b plus one commit). Verdict: **FAIL** against the alpha's "zero placeholders" bar, **PASS+NOTES** on the rest.

## The headline

World 1 does not meet "zero placeholders" yet, and the release check cannot tell. `scripts/placeholder-gate.mjs` reads park rows, icons and lists, so it passes; it cannot see a mesh the game builds from a Godot primitive. A bot run through the whole world (dam, flume, Brindle) drew 179 kinds of primitive surface; 81 of them belong to things a player meets as objects, not marks or effects: the cogs and dropped panels, the ambush altars, the cracked caches and the four field finds behind them, the pocket interiors, the radio caches, contraption doors and a geyser base, and the Slag Bowl's masts and vents.

The models graded on 10 November in the sight persona's audit ([SIGHT-PERSONA.md](../../../../sketches/core-loop/design-v3/SIGHT-PERSONA.md), the look direction for Scrapkeep's models) have not changed since (`git log --since=2026-11-10 -- tools/blender assets/models` shows only lift drums and flume scrap), so its grades stand. This page adds what it did not cover: stand-ins built in code, the item rarity read, HUD and icon art, the title and the landscape.

```
                         hold          close             off
pilots, balls, panels    ███
camp, Moss, launch gate  ███
rogues (crane 14)        ███
Slag Bowl, stage clear   ███
Spillway machines (12)                 ███
Wardens                                ███
flume piers and walls                  ███ plain faces, no wear
Brindle ship                           ███ petrol (taste call at the sitting); armour panels blank
item read (rarity)                     ███ colour only on gems and parts
HUD and icon art                       ███ token drift, 13 icons off spec
Spillway crew (12)                                       ███ one barrel body
dam landmark                                             ███ flat slabs
title scene                                              ███ code deck, plain wordmark
code-built stand-ins                                     ███ the placeholder bar
```

## Evidence and its limits

- **PC pictures of `cand/w40`** (12 Nov, RTX 4080, Vulkan, 1080p, headless gamescope): a first-timer film (156 pictures, title through Brindle), all 23 world 1 enemies close up, and 93 stills of the screens around play. Private page "World 1 visual critique stills", https://claude.ai/artifact/CxLxtaq7QGDMtQjqXJHtKA. Job: `art-direction/pc-jobs/visual-critique-w40.md` in the Library.
- **A primitive census** (the strongest evidence here: real code was run and would show the fault if it were wrong): `tools/bot_run.gd` with a scratch scan every 30 ticks that prints each visible surface (render layers not 0, so the hidden greybox under a dressed model is skipped) whose mesh is a Godot primitive, once per owner and path. Cloud, headless, `--table=park --policy=skipper --pilot=pylon_engineer --seeds=40317 --until=2`, 33,268 ticks, 370 game seconds, through Brindle. Output and the scratch script: `art-direction/critique-w40/prim-census-cand-w40.log` and `prim_census_scratch.gd` in the Library. SG-13 turns it into a check.
- **Code reads** at `cand/w40`, each with `file:line` (pointed at, not run).
- **Older pictures**: PC stills of 10 Nov (build 1c9bc643, page "Art Direction PC Stills") for the dam, and the Blender audit sheets of 9 Nov (`art-direction/sheets/`). The models in them are unchanged.
- **Annotated stills** for this page: `art-direction/critique-w40/01` to `05` in the Library.
- Not judged: feel, motion at play speed beyond the snap counts on record, sound. A blind read of the new findings was not run; findings 2 and 4 rest on earlier blind reads and on measurement.

## Findings, ranked by how much they change the sitting

### 1. Things the player meets are drawn as plain shapes (W1-21, W1-22, W1-23, W1-46)

| What the player sees | Built at | A model exists? | Row |
| --- | --- | --- | --- |
| Cogs, the money, on the ground: an 8-sided brass disc | `src/build/scrap_field.gd:122` | no | W1-21 |
| A dropped grey panel: a slate box under a bone column | `scrap_field.gd:129`, `:348` | the 12 panel models are used only on the ball | W1-21 |
| Ambush altar: a cylinder with a brass box cap | `src/world/activities.gd:936` | **yes**, `world_one/ambush_altar.glb`, loaded only on the device path (`ambush_altar.gd:21`) | W1-22 |
| Cracked cache, and the four field finds that use its wall (turbine hall, shift radio, trestle seep, crew radio): a 12 by 9 m box wall, box cracks, box sides, a cylinder pedestal, a box notice board | `activities.gd:942`, `:979`, `:1069` | **yes**, `world_one/cracked_cache.glb`, loaded only on the relic cache path (`cracked_cache.gd:60`) | W1-22 |
| The pause menu's build preview: a grey sphere where the ball should be (still 04) | `src/ui/build_read.gd` | the pilot shells | W1-46 |
| Pocket interiors: striped blocks | `activities.gd:891` | no | W1-23 |
| Signal radio cache: pole, half sphere, bulb, ring | `src/world/radio_cache.gd:93` | no | W1-23 |
| Valve doors and bulkheads (12 by 6 m boxes) and the geyser's base | `src/world/contraptions.gd:919` (`_build_valve`), the launcher build at `:760` | no | W1-23 |
| Slag Bowl crane masts and rim vents | `src/boss/arena.gd:434`, `:496` | no | W1-23 |
| Trade spots: boxes and cylinders with brass studs | `src/world/stake_devices.gd:204` | no (ruled after the sitting, ruling ci) | W1-23 |
| Title scene: a plank deck, canal lip and pipes, all code (still 03) | `src/presentation/title_stage.gd:439` | no | W1-47 |

Two of these have finished models that the park path never loads. That is the cheapest fix on this page (W1-22), and it also fixes the field finds, which are the completionist run's secrets. The cogs and dropped panels are the most seen: a player picks up dozens a run, and a brass disc is the game's money.

One result to check before it becomes a row: in the census run the flume's reward gates drew their code posts and toppers (tick 23,340) while the dam's gates were dressed. `hero_assets.gd` `_dress_gate` gives up silently when it cannot match a gate to an offer (`:2058`). The PC film's flume gates (still 0107) are too far away to tell. W1-22's builder checks it with the census before and after.

### 2. Twelve Spillway crew kinds share one body (W1-24, before the sitting)

The PC close-ups show it at once (still 01): the bola thrower, catch trap, gyro jammer, hooker, jolt layer, mag trapper, netcaster, swatter and winch drone are one rust barrel with two ear cones and a snout, told apart by a thin tool. In the blind outline read of 10 November, five readers named the job of 11 of 24 kinds; the brute read as crates, the deflector as a mushroom, the netcaster as a gong and the bola thrower as a bottle ([SIGHT-PERSONA.md](../../../../sketches/core-loop/design-v3/SIGHT-PERSONA.md) section 7). The fix is sized: a head per kind from its old job, a cast number and HIRED on each. It ranks second because the comic direction needs a crew a player remembers by face and pose, and today the crew is the least characterful thing on screen. SG-14 makes it cheap.

### 3. The dam, world 1's namesake, is flat slabs (W1-25, before the sitting)

`landmark_dam` is the only dam the park draws (one row in `park_dam.json`). On the PC it is a wall of flat beige planes behind the launch (still 02, 10 Nov build; the model is unchanged). Its mid and far meshes are the same slab. It is the largest object in the first stage and the backdrop of the Warden yard, and it shows none of a dam's parts or its crew: no gate bays, buttresses, penstocks, catwalks, stains or wear. The penstock tower and the flume trestle beside it read far better. The flume's piers and walls (film 0083 to 0098) are a lesser case of the same thing: designed shapes with flat faces and no 2010 finish. The 31 plain banks and drops in the dam map are terrain by ruling and are not counted.

### 4. Item tiers are told apart by colour alone in three places (W1-26)

[VISUAL-LANGUAGE.md](../../../../sketches/core-loop/VISUAL-LANGUAGE.md) section 2 says each rarity has a frame "so colour never carries it alone". Three places break that:

- pedestal gems are one octahedron for every tier (`src/world/cracked_cache.gd:134`);
- part pieces on the ball take their shape from the part and their tier only from colour (`src/build/accretion.gd:262`);
- shop frames for relic and evolved differ only by a 1 px width (`src/ui/shop_tile.gd:28`).

Measured with the Machado matrices in CIELAB: relic amber against evolved green is ΔE 80 in normal vision and 22 under deuteranopia; amber against brass is ΔE 16 and 3. The reward gates are fine: `reward_gate.glb` carries a topper per tier.

### 5. The money is drawn in Brindle's colour (W1-21)

BRASS is reserved for Brindle and the Fleet's requisition tags ([VISUAL-LANGUAGE.md](../../../../sketches/core-loop/VISUAL-LANGUAGE.md) palette table). The cogs (`scrap_field.gd:121`) and the HUD wallet (`src/ui/hud.gd:44`) are brass, and to a deuteranope brass and the relic's amber are the same colour. W1-21's cog takes worn steel with a bone rim. Assumption Andrew can overturn.

### 6. The title has no art of its own (W1-47, before the sitting)

The first screen is plain orange type over a plank deck built from code boxes, floating on teal (still 03). For a melodramatic comic game the title is the poster, and today it reads as a debug view. The sight persona's typeset-signs and 2010 gig-poster lettering already point the way. It needs a taste page (ruling cq) with two or three candidates and a PC check.

### 7. Brindle's armour panels are blank slabs up close (W1-48, before the sitting)

The boss's plating is the part the player hits most, and at ram distance it fills the screen as flat panels with a few lines (still 05, film 0124, where they also draw near white). They need edge bevels, stencils and the bolt pattern the persona gives keepers' gear, and the whiteness needs a cause first (a hit flash or the plating tint is the likely one; passed to effects).

### 8. Fleet machines go near black in the dam's dawn shade (watch list)

Judged on 10 November: in the yard's shade, rust paint drops to about sRGB 47 to 61 against ground at 73, 58, 42. A pale edge on hostile bodies is the fix, with its 4080 cost measured first. It stays on the sitting watch list.

### 9. HUD art has drifted off its tokens (W1-27)

Five HUD parts in play use no tokens: the ability bar (`ability_bar.gd:31`, gaps 14, 5 and 7), the aim reticle, the speed glyph, the danger mark and the restart meter. The achievement and lore plates use radius 8 and alpha 0.94 against the tokens' 6 and 0.92 (`hud.gd:426` and `:429`, `:478` and `:481`). `build_read.gd:105` sets a 40 px font, off the scale. Four camp and card screens use radius 8 or 10. Each is small; together they are why the HUD reads as several hands.

### 10. Thirteen hand-drawn icons break the icon spec (W1-28)

`assets/icons` holds 118 SVGs; 105 come from `tools/icons/generate_icons.py` and match it. The 13 hand-drawn ones (`ab_<pilot>_line`, `ab_<pilot>_ult`, `res_mass`) use stroke 5 or 3 against the spec's 6 and 4, six have no charcoal backplate, Kest's and Tarn's are in Rivet's copper, and `res_mass` is three filled dots beside outlined neighbours. They are the ability icons the player reads every few seconds.

### 11. Mesh faults that show at distance (W1-29)

From the fault scan of 10 November, still true: 94 of 286 park prop far meshes carry faces lit inside out, seven over 10% of their area (cable drums, the spool shed, knot boards, rope baskets); on the PC the far cable drum went dark at 80 m and streaked at 100 m. The fix is one function, `tools/blender/park/props/kit.py` `decimate()`.

### Taste calls

Andrew answered on 12 November 2026: the four look rebuilds (crew heads W1-24, the dam W1-25, the title W1-47, Brindle's plates W1-48) all land before the sitting. The stand-ins (W1-21 to W1-23, W1-46) were never part of that question, because the sitting's zero-placeholders bar already needs them. Brindle's petrol hull is already on the sitting watch list with a charcoal alternative mocked. The dam and the title each start from a taste page (ruling cq). The cog's steel colour (W1-21) is an assumption he can overturn.

## Passed to other threads

- **To "Critique world 1 effects":** the near-white Brindle plates in film 0124 (flash or tint?); the rainbow arc and pale beacon ring over the ball at the Warden yards (film 0048, 0056); the seven code-written marks that draw paler on the PC than designed (vertex colour switch); `daze_halo`, the only stun sign, draws at most 23 px; flood foam reads as stacked pale blocks from 60 m.
- **To "Critique world 1 gameplay design":** nothing that changes play.
- **To the board thread:** `tools/enemy_capture.gd`'s close camera cuts the tall kinds off (Shift Boss, miniboss, hooker in the 12 Nov stills); fit the camera to each body's bounds before the next enemy sheet.

## Rows for worlds 2 and 3: how the asset pipeline scales

The stand-ins in finding 1 exist because nothing counts what the game draws from code. The crew look alike because each recipe builds its figure by hand. Four rows fix the pipeline and leave world 1's look unchanged.

| Row | What it makes cheaper |
| --- | --- |
| SG-13 | The placeholder gate sees code-built meshes: the primitive census as a tool and a test, run through each stage of a world, against a list of the marks, rings and fallbacks meant to be code. A new one fails. World 1's 81 start pinned and the pin falls as W1-21 to W1-23 land |
| SG-14 | One crew kit for enemy figures: head, snout, ears, number plate and HIRED stencil as functions in a shared recipe module (the stencil lives in `tools/blender/rogues/kit.py` today), so a world 2 or 3 crew kind is a few lines and W1-24 is a swap per kind |
| SG-15 | One palette for recipes: the Blender kit and the icon generator read `src/core/palette.gd` instead of restating it (`item_panels.py:39`, `generate_icons.py:18`), so a colour change is one edit and STEEL `9aa0a0` joins the palette |
| SG-16 | The far-mesh fault check on every park prop: `model_audit.py faults` on the LOD files in the props kit's test, with a ceiling on inside-out area, so world 1's 94 cannot recur in worlds 2 and 3 |
