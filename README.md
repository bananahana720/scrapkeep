# Ambient life lane evidence (wave 17, Wave board #149)

Disposable evidence for the Ambient life PRs; nothing here ships. One folder per slice.

## l1: system plus Spillway (park_dam, park_flume)

- `ingame_contact.jpg`: 16 in-game frames, a calm and a react frame per kind and park. Rendered with `tools/ambient_capture.gd` (lands with the Dig PR) under xvfb, opengl3, preset high, 1280x720, at head ea077244. The ambient code there is identical to the PR head 2946e323, which only adds a stage merge. The camera is a close capture camera (7 m, fov 28), not the player camera.
- `ingame/`: the same frames at full size.
- `clips/`: 8 mp4s, one per kind and park: 2 s calm, the ball closes from 25 m to 5 m, a stub telegraph goes live, and the members react and hide. There are also two gifs.
- `capture_states.txt`: the member states each second, printed by the capture tool.
- `veto_before_after.jpg`: the capture at 48d2bed0 found quail on 48 to 63 degree dome faces and swifts inside the weir gatehouse. ea077244 vetoes both.
- `models/`: Blender stills of the four Spillway kinds (front three-quarter, side, react).
- `reference/enemies_sheet.jpg`: 12 world-one enemies (Cycles CPU, `tools/blender/glb_stills.py`), for the first-look comparison.
- `models/dam_swift_*.jpg` show the swift after b76cd78a lifted its body tone (first-look note); the in-game frames still show the older, darker swift.
