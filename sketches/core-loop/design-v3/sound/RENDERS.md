# Sound bible renders, 2026-10-16

Audio lives outside the repo in `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, the same way the existing `music_ace/` manifests point at renders outside it. The render job is that folder's `ace.json`. ACE-Step 1.5 XL turbo ran in draft mode (int8 DiT, planner on, instrumental) on the RTX 4080 with seeds 2101 and 2102. Title C came from a second round, `ace.py lab . round2`, with seeds 2201 and 2202 at the band's 172 BPM. The tempo search only covers 120 to 138 BPM, so its tempo is not measured. Andrew rejected that first title C as "way too Asian-inspired", so it is superseded. A third round, `ace.py lab . round3` with seeds 2301 to 2304, rewrote the caption around opening-sequence tropes without the word "anime" and excluded pentatonic and East Asian colour. Its readings near 129 could mean the takes fell to the house tempo, or could be a 3:4 reading of 172; that needs an ear. Each MP3 is loudness-matched to -16 LUFS with one constant gain.

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
| title-c2-show-opening-s2301 | 92 s | 129.1 read, asked for 172 | 1.8 s | |
| title-c2-show-opening-s2302 | 92 s | 127.5 read, asked for 172 | 2.0 s | |
| title-c2-show-opening-s2303 | 92 s | 128.7 read, asked for 172 | 3.4 s | |
| title-c2-show-opening-s2304 | 92 s | 127.1 read, asked for 172 | 3.8 s | |
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
ef57e9353bf1c377cdbb2fddc585e3cffc2d6f9708d26810ee50aae9054511d1  renders/lab-round3-1/title-c2-show-opening-s2301.mp3
acff4c224ca65755fdef94b1ef0bc6afe94cae6cb53225e36db71cb467636c00  renders/lab-round3-1/title-c2-show-opening-s2302.mp3
dc2fcb5fe9f924e73f4d663a5daa7cf5006cf608cef1bb1cc281affbd43735c5  renders/lab-round3-1/title-c2-show-opening-s2303.mp3
ba2fe1d5d970999419c53251ec6f0fd4e28c5a41ac3c406f40b3c47fbb1ae6cb  renders/lab-round3-1/title-c2-show-opening-s2304.mp3
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

## Full soundtrack pass, rounds 4 to 6

Andrew's go-ahead (2026-10-16) for the full soundtrack and sound effects. Round 4 rendered the combat hype loop and three boss themes, round 5 the roaming music, camp, run summaries and ending, and round 6 a cover of the approved mechanical swing track as an alternative hype loop. Round 6 ran alone in a fresh process after the warm worker ran out of VRAM on it twice. Every take was measured with `cut_loops.py` (172 BPM cues searched from 160 to 184) and stretched with `grid_stretch.py` onto its grid; each stretch report is `stretch.json` beside the files.

Skipped or unreliable stretches: `boss-brindle-s2401` read 138 and stays unstretched; `boss-waking-s2402` reads 130.15 after its stretch; `roam-highdraft-s2501` read 166.65 and 177.4 after stretching, so both Highdraft roaming takes are delivered unstretched; the four run-summary takes are short fanfares the detector cannot read, so they stay unstretched too.

The event set: 49 cues from `event_set.py`, checked by `check_events.py` (0 failures; the self-test's planted cue trips all three checks). `event-set-reel.mp3` plays every cue in order with `event-set-reel.txt` as its cue sheet.

```
083031f880ff9d9744ae700450ce8945f16ecadc70681d0a05d29f7dc9fa8ae7  renders/lab-round4-1/grid129/boss-brindle-s2402-129bpm.wav
7aca7506204311f89bce7d0570d04caca58bde61367127366fcee2b1588d4e7e  renders/lab-round4-1/grid129/boss-mind-s2401-129bpm.wav
7f82e496f02df1f298434caa66ec442bc4ae0345f40f12d5a1c9441b417d3a96  renders/lab-round4-1/grid129/boss-mind-s2402-129bpm.wav
7e5797777b5a65c422bf546b8aade166acc41abf64093707eb598b05ead1b58e  renders/lab-round4-1/grid129/boss-waking-s2401-129bpm.wav
af81fc23f248eb36ed8b5288c243fc1516d5215fd9c2f98e539aeed5fd02f1ea  renders/lab-round4-1/grid129/boss-waking-s2402-129bpm.wav
3e666a927386f3b7b9df1f20383588cb2815b7670a62e04c82cfca3023a1b929  renders/lab-round4-1/grid129/combat-hype-loop-s2401-129bpm.wav
1c15d346a8aa32dd23fc90f83c7adfbc3bde6e77ee0110e123dcbe733723f668  renders/lab-round4-1/grid129/combat-hype-loop-s2402-129bpm.wav
99d65b6c974dbf6dd3b0cf8003ecede08adee4482eef5e6cd737f3b29659812e  renders/lab-round5-1/grid172/ending-s2501-172bpm.wav
ccfc2e60a9ccef9473b4851355ca3d92104f03dde7741d358cd9f75f8e9d77da  renders/lab-round5-1/grid172/ending-s2502-172bpm.wav
dc61e6819fd0202637a85094bbcc58d038c6411ccfee0f41bba47eda2407e40e  renders/lab-round5-1/grid172/roam-dig-s2501-172bpm.wav
f075c9fc3933cd36c417e8a69be38bf963e56cffc302a2ec19fa1b7561b5ad44  renders/lab-round5-1/grid172/roam-dig-s2502-172bpm.wav
8d03321fe160a9a5d7912ad19179c6466f77abb04393dfd21d84d482520d6e23  renders/lab-round5-1/grid172/roam-highdraft-s2501-172bpm.wav
ee5d38a63a98b288c97b84d33c7322046ac72e2fb350f06c95702162f3a864be  renders/lab-round5-1/grid172/roam-spillway-s2501-172bpm.wav
472ddbe54cae65cd8ded747ded0caeb5c728788bf8fb354862260292ec22fd81  renders/lab-round5-1/grid172/roam-spillway-s2502-172bpm.wav
a5b30b804004c37215c41ad177441a182854b1783b9afb24a2cecfaffdb520f2  renders/lab-round5-1/grid129/camp-s2501-129bpm.wav
76bb58a2ae8a2320a18745624a8c671943c8a126c8fd08531cdc588b17b18514  renders/lab-round5-1/grid129/camp-s2502-129bpm.wav
390daa2e4a950a9e9ff18f3cdbb2c8ec6db2b6f80328ddcedeea25ccfc4ef54b  renders/lab-round5-1/grid129/summary-loss-s2502-129bpm.wav
ce35040ebc776cdf5e06c6f102e53744567aaeb6a09b7eb3c4680baa32f44989  renders/lab-round5-1/grid129/summary-win-s2501-129bpm.wav
1fca960bffd1296d7feef59e5fda7642441f7bd53f815fa02a240b3f80d7b15b  renders/lab-round6-1/grid129/combat-hype-cover-mechswing-s2601-129bpm.wav
45b942e3e9dd84e628a8bd6823799da8445550623f86caeb025c3e9dcffe1d71  event-set/achievement_chime.wav
5378c615600f7780e27c961f06e9c9954dc233d01ead5f3d50bef159d8aefb77  event-set/armor_shed.wav
7c3fd071536f47b08c899b76fa1642cb35258cf13bbd8d63d13564cac6b33dd5  event-set/boost_whoosh.wav
4c7c00ac064699683fcb388a8e8491bef0cc3fcfad668677a1f4bcc83ea1031c  event-set/boss_arena_in.wav
a016d9f4bff129a10de38612d82d56fa52b26e134b7698575a4e7bb96d51a75d  event-set/boss_phase.wav
b310c2aa6daea70f045af59e73ce4e98d8f64d3990ac367fff0adf09556db426  event-set/boss_weak_hit.wav
c80bd13219496c69e3e6f6b79f87e65111eeb8073067b1c1e635e596e1781bef  event-set/callout_chime.wav
64232dcf772e403377d29fef6207ef022f9fca14542ead95c398dbb03a0a85e7  event-set/crit_ping.wav
74ba1893d22284b75052b04e262c44a77635dba60616200b861a909fc49fc4bb  event-set/dash_whoosh.wav
bcd96ad726738ef339c2205f29b52325ddfa9080ce37a927a1d1f62c22c51877  event-set/death.wav
305a13e82e3c9690a73d5bbdbb736fd92f8b15ebeb52b83c19c97a8591138405  event-set/found_chime.wav
3475084a9081df6d18b3985267b7b3eb657c3114c5ab7484c7ffccd903b07b90  event-set/hit_thwack.wav
34ec7c05361b997550e08ed57bc96e34f01d2905bdea93a25fe3061045b669ce  event-set/hop.wav
c2392a6f9895d057497ffe1453d3239793b5b94224912a9fbd133bac5e192f96  event-set/hurt.wav
2f9215d169459f42c1ed38788652840d98172b8e4db5c5a0b8f521d9e3e28fb9  event-set/kill_chain_tier_1.wav
b58f3021fe26a1373d0747c429cd2504008b52e8b05c513f334c264472a41e42  event-set/kill_chain_tier_2.wav
ddb74ca14779c3281c3356e379448f1abe04bcc6a806994528f0558492b0bba0  event-set/kill_chain_tier_3.wav
734d4c7347fdafee19ca2f039fc9639dbfc3a35668bcc1240d1bdb0d78b2c589  event-set/kill_chain_tier_4.wav
9df58e6b5994207d375ef587e662b4700c8bf14d0d5ebdbc04fac5265dd81922  event-set/kill_chain_tier_5.wav
a5ba53db174d5caa1202e247f43a22df246b054976440db8ce85cd002a153d44  event-set/kill_pop.wav
8ce0e4b8d3b2bc2f4049f5fab9001a3cf81c7002a5b05a187c4d4b29c96afca2  event-set/land_thud.wav
8342f6c2829d91e56ee6f8fd8e6b4b8f8e9e51b6802f66d1a9b4f2f82694edf6  event-set/lore_found.wav
2f83e79393f21344599b1db621d5cca34fe8fa3596fe85e917079574a97d1998  event-set/near_whoosh.wav
99917acfb8d41d618f888675300959033f0e7ac5c7579b4d0682491b24776c68  event-set/part_get.wav
b48a42e2bd4cbcb871f1a29605dbc24acf1632173f882c962f7d8626f2ca3530  event-set/pickup_fountain.wav
20815cfac40563d614b5a0dba59e45b8ffbbf48f5d7e53c855217d960ac9d4fa  event-set/pilot_unlocked.wav
a8ae05ed03f16be681c5e580ed10a00667d60ad9fc5c6ea475358ece5024c66d  event-set/rarity_bell_common.wav
6a54acd31b725bd568879ed9855fe5633ee048cdd6f781c1d2bfe4a1c409ad07  event-set/rarity_bell_epic.wav
c034b2f20e34184341b056bc30af89a88b265be1ef6080d60498efcd087c99f5  event-set/rarity_bell_rare.wav
c55ab6342129c9f7e9e529eaefbb2f28719767921b152e39d789da154c748ed6  event-set/rescue_fanfare.wav
2821de9419fb7190fff754abce9ab0afe8c95722b4ad219771b6934b8eec7a19  event-set/scrap_tick_1.wav
ca38cdd1cb5cb26f45335066fbe128e27aa40ad8039759694bbb60ac4689512f  event-set/scrap_tick_2.wav
d4f8dc435936afba3040152a2cf254815cab390c5545d4b9eb19d93f864976f9  event-set/scrap_tick_3.wav
567d978b36a9905396b881d43a06d2bd13e0b43352f143de5b4fbf08e70aa798  event-set/scrap_tick_4.wav
25d10fd997b4ec01f61b8b020e63bdac5b2ae03d970d2b5e82c809e94267d0f8  event-set/scrap_tick_5.wav
796934379033d1c07f9f2dddd15bc0341c38301c12661d3abb744c0d03dc2699  event-set/shop_bell.wav
0f047dc149cb99704c0e29bc17bdf003ce6ccb97d015c1561d29d72e69b5a1ac  event-set/slam_boom.wav
23b7c5a11d9db74aee8c2ef522df6f68149dda30eca8beb5b9ad4f4a55619754  event-set/smash_crack.wav
e946ad8e0f8d1ca8779640ec4fa41551293e48e5ec82aad10d388c4610e2eab7  event-set/stinger_boss_defeated.wav
8848aaea55c8e38381d4f472874f888623d1d43723b5c2ec214bac4e84b5bfe1  event-set/stinger_clear.wav
42d643865042864f8cb54a322e62ea901c29a5ea698c078c2312a6e3f44234fc  event-set/stinger_milestone.wav
ca7aa97e4622af08a40b81ff85ecb691ecce6b1a05e7cd5905a1a13eb63b81f8  event-set/stinger_run_end.wav
f42ea10c66f5a3fbad65fa67ffe00a4d22dc90e76a2e4e5345af323f15d508fb  event-set/stinger_run.wav
48732387f468d2a9a76b5797b23938eaa72627cb1c4af4684b54a77b5dcebeb7  event-set/stinger_stage.wav
beca361e5280193d04c3b22050f8b53c2f61e3f836f189fd709610028ffb91e0  event-set/stinger_world.wav
42d643865042864f8cb54a322e62ea901c29a5ea698c078c2312a6e3f44234fc  event-set/synergy_fanfare.wav
a96b8048f316ace2b04cd22c4c9e04a6195aca5120ab7723d9c4dfabfa12a889  event-set/threat_whistle.wav
94762c1fbb9d3aa2b47f310118ecd99dbe9ad92c631daed717ff0a04058d147c  event-set/ui_tick.wav
876f826ee0d6cef027704cab5b02e8ab1b69f766664a2df7217171369c6a4915  event-set/verb_fail.wav
0709df2f584db81b7619a0d4c32bcb3598ff3783c9dad9de1e44dd527c2da23b  event-set-reel.mp3
```

## Reproduce

```bash
PATH=<shim dir>:$PATH CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=0 python3 ~/.claude/skills/song-composer/scripts/ace.py sketch <render folder> --seeds 2101 2102
~/.local/share/ACE-Step-1.5/.venv/bin/python -I cut_loops.py <render folder>/renders/sketch-1 <render folder>/loops
~/.local/share/ACE-Step-1.5/.venv/bin/python -I event_sounds.py <render folder>/event-sounds
~/.local/share/ACE-Step-1.5/.venv/bin/python -I grid_stretch.py <run dir> <run dir>/grid129 [--target 172 --only roam- ending]
~/.local/share/ACE-Step-1.5/.venv/bin/python -I event_set.py <render folder>/event-set
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py <render folder>/event-set
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py --self-test
```

The shim is a one-line `nvidia-smi` wrapper that adds `-i 0`. Since the RTX 3060 was installed, `ace.py`'s VRAM check fails because it parses one line of `nvidia-smi` output and now gets two.
