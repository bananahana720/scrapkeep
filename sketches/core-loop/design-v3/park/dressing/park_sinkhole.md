# park_sinkhole dressing, wave 18

> **Historical wave-18/20 dressing receipt:** Live prop placement and pins live in `sketches/core-loop/src/world/park/props/park_sinkhole.json`, `sketches/core-loop/tests/fixtures/pins/park_sinkhole.pin`, and [DRESSING-KITS.md](../DRESSING-KITS.md).

Base: sinkhole branch head 7afe0e43 (which already held the stage and foundation 07748516 merges) plus a final merge of `origin/stage/alpha-w18` f259e8cf (merge 27e6e028) and the accepted Dressing foundation `claude/zealous-franklin-ed0sxr-lineclear` e72fff7d (merge 4c23d363), then the foundation's stage merge be6189ec (merge b034a45f; its tree equals e72fff7d merged with f259e8cf). The foundation commits after 07748516 change only the audit, static checks and `park_props_test`, so the plan check is unchanged. The Dressing foundation (#220) and its `scatter_row` rule are on the stage.
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

`tools/park_props_plan.gd --map=park_sinkhole --check` reports 1,419 instances (229 litter), 0 violations and fingerprint 3120478943, which equals the current pin (w18k, section below; before it 2700969323, and before that 2160462734). Before the move it reported 3 `telegraph` violations on the checked-in vignettes (fingerprint 4292016683). It is the same on b100f674 after the second stage merge.

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
- 2026-10-19 World #219 flush lanes (ART-MISTAKES.md line 21), "never drop geometry to pass a check; cut or refit it, and look at a capture". tin_cart_b was refit (rotated), not removed, and I looked at the rendered sheet and the individual PNGs before this note.
- 2026-10-21 Grading #241 mapping claim (line 36), "measure before claiming". The colour guard and the plan check were run, not eyed, and the palette claims here cite kit calls from grep.
- 2026-10-21 Animation A1, "kill only PIDs found by pgrep". I used no `pkill`; a stuck test was left to its own timeout.

## Reference boards

Rulings 6330671507 (reference before making) and 6331210075 (board grounding). Boards settle look only, never mechanics, scale numbers or collision. I opened each image listed here before writing this section. The kit is unchanged by this note: recipe `sketches/core-loop/tools/blender/park/props/sinkhole.py` (sinkhole.py), colours from `tools/blender/park/props/kit.py` (kit.py), measures from `assets/models/park/props/sinkhole/manifest.json` (manifest).

Boards:
- `docs/art/reference/dig/dig-props-moodboard.jpg` (hoist bearing, cart repair, coil stores, ore sorting, keep water out, shift rest)
- `docs/art/reference/dig/dig-crew-moodboard.jpg`
- `docs/art/reference/dig/dig-landmark-sinkhole-afternoon.jpg`
- `docs/art/reference/style/style-palette-moodboard.jpg`, `style-materials-moodboard.jpg`, `style-shape-moodboard.jpg`
- `docs/art/reference/pilots/pilots-balls-heft-moodboard.jpg`, relative scale only

**Palette roles.** `dig/README.md:52`: "worn bone, petrol, timber and sandstone dominate; copper is a small functional fitting". The first version of this kit failed that: every machine body was steel grey (8f9893, 5d6563). It is recoloured in this commit. Board swatches against kit calls in `sinkhole.py`:
- Petrol 365754 (machine bodies on every board panel): `STEEL` (line 30) and `STEEL_D = shade("365754", 0.75)` (line 31). Carried by the pump engine block, cylinders, barrel and flywheel (lines 90 to 116), the horn bell and mouthpiece (234, 236), the rain gauge's water column (367), the `lamp()` body default (70, so the lamp_rack and coat_hooks lamps), and the drill steels (493, 501).
- Oxide 9b513a (painted bands and panels): `OXIDE` (line 34) on the pump's painted band (91) and the tin cart straps (263).
- Bone d2c5a5 ("rubbed metal", labels): `C["bone"]` on the pump cylinder caps, piston-guide caps and barrel flanges (94, 97, 118) and the stub-pipe cap (120), the horn's bell rim (235, 242) and the cart's tally tag (274, 297).
- Copper b77843 (small functional fittings): `COPPER` (line 35) on the pump's drain cock (121), the hose-reel crank peg (416) and nozzle (430) only. The drain cock is the largest of these (radius 0.4, depth 0.5, free-standing at about (-2.2, -1.6) on a 7 m plinth). The guard warns on the exact hex and the three calls are all small.
- Sandstone: `sandstone_pale` and the limestone mixes (granary jars, mist rings, column tops).
- Charcoal 242a28: the tally board, the rain-gauge level bars (369 to 371, `C["charcoal"]`) and rubber or outline parts.
Kit colours outside the board's six swatches: timber (8a6a46, 5d4630, 8e8470, a8885c; the landmark board's gallery rails), neutral iron 6b706c (`C["iron_light"]`, still on pails, funnel, the flywheel dead-code line 107 and drill-steel alternates; the board's cast-iron blocks), pale paint e0d9c3 (`PALE_PAINT`, already on lines 163, 190 and 448; now also the rain-gauge glass, 368), limestone and lichen (cfc8b2, a9a28c, 9aa284), fern and moss (7b8a58, 58664a; the board's green shrubs), basalt 3d4140, soil 6a5a42, rust brown 8a5a44 (`C["rust"]`, line 132) and canvas. The gallery_collapse, granary_jars, column_stubs, tally_post, cave_fern and mist_rings kinds are unchanged and carry no petrol, which suits stone, timber and plants.

