# Effects "after" strip for PR 912, head 65ea10e7

Rendered on the PC's RTX 3060 (Vulkan, headless gamescope), silent (`--audio-driver Dummy`). Branch `claude/project-thread-u3wusy` at 65ea10e7081b. All steps exit 0; the times are in steps.txt.

## What each folder holds

| Folder | Command | Wall |
| --- | --- | --- |
| fx-0.1, fx-0.35, fx-0.6, fx-0.85 | `tools/fx_capture.gd --freeze=<f> --only=spark_core,crit_core,daze_halo,moment_hit,moment_crit,moment_kill_ink,moment_kill_card,moment_kill_plain`, 1280x800 | 13, 9, 9, 9 s |
| fx-0.1-reduce | the same at 0.1 with `--reduce-flashes` | 8 s |
| fx-0.35-tint-8bf0d3, fx-0.35-tint-e6d9b8 | the same at 0.35 with `--tint=<hex>` | 9 s each |
| reel | `tools/sight_reel.gd --only=chaser --fixed-fps 60 --write-movie` (the chaser arrives, takes a hit, is stunned and dies on the dam). reel.mp4 is the 198 MB MJPEG AVI re-encoded to H.264 (CRF 24, no sound), 5.9 MB | 88 s |
| stress | `tools/stress_capture.gd`, which runs S1 to S3; only the S2 stills are kept, and no timings were read | 79 s |

`sight_reel.gd` has no option to choose the ground: its reel already plays on the dam. `stress_capture.gd` has no option to run S2 alone.

## Pass lines

`drawn_px` and `contrast` are fx_capture's own counts in frames.json. Contrast is the mean change, out of 255, of the pixels the effect drew against the empty sand stage.

| Line | Result | Verdict |
| --- | --- | --- |
| Stun (daze_halo) draws at least 4 x 17 px | box 57 x 28 at 0.1, 84 x 36 at 0.35, 81 x 34 at 0.6, 101 x 46 at 0.85; 378 to 909 px drawn | pass |
| Hit core contrast on sand 60 or more | spark_core 73, 69, 70, 79 (0.1, 0.35, 0.6, 0.85) | pass |
| moment_kill_ink draws more than moment_crit at 0.1 and 0.35 | 7791 against 4396 at 0.1; 9650 against 3320 at 0.35 | pass |

The stun's box is measured against `fx-0.85/moment_hit.png`, which changed only 4 px, so it stands in for the empty stage (fx_capture keeps no empty still). Its drawn count matches the tool's own: 382 against 378 at 0.1.

If "hit core" means moment_hit rather than spark_core: moment_hit reads 59, 52, 50 and 21, which is under 60.

## Counts (drawn_px / contrast)

| id | 0.1 | 0.35 | 0.6 | 0.85 | 0.1 reduce | 0.35 tint 8bf0d3 | 0.35 tint e6d9b8 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| spark_core | 1509/73 | 1063/69 | 484/70 | 173/79 | 1468/69 | 1063/69 | 1063/69 |
| crit_core | 3228/70 | 1485/71 | 614/78 | 0/0 | 3160/70 | 1485/71 | 1485/71 |
| daze_halo | 378/110 | 522/111 | 403/124 | 909/114 | 378/110 | 522/111 | 522/111 |
| moment_hit | 1206/59 | 743/52 | 337/50 | 4/21 | 853/68 | 743/52 | 743/52 |
| moment_crit | 4396/65 | 3320/57 | 1530/58 | 603/61 | 3464/62 | 3320/57 | 3320/57 |
| moment_kill_ink | 7791/69 | 9650/71 | 7767/42 | 653/22 | 5312/44 | 9710/80 | 9784/73 |
| moment_kill_card | 13547/74 | 14214/75 | 12539/57 | 5273/33 | 10938/40 | 14870/80 | 14575/76 |
| moment_kill_plain | 1154/31 | 2083/39 | 1018/39 | 411/30 | 1101/28 | 1726/37 | 1713/32 |

Files over 50 MB: none. The raw reel AVI stays on the PC.
