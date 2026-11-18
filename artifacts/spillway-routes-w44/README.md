# Four Spillway route studies

The dam's worn haul road now turns west below the Eye. At the flume, clearing one cottonwood opens the sightline across the kicker and into the wasteway. A worn shoulder leads away from the hollow timber toward its half-pipe. In Brindle's bowl, the rider arrives looking 12.6° inside the tangent, with the weathered steel mast opposite the copper ramp.

## Dam

The missing cue was the west turn on the descent. Both pilots enter the Eye from XZ (−8, 130) at 19.0 horizontal m/s. The west pilot reaches the working bench, skirts the west lane fin and approaches the beacon from the west. The incline pilot passes through the central yard and approaches from the east. At mass 1, the two lines reach the beacon in 28.9 and 22.6 s at 23.3 and 14.5 m/s. At mass 300, the trips take 28.8 and 21.8 s at 23.2 and 18.0 m/s. The slowest of these four runs stays above 9.8 horizontal m/s.

The open-cell test checks the map's 85% landmark sight requirement. Rider sight comes from the chase-camera frustum and a ray to the actual landmark. The face itself is visible for 12.2 s on the west run and 13.6 s on the incline. On the two live approaches, crossing the yard near (−130, 425) and (−9, 422) shuts the ring and admits three crew members. The live pilots continue applying movement into the closed ring.

[Route plan](dam-plan.jpg) · [Both approaches and exits](dam-routes.jpg) · [Live yard](dam-yard.jpg)

## Flume

A cottonwood at XZ (23.36, 241.48) put its trunk and crown between the ball and the receiving lane. The comparison shows the rolling view 1.50 s into the same kicker approach. The camera positions differ by 0.19 m. Other bank trees remain in place.

The upper route starts on the actual siphon deck at (14, 212), Y33.5. Maintaining the line carries the rider over the wasteway on the head reach at Y25. A jump out over the right wall from that same start lands in the wasteway, where the rider can steer toward the drum. From ground level at (14, 220), the kicker, low turn and deliberately wide take all join the lower route. The ground kicker returns the rider to the wasteway. The drum and upper deck share a bearing from below.

All five quiet takes start at 19.0 horizontal m/s. The upper carry reaches the forecourt in 20.0 s. The independent mass-300 runs also reach every waypoint. The live low approach shuts the yard after 7.7 s at (84, 331), where three crew members enter. The trace records the preceding open yard and the actual closed-yard fight.

[Matched before and after](flume-comparison.jpg) · [Measured takes](flume-plan.jpg) · [Chase strips](flume-routes.jpg) · [Live wave](flume-wave.jpg)

## Hollow trestles

The timber and the worn return share the view as the rider rolls down from the shoulder. Each trial uses the same approach. The driver presses RMB at tick 35. Its trace records held inputs, the Ctrl winch, rope release, steering and body movement. On the rendered starter run the working face is (−168.18, 39.84, −128.09). The held line peaks at Y39.87 in the contact window, 5.12 m above the roll and missed catch. Its first ground contact after release is (−164.21, 29.36, −119.29) at 3.44 horizontal m/s. Early release keeps 12.74 m/s at recontact. Late release approaches within 1.8 m of the underside. The higher line costs horizontal speed, and the roll and missed catch keep their speed into the trough. The chase trial records the positions of three live chasers, one behind the rider and two beside the receiving slope.

[Measured paths](hook-plan.jpg) · [Approach and crew](grapple-approach.jpg) · [Bite, release and recontact](grapple-chase.jpg) · [Side clearance](grapple-side.jpg)

## Brindle's bowl

The scripted handover passes 20 m/s in XZ and −2 m/s vertically into the normal boss entrance. The entrance turns that momentum onto its 115° tangent. In the first steerable view the next mast is at 315°, the inward ramp is at 0°, and the vent and bank continue toward 300°. A separate continuous drive around the eastern bank climbs the real ramp to local (33.81, 4.00, 0.47). The mast trial catches its physical face. The reverse trial shows the opposite mast and ramp from the same entry.

In the live Furnace phase, the moving bank trial stays outside the lit slag band. The deliberately exposed control records 36 damage from Brindle's slag after the warning goes live. The charge commits its lane and crosses the bank while the moving rider clears it. The damage ledger distinguishes the boss's hit from a lobber hit and subsequent healing.

[Actual bowl paths](bowl-plan.jpg) · [Entry and utility](bowl-approach.jpg) · [Slag and charge](bowl-fight.jpg)

## Read and repeat the measurements

These are instrumented Godot 4.7.2 source runs at 90 physics ticks per second. A placed start supplies the entry position and velocity. The pilot then submits normal movement, camera, RMB, Ctrl and jump input. Tripo models, the High preset and a 1280 × 720 viewport supply the frames. Human steering feel and a packed Linux run require separate evidence.

[Measurements for all trials](measurements.json) give the entry and exit speeds, hook flight and damage. The compressed JSON files hold the input and physics samples, world-space targets, yard state and damage events. XYZ positions are in metres. Velocity is a three-component vector. Plan labels use horizontal speed. Counts of clear camera samples refer to particular points on the surface. Clearance rays report metres from the ball skin to the real timber along the face bearing, or vertically to the underside.

For a local repeat, set GODOT_BIN to the 4.7.2 executable and ROUTE_HOME and ROUTE_OUT to fresh absolute scratch directories inside the worktree. Select dam, flume, hook or bowl. Use a separate output directory for each run. Add --grown for mass 300 and --live for a stage's ordinary yard and director.

```sh
mkdir -p "$ROUTE_HOME" "$ROUTE_OUT"
HOME="$ROUTE_HOME" "$GODOT_BIN" --audio-driver Dummy --fixed-fps 90 --resolution 1280x720 --disable-vsync \
  --path sketches/core-loop --script res://tools/spillway_route_capture.gd -- \
  --table=park --models=tripo --ball-look=cutaway --section=flume --out="$ROUTE_OUT"
```
