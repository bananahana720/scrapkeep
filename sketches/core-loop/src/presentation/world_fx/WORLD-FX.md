# World and event effects

The air, landmarks, events and ceremonies of Scrapkeep, as one data table and four small scripts. Player effects, and machine and boss effects, belong to their own kits.

| File | Owns |
| --- | --- |
| `world_fx_specs.gd` | Every effect (`SPECS`), what each place plays (`SETS`), weather and modifier air (`OVERLAYS`), game moments (`HOOKS`), run grain (`GRAIN`), the Spillway's placements (`SPILL_PLACES`), budgets |
| `world_fx_grain.gd` | Run grain: each run rolls every effect's dials once from the run seed |
| `world_fx_kit.gd` | Builds an emitter from a spec; the one shader (soft puff, streak, paper, ring, glint, rainbow); the clear zone |
| `world_fx.gd` | The runtime: a world's ambient air, overlays, hooks, anchor ranking |
| `world_fx_anchor.gd` | A drop-in effect for dressing: landmarks, camp, relay, secrets |
| `world_fx_cable.gd` | A swaying cable on a catenary (shader sway, no script cost) |
| `world_fx_word.gd` | The drawn sound word (SPLOSH, KA-CHUNK, OOH, PAID) |
| `world_fx_sound.gd` | The heard side of the world's water and steam (`SOUNDS` in the table): files, 3D distances, the Ambient bus, the cue log line |

Stills: `tools/world_fx_capture.gd` renders every set on greybox stand-ins (command in its header). Checks: `tests/world_fx_test.gd`.

## Rules the table keeps

