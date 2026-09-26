# cable bench

A throwaway Godot 4.7.2 greybox stage for one question: **does a rising difficulty
clock make "one more cache" a real decision, or do you just take everything?**

It is a Risk of Rain 2-shaped loop wrapped around the ball-lab scrap ball. The
movement, camera, tuning and enemy scripts are copied from `sketches/ball-lab`
unchanged, and the ball starts in **rigid** mode at the accepted defaults (drive 34,
cruise 14, gravity 26, jump 13, rigid torque 220, physics at 90 Hz). Nothing here
retunes the feel. Everything else — terrain, scrap, caches, buffs, director, forge
— is new and disposable.

## Launch it

```bash
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path sketches/cable-bench
```

The mouse is captured on start. Esc frees it, Esc again quits.

## Controls

| Key | Action |
| --- | --- |
| W A S D | drive, relative to where the camera is looking |
| mouse | look |
| Space | jump; again in the air for the double jump |
| Shift | boost along your current direction |
| Ctrl | brake |
| **E** | open the cache you are sitting on, or start the forge charge |
| Tab | switch physics mode (rigid <-> kinematic) |
| R | restart the stage |
| Esc | free the mouse; press again to quit |

## The stage in words

400 x 400 m of mountainside, bounded by rising terrain rather than fences, climbing
about 62 m from the south plain to the forging apron in the north. There are no
seams: one continuous height field carries every bench, road, trough and mesa.

- **Five benches, five switchbacks.** Each bench is a flat shelf separated from the
  next by a rock face too steep to climb. Exactly one road corridor cuts each face,
  and the corridors alternate sides — west at x=-130, then east at x=+130, and so
  on, with the last one dead centre. So the route up is: cross the bench, turn, climb,
  cross the next bench the other way. Each crossing is about 260 m of straight.
- **Rail sidings.** A shallow trough with verdigris rails runs the full width of every
  bench. It is the fast line: it funnels you, and it is where the scrap is.
- **Three high benches** ("east ledge" on bench 1, "drill shelf" on bench 2, "tank
  roost" on bench 3) sit right on the siding line, 7 m above it, walled on every side
  but one. A long rust-striped kicker ramp in the trough is the only way up at speed;
  the gentle chute off the far side is the way down. Each holds a cache.
- **Four overhead cableways** sweep loads across the benches at 26-34 m/s. The dark
  disc and the arc-green lamp on the ground show where the load will be in two
  seconds. It knocks back players and foes alike and takes 12 HP off you.
- **The secret.** A horseshoe of wrecked plate on the far west of bench 2, around
  (-150, 30). There is one gap in it. The cache inside is the cheapest reach on the
  mountain if you find it early.
- **The forge apron** at the top holds the exit rig, a copper hood on four legs with
  a 30 m verdigris ring painted on the ground.

## The loop

- **Scrap** (84 pieces) lies along the sidings, the roads and the high benches. A 6 m
  magnet pulls it in, so a fast clean pass sweeps a line. Foes drop more.
- **Eight caches.** Roll into one and press E. The cost is `25 * tier^1.25`: 25 scrap
  at tier 1, 99 at tier 3, 187 at tier 5. Each gives a random stacking buff —
  +10% cruise, +1 m/s jump, -15% boost cooldown, +25% impact damage, +20 max HP.
- **The director** raises the difficulty tier every 45 s and spawns off-screen, 42-74 m
  from you, faster and tougher each tier. Chasers run you down; lobbers stand still and
  lob telegraphed arcs at where you are, to punish fighting on the spot.
- **Combat is momentum only.** Land on a foe from above for a stomp (26 damage, and you
  get your air jump back), or ram one above the fast tier for speed x 1.7 damage. You
  have 100 HP, regenerating slowly five seconds after you were last hit.
- **The exit.** Press E at the rig to start a 60 s charge. You must stay inside the
  ring; leaving stalls the charge but never the tier clock. The charge spikes the
  director and drops one miniboss. When it fills, roll into the rig for **Stage clear**.
  At 0 HP you get **Scrapped**; R restarts.

## What to try first

1. From the spawn the camera is already aimed down the first line: west along the
   bench-0 siding toward the road at x=-130. Just drive it and take the first
   switchback without braking.
2. On bench 1, keep the trough and hit the **east ledge** kicker at full speed. It
   needs real speed: about 9 m/s stalls a metre up the ramp, 26 m/s clears the gap.
   Take the cache, then run off the chute on the far side instead of stopping.
3. Ignore the ground caches on the first run and see how high the tier is when you
   reach the apron. Then do it again and open everything. The run this sketch is
   asking about is the second one: at what tier does taking the next cache stop being
   worth the 45 seconds it costs you?
4. Let a cableway shadow catch you once, on purpose, so you know what it does.

## Checks

```bash
GODOT=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path sketches/cable-bench --import
$GODOT --headless --path sketches/cable-bench --quit-after 300
for t in descend kicker cableway director cache_cost exit_charge; do
  $GODOT --headless --path sketches/cable-bench --script res://tests/${t}_test.gd
done
```

Or `npm run sketch:smoke` from the repo root, which runs all of it.

| test | what it proves |
| --- | --- |
| `descend_test` | dropped at the top of each of the five switchbacks, the ball descends and stays within 6 m of the surface — that is, the trimesh winding is right and it is not falling through |
| `kicker_test` | a 26 m/s launch off the east ledge kicker lands on the mesa, a 9 m/s launch does not, and both launches actually started on the run-up |
| `cableway_test` | the load advances along its path and knocks a body out of the way |
| `director_test` | at least one foe spawns in 60 simulated seconds, all on the map, and the tier clock ticks every 45 s |
| `cache_cost_test` | the cost curve rises with tier, and a live cache in the stage charges it |
| `exit_charge_test` | 1.5 s outside the ring adds no charge; holding the ball inside completes the charge and the exit takes it |

`tools/probe.gd` prints the stage geometry the tests assert against (headless).
`tools/shot.gd` is windowed only — it renders the spawn view to a PNG, which is how
the terrain was confirmed to be visible and right way up:

```bash
$GODOT --path sketches/cable-bench --script res://tools/shot.gd -- /tmp/spawn.png
```

These prove the systems run. They say nothing about whether the choice is interesting;
that is the part only playing it answers.

One inherited quirk worth knowing before you play: `chase_camera.gd` (copied from
ball-lab unchanged) sets `cam.position` every idle frame, which overwrites where
SpringArm3D put the camera during the physics step. Captured frames land on either
placement, so `tools/shot.gd` sometimes renders from 7 m behind the ball and
sometimes from right on top of it. It is ball-lab's camera, so it is not touched
here. If it shows up as jitter when you play, that is the cause.
