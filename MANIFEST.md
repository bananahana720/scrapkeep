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

## Version 2 (jobs AE2 and AF2)

- AE2 used PR 966 at 1e4ea54a, with the same scratch lamp_capture.gd and the same framing as the third take. Files are in lamps-1e4ea54a/. At 75% of the wind-up the lamp's energy is 0.84, which is below the new 1.3 peak. At rest it is 0.25.
- AF2 used PR 968 at 269b4b32, with the same enemy_clip_capture.gd command. Files are in clips-269b4b32/.
- Both runs exited 0 on headless gamescope on the RTX 4080, with sound off.

## Version 3 (jobs AE3 and AF3)

- AE3 used PR 966 at bb86558f. Files are in lamps-bb86558f/.
  - Each kind is shot at rest, at 75% of the wind-up and at the strike (the attack live, 100%).
  - For the wind-up and strike shots, a real hostile telegraph ring, Telegraph.ring with Threat.Type.INSTANT, stands 2.4 m to the side of the crew at the same progress.
  - The lamp energy is 0.25 at rest, 0.84 at 75% and 1.3 at the strike. scratch-tool/lamp_capture.gd is updated.
- AF3 used PR 968 at e8094fd2, for the deflector and the gyro jammer only. Files are in clips-e8094fd2/.
- Both runs exited 0.

## Version 4 (job AF4)

- PR 971, branch claude/project-thread-ihg103 at f20ff5ed. Files are in clips-f20ff5ed/.
- enemy_clip_capture.gd --kinds=gyro_jammer, exit 0.
