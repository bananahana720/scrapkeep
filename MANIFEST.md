# W1-93 working machines, PC capture (job AA)

- Build: ceb2cfcd. Tool: tools/work_machines_capture.gd --seconds=24 --near=1, --fixed-fps 15, --audio-driver Dummy.
- Display: headless gamescope on the RTX 4080 (10de:2704), 1920x1080. Both runs exit 0 (park_dam 621 s, park_flume 664 s wall).
- One folder per shot: still.png and a 24 s mp4 (360 frames). `_near` is the 40 m camera; the other is about 90 m.
- WORKS_CAPTURE lines are in aa-park_dam.log and aa-park_flume.log. Raw frame PNGs stay on the PC (2.7 GB).