**Shape language.** The board shapes are chunky, softly bevelled blocks with broad wear: bolted housings, round bearings, wide pipes (style-shape "repair" and "tool"; dig-props hoist bearing and manifold). The pump engine, horn, barrel, reel and rain-gauge tube use the same rounded and bevelled primitives (`style="hard_smooth"`, `"round"`, `"flat"`) at 1,180 to 2,996 tris for props and 8,916 to 12,252 for heroes (manifest). Not everything is chunky: gallery_collapse's lagging planks and drill_steels' rods are thin, deliberately (a heap and a bundle), and the tally strokes are 0.025 m `style="fine"` boxes. The crew board's plush crews are not modelled; the props are what they leave behind.

**Materials.** sinkhole.py uses no brass: no `d9b44a` anywhere, and `kit.py` warns on it as Fleet-only. Copper is used, as small fittings only (above), as the board does (copper bands on the pump and coil-store panels) and as the packet allows in place of brass. Timber, canvas and stone are as the landmark board's gallery. Enamel wear (the board's sandstone-edged rust patches) is not modelled: the kit has flat vertex colour with a small tint, so petrol reads clean. See Board drift.

**Scale to the pilot ball.** The ball's radius is `RADIUS := 1.0` (`src/movement/tuning.gd:95`), so its diameter is 2.0 on the pilots board's relative scale. Manifest heights against it: pump_engine 4.45 and 4.83 (about 2.2 to 2.4 balls), lamp_rack 4.305 (about 2.2), gallery_collapse 3.97 and 1.963 (about 2.0 and 1.0), echo_horn 2.879 and 1.267, column_stubs b 2.562; the rest are 0.335 to 1.5 (tin_cart 1.18 to 1.507, jars 1.13 to 1.47, hose reel 1.1 and 1.367, coat hooks 0.557 and 1.437, cave_fern 0.614 to 1.281, mist_rings 0.54 and 0.69). Heroes stand about twice the ball and common props below it. No new metres are asserted.

**Avoid list, checked against sinkhole.py, kit.py and the manifest.**
- No emission: pass. kit.py line 567 asserts no emissive material at build, and the manifest has no emissive factor. The lamp lenses are LENS e4e2d6, commented "plain white, non-emissive".
- No hazard stripes or coral: pass. Grep of sinkhole.py for `ff5a3c`, hazard, stripe and coral finds only the colour-guard comments. The nearest any sinkhole colour comes to HAZARD, ANCIENT or MINT is 0.31 (copper b77843 to HAZARD; oxide 0.39, bone 0.37, petrol 0.78; Euclidean sRGB). The build ran the guard on every call: 5 copper WARNs, no failures; kit.py's guard rejects anything within 0.08.
- No cache-shaped containers: pass with a note. `granary_jars` is lidded stone seed jars on limestone slabs, round, 1.1 to 1.5 m, in a trench-granary vignette, and the recipe says at line 511 it swapped stacked tin rings (which read as a cache) for wide, low stepped lips on `mist_rings`. The reviewer may judge the jars.
- No taut or decorative grapple cables: pass. The only cable-like prop is `hose_reel`, a hose on a timber reel with its loose end coiled flat on the ground (hose torus rings use `style="flat"`). There is no rope, no cable span and no hook.
- No fake ride surfaces: pass. `tin_cart` is "solid wheels, no rails" (manifest story); variant b now lies on its side, the planks in `gallery_collapse` are heaped and tilted, there is no ramp, no rail and no flat deck, and the dressing is held off the lines by the `line_clear` and `keepout` rules.
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

