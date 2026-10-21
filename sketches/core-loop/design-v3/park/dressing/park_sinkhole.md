# park_sinkhole dressing, wave 18

Base: `stage/alpha-w18` bd86a7e4 merged into the sinkhole branch (head 535aa9e5). The Dressing foundation (#220) and its `scatter_row` rule are on the stage.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (an OpenGL compatibility proxy). This is not a frame-cost proof and says nothing about human feel.

## What and why

Sinkhole is world 2's underground afternoon: basalt, lava tubes and the timber gallery ring. Mining crews and their pumps worked here, and the old trench people kept granaries in it. The brief has a lamp veto (KITS.md, sinkhole section): lamp racks face the wrong way and none is lit.

The file holds 17 templates over 169 spots:
- Ten are crew moments: a pump parked off mid-shift, a lamp wall, a fallen gallery set, carts, a shift board, dropped gear, a signal horn.
- One is the trench people's seed jars (`granary_ledge`, only by `trench_granaries`, with no hearth).
- Six are fern, moss and rimstone clusters where a skylight or a seep reaches the floor.
- A litter layer runs between them.

## Plan check

`tools/park_props_plan.gd --map=park_sinkhole --check` reports 1,420 instances (230 litter), 0 violations and fingerprint 2160462734, which equals the pin. The figures are the same on a2b6cee5 and after the bd86a7e4 merge.

The `scatter_row` rule moved six cone heroes out of the scatter-dressed `cinder_cone` (commit ebff7251). Now no tall or hero spot lies in any scatter row: `cinder_cone`, `machine_vault`, `pump_gallery`, `east_mesa` and `gallery_ring` 1 to 3.

## Audit (head 535aa9e5; default run, mid camera, step 25 m, 309 samples)

- Props-only draw delta: max 82, median 28.5. The bar is 120 at every pose.
- Draw calls: max 810, median 445. Primitives: max 1,018,554, median 707,176.
- Density: 52 of 53 non-exempt windows pass, with 11 exempt (all arena). The one fail is kest at 900 m, (52.3, -332.4). It sits at the tube mouths `main_tube_upper_1`, `skylight_chain_1` and `east_drift_1`, which are all tunnel keepouts.
- Bare share 18.4%; void poses 0.

## Stills: why most frames look unchanged (coordinator ruling, #241 6327644729: option (c))

Two pose sets were replayed with the vignette file moved aside (before) and in place (after): the audit's 12 barest poses and 12 evenly spaced poses. Dressing is visible in 2 of the 24 after frames:
- even 141 (-163, -267): mist_rings, cave_fern and drill_steels from `s068_low_stones` on `west_gallery_4`;
- even 244 (-16, -409): a pump_station vignette on the plateau.

The other 22 are bare because the chase camera looks down ride interiors that are closed to props. Their walls and banks hide the bank vignettes. The density audit counts kinds in the frustum, not past occluders, which is why it passes while the frames show little.

| Pose (set, idx, x,z) | What hides or excludes dressing (row in `park_sinkhole.json`) |
|---|---|
| full 16 (-381,-580), even 90 (-367,-586) | `lava_channel_9` half-pipe and the `cinder_kicker` lip |
| full 39 (1,-357), full 134 (-15,-355), even 38 (-11,-379) | `lava_channel_21` half-pipe and the `crust_kicker` run-out |
| full 61 (-37,22), full 270 (-23,-3), even 270 | `great_room` bowl and landmark (arena keepout) |
| full 74 (79,231) | `main_tube_lower_9` tube interior |
| full 116 (2,-161) | `main_tube_upper_6`/`_7` tube walls |
| full 193 and even 193 (-140,-409) | `lava_channel_17`/`_18` half-pipe; the bank hides s043, s046 and s047 |
| full 222 (-628,-724) | `cinder_cone` scatter bowl with the `lava_channel_1`/`_2` half-pipes |
| full 275 (-145,117) | `west_breakthrough_5` tube and its kicker |
| full 284 (-29,283) | `hive_cells` home (caisson) and `west_breakthrough_10` |
| full 301 (-135,-208) | `cannon_tube_kicker` ramp and the `cannon_tube_5` tunnel |
| even 12 (-477,-562) | `lava_channel_6`/`_7` half-pipe |
| even 64 (-78,81), even 218 (-25,157) | `main_tube_lower_3` and `_5`/`_6` tube interiors |
| even 115 (42,-191) | `main_tube_upper_kicker` ramp and the `main_tube_upper_5` wall |
| even 167 (169,193) | `east_haulage_7` adit |
| even 296 (-64,-309) | `cannon_tube_2` tube |

Pixel change ranges from 0.30 to 4.35% on the full set and from 0.02 to 1.89% on the even set. Those figures include world-state noise from run timing: thin poles, a red telegraph column and a far spire appear in one render of a pair. One example proves it: pose 270 is in both sets, and the pole is in one after frame and not the other. ParkProps creates no collider (no StaticBody, Area3D or CollisionShape in `park_props.gd`), so these differences cannot touch a ride line. The frames are the evidence; pixel change is not.

The structural fix is flush wall dressing (`dress_flush`: decals and relief of 0.12 m or less on half-pipe, tube and gallery walls). It is a wave 19 card under the same ruling. Until then sinkhole ships with this list.

## Kit (`assets/models/park/props/sinkhole/manifest.json`)

14 kinds, 32 variants:
- Heroes: pump_engine 10,384 and 10,704 tris; lamp_rack 11,496 and 9,656; gallery_collapse 8,916 and 12,252.
- Props: 1,180 to 2,996 tris.
- LOD1 is 50% of LOD0, and LOD2 is 10.6 to 15% (smallest 148).
- The tallest variant is 4.83 m, so no perch is needed.

`gallery_collapse_b` stands 1.96 m but is a hero by triangle budget. The hero tier still holds it 20 m from lines.

Lamp veto: lenses are `e4e2d6`, the runtime material has no emission, and the racks face one way. No HAZARD, ANCIENT or MINT within 0.08 sRGB (kit.py guard).