1. **Air never hides a threat.** Every effect that follows the camera or the ball is `ambient` (the ball's `wake` is the one exception: it is the ball's own feedback, sits at the waterline and stays translucent): it fades out within 7 m of the ball (`CLEAR_RADIUS`) and near the lens, stays translucent, and never wears `HAZARD`, `ARC` or `ANCIENT`. The test fails any ambient spec that breaks this.
2. **Soft world, inked comic.** In-world effects have no outline. Ceremony and comic effects (title slam, summaries, the modifier announce, a secret's find) carry an ink rim, so the comic book sits on top of the world (tone bible, pillar 2).
3. **Budget.** A world's air plus its heaviest overlay stays under `AMBIENT_CEILING` (330 particles). Only the six nearest anchors inside their range emit at once. Past `lod_m` an anchor rests and shows its impostor, one soft quad that keeps a landmark's plume visible across the park for one draw call. The low preset keeps each spec's `low` share; reduced motion drops strobes and fast sparks, halves the rest, stills cables and skips words.
4. **Deterministic.** Fixed seed per run (the kit's seed off a run), no lights, no shadows, 30 fps particle step.

## Run grain (principle 21)

Every run looks a little different and replays its own look. `WorldFx` reads the run's seed on each stage entry (`set_run_seed`); `world_fx_grain.gd` rolls each spec's dials from that seed and the spec id alone, so it draws from no shared stream, and a spec added later never moves another's roll. A dial is a range in the spec's `GRAIN` row (or `GRAIN_DEFAULT`):

| Dial | What changes |
| --- | --- |
| `amount` | share of the spec's particles that emit (at most 1, so every budget still holds) |
| `size`, `speed` | particle size and launch speed multipliers |
| `wind_deg` | the emitter's direction and directional gravity turn about the vertical |
| `tint` | the emitter leans toward a named colour, up to a share |
| `pulse` | a pulsed effect breathes faster or slower |

Each rolled emitter also takes its own particle seed, so the scatter differs too. Grain never touches glow or alpha, and ceremony and comic effects (ink) take none. Seed 0 (the title and class select, captures, tests) is the authored look; a summary keeps its run's. `tests/world_fx_grain_test.gd` pins it; the Spillway's rows lean hardest (mist drifts and thins, steam breathes at its own pace, foam carries more silt).

## The Spillway in its parks

`spillway_fx.gd` stands world 1's anchor sets from `SPILL_PLACES` when a Spillway park's scenery builds: the powerhouse and weir gatehouse steam on their roofs (`spill_powerhouse`), the weir apron's falls (`spill_falls`), the dam's spray curtain and foot mist at its gate leaves (`landmark_dam`, once the landmark has built) and the penstock tower's vent (`landmark_penstock_tower`). They rank into `ANCHOR_SLOTS` like every anchor.

Water (the Spillway only, `WAKE_WORLDS` and `natural.gd` `FOAM_PARKS`): `WorldFx` reads the terrain's material under the ball 15 times a second. Rolling through standing water throws the wake (`spill_wake`: spray thrown back off the ball, foam rings), thicker with speed; a fast entry or a drop fires `ball_splash` once. A rising flood carries foam (`spill_flood`, hung by `natural.gd` on the water in up to four pieces along its footprint, each on its own surface height), thick while it climbs and calmer once full. `tests/spillway_fx_test.gd` checks the placements in both parks; `tools/spillway_fx_capture.gd` renders stills.

## Sound (FX-09)

The Spillway's water and steam are heard where they are drawn. `SOUNDS` in `world_fx_specs.gd` holds one row per set or hook; `tools/ace/world_sfx.py` makes the files under `assets/audio/world/` (synthesized, deterministic, in the ambience register: one-shots peak at -6.1 dBFS, loops sit at -26 dBFS RMS, every hiss low-passed, no rising sweep, nothing on the beat grid).

| Row | Sound | Plays |
| --- | --- | --- |
| `ball_splash` | `spill_splash`: a hollow plop, a slap of spray, droplets on D, A and E | once per splash, louder for a harder entry |
| `spill_wake` | `spill_wake`: a churn of small waves | while the ball rolls through water, louder with speed |
| `spill_falls` | `spill_falls`: a near roar with the pool's patter | loop while the weir's falls emit |
| `landmark_dam` | `dam_curtain`: a deep, wide, slow-rolling roar, voiced at the dam's foot | loop while the curtain emits |
| `spill_powerhouse` | `steam_breath`: a valve thunk and a soft plume | once as each steam puff starts |
| `landmark_penstock_tower` | `penstock_vent`: a low chuff and a firmer jet | once as each vent puff starts |
| `spill_flood` | `flood_foam`: bubbles fizzing over a low wash | loop on a flood's foam, quieter as it calms |

Rules: everything rides the Ambient bus, so a fight, a Warden and a boss pull it down and a warning's focus clears it (`mix_rows.gd`). Each set has one voice, on its nearest emitting anchor (`WorldFx._rank`), so a flood's four foam pieces are one loop and the two steaming roofs never breathe together; a hidden anchor and a resting world are silent, and an anchor with no WorldFx installed stays silent. Each start goes into the game's cue log (`audio.note_cue`) at the level the player hears against the effects bus, so `tools/mix/mixsim.py` weighs it. Mist, midges, soot, the water surface and the landmark beam stay silent on purpose: air has no sound, and a buzz at the ball would read as the swarm enemy's. Checks: `tests/world_fx_sound_test.gd`.

## Hooks for other systems

Fire from anywhere; with no `WorldFx` installed it does nothing.

```gdscript
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
WorldFx.fire("relay_full", relay_position)
```

| Hook | Who fires it | Plays |
| --- | --- | --- |
| `ball_splash` | the ball entering water fast (WorldFx's wake) | crown of droplets, ring, SPLOSH |
| `relay_quarter` | the relay at 25, 50 and 75 % | a ring of light traced along the relay's ground ring, so the boundary reads |
| `relay_stake` | each stake added (SR10) | brass ring and sparks off the mast top, RAISE |
| `relay_full` | the relay filling | spark fountain, ground shock ring, KA-CHUNK |
| `modifier_shown` | the pre-stage modifier card (SI3) | inked confetti burst |
| `secret_found` | entering a secret area | inked confetti, glints, OOH |
| `title_slam` | the title card landing | white speed lines, inked puffs |
| `summary_win` | the win summary's stamp | confetti popper, brass glints, PAID |

The relay's charge is a level, not a hook. Drop a relay anchor at the mast foot and feed it each tick:

```gdscript
var fx := WorldFxAnchor.make("relay")   # world_fx_anchor.gd
mast.add_child(fx)
fx.set_level(relay.progress(), not relay.inside)   # motes thicken, column climbs faster; pauses when empty
```

Weather and modifiers lay air over the world's own: `WorldFx.lay_overlay(kind)` with a weather sky id (`dust`, `storm_build`) or a modifier kind (`plenty`, `scarce`, `hidden`); `""` clears it. Weather rows already do this (`weather.gd` land and end).

## Wiring in the game

`game.gd` calls `WorldFx.hook(ctx)` once, beside the other scenery hooks. That installs one `WorldFx` under the game root. On each stage entry it swaps the air to that stage's world (a stage in the same world keeps its emitters), clears the overlay, and follows the chase camera and the ball. It rests (hidden, no new particles) on the title, class select, summary, death and victory screens. The relay is wired too: on the bus's `event_started`, `event_progress` and `event_ended` for `hold_the_relay`, it drops the relay anchor at the mast foot (scaled to the ring), follows the charge, pauses outside the ring, traces each quarter and fires `relay_full` on a win. The graphics preset reaches it through `GraphicsPreset.register_dressing_host`, and `Game.set_reduced_motion` sets `WorldFx.preferred`. `mod_far` is an anchor set: a brass flare to drop at each of a "farthest anchors" modifier's specials.

## Sets for dressing

`WorldFxAnchor.make(set_id)`, then place it. Landmark sets match the landmark ids in `park_recipes.gd`.

| Set | Where it goes |
| --- | --- |
| `spill_falls`, `spill_pipe`, `spill_pool` | foot of a waterfall or spillway lip; a pipe mouth; still water |
| `spill_powerhouse` | a powerhouse or gatehouse roof: pulsed steam and soot |
| `spill_flood` | on flood water (natural.gd hangs it; `fit` stretches it over the footprint) |
| `dig_drill`, `dig_ledge`, `dig_vent`, `dig_lamp` | a drill head (its +Z points out of the bore); a ledge edge; a floor vent; a hanging lamp (moths) |
| `hd_cable` | mid-span of a cable run (paper scraps caught in the wind) |
| `landmark_dam` | the dam's lip centre: spray curtain, foot mist, a rainbow in the spray |
| `landmark_penstock_tower` | the tower's relief valve: pulsed steam jets |
| `landmark_headframe` | twice: in the lamp shaft (falling dust) and at the sheave wheel (sparks) |
| `landmark_sinkhole` | the rim's centre at rim height: dust streaks drawn into the hole |
| `landmark_sky_island` | the island's underside: shedding rubble and long dust trails; tether sparks at the tether root |
| `landmark_spire` | the spire's waist: wind ribbons |
| `camp` | the fire pit: embers, smoke, fireflies, Moss's kettle |
| `title` | in the title's light shaft |
| `summary_win`, `summary_loss` | at the pilot on the summary stage; the loss is a ledger drifting down and one small rain cloud over the pilot |

Cables: `add_child(WorldFxCable.make(a, b, sag_m))`. Decoration only: no collision, never a latch.

## Known limits

- Stills are from software rendering on greybox stand-ins. Look, scale and frame time need a check on the 4080 once the landmark GLBs (PRs #26, #28) are in.
- Orbit velocity drew no visible spiral in the software renderer, so the sinkhole reads as inflow, not a whirlpool. Check on Vulkan before adding a tangential push.
- World air, weather overlays and the relay are wired in. The stake, modifier, secret, title and summary hooks and the landmark anchors wait on the threads that own those systems and the dressing.
