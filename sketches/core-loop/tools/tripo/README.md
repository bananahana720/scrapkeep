# Tripo-generated model siblings

Tripo (tripo3d.ai, CLI `tripo-cli`) turns a text prompt into a low-poly textured mesh. This folder turns
that mesh into a sibling of an authored model, `<stem>_tripo.glb` next to `<stem>.glb`. The game loads a
sibling only when it is launched with `--models=tripo` (`src/presentation/model_variants.gd`). Without
the switch, and for every model that has no sibling, the authored model loads as before. No authored file
is replaced. Andrew picks per model which one stays.

**Accepted or rejected, per model (ruling dr).** `--models=tripo` loads only accepted siblings. To reject one,
add its own `res://` path and a one-line reason to `REJECTED` in `src/presentation/model_variants.gd`, and set
`"accepted": false` with `"accepted_why"` on its row in `assets/registry.d/tripo_variants.json`, then run
`python3 tools/fold_registry.py`. A prop has three files (the model and two detail levels), so reject all three.
`tests/tripo_variants_test.gd` fails when the list and the rows disagree. `--models=tripo-all` loads every
sibling, rejected ones too, so a rejected model can still be judged in the game.

Rejected today (14 November 2026, by the board's PC looks and the render check):

- No file is rejected today. The first generated chaser failed the render check below (view 1 sent 0.54 of the authored chaser's brightness, with loose black faces on the shell). A new chaser that passes replaced it and is accepted (see its row below); it still needs the PC look.
- The first generated sluice shed was rejected by the PC look of PR 1024 because it lost the big red water wheel. A second shed that keeps the wheel replaced it and is accepted (see its row below); it still needs the PC look.

**The render check (generated enemy models, from 14 November 2026).** `tools/model_render_check.gd` judges a
generated enemy from rendered pixels, because the light test passed a barrel twice that the game drew near-black.
It spawns each enemy in the real game, paused, and takes two views from opposite sides (view 0 and view 1). For each
view it finds the enemy's own pixels and measures the still the game draws: mean brightness, and the share of
near-black pixels. Shoot once with the authored models and once with `--models=tripo-all`, then compare:

```
source /home/andrew/scratch/world1/env-pc.sh <name> 1 1
gamescope --backend headless --prefer-vk-device 10de:2504 -W 800 -H 600 -w 800 -h 600 -- $GODOT_BIN \
  --path sketches/core-loop --gpu-index 1 --resolution 800x600 --audio-driver Dummy \
  --script res://tools/model_render_check.gd -- --out=<abs>/authored [--kinds=hooker,lobber]
<the same> -- --out=<abs>/tripo --models=tripo-all
$GODOT_BIN --headless --path sketches/core-loop --script res://tools/model_render_check.gd -- \
  --compare=<abs>/authored,<abs>/tripo --out=<abs>/sheets
```

The compare step prints one PASS or FAIL line per enemy, writes a side-by-side sheet per enemy (authored left,
generated right) and exits 1 on any FAIL. An enemy fails when, in either view, the generated model sends under
0.80 of the authored brightness or has more than 0.15 more near-black pixels. A shoot needs a graphics card, so
it does not run in `npm run sketch:fast`; run it on the PC before a generated enemy model is marked accepted.
Its first run (14 November 2026) failed the hooker, which the PC look had failed twice, and passed the lobber
and the swatter, which the PC look had passed. It also failed the netcaster and the chaser. It covers the
chaser, lobber, swatter, hooker, netcaster and boom tender. The boom tender's generated hull passed on the same
day (0.97 and 1.05 of the authored brightness); the tool turns off the shadows of its batched floats too, and
frames it by its meshes. A prop is still judged by the PC look. The number is for the whole enemy, so an authored mast or tool dilutes a dark swapped part: the
known-dark hooker scored 0.81 in view 0 and failed only in view 1. A result near the floor still needs the PC look.
A shoot stops with exit 2 on an enemy name it does not know (the game would spawn a chaser for it) and on any
model flag but `--models=tripo-all`.

| Enemy | View 0: brightness, near-black (authored) | View 1: brightness, near-black (authored) | Result |
| --- | --- | --- | --- |
| Lobber | 1.06, 0.02 (0.00) | 1.11, 0.04 (0.02) | pass |
| Swatter | 0.96, 0.00 (0.00) | 1.04, 0.10 (0.13) | pass |
| Hooker | 0.81, 0.12 (0.03) | 0.65, 0.33 (0.04) | fail |
| Netcaster | 0.86, 0.31 (0.09) | 0.82, 0.10 (0.10) | fail |
| Chaser | 0.95, 0.20 (0.12) | 0.54, 0.37 (0.04) | fail |

The chaser was regenerated as a tall slab and shot again on 14 November 2026: view 0 brightness 1.19 with 0.01 near-black (authored 0.12), view 1 brightness 1.02 with 0.04 near-black (authored 0.04), pass. Its legs are shorter and sit under the slab, so from behind and above they are mostly hidden; from the front the visor, the clawed legs and the fin all show.

The hooker and the netcaster were dark for one cause, found the same day: their generated faces read as fully in
shadow in the second UV set (see "Crew enemies", **The bake**). Both were refitted with the fixed tool and shot
again, with the swatter as the unchanged control:

| Enemy | View 0: brightness, near-black (authored) | View 1: brightness, near-black (authored) | Result |
| --- | --- | --- | --- |
| Hooker | 1.07, 0.01 (0.00) | 0.97, 0.01 (0.04) | pass |
| Netcaster | 1.05, 0.00 (0.01) | 0.82, 0.05 (0.04) | pass |
| Swatter | 0.97, 0.00 (0.00) | 1.03, 0.13 (0.15) | pass |

Both are accepted again. The netcaster's view 1 is near the floor, so it still needs the PC look. After a model
file changes, run `$GODOT_BIN --headless --path sketches/core-loop --import` before a shoot: a script run draws
the last imported copy, and a shoot taken before the import still showed the old dark barrel.

Earlier generated-mesh trials were rejected (docs/decisions.tsv rows 352 to 361, TADR-011): lumps at
budget, licence problems, colour loss. Row 361 allows a reopen "only with a different model class".
Tripo's v3.1 smart_low_poly mode is that different class, and Andrew asked for it on 13 Nov 2026. The
fitter answers the colour-loss finding: the texture never ships; each face takes the nearest colour of
the authored model's own palette.

## Make one

1. Write the prompt in `prompts/<stem>.txt` from the model's recipe header and STORY-MAP section 3
   (Fleet: oxide paint, charcoal, one brass tag, visible fasteners; three colours and one metal).
2. Generate two candidates (30 credits each, 13 Nov 2026 price):
   `tripo make "$(cat prompts/<stem>.txt)" --model tripo-v3.1 -p smart_low_poly=true -p face_limit=<cap> -n 2 --yes --json -o ~/scratch/tripo/<stem>`
3. Fit one to the authored model:
   `blender -b --factory-startup -P tools/tripo/tripo_fit.py -- --in <tripo model.glb> --ref assets/models/<dir>/<stem>.glb --out assets/models/<dir>/<stem>_tripo.glb --yaw <deg> --max-tris <cap> [--fit box|fill] [--radius <m>] [--slots "slot;x0,y0,z0,x1,y1,z1=slot;..."] [--split "Part=zmax:0.22:rubber,..."]`
   - `--yaw` turns Tripo's +X forward onto the authored forward (-90 for camp models facing glTF +Z, 90 for world-one enemies leading along Blender +Y). The fitter prints each slot's centroid so a wrong turn shows: the accent slot (the visor, the eye) should sit on the forward side.
   - `--fit height` (default) matches the authored height. `--fit box` keeps the mesh inside the authored bounds, for enemies whose collider is that box. `--fit fill` stretches each axis to fill them. `--radius` then narrows the mesh to stay inside a round hit core, and `--slots` gives faces their material slot by box when the texture's colours land on the wrong slot; the script's header has both rules.
   - `--split` cuts animated parts out by height band and slot, named as the authored nodes the code animates (`enemy_clips.gd` parts), pivoted at the authored node.
4. Add a row to `assets/registry.d/tripo_variants.json` with the task id and sha256, run `python3 tools/fold_registry.py`, and add the pair to `tests/tripo_variants_test.gd` with its ceilings.

Licence: the account is paid, and Tripo's terms (section 5.2, read 13 Nov 2026) leave the rights in the
outputs with the account holder. Outputs made on a free account are public domain under section 5.2.1.

## Receipts

| sibling | Tripo task | prompt | credits | tris (authored) | draws (authored) | fit |
| --- | --- | --- | --- | --- | --- | --- |
| camp/camp_pet_tripo.glb | 4bbd2038-8fe8-48d9-8fda-afda32599557 | prompts/camp_pet.txt | 30 | 2,000 (1,100) | 1 (1) | yaw -90, height, 8 sockets |
| world_one/enemy_chaser_tripo.glb | Studio workspace 2f2966ab-1a15-41d1-bc51-94a44505dede (replaces API task 6013f673, which failed the render check, and Studio workspace 2635ebdc, a squat wedge never shipped) | prompts/enemy_chaser_slab.txt | 240 Studio (two generations of four candidates, two textures) plus 30 API for the first | 3,176 (3,176) | 5 (5) | yaw 180, `--yaw 180 --fit fill --radius 0.97 --max-tris 3176 --slots "fleet_paint;-1,-1,-1.6,1,1.1,-1.02=rubber;-1,-1,1.0,1,1.1,1.6=rubber;-0.43,0.59,0.1,0.47,0.86,0.8=rubber;-0.37,0.45,0.12,0.42,0.745,0.78=requisition_tag" --split "ChaserClaws=zmax:0.22:rubber,ChaserFin=zmin:0.8:rubber"` (body fleet_paint, top and bottom rubber, visor frame rubber, visor panel requisition_tag; claws below 22 %, fin above 80 %). The Studio export it starts from is not in the repo; this command rebuilds the shipped file byte for byte from it |
| world_one/enemy_lobber_tripo.glb | 904d0a41-6627-44d7-a982-ce68527c27f0 | prompts/enemy_lobber_whole.txt | 120 (four candidates over two prompts) | 6,699 (6,720) | 5 (5) | tripo_fit.py, yaw 90, `--name LobberBody --max-tris 6700`, then lobber_parts.py |
| world_one/enemy_swatter_tripo.glb (SwatterBody only) | fbbb83dd-0bbc-4636-9f2b-172f3a03d2dd (the second candidate; the row named the first candidate's id until 14 November 2026) | prompts/enemy_swatter_body.txt | 60 | 2,753 (2,760) | 3 (3) | tripo_swap.py, yaw 90, `--fit fill --max-tris 2650 --bright match` |
| world_one/enemy_hooker_tripo.glb (the barrel and head of HookerBody only) | fbbb83dd-0bbc-4636-9f2b-172f3a03d2dd (the swatter body, used a second time; the first barrel, task 27fecf60-4f86-4d56-92cd-e06c64efbf31, 60 credits, was replaced on 14 November 2026) | prompts/enemy_swatter_body.txt | 0 (a candidate already paid for) | 6,381 (6,414) | 3 (3) | tripo_swap.py, yaw 90, `--fit fill --max-tris 6100 --bright match --region "-0.8,-0.8,-1.15,0.72,0.8,1.65" --crop "0.2,1"` (the crop drops the generated feet, after the PC look of PR 1029 noted them) |
| world_one/enemy_netcaster_tripo.glb (the control box of NetcasterBody only) | ff17498a-5ed6-4f6b-b933-5f27f62e4cab (the first swatter body candidate, unused by the swatter) | prompts/enemy_swatter_body.txt | 0 (an unused candidate) | 6,993 (7,048) | 2 (2) | tripo_swap.py, yaw 90, `--fit fill --region ... --max-tris 7000 --bright match` |
| world_one/enemy_boom_tender_tripo.glb (TenderHull only) | cfa436e8-08dc-42f8-b416-53dee2a7619b | prompts/enemy_boom_tender.txt | 30 | 7,375 (7,928) | as authored | tripo_swap.py, yaw 90, box |
| park/props/dam/gate_wheelhouse_a{,_lod1,_lod2}_tripo.glb | 7f215046-0286-4f10-b0cd-6d0121db046e | prompts/gate_wheelhouse.txt | 30 | 6,000 / 3,000 / 900 (16,588 / 8,294 / 2,488) | 1 | box |
| park/props/dam/mixer_wreck_a{,_lod1,_lod2}_tripo.glb | see registry row | prompts/mixer_wreck.txt | 60 (2 candidates) | 6,000 / 3,000 / 898 (12,740 / 6,370 / 1,904) | 1 | box |
| park/props/dam/survey_tent_a{,_lod1,_lod2}_tripo.glb | see registry row | prompts/survey_tent.txt | 60 (2 candidates) | 5,000 / 2,500 / 750 (8,840 / 4,420 / 1,326) | 1 | box |
| park/props/flume/skiff_on_blocks_a{,_lod1,_lod2}_tripo.glb | Studio workspace 91afa2b0-76cf-452c-8c73-050af720aee6 | typed in Studio, not saved | 20 Pro (texture; the Smart Mesh batch of 4 was free on the trial counter) | 5,435 / 2,700 / 799 (11,524 / 5,762 / 1,728) | 1 | yaw 90, box |
| park/props/flume/boom_crane_wreck_a{,_lod1,_lod2}_tripo.glb | Studio workspace 5accd8b9-3eec-4698-9050-615d8214c2d5 | typed in Studio, not saved | 20 Pro (texture) | 5,999 / 3,000 / 1,237 (17,782 / 8,890 / 2,666) | 1 | yaw 0, box |
| park/props/flume/sluice_shed_a{,_lod1,_lod2}_tripo.glb | Studio workspace 2c172e1b-a32c-4c10-b35f-b88b6b8b33fd, the third of four candidates (the first shed, workspace 05a306ba-03b8-48d6-bc96-2dd5d84cc071, 120 Pro, lost the wheel and was replaced on 14 November 2026) | prompts/sluice_shed_wheel.txt | 120 Pro (Smart Mesh set of four, then texture) | 4,434 / 2,217 / 1,502 (10,364 / 5,182 / 1,553) | 1 | tripo_prop.py, `--yaw 90 --name Surface --root sluice_shed_a --lod-name Surface.001 --tall 5.65 --max-tris 5500 --colours 10 --lods "0.5,0.34" --paint "3=#5a4030"`, and `--region "1.42,-2.6,1.25,2.45,2.3,4.3=#b8482c;1.42,-1.3,0.25,2.45,2.3,1.25=#b8482c"` (the wheel, and its lower half without the crates). The far level keeps 1,502 triangles because at 650 the plank roof tore open |
| park/props/dam/compressor_cart_a{,_lod1,_lod2}_tripo.glb | Studio workspace f54a0591-0944-401c-b714-88dbfc594ca6 | prompts/compressor_cart.txt | 120 Pro | 1,499 / 750 / 216 (1,500 / 750 / 222) | 1 | yaw 0, box |

The two runner-up candidates cost 60 credits more (tasks 4ff28976-cb42-4c54-a38e-3f11ad6ff8d4 and
bf9a1416-9b54-4d86-9cc2-bc2f7b50791f). Counts are Godot's, from `tests/tripo_variants_test.gd`.

Wave 2 also generated a lobber hopper and a magnet cart (120 credits). Both were left out: swapping only
their body node left the authored sling, barrel and magnet discs floating or doubled. They need a
whole-model generation with the parts cut out instead. API spend after wave 2: 420 credits.

## Tripo Studio (Pro credits)

The CLI spends API credits, a pool apart from the Pro subscription's Studio credits. Pro credits are spent
in the browser at studio.tripo3d.ai: Model, Smart Mesh, a text prompt, then Texture (20 credits) on the
candidate kept, then Export as GLB. The exported GLB goes through the same fitter. The flume skiff and
crane were made this way on 13 Nov 2026. Both come out smaller than the authored prop's footprint, because
the fit holds them inside the authored bounds: the skiff 4.7 m in a 7.9 m footprint, the crane (an upright
crane, where the authored prop is a fallen boom) 6.5 m in 13.9 m. The 4k Studio texture never ships.

## Ball parts (the part's own shape)

A part bolted on the ball is drawn from rods, boxes and discs by family (`src/build/accretion.gd`). With
`--models=tripo`, a part that has `assets/models/item_parts/part_<id>_tripo.glb` shows that mesh instead,
painted in its rarity colour, on the same tier foot. No texture is generated, so one costs 20 API credits:

`tripo make "<prompts/part_<id>.txt>, single small machine part standing upright on a round bolted base plate, chunky toy-like low poly game prop, bold readable silhouette, thick shapes, no thin wires, no text" --model tripo-v3.1 -p smart_low_poly=true -p face_limit=600 -p texture=false -p pbr=false --yes --json`

`blender -b --factory-startup -P tools/tripo/tripo_part.py -- --in <model.glb> --out assets/models/item_parts/part_<id>_tripo.glb [--cut-above 0.62]`

Tripo ignores `face_limit=600` here (it returned 666 to 1,818 triangles); the fitter caps at 1,000. Flat
shading and a 600 cap turned the shapes into lumps, so the fitter keeps smooth shading with hard edges past
40 degrees. Up to 24 parts show at once, so the worst case is 24,000 triangles on the ball.

| part | grade | Tripo task | tris | note |
| --- | --- | --- | --- | --- |
| slag_rounds | common | Studio workspace 44ee8e17-935e-4603-84d9-6ca1a0ffc3cd | 999 | Studio remake; the API version lost its shells (task 7b2b8357-c299-483c-afa6-50e6bc2bb95a) |
| focus_lens | common | be892f4e-97f8-47a1-8c98-4a1655baed60 | 958 | API |
| gatling_heart | rare | c23a12d9-a38e-49ef-975d-5d411112e897 | 999 | API |
| rime_heart | relic | Studio workspace 25af73fd-2017-412a-bcc9-cf59ea8e8a4c | 984 | Studio remake; the API version was a rounded lump (task 8b9f62cf-df90-4e81-b550-a45525a85e9c) |
| sunforged_core | rare | Studio workspace 677c84b5-e429-4af3-8c91-8b755b7811d2 | 946 | Studio |
| horizon_optic | rare | Studio workspace 81bbd92e-54ea-47be-9fdb-bc38b454836b | 1000 | Studio |
| tempest_core | relic | Studio workspace 40dd48a7-e75d-4641-b55e-f4a56a847933 | 782 | Studio |
| scrap_gravity | relic | Studio workspace 581ed437-8f40-48ce-aede-b92c7f34e99b | 999 | Studio |

Studio's Smart Mesh gives cleaner part shapes than the API's smart_low_poly at this size: set Topology to
Triangle and the polygon count to 1,000 under Customize Poly Counts, Privacy to Private, and type the whole
prompt (the Studio prompt files hold the full text, with no shared suffix to add). One Generate costs 100
Pro credits and returns four candidates whatever the Number of Generation says; export the one kept as GLB
with no texture step.

API spend after this batch: 500 credits, the cap Andrew set on 13 Nov 2026. Pro spend: 640 credits (40 on the
flume textures, 600 on six part sets).

### Free parts from unused candidates

Each Studio set returns four candidates and one is kept, so three are paid for and unused. A related part
takes one of them: the same motif runs down an upgrade line (shells for the rounds, scopes for range, bolts
for storm parts), and the rarity colour and tier foot tell the grades apart. Select the candidate in
Studio's Assets panel and export it; no credits are spent.

| part | grade | source | tris | cost |
| --- | --- | --- | --- | --- |
| magnet_spool | common | unused candidate of the scrap_gravity set | 822 | free |
| storm_mast | evolved | unused candidate of the tempest_core set | 999 | free |
| arc_coil | common | unused candidate of the tempest_core set | 873 | free |
| long_barrel | common | unused candidate of the horizon_optic set | 1000 | free |
| hot_rivets | common | unused candidate of the sunforged_core set | 1000 | free |
| double_feed | common | unused candidate of the slag_rounds set | 1000 | free |
| rime_rounds | rare | unused candidate of the slag_rounds set | 1000 | free |
| rivet_plating | common | unused candidate of the rime_heart set | 945 | free |

Cost per usable part on 13 Nov 2026: API low-poly 40 credits (2 of 4 tries usable at 20), Studio Smart
Mesh 100 Pro credits (6 of 6 sets), unused candidates 0 (8 of 8). With the free candidates counted, the six
Studio sets gave 14 parts, 43 Pro credits each.

### The rest of the catalogue (14 Nov 2026)

Every part in `src/build/parts.gd` now has its own shape: 46 files. The last thirty came from five more
unused candidates and eight Studio sets, one set per motif, with all four candidates of a set exported and
shared out among related parts. The set prompts are `prompts/partset_<motif>.txt`.

| part | source | tris |
| --- | --- | --- |
| grounding_spike | unused candidate of the tempest_core set | 927 |
| breaker_drive | unused candidate of the sunforged_core set | 1000 |
| drop_weight | unused candidate of the sunforged_core set | 825 |
| relay_convergence | unused candidate of the scrap_gravity set | 893 |
| galvanic_rounds | unused candidate of the slag_rounds set | 974 |
| tread_plating | tread set | 950 |
| spark_tread | tread set | 1000 |
| ram_plow | tread set | 951 |
| grip_tread | tread set | 1000 |
| long_spool | coil set | 947 |
| spring_shims | coil set | 1000 |
| boost_coil | coil set | 981 |
| slack_coil | coil set | 1000 |
| dash_vane | vane set | 825 |
| frost_vane | vane set | 897 |
| live_line | harpoon set | 982 |
| winch_pawl | harpoon set | 985 |
| riveted_shell | armor set | 840 |
| cracked_plating | armor set | 925 |
| thin_pickings | armor set | 936 |
| load_dividend | armor set | 877 |
| vent_baffle | fan set | 809 |
| bladestorm_rotor | fan set | 649 |
| spiral_wave | fan set | 775 |
| runner_overclock | fan set | 807 |
| pylon_capacitor | capacitor set | 912 |
| spare_cell | capacitor set | 978 |
| chain_arc | capacitor set | 1000 |
| cross_split | trigger set | 994 |
| loose_trigger | trigger set | 571 |

Eight sets cost 800 Pro credits and gave 25 parts, 32 credits each; the five unused candidates were free.
Seven set candidates were left out: two thin weather vanes, two spare harpoons, two spare cross guns, and
one capacitor whose body sat in a separate shell from its base, so the fitter kept only the base (136
triangles; check the count the fitter prints). A prompt that names a thin object (a weather vane) returns
thin rods whatever the suffix says, so name a chunky object instead (the vent fan set).

Pro credits left after this batch: 1,760 (Studio's counter). Pro spend so far: 1,440.

The fitter drops floating fragments by walking shells whose bounding boxes touch. A fragment that sits
inside another shell's box survives; pick another of the four candidates then (Scrap Gravity's first
candidate had a bolt lying beside its base).

## Props: one generated model for every variant of a kind

A prop kind has variants a, b and c, and each placement picks one at random (`park_props.gd` `expand`). Only variant a has a generated sibling. With the switch on, a variant with no sibling of its own draws a sister's sibling when the sister has one for every detail level, is no more than 1.1 times as wide and is within 15 percent of its height (`park_props.gd` `_stand_in`). A narrower sister is allowed, so a stand-in can look smaller than the prop it stands for: the compressor cart's variants b and c draw a cart 26 to 36 percent narrower. So every sluice shed changes with the switch, not one in three, and the low survey tent b keeps its own model because tent a is too tall for it. The PC look of 14 November 2026 found the nearest sluice shed unchanged by the switch: it was a variant b.

## Generated and not shipped

A generated model ships only when it reads at least as well as the authored one beside it. These did not, and the
authored model stays. Each is listed so nobody spends credits on the same attempt again.

| Model | What was tried | Why it did not ship |
| --- | --- | --- |
| park/props/flume/gauge_dial_shed_a | Tripo Studio, three textured candidates (`prompts/gauge_dial_shed.txt`, workspaces 2be99a2f and b3e31c1b-6c7e-462b-a5d6-2d4eaa3bfc48, 160 Pro credits in all) | The prop is about its chalk-white dial. The dial face came out grey, then teal, and never white, even with the authored colours named in the prompt. |
| park/props/dam/cable_drum_a | Tripo Studio, one textured candidate (workspace ba236b15-44b1-4c72-ac28-fbe3ef28433f, 120 Pro credits) | It textured as one dark colour, standing on its rims. The authored drum lies flat, with tan wooden ends and a wound grey cable. |
| The other crew enemies (bola thrower, deflector, gyro jammer, jolt layer, mag trapper, winch drone, catch trap, ramp flipper) | A spare generated torso swapped into the drum of the bola thrower and the deflector with `tripo_swap.py --region`, no credits | These enemies share one authored drum that carries the crew number plate. The generated torso reads no better and loses the plate. |
| world_one/enemy_netcaster (whole model) | See "Crew enemies" below | Its own test failed it. |

**Colour match by tint.** `tripo_fit.py --match tone` snaps each face to the authored colour of the nearest tint and
counts lightness at a quarter weight. Use it when a generated texture is a lighter or darker shade of the authored
paint, so a sky-blue wall lands on the authored teal and not on the pale grey. The default, `--match rgb`, is the
plain nearest colour.

## New props (no authored twin)

A prop that does not exist yet has no authored model to fit against. `tripo_prop.py` fits it on its own terms:

`blender -b --factory-startup -P tools/tripo/tripo_prop.py -- --in <tripo model.glb> --out assets/models/world_one/<stem>.glb --name <MeshName> --tall <metres> [--wide <metres>] --max-tris <cap> --lods "0.5,0.15"`

It scales the mesh to `--tall` metres (or to `--wide` metres across its longer ground side), stands it on its origin, groups the texture into eight flat colours of its own, writes them as linear `COLOR_0` on one material named `paint`, drops the texture and the UVs, and writes `_lod1` and `_lod2` files by decimation. With both `--tall` and `--wide`, the height and the ground plane are scaled separately. `--span "a:b"` moves points a metres either side of the centre to b metres, which sets an opening to a planned width, and `--paint "n=#rrggbb"` repaints found colour n when the generated texture misses the palette (the script prints the found colours). The loader must set vertex colour as albedo, as `src/presentation/park_props.gd` does. Register each file in `assets/registry.d/poi_props.json` with its Tripo task and sha256, run `python3 tools/fold_registry.py`, and add the stem to `POI_PROPS` in `tests/tripo_variants_test.gd`. `--region "x0,y0,z0,x1,y1,z1=#rrggbb"` repaints every face whose centre lies in that box (metres, Blender axes, after the fit), for a part whose colour the texture lost; each face keeps its lightness against the box's average, within 0.7 to 1.3, and a box that holds no face stops the script. `--root <name>` names the root node, for a generated sibling that must keep an authored prop's node names (the second sluice shed: `--name Surface --root sluice_shed_a`). `--lod-name <name>` names the mesh node in the detail-level files, where an authored prop names it differently (`Surface.001`).

A mesh generator returns a thin shape (a stake, a wire fence) as a lump. Build those by hand: `tools/blender/world_one/poi_yard.py` builds the fence panel, the survey stake, the ring flag and the siren mast in the same format, and the plain box props (the furnace stacks, the tagged crate and its pieces, the requisition locker and its door, the tag rack and the scooter shed), which are cheaper to build than to generate. `tools/blender/world_one/poi_parade_crew.py` makes the two parade crew from the stands' crew in `assets/models/bosses/arena_bowl_yard.glb`, with the hat and a sash repainted, so the parade is the same animal as the crowd.

World 1 points of interest, 14 November 2026 (API credits, text to model v3.1, smart_low_poly, face limit 4,000, two candidates each at 30 credits; 180 credits, 320 left after):

| Prop | Prompt | Tripo task kept | Triangles (LODs) | Size |
| --- | --- | --- | --- | --- |
| `world_one/poi_tally_stand.glb` | `prompts/poi_tally_stand.txt` | 8a6d32a8-84a9-4ad4-b963-121041481f76 | 3,998 (1,999, 598) | 2.9 by 3.0 m, 4.0 m tall (`--wide 3 --tall 4`) |
| `world_one/poi_yard_gate.glb` | `prompts/poi_yard_gate.txt` | 116aee24-7cd0-4233-a99d-7a90954303a4 | 4,000 (2,000, 599) | 8.0 m wide along Z, 4.0 m tall, 2.3 m deep (`--wide 8 --tall 4`) |
| `world_one/poi_camp_tally_post.glb` | `prompts/poi_camp_tally_post.txt` | 8b2f90eb-a287-4815-8a9e-58f1d89d3b62 | 1,999 (999, 296) | 2.5 m tall |
| `world_one/poi_fence_panel.glb` | built by `poi_yard.py` | none | 288 | 6.2 m wide, 2.5 m tall; repeat every 6.2 m, feet touching |
| `world_one/poi_survey_stake.glb` | built by `poi_yard.py` | none | 168 | 3.16 m tall, origin at the foot |
| `world_one/poi_weighbridge_gantry.glb` | `prompts/poi_weighbridge_gantry.txt` | Studio workspace e67eb1c6-c217-4e11-a2a1-b9c2798bbd08 (120 Pro) | 3,200 (1,598, 478) | 12.0 m wide, 7.0 m tall, 5.5 m deep, 8 m roll-over plate (`--wide 12 --tall 7 --span 3.1:4.0`, seven colours repainted with `--paint`) |
| `world_one/poi_ring_flag.glb` | built by `poi_yard.py` | none | 204 | 2.0 m tall, origin at the foot |
| `world_one/poi_siren_mast.glb` | built by `poi_yard.py` | none | 328 | 6.0 m tall, horn along +X, origin at the foot |
| `world_one/poi_furnace_stacks.glb` | built by `poi_yard.py` | none | 396 | 46.6 m wide, 60.2 m tall, for a 600 m view |
| `world_one/poi_tagged_crate.glb` | built by `poi_yard.py` | none | 204 | 1.2 m cube, brass tag on the front |
| `world_one/poi_tagged_crate_piece_{a,b,c,d}.glb` | built by `poi_yard.py` | none | 36 each | the four pieces a broken crate leaves, each with its origin at its centre |
| `world_one/poi_req_locker.glb` | built by `poi_yard.py` | none | 156 | 3.0 m wide, 2.5 m tall, 1.5 m deep, open at the front |
| `world_one/poi_req_locker_door.glb` | built by `poi_yard.py` | none | 120 | 2.56 by 1.8 m, origin at the hinge foot; place at (-1.28, 0.3, 0.7) on the locker and turn about the up axis |
| `world_one/poi_tag_rack.glb` | built by `poi_yard.py` | none | 444 | 3.0 m wide, 3.0 m tall, 2.0 m deep; tags face the front |
| `world_one/poi_tag_rack_leaning.glb` | built by `poi_yard.py` | none | 492 | the rack tipped 14 degrees with a seventh crate on the ground beside it; 4.6 m wide, 3.7 m tall |
| `world_one/poi_scooter_shed.glb` | built by `poi_yard.py` | none | 352 | 4.0 m wide, 3.0 m deep, 3.0 m tall with its pennant; the scooter stands inside at the origin |
| `world_one/poi_scooter.glb` | built by `poi_yard.py` | none | 316 | 1.6 m long, 0.64 m wide, 1.05 m tall; nose toward the shed's door, so place it at the shed's origin |
| `world_one/poi_parade_crew_cheer.glb` | built by `poi_parade_crew.py` from the stands' crew | none | 1,802 | 1.4 m tall, both mittens up; orange parade hat and sash |
| `world_one/poi_parade_crew_standard.glb` | built by `poi_parade_crew.py` from the stands' crew | none | 1,758 | 1.4 m tall, holding the tally pennant; orange parade hat and sash |

The stand and the gate came back narrower and taller than the placement asked for (2 m across, and 6.7 m tall), so both are fitted with `--wide` and `--tall` together, which scales the ground plane and the height separately. Look at the render when using both: these two chunky shapes take it, a thin or round one may not.

The runner-up candidates are tasks f5a7ba00-eb9f-4153-a98c-f80c4fc5fc28 (stand), 3caed186-71a7-42da-b675-1e4eb764475f (gate) and 90a8c17b-94b5-4bec-b359-f07be0b83963 (post). All six candidates were usable. The count boards came back with painted digits although the prompt said no text; they ship as flat colour patches, and the game should draw the live number itself.

## Crew enemies (a new body, the authored tool kept)

The Spillway crew are a body mesh plus a tool mesh (the swatter's paddle, the hooker's harpoon). The tool carries the enemy's warning, so it stays authored and only the body is swapped:

`blender -b --factory-startup -P tools/tripo/tripo_swap.py -- --in <tripo model.glb> --ref assets/models/world_one/enemy_swatter.glb --node SwatterBody --out assets/models/world_one/enemy_swatter_tripo.glb --yaw 90 --fit fill --max-tris 2650`

- **Colour.** The game paints the crew from vertex colour, and the two slots only say which surface flashes. `tripo_swap.py` sees this (a white slot beside a coloured one) and gives each face the nearest of the authored node's own vertex colours, in that colour's slot. Before 14 November 2026 it flattened such a body to one colour.
- **Size.** `--fit fill` stretches the new body to the authored body's bounds on each axis, so the collider, the tool's pivot and the enemy's height stay as they were. `--fit box` keeps the generated proportions and left the swatter half its height.
- **The enemy's own test decides.** Run `tests/enemy_<name>_asset_test.gd -- --models=tripo`. A whole generated netcaster failed it: the authored body is a frame with an open window where the game draws the net, and a stout generated robot put 804 triangles in that window (`prompts/enemy_netcaster_whole.txt`, task 76b8b5f4-ce6a-4468-8a4a-0fde6507f4d3, 60 credits, not shipped).
- **A body that holds a frame** (the netcaster). `--region "x0,y0,z0,x1,y1,z1"` (the node's own Blender space, Z up) swaps only the faces whose centres lie in that box and keeps the node's other faces as authored. The netcaster keeps its masts, crossbar and feet, and only its control box becomes a generated torso: `--node NetcasterBody --yaw 90 --fit fill --region "-0.5,-0.85,-1.15,0.5,0.11,1.0" --max-tris 7000`. The torso is the unused first swatter body candidate, so it cost no credits.
- **Brightness.** Add `--bright match`. A generated texture is darker than the authored paint, so many faces snapped to charcoal and the PC look of 14 November 2026 found the swatter and the hooker standing out less against the dam rock. The option lifts the sampled colours until the body's mean brightness (weighted by area, kept faces included) reaches the authored body's. The tool prints the new part's brightness and the brightness of the faces it replaced (`lum`, `lum_ref`); with `--region` neither is the whole-body mean, which only the test measures: `tests/tripo_variants_test.gd` (`BODIES`) fails a body under 95 percent of the authored one.
- **The bake.** An authored crew body has a second UV set that holds the polish bake (x: the share of the face out of shadow, y: edge wear), and the game multiplies the rust paint by it (`src/presentation/bake_look.gd`). With `--region` the kept authored faces bring that set along, and until 14 November 2026 the generated faces read (0, 0) in it, fully in shadow: the hooker barrel and the netcaster torso rendered near-black in the game while every calculated brightness passed. `tripo_swap.py` now writes the unshaded value (1, 0.5) on the generated faces. A whole-node swap (the swatter) has no second set and is not shaded.
- **Silhouette.** The hooker's authored body is a barrel beside a thin mast. Swapping the whole node stretched one robot over both and read as a tall block, so its swap is limited to the barrel with `--region`, as the netcaster's is.
- **What the camera gets.** The mean brightness above passed a hooker barrel that the PC look of 14 November 2026 showed as a thin near-black figure: the mean is taken over the whole node, mast included, and says nothing about how much of the body faces the camera. `tests/tripo_variants_test.gd` (`_part_seen`) now also adds up the light each body sends to a chase camera from four sides and holds the worst side to 0.65 of the authored body. That hooker barrel sent 0.48; the swatter and the netcaster, which the same look passed, send 0.71 and 0.81. Pick a generated torso that fills the authored barrel: a robot figure with legs and arms does not.
- **Skinned bodies** (the plated brute, the foreman, the dispatcher, the linker, the splitter) cannot be swapped by this tool. They need the pilot route below.

## The lobber (a whole model split into moving parts)

The game moves the lobber's tube and swells its bulb, so its file must hold three meshes at the authored pivots. `lobber_parts.py` cuts them out of a whole fitted model:

`blender -b --factory-startup -P tools/tripo/lobber_parts.py -- --in <tripo_fit output> --ref assets/models/world_one/enemy_lobber.glb --out assets/models/world_one/enemy_lobber_tripo.glb`

It squeezes the model inside the 2.4 m collider, finds the brass ball (the largest joined brass patch; it stops if that patch is not a ball on the axis), stretches the model so the ball's centre lands on the authored bulb pivot, scales the ball to reach 0.9 m from that pivot, as the authored bulb does, and cuts body, tube and bulb in the authored slot order. The prompt must ask for a brass ball joint between the chassis and the tube, and for an upright tube: the first prompt's leaning tube reached outside the collider and the lobber's own test (`enemy_lobber_asset_test -- --models=tripo`) failed it.

**A warning must never read weaker than the one it replaces** (the board, 14 November 2026). The first lobber shipped a 0.65 m bulb, and the PC look measured about half the bright area of the authored 0.9 m bulb before a shot. Any Tripo part that carries a tell (a glow, a swell, a raised tool) is sized to the authored part, not to what looks tidy on the new body.

## Pilots (a new body on the authored skeleton)

A pilot's sibling is `assets/models/pilot_<name>_anim_tripo.glb`. `hero_assets.gd` loads it through `ModelVariants.path` when the game runs with `--models=tripo`. The sibling keeps the authored armature, its 25 bones and every clip, so the glance, the pose tables and every outfit that mounts on a bone work unchanged. Only the skin is new, and it wears the same `pilot` material slot, so the game dresses it like the authored pilot.

Two things differ from the authored pilots:

- The head and everything on it (ears, jaw, snout, crest, goggles) moves as one piece with the `head` bone, and a tail does not wag. The new skin has weights for the pelvis (the legs move with it), spine, neck, head, shoulders, arms and hands only.
- A new head is bigger than the authored one, so a head outfit built for the authored head would be buried in it. A sibling that needs it carries a `MountFit_head` node under its head bone. `hero_assets.gd` (`_mount_fit`) reads the node's size and place and re-seats every part mounted on that bone. Tarn and Tally carry one; Rivet's hood already showed, so Rivet has none.

Make one in three steps:

1. Generate in Tripo Studio: HD Model, text input, model H3.1, Private (45 Pro credits). The prompt must name the species, the head shape, the eyewear, each outfit colour and "No tail" if the pilot has none. A loose prompt gave a monkey; a render of the authored model as the image input gave smeared colours and no added detail.
2. Fit it: `blender -b --factory-startup -P tools/tripo/pilot_fit.py -- --old assets/models/pilot_<name>_anim.glb --new <download>.glb --out fit.glb --head-scale 1.35 --neck 0.5 --tris 8200`. This scales the body to the authored height, enlarges everything above the neck line, cuts the mesh to 8,200 triangles (the pilot class allows 8,100 vertices, and Godot makes 0.74 to 0.95 vertices per triangle on these six), bakes the texture to vertex colour, and works out the skin weights (below).
3. Tidy it: `blender -b --factory-startup -P tools/tripo/pilot_touch.py -- --in fit.glb --out assets/models/pilot_<name>_anim_tripo.glb --head 1.0 --fwd 0.57` (the defaults). This slides the pilot back until nothing is forward of 0.57 (the dash is at 0.60) and tucks in a pink tail stub. Leave `--head` at 1.0.

Then measure it: `blender -b --factory-startup -P tools/tripo/pilot_pose_check.py -- assets/models/pilot_<name>_anim_tripo.glb`. It plays every clip and prints the share of edges that more than double in length in the worst clip. Keep that under 4 percent, and look at `big_cheer` and `heave` yourself; the table below has each pilot's number.

### How the skin weights are made

`pilot_fit.py` works the weights out on the new mesh. The first six siblings copied them from the authored mesh, and the PC check of 14 November 2026 failed four of them: a new body is fatter, so its belly took the weights of the authored arm that rests in front of it, and `big_cheer` pulled the belly up in sheets.

1. It finds each hand on the new mesh (between hips and neck, beside the body, level with or in front of the shoulder, so ears, crests and a tail never count) and aims a stand-in arm at it. The stand-in armature has one bone along each limb, because the imported bones are short stubs that all point forward. It also has helper bones for the legs and the snout, which fold into the pelvis and the head, so those parts do not take the weights of a hand beside them.
2. It makes a watertight voxel copy of the mesh, gives it Blender's automatic weights from the stand-in, and copies the weights back to the mesh.
3. It removes forearm and hand weights from skin that is not joined to a hand (a whisker tip beside a control stick).
4. It gives skin the head mostly owns (half its weight or more) to the head alone. A cheek modelled beside a hand otherwise takes shoulder and upper arm weight, and a cheer pulls a dark split open in it. Only Tally was refitted with this rule; the other five passed the PC check without it.
5. It settles each bridge. A bridge is skin that joins a hand straight to the belly, legs or head: a hand modelled resting on the chest, or a control stick modelled from the hand down to the boot. Each bridge vertex goes wholly to one side. `--bridge` (default 0.5) sets the share the arm needs to take it. `--cut 1` also removes the few faces left spanning the break, so a raised hand lifts its stick clear instead of stretching it; that leaves a small open edge.
6. It carries the arms from where the new mesh has them to the authored rest pose.

`pilot_touch.py --lift <metres>` raises the whole pilot in the seat. Use it when the ball look measure (`tools/ball_look_capture.gd`, line 75 percent of the pilot seen) comes in low: Tally measured 74.2 percent on the PC check of 14 November 2026 and 76.7 percent with `--lift 0.04`. Keep the head top at or under +0.57, and add the lift to the `--mount-fit` up number. Do not combine it with `--cap-hue`: the cap split measures from the head bone, which the lift does not move.

### Head outfits

`pilot_touch.py --mount-fit "<size> <right> <forward> <up>"` adds the `MountFit_head` node: the outfit grows by the size about the head joint and then moves by the offset, in ball model units. Pick the numbers by eye from a render with the outfit on. `--cap-hue "<low> <high>"` splits a modelled cap of that hue (0 to 1) into its own `Cap` mesh, as authored Tarn has, so an outfit's `Replace_Cap` node hides it (`design-v3/CUSTOMIZE.md`). The body keeps those faces, pressed onto the skull and painted fur colour, so the head is whole under the outfit. `tests/tripo_variants_test.gd` checks that Tarn's Steady Cap hides and covers his modelled cap, that Tally's Eyeshade reaches the front of the head, and that Rivet's hood mounts as before.

Copy the authored model's tracked `.glb.import` settings to the sibling (everything after the `dest_files` line). `tests/asset_registry_test.gd` holds the sibling to the pilot class budget. Without the import settings Godot renames `idle_loop` to `idle` and the clip lookups miss. `tests/tripo_variants_test.gd` checks the bones, the clips, a 10,000 triangle cap, the `pilot` material slot and the cockpit limits. The limits are the ball look work's measurements of 13 November 2026, in ball model units: head top no higher than +0.57, feet no lower than -0.59, half width at most 0.43, nothing forward of 0.58 (the dash is at 0.60). `design-v3/ROSTER-LOOK.md` ("The cutaway as built") describes the cockpit they come from.

| Pilot | Prompt | Credits | Triangles, vertices | Options beyond the defaults | Edges doubled, worst clip (before the refit) |
| --- | --- | --- | --- | --- | --- |
| Rivet | `prompts/pilot_rivet.txt` | 45 Pro (plus 90 on two rejected tries) | 8,149 and 7,784 (authored: 10,456 triangles) | fit `--cut 1` | 1.3% in `big_cheer` (6.1%) |
| Sable | `prompts/pilot_sable.txt` | 45 Pro | 8,029 and 6,396 | fit `--bridge 0.2 --cut 1` (the sticks run down to the boots) | 0.4% in `wince` (7.5%) |
| Kest | typed in Studio and not saved here; it is in the Tripo account's history | 45 Pro | 8,200 and 6,856 | none | 3.4% in `big_cheer` (7.4%) |
| Tarn | typed in Studio and not saved here; it is in the Tripo account's history | 90 Pro (the first try stood upright and tore when seated) | 8,546 and 6,360, in two meshes (`Pilot` and `Cap`) | touch `--cap-hue "0.40 0.56" --mount-fit "1.6 0.008 -0.04 -0.14"` | 0.1% in `heave` (2.1%) |
| Tally | typed in Studio and not saved here; it is in the Tripo account's history | 45 Pro | 8,200 and 6,537 | touch `--lift 0.04 --mount-fit "1.32 0 0.062 0.109"` (refitted 14 November with the head rule, step 4) | 1.3% in `ult_strike` (5.1%) |
| The Cannon | typed in Studio and not saved here; it is in the Tripo account's history | 45 Pro | 8,199 and 6,562 | none | 1.3% in `big_cheer` (6.7%) |

The refit of 14 November 2026 used the saved Studio downloads and cost no credits. The authored pilots measure 0.0 to 0.1 percent. The measure is taken in Blender; the look in the game is the board's PC check.

Every sibling's rest box is inside the cockpit limits; `tests/tripo_variants_test.gd` prints each box.

What the six taught:

- Ask for the pose in the prompt: seated, knees bent, both arms reaching forward to hold two control sticks. An upright model with arms at its sides tears when the seated clips bend it.
- `pilot_fit.py` replaces every authored skinned mesh by default (`--drop all`): body, claws, tail, wings and cap.
- Tripo models the control sticks and often joins them to the boots, and models hands resting on the chest. Both are bridges (above). If a clip stretches a stick or a boot, refit with `--cut 1`.
- `pilot_touch.py` centres a pilot that fits the width but sits off centre, and narrows a pilot wider than 0.86 (twice `--half`, default 0.43) evenly about its centre and prints the factor (Kest, 6 percent). Pass `--tail 0` for a pilot that has a tail.
- After copying the import settings, `touch` the sibling's `.glb.import` before running `godot --headless --import`. Godot compares change times to the second, and skips a file whose settings changed in the same second it was first imported; the clips then keep Godot's default names (`idle`, not `idle_loop`). `*.import` is ignored here, so add the sibling's file with `git add -f`, as the authored pilots' files are.
