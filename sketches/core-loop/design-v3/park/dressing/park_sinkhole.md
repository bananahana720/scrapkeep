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

## Reference boards

Rulings 6330671507 (reference before making) and 6331210075 (board grounding). Boards settle look only, never mechanics, scale numbers or collision. I opened each image listed here before writing this section. The kit is unchanged by this note: recipe `sketches/core-loop/tools/blender/park/props/sinkhole.py` (sinkhole.py), colours from `tools/blender/park/props/kit.py` (kit.py), measures from `assets/models/park/props/sinkhole/manifest.json` (manifest).

Boards:
- `docs/art/reference/dig/dig-props-moodboard.jpg` (hoist bearing, cart repair, coil stores, ore sorting, keep water out, shift rest)
- `docs/art/reference/dig/dig-crew-moodboard.jpg`
- `docs/art/reference/dig/dig-landmark-sinkhole-afternoon.jpg`
- `docs/art/reference/style/style-palette-moodboard.jpg`, `style-materials-moodboard.jpg`, `style-shape-moodboard.jpg`
- `docs/art/reference/pilots/pilots-balls-heft-moodboard.jpg`, relative scale only

**Palette roles.** The Dig props board gives sandstone c6a274, oxide 9b513a, charcoal 242a28, petrol 365754, bone d2c5a5 and copper b77843. The kit's sandstone_pale d8c19a and bone d2c5a5 sit in the sandstone rock and bone panels (the cart bed, the sorting frame, the shift-rest canvas), and the kit's charcoal 242a28 and cable 2a3231 sit with the hose, rubber and pipe blacks (coil stores, keep water out). The canvas d9d2bc and canvas_dark b9b095 sit with the shift-rest canvas. Kit colours outside the board's six swatches: timber (8a6a46, 5d4630, 8e8470, a8885c; the landmark board's gallery rails and planks are the nearest panel), iron and steel greys (4a4e4c, 6b706c, 8f9893, 5d6563; the board's cast-iron blocks), limestone and lichen (cfc8b2, a9a28c, 9aa284), fern and moss (7b8a58, 58664a; the board's green shrubs), basalt 3d4140, soil 6a5a42 and a rust brown 8a5a44. The kit has no petrol and no oxide: C["verdigris"] is defined but unused in sinkhole.py, and the only rust is one C["rust"] use. See Board drift.

**Shape language.** The board shapes are big, chunky, softly bevelled blocks with broad wear: bolted housings, round bearings, wide pipes (style-shape "repair" and "tool" panels; dig-props hoist bearing and manifold). The kit builds from the same rounded and bevelled primitives (`style="hard_smooth"`, `"round"`, `"flat"`), at 1,180 to 2,996 tris for props and 8,916 to 12,252 for heroes (manifest), with broad forms and no thin detail: the pump engine's plinth and drum, the horn's squat cradle, the timber reel. The crew board's soft plush crews are not modelled; the props are what they leave behind (mug, coat, tally).

**Materials.** sinkhole.py uses no brass: STEEL's comment reads "steel-grey, no brass", and the oil can and nozzle are commented "brass-free". No `d9b44a` appears in sinkhole.py or in the palette it takes from kit.py (BRASS is in kit.py's WARN list as Fleet only). Copper is not used either (b77843 is not in sinkhole.py). The fittings are steel (STEEL, STEEL_D, iron_light), timber and canvas. The board shows copper pipe bands as accents; the kit has none, which is within the packet's "copper or steel fittings".

**Scale to the pilot ball.** The ball's radius is `RADIUS := 1.0` (`src/movement/tuning.gd:95`), so its diameter is 2.0 on the pilots board's relative scale. Manifest heights against it: pump_engine 4.45 and 4.83 (about 2.2 to 2.4 balls), lamp_rack 4.305 (about 2.2), gallery_collapse 3.97 and 1.963 (about 2.0 and 1.0), echo_horn 2.879 and 1.267, column_stubs b 2.562; the rest of the props are 0.335 to 1.5 (cart 1.47 to 1.507, jars 1.13 to 1.47, hose reel 1.1 and 1.367, coat hooks 0.557 and 1.437, cave_fern 0.614 to 1.281, mist_rings 0.54 and 0.69). So heroes stand about twice the ball and the common props stand below it, which keeps the ball larger than a cart or a jar, as the board shows a ball beside a rail and a pipe. No new metres are asserted.

