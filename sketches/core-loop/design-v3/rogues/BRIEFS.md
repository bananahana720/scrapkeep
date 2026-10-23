# Rogue fleet machines: body and anthem briefs

**Status:** briefs for the three rogue mini-bosses Andrew approved on 23 Oct (roster Q-P25, "fleet machines gone rogue"). The behaviour is in `src/combat/rogue.gd` and the stage director is in `src/world/rogue_director.gd`. Both use primitive bodies until the sculpted bodies land. Read the [tone bible](../TONE-BIBLE.md) and the approved boards in `docs/art/reference/hierarchy/` before making anything. The boards are *Off the foreman's books* (`hierarchy-rogues-moodboard.jpg`) and *Sky cable tender* (`hierarchy-rogue-sky-cable-tender-reference.jpg`).

## Canon each body must show

- **Outside the Mind's reach.** In DECISIONS, under "The Mind's reach", a few machines run outside the Mind's control. A rogue is not corrupted, and it carries no consumed purple. Its command line is cut, and a local brass governor still runs its old job on a loop. The loop is the fight. Two things show why it is free: the cut end of the command line, in oxide, and the spinning flyball governor. Both must read at 40 m.
- **All hands (principle 7).** The machine was a crew's tool. It still carries its crew number, stencilled large, and a HIRED stamp. Nobody is evil: it is a worker doing its shift, with nobody left to tell it to stop.
- **Its job is its attacks (principle 2).** Each attack is the old job done at the wrong moment. The silhouette must show the tool that makes each attack before the attack happens.
- **The weak window is the service hatch.** On the cable tender board, "the hatch opens with the work". After every strike the machine sticks for service: two plates swing open and the hatch core shows. A reel impact on the hatch is the payoff (principle 15).
- **Look (principle 12).** These are machines, so they are crisp and bevelled. The coordinator's 23 Oct pipeline note applies to their shells: sculpt each shell in Mojulo as one smooth piece, with no stacked-primitive seams. Bevels and panel lines go *on* that one piece; the body is not built from separate primitives. The crew number, governor and cut line are separate small parts.

## Pipeline (run on Andrew's PC)

1. **Mojulo sculpt:** one shell per machine, in the soft-toy proportion, with the moving parts listed below as separate pieces. Use true metres at scale 1, matching the table.
2. **Blender:** weight-paint the moving parts to the bones below, then bake vertex colour and AO with the kit's `polish.bake`. Export to `assets/models/rogues/<kind>.glb` with three parts: `<Kind>Hull` (slot `fleet_paint`), `<Kind>Armour` (slot `part_state`, the two hatch plates) and `<Kind>Core` (slot `core_state`). This is the same contract as `enemy_miniboss.glb`.
3. **Back in the cloud:** `rogue.gd` loads the GLB the way `miniboss.gd` does and keeps the primitive fallback. Add an asset test like `enemy_miniboss_asset_test.gd`.

Scale is set per site: `fit_site()` scales the whole body by the site's disc. A 40 m disc is 1.0, and the scale is clamped to 0.6 to 1.25. The islands' 20 m discs therefore get 0.6. Sculpt at 1.0.

## 1. Gate Crane No. 14 (Spillway: dam and flume)

| | |
|---|---|
| **Old job** | A gantry crane that lifts the dam's gate leaves for service. It still lifts and drops the leaf, and swings the hook block between them. |
| **Why it is free** | The command line was cut at the cab. The governor on top of the mast keeps the lift cycle going. |
| **Silhouette** | A four-legged bogie base on short rails, one tall mast, a long jib forward, a hook block on a cable under the jib's tip, and a counterweight drum at the back. Read from 100 m, it is a tall L. |
| **Size at 1.0** | Base 3.8 m square. Mast 6.5 m. Jib 7 m forward. Hook block 1.4 m. Collider radius 2.4 m, half height 3.6 m. |
| **Attacks** | **Sweep (pendulum):** the jib swings, and the hook block runs down the committed lane and back. It bats the ball sideways like a flipper. **Drop:** a gate leaf falls on the ring committed at the ball. |
| **Bones** | `CraneBody`, `CraneJib` (swing yaw), `CraneHook` (follows the lane), `CraneLeaf` (drops), `CranePlateLeft`, `CranePlateRight`, `CraneGovernor` (spins). |
| **Hatch (core)** | The drum's service hatch at the back, at the counterweight. |
| **Colour** | Petrol `#365754` body with sandstone wear, brass rails, and stencil `14` in bone `#d2c5a5`. |
| **Tone beat** | The gate leaf thuds down with a stamped KLANG. When it dies, the jib droops and the governor coasts to a stop with a sigh of steam. |

## 2. Haul Skip No. 31 (Dig: pit and sinkhole)

