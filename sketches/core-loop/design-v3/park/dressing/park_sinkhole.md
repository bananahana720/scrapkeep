# park_sinkhole dressing, wave 18

Base: sinkhole branch head 7afe0e43 (which already held the stage and foundation 07748516 merges) plus a final merge of `origin/stage/alpha-w18` f259e8cf (merge 27e6e028) and the accepted Dressing foundation `claude/zealous-franklin-ed0sxr-lineclear` e72fff7d (merge 4c23d363). The foundation commits after 07748516 change only the audit, static checks and `park_props_test`, so the plan check is unchanged. The Dressing foundation (#220) and its `scatter_row` rule are on the stage.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (an OpenGL compatibility proxy). This is not a frame-cost proof and says nothing about human feel.

## What and why

Sinkhole is world 2's underground afternoon: basalt, lava tubes and the timber gallery ring. Mining crews and their pumps worked here, and the old trench people kept granaries in it. The brief has a lamp veto (`sketches/core-loop/design-v3/park/dressing/KITS.md`, sinkhole section; the file lands in #269): lamp racks face the wrong way and none is lit.

The file holds 17 templates over 169 spots:
- Ten are crew moments: a pump parked off mid-shift, a lamp wall, a fallen gallery set, carts, a shift board, dropped gear, a signal horn.
- One is the trench people's seed jars (`granary_ledge`, only by `trench_granaries`, with no hearth).
- Six are fern, moss and rimstone clusters where a skylight or a seep reaches the floor.
- A litter layer runs between them.

Machine lore (Andrew's ruling, #241 6329943362): the giant machines are the humans' utility fleet, built for construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The Waking is the Mind's buried excavator, and the swarm remnants are its maintenance crew. Here the crew sites (pumps, lamp walls, gallery sets) read as plush crews living among working giants. The scale contrast is the point: small soft-toy props that crowd under machines that dwarf them.

## Plan check

`tools/park_props_plan.gd --map=park_sinkhole --check` reports 1,419 instances (229 litter), 0 violations and fingerprint 2700969323, which equals the new pin (old pin 2160462734). Before the move it reported 3 `telegraph` violations on the checked-in vignettes (fingerprint 4292016683). It is the same on b100f674 after the second stage merge.

The `scatter_row` rule moved six cone heroes out of the scatter-dressed `cinder_cone` (commit ebff7251). Now no tall or hero spot lies in any scatter row: `cinder_cone`, `machine_vault`, `pump_gallery`, `east_mesa` and `gallery_ring` 1 to 3.

## Audit (66d37439 plus the s122 move; the later stage merge touched no props, scatter or sinkhole files; default run, mid camera, step 25 m, 309 samples)

- Props-only draw delta: max 79, median 27.5 (before 82 and 28.5). The bar is 120 at every pose.
- Draw calls: max 743, median 455 (before max 810, median 445). Primitives delta: max 164,033, median 40,577.5.
- Density: 52 of 53 non-exempt windows pass (64 windows), with 11 exempt (all arena); the same as before. The one fail is kest at 900 m, (52.3, -332.4), with 0 kinds. It sits at the tube mouths `main_tube_upper_1`, `skylight_chain_1` and `east_drift_1`, which are all tunnel keepouts. The coordinator ruled on it at #241 6329171089: "the 22:25Z option (c) covers it. Tunnel keepouts are open space for the density audit, so it isn't a fail." It is therefore not counted as a fail.
- Bare share 18.1% (before 18.4%); void poses 0.

## Telegraph zones

The `telegraph` rule (`park_props.gd` `check_one`, documented in DRESSING-KITS.md) keeps every instance, litter included, out of each `event_rows` event's own geometry grown by its `hold_clear_m` plus the instance radius. Litter that fails is dropped; an authored spot that fails fails the plan check. Events in `park_sinkhole.json`:

| Event | Site, hold | Inside before | Result |
|---|---|---|---|
| `west_roof_cave_in` | `west_tube_roof` (-205, 250), box 40 x 30, hold 20 m | 3 instances of `s122_mid_rimstone_pool` (2 `cave_fern`, 1 `column_stubs`, near (-182, 214)) | spot moved |
| `junction_machine_wakes` | `machine_vault`, hold 15 m | 1 litter instance | dropped automatically (litter 230 to 229, instances 1,420 to 1,419) |
| `pump_boiler` | boiler_burst with `hazard_m` | none found by the plan check | none |

Spot moved: `s122_mid_rimstone_pool` `at` (-180.0, 210.0) to (-175.0, 210.0), 5 m east. Search: I tried the straight line away from the site first, which ran into the kicker run-out keepout (2 to 5 violations at 2 to 10 m). East offsets of 2 and 4 m still left 3 and 1 violations, and 5 m gave 0. The 5 m shift is under the 20 m limit, so the `near` label stays. All members are legal.

Why props stay clear of telegraphs: a prop inside the zone would be buried or thrown by the event, and would hide the telegraph itself. Other guards that keep props off the same ground:
- The colour guard in `tools/blender/park/props/kit.py` rejects any prop colour within 0.08 sRGB of HAZARD (ff5a3c), ANCIENT or MINT, and no prop has emission, so no prop can read as a telegraph.
- `home_clear` keeps props 25 m (`HOME_CLEAR_M`) from enemy homes and camps.
- The warden bowl (`Features.BOWL_FLAT + 3.0`) and activity sites (11 m) are keepouts in `set_dressing.gd` `keepouts`.

## Gate checks

On b100f674 (merge head before the final merge; the three park smoke tests, lint and docs were rerun on the final merge head, see the PR), each test run alone with `npm run sketch:smoke -- --sketch core-loop --test <name>`:
- `park_props_test`, `park_park_sinkhole_test`, `park_dressing_pin_test`, `pocket_line_clear_test` and `asset_registry_test`: PASS (exit 0).
- `scatter_rows_test`: the smoke wrapper hit its 180 s limit twice on the contended machine (exit null, all 24 printed checks PASS). Run directly with Godot headless it passes, 95 checks, exit 0.
- `run_tier_test`: red, and red on the base too. The smoke run (receipt `artifacts/local/receipts/named-242c8c62dacc-2026-10-22T02-00-19-083Z.json`, 3,452 passes, 8 fails, 790 s) and a direct run (3,044 passes, 19 fails) failed only on `[runtime child seed N] exit=-1 timeout=true`, the fresh-process child timeouts. The coordinator measured the clean stage b0e64a40 at load 17: the same failure, 8 of 192 checks, all child timeouts, 3,531 PASS lines. So this is measured base-red from machine load, not from this branch, which changes no run, tier or combat code.
- `npm run sketch:lint` exit 0 and `npm run check:docs` exit 0.

## ART-MISTAKES entries checked

Rows of `project-guide/handoff/ART-MISTAKES.md` read before the unit and applied:
- 2026-10-21 World #242 lane width, "read the function before describing what a flag means". I read `check_one` and the telegraph zone code in `park_props.gd` (lines 149 to 152, 323 and 766) before describing the rule, and used the plan check's own `detail` text for each violation instead of paraphrasing from the rule name.
- 2026-10-21 Modeling #241 lane map, "rebuild against the stage and run the check; a doc line is not a status". I did not carry over the old "0 violations" line. I re-ran the plan check, the audit and the tests on the merged tree and replaced every number in this note.
- 2026-10-21 Animation #261 receipt, SHAs typed from memory. Every SHA here was copied from `git rev-parse` or `git log` output.
- 2026-10-21 Animation A1, "kill only PIDs found by pgrep". I used no `pkill`; a stuck test was left to its own timeout.

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
