# mobility kit

A throwaway Godot 4.7.2 greybox for feeling a momentum-rolling scrap ball on slopes,
and for comparing two physics modes side by side. Nothing here is production code: the
movement and camera scripts are meant to be copied into the stage greyboxes once the
feel is settled. No add-ons, no imported assets, everything is built in script from
primitives and one procedural height field.

**v2** reworks the kit after Andrew's first play (playtest log entry 3): the slam plants,
the reel is a winch, the grapple shows whether it will connect, and a pylon mount replaces
mag-cling. Rigid mode is the one that matters; kinematic still runs but was not reworked.
Hold **Tab** in game for the field notes below.

## Changed in v2

- **Slam anchor.** One rule for every landing angle, driven by the contact normal. Flat
  ground plants the ball for up to 0.3 s with the full shockwave and zero exit speed; a
  steep slope barely plants and throws you downhill; anything between blends. Never a
  stun: a jump or boost pressed while planted fires the tick the plant releases.
- **Winch.** Holding Q hauls you toward the hook whether or not the rope is taut, and the
  rope follows you in. The wheel still pays out (down) and notches in (up).
- **Grapple reach indicator and magnetic assist.** One function decides what the grapple
  would hit; the reticle, the world marker and the fire action all read its result. If
  the centre ray misses, a 4 degree cone snaps onto the nearest hookable surface.
- **Pylon mount** (key E, augment 5) replaces mag-cling. The **LMB zap is a placeholder
  weapon**, there only so mount-to-fire can be felt.
- **Field notes and pause.** Hold Tab for the notes (the game pauses while held), P
  toggles pause. The physics-mode switch moved from Tab to **F2**.
- **Physics interpolation on F3**, off by default so v1's feel stays the baseline; the
  HUD shows its state. **F4** saves every tuning value, the physics mode and the
  interpolation state to `user://tuning-<unix time>.json` and prints the full path.
- **Split dash cooldown** toggle on the F1 panel, to compare against the shared 1.1 s.

## Launch it

```bash
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path sketches/mobility-kit
```

The mouse is captured on start. Esc frees it, Esc again quits.

## Controls

This table mirrors `CONTROLS` in `src/field_notes.gd`, which the Tab overlay and the HUD
hint line are built from.

| Key | Action |
| --- | --- |
| W A S D | drive, relative to where the camera looks |
| mouse | look (free while mounted) |
| Space | jump, double jump, hold falling to glide; jumps off a pylon |
| Shift | boost; airborne it is the air dash |
| Ctrl | brake; airborne it is the slam |
| right mouse | fire the grapple at the reticle's target; release to let go |
| Q (hold) | winch: haul toward the hook |
| mouse wheel | down pays rope out, up notches it in |
| E | plant a pylon on a steep face or a close wall hook; again to drop off |
| left mouse | while mounted: zap (placeholder weapon) |
| 1 - 5 | toggle the five augments |
| Tab (hold) | these field notes; the game pauses while held |
| P | pause / resume |
| F1 | tuning panel (frees the mouse) |
| F2 | switch physics mode (rigid <-> kinematic) |
| F3 | physics interpolation on/off (off by default) |
| F4 | save every tuning value to user://tuning-<time>.json |
| R | respawn at the top of the downhill run |
| Esc | free the mouse; again to quit |

The readout top-left shows the mode, whether physics interpolation is on, speed in m/s and km/h, the speed tier
(walk / cruise / fast / blazing), whether you are grounded, and whether the air jump is
available. The list top-right shows the five augments, their number keys and which one
is firing right now.

## The augments

All five start on; 1 to 5 switch them off one at a time, and with all five off the ball
behaves exactly as it did before them. They are fitted to the **rigid** mode, which is
the one worth feeling here; kinematic mode ignores them.

1. **Grapple**: right mouse fires at whatever the reticle is showing, on any static
   surface within 45 m of the ball. The reticle has three states, told apart by shape as
   well as colour: a grey **cross** (nothing to hook), an orange **ring** (the centre ray
   is on something in reach) and a cyan **diamond** with a line to the snapped point (the
   centre ray missed, and the electromagnetic hook found something inside a 4 degree
   cone). A matching marker sits on the target point in the world. The rope is a hard
   maximum length with a little spring; it takes away the part of your speed that pulls
   away from the anchor and leaves the rest, which turns a fall into a pendulum. Holding
   **Q** winches: an acceleration toward the hook (45 m/s², fading out as the haul nears
   16 m/s) that works slack or taut, with the rope shortening to follow you in. Letting
   go keeps every bit of the swing's speed. Ten posts and two arches are scattered for
   this.
