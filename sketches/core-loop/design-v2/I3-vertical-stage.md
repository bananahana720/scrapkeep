# I3 — Spillway: the Cable Reach (stage 2 vertical exploration)

Replaces `map_sluice.gd` as stage 2's map. Same slot in `stage_defs.gd` (threat 1.25,
`beacon_seconds` 30, `beacon_radius` 30); Warden plating/HP and lesson stay open for
tuning, proposed lesson "grip" / hint "Catch a barge, don't fight the current."

## The shape

One gorge, not three separate maps. `sample(x, z)` stays a single heightmap (it can only
return one height per point), so "three layers" means three shelf-heights the fall line
passes through, plus a sky layer that is **prop geometry suspended over a void in the
heightmap**, never itself a height sample. That keeps the whole stage buildable with the
existing terrain API and `build_props()` pattern (`stage_map.gd`, `features.gd`).

- **Sky** (z −170 to −20): a cable line at y≈62 strung between two rim towers, over a
  canyon gap where the heightmap drops to a deep floor (~−5 m, the rapids you'll reach
  later, glimpsed far below). No walkable ground here — only the cable, hover barges,
  and the two towers.
- **Ground** (z −20 to 70): true heightmap shelves at y≈22, canyon-floor aprons and
  chute ramps — the existing Spillway shelf/chute vocabulary (`_shelf`, `_chute` in
  `map_spillway.gd`), narrower (110 m wide) to keep the gorge read as a gorge.
  - Ground floor y≈22, apron width ±55 m, in x −65 to 65
- **Undercroft** (z 60 to 170): a sunken rapids canal at y≈−8, built with `halfpipe()`
  the way the existing chutes are, roofed by prop tunnel segments where it reads as
  underground and open where it reads as a canal. Beacon sits at its foot.

## Top-down (metres, x horizontal, z vertical on the page — fall direction is +z)

```
x: -120                    0                    120
z
-170  ┌───────────TOWER-A──cable──TOWER-B───────────┐   sky deck (spawn)
      │        ░barge1  ░barge2  ░barge3            │   y≈62, void below
-120  │   ·spur (secret 2, unlit)                    │
-70   └──────────────────void (gorge, y≈-5 far down)─┘
      ............ drop / geyser corridor ............
-20   ┌────────────────ground shelf───────────────────┐  y≈22
      │  fabricator      ▓apron▓        fabricator     │
  10  │        pump-house      kerb-chute (west)        │
  30  │   grapple posts (engineer line, x -70..-40)      │
  50  │        vault-plinth (off-line, +45,+40)          │
  70  └─────────skylight grate (secret 1)───────────────┘  drop to undercroft
      ............ rapids canal, roofed in spans ..........
 100  ┌───tunnel───  klaxon lamp  ───tunnel (open skylight mid-span)─┐  y≈-8
 130  │  wildcat-barge geyser (secret 4)   waterfall ledge (secret 3)│
 150  │              BEACON BOWL (28 m flat floor)                   │
 165  │         sunken bell, deep pool (secret 5)                    │
      └───────────────────────────────────────────────────────────────┘
```

## Side section (elevation, along the fall line)

```
y
 65 ─ TOWER-A══cable, barges══TOWER-B          (sky: props over void)
      \                              \
 30 ─  \  grapple line down            \  glide drop
        \                               \
 22 ───── ground shelf ───chute───ground shelf ─────skylight grate
                                                \       │(smash-through, secret 1)
  0 ── rim ───────────────────────────────────── \ ─────┘
                                                   \
 -8 ────────────── rapids canal (halfpipe) ─────────●── geyser vent up to sky (wildcat)
                    roofed╱open╱roofed              beacon bowl at z≈150
-15 ─ deep pool (secret 5) ──────────────────────────────────────────
```

## Speed-preserving transitions (no stops)

Every hand-off reuses a mechanic that already keeps momentum instead of a scripted cutscene drop:

1. **Sky → ground (grapple line).** Engineer-readable cable spans strung from each tower
   down to the ground shelf (`grapple_post` markers, same amber cap/copper mast as
   today). Grappling one and releasing near the bottom hands off at rope speed, same
   rule as the existing winch (`reel_force`/`reel_speed`).
2. **Sky → ground (glide drop).** Any class can walk off the sky deck's edge; the fall
   is long enough (~40 m) that a glide (caster, or a picked-up item) turns it into a
   controlled descent rather than a stomp. Falling without glide still lands on the
   ground shelf's mesa cushion — no fail state, per "nothing may stop the ball
   unforeseen."
