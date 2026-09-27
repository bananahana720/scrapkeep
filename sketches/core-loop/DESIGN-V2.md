# Core-loop v2 design

This is the accepted spec for the v2 round (TRACKING EV-0588). It answers playtest entry 7.

- The approved plan is `/home/andrew/.claude/plans/synchronous-weaving-crystal.md`.
- The inputs are under `artifacts/local/v2-research/` (R1 to R4 research, I1 to I3 ideation). They are suggestions; this file decides.
- The principles are in `DESIGN-NOTES.md` and the project memory. Momentum is sacred, readability comes first, and form mirrors function.

Names are candidates taken from the Bible's class vocabulary (§5.1), not a locked roster.

## 1. One input grammar for every class

Every class uses the same keys, so the ability bar always reads LMB, RMB, F and Ctrl.

| Key | Meaning for every class |
| --- | --- |
| LMB | the class weapon |
| RMB | the class movement ability |
| F (hold, release) | the class special, as a hold-gauge-release skill shot |
| Ctrl | the smash (a slam in the air, a class flavour on landing) |
| Space | jump and double jump. At a steep face in the air it becomes the **vault kick** (engineer only). The caster holds it to glide. |
| Shift | boost (shared) |
| E, Q, wheel | engineer only: mount a pylon, winch, rope length |

- The shared air dash is gone. What it did now lives in each class's movement ability.
- A stomp or rebound refreshes one air jump and one charge of the class movement ability. That's the same single refresh the stomp gives today.

## 2. The three characters

| | **Sable**, Pylon engineer | **Rivet**, Runner-gunner | **Kest**, Demolitions caster |
| --- | --- | --- | --- |
| Fantasy | Plant a beachhead, then launch off it like a cannonball | An unstoppable laser sprinter who turns crowd control into fuel | Vanish in your own smoke, then drop a line of fire where they least expect it |
| LMB | Arc caster, unchanged; a pylon turret while mounted | Rapid laser, **unchanged** (Andrew: "the gunning feels great") | **Sticky charges.** Hold shows a lobbed arc (the projectile grammar); release throws. 16 dmg, 3.0 m radius. The fuse is 1.2 s or contact. 0.6 s between throws, at most 3 live. |
| RMB | Grapple and winch, unchanged, with a clearer reticle and its own sound | **Overdrive sprint** (hold). Immune to crowd control, +25% cruise, crush threshold −20% while active. 2.0 s per charge, 5 s cooldown. | **Smoke blink.** An 8 m dash that leaves a dust cloud and grants the cloak. 4 s cooldown. |
| F | **Detonation gauge.** A hold-release arc discharge: radius 12 to 30 m, damage scaled by the gauge, 5 s cooldown. Planting a pylon still fires a free discharge from the banked speed. | **Overdrive blast.** Hold-release: radius, damage and knock scale with the gauge, then a 3 s fire-rate boost. 6 s cooldown. | **Detonation line.** Hold draws a 6 to 14 m line (the lane grammar). Release detonates every live sticky charge in the line early, plus line damage, with +25% per charge caught (up to 3). 6 s cooldown. |
| Space extra | **Vault kick** at a steep face in the air: exit speed = incoming × 1.8, capped at 45 m/s, 1.5 s cooldown per face. An aim cone shows while a vault is available. | – | **Glide** (hold while falling). A rocket jump off its own blast: 22 to 30 m/s by proximity, 1.0 s cooldown. |
| E | Mount; the slingshot is a hold-gauge-release on Space while mounted (aim cone and gauge) | – | – |
| Smash (Ctrl) | **Arc slam**: a mint shock ring that highlights steep faces within 12 m for 2 s | **Shockwave skid**: a forward slide-smash. Each enemy hit refunds 0.5 s of sprint cooldown. | **Demo slam**: 3 mini-charges spread on landing, 5.3 dmg, 1.5 m, arming after 0.3 s |
| Passive | – | – | **Dust cloak**, 1.5 s after any own detonation or blink. Enemy acquisition range −40%. The first shot from cloak crits (+100%) and breaks the cloak. |
| Colour | Field mint | Copper | Safety amber |
| Shape | Ring | Chevron | Starburst |
| Sound | A rising arpeggio | Hi-hat rolls | Low thumps |
| Synergy hooks | `on_vault_kick`, `on_pylon_discharge`, `on_mount_planted` | `on_sprint_start`, `on_blast_release`, `on_cc_ignored` | `on_cloak_crit`, `on_rocket_jump`, `on_chain_detonation` |

