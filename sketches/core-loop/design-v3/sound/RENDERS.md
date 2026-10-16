# Sound bible renders, 2026-10-16

Audio lives outside the repo in `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, the same way the existing `music_ace/` manifests point at renders outside it. The render job is that folder's `ace.json`. ACE-Step 1.5 XL turbo ran in draft mode (int8 DiT, planner on, instrumental) on the RTX 4080 with seeds 2101 and 2102. Title C came from a second round, `ace.py lab . round2`, with seeds 2201 and 2202 at the band's 172 BPM. The tempo search only covers 120 to 138 BPM, so its tempo is not measured. Each MP3 is loudness-matched to -16 LUFS with one constant gain.

## Measurements

These come from [cut_loops.py](cut_loops.py), whose tempo search read a synthetic 129 BPM click as 129.00. They are technical checks only. No one has listened to these takes yet.

| Take | Length | Kick tempo | Longest stretch under -50 dBFS | 16-bar loop seam jump |
| --- | --- | --- | --- | --- |
| title-a-sax-noir-s2101 | 92 s | 127.0 | 4.6 s | |
| title-a-sax-noir-s2102 | 92 s | 126.9 | 5.0 s | |
| title-b-machine-lead-s2101 | 92 s | 128.0 | 2.0 s | |
| title-b-machine-lead-s2102 | 92 s | 128.0 | 2.1 s | |
| title-c-anime-opening-s2201 | 92 s | not measured, asked for 172 | 4.0 s | |
| title-c-anime-opening-s2202 | 92 s | not measured, asked for 172 | 2.5 s | |
| spillway-loop-s2101 | 62 s | 127.0 | 1.6 s | -1.6 dB, candidate |
| spillway-loop-s2102 | 62 s | 128.0 | 2.0 s | -15.2 dB, rejected |
| dig-loop-s2101 | 62 s | 128.0 | 2.4 s | -17.6 dB, rejected |
| dig-loop-s2102 | 62 s | 128.0 | 2.4 s | -0.3 dB, candidate |
| highdraft-loop-s2101 | 62 s | 123.9 | 2.5 s | +1.0 dB, candidate |
| highdraft-loop-s2102 | 62 s | 128.0 | 2.3 s | -4.1 dB |

Two findings matter for wiring:

- **Tempo drifts below the request.** Every take asked for 129 BPM and came back between 124 and 128. To sit on the engine's 129 grid, a picked take needs a time-stretch of about 1 to 4 percent before stem splitting. Rubber Band at that ratio is normally inaudible, but that is not yet checked on these takes.
- **Seams.** A loop whose head and tail differ by more than about 3 dB has its cut landing across a section change. Three loops pass that bar. A seam can still click or drift at the beat level, so the loops need a listen before they become runtime assets.

## Checksums (SHA-256)

```
c653fc7bdbaf637d6ba3287014c8759617f44f305d9c39329054b7d17f30d481  renders/sketch-1/title-a-sax-noir-s2101.mp3
e216e1533c9615f628f80eaa9b40fa905f109bb0953ee913479fce0c7080bd37  renders/sketch-1/title-a-sax-noir-s2102.mp3
2fc89b7672b30af5d2c5d366ec0a7bf75715932a3343e21079bc606eccfa3556  renders/sketch-1/title-b-machine-lead-s2101.mp3
7a3b8610316c386f46f04dcf6fb1b3559ef0fed0c67975dfaa20cf6891bdfb75  renders/sketch-1/title-b-machine-lead-s2102.mp3
edd0023ae039408290dbf1f11dc1dab84e6e9fb190318382db43aeb969f2c41b  renders/lab-round2-1/title-c-anime-opening-s2201.mp3
de1f4c9d97e81c404d7dff4a9b8d4a102dc4e9e54400a66a8e0696646e957eda  renders/lab-round2-1/title-c-anime-opening-s2202.mp3
5afc9ac451f14a36545ccc6dd47a3ec132b5e89a3d6e270a1689bc9e9defc768  renders/sketch-1/spillway-loop-s2101.mp3
160ee71d08827399c4b9f6cc08ad2fc3037a2cc0cbfa68b1e587801d350699b5  renders/sketch-1/spillway-loop-s2102.mp3
025fb9d530937e60923ff9d4af31fceac7d4b08534774125dbc0ea9a3c2ea49f  renders/sketch-1/dig-loop-s2101.mp3
8d2f39fcc5efbbcc7d1be8666f8c36566a99e81a0b29634e5aad19b34dacb3a2  renders/sketch-1/dig-loop-s2102.mp3
affa2a9ca48dda82062faf6e875661a8ff6239ae4ec138e6a156d5cf12d41981  renders/sketch-1/highdraft-loop-s2101.mp3
c364a2b35f642701d95b9853c37ffe00e55822e6075e39f62abfa570a47d9a90  renders/sketch-1/highdraft-loop-s2102.mp3
31626f8a1eef73406408f06246cb40739947bd6a613c6709f78bf285f047cd85  loops/spillway-loop-s2101-16bar-loop.wav
02d221688f847a74a4ef76fb0273552ee3e2b2e42edb0189b75b9841e9812906  loops/dig-loop-s2102-16bar-loop.wav
f6fc8c18e8d052ef64a7d630f5bc5ad8a958e9bf45929d0792c4217e189a05c0  loops/highdraft-loop-s2101-16bar-loop.wav
708b88ea25f1aed727757acf7b950d91f76c653e0f9e20d53862d88fd4b2b332  event-sounds/scrap-pickup.wav
8ee5fb3578a98f68a329c3452d2f6460ba57e8f60ed495018f9dde61019506d2  event-sounds/harpoon-hit.wav
623b741531e02f1d6e5bb94dd7120b70be9ecd83607f5e22bc5042a0bb82bcc3  event-sounds/run-complete.wav
59a58533ddf2e21e9acdd4c27564dc9464c950e91b29431a7cc477cf750294df  event-sounds/menu-move.wav
b8944899861cc07c6d583fdf576a7043f6ed7c0f3887f46882ffda540a888c72  event-sounds/menu-confirm.wav
9221303ef089396bed26231dc2c44fd0a8ee4b6fdaccf13f6787f86513baf915  event-sounds/run-failed.wav
```

## Reproduce

```bash
PATH=<shim dir>:$PATH CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=0 python3 ~/.claude/skills/song-composer/scripts/ace.py sketch <render folder> --seeds 2101 2102
~/.local/share/ACE-Step-1.5/.venv/bin/python -I cut_loops.py <render folder>/renders/sketch-1 <render folder>/loops
~/.local/share/ACE-Step-1.5/.venv/bin/python -I event_sounds.py <render folder>/event-sounds
```

The shim is a one-line `nvidia-smi` wrapper that adds `-i 0`. Since the RTX 3060 was installed, `ace.py`'s VRAM check fails because it parses one line of `nvidia-smi` output and now gets two.
