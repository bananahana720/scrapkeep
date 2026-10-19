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

## dig: Dig world (park_pit, park_sinkhole)

- `ingame_contact.jpg` and `ingame/`: calm and react frames for each kind and park, captured with `tools/ambient_capture.gd` (this PR) at Dig head 441a38ec (xvfb, opengl3, preset high, 1280x720, close capture camera).
- `clips/`: 7 mp4s.
- `capture_states.txt`: the member states per second.
- `bats_before_after.jpg`: before the roof veto, bats were planned where no roof exists. Now they roost only under a real roof, which means park_pit's adit portals; park_sinkhole has none for now.
- `models/`: Blender stills of the burro, bat, lizard and prospector.
- `bats_roosting_below.jpg` and `clips/ambient_park_pit_tube_bat_below.mp4`: the park_pit roost seen from below (the capture tool's roost camera), two bats hanging under the adit beams. They read small and dark against the timber; that is a visibility question for the 4080 A/B, not a misread.

## hd: Highdraft world (park_islands, park_crown)

- `ingame_contact.jpg` and `ingame/`: calm and react frames for each kind and park, captured with `tools/ambient_capture.gd` (xvfb, opengl3, preset high, 1280x720, close capture camera). The lamb and wren frames are from Highdraft head 4eccc65b; the net weaver frames are from dc925c72, after its tail was retoned.
- `weaver_before_after.jpg`: the first capture showed the net weaver's plum and cream tail bands as high-contrast stripes, which rule 1 keeps off ambient kinds. dc925c72 retones them to plum and lilac rings.
- `clips/`: 6 mp4s.
- `capture_states.txt`: the member states per second.
- `models/`: Blender stills of the lamb, wren and net weaver (the weaver after the retone).
