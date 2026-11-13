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

The two runner-up candidates cost 60 credits more (tasks 4ff28976-cb42-4c54-a38e-3f11ad6ff8d4 and
bf9a1416-9b54-4d86-9cc2-bc2f7b50791f). Counts are Godot's, from `tests/tripo_variants_test.gd`.

Wave 2 also generated a lobber hopper and a magnet cart (120 credits). Both were left out: swapping only
their body node left the authored sling, barrel and magnet discs floating or doubled. They need a
whole-model generation with the parts cut out instead. API spend after wave 2: 420 credits.
