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
| Space | jump; again in the air for the double jump |
| Shift | boost along your current direction (1.1 s cooldown) |
| Ctrl | brake: heavy resistance and tighter turning |
| Tab | switch physics mode (kinematic <-> rigid), keeping position and velocity |
| F1 | tuning panel (frees the mouse while open) |
| R | respawn at the top of the downhill run |
| Esc | free the mouse; press again to quit |

The readout top-left shows the mode, speed in m/s and km/h, the speed tier
(walk / cruise / fast / blazing), whether you are grounded, and whether the air jump is
available.

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
  your air jump back; hit one from the side above the fast tier to knock it away.

## Tuning panel (F1)

Live sliders for drive accel, cruise speed, air control, gravity, jump speed, restitution,
rolling resistance and rigid-mode torque, plus a reset button. Values apply immediately to
both modes.

## Checks

```bash
GODOT=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path sketches/ball-lab --import
$GODOT --headless --path sketches/ball-lab --quit-after 300
$GODOT --headless --path sketches/ball-lab --script res://tests/slope_test.gd
$GODOT --headless --path sketches/ball-lab --script res://tests/mode_check.gd
```

`slope_test.gd` drops the ball at the top of the downhill run in each mode with no input
and asserts it gains speed, ends lower, and is still on the surface rather than falling
through it. `mode_check.gd` covers driving, the Tab toggle carrying position and velocity,
the descending rebound restoring the air jump, and enemy knockback. Both exit non-zero on
failure.

`tools/shot.gd` is the visual spot check: it opens a window, renders the spawn view and
saves a PNG (pass a path after `--`, otherwise it lands in `user://`). It is how the
terrain was confirmed to be visible and right way up, since a trimesh with inverted
winding is invisible from above and has no collision either.

```bash
$GODOT --path sketches/ball-lab --script res://tools/shot.gd -- /tmp/spawn.png
```

These prove the systems run and the slope physics does what it claims. They say nothing
about how any of it feels.