2. **Air dash**: Shift in the air is one flat burst along the camera's horizontal
   forward, refreshed when you land, rebound off a dummy or mount a pylon. Shift is one
   charge: a ground boost and an air dash share the 1.1 s cooldown, so the key never pays
   out twice. **Split dash cooldown** on the F1 panel gives the dash its own 1.1 s timer.
3. **Glide**: hold Space while falling once the double jump is spent. Gravity drops to
   30 percent and the fall is traded for forward speed, so a long drop becomes distance.
   Fins appear while it is working.
4. **Slam**: Ctrl in the air drives you straight down at 42 m/s. The landing is one
   blended rule. With `n` the contact normal, flatness is `f = clamp(n.up, 0, 1)^k`
   (k = 4). The ball is pinned for `0.3 s * f` and the shockwave (9 m, knocks and flashes
   dummies) is scaled by `f`. On release the ball leaves with `(1 - f) * (t + d * s * c)`:
   `t` is the impact velocity's tangential part, `s` is the impact speed into the surface
   (which the plant stops), `d` is the downhill direction and `c` = 0.5 is the downhill
   conversion. Flat pad: a full plant and a dead stop. The 34 degree kicker: about half
   the plant, and about 18 m/s downhill. Jump or boost pressed while planted fire the
   moment it lets go.
5. **Pylon**: press E within 1.5 m of a face leaning less than 60 degrees off vertical,
   or within 6 m of a wall your grapple is hooked into. A scrap post is driven into the
   face and the ball is held on its end, 2.2 m out. Planting sends a repel pulse that
   shoves dummies within 8 m away. While mounted, look is free, the grapple still works,
   and **left mouse fires a placeholder hitscan zap** that knocks a dummy it hits. Space
   jumps off along the face's normal; E drops straight off. The two tall walls east of
   the pad and the seven pillars on the pad are the places to try it.

Every augment knob is a slider on the F1 panel.

## The two modes

**kinematic** is the spec'd model: velocity is integrated by hand each tick. Gravity is
projected onto the contact plane, so downhill genuinely accelerates you and uphill bleeds
you off. Drive input fades out as your speed along the input reaches cruise, so it never
caps the speed a slope or a boost gave you. Landings keep tangential speed and bounce
only the normal component.

**rigid** is a Jolt `RigidBody3D` sphere driven by rolling torque plus a smaller central
force, with friction and bounce from a `PhysicsMaterial`. Jump, boost and brake come from
the same rule set, applied as impulses. It carries rotational inertia, so it spins up
slower and loses more on the same hill (the headless test measures 21 m/s versus 32 m/s
after the same three-second roll).

F2 keeps position and velocity, so you can switch mid-run and feel the difference on the
same line.

## The field

250 x 250 m, one continuous height field with props on top.

- **Downhill run**: the long chute from the mountain in the north-west, descending 34 m
  into a **halfpipe** channel you can pump side to side.
- **Banked turn**: the ring east of centre, banked 16 m at its outer edge.
- **Launch ramps**: a shallow one on the pad and a steep one aimed at the bench.
- **Raised bench**: the blue plateau at 9.5 m. The steep ramp clears the gap at roughly
  fast-tier speed; the long service ramp on its east face is the slow way up.
- **Pillars**: seven to weave through on the flat pad.
- **Dummies**: six capsules that chase at 4 m/s. Land on one from above to rebound and get
  your air jump back; hit one from the side above the fast tier to knock it away, or slam
  next to a cluster to knock all of them back at once.
- **Grapple rig**: ten posts with a lit ring on top, plus an arch over the halfpipe and an
  arch over the kicker that aims at the bench gap. Anything static works as an anchor;
  the posts are just the ones placed where a swing pays.
- **Magnet walls**: two 34 m walls east of the pad with a 9.5 m corridor between them;
  now pylon faces.

## Tuning panel (F1)

Live sliders, in two columns, for drive accel, cruise speed, air control, gravity, jump
speed, restitution, rolling resistance and rigid-mode torque, then the augment knobs:
dash impulse, glide gravity and lift, rope range and spring, grapple assist (degrees),
winch pull, winch top speed, slam speed, slam anchor (max seconds), slam flatness
exponent, slam downhill conversion and the split dash cooldown toggle. Plus a reset
button. Values apply immediately. The panel saves nothing; press **F4** to write the
current values to a file.

## Checks

