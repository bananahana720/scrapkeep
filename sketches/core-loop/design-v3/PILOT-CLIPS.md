# Pilot clips: the animation set for six pilots

Wave 13, unit A5. This sheet settles every pilot clip: the set, the names, the idle rule, the route from pose table to GLB, who moves the mecha, the verifier, the evidence, and the wave P-E units that build it. It follows the wave-13 session decisions ("Clip set per pilot"), the six pilot sheets (`design-v3/pilots/*.md`, section 6 of each), the signal contract (`design-v3/SKILL-BAR.md` section 7) and the Hoberman mecha (`design-v3/ROSTER-LOOK.md` section 0).

Every number is a starting value to tune in play unless it cites code or a measurement. Paths are under `sketches/core-loop/` unless they start with `docs/`, `adr/` or `BIBLE.md`.

Reads with: [SKILL-BAR.md](SKILL-BAR.md), [PILOTS.md](PILOTS.md), [ROSTER-LOOK.md](ROSTER-LOOK.md), `tools/blender/PILOT-RIG.md`.

**Terms.**

- **Clip**: one Blender action, exported as one glTF animation, played by the pilot's AnimationPlayer.
- **One-shot**: a clip that plays once and ends. **Loop**: a clip whose last frame equals its first, which Godot repeats.
- **Base loop**: the loop that plays when nothing else does: `idle_loop` normally, `ult_ride_loop` while an ultimate is in flight.
- **Anchor**: a named pose a clip starts or ends on. `rest` is the rig's bind pose, the seated driving pose. `ride` is the pilot's own "both hands on the big control" pose: both hands on the copper lap bar that fires the ultimate (`ROSTER-LOOK.md` section 0.7).
- **Row**: one entry in `PilotReactions.ROWS` (`src/presentation/pilot_reactions.gd:5-18`): a bus signal mapped to a clip, a priority and a cooldown.
- **Pose table**: the per-pilot JSON file that lists each clip's key poses in a small vocabulary (section 4).
- **Contact frame**: the frame where the pilot's hand meets a cockpit control. The mecha motion code reads it to move that control at the same moment.
- **End frame E**: the last frame of a clip at 30 fps. Length is (E - 1) / 30 seconds, the convention in `tools/blender/anim_pilot_reactions.py:297`.

## 0. What exists today

Each fact below was checked in this session.

**Six GLBs, seven one-shots each.** `hero_assets.gd:29-36` maps the six classes to `assets/models/pilot_<id>_anim.glb`. Every GLB holds the same seven clips at 30 fps, each with 75 channels (25 bones times location, rotation and scale), as `tools/blender/PILOT-RIG.md:9` describes. Measured on 2026-10-10 by parsing each GLB's JSON chunk ("animation data" sums the accessors the animations reference):

| GLB | Bytes | Animation data | `drop_land` | The other six |
| --- | --- | --- | --- | --- |
| `pilot_rivet_anim.glb` | 355,292 | 91,716 | 2.167 s | `big_cheer` 2.8, `slump` 1.5, `heave` 0.8, `phew` 0.8, `brace` 0.6, `wince` 0.5 s |
| `pilot_sable_anim.glb` | 365,644 | 89,108 | 2.167 s | same |
| `pilot_kest_anim.glb` | 365,912 | 84,928 | 2.2 s | same |
| `pilot_tarn_anim.glb` | 351,764 | 97,420 | 2.167 s | same |
| `pilot_tally_anim.glb` | 312,748 | 81,200 | 2.167 s | same |
| `pilot_cannon_anim.glb` | 310,284 | 46,440 | 2.167 s | same |

The shells (`world_one/shell_<id>.glb`) carry no animations (parsed: 0 animation bytes in `shell_tarn`, `shell_cannon`, `shell_sable`).

**The router.** `hero_assets.gd` connects every bus signal that has a row (`:532-542`) and plays the row's clip through `react()` (`:572-595`). A new clip wins only with a strictly higher priority (`:587`). Cooldowns are kept per resolved clip, not per row (`pilot_reactions.gd:4`, `hero_assets.gd:591`). Every clip starts with no blend, on purpose: "the authored recoil must be visible in its first frames" (`:592-593`). A row may name a per-class clip through `class_clips` (`pilot_reactions.gd:21-22`); no row uses it today. The `near_arg` filter (`hero_assets.gd:578`) is unused too.

**The seated pose is a bone reset.** When a clip finishes, `_pilot_finished` (`hero_assets.gd:598-601`) calls `_seat_pilot` (`:604-609`), which stops the animator and resets every bone to rest. `_fit_pilot` seats the pilot the same way (`:509`), and the class card preview copies it (`src/ui/class_preview.gd:165-175`). Between clips the pilot is a statue.

**Clips are used in two other places.** The rescue cage plays `slump`, `heave` and `big_cheer` on the caged pilot directly (`src/world/rescue_site.gd:171-174`). The class card seats its preview pilot as above.

**Mecha motion is code today.** The Core, which becomes the lattice, rolls with the ball because it sits under the rolling mesh (`hero_assets.gd:401`). The Pod turns to the heading above 1.5 m/s (`:72`, `:474-476`). The Gyro hoop spins about its side axis at speed / 0.98 rad/s (`:477-480`). ROSTER-LOOK section 0.1 turns that hoop into the outer ring of the cockpit gimbal. Kest's vanes open while gliding (`:481-486`). No src code moves the named machinery nodes (`ClawPivot`, `Flywheel`, `MainBarrel` and the rest); only tests read them.

**Four build routes, no shared one.** Section 4.1 lists them. Rivet, Sable and Kest share `anim_pilot_drop.py` and `anim_pilot_reactions.py`; Tarn, Tally and the Cannon each have their own.

**Tests that pin today's set.** `tests/pilot_reactions_test.gd` requires every row's clip in every GLB (`:47`), no looping clip (`:52`), bone tracks only (`:58`), and a stopped animator after a clip (`:131`). `tests/pilot_tarn_asset_test.gd:87`, `tests/pilot_tally_asset_test.gd:155` and `tests/pilot_cannon_asset_test.gd:123-127` pin exactly seven clips; Tarn's and Tally's also require one-shots (`:110`, `:164`). The Rivet, Sable and Kest shell tests check only for missing clips (`tests/world_one_shell_rivet_test.gd:194`, `_sable_test.gd:269`, `_kest_test.gd:267`), so extra clips pass there.

**Five traps for the P-E units.**

1. `_fit_pilot` calls `_seat_pilot` even when the GLB has no AnimationPlayer (`hero_assets.gd:507-509`), and `_seat_pilot` calls `rec.animator.stop()` (`:605`). A pilot GLB without animations errors there.
2. `_connect_pilot_events` picks a handler by argument count from five handlers, for 0 to 4 arguments (`hero_assets.gd:539-540`). `ultimate_started` carries five (SKILL-BAR.md section 7). A row for it indexes past the array.
3. `pilot_cannon.py` exports the Cannon's shell as well as its pilot (`tools/blender/pilot_cannon.py:474-476`, writing `assets/models/world_one/shell_cannon.glb` per `tools/blender/world_one/shell_cannon.py:18`). Rerunning it after P-D replaces the shell overwrites the new mecha shell.
4. The Rivet, Sable and Kest reaction route reads its inspected references from `<worktree>/artifacts/anim-reactions/` (`anim_pilot_reactions.py:21`, `:213-215`). That folder is not in every worktree; the ledger and editable `.blend` scenes were kept in the main checkout's ignored workspace (`artifacts/local/visual-development/workspace/artifacts/anim-reactions/<pilot>/<pilot>-reactions.blend`).
5. `verify_pilot_drop.py` asserts the GLB holds only `drop_land` (`tools/blender/verify_pilot_drop.py:48`). It fails on every shipped seven-clip GLB, so it can only verify the intermediate drop export. No verifier checks the shipped clip set.

## 1. The clip set

Eighteen clips per pilot: the seven that exist, plus eleven new. The plan's list (idle loop, class-up pulse, two skill casts, ultimate wind-up, strike and recovery, smash flavour, unlock ceremony) is nine. SKILL-BAR adds `ult_ready` (`SKILL-BAR.md` section 4, "Ready cue"). This sheet adds `ult_ride_loop`, so the pilot holds the big control through the flight instead of dropping back to idle mid-air (section 1.3).