**Colour, shape and sound come from one source.** Each class row in `class_def.gd` carries them. The HUD, VFX, audio and icons all read that row.

**How each class keeps momentum:**
- **Sable** banks speed rather than stopping.
- **Rivet's** sprint removes the one stop the player didn't cause, crowd control. It never removes damage.
- **Kest** hides by moving: blink, blast, glide. It never hides by standing still.

## 3. Shared: bowling-ball contact

The contact rule lives in `player_ball._on_enemy_touched`, beside the stomp and crush branches.

- **Rebound.** Applies when `enemy.weight >= heft × 1.15`, or `× 1.0` while Rivet sprints.
  - Reflect the incoming velocity across the contact normal with restitution 0.65.
  - Cap the vertical part at `jump_speed × 1.4`.
  - The refresh is the same single refresh a stomp gives.
- **Smash-through.** Applies when the enemy is lighter; this is the existing crush.
- **Pins.**
  - A knocked enemy moving faster than 6 m/s that hits another within 1.2 m deals `8 + 0.5 × speed` damage (cap 40).
  - It hits once per knock event, keyed by the carrier's instance id.

## 4. Shared: hold-gauge-release skill shots

Every F special, the caster's LMB and the slingshot follow one spec.

- **The indicator.** A sector, line or arc drawn as the committed geometry, in the class colour, never the hazard colour. The indicator is 15 to 20% larger than the damage geometry; that's the forgiveness.
- **The gauge.** A radial ring around the reticle, filling linearly over `charge_max`, which is 0.6 to 1.4 s depending on the ability.
- **Release.** The hold fraction scales damage and size from a floor, so a tap still works. At full charge it auto-fires after a 0.5 s grace.
- **Cancel.** Pressing the special again cancels, with no cooldown spent. Knock or crowd control mid-charge force-cancels the same way. Nothing is ever left stuck in a charging state.

## 5. Shared: cooldowns and charges