The board review of 9f1bb6bb failed the palette: the machines were steel grey, not petrol with oxide and bone panels and copper fittings. Recoloured in this commit (STEEL and STEEL_D to petrol; bone caps and flanges; oxide band and cart straps; copper on three small fittings; a bone rim on the horn bell, so it reads as a horn from behind). The crew board's plush crews are not a drift (reviewer ruling). Remaining differences from the board for review:
- No enamel wear: the board's petrol panels have sandstone-edged rust patches; the kit's are clean flat colour.
- Neutral iron 6b706c remains on pails, the funnel, and drill-steel alternates; the board's pails are dark iron or charcoal.
- Lamp rack lamps and the coat-hook lamp are petrol with a white lens, not lit; the board has no lamp.
- echo_horn: the preview tool renders one three-quarter view only, no back view. The bone rim tori (major 0.97 against bell end 0.95 on variant a; 0.57 against 0.55 on variant b) are nearly hidden from behind. Deferred: re-seating changes the kind's radius and height, which moves the plan pin; a polish pass with a re-pin.
- pump_engine drain cock: it stands free on the plinth edge and reads as a copper can, not a fitting. Deferred for the same reason: re-seating on the stub pipe changes the kind's radius and height, which moves the pin; a polish pass with a re-pin.

## Other notes

- `mist_rings` share the annulus family with area telegraphs. Low risk: limestone, raised, unstriped and non-emissive, and the `telegraph` rule keeps them out of event zones.
- The horn and cart micro-templates recur every 40 to 50 m on the lava-channel banks. The structural answer is the wave 19 flush-dressing card (`dress_flush`), not a kit change.
- `drift_valve` (`4-park_sinkhole.md:244`, kind valve, recipe `gauge`; `park_sinkhole.json:614`), read-only: the player rams a big cracked valve wheel, not a dial. `contraptions.gd` `_build_valve` (about 794-846) draws the `valve_wheel` and `valve_wheel_mount` props (`tools/blender/valve_wheel.py:3`, a cast eight-spoke wheel on a petrol body), a striped door and an optional plume, and never calls `_dial`. The tick-dial vocabulary in this park is on the 9 geyser launchers (`park_sinkhole.json:601-610`, via `_dial` at `contraptions.gd:747`) and the great room lift (`:613`, `_dial` at `:619`): 2.6 m dials (`tools/blender/park/contraptions/gauge.py`, copper bezel) at 3.4 m whose needle reads the cycle. `rain_gauge` (since w18k a vertical graduated measuring tube, no dial: a 0.2 m wide, 0.7 m tall pale tube with a petrol water column and five charcoal level bars, under a tin funnel on a short post; `sinkhole.py:363-371`) no longer echoes those dials. **Readability risk, closed in w18k:** the earlier round dial with ticks and a needle read like a launcher dial in the `s065_lamp_wall` eye frame, so it was replaced; the frames are read in the w18k section below.
- `tin_cart_b` is now laid on its side (a hand-laid box set, not a transform of the upright parts; mouth toward -Y, tailings spilled in front; no open top), so it no longer reads as an upright open crate (DRESSING-KITS.md:47). Height 1.48 to 1.18; tris and radius unchanged. `echo_horn` story text now says petrol-enamel with a bone rim.

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

## w18k gauge face and placements (card (a), coordinator 6335154095)

