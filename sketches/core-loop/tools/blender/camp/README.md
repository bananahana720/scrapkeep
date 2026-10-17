# Camp hub kit

The models and dressing for the between-runs camp. The camp came back into the alpha on 16 Oct 2026 (it reverses the 6 Oct cut W18-R1, `design-v3/park/storyboards` on PR #14 and `alpha-status/grill-alpha-scope-2026-10-16.md`). Andrew picked the **hub ring** layout on storyboard 7 (22:36:12Z on 16 Oct). He also picked the pet on 17 Oct (01:49:14Z): a **retired Fleet drone** that Moss rewired.

This folder holds models only. The camp scene, station behaviour, the skee-ball scoring, the ghost and medals, the enemy picker, the pet's animation and the lights are wave 19 machine work. See [Port notes](#port-notes).

## Build

```sh
sketches/core-loop/tools/blender/camp/build_all.sh            # writes assets/models/camp/*.glb and assets/registry.d/camp.json
sketches/core-loop/tools/blender/camp/build_all.sh /tmp/x     # a scratch build; compare with cmp to prove determinism
python3 sketches/core-loop/tools/fold_registry.py             # fold the fragment into assets/registry.json
```

There are 9 recipes and 34 GLBs. Every recipe rebuilds byte-identically. `build_all.sh` prints one `CAMP_EXPORT` row per GLB, with its sha256. Every GLB is one `enamel` draw with COLOR_0 vertex colour, the same as the park contraptions. Its class budget in `assets/asset_budgets.json` covers the drawn mesh plus the collision mesh, which is what `npm run asset:inspect` counts.

To render previews with Cycles on the CPU:

```sh
blender -b -P sketches/core-loop/tools/blender/camp/render.py -- --piece <glb> [<glb> ...] [--stack] --out DIR
blender -b -P sketches/core-loop/tools/blender/camp/render.py -- --layout --models sketches/core-loop/assets/models/camp --out DIR
```

## Conventions

- Axes: Godot +Y up, metres. The origin is on the ground at the footprint centre, unless a recipe header says otherwise.
- Facing: local +Z faces the plaza. `layout.yaw_to_centre` turns a piece's +Z toward the spawn.
- Collision: the node is named `<id>-col-col`. The Godot importer strips one `-col`, so the node becomes `<id>-col`, the name `park_recipes.gd` looks for. It holds only the solids the ball or harpoon should hit.
- Sockets: empties that the runtime wires to.
  - `interact` sits at ball height on the plaza side of every station.
  - `light_*` empties sit at bulb centres; the runtime adds the lights.
  - Each station has its own named sockets, listed in its recipe header.
- Colour: the game palette.
  - Mint marks only what the player uses: the launch pad, the shortcut, thresholds, the skee lane, the trial start, and the console knob, call-box lever and dial.
  - Amber marks scores and medals.
  - Copper marks machinery. Brass is used only on the Fleet requisition tag.
  - There is no hazard red and no lettering. Labels are runtime UI.

## Layout

`layout.py` is the one source of positions. The player wakes at the origin facing -Z.

| Station | Bearing | Radius | GLB | Recipe |
| --- | --- | --- | --- | --- |
| Launch gate | 0 (straight ahead) | 70 m | `camp_launch_gate` (+2 shells) | `gate_lockers.py` |
| Pet and toys | 55 | 48 m | `camp_pet_pen`, `camp_pet`, `camp_toy_*` | `pet.py` |
| Skee-ball | 120 | 48 m | `camp_skee_lane` (+2 shells) | `skee.py` |
| Settings | 160 | 48 m | `camp_settings_console` | `stations.py` |
| Achievements | 205 | 48 m | `camp_trophy_wall` (61 plaques) | `stations.py` |
| Moss | 250 | 48 m | `camp_moss_stall` (+2 shells), plus the shipped `moss_jukebox_cabinet` at its `jukebox` socket | `moss.py` |
| Pilot lockers | 305 | 48 m | `camp_lockers` (+2 shells) | `gate_lockers.py` |
| Time trial | east, centre (122, 0, -20) | | `camp_trial_track`, `camp_trial_arch` | `practice.py` |
| Sandbox | west, centre (-122, 0, 10), entry facing the plaza | | `camp_sandbox_yard`, `camp_call_box` | `practice.py` |
| Floor and shortcut | | | `camp_plaza`, `camp_shortcut` | `plaza.py` |
| Dressing | `layout.DRESSING` | | lamp post, signpost, fire pit, bench, crate stack, barrel, fence, tool rack, tarp | `dressing.py` |

At a cruise speed of 14 m/s, the gate is 5 s from spawn. The shortcut ramp sits on the gate spoke and throws a cruising ball toward the gate.

## Port notes

These are for the wave coordinator, who owns `src/` and the camp scene. Each note is needed before the camp is playable.

| Id | Change |
| --- | --- |
| C1 | Add a camp scene that places the pieces at `layout.py`'s positions and yaws. Take the ground and backdrop from a stage's terrain or a small canyon bench. `camp_menu.gd` says the full camp scene replaces it. |
| C2 | Each `-col` node becomes a StaticBody3D on the world layer, as `park_recipes.gd` does today. |
| C3 | Wire every `interact` socket to the screen it stands for: Launch, Customize and the lockers, Moss's shop and Companion, Achievements, Settings. |
| C4 | Skee-ball: put sensors at `cup_*`. Each cup's radius is in the `skee.py` header. Scores go to the blank amber panels at `score`, and the ball respawns at `return_exit`. See the [physics check](#skee-ball-physics-check). |
| C5 | Time trial: put checkpoints at `checkpoint_0..3`, start and finish at `start` and `finish`, and draw the ghost line from `ghost_00..31`. Medal lamps go at `light_bronze`, `light_silver` and `light_gold`. The timer digits go at `timer`. |
| C6 | Sandbox: the enemy picker sits at `camp_call_box` (`dial`, `lever`). Called enemies spawn at `enemy_spawn_0..3` on the grate. |
| C7 | Pet: animate the head, tail and paws from the pivot sockets, and add fetch using the toys. The pet idles at the pen's `pet_home`. |
| C8 | Lights: add an OmniLight3D at each `light_*` socket, warm for lamps and amber for marquees. Keep the count inside the frame budget. |
| C9 | Registry: `assets/registry.d/camp.json` has 34 rows, all `ships: false` until C1 loads them. **The folded `assets/registry.json` conflicts with every other open registry PR.** Re-run `tools/fold_registry.py` after merging rather than hand-merging. |