- Base cooldowns are 2 to 6 s.
- Every ability has `max_charges`, 1 by default. Items raise it.
- Charges recharge one at a time and stockpile. They show as pips under the slot (W1's ability-slot contract).

## 6. Risks each writer must test

1. **Vault ping-pong** between two faces. Covered by the cap and the per-face cooldown.
2. **Sprint used as a tank.** Damage still applies at the normal rate while sprinting.
3. **Detonation-line burst** against boss plating. The charge count is capped at 3.
4. **Rocket-jump flight chaining.** Neither cooldown can be driven to 0 by items. The floor is 0.4 s.
5. **Charge interrupt leak.** A crowd-control hit mid-charge clears the gauge, starts no cooldown and fires nothing.
6. **Traversal chaining past gating.** The air refresh stays at one per contact.

## 7. Loot and growth

[design-v2/I2-item-generator.md](design-v2/I2-item-generator.md) is accepted as the loot spec, with the changes below.

**Items**

- Items stay `PartDef` Resources. The new typed fields are `trigger`, `proc_coeff`, `stack_rule`, `stack_cap` and `icon_category`.
- The trigger vocabulary is closed, at 12 kinds, in `src/build/triggers.gd`. Adding a trigger kind is a code change, not data.
- **Chains end by construction.** A trigger kind can't re-post itself within one commitment pass, and `chain_depth` is at most 1.
- The generator is base × affix × element × trigger. It reuses the existing tier bands and rarity weights: common 60, uncommon 27, rare 10, rare_plus 3.
- **Stacking.** Stats that could reach 100% use the hyperbolic rule. Charges and procs use the capped rule.
- **The pool.** The 61-item table is the starting pool. The class-specific items (`glide_vane`, `anchor_spring`, `jet_vent`) only offer themselves to their own class. Item names follow §2: the engineer is Sable, the runner is Rivet, the caster is Kest.

**Changes to I2**

- **The fuzzer is a tool, not a test.** The full `item_fuzz` (200 seeds × 90 s) is `tools/item_fuzz.gd`. `tests/item_fuzz_smoke_test.gd` runs 8 seeds × 20 s, so `sketch:smoke` stays under its 120 s per-test timeout.
- **Happy accidents.** Anomalies go to `HAPPY-ACCIDENTS.md` for Andrew to mark KEEP or KILL. The five designed happy accidents ship.

**Legibility**

- A gate reads as a family shape, a rarity topper, a trigger glyph and an element glyph, with no added text.
- A pickup's colour is its element and its shape is its family. A pulse means it completes a synergy.
- A Risk of Rain-style clock with a difficulty bar sits in the HUD (from W1's timer).
- Two opt-in challenge modifiers are on the class-select screen: **Scrapless** and a **par timer**. Each is tagged in the run log.

## 8. The vertical stage

[design-v2/I3-vertical-stage.md](design-v2/I3-vertical-stage.md) is accepted as the stage 2 replacement: one gorge with three shelf heights.

**Layers**

- **Undercroft.** A heightmap shelf holding the Warden bowl and the rapids canal.
- **Ground shelf.**
- **Sky layer.** Props over a void: cable towers and hover barges on `AnimatableBody3D` with `sync_to_physics`. Barge motion and tilt are scripted.

**Getting between layers**

- Five speed-preserving transitions, with no stop anywhere: a grapple line, a glide drop, a skylight halfpipe, a geyser vent that reuses the rail maths, and chutes.
- Each class has a best route: Sable goes by the towers and a vault, Kest drops through a skylight and rocket-jumps back up, and Rivet sprints the shelf and the rapids.

**Blockers before it ships**

- The DESIGN-NOTES #39 gate-approach sweep must also cover towers, barges and tunnel roofs.
- If the ball slides on the barges, the fallback named in I3 applies.

## 9. Contraptions, focal points and events that change the terrain

Andrew added these on 2026-09-27, mid-round, in his words:

- "more steampunk and contraptions like um, steam, like lifts or launchers"
- "post-apocalyptic like futurism"
- "maps that are designed around a cluster buildings or a yeah focal point"
- events that "change the environment and cause like rocks to cave in or something to land and create a crater or um, a building being like you know kind of like destroyed and a portion of it or uh, changed or morphed into something"

The Wave 3 stage and event writers work these in:

- **Contraptions.** Momentum tools you ride, never stops:
  - steam lifts: an `AnimatableBody3D` piston platform that fires on a cycle you can read
  - steam launchers: a vent or catapult reusing the rail maths
  - pressure valves the player smashes to open a route
  - Each shows its cycle with steam and a gauge you can read at a glance, and has its own sound.
- **A focal point.** The vertical stage is built around one landmark: a ruined dam-works tower cluster. The undercroft, shelf and sky layers orbit it. It is the orientation anchor from every layer.
- **Events that change the terrain.** These come from the event director (TADR-010), always announced first (a telegraph plus a stinger on the beat). They change the committed geometry, and the new collider is exactly the drawn change.
  - **Cave-in.** Rocks seal one route and open another. A crumble telegraph runs 3 s ahead.
  - **Impact.** Something lands and leaves a crater bowl, a new halfpipe the ball can ride. A projectile-type telegraph marks the landing.
  - **Structural collapse.** Part of a tower shears off and becomes a ramp or bridge, or sheds a bonus vault.
  - Rules:
    - Momentum is sacred: a change never traps the ball inside new geometry.
    - The spawn-clear check holds the change until the ball is outside the footprint.
    - Participating (standing your ground, riding the new feature) pays a milestone reward.
    - Performance: a terrain swap pre-builds the post-change collider and swaps it in, per the ~34 ms trimesh note. It never rebuilds mid-frame.
