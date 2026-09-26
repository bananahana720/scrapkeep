# ball lab

A throwaway Godot 4.7.2 greybox for feeling a momentum-rolling scrap ball on slopes,
and for comparing two physics modes side by side. Nothing here is production code: the
movement and camera scripts are meant to be copied into the stage greyboxes once the
feel is settled. No add-ons, no imported assets, everything is built in script from
primitives and one procedural height field.

## Launch it

```bash
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path sketches/ball-lab
```

The mouse is captured on start. Esc frees it, Esc again quits.

## Controls

| Key | Action |
| --- | --- |
| W A S D | drive, relative to where the camera is looking |
| mouse | look |
| Space | jump; again in the air for the double jump; **hold while falling to glide** |
| Shift | boost along your current direction (1.1 s cooldown); **airborne it is the air dash** |
| Ctrl | brake: heavy resistance and tighter turning; **airborne it is the slam** |
| right mouse | **fire the grapple** at whatever the crosshair is on; release to let go |
| Q / mouse wheel | **reel the rope in** (wheel down pays it back out) |
| E | **mag-cling**: hold near a steep face to stick to it |
| 1 - 5 | toggle the five augments on and off |
| Tab | switch physics mode (kinematic <-> rigid), keeping position and velocity |
| F1 | tuning panel (frees the mouse while open) |
| R | respawn at the top of the downhill run |
| Esc | free the mouse; press again to quit |

The readout top-left shows the mode, speed in m/s and km/h, the speed tier
(walk / cruise / fast / blazing), whether you are grounded, and whether the air jump is
available. The list top-right shows the five augments, their number keys and which one
is firing right now.

## The augments

All five start on; 1 to 5 switch them off one at a time, and with all five off the ball
behaves exactly as it did before them. They are fitted to the **rigid** mode, which is
the one worth feeling here; kinematic mode ignores them.

1. **Grapple** — right mouse fires along the crosshair at any static surface within 45 m,
   and the crosshair turns orange when something is in range. The rope is a hard maximum
   length with a little spring, so it never pulls you in by itself: it takes away the
   part of your speed that pulls away from the anchor and leaves the rest, which turns a
   fall into a pendulum. Q or the wheel reels in. Letting go keeps every bit of the speed
   the swing gave you, so the release timing is the whole trick. Ten posts and two arches
   are scattered for this, including an arch over the halfpipe and one over the kicker
   that aims at the bench gap.
2. **Air dash** — Shift in the air is one flat burst along the camera's horizontal
   forward, refreshed when you land or rebound off a dummy. Shift is one charge: a ground
   boost and an air dash share the 1.1 s cooldown, so the key never pays out twice.
3. **Glide** — hold Space while falling once the double jump is spent. Gravity drops to
   30 percent and the fall is traded for forward speed, so a long drop becomes distance.
   Fins appear while it is working.
4. **Slam** — Ctrl in the air drives you straight down at 42 m/s. The landing sends out a
   shockwave that knocks back and flashes every dummy within 9 m, and a slam onto a slope
   converts the drop into speed along that slope, which is the fast way to enter the
   downhill run.
5. **Mag-cling** — hold E within 1.5 m of a face that leans less than 60 degrees off
   vertical. The magnet carries 82 percent of your weight, so you slide down slowly and
   can ride along a wall; jumping launches you off along the wall's normal. Two tall
   magnet walls stand east of the pad, 9.5 m apart, to bounce between.

Every augment knob (dash impulse, glide gravity and lift, rope range and spring, reel
speed, slam speed, cling strength) is a slider on the F1 panel.

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

Tab keeps position and velocity, so you can switch mid-run and feel the difference on the
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
- **Magnet walls**: two 34 m walls east of the pad with a 9.5 m corridor between them.

## Tuning panel (F1)

Live sliders for drive accel, cruise speed, air control, gravity, jump speed, restitution,
rolling resistance and rigid-mode torque, then the eight augment knobs: dash impulse,
glide gravity, glide lift, rope range, rope spring, reel speed, slam speed and cling
strength. Plus a reset button. Values apply immediately to both modes.

## Checks

```bash
GODOT=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path sketches/ball-lab --import
$GODOT --headless --path sketches/ball-lab --quit-after 300
$GODOT --headless --path sketches/ball-lab --script res://tests/slope_test.gd
$GODOT --headless --path sketches/ball-lab --script res://tests/mode_check.gd
$GODOT --headless --path sketches/ball-lab --script res://tests/augment_test.gd
```

`slope_test.gd` drops the ball at the top of the downhill run in each mode with no input
and asserts it gains speed, ends lower, and is still on the surface rather than falling
through it. `mode_check.gd` covers driving, the Tab toggle carrying position and velocity,
the descending rebound restoring the air jump, and enemy knockback. `augment_test.gd`
measures each augment against the same fall with it switched off: the rope holds its
length to 0.05 m over a three-second swing that peaks at 26 m/s, the dash adds its full
impulse sideways, gliding falls at 4.7 m/s against 30.7 free, the slam drives at 42 and
shoves a dummy 1.5 m further out, clinging falls at 4.4 m/s against 25.7 beside the same
wall, every anchor on the rig stops a ray, and holding every augment key with nothing
fitted falls at exactly the plain rate. All three exit non-zero on failure.

`tools/shot.gd` is the visual spot check: it opens a window, renders the spawn view and
saves a PNG (pass a path after `--`, otherwise it lands in `user://`). It is how the
terrain was confirmed to be visible and right way up, since a trimesh with inverted
winding is invisible from above and has no collision either.

```bash
$GODOT --path sketches/ball-lab --script res://tools/shot.gd -- /tmp/spawn.png
```

These prove the systems run and the slope physics does what it claims. They say nothing
about how any of it feels.

## What to try first

1. **R**, then ride the downhill run into the halfpipe as before, to confirm the base feel
   is untouched.
2. Halfway down the pipe, look up at the **arch over the halfpipe** and hold right mouse.
   Let the rope go taut, swing through the bottom, and release at the front of the swing:
   that is the fling, and it is the augment most likely to change how the whole field
   reads.
3. Off the top of the swing, hold **Space** and glide across to the pad, then **Shift** for
   one dash to stretch the line further.
4. From up there, **Ctrl** into the slope of the banked turn. A slam landing on a bank
   should spit you along it rather than stop you.
5. Slam into the middle of the dummies on the pad and watch the shockwave scatter them.
6. Drive east to the **two magnet walls**, jump at one and hold **E**. Ride down the face,
   jump off it into the other wall, and see whether crossing the corridor that way is fun
   or fiddly.
7. Then switch them off one at a time with **1** to **5** and ride the same line. The one
   you miss most is the answer.
