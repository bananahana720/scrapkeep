# Shared pilot rig

`rig_pilot.py` builds Rivet, Sable and Kest with the same 25-bone `pilot-v1` hierarchy. Each shell recipe supplies the head geometry and its anatomical anchors. `shell_base.spherical` supplies the common seated body and control positions. Rivet retains the accepted rest transforms and original 16-pose table. Its new accessory bones carry no geometry.

The models are in `sketches/core-loop/assets/models/pilot_{rivet,sable,kest}_anim.glb`. The shell recipes remain unchanged. Sable adds a two-part tail and a wrench; Kest adds four small feather fans. The complete pilot meshes contain 4,248, 4,592 and 4,492 triangles respectively.

## Import

All three GLBs contain exactly one action, `drop_land`, at 30 fps. Rivet and Sable span 0 to 2.166667 seconds; Kest spans 0 to 2.2 seconds. Play it once. The immutable pose tables retain their original 1–34 frame labels; `pilot_drop_timing.py` overlays the current 1–66/67 timing without changing pose values. GLB time starts at zero. No root motion is authored.

Place the rig at identity under the existing upright cockpit parent, replacing the static pilot. The origin is the sphere centre. Keep scale at `(1, 1, 1)`, matching the existing 0.98-unit glass radius. Blender uses +Z up and +Y forward; glTF uses +Y up and -Z forward. One model unit is one engine unit. The pelvis remains at Blender `(0, 0, -0.3)`, or glTF `(0, -0.3, 0)`.

| Pilot | Rig node | Skinned mesh nodes |
| --- | --- | --- |
| Rivet | `RivetRig` | `Pilot`, `Claws.R`, `Claws.L` |
| Sable | `SableRig` | `Pilot`, `TailBase`, `TailTip`, `Tool` |
| Kest | `KestRig` | `Pilot`, `WingUpper.R`, `WingFan.R`, `WingUpper.L`, `WingFan.L` |

Each file has one skin. Preserve animated nonuniform scales, which carry the squash. Optional controls remain in every skeleton, even when unused. Anatomical R is Blender +X. Godot's generated Skeleton3D/AnimationPlayer node paths have not been qualified; the names above are verified GLB node names.

## Bone hierarchy

| Bones | Parent |
| --- | --- |
| `root` | None |
| `pelvis` | `root` |
| `spine_01` | `pelvis` |
| `spine_02` | `spine_01` |
| `neck` | `spine_02` |
| `head` | `neck` |
| `snout`, `goggles`, `ear.R`, `ear.L`, `crest`, `jaw` | `head` |
| `shoulder.R`, `shoulder.L` | `spine_02` |
| `upper_arm.R/L` | Corresponding `shoulder.R/L` |
| `lower_arm.R/L` | Corresponding `upper_arm.R/L` |
| `hand.R/L` | Corresponding `lower_arm.R/L` |
| `curl.R/L` | Corresponding `hand.R/L` |
| `tail.01` | `pelvis` |
| `tail.02` | `tail.01` |
| `tool.R` | `hand.R` |

The tail, crest, jaw and tool extend Rivet's original 20-bone schema. `curl.R/L` remain available for claws or finger-like details. Bones inherit full scale. Every mesh vertex has one rigid weight. All rest bone axes use a short +Y tail, so pose-table XYZ rotations have consistent meaning.

## Reproduce

Run from the clone root with Blender 5.2.2, Python/Pillow and ffmpeg. These commands use cached ImageGen sheets and do not call a provider or git.

```sh
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/rig_pilot.py -- sable
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/rig_pilot.py -- kest
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/anim_pilot_drop.py -- rivet --retime --no-render
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/anim_pilot_drop.py -- sable --retime --no-render
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/anim_pilot_drop.py -- kest --retime --no-render
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/verify_pilot_drop.py -- rivet --retime
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/verify_pilot_drop.py -- sable --retime
blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/verify_pilot_drop.py -- kest --retime
```

Timing evidence lives in `artifacts/anim-pilot/retime/`. For each pilot, run `render_pilot_retime.py -- PILOT new` and `-- PILOT old` through Blender, then `python sketches/core-loop/tools/blender/compose_pilot_retime.py`. The saved `baseline/` GLBs are the actual pre-retime exports. These renders use the resting game chase camera (7.5-unit arm, 65-degree vertical FOV, pitch -0.30, anchor height 0.8) at 1920×1080 and 30 fps. Lossless render borders are composited at their original pixels, without magnification. Old and new play on the same clock. Individual videos retain the full camera projection; the sheet and trio crop empty background only.

For explicit reauthoring after image review, add `--author` to the Sable/Kest animation command. Each pose stores its source image SHA-256 and a concrete observation. Normal rebuilds refuse changed reference bytes. `--draft --render-tag=NEW_NAME` saves only four checkpoint poses to a new evidence folder. `--no-render` rebuilds the GLB and editable Blender scene without images or video.

`verify_rivet_shared.py` compares every source vertex at all 16 poses to `artifacts/anim-pilot/shared/baseline/rivet-drop.blend`. That baseline and the original GLB were saved before this task's edits. The measured difference is zero. The GLB bytes change because the skin now includes 25 joints.

## Evidence and limits

`artifacts/anim-pilot/sable/` and `kest/` contain neutral orthographic references, 16 built-in ImageGen sheets apiece, their exact prompts, explicit pose observations, rendered comparison sheets and chase-camera MP4s. `trio_drop_land.mp4` renders the three final GLBs in sync while rotating their display roots. Those display rotations are not part of the exported actions.

The shared verifier checks the actual exported animation name, duration, skin, hierarchy, triangle count and reimported geometry at all 16 keys. The retime also checks unchanged authored bone values and unit rig scale, and samples the full action at half-frame intervals (131 positions for Rivet/Sable, 133 for Kest). It does not test contact with cockpit equipment or prove every continuous instant between samples. Kest's preen includes a separate beak-to-feather contact check.

The generated references sometimes mirror a back view, add fingers, change feathers or enlarge mouths. Each affected pose records the chosen interpretation. Sable uses a whole-ear hinge; Kest retains the small source beak without a new mouth cavity. Fixed seated legs take precedence over generated foot splays. Rear glass mutes the smaller details; torso squash, arm silhouettes and tail motion carry the reactions.

Reference and chase runs used two CPU rendering threads. The trio turnaround used eight capped threads on the 32-thread machine and reused 37 hashed completed frames. All Blender processes had a 12 GiB address-space cap. The systemd user-scope bus was unavailable. Blender's read-only extension and thumbnail-cache warnings did not prevent output. No dependencies, gameplay, boards or git state were changed. Blender export/reimport and video evidence do not establish Godot import, combat readability or human feel.