| | |
|---|---|
| **Old job** | An ore skip that hauls tailings from the face to the dump and tips them, out and back on its route, forever. |
| **Why it is free** | Its route receiver was crushed in a slump. The analog governor on the hoist runs the out-and-back. |
| **Silhouette** | A deep, wide bucket on four flanged wheels, with a hoist frame arching over the bucket and a tip ram underneath. It is low and wide: a bathtub that charges. |
| **Size at 1.0** | 4.4 m wide, 5 m long, 4.8 m tall to the hoist frame. Collider radius 2.6 m, half height 2.4 m. |
| **Attacks** | **Haul:** it rams down the committed lane and back again, because it still runs its route. It cannot be knocked off the route mid-haul. **Dump:** it tips the bucket, and tailings land on a ring ahead of it. |
| **Bones** | `SkipBody`, `SkipBucket` (tip pitch), `SkipWheel0` to `SkipWheel3` (roll), `SkipPlateLeft`, `SkipPlateRight`, `SkipGovernor`. |
| **Hatch (core)** | The hoist hook ring at the back. It shows when the bucket stays tipped. |
| **Colour** | Oxide `#9b513a` bucket with charcoal wheels, the Dig's E-key amber lamps, and stencil `31`. |
| **Tone beat** | A deadpan "SHIFT 31: ON TIME" card slams in on entry. When it dies, it tips the last load on itself. |

## 3. Cable Tender No. 7 (Highdraft: islands and crown)

| | |
|---|---|
| **Old job** | It keeps the cableways' tension, from the approved *Sky cable tender* board. In play it is a single-spool tender sized to an island shelf, not the colossal 40-ball span on that board, which stays a later set piece. |
| **Why it is free** | The command line is cut and the local governor holds tension, as on the board. |
| **Silhouette** | A big horizontal spool on two A-frame legs, with a boom forward carrying the mooring harpoon. Loose cable ends hang off the spool. |
| **Size at 1.0** | Spool 3.7 m across. 6 m tall. Boom 5 m. Collider radius 2.3 m, half height 3 m. |
| **Attacks** | **Harpoon (grapple):** a mooring line fires down the committed lane and reels in a ball it catches. **Whip:** the cables whip round it on a ring centred on itself, so a reeled-in ball has the wind-up to get out. |
| **Bones** | `TenderBody`, `TenderSpool` (spins), `TenderBoom` (aims), `TenderHarpoon` (flies), `TenderPlateLeft`, `TenderPlateRight`, `TenderGovernor`. |
| **Hatch (core)** | The spool's service hatch: tension, reset, reel impact, as on the board. |
| **Colour** | Petrol and copper as on the board, with brass governor, frost-blue cable sheen and stencil `07`. |
| **Tone beat** | Its intro card reads "CABLE TENDER No. 7. Tension: correct. Has never been told to stop." |

## Anthem cues (for the music lane)

Ruling (19 Oct): every mini-boss gets its own high-energy, bass-heavy EDM anthem. Each has a singable lead hook, a big-room build, a drop and a second, bigger drop. Kick and bass carry the weight, and the lead stays on top. The rogue's wind-ups are counted in beats of its anthem's bpm (`rogue.gd` ROWS), so the attacks land on the music.

| Tune id | Rogue | bpm | Key | Hook and twist |
|---|---|---|---|---|
| `anthem-gate-crane` | Gate Crane No. 14 | 140 | D (Spillway) | A 4-bar lead that swings up and back like the hook, pendulum intervals (octave, then fifth back). Twist: a muted brass stab on every KLANG of the leaf. The first drop lands on the first sweep. |
| `anthem-haul-skip` | Haul Skip No. 31 | 145 | E (the Dig) | A driving, rail-clatter offbeat bass. The lead is a there-and-back phrase that repeats a tone higher on the return. Twist: a Latin cowbell pattern under the drop. |
| `anthem-cable-tender` | Cable Tender No. 7 | 150 | G (the Highdraft) | A tense, held-note lead that tightens and snaps (sustain, then a falling run). Twist: jazz-harmony pads in the break. The second drop is the whip. |

**Phase two (Andrew, 19:02Z 23 Oct).** Below half health each rogue enters phase 2 (`rogue.gd` `enter_phase`): wind-ups shorten to 0.75, and the first attack chains into the second with no vented window. Its anthem moves to the heavier variant id, `<tune id>-heavy` (for example `anthem-gate-crane-heavy`): same key and tempo, a heavier drop. The music lane renders it next to the main take.

**How it plays in game.** `audio.gd` gives a rogue the miniboss track and moment. It plays the rogue's own tune id once `TuneMoments.TUNES` has that row and the ACE manifest exists. Until then it plays the existing `miniboss` tune. To add a track, add the `TUNES` row with hook `"miniboss"`, then the `music_rows.gd` row and the manifest. No code change is needed.