```bash
GODOT=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path sketches/mobility-kit --import
$GODOT --headless --path sketches/mobility-kit --quit-after 300
$GODOT --headless --path sketches/mobility-kit --script res://tests/slope_test.gd
$GODOT --headless --path sketches/mobility-kit --script res://tests/mode_check.gd
$GODOT --headless --path sketches/mobility-kit --script res://tests/augment_test.gd
$GODOT --headless --path sketches/mobility-kit --script res://tests/kit_v2_test.gd
```

`npm run sketch:smoke` from the repository root runs all of these for every sketch.

`slope_test.gd` drops the ball at the top of the downhill run in each mode with no input
and asserts it gains speed, ends lower, and is still on the surface rather than falling
through it. `mode_check.gd` covers driving, the Tab toggle carrying position and velocity,
the descending rebound restoring the air jump, and enemy knockback. `augment_test.gd`
measures each augment against the same fall with it switched off: the rope holds its
length to 0.05 m over a three-second swing that peaks at 26 m/s, the dash adds its full
impulse sideways, gliding falls at 4.7 m/s against 30.7 free, the slam drives at 42 and
its landing shockwave shoves a dummy about 2 m further out, every anchor on the rig stops
a ray, and holding every augment key with nothing fitted falls at the plain rate.
`kit_v2_test.gd` covers v2: a flat slam plants for about 0.3 s and leaves at 0 m/s while
a kicker slam plants about 0.14 s and leaves at about 18 m/s downhill; the winch hauls a
ball on a slack rope from 12 m to 8.5 m in a second; the reticle's reading is exactly
the point the fire action hooks, for a centre hit, an assist snap and a miss; a mounted
ball stays on its mount point for 2 s and Space throws it off the face; planting next
to a dummy pushes it away; pause freezes a falling ball; F3 interpolation starts off and
draws the ball between physics ticks when on; F4 writes every tuning value. Every script
exits non-zero on failure.

`tools/shot.gd` is the visual spot check: it opens a window, renders the spawn view and
saves a PNG (pass a path after `--`, otherwise it lands in `user://`). It is how the
terrain was confirmed to be visible and right way up, since a trimesh with inverted
winding is invisible from above and has no collision either.

```bash
$GODOT --path sketches/mobility-kit --script res://tools/shot.gd -- /tmp/spawn.png
```

These prove the systems run and the slope physics does what it claims. They say nothing
about how any of it feels.

## What to try first

These mirror `TESTING`, `QUESTIONS` and `TRY_FIRST` in `src/field_notes.gd`, which the
Tab overlay prints.

What this build is testing:

- Slam anchor: one rule for every landing angle. Flat ground plants you for up to 0.3 s
  with the biggest shockwave; a steep slope barely plants and throws you downhill.
- Winch: hold Q and the rope hauls you toward the hook, slack or taut.
- Grapple reach indicator with a 4 degree magnetic assist: the reticle's shape and colour
  say whether a shot connects before you fire.
- Pylon mount replaces mag-cling: E drives a post into a steep face and holds the ball on
  it. The LMB zap is a PLACEHOLDER weapon.
- Physics interpolation on F3 (off by default, so v1's feel is the baseline). F4 saves
  every tuning value to a file.

Questions to answer:

- Does the angle-blended slam read, with a plant on flat ground and a launch on hills?
- Does the winch haul feel intuitive?
- Can you tell before firing whether the grapple will connect?
- Is mount-to-fire fun, and is it a breather when surrounded?
- Does air dash feel starved sharing one 1.1 s cooldown with boost? (F1: Split dash
  cooldown.)
- F3: does interpolation make the ball and grapple aim steadier?

Try, in order:

1. Jump on the pad and Ctrl-slam flat ground: you should stop dead for a beat. Hold Space
   as you land; the jump fires the moment the plant lets go.
2. Slam onto the orange kicker, then onto the banked turn's outer wall: less plant, more
   launch.
3. Sweep the crosshair past a post top: cross (nothing), ring (in reach), diamond (the
   magnet snapped on).
4. Hook a post from the ground, let the rope go slack, then hold Q to be winched up.
5. Drive into the dummies on the pad, hop next to a pillar and press E: the pylon shoves
   them back. LMB to zap, Space to jump off.
6. Grapple a magnet wall, swing in close and press E to mount where the hook bit.
7. F1, flip Split dash cooldown, and chain boost into air dash to compare.
8. Ride the downhill run with F3 off, then on: watch the ball and the reticle for judder.
   F4 when a setup feels right.
