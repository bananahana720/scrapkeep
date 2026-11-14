# Tripo-generated model siblings

Tripo (tripo3d.ai, CLI `tripo-cli`) turns a text prompt into a low-poly textured mesh. This folder turns
that mesh into a sibling of an authored model, `<stem>_tripo.glb` next to `<stem>.glb`. The game loads a
sibling only when it is launched with `--models=tripo` (`src/presentation/model_variants.gd`). Without
the switch, and for every model that has no sibling, the authored model loads as before. No authored file
is replaced. Andrew picks per model which one stays.

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
   `blender -b --factory-startup -P tools/tripo/tripo_fit.py -- --in <tripo model.glb> --ref assets/models/<dir>/<stem>.glb --out assets/models/<dir>/<stem>_tripo.glb --yaw <deg> --max-tris <cap> [--fit box] [--split "Part=zmax:0.22:rubber,..."]`
   - `--yaw` turns Tripo's +X forward onto the authored forward (-90 for camp models facing glTF +Z, 90 for world-one enemies leading along Blender +Y). The fitter prints each slot's centroid so a wrong turn shows: the accent slot (the visor, the eye) should sit on the forward side.
   - `--fit height` (default) matches the authored height. `--fit box` keeps the mesh inside the authored bounds, for enemies whose collider is that box.
   - `--split` cuts animated parts out by height band and slot, named as the authored nodes the code animates (`enemy_clips.gd` parts), pivoted at the authored node.
4. Add a row to `assets/registry.d/tripo_variants.json` with the task id and sha256, run `python3 tools/fold_registry.py`, and add the pair to `tests/tripo_variants_test.gd` with its ceilings.

Licence: the account is paid, and Tripo's terms (section 5.2, read 13 Nov 2026) leave the rights in the
outputs with the account holder. Outputs made on a free account are public domain under section 5.2.1.

## Receipts

| sibling | Tripo task | prompt | credits | tris (authored) | draws (authored) | fit |
| --- | --- | --- | --- | --- | --- | --- |
| camp/camp_pet_tripo.glb | 4bbd2038-8fe8-48d9-8fda-afda32599557 | prompts/camp_pet.txt | 30 | 2,000 (1,100) | 1 (1) | yaw -90, height, 8 sockets |
| world_one/enemy_chaser_tripo.glb | 6013f673-bd92-4d65-9bc4-7e6abff67f8c | prompts/enemy_chaser.txt | 30 | 3,175 (3,176) | 5 (5) | yaw 90, box, claws below 22 %, fin above 80 % (rubber) |
| world_one/enemy_boom_tender_tripo.glb (TenderHull only) | cfa436e8-08dc-42f8-b416-53dee2a7619b | prompts/enemy_boom_tender.txt | 30 | 7,375 (7,928) | as authored | tripo_swap.py, yaw 90, box |
| park/props/dam/gate_wheelhouse_a{,_lod1,_lod2}_tripo.glb | 7f215046-0286-4f10-b0cd-6d0121db046e | prompts/gate_wheelhouse.txt | 30 | 6,000 / 3,000 / 900 (16,588 / 8,294 / 2,488) | 1 | box |
| park/props/dam/mixer_wreck_a{,_lod1,_lod2}_tripo.glb | see registry row | prompts/mixer_wreck.txt | 60 (2 candidates) | 6,000 / 3,000 / 898 (12,740 / 6,370 / 1,904) | 1 | box |
| park/props/dam/survey_tent_a{,_lod1,_lod2}_tripo.glb | see registry row | prompts/survey_tent.txt | 60 (2 candidates) | 5,000 / 2,500 / 750 (8,840 / 4,420 / 1,326) | 1 | box |
| park/props/flume/skiff_on_blocks_a{,_lod1,_lod2}_tripo.glb | Studio workspace 91afa2b0-76cf-452c-8c73-050af720aee6 | typed in Studio, not saved | 20 Pro (texture; the Smart Mesh batch of 4 was free on the trial counter) | 5,435 / 2,700 / 799 (11,524 / 5,762 / 1,728) | 1 | yaw 90, box |
| park/props/flume/boom_crane_wreck_a{,_lod1,_lod2}_tripo.glb | Studio workspace 5accd8b9-3eec-4698-9050-615d8214c2d5 | typed in Studio, not saved | 20 Pro (texture) | 5,999 / 3,000 / 1,237 (17,782 / 8,890 / 2,666) | 1 | yaw 0, box |

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

## Pilots (a new body on the authored skeleton)

A pilot's sibling is `assets/models/pilot_<name>_anim_tripo.glb`. `hero_assets.gd` loads it through `ModelVariants.path` when the game runs with `--models=tripo`. The sibling keeps the authored armature, its 25 bones and every clip, so outfits, the glance and the pose tables work unchanged. Only the skin is new.

Make one in three steps:

1. Generate in Tripo Studio: HD Model, text input, model H3.1, Private (45 Pro credits). The prompt must name the species, the head shape, the eyewear, each outfit colour and "No tail" if the pilot has none. A loose prompt gave a monkey; a render of the authored model as the image input gave smeared colours and no added detail.
2. Fit it: `blender -b --factory-startup -P tools/tripo/pilot_fit.py -- --old assets/models/pilot_<name>_anim.glb --new <download>.glb --out fit.glb --head-scale 1.35 --neck 0.5 --tris 8200`. This scales the body to the authored height, enlarges everything above the neck line, cuts the mesh to 8,200 triangles (the pilot class allows 8,100 vertices, and Godot makes about 0.95 vertices per triangle here), bakes the texture to vertex colour, and copies the skin weights from the authored meshes posed to the new arm angle.
3. Tidy it: `blender -b --factory-startup -P tools/tripo/pilot_touch.py -- --in fit.glb --out assets/models/pilot_<name>_anim_tripo.glb --head 1.0 --fwd 0.57`. This slides the pilot back until nothing is forward of 0.57 (the dash is at 0.60) and tucks in a pink tail stub. Leave `--head` at 1.0: scaling the head by skin weights tears the back plate, because the authored head's weights reach the new shoulders.

Copy the authored model's tracked `.glb.import` settings to the sibling (everything after the `dest_files` line). `tests/asset_registry_test.gd` holds the sibling to the pilot class budget. Without the import settings Godot renames `idle_loop` to `idle` and the clip lookups miss. `tests/tripo_variants_test.gd` checks the bones, the clips, a 10,000 triangle cap and the cockpit limits from `design-v3/ROSTER-LOOK.md` ("The cutaway as built").

| Pilot | Prompt | Credits | Triangles, vertices | Rest box (x, y, z) |
| --- | --- | --- | --- | --- |
| Rivet | `prompts/pilot_rivet.txt` | 45 Pro (plus 90 on two rejected tries) | 8,200 and 7,811 (authored: 10,456 triangles) | -0.40 to 0.39, -0.54 to 0.43, -0.57 to 0.45 |