3. **Ground → undercroft (skylight/halfpipe entry).** The rapids canal's head is a
   `halfpipe()` drop-in with `fade_out`, identical technique to the existing chute
   mouths — you roll in at speed and the canal keeps you moving, no lip to catch on.
4. **Undercroft → sky (geyser vent).** A vertical launch reusing `launch.gd`'s rail
   math locally (fixed short arc instead of a full stage-to-stage cannon): horizontal
   speed kept exactly, floor-raised if slow, with a lift impulse. This is the one
   *upward* hop, so every layer is reachable from every other without backtracking
   through a menu or a stage reload.
5. **Ground ↔ ground (chutes).** Unchanged from Spillway: west/east kerb-flanked
   chutes, `_chute()` shape, still the fastest lane across the shelf.

No transition uses a loading trigger, an invisible wall, or a "hold to descend"
prompt — every one is something you roll, jump, grapple or glide into at your own
speed, so principle 1 (momentum is sacred) holds across all three layers.

## Landmarks and sightlines

- **The dam silhouette** looms over the whole gorge from any layer — the one shape
  that tells you "downhill" without a HUD arrow.
- **Twin cable towers** anchor the sky layer; their copper-and-amber grapple caps are
  visible from ground and undercroft through the skylights, so a glance up always
  answers "where's the cable."
- **Pump-house glow** (existing amber-lit windows) marks the ground layer's midpoint.
- **Klaxon lamp** at the rapids mouth (reusing `flood.gd`'s mast/lamp, already built)
  announces the undercroft's event window the same way the Spillway basin does today.
- Every layer keeps a sightline down toward the beacon bowl once you're past its own
  rim, so getting lost means looking down, not consulting a map.

## Beacon, gates, fabricators, vaults, secrets, events

- **Beacon/Warden**: undercroft floor, z≈150, the existing 28 m flat-floor bowl
  (`beacon_bowl`). Approach is always a descent (rapids canal), matching the "missed
  ram rolls back" rule.
- **Reward gates**: stand downhill of the ball at the foot of each transition (sky→
  ground landing zone, ground→undercroft skylight, and the beacon approach), following
  DESIGN-NOTES #35/#39's climb-and-clearance rule — flagged as a risk below since this
  map stresses that algorithm harder than a single-plane shelf.
- **Fabricators**: on the ground-layer apron, drive-through, off the fast chute lane
  but on the 25 m SHOULD-content band around the fall line.
- **Vaults**: one per layer — sky spur (grapple-only, secret 2), ground plinth (off-
  line, 40+ m, ≤1.5 m climb back per the existing vault rule), undercroft alcove behind
  the waterfall ledge.
- **Events**: `flood`→rapids current (undercroft, reuses `flood.gd`'s drag/current/lift
  wholesale), `dust_squall`→sky layer crosswind that nudges barge timing, `surge_run`→
  a hauler barge on the cable that you chase and ram (reuses `route.gd`).

## Best route per character

- **Engineer** (grapple, vault kick, pylon mount): skips the sky deck's marked barges
  entirely — grapples tower to tower, pylon-mounts on a tower face for the turret
  angle down into the ground shelf, then vault-kicks off the mount (~1.8× incoming
  speed) straight into the ground layer's fast chute. Fastest sky-to-beacon line.
- **Caster** (glide, rocket jump off own blast): drops from the sky deck through the
  ground layer's skylight grate directly into the undercroft (smashing the grate at
  cruise speed, secret 1), then rocket-jumps off her own blast from the rapids floor
  back up through the geyser corridor when she needs to reset — she never really
  "climbs," she detonates upward. Scrap dust cloak reads naturally in the roofed
  tunnel spans.
- **Runner** (overdrive sprint, CC immune): ignores the cable and the geyser — sprints
  the ground shelf's full apron at cruise-or-better, unstoppable through the rapids
  current where anyone else gets dragged, and takes the chute-to-chute lane the whole
  way down. The one class for whom the undercroft's current is a non-issue rather than
  a hazard, which is the joke of her kit.

## What the player searches for

- **Edge markers**: amber-capped grapple posts wherever a cable or ledge is meant to be
  grabbed — same visual language as today's grapple posts, so nothing new to learn.
- **Sound beacons**: the sunken bell (secret 5) pings audibly before it's in view, and
  the klaxon lamp's pre-flood announcement (5 s lead, unchanged from `flood.gd`) is the
  undercroft's "something's about to move" cue.
