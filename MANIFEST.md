# Job AS: PR 990 ball looks on stage/alpha-w40 6d4320b8

tools/ball_look_capture.gd, four runs on the Vulkan renderer under headless gamescope on the RTX 4080, 1920x1080, no audio: --ball-look=cutaway and --ball-look=today, each bare stage and --game=1. All four exit 0. The tool names the today look "current" in its file names.

| Look | Triangles | Surfaces | See-through surfaces | Pilot seen, rest / fast (median) | Chase-rest draw calls |
| --- | --- | --- | --- | --- | --- |
| today (current) | 14,576 | 20 | 0 | 0.538 / 0.537 | 40 |
| cutaway | 12,732 | 13 | 0 | 0.849 / 0.852 | 26 |

PC lane, Claude Opus 5.5.