Pose keys may include `"pelvis": {"pitch": 0, "roll": 0, "yaw": 0}`. These optional angles use the torso's XYZ convention in degrees and rotate the `pelvis` bone at its fixed seated head. They do not move `root` or replace the torso's 55/45 spine split. Omitted pelvis fields use rest rotation. The builder applies pelvis rotation before solving the hands; the verifier retains the fixed pelvis-head, clearance, anchor and planted-hand checks. In loops, pelvis rotation has the same 6-degree cap as the spine.

### 1.1 Roster table: one row per clip, the same in all six GLBs

Blend in is the `custom_blend` seconds passed to `AnimationPlayer.play()`. Every clip hands back to a base loop with a 0.1 s blend when it ends (section 3).

| Clip | Kind | Anchors | Trigger (bus signal, filter) | Priority | Cooldown | Blend in |
| --- | --- | --- | --- | --- | --- | --- |
| `drop_land` (kept) | one-shot | rest to rest | `drop_landed`; **queues** up to 1.0 s behind `smash` | 30 | 1.5 s | 0.0 |
| `big_cheer` (kept) | one-shot | rest to rest | `boss_defeated`, `stage_cleared`, `evolution_fired` (80, 4.0 s); `part_gained` (30, 12.0 s) | 80 or 30 | as listed | 0.08 |
| `wince` (kept) | one-shot | rest to rest | `player_hit` (60, 0.8 s); `missed_drop` (40, 3.0 s) | 60 or 40 | as listed | 0.0 |
| `slump` (kept) | one-shot | rest to rest | `player_died` | 100 | 2.0 s | 0.0 |
| `phew` (kept) | one-shot | rest to rest | `near_miss`, `hold_broken` | 20 | 4.0 s | 0.08 |
| `brace` (kept) | one-shot | rest to rest | `harpoon_bit` | 35 | 1.5 s | 0.0 |
| `heave` (kept) | one-shot | rest to rest | `harpoon_smashed` | 50 | 1.0 s | 0.0 |
| `idle_loop` | loop | rest to rest | base: no clip playing and no ultimate in flight | base, -1 | none | 0.1 on return |
| `ult_ride_loop` | loop | ride to ride | base: `set_piece_phase()` returns `flight` (SKILL-BAR section 7, runtime APIs) | base, 64 | none | 0.1 on return |
| `class_up` | one-shot | rest to rest | `heft_class_changed`, which only fires on a rise (`src/core/run_state.gd:287-290`) | 50 | 4.0 s | 0.08 |
| `cast_special` | one-shot | rest to rest | `slot_cast` with argument 0 equal to `"special"` (`src/core/ability_state.gd:13`) | 30 | 1.0 s | 0.0 |
| `cast_line` | one-shot | rest to rest | `line_skill_fired` | 32 | 1.0 s | 0.0 |
| `ult_ready` | one-shot | rest to rest | `ultimate_ready`; **queues** up to 1.0 s behind anything higher | 28 | 10.0 s | 0.08 |
| `ult_windup` | one-shot | rest to ride | `ultimate_started` (five arguments) | 70 | 0 | 0.0 |
| `ult_strike` | one-shot | ride to ride | `ultimate_peak` | 68 | 0 | 0.05 |
| `ult_recover` | one-shot | ride to rest | `ultimate_landed` (69); `ultimate_cancelled` (72) | 69 or 72 | 0 | 0.0 |
| `smash` | one-shot | rest to rest | `slammed` (`src/core/game_events.gd:50`) | 36 | 1.0 s | 0.0 |
| `unlock` | one-shot | rest to rest, `root` keyed | no row: the surface that shows the unlocked pilot plays it (section 1.4) | none | once per profile | 0.0 |

Blend rule: impact and commitment clips (a hit, a cast, a slam, the wind-up, the landing) start at once, as today. Status clips (cheer, relief, class up, ready) ease in over 0.08 s, because the idle loop now moves the pilot off rest and a hard cut would show.

**The priority ladder**, highest first. A clip only cuts in over a lower number.

```
100 slump ............ death always wins
 80 big_cheer ......... boss down, stage clear, evolution
 72 ult_recover ....... ultimate cancelled (recall, bail, stage, death)
 70 ult_windup
 69 ult_recover ....... ultimate landed
 68 ult_strike
 64 [ult_ride_loop] ... the base during flight: hits and casts cannot break the ride
 60 wince ............. player hit
 50 heave, class_up
 40 wince ............. missed drop
 36 smash
 35 brace
 32 cast_line
 30 cast_special, drop_land, big_cheer (part gained)
 28 ult_ready ......... queues instead of cutting a cast
 20 phew
 -1 [idle_loop] ....... the base the rest of the time
```

**Three changes to SKILL-BAR section 7's trigger table** (`SKILL-BAR.md` section 7, "Pilot reaction triggers"), each on the veto list:

- `ultimate_landed` rises from 65 to 69. At 65 it lost to a strike still playing (68), so a short beat-rounded flight could end with no recovery.
- `ultimate_cancelled` gets a row at 72, so a recall during the wind-up (70) still brings the pilot back to rest.
- `ult_ready` drops from 45 to 28 and queues. At 45 it cut the pilot's hand off a lever mid-cast. A status cue should not erase the action that caused it.

### 1.2 Lengths per pilot

End frames, with seconds in brackets. Lengths come from each sheet's section 6, rounded to whole frames at 30 fps. Idle and ride lengths are whole beats at 171.4 BPM (the frame-exact neighbour of the 172 BPM in the Kest and Cannon sheets): idle 12 beats (4.2 s), the Cannon's idle 8 beats (2.8 s, as its sheet asks), ride 4 beats (1.4 s).

| Clip | Sable | Rivet | Kest | Tarn | Tally | Cannon |
| --- | --- | --- | --- | --- | --- | --- |
| `idle_loop` | 127 (4.2) | 127 (4.2) | 127 (4.2) | 127 (4.2) | 127 (4.2) | 85 (2.8) |
| `ult_ride_loop` | 43 (1.4) | 43 (1.4) | 43 (1.4) | 43 (1.4) | 43 (1.4) | 43 (1.4) |
| `class_up` | 31 (1.0) | 37 (1.2) | 28 (0.9) | 37 (1.2) | 31 (1.0) | 28 (0.9) |
| `cast_special` | 19 (0.6) | 19 (0.6) | 16 (0.5) | 22 (0.7) | 16 (0.5) | 19 (0.6) |
| `cast_line` | 16 (0.5) | 16 (0.5) | 15 (0.467) | 25 (0.8) | 16 (0.5) | 15 (0.467) |
| `ult_ready` | 25 (0.8) | 25 (0.8) | 25 (0.8) | 19 (0.6) | 25 (0.8) | 25 (0.8) |
| `ult_windup` | 11 (0.333) | 11 (0.333) | 11 (0.333) | 11 (0.333) | 11 (0.333) | 11 (0.333) |
| `ult_strike` | 22 (0.7) | 19 (0.6) | 16 (0.5) | 19 (0.6) | 16 (0.5) | 16 (0.5) |
| `ult_recover` | 19 (0.6) | 22 (0.7) | 19 (0.6) | 25 (0.8) | 22 (0.7) | 19 (0.6) |
| `smash` | 19 (0.6) | 22 (0.7) | 19 (0.6) | 19 (0.6) | 15 (0.467) | 18 (0.567) |
| `unlock` | 73 (2.4) | 73 (2.4) | 91 (3.0) | 91 (3.0) | 91 (3.0) | 85 (2.8) |
| **New seconds, total** | 13.1 | 13.4 | 13.3 | 14.2 | 13.4 | 11.8 |

The wind-up clip is 0.333 s against the framework's 0.35 s wind-up (`SKILL-BAR.md` section 4, "The set piece contract"). It reaches the ride pose 17 ms before the flight starts, and `ult_ride_loop` takes over from there.

Pose stories stay in each sheet's section 6. Pilot-specific limits the clip author must keep:

| Pilot | Limit | Source |
| --- | --- | --- |
| Sable | One wrench in the right hand; whole-ear hinges; tail through `tail.01` and `tail.02` | `anim_pilot_reactions.py:61`, `:127-128`, `:177-179` |
| Rivet | Visor flip only in `class_up` and `unlock`; claws through `curl.R/L` | `design-v3/pilots/rivet.md:283` |
| Kest | Wings are the arm chain (no wing bones); the preen contact check stays | `design-v3/pilots/kest.md:365`, `anim_pilot_drop.py:139-146` |
| Tarn | The face never snarls; claws carry the aggression | `design-v3/pilots/tarn.md:326` |
| Tally | The ledger stays on `spine_01`; zero ledger-to-arm intersections | `pilot_tally.py:9`, `:596` |
| Cannon | Rigid cast: every bone scale stays 1, so no squash; lenses static | `pilot_cannon.py:301-302`, `:384` |