- **Tint changes**: skylight grates and geyser vents get the same concrete/verdigris
  tint break used for pylon-bitable faces, so a smashable or launchable surface reads
  differently from plain sand/rock at a glance.

## Moving-platform physics (Godot 4.7, rigid ball)

The ball is a torque-driven `RigidBody3D` (`tuning.gd`'s `rigid_torque`), not a
`CharacterBody3D`, so barges must carry it through friction contact, not a manual
velocity add:

- Barges are `AnimatableBody3D` with `sync_to_physics = true`. That flag is what makes
  Godot report the platform's implied linear/angular velocity to Jolt each physics
  tick, so a resting body gets correct friction coupling instead of the platform
  teleporting through it.
- Move barges by setting `global_position`/`global_transform` inside
  `_physics_process`, at the 90 Hz physics tick — never in `_process` — and by a
  bounded per-frame delta so `sync_to_physics` computes a sane velocity rather than a
  spike (this is the standard cause of the jitter R4 flags: a platform moved in
  `_process` and read back by physics one tick late).
- Widen barge collision shapes ~10–15% past the ball's radius (R4 rule 9) and use one
  continuous box shape per barge deck, not a seam of planks — a seam is where contact
  normals flip every frame and jitter shows up as a stutter, not just a visual pop.
- Barge tilt (R4 idea 4's "settle under weight") is scripted, not simulated: a small
  deterministic tilt as a function of the ball's local position on the deck, so a
  headless test can assert the exact tilt for a given ball position instead of chasing
  a physics-engine center-of-mass calc.
- The geyser vent reuses `launch.gd`'s pure `launch_velocity`/`arc_point` functions
  directly (already tested, already deterministic) rather than inventing a second
  impulse formula.

## Performance budget

- Heightmap trimesh: unchanged size and rebuild cost (~34 ms swap, per DESIGN-NOTES
  #26) — layering happens in props and z-bands, not a bigger or second grid.
- Target ≤40 collidable static/animatable bodies for the whole stage (2 towers, ~5
  barges, ~6 tunnel-roof segments, chute kerbs, plinths, pump-house) — comparable to
  Spillway's existing prop count, not a multiple of it.
- Shared materials (`Palette` solids/striped) across barges and towers to keep draw
  calls near Spillway's current handful, no per-barge unique material.
- Animating barges cost is O(barge count) transform updates per physics tick, not per
  render frame — cheap at 90 Hz for ~5 bodies.

## Risks

- The heightmap is single-valued per (x, z); "underground" only reads as underground
  because of roof props, not real occlusion — a camera angle from directly above could
  break the illusion and needs an art/camera check, not just terrain.
- Moving-platform friction coupling on a `RigidBody3D` ball is less forgiving than on a
  `CharacterBody3D`; if the ball still slides on barges after the `sync_to_physics` fix,
  the fallback is a small local friction bump on barge material, not a bespoke velocity
  hack.
- The gate-placement sweep (DESIGN-NOTES #39, `_candidate`'s sphere sweep) was proven
  against single-plane shelf maps; towers, barges and tunnel roofs are new obstacle
  classes on the ball's approach line and need their own sweep coverage before this
  ships, not just a shelf-height check.
- An upward-only geyser and multiple drop points create real backtrack loops (by
  design, for secrets), which is new for this game's maps — needs a check that no loop
  can trap a ball below cruise speed with no way out (see test 2 below).

## Five headless tests

1. **`vertical_layer_reach_test`** — script a bot for each of the three classes along
   its named best route; assert every bot's position visits the sky-deck, ground-shelf
   and undercroft-canal bounding boxes at least once in one run.
2. **`no_momentum_trap_test`** — sample many seeded trajectories through every
   transition (grapple hand-off, glide drop, skylight entry, geyser exit) and assert
   horizontal speed never falls below a floor without player input at any sampled
   point — the vertical-map version of the existing seam-check tests.
3. **`barge_carry_keeps_ball_on_test`** — hold a ball on a moving barge for its full
   traverse across its tilt range; assert world-space lateral drift matches barge
   displacement within tolerance, so nobody rides a barge and gets left behind.
4. **`gate_clears_vertical_props_test`** — extend the existing gate-approach sphere
   sweep (`build_gate_props_test`) to this map, including towers, barges and tunnel
   roofs as obstacles, and assert no chosen gate candidate is blocked.
5. **`stage2_swap_and_frame_budget_test`** — measure stage build/swap time and
   steady-state physics-tick cost with all barges animating; assert the swap stays near
   the existing ~34 ms and per-tick cost stays within stage 1/3's current budget.
