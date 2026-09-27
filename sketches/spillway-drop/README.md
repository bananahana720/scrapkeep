# spillway drop

A throwaway Godot 4.7.2 greybox stage for one question: **does verticality with a
guaranteed slow ground route create real route choice?** Every high place here can be
reached the slow way and left the fast way, and the stage loop (scrap, caches, a
director, an exit charge) exists only to give you a reason to keep choosing.

The ball is the accepted one from [ball lab](../ball-lab/README.md): the same rule set,
camera and tuning, starting in **rigid** mode at the defaults Andrew chose. Nothing here
retunes it. No add-ons, no imported assets; the terrain, props, pickups and enemies are
all built in script from primitives and one procedural height field.

## Launch it

```bash
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path sketches/spillway-drop
```

The mouse is captured on start. Esc frees it, Esc again quits.

## Controls

| Key | Action |
| --- | --- |
| W A S D | drive, relative to where the camera is looking |
| mouse | look |
| Space | jump; again in the air for the double jump |
| Shift | boost along your current direction |
| Ctrl | brake: heavy resistance and tighter turning |
| E | open the cache / start the exit charge you are standing at |
| Tab | switch physics mode (rigid <-> kinematic), keeping position and velocity |
| R | restart the run |
| Esc | free the mouse; press again to quit |

## The stage

400 x 400 m, bounded by terrain rather than fences: a tall canyon wall down the whole
west side and a rising rim on the other three. Three river shelves step down from the
north.

- **Top shelf, 30 m.** You spawn at the mouth of the west sluice, aimed down it. The
  **pump house** is the north-east building; the exit terminal stands in front of it.
- **Mid shelf, 15 m.** Two concrete benches carry scrap lines and make usable lips.
- **Lower basin, 0 m.** A shallow bowl in the south. The **maintenance hatch** sits at the
  bottom of it, and a klaxon mast stands beside it.

**Four sluice chutes** cut the shelf faces: two from the top shelf to the mid (at x -62
and x 54) and two from the mid to the basin (at x -18 and x 96). Each is a 28 m wide
U-section concrete channel at a steady 15.5 degrees, walled by a rust kerb at its mouth.
These are the fast lanes: from a standing start with no input the ball leaves a chute
doing about 16.5 m/s after three seconds.

**The bypass ramp** runs the full east edge at x 140. It is flat where it crosses each
shelf and climbs at 12 degrees across each riser, so it is rollable in both directions
at any speed. Foot to top shelf is about 190 m, roughly 18 seconds of holding W. It is
the guaranteed slow route, and every high place drains into a chute or onto it.

**The flood** runs on a 90 second clock: 57 s dry, a 5 s klaxon warning, 6 s of rising
water, 14 s flooded, 8 s draining. In the water you take heavy drag and a current toward
the middle of the basin. After the first flood drains it leaves the maintenance hatch
open, and the hatch is the secret cache.

## The loop

- **Scrap.** 95 pickups along the momentum lines: chute floors, ramp deck, bench edges,
  basin. They are magnetically pulled in from 6 m, so a fast clean line collects more
  than a careful one. Enemies drop more.
- **Caches.** Five out in the open plus the hatch secret. Roll up and press E to open one
  for a scrap cost (25 rising to 73, the secret 20). Each grants one random buff that
  stacks on the HUD: +10% cruise, +1 m/s jump, -15% boost cooldown, +25% impact damage,
  +20 max HP. Scrap becomes build.
- **Director.** The difficulty tier rises every 45 seconds and drives the spawn rate,
  enemy health and the live cap. It spawns off-screen within 34-56 m of you. **Chasers**
  are the ball-lab dummy with health; **lobbers** never move and fire slow, telegraphed
  arcs, so standing still is expensive.
- **Combat is momentum only.** You damage an enemy by landing on it from above (the
  ball-lab rebound, which also gives your air jump back) or by ramming it above the fast
  tier, scaled by speed. You have 100 HP with slow regen five seconds after the last hit.
- **Exit.** Press E at the pump house to start a 60 second charge; you have to stay
  within 30 m of it. The director spikes for the whole charge and one miniboss spawns.
  When it finishes, roll through the gate ring for the clear screen.

The HUD carries HP, scrap, stage time, tier, live enemies, exit charge, the buffs you
hold, the current interaction prompt, the flood alert, and speed with its tier.

## What to try first

1. **Take your hands off the keys for the first three seconds.** The spawn is aimed down
   the west sluice; let it do the work and feel where the ball is by the time the mid
   shelf arrives.
2. **Take a chute to the basin, then look back up.** The question is whether the way back
   is obvious and whether you resent it. The bypass is 190 m of holding W.
3. **Then try to get back up a chute instead** — boost in at the bottom, pump the U. If
   that works, the bypass is the floor and not the route, which is the answer.
4. **Get caught in the basin by the klaxon.** Five seconds of warning, and the water
   makes the basin slow. Decide whether the flood reads as a threat or an annoyance.
5. **Wait for it to drain and open the hatch.** The secret is the cheapest cache.
6. **Start the exit charge early, with few buffs.** The spike plus a miniboss for 60
   seconds is the stage's only real pressure test.

Note what you would change about the shelf heights and the chute pitch, not about the
ball. The ball is settled.

## Checks

```bash
GODOT=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path sketches/spillway-drop --import
$GODOT --headless --path sketches/spillway-drop --quit-after 300
for t in bypass chute director exit flood scrap; do
  $GODOT --headless --path sketches/spillway-drop --script res://tests/${t}_test.gd
done
```

Each test prints PASS/FAIL lines and exits non-zero on failure.

- `chute_test` drops the ball into each of the four chutes with no input and asserts it
  passes 10 m/s within three seconds while staying within 6 m of the surface. Without the
  clearance assertion a ball that tunnelled through the floor would pass by free-falling.
- `bypass_test` puts the ball at the ramp foot in rigid mode, holds forward, and asserts
  it reaches the top shelf. This is the one that proves the slow route exists. It also
  asserts its first read is at the foot: the spawn sits above the target, so a read taken
  before the rigid reset lands would otherwise pass without climbing.
- `director_test` steps 60 simulated seconds of scheduling in a loop and asserts enemies
  spawn, the tier rises and the live cap holds.
- `scrap_test` asserts the placed count is in range and that rolling through a pickup
  increments the run's scrap.
- `exit_test` asserts E starts the charge, that time out of the zone banks nothing, and
  that holding the zone completes it.
- `flood_test` steps a whole 90 second cycle and asserts every phase is reached, the
  water rises and drains, the hatch is uncovered, and a submerged ball is dragged.

The chute, bypass, scrap and exit tests run from `_physics_process` and count physics
ticks. A rigid reset lands on the next tick, and an idle frame can arrive before it does.

`tools/` is windowed-only and is never run by `npm run sketch:smoke`.

```bash
$GODOT --path sketches/spillway-drop --script res://tools/shot.gd -- /tmp/spawn.png
$GODOT --path sketches/spillway-drop --script res://tools/shot.gd -- /tmp/map.png overview
$GODOT --headless --path sketches/spillway-drop --script res://tools/geometry.gd
```

`shot.gd` renders the spawn view, or the whole stage from above with `overview`; it is
how the terrain was confirmed visible and right way up, since a trimesh with inverted
winding is invisible from above and has no collision either. `geometry.gd` prints the
shelf heights, chute pitches and the steepest sample on the bypass straight out of the
height field.

These prove the systems run and the stage's grades are what they claim. They say nothing
about whether any of it is worth playing.
