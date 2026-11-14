# Job AT: PR 993 cutaway kit on stage/alpha-w40 8dd574f5

tools/ball_look_capture.gd on the Vulkan renderer under headless gamescope on the RTX 4080, 1920x1080, no audio. All 16 captures exit 0. Files without a heft suffix are heft 1. The real-run pickup film (item 4) follows in a later commit.

Pilot seen by the chase camera (median over spins; worst in brackets):

| Pilot | Heft 1 rest / fast | Heft 5 rest / fast | Pilot height px |
| --- | --- | --- | --- |
| pylon_engineer | 0.886 / 0.885 | 0.887 / 0.885 | 117 |
| runner_gunner | 0.729 / 0.737 | 0.730 / 0.738 | 96 |
| demolitions_caster | 0.814 / 0.826 | 0.814 / 0.826 | 107 |
| tarn | 0.828 / 0.829 | 0.828 / 0.830 | 98 |
| tally | 0.806 / 0.815 | 0.806 / 0.813 | 106 |
| remembered_cannon | 0.799 / 0.807 | 0.798 / 0.807 | 93 |
| pylon_engineer heft 3, 40 plates, cutaway | 0.887 / 0.886 (worst 0.884) | | 117 |
| pylon_engineer heft 3, 40 plates, today | 0.217 / 0.214 (worst 0.068) | | 117 |
| pylon_engineer, paint d94f8a | 0.888 / 0.885 | | 117 |

No see-through surfaces in any capture. PC lane, Claude Opus 5.5.

## Pickup film (item 4)

Self-play seed 1, skipper, --ball-look=cutaway, filmed every second to stage 3 (441 frames, exit 0). film/ holds the frames either side of the biggest mass jumps (stage 1 at 7 s and 66 s, stage 2 at 61 s and 114 s, and the Brindle fight) and crop-*.jpg, the ball cut out of them. With chunks and plates riding the rim, the pilot still shows through the window in the later frames (0231, 0232, 0380). The aim reticle sits over the window at play size.