### 1.3 How the chains read

**The ultimate.** One chain of clips follows the framework's phases (`SKILL-BAR.md` section 4, "The set piece contract"):

```
Q press      wind-up 0.35 s        flight 1.6 to 3.2 s (beat-rounded)           landing  recovery
  |-- ult_windup --|-- ult_ride_loop --|-- ult_strike --|-- ult_ride_loop --|-- ult_recover --|-- idle_loop
  rest --------> ride               peak beat: ride -> ride                     ride -------> rest
```

The ride base sits at 64, so a hit (60), a harpoon smash (50) or a class up (50) cannot break it; death (100) and boss defeat (80) can. A clip that ends on the ride anchor while the set piece is no longer in flight hands off to `ult_recover`, never to idle (section 3, rule 2).

**The slam.** One slam emits, in this order: `slammed`, then `drop_landed` (a hit) or `missed_drop` (a miss), then the class's flavour signal (`src/movement/player_ball.gd:891-902`). So:

```
slammed ------> smash (36): the pilot's slam gesture (section 5, smash column)
  hit:  drop_landed (30) queues ------> drop_land plays when smash ends
  miss: missed_drop (40) cuts in -----> wince at once (the miss reads loud)
```

The smash keys on `slammed` for all six pilots. Rend, stamp and rush emit no signal of their own (`player_ball.gd:918-941`; the rush is combat's, `src/combat/combat.gd:1589`), so the per-flavour signals in three sheets (`arc_slammed`, `skid_smashed`, `demo_slammed`) would leave the other three without a trigger. One row covers everyone, and the action-then-outcome order keeps `drop_land` alive as the hit payoff.

### 1.4 Who plays `unlock`

`unlock` has no row. A row would make the pilot you are driving play someone else's unlock: `rescue_completed("rivet")` fires while you play Sable. It plays where the unlocked pilot is on screen:

| Surface | When | Pilots |
| --- | --- | --- |
| Rescue cage (`src/world/rescue_site.gd:171-174`) | once, when the cage is spent, in place of `big_cheer`; then `idle_loop` | Rivet (`rivet`), Kest (`dig`), per `PILOT_QUESTS` (`:9`) |
| Class card preview (`src/ui/class_preview.gd:167-175`) | the first time the card is focused after the pilot unlocks, once per profile; then `idle_loop` | all six; Sable on a new profile's first focus |
| Class card under `--profile=sitting` | first focus per launch | all six |

Once per profile uses the existing seen list: `ui_profile.seen()` and `mark_seen()` (`src/ui/ui_profile.gd:69-76`) with the id `unlock_clip_<class_id>`. No save schema change.

## 2. Naming rules

1. **The seven existing names stay**, spelled as they are: `drop_land`, `big_cheer`, `wince`, `slump`, `phew`, `brace`, `heave`. Their action data stays as built (the verifier checks it, section 6).
2. **One name per role in all six GLBs.** The GLB is the pilot's namespace. The sheets' `idle`, `idle_tally`, `smash_rush`, `smash_stamp`, `smash_rend`, `unlock_tally` and `unlock_tarn` become `idle_loop`, `smash` and `unlock`. `class_clips` stays in the router for a future exception; no row uses it.
3. **A loop's name ends in `_loop`. A one-shot's name never starts or ends with `loop` or `cycle`.** The names keep that rule, but the import does not rely on it. Godot 4.7 strips a `_loop` suffix from the clip name when `nodes/use_name_suffixes=true` (Godot docs, "Node type customization using name suffixes"), so each pilot's committed `.import` sets `nodes/use_name_suffixes=false` and gives `idle_loop` and `ult_ride_loop` `"settings/loop_mode": 1` (candidate 9f8e36b). `tests/pilot_reactions_test.gd` fails if either setting is lost.
4. **Lower snake case, role first**: `cast_special`, `ult_strike`. Prefixes group roles: `cast_` for bar slots, `ult_` for the ultimate chain.
5. **A new role is a roster change.** It goes into `src/presentation/clips/roster.json` and all six GLBs in the same wave, or into none.
6. **No `RESET` action is exported.** Today's tests skip `RESET` (`tests/pilot_reactions_test.gd:49`); the import keeps `animation/import_rest_as_RESET=false`.

## 3. The idle rule

Today the seated pose is a bone reset (`hero_assets.gd:604-609`). An idle loop replaces it, and every clip returns to a base loop, not to a reset.

1. **`_seat_pilot` becomes `_to_base(rec)`.** It plays the base loop from frame 0 with a 0.1 s blend: `ult_ride_loop` while `ctx.player.set_piece_phase.call()` returns `"flight"` (the callable B3 injects, SKILL-BAR section 7), else `idle_loop`. It clears `rec.reaction` and sets `rec.priority` to the base's priority, -1 or 64.
2. **The anchor decides the hand-off.** A one-shot that ends on `ride` while the set piece is not in flight hands off to `ult_recover`. A ride pose never snaps to rest.
3. **A queued clip goes first.** A row marked `queue` that lost on priority while the current clip had at most that many seconds left plays when the current clip ends, if its cooldown allows and the set piece is idle. One slot; the higher priority wins it.
4. **Idle frame 0 equals rest exactly.** Every rest-anchored clip starts and ends on rest, so the hand-off is seamless, and "returns every bone to seated rest" (`tests/pilot_reactions_test.gd:148`) still holds at the hand-off frame.
5. **Idle amplitude cap.** No bone departs rest by more than 6 degrees on the spine, neck and head, 0.02 m at either hand, or 15 degrees on ears, tail, crest, jaw and curls. A clip that starts with no blend over a moving idle then pops by 1 to 2 px at chase distance (the 0.4 m head at 10.5 m, `ROSTER-LOOK.md` section 3). The verifier enforces the cap.
6. **The ride loop obeys the same cap around the ride pose.**
7. **Fallback that works.** A GLB without `idle_loop` keeps today's stop and reset and warns once per pilot through `_warn_once` (`hero_assets.gd:307`). A pilot with no AnimationPlayer skips the seat entirely (trap 1).
8. **Base loops never hand back by themselves.** Godot does not emit `animation_finished` for a looping animation (Godot 4.7 docs, AnimationMixer), so `_pilot_finished` only ever runs for one-shots.
9. **The class card and the rescue cage play `idle_loop` too.** The card shows a living pilot; its first frame is the same still as today.
10. **Reduced motion keeps the clips.** They carry state (a hit, a cast, a ready meter). The reduced-motion setting drops only the shared fold and full-span extras (section 5).

**Separable extra, off by default: idle on the beat.** When the base is `idle_loop`, play it at `custom_speed = music_engine.bpm() / 171.43` (`src/presentation/music_engine.gd:499`), clamped to 0.8 to 1.25, so the pilot's tap lands near the band's beat. No phase lock in the alpha.

## 4. The pose-table route

### 4.1 Today's routes

| Pilots | Scripts | Pose source | Keys | Checks before export |
| --- | --- | --- | --- | --- |
| Rivet, Sable, Kest | `anim_pilot_drop.py`, then `anim_pilot_reactions.py` | `drop_land`: `<pilot>-drop-poses.json`, 16 rows of full 25-bone snapshots with an image SHA-256 and an observation each (`anim_pilot_drop.py:86-108`), retimed by `pilot_drop_timing.py`. The six reactions: per-pilot branches in `pose()` (`anim_pilot_reactions.py:89-198`), keys at `:22-29` | Bezier, auto-clamped; `wince` linear (`:270-276`) | pelvis drift, neutral endpoints (`:279-298`) |
| Tarn | `pilot_tarn.py`, `anim_tarn.py` | a 10-number row per key: torso height and pitch, head nod and yaw, shoulder lift, both wrist targets, ear, tail, jaw (`anim_tarn.py:32-78`) | smoothstep between keys (`:98-99`), baked every frame, linear (`:146-159`) | 0.98 m clearance, pelvis drift, fixed grips, neutral ends (`:161-189`) |
| Tally | `pilot_tally.py` | `pose()` branches (`:391-467`) | linear; planted hands baked per frame (`:507-533`) | adds zero ledger-to-arm intersections (`:553-602`) |
| Cannon | `pilot_cannon.py` | `pose()` branches (`:254-302`) | linear; planted hands baked per frame (`:330-351`) | scale stays 1; grip error under 1 mm (`:382-387`) |

The pose JSON tables exist only for `drop_land` (`tools/blender/{rivet,sable,kest}-drop-poses.json`, 104 to 128 KB each, 16 rows). Every other clip lives as code.

### 4.2 One route for the eleven new clips

**Reference, pose table, Blender action, export.** The seven stay on their own routes and are never re-posed.

1. **Reference.** The pilot sheet's section 6 pose story is the default source, the way `brace` and `heave` were authored from a written brief (`anim_pilot_reactions.py:256-257`). An image is optional: one motion sheet per pilot, eleven panels, made by the current concept route and pinned by SHA-256 in the table. Images guide gestures, never rig dimensions (`anim_tarn.py:3-4`).
2. **Pose table.** `src/presentation/clips/<pilot>.json`, one file per pilot, so six units never edit the same file. It lives under `src/` because the game reads it too (the mecha motion code reads contact frames), following `src/world/reach_routes.json` (`src/presentation/set_dressing.gd:10`, `:244`). Format in 4.3.
3. **Blender action.** `tools/blender/pilot_clips.py` (new, unit PE-0) opens the pilot's base scene, which already holds the rig, the meshes and the seven actions. It adds one action per table clip, baked every frame, with linear keys. It runs the same checks as the verifier before export.
4. **Export.** It exports all actions with the exact exporter arguments of that pilot's own route (table below), so the seven re-export from unchanged actions and the mesh bytes keep their attributes. Trap (PE-0b, 2026-10-11): a Rivet, Sable or Kest base scene older than `brace` and `heave` lacks those two kept clips, so the builder resamples them from `--baseline` and prints `PILOT_CLIPS_RESTORE <pilot> <clip> <baseline>`; check 16 still guards their values. Trap (PE round 2, 2026-10-11): Godot's scene importer strips a `_loop` suffix from clip names while name suffixes are on, so `idle_loop` would import as `idle`. The six `assets/models/pilot_<pilot>_anim.glb.import` files are committed (a `.gitignore` negation, like the texture imports) with `nodes/use_name_suffixes=false` and `idle_loop` and `ult_ride_loop` set to loop. A Blender rebuild leaves them alone; `tests/pilot_reactions_test.gd` fails if one loses either setting.

| Pilot | Base scene | How a unit gets it | Exporter arguments |
| --- | --- | --- | --- |
| Rivet, Sable, Kest | `<pilot>-reactions.blend` (saved by `anim_pilot_reactions.py:315`) | copy from the main checkout's workspace (trap 4) into the unit's scratch; read only at the source | `anim_pilot_reactions.py:311-314`; no `canonical_indices` |
| Tarn | `artifacts/local/dress-preview/PTA/pilot_tarn.blend` (`anim_tarn.py:210`) | run `pilot_tarn.py -- --out <scratch>/pilot_tarn_anim.glb` (`pilot_tarn.py:232-253`) | `anim_tarn.py:197-202`, vertex colour `ACTIVE`, then `canonical_indices` |
| Tally | `artifacts/local/dress-preview/PTL/tally-rig.blend` (`pilot_tally.py:31`, `:722`) | run `pilot_tally.py -- --out <scratch>/pilot_tally_anim.glb` | `pilot_tally.py:545-550`, `ACTIVE`, `export_extras=False`, then `canonical_indices` |
| Cannon | `artifacts/local/dress-preview/PCN/pilot_cannon-rig.blend` (`pilot_cannon.py:492`) | run `pilot_cannon.py -- --no-shell` (the flag PE-0 adds; trap 3) | `pilot_cannon.py:403-407`, then `canonical_indices` |

### 4.3 The pose table format

```json
{
  "schema": "pilot-clips-v1",
  "pilot": "tarn",
  "fps": 30,
  "rig": "pilot-v1",
  "torso_scale": true,
  "controls": "tools/blender/shell_tarn.py:CONTROLS",
  "anchors": {
    "rest": "bind",
    "ride": {"torso": {"height": 0.95, "pitch": -12}, "head": {"pitch": -8},
             "hand.R": {"control": "LapBar.R"}, "hand.L": {"control": "LapBar.L"}}
  },
  "clips": {
    "cast_special": {
      "end": 22, "loop": false, "from": "rest", "to": "rest", "ease": "smooth",
      "planted": ["L"],
      "contact": {"frame": 8, "hand": "R", "control": "ClampLever"},
      "source": {"sheet": "design-v3/pilots/tarn.md", "row": "cast_special"},
      "keys": [
        {"frame": 1, "pose": "rest"},
        {"frame": 5, "torso": {"pitch": 4}, "hand.R": {"control": "ClampLever", "offset": [0, -0.06, 0.04]},
         "note": "reach: the paw rises to the lever"},
        {"frame": 8, "torso": {"pitch": -6, "height": 0.97}, "hand.R": {"control": "ClampLever", "offset": [0, 0.08, -0.05]},
         "ears": 20, "note": "throw: the vice closes"},
        {"frame": 14, "torso": {"pitch": -3}, "hand.R": {"control": "ClampLever", "offset": [0, 0.08, -0.05]},
         "note": "hold"},
        {"frame": 22, "pose": "rest"}
      ]
    }
  }
}
```

**Partial tables (2026-10-18).** A table sets `"partial": true` to ship only the roles listed under `clips`; the verifier and `tests/support/pilot_clip_trigger.gd required_for` then require the seven kept clips plus those roles, not all eleven. Tarn's table lists `idle_loop` only. Sable and Cannon's idle tables wait in `src/presentation/clips/pending/` (a file there is inert: the game, verifier and tests read only `clips/<pilot>.json`) until their GLBs are exported; moving the file up is part of that export.

**The pose vocabulary.** A field left out of a key means its rest value. Angles in degrees, distances in metres, in Pod space with Blender axes (+Z up, +Y forward, +X anatomical right, `PILOT-RIG.md:11`).

| Field | Drives | Precedent |
| --- | --- | --- |
| `torso.height` | spine scale; 1 is rest. Refused when `torso_scale` is false (the Cannon) | `anim_tarn.py:116-119` |
| `torso.pitch`, `.yaw`, `.roll` | split 55/45 over `spine_01` and `spine_02` | `anim_tarn.py:114-115` |
| `pelvis.pitch`, `.roll`, `.yaw` | optional XYZ rotation on `pelvis`, in degrees; head stays fixed | section 1; `pilot_clips.apply` |
| `head.pitch`, `.yaw`, `.roll` | `head` | `anim_pilot_reactions.py:181` |
| `neck.drop` | `neck` location z | `anim_pilot_drop.py:50` |
| `shoulder.lift` | `shoulder.R/L` location z | `anim_tarn.py:125` |
| `hand.R`, `hand.L` | `{"at": [x, y, z]}` or `{"control": name, "offset": [x, y, z]}`, solved by the pilot's arm solver | `anim_rivet_drop.solve_arm`; Tally's `solve_tally_arm` (`pilot_tally.py:361-390`) |
| `wrist.R`, `wrist.L` | world hand rotation | `world_hand`, `anim_tarn.py:137` |
| `curl.R`, `curl.L` | claw or finger curl | `anim_pilot_reactions.py:189-195` |
| `ears`, `tail`, `jaw`, `crest`, `goggles` | the matching bones; ears mirror their yaw; `tail.02` takes -0.55 of `tail.01` | `anim_tarn.py:121-126` |
| `tool.R` | Sable's wrench | `anim_pilot_drop.py:82-83` |
| `root` | `[x, y, z]` location; `unlock` only | `PILOTS.md:67` |
| `note` | one concrete observation per key, as every route records | `anim_pilot_reactions.py:30-82` |

Clip keys: `end` (end frame), `loop`, `from` and `to` (anchors), `ease` (`smooth` or `linear`; `linear` for impact clips, as `wince` and `brace` are; `spline` for loops that should never dead-stop: a cardinal spline through the keys, tangents from the neighbouring keys, wrapping at a loop's seam, added 2026-10-18 for the Sable, Tarn and Cannon idles), `planted` (hands held at their grip every frame), `contact` (cast and smash clips; frame, hand and control), `preen_frames` (Kest only: the frames where the feather tip meets the beak, measured by check 17), `source`.

`controls` names the shell recipe's `CONTROLS` table: control name to Pod-space position. P-D's shell units write it; PE-0 defines the format. Since PE-0b (2026-10-11) the builder and check 14 read each control from one source, the pilot's shipped shell GLB (`roster.json` `shell`), by walking its `Control.*` and `LapBar.*` nodes up to `Pod` (`tools/blender/pilot_arm.py`). A table's hand-copied `control_points` block is ignored, never trusted. A control the shell lacks resolves to the grips `(±0.32, 0.40, 0.05)` (`anim_tarn.py:19`) and prints `PILOT_CLIPS_STANDIN <pilot> <control>`; the cast clip is re-targeted when P-D ships that control.

**Baking rules** (in `pilot_clips.py`). Interpolate every field between keys with the clip's ease. Bake every frame and key it linear, so nothing overshoots between inspected keys (the reason `pilot_cannon.py:323` gives). Re-solve planted hands every frame, as `pilot_cannon.py:330-345` and `pilot_tally.py:507-527` do. For a loop, write frame E equal to frame 1. After baking, write a full 25-bone snapshot per key to the evidence folder as `poses.json`, the receipt `anim_pilot_reactions.py:299` keeps.

### 4.4 How a writer adds one clip to one pilot

Run from the repo root (`PILOT-RIG.md:45`). Blender 5.2.2, two threads, a 12 GiB address-space cap (`PILOT-RIG.md:72`).

**Before step 4: never run `pilot_cannon.py` without `--no-shell`.** It rewrites `shell_cannon.glb` (trap 3).
**Before step 4: copy the Rivet, Sable or Kest base scene; never write into the main checkout's workspace.** It is the only copy of those inputs (trap 4).

1. Read the clip's row in this sheet (1.1, 1.2) and the pose story in the pilot's sheet, section 6.
2. Add the clip to `src/presentation/clips/<pilot>.json`: `end`, anchors, ease, planted hands, contact, source, and one key per beat with a `note`.
3. A clip role not in `src/presentation/clips/roster.json` is a coordinator change for all six pilots (rule 2.5). Stop and report it.
4. Keep a baseline: `cp sketches/core-loop/assets/models/pilot_<pilot>_anim.glb <scratch>/baseline/`.
5. Build:
   `prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/pilot_clips.py -- <pilot> --base <base.blend> --evidence artifacts/local/alpha/push/w13/clips/<pilot>`
6. Verify: `prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/verify_pilot_clips.py -- <pilot> --baseline <scratch>/baseline/pilot_<pilot>_anim.glb`. Expect `PILOT_CLIPS: PASS <pilot> 18 clips` and exit 0.
7. Render its strip on card 1 (section 7.1).
8. Run the Godot checks: `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/pilot_clips_<pilot>_test.gd`, then `pilot_reactions_test.gd` the same way (`GODOT_BIN` or `GODOT` selects your Godot 4.7.2 binary; `tools/coordinator/compile_check.sh:6` defaults `GODOT` to `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`).
9. Fence check: `git diff --name-status` shows only the unit's SCOPE files.

## 5. Mecha motion: code drives it

**Call: code moves every part of the mecha; clips move only pilot bones.** Three reasons:

1. **Continuous motion follows live values** a clip cannot know: roll speed, aim, the glide state. The code already does this (`hero_assets.gd:474-486`).
2. **Shells are swapped.** `_fit` frees and rebuilds the shell on a class change (`hero_assets.gd:369-374`), and P-D adds heft layers and shell variants on one loader path (`ROSTER-LOOK.md` section 5). Clips inside shells would multiply by variant and layer, and each shell would need its own AnimationPlayer kept in step with the pilot's.
3. **One fact, read twice.** A control moves when the pilot's hand reaches it. The contact frame lives once, in the pose table. `pilot_clips.py` keys the hand to it; the mecha motion code reads the same number from the same JSON and starts the control's throw then. The hands always match the bar (`ROSTER-LOOK.md` section 0.4).

| Motion | Node | Reads | Driver and owner | Starting values |
| --- | --- | --- | --- | --- |
| Lattice tumble | Core | the ball's true rotation | parenting under the rolling mesh (`hero_assets.gd:401`); exists | none |
| Gimbal rings hold the pod level | Pod > Gyro, today's hoop, becomes the outer gimbal ring; a new inner ring sits inside it (`ROSTER-LOOK.md` sections 0.1 and 0.7) | the lattice's tumble around the upright Pod | code in `_steer_pod`, replacing today's speed spin (`:477-480`); P-D base mecha unit | the outer ring pivots left-right, the inner ring front-back |
| Pod turn to heading | Pod | heading above 1.5 m/s | `_steer_pod` (`:474-476`); exists | rate 10 |
| Vanes open | VaneL, VaneR | `kit.gliding` | `_steer_pod` (`:481-486`); exists | 90 degrees, rate 8 |
| Weapon ring yaw to aim | Pod > WeaponRing | aim direction | code in `_steer_pod`; P-D base mecha unit, HOBERMAN-BASE (`ROSTER-LOOK.md` sections 0.1 and 0.6) | rate 14 |
| Gap panels slam in and fling out | Pod > `HeftC2`..`HeftC5` panel holders (outer face at radius 0.92, at the rest-pose positions the `Gap.NN` empties mark); the Core part of class III carries only the thicker tread caps (`ROSTER-LOOK.md` sections 0.3 and 5; `CUSTOMIZE.md` section 6) | `heft_class_changed`, `heft_class_dropped` | code tweens; P-D (`ROSTER-LOOK.md` section 0.3, timings in section 5) | in 0.18 s with 1.2 overshoot; out 0.45 s |
| Machinery glow when ready | `class_accent` emission | `ultimate_ready` until `ultimate_started` | code; P-D (`SKILL-BAR.md` section 4, "Ready cue") | 1 Hz breathe |
| Lattice fold on landing (extra) | Core scale | `landed` impact | code tween; P-D, on the veto list (`ROSTER-LOOK.md` section 0.5) | 0.92, back over 0.25 s |
| Lattice full span for the ultimate (extra) | Core scale | `ultimate_started` opens it; `ultimate_landed` or `ultimate_cancelled` folds it back | code tween; P-D, on the veto list (`ROSTER-LOOK.md` section 0.5) | about 1.15, hub modules locked out |
| Cannon fold for Fire Mission | Core scale | `ultimate_started` folds to 0.85, `ultimate_landed` or `ultimate_cancelled` springs back in 0.12 s | code tween; PE-0 | base, not an extra |
| **Control throw on a cast** | Pod > `Control.<name>`, in the slot 2 and 3 bank beside the right yoke | the row's signal, at the clip's contact time | **`src/presentation/mecha_motion.gd`, new in PE-0** | lever 35 degrees, crank half a turn, plunger 0.06 m; throw 0.08 s, return 0.25 s |
| **Trigger squeeze on fire** | Pod > `Control.Trigger`, on the twin yokes (label "1: <weapon>") | `shot_fired` | `mecha_motion.gd`, PE-0; at most once per 0.12 s | 12 degrees, 0.06 s |
| Pedal kick on Shift | Pod > `Control.Pedal.L`, `Control.Pedal.R` | the movement chip's signal | `mecha_motion.gd`, PE-0 | 20 degrees, 0.06 s |
| Lap bar haul | Pod > `Control.LapBar` | `ultimate_started` to `ultimate_landed` or `ultimate_cancelled` | `mecha_motion.gd`, PE-0 | 25 degrees back |

The weapon gets no pilot clip. At fire rates of 15 to 22 shots a second (Tally, `PILOTS.md:37`) a clip per shot would block every reaction. The yoke trigger squeeze carries it.

**Controls per pilot**, from ROSTER-LOOK's cockpit column (`ROSTER-LOOK.md` section 0.2), its cockpit control rule (section 0.7) and the sheets' pose stories. Section 0.7 sets one layout for all six:

- The twin yokes take the hands and carry the weapon trigger, labelled "1: <weapon>".
- Slots 2 and 3 sit in a small lever or button bank beside the right yoke, labelled "2: <slot 2>" and "3: <slot 3>".
- The ultimate is the largest control, a two-handed copper bar across the lap, labelled "Q: <ultimate>". Every `ride` anchor puts both hands on it.
- The Shift verb is on the two pedals, labelled "Shift: <movement>". The rig has no leg bones (veto 14), so no clip keys the pedals.
- The smash (Ctrl) has no control of its own. Its clip braces on the yokes or the seat frame.

P-D places the controls and names them `Control.<Name>` in the shell recipe's `CONTROLS`; P-E keys hands to them. Skill names come from `PILOTS.md` section 1.

Shared nodes for all six: `Control.Grip.L` and `Control.Grip.R` on the twin yokes (the forge shell brief's socket names, `tools/asset-forge/kinds/model/brief.shell.md:20`), `Control.LapBar` with hand points `LapBar.L` and `LapBar.R`, and `Control.Pedal.L` and `Control.Pedal.R`.

| Pilot | `cast_special`: slot 2, in the bank | `cast_line`: slot 3, in the bank | `ride` anchor: the lap bar | `smash` |
| --- | --- | --- | --- | --- |
| Sable | `GaugeLever`, "2: Arc discharge" (a paw slaps it) | `SpoolBrake`, "3: Bank Shot" (both paws haul) | `LapBar`, "Q: Cable Run" | a paw slaps the seat frame |
| Rivet | `Lever`, "2: Overdrive Blast" (both claws slam down) | `WinchLever`, "3: Line Drive" (one claw yanks) | `LapBar`, "Q: Foundry Cutter" | lean into the skid, both yokes planted |
| Kest | `FusePlunger`, "2: Detonation line" (a wing punches it, then sweeps along the aim) | `ChargeKey`, "3: Cable Charge" (a wing tip taps it) | `LapBar`, "Q: Windhover" | one wing over her head, the other on its yoke |
| Tarn | `ClampLever`, "2: Claw clamp" | `DrumLever`, "3: Claw Drag" (two hauls) | `LapBar`, "Q: Redjaw Rend" | both yokes to the chest |
| Tally | `CardTab.1`, "2: Gather Plate" (deal a card) | `CardTab.2`, "3: Ledger Clip" (punch the tab down, tug twice) | `LapBar`, "Q: Plate Return" | both paws drive the yokes down like a stamp; the stamp sole hub fires below (`ROSTER-LOOK.md` section 0.2) |
| Cannon | `PlateCrank`, "2: Cannon Plate" (half a turn) | `CableClamp`, "3: Lane Charge" (paddle slap) | `LapBar`, "Q: Fire Mission" | one paddle slaps the seat frame |

`CardTab.0`, `CardTab.1` and `CardTab.2` sit on `CardBay.0`, `CardBay.1` and `CardBay.2`; Tally's slot 2 control is `CardTab.1` and her slot 3 control is `CardTab.2`.

The pilot hangs directly under Pod (`hero_assets.gd:526`), so hand and control share one frame, Pod space.

## 6. The reaction-clip verifier

**`tools/blender/verify_pilot_clips.py -- <pilot> --baseline <glb>`**, new in PE-0. It runs on the shipped GLB, not on the Blender scene, so it checks the bytes Godot loads. It reimports the GLB into an empty Blender scene, the way `verify_pilot_drop.py:69-71` does, and samples every clip at half-frame steps.

**Structure, from the GLB's JSON chunk (no Blender needed):**

1. The clip set equals `roster.json` exactly: 18 names, none missing, none extra, no `RESET`. An empty set fails.
2. Each clip starts at 0 s and lasts the pose table's (E - 1) / 30 s within 1/60 s.
3. Names ending in `_loop` are exactly the table's loops; no one-shot name starts or ends with `loop` or `cycle` (rule 2.3).
4. One skin, 25 joints, and the `pilot-v1` hierarchy (`PILOT-RIG.md:23-40`).
5. Tracks target joints only, matching `tests/pilot_reactions_test.gd:53-58`.
6. Mesh primitives keep the baseline's attribute sets (`JOINTS_0`, `WEIGHTS_0`, colour), triangle count and draw count.
7. Size: GLB at most 1,024 KB; animation data at most 300 KB. (Raised from 640 KB on 18 Oct 2026 for the model polish, tools/blender/POLISH.md: a soft-toy pilot body carries about 6,000 to 7,000 vertices, about 470 KB of mesh.)

**Pose and geometry, sampled every half frame after reimport:**

8. Endpoints match the declared anchors: `rest` is the bind pose within 1e-5 per component; `ride` matches the table's ride pose within 1e-4.
9. Loops are seamless: frame E equals frame 1 within 1e-5.
10. Idle and ride amplitude stay inside the caps (section 3, rules 5 and 6), compared with a 1e-5 tolerance for float32 rounding after reimport.
11. No root motion: the pelvis head stays within 1e-6 of `(0, 0, -0.30)`, as every route checks (`anim_tarn.py:179`). `unlock` alone may move `root`, and it must end at rest.
12. Clearance: every skinned vertex stays inside 0.98 m, today's limit in all four routes (`anim_pilot_drop.py:129`, `anim_tarn.py:178`, `pilot_tally.py:592`, `pilot_cannon.py:382`). `unlock` is exempt. The receipt also records each clip's maximum radius as the clip envelope (section 10, first risk).
13. Planted hands stay within 3 mm of their target (Tally's bound, `pilot_tally.py:595`).
14. At each contact frame the named hand is within 10 mm of its control's position, read from the shipped shell GLB through the same lookup the builder uses (`pilot_arm.control`).
15. Scale: the Cannon keeps every bone scale at 1 within 1e-5 (`pilot_cannon.py:384`); the others stay between 0.7 and 1.4 on any axis.
16. The seven kept clips are unchanged: sampled bone values equal the baseline GLB's within 1e-5.
17. Pilot extras keep running: Kest's preen contact under 5 mm (`anim_pilot_drop.py:146`) on the retained `drop_land` and at every frame a new clip lists in `preen_frames`, and Tally's zero ledger-to-arm overlaps (`pilot_tally.py:596`) on every half-frame sample of every new clip. The preen is one pose, not a running motion, so a clip without a preen beat lists no `preen_frames` (ruling, 2026-10-11, PE-0b gate).

**Receipt.** `artifacts/local/alpha/push/w13/clips/<pilot>/verify.json`: the GLB's SHA-256 and bytes, per-clip length, anchors error, loop seam error, amplitude, envelope, grip and contact errors, and a verdict. It prints `PILOT_CLIPS: PASS <pilot> 18 clips` and exits 0, or names the first failure and exits 1.

**It must be able to fail.** `--selftest` builds four seeded defects from a clean synthetic GLB and requires each to FAIL: a one-shot whose last frame sits 3 degrees off rest, a loop named `idle` without `_loop`, a missing `cast_line`, and a track on a mesh node. The clean copy must PASS.

**Roster pass.** `verify_pilot_clips.py -- --roster` reads all six receipts and flags any role where two pilots' clips are reskins: a mean bone-rotation distance under 5 degrees across the clip's keys. It also writes the roster envelope (the largest pilot radius per clip) to `artifacts/local/alpha/push/w13/clips/envelope.json` for the P-D mecha units.

## 7. Evidence per clip and per pilot

### 7.1 A rendered strip per clip

`tools/blender/render_pilot_clips.py -- <pilot> [--clip <name>]`, new in PE-0. It imports the shipped pilot GLB and the pilot's shell GLB, seats the pilot at identity under Pod (`PILOT-RIG.md:11`), and renders from the reimported bytes, as `render_pilot_reactions.py:1` does.

| Item | Value |
| --- | --- |
| Rows | Row 1: the resting chase camera (7.5-unit arm, 65-degree vertical field of view, pitch -0.30, anchor height 0.8, `PILOT-RIG.md:58`), Core visible. Row 2: a three-quarter front close-up, 2.6 m, 35 degrees, Core hidden so the pose reads |
| Frames | Every clip: 5 per row. Collapse each consecutive run of equal key poses, ignoring `frame` and `note`, to its first frame. Always include the first contact beat, identified by the clip's `contact.frame`, a key's `contact` field or its contact note. Fill the other cells evenly from the remaining beats in time order. With fewer than 5 beats, use even frame spacing while retaining the first contact beat. Loops include their end beat to show the seam |
| Cell size | 480 by 360 px, with a 24 px label band (clip, frame, seconds) |
| Strip size | 2,400 by 768 px for every clip, so width does not reveal whether it loops |
| Video | `<clip>.mp4`, chase row only, 960 by 540, 30 fps; loops play three times |
| Contact sheet | `sheet.png`: all 18 clips, the chase cell at each clip's contact or peak frame |
| Path | `artifacts/local/alpha/push/w13/clips/<pilot>/<clip>.png`, `<clip>.mp4`, `sheet.png` |
| Renderer | Cycles on card 1, 16 samples with denoise |

Run it through the queue:

`sketches/core-loop/tools/coordinator/gpu_queue.sh --gpu 1 --need 3000 --name pe-<pilot>-strips -- blender --background --python-exit-code 1 --python sketches/core-loop/tools/blender/render_pilot_clips.py -- <pilot> --device CUDA`

The queue holds card 1's lock for the run and exports `CUDA_VISIBLE_DEVICES` (`tools/coordinator/README-gpu.md:3-6`). Card 0 stays free for FLUX boards and Terrain3D builds (plan, "How the session runs"). Estimate: 180 strip cells and about 640 video frames per pilot, 10 to 15 minutes on the 3060 (rough estimate, not measured).

**Blind read.** A fresh verifier sees the eleven new strips of one pilot with the labels cropped and names each clip's role. Two or more wrong names in eleven send the pilot's unit back for one fix round.

### 7.2 A runtime trigger test per pilot

`tests/pilot_clips_<pilot>_test.gd`, one file per pilot, on a shared helper `tests/support/pilot_clip_trigger.gd` (PE-0). It boots the game the way `tests/pilot_reactions_test.gd` does (fit the class, `hero._process(0.0)`) and drives the real bus.

1. After the fit, the base is `idle_loop`, looping, at priority -1.
2. Each new row: emit the real signal with representative arguments (for example `slot_cast.emit("special", <the class's special id>, Vector3.ZERO)`). The playing clip is the row's clip. A filtered-out argument (`slot_cast("line", ...)`) plays nothing.
3. Every one-shot hands back to `idle_loop`, with every bone at rest on the hand-off frame.
4. The ultimate chain, with a stub `set_piece_phase`: `ultimate_started` (five arguments) plays `ult_windup`; past 0.34 s in flight the base is `ult_ride_loop`; `player_hit` is refused; `ultimate_peak` plays `ult_strike`, then the ride again; `ultimate_landed` plays `ult_recover`, then `idle_loop`. A strike that ends with the phase idle hands off to `ult_recover`. `ultimate_cancelled("recall")` during the wind-up plays `ult_recover`.
5. The slam chain through the real `player._on_slammed` (as `tests/pilot_reactions_slam_test.gd:30-31` does): with an enemy in reach, `smash` then `drop_land` then `idle_loop`; with none, `wince` cuts the smash.
6. `ult_ready` emitted during `cast_special` waits, then plays when the cast ends.
7. `heft_class_changed` plays `class_up`; `heft_class_dropped` plays nothing.
8. On `cast_special`, the shell's `Control.<name>` has moved past half its throw by the contact time plus 0.05 s. A shell without the control prints `SKIP control <name>` and counts it.
9. Clip playback leaves `body().linear_velocity` and `state.velocity` unchanged (`tests/pilot_reactions_test.gd:149` pattern).
10. The class card plays `unlock` on the first focus of a fresh profile, then `idle_loop`; a second focus plays only `idle_loop`.
11. The test states its expected check count and fails on any other count, so an empty run cannot pass.

### 7.3 Measures: how each part shows it works

| Part | Measure | Healthy (start) |
| --- | --- | --- |
| The router | a `pilot_clips` row in the run log (`src/core/run_log.gd`): plays per clip, refusals by reason (cooldown, priority, missing), queued plays | in a bot run of world one, `smash` and `drop_land` both play; `missing` stays 0 |
| The idle | share of play time on `idle_loop` | 60 to 85 percent; above 90 means the reactions are not landing |
| The ride | `ult_ride_loop` seconds per ultimate | about the flight time; 0 means the chain broke |
| Readability | the blind read in 7.1 | at most one miss in eleven per pilot |
| Distinctness | the roster pass in section 6 | no reskin pair |
| Feel | one line in the sitting checklist: "Did you see the pilot work the lever when you cast?" | Andrew's yes |

## 8. Implementation map: wave P-E

**Order.** PE-0 first and alone in the shared files, after B1 (the new signals exist) and B3 (`set_piece_phase` exists). Then six pilot units in parallel. Each pilot unit starts after that pilot's P-D shell unit if its cast clips should meet the new controls; otherwise it uses the grips as stand-ins and re-targets later. PE-INT closes the wave. Writers: `scrapkeep-writer` on Opus, because posing and timing are design judgement; verifiers `scrapkeep-verifier` (Opus medium); gate `scrapkeep-reviewer-medium`. Every brief carries GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN and REPORT.

### PE-0: clip framework

- **SCOPE.** `src/presentation/pilot_reactions.gd` (the new rows; row keys `blend`, `arg` as `[index, value]` in place of the unused `near_arg`, and `queue` in seconds; a `BASES` table). `src/presentation/hero_assets.gd` (`_pilot_event_5`; `react()` reads the new keys; `_to_base` replaces `_seat_pilot`; the anchor hand-off; the queue slot; the null-animator guard; calls into the mecha motion code). `src/presentation/mecha_motion.gd` (new). `src/presentation/clips/roster.json` (new). `src/ui/class_preview.gd` (idle and first-focus unlock). `src/world/rescue_site.gd` (unlock when spent). `src/core/run_log.gd` (the `pilot_clips` row). `tools/blender/pilot_clips.py`, `verify_pilot_clips.py`, `render_pilot_clips.py` (new). `tools/blender/pilot_cannon.py` (the `--no-shell` flag only). `tests/support/pilot_clip_trigger.gd`, `tests/pilot_clips_policy_test.gd` (new). `tests/pilot_reactions_test.gd` (re-pin, below).
- **Rows go live at once.** `react()` already refuses a clip the GLB lacks (`hero_assets.gd:585`), so a pilot without the new clips simply does not react, as today. `pilot_reactions_test.gd:47` is re-pinned with a dated header: a pilot whose `src/presentation/clips/<pilot>.json` exists must carry all 18 clips; a pilot without one must carry the seven. `:52` allows loops only for names ending in `_loop`; `:131` expects `idle_loop` playing after a clip when the GLB has it.
- **ACCEPTANCE.**
  - With today's GLBs every existing test passes, and the base falls back to stop and reset with one warning per pilot.
  - `pilot_clips_policy_test.gd` proves routing on synthetic clips, the way the policy fixture at `pilot_reactions_test.gd:114-123` duplicates `drop_land`: base hand-off, the ride base, the chain priorities, the slam queue, the miss cut-in, the argument filter, and a five-argument signal connecting.
  - `verify_pilot_clips.py --selftest` fails all four seeded defects and passes the clean copy.
  - `pilot_cannon.py --no-shell` leaves `shell_cannon.glb` byte-identical (SHA-256 before and after).
- **VERIFY.** `tools/coordinator/compile_check.sh`; `node scripts/sketch-lint.mjs --sketch core-loop`; the two tests by `--script`; the self-test; then `npm run sketch:smoke -- --sketch core-loop`.
- **GPU.** None. Blender work here is CPU.
- **TIMEBOX.** 3 hours.

### PE-SABLE, PE-RIVET, PE-KEST, PE-TARN, PE-TALLY, PE-CANNON: one unit per pilot

- **SCOPE.** `src/presentation/clips/<pilot>.json` (new); `assets/models/pilot_<pilot>_anim.glb` (rebuilt); `tests/pilot_clips_<pilot>_test.gd` (new); the pilot's own asset-test re-pin to 18 clips with loops for `_loop` names (Tarn `tests/pilot_tarn_asset_test.gd:87`, `:110`; Tally `tests/pilot_tally_asset_test.gd:155`, `:164`; Cannon `tests/pilot_cannon_asset_test.gd:123-127`; Rivet, Sable and Kest need none); evidence under `artifacts/local/alpha/push/w13/clips/<pilot>/`.
- **ACCEPTANCE.**
  - `verify_pilot_clips.py -- <pilot>` passes with 18 clips and the seven unchanged.
  - 18 strips, 18 videos and the contact sheet exist; the blind read misses at most one of eleven.
  - `pilot_clips_<pilot>_test.gd` passes at its stated check count; `pilot_reactions_test.gd` and the pilot's asset test pass.
  - Every key carries a `note`; image sources carry a SHA-256.
- **VERIFY.** Section 4.4 steps 4 to 9, plus `npm run asset:inspect -- assets/models/pilot_<pilot>_anim.glb --max-tris 4600` with status pass.
- **GPU.** Strips on card 1 through `gpu_queue.sh --gpu 1` (section 7.1). Six units queue on one lock, so the strips serialize; build and verify first, render last. An in-engine look of three clips (`idle_loop`, `cast_special`, `ult_strike`) through `tools/look_capture.gd` on card 1 with `--display` once P-D's pilot look subject exists in `tools/look_subjects.gd`; until then it is a stated gap, not a pass.
- **FORBIDDEN.** Editing the seven kept actions; writing to the main checkout's workspace; running `pilot_cannon.py` without `--no-shell`; editing `roster.json`, `pilot_reactions.gd` or `hero_assets.gd`.
- **TIMEBOX.** 2.5 hours. **PE-CANNON**, the showcase, gets a second blind reader and 3 hours.

### PE-INT: integration

- **SCOPE.** Remove the transitional branch in `tests/pilot_reactions_test.gd:47` (all six must carry 18). Run the roster pass. Hand the envelope to P-D. Serve the six contact sheets as one review page in a tab of Andrew's Chrome.
- **ACCEPTANCE.** Roster pass with no reskin pair. Full smoke green. A world-one bot run whose `pilot_clips` row shows `smash`, `drop_land`, `cast_special` and at least one ultimate chain, with `missing` at 0. A perf ratio under 1.3x against the pre-wave base on card 1.
- **TIMEBOX.** 1 hour.

### File conflicts at a glance

| File | Writers |
| --- | --- |
| `hero_assets.gd` | PE-0 (`react`, seat, events); the P-D units (PILOTS and SHELLS rows, `_steer_pod`). Different functions; the coordinator merges PE-0 and P-D serially |
| `pilot_reactions.gd`, `roster.json`, `mecha_motion.gd` | PE-0 only |
| `src/presentation/clips/<pilot>.json`, `pilot_<pilot>_anim.glb` | that pilot's unit only |
| `tools/blender/shell_<pilot>.py` and `world_one/shell_<pilot>.py` (`CONTROLS`) | P-D only; P-E reads |
| `run_log.gd` | B3 (ultimate rows), then PE-0 (one field); sequential waves |

## 9. Budget and performance

| Item | Today (measured) | After P-E (projected) | Cap the verifier enforces (start) |
| --- | --- | --- | --- |
| Clips per GLB | 7 | 18 | exactly 18 |
| Seconds of animation per GLB | 9.17 | 20.9 to 23.4 | none |
| Animation data per GLB | 46 to 97 KB | about 106 KB (Cannon) to 248 KB (Tarn) | 300 KB |
| GLB size | 310 to 366 KB | about 370 KB (Cannon) to 503 KB (Tarn) | 1,024 KB (640 KB before the model polish) |
| Pilot mesh | 4,600 tris, 3,100 verts, 5 draws (`assets/asset_budgets.json:45-49`) | unchanged | unchanged |

The projection scales each pilot's measured rate (Tarn 10.6 KB per second of animation, the Cannon 5.1, likely because its rigid cast keeps every scale constant) by the new seconds in 1.2. Godot's import keeps `animation/remove_immutable_tracks=true` and `animation/fps=30` (`assets/models/pilot_tarn_anim.glb.import`), which drops constant tracks.

**Runtime.** Today the animator stops between clips (`hero_assets.gd:605`). With a base loop, one AnimationPlayer and one 25-bone Skeleton3D update every frame for the player's pilot, plus one on the class card. That is small next to the ball budget in `ROSTER-LOOK.md` sections 5 and 8. PE-INT measures it against the pre-wave base on card 1 under the 1.3x rule; absolute frame times come only from Andrew's display. The mecha motion code adds tweens on a handful of nodes and must not add a light or a per-instance `material_override` (`ROSTER-LOOK.md` section 8).

**Build cost.** CPU Blender at two threads under a 12 GiB cap, as `PILOT-RIG.md:72` records. Strips are the only GPU work.

## 10. Risks, with the cheapest check

| Risk | Cheapest check |
| --- | --- |
| The cockpit gimbal's two rings hang close round the seat and pivot (`ROSTER-LOOK.md` sections 0.1 and 0.7). The tumbling lattice's inner face sits near 0.94 m (outer radius 0.975 less the 0.035 m strut pairs, section 0.1). The seven kept clips were only held under 0.98 m | the verifier's envelope: P-D sizes the gimbal rings to clear the roster envelope and keeps the lattice's inner face outside it. The kept clips do not change |
| Kest's perch (`ROSTER-LOOK.md` section 0.2, drawn in the cockpit cutaway of `artifacts/local/alpha/push/w13/concepts/codex/kest/sheet.png`) changes her rest pose, so all 18 of her clips change | PE-KEST waits for Andrew's pick on the concept board; with a perch it rebuilds the seven too and records a dated waiver of check 16 |
| The idle loop reads as fidgeting at the card's close-up | the blind read and Andrew's first card focus; the amplitude cap can drop to 4 degrees |
| `drop_land` stops showing because the smash always plays first | the run-log `pilot_clips` row: `drop_land` plays on most hit slams through the queue |
| The pose table drifts from the bytes | check 2 compares lengths, check 14 compares contact frames, every build |
| Base scenes for Rivet, Sable and Kest go stale or missing in the main checkout's ignored folder | check 16 fails on a stale base; a missing base stops PE-RIVET, PE-SABLE or PE-KEST with BLOCKED, not a rebuild from guesses |
| The rescue cage plays `unlock` at scale 1.6 with the root moving (`rescue_site.gd:110-115`) | the unit renders one strip frame in the cage pose |
| A pose table under `src/` might not ship in the exported build (`export_presets.cfg` has an empty `include_filter` at `:9` and `:28`), so the mecha motion code would lose its contact frames | PE-INT reads one contact frame in the `sketch:export` build; if the table is absent, `mecha_motion.gd` falls back to 40 percent of the clip length and warns once |

## 11. Veto list

Calls made under the creative charge. Say "veto" on any line and it changes.

1. Eighteen clips per pilot: the plan's nine, SKILL-BAR's `ult_ready`, and a new `ult_ride_loop` that holds the big control through the flight.
2. Loops end in `_loop`, so Godot's import loops them by name; no one-shot starts or ends with `loop` or `cycle`.
3. One name per role in all six GLBs: `idle_loop`, `smash` and `unlock` replace the sheets' per-pilot ids.
4. The smash triggers on `slammed` for all six at priority 36. A hit queues `drop_land` after it; a miss cuts in with `wince`.
5. `ultimate_landed` moves from 65 to 69, and `ultimate_cancelled` gets a row at 72.
6. `ult_ready` drops from 45 to 28 and waits up to 1.0 s for a cast to finish.
7. During an ultimate's flight the base sits at priority 64: hits, harpoon smashes and class ups do not break the ride.
8. `unlock` plays only where the unlocked pilot is shown: the rescue cage for Rivet and Kest, and the first card focus for all six (each launch under `--profile=sitting`).
9. The weapon gets no pilot clip; the yoke trigger squeezes instead.
10. Code moves the whole mecha; shells carry no AnimationPlayer; clips animate pilot bones only.
11. Status clips ease in over 0.08 s; impact and commitment clips still cut in at once; every clip hands back over 0.1 s.
12. Idle amplitude caps: 6 degrees on spine and head, 0.02 m at the hands, 15 degrees on ears, tail, crest, jaw and curls.
13. Idle runs 12 beats (4.2 s) for five pilots and 8 beats (2.8 s) for the Cannon; the ride runs 4 beats (1.4 s).
14. No upper and lower body layering: the rig has no legs, so a clip may outlast the 0.25 s control lock, as the sheets ask.
15. Written pose stories are enough to author; image motion sheets are optional.
16. The pose tables live under `src/presentation/clips/`, one per pilot, read by Blender, the verifier and the mecha motion code.
17. Until P-D's controls exist, cast clips aim at today's grips and are re-targeted later.
18. A clip counts as a reskin when its mean bone-rotation distance to another pilot's same-role clip is under 5 degrees.
19. Separable extra, off: the idle plays at the band's tempo.
20. Reduced motion keeps every pilot clip and drops only the shared fold and full-span extras.