Base ddebc2b5. Authority: coordinator 6335154095 item 2a (board #241, from 6334639522): the gauge's round face must not read as a launcher dial in motion; Andrew, DECISIONS section 8, readability first. Method: headless Blender and Godot 4.7.2 on cloud llvmpipe; this proves frames and numbers, not human feel.

### Kit change
`rain_gauge` (`tools/blender/park/props/sinkhole.py:354-374`) lost its round dial: the STEEL_D torus rim, the PALE_PAINT face disc, the 8 charcoal ticks and the needle. It now carries a vertical graduated measuring tube under the funnel (`:363-371`):
- foot cap, r 0.10 m, 0.04 m tall, `iron_light` (`:366`);
- water column, r 0.09 m, `STEEL` petrol (`365754`, on the dig-props board; the packet asked for a board blue-grey or slate, and petrol is the board's only blue-leaning dark, so `concrete_dark` was not needed) (`:367`). Fill 0.35 m of the 0.70 m tube (half) on variant a and 0.20 m (about 30%) on b, so a is fuller than b. There is no needle angle;
- pale glass, r 0.09 m, `PALE_PAINT` (`e0d9c3`) from the water line to z 1.05 m (`:368`);
- five charcoal level bars up the left side, alternating 0.09 and 0.06 m long, 0.12 m apart from z 0.47 to 0.95 (`:369-371`).
Funnel, post, the three stones, the lichen and variant b's tipped cup are unchanged. Nothing is round with ticks, nothing is orange, nothing is emissive.

### Tris and size (manifest)
| | tris LOD0/1/2 before | after | radius before | after | height |
|---|---|---|---|---|---|
| a | 2400 / 1200 / 360 | 1580 / 790 / 234 | 0.854 | 0.838 | 1.384 (unchanged) |
| b | 2684 / 1342 / 402 | 1868 / 934 / 277 | 1.086 | 1.088 | 1.389 (unchanged) |
LOD0 stays inside the props band of 300 to 3k (DECISIONS section 8). The radius moved by 0.016 and 0.002 m, which is why the pin moved. Two builds gave identical sha256 on all six rain_gauge GLBs.

### Two moves
- `s113_lamp_wall`: `at` (180.0, -30.0) to (184.0, -20.0), 10.8 m; `yaw_deg` 30.9 to -136.6. Why: at the old spot its gauge (template offset (2.5, -9)) stood inside `s104_pump_station`'s pump_engine cylinder (radius 4.2 to 4.7, 13.3 m away, same yaw 30.9), so every bearing was blocked. The new yaw faces `east_drift_10` at (139.3, -67.2): atan2(139.3 - 184, -67.2 + 20) = -136.6 degrees (front is local +Z, `park_props.gd:808`). It still sits at that drift, so the `near` label ("east_drift_10: lamps facing the wrong way") is true and stays. Clearance to `s104`'s members, manifest radius times scale, centre to centre minus both radii: the closest lamp_wall member is 1.43 m clear (needed at least 1 m); the gauge's centre is 20.3 m from the nearest s104 member's edge (19.4 m clear, centre to centre minus both radii). At the old spot the worst pair overlapped by 2.38 m and the gauge was 1.25 m inside the pump.
- `s132_lamp_wall`: `at` (104.89, 195.69) to (118.89, 195.69), 14 m east; `yaw_deg` kept at 117.8. Why: the old gauge, at about (95.8, 197.7), was buried in a landform (hiding it changed 0 px; the old eye frame showed only a rock face and the ground). I chose a shift over a re-yaw because the shift keeps the wall's facing and its `near` label (`main_tube_lower_8`) true. I did not measure the landform's extent, so 14 m is a tried value, not a minimum.
Both moves are legal in the plan check (0 violations).

### Pin and checks
- Plan check: 1,419 instances (229 litter), 0 violations, fingerprint 3120478943. Old pin 2700969323; re-pinned on purpose (`park_sinkhole.json` `pin`). `park_props_test`: PASS (226 checks), "[park_sinkhole expansion matches its pin] got 3120478943, want 3120478943 -> PASS".
- Row scans on the props file: `scan_strict` 169 spots, 0 collinear runs, 4 one-yaw clusters, same before and after. `rowscan` 40 flagged runs, yaw groups 11 to 10 (the s113 yaw no longer joins the 30.9 group).
- Vignettes (tool tree `vsinkhole-vg`, branch merged, assets re-imported), `--subject-kind=rain_gauge`, `s065_lamp_wall,s113_lamp_wall,s132_lamp_wall,s109_mid_shift_board`: none blocked_all; eye subject_px 6,796 (s065), 8,941 (s109), 6,953 (s113), 6,917 (s132); chase 868, 1,177, 949, 936. Before, s113 was blocked in all bearings and s132 showed 0 px.
- Frames, read by me: in all four eye frames the gauge is a short post with a tin funnel and a thin upright pale tube with a near-black petrol column at its foot and small dark bars up one side; the read is vertical and straight, with no round face. In the `s065` frame the launcher's round orange dial stands on the right horizon, and the two no longer look alike. In s113 the gauge stands on open floor with a distant blue-grey wall behind it. In s132 it stands on open floor with the rock block behind it, not in it. At this distance the tube is small beside the funnel and its bars are a few pixels wide; the bars are visible but they are the weakest part of the read.
- Density audit (default run, mid camera, step 25 m, 309 samples; `artifacts/local/w18k`): 52 pass, 11 exempt (all arena), 1 fail of 64 windows, the kest 900 m window with 0 kinds that 6329171089 ruled open; the same as the line above. Bare share 18.1%, void poses 0. Props-only draw delta max 76, median 27.5 (bar 120); draw calls max 670, median 446.
- `npm run sketch:lint` exit 0 (0 findings) and `npm run check:docs` exit 0.

## w18m row and yaw fixes (card (b), #323)

Base 6ec831ba. Authority: coordinator 6342666489 item 10, option (a): each park head fails only on the rows and yaw groups #323 lists, and each group is fixed on the park's own PR. The plan check with the #323 rules reported 2 rows and 4 yaw groups (total 6, fingerprint 3120478943); the groups are now clear. Method: the plan check run headless on Godot 4.7.2; this proves the rules and numbers, not human feel.

Yaw. Front is local +Z, so a spot faces a target at degrees(atan2(dx, dz)). Every spot in the four yaw groups now faces the nearest point on its nearest ride line (kest for the cinder-cone cluster, sable for the main-tube pair, rivet for the west chamber, tarn for lava channel 13), rounded to 1 degree. Spots in one group face almost the same direction, so I then turned each one off its own target by a different step of 6 to 12 degrees: -8, 0, +8 for the groups of three and -12, -6, 0, +6, +12 for the groups of five. The largest turn is 12 degrees, inside the 15 allowed. The steps are in the order of the id list in the check (the kest group was reworked in round 2 below). After the turns no two linked spots share a yaw within 1 degree.

Rows. Two rows were moved by the single middle spot, which is the fewest spots:
- `s009_mid_tailings_cart` (kest row): `at` (-600.23, -629.78) to (-604.04, -628.57), 4 m perpendicular to the row, away from the line.
- `s042_mid_skylight_garden` (west gallery diagonal): `at` (-210.0, -250.0) to (-213.8, -251.3), 4 m perpendicular. Its yaw stays -108.5.
Three more spots moved 3 m straight away from their line, because facing the line put a template member inside the line-clear band: `s030_gallery_fall` (-186.86, -619.8) to (-184.57, -621.74), `s074_gallery_fall` (37.37, -278.48) to (35.17, -276.44), `gr2_low_stones` (-38.5, -25.5) to (-39.95, -22.87).

Changed spots (old yaw to new yaw; target is the nearest point on the named line):
| spot | yaw | target |
|---|---|---|
| f05_low_ferns | -47.1 to 125 | sable line, near station 978 |
| s060_low_ferns | -47.1 to 133 | sable line, station 978 |
| s074_gallery_fall | -47.1 to 141 | sable line, station 993 |
| f10_low_gear | -28.9 to 139 | rivet line, station 1396 |
| f11_low_stones | -28.9 to 145 | rivet line, station 1392 |
| f12_low_ferns | -28.9 to 151 | rivet line, station 1386 |
| gr2_low_stones | -28.9 to 157 | rivet line, station 1414 |
| s097_low_gear | -28.9 to 162 | rivet line, station ~1372 (at moved, see round 2) |
| m02_mid_horn_stubs | -59.8 to 108 | kest line, station 131 |
| m03_mid_cart_stub | -59.8 to 123 | kest line, station 139 |
| s009_mid_tailings_cart | -59.8 to 129 | kest line, station 158 |
| m13_mid_horn_stubs | 130.4 to -62 | tarn line, station 597 |
| s028_low_ferns | 130.4 to -56 | tarn line, station 575 |
| s030_gallery_fall | 130.4 to -50 | tarn line, station 578 |
| s031_low_stones | 130.4 to -44 | tarn line, station 620 |
| s032_mid_skylight_garden | 130.4 to -38 | tarn line, station 596 |

`near` labels are unchanged: each already names a park row and its story, and the lint stays at 0.

Round 2 (verifier on #323, rule fix af522720: a line-defining pair over 40 m now counts). Two more rows appeared and were fixed with the smallest legal moves:
- `f11_low_stones`, `gr2_low_stones`, `s097_low_gear` (gaps 19.9 and 21.7, CV 0.043): `s097_low_gear` `at` (-77.5, -40.9) to (-83.6, -44.3), 7 m along the row away from f11. Gaps are now 26.9 and 21.7, CV 0.108. Moving f11 sideways failed (slope, or a new row with f10 and f12), and moving s097 sideways failed (slope or line-clear). Its yaw is the rivet-line target (150) plus the same +12 turn, 162.
- `m19_mid_horn_stubs`, `s055_low_ferns`, `s072_lamp_wall` (gaps 34.0 and 32.9, CV 0.016): `s055_low_ferns` `at` (-45.1, -450.7) to (-44.55, -454.66), 4 m perpendicular, away from the tarn line. Yaw stays 141.4.
The kest fan was regular (+8 and +8 in position order). It now faces three different stations of the kest line, so the turns differ in size: `m02_mid_horn_stubs` faces station 131 (108, turned -12 from its nearest point), `m03_mid_cart_stub` station 139 (123, +3), `s009_mid_tailings_cart` station 158 (129, +9). All are within 15 degrees and no yaw group forms.

Pin and checks. Fingerprint 3120478943 to 1439281478, re-pinned on purpose (`pin` in `park_sinkhole.json`, line 3060). Plan check with the fixed #323 rules (vsinkhole-vg reading this file): 1,419 instances (229 litter), 0 violations, 0 pattern, 0 pin, 0 lint. The old plan check here: 0 violations, same fingerprint. `park_props_test`: PASS (226 checks), "[park_sinkhole expansion matches its pin] got 1439281478, want 1439281478 -> PASS". The span row scan at 80 m: triples 0.

Density audit (default run, mid camera, step 25 m, 309 samples; `artifacts/local/w18m`): 52 pass, 11 exempt (all arena), 1 fail, the kest 900 m window at (52.3, -332.4) with 0 kinds that 6329171089 ruled open space. Identical to the w18k line. Vignette frames of the moved spots were not rendered in this round because the branch's audit has no `--vignettes` mode.

## w18n stage merge (stage 0446a2f2, ruling 6335352057)

The merge conflicted only in the folded `assets/registry.json`; it takes stage's file and re-folds (`fold_registry`: PASS, 1533 assets). World's b4dba39a moved `lava_channel_post_21i` from (-164.9, -448.2) to (-158.3, -450.6), and its plateau now sat under m17's tin_cart and column stub (slope 85.2 and 83.8 degrees, want 25 at most). A grid search of the whole-park check within 25 m (1 m step, 555 legal points) gave (-149.7, -454.8) as the nearest; m17 moves there from (-153.72, -450.83), 5.7 m, with the same yaw, template and label.

Pin 1439281478 to 1683370189. Plan check: 1419 instances (229 litter), 0 violations; #323's check in a scratch merge: 0 violations, 0 pattern, 0 pin, 0 lint. `park_props_test` PASS (270 checks, pin line PASS). Density audit (default run, mid camera, step 25 m, 309 samples): 52 pass, 11 exempt, 1 fail, the kest 900 m window (ruled open, 6329171089), unchanged; bare share 18.1 percent; props-only draw delta max 79.

## w18o B12 restack (stage 2b04b3f3, #350)

#350 moves `main_tube_upper_post_11i` to (-27.3, -120.2) and `lava_channel_post_13i` to (-307.1, -582.2). The litter fill re-seeds around the new post footprints: `coat_hooks` at (-27.9, -116.9) and `drill_steels` at (-310.3, -577.2) drop, and one `cave_fern` moves from (-26.6, -123.1) to (-316.4, -581.7). The drop stays: both are fill litter, not vignette props, and density does not change. The merge had no conflicts; `fold_registry`: PASS, 1533 assets, no change.

Pin 1683370189 to 933495370. Plan check: 1417 instances (227 litter), 0 violations, 0 pattern, 0 pin, 0 lint. Density audit (default run, mid camera, step 25 m) on the pre-check tree with the same expansion: 52 pass, 11 exempt (all arena), 1 fail, the kest 900 m window (ruled open, 6329171089), unchanged; props-only primitive delta median 61,569, max 171,935.

## w18p #359 elbow re-pin

World's #359 reshapes `lava_channel_12`, `13` and `21` and rebakes the sinkhole ground; no dressing spot moves. The litter fill gains one `cave_fern` at (-264.0, -631.6). Pin 933495370 to 506677904; `park_dressing_pin_test` stage 4 3017710206 to 2334293701. Plan check: 1418 instances (228 litter), 0 violations, 0 pattern, 0 pin, 0 lint.
