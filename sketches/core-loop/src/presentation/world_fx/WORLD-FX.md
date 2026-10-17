# World and event effects

The air, landmarks, events and ceremonies of Scrapkeep, as one data table and four small scripts. Player effects, and machine and boss effects, belong to their own kits.

| File | Owns |
| --- | --- |
| `world_fx_specs.gd` | Every effect (`SPECS`), what each place plays (`SETS`), weather and modifier air (`OVERLAYS`), game moments (`HOOKS`), budgets |
| `world_fx_kit.gd` | Builds an emitter from a spec; the one shader (soft puff, streak, paper, ring, glint, rainbow); the clear zone |
| `world_fx.gd` | The runtime: a world's ambient air, overlays, hooks, anchor ranking |
| `world_fx_anchor.gd` | A drop-in effect for dressing: landmarks, camp, relay, secrets |
| `world_fx_cable.gd` | A swaying cable on a catenary (shader sway, no script cost) |
| `world_fx_word.gd` | The drawn sound word (SPLOSH, KA-CHUNK, OOH, PAID) |

Stills: `tools/world_fx_capture.gd` renders every set on greybox stand-ins (command in its header). Checks: `tests/world_fx_test.gd`.

## Rules the table keeps

1. **Air never hides a threat.** Every effect that follows the camera or the ball is `ambient`: it fades out within 7 m of the ball (`CLEAR_RADIUS`) and near the lens, stays translucent, and never wears `HAZARD`, `ARC` or `ANCIENT`. The test fails any ambient spec that breaks this.
2. **Soft world, inked comic.** In-world effects have no outline. Ceremony and comic effects (title slam, summaries, the modifier announce, a secret's find) carry an ink rim, so the comic book sits on top of the world (tone bible, pillar 2).
3. **Budget.** A world's air plus its heaviest overlay stays under `AMBIENT_CEILING` (330 particles). Only the six nearest anchors inside their range emit at once. Past `lod_m` an anchor rests and shows its impostor, one soft quad that keeps a landmark's plume visible across the park for one draw call. The low preset keeps each spec's `low` share; reduced motion drops strobes and fast sparks, halves the rest, stills cables and skips words.
4. **Deterministic.** Fixed seed, no lights, no shadows, 30 fps particle step.

## Hooks for other systems

Fire from anywhere; with no `WorldFx` installed it does nothing.

```gdscript
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
WorldFx.fire("relay_full", relay_position)
```

| Hook | Who fires it | Plays |
| --- | --- | --- |
| `ball_splash` | the ball entering water | crown of droplets, ring, SPLOSH |
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

`game.gd` calls `WorldFx.hook(ctx)` once, beside the other scenery hooks. That installs one `WorldFx` under the game root. On each stage entry it swaps the air to that stage's world (a stage in the same world keeps its emitters), clears the overlay, and follows the chase camera and the ball. It rests (hidden, no new particles) on the title, class select, summary, death and victory screens. The graphics preset reaches it through `GraphicsPreset.register_dressing_host`, and `Game.set_reduced_motion` sets `WorldFx.preferred`. `mod_far` is an anchor set: a brass flare to drop at each of a "farthest anchors" modifier's specials.

## Sets for dressing

`WorldFxAnchor.make(set_id)`, then place it. Landmark sets match the landmark ids in `park_recipes.gd`.

| Set | Where it goes |
| --- | --- |
| `spill_falls`, `spill_pipe`, `spill_pool` | foot of a waterfall or spillway lip; a pipe mouth; still water |
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
- The world air and weather overlays are wired in. The event hooks (relay, modifiers, secrets, title, summaries) and the landmark anchors wait on the threads that own those systems and the dressing.
