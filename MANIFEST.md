# Effects critique captures, stage/alpha-w38 46de0578

Rendered on the PC's RTX 3060 (Vulkan, headless gamescope), silent (--audio-driver Dummy). Item 5, stress_capture timings, runs later in a quiet slot on the 4080.

| Item | Folder | Command | Exit | Wall |
| --- | --- | --- | --- | --- |
| fx-0.1 | fx-0.1 | see below | 0 | 21 s |
| fx-0.35 | fx-0.35 | see below | 0 | 12 s |
| fx-0.6 | fx-0.6 | see below | 0 | 11 s |
| fx-0.85 | fx-0.85 | see below | 0 | 11 s |
| fx-0.35-reduce | fx-0.35-reduce | see below | 0 | 11 s |
| flash | flash | see below | 0 | 65 s |
| reel | reel | see below | 0 | 582 s |
| brindle | brindle | see below | 0 | 31 s |
| phase | phase | see below | 0 | 27 s |

- fx-*: tools/fx_capture.gd --freeze=<f> at 1280x800; fx-0.35-reduce adds --reduce-flashes. Each has <id>.png and frames.json.
- flash: tools/flash_capture.gd at 1920x1080; peak.txt is still_compare --peak for each site and mode (rest against peak).
- reel: tools/sight_reel.gd --fixed-fps 60 --write-movie at 1600x900. reel.mp4 is the movie writer's 1.6 GB MJPEG AVI re-encoded to H.264 (CRF 26, no sound), 208.7 s; reel.json is the motion count.
- brindle: tools/brindle_beats_capture.gd --human=1 --fixed-fps 30 at 1920x1080.
- phase: tools/phase_read_capture.gd --resolution 1920x1080.

Files over 50 MB: none (the raw AVI stays on the PC).
