# Crew lamps and clips on the PC (jobs AE and AF)

## Lamp eyes (job AE)

- PR 966, branch claude/project-thread-ihg103, head ecf6e04e.
- Files are in lamps-ecf6e04e/. There are 12 kinds, each with a rest still and a still 75% into the wind-up, 1920x1080. The camera sits at chase height, 3.5 m above the ground and 12 m out.
- The hooker also has two close shots from 3 m. lamps.json records the lamp's energy (emission): 0.25 at rest and 2.36 in the wind-up, for every kind.
- The tool is the scratch-only scratch-tool/lamp_capture.gd, which is not for a game branch. tools/enemy_capture.gd has no wind-up pose and no game camera.
  - It poses each crew with the crew's own phase, _t and _pose(), and the lamp's watch(), with the tree paused.
  - The ball stands under the camera, so each crew turns its head toward the lens.
- Third take. In the first two, the crews faced away from the camera or the ball sat in the frame.

## Clips (job AF)

- PR 968, branch claude/project-thread-ihg103-clips, head fcff6d9f.
- Files are in clips-fcff6d9f/, made by tools/enemy_clip_capture.gd --kinds=netcaster,bola_thrower,swatter,catch_trap,deflector,gyro_jammer, 640x480.
- Each kind has 8 key-pose stills: rest, idle, move, wind-up half, wind-up release, attack, hit and death. shots.json lists them.
- The tool takes stills, not moving clips.

## Run

Both jobs ran on headless gamescope on the RTX 4080, with sound off and a scratch data home. Import and capture exited 0 for both.