**Avoid list, checked against sinkhole.py, kit.py and the manifest.**
- No emission: pass. kit.py line 567 asserts no emissive material at build, and the manifest has no emissive factor. The lamp lenses are LENS e4e2d6, commented "plain white, non-emissive".
- No hazard stripes or coral: pass. Grep of sinkhole.py for `ff5a3c`, hazard, stripe and coral finds only the colour-guard comments. The nearest any sinkhole colour comes to HAZARD, ANCIENT or MINT is 0.32 (concrete_light b8b7ae to MINT, by Euclidean sRGB, computed from the 26 colours the file uses); kit.py's guard rejects anything within 0.08.
- No cache-shaped containers: pass with a note. `granary_jars` is lidded stone seed jars on limestone slabs, round, 1.1 to 1.5 m, in a trench-granary vignette, and the recipe says at line 508 it swapped stacked tin rings (which read as a cache) for wide, low stepped lips on `mist_rings`. The reviewer may judge the jars.
- No taut or decorative grapple cables: pass. The only cable-like prop is `hose_reel`, a hose on a timber reel with its loose end coiled flat on the ground (hose torus rings use `style="flat"`). There is no rope, no cable span and no hook.
- No fake ride surfaces: pass. `tin_cart` is "solid wheels, no rails" (manifest story), the planks in `gallery_collapse` are heaped and tilted, there is no ramp, no rail and no flat deck, and the dressing is held off the lines by the `line_clear` and `keepout` rules.
- No glowing lamps: pass. Every lamp in `lamp_rack` and `coat_hooks` is the unlit `lamp()` with the plain lens; the brief's lamp veto says none is lit.
- No ancient-green or uranium-green: pass. The greens are FERN 7b8a58, FERN_D 58664a and LICHEN 9aa284, a dusty grey-sage "never luminous, clear of mint and ancient green" (sinkhole.py line 27). The closest to ANCIENT is FERN at 0.49.

**GROUNDING.md (main cb534a2d) rows read.**
- Line 30 and line 201 (Conflict: the board's brood pod against the honeycomb nest): not copied. The props include no pod, no sphere-on-a-pipe and no hex cell.
- Line 199 (open sky, gallery ring, 20 m caisson bowl): not a prop concern; the props stay out of the ring and bowl through the `set_dressing.gd` keepouts.
- Line 200 (brood light column, ancient green only on ancient machines): not copied; no prop is green-lit.
- Line 202 (tube to daylight, plain wooden rails, no glowing walls): followed; no prop emits.
- Line 203 (rope hardware ownership left open): followed; no rope or hook prop.
- Line 204 (rails and props clear of the rolling route; floor stays empty): followed through the line and route keepouts; the stills section above lists where this leaves the frames bare.
- Line 205 (mining clusters in recesses, non-emissive, off the route): followed by the vignette templates and the plan check.
- Line 206 (coils and manifolds as set dressing, water is reflected daylight): followed by `hose_reel` and the pump engine, neither a grapple point or pickup.
- Line 213 (green only on ancient machines, unlit lamps): followed, as in the avoid list.
- Line 217 (pump crew lore at the caisson): the pump engine and gallery vignettes are the visual hook for that line (`lore_rows.gd:338-341`).

## Board drift (for review)

I did not change the kit. The reviewer decides FAIL and the ART-MISTAKES line.
- Petrol and oxide: the Dig props board's machines are petrol enamel and oxide panels with sandstone-edged rust patches (hoist bearing, cart repair, manifold). The sinkhole machines are steel grey and timber. The kit carries no petrol and one rust use, so the pump engine and cart read greyer and duller than the board.
- Copper accents: the board's bands and pipe fittings are copper; the kit uses none. This is allowed by the brass rule, but it is a palette difference.
- Plush crews: the crew board's soft-toy crews are not modelled; the props show only what the crew left. GROUNDING line 217 keeps the crew as lore, so I read this as intended.

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
