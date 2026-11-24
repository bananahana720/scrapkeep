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
| title-c2-show-opening-s2301 (Andrew's pick) | 92 s | 129.1 read, asked for 172 | 1.8 s | |
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
6b1acaa5b56fd93da93391b7c8c3b15abb22fe5b2221829637cb3f793d1b3f68  event-set/boss_arena_in.wav
a016d9f4bff129a10de38612d82d56fa52b26e134b7698575a4e7bb96d51a75d  event-set/boss_phase.wav
939956e3e717c3aefb9ac2ed761be99d963c4dc3760f9ede8881172e3ec18570  event-set/boss_weak_hit.wav
c80bd13219496c69e3e6f6b79f87e65111eeb8073067b1c1e635e596e1781bef  event-set/callout_chime.wav
dcc4066c214b21d09fe80449af7f2a386bef92d2a2c1b3592dc685d5feba001b  event-set/crit_ping.wav
74ba1893d22284b75052b04e262c44a77635dba60616200b861a909fc49fc4bb  event-set/dash_whoosh.wav
bcd96ad726738ef339c2205f29b52325ddfa9080ce37a927a1d1f62c22c51877  event-set/death.wav
305a13e82e3c9690a73d5bbdbb736fd92f8b15ebeb52b83c19c97a8591138405  event-set/found_chime.wav
24c1efce87954d6a4306bcdcd6a63bf4aab10ea92cf8f2e1cb5608652a4ca10e  event-set/hit_thwack.wav
34ec7c05361b997550e08ed57bc96e34f01d2905bdea93a25fe3061045b669ce  event-set/hop.wav
c21c449a597bbe16e8ccc5e6bd5ce63dc1ffc764d647b993c0fc1dec8978d309  event-set/hurt.wav
1e0f85ca127ed6fa6ead590bf148609b5d6c0f31f79fe5341b7d9228420376ca  event-set/kill_chain_tier_1.wav
2cfc786b0622510327db827cc763460707555bc802e4c88cf712af6d5f05c6ef  event-set/kill_chain_tier_2.wav
e5e3d45f71dc46d3d4b5ea62c15cb3f8fc08f1a7c23245ccc8a32f2fa3d3b2a9  event-set/kill_chain_tier_3.wav
65f1a645e2c8ea3557cd7b623367610e25d62b21deb1a27d9f4382fac679bf22  event-set/kill_chain_tier_4.wav
a8a1e965db6d8a3e147adfcba9bf7f8af7e5f57227a4a7c746f861c900002804  event-set/kill_chain_tier_5.wav
4d06a8780f9a4647ac19485211687d8e17febcae8564308053c36d4ab4bfd853  event-set/kill_pop.wav
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
4312e4786346df64b09ed05ef1c3f9046ad28414e2bbdb9e7f7b453e9c971919  event-set/ui_tick.wav
876f826ee0d6cef027704cab5b02e8ab1b69f766664a2df7217171369c6a4915  event-set/verb_fail.wav
ff2a1c3ba2f4d2581ce8e5b6a4f4fc7c71ab2c666264d31bc118da0536e499c9  event-set/weapon_zap.wav
1239c485eae9f1d589eb473e7f6eea8516aceb166d2c7f09c491edb31a1f168f  event-set/clank.wav
0709df2f584db81b7619a0d4c32bcb3598ff3783c9dad9de1e44dd527c2da23b  event-set-reel.mp3
```

## Special enemies, 2026-10-17

17 cues from `specials.py` in `specials/`, checked by `check_events.py`: 0 failures. Two families are new to the checker. `spawn` must start within 5 ms and last at most 1.5 s. `presence` must last at most 4.0 s and wrap with a sample jump below -24 dB of its peak. The self-test's planted ramp loop trips the seam check. The original 49 event cues still pass.

The first build of the presence loops folded a 1 s tail onto the head of each loop, which doubled the steady drones there. Spectrograms showed it as a step about 1 s in. The fix makes each drone exactly periodic: pitches are rounded to whole cycles per loop, and noise beds are filtered circularly. Only short hits fold now. The first second's loudness against the rest of the loop: Splitter -15.7 against -15.8 dB, Linker -18.6 against -18.5 dB. The Foreman reads +3.3 dB there because its swell is meant to peak at a quarter of the loop. A 25 Hz high-pass removes the DC that the pulse-wave pings carried.

`reel-<name>.mp3` plays each special's presence loop twice, then its tell, break and spawn answer, loudness-matched to -16 LUFS.

```text
6fe6cff89c6b86ac246c66f2579579a870bbd108af78f071650417a134a1fbc0  specials/dispatcher_break.wav
20bc611b828f5b4b2d6247ecc6fd7ad58e55d5a174a908263db93455f60a1c45  specials/dispatcher_presence.wav
734975074c1a37f2d9fb8b5259f7121debea413bdb34f6d698b20247fde9dd3c  specials/dispatcher_spawn.wav
21dc4052d915073622446c42fcf12b23b5854f086a7a8cdd1aa57716285c5d4d  specials/dispatcher_tell.wav
3f3124ad5f1028659779b2fe82039b89c02dae0500798f4b615ab8ad0a7eccad  specials/foreman_break.wav
8238090c2d4a517d2376d2923b4d6de75cc8e6191ab71769a80851dd1dbea63f  specials/foreman_presence.wav
c1245393bc0b521aea76a0cafd98e8de11c862aba50e3bbf080d6c66c1736e99  specials/foreman_spawn.wav
b5fb9b9379d5707726b5592c7156c8dbb429bdc433b5fbd106b06143b72c4b4e  specials/foreman_tell.wav
8664695534dfe523b10c9bcbee0e15b5d78f172af5273d6b0e3cc522be70351a  specials/linker_break.wav
b8d6f1e3add45e034226dcd64a434f0d3f5be634c7445a5ec912f657a94d9ab7  specials/linker_presence.wav
660f19c684226559c7cabfa6a26a8cd1bbebc03ab9cedf1924eedc9b08fd7d33  specials/linker_spawn.wav
03f3724b4640303435e1381cad90c362a6f1c21592f6341385ac29179b4693c3  specials/linker_tell.wav
80fbff0a02bd8a502122650db78821bad7cd73a1c537fd5997729a01c3523326  specials/splitter_break_clean.wav
d72de2af83b858981ef18bd11b0ee73cd905deb4a8623d494510c0fb10b9d0ec  specials/splitter_break_split.wav
83eea248da33d40b8b14d5a8b0e8e8197ba7d48596810220ebe83ef0eecb9bd3  specials/splitter_presence.wav
09fb23850873286523539dfdbf5bc14671a46862a3cecf2743f46bc0064dad9d  specials/splitter_spawn.wav
4cb4f0a3f47e034982e1a96ff959d645e74eeb0c9c0f4f78758f36f6c9f21625  specials/splitter_tell.wav
56570e217e92aac3c017a541ee706dc6fb223520e63b9e42acf1056bb5b644ed  specials/reel-dispatcher.mp3
4c3b8a02d21a0854bfd774f217a7ad43c7eb9288b59951c5d59bf2ff37d7cd0f  specials/reel-foreman.mp3
b2d189f3a543c7e56037393a1d9fd6aafa12ae697932d18877726645531ad9b3  specials/reel-linker.mp3
59476cf7b559c3fc902163cd7794cf3f5641a990a6e9276c26ed4693f16f0660  specials/reel-splitter.mp3
```

## Variations, round 7, 2026-10-17

Covers of the picked parents (`ace.py lab . round7 --seeds 2701 2702`, draft mode, RTX 4080, about 5 s per take). Each source in `variant-src/` is the parent take stretched with Rubber Band to the variation's tempo and cut to 64 s. Brindle's parent is boss-brindle-s2402. The Waking's is boss-waking-s2401, the Mind's boss-mind-s2402, the champion's combat-hype-cover-mechswing-s2601. Each world's roam s2501 is the parent of its secret area. Title B s2101 is the parent of Scrap Rush, and title A s2101 of the minigame. Strength 0.6 for phases and the champion, 0.55 for areas and the minigame, 0.5 for the event.

`measure_variants.py` scores each take's 12-bin chroma over time against its own parent (parent) and against a different variant's parent (other, the control). The control comes from a different theme family (see `family()` in the script), since a sibling phase is the same melody at another tempo. A take counts as having kept its parent when it beats the control by at least 0.1, because a control in the same key scores higher from shared notes alone. Two picks fall short of that: the Mind's final phase (margin 0.07) and secret Spillway (0.05). The listening page flags both for an ear check. Tempo is the kick-onset search within 15% of the request.

| Take | Asked | Tempo read | Parent | Control | Margin | Longest quiet | Pick |
| --- | --- | --- | --- | --- | --- | --- | --- |
| brindle-p1-requisition-s2701 | 138 | 137.9 | 0.54 | 0.14 (boss-waking-s2401-129bpm.wav) | 0.40 | 0.1 s | yes |
| brindle-p1-requisition-s2702 | 138 | 138.0 | 0.52 | 0.13 (boss-waking-s2401-129bpm.wav) | 0.39 | 0.1 s |  |
| brindle-p2-furnace-s2701 | 150 | 132.3 | 0.48 | 0.25 (roam-highdraft-172.wav) | 0.23 | 0.7 s |  |
| brindle-p2-furnace-s2702 | 150 | 150.0 | 0.4 | 0.19 (roam-highdraft-172.wav) | 0.21 | 0.1 s | yes |
| brindle-p3-scuttle-s2701 | 172 | 172.0 | 0.54 | 0.22 (boss-mind-s2402-129bpm.wav) | 0.32 | 0.0 s |  |
| brindle-p3-scuttle-s2702 | 172 | 171.9 | 0.67 | 0.23 (boss-mind-s2402-129bpm.wav) | 0.44 | 0.2 s | yes |
| waking-final-s2701 | 142 | 125.0 | 0.35 | 0.08 (hype-129.wav) | 0.27 | 0.0 s |  |
| waking-final-s2702 | 142 | 129.5 | 0.41 | 0.11 (hype-129.wav) | 0.30 | 0.0 s | yes |
| mind-final-s2701 | 142 | 141.9 | 0.6 | 0.53 (roam-highdraft-172.wav) | 0.07 weak | 0.0 s | yes |
| mind-final-s2702 | 142 | 132.2 | 0.73 | 0.63 (roam-highdraft-172.wav) | 0.10 weak | 0.0 s |  |
| champion-hype-s2701 | 129 | 129.0 | 0.39 | 0.24 (brindle-p3-172.wav) | 0.15 | 0.1 s |  |
| champion-hype-s2702 | 129 | 129.0 | 0.4 | 0.22 (brindle-p3-172.wav) | 0.18 | 0.1 s | yes |
| secret-spillway-s2701 | 172 | 178.5 | 0.37 | 0.36 (r7-brindle-p1-requisition-s2701.wav) | 0.01 weak | 0.8 s |  |
| secret-spillway-s2702 | 172 | 146.3 | 0.46 | 0.41 (r7-brindle-p1-requisition-s2701.wav) | 0.05 weak | 0.0 s | yes |
| secret-dig-s2701 | 172 | 172.0 | 0.55 | 0.07 (title-b-172.wav) | 0.48 | 0.0 s |  |
| secret-dig-s2702 | 172 | 172.0 | 0.58 | 0.11 (title-b-172.wav) | 0.47 | 0.1 s | yes |
| secret-highdraft-s2701 | 172 | 174.0 | 0.41 | 0.06 (brindle-p2-150.wav) | 0.35 | 0.1 s | yes |
| secret-highdraft-s2702 | 172 | 187.5 | 0.5 | 0.06 (brindle-p2-150.wav) | 0.44 | 0.0 s |  |
| event-scrap-rush-s2701 | 172 | 172.0 | 0.36 | 0.37 (r7-brindle-p1-requisition-s2701.wav) | -0.01 weak | 0.2 s |  |
| event-scrap-rush-s2702 | 172 | 172.0 | 0.52 | 0.4 (r7-brindle-p1-requisition-s2701.wav) | 0.12 | 0.0 s | yes |
| minigame-chiptune-s2701 | 129 | 123.5 | 0.46 | 0.27 (roam-highdraft-172.wav) | 0.19 | 0.2 s |  |
| minigame-chiptune-s2702 | 129 | 129.9 | 0.55 | 0.25 (roam-highdraft-172.wav) | 0.30 | 0.2 s | yes |

Both Waking final takes read near 129 against an asked 142, so the model drifted back toward the parent's tempo. `grid/waking-final-s2702-142bpm.wav` is stretched by 142/129.5 and then reads 139.7. The tempo read is unreliable on that take, so it needs an ear. Secret Spillway take 2 reads 146 against 172, probably a half-time feel; also an ear check.

`variations.py` writes the buff previews (the picked hype loop, 4 bars clean, 8 buffed, 4 clean), the switch-hit and turnaround stingers at 129 and 172, and two demos that splice them between real tracks. Spectrograms show each buff entering at bar 5 and leaving at bar 13.

```text
a6c13e34aabd62ac248a769d52e9d98a0bfc3277d4bc93e16b8cfbb0f1880a6c  renders/lab-round7-1/brindle-p1-requisition-s2701.mp3
f3f6980b1b83332ea4ca8a01c32e0f35ddaca23dac66054a1c6fbcf10cb4f57c  renders/lab-round7-1/brindle-p1-requisition-s2702.mp3
3fcf1704f6594dabc6f738e331e1b173dc399c0e1f17aea16dff4c689bad5b43  renders/lab-round7-1/brindle-p2-furnace-s2701.mp3
25f5002369ed3eb2d082394da39850d8597d60c83beeab4fbd43816a40365e7a  renders/lab-round7-1/brindle-p2-furnace-s2702.mp3
bc3250f4898fe84c753fedd9721cde56b775d3ba66c63bda821dcbf6d7b423c3  renders/lab-round7-1/brindle-p3-scuttle-s2701.mp3
4a612b5958ed9c064b39b9ade936f33f2cefec6403e9a765e2ceb64ab2f9712c  renders/lab-round7-1/brindle-p3-scuttle-s2702.mp3
5c082acb0f1c8b8ec188b16e691fe948b99064ceadec12a9fa36b8bb875e419c  renders/lab-round7-1/champion-hype-s2701.mp3
b0c7b3c38d69f7fca3343507e17439be9fb09bb805fe3f0f816dfc278e0f34e0  renders/lab-round7-1/champion-hype-s2702.mp3
f038a6531ffd4562ac4721aaa00a0ddce51a249c5ac0ba27662042ac7a3ca642  renders/lab-round7-1/event-scrap-rush-s2701.mp3
796a048dbe6596d06f00c691940a8a372a4cf25c9be1f8ba37fcd36fb53a9caf  renders/lab-round7-1/event-scrap-rush-s2702.mp3
5abf8dcfb409e2c3fe39096eba9fa6cd9213e6e5ee7d45d7211dcdf4267be6e9  renders/lab-round7-1/mind-final-s2701.mp3
c3a4d5efc385c87e193665cde949bdef9bd88947cd09cfe7f2215a2267d47b79  renders/lab-round7-1/mind-final-s2702.mp3
a697e7f3c9b3e8deeb5a4c0eb023c35668431a34e26143b38016ca32e15f6135  renders/lab-round7-1/minigame-chiptune-s2701.mp3
87a939fc9a2554fb3e95a5292d7eef52ce6e3a475b8f7a8135b96991cc289a92  renders/lab-round7-1/minigame-chiptune-s2702.mp3
006d760e798d6139da1e08d8a96b65542cc7b013ffeccd49d21703ed137501b4  renders/lab-round7-1/secret-dig-s2701.mp3
f49222a267da6796d524017f50e52b9a993ed61663bad9baf88fa7c9f598ab25  renders/lab-round7-1/secret-dig-s2702.mp3
028e84439f24617e682a85658a66cb1cd136e5809a274d3cbd83af254de70803  renders/lab-round7-1/secret-highdraft-s2701.mp3
9b2f9edc960cbb9cb061b8b9aa78f8a3acec37538062854e4ff5866ed7027a40  renders/lab-round7-1/secret-highdraft-s2702.mp3
ccda33ed3183892baae310cca5c5484857d9ec7496c317d3d46e49ff4fefa186  renders/lab-round7-1/secret-spillway-s2701.mp3
eae3745d419bf5c7990df905f3ae6ba1b493b47b60295039807706b28db13dbc  renders/lab-round7-1/secret-spillway-s2702.mp3
621e4f2fcdc1424fced0030c8999e3bb1b16a6bb0427efd3605bcc9481d591b2  renders/lab-round7-1/waking-final-s2701.mp3
b6886730801c07d5386fde6f2cb9e53e92ec201ad849b7be112be4cfaf069278  renders/lab-round7-1/waking-final-s2702.mp3
acb514797835f621f9837ddc420bc1724976188751a191f3ce50d812059b4727  renders/lab-round7-1/grid/waking-final-s2702-142bpm.wav
da37880badd5e95394d5ff5c95b4d7ce8ec79543cc5cc525379569f069ccf585  variations/buff-low-hull.wav
8a1022bd080883864a9a2a0ea8d7bc0c44a4147f5634f906d05d8ebfaca2e7cc  variations/buff-overdrive.wav
9d8893c48edf145db382c8e76401f2918d1a4a805a183f2887fd8144723e20ce  variations/buff-scrap-streak.wav
8ea3c7762aec09d64e8034dc0af00c6f680d6a7172d255a0cb853c7728b33f05  variations/buff-shield.wav
536d3050cedf00fb74cf11bd4d4f6580f0c58ff22be760ed3a402f49619409fa  variations/buff-slowmo.wav
be9906533b7f7c4bd2ce90527ed5cbebebaccba4a0c13bfb67abf89999917598  variations/demo-fight-switchup-boss.wav
6d7df11e45eab0d1cb86862d64311f4cd65789760430a7f25ad7f01ba61f1404  variations/demo-roam-turnaround-fight.wav
46cd99caa0ab1987ae0ba736b6861d265da9827bc47cf1d8b26c9b6c9504b936  variations/switch-hit-129.wav
244136850cc042f0d1404e52e496acd58d70b5a6ec594df59505690ffcab4d67  variations/switch-hit-172.wav
0365deac34ad0a26dd77f4deb5de097283f62253ac8304d70ae7076eb4d85f55  variations/turnaround-129.wav
7f9d58fa3817bd24996dc75ee63ebc9f2e11921d82735704d204a46668281ad2  variations/turnaround-172.wav
03b8154cfa91d2e05602a66d987a46b5dc1cb5eeb47d856ab048a0b3ff56c671  variant-src/brindle-p1-138.wav
cdbda50daad24185fafe92dad126713e86734615430551f544e5d6a01cd801a7  variant-src/brindle-p2-150.wav
6f4f2cf9fa2ed8cc12216eb0fdc5706789578918fd8660d69cd44fa895e710bb  variant-src/brindle-p3-172.wav
611b6ba212b4cb47da03ae891d1e2447513c60070c266e48cf476b57f82cf8aa  variant-src/hype-129.wav
f541215e8d892405a84fcec5cc6be10de280a98b441b705e3eee02e68918add1  variant-src/mind-final-142.wav
d1672b7b2a521f8aee9630fd2c826ef5879de4ac236be0f4eb5a845fd8e1f51f  variant-src/roam-dig-172.wav
595c1caebab76b4a56a07957b6bc9a21f482b08bc112703597a7b39df683ae05  variant-src/roam-highdraft-172.wav
b7f05b13cc1ec936aeb51c37fe1ade8902ab8a1b25aa246813b43dea29f9abb1  variant-src/roam-spillway-172.wav
1dd5c20b291e195b21e18b3ff27c8edf3fa54eb8d90a18e56dab4ca146d24235  variant-src/title-a-129.wav
0c72d3fad5a6f8565531be91a3a425e2210e40aea7d05a0c06d23d14ed4e21f6  variant-src/title-b-172.wav
d9ec3de2f1a7079b5e50045c4f32c5128c680616ce366887d74a4c1b1153ef11  variant-src/waking-final-142.wav
```

## Eurodance bosses and the hype rule, rounds 8 and 9, 2026-10-17

Covers of the picked takes (round 7 picks for Brindle's phases and the final phases, the round 4 grid takes for the Waking and the Mind). Round 9 is the champion pick stretched to 145, the flow band, then covered. Strength 0.55. Seeds 2801 and 2802, then 2901 and 2902. Every take beats its control by at least 0.17 (euro-waking-s2802).

| Take | Asked | Tempo read | Parent | Control | Margin | Longest quiet | Pick |
| --- | --- | --- | --- | --- | --- | --- | --- |
| euro-brindle-p1-s2801 | 138 | 137.9 | 0.49 | 0.15 (boss-waking-s2401-129bpm.wav) | 0.34 | 0.5 s |  |
| euro-brindle-p1-s2802 | 138 | 137.9 | 0.61 | 0.22 (boss-waking-s2401-129bpm.wav) | 0.39 | 0.1 s | yes |
| euro-brindle-p2-s2801 | 150 | 163.6 | 0.65 | 0.2 (roam-highdraft-172.wav) | 0.45 | 0.1 s | yes |
| euro-brindle-p2-s2802 | 150 | 128.5 | 0.62 | 0.32 (roam-highdraft-172.wav) | 0.30 | 1.2 s |  |
| euro-brindle-p3-s2801 | 172 | 172.0 | 0.56 | 0.28 (boss-mind-s2402-129bpm.wav) | 0.28 | 0.1 s | yes |
| euro-brindle-p3-s2802 | 172 | 172.0 | 0.51 | 0.19 (boss-mind-s2402-129bpm.wav) | 0.32 | 0.0 s |  |
| euro-waking-s2801 | 129 | 129.0 | 0.36 | 0.16 (hype-129.wav) | 0.20 | 0.5 s |  |
| euro-waking-s2802 | 129 | 129.0 | 0.37 | 0.2 (hype-129.wav) | 0.17 | 0.0 s | yes |
| euro-waking-final-s2801 | 142 | 140.0 | 0.61 | 0.38 (roam-dig-172.wav) | 0.23 | 1.4 s | yes |
| euro-waking-final-s2802 | 142 | 140.0 | 0.56 | 0.38 (roam-dig-172.wav) | 0.18 | 1.1 s |  |
| euro-mind-s2801 | 129 | 129.0 | 0.63 | 0.28 (boss-waking-s2401-129bpm.wav) | 0.35 | 0.0 s | yes |
| euro-mind-s2802 | 129 | 114.6 | 0.5 | 0.3 (boss-waking-s2401-129bpm.wav) | 0.20 | 0.0 s |  |
| euro-mind-final-s2801 | 142 | 141.9 | 0.62 | 0.3 (r7-brindle-p3-scuttle-s2702.wav) | 0.32 | 0.0 s | yes |
| euro-mind-final-s2802 | 142 | 141.9 | 0.62 | 0.29 (r7-brindle-p3-scuttle-s2702.wav) | 0.33 | 0.0 s |  |

| Take | Asked | Tempo read | Parent | Control | Margin | Longest quiet | Pick |
| --- | --- | --- | --- | --- | --- | --- | --- |
| euro-champion-s2901 | 145 | 145.0 | 0.57 | 0.3 (brindle-p2-150.wav) | 0.27 | 0.6 s | yes |
| euro-champion-s2902 | 145 | 145.0 | 0.53 | 0.16 (brindle-p2-150.wav) | 0.37 | 0.5 s |  |

The first round 9 measurement scored the take against its own parent as the control, because the round has one variant; the scores were equal (0.57 and 0.57). The script now draws the control from every round's parents, from another theme family.

`extras.py` writes 13 cues to `extras/`, checked by `check_events.py` with 0 failures. The cues are six pilot quotes (cells copied from `Harmony.MOTIFS`), the clutch comeback, three crowd tiers, the honk, the hype drop and the retry kick-in. The checker first failed `hype_drop` on onset (152 ms), because it was filed as a boss cue; it swells in on purpose a bar early, so it is now a stinger. `variant-src/hype-129-up1.wav` is the hype loop a semitone up, for the clutch demo. `variations.py`'s low-hull buff now pumps an 808 heartbeat and ducks the band on each beat.

```text
2eba19fd3726a39a8196343b822b7ee65579509b113eec1d44aab0e646f1d9df  renders/lab-round8-1/euro-brindle-p1-s2801.mp3
e83b0f7ae63b57fdc28088ead7c43f82c94d401461bc756e445a04aabe7781fe  renders/lab-round8-1/euro-brindle-p1-s2802.mp3
92f62734808fcc860da108c26003dd1f0131f7f8f4b77e69d57387e746b7858b  renders/lab-round8-1/euro-brindle-p2-s2801.mp3
30fe7ec29b35b31cf422d33135496a166a19bcf2b5544ff3002012e2471e2ad3  renders/lab-round8-1/euro-brindle-p2-s2802.mp3
78b11663cb624fe67d70ca51446c164569462d9021fadda14baaff12816965b9  renders/lab-round8-1/euro-brindle-p3-s2801.mp3
cf52921afe18ce0f5e31fb4b9bcd37b5c654809ac71d1f1f8d0ce0ef3ddb0a0a  renders/lab-round8-1/euro-brindle-p3-s2802.mp3
b89b81f76a4a96467eba43a554486f4fb2a26b9f348eb5cbdc1b5025ea08b07d  renders/lab-round8-1/euro-mind-final-s2801.mp3
253796cb8e6b3fece417d3f14a2c57efccfd585dbf4d0054119d85b1be350a12  renders/lab-round8-1/euro-mind-final-s2802.mp3
4865434369e1ab0328c7c5b518a2266bc1705e39e8f78639156a6943ba30bddd  renders/lab-round8-1/euro-mind-s2801.mp3
8d81baf5847ed963731539185aa67cfee3551b5cefe2c8491588a83bf9f5c439  renders/lab-round8-1/euro-mind-s2802.mp3
e869ff1e9d1e4478dfe2f4b174477da6eb3f5b8608fc914df2010204cfc83389  renders/lab-round8-1/euro-waking-final-s2801.mp3
39b64dd7195d2e8b5bec1ee6f7a6cf4011d395fdc2e7878bc9ff66cc593fb007  renders/lab-round8-1/euro-waking-final-s2802.mp3
3acee3863bea6e165e365c0af4d6ea6602da0948a07c1552f8bc2bb01317355d  renders/lab-round8-1/euro-waking-s2801.mp3
eafe25f6fa754a9bd58799be21d4e5cd2ce3ee5a6ad16c48ae9aca6bdbaccfa9  renders/lab-round8-1/euro-waking-s2802.mp3
3ad68d8a95a240cc5827ad0b2f623aa18bbce0aa18b70738342862a763664f76  renders/lab-round9-1/euro-champion-s2901.mp3
a9cac9f62ac8d0fc5cfd0ce0ccc317c2bb4a8594e4c4f172000030bbbade075d  renders/lab-round9-1/euro-champion-s2902.mp3
3cd6b33d36c4e0c6a0c077cc2518e7b48b418b8d7dbba8a54f662ad12e9b4ccb  extras/clutch_comeback.wav
ae56e2056c6763b843a715528206bd3b9a438af71775992d77e0622e7bcd3734  extras/crowd_cheer_1.wav
5f4529e41c51fa423b9bd345886697be360a9b88f0b57ec6bde87a004f0fcbe0  extras/crowd_cheer_2.wav
267b019ec4e024ef14511473e26116757df9ad443575e93435e2b368d0da0879  extras/crowd_cheer_3.wav
a0335c6178cc0ca24a811608f7422140403ef0529a9593c19e425f4daef5e5be  extras/demo-clutch.wav
94209439df7d1819ce0c9dd75607736faa17a2ee62b5da183f426bd67a23b9e7  extras/demo-crowd.wav
6564b4bfaed4c92c809a90af252a492f3f68bba7804d60a285bdfe841da3bec3  extras/demo-honk.wav
890a912d8f18e3c81a9c34133115e241180703eeb3a222602812fff485c6ffe4  extras/demo-pilot-quotes.wav
4ce0e56ebbc5436886d060e0449cb6efc875dd0d140bfd7016703b4374155905  extras/hype_drop.wav
42fa1d30d7a969a8a685c4ee06e1c3b90139f53770d5ea59f3d69659e11c5d44  extras/pilot_quote_cannon.wav
fdccd89603ce65c3e7f24fbee83a4e11bbbb2c78b9be1d9197a8c1566c279f4a  extras/pilot_quote_kest.wav
b5355e30199c76ee4f9686e0a8665840b02ba0d531744d79e87381bde8357b2c  extras/pilot_quote_rivet.wav
125bbd7134a34082fcee150adb954697ed96afef9212f659d45521a8a194e012  extras/pilot_quote_sable.wav
144382164782d1bebe36e62cc8e4e3485f9141d9b1e02e5a614ddf7cc3e83375  extras/pilot_quote_tally.wav
4f80309501d810e1ff8b75329ba55d869c620d11b0535689565ff2dc5a3e69e7  extras/pilot_quote_tarn.wav
b0cfcfbe5c7042ef8e70656efec29042c4538de3483e64c5be893c237f7a6e0a  extras/retry_kickin.wav
aa3e67e28cd9df4fd365c979078148eb999465eb60175535ea5d482e6ee127e2  extras/whiff_honk.wav
ba659c66400a4b59386abd586aaf7ab8f398150e4ce0c451938fae67f48eb888  variations/buff-low-hull.wav
6b57fea104210c1bd40f0881b25c3fe4cfb53fd9b42f0243dc6081263ff2ae36  variant-src/r7-brindle-p1-requisition-s2701.wav
e33d1f15ca1d14b81a03b8979cb809b8c21347fd214ab9cbb13027e12f119594  variant-src/r7-brindle-p2-furnace-s2702.wav
0acaee0f956e750067a5f80813a5eabb35a2ca5d590871d6a905e0ecff47a37e  variant-src/r7-brindle-p3-scuttle-s2702.wav
72755adf4cf8d333535c950cf13cfcd9a71fea3aed1ad276efd938efa50ada59  variant-src/r7-champion-145.wav
8a525bdd2164651cd42c8f839a1e8498f5cca111a67e966290281b272b9e5feb  variant-src/r7-mind-final-s2701.wav
acb514797835f621f9837ddc420bc1724976188751a191f3ce50d812059b4727  variant-src/r7-waking-final.wav
e67e6e0a372aca18b339cf539d641156029d188852e147f05008b5187c134f98  variant-src/hype-129-up1.wav
```

## Cue sheet notes, 2026-10-17

- **The Mind's first quote, in the Spillway** (Andrew, Q9 "A musical quote"). `music_layer_mind_quote_spillway` is two bars of the Spillway pack's travel clip (bars 1 to 3) with the Mind's line on its sine chime on top: theme K bars 1 and 2 in D Dorian, inverted around its first note, last note a semitone flat (D B G E C | D E F G A Bb), swung, the band's melody stem at 0.45 under it. Made by `tools/ace/mind_quote.py`, -16 LUFS, true peak -2.7 dBTP. It is the first time the player hears the Mind, a world before they meet it. Ear check: Andrew. Where it fires is the Spillway's choice (a landmark or the Warden approach, once per run); it sits in SfxBank as a file sound.
- **A hit on the beat** (Andrew, Q10 "Sound only"). Since 13 November 2026 it is `assets/audio/sfx/onbeat_clap.wav` from [feedback_set.py](feedback_set.py): a clap of three short noise bursts and a small room, 0.18 s, no pitch, played about at a ranged hit's level (8 dB under the old stab) at most once per beat. The earlier `onbeat_sax_stab.wav` (a two-note `sax_lounge` stab, A5 and D6) is no longer played. No damage change.
- **Place layers stay out of arenas** (the Crown pass). A place music layer's sensor sits outside every arena, or the music director locks layers during a fight: a layer switching mid-fight moves the on-bar telegraphs. That holds for the Mind quote above wherever it fires.
- **The Highdraft's own drops** (PR #83). `drop_fleet_anvil` (an anvil pair, then a G Lydian brass stab) and `drop_boiler` (a hiss, a pop and a whistle bending to the tritone) are designed one-shots for 3-1 and 3-2, a whole step apart, by `tools/ace/highdraft_stingers.py`; `cut_stingers.py` leaves them to it. The Highdraft has no cut `riser_mind_quote` or `drop_mind_wrong`, so the engine plays its pilot-aware Mind quote there.

## Core packs from the sound-bible picks (2026-10-17)

The core ACE packs play Andrew's mastered picks from `sound-bible-2026-10-16/spice/` (`<cue>-current.wav`, `-spiced.wav`, `-light.wav`), cut by `tools/ace/package_core_packs.py` (`stretch`, `plan`, `pack`) from htdemucs stems (`nice -n 10`, cuda, vocals folded into other) of the 44.1 kHz resample. The rule: roaming ramps with speed, so calm, travel and the kill cadence come from the -current mix and pivot, build, telegraph, open and drop from the -spiced mix of the same track (same tempo, sample-aligned, so a switch never jumps). The roam packs and the title packs use the layout calm, travel, cadence. Every clip is cut on the measured kick phase of its own drums stem (45 ms snap limit) and loops join like `package_music.cut_clip`; gains put each 10 s or longer clip at -16 LUFS with a -3 dBFS limiter ceiling. The three 16-bar loop tracks (126.95, 127.95 and 123.9 bpm) are stretched with Rubber Band to exactly 129, one ratio per track on every stem. The grid files (roam, boss) are cut at their nominal 172 or 129; the titles at the tempo read from their kicks. Timing is not human-verified (`timing_verified` false). Keys are the nominal world tonics, not measured; `tools/ace/key_check.py` found mismatches, listed below the table. `camp` is the light mix whole at 129 (key check: D minor, a match). `summary` follows Andrew's card (2026-10-17 23:24:59Z, "Won run and ending"): a won run plays theme C, its two intro bars in D and then the loop lifted a whole step to E (Rubber Band `-p 2` on bass, other and vocals; drums unshifted), and a lost run keeps the jazz-club summary-loss. The intro bars sit at -23 LUFS, theme C's own build into the lift; that and the lift want an ear check. `title` is untouched.

Bars count from the first kick-grid downbeat of the track; a loop track wraps. M is the track's music bar count.

| Pack | bpm | Sources | Section map |
|---|---|---|---|
| roam_spillway | 172.0 | roam-spillway-current, roam-spillway-spiced | calm cur 5-20 loop, travel cur 21-36 loop, cadence spi 43-44 |
| roam_dig | 172.0 | roam-dig-current, roam-dig-spiced | calm cur 5-20 loop, travel cur 21-36 loop, cadence spi 43-44 |
| roam_highdraft | 172.0 | roam-highdraft-current, roam-highdraft-spiced | calm cur 5-20 loop, travel cur 21-36 loop, cadence spi 42-43 |
| spillway | 129.0 / 172.0 | roam-spillway-current, spillway-loop-current, spillway-loop-spiced | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 0-0, build spi 1-16 loop, telegraph spi 5-8 loop, open spi 11-14 loop, drop spi 13-16, cadence cur 15-16 |
| cable_reach | 129.0 / 172.0 | roam-spillway-current, spillway-loop-current, spillway-loop-spiced | calm cur 13-28 loop, travel cur 29-44 loop, pivot spi 8-8, build spi 9-24 loop, telegraph spi 17-20 loop, open spi 13-16 loop, drop spi 21-24, cadence cur 23-24 |
| dig_upper | 129.0 / 172.0 | dig-loop-current, dig-loop-spiced, roam-dig-current | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 0-0, build spi 1-16 loop, telegraph spi 5-8 loop, open spi 11-14 loop, drop spi 13-16, cadence cur 15-16 |
| dig_deep | 129.0 / 172.0 | dig-loop-current, dig-loop-spiced, roam-dig-current | calm cur 13-28 loop, travel cur 29-44 loop, pivot spi 8-8, build spi 9-24 loop, telegraph spi 17-20 loop, open spi 13-16 loop, drop spi 21-24, cadence cur 23-24 |
| highdraft | 129.0 / 172.0 | highdraft-loop-current, highdraft-loop-spiced, roam-highdraft-current | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 0-0, build spi 1-16 loop, telegraph spi 5-8 loop, open spi 11-14 loop, drop spi 13-16, cadence cur 15-16 |
| highdraft_crown | 129.0 / 172.0 | highdraft-loop-current, highdraft-loop-spiced, roam-highdraft-current | calm cur 13-28 loop, travel cur 29-44 loop, pivot spi 8-8, build spi 9-24 loop, telegraph spi 17-20 loop, open spi 13-16 loop, drop spi 21-24, cadence cur 23-24 |
| boss_brindle | 129.0 | boss-brindle-current, boss-brindle-spiced | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 16-16, build spi 17-32 loop, telegraph spi 40-43 loop, open spi 44-47 loop, drop spi 48-51, cadence cur 50-51 |
| boss_waking | 129.0 | boss-waking-current, boss-waking-spiced | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 16-16, build spi 17-32 loop, telegraph spi 40-43 loop, open spi 44-47 loop, drop spi 48-51, cadence cur 50-51 |
| boss_mind | 129.0 | boss-mind-current, boss-mind-spiced | calm cur 5-20 loop, travel cur 21-36 loop, pivot spi 16-16, build spi 17-32 loop, telegraph spi 41-44 loop, open spi 45-48 loop, drop spi 49-52, cadence cur 51-52 |
| title_a | 127.01 | title-a-spiced | calm spi 5-20 loop, travel spi 21-36 loop, cadence spi 45-46 |
| title_b | 128.0 | title-b-spiced | calm spi 5-20 loop, travel spi 21-36 loop, cadence spi 47-48 |
| title_c | 172.02 | title-c-spiced | calm spi 5-20 loop, travel spi 21-36 loop, cadence spi 63-64 |
| camp | 129.0 | camp-light | calm 5-20 loop, travel 21-36 loop, cadence 40-41 |
| summary | 172.02 won, 129.0 lost | title-c-spiced, title-c-spiced up a whole step, summary-loss-light | won: cadence title-c 3-4 in D into calm title-c 5-20 lifted to E (loop); lost: travel summary-loss light 2-17 (loop) |

In the section map `cur` is the -current mix, `spi` the -spiced mix and `lig` the -light mix; the numbers are the 1-based bars of the source (loop tracks wrap past bar 16).

Key check (chroma against the nominal tonic, `key_check.py`, native stems): the loop tracks match (spillway and cable_reach D minor, dig E minor, highdraft G minor), as do brindle D minor and title_b and title_c D major. Mismatches: the roam tracks (roam_spillway reads A minor, roam_dig C major, roam_highdraft D major), so a zone pack's calm and travel sit in a different key from its pivot to cadence clips; boss_waking reads E minor and boss_mind G minor against nominal D and E; title_a reads A minor against D. The manifests keep the nominal keys until Andrew decides.

## Reproduce

```bash
PATH=<shim dir>:$PATH CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=0 python3 ~/.claude/skills/song-composer/scripts/ace.py sketch <render folder> --seeds 2101 2102
~/.local/share/ACE-Step-1.5/.venv/bin/python -I cut_loops.py <render folder>/renders/sketch-1 <render folder>/loops
~/.local/share/ACE-Step-1.5/.venv/bin/python -I event_sounds.py <render folder>/event-sounds
~/.local/share/ACE-Step-1.5/.venv/bin/python -I grid_stretch.py <run dir> <run dir>/grid129 [--target 172 --only roam- ending]
~/.local/share/ACE-Step-1.5/.venv/bin/python -I event_set.py <render folder>/event-set
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py <render folder>/event-set
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py --self-test
~/.local/share/ACE-Step-1.5/.venv/bin/python -I specials.py <render folder>/specials
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py <render folder>/specials
PATH=<shim dir>:$PATH CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=0 python3 ~/.claude/skills/song-composer/scripts/ace.py lab <render folder> round7 --seeds 2701 2702
~/.local/share/ACE-Step-1.5/.venv/bin/python -I measure_variants.py <render folder> round7 <render folder>/renders/lab-round7-1
~/.local/share/ACE-Step-1.5/.venv/bin/python -I variations.py <render folder>
~/.local/share/ACE-Step-1.5/.venv/bin/python -I extras.py <render folder>
~/.local/share/ACE-Step-1.5/.venv/bin/python -I check_events.py <render folder>/extras
(ace.py lab <render folder> round8 --seeds 2801 2802, and round9 --seeds 2901 2902, then measure_variants.py for each)
```

The shim is a one-line `nvidia-smi` wrapper that adds `-i 0`. Since the RTX 3060 was installed, `ace.py`'s VRAM check fails because it parses one line of `nvidia-smi` output and now gets two.

## Pack levels and the stale-Ogg check (2026-10-18)

The audio gate on every pack's Oggs showed two things the gate could not see while the stems were missing from every checkout. First, the zone packs (spillway, cable_reach, dig_upper, dig_deep, highdraft, highdraft_crown) and the summary pack had Oggs from 30 Sep under manifests rewritten on 17 Oct for the sound-bible picks (153 files): every export and playtest build played the old mix at -12 to -16.7 LUFS while the manifests said -16.0. The fresh Oggs were in other worktrees; they were swapped in. Second, nine clips of the older brindle, mind, title and waking packs sat above -16 LUFS or past -1 dBTP (`mind/travel` -11.5 LUFS, `mind/build` -12.4, and others); `tools/ace/level_packs.py` applied one gain per clip to its three stems and recorded `gain_db` and `measured` in the manifest. No pick, take or cut point changed.

The structural fix: `assets/music_ace/STEMS.sha256` lists the sha256 of every packed Ogg. `scripts/audio-gate.mjs` now reports `stale` for any named Ogg whose hash differs or is unlisted, for a decoded length that differs from `sample_count`, and for a clip more than 0.3 LU from its manifest's `measured.lufs`; `sketch:export` refuses a `--stems-from` folder with any such file and names each one. Run `scripts/music/mx stem-hashes` after every pack or level change. In any new worktree, run `scripts/music/mx stems-sync` first: the Oggs are gitignored, so a fresh worktree holds manifests and no audio. It copies every Ogg `STEMS.sha256` lists from the main checkout (or `~/scratch/w17/music_ace-full`), checks each copy's hash, never overwrites a file whose hash differs, and exits 1 on any mismatched or missing file. The tests plant a stale Ogg and require the check to fail on it before its zero is trusted.

**Short pages (10 November 2026).** An Ogg is stored in pages, and a start anywhere but a page's first sample decodes from the page before. ffmpeg writes one-second pages unless told otherwise, so the sequencer's starts deep in a clip (a build's return at bar 9, a held breath) decoded up to a second of audio on the frame that asked: 2.9 ms a stem on the PC against 0.5 ms at a clip's head. Packed Oggs are therefore stored in 20 ms pages. `tools/ace/package_music.py` `encode` writes them that way; `tools/ace/repage.py apply` re-pages files cut before that without encoding again (the same packets in shorter pages, each file proved to decode to the same samples before it replaces the original, about 9 percent bigger), after which `scripts/music/mx stem-hashes` writes the hash list again. `scripts/audio-gate.mjs` reports `pages` for any named Ogg whose longest page holds more than 0.1 s. `tools/ace/repage_test.py` and the gate's own test cover both.

**Short-clip true-peak trim and repaged hashes (24 November 2026).** Six `< 10 s` clips in the older `brindle`, `mind`, `title` and `waking` packs (`brindle/drop`, `mind/open`, `mind/drop`, `title/cadence`, `waking/telegraph`, `waking/cadence`) sat at `-0.9` to `-0.7 dBTP` after `level_packs.py` skipped them on 18 October. Each clip's three stems received a uniform `-0.8 dB` trim (no limiter; picks, takes, cut points and stem balance unchanged) and 20 ms Ogg re-encode via `package_music.encode` (post-encode peaks `-1.8` to `-1.3 dBTP`, exact `sample_count`, looping seams inside p99.9). The 12 Spillway roaming stems (`spillway/{calm,travel}`, `cable_reach/{calm,travel}`) were restored from Andrew's Take 6107 render (`a-roam174-s6107`, fitted to 172 BPM, htdemucs split, `package_core_packs.py`, 20 ms Ogg pages) because `~/scratch/repage/music_ace` predated commit `8901cc7b5`. All 768 short-paged Oggs live in an Ogg-only directory `~/scratch/w46/music_ace-v2`; `assets/music_ace/STEMS.sha256` was refreshed from it, and `scripts/stems-sync.mjs` checks the main checkout's `assets/music_ace` first, then `~/scratch/w46/music_ace-v2` first among scratch directories (ahead of `w33`, `w19`, `w18` and `w17`), with `~/scratch/repage/music_ace` last.

## Radio takes packed (2026-10-18)

All 81 takes of `assets/radio/catalogue.json` are rendered (two seeds each, 5101 and 5102), picked (`RADIO-PICKS.md`, Andrew's "Music thread picks" tap, 17 Oct 22:28Z: a version that passes every mix check beats one that fails; between two passing versions, more room around the lead wins) and packed as whole-song packs with `tools/ace/package_phase_tracks.py pack --whole`. The registry the pack step reads is `radio_renders.json` (81 rows, one pick each). Each pack is `assets/music_ace/take_<id>/manifest.json`; the Oggs are gitignored like every pack. `MusicRows.take_manifest` resolves a `take-*` id to its pack, so the radio plays the take's own recording and no longer its parent tune. `timing_verified` is false on all 81.

Audio gate (`node scripts/audio-gate.mjs`, run on the 81 packs): loudness -16.0 to -16.1 LUFS on all 81; seam wrap under the loop's own 99.9th percentile step on all 81; true peak under -1 dBTP on 79 at the first pack (limiter ceiling -2.6), `take_fabricator_overclocked` (-0.7) and `take_sinkhole_trip` (-0.9) over after the Ogg encode, repacked at ceiling -3.6 to -1.8 and -1.7 dBTP. Ear check: Andrew, at the sitting.

## Heat radio remake (2026-10-19)

Andrew, 19 Oct: percussion should serve the song like a band's drummer, and many takes sound sloppy. DECISIONS rows "percussion serves the song" and "radio quality pass" apply. The 8 Furnace FM takes that failed the percussion bar were rebuilt from written briefs (`design-v3/sound/radio-briefs/heat.md`, one story moment, feeling, motif, arrangement map and mix note each; reviewed against TONE-BIBLE before any render). Tooling: `radio_remake.py` (render, split, master and pack) and `tools/ace/radio_master.py` (stem chain: per-stem EQ, bus compression, limiter; drum trim).

Two arms, 6 seeds (arm A) and 4 seeds (arm B), rendered on the RTX 3060 (CUDA device 1, 10.2 GB peak):
- arm A: melody-first caption on a plain cover of the parent pick, strength 0.34 to 0.60.
- arm B: cover of a hybrid source (parent bass, drums at -9 dB, the written motif lead from `score/themes.py`), strength 0.60. Hybrids are built by `radio-briefs/build_hybrid.py`.

Picks are the best rubric overall per take with a drum share under the bar; the other seeds stay in the scratch folder for the listen page. Shipped -> remade, from `qp/triage.py` (a proxy: it cannot judge melody or feel, so Andrew's ear decides at the playtest):

| take | pick | overall | percussion | melody | drum share (median) | flags |
|---|---|---|---|---|---|---|
| top-shelf-overdrive | A s6204 | 2.52 -> 3.8 | 0.0 -> 4.34 | 2.72 -> 2.41 | 0.81 -> 0.42 | LOUDNESS_OFF |
| mind-overclock | A s6205 | 2.65 -> 2.9 | 0.0 -> 1.62 | 1.72 -> 2.25 | 0.89 -> 0.55 | PERC_HEAVY,LOUDNESS_OFF |
| stampede-encore | A s6202 | 2.04 -> 4.01 | 0.0 -> 4.18 | 0.97 -> 2.5 | 0.78 -> 0.40 | LOUDNESS_OFF |
| champion-club-mix | B s6302 | 2.13 -> 4.33 | 0.0 -> 4.71 | 0.97 -> 3.11 | 0.73 -> 0.35 | - |
| heavyweight-big-room | B s6303 | 2.62 -> 4.01 | 0.0 -> 4.46 | 2.68 -> 2.42 | 0.65 -> 0.40 | TRUE_PEAK |
| brindle-afterburner | B s6304 | 2.64 -> 3.99 | 0.0 -> 4.85 | 2.26 -> 2.17 | 0.92 -> 0.33 | TRUE_PEAK,LOW_LRA |
| highdraft-hands-up | B s6303 | 2.66 -> 3.9 | 0.0 -> 5.0 | 2.75 -> 2.25 | 0.89 -> 0.24 | TRUE_PEAK |
| round-arena-main-event | B s6302 | 2.58 -> 4.01 | 0.0 -> 4.75 | 1.54 -> 3.83 | 0.69 -> 0.34 | TRUE_PEAK |

Each pick's seed, caption, strength and arm are in `radio_renders.json` under `remade`. Previous renders are untouched, so a pick can be swapped back by removing `remade` and repacking. Motif detection by pitch tracking found no exact hits in any take, old or new, so whether the written hooks are audible is an open question for the ear.

Open items: The Mind, Overclock is still PERC_HEAVY (drums 0.55 of the mix) and is the weakest remake; no seed of either arm cleared the bar, so its pick is the least bad. Melody dropped slightly on Top Shelf, Heavyweight, Brindle and Highdraft while drums fell; Andrew's ear decides whether the trade is right. Flags are from the stem-sum view; the overall column uses the master.wav view, and the shipped packs pass the audio gate (below).

## Rogue mini-boss anthems (2026-10-23)

`gapfill.py anthem-gate-crane anthem-haul-skip anthem-cable-tender` on the RTX 3060 (`ACE_GPU=1`), run `lab-gapfill-4`, seeds 4101 and 4102, cover strength 0.5 of the world's parent, captions from `design-v3/rogues/BRIEFS.md`. Measured with `measure_variants.py`'s chroma match against the parent and an other-family control. The pick is the take whose tempo reads on its row, then the larger margin.

| Take | Asked | Tempo read | Parent | Control | Margin | Longest quiet | Pick |
| --- | --- | --- | --- | --- | --- | --- | --- |
| anthem-gate-crane-s4101 | 140 | 140.0 | 0.17 | 0.18 (take-heavyweight-drum-corps-135.wav) | -0.01 | 0.1 s |  |
| anthem-gate-crane-s4102 | 140 | 140.0 | 0.22 | 0.19 (take-heavyweight-drum-corps-135.wav) | 0.02 | 0.0 s | yes |
| anthem-haul-skip-s4101 | 145 | 165.7 | 0.30 | 0.14 (take-sinkhole-drain-dub-88.wav) | 0.16 | 0.2 s |  |
| anthem-haul-skip-s4102 | 145 | 145.0 | 0.29 | 0.22 (take-sinkhole-drain-dub-88.wav) | 0.07 | 0.2 s | yes |
| anthem-cable-tender-s4101 | 150 | 136.3 (149.65 narrow) | 0.58 | 0.25 (take-sinkhole-drain-dub-88.wav) | 0.33 | 0.1 s | yes |
| anthem-cable-tender-s4102 | 150 | 128.5 | 0.40 | 0.34 (take-sinkhole-drain-dub-88.wav) | 0.06 | 0.1 s |  |

The gate crane takes barely keep combat-hype's harmony (margin 0.02): at strength 0.5 the anthem caption won, so its hook is new rather than a twist. Andrew's ear decides whether that is right.

Packed with `package_phase_tracks.py stretch --tunes` (the three rows only) then `pack --ceiling -2.2`, stems split with htdemucs on the CPU. `scripts/audio-gate.mjs`: every anthem pack passes; the one finding is the 238 clips with no local Oggs in this checkout.

| Pack | Seconds | LUFS | True peak | Seam wrap / p99.9 |
| --- | --- | --- | --- | --- |
| anthem_gate_crane/main | 27.5 | -16.1 | -1.4 | 0.2108 / 0.3243 |
| anthem_haul_skip/main | 26.6 | -16.0 | -1.9 | 0.0065 / 0.277 |
| anthem_cable_tender/main | 25.7 | -16.0 | -1.8 | 0.0091 / 0.2064 |

```text
48882e10d4be1b5fe0a9cffa0104168f50a0e863a6a1099cdf7a7a5524828ec8  renders/lab-gapfill-4/anthem-gate-crane-s4101.mp3
4421c89918138066b8e6d4d8cf3363bc730d0b0676f0012c6ea05ef1d92015d2  renders/lab-gapfill-4/anthem-gate-crane-s4102.mp3
65a23acfb552c12d3b46b0edc4093ab3a5a0dece4d185c583a59083659795788  renders/lab-gapfill-4/anthem-haul-skip-s4101.mp3
55575ca907dfd6b262542f9e4d01d6ea32d83f63119eb91acd5bc1e1ebc6dfb2  renders/lab-gapfill-4/anthem-haul-skip-s4102.mp3
dc8f988499fb71e453113032297f2a9bfd5926709e2a88b4a750354ad95741dc  renders/lab-gapfill-4/anthem-cable-tender-s4101.mp3
9a7fefacc7fba18767e9b466a945548b38ff9a8d111cc4dd3606bffa7ed4d91a  renders/lab-gapfill-4/anthem-cable-tender-s4102.mp3
```
